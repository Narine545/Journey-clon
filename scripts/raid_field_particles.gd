class_name RaidFieldParticles
extends Node3D
## Analytic visual particles, not a physics simulation or copied ParticleProcess shader.
const PER_FIELD := 20
const CAPACITY := 160  # 4 debug fields of each kind, 20 sparks each.
var run: RaidRun
var batch: MultiMesh


func setup(raid: RaidRun) -> void:
	run = raid
	var quad := QuadMesh.new()
	quad.size = Vector2(0.18, 0.18)
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/raid_field_spark.gdshader")
	quad.material = material
	batch = MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.use_colors = true
	batch.mesh = quad
	batch.instance_count = CAPACITY
	batch.visible_instance_count = 0
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = batch
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)


func reset() -> void:
	batch.visible_instance_count = 0


func render() -> void:
	if not run.effects_enabled or run.main.inspection_active():
		reset()
		return
	var count := 0
	count = _fields(run.sphere_mines.mines, false, count)
	count = _fields(run.gravity_mines.mines, true, count)
	batch.visible_instance_count = count


func _fields(fields: Array[Dictionary], inward: bool, count: int) -> int:
	var facing := run.main.camera.global_basis.orthonormalized()
	for mine in fields:
		var phase := float(mine["age"]) - SphereMines.FUSE
		var duration := float(mine["duration"])
		if phase <= 0.0 or phase >= duration:
			continue
		var center: Vector2 = mine["at"]
		var radius := float(mine["radius"])
		var growth := clampf(phase / 0.3, 0.0, 1.0)
		var collapse := clampf((phase - duration + 0.4) / 0.4, 0.0, 1.0)
		for index in range(PER_FIELD):
			if count >= CAPACITY:
				return count
			var seed := fposmod(float(index) * 0.6180339 + center.x * 0.017, 1.0)
			var cycle := fposmod(phase * 0.8 + seed, 1.0)
			var radial := 1.0 - cycle if inward else cycle
			var alpha := sin(cycle * PI) * growth * (1.0 - collapse)
			if inward and collapse > 0.0:
				# One synchronized outward release, following the actual mechanical phase.
				radial = collapse
				alpha = sin(collapse * PI)
			var angle := float(index) * 2.399963 + phase * (0.4 if inward else -0.15)
			var distance := radius * growth * radial
			var offset := Vector2.from_angle(angle) * distance
			var height := Coast.SEA_LEVEL + 0.65 + 0.65 * sin(seed * PI)
			var point := Vector3(center.x + offset.x, height, center.y + offset.y)
			var scale_factor := 0.7 + 0.6 * seed
			batch.set_instance_transform(
				count, Transform3D(facing.scaled(Vector3.ONE * scale_factor), point)
			)
			var tint := (
				Color(0.75, 0.35, 1.0, alpha * 0.85)
				if inward
				else Color(0.25, 0.9, 0.85, alpha * 0.75)
			)
			batch.set_instance_color(count, tint)
			count += 1
	return count
