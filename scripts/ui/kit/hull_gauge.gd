class_name TideHullGauge
extends Control
## HP = осадка корпуса. Силуэт лодки, вода поднимается по корпусу,
## на ватерлинии — пенная кромка. При HP < 25 % вода пульсирует flare.

const SHADER := preload("res://shaders/water_fill.gdshader")

var hp := 1.0
var _water: Polygon2D
var _material: ShaderMaterial
var _lines: Control


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_water = Polygon2D.new()
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_water.material = _material
	add_child(_water)
	_lines = Control.new()
	_lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lines.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_lines.draw.connect(_draw_lines)
	add_child(_lines)
	resized.connect(_rebuild)
	_rebuild()


func set_hp(value: float) -> void:
	var clamped := clampf(value, 0.0, 1.0)
	if is_equal_approx(clamped, hp):
		return
	hp = clamped
	_rebuild()


func set_danger(active: bool) -> void:
	if _material != null:
		_material.set_shader_parameter("danger", 1.0 if active else 0.0)


## Правая полоса под мерную рейку осадки.
const RULER_W := 70.0


func hull_size() -> Vector2:
	return Vector2(maxf(40.0, size.x - RULER_W), size.y)


func _rebuild() -> void:
	if _material == null or size.x < 8.0:
		return
	var extent := hull_size()
	var points := TideShapes.hull_side(extent)
	_water.polygon = points
	_material.set_shader_parameter("poly_size", extent)
	_material.set_shader_parameter("fill", 1.0 - hp)
	_material.set_shader_parameter("danger", 1.0 if hp < 0.25 else 0.0)
	_material.set_shader_parameter("wave_amp", 2.5 + (1.0 - hp) * 3.0)
	if _lines != null:
		_lines.queue_redraw()


## Уровень воды (y) для запаса корпуса value (0…1) — та же формула, что в шейдере.
func _level_y(value: float) -> float:
	return lerpf(size.y - 4.0, 4.0, 1.0 - value)


func _draw_lines() -> void:
	var extent := hull_size()
	var points := TideShapes.hull_side(extent)
	_lines.draw_polyline(TideShapes.closed(points), TideTokens.FOAM, 3.0, true)
	# Иллюминаторы рубки и привальный брус.
	for index in range(2):
		var at := Vector2(extent.x * (0.30 + 0.12 * float(index)), extent.y * 0.31)
		_lines.draw_rect(Rect2(at - Vector2(7.0, 7.0), Vector2(14.0, 14.0)), TideTokens.FOAM)
	_lines.draw_line(
		Vector2(extent.x * 0.05, extent.y * 0.56), Vector2(extent.x * 0.94, extent.y * 0.56),
		TideTokens.foam_alpha(0.4), 2.0, true
	)
	# Мерная рейка осадки: 75 / 50 / 25, нижняя отметка — аварийная.
	var font := TideTokens.mono_font()
	var x := extent.x + 16.0
	_lines.draw_line(Vector2(x, _level_y(1.0)), Vector2(x, _level_y(0.0)), TideTokens.foam_alpha(0.45), 2.0)
	for mark in [75, 50, 25]:
		var y := _level_y(float(mark) / 100.0)
		var tint: Color = TideTokens.FLARE if mark == 25 else TideTokens.foam_alpha(0.7)
		_lines.draw_line(Vector2(x, y), Vector2(x + 12.0, y), tint, 3.0 if mark == 25 else 2.0)
		_lines.draw_string(font, Vector2(x + 18.0, y + 5.0), str(mark), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, tint)
