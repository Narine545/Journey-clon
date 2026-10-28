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
	var encoded := Marshalls.raw_to_base64(image.save_jpg_to_buffer(0.45))
	var chunk := 0
	for offset in range(0, encoded.length(), 3000):
		print("[SHOT_PREVIEW_%d]%s" % [chunk, encoded.substr(offset, 3000)])
		chunk += 1
	get_tree().quit(0)
