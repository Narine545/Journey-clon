class_name BoatHud
extends Control
## Интерфейс «Приливной лаборатории»: ресурсы, статус корпуса, радар-пеленгатор маяков и системы судна.
var main: BoatMain


func _draw() -> void:
	if main == null or main.boat == null:
		return
	var font := ThemeDB.fallback_font
	var ink := Color("e9f0e8")
	var muted := Color("9db8b7")
	var accent := Color("78dfcb")
	var warn := Color("f3c783")
	var danger := Color("f07b62")
	var backdrop := Color(0.035, 0.075, 0.10, 0.88)

	# 1. ГЛАВНАЯ ПАНЕЛЬ ЛАБОРАТОРИИ И РЕСУРСОВ
	var panel := Rect2(22, 22, 412, 380)
	draw_rect(panel, backdrop)
	draw_rect(panel, Color("548c89"), false, 1.5)
	draw_string(font, Vector2(42, 52), "ПРИЛИВНАЯ ЛАБОРАТОРИЯ", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, ink)
	draw_string(font, Vector2(42, 76), "ХОД  %02.0f / %.0f УЗ.    КОРПУС  %d%%    СУМЕРКИ  %d%%" % [
		absf(main.boat.speed),
		main.boat.effective_max_speed(),
		int(round(main.boat.hull_hp)),
		int(round(main.night01 * 100.0))
	], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, danger if main.boat.hull_hp < 45.0 else muted)

	var required := 2 if main.boat.has_trailer else 3
	var role_hints := ["[1] СОНАР", "[2] РЕМОНТ", "[3] ФОРСАЖ", "КАТАЛИЗАТОР"]
	for i in range(ResourceSlick.COLORS.size()):
		var y := 105.0 + float(i) * 32.0
		draw_rect(Rect2(42, y - 15, 13, 13), ResourceSlick.COLORS[i])
		draw_string(font, Vector2(64, y - 3), ResourceSlick.NAMES[i].to_upper(), HORIZONTAL_ALIGNMENT_LEFT, 96, 15, ink)
		draw_string(font, Vector2(158, y - 3), role_hints[i], HORIZONTAL_ALIGNMENT_LEFT, 86, 11, muted)
		draw_string(font, Vector2(252, y - 3), "%02d сыр. → %02d гот." % [main.raw[i], main.refined[i]], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, ink)
		draw_rect(Rect2(252, y + 2, 160, 4), Color("273c41"))
		draw_rect(Rect2(252, y + 2, 160.0 * clampf(float(main.raw[i]) / float(required), 0.0, 1.0), 4),
			ResourceSlick.COLORS[i])

	var trailer_status := "ПЛАШКОУТ: НА БУКСИРЕ (2 сыр. → 1 гот.)" if main.boat.has_trailer else "ПЛАШКОУТ: НЕТ  [B — КУПИТЬ ЗА 2 ГОТ. / T — ТЕСТ]"
	draw_string(font, Vector2(42, 236), trailer_status, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, accent if main.boat.has_trailer else muted)

	# Блок экспедиционной цели (Маяки побережья)
	draw_line(Vector2(42, 248), Vector2(412, 248), Color("35585c"), 1.0)
	var lit_count := main.lit_beacon_count()
	var total_b := main.beacons.size()
	draw_string(font, Vector2(42, 270), "МАЯКИ ПОБЕРЕЖЬЯ:  %d / %d ЗАЖЖЕНО" % [lit_count, total_b],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 15, accent if lit_count == total_b else warn)

	var next_b := main.next_unlit_beacon()
	if not next_b.is_empty():
		var bp: Vector3 = next_b["buoy_pos"]
		var dist := int(round(Vector2(main.boat.global_position.x, main.boat.global_position.z).distance_to(Vector2(bp.x, bp.z))))
		draw_string(font, Vector2(42, 292), "ЦЕЛЬ: «%s» (%d М)" % [next_b["name"].to_upper(), dist],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 13, ink)
		draw_string(font, Vector2(42, 312), "РЕЦЕПТ: %s" % main.format_beacon_recipe(next_b["cost"]),
			HORIZONTAL_ALIGNMENT_LEFT, 370, 13, muted)
		var cost: PackedInt32Array = next_b["cost"]
		var can_fuel := true
		for i in range(cost.size()):
			if main.refined[i] + int(main.raw[i] / float(required)) < cost[i]:
				can_fuel = false
				break
		var instruction := "СЫРЬЯ ХВАТАЕТ → К БУЮ (<14 М), ЗАТЕМ [E]" if can_fuel else \
			"СОБЕРИТЕ РЕЦЕПТ: %d СЫРЬЯ = 1 ГОТОВЫЙ [R]" % required
		draw_string(font, Vector2(42, 335), instruction,
			HORIZONTAL_ALIGNMENT_LEFT, 370, 12, accent if can_fuel else warn)
	else:
		draw_string(font, Vector2(42, 295), "ВСЕ МАЯКИ СВЕТА АКТИВИРОВАНЫ!", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, accent)

	var sys_line := "СИСТЕМЫ:  1 — СОНАР %s   2 — РЕМОНТ   3 — ФОРСАЖ %s" % [
		("(%02.0fс)" % main.sonar_timer) if main.sonar_timer > 0.0 else "",
		("(%02.0fс)" % main.overdrive_timer) if main.overdrive_timer > 0.0 else ""
	]
	draw_string(font, Vector2(42, 369), sys_line, HORIZONTAL_ALIGNMENT_LEFT, 370, 12, accent if (main.sonar_timer > 0.0 or main.overdrive_timer > 0.0) else muted)

	# 2. КРУГОВОЙ ПЕЛЕНГАТОР-КОМПАС (справа от главной панели)
	_draw_beacon_compass(font, Vector2(505, 102), 58.0, backdrop, accent, warn, muted, ink)

	# Отладка всегда доступна в лодочном режиме; [0] прячет только панель.
	if main.debug_panel_visible:
		var dbg := Vector2(size.x - 355.0, 22.0)
		draw_rect(Rect2(dbg, Vector2(333, 214)), backdrop)
		draw_rect(Rect2(dbg, Vector2(333, 214)), Color("548c89"), false, 1.0)
		draw_string(font, dbg + Vector2(12, 23), "БЫСТРАЯ ПРОВЕРКА  •  %d FPS" % Engine.get_frames_per_second(),
			HORIZONTAL_ALIGNMENT_LEFT, 309, 14, accent)
		draw_string(font, dbg + Vector2(12, 47), "[0] — СКРЫТЬ / ПОКАЗАТЬ", HORIZONTAL_ALIGNMENT_LEFT, 309, 13, ink)
		draw_string(font, dbg + Vector2(12, 70), "[4] — +3 ГОТОВЫХ КАЖДОГО ЦВЕТА", HORIZONTAL_ALIGNMENT_LEFT, 309, 13, ink)
		draw_string(font, dbg + Vector2(12, 93), "[5] — ДЕНЬ / СУМЕРКИ / НОЧЬ", HORIZONTAL_ALIGNMENT_LEFT, 309, 13, ink)
		draw_string(font, dbg + Vector2(12, 116), "[6] — К СЛЕДУЮЩЕМУ БУЮ", HORIZONTAL_ALIGNMENT_LEFT, 309, 13, ink)
		draw_string(font, dbg + Vector2(12, 139), "[7] — ПРОДОЛЖИТЬ ВРЕМЯ", HORIZONTAL_ALIGNMENT_LEFT, 309, 13, ink)
		draw_string(font, dbg + Vector2(12, 162), "[8] / [9] — НОЧНОЙ ОБЪЁМ - / +", HORIZONTAL_ALIGNMENT_LEFT, 309, 13, ink)
		draw_string(font, dbg + Vector2(12, 185), "[L] — ТОЛЬКО AgX / FILMIC: %s" % (
			"AgX" if main.debug_lighting_profile else "FILMIC"),
			HORIZONTAL_ALIGNMENT_LEFT, 309, 13, accent)
		draw_string(font, dbg + Vector2(12, 207),
			"НОЧЬ %d%%  %s  •  СВЕТ %.2f  ТУМАН %.3f" % [int(main.night01 * 100.0),
				"ПАУЗА" if main.debug_night_paused else "ИДЁТ",
				main.debug_night_fill, main.world._env.fog_density],
			HORIZONTAL_ALIGNMENT_LEFT, 309, 11, muted)

	# 3. КОНТЕКСТНАЯ ПОДСКАЗКА ДЕЙСТВИЯ ВНИЗУ ЭКРАНА
	var dock_b := main.nearby_dock_beacon()
	var resource_name := main.boat.target_name()
	var action := "ИЩИТЕ СВЕТЯЩИЕСЯ ПЯТНА И ЗАЖИГАЙТЕ МАЯКИ НА БЕРЕГУ"
	var action_col := ink

	if not dock_b.is_empty():
		if dock_b["lit"]:
			action = "E — ПРИЧАЛ МАЯКА «%s» (ПОЛНЫЙ РЕМОНТ КОРПУСА)" % dock_b["name"].to_upper()
			action_col = accent
		else:
			action = "E — ЗАЖЕЧЬ МАЯК «%s» (%s)" % [dock_b["name"].to_upper(), main.format_beacon_recipe(dock_b["cost"]).to_upper()]
			action_col = warn
	elif not resource_name.is_empty():
		action = "ПРОБЕЛ — ЗАБРАТЬ (ЛЕВ. БОРТ): %s" % resource_name.to_upper()
		action_col = accent
	elif main.boat.wrong_side_target:
		action = "ПОВЕРНИТЕСЬ ЛЕВЫМ БОРТОМ К ПЯТНУ"
		action_col = warn
	elif not next_b.is_empty():
		var destination: Vector3 = next_b["buoy_pos"]
		var distance := int(round(Vector2(main.boat.global_position.x,
			main.boat.global_position.z).distance_to(Vector2(destination.x, destination.z))))
		action = "ДО БУЯ %d М  •  [E] НА РАССТОЯНИИ ДО 14 М" % distance
		action_col = warn

	var center := Vector2(size.x * 0.5 - 245.0, size.y - 134.0)
	draw_rect(Rect2(center, Vector2(490, 38)), backdrop)
	draw_rect(Rect2(center, Vector2(490, 38)), Color("548c89"), false, 1.0)
	draw_string(font, center + Vector2(14, 25), action, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, action_col)
	if main.boat.pump_fraction() > 0.0:
		draw_rect(Rect2(center + Vector2(0, 35), Vector2(490.0 * main.boat.pump_fraction(), 3)), accent)

	var controls := "W/S — ХОД   A/D — РУЛЬ   ПРОБЕЛ — НАСОС   R — ПЕРЕРАБОТКА   E — МАЯК   1/2/3 — СОНАР/РЕМОНТ/ФОРСАЖ   B/T — ПЛАШКОУТ"
	draw_string(font, Vector2(28, size.y - 28), controls, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, ink)
	if main.notice_time > 0.0:
		draw_string(font, Vector2(size.x * 0.5 - 290, size.y - 168), main.notice, HORIZONTAL_ALIGNMENT_CENTER, 580, 17, warn)


func _draw_beacon_compass(font: Font, center: Vector2, radius: float, backdrop: Color, accent: Color, warn: Color, muted: Color, ink: Color) -> void:
	draw_circle(center, radius, backdrop)
	var ring_col := accent if main.sonar_timer > 0.0 else Color("548c89")
	draw_arc(center, radius, 0.0, TAU, 40, ring_col, 1.8)
	draw_arc(center, radius * 0.55, 0.0, TAU, 28, Color(0.25, 0.45, 0.48, 0.35), 1.0)

	var cam_right := Vector2(main.camera.global_transform.basis.x.x, main.camera.global_transform.basis.x.z).normalized()
	var cam_up := Vector2(-main.camera.global_transform.basis.z.x, -main.camera.global_transform.basis.z.z).normalized()
	var boat_xz := Vector2(main.boat.global_position.x, main.boat.global_position.z)

	# Курс самого судна в центре радара
	var ship_fwd_3d := -main.boat.global_transform.basis.z
	var ship_fwd_xz := Vector2(ship_fwd_3d.x, ship_fwd_3d.z).normalized()
	var ship_scr := Vector2(ship_fwd_xz.dot(cam_right), -ship_fwd_xz.dot(cam_up)).normalized()
	draw_line(center - ship_scr * 8.0, center + ship_scr * 12.0, ink, 2.2)

	# Если активен сонар [1], подсвечиваем на радаре ближайшие ресурсные пятна
	if main.sonar_timer > 0.0:
		for slick in main.slicks:
			if slick.depleted:
				continue
			var rel_s := Vector2(slick.position.x, slick.position.z) - boat_xz
			var d_s := rel_s.length()
			if d_s < 85.0 and d_s > 1.0:
				var dir_s := rel_s / d_s
				var scr_s := Vector2(dir_s.dot(cam_right), -dir_s.dot(cam_up))
				var pt_s := center + scr_s * clampf(d_s / 85.0, 0.15, 0.90) * (radius - 6.0)
				draw_circle(pt_s, 3.0, ResourceSlick.COLORS[slick.kind])

	# Отображаем все 3 Маяка на ободе компаса
	for b in main.beacons:
		var bp: Vector3 = b["buoy_pos"]
		var rel := Vector2(bp.x, bp.z) - boat_xz
		var dist := rel.length()
		if dist < 0.5:
			continue
		var dir := rel / dist
		var scr := Vector2(dir.dot(cam_right), -dir.dot(cam_up)).normalized()
		var marker_pos := center + scr * (radius - 9.0)
		var b_col := accent if b["lit"] else warn
		draw_circle(marker_pos, 4.5, b_col)
		if not b["lit"]:
			draw_line(center + scr * 16.0, marker_pos - scr * 5.0, Color(warn.r, warn.g, warn.b, 0.55), 1.5)

	draw_string(font, center + Vector2(-38, radius + 18), "ПЕЛЕНГ МАЯКОВ", HORIZONTAL_ALIGNMENT_CENTER, 76, 11, muted)
