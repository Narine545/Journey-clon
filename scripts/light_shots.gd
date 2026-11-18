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
	main.camera.size = 96.0
	await _shot("light_11_day_sea_wide", 12.0, 0.0)
	main.camera.size = 32.0

	for i in range(main.refined.size()):
		main.refined[i] = 9
	main.debug_warp_to_beacon()
	main.interact_with_beacon()
	await _shot("light_06_night_beacon", 23.0, 0.35)
	# Общий план: буй, башня маяка и песок вокруг неё.
	main.camera.size = 84.0
	await _shot("light_10_night_beacon_wide", 23.0, 0.0)

	# Сфера-вход: погружение перед взлётом — всплеск, кольца и свет из-под воды.
	_night_atmosphere(0.0)
	_camera_on_gate()
	await _shooter.wait_frames_count(20)
	main.camera.size = 26.0
	main.raid_gate.enter()
	# Сфера уже под водой: пятно света сквозь толщу и всплеск на поверхности.
	await _shooter.wait_frames_count(21)
	await _shooter.capture("light_12_orb_dive")
	# Сфера вырывается обратно — второй всплеск.
	await _shooter.wait_frames_count(9)
	await _shooter.capture("light_13_orb_out")

	# Ходячие ноги: временный бонус рейда, шаг по воде.
	_go_to_sea()
	main.clock_hours = 12.0
	main.weather.fog_amount = 0.0
	main.weather.cloud_amount = 0.1
	main._apply_atmosphere(BoatMain.night_for_hour(12.0))
	main.camera.size = 22.0
	await _shooter.wait_frames_count(12)
	main.raid.hud.modulate.a = 0.0
	main.raid.start()
	main.raid.legs_rank = 1
	Input.action_press("boat_forward")
	await _shooter.wait_frames_count(10)
	main.raid.start_legs()
	# Первые кадры появления: ноги не должны тянуться за край экрана.
	await _shooter.wait_frames_count(2)
	await _shooter.capture("light_15_legs_appear_00")
	await _shooter.wait_frames_count(5)
	await _shooter.capture("light_15_legs_appear_01")
	await _shooter.wait_frames_count(9)
	await _shooter.capture("light_15_legs_appear_02")
	await _shooter.wait_frames_count(20)
	await _shooter.capture("light_14_legs_00")
	await _shooter.wait_frames_count(7)
	await _shooter.capture("light_14_legs_01")
	await _shooter.wait_frames_count(7)
	await _shooter.capture("light_14_legs_02")
	# Последний кадр — с интерфейсом рейда: видно плашку бонуса.
	main.raid.hud.modulate.a = 1.0
	await _shooter.wait_frames_count(6)
	await _shooter.capture("light_14_legs_03")
	Input.action_release("boat_forward")

	# Хватающие руки: рука сама тянется к врагу и швыряет его во второго.
	main.raid.enemies.clear()
	main.raid.hands_rank = 1
	main.raid.hands.set_active(true)
	main.raid.hands_cooldown = 0.0
	var bow: Vector2 = main.raid.forward()
	var base: Vector2 = main.raid.boat_at() + bow * 6.5
	main.raid.enemies.append(_dummy_enemy(base, 100.0, 901))
	main.raid.enemies.append(_dummy_enemy(base + bow.orthogonal() * 4.5, 100.0, 902))
	main.raid._rebuild_grid()
	# Руки успевают подняться из воды — только потом тянутся к врагу.
	await _shooter.wait_frames_count(24)
	await _shooter.capture("light_16_hands_00")
	main.raid._hands_grab()
	await _shooter.wait_frames_count(5)
	await _shooter.capture("light_16_hands_01")
	await _shooter.wait_frames_count(7)
	await _shooter.capture("light_16_hands_02")
	await _shooter.wait_frames_count(10)
	main.raid.hud.modulate.a = 1.0
	await _shooter.capture("light_16_hands_03")
	main.raid.enemies.clear()

	# Пинок ноги: нога должна прийти в врага, а враг — отлететь.
	# Руки на это время убираем, иначе они перехватят цель первыми.
	main.raid.hud.modulate.a = 0.0
	main.raid.hands_rank = 0
	main.raid.hands.set_active(false)
	var kick_at: Vector2 = main.raid.boat_at() + bow.rotated(0.35) * 7.5
	main.raid.enemies.append(_dummy_enemy(kick_at, 160.0, 903))
	main.raid._rebuild_grid()
	await _shooter.wait_frames_count(6)
	await _shooter.capture("light_17_kick_00")
	main.raid._legs_kick()
	await _shooter.wait_frames_count(3)
	await _shooter.capture("light_17_kick_01")
	await _shooter.wait_frames_count(5)
	await _shooter.capture("light_17_kick_02")
	await _shooter.wait_frames_count(10)
	await _shooter.capture("light_17_kick_03")
	main.raid.enemies.clear()

	print("[LIGHT SHOTS] готово")
	get_tree().quit(0)


## Пустой враг для кадра: только то, что нужно отрисовке и движению.
func _dummy_enemy(at: Vector2, hp: float, combat_id: int) -> Dictionary:
	return {
		"at": at,
		"previous": at,
		"hp": hp,
		"max_hp": hp,
		"radius": 1.1,
		"kind": 0,
		"born": 0.0,
		"flash": 0.0,
		"timer": 2.0,
		"charge": 0.0,
		"aim": Vector2.DOWN,
		"combat_id": combat_id,
	}


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


## Ночная атмосфера без тумана: нужна для кадров со сферой.
func _night_atmosphere(cloud: float) -> void:
	main.clock_hours = 23.0
	main.weather.fog_amount = 0.0
	main.weather.cloud_amount = cloud
	main.weather._hold_left = 99999.0
	main.weather._transition_time = 0.0
	main._apply_atmosphere(BoatMain.night_for_hour(23.0))


## Лодка рядом со сферой, камера — на неё: видно погружение и отклик воды.
func _camera_on_gate() -> void:
	var gate := main.raid_gate
	var spot := gate.at() + Vector2(16.0, 0.0)
	main.harbor.moored = false
	var boat := main.boat
	boat.global_position = Vector3(spot.x, main.water.surface_height(spot.x, spot.y) + 0.08, spot.y)
	boat.rotation.y = PI * 0.5
	boat.speed = 0.0
	boat._reset_trail(spot)
	boat.reset_physics_interpolation()
	var focus := gate.at()
	main._camera_focus = Vector3(focus.x, main.water.surface_height(focus.x, focus.y) + 2.0, focus.y)
	main.camera.size = 26.0
	main.camera.global_position = main._camera_focus + Vector3(13.0, 16.0, 19.0)
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
