class_name BuoyDynamics
extends RefCounted
## Analytic moored floats for the game's kinematic (Node3D) vessels.
## Fixed physics steps + swept capsule/disc contacts; rendering is interpolated.
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
			offset = offset + velocity * h
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
		half_segment: float, radius: float, delta: float, _is_trailer: bool = false) -> Dictionary:
	# Soft mooring: contact moves ONLY the float. Never shorten the vessel's
	# travel, reject its yaw or damp its speed because a tether is stretched.
	var motion := to - from
	var angle := angle_difference(old_yaw, new_yaw)
	var distance := motion.length() + absf(angle) * (half_segment + radius)
	var steps := clampi(int(ceil(distance / SWEEP_STEP)), 1, MAX_SWEEP_STEPS)
	var hit := false
	for sweep in range(steps):
		var weight := float(sweep + 1) / float(steps)
		var trial := from.lerp(to, weight)
		var yaw := lerp_angle(old_yaw, new_yaw, weight)
		var side := Vector2(cos(yaw), -sin(yaw))
		for i in range(floats.size()):
			var item: Dictionary = floats[i]
			var p := center(i)
			var nearest := capsule_point(p, trial, yaw, half_segment)
			var gap := p - nearest
			var minimum := radius + float(item["radius"]) + CONTACT_SLOP
			if gap.length_squared() >= minimum * minimum:
				continue
			hit = true
			var normal := gap.normalized() if gap.length_squared() > 0.000001 else side
			# Guide a head-on float sideways instead of carrying it at the bow.
			var side_sign := 1.0 if (p - trial).dot(side) >= 0.0 else -1.0
			var away := normal.lerp(side * side_sign, 0.72).normalized()
			if away.dot(normal) < 0.15:
				away = normal
			var penetration := minimum - gap.length()
			var moved := p + away * (penetration / maxf(away.dot(normal), 0.15))
			# Project outside the current hull even on a large low-FPS step.
			var edge := capsule_point(moved, trial, yaw, half_segment)
			var outward := moved - edge
			if outward.length() < minimum:
				moved = edge + (outward.normalized() if outward.length_squared() > 0.000001 else side) * minimum
			var anchor: Vector2 = item["anchor"]
			item["offset"] = moved - anchor
			var impact := minf(0.8, motion.length() / maxf(delta, 0.001) * 0.08 + penetration)
			var velocity: Vector2 = item["velocity"]
			item["velocity"] = (velocity + away * impact).limit_length(2.5)
			var angular: Vector2 = item["angular_velocity"]
			item["angular_velocity"] = (angular + Vector2(away.y, -away.x) * impact).limit_length(2.8)
			item["contact_hold"] = 0.15
	return {"position": to, "yaw": new_yaw, "hit": hit, "speed_factor": 1.0, "yaw_kick": 0.0}


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


static func add_glare(parent: Node3D, height: float, color: Color) -> ShaderMaterial:
	var mesh := QuadMesh.new()
	mesh.size = Vector2(1.1, 1.1)
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/buoy_glare.gdshader")
	material.set_shader_parameter("tint", color)
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	node.position.y = height
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	return material
