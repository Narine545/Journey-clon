class_name TideGameOverReport
extends Control
## Game over «ПРОПАЛ БЕЗ ВЕСТИ»: телеграмма-рапорт на пене, двойная рамка,
## заголовок flare с сильным наклоном, статистика протоколом моноширинным.
## Появление — медленный нырок сверху вниз, затем штамп.

signal restart_requested
signal menu_requested

var _page: Control
var _title: TideTitleLabel
var _kicker: Label
var _protocol: Label
var _build: Label
var _log: Label
var _stamp: TideStamp
var _restart: TideButton
var _menu: TideButton
var _verdict: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build()


func _build() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = TideTokens.ink_alpha(0.84)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	TideKit.place(backdrop, Rect2(Vector2.ZERO, TideTokens.BASE))
	add_child(backdrop)
	TideKit.isobaths(self, Rect2(Vector2.ZERO, TideTokens.BASE), 0.065, 38.0)

	_page = Control.new()
	_page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_page.size = TideTokens.BASE
	add_child(_page)

	# Двойная рамка рапорта: верхняя — алая подложка, нижняя — пена.
	var under := TideKit.panel(
		_page, Rect2(276, 168, 1140, 792), TideTokens.deep_alpha(0.95), Color(0, 0, 0, 0), false, 1.8, true
	)
	under.skew = 0.0
	var sheet := TideKit.panel(
		_page, Rect2(258, 142, 1140, 792), TideTokens.FOAM, TideTokens.FLARE, true, 0.8
	)
	sheet.hatch_color = TideTokens.deep_alpha(0.16)
	sheet.hatch_spacing = 7.0
	sheet.border_color = TideTokens.ink_alpha(0.5)
	sheet.border_width = 3.0

	_title = TideKit.title(_page, "ПРОПАЛ БЕЗ ВЕСТИ", Vector2(300, 74), 100, -11.0, TideTokens.FLARE, 10)
	TideKit.fit_title(_title, 1060.0, 100, 62)
	_kicker = TideKit.mono(_page, "РАПОРТ КАПИТАНА · ВАХТА ЗАКРЫТА", Vector2(310, 226), 21, TideTokens.SONAR, -2.0)
	_verdict = TideKit.label(
		_page, "", Rect2(312, 262, 1000, 66), 2, 32, TideTokens.INK, -1.0, false
	)
	_protocol = TideKit.label(
		_page, "", Rect2(312, 340, 630, 420), 1, 23, TideTokens.INK, 0.0, false
	)
	_protocol.add_theme_constant_override("line_spacing", 13)
	_build = TideKit.label(
		_page, "", Rect2(960, 340, 400, 300), 1, 20, TideTokens.ink_alpha(0.72), 0.0, false
	)
	_build.add_theme_constant_override("line_spacing", 11)
	_log = TideKit.label(
		_page, "", Rect2(960, 650, 400, 230), 1, 17, TideTokens.FLARE, -0.6, true
	)
	_log.add_theme_constant_override("line_spacing", 8)

	_stamp = TideKit.stamp(self, "SOS", Rect2(1046, 214, 296, 104), TideTokens.FLARE, 44, -12.0)

	_restart = TideKit.button(
		self,
		"НОВАЯ ВАХТА",
		Rect2(322, 872, 540, 106),
		TideButton.Shape.SOLID,
		TideTokens.SONAR,
		0,
		46,
		TideTokens.INK,
		-2.2
	)
	_restart.pressed.connect(func() -> void: restart_requested.emit())
	_menu = TideKit.button(
		self,
		"В МЕНЮ",
		Rect2(932, 892, 320, 84),
		TideButton.Shape.OUTLINE,
		TideTokens.FLARE,
		0,
		28,
		TideTokens.FLARE,
		1.8
	)
	_menu.pressed.connect(func() -> void: menu_requested.emit())


## report: {win, title, verdict, clock, loot, level, kills, received, modules,
##          protocol_lines, build_lines, log_lines}
func open(report: Dictionary) -> void:
	show()
	var win: bool = report.get("win", false)
	_title.text = String(report.get("title", "ПРОПАЛ БЕЗ ВЕСТИ")).to_upper()
	_title.paper_color = TideTokens.SONAR if win else TideTokens.FLARE
	_title._apply()
	TideKit.fit_title(_title, 1060.0, 100, 52)
	_kicker.text = String(report.get("kicker", "РАПОРТ КАПИТАНА · ВАХТА ЗАКРЫТА"))
	_verdict.text = String(report.get("verdict", "")).to_upper()
	_protocol.text = String(report.get("protocol", ""))
	_build.text = String(report.get("build", ""))
	_log.text = String(report.get("log", ""))
	_stamp.text = "ЗАЧТЕНО" if win else "SOS"
	_stamp.tint = TideTokens.SONAR if win else TideTokens.FLARE
	_stamp.point_size = 40
	_stamp.queue_redraw()
	_play_entrance()


func _play_entrance() -> void:
	_stamp.hide()
	_page.position = Vector2(0.0, -1180.0)
	_page.rotation = deg_to_rad(-2.2)
	_page.pivot_offset = TideTokens.BASE * 0.5
	var tween := create_tween()
	tween.set_parallel(true)
	# «Нырок»: медленный, но не LINEAR — кубический разгон и мягкая посадка.
	tween.tween_property(_page, "position:y", 0.0, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(_page, "rotation", deg_to_rad(0.0), 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var stamp_tween := create_tween()
	stamp_tween.tween_interval(0.52)
	stamp_tween.tween_callback(func() -> void: _stamp.hit(self))
	stamp_tween.tween_callback(func() -> void: TideFx.shake(self, 4.0, 0.12))
