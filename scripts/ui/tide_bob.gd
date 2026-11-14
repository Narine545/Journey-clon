class_name TideBob
extends Node
## Медленная качка блока интерфейса: у каждого своя амплитуда, период и фаза.
## Крутится вокруг центра, поэтому текст остаётся на месте, а форма «дышит».

var target: Control
var base_deg := 0.0
var amplitude_deg := 0.9
var period := 2.8
var phase := 0.0
var lean_deg := 0.0
var _time := 0.0


func setup(
	control: Control, rest_deg: float, amplitude: float, cycle: float, offset: float
) -> void:
	target = control
	base_deg = rest_deg
	amplitude_deg = amplitude
	period = maxf(0.5, cycle)
	phase = offset
	process_mode = Node.PROCESS_MODE_ALWAYS
	if target != null:
		target.pivot_offset = target.size * 0.5
		target.rotation = deg_to_rad(base_deg)
		target.resized.connect(_recenter)


func _recenter() -> void:
	if is_instance_valid(target):
		target.pivot_offset = target.size * 0.5


func _process(delta: float) -> void:
	if not is_instance_valid(target):
		queue_free()
		return
	_time += delta
	var wave := sin(TAU * _time / period + phase)
	target.rotation = deg_to_rad(base_deg + lean_deg + amplitude_deg * wave)


## Мгновенно «пригнуть» блок (например, остальные флаги при наведении).
func lean(offset_deg: float, duration: float = TideTokens.HOVER_TIME) -> void:
	var tween := create_tween()
	tween.tween_property(self, "lean_deg", offset_deg, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## Прямой угол для «выпрямленного» состояния (hover).
func straighten() -> void:
	lean(0.0)
