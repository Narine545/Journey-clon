class_name RaidHud
extends Control
## Small native HUD. No second viewport, imported assets, or font dependency.
var run: RaidRun
var _launch: Button
var _pause: Button
var _modal_scroll: ScrollContainer
var _modal: PanelContainer
var _title: Label
var _results: GridContainer
var _result_columns: Array[Label] = []
var _modal_footer: VBoxContainer
var _detail: Label
var _cards: GridContainer
var _modal_content: VBoxContainer
var _card_buttons: Array[Button] = []
var _reroll: Button
var _resume: Button
var _retry: Button
var _bars: Array[ColorRect] = []
var _bar_index := 0
var _title_material: ShaderMaterial
var _sphere_toggle: CheckButton
var _god_toggle: CheckButton
var _clear_toggle: CheckButton
var _fx_toggle: CheckButton
var _leave: Button


func setup() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ui_theme := Theme.new()
	ui_theme.default_font_size = 18
	theme = ui_theme
	for _index in range(3):
		var bar := ColorRect.new()
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.visible = false
		var bar_material := ShaderMaterial.new()
		bar_material.shader = preload("res://shaders/raid_progress.gdshader")
		bar.material = bar_material
		add_child(bar)
		_bars.append(bar)
	_fx_toggle = CheckButton.new()
	_fx_toggle.text = "ЭФФЕКТЫ"
	_fx_toggle.button_pressed = run.effects_enabled
	_fx_toggle.toggled.connect(_set_effects)
	add_child(_fx_toggle)
	_sphere_toggle = CheckButton.new()
	_sphere_toggle.text = "ТЕСТ: СФЕРИЧЕСКИЕ МИНЫ"
	_sphere_toggle.tooltip_text = "Автовыпуск за кормой. Толчок при раскрытии, волны при схлопывании. Без урона/щита."
	_sphere_toggle.toggled.connect(run.sphere_mines.set_enabled)
	add_child(_sphere_toggle)
	_god_toggle = CheckButton.new()
	_god_toggle.text = "БЕССМЕРТИЕ"
	_god_toggle.tooltip_text = "Отладка: блокирует урон корпусу, но не останавливает таймер рейда."
	_god_toggle.toggled.connect(_set_invulnerable)
	add_child(_god_toggle)
	_clear_toggle = CheckButton.new()
	_clear_toggle.text = "ЗАЧИСТКА ЭКРАНА"
	_clear_toggle.tooltip_text = (
		"Отладка: убивает врагов в кадре, пока включена. " + "Босс тоже погибает — победа."
	)
	_clear_toggle.toggled.connect(_set_clear_screen)
	add_child(_clear_toggle)
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
	var scroll := ScrollContainer.new()
	_modal_scroll = scroll
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var shell := VBoxContainer.new()
	shell.add_theme_constant_override("separation", 16)
	_modal.add_child(shell)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shell.add_child(scroll)
	_modal_footer = VBoxContainer.new()
	_modal_footer.add_theme_constant_override("separation", 12)
	_modal_footer.minimum_size_changed.connect(_layout, CONNECT_DEFERRED)
	shell.add_child(_modal_footer)
	var box := VBoxContainer.new()
	_modal_content = box
	box.minimum_size_changed.connect(_layout, CONNECT_DEFERRED)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 18)
	scroll.add_child(box)
	_title = Label.new()
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title.add_theme_font_size_override("font_size", 36)
	_title.add_theme_constant_override("outline_size", 2)
	_title.add_theme_color_override("font_outline_color", Color("08141d"))
	_title_material = ShaderMaterial.new()
	_title_material.shader = preload("res://shaders/raid_title.gdshader")
	_title.material = _title_material if run.effects_enabled else null
	_title.resized.connect(_sync_title)
	box.add_child(_title)
	_detail = Label.new()
	_detail.add_theme_font_size_override("font_size", 20)
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_detail)
	_results = GridContainer.new()
	_results.columns = 2
	_results.add_theme_constant_override("h_separation", 24)
	_results.add_theme_constant_override("v_separation", 18)
	box.add_child(_results)
	for _index in range(2):
		var column := Label.new()
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		column.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		column.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		column.add_theme_font_size_override("font_size", 20)
		_results.add_child(column)
		_result_columns.append(column)
	_cards = GridContainer.new()
	_cards.columns = 3
	_cards.add_theme_constant_override("h_separation", 16)
	_cards.add_theme_constant_override("v_separation", 16)
	box.add_child(_cards)
	for index in range(3):
		var card := Button.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.custom_minimum_size = Vector2(0, 240)
		card.add_theme_font_size_override("font_size", 20)
		card.pressed.connect(run.choose.bind(index))
		_cards.add_child(card)
		_card_buttons.append(card)
	_reroll = Button.new()
	_reroll.pressed.connect(run._reroll_choices)
	_modal_footer.add_child(_reroll)
	_resume = Button.new()
	_resume.text = "ПРОДОЛЖИТЬ"
	_resume.pressed.connect(run.toggle_pause)
	_modal_footer.add_child(_resume)
	_retry = Button.new()
	_retry.text = "ЕЩЁ ОДИН РЕЙД"
	_retry.pressed.connect(run.restart)
	_modal_footer.add_child(_retry)
	_leave = Button.new()
	_leave.text = "ВЕРНУТЬСЯ К ПЛАВАНИЮ"
	_leave.pressed.connect(run.leave)
	_modal_footer.add_child(_leave)
	resized.connect(_layout)
	_layout()
	refresh()


func _layout() -> void:
	if _launch == null:
		return
	_launch.position = Vector2(size.x - 324, size.y - 104)
	_launch.size = Vector2(300, 42)
	_pause.position = Vector2(size.x - 170, 28)
	_pause.size = Vector2(146, 32)
	_fx_toggle.position = Vector2(size.x - 190, 254)
	_fx_toggle.size = Vector2(166, 28)
	_sphere_toggle.position = Vector2(size.x - 310, 496)
	_sphere_toggle.size = Vector2(300, 30)
	_god_toggle.position = Vector2(size.x - 248, 420)
	_god_toggle.size = Vector2(224, 30)
	_clear_toggle.position = Vector2(size.x - 248, 458)
	_clear_toggle.size = Vector2(224, 30)
	var is_result := run.state in [RaidRun.State.WON, RaidRun.State.LOST]
	var width := minf(1280.0 if is_result else 1120.0, size.x - 32.0)
	_results.columns = 2 if width >= 1000.0 else 1
	_cards.columns = 3 if width >= 1000.0 else 1
	var height := minf(
		maxf(
			180.0,
			(
				_modal_content.get_combined_minimum_size().y
				+ _modal_footer.get_combined_minimum_size().y
				+ 64.0
			)
		),
		size.y - 32.0
	)
	_modal.size = Vector2(width, height)
	_modal.position = Vector2((size.x - width) * 0.5, maxf(16.0, (size.y - height) * 0.5))


func refresh() -> void:
	if _launch == null:
		return
	_launch.visible = not run.engaged()
	_fx_toggle.visible = run.engaged()
	if run.modal():
		run.damage_fx.reset()
	_sphere_toggle.visible = run.engaged()
	_sphere_toggle.disabled = run.state in [RaidRun.State.WON, RaidRun.State.LOST]
	_sphere_toggle.set_pressed_no_signal(run.sphere_mines.enabled)
	_god_toggle.visible = run.engaged()
	_clear_toggle.visible = run.engaged()
	_god_toggle.disabled = run.state in [RaidRun.State.WON, RaidRun.State.LOST]
	_clear_toggle.disabled = _god_toggle.disabled
	_god_toggle.set_pressed_no_signal(run.debug_invulnerable)
	_clear_toggle.set_pressed_no_signal(run.debug_clear_screen)
	for bar in _bars:
		bar.visible = false
	_pause.visible = run.state == RaidRun.State.RUNNING
	_modal.visible = run.modal()
	_results.visible = run.state in [RaidRun.State.WON, RaidRun.State.LOST]
	if _results.visible:
		_modal_scroll.set_deferred("scroll_vertical", 0)
		_result_columns[0].text = _combat_summary().strip_edges()
		_result_columns[1].text = (_build_summary() + "\n" + _evolution_summary()).strip_edges()
	_cards.visible = run.state == RaidRun.State.CHOOSING
	_reroll.visible = run.state == RaidRun.State.CHOOSING
	_reroll.text = "ПЕРЕБРОСИТЬ · осталось %d/%d" % [run.rerolls_left, RaidRun.REROLLS]
	_reroll.disabled = not run._can_reroll()
	_reroll.tooltip_text = "Без расхода XP. Хотя бы одна новая карточка. Две попытки на весь рейд."
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
	_title_material.set_shader_parameter(
		"fluid_top", Color("ffca91") if run.state == RaidRun.State.LOST else Color("a6ffe0")
	)
	_title_material.set_shader_parameter(
		"fluid_bottom", Color("e66e67") if run.state == RaidRun.State.LOST else Color("379dc7")
	)
	_modal.reset_size()
	_layout()


func _summary() -> String:
	return (
		(
			(
				"Время %02d:%02d · уничтожено %d · уровень %d.\n"
				+ "Базовый сбор: %d · осталось: %d.\nНачислено с бонусами: %d XP."
			)
			% [
				floori(run.elapsed / 60.0),
				int(run.elapsed) % 60,
				run.kills,
				run.level,
				run.salvage.collected,
				run.salvage.remaining(),
				run.xp_awarded
			]
		)
		+ (
			"\nОТЛАДОЧНЫЙ РЕЙД — бессмертие / зачистка использовались."
			if run.stats.debug_used
			else ""
		)
	)


func _combat_summary() -> String:
	var report := "\n\nФАКТИЧЕСКИЙ УРОН ПО ЦЕЛЯМ"
	var labels := ["Нос", "Борта", "Импульс Q", "Кормовые заряды"]
	var total: float = run.stats.total_damage()
	for index in range(labels.size()):
		var amount: float = run.stats.dealt[index]
		var share := amount * 100.0 / total if total > 0.0 else 0.0
		report += "\n%s: %.0f · %.0f%%" % [labels[index], amount, share]
	report += _incoming_summary()
	return report


func _evolution_summary() -> String:
	var names := ["Гарпун", "Резонанс", "Штормовая картечь", "Цепной подрыв"]
	var report := "ЭВОЛЮЦИИ (боевое время)"
	for index in range(names.size()):
		var seconds: float = run.stats.evolution_times[index]
		report += "\n%s: %s" % [names[index], _report_time(seconds)]
	return report


func _report_time(seconds: float) -> String:
	return "%02d:%02d" % [floori(seconds / 60.0), int(seconds) % 60] if seconds >= 0 else "—"


func _incoming_summary() -> String:
	var report := "\n\nПОЛУЧЕНО КОРПУСОМ: %.0f" % run.stats.received
	var labels := ["Контакт с врагами", "Вражеские снаряды", "Рифы", "Мели", "Прочее"]
	for index in range(labels.size()):
		var amount: float = run.stats.incoming[index]
		var share := amount * 100.0 / run.stats.received if run.stats.received > 0.0 else 0.0
		report += (
			"\n%s: %.0f · %.0f%% · ударов %d"
			% [labels[index], amount, share, run.stats.incoming_hits[index]]
		)
	if run.stats.last_cause >= 0:
		report += (
			"\nПоследний урон: %s · %s"
			% [labels[run.stats.last_cause], _report_time(run.stats.last_hit_at)]
		)
	else:
		report += "\nПоследний урон: —"
	report += (
		"\nРемонтных карточек: %d · восстановлено %.0f HP" % [run.stats.repairs, run.stats.repaired]
	)
	return report


func _build_summary() -> String:
	var report := "\n\nИТОГОВАЯ СБОРКА"
	report += (
		"\nУрон: нос %.0f / борт %.1f · картечь ×%d" % [run.damage, run.damage * 0.7, run.pellets]
	)
	report += (
		"\nПерезарядка: нос %.2f с / борта %.2f с"
		% [0.65 * run.reload_scale, 1.25 * run.reload_scale]
	)
	report += (
		"\nДвигатель %d/3 (×%.2f) · руль %d/3 (×%.2f)"
		% [run.speed_rank, run.speed_multiplier(), run.turn_rank, run.turn_multiplier()]
	)
	report += (
		"\nОпытная команда %d/4 (×%.2f) · притяжение %.0f м"
		% [run.xp_rank, run.xp_multiplier(), run.salvage.magnet_range]
	)
	report += (
		"\nQ: %.0f урона / %.0f м · применений %d"
		% [run.pulse_damage, run.pulse_radius, run.stats.pulses]
	)
	if run.stern_rank > 0:
		report += (
			"\nКорма %d/3: %.0f урона / %.0f м / %.1f с"
			% [
				run.stern_rank,
				RaidSternCharges.power(run.stern_rank),
				RaidSternCharges.radius(run.stern_rank),
				RaidSternCharges.interval(run.stern_rank)
			]
		)
		report += (
			"\nУстановлена в %s · сброшено %d · взорвано %d"
			% [
				_report_time(run.stats.stern_unlocked_at),
				run.stats.charges_dropped,
				run.stats.charges_exploded
			]
		)
	else:
		report += "\nКорма: не установлена"
	report += (
		"\nПеребросов использовано: %d/%d" % [RaidRun.REROLLS - run.rerolls_left, RaidRun.REROLLS]
	)
	return report


func _text(at: Vector2, text: String, font_size: int = 20, color: Color = Color("dfefea")) -> void:
	draw_string(ThemeDB.fallback_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _bar(rect: Rect2, amount: float, color: Color) -> void:
	if _bar_index >= _bars.size():
		return
	var bar := _bars[_bar_index]
	_bar_index += 1
	bar.position = rect.position
	bar.size = rect.size
	bar.visible = not run.modal()
	var bar_material := bar.material as ShaderMaterial
	bar_material.set_shader_parameter("progress", clampf(amount, 0.0, 1.0))
	bar_material.set_shader_parameter("bar_size", rect.size)
	bar_material.set_shader_parameter("fill_color", color)
	bar_material.set_shader_parameter("effect_time", run.elapsed)
	bar_material.set_shader_parameter("motion", 1.0 if run.effects_enabled else 0.0)


func _set_invulnerable(enabled: bool) -> void:
	run.debug_invulnerable = enabled
	run.stats.debug_used = run.stats.debug_used or enabled
	queue_redraw()


func _set_clear_screen(enabled: bool) -> void:
	run.debug_clear_screen = enabled
	run.stats.debug_used = run.stats.debug_used or enabled
	queue_redraw()


func _set_effects(enabled: bool) -> void:
	run.effects_enabled = enabled
	if not enabled:
		run.damage_fx.reset()
	if enabled:
		run.weapon_fx.preview()
	_title.material = _title_material if enabled else null
	queue_redraw()


func _sync_title() -> void:
	_title_material.set_shader_parameter("label_size", _title.size)


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
	_bar_index = 0
	for bar in _bars:
		bar.visible = false
	var main := run.main
	var available_speed := (
		BoatVessel.REVERSE_SPEED * main.boat.raid_speed_factor()
		if main.boat.speed < -0.05
		else main.boat.effective_max_speed()
	)
	var accent := Color("78dfcb")
	_bar(Rect2(0, 0, size.x, 10), float(run.xp) / run.xp_needed, accent)
	draw_rect(Rect2(20, 22, 310, 146), Color(0.025, 0.06, 0.08, 0.9))
	_text(Vector2(34, 46), "КОРПУС %d%% · УР. %d" % [int(ceil(main.boat.hull_hp)), run.level])
	_bar(Rect2(34, 58, 280, 9), main.boat.hull_hp / 100.0, Color("ed846d"))
	_text(Vector2(34, 86), "ОПЫТ %d/%d · ×%.2f" % [run.xp, run.xp_needed, run.xp_multiplier()], 16)
	_text(
		Vector2(34, 111),
		"ХОД %.1f/%.1f · РУЛЬ ×%.2f" % [main.boat.speed, available_speed, run.turn_multiplier()],
		15
	)
	_text(
		Vector2(34, 135),
		(
			"ДВИГ ×%.2f · КОРПУС −%d%% ХОДА"
			% [run.speed_multiplier(), roundi((1.0 - main.boat.hull_speed_factor()) * 100.0)]
		),
		14
	)
	_text(
		Vector2(34, 157),
		(
			"ФОРСАЖ: %.0f с (временный)" % main.overdrive_timer
			if main.overdrive_timer > 0.0
			else "БОНУСЫ — ДО КОНЦА РЕЙДА"
		),
		14
	)
	_text(
		Vector2(size.x * 0.5 - 48, 45),
		"%02d:%02d" % [floori(run.elapsed / 60.0), int(run.elapsed) % 60],
		30
	)
	if run.elapsed >= 225.0 and not run.boss_spawned:
		_text(Vector2(size.x * 0.5 - 180, 104), "КРУПНАЯ ЦЕЛЬ ПРИБЛИЖАЕТСЯ", 20, Color("ffb37e"))
	else:
		_text(Vector2(size.x * 0.5 - 150, 104), RaidWaves.label(run.elapsed), 18, accent)
	for enemy in run.enemies:
		if int(enemy["kind"]) == 3:
			_bar(
				Rect2(size.x * 0.3, 65, size.x * 0.4, 12),
				float(enemy["hp"]) / float(enemy["max_hp"]),
				Color("f05c75")
			)
			_text(
				Vector2(size.x * 0.3, 61),
				"КРУПНАЯ ЦЕЛЬ · ФАЗА %d" % RaidBoss.phase(enemy),
				16,
				Color("f5b4a4")
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
			if bool(enemy.get("elite", false)):
				draw_arc(center + relative, 6, 0, TAU, 16, Color("ffe144"), 1.5, true)
	for entry in run.salvage.drops:
		var relative: Vector2 = (entry["at"] - run.boat_at()) * (66.0 / 55.0)
		if relative.length() < 64:
			draw_circle(center + relative, 1.5, accent)
	draw_line(center, center + run.forward() * 12, accent, 2.0, true)
	draw_circle(center, 3, accent)
	_text(center + Vector2(-53, 86), "РАДАР · 55 М", 15)
	var roles := ["Преследователь", "Рывок", "Стрелок", "Босс"]
	for kind in range(4):
		var key_at := Vector2(size.x - 190, 314 + kind * 24)
		draw_circle(key_at, 4.0, RaidRun.COLORS[kind])
		_text(key_at + Vector2(12, 5), roles[kind], 16, RaidRun.COLORS[kind])
	var panel := Rect2(Vector2(size.x * 0.5 - 295, size.y - 108), Vector2(590, 88))
	draw_rect(panel, Color(0.025, 0.06, 0.08, 0.9))
	_text(
		panel.position + Vector2(15, 24),
		(
			"НОС%s: %.0f | БОРТА%s ×%d | Q %s: %s"
			% [
				"[П]" if run.piercing_harpoon else "",
				run.damage,
				"[Ш]" if run.storm_broadside else "",
				run.pellets,
				"РЕЗОНАНС" if run.resonant_pulse else "ИМПУЛЬС",
				"ГОТОВ" if run.pulse_cooldown <= 0 else "%.1f с" % run.pulse_cooldown
			]
		),
		18,
		accent
	)
	_text(
		panel.position + Vector2(15, 48),
		(
			(
				"КОРМА%s %d · заряд %.1f с · урон %.0f · радиус %.0f м"
				% [
					"[Ц]" if run.chain_mines else "",
					run.stern_rank,
					run.stern_charges.cooldown,
					RaidSternCharges.power(run.stern_rank),
					RaidSternCharges.radius(run.stern_rank)
				]
			)
			if run.stern_rank > 0
			else "Зелёные трофеи — опыт · подойдите корпусом или плашкоутом"
		),
		15
	)
	_text(
		panel.position + Vector2(15, 72), "WASD — курс · M/F/F2 — осмотр с паузой · Esc — пауза", 15
	)
	if main.shoals != null and main.shoals.warning:
		_text(
			Vector2(size.x * 0.5 - 190, 134), "ОТМЕЛЬ ПО КУРСУ — СНИЗЬТЕ ХОД", 18, Color("ffb37e")
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
	if run.modal():
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.005, 0.015, 0.025, 0.65))


func _draw_telegraphs() -> void:
	var camera := run.main.camera
	for enemy in run.enemies:
		if bool(enemy.get("elite", false)):
			_draw_elite_marker(enemy)
		var kind: int = enemy["kind"]
		var timer: float = enemy["timer"]
		if kind == 3:
			_draw_boss_warning(enemy)
			continue
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


func _draw_elite_marker(enemy: Dictionary) -> void:
	var at: Vector2 = enemy["at"]
	if at.distance_to(run.boat_at()) > 60.0 or float(enemy["hp"]) <= 0.0:
		return
	var world_at := Vector3(at.x, Coast.SEA_LEVEL + 2.0, at.y)
	var camera := run.main.camera
	if camera.is_position_behind(world_at):
		return
	var screen := camera.unproject_position(world_at)
	var ink := RaidRun.COLORS[1]
	draw_arc(screen, 26, 0, TAU, 24, ink, 2.0, true)
	var percent := ceili(100.0 * float(enemy["hp"]) / float(enemy["max_hp"]))
	_text(screen + Vector2(28, -28), "ЭЛИТА · %d%%" % percent, 18, ink)


func _draw_boss_warning(enemy: Dictionary) -> void:
	if not RaidBoss.preparing(enemy):
		return
	var camera := run.main.camera
	var at: Vector2 = enemy["at"]
	var origin := Vector3(at.x, Coast.SEA_LEVEL + 1.5, at.y)
	if camera.is_position_behind(origin):
		return
	var screen := camera.unproject_position(origin)
	var ink := Color("ffc18e") if int(enemy["boss_attack_phase"]) == 1 else Color("f789a4")
	var progress := 1.0 - float(enemy["boss_windup"]) / RaidBoss.warning_length(enemy)
	draw_arc(
		screen, 26, -PI * 0.5, -PI * 0.5 + TAU * clampf(progress, 0.0, 1.0), 40, ink, 3.0, true
	)
	for direction in RaidBoss.directions(enemy):
		var end := origin + Vector3(direction.x, 0, direction.y) * 26.0
		if not camera.is_position_behind(end):
			draw_line(screen, camera.unproject_position(end), Color(ink, 0.45), 2.0, true)
	_text(
		screen + Vector2(30, -24), "ВЕЕР" if int(enemy["boss_pattern"]) == 0 else "КОЛЬЦО", 18, ink
	)
