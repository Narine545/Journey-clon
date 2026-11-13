class_name RaidCombatUi
extends Control
## Original native, responsive HUD. Read-only view of existing raid state.
var run: RaidRun
var hull_panel: RaidCutPanel
var hull_title: Label
var hull_bar: ProgressBar
var xp_bar: ProgressBar
var navigation: Label
var weapons: GridContainer
var weapon_cards: Array[RaidCutPanel] = []
var weapon_labels: Array[Label] = []
var weapon_titles: Array[Label] = []
var _composition_key := ""


static func surface() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("10232bee")
	style.border_color = Color("355159")
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 9
	style.content_margin_bottom = 9
	return style


func setup(raid: RaidRun) -> void:
	run = raid
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	hull_panel = RaidCutPanel.new()
	hull_panel.paper = Color("efe8dc")
	hull_panel.underprint = Color("111619")
	add_child(hull_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 5)
	hull_panel.add_child(column)
	var eyebrow := _label(column, 12)
	eyebrow.text = "КОРПУС"
	eyebrow.add_theme_color_override("font_color", Color("a93329"))
	hull_title = _label(column, 28)
	hull_title.add_theme_color_override("font_color", Color("111619"))
	hull_bar = _progress(column, Color("ef967c"))
	xp_bar = _progress(column, Color("76d8c0"))
	navigation = _label(column, 13)
	navigation.add_theme_color_override("font_color", Color("111619"))
	weapons = GridContainer.new()
	weapons.add_theme_constant_override("h_separation", 8)
	weapons.add_theme_constant_override("v_separation", 8)
	add_child(weapons)
	for title in [
		"01  НОС",
		"02  БОРТА",
		"Q  ИМПУЛЬС",
		"04  КОРМОВЫЕ МИНЫ",
		"05  ВЫТЕСНЕНИЕ",
		"06  СТЯГИВАНИЕ"
	]:
		var card := RaidCutPanel.new()
		card.underprint = Color("e5dfd0")
		weapon_cards.append(card)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var box := VBoxContainer.new()
		card.add_child(box)
		weapons.add_child(card)
		var heading := _label(box, 12)
		weapon_titles.append(heading)
		heading.text = title
		heading.modulate = Color("8caab0")
		weapon_labels.append(_label(box, 15))
	weapon_cards[4].underprint = Color("78dfcb")
	weapon_cards[5].underprint = Color("b286db")
	weapon_cards[2].reparent(self)
	weapon_cards[2].paper = Color("c83f30")
	weapon_cards[2].underprint = Color("efe8dc")
	weapon_titles[2].add_theme_font_size_override("font_size", 28)
	weapon_titles[2].modulate = Color.WHITE
	_ignore_mouse(self)
	navigation.mouse_filter = Control.MOUSE_FILTER_PASS
	resized.connect(_layout)
	_layout()


func _ignore_mouse(node: Node) -> void:
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_ignore_mouse(child)


func _label(parent: Node, font_size: int) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("e0eeed"))
	parent.add_child(label)
	return label


func _progress(parent: Node, color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size.y = 7
	var background := StyleBoxFlat.new()
	background.bg_color = Color("9e9990")
	background.set_corner_radius_all(0)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(0)
	bar.add_theme_stylebox_override("background", background)
	bar.add_theme_stylebox_override("fill", fill)
	parent.add_child(bar)
	return bar


func _layout() -> void:
	if hull_panel == null:
		return
	hull_panel.position = Vector2(20, 24)
	hull_panel.size = Vector2(278 if size.x >= 1000 else 242, 158)
	weapon_cards[2].position = Vector2(22, size.y - 132)
	weapon_cards[2].size = Vector2(218, 108)
	weapons.columns = 5 if size.x >= 1600 else (3 if size.x >= 1000 else 2)
	var active := 2
	for index in [3, 4, 5]:
		if weapon_cards[index].visible:
			active += 1
	var rows := ceili(float(active) / weapons.columns)
	var width := maxf(300, size.x - 280)
	for card in weapons.get_children():
		card.custom_minimum_size = Vector2(
			(width - 8 * (weapons.columns - 1)) / weapons.columns, 66
		)
	weapons.position = Vector2(260, size.y - 24 - rows * 66 - (rows - 1) * 8)
	weapons.size = Vector2(width, rows * 66 + (rows - 1) * 8)


func _clock(seconds: float) -> String:
	return "ГОТОВО" if seconds <= 0.0 else "%.1f с" % seconds


func _process(_delta: float) -> void:
	visible = run.engaged() and not run.modal() and not run.main.inspection_active()
	if not visible:
		return
	hull_title.text = "%d%% / УР.%d" % [ceili(run.main.boat.hull_hp), run.level]
	hull_bar.value = run.main.boat.hull_hp
	xp_bar.value = clampf(float(run.xp) / run.xp_needed * 100.0, 0.0, 100.0)
	xp_bar.tooltip_text = "Опыт %d / %d · ×%.2f" % [run.xp, run.xp_needed, run.xp_multiplier()]
	var main := run.main
	var available_speed := (
		BoatVessel.REVERSE_SPEED * main.boat.raid_speed_factor()
		if main.boat.speed < -0.05
		else main.boat.effective_max_speed()
	)
	navigation.text = (
		"Опыт %d/%d · ×%.2f\nХод %.1f/%.1f · руль ×%.2f"
		% [
			run.xp,
			run.xp_needed,
			run.xp_multiplier(),
			main.boat.speed,
			available_speed,
			run.turn_multiplier()
		]
	)
	navigation.tooltip_text = (
		"Двигатель ×%.2f · корпус −%d%% хода\n%s"
		% [
			run.speed_multiplier(),
			roundi((1.0 - main.boat.hull_speed_factor()) * 100.0),
			(
				"ФОРСАЖ %.0f с" % main.overdrive_timer
				if main.overdrive_timer > 0.0
				else "БОНУСЫ — ДО КОНЦА РЕЙДА"
			)
		]
	)
	weapon_cards[2].paper = Color("c83f30") if run.pulse_cooldown <= 0.0 else Color("282b2d")
	weapon_cards[2].queue_redraw()
	weapon_titles[0].text = "НОС · ГАРПУН" if run.piercing_harpoon else "НОС"
	weapon_titles[1].text = "БОРТА · ШТОРМ" if run.storm_broadside else "БОРТА"
	weapon_titles[2].text = "Q  РЕЗОНАНС" if run.resonant_pulse else "Q  ИМПУЛЬС"
	weapon_titles[3].text = "КОРМА · ЦЕПЬ" if run.chain_mines else "КОРМОВЫЕ МИНЫ"
	weapon_labels[0].text = "%.0f урона · %s" % [run.damage, _clock(run._bow_timer)]
	weapon_labels[1].text = "×%d · %s" % [run.pellets, _clock(run._side_timer)]
	weapon_labels[2].text = "%.0f м · %s" % [run.pulse_radius, _clock(run.pulse_cooldown)]
	weapon_labels[3].text = (
		"%d/3 · %s" % [run.stern_rank, _clock(run.stern_charges.cooldown)]
		if run.stern_rank > 0
		else "НЕ УСТАНОВЛЕНО"
	)
	weapon_labels[4].text = (
		"%d/3 · сброс %s" % [run.sphere_rank, _clock(run.sphere_mines.cooldown)]
		if run.sphere_rank > 0
		else "НЕ УСТАНОВЛЕНО"
	)
	weapon_labels[5].text = (
		"%d/3 · сброс %s" % [run.gravity_rank, _clock(run.gravity_mines.cooldown)]
		if run.gravity_rank > 0
		else "НЕ УСТАНОВЛЕНО"
	)
	weapon_titles[4].text = "ВЫТЕСНЕНИЕ"
	weapon_titles[5].text = "СТЯГИВАНИЕ"
	weapon_cards[3].visible = run.stern_rank > 0
	weapon_cards[4].visible = run.sphere_rank > 0
	weapon_cards[5].visible = run.gravity_rank > 0
	var key := "%d/%d/%d" % [run.stern_rank, run.sphere_rank, run.gravity_rank]
	if key != _composition_key:
		_composition_key = key
		_layout()
	for index in range(3, 6):
		weapon_labels[index].modulate = (
			Color("71868b") if "НЕ УСТАНОВЛЕНО" in weapon_labels[index].text else Color.WHITE
		)
