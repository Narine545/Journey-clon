class_name CameraRig
extends Node3D
## FPS-камера: обзор мышью (захват курсора), глаза на высоте 1.62 м,
## лёгкое покачивание в такт шагам, FOV «дышит» на сёрфе.
## Фонарик — конус тёплого света: в волюметрическом тумане он виден
## как настоящий луч (F — включить/выключить, ESC — отпустить курсор).

const EYE := 1.62
const FOV_BASE := 78.0
const FOV_SURF := 92.0
const SURF_REF_SPEED := 17.5
const PITCH_MIN := -1.35
const PITCH_MAX := 1.35
const SENS := 0.0022 # рад на пиксель

var cam: Camera3D
var player: Player
var terrain: Terrain
var arms: FpsArms
var flashlight: SpotLight3D
var flash_on := true

var yaw := PI # курс: fwd = (sin(yaw), 0, cos(yaw)); старт — лицом к «маяку» (-Z)
var pitch := 0.0

var _fov := FOV_BASE
var _interactive := true # в автотестах/CI курсор не захватываем


func setup(main_ref) -> void:
	player = main_ref.player
	terrain = main_ref.terrain
	_interactive = OS.get_environment("JOURNEY_SMOKE") != "1" \
		and OS.get_environment("JOURNEY_SHOT") != "1"

	cam = Camera3D.new()
	add_child(cam)
	cam.fov = FOV_BASE
	cam.near = 0.02 # руки с пистолетом близко к камере
	cam.far = 1800.0
	cam.make_current()

	# фонарик: тёплый конус чуть ниже взгляда — в тумане читается лучом
	flashlight = SpotLight3D.new()
	cam.add_child(flashlight)
	flashlight.position = Vector3(0.10, -0.26, 0.0)
	flashlight.rotation_degrees = Vector3(-11.0, 0.0, 0.0)
	flashlight.spot_range = 42.0
	flashlight.spot_angle = 27.0
	flashlight.spot_attenuation = 1.4
	flashlight.light_color = Color(1.0, 0.93, 0.80)
	flashlight.light_energy = 2.6
	# Руки живут на visual layer 2, мир — на layer 1. Фонарь освещает только
	# мир: больше никакого белого пятна на кистях и затворе перед камерой.
	flashlight.light_cull_mask = 1
	# Отдельный коэффициент обязателен для читаемого конуса в объёмном тумане.
	flashlight.light_volumetric_fog_energy = 2.2
	flashlight.shadow_enabled = true
	flashlight.shadow_bias = 0.08
	flashlight.visible = flash_on

	# руки с пистолетом — прямо на камере
	arms = FpsArms.new()
	cam.add_child(arms)
	arms.setup(main_ref, self)

	yaw = player.heading
	if _interactive:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		apply_mouse_motion(event.relative)
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_ESCAPE and _interactive:
			# ESC — отпустить/захватить курсор (пауза-лайт)
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE \
				if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED
		elif event.physical_keycode == KEY_F:
			flash_on = not flash_on
			flashlight.visible = flash_on
	elif event is InputEventMouseButton and event.pressed and _interactive:
		if event.button_index == MOUSE_BUTTON_LEFT \
				and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			if arms != null:
				arms.suppress_shoot_frames = 3 # клик-захват — не выстрел


## Поворот взгляда мышью (радиан на пиксель) — общий путь для ввода и тестов.
func apply_mouse_motion(rel: Vector2) -> void:
	yaw = wrapf(yaw - rel.x * SENS, -PI, PI)
	pitch = clampf(pitch - rel.y * SENS, PITCH_MIN, PITCH_MAX)


## Задать взгляд напрямую (тесты/сценарии CI).
func set_view(new_yaw: float, new_pitch: float) -> void:
	yaw = wrapf(new_yaw, -PI, PI)
	pitch = clampf(new_pitch, PITCH_MIN, PITCH_MAX)


func _physics_process(delta: float) -> void:
	player.heading = yaw

	var p := player.global_position
	cam.global_position = p + Vector3(0.0, EYE + player.gait_bob(), 0.0)

	# взгляд: базис строим из yaw/pitch (forward = (sin, 0, cos) при pitch=0)
	var b := Basis(Vector3.UP, yaw + PI) * Basis(Vector3.RIGHT, pitch)
	cam.basis = b

	_update_fov(delta)


## FOV дышит со скоростью: сёрф «раскрывает» мир.
func _update_fov(delta: float) -> void:
	var hv := Vector3(player.vel.x, 0.0, player.vel.z)
	var spd01 := clampf(hv.length() / SURF_REF_SPEED, 0.0, 1.0)
	var target_fov := lerpf(FOV_BASE, FOV_SURF, clampf(player.surf01 * 0.8 + spd01 * 0.35, 0.0, 1.0))
	_fov = lerpf(_fov, target_fov, 1.0 - exp(-3.2 * delta))
	cam.fov = _fov
