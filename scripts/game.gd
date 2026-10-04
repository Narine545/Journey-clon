extends Node
## Автозагрузка «Game»: глобальное состояние — ветер, солнце, прогресс главы.
## Единственный источник истины о ветре: его читают шейдер песка и частицы.
## Никакого HUD и текста не предусмотрено.

# --- Солнце и палитра (глава 1: тёплые дюны, вечер) ---
# Направление К солнцу — вар (меняется DEV-панелью F3)
var sun_dir := Vector3(0.16, 0.44, -0.88) # полдень-на-закат: выше, ровнее свет

const SAND_SUNNY := Color(0.98, 0.62, 0.30) # ярко-золотой песок
const SAND_HOT := Color(1.00, 0.78, 0.42) # раскалённые гребни
const SAND_SHADE := Color(0.47, 0.40, 0.56) # мягкая пыльная сирень (не мрак)
const HORIZON_COL := Color(1.00, 0.70, 0.48)
const SKY_COL := Color(0.27, 0.24, 0.44)

const FOG_DISTANCE := 340.0

# --- Ветер ---
var wind_base := -1.26 # базовое направление: почти к маяку (−Z), чуть вправо
var wind_angle := -1.26 # текущее (гуляет вокруг базы)
var wind_strength := 1.0
var elapsed := 0.0

# --- Состояние игрока (читают: камера, музыка позже) ---
var surf01 := 0.0 # 0..1 — насколько игрок «сёрфит» по крутому склону
var player_altitude := 0.0


func _ready() -> void:
	_ensure_input()


func _process(delta: float) -> void:
	elapsed += delta
	# Ветер живёт: медленно гуляет направление и сила (сумма синусов — органично и дёшево).
	wind_angle = wind_base + 0.38 * sin(elapsed * 0.021) + 0.16 * sin(elapsed * 0.047 + 1.7)
	wind_strength = 1.0 + 0.22 * sin(elapsed * 0.033 + 4.0) + 0.10 * sin(elapsed * 0.081)


func wind_dir() -> Vector2:
	# Единичный вектор ветра в мировой плоскости XZ.
	return Vector2(cos(wind_angle), sin(wind_angle))


func wind_dir_3d() -> Vector3:
	return Vector3(cos(wind_angle), 0.0, sin(wind_angle))


## Страховка: если action-ы из project.godot не подхватились — добавляем кодом.
func _ensure_input() -> void:
	_add_key_action("move_forward", [KEY_W, KEY_UP])
	_add_key_action("move_back", [KEY_S, KEY_DOWN])
	_add_key_action("move_left", [KEY_A, KEY_LEFT])
	_add_key_action("move_right", [KEY_D, KEY_RIGHT])
	_add_key_action("jump", [KEY_SPACE])
	if not InputMap.has_action("sing"):
		InputMap.add_action("sing")
		var key := InputEventKey.new()
		key.physical_keycode = KEY_E
		InputMap.action_add_event("sing", key)
		var mouse := InputEventMouseButton.new()
		mouse.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event("sing", mouse)


func _add_key_action(action: String, keys: Array) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)
