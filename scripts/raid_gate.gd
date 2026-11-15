class_name RaidGate
extends Node3D
## Сфера из другого мира: случайная точка в океане, где начинается рейд.
## Подойти на RANGE метров и нажать E. После рейда сфера гаснет и всплывает
## в новом месте; за победу в рейде в трюм ложится артефакт.

const RANGE := 18.0
const MIN_DEPTH := 8.0
## Открытый океан к западу от острова (карта Coast: x −280…620, край 64 м).
const AREA := Rect2(-208.0, -330.0, 96.0, 660.0)
const FALLBACK := Vector2(-185.0, 95.0)

var main: BoatMain
var artifacts := 0
var _model: Node3D
var _light: OmniLight3D
var _time := 0.0
var _was_engaged := false
var _won := false
var _rng := RandomNumberGenerator.new()


func setup(scene: BoatMain) -> void:
	main = scene
	_rng.randomize()
	_model = ArtifactModel.build(ArtifactModel.ORB, 4.2)
	add_child(_model)
	_light = OmniLight3D.new()
	_light.light_color = Color("35d0ba")
	_light.light_energy = 3.0
	_light.omni_range = 22.0
	_light.position = Vector3(0.0, 3.0, 0.0)
	add_child(_light)
	relocate()


func at() -> Vector2:
	return Vector2(position.x, position.z)


func distance() -> float:
	if main == null or main.boat == null:
		return INF
	return at().distance_to(Vector2(main.boat.global_position.x, main.boat.global_position.z))


func in_range() -> bool:
	return visible and distance() <= RANGE


## Новое случайное место: глубокая вода вокруг, не у старта и не у буёв.
func relocate() -> void:
	var spot := FALLBACK
	var avoid := Vector2(IslandLayout.BOAT_START)
	if main != null and main.boat != null and _was_engaged:
		avoid = Vector2(main.boat.global_position.x, main.boat.global_position.z)
	for attempt in range(60):
		var candidate := Vector2(
			_rng.randf_range(AREA.position.x, AREA.end.x), _rng.randf_range(AREA.position.y, AREA.end.y)
		)
		if candidate.distance_to(avoid) < 90.0:
			continue
		if _clear(candidate):
			spot = candidate
			break
	position = Vector3(spot.x, 0.0, spot.y)


func _clear(spot: Vector2) -> bool:
	if main == null or main.coast == null:
		return true
	for offset: Vector2 in [Vector2.ZERO, Vector2(14, 0), Vector2(-14, 0), Vector2(0, 14), Vector2(0, -14)]:
		if main.coast.water_depth(spot.x + offset.x, spot.y + offset.y) < MIN_DEPTH:
			return false
	for beacon in main.beacons:
		var buoy: Vector3 = beacon["buoy_pos"]
		if spot.distance_to(Vector2(buoy.x, buoy.z)) < 45.0:
			return false
	return true


## Войти в рейд. Возвращает true, если рейд начался.
func enter() -> bool:
	if main == null or main.raid == null or main.raid.engaged() or not in_range():
		return false
	main.raid.start()
	return main.raid.engaged()


func _process(delta: float) -> void:
	_time += delta
	if main == null or main.raid == null:
		return
	var engaged := main.raid.engaged()
	if engaged and main.raid.state == RaidRun.State.WON:
		_won = true
	if _was_engaged and not engaged:
		# Рейд закончен: сфера гаснет здесь и всплывает в другом месте.
		if _won:
			artifacts += 1
			main.announce("АРТЕФАКТ ИЗ ДРУГОГО МИРА — В ТРЮМЕ. СФЕРА ВСПЛЫЛА В НОВОМ МЕСТЕ.")
		else:
			main.announce("СФЕРА ПОГАСЛА И ВСПЛЫЛА В НОВОМ МЕСТЕ. СЛЕД — НА КОМПАСЕ.")
		_won = false
		relocate()
	if engaged and not _was_engaged:
		_won = false
	_was_engaged = engaged
	visible = not engaged
	if not visible:
		return
	# Парит над водой, медленно вращается и «дышит» светом.
	_model.position.y = 3.2 + 0.55 * sin(_time * 1.3)
	_model.rotation.y = _time * 0.6
	_model.rotation.x = 0.18 * sin(_time * 0.7)
	_light.light_energy = 2.6 + 1.2 * sin(_time * 2.1)
