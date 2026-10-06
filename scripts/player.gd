class_name Player
extends Node3D
## Кинематика игрока от первого лица по полю высот террейна: ходьба по
## дюнам, прыжок/парение и «сёрф». Тело не рендерится — вид от первого
## лица, руки с пистолетом висят на камере (FpsArms); этот узел — физика,
## следы на песке и пыль.
##
## Скольжение — ТОЛЬКО по зажатому Shift: без Shift песок держит на любом
## уклоне, самовольного скольжения нет ни при каких обстоятельствах.
##
## Песок и шаги связаны накротко: фаза шага рождает отпечаток стопы в
## SandField, лёгкую пыль и звук; сёрф режет непрерывную борозду.
## Игрок ходит ПО поверхности дюн вместе со всеми следами.

const GRAVITY := 26.0
const WALK_ACCEL := 26.0
const WALK_MAX := 2.4 # спокойный шаг; в FPS темп задаёт анимация рук не ног
const SURF_MAX := 17.5
const JUMP_V := 8.6
const GLIDE_G := 5.5 # гравитация при парении
const AIR_ACCEL := 6.0

const SURF_TRACK_SPEED := 4.6 # выше — СКАЛЬЗЯЩИЙ сёрф (возможен только со Shift)

const HOLD_SLOPE_ACC := 9.8 # ~22°: со Shift на более пологих склонах песок ДЕРЖИТ
const STOP_SPEED := 1.1 # м/с: без ввода игрок выпахивается до остановки

const BOUND_X := 185.0
const BOUND_Z_MIN := -445.0
const BOUND_Z_MAX := 50.0

var vel := Vector3.ZERO
var grounded := true
var heading := PI # курс камеры (пишет CameraRig каждый кадр)
var surf01 := 0.0 # 0..1 — насколько мы «сёрфим» (камера, музыка, эффекты)
var gliding := false

var game
var terrain: Terrain
var sand: SandField
var audio # SoundScape (подключается после создания)

var _gait_phase := 0.0 # фаза шага: π = постановка стопы
var _last_step_idx := 0
var _foot_side := 1.0
var _air_time := 0.0 # секунд с последнего касания земли
var _track_on := false
var _track_last := Vector2.ZERO
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
	_build_fx()


func _build_fx() -> void:
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

	# пылинка от каждого шага — песок «пыхтит» под ногами
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


func _physics_process(delta: float) -> void:
	var wish := _wish_dir()
	if grounded:
		_step_grounded(delta, wish)
	else:
		_step_air(delta, wish)
	_bounds(delta)
	_update_gait(delta)
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

	# СКОЛЬЖЕНИЕ — ТОЛЬКО ОСОЗНАННОЕ: Shift открывает «сёрф-режим».
	# Без Shift песок держит на любом уклоне: игрок ходит и стоит,
	# самовольного сползания нет.
	var surf_armed := Input.is_action_pressed("slide_mod")

	# скольжение: тянет вниз по склону (в гору — тормозит)
	var g := Vector3.DOWN * GRAVITY
	var slope_acc := g - n * g.dot(n)
	var slope_mag := slope_acc.length()
	var no_input := wish.length_squared() < 0.001

	# Песок ДЕРЖИТ игрока: без ввода — полная остановка (статическое
	# трение). Без Shift — на ЛЮБОМ уклоне; со Shift песок «течёт»
	# только на крутых сёрф-лицах (уклон выше HOLD_SLOPE_ACC).
	if no_input and vel.length() < STOP_SPEED and (not surf_armed or slope_mag < HOLD_SLOPE_ACC):
		vel = vel.move_toward(Vector3.ZERO, 30.0 * delta)
		surf01 = 0.0
		if Input.is_action_just_pressed("jump"):
			vel += n * JUMP_V * 0.35 + Vector3.UP * JUMP_V * 0.75
			grounded = false
			return
		global_position += vel * delta
		global_position.y = terrain.ground_height(global_position.x, global_position.z)
		return

	if surf_armed:
		vel += slope_acc * delta # сток по склону — только в сёрф-режиме

	# управление: проецируем желание на склон
	if wish.length_squared() > 0.001:
		var wish_slope := wish - n * wish.dot(n)
		if wish_slope.length() > 0.01:
			vel += wish_slope.normalized() * WALK_ACCEL * delta

	# трение песка: на скорости и круче — скользкий (песок «течёт»)
	var spd := vel.length()
	var n_speed := clampf(spd / 10.0, 0.0, 1.0)
	var fric := lerpf(1.7, 0.22, n_speed)
	if no_input:
		fric *= 2.8 # отпустил клавиши — песок выпахивает и тормозит
	if surf_armed:
		var slope_factor := clampf((1.0 - n.y) * 2.6, 0.0, 1.0)
		fric *= 1.0 - slope_factor * 0.85 # крутая дюна «течёт» — но только со Shift
	vel *= exp(-fric * delta)

	# потолок скорости: на спуске выше (сёрф)
	var downhill := slope_acc.normalized() # направление стока (вниз по склону)
	var dvel := 0.0
	if spd > 0.01:
		dvel = vel.dot(downhill) / spd # -1..1: движение совпадает со спуском
	var surf_bias := clampf(dvel, 0.0, 1.0) * n_speed
	# в горку шаг слабеет (песок пересыпается из-под ног) — подъём читается
	# как подъём, а не езда вверх по стеклу
	var surf_mix := clampf(surf_bias * 1.5, 0.0, 1.0) if surf_armed else 0.0
	var max_spd := lerpf(WALK_MAX * lerpf(1.0, 0.55, _uphill01()), SURF_MAX, surf_mix)
	if spd > max_spd:
		var over := spd - max_spd
		vel = vel.normalized() * (spd - over * clampf(delta * 8.0, 0.0, 1.0))
	surf01 = clampf(surf_bias * (spd / SURF_MAX) * 1.4, 0.0, 1.0) if surf_armed else 0.0

	# прыжок — вверх по инерции склона, с лёгким задиранием песка
	if Input.is_action_just_pressed("jump"):
		if sand != null:
			sand.stamp_foot(
				Vector2(pos.x, pos.z),
				Vector2(sin(heading), cos(heading)),
				0.34, 0.24, 0.050, 0.018
			)
		vel += n * JUMP_V * 0.35 + Vector3.UP * JUMP_V * 0.75
		grounded = false
		return

	# движение по склону (по дюнам + собственным следам)
	global_position += vel * delta
	var gh := terrain.ground_height(global_position.x, global_position.z)
	var gap := global_position.y - gh
	# На разгоняющемся спуске рельеф «убегает» из-под ног быстрее гравитации.
	# Держим игрока на склоне в пределах скоростного зазора — сёрф льнёт
	# к дюне, в полёт бросает только настоящий обрыв.
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

	# лёгкое управление в воздухе (слегка планируем)
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
		vel = vel - n * vel.dot(n)
		surf01 = 0.0
		# настоящий отпечаток посадки: песок вдавлен обеими стопами
		if sand != null and impact > 2.0:
			sand.stamp_land(
				Vector2(global_position.x, global_position.z),
				Vector2(sin(heading), cos(heading)),
				0.06 + 0.08 * impact01
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
## Следы на песке. Фаза _gait_phase крутится с частотой шагов; на каждом π
## стопа касается песка: отпечаток + пыль + звук. На сёрфе шаги сменяются
## непрерывной бороздой (штампуется чуть позади, чтобы песок не
## «проваливался» под ногами рывком).
# ---------------------------------------------------------------------------
func _update_gait(delta: float) -> void:
	if sand == null or not grounded:
		_track_on = false
		return
	var hv := Vector3(vel.x, 0.0, vel.z)
	var hspd := hv.length()
	# отпечатки ставятся ПО ХОДУ ДВИЖЕНИЯ (стрейф в FPS — тоже шаги)
	var fwd := Vector2(sin(heading), cos(heading))
	if hspd > 0.5:
		fwd = Vector2(hv.x, hv.z) / hspd
	var pos := Vector2(global_position.x, global_position.z)

	# сёрф: непрерывная churned борозда с валиками по краям
	if hspd > SURF_TRACK_SPEED:
		var behind := pos - fwd * 0.45
		if not _track_on:
			_track_on = true
			_track_last = behind
		elif behind.distance_to(_track_last) >= 0.26:
			var spd01 := clampf(hspd / SURF_MAX, 0.0, 1.0)
			sand.stamp_track(_track_last, behind, 0.62, 0.08 + 0.07 * spd01, 0.035)
			_track_last = behind
			return

	_track_on = false
	if hspd < 0.7:
		return

	# частота шагов = темпу: цикл ~1.33 с, стопы там, где идём
	var cadence: float = clampf(1.5 * hspd, 0.8, 4.5)
	_gait_phase += cadence * PI * delta
	var step_idx := int(_gait_phase / PI)
	if step_idx > _last_step_idx:
		_last_step_idx = step_idx
		_plant_foot(pos, fwd, hspd)


## Постановка стопы: песок поддаётся бесформенно. Подъём — глубже
## (песок сползает из-под ног), каждый шаг — свой размер, поворот
## и разброс. Никаких «отпечатков ботинка».
func _plant_foot(pos: Vector2, fwd: Vector2, hspd: float) -> void:
	var spd01 := clampf(hspd / SURF_MAX, 0.0, 1.0)
	var perp := Vector2(-fwd.y, fwd.x)
	var uphill := _uphill01()
	var p := pos - fwd * 0.30 + perp * (0.10 * _foot_side + randf_range(-0.04, 0.04))
	_foot_side = -_foot_side
	var f := fwd.rotated(randf_range(-0.35, 0.35)) # стопа развёрнута случайно
	sand.stamp_foot(
		p, f,
		(0.46 + 0.22 * spd01) * randf_range(0.85, 1.20),  # длина — каждый шаг своя
		(0.26 + 0.14 * spd01) * randf_range(0.85, 1.30),  # ширина
		(0.052 + 0.036 * spd01 + 0.08 * uphill) * randf_range(0.80, 1.35),
		0.016 + 0.014 * spd01
	)
	# процедурный «пинок»: с подъёма песок выползает из-под стопы вбок
	if randf() < 0.30 + uphill * 0.45:
		var kick := p + f * randf_range(0.10, 0.45) + perp * randf_range(-0.30, 0.30) * _foot_side
		sand.stamp_track(kick, kick + f * 0.22, randf_range(0.10, 0.20), randf_range(0.02, 0.05), 0.010)
	if audio != null:
		audio.on_step(clampf(hspd / 3.0, 0.0, 1.0))
	if spd01 > 0.10 or uphill > 0.4:
		_step_dust.restart()


## 0..1 — насколько движение сейчас В ГОРКУ (песок поддаётся глубже).
func _uphill01() -> float:
	if not grounded:
		return 0.0
	var hv := Vector3(vel.x, 0.0, vel.z)
	if hv.length() < 0.5:
		return 0.0
	var n := terrain.ground_normal(global_position.x, global_position.z)
	var g := Vector3.DOWN * GRAVITY
	var downhill := (g - n * g.dot(n)).normalized()
	return clampf(-hv.normalized().dot(downhill), 0.0, 1.0)


func _update_game_state() -> void:
	game.surf01 = game.surf01 * 0.9 + surf01 * 0.1 # сглаженное для музыки/камеры
	game.player_altitude = global_position.y


## Покачивание головы для камеры: тот же такт, что ставит следы.
func gait_bob() -> float:
	var hv := Vector3(vel.x, 0.0, vel.z)
	var spd01 := clampf(hv.length() / 2.6, 0.0, 1.0)
	return sin(_gait_phase) * 0.03 * spd01 * (1.0 - surf01)
