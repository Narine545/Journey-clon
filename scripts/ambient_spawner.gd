class_name AmbientSpawner
extends Node3D
## Вне маяка — независимые редкие вероятностные встречи.
## Передача постепенно увеличивает отклик, после выключения он затихает.
## Это не расписание волн: новые роботы получают индивидуальные задержки.
const BASE_INTERVAL := 900.0 # математическое ожидание, НЕ гарантированный срок
const MAX_ACTIVE := 2 # лимит редких фоновых встреч
const MAX_SIGNAL_ACTIVE := 8 # общий предохранитель и при полной угрозе
const THREAT_RISE_SECONDS := 480.0
const THREAT_FADE_SECONDS := 240.0
const MIN_DISTANCE := 220.0
const MAX_DISTANCE := 520.0
const CALL_DELAY_MIN := 10.0
const CALL_DELAY_MAX := 40.0
const SPAWN_RETRY_SECONDS := 2.0
var main: MainScene
var rng := RandomNumberGenerator.new()
var preview_robots := false
# Каждый свободный слот имеет собственную задержку; -1 означает незапущенный.
var call_delays: Array[float] = [-1.0, -1.0, -1.0, -1.0, -1.0, -1.0, -1.0, -1.0]
var threat := 0.0 # 0..1: растёт только при передаче, затем плавно спадает
# Точки относительно башни: все рядом с начальным направлением взгляда.
const PREVIEW_OFFSETS := [Vector2(185.0, -25.0), Vector2(220.0, 0.0), Vector2(260.0, 35.0)]


func setup(main_ref: MainScene) -> void:
	main = main_ref
	rng.randomize()
	preview_robots = bool(ProjectSettings.get_setting("journey/m4/robot_preview", false))
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
		if (not robot.alive or (not robot.signal_called and not main.radio_tuner.transmitting)) and not robot.approaching_signal and robot.age >= expiry and not main.cam_rig.cam.is_position_in_frustum(robot.global_position + Vector3.UP * robot.body_size.y * 0.5):
			robot.queue_free()
	advance_signal(delta, living)
	# Пока есть отклик маяка, фон не добавляет отдельные вызовы.
	if living >= MAX_ACTIVE or main.radio_tuner.transmitting or threat > 0.0:
		return
	if rng.randf() >= chance_for(delta, main.game.wind_strength, main.game.night01, main.radio_tuner.live_on_air):
		return
	_try_spawn()


## При нулевом остатке запланированных откликов больше нет. При выключении
## маяка раньше этого они постепенно редеют, как уже переданный сигнал.
func cancel_signal() -> void:
	if threat <= 0.0:
		_clear_call_delays()


func _clear_call_delays() -> void:
	for slot in range(call_delays.size()):
		call_delays[slot] = -1.0


static func threat_after(value: float, transmitting: bool, delta: float) -> float:
	# Линейное нарастание/затухание не зависит от частоты кадров.
	return move_toward(clampf(value, 0.0, 1.0), 1.0 if transmitting else 0.0, maxf(delta, 0.0) / (THREAT_RISE_SECONDS if transmitting else THREAT_FADE_SECONDS))


static func capacity_for(value: float) -> int:
	# Плавный уровень превращается в целый бюджет без удаления лишних роботов.
	return MAX_ACTIVE + floori(clampf(value, 0.0, 1.0) * float(MAX_SIGNAL_ACTIVE - MAX_ACTIVE))


static func delay_range_for(value: float) -> Vector2:
	var pressure := clampf(value, 0.0, 1.0)
	return Vector2(lerpf(CALL_DELAY_MIN, 4.0, pressure), lerpf(CALL_DELAY_MAX, 15.0, pressure))


func advance_signal(delta: float, living: int) -> void:
	var transmitting := main.radio_tuner.transmitting
	# Время передатчика, а не возраст всей игровой сессии; границы 0..1.
	var elapsed := maxf(delta, 0.0)
	threat = threat_after(threat, transmitting, elapsed)
	if not transmitting and threat <= 0.0:
		_clear_call_delays()
		return
	var capacity := capacity_for(threat)
	var occupied: Array[bool] = []
	occupied.resize(MAX_SIGNAL_ACTIVE)
	occupied.fill(false)
	for child in get_children():
		var robot := child as AmbientRobot
		if robot == null or not robot.alive:
			continue
		# Случайный робот реагирует на текущую передачу, а не на её остаток.
		if transmitting and not robot.signal_called:
			robot.respond_to_signal(main.tower.global_position, -1)
		if robot.call_slot >= 0 and robot.call_slot < MAX_SIGNAL_ACTIVE:
			occupied[robot.call_slot] = true
	var delay_range := delay_range_for(threat)
	for slot in range(MAX_SIGNAL_ACTIVE):
		if slot >= capacity or occupied[slot]:
			call_delays[slot] = -1.0
			continue
		if call_delays[slot] < 0.0:
			call_delays[slot] = rng.randf_range(delay_range.x, delay_range.y)
		else:
			call_delays[slot] = maxf(0.0, call_delays[slot] - elapsed)
		# Один ожидающий отклик на слот, без бесконечного долга при лимите.
		if call_delays[slot] <= 0.0 and living < capacity:
			var called := _try_spawn(slot)
			if called != null:
				living += 1
				call_delays[slot] = -1.0
			else:
				# Не выполнять десятки проверок рельефа каждый кадр, если
				# вокруг камеры пока не нашлось допустимого места.
				call_delays[slot] = SPAWN_RETRY_SECONDS


func _try_spawn(call_slot: int = -1) -> AmbientRobot:
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
		var robot_kind := rng.randi_range(0, 2) as AmbientRobot.Kind
		if call_slot >= 0:
			# С усилением отклика чаще приходят разведчики; бронированные не исчезают.
			var kind_roll := rng.randf()
			var scout_share := lerpf(1.0 / 3.0, 0.55, threat)
			var carrier_share := lerpf(1.0 / 3.0, 0.15, threat)
			robot_kind = AmbientRobot.Kind.SCOUT if kind_roll < scout_share else (AmbientRobot.Kind.CARRIER if kind_roll < scout_share + carrier_share else AmbientRobot.Kind.WALKER)
		var robot := spawn_at(robot_kind, pos, rng.randi())
		if call_slot >= 0:
			robot.configure_signal_speed(threat, rng.randf())
			robot.respond_to_signal(center, call_slot)
		return robot
	return null


## Отдельный метод также позволяет детерминированно проверять физику в CI,
## не ожидая случайную встречу в реальном времени.
func spawn_at(robot_kind: AmbientRobot.Kind, at: Vector3, seed_value: int) -> AmbientRobot:
	var robot := AmbientRobot.new()
	robot.name = "WanderingRobot"
	add_child(robot)
	robot.setup(robot_kind, main.coast, at, seed_value)
	return robot
