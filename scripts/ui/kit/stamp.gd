class_name TideStamp
extends Control
## Резиновый штамп: рамка, капс, поворот −12°, alpha 85 %.
## Используется минимум на двух экранах: «ЗАЧТЕНО», «ПОВЫШЕНИЕ», «SOS».

@export var text := "ЗАЧТЕНО":
	set(value):
		text = value
		_refresh()
@export var tint := TideTokens.FLARE:
	set(value):
		tint = value
		_refresh()
@export var point_size := 38:
	set(value):
		point_size = value
		_refresh()


func _refresh() -> void:
	if is_inside_tree():
		queue_redraw()
@export var rest_deg := -12.0
@export var framed := true
@export var opacity := 0.85


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	rotation = deg_to_rad(rest_deg)
	pivot_offset = size * 0.5
	modulate = Color(1.0, 1.0, 1.0, opacity)
	resized.connect(func() -> void: pivot_offset = size * 0.5)


func _draw() -> void:
	var pad := 14.0
	if framed:
		# Двойная рамка с «непропечатками» — как настоящий резиновый штамп.
		var outer := Rect2(Vector2(pad, pad), size - Vector2(pad, pad) * 2.0)
		draw_rect(outer, tint, false, 3.0)
		var inner := outer.grow(-7.0)
		draw_rect(inner, tint, false, 1.5)
		for corner in [inner.position, inner.position + Vector2(inner.size.x, 0.0)]:
			draw_circle(corner, 2.0, tint)
	var font := TideTokens.title_font()
	var baseline := size.y * 0.5 + float(point_size) * 0.34
	draw_string(
		font,
		Vector2(0.0, baseline),
		text,
		HORIZONTAL_ALIGNMENT_CENTER,
		size.x,
		point_size,
		tint
	)


## Удар штампа: scale 1.9 → 1.0 с overshoot, плюс брызги вокруг.
func hit(parent: Node = null) -> void:
	show()
	modulate = Color(1.0, 1.0, 1.0, opacity)
	scale = Vector2(1.9, 1.9)
	rotation = deg_to_rad(rest_deg - 7.0)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2.ONE, TideTokens.STAMP_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "rotation", deg_to_rad(rest_deg), TideTokens.STAMP_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var host: Node = parent if parent != null else get_parent()
	if host != null:
		TideFx.splash(host, position + size * 0.5, 10, tint)
