class_name SphereMines
extends Node3D
## Debug-only contact ordnance. No damage, shielding, RNG or progression changes.
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
		var previous_age := float(mine["age"])
		var age := previous_age + delta
		mine["age"] = age
		var at: Vector2 = mine["at"]
		_expansion_contacts(mine, previous_age, age)
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
	mines.append({"at": at, "age": 0.0, "opened": false, "node": node, "touched": {}})


func _expansion_contacts(mine: Dictionary, before: float, after: float) -> void:
	if after <= FUSE or before >= FUSE + 0.3:
		return
	var radius_before := 4.5 * clampf((before - FUSE) / 0.3, 0.0, 1.0)
	var radius_after := 4.5 * clampf((after - FUSE) / 0.3, 0.0, 1.0)
	var center: Vector2 = mine["at"]
	var touched: Dictionary = mine["touched"]
	for enemy in run.enemies:
		var identity := int(enemy["combat_id"])
		if touched.has(identity) or float(enemy["hp"]) <= 0.0:
			continue
		if float(enemy.get("born", 0.0)) > 0.0:
			continue
		var position: Vector2 = enemy["at"]
		var previous: Vector2 = enemy.get("previous", position)
		var body_radius := float(enemy["radius"])
		var old_gap := previous.distance_to(center) - body_radius - radius_before
		var new_gap := position.distance_to(center) - body_radius - radius_after
		# Linear swept gap catches a fast crossing between fixed steps.
		if new_gap > 0.0 or (old_gap < 0.0 and before > FUSE):
			continue
		var fraction := clampf(old_gap / maxf(old_gap - new_gap, 0.0001), 0.0, 1.0)
		var contact := previous.lerp(position, fraction)
		if not run.stern_charges._line_clear(center, contact):
			continue
		var offset := contact - center
		var normal := (
			offset.normalized()
			if offset.length_squared() > 0.000001
			else Vector2.from_angle(float(identity) * 2.399963)
		)
		touched[identity] = true
		# Visual growth is 15 m/s; limit coupled water/body impulse to 6 m/s.
		RaidMotion.sphere_contact(enemy, normal, 6.0)
