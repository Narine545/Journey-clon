class_name BuoyDynamics
extends RefCounted
## Analytic moored floats for the game's kinematic (Node3D) vessels.
## Fixed physics steps + swept capsule/disc contacts; rendering is interpolated.
const MAX_OFFSET := 1.35
const MAX_TILT := 0.52
const CONTACT_SLOP := 0.003
const SWEEP_STEP := 0.22
const MAX_SWEEP_STEPS := 128
var main: BoatMain
var floats: Array[Dictionary] = []
var _interpolate := true


func setup(game: BoatMain) -> void:
	main = game
	_interpolate = bool(ProjectSettings.get_setting("physics/common/physics_interpolation", false))


func register(anchor: Vector2, radius: float, node: Node3D = null) -> int:
	var y := main.water.surface_height(anchor.x, anchor.y)
	floats.append({"anchor": anchor, "radius": radius, "node": node,
		"offset": Vector2.ZERO, "velocity": Vector2.ZERO,
		"tilt": Vector2.ZERO, "angular_velocity": Vector2.ZERO,
		"wave_tilt": Vector2.ZERO, "wave_timer": fmod(float(floats.size()) * 0.017, 0.05),
		"height": y, "previous_height": y, "previous_offset": Vector2.ZERO,
		"previous_tilt": Vector2.ZERO, "contact_hold": 0.0})
	if node != null:
		node.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	return floats.size() - 1


func center(index: int) -> Vector2:
	var item: Dictionary = floats[index]
	var anchor: Vector2 = item["anchor"]
	var offset: Vector2 = item["offset"]
	return anchor + offset


func _bounded_velocity(displacement: Vector2, velocity: Vector2, limit: float) -> Vector2:
	if displacement.length() >= limit - 0.00001 and velocity.dot(displacement) > 0.0:
		var normal := displacement.normalized()
		return velocity - normal * velocity.dot(normal)
	return velocity


func step(delta: float) -> void:
	var dt := minf(delta, 0.1)
	for i in range(floats.size()):
		var item: Dictionary = floats[i]
		var offset: Vector2 = item["offset"]
		var velocity: Vector2 = item["velocity"]
		var tilt: Vector2 = item["tilt"]
		var angular: Vector2 = item["angular_velocity"]
		item["previous_offset"] = offset
		item["previous_tilt"] = tilt
		item["previous_height"] = item["height"]
		item["contact_hold"] = maxf(0.0, float(item["contact_hold"]) - dt)
		# Substep springs too, so a slow physics tick cannot destabilise a mooring.
		var count := maxi(1, int(ceil(dt / (1.0 / 60.0))))
		var h := dt / float(count)
		for _iteration in range(count):
			velocity += (-offset * 5.0 - velocity * 3.4) * h
			offset = (offset + velocity * h).limit_length(MAX_OFFSET)
			velocity = _bounded_velocity(offset, velocity, MAX_OFFSET)
			var wave_tilt: Vector2 = item["wave_tilt"]
			angular += ((wave_tilt - tilt) * 18.0 - angular * 5.0) * h
			tilt = (tilt + angular * h).limit_length(MAX_TILT)
			angular = _bounded_velocity(tilt, angular, MAX_TILT)
		# A returning tether must not pull its float through a stationary hull.
		var anchor: Vector2 = item["anchor"]
		var radius: float = item["radius"]
		if not _clear_of_hull(anchor + offset, radius, false) or not _clear_of_hull(anchor + offset, radius, true):
			offset = item["previous_offset"]
			velocity = Vector2.ZERO
		item["offset"] = offset
		item["velocity"] = velocity
		item["tilt"] = tilt
		item["angular_velocity"] = angular
		var p := center(i)
		item["height"] = main.water.surface_height(p.x, p.y)
		item["wave_timer"] = float(item["wave_timer"]) - dt
		if float(item["wave_timer"]) <= 0.0:
			item["wave_timer"] = 0.05
			var sx := (main.water.surface_height(p.x + 0.65, p.y) - main.water.surface_height(p.x - 0.65, p.y)) / 1.3
			var sz := (main.water.surface_height(p.x, p.y + 0.65) - main.water.surface_height(p.x, p.y - 0.65)) / 1.3
			item["wave_tilt"] = Vector2(-atan(sz), atan(sx)).limit_length(0.18) * 1.35


func capsule_point(p: Vector2, at: Vector2, yaw: float, half_segment: float) -> Vector2:
	var heading := Vector2(-sin(yaw), -cos(yaw))
	return at + heading * clampf((p - at).dot(heading), -half_segment, half_segment)


func hull_distance(index: int, at: Vector2, yaw: float, half_segment: float, radius: float) -> float:
	var p := center(index)
	return p.distance_to(capsule_point(p, at, yaw, half_segment)) - radius - float(floats[index]["radius"])


func _clear_of_hull(p: Vector2, radius: float, trailer: bool) -> bool:
	if main.boat == null:
		return true
	var hull: Node3D = main.boat
	var half_segment := 3.7
	var hull_radius := 1.7
	if trailer:
		if not main.boat.has_trailer or main.boat._trailer == null:
			return true
		hull = main.boat._trailer
		half_segment = 1.6
		hull_radius = 1.5
	var at := Vector2(hull.global_position.x, hull.global_position.z)
	return p.distance_to(capsule_point(p, at, hull.rotation.y, half_segment)) >= radius + hull_radius - 0.001


func overlaps(at: Vector2, yaw: float, half_segment: float, radius: float) -> bool:
	for i in range(floats.size()):
		if hull_distance(i, at, yaw, half_segment, radius) < -0.001:
			return true
	return false


func resolve_motion(from: Vector2, to: Vector2, old_yaw: float, new_yaw: float,
		half_segment: float, radius: float, delta: float, is_trailer: bool = false) -> Dictionary:
	var motion := to - from
	var angle := angle_difference(old_yaw, new_yaw)
	var distance := motion.length() + absf(angle) * (half_segment + radius)
	var steps := maxi(1, int(ceil(distance / SWEEP_STEP)))
	if steps > MAX_SWEEP_STEPS:
		# A teleport is not a sweep: reject it, rather than testing only the end.
		return {"position": from, "yaw": old_yaw, "hit": true, "speed_factor": 0.0, "yaw_kick": 0.0}
	var at := from
	var yaw := old_yaw
	var hit := false
	var head_on := 0.0
	var yaw_kick := 0.0
	var travel_speed := motion.length() / maxf(delta, 0.001)
	for _sweep in range(steps):
		var trial := at + motion / float(steps)
		var trial_yaw := yaw + angle / float(steps)
		var changed: Dictionary = {}
		for _pass in range(4):
			for i in range(floats.size()):
				var item: Dictionary = floats[i]
				var p := center(i)
				var reach := half_segment + radius + float(item["radius"]) + 0.1
				if p.distance_squared_to(trial) > reach * reach:
					continue
				var nearest := capsule_point(p, trial, trial_yaw, half_segment)
				var gap := p - nearest
				var minimum := radius + float(item["radius"]) + CONTACT_SLOP
				if gap.length_squared() >= minimum * minimum:
					continue
				if not changed.has(i):
					changed[i] = [item["offset"], item["velocity"], item["angular_velocity"], item["contact_hold"]]
				hit = true
				var normal := gap.normalized()
				if gap.length_squared() < 0.000001:
					normal = Vector2(cos(trial_yaw), -sin(trial_yaw))
				var penetration := minimum - gap.length()
				var offset: Vector2 = item["offset"]
				# The light float yields first. Once the tether is taut, residual
				# penetration is resolved on the vessel: no passing through it.
				var proposed := (offset + normal * penetration).limit_length(MAX_OFFSET)
				var anchor: Vector2 = item["anchor"]
				var moved := anchor + proposed
				if main.coast.water_depth(moved.x, moved.y) < 0.5 or not _clear_of_hull(moved, float(item["radius"]), not is_trailer):
					proposed = offset
				var yield_distance := maxf(0.0, (proposed - offset).dot(normal))
				item["offset"] = proposed
				trial -= normal * maxf(0.0, penetration - yield_distance)
				var impact := minf(1.2, travel_speed * 0.13 + penetration * 0.25)
				var velocity: Vector2 = item["velocity"]
				item["velocity"] = (velocity + normal * impact).limit_length(2.5)
				var angular: Vector2 = item["angular_velocity"]
				item["angular_velocity"] = (angular + Vector2(normal.y, -normal.x) * impact * 1.4).limit_length(2.8)
				item["contact_hold"] = 1.0
				if motion.length_squared() > 0.000001:
					head_on = maxf(head_on, maxf(0.0, motion.normalized().dot(normal)))
				var lever := nearest - trial
				yaw_kick += (lever.x * normal.y - lever.y * normal.x) / maxf(half_segment, 0.1) * minf(0.025, penetration * 0.05)
		if overlaps(trial, trial_yaw, half_segment, radius):
			# Multi-contact corner or rotational pinch: keep the last clear pose
			# AND restore floats touched by this rejected substep.
			for key in changed:
				var item: Dictionary = floats[int(key)]
				var saved: Array = changed[key]
				item["offset"] = saved[0]
				item["velocity"] = saved[1]
				item["angular_velocity"] = saved[2]
				item["contact_hold"] = saved[3]
			head_on = maxf(head_on, 0.9)
			break
		at = trial
		yaw = trial_yaw
	return {"position": at, "yaw": yaw, "hit": hit,
		"speed_factor": 1.0 - head_on * 0.65, "yaw_kick": clampf(yaw_kick, -0.10, 0.10)}


func render_pose(index: int) -> Transform3D:
	var item: Dictionary = floats[index]
	var alpha := 1.0
	if _interpolate:
		alpha = clampf(Engine.get_physics_interpolation_fraction(), 0.0, 1.0)
	var previous_offset: Vector2 = item["previous_offset"]
	var offset: Vector2 = item["offset"]
	var previous_tilt: Vector2 = item["previous_tilt"]
	var tilt: Vector2 = item["tilt"]
	var render_tilt := previous_tilt.lerp(tilt, alpha)
	var anchor: Vector2 = item["anchor"]
	var p := anchor + previous_offset.lerp(offset, alpha)
	var y := lerpf(float(item["previous_height"]), float(item["height"]), alpha)
	return Transform3D(Basis.from_euler(Vector3(render_tilt.x, 0.0, render_tilt.y)), Vector3(p.x, y, p.y))


func render_nodes() -> void:
	for i in range(floats.size()):
		var node: Node3D = floats[i]["node"]
		if is_instance_valid(node):
			node.global_transform = render_pose(i)
