class_name BoatSmoke
extends Node
## Headless-проверка нового цикла, не заменяет тесты старой рыбалки.
var main: BoatMain
var ticks := 0
var origin := Vector3.ZERO
var failures := 0
var trail_sample := Vector4.ZERO


func setup(boat_main: BoatMain) -> void:
	main = boat_main
	origin = main.boat.global_position


func _physics_process(_delta: float) -> void:
	ticks += 1
	if ticks == 1:
		_check(main.water != null and main.water.field != null, "волны CPU + шейдерное море")
		_check(main.coast.water_depth(origin.x, origin.z) > 2.0, "лодка спущена на глубокую воду")
		_check(main.slicks.size() >= 6, "SDF-пятна распределены вокруг лодки")
		_check(main.camera.projection == Camera3D.PROJECTION_ORTHOGONAL, "изометрическая камера")
		_check(is_zero_approx(main.boat._window_light.light_energy) and
			not main.boat._window_glass_mat.emission_enabled and
			main.boat._window_glass_mat.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA,
			"днём видны тёмные стёкла, а не светящаяся картонка")
		var yaw := main.boat.rotation.y
		var view_right := main.camera.global_transform.basis.x
		var heading := -main.boat.global_transform.basis.z
		var left_yaw := main.boat.steering_yaw_delta(-1.0, 5.0, 0.2)
		var right_yaw := main.boat.steering_yaw_delta(1.0, 5.0, 0.2)
		var left_heading := -Basis(Vector3.UP, yaw + left_yaw).z
		var right_heading := -Basis(Vector3.UP, yaw + right_yaw).z
		_check(left_heading.dot(view_right) < heading.dot(view_right) and
			right_heading.dot(view_right) > heading.dot(view_right) and
			main.boat.steering_yaw_delta(-1.0, -5.0, 0.2) < 0.0,
			"A ведёт нос влево на экране, D вправо, задний ход инвертирует руль")
		_check(main.beacons.size() == 3 and main.reefs.size() > 0,
			"три маяка и морские рифы созданы")
		var safe_buoys := true
		for beacon in main.beacons:
			var bp: Vector3 = beacon["buoy_pos"]
			if main.coast.water_depth(bp.x, bp.z) < 4.5:
				safe_buoys = false
		_check(safe_buoys, "каждый причальный буй на глубине не менее 4.5 м")
		Input.action_press("boat_forward")
	if ticks == 60:
		trail_sample = main.boat._trail_buffer[2]
		main.boat.rotation.y += 0.35
	if ticks == 61:
		var kept := false
		for i in range(2, BoatVessel.TRAIL_POINTS):
			var old: Vector4 = main.boat._trail_buffer[i]
			if Vector2(old.x, old.y).distance_to(Vector2(trail_sample.x, trail_sample.y)) < 0.001:
				kept = true
				break
		_check(kept and trail_sample.z > 0.0,
			"старый участок кильватера остаётся в мировых координатах при повороте")
	if ticks == 70:
		Input.action_release("boat_forward")
		_check(main.boat.global_position.distance_to(origin) > 1.0, "мотор двигает лодку")
		var first := main.slicks[0]
		main.boat.global_position = first.global_position - Vector3(4.0, 0.0, 1.0)
		main.boat.speed = 0.0
		Input.action_press("boat_pump")
	if ticks == 73:
		_check(main.boat.wrong_side_target and main.raw[0] == 0 and
			main.boat.pump_fraction() == 0.0, "насос не проходит через правый борт")
		var first := main.slicks[0]
		main.boat.global_position = first.global_position + Vector3(4.0, 0.0, 1.0)
	if ticks == 185:
		Input.action_release("boat_pump")
		_check(main.raw[0] == 1 and main.slicks[0].depleted, "насос собирает одно пятно")
		main.receive_resource(0)
		main.receive_resource(0)
		_check(main.refine() == 1 and main.refined[0] == 1 and main.raw[0] == 0,
			"три единицы сырья превращаются в один очищенный материал")
		_check(not main.boat.has_trailer and main.boat.effective_max_speed() == 10.0,
			"прицеп изначально не куплен")
		main.refined[1] = 1
		main.buy_trailer()
		_check(main.boat.has_trailer and main.total_refined() == 0,
			"прицеп покупается за два готовых материала")
		var trailer_before := main.boat._trailer.global_position
		var reverse_next := main.boat.global_position + main.boat.global_transform.basis.z * 2.0
		var can_reverse := main.boat._make_room_for_trailer(reverse_next)
		var trailer_after := main.boat._trailer.global_position
		var clearance := Vector2(trailer_after.x - reverse_next.x,
			trailer_after.z - reverse_next.z).length()
		_check(can_reverse and trailer_after.distance_to(trailer_before) > 0.5 and
			clearance >= BoatVessel.TRAILER_CLEARANCE - 0.001,
			"задний ход отталкивает прицеп, корпуса не пересекаются")
		main.raw[2] = 2
		_check(main.refine() == 1 and main.refined[2] == 1 and main.raw[2] == 0,
			"прицеп снижает цену переработки до двух единиц сырья")
		_check(main.boat.effective_max_speed() > 10.0 and
			main.boat.effective_pump_range() > BoatVessel.PUMP_RANGE,
			"прицеп усиливает мотор и насос")
		# Изолируем рабочую зону прицепа от стартовых пятен и проверяем
		# настоящий сбор по обе стороны через тот же ресурсный цикл.
		main.boat.global_position = origin + Vector3(-220.0, 0.0, 0.0)
		main.boat.rotation.y = 0.0
		main.boat.speed = 0.0
		main.boat._trailer.global_position = main.boat.global_position + Vector3(0.0, 0.0, 9.3)
		main.boat._trailer.rotation.y = 0.0
		var trailer_node := main.boat._trailer
		var arm_mesh: BoxMesh = (main.boat._trailer_arm_pivot.get_child(1) as MeshInstance3D).mesh as BoxMesh
		_check(is_equal_approx(main.boat._trailer_arm_pivot.position.z, 0.0) and
			is_equal_approx(main.boat._trailer_arm_pivot.position.x, 0.0) and
			arm_mesh.size.z > 2.8,
			"длинная рука установлена в центре прицепа")
		_check(not main.boat.is_on_trailer_working_side(trailer_node.to_global(Vector3(0.0, 0.0, 0.3))) and
			not main.boat.is_on_trailer_working_side(trailer_node.to_global(Vector3(0.0, 0.0, -2.2))) and
			main.boat.is_on_trailer_working_side(trailer_node.to_global(Vector3(-3.0, 0.0, 0.3))) and
			main.boat.is_on_trailer_working_side(trailer_node.to_global(Vector3(3.0, 0.0, 0.3))),
			"рука прицепа доступна по обоим бортам, но не в центре и не у носа")
		for side in [-1.0, 1.0]:
			var sample_pos: Vector3 = trailer_node.to_global(Vector3(side * 3.0, 0.0, 0.3))
			var sample := ResourceSlick.new()
			main.add_child(sample)
			sample.setup(main.water, Vector2(sample_pos.x, sample_pos.z), 0, 0.0)
			main.slicks.append(sample)
			var raw_before := main.raw[0]
			main.boat._update_pump(0.01)
			_check(main.boat._target == sample and main.boat.target_from_trailer(),
				"прицеп выбирает пятно с борта %s" % ("левого" if side < 0.0 else "правого"))
			Input.action_press("boat_pump")
			main.boat._update_pump(main.boat.effective_pump_seconds() + 0.01)
			Input.action_release("boat_pump")
			_check(sample.depleted and main.raw[0] == raw_before + 1 and
				main.boat._trailer_hose.visible and not main.boat._hose.visible,
				"прицеп собирает пятно с борта %s своей рукой" % ("левого" if side < 0.0 else "правого"))
			main.slicks.erase(sample)
			sample.queue_free()
		var blocked := ResourceSlick.new()
		main.add_child(blocked)
		main.slicks.append(blocked)
		for local_at in [Vector3(0.0, 0.0, 0.3), Vector3(0.0, 0.0, -2.2)]:
			var blocked_at: Vector3 = trailer_node.to_global(local_at)
			if blocked._mat == null:
				blocked.setup(main.water, Vector2(blocked_at.x, blocked_at.z), 0, 0.0)
			else:
				blocked.global_position = blocked_at
			main.boat._update_pump(0.01)
			_check(main.boat._target != blocked,
				"прицеп не собирает пятно по центру или перед носом")
		main.slicks.erase(blocked)
		blocked.queue_free()
		main.toggle_trailer_free()
		_check(not main.boat.has_trailer, "тестовая клавиша отключает прицеп")
		# В новом районе пятна должны появляться снова, не оставаясь навсегда
		# в стартовом круге. Уходим в открытое море, не заходя на берег.
		main.boat.global_position = origin + Vector3(-220.0, 0.0, 0.0)
		main.boat.speed = 0.0
		# Тест телепортирует лодку; для проверки видимого кадра переносим
		# камеру тоже. При обычной езде она остаётся плавной и инерционной.
		main._camera_focus = main.boat.global_position + Vector3.UP * 0.8
		main.camera.global_position = main._camera_focus + Vector3(21.0, 26.2, 30.0)
		main.camera.look_at(main._camera_focus, Vector3.UP)
		# На экране игра переселяет не более одного пятна за тик.
		for _i in range(main.slicks.size()):
			main._stream_resources()
		var nearby := 0
		var popped_in_view := 0
		for slick in main.slicks:
			if slick.depleted:
				continue
			var slick_xz := Vector2(slick.position.x, slick.position.z)
			if slick_xz.distance_to(Vector2(main.boat.global_position.x,
				main.boat.global_position.z)) < BoatMain.SLICK_RECYCLE_DISTANCE:
				nearby += 1
				if not main._outside_boat_view(slick_xz):
					popped_in_view += 1
		_check(nearby >= 4, "пятна появляются близко к лодке в новом районе")
		_check(popped_in_view == 0, "перемещённые пятна не возникают в кадре")

		# Новые способности: расходы, восстановление и изменение характеристик.
		main.refined[0] = 1
		main.activate_sonar()
		_check(main.sonar_timer > 0.0 and main.refined[0] == 0,
			"сонар расходует бирюзу и показывает пеленги")
		main.boat.hull_hp = 40.0
		main.raw[1] = 2
		main.activate_hull_repair()
		_check(is_equal_approx(main.boat.hull_hp, 85.0) and main.raw[1] == 0,
			"ремонт восстанавливает 45% корпуса за два сырых коралла")
		main._apply_atmosphere(0.70)
		var dusk_before := main.night01
		var glitter_before := float(main.water.material().get_shader_parameter("glitter_amount"))
		main.refined[2] = 1
		main.activate_overdrive()
		_check(main.overdrive_timer > 0.0 and main.refined[2] == 0 and
			main.boat.effective_max_speed() > BoatVessel.MAX_SPEED and
			is_equal_approx(main.night01, dusk_before),
			"форсаж ускоряет судно, но не превращает ночь в день")

		# У причального буя E не списывает материалы, пока рецепт неполный.
		var beacon: Dictionary = main.beacons[0]
		var bp: Vector3 = beacon["buoy_pos"]
		main.boat.global_position = bp
		main.raw[0] = 3
		main.interact_with_beacon()
		_check(not beacon["lit"] and main.raw[0] == 3,
			"неполный рецепт не зажигает маяк и не расходует сырьё")
		var cost: PackedInt32Array = beacon["cost"]
		for i in range(cost.size()):
			main.raw[i] = cost[i] * 3
		main.interact_with_beacon()
		_check(beacon["lit"] and main.lit_beacon_count() == 1 and
			main.total_refined() == 0 and main.raw[0] == 0 and main.raw[2] == 0 and
			main.boat.hull_hp == 100.0 and is_equal_approx(main.night01, dusk_before) and
			is_equal_approx(float(main.water.material().get_shader_parameter("glitter_amount")), glitter_before),
			"маяк питается по рецепту, не подсвечивает весь мир и не меняет глиттер")
		main.boat.hull_hp = 55.0
		main.interact_with_beacon()
		_check(main.boat.hull_hp == 100.0, "зажжённый маяк ремонтирует бесплатно")

		# Проверяем столкновение без пропуска физики в режиме smoke.
		var rf: Dictionary = main.reefs[0]
		var rp: Vector2 = rf["pos"]
		main.boat.set_trailer_enabled(false)
		main.boat.global_position = Vector3(rp.x + float(rf["radius"]) + 1.88,
			Coast.SEA_LEVEL, rp.y)
		main.boat.rotation.y = PI / 2.0
		main.boat.speed = 7.0
		var hp_before := main.boat.hull_hp
		main.boat._physics_process(0.1)
		var gap := Vector2(main.boat.global_position.x, main.boat.global_position.z).distance_to(rp)
		_check(main.boat.hull_hp < hp_before and main.boat.speed == 0.0 and
			gap >= float(rf["radius"]) + 1.85 - 0.01,
			"риф гасит скорость, повреждает корпус и не телепортирует его внутрь")
		main._apply_atmosphere(0.88)
		_check(main.world._sun.light_energy > 0.23 and main.world._sun.light_energy < 0.29 and
			float(main.water.material().get_shader_parameter("sun_path_amount")) < 0.001 and
			main.world._env.volumetric_fog_density > 0.013,
			"ночью нет световой дорожки, а слабый свет сохраняет объём в тумане")
		var night_glitter := float(main.water.material().get_shader_parameter("glitter_amount"))
		_check(not main.world._env.volumetric_fog_enabled,
			"лодка не включает невидимый объёмный туман по умолчанию")
		main.debug_toggle_volumetric_fog()
		_check(main.world._env.volumetric_fog_enabled and
			is_equal_approx(float(main.water.material().get_shader_parameter("glitter_amount")), night_glitter),
			"[G] включает только объёмный туман")
		main.debug_toggle_volumetric_fog()
		_check(not main.world._env.volumetric_fog_enabled, "[G] возвращает обычную дымку")
		_check(is_equal_approx(float(main.world._sky_mat.get_shader_parameter("daylight_scatter")), 0.16),
			"ночное небо снижает дневное рассеяние, не меняя глиттер")
		_check(main.world._env.tonemap_mode == Environment.TONE_MAPPER_AGX and
			main.world._env.ssao_light_affect > 0.0 and
			is_equal_approx(float(main.water.material().get_shader_parameter("surface_light_detail")), 0.16),
			"лодочный профиль включает AgX, SSAO и мягкое освещение волн")
		var before_light := main.world._sun.light_energy
		var before_ambient := main.world._env.ambient_light_energy
		var before_ssao := main.world._env.ssao_light_affect
		var before_sky := float(main.world._sky_mat.get_shader_parameter("daylight_scatter"))
		var spot := main.boat._bow_spot
		_check(spot != null and spot.light_energy > 18.0 and
			spot.spot_range < 30.0 and spot.rotation.x < -0.4,
			"ночной прожектор усилен, оставаясь локальным")
		_check(main.boat._window_interior_mat.emission_energy_multiplier > 3.0 and
			main.boat._window_light.light_energy > 0.8 and
			main.boat._window_light.omni_range < 4.0 and
			main.boat._deck_light.light_energy > 0.4 and
			main.boat._vat_mats[0].emission_energy_multiplier > 0.7,
			"ночью светятся окна, рубка и приборы без глобальной засветки")
		main.debug_toggle_headlight()
		_check(not spot.visible and is_equal_approx(main.world._sun.light_energy, before_light) and
			is_equal_approx(float(main.water.material().get_shader_parameter("glitter_amount")), night_glitter),
			"[H] отключает прожектор без изменения фона и глиттера")
		main.debug_toggle_headlight()
		_check(spot.visible, "[H] возвращает прожектор")
		main.debug_toggle_lighting()
		_check(main.world._env.tonemap_mode == Environment.TONE_MAPPER_FILMIC and
			is_equal_approx(main.world._sun.light_energy, before_light) and
			is_equal_approx(main.world._env.ambient_light_energy, before_ambient) and
			is_equal_approx(main.world._env.ssao_light_affect, before_ssao) and
			is_equal_approx(float(main.world._sky_mat.get_shader_parameter("daylight_scatter")), before_sky) and
			is_equal_approx(float(main.water.material().get_shader_parameter("surface_light_detail")), 0.16) and
			is_equal_approx(float(main.water.material().get_shader_parameter("glitter_amount")), night_glitter),
			"[L] меняет только тонмаппер, сохраняя свет, небо и воду")
		main.debug_toggle_lighting()
		main.debug_adjust_fill(0.04)
		_check(main.world._sun.light_energy > 0.29 and
			is_equal_approx(float(main.water.material().get_shader_parameter("glitter_amount")), night_glitter),
			"[9] добавляет объёмный свет, не изменяя глиттер")
		main.debug_adjust_fill(-0.04)
		var before_grant := main.refined[0]
		main.debug_grant_materials()
		_check(main.refined[0] == before_grant + 3 and main.refined[3] >= 3,
			"[4] выдаёт готовые материалы для быстрой проверки")
		main.debug_cycle_night()
		_check(main.debug_night_paused and is_equal_approx(main.night01, 0.45) and
			main.boat._window_light.light_energy > 0.15 and
			main.boat._window_interior_mat.emission_energy_multiplier > 0.6 and
			main.boat._window_interior_mat.emission_energy_multiplier < 1.6 and
			not main.boat._window_glass_mat.emission_enabled,
			"при 45% тёплый свет виден за стеклом, само стекло не светится")
		main.debug_cycle_night()
		_check(is_equal_approx(main.night01, 0.88), "[5] фиксирует тёмную ночь")
		main.debug_warp_to_beacon()
		_check(not main.nearby_dock_beacon().is_empty() and main.boat.speed == 0.0,
			"[6] доставляет судно к бую без рывка двигателя")
		print("[BOAT SMOKE] итог: %s" % ("ВСЁ ПРОШЛО" if failures == 0 else "%d ОШИБОК" % failures))
		get_tree().quit(0 if failures == 0 else 1)


func _check(ok: bool, description: String) -> void:
	if ok:
		print("[BOAT SMOKE] PASS ", description)
	else:
		failures += 1
		push_error("[BOAT SMOKE] FAIL " + description)
