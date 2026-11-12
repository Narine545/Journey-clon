class_name RaidFireballs
extends Node3D
## Visual-only bounded batch. Physics, damage and hit radius remain in RaidRun.
var run: RaidRun
var batch: MultiMesh
var material: ShaderMaterial


func setup(raid: RaidRun) -> void:
	run = raid
	material = ShaderMaterial.new()
	material.shader = preload("res://shaders/raid_fireball.gdshader")
	var quad := QuadMesh.new()
	quad.size = Vector2(2.75, 1.125)
	quad.material = material
	batch = MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.mesh = quad
	batch.instance_count = RaidRun.SHOT_CAP
	batch.visible_instance_count = 0
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = batch
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)


func applies(shot: Dictionary) -> bool:
	return (
		run.fireball_enabled
		and run.effects_enabled
		and not bool(shot["hostile"])
		and int(shot.get("channel", RaidStats.Channel.NOSE)) == RaidStats.Channel.NOSE
	)


func reset() -> void:
	batch.visible_instance_count = 0


func render(blend: float) -> void:
	material.set_shader_parameter("effect_time", run.elapsed)
	var count := 0
	var camera_normal := run.main.camera.global_basis.z.normalized()
	for shot in run.shots:
		if not applies(shot):
			continue
		var velocity: Vector2 = shot["velocity"]
		var forward := Vector3(velocity.x, 0.0, velocity.y)
		var screen_axis := forward - camera_normal * forward.dot(camera_normal)
		if screen_axis.length_squared() < 0.000001:
			screen_axis = run.main.camera.global_basis.x
		screen_axis = screen_axis.normalized()
		var up := camera_normal.cross(screen_axis).normalized()
		var at: Vector2 = Vector2(shot["previous"]).lerp(shot["at"], blend)
		# Bright head is at UV.x=.75; shift quad so that head stays at the collision point.
		var anchor := Vector3(at.x, Coast.SEA_LEVEL + 1.1, at.y) - screen_axis * 0.6875
		batch.set_instance_transform(
			count, Transform3D(Basis(screen_axis, up, camera_normal), anchor)
		)
		count += 1
	batch.visible_instance_count = count
