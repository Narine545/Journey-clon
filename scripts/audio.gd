class_name SoundScape
extends Node
## Звуковой мир: шаги по песку, шелест скольжения, ветер и два слоя
## «музыки» (амбиент-пад + сияние на сёрфе). Всё синтезируется кодом
## в AudioStreamWAV при запуске — бинарных ассетов в проекте нет.
##
## Реактивность: громкость скольжения следует скорости по песку,
## ветер — высоте и силе ветра, сияние — сёрфу (game.surf01).
## Шаги, посадка и пыль вызываются из Player в момент постановки стопы.

const RATE_SFX := 22050 # Гц — шагам нужен хруст
const RATE_MUSIC := 5512 # Гц — пады низкочастотные, синтез дешевле

const PAD_BASE := [146.83, 220.0, 293.66, 329.63] # D3 A3 D4 E4 — открытая кварта
const PAD_BASE_AMP := [1.0, 0.75, 0.5, 0.42]
const PAD_SHIMMER := [220.0, 293.66, 329.63] # A3 D4 E4 — тёплое сияние (без «звона»)
const PAD_SHIMMER_AMP := [0.85, 0.6, 0.5]

var game
var player: Player

var _step_streams: Array[AudioStreamWAV] = []
var _step_players: Array[AudioStreamPlayer3D] = []
var _step_rr := 0
var _slide: AudioStreamPlayer3D
var _land: AudioStreamPlayer3D
var _wind: AudioStreamPlayer
var _pad: AudioStreamPlayer
var _shimmer: AudioStreamPlayer
var _wind_filter: AudioEffectLowPassFilter
var _slide_gain := 0.0
var _wind_gain := 0.0
var _shimmer_gain := 0.0
var _pad_fade := 0.0
var _shot: AudioStreamPlayer
var _gun_empty: AudioStreamPlayer
var _reload_sfx: AudioStreamPlayer


func setup(game_ref, player_ref: Player) -> void:
	game = game_ref
	player = player_ref
	_make_buses()
	_make_sounds()


func _make_buses() -> void:
	_ensure_bus("Sand")
	_ensure_bus("Wind")
	_ensure_bus("Music")

	# ветер глохнет через фильтр — частота среза дышит от погоды и скорости
	_wind_filter = AudioEffectLowPassFilter.new()
	_wind_filter.cutoff_hz = 1800.0
	AudioServer.add_bus_effect(AudioServer.get_bus_index("Wind"), _wind_filter, 0)

	# музыке — мягкость (срезаем «звон» сверху) и немного пространства
	var music_lp := AudioEffectLowPassFilter.new()
	music_lp.cutoff_hz = 2600.0
	AudioServer.add_bus_effect(AudioServer.get_bus_index("Music"), music_lp, 0)
	var reverb := AudioEffectReverb.new()
	reverb.room_size = 0.62
	reverb.damping = 0.45
	reverb.wet = 0.14
	reverb.dry = 0.9
	AudioServer.add_bus_effect(AudioServer.get_bus_index("Music"), reverb, 1)


func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) < 0:
		AudioServer.add_bus()
		var idx := AudioServer.get_bus_count() - 1
		AudioServer.set_bus_name(idx, bus_name)
		AudioServer.set_bus_send(idx, "Master")


func _make_sounds() -> void:
	# шаги: 6 вариаций мягкого «пшш» по песку
	for k in range(6):
		_step_streams.append(_gen_footstep(917 + k * 131))
	for k in range(4):
		var p := AudioStreamPlayer3D.new()
		p.bus = "Sand"
		p.unit_size = 5.0
		p.position = Vector3(0.0, 0.1, 0.0)
		player.add_child(p)
		_step_players.append(p)

	# шелест скольжения — петля, громкость следует скорости
	_slide = AudioStreamPlayer3D.new()
	_slide.bus = "Sand"
	_slide.stream = _gen_slide()
	_slide.unit_size = 7.0
	_slide.position = Vector3(0.0, 0.12, 0.0)
	player.add_child(_slide)
	_slide.volume_db = linear_to_db(0.0001)
	_slide.play()

	# глухой удар посадки
	_land = AudioStreamPlayer3D.new()
	_land.bus = "Sand"
	_land.stream = _gen_land()
	_land.unit_size = 8.0
	_land.position = Vector3(0.0, 0.1, 0.0)
	player.add_child(_land)

	# ветер — глобальный
	_wind = AudioStreamPlayer.new()
	_wind.bus = "Wind"
	_wind.stream = _gen_wind()
	add_child(_wind)
	_wind.volume_db = linear_to_db(0.0001)
	_wind.play()

	# музыка: тихий амбиент-пад с медленным появлением + сияние на сёрфе
	_pad = AudioStreamPlayer.new()
	_pad.bus = "Music"
	_pad.stream = _gen_pad(PAD_BASE, PAD_BASE_AMP, 9.0)
	add_child(_pad)
	_pad.volume_db = linear_to_db(0.0001)
	_pad.play()

	_shimmer = AudioStreamPlayer.new()
	_shimmer.bus = "Music"
	_shimmer.stream = _gen_pad(PAD_SHIMMER, PAD_SHIMMER_AMP, 7.0)
	add_child(_shimmer)
	_shimmer.volume_db = linear_to_db(0.0001)
	_shimmer.play()

	# оружие: выстрел, сухой щелчок пустого магазина, перезарядка
	_shot = AudioStreamPlayer.new()
	_shot.stream = _gen_shot()
	add_child(_shot)

	_gun_empty = AudioStreamPlayer.new()
	_gun_empty.stream = _gen_empty_click()
	add_child(_gun_empty)

	_reload_sfx = AudioStreamPlayer.new()
	_reload_sfx.stream = _gen_reload()
	add_child(_reload_sfx)


func _process(delta: float) -> void:
	var hv := Vector3(player.vel.x, 0.0, player.vel.z)
	var spd := hv.length()
	var spd01 := clampf(spd / 17.5, 0.0, 1.0)

	# --- скольжение по песку ---
	var slide_target := 0.0
	if player.grounded and spd > 3.2:
		slide_target = clampf((spd - 3.2) / 8.0, 0.0, 1.0) * (0.28 + 0.42 * game.surf01)
	_slide_gain = _damp(_slide_gain, slide_target, 6.0, delta)
	_slide.volume_db = linear_to_db(maxf(_slide_gain, 0.0001))
	_slide.pitch_scale = 0.75 + spd01 * 0.45

	# --- ветер: сильнее на высоте, в полёте и в порывах ---
	var alt01 := clampf((player.global_position.y - 6.0) / 26.0, 0.0, 1.0)
	var gust := clampf(game.wind_strength - 0.9, 0.0, 0.45) / 0.45
	var wind_target := 0.15 + 0.14 * gust + 0.20 * alt01
	if player.gliding:
		wind_target += 0.20
	elif not player.grounded:
		wind_target += 0.10
	_wind_gain = _damp(_wind_gain, wind_target, 3.0, delta)
	_wind.volume_db = linear_to_db(maxf(_wind_gain, 0.0001))
	_wind_filter.cutoff_hz = lerpf(650.0, 2500.0, clampf(gust + spd01 * 0.5, 0.0, 1.0))

	# --- музыка: фон тихий, сияние на сёрфе — деликатное дыхание, не звон ---
	_pad_fade = minf(_pad_fade + delta / 7.0, 1.0) # мир входит тихо
	_pad.volume_db = linear_to_db(0.26 * _pad_fade + 0.0001)
	var shine := pow(clampf(game.surf01, 0.0, 1.0), 1.2)
	_shimmer_gain = _damp(_shimmer_gain, shine * 0.22, 1.6, delta)
	_shimmer.volume_db = linear_to_db(maxf(_shimmer_gain, 0.0001))


# ---------------------------------------------------------------------------
# События (вызывает Player)
# ---------------------------------------------------------------------------

func on_step(spd01: float) -> void:
	if _step_players.is_empty():
		return
	var p := _step_players[_step_rr]
	_step_rr = (_step_rr + 1) % _step_players.size()
	p.stream = _step_streams[randi() % _step_streams.size()]
	p.pitch_scale = 0.80 + randf() * 0.35
	p.volume_db = linear_to_db(0.10 + 0.26 * spd01)
	p.play()


func on_land(impact01: float) -> void:
	_land.pitch_scale = 0.72 + randf() * 0.16
	_land.volume_db = linear_to_db(0.18 + 0.34 * impact01)
	_land.play()


func on_shot() -> void:
	_shot.pitch_scale = 0.94 + randf() * 0.10
	_shot.play()


func on_gun_empty() -> void:
	_gun_empty.play()


func on_reload() -> void:
	_reload_sfx.pitch_scale = 0.95 + randf() * 0.08
	_reload_sfx.play()


# ---------------------------------------------------------------------------
# Синтез
# ---------------------------------------------------------------------------

## Шаг по песку: глухой мягкий «пшш» — песок шуршит, а не трещит.
## Спектр глушится двумя полюсами, «зернистость» — лёгкое переваливание
## на низкой частоте, атака не мгновенная.
func _gen_footstep(p_seed: int) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = p_seed
	var n := int(0.16 * RATE_SFX)
	var s := PackedFloat32Array()
	s.resize(n)
	var lp1 := 0.0
	var lp2 := 0.0
	var sway := lerpf(34.0, 58.0, rng.randf())
	var cph := rng.randf() * TAU
	for i in n:
		var t := float(i) / RATE_SFX
		var w := rng.randf_range(-1.0, 1.0)
		var cut := lerpf(0.32, 0.09, t / 0.16)
		lp1 += (w - lp1) * cut
		lp2 += (lp1 - lp2) * cut
		var env := minf(t / 0.009, 1.0) * exp(-t * 19.0)
		var soft := 1.0 + 0.10 * sin(TAU * sway * t + cph)
		s[i] = lp2 * env * soft * 0.55
	return _stream(s, RATE_SFX, false)


## Шелест скольжения: бесшовная петля розового шума с дыханием.
func _gen_slide() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5501
	var n := int(1.8 * RATE_SFX)
	var fade := int(0.06 * RATE_SFX)
	var m := n + fade
	var buf := PackedFloat32Array()
	buf.resize(m)
	var lp1 := 0.0
	var lp2 := 0.0
	var lp3 := 0.0
	for i in m:
		var w := rng.randf_range(-1.0, 1.0)
		lp1 += (w - lp1) * 0.22
		lp2 += (lp1 - lp2) * 0.30
		lp3 += (lp2 - lp3) * 0.04
		var lfo := 0.78 + 0.22 * sin(TAU * 2.0 * float(i) / float(n))
		buf[i] = (lp2 - lp3 * 0.7) * lfo
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		if i < fade:
			var k := float(i) / float(fade)
			s[i] = buf[i] * k + buf[n + i] * (1.0 - k)
		else:
			s[i] = buf[i]
	return _stream(s, RATE_SFX, true)


## Ветер: низкий гул шума с медленными волнами громкости.
func _gen_wind() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7717
	var n := int(3.2 * RATE_SFX)
	var fade := int(0.10 * RATE_SFX)
	var m := n + fade
	var buf := PackedFloat32Array()
	buf.resize(m)
	var lp1 := 0.0
	var lp2 := 0.0
	var lp3 := 0.0
	for i in m:
		var w := rng.randf_range(-1.0, 1.0)
		lp1 += (w - lp1) * 0.06
		lp2 += (lp1 - lp2) * 0.10
		lp3 += (lp2 - lp3) * 0.25
		var ph := float(i) / float(n)
		var lfo := 0.72 + 0.18 * sin(TAU * 1.0 * ph) + 0.10 * sin(TAU * 3.0 * ph + 1.3)
		buf[i] = (lp2 + lp3 * 0.4) * lfo
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		if i < fade:
			var k := float(i) / float(fade)
			s[i] = buf[i] * k + buf[n + i] * (1.0 - k)
		else:
			s[i] = buf[i]
	return _stream(s, RATE_SFX, true)


## Посадка: глухой удар с низким тоном.
func _gen_land() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 313
	var n := int(0.28 * RATE_SFX)
	var s := PackedFloat32Array()
	s.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE_SFX
		var w := rng.randf_range(-1.0, 1.0)
		lp += (w - lp) * 0.12
		var env := minf(t / 0.003, 1.0) * exp(-t * 16.0)
		var thump := sin(TAU * 82.0 * t) * exp(-t * 20.0) * 0.55
		s[i] = (lp * 0.8 + thump) * env
	return _stream(s, RATE_SFX, false)


## Выстрел: мгновенная атака, тело — быстро глохнущий шум
## плюс низкий удар (дульный тон).
func _gen_shot() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var n := int(0.30 * RATE_SFX)
	var s := PackedFloat32Array()
	s.resize(n)
	var lp1 := 0.0
	var lp2 := 0.0
	for i in n:
		var t := float(i) / RATE_SFX
		var w := rng.randf_range(-1.0, 1.0)
		var cut := lerpf(0.85, 0.05, pow(t / 0.30, 0.6))
		lp1 += (w - lp1) * cut
		lp2 += (lp1 - lp2) * cut
		var env := minf(t / 0.0025, 1.0) * exp(-t * 13.0)
		var thump := sin(TAU * 95.0 * t) * exp(-t * 26.0) * 0.6
		s[i] = (lp2 * 1.4 + thump) * env
	var peak := 0.0001
	for i in n:
		peak = maxf(peak, absf(s[i]))
	for i in n:
		s[i] = s[i] / peak * 0.9
	return _stream(s, RATE_SFX, false)


## Пустой магазин: сухой короткий щелчок.
func _gen_empty_click() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 931
	var n := int(0.05 * RATE_SFX)
	var s := PackedFloat32Array()
	s.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE_SFX
		var w := rng.randf_range(-1.0, 1.0)
		lp += (w - lp) * 0.45
		var env := minf(t / 0.001, 1.0) * exp(-t * 90.0)
		s[i] = lp * env * 0.6
	return _stream(s, RATE_SFX, false)


## Перезарядка: два механических щелчка — магазин вышел, магазин вошёл.
func _gen_reload() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1157
	var n := int(0.55 * RATE_SFX)
	var s := PackedFloat32Array()
	s.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE_SFX
		var w := rng.randf_range(-1.0, 1.0)
		lp += (w - lp) * 0.30
		var click1 := exp(-absf(t - 0.08) * 70.0)
		var click2 := exp(-absf(t - 0.38) * 70.0)
		s[i] = lp * (click1 + click2) * 0.85
	return _stream(s, RATE_SFX, false)


## Пад: аккорд из синусов. Каждая частота округляется до целого числа
## периодов в петле — луп идеально бесшовный. Голоса «дышат» медленными
## LFO (тоже целое число циклов на петлю).
func _gen_pad(freqs: Array, amps: Array, length_s: float) -> AudioStreamWAV:
	var n := int(length_s * RATE_MUSIC)
	var voices: Array = []
	for k in freqs.size():
		var cycles := maxf(1.0, roundf(float(freqs[k]) * length_s))
		var f := cycles / length_s
		voices.append([f, float(amps[k]), 1 + (k % 3), float(k) * 1.7])
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t := float(i) / RATE_MUSIC
		var ph := t / length_s # 0..1 за петлю
		var v := 0.0
		for p in voices:
			var f: float = p[0]
			var a: float = p[1]
			var lfo_k: int = p[2]
			var off: float = p[3]
			var breath := 0.80 + 0.20 * sin(TAU * float(lfo_k) * ph + off)
			v += (sin(TAU * f * t) + 0.22 * sin(TAU * f * 2.0 * t)) * a * breath
		s[i] = v
	var peak := 0.0001
	for i in n:
		peak = maxf(peak, absf(s[i]))
	for i in n:
		s[i] = s[i] / peak * 0.85
	return _stream(s, RATE_MUSIC, true)


## PackedFloat32Array -> AudioStreamWAV (16 бит).
func _stream(s: PackedFloat32Array, rate: int, loop: bool) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(s.size() * 2)
	for i in s.size():
		var v := int(clampf(s[i], -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, v)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	if loop:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = s.size()
	wav.data = data
	return wav


func _damp(v: float, target: float, rate: float, delta: float) -> float:
	return lerpf(v, target, 1.0 - exp(-rate * delta))
