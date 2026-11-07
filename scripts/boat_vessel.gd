class_name BoatVessel
extends Node3D
## Малое научно-исследовательское судно («Приливная лаборатория»).
## Выверенная геометрия корпуса без выступающих планок на носу,
## насос строго по левому борту, прочность корпуса, прожектор и запись мировой траектории следа.

const MAX_SPEED := 10.0
const REVERSE_SPEED := 4.0
const ACCELERATION := 3.2
const DRAG := 1.8
const TURN_RATE := 0.95
const PUMP_RANGE := 6.5
const PUMP_SECONDS := 1.4
const SHIP_EMISSION_BOOST := 2.0

const START_WITH_TRAILER := false
const TRAILER_DISTANCE := 9.3
const TRAILER_CLEARANCE := 9.15
const TRAILER_PUMP_RANGE := 8.0 # от ближайшего борта, а не от центра прицепа
const TRAILER_SLICK_RADIUS := 1.8 # видимая кромка SDF-пятна не совпадает с центром
const TRAILER_PUMP_SECONDS := 0.55
const TRAIL_POINTS := 20
const TRAIL_STEP_TIME := 0.25

var main: BoatMain
var water: WaterSurface
var coast: Coast
var speed := 0.0
var hull_hp := 100.0
var has_trailer := false
var wrong_side_target := false

var _pump_progress := 0.0
var _anim_time := 0.0
var _steer_visual := 0.0
var _refine_flash := 0.0
var _impact_cooldown := 0.0

var _heave_vel := 0.0
var _pitch_vel := 0.0
var _roll_vel := 0.0

var _trail_buffer := PackedVector4Array()
var _trail_timer := 0.0
var _last_trail_pos := Vector2.ZERO

var _target: ResourceSlick # ручной насос лодки
var _trailer_target: ResourceSlick # независимый автоматический насос
var _trailer_pump_progress := 0.0
var _body: Node3D
var _radar: Node3D
var _rudder: Node3D
var _prop_l: Node3D
var _prop_r: Node3D
var _bow_spot: SpotLight3D
var _deck_light: OmniLight3D
var _window_glass_mat: StandardMaterial3D
var _window_light: OmniLight3D

var _crane_turret: Node3D
var _crane_boom: Node3D
var _crane_jib: Node3D
var _hose: MeshInstance3D
var _hose_mat: StandardMaterial3D
var _intake_head: MeshInstance3D
var _intake_mat: StandardMaterial3D

var _vat_fills: Array[MeshInstance3D] = []
var _vat_mats: Array[StandardMaterial3D] = []

var _trailer: Node3D
var _trailer_body: Node3D
var _tow_cable_l: MeshInstance3D
var _tow_cable_r: MeshInstance3D
var _trailer_sight_fills: Array[MeshInstance3D] = []
var _trailer_arm_pivot: Node3D
var _trailer_hose: MeshInstance3D
var _trailer_hose_mat: StandardMaterial3D
var _trailer_head: MeshInstance3D
var _trailer_head_mat: StandardMaterial3D


func setup(boat_main: BoatMain, water_ref: WaterSurface, coast_ref: Coast) -> void:
	main = boat_main
	water = water_ref
	coast = coast_ref
	_trail_buffer.resize(TRAIL_POINTS)
	_reset_trail(Vector2(global_position.x, global_position.z))

	_body = Node3D.new()
	_body.name = "HullAndCabin"
	add_child(_body)
	_build_appearance()
	_build_trailer()
	if START_WITH_TRAILER:
		set_trailer_enabled(true)


func steering_yaw_delta(steer: float, current_speed: float, delta: float) -> float:
	return -steer * TURN_RATE * delta * clampf(absf(current_speed) / 3.5, 0.0, 1.0) * (1.0 if current_speed >= 0.0 else -1.0)


func effective_max_speed() -> float:
	var base := MAX_SPEED + (2.0 if has_trailer else 0.0)
	var hp_factor := lerpf(0.60, 1.0, clampf(hull_hp / 100.0, 0.0, 1.0))
	var boost := 1.35 if (main != null and main.overdrive_timer > 0.0) else 1.0
	return base * hp_factor * boost


func effective_pump_range() -> float:
	return PUMP_RANGE + (2.5 if has_trailer else 0.0)


func effective_pump_seconds() -> float:
	return PUMP_SECONDS * (0.70 if has_trailer else 1.0)


func update_night_lights(night01: float, overdrive: bool) -> void:
	# Прожектор — короткий локальный луч перед носом, не замена лунному
	# или фоновому свету всей сцены. [H] отключает его для честного A/B.
	if _bow_spot != null:
		_bow_spot.light_energy = 12.0 * lerpf(0.12, 3.4, night01) * (1.35 if overdrive else 1.0)
		_bow_spot.spot_range = lerpf(18.0, 28.0, night01) * (1.20 if overdrive else 1.0)
	if _deck_light != null:
		_deck_light.light_energy = lerpf(0.10, 0.55, night01)
		_deck_light.omni_range = 5.5
	# Вернули первоначальный тёплый цвет света; прозрачное стекло и
	# умеренная яркость не дают белой непрозрачной пластины.
	var window_on := smoothstep(0.25, 0.82, night01)
	if _window_glass_mat != null:
		_window_glass_mat.emission_energy_multiplier = 0.85 * window_on
	if _window_light != null:
		_window_light.light_energy = 0.85 * window_on


func set_trailer_enabled(enabled: bool) -> void:
	has_trailer = enabled
	if _trailer != null:
		_trailer.visible = enabled
		var heading := -global_transform.basis.z
		_trailer.global_position = global_position - heading * TRAILER_DISTANCE
		_trailer.global_rotation = Vector3(0.0, rotation.y, 0.0)
		_trailer.reset_physics_interpolation()
	if not enabled:
		_trailer_target = null
		_trailer_pump_progress = 0.0
		if _trailer_hose != null:
			_trailer_hose.visible = false
		if _trailer_head != null:
			_trailer_head.visible = false
	if _tow_cable_l != null:
		_tow_cable_l.visible = enabled
	if _tow_cable_r != null:
		_tow_cable_r.visible = enabled


func trigger_refine_effect() -> void:
	_refine_flash = 1.0


func is_on_port_working_side(world_pos: Vector3) -> bool:
	var local := to_local(world_pos)
	return local.x < -0.30 and local.z > -4.8 and local.z < 4.8


func _physics_process(delta: float) -> void:
	if water == null or coast == null:
		return
	_anim_time += delta
	_refine_flash = maxf(0.0, _refine_flash - delta * 1.8)
	_impact_cooldown = maxf(0.0, _impact_cooldown - delta)

	var throttle := Input.get_axis("boat_reverse", "boat_forward")
	var steer := Input.get_axis("boat_left", "boat_right")
	_steer_visual = lerpf(_steer_visual, steer, minf(1.0, delta * 5.5))

	var max_spd := effective_max_speed()
	var target_speed := throttle * (max_spd if throttle >= 0.0 else REVERSE_SPEED)
	var prev_speed := speed
	speed = move_toward(speed, target_speed, (ACCELERATION if absf(throttle) > 0.01 else DRAG) * delta)
	var accel_rate := (speed - prev_speed) / maxf(delta, 0.001)

	# При текущем ракурсе положительный yaw ведёт нос ВЛЕВО на экране.
	# Input axis: A=-1, D=+1; A должен давать положительный yaw.
	rotation.y += steering_yaw_delta(steer, speed, delta)

	var heading := -global_transform.basis.z
	var right := global_transform.basis.x
	var next := global_position + heading * speed * delta

	# Проверка столкновения со скальными рифами
	var hit_reef := false
	if main != null:
		var next_xz := Vector2(next.x, next.z)
		for rf in main.reefs:
			var r_pos: Vector2 = rf["pos"]
			var r_rad: float = rf["radius"]
			var clearance := r_rad + 1.85
			if next_xz.distance_to(r_pos) < clearance:
				hit_reef = true
				# Не двигать корпус на фиксированные 0.45 м каждый тик: это
				# выглядело как резкие рывки даже при неподвижном судне.
				var away := global_position
				var gap := Vector2(away.x, away.z) - r_pos
				if gap.length_squared() < 0.0001:
					gap = Vector2(-heading.x, -heading.z)
				if gap.length() < clearance:
					var edge := r_pos + gap.normalized() * clearance
					away.x = edge.x
					away.z = edge.y
					if coast.water_depth(away.x, away.z) > 1.7 and _make_room_for_trailer(away):
						global_position = away
				if _impact_cooldown <= 0.0 and absf(speed) > 1.5:
					_impact_cooldown = 1.2
					var dmg := clampf(absf(speed) * 2.8, 6.0, 24.0)
					hull_hp = maxf(15.0, hull_hp - dmg)
					_roll_vel += (0.45 if _steer_visual >= 0.0 else -0.45)
					if water.field != null:
						water.field.splash(next_xz, 1.8)
					main.announce("УДАР О СКАЛЬНЫЙ РИФ! КОРПУС %d%% ([2] — РЕМОНТ)" % int(round(hull_hp)))
				# Гасим скорость, не создавая отскок в обратную сторону.
				speed = 0.0
				break

	if not hit_reef:
		if coast.water_depth(next.x, next.z) > 1.7:
			if _make_room_for_trailer(next):
				global_position = next
			else:
				speed = 0.0
		else:
			if _impact_cooldown <= 0.0 and absf(speed) > 4.5 and OS.get_environment("JOURNEY_BOAT_SMOKE") != "1":
				_impact_cooldown = 1.2
				hull_hp = maxf(15.0, hull_hp - 8.0)
				main.announce("ПОСАДКА НА МЕЛЬ! КОРПУС %d%%" % int(round(hull_hp)))
			speed = minf(speed, 0.0)

	# 5-точечный расчёт плавучести
	var bow_pt := global_position + heading * 4.4
	var stern_pt := global_position - heading * 4.4
	var port_pt := global_position - right * 1.55
	var star_pt := global_position + right * 1.55

	var h_center := water.surface_height(global_position.x, global_position.z)
	var h_bow := water.surface_height(bow_pt.x, bow_pt.z)
	var h_stern := water.surface_height(stern_pt.x, stern_pt.z)
	var h_port := water.surface_height(port_pt.x, port_pt.z)
	var h_star := water.surface_height(star_pt.x, star_pt.z)

	var avg_water := (h_center * 2.0 + h_bow + h_stern + h_port + h_star) / 6.0
	var target_y := avg_water + 0.08 - absf(speed) * 0.003
	var y_err := target_y - global_position.y
	_heave_vel = (_heave_vel + y_err * 28.0 * delta) * exp(-5.5 * delta)
	global_position.y += _heave_vel * delta

	var wave_pitch := atan2(h_bow - h_stern, 8.8)
	var dynamic_trim := clampf(speed * 0.004 + accel_rate * 0.007, -0.04, 0.06)
	var pitch_err := (wave_pitch + dynamic_trim) - _body.rotation.x
	_pitch_vel = (_pitch_vel + pitch_err * 30.0 * delta) * exp(-4.8 * delta)
	_body.rotation.x += _pitch_vel * delta

	var wave_roll := atan2(h_star - h_port, 3.1)
	var turn_heel := -_steer_visual * clampf(absf(speed) / MAX_SPEED, 0.0, 1.0) * 0.06
	var roll_err := (wave_roll + turn_heel) - _body.rotation.z
	_roll_vel = (_roll_vel + roll_err * 25.0 * delta) * exp(-4.2 * delta)
	_body.rotation.z += _roll_vel * delta

	_record_world_wake_trail(delta, heading)
	_update_animations(delta)
	_update_trailer(delta)
	_update_pump(delta)
	_sync_water_shader()


func _separate_trailer_from(boat_at: Vector3, trailer_at: Vector3) -> Vector3:
	var gap := Vector2(trailer_at.x - boat_at.x, trailer_at.z - boat_at.z)
	if gap.length_squared() >= TRAILER_CLEARANCE * TRAILER_CLEARANCE:
		return trailer_at
	if gap.length_squared() < 0.0001:
		gap = Vector2(global_transform.basis.z.x, global_transform.basis.z.z)
	gap = gap.normalized() * TRAILER_CLEARANCE
	return Vector3(boat_at.x + gap.x, trailer_at.y, boat_at.z + gap.y)


func _make_room_for_trailer(boat_next: Vector3) -> bool:
	if not has_trailer or _trailer == null:
		return true
	var pushed := _separate_trailer_from(boat_next, _trailer.global_position)
	if pushed.distance_squared_to(_trailer.global_position) < 0.000001:
		return true
	if coast.water_depth(pushed.x, pushed.z) < 1.2:
		return false
	_trailer.global_position = pushed
	return true


func _reset_trail(at: Vector2) -> void:
	_last_trail_pos = at
	_trail_timer = 0.0
	for i in range(TRAIL_POINTS):
		_trail_buffer[i] = Vector4(at.x, at.y, -100.0, 0.0)


func _record_world_wake_trail(delta: float, heading: Vector3) -> void:
	if water == null or water.field == null:
		return
	var now := water.field.t
	var stern_world := global_position - heading * 4.2
	var stern_xz := Vector2(stern_world.x, stern_world.z)
	var moved := stern_xz.distance_to(_last_trail_pos)
	if moved > 12.0:
		_reset_trail(stern_xz)
		moved = 0.0
	_trail_timer -= delta
	if (_trail_timer <= 0.0 and moved > 0.35) or moved > 2.5:
		_trail_timer = TRAIL_STEP_TIME
		_last_trail_pos = stern_xz
		for i in range(TRAIL_POINTS - 1, 0, -1):
			_trail_buffer[i] = _trail_buffer[i - 1]
	_trail_buffer[0] = Vector4(stern_xz.x, stern_xz.y, now, absf(speed))


func _sync_water_shader() -> void:
	if water == null:
		return
	water.set_param("u_vessel_state", Vector4(global_position.x, global_position.z, rotation.y, speed))
	water.set_param("u_wake_trail", _trail_buffer)
	if has_trailer and _trailer != null:
		water.set_param("u_trailer_state", Vector4(_trailer.global_position.x, _trailer.global_position.z, _trailer.rotation.y, 1.0))
	else:
		water.set_param("u_trailer_state", Vector4(0.0, 0.0, 0.0, 0.0))


func _update_animations(delta: float) -> void:
	if _radar != null:
		var radar_spd := 4.2 if (main != null and main.sonar_timer > 0.0) else 2.1
		_radar.rotation.y += delta * radar_spd
	if _rudder != null:
		_rudder.rotation.y = -_steer_visual * 0.48
	var prop_spin := (speed * 2.8 + (0.4 if absf(speed) < 0.2 else 0.0)) * delta
	if _prop_l != null:
		_prop_l.rotation.z += prop_spin
	if _prop_r != null:
		_prop_r.rotation.z -= prop_spin

	if main != null and _vat_fills.size() == 4:
		for i in range(4):
			var amount := float(main.raw[i]) * 0.22 + float(main.refined[i]) * 0.34
			var fill := clampf(0.10 + amount, 0.10, 1.0)
			var mesh_node := _vat_fills[i]
			mesh_node.scale.y = lerpf(mesh_node.scale.y, fill, minf(1.0, delta * 5.0))
			mesh_node.position.y = 1.06 + mesh_node.scale.y * 0.34
			var mat := _vat_mats[i]
			mat.emission_energy_multiplier = SHIP_EMISSION_BOOST * (0.35 + fill * 0.85 + _refine_flash * 1.5)
			if has_trailer and i < _trailer_sight_fills.size():
				var t_fill := clampf(0.12 + float(main.refined[i]) * 0.28, 0.12, 1.0)
				var tf := _trailer_sight_fills[i]
				tf.scale.y = lerpf(tf.scale.y, t_fill, minf(1.0, delta * 4.0))


func trailer_pickup_distance(world_pos: Vector3) -> float:
	if not has_trailer or _trailer == null:
		return INF
	var local := _trailer.to_local(world_pos)
	# Отсекаем ось прицепа и участок перед самым носом. За бортом же
	# измеряем расстояние до ближайшей точки на борту, а не до центра
	# корпуса: иначе соседнее пятно ложно кажется «далёким».
	if absf(local.x) < 0.85 or local.z < -2.8:
		return INF
	var rail_x := 1.4 if local.x > 0.0 else -1.4
	var rail_z := clampf(local.z, -1.9, 2.3)
	return Vector2(local.x - rail_x, local.z - rail_z).length()


func is_on_trailer_working_side(world_pos: Vector3) -> bool:
	# Пятно рисуется шире своей точки спавна: если его видимая кромка
	# касается рабочей зоны, сбор возможен и без точного совмещения центров.
	return trailer_pickup_distance(world_pos) < TRAILER_PUMP_RANGE + TRAILER_SLICK_RADIUS


func _update_pump(delta: float) -> void:
	# Ручной насос лодки по-прежнему работает только с левого борта.
	var p_range := effective_pump_range()
	var previous := _target
	_target = null
	wrong_side_target = false
	var best_d2 := p_range * p_range
	for slick in main.slicks:
		if slick.depleted or not is_on_port_working_side(slick.global_position):
			continue
		var at := slick.global_position
		var d2 := Vector2(global_position.x, global_position.z).distance_squared_to(Vector2(at.x, at.z))
		if d2 < best_d2:
			best_d2 = d2
			_target = slick
	if _target == null:
		wrong_side_target = main.nearest_resource(global_position, p_range) != null
	if _target != previous:
		_pump_progress = 0.0

	var drawing := Input.is_action_pressed("boat_pump") and _target != null and absf(speed) < 5.0
	if _crane_turret != null:
		var target_yaw := -0.18
		if _target != null:
			var local_t := _body.to_local(_target.global_position)
			var rel := local_t - _crane_turret.position
			target_yaw = clampf(atan2(rel.x, rel.z), -2.68, -0.36)
		_crane_turret.rotation.y = lerp_angle(_crane_turret.rotation.y, target_yaw, minf(1.0, delta * 5.0))
	if _crane_boom != null and _crane_jib != null:
		var boom_pitch := -0.25 if drawing else (0.05 if _target != null else 0.22)
		var jib_pitch := 0.55 if drawing else (0.35 if _target != null else 0.72)
		_crane_boom.rotation.x = lerpf(_crane_boom.rotation.x, boom_pitch, minf(1.0, delta * 5.5))
		_crane_jib.rotation.x = lerpf(_crane_jib.rotation.x, jib_pitch, minf(1.0, delta * 5.5))

	_hose.visible = false
	_intake_head.visible = false
	if drawing:
		_pump_progress += delta
		var to := _target.global_position + Vector3.UP * 0.10
		var pigment_col := ResourceSlick.COLORS[_target.kind]
		var tip := _crane_jib.to_global(Vector3(0.0, -0.12, 1.05))
		_hose_mat.albedo_color = pigment_col.darkened(0.35)
		_hose_mat.emission = pigment_col
		_hose_mat.emission_energy_multiplier = SHIP_EMISSION_BOOST * (0.65 + 0.35 * sin(_anim_time * 10.0))
		_intake_mat.albedo_color = pigment_col.darkened(0.15)
		_intake_mat.emission = pigment_col
		_hose.visible = true
		_place_cable(_hose, tip, to)
		_intake_head.visible = true
		_intake_head.global_position = to
		var pulse_s := 1.0 + 0.10 * sin(_anim_time * 8.0)
		_intake_head.scale = Vector3(pulse_s, 1.0, pulse_s)
		if _pump_progress >= effective_pump_seconds():
			main.receive_resource(_target.kind)
			_target.collect()
			_pump_progress = 0.0
	else:
		_pump_progress = maxf(0.0, _pump_progress - delta * 2.0)

	_update_trailer_pump(delta)


func _update_trailer_pump(delta: float) -> void:
	# Самостоятельная рука: обе стороны, без ПРОБЕЛА и ограничения
	# скорости — при проходе мимо пятна она должна успевать сработать.
	# Смена цели обнуляет прогресс.
	var previous := _trailer_target
	_trailer_hose.visible = false
	_trailer_head.visible = false
	if _trailer_target != null and (_trailer_target.depleted or
			not is_on_trailer_working_side(_trailer_target.global_position) or
			(_trailer_target == _target and Input.is_action_pressed("boat_pump"))):
		_trailer_target = null
	if _trailer_target == null and has_trailer and _trailer != null:
		var best_distance := TRAILER_PUMP_RANGE + TRAILER_SLICK_RADIUS
		for slick in main.slicks:
			if slick.depleted or (slick == _target and Input.is_action_pressed("boat_pump")):
				continue
			var distance := trailer_pickup_distance(slick.global_position)
			if distance < best_distance:
				best_distance = distance
				_trailer_target = slick
	if _trailer_target != previous:
		_trailer_pump_progress = 0.0

	var arm_yaw := 0.0
	if _trailer_target != null:
		var rel := _trailer_body.to_local(_trailer_target.global_position) - _trailer_arm_pivot.position
		arm_yaw = atan2(-rel.x, -rel.z)
	_trailer_arm_pivot.rotation.y = lerp_angle(_trailer_arm_pivot.rotation.y, arm_yaw, minf(1.0, delta * 5.0))
	if _trailer_target == null:
		return

	_trailer_pump_progress += delta
	var to := _trailer_target.global_position + Vector3.UP * 0.10
	var pigment_col := ResourceSlick.COLORS[_trailer_target.kind]
	var tip := _trailer_arm_pivot.to_global(Vector3(0.0, -0.02, -2.95))
	_trailer_hose_mat.albedo_color = pigment_col.darkened(0.35)
	_trailer_hose_mat.emission = pigment_col
	_trailer_hose.visible = true
	_place_cable(_trailer_hose, tip, to)
	_trailer_head_mat.albedo_color = pigment_col.darkened(0.15)
	_trailer_head_mat.emission = pigment_col
	_trailer_head.visible = true
	_trailer_head.global_position = to
	var pulse_s := 1.0 + 0.10 * sin(_anim_time * 8.0)
	_trailer_head.scale = Vector3(pulse_s, 1.0, pulse_s)
	if _trailer_pump_progress >= TRAILER_PUMP_SECONDS:
		main.receive_resource(_trailer_target.kind)
		_trailer_target.collect()
		_trailer_pump_progress = 0.0


func _update_trailer(delta: float) -> void:
	if not has_trailer or _trailer == null or water == null:
		return
	var stern_center := _body.to_global(Vector3(0.0, 0.85, 4.95))
	var trailer_pos := _trailer.global_position
	var to_hitch := stern_center - trailer_pos
	to_hitch.y = 0.0
	var dist := to_hitch.length()
	if dist > 0.001:
		var dir := to_hitch / dist
		var target_yaw := atan2(-dir.x, -dir.z)
		_trailer.rotation.y = lerp_angle(_trailer.rotation.y, target_yaw, minf(1.0, delta * 4.2))
		var pull_dist := 5.65
		if dist > pull_dist:
			var desired_xz := Vector2(stern_center.x, stern_center.z) - Vector2(dir.x, dir.z) * pull_dist
			var next_xz := Vector2(trailer_pos.x, trailer_pos.z).lerp(desired_xz, minf(1.0, delta * 7.5))
			if coast == null or coast.water_depth(next_xz.x, next_xz.y) > 1.2:
				trailer_pos.x = next_xz.x
				trailer_pos.z = next_xz.y

	var separated := _separate_trailer_from(global_position, trailer_pos)
	if coast != null and coast.water_depth(separated.x, separated.z) < 1.2:
		trailer_pos = _trailer.global_position
	else:
		trailer_pos = separated
	var t_surf := water.surface_height(trailer_pos.x, trailer_pos.z)
	trailer_pos.y = lerpf(trailer_pos.y, t_surf + 0.06, minf(1.0, delta * 3.8))
	_trailer.global_position = trailer_pos

	var t_head := -_trailer.global_transform.basis.z
	var t_right := _trailer.global_transform.basis.x
	var t_bow := trailer_pos + t_head * 2.8
	var t_stern := trailer_pos - t_head * 2.8
	var t_port := trailer_pos - t_right * 1.4
	var t_star := trailer_pos + t_right * 1.4
	var t_pitch := atan2(water.surface_height(t_bow.x, t_bow.z) - water.surface_height(t_stern.x, t_stern.z), 5.6)
	var t_roll := atan2(water.surface_height(t_star.x, t_star.z) - water.surface_height(t_port.x, t_port.z), 2.8)
	_trailer_body.rotation.x = lerpf(_trailer_body.rotation.x, t_pitch, minf(1.0, delta * 3.2))
	_trailer_body.rotation.z = lerpf(_trailer_body.rotation.z, t_roll, minf(1.0, delta * 3.2))

	var stern_l := _body.to_global(Vector3(-0.75, 0.92, 4.90))
	var stern_r := _body.to_global(Vector3( 0.75, 0.92, 4.90))
	var bow_l := _trailer_body.to_global(Vector3(-0.65, 0.58, -2.95))
	var bow_r := _trailer_body.to_global(Vector3( 0.65, 0.58, -2.95))
	_place_cable(_tow_cable_l, stern_l, bow_l)
	_place_cable(_tow_cable_r, stern_r, bow_r)


func _place_cable(cable: MeshInstance3D, a: Vector3, b: Vector3) -> void:
	if cable == null:
		return
	cable.global_position = (a + b) * 0.5
	var vec := b - a
	if vec.length_squared() > 0.001:
		cable.global_basis = Basis(Quaternion(Vector3.UP, vec.normalized()))
	cable.scale.y = vec.length()


func pump_fraction() -> float:
	return clampf(_pump_progress / effective_pump_seconds(), 0.0, 1.0)


func target_name() -> String:
	return ResourceSlick.NAMES[_target.kind] if _target != null and not _target.depleted else ""


func trailer_target_name() -> String:
	return ResourceSlick.NAMES[_trailer_target.kind] if _trailer_target != null and not _trailer_target.depleted else ""


func trailer_pump_fraction() -> float:
	return clampf(_trailer_pump_progress / TRAILER_PUMP_SECONDS, 0.0, 1.0)


# ---------------------------------------------------------------------------
# Инструменты процедурного судостроения
# ---------------------------------------------------------------------------

func _material(color: Color, metal := 0.0, glow := 0.0, rough := 0.68) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = metal
	mat.roughness = rough
	if glow > 0.0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = glow * SHIP_EMISSION_BOOST
	return mat


func _box_on(parent: Node3D, at: Vector3, size: Vector3, mat: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	part.mesh = box
	part.position = at
	part.rotation = rot
	part.material_override = mat
	parent.add_child(part)
	return part


func _cyl_on(parent: Node3D, at: Vector3, r_top: float, r_bot: float, h: float, mat: Material, rot := Vector3.ZERO, segs := 14) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = r_top
	cyl.bottom_radius = r_bot
	cyl.height = h
	cyl.radial_segments = segs
	part.mesh = cyl
	part.position = at
	part.rotation = rot
	part.material_override = mat
	parent.add_child(part)
	return part


func _tri_outward(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, outward: Vector3) -> void:
	var n := (c - a).cross(b - a).normalized()
	if n.dot(outward) < 0.0:
		n = -n
		st.set_normal(n)
		st.add_vertex(a)
		st.add_vertex(c)
		st.add_vertex(b)
	else:
		st.set_normal(n)
		st.add_vertex(a)
		st.add_vertex(b)
		st.add_vertex(c)


func _quad_outward(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, outward: Vector3) -> void:
	_tri_outward(st, a, b, c, outward)
	_tri_outward(st, a, c, d, outward)


func _loft_segment(
		parent: Node3D,
		z_front_bot: float, z_front_top: float,
		z_back_bot: float, z_back_top: float,
		y_bot: float, y_top: float,
		w_front_bot: float, w_front_top: float,
		w_back_bot: float, w_back_top: float,
		mat: Material) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var flb := Vector3(-w_front_bot * 0.5, y_bot, z_front_bot)
	var frb := Vector3( w_front_bot * 0.5, y_bot, z_front_bot)
	var flt := Vector3(-w_front_top * 0.5, y_top, z_front_top)
	var frt := Vector3( w_front_top * 0.5, y_top, z_front_top)

	var blb := Vector3(-w_back_bot * 0.5, y_bot, z_back_bot)
	var brb := Vector3( w_back_bot * 0.5, y_bot, z_back_bot)
	var blt := Vector3(-w_back_top * 0.5, y_top, z_back_top)
	var brt := Vector3( w_back_top * 0.5, y_top, z_back_top)

	_quad_outward(st, flt, frt, brt, blt, Vector3.UP)
	_quad_outward(st, flb, blb, brb, frb, Vector3.DOWN)
	_quad_outward(st, flb, flt, blt, blb, Vector3(-1.0, 0.15, 0.0))
	_quad_outward(st, frb, brb, brt, frt, Vector3(1.0, 0.15, 0.0))
	_quad_outward(st, flb, frb, frt, flt, Vector3(0.0, 0.1, -1.0))
	_quad_outward(st, blb, blt, brt, brb, Vector3(0.0, 0.1, 1.0))

	var inst := MeshInstance3D.new()
	inst.mesh = st.commit()
	inst.material_override = mat
	parent.add_child(inst)
	return inst


func _loft_bulwark(
		parent: Node3D,
		z_front: float, z_back: float,
		y_bot: float, y_top: float,
		w_front: float, w_back: float,
		thickness: float,
		mat: Material) -> void:
	for side in [-1.0, 1.0]:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var f_out_b := Vector3(side * (w_front * 0.5), y_bot, z_front)
		var f_out_t := Vector3(side * (w_front * 0.5), y_top, z_front)
		var f_in_b  := Vector3(side * maxf(0.02, w_front * 0.5 - thickness), y_bot, z_front)
		var f_in_t  := Vector3(side * maxf(0.02, w_front * 0.5 - thickness), y_top, z_front)

		var b_out_b := Vector3(side * (w_back * 0.5), y_bot, z_back)
		var b_out_t := Vector3(side * (w_back * 0.5), y_top, z_back)
		var b_in_b  := Vector3(side * maxf(0.02, w_back * 0.5 - thickness), y_bot, z_back)
		var b_in_t  := Vector3(side * maxf(0.02, w_back * 0.5 - thickness), y_top, z_back)

		_quad_outward(st, f_out_t, f_in_t, b_in_t, b_out_t, Vector3.UP)
		_quad_outward(st, f_out_b, b_out_b, b_in_b, f_in_b, Vector3.DOWN)
		_quad_outward(st, f_out_b, f_out_t, b_out_t, b_out_b, Vector3(side, 0.0, 0.0))
		_quad_outward(st, f_in_b, b_in_b, b_in_t, f_in_t, Vector3(-side, 0.0, 0.0))
		_quad_outward(st, f_out_b, f_in_b, f_in_t, f_out_t, Vector3(0.0, 0.0, -1.0))
		_quad_outward(st, b_out_b, b_out_t, b_in_t, b_in_b, Vector3(0.0, 0.0, 1.0))

		var inst := MeshInstance3D.new()
		inst.mesh = st.commit()
		inst.material_override = mat
		parent.add_child(inst)


func _build_appearance() -> void:
	var anti_fouling := _material(Color("47241f"), 0.08, 0.0, 0.78)
	var boot_stripe := _material(Color("12161a"), 0.15, 0.0, 0.65)
	var hull_steel := _material(Color("1e272e"), 0.30, 0.0, 0.66)
	var gunwale_steel := _material(Color("2b363e"), 0.35, 0.0, 0.60)
	var timber_fender := _material(Color("4a3b2f"), 0.04, 0.0, 0.84)
	var deck_steel := _material(Color("262f35"), 0.25, 0.0, 0.75)
	var deck_planks := _material(Color("57473a"), 0.05, 0.0, 0.80)
	var cabin_chalk := _material(Color("c4bfb2"), 0.08, 0.0, 0.68)
	var cabin_trim := _material(Color("3a444b"), 0.32, 0.0, 0.60)
	var roof_ochre := _material(Color("8c6239"), 0.22, 0.0, 0.62)
	var machinery := _material(Color("334042"), 0.42, 0.0, 0.55)
	var dark_iron := _material(Color("161c20"), 0.55, 0.0, 0.50)
	var aged_bronze := _material(Color("7d6340"), 0.62, 0.0, 0.45)
	# Одно стекло для ВСЕХ окон: прозрачное, тёмное днём, ночью целиком
	# светится тем же тёплым цветом, что и первый вариант рубки.
	var bridge_glass := _material(Color(0.04, 0.09, 0.12, 0.24), 0.15, 0.0, 0.22)
	bridge_glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bridge_glass.emission_enabled = true
	bridge_glass.emission = Color("ffd49a")
	bridge_glass.emission_energy_multiplier = 0.0
	_window_glass_mat = bridge_glass
	var warm_interior := _material(Color("d69e5c"), 0.10, 0.0, 0.30)

	# 1. ГЛАВНЫЙ СТАЛЬНОЙ КОРПУС
	_loft_segment(_body, -5.05, -5.25, -3.2, -3.2, -0.45, 0.08, 0.06, 0.12, 1.55, 1.95, anti_fouling)
	_loft_segment(_body, -5.25, -5.32, -3.2, -3.2,  0.08, 0.24, 0.12, 0.16, 1.95, 2.15, boot_stripe)
	_loft_segment(_body, -5.32, -5.65, -3.2, -3.2,  0.24, 0.92, 0.16, 0.28, 2.15, 2.68, hull_steel)

	_loft_segment(_body, -3.2, -3.2, -1.2, -1.2, -0.45, 0.08, 1.55, 1.95, 2.55, 2.95, anti_fouling)
	_loft_segment(_body, -3.2, -3.2, -1.2, -1.2,  0.08, 0.24, 1.95, 2.15, 2.95, 3.08, boot_stripe)
	_loft_segment(_body, -3.2, -3.2, -1.2, -1.2,  0.24, 0.92, 2.15, 2.68, 3.08, 3.36, hull_steel)

	_loft_segment(_body, -1.2, -1.2, 2.6, 2.6, -0.45, 0.08, 2.55, 2.95, 2.50, 2.90, anti_fouling)
	_loft_segment(_body, -1.2, -1.2, 2.6, 2.6,  0.08, 0.24, 2.95, 3.08, 2.90, 3.04, boot_stripe)
	_loft_segment(_body, -1.2, -1.2, 2.6, 2.6,  0.24, 0.88, 3.08, 3.36, 3.04, 3.30, hull_steel)

	_loft_segment(_body, 2.6, 2.6, 4.75, 4.90, -0.42, 0.08, 2.50, 2.90, 1.70, 2.25, anti_fouling)
	_loft_segment(_body, 2.6, 2.6, 4.90, 4.95,  0.08, 0.24, 2.90, 3.04, 2.25, 2.40, boot_stripe)
	_loft_segment(_body, 2.6, 2.6, 4.95, 5.08,  0.24, 0.88, 3.04, 3.30, 2.40, 2.68, hull_steel)

	# 2. НОСОВОЙ ПОЛУБАК
	_loft_segment(_body, -5.65, -5.80, -3.2, -3.2, 0.92, 1.18, 0.28, 0.34, 2.68, 2.82, hull_steel)
	_loft_segment(_body, -3.2,  -3.2,  -1.85,-1.85,0.92, 1.18, 2.68, 2.82, 3.36, 3.40, hull_steel)
	_loft_segment(_body, -5.60, -5.60, -3.2, -3.2, 1.14, 1.19, 0.24, 0.24, 2.58, 2.58, deck_steel)
	_loft_segment(_body, -3.2,  -3.2,  -1.85,-1.85,1.14, 1.19, 2.58, 2.58, 3.20, 3.20, deck_steel)

	_loft_bulwark(_body, -5.75, -3.20, 1.18, 1.34, 0.34, 2.82, 0.12, hull_steel)
	_loft_bulwark(_body, -3.20, -1.85, 1.18, 1.32, 2.82, 3.40, 0.12, hull_steel)
	_loft_bulwark(_body, -5.75, -3.20, 1.34, 1.39, 0.38, 2.88, 0.16, gunwale_steel)
	_loft_bulwark(_body, -3.20, -1.85, 1.32, 1.37, 2.88, 3.44, 0.16, gunwale_steel)

	_box_on(_body, Vector3(0.0, 1.28, -3.75), Vector3(0.48, 0.22, 0.36), machinery)
	_cyl_on(_body, Vector3(0.0, 1.32, -3.75), 0.12, 0.12, 0.68, dark_iron, Vector3(0.0, 0.0, PI * 0.5), 12)
	for side in [-1.0, 1.0]:
		_box_on(_body, Vector3(side * 0.62, 1.21, -3.15), Vector3(0.28, 0.05, 0.16), dark_iron)
		_cyl_on(_body, Vector3(side * 0.55, 1.28, -3.15), 0.045, 0.045, 0.16, dark_iron)
		_cyl_on(_body, Vector3(side * 0.69, 1.28, -3.15), 0.045, 0.045, 0.16, dark_iron)

	# 3. РАБОЧАЯ ПАЛУБА И КОРМОВОЙ ФАЛЬШБОРТ
	_box_on(_body, Vector3(0.0, 0.88, 1.55), Vector3(3.12, 0.06, 6.75), deck_steel)
	for i in range(7):
		var px := -1.20 + float(i) * 0.40
		_box_on(_body, Vector3(px, 0.915, 2.35), Vector3(0.36, 0.025, 4.85), deck_planks)

	for side in [-1.0, 1.0]:
		for seg_z in [-0.85, 0.75, 2.35, 3.85]:
			_box_on(_body, Vector3(side * 1.58, 1.08, seg_z), Vector3(0.08, 0.28, 1.32), hull_steel)
		_box_on(_body, Vector3(side * 1.59, 1.23, 1.55), Vector3(0.14, 0.05, 6.75), gunwale_steel)
		_box_on(_body, Vector3(side * 1.65, 0.78, 1.15), Vector3(0.10, 0.14, 6.65), timber_fender)
		for frame_z in [-1.4, -0.3, 0.8, 1.9, 3.0, 4.1]:
			_box_on(_body, Vector3(side * 1.52, 1.04, frame_z), Vector3(0.08, 0.32, 0.06), gunwale_steel)
		_box_on(_body, Vector3(side * 1.08, 0.93, 4.75), Vector3(0.30, 0.05, 0.18), dark_iron)
		_cyl_on(_body, Vector3(side * 1.01, 1.00, 4.75), 0.045, 0.045, 0.16, dark_iron)
		_cyl_on(_body, Vector3(side * 1.15, 1.00, 4.75), 0.045, 0.045, 0.16, dark_iron)

	_box_on(_body, Vector3(-0.85, 1.06, 4.96), Vector3(0.80, 0.32, 0.10), hull_steel)
	_box_on(_body, Vector3( 0.85, 1.06, 4.96), Vector3(0.80, 0.32, 0.10), hull_steel)
	_cyl_on(_body, Vector3( 0.00, 0.96, 4.98), 0.09, 0.09, 0.78, aged_bronze, Vector3(0.0, 0.0, PI * 0.5), 12)

	# 4. НАДСТРОЙКА И ХОДОВОЙ МОСТИК
	_box_on(_body, Vector3(0.0, 0.98, -1.05), Vector3(2.38, 0.16, 2.82), cabin_trim)
	_loft_segment(_body, -2.42, -2.35, 0.32, 0.32, 1.06, 1.98, 2.32, 2.26, 2.32, 2.26, cabin_chalk)
	_box_on(_body, Vector3(-0.45, 1.48, 0.33), Vector3(0.56, 0.82, 0.06), cabin_trim)
	_box_on(_body, Vector3(-0.45, 1.62, 0.36), Vector3(0.28, 0.24, 0.04), bridge_glass)
	for side in [-1.0, 1.0]:
		for wz in [-1.65, -0.85]:
			_box_on(_body, Vector3(side * 1.15, 1.56, wz), Vector3(0.06, 0.34, 0.46), cabin_trim)
			_box_on(_body, Vector3(side * 1.17, 1.56, wz), Vector3(0.04, 0.24, 0.36), bridge_glass)
		_cyl_on(_body, Vector3(side * 1.17, 1.46, -0.10), 0.22, 0.22, 0.06, _material(Color("b84b39"), 0.05, 0.0, 0.7), Vector3(0.0, 0.0, PI * 0.5), 14)

	_box_on(_body, Vector3(0.0, 2.01, -1.08), Vector3(2.96, 0.07, 2.55), cabin_trim)
	for side in [-1.0, 1.0]:
		_box_on(_body, Vector3(side * 1.42, 2.22, -1.08), Vector3(0.06, 0.38, 1.85), cabin_chalk)
		var nav_col := Color("d93829") if side < 0.0 else Color("29b856")
		_box_on(_body, Vector3(side * 1.44, 2.32, -1.72), Vector3(0.12, 0.16, 0.34), cabin_trim)
		_cyl_on(_body, Vector3(side * 1.46, 2.32, -1.72), 0.05, 0.05, 0.12, _material(nav_col, 0.1, 1.8, 0.2))

	_loft_segment(_body, -2.18, -2.42, -0.32, -0.28, 2.04, 2.82, 1.98, 2.12, 2.06, 1.98, cabin_chalk)
	_box_on(_body, Vector3(0.0, 2.36, -1.45), Vector3(1.55, 0.32, 1.15), warm_interior)
	_loft_segment(_body, -2.20, -2.40, -2.14, -2.34, 2.26, 2.72, 1.84, 1.96, 1.84, 1.96, bridge_glass)
	for mx in [-0.58, 0.0, 0.58]:
		_box_on(_body, Vector3(mx, 2.49, -2.31), Vector3(0.05, 0.50, 0.08), cabin_trim, Vector3(-0.38, 0.0, 0.0))
	for side in [-1.0, 1.0]:
		_box_on(_body, Vector3(side * 1.02, 2.48, -1.32), Vector3(0.06, 0.44, 1.52), bridge_glass)
		_box_on(_body, Vector3(side * 1.03, 2.48, -1.32), Vector3(0.07, 0.48, 0.06), cabin_trim)
	_box_on(_body, Vector3(-0.48, 2.48, -0.29), Vector3(0.72, 0.42, 0.06), bridge_glass)
	_window_light = OmniLight3D.new()
	_window_light.light_color = Color("ffd49a")
	_window_light.light_energy = 0.0
	_window_light.omni_range = 3.8
	_window_light.position = Vector3(0.0, 2.40, -1.35)
	_body.add_child(_window_light)

	_loft_segment(_body, -2.62, -2.52, -0.18, -0.22, 2.82, 2.94, 2.28, 2.14, 2.16, 2.04, roof_ochre)

	# Прожектор, радар и сигнальная мачта
	_cyl_on(_body, Vector3(0.0, 3.08, -2.28), 0.11, 0.13, 0.26, dark_iron, Vector3(PI * 0.5 - 0.28, 0.0, 0.0), 12)
	_cyl_on(_body, Vector3(0.0, 3.12, -2.38), 0.09, 0.09, 0.06, _material(Color("ffdf9e"), 0.1, 2.0, 0.2), Vector3(PI * 0.5 - 0.28, 0.0, 0.0), 12)
	_bow_spot = SpotLight3D.new()
	_bow_spot.light_color = Color("ffe8ba")
	_bow_spot.light_energy = 24.0
	_bow_spot.spot_range = 24.0
	_bow_spot.spot_angle = 30.0
	_bow_spot.light_volumetric_fog_energy = 2.0
	_bow_spot.position = Vector3(0.0, 3.12, -2.45)
	# -Z вдоль курса, наклон вниз: пятно на воде в нескольких метрах
	# перед носом, а не вдали под туманом.
	_bow_spot.rotation = Vector3(-0.48, 0.0, 0.0)
	_body.add_child(_bow_spot)

	_cyl_on(_body, Vector3(0.0, 3.12, -1.35), 0.10, 0.14, 0.36, cabin_chalk)
	_radar = Node3D.new()
	_radar.position = Vector3(0.0, 3.32, -1.35)
	_body.add_child(_radar)
	_box_on(_radar, Vector3(0.0, 0.04, 0.0), Vector3(1.08, 0.10, 0.18), cabin_chalk)

	for side in [-1.0, 1.0]:
		_cyl_on(_body, Vector3(side * 0.36, 3.68, -0.52), 0.03, 0.05, 1.62, dark_iron, Vector3(0.12, 0.0, side * 0.20), 8)
	_cyl_on(_body, Vector3(0.0, 3.92, -0.60), 0.025, 0.025, 1.45, dark_iron, Vector3(0.0, 0.0, PI * 0.5), 8)
	_cyl_on(_body, Vector3(0.0, 4.46, -0.62), 0.06, 0.06, 0.14, _material(Color("ffcf87"), 0.1, 1.8, 0.2))

	# 5. МАШИННЫЙ КОЖУХ И ТРУБА ПО ПРАВОМУ БОРТУ
	_box_on(_body, Vector3(0.46, 1.36, 0.95), Vector3(1.18, 0.88, 1.25), cabin_trim)
	var stack_node := Node3D.new()
	stack_node.position = Vector3(0.46, 1.80, 0.95)
	_body.add_child(stack_node)
	_loft_segment(stack_node, -0.42, -0.25, 0.42, 0.56, 0.0, 0.95, 0.68, 0.56, 0.68, 0.56, roof_ochre)
	_loft_segment(stack_node, -0.25, -0.18, 0.56, 0.62, 0.95, 1.22, 0.56, 0.52, 0.56, 0.52, dark_iron)
	_cyl_on(stack_node, Vector3(-0.12, 1.30, 0.22), 0.07, 0.07, 0.24, dark_iron, Vector3(0.18, 0.0, 0.0), 10)
	_cyl_on(stack_node, Vector3( 0.12, 1.30, 0.22), 0.07, 0.07, 0.24, dark_iron, Vector3(0.18, 0.0, 0.0), 10)

	# 6. КРАН-МАНИПУЛЯТОР И НАСОС НА ЛЕВОМ БОРТУ
	_cyl_on(_body, Vector3(-1.22, 1.08, 0.95), 0.26, 0.30, 0.36, cabin_trim)
	_box_on(_body, Vector3(-0.82, 1.08, 0.95), Vector3(0.56, 0.34, 0.62), machinery)
	_cyl_on(_body, Vector3(-0.55, 1.12, 1.55), 0.06, 0.06, 1.25, dark_iron, Vector3(PI * 0.5, 0.0, 0.0), 10)

	_crane_turret = Node3D.new()
	_crane_turret.position = Vector3(-1.22, 1.26, 0.95)
	_crane_turret.rotation.y = -0.18
	_body.add_child(_crane_turret)
	_cyl_on(_crane_turret, Vector3(0.0, 0.26, 0.0), 0.16, 0.20, 0.52, machinery)
	_box_on(_crane_turret, Vector3(0.0, 0.56, -0.05), Vector3(0.26, 0.24, 0.34), dark_iron)

	_crane_boom = Node3D.new()
	_crane_boom.position = Vector3(0.0, 0.62, 0.0)
	_crane_turret.add_child(_crane_boom)
	_box_on(_crane_boom, Vector3(0.0, 0.14, 0.62), Vector3(0.14, 0.16, 1.32), machinery, Vector3(-0.20, 0.0, 0.0))
	_cyl_on(_crane_boom, Vector3(0.0, -0.02, 0.45), 0.045, 0.055, 0.78, aged_bronze, Vector3(1.15, 0.0, 0.0), 8)

	_crane_jib = Node3D.new()
	_crane_jib.position = Vector3(0.0, 0.26, 1.18)
	_crane_boom.add_child(_crane_jib)
	_box_on(_crane_jib, Vector3(0.0, 0.0, 0.52), Vector3(0.11, 0.12, 1.10), machinery)
	_cyl_on(_crane_jib, Vector3(0.0, -0.08, 1.05), 0.10, 0.14, 0.22, dark_iron)

	# 7. КОРМОВОЙ ПРОМЫШЛЕННЫЙ МАНИФОЛЬД И 4 ТАНКА
	_box_on(_body, Vector3(0.0, 0.96, 3.00), Vector3(2.26, 0.10, 2.08), cabin_trim)
	_box_on(_body, Vector3(0.0, 1.52, 3.00), Vector3(0.16, 1.05, 1.95), dark_iron)

	_vat_fills.clear()
	_vat_mats.clear()
	var tank_coords := [
		Vector3(-0.62, 0.0, 2.48),
		Vector3( 0.62, 0.0, 2.48),
		Vector3(-0.62, 0.0, 3.52),
		Vector3( 0.62, 0.0, 3.52),
	]
	for i in range(4):
		var tc: Vector3 = tank_coords[i]
		var side_sign := -1.0 if tc.x < 0.0 else 1.0
		_cyl_on(_body, Vector3(tc.x, 1.42, tc.z), 0.34, 0.34, 0.84, gunwale_steel, Vector3.ZERO, 16)
		_cyl_on(_body, Vector3(tc.x, 1.86, tc.z), 0.28, 0.35, 0.10, cabin_trim, Vector3.ZERO, 16)
		_cyl_on(_body, Vector3(tc.x, 1.22, tc.z), 0.355, 0.355, 0.05, dark_iron, Vector3.ZERO, 16)
		_cyl_on(_body, Vector3(tc.x, 1.62, tc.z), 0.355, 0.355, 0.05, dark_iron, Vector3.ZERO, 16)
		var ring_mat := _material(ResourceSlick.COLORS[i].darkened(0.25), 0.2, 0.25, 0.5)
		_cyl_on(_body, Vector3(tc.x, 1.93, tc.z), 0.14, 0.14, 0.06, ring_mat, Vector3.ZERO, 12)

		_box_on(_body, Vector3(tc.x + side_sign * 0.32, 1.42, tc.z), Vector3(0.06, 0.72, 0.16), dark_iron)
		var f_mat := _material(ResourceSlick.COLORS[i], 0.1, 0.75, 0.25)
		var f_bar := _box_on(_body, Vector3(tc.x + side_sign * 0.34, 1.12, tc.z), Vector3(0.05, 0.66, 0.10), f_mat)
		f_bar.scale.y = 0.12
		_vat_fills.append(f_bar)
		_vat_mats.append(f_mat)

	# 8. КОРМОВОЙ ПОРТАЛ И ВИНТОРУЛЕВАЯ ГРУППА
	for side in [-1.0, 1.0]:
		_box_on(_body, Vector3(side * 1.22, 1.68, 4.45), Vector3(0.12, 1.56, 0.16), cabin_trim, Vector3(-0.14, 0.0, side * 0.12))
	_box_on(_body, Vector3(0.0, 2.42, 4.35), Vector3(2.38, 0.14, 0.18), roof_ochre)

	_rudder = Node3D.new()
	_rudder.position = Vector3(0.0, -0.12, 4.82)
	_body.add_child(_rudder)
	_box_on(_rudder, Vector3(0.0, 0.0, 0.20), Vector3(0.08, 0.54, 0.42), dark_iron)

	_prop_l = _build_propeller(Vector3(-0.65, -0.15, 4.72), aged_bronze)
	_prop_r = _build_propeller(Vector3( 0.65, -0.15, 4.72), aged_bronze)

	_deck_light = OmniLight3D.new()
	_deck_light.light_color = Color("ffd296")
	_deck_light.light_energy = 0.90
	_deck_light.omni_range = 9.5
	_deck_light.position = Vector3(0.0, 2.35, 2.40)
	_body.add_child(_deck_light)

	_hose = MeshInstance3D.new()
	var tube := CylinderMesh.new()
	tube.top_radius = 0.06
	tube.bottom_radius = 0.085
	tube.height = 1.0
	_hose.mesh = tube
	_hose_mat = _material(Color("2e524e"), 0.2, 0.8, 0.45)
	_hose.material_override = _hose_mat
	_hose.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_hose.visible = false
	add_child(_hose)

	_intake_head = MeshInstance3D.new()
	var head_cyl := CylinderMesh.new()
	head_cyl.top_radius = 0.34
	head_cyl.bottom_radius = 0.42
	head_cyl.height = 0.16
	_intake_head.mesh = head_cyl
	_intake_mat = _material(Color("459990"), 0.2, 1.1, 0.35)
	_intake_head.material_override = _intake_mat
	_intake_head.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_intake_head.visible = false
	add_child(_intake_head)


func _build_propeller(at: Vector3, mat: Material) -> Node3D:
	var hub := Node3D.new()
	hub.position = at
	_body.add_child(hub)
	_cyl_on(hub, Vector3.ZERO, 0.09, 0.09, 0.22, mat, Vector3(PI * 0.5, 0.0, 0.0), 10)
	for i in range(3):
		var a := float(i) * TAU / 3.0
		var blade := _box_on(hub, Vector3(cos(a) * 0.18, sin(a) * 0.18, 0.03), Vector3(0.24, 0.08, 0.025), mat)
		blade.rotation.z = a
	return hub


func _build_trailer() -> void:
	_trailer = Node3D.new()
	_trailer.name = "TowedEquipmentBarge"
	_trailer.top_level = true
	_trailer.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON
	_trailer.visible = false
	add_child(_trailer)

	_trailer_body = Node3D.new()
	_trailer.add_child(_trailer_body)

	var anti_fouling := _material(Color("47241f"), 0.08, 0.0, 0.78)
	var hull_steel := _material(Color("1e272e"), 0.30, 0.0, 0.66)
	var gunwale_steel := _material(Color("2b363e"), 0.35, 0.0, 0.60)
	var deck_steel := _material(Color("262f35"), 0.25, 0.0, 0.75)
	var roof_ochre := _material(Color("8c6239"), 0.22, 0.0, 0.62)
	var dark_iron := _material(Color("161c20"), 0.55, 0.0, 0.50)
	var cable_steel := _material(Color("384248"), 0.65, 0.0, 0.45)

	_loft_segment(_trailer_body, -2.75, -3.05, -2.0, -2.0, -0.32, 0.12, 2.20, 2.52, 2.48, 2.65, anti_fouling)
	_loft_segment(_trailer_body, -2.0,  -2.0,   2.0,  2.0, -0.32, 0.12, 2.48, 2.65, 2.48, 2.65, anti_fouling)
	_loft_segment(_trailer_body,  2.0,   2.0,   2.75, 2.95,-0.32, 0.12, 2.48, 2.65, 2.25, 2.50, anti_fouling)

	_loft_segment(_trailer_body, -3.05, -3.15, -2.0, -2.0, 0.12, 0.56, 2.52, 2.62, 2.65, 2.74, hull_steel)
	_loft_segment(_trailer_body, -2.0,  -2.0,   2.0,  2.0, 0.12, 0.56, 2.65, 2.74, 2.65, 2.74, hull_steel)
	_loft_segment(_trailer_body,  2.0,   2.0,   2.95, 3.05,0.12, 0.56, 2.65, 2.74, 2.50, 2.60, hull_steel)

	_box_on(_trailer_body, Vector3(0.0, 0.57, 0.0), Vector3(2.58, 0.05, 5.85), deck_steel)
	for side in [-1.0, 1.0]:
		_box_on(_trailer_body, Vector3(side * 1.32, 0.66, 0.0), Vector3(0.10, 0.16, 5.65), gunwale_steel)
		_cyl_on(_trailer_body, Vector3(side * 0.65, 0.66, -2.85), 0.05, 0.05, 0.18, dark_iron)

	_box_on(_trailer_body, Vector3(0.0, 0.98, -0.55), Vector3(1.92, 0.78, 2.15), gunwale_steel)
	_box_on(_trailer_body, Vector3(0.0, 1.40, -0.55), Vector3(2.02, 0.08, 2.24), roof_ochre)

	_trailer_sight_fills.clear()
	for i in range(4):
		var tx := -0.58 if (i % 2 == 0) else 0.58
		var tz := 1.15 + float(i) / 2.0 * 0.92
		_cyl_on(_trailer_body, Vector3(tx, 0.92, tz), 0.28, 0.28, 0.72, gunwale_steel, Vector3.ZERO, 14)
		_cyl_on(_trailer_body, Vector3(tx, 1.30, tz), 0.22, 0.28, 0.08, dark_iron, Vector3.ZERO, 14)
		var s_mat := _material(ResourceSlick.COLORS[i], 0.1, 0.65, 0.3)
		var s_bar := _box_on(_trailer_body, Vector3(tx, 0.92, tz + 0.26), Vector3(0.12, 0.48, 0.06), s_mat)
		s_bar.scale.y = 0.2
		_trailer_sight_fills.append(s_bar)

	_cyl_on(_trailer_body, Vector3(0.0, 1.25, 2.65), 0.03, 0.04, 1.35, dark_iron)
	_cyl_on(_trailer_body, Vector3(0.0, 1.96, 2.65), 0.07, 0.07, 0.14, _material(Color("ffdfa0"), 0.1, 1.8, 0.2))

	# Одна поворотная рука обслуживает оба борта прицепа; центр и нос
	# намеренно не входят в рабочую зону (is_on_trailer_working_side).
	_trailer_arm_pivot = Node3D.new()
	# Поворотный шарнир в геометрическом центре палубы, выше крыши
	# надстройки; длинная стрела физически дотягивается до обоих бортов.
	_trailer_arm_pivot.position = Vector3(0.0, 1.72, 0.0)
	_trailer_body.add_child(_trailer_arm_pivot)
	_cyl_on(_trailer_arm_pivot, Vector3(0.0, -0.12, 0.0),
		0.32, 0.36, 0.54, dark_iron)
	_box_on(_trailer_arm_pivot, Vector3(0.0, 0.12, -1.45),
		Vector3(0.32, 0.24, 2.90), cable_steel)
	_box_on(_trailer_arm_pivot, Vector3(0.0, -0.10, -2.43),
		Vector3(0.20, 0.20, 0.95), gunwale_steel)
	_cyl_on(_trailer_arm_pivot, Vector3(0.0, -0.02, -2.95),
		0.21, 0.21, 0.24, dark_iron)
	_trailer_hose_mat = _material(Color("459990"), 0.15, 0.9, 0.45)
	_trailer_hose = MeshInstance3D.new()
	var hose_mesh := CylinderMesh.new()
	hose_mesh.top_radius = 0.045
	hose_mesh.bottom_radius = 0.045
	hose_mesh.height = 1.0
	_trailer_hose.mesh = hose_mesh
	_trailer_hose.material_override = _trailer_hose_mat
	_trailer_hose.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_trailer_hose.visible = false
	_trailer.add_child(_trailer_hose)
	_trailer_head_mat = _material(Color("459990"), 0.15, 1.2, 0.45)
	_trailer_head = _cyl_on(_trailer, Vector3.ZERO, 0.22, 0.27,
		0.14, _trailer_head_mat)
	_trailer_head.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_trailer_head.visible = false

	var c_mesh := CylinderMesh.new()
	c_mesh.top_radius = 0.032
	c_mesh.bottom_radius = 0.032
	c_mesh.height = 1.0

	_tow_cable_l = MeshInstance3D.new()
	_tow_cable_l.top_level = true
	_tow_cable_l.mesh = c_mesh
	_tow_cable_l.material_override = cable_steel
	_tow_cable_l.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_tow_cable_l.visible = false
	add_child(_tow_cable_l)

	_tow_cable_r = MeshInstance3D.new()
	_tow_cable_r.top_level = true
	_tow_cable_r.mesh = c_mesh
	_tow_cable_r.material_override = cable_steel
	_tow_cable_r.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_tow_cable_r.visible = false
	add_child(_tow_cable_r)
