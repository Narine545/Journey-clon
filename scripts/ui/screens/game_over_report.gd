class_name TideGameOverReport
extends Control
## Game over «ПРОПАЛ БЕЗ ВЕСТИ»: телеграмма-рапорт на пене, двойная рамка,
## заголовок flare с сильным наклоном, статистика протоколом моноширинным.
## Появление — медленный нырок сверху вниз, затем штамп.

signal restart_requested
signal menu_requested

const SHEET_RECT := Rect2(250, 150, 1200, 840)
const SHEET_DEG := 1.6
const MARGIN := 62.0

var _page: Control
var _sheet: Control
var _title: TideTitleLabel
var _kicker: Label
var _protocol: Label
var _build_label: Label
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

	# Вся телеграмма — одна группа: она «ныряет» целиком.
	_page = TideKit.group(self, Rect2(Vector2.ZERO, TideTokens.BASE))
	# Подложка — второй лист под рапортом, повёрнут в другую сторону.
	var under := TideKit.panel(
		_page, SHEET_RECT.grow(-6.0), TideTokens.DEEP, Color(0, 0, 0, 0), true, -1.8
	)
	under.hatch_color = TideTokens.foam_alpha(0.08)
	under.hatch_spacing = 8.0
	_sheet = TideKit.group(_page, SHEET_RECT, SHEET_DEG)
	var paper := TideKit.panel(
		_sheet, Rect2(Vector2.ZERO, SHEET_RECT.size), TideTokens.FOAM, TideTokens.FLARE, true
	)
	paper.hatch_color = TideTokens.deep_alpha(0.12)
	paper.hatch_spacing = 7.0
	paper.underprint_offset = Vector2(12.0, 14.0)
	paper.double_frame = true
	paper.frame_inset = 22.0

	var inner := SHEET_RECT.size.x - MARGIN * 2.0
	# Заголовок наполовину свисает с верхней кромки листа — коллаж.
	_title = TideKit.headline(
		_sheet, "ПРОПАЛ БЕЗ ВЕСТИ", Vector2(MARGIN - 20.0, -62.0), inner - 60.0, 92,
		TideTokens.FLARE, 10, -12.0
	)
	_kicker = TideKit.text(
		_sheet, "РАПОРТ КАПИТАНА · ВАХТА ЗАКРЫТА", Vector2(MARGIN, 74), 1, 18,
		TideTokens.ink_alpha(0.6), inner
	)
	_verdict = TideKit.text(_sheet, "КОРПУС ПОТЕРЯН", Vector2(MARGIN, 100), 2, 34, TideTokens.INK, inner)
	TideKit.poly(
		_sheet,
		PackedVector2Array([
			Vector2(MARGIN, 160), Vector2(MARGIN + inner, 160),
			Vector2(MARGIN + inner, 164), Vector2(MARGIN, 164),
		]),
		TideTokens.INK
	)
	_protocol = TideKit.block(
		_sheet, "", Rect2(MARGIN, 186, 560, 420), 1, 22, TideTokens.INK, 13
	)
	# Вертикальная линейка между протоколом и сборкой.
	TideKit.poly(
		_sheet,
		PackedVector2Array([Vector2(646, 186), Vector2(649, 186), Vector2(649, 604), Vector2(646, 604)]),
		TideTokens.ink_alpha(0.3)
	)
	_build_label = TideKit.block(
		_sheet, "", Rect2(680, 186, inner - 618.0, 290), 1, 17, TideTokens.ink_alpha(0.78), 3
	)
	_log = TideKit.block(
		_sheet, "", Rect2(680, 488, inner - 618.0, 130), 1, 16, TideTokens.FLARE, 2
	)

	_restart = TideKit.button(
		_sheet,
		"НОВАЯ ВАХТА",
		Rect2(MARGIN + 20.0, 660, 560, 112),
		TideButton.Shape.SOLID,
		TideTokens.SONAR,
		0,
		50,
		TideTokens.INK,
		-1.4
	)
	_restart.pressed.connect(func() -> void: restart_requested.emit())
	_menu = TideKit.button(
		_sheet,
		"В МЕНЮ",
		Rect2(MARGIN + 650.0, 680, 300, 80),
		TideButton.Shape.SOLID,
		TideTokens.FLARE,
		0,
		30,
		TideTokens.FOAM,
		1.4
	)
	_menu.pressed.connect(func() -> void: menu_requested.emit())

	add_child(TideFx.bob(_sheet, SHEET_DEG, 0.5, 3.0, 0.9))
	add_child(TideFx.bob(under, -1.8, 0.9, 2.6, 3.0))

	_stamp = TideKit.stamp(
		_sheet, "SOS", Rect2(SHEET_RECT.size.x - 372.0, 36, 310, 130), TideTokens.FLARE, 64, -12.0
	)


## report: {win, title, kicker, verdict, protocol, build, log}
func open(report: Dictionary) -> void:
	show()
	var win: bool = report.get("win", false)
	_title.paper_color = TideTokens.SONAR if win else TideTokens.FLARE
	_title.set_title(String(report.get("title", "ПРОПАЛ БЕЗ ВЕСТИ")))
	_kicker.text = String(report.get("kicker", "РАПОРТ КАПИТАНА · ВАХТА ЗАКРЫТА"))
	var verdict := String(report.get("verdict", "")).to_upper()
	_verdict.text = verdict
	_verdict.add_theme_font_size_override(
		"font_size",
		TideTokens.fit_point(TideTokens.title_font(), verdict, SHEET_RECT.size.x - MARGIN * 2.0 - 380.0, 34, 18)
	)
	_protocol.text = String(report.get("protocol", ""))
	_build_label.text = String(report.get("build", ""))
	_log.text = String(report.get("log", ""))
	_stamp.text = "ЗАЧТЕНО" if win else "SOS"
	_stamp.tint = TideTokens.SONAR if win else TideTokens.FLARE
	_stamp.queue_redraw()
	_play_entrance()


func _play_entrance() -> void:
	_stamp.hide()
	_page.position = Vector2(0.0, -1180.0)
	_page.rotation = deg_to_rad(-3.0)
	var tween := create_tween()
	tween.set_parallel(true)
	# «Нырок»: медленный, но не LINEAR — лист тонет сверху вниз и садится
	# с лёгким перелётом, как брошенный в воду.
	tween.tween_property(_page, "position:y", 0.0, 0.46).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_page, "rotation", 0.0, 0.46).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var stamp_tween := create_tween()
	stamp_tween.tween_interval(0.5)
	stamp_tween.tween_callback(func() -> void: _stamp.hit(_sheet))
	stamp_tween.tween_callback(func() -> void: TideFx.shake(self, 4.0, 0.12))
	stamp_tween.tween_callback(
		func() -> void: TideFx.splash(self, Vector2(SHEET_RECT.position.x + 320.0, SHEET_RECT.end.y), 14)
	)
