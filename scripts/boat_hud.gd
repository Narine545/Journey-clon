class_name BoatHud
extends Control
## Интерфейс плавания «ШТУРМАНСКИЙ СТОЛ» — тот же TIDECUT, что и в рейде, но
## со своим характером: вместо плашек и цепи здесь круглые приборы.
##
##  · трюм — четыре банки-циферблата: кольцо набирается сырьём, в центре готовое;
##  · пеленгатор — роза с сегментами маяков, стрелкой курса и развёрткой сонара;
##  · машинный телеграф — полукруг хода с вложенной дугой корпуса;
##  · системы — три «монеты» с круговым отсчётом;
##  · плашка действия — заполняется насосом, подпрыгивает при смене подсказки.
##
## Всё рисуется кодом в авторских координатах 1920×1080 и масштабируется под
## окно. Блоки покачиваются, вылетают с перелётом и «щёлкают» на событиях.

const BASE := Vector2(1920.0, 1080.0)
const ROLES := ["1 · СОНАР", "2 · РЕМОНТ", "3 · ФОРСАЖ", "КАТАЛИЗАТОР"]
const SYSTEMS := ["СОНАР", "РЕМОНТ", "ФОРСАЖ"]
const SONAR_FULL := 20.0
const OVERDRIVE_FULL := 16.0
const KEYS_LINE := "[M] КАРТА   [F] СВОБОДНАЯ КАМЕРА   [F2] ФОТО   [PgUp/PgDn] ВЫСОТА   [0] ПРОВЕРКА"
const CONTROLS_LINE := "W/S — ХОД   A/D — РУЛЬ   ПРОБЕЛ — НАСОС   R — ПЕРЕРАБОТКА   E — МАЯК/ПРИЧАЛ   B/T — ПЛАШКОУТ"

var main: BoatMain
## Витрина и проверки подставляют готовое состояние вместо живой игры.
var demo_state := {}

var _time := 0.0
var _age := 0.0
var _factor := 1.0
var _view := BASE
var _fill: Array[float] = [0.0, 0.0, 0.0, 0.0]
var _pop: Array[float] = [0.0, 0.0, 0.0, 0.0]
var _prev_refined: Array[int] = [-1, -1, -1, -1]
var _speed := 0.0
var _hull := 1.0
var _lit_pop := 0.0
var _prev_lit := -1
var _action_text := ""
var _action_age := 1.0
var _notice_text := ""
var _notice_age := 1.0
var _state := {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visibility_changed.connect(_on_visibility)


func _on_visibility() -> void:
	if visible:
		_age = 0.0


func _process(delta: float) -> void:
	if not visible or (main == null and demo_state.is_empty()):
		return
	_time += delta
	_age += delta
	_action_age += delta
	_notice_age += delta
	_lit_pop = maxf(0.0, _lit_pop - delta)
	_state = _read_state()
	if _state.is_empty():
		return
	var blend := 1.0 - exp(-delta * 9.0)
	var required := float(_state["required"])
	for i in range(4):
		var raw := float(_state["raw"][i])
		_fill[i] = lerpf(_fill[i], clampf(fmod(raw, required) / required if raw < required else 1.0, 0.0, 1.0), blend)
		_pop[i] = maxf(0.0, _pop[i] - delta)
		var stock := int(_state["refined"][i])
		if _prev_refined[i] >= 0 and stock > _prev_refined[i]:
			_pop[i] = 0.45
		_prev_refined[i] = stock
	_speed = lerpf(_speed, float(_state["speed"]) / maxf(1.0, float(_state["max_speed"])), blend)
	_hull = lerpf(_hull, clampf(float(_state["hull"]) / 100.0, 0.0, 1.0), blend)
	var lit := int(_state["lit"])
	if _prev_lit >= 0 and lit > _prev_lit:
		_lit_pop = 0.6
	_prev_lit = lit
	var action := String(_state["action"])
	if action != _action_text:
		_action_text = action
		_action_age = 0.0
	var notice := String(_state["notice"])
	if notice != _notice_text:
		_notice_text = notice
		if not notice.is_empty():
			_notice_age = 0.0
	queue_redraw()


# --- Состояние -------------------------------------------------------------


func _read_state() -> Dictionary:
	if not demo_state.is_empty():
		return demo_state
	if main == null or main.boat == null:
		return {}
	var required := 2 if main.boat.has_trailer else 3
	var raw_text := []
	for i in range(ResourceSlick.COLORS.size()):
		raw_text.append(main.resource_amount_text(main.raw[i]))
	var boat_xz := Vector2(main.boat.global_position.x, main.boat.global_position.z)
	var basis := main.camera.global_transform.basis
	var cam_right := Vector2(basis.x.x, basis.x.z).normalized()
	var cam_up := Vector2(-basis.z.x, -basis.z.z).normalized()
	var forward := -main.boat.global_transform.basis.z
	var forward_xz := Vector2(forward.x, forward.z).normalized()
	var beacons := []
	for b in main.beacons:
		var bp: Vector3 = b["buoy_pos"]
		var rel := Vector2(bp.x, bp.z) - boat_xz
		if rel.length() < 0.5:
			continue
		var dir := rel.normalized()
		beacons.append({"dir": Vector2(dir.dot(cam_right), -dir.dot(cam_up)).normalized(), "lit": bool(b["lit"])})
	var slicks := []
	if main.sonar_timer > 0.0:
		for slick in main.slicks:
			if slick.depleted:
				continue
			var rel_s := Vector2(slick.position.x, slick.position.z) - boat_xz
			var distance_s := rel_s.length()
			if distance_s < 85.0 and distance_s > 1.0:
				var dir_s := rel_s / distance_s
				slicks.append({
					"at": Vector2(dir_s.dot(cam_right), -dir_s.dot(cam_up)) * clampf(distance_s / 85.0, 0.15, 0.9),
					"kind": int(slick.kind),
				})
	var target := {}
	var next_b: Dictionary = main.next_unlit_beacon()
	if not next_b.is_empty():
		var at: Vector3 = next_b["buoy_pos"]
		var cost: PackedInt32Array = next_b["cost"]
		var can_fuel := true
		for i in range(cost.size()):
			if main.refined[i] + int(main.raw[i] / float(required)) < cost[i]:
				can_fuel = false
				break
		var rel_t := Vector2(at.x, at.z) - boat_xz
		var dir_t := rel_t.normalized()
		target = {
			"name": String(next_b["name"]).to_upper(),
			"dist": int(round(rel_t.length())),
			"cost": cost,
			"can_fuel": can_fuel,
			"dir": Vector2(dir_t.dot(cam_right), -dir_t.dot(cam_up)).normalized(),
		}
	var action := _action(next_b, boat_xz)
	var pump_kind := -1
	var pump := maxf(main.boat.pump_fraction(), main.boat.trailer_pump_fraction())
	if pump > 0.0:
		var pumped := main.boat.target_name()
		if pumped.is_empty():
			pumped = main.boat.trailer_target_name()
		pump_kind = ResourceSlick.NAMES.find(pumped)
	return {
		"speed": absf(main.boat.speed),
		"max_speed": main.boat.effective_max_speed(),
		"hull": main.boat.hull_hp,
		"night": main.night01,
		"raw": main.raw,
		"raw_text": raw_text,
		"refined": main.refined,
		"required": required,
		"trailer": main.boat.has_trailer,
		"lit": main.lit_beacon_count(),
		"total": main.beacons.size(),
		"target": target,
		"beacons": beacons,
		"slicks": slicks,
		"heading": Vector2(forward_xz.dot(cam_right), -forward_xz.dot(cam_up)).normalized(),
		"sonar": main.sonar_timer,
		"overdrive": main.overdrive_timer,
		"weather": "ПОГОДА: " + main.weather.label(),
		"camera": main.camera_scale_text(),
		"shoal": main.shoals != null and main.shoals.warning,
		"key": action[0],
		"action": action[1],
		"tone": action[2],
		"pump": pump,
		"pump_kind": pump_kind,
		"notice": main.notice if main.notice_time > 0.0 else "",
		"debug": main.debug_panel_visible,
		"headlight": main.debug_headlight_enabled,
	}


## Подсказка действия: [клавиша, текст, тон]. Тон: 0 — пена, 1 — сонарь, 2 — алый.
func _action(next_b: Dictionary, boat_xz: Vector2) -> Array:
	var dock_b: Dictionary = main.nearby_dock_beacon()
	var resource_name := main.boat.target_name()
	var trailer_resource := main.boat.trailer_target_name()
	if main.harbor != null and main.harbor.moored:
		return ["E", "ТИХАЯ БУХТА · ОТДАТЬ ШВАРТОВЫ", 1]
	if main.harbor != null and main.harbor.near_berth():
		return ["E", "ШВАРТОВКА · ХОД ДО 1.2 М/С", 1]
	if not dock_b.is_empty():
		if dock_b["lit"]:
			return ["E", "ПРИЧАЛ МАЯКА «%s» · РЕМОНТ КОРПУСА" % String(dock_b["name"]).to_upper(), 1]
		return ["E", "ЗАЖЕЧЬ МАЯК «%s»" % String(dock_b["name"]).to_upper(), 2]
	if not trailer_resource.is_empty():
		return ["", "ПЛАШКОУТ · АВТОСБОР: %s" % trailer_resource.to_upper(), 1]
	if not resource_name.is_empty():
		return ["ПРОБЕЛ", "ЗАБРАТЬ С ЛЕВОГО БОРТА: %s" % resource_name.to_upper(), 1]
	if main.boat.wrong_side_target:
		if main.boat.has_trailer:
			return ["", "ПОДВЕДИТЕ ЛЕВЫЙ БОРТ ИЛИ БОРТ ПЛАШКОУТА", 2]
		return ["", "ПОВЕРНИТЕСЬ ЛЕВЫМ БОРТОМ К ПЯТНУ", 2]
	if not next_b.is_empty():
		var at: Vector3 = next_b["buoy_pos"]
		var distance := int(round(boat_xz.distance_to(Vector2(at.x, at.z))))
		return ["E", "ДО БУЯ %d М · ПОДОЙДИТЕ НА 14 М" % distance, 0]
	return ["", "ИЩИТЕ СВЕТЯЩИЕСЯ ПЯТНА И ЗАЖИГАЙТЕ МАЯКИ", 0]


# --- Помощники рисования -----------------------------------------------------


static func _back(t: float) -> float:
	var x := clampf(t, 0.0, 1.0) - 1.0
	return 1.0 + 2.70158 * x * x * x + 1.70158 * x * x


## Блок интерфейса: своя ось, свой наклон, качка и вылет с перелётом.
## Возвращает false, пока блок ещё не появился.
func _block(slot: int, pivot: Vector2, base_deg: float, extra_scale: float = 1.0) -> bool:
	var t := (_age - 0.05 * float(slot)) / 0.24
	if t <= 0.0:
		return false
	var grow := _back(t)
	var index := slot % TideTokens.BOB_PERIOD.size()
	var sway: float = TideTokens.BOB_AMP[index] * 0.8 * sin(
		TAU * _time / TideTokens.BOB_PERIOD[index] + TideTokens.BOB_PHASE[index]
	)
	var deg := base_deg + sway - 10.0 * (1.0 - grow)
	var scale_now := _factor * lerpf(0.5, 1.0, grow) * extra_scale
	draw_set_transform(pivot * _factor, deg_to_rad(deg), Vector2(scale_now, scale_now))
	return true


func _write(
	at: Vector2, value: String, kind: int, point: int, color: Color,
	align: int = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1.0
) -> void:
	draw_string(TideTokens.font_of(kind), at, value, align as HorizontalAlignment, width, point, color)


func _ring(center: Vector2, radius: float, from: float, to: float, color: Color, width: float) -> void:
	if absf(to - from) < 0.002:
		return
	var points := maxi(6, int(absf(to - from) * radius / 5.0))
	draw_arc(center, radius, from, to, points, color, width, true)


func _pie(center: Vector2, radius: float, from: float, to: float, color: Color) -> void:
	if to - from < 0.01:
		return
	var points := PackedVector2Array([center])
	var steps := maxi(3, int((to - from) * radius / 6.0))
	for step in range(steps + 1):
		var angle := lerpf(from, to, float(step) / float(steps))
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	draw_colored_polygon(points, color)


func _ticks(center: Vector2, inner: float, outer: float, count: int, spin: float, color: Color, width: float) -> void:
	for index in range(count):
		var angle := spin + TAU * float(index) / float(count)
		var dir := Vector2(cos(angle), sin(angle))
		draw_line(center + dir * inner, center + dir * outer, color, width, true)


func _plate(rect: Rect2, paper: Color, under: Color, hatch: bool = false) -> void:
	var shape := TideShapes.offset(TideShapes.torn_rect(rect.size, 24.0), rect.position)
	if under.a > 0.0:
		TideShapes.fill(self, TideShapes.offset(shape, Vector2(9.0, 10.0)), under)
	TideShapes.fill(self, shape, paper)
	if hatch:
		TideShapes.hatch(self, shape, 8.0, TideTokens.foam_alpha(0.06), 1.0, 58.0)


# --- Кадр --------------------------------------------------------------------


func _draw() -> void:
	if _state.is_empty():
		return
	_factor = minf(size.x / BASE.x, size.y / BASE.y)
	if _factor <= 0.0:
		return
	_view = size / _factor
	_draw_hold()
	_draw_compass()
	_draw_target()
	_draw_telegraph()
	_draw_systems()
	_draw_action()
	_draw_notice()
	_draw_shoal()
	_draw_footer()
	if bool(_state["debug"]):
		_draw_debug()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Трюм: четыре банки-циферблата с пигментом.
func _draw_hold() -> void:
	if not _block(0, Vector2(350, 150), -1.8):
		return
	_plate(Rect2(-326, -128, 652, 262), TideTokens.DEEP, TideTokens.INK, true)
	_write(Vector2(-296, -92), "ТРЮМ · ПИГМЕНТЫ", 1, 20, TideTokens.SONAR)
	var required := int(_state["required"])
	_write(
		Vector2(-296, -92), "%d СЫРЬЯ = 1 ГОТОВЫЙ · R" % required, 1, 16, TideTokens.foam_alpha(0.75),
		HORIZONTAL_ALIGNMENT_RIGHT, 592.0
	)
	var pump_kind := int(_state["pump_kind"])
	for i in range(4):
		var color: Color = ResourceSlick.COLORS[i]
		var center := Vector2(-222.0 + float(i) * 148.0, -6.0)
		var pop := _pop[i] / 0.45
		var radius := 50.0 * (1.0 + 0.22 * pop * pop)
		draw_circle(center, radius + 9.0, TideTokens.INK)
		_ring(center, radius, 0.0, TAU, TideTokens.foam_alpha(0.22), 9.0)
		_ring(center, radius, -PI * 0.5, -PI * 0.5 + TAU * _fill[i], color, 9.0)
		# Насечки по ободу: при работе насоса кольцо «крутится».
		var pumping := pump_kind == i
		var spin := _time * 2.6 if pumping else 0.0
		_ticks(
			center, radius + 12.0, radius + (20.0 if pumping else 16.0), 12, spin,
			color if pumping else TideTokens.foam_alpha(0.35), 3.0 if pumping else 2.0
		)
		if pop > 0.0:
			# Щелчок: новая порция готова — расходящееся кольцо.
			_ring(center, radius + 14.0 + (1.0 - pop) * 34.0, 0.0, TAU, Color(color, pop), 2.0 + 4.0 * pop)
		_write(
			center + Vector2(-50, 16), "%02d" % int(_state["refined"][i]), 1, 44, TideTokens.FOAM,
			HORIZONTAL_ALIGNMENT_CENTER, 100.0
		)
		_write(
			center + Vector2(-70, 84), String(ResourceSlick.NAMES[i]).to_upper(), 1, 17, color,
			HORIZONTAL_ALIGNMENT_CENTER, 140.0
		)
		_write(
			center + Vector2(-70, 104), "%s СЫР." % String(_state["raw_text"][i]), 1, 14,
			TideTokens.foam_alpha(0.75), HORIZONTAL_ALIGNMENT_CENTER, 140.0
		)
	# Ярлык плашкоута висит на нижней кромке трюма.
	var trailer := bool(_state["trailer"])
	var tag := TideShapes.offset(TideShapes.plate(Vector2(430, 40), 8.0), Vector2(-300, 146))
	TideShapes.fill(self, tag, TideTokens.SONAR if trailer else TideTokens.INK)
	if not trailer:
		TideShapes.stroke(self, tag, TideTokens.foam_alpha(0.5), 2.0)
	_write(
		Vector2(-300, 173),
		"ПЛАШКОУТ · АВТОСБОР С ДВУХ БОРТОВ" if trailer else "ПЛАШКОУТА НЕТ · B — КУПИТЬ ЗА 2 ГОТ.",
		1, 16, TideTokens.INK if trailer else TideTokens.foam_alpha(0.85), HORIZONTAL_ALIGNMENT_CENTER, 430.0
	)


## Пеленгатор: роза маяков, курс, развёртка сонара.
func _draw_compass() -> void:
	var pop := _lit_pop / 0.6
	if not _block(1, Vector2(_view.x - 190.0, 196.0), 2.4, 1.0 + 0.12 * pop * pop):
		return
	var center := Vector2.ZERO
	var radius := 132.0
	var sonar := float(_state["sonar"])
	draw_circle(center, radius + 26.0, TideTokens.INK)
	draw_circle(center, radius - 14.0, TideTokens.DEEP)
	# Изобаты прибора: два тонких круга.
	_ring(center, radius * 0.36, 0.0, TAU, TideTokens.foam_alpha(0.14), 1.5)
	_ring(center, radius * 0.66, 0.0, TAU, TideTokens.foam_alpha(0.14), 1.5)
	# Обод: по сегменту на маяк, зажжённые — сонарь.
	var total := maxi(1, int(_state["total"]))
	var lit := int(_state["lit"])
	var gap := 0.09
	for index in range(total):
		var from := -PI * 0.5 + TAU * float(index) / float(total) + gap * 0.5
		var to := -PI * 0.5 + TAU * float(index + 1) / float(total) - gap * 0.5
		_ring(center, radius, from, to, TideTokens.SONAR if index < lit else TideTokens.foam_alpha(0.28), 12.0)
	# Медленно вращающаяся шкала.
	_ticks(center, radius + 12.0, radius + 20.0, 36, _time * 0.12, TideTokens.foam_alpha(0.4), 2.0)
	_ticks(center, radius + 12.0, radius + 26.0, 4, _time * 0.12, TideTokens.FOAM, 3.0)
	if sonar > 0.0:
		# Развёртка: клин идёт по кругу, пятна вспыхивают точками.
		var sweep := fmod(_time * 2.2, TAU)
		_pie(center, radius - 16.0, sweep - 0.5, sweep, Color(TideTokens.SONAR, 0.3))
		var edge := Vector2(cos(sweep), sin(sweep))
		draw_line(center, center + edge * (radius - 16.0), TideTokens.SONAR, 3.0, true)
		for slick in _state["slicks"]:
			var at: Vector2 = slick["at"]
			draw_rect(Rect2(center + at * (radius - 22.0) - Vector2(4, 4), Vector2(8, 8)), ResourceSlick.COLORS[int(slick["kind"])])
		_ring(center, radius - 18.0, -PI * 0.5, -PI * 0.5 + TAU * clampf(sonar / SONAR_FULL, 0.0, 1.0), TideTokens.SONAR, 3.0)
	# Маяки на ободе.
	for beacon in _state["beacons"]:
		var dir: Vector2 = beacon["dir"]
		var at := center + dir * radius
		var side := Vector2(-dir.y, dir.x)
		var is_lit := bool(beacon["lit"])
		var mark := PackedVector2Array([at + dir * 16.0, at - dir * 10.0 + side * 11.0, at - dir * 10.0 - side * 11.0])
		draw_colored_polygon(mark, TideTokens.SONAR if is_lit else TideTokens.FLARE)
		draw_polyline(TideShapes.closed(mark), TideTokens.INK, 2.0, true)
	var target: Dictionary = _state["target"]
	if not target.is_empty():
		var dir_t: Vector2 = target["dir"]
		var pulse := 0.5 + 0.5 * sin(_time * 4.0)
		draw_line(center + dir_t * 34.0, center + dir_t * (radius - 20.0), Color(TideTokens.FLARE, 0.45 + 0.4 * pulse), 3.0, true)
	# Стрелка курса: вымпел.
	var heading: Vector2 = _state["heading"]
	var wing := Vector2(-heading.y, heading.x)
	draw_colored_polygon(
		PackedVector2Array([center + heading * 30.0, center - heading * 16.0 + wing * 13.0, center - heading * 7.0, center - heading * 16.0 - wing * 13.0]),
		TideTokens.FOAM
	)
	# Подпись под прибором: сколько зажжено.
	var label := TideShapes.offset(TideShapes.plate(Vector2(250, 40), 8.0), Vector2(-125, radius + 34.0))
	TideShapes.fill(self, label, TideTokens.SONAR if lit >= total else TideTokens.FOAM)
	_write(
		Vector2(-125, radius + 62.0), "МАЯКИ  %d / %d" % [lit, total], 1, 20, TideTokens.INK,
		HORIZONTAL_ALIGNMENT_CENTER, 250.0
	)
	if pop > 0.0:
		_ring(center, radius + 30.0 + (1.0 - pop) * 60.0, 0.0, TAU, Color(TideTokens.SONAR, pop), 3.0 + 5.0 * pop)


## Билет цели: следующий маяк и его рецепт.
func _draw_target() -> void:
	if not _block(2, Vector2(_view.x - 600.0, 132.0), -2.2):
		return
	var target: Dictionary = _state["target"]
	_plate(Rect2(-200, -84, 400, 178), TideTokens.FOAM, TideTokens.FLARE)
	if target.is_empty():
		_write(Vector2(-172, -42), "ЦЕЛЬ РЕЙСА", 1, 16, TideTokens.ink_alpha(0.7))
		_write(Vector2(-172, 4), "ВСЕ МАЯКИ", 2, 30, TideTokens.INK)
		_write(Vector2(-172, 40), "ЗАЖЖЕНЫ", 2, 30, TideTokens.FLARE)
		return
	_write(Vector2(-172, -46), "ЦЕЛЬ · %d М" % int(target["dist"]), 1, 17, TideTokens.ink_alpha(0.75))
	var name_point := TideTokens.fit_point(TideTokens.font_of(2), String(target["name"]), 344.0, 30, 16)
	_write(Vector2(-172, -10), String(target["name"]), 2, name_point, TideTokens.INK)
	# Рецепт: фишки пигмента «есть / надо».
	var cost: PackedInt32Array = target["cost"]
	var x := -172.0
	for i in range(cost.size()):
		if cost[i] <= 0:
			continue
		var have := int(_state["refined"][i])
		var enough := have >= cost[i]
		draw_rect(Rect2(x, 8, 22, 22), ResourceSlick.COLORS[i])
		draw_rect(Rect2(x, 8, 22, 22), TideTokens.INK, false, 2.0)
		_write(Vector2(x + 28.0, 27), "%d/%d" % [mini(have, 99), cost[i]], 1, 18, TideTokens.INK if enough else TideTokens.FLARE)
		x += 88.0
	var enough_all := bool(target["can_fuel"])
	var strip := TideShapes.offset(TideShapes.plate(Vector2(356, 34), 7.0), Vector2(-178, 42))
	TideShapes.fill(self, strip, TideTokens.SONAR if enough_all else TideTokens.INK)
	_write(
		Vector2(-178, 66), "ХВАТАЕТ → К БУЮ, ЗАТЕМ E" if enough_all else "СОБЕРИТЕ РЕЦЕПТ", 1, 16,
		TideTokens.INK if enough_all else TideTokens.FOAM, HORIZONTAL_ALIGNMENT_CENTER, 356.0
	)


## Машинный телеграф: полукруг хода, внутри — дуга корпуса.
func _draw_telegraph() -> void:
	if not _block(3, Vector2(214.0, _view.y - 132.0), 2.0):
		return
	var center := Vector2(0, 40)
	var radius := 150.0
	var overdrive := float(_state["overdrive"]) > 0.0
	_pie(center, radius + 24.0, PI, TAU, TideTokens.INK)
	draw_rect(Rect2(-radius - 24.0, 38, (radius + 24.0) * 2.0, 60), TideTokens.INK)
	_ring(center, radius, PI, TAU, TideTokens.foam_alpha(0.22), 16.0)
	var tone := TideTokens.FLARE if overdrive else TideTokens.SONAR
	_ring(center, radius, PI, PI + PI * clampf(_speed, 0.0, 1.0), tone, 16.0)
	for index in range(11):
		var angle := PI + PI * float(index) / 10.0
		var dir := Vector2(cos(angle), sin(angle))
		var long := index % 5 == 0
		draw_line(center + dir * (radius + 12.0), center + dir * (radius + (22.0 if long else 17.0)), TideTokens.FOAM if long else TideTokens.foam_alpha(0.5), 3.0 if long else 2.0, true)
	# Корпус: вложенная дуга, ниже 45 % — алая и мигает.
	var hull_low := _hull < 0.45
	var blink := 1.0 if not hull_low else (0.55 + 0.45 * sin(_time * 7.0))
	_ring(center, radius - 30.0, PI, TAU, TideTokens.foam_alpha(0.16), 8.0)
	_ring(
		center, radius - 30.0, PI, PI + PI * _hull,
		Color(TideTokens.FLARE, blink) if hull_low else TideTokens.FOAM, 8.0
	)
	# Стрелка телеграфа.
	var needle := PI + PI * clampf(_speed, 0.0, 1.0)
	var tip := Vector2(cos(needle), sin(needle))
	var side := Vector2(-tip.y, tip.x)
	draw_colored_polygon(
		PackedVector2Array([center + tip * (radius - 4.0), center + tip * 60.0 + side * 7.0, center + tip * 60.0 - side * 7.0]),
		TideTokens.FOAM
	)
	_write(Vector2(-90, 28), "%02d" % roundi(float(_state["speed"])), 1, 64, TideTokens.FOAM, HORIZONTAL_ALIGNMENT_CENTER, 180.0)
	_write(
		Vector2(-150, 62), "ХОД · УЗ. ИЗ %d" % roundi(float(_state["max_speed"])), 1, 15, TideTokens.foam_alpha(0.8),
		HORIZONTAL_ALIGNMENT_CENTER, 300.0
	)
	_write(
		Vector2(-150, 86), "КОРПУС %d%%" % roundi(float(_state["hull"])), 1, 16,
		TideTokens.FLARE if hull_low else TideTokens.foam_alpha(0.85), HORIZONTAL_ALIGNMENT_CENTER, 300.0
	)
	if overdrive:
		_write(Vector2(-150, -50), "ФОРСАЖ", 2, 18, TideTokens.FLARE, HORIZONTAL_ALIGNMENT_CENTER, 300.0)


## Системы судна: три «монеты» с круговым отсчётом и диск сумерек.
func _draw_systems() -> void:
	if not _block(4, Vector2(560.0, _view.y - 128.0), -1.6):
		return
	var timers := [float(_state["sonar"]) / SONAR_FULL, 0.0, float(_state["overdrive"]) / OVERDRIVE_FULL]
	for i in range(3):
		var center := Vector2(-112.0 + float(i) * 98.0, 0.0)
		var left := clampf(float(timers[i]), 0.0, 1.0)
		var active := left > 0.0
		var color: Color = ResourceSlick.COLORS[i]
		var beat := 1.0 + (0.05 * sin(_time * 6.0 + float(i)) if active else 0.0)
		var radius := 36.0 * beat
		draw_circle(center, radius + 6.0, TideTokens.INK)
		draw_circle(center, radius, TideTokens.DEEP)
		if active:
			# Круговой отсчёт: толстая дуга убывает по часовой стрелке.
			_ring(center, radius - 9.0, -PI * 0.5, -PI * 0.5 + TAU * left, TideTokens.SONAR, 10.0)
		var stock := int(_state["refined"][i])
		_ring(center, radius, 0.0, TAU, color if stock > 0 else TideTokens.foam_alpha(0.3), 4.0)
		_write(
			center + Vector2(-30, 13), str(i + 1), 1, 34, TideTokens.FOAM,
			HORIZONTAL_ALIGNMENT_CENTER, 60.0
		)
		_write(
			center + Vector2(-49, 64), SYSTEMS[i], 1, 14, TideTokens.SONAR if active else TideTokens.foam_alpha(0.8),
			HORIZONTAL_ALIGNMENT_CENTER, 98.0
		)
	# Сумерки: диск закрывается «тенью» по мере наступления ночи.
	var moon := Vector2(196.0, 0.0)
	var night := clampf(float(_state["night"]), 0.0, 1.0)
	draw_circle(moon, 42.0, TideTokens.INK)
	draw_circle(moon, 36.0, TideTokens.FOAM)
	_pie(moon, 36.0, -PI * 0.5, -PI * 0.5 + TAU * night, TideTokens.DEEP)
	_ring(moon, 36.0, 0.0, TAU, TideTokens.FOAM, 3.0)
	_write(moon + Vector2(-60, 64), "НОЧЬ %d%%" % roundi(night * 100.0), 1, 14, TideTokens.foam_alpha(0.8), HORIZONTAL_ALIGNMENT_CENTER, 120.0)
	_write(Vector2(-150, -62), String(_state["weather"]), 1, 15, TideTokens.foam_alpha(0.8))


## Плашка действия: клавиша, подсказка, заполнение насосом.
func _draw_action() -> void:
	var bump := 1.0
	if _action_age < 0.2:
		bump = lerpf(0.86, 1.0, _back(_action_age / 0.2))
	if not _block(5, Vector2(_view.x * 0.5, _view.y - 262.0), -1.2, bump):
		return
	var tone := int(_state["tone"])
	var plate_size := Vector2(820, 66)
	var origin := -plate_size * 0.5
	var shape := TideShapes.offset(TideShapes.plate(plate_size, 14.0, 10.0), origin)
	TideShapes.fill(self, TideShapes.offset(shape, Vector2(8, 9)), TideTokens.FLARE if tone == 2 else TideTokens.INK)
	var pump := clampf(float(_state["pump"]), 0.0, 1.0)
	# Пока работает насос, плашка становится бумажной: сонарь заливает её
	# слева направо, чернильный текст читается на обеих половинах.
	TideShapes.fill(self, shape, TideTokens.FOAM if pump > 0.0 else TideTokens.DEEP)
	if pump > 0.0:
		# Насос: плашка заливается слева направо по своей же форме.
		var edge := TideShapes.bounds_of(shape).position.x + TideShapes.bounds_of(shape).size.x * pump
		for piece in TideShapes.clip_left(shape, edge):
			if piece.size() >= 3:
				draw_colored_polygon(piece, TideTokens.SONAR)
	var key := String(_state["key"])
	var text_x := origin.x + 34.0
	if not key.is_empty():
		var key_w := TideTokens.font_of(1).get_string_size(key, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x + 28.0
		var cap := TideShapes.offset(TideShapes.plate(Vector2(key_w, 42), 6.0), Vector2(origin.x + 24.0, -21.0))
		TideShapes.fill(self, cap, TideTokens.INK if pump > 0.0 else TideTokens.FOAM)
		_write(
			Vector2(origin.x + 24.0, 9.0), key, 1, 22, TideTokens.FOAM if pump > 0.0 else TideTokens.INK,
			HORIZONTAL_ALIGNMENT_CENTER, key_w
		)
		text_x += key_w + 14.0
	var room := plate_size.x * 0.5 - text_x - 30.0
	var color := TideTokens.FOAM if tone == 0 else (TideTokens.SONAR if tone == 1 else TideTokens.FOAM)
	if pump > 0.0:
		color = TideTokens.INK
	var point := TideTokens.fit_point(TideTokens.font_of(1), _action_text, room, 24, 14)
	_write(Vector2(text_x, 9.0), _action_text, 1, point, color)


## Сообщение судну: бумажный ярлык выезжает над плашкой действия.
func _draw_notice() -> void:
	if _notice_text.is_empty() or String(_state["notice"]).is_empty():
		return
	var rise := _back(_notice_age / 0.24)
	var pivot := Vector2(_view.x * 0.5, _view.y - 344.0 + 40.0 * (1.0 - rise))
	if not _block(6, pivot, 1.4, lerpf(0.7, 1.0, rise)):
		return
	var font := TideTokens.font_of(0)
	var point := TideTokens.fit_point(font, _notice_text, 900.0, 26, 15)
	var width := minf(940.0, font.get_string_size(_notice_text, HORIZONTAL_ALIGNMENT_LEFT, -1, point).x + 64.0)
	var shape := TideShapes.offset(TideShapes.plate(Vector2(width, 50), 10.0), Vector2(-width * 0.5, -25))
	TideShapes.fill(self, TideShapes.offset(shape, Vector2(6, 7)), TideTokens.FLARE)
	TideShapes.fill(self, shape, TideTokens.FOAM)
	_write(Vector2(-width * 0.5, 10.0), _notice_text, 0, point, TideTokens.INK, HORIZONTAL_ALIGNMENT_CENTER, width)


func _draw_shoal() -> void:
	if not bool(_state["shoal"]):
		return
	var beat := 1.0 + 0.04 * sin(_time * 9.0)
	if not _block(0, Vector2(_view.x * 0.5, 330.0), -2.0, beat):
		return
	var shape := TideShapes.offset(TideShapes.torn_rect(Vector2(640, 84), 18.0), Vector2(-320, -42))
	TideShapes.fill(self, TideShapes.offset(shape, Vector2(8, 9)), TideTokens.INK)
	TideShapes.fill(self, shape, TideTokens.FLARE)
	_write(Vector2(-320, -2), "ОТМЕЛЬ ПО КУРСУ — СНИЗЬТЕ ХОД", 2, 22, TideTokens.FOAM, HORIZONTAL_ALIGNMENT_CENTER, 640.0)
	_write(Vector2(-320, 24), "МАЛАЯ ГЛУБИНА ПОД КОРПУСОМ ИЛИ ВПЕРЕДИ", 1, 15, TideTokens.FOAM, HORIZONTAL_ALIGNMENT_CENTER, 640.0)


func _draw_footer() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(_factor, _factor))
	var right := _view.x - 28.0
	_write(Vector2(0, _view.y - 50.0), KEYS_LINE, 1, 15, TideTokens.foam_alpha(0.7), HORIZONTAL_ALIGNMENT_RIGHT, right)
	_write(Vector2(0, _view.y - 26.0), CONTROLS_LINE, 1, 15, TideTokens.foam_alpha(0.85), HORIZONTAL_ALIGNMENT_RIGHT, right)
	_write(Vector2(0, _view.y - 74.0), String(_state["camera"]), 1, 15, TideTokens.SONAR, HORIZONTAL_ALIGNMENT_RIGHT, right)


## Быстрая проверка [0]: отладочные клавиши плавания.
func _draw_debug() -> void:
	if not _block(6, Vector2(_view.x - 660.0, 520.0), 1.8):
		return
	_plate(Rect2(-200, -150, 400, 300), TideTokens.DEEP, TideTokens.INK, true)
	_write(Vector2(-176, -112), "БЫСТРАЯ ПРОВЕРКА", 1, 20, TideTokens.SONAR)
	_write(Vector2(-176, -112), "%d FPS" % Engine.get_frames_per_second(), 1, 16, TideTokens.foam_alpha(0.8), HORIZONTAL_ALIGNMENT_RIGHT, 352.0)
	var rows := [
		"0 — СКРЫТЬ ПАНЕЛЬ",
		"4 — +3 ГОТОВЫХ КАЖДОГО ЦВЕТА",
		"5 — ДЕНЬ / СУМЕРКИ / НОЧЬ",
		"6 — К СЛЕДУЮЩЕМУ БУЮ",
		"7 — ПРОДОЛЖИТЬ ВРЕМЯ",
		"8 / 9 — НОЧНОЙ ОБЪЁМ − / +",
		"H — ПРОЖЕКТОР: %s" % ("ВКЛ" if bool(_state["headlight"]) else "ВЫКЛ"),
	]
	for index in range(rows.size()):
		_write(Vector2(-176, -76.0 + float(index) * 28.0), rows[index], 1, 16, TideTokens.FOAM)
