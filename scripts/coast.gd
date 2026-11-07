class_name Coast
extends MeshInstance3D
## Closed island and seabed share a single sampled height field with the water.
## IslandLayout owns the coast, hills and bay; this class owns mesh/CPU/GPU data.
## SandField displacement remains real geometry, including walking footprints.

const OUTER_SEABED := -100.0
const EDGE_TRANSITION := 64.0
const SIZE := 900.0 # сторона мира (м)
const SEGMENTS := 760 # 761×761 вершин, ячейка ~1.18 м — урез не «лесенкой»
const CENTER := Vector2(170.0, 0.0) # центр плоскости

const SEA_LEVEL := 0.0 # уровень моря, м
const SPAWN_Z := -14.0 # z стартовой точки на пляже
const SPAWN_INLAND := 26.0 # сколько метров вглубь от уреза

# --- ambient occlusion, baked from the same island heights ---
const AO_STEP := 4
const AO_DIRS := 8
const AO_RAYS := [2.5, 6.0, 12.0]

var game: GameState # автозагрузка Game
var sand: SandField # поле настоящего песка (может не быть)

var _grid := PackedFloat32Array()
var _dgrid := PackedFloat32Array() # 0 — пляж, 1 — дюны (для шейдера)
var _ao_grid := PackedFloat32Array()
## Карта высот поверхности (та же, что у меша): шейдер моря кладёт
## плёнку прибоя прямо на песок — иначе на буграх она рвётся лоскутами.
var height_tex: ImageTexture
var grid_n := 0
var grid_origin := Vector2.ZERO
var grid_cell := 1.0

var _x0 := 0.0
var _z0 := 0.0
var _cell := 0.0
var _row := 0


func setup(game_ref) -> void:
	game = game_ref
	_x0 = CENTER.x - SIZE * 0.5
	_z0 = CENTER.y - SIZE * 0.5
	_cell = SIZE / float(SEGMENTS)
	_row = SEGMENTS + 1

	_build_grid()
	_build_ao()
	_build_mesh()


## Western land entry for legacy walking/fishing props only.
## This is not a terrain classifier: a closed coastline is not a function X(Z).
func shore_x(z: float) -> float:
	return IslandLayout.west_shore(z)


## Точка старта: всегда на одном и том же расстоянии вглубь от уреза.
func spawn_point() -> Vector2:
	return Vector2(shore_x(SPAWN_Z) + SPAWN_INLAND, SPAWN_Z)


## Island terrain (before SandField displacement) in world space.
func height_at(x: float, z: float) -> float:
	return IslandLayout.height_at(Vector2(x, z))


## Material blend from actual elevation: beach hollows to upland crests.
func dune01_at(x: float, z: float) -> float:
	return smoothf(height_at(x, z), 0.8, 14.0)


## Глубина воды в точке (0 — сухо). Учитывает следы на песке.
func water_depth(x: float, z: float) -> float:
	return maxf(0.0, SEA_LEVEL - ground_height(x, z))


func is_water(x: float, z: float) -> bool:
	return ground_height(x, z) < SEA_LEVEL - 0.02


## Направление «вглубь суши» в горизонтальной плоскости (по рельефу).
func land_dir(x: float, z: float) -> Vector3:
	var n := ground_normal(x, z)
	var d := Vector3(-n.x, 0.0, -n.z)
	if d.length_squared() < 0.000001:
		return Vector3.RIGHT
	return d.normalized()


# ---------------------------------------------------------------------------
# Выборка высоты
# ---------------------------------------------------------------------------

## Бикубический Катмулл-Ром по сетке высот: C1-гладкая поверхность,
## по которой ходит физика.
func sample_height(x: float, z: float) -> float:
	if x < _x0 or z < _z0 or x > _x0 + SIZE or z > _z0 + SIZE:
		return OUTER_SEABED
	var fx := (x - _x0) / _cell
	var fz := (z - _z0) / _cell
	# Крайние ячейки доходят до настоящего края, а не зажимаются
	# ко второму ряду бикубической выборки.
	if fx < 1.0 or fz < 1.0 or fx > SEGMENTS - 1 or fz > SEGMENTS - 1:
		var ex := clampi(int(floor(fx)), 0, SEGMENTS - 1)
		var ez := clampi(int(floor(fz)), 0, SEGMENTS - 1)
		var ux := clampf(fx - ex, 0.0, 1.0)
		var uz := clampf(fz - ez, 0.0, 1.0)
		return lerpf(lerpf(_grid[ez * _row + ex], _grid[ez * _row + ex + 1], ux),
			lerpf(_grid[(ez + 1) * _row + ex], _grid[(ez + 1) * _row + ex + 1], ux), uz)
	var ix := clampi(int(floor(fx)), 1, SEGMENTS - 2)
	var iz := clampi(int(floor(fz)), 1, SEGMENTS - 2)
	var tx := clampf(fx - float(ix), 0.0, 1.0)
	var tz := clampf(fz - float(iz), 0.0, 1.0)

	var c0 := _cr_x(iz - 1, ix, tx)
	var c1 := _cr_x(iz, ix, tx)
	var c2 := _cr_x(iz + 1, ix, tx)
	var c3 := _cr_x(iz + 2, ix, tx)
	return _cr(c0, c1, c2, c3, tz)


## Настоящая высота поверхности: рельеф + смещение песка (следы).
func ground_height(x: float, z: float) -> float:
	var h := sample_height(x, z)
	if sand != null:
		h += sand.disp_at(x, z)
	return h


func ground_normal(x: float, z: float) -> Vector3:
	var e := _cell * 0.35
	var hl := ground_height(x - e, z)
	var hr := ground_height(x + e, z)
	var hd := ground_height(x, z - e)
	var hu := ground_height(x, z + e)
	return Vector3(hl - hr, 2.0 * e, hd - hu).normalized()


func _cr_x(iz: int, ix: int, tx: float) -> float:
	var base := iz * _row + ix
	return _cr(_grid[base - 1], _grid[base], _grid[base + 1], _grid[base + 2], tx)


func _cr(p0: float, p1: float, p2: float, p3: float, t: float) -> float:
	var t2 := t * t
	var t3 := t2 * t
	return 0.5 * (
		2.0 * p1
		+ (p2 - p0) * t
		+ (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2
		+ (3.0 * p1 - p0 - 3.0 * p2 + p3) * t3
	)


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


# ---------------------------------------------------------------------------
# Сетка, AO, меш
# ---------------------------------------------------------------------------

func _build_ao() -> void:
	var m := SEGMENTS >> 2
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


func _ao_at(ix: int, iz: int) -> float:
	var m := SEGMENTS >> 2
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
			# Сетка, CPU и R32F-текстура имеют одну и ту же границу:
			# наружный пояс плавно уходит под море, а не обрывается стеной.
			var dx := minf(x - _x0, _x0 + SIZE - x)
			var dz := minf(z - _z0, _z0 + SIZE - z)
			var edge := smoothf(dx, 0.0, EDGE_TRANSITION) \
				* smoothf(dz, 0.0, EDGE_TRANSITION)
			_grid[i] = lerpf(OUTER_SEABED, height_at(x, z), edge)
			_dgrid[i] = smoothf(_grid[i], 0.8, 14.0) # reuse height; no second coast evaluation
	_build_height_tex()


## R32F-карта высот для моря: ровно те вершины, что видит глаз.
func _build_height_tex() -> void:
	grid_n = _row
	grid_origin = Vector2(_x0, _z0)
	grid_cell = _cell
	var img := Image.create_from_data(_row, _row, false, Image.FORMAT_RF,
		_grid.to_byte_array())
	height_tex = ImageTexture.create_from_image(img)


func _build_mesh() -> void:
	var n := _row
	var count := n * n
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var uvs2 := PackedVector2Array()
	verts.resize(count)
	normals.resize(count)
	uvs.resize(count)
	uvs2.resize(count)

	for iz in range(n):
		for ix in range(n):
			var i := iz * n + ix
			var x := _x0 + float(ix) * _cell
			var z := _z0 + float(iz) * _cell
			verts[i] = Vector3(x, _grid[i], z)
			uvs[i] = Vector2(x, z) * 0.01
			uvs2[i] = Vector2(_dgrid[i], _ao_at(ix, iz))
			var xl := _grid[iz * n + maxi(ix - 1, 0)]
			var xr := _grid[iz * n + mini(ix + 1, n - 1)]
			var xd := _grid[maxi(iz - 1, 0) * n + ix]
			var xu := _grid[mini(iz + 1, n - 1) * n + ix]
			normals[i] = Vector3(xl - xr, 2.0 * _cell, xd - xu).normalized()

	# Winding как у PlaneMesh (FACE_Y): иначе грань вывернута и песок
	# просвечивает насквозь.
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

	var coast_mesh := ArrayMesh.new()
	coast_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

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
	mat.set_shader_parameter("sand_map", ProcTextures.black_pixel())
	mat.set_shader_parameter("sand_texel", SandField.TEXEL)
	# мокрая полоса у уреза и подводный песок — красит шейдер
	mat.set_shader_parameter("sea_level", SEA_LEVEL)
	# Узкая мокрая кайма сохраняет тёплую палитру суши; вода остаётся
	# отдельным холодным материалом.
	mat.set_shader_parameter("wet_band", 0.18)
	mat.set_shader_parameter("wet_darken", 0.38)

	mesh = coast_mesh
	material_override = mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _process(_delta: float) -> void:
	if material_override != null:
		var m: ShaderMaterial = material_override
		m.set_shader_parameter("wind_dir", game.wind_dir())
		m.set_shader_parameter("wind_power", game.wind_strength)
		if sand != null:
			m.set_shader_parameter("sand_origin", Vector2(sand.win_x0, sand.win_z0))


func apply_sun(dir: Vector3) -> void:
	if material_override != null:
		(material_override as ShaderMaterial).set_shader_parameter("sun_dir", dir)


## Ночь красит ПЕСОК: шейдер песка живёт на собственной палитре.
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
	m.set_shader_parameter("night_amount", v)


func set_sand(param: String, value) -> void:
	if material_override != null:
		(material_override as ShaderMaterial).set_shader_parameter(param, value)


func attach_sand(sand_ref: SandField) -> void:
	sand = sand_ref
	var m: ShaderMaterial = material_override
	m.set_shader_parameter("sand_map", sand_ref.get_texture())


func smoothf(v: float, a: float, b: float) -> float:
	var t := clampf((v - a) / (b - a), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


## 0..1 «бугор» между a и b (нарастает, потом спадает).
func bump01(v: float, a: float, b: float) -> float:
	if v <= a or v >= b:
		return 0.0
	var t := (v - a) / (b - a)
	return sin(PI * t)
