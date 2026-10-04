class_name GameWorld
extends Node3D
## Небо, солнце, дымка, виньетка. Всё строится кодом в setup().
## Горизонт закрыт настоящими дальними дюнами — карта террейна
## расширена (см. Terrain), никаких декораций-подставок.

var game # автозагрузка Game

var _sky_mat: ShaderMaterial
var _sun: DirectionalLight3D
var _env: Environment


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

	# Киношный тонмаппинг: мягкие света, тёплая плёночная картинка
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


## Смена солнца: небо + свет (базис и цвет по Кельвину — низкое солнце
## краснеет, высокое белеет).
func apply_sun(dir: Vector3) -> void:
	_sky_mat.set_shader_parameter("sun_direction", dir)
	_sun.basis = Basis.looking_at(-dir.normalized(), Vector3.UP)
	var elev01 := smoothf(dir.y, 0.05, 0.55)
	_sun.light_color = Color(1.0, 0.83, 0.66).lerp(Color(1.0, 0.97, 0.92), elev01)


func smoothf(v: float, a: float, b: float) -> float:
	var t := clampf((v - a) / (b - a), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)
