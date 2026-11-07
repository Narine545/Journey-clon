class_name GameWorld
extends Node3D
## Небо, луна и волюметрический туман (Forward+/Vulkan).
## Всё строится кодом в setup(). Горизонт закрыт настоящими дальними
## дюнами — карта террейна расширена (см. Coast), никаких подставок.

## Направления солнца лодочной сцены. Раньше ночным было
## Vector3(-0.62, 0.22, -0.75): y = +0.22, то есть светило оставалось на
## ~12.7° НАД горизонтом при night01 = 0.88. Диск гасили, направление — нет,
## поэтому тени шли по-дневному, а небо продолжало светиться закатом.
const BOAT_DAY_SUN := Vector3(-0.36, 0.76, -0.54)
const BOAT_DUSK_SUN := Vector3(-0.62, 0.22, -0.75)
const BOAT_NIGHT_SUN := Vector3(-0.71, -0.24, -0.66)


var game: GameState # автозагрузка Game

var _sky_mat: ShaderMaterial
var _sun: DirectionalLight3D
var _env: Environment
var _using_sky_plus := false
var _cloud_drift := 7.0
var compat_fallback := false # Vulkan не поднялся → Godot ушёл в Compatibility
var boat_lighting_profile := false


func setup(game_ref) -> void:
	game = game_ref
	_build_environment()
	_build_sun()


func _build_environment() -> void:
	# Полный Sky++ в Forward+: Rayleigh/Mie/Ozone + half-res raymarched
	# cumulus + cirrus. В Compatibility остаётся лёгкое прежнее небо.
	_using_sky_plus = RenderingServer.get_rendering_device() != null
	_sky_mat = ShaderMaterial.new()
	_sky_mat.shader = load("res://shaders/sky_plus.gdshader" if _using_sky_plus \
		else "res://shaders/sky.gdshader")
	if _using_sky_plus:
		_setup_sky_plus_material()
	else:
		_sky_mat.set_shader_parameter("sun_direction", game.sun_dir)

	var sky := Sky.new()
	sky.process_mode = Sky.PROCESS_MODE_REALTIME if _using_sky_plus else Sky.PROCESS_MODE_AUTOMATIC
	# Realtime Sky в Godot поддерживает только 256; явное значение убирает
	# предупреждение и совпадает с фактическим внутренним размером.
	sky.radiance_size = Sky.RADIANCE_SIZE_256 if _using_sky_plus else Sky.RADIANCE_SIZE_128
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
	_env.glow_hdr_threshold = 1.15

	# Контактная глубина и непрямой экранный свет: без них процедурные дюны
	# выглядят плоскими даже при хорошем небе и тумане.
	_env.ssao_enabled = true
	_env.ssao_radius = 3.0
	_env.ssao_intensity = 2.0
	_env.ssao_power = 1.35
	_env.ssil_enabled = true
	_env.ssil_radius = 6.0
	_env.ssil_intensity = 0.85

	# Дымка в цвет горизонта — для любых материалов со стандартным туманом.
	# Она дешёвая и работает даже без Forward+, поэтому держим её лёгкой:
	# основной воздух делает объёмный туман ниже, а не двойная дымка.
	_env.fog_enabled = true
	_env.fog_light_color = Game.HORIZON_COL
	_env.fog_density = 0.0034
	# Небо тоже должно уходить в дымку у горизонта. Нулевое значение делало
	# стык неба и дюн резким и визуально выдавало пост-эффект.
	_env.fog_sky_affect = 0.35
	# Из ветки радиобашни: воздушная перспектива смягчает дальние планы.
	# Высотный туман оттуда НЕ берём — он спрятал бы воду на уровне 0.
	_env.fog_aerial_perspective = 0.25

	# ВОЛЮМЕТРИЧЕСКИЙ ТУМАН (Forward+/Vulkan): настоящий 3D-объём —
	# луч фонаря и огонь маяка видны в воздухе. Крутилки — в DEV-панели (F3).
	_env.volumetric_fog_enabled = true
	# 0.09 превращало весь кадр в равномерную серую стену и убивало глубину.
	# Более длинный и прозрачный объём даёт планы, силуэты и световые лучи.
	_env.volumetric_fog_density = 0.026
	_env.volumetric_fog_albedo = Color(0.46, 0.52, 0.64)
	_env.volumetric_fog_emission = Color(0.006, 0.009, 0.018)
	_env.volumetric_fog_emission_energy = 0.35
	_env.volumetric_fog_anisotropy = 0.70
	_env.volumetric_fog_length = 160.0
	_env.volumetric_fog_detail_spread = 1.5
	_env.volumetric_fog_ambient_inject = 0.22
	_env.volumetric_fog_gi_inject = 0.0
	# ВНИМАНИЕ: volumetric_fog_sky_affect в 4.7.2 — мёртвая крутилка.
	# В fog.cpp вклад неба берётся из ambient_light_sky_contribution
	# (params.sky_contribution), а геттер volumetric_fog_sky_affect не
	# читает никто, кроме привязки свойства. Значение оставляем только
	# ради инспектора, управляем — через ambient_light_sky_contribution.
	_env.volumetric_fog_sky_affect = 0.30
	_env.volumetric_fog_temporal_reprojection_enabled = true

	var world_env := WorldEnvironment.new()
	world_env.environment = _env
	add_child(world_env)


## Sky++ preset: original look, but tuned from 64+64 marches to a practical
## 16 atmosphere / 24 cloud samples. Clouds render in the half-resolution pass.
func _setup_sky_plus_material() -> void:
	_sky_mat.set_shader_parameter("atmosphere_sample_count", 16)
	_sky_mat.set_shader_parameter("rayleigh_strength", 1.0)
	_sky_mat.set_shader_parameter("mie_strength", 0.82)
	_sky_mat.set_shader_parameter("ozone_strength", 1.0)
	_sky_mat.set_shader_parameter("mie_anisotropy_factor", 0.78)
	_sky_mat.set_shader_parameter("atmosphere_density", 1.0)
	_sky_mat.set_shader_parameter("exposure", 11.5)
	_sky_mat.set_shader_parameter("sundisc_intensity", 24.0)
	_sky_mat.set_shader_parameter("sun_disc_feather", 0.35)
	_sky_mat.set_shader_parameter("coverage", 0.43)
	_sky_mat.set_shader_parameter("cloud_smoothness", 0.075)
	_sky_mat.set_shader_parameter("cloud_marches", 24)
	_sky_mat.set_shader_parameter("light_marches", 6)
	_sky_mat.set_shader_parameter("density_coeff", 1.18)
	_sky_mat.set_shader_parameter("light_strength", 18.0)
	_sky_mat.set_shader_parameter("cloud_shape_size", 3.2)
	_sky_mat.set_shader_parameter("cloud_noise_size", 11.0)
	# В ветке радиобашни убрали клеточные кольца у облаков. Для морского
	# горизонта берём только этот выигрыш, а не игровой код того форка.
	_sky_mat.set_shader_parameter("cloud_noise_factor", 0.14)
	_sky_mat.set_shader_parameter("cloud_base_color", Color(0.58, 0.64, 0.76))
	_sky_mat.set_shader_parameter("cloud_overcast_color", Color(0.16, 0.20, 0.30))
	_sky_mat.set_shader_parameter("cloud_shape", _noise_3d(64, 2, 0.023, FastNoiseLite.TYPE_SIMPLEX_SMOOTH))
	_sky_mat.set_shader_parameter("cloud_noise", _noise_3d(64, 19, 0.045, FastNoiseLite.TYPE_SIMPLEX_SMOOTH))
	_sky_mat.set_shader_parameter("cloud_color_texture", _noise_2d(256, 41, 0.018, 3))
	_sky_mat.set_shader_parameter("use_cirrus", false) # без масляных разводов на горизонте
	_sky_mat.set_shader_parameter("cirrus_texture", _noise_2d(512, 73, 0.012, 4))
	_sky_mat.set_shader_parameter("cirrus_distortion_texture", _noise_2d(256, 7, 0.02, 2))
	_sky_mat.set_shader_parameter("cirrus_mask_texture", _noise_2d(256, 101, 0.008, 2))
	_sky_mat.set_shader_parameter("cirrus_scale", 0.22)
	_sky_mat.set_shader_parameter("cirrus_opacity", 0.16)
	_sky_mat.set_shader_parameter("use_rainbow", false)
	_sky_mat.set_shader_parameter("dim_stars_at_day", true)


func _noise_3d(px: int, seed_value: int, frequency: float, noise_type: int) -> NoiseTexture3D:
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.frequency = frequency
	noise.noise_type = noise_type as FastNoiseLite.NoiseType
	noise.fractal_octaves = 3
	var texture := NoiseTexture3D.new()
	texture.width = px
	texture.height = px
	texture.depth = px
	texture.seamless = true
	texture.noise = noise
	return texture


func _noise_2d(px: int, seed_value: int, frequency: float, octaves: int) -> NoiseTexture2D:
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.frequency = frequency
	noise.fractal_octaves = octaves
	var texture := NoiseTexture2D.new()
	texture.width = px
	texture.height = px
	texture.seamless = true
	texture.noise = noise
	return texture


func _build_sun() -> void:
	# Свет нужен в первую очередь небу (диск солнца).
	_sun = DirectionalLight3D.new()
	var forward: Vector3 = -(game.sun_dir as Vector3).normalized()
	_sun.basis = Basis.looking_at(forward, Vector3.UP)
	_sun.light_color = Color(1.0, 0.83, 0.66)
	_sun.light_energy = 1.15
	_sun.shadow_enabled = true
	_sun.directional_shadow_max_distance = 180.0
	_sun.directional_shadow_fade_start = 0.75
	_sun.light_volumetric_fog_energy = 0.75
	add_child(_sun)

	# Если Vulkan не поднялся, Godot молча уходит в Compatibility —
	# волюметрики там нет. Честно фиксируем и усиливаем depth-fog.
	compat_fallback = RenderingServer.get_rendering_device() == null
	if compat_fallback:
		print("WORLD: Vulkan недоступен — Compatibility-фолбэк, ",
			"волюметрический туман заменён плотной дымкой")


func _process(_delta: float) -> void:
	if _using_sky_plus and _sky_mat != null:
		# Два масштаба дрейфуют неодинаково — форма облаков эволюционирует,
		# а не ездит цельной маской по небу.
		var drift: Vector3 = (game.wind_dir_3d() as Vector3) \
			* float(game.elapsed) * _cloud_drift * 0.00018
		_sky_mat.set_shader_parameter("cloud_shape_offset", drift)
		_sky_mat.set_shader_parameter("cloud_noise_offset", -drift * 1.7)
		_sky_mat.set_shader_parameter("cirrus_offset", Vector2(drift.x, drift.z) * 0.35)


# ---------------------------------------------------------------------------
# API для DEV-панели (F3)
# ---------------------------------------------------------------------------

func set_sky(param: String, value) -> void:
	if not _using_sky_plus:
		_sky_mat.set_shader_parameter(param, value)
		return
	# Совместимость DEV-панели со словарём uniform-ов Sky++.
	match param:
		"sun_intensity": _sky_mat.set_shader_parameter("sundisc_intensity", float(value) * 0.48)
		"mie_scattering": _sky_mat.set_shader_parameter("mie_strength", clampf(float(value) * 100000.0, 0.0, 3.0))
		"rayleigh_scale_height": _sky_mat.set_shader_parameter("rayleigh_strength", float(value) / 8000.0)
		"rayleigh_multi_scattering": _sky_mat.set_shader_parameter("ozone_strength", 0.75 + float(value) * 10.0)
		"cloud_cover": _sky_mat.set_shader_parameter("coverage", value)
		"cloud_size": _sky_mat.set_shader_parameter("cloud_shape_size", float(value) * 2.5)
		"cloud_drift": _cloud_drift = float(value)
		_: _sky_mat.set_shader_parameter(param, value)


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
	var n: float = game.night01
	# песок/вода сами пекут свет в ALBEDO, поэтому сцена даёт только
	# «добавку»: днём солнце и небо слабее, иначе всё уходит в белое
	_env.ambient_light_energy = lerpf(0.72, 0.42, n)
	_env.tonemap_exposure = lerpf(0.95, 1.15, n)
	_env.fog_light_color = Game.HORIZON_COL.lerp(Color(0.15, 0.20, 0.34), n)
	# днём дымка лёгкая (0.008 volumetric = белая пелена на полкадра),
	# к ночи туман сгущается — это и есть ночной хоррор-воздух
	_env.fog_density = lerpf(0.0011, 0.0042, n) if not compat_fallback \
		else lerpf(0.0011, 0.011, n)
	_env.volumetric_fog_density = lerpf(0.0016, 0.019, n)
	_env.volumetric_fog_albedo = Color(0.72, 0.72, 0.72).lerp(Color(0.46, 0.52, 0.64), n)
	if _using_sky_plus:
		_sky_mat.set_shader_parameter("exposure", lerpf(13.5, 8.5, n))
		_sky_mat.set_shader_parameter("sundisc_intensity", lerpf(32.0, 10.0, n))
		_sky_mat.set_shader_parameter("coverage", lerpf(0.34, 0.48, n))
	else:
		_sky_mat.set_shader_parameter("sun_intensity", lerpf(50.0, 8.0, n))
	_sun.light_energy = lerpf(0.85, 0.30, n)
	_sun.light_color = Color(1.0, 0.83, 0.66).lerp(Color(0.72, 0.78, 0.95), n)


## Смена солнца: небо + свет (базис и цвет по Кельвину — низкое солнце
## краснеет, высокое белеет).
func apply_sun(dir: Vector3) -> void:
	# Sky++ читает LIGHT0_DIRECTION напрямую; fallback получает uniform.
	if not _using_sky_plus:
		_sky_mat.set_shader_parameter("sun_direction", dir)
	_sun.basis = Basis.looking_at(-dir.normalized(), Vector3.UP)
	var elev01 := smoothf(dir.y, 0.05, 0.55)
	var daylight := Color(1.0, 0.83, 0.66).lerp(Color(1.0, 0.97, 0.92), elev01)
	# Без порога 0.5: резкая замена солнца белой «луной» была заметна
	# на всём мире при смене сумерек.
	_sun.light_color = daylight.lerp(Color(0.59, 0.72, 0.91), game.night01)


## Постоянный лодочный профиль. Не связываем тонмаппер с SSAO, небом,
## тенями или нормалью воды: [L] должен сравнивать ОДНУ настройку.
func configure_boat_lighting() -> void:
	boat_lighting_profile = true
	_env.adjustment_enabled = true
	_env.adjustment_contrast = 1.12
	_env.adjustment_saturation = 1.08
	_env.ambient_light_sky_contribution = 0.85
	_env.ambient_light_color = Color(0.20, 0.27, 0.36)
	_env.ssao_radius = 1.35
	_env.ssao_intensity = 1.8
	# В Godot 4.7.2 имя свойства — ssao_light_affect, НЕ имя сеттера.
	_env.ssao_light_affect = 0.32
	_env.ssao_ao_channel_affect = 0.45
	_env.ssil_intensity = 0.95
	# Раньше здесь стояло volumetric_fog_enabled = false: «объём лишь
	# затемняет кадр без видимого рассеяния». Причина была не в стоимости
	# эффекта, а в настройках — свет в тумане обнулялся, а плотность была
	# мала. Без объёма в Forward+ не рендерится вообще ничего: и глобальный
	# туман, и FogVolume с RME4-шейдером пропускаются одним early-return в
	# _update_volumetric_fog(). Поэтому объём включён, а рассеяние в нём
	# настраивает apply_boat_atmosphere().
	_env.volumetric_fog_enabled = true
	_env.volumetric_fog_anisotropy = 0.25
	_env.volumetric_fog_gi_inject = 0.0
	# Тонкий слой требует более мелких ячеек по глубине. Для изометрии
	# тратить 160 м на невидимую даль не нужно; число froxel-ов не растёт.
	_env.volumetric_fog_length = 80.0
	_env.volumetric_fog_detail_spread = 1.0
	_sun.directional_shadow_max_distance = 100.0


func set_boat_tonemapper(use_agx: bool) -> void:
	_env.tonemap_mode = Environment.TONE_MAPPER_AGX if use_agx else Environment.TONE_MAPPER_FILMIC


## Направление НА солнце для заданного времени суток. Проходит через
## горизонт: к ночи светило действительно садится.
func boat_sun_dir(n01: float) -> Vector3:
	var n := clampf(n01, 0.0, 1.0)
	var dusk := BOAT_DAY_SUN.lerp(BOAT_DUSK_SUN, clampf(n / 0.55, 0.0, 1.0))
	return dusk.lerp(BOAT_NIGHT_SUN, clampf((n - 0.55) / 0.45, 0.0, 1.0)).normalized()


## ЕДИНСТВЕННЫЙ писатель лодочной атмосферы.
##
## Прежняя схема была «apply_night01(n) → apply_sun(dir) → fade_boat_sun(n)»,
## и все три писали одни и те же свойства: ambient_light_energy,
## tonemap_exposure, fog_density, volumetric_fog_density, light_energy,
## light_color и sundisc_intensity. Первые два вызова были мёртвыми
## записями — побеждал третий. Отсюда и ощущение, что свет «какой-то
## странный» и не поддаётся настройке.
##
## rme4_active — включён ли локальный FogVolume с RME4-шейдером. Когда он
## включён, глобальная плотность обязана быть нулевой: в Godot локальная
## плотность ПРИБАВЛЯЕТСЯ к volumetric_fog_density (volumetric_fog_process
## .glsl: total_density = params.base_density + local/1024), а не заменяет
## её, иначе к шумовому слою липнет равномерная пелена.
func apply_boat_atmosphere(n01: float, sun: Vector3, fill_energy: float,
		rme4_active: bool, weather_fog: float = 1.0, weather_cloud: float = 0.0) -> void:
	game.night01 = clampf(n01, 0.0, 1.0)
	var n: float = game.night01
	var fog := clampf(weather_fog, 0.0, 1.0)
	var cloud := clampf(weather_cloud, 0.0, 1.0)
	var sunset := clampf((n - 0.16) / 0.58, 0.0, 1.0)

	_sun.basis = Basis.looking_at(-sun.normalized(), Vector3.UP)

	# --- Ключевой свет -------------------------------------------------
	# Низкое солнце краснеет; ночью остаётся слабый холодный ключ, а не
	# ноль: форму держат тени, а не завышенная экспозиция.
	var elev01 := smoothf(sun.y, 0.05, 0.55)
	var daylight := Color(1.0, 0.83, 0.66).lerp(Color(1.0, 0.97, 0.92), elev01)
	# На закате ключ уходит в янтарь сильнее, чем даёт одна высота солнца,
	# иначе сумерки получались белёсыми, а не золотыми.
	daylight = daylight.lerp(Color(1.0, 0.62, 0.38), sin(sunset * PI) * 0.75)
	# В ночную синеву уходим только во второй половине заката, чтобы
	# золотой час не гасили сразу.
	_sun.light_color = daylight.lerp(Color(0.58, 0.71, 0.94),
		smoothf(sunset, 0.55, 1.0))
	var key := minf(0.42, fill_energy + 0.08) if boat_lighting_profile else fill_energy
	_sun.light_energy = lerpf(0.85, key, sunset) * lerpf(1.0, lerpf(0.68, 0.92, sunset), cloud)
	# Ключ НЕ должен гаснуть в воздухе вместе с диском. Прежнее
	# 0.75 * (1 - sunset) обнуляло его к ночи, и туман оставался плоским
	# серым wash'ем от ambient_inject. Теперь вклад ключа умеренный:
	# он не должен перекрывать локальный прожектор при смене курса.
	_sun.light_volumetric_fog_energy = lerpf(1.8, 1.1, sunset)

	# --- Небо ----------------------------------------------------------
	if _using_sky_plus:
		_sky_mat.set_shader_parameter("exposure", lerpf(13.5, 8.5, n) * lerpf(1.0, 0.92, cloud))
		_sky_mat.set_shader_parameter("coverage", lerpf(lerpf(0.34, 0.48, n), 0.88, cloud))
		_sky_mat.set_shader_parameter("sundisc_intensity", lerpf(32.0, 0.0, sunset))
	else:
		_sky_mat.set_shader_parameter("sun_intensity", lerpf(50.0, 0.0, sunset) * lerpf(1.0, 0.65, cloud))
	# Дневное рассеяние уходит вместе с диском, иначе при выключенном солнце
	# небо продолжало светиться как днём.
	_sky_mat.set_shader_parameter("daylight_scatter", lerpf(1.0, 0.16, sunset))

	# --- Заливка и пост ------------------------------------------------
	_env.ambient_light_energy = lerpf(0.72, 0.25 if boat_lighting_profile else 0.34, n)
	_env.tonemap_exposure = lerpf(0.95, 1.05, n)

	# --- Туман ---------------------------------------------------------
	_env.fog_light_color = Game.HORIZON_COL.lerp(Color(0.15, 0.20, 0.34), n)
	# Дымка материалов остаётся лёгкой: основной воздух делает объём, иначе
	# получается двойная пелена и сцена теряет глубину.
	_env.fog_density = lerpf(0.0012, 0.0035, n) if not compat_fallback \
		else lerpf(0.0011, 0.012, n)
	_env.fog_density *= lerpf(0.35, 1.0, fog)
	_env.fog_aerial_perspective = lerpf(0.25, 0.42, n)
	if rme4_active:
		_env.volumetric_fog_density = 0.0
	else:
		_env.volumetric_fog_density = lerpf(0.010, 0.018, n) * fog
	_env.volumetric_fog_albedo = Color(0.55, 0.60, 0.68).lerp(Color(0.30, 0.36, 0.48), n)
	# ambient_inject в Godot умножается на ambient_light_energy, поэтому
	# даже 0.10 днём давали бы вклад больше солнечного. Держим низким:
	# пусть воздух освещает ключ, а не константа.
	_env.volumetric_fog_ambient_inject = lerpf(0.10, 0.07, sunset)
	# Более широкий угловой отклик: вращение лодки не должно превращать
	# прожектор в почти невидимый луч. Полная независимость от угла не нужна.
	_env.volumetric_fog_anisotropy = 0.25


func smoothf(v: float, a: float, b: float) -> float:
	var t := clampf((v - a) / (b - a), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)
