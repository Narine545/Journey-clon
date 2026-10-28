class_name SmokeTest
extends Node
## Headless-проверка M0. Отдельно требуется проверка настоящего Vulkan-рендера.
var main: MainScene


func setup(main_ref: MainScene) -> void:
	main = main_ref
	_run.call_deferred()


func _run() -> void:
	await get_tree().physics_frame
	var failures: Array[String] = []
	_check(main.coast.mesh != null, "сетка рельефа", failures)
	_check(main.sand.get_texture() != null, "поле физического песка", failures)
	_check(main.world != null and main.cam_rig.cam.current, "мир и активная камера", failures)
	_check(main.audio != null, "процедурный звук", failures)
	_check(main.audio._step_streams.size() == 6, "синтез шагов", failures)
	_check(main.audio._wind.stream != null and main.audio._wind.playing, "петля ветра", failures)
	var origin := main.player.global_position
	var yaw: float = main.cam_rig.yaw
	main.cam_rig.apply_mouse_motion(Vector2(50.0, 0.0))
	_check(not is_equal_approx(main.cam_rig.yaw, yaw), "поворот камеры", failures)
	for action in ["move_forward", "move_back", "move_left", "move_right", "jump"]:
		_check(not InputMap.has_action(action), "нет ввода %s" % action, failures)
	var key := InputEventKey.new()
	key.physical_keycode = KEY_W
	key.pressed = true
	Input.parse_input_event(key)
	for i in range(5):
		await get_tree().physics_frame
	key.pressed = false
	Input.parse_input_event(key)
	_check(main.player.global_position.is_equal_approx(origin), "W не перемещает якорь", failures)
	var sand_pos := Vector2(origin.x, origin.z)
	main.sand.stamp_foot(sand_pos, Vector2.RIGHT, 0.5, 0.3, 0.1, 0.02)
	_check(main.sand.disp_at(origin.x, origin.z) < -0.001, "песок реагирует на отпечаток", failures)
	main.set_time(1.0)
	_check(is_equal_approx(main.game.night01, 1.0), "смена времени", failures)
	main.set_time(0.0)
	_check(main.get_node_or_null("ViewAnchor") != null, "временный якорь", failures)
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
