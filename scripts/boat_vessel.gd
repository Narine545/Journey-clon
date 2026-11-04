class_name BoatVessel
extends Node3D
## Малое научно-исследовательское судно траулерного типа («Приливная лаборатория»).
## Реальная морская компоновка: носовой полубак, смещённая в нос рубка с крыльями мостика,
## дымовая труба по правому борту, гидравлический кран-насос СТРОГО по левому борту,
## кормовой манифольд с 4 баками, А-образный портал и буксируемый стальной плашкоут.

const MAX_SPEED := 10.0
const REVERSE_SPEED := 4.0
const ACCELERATION := 3.2
const DRAG := 1.8
const TURN_RATE := 0.95
const PUMP_RANGE := 6.5
const PUMP_SECONDS := 1.4

const START_WITH_TRAILER := false
const TRAILER_DISTANCE := 8.8

var main: BoatMain
var water: WaterSurface
var coast: Coast
var speed := 0.0
var has_trailer := false
var wrong_side_target := false

var _wake_timer := 0.0
var _trailer_wake_timer := 0.0
var _pump_progress := 0.0
var _anim_time := 0.0
var _steer_visual := 0.0
var _throttle_visual := 0.0
var _refine_flash := 0.0

# Пружинно-демпферная физика качки на волнах
var _heave_vel := 0.0
var _pitch_vel := 0.0
var _roll_vel := 0.0

var _target: ResourceSlick
var _body: Node3D
var _radar: Node3D
var _rudder: Node3D
var _prop_l: Node3D
var _prop_r: Node3D

# Кран-манипулятор левого борта
var _crane_turret: Node3D
var _crane_boom: Node3D
var _crane_jib: Node3D
var _hose: MeshInstance3D
var _hose_mat: StandardMaterial3D
var _intake_head: MeshInstance3D
var _intake_mat: StandardMaterial3D

# Индикаторы заполнения 4 промышленных танков на корме
var _vat_fills: Array[MeshInstance3D] = []
var _vat_mats: Array[StandardMaterial3D] = []

# Буксируемый плашкоут (прицеп)
var _trailer: Node3D
var _trailer_body: Node3D
var _tow_cable_l: MeshInstance3D
var _tow_cable_r: MeshInstance3D
var _trailer_Sight_fills: Array[MeshInstance3D] = []


func setup(boat_main: BoatMain, water_ref: WaterSurface, coast_ref: Coast) -> void:
	main = boat_main
	water = water_ref
	coast = coast_ref
	_body = Node3D.new()
	_body.name = "HullAndCabin"
	add_child(_body)
	_build_appearance()
	_build_trailer()
	if START_WITH_TRAILER:
		set_trailer_enabled(true)


func effective_max_speed() -> float:
	return MAX_SPEED + (2.0 if has_trailer else 0.0)


func effective_pump_range() -> float:
	return PUMP_RANGE + (2.5 if has_trailer else 0.0)


func effective_pump_seconds() -> float:
	return PUMP_SECONDS * (0.70 if has_trailer else 1.0)


func set_trailer_enabled(enabled: bool) -> void:
	has_trailer = enabled
	if _trailer != null:
		_trailer.visible = enabled
		var heading := -global_transform.basis.z
		_trailer.global_position = global_position - heading * TRAILER_DISTANCE
		_trailer.global_rotation = Vector3(0.0, rotation.y, 0.0)
	if _tow_cable_l != null:
		_tow_cable_l.visible = enabled
	if _tow_cable_r != null:
		_tow_cable_r.visible = enabled
	if enabled and water != null and water.field != null:
		water.field.splash(Vector2(_trailer.global_position.x, _trailer.global_position.z), 1.6)


func trigger_refine_effect() -> void:
	_refine_flash = 1.0


## Проверяет, находится ли пятно со стороны рабочего ЛЕВОГО борта (-X)
func is_on_port_working_side(world_pos: Vector3) -> bool:
	var local := to_local(world_pos)
	# Кран стоит на левом борту (X < 0). Запрещаем захват через правый борт и сквозь рубку:
	return local.x < -0.30 and local.z > -4.8 and local.z < 4.8


func _physics_process(delta: float) -> void:
	if water == null or coast == null:
		return
	_anim_time += delta
	_refine_flash = maxf(0.0, _refine_flash - delta * 1.8)

	var throttle := Input.get_axis("boat_reverse", "boat_forward")
	var steer := Input.get_axis("boat_left", "boat_right")
	_steer_visual = lerpf(_steer_visual, steer, minf(1.0, delta * 5.5))
	_throttle_visual = lerpf(_throttle_visual, throttle, minf(1.0, delta * 3.5))

	var max_spd := effective_max_speed()
	var target_speed := throttle * (max_spd if throttle >= 0.0 else REVERSE_SPEED)
	var prev_speed := speed
	speed = move_toward(speed, target_speed, (ACCELERATION if absf(throttle) > 0.01 else DRAG) * delta)
	var accel_rate := (speed - prev_speed) / maxf(delta, 0.001)

	rotation.y += steer * TURN_RATE * delta * clampf(absf(speed) / 3.5, 0.0, 1.0) * (1.0 if speed >= 0.0 else -1.0)

	var heading := -global_transform.basis.z
	var right := global_transform.basis.x
	var next := global_position + heading * speed * delta
	if coast.water_depth(next.x, next.z) > 1.7:
		global_position = next
	else:
		speed = minf(speed, 0.0)

	# 5-точечный замер поверхности воды для реалистичной качки (Heave, Pitch, Roll)
	var bow_pt := global_position + heading * 4.4
	var stern_pt := global_position - heading * 4.4
	var port_pt := global_position - right * 1.55
	var star_pt := global_position + right * 1.55

	var h_center := water.surface_height(global_position.x, global_position.z)
	var h_bow := water.surface_height(bow_pt.x, bow_pt.z)
	var h_stern := water.surface_height(stern_pt.x, stern_pt.z)
	var h_port := water.surface_height(port_pt.x, port_pt.z)
	var h_star := water.surface_height(star_pt.x, star_pt.z)

	# Средняя взвешенная ватерлиния + проседание кормы (squat) на полном ходу
	var avg_water := (h_center * 2.0 + h_bow + h_stern + h_port + h_star) / 6.0
	var target_y := avg_water + 0.08 - absf(speed) * 0.004
	var y_err := target_y - global_position.y
	_heave_vel = (_heave_vel + y_err * 28.0 * delta) * exp(-5.5 * delta)
	global_position.y += _heave_vel * delta

	# Продольная килевая качка (Pitch) + подъём носа при тяге винтов
	var wave_pitch := atan2(h_bow - h_stern, 8.8)
	var dynamic_trim := clampf(speed * 0.0045 + accel_rate * 0.008, -0.04, 0.065)
	var target_pitch := wave_pitch + dynamic_trim
	var pitch_err := target_pitch - _body.rotation.x
	_pitch_vel = (_pitch_vel + pitch_err * 32.0 * delta) * exp(-4.8 * delta)
	_body.rotation.x += _pitch_vel * delta

	# Бортовая качка (Roll) + гидродинамический крен в циркуляции
	var wave_roll := atan2(h_star - h_port, 3.1)
	var turn_heel := -_steer_visual * clampf(absf(speed) / MAX_SPEED, 0.0, 1.0) * 0.065
	var target_roll := wave_roll + turn_heel
	var roll_err := target_roll - _body.rotation.z
	_roll_vel = (_roll_vel + roll_err * 26.0 * delta) * exp(-4.2 * delta)
	_body.rotation.z += _roll_vel * delta

	# Генерация волновых колец от носовых скул и кормы в WaterField
	_wake_timer -= delta
	if absf(speed) > 0.8 and _wake_timer <= 0.0:
		_wake_timer = clampf(0.26 - absf(speed) * 0.012, 0.12, 0.26)
		var amp := clampf(absf(speed) / 6.5, 0.25, 1.45)
		var stern_wake := global_position - heading * 4.8
		var bow_wake := global_position + heading * 4.5
		water.field.wake(Vector2(stern_wake.x, stern_wake.z), amp)
		if absf(speed) > 2.8:
			water.field.splash(Vector2(bow_wake.x, bow_wake.z), amp * 0.55)

	_update_animations(delta)
	_update_pump(delta)
	_update_trailer(delta)
	_sync_water_shader()


## Передаём точное положение, курс и скорость корабля и прицепа в шейдер воды
func _sync_water_shader() -> void:
	if water == null:
		return
	water.set_param("u_vessel_state", Vector4(global_position.x, global_position.z, rotation.y, speed))
	if has_trailer and _trailer != null:
		water.set_param("u_trailer_state", Vector4(_trailer.global_position.x, _trailer.global_position.z, _trailer.rotation.y, 1.0))
	else:
		water.set_param("u_trailer_state", Vector4(0.0, 0.0, 0.0, 0.0))


func _update_animations(delta: float) -> void:
	if _radar != null:
		_radar.rotation.y += delta * 2.1
	if _rudder != null:
		_rudder.rotation.y = -_steer_visual * 0.48
	var prop_spin := (speed * 2.8 + (0.4 if absf(speed) < 0.2 else 0.0)) * delta
	if _prop_l != null:
		_prop_l.rotation.z += prop_spin
	if _prop_r != null:
		_prop_r.rotation.z -= prop_spin

	# Обновляем уровень в водомерных окнах 4 танков
	if main != null and _vat_fills.size() == 4:
		for i in range(4):
			var amount := float(main.raw[i]) * 0.22 + float(main.refined[i]) * 0.34
			var fill := clampf(0.10 + amount, 0.10, 1.0)
			var mesh_node := _vat_fills[i]
			mesh_node.scale.y = lerpf(mesh_node.scale.y, fill, minf(1.0, delta * 5.0))
			mesh_node.position.y = 1.06 + mesh_node.scale.y * 0.34
			var mat := _vat_mats[i]
			mat.emission_energy_multiplier = 0.35 + fill * 0.85 + _refine_flash * 1.5
			if has_trailer and i < _trailer_Sight_fills.size():
				var t_fill := clampf(0.12 + float(main.refined[i]) * 0.28, 0.12, 1.0)
				var tf := _trailer_Sight_fills[i]
				tf.scale.y = lerpf(tf.scale.y, t_fill, minf(1.0, delta * 4.0))


func _update_pump(delta: float) -> void:
	var p_range := effective_pump_range()
	var p_secs := effective_pump_seconds()

	# Ищем ближайшее пятно строго по ЛЕВОМУ борту
	_target = null
	wrong_side_target = false
	var any_near := main.nearest_resource(global_position, p_range)
	if any_near != null:
		if is_on_port_working_side(any_near.global_position):
			_target = any_near
		else:
			# Проверяем, нет ли другого доступного пятна по левому борту
			var best_d2 := p_range * p_range
			for slick in main.slicks:
				if slick.depleted:
					continue
				var d2 := Vector2(global_position.x, global_position.z).distance_squared_to(Vector2(slick.position.x, slick.position.z))
				if d2 < best_d2 and is_on_port_working_side(slick.global_position):
					best_d2 = d2
					_target = slick
			if _target == null:
				wrong_side_target = true

	var drawing := Input.is_action_pressed("boat_pump") and _target != null and absf(speed) < 5.0

	# Вращение башни крана ЖЁСТКО ограничено сектором левого борта (-X):
	# -PI*0.5 — строго влево перпендикулярно борту; допустимый сектор [-2.65 .. -0.38] рад.
	# В походном положении кран сложен вдоль левого борта назад (-0.18 рад).
	if _crane_turret != null:
		var target_yaw := -0.18
		if _target != null:
			var local_t := _body.to_local(_target.global_position)
			var rel := local_t - _crane_turret.position
			var raw_yaw := atan2(rel.x, rel.z)
			# Ни при каких условиях не пускаем стрелу в +X (в сторону рубки):
			target_yaw = clampf(raw_yaw, -2.68, -0.36)
		_crane_turret.rotation.y = lerp_angle(_crane_turret.rotation.y, target_yaw, minf(1.0, delta * 5.0))

	if _crane_boom != null and _crane_jib != null:
		var boom_pitch := -0.25 if drawing else (0.05 if _target != null else 0.22)
		var jib_pitch := 0.55 if drawing else (0.35 if _target != null else 0.72)
		_crane_boom.rotation.x = lerpf(_crane_boom.rotation.x, boom_pitch, minf(1.0, delta * 5.5))
		_crane_jib.rotation.x = lerpf(_crane_jib.rotation.x, jib_pitch, minf(1.0, delta * 5.5))

	if drawing:
		_pump_progress += delta
		var tip_world := _crane_jib.to_global(Vector3(0.0, -0.12, 1.05))
		var to := _target.global_position + Vector3.UP * 0.10
		var pigment_col := ResourceSlick.COLORS[_target.kind]

		_hose_mat.albedo_color = pigment_col.darkened(0.35)
		_hose_mat.emission = pigment_col
		_hose_mat.emission_energy_multiplier = 0.65 + 0.35 * sin(_anim_time * 10.0)
		_intake_mat.albedo_color = pigment_col.darkened(0.15)
		_intake_mat.emission = pigment_col

		_hose.visible = true
		_hose.global_position = (tip_world + to) * 0.5
		var dir := (to - tip_world).normalized()
		if dir.length_squared() > 0.001:
			_hose.global_basis = Basis(Quaternion(Vector3.UP, dir))
		_hose.scale.y = tip_world.distance_to(to)

		_intake_head.visible = true
		_intake_head.global_position = to
		var pulse_s := 1.0 + 0.10 * sin(_anim_time * 8.0)
		_intake_head.scale = Vector3(pulse_s, 1.0, pulse_s)

		# Пускаем круги по воде вокруг заборной головки насоса
		if water != null and water.field != null and fmod(_pump_progress, 0.35) < delta * 1.5:
			water.field.wake(Vector2(to.x, to.z), 0.55)

		if _pump_progress >= p_secs:
			main.receive_resource(_target.kind)
			_target.collect()
			_pump_progress = 0.0
	else:
		_pump_progress = maxf(0.0, _pump_progress - delta * 2.0)
		_hose.visible = false
		_intake_head.visible = false


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

	var t_surf := water.surface_height(trailer_pos.x, trailer_pos.z)
	trailer_pos.y = lerpf(trailer_pos.y, t_surf + 0.06, minf(1.0, delta * 3.8))
	_trailer.global_position = trailer_pos

	# Качка плашкоута по 4 точкам
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

	# Двухтросовая буксирная упряжь (Bridle) от кормовых кнехтов к носу плашкоута
	var stern_l := _body.to_global(Vector3(-0.75, 0.92, 4.90))
	var stern_r := _body.to_global(Vector3( 0.75, 0.92, 4.90))
	var bow_l := _trailer_body.to_global(Vector3(-0.65, 0.58, -2.95))
	var bow_r := _trailer_body.to_global(Vector3( 0.65, 0.58, -2.95))
	_place_cable(_tow_cable_l, stern_l, bow_l)
	_place_cable(_tow_cable_r, stern_r, bow_r)

	_trailer_wake_timer -= delta
	if absf(speed) > 1.2 and _trailer_wake_timer <= 0.0:
		_trailer_wake_timer = 0.36
		var t_tail := trailer_pos - t_head * 3.1
		water.field.wake(Vector2(t_tail.x, t_tail.z), clampf(absf(speed) / 7.0, 0.2, 1.15))


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
	return ResourceSlick.NAMES[_target.kind] if _target != null else ""


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
		mat.emission_energy_multiplier = glow
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


# ---------------------------------------------------------------------------
# Сборка корпуса и надстройки по схеме реального научно-промыслового судна
# ---------------------------------------------------------------------------

func _build_appearance() -> void:
	# Профессиональная морская палитра (сдержанные, выветренные материалы):
	var anti_fouling := _material(Color("47241f"), 0.08, 0.0, 0.78) # подводный сурик
	var boot_stripe := _material(Color("12161a"), 0.15, 0.0, 0.65)  # чёрный пояс ватерлинии
	var hull_steel := _material(Color("1e272e"), 0.30, 0.0, 0.66)   # тёмный сланцевый борт
	var gunwale_steel := _material(Color("2b363e"), 0.35, 0.0, 0.60)# планширь и шпангоуты
	var timber_fender := _material(Color("4a3b2f"), 0.04, 0.0, 0.84)# дубовый привальный брус
	var deck_steel := _material(Color("262f35"), 0.25, 0.0, 0.75)   # нескользящая палубная сталь
	var deck_planks := _material(Color("57473a"), 0.05, 0.0, 0.80)  # деревянный настил рабочей палубы
	var cabin_chalk := _material(Color("c4bfb2"), 0.08, 0.0, 0.68)  # выветренная белая надстройка
	var cabin_trim := _material(Color("3a444b"), 0.32, 0.0, 0.60)   # стальные двери, комингсы и рамы
	var roof_ochre := _material(Color("8c6239"), 0.22, 0.0, 0.62)   # морская охра (крыша мостика и марка трубы)
	var machinery := _material(Color("334042"), 0.42, 0.0, 0.55)    # гидравлика, лебёдки, кран
	var dark_iron := _material(Color("161c20"), 0.55, 0.0, 0.50)    # чугун, кнехты, трубы
	var aged_bronze := _material(Color("7d6340"), 0.62, 0.0, 0.45)  # состаренная бронза
	var bridge_glass := _material(Color("121e24"), 0.35, 0.08, 0.18)# тёмное антибликовое стекло рубки
	var warm_interior := _material(Color("d69e5c"), 0.10, 0.45, 0.30)# приглушённый свет приборов

	# -----------------------------------------------------------------------
	# 1. СТАЛЬНОЙ ВОДОИЗМЕЩАЮЩИЙ КОРПУС (4 секции от форштевня до транца)
	# -----------------------------------------------------------------------
	# Секция A: Острый носовой вход (Z: -5.5 .. -3.2)
	_loft_segment(_body, -5.05, -5.25, -3.2, -3.2, -0.45, 0.08, 0.06, 0.12, 1.55, 1.95, anti_fouling)
	_loft_segment(_body, -5.25, -5.32, -3.2, -3.2,  0.08, 0.24, 0.12, 0.16, 1.95, 2.15, boot_stripe)
	_loft_segment(_body, -5.32, -5.65, -3.2, -3.2,  0.24, 0.92, 0.16, 0.28, 2.15, 2.68, hull_steel)

	# Секция B: Носовая скула (Z: -3.2 .. -1.2)
	_loft_segment(_body, -3.2, -3.2, -1.2, -1.2, -0.45, 0.08, 1.55, 1.95, 2.55, 2.95, anti_fouling)
	_loft_segment(_body, -3.2, -3.2, -1.2, -1.2,  0.08, 0.24, 1.95, 2.15, 2.95, 3.08, boot_stripe)
	_loft_segment(_body, -3.2, -3.2, -1.2, -1.2,  0.24, 0.92, 2.15, 2.68, 3.08, 3.36, hull_steel)

	# Секция C: Цилиндрическая вставка миделя (Z: -1.2 .. +2.6)
	_loft_segment(_body, -1.2, -1.2, 2.6, 2.6, -0.45, 0.08, 2.55, 2.95, 2.50, 2.90, anti_fouling)
	_loft_segment(_body, -1.2, -1.2, 2.6, 2.6,  0.08, 0.24, 2.95, 3.08, 2.90, 3.04, boot_stripe)
	_loft_segment(_body, -1.2, -1.2, 2.6, 2.6,  0.24, 0.88, 3.08, 3.36, 3.04, 3.30, hull_steel)

	# Секция D: Кормовой подзор и рабочий транец (Z: +2.6 .. +5.0)
	_loft_segment(_body, 2.6, 2.6, 4.75, 4.90, -0.42, 0.08, 2.50, 2.90, 1.70, 2.25, anti_fouling)
	_loft_segment(_body, 2.6, 2.6, 4.90, 4.95,  0.08, 0.24, 2.90, 3.04, 2.25, 2.40, boot_stripe)
	_loft_segment(_body, 2.6, 2.6, 4.95, 5.08,  0.24, 0.88, 3.04, 3.30, 2.40, 2.68, hull_steel)

	# -----------------------------------------------------------------------
	# 2. НОСОВОЙ ПОЛУБАК (Forecastle, Z: -5.65 .. -1.8) И ЯКОРНОЕ УСТРОЙСТВО
	# -----------------------------------------------------------------------
	_loft_segment(_body, -5.65, -5.85, -3.2, -3.2, 0.92, 1.32, 0.28, 0.36, 2.68, 2.86, hull_steel)
	_loft_segment(_body, -3.2,  -3.2,  -1.8, -1.9, 0.92, 1.28, 2.68, 2.86, 3.36, 3.42, hull_steel)
	# Настил полубака
	_loft_segment(_body, -5.60, -5.60, -3.2, -3.2, 1.12, 1.18, 0.26, 0.26, 2.55, 2.55, deck_steel)
	_loft_segment(_body, -3.2,  -3.2,  -1.85,-1.85,1.12, 1.18, 2.55, 2.55, 3.18, 3.18, deck_steel)
	# Планширь носового фальшборта
	for side in [-1.0, 1.0]:
		_box_on(_body, Vector3(side * 0.82, 1.33, -4.35), Vector3(0.14, 0.06, 2.45), gunwale_steel, Vector3(0.0, -side * 0.42, 0.0))
		_box_on(_body, Vector3(side * 1.54, 1.30, -2.50), Vector3(0.14, 0.06, 1.45), gunwale_steel, Vector3(0.0, -side * 0.16, 0.0))
		# Носовые парные кнехты (Bollards) и якорные клюзы
		_box_on(_body, Vector3(side * 0.95, 1.20, -3.55), Vector3(0.36, 0.06, 0.18), dark_iron)
		_cyl_on(_body, Vector3(side * 0.86, 1.28, -3.55), 0.05, 0.05, 0.18, dark_iron)
		_cyl_on(_body, Vector3(side * 1.04, 1.28, -3.55), 0.05, 0.05, 0.18, dark_iron)
		_cyl_on(_body, Vector3(side * 0.78, 0.95, -4.45), 0.11, 0.11, 0.08, dark_iron, Vector3(0.0, -side * 0.42, PI * 0.5))

	# Якорный брашпиль (лебёдка) в ДП на полубаке
	_box_on(_body, Vector3(0.0, 1.28, -4.05), Vector3(0.52, 0.24, 0.38), machinery)
	_cyl_on(_body, Vector3(0.0, 1.32, -4.05), 0.14, 0.14, 0.78, dark_iron, Vector3(0.0, 0.0, PI * 0.5), 12)
	_cyl_on(_body, Vector3(-0.34, 1.32, -4.05), 0.18, 0.16, 0.12, aged_bronze, Vector3(0.0, 0.0, PI * 0.5), 12)
	_cyl_on(_body, Vector3( 0.34, 1.32, -4.05), 0.18, 0.16, 0.12, aged_bronze, Vector3(0.0, 0.0, PI * 0.5), 12)

	# -----------------------------------------------------------------------
	# 3. РАБОЧАЯ ПАЛУБА, ФАЛЬШБОРТ СО ШПИГАТАМИ И ПРИВАЛЬНЫЙ БРУС (Z: -1.8 .. +5.0)
	# -----------------------------------------------------------------------
	_box_on(_body, Vector3(0.0, 0.88, 1.55), Vector3(3.12, 0.06, 6.75), deck_steel)
	# Деревянный рабочий настил на кормовой палубе с продольными швами
	for i in range(7):
		var px := -1.20 + float(i) * 0.40
		_box_on(_body, Vector3(px, 0.915, 2.35), Vector3(0.36, 0.025, 4.85), deck_planks)

	# Бортовые фальшборты из секций (оставляем просветы внизу — шпигаты для слива воды)
	for side in [-1.0, 1.0]:
		for seg_z in [-0.85, 0.75, 2.35, 3.85]:
			_box_on(_body, Vector3(side * 1.60, 1.08, seg_z), Vector3(0.08, 0.28, 1.32), hull_steel)
		# Непрерывный верхний планширь и наружный дубовый привальный брус
		_box_on(_body, Vector3(side * 1.61, 1.23, 1.55), Vector3(0.14, 0.05, 6.75), gunwale_steel)
		_box_on(_body, Vector3(side * 1.68, 0.78, 1.15), Vector3(0.12, 0.14, 6.95), timber_fender)
		# Внутренние батенсы (шпангоуты фальшборта)
		for frame_z in [-1.4, -0.3, 0.8, 1.9, 3.0, 4.1]:
			_box_on(_body, Vector3(side * 1.54, 1.04, frame_z), Vector3(0.08, 0.32, 0.06), gunwale_steel)
		# Кормовые буксирные кнехты
		_box_on(_body, Vector3(side * 1.15, 0.93, 4.78), Vector3(0.32, 0.05, 0.18), dark_iron)
		_cyl_on(_body, Vector3(side * 1.07, 1.00, 4.78), 0.045, 0.045, 0.16, dark_iron)
		_cyl_on(_body, Vector3(side * 1.23, 1.00, 4.78), 0.045, 0.045, 0.16, dark_iron)

	# Кормовой транец с буксирным роульсом по центру
	_box_on(_body, Vector3(-0.88, 1.06, 4.98), Vector3(0.82, 0.32, 0.10), hull_steel)
	_box_on(_body, Vector3( 0.88, 1.06, 4.98), Vector3(0.82, 0.32, 0.10), hull_steel)
	_cyl_on(_body, Vector3( 0.00, 0.96, 5.00), 0.09, 0.09, 0.78, aged_bronze, Vector3(0.0, 0.0, PI * 0.5), 12)

	# -----------------------------------------------------------------------
	# 4. НАДСТРОЙКА И ХОДОВОЙ МОСТИК (смещены в нос, Z: -2.45 .. +0.35)
	# -----------------------------------------------------------------------
	# Стальной комингс (цоколь) рубки
	_box_on(_body, Vector3(0.0, 0.98, -1.05), Vector3(2.38, 0.16, 2.82), cabin_trim)
	# 1-й ярус: Жилая надстройка и «мокрая» лаборатория
	_loft_segment(_body, -2.42, -2.35, 0.32, 0.32, 1.06, 1.98, 2.32, 2.26, 2.32, 2.26, cabin_chalk)
	# Водонепроницаемая стальная дверь на кормовой переборке рубки + трап на мостик
	_box_on(_body, Vector3(-0.45, 1.48, 0.33), Vector3(0.56, 0.82, 0.06), cabin_trim)
	_box_on(_body, Vector3(-0.45, 1.62, 0.36), Vector3(0.28, 0.24, 0.04), bridge_glass)
	# Боковые иллюминаторы и спасательные круги на 1-м ярусе
	for side in [-1.0, 1.0]:
		for wz in [-1.65, -0.85]:
			_box_on(_body, Vector3(side * 1.15, 1.56, wz), Vector3(0.06, 0.34, 0.46), cabin_trim)
			_box_on(_body, Vector3(side * 1.17, 1.56, wz), Vector3(0.04, 0.24, 0.36), bridge_glass)
		_cyl_on(_body, Vector3(side * 1.17, 1.46, -0.10), 0.22, 0.22, 0.06, _material(Color("b84b39"), 0.05, 0.0, 0.7), Vector3(0.0, 0.0, PI * 0.5), 14)

	# Палуба мостика с боковыми крыльями (Bridge Wings) и ветроотбойниками
	_box_on(_body, Vector3(0.0, 2.01, -1.08), Vector3(2.96, 0.07, 2.55), cabin_trim)
	for side in [-1.0, 1.0]:
		_box_on(_body, Vector3(side * 1.42, 2.22, -1.08), Vector3(0.06, 0.38, 1.85), cabin_chalk)
		# Кожухи бортовых навигационных огней (красный — левый борт, зелёный — правый)
		var nav_col := Color("d93829") if side < 0.0 else Color("29b856")
		_box_on(_body, Vector3(side * 1.44, 2.32, -1.72), Vector3(0.12, 0.16, 0.34), cabin_trim)
		_cyl_on(_body, Vector3(side * 1.46, 2.32, -1.72), 0.05, 0.05, 0.12, _material(nav_col, 0.1, 1.8, 0.2))

	# 2-й ярус: Рулевая рубка (Wheelhouse) с наклоном лобовых окон вперёд
	_loft_segment(_body, -2.18, -2.42, -0.32, -0.28, 2.04, 2.82, 1.98, 2.12, 2.06, 1.98, cabin_chalk)
	# Внутреннее свечение штурманского стола
	_box_on(_body, Vector3(0.0, 2.36, -1.45), Vector3(1.55, 0.32, 1.15), warm_interior)
	# Лобовое антибликовое остекление с переплётами (4 стойки)
	_loft_segment(_body, -2.20, -2.40, -2.14, -2.34, 2.26, 2.72, 1.84, 1.96, 1.84, 1.96, bridge_glass)
	for mx in [-0.58, 0.0, 0.58]:
		_box_on(_body, Vector3(mx, 2.49, -2.31), Vector3(0.05, 0.50, 0.08), cabin_trim, Vector3(-0.38, 0.0, 0.0))
	# Боковые и кормовые обзорные окна мостика (чтобы штурман видел левый борт и кран!)
	for side in [-1.0, 1.0]:
		_box_on(_body, Vector3(side * 1.02, 2.48, -1.32), Vector3(0.06, 0.44, 1.52), bridge_glass)
		_box_on(_body, Vector3(side * 1.03, 2.48, -1.32), Vector3(0.07, 0.48, 0.06), cabin_trim)
	_box_on(_body, Vector3(-0.48, 2.48, -0.29), Vector3(0.72, 0.42, 0.06), bridge_glass)

	# Крыша ходового мостика с солнцезащитным козырьком
	_loft_segment(_body, -2.62, -2.52, -0.18, -0.22, 2.82, 2.94, 2.28, 2.14, 2.16, 2.04, roof_ochre)

	# Поисковый прожектор, радар и А-образная сигнальная мачта на крыше рубки
	_cyl_on(_body, Vector3(0.0, 3.08, -2.28), 0.11, 0.13, 0.26, dark_iron, Vector3(PI * 0.5 - 0.28, 0.0, 0.0), 12)
	_cyl_on(_body, Vector3(0.0, 3.12, -2.38), 0.09, 0.09, 0.06, _material(Color("ffdf9e"), 0.1, 2.0, 0.2), Vector3(PI * 0.5 - 0.28, 0.0, 0.0), 12)
	var spot := SpotLight3D.new()
	spot.light_color = Color("ffe8ba")
	spot.light_energy = 2.0
	spot.spot_range = 24.0
	spot.spot_angle = 30.0
	spot.position = Vector3(0.0, 3.12, -2.45)
	spot.rotation = Vector3(-0.34, 0.0, 0.0)
	_body.add_child(spot)

	# Тумба радара
	_cyl_on(_body, Vector3(0.0, 3.12, -1.35), 0.10, 0.14, 0.36, cabin_chalk)
	_radar = Node3D.new()
	_radar.position = Vector3(0.0, 3.32, -1.35)
	_body.add_child(_radar)
	_box_on(_radar, Vector3(0.0, 0.04, 0.0), Vector3(1.08, 0.10, 0.18), cabin_chalk)

	# Сигнальная мачта с реей позади мостика
	for side in [-1.0, 1.0]:
		_cyl_on(_body, Vector3(side * 0.36, 3.68, -0.52), 0.03, 0.05, 1.62, dark_iron, Vector3(0.12, 0.0, side * 0.20), 8)
	_cyl_on(_body, Vector3(0.0, 3.92, -0.60), 0.025, 0.025, 1.45, dark_iron, Vector3(0.0, 0.0, PI * 0.5), 8)
	_cyl_on(_body, Vector3(0.0, 4.46, -0.62), 0.06, 0.06, 0.14, _material(Color("ffcf87"), 0.1, 1.8, 0.2))

	# -----------------------------------------------------------------------
	# 5. КОЖУХ МАШИННОГО ОТДЕЛЕНИЯ И ДЫМОВАЯ ТРУБА (смещены к ПРАВОМУ борту +X)
	# -----------------------------------------------------------------------
	# Это открывает широкий рабочий проход вдоль ЛЕВОГО борта (-X)
	_box_on(_body, Vector3(0.46, 1.36, 0.95), Vector3(1.18, 0.88, 1.25), cabin_trim)
	# Наклонная трапециевидная дымовая труба
	var stack_node := Node3D.new()
	stack_node.position = Vector3(0.46, 1.80, 0.95)
	_body.add_child(stack_node)
	_loft_segment(stack_node, -0.42, -0.25, 0.42, 0.56, 0.0, 0.95, 0.68, 0.56, 0.68, 0.56, roof_ochre)
	_loft_segment(stack_node, -0.25, -0.18, 0.56, 0.62, 0.95, 1.22, 0.56, 0.52, 0.56, 0.52, dark_iron)
	# Двойные выхлопные патрубки из трубы
	_cyl_on(stack_node, Vector3(-0.12, 1.30, 0.22), 0.07, 0.07, 0.24, dark_iron, Vector3(0.18, 0.0, 0.0), 10)
	_cyl_on(stack_node, Vector3( 0.12, 1.30, 0.22), 0.07, 0.07, 0.24, dark_iron, Vector3(0.18, 0.0, 0.0), 10)

	# -----------------------------------------------------------------------
	# 6. ГИДРАВЛИЧЕСКИЙ КРАН-МАНИПУЛЯТОР И НАСОС (СТРОГО НА ЛЕВОМ БОРТУ -X)
	# -----------------------------------------------------------------------
	# Установлен на мощной тумбе у левого планширя (X = -1.22, Z = 0.95)
	_cyl_on(_body, Vector3(-1.22, 1.08, 0.95), 0.26, 0.30, 0.36, cabin_trim)
	_box_on(_body, Vector3(-0.82, 1.08, 0.95), Vector3(0.56, 0.34, 0.62), machinery) # насосная гидростанция
	_cyl_on(_body, Vector3(-0.55, 1.12, 1.55), 0.06, 0.06, 1.25, dark_iron, Vector3(PI * 0.5, 0.0, 0.0), 10) # магистраль к бакам

	_crane_turret = Node3D.new()
	_crane_turret.position = Vector3(-1.22, 1.26, 0.95)
	_crane_turret.rotation.y = -0.18
	_body.add_child(_crane_turret)
	_cyl_on(_crane_turret, Vector3(0.0, 0.26, 0.0), 0.16, 0.20, 0.52, machinery)
	_box_on(_crane_turret, Vector3(0.0, 0.56, -0.05), Vector3(0.26, 0.24, 0.34), dark_iron)

	# Главная стрела (Main Boom) и рукоять (Jib)
	_crane_boom = Node3D.new()
	_crane_boom.position = Vector3(0.0, 0.62, 0.0)
	_crane_turret.add_child(_crane_boom)
	_box_on(_crane_boom, Vector3(0.0, 0.14, 0.62), Vector3(0.14, 0.16, 1.32), machinery, Vector3(-0.20, 0.0, 0.0))
	_cyl_on(_crane_boom, Vector3(0.0, -0.02, 0.45), 0.045, 0.055, 0.78, aged_bronze, Vector3(1.15, 0.0, 0.0), 8) # гидроцилиндр

	_crane_jib = Node3D.new()
	_crane_jib.position = Vector3(0.0, 0.26, 1.18)
	_crane_boom.add_child(_crane_jib)
	_box_on(_crane_jib, Vector3(0.0, 0.0, 0.52), Vector3(0.11, 0.12, 1.10), machinery)
	_cyl_on(_crane_jib, Vector3(0.0, -0.08, 1.05), 0.10, 0.14, 0.22, dark_iron)

	# -----------------------------------------------------------------------
	# 7. КОРМОВОЙ ПРОМЫШЛЕННЫЙ МАНИФОЛЬД И 4 СТАЛЬНЫХ ТАНКА С ВОДОМЕРНЫМИ ОКНАМИ
	# -----------------------------------------------------------------------
	# Стальной поддон-коффердам на рабочей палубе (Z: 1.95 .. 4.05)
	_box_on(_body, Vector3(0.0, 0.96, 3.00), Vector3(2.26, 0.10, 2.08), cabin_trim)
	_box_on(_body, Vector3(0.0, 1.52, 3.00), Vector3(0.16, 1.05, 1.95), dark_iron) # центральный коллектор

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
		# Тёмный стальной корпус бака высокого давления + бандажные кольца
		_cyl_on(_body, Vector3(tc.x, 1.42, tc.z), 0.34, 0.34, 0.84, gunwale_steel, Vector3.ZERO, 16)
		_cyl_on(_body, Vector3(tc.x, 1.86, tc.z), 0.28, 0.35, 0.10, cabin_trim, Vector3.ZERO, 16)
		_cyl_on(_body, Vector3(tc.x, 1.22, tc.z), 0.355, 0.355, 0.05, dark_iron, Vector3.ZERO, 16)
		_cyl_on(_body, Vector3(tc.x, 1.62, tc.z), 0.355, 0.355, 0.05, dark_iron, Vector3.ZERO, 16)
		# Цветное маркировочное кольцо на крышке бака (чтобы различать 4 ресурса)
		var ring_mat := _material(ResourceSlick.COLORS[i].darkened(0.25), 0.2, 0.25, 0.5)
		_cyl_on(_body, Vector3(tc.x, 1.93, tc.z), 0.14, 0.14, 0.06, ring_mat, Vector3.ZERO, 12)

		# Узкое вертикальное смотровое окно (Sight-Glass) снаружи бака
		_box_on(_body, Vector3(tc.x + side_sign * 0.32, 1.42, tc.z), Vector3(0.06, 0.72, 0.16), dark_iron)
		var f_mat := _material(ResourceSlick.COLORS[i], 0.1, 0.75, 0.25)
		var f_bar := _box_on(_body, Vector3(tc.x + side_sign * 0.34, 1.12, tc.z), Vector3(0.05, 0.66, 0.10), f_mat)
		f_bar.scale.y = 0.12
		_vat_fills.append(f_bar)
		_vat_mats.append(f_mat)

	# -----------------------------------------------------------------------
	# 8. КОРМОВОЙ А-ОБРАЗНЫЙ ПОРТАЛ (Stern Gantry, Z: +4.45) И ВИНТОРУЛЕВАЯ ГРУППА
	# -----------------------------------------------------------------------
	for side in [-1.0, 1.0]:
		_box_on(_body, Vector3(side * 1.22, 1.68, 4.45), Vector3(0.12, 1.56, 0.16), cabin_trim, Vector3(-0.14, 0.0, side * 0.12))
	_box_on(_body, Vector3(0.0, 2.42, 4.35), Vector3(2.38, 0.14, 0.18), roof_ochre)

	# Перо руля и два гребных винта под кормовым подзором
	_rudder = Node3D.new()
	_rudder.position = Vector3(0.0, -0.12, 4.82)
	_body.add_child(_rudder)
	_box_on(_rudder, Vector3(0.0, 0.0, 0.20), Vector3(0.08, 0.54, 0.42), dark_iron)

	_prop_l = _build_propeller(Vector3(-0.65, -0.15, 4.72), aged_bronze)
	_prop_r = _build_propeller(Vector3( 0.65, -0.15, 4.72), aged_bronze)

	# Мягкий рабочий прожектор над кормовой палубой
	var deck_light := OmniLight3D.new()
	deck_light.light_color = Color("ffd296")
	deck_light.light_energy = 0.90
	deck_light.omni_range = 9.5
	deck_light.position = Vector3(0.0, 2.35, 2.40)
	_body.add_child(deck_light)

	# Армированный всасывающий шланг и заборная головка насоса
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


# ---------------------------------------------------------------------------
# Сборка буксируемого стального плашкоута (Equipment Barge Trailer)
# ---------------------------------------------------------------------------

func _build_trailer() -> void:
	_trailer = Node3D.new()
	_trailer.name = "TowedEquipmentBarge"
	_trailer.top_level = true
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

	# Прямоугольный стальной корпус плашкоута с наклонными подзорами (Rake)
	_loft_segment(_trailer_body, -2.75, -3.05, -2.0, -2.0, -0.32, 0.12, 2.20, 2.52, 2.48, 2.65, anti_fouling)
	_loft_segment(_trailer_body, -2.0,  -2.0,   2.0,  2.0, -0.32, 0.12, 2.48, 2.65, 2.48, 2.65, anti_fouling)
	_loft_segment(_trailer_body,  2.0,   2.0,   2.75, 2.95,-0.32, 0.12, 2.48, 2.65, 2.25, 2.50, anti_fouling)

	_loft_segment(_trailer_body, -3.05, -3.15, -2.0, -2.0, 0.12, 0.56, 2.52, 2.62, 2.65, 2.74, hull_steel)
	_loft_segment(_trailer_body, -2.0,  -2.0,   2.0,  2.0, 0.12, 0.56, 2.65, 2.74, 2.65, 2.74, hull_steel)
	_loft_segment(_trailer_body,  2.0,   2.0,   2.95, 3.05,0.12, 0.56, 2.65, 2.74, 2.50, 2.60, hull_steel)

	# Рабочая палуба плашкоута и комингс грузового трюма
	_box_on(_trailer_body, Vector3(0.0, 0.57, 0.0), Vector3(2.58, 0.05, 5.85), deck_steel)
	for side in [-1.0, 1.0]:
		_box_on(_trailer_body, Vector3(side * 1.32, 0.66, 0.0), Vector3(0.10, 0.16, 5.65), gunwale_steel)
		# Носовые буксирные кнехты плашкоута
		_cyl_on(_trailer_body, Vector3(side * 0.65, 0.66, -2.85), 0.05, 0.05, 0.18, dark_iron)

	# Промышленный контейнерный скид переработки в центре плашкоута
	_box_on(_trailer_body, Vector3(0.0, 0.98, -0.55), Vector3(1.92, 0.78, 2.15), gunwale_steel)
	_box_on(_trailer_body, Vector3(0.0, 1.40, -0.55), Vector3(2.02, 0.08, 2.24), roof_ochre)

	# 4 горизонтальных накопительных ресивера в кормовой части плашкоута
	_trailer_Sight_fills.clear()
	for i in range(4):
		var tx := -0.58 if (i % 2 == 0) else 0.58
		var tz := 1.15 + float(i / 2) * 0.92
		_cyl_on(_trailer_body, Vector3(tx, 0.92, tz), 0.28, 0.28, 0.72, gunwale_steel, Vector3.ZERO, 14)
		_cyl_on(_trailer_body, Vector3(tx, 1.30, tz), 0.22, 0.28, 0.08, dark_iron, Vector3.ZERO, 14)
		var s_mat := _material(ResourceSlick.COLORS[i], 0.1, 0.65, 0.3)
		var s_bar := _box_on(_trailer_body, Vector3(tx, 0.92, tz + 0.26), Vector3(0.12, 0.48, 0.06), s_mat)
		s_bar.scale.y = 0.2
		_trailer_Sight_fills.append(s_bar)

	# Кормовая стойка с белым буксирным огнём
	_cyl_on(_trailer_body, Vector3(0.0, 1.25, 2.65), 0.03, 0.04, 1.35, dark_iron)
	_cyl_on(_trailer_body, Vector3(0.0, 1.96, 2.65), 0.07, 0.07, 0.14, _material(Color("ffdfa0"), 0.1, 1.8, 0.2))

	# Двухтросовая стальная буксирная упряжь (Bridle)
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
