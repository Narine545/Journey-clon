class_name ShadowStars
extends CanvasLayer
## Ночной процедурный слой звёзд: luminance mask по экрану + анимация
## многослойных звёзд. Не использует bitmap/star map.

var _mat: ShaderMaterial


func setup() -> void:
	layer = 9 # после 3D, до виньетки/HUD/колор-грейда
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://shaders/shadow_stars.gdshader")
	var rect := ColorRect.new()
	rect.material = _mat
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)
	set_night(0.0)


func set_night(value: float) -> void:
	if _mat != null:
		_mat.set_shader_parameter("night_amount", clampf(value, 0.0, 1.0))


func set_param(name: String, value: float) -> void:
	if _mat != null:
		_mat.set_shader_parameter(name, value)
