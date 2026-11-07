class_name IslandLayout
extends RefCounted
## Closed coastline, independent of the terrain mesh boundary. Metres, +Z south.
## Positive distance is land. The bay is open to the west, not an inland lake.
const CENTER := Vector2(170.0, 5.0)
const AXES := Vector2(230.0, 285.0)
const BAY_OUTER := Vector2(-165.0, -30.0)
const BAY_INNER := Vector2(88.0, -30.0)
const BAY_RADIUS := 62.0
const BOAT_START := Vector2(-160.0, -30.0)
const BERTH := Vector2(114.0, -38.0)
const SETTLEMENT := Vector2(188.0, -30.0)
const PIER_RECT := Rect2(109.0, -33.0, 51.0, 6.0)


# Keep complete slicks (including the 8 m mesh) outside the approach and basin.
const HARBOR_NO_SLICKS := Rect2(-105.0, -124.0, 295.0, 188.0)
const HARBOR_APRON := Rect2(118.0, -54.0, 13.0, 12.0)
const HARBOR_LINK := Rect2(131.0, -48.0, 4.0, 21.0)


static func permits_slick(p: Vector2) -> bool:
	return not HARBOR_NO_SLICKS.grow(8.0).has_point(p)



static func _smooth(a: float, lo: float, hi: float) -> float:
	var t := clampf((a - lo) / (hi - lo), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


static func _smin(a: float, b: float, k: float) -> float:
	var h := maxf(k - absf(a - b), 0.0) / k
	return minf(a, b) - h * h * k * 0.25


static func _radius(angle: float) -> float:
	return 1.0 + 0.085 * sin(3.0 * angle + 0.4) \
		+ 0.045 * cos(5.0 * angle - 0.6) - 0.035 * sin(2.0 * angle) \
		+ 0.022 * cos(9.0 * angle + 1.2)


static func inland_distance(p: Vector2) -> float:
	var q := (p - CENTER) / AXES
	var outer := (_radius(atan2(q.y, q.x)) - q.length()) * AXES.x
	var along := clampf((p.x - BAY_OUTER.x) / (BAY_INNER.x - BAY_OUTER.x), 0.0, 1.0)
	var cx := lerpf(BAY_OUTER.x, BAY_INNER.x, along)
	var delta := cx - BAY_INNER.x
	var bend_mask := _smooth(absf(delta), 0.0, 42.0)
	var cz := BAY_INNER.y + (7.0 * sin(delta * 0.011) + 3.0 * sin(delta * 0.027)) * bend_mask
	var width := BAY_RADIUS + (6.0 * sin(delta * 0.017) + 2.0 * sin(delta * 0.039)) * bend_mask
	# Curving, unequal bay shores; never two straight sides of a capsule cutout.
	var local := p - Vector2(cx, cz)
	var angle := atan2(local.y, local.x)
	var bay_distance := local.length()
	var irregular := (3.8 * sin(3.0 * angle) + 1.6 * cos(4.0 * angle)) * _smooth(bay_distance, 20.0, 50.0)
	var channel := bay_distance - width - irregular
	var d := _smin(outer, channel, 18.0)
	# Smaller, unequally shaped coves interrupt the east and north shores.
	var east := (((p - Vector2(410.0, 150.0)) / Vector2(58.0, 78.0)).length() - 1.0) * 58.0
	var north := (((p - Vector2(110.0, -296.0)) / Vector2(45.0, 38.0)).length() - 1.0) * 38.0
	return _smin(_smin(d, east, 14.0), north, 12.0)


static func _hill(p: Vector2, center: Vector2, axes: Vector2, height: float) -> float:
	var q := (p - center) / axes
	return height * exp(-q.length_squared())


static func height_at(p: Vector2) -> float:
	var d := inland_distance(p)
	if d <= 0.0:
		# Shallow shelf first, then a smoothly deepening seabed. No raised rim.
		var offshore := -d
		var depth := 0.115 * offshore + 0.00125 * offshore * offshore
		return -100.0 * (1.0 - exp(-depth / 100.0))
	var hills := _hill(p, Vector2(218.0, 0.0), Vector2(95.0, 150.0), 23.0)
	hills += _hill(p, Vector2(150.0, -174.0), Vector2(82.0, 85.0), 12.0)
	hills += _hill(p, Vector2(205.0, 175.0), Vector2(105.0, 88.0), 16.0)
	# A broad low glen continues inland from the harbour; do not cut a flat
	# building pad abruptly into the flank of the central hill.
	var glen := ((p - SETTLEMENT) / Vector2(82.0, 60.0)).length_squared()
	hills *= 1.0 - 0.9 * exp(-glen)
	# Coastal lowlands and separate rounded summits, not an inland wall/plateau.
	var h := 8.0 * (1.0 - exp(-d / 85.0)) + hills * _smooth(d, 10.0, 75.0)
	var broken := sin(p.x * 0.038 + sin(p.y * 0.022)) * cos(p.y * 0.031 - 0.7)
	h += broken * 1.1 * _smooth(d, 12.0, 65.0)
	# Only a small terrace at the head of the bay is levelled for future services.
	var pad := ((p - SETTLEMENT) / Vector2(30.0, 24.0)).length()
	var terrace := (1.0 - _smooth(pad, 0.55, 1.55)) * _smooth(d, 8.0, 16.0)
	return lerpf(h, 4.0, terrace)


static func coastal_site(degrees: float, inset: float = 14.0) -> Dictionary:
	var angle := deg_to_rad(degrees)
	var direction := Vector2(cos(angle) * AXES.x, sin(angle) * AXES.y).normalized()
	# From open water inward: find the OUTERMOST shore even on a cove bearing.
	var hi := 470.0
	var lo := 0.0
	for step in range(1, 236):
		var r := 470.0 - float(step) * 2.0
		if inland_distance(CENTER + direction * r) > 0.0:
			lo = r
			break
		hi = r
	assert(lo > 0.0, "Island headland bearing does not intersect land")
	for i in range(20):
		var mid := (lo + hi) * 0.5
		if inland_distance(CENTER + direction * mid) > 0.0:
			lo = mid
		else:
			hi = mid
	var shore := CENTER + direction * ((lo + hi) * 0.5)
	# Normal, not just a west-facing offset; important on oblique headlands.
	var gradient := Vector2(
		inland_distance(shore + Vector2(0.5, 0.0)) - inland_distance(shore - Vector2(0.5, 0.0)),
		inland_distance(shore + Vector2(0.0, 0.5)) - inland_distance(shore - Vector2(0.0, 0.5)))
	var outward := -gradient.normalized()
	return {"shore": shore, "land": shore - outward * inset, "outward": outward}


static func west_shore(z: float) -> float:
	# Compatibility for the original walking/fishing scene. NOT used to classify
	# island ground, water, beacons, or wet sand: one X cannot describe a loop.
	var previous := -260.0
	for i in range(1, 109):
		var x := -260.0 + float(i) * 8.0
		if inland_distance(Vector2(x, z)) > 0.0:
			var lo := previous
			var hi := x
			for j in range(18):
				var mid := (lo + hi) * 0.5
				if inland_distance(Vector2(mid, z)) > 0.0:
					hi = mid
				else:
					lo = mid
			return (lo + hi) * 0.5
		previous = x
	return CENTER.x
