# Ревью №2: актуальный прототип «Приливная лаборатория»

**Срез кода:** [`493c20ed016c`](https://github.com/Narine545/Journey-clon/commit/493c20ed016ca3ba2c95f3183b759ebdbb4da476) в ветке `arena/c0cfd826-journey-clon`. Документ является **текстовой копией текущих исходников** в конце файла; старый `boat-code-review.md` — исторический вариант, его не стоит применять поверх этого кода. Здесь нет бинарных файлов, архивов и артефактов сборки. Для запуска нужен весь репозиторий, поскольку исходники ниже используют общие классы береговой/песчаной сцены.

## Что уже сделано

- Godot **4.7.2 / Forward+**. Главная сцена `scenes/boat_main.tscn` собирает лодку с видимой наружной каютой, песчаный берег, море, четыре вида ресурсных пятен и изометрическую ортографическую камеру. Рыбалка остаётся отдельной сценой `scenes/main.tscn`.
- Лодка: ускорение/задний ход/поворот, пяти-точечная плавучесть (высота, крен, дифферент), кильватер из **20 мировых точек** с историей около 5 секунд. При повороте старый след остаётся на месте; после телепортации история сбрасывается. Насос работает только с левого борта и при небольшой скорости.
- Вода **только для лодки** использует отдельный шейдер и три аналитические глубоководные волны с дисперсией `ω² = gk`. Вершины моря, CPU-высота для плавучести и сетчатые вершины пятен используют согласованные формулы. Рябь, блики и пена — визуальные приближения, **это не расчёт Navier–Stokes**. Синусоидальные «песчаные» микрополосы в лодочной воде заменены шумовой рябью. За картой морского дна шейдер подставляет глубокую воду; плотная сетка периодически переносится вслед за лодкой.
- Ресурсы: четыре цвета; отдельные SDF-пятна на поверхности; собранное пятно истощается и возвращается через ~35 с. Невидимые для камеры пятна переиспользуются в новом районе, не более одного за тик. Вода и пятна имеют явный порядок прозрачной отрисовки. Условия видимости в движении лучше проверять визуально: headless-smoke не проверяет пиксели.
- Переработка: обычно **3 сырья одного цвета → 1 готовый материал**, с прицепом **2 → 1**. Прицеп покупается за 2 готовых материала, повышает максимальную скорость и эффективность насоса; `T` включает/отключает его бесплатно для сравнения. Четыре бака на палубе имеют цветные заполнители; HUD показывает числа сырья и готового материала и прогресс до следующей переработки.
- Прицеп следует за кормой и качается на воде. При заднем ходе и повороте используется **кинематическое ограничение расстояния между корпусами** с проверкой глубины; если оттолкнуть прицеп в сторону нельзя, лодка останавливается. Это не полноценная система столкновений `RigidBody3D`.
- Виньетка удалена. Перспективная рыбалка и лодочная вода используют разные шейдеры; песчаный материал лодки использует ортографическую настройку глиттера без концентрического LOD.

## Управление

| Ввод | Действие |
| --- | --- |
| `W` / `S` | вперёд / задний ход |
| `A` / `D` | руление |
| Удерживать `Пробел` | насос при подходе левым бортом, на малой скорости |
| `R` | переработать сырьё |
| `B` | купить буксируемый плашкоут за два готовых материала |
| `T` | тестовое бесплатное пристыковывание/отстыковывание |
| Колесо мыши | масштаб камеры |

## Где искать логику

| Путь | Ответственность |
| --- | --- |
| `scripts/boat_main.gd` | сборка сцены, экономика, пул/переселение пятен, камера и ввод |
| `scripts/boat_vessel.gd` | геометрия, движение, плавучесть, насос, история следа, прицеп и его ограничение |
| `scripts/boat_hud.gd` | показания ресурсов, прогресс переработки и подсказки |
| `scripts/resource_slick.gd`, `shaders/resource_slick.gdshader` | жизненный цикл и вид ресурсных пятен |
| `scripts/water_surface.gd`, `scripts/water_field.gd` | геометрия воды, CPU-высота, волновые события и GPU-uniforms |
| `shaders/boat_wave_spectrum.gdshaderinc`, `shaders/water_boat.gdshader` | спектр, визуальная вода, мировая история кильватера |
| `scripts/boat_smoke.gd` | headless-проверки механик без проверки картинки |

**Дополнительные текстовые зависимости (не дублируются ниже):** [`scripts/coast.gd`](https://github.com/Narine545/Journey-clon/blob/493c20ed016ca3ba2c95f3183b759ebdbb4da476/scripts/coast.gd), [`scripts/sand_field.gd`](https://github.com/Narine545/Journey-clon/blob/493c20ed016ca3ba2c95f3183b759ebdbb4da476/scripts/sand_field.gd), [`shaders/sand.gdshader`](https://github.com/Narine545/Journey-clon/blob/493c20ed016ca3ba2c95f3183b759ebdbb4da476/shaders/sand.gdshader), [`scripts/world.gd`](https://github.com/Narine545/Journey-clon/blob/493c20ed016ca3ba2c95f3183b759ebdbb4da476/scripts/world.gd), [`scripts/game.gd`](https://github.com/Narine545/Journey-clon/blob/493c20ed016ca3ba2c95f3183b759ebdbb4da476/scripts/game.gd), [`shaders/sky_plus.gdshader`](https://github.com/Narine545/Journey-clon/blob/493c20ed016ca3ba2c95f3183b759ebdbb4da476/shaders/sky_plus.gdshader), [workflow](https://github.com/Narine545/Journey-clon/blob/493c20ed016ca3ba2c95f3183b759ebdbb4da476/.github/workflows/validate.yml). При переносе в новый проект брать их вместе с исходными сценами, а не копировать только листинг ниже.

## Проверка и известные ограничения

- Предыдущий успешный полный прогон: [GitHub Actions #41820088385](https://github.com/Narine545/Journey-clon/actions/runs/41820088385). **Он относится к более раннему коду.** Последующие правки воды, ресурсов, качки, HUD и прицепа сделаны с `[skip ci]` по просьбе не тратить время на долгие прогоны. **Текущий SHA не прошёл полный CI и Vulkan-проверку; не считать это подтверждённым релизом.**
- При наличии Godot: `godot --headless --path . --import`; `JOURNEY_BOAT_SMOKE=1 godot --headless --path . --quit-after 500`. Для проверки прозрачности пятен/прицепа/производительности нужен запуск сцены на реальном рендерере Forward+ и визуальный просмотр; headless не выявляет такие дефекты.
- Лимита вместимости баков и сохранения экономики пока нет. Шкала HUD — **не ёмкость**, а прогресс до очередной переработки.
- Прицеп проверяется упрощённой окружностью в плоскости XZ и глубиной воды; настоящие физические коллайдеры корпуса, троса и прицепа отсутствуют. Рекомендуется испытать задний ход, резкие повороты и упор в мель.
- Следить за частотой кадров: море содержит процедурное освещение, шум и цикл по сегментам следа; обновление пятен распределено по тикам. Измерений FPS для текущего SHA нет.

---

# Актуальные исходники (копии без сокращений)

Все блоки ниже взяты **напрямую из файлов этого коммита**. Заголовок блока — путь для обратного копирования; общие зависимости доступны по ссылкам выше.

## `project.godot`

```ini
; Engine configuration file.
; Лодка и цветные SDF-пятна в исходном песчаном море.
; Старую рыбалку можно запустить отдельно: res://scenes/main.tscn.
; Рендерер жёстко зафиксирован: Forward+ (Vulkan) для объёмного тумана,
; glow и SDF-существ. Ввод создаётся кодом (Game._ensure_input), поэтому
; секции [input] нет — действия живут в одном месте.

config_version=5

[application]

config/name="To The Light"
run/main_scene="res://scenes/boat_main.tscn"
config/features=PackedStringArray("4.7", "Forward Plus")
config/icon="res://icon.svg"

[autoload]

Game="*res://scripts/game.gd"

[display]

window/size/viewport_width=1920
window/size/viewport_height=1080

[editor_plugins]

enabled=PackedStringArray()

[rendering]

renderer/rendering_method="forward_plus"
renderer/rendering_method.mobile="gl_compatibility"
anti_aliasing/quality/msaa_3d=2
textures/vram_compression/import_etc2_astc=true
environment/defaults/default_clear_color=Color(0.35, 0.27, 0.38, 1)
```

## `scenes/boat_main.tscn`

```ini
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/boat_main.gd" id="1_boat"]

[node name="BoatWorld" type="Node3D"]
script = ExtResource("1_boat")
```

## `scripts/boat_main.gd`

```gdscript
class_name BoatMain
extends Node3D
## Первый самостоятельный игровой срез. Старая рыбалка сохранена в main.tscn.

const START_Z := Coast.SPAWN_Z
const START_SEAWARD := 95.0
# Переставляем только ушедшие за кадр пятна, чтобы в движении не было
# многосекундной пустоты между видимой областью и дальним кольцом спавна.
const SLICK_RECYCLE_DISTANCE := 60.0
const SLICK_SPAWN_MIN := 38.0
const SLICK_SPAWN_MAX := 57.0
const TRAILER_COST := 2

var game: GameState
var world: GameWorld
var coast: Coast
var sand: SandField
var water: WaterSurface
var boat: BoatVessel
var camera: Camera3D
var hud: BoatHud
var slicks: Array[ResourceSlick] = []
var raw := PackedInt32Array([0, 0, 0, 0])
var refined := PackedInt32Array([0, 0, 0, 0])
var notice := ""
var notice_time := 0.0
var _capture_frames := 0
var _camera_focus := Vector3.ZERO
var _stream_timer := 0.0
var _stream_cursor := 0
var _slick_rng := RandomNumberGenerator.new()


func _ready() -> void:
	game = get_node("/root/Game") as GameState
	world = GameWorld.new()
	add_child(world)
	world.setup(game)
	coast = Coast.new()
	add_child(coast)
	coast.setup(game)
	sand = SandField.new()
	add_child(sand)
	sand.setup(game)
	coast.attach_sand(sand)
	# Песок под ортографической камерой не должен менять LOD кругами
	# вокруг её положения; режим рыбалки остаётся перспективным.
	coast.set_sand("orthographic_glitter", 1.0)
	water = WaterSurface.new()
	water.shader_path = "res://shaders/water_boat.gdshader"
	add_child(water)
	water.setup(game, Vector2(-150.0, 20.0), Coast.SEA_LEVEL)
	# Усиленное волнение и след — только у лодки; рыбалка не меняется.
	water.configure_boat_waves()
	water.set_ground(coast.height_tex, coast.grid_origin, coast.grid_cell, coast.grid_n, coast)
	game.water = water
	boat = BoatVessel.new()
	boat.name = "Vessel"
	add_child(boat)
	boat.global_position = Vector3(coast.shore_x(START_Z) - START_SEAWARD, 0.2, START_Z)
	boat.setup(self, water, coast)
	# Для CI снимок с буксируемым плашкоутом; в игре он покупается отдельно.
	if OS.get_environment("JOURNEY_BOAT_SHOT_TRAILER") == "1":
		boat.set_trailer_enabled(true)
	_build_resources()
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
	_ensure_boat_input()
	if OS.get_environment("JOURNEY_BOAT_SHOT_DRIVE") == "1":
		Input.action_press("boat_forward")
	world.apply_night01(0.0)
	coast.set_night01(0.0)
	water.apply_night01(0.0)
	var sun := Vector3(-0.36, 0.76, -0.54).normalized()
	game.sun_dir = sun
	world.apply_sun(sun)
	coast.apply_sun(sun)
	water.apply_sun(sun)
	water.set_param("water_shallow", Color("49a9a2"))
	water.set_param("water_mid", Color("258b91"))
	water.set_param("water_deep", Color("0f5668"))
	water.set_param("horizon_col", Color("6996a0"))
	water.set_param("sky_col", Color("447084"))
	# 18/9.5/4.5-метровые дисперсионные волны; мелкая рябь лишь дополняет их.
	water.set_param("mega_amp", 0.25)
	water.set_param("ripple_strength", 0.10)
	# Вернуть искры на ровно освещённую воду, без экранной «линзы» и LOD-колец.
	water.set_param("glitter_amount", 0.32)
	water.set_param("sun_path_amount", 0.09)
	water.set_param("direct_specular_amount", 0.018)
	if OS.get_environment("JOURNEY_BOAT_SMOKE") == "1":
		var test := BoatSmoke.new()
		add_child(test)
		test.setup(self)


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
	# Проверяем прогнозируемый кадр вокруг лодки, а не догоняющую камеру:
	# при резком манёвре и тестовом переносе камеры эти центры различаются.
	var relative := Vector3(at.x - boat.global_position.x, 0.0,
		at.y - boat.global_position.z)
	var viewport_size := get_viewport().get_visible_rect().size
	var half_height := camera.size * 0.5 + 4.0 # запас на радиус пятна
	var half_width := camera.size * 0.5 * viewport_size.x / maxf(viewport_size.y, 1.0) + 4.0
	return absf(relative.dot(camera.global_transform.basis.x)) > half_width or \
		absf(relative.dot(camera.global_transform.basis.y)) > half_height


func _outside_camera_view(at: Vector2) -> bool:
	# Дополнительно учитываем реальный кадр: камера с инерцией может
	# отставать от лодки, и пятно нельзя переносить на глазах игрока.
	var screen_pos := camera.unproject_position(Vector3(at.x, Coast.SEA_LEVEL, at.y))
	var viewport_size := get_viewport().get_visible_rect().size
	return not Rect2(Vector2(-64.0, -64.0),
		viewport_size + Vector2(128.0, 128.0)).has_point(screen_pos)


func _stream_resources() -> void:
	var center := Vector2(boat.global_position.x, boat.global_position.z)
	var forward := Vector2(-boat.global_transform.basis.z.x,
		-boat.global_transform.basis.z.z)
	# Не переселять сразу все 12 пятен в один кадр: каждые полсекунды
	# такой пакет блокировал главный поток и дёргал движение лодки.
	for offset in range(slicks.size()):
		var index := (_stream_cursor + offset) % slicks.size()
		var slick := slicks[index]
		if slick.depleted:
			continue
		var current := Vector2(slick.position.x, slick.position.z)
		# Не трогаем видимые пятна, даже если камера сильно отстала.
		if current.distance_to(center) <= SLICK_RECYCLE_DISTANCE or \
				not _outside_boat_view(current) or not _outside_camera_view(current):
			continue
		_stream_cursor = (index + 1) % slicks.size()
		for attempt in range(24):
			var angle := _slick_rng.randf_range(-PI, PI)
			var direction := Vector2.from_angle(angle)
			# Первые попытки — в сторону движения, чтобы пятна не оставались
			# только позади. Запасные попытки допускают любую сторону у берега.
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
		break # одно пятно за тик, даже если подходящее место не нашлось


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
	announce("ПРИСТЫКОВАН БУКСИРУЕМЫЙ ПЛАШКОУТ! (+СКОРОСТЬ, ПЕРЕРАБОТКА 2→1)")


func toggle_trailer_free() -> void:
	if boat == null:
		return
	boat.set_trailer_enabled(not boat.has_trailer)
	announce("БУКСИРУЕМЫЙ ПЛАШКОУТ: %s" % ("ПРИСТЫКОВАН" if boat.has_trailer else "ОТСТЫКОВАН"))


func announce(text: String) -> void:
	notice = text
	notice_time = 2.8


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_R:
			refine()
			get_viewport().set_input_as_handled()
		elif event.physical_keycode == KEY_B:
			buy_trailer()
			get_viewport().set_input_as_handled()
		elif event.physical_keycode == KEY_T:
			toggle_trailer_free()
			get_viewport().set_input_as_handled()
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera.size = maxf(16.0, camera.size - 2.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera.size = minf(42.0, camera.size + 2.0)


func _process(delta: float) -> void:
	if boat == null or camera == null:
		return
	# Плотная сетка моря конечна (±310 м). Переставляем её редкими
	# шагами вдали от экрана, чтобы лодка не выходила на разреженные
	# дальние треугольники. Шейдер и физика используют МИРОВЫЕ координаты.
	if absf(boat.global_position.x - water.position.x) > 100.0 or \
			absf(boat.global_position.z - water.position.z) > 100.0:
		water.position = Vector3(boat.global_position.x, Coast.SEA_LEVEL,
			boat.global_position.z)
	# Не наводить объектив на дискретную физическую высоту корпуса:
	# при переменном FPS это выглядело как внезапный рывок лодки в кадре.
	var target := boat.global_position + Vector3.UP * 0.8
	_camera_focus = _camera_focus.lerp(target, 1.0 - exp(-4.0 * delta))
	var desired := _camera_focus + Vector3(21.0, 26.2, 30.0)
	camera.global_position = camera.global_position.lerp(desired, 1.0 - exp(-3.0 * delta))
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
```

## `scripts/boat_vessel.gd`

```gdscript
class_name BoatVessel
extends Node3D
## Малое научно-исследовательское судно («Приливная лаборатория»).
## Выверенная геометрия корпуса без выступающих планок на носу,
## насос строго по левому борту и запись мировой траектории кильватерного следа.

const MAX_SPEED := 10.0
const REVERSE_SPEED := 4.0
const ACCELERATION := 3.2
const DRAG := 1.8
const TURN_RATE := 0.95
const PUMP_RANGE := 6.5
const PUMP_SECONDS := 1.4

const START_WITH_TRAILER := false
const TRAILER_DISTANCE := 9.3
# Описанные окружности корпусов: корпус 5.4 м, плашкоут 3.35 м + зазор.
# Кинематический контакт нужен и при заднем ходе, когда трос слабеет.
const TRAILER_CLEARANCE := 9.15
const TRAIL_POINTS := 20
const TRAIL_STEP_TIME := 0.25 # 20 точек сохраняют примерно 5 секунд пути

var main: BoatMain
var water: WaterSurface
var coast: Coast
var speed := 0.0
var has_trailer := false
var wrong_side_target := false

var _pump_progress := 0.0
var _anim_time := 0.0
var _steer_visual := 0.0
var _refine_flash := 0.0

# Физика плавучести и качки
var _heave_vel := 0.0
var _pitch_vel := 0.0
var _roll_vel := 0.0

# Мировая история пути судна для честного изогнутого следа на воде
var _trail_buffer := PackedVector4Array()
var _trail_timer := 0.0
var _last_trail_pos := Vector2.ZERO

var _target: ResourceSlick
var _body: Node3D
var _radar: Node3D
var _rudder: Node3D
var _prop_l: Node3D
var _prop_r: Node3D

# Кран-манипулятор левого борта
var _crane_turret: Node3D
var _crane_boom: Node3D
var _crane_jib: Node3D
var _hose: MeshInstance3D
var _hose_mat: StandardMaterial3D
var _intake_head: MeshInstance3D
var _intake_mat: StandardMaterial3D

var _vat_fills: Array[MeshInstance3D] = []
var _vat_mats: Array[StandardMaterial3D] = []

# Буксируемый плашкоут
var _trailer: Node3D
var _trailer_body: Node3D
var _tow_cable_l: MeshInstance3D
var _tow_cable_r: MeshInstance3D
var _trailer_sight_fills: Array[MeshInstance3D] = []


func setup(boat_main: BoatMain, water_ref: WaterSurface, coast_ref: Coast) -> void:
	main = boat_main
	water = water_ref
	coast = coast_ref
	_trail_buffer.resize(TRAIL_POINTS)
	_reset_trail(Vector2(global_position.x, global_position.z))

	_body = Node3D.new()
	_body.name = "HullAndCabin"
	add_child(_body)
	_build_appearance()
	_build_trailer()
	if START_WITH_TRAILER:
		set_trailer_enabled(true)


func effective_max_speed() -> float:
	return MAX_SPEED + (2.0 if has_trailer else 0.0)


func effective_pump_range() -> float:
	return PUMP_RANGE + (2.5 if has_trailer else 0.0)


func effective_pump_seconds() -> float:
	return PUMP_SECONDS * (0.70 if has_trailer else 1.0)


func set_trailer_enabled(enabled: bool) -> void:
	has_trailer = enabled
	if _trailer != null:
		_trailer.visible = enabled
		var heading := -global_transform.basis.z
		_trailer.global_position = global_position - heading * TRAILER_DISTANCE
		_trailer.global_rotation = Vector3(0.0, rotation.y, 0.0)
	if _tow_cable_l != null:
		_tow_cable_l.visible = enabled
	if _tow_cable_r != null:
		_tow_cable_r.visible = enabled


func trigger_refine_effect() -> void:
	_refine_flash = 1.0


## Проверяет, находится ли пятно со стороны рабочего ЛЕВОГО борта (-X)
func is_on_port_working_side(world_pos: Vector3) -> bool:
	var local := to_local(world_pos)
	return local.x < -0.30 and local.z > -4.8 and local.z < 4.8


func _physics_process(delta: float) -> void:
	if water == null or coast == null:
		return
	_anim_time += delta
	_refine_flash = maxf(0.0, _refine_flash - delta * 1.8)

	var throttle := Input.get_axis("boat_reverse", "boat_forward")
	var steer := Input.get_axis("boat_left", "boat_right")
	_steer_visual = lerpf(_steer_visual, steer, minf(1.0, delta * 5.5))

	var max_spd := effective_max_speed()
	var target_speed := throttle * (max_spd if throttle >= 0.0 else REVERSE_SPEED)
	var prev_speed := speed
	speed = move_toward(speed, target_speed, (ACCELERATION if absf(throttle) > 0.01 else DRAG) * delta)
	var accel_rate := (speed - prev_speed) / maxf(delta, 0.001)

	rotation.y += steer * TURN_RATE * delta * clampf(absf(speed) / 3.5, 0.0, 1.0) * (1.0 if speed >= 0.0 else -1.0)

	var heading := -global_transform.basis.z
	var right := global_transform.basis.x
	var next := global_position + heading * speed * delta
	if coast.water_depth(next.x, next.z) > 1.7:
		# Слабый трос не мешает идти задним ходом: корпус должен толкнуть
		# плашкоут, а не проходить сквозь его геометрию.
		if _make_room_for_trailer(next):
			global_position = next
		else:
			speed = 0.0
	else:
		speed = minf(speed, 0.0)

	# 5-точечный расчёт плавучести (корпус следует за волнами с физической инерцией)
	var bow_pt := global_position + heading * 4.4
	var stern_pt := global_position - heading * 4.4
	var port_pt := global_position - right * 1.55
	var star_pt := global_position + right * 1.55

	var h_center := water.surface_height(global_position.x, global_position.z)
	var h_bow := water.surface_height(bow_pt.x, bow_pt.z)
	var h_stern := water.surface_height(stern_pt.x, stern_pt.z)
	var h_port := water.surface_height(port_pt.x, port_pt.z)
	var h_star := water.surface_height(star_pt.x, star_pt.z)

	var avg_water := (h_center * 2.0 + h_bow + h_stern + h_port + h_star) / 6.0
	var target_y := avg_water + 0.08 - absf(speed) * 0.003
	var y_err := target_y - global_position.y
	_heave_vel = (_heave_vel + y_err * 28.0 * delta) * exp(-5.5 * delta)
	global_position.y += _heave_vel * delta

	var wave_pitch := atan2(h_bow - h_stern, 8.8)
	var dynamic_trim := clampf(speed * 0.004 + accel_rate * 0.007, -0.04, 0.06)
	var pitch_err := (wave_pitch + dynamic_trim) - _body.rotation.x
	_pitch_vel = (_pitch_vel + pitch_err * 30.0 * delta) * exp(-4.8 * delta)
	_body.rotation.x += _pitch_vel * delta

	var wave_roll := atan2(h_star - h_port, 3.1)
	var turn_heel := -_steer_visual * clampf(absf(speed) / MAX_SPEED, 0.0, 1.0) * 0.06
	var roll_err := (wave_roll + turn_heel) - _body.rotation.z
	_roll_vel = (_roll_vel + roll_err * 25.0 * delta) * exp(-4.2 * delta)
	_body.rotation.z += _roll_vel * delta

	# Записываем точки мировой траектории (никаких радиальных кругов поплавка из кормы!)
	_record_world_wake_trail(delta, heading)
	_update_animations(delta)
	_update_pump(delta)
	_update_trailer(delta)
	_sync_water_shader()


func _separate_trailer_from(boat_at: Vector3, trailer_at: Vector3) -> Vector3:
	var gap := Vector2(trailer_at.x - boat_at.x, trailer_at.z - boat_at.z)
	if gap.length_squared() >= TRAILER_CLEARANCE * TRAILER_CLEARANCE:
		return trailer_at
	if gap.length_squared() < 0.0001:
		gap = Vector2(global_transform.basis.z.x, global_transform.basis.z.z)
	gap = gap.normalized() * TRAILER_CLEARANCE
	return Vector3(boat_at.x + gap.x, trailer_at.y, boat_at.z + gap.y)


func _make_room_for_trailer(boat_next: Vector3) -> bool:
	if not has_trailer or _trailer == null:
		return true
	var pushed := _separate_trailer_from(boat_next, _trailer.global_position)
	if pushed.distance_squared_to(_trailer.global_position) < 0.000001:
		return true
	if coast.water_depth(pushed.x, pushed.z) < 1.2:
		return false
	_trailer.global_position = pushed
	return true


func _reset_trail(at: Vector2) -> void:
	_last_trail_pos = at
	_trail_timer = 0.0
	for i in range(TRAIL_POINTS):
		_trail_buffer[i] = Vector4(at.x, at.y, -100.0, 0.0)


func _record_world_wake_trail(delta: float, heading: Vector3) -> void:
	if water == null or water.field == null:
		return
	var now := water.field.t
	var stern_world := global_position - heading * 4.2
	var stern_xz := Vector2(stern_world.x, stern_world.z)
	var moved := stern_xz.distance_to(_last_trail_pos)
	# Телепортация в тестах или резкая смена района не рисует волну через весь мир.
	if moved > 12.0:
		_reset_trail(stern_xz)
		moved = 0.0
	_trail_timer -= delta
	if (_trail_timer <= 0.0 and moved > 0.35) or moved > 2.5:
		_trail_timer = TRAIL_STEP_TIME
		_last_trail_pos = stern_xz
		for i in range(TRAIL_POINTS - 1, 0, -1):
			_trail_buffer[i] = _trail_buffer[i - 1]
	# Точка 0 догоняет текущую корму; остальные остаются в мировых координатах.
	_trail_buffer[0] = Vector4(stern_xz.x, stern_xz.y, now, absf(speed))


func _sync_water_shader() -> void:
	if water == null:
		return
	water.set_param("u_vessel_state", Vector4(global_position.x, global_position.z, rotation.y, speed))
	water.set_param("u_wake_trail", _trail_buffer)
	if has_trailer and _trailer != null:
		water.set_param("u_trailer_state", Vector4(_trailer.global_position.x, _trailer.global_position.z, _trailer.rotation.y, 1.0))
	else:
		water.set_param("u_trailer_state", Vector4(0.0, 0.0, 0.0, 0.0))


func _update_animations(delta: float) -> void:
	if _radar != null:
		_radar.rotation.y += delta * 2.1
	if _rudder != null:
		_rudder.rotation.y = -_steer_visual * 0.48
	var prop_spin := (speed * 2.8 + (0.4 if absf(speed) < 0.2 else 0.0)) * delta
	if _prop_l != null:
		_prop_l.rotation.z += prop_spin
	if _prop_r != null:
		_prop_r.rotation.z -= prop_spin

	if main != null and _vat_fills.size() == 4:
		for i in range(4):
			var amount := float(main.raw[i]) * 0.22 + float(main.refined[i]) * 0.34
			var fill := clampf(0.10 + amount, 0.10, 1.0)
			var mesh_node := _vat_fills[i]
			mesh_node.scale.y = lerpf(mesh_node.scale.y, fill, minf(1.0, delta * 5.0))
			mesh_node.position.y = 1.06 + mesh_node.scale.y * 0.34
			var mat := _vat_mats[i]
			mat.emission_energy_multiplier = 0.35 + fill * 0.85 + _refine_flash * 1.5
			if has_trailer and i < _trailer_sight_fills.size():
				var t_fill := clampf(0.12 + float(main.refined[i]) * 0.28, 0.12, 1.0)
				var tf := _trailer_sight_fills[i]
				tf.scale.y = lerpf(tf.scale.y, t_fill, minf(1.0, delta * 4.0))


func _update_pump(delta: float) -> void:
	var p_range := effective_pump_range()
	var p_secs := effective_pump_seconds()

	_target = null
	wrong_side_target = false
	var any_near := main.nearest_resource(global_position, p_range)
	if any_near != null:
		if is_on_port_working_side(any_near.global_position):
			_target = any_near
		else:
			var best_d2 := p_range * p_range
			for slick in main.slicks:
				if slick.depleted:
					continue
				var d2 := Vector2(global_position.x, global_position.z).distance_squared_to(Vector2(slick.position.x, slick.position.z))
				if d2 < best_d2 and is_on_port_working_side(slick.global_position):
					best_d2 = d2
					_target = slick
			if _target == null:
				wrong_side_target = true

	var drawing := Input.is_action_pressed("boat_pump") and _target != null and absf(speed) < 5.0

	# Башня крана вращается ТОЛЬКО наружу через левый борт (сектор [-2.68 .. -0.36] рад)
	if _crane_turret != null:
		var target_yaw := -0.18
		if _target != null:
			var local_t := _body.to_local(_target.global_position)
			var rel := local_t - _crane_turret.position
			var raw_yaw := atan2(rel.x, rel.z)
			target_yaw = clampf(raw_yaw, -2.68, -0.36)
		_crane_turret.rotation.y = lerp_angle(_crane_turret.rotation.y, target_yaw, minf(1.0, delta * 5.0))

	if _crane_boom != null and _crane_jib != null:
		var boom_pitch := -0.25 if drawing else (0.05 if _target != null else 0.22)
		var jib_pitch := 0.55 if drawing else (0.35 if _target != null else 0.72)
		_crane_boom.rotation.x = lerpf(_crane_boom.rotation.x, boom_pitch, minf(1.0, delta * 5.5))
		_crane_jib.rotation.x = lerpf(_crane_jib.rotation.x, jib_pitch, minf(1.0, delta * 5.5))

	if drawing:
		_pump_progress += delta
		var tip_world := _crane_jib.to_global(Vector3(0.0, -0.12, 1.05))
		var to := _target.global_position + Vector3.UP * 0.10
		var pigment_col := ResourceSlick.COLORS[_target.kind]

		_hose_mat.albedo_color = pigment_col.darkened(0.35)
		_hose_mat.emission = pigment_col
		_hose_mat.emission_energy_multiplier = 0.65 + 0.35 * sin(_anim_time * 10.0)
		_intake_mat.albedo_color = pigment_col.darkened(0.15)
		_intake_mat.emission = pigment_col

		_hose.visible = true
		_hose.global_position = (tip_world + to) * 0.5
		var dir := (to - tip_world).normalized()
		if dir.length_squared() > 0.001:
			_hose.global_basis = Basis(Quaternion(Vector3.UP, dir))
		_hose.scale.y = tip_world.distance_to(to)

		_intake_head.visible = true
		_intake_head.global_position = to
		var pulse_s := 1.0 + 0.10 * sin(_anim_time * 8.0)
		_intake_head.scale = Vector3(pulse_s, 1.0, pulse_s)

		if _pump_progress >= p_secs:
			main.receive_resource(_target.kind)
			_target.collect()
			_pump_progress = 0.0
	else:
		_pump_progress = maxf(0.0, _pump_progress - delta * 2.0)
		_hose.visible = false
		_intake_head.visible = false


func _update_trailer(delta: float) -> void:
	if not has_trailer or _trailer == null or water == null:
		return
	var stern_center := _body.to_global(Vector3(0.0, 0.85, 4.95))
	var trailer_pos := _trailer.global_position
	var to_hitch := stern_center - trailer_pos
	to_hitch.y = 0.0
	var dist := to_hitch.length()
	if dist > 0.001:
		var dir := to_hitch / dist
		var target_yaw := atan2(-dir.x, -dir.z)
		_trailer.rotation.y = lerp_angle(_trailer.rotation.y, target_yaw, minf(1.0, delta * 4.2))
		var pull_dist := 5.65
		if dist > pull_dist:
			var desired_xz := Vector2(stern_center.x, stern_center.z) - Vector2(dir.x, dir.z) * pull_dist
			var next_xz := Vector2(trailer_pos.x, trailer_pos.z).lerp(desired_xz, minf(1.0, delta * 7.5))
			if coast == null or coast.water_depth(next_xz.x, next_xz.y) > 1.2:
				trailer_pos.x = next_xz.x
				trailer_pos.z = next_xz.y

	# Подтягивание тросом на повороте тоже не должно втаскивать прицеп
	# в борт. Если выталкивать его некуда (мель), оставляем прежнее место.
	var separated := _separate_trailer_from(global_position, trailer_pos)
	if coast != null and coast.water_depth(separated.x, separated.z) < 1.2:
		trailer_pos = _trailer.global_position
	else:
		trailer_pos = separated
	var t_surf := water.surface_height(trailer_pos.x, trailer_pos.z)
	trailer_pos.y = lerpf(trailer_pos.y, t_surf + 0.06, minf(1.0, delta * 3.8))
	_trailer.global_position = trailer_pos

	var t_head := -_trailer.global_transform.basis.z
	var t_right := _trailer.global_transform.basis.x
	var t_bow := trailer_pos + t_head * 2.8
	var t_stern := trailer_pos - t_head * 2.8
	var t_port := trailer_pos - t_right * 1.4
	var t_star := trailer_pos + t_right * 1.4
	var t_pitch := atan2(water.surface_height(t_bow.x, t_bow.z) - water.surface_height(t_stern.x, t_stern.z), 5.6)
	var t_roll := atan2(water.surface_height(t_star.x, t_star.z) - water.surface_height(t_port.x, t_port.z), 2.8)
	_trailer_body.rotation.x = lerpf(_trailer_body.rotation.x, t_pitch, minf(1.0, delta * 3.2))
	_trailer_body.rotation.z = lerpf(_trailer_body.rotation.z, t_roll, minf(1.0, delta * 3.2))

	var stern_l := _body.to_global(Vector3(-0.75, 0.92, 4.90))
	var stern_r := _body.to_global(Vector3( 0.75, 0.92, 4.90))
	var bow_l := _trailer_body.to_global(Vector3(-0.65, 0.58, -2.95))
	var bow_r := _trailer_body.to_global(Vector3( 0.65, 0.58, -2.95))
	_place_cable(_tow_cable_l, stern_l, bow_l)
	_place_cable(_tow_cable_r, stern_r, bow_r)


func _place_cable(cable: MeshInstance3D, a: Vector3, b: Vector3) -> void:
	if cable == null:
		return
	cable.global_position = (a + b) * 0.5
	var vec := b - a
	if vec.length_squared() > 0.001:
		cable.global_basis = Basis(Quaternion(Vector3.UP, vec.normalized()))
	cable.scale.y = vec.length()


func pump_fraction() -> float:
	return clampf(_pump_progress / effective_pump_seconds(), 0.0, 1.0)


func target_name() -> String:
	return ResourceSlick.NAMES[_target.kind] if _target != null else ""


# ---------------------------------------------------------------------------
# Инструменты процедурного судостроения
# ---------------------------------------------------------------------------

func _material(color: Color, metal := 0.0, glow := 0.0, rough := 0.68) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = metal
	mat.roughness = rough
	if glow > 0.0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = glow
	return mat


func _box_on(parent: Node3D, at: Vector3, size: Vector3, mat: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	part.mesh = box
	part.position = at
	part.rotation = rot
	part.material_override = mat
	parent.add_child(part)
	return part


func _cyl_on(parent: Node3D, at: Vector3, r_top: float, r_bot: float, h: float, mat: Material, rot := Vector3.ZERO, segs := 14) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = r_top
	cyl.bottom_radius = r_bot
	cyl.height = h
	cyl.radial_segments = segs
	part.mesh = cyl
	part.position = at
	part.rotation = rot
	part.material_override = mat
	parent.add_child(part)
	return part


func _tri_outward(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, outward: Vector3) -> void:
	var n := (c - a).cross(b - a).normalized()
	if n.dot(outward) < 0.0:
		n = -n
		st.set_normal(n)
		st.add_vertex(a)
		st.add_vertex(c)
		st.add_vertex(b)
	else:
		st.set_normal(n)
		st.add_vertex(a)
		st.add_vertex(b)
		st.add_vertex(c)


func _quad_outward(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, outward: Vector3) -> void:
	_tri_outward(st, a, b, c, outward)
	_tri_outward(st, a, c, d, outward)


func _loft_segment(
		parent: Node3D,
		z_front_bot: float, z_front_top: float,
		z_back_bot: float, z_back_top: float,
		y_bot: float, y_top: float,
		w_front_bot: float, w_front_top: float,
		w_back_bot: float, w_back_top: float,
		mat: Material) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var flb := Vector3(-w_front_bot * 0.5, y_bot, z_front_bot)
	var frb := Vector3( w_front_bot * 0.5, y_bot, z_front_bot)
	var flt := Vector3(-w_front_top * 0.5, y_top, z_front_top)
	var frt := Vector3( w_front_top * 0.5, y_top, z_front_top)

	var blb := Vector3(-w_back_bot * 0.5, y_bot, z_back_bot)
	var brb := Vector3( w_back_bot * 0.5, y_bot, z_back_bot)
	var blt := Vector3(-w_back_top * 0.5, y_top, z_back_top)
	var brt := Vector3( w_back_top * 0.5, y_top, z_back_top)

	_quad_outward(st, flt, frt, brt, blt, Vector3.UP)
	_quad_outward(st, flb, blb, brb, frb, Vector3.DOWN)
	_quad_outward(st, flb, flt, blt, blb, Vector3(-1.0, 0.15, 0.0))
	_quad_outward(st, frb, brb, brt, frt, Vector3(1.0, 0.15, 0.0))
	_quad_outward(st, flb, frb, frt, flt, Vector3(0.0, 0.1, -1.0))
	_quad_outward(st, blb, blt, brt, brb, Vector3(0.0, 0.1, 1.0))

	var inst := MeshInstance3D.new()
	inst.mesh = st.commit()
	inst.material_override = mat
	parent.add_child(inst)
	return inst


## Строит парные бортовые стенки (фальшборт или планширь) точно по контуру бортов без поворота боксов
func _loft_bulwark(
		parent: Node3D,
		z_front: float, z_back: float,
		y_bot: float, y_top: float,
		w_front: float, w_back: float,
		thickness: float,
		mat: Material) -> void:
	for side in [-1.0, 1.0]:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var f_out_b := Vector3(side * (w_front * 0.5), y_bot, z_front)
		var f_out_t := Vector3(side * (w_front * 0.5), y_top, z_front)
		var f_in_b  := Vector3(side * maxf(0.02, w_front * 0.5 - thickness), y_bot, z_front)
		var f_in_t  := Vector3(side * maxf(0.02, w_front * 0.5 - thickness), y_top, z_front)

		var b_out_b := Vector3(side * (w_back * 0.5), y_bot, z_back)
		var b_out_t := Vector3(side * (w_back * 0.5), y_top, z_back)
		var b_in_b  := Vector3(side * maxf(0.02, w_back * 0.5 - thickness), y_bot, z_back)
		var b_in_t  := Vector3(side * maxf(0.02, w_back * 0.5 - thickness), y_top, z_back)

		_quad_outward(st, f_out_t, f_in_t, b_in_t, b_out_t, Vector3.UP)
		_quad_outward(st, f_out_b, b_out_b, b_in_b, f_in_b, Vector3.DOWN)
		_quad_outward(st, f_out_b, f_out_t, b_out_t, b_out_b, Vector3(side, 0.0, 0.0))
		_quad_outward(st, f_in_b, b_in_b, b_in_t, f_in_t, Vector3(-side, 0.0, 0.0))
		_quad_outward(st, f_out_b, f_in_b, f_in_t, f_out_t, Vector3(0.0, 0.0, -1.0))
		_quad_outward(st, b_out_b, b_out_t, b_in_t, b_in_b, Vector3(0.0, 0.0, 1.0))

		var inst := MeshInstance3D.new()
		inst.mesh = st.commit()
		inst.material_override = mat
		parent.add_child(inst)


# ---------------------------------------------------------------------------
# Сборка корпуса и надстройки
# ---------------------------------------------------------------------------

func _build_appearance() -> void:
	var anti_fouling := _material(Color("47241f"), 0.08, 0.0, 0.78)
	var boot_stripe := _material(Color("12161a"), 0.15, 0.0, 0.65)
	var hull_steel := _material(Color("1e272e"), 0.30, 0.0, 0.66)
	var gunwale_steel := _material(Color("2b363e"), 0.35, 0.0, 0.60)
	var timber_fender := _material(Color("4a3b2f"), 0.04, 0.0, 0.84)
	var deck_steel := _material(Color("262f35"), 0.25, 0.0, 0.75)
	var deck_planks := _material(Color("57473a"), 0.05, 0.0, 0.80)
	var cabin_chalk := _material(Color("c4bfb2"), 0.08, 0.0, 0.68)
	var cabin_trim := _material(Color("3a444b"), 0.32, 0.0, 0.60)
	var roof_ochre := _material(Color("8c6239"), 0.22, 0.0, 0.62)
	var machinery := _material(Color("334042"), 0.42, 0.0, 0.55)
	var dark_iron := _material(Color("161c20"), 0.55, 0.0, 0.50)
	var aged_bronze := _material(Color("7d6340"), 0.62, 0.0, 0.45)
	var bridge_glass := _material(Color("121e24"), 0.35, 0.08, 0.18)
	var warm_interior := _material(Color("d69e5c"), 0.10, 0.45, 0.30)

	# 1. ГЛАВНЫЙ СТАЛЬНОЙ КОРПУС (4 секции от форштевня до транца)
	# Секция A: Носовой вход (Z: -5.5 .. -3.2)
	_loft_segment(_body, -5.05, -5.25, -3.2, -3.2, -0.45, 0.08, 0.06, 0.12, 1.55, 1.95, anti_fouling)
	_loft_segment(_body, -5.25, -5.32, -3.2, -3.2,  0.08, 0.24, 0.12, 0.16, 1.95, 2.15, boot_stripe)
	_loft_segment(_body, -5.32, -5.65, -3.2, -3.2,  0.24, 0.92, 0.16, 0.28, 2.15, 2.68, hull_steel)

	# Секция B: Носовая скула (Z: -3.2 .. -1.2)
	_loft_segment(_body, -3.2, -3.2, -1.2, -1.2, -0.45, 0.08, 1.55, 1.95, 2.55, 2.95, anti_fouling)
	_loft_segment(_body, -3.2, -3.2, -1.2, -1.2,  0.08, 0.24, 1.95, 2.15, 2.95, 3.08, boot_stripe)
	_loft_segment(_body, -3.2, -3.2, -1.2, -1.2,  0.24, 0.92, 2.15, 2.68, 3.08, 3.36, hull_steel)

	# Секция C: Цилиндрическая вставка миделя (Z: -1.2 .. +2.6)
	_loft_segment(_body, -1.2, -1.2, 2.6, 2.6, -0.45, 0.08, 2.55, 2.95, 2.50, 2.90, anti_fouling)
	_loft_segment(_body, -1.2, -1.2, 2.6, 2.6,  0.08, 0.24, 2.95, 3.08, 2.90, 3.04, boot_stripe)
	_loft_segment(_body, -1.2, -1.2, 2.6, 2.6,  0.24, 0.88, 3.08, 3.36, 3.04, 3.30, hull_steel)

	# Секция D: Корма и транец (Z: +2.6 .. +5.0)
	_loft_segment(_body, 2.6, 2.6, 4.75, 4.90, -0.42, 0.08, 2.50, 2.90, 1.70, 2.25, anti_fouling)
	_loft_segment(_body, 2.6, 2.6, 4.90, 4.95,  0.08, 0.24, 2.90, 3.04, 2.25, 2.40, boot_stripe)
	_loft_segment(_body, 2.6, 2.6, 4.95, 5.08,  0.24, 0.88, 3.04, 3.30, 2.40, 2.68, hull_steel)

	# 2. НОСОВОЙ ПОЛУБАК (Forecastle, Z: -5.65 .. -1.85) — без единого выступающего бокса!
	_loft_segment(_body, -5.65, -5.80, -3.2, -3.2, 0.92, 1.18, 0.28, 0.34, 2.68, 2.82, hull_steel)
	_loft_segment(_body, -3.2,  -3.2,  -1.85,-1.85,0.92, 1.18, 2.68, 2.82, 3.36, 3.40, hull_steel)
	# Стальная палуба полубака
	_loft_segment(_body, -5.60, -5.60, -3.2, -3.2, 1.14, 1.19, 0.24, 0.24, 2.58, 2.58, deck_steel)
	_loft_segment(_body, -3.2,  -3.2,  -1.85,-1.85,1.14, 1.19, 2.58, 2.58, 3.20, 3.20, deck_steel)

	# Фальшборт и планширь полубака, построенные точно по точкам корпуса (0 выступающих планок)
	_loft_bulwark(_body, -5.75, -3.20, 1.18, 1.34, 0.34, 2.82, 0.12, hull_steel)
	_loft_bulwark(_body, -3.20, -1.85, 1.18, 1.32, 2.82, 3.40, 0.12, hull_steel)
	_loft_bulwark(_body, -5.75, -3.20, 1.34, 1.39, 0.38, 2.88, 0.16, gunwale_steel)
	_loft_bulwark(_body, -3.20, -1.85, 1.32, 1.37, 2.88, 3.44, 0.16, gunwale_steel)

	# Якорный брашпиль и кнехты строго внутри палубы полубака
	_box_on(_body, Vector3(0.0, 1.28, -3.75), Vector3(0.48, 0.22, 0.36), machinery)
	_cyl_on(_body, Vector3(0.0, 1.32, -3.75), 0.12, 0.12, 0.68, dark_iron, Vector3(0.0, 0.0, PI * 0.5), 12)
	for side in [-1.0, 1.0]:
		_box_on(_body, Vector3(side * 0.62, 1.21, -3.15), Vector3(0.28, 0.05, 0.16), dark_iron)
		_cyl_on(_body, Vector3(side * 0.55, 1.28, -3.15), 0.045, 0.045, 0.16, dark_iron)
		_cyl_on(_body, Vector3(side * 0.69, 1.28, -3.15), 0.045, 0.045, 0.16, dark_iron)

	# 3. РАБОЧАЯ ПАЛУБА И КОРМОВОЙ ФАЛЬШБОРТ (Z: -1.85 .. +5.0)
	_box_on(_body, Vector3(0.0, 0.88, 1.55), Vector3(3.12, 0.06, 6.75), deck_steel)
	for i in range(7):
		var px := -1.20 + float(i) * 0.40
		_box_on(_body, Vector3(px, 0.915, 2.35), Vector3(0.36, 0.025, 4.85), deck_planks)

	for side in [-1.0, 1.0]:
		for seg_z in [-0.85, 0.75, 2.35, 3.85]:
			_box_on(_body, Vector3(side * 1.58, 1.08, seg_z), Vector3(0.08, 0.28, 1.32), hull_steel)
		_box_on(_body, Vector3(side * 1.59, 1.23, 1.55), Vector3(0.14, 0.05, 6.75), gunwale_steel)
		_box_on(_body, Vector3(side * 1.65, 0.78, 1.15), Vector3(0.10, 0.14, 6.65), timber_fender)
		for frame_z in [-1.4, -0.3, 0.8, 1.9, 3.0, 4.1]:
			_box_on(_body, Vector3(side * 1.52, 1.04, frame_z), Vector3(0.08, 0.32, 0.06), gunwale_steel)
		# Кормовые кнехты
		_box_on(_body, Vector3(side * 1.08, 0.93, 4.75), Vector3(0.30, 0.05, 0.18), dark_iron)
		_cyl_on(_body, Vector3(side * 1.01, 1.00, 4.75), 0.045, 0.045, 0.16, dark_iron)
		_cyl_on(_body, Vector3(side * 1.15, 1.00, 4.75), 0.045, 0.045, 0.16, dark_iron)

	_box_on(_body, Vector3(-0.85, 1.06, 4.96), Vector3(0.80, 0.32, 0.10), hull_steel)
	_box_on(_body, Vector3( 0.85, 1.06, 4.96), Vector3(0.80, 0.32, 0.10), hull_steel)
	_cyl_on(_body, Vector3( 0.00, 0.96, 4.98), 0.09, 0.09, 0.78, aged_bronze, Vector3(0.0, 0.0, PI * 0.5), 12)

	# 4. НАДСТРОЙКА И ХОДОВОЙ МОСТИК (Z: -2.42 .. +0.32)
	_box_on(_body, Vector3(0.0, 0.98, -1.05), Vector3(2.38, 0.16, 2.82), cabin_trim)
	_loft_segment(_body, -2.42, -2.35, 0.32, 0.32, 1.06, 1.98, 2.32, 2.26, 2.32, 2.26, cabin_chalk)
	_box_on(_body, Vector3(-0.45, 1.48, 0.33), Vector3(0.56, 0.82, 0.06), cabin_trim)
	_box_on(_body, Vector3(-0.45, 1.62, 0.36), Vector3(0.28, 0.24, 0.04), bridge_glass)
	for side in [-1.0, 1.0]:
		for wz in [-1.65, -0.85]:
			_box_on(_body, Vector3(side * 1.15, 1.56, wz), Vector3(0.06, 0.34, 0.46), cabin_trim)
			_box_on(_body, Vector3(side * 1.17, 1.56, wz), Vector3(0.04, 0.24, 0.36), bridge_glass)
		_cyl_on(_body, Vector3(side * 1.17, 1.46, -0.10), 0.22, 0.22, 0.06, _material(Color("b84b39"), 0.05, 0.0, 0.7), Vector3(0.0, 0.0, PI * 0.5), 14)

	_box_on(_body, Vector3(0.0, 2.01, -1.08), Vector3(2.96, 0.07, 2.55), cabin_trim)
	for side in [-1.0, 1.0]:
		_box_on(_body, Vector3(side * 1.42, 2.22, -1.08), Vector3(0.06, 0.38, 1.85), cabin_chalk)
		var nav_col := Color("d93829") if side < 0.0 else Color("29b856")
		_box_on(_body, Vector3(side * 1.44, 2.32, -1.72), Vector3(0.12, 0.16, 0.34), cabin_trim)
		_cyl_on(_body, Vector3(side * 1.46, 2.32, -1.72), 0.05, 0.05, 0.12, _material(nav_col, 0.1, 1.8, 0.2))

	_loft_segment(_body, -2.18, -2.42, -0.32, -0.28, 2.04, 2.82, 1.98, 2.12, 2.06, 1.98, cabin_chalk)
	_box_on(_body, Vector3(0.0, 2.36, -1.45), Vector3(1.55, 0.32, 1.15), warm_interior)
	_loft_segment(_body, -2.20, -2.40, -2.14, -2.34, 2.26, 2.72, 1.84, 1.96, 1.84, 1.96, bridge_glass)
	for mx in [-0.58, 0.0, 0.58]:
		_box_on(_body, Vector3(mx, 2.49, -2.31), Vector3(0.05, 0.50, 0.08), cabin_trim, Vector3(-0.38, 0.0, 0.0))
	for side in [-1.0, 1.0]:
		_box_on(_body, Vector3(side * 1.02, 2.48, -1.32), Vector3(0.06, 0.44, 1.52), bridge_glass)
		_box_on(_body, Vector3(side * 1.03, 2.48, -1.32), Vector3(0.07, 0.48, 0.06), cabin_trim)
	_box_on(_body, Vector3(-0.48, 2.48, -0.29), Vector3(0.72, 0.42, 0.06), bridge_glass)

	_loft_segment(_body, -2.62, -2.52, -0.18, -0.22, 2.82, 2.94, 2.28, 2.14, 2.16, 2.04, roof_ochre)

	# Прожектор, радар и сигнальная мачта
	_cyl_on(_body, Vector3(0.0, 3.08, -2.28), 0.11, 0.13, 0.26, dark_iron, Vector3(PI * 0.5 - 0.28, 0.0, 0.0), 12)
	_cyl_on(_body, Vector3(0.0, 3.12, -2.38), 0.09, 0.09, 0.06, _material(Color("ffdf9e"), 0.1, 2.0, 0.2), Vector3(PI * 0.5 - 0.28, 0.0, 0.0), 12)
	var spot := SpotLight3D.new()
	spot.light_color = Color("ffe8ba")
	spot.light_energy = 2.0
	spot.spot_range = 24.0
	spot.spot_angle = 30.0
	spot.position = Vector3(0.0, 3.12, -2.45)
	spot.rotation = Vector3(-0.34, 0.0, 0.0)
	_body.add_child(spot)

	_cyl_on(_body, Vector3(0.0, 3.12, -1.35), 0.10, 0.14, 0.36, cabin_chalk)
	_radar = Node3D.new()
	_radar.position = Vector3(0.0, 3.32, -1.35)
	_body.add_child(_radar)
	_box_on(_radar, Vector3(0.0, 0.04, 0.0), Vector3(1.08, 0.10, 0.18), cabin_chalk)

	for side in [-1.0, 1.0]:
		_cyl_on(_body, Vector3(side * 0.36, 3.68, -0.52), 0.03, 0.05, 1.62, dark_iron, Vector3(0.12, 0.0, side * 0.20), 8)
	_cyl_on(_body, Vector3(0.0, 3.92, -0.60), 0.025, 0.025, 1.45, dark_iron, Vector3(0.0, 0.0, PI * 0.5), 8)
	_cyl_on(_body, Vector3(0.0, 4.46, -0.62), 0.06, 0.06, 0.14, _material(Color("ffcf87"), 0.1, 1.8, 0.2))

	# 5. МАШИННЫЙ КОЖУХ И ТРУБА ПО ПРАВОМУ БОРТУ (+X)
	_box_on(_body, Vector3(0.46, 1.36, 0.95), Vector3(1.18, 0.88, 1.25), cabin_trim)
	var stack_node := Node3D.new()
	stack_node.position = Vector3(0.46, 1.80, 0.95)
	_body.add_child(stack_node)
	_loft_segment(stack_node, -0.42, -0.25, 0.42, 0.56, 0.0, 0.95, 0.68, 0.56, 0.68, 0.56, roof_ochre)
	_loft_segment(stack_node, -0.25, -0.18, 0.56, 0.62, 0.95, 1.22, 0.56, 0.52, 0.56, 0.52, dark_iron)
	_cyl_on(stack_node, Vector3(-0.12, 1.30, 0.22), 0.07, 0.07, 0.24, dark_iron, Vector3(0.18, 0.0, 0.0), 10)
	_cyl_on(stack_node, Vector3( 0.12, 1.30, 0.22), 0.07, 0.07, 0.24, dark_iron, Vector3(0.18, 0.0, 0.0), 10)

	# 6. КРАН-МАНИПУЛЯТОР И НАСОС СТРОГО НА ЛЕВОМ БОРТУ (-X)
	_cyl_on(_body, Vector3(-1.22, 1.08, 0.95), 0.26, 0.30, 0.36, cabin_trim)
	_box_on(_body, Vector3(-0.82, 1.08, 0.95), Vector3(0.56, 0.34, 0.62), machinery)
	_cyl_on(_body, Vector3(-0.55, 1.12, 1.55), 0.06, 0.06, 1.25, dark_iron, Vector3(PI * 0.5, 0.0, 0.0), 10)

	_crane_turret = Node3D.new()
	_crane_turret.position = Vector3(-1.22, 1.26, 0.95)
	_crane_turret.rotation.y = -0.18
	_body.add_child(_crane_turret)
	_cyl_on(_crane_turret, Vector3(0.0, 0.26, 0.0), 0.16, 0.20, 0.52, machinery)
	_box_on(_crane_turret, Vector3(0.0, 0.56, -0.05), Vector3(0.26, 0.24, 0.34), dark_iron)

	_crane_boom = Node3D.new()
	_crane_boom.position = Vector3(0.0, 0.62, 0.0)
	_crane_turret.add_child(_crane_boom)
	_box_on(_crane_boom, Vector3(0.0, 0.14, 0.62), Vector3(0.14, 0.16, 1.32), machinery, Vector3(-0.20, 0.0, 0.0))
	_cyl_on(_crane_boom, Vector3(0.0, -0.02, 0.45), 0.045, 0.055, 0.78, aged_bronze, Vector3(1.15, 0.0, 0.0), 8)

	_crane_jib = Node3D.new()
	_crane_jib.position = Vector3(0.0, 0.26, 1.18)
	_crane_boom.add_child(_crane_jib)
	_box_on(_crane_jib, Vector3(0.0, 0.0, 0.52), Vector3(0.11, 0.12, 1.10), machinery)
	_cyl_on(_crane_jib, Vector3(0.0, -0.08, 1.05), 0.10, 0.14, 0.22, dark_iron)

	# 7. КОРМОВОЙ ПРОМЫШЛЕННЫЙ МАНИФОЛЬД И 4 ТАНКА
	_box_on(_body, Vector3(0.0, 0.96, 3.00), Vector3(2.26, 0.10, 2.08), cabin_trim)
	_box_on(_body, Vector3(0.0, 1.52, 3.00), Vector3(0.16, 1.05, 1.95), dark_iron)

	_vat_fills.clear()
	_vat_mats.clear()
	var tank_coords := [
		Vector3(-0.62, 0.0, 2.48),
		Vector3( 0.62, 0.0, 2.48),
		Vector3(-0.62, 0.0, 3.52),
		Vector3( 0.62, 0.0, 3.52),
	]
	for i in range(4):
		var tc: Vector3 = tank_coords[i]
		var side_sign := -1.0 if tc.x < 0.0 else 1.0
		_cyl_on(_body, Vector3(tc.x, 1.42, tc.z), 0.34, 0.34, 0.84, gunwale_steel, Vector3.ZERO, 16)
		_cyl_on(_body, Vector3(tc.x, 1.86, tc.z), 0.28, 0.35, 0.10, cabin_trim, Vector3.ZERO, 16)
		_cyl_on(_body, Vector3(tc.x, 1.22, tc.z), 0.355, 0.355, 0.05, dark_iron, Vector3.ZERO, 16)
		_cyl_on(_body, Vector3(tc.x, 1.62, tc.z), 0.355, 0.355, 0.05, dark_iron, Vector3.ZERO, 16)
		var ring_mat := _material(ResourceSlick.COLORS[i].darkened(0.25), 0.2, 0.25, 0.5)
		_cyl_on(_body, Vector3(tc.x, 1.93, tc.z), 0.14, 0.14, 0.06, ring_mat, Vector3.ZERO, 12)

		_box_on(_body, Vector3(tc.x + side_sign * 0.32, 1.42, tc.z), Vector3(0.06, 0.72, 0.16), dark_iron)
		var f_mat := _material(ResourceSlick.COLORS[i], 0.1, 0.75, 0.25)
		var f_bar := _box_on(_body, Vector3(tc.x + side_sign * 0.34, 1.12, tc.z), Vector3(0.05, 0.66, 0.10), f_mat)
		f_bar.scale.y = 0.12
		_vat_fills.append(f_bar)
		_vat_mats.append(f_mat)

	# 8. КОРМОВОЙ ПОРТАЛ И ВИНТОРУЛЕВАЯ ГРУППА
	for side in [-1.0, 1.0]:
		_box_on(_body, Vector3(side * 1.22, 1.68, 4.45), Vector3(0.12, 1.56, 0.16), cabin_trim, Vector3(-0.14, 0.0, side * 0.12))
	_box_on(_body, Vector3(0.0, 2.42, 4.35), Vector3(2.38, 0.14, 0.18), roof_ochre)

	_rudder = Node3D.new()
	_rudder.position = Vector3(0.0, -0.12, 4.82)
	_body.add_child(_rudder)
	_box_on(_rudder, Vector3(0.0, 0.0, 0.20), Vector3(0.08, 0.54, 0.42), dark_iron)

	_prop_l = _build_propeller(Vector3(-0.65, -0.15, 4.72), aged_bronze)
	_prop_r = _build_propeller(Vector3( 0.65, -0.15, 4.72), aged_bronze)

	var deck_light := OmniLight3D.new()
	deck_light.light_color = Color("ffd296")
	deck_light.light_energy = 0.90
	deck_light.omni_range = 9.5
	deck_light.position = Vector3(0.0, 2.35, 2.40)
	_body.add_child(deck_light)

	_hose = MeshInstance3D.new()
	var tube := CylinderMesh.new()
	tube.top_radius = 0.06
	tube.bottom_radius = 0.085
	tube.height = 1.0
	_hose.mesh = tube
	_hose_mat = _material(Color("2e524e"), 0.2, 0.8, 0.45)
	_hose.material_override = _hose_mat
	_hose.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_hose.visible = false
	add_child(_hose)

	_intake_head = MeshInstance3D.new()
	var head_cyl := CylinderMesh.new()
	head_cyl.top_radius = 0.34
	head_cyl.bottom_radius = 0.42
	head_cyl.height = 0.16
	_intake_head.mesh = head_cyl
	_intake_mat = _material(Color("459990"), 0.2, 1.1, 0.35)
	_intake_head.material_override = _intake_mat
	_intake_head.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_intake_head.visible = false
	add_child(_intake_head)


func _build_propeller(at: Vector3, mat: Material) -> Node3D:
	var hub := Node3D.new()
	hub.position = at
	_body.add_child(hub)
	_cyl_on(hub, Vector3.ZERO, 0.09, 0.09, 0.22, mat, Vector3(PI * 0.5, 0.0, 0.0), 10)
	for i in range(3):
		var a := float(i) * TAU / 3.0
		var blade := _box_on(hub, Vector3(cos(a) * 0.18, sin(a) * 0.18, 0.03), Vector3(0.24, 0.08, 0.025), mat)
		blade.rotation.z = a
	return hub


func _build_trailer() -> void:
	_trailer = Node3D.new()
	_trailer.name = "TowedEquipmentBarge"
	_trailer.top_level = true
	_trailer.visible = false
	add_child(_trailer)

	_trailer_body = Node3D.new()
	_trailer.add_child(_trailer_body)

	var anti_fouling := _material(Color("47241f"), 0.08, 0.0, 0.78)
	var hull_steel := _material(Color("1e272e"), 0.30, 0.0, 0.66)
	var gunwale_steel := _material(Color("2b363e"), 0.35, 0.0, 0.60)
	var deck_steel := _material(Color("262f35"), 0.25, 0.0, 0.75)
	var roof_ochre := _material(Color("8c6239"), 0.22, 0.0, 0.62)
	var dark_iron := _material(Color("161c20"), 0.55, 0.0, 0.50)
	var cable_steel := _material(Color("384248"), 0.65, 0.0, 0.45)

	_loft_segment(_trailer_body, -2.75, -3.05, -2.0, -2.0, -0.32, 0.12, 2.20, 2.52, 2.48, 2.65, anti_fouling)
	_loft_segment(_trailer_body, -2.0,  -2.0,   2.0,  2.0, -0.32, 0.12, 2.48, 2.65, 2.48, 2.65, anti_fouling)
	_loft_segment(_trailer_body,  2.0,   2.0,   2.75, 2.95,-0.32, 0.12, 2.48, 2.65, 2.25, 2.50, anti_fouling)

	_loft_segment(_trailer_body, -3.05, -3.15, -2.0, -2.0, 0.12, 0.56, 2.52, 2.62, 2.65, 2.74, hull_steel)
	_loft_segment(_trailer_body, -2.0,  -2.0,   2.0,  2.0, 0.12, 0.56, 2.65, 2.74, 2.65, 2.74, hull_steel)
	_loft_segment(_trailer_body,  2.0,   2.0,   2.95, 3.05,0.12, 0.56, 2.65, 2.74, 2.50, 2.60, hull_steel)

	_box_on(_trailer_body, Vector3(0.0, 0.57, 0.0), Vector3(2.58, 0.05, 5.85), deck_steel)
	for side in [-1.0, 1.0]:
		_box_on(_trailer_body, Vector3(side * 1.32, 0.66, 0.0), Vector3(0.10, 0.16, 5.65), gunwale_steel)
		_cyl_on(_trailer_body, Vector3(side * 0.65, 0.66, -2.85), 0.05, 0.05, 0.18, dark_iron)

	_box_on(_trailer_body, Vector3(0.0, 0.98, -0.55), Vector3(1.92, 0.78, 2.15), gunwale_steel)
	_box_on(_trailer_body, Vector3(0.0, 1.40, -0.55), Vector3(2.02, 0.08, 2.24), roof_ochre)

	_trailer_sight_fills.clear()
	for i in range(4):
		var tx := -0.58 if (i % 2 == 0) else 0.58
		var tz := 1.15 + float(i) / 2.0 * 0.92
		_cyl_on(_trailer_body, Vector3(tx, 0.92, tz), 0.28, 0.28, 0.72, gunwale_steel, Vector3.ZERO, 14)
		_cyl_on(_trailer_body, Vector3(tx, 1.30, tz), 0.22, 0.28, 0.08, dark_iron, Vector3.ZERO, 14)
		var s_mat := _material(ResourceSlick.COLORS[i], 0.1, 0.65, 0.3)
		var s_bar := _box_on(_trailer_body, Vector3(tx, 0.92, tz + 0.26), Vector3(0.12, 0.48, 0.06), s_mat)
		s_bar.scale.y = 0.2
		_trailer_sight_fills.append(s_bar)

	_cyl_on(_trailer_body, Vector3(0.0, 1.25, 2.65), 0.03, 0.04, 1.35, dark_iron)
	_cyl_on(_trailer_body, Vector3(0.0, 1.96, 2.65), 0.07, 0.07, 0.14, _material(Color("ffdfa0"), 0.1, 1.8, 0.2))

	var c_mesh := CylinderMesh.new()
	c_mesh.top_radius = 0.032
	c_mesh.bottom_radius = 0.032
	c_mesh.height = 1.0

	_tow_cable_l = MeshInstance3D.new()
	_tow_cable_l.top_level = true
	_tow_cable_l.mesh = c_mesh
	_tow_cable_l.material_override = cable_steel
	_tow_cable_l.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_tow_cable_l.visible = false
	add_child(_tow_cable_l)

	_tow_cable_r = MeshInstance3D.new()
	_tow_cable_r.top_level = true
	_tow_cable_r.mesh = c_mesh
	_tow_cable_r.material_override = cable_steel
	_tow_cable_r.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_tow_cable_r.visible = false
	add_child(_tow_cable_r)
```

## `scripts/boat_hud.gd`

```gdscript
class_name BoatHud
extends Control
## Лёгкий интерфейс без экранной цветокоррекции.
var main: BoatMain

func _draw() -> void:
	if main == null or main.boat == null:
		return
	var font := ThemeDB.fallback_font
	var ink := Color("e9f0e8")
	var muted := Color("9db8b7")
	var accent := Color("78dfcb")
	var warn := Color("f3c783")
	var backdrop := Color(0.035, 0.075, 0.10, 0.88)
	var panel := Rect2(22, 22, 396, 276)
	draw_rect(panel, backdrop)
	draw_rect(panel, Color("548c89"), false, 1.5)
	draw_string(font, Vector2(42, 53), "ПРИЛИВНАЯ ЛАБОРАТОРИЯ", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, ink)
	draw_string(font, Vector2(42, 78), "СКОРОСТЬ  %02.0f / %.0f     НАСОС (ЛЕВ. БОРТ)  %s" % [
		absf(main.boat.speed),
		main.boat.effective_max_speed(),
		"РАБОТАЕТ" if main.boat.pump_fraction() > 0.0 else "ГОТОВ"
	], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, muted)
	var required := 2 if main.boat.has_trailer else 3
	for i in range(ResourceSlick.COLORS.size()):
		var y := 105.0 + float(i) * 32.0
		draw_rect(Rect2(42, y - 15, 13, 13), ResourceSlick.COLORS[i])
		draw_string(font, Vector2(65, y - 3), ResourceSlick.NAMES[i].to_upper(), HORIZONTAL_ALIGNMENT_LEFT, 122, 15, ink)
		draw_string(font, Vector2(235, y - 3), "%02d сыр.  →  %02d гот." % [main.raw[i], main.refined[i]], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, muted)
		# Это прогресс следующей переработки, не «ёмкость»: запасы не ограничены.
		draw_rect(Rect2(235, y + 2, 158, 4), Color("273c41"))
		draw_rect(Rect2(235, y + 2, 158.0 * clampf(float(main.raw[i]) / float(required), 0.0, 1.0), 4),
			ResourceSlick.COLORS[i])
	draw_string(font, Vector2(42, 223), "ПОЛОСЫ: СЫРЬЁ ДО ПЕРЕРАБОТКИ (%d ШТ.)" % required,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 12, muted)

	var trailer_status := "ПЛАШКОУТ: НА БУКСИРЕ (2 сыр. → 1 гот.)" if main.boat.has_trailer else "ПЛАШКОУТ: НЕТ  [B — КУПИТЬ ЗА 2 ГОТ. / T — ТЕСТ]"
	draw_string(font, Vector2(42, 240), trailer_status, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, accent if main.boat.has_trailer else muted)

	var resource_name := main.boat.target_name()
	var action := "ИЩИТЕ СВЕТЯЩИЕСЯ ПЯТНА"
	var action_col := ink
	if not resource_name.is_empty():
		action = "ПРОБЕЛ — ЗАБРАТЬ (ЛЕВ. БОРТ): %s" % resource_name.to_upper()
		action_col = accent
	elif main.boat.wrong_side_target:
		action = "ПОВЕРНИТЕСЬ ЛЕВЫМ БОРТОМ К ПЯТНУ"
		action_col = warn

	var center := Vector2(size.x * 0.5 - 205.0, size.y - 134.0)
	draw_rect(Rect2(center, Vector2(410, 38)), backdrop)
	draw_string(font, center + Vector2(14, 26), action, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, action_col)
	if main.boat.pump_fraction() > 0.0:
		draw_rect(Rect2(center + Vector2(0, 36), Vector2(410.0 * main.boat.pump_fraction(), 3)), accent)
	var controls := "W/S — ХОД    A/D — РУЛЬ    ПРОБЕЛ — НАСОС    R — ПЕРЕРАБОТКА    B — ПЛАШКОУТ    T — ТЕСТ    КОЛЕСО — ЗУМ"
	draw_string(font, Vector2(28, size.y - 28), controls, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, ink)
	if main.notice_time > 0.0:
		draw_string(font, Vector2(size.x * 0.5 - 260, size.y - 168), main.notice, HORIZONTAL_ALIGNMENT_CENTER, 520, 17, warn)
```

## `scripts/resource_slick.gd`

```gdscript
class_name ResourceSlick
extends MeshInstance3D
## Отдельный SDF-материал на каждый цветной метабол.

const SHADER := preload("res://shaders/resource_slick.gdshader")
# Вершины пятна повторяют дисперсионные волны; небольшой запас оставляет
# шейдерное пятно над контактной пеной и редкими точечными всплесками.
const FLOAT_HEIGHT := 0.34
const COLORS: Array[Color] = [
	Color("31c2bd"), # приливная бирюза
	Color("f07b62"), # коралл
	Color("f2bc67"), # янтарь
	Color("a699ed"), # орхидея
]
const NAMES: Array[String] = ["Бирюза", "Коралл", "Янтарь", "Орхидея"]

var kind := 0
var depleted := false
var _mat: ShaderMaterial
var _water: WaterSurface
var _age := 0.0
var _respawn := 0.0
var _fade := 1.0


func setup(water: WaterSurface, at: Vector2, resource_kind: int, variation: float) -> void:
	_water = water
	kind = resource_kind % COLORS.size()
	position = Vector3(at.x, water.surface_height(at.x, at.y) + FLOAT_HEIGHT, at.y)
	var plane := PlaneMesh.new()
	plane.size = Vector2(5.6, 5.6)
	plane.subdivide_width = 12
	plane.subdivide_depth = 12
	mesh = plane
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_mat.set_shader_parameter("pigment", COLORS[kind])
	_mat.set_shader_parameter("seed", variation)
	_mat.set_shader_parameter("fade", 1.0)
	material_override = _mat
	_mat.render_priority = 10 # после моря, но тест глубины сохраняет окклюзию корпусом
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Вершинный шейдер поднимает край пятна за исходный плоский AABB:
	# иначе движущийся объект может исчезнуть из-за frustum culling.
	extra_cull_margin = 1.0
	sorting_offset = 100.0 # поверх прозрачной воды, без вмешательства в шейдер моря


func relocate_smoothly(new_pos: Vector3) -> void:
	position = new_pos
	_fade = 0.0
	if _mat != null:
		_mat.set_shader_parameter("fade", 0.0)


func _process(delta: float) -> void:
	_age += delta
	if depleted:
		_respawn -= delta
		if _respawn <= 0.0:
			depleted = false
			visible = true
			_fade = 0.0
		return
	_fade = minf(1.0, _fade + delta * 1.2)
	if _water != null:
		position.y = _water.surface_height(position.x, position.z) + FLOAT_HEIGHT
		if _water.field != null and _mat != null:
			_mat.set_shader_parameter("wave_time", _water.field.t)
			_mat.set_shader_parameter("wave_amp", _water.field.mega_amp)
			_mat.set_shader_parameter("wave_power", _water.field.wind_power)
			_mat.set_shader_parameter("wave_wind", _water.field.wind_dir)
	if _mat != null:
		_mat.set_shader_parameter("pulse", 0.5 + 0.5 * sin(_age * 2.2))
		_mat.set_shader_parameter("fade", _fade)


func collect() -> void:
	if depleted:
		return
	depleted = true
	visible = false
	_respawn = 35.0
	if _water != null and _water.field != null:
		_water.field.splash(Vector2(position.x, position.z), 1.2)
```

## `shaders/resource_slick.gdshader`

```glsl
shader_type spatial;
// Цветные приливные пятна. Та же SDF-идея, что в sand_sea_sdf.gdshader:
// расстояния до примитивов, плавное объединение форм и цветов, а не текстура.
// Пятно лежит поверх существующего волнового моря и не заменяет его шейдер.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;

uniform vec3 pigment : source_color = vec3(0.20, 0.80, 0.77);
uniform float seed = 0.0;
uniform float pulse = 0.0;
uniform float fade = 1.0;
uniform float wave_time = 0.0;
uniform float wave_amp = 0.25;
uniform float wave_power = 1.0;
uniform vec2 wave_wind = vec2(0.32, -0.95);
varying vec2 local_pos;

#include "res://shaders/boat_wave_spectrum.gdshaderinc"

float hash21(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

// IQ polynomial smooth-min: та же операция "плавления", что у SDF-рыб.
float smooth_union(float a, float b, float k) {
    float h = max(k - abs(a - b), 0.0) / k;
    return min(a, b) - h * h * k * 0.25;
}

void vertex() {
	local_pos = VERTEX.xz;
	// Сетка пятна повторяет тот же дисперсионный спектр, что и море.
	vec2 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
	vec2 center = MODEL_MATRIX[3].xz;
	VERTEX.y += spectrum_height(wp, wave_time, wave_wind, wave_amp, wave_power)
		- spectrum_height(center, wave_time, wave_wind, wave_amp, wave_power);
}

void fragment() {
    vec2 p = local_pos * 0.82;
    float t = TIME * 0.45 + seed;
    float d = length(p + vec2(sin(t) * 0.10, cos(t * 0.8) * 0.10)) - 0.96;
    for (int i = 0; i < 4; i++) {
        float a = float(i) * 2.399963 + seed * 2.7;
        vec2 center = vec2(cos(a), sin(a)) * (0.68 + 0.15 * sin(t + float(i)));
        float lobe = length(p - center) - (0.52 + 0.12 * sin(t * 1.2 + float(i) * 2.0));
        d = smooth_union(d, lobe, 0.48);
    }
    float ripple = sin(length(p) * 11.0 - t * 3.8 + atan(p.y, p.x) * 4.0);
    float angle = atan(p.y, p.x);
    d += sin(angle * 5.0 + t * 0.65) * 0.08
        + sin(angle * 9.0 - t * 0.25) * 0.035;
    d += ripple * 0.035 + (hash21(floor(p * 12.0) + floor(t * 0.2)) - 0.5) * 0.025;
    float aa = max(fwidth(d), 0.012);
    float body = 1.0 - smoothstep(-aa, aa, d);
    float edge = exp(-pow(d / 0.19, 2.0));
    float veins = 0.5 + 0.5 * sin(p.x * 7.0 + p.y * 9.0 + t * 2.4);
    vec3 col = pigment * (0.72 + 0.28 * veins);
    col += pigment * edge * (0.8 + 0.5 * sin(t * 2.0));
    col += vec3(0.85, 0.96, 0.90) * edge * pulse * 0.65;
    ALBEDO = col;
    ALPHA = body * (0.63 + 0.17 * veins) * fade;
    EMISSION = pigment * body * (0.10 + 0.20 * pulse) * fade;
}
```

## `scripts/water_surface.gd`

```gdscript
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
## Урез: карта высот читается по фрагментам, без подрезания вершин воды
## к рельефу и без висящей плёнки. Градиент прозрачности сглаживает кромку.

const SHADER_PATH := "res://shaders/water.gdshader"
# Выбирается до setup(): архивная рыбалка использует прежний шейдер,
# лодочная сцена — отдельный вариант с волнами от корпуса и винтов.
var shader_path := SHADER_PATH

const DENSE_SPAN := 620.0 # однородная зона вокруг берега, м
const DENSE_CELL := 1.25 # ячейка в ней, м
const FAR_LIMIT := 3600.0 # докуда доходит море
const FAR_GROWTH := 1.16 # рост шага вдали

var field: WaterField
var level_y := 0.0
var mesh_size := 240.0

var game: GameState # автозагрузка Game (ветер — общий с песком)
var coast: Coast
var _night01 := 0.0
var _mat: ShaderMaterial


func setup(game_ref, center: Vector2, p_level_y: float) -> void:
	game = game_ref
	level_y = p_level_y
	position = Vector3(center.x, level_y, center.y)

	_build_mesh()

	_mat = ShaderMaterial.new()
	_mat.shader = load(shader_path)
	if game != null:
		_mat.set_shader_parameter("sun_dir", game.sun_dir)
		_mat.set_shader_parameter("fog_distance", game.FOG_DISTANCE)
	# уровень моря: шейдер вычисляет глубину у кромки берега
	_mat.set_shader_parameter("sea_level", level_y)
	material_override = _mat
	if shader_path == "res://shaders/water_boat.gdshader":
		# В прозрачном проходе всегда рисовать море раньше ресурсных пятен.
		_mat.render_priority = -10
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# море непрозрачное в глубине, alpha используется только у мягкого уреза; рисуем ПЕРВЫМ:
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


## Усиленное CPU-зеркало волн только для изометрической лодочной сцены.
## Режим рыбалки остаётся на исходных значениях WaterField.
func configure_boat_waves() -> void:
	field.ring_amp = 0.065
	field.wake_interval = 0.12
	field.wake_strength = 0.45
	field.swell_time_rate = 0.55
	field.chop_strength = 0.0
	field.use_spectrum = true


## Высота поверхности моря в мировой точке (уровень + дыхание + кольца).
func surface_height(x: float, z: float) -> float:
	if field == null:
		return level_y
	var shore_fade := 1.0
	if coast != null:
		var depth := coast.water_depth(x, z)
		var t := clampf(depth / 4.0, 0.0, 1.0)
		shore_fade = t * t * (3.0 - 2.0 * t)
	return level_y + field.height_at(x, z) * shore_fade


func material() -> ShaderMaterial:
	return _mat


func set_param(param: String, value) -> void:
	if _mat != null:
		_mat.set_shader_parameter(param, value)


## Карта высот берега из Coast: по ней море кладёт плёнку прибоя на песок.
func set_ground(tex: Texture2D, origin: Vector2, cell: float, n: int,
		coast_ref: Coast = null) -> void:
	coast = coast_ref
	set_param("ground_tex", tex)
	set_param("ground_origin", origin)
	set_param("ground_cell", cell)
	set_param("ground_n", float(n))


func apply_sun(dir: Vector3) -> void:
	set_param("sun_dir", dir)


## Палитра моря: день — бирюза/индиго, ночь — почти чёрная глубина.
## Песок сюда НЕ подмешивается: у суши и воды разные материалы.
const DAY_SHALLOW := Color(0.30, 0.66, 0.62)
const DAY_MID := Color(0.10, 0.38, 0.48)
const DAY_DEEP := Color(0.035, 0.150, 0.300)
const DAY_FOAM := Color(0.95, 0.92, 0.86)
const NIGHT_SHALLOW := Color(0.045, 0.110, 0.120)
const NIGHT_MID := Color(0.012, 0.040, 0.060)
const NIGHT_DEEP := Color(0.003, 0.010, 0.022)
const NIGHT_FOAM := Color(0.30, 0.36, 0.42)


func apply_night01(v: float) -> void:
	_night01 = clampf(v, 0.0, 1.0)
	set_param("water_shallow", DAY_SHALLOW.lerp(NIGHT_SHALLOW, v))
	set_param("water_mid", DAY_MID.lerp(NIGHT_MID, v))
	set_param("water_deep", DAY_DEEP.lerp(NIGHT_DEEP, v))
	set_param("foam_col", DAY_FOAM.lerp(NIGHT_FOAM, v))
	set_param("horizon_col", Coast.DAY_HORIZON.lerp(Coast.NIGHT_HORIZON, v))
	set_param("sky_col", Coast.DAY_SKY.lerp(Coast.NIGHT_SKY, v))
	set_param("fog_distance", lerpf(340.0, 130.0, v))
	# На ночной воде гасим обычные микроблики и солнечные частицы:
	# редкие огни остаются, а звёзды на песке не превращаются в сплошную россыпь.
	set_param("glitter_amount", lerpf(1.0, 0.08, _night01))
	set_param("solar_glitter_amount", lerpf(1.0, 0.0, _night01))


func _process(_delta: float) -> void:
	if game == null or _mat == null:
		return
	# Погода усиливает море нелинейно; ночью дыхание чуть спокойнее.
	# F3 меняет базовый mega_amp, а этот множитель мягко следует ветру.
	var weather01 := clampf((game.wind_strength - 0.65) / 0.70, 0.0, 1.0)
	var weather_gain := lerpf(0.72, 1.28, weather01)
	var night_gain := lerpf(1.0, 0.84, _night01)
	var sea_power := clampf(game.wind_strength * weather_gain * night_gain, 0.45, 1.65)
	_mat.set_shader_parameter("wind_dir", game.wind_dir())
	_mat.set_shader_parameter("wind_power", sea_power)
	if field != null:
		field.wind_dir = game.wind_dir()
		field.wind_power = sea_power
		var ma: Variant = _mat.get_shader_parameter("mega_amp")
		if ma != null:
			field.mega_amp = ma # CPU-поплавок следует за F3 и морским состоянием


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
```

## `scripts/water_field.gd`

```gdscript
class_name WaterField
extends Node
## Песчаное море: поле СОБЫТИЙ вместо поля высот.
##
## У SandField высота хранится в торе 800×800 и штампуется следами. Морю
## сетка не нужна (вариант А): каждое событие — расходящееся кольцо-пакет,
## а «дыхание» моря (мега-рябь песка ~9 м) считается аналитически. Формулы
## в точности те же, что в water.gdshader: шейдер рисует нормали, эта нода
## даёт физике ВЫСОТУ воды в точке — поплавок качается на том же «одеяле»
## и на тех же кольцах, что видит глаз.
##
## Кольца — ring buffer: при переполнении перезаписывается самый старый
## слот (при 24 слотах и жизни 5 с даже спам-клики не вытесняют живое).
## Uniform-ы пушатся в материал на 30 Гц — как карта песка у SandField.
##
## Вариант Б (настоящее волновое уравнение на compute) садится сюда же:
## у WaterField тот же публичный API (height_at / splash / nibble / wake).

const MAX_RINGS := 24
const RING_LIFE := 5.0 # с, после — слот освобождается

const RING_SPEED := 1.5 # м/с, фронт (должно совпадать с шейдером)
const RING_WAVELEN := 0.85
const RING_TAU := 0.55
const RING_W0 := 0.30
const RING_WG := 0.18
const RING_AMP := 0.055

const PUSH_HZ := 30.0 # частота пуша uniform-ов

var t := 0.0 # время поля — ЕДИНОЕ с шейдерным u_time
var mat: ShaderMaterial # куда пушим кольца (назначает WaterSurface)

# Живой ветер: WaterSurface обновляет каждый кадр из game (как у песка),
# чтобы физика поплавка качалась ровно на том «одеяле», что рисует шейдер.
var wind_dir := Vector2(0.32, -0.95)
var wind_power := 1.0
var mega_amp := 0.055 # дыхание моря — синхронно с uniform-ом шейдера
# Только лодочная сцена переопределяет эти параметры для штормового моря.
var ring_amp := RING_AMP
var wake_interval := 0.33
var wake_strength := 0.30
var swell_time_rate := 0.25
var chop_strength := 0.0
var use_spectrum := false # лодочное море: дисперсионные волны вместо песчаного шума

var _pos := PackedVector2Array()
var _t0 := PackedFloat32Array()
var _amp := PackedFloat32Array()
var _cursor := 0
var _push_clock := 0.0
var _last_wake := -10.0


func _ready() -> void:
	_pos.resize(MAX_RINGS)
	_t0.resize(MAX_RINGS)
	_t0.fill(-1000.0) # все слоты «давно умерли»
	_amp.resize(MAX_RINGS)
	_amp.fill(0.0)


# ---------------------------------------------------------------------------
# Публичное API
# ---------------------------------------------------------------------------

## Всплеск: посадка поплавка, прыжок рыбы, брошенный камень.
## strength 1.0 — поплавок; 1.5–2.0 — что-то покрупнее.
func splash(pos: Vector2, strength := 1.0) -> void:
	_add_ring(pos, clampf(strength, 0.1, 2.0))


## Поклёвка: короткая серия из трёх убывающих колец — «буль-буль-буль».
func nibble(pos: Vector2) -> void:
	_add_ring(pos, 0.45)
	_add_ring(pos + Vector2(0.12, 0.05), 0.30)
	_add_ring(pos + Vector2(-0.08, 0.10), 0.20)


## След в воде: подмотка поплавка, брод путника. Тротлится по времени.
func wake(pos: Vector2, strength := 1.0) -> void:
	if t - _last_wake < wake_interval:
		return
	_last_wake = t
	_add_ring(pos, wake_strength * clampf(strength, 0.0, 2.0))


## Высота воды в точке СЕЙЧАС: дыхание (мега-рябь) + все живые кольца.
## Зеркало шейдерной математики (mega_phase + кольца) — поплавок и физика
## качаются ровно на той воде, которую рисует шейдер.
func height_at(x: float, z: float) -> float:
	var h := _spectrum_height(x, z) if use_spectrum else _mega_h_cpu(x, z)
	for i in range(MAX_RINGS):
		var a := _amp[i]
		if a < 0.0005:
			continue
		var age := t - _t0[i]
		if age < 0.0:
			continue
		var dd := Vector2(x, z).distance_to(_pos[i])
		var rf := RING_SPEED * age
		var bw := RING_W0 + RING_WG * age
		var xx := (dd - rf) / bw
		var env := exp(-xx * xx)
		var ph := TAU / RING_WAVELEN * (dd - rf)
		var dec := exp(-age * RING_TAU) / sqrt(maxf(rf, 0.6))
		h += ring_amp * a * env * cos(ph) * dec
	return h


## Высота поверхности для ноды воды (уровень добавляет WaterSurface).
func surface_offset(x: float, z: float) -> float:
	return height_at(x, z)


# ---------------------------------------------------------------------------
# Ядро колец
# ---------------------------------------------------------------------------

func _add_ring(pos: Vector2, amp: float) -> void:
	var i := _cursor
	_cursor = (_cursor + 1) % MAX_RINGS
	_pos[i] = pos
	_t0[i] = t
	_amp[i] = amp


# Лодка читает волну в _physics_process: её время должно идти теми же
# фиксированными шагами, а не прыгать вслед за переменным FPS рендера.
# У старой рыбалки оставляем прежний порядок обновления.
func _physics_process(delta: float) -> void:
	if use_spectrum:
		_advance_time(delta)


func _process(delta: float) -> void:
	if not use_spectrum:
		_advance_time(delta)


func _advance_time(delta: float) -> void:
	t += delta
	if use_spectrum and mat != null:
		# Время вершин воды идёт в том же такте, что и плавучесть лодки;
		# массивы колец по-прежнему отправляются только на PUSH_HZ.
		mat.set_shader_parameter("u_time", t)
	# гашение мёртвых слотов (не обязательно, но держит uniform чистым)
	for i in range(MAX_RINGS):
		if _amp[i] > 0.0 and t - _t0[i] > RING_LIFE:
			_amp[i] = 0.0
	# пуш в материал на PUSH_HZ (как карта песка на 30 Гц у SandField)
	_push_clock += delta
	if mat != null and _push_clock >= 1.0 / PUSH_HZ:
		_push_uniforms()
		_push_clock = 0.0


func _push_uniforms() -> void:
	var data := PackedVector4Array()
	data.resize(MAX_RINGS)
	for i in range(MAX_RINGS):
		data[i] = Vector4(_pos[i].x, _pos[i].y, _t0[i], _amp[i])
	mat.set_shader_parameter("u_rings", data)
	mat.set_shader_parameter("u_time", t)


# ---------------------------------------------------------------------------
# CPU-зеркало дыхания моря (mega_phase в шейдере, 1:1 из песка)
# ---------------------------------------------------------------------------

func _hash12(p: Vector2) -> float:
	var p3 := Vector3(fposmod(p.x * 0.1031, 1.0), fposmod(p.y * 0.1031, 1.0),
			fposmod(p.x * 0.1031, 1.0))
	var q := Vector3(p3.y, p3.z, p3.x) + Vector3(33.33, 33.33, 33.33)
	p3 += Vector3(p3.dot(q), p3.dot(q), p3.dot(q))
	return fposmod((p3.x + p3.y) * p3.z, 1.0)


func _vnoise(p: Vector2) -> float:
	var i := p.floor()
	var f := p - i
	f = Vector2(f.x * f.x * (3.0 - 2.0 * f.x), f.y * f.y * (3.0 - 2.0 * f.y)) # smoothstep 3f²-2f³
	var a := _hash12(i)
	var b := _hash12(i + Vector2(1.0, 0.0))
	var c := _hash12(i + Vector2(0.0, 1.0))
	var d := _hash12(i + Vector2(1.0, 1.0))
	return lerpf(lerpf(a, b, f.x), lerpf(c, d, f.x), f.y)


## Линейная дисперсия глубоководных волн omega²=g*k; коэффициенты
## повторяют boat_wave_spectrum.gdshaderinc для плавучести и пятен.
func _spectrum_height(x: float, z: float) -> float:
	var d1 := wind_dir.normalized()
	var d2 := Vector2(d1.x * 0.80 - d1.y * 0.60,
		d1.x * 0.60 + d1.y * 0.80).normalized()
	var d3 := Vector2(d1.x * 0.52 + d1.y * 0.85,
		-d1.x * 0.85 + d1.y * 0.52).normalized()
	var p := Vector2(x, z)
	var k1 := TAU / 18.0
	var k2 := TAU / 9.5
	var k3 := TAU / 4.5
	return mega_amp * wind_power * (
		0.75 * cos(k1 * p.dot(d1) - sqrt(9.81 * k1) * t)
		+ 0.45 * cos(k2 * p.dot(d2) - sqrt(9.81 * k2) * t + 1.7)
		+ 0.22 * cos(k3 * p.dot(d3) - sqrt(9.81 * k3) * t + 3.1))


func _mega_h_cpu(x: float, z: float) -> float:
	var wdir := wind_dir.normalized() if wind_dir.length_squared() > 0.0001 else Vector2(0.32, -0.95)
	var wperp := Vector2(-wdir.y, wdir.x)
	var wp := Vector2(x, z)
	var u := wp.dot(wdir)
	var v := wp.dot(wperp)

	var rn := _vnoise(wp * 0.15)
	var rn2 := _vnoise(wp * 0.07 + Vector2(9.1, 3.3))

	var mph := v * 0.70 + u * 0.16 + rn * 2.6 + rn2 * 3.4 + t * swell_time_rate
	var chop_ph := u * 1.15 - v * 0.45 + t * 1.65
	var primary := (cos(mph) * 0.62 + cos(mph * 2.63 + 1.7) * 0.30
		+ cos(mph * 0.47 + 0.8) * 0.22)
	return (primary + sin(chop_ph) * chop_strength) * mega_amp * wind_power
```

## `shaders/boat_wave_spectrum.gdshaderinc`

```glsl
// Три дисперсионные волны глубокой воды: omega^2 = g*k.
// Одни и те же амплитуды, направления и частоты используются CPU-зеркалом
// WaterField и вершинами воды/ресурсных пятен.
const float WAVE_TAU = 6.28318530718;

float spectrum_height(vec2 xz, float time, vec2 wind, float amplitude, float power) {
	vec2 d1 = normalize(wind);
	vec2 d2 = normalize(vec2(d1.x * 0.80 - d1.y * 0.60, d1.x * 0.60 + d1.y * 0.80));
	vec2 d3 = normalize(vec2(d1.x * 0.52 + d1.y * 0.85, -d1.x * 0.85 + d1.y * 0.52));
	float k1 = WAVE_TAU / 18.0;
	float k2 = WAVE_TAU / 9.5;
	float k3 = WAVE_TAU / 4.5;
	return amplitude * power * (
		0.75 * cos(k1 * dot(xz, d1) - sqrt(9.81 * k1) * time)
		+ 0.45 * cos(k2 * dot(xz, d2) - sqrt(9.81 * k2) * time + 1.7)
		+ 0.22 * cos(k3 * dot(xz, d3) - sqrt(9.81 * k3) * time + 3.1));
}

vec2 spectrum_gradient(vec2 xz, float time, vec2 wind, float amplitude, float power) {
	vec2 d1 = normalize(wind);
	vec2 d2 = normalize(vec2(d1.x * 0.80 - d1.y * 0.60, d1.x * 0.60 + d1.y * 0.80));
	vec2 d3 = normalize(vec2(d1.x * 0.52 + d1.y * 0.85, -d1.x * 0.85 + d1.y * 0.52));
	float k1 = WAVE_TAU / 18.0;
	float k2 = WAVE_TAU / 9.5;
	float k3 = WAVE_TAU / 4.5;
	return -amplitude * power * (
		0.75 * k1 * sin(k1 * dot(xz, d1) - sqrt(9.81 * k1) * time) * d1
		+ 0.45 * k2 * sin(k2 * dot(xz, d2) - sqrt(9.81 * k2) * time + 1.7) * d2
		+ 0.22 * k3 * sin(k3 * dot(xz, d3) - sqrt(9.81 * k3) * time + 3.1) * d3);
}
```

## `shaders/water_boat.gdshader`

```glsl
shader_type spatial;
// МОРЕ С ИСТОРИЧЕСКОЙ ТРАЕКТОРИЕЙ КИЛЬВАТЕРНОГО СЛЕДА В МИРОВЫХ КООРДИНАТАХ:
// - Кильватерная струя и волны Кельвина строятся вдоль кривой u_wake_trail[20],
//   поэтому след остаётся в мировых координатах воды и плавно изгибается при поворотах.

// Прозрачное море не должно записывать глубину поверх пятен ресурсов:
// depth_draw_always мог скрывать их всюду, кроме выреза под корпусом.
render_mode diffuse_burley, specular_schlick_ggx, blend_mix, depth_draw_opaque;

uniform vec3 water_shallow : source_color = vec3(0.30, 0.66, 0.62);
uniform vec3 water_mid : source_color = vec3(0.10, 0.38, 0.48);
uniform vec3 water_deep : source_color = vec3(0.035, 0.150, 0.300);
uniform vec3 foam_col : source_color = vec3(0.95, 0.92, 0.86);
uniform vec3 sun_col : source_color = vec3(1.0, 0.80, 0.52);
uniform vec3 sun_dir = vec3(0.10, 0.26, -0.96);

uniform vec3 horizon_col : source_color = vec3(0.96, 0.66, 0.55);
uniform vec3 sky_col : source_color = vec3(0.28, 0.24, 0.43);
uniform float fog_distance = 340.0;

uniform vec2 wind_dir = vec2(0.32, -0.95);
uniform float wind_power = 1.0;
uniform float mega_amp = 0.15;

uniform float ripple_strength = 0.38;
uniform float glitter_amount = 1.0;
uniform float sun_path_amount = 1.0;
uniform float direct_specular_amount = 1.0;

uniform float proxima_test = 0.0;
uniform float proxima_specular_strength = 0.55;
uniform vec3 proxima_diffuse_fresnel_tint = vec3(1.0);
uniform float proxima_diffuse_fresnel = 1.0;
uniform float proxima_diffuse_fresnel_falloff = 0.75;
uniform float proxima_diffuse_tangent_falloff = 0.75;
uniform vec3 proxima_retroreflection_tint = vec3(1.0);
uniform float proxima_retroreflection = 1.0;
uniform float proxima_retroreflection_falloff = 0.75;
uniform float proxima_retroreflection_tangent_falloff = 0.75;
uniform float proxima_specular_fresnel_falloff = 0.5;
uniform float proxima_smooth_terminator = 0.0;
uniform float proxima_smooth_terminator_length = 0.5;

uniform float ring_amp = 0.065;
uniform float ring_speed = 1.5;
uniform float ring_len = 0.85;
uniform float ring_tau = 0.55;
uniform float ring_w0 = 0.30;
uniform float ring_wg = 0.18;
uniform float ring_boost = 1.4;

uniform float u_time = 0.0;

uniform sampler2D ground_tex : filter_linear, repeat_disable;
uniform vec2 ground_origin = vec2(-280.0, -450.0);
uniform float ground_cell = 1.184;
uniform float ground_n = 761.0;
uniform float sea_level = 0.0;
uniform float shore_fade = 0.03;

uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform vec4 u_rings[24];

// Текущее положение корпуса (x, z, yaw, speed) и массив мировых точек траектории
uniform vec4 u_vessel_state = vec4(0.0, 0.0, 0.0, 0.0);
uniform vec4 u_trailer_state = vec4(0.0, 0.0, 0.0, 0.0);
uniform vec4 u_wake_trail[20]; // xy = world_xz, z = birth_time, w = speed_at_birth

varying vec3 w_pos;

const float PI_2 = 6.28318530718;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	vec3 q = p3.yzx + vec3(33.33);
	p3 += vec3(dot(p3, q));
	return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash12(i);
	float b = hash12(i + vec2(1.0, 0.0));
	float c = hash12(i + vec2(0.0, 1.0));
	float d = hash12(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

#include "res://shaders/boat_wave_spectrum.gdshaderinc"

float ground_at(vec2 wp) {
	vec2 uv = (wp - ground_origin) / (ground_cell * (ground_n - 1.0));
	if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) {
		// За краем 900-метровой карты море должно оставаться ГЛУБОКИМ.
		// -6 м попадало в середину градиента цвета, давая резкую
		// диагональную границу, когда лодка выходила за карту дна.
		return -100.0;
	}
	return texture(ground_tex, uv).r;
}

vec2 to_ship_local(vec2 wp, vec2 center, float yaw) {
	vec2 d = wp - center;
	float c = cos(yaw);
	float s = sin(yaw);
	return vec2(d.x * c - d.y * s, d.x * s + d.y * c);
}

float hull_sdf(vec2 lp) {
	float z_norm = clamp((lp.y + 5.3) / 10.3, 0.0, 1.0);
	float half_w = mix(0.12, 1.62, pow(sin(z_norm * 2.65), 0.65));
	if (lp.y > 1.5) {
		half_w = mix(1.58, 1.25, clamp((lp.y - 1.5) / 3.5, 0.0, 1.0));
	}
	vec2 q = vec2(abs(lp.x) - half_w, abs(lp.y + 0.15) - 5.15);
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0);
}

void vertex() {
	w_pos = (MODEL_MATRIX * vec4(VERTEX.x, VERTEX.y, VERTEX.z, 1.0)).xyz;
	float ground = ground_at(w_pos.xz);
	float shore_depth = max(sea_level - ground, 0.0);
	float shore_t = clamp(shore_depth / 4.0, 0.0, 1.0);
	float shore_wave_fade = shore_t * shore_t * (3.0 - 2.0 * shore_t);
	float hrip = spectrum_height(w_pos.xz, u_time, wind_dir, mega_amp, wind_power)
		* shore_wave_fade;

	// Локальный бурун непосредственно перед носом судна и вытеснение внутри корпуса
	vec2 ship_lp = to_ship_local(w_pos.xz, u_vessel_state.xy, u_vessel_state.z);
	float spd01 = clamp(abs(u_vessel_state.w) / 10.0, 0.0, 1.2);
	float d_bow = length(ship_lp - vec2(0.0, -5.2));
	float bow_crest = exp(-d_bow * d_bow * 0.55) * 0.18 * spd01;
	float d_hull = hull_sdf(ship_lp);
	float hull_cut = -(1.0 - smoothstep(-0.35, 0.20, d_hull)) * 0.30;

	float y = hrip + bow_crest + hull_cut;
	VERTEX.y += y;
	w_pos.y += y;
}

void fragment() {
	vec2 wp = w_pos.xz;
	vec2 wdir = normalize(wind_dir);

	float ground = ground_at(wp);
	float depth_m = w_pos.y - ground;
	if (depth_m < -0.08) {
		discard;
	}
	float near_shore = 1.0 - smoothstep(-0.08, 0.9, depth_m);

	vec3 L = normalize(sun_dir);
	vec3 N = vec3(0.0, 1.0, 0.0);

	float dist = length(CAMERA_POSITION_WORLD - w_pos);

	// Дисперсионные волны: нормаль — производная тех же высот, что у вершин.
	vec2 wave_grad = spectrum_gradient(wp, u_time, wind_dir, mega_amp, wind_power);
	N = normalize(N - vec3(wave_grad.x, 0.0, wave_grad.y)
		* (1.0 - 0.92 * near_shore));

	// ---------- локальная микрорябь без песчаных «сканлайнов» ----------
	// Три параллельных cos(dot(wp, wind)) из старой воды образовывали
	// бегущие светлые полосы. Вместо них — градиент двумерного шума в
	// МИРОВЫХ координатах: он адвектируется ветром, но не создаёт гребней.
	// Крупные волны остаются в spectrum_height/gradient и CPU-плавучести.
	// Один слой вместо двух: 3 выборки шума на пиксель, а не 6.
	vec2 flow = wp * 0.68 + wdir * u_time * 0.22;
	float n = vnoise(flow);
	vec2 micro_grad = vec2(vnoise(flow + vec2(0.18, 0.0)) - n,
		vnoise(flow + vec2(0.0, 0.18)) - n) * 4.4;
	micro_grad *= ripple_strength * wind_power * (1.0 - 0.88 * near_shore);
	N = normalize(N - vec3(micro_grad.x, 0.0, micro_grad.y) * 0.44);

	// ---------- точечные кольца событий (только от сбора пятен) ----------
	float rk = PI_2 / ring_len;
	vec2 rgrad = vec2(0.0);
	for (int i = 0; i < 24; i++) {
		vec4 rg = u_rings[i];
		if (rg.w < 0.0005) {
			continue;
		}
		float age = u_time - rg.z;
		if (age < 0.0) {
			continue;
		}
		vec2 d = wp - rg.xy;
		float dd = max(length(d), 0.0001);
		float rf = ring_speed * age;
		float bw = ring_w0 + ring_wg * age;
		float x = (dd - rf) / bw;
		float env = exp(-x * x);
		float ph = rk * (dd - rf);
		float dec = exp(-age * ring_tau) / sqrt(max(rf, 0.6));
		float a = ring_amp * rg.w * dec;
		float dhdd = a * (env * (-2.0 * x / bw) * cos(ph) - env * sin(ph) * rk);
		rgrad += (d / dd) * dhdd;
	}
	N = normalize(N - vec3(rgrad.x * ring_boost, 0.0, rgrad.y * ring_boost));

	// ---------- МИРОВОЙ КИЛЬВАТЕРНЫЙ СЛЕД ПО ИСТОРИЧЕСКОЙ ТРАЕКТОРИИ ----------
	vec2 ship_lp = to_ship_local(wp, u_vessel_state.xy, u_vessel_state.z);
	float spd01 = clamp(abs(u_vessel_state.w) / 10.0, 0.0, 1.25);
	float d_hull = hull_sdf(ship_lp);
	float turb_noise = vnoise(wp * 2.6 + vec2(0.0, -u_time * 1.8));
	float fine_noise = vnoise(wp * 6.2 + vec2(u_time * 1.1, -u_time * 2.4));

	// 1. Пенное обтекание непосредственно вдоль бортов корпуса и носового буруна
	float hull_collar = exp(-pow((d_hull - 0.10) / (0.18 + 0.12 * spd01), 2.0)) * step(-0.06, d_hull);
	hull_collar *= smoothstep(0.22, 0.75, turb_noise * 0.65 + fine_noise * 0.35);

	// 2. Поиск ближайшей точки на мировой кривой пути u_wake_trail[20]
	float best_d2 = 1e9;
	float best_age = 100.0;
	float best_spd = 0.0;
	vec2 best_normal_xz = vec2(0.0);

	for (int i = 0; i < 19; i++) {
		vec4 p0 = u_wake_trail[i];
		vec4 p1 = u_wake_trail[i + 1];
		float age0 = u_time - p0.z;
		float age1 = u_time - p1.z;
		if (age0 < 0.0 || age0 > 5.5 || age1 > 6.0) {
			continue;
		}
		vec2 seg = p1.xy - p0.xy;
		float seg_len2 = dot(seg, seg);
		float h_proj = (seg_len2 > 0.0001) ? clamp(dot(wp - p0.xy, seg) / seg_len2, 0.0, 1.0) : 0.0;
		vec2 closest = p0.xy + seg * h_proj;
		vec2 diff = wp - closest;
		float d2 = dot(diff, diff);
		if (d2 < best_d2) {
			best_d2 = d2;
			best_age = mix(age0, age1, h_proj);
			best_spd = mix(p0.w, p1.w, h_proj);
			best_normal_xz = (d2 > 1e-5) ? (diff / sqrt(d2)) : vec2(0.0);
		}
	}

	float trail_foam = 0.0;
	float trail_aerated = 0.0;
	if (best_age < 5.2 && best_spd > 0.4) {
		float perp_d = sqrt(best_d2);
		float local_spd01 = clamp(best_spd / 10.0, 0.0, 1.2);
		float age_fade = exp(-best_age * 0.55) * local_spd01;

		// Центральная турбулентная струя от винтов (расширяется со временем вдоль кривой пути)
		float wash_w = 0.55 + best_age * 0.36;
		float wash_env = exp(-pow(perp_d / wash_w, 2.0)) * age_fade;
		trail_foam += wash_env * smoothstep(0.24, 0.78, fine_noise * 0.55 + turb_noise * 0.45) * 0.90;
		trail_aerated = wash_env * 0.55;

		// Расходящиеся боковые волны Кельвина (фронт уходит в стороны от мировой траектории со скоростью волны)
		float kelvin_front = 0.65 + best_age * (1.25 + local_spd01 * 0.95);
		float d_front = perp_d - kelvin_front;
		float k_band = 0.45 + best_age * 0.22;
		float k_env = exp(-pow(d_front / k_band, 2.0)) * age_fade;
		float k_phase = d_front * 4.6;
		// Наклон нормалей воды на расходящихся волнах
		float k_slope = -sin(k_phase) * k_env * 0.58;
		N = normalize(N - vec3(best_normal_xz.x * k_slope, 0.0, best_normal_xz.y * k_slope));
		trail_foam += max(0.0, cos(k_phase)) * k_env * smoothstep(0.28, 0.76, turb_noise) * 0.72;
	}

	// 3. Обтекание буксируемого плашкоута (если прицеплен)
	float trailer_foam = 0.0;
	if (u_trailer_state.w > 0.5) {
		vec2 tr_lp = to_ship_local(wp, u_trailer_state.xy, u_trailer_state.z);
		vec2 tq = abs(tr_lp) - vec2(1.32, 3.0);
		float d_tr = length(max(tq, 0.0)) + min(max(tq.x, tq.y), 0.0);
		trailer_foam = exp(-pow((d_tr - 0.10) / 0.20, 2.0)) * step(-0.05, d_tr) * smoothstep(0.25, 0.75, turb_noise);
	}

	float ship_wake_foam = clamp(hull_collar * (0.65 + 0.45 * spd01) + trail_foam + trailer_foam * 0.70, 0.0, 1.0);

	// ---------- цвет воды ----------
	vec3 base = mix(water_shallow, water_mid, smoothstep(0.0, 3.0, depth_m));
	base = mix(base, water_deep, smoothstep(1.0, 12.0, depth_m));
	base = mix(base, water_shallow * 1.22, near_shore * 0.45);
	base = mix(base, water_shallow * 1.28, clamp(trail_aerated, 0.0, 0.55));

	// Периодические склоны волн НЕ должны полосами перекрашивать небо.
	// Ровный базовый свет; полный наклон волн остаётся для мелких бликов
	// и кильватера, а геометрия и CPU-плавучесть не меняются.
	vec3 N_ambient = vec3(0.0, 1.0, 0.0);
	float ndl = clamp(dot(N_ambient, L) * 0.5 + 0.5, 0.0, 1.0);
	base *= 0.80 + 0.32 * ndl;

	// ---------- френель: небо в воде ----------
	// Ортографическая камера: все лучи параллельны. Вектор от точки до
	// положения камеры создавал ложную сферическую область бликов в кадре.
	vec3 V = normalize((INV_VIEW_MATRIX * vec4(0.0, 0.0, 1.0, 0.0)).xyz);
	vec3 R = reflect(-V, N_ambient);
	float fres = pow(1.0 - clamp(dot(N_ambient, V), 0.0, 1.0), 3.2);
	vec3 sky_ref = mix(horizon_col, sky_col, smoothstep(0.02, 0.42, R.y));
	sky_ref = mix(sky_ref, sky_ref * vec3(0.60, 0.80, 1.02), 0.62);
	float mirror = clamp(0.05 + 0.92 * fres, 0.0, 0.88);
	mirror *= 1.0 - 0.18 * near_shore;
	base = mix(base, sky_ref, mirror);

	// ---------- солнечный глиттер ----------
	vec3 H = normalize(V + L);
	// Плотность мировых ячеек постоянна на экране ортографической камеры:
	// ступенчатый LOD по расстоянию рисовал заметные концентрические зоны.
	float density = 4.0;
	vec2 celluv = floor(wp * density);
	float cellid = hash12(celluv);
	float cellb = hash12(celluv + vec2(7.31, 1.77));
	float cellc = fract(cellid * 13.7);
	vec3 G = normalize(vec3(cellid - 0.5, 0.05 + 0.95 * cellb, cellc - 0.5));
	vec3 Hg = normalize(H + vec3(cellid - 0.5, cellb - 0.5, cellc - 0.5) * 0.55);
	float sun_lobe = pow(clamp(dot(N, Hg), 0.0, 1.0), mix(30.0, 110.0, cellb));
	float sky_lobe = pow(clamp(dot(G, V), 0.0, 1.0), mix(24.0, 80.0, cellc));
	float glit_chance = glitter_amount * 0.28;
	float glint = step(1.0 - glit_chance, cellid);
	float glit_fade = 0.95 * (1.0 - 0.72 * near_shore);
	base += sun_col * (sun_lobe * 1.6 + sky_lobe * 0.26) * glint * glit_fade;

	float path = pow(clamp(dot(N_ambient, H), 0.0, 1.0), 180.0);
	base += sun_col * path * 0.55 * sun_path_amount * (1.0 - 0.85 * near_shore);

	// ---------- пена прибоя + мировая кильватерная пена ----------
	float fn = vnoise(vec2(wp.x * 0.85 + u_time * 0.10, wp.y * 1.55));
	float fn2 = vnoise(vec2(wp.x * 3.2 - u_time * 0.38, wp.y * 2.35));
	float edge = exp(-pow((depth_m - 0.014 - 0.014 * sin(wp.x * 0.9 + u_time * 1.3)) / 0.075, 2.0));
	float edge2 = exp(-pow((depth_m - 0.17 - 0.03 * sin(wp.y * 0.21 + u_time * 1.15)) / 0.08, 2.0));
	float foam = edge * smoothstep(0.02, 0.40, fn) * (0.72 + 0.28 * fn2);
	foam += edge2 * smoothstep(0.45, 0.85, fn2) * 0.55;
	foam = clamp(max(foam, ship_wake_foam), 0.0, 1.0);
	base = mix(base, foam_col * (0.82 + 0.18 * ndl), foam * 0.92);

	// ---------- дымка к горизонту ----------
	float fog = 1.0 - exp(-pow(dist / fog_distance, 2.1));
	float above = smoothstep(-2.0, 16.0, w_pos.y - CAMERA_POSITION_WORLD.y);
	vec3 fcol = mix(horizon_col, sky_col, above * 0.6);
	ALBEDO = mix(base, fcol, fog);

	// Прямое освещение равномерно: периодическая нормаль спектра раньше
	// давала «сканлайны» даже при малом весе. Полная N остаётся в
	// микробликах, высота волн — в геометрии, пена — в цвете.
	NORMAL = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
	float rough = mix(0.29, 0.55, near_shore); // зыбь не должна давать белые зеркальные прямоугольники
	ROUGHNESS = mix(rough, 0.88, foam);
	SPECULAR = mix(0.55, 0.18, near_shore);
	METALLIC = 0.0;

	float shore_a = smoothstep(-0.08, 0.22, depth_m);
	float sea_a = shore_a;
	float a = max(sea_a, foam * 0.92);
	float sd = texture(depth_tex, SCREEN_UV).r;
	vec2 ndc_xy = SCREEN_UV * 2.0 - 1.0;
	vec4 ndc = vec4(ndc_xy.x, ndc_xy.y, sd, 1.0);
	vec4 vp = INV_PROJECTION_MATRIX * ndc;
	vp.xyz /= vp.w;
	float scene_z = -vp.z;
	float water_z = -VERTEX.z;
	float obj_a = smoothstep(0.0, shore_fade, scene_z - water_z);
	ALPHA = clamp(min(a, obj_a), 0.0, 1.0);
}

// Адаптация формул Proxima Diffuse + Schlick-GGX для A/B-теста воды.
// Источник: ElSuicio, 2026; MIT, godotshaders.com/shader/
// proxima-ggx-the-callisto-protocol-light-model/.
// Copyright (c) 2026 ElSuicio. Permission is hereby granted, free of charge,
// to any person obtaining a copy of this software and associated files, to
// deal in the Software without restriction, including without limitation the
// rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
// sell copies, subject to inclusion of this copyright and permission notice.
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND.
float proxima_h(float ctheta, float n, float cphi, float m) {
	return clamp(pow(max(1.0 - ctheta, 0.0), 5.0 * n)
		* pow(max(cphi, 0.0), 5.0 * m), 0.0, 1.0);
}

float proxima_r(float x) {
	return 2.0 * (1.0 - x);
}

float proxima_t(float x) {
	return clamp(x, 0.0, 1.0);
}

void light() {
	vec3 n = normalize(NORMAL);
	vec3 l = normalize(LIGHT);
	vec3 v = normalize(VIEW);
	float nl = max(dot(n, l), 0.0);
	float nv = clamp(dot(n, v), 1e-3, 1.0);
	if (nl > 0.0) {
	vec3 h = normalize(v + l);
	float nh = clamp(dot(h, n), 0.0, 1.0);
	float hl = clamp(dot(h, l), 0.0, 1.0);
	vec3 radiance = LIGHT_COLOR * ATTENUATION;

	if (proxima_test < 0.5) {
		float a = max(ROUGHNESS * ROUGHNESS, 0.002);
		float a2 = a * a;
		float q = 1.0 + (a2 - 1.0) * nh * nh;
		float d = a2 / (PI * q * q);
		float k = pow(ROUGHNESS + 1.0, 2.0) * 0.125;
		float gl = nl / (nl * (1.0 - k) + k);
		float gv = nv / (nv * (1.0 - k) + k);
		vec3 f0 = mix(vec3(0.04 * proxima_specular_strength), ALBEDO, METALLIC);
		vec3 f = f0 + (1.0 - f0) * pow(1.0 - hl, 5.0);
		float fd90 = 0.5 + 2.0 * ROUGHNESS * hl * hl;
		float burley_l = 1.0 + (fd90 - 1.0) * pow(1.0 - nl, 5.0);
		float burley_v = 1.0 + (fd90 - 1.0) * pow(1.0 - nv, 5.0);
		DIFFUSE_LIGHT += radiance * ALBEDO * (1.0 / PI)
			* burley_l * burley_v * nl;
		SPECULAR_LIGHT += radiance * d * gl * gv * f * direct_specular_amount
			/ max(4.0 * nl * nv, 1e-3);
	} else {
	float alpha = ROUGHNESS * ROUGHNESS;
	float alpha2 = alpha * alpha;
	float vdl = max(dot(-v, l), 0.0);
	float theta_h = acos(nh);
	float theta_d = acos(hl);
	float alpha_f = proxima_h(hl, proxima_r(proxima_diffuse_fresnel_falloff),
		nh, proxima_r(proxima_diffuse_tangent_falloff));
	float alpha_r = proxima_h(nh, proxima_r(proxima_retroreflection_falloff),
		hl, proxima_r(proxima_retroreflection_tangent_falloff));
	float alpha_s = (1.0 - pow(1.0 - theta_d, 3.0))
		* (1.0 - pow(1.0 - theta_h, 3.0));
	vec3 rho_f = proxima_diffuse_fresnel * proxima_diffuse_fresnel_tint;
	vec3 rho_r = proxima_retroreflection * proxima_retroreflection_tint;
	vec3 c1 = mix(vec3(1.0), rho_f, alpha_f)
		* mix(vec3(1.0), rho_r, alpha_r);
	float smooth_term = mix(1.0, smoothstep(0.0,
		max(alpha_s * proxima_smooth_terminator_length, 1e-4), nl),
		alpha_s * proxima_smooth_terminator);
	vec3 fd = c1 * (1.0 / PI)
		* (alpha * (-0.55 + 0.19 / max(nl, 1e-3))
		* (1.0 - sqrt(vdl)) + 1.0) * smooth_term * nl;

	float t = 1.0 + (alpha2 - 1.0) * nh * nh;
	float d = alpha2 / (PI * t * t);
	float gl = 1.0 / (nl + sqrt(alpha2 + (1.0 - alpha2) * nl * nl));
	float gv = 1.0 / (nv + sqrt(alpha2 + (1.0 - alpha2) * nv * nv));
	vec3 f0 = mix(vec3(proxima_specular_strength * 0.08), ALBEDO, vec3(METALLIC));
	float fh = pow(clamp(1.0 - hl, 0.0, 1.0),
		5.0 * proxima_r(proxima_specular_fresnel_falloff));
	vec3 fresnel = f0 + proxima_t(2.0
		- proxima_r(proxima_specular_fresnel_falloff)) * (1.0 - f0) * fh;
	vec3 fs = d * gl * gv * fresnel * nl;
	DIFFUSE_LIGHT += radiance * fd;
	SPECULAR_LIGHT += radiance * fs * direct_specular_amount;
	}
	}
}
```

## `scripts/boat_smoke.gd`

```gdscript
class_name BoatSmoke
extends Node
## Headless-проверка нового цикла, не заменяет тесты старой рыбалки.
var main: BoatMain
var ticks := 0
var origin := Vector3.ZERO
var failures := 0
var trail_sample := Vector4.ZERO


func setup(boat_main: BoatMain) -> void:
	main = boat_main
	origin = main.boat.global_position


func _physics_process(_delta: float) -> void:
	ticks += 1
	if ticks == 1:
		_check(main.water != null and main.water.field != null, "волны CPU + шейдерное море")
		_check(main.coast.water_depth(origin.x, origin.z) > 2.0, "лодка спущена на глубокую воду")
		_check(main.slicks.size() >= 6, "SDF-пятна распределены вокруг лодки")
		_check(main.camera.projection == Camera3D.PROJECTION_ORTHOGONAL, "изометрическая камера")
		Input.action_press("boat_forward")
	if ticks == 60:
		trail_sample = main.boat._trail_buffer[2]
		main.boat.rotation.y += 0.35
	if ticks == 61:
		var kept := false
		for i in range(2, BoatVessel.TRAIL_POINTS):
			var old: Vector4 = main.boat._trail_buffer[i]
			if Vector2(old.x, old.y).distance_to(Vector2(trail_sample.x, trail_sample.y)) < 0.001:
				kept = true
				break
		_check(kept and trail_sample.z > 0.0,
			"старый участок кильватера остаётся в мировых координатах при повороте")
	if ticks == 70:
		Input.action_release("boat_forward")
		_check(main.boat.global_position.distance_to(origin) > 1.0, "мотор двигает лодку")
		var first := main.slicks[0]
		main.boat.global_position = first.global_position - Vector3(4.0, 0.0, 1.0)
		main.boat.speed = 0.0
		Input.action_press("boat_pump")
	if ticks == 73:
		_check(main.boat.wrong_side_target and main.raw[0] == 0 and
			main.boat.pump_fraction() == 0.0, "насос не проходит через правый борт")
		var first := main.slicks[0]
		main.boat.global_position = first.global_position + Vector3(4.0, 0.0, 1.0)
	if ticks == 185:
		Input.action_release("boat_pump")
		_check(main.raw[0] == 1 and main.slicks[0].depleted, "насос собирает одно пятно")
		main.receive_resource(0)
		main.receive_resource(0)
		_check(main.refine() == 1 and main.refined[0] == 1 and main.raw[0] == 0,
			"три единицы сырья превращаются в один очищенный материал")
		_check(not main.boat.has_trailer and main.boat.effective_max_speed() == 10.0,
			"прицеп изначально не куплен")
		main.refined[1] = 1
		main.buy_trailer()
		_check(main.boat.has_trailer and main.total_refined() == 0,
			"прицеп покупается за два готовых материала")
		var trailer_before := main.boat._trailer.global_position
		var reverse_next := main.boat.global_position + main.boat.global_transform.basis.z * 2.0
		var can_reverse := main.boat._make_room_for_trailer(reverse_next)
		var trailer_after := main.boat._trailer.global_position
		var clearance := Vector2(trailer_after.x - reverse_next.x,
			trailer_after.z - reverse_next.z).length()
		_check(can_reverse and trailer_after.distance_to(trailer_before) > 0.5 and
			clearance >= BoatVessel.TRAILER_CLEARANCE - 0.001,
			"задний ход отталкивает прицеп, корпуса не пересекаются")
		main.raw[2] = 2
		_check(main.refine() == 1 and main.refined[2] == 1 and main.raw[2] == 0,
			"прицеп снижает цену переработки до двух единиц сырья")
		_check(main.boat.effective_max_speed() > 10.0 and
			main.boat.effective_pump_range() > BoatVessel.PUMP_RANGE,
			"прицеп усиливает мотор и насос")
		main.toggle_trailer_free()
		_check(not main.boat.has_trailer, "тестовая клавиша отключает прицеп")
		# В новом районе пятна должны появляться снова, не оставаясь навсегда
		# в стартовом круге. Уходим в открытое море, не заходя на берег.
		main.boat.global_position = origin + Vector3(-220.0, 0.0, 0.0)
		main.boat.speed = 0.0
		# Тест телепортирует лодку; для проверки видимого кадра переносим
		# камеру тоже. При обычной езде она остаётся плавной и инерционной.
		main._camera_focus = main.boat.global_position + Vector3.UP * 0.8
		main.camera.global_position = main._camera_focus + Vector3(21.0, 26.2, 30.0)
		main.camera.look_at(main._camera_focus, Vector3.UP)
		# На экране игра переселяет не более одного пятна за тик.
		for _i in range(main.slicks.size()):
			main._stream_resources()
		var nearby := 0
		var popped_in_view := 0
		for slick in main.slicks:
			if slick.depleted:
				continue
			var slick_xz := Vector2(slick.position.x, slick.position.z)
			if slick_xz.distance_to(Vector2(main.boat.global_position.x,
				main.boat.global_position.z)) < BoatMain.SLICK_RECYCLE_DISTANCE:
				nearby += 1
				if not main._outside_boat_view(slick_xz):
					popped_in_view += 1
		_check(nearby >= 4, "пятна появляются близко к лодке в новом районе")
		_check(popped_in_view == 0, "перемещённые пятна не возникают в кадре")
		print("[BOAT SMOKE] итог: %s" % ("ВСЁ ПРОШЛО" if failures == 0 else "%d ОШИБОК" % failures))
		get_tree().quit(0 if failures == 0 else 1)


func _check(ok: bool, description: String) -> void:
	if ok:
		print("[BOAT SMOKE] PASS ", description)
	else:
		failures += 1
		push_error("[BOAT SMOKE] FAIL " + description)
```
