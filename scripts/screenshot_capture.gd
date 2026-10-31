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
	for step in range(120):
		climber._physics_process(0.5)
		if climber.climb_state == AmbientRobot.ClimbState.CLIMBING and climber.global_position.y >= climb_center.y + 43.0:
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
	get_tree().quit(0)
