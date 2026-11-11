class_name SphereMines
extends Node3D
## Independent control weapon. Debug override shares this emitter, never doubles it.
const CAPACITY := 4
const INTERVAL := 3.5
const FUSE := 0.85
const FIELD_TIME := 3.0
var run: RaidRun
var enabled := false
var cooldown := 0.0
var mines: Array[Dictionary] = []


static func radius(rank: int) -> float:
	return 0.0 if rank <= 0 else 4.5 + 0.75 * float(mini(3, rank) - 1)


static func interval(rank: int) -> float:
	return 8.0 - float(clampi(rank, 1, 3) - 1)


func weapon_rank() -> int:
	return run.sphere_rank


func field_duration() -> float:
	return FIELD_TIME + float(run.sphere_stability)


func release_interval() -> float:
	return interval(weapon_rank())


func drop_offset() -> Vector2:
	return Vector2.ZERO


func record_drop() -> void:
	run.stats.sphere_dropped += 1


func record_open() -> void:
	run.stats.sphere_opened += 1


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
	if (enabled or weapon_rank() > 0) and cooldown <= 0.0:
		cooldown = INTERVAL if enabled else release_interval()
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
			record_open()
			run.main.water.field.splash(at, 2.0)
		if age >= FUSE + float(mine["duration"]):
			# Exactly one second impulse, also when visual effects are disabled.
			run.main.water.field.splash(at, 2.0)
			mine["node"].queue_free()
			mines.remove_at(index)
			continue
		var node: MeshInstance3D = mine["node"]
		var visual_radius := 0.35
		if age >= FUSE:
			var phase := age - FUSE
			visual_radius = (
				float(mine["radius"])
				* minf(
					clampf(phase / 0.3, 0.0, 1.0),
					clampf((float(mine["duration"]) - phase) / 0.4, 0.0, 1.0)
				)
			)
			visual_radius = maxf(0.01, visual_radius)
		node.scale = Vector3.ONE * visual_radius
		# Stationary world anchor: sphere intersects the sea, not attached to boat.
		node.position = Vector3(at.x, Coast.SEA_LEVEL + 0.2, at.y)


func _drop() -> void:
	if mines.size() >= (CAPACITY if enabled else 1):
		return
	var at := run.stern_charges.drop_point() + drop_offset()
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
	mines.append(
		{
			"at": at,
			"age": 0.0,
			"opened": false,
			"node": node,
			"radius": radius(maxi(1, weapon_rank())),
			"duration": field_duration(),
			"measured": {}
		}
	)
	record_drop()


func _expansion_contacts(mine: Dictionary, before: float, after: float) -> void:
	# Compliant contact throughout growth + hold, not a one-shot hit list.
	var active_start := maxf(before, FUSE)
	var active_end := minf(after, FUSE + float(mine["duration"]) - 0.4)
	var contact_delta := active_end - active_start
	if contact_delta <= 0.0:
		return
	var radius_before := float(mine["radius"]) * clampf((active_start - FUSE) / 0.3, 0.0, 1.0)
	var radius_after := float(mine["radius"]) * clampf((active_end - FUSE) / 0.3, 0.0, 1.0)
	var surface_speed := (radius_after - radius_before) / contact_delta
	var center: Vector2 = mine["at"]
	for enemy in run.enemies:
		if float(enemy["hp"]) <= 0.0 or float(enemy.get("born", 0.0)) > 0.0:
			continue
		var enemy_at: Vector2 = enemy["at"]
		var body_radius := float(enemy["radius"])
		var offset := enemy_at - center
		var penetration := radius_after + body_radius - offset.length()
		if penetration <= 0.0:
			continue
		if not run.stern_charges._line_clear(center, enemy_at):
			continue
		var normal := (
			offset.normalized()
			if offset.length_squared() > 0.000001
			else Vector2.from_angle(float(enemy["combat_id"]) * 2.399963)
		)
		var before_push: Vector2 = enemy.get("sphere_velocity", Vector2.ZERO)
		RaidMotion.sphere_contact(enemy, normal, surface_speed, penetration, contact_delta)
		var after_push: Vector2 = enemy.get("sphere_velocity", Vector2.ZERO)
		# Count actual control, not geometric overlap or every pressure tick.
		if (after_push - before_push).dot(normal) >= 0.05:
			var measured: Dictionary = mine["measured"]
			var identity := int(enemy["combat_id"])
			if not measured.has(identity):
				if measured.is_empty():
					run.stats.sphere_effective += 1
				measured[identity] = true
				run.stats.sphere_contacts += 1
