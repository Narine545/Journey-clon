class_name RaidDamageFx
extends Node
## Reactive mesh overlay on the boat only. Original surface materials remain untouched.
const LIFE := 0.40
const PREVIEW_LIFE := 1.50
var run: RaidRun
var _material: ShaderMaterial
var _targets: Array[MeshInstance3D] = []
var _saved: Array[Material] = []
var _active := false
var _duration := LIFE
var _hold := 0.12
var _age := LIFE
var _strength := 0.0


func setup(raid: RaidRun) -> void:
	run = raid
	_material = ShaderMaterial.new()
	_material.shader = preload("res://shaders/raid_damage.gdshader")


func reset() -> void:
	_duration = LIFE
	_hold = 0.12
	_age = LIFE
	_strength = 0.0
	_restore()


func hit(actual: float) -> void:
	if actual <= 0.0 or not _allowed():
		return
	_duration = LIFE
	_hold = 0.12
	_age = 0.0
	_strength = clampf(0.55 + actual / 100.0, 0.55, 0.80)
	_sync()


func preview() -> void:
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
	if _age >= _duration:
		_restore()
		return
	var pose := run.main.boat._body.get_global_transform_interpolated()
	_material.set_shader_parameter("boat_inverse", pose.affine_inverse())
	var envelope := clampf((_duration - _age) / (_duration - _hold), 0.0, 1.0)
	_material.set_shader_parameter("intensity", _strength * envelope)
	_material.set_shader_parameter("effect_age", _age)
	if not _active:
		_collect(run.main.boat._body)
		_active = not _targets.is_empty()


func _collect(root: Node) -> void:
	if root is MeshInstance3D:
		var mesh := root as MeshInstance3D
		_targets.append(mesh)
		_saved.append(mesh.material_overlay)
		mesh.material_overlay = _material
	for child in root.get_children():
		_collect(child)


func _restore() -> void:
	for index in range(_targets.size()):
		if not is_instance_valid(_targets[index]):
			continue
		var mesh: MeshInstance3D = _targets[index]
		if mesh.material_overlay == _material:
			mesh.material_overlay = _saved[index]
	_targets.clear()
	_saved.clear()
	_active = false


func is_active() -> bool:
	return _active


func _exit_tree() -> void:
	_restore()
