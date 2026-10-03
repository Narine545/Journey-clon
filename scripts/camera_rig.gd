class_name CameraRig
extends Node3D
## Следящая камера: плывёт за путником, заглядывает вперёд по скорости,
## расширяет FOV на сёрфе и никогда не проваливается под песок.

const POS_DAMP := 4.2
const LOOK_DAMP := 7.0
const YAW_DAMP := 2.4
const FOV_BASE := 74.0
const FOV_SURF := 88.0
const SURF_REF_SPEED := 17.5

var cam: Camera3D
var player: Player
var terrain: Terrain

var _pos := Vector3.ZERO
var _look := Vector3.ZERO
var _yaw := PI
var _fov := FOV_BASE


func setup(player_ref: Player, terrain_ref: Terrain) -> void:
	player = player_ref
	terrain = terrain_ref

	cam = Camera3D.new()
	add_child(cam)
	cam.fov = FOV_BASE
	cam.near = 0.1
	cam.far = 1400.0
	cam.make_current() # камера одна, но порядок добавления не должен иметь значения

	_yaw = player.heading
	var p := player.global_position
	_pos = p + Vector3(0.0, 2.3, 6.5) # за спиной, взгляд к маяку
	_look = p + Vector3.UP * 1.4

	# сразу корректный кадр — без вспышки «камеры в начале координат»
	cam.global_position = _pos
	cam.look_at(_look, Vector3.UP)


func _physics_process(delta: float) -> void:
	var p: Vector3 = player.global_position
	var hv := Vector3(player.vel.x, 0.0, player.vel.z)

	# камера доворачивается за направлением движения — плавно, с задержкой
	if hv.length() > 1.5:
		var target_yaw := atan2(hv.x, hv.z)
		_yaw = lerp_angle(_yaw, target_yaw, 1.0 - exp(-YAW_DAMP * delta))

	var f := Vector3(sin(_yaw), 0.0, cos(_yaw))
	var spd01 := clampf(hv.length() / SURF_REF_SPEED, 0.0, 1.0)
	var dist := lerpf(5.4, 7.2, spd01)
	var height := lerpf(2.1, 3.0, spd01)

	var desired := p + Vector3.UP * height - f * dist
	var look_target := p + Vector3.UP * 1.4 + f * 2.2 + hv * 0.30
	if look_target.distance_to(p) > 8.0:
		look_target = p + (look_target - p).normalized() * 8.0

	_pos = _pos.lerp(desired, 1.0 - exp(-POS_DAMP * delta))
	_look = _look.lerp(look_target, 1.0 - exp(-LOOK_DAMP * delta))

	# песок не должен оказаться в кадре между камерой и небом
	var gh := terrain.sample_height(_pos.x, _pos.z) + 0.75
	if _pos.y < gh:
		_pos.y = gh

	cam.global_position = _pos
	cam.look_at(_look, Vector3.UP)

	# FOV дышит со скоростью: сёрф «раскрывает» мир
	var target_fov := lerpf(FOV_BASE, FOV_SURF, clampf(player.surf01 * 0.8 + spd01 * 0.35, 0.0, 1.0))
	_fov = lerpf(_fov, target_fov, 1.0 - exp(-3.2 * delta))
	cam.fov = _fov
