class_name RaidRun
extends Node3D
## Independent, bounded survivors prototype. Original implementation, no imported code.
enum State { IDLE, RUNNING, CHOOSING, PAUSED, WON, LOST }
const ENEMY_CAP := 80
const SHOT_CAP := 160
const DURATION := 300.0
const CELL := 8.0
const COLORS := [Color("d5806d"), Color("ffcb76"), Color("bb97e9"), Color("f05c75")]
const UPGRADES := [
	["Усиленные снаряды", "+8 базового урона орудий"],
	["Скоростные затворы", "−12% перезарядки обоих орудий"],
	["Бортовая картечь", "+1 снаряд в каждом бортовом залпе"],
	["Резонатор", "+5 м радиуса и +15 урона импульса"],
	["Ремонтная команда", "Восстановить 30% прочности корпуса"],
]
var hud: RaidHud
var main: BoatMain
var state := State.IDLE
var elapsed := 0.0
var kills := 0
var level := 1
var xp := 0
var xp_needed := 8
var damage := 22.0
var reload_scale := 1.0
var pellets := 1
var pulse_radius := 13.0
var pulse_damage := 35.0
var pulse_cooldown := 0.0
var boss_spawned := false
var choices: Array[int] = []
var enemies: Array[Dictionary] = []
var shots: Array[Dictionary] = []
var grid: Dictionary = {}
var rng := RandomNumberGenerator.new()
var _water_cells: Dictionary = {}
var _enemy_batch: MultiMesh
var _shot_batch: MultiMesh
var _spawn_timer := 0.0
var _bow_timer := 0.0
var _side_timer := 0.0
var _hurt_timer := 0.0
var _saved_hp := 100.0
var _saved_debug := true
var _pulse_flash := 0.0


func setup(scene: BoatMain) -> void:
	main = scene
	rng.randomize()
	_enemy_batch = _batch(ENEMY_CAP, false)
	_shot_batch = _batch(SHOT_CAP, true)
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	hud = RaidHud.new()
	hud.run = self
	layer.add_child(hud)
	hud.setup()


func engaged() -> bool:
	return state != State.IDLE


func modal() -> bool:
	return engaged() and state != State.RUNNING


func start() -> void:
	if engaged() or main.inspection_active():
		return
	if (
		main.harbor.moored
		or main.coast.water_depth(main.boat.position.x, main.boat.position.z) < 3.5
	):
		main.announce("Для рейда выйдите из причала на глубокую воду.")
		return
	_saved_hp = main.boat.hull_hp
	_saved_debug = main.debug_panel_visible
	main.debug_panel_visible = false
	main.boat.hull_hp = 100.0
	state = State.RUNNING
	elapsed = 0.0
	kills = 0
	level = 1
	xp = 0
	xp_needed = 8
	damage = 22.0
	reload_scale = 1.0
	pellets = 1
	pulse_radius = 13.0
	pulse_damage = 35.0
	pulse_cooldown = 0.0
	boss_spawned = false
	_spawn_timer = 0.0
	_bow_timer = 0.0
	_side_timer = 0.0
	_hurt_timer = 0.0
	_pulse_flash = 0.0
	enemies.clear()
	shots.clear()
	grid.clear()
	_water_cells.clear()
	choices.clear()
	hud.refresh()


func restart() -> void:
	leave()
	start()


func leave() -> void:
	if not engaged():
		return
	state = State.IDLE
	main.boat.hull_hp = _saved_hp
	main.boat.speed = 0.0
	main.debug_panel_visible = _saved_debug
	enemies.clear()
	shots.clear()
	grid.clear()
	_water_cells.clear()
	choices.clear()
	_enemy_batch.visible_instance_count = 0
	_shot_batch.visible_instance_count = 0
	hud.refresh()


func _batch(capacity: int, projectile: bool) -> MultiMesh:
	var sphere := SphereMesh.new()
	sphere.radius = 0.22 if projectile else 1.0
	sphere.height = 0.44 if projectile else 2.0
	sphere.radial_segments = 8
	sphere.rings = 4
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sphere.material = material
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.use_colors = true
	batch.mesh = sphere
	batch.instance_count = capacity
	batch.visible_instance_count = 0
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = batch
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	return batch


func boat_at() -> Vector2:
	return Vector2(main.boat.global_position.x, main.boat.global_position.z)


func forward() -> Vector2:
	return Vector2(-sin(main.boat.rotation.y), -cos(main.boat.rotation.y))


func navigable(at: Vector2, radius: float = 1.0) -> bool:
	if not (
		Rect2(Coast.CENTER - Vector2.ONE * Coast.SIZE * 0.5, Vector2.ONE * Coast.SIZE)
		. grow(-8.0)
		. has_point(at)
	):
		return false
	for offset in [
		Vector2.ZERO,
		Vector2(radius, 0),
		Vector2(-radius, 0),
		Vector2(0, radius),
		Vector2(0, -radius)
	]:
		var p: Vector2 = at + offset
		var key := Vector2i(floori(p.x * 2.0), floori(p.y * 2.0))
		if not _water_cells.has(key):
			# Half-metre cache, conservative depth margin; refreshed for every raid.
			var center := (Vector2(key) + Vector2.ONE * 0.5) * 0.5
			_water_cells[key] = main.coast.water_depth(center.x, center.y) >= 2.5
		if not bool(_water_cells[key]):
			return false
	if main.harbor.blocks_hull(at, 0.0, radius, radius):
		return false
	for reef in main.reefs:
		if at.distance_to(reef["pos"]) < float(reef["radius"]) + radius:
			return false
	return true


func _spawn(kind: int) -> bool:
	if enemies.size() >= ENEMY_CAP:
		return false
	var radius := 3.4 if kind == 3 else (1.7 if kind == 2 else 1.1)
	for _attempt in range(24):
		var at := (
			boat_at() + Vector2.from_angle(rng.randf_range(-PI, PI)) * rng.randf_range(36.0, 48.0)
		)
		if not navigable(at, radius):
			continue
		var hp := (650.0 if kind == 3 else 25.0 + kind * 14.0) * (1.0 + elapsed / 400.0)
		enemies.append(
			{
				"at": at,
				"previous": at,
				"hp": hp,
				"max_hp": hp,
				"kind": kind,
				"radius": radius,
				"timer": rng.randf_range(1.3, 2.5),
				"charge": 0.0,
				"aim": Vector2.ZERO,
				"flash": 0.0,
				"born": 0.6
			}
		)
		return true
	return false


func _physics_process(delta: float) -> void:
	if main == null or state != State.RUNNING or main.inspection_active():
		return
	if main.boat.hull_hp <= 0.0:
		_finish(State.LOST)
		return
	elapsed += delta
	_hurt_timer = maxf(0.0, _hurt_timer - delta)
	pulse_cooldown = maxf(0.0, pulse_cooldown - delta)
	_pulse_flash = maxf(0.0, _pulse_flash - delta)
	# Recycle only combat enemies, never fixed pigment resources. No XP for leaving.
	for index in range(enemies.size() - 1, -1, -1):
		if int(enemies[index]["kind"]) != 3 and boat_at().distance_to(enemies[index]["at"]) > 100.0:
			enemies.remove_at(index)
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_timer = maxf(0.24, 1.15 - elapsed / 330.0)
		_spawn(0 if elapsed < 15.0 else rng.randi_range(0, 2))
	# Warning begins at 225s. Reserve room for boss even at the population cap.
	if elapsed >= 240.0 and not boss_spawned:
		if enemies.size() >= ENEMY_CAP:
			enemies.remove_at(0)
		boss_spawned = _spawn(3)
	_move_enemies(delta)
	_rebuild_grid()
	_fire_weapons(delta)
	_move_shots(delta)
	for index in range(enemies.size() - 1, -1, -1):
		if float(enemies[index]["hp"]) <= 0.0:
			var kind: int = enemies[index]["kind"]
			enemies.remove_at(index)
			kills += 1
			xp += 4 if kind == 2 else 2
			if kind == 3:
				_finish(State.WON)
				return
	if main.boat.hull_hp <= 0.0:
		_finish(State.LOST)
	elif elapsed >= DURATION:
		_finish(State.LOST)
	elif xp >= xp_needed:
		_offer_upgrade()


func _move_enemies(delta: float) -> void:
	var target := boat_at()
	for enemy in enemies:
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
		enemy["timer"] = float(enemy["timer"]) - delta
		enemy["flash"] = maxf(0.0, float(enemy["flash"]) - delta)
		var speed := 2.8 + elapsed / 180.0
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
			if float(enemy["timer"]) <= 0.0:
				for spread in [-0.25, 0.0, 0.25] if kind == 3 else [0.0]:
					_add_shot(at, to_boat.normalized().rotated(float(spread)) * 12.0, 12.0, true)
				enemy["timer"] = 2.6 if kind == 3 else 3.8
		var step := direction * speed * delta
		if navigable(at + step, float(enemy["radius"])):
			enemy["at"] = at + step
		else:
			for turn in [-PI * 0.5, PI * 0.5]:
				var slide := at + step.rotated(turn)
				if navigable(slide, float(enemy["radius"])):
					enemy["at"] = slide
					break
		if _hull_distance(enemy["at"]) < float(enemy["radius"]):
			_hurt(9.0 if kind < 3 else 20.0)


func _cell(at: Vector2) -> Vector2i:
	return Vector2i(floori(at.x / CELL), floori(at.y / CELL))


func _rebuild_grid() -> void:
	grid.clear()
	for index in range(enemies.size()):
		var key := _cell(enemies[index]["at"])
		if not grid.has(key):
			grid[key] = []
		grid[key].append(index)


func _near(at: Vector2, radius: float) -> Array[int]:
	var result: Array[int] = []
	var lo := _cell(at - Vector2.ONE * radius)
	var hi := _cell(at + Vector2.ONE * radius)
	for x in range(lo.x, hi.x + 1):
		for y in range(lo.y, hi.y + 1):
			for index in grid.get(Vector2i(x, y), []):
				result.append(int(index))
	return result


func _fire_weapons(delta: float) -> void:
	_bow_timer -= delta
	_side_timer -= delta
	var bow := forward()
	for weapon in range(3):
		if (weapon == 0 and _bow_timer > 0.0) or (weapon > 0 and _side_timer > 0.0):
			continue
		var axis := bow if weapon == 0 else bow.rotated(PI * 0.5 if weapon == 1 else -PI * 0.5)
		var nearest := 29.0
		var chosen := -1
		for index in _near(boat_at(), 30.0):
			var offset: Vector2 = enemies[index]["at"] - boat_at()
			if (
				float(enemies[index]["hp"]) > 0.0
				and offset.length() < nearest
				and axis.dot(offset.normalized()) > 0.65
			):
				nearest = offset.length()
				chosen = index
		if chosen < 0:
			continue
		var aim: Vector2 = (enemies[chosen]["at"] - boat_at()).normalized()
		for pellet in range(1 if weapon == 0 else pellets):
			var angle := (float(pellet) - float(pellets - 1) * 0.5) * 0.13 if weapon > 0 else 0.0
			_add_shot(
				boat_at() + axis * 3.0,
				aim.rotated(angle) * 38.0,
				damage if weapon == 0 else damage * 0.7,
				false
			)
		if weapon == 0:
			_bow_timer = 0.65 * reload_scale
	# Both sides share one salvo clock, but both get evaluated before resetting it.
	if _side_timer <= 0.0:
		_side_timer = 1.25 * reload_scale


func _add_shot(at: Vector2, velocity: Vector2, power: float, hostile: bool) -> void:
	if shots.size() < SHOT_CAP:
		shots.append(
			{
				"at": at,
				"previous": at,
				"velocity": velocity,
				"power": power,
				"hostile": hostile,
				"life": 3.5 if hostile else 0.9
			}
		)


static func segment_distance(at: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((at - a).dot(ab) / maxf(ab.length_squared(), 0.000001), 0.0, 1.0)
	return at.distance_to(a + ab * t)


func _hull_distance(at: Vector2) -> float:
	var bow := forward()
	var distance := segment_distance(at, boat_at() - bow * 3.7, boat_at() + bow * 3.7) - 1.7
	if main.boat.has_trailer and main.boat._trailer != null:
		var trailer := main.boat._trailer
		var center := Vector2(trailer.global_position.x, trailer.global_position.z)
		var axis := Vector2(-sin(trailer.global_rotation.y), -cos(trailer.global_rotation.y))
		distance = minf(
			distance, segment_distance(at, center - axis * 1.6, center + axis * 1.6) - 1.5
		)
	return distance


func _move_shots(delta: float) -> void:
	for index in range(shots.size() - 1, -1, -1):
		var shot := shots[index]
		var previous: Vector2 = shot["at"]
		var next: Vector2 = previous + shot["velocity"] * delta
		shot["previous"] = previous
		shot["at"] = next
		shot["life"] = float(shot["life"]) - delta
		var consumed := false
		# Ordered subsegments: no tunnelling, no hits through terrain or behind cover.
		var steps := maxi(1, ceili(previous.distance_to(next) / 0.45))
		var candidates: Array[int] = []
		if not bool(shot["hostile"]):
			candidates = _near((previous + next) * 0.5, previous.distance_to(next) * 0.5 + 4.0)
		for step in range(1, steps + 1):
			var p := previous.lerp(next, float(step) / float(steps))
			if not navigable(p, 0.1):
				consumed = true
				break
			if bool(shot["hostile"]):
				if _hull_distance(p) < 0.4:
					_hurt(float(shot["power"]))
					consumed = true
					break
			else:
				var best_distance := INF
				var victim := -1
				for enemy_index in candidates:
					var enemy := enemies[enemy_index]
					var at: Vector2 = enemy["at"]
					var distance := at.distance_to(p)
					if (
						float(enemy["hp"]) > 0.0
						and distance < float(enemy["radius"]) + 0.3
						and distance < best_distance
					):
						best_distance = distance
						victim = enemy_index
				if victim >= 0:
					enemies[victim]["hp"] = float(enemies[victim]["hp"]) - float(shot["power"])
					enemies[victim]["flash"] = 0.12
					consumed = true
					break
		if consumed or float(shot["life"]) <= 0.0:
			shots.remove_at(index)


func _hurt(amount: float) -> void:
	if _hurt_timer > 0.0:
		return
	main.boat.apply_hull_damage(amount)
	_hurt_timer = 0.65


func pulse() -> void:
	if state != State.RUNNING or main.inspection_active() or pulse_cooldown > 0.0:
		return
	for enemy in enemies:
		if boat_at().distance_to(enemy["at"]) < pulse_radius + float(enemy["radius"]):
			enemy["hp"] = float(enemy["hp"]) - pulse_damage
			enemy["flash"] = 0.25
	pulse_cooldown = 9.0
	_pulse_flash = 0.5


func _offer_upgrade() -> void:
	state = State.CHOOSING
	choices.clear()
	var available: Array[int] = [0, 1, 2, 3, 4]
	if pellets >= 5:
		available.erase(2)
	if reload_scale <= 0.38:
		available.erase(1)
	while choices.size() < 3:
		var index := rng.randi_range(0, available.size() - 1)
		choices.append(available.pop_at(index))
	hud.refresh()


func choose(index: int) -> void:
	if state != State.CHOOSING or index < 0 or index >= choices.size():
		return
	match choices[index]:
		0:
			damage += 8.0
		1:
			reload_scale = maxf(0.35, reload_scale * 0.88)
		2:
			pellets += 1
		3:
			pulse_radius += 5.0
			pulse_damage += 15.0
		4:
			main.boat.hull_hp = minf(100.0, main.boat.hull_hp + 30.0)
	xp -= xp_needed
	level += 1
	xp_needed = 8 + (level - 1) * 5
	choices.clear()
	state = State.RUNNING
	if xp >= xp_needed:
		_offer_upgrade()
	hud.refresh()


func toggle_pause() -> void:
	if state == State.RUNNING:
		state = State.PAUSED
	elif state == State.PAUSED:
		state = State.RUNNING
	hud.refresh()


func _finish(result: State) -> void:
	state = result
	main.boat.speed = 0.0
	hud.refresh()


func _unhandled_input(event: InputEvent) -> void:
	if not engaged() or main.inspection_active():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_ESCAPE:
			toggle_pause()
			get_viewport().set_input_as_handled()
		elif event.physical_keycode == KEY_Q:
			pulse()
			get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if main == null:
		return
	hud.visible = not main.inspection_active()
	if engaged():
		var blend := (
			1.0
			if modal() or main.inspection_active()
			else Engine.get_physics_interpolation_fraction()
		)
		for index in range(enemies.size()):
			var enemy := enemies[index]
			var at: Vector2 = enemy["previous"].lerp(enemy["at"], blend)
			var radius: float = float(enemy["radius"]) * (1.0 - float(enemy["born"]) * 1.3)
			var enemy_basis := Basis.IDENTITY.scaled(Vector3(radius, radius * 0.65, radius))
			_enemy_batch.set_instance_transform(
				index, Transform3D(enemy_basis, Vector3(at.x, Coast.SEA_LEVEL + 1.0, at.y))
			)
			_enemy_batch.set_instance_color(
				index, Color.WHITE if float(enemy["flash"]) > 0.0 else COLORS[int(enemy["kind"])]
			)
		_enemy_batch.visible_instance_count = enemies.size()
		for index in range(shots.size()):
			var shot := shots[index]
			var at: Vector2 = shot["previous"].lerp(shot["at"], blend)
			_shot_batch.set_instance_transform(
				index,
				Transform3D(
					Basis.IDENTITY.scaled(
						Vector3(1.5, 1.5, 1.5) if bool(shot["hostile"]) else Vector3.ONE
					),
					Vector3(at.x, Coast.SEA_LEVEL + 1.1, at.y)
				)
			)
			_shot_batch.set_instance_color(
				index, Color("ff6f99") if bool(shot["hostile"]) else Color("a5ffe3")
			)
		_shot_batch.visible_instance_count = shots.size()
	hud.queue_redraw()
