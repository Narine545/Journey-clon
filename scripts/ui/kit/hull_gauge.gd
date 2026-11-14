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


func _rebuild() -> void:
	if _material == null or size.x < 8.0:
		return
	var points := TideShapes.hull(size)
	_water.polygon = points
	_water.uv = points
	_material.set_shader_parameter("poly_size", size)
	_material.set_shader_parameter("fill", 1.0 - hp)
	_material.set_shader_parameter("danger", 1.0 if hp < 0.25 else 0.0)
	_material.set_shader_parameter("wave_amp", 3.0 + (1.0 - hp) * 3.6)
	if _lines != null:
		_lines.queue_redraw()
	queue_redraw()


func _draw_lines() -> void:
	var points := TideShapes.hull(size)
	_lines.draw_polyline(TideShapes.closed(points), TideTokens.INK, 4.0, true)
	# Шпангоуты: поперечные рёбра корпуса, обрезанные силуэтом.
	for index in range(1, 5):
		var y := size.y * float(index) / 5.0
		var segment := PackedVector2Array([Vector2(-4.0, y), Vector2(size.x + 4.0, y)])
		for piece in Geometry2D.intersect_polyline_with_polygon(segment, points):
			if piece.size() >= 2:
				_lines.draw_line(piece[0], piece[piece.size() - 1], TideTokens.ink_alpha(0.28), 1.5, true)
	# Носовой форштевень и заклёпки по борту.
	_lines.draw_line(Vector2(size.x * 0.5, 8.0), Vector2(size.x * 0.5, size.y * 0.24), TideTokens.ink_alpha(0.35), 2.0, true)
	for index in range(6):
		var angle := PI * (0.12 + 0.76 * float(index) / 5.0)
		var at := Vector2(size.x * 0.5 - cos(angle) * size.x * 0.36, size.y * 0.5 + sin(angle) * size.y * 0.3)
		if Geometry2D.is_point_in_polygon(at, points):
			_lines.draw_circle(at, 2.4, TideTokens.ink_alpha(0.4))
