class_name TideMainMenu
extends Control
## Главное меню — афиша пароходства. Слева рваный лист афиши с заголовком
## и кнопками-вымпелами, справа — живая сцена игры (её рисует сама игра),
## на которую заголовок и штамп заходят внахлёст.

signal voyage_requested
signal continue_requested
signal quit_requested

const POSTER_RECT := Rect2(-90, -90, 800, 1280)
const POSTER_DEG := -3.0
const HEAD_RECT := Rect2(70, 150, 1010, 330)
const HEAD_DEG := -4.0
const TICKET_RECT := Rect2(1480, 70, 380, 132)
const TICKET_DEG := 4.0
const BUTTONS := [
	Rect2(104, 548, 540, 108),
	Rect2(150, 684, 450, 86),
	Rect2(196, 798, 340, 74),
	Rect2(180, 888, 390, 68),
]

var _poster: TidePanelTorn
var _head: Control
var _title: TideTitleLabel
var _ticket: Control
var _voyage: TideButton
var _continue: TideButton
var _quit: TideButton
var _settings_button: TideButton
var graphics_settings: GameGraphicsSettings
var settings_open := false
var _settings_panel: Control
var _scale_value: Label
var _msaa_value: Label
var _settings_notice: Label
var _stamp: TideStamp
var _footer: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_build()


func _build() -> void:
	TideKit.isobaths(self, Rect2(Vector2.ZERO, TideTokens.BASE), 0.06, 40.0)

	# --- Лист афиши: уходит за левый и верхний край ---
	_poster = TideKit.panel(self, POSTER_RECT, TideTokens.DEEP, TideTokens.FLARE, true, POSTER_DEG)
	_poster.hatch_color = TideTokens.foam_alpha(0.06)
	_poster.hatch_spacing = 8.0
	_poster.underprint_offset = Vector2(16.0, 10.0)

	# --- Шапка: пароходство, название игры, жанр ---
	_head = TideKit.group(self, HEAD_RECT, HEAD_DEG)
	TideKit.text(_head, "ПАРОХОДСТВО «МАЯК» · РЕЙСЫ В ОДИН КОНЕЦ", Vector2(14, 0), 1, 22, TideTokens.SONAR)
	_title = TideKit.headline(
		_head, "К СВЕТУ", Vector2(0, 30), HEAD_RECT.size.x - 20.0, 190, TideTokens.FOAM, 10, -12.0
	)
	var rule_y := _title.position.y + _title.size.y + 4.0
	TideKit.poly(
		_head,
		PackedVector2Array([
			Vector2(22, rule_y), Vector2(560, rule_y), Vector2(552, rule_y + 12.0),
			Vector2(14, rule_y + 12.0),
		]),
		TideTokens.FLARE
	)
	TideKit.text(
		_head, "ПОСЛЕДНИЙ РЕЙС К ПОГАСШЕМУ МАЯКУ", Vector2(14, rule_y + 24.0), 1, 20,
		TideTokens.foam_alpha(0.7)
	)

	# --- Кнопки-вымпелы: лесенкой, каждая со своим наклоном ---
	_voyage = TideKit.button(
		self, "НОВАЯ ВАХТА", BUTTONS[0], TideButton.Shape.PENNANT, TideTokens.SONAR, 0, 46,
		TideTokens.INK, -2.4
	)
	_voyage.pressed.connect(func() -> void: voyage_requested.emit())
	_continue = TideKit.button(
		self, "ПРОДОЛЖИТЬ", BUTTONS[1], TideButton.Shape.PENNANT, TideTokens.FOAM, 0, 32,
		TideTokens.INK, 1.6
	)
	_continue.pressed.connect(func() -> void: continue_requested.emit())
	_quit = TideKit.button(
		self, "ВЫХОД", BUTTONS[2], TideButton.Shape.PENNANT, TideTokens.FLARE, 0, 26,
		TideTokens.FOAM, -1.4
	)
	_quit.pressed.connect(func() -> void: quit_requested.emit())
	_settings_button = TideKit.button(self, "ГРАФИКА", BUTTONS[3], TideButton.Shape.PENNANT,
		TideTokens.FOAM, 0, 24, TideTokens.INK, -1.0)
	_settings_button.visible = graphics_settings != null
	_settings_button.pressed.connect(open_settings)
	for button in [_voyage, _continue, _quit, _settings_button]:
		button.mouse_entered.connect(_splash_at.bind(button))
		button.focus_entered.connect(_splash_at.bind(button))

	# --- Талон порта приписки: противовес справа сверху ---
	_ticket = TideKit.group(self, TICKET_RECT, TICKET_DEG)
	TideKit.panel(
		_ticket, Rect2(Vector2.ZERO, TICKET_RECT.size), TideTokens.FOAM, TideTokens.FLARE, true
	).hatch_color = TideTokens.deep_alpha(0.12)
	TideKit.text(_ticket, "ПОРТ ПРИПИСКИ", Vector2(34, 16), 1, 17, TideTokens.ink_alpha(0.6))
	TideKit.text(_ticket, "БУХТА", Vector2(32, 38), 2, 46, TideTokens.INK)

	_stamp = TideKit.stamp(self, "ОТХОД 06:00", Rect2(560, 842, 460, 136), TideTokens.FLARE, 46, -12.0)
	_footer = TideKit.text(
		self, "РЕЙС №041 · ВЕРСИЯ 0.9.4", Vector2(96, 1014), 1, 20, TideTokens.foam_alpha(0.8)
	)
	_footer.rotation = deg_to_rad(-1.0)

	_build_settings()
	var bob_poster := TideFx.bob(_poster, POSTER_DEG, 0.5, 3.2, 0.0)
	add_child(bob_poster)
	add_child(TideFx.bob(_head, HEAD_DEG, 0.8, 2.6, 1.7))
	add_child(TideFx.bob(_ticket, TICKET_DEG, 1.1, 2.9, 3.3))


func _build_settings() -> void:
	_settings_panel = Control.new()
	_settings_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	TideKit.place(_settings_panel, Rect2(Vector2.ZERO, TideTokens.BASE))
	add_child(_settings_panel)
	var shade := ColorRect.new()
	shade.color = TideTokens.ink_alpha(0.78)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	TideKit.place(shade, Rect2(Vector2.ZERO, TideTokens.BASE))
	_settings_panel.add_child(shade)
	var page := TideKit.group(_settings_panel, Rect2(520, 200, 880, 660), -1.0)
	var sheet := TideKit.panel(page, Rect2(0, 0, 880, 660), TideTokens.FOAM, TideTokens.FLARE, true)
	sheet.hatch_color = TideTokens.ink_alpha(0.05)
	TideKit.text(page, "НАСТРОЙКИ · ИЗОБРАЖЕНИЕ", Vector2(60, 42), 1, 20, TideTokens.FLARE, 750)
	TideKit.headline(page, "ГРАФИКА", Vector2(54, 80), 740, 68, TideTokens.INK, 4, -4.0)
	TideKit.text(page, "МАСШТАБ 3D", Vector2(60, 212), 2, 30, TideTokens.INK, 420)
	TideKit.text(page, "Меньше — выше FPS; интерфейс остаётся чётким", Vector2(60, 255), 1, 17, TideTokens.ink_alpha(0.75), 700)
	_scale_value = TideKit.text(page, "", Vector2(546, 211), 1, 28, TideTokens.INK, 130, HORIZONTAL_ALIGNMENT_CENTER)
	var scale_minus := TideKit.button(page, "−", Rect2(474, 207, 62, 56), TideButton.Shape.GHOST, TideTokens.INK, 0, 30, TideTokens.INK)
	var scale_plus := TideKit.button(page, "+", Rect2(690, 207, 62, 56), TideButton.Shape.GHOST, TideTokens.INK, 0, 30, TideTokens.INK)
	scale_minus.pressed.connect(_change_scale.bind(-1))
	scale_plus.pressed.connect(_change_scale.bind(1))
	TideKit.text(page, "СГЛАЖИВАНИЕ MSAA", Vector2(60, 335), 2, 30, TideTokens.INK, 420)
	TideKit.text(page, "Сглаживает края, но увеличивает нагрузку", Vector2(60, 378), 1, 17, TideTokens.ink_alpha(0.75), 700)
	_msaa_value = TideKit.text(page, "", Vector2(546, 334), 1, 25, TideTokens.INK, 130, HORIZONTAL_ALIGNMENT_CENTER)
	var msaa_minus := TideKit.button(page, "−", Rect2(474, 330, 62, 56), TideButton.Shape.GHOST, TideTokens.INK, 0, 30, TideTokens.INK)
	var msaa_plus := TideKit.button(page, "+", Rect2(690, 330, 62, 56), TideButton.Shape.GHOST, TideTokens.INK, 0, 30, TideTokens.INK)
	msaa_minus.pressed.connect(_change_msaa.bind(-1))
	msaa_plus.pressed.connect(_change_msaa.bind(1))
	_settings_notice = TideKit.text(page, "", Vector2(60, 456), 1, 17, TideTokens.ink_alpha(0.75), 760)
	var back := TideKit.button(page, "НАЗАД", Rect2(60, 528, 300, 76), TideButton.Shape.SOLID, TideTokens.SONAR, 0, 28, TideTokens.INK)
	back.pressed.connect(close_settings)
	_settings_panel.hide()


func open_settings() -> void:
	if graphics_settings == null:
		return
	settings_open = true
	_refresh_settings()
	_settings_panel.show()
	_settings_panel.modulate.a = 0.0
	create_tween().tween_property(_settings_panel, "modulate:a", 1.0, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func close_settings() -> void:
	settings_open = false
	if _settings_panel != null:
		_settings_panel.hide()


func _change_scale(direction: int) -> void:
	var values := GameGraphicsSettings.SCALES
	var index := clampi(values.find(graphics_settings.scale_percent) + direction, 0, values.size() - 1)
	graphics_settings.set_scale(values[index])
	_refresh_settings()


func _change_msaa(direction: int) -> void:
	var values := GameGraphicsSettings.MSAA_VALUES
	var index := clampi(values.find(graphics_settings.msaa) + direction, 0, values.size() - 1)
	graphics_settings.set_msaa(values[index])
	_refresh_settings()


func _refresh_settings() -> void:
	_scale_value.text = "%d%%" % graphics_settings.scale_percent
	var names := ["ВЫКЛ", "2×", "4×", "8×"]
	_msaa_value.text = names[GameGraphicsSettings.MSAA_VALUES.find(graphics_settings.msaa)]
	_settings_notice.text = "СОХРАНЕНО · ИЗМЕНЕНИЯ ПРИМЕНЯЮТСЯ СРАЗУ" if graphics_settings.save_error == OK else "НЕ УДАЛОСЬ СОХРАНИТЬ НАСТРОЙКИ"


## Наведение: брызги из-под вымпела.
func _splash_at(button: TideButton) -> void:
	TideFx.splash(self, button.position + button.size * Vector2(0.86, 0.5), 14)
	TideFx.splash(self, button.position + button.size * Vector2(0.2, 0.8), 8, TideTokens.SONAR)


func open() -> void:
	show()
	mouse_filter = Control.MOUSE_FILTER_STOP
	_stamp.hide()
	_stagger(_poster, 0.0, 0.8, -8.0)
	_stagger(_ticket, 0.16, 0.5, 10.0)
	# Заголовок влетает сверху с overshoot.
	TideKit.place(_head, HEAD_RECT, HEAD_DEG)
	_head.modulate.a = 0.0
	var head_tween := create_tween()
	head_tween.tween_interval(0.08)
	head_tween.tween_callback(_head_in)
	head_tween.tween_interval(0.36)
	head_tween.tween_callback(func() -> void: _stamp.hit(self))
	_footer.modulate.a = 0.0
	var footer_tween := create_tween()
	footer_tween.tween_interval(0.3)
	footer_tween.tween_property(_footer, "modulate:a", 1.0, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	close_settings()
	var buttons := [_voyage, _continue, _quit, _settings_button]
	for index in range(buttons.size()):
		var button: TideButton = buttons[index]
		button.position = BUTTONS[index].position
		button.modulate.a = 0.0
		var tween := create_tween()
		tween.tween_interval(0.16 + 0.06 * float(index))
		tween.tween_callback(_button_in.bind(button))


func _head_in() -> void:
	_head.modulate.a = 1.0
	TideFx.slide_in(_head, Vector2(-40, -420), 0.26)


## Вымпел выстреливает слева: сдвиг с overshoot + брызги пены.
func _button_in(button: TideButton) -> void:
	button.modulate.a = 1.0
	TideFx.slide_in(button, Vector2(-560, 0), 0.22)
	TideFx.splash(self, button.position + button.size * Vector2(1.0, 0.5) + Vector2(560, 0), 10)


func _stagger(node: Control, delay: float, from_scale: float, from_deg: float) -> void:
	node.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_interval(delay)
	tween.tween_callback(func() -> void: TideFx.pop_in(node, from_scale, from_deg))


func close() -> void:
	close_settings()
	hide()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
