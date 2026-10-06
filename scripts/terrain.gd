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

const SIZE := 1400.0 # сторона мира (метры) — горизонт закрывают НАСТОЯЩИЕ дюны
const SEGMENTS := 600 # разбиение (601x601 вершин, ячейка 2.33 м)
const CENTER := Vector2(0.0, -260.0) # центр плоскости

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

# --- ambient occlusion (горизонтный, запекается по карте высот) ---
const AO_STEP := 4 # сетка AO: каждая 4-я вершина (129×129)
const AO_DIRS := 8 # азимутов взгляда
const AO_RAYS := [2.5, 6.0, 12.0] # дистанции лучей горизонта, м

var game # автозагрузка Game
var sand: SandField # поле настоящего песка (может не быть)

var _warp := FastNoiseLite.new()
var _swell := FastNoiseLite.new()
var _macro := FastNoiseLite.new()
var _fine := FastNoiseLite.new()
var _wave := FastNoiseLite.new()
var _grid := PackedFloat32Array() # (SEGMENTS+1)^2 высот
var _dgrid := PackedFloat32Array() # те же узлы: дюнность 0..1 (для шейдера)
var _ao_grid := PackedFloat32Array() # грубая сетка AO (для шейдера, UV2.y)

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
	_build_ao()
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
	# Спуск ~88 м перепада на 320 м (~15° в среднем) — рельеф «падает»
	# к маяку непрерывно, тормозить не приходится никогда.
	var d0 := smoothf(-z, -40.0, 80.0) # 0 у старта → 1 к началу спуска
	var d1 := smoothf(-z, 80.0, 400.0) # зона длинного спуска
	var d2 := smoothf(-z, 400.0, 445.0) # выкат
	var trend := 8.0 + (1.0 - d0) * 8.0 - d1 * 88.0 - d2 * 8.0

	# 2) вал дюны: широкое плавное подножие и мягкий гребень.
	# В коридоре пути (|x| < 70) дюны вдвое ниже — дышится свободно,
	# полная их высота встаёт по сторонам, направляя взгляд к маяку.
	var s := dune_at(x, z)
	var dune := smoothf(s, 0.28, 0.78)
	var crest := smoothf(s, 0.74, 0.94)
	var corridor := 1.0 - 0.5 * (1.0 - smoothf(absf(x), 70.0, 140.0))
	var h := (dune * 17.0 + crest * 5.0) * corridor

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
	edge += smoothf(absf(x), 210.0, 320.0) # по бокам
	edge += smoothf(z, 70.0, 160.0) # за спиной старта
	edge += smoothf(-z, 560.0, 720.0) # дальняя стена дюн — дальше новые поля
	h += edge * (26.0 + dune * 22.0)

	# 8) длинный спуск: волны-перекаты поперёк пути, перестроенные под
	# «вперёд без торможений»: КРУТОЙ сброс ~35 м (сёрф-лицо навстречу
	# движению) и вдвое более пологий длинный подъём (~75 м), который
	# перекрывает базовый уклон — даже «в горку» путь продолжает падать.
	# Берега-валы отодвинуты: коридор ~260 м шириной.
	var dz_mask := smoothf(-z, 60.0, 110.0) * (1.0 - smoothf(-z, 380.0, 430.0))
	if dz_mask > 0.001:
		var wx: float = _warp.get_noise_2d(x * WARP_F + 3.1, z * WARP_F + 5.3)
		var px2: float = x + wx * WARP_AMP
		var wn: float = _wave.get_noise_2d(px2 * 0.011, z * 0.006)
		var q := fmod(-z * 0.008 + wn * 0.45, 1.0)
		if q < 0.0:
			q += 1.0
		# период ~125 м: сброс 0.06→0.34 (крутой), подъём 0.34→0.96 (пологий)
		var drop := 1.0 - smoothf(q, 0.06, 0.34)
		var rise := smoothf(q, 0.34, 0.96)
		h += dz_mask * clampf(drop + rise, 0.0, 1.0) * 6.5
		h += smoothf(absf(x), 130.0, 205.0) * dz_mask * 14.0

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


## Линейная выборка высоты прямо по сетке (для запечки AO — хватит).
func _sample_grid(x: float, z: float) -> float:
	var fx := clampf((x - _x0) / _cell, 0.0, float(SEGMENTS))
	var fz := clampf((z - _z0) / _cell, 0.0, float(SEGMENTS))
	var ix := int(fx)
	var iz := int(fz)
	var tx := fx - float(ix)
	var tz := fz - float(iz)
	var ix1 := mini(ix + 1, SEGMENTS)
	var iz1 := mini(iz + 1, SEGMENTS)
	var a := _grid[iz * _row + ix]
	var b := _grid[iz * _row + ix1]
	var c := _grid[iz1 * _row + ix]
	var d := _grid[iz1 * _row + ix1]
	return lerpf(lerpf(a, b, tx), lerpf(c, d, tx), tz)


## Ambient occlusion по горизонту: насколько соседние дюны закрывают небо
## над точкой. 8 азимутов × 3 дистанции, sin(horizon) усредняется.
## Запекаем раз в 4-й вершины, в шейдер уходит через UV2.y.
func _build_ao() -> void:
	var m := SEGMENTS >> 2 # AO_STEP = 4 — сдвиг вместо деления (без варнинга)
	var mm := m + 1
	_ao_grid.resize(mm * mm)
	for j in range(mm):
		var iz := j * AO_STEP
		var z := _z0 + float(iz) * _cell
		for i in range(mm):
			var ix := i * AO_STEP
			var x := _x0 + float(ix) * _cell
			var h0 := _grid[iz * _row + ix]
			var occ := 0.0
			for k in range(AO_DIRS):
				var a := TAU * float(k) / float(AO_DIRS)
				var dx := cos(a)
				var dz := sin(a)
				var horizon := 0.0
				for r in AO_RAYS:
					var dh := _sample_grid(x + dx * r, z + dz * r) - h0
					if dh > 0.0:
						horizon = maxf(horizon, dh / sqrt(dh * dh + r * r))
				occ += horizon
			_ao_grid[j * mm + i] = clampf(1.0 - occ * 0.17, 0.30, 1.0)


## AO в узел полной сетки (билинейно из грубой).
func _ao_at(ix: int, iz: int) -> float:
	var m := SEGMENTS >> 2 # AO_STEP = 4
	var fx := float(ix) / float(AO_STEP)
	var fz := float(iz) / float(AO_STEP)
	var i0 := mini(int(fx), m - 1)
	var j0 := mini(int(fz), m - 1)
	var tx := fx - float(i0)
	var tz := fz - float(j0)
	var mm := m + 1
	var a := _ao_grid[j0 * mm + i0]
	var b := _ao_grid[j0 * mm + i0 + 1]
	var c := _ao_grid[(j0 + 1) * mm + i0]
	var d := _ao_grid[(j0 + 1) * mm + i0 + 1]
	return lerpf(lerpf(a, b, tx), lerpf(c, d, tx), tz)


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
			uvs2[i] = Vector2(_dgrid[i], _ao_at(ix, iz)) # y — запечённый AO
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
	mat.set_shader_parameter("sun_dir", game.sun_dir)
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


## Направление солнца (DEV-панель).
func apply_sun(dir: Vector3) -> void:
	if material_override != null:
		(material_override as ShaderMaterial).set_shader_parameter("sun_dir", dir)


## Ночь красит ПЕСОК: шейдер песка освещается собственной палитрой
## (трёхсветовая схема), свет сцены его не трогает — поэтому день/ночь
## проводим прямо в uniform-ы: холодная тусклая луна, короткая видимость.
const DAY_SUNNY := Color(0.93, 0.52, 0.30)
const DAY_HOT := Color(1.00, 0.68, 0.36)
const DAY_SHADE := Color(0.40, 0.32, 0.52)
const DAY_HORIZON := Color(0.96, 0.66, 0.55)
const DAY_SKY := Color(0.28, 0.24, 0.43)
const NIGHT_SUNNY := Color(0.135, 0.155, 0.24)
const NIGHT_HOT := Color(0.19, 0.215, 0.32)
const NIGHT_SHADE := Color(0.055, 0.065, 0.115)
const NIGHT_HORIZON := Color(0.22, 0.27, 0.40)
const NIGHT_SKY := Color(0.04, 0.05, 0.10)

func set_night01(v: float) -> void:
	if material_override == null:
		return
	var m: ShaderMaterial = material_override
	m.set_shader_parameter("sand_sunny", DAY_SUNNY.lerp(NIGHT_SUNNY, v))
	m.set_shader_parameter("sand_hot", DAY_HOT.lerp(NIGHT_HOT, v))
	m.set_shader_parameter("sand_shade", DAY_SHADE.lerp(NIGHT_SHADE, v))
	m.set_shader_parameter("horizon_col", DAY_HORIZON.lerp(NIGHT_HORIZON, v))
	m.set_shader_parameter("sky_col", DAY_SKY.lerp(NIGHT_SKY, v))
	m.set_shader_parameter("fog_distance", lerpf(340.0, 130.0, v))
	m.set_shader_parameter("glitter_amount", lerpf(0.20, 0.06, v))


## Параметр шейдера песка (DEV-панель).
func set_sand(param: String, value) -> void:
	if material_override != null:
		(material_override as ShaderMaterial).set_shader_parameter(param, value)


## Подключает поле настоящего песка (создаётся после террейна).
func attach_sand(sand_ref: SandField) -> void:
	sand = sand_ref
	var m: ShaderMaterial = material_override
	m.set_shader_parameter("sand_map", sand_ref.get_texture())


func smoothf(v: float, a: float, b: float) -> float:
	# smoothstep(a, b, v); корректно работает и при a > b
	var t := clampf((v - a) / (b - a), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)
