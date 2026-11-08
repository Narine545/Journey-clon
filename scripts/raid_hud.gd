class_name RaidHud
extends Control
## Small native HUD. No second viewport, imported assets, or font dependency.
var run: RaidRun
var _launch: Button
var _pause: Button
var _modal: PanelContainer
var _title: Label
var _detail: Label
var _cards: HBoxContainer
var _card_buttons: Array[Button] = []
var _resume: Button
var _retry: Button
var _bar_skin: StyleBoxFlat
var _leave: Button


func setup() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar_skin = StyleBoxFlat.new()
	_bar_skin.bg_color = Color(0.025, 0.06, 0.08, 0.88)
	_launch = Button.new()
	_launch.text = "НАЧАТЬ РЕЙД · ПРОТОТИП"
	_launch.pressed.connect(run.start)
	add_child(_launch)
	_pause = Button.new()
	_pause.text = "ПАУЗА · Esc"
	_pause.pressed.connect(run.toggle_pause)
	add_child(_pause)
	_modal = PanelContainer.new()
	var skin := StyleBoxFlat.new()
	skin.bg_color = Color("101f28")
	skin.border_color = Color("69b8ad")
	skin.set_border_width_all(2)
	skin.set_corner_radius_all(12)
	skin.content_margin_left = 24
	skin.content_margin_right = 24
	skin.content_margin_top = 24
	skin.content_margin_bottom = 24
	_modal.add_theme_stylebox_override("panel", skin)
	add_child(_modal)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	_modal.add_child(box)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 25)
	box.add_child(_title)
	_detail = Label.new()
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_detail)
	_cards = HBoxContainer.new()
	_cards.add_theme_constant_override("separation", 14)
	box.add_child(_cards)
	for index in range(3):
		var card := Button.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.custom_minimum_size = Vector2(0, 190)
		card.add_theme_font_size_override("font_size", 15)
		card.pressed.connect(run.choose.bind(index))
		_cards.add_child(card)
		_card_buttons.append(card)
	_resume = Button.new()
	_resume.text = "ПРОДОЛЖИТЬ"
	_resume.pressed.connect(run.toggle_pause)
	box.add_child(_resume)
	_retry = Button.new()
	_retry.text = "ЕЩЁ ОДИН РЕЙД"
	_retry.pressed.connect(run.restart)
	box.add_child(_retry)
	_leave = Button.new()
	_leave.text = "ВЕРНУТЬСЯ К ПЛАВАНИЮ"
	_leave.pressed.connect(run.leave)
	box.add_child(_leave)
	resized.connect(_layout)
	_layout()
	refresh()


func _layout() -> void:
	if _launch == null:
		return
	_launch.position = Vector2(size.x - 260, size.y - 104)
	_launch.size = Vector2(236, 36)
	_pause.position = Vector2(size.x - 170, 28)
	_pause.size = Vector2(146, 32)
	var width := minf(960.0, size.x - 32.0)
	_modal.position = Vector2((size.x - width) * 0.5, maxf(90.0, size.y * 0.5 - 180.0))
	_modal.size.x = width


func refresh() -> void:
	if _launch == null:
		return
	_launch.visible = not run.engaged()
	_pause.visible = run.state == RaidRun.State.RUNNING
	_modal.visible = run.modal()
	_cards.visible = run.state == RaidRun.State.CHOOSING
	_resume.visible = run.state == RaidRun.State.PAUSED
	_retry.visible = run.state in [RaidRun.State.WON, RaidRun.State.LOST]
	_leave.visible = run.state != RaidRun.State.CHOOSING
	match run.state:
		RaidRun.State.CHOOSING:
			_title.text = "НОВЫЙ МОДУЛЬ · УРОВЕНЬ %d" % (run.level + 1)
			_detail.text = "Бой и судно остановлены. Выберите улучшение сборки."
			for index in range(run.choices.size()):
				var data: Array = RaidRun.UPGRADES[run.choices[index]]
				_card_buttons[index].text = (
					"%s\n\n%s\n\n%s"
					% [data[0], _wrap(String(data[1])), run.upgrade_preview(run.choices[index])]
				)
		RaidRun.State.PAUSED:
			_title.text = "РЕЙД ПРИОСТАНОВЛЕН"
			_detail.text = "Курс и перезарядки сохранены. При выходе вернётся дорейдовая прочность."
		RaidRun.State.WON:
			_title.text = "РЕЙД ЗАВЕРШЁН · ЦЕЛЬ УНИЧТОЖЕНА"
			_detail.text = _summary()
		RaidRun.State.LOST:
			_title.text = (
				"РЕЙД ЗАВЕРШЁН · "
				+ ("КОРПУС ПОТЕРЯН" if run.main.boat.hull_hp <= 0.0 else "ВРЕМЯ ВЫШЛО")
			)
			_detail.text = _summary()
	_modal.reset_size()
	_layout()


func _summary() -> String:
	return (
		(
			"Время %02d:%02d · уничтожено %d · уровень %d.\n"
			+ "Собрано опыта: %d · оставлено на воде: %d."
		)
		% [
			floori(run.elapsed / 60.0),
			int(run.elapsed) % 60,
			run.kills,
			run.level,
			run.salvage.collected,
			run.salvage.remaining()
		]
	)


func _text(at: Vector2, text: String, font_size: int = 16, color: Color = Color("dfefea")) -> void:
	draw_string(ThemeDB.fallback_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _bar(rect: Rect2, amount: float, color: Color) -> void:
	draw_style_box(_bar_skin, rect)
	draw_rect(
		Rect2(rect.position, Vector2(rect.size.x * clampf(amount, 0.0, 1.0), rect.size.y)), color
	)


func _wrap(text: String) -> String:
	var result := ""
	var line := ""
	for word in text.split(" "):
		if line.length() + word.length() > 25:
			result += line + "\n"
			line = ""
		line += (" " if not line.is_empty() else "") + word
	return result + line


func _draw() -> void:
	if run == null or not run.engaged():
		return
	var main := run.main
	var accent := Color("78dfcb")
	_bar(Rect2(0, 0, size.x, 6), float(run.xp) / run.xp_needed, accent)
	draw_rect(Rect2(20, 22, 275, 77), Color(0.025, 0.06, 0.08, 0.9))
	_text(Vector2(34, 46), "КОРПУС %d%% · УРОВЕНЬ %d" % [int(ceil(main.boat.hull_hp)), run.level])
	_bar(Rect2(34, 58, 245, 6), main.boat.hull_hp / 100.0, Color("ed846d"))
	_text(
		Vector2(34, 86), "ОПЫТ %d/%d · ЦЕЛЕЙ %d" % [run.xp, run.xp_needed, run.enemies.size()], 13
	)
	_text(
		Vector2(size.x * 0.5 - 48, 45),
		"%02d:%02d" % [floori(run.elapsed / 60.0), int(run.elapsed) % 60],
		24
	)
	if run.elapsed >= 225.0 and not run.boss_spawned:
		_text(Vector2(size.x * 0.5 - 165, 78), "КРУПНАЯ ЦЕЛЬ ПРИБЛИЖАЕТСЯ", 17, Color("ffb37e"))
	for enemy in run.enemies:
		if int(enemy["kind"]) == 3:
			_bar(
				Rect2(size.x * 0.3, 65, size.x * 0.4, 8),
				float(enemy["hp"]) / float(enemy["max_hp"]),
				Color("f05c75")
			)
	var center := Vector2(size.x - 104, 155)
	draw_circle(center, 66, Color(0.025, 0.06, 0.08, 0.88))
	draw_arc(center, 66, 0, TAU, 48, Color("497f7d"), 1.0, true)
	for enemy in run.enemies:
		var relative: Vector2 = (enemy["at"] - run.boat_at()) * (66.0 / 55.0)
		if relative.length() < 64:
			draw_circle(
				center + relative,
				3 if int(enemy["kind"]) < 3 else 5,
				RaidRun.COLORS[int(enemy["kind"])]
			)
	for entry in run.salvage.drops:
		var relative: Vector2 = (entry["at"] - run.boat_at()) * (66.0 / 55.0)
		if relative.length() < 64:
			draw_circle(center + relative, 1.5, accent)
	draw_line(center, center + run.forward() * 12, accent, 2.0, true)
	draw_circle(center, 3, accent)
	_text(center + Vector2(-53, 86), "РАДАР · 55 М", 12)
	var panel := Rect2(Vector2(size.x * 0.5 - 295, size.y - 108), Vector2(590, 88))
	draw_rect(panel, Color(0.025, 0.06, 0.08, 0.9))
	_text(
		panel.position + Vector2(15, 24),
		(
			"НОС: %.0f   |   БОРТА: ×%d   |   [Q] ИМПУЛЬС: %s"
			% [
				run.damage,
				run.pellets,
				"ГОТОВ" if run.pulse_cooldown <= 0 else "%.1f с" % run.pulse_cooldown
			]
		),
		15,
		accent
	)
	_text(
		panel.position + Vector2(15, 48),
		"Зелёные трофеи — опыт · подойдите корпусом или плашкоутом",
		12
	)
	_text(
		panel.position + Vector2(15, 72), "WASD — курс · M/F/F2 — осмотр с паузой · Esc — пауза", 12
	)
	if main.shoals != null and main.shoals.warning:
		_text(
			Vector2(size.x * 0.5 - 165, 110), "ОТМЕЛЬ ПО КУРСУ — СНИЗЬТЕ ХОД", 15, Color("ffb37e")
		)
	if main.debug_panel_visible:
		var debug_at := Vector2(22, size.y - 250)
		draw_rect(Rect2(debug_at, Vector2(310, 115)), Color(0.025, 0.06, 0.08, 0.9))
		_text(
			debug_at + Vector2(12, 24),
			"ПРОВЕРКА · %d FPS · [0] скрыть" % Engine.get_frames_per_second(),
			14
		)
		_text(debug_at + Vector2(12, 49), "[4] ресурсы · [5] ночь · [6] к бую", 13)
		_text(debug_at + Vector2(12, 74), "[7] время · [8/9] ночной объём", 13)
		_text(debug_at + Vector2(12, 99), "[H] прожектор · это тестовые команды", 13)
	_draw_telegraphs()
	if run._hurt_timer > 0.45:
		draw_rect(Rect2(3, 3, size.x - 6, size.y - 6), Color(1, 0.3, 0.25, 0.6), false, 5)
	if run.modal():
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.005, 0.015, 0.025, 0.65))


func _draw_telegraphs() -> void:
	var camera := run.main.camera
	for enemy in run.enemies:
		var kind: int = enemy["kind"]
		var timer: float = enemy["timer"]
		if not ((kind == 1 and timer < 1.1) or (kind >= 2 and timer < 0.9)):
			continue
		var at: Vector2 = enemy["at"]
		var world_at := Vector3(at.x, Coast.SEA_LEVEL + 1.5, at.y)
		if camera.is_position_behind(world_at):
			continue
		var screen := camera.unproject_position(world_at)
		draw_arc(screen, 18, 0, TAU, 24, Color("ffca76"), 2, true)
		if kind == 1:
			var aim: Vector2 = enemy["aim"]
			var end := world_at + Vector3(aim.x, 0, aim.y) * 10.0
			draw_line(screen, camera.unproject_position(end), Color(1, 0.6, 0.3, 0.7), 2, true)
	if run._pulse_flash > 0:
		var at := run.main.boat.global_position
		var screen := camera.unproject_position(at)
		var edge := camera.unproject_position(at + camera.global_basis.x * run.pulse_radius)
		draw_arc(
			screen,
			screen.distance_to(edge) * (1.0 - run._pulse_flash / 0.5),
			0,
			TAU,
			64,
			Color(0.4, 1, 0.85, run._pulse_flash * 2.0),
			2,
			true
		)
