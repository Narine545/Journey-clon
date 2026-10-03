class_name Terrain
extends MeshInstance3D
## Процедурные дюны «как в Journey»: гигантские гладкие валы барханов,
## вытянутые вдоль пути, с плавными спусками для сёрфа. Никакого
## мелкооктавного «горного» шума — деталь даёт только рябь в шейдере.
## Хранит сетку высот; физика едет по гладкой бикубической поверхности
## этой сетки (Катмулл-Ром) — плотный меш делает её неотличимой от видимой.
##
## ПОВЕРХНОСТЬ = дюны + НАСТОЯЩИЙ ПЕСОК: SandField добавляет к высоте
## смещения из карты следов, и физика, и камера, и ветер ходят по этой
## сумме — путник ступает в собственные следы.

const SIZE := 1040.0 # сторона мира (метры)
const SEGMENTS := 512 # разбиение (513x513 вершин, ячейка 2 м)
const CENTER := Vector2(0.0, -190.0) # центр плоскости

const SPAWN := Vector2(0.0, 40.0) # старт игрока
const PATH_END_Z := -430.0 # конец пути у стены перед маяком

const PLATEAU_R := 14.0 # радиус ровной стартовой площадки
const PLATEAU_FADE := 60.0 # дальше — полноценные дюны

# --- дюнные формы (частоты — в циклах на метр) ---
const WARP_F := 1.0 / 130.0 # изгиб линий дюн
const WARP_AMP := 40.0 # амплитуда изгиба (метры)
const SWELL_X := 1.0 / 100.0 # частота валов поперёк пути
const SWELL_Z := 1.0 / 240.0 # вдоль пути — в 2.4 раза реже (длинные дюны)
const MACRO_F := 1.0 / 330.0 # где дюны выше, где ниже
const FINE_F := 1.0 / 23.0 # микро-рельеф — едва заметный
const FINE_AMP := 0.4

var game # автозагрузка Game
var sand: SandField # поле настоящего песка (может не быть)

var _warp := FastNoiseLite.new()
var _swell := FastNoiseLite.new()
var _macro := FastNoiseLite.new()
var _fine := FastNoiseLite.new()
var _wave := FastNoiseLite.new()
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

	_warp.seed = 517
	_warp.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_warp.frequency = WARP_F
	_warp.fractal_octaves = 1

	_swell.seed = 1373
	_swell.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_swell.frequency = 1.0
	_swell.fractal_octaves = 1 # одна октава — никаких «гор» из шума

	_macro.seed = 991
	_macro.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_macro.frequency = MACRO_F
	_macro.fractal_octaves = 2

	_fine.seed = 771
	_fine.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_fine.frequency = FINE_F
	_fine.fractal_octaves = 1

	_wave.seed = 3117
	_wave.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_wave.frequency = 1.0
	_wave.fractal_octaves = 1

	_build_grid()
	_build_mesh()


## Дюнность 0..1: варп координат изгибает линии, одна низкочастотная
## октава задаёт валы, вытянутые вдоль пути.
func dune_at(x: float, z: float) -> float:
	var wx: float = _warp.get_noise_2d(x * WARP_F + 3.1, z * WARP_F + 5.3)
	var wz: float = _warp.get_noise_2d(x * WARP_F + 7.7, z * WARP_F - 2.8)
	var px: float = x + wx * WARP_AMP
	var pz: float = z + wz * WARP_AMP
	var s: float = _swell.get_noise_2d(px * SWELL_X, pz * SWELL_Z)
	return clampf(s * 0.5 + 0.5, 0.0, 1.0)


## Непрерывная функция высоты (гладкая — по ней строится рельеф).
func height_at(x: float, z: float) -> float:
	# 1) рельеф пути: плоскогорье → длинный песочный спуск → выкат у маяка.
	# Спуск ~70 м перепада на 320 м (12–13° в среднем) — «горнолыжная»
	# секция, на склонах дюн поверх — до 25–35°.
	var d0 := smoothf(-z, -40.0, 80.0) # 0 у старта → 1 к началу спуска
	var d1 := smoothf(-z, 80.0, 400.0) # зона длинного спуска
	var d2 := smoothf(-z, 400.0, 445.0) # выкат
	var trend := 8.0 + (1.0 - d0) * 8.0 - d1 * 70.0 - d2 * 6.0

	# 2) вал дюны: широкое плавное подножие и мягкий гребень
	var s := dune_at(x, z)
	var dune := smoothf(s, 0.28, 0.78)
	var crest := smoothf(s, 0.74, 0.94)
	var h := dune * 17.0 + crest * 5.0

	# 3) макро-вариация: одни дюны выше, другие ниже
	var m := clampf(_macro.get_noise_2d(x, z) * 0.5 + 0.5, 0.0, 1.0)
	h *= 0.62 + 0.38 * m

	# 4) микро-рельеф — почти плоский (деталь у шейдерной ряби)
	h += _fine.get_noise_2d(x, z) * FINE_AMP

	# 5) у старта дюны гаснут — вход в игру с ровного балкона
	var ds := Vector2(x, z).distance_to(SPAWN)
	var dune_mask := smoothf(ds, PLATEAU_R, PLATEAU_FADE)
	h *= dune_mask

	# 6) стартовая площадка: ровный уклон, приглашающий скользнуть вниз
	# (trend добавится один раз в конце — здесь без него)
	var plateau := 2.0 - (SPAWN.y - z) * 0.30
	h = lerpf(plateau, h, dune_mask)

	# 7) стены-дюны по краям мира — путь читается естественно
	var edge := 0.0
	edge += smoothf(absf(x), 170.0, 260.0) # по бокам
	edge += smoothf(z, 70.0, 160.0) # за спиной старта
	edge += smoothf(-z, 460.0, 570.0) # за маяком
	h += edge * (26.0 + dune * 22.0)

	# 8) длинный спуск: перекаты поперёк пути (пологий наветренный склон,
	# крутой подветренный — сёрф-лицо вниз по пути) и берега-валы по бокам,
	# чтобы коридор читался как горнолыжная трейса.
	var dz_mask := smoothf(-z, 60.0, 110.0) * (1.0 - smoothf(-z, 380.0, 430.0))
	if dz_mask > 0.001:
		var wx: float = _warp.get_noise_2d(x * WARP_F + 3.1, z * WARP_F + 5.3)
		var px2: float = x + wx * WARP_AMP
		var wn: float = _wave.get_noise_2d(px2 * 0.011, z * 0.006)
		var q := fmod(-z * 0.0105 + wn * 0.45, 1.0)
		if q < 0.0:
			q += 1.0
		# пологий подъём ~48 м, крутой сброс ~19 м: волны каждые ~95 м пути
		h += dz_mask * minf(smoothf(q, 0.05, 0.55), 1.0 - smoothf(q, 0.55, 0.75)) * 9.0
		h += smoothf(absf(x), 95.0, 150.0) * dz_mask * 16.0

	return h + trend


## Высота дюн под точкой: бикубический Катмулл-Ром по сетке высот.
## Проходит через узлы сетки и C1-гладкая — путник не «дёргается»
## на стыках ячеек, а меш 2 м настолько плотный, что расхождение
## с видимыми треугольниками — миллиметры.
func sample_height(x: float, z: float) -> float:
	var fx := (x - _x0) / _cell
	var fz := (z - _z0) / _cell
	var ix := clampi(int(floor(fx)), 1, SEGMENTS - 2)
	var iz := clampi(int(floor(fz)), 1, SEGMENTS - 2)
	var tx := clampf(fx - float(ix), 0.0, 1.0)
	var tz := clampf(fz - float(iz), 0.0, 1.0)

	var c0 := _cr_x(iz - 1, ix, tx)
	var c1 := _cr_x(iz, ix, tx)
	var c2 := _cr_x(iz + 1, ix, tx)
	var c3 := _cr_x(iz + 2, ix, tx)
	return _cr(c0, c1, c2, c3, tz)


## НАСТОЯЩАЯ высота поверхности: дюны + смещение песка (следы!).
## По ней ходит физика путника, камера и ветер.
func ground_height(x: float, z: float) -> float:
	var h := sample_height(x, z)
	if sand != null:
		h += sand.disp_at(x, z)
	return h


## Нормаль поверхности (дюны + наклон потревоженного песка).
func ground_normal(x: float, z: float) -> Vector3:
	var e := _cell * 0.35
	var hl := ground_height(x - e, z)
	var hr := ground_height(x + e, z)
	var hd := ground_height(x, z - e)
	var hu := ground_height(x, z + e)
	return Vector3(hl - hr, 2.0 * e, hd - hu).normalized()


## Строка Катмулла-Рома по x в строке сетки iz.
func _cr_x(iz: int, ix: int, tx: float) -> float:
	var base := iz * _row + ix
	return _cr(_grid[base - 1], _grid[base], _grid[base + 1], _grid[base + 2], tx)


## Кубическая интерполяция Катмулла-Рома по четырём узлам.
func _cr(p0: float, p1: float, p2: float, p3: float, t: float) -> float:
	var t2 := t * t
	var t3 := t2 * t
	return 0.5 * (
		2.0 * p1
		+ (p2 - p0) * t
		+ (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2
		+ (3.0 * p1 - p0 - 3.0 * p2 + p3) * t3
	)


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
	# и песок просвечивает насквозь.
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
	mat.set_shader_parameter("sand_map", ProcTextures.black_pixel()) # до появления карты — нетронутый песок
	mat.set_shader_parameter("sand_texel", SandField.TEXEL)

	self.mesh = terrain_mesh
	material_override = mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _process(_delta: float) -> void:
	if material_override != null:
		var m: ShaderMaterial = material_override
		# Ветер один для всех: рябь и струи бегут туда, куда дует game.wind_dir().
		m.set_shader_parameter("wind_dir", game.wind_dir())
		m.set_shader_parameter("wind_power", game.wind_strength)
		# окно карты настоящего песка скользит за путником
		if sand != null:
			m.set_shader_parameter("sand_origin", Vector2(sand.win_x0, sand.win_z0))


## Подключает поле настоящего песка (создаётся после террейна).
func attach_sand(sand_ref: SandField) -> void:
	sand = sand_ref
	var m: ShaderMaterial = material_override
	m.set_shader_parameter("sand_map", sand_ref.get_texture())


func smoothf(v: float, a: float, b: float) -> float:
	# smoothstep(a, b, v); корректно работает и при a > b
	var t := clampf((v - a) / (b - a), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)
