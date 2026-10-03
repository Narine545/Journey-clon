class_name Terrain
extends MeshInstance3D
## Процедурные дюны: рельеф из ridged-шума FastNoiseLite, меш строится в setup().
## Хранит сетку высот и даёт точную выборку высоты/нормали — физика «езжает»
## ровно по тем треугольникам, которые видит игрок.

const SIZE := 1040.0 # сторона мира (метры)
const SEGMENTS := 260 # разбиение (261x261 вершин, ячейка 4 м)
const CENTER := Vector2(0.0, -190.0) # центр плоскости

const SPAWN := Vector2(0.0, 40.0) # старт игрока
const PATH_END_Z := -430.0 # конец пути у стены перед маяком

const PLATEAU_R := 12.0 # радиус ровной стартовой площадки
const PLATEAU_FADE := 42.0 # дальше — полноценные дюны

var game # автозагрузка Game

var _dunes := FastNoiseLite.new()
var _detail := FastNoiseLite.new()
var _grid := PackedFloat32Array() # (SEGMENTS+1)^2 высот
var _dgrid := PackedFloat32Array() # те же узлы: дюнность 0..1 (для шейдера)

var _x0 := 0.0
var _z0 := 0.0
var _cell := 0.0
var _row := 0 # SEGMENTS+1


func setup(game_ref) -> void:
	game = game_ref
	_x0 = CENTER.x - SIZE * 0.5
	_z0 = CENTER.y - SIZE * 0.5
	_cell = SIZE / float(SEGMENTS)
	_row = SEGMENTS + 1

	_dunes.seed = 1373
	_dunes.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_dunes.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	_dunes.frequency = 1.0 / 44.0
	_dunes.fractal_octaves = 4
	_dunes.fractal_gain = 0.52
	_dunes.fractal_lacunarity = 2.05
	_dunes.domain_warp_enabled = true
	_dunes.domain_warp_type = FastNoiseLite.DOMAIN_WARP_SIMPLEX
	_dunes.domain_warp_amplitude = 16.0
	_dunes.domain_warp_frequency = 1.0 / 125.0

	_detail.seed = 991
	_detail.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_detail.frequency = 1.0 / 8.5
	_detail.fractal_octaves = 2
	_detail.fractal_gain = 0.45

	_build_grid()
	_build_mesh()


## Непрерывная функция высоты (гладкая — по ней строится рельеф).
func height_at(x: float, z: float) -> float:
	# 1) общий спуск к маяку: старт высоко, у стены — низко
	var t := clampf((-z - SPAWN.y) / 380.0, 0.0, 1.0)
	t = t * t * (3.0 - 2.0 * t) # smoothstep
	var trend := lerpf(16.0, -22.0, t)

	# 2) дюны: ridged fbm, вытянутые вдоль пути (координата z сжата)
	var d := dune_at(x, z)
	var h := d * 15.5

	# 3) мелкая вариация
	h += _detail.get_noise_2d(x, z) * 1.15

	# 4) у старта дюны гаснут — вход в игру с ровного балкона
	var ds := Vector2(x, z).distance_to(SPAWN)
	var dune_mask := smoothf(ds, PLATEAU_R, PLATEAU_FADE)
	h *= dune_mask

	# 5) стартовая площадка: ровный уклон, приглашающий скользнуть вниз
	# (trend добавится один раз в конце — здесь без него)
	var plateau := 2.0 - (SPAWN.y - z) * 0.30
	h = lerpf(plateau, h, dune_mask)

	# 6) стены-дюны по краям мира — путь читается естественно, без невидимых барьеров
	var edge := 0.0
	edge += smoothf(absf(x), 170.0, 260.0) # по бокам
	edge += smoothf(z, 70.0, 160.0) # за спиной старта
	edge += smoothf(-z, 460.0, 570.0) # за маяком
	h += edge * (26.0 + d * 22.0)

	return h + trend


## Дюнность 0..1 (до масок) — общий знаменатель для рельефа и покраски.
func dune_at(x: float, z: float) -> float:
	var d: float = _dunes.get_noise_2d(x * 1.15, z * 0.60)
	d = clampf(d * 0.5 + 0.5, 0.0, 1.0)
	return pow(d, 1.45) # острые гребни, мягкие ложбины


## Точная высота треугольника меша под точкой (совпадает с видимыми гранями).
func sample_height(x: float, z: float) -> float:
	var fx := (x - _x0) / _cell
	var fz := (z - _z0) / _cell
	var ix := clampi(int(floor(fx)), 0, SEGMENTS - 1)
	var iz := clampi(int(floor(fz)), 0, SEGMENTS - 1)
	var tx := clampf(fx - float(ix), 0.0, 1.0)
	var tz := clampf(fz - float(iz), 0.0, 1.0)

	var i00 := iz * _row + ix
	var h00 := _grid[i00]
	var h10 := _grid[i00 + 1]
	var h01 := _grid[i00 + _row]
	var h11 := _grid[i00 + _row + 1]

	if tx + tz <= 1.0:
		# нижний треугольник ячейки: 00, 10, 01
		return h00 + (h10 - h00) * tx + (h01 - h00) * tz
	# верхний треугольник ячейки: 10, 11, 01
	return h11 + (h10 - h11) * (1.0 - tz) + (h01 - h11) * (1.0 - tx)


## Нормаль поверхности (сглаженная по сетке — стабильна на границах ячеек).
func ground_normal(x: float, z: float) -> Vector3:
	var e := _cell * 0.35
	var hl := sample_height(x - e, z)
	var hr := sample_height(x + e, z)
	var hd := sample_height(x, z - e)
	var hu := sample_height(x, z + e)
	return Vector3(hl - hr, 2.0 * e, hd - hu).normalized()


func _build_grid() -> void:
	_grid.resize(_row * _row)
	_dgrid.resize(_row * _row)
	for iz in range(_row):
		var z := _z0 + float(iz) * _cell
		for ix in range(_row):
			var i := iz * _row + ix
			var x := _x0 + float(ix) * _cell
			_grid[i] = height_at(x, z)
			_dgrid[i] = dune_at(x, z)


func _build_mesh() -> void:
	var n := _row
	var count := n * n
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var uvs2 := PackedVector2Array() # x — дюнность 0..1 (для покраски шейдером)
	verts.resize(count)
	normals.resize(count)
	uvs.resize(count)
	uvs2.resize(count)

	# Нормали — центральными разностями по сетке высот (быстро и гладко).
	for iz in range(n):
		for ix in range(n):
			var i := iz * n + ix
			var x := _x0 + float(ix) * _cell
			var z := _z0 + float(iz) * _cell
			verts[i] = Vector3(x, _grid[i], z)
			uvs[i] = Vector2(x, z) * 0.01
			uvs2[i] = Vector2(_dgrid[i], 0.0)
			var xl := _grid[iz * n + maxi(ix - 1, 0)]
			var xr := _grid[iz * n + mini(ix + 1, n - 1)]
			var xd := _grid[maxi(iz - 1, 0) * n + ix]
			var xu := _grid[mini(iz + 1, n - 1) * n + ix]
			normals[i] = Vector3(xl - xr, 2.0 * _cell, xd - xu).normalized()

	# Индексы: два треугольника на ячейку. Winding как у PlaneMesh (FACE_Y):
	# во Godot фронталь «сверху» даёт cross(e1,e2) = -Y — иначе грань вывернута
	# и песок просвечивает насквозь. Диагональ (b-c) совпадает с sample_height.
	var idx := PackedInt32Array()
	idx.resize(SEGMENTS * SEGMENTS * 6)
	var w := 0
	for iz in range(SEGMENTS):
		for ix in range(SEGMENTS):
			var a := iz * n + ix
			var b := a + 1
			var c := a + n
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
	arrays[Mesh.ARRAY_TEX_UV2] = uvs2
	arrays[Mesh.ARRAY_INDEX] = idx

	var terrain_mesh := ArrayMesh.new()
	terrain_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/sand.gdshader")
	mat.set_shader_parameter("sun_dir", Game.SUN_DIR)
	mat.set_shader_parameter("sand_sunny", Game.SAND_SUNNY)
	mat.set_shader_parameter("sand_hot", Game.SAND_HOT)
	mat.set_shader_parameter("sand_shade", Game.SAND_SHADE)
	mat.set_shader_parameter("horizon_col", Game.HORIZON_COL)
	mat.set_shader_parameter("sky_col", Game.SKY_COL)
	mat.set_shader_parameter("fog_distance", Game.FOG_DISTANCE)
	mat.set_shader_parameter("wind_dir", Game.wind_dir())

	self.mesh = terrain_mesh
	material_override = mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _process(_delta: float) -> void:
	# Ветер один для всех: рябь и струи бегут туда, куда дует game.wind_dir().
	if material_override != null:
		var m: ShaderMaterial = material_override
		m.set_shader_parameter("wind_dir", game.wind_dir())
		m.set_shader_parameter("wind_power", game.wind_strength)


func smoothf(v: float, a: float, b: float) -> float:
	# smoothstep(a, b, v); корректно работает и при a > b
	var t := clampf((v - a) / (b - a), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)
