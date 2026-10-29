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
	get_tree().quit(0)
