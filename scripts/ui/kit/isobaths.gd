class_name TideIsobaths
extends ColorRect
## Фоновая текстура глубины: тонкие контуры изобат, шаг 28–40 px, alpha 6 %.
## Это canvas_item-шейдер, а не картинка и не полутоновая сетка.

const SHADER := preload("res://shaders/isobaths.gdshader")

@export var step_px := 34.0
@export var line_alpha := 0.06
@export var line_color: Color = TideTokens.FOAM
@export var drift := 0.3


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	color = Color(1.0, 1.0, 1.0, 1.0)
	var lines := ShaderMaterial.new()
	lines.shader = SHADER
	lines.set_shader_parameter("line_color", Color(line_color, line_alpha))
	lines.set_shader_parameter("step_px", step_px)
	lines.set_shader_parameter("drift", drift)
	lines.set_shader_parameter("field_size", size)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	material = lines
	resized.connect(_sync)
	_sync()


func _sync() -> void:
	if material is ShaderMaterial:
		(material as ShaderMaterial).set_shader_parameter("field_size", size)
