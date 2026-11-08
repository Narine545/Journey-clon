class_name RaidWeaponFx
extends Node3D
## Six reused quads: one side/face pair for each of three weapon mounts.
const LIFE := 0.16
const MOUNTS := [Vector3(0, 2.0, -6.4), Vector3(2.4, 1.9, 1.0), Vector3(-2.4, 1.9, 1.0)]
var run: RaidRun
var _batch: MultiMesh
var _material: ShaderMaterial
var _remaining := PackedFloat32Array([0.0, 0.0, 0.0])
var _aims := PackedVector2Array([Vector2.UP, Vector2.RIGHT, Vector2.LEFT])


func setup(raid: RaidRun) -> void:
	run = raid
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/raid_muzzle.gdshader")
	material.render_priority = 10
	_material = material
	quad.material = material
	_batch = MultiMesh.new()
	_batch.transform_format = MultiMesh.TRANSFORM_3D
	_batch.use_custom_data = true
	_batch.mesh = quad
	_batch.instance_count = 6
	_batch.visible_instance_count = 0
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = _batch
	# Vertex shader expands/turns the quad beyond its original mesh AABB.
	instance.extra_cull_margin = 8.0
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)


func reset() -> void:
	_remaining.fill(0.0)
	_batch.visible_instance_count = 0


func emit(weapon: int, aim: Vector2, lifetime: float = LIFE) -> void:
	if not run.effects_enabled:
		return
	_remaining[weapon] = lifetime
	_aims[weapon] = aim.normalized()


func step(delta: float) -> void:
	for index in range(3):
		_remaining[index] = maxf(0.0, _remaining[index] - delta)


func render() -> void:
	if (
		not run.effects_enabled
		or (_remaining[0] <= 0.0 and _remaining[1] <= 0.0 and _remaining[2] <= 0.0)
	):
		_batch.visible_instance_count = 0
		return
	var active := false
	var pose := run.main.boat._body.get_global_transform_interpolated()
	_material.set_shader_parameter("flash_scale", clampf(run.main.camera.size / 32.0, 1.0, 1.6))
	for weapon in range(3):
		var strength := clampf(_remaining[weapon] / LIFE * 2.0, 0.0, 1.0)
		active = active or strength > 0.0
		var direction := Vector3(_aims[weapon].x, 0.0, _aims[weapon].y)
		var flash_basis := Basis(Vector3.UP.cross(direction), Vector3.UP, direction)
		var at: Vector3 = pose * MOUNTS[weapon]
		for face in range(2):
			var index := weapon * 2 + face
			_batch.set_instance_transform(index, Transform3D(flash_basis, at))
			_batch.set_instance_custom_data(index, Color(strength, float(face), 0.0, 0.0))
	_batch.visible_instance_count = 6 if active else 0


func preview() -> void:
	if run.state != RaidRun.State.RUNNING or run.main.inspection_active():
		return
	var bow := run.forward()
	emit(0, bow, 0.55)
	emit(1, bow.rotated(PI * 0.5), 0.55)
	emit(2, bow.rotated(-PI * 0.5), 0.55)
