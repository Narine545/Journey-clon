@tool
class_name EyeJitterModifier
extends SkeletonModifier3D

## Adds subtle randomized jitter and roll to eye bones, layered on top of
## any LookAt modifier applied earlier in the pipeline.

## Bone names that should receive the jitter.
@export var eye_bones: Array[StringName] = [&"eye_L", &"eye_R"]

## Maximum yaw/pitch jitter amplitude, in radians.
@export var jitter_strength: float = 0.03

## Maximum roll jitter amplitude, in radians.
@export var roll_strength: float = 0.01

## Time between two consecutive jitter targets, in seconds.
@export var change_interval: float = 1.5

## How quickly the current jitter approaches the target.
@export var smoothing_speed: float = 6.0

var _current_jitter := Vector3.ZERO
var _target_jitter := Vector3.ZERO
var _timer := 0.0


func _process_modification() -> void:
	var delta := get_process_delta_time()
	var skel := get_skeleton()

	if skel == null:
		return

	# Pick a new random target at fixed intervals.
	_timer -= delta
	if _timer <= 0.0:
		_timer = change_interval
		_target_jitter = Vector3(
			randf_range(-jitter_strength, jitter_strength),
			randf_range(-jitter_strength, jitter_strength),
			randf_range(-roll_strength, roll_strength)
		)

	# Smoothly approach the target.
	_current_jitter = _current_jitter.lerp(
		_target_jitter,
		clampf(smoothing_speed * delta, 0.0, 1.0)
	)

	for bone_name in eye_bones:
		var idx := skel.find_bone(bone_name)
		if idx == -1:
			continue

		# Current bone pose (after any LookAt modifier has been applied).
		var current_pose := skel.get_bone_pose_rotation(idx)

		# NOTE: use the bone's local axes, not global RIGHT/UP.
		# Query the bone's global pose to derive its local axes.
		var bone_global := skel.get_bone_global_pose(idx)

		# Bone's local "up" axis (Y) in global space.
		var local_up := bone_global.basis.y.normalized()
		# Bone's local "right" axis (X) in global space.
		var local_right := bone_global.basis.x.normalized()
		# Bone's local "forward" axis (Z) — used for roll.
		var local_forward := bone_global.basis.z.normalized()

		# Build the jitter around the LOCAL axes.
		var jitter_q := (
			Quaternion(local_right,   _current_jitter.x) *
			Quaternion(local_up,      _current_jitter.y) *
			Quaternion(local_forward, _current_jitter.z)
		)

		skel.set_bone_pose_rotation(idx, current_pose * jitter_q)
