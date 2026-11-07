class_name ResourceSlick
extends MeshInstance3D
## Отдельный SDF-материал на каждый цветной метабол.

const SHADER := preload("res://shaders/resource_slick.gdshader")
# Вершины пятна повторяют дисперсионные волны; небольшой запас оставляет
# шейдерное пятно над контактной пеной и редкими точечными всплесками.
const FLOAT_HEIGHT := 0.34
const CHARGE_RATE := 2.0
const GLOW_HOLD_SECONDS := 5.0
const GLOW_FADE_SECONDS := 6.0
const SPLIT_HOLD_SECONDS := 1.4
const SPLIT_OPEN_RATE := 2.8
const SPLIT_CLOSE_RATE := 0.28
const COLORS: Array[Color] = [
	Color("31c2bd"), # приливная бирюза
	Color("f07b62"), # коралл
	Color("f2bc67"), # янтарь
	Color("a699ed"), # орхидея
]
const NAMES: Array[String] = ["Бирюза", "Коралл", "Янтарь", "Орхидея"]

var kind := 0
var depleted := false
var _mat: ShaderMaterial
var _glow_charge := 0.0
var _glow_hold := 0.0
var _night_factor := 0.0
var _reveal_light: SpotLight3D
var _water: WaterSurface
var _age := 0.0
var _respawn := 0.0
var _fade := 1.0
var _split_amount := 0.0
var _split_hold := 0.0
var _split_strength := 0.0
var _split_rng := RandomNumberGenerator.new()


func setup(water: WaterSurface, at: Vector2, resource_kind: int, variation: float) -> void:
	_water = water
	_split_rng.seed = int(absf(variation) * 10000.0) + resource_kind * 137 + 41
	kind = resource_kind % COLORS.size()
	position = Vector3(at.x, water.surface_height(at.x, at.y) + FLOAT_HEIGHT, at.y)
	var plane := PlaneMesh.new()
	plane.size = Vector2(8.0, 8.0)
	plane.subdivide_width = 18
	plane.subdivide_depth = 18
	mesh = plane
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_mat.set_shader_parameter("pigment", COLORS[kind])
	_mat.set_shader_parameter("seed", variation)
	_mat.set_shader_parameter("fade", 1.0)
	material_override = _mat
	_mat.render_priority = 10 # после моря, но тест глубины сохраняет окклюзию корпусом
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Вершинный шейдер поднимает край пятна за исходный плоский AABB:
	# иначе движущийся объект может исчезнуть из-за frustum culling.
	extra_cull_margin = 1.0
	sorting_offset = 100.0 # поверх прозрачной воды, без вмешательства в шейдер моря


func relocate_smoothly(new_pos: Vector3) -> void:
	_reset_afterglow()
	_reset_disturbance()
	position = new_pos
	_fade = 0.0
	if _mat != null:
		_mat.set_shader_parameter("fade", 0.0)


func _process(delta: float) -> void:
	_sync_reveal_light()
	_age += delta
	if depleted:
		_respawn -= delta
		if _respawn <= 0.0:
			depleted = false
			visible = true
			_fade = 0.0
		return
	_fade = minf(1.0, _fade + delta * 1.2)
	if _water != null:
		position.y = _water.surface_height(position.x, position.z) + FLOAT_HEIGHT
		if _water.field != null and _mat != null:
			_mat.set_shader_parameter("wave_time", _water.field.t)
			_mat.set_shader_parameter("wave_amp", _water.field.mega_amp)
			_mat.set_shader_parameter("wave_power", _water.field.wind_power)
			_mat.set_shader_parameter("wave_wind", _water.field.wind_dir)
	_update_disturbance(delta)
	_update_afterglow(delta)
	if _mat != null:
		_mat.set_shader_parameter("pulse", 0.5 + 0.5 * sin(_age * 2.2))
		_mat.set_shader_parameter("fade", _fade)


func collect() -> void:
	if depleted:
		return
	depleted = true
	_reset_afterglow()
	_reset_disturbance()
	visible = false
	_respawn = 35.0
	if _water != null and _water.field != null:
		_water.field.splash(Vector2(position.x, position.z), 1.2)


func set_parallax_enabled(enabled: bool) -> void:
	if _mat != null:
		_mat.set_shader_parameter("parallax_depth", 0.55 if enabled else 0.0)


func configure_night_visibility(light: SpotLight3D, night: float) -> void:
	_reveal_light = light
	_night_factor = night
	if _mat != null:
		_mat.set_shader_parameter("night_factor", night)
		_sync_reveal_light()


func _sync_reveal_light() -> void:
	if _mat == null:
		return
	var active := is_instance_valid(_reveal_light)
	if active:
		active = _reveal_light.is_visible_in_tree() and _reveal_light.light_energy > 0.001
	_mat.set_shader_parameter("reveal_enabled", 1.0 if active else 0.0)
	if not active:
		return
	# Маска пятен должна совпадать с отрисованным интерполированным фонарём.
	var rendered_light := _reveal_light.get_global_transform_interpolated()
	_mat.set_shader_parameter("reveal_position", rendered_light.origin)
	_mat.set_shader_parameter("reveal_direction", -rendered_light.basis.z.normalized())
	_mat.set_shader_parameter("reveal_range", maxf(_reveal_light.spot_range, 0.01))
	var angle := deg_to_rad(_reveal_light.spot_angle)
	_mat.set_shader_parameter("reveal_cos_outer", cos(angle))
	_mat.set_shader_parameter("reveal_cos_inner", cos(angle * 0.80))


func _reset_afterglow() -> void:
	_glow_charge = 0.0
	_glow_hold = 0.0
	if _mat != null:
		_mat.set_shader_parameter("afterglow", 0.0)


func _beam_exposure() -> float:
	if not is_instance_valid(_reveal_light):
		return 0.0
	if not _reveal_light.is_visible_in_tree() or _reveal_light.light_energy <= 0.001:
		return 0.0
	var direction := -_reveal_light.global_basis.z.normalized()
	var reach := maxf(_reveal_light.spot_range, 0.01)
	var angle := deg_to_rad(_reveal_light.spot_angle)
	var strength := 0.0
	# Центр и четыре точки внутри тела пятна: касание края лучом тоже
	# даёт заряд. Это маска конуса, не проверка теней препятствий.
	for offset in [Vector3.ZERO, Vector3(0.9, 0, 0), Vector3(-0.9, 0, 0),
		Vector3(0, 0, 0.9), Vector3(0, 0, -0.9)]:
		var to_point: Vector3 = global_position + offset - _reveal_light.global_position
		var distance := to_point.length()
		var cone := smoothstep(cos(angle), cos(angle * 0.80),
			to_point.dot(direction) / maxf(distance, 0.001))
		var range_fade := 1.0 - smoothstep(reach * 0.78, reach, distance)
		strength = maxf(strength, cone * range_fade)
	return strength


func _update_afterglow(delta: float) -> void:
	var exposure := _beam_exposure()
	if _night_factor <= 0.55:
		# Обычный свет поддерживает заряд днём и вечером.
		_glow_charge = 1.0
		_glow_hold = GLOW_HOLD_SECONDS
	elif exposure > 0.05:
		_glow_charge = minf(1.0, _glow_charge + delta * CHARGE_RATE * exposure)
		_glow_hold = GLOW_HOLD_SECONDS
	else:
		# Остаток delta после выдержки сразу идёт в затухание:
		# результат не зависит от того, пересёк ли кадр границу таймера.
		var fade_delta := maxf(0.0, delta - _glow_hold)
		_glow_hold = maxf(0.0, _glow_hold - delta)
		_glow_charge = move_toward(_glow_charge, 0.0, fade_delta / GLOW_FADE_SECONDS)
	if _mat != null:
		_mat.set_shader_parameter("afterglow", _glow_charge)


func react_to_sweep(from: Vector2, to: Vector2, heading: Vector2,
		half_length: float, half_width: float, delta: float) -> void:
	if depleted or _mat == null or _fade < 0.1 or delta <= 0.0:
		return
	var movement := to - from
	var distance := movement.length()
	var travel_speed := distance / delta
	# Только движение, не качка/стоянка и не телепорт через весь мир.
	if travel_speed < 0.25 or distance > maxf(1.5, delta * 30.0):
		return
	var axis := heading.normalized()
	if axis.length_squared() < 0.5:
		return
	if movement.dot(axis) < 0.0:
		axis = -axis
	var a := from - axis * half_length
	var b := to + axis * half_length
	var point := Vector2(global_position.x, global_position.z)
	var ab := b - a
	var closest := a + ab * clampf((point - a).dot(ab) / maxf(ab.length_squared(), 0.001),
		0.0, 1.0)
	var gap := point.distance_to(closest)
	var contact := 1.0 - smoothstep(half_width + 0.6, half_width + 1.8, gap)
	if contact <= 0.01:
		return
	if _split_amount < 0.08 and _split_hold <= 0.0:
		_split_strength = 0.0
		# Одна случайность на событие, а не на каждый кадр/источник.
		var lateral := Vector2(-axis.y, axis.x).rotated(_split_rng.randf_range(-0.22, 0.22))
		var local_axis := global_basis.inverse() * Vector3(lateral.x, 0.0, lateral.y)
		_mat.set_shader_parameter("split_axis", Vector2(local_axis.x, local_axis.z).normalized())
		_mat.set_shader_parameter("split_bias", _split_rng.randf_range(-0.20, 0.20))
		_mat.set_shader_parameter("split_asymmetry", _split_rng.randf_range(-0.15, 0.15))
	_split_strength = maxf(_split_strength, clampf(travel_speed / 4.0, 0.35, 1.0) * contact)
	_split_hold = SPLIT_HOLD_SECONDS


func _update_disturbance(delta: float) -> void:
	var opening_time := minf(delta, _split_hold)
	if opening_time > 0.0:
		_split_amount = move_toward(_split_amount, _split_strength, opening_time * SPLIT_OPEN_RATE)
		_split_hold -= opening_time
	var closing_time := delta - opening_time
	if closing_time > 0.0:
		_split_amount = move_toward(_split_amount, 0.0, closing_time * SPLIT_CLOSE_RATE)
	if _mat != null:
		_mat.set_shader_parameter("split_amount", _split_amount)


func _reset_disturbance() -> void:
	_split_amount = 0.0
	_split_hold = 0.0
	_split_strength = 0.0
	if _mat != null:
		_mat.set_shader_parameter("split_amount", 0.0)
