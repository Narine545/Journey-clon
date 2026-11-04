class_name ResourceSlick
extends MeshInstance3D
## Отдельный SDF-материал на каждый цветной метабол.

const SHADER := preload("res://shaders/resource_slick.gdshader")
# Квад не повторяет волну в каждой вершине: запас над водой не даёт её
# гребням скрывать края пятна при движении камеры и усиленной зыби.
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


func setup(water: WaterSurface, at: Vector2, resource_kind: int, variation: float) -> void:
	_water = water
	kind = resource_kind % COLORS.size()
	position = Vector3(at.x, water.surface_height(at.x, at.y) + FLOAT_HEIGHT, at.y)
	var plane := PlaneMesh.new()
	plane.size = Vector2(5.6, 5.6)
	mesh = plane
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_mat.set_shader_parameter("pigment", COLORS[kind])
	_mat.set_shader_parameter("seed", variation)
	material_override = _mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sorting_offset = 100.0 # поверх прозрачной воды, без вмешательства в шейдер моря


func _process(delta: float) -> void:
	_age += delta
	if depleted:
		_respawn -= delta
		if _respawn <= 0.0:
			depleted = false
			visible = true
		return
	if _water != null:
		# Поле волн работает на CPU и GPU — пятно следует той же поверхности.
		position.y = _water.surface_height(position.x, position.z) + FLOAT_HEIGHT
	if _mat != null:
		_mat.set_shader_parameter("pulse", 0.5 + 0.5 * sin(_age * 2.2))


func collect() -> void:
	if depleted:
		return
	depleted = true
	visible = false
	_respawn = 35.0
	if _water != null and _water.field != null:
		_water.field.splash(Vector2(position.x, position.z), 1.2)
