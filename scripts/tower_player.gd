class_name TowerPlayer
extends Node3D
## Неподвижная высота и ограниченное перемещение только по настилу.
## Прямоугольное ограничение используется вместо земной физики M0: выйти за
## перила или спрыгнуть нельзя, даже при большом delta или диагональном вводе.

const WALK_SPEED := 2.6
const STEP_DISTANCE := 1.35

var camera_rig: CameraRig
var audio: SoundScape
var _step_distance := 0.0


func _physics_process(delta: float) -> void:
	if camera_rig == null:
		return
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var yaw: float = camera_rig.yaw
	var forward := Vector3(sin(yaw), 0.0, cos(yaw))
	var right := Vector3(-cos(yaw), 0.0, sin(yaw))
	var movement := (right * input.x - forward * input.y) * WALK_SPEED * delta
	var distance := move_on_deck(movement)
	_step_distance += distance
	if _step_distance >= STEP_DISTANCE:
		_step_distance = fmod(_step_distance, STEP_DISTANCE)
		if audio != null:
			audio.on_step(0.30, 0.35)


## Возвращает фактическую длину шага; границы заданы в координатах башни.
func move_on_deck(movement: Vector3) -> float:
	var previous := position
	position.x = clampf(position.x + movement.x, -ObservationTower.WALK_LIMIT, ObservationTower.WALK_LIMIT)
	position.z = clampf(position.z + movement.z, -ObservationTower.WALK_LIMIT, ObservationTower.WALK_LIMIT)
	position.y = ObservationTower.DECK_HEIGHT
	return previous.distance_to(position)
