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
		_check(main.world._sun.light_energy < 0.001 and
			float(main.water.material().get_shader_parameter("sun_path_amount")) < 0.001 and
			main.world._env.volumetric_fog_density > 0.014,
			"ночью нет лунной дорожки и направленной луны, но есть плотный туман")
		print("[BOAT SMOKE] итог: %s" % ("ВСЁ ПРОШЛО" if failures == 0 else "%d ОШИБОК" % failures))
		get_tree().quit(0 if failures == 0 else 1)


func _check(ok: bool, description: String) -> void:
	if ok:
		print("[BOAT SMOKE] PASS ", description)
	else:
		failures += 1
		push_error("[BOAT SMOKE] FAIL " + description)
