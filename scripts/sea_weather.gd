class_name SeaWeather
extends RefCounted
## Погода независима от часов освещения. Длительные состояния и плавные
## фронты, а не новая случайность каждый кадр. Дождь/шторм пока не моделируются.
enum Profile { CLEAR, OVERCAST, MIST, FOG }
const LABELS: Array[String] = ["ЯСНО", "ПАСМУРНО", "ДЫМКА", "ТУМАН"]
const DAY_WEIGHTS: Array[float] = [0.45, 0.30, 0.20, 0.05]
const NIGHT_WEIGHTS: Array[float] = [0.08, 0.12, 0.30, 0.50]
const FOG_RANGES: Array[Vector2] = [Vector2(0.0, 0.0), Vector2(0.03, 0.10),
	Vector2(0.23, 0.42), Vector2(0.78, 1.0)]
const CLOUD_RANGES: Array[Vector2] = [Vector2(0.0, 0.12), Vector2(0.78, 1.0),
	Vector2(0.25, 0.50), Vector2(0.42, 0.72)]

var profile: int = Profile.CLEAR
var fog_amount := 0.0
var cloud_amount := 0.0
var _rng := RandomNumberGenerator.new()
var _hold_left := 55.0
var _transition_time := 0.0
var _transition_elapsed := 0.0
var _from_fog := 0.0
var _from_cloud := 0.0
var _target_fog := 0.0
var _target_cloud := 0.0


func setup(seed_value: int = -1) -> void:
	if seed_value >= 0:
		_rng.seed = seed_value
	else:
		_rng.randomize()
	profile = Profile.CLEAR
	fog_amount = 0.0
	cloud_amount = 0.0
	_transition_time = 0.0
	_transition_elapsed = 0.0
	_hold_left = _rng.randf_range(45.0, 70.0)


static func weights(night: float) -> PackedFloat64Array:
	var darkness := smoothstep(0.25, 0.75, night)
	var result := PackedFloat64Array()
	for i in range(DAY_WEIGHTS.size()):
		result.append(lerpf(DAY_WEIGHTS[i], NIGHT_WEIGHTS[i], darkness))
	return result


static func select_profile(roll: float, night: float) -> int:
	var probabilities := weights(night)
	var cumulative := 0.0
	for i in range(probabilities.size()):
		cumulative += probabilities[i]
		if roll < cumulative:
			return i
	return Profile.FOG


func _begin_front(night: float) -> void:
	profile = select_profile(_rng.randf(), night)
	_from_fog = fog_amount
	_from_cloud = cloud_amount
	var fog_range: Vector2 = FOG_RANGES[profile]
	var cloud_range: Vector2 = CLOUD_RANGES[profile]
	_target_fog = _rng.randf_range(fog_range.x, fog_range.y)
	_target_cloud = _rng.randf_range(cloud_range.x, cloud_range.y)
	_transition_time = _rng.randf_range(18.0, 30.0)
	_transition_elapsed = 0.0
	_hold_left = _rng.randf_range(80.0, 130.0) if profile == Profile.FOG else _rng.randf_range(50.0, 100.0)


func advance(delta: float, night: float) -> void:
	# Делим dt на фазы: большой кадр не теряет время и не перескакивает
	# интерполяцию. Вероятность учитывает ночь при выборе НОВОГО фронта.
	var remaining := maxf(delta, 0.0)
	while remaining > 0.000001:
		if _transition_elapsed < _transition_time:
			var front_step := minf(remaining, _transition_time - _transition_elapsed)
			_transition_elapsed += front_step
			remaining -= front_step
			var blend := smoothstep(0.0, _transition_time, _transition_elapsed)
			fog_amount = lerpf(_from_fog, _target_fog, blend)
			cloud_amount = lerpf(_from_cloud, _target_cloud, blend)
		else:
			var hold_step := minf(remaining, _hold_left)
			_hold_left -= hold_step
			remaining -= hold_step
			if _hold_left <= 0.000001:
				_begin_front(night)


func label() -> String:
	return LABELS[profile] + (" · ПЕРЕХОД" if _transition_elapsed < _transition_time else "")
