class_name TowerPlayer
extends CharacterBody3D
## Адаптация MIT-контроллера Whimfoome First Person Starter (ускорение,
## торможение и управление в воздухе). Лицензия и точный исходник — в
## third_party/first_person_starter. Узел остаётся привязан к башне.
const WALK_SPEED := 2.6
const SPRINT_SPEED := 4.6
const ACCELERATION := 8.0
const DECELERATION := 10.0
const AIR_CONTROL := 0.3
const GRAVITY := 18.0
const JUMP_VELOCITY := 6.0
const STEP_DISTANCE := 1.35

var camera_rig: CameraRig
var audio: SoundScape
var radio: RadioTuner
var debug_menu: DebugMenu
var health: PlayerHealth
var coast: Coast
var grapple: GrappleHook
var terrain_grounded := false
var safety_barriers_enabled := true
var sprinting := false
var _step_distance := 0.0
var _bob_phase := 0.0


func _ready() -> void:
	collision_layer = 16
	collision_mask = 8 | 64
	floor_snap_length = 0.15
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 2.35
	var collider := CollisionShape3D.new()
	collider.name = "PlayerCapsule"
	collider.shape = capsule
	# Корень тела находится на уровне ступней, как и старый TowerPlayer.
	collider.position.y = capsule.height * 0.5
	add_child(collider)


func _physics_process(delta: float) -> void:
	if camera_rig == null:
		return
	var locked := (radio != null and radio.tuning) or (debug_menu != null and debug_menu.is_open) or (health != null and health.defeated)
	var input := Vector2.ZERO if locked else Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var yaw: float = camera_rig.yaw
	var forward := Vector3(sin(yaw), 0.0, cos(yaw))
	var right := Vector3(-cos(yaw), 0.0, sin(yaw))
	var direction := (right * input.x - forward * input.y).normalized()
	if locked and grapple != null and grapple.attached:
		# При открытом меню не отпускаем зависшего на тросе игрока.
		velocity = Vector3.ZERO
		return
	var was_grounded := is_on_floor() or terrain_grounded
	sprinting = not locked and was_grounded and Input.is_action_pressed("sprint") and input.y < -0.1
	if was_grounded:
		if not locked and Input.is_action_just_pressed("jump"):
			velocity.y = JUMP_VELOCITY
	else:
		velocity.y -= GRAVITY * delta
	if locked:
		velocity.x = 0.0
		velocity.z = 0.0
	elif grapple != null and grapple.attached and not was_grounded:
		# Не гасим инерцию маятника обычным воздушным торможением FPS.
		velocity.x += direction.x * 5.0 * delta
		velocity.z += direction.z * 5.0 * delta
	else:
		_accelerate(direction, SPRINT_SPEED if sprinting else WALK_SPEED, delta, was_grounded)
	if grapple != null and grapple.attached:
		velocity = grapple.constrain_velocity(velocity, delta, direction)
	var previous := global_position
	move_and_slide()
	_update_terrain_floor()
	_update_barriers()
	var displacement := global_position - previous
	var grounded_now := is_on_floor() or terrain_grounded
	var distance := Vector2(displacement.x, displacement.z).length() if grounded_now else 0.0
	if not was_grounded and grounded_now and audio != null:
		audio.on_land(0.35)
	_step_distance += distance
	if _step_distance >= STEP_DISTANCE:
		_step_distance = fmod(_step_distance, STEP_DISTANCE)
		if audio != null:
			audio.on_step(0.55 if sprinting else 0.30, 0.35)
	_bob_phase += distance * (4.8 if sprinting else 4.2)
	var bob_amount := clampf(distance / maxf(delta * WALK_SPEED, 0.001), 0.0, 1.0) if not locked else 0.0
	camera_rig.bob = lerpf(camera_rig.bob, sin(_bob_phase * 2.0) * 0.024 * bob_amount, minf(1.0, delta * 12.0))
	var desired_lean := 0.0 if locked else Input.get_action_strength("lean_right") - Input.get_action_strength("lean_left")
	camera_rig.lean = lerpf(camera_rig.lean, desired_lean, minf(1.0, delta * 9.0))


## Формула First Person Starter: lerp горизонтальной скорости, уменьшенное
## управление в воздухе; вертикальную скорость и гравитацию не интерполируем.
func _accelerate(direction: Vector3, speed: float, delta: float, grounded: bool) -> void:
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	var rate := ACCELERATION if direction.dot(horizontal) > 0.0 else DECELERATION
	if not grounded:
		rate *= AIR_CONTROL
	horizontal = horizontal.lerp(direction * speed, clampf(rate * delta, 0.0, 1.0))
	velocity.x = horizontal.x
	velocity.z = horizontal.z


## Песок — высотное поле без встроенного тела Godot. Останавливаем капсулу
## по той же функции, что используется снарядами и роботами. Крыша башни
## остаётся обычной коллизией move_and_slide и не заменяется этим полом.
func _update_terrain_floor() -> void:
	terrain_grounded = false
	if coast == null:
		return
	var ground := coast.ground_height(global_position.x, global_position.z)
	if global_position.y <= ground + 0.04 and velocity.y <= 0.0:
		global_position.y = ground
		velocity.y = 0.0
		terrain_grounded = true


func _update_barriers() -> void:
	var local := global_position - (get_parent() as Node3D).global_position
	if grapple != null and grapple.attached:
		safety_barriers_enabled = false
	elif absf(local.x) < ObservationTower.WALK_LIMIT - 0.15 and absf(local.z) < ObservationTower.WALK_LIMIT - 0.15 and local.y >= ObservationTower.DECK_HEIGHT - 0.05:
		# Включаем барьеры только когда капсула полностью внутри площадки.
		safety_barriers_enabled = true
	collision_mask = 8 | (64 if safety_barriers_enabled else 0)
