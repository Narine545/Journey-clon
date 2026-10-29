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
	# Луч к мишени пересекает перила между двумя поручнями, не через настил.
	var rail_t: float = (main.tower.global_position.x + 5.95 - eye.x) / (target_center.x - eye.x)
	var rail_height: float = eye.lerp(target_center, rail_t).y - main.tower.global_position.y - ObservationTower.DECK_HEIGHT
	_check(rail_height > 0.55 and rail_height < 1.17, "мишень между поручнями", failures)
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
	if failures.is_empty():
		print("[SMOKE] итог: ВСЁ ПРОШЛО")
		get_tree().quit(0)
	else:
		printerr("[SMOKE] итог: ошибки: ", failures)
		get_tree().quit(1)


func _check(ok: bool, description: String, failures: Array[String]) -> void:
	if ok:
		print("[SMOKE] PASS ", description)
	else:
		failures.append(description)
		printerr("[SMOKE] FAIL ", description)
