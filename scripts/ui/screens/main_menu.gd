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
]

var _poster: TidePanelTorn
var _head: Control
var _title: TideTitleLabel
var _ticket: Control
var _voyage: TideButton
var _continue: TideButton
var _quit: TideButton
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
	for button in [_voyage, _continue, _quit]:
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
		self, "РЕЙС №041 · ВЕРСИЯ 0.9.4", Vector2(96, 1014), 1, 18, TideTokens.foam_alpha(0.55)
	)
	_footer.rotation = deg_to_rad(-1.0)

	var bob_poster := TideFx.bob(_poster, POSTER_DEG, 0.5, 3.2, 0.0)
	add_child(bob_poster)
	add_child(TideFx.bob(_head, HEAD_DEG, 0.8, 2.6, 1.7))
	add_child(TideFx.bob(_ticket, TICKET_DEG, 1.1, 2.9, 3.3))


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
	var buttons := [_voyage, _continue, _quit]
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
	hide()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
