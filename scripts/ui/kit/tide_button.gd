class_name TideButton
extends Button
## Кнопка-плашка со срезанными углами. Hover: сдвиг 4 px и усиление skew,
## нажатие: scale 0.93 на 0.06 с и отскок TRANS_BACK.

enum Shape { SOLID, OUTLINE, GHOST }

@export var variant := Shape.SOLID
@export var tint := TideTokens.SONAR
@export var label_color := TideTokens.INK
@export var font_kind := 0 # 0 — Unbounded Black, 1 — JetBrains Mono, 2 — Oswald
@export var point_size := 30
@export var skew := 14.0
@export var cut := 12.0

var caption: Label
var _hover := 0.0
var _tween: Tween


func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	caption = Label.new()
	caption.name = "Caption"
	caption.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption.add_theme_color_override("font_color", label_color)
	match font_kind:
		1:
			TideTokens.style_mono(caption, point_size, label_color)
		2:
			TideTokens.style_body(caption, point_size, label_color)
		_:
			TideTokens.style_title(caption, point_size, label_color, 0)
	add_child(caption)
	mouse_entered.connect(_set_hover.bind(1.0))
	mouse_exited.connect(_set_hover.bind(0.0))
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
	button_down.connect(_on_down)
	button_up.connect(queue_redraw)
	resized.connect(queue_redraw)


func set_caption(text: String, color: Color = Color(0, 0, 0, 0)) -> void:
	if caption == null:
		return
	caption.text = text
	if color.a > 0.001:
		caption.add_theme_color_override("font_color", color)


func _set_hover(value: float) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_method(_apply_hover, _hover, value, TideTokens.HOVER_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _apply_hover(value: float) -> void:
	_hover = value
	if caption != null:
		caption.position = Vector2(0.0, 4.0 * value)
	queue_redraw()


func _on_down() -> void:
	TideFx.press(self)
	queue_redraw()


func _draw() -> void:
	var shape := TideShapes.plate(size, skew * (1.0 + 0.35 * _hover), cut)
	var alpha := 0.45 if disabled else 1.0
	match variant:
		Shape.SOLID:
			TideShapes.fill(self, shape, Color(tint, alpha))
		Shape.OUTLINE:
			TideShapes.stroke(self, shape, Color(tint, alpha), 4.0)
		_:
			TideShapes.fill(self, shape, Color(TideTokens.DEEP, alpha))
			TideShapes.stroke(self, shape, Color(TideTokens.foam_alpha(0.25), alpha), 2.0)
	# Уголок-зацепка: подчёркивает направление движения плашки.
	var edge := TideShapes.plate(size, skew * (1.0 + 0.35 * _hover), cut)
	var accent := Color(tint, alpha) if variant != Shape.SOLID else Color(TideTokens.INK, 0.55)
	draw_line(edge[3], edge[2], accent, 3.0, true)
	if has_focus():
		var focus_shape := PackedVector2Array()
		for point in shape:
			focus_shape.append(point + (size * 0.5 - point).normalized() * 5.0)
		draw_polyline(TideShapes.closed(focus_shape), TideTokens.foam_alpha(0.55), 1.5, true)
