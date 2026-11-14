class_name TideMainMenu
extends Control
## Главное меню — афиша пароходства: рваные панели по краям, за ними живая
## сцена (её рисует сама игра), крупный заголовок и кнопки-вымпелы.

signal voyage_requested
signal continue_requested
signal quit_requested

var _title: TideTitleLabel
var _kicker: Label
var _voyage: TideButton
var _continue: TideButton
var _quit: TideButton
var _left_panel: TidePanelTorn
var _right_panel: TidePanelTorn
var _bottom_panel: TidePanelTorn
var _stamp: TideStamp
var _footer: Label
var _route: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_build()


func _build() -> void:
	TideKit.isobaths(self, Rect2(Vector2.ZERO, TideTokens.BASE), 0.045, 40.0)

	_left_panel = TideKit.panel(
		self, Rect2(-72, -40, 452, 1200), TideTokens.deep_alpha(0.88), TideTokens.FLARE, true, -2.5
	)
	_right_panel = TideKit.panel(
		self, Rect2(1520, -40, 500, 1200), TideTokens.deep_alpha(0.88), TideTokens.SONAR, true, 2.2
	)
	_bottom_panel = TideKit.panel(
		self, Rect2(300, 986, 1120, 150), TideTokens.deep_alpha(0.9), Color(0, 0, 0, 0), false, -1.2, true
	)

	_kicker = TideKit.mono(
		self, "ПОСЛЕДНИЙ РЕЙС К ПОГАСШЕМУ МАЯКУ", Vector2(470, 292), 24, TideTokens.SONAR, -3.0
	)
	_title = TideKit.title(self, "К СВЕТУ", Vector2(452, 322), 180, -8.0, TideTokens.FOAM, 12)
	TideKit.fit_title(_title, 1120.0, 210, 90)

	_route = TideKit.mono(
		self, "ТОП-ДАУН ВЫЖИВАЛКА · РОГАЛИК О ЛОДКЕ", Vector2(470, 604), 20, TideTokens.foam_alpha(0.62), -1.6
	)

	_voyage = TideKit.button(
		self,
		"НОВАЯ ВАХТА",
		Rect2(1152, 470, 500, 108),
		TideButton.Variant.SOLID,
		TideTokens.SONAR,
		0,
		46,
		TideTokens.INK,
		-2.4
	)
	_voyage.pressed.connect(func() -> void: voyage_requested.emit())
	_continue = TideKit.button(
		self,
		"ПРОДОЛЖИТЬ",
		Rect2(1204, 600, 430, 84),
		TideButton.Variant.OUTLINE,
		TideTokens.FOAM,
		0,
		32,
		TideTokens.FOAM,
		1.8
	)
	_continue.pressed.connect(func() -> void: continue_requested.emit())
	_quit = TideKit.button(
		self,
		"ВЫХОД",
		Rect2(1268, 706, 330, 74),
		TideButton.Variant.OUTLINE,
		TideTokens.FLARE,
		0,
		26,
		TideTokens.FLARE,
		-1.4
	)
	_quit.pressed.connect(func() -> void: quit_requested.emit())

	_stamp = TideKit.stamp(self, "ОТХОД 06:00", Rect2(120, 690, 348, 120), TideTokens.FLARE, 40, -12.0)
	_footer = TideKit.mono(
		self,
		"РЕЙС №041 · ВЕРСИЯ 0.9.4 · TIDECUT UI KIT",
		Vector2(330, 1042),
		19,
		TideTokens.foam_alpha(0.5),
		-1.0
	)
	for button in [_voyage, _continue, _quit]:
		button.mouse_entered.connect(_splash_at.bind(button))
		button.focus_entered.connect(_splash_at.bind(button))


func _splash_at(button: TideButton) -> void:
	TideFx.splash(self, button.position + button.size * Vector2(0.5, 0.3), 14)
	TideFx.splash(self, button.position + button.size * Vector2(0.2, 0.75), 8, TideTokens.SONAR)


func open() -> void:
	show()
	mouse_filter = Control.MOUSE_FILTER_STOP
	_stamp.hide()
	_title.modulate.a = 0.0
	_kicker.modulate.a = 0.0
	_route.modulate.a = 0.0
	_footer.modulate.a = 0.0
	for button in [_voyage, _continue, _quit]:
		button.modulate.a = 0.0
	_stagger(_left_panel, 0.0, 0.9, -6.0)
	_stagger(_right_panel, 0.04, 0.9, 6.0)
	_stagger(_bottom_panel, 0.08, 0.94, -4.0)
	var title_tween := create_tween()
	title_tween.tween_interval(0.10)
	title_tween.tween_callback(_title_in)
	title_tween.tween_interval(0.12)
	title_tween.tween_callback(func() -> void: _stamp.hit(self))
	var line_tween := create_tween()
	line_tween.tween_interval(0.20)
	line_tween.tween_property(_kicker, "modulate:a", 1.0, 0.16)
	line_tween.tween_interval(0.04)
	line_tween.tween_property(_route, "modulate:a", 1.0, 0.16)
	line_tween.tween_interval(0.04)
	line_tween.tween_property(_footer, "modulate:a", 1.0, 0.16)
	var buttons := [_voyage, _continue, _quit]
	for index in range(buttons.size()):
		var button: TideButton = buttons[index]
		var tween := create_tween()
		tween.tween_interval(0.18 + 0.05 * float(index))
		tween.tween_property(button, "modulate:a", 1.0, 0.16)
		tween.tween_callback(_button_in.bind(button, index))


func _title_in() -> void:
	_title.modulate.a = 1.0
	_title.position = Vector2(452, 322)
	TideFx.slide_in(_title, Vector2(0, -220), 0.28)


func _button_in(button: TideButton, index: int) -> void:
	var target := button.position
	button.position = target + Vector2(0, 18)
	var tween := button.create_tween()
	tween.tween_property(button, "position", target, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	TideFx.splash(self, button.position + button.size * Vector2(0.5, 0.4), 10)


func _stagger(node: Control, delay: float, from_scale: float, from_deg: float) -> void:
	node.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_interval(delay)
	tween.tween_callback(
		func() -> void:
			node.modulate.a = 1.0
			TideFx.pop_in(node, from_scale, from_deg)
	)


func close() -> void:
	hide()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
