class_name TidePauseJournal
extends Control
## Пауза «СУДОВОЙ ЖУРНАЛ»: страница пены с гравюрной штриховкой и зубцами.
## Список взятых модулей — записи вахты (время + название), у свежей записи
## стоит штамп «ЗАЧТЕНО». Кнопки — скошенные плашки sonar / flare.

signal resume_requested
signal menu_requested
signal debug_toggled(key: String, value: bool)

const DEBUG_KEYS := [
	["god", "БЕССМЕРТИЕ"],
	["clear", "ЗАЧИСТКА"],
	["spheres", "СФЕРЫ"],
	["gravity", "СТЯГИВАНИЕ"],
	["effects", "ЭФФЕКТЫ"],
	["fireballs", "СНАРЯДЫ"],
]

var _page: Control
var _list: Control
var _stamp: TideStamp
var _stats_label: Label
var _debug_buttons := {}
var _resume: TideButton
var _menu: TideButton
var _header: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build()


func _build() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = TideTokens.ink_alpha(0.72)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	TideKit.place(backdrop, Rect2(Vector2.ZERO, TideTokens.BASE))
	add_child(backdrop)
	TideKit.isobaths(self, Rect2(Vector2.ZERO, TideTokens.BASE), 0.07, 36.0)

	# Правая колонка — обрывки с показаниями и отладкой.
	var stats_panel := TideKit.panel(
		self, Rect2(1372, 116, 430, 540), TideTokens.deep_alpha(0.94), TideTokens.SONAR, true, 3.4
	)
	TideKit.mono(stats_panel, "ПОКАЗАНИЯ", Vector2(26, 18), 24, TideTokens.SONAR, -1.0)
	_stats_label = TideKit.label(
		stats_panel, "", Rect2(26, 60, 392, 440), 1, 20, TideTokens.FOAM, -0.6, false
	)
	_stats_label.add_theme_constant_override("line_spacing", 10)

	var debug_panel := TideKit.panel(
		self, Rect2(1372, 692, 430, 296), TideTokens.deep_alpha(0.94), Color(0, 0, 0, 0), true, -2.2
	)
	TideKit.mono(debug_panel, "ОТЛАДКА · ТЕСТ", Vector2(26, 14), 18, TideTokens.foam_alpha(0.55), -1.0)
	var index := 0
	for entry in DEBUG_KEYS:
		var key := String(entry[0])
		var column := index % 2
		var row := int(index / 2.0)
		var button := TideKit.button(
			debug_panel,
			String(entry[1]),
			Rect2(24 + column * 196, 52 + row * 72, 184, 58),
			TideButton.Variant.GHOST,
			TideTokens.SONAR,
			1,
			17,
			TideTokens.FOAM,
			-1.2
		)
		button.toggle_mode = true
		button.toggled.connect(_on_debug_toggled.bind(key))
		_debug_buttons[key] = button
		index += 1

	# Страница журнала.
	_page = Control.new()
	_page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_page.size = TideTokens.BASE
	_page.pivot_offset = TideTokens.BASE * 0.5
	add_child(_page)
	var sheet := TideKit.panel(
		_page, Rect2(146, 76, 1188, 934), TideTokens.FOAM, TideTokens.FLARE, true, -1.6
	)
	sheet.hatch_color = TideTokens.deep_alpha(0.18)
	sheet.hatch_spacing = 7.0
	sheet.border_color = TideTokens.ink_alpha(0.35)
	sheet.border_width = 2.0

	var title := TideKit.title(_page, "СУДОВОЙ ЖУРНАЛ", Vector2(198, 108), 92, -8.0, TideTokens.INK, 7)
	TideKit.fit_title(title, 980.0, 92, 54)
	TideKit.mono(_page, "ESC · ПРОДОЛЖИТЬ ВАХТУ", Vector2(1010, 96), 18, TideTokens.ink_alpha(0.55), -1.0)
	var rule_shape := PackedVector2Array(
		[Vector2(200, 268), Vector2(1284, 252), Vector2(1284, 264), Vector2(200, 280)]
	)
	TideShapes.fill(_page, rule_shape, TideTokens.SONAR)
	_header = TideKit.mono(_page, "ВАХТА · 00:00", Vector2(200, 292), 21, TideTokens.ink_alpha(0.7), -0.8)

	_list = Control.new()
	_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_list.position = Vector2(206, 348)
	add_child(_list)

	_stamp = TideKit.stamp(self, "ЗАЧТЕНО", Rect2(946, 330, 300, 96), TideTokens.FLARE, 40, -12.0)

	_resume = TideKit.button(
		self,
		"ПРОДОЛЖИТЬ",
		Rect2(196, 902, 430, 100),
		TideButton.Variant.SOLID,
		TideTokens.SONAR,
		0,
		40,
		TideTokens.INK,
		-2.0
	)
	_resume.pressed.connect(func() -> void: resume_requested.emit())
	_menu = TideKit.button(
		self,
		"В МЕНЮ",
		Rect2(664, 924, 306, 78),
		TideButton.Variant.OUTLINE,
		TideTokens.FLARE,
		0,
		28,
		TideTokens.FLARE,
		1.6
	)
	_menu.pressed.connect(func() -> void: menu_requested.emit())


## data: {entries: [{clock, title, evolution}], stats: String, debug: Dictionary, clock: String}
func open(data: Dictionary) -> void:
	show()
	_header.text = "ВАХТА · %s" % String(data.get("clock", "00:00"))
	_stats_label.text = String(data.get("stats", ""))
	var debug: Dictionary = data.get("debug", {})
	for key in _debug_buttons.keys():
		var button: TideButton = _debug_buttons[key]
		button.set_pressed_no_signal(bool(debug.get(key, false)))
		_paint_debug(button, bool(debug.get(key, false)))
	for child in _list.get_children():
		child.queue_free()
	var entries: Array = data.get("entries", [])
	if entries.is_empty():
		TideKit.mono(
			_list,
			"ЗАПИСЕЙ НЕТ — ВАХТА ТОЛЬКО НАЧАЛАСЬ",
			Vector2(0, 10),
			22,
			TideTokens.ink_alpha(0.6),
			-0.8
		)
	else:
		var rows := mini(entries.size(), 8)
		for index in range(rows):
			_write_entry(entries[index], index)
	_stamp.hide()
	_play_entrance()


func _write_entry(entry: Dictionary, index: int) -> void:
	var y := float(index) * 62.0
	TideKit.mono(_list, String(entry.get("clock", "00:00")), Vector2(0, y + 2), 21, TideTokens.FLARE, -0.6)
	var name_text := String(entry.get("title", "")).to_upper()
	var name_label := TideKit.label(
		_list,
		name_text,
		Rect2(112, y - 8, 640, 46),
		2,
		26,
		TideTokens.INK,
		-0.8,
		false
	)
	name_label.add_theme_constant_override("outline_size", 0)
	if bool(entry.get("evolution", false)):
		TideKit.mono(_list, "ЭВОЛЮЦИЯ", Vector2(766, y + 6), 15, TideTokens.FLARE, -1.4)
	if index > 0:
		var fresh := TideShapes.plate(Vector2(664, 3), 3.0)
		TideShapes.fill(_list, TideShapes.offset(fresh, Vector2(112, y + 40)), TideTokens.ink_alpha(0.16))


func _paint_debug(button: TideButton, state: bool) -> void:
	button.tint = TideTokens.SONAR if state else TideTokens.foam_alpha(0.3)
	button.set_caption(button.caption.text, TideTokens.FOAM if state else TideTokens.foam_alpha(0.6))
	button.queue_redraw()


func _on_debug_toggled(state: bool, key: String) -> void:
	_paint_debug(_debug_buttons[key], state)
	debug_toggled.emit(key, state)


func _play_entrance() -> void:
	for child in _list.get_children():
		var node := child as CanvasItem
		if node == null:
			continue
		node.modulate.a = 0.0
	var delay := 0.0
	var row := 0
	for child in _list.get_children():
		var node := child as Control
		if node == null:
			continue
		var tween := create_tween()
		tween.tween_interval(delay)
		tween.tween_property(node, "modulate:a", 1.0, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_callback(_row_slide.bind(node))
		delay += 0.015 * float(row + 1)
		row += 1
	TideFx.pop_in(_page, 0.8, -6.0)
	var stamp_tween := create_tween()
	stamp_tween.tween_interval(0.28)
	stamp_tween.tween_callback(func() -> void: _stamp.hit(self))
	stamp_tween.tween_interval(0.5)
	stamp_tween.tween_callback(func() -> void: _stamp.hide())


func _row_slide(node: Control) -> void:
	if node == null or not node.is_inside_tree():
		return
	var target := node.position
	node.position = target + Vector2(-18, 0)
	var tween := node.create_tween()
	tween.tween_property(node, "position", target, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
