class_name RaidSternCharges
extends Node3D
## World-fixed stern ordnance. One bounded pool, no rigid bodies or new lights.
const CAPACITY := 12
const ARM_TIME := 0.65
const LIFETIME := 9.0
const BLAST_TIME := 0.38
var run: RaidRun
var charges: Array[Dictionary] = []
var cooldown := 0.0
var _bodies: MultiMesh
var _rings: MultiMesh


static func power(rank: int) -> float:
	return 0.0 if rank <= 0 else 42.0 + float(rank - 1) * 18.0


static func radius(rank: int) -> float:
	return 0.0 if rank <= 0 else 6.0 + float(rank - 1)


static func interval(rank: int) -> float:
	return 3.2 - float(maxi(1, rank) - 1) * 0.5


func setup(raid: RaidRun) -> void:
	run = raid
	var body := SphereMesh.new()
	body.radius = 0.48
	body.height = 0.7
	body.radial_segments = 8
	body.rings = 3
	_bodies = _make_batch(body)
	var ring := TorusMesh.new()
	ring.inner_radius = 0.94
	ring.outer_radius = 1.0
	ring.rings = 24
	ring.ring_segments = 4
	_rings = _make_batch(ring)


func _make_batch(mesh: PrimitiveMesh) -> MultiMesh:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	mesh.material = material
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.use_colors = true
	batch.mesh = mesh
	batch.instance_count = CAPACITY
	batch.visible_instance_count = 0
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = batch
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	return batch


func reset() -> void:
	charges.clear()
	cooldown = 0.0
	_bodies.visible_instance_count = 0
	_rings.visible_instance_count = 0


func drop_point() -> Vector2:
	var at := run.boat_at() - run.forward() * 6.5
	if run.main.boat.has_trailer and run.main.boat._trailer != null:
		var trailer := run.main.boat._trailer
		var axis := Vector2(-sin(trailer.global_rotation.y), -cos(trailer.global_rotation.y))
		at = Vector2(trailer.global_position.x, trailer.global_position.z) - axis * 4.5
	return at


func _try_drop() -> bool:
	if charges.size() >= CAPACITY:
		return false
	var at := drop_point()
	if not run.navigable(at, 0.7) or run._hull_distance(at) < 0.8:
		return false
	# No tower of charges when the boat is stationary; retry after moving away.
	for charge in charges:
		if float(charge["blast"]) < 0.0 and at.distance_squared_to(charge["at"]) < 9.0:
			return false
	charges.append(
		{
			"at": at,
			"age": 0.0,
			"blast": -1.0,
			"power": power(run.stern_rank),
			"radius": radius(run.stern_rank)
		}
	)
	return true


func step(delta: float) -> void:
	if run.stern_rank <= 0:
		return
	cooldown = maxf(0.0, cooldown - delta)
	if cooldown <= 0.0:
		cooldown = interval(run.stern_rank) if _try_drop() else 0.5
	for index in range(charges.size() - 1, -1, -1):
		var charge := charges[index]
		if float(charge["blast"]) >= 0.0:
			charge["blast"] = float(charge["blast"]) + delta
			if float(charge["blast"]) >= BLAST_TIME:
				charges.remove_at(index)
			continue
		charge["age"] = float(charge["age"]) + delta
		if float(charge["age"]) < ARM_TIME:
			continue
		var at: Vector2 = charge["at"]
		var trigger := float(charge["age"]) >= LIFETIME
		for enemy_index in run._near(at, 6.0):
			var enemy := run.enemies[enemy_index]
			if (
				float(enemy["hp"]) > 0.0
				and at.distance_to(enemy["at"]) <= 2.2 + float(enemy["radius"])
				and _line_clear(at, enemy["at"])
			):
				trigger = true
		if trigger:
			_detonate(charge)


func _line_clear(a: Vector2, b: Vector2) -> bool:
	var steps := maxi(1, ceili(a.distance_to(b) / 0.5))
	for index in range(1, steps + 1):
		if not run.navigable(a.lerp(b, float(index) / float(steps)), 0.1):
			return false
	return true


func _detonate(charge: Dictionary) -> void:
	if float(charge["blast"]) >= 0.0:
		return
	charge["blast"] = 0.0
	var at: Vector2 = charge["at"]
	var reach: float = charge["radius"]
	for enemy_index in run._near(at, reach + 4.0):
		var enemy := run.enemies[enemy_index]
		if float(enemy["hp"]) <= 0.0:
			continue
		var enemy_at: Vector2 = enemy["at"]
		if at.distance_to(enemy_at) <= reach + float(enemy["radius"]) and _line_clear(at, enemy_at):
			enemy["hp"] = float(enemy["hp"]) - float(charge["power"])
			enemy["flash"] = 0.2


func render() -> void:
	for index in range(charges.size()):
		var charge := charges[index]
		var at: Vector2 = charge["at"]
		var blast: float = charge["blast"]
		var armed := float(charge["age"]) >= ARM_TIME
		var body_scale := 0.001 if blast >= 0.0 else 1.0
		_bodies.set_instance_transform(
			index,
			Transform3D(
				Basis.IDENTITY.scaled(Vector3.ONE * body_scale),
				Vector3(at.x, Coast.SEA_LEVEL + 0.8, at.y)
			)
		)
		_bodies.set_instance_color(index, Color("ffbd69") if armed else Color("778e94"))
		var ring_radius := 1.4 if armed else 0.7
		if blast >= 0.0:
			ring_radius = (
				maxf(0.1, float(charge["radius"]) * blast / BLAST_TIME)
				if run.effects_enabled
				else 0.001
			)
		_rings.set_instance_transform(
			index,
			Transform3D(
				Basis.IDENTITY.scaled(Vector3(ring_radius, 0.6, ring_radius)),
				Vector3(at.x, Coast.SEA_LEVEL + 1.0, at.y)
			)
		)
		_rings.set_instance_color(index, Color("ffe3a2") if blast >= 0.0 else Color("c29462"))
	_bodies.visible_instance_count = charges.size()
	_rings.visible_instance_count = charges.size()
