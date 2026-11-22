class_name GiltStyle
extends CanvasLayer
## Слой стиля «Золочёный прилив» поверх кадра: vaporwave × gothic.
##
## Отдельный CanvasLayer НИЖЕ HUD (слой 11): бумажные плашки TIDECUT
## остаются бумагой, неон достаётся только миру. Слой живёт между
## ColorGrader (в сцене берега) и HUD и работает полным экраном.
##
## Три числа, которые что-то значат:
##   • intensity — сила всего слоя (0 = просто исходный кадр);
##   • night01   — баланс «золото ↔ неон», едет вместе с временем суток;
##   • structure — виньет-арка, аберрация, зерно.
##
## Выключается целиком (visible = false) — например, для фото-режима,
## если игрок хочет чистый кадр.

const SHADER := "res://shaders/gilt_style.gdshader"

var intensity := 0.55
var structure := 0.5
var night01 := 0.0
var enabled := true

var _rect: ColorRect
var _material: ShaderMaterial
var _time := 0.0


func setup() -> void:
	layer = 11
	name = "GiltStyle"
	_rect = ColorRect.new()
	_rect.name = "GiltStylePass"
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_material = ShaderMaterial.new()
	_material.shader = load(SHADER)
	_rect.material = _material
	add_child(_rect)
	_apply()


func set_intensity(value: float) -> void:
	intensity = clampf(value, 0.0, 1.0)
	_apply()


func set_structure(value: float) -> void:
	structure = clampf(value, 0.0, 1.0)
	_apply()


## Ночь двигает баланс: золото уходит, неон разгорается. Сила при этом
## слегка растёт — вечером стиль должен читаться сильнее, чем в полдень.
func set_night(amount: float) -> void:
	night01 = clampf(amount, 0.0, 1.0)
	_apply()


func set_enabled(value: bool) -> void:
	enabled = value
	visible = value


func _apply() -> void:
	if _material == null:
		return
	_material.set_shader_parameter("intensity", intensity)
	_material.set_shader_parameter("structure", structure)
	_material.set_shader_parameter("night01", night01)


func _process(delta: float) -> void:
	if not enabled:
		return
	_time += delta
