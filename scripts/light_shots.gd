class_name LightShots
extends Node
## Серия кадров освещения мира для CI (TIDE_LIGHT_SHOTS=1).
## Один и тот же набор ракурсов в разное время суток: по ним видно, что
## делает правка света, без получасового рендер-прогона.

const WAIT_FRAMES := 36

var main: BoatMain
var _shooter: TideScreenshot


func setup(owner_main: BoatMain) -> void:
	main = owner_main
	_shooter = TideScreenshot.new()
	add_child(_shooter)
	_run.call_deferred()


func _run() -> void:
	main.debug_night_paused = true
	main.hud.modulate.a = 0.0
	if main.sea_look_trial != null:
		main.sea_look_trial.offset = Vector2(-4000.0, 0.0)
	main._start_in_harbor()
	await _shooter.wait_frames_count(20)

	await _shot("light_01_day_harbor", 12.0, 0.0)
	await _shot("light_02_dusk_harbor", 19.75, 0.0)
	await _shot("light_03_night_harbor", 23.0, 0.0)
	await _shot("light_07_dawn_harbor", 6.0, 0.15)

	_go_to_sea()
	await _shot("light_04_night_sea_clear", 23.0, 0.0)
	await _shot("light_05_night_sea_fog", 23.0, 1.0)
	await _shot("light_08_dusk_sea", 19.75, 0.1)
	await _shot("light_09_day_sea", 12.0, 0.0)

	for i in range(main.refined.size()):
		main.refined[i] = 9
	main.debug_warp_to_beacon()
	main.interact_with_beacon()
	await _shot("light_06_night_beacon", 23.0, 0.35)

	print("[LIGHT SHOTS] готово")
	get_tree().quit(0)


func _go_to_sea() -> void:
	main.harbor.moored = false
	var at := Vector2(-150.0, 0.0)
	for _step in range(40):
		if main.coast.water_depth(at.x, at.y) >= 8.0:
			break
		at.y += 12.0
	var boat := main.boat
	boat.global_position = Vector3(at.x, main.water.surface_height(at.x, at.y) + 0.08, at.y)
	boat.rotation.y = PI * 0.5
	boat.speed = 0.0
	boat._reset_trail(at)
	boat.reset_physics_interpolation()
	main._camera_focus = boat.global_position + Vector3.UP * 0.8
	main.camera.global_position = main._camera_focus + Vector3(21.0, 26.2, 30.0)
	main.camera.look_at(main._camera_focus, Vector3.UP)


func _shot(file_name: String, hour: float, fog: float) -> void:
	main.clock_hours = hour
	main.weather.fog_amount = fog
	main.weather.cloud_amount = 0.1
	main.weather._hold_left = 99999.0
	main.weather._transition_time = 0.0
	main._apply_atmosphere(BoatMain.night_for_hour(hour))
	await _shooter.wait_frames_count(WAIT_FRAMES)
	await _shooter.capture(file_name)
