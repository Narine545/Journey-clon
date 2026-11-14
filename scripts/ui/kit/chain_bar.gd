class_name TideChainBar
extends Control
## XP = якорная цепь во всю ширину: звенья-стадионы, заполненные — сонарь.
## При заполнении звено «отщёлкивается»: вспышка, искры, уровень +1.

signal link_filled(index: int)

@export var segments := 16
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
	return Vector2(maxf(10.0, step - gap), minf(34.0, size.y * 0.72))


func _link_center(index: int) -> Vector2:
	var step := size.x / float(maxi(1, segments))
	return Vector2(step * (float(index) + 0.5), size.y * 0.5)


func _process(delta: float) -> void:
	if _flash.is_empty():
		return
	var dirty := false
	for key in _flash.keys():
		_flash[key] = float(_flash[key]) - delta
		if float(_flash[key]) <= 0.0:
			_flash.erase(key)
		dirty = true
	if dirty:
		queue_redraw()


func _draw() -> void:
	var link := _link_size()
	var radius := link.y * 0.5
	var step := size.x / float(maxi(1, segments))
	var total := progress * float(segments)
	for index in range(segments):
		var center := Vector2(step * (float(index) + 0.5), size.y * 0.5)
		var filled := clampf(total - float(index), 0.0, 1.0)
		var rect := Rect2(center - link * 0.5, link)
		# Пустое звено: контур пены 30 %.
		var outline := PackedVector2Array()
		if filled <= 0.0:
			for point in TideShapes.stadium(link):
				outline.append(rect.position + point)
			draw_polyline(TideShapes.closed(outline), empty_color, 3.0, true)
			continue
		# Заполненное (или частично) звено — плотный сонарь.
		var part := rect
		part.size.x = maxf(radius * 2.0, rect.size.x * filled)
		var shape := PackedVector2Array()
		for point in TideShapes.stadium(part.size):
			shape.append(part.position + point)
		TideShapes.fill(self, shape, fill_color)
		var inner := PackedVector2Array()
		var inset := 5.0
		for point in TideShapes.stadium(part.size - Vector2(inset, inset) * 2.0):
			inner.append(part.position + Vector2(inset, inset) + point)
		draw_polyline(TideShapes.closed(inner), TideTokens.ink_alpha(0.55), 2.0, true)
		if _flash.has(index):
			var amount := clampf(float(_flash[index]) / 0.34, 0.0, 1.0)
			TideShapes.fill(self, shape, TideTokens.foam_alpha(0.8 * amount))
			var burst := 10.0 + (1.0 - amount) * 26.0
			draw_arc(center, link.y * 0.5 + burst, 0.0, TAU, 24, TideTokens.foam_alpha(amount), 2.0, true)
	# Якорное кольцо слева и подпись справа.
	draw_circle(Vector2(-16.0, size.y * 0.5), 8.0, TideTokens.foam_alpha(0.35))
	draw_circle(Vector2(-16.0, size.y * 0.5), 4.0, TideTokens.INK)
