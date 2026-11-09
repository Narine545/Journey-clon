class_name RaidRun
extends Node3D
## Independent, bounded survivors prototype. Original implementation, no imported code.
enum State { IDLE, RUNNING, CHOOSING, PAUSED, WON, LOST }
const ENEMY_CAP := 80
const SHOT_CAP := 160
const DURATION := 300.0
const CELL := 8.0
const MOBILITY_MAX_RANK := 3
const SPEED_PER_RANK := 0.12
const TURN_PER_RANK := 0.15
const XP_MAX_RANK := 4
const REROLLS := 2
const COLORS := [Color("ff4b35"), Color("ffe144"), Color("be62ff"), Color("39a9ff")]
const UPGRADES := [
	["Усиленные снаряды", "+8 базового урона орудий"],
	["Скоростные затворы", "До −12% перезарядки орудий"],
	["Бортовая картечь", "+1 снаряд в каждом бортовом залпе"],
	["Резонатор", "+5 м радиуса и +15 урона импульса"],
	["Ремонтная команда", "Восстановить 30% прочности корпуса"],
	["Сборщики трофеев", "+3 м притяжения боевого опыта"],
	["Форсированный двигатель", "+12% базового хода, разгона и торможения"],
	["Усиленный руль", "+15% базовой скорости поворота на ходу"],
	["Кормовые заряды", "Открыть / усилить мины против преследователей"],
	["Опытная команда", "+25% опыта с трофеев до конца рейда"],
	["Пробивной гарпун", "ЭВОЛЮЦИЯ: носовой снаряд пробивает до 3 целей"],
	["Резонансный импульс", "ЭВОЛЮЦИЯ: Q уничтожает вражеские снаряды"],
	["Штормовая картечь", "ЭВОЛЮЦИЯ: широкий бортовой веер, пробитие 2 целей"],
	["Цепной подрыв", "ЭВОЛЮЦИЯ: мины запускают соседние взведённые заряды"],
	["Сферические мины", "Открыть / усилить поле вытеснения. Без урона и щита"],
]
var stats := RaidStats.new()
var effects_enabled := true
var debug_invulnerable := false
var debug_clear_screen := false
var damage_fx: RaidDamageFx
var weapon_fx: RaidWeaponFx
var sphere_mines: SphereMines
var stern_charges: RaidSternCharges
var salvage: RaidSalvage
var hud: RaidHud
var main: BoatMain
var state := State.IDLE
var elapsed := 0.0
var kills := 0
var level := 1
var xp := 0
var xp_needed := 8
var xp_rank := 0
var piercing_harpoon := false
var resonant_pulse := false
var storm_broadside := false
var chain_mines := false
var xp_awarded := 0
var damage := 22.0
var reload_scale := 1.0
var pellets := 1
var speed_rank := 0
var turn_rank := 0
var sphere_rank := 0
var stern_rank := 0
var pulse_radius := 13.0
var pulse_damage := 35.0
var pulse_cooldown := 0.0
var boss_spawned := false
var rerolls_left := REROLLS
var choices: Array[int] = []
var enemies: Array[Dictionary] = []
var shots: Array[Dictionary] = []
var grid: Dictionary = {}
var rng := RandomNumberGenerator.new()
var _xp_quarters := 0
var _next_enemy_id := 0
var _water_cells: Dictionary = {}
var _enemy_batch: MultiMesh
var _shot_batch: MultiMesh
var _elites := RaidElites.new()
var _approaches := RaidApproaches.new()
var _boss_retry := 0.0
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
	salvage = RaidSalvage.new()
	add_child(salvage)
	salvage.setup(self)
	weapon_fx = RaidWeaponFx.new()
	add_child(weapon_fx)
	weapon_fx.setup(self)
	stern_charges = RaidSternCharges.new()
	add_child(stern_charges)
	stern_charges.setup(self)
	sphere_mines = SphereMines.new()
	add_child(sphere_mines)
	sphere_mines.setup(self)
	damage_fx = RaidDamageFx.new()
	add_child(damage_fx)
	damage_fx.setup(self)
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
	xp_rank = 0
	piercing_harpoon = false
	resonant_pulse = false
	storm_broadside = false
	chain_mines = false
	_next_enemy_id = 0
	_elites.reset()
	_approaches.reset()
	stats.reset()
	debug_invulnerable = false
	debug_clear_screen = false
	rerolls_left = REROLLS
	xp_awarded = 0
	_xp_quarters = 0
	damage = 22.0
	reload_scale = 1.0
	pellets = 1
	speed_rank = 0
	turn_rank = 0
	sphere_rank = 0
	stern_rank = 0
	pulse_radius = 13.0
	pulse_damage = 35.0
	pulse_cooldown = 0.0
	boss_spawned = false
	_spawn_timer = 0.0
	_boss_retry = 0.0
	_bow_timer = 0.0
	_side_timer = 0.0
	_hurt_timer = 0.0
	_pulse_flash = 0.0
	enemies.clear()
	shots.clear()
	grid.clear()
	_water_cells.clear()
	choices.clear()
	salvage.reset()
	weapon_fx.reset()
	damage_fx.reset()
	stern_charges.reset()
	sphere_mines.reset()
	hud.refresh()


func restart() -> void:
	leave()
	start()


func leave() -> void:
	if not engaged():
		return
	state = State.IDLE
	xp_rank = 0
	piercing_harpoon = false
	resonant_pulse = false
	storm_broadside = false
	chain_mines = false
	_next_enemy_id = 0
	_elites.reset()
	_approaches.reset()
	stats.reset()
	debug_invulnerable = false
	debug_clear_screen = false
	rerolls_left = REROLLS
	xp_awarded = 0
	_xp_quarters = 0
	speed_rank = 0
	turn_rank = 0
	sphere_rank = 0
	stern_rank = 0
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
	salvage.reset()
	weapon_fx.reset()
	damage_fx.reset()
	stern_charges.reset()
	sphere_mines.reset()
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
	if projectile:
		sphere.material = material
	else:
		var enemy_material := ShaderMaterial.new()
		enemy_material.shader = preload("res://shaders/raid_enemy.gdshader")
		sphere.material = enemy_material
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


func _spawn(kind: int, elite: bool = false) -> bool:
	var replacement := -1
	if enemies.size() >= ENEMY_CAP:
		if kind == 3:
			for index in range(enemies.size()):
				var enemy := enemies[index]
				if not RaidApproaches.on_screen(self, enemy["at"], float(enemy["radius"])):
					replacement = index
					break
		if replacement < 0:
			return false
	var promoted := elite and kind == 1
	var radius := 3.4 if kind == 3 else (1.7 if kind == 2 else 1.1)
	if promoted:
		radius *= RaidElites.RADIUS_SCALE
	for _attempt in range(1):
		var slot := _approaches.next_slot(self)
		if slot.is_empty():
			return false
		var at: Vector2 = slot["at"]
		if elapsed > float(slot["expires"]) or RaidApproaches.on_screen(self, at, radius):
			return false
		if not navigable(at, radius):
			continue
		var crowded := false
		for other in enemies:
			if (
				float(other["hp"]) > 0.0
				and at.distance_to(other["at"]) < radius + float(other["radius"]) + 0.1
			):
				crowded = true
				break
		if crowded:
			continue
		var hp := (650.0 if kind == 3 else 25.0 + kind * 14.0) * (1.0 + elapsed / 400.0)
		if promoted:
			hp *= RaidElites.HP_SCALE
		if replacement >= 0:
			enemies.remove_at(replacement)
		enemies.append(
			{
				"at": at,
				"previous": at,
				"hp": hp,
				"max_hp": hp,
				"kind": kind,
				"elite": promoted,
				"radius": radius,
				"timer": rng.randf_range(1.3, 2.5),
				"charge": 0.0,
				"aim": Vector2.ZERO,
				"flash": 0.0,
				"born": 0.6,
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
	stats.debug_used = stats.debug_used or debug_invulnerable or debug_clear_screen
	elapsed += delta
	weapon_fx.step(delta)
	_hurt_timer = maxf(0.0, _hurt_timer - delta)
	pulse_cooldown = maxf(0.0, pulse_cooldown - delta)
	_pulse_flash = maxf(0.0, _pulse_flash - delta)
	# Recycle only combat enemies, never fixed pigment resources. No XP for leaving.
	_spawn_timer -= delta
	_step_elites()
	if _spawn_timer <= 0.0 and not RaidWaves.respite(elapsed):
		_spawn_timer = RaidWaves.interval(elapsed)
		var ranged_count := 0
		for enemy in enemies:
			if int(enemy["kind"]) == 2 and float(enemy["hp"]) > 0.0:
				ranged_count += 1
		_spawn(RaidWaves.choose_kind(elapsed, ranged_count, rng.randf()))
	# Warning begins at 225s. Reserve room for boss even at the population cap.
	_boss_retry = maxf(0.0, _boss_retry - delta)
	if elapsed >= 240.0 and not boss_spawned and _boss_retry <= 0.0:
		_boss_retry = 1.0
		boss_spawned = _spawn(3)
	_debug_clear_visible()
	_rebuild_grid()
	_move_enemies(delta)
	RaidContacts.resolve(self, delta)
	RaidBuoyancy.step_enemies(enemies, delta, main.water)
	_rebuild_grid()
	stern_charges.step(delta)
	sphere_mines.step(delta)
	_fire_weapons(delta)
	_move_shots(delta)
	for index in range(enemies.size() - 1, -1, -1):
		if float(enemies[index]["hp"]) <= 0.0:
			var kind: int = enemies[index]["kind"]
			if kind != 3:
				salvage.drop(enemies[index]["at"], RaidElites.reward(enemies[index]))
			enemies.remove_at(index)
			kills += 1
			if kind == 3:
				_finish(State.WON)
				return
	credit_xp(salvage.step(delta))
	if main.boat.hull_hp <= 0.0:
		_finish(State.LOST)
	elif elapsed >= DURATION:
		_finish(State.LOST)
	elif xp >= xp_needed:
		_offer_upgrade()


func _debug_clear_visible() -> void:
	if not debug_clear_screen or state != State.RUNNING or main.inspection_active():
		return
	for enemy in enemies:
		if float(enemy["hp"]) <= 0.0:
			continue
		var at: Vector2 = enemy["at"]
		var world_at := Vector3(at.x, Coast.SEA_LEVEL + 1.0, at.y)
		if main.camera.is_position_in_frustum(world_at):
			enemy["hp"] = 0.0


func _step_elites() -> void:
	if not _elites.due(elapsed, enemies):
		return
	var spawned := _spawn(1, true)
	_elites.attempted(elapsed, spawned)
	if spawned:
		# Replace this tick's ordinary spawn; never add a burst on top of it.
		_spawn_timer = maxf(_spawn_timer, RaidWaves.interval(elapsed))


func _move_enemies(delta: float) -> void:
	RaidMotion.move_enemies(self, delta)


func _cell(at: Vector2) -> Vector2i:
	return Vector2i(floori(at.x / CELL), floori(at.y / CELL))


func _rebuild_grid() -> void:
	grid.clear()
	for index in range(enemies.size()):
		if not enemies[index].has("combat_id"):
			enemies[index]["combat_id"] = _next_enemy_id
			_next_enemy_id += 1
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
		# One flash per mount/salvo, not per pellet. No extra light source.
		if shots.size() < SHOT_CAP:
			weapon_fx.emit(weapon, aim)
		for pellet in range(1 if weapon == 0 else pellets):
			var spread := 0.26 if storm_broadside else 0.13
			var angle := (float(pellet) - float(pellets - 1) * 0.5) * spread if weapon > 0 else 0.0
			_add_shot(
				boat_at() + axis * 3.0,
				aim.rotated(angle) * 38.0,
				damage if weapon == 0 else damage * 0.7,
				false,
				_weapon_hit_limit(weapon),
				RaidStats.Channel.NOSE if weapon == 0 else RaidStats.Channel.SIDES
			)
		if weapon == 0:
			_bow_timer = 0.65 * reload_scale
	# Both sides share one salvo clock, but both get evaluated before resetting it.
	if _side_timer <= 0.0:
		_side_timer = 1.25 * reload_scale


func _add_shot(
	at: Vector2,
	velocity: Vector2,
	power: float,
	hostile: bool,
	hit_limit: int = 1,
	channel: int = RaidStats.Channel.NOSE
) -> void:
	if shots.size() < SHOT_CAP:
		shots.append(
			{
				"at": at,
				"previous": at,
				"velocity": velocity,
				"power": power,
				"channel": channel,
				"hostile": hostile,
				"hits_left": clampi(hit_limit, 1, 3),
				"hit_ids": [],
				"piercing": not hostile and hit_limit > 1,
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
					_hurt(float(shot["power"]), RaidStats.Cause.SHELL)
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
						and not shot["hit_ids"].has(enemy["combat_id"])
						and distance < float(enemy["radius"]) + 0.3
						and distance < best_distance
					):
						best_distance = distance
						victim = enemy_index
				if victim >= 0:
					stats.record_damage(
						int(shot.get("channel", RaidStats.Channel.NOSE)),
						float(enemies[victim]["hp"]),
						float(shot["power"])
					)
					enemies[victim]["hp"] = float(enemies[victim]["hp"]) - float(shot["power"])
					enemies[victim]["flash"] = 0.12
					shot["hit_ids"].append(enemies[victim]["combat_id"])
					shot["hits_left"] = int(shot["hits_left"]) - 1
					if int(shot["hits_left"]) <= 0:
						consumed = true
						break
		if consumed or float(shot["life"]) <= 0.0:
			shots.remove_at(index)


func _hurt(amount: float, cause: int = RaidStats.Cause.CONTACT) -> void:
	if debug_invulnerable or _hurt_timer > 0.0:
		return
	main.boat.apply_hull_damage(amount, cause)
	_hurt_timer = 0.65


func pulse() -> void:
	if state != State.RUNNING or main.inspection_active() or pulse_cooldown > 0.0:
		return
	for enemy in enemies:
		if boat_at().distance_to(enemy["at"]) < pulse_radius + float(enemy["radius"]):
			stats.record_damage(RaidStats.Channel.PULSE, float(enemy["hp"]), pulse_damage)
			enemy["hp"] = float(enemy["hp"]) - pulse_damage
			enemy["flash"] = 0.25
			RaidMotion.kick(enemy, boat_at(), 4.0, pulse_radius)
	if resonant_pulse:
		for index in range(shots.size() - 1, -1, -1):
			if (
				bool(shots[index]["hostile"])
				and boat_at().distance_to(shots[index]["at"]) <= pulse_radius
			):
				shots.remove_at(index)
	stats.pulses += 1
	pulse_cooldown = 9.0
	_pulse_flash = 0.5


func _upgrade_pool() -> Array[int]:
	var available: Array[int] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
	if sphere_rank < 3:
		available.append(14)
	if can_evolve_harpoon():
		available.append(10)
	if can_evolve_pulse():
		available.append(11)
	if _can_evolve_broadside():
		available.append(12)
	if _can_evolve_chain():
		available.append(13)
	if xp_rank >= XP_MAX_RANK:
		available.erase(9)
	if stern_rank >= 3:
		available.erase(8)
	if speed_rank >= MOBILITY_MAX_RANK:
		available.erase(6)
	if turn_rank >= MOBILITY_MAX_RANK:
		available.erase(7)
	if main.boat.hull_hp >= 100.0:
		available.erase(4)
	if pellets >= 5:
		available.erase(2)
	if reload_scale <= 0.38:
		available.erase(1)
	return available


func _can_reroll() -> bool:
	if state != State.CHOOSING or rerolls_left <= 0:
		return false
	for kind in _upgrade_pool():
		if not choices.has(kind):
			return true
	return false


func _reroll_choices() -> void:
	if not _can_reroll():
		return
	var previous: Array[int] = choices.duplicate()
	_deal_choices(previous)
	rerolls_left -= 1
	hud.refresh()


func _offer_upgrade() -> void:
	state = State.CHOOSING
	_deal_choices([])
	hud.refresh()


func _deal_choices(previous: Array[int]) -> void:
	var available := _upgrade_pool()
	var fresh: Array[int] = []
	for kind in available:
		if not previous.has(kind):
			fresh.append(kind)
	choices.clear()
	if not previous.is_empty() and not fresh.is_empty():
		var forced: int = fresh[rng.randi_range(0, fresh.size() - 1)]
		choices.append(forced)
		available.erase(forced)
	while choices.size() < 3:
		var index := rng.randi_range(0, available.size() - 1)
		choices.append(available.pop_at(index))


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
			stats.repairs += 1
			stats.repaired += minf(30.0, 100.0 - main.boat.hull_hp)
			main.boat.hull_hp = minf(100.0, main.boat.hull_hp + 30.0)
		5:
			salvage.magnet_range += 3.0
		6:
			speed_rank = mini(MOBILITY_MAX_RANK, speed_rank + 1)
		7:
			turn_rank = mini(MOBILITY_MAX_RANK, turn_rank + 1)
		8:
			if stern_rank == 0:
				stats.stern_unlocked_at = elapsed
			stern_rank = mini(3, stern_rank + 1)
		9:
			xp_rank = mini(XP_MAX_RANK, xp_rank + 1)
		10:
			if not can_evolve_harpoon():
				return
			piercing_harpoon = true
		11:
			if not can_evolve_pulse():
				return
			resonant_pulse = true
		12:
			if not _can_evolve_broadside():
				return
			storm_broadside = true
		13:
			if not _can_evolve_chain():
				return
			chain_mines = true
		14:
			sphere_rank = mini(3, sphere_rank + 1)
	if choices[index] >= 10 and choices[index] <= 13:
		stats.record_evolution(choices[index], elapsed)
	xp -= xp_needed
	level += 1
	xp_needed = 8 + (level - 1) * 5
	choices.clear()
	state = State.RUNNING
	if xp >= xp_needed:
		_offer_upgrade()
	hud.refresh()


func upgrade_preview(kind: int) -> String:
	var preview := ""
	match kind:
		0:
			preview = (
				"Нос: %.0f → %.0f\nБорт: %.1f → %.1f"
				% [damage, damage + 8.0, damage * 0.7, (damage + 8.0) * 0.7]
			)
		1:
			var next_scale := maxf(0.35, reload_scale * 0.88)
			preview = (
				"Нос: %.2f → %.2f с\nБорта: %.2f → %.2f с"
				% [0.65 * reload_scale, 0.65 * next_scale, 1.25 * reload_scale, 1.25 * next_scale]
			)
		2:
			preview = "Залп с борта: %d → %d" % [pellets, pellets + 1]
		3:
			preview = (
				"Радиус: %.0f → %.0f м\nУрон: %.0f → %.0f"
				% [pulse_radius, pulse_radius + 5.0, pulse_damage, pulse_damage + 15.0]
			)
		4:
			preview = (
				"Корпус: %.0f → %.0f%%" % [main.boat.hull_hp, minf(100.0, main.boat.hull_hp + 30.0)]
			)
		5:
			preview = "Радиус: %.0f → %.0f м" % [salvage.magnet_range, salvage.magnet_range + 3.0]
		6:
			preview = (
				"Ход: ×%.2f → ×%.2f\nРазгон / тормоз: так же"
				% [
					speed_multiplier(),
					1.0 + float(mini(MOBILITY_MAX_RANK, speed_rank + 1)) * SPEED_PER_RANK
				]
			)
		7:
			preview = (
				"Поворот: ×%.2f → ×%.2f"
				% [
					turn_multiplier(),
					1.0 + float(mini(MOBILITY_MAX_RANK, turn_rank + 1)) * TURN_PER_RANK
				]
			)
		8:
			var next_rank := mini(3, stern_rank + 1)
			preview = (
				"Урон: %.0f → %.0f\nРадиус: %.0f → %.0f м\nСброс: %.1f с"
				% [
					RaidSternCharges.power(stern_rank),
					RaidSternCharges.power(next_rank),
					RaidSternCharges.radius(stern_rank),
					RaidSternCharges.radius(next_rank),
					RaidSternCharges.interval(next_rank)
				]
			)
		9:
			preview = (
				"Опыт: ×%.2f → ×%.2f"
				% [xp_multiplier(), 1.0 + float(mini(XP_MAX_RANK, xp_rank + 1)) * 0.25]
			)
		10:
			preview = "Целей одним носовым\nснарядом: 1 → 3\nУрон не снижается"
		11:
			preview = (
				"Q: урон + перехват\nРадиус перехвата: %.0f м\nПерезарядка: 9 с" % pulse_radius
			)
		12:
			preview = "Веер бортов: ×2 шире\nЦелей снарядом: 1 → 2\nУрон и темп прежние"
		13:
			preview = "Новые мины: цепной подрыв\nПередача: до 8 м, 0.20 с\nТолько взведённые, без преград"
		14:
			var next_sphere := mini(3, sphere_rank + 1)
			preview = ("Ранг: %d → %d / 3\nРадиус: %.2f м · сброс: %.1f с\nОдно поле · без урона"
				% [sphere_rank, next_sphere, SphereMines.radius(next_sphere),
				SphereMines.interval(next_sphere)])
	return preview


func can_evolve_harpoon() -> bool:
	return not piercing_harpoon and damage >= 46.0 and reload_scale <= 0.78


func can_evolve_pulse() -> bool:
	return not resonant_pulse and pulse_radius >= 23.0 and salvage.magnet_range >= 16.0


func _can_evolve_broadside() -> bool:
	return not storm_broadside and pellets >= 3 and turn_rank >= 1


func _can_evolve_chain() -> bool:
	return not chain_mines and stern_rank >= 3 and pulse_radius >= 18.0


func _weapon_hit_limit(weapon: int) -> int:
	if weapon > 0 and storm_broadside:
		return 2
	return 3 if weapon == 0 and piercing_harpoon else 1


func xp_multiplier() -> float:
	return 1.0 + float(xp_rank) * 0.25


func credit_xp(amount: int) -> void:
	if amount <= 0:
		return
	# Quarter-XP carry avoids rounding 2 * 1.25 down on every small trophy.
	var units := amount * (4 + xp_rank) + _xp_quarters
	var gained := floori(float(units) * 0.25)
	_xp_quarters = units % 4
	xp += gained
	xp_awarded += gained


func speed_multiplier() -> float:
	return 1.0 + float(speed_rank) * SPEED_PER_RANK


func turn_multiplier() -> float:
	return 1.0 + float(turn_rank) * TURN_PER_RANK


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


func _enemy_visual_color(enemy: Dictionary) -> Color:
	var tint: Color = COLORS[int(enemy["kind"])]
	# Keep archetype hue even during frequent hits; never flatten the whole enemy to white.
	return tint.lerp(Color.WHITE, 0.25) if float(enemy["flash"]) > 0.0 else tint


func _enemy_visual_basis(enemy: Dictionary, radius: float) -> Basis:
	var kind: int = enemy["kind"]
	var proportions := Vector3(1.0, 0.65, 1.0)
	var yaw := 0.0
	if kind == 1:
		proportions = Vector3(0.65, 0.70, 1.0)
		var direction: Vector2 = boat_at() - enemy["at"]
		if float(enemy.get("charge", 0.0)) > 0.0 or float(enemy.get("timer", 2.0)) < 1.1:
			var locked: Vector2 = enemy.get("aim", Vector2.ZERO)
			if locked.length_squared() > 0.0001:
				direction = locked
		yaw = atan2(-direction.x, -direction.y)
	elif kind == 2:
		proportions = Vector3(0.85, 1.15, 0.85)
	elif kind == 3:
		proportions = Vector3(1.0, 0.85, 1.0)
	return Basis(Vector3.UP, yaw) * Basis.from_scale(proportions * radius)


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
		salvage.render(blend, elapsed)
		weapon_fx.render()
		stern_charges.render(blend)
		for index in range(enemies.size()):
			var enemy := enemies[index]
			var at: Vector2 = enemy["previous"].lerp(enemy["at"], blend)
			var radius: float = float(enemy["radius"]) * (1.0 - float(enemy["born"]) * 1.3)
			var floating := RaidBuoyancy.pose(enemy, blend, Coast.SEA_LEVEL + 1.0)
			var enemy_basis := (
				RaidBuoyancy.tilt_basis(floating) * _enemy_visual_basis(enemy, radius)
			)
			_enemy_batch.set_instance_transform(
				index, Transform3D(enemy_basis, Vector3(at.x, floating.x, at.y))
			)
			_enemy_batch.set_instance_color(index, _enemy_visual_color(enemy))
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
				index,
				(
					Color("ff6f99")
					if bool(shot["hostile"])
					else (Color("ffd589") if bool(shot["piercing"]) else Color("a5ffe3"))
				)
			)
		_shot_batch.visible_instance_count = shots.size()
	hud.queue_redraw()
