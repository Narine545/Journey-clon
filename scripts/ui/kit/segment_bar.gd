class_name TideSegmentBar
extends Control
## Полоса-протокол: не прогрессбар, а ряд плоских марок.
## Используется для прочности крупной цели.

@export var segments := 12
@export var tint: Color = TideTokens.FLARE
@export var empty_color: Color = TideTokens.foam_alpha(0.18)
@export var gap := 4.0

var ratio := 1.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func set_ratio(value: float) -> void:
	var clamped := clampf(value, 0.0, 1.0)
	if is_equal_approx(clamped, ratio):
		return
	ratio = clamped
	queue_redraw()


func _draw() -> void:
	if size.x < 8.0:
		return
	var step := (size.x - gap * float(segments - 1)) / float(segments)
	var filled := ratio * float(segments)
	for index in range(segments):
		var x := float(index) * (step + gap)
		var amount := clampf(filled - float(index), 0.0, 1.0)
		var rect := Rect2(Vector2(x, 0.0), Vector2(step, size.y))
		draw_rect(rect, empty_color)
		if amount > 0.0:
			draw_rect(Rect2(rect.position, Vector2(step * amount, size.y)), tint)
