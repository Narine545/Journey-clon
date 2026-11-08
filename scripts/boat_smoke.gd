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
	# Освещение ниже проверяется в прежнем фиксированном плотном тумане.
	# Собственно погода отдельно проверяется без подмены игровых вероятностей.
	main.weather.fog_amount = 1.0
	main.weather.cloud_amount = 0.0
	main._apply_atmosphere(main.night01)
	origin = main.boat.global_position


func _physics_process(_delta: float) -> void:
	ticks += 1
	if ticks == 1:
		_check(main.water != null and main.water.field != null, "волны CPU + шейдерное море")
		_check(main.coast.water_depth(origin.x, origin.z) > 2.0, "лодка спущена на глубокую воду")
		_check(main.slicks.size() >= 6, "SDF-пятна распределены вокруг лодки")
		_check(main.camera.projection == Camera3D.PROJECTION_ORTHOGONAL, "изометрическая камера")
		_check(is_zero_approx(main.boat._window_light.light_energy) and
			is_zero_approx(main.boat._window_glass_mat.emission_energy_multiplier) and
			main.boat._window_glass_mat.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA,
			"днём весь прозрачный стеклопакет остаётся тёмным")
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
		_check(main.beacons.size() == 4 and main.reefs.size() > 0,
			"четыре маяка и морские рифы созданы")
		var safe_buoys := true
		for beacon in main.beacons:
			var bp: Vector3 = beacon["buoy_pos"]
			if main.coast.water_depth(bp.x, bp.z) < 4.5:
				safe_buoys = false
		_check(safe_buoys, "каждый причальный буй на глубине не менее 4.5 м")
		_check_island_harbor()
		_check_shoal_navigation()
		_check_resource_zones()
		_check_buoy_dynamics()
		_check_photo_mode()
		_check_camera_framing()
		_check_reef_signals()
		_check_raid()
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
		for edge_point in [Vector2(Coast.CENTER.x - Coast.SIZE * 0.5, 0.0),
			Vector2(Coast.CENTER.x + Coast.SIZE * 0.5, 0.0),
			Vector2(Coast.CENTER.x, -Coast.SIZE * 0.5),
			Vector2(Coast.CENTER.x, Coast.SIZE * 0.5)]:
			_check(is_equal_approx(main.coast.sample_height(edge_point.x, edge_point.y),
				Coast.OUTER_SEABED), "край рельефа согласован с внешним дном воды")
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
			main.boat.is_on_trailer_working_side(trailer_node.to_global(Vector3(-10.0, 0.0, 0.3))) and
			main.boat.is_on_trailer_working_side(trailer_node.to_global(Vector3(10.0, 0.0, 0.3))) and
			main.boat.is_on_trailer_working_side(trailer_node.to_global(Vector3(1.0, 0.0, 0.3))) and
			main.boat.is_on_trailer_working_side(trailer_node.to_global(Vector3(2.0, 0.0, 4.5))) and
			not main.boat.is_on_trailer_working_side(trailer_node.to_global(Vector3(0.0, 0.0, 0.3))) and
			not main.boat.is_on_trailer_working_side(trailer_node.to_global(Vector3(2.0, 0.0, -4.0))) and
			not main.boat.is_on_trailer_working_side(trailer_node.to_global(Vector3(11.5, 0.0, 0.3))),
			"прицеп собирает у кромки обоих бортов, но не по оси и не у носа")
		for side_x in [-10.0, 10.0, 1.0]:
			var sample_pos: Vector3 = trailer_node.to_global(Vector3(side_x, 0.0, 0.3))
			var sample := ResourceSlick.new()
			main.add_child(sample)
			sample.setup(main.water, Vector2(sample_pos.x, sample_pos.z), 0, 0.0)
			main.slicks.append(sample)
			var raw_before := main.raw[0]
			var zone := "близкой кромки" if side_x == 1.0 else ("левого борта" if side_x < 0.0 else "правого борта")
			main.boat.speed = 7.0 # автосбор без ручного ввода даже на ходу
			main.boat._update_pump(0.01)
			_check(main.boat._trailer_target == sample and
				main.boat.trailer_pump_fraction() > 0.0 and
				not Input.is_action_pressed("boat_pump"),
				"прицеп сам выбирает пятно у %s" % zone)
			main.boat._update_pump(BoatVessel.TRAILER_PUMP_SECONDS + 0.01)
			_check(sample.depleted and main.raw[0] == raw_before + 1 and
				main.boat._trailer_hose.visible and not main.boat._hose.visible,
				"прицеп автоматически собирает пятно у %s" % zone)
			main.boat.speed = 0.0
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
			_check(main.boat._trailer_target != blocked and not blocked.depleted,
				"автоматический насос не собирает пятно по центру или перед носом")
		main.slicks.erase(blocked)
		blocked.queue_free()
		main.toggle_trailer_free()
		_check(not main.boat.has_trailer and main.boat._trailer_target == null and
			is_zero_approx(main.boat.trailer_pump_fraction()),
			"отстыковка прицепа отключает автоматический насос")
		# A voyage must not pull the world's deposits toward the vessel.
		var zone_positions: Array[Vector3] = []
		for zone_slot in main.resource_zones.slots:
			var zone_slick: ResourceSlick = zone_slot["slick"]
			zone_positions.append(zone_slick.position)
		main.boat.global_position = origin + Vector3(-220.0, 0.0, 0.0)
		main.boat.speed = 0.0
		main._camera_focus = main.boat.global_position + Vector3.UP * 0.8
		main.camera.global_position = main._camera_focus + Vector3(21.0, 26.2, 30.0)
		main.camera.look_at(main._camera_focus, Vector3.UP)
		main.resource_zones.update(1.0)
		for zone_index in range(main.resource_zones.slots.size()):
			var zone_slick: ResourceSlick = main.resource_zones.slots[zone_index]["slick"]
			_check(zone_slick.position == zone_positions[zone_index],
				"выход в другой район не переселяет пятна к лодке")

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
		if RenderingServer.get_rendering_device() != null:
			_check(beacon["beam_volume"] != null and beacon["beam_volume"].visible,
				"активированный маяк включает локальную дымку вращающегося луча")
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
		# Регресс «свет не работает на атмосферу»: раньше fade_boat_sun()
		# домножал light_volumetric_fog_energy на (1 - sunset), и к ночи
		# ключ переставал рассеиваться в воздухе вовсе.
		_check(main.world._sun.light_volumetric_fog_energy > 1.0,
			"ключевой свет продолжает рассеиваться в тумане и ночью")
		# Регресс «странный свет ночью»: ночное направление было
		# (-0.62, +0.22, -0.75), то есть светило не садилось.
		_check(main.game.sun_dir.y < 0.0,
			"к ночи солнце действительно уходит под горизонт")
		var day_sun_y: float = main.world.boat_sun_dir(0.0).y
		_check(day_sun_y > 0.5 and main.world.boat_sun_dir(0.45).y > 0.0,
			"днём солнце высоко, на закате ещё над горизонтом")
		var night_glitter := float(main.water.material().get_shader_parameter("glitter_amount"))
		# Объём включён по умолчанию: без volumetric_fog_enabled Forward+
		# пропускает весь проход, включая FogVolume с RME4-шейдером.
		_check(main.world._env.volumetric_fog_enabled,
			"объёмный туман включён в лодочном профиле по умолчанию")
		main.debug_toggle_volumetric_fog()
		_check(not main.world._env.volumetric_fog_enabled and
			is_equal_approx(float(main.water.material().get_shader_parameter("glitter_amount")), night_glitter),
			"[G] выключает весь volumetric-проход, не трогая воду")
		main.debug_toggle_volumetric_fog()
		_check(main.world._env.volumetric_fog_enabled, "[G] возвращает объёмный туман")
		_check(is_equal_approx(float(main.world._sky_mat.get_shader_parameter("daylight_scatter")), 0.16),
			"ночное небо снижает дневное рассеяние, не меняя глиттер")
		# Атмосфера применяется одним вызовом. Если писателей снова станет
		# несколько, повторное применение даст другой результат.
		var once_density := main.world._env.volumetric_fog_density
		var once_energy := main.world._sun.light_energy
		var once_ambient := main.world._env.ambient_light_energy
		main._apply_atmosphere(0.88)
		_check(is_equal_approx(main.world._env.volumetric_fog_density, once_density) and
			is_equal_approx(main.world._sun.light_energy, once_energy) and
			is_equal_approx(main.world._env.ambient_light_energy, once_ambient),
			"повторное применение ночи идемпотентно (нет конфликтующих записей)")
		_check(main.world._env.tonemap_mode == Environment.TONE_MAPPER_AGX and
			main.world._env.ssao_light_affect > 0.0 and
			is_equal_approx(float(main.water.material().get_shader_parameter("surface_light_detail")), 0.16),
			"лодочный профиль включает AgX, SSAO и мягкое освещение волн")
		var before_light := main.world._sun.light_energy
		var before_ambient := main.world._env.ambient_light_energy
		var before_ssao := main.world._env.ssao_light_affect
		var before_sky := float(main.world._sky_mat.get_shader_parameter("daylight_scatter"))
		# Форсаж включён этим же физическим тиком (activate_overdrive выше),
		# а overdrive_timer внутри одного тика не уменьшается. Он даёт
		# прожектору ×1.35 к энергии и ×1.20 к дальности, то есть здесь
		# измерялся бы временный буст, а не базовый ночной свет —
		# spot_range уезжал на 32.16 при пороге 30. Сбрасываем на обычное
		# ночное состояние: проверяем именно «усилен, оставаясь локальным».
		main.boat.update_night_lights(main.night01, false)
		var spot := main.boat._bow_spot
		_check(spot != null and spot.light_energy > 36.0 and
			spot.spot_range < 30.0 and spot.rotation.x < -0.1 and spot.rotation.x > -0.3 and
			spot.position.z < -5.7 and spot.position.y > 1.4 and spot.position.y < 2.0,
			"ночной прожектор усилен, оставаясь локальным")
		_check(main.boat._window_glass_mat.emission_energy_multiplier > 0.8 and
			main.boat._window_glass_mat.emission == Color("ffd49a") and
			main.boat._window_light.light_energy > 0.8 and
			main.boat._window_light.omni_range < 4.0 and
			main.boat._deck_light.light_energy > 0.4 and
			main.boat._vat_mats[0].emission_energy_multiplier > 0.7,
			"ночью светятся окна, рубка и приборы без глобальной засветки")
		_check(main.boat._body.has_node("BridgeFrontWindow0") and
			main.boat._body.has_node("BridgeFrontWindow1") and
			main.boat._body.has_node("BridgeFrontWindow2"),
			"носовая стенка мостика имеет три отдельных стекла")
		_check(main.boat._practical_lights.size() == 4 and
			main.boat._cargo_light.omni_range < 3.0 and
			main.boat._intake_light.get_parent() == main.boat._intake_head,
			"навигационные/мачтовые огни и груз имеют ограниченный локальный свет")
		main.debug_toggle_headlight()
		_check(not spot.visible and is_equal_approx(main.world._sun.light_energy, before_light) and
			is_equal_approx(float(main.water.material().get_shader_parameter("glitter_amount")), night_glitter),
			"[H] отключает прожектор без изменения фона и глиттера")
		_check(is_equal_approx(float(main.water.material().get_shader_parameter(
			"night_surface_fill")), 0.18),
			"ночная вода сохраняет собственный слабый фон при выключенном прожекторе")
		main.debug_toggle_headlight()
		_check(spot.visible, "[H] возвращает прожектор")
		_check(main.boat._bow_lens_mat.emission_energy_multiplier > 0.0,
			"[H] возвращает свечение линзы вместе с реальным прожектором")
		main.debug_toggle_local_water_response()
		_check(is_zero_approx(float(main.water.material().get_shader_parameter(
			"local_water_response"))) and
			is_equal_approx(float(main.water.material().get_shader_parameter("glitter_amount")),
				night_glitter), "[I] возвращает прежний отклик локальных ламп без изменения глиттера")
		main.debug_toggle_local_water_response()
		_check(is_equal_approx(float(main.water.material().get_shader_parameter(
			"local_water_response")), 1.0), "[I] возвращает волновое отражение фонаря")
		_check(not main.debug_retro_enabled and not main._retro_rect.visible and
			main._retro_rect.material is ShaderMaterial and
			main._retro_rect.size == Vector2(main.get_viewport().get_visible_rect().size) and
			(main._retro_rect.get_parent() as CanvasLayer).layer == 11,
			"ретро-постэффект по умолчанию выключен и расположен ниже HUD")
		main.debug_toggle_retro()
		_check(main.debug_retro_enabled and main._retro_rect.visible and
			is_equal_approx(float(main.water.material().get_shader_parameter("glitter_amount")), night_glitter),
			"[V] включает экранный эффект без изменения воды")
		main.debug_toggle_retro()
		_check(not main.debug_retro_enabled and not main._retro_rect.visible,
			"[V] возвращает изображение без постэффекта")
		if RenderingServer.get_rendering_device() == null:
			_check(not main.debug_rme4_enabled and main._rme4_volume == null,
				"в Compatibility RME4-объём не создаётся и не обещает воздух")
		else:
			# В Forward+ слой воздуха — штатная часть сцены, а не отладка.
			_check(main.debug_rme4_enabled and main._rme4_volume != null and
				main._rme4_volume.visible and
				main._rme4_volume.material is ShaderMaterial and
				main._rme4_volume.size == BoatMain.RME4_BOX_SIZE,
				"RME4-слой воздуха создан при старте и виден по умолчанию")
			_check(is_zero_approx(main.world._env.volumetric_fog_density) and
				main.world._env.volumetric_fog_enabled,
				"при живом RME4-слое глобальная плотность нулевая: нет двойной пелены")
			var rme4_mat: ShaderMaterial = main._rme4_volume.material
			_check(float(rme4_mat.get_shader_parameter("density_scale")) > 0.02 and
				rme4_mat.get_shader_parameter("density_noise") != null,
				"RME4-шейдер получил рабочую плотность и 3D-шум")
			_check(is_equal_approx(float(rme4_mat.get_shader_parameter("mystery_profile")), 1.0),
				"низкий профиль у воды включён по умолчанию")
			main.debug_toggle_mystery_atmosphere()
			_check(is_zero_approx(float(rme4_mat.get_shader_parameter("mystery_profile"))) and
				is_zero_approx(main.world._env.volumetric_fog_density),
				"[O] возвращает старый профиль без второго слоя плотности")
			main.debug_toggle_mystery_atmosphere()
			_check(is_equal_approx(float(rme4_mat.get_shader_parameter("mystery_profile")), 1.0),
				"[O] возвращает низкий туман")
			var fog_glitter_before := float(main.water.material().get_shader_parameter("glitter_amount"))
			var fog_sun_before := main.world._sun.light_volumetric_fog_energy
			main.debug_toggle_rme4_fog()
			_check(not main.debug_rme4_enabled and not main._rme4_volume.visible and
				main.world._env.volumetric_fog_density > 0.005 and
				is_equal_approx(main.world._sun.light_volumetric_fog_energy, fog_sun_before) and
				is_equal_approx(float(main.water.material().get_shader_parameter("glitter_amount")), fog_glitter_before),
				"[J] выключает RME4 и подставляет ровную дымку, не трогая свет и воду")
			main.debug_toggle_rme4_fog()
			_check(main.debug_rme4_enabled and main._rme4_volume.visible and
				is_zero_approx(main.world._env.volumetric_fog_density),
				"[J] возвращает RME4-слой и убирает глобальную плотность")
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
			main.boat._window_glass_mat.emission_energy_multiplier > 0.15 and
			main.boat._window_glass_mat.emission_energy_multiplier < 0.4 and
			main.boat._window_glass_mat.albedo_color.a < 0.5,
			"при 45% вся поверхность окон мягко светится янтарным и остаётся прозрачной")
		main.debug_cycle_night()
		_check(is_equal_approx(main.night01, 0.88), "[5] фиксирует тёмную ночь")
		main.debug_warp_to_beacon()
		_check(not main.nearby_dock_beacon().is_empty() and main.boat.speed == 0.0,
			"[6] доставляет судно к бую без рывка двигателя")
		_check_slick_disturbance()
		_check_partial_slick_collection()
		_check_weather()
		_check_world_inspector()
		print("[BOAT SMOKE] итог: %s" % ("ВСЁ ПРОШЛО" if failures == 0 else "%d ОШИБОК" % failures))
		get_tree().quit(0 if failures == 0 else 1)


func _check(ok: bool, description: String) -> void:
	if ok:
		print("[BOAT SMOKE] PASS ", description)
	else:
		failures += 1
		push_error("[BOAT SMOKE] FAIL " + description)


func _check_slick_disturbance() -> void:
	var probe := ResourceSlick.new()
	main.add_child(probe)
	var center := Vector2(main.boat.global_position.x, main.boat.global_position.z)
	probe.setup(main.water, center, 0, 17.0)
	var before := center + Vector2(0.0, 0.2)
	var after := center - Vector2(0.0, 0.2)
	var forward := Vector2(0.0, -1.0)
	probe.react_to_sweep(center, center, forward, 4.7, 1.6, 0.1)
	probe.react_to_sweep(before + Vector2(30.0, 0.0), after + Vector2(30.0, 0.0),
		forward, 4.7, 1.6, 0.1)
	probe.react_to_sweep(center + Vector2(0.0, 30.0), center - Vector2(0.0, 30.0),
		forward, 4.7, 1.6, 0.1)
	_check(probe._film == null, "плёнка не создаётся при стоянке, дальнем проходе и телепорте")
	probe.react_to_sweep(center + Vector2(0.0, 7.6), center + Vector2(0.0, 7.2),
		forward, 4.7, 1.6, 0.1)
	for step in range(10):
		probe._update_disturbance(0.05)
	_check(probe._film != null and not probe._film.disturbed and is_zero_approx(probe._film_blend),
		"до физического касания пятно сохраняет обычный бесформенный контур")
	probe._reset_disturbance()
	probe._glow_charge = 0.6
	probe.react_to_sweep(before, after, forward, 4.7, 1.6, 0.1)
	var film := probe._film
	var count := film.positions.size()
	for step in range(12):
		probe.react_to_sweep(before, after, forward, 4.7, 1.6, 0.1)
		probe._update_disturbance(0.05)
	var moved := false
	for i in range(count):
		moved = moved or film.positions[i].distance_to(film.origins[i]) > 0.3
	_check(moved and probe._film_blend > 0.9 and count > 40 and
		count == film.positions.size() and not probe.depleted and
		is_equal_approx(probe._glow_charge, 0.6),
		"корпус переносит частицы пигмента, не тратит массу, ресурс и ночной заряд")
	var pickup := probe.pickup_position(Vector3(center.x - 3.0, probe.position.y, center.y))
	_check(pickup.distance_to(probe.global_position) > 0.5,
		"насос целится в сгусток, а не в пустой центр разошедшегося пятна")
	film.push_hull(Vector2.ZERO, Vector2.ZERO, forward, 4.7, 1.6, 4.0, 0)
	film.push_hull(Vector2.ZERO, Vector2.ZERO, forward, 2.8, 1.4, 4.0, 1)
	_check(film._hulls.size() == 2, "судно и баржа сохраняют независимые воздействия в одном шаге")
	film._hulls.clear()
	for step in range(230):
		probe._update_disturbance(0.05)
	_check(probe._film == null and is_zero_approx(probe._film_blend),
		"затихшая плёнка освобождает симуляцию и возвращает обычный живой контур")
	probe.react_to_sweep(before, after, forward, 2.8, 1.4, 0.1, 1)
	_check(probe._film != null, "баржа снова активирует плёнку после затихания")
	probe.relocate_smoothly(probe.position)
	_check(probe._film == null, "перенос пятна сбрасывает старое поле")
	probe._fade = 1.0
	probe.react_to_sweep(before, after, forward, 4.7, 1.6, 0.1)
	probe.collect()
	probe.react_to_sweep(before, after, forward, 4.7, 1.6, 0.1)
	_check(probe.depleted and probe._film == null, "собранное пятно не хранит и не запускает плёнку")
	probe.queue_free()


func _check_partial_slick_collection() -> void:
	var probe := ResourceSlick.new()
	main.add_child(probe)
	var center := Vector2(main.boat.global_position.x, main.boat.global_position.z)
	probe.setup(main.water, center, 0, 17.0)
	var film := SlickFilm.new()
	film.setup(17.0, 17.0)
	# Детерминированный fixture: два не связанных плотностью сгустка.
	for i in range(film.positions.size()):
		var side: float = -1.0 if film.positions[i].x < 0.0 else 1.0
		film.positions[i] += Vector2(side * 1.2, 0.0)
	film._upload()
	probe._film = film
	probe._film_blend = 1.0
	probe._glow_charge = 0.6
	var count := film.positions.size()
	var stock := main.raw[0]
	var first := probe.collect_portion(probe.global_position + Vector3.LEFT * 3.0)
	main.receive_resource(0, first)
	_check(first > 0.1 and first < 0.9 and not probe.depleted and
		probe._film != null and film.positions.size() < count and
		is_equal_approx(probe.remaining_mass + first, 1.0) and
		is_equal_approx(probe._glow_charge, 0.6),
		"сбор одной доли удаляет только её массу и сохраняет вторую с цветом/зарядом")
	probe._update_disturbance(5.0)
	probe.relocate_smoothly(probe.position + Vector3.RIGHT)
	_check(probe._film == film and film.persistent and probe._film_blend > 0.9 and
		is_equal_approx(probe.remaining_mass, 1.0 - first),
		"частичный остаток не отрастает до целого при затихании и переносе")
	var second := probe.collect_portion(probe.global_position + Vector3.RIGHT * 3.0)
	main.receive_resource(0, second)
	_check(probe.depleted and probe._film == null and
		is_equal_approx(first + second, 1.0) and is_equal_approx(main.raw[0], stock + 1.0),
		"две собранные доли дают ровно один исходный ресурс, без потерь и дублирования")
	_check(is_zero_approx(probe.collect_portion(probe.global_position)),
		"повторный сбор истощённого пятна не выдаёт ресурс")
	probe._respawn = 0.0
	probe._process(0.0)
	_check(not probe.depleted and is_equal_approx(probe.remaining_mass, 1.0),
		"обычный респавн восстанавливает полный запас только после истощения")
	main.raw[0] = stock
	probe.queue_free()


func _check_weather() -> void:
	var model := SeaWeather.new()
	model.setup(137)
	var day := SeaWeather.weights(0.0)
	var night := SeaWeather.weights(0.88)
	_check(day[2] + day[3] < 0.3 and night[2] + night[3] > 0.75 and night[0] > 0.0,
		"погода предпочитает ночной туман, но допускает ясную ночь и дневной туман")
	model._from_fog = 0.0
	model._target_fog = 1.0
	model._from_cloud = 0.0
	model._target_cloud = 0.8
	model._transition_time = 20.0
	model._transition_elapsed = 0.0
	model.advance(10.0, 0.88)
	_check(is_equal_approx(model.fog_amount, 0.5) and is_equal_approx(model.cloud_amount, 0.4),
		"фронт плавно меняет туман и облачность при неподвижных часах ночи")
	model.advance(10.0, 0.88)
	_check(is_equal_approx(model.fog_amount, 1.0), "погодный переход доходит до цели без скачка")
	var old_fog := main.weather.fog_amount
	var old_cloud := main.weather.cloud_amount
	main.weather.fog_amount = 0.0
	main.weather.cloud_amount = 0.0
	main._apply_atmosphere(main.night01)
	var clear_density := main.world._env.fog_density
	var clear_light := main.world._sun.light_energy
	var spot_energy := main.boat._bow_spot.light_energy
	var glitter: Variant = main.water.material().get_shader_parameter("glitter_amount")
	if main._rme4_material != null:
		_check(is_zero_approx(float(main._rme4_material.get_shader_parameter("weather_fog"))),
			"ясная погода обнуляет низкую плёнку тумана, не отключая весь volumetric-pass")
	main.weather.fog_amount = 1.0
	main.weather.cloud_amount = 1.0
	main._apply_atmosphere(main.night01)
	_check(main.world._env.fog_density > clear_density and
		main.world._sun.light_energy < clear_light and
		is_equal_approx(main.boat._bow_spot.light_energy, spot_energy) and
		main.water.material().get_shader_parameter("glitter_amount") == glitter,
		"погода меняет дымку/ключ, не меняя энергию фонаря и рисунок водных искр")
	main.weather.fog_amount = old_fog
	main.weather.cloud_amount = old_cloud
	main._apply_atmosphere(main.night01)


func _check_world_inspector() -> void:
	var tool := main.inspector
	var rect := Rect2(28.0, 92.0, 600.0, 600.0)
	var bounds := WorldInspector.map_bounds()
	var corner := WorldInspector.world_to_map(bounds.position, rect)
	var round_trip := WorldInspector.map_to_world(corner, rect)
	_check(corner.is_equal_approx(rect.position) and round_trip.is_equal_approx(bounds.position),
		"карта использует мировые X/Z и правильные конечные границы рельефа")
	var boat_position := main.boat.global_position
	var old_size := main.camera.size
	var old_far := main.camera.far
	var old_transform := main.camera.global_transform
	var old_fog := main.world._env.fog_enabled
	var old_volume := main.world._env.volumetric_fog_enabled
	var old_weather := main.weather.fog_amount
	var old_markers: Array[Vector3] = tool.markers.duplicate()
	var old_selected := tool.selected
	tool.set_free_camera(true)
	_check(main.inspection_active() and main.boat.global_position.is_equal_approx(boat_position),
		"свободная камера включает отдельное управление, не телепортируя судно")
	main.camera.global_position = Vector3(-100.0, 200.0, 0.0)
	main.camera.look_at(Vector3(-100.0, 0.0, 0.0), Vector3.FORWARD)
	var hit := tool.pick_surface(tool.size * 0.5)
	var picked := Vector3.ZERO
	if not hit.is_empty():
		picked = hit["point"]
	_check(not hit.is_empty() and picked.distance_to(Vector3(-100.0, 0.0, 0.0)) < 0.1,
		"щелчок по морю даёт координату уровня воды, а не удалённого дна")
	tool.add_marker(Vector3(-100.0, 0.0, 0.0))
	var report := tool.make_report()
	_check(report["point"] != null and report.has("camera_position") and
		report.has("weather_fog") and report.has("volume_length") and report.has("ground_height"),
		"отчёт содержит метку, камеру, погоду и границы рендерных областей")
	tool.overview()
	_check(tool.clear_view and main.camera.size > 900.0 and
		not main.world._env.fog_enabled and not main.world._env.volumetric_fog_enabled and
		is_equal_approx(main.weather.fog_amount, old_weather),
		"общий вид показывает всю карту без дымки, не подменяя игровую погоду")
	tool.set_free_camera(false)
	_check(not main.inspection_active() and is_equal_approx(main.camera.size, old_size) and
		is_equal_approx(main.camera.far, old_far) and main.world._env.fog_enabled == old_fog and
		main.world._env.volumetric_fog_enabled == old_volume,
		"выход возвращает обычную камеру и прежние флаги атмосферы")
	main.camera.global_transform = old_transform
	tool.markers = old_markers
	tool.selected = old_selected


func _check_island_harbor() -> void:
	for beacon in main.beacons:
		var tower: Vector3 = beacon["tower_pos"]
		_check(tower.y > 0.5 and is_equal_approx(tower.y,
			main.coast.ground_height(tower.x, tower.z) + 0.15), "маяк опирается на настоящий рельеф")
	for i in range(24):
		var x := lerpf(-160.0, 88.0, float(i) / 23.0)
		_check(main.coast.water_depth(x, -30.0) > 4.5, "вход в бухту открыт с моря")
	var port := main.harbor
	_check(port != null and main.coast.water_depth(IslandLayout.BERTH.x, IslandLayout.BERTH.y) > 4.5,
		"настоящий причал стоит над глубокой водой")
	_check(port.blocks_hull(Vector2(110, -30), -PI * 0.5) and
		not port.blocks_hull(IslandLayout.BERTH, PI * 0.5), "пирс блокирует корпус, но не место стоянки")
	var saved := main.boat.global_position
	var yaw := main.boat.rotation.y
	main.boat.global_position.x = IslandLayout.BERTH.x - 3.0
	main.boat.global_position.z = IslandLayout.BERTH.y
	main.boat.speed = 2.0
	port.interact()
	_check(not port.moored, "нельзя швартоваться на ходу")
	main.boat.speed = 0.0
	port.interact()
	_check(port.moored and is_equal_approx(main.boat.rotation.y, PI * 0.5),
		"швартовка ставит лодку вдоль причала")
	port.interact()
	_check(not port.moored, "повторное действие отдаёт швартовы")
	main.boat.global_position = saved
	main.boat.rotation.y = yaw
	if main.boat.has_trailer:
		main.boat.set_trailer_enabled(true)
	main.boat._reset_trail(Vector2(saved.x, saved.z))
	main.boat.reset_physics_interpolation()


func _check_shoal_navigation() -> void:
	var marks := main.shoals
	_check(marks != null and marks.positions.size() >= 10 and marks.positions.size() <= ShoalMarkers.MAX_MARKERS,
		"редкие буи по периметру отмели созданы")
	for p in marks.positions:
		_check(absf(main.coast.water_depth(p.x, p.y) - ShoalMarkers.DEPTH) < 0.15,
			"предупреждающий буй стоит на настоящей изобате")
	_check(not IslandLayout.permits_slick(IslandLayout.BERTH) and IslandLayout.permits_slick(IslandLayout.BOAT_START),
		"бухта исключена из размещения пятен, море разрешено")
	for slick in main.slicks:
		_check(IslandLayout.permits_slick(Vector2(slick.position.x, slick.position.z)), "стартовое пятно вне бухты")
	var saved := main.boat.global_position
	var yaw := main.boat.rotation.y
	var speed := main.boat.speed
	var trailer_enabled := main.boat.has_trailer
	main.boat.set_trailer_enabled(false)
	var beacon: Dictionary = main.beacons[0]
	var bp: Vector3 = beacon["buoy_pos"]
	var outward: Vector2 = beacon["outward"]
	main.boat.global_position = bp
	main.boat.rotation.y = atan2(outward.x, outward.y)
	main.boat.speed = 7.0
	marks._check_course()
	_check(marks.warning, "прогноз глубины предупреждает до касания отмели")
	main.boat.global_position = saved
	main.boat.rotation.y = yaw
	main.boat.speed = 0.0
	marks._check_course()
	_check(not marks.warning, "на глубокой воде предупреждение гаснет")
	main.boat.set_trailer_enabled(true)
	main.boat._trailer.global_position = bp - Vector3(outward.x, 0.0, outward.y) * 12.0
	marks._check_course()
	_check(marks.warning, "отмель под прицепом также вызывает предупреждение")
	main.boat.set_trailer_enabled(trailer_enabled)
	main.boat.global_position = saved
	main.boat.rotation.y = yaw
	main.boat.speed = speed
	main.boat._reset_trail(Vector2(saved.x, saved.z))
	main.boat.reset_physics_interpolation()
	marks._check_course()
	# Frame the new station using the ordinary follow-camera geometry, no zoom.
	var camera_transform := main.camera.global_transform
	var focus := Vector3(IslandLayout.BERTH.x, 0.8, IslandLayout.BERTH.y)
	main.camera.global_position = focus + Vector3(21.0, 26.2, 30.0)
	main.camera.look_at(focus, Vector3.UP)
	var screen := main.camera.unproject_position(Vector3(124.0, 4.0, -49.0))
	_check(Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size).has_point(screen),
		"рыбацкая станция в кадре обычной камеры у стоянки")
	main.camera.global_transform = camera_transform


func _check_resource_zones() -> void:
	var pool := main.resource_zones
	_check(pool.zones.size() == 4 and pool.slots.size() == 12, "четыре мировые зоны и фиксированный пул 12 пятен")
	var old_positions: Array[Vector3] = []
	for slot in pool.slots:
		var slick: ResourceSlick = slot["slick"]
		var zone: Dictionary = pool.zones[int(slot["zone"])]
		var center: Vector2 = zone["center"]
		old_positions.append(slick.position)
		_check(slick.zone_managed and Vector2(slick.position.x, slick.position.z).distance_to(center) <= float(zone["radius"]) - 6.0,
			"пятно принадлежит своей постоянной зоне")
		_check(slick.kind == int(zone["kind"]) and IslandLayout.permits_slick(Vector2(slick.position.x, slick.position.z)),
			"региональный пигмент и запрет бухты соблюдены")
	var boat_at := main.boat.global_position
	main.boat.global_position += Vector3(700, 0, 700)
	pool.update(1.0)
	for i in range(pool.slots.size()):
		var slick: ResourceSlick = pool.slots[i]["slick"]
		_check(slick.position == old_positions[i], "лодка не перетягивает пятна за собой")
	main.boat.global_position = boat_at
	main.boat.reset_physics_interpolation()
	var temp := ResourceSlick.new()
	temp.zone_managed = true
	main.add_child(temp)
	temp.setup(main.water, Vector2(-240, -200), 0, 0.1)
	temp.remaining_mass = 0.25
	_check(not temp.can_zone_shuffle() and not temp.renew_in_zone(Vector3(-240, 0, -200)) and temp.remaining_mass == 0.25,
		"четверть пятна не перемещается и не восстанавливается до целого")
	temp.collect()
	temp._process(36.0)
	_check(temp.depleted, "зональное пятно не возрождается само через прежние 35 секунд")
	_check(temp.renew_in_zone(Vector3(-240, 0, -200)) and not temp.depleted and temp.remaining_mass == 1.0,
		"новый запас появляется только из полностью исчерпанного слота")
	temp.queue_free()


func _check_buoy_dynamics() -> void:
	# Real production solver, isolated deep-water fixture; not a replacement
	# for running the scene in Godot and inspecting contacts visually.
	var dynamics := BuoyDynamics.new()
	dynamics.setup(main)
	dynamics._interpolate = false
	var anchor := Vector2(-480.0, -480.0)
	var id := dynamics.register(anchor, 0.75)
	var contact := dynamics.resolve_motion(anchor - Vector2(12.0, 0.0), anchor + Vector2(12.0, 0.0), PI * 0.5, PI * 0.5, 3.7, 1.7, 0.1)
	var resolved: Vector2 = contact["position"]
	var offset: Vector2 = dynamics.floats[id]["offset"]
	var angular: Vector2 = dynamics.floats[id]["angular_velocity"]
	_check(bool(contact["hit"]) and resolved.is_equal_approx(anchor + Vector2(12.0, 0.0)) and is_equal_approx(float(contact["speed_factor"]), 1.0),
		"буй уступает быстрому проходу лодки, не сокращая путь и скорость")
	_check(offset.length() > 0.1 and angular.length() > 0.01,
		"контакт сдвигает буй в сторону и раскачивает его")
	for _tick in range(600):
		dynamics.step(1.0 / 60.0)
	offset = dynamics.floats[id]["offset"]
	_check(offset.length() < 0.01, "после контакта буй возвращается к якорю")
	dynamics.floats[id]["wave_tilt"] = Vector2(0.12, -0.08)
	dynamics.floats[id]["wave_timer"] = 1.0
	for _tick in range(30):
		dynamics.step(1.0 / 60.0)
	_check(not dynamics.render_pose(id).basis.y.is_equal_approx(Vector3.UP),
		"уклон волны наклоняет весь буй, а не только меняет высоту")

	var boat := main.boat
	var saved_pose := boat.global_transform
	var saved_trailer := boat._trailer.global_transform
	var saved_trailer_rotation := boat._trailer_body.rotation
	var trailer_enabled := boat.has_trailer
	var original := main.buoy_dynamics
	main.buoy_dynamics = dynamics
	boat.global_position = Vector3(anchor.x - 15.0, 0.0, anchor.y)
	boat.rotation.y = PI * 0.5
	boat.set_trailer_enabled(true)
	boat._trailer.global_position = Vector3(anchor.x + 10.0, 0.0, anchor.y)
	dynamics.floats[id]["offset"] = Vector2.ZERO
	boat._update_trailer(1.0)
	var trailer_at := Vector2(boat._trailer.global_position.x, boat._trailer.global_position.z)
	_check(trailer_at.x < anchor.x and dynamics.hull_distance(id, trailer_at, boat._trailer.rotation.y, 1.6, 1.5) >= -0.001,
		"плашкоут проходит дальше, оттесняя буй в сторону")
	dynamics.floats[id]["offset"] = Vector2.ZERO
	boat.global_position = Vector3(anchor.x - 14.0, 0.0, anchor.y)
	boat._trailer.global_position = Vector3(anchor.x - 14.0 + BoatVessel.TRAILER_CLEARANCE, 0.0, anchor.y)
	boat._trailer.rotation.y = PI * 0.5
	_check(boat._make_room_for_trailer(Vector3(anchor.x - 8.0, 0.0, anchor.y)),
		"буй не блокирует задний ход и уступает плашкоуту")
	main.buoy_dynamics = original
	boat.global_transform = saved_pose
	boat.set_trailer_enabled(false)
	var marks := main.shoals
	var saved_near: Array[bool] = marks._near.duplicate()
	var saved_colors: Array[Color] = marks._colors.duplicate()
	var marker := marks.positions[0]
	boat.global_position = Vector3(marker.x, 0.0, marker.y + 12.0)
	boat.rotation.y = 0.0
	marks._process(0.3)
	_check(marks._near[0] and marks._colors[0].r > marks._colors[0].g,
		"при приближении лодки предупреждающий буй красный")
	boat.global_position = Vector3(anchor.x, 0.0, anchor.y)
	marks._process(0.3)
	_check(not marks._near[0] and marks._colors[0].g > marks._colors[0].r,
		"вдали от лодки предупреждающий буй зелёный")
	marks._near = saved_near
	marks._colors = saved_colors
	boat.global_transform = saved_pose
	boat.set_trailer_enabled(trailer_enabled)
	boat._trailer.global_transform = saved_trailer
	boat._trailer_body.rotation = saved_trailer_rotation
	boat.reset_physics_interpolation()
	boat._trailer.reset_physics_interpolation()
	marks._check_course()


func _check_photo_mode() -> void:
	var photo := main.photo_mode
	var camera := main.camera
	var pose := camera.global_transform
	var projection := camera.projection
	var near_clip := camera.near
	var far_clip := camera.far
	var attributes := camera.attributes
	photo.set_active(true)
	_check(photo.active and main.inspection_active() and camera.projection == Camera3D.PROJECTION_PERSPECTIVE,
		"фоторежим использует перспективу и отключает управление судном")
	for index in range(BoatPhotoMode.POINTS.size()):
		photo._select_point(index)
		photo.update_camera(0.0)
		var body := main.boat._body.get_global_transform_interpolated()
		var expected: Vector3 = body * BoatPhotoMode.POINTS[index]
		_check(camera.global_position.distance_to(expected) < 0.001,
			"точка фотокамеры следует интерполированному корпусу")
	_check(is_equal_approx(BoatPhotoMode.exposure_gain(400, 4, 1.0 / 60.0, 0), 1.0) and
		is_equal_approx(BoatPhotoMode.exposure_gain(800, 4, 1.0 / 60.0, 0), 2.0),
		"фотоэкспозиция: исходный множитель 1, удвоение ISO даёт ступень")
	photo.set_active(false)
	photo._select_point(0)
	_check(not photo.active and camera.projection == projection and camera.attributes == attributes and
		is_equal_approx(camera.near, near_clip) and is_equal_approx(camera.far, far_clip) and
		camera.global_transform.is_equal_approx(pose), "выход из фоторежима восстанавливает камеру")


func _check_camera_framing() -> void:
	var camera := main.camera
	var saved_pose := camera.global_transform
	var saved_size := camera.size
	var focus := Vector3(114.0, 0.88, -38.0)
	var preferred := Vector3(21.0, 26.2, 30.0)
	camera.size = BoatMain.CAMERA_MAX_SIZE
	camera.global_position = focus + preferred
	camera.look_at(focus, Vector3.UP)
	var landmark := Vector3(124.0, 6.0, -49.0)
	var before := camera.unproject_position(landmark)
	var offset := main.camera_framing.fit_offset(focus, preferred, camera, get_viewport().get_visible_rect().size)
	camera.global_position = focus + offset
	camera.look_at(focus, Vector3.UP)
	var after := camera.unproject_position(landmark)
	var lowest := camera.global_position.y - camera.global_basis.z.y * camera.near - camera.global_basis.y.y * camera.size * 0.5
	_check(lowest >= Coast.SEA_LEVEL + 1.0,
		"при 2,25× нижняя сторона near plane находится над водой")
	_check(before.distance_to(after) < 0.05 and is_equal_approx(camera.size, 72.0),
		"безопасное отступление камеры сохраняет кадр и охват 2,25×")
	camera.size = saved_size
	camera.global_transform = saved_pose


func _check_reef_signals() -> void:
	if main.reefs.is_empty():
		_check(false, "рифовые вехи созданы")
		return
	var reef: Dictionary = main.reefs[0]
	var at: Vector2 = reef["pos"]
	var lens: StandardMaterial3D = reef["signal_material"]
	var glare: ShaderMaterial = reef["signal_glare"]
	var boat := main.boat
	var pose := boat.global_transform
	var trailer_pose := boat._trailer.global_transform
	var had_trailer := boat.has_trailer
	var saved_night := main.night01
	var saved_time := main._beacon_anim_time
	boat.set_trailer_enabled(false)
	boat.global_position = Vector3(at.x + 15.0, 0.0, at.y)
	main._beacon_anim_time = 0.08 - float(reef["signal_phase"])
	main.night01 = 0.0
	main._update_reef_signals()
	_check(is_zero_approx(lens.emission_energy_multiplier) and is_zero_approx(float(glare.get_shader_parameter("flash_strength"))),
		"рифовая сигнализация не светится днём даже рядом с лодкой")
	main.night01 = 0.88
	main._update_reef_signals()
	_check(lens.emission_energy_multiplier > 5.0 and float(glare.get_shader_parameter("flash_strength")) > 0.9,
		"ночью близкий риф даёт яркий синхронный проблеск и ореол")
	boat.global_position = Vector3(at.x + 100.0, 0.0, at.y)
	main._update_reef_signals()
	_check(lens.emission_energy_multiplier < 0.1 and is_zero_approx(float(glare.get_shader_parameter("flash_strength"))),
		"ночью дальние рифы не мигают всем периметром")
	boat.set_trailer_enabled(true)
	boat._trailer.global_position = Vector3(at.x + 15.0, 0.0, at.y)
	main._update_reef_signals()
	_check(lens.emission_energy_multiplier > 5.0, "сигнал рифа также реагирует на плашкоут")
	boat.global_transform = pose
	boat.set_trailer_enabled(had_trailer)
	boat._trailer.global_transform = trailer_pose
	boat.reset_physics_interpolation()
	boat._trailer.reset_physics_interpolation()
	main.night01 = saved_night
	main._beacon_anim_time = saved_time
	main._update_reef_signals()


func _check_raid() -> void:
	# Native integration regression, exercised only by JOURNEY_BOAT_SMOKE=1.
	var run := main.raid
	var saved_hp := main.boat.hull_hp
	var saved_speed := main.boat.speed
	var saved_debug := main.debug_panel_visible
	var saved_raw := main.raw.duplicate()
	var saved_refined := main.refined.duplicate()
	var saved_sonar := main.sonar_timer
	var saved_overdrive := main.overdrive_timer
	_check(run != null and run.state == RaidRun.State.IDLE, "рейд выключен при обычном запуске")
	_check(is_equal_approx(RaidRun.segment_distance(Vector2(5, 3), Vector2.ZERO, Vector2(10, 0)), 3.0),
		"аналитическая геометрия боевых капсул")
	run.start()
	_check(run.state == RaidRun.State.RUNNING and is_equal_approx(main.boat.hull_hp, 100.0),
		"рейд запускается на глубокой воде с отдельной прочностью")
	main.boat.speed = 3.0
	run.toggle_pause()
	var at := main.boat.global_transform
	var elapsed := run.elapsed
	main.boat._physics_process(0.5)
	run._physics_process(0.5)
	_check(main.boat.global_transform.is_equal_approx(at) and is_equal_approx(run.elapsed, elapsed)
		and main.gameplay_paused(), "пауза замораживает движение судна и боевые часы")
	run.toggle_pause()
	run.xp = run.xp_needed
	run._offer_upgrade()
	_check(run.choices.size() == 3 and run.choices[0] != run.choices[1]
		and run.choices[1] != run.choices[2] and run.choices[0] != run.choices[2],
		"три различных предложения улучшения")
	run.choices = [0, 1, 2]
	run.choose(1)
	_check(run.state == RaidRun.State.RUNNING and run.level == 2 and run.xp == 0
		and is_equal_approx(run.reload_scale, 0.88), "карточка применяет эффект и списывает опыт")
	_check_raid_mobility()
	_check_raid_fx()
	_check_raid_waves()
	_check_raid_stern()
	# Real manager grid and projectile path, not a Python port of the hit algorithm.
	var target := run.boat_at() + run.forward() * 10.0
	run.enemies.append({"at": target, "previous": target, "hp": 10.0,
		"max_hp": 10.0, "radius": 1.1, "kind": 0, "flash": 0.0, "born": 0.0,
		"timer": 2.0, "charge": 0.0, "aim": Vector2.ZERO})
	run._rebuild_grid()
	run._add_shot(run.boat_at(), run.forward() * 38.0, 22.0, false)
	run._move_shots(0.5)
	_check(float(run.enemies[0]["hp"]) < 0.0 and run.shots.is_empty(),
		"быстрый снаряд попадает между концами шага и расходуется один раз")
	run._physics_process(0.001)
	_check(run.kills == 1 and run.xp == 0 and run.salvage.remaining() == 2,
		"боевой цикл создаёт трофей на месте гибели, но не выдаёт опыт дистанционно")
	run.enemies.clear()
	run.grid.clear()
	_check_raid_salvage()
	run._hurt_timer = 0.0
	run._hurt(200.0)
	run._physics_process(0.01)
	_check(run.state == RaidRun.State.LOST and is_zero_approx(main.boat.hull_hp),
		"боевой урон достигает нуля и завершает рейд")
	run.leave()
	_check(run.state == RaidRun.State.IDLE and run.enemies.is_empty() and run.shots.is_empty()
		and is_equal_approx(main.boat.hull_hp, saved_hp) and main.debug_panel_visible == saved_debug
		and is_equal_approx(main.boat.raid_speed_factor(), 1.0) and is_equal_approx(main.boat.raid_turn_factor(), 1.0),
		"выход очищает бой и возвращает дорейдовую прочность и интерфейс")
	_check(main.raw == saved_raw and main.refined == saved_refined,
		"карточки и боевой импульс не расходуют экспедиционные пигменты")
	main.boat.speed = saved_speed
	main.sonar_timer = saved_sonar
	main.overdrive_timer = saved_overdrive


func _check_raid_salvage() -> void:
	var run := main.raid
	var loot := run.salvage
	loot.reset()
	var xp_before := run.xp
	loot.drop(run.boat_at() + run.forward() * 25.0, 4)
	_check(run.xp == xp_before and loot.remaining() == 4,
		"уничтожение оставляет опыт в мире, без дистанционного начисления")
	run.toggle_pause()
	var loot_at: Vector2 = loot.drops[0]["at"]
	run._physics_process(0.5)
	_check(loot.drops[0]["at"] == loot_at and loot.collected == 0,
		"боевой опыт не двигается и не собирается на паузе")
	run.toggle_pause()
	loot.drop(run.boat_at(), 2)
	run._physics_process(0.02)
	_check(run.xp == xp_before + 2 and loot.collected == 2 and loot.remaining() == 4,
		"корпус собирает только ближайший опыт через боевой тик")
	var had_trailer := main.boat.has_trailer
	var trailer_pose := main.boat._trailer.global_transform
	main.boat.set_trailer_enabled(true)
	main.boat._trailer.global_position = main.boat.global_position + Vector3(0, 0, 50)
	loot.drop(Vector2(main.boat._trailer.global_position.x, main.boat._trailer.global_position.z), 3)
	_check(loot.step(0.0) == 3 and loot.collected == 5,
		"плашкоут подбирает боевые трофеи своим корпусом")
	main.boat.set_trailer_enabled(had_trailer)
	main.boat._trailer.global_transform = trailer_pose
	main.boat._trailer.reset_physics_interpolation()
	loot.reset()
	for index in range(RaidSalvage.CAPACITY + 20):
		loot.drop(Vector2(float(index) * 3.0, 0), 2)
	_check(loot.drops.size() == RaidSalvage.CAPACITY
		and loot.remaining() == (RaidSalvage.CAPACITY + 20) * 2,
		"лимит трофеев объединяет остаток без потери массы опыта")
	loot.reset()


func _check_raid_mobility() -> void:
	var run := main.raid
	var old_level := run.level
	var old_xp := run.xp
	var old_needed := run.xp_needed
	var baseline_speed := main.boat.effective_max_speed()
	var baseline_turn := main.boat.steering_yaw_delta(1.0, 5.0, 0.1)
	run.xp = run.xp_needed
	run.choices = [6, 7, 0]
	run.state = RaidRun.State.CHOOSING
	run.choose(0)
	_check(is_equal_approx(main.boat.effective_max_speed(), baseline_speed * 1.12),
		"карточка двигателя реально повышает максимальный ход")
	run.xp = run.xp_needed
	run.choices = [6, 7, 0]
	run.state = RaidRun.State.CHOOSING
	run.choose(1)
	_check(is_equal_approx(main.boat.steering_yaw_delta(1.0, 5.0, 0.1), baseline_turn * 1.15)
		and is_zero_approx(main.boat.steering_yaw_delta(1.0, 0.0, 0.1))
		and main.boat.steering_yaw_delta(1.0, -5.0, 0.1) > 0.0,
		"карточка руля ускоряет поворот, сохраняя нулевой ход и инверсию заднего хода")
	run.speed_rank = RaidRun.MOBILITY_MAX_RANK
	run.turn_rank = RaidRun.MOBILITY_MAX_RANK
	run._offer_upgrade()
	_check(not run.choices.has(6) and not run.choices.has(7),
		"максимальные двигатель и руль исключены из предложений")
	run.speed_rank = 0
	run.turn_rank = 0
	run.level = old_level
	run.xp = old_xp
	run.xp_needed = old_needed
	run.choices.clear()
	run.state = RaidRun.State.RUNNING
	run.hud.refresh()


func _check_raid_fx() -> void:
	var run := main.raid
	var fx := run.weapon_fx
	var previous_setting := run.effects_enabled
	run.effects_enabled = true
	fx.emit(0, run.forward())
	fx.render()
	_check(fx._batch.instance_count == 6 and fx._batch.visible_instance_count == 6,
		"дульная вспышка использует фиксированные шесть side/face-квадов")
	var remaining := fx._remaining[0]
	run.toggle_pause()
	run._physics_process(0.5)
	_check(is_equal_approx(fx._remaining[0], remaining), "дульная вспышка заморожена с боевым временем")
	run.toggle_pause()
	fx.step(RaidWeaponFx.LIFE + 0.01)
	fx.render()
	_check(fx._batch.visible_instance_count == 0, "истёкшая вспышка не рисуется")
	run.effects_enabled = false
	fx.emit(1, run.forward())
	fx.render()
	_check(fx._batch.visible_instance_count == 0 and is_zero_approx(fx._remaining[1]),
		"отключение эффектов выключает дульные вспышки")
	run.hud._bar_index = 0
	run.hud._bar(Rect2(0, 0, 100, 8), -2.0, Color.WHITE)
	run.hud._bar(Rect2(0, 10, 100, 8), 2.0, Color.WHITE)
	var empty_material := run.hud._bars[0].material as ShaderMaterial
	var full_material := run.hud._bars[1].material as ShaderMaterial
	_check(run.hud._bars.size() == 3
		and is_zero_approx(float(empty_material.get_shader_parameter("progress")))
		and is_equal_approx(float(full_material.get_shader_parameter("progress")), 1.0),
		"полосы ограничивают прогресс нулём и единицей")
	run.effects_enabled = previous_setting
	fx.reset()
	run.hud.refresh()


func _check_raid_waves() -> void:
	_check(RaidWaves.phase(59.9) == 0 and RaidWaves.phase(60.0) == 1
		and RaidWaves.phase(180.0) == 3 and RaidWaves.phase(240.0) == 5,
		"границы фаз волн определяются боевыми часами")
	_check(not RaidWaves.respite(224.9) and RaidWaves.respite(225.0)
		and RaidWaves.respite(239.9) and not RaidWaves.respite(240.0),
		"15 секунд передышки перед боссом без обычного спавна")
	var caps_ok := true
	for seconds in [0.0, 35.0, 60.0, 120.0, 180.0, 240.0]:
		for roll_index in range(100):
			if RaidWaves.choose_kind(seconds, RaidWaves.ranged_cap(seconds), float(roll_index) / 100.0) == 2:
				caps_ok = false
	_check(caps_ok, "достигнутый лимит стрелков запрещает появление следующего")


func _check_raid_stern() -> void:
	var run := main.raid
	var ordnance := run.stern_charges
	var old_level := run.level
	var old_xp := run.xp
	var old_needed := run.xp_needed
	run.xp = run.xp_needed
	run.choices = [8, 0, 1]
	run.state = RaidRun.State.CHOOSING
	run.choose(0)
	_check(run.stern_rank == 1, "карточка устанавливает кормовой модуль")
	ordnance.step(0.01)
	_check(ordnance.charges.size() == 1 and not ordnance._try_drop(),
		"кормовой заряд сброшен в воду, стационарная куча не создаётся")
	if not ordnance.charges.is_empty():
		var charge: Dictionary = ordnance.charges[0]
		var at: Vector2 = charge["at"]
		run.enemies.append({"at": at + Vector2(1, 0), "hp": 200.0, "radius": 1.1, "flash": 0.0})
		run._rebuild_grid()
		ordnance.step(0.1)
		_check(is_equal_approx(float(run.enemies[0]["hp"]), 200.0), "заряд не срабатывает до взведения")
		ordnance.step(RaidSternCharges.ARM_TIME)
		_check(is_equal_approx(float(run.enemies[0]["hp"]), 158.0), "взведённый заряд наносит площадной урон")
		ordnance._detonate(charge)
		_check(is_equal_approx(float(run.enemies[0]["hp"]), 158.0), "один заряд не наносит повторный урон")
		run.toggle_pause()
		var age: float = charge["blast"]
		run._physics_process(0.5)
		_check(is_equal_approx(float(charge["blast"]), age), "пауза замораживает кормовые заряды")
		run.toggle_pause()
		ordnance.step(RaidSternCharges.BLAST_TIME + 0.01)
		_check(ordnance.charges.is_empty(), "взорванный заряд освобождает ограниченный пул")
	var had_trailer := main.boat.has_trailer
	var trailer_pose := main.boat._trailer.global_transform
	main.boat.set_trailer_enabled(true)
	var trailer := main.boat._trailer
	var center := Vector2(trailer.global_position.x, trailer.global_position.z)
	var backwards := Vector2(sin(trailer.global_rotation.y), cos(trailer.global_rotation.y))
	_check(is_equal_approx((ordnance.drop_point() - center).dot(backwards), 4.5),
		"с плашкоутом заряд сбрасывается за кормой плашкоута")
	main.boat.set_trailer_enabled(had_trailer)
	main.boat._trailer.global_transform = trailer_pose
	main.boat._trailer.reset_physics_interpolation()
	run.stern_rank = 0
	run.level = old_level
	run.xp = old_xp
	run.xp_needed = old_needed
	run.enemies.clear()
	run.grid.clear()
	ordnance.reset()
	run.hud.refresh()
