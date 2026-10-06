class_name GameWorld
extends Node3D
## Небо, луна, волюметрический туман (Forward+/Vulkan), виньетка.
## Всё строится кодом в setup(). Горизонт закрыт настоящими дальними
## дюнами — карта террейна расширена (см. Terrain), никаких подставок.

var game # автозагрузка Game

var _sky_mat: ShaderMaterial
var _sun: DirectionalLight3D
var _env: Environment
var _beacon_light: OmniLight3D
var compat_fallback := false # Vulkan не поднялся → Godot ушёл в Compatibility


func setup(game_ref) -> void:
	game = game_ref
	_build_environment()
	_build_sun()
	_build_vignette()


func _build_environment() -> void:
	# Физически достоверное небо (Рэлей + Mie + озон): градиент, ореол
	# солнца и краски заката рождаются рассеянием, а не покраской.
	_sky_mat = ShaderMaterial.new()
	_sky_mat.shader = load("res://shaders/sky.gdshader")
	_sky_mat.set_shader_parameter("sun_direction", game.sun_dir)

	var sky := Sky.new()
	sky.sky_material = _sky_mat

	_env = Environment.new()
	_env.background_mode = Environment.BG_SKY
	_env.sky = sky
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	_env.ambient_light_energy = 1.0

	# Киношный тонмаппинг: ночью чуть длиннее выдержка
	_env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_env.tonemap_exposure = 1.08
	_env.tonemap_white = 4.0

	# Свечение: солнце и искры песка (в Compatibility glow есть)
	_env.glow_enabled = true
	_env.glow_intensity = 0.55
	_env.glow_strength = 1.0
	_env.glow_bloom = 0.08
	_env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	_env.glow_hdr_threshold = 0.95

	# Дымка в цвет горизонта — для любых материалов со стандартным туманом.
	_env.fog_enabled = true
	_env.fog_light_color = Game.HORIZON_COL
	_env.fog_density = 0.0034
	_env.fog_sky_affect = 0.0

	# ВОЛЮМЕТРИЧЕСКИЙ ТУМАН (Forward+/Vulkan): настоящий 3D-объём —
	# луч фонаря и огонь маяка видны в воздухе. Ночь пустыни: плотный
	# холодный туман гуляет по дюнам. Крутилки — в DEV-панели (F3).
	_env.volumetric_fog_enabled = true
	_env.volumetric_fog_density = 0.09
	_env.volumetric_fog_albedo = Color(0.55, 0.58, 0.66)
	_env.volumetric_fog_anisotropy = 0.55
	_env.volumetric_fog_length = 72.0
	_env.volumetric_fog_detail_spread = 2.0
	_env.volumetric_fog_ambient_inject = 0.12
	_env.volumetric_fog_gi_inject = 0.0
	_env.volumetric_fog_sky_affect = 0.0
	_env.volumetric_fog_temporal_reprojection_enabled = true

	var world_env := WorldEnvironment.new()
	world_env.environment = _env
	add_child(world_env)


func _build_sun() -> void:
	# Свет нужен в первую очередь небу (диск солнца).
	_sun = DirectionalLight3D.new()
	var forward: Vector3 = -(game.sun_dir as Vector3).normalized()
	_sun.basis = Basis.looking_at(forward, Vector3.UP)
	_sun.light_color = Color(1.0, 0.83, 0.66)
	_sun.light_energy = 1.15
	_sun.shadow_enabled = false
	add_child(_sun)

	# Если Vulkan не поднялся, Godot молча уходит в Compatibility —
	# волюметрики там нет. Честно фиксируем и усиливаем depth-fog.
	compat_fallback = RenderingServer.get_rendering_device() == null
	if compat_fallback:
		print("WORLD: Vulkan недоступен — Compatibility-фолбэк, ",
			"волюметрический туман заменён плотной дымкой")


## Тестовый «маяк» в тумане: тёплый пульсирующий огонёк в коридоре дюн —
## видно, как точечный свет играет в волюметрике (удаляется одним движением).
func build_beacon(terrain: Terrain) -> void:
	var x := 0.0
	var z := -150.0
	var y := terrain.sample_height(x, z)
	var pole := MeshInstance3D.new()
	add_child(pole)
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.35
	cyl.bottom_radius = 0.6
	cyl.height = 7.0
	pole.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.10, 0.08, 0.08)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.42, 0.20)
	mat.emission_energy_multiplier = 2.6
	pole.material_override = mat
	pole.global_position = Vector3(x, y + 3.5, z)
	_beacon_light = OmniLight3D.new()
	add_child(_beacon_light)
	_beacon_light.light_color = Color(1.0, 0.45, 0.22)
	_beacon_light.light_energy = 5.0
	_beacon_light.omni_range = 60.0
	_beacon_light.shadow_enabled = false
	_beacon_light.global_position = Vector3(x, y + 7.6, z)


func _process(_delta: float) -> void:
	if _beacon_light != null:
		_beacon_light.light_energy = 4.2 + 1.8 * sin(game.elapsed * 2.1)


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


# ---------------------------------------------------------------------------
# API для DEV-панели (F3)
# ---------------------------------------------------------------------------

func set_sky(param: String, value) -> void:
	_sky_mat.set_shader_parameter(param, value)


func get_exposure() -> float:
	return _env.tonemap_exposure


func set_exposure(v: float) -> void:
	_env.tonemap_exposure = v


func get_glow_threshold() -> float:
	return _env.glow_hdr_threshold


func set_glow_threshold(v: float) -> void:
	_env.glow_hdr_threshold = v


## Волюметрический туман: крутилки DEV-панели. В Compatibility-фолбэке
## плотность дополнительно уезжает в depth-fog — крутилки не мёртвые.
func set_vol_fog(param: String, value) -> void:
	_env.set(param, value)
	if param == "volumetric_fog_density" and compat_fallback:
		_env.fog_density = clampf(float(value) * 0.12, 0.002, 0.03)


## ГЛАВНЫЙ ПОЛЗУНОК «НОЧЬ» (0=день, 1=ночь): красит всё сразу —
## небо, свет, песок, туман, экспозицию, грейдинг.
func apply_night01(v: float) -> void:
	game.night01 = clampf(v, 0.0, 1.0)
	var n := game.night01
	_env.ambient_light_energy = lerpf(1.0, 0.30, n)
	_env.tonemap_exposure = lerpf(1.08, 1.16, n)
	_env.fog_light_color = Game.HORIZON_COL.lerp(Color(0.23, 0.28, 0.42), n)
	_env.fog_density = lerpf(0.0034, 0.0068, n) if not compat_fallback \
		else lerpf(0.0034, 0.011, n)
	_env.volumetric_fog_density = lerpf(0.012, 0.09, n)
	_env.volumetric_fog_albedo = Color(0.72, 0.72, 0.72).lerp(Color(0.55, 0.58, 0.66), n)
	_sky_mat.set_shader_parameter("sun_intensity", lerpf(50.0, 8.0, n))
	_sun.light_energy = lerpf(1.15, 0.30, n)
	_sun.light_color = Color(1.0, 0.83, 0.66).lerp(Color(0.72, 0.78, 0.95), n)


## Смена солнца: небо + свет (базис и цвет по Кельвину — низкое солнце
## краснеет, высокое белеет).
func apply_sun(dir: Vector3) -> void:
	_sky_mat.set_shader_parameter("sun_direction", dir)
	_sun.basis = Basis.looking_at(-dir.normalized(), Vector3.UP)
	if game.night01 > 0.5:
		var elev01n := smoothf(dir.y, 0.05, 0.55)
		_sun.light_color = Color(0.68, 0.74, 0.95).lerp(Color(0.85, 0.90, 1.0), elev01n)
	else:
		var elev01 := smoothf(dir.y, 0.05, 0.55)
		_sun.light_color = Color(1.0, 0.83, 0.66).lerp(Color(1.0, 0.97, 0.92), elev01)


func smoothf(v: float, a: float, b: float) -> float:
	var t := clampf((v - a) / (b - a), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)
