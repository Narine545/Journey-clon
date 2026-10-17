class_name WaterSurface
extends MeshInstance3D
## Море: меш + материал + поле колец, в одном узле.
##
## Поверхность плоская (уровень воды), «дыхание» и кольца считаются
## аналитически — и в шейдере, и в CPU-зеркале WaterField, поэтому поплавок
## качается ровно на той воде, которую рисует глаз.
##
## Сетка НЕОДНОРОДНАЯ: у берега ячейка ~1.2 м (волны «дыхания» ~9 м читаются
## гладко), дальше шаг геометрически растёт до километров — море уходит за
## горизонт, оставаясь дешёвым.
##
## Урез: шейдер получает карту берега (shore_lut) и сам гасит волну,
## растворяет альфу и добавляет пену — жёсткой линии пересечения нет.

const SHADER_PATH := "res://shaders/water.gdshader"

const DENSE_SPAN := 620.0 # однородная зона вокруг берега, м
const DENSE_CELL := 1.25 # ячейка в ней, м
const FAR_LIMIT := 3600.0 # докуда доходит море
const FAR_GROWTH := 1.16 # рост шага вдали

var field: WaterField
var level_y := 0.0
var mesh_size := 240.0

var game: GameState # автозагрузка Game (ветер — общий с песком)
var _mat: ShaderMaterial


func setup(game_ref, center: Vector2, p_level_y: float) -> void:
	game = game_ref
	level_y = p_level_y
	position = Vector3(center.x, level_y, center.y)

	_build_mesh()

	_mat = ShaderMaterial.new()
	_mat.shader = load(SHADER_PATH)
	if game != null:
		_mat.set_shader_parameter("sun_dir", game.sun_dir)
		_mat.set_shader_parameter("fog_distance", game.FOG_DISTANCE)
	# уклон пляжа нужен шейдеру, чтобы переводить высоту наката в сдвиг кромки
	_mat.set_shader_parameter("beach_slope", Coast.BEACH_SLOPE)
	material_override = _mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# море прозрачное (мягкий урез), но по-прежнему рисуется ПЕРВЫМ:
	# SDF-квад существ читает u_screen с уже нарисованной водой (по ней
	# считается «вуаль» подводных китов) и рисуется поверх (у него 4096).
	# transparency = 0 выключает сортировку по глубине — порядок задаёт
	# sorting_offset, иначе море уплывало за SDF-слой.
	transparency = 0.0
	sorting_offset = -4096.0

	field = WaterField.new()
	field.name = "WaterField"
	add_child(field)
	field.mat = _mat
	field._push_uniforms() # сразу нулевые кольца, чтобы шейдер не ждал 1/30 с


## Высота поверхности моря в мировой точке (уровень + дыхание + кольца).
func surface_height(x: float, z: float) -> float:
	if field == null:
		return level_y
	return level_y + field.height_at(x, z)


func material() -> ShaderMaterial:
	return _mat


func set_param(param: String, value) -> void:
	if _mat != null:
		_mat.set_shader_parameter(param, value)


## Карта уреза из Coast: море знает, где песок, и плавно гаснет у кромки.
func set_shore(lut: Texture2D, z0: float, z1: float) -> void:
	set_param("shore_lut", lut)
	set_param("shore_z0", z0)
	set_param("shore_z1", z1)


func apply_sun(dir: Vector3) -> void:
	set_param("sun_dir", dir)


## Палитра моря: день — бирюза/индиго, ночь — почти чёрная глубина.
## Песок сюда НЕ подмешивается: у суши и воды разные материалы.
const DAY_SHALLOW := Color(0.16, 0.46, 0.44)
const DAY_MID := Color(0.045, 0.24, 0.33)
const DAY_DEEP := Color(0.012, 0.070, 0.140)
const DAY_FOAM := Color(0.95, 0.92, 0.86)
const NIGHT_SHALLOW := Color(0.028, 0.085, 0.095)
const NIGHT_MID := Color(0.008, 0.032, 0.050)
const NIGHT_DEEP := Color(0.002, 0.008, 0.018)
const NIGHT_FOAM := Color(0.28, 0.34, 0.40)


func apply_night01(v: float) -> void:
	set_param("water_shallow", DAY_SHALLOW.lerp(NIGHT_SHALLOW, v))
	set_param("water_mid", DAY_MID.lerp(NIGHT_MID, v))
	set_param("water_deep", DAY_DEEP.lerp(NIGHT_DEEP, v))
	set_param("foam_col", DAY_FOAM.lerp(NIGHT_FOAM, v))
	set_param("horizon_col", Coast.DAY_HORIZON.lerp(Coast.NIGHT_HORIZON, v))
	set_param("sky_col", Coast.DAY_SKY.lerp(Coast.NIGHT_SKY, v))
	set_param("fog_distance", lerpf(340.0, 130.0, v))
	set_param("glitter_amount", lerpf(0.16, 0.05, v))


func _process(_delta: float) -> void:
	if game == null or _mat == null:
		return
	# один ветер на всю игру — как у песка (рябь и дыхание бегут вместе)
	_mat.set_shader_parameter("wind_dir", game.wind_dir())
	_mat.set_shader_parameter("wind_power", game.wind_strength)
	if field != null:
		field.wind_dir = game.wind_dir()
		field.wind_power = game.wind_strength
		var ma: Variant = _mat.get_shader_parameter("mega_amp")
		if ma != null:
			field.mega_amp = ma # если амплитуду тюнили вручную


# ---------------------------------------------------------------------------
# Неоднородная сетка: плотно у берега, редко вдали
# ---------------------------------------------------------------------------

## Координаты оси: однородный центр + геометрически растущие хвосты.
func _axis() -> PackedFloat32Array:
	var half := DENSE_SPAN * 0.5
	var n := int(round(DENSE_SPAN / DENSE_CELL))
	var step := DENSE_SPAN / float(n)
	var tail := PackedFloat32Array()
	var x := half
	var s := step
	while x < FAR_LIMIT:
		s *= FAR_GROWTH
		x += s
		tail.append(x)
	var head := PackedFloat32Array()
	x = -half
	s = step
	while x > -FAR_LIMIT:
		s *= FAR_GROWTH
		x -= s
		head.append(x)

	var out := PackedFloat32Array()
	out.resize(head.size() + n + 1 + tail.size())
	var k := 0
	for i in range(head.size() - 1, -1, -1):
		out[k] = head[i]
		k += 1
	for i in range(n + 1):
		out[k] = -half + float(i) * step
		k += 1
	for i in range(tail.size()):
		out[k] = tail[i]
		k += 1
	return out


func _build_mesh() -> void:
	var xs := _axis()
	var zs := _axis()
	var nx := xs.size()
	var nz := zs.size()
	var count := nx * nz

	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	verts.resize(count)
	normals.resize(count)
	uvs.resize(count)
	for iz in range(nz):
		var lz := zs[iz]
		for ix in range(nx):
			var i := iz * nx + ix
			var lx := xs[ix]
			verts[i] = Vector3(lx, 0.0, lz)
			normals[i] = Vector3.UP
			uvs[i] = Vector2(lx, lz) * 0.01

	# Winding — тот же, что у берега (FACE_Y), иначе грань вывернута.
	var idx := PackedInt32Array()
	idx.resize((nx - 1) * (nz - 1) * 6)
	var w := 0
	for iz in range(nz - 1):
		for ix in range(nx - 1):
			var a := iz * nx + ix
			var b := a + 1
			var c := a + nx
			var d := c + 1
			idx[w] = d
			idx[w + 1] = c
			idx[w + 2] = b
			idx[w + 3] = c
			idx[w + 4] = a
			idx[w + 5] = b
			w += 6

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idx

	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh = m
