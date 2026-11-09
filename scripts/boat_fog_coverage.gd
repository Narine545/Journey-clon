class_name BoatFogCoverage
extends RefCounted
## Cover the ordinary top-down water footprint, not just the camera-to-boat centre ray.
const MIN_LENGTH := 80.0
const MAX_LENGTH := 640.0
const DEPTH_MARGIN := 16.0
const SIDE_MARGIN := 32.0


static func update(main: BoatMain, delta: float) -> void:
	if main._rme4_volume == null or main.inspection_active():
		return
	var camera := main.camera
	if camera.projection != Camera3D.PROJECTION_ORTHOGONAL:
		return
	var viewport := main.get_viewport().get_visible_rect().size
	var furthest := 0.0
	var extent := Vector2.ZERO
	var boat_at := Vector2(main.boat.global_position.x, main.boat.global_position.z)
	for x in [0.0, 1.0]:
		for y in [0.0, 1.0]:
			var pixel := Vector2(float(x) * viewport.x, float(y) * viewport.y)
			var ray_start := camera.project_ray_origin(pixel)
			var ray := camera.project_ray_normal(pixel)
			if ray.y >= -0.01:
				continue
			var distance := (Coast.SEA_LEVEL - ray_start.y) / ray.y
			if distance <= 0.0:
				continue
			var point := ray_start + ray * distance
			furthest = maxf(furthest, -camera.to_local(point).z)
			var relative := Vector2(point.x, point.z) - boat_at
			extent.x = maxf(extent.x, absf(relative.x))
			extent.y = maxf(extent.y, absf(relative.y))
	if furthest <= 0.0:
		return
	var required := clampf(ceilf((furthest + DEPTH_MARGIN) / 8.0) * 8.0, MIN_LENGTH, MAX_LENGTH)
	var environment := main.world._env
	if required > environment.volumetric_fog_length:
		environment.volumetric_fog_length = required
	elif environment.volumetric_fog_length > required + 8.0:
		environment.volumetric_fog_length = maxf(
			required, environment.volumetric_fog_length - delta * 40.0
		)
	# Keep the existing 18 m edge fade outside visible water, including wide windows.
	main._rme4_volume.size = Vector3(
		maxf(BoatMain.RME4_BOX_SIZE.x, (extent.x + SIDE_MARGIN) * 2.0),
		BoatMain.RME4_BOX_SIZE.y,
		maxf(BoatMain.RME4_BOX_SIZE.z, (extent.y + SIDE_MARGIN) * 2.0)
	)
