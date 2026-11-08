class_name RaidBuoyancy
extends RefCounted
## Sample the existing CPU water surface at 10 Hz; smooth on combat ticks, render interpolated.
const SAMPLE_INTERVAL := 0.10
const MAX_TILT := 0.18


static func step(
	entry: Dictionary,
	at: Vector2,
	span: float,
	clearance: float,
	response: float,
	delta: float,
	water: WaterSurface,
	tilt: bool = true
) -> void:
	var timer := float(entry.get("float_timer", 0.0)) - delta
	if timer <= 0.0:
		var center := water.surface_height(at.x, at.y)
		var pitch := 0.0
		var roll := 0.0
		if tilt:
			var reach := maxf(1.0, span)
			pitch = -atan2(water.surface_height(at.x, at.y + reach) - center, reach)
			roll = atan2(water.surface_height(at.x + reach, at.y) - center, reach)
		entry["float_target"] = Vector3(
			center + clearance,
			clampf(pitch, -MAX_TILT, MAX_TILT),
			clampf(roll, -MAX_TILT, MAX_TILT)
		)
		entry["float_timer"] = SAMPLE_INTERVAL
	else:
		entry["float_timer"] = timer
	var target: Vector3 = entry["float_target"]
	var current: Vector3 = entry.get("float_pose", target)
	entry["float_previous"] = current
	entry["float_pose"] = current.lerp(target, 1.0 - exp(-response * delta))


static func pose(entry: Dictionary, blend: float, default_height: float) -> Vector3:
	var current: Vector3 = entry.get("float_pose", Vector3(default_height, 0.0, 0.0))
	var previous: Vector3 = entry.get("float_previous", current)
	return previous.lerp(current, blend)


static func tilt_basis(pose_at: Vector3) -> Basis:
	return Basis.from_euler(Vector3(pose_at.y, 0.0, pose_at.z))


static func step_enemies(enemies: Array[Dictionary], delta: float, water: WaterSurface) -> void:
	for enemy in enemies:
		if float(enemy["hp"]) > 0.0:
			RaidBuoyancy.step(
				enemy,
				enemy["at"],
				float(enemy["radius"]),
				1.0,
				3.0 if int(enemy["kind"]) == 3 else 6.0,
				delta,
				water
			)
