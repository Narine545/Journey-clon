class_name AnimationStateMachine
extends Node

## A small state machine built on top of AnimationPlayer.
## Transitions are declared in the `transitions` dictionary using keys of the
## form "<from>_to_<to>". A transition may be triggered manually via `travel()`
## or automatically when the current animation finishes (if `at_end` is true).

@export var animation_player: AnimationPlayer

## Transition map. Key format: "<from_state>_to_<to_state>".
@export var transitions: Dictionary[String, Transition] = {}

## Animation played on ready. If empty, the first animation in the player is used.
@export var initial_animation: StringName

# Deferred transition requested while the current animation is still playing.
var _pending_state: StringName = &""

# Set to true for one frame after an animation finishes.
var _animation_finished_flag: bool = false


# --- Lifecycle ---

func _ready() -> void:
	animation_player.animation_finished.connect(_on_animation_finished)

	if initial_animation == &"":
		var anims := animation_player.get_animation_list()
		assert(anims.size() > 0, "AnimationPlayer has no animations")
		initial_animation = StringName(anims[0])

	animation_player.play(initial_animation)


# --- Public API ---

## Returns the name of the currently playing animation.
func get_current_state() -> StringName:
	return animation_player.current_animation


## Requests a transition to `to_state`.
## If the matching transition is marked `at_end` and the current animation is
## still playing, the request is deferred until the animation finishes.
func travel(to_state: StringName) -> void:
	var _current_state = animation_player.current_animation
	if to_state == _current_state:
		return
	if not animation_player.has_animation(to_state):
		push_warning("Animation not found: " + to_state)
		return

	var anim_info: Transition = _resolve_transition(to_state)

	# If `at_end` and the animation is still running, defer the transition.
	if anim_info and anim_info.at_end and not _animation_finished_flag:
		_pending_state = to_state
		return

	var xfade: float = anim_info.xfade_time if anim_info else 0.0
	animation_player.play(to_state, xfade, 1.0)
	_current_state = to_state
	_pending_state = &""
	_animation_finished_flag = false


# --- Internal logic ---

func _on_animation_finished(anim_name: StringName) -> void:
	_animation_finished_flag = true

	# 1. Deferred transition takes highest priority.
	if _pending_state != &"":
		var next := _pending_state
		_pending_state = &""
		travel(next)
		return

	# 2. Automatic transitions: only those with `at_end == true`.
	var prefix := String(anim_name) + "_to_"
	var candidates: Array = transitions.keys().filter(
		func(key: String): return key.begins_with(prefix)
	)
	var auto_candidates: Array = candidates.filter(
		func(key: String): return (transitions[key] as Transition).at_end
	)
	if auto_candidates.is_empty():
		return

	auto_candidates.sort_custom(func(a, b):
		var ta: Transition = transitions[a]
		var tb: Transition = transitions[b]
		if ta.priority != tb.priority:
			return ta.priority > tb.priority   # Higher priority wins.
		return false
	)

	var parts := (auto_candidates[0] as String).split("_to_")
	if parts.size() >= 2:
		travel(StringName(parts[1]))


func _resolve_transition(to_state: StringName) -> Transition:
	var _current_state = animation_player.current_animation
	if _current_state == &"":
		return null
	var key := String(_current_state) + "_to_" + String(to_state)
	if transitions.has(key):
		return transitions[key] as Transition
	return null
