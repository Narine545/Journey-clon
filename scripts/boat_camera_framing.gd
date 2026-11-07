class_name BoatCameraFraming
extends RefCounted
## Keep the WHOLE orthographic near rectangle in front of water/terrain.
## Moving along the view axis preserves framing, scale and screen positions.
const CLEARANCE := 2.0
var coast: Coast
var _terrain_ceiling := 32.0


func setup(terrain: Coast) -> void:
	coast = terrain
	# Cached once, not a terrain scan every frame. Margin covers interpolation
	# and small sand displacement above the finite mesh's sampled maximum.
	var highest := Coast.SEA_LEVEL
	for sample in coast._grid:
		highest = maxf(highest, sample)
	_terrain_ceiling = highest + 3.0


func fit_offset(focus: Vector3, preferred: Vector3, camera: Camera3D, viewport: Vector2) -> Vector3:
	if camera.projection != Camera3D.PROJECTION_ORTHOGONAL or preferred.length_squared() < 0.001:
		return preferred
	var back := preferred.normalized()
	if back.y <= 0.01:
		return preferred
	var right := Vector3.UP.cross(back).normalized()
	var up := back.cross(right).normalized()
	var aspect := maxf(viewport.x, 1.0) / maxf(viewport.y, 1.0)
	var half_height := camera.size * 0.5
	var half_width := half_height * aspect
	if camera.keep_aspect == Camera3D.KEEP_WIDTH:
		half_width = camera.size * 0.5
		half_height = half_width / aspect
	# At wide zoom pull back smoothly even over open sea. The old eye stayed
	# 27m high while a 160m-tall near rectangle extended below sea level.
	var zoom_guard := minf(_terrain_ceiling - Coast.SEA_LEVEL, maxf(0.0, camera.size - 32.0) * 0.5)
	var floor_height := Coast.SEA_LEVEL + CLEARANCE + zoom_guard
	var distance := maxf(preferred.length(), camera.near + (floor_height - focus.y + up.y * half_height) / back.y)
	var near_center := focus + back * (distance - camera.near)
	# A low/default camera near a hill can still need extra room. Sample the
	# near rectangle, not just the eye/centre ray. Only low rows need probes.
	var blocked := false
	for row in range(5):
		var vertical := lerpf(-half_height, half_height, float(row) / 4.0)
		var row_center := near_center + up * vertical
		if row_center.y >= _terrain_ceiling + CLEARANCE:
			continue
		for column in range(9):
			var horizontal := lerpf(-half_width, half_width, float(column) / 8.0)
			var point := row_center + right * horizontal
			var ground := maxf(Coast.SEA_LEVEL, coast.sample_height(point.x, point.z))
			if point.y < ground + CLEARANCE:
				blocked = true
				break
		if blocked:
			break
	if blocked:
		# One conservative retreat clears ALL terrain, rather than iterating
		# into a different ridge or changing the island/shader to hide clipping.
		distance = maxf(distance, camera.near + (_terrain_ceiling + CLEARANCE - focus.y + up.y * half_height) / back.y)
	return back * distance
