class_name VillageInteraction
extends CanvasLayer
## Дом выбирается мышью только у пришвартованной лодки. Данные жителя и
## портрет отделены от диалога; portrait_path можно добавить в VillagePeople.
var main: BoatMain
var panel_open := false
var hovered := -1
var _current := -1
var _targets: Array[Dictionary] = []
var _steps: Dictionary = {}
var _root: Control
var _dialog: PanelContainer
var _portrait: VillagePortrait
var _title: Label
var _role: Label
var _line: Label
var _hint: Label
var _next: Button


func setup(owner_main: BoatMain) -> void:
	main = owner_main
	name = "VillageInteraction"
	layer = 33
	for house in main.village.cottages:
		if not house.person_id.is_empty():
			_targets.append({"house": house, "person_id": house.person_id})
	# Эти жители находятся не в жилых домах, но также доступны для разговора.
	for entry in [{"node": main.village.chapel, "person_id": "bellringer", "height": 7.0},
			{"node": main.village.shrine, "person_id": "lanternkeeper", "height": 3.6}]:
		if entry.node != null:
			_targets.append(entry)
	_build_ui()


func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_hint = Label.new()
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.add_theme_font_size_override("font_size", 18)
	_root.add_child(_hint)
	_dialog = PanelContainer.new()
	_dialog.anchor_left = 0.18
	_dialog.anchor_right = 0.82
	_dialog.anchor_top = 0.22
	_dialog.anchor_bottom = 0.78
	_dialog.visible = false
	_dialog.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(_dialog)
	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 24)
	_dialog.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	margin.add_child(row)
	_portrait = VillagePortrait.new()
	_portrait.custom_minimum_size = Vector2(200, 300)
	_portrait.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(_portrait)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 12)
	row.add_child(column)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 27)
	column.add_child(_title)
	_role = Label.new()
	_role.add_theme_font_size_override("font_size", 16)
	column.add_child(_role)
	_line = Label.new()
	_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_line.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_line.add_theme_font_size_override("font_size", 21)
	column.add_child(_line)
	var buttons := HBoxContainer.new()
	column.add_child(buttons)
	_next = Button.new()
	_next.text = "ДАЛЬШЕ"
	_next.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_next.pressed.connect(_on_talk)
	buttons.add_child(_next)
	var close := Button.new()
	close.text = "УЙТИ"
	close.pressed.connect(_close)
	buttons.add_child(close)


func _can_interact() -> bool:
	return main != null and main.harbor != null and main.harbor.moored \
		and not main.menu_open and not main.inspection_active() \
		and (panel_open or not main.gameplay_paused()) \
		and (main.raid == null or not main.raid.engaged()) \
		and (main.rest == null or not main.rest.visible)


func _process(_delta: float) -> void:
	if panel_open:
		if not _can_interact():
			_close()
		return
	if not _can_interact():
		_set_hover(-1)
		_hint.visible = false
		return
	var mouse := get_viewport().get_mouse_position()
	_set_hover(_pick(mouse))
	_hint.visible = hovered >= 0
	if hovered >= 0:
		var person := VillagePeople.get_person(String(_targets[hovered]["person_id"]))
		_hint.text = "%s — нажмите, чтобы поговорить" % String(person.get("name", "ЖИТЕЛЬ"))
		_hint.position = mouse + Vector2(18, 16)


func _pick(mouse: Vector2) -> int:
	if main.camera == null:
		return -1
	var origin := main.camera.project_ray_origin(mouse)
	var direction := main.camera.project_ray_normal(mouse)
	var best := INF
	var result := -1
	for i in range(_targets.size()):
		var target := _targets[i]
		if target.has("house"):
			var house: GiltHouse = target["house"]
			var distance := house.ray_distance(origin, direction)
			if distance > 0.0 and distance < best:
				best = distance
				result = i
		else:
			var node: Node3D = target["node"]
			var local_origin := node.to_local(origin)
			var local_direction := node.global_transform.basis.inverse() * direction
			var bounds := AABB(Vector3(-2.8, 0.0, -2.8), Vector3(5.6, float(target["height"]), 5.6))
			var hit: Variant = bounds.intersects_ray(local_origin, local_direction)
			if hit != null:
				var point: Vector3 = hit
				var distance := origin.distance_to(node.to_global(point))
				if distance < best:
					best = distance
					result = i
	return result


func _set_hover(index: int) -> void:
	if hovered == index:
		return
	if hovered >= 0 and _targets[hovered].has("house"):
		(_targets[hovered]["house"] as GiltHouse).set_highlight(false)
	hovered = index
	if hovered >= 0 and _targets[hovered].has("house"):
		(_targets[hovered]["house"] as GiltHouse).set_highlight(true)


func _unhandled_input(event: InputEvent) -> void:
	if panel_open or not _can_interact():
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Pick at click time, not a stale hover from a previous frame.
		var picked := _pick(event.position)
		if picked >= 0:
			_open(picked)
			get_viewport().set_input_as_handled()


func _input(event: InputEvent) -> void:
	if not panel_open:
		return
	if event is InputEventKey:
		if event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE:
			_close()
			get_viewport().set_input_as_handled()


func _open(index: int) -> void:
	if index < 0 or index >= _targets.size() or not _can_interact():
		return
	_current = index
	var id := String(_targets[index]["person_id"])
	var person := VillagePeople.get_person(id)
	if person.is_empty():
		_current = -1
		return
	_steps[id] = 0
	_title.text = String(person.get("name", "ЖИТЕЛЬ"))
	_role.text = String(person.get("role", ""))
	_portrait.set_person(person)
	panel_open = true
	main.village_panel_open = true
	_dialog.visible = true
	_set_hover(-1)
	_hint.visible = false
	_refresh()
	_next.grab_focus()


func _refresh() -> void:
	if _current < 0:
		return
	var id := String(_targets[_current]["person_id"])
	_line.text = VillagePeople.line_for(id, main.clock_hours, int(_steps.get(id, 0)))


func _on_talk() -> void:
	if _current < 0:
		return
	var id := String(_targets[_current]["person_id"])
	_steps[id] = int(_steps.get(id, 0)) + 1
	_refresh()


func _close() -> void:
	panel_open = false
	_current = -1
	_dialog.visible = false
	if main != null:
		main.village_panel_open = false
