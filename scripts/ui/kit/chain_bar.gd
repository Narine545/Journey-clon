class_name TideChainBar
extends Control
## XP = якорная цепь во всю ширину: овальные звенья, заполненные — сонарь.
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
	return Vector2(maxf(10.0, step * 0.8), minf(34.0, size.y * 0.78))


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


func _oval(center: Vector2, extent: Vector2) -> PackedVector2Array:
	return TideShapes.offset(TideShapes.stadium(extent, 10), center - extent * 0.5)


## Цепь: овальные звенья анфас и короткие перемычки между ними. Заполнение
## идёт одной сплошной границей слева направо по всей длине цепи — без
## рывков и без отдельных плашек внутри звена: набранная часть звена просто
## закрашена сонарём по его же форме.
func _draw() -> void:
	var link := _link_size()
	var step := size.x / float(maxi(1, segments))
	var middle := size.y * 0.5
	var edge := progress * size.x
	# Непрозрачный «пустой» цвет: пена 38 % на чернилах. Звенья и перемычки
	# не просвечивают друг сквозь друга, стыков не видно.
	var idle := TideTokens.INK.lerp(TideTokens.FOAM, 0.38)
	var half_gap := (step - link.x) * 0.5
	for index in range(segments - 1):
		# Перемычка лежит строго в зазоре между соседними звеньями.
		var from_x := step * float(index + 1) - half_gap - 3.0
		var bar := Rect2(Vector2(from_x, middle - 3.5), Vector2(half_gap * 2.0 + 6.0, 7.0))
		draw_rect(bar, idle)
		var lit := clampf(edge - bar.position.x, 0.0, bar.size.x)
		if lit > 0.0:
			draw_rect(Rect2(bar.position, Vector2(lit, bar.size.y)), fill_color)
	var hole := Vector2(maxf(4.0, link.x - 20.0), maxf(4.0, link.y - 20.0))
	for index in range(segments):
		var center := _link_center(index)
		var shape := _oval(center, link)
		TideShapes.fill(self, shape, idle)
		for piece in TideShapes.clip_left(shape, edge):
			if piece.size() >= 3:
				draw_colored_polygon(piece, fill_color)
		# Просвет звена.
		TideShapes.fill(self, _oval(center, hole), TideTokens.INK)
		if _flash.has(index):
			var amount := clampf(float(_flash[index]) / 0.34, 0.0, 1.0)
			var burst := link + Vector2.ONE * (6.0 + (1.0 - amount) * 30.0)
			draw_polyline(_oval(center, burst), TideTokens.foam_alpha(amount), 2.0, true)
