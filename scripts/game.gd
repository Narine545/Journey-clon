class_name GameState
extends Node
## Автозагрузка «Game»: глобальное состояние — ветер, солнце, время суток.
## Единственный источник ветра для песка и процедурного звука.

# --- Светила и палитра ---
var night01 := 0.0 # 0=день … 1=ночь
var sun_dir := Vector3(-0.55, 0.185, -0.30).normalized()

const SAND_SUNNY := Color(0.98, 0.62, 0.30)
const SAND_HOT := Color(1.00, 0.78, 0.42)
const SAND_SHADE := Color(0.47, 0.40, 0.56)
const HORIZON_COL := Color(1.00, 0.70, 0.48)
const SKY_COL := Color(0.27, 0.24, 0.44)

const FOG_DISTANCE := 340.0

# --- Ветер ---
var wind_base := 0.18
var wind_angle := 0.18 # текущее (гуляет вокруг базы)
var wind_strength := 1.0
var elapsed := 0.0

func _ready() -> void:
	_add_key_action("move_forward", [KEY_W, KEY_UP])
	_add_key_action("move_back", [KEY_S, KEY_DOWN])
	_add_key_action("move_left", [KEY_A, KEY_LEFT])
	_add_key_action("move_right", [KEY_D, KEY_RIGHT])


func _add_key_action(action: String, keys: Array) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	for key in keys:
		var event := InputEventKey.new()
		event.physical_keycode = key
		InputMap.action_add_event(action, event)


func _process(delta: float) -> void:
	elapsed += delta
	# Ветер живёт: медленно гуляет направление и сила (сумма синусов).
	wind_angle = wind_base + 0.28 * sin(elapsed * 0.021) + 0.12 * sin(elapsed * 0.047 + 1.7)
	wind_strength = 1.0 + 0.22 * sin(elapsed * 0.033 + 4.0) + 0.10 * sin(elapsed * 0.081)


func wind_dir() -> Vector2:
	return Vector2(cos(wind_angle), sin(wind_angle))


func wind_dir_3d() -> Vector3:
	return Vector3(cos(wind_angle), 0.0, sin(wind_angle))
