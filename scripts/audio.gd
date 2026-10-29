class_name SoundScape
extends Node
## Сохранённый процедурный синтез ветра и шагов. В M0 слышен только ветер;
## музыку, воду и рыболовные события отключили, не заменяя звук новой системой.

const RATE_SFX := 22050
var game: GameState
var listener: Node3D
var _step_streams: Array[AudioStreamWAV] = []
var _step_players: Array[AudioStreamPlayer3D] = []
var _step_rr := 0
var _land: AudioStreamPlayer3D
var _wind: AudioStreamPlayer
var _wind_filter: AudioEffectLowPassFilter
var _wind_gain := 0.0
var _shot: AudioStreamPlayer
var _bolt: AudioStreamPlayer
var _confirmation: AudioStreamPlayer


func setup(game_ref: GameState, listener_ref: Node3D) -> void:
	game = game_ref
	listener = listener_ref
	_ensure_bus("Sand")
	_ensure_bus("Wind")
	_wind_filter = AudioEffectLowPassFilter.new()
	_wind_filter.cutoff_hz = 1800.0
	AudioServer.add_bus_effect(AudioServer.get_bus_index("Wind"), _wind_filter)
	for k in range(6):
		_step_streams.append(_gen_footstep(917 + k * 131))
	for k in range(4):
		var p := AudioStreamPlayer3D.new()
		p.bus = "Sand"
		p.unit_size = 5.0
		listener.add_child(p)
		_step_players.append(p)
	_land = AudioStreamPlayer3D.new()
	_land.bus = "Sand"
	_land.stream = _gen_land()
	_land.unit_size = 8.0
	listener.add_child(_land)
	_wind = AudioStreamPlayer.new()
	_wind.bus = "Wind"
	_wind.stream = _gen_wind()
	add_child(_wind)
	_wind.volume_db = linear_to_db(0.0001)
	_wind.play()
	_shot = _make_effect(_gen_rifle_shot(), -3.0)
	_bolt = _make_effect(_gen_bolt(), -12.0)
	_confirmation = _make_effect(_gen_confirmation(), -22.0)



func _make_effect(stream: AudioStreamWAV, volume: float) -> AudioStreamPlayer:
	var effect := AudioStreamPlayer.new()
	effect.stream = stream
	effect.volume_db = volume
	add_child(effect)
	return effect


func on_rifle_shot() -> void:
	_shot.pitch_scale = randf_range(0.97, 1.03)
	_shot.play()


func on_bolt() -> void:
	_bolt.play()


func on_hit_confirmed() -> void:
	_confirmation.play()

func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) < 0:
		AudioServer.add_bus()
		var idx := AudioServer.get_bus_count() - 1
		AudioServer.set_bus_name(idx, bus_name)
		AudioServer.set_bus_send(idx, "Master")


func _process(delta: float) -> void:
	if listener == null or _wind == null:
		return
	var alt01 := clampf((listener.global_position.y - 2.0) / 26.0, 0.0, 1.0)
	var gust := clampf(game.wind_strength - 0.9, 0.0, 0.45) / 0.45
	var wind_target := 0.14 + 0.14 * gust + 0.16 * alt01
	_wind_gain = _damp(_wind_gain, wind_target, 3.0, delta)
	_wind.volume_db = linear_to_db(maxf(_wind_gain, 0.0001))
	_wind_filter.cutoff_hz = lerpf(650.0, 2500.0, gust)


func on_step(spd01: float, hardness := 1.0) -> void:
	if _step_players.is_empty():
		return
	var p := _step_players[_step_rr]
	_step_rr = (_step_rr + 1) % _step_players.size()
	p.stream = _step_streams[randi() % _step_streams.size()]
	p.pitch_scale = (0.72 + randf() * 0.22) * (0.96 + 0.06 * hardness)
	p.volume_db = linear_to_db((0.035 + 0.11 * spd01) * hardness)
	p.play()


func on_land(impact01: float) -> void:
	_land.pitch_scale = 0.72 + randf() * 0.16
	_land.volume_db = linear_to_db(0.10 + 0.22 * impact01)
	_land.play()


## Шаг по песку: глухой мягкий «пшш» — песок шуршит, а не трещит.
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
		var env := minf(t / 0.016, 1.0) * exp(-t * 16.0)
		var soft := 1.0 + 0.08 * sin(TAU * sway * t + cph)
		s[i] = lp2 * env * soft * 0.34
	return _stream(s, RATE_SFX, false)


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



## Сухой импульс и короткий низкий хвост: событие громче фонового ветра.
func _gen_rifle_shot() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 91723
	var count := int(0.65 * RATE_SFX)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var low := 0.0
	for i in count:
		var t := float(i) / RATE_SFX
		var noise := rng.randf_range(-1.0, 1.0)
		low += (noise - low) * 0.08
		var crack := noise * exp(-t * 45.0) * 0.48
		var body := (low * 0.85 + sin(TAU * 72.0 * t) * 0.20) * exp(-t * 8.0)
		samples[i] = clampf(crack + body, -0.9, 0.9)
	return _stream(samples, RATE_SFX, false)


## Два коротких металлических движения затвора на фоне ветра.
func _gen_bolt() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7401
	var count := int(0.48 * RATE_SFX)
	var samples := PackedFloat32Array()
	samples.resize(count)
	for i in count:
		var t := float(i) / RATE_SFX
		var first := exp(-maxf(t - 0.04, 0.0) * 45.0) if t >= 0.04 else 0.0
		var second := exp(-maxf(t - 0.25, 0.0) * 36.0) if t >= 0.25 else 0.0
		var metallic := sin(TAU * 1400.0 * t) * 0.32 + rng.randf_range(-1.0, 1.0) * 0.42
		samples[i] = metallic * (first + second) * 0.55
	return _stream(samples, RATE_SFX, false)


## Тихий короткий тик — без фанфар за попадание.
func _gen_confirmation() -> AudioStreamWAV:
	var count := int(0.07 * RATE_SFX)
	var samples := PackedFloat32Array()
	samples.resize(count)
	for i in count:
		var t := float(i) / RATE_SFX
		samples[i] = sin(TAU * 1100.0 * t) * exp(-t * 75.0) * 0.25
	return _stream(samples, RATE_SFX, false)

## Упаковка синтезированных сэмплов в WAV.
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
