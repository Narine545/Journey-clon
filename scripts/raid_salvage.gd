class_name RaidSalvage
extends Node3D
## Raid-only XP, deliberately separate from fixed pigment resources.
const CAPACITY := 192
const PICKUP_CLEARANCE := 2.5
const MAGNET_RANGE := 10.0
var run: RaidRun
var drops: Array[Dictionary] = []
var collected := 0
var magnet_range := MAGNET_RANGE
var _batch: MultiMesh


func setup(raid: RaidRun) -> void:
	run = raid
	var mesh := SphereMesh.new()
	mesh.radius = 0.45
	mesh.height = 1.0
	mesh.radial_segments = 4
	mesh.rings = 2
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color("76ebce")
	mesh.material = material
	_batch = MultiMesh.new()
	_batch.transform_format = MultiMesh.TRANSFORM_3D
	_batch.mesh = mesh
	_batch.instance_count = CAPACITY
	_batch.visible_instance_count = 0
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = _batch
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)


func reset() -> void:
	drops.clear()
	collected = 0
	magnet_range = MAGNET_RANGE
	_batch.visible_instance_count = 0


func drop(at: Vector2, amount: int) -> void:
	if amount <= 0:
		return
	# Compact nearby rewards; at the hard cap merge into the closest existing drop.
	var nearest := -1
	var distance := INF
	for index in range(drops.size()):
		var gap := at.distance_squared_to(drops[index]["at"])
		if gap < distance:
			distance = gap
			nearest = index
	if nearest >= 0 and (distance < 4.0 or drops.size() >= CAPACITY):
		drops[nearest]["amount"] = int(drops[nearest]["amount"]) + amount
	else:
		drops.append({"at": at, "previous": at, "amount": amount})


func step(delta: float) -> int:
	var gained := 0
	for index in range(drops.size() - 1, -1, -1):
		var entry := drops[index]
		var at: Vector2 = entry["at"]
		entry["previous"] = at
		var clearance := run._hull_distance(at)
		if clearance <= PICKUP_CLEARANCE:
			gained += int(entry["amount"])
			drops.remove_at(index)
			continue
		if clearance > magnet_range:
			continue
		var target := run.boat_at()
		if run.main.boat.has_trailer and run.main.boat._trailer != null:
			var trailer_pos := run.main.boat._trailer.global_position
			var trailer_at := Vector2(trailer_pos.x, trailer_pos.z)
			if at.distance_squared_to(trailer_at) < at.distance_squared_to(target):
				target = trailer_at
		# Small ordered steps prevent attraction through a thin bank or reef.
		var travel := minf(at.distance_to(target), 18.0 * delta)
		var steps := maxi(1, ceili(travel / 0.4))
		var direction := (target - at).normalized()
		for _step in range(steps):
			var next := at + direction * (travel / float(steps))
			if not run.navigable(next, 0.15):
				break
			at = next
		entry["at"] = at
	for entry in drops:
		RaidBuoyancy.step(entry, entry["at"], 1.0, 1.2, 7.0, delta, run.main.water, false)
	collected += gained
	return gained


func render(blend: float, time: float) -> void:
	for index in range(drops.size()):
		var entry := drops[index]
		var at: Vector2 = entry["previous"].lerp(entry["at"], blend)
		var scale_factor := minf(1.8, 1.0 + log(float(entry["amount"])) * 0.15)
		var crystal_basis := Basis(Vector3.UP, time * 0.7).scaled(Vector3.ONE * scale_factor)
		var floating := RaidBuoyancy.pose(entry, blend, Coast.SEA_LEVEL + 1.2)
		var height := floating.x + sin(time * 2.0 + at.x) * 0.12
		_batch.set_instance_transform(
			index, Transform3D(crystal_basis, Vector3(at.x, height, at.y))
		)
	_batch.visible_instance_count = drops.size()


func remaining() -> int:
	var total := 0
	for entry in drops:
		total += int(entry["amount"])
	return total
