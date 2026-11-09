class_name RaidMotion
extends RefCounted
## Controlled planar inertia and dissipative pushes. No rigid-body impulses into the boat.
const PUSH_DRAG := 4.5
const MAX_PUSH := 5.0


static func inverse_mass(enemy: Dictionary) -> float:
	var relative := maxf(1.0, float(enemy.get("radius", 1.1)) / 1.1)
	return 1.0 / (relative * relative)


static func _add_push(enemy: Dictionary, impulse: Vector2) -> void:
	if float(enemy["hp"]) <= 0.0 or float(enemy.get("born", 0.0)) > 0.0:
		return
	if RaidContacts.mobility(enemy) <= 0.0:
		return
	if int(enemy.get("kind", 0)) == 1 and float(enemy.get("charge", 0.0)) > 0.0:
		return
	var velocity: Vector2 = enemy.get("push_velocity", Vector2.ZERO)
	enemy["push_velocity"] = (velocity + impulse * inverse_mass(enemy)).limit_length(MAX_PUSH)


static func kick(enemy: Dictionary, origin_at: Vector2, strength: float, reach: float) -> void:
	var offset: Vector2 = Vector2(enemy["at"]) - origin_at
	var distance := offset.length()
	var normal := (
		offset / distance
		if distance > 0.0001
		else Vector2.from_angle(float(enemy.get("combat_id", 0)) * 2.399963)
	)
	var falloff := clampf(
		1.0 - distance / maxf(0.1, reach + float(enemy.get("radius", 1.1))), 0.25, 1.0
	)
	_add_push(enemy, normal * maxf(0.0, strength) * falloff)


static func from_contact(enemy: Dictionary, correction: Vector2, boat_speed: float) -> void:
	if correction.length_squared() <= 0.000001 or absf(boat_speed) <= 1.0:
		return
	_add_push(enemy, correction.normalized() * minf(2.0, absf(boat_speed) * 0.16))


static func step(enemy: Dictionary, target: Vector2, delta: float) -> Vector2:
	if delta <= 0.0:
		return Vector2.ZERO
	if RaidContacts.mobility(enemy) <= 0.0:
		enemy["motion_velocity"] = Vector2.ZERO
		enemy["push_velocity"] = Vector2.ZERO
		enemy["motion_dash"] = false
		target = Vector2.ZERO
	var previous: Vector2 = enemy.get("motion_velocity", Vector2.ZERO)
	var dash := int(enemy["kind"]) == 1 and target.length_squared() > 100.0
	var response := 3.0 if int(enemy["kind"]) == 3 else 6.0
	var decay := exp(-response * delta)
	var displacement := target * delta + (previous - target) * ((1.0 - decay) / response)
	var velocity := target + (previous - target) * decay
	if dash or bool(enemy.get("motion_dash", false)):
		# Preserve the authored dash and stop its extra speed exactly at recovery.
		velocity = target
		displacement = target * delta
	enemy["motion_dash"] = dash
	enemy["motion_velocity"] = velocity
	var push: Vector2 = Vector2.ZERO if dash else enemy.get("push_velocity", Vector2.ZERO)
	var damping := exp(-PUSH_DRAG * delta)
	enemy["push_velocity"] = push * damping
	var field_push: Vector2 = enemy.get("sphere_velocity", Vector2.ZERO)
	var field_decay := exp(-2.2 * delta)
	enemy["sphere_velocity"] = field_push * field_decay
	return (
		displacement
		+ push * ((1.0 - damping) / PUSH_DRAG)
		+ field_push * ((1.0 - field_decay) / 2.2)
	)


static func feedback(enemy: Dictionary, blocked_motion: Vector2) -> void:
	if blocked_motion.length_squared() <= 0.000001:
		return
	var normal := blocked_motion.normalized()
	for key in ["motion_velocity", "push_velocity", "sphere_velocity"]:
		var velocity: Vector2 = enemy.get(key, Vector2.ZERO)
		# Remove the blocked component, never reflect or increase kinetic energy.
		enemy[key] = velocity - normal * maxf(0.0, velocity.dot(normal))


static func move_enemies(run: RaidRun, delta: float) -> void:
	var target := run.boat_at()
	for enemy in run.enemies:
		enemy["previous"] = enemy["at"]
		if float(enemy["hp"]) <= 0.0:
			continue
		if float(enemy["born"]) > 0.0:
			enemy["born"] = maxf(0.0, float(enemy["born"]) - delta)
			continue
		var at: Vector2 = enemy["at"]
		var to_boat := target - at
		var direction := to_boat.normalized()
		var kind: int = enemy["kind"]
		if kind != 3:
			enemy["timer"] = float(enemy["timer"]) - delta
		enemy["flash"] = maxf(0.0, float(enemy["flash"]) - delta)
		var speed := 2.8 + run.elapsed / 180.0
		if kind == 1:
			if float(enemy["charge"]) > 0.0:
				enemy["charge"] = maxf(0.0, float(enemy["charge"]) - delta)
				direction = enemy["aim"]
				speed = 14.0
			elif float(enemy["timer"]) <= 0.0:
				enemy["charge"] = 0.7
				enemy["timer"] = 3.8
			elif float(enemy["timer"]) < 1.1:
				speed = 0.0
				# Lock direction when warning starts, not at the instant of impact.
				if float(enemy["timer"]) > 1.1 - delta:
					enemy["aim"] = direction
		elif kind >= 2:
			speed = 1.8 if kind == 3 else 2.2
			if to_boat.length() < 18.0:
				direction = -direction if to_boat.length() < 12.0 else Vector2.ZERO
			if kind == 3:
				var volley := RaidBoss.step(enemy, delta, target)
				for aim in volley:
					run._add_shot(at, aim * RaidBoss.shell_speed(enemy), 12.0, true)
				if RaidBoss.preparing(enemy):
					direction = Vector2.ZERO
			elif float(enemy["timer"]) <= 0.0:
				run._add_shot(at, to_boat.normalized() * 12.0, 12.0, true)
				enemy["timer"] = 3.8
		var requested := step(enemy, direction * speed, delta)
		var displacement := RaidContacts.slide_motion(run, enemy, requested)
		var clear := Callable(run, "navigable")
		var moved := RaidContacts.safe_move(at, at + displacement, float(enemy["radius"]), clear)
		if (
			moved.is_equal_approx(at)
			and displacement.length_squared() > 0.000001
			and Vector2(enemy.get("sphere_velocity", Vector2.ZERO)).length_squared() < 0.01
		):
			for turn in [-PI * 0.5, PI * 0.5]:
				var slide := RaidContacts.slide_motion(run, enemy, requested.rotated(turn))
				var candidate := RaidContacts.safe_move(
					at, at + slide, float(enemy["radius"]), clear
				)
				if not candidate.is_equal_approx(at):
					moved = candidate
					break
		enemy["at"] = moved

		feedback(enemy, requested - (Vector2(enemy["at"]) - at))


static func sphere_contact(enemy: Dictionary, normal: Vector2, surface_speed: float) -> void:
	# Frictionless finite-mass impact: only the normal component changes.
	# Kept separate from authored dash/push, so dash recovery cannot erase the impulse.
	if float(enemy["hp"]) <= 0.0 or float(enemy.get("born", 0.0)) > 0.0:
		return
	var external: Vector2 = enemy.get("sphere_velocity", Vector2.ZERO)
	var velocity: Vector2 = (
		Vector2(enemy.get("motion_velocity", Vector2.ZERO))
		+ Vector2(enemy.get("push_velocity", Vector2.ZERO))
		+ external
	)
	var closing := surface_speed - velocity.dot(normal)
	if closing <= 0.0:
		return
	var inv_mass := inverse_mass(enemy)
	# Field's effective mass is four light enemies. No per-frame pressure stacking.
	var impulse := minf(24.0, 1.1 * closing / (inv_mass + 0.25))
	enemy["sphere_velocity"] = external + normal * impulse * inv_mass
