class_name BoatMain
extends Node3D
## Игровой цикл «To The Light»:
## - Сбор и переработка 4 пигментов, покупка буксируемого плашкоута
## - Наступающие сумерки (динамический night01)
## - Цепь из 3 Погасших Маяков с глубоководными причальными буями вдоль берега
## - Морские рифы, прочность корпуса и 3 активные судовые системы (Сонар, Ремонт, Форсаж)

const START_Z := Coast.SPAWN_Z
const START_SEAWARD := 95.0
const SLICK_RECYCLE_DISTANCE := 60.0
const SLICK_SPAWN_MIN := 38.0
const SLICK_SPAWN_MAX := 57.0
const TRAILER_COST := 2
const DOCK_RANGE := 13.5
const RME4_BOX_SIZE := Vector3(320.0, 60.0, 320.0)
const RME4_BOX_Y := 22.0
const RME4_NOISE_PX := 32

var game: GameState
var world: GameWorld
var coast: Coast
var sand: SandField
var water: WaterSurface
var boat: BoatVessel
var camera: Camera3D
var hud: BoatHud
var slicks: Array[ResourceSlick] = []
var debug_slick_parallax := true
var raw := PackedInt32Array([0, 0, 0, 0])
var refined := PackedInt32Array([0, 0, 0, 0])
var notice := ""
var notice_time := 0.0

# Состояние игрового цикла (Маяки, Сумерки, Рифы, Сонар)
var night01 := 0.0
var sonar_timer := 12.0 # со старта даём краткий пеленг, чтобы игрок сразу увидел цель
var overdrive_timer := 0.0
var beacons: Array[Dictionary] = []
var reefs: Array[Dictionary] = []
var all_beacons_lit := false

# Быстрый тест встроен в лодочную сцену, не требует внешних консольных команд.
var debug_panel_visible := true
var debug_night_paused := false
var debug_night_fill := 0.18
var debug_lighting_profile := true
var debug_headlight_enabled := true
var debug_retro_enabled := false
# RME4-слой — это штатный воздух сцены, а не отладочный режим: без него
# Forward+ не рендерит объёмный туман вовсе (см. configure_boat_lighting).
var debug_rme4_enabled := true
var debug_mystery_atmosphere := true
var debug_fog_diagnostic := 0
var _fog_diagnostic_saved_enabled := true
var _fog_diagnostic_saved_emission := Color.BLACK
var _fog_diagnostic_saved_emission_energy := 0.0
var _retro_rect: ColorRect
var _rme4_volume: FogVolume
var _rme4_material: ShaderMaterial
var _debug_night_step := 0

var _capture_frames := 0
var _camera_focus := Vector3.ZERO
var _stream_timer := 0.0
var _stream_cursor := 0
var _beacon_anim_time := 0.0
var _atmosphere_timer := 0.0
var _slick_rng := RandomNumberGenerator.new()


func _ready() -> void:
	game = get_node("/root/Game") as GameState
	world = GameWorld.new()
	add_child(world)
	world.setup(game)
	world.configure_boat_lighting()
	world.set_boat_tonemapper(debug_lighting_profile)
	coast = Coast.new()
	add_child(coast)
	coast.setup(game)
	sand = SandField.new()
	add_child(sand)
	sand.setup(game)
	coast.attach_sand(sand)
	coast.set_sand("orthographic_glitter", 1.0)
	water = WaterSurface.new()
	water.shader_path = "res://shaders/water_boat.gdshader"
	add_child(water)
	water.setup(game, Vector2(-150.0, 20.0), Coast.SEA_LEVEL)
	water.configure_boat_waves()
	water.set_ground(coast.height_tex, coast.grid_origin, coast.grid_cell, coast.grid_n, coast)
	game.water = water
	boat = BoatVessel.new()
	boat.name = "Vessel"
	# Только физически движущаяся ветка: вода/камера/пятна живут в _process.
	boat.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON
	add_child(boat)
	boat.global_position = Vector3(coast.shore_x(START_Z) - START_SEAWARD, 0.2, START_Z)
	boat.setup(self, water, coast)
	boat.reset_physics_interpolation()
	if OS.get_environment("JOURNEY_BOAT_SHOT_TRAILER") == "1":
		boat.set_trailer_enabled(true)
	_build_resources()
	_build_beacons()
	_build_reefs()
	_slick_rng.seed = 845239
	camera = Camera3D.new()
	camera.name = "IsometricCamera"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 32.0
	camera.near = 0.2
	camera.far = 1500.0
	add_child(camera)
	camera.current = true
	_camera_focus = boat.global_position + Vector3.UP * 0.8
	camera.position = boat.global_position + Vector3(21.0, 27.0, 30.0)
	camera.look_at(_camera_focus, Vector3.UP)
	hud = BoatHud.new()
	var layer := CanvasLayer.new()
	layer.layer = 12
	add_child(layer)
	hud.main = self
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(hud)
	_setup_retro_debug()
	_setup_rme4_atmosphere()
	_ensure_boat_input()
	if OS.get_environment("JOURNEY_BOAT_SHOT_DRIVE") == "1":
		Input.action_press("boat_forward")
	_apply_atmosphere(0.0)
	if OS.get_environment("JOURNEY_BOAT_SMOKE") == "1":
		var test := BoatSmoke.new()
		add_child(test)
		test.setup(self)


func _apply_atmosphere(n01: float) -> void:
	night01 = clampf(n01, 0.0, 0.88)
	coast.set_night01(night01)
	water.apply_night01(night01)
	# Солнце проходит через горизонт: к ночи оно садится, а не остаётся
	# висеть на 12° с выключенным диском.
	var sun := world.boat_sun_dir(night01)
	game.sun_dir = sun
	# Один вызов вместо трёх конфликтующих. Раньше здесь шли подряд
	# apply_night01(), apply_sun() и fade_boat_sun(), и все три писали одни
	# и те же свойства окружения — побеждал последний, а первые два были
	# мёртвыми записями.
	world.apply_boat_atmosphere(night01, sun, debug_night_fill, debug_rme4_enabled)
	if debug_fog_diagnostic != 0:
		_apply_fog_diagnostic()
	if _rme4_material != null:
		_rme4_material.set_shader_parameter("night_factor", night01)
		_rme4_material.set_shader_parameter("sun_direction", sun)
	coast.apply_sun(sun)
	water.apply_sun(sun)
	# Уходит дневной свет, а не включается отдельная луна. Оставляем
	# тёмную воду и цвет тумана, не меняя настройки микробликов.
	water.set_param("water_shallow", Color("49a9a2").lerp(Color("163d42"), night01))
	water.set_param("water_mid", Color("258b91").lerp(Color("0b2530"), night01))
	water.set_param("water_deep", Color("0f5668").lerp(Color("04111c"), night01))
	water.set_param("horizon_col", Color("6996a0").lerp(Color("1d2c3b"), night01))
	water.set_param("sky_col", Color("447084").lerp(Color("0d1624"), night01))
	water.set_param("sun_col", Color("ffcc85").lerp(Color("a8c9e3"), night01))
	water.set_param("mega_amp", lerpf(0.25, 0.31, night01))
	water.set_param("ripple_strength", 0.10)
	# Ночной фон только у моря: скрытые пятна не подсвечиваем.
	var water_night := smoothstep(0.35, 0.80, night01)
	water.set_param("night_surface_fill", 0.18 * water_night)
	water.set_param("glitter_amount", lerpf(0.32, 0.18, night01))
	# Это широкая искусственная дорожка, НЕ отдельные искры-глиттер.
	# Плавно убрать её до наступления полной темноты.
	water.set_param("sun_path_amount", 0.09 * (1.0 - clampf((night01 - 0.25) / 0.53, 0.0, 1.0)))
	water.set_param("direct_specular_amount", 0.018)
	water.set_param("surface_light_detail", 0.16) # [L] не меняет нормаль воды
	water.set_param("swell_light_detail", 0.65) # [K] — сравнение с прежней водой
	if boat != null:
		boat.update_night_lights(night01, overdrive_timer > 0.0)
		for slick in slicks:
			slick.configure_night_visibility(boat._bow_spot, night01)


# ---------------------------------------------------------------------------
# Постройка 3 береговых Маяков с причальными буями и морских рифов
# ---------------------------------------------------------------------------

func _mat(col: Color, metal := 0.0, glow := 0.0, rough := 0.68) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.metallic = metal
	m.roughness = rough
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = col
		m.emission_energy_multiplier = glow
	return m


func _build_beacons() -> void:
	var specs := [
		{
			"name": "Южный Створ",
			"z": START_Z - 105.0,
			"cost": PackedInt32Array([1, 0, 1, 0]), # 1 Бирюза + 1 Янтарь
			"color": Color("ffd485"),
		},
		{
			"name": "Рифовый Мыс",
			"z": START_Z + 18.0,
			"cost": PackedInt32Array([1, 1, 1, 0]), # 1 Бирюза + 1 Коралл + 1 Янтарь
			"color": Color("78f0dc"),
		},
		{
			"name": "Северный Бастион",
			"z": START_Z + 142.0,
			"cost": PackedInt32Array([1, 1, 1, 1]), # Все 4 очищенных пигмента
			"color": Color("f5b8ff"),
		},
	]
	var stone_mat := _mat(Color("3b4247"), 0.15, 0.0, 0.82)
	var tower_mat := _mat(Color("c9c2b4"), 0.08, 0.0, 0.68)
	var band_mat := _mat(Color("8f4636"), 0.18, 0.0, 0.62)
	var iron_mat := _mat(Color("1a2228"), 0.55, 0.0, 0.48)

	for i in range(specs.size()):
		var s: Dictionary = specs[i]
		var bz: float = s["z"]
		var shore_x := coast.shore_x(bz)
		var tower_pos := Vector3(shore_x + 10.0, Coast.SEA_LEVEL + 1.2, bz)
		# Ищем настоящую глубину, а не предполагаем, что 36 м от берега
		# автоматически дают обещанные 4.5 м (обычно там лишь ~3 м).
		var buoy_x := shore_x - 36.0
		while coast.water_depth(buoy_x, bz) < 4.5 and buoy_x > shore_x - 110.0:
			buoy_x -= 3.0
		var buoy_pos := Vector3(buoy_x, Coast.SEA_LEVEL, bz)

		var root := Node3D.new()
		root.name = "CoastalBeacon%d" % i
		add_child(root)

		# Каменная башня маяка на берегу
		var tower := Node3D.new()
		tower.position = tower_pos
		root.add_child(tower)
		_add_cyl(tower, Vector3(0.0, 1.4, 0.0), 2.3, 2.8, 3.2, stone_mat)
		_add_cyl(tower, Vector3(0.0, 5.2, 0.0), 1.45, 2.1, 4.6, tower_mat)
		_add_cyl(tower, Vector3(0.0, 8.2, 0.0), 1.25, 1.45, 1.8, band_mat)
		_add_cyl(tower, Vector3(0.0, 9.4, 0.0), 1.65, 1.55, 0.6, iron_mat)

		# Фонарная камера маяка (гаснет/зажигается)
		var lantern_mat := _mat(Color("26343b"), 0.2, 0.0, 0.25)
		var lantern_mesh := _add_cyl(tower, Vector3(0.0, 10.3, 0.0), 1.15, 1.15, 1.4, lantern_mat)
		_add_cyl(tower, Vector3(0.0, 11.4, 0.0), 0.1, 1.45, 1.0, iron_mat)

		var top_light := OmniLight3D.new()
		top_light.light_color = s["color"]
		top_light.light_energy = 0.0
		top_light.omni_range = 28.0
		top_light.position = Vector3(0.0, 10.4, 0.0)
		tower.add_child(top_light)

		# Вращающийся прожекторный луч маяка
		var beam_pivot := Node3D.new()
		beam_pivot.position = Vector3(0.0, 10.3, 0.0)
		tower.add_child(beam_pivot)
		var spot := SpotLight3D.new()
		spot.light_color = s["color"]
		spot.light_energy = 0.0
		spot.spot_range = 58.0
		spot.spot_angle = 20.0
		spot.light_volumetric_fog_energy = 0.45
		spot.rotation = Vector3(-0.22, PI * 0.5, 0.0)
		beam_pivot.add_child(spot)

		# Глубоководный причальный буй в море (где лодка безопасно швартуется)
		var buoy := Node3D.new()
		buoy.position = buoy_pos
		root.add_child(buoy)
		_add_cyl(buoy, Vector3(0.0, 0.15, 0.0), 1.25, 0.95, 0.55, band_mat)
		_add_cyl(buoy, Vector3(0.0, 0.95, 0.0), 0.18, 0.45, 1.2, iron_mat)
		var buoy_lamp_mat := _mat(Color("e88554"), 0.1, 1.4, 0.25)
		var buoy_lamp := _add_cyl(buoy, Vector3(0.0, 1.65, 0.0), 0.22, 0.22, 0.28, buoy_lamp_mat)

		beacons.append({
			"name": s["name"],
			"cost": s["cost"],
			"color": s["color"],
			"lit": false,
			"tower_pos": tower_pos,
			"buoy_node": buoy,
			"buoy_pos": buoy_pos,
			"lantern_mat": lantern_mat,
			"lantern_mesh": lantern_mesh,
			"buoy_lamp_mat": buoy_lamp_mat,
			"buoy_lamp": buoy_lamp,
			"top_light": top_light,
			"spot": spot,
			"beam_pivot": beam_pivot,
		})


func _build_reefs() -> void:
	# Координаты скал выбраны в стороне от стартового коридора автотеста boat_smoke.gd
	var offsets := [
		Vector2(18.0, -34.0),
		Vector2(-26.0, -48.0),
		Vector2(24.0, 52.0),
		Vector2(-38.0, 68.0),
		Vector2(12.0, -82.0),
		Vector2(22.0, 108.0),
	]
	var base := Vector2(boat.global_position.x, boat.global_position.z)
	var rock_mat := _mat(Color("222a30"), 0.12, 0.0, 0.88)
	var barnacle_mat := _mat(Color("3d4b4a"), 0.08, 0.0, 0.85)
	var warn_mat := _mat(Color("f06848"), 0.1, 1.5, 0.3)

	for i in range(offsets.size()):
		var rp: Vector2 = base + offsets[i]
		if coast.water_depth(rp.x, rp.y) < 3.5:
			continue
		var r_node := Node3D.new()
		r_node.name = "SeaReef%d" % i
		r_node.position = Vector3(rp.x, Coast.SEA_LEVEL, rp.y)
		add_child(r_node)

		# Главный скальный пик и боковые валуны
		_add_cyl(r_node, Vector3(0.0, 0.35, 0.0), 0.45, 2.25, 1.85, rock_mat, Vector3(0.12, float(i) * 1.1, -0.08), 7)
		_add_cyl(r_node, Vector3(1.15, 0.05, 0.65), 0.35, 1.45, 1.15, barnacle_mat, Vector3(-0.15, 0.5, 0.18), 6)
		_add_cyl(r_node, Vector3(-1.05, -0.05, -0.55), 0.30, 1.35, 0.95, rock_mat, Vector3(0.1, -0.7, -0.14), 6)
		# Предупреждающая навигационная веха на рифе
		_add_cyl(r_node, Vector3(0.0, 1.55, 0.0), 0.04, 0.05, 0.95, rock_mat)
		_add_cyl(r_node, Vector3(0.0, 2.08, 0.0), 0.10, 0.10, 0.16, warn_mat)

		reefs.append({
			"pos": rp,
			"radius": 2.65,
			"node": r_node,
		})


func _add_cyl(parent: Node3D, at: Vector3, rt: float, rb: float, h: float, mat: Material, rot := Vector3.ZERO, segs := 12) -> MeshInstance3D:
	var inst := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = rt
	c.bottom_radius = rb
	c.height = h
	c.radial_segments = segs
	inst.mesh = c
	inst.position = at
	inst.rotation = rot
	inst.material_override = mat
	parent.add_child(inst)
	return inst


func _build_resources() -> void:
	var base := Vector2(boat.global_position.x, boat.global_position.z)
	var samples := [
		Vector2(-3, -11), Vector2(-17, -13), Vector2(-20, 3),
		Vector2(-5, 21), Vector2(13, 28), Vector2(-29, 25),
		Vector2(-40, -9), Vector2(6, -30), Vector2(-32, -38),
		Vector2(-13, 42), Vector2(16, 45), Vector2(-47, 43),
	]
	for i in range(samples.size()):
		var at: Vector2 = base + samples[i]
		if coast.water_depth(at.x, at.y) < 3.0:
			continue
		var slick := ResourceSlick.new()
		slick.name = "PigmentSlick%d" % i
		add_child(slick)
		slick.setup(water, at, i % ResourceSlick.COLORS.size(), float(i) * 1.73)
		slicks.append(slick)


func _outside_boat_view(at: Vector2) -> bool:
	var relative := Vector3(at.x - boat.global_position.x, 0.0,
		at.y - boat.global_position.z)
	var viewport_size := get_viewport().get_visible_rect().size
	var half_height := camera.size * 0.5 + 4.0
	var half_width := camera.size * 0.5 * viewport_size.x / maxf(viewport_size.y, 1.0) + 4.0
	return absf(relative.dot(camera.global_transform.basis.x)) > half_width or \
		absf(relative.dot(camera.global_transform.basis.y)) > half_height


func _outside_camera_view(at: Vector2) -> bool:
	var screen_pos := camera.unproject_position(Vector3(at.x, Coast.SEA_LEVEL, at.y))
	var viewport_size := get_viewport().get_visible_rect().size
	return not Rect2(Vector2(-64.0, -64.0),
		viewport_size + Vector2(128.0, 128.0)).has_point(screen_pos)


func _stream_resources() -> void:
	var center := Vector2(boat.global_position.x, boat.global_position.z)
	var forward := Vector2(-boat.global_transform.basis.z.x,
		-boat.global_transform.basis.z.z)
	for offset in range(slicks.size()):
		var index := (_stream_cursor + offset) % slicks.size()
		var slick := slicks[index]
		if slick.depleted:
			continue
		var current := Vector2(slick.position.x, slick.position.z)
		if current.distance_to(center) <= SLICK_RECYCLE_DISTANCE or \
				not _outside_boat_view(current) or not _outside_camera_view(current):
			continue
		_stream_cursor = (index + 1) % slicks.size()
		for attempt in range(24):
			var angle := _slick_rng.randf_range(-PI, PI)
			var direction := Vector2.from_angle(angle)
			if attempt < 12 and boat.speed > 0.5 and direction.dot(forward) < -0.15:
				continue
			var distance := _slick_rng.randf_range(SLICK_SPAWN_MIN, SLICK_SPAWN_MAX)
			var candidate := center + direction * distance
			if not _outside_boat_view(candidate) or not _outside_camera_view(candidate) or \
					coast.water_depth(candidate.x, candidate.y) < 3.0:
				continue
			var clear := true
			for other in slicks:
				if other == slick or other.depleted:
					continue
				if candidate.distance_to(Vector2(other.position.x, other.position.z)) < 9.0:
					clear = false
					break
			if clear:
				slick.relocate_smoothly(Vector3(candidate.x,
					water.surface_height(candidate.x, candidate.y) + ResourceSlick.FLOAT_HEIGHT, candidate.y))
				break
		break


func nearest_resource(at: Vector3, radius: float) -> ResourceSlick:
	var candidate: ResourceSlick = null
	var closest := radius * radius
	for slick in slicks:
		if slick.depleted:
			continue
		var distance := Vector2(at.x, at.z).distance_squared_to(Vector2(slick.position.x, slick.position.z))
		if distance < closest:
			closest = distance
			candidate = slick
	return candidate


func receive_resource(kind: int) -> void:
	raw[kind] += 1
	announce("СОБРАНО: %s" % ResourceSlick.NAMES[kind].to_upper())


func total_refined() -> int:
	var sum := 0
	for count in refined:
		sum += count
	return sum


func refine() -> int:
	var needed := 2 if (boat != null and boat.has_trailer) else 3
	var produced := 0
	for i in range(raw.size()):
		var batches := int(raw[i] / float(needed))
		raw[i] -= batches * needed
		refined[i] += batches
		produced += batches
	if produced > 0 and boat != null:
		boat.trigger_refine_effect()
	announce("ПЕРЕРАБОТАНО: %d" % produced if produced > 0 else ("НУЖНО %d ПЯТНА ОДНОГО ЦВЕТА" % needed))
	return produced


func buy_trailer() -> void:
	if boat == null:
		return
	if boat.has_trailer:
		announce("ПЛАШКОУТ УЖЕ НА БУКСИРЕ")
		return
	if total_refined() < TRAILER_COST:
		announce("ДЛЯ ПЛАШКОУТА НУЖНО 2 ГОТ. МАТЕРИАЛА (ИЛИ НАЖМИТЕ T ДЛЯ ТЕСТА)")
		return
	var remaining := TRAILER_COST
	for i in range(refined.size()):
		var take := mini(refined[i], remaining)
		refined[i] -= take
		remaining -= take
		if remaining <= 0:
			break
	boat.set_trailer_enabled(true)
	announce("ПЛАШКОУТ: АВТОСБОР У ОБОИХ БОРТОВ, +СКОРОСТЬ, ПЕРЕРАБОТКА 2→1")


func toggle_trailer_free() -> void:
	if boat == null:
		return
	boat.set_trailer_enabled(not boat.has_trailer)
	announce("БУКСИРУЕМЫЙ ПЛАШКОУТ: %s" % ("ПРИСТЫКОВАН" if boat.has_trailer else "ОТСТЫКОВАН"))


# ---------------------------------------------------------------------------
# Игровые механики: Маяки и Активные умения 4 пигментов
# ---------------------------------------------------------------------------

## Тратит 1 готовый ресурс kind (или 1 Орхидею-катализатор, или 2 сырья этого типа)
func _consume_pigment_charge(kind: int) -> bool:
	if refined[kind] > 0:
		refined[kind] -= 1
		return true
	if raw[kind] >= 2:
		raw[kind] -= 2
		return true
	if refined[3] > 0: # Орхидея как универсальный катализатор
		refined[3] -= 1
		return true
	return false


## [1] БИРЮЗА — Гидроакустический сонар и пеленг Маяков
func activate_sonar() -> void:
	if not _consume_pigment_charge(0):
		announce("ДЛЯ СОНАРА НУЖНА 1 ГОТ. БИРЮЗА (ИЛИ 2 СЫР. БИРЮЗЫ)")
		return
	sonar_timer = 20.0
	if water != null and water.field != null and boat != null:
		water.field.splash(Vector2(boat.global_position.x, boat.global_position.z), 2.0)
	announce("ГИДРОЛОКАТОР АКТИВЕН: ПЕЛЕНГ НА МАЯКИ И ПЯТНА (20 С)")


## [2] КОРАЛЛ — Аварийный ремонт обшивки корпуса
func activate_hull_repair() -> void:
	if boat == null:
		return
	if boat.hull_hp >= 99.5:
		announce("КОРПУС СУДНА В ПОЛНОМ ПОРЯДКЕ (100%)")
		return
	if not _consume_pigment_charge(1):
		announce("ДЛЯ РЕМОНТА НУЖЕН 1 ГОТ. КОРАЛЛ (ИЛИ 2 СЫР. КОРАЛЛА)")
		return
	boat.hull_hp = minf(100.0, boat.hull_hp + 45.0)
	boat.trigger_refine_effect()
	announce("ОБШИВКА ОТРЕМОНТИРОВАНА: КОРПУС %d%%" % int(round(boat.hull_hp)))


## [3] ЯНТАРЬ — Форсаж реактора и прожектора + откат сумерек
func activate_overdrive() -> void:
	if not _consume_pigment_charge(2):
		announce("ДЛЯ ФОРСАЖА НУЖЕН 1 ГОТ. ЯНТАРЬ (ИЛИ 2 СЫР. ЯНТАРЯ)")
		return
	overdrive_timer = 16.0
	# Форсаж усиливает только судно, но не отматывает время суток назад.
	if boat != null:
		boat.update_night_lights(night01, true)
		boat.trigger_refine_effect()
	announce("ЯНТАРНЫЙ ФОРСАЖ: +35% ХОДА И ДАЛЬНИЙ СВЕТ ПРОЖЕКТОРА!")


func lit_beacon_count() -> int:
	var c := 0
	for b in beacons:
		if b["lit"]:
			c += 1
	return c


## Ближайший причальный буй Маяка (в пределах DOCK_RANGE)
func nearby_dock_beacon() -> Dictionary:
	if boat == null:
		return {}
	var boat_xz := Vector2(boat.global_position.x, boat.global_position.z)
	for b in beacons:
		var bp: Vector3 = b["buoy_pos"]
		if boat_xz.distance_to(Vector2(bp.x, bp.z)) <= DOCK_RANGE:
			return b
	return {}


## Следующий незажжённый Маяк для стрелки компаса
func next_unlit_beacon() -> Dictionary:
	if boat == null:
		return {}
	var boat_xz := Vector2(boat.global_position.x, boat.global_position.z)
	var best: Dictionary = {}
	var best_d := 1e9
	for b in beacons:
		if b["lit"]:
			continue
		var bp: Vector3 = b["buoy_pos"]
		var d := boat_xz.distance_to(Vector2(bp.x, bp.z))
		if d < best_d:
			best_d = d
			best = b
	return best


func format_beacon_recipe(cost: PackedInt32Array) -> String:
	var parts: Array[String] = []
	for i in range(cost.size()):
		if cost[i] > 0:
			parts.append("%d %s" % [cost[i], ResourceSlick.NAMES[i]])
	return " + ".join(parts)


## [E] Зажечь Маяк или отремонтироваться у зажжённого Маяка
func interact_with_beacon() -> void:
	var b := nearby_dock_beacon()
	if b.is_empty():
		var target_b := next_unlit_beacon()
		if not target_b.is_empty():
			var bp: Vector3 = target_b["buoy_pos"]
			var dist := int(round(Vector2(boat.global_position.x, boat.global_position.z).distance_to(Vector2(bp.x, bp.z))))
			announce("ДО БУЯ «%s» %d М. [E] РАБОТАЕТ В ПРЕДЕЛАХ 14 М; %d СЫРЬЯ = 1 ГОТОВЫЙ" % [target_b["name"].to_upper(), dist, 2 if boat.has_trailer else 3])
		return

	if b["lit"]:
		if boat != null and boat.hull_hp < 100.0:
			boat.hull_hp = 100.0
			announce("МАЯК «%s»: КОРПУС ПОЛНОСТЬЮ ВОССТАНОВЛЕН" % b["name"].to_upper())
		else:
			announce("МАЯК «%s» УЖЕ СВЕТИТ В ПОЛНУЮ СИЛУ" % b["name"].to_upper())
		return

	var cost: PackedInt32Array = b["cost"]
	var needed := 2 if boat.has_trailer else 3
	# E принимает как готовый материал, так и достаточно сырья. Сначала
	# проверяем ВЕСЬ рецепт: при нехватке ничего не списываем.
	for i in range(cost.size()):
		var available := refined[i] + int(raw[i] / float(needed))
		if available < cost[i]:
			announce("МАЯК: НУЖНО %d %s (ЕСТЬ %d ГОТ. И %d СЫР.; %d СЫР. = 1 ГОТ.)" % [
				cost[i], ResourceSlick.NAMES[i].to_upper(), refined[i], raw[i], needed])
			return

	for i in range(cost.size()):
		var missing := maxi(0, cost[i] - refined[i])
		raw[i] -= missing * needed
		refined[i] += missing
		refined[i] -= cost[i]

	b["lit"] = true
	var col: Color = b["color"]
	var l_mat: StandardMaterial3D = b["lantern_mat"]
	l_mat.albedo_color = col
	l_mat.emission_enabled = true
	l_mat.emission = col
	l_mat.emission_energy_multiplier = 3.2

	var b_mat: StandardMaterial3D = b["buoy_lamp_mat"]
	b_mat.albedo_color = Color("52f29c")
	b_mat.emission = Color("52f29c")

	var top_l: OmniLight3D = b["top_light"]
	top_l.light_energy = 1.4
	var spot_l: SpotLight3D = b["spot"]
	spot_l.light_energy = 1.8

	if boat != null:
		boat.hull_hp = 100.0
		boat.trigger_refine_effect()
	# Свет локального маяка и указатели видны в тумане, но ночь и всё
	# освещение мира НЕ становятся светлее при нажатии [E].
	sonar_timer = maxf(sonar_timer, 15.0)

	if lit_beacon_count() >= beacons.size():
		all_beacons_lit = true
		announce("ВСЕ МАЯКИ ЗАЖЖЕНЫ! БЕРЕГ ОЗАРЁН СВЕТОМ — ПОБЕДА!")
	else:
		announce("ЗАЖЖЁН МАЯК «%s»! (%d / %d)" % [b["name"].to_upper(), lit_beacon_count(), beacons.size()])


func announce(text: String) -> void:
	notice = text
	notice_time = 6.0


func debug_grant_materials() -> void:
	# Одно нажатие покрывает суммарные рецепты всех трёх маяков.
	for i in range(refined.size()):
		refined[i] += 3
	announce("ТЕСТ: +3 ГОТОВЫХ ПИГМЕНТА КАЖДОГО ЦВЕТА")


func debug_cycle_night() -> void:
	_debug_night_step = (_debug_night_step + 1) % 3
	debug_night_paused = true
	var presets := PackedFloat32Array([0.0, 0.45, 0.88])
	_apply_atmosphere(presets[_debug_night_step])
	announce("ТЕСТ: ВРЕМЯ СУТОК %d%% (ЗАФИКСИРОВАНО; [7] — ПРОДОЛЖИТЬ)" % int(round(night01 * 100.0)))


func debug_toggle_lighting() -> void:
	debug_lighting_profile = not debug_lighting_profile
	world.set_boat_tonemapper(debug_lighting_profile)
	announce("ТЕСТ: ТОЛЬКО ТОНМАППЕР %s (ОСТАЛЬНОЕ НЕИЗМЕННО)" % (
		"AgX" if debug_lighting_profile else "Filmic"))


func debug_toggle_slick_parallax() -> void:
	debug_slick_parallax = not debug_slick_parallax
	for slick in slicks:
		slick.set_parallax_enabled(debug_slick_parallax)
	announce("[P] ПАРАЛЛАКС ПИГМЕНТА: %s" % ("ВКЛ" if debug_slick_parallax else "ВЫКЛ"))


func debug_toggle_wave_lighting() -> void:
	var current := float(water.material().get_shader_parameter("swell_light_detail"))
	var enabled := current < 0.01
	water.set_param("swell_light_detail", 0.65 if enabled else 0.0)
	announce("[K] ГЛИТТЕР НА ГРЕБНЯХ: %s" % ("НОВЫЙ" if enabled else "ПРЕЖНИЙ"))


func debug_toggle_headlight() -> void:
	debug_headlight_enabled = not debug_headlight_enabled
	boat._bow_spot.visible = debug_headlight_enabled
	announce("ТЕСТ: НОСОВОЙ ПРОЖЕКТОР %s" % ("ВКЛ" if debug_headlight_enabled else "ВЫКЛ"))


func _setup_retro_debug() -> void:
	var layer := CanvasLayer.new()
	layer.name = "RetroDebugLayer"
	layer.layer = 11 # Мир — ниже; HUD (слой 12) — поверх эффекта.
	add_child(layer)
	_retro_rect = ColorRect.new()
	_retro_rect.name = "RetroDebugPostprocess"
	_retro_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/boat_retro_debug.gdshader")
	_retro_rect.material = material
	_retro_rect.visible = false
	layer.add_child(_retro_rect)
	# CanvasLayer не является Control-контейнером: явный размер надёжнее
	# preset до add_child(), который ранее мог оставить ColorRect нулевым.
	_sync_retro_rect()
	get_viewport().size_changed.connect(_sync_retro_rect)


func _sync_retro_rect() -> void:
	_retro_rect.position = Vector2.ZERO
	_retro_rect.size = get_viewport().get_visible_rect().size


func debug_toggle_retro() -> void:
	debug_retro_enabled = not debug_retro_enabled
	_retro_rect.visible = debug_retro_enabled
	print("RETRO DEBUG: visible=", _retro_rect.visible, " rect=", _retro_rect.size,
		" viewport=", get_viewport().get_visible_rect().size)
	announce("ТЕСТ: FEARS TO FATHOM %s (БЕЗ ВИНЬЕТКИ И ПОЛОС)" % (
		"ВКЛ" if debug_retro_enabled else "ВЫКЛ"))


## RME4-слой воздуха. Это штатная часть сцены, поэтому объём создаётся
## в _ready(): без него в Forward+ не рисуется вообще ничего, и шейдер
## даже не компилируется.
##
## BOX остаётся высоким (60 м); рабочий низкий слой ограничен y <= 2.6 м.
## Прошлая версия брала бокс 18 м толщиной и гасила край через
## smoothstep(0, 18, -SDF) — при такой геометрии «край» наступал ровно
## там, где плотность максимальна, и срезал её почти в ноль. Теперь
## по вертикали форму держит height_mask в шейдере, а edgefade работает
## только по горизонтальным стенкам в 160 м от лодки.
func _setup_rme4_atmosphere() -> void:
	if RenderingServer.get_rendering_device() == null:
		# Compatibility: объёмного тумана нет, мир живёт на дымке материалов.
		debug_rme4_enabled = false
		return
	_rme4_volume = FogVolume.new()
	_rme4_volume.name = "RME4SeaAtmosphere"
	_rme4_volume.shape = RenderingServer.FOG_VOLUME_SHAPE_BOX
	_rme4_volume.size = RME4_BOX_SIZE
	_rme4_material = ShaderMaterial.new()
	_rme4_material.shader = preload("res://shaders/boat_rme4_fog.gdshader")
	_rme4_material.set_shader_parameter("mystery_profile",
		1.0 if debug_mystery_atmosphere else 0.0)
	_rme4_material.set_shader_parameter("density_noise",
		world._noise_3d(RME4_NOISE_PX, 137, 0.085, FastNoiseLite.TYPE_SIMPLEX_SMOOTH))
	_rme4_volume.material = _rme4_material
	add_child(_rme4_volume)
	_rme4_volume.global_position = Vector3(boat.global_position.x, RME4_BOX_Y,
		boat.global_position.z)
	_rme4_volume.visible = debug_rme4_enabled
	print("RME4: слой воздуха ", RME4_BOX_SIZE, " центр y=", RME4_BOX_Y,
		" noise=", RME4_NOISE_PX, "^3")


## [U]: штатная атмосфера -> сплошной Environment -> тест FogVolume -> штатная.
## Это диагностика РЕНДЕРА, а не ещё один художественный профиль тумана.
func debug_cycle_fog_diagnostic() -> void:
	if RenderingServer.get_rendering_device() == null:
		announce("[U] ОБЪЁМНЫЙ ПРОХОД НЕДОСТУПЕН: НУЖЕН FORWARD+")
		return
	if debug_fog_diagnostic == 0:
		_fog_diagnostic_saved_enabled = world._env.volumetric_fog_enabled
		_fog_diagnostic_saved_emission = world._env.volumetric_fog_emission
		_fog_diagnostic_saved_emission_energy = world._env.volumetric_fog_emission_energy
	debug_fog_diagnostic = (debug_fog_diagnostic + 1) % 3
	if debug_fog_diagnostic == 0:
		world._env.volumetric_fog_emission = _fog_diagnostic_saved_emission
		world._env.volumetric_fog_emission_energy = _fog_diagnostic_saved_emission_energy
		world._env.volumetric_fog_enabled = _fog_diagnostic_saved_enabled
		if _rme4_material != null:
			_rme4_material.set_shader_parameter("diagnostic_volume", false)
		if _rme4_volume != null:
			_rme4_volume.visible = debug_rme4_enabled
		_apply_atmosphere(night01)
		announce("[U] ШТАТНАЯ АТМОСФЕРА ВОССТАНОВЛЕНА")
	else:
		_apply_fog_diagnostic()
		announce("[U] ТЕСТ %d: %s" % [debug_fog_diagnostic,
			"ЯНТАРНЫЙ GLOBAL FOG" if debug_fog_diagnostic == 1 else "ГОЛУБОЙ FOGVOLUME"])
	print("FOG DIAGNOSTIC: stage=", debug_fog_diagnostic,
		" renderer=", RenderingServer.get_current_rendering_method(),
		" camera=", camera.projection, " volume=", _rme4_volume != null)


func _apply_fog_diagnostic() -> void:
	world._env.volumetric_fog_enabled = true
	var global_test := debug_fog_diagnostic == 1
	world._env.volumetric_fog_density = 0.06 if global_test else 0.0
	world._env.volumetric_fog_emission = Color(0.75, 0.32, 0.04) if global_test else Color.BLACK
	world._env.volumetric_fog_emission_energy = 1.0 if global_test else 0.0
	if _rme4_volume != null:
		_rme4_volume.visible = not global_test
	if _rme4_material != null:
		_rme4_material.set_shader_parameter("diagnostic_volume", not global_test)


## [O] — сравнение формы и собственного свечения одного FogVolume.
func debug_toggle_mystery_atmosphere() -> void:
	# O всегда возвращает рабочую атмосферу, даже если оставлен тест U.
	while debug_fog_diagnostic != 0:
		debug_cycle_fog_diagnostic()
	if _rme4_material == null:
		announce("[O] ОБЪЁМНЫЙ ПРОФИЛЬ НЕДОСТУПЕН: НУЖЕН FORWARD+")
		return
	debug_mystery_atmosphere = not debug_mystery_atmosphere
	_rme4_material.set_shader_parameter("mystery_profile",
		1.0 if debug_mystery_atmosphere else 0.0)
	announce("[O] ТУМАН: %s" % (
		"НИЗКИЙ ТУМАН" if debug_mystery_atmosphere else "ПРЕЖНИЙ ВЫСОКИЙ СЛОЙ"))


func debug_toggle_headlight_shadows() -> void:
	if RenderingServer.get_rendering_device() == null:
		announce("[Y] СРАВНЕНИЕ ОБЪЁМНЫХ ТЕНЕЙ ТРЕБУЕТ FORWARD+")
		return
	boat._bow_spot.shadow_enabled = not boat._bow_spot.shadow_enabled
	announce("[Y] ТЕНИ ПРОЖЕКТОРА: %s (СРАВНИТЕ FPS)" % (
		"ВКЛ" if boat._bow_spot.shadow_enabled else "ВЫКЛ"))


## [J] — A/B воздуха: RME4-слой против ровной глобальной дымки.
## Плотности переключает apply_boat_atmosphere(), поэтому здесь только
## видимость: никаких «сохранить/восстановить» состояний, которые могли
## бы разойтись с профилем ночи.
func debug_toggle_rme4_fog() -> void:
	if debug_fog_diagnostic != 0:
		announce("СНАЧАЛА ВЫЙДИТЕ ИЗ ТЕСТА ТУМАНА КЛАВИШЕЙ [U]")
		return
	if _rme4_volume == null:
		announce("ТЕСТ: RME4-ОБЪЁМ НЕДОСТУПЕН В COMPATIBILITY (НУЖЕН FORWARD+)")
		return
	debug_rme4_enabled = not debug_rme4_enabled
	_rme4_volume.visible = debug_rme4_enabled
	_apply_atmosphere(night01)
	announce("ТЕСТ: RME4-АТМОСФЕРА %s" % ("ВКЛ" if debug_rme4_enabled \
		else "ВЫКЛ (РОВНАЯ ГЛОБАЛЬНАЯ ДЫМКА)"))


## [G] — весь volumetric-проход Forward+ целиком. Это отдельная ось A/B от
## [J]: [J] меняет источник плотности (RME4-шум против ровной дымки),
## а [G] выключает сам проход, вместе с FogVolume.
func debug_toggle_volumetric_fog() -> void:
	if debug_fog_diagnostic != 0:
		announce("СНАЧАЛА ВЫЙДИТЕ ИЗ ТЕСТА ТУМАНА КЛАВИШЕЙ [U]")
		return
	world._env.volumetric_fog_enabled = not world._env.volumetric_fog_enabled
	announce("ТЕСТ: ОБЪЁМНЫЙ ТУМАН %s%s (RD: %s)" % [
		"ВКЛ" if world._env.volumetric_fog_enabled else "ВЫКЛ",
		"" if world._env.volumetric_fog_enabled else " — RME4-СЛОЙ ТОЖЕ НЕ ВИДЕН",
		"ДА" if RenderingServer.get_rendering_device() != null else "НЕТ"])


func debug_adjust_fill(change: float) -> void:
	debug_night_fill = clampf(debug_night_fill + change, 0.02, 0.42)
	_apply_atmosphere(night01)
	announce("ТЕСТ: НОЧНОЙ БОКОВОЙ СВЕТ %.2f (БЕЗ ЛУННОЙ ДОРОЖКИ)" % debug_night_fill)


func debug_warp_to_beacon() -> void:
	var target_b := next_unlit_beacon()
	if target_b.is_empty() and not beacons.is_empty():
		target_b = beacons[0]
	if target_b.is_empty() or boat == null:
		return
	var bp: Vector3 = target_b["buoy_pos"]
	var at := Vector3(bp.x - 5.0, water.surface_height(bp.x - 5.0, bp.z) + 0.08, bp.z)
	boat.global_position = at
	boat.speed = 0.0
	boat._reset_trail(Vector2(at.x, at.z))
	if boat.has_trailer:
		boat.set_trailer_enabled(true)
	boat.reset_physics_interpolation()
	_camera_focus = at + Vector3.UP * 0.8
	camera.global_position = _camera_focus + Vector3(21.0, 26.2, 30.0)
	camera.look_at(_camera_focus, Vector3.UP)
	announce("ТЕСТ: У БУЯ «%s» — НАЖМИТЕ [E]" % target_b["name"].to_upper())


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_R:
				refine()
				get_viewport().set_input_as_handled()
			KEY_B:
				buy_trailer()
				get_viewport().set_input_as_handled()
			KEY_T:
				toggle_trailer_free()
				get_viewport().set_input_as_handled()
			KEY_E:
				interact_with_beacon()
				get_viewport().set_input_as_handled()
			KEY_1:
				activate_sonar()
				get_viewport().set_input_as_handled()
			KEY_2:
				activate_hull_repair()
				get_viewport().set_input_as_handled()
			KEY_3:
				activate_overdrive()
				get_viewport().set_input_as_handled()
			# Цифры не перехватываются редактором Godot: F6/F8 заняты
			# запуском/остановкой сцены при игре внутри редактора.
			KEY_0:
				debug_panel_visible = not debug_panel_visible
				get_viewport().set_input_as_handled()
			KEY_4:
				debug_grant_materials()
				get_viewport().set_input_as_handled()
			KEY_5:
				debug_cycle_night()
				get_viewport().set_input_as_handled()
			KEY_6:
				debug_warp_to_beacon()
				get_viewport().set_input_as_handled()
			KEY_7:
				debug_night_paused = false
				announce("ТЕСТ: ВРЕМЯ СУТОК СНОВА ИДЁТ")
				get_viewport().set_input_as_handled()
			KEY_8:
				debug_adjust_fill(-0.04)
				get_viewport().set_input_as_handled()
			KEY_9:
				debug_adjust_fill(0.04)
				get_viewport().set_input_as_handled()
			KEY_L:
				debug_toggle_lighting()
				get_viewport().set_input_as_handled()
			KEY_U:
				debug_cycle_fog_diagnostic()
				get_viewport().set_input_as_handled()
			KEY_O:
				debug_toggle_mystery_atmosphere()
				get_viewport().set_input_as_handled()
			KEY_Y:
				debug_toggle_headlight_shadows()
				get_viewport().set_input_as_handled()
			KEY_P:
				debug_toggle_slick_parallax()
				get_viewport().set_input_as_handled()
			KEY_K:
				debug_toggle_wave_lighting()
				get_viewport().set_input_as_handled()
			KEY_H:
				debug_toggle_headlight()
				get_viewport().set_input_as_handled()
			KEY_G:
				debug_toggle_volumetric_fog()
				get_viewport().set_input_as_handled()
			KEY_V:
				debug_toggle_retro()
				get_viewport().set_input_as_handled()
			KEY_J:
				debug_toggle_rme4_fog()
				get_viewport().set_input_as_handled()
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera.size = maxf(16.0, camera.size - 2.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera.size = minf(42.0, camera.size + 2.0)


func _process(delta: float) -> void:
	if boat == null or camera == null:
		return
	if (debug_rme4_enabled or debug_fog_diagnostic == 2) and _rme4_volume != null:
		_rme4_volume.global_position = Vector3(boat.global_position.x, RME4_BOX_Y,
			boat.global_position.z)
	_beacon_anim_time += delta
	sonar_timer = maxf(0.0, sonar_timer - delta)
	var had_overdrive := overdrive_timer > 0.0
	overdrive_timer = maxf(0.0, overdrive_timer - delta)
	if had_overdrive and overdrive_timer <= 0.0:
		boat.update_night_lights(night01, false)

	# Плавное наступление сумерек (в режиме smoke-теста оставляем яркий день)
	if OS.get_environment("JOURNEY_BOAT_SMOKE") != "1" and not debug_night_paused:
		var night_rate := 0.0015 if all_beacons_lit else (0.0055 - float(lit_beacon_count()) * 0.0012)
		night01 = minf(0.88, night01 + night_rate * delta)
		_atmosphere_timer -= delta
		if _atmosphere_timer <= 0.0:
			_atmosphere_timer = 0.15
			_apply_atmosphere(night01)

	# Качка причальных буёв и вращение лучей зажжённых Маяков
	for b in beacons:
		var bp: Vector3 = b["buoy_pos"]
		var buoy_node: Node3D = b["buoy_node"]
		buoy_node.position.y = water.surface_height(bp.x, bp.z)
		buoy_node.rotation.z = sin(_beacon_anim_time * 2.0 + bp.z * 0.1) * 0.08
		if b["lit"]:
			var pivot: Node3D = b["beam_pivot"]
			pivot.rotation.y += delta * 0.85

	if absf(boat.global_position.x - water.position.x) > 100.0 or \
			absf(boat.global_position.z - water.position.z) > 100.0:
		water.position = Vector3(boat.global_position.x, Coast.SEA_LEVEL,
			boat.global_position.z)

	# Рендерная камера должна следовать рендерной, а не последней тиковой
	# позиции лодки. Иначе при 60 Гц физики и другом FPS видны ступеньки.
	var target := boat.get_global_transform_interpolated().origin + Vector3.UP * 0.8
	_camera_focus = _camera_focus.lerp(target, 1.0 - exp(-4.0 * delta))
	var desired := _camera_focus + Vector3(21.0, 26.2, 30.0)
	# Один фильтр для focus; второй лаг позиции менял угол взгляда камеры
	# при разгоне и поворотах, хотя ракурс должен оставаться изометрическим.
	camera.global_position = desired
	camera.look_at(_camera_focus, Vector3.UP)
	notice_time = maxf(0.0, notice_time - delta)
	_stream_timer -= delta
	if _stream_timer <= 0.0:
		_stream_timer = 0.12
		_stream_resources()
	hud.queue_redraw()
	if OS.get_environment("JOURNEY_BOAT_SHOT") == "1":
		_capture_frames += 1
		var drive_shot := OS.get_environment("JOURNEY_BOAT_SHOT_DRIVE") == "1"
		if drive_shot and _capture_frames == 35:
			Input.action_press("boat_right")
		if drive_shot and _capture_frames == 72:
			Input.action_release("boat_right")
		if _capture_frames == (110 if drive_shot else 35):
			var output := OS.get_environment("JOURNEY_BOAT_SHOT_PATH")
			if output.is_empty():
				output = "user://boat.png"
			var err := get_viewport().get_texture().get_image().save_png(output)
			print("[BOAT] screenshot %s (%d)" % [output, err])
			get_tree().quit(0 if err == OK else 1)


func _ensure_boat_input() -> void:
	_add_action("boat_forward", [KEY_W, KEY_UP])
	_add_action("boat_reverse", [KEY_S, KEY_DOWN])
	_add_action("boat_left", [KEY_A, KEY_LEFT])
	_add_action("boat_right", [KEY_D, KEY_RIGHT])
	_add_action("boat_pump", [KEY_SPACE])


func _add_action(action: String, keys: Array) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	for key in keys:
		var input := InputEventKey.new()
		input.physical_keycode = key
		InputMap.action_add_event(action, input)
