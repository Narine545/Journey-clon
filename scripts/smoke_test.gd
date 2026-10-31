class_name SmokeTest
extends Node
## Проверка окружения и границ площадки; визуальную часть проверяет Vulkan.
var main: MainScene


func setup(main_ref: MainScene) -> void:
	main = main_ref
	_run.call_deferred()


func _run() -> void:
	await get_tree().physics_frame
	var failures: Array[String] = []
	# По умолчанию — редкий режим без обязательных объектов и F4.
	_check(not main.ambient_spawner.preview_robots and main.ambient_spawner.get_child_count() == 0, "тихий режим запускается без гарантированных роботов", failures)
	var reset_key := InputEventKey.new()
	reset_key.physical_keycode = KEY_F4
	reset_key.pressed = true
	main.ambient_spawner._unhandled_input(reset_key)
	_check(main.ambient_spawner.get_child_count() == 0, "F4 не создаёт роботов в тихом режиме", failures)
	# Отдельно включаем опциональную демонстрацию и проверяем её в CI;
	# после проверки возвращаем исходную настройку и пустую сцену.
	ProjectSettings.set_setting("journey/m4/robot_preview", true)
	var preview_spawner := AmbientSpawner.new()
	main.add_child(preview_spawner)
	preview_spawner.setup(main)
	_check(preview_spawner.preview_robots and preview_spawner.get_child_count() == 3, "три робота в режиме демонстрации", failures)
	var demo_kinds: Array[int] = []
	for child in preview_spawner.get_children():
		var demo_robot := child as AmbientRobot
		if demo_robot == null:
			continue
		demo_kinds.append(demo_robot.kind)
		var demo_center := demo_robot.global_position + Vector3.UP * demo_robot.body_size.y * 0.5
		_check(main.cam_rig.cam.is_position_in_frustum(demo_center), "демонстрационный робот %d в начальном кадре" % demo_robot.kind, failures)
		_check(Ballistics.terrain_hit(main.coast, main.cam_rig.cam.global_position, demo_center, 4.0).is_empty(), "демонстрационный робот %d не скрыт рельефом" % demo_robot.kind, failures)
	_check(demo_kinds.has(0) and demo_kinds.has(1) and demo_kinds.has(2), "все три типа представлены", failures)
	preview_spawner._unhandled_input(reset_key)
	await get_tree().process_frame
	_check(preview_spawner.get_child_count() == 3, "F4 восстанавливает демо", failures)
	preview_spawner.free()
	ProjectSettings.set_setting("journey/m4/robot_preview", false)
	_check(main.coast.mesh != null, "сетка рельефа", failures)
	_check(Coast.WORLD_SIZE >= 2500.0, "ширина пустоши не менее 2,5 км", failures)
	var outer := main.coast.get_node_or_null("OuterDunes") as MeshInstance3D
	_check(outer != null and outer.mesh != null, "внешний пояс рельефа", failures)
	for side in range(4):
		var sign_value := 1.0 if side % 2 == 0 else -1.0
		var x := Coast.CENTER.x + (sign_value * Coast.SIZE * 0.5 if side < 2 else 0.0)
		var z := Coast.CENTER.y + (sign_value * Coast.SIZE * 0.5 if side >= 2 else 0.0)
		var direction := Vector2(sign_value, 0.0) if side < 2 else Vector2(0.0, sign_value)
		var edge := main.coast.height_at(x, z)
		var outside := main.coast.ground_height(x + direction.x * 0.01, z + direction.y * 0.01)
		_check(absf(edge - outside) < 0.1, "непрерывный шов рельефа %d" % side, failures)
	_check(main.landmarks.detailed.size() == 3 and main.landmarks.simplified.size() == 3, "три ориентира и LOD", failures)
	var test_rotation := Vector3(0.1, 0.2, 0.3)
	var part := main.landmarks._part(Vector3.ZERO, Vector3.ONE, test_rotation)
	_check(part["rotation"] == test_rotation, "поворот детали ориентира", failures)
	for i in range(main.landmarks.detailed.size()):
		var high := main.landmarks.detailed[i]
		var low := main.landmarks.simplified[i]
		_check(is_equal_approx(high.visibility_range_end, low.visibility_range_begin) and high.custom_aabb == low.custom_aabb, "совпадающий порог и AABB LOD %d" % i, failures)
		_check(high.mesh.surface_get_array_len(0) > low.mesh.surface_get_array_len(0), "упрощение геометрии %d" % i, failures)
	_check(main.world._env.fog_height_density > 0.0 and main.world._env.fog_aerial_perspective > 0.0,
			"высотная дымка и воздушная перспектива", failures)
	var target_low := main.target.get_node_or_null("DistantSilhouette") as MeshInstance3D
	_check(target_low != null and target_low.visibility_range_begin > 0.0, "дальний LOD мишени", failures)
	_check(main.sand.get_texture() != null, "поле физического песка", failures)
	_check(main.world != null and main.cam_rig.cam.current, "мир и активная камера", failures)
	_check(not main.performance_overlay.visible, "FPS по умолчанию скрыт", failures)
	var f3 := InputEventKey.new()
	f3.physical_keycode = KEY_F3
	f3.pressed = true
	main.performance_overlay._unhandled_input(f3)
	_check(main.performance_overlay.visible, "F3 показывает FPS", failures)
	main.performance_overlay._unhandled_input(f3)
	_check(not main.performance_overlay.visible, "F3 скрывает FPS", failures)
	_check(main.audio._step_streams.size() == 6, "синтез шагов", failures)
	_check(main.audio._wind.stream != null and main.audio._wind.playing, "петля ветра", failures)
	_check(main.tower.scene_file_path == "res://scenes/Tower.tscn", "отдельная сцена башни", failures)
	_check(main.tower.model != null and main.tower.animation != null and not main.tower.cage_track.is_empty() and not main.tower.door_track.is_empty(), "модель пользователя и дорожки лифта/дверцы", failures)
	_check(main.tower.model.scene_file_path == "res://assets/tower/tower_delivery.glb", "используется исправленный GLB", failures)
	# Исправленный экспорт содержит отражённые модификаторами детали, а не
	# одиночные исходные кубы старого экспорта (по 36 индексов каждый).
	for part_pattern in ["*LiftFloorPanel*001*", "*LiftFloorPanel*002*", "*LiftFloorPanel*003*", "*LiftFloorPanel*004*", "*LiftCrossbar*54*Z2*001*", "*LiftCrossbar*54*Z2*002*", "*LiftCrossbar*54*Z2*003*", "*LiftCrossbar*54*Z2*005*", "*LiftCrossbar*54*Z2*006*"]:
		var mesh_piece := main.tower.model.find_child(part_pattern, true, false) as MeshInstance3D
		_check(mesh_piece != null and mesh_piece.mesh != null and mesh_piece.mesh.get_faces().size() >= 72, "геометрия с модификаторами %s" % part_pattern, failures)
	_check(main.player.get_parent() == main.tower, "игрок на башне", failures)
	_check(absf(main.player.position.y - ObservationTower.DECK_HEIGHT) < 0.05, "высота площадки", failures)
	_check(main.target.global_position.y < main.player.global_position.y - 20.0, "мишень внизу", failures)
	var aim := (main.target.global_position + Vector3(0, TargetDummy.CENTER_HEIGHT, 0) - main.cam_rig.cam.global_position).normalized()
	_check((-main.cam_rig.cam.global_basis.z).dot(aim) > 0.999, "мишень в начальном направлении взгляда", failures)
	var eye := main.cam_rig.cam.global_position
	var target_center: Vector3 = main.target.global_position + Vector3.UP * TargetDummy.CENTER_HEIGHT
	# Дальний ориентир должен действительно выступать над дюнами, а не быть
	# просто расположен в направлении камеры за непрозрачным рельефом.
	for landmark in ["BuriedShip", "RadioMast", "BrokenRib"]:
		var anchor := main.landmarks.get_node(landmark) as Node3D
		var high_point := anchor.global_position + Vector3.UP * 150.0
		var clearance := INF
		for sample in range(1, 30):
			var test_point := eye.lerp(high_point, float(sample) / 30.0)
			clearance = minf(clearance, test_point.y - main.coast.ground_height(test_point.x, test_point.z))
		_check(clearance > 0.0, "ориентир %s над дюнами (%.1f м)" % [landmark, clearance], failures)
	var terrain_clear := true
	for i in range(1, 20):
		var point := eye.lerp(target_center, float(i) / 20.0)
		if point.y <= main.coast.ground_height(point.x, point.z):
			terrain_clear = false
	_check(terrain_clear, "рельеф не закрывает мишень", failures)
	# После подъёма камеры луч к ближней мишени проходит над верхним поручнем.
	var rail_t: float = (main.tower.global_position.x + 5.95 - eye.x) / (target_center.x - eye.x)
	var rail_height: float = eye.lerp(target_center, rail_t).y - main.tower.global_position.y - ObservationTower.DECK_HEIGHT
	_check(rail_height > 1.34, "ближняя мишень видна над поручнем (%.2f м)" % rail_height, failures)
	var start_yaw: float = main.cam_rig.yaw
	main.cam_rig.apply_mouse_motion(Vector2(50, 0))
	_check(not is_equal_approx(main.cam_rig.yaw, start_yaw), "поворот мышью", failures)
	_check(InputMap.has_action("jump") and main.player is CharacterBody3D, "прыжок доступен на физическом FPS-контроллере", failures)
	# Окно песка по-прежнему работает, несмотря на то что ходим по настилу.
	var sand_pos := Vector2(main.player.global_position.x, main.player.global_position.z)
	main.sand.stamp_foot(sand_pos, Vector2.RIGHT, 0.5, 0.3, 0.1, 0.02)
	_check(main.sand.disp_at(sand_pos.x, sand_pos.y) < -0.001, "песок реагирует на отпечаток", failures)
	main.set_time(1.0)
	_check(is_equal_approx(main.game.night01, 1.0), "смена времени", failures)
	main.set_time(0.0)

	# Проверяем настоящий путь ввода, а не только формулу ограничения.
	main.player.position = Vector3(0, ObservationTower.DECK_HEIGHT, 0)
	main.cam_rig.set_view(0.0, 0.0)
	Input.action_press("move_forward")
	for i in range(8):
		await get_tree().physics_frame
	Input.action_release("move_forward")
	_check(main.player.position.z > 0.1, "W перемещает вперёд по площадке", failures)
	var before_side := main.player.position
	Input.action_press("move_right")
	for i in range(8):
		await get_tree().physics_frame
	Input.action_release("move_right")
	_check(main.player.position.x < before_side.x - 0.1, "D перемещает вправо относительно камеры", failures)
	var before_back := main.player.position
	Input.action_press("move_back")
	for i in range(8):
		await get_tree().physics_frame
	Input.action_release("move_back")
	_check(main.player.position.z < before_back.z - 0.1, "S перемещает назад", failures)
	var before_left := main.player.position
	Input.action_press("move_left")
	for i in range(8):
		await get_tree().physics_frame
	Input.action_release("move_left")
	_check(main.player.position.x > before_left.x + 0.1, "A перемещает влево", failures)
	# После остановки инерция и качание затухают.
	main.player.velocity = Vector3.ZERO
	main.player._physics_process(1.0)
	main.cam_rig.refresh_pose()
	_check(main.cam_rig.cam.global_position.is_equal_approx(main.player.global_position + Vector3.UP * CameraRig.EYE),
			"камера следует за игроком", failures)

	# Ускорение, бег и два направления наклона используют реальные InputMap actions.
	main.player.position = Vector3(0, ObservationTower.DECK_HEIGHT, 0)
	main.player.velocity = Vector3.ZERO
	Input.action_press("move_forward")
	main.player._physics_process(0.4)
	var walk_distance := Vector2(main.player.position.x, main.player.position.z).length()
	main.player.position = Vector3(0, ObservationTower.DECK_HEIGHT, 0)
	main.player.velocity = Vector3.ZERO
	Input.action_press("sprint")
	main.player._physics_process(0.4)
	var sprint_distance := Vector2(main.player.position.x, main.player.position.z).length()
	_check(main.player.sprinting and sprint_distance > walk_distance * 1.5, "Shift ускоряет бег на площадке", failures)
	Input.action_release("sprint")
	Input.action_release("move_forward")
	main.player.velocity = Vector3.ZERO
	Input.action_press("lean_left")
	main.player._physics_process(0.2)
	_check(main.cam_rig.lean < -0.9, "Q наклоняет влево", failures)
	Input.action_release("lean_left")
	Input.action_press("lean_right")
	main.player._physics_process(0.2)
	_check(main.cam_rig.lean > 0.9, "C наклоняет вправо", failures)
	Input.action_release("lean_right")
	main.player._physics_process(1.0)
	main.cam_rig.refresh_pose()
	_check(absf(main.cam_rig.lean) < 0.01 and absf(main.cam_rig.bob) < 0.001, "наклон и покачивание затухают при остановке", failures)
	# Прыжок, посадка и физические границы — реальными физическими кадрами.
	main.player.position = Vector3(0, ObservationTower.DECK_HEIGHT + 0.05, 0)
	main.player.velocity = Vector3.ZERO
	for frame in range(12):
		await get_tree().physics_frame
	_check(main.player.is_on_floor(), "капсула стоит на физическом настиле", failures)
	Input.action_press("jump")
	var jump_peak := main.player.position.y
	for frame in range(20):
		await get_tree().physics_frame
		jump_peak = maxf(jump_peak, main.player.position.y)
	Input.action_release("jump")
	_check(jump_peak > ObservationTower.DECK_HEIGHT + 0.5 and not main.player.is_on_floor(), "пробел запускает прыжок", failures)
	for frame in range(70):
		await get_tree().physics_frame
	_check(main.player.is_on_floor() and absf(main.player.position.y - ObservationTower.DECK_HEIGHT) < 0.06, "после прыжка игрок приземляется на настил", failures)
	main.cam_rig.set_view(0.0, 0.0)
	for boundary in [
		{"start": Vector3(4.9, ObservationTower.DECK_HEIGHT, 0), "action": "move_left"},
		{"start": Vector3(-4.9, ObservationTower.DECK_HEIGHT, 0), "action": "move_right"},
		{"start": Vector3(0, ObservationTower.DECK_HEIGHT, 4.9), "action": "move_forward"},
		{"start": Vector3(0, ObservationTower.DECK_HEIGHT, -4.9), "action": "move_back"},
	]:
		main.player.position = boundary["start"]
		main.player.velocity = Vector3.ZERO
		Input.action_press(boundary["action"])
		for frame in range(35):
			await get_tree().physics_frame
		Input.action_release(boundary["action"])
		var player_at_wall := main.player.position
		_check(absf(player_at_wall.x) <= ObservationTower.WALK_LIMIT + 0.06 and absf(player_at_wall.z) <= ObservationTower.WALK_LIMIT + 0.06, "капсула не проходит границу %s" % boundary["action"], failures)
	main.player.position = Vector3(5.15, ObservationTower.DECK_HEIGHT, 0)
	main.player.velocity = Vector3.ZERO
	for frame in range(5):
		await get_tree().physics_frame
	Input.action_press("move_left")
	Input.action_press("jump")
	var edge_min_y := main.player.position.y
	for frame in range(90):
		await get_tree().physics_frame
		edge_min_y = minf(edge_min_y, main.player.position.y)
	Input.action_release("jump")
	Input.action_release("move_left")
	_check(main.player.position.x <= ObservationTower.WALK_LIMIT + 0.06 and edge_min_y >= ObservationTower.DECK_HEIGHT - 0.06, "прыжком нельзя пройти временную границу до механики спуска", failures)
	# Радиостойка — отдельная физическая преграда, а не проходящая сквозь игрока декорация.
	main.player.position = Vector3(-3.2, ObservationTower.DECK_HEIGHT, -3.9)
	main.player.velocity = Vector3.ZERO
	Input.action_press("move_right")
	for frame in range(55):
		await get_tree().physics_frame
	Input.action_release("move_right")
	_check(main.player.position.x > -3.94 and main.radio_tuner.nearby(), "радиостойка останавливает капсулу, но остаётся доступной", failures)
	# Проверяем все углы ограничивающих коробок модели у сторон и в углах
	# площадки, при горизонтальном и крутом взгляде вверх/вниз.
	main.rifle.aim_requested = false
	main.rifle.scope_amount = 0.0
	main.rifle._recoil = 0.0
	var limit := ObservationTower.WALK_LIMIT
	var poses := [Vector2(limit, 0), Vector2(-limit, 0), Vector2(0, limit), Vector2(0, -limit), Vector2(limit, limit), Vector2(-limit, -limit)]
	var model_clear := true
	for deck_pos in poses:
		main.player.position = Vector3(deck_pos.x, ObservationTower.DECK_HEIGHT, deck_pos.y)
		for direction_index in range(8):
			for view_pitch in [-1.3, -0.6, 0.0, 0.6, 1.3]:
				main.cam_rig.set_view(float(direction_index) * PI / 4.0, view_pitch)
				main.rifle._physics_process(0.0)
				if not _model_within_rails():
					model_clear = false
	_check(model_clear, "винтовка остаётся внутри перил при разных положениях и углах", failures)
	# Равномерное масштабирование вместе со смещением сохраняет проекцию.
	main.player.position = Vector3(0, ObservationTower.DECK_HEIGHT, 0)
	main.cam_rig.set_view(PI * 0.5, -0.3)
	main.rifle._physics_process(0.0)
	var barrel := main.rifle._view_model.get_node("Barrel") as MeshInstance3D
	var center_projection := main.cam_rig.cam.unproject_position(barrel.global_position)
	main.player.position.x = limit
	main.cam_rig.refresh_pose()
	main.rifle._physics_process(0.0)
	var edge_projection := main.cam_rig.cam.unproject_position(barrel.global_position)
	_check(center_projection.distance_to(edge_projection) < 1.0, "положение винтовки на экране сохраняется у перил", failures)
	# M3: реальный снаряд летит к дальней мишени, а не попадает в кадр выстрела.
	_check(main.rifle.scene_file_path == "res://scenes/Rifle.tscn", "отдельная сцена винтовки", failures)
	_check(main.rifle.get_parent() == main.cam_rig.cam, "винтовка прикреплена к камере", failures)
	_check(main.long_target.global_position.distance_to(main.player.global_position) > 500.0, "дальняя мишень за 500 м", failures)
	var initial_fov := main.cam_rig.cam.fov
	main.rifle.aim_requested = true
	for i in range(60):
		await get_tree().physics_frame
	_check(main.cam_rig.cam.fov < initial_fov - 25.0 and main.rifle.scope_amount > 0.8, "плавное увеличение прицела", failures)
	main.rifle.aim_requested = false
	for i in range(60):
		await get_tree().physics_frame
	_check(main.cam_rig.cam.fov > 65.0, "возврат из прицела", failures)
	var accel := Ballistics.acceleration(main.game, 0.0, 0.0)
	_check(accel.y < -9.0 and Vector2(accel.x, accel.z).length() > 0.1, "гравитация и ветер влияют на снаряд", failures)
	var ground_x := main.tower.global_position.x + 35.0
	var ground_z := main.tower.global_position.z
	var ground_height := main.coast.ground_height(ground_x, ground_z)
	var ground_test := Ballistics.terrain_hit(main.coast, Vector3(ground_x, ground_height + 10.0, ground_z), Vector3(ground_x, ground_height - 5.0, ground_z))
	_check(not ground_test.is_empty(), "снаряд сталкивается с рельефом", failures)
	main.player.position = Vector3(-4.7, ObservationTower.DECK_HEIGHT, -1.4)
	main.cam_rig.aim_offset = Vector2.ZERO
	main.cam_rig.set_view(-PI * 0.5, 0.0)
	await get_tree().physics_frame
	var firing_origin := main.player.global_position + Vector3.UP * CameraRig.EYE
	var far_center := main.long_target.global_position + Vector3.UP * TargetDummy.CENTER_HEIGHT
	var min_clearance := INF
	for i in range(1, 50):
		var point := firing_origin.lerp(far_center, float(i) / 50.0)
		min_clearance = minf(min_clearance, point.y - main.coast.ground_height(point.x, point.z))
	_check(min_clearance > 0.0, "дальняя мишень не закрыта рельефом (%.1f м)" % min_clearance, failures)
	var range_to_far := firing_origin.distance_to(far_center)
	var flight_time := range_to_far / SniperRifle.MUZZLE_SPEED
	# Приближённое упреждение по баллистической формуле s = a*t²/2;
	# интегратор и порывы не обязаны совпадать с оценкой идеально.
	var correction := -Ballistics.acceleration(main.game, 0.0, 0.0) * (0.5 * flight_time * flight_time)
	var shot_direction := (far_center + correction - firing_origin).normalized()
	main.cam_rig.set_view(atan2(shot_direction.x, shot_direction.z), asin(shot_direction.y))
	var observed_impacts: Array[TargetDummy] = []
	main.rifle.impact_confirmed.connect(func(hit_target: TargetDummy) -> void: observed_impacts.append(hit_target))
	var score_before := Economy.points
	main.rifle.on_projectile_hit(main.long_target, firing_origin + main.cam_rig.cam.global_basis.z * 10.0)
	_check(Economy.points == score_before, "попадание вне кадра не начисляет очки", failures)
	var ammo_before := main.rifle.ammo
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var capture_click := InputEventMouseButton.new()
	capture_click.button_index = MOUSE_BUTTON_LEFT
	capture_click.pressed = true
	main.rifle._input(capture_click)
	_check(main.rifle.ammo == ammo_before, "клик захвата курсора не стреляет", failures)
	_check(main.rifle.fire(), "выстрел разрешён", failures)
	_check(not main.rifle.fire() and main.rifle.ammo == ammo_before - 1, "затвор блокирует повторный выстрел", failures)
	_check(Economy.points == score_before and main.get_node_or_null("Projectile") != null, "снаряд летит, не хитскан", failures)
	var flying := main.get_node("Projectile") as RifleProjectile
	var initial_position := flying.position
	var initial_velocity := flying.velocity
	await get_tree().physics_frame
	await get_tree().physics_frame
	var delta_velocity := flying.velocity - initial_velocity
	_check(flying.position.distance_to(initial_position) > 1.0, "снаряд проходит расстояние во времени", failures)
	_check(delta_velocity.y < 0.0 and Vector2(delta_velocity.x, delta_velocity.z).length() > 0.001, "скорость снаряда меняется под действием ветра и гравитации", failures)
	await get_tree().create_timer(1.8).timeout
	_check(Economy.points == score_before + SniperRifle.HIT_POINTS and observed_impacts.size() == 1, "подтверждённое попадание за 500 м начисляет очки", failures)
	await get_tree().create_timer(0.8).timeout
	_check(main.rifle.can_fire(), "затвор снова готов", failures)
	_check(main.rifle.fire(), "второй выстрел после затвора", failures)
	await get_tree().create_timer(1.8).timeout
	_check(observed_impacts.size() == 2 and Economy.points == score_before + SniperRifle.HIT_POINTS, "повторное попадание не начисляет очки дважды", failures)
	main.rifle.ammo = 0
	_check(not main.rifle.fire(), "без патронов выстрел невозможен", failures)

	# M4: радио — интерактивное и локальное, эфир не равен присутствию робота.
	var radio := main.radio_tuner
	_check(not radio.powered and not radio.tuning, "радио выключено по умолчанию", failures)
	main.player.position = Vector3(-3.6, ObservationTower.DECK_HEIGHT, -3.9)
	_check(radio.nearby(), "к радио можно подойти", failures)
	var radio_key := InputEventKey.new()
	radio_key.physical_keycode = KEY_E
	radio_key.pressed = true
	Input.parse_input_event(radio_key)
	Input.flush_buffered_events()
	await get_tree().process_frame
	_check(radio.tuning and radio.powered, "E открывает и включает приёмник через ввод", failures)
	var player_before_radio := main.player.position
	Input.action_press("move_forward")
	main.player._physics_process(1.0)
	Input.action_release("move_forward")
	var radio_horizontal_move := Vector2(main.player.position.x - player_before_radio.x, main.player.position.z - player_before_radio.z).length()
	_check(radio_horizontal_move < 0.01, "при настройке ходьба отключена", failures)
	main.rifle.ammo = 2
	main.rifle.cycle_remaining = 0.0
	main.rifle._input(capture_click)
	_check(main.rifle.ammo == 2, "при настройке нельзя случайно выстрелить", failures)
	var freq_key := InputEventKey.new()
	freq_key.physical_keycode = KEY_RIGHT
	freq_key.pressed = true
	var previous_freq := radio.frequency
	radio._input(freq_key)
	_check(is_equal_approx(radio.frequency, previous_freq + 0.1), "ручная настройка частоты", failures)
	radio.set_frequency(88.5)
	radio.update_signal()
	_check(radio.station_index == 0 and radio.signal_strength > 0.8, "станция архивной записи", failures)
	radio._process(0.0)
	_check(radio._record.stream != null and radio._record.playing, "архивная речь воспроизводится", failures)
	radio.set_frequency(94.2)
	radio.live_on_air = true
	radio.update_signal()
	_check(radio.station_index == 1 and radio.signal_strength > 0.8 and main.ambient_spawner.get_child_count() == 0, "живой сигнал возможен без робота", failures)
	radio.live_on_air = false
	radio.update_signal()
	_check(radio.station_index == -1 and radio.signal_strength == 0.0, "эфир может пропасть без появления робота", failures)
	_check(radio._packets.size() == 4 and radio._noise.stream != null, "живые пакеты и фоновый шум", failures)
	radio.set_frequency(103.1)
	radio.update_signal()
	_check(radio.station_index == 2, "вторая архивная запись", failures)
	radio.set_frequency(120.0)
	_check(is_equal_approx(radio.frequency, RadioTuner.MAX_FREQ), "шкала ограничена", failures)
	# Передача включается отдельной клавишей; приём эфира остаётся независимым.
	var beacon_key := InputEventKey.new()
	beacon_key.physical_keycode = KEY_T
	beacon_key.pressed = true
	Input.parse_input_event(beacon_key)
	Input.flush_buffered_events()
	_check(radio.transmitting and radio._beacon.playing, "T запускает сообщение маяка через ввод", failures)
	var beacon_spawner := main.ambient_spawner
	beacon_spawner.rng.seed = 19381
	beacon_spawner.advance_signal(0.0, 0)
	_check(beacon_spawner.get_child_count() == 0 and beacon_spawner.call_delays[0] >= 10.0 and beacon_spawner.call_delays[0] <= 40.0 and beacon_spawner.call_delays[1] >= 10.0 and beacon_spawner.call_delays[1] <= 40.0 and not is_equal_approx(beacon_spawner.call_delays[0], beacon_spawner.call_delays[1]), "у каждого свободного слота своя задержка 10–40 секунд", failures)
	beacon_spawner.advance_signal(9.9, 0)
	_check(beacon_spawner.get_child_count() == 0, "на сигнал нет мгновенного появления", failures)
	for attempt in range(40):
		beacon_spawner.advance_signal(40.0 if attempt == 0 else 2.0, beacon_spawner.get_child_count())
		if beacon_spawner.get_child_count() >= AmbientSpawner.MAX_ACTIVE:
			break
	_check(beacon_spawner.get_child_count() == AmbientSpawner.MAX_ACTIVE, "сигнал вызывает роботов с общим лимитом", failures)
	for called_child in beacon_spawner.get_children():
		var called_robot := called_child as AmbientRobot
		var called_vector := called_robot.global_position - main.cam_rig.cam.global_position
		var called_forward := -main.cam_rig.cam.global_basis.z
		var called_dot := Vector2(called_forward.x, called_forward.z).normalized().dot(Vector2(called_vector.x, called_vector.z).normalized())
		_check(called_dot <= 0.4 and not main.cam_rig.cam.is_position_in_frustum(called_robot.global_position + Vector3.UP * 3.0), "вызванный робот создаётся вне широкого сектора взгляда", failures)
		_check(called_robot.approaching_signal and called_robot.call_slot >= 0 and Vector2(called_robot.destination.x - main.tower.global_position.x, called_robot.destination.y - main.tower.global_position.z).length() < 20.0, "вызванный робот направляется к подножию", failures)
	radio.set_tuning(false)
	_check(radio.transmitting, "маяк продолжает передачу после закрытия панели", failures)
	radio.set_tuning(true)
	# Уровень угрозы растёт от времени передачи и ограничивается; количество
	# меняется по ступеням, но это не синхронные волны.
	_check(is_equal_approx(AmbientSpawner.threat_after(0.0, true, 240.0), 0.5) and is_equal_approx(AmbientSpawner.threat_after(0.5, true, 240.0), 1.0), "рост угрозы зависит от времени маяка", failures)
	_check(is_equal_approx(AmbientSpawner.threat_after(1.0, false, 120.0), 0.5) and is_zero_approx(AmbientSpawner.threat_after(1.0, false, 240.0)), "угроза плавно затихает и ограничена", failures)
	_check(AmbientSpawner.capacity_for(0.0) == 2 and AmbientSpawner.capacity_for(0.5) == 5 and AmbientSpawner.capacity_for(1.0) == 8, "бюджет растёт от двух до восьми", failures)
	_check(AmbientSpawner.delay_range_for(1.0).x < AmbientSpawner.delay_range_for(0.0).x and AmbientSpawner.delay_range_for(1.0).y < AmbientSpawner.delay_range_for(0.0).y, "с ростом угрозы задержки короче", failures)
	var steady_pos := main.tower.global_position + Vector3(220.0, 0.0, 40.0)
	steady_pos.y = main.coast.ground_height(steady_pos.x, steady_pos.z)
	var steady_robot := beacon_spawner.spawn_at(AmbientRobot.Kind.SCOUT, steady_pos, 4190)
	var fast_robot := beacon_spawner.spawn_at(AmbientRobot.Kind.SCOUT, steady_pos, 4191)
	steady_robot.configure_signal_speed(0.0, 0.3)
	fast_robot.configure_signal_speed(1.0, 0.3)
	_check(not steady_robot.signal_fast and fast_robot.signal_fast and fast_robot.speed > steady_robot.speed, "высокая угроза увеличивает долю и скорость быстрых роботов", failures)
	steady_robot.free()
	fast_robot.free()
	# Реальная проверка полного бюджета, не только формулы: восемь разных
	# откликов, даже если некоторые попытки позиции с первого раза не прошли.
	for step in range(60):
		beacon_spawner.advance_signal(10.0, beacon_spawner.get_child_count())
	_check(is_equal_approx(beacon_spawner.threat, 1.0) and beacon_spawner.get_child_count() == AmbientSpawner.MAX_SIGNAL_ACTIVE, "маяк постепенно вызывает до восьми роботов", failures)
	for i in range(5):
		beacon_spawner.get_child(beacon_spawner.get_child_count() - 1).free()
	radio.set_transmitting(false)
	beacon_spawner.advance_signal(0.0, beacon_spawner.get_child_count())
	_check(not radio._beacon.playing and is_equal_approx(beacon_spawner.threat, 1.0) and beacon_spawner.call_delays.any(func(delay: float) -> bool: return delay >= 0.0), "отключение сохраняет остаточный отклик", failures)
	beacon_spawner.advance_signal(15.0, beacon_spawner.get_child_count())
	for retry in range(40):
		if beacon_spawner.get_child_count() > 3:
			break
		beacon_spawner.advance_signal(2.0, beacon_spawner.get_child_count())
	_check(beacon_spawner.threat < 1.0 and beacon_spawner.threat > 0.0 and beacon_spawner.get_child_count() > 3, "после выключения ещё возможны отложенные отклики", failures)
	var survivors_before_fade := beacon_spawner.get_child_count()
	beacon_spawner.advance_signal(240.0, survivors_before_fade)
	_check(is_zero_approx(beacon_spawner.threat) and beacon_spawner.get_child_count() == survivors_before_fade and not beacon_spawner.call_delays.any(func(delay: float) -> bool: return delay >= 0.0), "отклик затихает без удаления уже пришедших", failures)
	var arrived_robot := beacon_spawner.get_child(0) as AmbientRobot
	arrived_robot.approaching_signal = false
	arrived_robot.age = arrived_robot.lifetime + 1.0
	beacon_spawner._process(0.0)
	_check(not arrived_robot.is_queued_for_deletion(), "живой робот не исчезает после прибытия и затухания", failures)
	arrived_robot.approaching_signal = true
	for called_child in beacon_spawner.get_children():
		var called_robot := called_child as AmbientRobot
		var dist_before_call_move := Vector2(called_robot.global_position.x - main.tower.global_position.x, called_robot.global_position.z - main.tower.global_position.z).length()
		called_robot._physics_process(3.0)
		var dist_after_call_move := Vector2(called_robot.global_position.x - main.tower.global_position.x, called_robot.global_position.z - main.tower.global_position.z).length()
		_check(called_robot.approaching_signal and dist_after_call_move < dist_before_call_move, "уже откликнувшийся робот продолжает путь после выключения", failures)
		called_robot.free()
	var existing_position := main.tower.global_position + Vector3(250.0, 0.0, 0.0)
	existing_position.y = main.coast.ground_height(existing_position.x, existing_position.z)
	var existing_robot := beacon_spawner.spawn_at(AmbientRobot.Kind.SCOUT, existing_position, 2193)
	radio.set_transmitting(true)
	beacon_spawner.advance_signal(0.0, 1)
	_check(existing_robot.signal_called and existing_robot.approaching_signal and existing_robot.call_slot == -1, "существующий робот тоже откликается на маяк", failures)
	existing_robot.free()
	radio.set_powered(false)
	_check(not radio.transmitting and not radio._beacon.playing and not radio.powered and not radio._record.playing and not radio._live.playing and not radio._noise.playing, "питание выключает передачу, записи, шум и сигнал", failures)
	var freq_before_close := radio.frequency
	Input.parse_input_event(radio_key)
	Input.flush_buffered_events()
	await get_tree().process_frame
	_check(not radio.tuning and is_equal_approx(radio.frequency, freq_before_close), "E закрывает радио, не меняя частоту", failures)
	_check(main.rifle.hud.visible, "выход из радио возвращает интерфейс винтовки", failures)
	main.player.position = Vector3(4.7, ObservationTower.DECK_HEIGHT, -1.4)
	_check(not radio.nearby(), "радио не управляется с другого края площадки", failures)
	# Статистическая проверка вероятностного процесса: более 500 опытов по
	# десять минут в виртуальном времени; игра не обязана показывать встречу.
	var sim_rng := RandomNumberGenerator.new()
	sim_rng.seed = 4791
	var empty_runs := 0
	var probability := AmbientSpawner.chance_for(1.0, 1.0, 0.0, false)
	for run in range(600):
		var encountered := false
		for second in range(600):
			if sim_rng.randf() < probability:
				encountered = true
				break
		if not encountered:
			empty_runs += 1
	_check(empty_runs > 200 and empty_runs < 400, "10 минут без встреч — штатный исход (%d/600)" % empty_runs, failures)
	_check(AmbientSpawner.chance_for(1.0, 1.0, 0.0, true) > probability and probability > 0.0, "эфир лишь меняет вероятность, появление возможно без него", failures)
	_check(AmbientSpawner.chance_for(1.0, 1.2, 0.0, false) < probability and AmbientSpawner.chance_for(1.0, 1.0, 1.0, false) > probability, "погода и время суток мягко влияют на вероятность", failures)
	# Испытать и настоящий путь выбора позиции, не только ручное spawn_at.
	main.cam_rig.refresh_pose()
	radio.live_on_air = false
	main.ambient_spawner.rng.seed = 1771
	for attempt in range(10):
		if main.ambient_spawner.get_child_count() > 0:
			break
		main.ambient_spawner._try_spawn()
	_check(main.ambient_spawner.get_child_count() == 1, "реальный алгоритм создаёт встречу и без сигнала", failures)
	if main.ambient_spawner.get_child_count() > 0:
		var spawned := main.ambient_spawner.get_child(0) as AmbientRobot
		var view_vector := -main.cam_rig.cam.global_basis.z
		var robot_vector := spawned.global_position - main.cam_rig.cam.global_position
		var view_flat := Vector2(view_vector.x, view_vector.z).normalized()
		var robot_flat := Vector2(robot_vector.x, robot_vector.z).normalized()
		_check(view_flat.dot(robot_flat) <= 0.4, "робот появляется за пределами широкого сектора обзора", failures)
		spawned.free()
	main.player.position = Vector3(-4.7, ObservationTower.DECK_HEIGHT, -1.4)
	main.cam_rig.aim_offset = Vector2.ZERO
	main.cam_rig.set_view(-PI * 0.5, 0.0)
	await get_tree().physics_frame
	var robot_x := main.tower.global_position.x - 220.0
	var robot_z := main.tower.global_position.z - 1.4
	var robots: Array[AmbientRobot] = []
	for i in range(3):
		var z := robot_z + (float(i) - 1.0) * 25.0
		var robot_pos := Vector3(robot_x, main.coast.ground_height(robot_x, z), z)
		robots.append(main.ambient_spawner.spawn_at(i as AmbientRobot.Kind, robot_pos, 6300 + i))
	_check(robots[0].body_size != robots[1].body_size and robots[1].body_size != robots[2].body_size, "три разных типа роботов", failures)
	var robot_start := robots[0].global_position
	robots[0]._physics_process(1.0)
	_check(robots[0].global_position.distance_to(robot_start) > 0.05 and absf(robots[0].global_position.y - robots[0].support_height(robots[0].global_position.x, robots[0].global_position.z)) < 0.01, "робот медленно движется по рельефу", failures)
	var terrain_progress_start := robots[0].global_position
	robots[0].destination = Vector2(terrain_progress_start.x + 80.0, terrain_progress_start.z + 25.0)
	var robot_feet_clear := true
	for terrain_step in range(40):
		robots[0]._physics_process(0.25)
		if robots[0].global_position.y + 0.001 < robots[0].support_height(robots[0].global_position.x, robots[0].global_position.z):
			robot_feet_clear = false
	_check(robot_feet_clear and robots[0].global_position.distance_to(terrain_progress_start) > 5.0, "робот проходит неровный песок без проваливания опоры", failures)
	_check(not radio.live_on_air and robots[1].alive, "робот существует без живого сигнала", failures)
	radio.live_on_air = true
	_check(radio.live_on_air and main.ambient_spawner.get_child_count() > 0, "состояние эфира независимо от объектов", failures)
	var victim := robots[2]
	victim.speed = 0.0
	victim.velocity = Vector2.ZERO
	await get_tree().physics_frame
	var shot_origin := main.player.global_position + Vector3.UP * CameraRig.EYE
	var victim_center := victim.global_position + Vector3.UP * victim.body_size.y * 0.5
	var travel := shot_origin.distance_to(victim_center) / SniperRifle.MUZZLE_SPEED
	var aim_robot := (victim_center - Ballistics.acceleration(main.game, 0.0, 0.0) * (0.5 * travel * travel) - shot_origin).normalized()
	main.cam_rig.set_view(atan2(aim_robot.x, aim_robot.z), asin(aim_robot.y))
	main.rifle._recoil = 0.0
	main.rifle._hit_flash = 0.0
	var score_before_robot := Economy.points
	var robot_feedback: Array[float] = []
	main.rifle.robot_impact_confirmed.connect(func(_robot: AmbientRobot) -> void: robot_feedback.append(main.rifle._hit_flash))
	main.rifle.on_robot_hit(victim, shot_origin + main.cam_rig.cam.global_basis.z * 10.0)
	_check(robot_feedback.is_empty() and main.rifle._hit_flash == 0.0, "робот вне кадра не подтверждается", failures)
	main.rifle.aim_requested = true
	main.rifle.scope_amount = 1.0
	main.rifle._physics_process(0.0)
	_check(main.rifle.fire(), "выстрел по роботу", failures)
	await get_tree().create_timer(1.0).timeout
	_check(not victim.alive and victim.hitbox.disabled, "реальный летящий снаряд тихо выводит робота из строя", failures)
	_check(robot_feedback.size() == 1 and robot_feedback[0] > 0.9, "видимое попадание в робота подтверждается маркером", failures)
	_check(Economy.points == score_before_robot + 250, "подтверждение робота начисляет награду", failures)
	# M5: броня принимает только реальный AP-снаряд.
	var armored := robots[1]
	armored.speed = 0.0
	armored.velocity = Vector2.ZERO
	main.rifle.cycle_remaining = 0.0
	main.rifle.ammo_type = "regular"
	main.rifle.ammo = 2
	main.rifle._recoil = 0.0
	var armor_center := armored.global_position + Vector3.UP * armored.body_size.y * 0.5
	var armor_flight := shot_origin.distance_to(armor_center) / SniperRifle.MUZZLE_SPEED
	var armor_aim := (armor_center - Ballistics.acceleration(main.game, 0.0, 0.0) * (0.5 * armor_flight * armor_flight) - shot_origin).normalized()
	main.cam_rig.aim_offset = Vector2.ZERO
	main.cam_rig.set_view(atan2(armor_aim.x, armor_aim.z), asin(armor_aim.y))
	var points_before_armor := Economy.points
	_check(main.rifle.fire(), "обычный выстрел по броне", failures)
	await get_tree().create_timer(0.55).timeout
	_check(armored.alive and Economy.points == points_before_armor and main.rifle._deflect_flash > 0.0, "обычный снаряд отскакивает без награды", failures)
	main.rifle.cycle_remaining = 0.0
	main.rifle._recoil = 0.0
	main.rifle.ap_reserve = 3
	var tab_key := InputEventKey.new()
	tab_key.pressed = true
	tab_key.physical_keycode = KEY_TAB
	main.rifle._input(tab_key)
	_check(main.rifle.ammo_type == "ap" and main.rifle.ammo == 3, "Tab меняет тип и заряжает AP из запаса", failures)
	main.cam_rig.set_view(atan2(armor_aim.x, armor_aim.z), asin(armor_aim.y))
	_check(main.rifle.fire(), "выстрел AP", failures)
	var ap_shot := main.get_node_or_null("Projectile") as RifleProjectile
	_check(ap_shot != null and ap_shot.pierce, "физический снаряд имеет флаг pierce", failures)
	await get_tree().create_timer(0.8).timeout
	_check(not armored.alive and Economy.points == points_before_armor + 400, "AP поражает броню и даёт 400 очков", failures)
	for robot in robots:
		robot.queue_free()
	await get_tree().process_frame
	await _test_piercing(failures)
	await _test_m5(failures)
	_test_terrain_paths(failures)
	await _test_climbing(failures)
	_test_reload(failures)
	await _test_debug_menu(failures)
	await _test_contact_combat(failures)

	if failures.is_empty():
		print("[SMOKE] итог: ВСЁ ПРОШЛО")
		get_tree().quit(0)
	else:
		printerr("[SMOKE] итог: ошибки: ", failures)
		get_tree().quit(1)


func _test_terrain_paths(failures: Array[String]) -> void:
	# Ускоренно проверяем разные подходы и все три скорости, без ожидания в реальном времени.
	var center := main.tower.global_position
	for robot_kind in range(3):
		for heading in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
			var at := Vector3(center.x + heading.x * 220.0, 0.0, center.z + heading.y * 220.0)
			at.y = main.coast.ground_height(at.x, at.z)
			var path_robot := main.ambient_spawner.spawn_at(robot_kind as AmbientRobot.Kind, at, 973 + robot_kind)
			path_robot.set_physics_process(false)
			path_robot.respond_to_signal(center, 0)
			var feet_clear := true
			for virtual_second in range(650):
				path_robot._physics_process(1.0)
				var footprint_radius := Vector2(path_robot.body_size.x, path_robot.body_size.z).length() * 0.5
				for dx in [-footprint_radius, 0.0, footprint_radius]:
					for dz in [-footprint_radius, 0.0, footprint_radius]:
						if path_robot.global_position.y < main.coast.ground_height(path_robot.global_position.x + dx, path_robot.global_position.z + dz):
							feet_clear = false
				if not path_robot.approaching_signal:
					break
			var remaining := Vector2(path_robot.global_position.x - center.x, path_robot.global_position.z - center.z).length()
			_check(feet_clear and not path_robot.approaching_signal and remaining < 21.0, "робот %d проходит песок к башне со стороны %s" % [robot_kind, heading], failures)
			path_robot.free()


func _test_climbing(failures: Array[String]) -> void:
	var center := main.tower.global_position
	# Отдельный тестовый режим не влияет на обычную игру и сбрасывается F4.
	ProjectSettings.set_setting("journey/m6/climb_preview", true)
	var climb_preview_spawner := AmbientSpawner.new()
	main.add_child(climb_preview_spawner)
	climb_preview_spawner.setup(main)
	_check(climb_preview_spawner.preview_climbing and climb_preview_spawner.get_child_count() == 1, "демо подъёма запускает одну машину у башни", failures)
	var reset_climb := InputEventKey.new()
	reset_climb.physical_keycode = KEY_F4
	reset_climb.pressed = true
	climb_preview_spawner._unhandled_input(reset_climb)
	_check(climb_preview_spawner.get_child_count() == 1 and (climb_preview_spawner.get_child(0) as AmbientRobot).approaching_signal, "F4 сбрасывает только демо подъёма", failures)
	climb_preview_spawner.free()
	ProjectSettings.set_setting("journey/m6/climb_preview", false)
	# Проверяем четыре сектора и опоры, а не только ту, что видна в демо.
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var corner_start := center + Vector3(sx * 15.0, 0.0, sz * 15.0)
			corner_start.y = main.coast.ground_height(corner_start.x, corner_start.z)
			var corner_robot := main.ambient_spawner.spawn_at(AmbientRobot.Kind.SCOUT, corner_start, 7000)
			corner_robot.set_physics_process(false)
			corner_robot.respond_to_signal(center, 0)
			var target_offset := corner_robot.support_target - Vector2(center.x, center.z)
			_check(signf(target_offset.x) == sx and signf(target_offset.y) == sz, "выбрана ближайшая опора сектора %s, %s" % [sx, sz], failures)
			for path_step in range(200):
				corner_robot._physics_process(0.5)
				if corner_robot.climb_state == AmbientRobot.ClimbState.AT_TOP:
					break
			_check(corner_robot.climb_state == AmbientRobot.ClimbState.AT_TOP, "робот достиг вершины сектора %s, %s" % [sx, sz], failures)
			corner_robot.free()
	# Все три типа доходят до опоры, поднимаются, ждут и падают при попадании.
	for robot_kind in range(3):
		var start_at := center + Vector3(20.0, 0.0, -2.0)
		start_at.y = main.coast.ground_height(start_at.x, start_at.z)
		var climbing_robot := main.ambient_spawner.spawn_at(robot_kind as AmbientRobot.Kind, start_at, 8000 + robot_kind)
		climbing_robot.set_physics_process(false)
		# В этой части проверяем только подъём и падение, не контактную фазу.
		climbing_robot.health_ref = null
		climbing_robot.respond_to_signal(center, robot_kind)
		var saw_climb := false
		var last_y := -INF
		var rose := false
		for virtual_step in range(400):
			climbing_robot._physics_process(0.5)
			if climbing_robot.climb_state == AmbientRobot.ClimbState.CLIMBING:
				saw_climb = true
				if last_y > -INF and climbing_robot.global_position.y > last_y:
					rose = true
				last_y = climbing_robot.global_position.y
			if climbing_robot.climb_state == AmbientRobot.ClimbState.AT_TOP:
				break
		_check(saw_climb and rose and climbing_robot.climb_state == AmbientRobot.ClimbState.AT_TOP and absf(climbing_robot.global_position.y - (center.y + ObservationTower.DECK_HEIGHT)) < 0.01, "робот %d поднимается и останавливается у площадки" % robot_kind, failures)
		var top_before := climbing_robot.global_position
		climbing_robot._physics_process(4.0)
		_check(climbing_robot.global_position == top_before and climbing_robot.alive, "робот %d ждёт наверху без атаки" % robot_kind, failures)
		_check(climbing_robot.apply_projectile_hit(robot_kind == AmbientRobot.Kind.CARRIER) and climbing_robot.falling, "робот %d выводится из строя наверху" % robot_kind, failures)
		var top_y := climbing_robot.global_position.y
		climbing_robot._physics_process(0.25)
		_check(climbing_robot.global_position.y < top_y, "робот %d падает после поражения" % robot_kind, failures)
		for fall_step in range(30):
			climbing_robot._physics_process(0.25)
		_check(not climbing_robot.falling and is_equal_approx(climbing_robot.global_position.y, climbing_robot.support_height(climbing_robot.global_position.x, climbing_robot.global_position.z)), "робот %d падает на грунт" % robot_kind, failures)
		climbing_robot.free()
	# Отдельно проверяем реальный выстрел по движущемуся хитбоксу при подъёме.
	var shot_start := center + Vector3(20.0, 0.0, -1.4)
	shot_start.y = main.coast.ground_height(shot_start.x, shot_start.z)
	var shot_climber := main.ambient_spawner.spawn_at(AmbientRobot.Kind.SCOUT, shot_start, 9120)
	shot_climber.set_physics_process(false)
	shot_climber.respond_to_signal(center, 0)
	for virtual_step in range(120):
		shot_climber._physics_process(0.5)
		if shot_climber.climb_state == AmbientRobot.ClimbState.CLIMBING and shot_climber.global_position.y >= center.y + 49.0:
			break
	_check(shot_climber.climb_state == AmbientRobot.ClimbState.CLIMBING, "мишень для теста находится на подъёме", failures)
	main.radio_tuner.set_powered(true)
	main.radio_tuner.set_transmitting(true)
	main.radio_tuner.set_transmitting(false)
	var climb_before_cancel := shot_climber.global_position.y
	shot_climber._physics_process(0.5)
	_check(shot_climber.signal_called and shot_climber.global_position.y > climb_before_cancel, "выключение маяка не останавливает подъём", failures)
	main.radio_tuner.set_tuning(false)
	main.player.position = Vector3(4.7, ObservationTower.DECK_HEIGHT, -1.4)
	await get_tree().physics_frame
	main.cam_rig.aim_offset = Vector2.ZERO
	main.cam_rig.refresh_pose()
	var climb_hit_center := shot_climber.global_position + Vector3.UP * shot_climber.body_size.y * 0.5
	var climb_eye := main.cam_rig.cam.global_position
	var shot_dir := (climb_hit_center - climb_eye).normalized()
	main.cam_rig.set_view(atan2(shot_dir.x, shot_dir.z), asin(shot_dir.y))
	main.rifle.aim_requested = false
	main.rifle.scope_amount = 0.0
	main.rifle.ammo_type = "regular"
	main.rifle.ammo = 2
	main.rifle.cycle_remaining = 0.0
	main.rifle.reload_remaining = 0.0
	main.rifle._recoil = 0.0
	var climb_reward_before := Economy.points
	await get_tree().physics_frame
	_check(main.rifle.fire(), "реальный выстрел по поднимающемуся роботу", failures)
	await get_tree().create_timer(0.4).timeout
	_check(not shot_climber.alive and shot_climber.falling and Economy.points == climb_reward_before + 100, "выстрел прерывает подъём и начисляет обычную награду", failures)
	shot_climber.free()
	# Та же проверка физическим снарядом для брони: обычная пуля не
	# прерывает подъём, AP поражает и начисляет награду один раз.
	var armored_climber := main.ambient_spawner.spawn_at(AmbientRobot.Kind.CARRIER, shot_start, 9121)
	armored_climber.set_physics_process(false)
	armored_climber.respond_to_signal(center, 1)
	for virtual_step in range(200):
		armored_climber._physics_process(0.5)
		if armored_climber.climb_state == AmbientRobot.ClimbState.CLIMBING and armored_climber.global_position.y >= center.y + 49.0:
			break
	_check(armored_climber.climb_state == AmbientRobot.ClimbState.CLIMBING, "бронированный робот находится на подъёме", failures)
	main.cam_rig.refresh_pose()
	var armored_center := armored_climber.global_position + Vector3.UP * armored_climber.body_size.y * 0.5
	var armored_dir := (armored_center - main.cam_rig.cam.global_position).normalized()
	main.cam_rig.set_view(atan2(armored_dir.x, armored_dir.z), asin(armored_dir.y))
	main.rifle.ammo_type = "regular"
	main.rifle.ammo = 2
	main.rifle.cycle_remaining = 0.0
	main.rifle._recoil = 0.0
	var armored_reward_before := Economy.points
	await get_tree().physics_frame
	_check(main.rifle.fire(), "обычный выстрел по броне на опоре", failures)
	await get_tree().create_timer(0.4).timeout
	_check(armored_climber.alive and Economy.points == armored_reward_before and main.rifle._deflect_flash > 0.0, "броня на опоре отражает обычный снаряд", failures)
	main.rifle.ammo_type = "ap"
	main.rifle.ammo = 2
	main.rifle.cycle_remaining = 0.0
	main.rifle._recoil = 0.0
	main.cam_rig.set_view(atan2(armored_dir.x, armored_dir.z), asin(armored_dir.y))
	_check(main.rifle.fire(), "AP по броне на опоре", failures)
	await get_tree().create_timer(0.4).timeout
	_check(not armored_climber.alive and armored_climber.falling and Economy.points == armored_reward_before + 400, "AP поражает броню на опоре с наградой и падением", failures)
	armored_climber.free()


func _test_debug_menu(failures: Array[String]) -> void:
	# Настоящие события F2 и мыши при реалистичном размере окна.
	var previous_size := get_tree().root.size
	get_tree().root.size = Vector2i(1280, 720)
	await get_tree().process_frame
	_check(not main.debug_menu.is_open and main.debug_menu.hint.visible, "подсказка F2 видна без включения демонстрации", failures)
	main.radio_tuner.set_tuning(true)
	main.shop.set_open(true)
	var f2_event := InputEventKey.new()
	f2_event.physical_keycode = KEY_F2
	f2_event.pressed = true
	Input.parse_input_event(f2_event)
	Input.flush_buffered_events()
	await get_tree().process_frame
	_check(main.debug_menu.is_open and main.debug_menu.backdrop.visible and not main.shop.is_open and not main.radio_tuner.tuning, "F2 открывает отладку и корректно закрывает радио и магазин", failures)
	var ammo_type_before := main.rifle.ammo_type
	var tab_event := InputEventKey.new()
	tab_event.physical_keycode = KEY_TAB
	tab_event.pressed = true
	main.rifle._input(tab_event)
	_check(main.rifle.ammo_type == ammo_type_before, "клавиши отладки не переключают боеприпасы", failures)
	var ordinary_at := main.tower.global_position + Vector3(100.0, 0.0, 100.0)
	ordinary_at.y = main.coast.ground_height(ordinary_at.x, ordinary_at.z)
	var ordinary := main.ambient_spawner.spawn_at(AmbientRobot.Kind.SCOUT, ordinary_at, 11991)
	ordinary.set_physics_process(false)
	await get_tree().process_frame
	var button_center := main.debug_menu.top_button.get_global_rect().get_center()
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = button_center
	click.global_position = button_center
	click.pressed = true
	Input.parse_input_event(click)
	Input.flush_buffered_events()
	click = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = button_center
	click.global_position = button_center
	click.pressed = false
	Input.parse_input_event(click)
	Input.flush_buffered_events()
	await get_tree().process_frame
	main.ambient_spawner.set_process(false)
	var top_robot := main.ambient_spawner.get_node_or_null("ClimbPreviewRobot") as AmbientRobot
	_check(not main.debug_menu.is_open and main.ambient_spawner.preview_climbing and top_robot != null and top_robot.climb_state == AmbientRobot.ClimbState.CLIMBING, "кнопка сразу показывает подъём у площадки", failures)
	if top_robot != null:
		var aim := (top_robot.global_position + Vector3.UP * top_robot.body_size.y * 0.5 - main.cam_rig.cam.global_position).normalized()
		_check((-main.cam_rig.cam.global_basis.z).dot(aim) > 0.999, "быстрая проверка наводит камеру на робота", failures)
	var f4_event := InputEventKey.new()
	f4_event.physical_keycode = KEY_F4
	f4_event.pressed = true
	main.ambient_spawner._unhandled_input(f4_event)
	var reset_robot := main.ambient_spawner.get_node_or_null("ClimbPreviewRobot") as AmbientRobot
	_check(reset_robot != null and reset_robot.approaching_signal and ordinary.get_parent() == main.ambient_spawner, "F4 сбрасывает только тестового робота, не обычного", failures)
	main.debug_menu.set_open(true)
	main.debug_menu.robots_button.pressed.emit()
	_check(main.ambient_spawner.preview_robots and not main.ambient_spawner.preview_climbing and ordinary.get_parent() == main.ambient_spawner and main.ambient_spawner.get_child_count() == 4, "демо трёх типов сохраняет обычных роботов", failures)
	main.ambient_spawner._unhandled_input(f4_event)
	_check(main.ambient_spawner.get_child_count() == 4 and ordinary.get_parent() == main.ambient_spawner, "F4 тройки не удаляет обычных роботов", failures)
	main.debug_menu.set_open(true)
	main.debug_menu.normal_button.pressed.emit()
	main.ambient_spawner.set_process(false)
	_check(not main.ambient_spawner.preview_robots and not main.ambient_spawner.preview_climbing and ordinary.get_parent() == main.ambient_spawner and main.ambient_spawner.get_child_count() == 1, "обычный режим убирает только демо и возвращает обычный спавнер", failures)
	ordinary.free()
	get_tree().root.size = previous_size
	await get_tree().process_frame


func _test_contact_combat(failures: Array[String]) -> void:
	main.player.position = Vector3(4.7, ObservationTower.DECK_HEIGHT, -1.4)
	main.player.velocity = Vector3.ZERO
	main.player_health.health = PlayerHealth.MAX_HEALTH
	main.player_health.invulnerability = 0.0
	main.debug_menu.set_open(true)
	main.debug_menu.attack_button.pressed.emit()
	main.ambient_spawner.set_process(false)
	var attacker := main.ambient_spawner.get_node_or_null("AttackPreviewRobot") as AmbientRobot
	_check(main.ambient_spawner.preview_attack and attacker != null and attacker.climb_state == AmbientRobot.ClimbState.AT_TOP, "F2 создаёт атакующего робота на площадке", failures)
	if attacker == null:
		return
	attacker.set_physics_process(false)
	var start_distance := attacker.global_position.distance_to(main.player.global_position)
	attacker._physics_process(1.0)
	_check(attacker.global_position.distance_to(main.player.global_position) < start_distance, "робот движется к игроку по площадке", failures)
	attacker._physics_process(0.1)
	_check(attacker.attack_windup > 0.0 and attacker.metal.emission_enabled and attacker.attack_arm.visible and attacker.attack_beacon.visible and main.player_health.warning_time > 0.0, "перед ударом есть визуальное и текстовое предупреждение", failures)
	# Уход за дистанцию в течение подготовки отменяет удар.
	main.player.position = Vector3(-4.7, ObservationTower.DECK_HEIGHT, 4.7)
	attacker._physics_process(0.1)
	_check(attacker.attack_windup == 0.0 and not attacker.metal.emission_enabled and not attacker.attack_arm.visible and main.player_health.health == 100, "можно выйти из радиуса до удара", failures)
	# Вернуть игрока на исходную позицию: атака сначала готовится, потом бьёт.
	main.player.position = Vector3(4.7, ObservationTower.DECK_HEIGHT, -1.4)
	for step in range(10):
		attacker._physics_process(0.1)
		if attacker.attack_windup > 0.0:
			break
	attacker._physics_process(AmbientRobot.ATTACK_WINDUP - 0.1)
	_check(main.player_health.health == 100, "удар не происходит до окончания подготовки", failures)
	attacker._physics_process(0.2)
	_check(main.player_health.health == 85 and attacker.attack_cooldown > 0.0, "удар отнимает 15 здоровья и запускает паузу", failures)
	_check(not main.player_health.take_damage(15) and main.player_health.health == 85, "соседние одновременные удары не накладываются", failures)
	main.player_health._physics_process(PlayerHealth.INVULNERABILITY + 0.1)
	_check(main.player_health.take_damage(15) and main.player_health.health == 70, "после короткой защиты урон снова возможен", failures)
	main.debug_menu.set_open(true)
	main.debug_menu.heal_button.pressed.emit()
	_check(main.player_health.health == 100, "отладочная кнопка явно восстанавливает здоровье", failures)
	main.debug_menu.set_open(false)
	# Погибший робот не наносит удар, и тело на настиле не падает сквозь пол.
	attacker.attack_cooldown = 0.0
	attacker._physics_process(0.1)
	_check(attacker.attack_windup > 0.0, "повторная атака проходит подготовку", failures)
	_check(attacker.apply_projectile_hit(false) and not attacker.falling, "робот на настиле остаётся на настиле после поражения", failures)
	attacker._physics_process(3.0)
	_check(main.player_health.health == 100 and not attacker.metal.emission_enabled, "убитый робот не наносит подготовленный удар", failures)
	var f4_attack := InputEventKey.new()
	f4_attack.physical_keycode = KEY_F4
	f4_attack.pressed = true
	main.ambient_spawner._unhandled_input(f4_attack)
	var new_attacker := main.ambient_spawner.get_node_or_null("AttackPreviewRobot") as AmbientRobot
	_check(new_attacker != null and new_attacker.alive, "F4 восстанавливает атакующего тестового робота", failures)
	if new_attacker != null:
		new_attacker.set_physics_process(false)
		main.cam_rig.aim_offset = Vector2.ZERO
		main.cam_rig.refresh_pose()
		var target := new_attacker.global_position + Vector3.UP * new_attacker.body_size.y * 0.5
		var dir := (target - main.cam_rig.cam.global_position).normalized()
		main.cam_rig.set_view(atan2(dir.x, dir.z), asin(dir.y))
		main.rifle.ammo_type = "regular"
		main.rifle.ammo = 2
		main.rifle.cycle_remaining = 0.0
		main.rifle.reload_remaining = 0.0
		main.rifle._recoil = 0.0
		var score_before := Economy.points
		await get_tree().physics_frame
		_check(main.rifle.fire(), "выстрел в атакующего на площадке", failures)
		await get_tree().create_timer(0.4).timeout
		_check(not new_attacker.alive and Economy.points == score_before + 100, "реальная пуля поражает атакующего и выдаёт награду", failures)
	main.debug_menu.set_open(true)
	main.debug_menu.normal_button.pressed.emit()
	main.ambient_spawner.set_process(false)
	main.player_health.health = PlayerHealth.MAX_HEALTH
	main.player_health.invulnerability = 0.0
	await get_tree().process_frame


func _test_reload(failures: Array[String]) -> void:
	var rifle := main.rifle
	main.shop.set_open(false)
	main.radio_tuner.set_tuning(false)
	rifle.ammo_type = "regular"
	rifle.ammo = 5
	rifle.regular_reserve = 7
	rifle.cycle_remaining = 0.0
	rifle.reload_remaining = 0.0
	for shot_number in range(5):
		_check(rifle.fire(), "выстрел %d из пятизарядного магазина" % (shot_number + 1), failures)
		if shot_number < 4:
			rifle._physics_process(SniperRifle.CYCLE_TIME)
	_check(rifle.ammo == 0 and rifle.reload_remaining > 0.0 and not rifle.can_fire() and rifle.regular_reserve == 7, "пустой магазин автоматически начинает перезарядку", failures)
	rifle._physics_process(SniperRifle.RELOAD_TIME)
	_check(rifle.ammo == 5 and rifle.regular_reserve == 2 and rifle.can_fire(), "автоперезарядка переносит пять патронов из запаса", failures)
	rifle.ammo = 3
	rifle.regular_reserve = 7
	var reload_key := InputEventKey.new()
	reload_key.physical_keycode = KEY_R
	reload_key.pressed = true
	rifle._input(reload_key)
	_check(rifle.reload_remaining > 0.0 and rifle.ammo == 3 and not rifle.fire(), "R запускает неполную перезарядку и блокирует выстрел", failures)
	rifle._physics_process(SniperRifle.RELOAD_TIME)
	_check(rifle.ammo == 5 and rifle.regular_reserve == 5 and not rifle.start_reload(), "R дозаряжает до пяти без потери патронов; полный магазин не перезаряжается", failures)
	rifle.ammo = 2
	rifle.regular_reserve = 1
	_check(rifle.start_reload(), "перезарядка с малым запасом разрешена", failures)
	rifle._physics_process(SniperRifle.RELOAD_TIME)
	_check(rifle.ammo == 3 and rifle.regular_reserve == 0 and not rifle.start_reload(), "частичный запас не создаёт лишние патроны", failures)
	rifle.regular_reserve = 3
	rifle.ap_reserve = 2
	_check(rifle.start_reload(), "перезарядка перед сменой типа", failures)
	rifle.switch_ammo()
	_check(rifle.ammo_type == "ap" and rifle.ammo == 2 and rifle.regular_reserve == 6 and rifle.reload_remaining == 0.0, "смена типа отменяет перезарядку без потери патронов", failures)
	_check("БРОНЕБОЙНЫЕ" in rifle.hud._notice, "Tab показывает выбранные бронебойные", failures)
	rifle.switch_ammo()
	rifle.ap_reserve = 0
	rifle.switch_ammo()
	_check(rifle.ammo_type == "ap" and rifle.ammo == 0 and "НЕТ ПАТРОНОВ" in rifle.hud._notice, "при пустом запасе AP показывается понятная подсказка", failures)


func _test_piercing(failures: Array[String]) -> void:
	# Два тестовых хитбокса в воздухе на одной линии: один физический
	# отрезок бронебойного снаряда должен реально пройти сквозь первый.
	main.rifle.aim_requested = false
	main.rifle.scope_amount = 0.0
	main.rifle._recoil = 0.0
	main.cam_rig.aim_offset = Vector2.ZERO
	main.cam_rig.set_view(PI * 0.5, 0.0)
	var origin := main.player.global_position + Vector3.UP * CameraRig.EYE
	var targets: Array[TargetDummy] = []
	for distance in [18.0, 34.0]:
		var dummy := TargetDummy.new()
		main.add_child(dummy)
		dummy.global_position = origin + Vector3.RIGHT * distance - Vector3.UP * 2.9
		targets.append(dummy)
	await get_tree().physics_frame
	var shot := RifleProjectile.new()
	main.add_child(shot)
	shot.set_physics_process(false)
	shot.setup(origin, Vector3.RIGHT, SniperRifle.MUZZLE_SPEED, main, main.rifle, true)
	shot._physics_process(0.08)
	_check(targets[0]._confirmed and targets[1]._confirmed and shot.excluded.size() == 2, "AP реально проходит сквозь первую цель и поражает вторую", failures)
	shot.queue_free()
	for dummy in targets:
		dummy.queue_free()
	await get_tree().process_frame


func _test_m5(failures: Array[String]) -> void:
	# Автономный кошелёк проверяет сигналы и граничное списание без сброса
	# настоящего баланса игры, в том числе отрицательные значения.
	var wallet := Wallet.new()
	var deltas: Array[int] = []
	wallet.points_changed.connect(func(_value: int, delta: int) -> void: deltas.append(delta))
	wallet.add_points(150)
	_check(wallet.can_afford(150) and wallet.try_spend(150) and wallet.points == 0, "кошелёк списывает впритык", failures)
	_check(not wallet.try_spend(1) and not wallet.try_spend(-1) and wallet.points == 0, "недостаток и отрицательная цена не дают уйти в минус", failures)
	_check(deltas == [150, -150], "кошелёк сообщает значение и дельту", failures)
	wallet.free()
	var lift := main.lift
	_check(lift.state == SupplyLift.State.IDLE and lift.status_text() == "ЛИФТ ВНИЗУ", "лифт первоначально внизу", failures)
	_check(lift.scene_file_path == "res://scenes/Lift.tscn" and main.shop.scene_file_path == "res://scenes/ShopUI.tscn", "лифт и магазин — отдельные сцены", failures)
	Economy.try_spend(Economy.points)
	_check(not lift.can_order("ammo") and not lift.request_order("ammo") and Economy.points == 0, "недостаток очков делает товар недоступным без списания", failures)
	_check(not lift.request_batch({"ammo": 1, "ap": 1}) and lift.pending_items.is_empty() and lift.state == SupplyLift.State.IDLE and Economy.points == 0, "недостаток очков отклоняет всю корзину без частичной покупки", failures)
	for invalid_basket in [{}, {"missing": 1}, {"ammo": 0}, {"ammo": -1}, {"ammo": 100}, {"ammo": 1.5}, {"scope": 2}]:
		_check(lift.order_total(invalid_basket) == -1 and not lift.request_batch(invalid_basket) and lift.state == SupplyLift.State.IDLE, "отклоняется некорректная корзина %s" % str(invalid_basket), failures)
	# Headless создаёт окно 64×64: для проверки координат кнопок нужен
	# реалистичный размер viewport, иначе элементы не помещаются физически.
	get_tree().root.size = Vector2i(1280, 720)
	# Радио открывает терминал; пока он открыт, оружие/ходьба блокируются.
	main.player.position = Vector3(-3.6, ObservationTower.DECK_HEIGHT, -3.9)
	main.radio_tuner.set_tuning(true)
	var open_key := InputEventKey.new()
	open_key.physical_keycode = KEY_B
	open_key.pressed = true
	main.radio_tuner._input(open_key)
	_check(main.shop.is_open and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "B на радио открывает терминал и курсор", failures)
	var shop_interact := InputEventKey.new()
	shop_interact.physical_keycode = KEY_E
	shop_interact.pressed = true
	main.radio_tuner._input(shop_interact)
	_check(main.shop.is_open and main.radio_tuner.tuning, "E в открытом терминале не закрывает радио", failures)
	# После показа Control получает размеры на следующем кадре.
	await get_tree().process_frame
	await get_tree().process_frame
	var before_ammo := main.rifle.ammo
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	main.rifle._input(click)
	_check(main.rifle.ammo == before_ammo, "в терминале клик не стреляет", failures)
	Economy.add_points(5000)
	var before_order := Economy.points
	main.shop.change_quantity(0, 40)
	_check(not main.shop.attempt_order() and Economy.points == before_order and main.shop.cart == {"ammo": 40} and lift.state == SupplyLift.State.IDLE, "дорогая корзина не списывает деньги и остаётся для редактирования", failures)
	main.shop.change_quantity(0, -40)
	var orders_during_signal: Array[bool] = []
	var reentrant := func(_value: int, _delta: int) -> void: orders_during_signal.append(lift.request_order("ammo"))
	Economy.points_changed.connect(reentrant, CONNECT_ONE_SHOT)
	var shop_click := InputEventMouseButton.new()
	shop_click.button_index = MOUSE_BUTTON_LEFT
	shop_click.pressed = true
	shop_click.position = main.shop.panel.plus_button(0).get_center()
	main.shop.panel._gui_input(shop_click)
	main.shop.panel._gui_input(shop_click)
	shop_click.position = main.shop.panel.plus_button(1).get_center()
	main.shop.panel._gui_input(shop_click)
	shop_click.position = main.shop.panel.plus_button(3).get_center()
	main.shop.panel._gui_input(shop_click)
	main.shop.panel._gui_input(shop_click)
	_check(main.shop.cart == {"ammo": 2, "ap": 1, "stability": 1} and Economy.points == before_order and lift.state == SupplyLift.State.IDLE, "выбор нескольких позиций: cart=%s баланс=%d/%d state=%d panel=%s row=%s plus=%s" % [str(main.shop.cart), Economy.points, before_order, lift.state, str(main.shop.panel.size), str(main.shop.panel.row(0)), str(main.shop.panel.plus_button(0))], failures)
	shop_click.position = main.shop.panel.minus_button(0).get_center()
	main.shop.panel._gui_input(shop_click)
	_check(int(main.shop.cart.get("ammo", 0)) == 1, "кнопка минус уменьшает количество: %s" % str(main.shop.cart), failures)
	main.shop.selected = 0
	var cart_right := InputEventKey.new()
	cart_right.physical_keycode = KEY_RIGHT
	cart_right.pressed = true
	main.shop._input(cart_right)
	_check(int(main.shop.cart.get("ammo", 0)) == 2 and lift.order_total(main.shop.cart) == 1100, "стрелка увеличивает количество: %s total=%d" % [str(main.shop.cart), lift.order_total(main.shop.cart)], failures)
	shop_click.position = main.shop.panel.order_button().get_center()
	main.shop.panel._gui_input(shop_click)
	_check(lift.state == SupplyLift.State.CALLED and lift.pending_items == {"ammo": 2, "ap": 1, "stability": 1} and main.shop.cart.is_empty(), "кнопка оформляет один заказ и сохраняет снимок содержимого", failures)
	main.shop.panel._gui_input(shop_click)
	_check(orders_during_signal == [false] and Economy.points == before_order - 1100, "повторный клик и reentrant-заказ не списывают деньги дважды", failures)
	var order_enter := InputEventKey.new()
	order_enter.physical_keycode = KEY_ENTER
	order_enter.pressed = true
	main.shop._input(order_enter)
	_check(Economy.points == before_order - 1100 and lift.pending_items.size() == 3, "Enter с пустой корзиной не дублирует заказ", failures)
	_check(lift.state == SupplyLift.State.CALLED and lift._start_sfx.playing, "CALLED и лязг старта", failures)
	_check(lift.ascent_duration >= 30.0 and lift.ascent_duration <= 60.0 and lift.status_text() == "ЛИФТ В ПУТИ", "длительность 45±15 и только статус без обратного отсчёта", failures)
	main.shop.set_open(false)
	main.radio_tuner.set_tuning(false)
	lift.advance(1.0)
	_check(lift.state == SupplyLift.State.ASCENDING and lift._hum.playing, "ASCENDING и гул троса", failures)
	var cage_anchor := main.tower.model.find_child("*CAGE*center*", true, false) as Node3D
	var door_anchor := main.tower.model.find_child("*door*center*", true, false) as Node3D
	_check(cage_anchor != null and door_anchor != null, "якоря авторской модели", failures)
	var cage_bottom: float = cage_anchor.global_position.y if cage_anchor != null else 0.0
	var ammo_before_collect := main.rifle.regular_reserve
	var ap_before_collect := main.rifle.ap_reserve
	var received_batches: Array[Dictionary] = []
	lift.delivery_collected.connect(func(contents: Dictionary) -> void: received_batches.append(contents.duplicate(true)))
	lift.advance(lift.ascent_duration * 0.5)
	_check(cage_anchor != null and cage_anchor.global_position.y > cage_bottom + 10.0, "авторская кабина поднимается вместе с заказом (низ=%.2f, середина=%.2f)" % [cage_bottom, cage_anchor.global_position.y if cage_anchor != null else -999.0], failures)
	lift.advance(lift.ascent_duration * 0.5)
	_check(lift.state == SupplyLift.State.ARRIVED and lift._arrival_sfx.playing, "ARRIVED: удар и скрип", failures)
	_check(cage_anchor != null and absf(cage_anchor.position.y - ObservationTower.DECK_HEIGHT - ObservationTower.FLOOR_BELOW_ANCHOR) < 0.01, "центр кабины на расчётной высоте", failures)
	var floor_mesh := main.tower.model.find_child("*LiftFloorPanel*001*", true, false) as MeshInstance3D
	var floor_bottom := INF
	if floor_mesh != null and floor_mesh.mesh != null:
		var bounds := floor_mesh.mesh.get_aabb()
		for corner in range(8):
			floor_bottom = minf(floor_bottom, floor_mesh.to_global(bounds.get_endpoint(corner)).y - main.tower.global_position.y)
	_check(absf(floor_bottom - (ObservationTower.DECK_HEIGHT - 0.05)) < 0.08, "реальный пол кабины совпадает с настилом", failures)
	_check(not is_instance_valid(lift.crate) and lift.status_text() == "ЛИФТ В ПУТИ" and not lift.collect_crate(), "ящика и статуса груза нет до открытия дверцы", failures)
	var interaction := InputEventKey.new()
	interaction.physical_keycode = KEY_E
	interaction.pressed = true
	var ammo_before_interaction := main.rifle.ammo
	main.rifle._input(interaction)
	_check(main.rifle.ammo == ammo_before_interaction and lift.state == SupplyLift.State.ARRIVED, "E во время открытия не стреляет и не принимает груз", failures)
	var readiness: Array[String] = []
	lift.cargo_ready.connect(func() -> void: readiness.append(lift.status_text()))
	var open_seconds := float(SupplyCatalog.SETTINGS["lift_open_seconds"])
	var door_closed: float = door_anchor.global_position.y if door_anchor != null else 0.0
	lift.advance(open_seconds * 0.5)
	_check(door_anchor != null and door_anchor.global_position.y > door_closed + 0.5, "авторская дверца открывается после прибытия", failures)
	_check(not is_instance_valid(lift.crate) and readiness.is_empty(), "на середине анимации ящик ещё не создан", failures)
	lift.advance(open_seconds * 0.49)
	_check(not is_instance_valid(lift.crate), "ящик не появляется до последнего кадра открытия", failures)
	lift.advance(open_seconds * 0.02)
	_check(is_instance_valid(lift.crate) and lift.crate.scene_file_path == "res://scenes/Crate.tscn" and lift.status_text() == "ГРУЗ НА ПЛОЩАДКЕ" and readiness == ["ГРУЗ НА ПЛОЩАДКЕ"], "после полного открытия появляется ящик и обновляется статус", failures)
	await get_tree().physics_frame
	main.player.position = Vector3(-3.0, ObservationTower.DECK_HEIGHT, 3.5)
	main.cam_rig.aim_offset = Vector2.ZERO
	var to_crate := (lift.crate.global_position - (main.player.global_position + Vector3.UP * CameraRig.EYE)).normalized()
	main.cam_rig.set_view(atan2(to_crate.x, to_crate.z), asin(to_crate.y))
	await get_tree().physics_frame
	main.rifle.cycle_remaining = 0.0
	var bullet_before_interaction := main.rifle.ammo
	var origin := main.cam_rig.cam.global_position
	var direction := -main.cam_rig.cam.global_basis.z
	var test_query := PhysicsRayQueryParameters3D.create(origin, origin + direction * float(SupplyCatalog.SETTINGS["crate_reach"]), 4)
	var test_hit := main.cam_rig.cam.get_world_3d().direct_space_state.intersect_ray(test_query)
	_check(test_hit.get("collider") == lift.crate, "луч камеры попадает именно в ящик", failures)
	interaction.echo = true
	main.rifle._input(interaction)
	_check(lift.state == SupplyLift.State.ARRIVED, "повтор удерживаемой E не принимает ящик", failures)
	interaction.echo = false
	Input.parse_input_event(interaction)
	Input.flush_buffered_events()
	await get_tree().process_frame
	_check(lift.state == SupplyLift.State.UNLOADED and main.rifle.regular_reserve == ammo_before_collect + 10 and main.rifle.ap_reserve == ap_before_collect + 3 and main.rifle.ammo == bullet_before_interaction, "E принимает весь заказ одним ящиком без выстрела", failures)
	_check(received_batches == [{"ammo": 2, "ap": 1, "stability": 1}] and lift.is_installed("stability") and (main.rifle._view_model.get_node("Stabilizer") as Node3D).visible, "все позиции применены один раз, улучшение установлено", failures)
	_check("ПАТРОНЫ ×2" in main.rifle.hud._notice and "БРОНЕБОЙНЫЕ ×1" in main.rifle.hud._notice and "СТАБИЛИЗАЦИЯ ×1" in main.rifle.hud._notice, "уведомление перечисляет весь полученный состав", failures)
	main.rifle._input(interaction)
	_check(main.rifle.ammo == bullet_before_interaction and received_batches.size() == 1, "повторная E не стреляет и не выдаёт заказ повторно", failures)
	_check(not lift.collect_crate() and not lift.request_order("ammo"), "ящик нельзя принять дважды, пока лифт не внизу", failures)
	lift.advance(1.0)
	_check(lift.state == SupplyLift.State.DESCENDING and lift._hum.playing, "DESCENDING и гул", failures)
	_check(door_anchor != null and absf(door_anchor.global_position.y - door_closed) < 0.1, "дверца закрылась до спуска", failures)
	var cage_top: float = cage_anchor.global_position.y if cage_anchor != null else 0.0
	lift.advance(float(SupplyCatalog.SETTINGS["lift_descent_seconds"]) * 0.5)
	_check(cage_anchor != null and cage_anchor.global_position.y < cage_top - 10.0, "авторская кабина опускается", failures)
	lift.advance(float(SupplyCatalog.SETTINGS["lift_descent_seconds"]) * 0.5)
	_check(lift.state == SupplyLift.State.IDLE and not lift._hum.playing, "лифт возвращается в IDLE", failures)
	main.radio_tuner.set_tuning(true)
	main.shop.set_open(true)
	main.shop.change_quantity(0, 1)
	Input.parse_input_event(order_enter)
	Input.flush_buffered_events()
	_check(lift.state == SupplyLift.State.CALLED and lift.pending_items == {"ammo": 1}, "Enter оформляет повторный заказ через ввод", failures)
	main.shop.set_open(false)
	main.radio_tuner.set_tuning(false)
	await _deliver_test_item(failures)
	_check(main.rifle.regular_reserve == ammo_before_collect + 15, "вторая пачка прибавлена в резерв", failures)
	# Все улучшения идут через тот же сигнал доставки и один раз.
	main.radio_tuner.live_on_air = true
	main.radio_tuner.set_frequency(94.7)
	main.radio_tuner.update_signal()
	var weak_signal := main.radio_tuner.signal_strength
	var stability_balance := Economy.points
	_check(not lift.request_batch({"ammo": 1, "stability": 1}) and Economy.points == stability_balance, "уже установленное улучшение отклоняет весь заказ без списания", failures)
	for id in ["antenna", "scope", "ap"]:
		_check(lift.request_order(id), "заказ %s" % id, failures)
		await _deliver_test_item(failures)
		_check(not main.rifle.hud._notice.is_empty(), "%s отображает подтверждение получения" % id, failures)
		if id == "antenna":
			_check(main.radio_tuner.antenna_upgrade.visible, "у радио появляется видимая антенна", failures)
		elif id == "stability":
			_check((main.rifle._view_model.get_node("Stabilizer") as Node3D).visible, "стабилизация видна на винтовке", failures)
		elif id == "scope":
			_check((main.rifle._view_model.get_node("ScopeUpgrade") as Node3D).visible, "улучшенная оптика видна на винтовке", failures)
		if SupplyCatalog.item(id)["type"] == "Upgrade":
			var points_before_repeat := Economy.points
			_check(lift.is_installed(id) and not lift.request_order(id) and Economy.points == points_before_repeat, "%s установлен один раз" % id, failures)
	_check(main.radio_tuner.signal_strength > weak_signal and main.radio_tuner._live.max_distance > 18.0, "антенна усиливает и расширяет живой приём", failures)
	_check(is_equal_approx(main.rifle.sway_multiplier, 0.5) and is_equal_approx(main.rifle.zoom_multiplier, 1.5), "стабилизация и оптика меняют параметры винтовки", failures)
	_check(main.rifle.ap_reserve >= 3, "AP добавлены в запас", failures)
	main.rifle.scope_amount = 1.0
	main.rifle.aim_requested = true
	main.rifle._physics_process(0.0)
	_check(main.cam_rig.cam.fov < SniperRifle.SCOPE_FOV, "оптика действительно увеличивает кратность", failures)
	_check(main.rifle.hud._drawing.points == Economy.points and main.rifle.hud._drawing.ammo_type == main.rifle.ammo_type, "HUD показывает кошелёк и тип патрона", failures)
	main.rifle._clock = 1.3
	main.rifle._recoil = 0.0
	main.rifle.sway_multiplier = 1.0
	main.rifle._physics_process(0.0)
	var base_sway := main.cam_rig.aim_offset.length()
	main.rifle.sway_multiplier = 0.5
	main.rifle._physics_process(0.0)
	_check(is_equal_approx(main.cam_rig.aim_offset.length(), base_sway * 0.5), "стабилизация реально уменьшает раскачку", failures)
	# Длинный виртуальный прогон не заменяет ручную игру и измерение FPS.
	for step in range(7200):
		lift.advance(0.1)
		main.game._process(0.1)
		main.radio_tuner.update_signal()
	_check(lift.state == SupplyLift.State.IDLE and Economy.points >= 0 and is_finite(main.game.wind_strength), "720 секунд ускоренной симуляции систем без ошибки", failures)


func _deliver_test_item(failures: Array[String]) -> void:
	var lift := main.lift
	lift.advance(1.0)
	lift.advance(lift.ascent_duration)
	lift.advance(1.0)
	await get_tree().physics_frame
	_check(lift.collect_crate(), "доставка и получение содержимого", failures)
	lift.advance(1.0)
	lift.advance(float(SupplyCatalog.SETTINGS["lift_descent_seconds"]))


func _model_within_rails() -> bool:
	var max_coordinate := ObservationTower.HALF_DECK - 0.10
	for child in main.rifle._view_model.get_children():
		var mesh_part := child as MeshInstance3D
		if mesh_part == null:
			continue
		var bounds := mesh_part.mesh.get_aabb()
		for i in range(8):
			var corner := main.tower.to_local(mesh_part.to_global(bounds.get_endpoint(i)))
			if absf(corner.x) > max_coordinate or absf(corner.z) > max_coordinate:
				return false
	return true


func _check(ok: bool, description: String, failures: Array[String]) -> void:
	if ok:
		print("[SMOKE] PASS ", description)
	else:
		failures.append(description)
		printerr("[SMOKE] FAIL ", description)
