class_name Player
extends Node3D
## Путник. Аналитическая кинематика по полю высот террейна:
## вниз по склону разгоняемся, в гору — теряем ход, на крутом спуске — «сёрф».
## Никакой смерти, таймеров и провалов — только движение.
##
## Походка и песок связаны накрепко: шаг (фаза покачивания тела) рождает
## отпечаток стопы в SandField, лёгкую пыль и звук; сёрф режет непрерывную
## борозду; посадка вдавливает песок. Путник ходит ПО поверхности дюн
## вместе со всеми своими следами (terrain.ground_height).

const GRAVITY := 26.0
const WALK_ACCEL := 34.0
const WALK_MAX := 6.2 # неспешная рысь — следы успевают читаться
const SURF_MAX := 17.5
const JUMP_V := 8.6
const GLIDE_G := 5.5 # гравитация при парении
const AIR_ACCEL := 6.0

const SURF_TRACK_SPEED := 10.8 # выше этой скорости — не шаги, а борозда

const BOUND_X := 150.0
const BOUND_Z_MIN := -445.0
const BOUND_Z_MAX := 50.0

var vel := Vector3.ZERO
var grounded := true
var heading := PI # старт лицом к маяку (-Z)
var surf01 := 0.0 # 0..1 — насколько мы «сёрфим» (камера, музыка, эффекты)
var gliding := false

var game
var terrain: Terrain
var sand: SandField
var audio # SoundScape (подключается после создания)
var visual: Node3D

var _gait_phase := 0.0 # фаза шага: π = постановка стопы
var _last_step_idx := 0
var _foot_side := 1.0
var _squash := 0.0
var _air_time := 0.0 # секунд с последнего касания земли
var _track_on := false
var _track_last := Vector2.ZERO
var _surf_sparks: CPUParticles3D
var _land_dust: CPUParticles3D
var _step_dust: CPUParticles3D


func setup(game_ref, terrain_ref: Terrain, sand_ref: SandField) -> void:
	game = game_ref
	terrain = terrain_ref
	sand = sand_ref
	global_position = Vector3(
		Terrain.SPAWN.x,
		terrain.sample_height(Terrain.SPAWN.x, Terrain.SPAWN.y),
		Terrain.SPAWN.y
	)
	_build_body()
	_build_fx()


func _build_fx() -> void:
	# брызги песка из-под ног на настоящем сёрфе: вытянутые золотые
	# чёрточки (не круглые облачка!), короткая жизнь. local_coords
	# по умолчанию false — частицы остаются в мире позади путника.
	_surf_sparks = CPUParticles3D.new()
	_surf_sparks.amount = 70
	_surf_sparks.lifetime = 0.28
	_surf_sparks.lifetime_randomness = 0.3
	_surf_sparks.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_surf_sparks.emission_sphere_radius = 0.15
	_surf_sparks.spread = 14.0
	_surf_sparks.initial_velocity_min = 3.0
	_surf_sparks.initial_velocity_max = 6.0
	_surf_sparks.gravity = Vector3(0.0, -12.0, 0.0)
	_surf_sparks.particle_flag_align_y = true
	_surf_sparks.scale_amount_min = 0.7
	_surf_sparks.scale_amount_max = 1.3
	_surf_sparks.color_ramp = ProcTextures.fade_ramp()
	var spray_mesh := BoxMesh.new()
	spray_mesh.size = Vector3(0.018, 0.30, 0.018)
	spray_mesh.material = ProcTextures.streak_material(Color(0.80, 0.52, 0.22, 0.60))
	_surf_sparks.mesh = spray_mesh
	_surf_sparks.visibility_aabb = AABB(Vector3(-8.0, -8.0, -8.0), Vector3(16.0, 16.0, 16.0))
	_surf_sparks.position = Vector3(0.0, 0.10, 0.0)
	_surf_sparks.emitting = false
	_surf_sparks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_surf_sparks)

	# пыль при посадке — мягкое облачко цвета песка (не аддитивное)
	_land_dust = CPUParticles3D.new()
	_land_dust.amount = 40
	_land_dust.lifetime = 0.8
	_land_dust.lifetime_randomness = 0.3
	_land_dust.one_shot = true
	_land_dust.explosiveness = 1.0
	_land_dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_land_dust.emission_sphere_radius = 0.25
	_land_dust.spread = 180.0
	_land_dust.initial_velocity_min = 1.2
	_land_dust.initial_velocity_max = 2.6
	_land_dust.gravity = Vector3(0.0, -1.2, 0.0)
	_land_dust.damping_min = 3.0
	_land_dust.damping_max = 5.0
	_land_dust.scale_amount_min = 0.9
	_land_dust.scale_amount_max = 1.3
	_land_dust.scale_amount_curve = ProcTextures.grow_curve(0.35, 1.15)
	_land_dust.color_ramp = ProcTextures.fade_ramp()
	var dust_quad := QuadMesh.new()
	dust_quad.size = Vector2(0.6, 0.6)
	dust_quad.material = ProcTextures.soft_material(Color(0.97, 0.78, 0.55, 0.40))
	_land_dust.mesh = dust_quad
	_land_dust.visibility_aabb = AABB(Vector3(-8.0, -5.0, -8.0), Vector3(16.0, 10.0, 16.0))
	_land_dust.position = Vector3(0.0, 0.15, 0.0)
	_land_dust.emitting = false
	_land_dust.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_land_dust)

	# пылинка от каждого шага на бегу — песок «пыхтит» под ногами
	_step_dust = CPUParticles3D.new()
	_step_dust.amount = 9
	_step_dust.one_shot = true
	_step_dust.explosiveness = 1.0
	_step_dust.lifetime = 0.45
	_step_dust.lifetime_randomness = 0.4
	_step_dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_step_dust.emission_sphere_radius = 0.07
	_step_dust.spread = 180.0
	_step_dust.initial_velocity_min = 0.4
	_step_dust.initial_velocity_max = 1.0
	_step_dust.gravity = Vector3(0.0, -2.0, 0.0)
	_step_dust.damping_min = 4.0
	_step_dust.damping_max = 6.0
	_step_dust.scale_amount_min = 0.5
	_step_dust.scale_amount_max = 0.85
	_step_dust.scale_amount_curve = ProcTextures.grow_curve(0.3, 1.0)
	_step_dust.color_ramp = ProcTextures.fade_ramp()
	var step_quad := QuadMesh.new()
	step_quad.size = Vector2(0.32, 0.32)
	step_quad.material = ProcTextures.soft_material(Color(0.96, 0.74, 0.52, 0.30))
	_step_dust.mesh = step_quad
	_step_dust.visibility_aabb = AABB(Vector3(-3.0, -2.0, -3.0), Vector3(6.0, 4.0, 6.0))
	_step_dust.position = Vector3(0.0, 0.06, 0.0)
	_step_dust.emitting = false
	_step_dust.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_step_dust)


func _build_body() -> void:
	visual = Node3D.new()
	add_child(visual)

	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/cloth.gdshader")
	mat.set_shader_parameter("sun_dir", Game.SUN_DIR)
	mat.set_shader_parameter("cloth_main", Color(0.50, 0.15, 0.15))
	mat.set_shader_parameter("cloth_lit", Color(1.0, 0.60, 0.40))
	mat.set_shader_parameter("horizon_col", Game.HORIZON_COL)
	mat.set_shader_parameter("sky_col", Game.SKY_COL)
	mat.set_shader_parameter("fog_distance", Game.FOG_DISTANCE)

	#robe
	var robe := MeshInstance3D.new()
	var robe_mesh := CylinderMesh.new()
	robe_mesh.top_radius = 0.22
	robe_mesh.bottom_radius = 0.44
	robe_mesh.height = 0.55
	robe_mesh.radial_segments = 14
	robe.mesh = robe_mesh
	robe.material_override = mat
	robe.position = Vector3(0.0, 0.30, 0.0)
	visual.add_child(robe)

	# тело
	var body := MeshInstance3D.new()
	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = 0.26
	body_mesh.height = 1.05
	body.mesh = body_mesh
	body.material_override = mat
	body.position = Vector3(0.0, 0.66, 0.0)
	visual.add_child(body)

	# голова
	var head := MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.19
	head_mesh.height = 0.38
	head.mesh = head_mesh
	head.material_override = mat
	head.position = Vector3(0.0, 1.30, 0.05)
	visual.add_child(head)

	for child in visual.get_children():
		child.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _physics_process(delta: float) -> void:
	var wish := _wish_dir()
	if grounded:
		_step_grounded(delta, wish)
	else:
		_step_air(delta, wish)
	_bounds(delta)
	_update_gait(delta)
	_update_fx()
	_update_visual(delta)
	_update_game_state()


func _wish_dir() -> Vector3:
	# Направление желания относительно камеры.
	var fwd := Input.get_action_strength("move_forward") - Input.get_action_strength("move_back")
	var side := Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	if absf(fwd) < 0.001 and absf(side) < 0.001:
		return Vector3.ZERO
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return Vector3.ZERO
	var cam_basis := cam.global_transform.basis
	var f := -cam_basis.z
	f.y = 0.0
	var r := cam_basis.x
	r.y = 0.0
	if f.length_squared() < 0.001 and r.length_squared() < 0.001:
		return Vector3.ZERO
	var dir := (f.normalized() * fwd + r.normalized() * side)
	if dir.length() > 1.0:
		dir = dir.normalized()
	return dir


func _step_grounded(delta: float, wish: Vector3) -> void:
	_air_time = 0.0
	var pos := global_position
	var n := terrain.ground_normal(pos.x, pos.z)

	# скорость живёт в плоскости склона
	vel = vel - n * vel.dot(n)

	# скольжение: тянет вниз по склону (в гору — тормозит)
	var g := Vector3.DOWN * GRAVITY
	var slope_acc := g - n * g.dot(n)
	vel += slope_acc * delta

	# управление: проецируем желание на склон
	if wish.length_squared() > 0.001:
		var wish_slope := wish - n * wish.dot(n)
		if wish_slope.length() > 0.01:
			vel += wish_slope.normalized() * WALK_ACCEL * delta

	# трение песка: на скорости и круче — скользкий (песок «течёт»)
	var spd := vel.length()
	var n_speed := clampf(spd / 10.0, 0.0, 1.0)
	var fric := lerpf(1.9, 0.22, n_speed)
	var slope_factor := clampf((1.0 - n.y) * 2.6, 0.0, 1.0)
	fric *= 1.0 - slope_factor * 0.85
	vel *= exp(-fric * delta)

	# потолок скорости: на спуске выше (сёрф)
	var downhill := slope_acc.normalized() # направление стока (вниз по склону)
	var dvel := 0.0
	if spd > 0.01:
		dvel = vel.dot(downhill) / spd # -1..1: движение совпадает со спуском
	var surf_bias := clampf(dvel, 0.0, 1.0) * n_speed
	var max_spd := lerpf(WALK_MAX, SURF_MAX, clampf(surf_bias * 1.5, 0.0, 1.0))
	if spd > max_spd:
		var over := spd - max_spd
		vel = vel.normalized() * (spd - over * clampf(delta * 8.0, 0.0, 1.0))
	surf01 = clampf(surf_bias * (spd / SURF_MAX) * 1.4, 0.0, 1.0)

	# прыжок — вверх по инерции склона, с лёгким задиранием песка
	if Input.is_action_just_pressed("jump"):
		if sand != null:
			sand.stamp_foot(
				Vector2(pos.x, pos.z),
				Vector2(sin(heading), cos(heading)),
				0.30, 0.22, 0.030, 0.012
			)
		vel += n * JUMP_V * 0.35 + Vector3.UP * JUMP_V * 0.75
		grounded = false
		return

	# движение по склону (по дюнам + собственным следам)
	global_position += vel * delta
	var gh := terrain.ground_height(global_position.x, global_position.z)
	var gap := global_position.y - gh
	# На разгоняющемся спуске рельеф «убегает» из-под ног быстрее гравитации.
	# Держим путника на склоне в пределах скоростного зазора — сёрф льнёт
	# к дюне (как в Journey), в полёт бросает только настоящий обрыв.
	var launch := 0.45 + Vector2(vel.x, vel.z).length() * 0.10
	if gap > launch:
		grounded = false
		_air_time = 0.0
	else:
		global_position.y = gh


func _step_air(delta: float, wish: Vector3) -> void:
	_air_time += delta
	gliding = Input.is_action_pressed("jump") and vel.y < 1.5
	var grav := GLIDE_G if gliding else GRAVITY
	vel.y -= grav * delta

	# лёгкое управление в воздухе (путник слегка планирует)
	if wish.length_squared() > 0.001:
		vel.x += wish.x * AIR_ACCEL * delta
		vel.z += wish.z * AIR_ACCEL * delta
	if gliding:
		vel.y = maxf(vel.y, -4.5)

	global_position += vel * delta
	var gh := terrain.ground_height(global_position.x, global_position.z)
	var gap := global_position.y - gh
	# «прилипание»: соскочили с выпуклого гребня и уже почти вернулись к песку —
	# мягко возвращаемся на склон, сохраняя скорость вдоль него.
	# Прыжок с зажатой клавишей парения — намеренный полёт, его не ломаем.
	var snap := 0.45 + Vector2(vel.x, vel.z).length() * 0.10
	if _air_time < 0.35 and vel.y <= 0.5 and gap <= snap and not Input.is_action_pressed("jump"):
		global_position.y = gh
		grounded = true
		gliding = false
		var n := terrain.ground_normal(global_position.x, global_position.z)
		if vel.dot(n) < 0.0:
			vel = vel - n * vel.dot(n)
		surf01 = 0.0
		return
	if global_position.y <= gh:
		global_position.y = gh
		grounded = true
		gliding = false
		# приземление: скорость укладывается в склон — песок «принимает»
		var n := terrain.ground_normal(global_position.x, global_position.z)
		var impact := maxf(0.0, -vel.y)
		var impact01 := clampf(impact / 15.0, 0.0, 1.0)
		_squash = impact01
		vel = vel - n * vel.dot(n)
		surf01 = 0.0
		# настоящий отпечаток посадки: песок вдавлен обеими стопами
		if sand != null and impact > 2.0:
			sand.stamp_land(
				Vector2(global_position.x, global_position.z),
				Vector2(sin(heading), cos(heading)),
				0.05 + 0.05 * impact01
			)
		if audio != null and impact > 2.5:
			audio.on_land(impact01)
		if impact > 6.0:
			_land_dust.restart()


func _bounds(delta: float) -> void:
	# Мягкие границы: мир замкнут дюнами, сюда игрок почти не доходит.
	var pos := global_position
	var push := Vector3.ZERO
	if pos.x > BOUND_X:
		push.x = BOUND_X - pos.x
	elif pos.x < -BOUND_X:
		push.x = -BOUND_X - pos.x
	if pos.z > BOUND_Z_MAX:
		push.z = BOUND_Z_MAX - pos.z
	elif pos.z < BOUND_Z_MIN:
		push.z = BOUND_Z_MIN - pos.z
	if push != Vector3.ZERO:
		global_position += push * clampf(delta * 1.5, 0.0, 1.0)
		vel += push * delta * 2.0


# ---------------------------------------------------------------------------
## Походка и следы. Фаза _gait_phase крутится с частотой шагов; на каждом π
## стопа касается песка: отпечаток + пыль + звук. Покачивание тела — это
## тот же sin(_gait_phase), так что видимый шаг и след совпадают кадр в кадр.
## На сёрфе шаги сменяются непрерывной бороздой (штампуется чуть позади,
## чтобы песок не «проваливался» под ногами рывком).
# ---------------------------------------------------------------------------
func _update_gait(delta: float) -> void:
	if sand == null or not grounded:
		_track_on = false
		return
	var hv := Vector3(vel.x, 0.0, vel.z)
	var hspd := hv.length()
	var fwd := Vector2(sin(heading), cos(heading))
	var pos := Vector2(global_position.x, global_position.z)

	# сёрф: непрерывная churned борозда с валиками по краям
	if hspd > SURF_TRACK_SPEED:
		var behind := pos - fwd * 0.45
		if not _track_on:
			_track_on = true
			_track_last = behind
		elif behind.distance_to(_track_last) >= 0.34:
			var spd01 := clampf(hspd / SURF_MAX, 0.0, 1.0)
			sand.stamp_track(_track_last, behind, 0.52, 0.05 + 0.05 * spd01, 0.03)
			_track_last = behind
		return

	_track_on = false
	if hspd < 0.7:
		return

	# частота шагов растёт со скоростью — мелкая рысь путника
	var cadence: float = clampf(0.9 + hspd * 0.68, 1.0, 5.0)
	_gait_phase += cadence * PI * delta
	var step_idx := int(_gait_phase / PI)
	if step_idx > _last_step_idx:
		_last_step_idx = step_idx
		_plant_foot(pos, fwd, hspd)


## Постановка стопы: чередование левой/правой чуть в стороне от курса.
func _plant_foot(pos: Vector2, fwd: Vector2, hspd: float) -> void:
	var spd01 := clampf(hspd / SURF_MAX, 0.0, 1.0)
	var perp := Vector2(-fwd.y, fwd.x)
	var p := pos - fwd * 0.30 + perp * (0.10 * _foot_side)
	_foot_side = -_foot_side
	var rnd := randf_range(0.88, 1.12) # каждый шаг чуть другой
	sand.stamp_foot(
		p, fwd,
		0.46 + 0.22 * spd01,               # длина стопы
		0.24,                                # ширина
		(0.034 + 0.028 * spd01) * rnd,      # глубина
		0.015 + 0.013 * spd01               # вал выброшенного песка
	)
	if audio != null:
		audio.on_step(clampf(hspd / 10.0, 0.0, 1.0))
	if spd01 > 0.30:
		_step_dust.restart()


func _update_fx() -> void:
	# золотые брызги — только настоящий сёрф (обычный бег с горы не считается)
	var hv := Vector3(vel.x, 0.0, vel.z)
	var hspd := hv.length()
	var spark := grounded and hspd > 11.5
	_surf_sparks.emitting = spark
	if spark:
		# летят назад и чуть вверх от ног, ложась дугой на песок
		var back := -hv / hspd
		_surf_sparks.direction = (back + Vector3.UP * 0.30).normalized()


func _update_visual(delta: float) -> void:
	var hv := Vector3(vel.x, 0.0, vel.z)
	if hv.length() > 0.8:
		heading = lerp_angle(heading, atan2(hv.x, hv.z), 1.0 - exp(-10.0 * delta))

	var spd := vel.length()
	var n := terrain.ground_normal(global_position.x, global_position.z) if grounded else Vector3.UP

	# выравнивание по склону при сёрфе + наклон вперёд от скорости
	var up := Vector3.UP.lerp(n, surf01 * 0.55).normalized()
	var fwd := Vector3(sin(heading), 0.0, cos(heading))
	fwd = (fwd - up * fwd.dot(up)).normalized()
	var x_axis := up.cross(fwd).normalized()
	var y_axis := fwd.cross(x_axis)
	var lean := clampf(spd / SURF_MAX, 0.0, 1.0) * 0.32 + (0.12 if gliding else 0.0)
	visual.basis = Basis(x_axis, y_axis, fwd) * Basis(Vector3.RIGHT, lean)

	# шаг: тело качается той же фазой, что и стопы бьют по песку
	_squash = lerpf(_squash, 0.0, 1.0 - exp(-9.0 * delta))
	var bob_y := sin(_gait_phase) * 0.05 * clampf(spd / 6.0, 0.0, 1.0) * (1.0 - surf01)
	visual.position = Vector3(0.0, bob_y - _squash * 0.30, 0.0)


func _update_game_state() -> void:
	game.surf01 = game.surf01 * 0.9 + surf01 * 0.1 # сглаженное для музыки/камеры
	game.player_altitude = global_position.y


## Мировая точка крепления шарфа.
func neck_pos() -> Vector3:
	return visual.global_transform * Vector3(0.0, 1.05, -0.16)
