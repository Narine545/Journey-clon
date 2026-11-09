class_name RaidDamageFx
extends CanvasLayer
## Experimental reactive screen glitch below the raid HUD, never an always-on filter.
const LIFE := 0.40
const PREVIEW_LIFE := 1.50
var run: RaidRun
var _copy: BackBufferCopy
var _rect: ColorRect
var _material: ShaderMaterial
var _duration := LIFE
var _hold := 0.12
var _age := LIFE
var _strength := 0.0


func setup(raid: RaidRun) -> void:
	run = raid
	layer = 19
	_copy = BackBufferCopy.new()
	_copy.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	_copy.visible = false
	add_child(_copy)
	_rect = ColorRect.new()
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_material = ShaderMaterial.new()
	_material.shader = preload("res://shaders/raid_damage.gdshader")
	_rect.material = _material
	_rect.visible = false
	add_child(_rect)
	_resize_rect()
	get_viewport().size_changed.connect(_resize_rect)


func reset() -> void:
	_duration = LIFE
	_hold = 0.12
	_age = LIFE
	_strength = 0.0
	_rect.visible = false
	_copy.visible = false


func hit(actual: float) -> void:
	if actual <= 0.0 or not _allowed():
		return
	_duration = LIFE
	_hold = 0.12
	_age = 0.0
	_strength = clampf(0.55 + actual / 100.0, 0.55, 0.80)
	_sync()


func preview() -> void:
	# Visual-only test: no hull damage, statistics, invulnerability or combat-clock changes.
	if not _allowed():
		return
	hit(12.0)
	_duration = PREVIEW_LIFE
	_hold = 0.90
	_strength = 0.80
	_sync()


func _allowed() -> bool:
	return (
		run.effects_enabled
		and run.state == RaidRun.State.RUNNING
		and not run.main.inspection_active()
	)


func _process(delta: float) -> void:
	if not _allowed():
		reset()
		return
	if _age < _duration:
		_age = minf(_duration, _age + delta)
		_sync()


func _sync() -> void:
	_rect.visible = _age < _duration
	_copy.visible = _rect.visible
	# Brief plateau, then fade; no random activation gate that can miss a short hit.
	var envelope := clampf((_duration - _age) / (_duration - _hold), 0.0, 1.0)
	_material.set_shader_parameter("intensity", _strength * envelope)
	_material.set_shader_parameter("effect_age", _age)


func _resize_rect() -> void:
	# A root Control under CanvasLayer has no Control parent: use explicit viewport bounds.
	_rect.position = Vector2.ZERO
	_rect.size = get_viewport().get_visible_rect().size


func is_active() -> bool:
	return _rect.visible and _copy.visible
