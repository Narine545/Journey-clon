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
	# Маленькое JPEG-превью доступно в аннотациях CI даже без доступа к артефактам.
	image.resize(320, 180, Image.INTERPOLATE_LANCZOS)
	print("[SHOT_PREVIEW]", Marshalls.raw_to_base64(image.save_jpg_to_buffer(0.45)))
	get_tree().quit(0)
