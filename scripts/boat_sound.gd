class_name BoatSound
extends Node
## Звуки моря в сцене лодки. Всё синтезируется кодом при запуске —
## бинарных звуковых ассетов в проекте нет, как и на берегу.
##
## Набор намеренно скупой: всплеск, глухой «буль» под водой и свист взлёта.
## Никаких резких тембров и громких атак: звук поддерживает картинку,
## а не спорит с ней. Фоновых петель нет — только события.

const RATE := 22050

var _splash: AudioStreamPlayer3D
var _glug: AudioStreamPlayer3D
var _rise: AudioStreamPlayer3D
var _rng := RandomNumberGenerator.new()


func setup() -> void:
	_rng.randomize()
	_splash = _player3d(_gen_splash(), -7.0, 70.0)
	_glug = _player3d(_gen_glug(), -6.0, 60.0)
	_rise = _player3d(_gen_rise(), -9.0, 95.0)


## Всплеск: вход в воду (вниз) или выход из неё (вверх).
func splash(at_world: Vector3, strength := 1.0) -> void:
	_splash.global_position = at_world
	_splash.pitch_scale = _rng.randf_range(0.90, 1.05)
	_splash.volume_db = lerpf(-11.0, -6.0, clampf(strength, 0.0, 1.0))
	_splash.play()


## Глухой «буль» под водой: сфера ушла под поверхность.
func glug(at_world: Vector3) -> void:
	_glug.global_position = at_world
	_glug.pitch_scale = _rng.randf_range(0.85, 1.0)
	_glug.play()


## Взлёт: короткий свист вверх, когда сфера вырывается из воды.
func rise(at_world: Vector3) -> void:
	_rise.global_position = at_world
	_rise.pitch_scale = _rng.randf_range(0.94, 1.02)
	_rise.play()


func _player3d(stream: AudioStreamWAV, db: float, distance: float) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.stream = stream
	p.volume_db = db
	p.max_distance = distance
	p.unit_size = 16.0
	p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	add_child(p)
	return p


## Всплеск: шумовая полоса, которая на глазах съезжает вниз, плюс шлепок
## и низкий удар воды. Резкая атака — но короткая и мягкая по тембру.
func _gen_splash() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5177
	var n := int(1.05 * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var lp := 0.0
	var lp2 := 0.0
	for i in n:
		var t := float(i) / RATE
		var w := rng.randf_range(-1.0, 1.0)
		lp += (w - lp) * lerpf(0.55, 0.05, minf(t / 0.45, 1.0))
		lp2 += (lp - lp2) * 0.25
		var env := minf(t / 0.006, 1.0) * pow(maxf(1.0 - t, 0.0), 2.0)
		var slap := sin(TAU * (240.0 - 200.0 * t) * t) * exp(-t * 9.0) * 0.40
		var thump := sin(TAU * 68.0 * t) * exp(-t * 6.5) * 0.35
		s[i] = (lp2 * 1.5 + slap + thump) * env
	return _stream(_peak_norm(s, 0.9), RATE, false)


## Под водой: приглушённый нисходящий тон и несколько пузырьков.
func _gen_glug() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3391
	var n := int(1.15 * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var lp := 0.0
	var bubbles: Array[Vector3] = []
	for index in range(6):
		bubbles.append(
			Vector3(
				rng.randf_range(0.06, 0.80),
				rng.randf_range(320.0, 720.0),
				rng.randf_range(0.22, 0.42)
			)
		)
	for i in n:
		var t := float(i) / RATE
		var w := rng.randf_range(-1.0, 1.0)
		lp += (w - lp) * 0.10
		var env := minf(t / 0.03, 1.0) * exp(-t * 2.4)
		env *= 1.0 - smoothstep(0.85, 1.15, t)
		# Тон уходит вниз, но остаётся в слышимой середине: 430 → 180 Гц.
		# Прежний вариант жил на 60–170 Гц и на обычных динамиках пропадал.
		var tone := sin(TAU * (430.0 - 250.0 * t) * t) * 0.40
		var value := (tone + lp * 0.30) * env
		for bubble: Vector3 in bubbles:
			var bt := t - bubble.x
			if bt < 0.0 or bt > 0.55:
				continue
			value += sin(TAU * bubble.y * bt) * exp(-bt * 11.0) * bubble.z * 0.34
		s[i] = value
	return _stream(_peak_norm(s, 0.8), RATE, false)


## Взлёт: шум и тон, ползущие вверх — «свист в небо», но без резкости.
func _gen_rise() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 8849
	var n := int(1.25 * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var lp := 0.0
	var phase := 0.0
	for i in n:
		var t := float(i) / RATE
		var tt := minf(t / 1.25, 1.0)
		var w := rng.randf_range(-1.0, 1.0)
		lp += (w - lp) * lerpf(0.02, 0.30, tt * tt)
		phase += TAU * lerpf(85.0, 520.0, tt) / RATE
		var env := minf(t / 0.22, 1.0) * pow(maxf(1.0 - tt, 0.0), 1.3)
		s[i] = (lp * 1.1 + sin(phase) * 0.30) * env
	return _stream(_peak_norm(s, 0.8), RATE, false)


func _peak_norm(s: PackedFloat32Array, target: float) -> PackedFloat32Array:
	var peak := 0.0001
	for i in s.size():
		peak = maxf(peak, absf(s[i]))
	for i in s.size():
		s[i] = s[i] / peak * target
	return s


func _stream(s: PackedFloat32Array, rate: int, loop: bool) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(s.size() * 2)
	for i in s.size():
		data.encode_s16(i * 2, int(clampf(s[i], -1.0, 1.0) * 32767.0))
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
