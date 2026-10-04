class_name FaceAnimator
extends Node

## Drives facial expressions and blinking via blend shapes.
## Expression patterns are layered with a procedural blink layer; the maximum
## of both layers is applied to each blend shape.

@export var skeleton_path: NodePath

# --- Expression timing ---
@export_group("Face animation timing")
@export var fade_speed: float = 6.0
@export var idle_time_min: float = 1.5
@export var idle_time_max: float = 4.0
@export var hold_time_min: float = 0.6
@export var hold_time_max: float = 2.0

# --- Blink timing ---
@export_group("Blink timing")
@export var blink_interval_min: float = 2.0
@export var blink_interval_max: float = 6.0
@export var blink_close_duration: float = 0.08
@export var blink_open_duration: float = 0.12
@export var double_blink_chance: float = 0.15
@export var double_blink_gap: float = 0.1

# --- Blink shape keys ---
@export var blink_shape_both: StringName = &"Blink"   # Shared blink shape, if any.
@export var blink_weight: float = 1.0

@export_group("Patterns")
## Dictionary of named patterns: { pattern_name: { "shapes": { shape: weight }, "duration_scale": float } }
@export var patterns: Dictionary = {}


var _meshes: Array[MeshInstance3D] = []
var _shape_indices: Dictionary = {}   # shape_name -> { mesh, index }

# Expression layer (patterns).
var _expr_target: Dictionary = {}
# Blink layer.
var _blink_target: Dictionary = {}

# Final blended values applied to the meshes.
var _current: Dictionary = {}

var _state: int = State.IDLE
var _timer: float = 0.0

# --- Blink state ---
var _blink_timer: float = 0.0
var _blink_phase: int = BlinkPhase.WAIT
var _blink_phase_timer: float = 0.0
var _blink_pending_double: bool = false

enum State { IDLE, HOLD }
enum BlinkPhase { WAIT, CLOSING, OPENING, GAP }


# --- Lifecycle ---

func _ready() -> void:
	var skeleton: Skeleton3D = get_node_or_null(skeleton_path)
	if skeleton == null:
		push_error("FaceAnimator: skeleton not found at %s" % skeleton_path)
		return

	for node in skeleton.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		var count = mesh_instance.mesh.get_blend_shape_count()
		if count == 0:
			continue
		_meshes.append(mesh_instance)
		for i in count:
			var shape_name = mesh_instance.mesh.get_blend_shape_name(i)
			if not _shape_indices.has(shape_name):
				_shape_indices[shape_name] = {
					"mesh": mesh_instance,
					"index": i
				}
			_current[shape_name] = 0.0
			_expr_target[shape_name] = 0.0
			_blink_target[shape_name] = 0.0

	_schedule_next_idle()
	_schedule_next_blink()


# --- Main loop ---

func _process(delta: float) -> void:
	_process_expression(delta)
	_process_blink(delta)
	_apply_blended(delta)


# --- Expression layer ---

func _process_expression(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	match _state:
		State.IDLE:
			_pick_and_apply_pattern()
		State.HOLD:
			_reset_expression()
			_schedule_next_idle()


func _reset_expression() -> void:
	for shape_name in _expr_target.keys():
		_expr_target[shape_name] = 0.0
	_state = State.IDLE


func _schedule_next_idle() -> void:
	_state = State.IDLE
	_timer = randf_range(idle_time_min, idle_time_max)


func _pick_and_apply_pattern() -> void:
	if patterns.is_empty():
		_schedule_next_idle()
		return

	var keys := patterns.keys()
	var pattern_name: StringName = keys[randi() % keys.size()]
	var pattern: Dictionary = patterns[pattern_name]
	var shapes: Dictionary = pattern.get("shapes", {})

	for shape_name in shapes.keys():
		if _expr_target.has(shape_name):
			_expr_target[shape_name] = float(shapes[shape_name])

	var duration := randf_range(hold_time_min, hold_time_max)
	duration *= float(pattern.get("duration_scale", 1.0))
	_timer = duration
	_state = State.HOLD


# --- Blink layer ---

func _schedule_next_blink() -> void:
	_blink_phase = BlinkPhase.WAIT
	_blink_timer = randf_range(blink_interval_min, blink_interval_max)


func _process_blink(delta: float) -> void:
	match _blink_phase:
		BlinkPhase.WAIT:
			_blink_timer -= delta
			if _blink_timer <= 0.0:
				_start_blink()

		BlinkPhase.CLOSING:
			_blink_phase_timer -= delta
			if _blink_phase_timer <= 0.0:
				_set_blink_target(blink_weight)
				_blink_phase = BlinkPhase.OPENING
				_blink_phase_timer = blink_open_duration

		BlinkPhase.OPENING:
			_blink_phase_timer -= delta
			if _blink_phase_timer <= 0.0:
				_set_blink_target(0.0)
				if _blink_pending_double:
					_blink_pending_double = false
					_blink_phase = BlinkPhase.GAP
					_blink_phase_timer = double_blink_gap
				else:
					_schedule_next_blink()

		BlinkPhase.GAP:
			_blink_phase_timer -= delta
			if _blink_phase_timer <= 0.0:
				_start_blink(false)


func _start_blink(allow_double: bool = true) -> void:
	_set_blink_target(blink_weight)
	_blink_phase = BlinkPhase.CLOSING
	_blink_phase_timer = blink_close_duration
	if allow_double and randf() < double_blink_chance:
		_blink_pending_double = true
	else:
		_blink_pending_double = false


func _set_blink_target(weight: float) -> void:
	if _blink_target.has(blink_shape_both):
		_blink_target[blink_shape_both] = weight


# --- Blending and application ---

func _apply_blended(delta: float) -> void:
	var speed := clampf(fade_speed * delta, 0.0, 1.0)
	for shape_name in _current.keys():
		# Final value = expression + blink (blink dominates for the eyes).
		var expr: float = _expr_target.get(shape_name, 0.0)
		var blink: float = _blink_target.get(shape_name, 0.0)
		var target: float = clampf(maxf(expr, blink), 0.0, 1.0)

		var cur: float = _current[shape_name]
		if not is_equal_approx(cur, target):
			cur = lerpf(cur, target, speed)
			if absf(cur - target) < 0.001:
				cur = target
			_current[shape_name] = cur
			_apply_shape(shape_name, cur)


func _apply_shape(shape_name: StringName, value: float) -> void:
	var info: Dictionary = _shape_indices.get(shape_name, {})
	if info.is_empty():
		return
	var mesh_instance: MeshInstance3D = info["mesh"]
	var index: int = info["index"]
	mesh_instance.set_blend_shape_value(index, value)
