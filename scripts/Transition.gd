class_name Transition
extends Resource

## Defines a single transition between two animation states.
## Used by AnimationStateMachine via its `transitions` dictionary.

## Cross-fade duration when entering this transition, in seconds.
@export var xfade_time: float = 0.0

## Higher values win when multiple automatic transitions are candidates.
@export var priority: float = 0.0

## If true, the transition can fire automatically when the current animation ends.
@export var at_end: bool = false
