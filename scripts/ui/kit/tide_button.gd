class_name TideButton
extends Button
## Кнопка-плашка со срезанными углами. Hover: сдвиг 4 px и усиление skew,
## нажатие: scale 0.93 на 0.06 с и отскок TRANS_BACK.

enum Shape { SOLID, OUTLINE, GHOST, PENNANT }

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
	resized.connect(_fit_caption)


func set_caption(text: String, color: Color = Color(0, 0, 0, 0)) -> void:
	if caption == null:
		return
	caption.text = text
	if color.a > 0.001:
		caption.add_theme_color_override("font_color", color)
	_fit_caption()


## Подпись ужимается под плашку: текст не выходит за скошенные края.
func _fit_caption() -> void:
	if caption == null or size.x < 8.0:
		return
	var font := TideTokens.title_font()
	if font_kind == 1:
		font = TideTokens.mono_font()
	elif font_kind == 2:
		font = TideTokens.body_font()
	var room := size.x - (skew + cut) * 2.0 - 28.0 - _tail()
	var point := TideTokens.fit_point(font, caption.text, room, point_size, 10)
	point = mini(point, int(size.y * 0.62))
	caption.add_theme_font_size_override("font_size", point)
	caption.offset_right = -_tail()


func _tail() -> float:
	return size.y * 0.42 if variant == Shape.PENNANT else 0.0


func _outline_points() -> PackedVector2Array:
	var lean := skew * (1.0 + 0.35 * _hover)
	if variant != Shape.PENNANT:
		return TideShapes.plate(size, lean, cut)
	# Вымпел: скошенная плашка с вырезом «ласточкин хвост» на свободном конце.
	return PackedVector2Array(
		[
			Vector2(lean + cut, 0.0),
			Vector2(size.x + lean, 0.0),
			Vector2(size.x - _tail(), size.y * 0.5),
			Vector2(size.x - lean, size.y),
			Vector2(-lean - cut, size.y),
		]
	)


func _set_hover(value: float) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_method(_apply_hover, _hover, value, TideTokens.HOVER_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _apply_hover(value: float) -> void:
	_hover = value
	if caption != null:
		caption.position = Vector2(4.0 * value, 0.0)
	queue_redraw()


func _on_down() -> void:
	TideFx.press(self)
	queue_redraw()


func _draw() -> void:
	var shape := _outline_points()
	var alpha := 0.45 if disabled else 1.0
	match variant:
		Shape.SOLID, Shape.PENNANT:
			# Оттиск-подложка: плоский сдвинутый силуэт, сдвиг растёт на hover.
			var lift := 6.0 + 4.0 * _hover
			TideShapes.fill(self, TideShapes.offset(shape, Vector2(lift, lift)), TideTokens.ink_alpha(0.7 * alpha))
			TideShapes.fill(self, shape, Color(tint, alpha))
		Shape.OUTLINE:
			TideShapes.fill(self, shape, TideTokens.ink_alpha(0.55 * alpha))
			TideShapes.stroke(self, shape, Color(tint, alpha), 4.0)
		_:
			TideShapes.fill(self, shape, TideTokens.ink_alpha(0.5 * alpha))
			TideShapes.stroke(self, shape, Color(tint.r, tint.g, tint.b, tint.a * alpha), 2.5)
	if has_focus():
		var focus_shape := PackedVector2Array()
		for point in shape:
			focus_shape.append(point + (point - size * 0.5).normalized() * 7.0)
		draw_polyline(TideShapes.closed(focus_shape), TideTokens.foam_alpha(0.55), 2.0, true)
