class_name AmbientSpawner
extends Node3D
## Независимые редкие вероятностные появления, не волны и не расписание.
## Каждый кадр испытание с пуассоновской вероятностью; нулевая длительность
## без встреч ничем не компенсируется и не становится «долгом» системы.
const BASE_INTERVAL := 900.0 # математическое ожидание, НЕ гарантированный срок
const MAX_ACTIVE := 2 # только бюджет объектов, не игровая цель
const MIN_DISTANCE := 220.0
const MAX_DISTANCE := 520.0
var main: MainScene
var rng := RandomNumberGenerator.new()
var preview_robots := false
# Точки относительно башни: все рядом с начальным направлением взгляда.
const PREVIEW_OFFSETS := [Vector2(185.0, -25.0), Vector2(220.0, 0.0), Vector2(260.0, 35.0)]


func setup(main_ref: MainScene) -> void:
	main = main_ref
	rng.randomize()
	preview_robots = bool(ProjectSettings.get_setting("journey/m4/robot_preview", true))
	if preview_robots:
		reset_preview()
		set_process(false) # демонстрация вместо случайного фонового спавна



func _unhandled_input(event: InputEvent) -> void:
	# Явный ручной сброс только в демонстрационном режиме, без таймера/волн.
	if preview_robots and event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F4:
		reset_preview()


func reset_preview() -> void:
	for child in get_children():
		child.queue_free()
	for i in range(PREVIEW_OFFSETS.size()):
		var offset: Vector2 = PREVIEW_OFFSETS[i]
		var x := main.tower.global_position.x + offset.x
		var z := main.tower.global_position.z + offset.y
		var p := Vector3(x, main.coast.ground_height(x, z), z)
		var robot := spawn_at(i as AmbientRobot.Kind, p, 4010 + i)
		# Живые демонстрационные экземпляры остаются до перезапуска/F4.
		robot.preview = true
		robot._choose_destination()


static func chance_for(delta: float, wind_strength: float, night: float, signal_on_air: bool) -> float:
	var world_factor := clampf(1.0 - (wind_strength - 1.0) * 0.22 + night * 0.12, 0.65, 1.3)
	var signal_factor := 1.3 if signal_on_air else 1.0
	# Для интервала dt: P(хотя бы одно событие) = 1 - exp(-lambda * dt).
	return 1.0 - exp(-maxf(delta, 0.0) * world_factor * signal_factor / BASE_INTERVAL)


func _process(delta: float) -> void:
	if main == null:
		return
	var living := 0
	for child in get_children():
		var robot := child as AmbientRobot
		if robot == null:
			continue
		if robot.alive:
			living += 1
		# Не убирать даже мёртвый объект на глазах у игрока.
		var expiry := robot.lifetime if robot.alive else 90.0
		if robot.age >= expiry and not main.cam_rig.cam.is_position_in_frustum(robot.global_position + Vector3.UP * robot.body_size.y * 0.5):
			robot.queue_free()
	if living >= MAX_ACTIVE:
		return
	if rng.randf() >= chance_for(delta, main.game.wind_strength, main.game.night01, main.radio_tuner.live_on_air):
		return
	_try_spawn()


func _try_spawn() -> void:
	var center := main.tower.global_position
	for attempt in range(8):
		var angle := rng.randf_range(0.0, TAU)
		var distance := rng.randf_range(MIN_DISTANCE, MAX_DISTANCE)
		var x := center.x + cos(angle) * distance
		var z := center.z + sin(angle) * distance
		var pos := Vector3(x, main.coast.ground_height(x, z), z)
		var robot_center := pos + Vector3.UP * 3.0
		# Прицел сужает frustum; также запрещаем появления перед камерой
		# в широком секторе обычного обзора, чтобы не возникать на глазах
		# при выходе из оптики. Y игнорируется: это запас по горизонтали.
		var forward := -main.cam_rig.cam.global_basis.z
		var to_candidate := robot_center - main.cam_rig.cam.global_position
		var look_2d := Vector2(forward.x, forward.z).normalized()
		var to_2d := Vector2(to_candidate.x, to_candidate.z).normalized()
		if look_2d.dot(to_2d) > 0.4 or main.cam_rig.cam.is_position_in_frustum(robot_center):
			continue
		if not Ballistics.terrain_hit(main.coast, main.cam_rig.cam.global_position, robot_center, 8.0).is_empty():
			continue
		spawn_at(rng.randi_range(0, 2) as AmbientRobot.Kind, pos, rng.randi())
		return


## Отдельный метод также позволяет детерминированно проверять физику в CI,
## не ожидая случайную встречу в реальном времени.
func spawn_at(robot_kind: AmbientRobot.Kind, at: Vector3, seed_value: int) -> AmbientRobot:
	var robot := AmbientRobot.new()
	robot.name = "WanderingRobot"
	add_child(robot)
	robot.setup(robot_kind, main.coast, at, seed_value)
	return robot
