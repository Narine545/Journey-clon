class_name BoatVessel
extends Node3D
## Многокорпусная «Приливная лаборатория» (три каюты, боковые гидро-понтоны,
## поворотный кран-сифон, живые колбы ресурсов и буксируемый прицеп-оранжерея).

const MAX_SPEED := 10.0
const REVERSE_SPEED := 4.0
const ACCELERATION := 3.2
const DRAG := 1.8
const TURN_RATE := 0.95
const PUMP_RANGE := 6.0
const PUMP_SECONDS := 1.4

# Поставь true, если хочешь, чтобы прицеп был прицеплен сразу со старта:
const START_WITH_TRAILER := false
const TRAILER_DISTANCE := 8.2

var main: BoatMain
var water: WaterSurface
var coast: Coast
var speed := 0.0
var has_trailer := false

var _wake_timer := 0.0
var _trailer_wake_timer := 0.0
var _pump_progress := 0.0
var _anim_time := 0.0
var _steer_visual := 0.0
var _refine_flash := 0.0

var _target: ResourceSlick
var _body: Node3D
var _radar: Node3D
var _rudder: Node3D
var _prop_l: Node3D
var _prop_r: Node3D
var _crane_turret: Node3D
var _crane_boom: Node3D
var _hose: MeshInstance3D
var _hose_mat: StandardMaterial3D
var _intake_ring: MeshInstance3D
var _intake_mat: StandardMaterial3D
var _vat_fills: Array[MeshInstance3D] = []
var _vat_mats: Array[StandardMaterial3D] = []

var _trailer: Node3D
var _trailer_body: Node3D
var _tow_cable: MeshInstance3D
var _trailer_tanks: Array[MeshInstance3D] = []


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
	return MAX_SPEED + (2.2 if has_trailer else 0.0)


func effective_pump_range() -> float:
	return PUMP_RANGE + (3.0 if has_trailer else 0.0)


func effective_pump_seconds() -> float:
	return PUMP_SECONDS * (0.68 if has_trailer else 1.0)


func set_trailer_enabled(enabled: bool) -> void:
	has_trailer = enabled
	if _trailer != null:
		_trailer.visible = enabled
		var heading := -global_transform.basis.z
		_trailer.global_position = global_position - heading * TRAILER_DISTANCE
		_trailer.global_rotation = Vector3(0.0, rotation.y, 0.0)
	if _tow_cable != null:
		_tow_cable.visible = enabled
	if enabled and water != null and water.field != null:
		water.field.splash(Vector2(_trailer.global_position.x, _trailer.global_position.z), 1.5)


func trigger_refine_effect() -> void:
	_refine_flash = 1.0


func _physics_process(delta: float) -> void:
	if water == null or coast == null:
		return
	_anim_time += delta
	_refine_flash = maxf(0.0, _refine_flash - delta * 1.8)

	var throttle := Input.get_axis("boat_reverse", "boat_forward")
	var steer := Input.get_axis("boat_left", "boat_right")
	_steer_visual = lerpf(_steer_visual, steer, minf(1.0, delta * 6.0))

	var max_spd := effective_max_speed()
	var target_speed := throttle * (max_spd if throttle >= 0.0 else REVERSE_SPEED)
	speed = move_toward(speed, target_speed, (ACCELERATION if absf(throttle) > 0.01 else DRAG) * delta)
	rotation.y += steer * TURN_RATE * delta * clampf(absf(speed) / 3.5, 0.0, 1.0) * (1.0 if speed >= 0.0 else -1.0)

	var heading := -global_transform.basis.z
	var next := global_position + heading * speed * delta
	if coast.water_depth(next.x, next.z) > 1.7:
		global_position = next
	else:
		speed = minf(speed, 0.0)

	# Поднимаем ватерлинию так, чтобы корпус уверенно сидел НАД водой
	var surface := water.surface_height(global_position.x, global_position.z)
	global_position.y = lerpf(global_position.y, surface + 0.16, minf(1.0, delta * 3.5))

	var bow := global_position + heading * 4.2
	var stern := global_position - heading * 4.2
	var right := global_transform.basis.x
	var port := global_position - right * 2.1
	var starboard := global_position + right * 2.1
	var pitch := atan2(water.surface_height(bow.x, bow.z) - water.surface_height(stern.x, stern.z), 8.4)
	var roll := atan2(water.surface_height(starboard.x, starboard.z) - water.surface_height(port.x, port.z), 4.2)
	_body.rotation.x = lerpf(_body.rotation.x, pitch, minf(1.0, delta * 3.2))
	_body.rotation.z = lerpf(_body.rotation.z, roll - steer * absf(speed) * 0.005, minf(1.0, delta * 3.2))

	_wake_timer -= delta
	if absf(speed) > 1.2 and _wake_timer <= 0.0:
		_wake_timer = 0.30
		var tail := global_position - heading * 4.6
		water.field.wake(Vector2(tail.x, tail.z), clampf(absf(speed) / 6.0, 0.25, 1.6))

	_update_animations(delta)
	_update_pump(delta)
	_update_trailer(delta)


func _update_animations(delta: float) -> void:
	if _radar != null:
		_radar.rotation.y += delta * 1.8
	if _rudder != null:
		_rudder.rotation.y = -_steer_visual * 0.45
	var prop_spin := (speed * 2.6 + (0.6 if absf(speed) < 0.2 else 0.0)) * delta
	if _prop_l != null:
		_prop_l.rotation.z += prop_spin
	if _prop_r != null:
		_prop_r.rotation.z -= prop_spin

	# Обновляем заполнение 4 лабораторных колб на корме в зависимости от ресурсов
	if main != null and _vat_fills.size() == 4:
		for i in range(4):
			var amount := float(main.raw[i]) * 0.22 + float(main.refined[i]) * 0.35
			var fill := clampf(0.12 + amount, 0.12, 1.0)
			var mesh_node := _vat_fills[i]
			mesh_node.scale.y = lerpf(mesh_node.scale.y, fill, minf(1.0, delta * 5.0))
			mesh_node.position.y = 1.10 + mesh_node.scale.y * 0.38
			var mat := _vat_mats[i]
			mat.emission_energy_multiplier = 0.55 + fill * 1.35 + _refine_flash * 2.0
			if has_trailer and i < _trailer_tanks.size():
				var t_fill := clampf(0.2 + float(main.refined[i]) * 0.25, 0.2, 1.0)
				_trailer_tanks[i].scale = Vector3.ONE * lerpf(_trailer_tanks[i].scale.x, 0.75 + t_fill * 0.30, delta * 4.0)


func _update_pump(delta: float) -> void:
	var p_range := effective_pump_range()
	var p_secs := effective_pump_seconds()
	_target = main.nearest_resource(global_position, p_range)

	# Поворот кран-балки к ближайшему пятну
	if _crane_turret != null:
		if _target != null:
			var local_t := _body.to_local(_target.global_position)
			var desired_yaw := atan2(local_t.x - _crane_turret.position.x, local_t.z - _crane_turret.position.z)
			_crane_turret.rotation.y = lerp_angle(_crane_turret.rotation.y, desired_yaw, minf(1.0, delta * 5.0))
		else:
			_crane_turret.rotation.y = lerp_angle(_crane_turret.rotation.y, -0.35, minf(1.0, delta * 2.5))

	var drawing := Input.is_action_pressed("boat_pump") and _target != null and absf(speed) < 5.0
	if _crane_boom != null:
		var target_pitch := -0.32 if drawing else 0.12
		_crane_boom.rotation.x = lerpf(_crane_boom.rotation.x, target_pitch, minf(1.0, delta * 6.0))

	if drawing:
		_pump_progress += delta
		var tip_world := _crane_boom.to_global(Vector3(0.0, -0.10, 1.85))
		var to := _target.global_position + Vector3.UP * 0.14
		var pigment_col := ResourceSlick.COLORS[_target.kind]
		_hose_mat.albedo_color = pigment_col.lightened(0.25)
		_hose_mat.emission = pigment_col
		_hose_mat.emission_energy_multiplier = 1.4 + 0.6 * sin(_anim_time * 12.0)
		_intake_mat.albedo_color = pigment_col
		_intake_mat.emission = pigment_col

		_hose.visible = true
		_hose.global_position = (tip_world + to) * 0.5
		var dir := (to - tip_world).normalized()
		if dir.length_squared() > 0.001:
			_hose.global_basis = Basis(Quaternion(Vector3.UP, dir))
		_hose.scale.y = tip_world.distance_to(to)

		_intake_ring.visible = true
		_intake_ring.global_position = to
		var pulse_s := 1.0 + 0.18 * sin(_anim_time * 9.0)
		_intake_ring.scale = Vector3(pulse_s, 1.0, pulse_s)

		if _pump_progress >= p_secs:
			main.receive_resource(_target.kind)
			_target.collect()
			_pump_progress = 0.0
	else:
		_pump_progress = maxf(0.0, _pump_progress - delta * 2.0)
		_hose.visible = false
		_intake_ring.visible = false


func _update_trailer(delta: float) -> void:
	if not has_trailer or _trailer == null or water == null:
		return
	var stern_hitch := _body.to_global(Vector3(0.0, 0.72, 4.75))
	var trailer_pos := _trailer.global_position
	var to_hitch := stern_hitch - trailer_pos
	to_hitch.y = 0.0
	var dist := to_hitch.length()
	if dist > 0.001:
		var dir := to_hitch / dist
		var target_yaw := atan2(-dir.x, -dir.z)
		_trailer.rotation.y = lerp_angle(_trailer.rotation.y, target_yaw, minf(1.0, delta * 4.5))
		var pull_dist := 5.15 # расстояние от центра прицепа до кормового фаркопа
		if dist > pull_dist:
			var desired_xz := Vector2(stern_hitch.x, stern_hitch.z) - Vector2(dir.x, dir.z) * pull_dist
			var next_xz := Vector2(trailer_pos.x, trailer_pos.z).lerp(desired_xz, minf(1.0, delta * 8.0))
			if coast == null or coast.water_depth(next_xz.x, next_xz.y) > 1.2:
				trailer_pos.x = next_xz.x
				trailer_pos.z = next_xz.y

	var t_surf := water.surface_height(trailer_pos.x, trailer_pos.z)
	trailer_pos.y = lerpf(trailer_pos.y, t_surf + 0.14, minf(1.0, delta * 3.5))
	_trailer.global_position = trailer_pos

	# Собственная качка прицепа по 4 точкам на воде
	var t_head := -_trailer.global_transform.basis.z
	var t_right := _trailer.global_transform.basis.x
	var t_bow := trailer_pos + t_head * 2.6
	var t_stern := trailer_pos - t_head * 2.6
	var t_port := trailer_pos - t_right * 1.5
	var t_star := trailer_pos + t_right * 1.5
	var t_pitch := atan2(water.surface_height(t_bow.x, t_bow.z) - water.surface_height(t_stern.x, t_stern.z), 5.2)
	var t_roll := atan2(water.surface_height(t_star.x, t_star.z) - water.surface_height(t_port.x, t_port.z), 3.0)
	_trailer_body.rotation.x = lerpf(_trailer_body.rotation.x, t_pitch, minf(1.0, delta * 3.2))
	_trailer_body.rotation.z = lerpf(_trailer_body.rotation.z, t_roll, minf(1.0, delta * 3.2))

	# Обновляем буксировочный кабель между кормой лодки и носом прицепа
	var bow_hitch := _trailer_body.to_global(Vector3(0.0, 0.65, -2.85))
	_tow_cable.global_position = (stern_hitch + bow_hitch) * 0.5
	var cable_vec := bow_hitch - stern_hitch
	if cable_vec.length_squared() > 0.001:
		_tow_cable.global_basis = Basis(Quaternion(Vector3.UP, cable_vec.normalized()))
	_tow_cable.scale.y = cable_vec.length()

	_trailer_wake_timer -= delta
	if absf(speed) > 1.4 and _trailer_wake_timer <= 0.0:
		_trailer_wake_timer = 0.42
		var t_tail := trailer_pos - t_head * 2.9
		water.field.wake(Vector2(t_tail.x, t_tail.z), clampf(absf(speed) / 7.5, 0.2, 1.1))


func pump_fraction() -> float:
	return clampf(_pump_progress / effective_pump_seconds(), 0.0, 1.0)


func target_name() -> String:
	return ResourceSlick.NAMES[_target.kind] if _target != null else ""


# ---------------------------------------------------------------------------
# Инструменты процедурного моделирования (с защитой от вывернутых нормалей)
# ---------------------------------------------------------------------------

func _material(color: Color, metal := 0.0, glow := 0.0, rough := 0.55) -> StandardMaterial3D:
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


func _cyl_on(parent: Node3D, at: Vector3, r_top: float, r_bot: float, h: float, mat: Material, rot := Vector3.ZERO, segs := 16) -> MeshInstance3D:
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


## Добавляет треугольник с гарантированным направлением нормали наружу (по часовой стрелке для Godot)
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


## Строит граненый сегмент (корпус с развалом бортов, наклонную рубку, скошенный нос или понтон)
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

	# Верх (палуба/крыша) и низ (днище)
	_quad_outward(st, flt, frt, brt, blt, Vector3.UP)
	_quad_outward(st, flb, blb, brb, frb, Vector3.DOWN)
	# Левый борт (-X) и правый борт (+X)
	_quad_outward(st, flb, flt, blt, blb, Vector3(-1.0, 0.15, 0.0))
	_quad_outward(st, frb, brb, brt, frt, Vector3(1.0, 0.15, 0.0))
	# Носовая грань (-Z) и кормовая грань (+Z)
	_quad_outward(st, flb, frb, frt, flt, Vector3(0.0, 0.1, -1.0))
	_quad_outward(st, blb, blt, brt, brb, Vector3(0.0, 0.1, 1.0))

	var inst := MeshInstance3D.new()
	inst.mesh = st.commit()
	inst.material_override = mat
	parent.add_child(inst)
	return inst


# ---------------------------------------------------------------------------
# Сборка визуала основного судна «Приливная лаборатория»
# ---------------------------------------------------------------------------

func _build_appearance() -> void:
	# Палитра: графитовая сталь, оксидная медь у ватерлинии, морская бирюза,
	# меловые надстройки и тёплое янтарное свечение приборов.
	var hull_dark := _material(Color("1c2f3e"), 0.42, 0.0, 0.48)
	var hull_boot := _material(Color("9e4736"), 0.25, 0.0, 0.62) # антикоррозийный пояс ватерлинии
	var hull_trim := _material(Color("2f6974"), 0.35, 0.0, 0.45)
	var deck_wood := _material(Color("8a7056"), 0.05, 0.0, 0.72)
	var deck_plank := _material(Color("634e3b"), 0.08, 0.0, 0.78)
	var cabin_wall := _material(Color("efe6d4"), 0.08, 0.0, 0.55)
	var cabin_alt := _material(Color("d6ccb8"), 0.12, 0.0, 0.58)
	var roof_teal := _material(Color("2d857e"), 0.32, 0.0, 0.42)
	var copper := _material(Color("d88c5a"), 0.72, 0.0, 0.35)
	var brass := _material(Color("e6b86a"), 0.78, 0.0, 0.30)
	var iron := _material(Color("13222c"), 0.60, 0.0, 0.45)
	var win_warm := _material(Color("ffcf86"), 0.15, 1.15, 0.20)
	var win_cyan := _material(Color("6ee2d8"), 0.20, 0.95, 0.20)
	var glass_vat := _material(Color("345c68"), 0.25, 0.15, 0.18)
	var foam_skirt := _material(Color("b8ebe6"), 0.0, 0.35, 0.85)

	# 1. ГЛАВНЫЙ КОРПУС (с развалом бортов и высоким надводным бортом)
	# Нижний пояс ватерлинии (видно у самой воды)
	_loft_segment(_body, -5.2, -5.5, -2.2, -2.2, -0.28, 0.26, 0.14, 0.28, 2.35, 2.75, hull_boot)
	_loft_segment(_body, -2.2, -2.2,  2.5,  2.5, -0.28, 0.26, 2.35, 2.75, 2.35, 2.75, hull_boot)
	_loft_segment(_body,  2.5,  2.5,  4.4,  4.6, -0.28, 0.26, 2.35, 2.75, 1.65, 2.15, hull_boot)

	# Верхний бронированный борт (Y от 0.26 до 0.88 — уверенно возвышается над водой)
	_loft_segment(_body, -5.5, -6.1, -2.2, -2.2, 0.26, 0.88, 0.28, 0.44, 2.75, 3.30, hull_dark)
	_loft_segment(_body, -2.2, -2.2,  2.5,  2.5, 0.26, 0.88, 2.75, 3.30, 2.75, 3.30, hull_dark)
	_loft_segment(_body,  2.5,  2.5,  4.6,  4.85, 0.26, 0.88, 2.75, 3.30, 2.15, 2.60, hull_dark)

	# Приподнятый носовой полубак / волнорез (Forecastle, Y: 0.88 .. 1.18)
	_loft_segment(_body, -6.1, -6.35, -2.5, -2.35, 0.88, 1.18, 0.44, 0.30, 3.30, 3.38, hull_trim)
	# Привальный брус и фальшборты вдоль палубы
	for side in [-1.0, 1.0]:
		_box_on(_body, Vector3(side * 1.66, 0.93, 0.25), Vector3(0.14, 0.18, 5.2), hull_trim)
		# Стойки леерного ограждения
		for z_pos in [-1.8, -0.6, 0.6, 1.8, 3.0, 4.1]:
			_cyl_on(_body, Vector3(side * 1.60, 1.16, z_pos), 0.025, 0.025, 0.38, copper, Vector3.ZERO, 8)
		_cyl_on(_body, Vector3(side * 1.60, 1.34, 1.15), 0.022, 0.022, 6.1, brass, Vector3(PI * 0.5, 0.0, 0.0), 8)
	# Кормовой фальшборт
	_box_on(_body, Vector3(0.0, 1.02, 4.72), Vector3(2.55, 0.28, 0.14), hull_trim)

	# Деревянный настил палубы с рейками
	_box_on(_body, Vector3(0.0, 0.89, 1.15), Vector3(3.05, 0.06, 6.7), deck_wood)
	_loft_segment(_body, -5.9, -5.9, -2.4, -2.4, 1.16, 1.21, 0.36, 0.36, 3.05, 3.05, deck_wood)
	for i in range(7):
		var z_plank := -1.8 + float(i) * 0.95
		_box_on(_body, Vector3(0.0, 0.925, z_plank), Vector3(2.95, 0.02, 0.08), deck_plank)

	# Светящаяся пенная кайма по ватерлинии (визуально связывает корпус с водой)
	_loft_segment(_body, -5.3, -5.3, 4.5, 4.5, -0.02, 0.04, 0.45, 0.45, 2.95, 2.95, foam_skirt)

	# 2. БОКОВЫЕ ГИДРО-ПОНТОНЫ (Аутригеры для устойчивости лаборатории)
	for side in [-1.0, 1.0]:
		var px := side * 2.42
		# Носовой конус, середина и корма понтона
		_loft_segment(_body, -2.3, -2.1, -1.1, -1.1, -0.18, 0.42, 0.08, 0.12, 0.58, 0.68, hull_boot)
		# Смещаем понтон по X через дочерний узел
		var pontoon := Node3D.new()
		pontoon.position = Vector3(px, 0.0, 0.4)
		_body.add_child(pontoon)
		_loft_segment(pontoon, -2.4, -2.1, -1.1, -1.1, -0.18, 0.45, 0.08, 0.10, 0.56, 0.66, hull_dark)
		_loft_segment(pontoon, -1.1, -1.1,  1.6,  1.6, -0.18, 0.45, 0.56, 0.66, 0.56, 0.66, hull_dark)
		_loft_segment(pontoon,  1.6,  1.6,  2.7,  2.5, -0.18, 0.45, 0.56, 0.66, 0.12, 0.16, hull_dark)
		_box_on(pontoon, Vector3(0.0, 0.47, 0.25), Vector3(0.52, 0.06, 3.2), roof_teal)
		_box_on(pontoon, Vector3(0.0, 0.15, 0.25), Vector3(0.70, 0.14, 2.8), hull_boot)
		# Навигационный бортовой огонь (красный слева, зеленый справа)
		var nav_col := Color("ff5349") if side < 0.0 else Color("49f282")
		_cyl_on(pontoon, Vector3(0.0, 0.58, -1.0), 0.07, 0.09, 0.16, _material(nav_col, 0.1, 2.2))

		# Арочные стальные балки-фермы от корпуса к понтонам
		for z_strut in [-0.45, 1.55]:
			_box_on(_body, Vector3(side * 1.92, 0.68, z_strut), Vector3(1.15, 0.16, 0.22), iron, Vector3(0.0, 0.0, -side * 0.22))
			_cyl_on(_body, Vector3(side * 1.92, 0.80, z_strut), 0.04, 0.04, 1.05, copper, Vector3(0.0, 0.0, PI * 0.5 - side * 0.18), 10)

	# 3. КАЮТА №1 — ДВУХЪЯРУСНАЯ НОСОВАЯ РУБКА УПРАВЛЕНИЯ (Z: -2.65 .. -0.55)
	# Нижний ярус рубки (приборный отсек)
	_loft_segment(_body, -2.65, -2.55, -0.55, -0.55, 0.90, 1.92, 2.25, 2.18, 2.40, 2.32, cabin_wall)
	_box_on(_body, Vector3(0.0, 1.94, -1.58), Vector3(2.46, 0.08, 2.24), hull_trim)
	# Верхний ярус — ходовой мостик с обратным наклоном лобового стекла (как у траулеров/ледоколов)
	_loft_segment(_body, -2.42, -2.72, -0.68, -0.62, 1.96, 2.86, 1.96, 2.12, 2.10, 1.98, cabin_wall)
	# Крыша мостика с козырьком
	_loft_segment(_body, -2.92, -2.80, -0.50, -0.55, 2.86, 3.04, 2.34, 2.16, 2.22, 2.04, roof_teal)
	# Панорамные светящиеся окна мостика
	_loft_segment(_body, -2.46, -2.70, -2.38, -2.62, 2.15, 2.72, 1.68, 1.80, 1.68, 1.80, win_warm)
	for side in [-1.0, 1.0]:
		_box_on(_body, Vector3(side * 1.03, 2.44, -1.62), Vector3(0.06, 0.50, 1.32), win_warm)
		# Иллюминаторы нижнего яруса
		_cyl_on(_body, Vector3(side * 1.15, 1.44, -1.95), 0.19, 0.19, 0.08, brass, Vector3(0.0, 0.0, PI * 0.5), 14)
		_cyl_on(_body, Vector3(side * 1.17, 1.44, -1.95), 0.13, 0.13, 0.09, win_warm, Vector3(0.0, 0.0, PI * 0.5), 14)

	# Вращающийся радар и мачта связи на крыше мостика
	_cyl_on(_body, Vector3(0.0, 3.22, -1.45), 0.12, 0.18, 0.36, iron)
	_radar = Node3D.new()
	_radar.position = Vector3(0.0, 3.45, -1.45)
	_body.add_child(_radar)
	_box_on(_radar, Vector3(0.0, 0.06, 0.0), Vector3(1.15, 0.14, 0.22), brass)
	_cyl_on(_radar, Vector3(0.0, 0.06, 0.12), 0.18, 0.05, 0.16, win_cyan, Vector3(PI * 0.5, 0.0, 0.0), 12)
	# Высокая антенна с топовым огнем
	_cyl_on(_body, Vector3(0.55, 3.65, -0.95), 0.025, 0.05, 1.35, copper)
	_cyl_on(_body, Vector3(0.55, 4.35, -0.95), 0.09, 0.09, 0.18, _material(Color("ffd685"), 0.1, 2.5))

	# 4. КАЮТА №2 — ЦЕНТРАЛЬНАЯ ГИДРОХИМИЧЕСКАЯ ЛАБОРАТОРИЯ (Z: -0.55 .. 1.95)
	_loft_segment(_body, -0.55, -0.55, 1.95, 1.95, 0.90, 2.18, 2.56, 2.42, 2.56, 2.42, cabin_alt)
	# Скошенная крыша лаборатории со светящимся бирюзовым зенитным окном (Skylight)
	_loft_segment(_body, -0.62, -0.45, 2.02, 1.85, 2.18, 2.44, 2.68, 1.95, 2.68, 1.95, roof_teal)
	_box_on(_body, Vector3(0.0, 2.46, 0.70), Vector3(1.15, 0.08, 1.65), win_cyan)
	_box_on(_body, Vector3(0.0, 2.47, 0.70), Vector3(1.25, 0.05, 0.10), brass)

	# Круглые медные иллюминаторы лаборатории (по 2 с каждого борта) + наружные трубы
	for side in [-1.0, 1.0]:
		for z_port in [0.10, 1.20]:
			_cyl_on(_body, Vector3(side * 1.26, 1.56, z_port), 0.23, 0.23, 0.09, copper, Vector3(0.0, 0.0, PI * 0.5), 16)
			_cyl_on(_body, Vector3(side * 1.28, 1.56, z_port), 0.16, 0.16, 0.10, win_cyan, Vector3(0.0, 0.0, PI * 0.5), 16)
	# Спасательный круг и медный змеевик на правом борту
	_cyl_on(_body, Vector3(1.30, 1.48, -1.15), 0.28, 0.28, 0.08, _material(Color("f07b62"), 0.1, 0.3), Vector3(0.0, 0.0, PI * 0.5), 16)
	_cyl_on(_body, Vector3(1.26, 1.55, 0.65), 0.05, 0.05, 2.2, copper, Vector3(PI * 0.5, 0.0, 0.0), 10)

	# 5. КАЮТА №3 — КОРМОВОЙ ИНЖЕНЕРНЫЙ ОТСЕК И 4 РЕАКТОРНЫЕ КОЛБЫ (Z: 1.95 .. 4.35)
	_loft_segment(_body, 1.95, 1.95, 3.05, 2.90, 0.90, 1.72, 2.20, 2.00, 2.10, 1.85, hull_dark)
	_box_on(_body, Vector3(0.0, 1.75, 2.45), Vector3(2.12, 0.08, 1.08), copper)
	# Две наклонные медные выхлопные трубы позади лаборатории
	for side in [-1.0, 1.0]:
		_cyl_on(_body, Vector3(side * 0.62, 2.35, 2.22), 0.13, 0.16, 1.35, copper, Vector3(0.18, 0.0, 0.0), 14)
		_cyl_on(_body, Vector3(side * 0.62, 2.95, 2.33), 0.16, 0.14, 0.18, iron, Vector3(0.18, 0.0, 0.0), 14)

	# 4 СТЕКЛЯННЫЕ КОЛБЫ РЕСУРСОВ НА КОРМЕ (заполняются по мере сбора Бирюзы/Коралла/Янтаря/Орхидеи)
	_vat_fills.clear()
	_vat_mats.clear()
	var vat_positions := [
		Vector3(-0.68, 0.0, 3.35),
		Vector3( 0.68, 0.0, 3.35),
		Vector3(-0.68, 0.0, 4.08),
		Vector3( 0.68, 0.0, 4.08),
	]
	for i in range(4):
		var vp: Vector3 = vat_positions[i]
		# Медный пьедестал и крышка колбы
		_cyl_on(_body, Vector3(vp.x, 0.98, vp.z), 0.28, 0.31, 0.16, brass, Vector3.ZERO, 14)
		_cyl_on(_body, Vector3(vp.x, 1.48, vp.z), 0.25, 0.25, 0.86, glass_vat, Vector3.ZERO, 14)
		_cyl_on(_body, Vector3(vp.x, 1.94, vp.z), 0.27, 0.29, 0.12, copper, Vector3.ZERO, 14)
		# Внутренний светящийся столб пигмента
		var f_mat := _material(ResourceSlick.COLORS[i], 0.1, 1.1, 0.25)
		var f_cyl := _cyl_on(_body, Vector3(vp.x, 1.18, vp.z), 0.19, 0.19, 0.76, f_mat, Vector3.ZERO, 12)
		f_cyl.scale.y = 0.15
		_vat_fills.append(f_cyl)
		_vat_mats.append(f_mat)

	# Кормовая П-образная кран-балка (портал)
	for side in [-1.0, 1.0]:
		_box_on(_body, Vector3(side * 1.18, 1.55, 4.35), Vector3(0.12, 1.35, 0.14), iron)
	_box_on(_body, Vector3(0.0, 2.22, 4.35), Vector3(2.55, 0.14, 0.16), copper)

	# 6. НОСОВОЙ БУШПРИТ С ПРИЛИВНЫМ ЗОНДОМ И ПРОЖЕКТОРОМ
	for side in [-1.0, 1.0]:
		_cyl_on(_body, Vector3(side * 0.28, 1.32, -5.85), 0.04, 0.06, 1.65, iron, Vector3(1.18, 0.0, side * 0.18), 8)
	# Светящийся кристалл-детектор над самым носом
	_cyl_on(_body, Vector3(0.0, 1.52, -6.52), 0.02, 0.14, 0.36, win_cyan, Vector3.ZERO, 8)
	_cyl_on(_body, Vector3(0.0, 1.25, -6.52), 0.14, 0.02, 0.28, win_cyan, Vector3.ZERO, 8)
	# Носовой прожектор на козырьке рубки
	_cyl_on(_body, Vector3(0.0, 3.08, -2.82), 0.14, 0.18, 0.32, brass, Vector3(PI * 0.5 - 0.35, 0.0, 0.0), 12)
	var spot := SpotLight3D.new()
	spot.light_color = Color("fff0cf")
	spot.light_energy = 2.4
	spot.spot_range = 22.0
	spot.spot_angle = 32.0
	spot.position = Vector3(0.0, 3.08, -2.95)
	spot.rotation = Vector3(-0.38, 0.0, 0.0)
	_body.add_child(spot)

	# 7. ПОВОРОТНЫЙ КРАН-СИФОН НА ЛЕВОМ БОРТУ (для откачки пятен)
	_crane_turret = Node3D.new()
	_crane_turret.position = Vector3(-1.38, 0.92, -0.15)
	_body.add_child(_crane_turret)
	_cyl_on(_crane_turret, Vector3(0.0, 0.22, 0.0), 0.24, 0.30, 0.44, copper, Vector3.ZERO, 12)
	_box_on(_crane_turret, Vector3(0.0, 0.52, 0.0), Vector3(0.32, 0.28, 0.36), iron)

	_crane_boom = Node3D.new()
	_crane_boom.position = Vector3(0.0, 0.58, 0.0)
	_crane_turret.add_child(_crane_boom)
	_box_on(_crane_boom, Vector3(0.0, 0.12, 0.92), Vector3(0.12, 0.12, 1.95), brass, Vector3(-0.15, 0.0, 0.0))
	_cyl_on(_crane_boom, Vector3(0.0, -0.02, 1.85), 0.14, 0.20, 0.28, copper)

	# 8. РУЛЬ И ДВА ВРАЩАЮЩИХСЯ ГРЕБНЫХ ВИНТА ПОД КОРМОЙ
	_rudder = Node3D.new()
	_rudder.position = Vector3(0.0, 0.05, 4.78)
	_body.add_child(_rudder)
	_box_on(_rudder, Vector3(0.0, 0.0, 0.22), Vector3(0.08, 0.58, 0.46), copper)

	_prop_l = _build_propeller(Vector3(-0.68, 0.02, 4.68), brass)
	_prop_r = _build_propeller(Vector3( 0.68, 0.02, 4.68), brass)

	# Тёплый корабельный фонарь над палубой
	var lantern := OmniLight3D.new()
	lantern.light_color = Color("ffc98b")
	lantern.light_energy = 1.15
	lantern.omni_range = 10.5
	lantern.position = Vector3(0.0, 2.85, 0.85)
	_body.add_child(lantern)

	# Шланг насоса и светящееся заборное кольцо на воде
	_hose = MeshInstance3D.new()
	var tube := CylinderMesh.new()
	tube.top_radius = 0.065
	tube.bottom_radius = 0.11
	tube.height = 1.0
	_hose.mesh = tube
	_hose_mat = _material(Color("7ee1c9"), 0.1, 1.3)
	_hose.material_override = _hose_mat
	_hose.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_hose.visible = false
	add_child(_hose)

	_intake_ring = MeshInstance3D.new()
	var ring_cyl := CylinderMesh.new()
	ring_cyl.top_radius = 0.48
	ring_cyl.bottom_radius = 0.55
	ring_cyl.height = 0.14
	_intake_ring.mesh = ring_cyl
	_intake_mat = _material(Color("7ee1c9"), 0.1, 1.8)
	_intake_ring.material_override = _intake_mat
	_intake_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_intake_ring.visible = false
	add_child(_intake_ring)


func _build_propeller(at: Vector3, mat: Material) -> Node3D:
	var hub := Node3D.new()
	hub.position = at
	_body.add_child(hub)
	_cyl_on(hub, Vector3.ZERO, 0.10, 0.10, 0.24, mat, Vector3(PI * 0.5, 0.0, 0.0), 10)
	for i in range(3):
		var a := float(i) * TAU / 3.0
		var blade := _box_on(hub, Vector3(cos(a) * 0.20, sin(a) * 0.20, 0.04), Vector3(0.26, 0.09, 0.03), mat)
		blade.rotation.z = a
	return hub


# ---------------------------------------------------------------------------
# Сборка покупаемого Прицепа («Буксируемый Био-Понтон»)
# ---------------------------------------------------------------------------

func _build_trailer() -> void:
	_trailer = Node3D.new()
	_trailer.name = "LaboratoryTrailer"
	_trailer.top_level = true
	_trailer.visible = false
	add_child(_trailer)

	_trailer_body = Node3D.new()
	_trailer.add_child(_trailer_body)

	var hull_dark := _material(Color("1c2f3e"), 0.42, 0.0, 0.48)
	var hull_boot := _material(Color("9e4736"), 0.25, 0.0, 0.62)
	var deck_wood := _material(Color("8a7056"), 0.05, 0.0, 0.72)
	var roof_teal := _material(Color("2d857e"), 0.32, 0.0, 0.42)
	var copper := _material(Color("d88c5a"), 0.72, 0.0, 0.35)
	var brass := _material(Color("e6b86a"), 0.78, 0.0, 0.30)
	var glass_dome := _material(Color("5fd4c8"), 0.20, 0.65, 0.18)

	# Двухкорпусный катамаранный понтон прицепа
	for side in [-1.0, 1.0]:
		var hull_side := Node3D.new()
		hull_side.position = Vector3(side * 1.12, 0.0, 0.0)
		_trailer_body.add_child(hull_side)
		_loft_segment(hull_side, -2.9, -3.1, -1.4, -1.4, -0.22, 0.56, 0.12, 0.20, 0.78, 0.92, hull_dark)
		_loft_segment(hull_side, -1.4, -1.4,  1.8,  1.8, -0.22, 0.56, 0.78, 0.92, 0.78, 0.92, hull_dark)
		_loft_segment(hull_side,  1.8,  1.8,  2.8,  2.9, -0.22, 0.56, 0.78, 0.92, 0.42, 0.56, hull_dark)
		_box_on(hull_side, Vector3(0.0, 0.12, 0.0), Vector3(0.95, 0.16, 4.6), hull_boot)

	# Общая грузовая палуба прицепа и медное ограждение
	_box_on(_trailer_body, Vector3(0.0, 0.60, 0.0), Vector3(3.15, 0.12, 4.85), deck_wood)
	_box_on(_trailer_body, Vector3(0.0, 0.68, -2.55), Vector3(1.65, 0.14, 0.55), copper) # носовой узел сцепки

	# Стеклянная био-оранжерея (теплица для редких образцов) в передней части прицепа
	_loft_segment(_trailer_body, -1.85, -1.45, 0.35, 0.05, 0.66, 1.78, 2.25, 1.45, 2.25, 1.45, glass_dome)
	_box_on(_trailer_body, Vector3(0.0, 1.82, -0.70), Vector3(1.52, 0.08, 1.58), roof_teal)
	# Светящиеся капсулы с орхидеями/кораллами внутри оранжереи
	for side in [-1.0, 1.0]:
		_cyl_on(_trailer_body, Vector3(side * 0.52, 1.08, -0.75), 0.24, 0.18, 0.62, _material(ResourceSlick.COLORS[3 if side > 0 else 1], 0.1, 1.4))

	# 4 сферических резервуара на корме прицепа
	_trailer_tanks.clear()
	for i in range(4):
		var tx := -0.72 if (i % 2 == 0) else 0.72
		var tz := 1.05 + float(i / 2) * 0.95
		_cyl_on(_trailer_body, Vector3(tx, 0.75, tz), 0.32, 0.36, 0.20, brass)
		var sphere := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.38
		sm.height = 0.76
		sphere.mesh = sm
		sphere.position = Vector3(tx, 1.12, tz)
		sphere.material_override = _material(ResourceSlick.COLORS[i], 0.25, 0.95, 0.25)
		_trailer_body.add_child(sphere)
		_trailer_tanks.append(sphere)

	# Кормовая мачта прицепа с тёплым фонарем
	_cyl_on(_trailer_body, Vector3(0.0, 1.45, 2.25), 0.04, 0.06, 1.65, copper)
	_cyl_on(_trailer_body, Vector3(0.0, 2.30, 2.25), 0.12, 0.12, 0.22, _material(Color("ffd188"), 0.1, 2.2))
	var t_light := OmniLight3D.new()
	t_light.light_color = Color("ffc880")
	t_light.light_energy = 0.85
	t_light.omni_range = 7.5
	t_light.position = Vector3(0.0, 2.35, 2.25)
	_trailer_body.add_child(t_light)

	# Буксировочный трос-кабель
	_tow_cable = MeshInstance3D.new()
	_tow_cable.top_level = true
	var c_mesh := CylinderMesh.new()
	c_mesh.top_radius = 0.045
	c_mesh.bottom_radius = 0.045
	c_mesh.height = 1.0
	_tow_cable.mesh = c_mesh
	_tow_cable.material_override = copper
	_tow_cable.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_tow_cable.visible = false
	add_child(_tow_cable)
