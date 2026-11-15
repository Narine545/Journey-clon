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
## Номера уже найденных вещей (см. ArtifactModel.ITEMS).
var found: Array[int] = []
var _pending := -1
var _last_state := RaidRun.State.IDLE
var _launching := false
var _lift := 0.0
var _shrink := 1.0
var _spin := 0.0
var _flare := 0.0
var _fly: Tween
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
	# У модели сферы своя анимация вращения колец — крутим её по кругу.
	var player := _model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if player != null:
		for clip in player.get_animation_list():
			if clip == "RESET":
				continue
			player.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
			player.play(clip)
			break
	relocate()


func at() -> Vector2:
	return Vector2(position.x, position.z)


func distance() -> float:
	if main == null or main.boat == null:
		return INF
	return at().distance_to(Vector2(main.boat.global_position.x, main.boat.global_position.z))


func in_range() -> bool:
	return visible and not _launching and distance() <= RANGE


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
	# Сфера приседает, раскручивается и уходит свечой в небо; рейд начинается,
	# когда она скрылась.
	_launching = true
	if _fly != null and _fly.is_valid():
		_fly.kill()
	_fly = create_tween()
	_fly.set_parallel(true)
	_fly.tween_property(self, "_lift", 90.0, 1.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	_fly.tween_property(self, "_shrink", 0.12, 1.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_fly.tween_property(self, "_spin", 26.0, 1.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_fly.tween_property(self, "_flare", 9.0, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_fly.chain().tween_callback(_launched)
	main.announce("СФЕРА ОТКЛИКНУЛАСЬ. ДЕРЖИТЕСЬ.")
	return true


func _launched() -> void:
	_launching = false
	_flare = 0.0
	main.raid.start()
	if not main.raid.engaged():
		# Рейд не начался (например, лодку унесло на мель): сфера возвращается.
		_arrive()


## Сфера опускается с неба на новое место.
func _arrive() -> void:
	if _fly != null and _fly.is_valid():
		_fly.kill()
	_lift = 90.0
	_shrink = 0.12
	_spin = 0.0
	_flare = 0.0
	_fly = create_tween()
	_fly.set_parallel(true)
	_fly.tween_property(self, "_lift", 0.0, 1.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_fly.tween_property(self, "_shrink", 1.0, 1.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Вещь, которую покажет рапорт победы: сперва те, что ещё не попадались.
func claim_prize() -> int:
	if _pending >= 0:
		return _pending
	var pool: Array[int] = []
	for index in range(ArtifactModel.ITEMS.size()):
		if not found.has(index):
			pool.append(index)
	if pool.is_empty():
		_pending = _rng.randi_range(0, ArtifactModel.ITEMS.size() - 1)
	else:
		_pending = pool[_rng.randi_range(0, pool.size() - 1)]
	return _pending


func _bank() -> void:
	var prize := claim_prize()
	if not found.has(prize):
		found.append(prize)
	artifacts += 1
	_pending = -1


func _process(delta: float) -> void:
	_time += delta
	if main == null or main.raid == null:
		return
	var engaged := main.raid.engaged()
	var state := main.raid.state
	# Победа засчитывается, когда рапорт закрыт: выходом или новой вахтой.
	if _last_state == RaidRun.State.WON and state != RaidRun.State.WON:
		_bank()
		_won = true
	_last_state = state
	if _was_engaged and not engaged:
		# Рейд закончен: сфера опускается с неба в другом месте.
		if _won:
			main.announce("АРТЕФАКТ ИЗ ДРУГОГО МИРА — В ТРЮМЕ. СФЕРА ОПУСТИЛАСЬ В НОВОМ МЕСТЕ.")
		else:
			main.announce("СФЕРА ОПУСТИЛАСЬ В НОВОМ МЕСТЕ. СЛЕД — НА КОМПАСЕ.")
		_won = false
		relocate()
		_arrive()
	_was_engaged = engaged
	visible = not engaged
	if not visible:
		return
	# Парит над водой, медленно вращается и «дышит» светом; _lift, _shrink и
	# _spin ведёт анимация взлёта и посадки.
	_model.position.y = 3.2 + 0.55 * sin(_time * 1.3) + _lift
	_model.scale = Vector3.ONE * _shrink
	_model.rotation.y += (0.6 + _spin) * delta
	_model.rotation.x = 0.18 * sin(_time * 0.7)
	_light.position.y = 3.0 + _lift
	_light.light_energy = (2.6 + 1.2 * sin(_time * 2.1)) * _shrink + _flare
