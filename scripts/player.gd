class_name Player
extends Node3D
## Путник. Аналитическая кинематика по полю высот террейна:
## вниз по склону разгоняемся, в гору — теряем ход, на крутом спуске — «сёрф».
## Никакой смерти, таймеров и провалов — только движение.

const GRAVITY := 26.0
const WALK_ACCEL := 34.0
const WALK_MAX := 7.0
const SURF_MAX := 17.5
const JUMP_V := 9.0
const GLIDE_G := 5.5 # гравитация при парении
const AIR_ACCEL := 6.0

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
var visual: Node3D
var scarf: Scarf
var trail: Trail

var _bob := 0.0
var _squash := 0.0
var _step_accum := 0.0
var _foot_side := 1.0
var _surf_sparks: CPUParticles3D
var _land_dust: CPUParticles3D


func setup(game_ref, terrain_ref: Terrain) -> void:
	game = game_ref
	terrain = terrain_ref
	global_position = Vector3(
		Terrain.SPAWN.x,
		terrain.sample_height(Terrain.SPAWN.x, Terrain.SPAWN.y),
		Terrain.SPAWN.y
	)
	_build_body()
	_build_fx()


## Подключает карту следов (создаётся после игрока).
func attach_trail(trail_ref: Trail) -> void:
	trail = trail_ref


func _build_fx() -> void:
	var tex := ProcTextures.radial(32, 1.8)

	# искры из-под ног при быстром скольжении.
	# local_coords по умолчанию false: частицы живут в мировых
	# координатах и остаются позади летящего путника.
	_surf_sparks = CPUParticles3D.new()
	_surf_sparks.amount = 140
	_surf_sparks.lifetime = 0.7
	_surf_sparks.lifetime_randomness = 0.4
	_surf_sparks.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_surf_sparks.emission_sphere_radius = 0.22
	_surf_sparks.spread = 24.0
	_surf_sparks.initial_velocity_min = 3.5
	_surf_sparks.initial_velocity_max = 8.0
	_surf_sparks.gravity = Vector3(0.0, -10.0, 0.0)
	_surf_sparks.damping_min = 1.0
	_surf_sparks.damping_max = 2.5
	_surf_sparks.scale_amount_min = 0.05
	_surf_sparks.scale_amount_max = 0.12
	_surf_sparks.mesh = _particle_quad(tex, Color(1.0, 0.78, 0.45, 0.85))
	_surf_sparks.visibility_aabb = AABB(Vector3(-15.0, -12.0, -15.0), Vector3(30.0, 24.0, 30.0))
	_surf_sparks.position = Vector3(0.0, 0.18, 0.0)
	_surf_sparks.emitting = false
	_surf_sparks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_surf_sparks)

	# пыль при посадке — разовый выброс
	_land_dust = CPUParticles3D.new()
	_land_dust.amount = 60
	_land_dust.lifetime = 0.9
	_land_dust.lifetime_randomness = 0.3
	_land_dust.one_shot = true
	_land_dust.explosiveness = 1.0
	_land_dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_land_dust.emission_sphere_radius = 0.3
	_land_dust.spread = 180.0
	_land_dust.initial_velocity_min = 1.5
	_land_dust.initial_velocity_max = 3.5
	_land_dust.gravity = Vector3(0.0, -4.0, 0.0)
	_land_dust.damping_min = 2.0
	_land_dust.damping_max = 4.0
	_land_dust.scale_amount_min = 0.08
	_land_dust.scale_amount_max = 0.2
	_land_dust.mesh = _particle_quad(tex, Color(1.0, 0.85, 0.65, 0.55))
	_land_dust.visibility_aabb = AABB(Vector3(-10.0, -6.0, -10.0), Vector3(20.0, 12.0, 20.0))
	_land_dust.position = Vector3(0.0, 0.15, 0.0)
	_land_dust.emitting = false
	_land_dust.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_land_dust)


func _particle_quad(tex: ImageTexture, tint: Color) -> QuadMesh:
	var quad := QuadMesh.new()
	quad.size = Vector2(1.0, 1.0)
	quad.material = ProcTextures.particle_material(tex, tint)
	return quad


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
	_update_footsteps(delta)
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
	var downhill := -slope_acc.normalized()
	var dvel := 0.0
	if spd > 0.01:
		dvel = vel.dot(downhill) / spd # -1..1: движение совпадает со спуском
	var surf_bias := clampf(dvel, 0.0, 1.0) * n_speed
	var max_spd := lerpf(WALK_MAX, SURF_MAX, clampf(surf_bias * 1.5, 0.0, 1.0))
	if spd > max_spd:
		var over := spd - max_spd
		vel = vel.normalized() * (spd - over * clampf(delta * 8.0, 0.0, 1.0))
	surf01 = clampf(surf_bias * (spd / SURF_MAX) * 1.4, 0.0, 1.0)

	# прыжок — вверх по инерции склона
	if Input.is_action_just_pressed("jump"):
		vel += n * JUMP_V * 0.35 + Vector3.UP * JUMP_V * 0.75
		grounded = false
		return

	# движение по склону
	global_position += vel * delta
	var gh := terrain.sample_height(global_position.x, global_position.z)
	if global_position.y - gh > 0.38:
		# гребень ушёл из-под ног — короткий полёт
		grounded = false
	else:
		global_position.y = gh


func _step_air(delta: float, wish: Vector3) -> void:
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
	var gh := terrain.sample_height(global_position.x, global_position.z)
	if global_position.y <= gh:
		global_position.y = gh
		grounded = true
		gliding = false
		# приземление: скорость укладывается в склон — песок «принимает»
		var n := terrain.ground_normal(global_position.x, global_position.z)
		var impact := maxf(0.0, -vel.y)
		_squash = clampf(impact / 15.0, 0.0, 1.0)
		vel = vel - n * vel.dot(n)
		surf01 = 0.0
		# примятый отпечаток посадки + пыль
		if trail != null and impact > 2.0:
			trail.stamp(global_position.x, global_position.z, 0.9, clampf(impact / 16.0, 0.0, 0.6))
		if impact > 4.0:
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


func _update_footsteps(delta: float) -> void:
	if trail == null or not grounded:
		return
	var hv := Vector3(vel.x, 0.0, vel.z)
	var hspd := hv.length()
	if hspd < 0.5:
		return
	# шаг — короткий, сёрф — длинный глиссирующий штрих
	var stride := 0.6 if hspd < 9.0 else 0.9
	_step_accum += hspd * delta
	while _step_accum >= stride:
		_step_accum -= stride
		# чередование левой/правой ноги: штамп чуть в стороне от курса
		var fwd := Vector3(sin(heading), 0.0, cos(heading))
		var side := Vector3(fwd.z, 0.0, -fwd.x) * (0.15 * _foot_side)
		_foot_side = -_foot_side
		var px := global_position.x + side.x - fwd.x * 0.25
		var pz := global_position.z + side.z - fwd.z * 0.25
		if hspd < 9.0:
			trail.stamp(px, pz, 0.35, 0.35)
		else:
			trail.stamp(px, pz, 0.55, 0.60)


func _update_fx() -> void:
	# искры из-под ног при быстрой езде по песку
	var hv := Vector3(vel.x, 0.0, vel.z)
	var hspd := hv.length()
	var spark := grounded and hspd > 9.0
	_surf_sparks.emitting = spark
	if spark:
		# летят назад-вверх против движения
		var back := -hv / hspd
		_surf_sparks.direction = (back + Vector3.UP * 0.45).normalized()


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

	# шаг: лёгкое покачивание при ходьбе, приземление — присед
	if grounded and spd > 0.5:
		_bob += delta * (5.0 + spd * 1.4)
	_squash = lerpf(_squash, 0.0, 1.0 - exp(-9.0 * delta))
	var bob_y := sin(_bob) * 0.05 * clampf(spd / 7.0, 0.0, 1.0) * (1.0 - surf01)
	visual.position = Vector3(0.0, bob_y - _squash * 0.30, 0.0)


func _update_game_state() -> void:
	game.surf01 = game.surf01 * 0.9 + surf01 * 0.1 # сглаженное для музыки/камеры
	game.player_altitude = global_position.y


## Мировая точка крепления шарфа.
func neck_pos() -> Vector3:
	return visual.global_transform * Vector3(0.0, 1.05, -0.16)
