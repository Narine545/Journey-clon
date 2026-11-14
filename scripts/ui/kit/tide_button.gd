class_name TideButton
extends Button
## Кнопка-плашка со срезанными углами.
## Hover: сдвиг 4 px, усиление skew, плашка приподнимается над оттиском.
## Нажатие: плашка вдавливается в свой оттиск (scale 0.93, 0.06 с).
## Отпускание: отскок TRANS_BACK с рывком поворота, пенная вспышка по форме,
## расходящийся контур-«кильватер» и брызги из-под нижней кромки.

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
var _sink := 0.0 # 0 — отпущена, 1 — вдавлена в оттиск
var _flash := 0.0 # пенная вспышка по форме плашки
var _wake := 1.0 # 0→1: контур расходится и гаснет
var _fx: Tween
var _rest := 0.0


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
	button_up.connect(_on_up)
	resized.connect(queue_redraw)
	resized.connect(_fit_caption)


func set_caption(value: String, color: Color = Color(0, 0, 0, 0)) -> void:
	if caption == null:
		return
	caption.text = value
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
		caption.position = Vector2(4.0 * value + 5.0 * _sink, 5.0 * _sink)
	queue_redraw()


func _set_sink(value: float) -> void:
	_sink = value
	if caption != null:
		caption.position = Vector2(4.0 * _hover + 5.0 * value, 5.0 * value)
	queue_redraw()


func _set_flash(value: float) -> void:
	_flash = value
	queue_redraw()


func _set_wake(value: float) -> void:
	_wake = value
	queue_redraw()


func _restart_fx() -> Tween:
	if _fx != null and _fx.is_valid():
		_fx.kill()
	_fx = create_tween()
	_fx.set_parallel(true)
	return _fx


func _on_down() -> void:
	if disabled:
		return
	pivot_offset = size * 0.5
	if _fx == null or not _fx.is_running():
		_rest = rotation
	var tween := _restart_fx()
	tween.tween_method(_set_sink, _sink, 1.0, TideTokens.PRESS_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2(0.93, 0.93), TideTokens.PRESS_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _on_up() -> void:
	if disabled:
		return
	var kick := deg_to_rad(-2.5 if (get_index() % 2) == 0 else 2.5)
	var rest := _rest
	rotation = rest + kick
	_flash = 1.0
	_wake = 0.0
	var tween := _restart_fx()
	tween.tween_method(_set_sink, _sink, 0.0, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "rotation", rest, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_method(_set_flash, 1.0, 0.0, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_method(_set_wake, 0.0, 1.0, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if is_inside_tree() and get_parent() != null and size.x > 60.0:
		var count := 14 if variant in [Shape.SOLID, Shape.PENNANT] else 8
		var origin := position + Vector2(size.x * 0.5, size.y).rotated(rotation)
		TideFx.splash(get_parent(), origin, count, TideTokens.FOAM)


func _draw() -> void:
	var base_shape := _outline_points()
	var alpha := 0.45 if disabled else 1.0
	# Вдавливание: плашка съезжает на свой оттиск.
	var lift := (6.0 + 4.0 * _hover) * (1.0 - _sink)
	var sunk := (6.0 + 4.0 * _hover) * _sink
	var shape := TideShapes.offset(base_shape, Vector2(sunk, sunk))
	match variant:
		Shape.SOLID, Shape.PENNANT:
			# Оттиск-подложка: плоский сдвинутый силуэт, сдвиг растёт на hover.
			if lift > 0.5:
				TideShapes.fill(self, TideShapes.offset(shape, Vector2(lift, lift)), TideTokens.ink_alpha(0.7 * alpha))
			TideShapes.fill(self, shape, Color(tint, alpha))
		Shape.OUTLINE:
			TideShapes.fill(self, shape, TideTokens.ink_alpha(0.55 * alpha))
			TideShapes.stroke(self, shape, Color(tint, alpha), 4.0)
		_:
			TideShapes.fill(self, shape, TideTokens.ink_alpha(0.5 * alpha))
			TideShapes.stroke(self, shape, Color(tint.r, tint.g, tint.b, tint.a * alpha), 2.5)
	if _flash > 0.01:
		draw_colored_polygon(shape, TideTokens.foam_alpha(0.85 * _flash))
	if _wake < 0.99:
		var ring := PackedVector2Array()
		var spread := 6.0 + 26.0 * _wake
		for point in base_shape:
			ring.append(point + (point - size * 0.5).normalized() * spread)
		draw_polyline(
			TideShapes.closed(ring), Color(tint.r, tint.g, tint.b, (1.0 - _wake) * alpha),
			maxf(1.0, 5.0 * (1.0 - _wake)), true
		)
	if has_focus():
		var focus_shape := PackedVector2Array()
		for point in shape:
			focus_shape.append(point + (point - size * 0.5).normalized() * 7.0)
		draw_polyline(TideShapes.closed(focus_shape), TideTokens.foam_alpha(0.55), 2.0, true)
