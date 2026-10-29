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
	get_tree().quit(0)
