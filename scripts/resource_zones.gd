class_name ResourceZones
extends RefCounted
## World-owned deposits. The vessel is used ONLY to defer visible updates.
const DEFINITIONS := [
	{"name": "Западное течение", "center": Vector2(-190, -125), "radius": 42.0, "kind": 0},
	{"name": "Северо-западная банка", "center": Vector2(-105, -215), "radius": 42.0, "kind": 2},
	{"name": "Восточный дрейф", "center": Vector2(480, 15), "radius": 44.0, "kind": 1},
	{"name": "Южное течение", "center": Vector2(150, 345), "radius": 44.0, "kind": 3},
]
const SLOTS_PER_ZONE := 3
const RENEW_MIN := 100.0
const RENEW_MAX := 160.0
var main: BoatMain
var zones: Array[Dictionary] = []
var slots: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()
var _step := 0.0


func setup(game: BoatMain) -> void:
	main = game
	_rng.seed = 845239
	for i in range(DEFINITIONS.size()):
		var spec: Dictionary = DEFINITIONS[i]
		zones.append({"name": spec["name"], "center": spec["center"], "radius": spec["radius"], "kind": spec["kind"],
			"epoch": 0, "until_shuffle": _rng.randf_range(180.0, 260.0)})
		for j in range(SLOTS_PER_ZONE):
			var candidate := _pick_position(i, null)
			if not candidate["valid"]:
				push_error("No valid deposit position in zone %s" % spec["name"])
				continue
			var at: Vector2 = candidate["at"]
			var slick := ResourceSlick.new()
			slick.name = "Zone%dDeposit%d" % [i, j]
			slick.zone_managed = true
			main.add_child(slick)
			slick.setup(main.water, at, int(spec["kind"]), float(i * SLOTS_PER_ZONE + j) * 1.73)
			main.slicks.append(slick)
			slots.append({"zone": i, "slick": slick, "was_depleted": false,
				"renew_after": 0.0, "shuffle_due": false, "pending": {}})


func _pick_position(zone_index: int, excluded_slick: ResourceSlick) -> Dictionary:
	var zone: Dictionary = zones[zone_index]
	var center: Vector2 = zone["center"]
	var radius: float = zone["radius"]
	for _attempt in range(64):
		# Area-uniform distribution. No boat position, heading, camera or speed here.
		var angle := _rng.randf_range(-PI, PI)
		var p := center + Vector2.from_angle(angle) * sqrt(_rng.randf()) * (radius - 6.0)
		if not IslandLayout.permits_slick(p) or main.coast.water_depth(p.x, p.y) < 4.0:
			continue
		var clear := true
		for other in main.slicks:
			if other != excluded_slick and not other.depleted and p.distance_to(Vector2(other.position.x, other.position.z)) < 12.0:
				clear = false
		for reef in main.reefs:
			var rp: Vector2 = reef["pos"]
			if p.distance_to(rp) < 11.0:
				clear = false
		if clear:
			return {"valid": true, "at": p}
	return {"valid": false}


func _unobserved(p: Vector2) -> bool:
	var boat_at := Vector2(main.boat.global_position.x, main.boat.global_position.z)
	if p.distance_to(boat_at) < 38.0:
		return false
	if main.boat.has_trailer and main.boat._trailer != null:
		var trailer_at := main.boat._trailer.global_position
		if p.distance_to(Vector2(trailer_at.x, trailer_at.z)) < 26.0:
			return false
	return main._outside_boat_view(p) and main._outside_camera_view(p)


func update(delta: float) -> void:
	# Paused by BoatMain in inspection mode; no refresh caused by opening the map.
	_step += delta
	if _step < 0.5:
		return
	var elapsed := _step
	_step = 0.0
	for i in range(zones.size()):
		var zone: Dictionary = zones[i]
		zone["until_shuffle"] = float(zone["until_shuffle"]) - elapsed
		if float(zone["until_shuffle"]) <= 0.0:
			zone["epoch"] = int(zone["epoch"]) + 1
			zone["until_shuffle"] = _rng.randf_range(180.0, 260.0)
			for slot in slots:
				if int(slot["zone"]) == i:
					slot["shuffle_due"] = true
	var changed := false
	for slot in slots:
		var slick: ResourceSlick = slot["slick"]
		if slick.depleted:
			if not slot["was_depleted"]:
				slot["was_depleted"] = true
				slot["renew_after"] = _rng.randf_range(RENEW_MIN, RENEW_MAX)
				slot["pending"] = {}
			else:
				slot["renew_after"] = float(slot["renew_after"]) - elapsed
			if float(slot["renew_after"]) > 0.0:
				continue
		else:
			if not slot["shuffle_due"]:
				continue
			if not slick.can_zone_shuffle():
				# A partial portion stays exactly where the player left it.
				slot["shuffle_due"] = false
				slot["pending"] = {}
				continue
		if changed:
			continue
		var current := Vector2(slick.position.x, slick.position.z)
		if not _unobserved(current):
			continue
		var pending: Dictionary = slot["pending"]
		if pending.is_empty():
			pending = _pick_position(int(slot["zone"]), slick)
			slot["pending"] = pending
		if not pending["valid"]:
			slot["pending"] = {}
			continue
		var candidate: Vector2 = pending["at"]
		if not _unobserved(candidate):
			continue # Keep candidate; don't hunt for one surrounding the camera.
		# Another slot may have refreshed while this candidate waited offscreen.
		var clear := true
		for other in main.slicks:
			if other != slick and not other.depleted and candidate.distance_to(Vector2(other.position.x, other.position.z)) < 12.0:
				clear = false
		if not clear:
			slot["pending"] = {}
			continue
		var at := Vector3(candidate.x, main.water.surface_height(candidate.x, candidate.y) + ResourceSlick.FLOAT_HEIGHT, candidate.y)
		if slick.depleted:
			slick.renew_in_zone(at)
		else:
			slick.relocate_smoothly(at)
		slot["was_depleted"] = false
		slot["shuffle_due"] = false
		slot["pending"] = {}
		changed = true


func summary() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for i in range(zones.size()):
		var zone: Dictionary = zones[i]
		var mass := 0.0
		for slot in slots:
			if int(slot["zone"]) == i:
				var slick: ResourceSlick = slot["slick"]
				mass += slick.remaining_mass
		var center: Vector2 = zone["center"]
		result.append({"name": zone["name"], "center": [center.x, center.y],
			"radius": zone["radius"], "kind": zone["kind"], "mass": mass, "epoch": zone["epoch"]})
	return result
