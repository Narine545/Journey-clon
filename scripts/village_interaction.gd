class_name VillageInteraction
extends CanvasLayer
## Клик по дому в посёлке — пока лодка пришвартована.
##
## Мир остаётся миром: никаких маркеров над крышами и никаких иконок. При
## наведении дом получает тонкое неоновое кольцо на земле, а рядом с
## курсором появляется бумажная карточка «здесь живут». Клик открывает
## страницу TIDECUT: портрет, имя, дело, реплика по времени суток и три
## действия — поговорить, попросить о малом, уйти.
##
## Ограничения честные:
##   • работает только при `harbor.moored` (пришвартованы, не на ходу);
##   • не работает в меню, рейде, фото-режиме и у привала;
##   • «дело» — раз в сутки на человека (`clock_day`), чтобы посёлок не
##     стал автоматом по выдаче ресурсов.
##
## Луч идёт из камеры через курсор и пересекает габарит дома (AABB в
## локальных координатах). Физика не нужна: клик работает и по крыше, и по
## стене, и не цепляет корпус лодки, пришвартованной впереди.

const PAGE := Rect2(250.0, 96.0, 1420.0, 888.0)
const PAGE_DEG := -1.3
const MARGIN := 66.0
const PORTRAIT_RECT := Rect2(70.0, 206.0, 320.0, 400.0)
const TEXT_X := 440.0
const TEXT_W := 900.0

var main: BoatMain
var panel_open := false
var hovered := -1
var _current := -1
var _targets: Array[Dictionary] = []
var _regions: Array[Dictionary] = []

var _root: Control
var _panel: Control
var _page: Control
var _backdrop: ColorRect
var _portrait: VillagePortrait
var _house_title: Label
var _person_name: Label
var _person_role: Label
var _scene_text: Label
var _line_text: Label
var _gift_text: Label
var _gift_note: Label
var _counter: Label
var _talk_button: TideButton
var _gift_button: TideButton
var _close_button: TideButton
var _tooltip: Control
var _tip_title: Label
var _tip_role: Label
var _tip_hint: Label
var _steps: Dictionary = {}
var _gifted: Dictionary = {}
var _open_page_y := 0.0


func setup(owner_main: BoatMain) -> void:
	main = owner_main
	name = "VillageInteraction"
	layer = 33
	_build_targets()
	_build_root()
	_build_panel()
	_build_tooltip()
	set_process(true)


func _build_targets() -> void:
	_targets.clear()
	if main == null or main.village == null:
		return
	for house in main.village.cottages:
		var id := String(house.person_id)
		if id.is_empty():
			continue
		_targets.append({
			"kind": "house", "house": house, "node": house,
			"person_id": id, "title": String(VillagePeople.get_person(id).get("house", "ДОМ")),
		})
	# Часовня и прибрежный храм: их тоже можно «навестить», хотя это не дома.
	for entry in [
		{"node": main.village.chapel, "id": "bellringer", "title": "ЧАСОВНЯ", "height": 7.0},
		{"node": main.village.shrine, "id": "lanternkeeper", "title": "ПРИБРЕЖНЫЙ ХРАМ", "height": 3.6},
	]:
		var node: Node3D = entry["node"]
		if node == null:
			continue
		_targets.append({
			"kind": "landmark", "node": node, "person_id": String(entry["id"]),
			"title": String(entry["title"]), "height": float(entry["height"]),
		})


func _build_root() -> void:
	_root = Control.new()
	_root.name = "VillageRoot"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)


# --- Подсказка у курсора ----------------------------------------------------

func _build_tooltip() -> void:
	_tooltip = TideKit.group(_root, Rect2(0.0, 0.0, 430.0, 112.0), -1.0)
	TideKit.panel(_tooltip, Rect2(Vector2.ZERO, Vector2(430.0, 112.0)), TideTokens.FOAM,
		TideTokens.FLARE, true)
	_tip_title = TideKit.text(_tooltip, "", Vector2(24.0, 16.0), 2, 30, TideTokens.INK, 380.0)
	_tip_role = TideKit.text(_tooltip, "", Vector2(24.0, 56.0), 1, 17,
		TideTokens.ink_alpha(0.72), 380.0)
	_tip_hint = TideKit.text(_tooltip, "ЛКМ · ПОСТУЧАТЬ", Vector2(24.0, 82.0), 1, 15,
		TideTokens.FLARE, 380.0)
	_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in _tooltip.get_children():
		if child is Control:
			(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip.visible = false


# --- Страница дома ----------------------------------------------------------

func _build_panel() -> void:
	_panel = Control.new()
	_panel.name = "VillagePanel"
	_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.visible = false
	_root.add_child(_panel)

	_backdrop = ColorRect.new()
	_backdrop.color = TideTokens.ink_alpha(0.62)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel.add_child(_backdrop)
	TideKit.isobaths(_panel, Rect2(Vector2.ZERO, TideTokens.BASE), 0.05, 40.0)

	_page = TideKit.group(_panel, PAGE, PAGE_DEG)
	var sheet := TideKit.panel(_page, Rect2(Vector2.ZERO, PAGE.size), TideTokens.FOAM,
		TideTokens.FLARE, true)
	sheet.hatch_color = TideTokens.deep_alpha(0.10)
	sheet.hatch_spacing = 8.0
	sheet.underprint_offset = Vector2(14.0, 16.0)

	# Верхняя строка-«шапка»: номер дома, посёлок, время.
	var top := TideKit.text(_page, "ТИХАЯ БУХТА · СУДОВАЯ РОЛЬ", Vector2(MARGIN, 30.0), 1,
		18, TideTokens.flare_alpha(0.85), 700.0)
	_counter = TideKit.text(_page, "", Vector2(PAGE.size.x - MARGIN - 420.0, 30.0), 1,
		18, TideTokens.ink_alpha(0.60), 420.0, HORIZONTAL_ALIGNMENT_RIGHT)
	# Название дома — крупно, наклонно, с алой «misprint»-тенью.
	_house_title = TideKit.text(_page, "", Vector2(MARGIN - 4.0, 56.0), 2, 78,
		TideTokens.INK, PAGE.size.x - MARGIN * 2.0)
	_house_title.add_theme_constant_override("outline_size", 0)

	# Портрет и подпись.
	_portrait = VillagePortrait.new()
	_portrait.position = PORTRAIT_RECT.position
	_portrait.size = PORTRAIT_RECT.size
	_page.add_child(_portrait)
	var portrait_note := TideKit.text(_page, "ФОТО НЕ ПРИЛАГАЕТСЯ · РИСУНОК ПО СЛОВАМ",
		Vector2(PORTRAIT_RECT.position.x - 4.0, PORTRAIT_RECT.end.y + 10.0), 1, 13,
		TideTokens.ink_alpha(0.48), PORTRAIT_RECT.size.x + 8.0, HORIZONTAL_ALIGNMENT_CENTER)
	portrait_note.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	portrait_note.size.y = 34.0

	_person_name = TideKit.text(_page, "", Vector2(TEXT_X, 168.0), 2, 44,
		TideTokens.FLARE, TEXT_W)
	_person_role = TideKit.text(_page, "", Vector2(TEXT_X, 214.0), 1, 19,
		TideTokens.ink_alpha(0.68), TEXT_W)
	# Линовка: три линии под именем, как в судовой роли.
	for i in range(3):
		var y := 252.0 + float(i) * 6.0
		TideKit.poly(_page, PackedVector2Array([
			Vector2(TEXT_X, y), Vector2(TEXT_X + TEXT_W, y),
			Vector2(TEXT_X + TEXT_W - 6.0, y + 2.0), Vector2(TEXT_X, y + 2.0),
		]), TideTokens.ink_alpha(0.16))

	_scene_text = _wrapped(_page, "", Rect2(TEXT_X, 282.0, TEXT_W, 76.0), 20,
		TideTokens.ink_alpha(0.78), 8)
	# Реплика на бумаге: крупный Oswald, с «кавычкой» из сонаря.
	TideKit.poly(_page, PackedVector2Array([
		Vector2(TEXT_X - 8.0, 376.0), Vector2(TEXT_X + 4.0, 376.0),
		Vector2(TEXT_X + 4.0, 392.0), Vector2(TEXT_X - 2.0, 392.0),
	]), TideTokens.SONAR)
	_line_text = _wrapped(_page, "", Rect2(TEXT_X, 372.0, TEXT_W, 216.0), 34,
		TideTokens.INK, 12)

	# Нижний блок «дело»: что можно попросить и что уже сделано.
	TideKit.poly(_page, PackedVector2Array([
		Vector2(TEXT_X, 604.0), Vector2(TEXT_X + TEXT_W, 604.0),
		Vector2(TEXT_X + TEXT_W - 8.0, 607.0), Vector2(TEXT_X, 607.0),
	]), TideTokens.ink_alpha(0.22))
	_gift_note = TideKit.text(_page, "", Vector2(TEXT_X, 618.0), 1, 16,
		TideTokens.flare_alpha(0.9), TEXT_W)
	_gift_text = _wrapped(_page, "", Rect2(TEXT_X, 646.0, TEXT_W, 92.0), 19,
		TideTokens.ink_alpha(0.74), 6)

	# Три действия. Ширина — по бумаге, высота — под палец.
	var button_y := PAGE.size.y - 148.0
	_talk_button = TideKit.button(_page, "ПОГОВОРИТЬ", Rect2(TEXT_X, button_y, 300.0, 92.0),
		TideButton.Shape.SOLID, TideTokens.SONAR, 0, 32, TideTokens.INK, -1.0)
	_talk_button.pressed.connect(_on_talk)
	_gift_button = TideKit.button(_page, "ПОПРОСИТЬ", Rect2(TEXT_X + 330.0, button_y, 320.0, 92.0),
		TideButton.Shape.SOLID, TideTokens.FLARE,
		0, 32, TideTokens.INK, 1.2)
	_gift_button.pressed.connect(_on_gift)
	_close_button = TideKit.button(_page, "УЙТИ", Rect2(TEXT_X + 680.0, button_y + 8.0, 220.0, 78.0),
		TideButton.Shape.GHOST, TideTokens.INK, 0, 28, TideTokens.INK, -1.4)
	_close_button.pressed.connect(_close)

	# Печать «СВОЙ» — на свободном месте справа от портрета.
	var stamp := TideKit.stamp(_page, "СВОЙ", Rect2(PAGE.size.x - 300.0, 120.0, 260.0, 110.0),
		TideTokens.SONAR, 36, -9.0)
	stamp.show()
	stamp.hit(_page)
	# Качка страницы: один раз, дальше живёт сама.
	add_child(TideFx.bob(_page, PAGE_DEG, 0.35, 3.1, 0.0))


func _wrapped(parent: Node, text_value: String, rect: Rect2, point: int, color: Color,
		line_gap: int) -> Label:
	var node := Label.new()
	node.text = text_value
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.add_theme_font_override("font", TideTokens.body_font())
	node.add_theme_font_size_override("font_size", point)
	node.add_theme_color_override("font_color", color)
	node.add_theme_constant_override("line_spacing", line_gap)
	node.position = rect.position
	node.size = rect.size
	node.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	parent.add_child(node)
	return node


# --- Наведение и клик -------------------------------------------------------

func _can_interact() -> bool:
	if main == null or main.harbor == null or not main.harbor.moored:
		return false
	if main.menu_open or main.inspection_active() or main.gameplay_paused():
		return false
	if main.raid != null and main.raid.engaged():
		return false
	if main.rest != null and main.rest.visible:
		return false
	if main.photo_mode != null and main.photo_mode.active:
		return false
	return true


func _process(_delta: float) -> void:
	if panel_open:
		return
	if not _can_interact():
		_set_hover(-1)
		return
	var mouse := get_viewport().get_mouse_position()
	var picked := _pick(mouse)
	_set_hover(picked)
	if picked < 0:
		_tooltip.visible = false
		return
	_tooltip.visible = true
	var target := _targets[picked]
	var person := VillagePeople.get_person(String(target["person_id"]))
	_tip_title.text = String(target["title"])
	_tip_role.text = "%s · %s" % [String(person.get("name", "")), String(person.get("role", ""))]
	var desired := mouse + Vector2(26.0, 22.0)
	var limit := get_viewport().get_visible_rect().size
	if desired.x + 430.0 > limit.x:
		desired.x = mouse.x - 456.0
	if desired.y + 112.0 > limit.y:
		desired.y = mouse.y - 134.0
	_tooltip.position = desired


## Ближайшая цель под курсором. Дома — по лучу через габарит, храмы — по
## экранному расстоянию до их силуэта (у них нет своей AABB-ручки).
func _pick(mouse: Vector2) -> int:
	var camera := main.camera
	if camera == null:
		return -1
	var origin := camera.project_ray_origin(mouse)
	var direction := camera.project_ray_normal(mouse)
	var best := 1e9
	var best_index := -1
	for i in range(_targets.size()):
		var target := _targets[i]
		if String(target["kind"]) == "house":
			var house: GiltHouse = target["house"]
			var d: float = house.ray_distance(origin, direction)
			if d > 0.0 and d < best:
				best = d
				best_index = i
		else:
			var node: Node3D = target["node"]
			var base := camera.unproject_position(node.global_position + Vector3.UP * 0.8)
			var top := camera.unproject_position(node.global_position
				+ Vector3.UP * float(target.get("height", 3.0)))
			var screen := Geometry2D.get_closest_point_to_segment(mouse, base, top)
			if mouse.distance_to(screen) < 34.0 and best > 40.0:
				best = 40.0
				best_index = i
	return best_index


func _set_hover(index: int) -> void:
	if hovered == index:
		return
	if hovered >= 0 and hovered < _targets.size():
		var old := _targets[hovered]
		if String(old["kind"]) == "house":
			var old_house: GiltHouse = old["house"]
			old_house.set_highlight(false)
	hovered = index
	if hovered >= 0 and hovered < _targets.size():
		var target := _targets[hovered]
		if String(target["kind"]) == "house":
			var house: GiltHouse = target["house"]
			house.set_highlight(true)


func _unhandled_input(event: InputEvent) -> void:
	if not _can_interact():
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if hovered >= 0:
			_open(hovered)
			get_viewport().set_input_as_handled()


func _input(event: InputEvent) -> void:
	if not panel_open:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		# Пока открыта судовая роль, клавиши принадлежат ей: E не отдаёт
		# швартовы за спиной у игрока.
		if event.physical_keycode == KEY_ESCAPE:
			_close()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Клик вне бумаги закрывает страницу; клики по кнопкам остаются
		# кнопкам (они лежат внутри PAGE).
		if not PAGE.has_point(event.position):
			_close()
			get_viewport().set_input_as_handled()


# --- Открытие и содержимое --------------------------------------------------

func _open(index: int) -> void:
	if index < 0 or index >= _targets.size():
		return
	_current = index
	var target := _targets[index]
	var id := String(target["person_id"])
	_steps[id] = int(_steps.get(id, 0))
	panel_open = true
	main.village_panel_open = true
	_panel.visible = true
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_set_hover(-1)
	_tooltip.visible = false
	_house_title.text = String(target["title"]).to_upper()
	_portrait.set_person(VillagePeople.get_person(id))
	_refresh_texts()
	# Число знакомых жителей — не задание, просто счётчик встреч.
	var met := 0
	for key in _steps:
		if int(_steps[key]) > 0:
			met += 1
	_counter.text = "ЗНАКОМЫХ: %d ИЗ %d" % [met, _targets.size()]
	TideKit.place(_page, PAGE, PAGE_DEG)
	TideFx.pop_in(_page, 0.88, -7.0)
	TideFx.splash(_panel, Vector2(520.0, 120.0), 12)
	UiSound.tap()


func _refresh_texts() -> void:
	if _current < 0 or _current >= _targets.size():
		return
	var target := _targets[_current]
	var id := String(target["person_id"])
	var person := VillagePeople.get_person(id)
	_person_name.text = String(person.get("name", ""))
	_person_role.text = String(person.get("role", ""))
	var hour := 12.0
	var night := 0.0
	if main != null:
		hour = main.clock_hours
		night = main.night01
	_scene_text.text = VillagePeople.scene_for(id, hour, night)
	var step := int(_steps.get(id, 0))
	_line_text.text = VillagePeople.line_for(id, hour, step)
	# Дело: раз в сутки. Текст всегда виден — игрок должен знать, что можно
	# попросить, даже если сегодня уже просил.
	var gift_used := int(_gifted.get(id, -1)) == int(main.clock_day if main != null else 0)
	_gift_note.text = String(person.get("gift_title", "МАЛОЕ ДЕЛО"))
	_gift_text.text = String(person.get("gift_text", ""))
	if gift_used:
		_gift_note.text += " · УЖЕ СЕГОДНЯ"
		_gift_button.set_caption("СПАСИБО", TideTokens.ink_alpha(0.42))
	else:
		_gift_button.set_caption("ПОПРОСИТЬ", TideTokens.INK)


func _on_talk() -> void:
	if _current < 0:
		return
	var id := String(_targets[_current]["person_id"])
	_steps[id] = int(_steps.get(id, 0)) + 1
	UiSound.tap()
	_refresh_texts()


func _on_gift() -> void:
	if _current < 0:
		return
	var id := String(_targets[_current]["person_id"])
	var person := VillagePeople.get_person(id)
	var day := int(main.clock_day)
	if int(_gifted.get(id, -1)) == day:
		_gift_note.text = String(person.get("gift_title", "ДЕЛО")) + " · УЖЕ СЕГОДНЯ"
		UiSound.tap()
		return
	var text := _apply_gift(person)
	_gifted[id] = day
	_gift_text.text = text
	_gift_note.text = String(person.get("gift_title", "ДЕЛО")) + " · СДЕЛАНО"
	_gift_button.set_caption("СПАСИБО", TideTokens.ink_alpha(0.42))
	UiSound.tap()


## Малое дело: ресурс, латка, пеленг или благословение. Ничего не ломает
## баланс: всё это можно получить и обычным плаванием, просто дольше.
func _apply_gift(person: Dictionary) -> String:
	var kind := String(person.get("gift_kind", "raw"))
	var color := int(person.get("gift_color", 0))
	var text := String(person.get("gift_text", ""))
	match kind:
		"raw":
			main.raw[color] += 1
			main.announce("ПОСЁЛОК: +1 СЫРЬЁ")
		"refined":
			main.refined[color] += 1
			main.announce("ПОСЁЛОК: +1 ГОТОВЫЙ МАТЕРИАЛ")
		"hull":
			main.boat.hull_hp = minf(100.0, main.boat.hull_hp + 30.0)
			main.announce("КОРПУС ПОДЛАТАН: +30")
		"sonar":
			main.sonar_timer = maxf(main.sonar_timer, 16.0)
			main.announce("ПЕЛЕНГ ПОСЁЛКА: СОНАР РАБОТАЕТ 16 С")
		"chart":
			main.sonar_timer = maxf(main.sonar_timer, 18.0)
			var beacon := main.next_unlit_beacon()
			if not beacon.is_empty():
				var bp: Vector3 = beacon["buoy_pos"]
				var boat_pos := Vector2(main.boat.global_position.x, main.boat.global_position.z)
				var dist := int(round(boat_pos.distance_to(Vector2(bp.x, bp.z))))
				main.announce("ФАРВАТЕР: «%s» — %d М" % [String(beacon["name"]).to_upper(), dist])
			else:
				main.announce("ФАРВАТЕР: ВСЕ МАЯКИ ГОРЯТ. ХОРОШАЯ НОЧЬ")
		"blessing":
			main.boat.hull_hp = minf(100.0, main.boat.hull_hp + 18.0)
			main.sonar_timer = maxf(main.sonar_timer, 12.0)
			main.announce("БЛАГОСЛОВЕНИЕ: КОРПУС +18, СОНАР 12 С")
	return text


func _close() -> void:
	if not panel_open:
		return
	panel_open = false
	_current = -1
	_panel.visible = false
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if main != null:
		main.village_panel_open = false
	UiSound.tap()
