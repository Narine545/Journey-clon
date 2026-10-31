class_name DebugMenu
extends CanvasLayer
## Явные, не сохраняемые между запусками тестовые режимы. F2 открывает панель.
var main: MainScene
var is_open := false
var previous_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_CAPTURED
var backdrop: ColorRect
var hint: Label
var status: Label
var normal_button: Button
var climb_button: Button
var top_button: Button
var robots_button: Button
var close_button: Button


func setup(main_ref: MainScene) -> void:
	main = main_ref
	layer = 30
	hint = Label.new()
	hint.text = "F2 — ОТЛАДКА"
	hint.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	hint.offset_left = -180
	hint.offset_top = 18
	hint.offset_right = -18
	hint.offset_bottom = 48
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.add_theme_font_size_override("font_size", 17)
	hint.add_theme_color_override("font_color", Color(0.9, 0.87, 0.76, 0.8))
	hint.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.02, 0.9))
	hint.add_theme_constant_override("outline_size", 3)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hint)
	backdrop = ColorRect.new()
	backdrop.color = Color(0.01, 0.015, 0.015, 0.82)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	backdrop.visible = false
	add_child(backdrop)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(600, 0)
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 24)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)
	var title := Label.new()
	title.text = "ОТЛАДКА · F2"
	title.add_theme_font_size_override("font_size", 26)
	column.add_child(title)
	status = Label.new()
	status.add_theme_font_size_override("font_size", 18)
	column.add_child(status)
	var info := Label.new()
	info.text = "Выберите режим мышью. Демо-роботов можно сбросить клавишей F4.\nОбычная игра и маяк сохраняются; тестовые режимы — до перезапуска."
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_theme_font_size_override("font_size", 16)
	column.add_child(info)
	normal_button = _button(column, "Обычная игра — выключить демонстрацию")
	normal_button.pressed.connect(_select_normal)
	climb_button = _button(column, "Подъём с земли — пройти весь путь у опоры")
	climb_button.pressed.connect(_select_climb)
	top_button = _button(column, "Быстро показать робота у площадки")
	top_button.pressed.connect(_show_near_top)
	var note := Label.new()
	note.text = "Быстрая проверка переместит вас к краю и наведёт взгляд."
	note.add_theme_font_size_override("font_size", 15)
	column.add_child(note)
	robots_button = _button(column, "Три типа роботов — демонстрация вдали")
	robots_button.pressed.connect(_select_robots)
	close_button = _button(column, "Вернуться в игру  ·  F2 / Esc")
	close_button.pressed.connect(set_open.bind(false))
	_refresh()


func _button(parent: VBoxContainer, text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 42
	button.add_theme_font_size_override("font_size", 18)
	parent.add_child(button)
	return button


func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.physical_keycode == KEY_F2:
		set_open(not is_open)
		get_viewport().set_input_as_handled()
	elif is_open and event.physical_keycode == KEY_ESCAPE:
		set_open(false)
		get_viewport().set_input_as_handled()


func set_open(value: bool) -> void:
	if is_open == value:
		return
	if value:
		# Нельзя оставить два активных меню и потерять режим курсора.
		if main.shop.is_open:
			main.shop.set_open(false)
		if main.radio_tuner.tuning:
			main.radio_tuner.set_tuning(false)
		previous_mouse_mode = Input.mouse_mode
		main.rifle.aim_requested = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = previous_mouse_mode
	is_open = value
	backdrop.visible = value
	hint.visible = not value
	_refresh()


func _refresh() -> void:
	if status == null or main == null:
		return
	var mode := "ОБЫЧНАЯ ИГРА"
	if main.ambient_spawner.preview_climbing:
		mode = "ДЕМО ПОДЪЁМА"
	elif main.ambient_spawner.preview_robots:
		mode = "ДЕМО ТРЁХ ТИПОВ"
	status.text = "Текущий режим: " + mode


func _select_normal() -> void:
	main.ambient_spawner.set_debug_mode(AmbientSpawner.DebugMode.NORMAL)
	set_open(false)


func _select_climb() -> void:
	main.ambient_spawner.set_debug_mode(AmbientSpawner.DebugMode.CLIMB)
	set_open(false)


func _select_robots() -> void:
	main.ambient_spawner.set_debug_mode(AmbientSpawner.DebugMode.ROBOTS)
	set_open(false)


func _show_near_top() -> void:
	main.ambient_spawner.set_debug_mode(AmbientSpawner.DebugMode.CLIMB, true)
	var climber := main.ambient_spawner.get_node_or_null("ClimbPreviewRobot") as AmbientRobot
	if climber != null:
		# Отладочная кнопка прямо предупреждает о перемещении игрока.
		main.player.position = Vector3(4.7, ObservationTower.DECK_HEIGHT, -1.4)
		main.player.velocity = Vector3.ZERO
		main.cam_rig.aim_offset = Vector2.ZERO
		main.cam_rig.refresh_pose()
		var target := climber.global_position + Vector3.UP * climber.body_size.y * 0.5
		var dir := (target - main.cam_rig.cam.global_position).normalized()
		main.cam_rig.set_view(atan2(dir.x, dir.z), asin(dir.y))
	set_open(false)
