class_name TideShowcase
extends Control
## Витрина TIDECUT: прогоняет все экраны интерфейса на синтетическом море
## и снимает PNG в shots/. Нужна для дизайн-приёмки без запуска боя.
##
## Экран боевого HUD здесь кормится фиктивным состоянием: это проверка
## композиции и типографики, а не геймплея.

var stage: TideStage
var hud: TideHud
var upgrade: TideUpgradeScreen
var journal: TidePauseJournal
var report: TideGameOverReport
var menu: TideMainMenu
var _clock := 0.0
var _sea: Control


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = load("res://assets/ui/tide_theme.tres")
	stage = TideStage.new()
	add_child(stage)
	var canvas := stage.canvas
	var backdrop := ColorRect.new()
	backdrop.color = TideTokens.INK
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	TideKit.place(backdrop, Rect2(Vector2.ZERO, TideTokens.BASE))
	canvas.add_child(backdrop)
	_sea = Control.new()
	_sea.mouse_filter = Control.MOUSE_FILTER_IGNORE
	TideKit.place(_sea, Rect2(Vector2.ZERO, TideTokens.BASE))
	_sea.draw.connect(_draw_sea)
	canvas.add_child(_sea)
	TideKit.isobaths(canvas, Rect2(Vector2.ZERO, TideTokens.BASE), 0.07, 34.0)

	hud = TideHud.new()
	canvas.add_child(hud)
	upgrade = TideUpgradeScreen.new()
	canvas.add_child(upgrade)
	journal = TidePauseJournal.new()
	canvas.add_child(journal)
	report = TideGameOverReport.new()
	canvas.add_child(report)
	menu = TideMainMenu.new()
	canvas.add_child(menu)
	menu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)
	if OS.has_environment("TIDE_SHOWCASE_QUIT"):
		_run_sequence.call_deferred()


func _process(delta: float) -> void:
	_clock += delta
	if hud != null and hud.visible:
		hud.push(_hud_state())


func _draw_sea() -> void:
	# Синтетическое море: плоские полосы воды и пенные штрихи.
	_sea.draw_rect(Rect2(0, 0, 1920, 1080), TideTokens.ink_alpha(0.0))
	for band in range(5):
		var y := 300.0 + float(band) * 130.0
		var color := TideTokens.deep_alpha(0.18 + 0.05 * float(band))
		_sea.draw_rect(Rect2(0, y, 1920, 96), color)
		for dash in range(18):
			var x := 40.0 + float(dash) * 112.0 + float(band) * 37.0
			var wave := TideShapes.plate(Vector2(58.0, 3.0), 2.0)
			TideShapes.fill(_sea, TideShapes.offset(wave, Vector2(x, y + 22.0)), TideTokens.foam_alpha(0.12))
	var hull := TideShapes.hull(Vector2(150, 260))
	TideShapes.fill(_sea, TideShapes.offset(hull, Vector2(900, 420)), TideTokens.foam_alpha(0.3))


func _hud_state() -> Dictionary:
	var ratio := 0.62 + 0.24 * sin(_clock * 0.4)
	return {
		"engaged": true,
		"hp01": 0.42,
		"xp": 13.0,
		"xp_needed": 24.0,
		"level": 6,
		"seconds": 252.0,
		"duration": 300.0,
		"wave": "V · КРУПНАЯ ЦЕЛЬ",
		"loot": 37,
		"weapons": "НОС ГОТОВ · БОРТА 0.8 с · Q ГОТОВ · КОРМА 2.4 с",
		"contacts": [
			{"offset": Vector2(-18, 24), "kind": 0, "elite": false},
			{"offset": Vector2(22, -16), "kind": 2, "elite": false},
			{"offset": Vector2(8, 34), "kind": 1, "elite": false},
			{"offset": Vector2(-30, -22), "kind": 0, "elite": true},
		],
		"loot_dots": [Vector2(12, 8), Vector2(-8, 28), Vector2(28, 16), Vector2(-24, -6)],
		"forward": Vector2(0.2, -1.0).normalized(),
		"shoal": false,
		"boss":
		{
			"ratio": ratio,
			"phase": 2,
			"remaining": 48,
		},
	}


func _upgrade_entries() -> Array:
	return [
		{
			"title": "Усиленные снаряды",
			"desc": "+8 базового урона орудий",
			"preview": "Нос: 22 → 30\nБорт: 15.4 → 21.0",
		},
		{
			"title": "Форсированный двигатель",
			"desc": "+12% базового хода, разгона и торможения",
			"preview": "Ход: 1.00× → 1.12×",
		},
		{
			"title": "Резонатор",
			"desc": "+5 м радиуса и +15 урона импульса",
			"preview": "Радиус: 13 → 18 м\nУрон: 35 → 50",
		},
	]


func _journal_data() -> Dictionary:
	return {
		"clock": "04:12",
		"entries":
		[
			{"clock": "04:12", "title": "Резонатор", "evolution": false},
			{"clock": "03:20", "title": "Скоростные затворы", "evolution": false},
			{"clock": "02:41", "title": "Бортовая картечь", "evolution": false},
			{"clock": "01:55", "title": "Сборщики трофеев", "evolution": false},
			{"clock": "01:06", "title": "Пробивной гарпун", "evolution": true},
			{"clock": "00:28", "title": "Усиленные снаряды", "evolution": false},
		],
		"stats": "ВРЕМЯ ...... 04:12\nУРОВЕНЬ .... 06\nУНИЧТОЖЕНО . 214\nДОБЫЧА ..... 37\nКОРПУС ..... 58%\nФАЗА ....... V\n\nЗАПИСЕЙ В ЖУРНАЛЕ: 6",
		"debug":
		{
			"god": false,
			"clear": false,
			"spheres": true,
			"gravity": false,
			"effects": true,
			"fireballs": true,
		},
	}


func _report_data() -> Dictionary:
	return {
		"win": false,
		"title": "ПРОПАЛ БЕЗ ВЕСТИ",
		"kicker": "РАПОРТ КАПИТАНА · ВАХТА ЗАКРЫТА",
		"verdict": "КОРПУС ПОТЕРЯН",
		"protocol": "ВРЕМЯ ВАХТЫ ................. 04:12\nДОБЫЧА ..................... 37\nУРОВЕНЬ .................... 06\nУНИЧТОЖЕНО ................. 214\nПОЛУЧЕНО КОРПУСОМ .......... 240\nВЗЯТО МОДУЛЕЙ .............. 6\nПОСЛЕДНИЙ УДАР ............. РИФ\nКОРПУС ..................... 0%",
		"build": "СБОРКА\nУРОН НОС     30\nУРОН БОРТ    21.0\nКАРТЕЧЬ      ×2\nПЕРЕЗАРЯДКА  0.57 / 1.10\nДВИГАТЕЛЬ    1/3\nРУЛЬ         1/3\nQ            50 / 18 М\nКОРМА        1/3\nСФЕРЫ        0/3\nСТЯГИВАНИЕ  0/3",
		"log": "ПОСЛЕДНИЕ ЗАПИСИ\n04:12 · Резонатор\n03:20 · Скоростные затворы\n02:41 · Бортовая картечь\n01:55 · Сборщики трофеев",
	}


func _run_sequence() -> void:
	var shot := TideScreenshot.new()
	add_child(shot)
	upgrade.open(_upgrade_entries(), 5, 6, 2, true)
	await _wait(46)
	await shot.capture("tide_01_upgrade")
	upgrade._pick(1)
	await _wait(12)
	await shot.capture("tide_02_upgrade_stamp")
	await _wait(30)
	upgrade.hide()

	hud.show()
	await _wait(40)
	print(
		"[TIDE SHOWCASE] экран=", get_viewport_rect().size,
		" окно=", DisplayServer.window_get_size(),
		" холст=", stage.size, " масштаб=", stage.canvas.scale,
		" плита_осадки=", hud._hull_plate.get_global_rect(),
		" ярлык_осадки=", hud._hp_tag.get_global_rect()
	)
	await shot.capture("tide_03_hud")

	hud.hide()
	journal.open(_journal_data())
	await _wait(44)
	await shot.capture("tide_04_journal")
	journal.hide()

	report.open(_report_data())
	await _wait(50)
	await shot.capture("tide_05_report")
	report.hide()

	menu.open()
	await _wait(44)
	await shot.capture("tide_06_menu")

	print("[TIDE SHOWCASE] кадры сняты")
	await _wait(6)
	get_tree().quit(0)


func _wait(frames: int) -> void:
	for _index in range(maxi(1, frames)):
		await get_tree().process_frame
