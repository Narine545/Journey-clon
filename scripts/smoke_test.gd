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
	_check(main.player.get_parent() == main.tower, "игрок на башне", failures)
	_check(is_equal_approx(main.player.position.y, ObservationTower.DECK_HEIGHT), "высота площадки", failures)
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
	_check(not InputMap.has_action("jump"), "спрыгнуть нельзя", failures)
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
	await get_tree().physics_frame
	_check(main.cam_rig.cam.global_position.is_equal_approx(main.player.global_position + Vector3.UP * CameraRig.EYE),
			"камера следует за игроком", failures)

	# На каждой стороне и по диагонали даже большой шаг не может пересечь перила.
	for direction in [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK, Vector3(1, 8, 1), Vector3(-1, -8, -1)]:
		main.player.position = Vector3(0, ObservationTower.DECK_HEIGHT, 0)
		main.player.move_on_deck(direction * 1000.0)
		var p := main.player.position
		_check(absf(p.x) <= ObservationTower.WALK_LIMIT and absf(p.z) <= ObservationTower.WALK_LIMIT
				and is_equal_approx(p.y, ObservationTower.DECK_HEIGHT), "граница площадки %s" % direction, failures)
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
	main.player.position = Vector3(-4.0, ObservationTower.DECK_HEIGHT, -3.9)
	_check(radio.nearby(), "к радио можно подойти", failures)
	var radio_key := InputEventKey.new()
	radio_key.physical_keycode = KEY_R
	radio_key.pressed = true
	radio._input(radio_key)
	_check(radio.tuning and radio.powered, "R открывает и включает приёмник", failures)
	var player_before_radio := main.player.position
	Input.action_press("move_forward")
	main.player._physics_process(1.0)
	Input.action_release("move_forward")
	_check(main.player.position == player_before_radio, "при настройке ходьба отключена", failures)
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
	radio.set_powered(false)
	_check(not radio.powered and not radio._record.playing and not radio._live.playing and not radio._noise.playing, "питание выключает записи, шум и сигнал", failures)
	radio.set_tuning(false)
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
	_check(robots[0].global_position.distance_to(robot_start) > 0.05 and absf(robots[0].global_position.y - main.coast.ground_height(robots[0].global_position.x, robots[0].global_position.z)) < 0.01, "робот медленно движется по рельефу", failures)
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
	main.rifle.switch_ammo()
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
	await _test_m5(failures)

	if failures.is_empty():
		print("[SMOKE] итог: ВСЁ ПРОШЛО")
		get_tree().quit(0)
	else:
		printerr("[SMOKE] итог: ошибки: ", failures)
		get_tree().quit(1)


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
	# Радио открывает терминал; пока он открыт, оружие/ходьба блокируются.
	main.player.position = Vector3(-4.0, ObservationTower.DECK_HEIGHT, -3.9)
	main.radio_tuner.set_tuning(true)
	var open_key := InputEventKey.new()
	open_key.physical_keycode = KEY_B
	open_key.pressed = true
	main.radio_tuner._input(open_key)
	_check(main.shop.is_open and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "B на радио открывает терминал и курсор", failures)
	var before_ammo := main.rifle.ammo
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	main.rifle._input(click)
	_check(main.rifle.ammo == before_ammo, "в терминале клик не стреляет", failures)
	Economy.add_points(5000)
	var before_order := Economy.points
	var orders_during_signal: Array[bool] = []
	var reentrant := func(_value: int, _delta: int) -> void: orders_during_signal.append(lift.request_order("ammo"))
	Economy.points_changed.connect(reentrant, CONNECT_ONE_SHOT)
	main.shop.selected = 0
	_check(main.shop.attempt_selected(), "заказ патронов через терминал", failures)
	_check(orders_during_signal == [false] and not main.shop.attempt_selected() and Economy.points == before_order - 150, "повторный и reentrant-заказ не списывает второй раз", failures)
	_check(lift.state == SupplyLift.State.CALLED and lift._start_sfx.playing, "CALLED и лязг старта", failures)
	_check(lift.ascent_duration >= 30.0 and lift.ascent_duration <= 60.0 and lift.status_text() == "ЛИФТ В ПУТИ", "длительность 45±15 и только статус без обратного отсчёта", failures)
	main.shop.set_open(false)
	main.radio_tuner.set_tuning(false)
	lift.advance(1.0)
	_check(lift.state == SupplyLift.State.ASCENDING and lift._hum.playing, "ASCENDING и гул троса", failures)
	var ammo_before_collect := main.rifle.regular_reserve
	lift.advance(lift.ascent_duration)
	_check(lift.state == SupplyLift.State.ARRIVED and lift._arrival_sfx.playing and is_instance_valid(lift.crate), "ARRIVED: удар, скрип и ящик", failures)
	_check(lift.crate.scene_file_path == "res://scenes/Crate.tscn" and lift.status_text() == "ГРУЗ НА ПЛОЩАДКЕ", "ящик и статус груза", failures)
	await get_tree().physics_frame
	main.player.position = Vector3(-3.0, ObservationTower.DECK_HEIGHT, 3.5)
	main.cam_rig.aim_offset = Vector2.ZERO
	var to_crate := (lift.crate.global_position - (main.player.global_position + Vector3.UP * CameraRig.EYE)).normalized()
	main.cam_rig.set_view(atan2(to_crate.x, to_crate.z), asin(to_crate.y))
	await get_tree().physics_frame
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	main.rifle.cycle_remaining = 0.0
	var bullet_before_click := main.rifle.ammo
	var origin := main.cam_rig.cam.global_position
	var direction := -main.cam_rig.cam.global_basis.z
	var test_query := PhysicsRayQueryParameters3D.create(origin, origin + direction * float(SupplyCatalog.SETTINGS["crate_reach"]), 4)
	var test_hit := main.cam_rig.cam.get_world_3d().direct_space_state.intersect_ray(test_query)
	main.rifle._input(click)
	_check(lift.state == SupplyLift.State.UNLOADED and main.rifle.regular_reserve == ammo_before_collect + 5 and main.rifle.ammo == bullet_before_click, "настоящий луч камеры принимает ящик без выстрела (state=%d, mouse=%d, hit=%s, direction=%s)" % [lift.state, Input.mouse_mode, str(test_hit.get("collider")), str(direction)], failures)
	_check(not lift.collect_crate() and not lift.request_order("ammo"), "ящик нельзя принять дважды, пока лифт не внизу", failures)
	lift.advance(1.0)
	_check(lift.state == SupplyLift.State.DESCENDING and lift._hum.playing, "DESCENDING и гул", failures)
	lift.advance(float(SupplyCatalog.SETTINGS["lift_descent_seconds"]))
	_check(lift.state == SupplyLift.State.IDLE and not lift._hum.playing, "лифт возвращается в IDLE", failures)
	_check(lift.request_order("ammo"), "расходники можно заказывать повторно", failures)
	await _deliver_test_item(failures)
	_check(main.rifle.regular_reserve == ammo_before_collect + 10, "вторая пачка прибавлена в резерв", failures)
	# Все улучшения идут через тот же сигнал доставки и один раз.
	main.radio_tuner.live_on_air = true
	main.radio_tuner.set_frequency(94.7)
	main.radio_tuner.update_signal()
	var weak_signal := main.radio_tuner.signal_strength
	for id in ["antenna", "stability", "scope", "ap"]:
		_check(lift.request_order(id), "заказ %s" % id, failures)
		await _deliver_test_item(failures)
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
