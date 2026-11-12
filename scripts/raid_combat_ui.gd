class_name RaidCombatUi
extends Control
## Original native, responsive HUD. Read-only view of existing raid state.
var run: RaidRun
var hull_panel: PanelContainer
var hull_title: Label
var hull_bar: ProgressBar
var xp_bar: ProgressBar
var navigation: Label
var weapons: GridContainer
var weapon_labels: Array[Label] = []
var weapon_titles: Array[Label] = []


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
	hull_panel = PanelContainer.new()
	hull_panel.add_theme_stylebox_override("panel", surface())
	add_child(hull_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 5)
	hull_panel.add_child(column)
	hull_title = _label(column, 19)
	hull_bar = _progress(column, Color("ef967c"))
	xp_bar = _progress(column, Color("76d8c0"))
	navigation = _label(column, 13)
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
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", surface())
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var box := VBoxContainer.new()
		card.add_child(box)
		weapons.add_child(card)
		var heading := _label(box, 12)
		weapon_titles.append(heading)
		heading.text = title
		heading.modulate = Color("8caab0")
		weapon_labels.append(_label(box, 15))
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
	background.bg_color = Color("263b43")
	background.set_corner_radius_all(3)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("background", background)
	bar.add_theme_stylebox_override("fill", fill)
	parent.add_child(bar)
	return bar


func _layout() -> void:
	if hull_panel == null:
		return
	hull_panel.position = Vector2(16, 22)
	hull_panel.size = Vector2(260 if size.x >= 1000 else 220, 118)
	weapons.columns = 6 if size.x >= 1400 else 3
	var rows := 1 if weapons.columns == 6 else 2
	var width := maxf(300, size.x - 32)
	for card in weapons.get_children():
		card.custom_minimum_size = Vector2(
			(width - 8 * (weapons.columns - 1)) / weapons.columns, 72
		)
	weapons.position = Vector2(16, size.y - 16 - rows * 72 - (rows - 1) * 8)
	weapons.size = Vector2(width, rows * 72 + (rows - 1) * 8)


func _clock(seconds: float) -> String:
	return "ГОТОВО" if seconds <= 0.0 else "%.1f с" % seconds


func _process(_delta: float) -> void:
	visible = run.engaged() and not run.modal() and not run.main.inspection_active()
	if not visible:
		return
	hull_title.text = "КОРПУС %d%%   /   УР. %d" % [ceili(run.main.boat.hull_hp), run.level]
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
	weapon_titles[0].text = "01  НОС · ГАРПУН" if run.piercing_harpoon else "01  НОС"
	weapon_titles[1].text = "02  БОРТА · ШТОРМ" if run.storm_broadside else "02  БОРТА"
	weapon_titles[2].text = "Q  РЕЗОНАНС" if run.resonant_pulse else "Q  ИМПУЛЬС"
	weapon_titles[3].text = "04  КОРМА · ЦЕПЬ" if run.chain_mines else "04  КОРМОВЫЕ МИНЫ"
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
	for index in range(3, 6):
		weapon_labels[index].modulate = (
			Color("71868b") if "НЕ УСТАНОВЛЕНО" in weapon_labels[index].text else Color.WHITE
		)
