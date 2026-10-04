class_name GameWorld
extends Node3D
## Небо, солнце, дымка, горизонт. Всё строится кодом в setup().
## Горизонт закрыт гигантскими барханами: серповидные дюны-меши
## в дымке (силуэты) + дальнее море барханов SDF-реймарчингом.

var game # автозагрузка Game


func setup(game_ref) -> void:
	game = game_ref
	_build_environment()
	_build_sun()
	_build_barchans()
	_build_sdf_dunes()
	_build_vignette()


func _build_environment() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.23, 0.21, 0.41)
	sky_mat.sky_horizon_color = Color(1.00, 0.68, 0.46)
	sky_mat.ground_bottom_color = Color(0.22, 0.16, 0.28)
	sky_mat.ground_horizon_color = Color(0.98, 0.64, 0.47)
	sky_mat.sun_angle_max = 9.0 # мягкий широкий ореол вокруг солнца
	sky_mat.sun_curve = 0.07
	sky_mat.sky_energy_multiplier = 1.0

	var sky := Sky.new()
	sky.sky_material = sky_mat

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.0

	# Киношный тонмаппинг: мягкие света, тёплая плёночная картинка
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.08
	env.tonemap_white = 4.0

	# Свечение: солнце и искры песка (в Compatibility glow есть)
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_strength = 1.0
	env.glow_bloom = 0.08
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.glow_hdr_threshold = 0.95

	# Дымка в цвет горизонта — для любых материалов со стандартным туманом.
	env.fog_enabled = true
	env.fog_light_color = Game.HORIZON_COL
	env.fog_density = 0.0034
	env.fog_sky_affect = 0.0

	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)


func _build_sun() -> void:
	# Свет нужен в первую очередь небу (диск солнца).
	var sun := DirectionalLight3D.new()
	var forward := -Game.SUN_DIR.normalized()
	sun.basis = Basis.looking_at(forward, Vector3.UP)
	sun.light_color = Color(1.0, 0.83, 0.66)
	sun.light_energy = 1.15
	sun.shadow_enabled = false
	add_child(sun)


# ---------------------------------------------------------------------------
# Горизонт: большие барханы-серпы (процедурные меши, силуэты в дымке)
# ---------------------------------------------------------------------------

## Серп бархана: дуга с сужающимися рогами и горбом посередине.
## Параметрическая сетка (дуга × поперёк), нормали — разностями.
func _barchan_mesh(radius: float, height: float, horn_drop: float) -> ArrayMesh:
	var seg := 40
	var rings := 10
	var arc := 3.4 # радиан (~195°) — рога обнимают горизонт
	var stride := rings + 1
	var count := (seg + 1) * stride

	var verts := PackedVector3Array()
	verts.resize(count)
	var normals := PackedVector3Array()
	normals.resize(count)

	for i in range(seg + 1):
		var u := float(i) / float(seg)
		var ang := -arc * 0.5 + arc * u
		var taper := 0.22 + 0.78 * sin(PI * u) # рога узкие, живот широкий
		var width := radius * 0.42 * taper
		var hmax := height * pow(sin(PI * clampf(u * 1.08, 0.0, 1.0)), 1.25)
		for j in range(stride):
			var v := float(j) / float(rings) * 2.0 - 1.0 # -1..1 поперёк
			var profile := pow(maxf(cos(v * PI * 0.5), 0.0), 1.35) # горб
			var horns := -pow(absf(v), 2.0) * horn_drop * (0.35 + 0.65 * (1.0 - sin(PI * u)))
			var x := sin(ang) * radius + cos(ang) * v * width
			var z := -cos(ang) * radius + sin(ang) * v * width
			var y := hmax * profile + horns
			verts[i * stride + j] = Vector3(x, y, z)

	# нормали конечными разностями по сетке (вверх)
	for i in range(seg + 1):
		var i0 := maxi(i - 1, 0)
		var i1 := mini(i + 1, seg)
		for j in range(stride):
			var j0 := maxi(j - 1, 0)
			var j1 := mini(j + 1, rings)
			var du := verts[i1 * stride + j] - verts[i0 * stride + j]
			var dv := verts[i * stride + j1] - verts[i * stride + j0]
			var n := dv.cross(du)
			if n.y < 0.0:
				n = -n
			normals[i * stride + j] = n.normalized()

	var idx := PackedInt32Array()
	idx.resize(seg * rings * 6)
	var w := 0
	for i in range(seg):
		for j in range(rings):
			var a := i * stride + j
			var b := a + 1
			var c := a + stride
			var d := c + 1
			idx[w] = a
			idx[w + 1] = b
			idx[w + 2] = c
			idx[w + 3] = b
			idx[w + 4] = d
			idx[w + 5] = c
			w += 6

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _build_barchans() -> void:
	# Силуэтный материал: дюны почти растворены в дымке, читаются массой
	var silhouette_mat := ShaderMaterial.new()
	silhouette_mat.shader = load("res://shaders/silhouette.gdshader")

	# [позиция, радиус, высота, просадка рогов, поворот°]
	var specs := [
		[Vector2(-430.0, -640.0), 210.0, 46.0, 26.0, -8.0],
		[Vector2(-40.0, -700.0), 260.0, 58.0, 30.0, 4.0],
		[Vector2(310.0, -660.0), 230.0, 50.0, 27.0, -5.0],
		[Vector2(650.0, -720.0), 200.0, 42.0, 24.0, 10.0],
		[Vector2(-720.0, -730.0), 240.0, 52.0, 28.0, -12.0],
		[Vector2(80.0, -560.0), 170.0, 36.0, 20.0, 6.0],
	]
	for spec in specs:
		var mi := MeshInstance3D.new()
		mi.mesh = _barchan_mesh(spec[1], spec[2], spec[3])
		mi.material_override = silhouette_mat
		mi.position = Vector3(spec[0].x, -6.0, spec[0].y)
		mi.rotate_y(deg_to_rad(spec[4]))
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)


func _build_sdf_dunes() -> void:
	# Дальнее море барханов: SDF-реймарчинг с плавным CSG (слой за слоем
	# за серпами) — горизонт «закрыт» и тает в мареве
	var far := SdfDunes.new()
	add_child(far)
	far.setup()


## Виньетка: лёгкое затемнение углов — собирает кадр, работает в любом
## рендерере (обычный Control поверх 3D, текстура генерируется кодом).
func _build_vignette() -> void:
	var rect := TextureRect.new()
	rect.texture = ProcTextures.vignette(512, 0.34)
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var layer := CanvasLayer.new()
	layer.layer = 10
	layer.add_child(rect)
	add_child(layer)
