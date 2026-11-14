class_name TideChainBar
extends Control
## XP = якорная цепь во всю ширину: гранёные звенья, заполненные — сонарь.
## При заполнении звено «отщёлкивается»: вспышка, искры, уровень +1.

signal link_filled(index: int)

@export var segments := 20
@export var fill_color: Color = TideTokens.SONAR
@export var empty_color: Color = TideTokens.foam_alpha(0.3)
@export var gap := 7.0

var progress := 0.0
var _flash := {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func set_progress(value: float) -> void:
	var clamped := clampf(value, 0.0, 1.0)
	if clamped < progress:
		# Сброс на новый уровень: цепь начинает набираться заново.
		_flash.clear()
	progress = clamped
	queue_redraw()


func set_values(current: float, needed: float) -> void:
	set_progress(current / maxf(1.0, needed))


## Вспышка конкретного звена + искры: вызывается при «отщёлкивании».
func snap(index: int) -> void:
	_flash[index] = 0.34
	TideFx.sparks(get_parent(), position + _link_center(index), 12)
	link_filled.emit(index)
	queue_redraw()


func _link_size() -> Vector2:
	var step := size.x / float(maxi(1, segments))
	return Vector2(maxf(10.0, step * 0.74), minf(36.0, size.y * 0.82))


func _link_center(index: int) -> Vector2:
	var step := size.x / float(maxi(1, segments))
	return Vector2(step * (float(index) + 0.5), size.y * 0.5)


func _process(delta: float) -> void:
	if _flash.is_empty():
		return
	for key in _flash.keys():
		_flash[key] = float(_flash[key]) - delta
		if float(_flash[key]) <= 0.0:
			_flash.erase(key)
	queue_redraw()


func _shape_at(center: Vector2, extent: Vector2, chamfer: float) -> PackedVector2Array:
	return TideShapes.offset(TideShapes.link(extent, chamfer), center - extent * 0.5)


## Цепь: звенья анфас (гранёные, со срезанными углами) чередуются с
## перемычками-звеньями «в профиль». Набранные — плотный сонарь.
func _draw() -> void:
	var link := _link_size()
	var chamfer := link.y * 0.32
	var step := size.x / float(maxi(1, segments))
	var total := progress * float(segments)
	var middle := size.y * 0.5
	# Перемычки под звеньями.
	for index in range(segments + 1):
		var x := step * float(index)
		var lit := total >= float(index) and index > 0
		var bar := Rect2(Vector2(x - step * 0.2, middle - 4.0), Vector2(step * 0.4, 8.0))
		draw_rect(bar, fill_color if lit else empty_color)
	for index in range(segments):
		var center := _link_center(index)
		var filled := clampf(total - float(index), 0.0, 1.0)
		var shape := _shape_at(center, link, chamfer)
		if filled >= 1.0:
			TideShapes.fill(self, shape, fill_color)
			# Прорезь звена.
			var slot := Vector2(link.x - 22.0, 6.0)
			if slot.x > 6.0:
				draw_rect(Rect2(center - slot * 0.5, slot), TideTokens.INK)
		else:
			TideShapes.fill(self, shape, TideTokens.ink_alpha(0.6))
			TideShapes.stroke(self, shape, empty_color, 3.0)
			if filled > 0.0:
				# Звено набирается: плашка сонаря растёт слева направо.
				var room := link - Vector2(12.0, 12.0)
				draw_rect(
					Rect2(center - room * 0.5, Vector2(room.x * filled, room.y)), fill_color
				)
		if _flash.has(index):
			var amount := clampf(float(_flash[index]) / 0.34, 0.0, 1.0)
			TideShapes.fill(self, shape, TideTokens.foam_alpha(0.85 * amount))
			var burst := link + Vector2.ONE * (8.0 + (1.0 - amount) * 30.0)
			TideShapes.stroke(self, _shape_at(center, burst, chamfer), TideTokens.foam_alpha(amount), 2.0)
