class_name RaidContacts
extends RefCounted
## Bounded soft circle contacts; no bodies, restitution or impulses into the player's boat.
const CELL := 8.0
const PASSES := 3
const SEPARATION_SPEED := 6.0


static func mobility(enemy: Dictionary) -> float:
	if int(enemy.get("kind", 0)) == 3:
		return 0.0 if RaidBoss.preparing(enemy) else 0.25
	if int(enemy.get("kind", 0)) == 1 and float(enemy.get("timer", 2.0)) < 1.1:
		return 0.0
	return 1.0


static func safe_move(at: Vector2, desired: Vector2, radius: float, clear: Callable) -> Vector2:
	if at.is_equal_approx(desired):
		return at
	var steps := maxi(1, ceili(at.distance_to(desired) / 0.35))
	var result := at
	for step in range(1, steps + 1):
		var candidate := at.lerp(desired, float(step) / float(steps))
		if not bool(clear.call(candidate, radius)):
			break
		result = candidate
	return result


static func outside_capsule(
	at: Vector2, a: Vector2, b: Vector2, clearance: float, fallback: Vector2
) -> Vector2:
	var axis := b - a
	var along := clampf((at - a).dot(axis) / maxf(axis.length_squared(), 0.000001), 0.0, 1.0)
	var nearest := a + axis * along
	var offset := at - nearest
	if offset.length_squared() >= clearance * clearance:
		return at
	var normal := (
		offset.normalized() if offset.length_squared() > 0.000001 else fallback.normalized()
	)
	return nearest + normal * clearance


static func separate(enemies: Array[Dictionary], delta: float, clear: Callable) -> void:
	for _pass in range(PASSES):
		var buckets: Dictionary = {}
		var offsets := PackedVector2Array()
		offsets.resize(enemies.size())
		for index in range(enemies.size()):
			var enemy: Dictionary = enemies[index]
			if float(enemy["hp"]) <= 0.0:
				continue
			var at: Vector2 = enemy["at"]
			var key := Vector2i(floori(at.x / CELL), floori(at.y / CELL))
			if not buckets.has(key):
				buckets[key] = []
			buckets[key].append(index)
		for index in range(enemies.size()):
			var enemy: Dictionary = enemies[index]
			if float(enemy["hp"]) <= 0.0:
				continue
			var at: Vector2 = enemy["at"]
			var key := Vector2i(floori(at.x / CELL), floori(at.y / CELL))
			for x in range(-1, 2):
				for y in range(-1, 2):
					for candidate in buckets.get(key + Vector2i(x, y), []):
						var other_index := int(candidate)
						if other_index <= index:
							continue
						var other: Dictionary = enemies[other_index]
						var offset: Vector2 = at - Vector2(other["at"])
						var reach := float(enemy["radius"]) + float(other["radius"]) + 0.08
						var distance := offset.length()
						var weight := mobility(enemy) + mobility(other)
						if distance >= reach or weight <= 0.0:
							continue
						var normal := (
							offset / distance
							if distance > 0.0001
							else Vector2.from_angle(
								(
									float(
										(
											int(enemy.get("combat_id", index)) * 31
											+ int(other.get("combat_id", other_index)) * 17
										)
									)
									* 2.399963
								)
							)
						)
						var correction := normal * (reach - distance) * 0.65
						offsets[index] += correction * mobility(enemy) / weight
						offsets[other_index] -= correction * mobility(other) / weight
		for index in range(enemies.size()):
			var enemy: Dictionary = enemies[index]
			if float(enemy["hp"]) <= 0.0:
				continue
			var at: Vector2 = enemy["at"]
			var step := offsets[index].limit_length(SEPARATION_SPEED * delta / float(PASSES))
			enemy["at"] = safe_move(at, at + step, float(enemy["radius"]), clear)


static func resolve(run: RaidRun, delta: float) -> void:
	var clear := Callable(run, "navigable")
	RaidContacts.separate(run.enemies, delta, clear)
	var bow := run.forward()
	for enemy in run.enemies:
		if float(enemy["hp"]) <= 0.0:
			continue
		var radius: float = enemy["radius"]
		var at: Vector2 = enemy["at"]
		if run._hull_distance(at) < radius:
			run._hurt(9.0 if int(enemy["kind"]) < 3 else 20.0)
		for _pass in range(2):
			var desired := RaidContacts.outside_capsule(
				at,
				run.boat_at() - bow * 3.7,
				run.boat_at() + bow * 3.7,
				radius + 1.72,
				bow.rotated(PI * 0.5)
			)
			at = RaidContacts.safe_move(at, desired, radius, clear)
			if run.main.boat.has_trailer and run.main.boat._trailer != null:
				var trailer := run.main.boat._trailer
				var center := Vector2(trailer.global_position.x, trailer.global_position.z)
				var axis := Vector2(
					-sin(trailer.global_rotation.y), -cos(trailer.global_rotation.y)
				)
				desired = RaidContacts.outside_capsule(
					at,
					center - axis * 1.6,
					center + axis * 1.6,
					radius + 1.52,
					axis.rotated(PI * 0.5)
				)
				at = RaidContacts.safe_move(at, desired, radius, clear)
		RaidMotion.from_contact(enemy, at - Vector2(enemy["at"]), run.main.boat.speed)
		enemy["at"] = at


static func slide_motion(run: RaidRun, enemy: Dictionary, motion: Vector2) -> Vector2:
	if not enemy.has("combat_id"):
		return motion
	var at: Vector2 = enemy["at"]
	var result := motion
	for index in run._near(at, float(enemy["radius"]) + 4.0 + motion.length()):
		var other: Dictionary = run.enemies[index]
		if int(other["combat_id"]) == int(enemy["combat_id"]) or float(other["hp"]) <= 0.0:
			continue
		var offset: Vector2 = at - Vector2(other["at"])
		var distance := offset.length()
		if distance <= 0.0001:
			continue
		var normal := offset / distance
		var gap := maxf(0.0, distance - float(enemy["radius"]) - float(other["radius"]) - 0.04)
		var approach := -result.dot(normal)
		if approach > gap:
			result += normal * (approach - gap)
	return result
