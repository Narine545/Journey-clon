class_name RaidUpgradeCard
extends Button
## Original cut-paper choice. Native Button input/focus, no animated hit target.
var caption: Label
var heading: Label
var description: Label
var effect: Label
var _margin: MarginContainer


func _init() -> void:
	custom_minimum_size = Vector2(0, 280)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	_margin = MarginContainer.new()
	_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_margin.add_theme_constant_override("margin_left", 20)
	_margin.add_theme_constant_override("margin_right", 20)
	_margin.add_theme_constant_override("margin_top", 20)
	_margin.add_theme_constant_override("margin_bottom", 20)
	add_child(_margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	_margin.add_child(column)
	caption = _label(column, 12, Color("b63a2f"))
	heading = _label(column, 25, Color("111619"))
	description = _label(column, 16, Color("454846"))
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(spacer)
	effect = _label(column, 19, Color("111619"))
	_ignore_mouse(_margin)
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
	resized.connect(queue_redraw)
	_margin.minimum_size_changed.connect(_sync_minimum, CONNECT_DEFERRED)


func _label(parent: Node, font_size: int, ink: Color) -> Label:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", ink)
	parent.add_child(label)
	return label


func _ignore_mouse(node: Control) -> void:
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		if child is Control:
			_ignore_mouse(child)


func _sync_minimum() -> void:
	custom_minimum_size.y = maxf(280.0, _margin.get_combined_minimum_size().y + 8.0)


func set_content(
	order: int, name_text: String, explanation: String, values: String, evolution: bool
) -> void:
	caption.text = "%02d / %s" % [order + 1, "ЭВОЛЮЦИЯ" if evolution else "МОДУЛЬ СБОРКИ"]
	heading.text = name_text
	description.text = explanation
	effect.text = values
	tooltip_text = "%s\n%s\n%s" % [name_text, explanation, values]
	_sync_minimum.call_deferred()
	queue_redraw()


func _draw() -> void:
	var active := is_hovered() or has_focus()
	var ink := Color("e3543d") if active else Color("111619")
	var w := size.x
	var h := size.y
	var outline := PackedVector2Array(
		[Vector2(8, 0), Vector2(w, 5), Vector2(w - 8, h), Vector2(0, h - 5)]
	)
	var backing := PackedVector2Array()
	for point in outline:
		backing.append(point + Vector2(0, 5))
	draw_colored_polygon(backing, ink)
	draw_colored_polygon(outline, Color("efe8dc"))
	draw_line(Vector2(16, 6), Vector2(w - 12, 9), ink, 5.0 if active else 2.0, true)
	if active:
		draw_colored_polygon(
			PackedVector2Array([Vector2(w - 24, 18), Vector2(w - 10, 24), Vector2(w - 24, 30)]), ink
		)
