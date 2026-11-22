class_name VillageInteraction
extends CanvasLayer
## Дом выбирается мышью только у пришвартованной лодки.
## У таверны доступен пробный разговор Мимо и Тимби; остальные жители текстовые.
var main: BoatMain
var panel_open := false
var hovered := -1
var _current := -1
var _targets: Array[Dictionary] = []
var _steps: Dictionary = {}
var _root: Control
var _dialog: Control
var _page: Control
var _shade: ColorRect
var _title: Label
var _role: Label
var _line: Label
var _hint: Label
var _next: TideButton
var _close_button: TideButton
var _guest_button: TideButton
var _divider: Polygon2D
var _mimo: TextureRect
var _timbi: TextureRect
var _timbi_mode := false


func setup(owner_main: BoatMain) -> void:
	main = owner_main
	name = "VillageInteraction"
	layer = 33
	for house in main.village.cottages:
		if not house.person_id.is_empty():
			_targets.append({"house": house, "person_id": house.person_id})
	_build_ui()


func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_hint = Label.new()
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	TideTokens.style_mono(_hint, 20, TideTokens.FOAM)
	_hint.add_theme_color_override("font_shadow_color", TideTokens.INK)
	_hint.add_theme_constant_override("shadow_offset_x", 2)
	_hint.add_theme_constant_override("shadow_offset_y", 2)
	_root.add_child(_hint)

	_dialog = Control.new()
	_dialog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dialog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dialog.visible = false
	_root.add_child(_dialog)
	_shade = ColorRect.new()
	_shade.color = TideTokens.ink_alpha(0.70)
	_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_shade.mouse_filter = Control.MOUSE_FILTER_STOP
	_dialog.add_child(_shade)

	# Такой же бумажный язык, шрифты и кнопки TIDECUT, как в остальных экранах.
	# Внутренняя система 1920×1080 масштабируется вместе с реальным окном.
	_page = TideKit.group(_dialog, Rect2(0, 0, 1420, 840), -1.2)
	var sheet := TideKit.panel(_page, Rect2(0, 0, 1420, 840), TideTokens.FOAM,
		TideTokens.FLARE, true)
	sheet.hatch_color = TideTokens.deep_alpha(0.10)
	# Изображения — настоящие авторские спрайты, за текстом и кнопками.
	_mimo = _make_actor(Rect2(15, 100, 350, 530))
	_timbi = _make_actor(Rect2(1055, 100, 350, 530))
	TideKit.text(_page, "ТИХАЯ БУХТА · РАЗГОВОР", Vector2(65, 35), 1, 20,
		TideTokens.flare_alpha(0.9), 1000)
	_title = TideKit.text(_page, "", Vector2(85, 145), 2, 54, TideTokens.FLARE, 1200)
	_role = TideKit.text(_page, "", Vector2(85, 210), 1, 20,
		TideTokens.ink_alpha(0.70), 1200)
	_divider = TideKit.poly(_page, PackedVector2Array([Vector2(85, 260), Vector2(1330, 260),
		Vector2(1324, 264), Vector2(85, 264)]), TideTokens.ink_alpha(0.24))
	_line = Label.new()
	_line.position = Vector2(85, 300)
	_line.size = Vector2(1230, 260)
	_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	TideTokens.style_body(_line, 34, TideTokens.INK)
	_page.add_child(_line)
	_next = TideKit.button(_page, "ДАЛЬШЕ", Rect2(85, 665, 360, 92),
		TideButton.Shape.SOLID, TideTokens.SONAR, 0, 30, TideTokens.INK, -1.0)
	_next.pressed.connect(_on_talk)
	_close_button = TideKit.button(_page, "УЙТИ", Rect2(480, 665, 300, 92),
		TideButton.Shape.GHOST, TideTokens.INK, 0, 30, TideTokens.INK, 1.0)
	_close_button.pressed.connect(_close)
	_guest_button = TideKit.button(_page, "ТИМБИ", Rect2(820, 665, 340, 92),
		TideButton.Shape.GHOST, TideTokens.INK, 0, 26, TideTokens.INK)
	_guest_button.pressed.connect(_switch_tavern_guest)
	_guest_button.visible = false
	TideKit.text(_page, "ESC · ЗАКРЫТЬ", Vector2(1130, 780), 1, 15,
		TideTokens.ink_alpha(0.55), 240)
	_root.resized.connect(_layout_page)
	_layout_page()


func _make_actor(rect: Rect2) -> TextureRect:
	var actor := TextureRect.new()
	actor.position = rect.position
	actor.size = rect.size
	actor.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	actor.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	actor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	actor.visible = false
	_page.add_child(actor)
	return actor


func _set_dialog_mode(timbi: bool) -> void:
	_timbi_mode = timbi
	_mimo.visible = timbi
	_timbi.visible = timbi
	_divider.visible = not timbi
	_title.position = Vector2(390, 145) if timbi else Vector2(85, 145)
	_title.size.x = 650 if timbi else 1200
	_role.position = Vector2(390, 210) if timbi else Vector2(85, 210)
	_role.size.x = 650 if timbi else 1200
	_line.position = Vector2(390, 300) if timbi else Vector2(85, 300)
	_line.size = Vector2(640, 260) if timbi else Vector2(1230, 260)
	_next.position = Vector2(375, 665) if timbi else Vector2(85, 665)
	_next.size = Vector2(250, 92) if timbi else Vector2(360, 92)
	_close_button.position = Vector2(645, 665) if timbi else Vector2(480, 665)
	_close_button.size = Vector2(170, 92) if timbi else Vector2(300, 92)
	_guest_button.position = Vector2(835, 665) if timbi else Vector2(820, 665)
	_guest_button.size = Vector2(210, 92) if timbi else Vector2(340, 92)
	_guest_button.set_caption("ХЕЛЬГА" if timbi else "ТИМБИ")
	_next.set_caption("ДАЛЬШЕ")
	if not timbi:
		_mimo.texture = null
		_timbi.texture = null


func _switch_tavern_guest() -> void:
	if _current < 0 or String(_targets[_current]["person_id"]) != "tavern":
		return
	_set_dialog_mode(not _timbi_mode)
	_steps["tavern"] = 0
	_refresh()
	_next.grab_focus()


func _layout_page() -> void:
	if _page == null:
		return
	var viewport_size := Vector2(get_viewport().get_texture().get_size())
	var factor := minf(viewport_size.x / 1920.0, viewport_size.y / 1080.0)
	_page.scale = Vector2.ONE * factor
	# Масштабирование идёт относительно центра листа (pivot_offset),
	# поэтому центрируем исходный размер, а не уже масштабированный.
	_page.position = (viewport_size - Vector2(1420, 840)) * 0.5


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
	_layout_page()
	_current = index
	var id := String(_targets[index]["person_id"])
	var person := VillagePeople.get_person(id)
	if person.is_empty():
		_current = -1
		return
	_steps[id] = 0
	_set_dialog_mode(id == "tavern")
	_guest_button.visible = id == "tavern"
	_title.text = String(person.get("name", "ЖИТЕЛЬ"))
	_role.text = String(person.get("role", ""))
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
	if _timbi_mode:
		var step := clampi(int(_steps.get(id, 0)), 0, VillagePeople.TIMBI_SCENE.size() - 1)
		var beat: Dictionary = VillagePeople.TIMBI_SCENE[step]
		var who := String(beat["who"])
		_title.text = "ТИМБИ" if who == "timbi" else TideStory.HEROINE
		_role.text = "ДОЧЬ ХОЗЯЙКИ ТАВЕРНЫ" if who == "timbi" else "ПОДРУГА ТИМБИ"
		_line.text = String(beat["line"])
		_mimo.texture = TideStory.portrait(String(beat["mimo"]))
		_timbi.texture = TideStory.picture(String(beat["pose"]))
		_mimo.modulate = Color.WHITE if who == "mimo" else Color(0.52, 0.52, 0.52)
		_timbi.modulate = Color.WHITE if who == "timbi" else Color(0.52, 0.52, 0.52)
		_next.set_caption("ЗАВЕРШИТЬ" if step == VillagePeople.TIMBI_SCENE.size() - 1 else "ДАЛЬШЕ")
		return
	var person := VillagePeople.get_person(id)
	_title.text = String(person.get("name", "ЖИТЕЛЬ"))
	_role.text = String(person.get("role", ""))
	_line.text = VillagePeople.line_for(id, main.clock_hours, int(_steps.get(id, 0)))


func _on_talk() -> void:
	if _current < 0:
		return
	var id := String(_targets[_current]["person_id"])
	if _timbi_mode and int(_steps.get(id, 0)) >= VillagePeople.TIMBI_SCENE.size() - 1:
		_close()
		return
	_steps[id] = int(_steps.get(id, 0)) + 1
	_refresh()


func _close() -> void:
	panel_open = false
	_current = -1
	_set_dialog_mode(false)
	_guest_button.visible = false
	_dialog.visible = false
	if main != null:
		main.village_panel_open = false
