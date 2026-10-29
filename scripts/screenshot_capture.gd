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
	get_tree().quit(0)
