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
