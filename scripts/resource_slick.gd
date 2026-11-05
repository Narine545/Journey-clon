class_name ResourceSlick
extends MeshInstance3D
## Отдельный SDF-материал на каждый цветной метабол.

const SHADER := preload("res://shaders/resource_slick.gdshader")
# Вершины пятна повторяют дисперсионные волны; небольшой запас оставляет
# шейдерное пятно над контактной пеной и редкими точечными всплесками.
const FLOAT_HEIGHT := 0.34
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
var _water: WaterSurface
var _age := 0.0
var _respawn := 0.0
var _fade := 1.0


func setup(water: WaterSurface, at: Vector2, resource_kind: int, variation: float) -> void:
	_water = water
	kind = resource_kind % COLORS.size()
	position = Vector3(at.x, water.surface_height(at.x, at.y) + FLOAT_HEIGHT, at.y)
	var plane := PlaneMesh.new()
	plane.size = Vector2(5.6, 5.6)
	plane.subdivide_width = 12
	plane.subdivide_depth = 12
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
	position = new_pos
	_fade = 0.0
	if _mat != null:
		_mat.set_shader_parameter("fade", 0.0)


func _process(delta: float) -> void:
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
	if _mat != null:
		_mat.set_shader_parameter("pulse", 0.5 + 0.5 * sin(_age * 2.2))
		_mat.set_shader_parameter("fade", _fade)


func collect() -> void:
	if depleted:
		return
	depleted = true
	visible = false
	_respawn = 35.0
	if _water != null and _water.field != null:
		_water.field.splash(Vector2(position.x, position.z), 1.2)


func set_parallax_enabled(enabled: bool) -> void:
	if _mat != null:
		_mat.set_shader_parameter("parallax_depth", 0.55 if enabled else 0.0)
