class_name SphereMines
extends Node3D
## Debug-only visual ordnance. No damage, shielding, RNG or progression changes.
const CAPACITY := 4
const INTERVAL := 3.5
const FUSE := 0.85
const FIELD_TIME := 1.6
var run: RaidRun
var enabled := false
var cooldown := 0.0
var mines: Array[Dictionary] = []


func setup(raid: RaidRun) -> void:
	run = raid


func reset() -> void:
	enabled = false
	for mine in mines:
		mine["node"].queue_free()
	mines.clear()
	cooldown = 0.0


func set_enabled(value: bool) -> void:
	enabled = value
	cooldown = 0.0
	if value:
		run.stats.debug_used = true


func step(delta: float) -> void:
	cooldown -= delta
	if enabled and cooldown <= 0.0:
		cooldown = INTERVAL
		_drop()
	for index in range(mines.size() - 1, -1, -1):
		var mine := mines[index]
		var age := float(mine["age"]) + delta
		mine["age"] = age
		var at: Vector2 = mine["at"]
		if age >= FUSE and not bool(mine["opened"]):
			mine["opened"] = true
			run.main.water.field.splash(at, 2.0)
		if age >= FUSE + FIELD_TIME:
			# Exactly one second impulse, also when visual effects are disabled.
			run.main.water.field.splash(at, 2.0)
			mine["node"].queue_free()
			mines.remove_at(index)
			continue
		var node: MeshInstance3D = mine["node"]
		var radius := 0.35
		if age >= FUSE:
			var phase := age - FUSE
			radius = (
				4.5
				* minf(clampf(phase / 0.3, 0.0, 1.0), clampf((FIELD_TIME - phase) / 0.4, 0.0, 1.0))
			)
			radius = maxf(0.01, radius)
		node.scale = Vector3.ONE * radius
		# Stationary world anchor: sphere intersects the sea, not attached to boat.
		node.position = Vector3(at.x, Coast.SEA_LEVEL + 0.2, at.y)


func _drop() -> void:
	if mines.size() >= CAPACITY:
		return
	var at := run.stern_charges.drop_point()
	if not run.navigable(at, 1.0) or run._hull_distance(at) < 0.8:
		cooldown = 0.5
		return
	for mine in mines:
		if at.distance_squared_to(mine["at"]) < 16.0:
			return
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 32
	mesh.rings = 16
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/sphere_mine.gdshader")
	mesh.material = material
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.scale = Vector3.ONE * 0.35
	node.position = Vector3(at.x, Coast.SEA_LEVEL + 0.2, at.y)
	add_child(node)
	mines.append({"at": at, "age": 0.0, "opened": false, "node": node})
