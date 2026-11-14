class_name TideScreenshot
extends Node
## Скриншот-скрипт: ждёт N кадров и сохраняет PNG в shots/<имя_экрана>.png.
## Требует настоящего рендера (xvfb + Vulkan/OpenGL); в headless картинка
## пустая, и скрипт об этом честно предупреждает, а не делает вид.

@export var screen_name := "screen"
@export var wait_frames := 30
@export var quit_after := false


static func shots_dir() -> String:
	var from_env := OS.get_environment("TIDE_SHOT_DIR")
	if not from_env.is_empty():
		return from_env
	return ProjectSettings.globalize_path("res://shots")


func wait_frames_count(count: int) -> void:
	for _index in range(maxi(1, count)):
		await get_tree().process_frame


## Сохранить текущий кадр. Имя файла — без .png.
func capture(file_name: String = "") -> String:
	var name := file_name if not file_name.is_empty() else screen_name
	await RenderingServer.frame_post_draw
	var directory := shots_dir()
	DirAccess.make_dir_recursive_absolute(directory)
	var path := directory.path_join("%s.png" % name)
	var image := get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		push_warning("[TIDE SHOT] пустой кадр: похоже, рендер headless")
		return ""
	var error := image.save_png(path)
	if error != OK:
		push_warning("[TIDE SHOT] не удалось сохранить %s (%d)" % [path, error])
		return ""
	print("[TIDE SHOT] %s %dx%d" % [path, image.get_width(), image.get_height()])
	return path


func _ready() -> void:
	if not OS.has_environment("TIDE_SHOT"):
		return
	await wait_frames_count(wait_frames)
	await capture()
	if quit_after:
		get_tree().quit(0)
