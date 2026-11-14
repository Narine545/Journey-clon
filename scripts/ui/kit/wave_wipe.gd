class_name TideWaveWipe
extends Control
## Переход между экранами: маска с «зубцами волны», 0.30–0.40 с.
## Экран не растворяется — его накрывает гребень с регулярными зубцами.

const SHADER := preload("res://shaders/wave_wipe.gdshader")

signal covered

var progress := 0.0
var _material: ShaderMaterial
var _rect: ColorRect


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rect = ColorRect.new()
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_material.set_shader_parameter("progress", 0.0)
	_rect.material = _material
	add_child(_rect)
	progress = 0.0
	visible = false


func _apply(value: float) -> void:
	progress = value
	_material.set_shader_parameter("progress", value)


## Накрыть экран и выполнить действие в момент полного закрытия.
func cover_then(action: Callable, duration: float = TideTokens.WIPE_TIME * 0.5) -> void:
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	var tween := create_tween()
	tween.tween_method(_apply, progress, 1.0, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_callback(action)
	covered.emit()


## Открыть новую сцену из-под гребня.
func reveal(duration: float = TideTokens.WIPE_TIME * 0.5) -> void:
	visible = true
	var tween := create_tween()
	tween.tween_method(_apply, progress, 0.0, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_callback(_finish)
	covered.emit()


func _finish() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
