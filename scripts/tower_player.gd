class_name TowerPlayer
extends Node3D
## FPS-передвижение на настиле: инерция, бег и наклоны без выхода за перила.
## Высота фиксирована: прыжки/выход в пустошь в этот этап не входят.
const WALK_SPEED := 2.6
const SPRINT_SPEED := 4.6
const ACCELERATION := 25.0
const BRAKING := 30.0
const STEP_DISTANCE := 1.35

var camera_rig: CameraRig
var audio: SoundScape
var radio: RadioTuner
var velocity := Vector3.ZERO
var sprinting := false
var _step_distance := 0.0
var _bob_phase := 0.0


func _physics_process(delta: float) -> void:
	if camera_rig == null:
		return
	var locked := radio != null and radio.tuning
	var input := Vector2.ZERO if locked else Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var yaw: float = camera_rig.yaw
	var forward := Vector3(sin(yaw), 0.0, cos(yaw))
	var right := Vector3(-cos(yaw), 0.0, sin(yaw))
	sprinting = not locked and Input.is_action_pressed("sprint") and input.y < -0.1
	var desired := (right * input.x - forward * input.y) * (SPRINT_SPEED if sprinting else WALK_SPEED)
	velocity = velocity.move_toward(desired, (ACCELERATION if input.length_squared() > 0.0 else BRAKING) * delta)
	if locked:
		velocity = Vector3.ZERO
	var distance := move_on_deck(velocity * delta)
	# У перил фактический путь равен нулю: не играем шаги и не качаем камеру.
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


## Возвращает фактическую длину шага; границы заданы в координатах башни.
func move_on_deck(movement: Vector3) -> float:
	var previous := position
	position.x = clampf(position.x + movement.x, -ObservationTower.WALK_LIMIT, ObservationTower.WALK_LIMIT)
	position.z = clampf(position.z + movement.z, -ObservationTower.WALK_LIMIT, ObservationTower.WALK_LIMIT)
	position.y = ObservationTower.DECK_HEIGHT
	return previous.distance_to(position)
