class_name TidePauseJournal
extends Control
## Пауза «СУДОВОЙ ЖУРНАЛ»: страница пены с гравюрной штриховкой и зубцами.
## Список взятых модулей — записи вахты (время + название) по линованным
## строкам, у свежей записи стоит штамп «ЗАЧТЕНО». Кнопки — скошенные
## плашки sonar / flare. Всё содержимое страницы живёт в её координатах.

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
const PAGE_RECT := Rect2(110, 62, 1170, 956)
const PAGE_DEG := -2.0
const STATS_RECT := Rect2(1336, 96, 480, 452)
const DEBUG_RECT := Rect2(1352, 590, 456, 330)
const ROWS := 8
const ROW_H := 68.0
const LIST_TOP := 240.0
const MARGIN := 64.0

var _page: Control
var _list: Control
var _stamp: TideStamp
var _stats_panel: Control
var _debug_panel: Control
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
	backdrop.color = TideTokens.ink_alpha(0.74)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	TideKit.place(backdrop, Rect2(Vector2.ZERO, TideTokens.BASE))
	add_child(backdrop)
	TideKit.isobaths(self, Rect2(Vector2.ZERO, TideTokens.BASE), 0.07, 36.0)

	# --- Правая колонка: показания и отладка, обрывки под страницей ---
	_stats_panel = TideKit.group(self, STATS_RECT, 3.2)
	var stats_back := TideKit.panel(
		_stats_panel, Rect2(Vector2.ZERO, STATS_RECT.size), TideTokens.DEEP, TideTokens.SONAR, true
	)
	stats_back.hatch_color = TideTokens.foam_alpha(0.07)
	stats_back.hatch_spacing = 8.0
	TideKit.text(_stats_panel, "ПОКАЗАНИЯ", Vector2(48, 28), 1, 26, TideTokens.SONAR)
	_stats_label = TideKit.block(
		_stats_panel, "", Rect2(48, 84, 424, 350), 1, 19, TideTokens.FOAM, 8
	)

	_debug_panel = TideKit.group(self, DEBUG_RECT, -2.4)
	TideKit.panel(
		_debug_panel, Rect2(Vector2.ZERO, DEBUG_RECT.size), TideTokens.DEEP, Color(0, 0, 0, 0), false
	)
	TideKit.text(_debug_panel, "ОТЛАДКА · ТЕСТ", Vector2(56, 22), 1, 18, TideTokens.foam_alpha(0.55))
	var index := 0
	for entry in DEBUG_KEYS:
		var key := String(entry[0])
		var column := index % 2
		var row := int(index / 2.0)
		var button := TideKit.button(
			_debug_panel,
			String(entry[1]),
			Rect2(64.0 + float(column) * 190.0, 74.0 + float(row) * 76.0, 164, 54),
			TideButton.Shape.GHOST,
			TideTokens.SONAR,
			1,
			17,
			TideTokens.FOAM
		)
		button.skew = 9.0
		button.cut = 0.0
		button.toggle_mode = true
		button.toggled.connect(_on_debug_toggled.bind(key))
		_debug_buttons[key] = button
		index += 1

	# --- Страница журнала ---
	_page = TideKit.group(self, PAGE_RECT, PAGE_DEG)
	var sheet := TideKit.panel(
		_page, Rect2(Vector2.ZERO, PAGE_RECT.size), TideTokens.FOAM, TideTokens.FLARE, true
	)
	sheet.hatch_color = TideTokens.deep_alpha(0.14)
	sheet.hatch_spacing = 7.0
	sheet.underprint_offset = Vector2(14.0, 16.0)

	var inner := PAGE_RECT.size.x - MARGIN * 2.0
	var title := TideKit.headline(
		_page, "СУДОВОЙ ЖУРНАЛ", Vector2(MARGIN - 6.0, 40), inner - 120.0, 96,
		TideTokens.INK, 0, -11.0, TideTokens.FLARE
	)
	var rule_y := title.position.y + title.size.y + 6.0
	TideKit.poly(
		_page,
		PackedVector2Array([
			Vector2(MARGIN + 8.0, rule_y), Vector2(MARGIN + inner, rule_y),
			Vector2(MARGIN + inner - 8.0, rule_y + 12.0), Vector2(MARGIN, rule_y + 12.0),
		]),
		TideTokens.SONAR
	)
	_header = TideKit.text(
		_page, "ВАХТА · 00:00", Vector2(MARGIN, rule_y + 22.0), 1, 22, TideTokens.INK, 420.0
	)
	TideKit.text(
		_page, "ESC · ПРОДОЛЖИТЬ ВАХТУ", Vector2(MARGIN + inner - 420.0, rule_y + 24.0), 1, 17,
		TideTokens.ink_alpha(0.55), 420.0, HORIZONTAL_ALIGNMENT_RIGHT
	)
	# Линовка журнала: строки есть всегда, даже когда записей мало.
	for row in range(ROWS + 1):
		var y := LIST_TOP + float(row) * ROW_H
		TideKit.poly(
			_page,
			PackedVector2Array([
				Vector2(MARGIN, y), Vector2(MARGIN + inner, y),
				Vector2(MARGIN + inner, y + 2.0), Vector2(MARGIN, y + 2.0),
			]),
			TideTokens.ink_alpha(0.22)
		)
	_list = Control.new()
	_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_list.position = Vector2(MARGIN, LIST_TOP)
	_page.add_child(_list)

	var buttons_y := LIST_TOP + float(ROWS) * ROW_H + 36.0
	_resume = TideKit.button(
		_page,
		"ПРОДОЛЖИТЬ",
		Rect2(MARGIN + 18.0, buttons_y, 500, 104),
		TideButton.Shape.SOLID,
		TideTokens.SONAR,
		0,
		44,
		TideTokens.INK,
		-1.2
	)
	_resume.pressed.connect(func() -> void: resume_requested.emit())
	_menu = TideKit.button(
		_page,
		"В МЕНЮ",
		Rect2(MARGIN + 580.0, buttons_y + 14.0, 300, 82),
		TideButton.Shape.SOLID,
		TideTokens.FLARE,
		0,
		30,
		TideTokens.FOAM,
		1.4
	)
	_menu.pressed.connect(func() -> void: menu_requested.emit())

	# Качка: три листа, три фазы.
	add_child(TideFx.bob(_page, PAGE_DEG, 0.5, 3.1, 0.0))
	add_child(TideFx.bob(_stats_panel, 3.2, 1.0, 2.5, 2.1))
	add_child(TideFx.bob(_debug_panel, -2.4, 0.8, 2.8, 4.0))

	# Штамп ложится на свежую (верхнюю) запись, справа от названия.
	_stamp = TideKit.stamp(
		_page, "ЗАЧТЕНО", Rect2(MARGIN + inner - 330.0, LIST_TOP - 26.0, 320, 112),
		TideTokens.FLARE, 44, -12.0
	)


## data: {entries: [{clock, title, evolution}], stats: String, debug: Dictionary, clock: String}
func open(data: Dictionary) -> void:
	show()
	mouse_filter = Control.MOUSE_FILTER_STOP
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
		TideKit.text(
			_list, "ЗАПИСЕЙ НЕТ — ВАХТА ТОЛЬКО НАЧАЛАСЬ", Vector2(0, 18), 1, 22,
			TideTokens.ink_alpha(0.6)
		)
	else:
		for index in range(mini(entries.size(), ROWS)):
			_write_entry(entries[index], index)
	_stamp.hide()
	_play_entrance(not entries.is_empty())


## Одна запись вахты: время — моно, название — заголовочным, по линейке.
func _write_entry(entry: Dictionary, index: int) -> void:
	var row := Control.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.position = Vector2(0.0, float(index) * ROW_H)
	row.size = Vector2(PAGE_RECT.size.x - MARGIN * 2.0, ROW_H)
	_list.add_child(row)
	var evolution := bool(entry.get("evolution", false))
	var mono := TideTokens.mono_font()
	var clock := TideKit.text(
		row, String(entry.get("clock", "00:00")), Vector2(4, 0), 1, 24, TideTokens.FLARE
	)
	clock.position.y = (ROW_H - clock.size.y) * 0.5 + 2.0
	var name_text := String(entry.get("title", "")).to_upper()
	# Свежая запись делит строку со штампом, остальные — с меткой эволюции.
	var room := 520.0 if index == 0 else 640.0
	var point := TideTokens.fit_point(TideTokens.title_font(), name_text, room, 28, 16)
	var caption := TideKit.text(
		row, name_text, Vector2(128, 0), 2, point, TideTokens.FLARE if evolution else TideTokens.INK
	)
	caption.position.y = (ROW_H - caption.size.y) * 0.5 + 2.0
	if evolution and index > 0:
		var tag_text := "ЭВОЛЮЦИЯ"
		var tag_w := mono.get_string_size(tag_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x + 36.0
		var tag_at := Vector2(row.size.x - tag_w - 12.0, 18.0)
		TideKit.poly(row, TideShapes.plate(Vector2(tag_w, 32.0), 6.0), TideTokens.FLARE, tag_at)
		var tag := TideKit.text(
			row, tag_text, tag_at, 1, 16, TideTokens.FOAM, tag_w, HORIZONTAL_ALIGNMENT_CENTER
		)
		tag.size.y = 32.0


func _paint_debug(button: TideButton, state: bool) -> void:
	button.tint = TideTokens.SONAR if state else TideTokens.foam_alpha(0.3)
	button.set_caption(button.caption.text, TideTokens.SONAR if state else TideTokens.foam_alpha(0.6))
	button.queue_redraw()


func _on_debug_toggled(state: bool, key: String) -> void:
	_paint_debug(_debug_buttons[key], state)
	debug_toggled.emit(key, state)


func _play_entrance(with_stamp: bool) -> void:
	# Страница: scale 0.5 → 1 и поворот от −10°, 0.22 с, TRANS_BACK.
	TideKit.place(_page, PAGE_RECT, PAGE_DEG)
	TideFx.pop_in(_page, 0.5, -10.0)
	TideFx.splash(self, Vector2(PAGE_RECT.position.x + 200.0, PAGE_RECT.end.y - 20.0), 14)
	_side_in(_stats_panel, STATS_RECT, 3.2, 0.08)
	_side_in(_debug_panel, DEBUG_RECT, -2.4, 0.14)
	# Записи «вписываются» по очереди: короткий сдвиг с overshoot.
	var order := 0
	for child in _list.get_children():
		var row := child as Control
		if row == null or row.is_queued_for_deletion():
			continue
		var target := row.position
		row.modulate.a = 0.0
		row.position = target + Vector2(-36.0, 0.0)
		var tween := row.create_tween()
		tween.tween_interval(0.16 + 0.035 * float(order))
		tween.tween_property(row, "modulate:a", 1.0, 0.05)
		tween.parallel().tween_property(row, "position", target, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		order += 1
	if with_stamp:
		var stamp_tween := create_tween()
		stamp_tween.tween_interval(0.42)
		stamp_tween.tween_callback(func() -> void: _stamp.hit(_page))


func _side_in(node: Control, rect: Rect2, deg: float, delay: float) -> void:
	TideKit.place(node, rect, deg)
	node.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_interval(delay)
	tween.tween_callback(func() -> void: TideFx.pop_in(node, 0.5, 10.0))
