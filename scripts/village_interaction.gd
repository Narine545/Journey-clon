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
var _story: Control
var _story_box: Control
var _story_plate: Polygon2D
var _story_name: Label
var _story_body: Label
var _story_counter: Label
var _story_type: Tween
var _actor_pop: Tween


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
	_shade.gui_input.connect(_on_story_click)

	# Такой же бумажный язык, шрифты и кнопки TIDECUT, как в остальных экранах.
	# Внутренняя система 1920×1080 масштабируется вместе с реальным окном.
	_page = TideKit.group(_dialog, Rect2(0, 0, 1420, 840), -1.2)
	var sheet := TideKit.panel(_page, Rect2(0, 0, 1420, 840), TideTokens.FOAM,
		TideTokens.FLARE, true)
	sheet.hatch_color = TideTokens.deep_alpha(0.10)
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
	_build_story()
	_root.resized.connect(_layout_page)
	_layout_page()


## Визуальный язык пролога: затемнение, изобаты, рваный лист, плашка,
## подложка за фигурами и печатающийся текст. Координаты — как в прологе.
func _build_story() -> void:
	_story = TideKit.group(_dialog, Rect2(0, 0, 1920, 1080))
	_story.mouse_filter = Control.MOUSE_FILTER_IGNORE
	TideKit.isobaths(_story, Rect2(Vector2.ZERO, TideTokens.BASE), 0.06, 36.0)
	var left_back := TideKit.panel(_story, Rect2(-40, -80, 710, 1300), TideTokens.DEEP,
		TideTokens.FLARE, true, -4.0, false)
	left_back.hatch_color = TideTokens.foam_alpha(0.07)
	var right_back := TideKit.panel(_story, Rect2(1250, -80, 710, 1300), TideTokens.DEEP,
		TideTokens.FLARE, true, 4.0, false)
	right_back.hatch_color = TideTokens.foam_alpha(0.07)
	_mimo = _make_actor(Rect2(-20, 25, 700, 1250))
	_timbi = _make_actor(Rect2(1240, 25, 700, 1250))
	var head := TideKit.group(_story, Rect2(680, 70, 650, 170), -3.0)
	TideKit.text(head, "ТИХАЯ БУХТА · ТАВЕРНА", Vector2(6, 0), 1, 22, TideTokens.SONAR)
	TideKit.headline(head, "ВСТРЕЧА", Vector2(0, 34), 580.0, 80, TideTokens.FOAM, 8, -10.0)
	_story_box = TideKit.group(_story, Rect2(510, 660, 900, 310), -1.6)
	var sheet := TideKit.panel(_story_box, Rect2(0, 0, 900, 310), TideTokens.FOAM, TideTokens.FLARE, true)
	sheet.hatch_color = TideTokens.ink_alpha(0.05)
	_story_plate = TideKit.poly(_story_box, PackedVector2Array(), TideTokens.SONAR, Vector2(34, -30))
	_story_name = TideKit.text(_story_box, "", Vector2(62, -24), 2, 26, TideTokens.INK)
	_story_body = TideKit.block(_story_box, "", Rect2(55, 58, 790, 205), 0, 40, TideTokens.INK, 4)
	_story_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_story_counter = TideKit.text(_story_box, "", Vector2(55, 255), 1, 20,
		TideTokens.ink_alpha(0.7), 790, HORIZONTAL_ALIGNMENT_RIGHT)
	TideKit.text(_story, "ПРОБЕЛ · КЛИК — ДАЛЬШЕ", Vector2(450, 1000), 1, 20, TideTokens.foam_alpha(0.8))
	var helga := TideKit.button(_story, "ХЕЛЬГА", Rect2(1030, 988, 190, 56),
		TideButton.Shape.GHOST, TideTokens.SONAR, 1, 20, TideTokens.SONAR, -1.6)
	helga.focus_mode = Control.FOCUS_NONE
	helga.pressed.connect(_switch_tavern_guest)
	var leave := TideKit.button(_story, "ESC · УЙТИ", Rect2(1240, 988, 230, 56),
		TideButton.Shape.GHOST, TideTokens.SONAR, 1, 20, TideTokens.SONAR, -1.6)
	leave.focus_mode = Control.FOCUS_NONE
	leave.pressed.connect(_close)
	_story.add_child(TideFx.bob(_story_box, -1.6, 0.6, 2.9, 0.4))
	_story.add_child(TideFx.bob(left_back, -4.0, 0.7, 3.1, 1.0))
	_story.add_child(TideFx.bob(right_back, 4.0, 0.7, 3.1, 2.1))
	_story.visible = false


func _make_actor(rect: Rect2) -> TextureRect:
	var actor := TextureRect.new()
	actor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	actor.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	# Разные исходные разрешения не меняют пропорций персонажей.
	actor.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	TideKit.place(actor, rect)
	actor.pivot_offset = Vector2(rect.size.x * 0.5, rect.size.y * 0.72)
	actor.material = TideStory.backing(14.0)
	_story.add_child(actor)
	return actor


func _set_dialog_mode(timbi: bool) -> void:
	_timbi_mode = timbi
	_story.visible = timbi
	_page.visible = not timbi
	_shade.color = TideTokens.ink_alpha(0.88 if timbi else 0.70)
	_guest_button.set_caption("ТИМБИ")
	if not timbi:
		if _story_type != null and _story_type.is_valid():
			_story_type.kill()
		if _actor_pop != null and _actor_pop.is_valid():
			_actor_pop.kill()
		_mimo.scale = Vector2.ONE
		_timbi.scale = Vector2.ONE
		_mimo.texture = null
		_timbi.texture = null


func _switch_tavern_guest() -> void:
	if _current < 0 or String(_targets[_current]["person_id"]) != "tavern":
		return
	_set_dialog_mode(not _timbi_mode)
	_steps["tavern"] = 0
	_refresh()
	if not _timbi_mode:
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
	_story.scale = Vector2.ONE * factor
	_story.position = (viewport_size - TideTokens.BASE) * 0.5


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


func _on_story_click(event: InputEvent) -> void:
	if panel_open and _timbi_mode and event is InputEventMouseButton \
			and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_talk()
		_shade.accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if panel_open:
		if _timbi_mode and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_on_talk()
			get_viewport().set_input_as_handled()
		return
	if not _can_interact():
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
		elif _timbi_mode and event.pressed and not event.echo and event.physical_keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_E]:
			_on_talk()
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
	if not _timbi_mode:
		_next.grab_focus()


func _refresh() -> void:
	if _current < 0:
		return
	var id := String(_targets[_current]["person_id"])
	if _timbi_mode:
		var step := clampi(int(_steps.get(id, 0)), 0, VillagePeople.TIMBI_SCENE.size() - 1)
		var beat: Dictionary = VillagePeople.TIMBI_SCENE[step]
		var who := String(beat["who"])
		_story_name.text = "ТИМБИ" if who == "timbi" else TideStory.HEROINE
		var width := TideTokens.font_of(2).get_string_size(_story_name.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
		_story_name.size.x = width + 8.0
		# Имя у ближайшего к говорящему края листа.
		var plate_x := 900.0 - width - 98.0 if who == "timbi" else 34.0
		_story_plate.position = Vector2(plate_x, -30)
		_story_name.position = Vector2(plate_x + 28.0, -24)
		_story_name.add_theme_color_override("font_color", TideTokens.FOAM if who == "timbi" else TideTokens.INK)
		_story_plate.color = TideTokens.FLARE if who == "timbi" else TideTokens.SONAR
		_story_plate.polygon = TideShapes.plate(Vector2(width + 64.0, 58.0), 10.0, 10.0)
		_story_plate.scale = Vector2(1.18, 1.18)
		var plate_tween := create_tween()
		plate_tween.tween_property(_story_plate, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_story_body.text = "«%s»" % String(beat["line"])
		_story_counter.text = "%02d / %02d" % [step + 1, VillagePeople.TIMBI_SCENE.size()]
		if _story_type != null and _story_type.is_valid():
			_story_type.kill()
		_story_body.visible_ratio = 0.0
		_story_type = create_tween()
		_story_type.tween_property(_story_body, "visible_ratio", 1.0, maxf(0.2, float(_story_body.text.length()) / TidePrologue.TYPE_SPEED))
		_mimo.texture = TideStory.portrait(String(beat["mimo"]))
		_timbi.texture = TideStory.picture(String(beat["pose"]))
		# Подчёркиваем реплику коротким упругим движением, не затемняя слушателя.
		if _actor_pop != null and _actor_pop.is_valid():
			_actor_pop.kill()
		_mimo.scale = Vector2.ONE
		_timbi.scale = Vector2.ONE
		var speaker := _timbi if who == "timbi" else _mimo
		speaker.scale = Vector2(0.955, 0.955)
		_actor_pop = create_tween()
		_actor_pop.tween_property(speaker, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		return
	var person := VillagePeople.get_person(id)
	_title.text = String(person.get("name", "ЖИТЕЛЬ"))
	_role.text = String(person.get("role", ""))
	_line.text = VillagePeople.line_for(id, main.clock_hours, int(_steps.get(id, 0)))


func _on_talk() -> void:
	if _current < 0:
		return
	var id := String(_targets[_current]["person_id"])
	if _timbi_mode and _story_type != null and _story_type.is_running():
		_story_type.kill()
		_story_body.visible_ratio = 1.0
		return
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
