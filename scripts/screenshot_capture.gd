class_name ScreenshotCapture
extends Node
## Включается только в CI: сохраняет кадр Forward+ после прогрева шейдеров.
func _ready() -> void:
	_capture.call_deferred()


func _capture() -> void:
	for i in range(12):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := OS.get_environment("JOURNEY_SHOT_PATH")
	if path.is_empty():
		path = "user://tower.png"
	var err := image.save_png(path)
	if err != OK:
		printerr("[SHOT] не удалось сохранить: ", err)
		get_tree().quit(1)
		return
	print("[SHOT] сохранён: ", path)
	# Второй кадр — горизонт и мегаструктуры, а не только мишень под ногами.
	var main := get_parent() as MainScene
	main.cam_rig.set_view(PI * 0.5, 0.06)
	for i in range(8):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var landscape := get_viewport().get_texture().get_image()
	var landscape_path := OS.get_environment("JOURNEY_LANDSCAPE_PATH")
	if landscape_path.is_empty():
		landscape_path = "user://landscape.png"
	if landscape.save_png(landscape_path) != OK:
		printerr("[SHOT] не удалось сохранить горизонт")
		get_tree().quit(1)
		return
	print("[SHOT] сохранён: ", landscape_path)
	# Взгляд с самого края, без оптики, для проверки оружия и перил.
	main.player.position = Vector3(ObservationTower.WALK_LIMIT, ObservationTower.DECK_HEIGHT, -1.4)
	main.cam_rig.set_view(PI * 0.5, -0.30)
	main.rifle._physics_process(0.016)
	for i in range(8):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var rail := get_viewport().get_texture().get_image()
	var rail_path := OS.get_environment("JOURNEY_RAIL_PATH")
	if rail_path.is_empty():
		rail_path = "user://rail.png"
	if rail.save_png(rail_path) != OK:
		printerr("[SHOT] не удалось сохранить вид у перил")
		get_tree().quit(1)
		return
	# Временная проверка F2, положения модели и ближнего среза в трёх позах.
	main.player.position = Vector3(0, ObservationTower.DECK_HEIGHT, -1.4)
	main.cam_rig.set_view(PI * 0.5, -0.30)
	main.rifle.set_infinite_ammo(true)
	main.rifle.aim_requested = false
	main.rifle.scope_amount = 0.0
	main.rifle.cycle_remaining = 0.0
	main.rifle._physics_process(0.0)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_spring_diagnostic(main)
	var rest_path := OS.get_environment("JOURNEY_SPRING_REST")
	if not rest_path.is_empty() and get_viewport().get_texture().get_image().save_png(rest_path) != OK:
		get_tree().quit(1)
		return
	if not main.rifle.fire():
		printerr("[SHOT] отладочный выстрел недоступен")
		get_tree().quit(1)
		return
	main.rifle._physics_process(0.0)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var fire_path := OS.get_environment("JOURNEY_SPRING_FIRE")
	if not fire_path.is_empty() and get_viewport().get_texture().get_image().save_png(fire_path) != OK:
		get_tree().quit(1)
		return
	if not main.rifle.start_reload():
		printerr("[SHOT] отладочная перезарядка недоступна")
		get_tree().quit(1)
		return
	main.rifle.reload_remaining = SniperRifle.RELOAD_TIME * 0.5
	main.rifle._physics_process(0.0)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var reload_path := OS.get_environment("JOURNEY_SPRING_RELOAD")
	if not reload_path.is_empty() and get_viewport().get_texture().get_image().save_png(reload_path) != OK:
		get_tree().quit(1)
		return
	main.rifle.set_infinite_ammo(false)
	main.rifle.cycle_remaining = 0.0
	main.rifle._recoil = 0.0
	main.rifle._physics_process(0.0)
	# Небо в оптике — отдельный регрессионный кадр Forward+.
	main.cam_rig.set_view(PI * 0.5, 0.60)
	main.rifle.aim_requested = true
	main.rifle.scope_amount = 1.0
	main.rifle._physics_process(0.016)
	for i in range(8):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var sky_image := get_viewport().get_texture().get_image()
	var sky_path := OS.get_environment("JOURNEY_SKY_PATH")
	if sky_path.is_empty():
		sky_path = "user://sky.png"
	if sky_image.save_png(sky_path) != OK:
		printerr("[SHOT] не удалось сохранить небо")
		get_tree().quit(1)
		return

	# Третий кадр — увеличенная дальняя мишень и маска оптики.
	main.player.position = Vector3(-4.7, ObservationTower.DECK_HEIGHT, -1.4)
	var eye := main.player.global_position + Vector3.UP * CameraRig.EYE
	var target_point := main.long_target.global_position + Vector3.UP * TargetDummy.CENTER_HEIGHT
	var direction := (target_point - eye).normalized()
	main.cam_rig.set_view(atan2(direction.x, direction.z), asin(direction.y))
	main.rifle.aim_requested = true
	main.rifle.scope_amount = 1.0
	main.rifle._physics_process(0.016)
	for i in range(8):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var scope := get_viewport().get_texture().get_image()
	var scope_path := OS.get_environment("JOURNEY_SCOPE_PATH")
	if scope_path.is_empty():
		scope_path = "user://scope.png"
	if scope.save_png(scope_path) != OK:
		printerr("[SHOT] не удалось сохранить оптику")
		get_tree().quit(1)
		return
	print("[SHOT] сохранён: ", scope_path)
	# Временно открыть радио около стола для проверки шкалы.
	main.rifle.aim_requested = false
	main.rifle.scope_amount = 0.0
	main.rifle._physics_process(0.016)
	main.player.position = Vector3(-4.0, ObservationTower.DECK_HEIGHT, -3.9)
	main.cam_rig.set_view(-PI * 0.5, -0.4)
	main.radio_tuner.set_tuning(true)
	main.radio_tuner.set_frequency(88.5)
	for i in range(8):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var radio_image := get_viewport().get_texture().get_image()
	var radio_path := OS.get_environment("JOURNEY_RADIO_PATH")
	if radio_path.is_empty():
		radio_path = "user://radio.png"
	if radio_image.save_png(radio_path) != OK:
		printerr("[SHOT] не удалось сохранить радио")
		get_tree().quit(1)
		return
	# Отдельно проверяем реальный текстовый терминал M5.
	Economy.add_points(1000)
	main.shop.set_open(true)
	# Демонстрируем содержимое корзины и итог в CI-кадре.
	main.shop.change_quantity(0, 2)
	main.shop.change_quantity(1, 1)
	main.shop.change_quantity(2, 1)
	for i in range(8):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var shop_path := OS.get_environment("JOURNEY_SHOP_PATH")
	if shop_path.is_empty():
		shop_path = "user://shop.png"
	if get_viewport().get_texture().get_image().save_png(shop_path) != OK:
		printerr("[SHOT] не удалось сохранить терминал")
		get_tree().quit(1)
		return
	main.shop.cart.clear()
	main.shop.set_open(false)
	main.radio_tuner.set_tuning(false)
	# Ящик на настиле и угол взгляда, с которого его можно принять.
	main.lift.request_order("ammo")
	main.lift.advance(1.0)
	main.lift.advance(main.lift.ascent_duration)
	main.lift.advance(1.0)
	# Крупный план авторской кабины и открытой дверцы после прибытия.
	main.player.position = Vector3(-3.7, ObservationTower.DECK_HEIGHT, 1.5)
	main.cam_rig.aim_offset = Vector2.ZERO
	var lift_target := main.tower.to_global(Vector3(-6.8, ObservationTower.DECK_HEIGHT + 1.3, 3.5))
	var lift_dir := (lift_target - (main.player.global_position + Vector3.UP * CameraRig.EYE)).normalized()
	main.cam_rig.set_view(atan2(lift_dir.x, lift_dir.z), asin(lift_dir.y))
	for i in range(8):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var lift_path := OS.get_environment("JOURNEY_LIFT_PATH")
	if lift_path.is_empty():
		lift_path = "user://lift.png"
	if get_viewport().get_texture().get_image().save_png(lift_path) != OK:
		printerr("[SHOT] не удалось сохранить лифт")
		get_tree().quit(1)
		return
	main.player.position = Vector3(-2.6, ObservationTower.DECK_HEIGHT, 3.5)
	main.cam_rig.aim_offset = Vector2.ZERO
	var crate_dir := (main.lift.crate.global_position - (main.player.global_position + Vector3.UP * CameraRig.EYE)).normalized()
	main.cam_rig.set_view(atan2(crate_dir.x, crate_dir.z), asin(crate_dir.y))
	for i in range(8):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var crate_path := OS.get_environment("JOURNEY_CRATE_PATH")
	if crate_path.is_empty():
		crate_path = "user://crate.png"
	if get_viewport().get_texture().get_image().save_png(crate_path) != OK:
		printerr("[SHOT] не удалось сохранить ящик")
		get_tree().quit(1)
		return
	main.lift.collect_crate()
	# Детерминированный объект только для CI-кадра, не для обычной игры.
	main.radio_tuner.set_tuning(false)
	main.radio_tuner.set_powered(false)
	main.player.position = Vector3(-4.7, ObservationTower.DECK_HEIGHT, -1.4)
	var robot_x := main.tower.global_position.x - 220.0
	var robot_z := main.tower.global_position.z - 1.4
	var robot_pos := Vector3(robot_x, main.coast.ground_height(robot_x, robot_z), robot_z)
	var robot := main.ambient_spawner.spawn_at(AmbientRobot.Kind.SCOUT, robot_pos, 1401)
	robot.speed = 0.0
	var robot_eye := main.player.global_position + Vector3.UP * CameraRig.EYE
	var robot_dir := (robot.global_position + Vector3.UP * robot.body_size.y * 0.5 - robot_eye).normalized()
	main.cam_rig.set_view(atan2(robot_dir.x, robot_dir.z), asin(robot_dir.y))
	main.rifle.aim_requested = true
	main.rifle.scope_amount = 1.0
	main.rifle._physics_process(0.016)
	for i in range(8):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var robot_image := get_viewport().get_texture().get_image()
	var robot_path := OS.get_environment("JOURNEY_ROBOT_PATH")
	if robot_path.is_empty():
		robot_path = "user://robot.png"
	if robot_image.save_png(robot_path) != OK:
		printerr("[SHOT] не удалось сохранить робота")
		get_tree().quit(1)
		return
	robot.queue_free()
	await get_tree().process_frame
	# Проверяем в рендере робота у опоры, а не только далёкий силуэт.
	main.rifle.aim_requested = false
	main.rifle.scope_amount = 0.0
	main.player.position = Vector3(4.7, ObservationTower.DECK_HEIGHT, -1.4)
	var climb_center := main.tower.global_position
	var climb_start := climb_center + Vector3(20.0, 0.0, -1.4)
	climb_start.y = main.coast.ground_height(climb_start.x, climb_start.z)
	var climber := main.ambient_spawner.spawn_at(AmbientRobot.Kind.SCOUT, climb_start, 6311)
	climber.set_physics_process(false)
	climber.respond_to_signal(climb_center, 0)
	for step in range(300):
		climber._physics_process(0.2)
		if climber.climb_state == AmbientRobot.ClimbState.CLIMBING and climber.global_position.y >= climb_center.y + 51.0:
			break
	if climber.climb_state != AmbientRobot.ClimbState.CLIMBING:
		printerr("[SHOT] робот не достиг опоры")
		get_tree().quit(1)
		return
	var climb_eye := main.player.global_position + Vector3.UP * CameraRig.EYE
	var climb_dir := (climber.global_position + Vector3.UP * climber.body_size.y * 0.5 - climb_eye).normalized()
	main.cam_rig.aim_offset = Vector2.ZERO
	main.cam_rig.set_view(atan2(climb_dir.x, climb_dir.z), asin(climb_dir.y))
	main.rifle._physics_process(0.016)
	for i in range(8):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var climb_path := OS.get_environment("JOURNEY_CLIMB_PATH")
	if climb_path.is_empty():
		climb_path = "user://climb.png"
	if get_viewport().get_texture().get_image().save_png(climb_path) != OK:
		printerr("[SHOT] не удалось сохранить подъём")
		get_tree().quit(1)
		return
	climber.queue_free()
	await get_tree().process_frame
	main.debug_menu.set_open(true)
	main.debug_menu.ammo_toggle.button_pressed = true
	for i in range(8):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var debug_path := OS.get_environment("JOURNEY_DEBUG_PATH")
	if debug_path.is_empty():
		debug_path = "user://debug.png"
	if get_viewport().get_texture().get_image().save_png(debug_path) != OK:
		printerr("[SHOT] не удалось сохранить меню отладки")
		get_tree().quit(1)
		return
	main.debug_menu.ammo_toggle.button_pressed = false
	# Три размера рядом с игроком — полезнее, чем силуэт за 200 м.
	main.debug_menu._select_scale()
	for i in range(8):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var scale_path := OS.get_environment("JOURNEY_SCALE_PATH")
	if scale_path.is_empty():
		scale_path = "user://robot_scale.png"
	if get_viewport().get_texture().get_image().save_png(scale_path) != OK:
		printerr("[SHOT] не удалось сохранить сравнение размеров")
		get_tree().quit(1)
		return
	# Отдельные кадры атаки и поражения: без случайного появления.
	main.debug_menu.set_open(true)
	main.debug_menu._select_attack()
	var attack_robot := main.ambient_spawner.get_node_or_null("AttackPreviewRobot") as AmbientRobot
	if attack_robot == null:
		printerr("[SHOT] нет тестового атакующего")
		get_tree().quit(1)
		return
	attack_robot.set_physics_process(false)
	for step in range(100):
		attack_robot._physics_process(0.1)
		if attack_robot.attack_windup > 0.0:
			break
	if attack_robot.attack_windup <= 0.0:
		printerr("[SHOT] робот не начал подготовку удара")
		get_tree().quit(1)
		return
	attack_robot._physics_process(0.8)
	for i in range(8):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var attack_path := OS.get_environment("JOURNEY_ATTACK_PATH")
	if attack_path.is_empty():
		attack_path = "user://attack.png"
	if get_viewport().get_texture().get_image().save_png(attack_path) != OK:
		printerr("[SHOT] не удалось сохранить атаку")
		get_tree().quit(1)
		return
	# Пистолет — отдельный кадр без стрелкового ассета и без демо-робота.
	main.ambient_spawner.set_debug_mode(AmbientSpawner.DebugMode.NORMAL)
	main.rifle.select_weapon(SniperRifle.Weapon.PISTOL)
	main.rifle._physics_process(0.016)
	for i in range(8):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var pistol_path := OS.get_environment("JOURNEY_PISTOL_PATH")
	if pistol_path.is_empty():
		pistol_path = "user://pistol.png"
	if get_viewport().get_texture().get_image().save_png(pistol_path) != OK:
		printerr("[SHOT] не удалось сохранить пистолет")
		get_tree().quit(1)
		return
	# Вид с земли: временная верхняя рейка — цель крюка; затем сам трос.
	var ground_pos := main.tower.global_position + Vector3(42.0, 0.0, 0.0)
	ground_pos.y = main.coast.ground_height(ground_pos.x, ground_pos.z)
	main.player.global_position = ground_pos
	main.player.velocity = Vector3.ZERO
	main.cam_rig.aim_offset = Vector2.ZERO
	main.cam_rig.refresh_pose()
	var top := main.tower.global_position + Vector3(6.6, ObservationTower.DECK_HEIGHT + 3.5, 0.0)
	var hook_dir := (top - main.cam_rig.cam.global_position).normalized()
	main.cam_rig.set_view(atan2(hook_dir.x, hook_dir.z), asin(hook_dir.y))
	for i in range(12):
		await get_tree().physics_frame
	if not main.grapple.try_attach():
		printerr("[SHOT] не удалось зацепить башню с земли")
		get_tree().quit(1)
		return
	for i in range(20):
		await get_tree().physics_frame
	await RenderingServer.frame_post_draw
	var hook_path := OS.get_environment("JOURNEY_HOOK_PATH")
	if hook_path.is_empty():
		hook_path = "user://hook.png"
	if get_viewport().get_texture().get_image().save_png(hook_path) != OK:
		printerr("[SHOT] не удалось сохранить крюк")
		get_tree().quit(1)
		return
	main.grapple.detach()
	# Проверка крепления рамы: вид с настила на одну из четырёх опор.
	main.player.position = Vector3(1.5, ObservationTower.DECK_HEIGHT, 1.5)
	main.player.velocity = Vector3.ZERO
	main.cam_rig.aim_offset = Vector2.ZERO
	main.cam_rig.refresh_pose()
	var frame_target := main.tower.to_global(Vector3(5.95, ObservationTower.DECK_HEIGHT + 1.7, 5.95))
	var frame_dir := (frame_target - main.cam_rig.cam.global_position).normalized()
	main.cam_rig.set_view(atan2(frame_dir.x, frame_dir.z), asin(frame_dir.y))
	for i in range(8):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var frame_path := OS.get_environment("JOURNEY_FRAME_PATH")
	if frame_path.is_empty():
		frame_path = "user://frame.png"
	if get_viewport().get_texture().get_image().save_png(frame_path) != OK:
		printerr("[SHOT] не удалось сохранить крепление рамы")
		get_tree().quit(1)
		return
	main.debug_menu._return_player()
	main.player_health.take_damage(100)
	for i in range(8):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var defeat_path := OS.get_environment("JOURNEY_DEFEAT_PATH")
	if defeat_path.is_empty():
		defeat_path = "user://defeat.png"
	if get_viewport().get_texture().get_image().save_png(defeat_path) != OK:
		printerr("[SHOT] не удалось сохранить поражение")
		get_tree().quit(1)
		return
	get_tree().quit(0)


func _spring_diagnostic(main: MainScene) -> void:
	var skin_mesh := main.rifle._springfield_mesh
	var skin := skin_mesh.skin
	var skel := main.rifle._springfield_skeleton
	print("[SPRING-DIAG] mesh=", skin_mesh.global_transform, " skeleton=", skel.global_transform, " binds=", skin.get_bind_count())
	var rid := skel.find_bone("rifle")
	print("[SPRING-DIAG] rifle bone=", rid, " pose=", skel.get_bone_global_pose(rid))
	for bind_index in range(skin.get_bind_count()):
		if skin.get_bind_bone(bind_index) == rid or String(skin.get_bind_name(bind_index)) == "rifle":
			print("[SPRING-DIAG] rifle bind idx=", bind_index, " bind pose=", skin.get_bind_pose(bind_index))
	var min_depth := INF
	var max_depth := -INF
	var closest_at := -1.0
	var count := 0
	for sample in range(20):
		var elapsed := float(sample) * 0.1
		main.rifle.reload_remaining = SniperRifle.RELOAD_TIME - minf(elapsed, SniperRifle.RELOAD_TIME - 0.001)
		main.rifle._update_springfield_animation()
		for surface in range(skin_mesh.mesh.get_surface_count()):
			var arrays := skin_mesh.mesh.surface_get_arrays(surface)
			var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var joints: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			if positions.is_empty() or joints.is_empty():
				continue
			var influence_count := int(float(joints.size()) / float(positions.size()))
			for vertex_index in range(positions.size()):
				var p := Vector3.ZERO
				var is_rifle := false
				for j in range(influence_count):
					var ix: int = vertex_index * influence_count + j
					var weight: float = weights[ix]
					if weight <= 0.0:
						continue
					var bind_index: int = joints[ix]
					var bone := skin.get_bind_bone(bind_index)
					if bone < 0:
						bone = skel.find_bone(skin.get_bind_name(bind_index))
					if bone < 0:
						continue
					if bone == rid and weight > 0.5:
						is_rifle = true
					p += (skel.get_bone_global_pose(bone) * skin.get_bind_pose(bind_index) * positions[vertex_index]) * weight
				if not is_rifle:
					continue
				var depth := -main.cam_rig.cam.to_local(skel.to_global(p)).z
				if depth < min_depth:
					min_depth = depth
					closest_at = elapsed
				max_depth = maxf(max_depth, depth)
				count += 1
	print("[SPRING-DIAG] rifle sample depth=", min_depth, "..", max_depth, " closest at=", closest_at, " count=", count)
	main.rifle.reload_remaining = 0.0
	main.rifle._update_springfield_animation()
