extends Node
## Тихие отклики интерфейса — пока ровно один: короткий «кап» на нажатие
## кнопки. Синтез кодом при запуске, как и всё остальное в проекте:
## бинарных ассетов нет.
##
## Автозагрузка `UiSound`: интерфейс живёт в разных сценах, а звук должен
## переживать смену экрана. Громкость намеренно низкая — отклик, а не событие.


const RATE := 22050
## Общая громкость отклика. Один кап слышно, десять подряд — нет.
const VOLUME_DB := -15.0

var _tap: AudioStreamPlayer
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_tap = AudioStreamPlayer.new()
	_tap.stream = _gen_tap()
	_tap.volume_db = VOLUME_DB
	add_child(_tap)


## Нажатие кнопки: короткий мягкий кап с лёгким сдвигом высоты, чтобы
## серия нажатий не звучала как один и тот же щелчок.
func tap() -> void:
	if _tap == null:
		return
	_tap.pitch_scale = _rng.randf_range(0.97, 1.05)
	_tap.play()


## Кап: короткий синус с уходом вниз плюс приглушённый шумовой щелчок.
## Ни резкой атаки, ни высоких частот — на слух это «капля», не «клик».
func _gen_tap() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2609
	var n := int(0.075 * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		var w := rng.randf_range(-1.0, 1.0)
		lp += (w - lp) * 0.30
		var env := minf(t / 0.0025, 1.0) * exp(-t * 68.0)
		var blip := sin(TAU * (760.0 - 300.0 * t) * t) * 0.55
		s[i] = (blip + lp * 0.30) * env
	return _stream(s, RATE)


func _stream(s: PackedFloat32Array, rate: int) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(s.size() * 2)
	for i in s.size():
		data.encode_s16(i * 2, int(clampf(s[i], -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = data
	return wav
