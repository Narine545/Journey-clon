class_name RaidApproaches
extends RefCounted
## One slot per existing spawn tick, not additional burst spawning.
var slots: Array[Dictionary] = []
var sequence := 0


func reset() -> void:
	slots.clear()
	sequence = 0


static func on_screen(run: RaidRun, at: Vector2, radius: float) -> bool:
	var camera := run.main.camera
	var point := Vector3(at.x, Coast.SEA_LEVEL + 0.8, at.y)
	if camera.is_position_behind(point):
		return false
	var rect := camera.get_viewport().get_visible_rect().grow(96.0)
	# Conservative body extent in screen space, including the spawn warning.
	var center := camera.unproject_position(point)
	var edge := camera.unproject_position(point + camera.global_basis.x * (radius + 2.0))
	return rect.grow(center.distance_to(edge)).has_point(center)


func next_slot(run: RaidRun) -> Dictionary:
	if slots.is_empty():
		_plan(run)
	if slots.is_empty():
		return {}
	return slots.pop_front()


func _plan(run: RaidRun) -> void:
	var center := run.boat_at()
	var camera := run.main.camera
	var viewport := camera.get_viewport().get_visible_rect().size
	var extent := 40.0
	for pixel in [Vector2.ZERO, Vector2(viewport.x, 0), viewport, Vector2(0, viewport.y)]:
		var start := camera.project_ray_origin(pixel)
		var ray := camera.project_ray_normal(pixel)
		if absf(ray.y) < 0.0001:
			return
		var travel := (Coast.SEA_LEVEL - start.y) / ray.y
		if travel < 0.0:
			return
		var point := start + ray * travel
		extent = maxf(extent, center.distance_to(Vector2(point.x, point.z)))
	var angle := run.rng.randf_range(-PI, PI)
	var mode := sequence % 3
	sequence += 1
	var axis := Vector2.from_angle(angle)
	for index in range(5):
		var direction := axis
		if mode == 2:
			# Open arc, not a sealed ring: deliberately leave an escape sector.
			direction = axis.rotated((float(index) - 2.0) * 0.55)
		var at := center + direction * (extent + 22.0)
		if mode != 2:
			at += axis.orthogonal() * (float(index) - 2.0) * 5.5
		if mode == 0:
			# Loose approach: scatter in depth as well as sideways, outside the frame margin.
			at += axis * run.rng.randf_range(0.0, 12.0)
			at += axis.orthogonal() * run.rng.randf_range(-1.0, 1.0)
		slots.append(
			{
				"at": at,
				"route": -axis if mode == 1 else Vector2.ZERO,
				"expires": run.elapsed + 15.0,
				"mode": mode
			}
		)
	if mode == 0:
		# Use the raid RNG, not Array.shuffle's global RNG; no left-to-right conveyor.
		for index in range(slots.size() - 1, 0, -1):
			var other := run.rng.randi_range(0, index)
			var saved := slots[index]
			slots[index] = slots[other]
			slots[other] = saved
