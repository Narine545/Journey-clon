# Исходный код лодки и воды — To The Light

Только текст: точные исходники из файлов проекта Godot 4.7, без изображений, `.godot/`, `.git/` и архивов. Каждая секция подписана путём исходного файла; код можно копировать обратно в этот путь.

Сцена собирается в `scripts/boat_main.gd`: лодка, водная поверхность, пятна и HUD. Управление/качка/насос — `scripts/boat_vessel.gd`; размещение пятен — `scripts/boat_main.gd`; шейдер пятен — `shaders/resource_slick.gdshader`. Пятна, оставшиеся далеко позади лодки, переиспользуются за кадром.

Дополнительные текстовые зависимости: [берег](https://github.com/Narine545/Journey-clon/blob/arena/c0cfd826-journey-clon/scripts/coast.gd), [песок](https://github.com/Narine545/Journey-clon/blob/arena/c0cfd826-journey-clon/scripts/sand_field.gd), [мир/освещение](https://github.com/Narine545/Journey-clon/blob/arena/c0cfd826-journey-clon/scripts/world.gd), [глобальное состояние](https://github.com/Narine545/Journey-clon/blob/arena/c0cfd826-journey-clon/scripts/game.gd), [шейдер песка](https://github.com/Narine545/Journey-clon/blob/arena/c0cfd826-journey-clon/shaders/sand.gdshader), [шейдер неба](https://github.com/Narine545/Journey-clon/blob/arena/c0cfd826-journey-clon/shaders/sky_plus.gdshader).

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
## Небо/атмосфера, песчаный берег, вода и её CPU-зеркало волн — из проекта.

const START_Z := Coast.SPAWN_Z
const START_SEAWARD := 95.0
# Пул пятен остаётся постоянным, но переставляется за пределами экрана:
# игрок не должен навсегда терять ресурсы после ухода от стартового района.
const SLICK_RECYCLE_DISTANCE := 72.0
const SLICK_SPAWN_MIN := 28.0
const SLICK_SPAWN_MAX := 47.0

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
var _stream_timer := 0.0
var _slick_rng := RandomNumberGenerator.new()


func _ready() -> void:
	game = get_node("/root/Game") as GameState
	world = GameWorld.new()
	add_child(world)
	world.setup(game)
	# Из ветки башни взяты более мягкие облака и воздушная перспектива,
	# но не её высотный туман: он скрывал бы поверхность у уровня моря.
	coast = Coast.new()
	add_child(coast)
	coast.setup(game)
	sand = SandField.new()
	add_child(sand)
	sand.setup(game)
	coast.attach_sand(sand)
	water = WaterSurface.new()
	add_child(water)
	water.setup(game, Vector2(-150.0, 20.0), Coast.SEA_LEVEL)
	water.set_ground(coast.height_tex, coast.grid_origin, coast.grid_cell, coast.grid_n, coast)
	game.water = water
	boat = BoatVessel.new()
	boat.name = "Vessel"
	add_child(boat)
	boat.global_position = Vector3(coast.shore_x(START_Z) - START_SEAWARD, 0.2, START_Z)
	boat.setup(self, water, coast)
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
	camera.position = boat.global_position + Vector3(21.0, 27.0, 30.0)
	camera.look_at(boat.global_position + Vector3.UP * 0.8, Vector3.UP)
	hud = BoatHud.new()
	var layer := CanvasLayer.new()
	layer.layer = 12
	add_child(layer)
	hud.main = self
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(hud)
	_ensure_boat_input()
	world.apply_night01(0.0)
	coast.set_night01(0.0)
	water.apply_night01(0.0)
	# В архивной сцене солнце низкое и золотое. В изометрии это делало
	# открытое море почти целиком шоколадным: поднимаем солнце и оставляем
	# тёплые акценты на самом судне, воде даём прохладную глубину.
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
	water.set_param("glitter_amount", 0.05)
	water.set_param("solar_glitter_amount", 0.018)
	water.set_param("sun_path_amount", 0.13)
	# GGX прямого света всё ещё давал белое пятно под лодкой даже при
	# приглушённой нарисованной дорожке. Старая сцена сохраняет исходный свет.
	water.set_param("direct_specular_amount", 0.07)
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


func _stream_resources() -> void:
	var center := Vector2(boat.global_position.x, boat.global_position.z)
	for slick in slicks:
		if slick.depleted:
			continue # таймер повторного появления нельзя обойти перемещением
		var current := Vector2(slick.position.x, slick.position.z)
		if current.distance_to(center) <= SLICK_RECYCLE_DISTANCE:
			continue
		# Только ушедшие далеко за пределы кадра пятна получают новое место.
		# До подхода игрока позиция остаётся постоянной (без мигания/телепорта).
		for _attempt in range(24):
			var angle := _slick_rng.randf_range(-PI, PI)
			var distance := _slick_rng.randf_range(SLICK_SPAWN_MIN, SLICK_SPAWN_MAX)
			var candidate := center + Vector2.from_angle(angle) * distance
			if coast.water_depth(candidate.x, candidate.y) < 3.0:
				continue
			var clear := true
			for other in slicks:
				if other == slick or other.depleted:
					continue
				if candidate.distance_to(Vector2(other.position.x, other.position.z)) < 9.0:
					clear = false
					break
			if clear:
				slick.position = Vector3(candidate.x,
					water.surface_height(candidate.x, candidate.y) + 0.20, candidate.y)
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


func refine() -> int:
	var produced := 0
	for i in range(raw.size()):
		var batches := int(raw[i] / 3.0)
		raw[i] -= batches * 3
		refined[i] += batches
		produced += batches
	announce("ПЕРЕРАБОТАНО: %d" % produced if produced > 0 else "НУЖНО ТРИ ПЯТНА ОДНОГО ЦВЕТА")
	return produced


func announce(text: String) -> void:
	notice = text
	notice_time = 2.8


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_R:
		refine()
		get_viewport().set_input_as_handled()
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera.size = maxf(16.0, camera.size - 2.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera.size = minf(42.0, camera.size + 2.0)


func _process(delta: float) -> void:
	if boat == null or camera == null:
		return
	var target := boat.global_position + Vector3.UP * 0.8
	var desired := target + Vector3(21.0, 27.0, 30.0)
	camera.global_position = camera.global_position.lerp(desired, 1.0 - exp(-3.0 * delta))
	camera.look_at(target, Vector3.UP)
	notice_time = maxf(0.0, notice_time - delta)
	_stream_timer -= delta
	if _stream_timer <= 0.0:
		_stream_timer = 0.5
		_stream_resources()
	hud.queue_redraw()
	if OS.get_environment("JOURNEY_BOAT_SHOT") == "1":
		_capture_frames += 1
		if _capture_frames == 35:
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
## Лодка с мотором и насосом: управляемая инерция и качка на WaterField.
## Корпус и каюта пока наружные; интерьер и прицеп — следующие этапы.

const MAX_SPEED := 10.0
const REVERSE_SPEED := 4.0
const ACCELERATION := 3.2
const DRAG := 1.8
const TURN_RATE := 0.95
const PUMP_RANGE := 6.0
const PUMP_SECONDS := 1.4

var main: BoatMain
var water: WaterSurface
var coast: Coast
var speed := 0.0
var _wake_timer := 0.0
var _pump_progress := 0.0
var _target: ResourceSlick
var _body: Node3D
var _hose: MeshInstance3D
var _nozzle := Vector3(-1.65, 0.05, 0.3)


func setup(boat_main: BoatMain, water_ref: WaterSurface, coast_ref: Coast) -> void:
	main = boat_main
	water = water_ref
	coast = coast_ref
	_body = Node3D.new()
	_body.name = "HullAndCabin"
	add_child(_body)
	_build_appearance()


func _physics_process(delta: float) -> void:
	if water == null or coast == null:
		return
	var throttle := Input.get_axis("boat_reverse", "boat_forward")
	var steer := Input.get_axis("boat_left", "boat_right")
	var target_speed := throttle * (MAX_SPEED if throttle >= 0.0 else REVERSE_SPEED)
	speed = move_toward(speed, target_speed, (ACCELERATION if absf(throttle) > 0.01 else DRAG) * delta)
	# Направление поворота зависит от движения: задним ходом руль инвертируется.
	rotation.y += steer * TURN_RATE * delta * clampf(absf(speed) / 3.5, 0.0, 1.0) * (1.0 if speed >= 0.0 else -1.0)
	var heading := -global_transform.basis.z
	var next := global_position + heading * speed * delta
	if coast.water_depth(next.x, next.z) > 1.7:
		global_position = next
	else:
		speed = minf(speed, 0.0) # берег — преграда, а не невидимая телепортация
	var surface := water.surface_height(global_position.x, global_position.z)
	global_position.y = lerpf(global_position.y, surface + 0.10, minf(1.0, delta * 3.0))
	var bow := global_position + heading * 2.8
	var stern := global_position - heading * 2.8
	var right := global_transform.basis.x
	var port := global_position - right * 1.3
	var starboard := global_position + right * 1.3
	var pitch := atan2(water.surface_height(bow.x, bow.z) - water.surface_height(stern.x, stern.z), 5.6)
	var roll := atan2(water.surface_height(starboard.x, starboard.z) - water.surface_height(port.x, port.z), 2.6)
	_body.rotation.x = lerpf(_body.rotation.x, pitch, minf(1.0, delta * 3.0))
	_body.rotation.z = lerpf(_body.rotation.z, roll - steer * absf(speed) * 0.004, minf(1.0, delta * 3.0))
	_wake_timer -= delta
	if absf(speed) > 1.2 and _wake_timer <= 0.0:
		_wake_timer = 0.33
		var tail := global_position - heading * 3.0
		water.field.wake(Vector2(tail.x, tail.z), clampf(absf(speed) / 6.0, 0.2, 1.5))
	_update_pump(delta)


func _update_pump(delta: float) -> void:
	_target = main.nearest_resource(global_position, PUMP_RANGE)
	var drawing := Input.is_action_pressed("boat_pump") and _target != null and absf(speed) < 5.0
	if drawing:
		_pump_progress += delta
		var from := _body.to_global(_nozzle)
		var to := _target.global_position + Vector3.UP * 0.12
		_hose.visible = true
		_hose.global_position = (from + to) * 0.5
		_hose.global_basis = Basis(Quaternion(Vector3.UP, (to - from).normalized()))
		_hose.scale.y = from.distance_to(to)
		if _pump_progress >= PUMP_SECONDS:
			main.receive_resource(_target.kind)
			_target.collect()
			_pump_progress = 0.0
	else:
		_pump_progress = maxf(0.0, _pump_progress - delta * 2.0)
		_hose.visible = false


func pump_fraction() -> float:
	return clampf(_pump_progress / PUMP_SECONDS, 0.0, 1.0)


func target_name() -> String:
	return ResourceSlick.NAMES[_target.kind] if _target != null else ""


func _material(color: Color, metal := 0.0, glow := 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = metal
	mat.roughness = 0.58
	if glow > 0.0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = glow
	return mat


func _box(at: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	part.mesh = box
	part.position = at
	part.material_override = mat
	_body.add_child(part)
	return part


func _triangle(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	tool.add_vertex(a)
	tool.add_vertex(b)
	tool.add_vertex(c)


func _build_appearance() -> void:
	# Палитра: графитовый корпус, глубокий петроль, меловая каюта,
	# медная механика и четыре чистых акцентных цвета собранных ресурсов.
	var hull := _material(Color("203343"), 0.36)
	var hull_edge := _material(Color("315968"), 0.30)
	var cabin := _material(Color("eee5d1"), 0.07)
	var roof := _material(Color("318982"), 0.30)
	var glass := _material(Color("244956"), 0.20)
	var copper := _material(Color("d48d60"), 0.65)
	var dark := _material(Color("142833"), 0.55)
	_box(Vector3(0, -0.42, 0), Vector3(3.0, 0.85, 7.1), hull)
	_box(Vector3(0, 0.04, 0), Vector3(3.18, 0.14, 6.85), hull_edge)
	# Нос треугольный В ГОРИЗОНТАЛЬНОЙ плоскости. Готовый PrismMesh
	# после поворота давал вертикальный чёрный «парус» вместо носа.
	var prow := MeshInstance3D.new()
	var triangles := SurfaceTool.new()
	triangles.begin(Mesh.PRIMITIVE_TRIANGLES)
	var lp := Vector3(-1.5, 0.02, -3.25)
	var rp := Vector3(1.5, 0.02, -3.25)
	var tip := Vector3(0.0, 0.02, -5.0)
	var lp_low := lp + Vector3.DOWN * 0.75
	var rp_low := rp + Vector3.DOWN * 0.75
	var tip_low := tip + Vector3.DOWN * 0.75
	_triangle(triangles, lp, rp, tip) # палуба
	_triangle(triangles, lp_low, tip_low, rp_low) # днище
	_triangle(triangles, lp, tip, tip_low)
	_triangle(triangles, lp, tip_low, lp_low)
	_triangle(triangles, rp, rp_low, tip_low)
	_triangle(triangles, rp, tip_low, tip)
	triangles.generate_normals()
	prow.mesh = triangles.commit()
	prow.material_override = hull
	_body.add_child(prow)
	_box(Vector3(0, 0.13, -0.4), Vector3(2.83, 0.09, 5.9), _material(Color("8d7762")))
	# Каюта ближе к корме; окна визуально доступны при изометрическом взгляде.
	_box(Vector3(0, 0.90, 0.65), Vector3(2.35, 1.55, 2.75), cabin)
	_box(Vector3(0, 1.76, 0.65), Vector3(2.65, 0.23, 3.02), roof)
	_box(Vector3(0, 1.17, -0.76), Vector3(1.72, 0.73, 0.055), glass)
	for side in [-1.0, 1.0]:
		_box(Vector3(side * 1.19, 1.17, 0.56), Vector3(0.065, 0.68, 1.72), glass)
		_box(Vector3(side * 1.34, 0.23, -2.16), Vector3(0.055, 0.23, 2.4), copper)
		_box(Vector3(side * 1.34, 0.23, 2.45), Vector3(0.055, 0.23, 1.15), copper)
	_box(Vector3(0, 0.36, 3.30), Vector3(2.20, 0.6, 0.83), dark) # моторный кожух
	_box(Vector3(0, 0.62, 3.18), Vector3(0.38, 0.28, 0.52), copper)
	_box(Vector3(-1.53, 0.25, 0.30), Vector3(0.30, 0.62, 0.62), copper) # насос
	_box(Vector3(-1.79, 0.0, 0.30), Vector3(0.32, 0.11, 0.11), dark)
	var lantern := OmniLight3D.new()
	lantern.light_color = Color("ffc993")
	lantern.light_energy = 0.7
	lantern.omni_range = 7.0
	lantern.position = Vector3(0, 2.02, 0.66)
	_body.add_child(lantern)
	_hose = MeshInstance3D.new()
	var tube := CylinderMesh.new()
	tube.top_radius = 0.052
	tube.bottom_radius = 0.095
	tube.height = 1.0
	_hose.mesh = tube
	_hose.material_override = _material(Color("7ee1c9"), 0.08, 0.9)
	_hose.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_hose.visible = false
	add_child(_hose)
```

## `scripts/resource_slick.gd`

```gdscript
class_name ResourceSlick
extends MeshInstance3D
## Отдельный SDF-материал на каждый цветной метабол.

const SHADER := preload("res://shaders/resource_slick.gdshader")
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


func setup(water: WaterSurface, at: Vector2, resource_kind: int, variation: float) -> void:
	_water = water
	kind = resource_kind % COLORS.size()
	position = Vector3(at.x, water.level_y + 0.20, at.y)
	var plane := PlaneMesh.new()
	plane.size = Vector2(5.6, 5.6)
	mesh = plane
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_mat.set_shader_parameter("pigment", COLORS[kind])
	_mat.set_shader_parameter("seed", variation)
	material_override = _mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sorting_offset = 100.0 # поверх прозрачной воды, без вмешательства в шейдер моря


func _process(delta: float) -> void:
	_age += delta
	if depleted:
		_respawn -= delta
		if _respawn <= 0.0:
			depleted = false
			visible = true
		return
	if _water != null:
		# Поле волн работает на CPU и GPU — пятно следует той же поверхности.
		position.y = _water.surface_height(position.x, position.z) + 0.20
	if _mat != null:
		_mat.set_shader_parameter("pulse", 0.5 + 0.5 * sin(_age * 2.2))


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
varying vec2 local_pos;

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

## `scripts/boat_hud.gd`

```gdscript
class_name BoatHud
extends Control
## Лёгкий интерфейс без экранной цветокоррекции: чистые пигменты остаются чистыми.
var main: BoatMain

func _draw() -> void:
	if main == null or main.boat == null:
		return
	var font := ThemeDB.fallback_font
	var ink := Color("e9f0e8")
	var muted := Color("9db8b7")
	var backdrop := Color(0.035, 0.075, 0.10, 0.88)
	var panel := Rect2(22, 22, 380, 244)
	draw_rect(panel, backdrop)
	draw_rect(panel, Color("548c89"), false, 1.5)
	draw_string(font, Vector2(42, 53), "ПРИЛИВНАЯ ЛАБОРАТОРИЯ", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, ink)
	draw_string(font, Vector2(42, 78), "СКОРОСТЬ  %02.0f / 10     НАСОС  %s" % [absf(main.boat.speed), "АКТИВЕН" if main.boat.pump_fraction() > 0.0 else "ГОТОВ"], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, muted)
	for i in range(ResourceSlick.COLORS.size()):
		var y := 105.0 + float(i) * 32.0
		draw_rect(Rect2(42, y - 15, 13, 13), ResourceSlick.COLORS[i])
		draw_string(font, Vector2(65, y - 3), ResourceSlick.NAMES[i].to_upper(), HORIZONTAL_ALIGNMENT_LEFT, 122, 15, ink)
		draw_string(font, Vector2(235, y - 3), "%02d сыр.  →  %02d гот." % [main.raw[i], main.refined[i]], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, muted)
	var resource_name := main.boat.target_name()
	var action := "ПРОБЕЛ — ЗАБРАТЬ: %s" % resource_name.to_upper() if not resource_name.is_empty() else "ИЩИТЕ СВЕТЯЩИЕСЯ ПЯТНА"
	var center := Vector2(size.x * 0.5 - 195.0, size.y - 134.0)
	draw_rect(Rect2(center, Vector2(390, 38)), backdrop)
	draw_string(font, center + Vector2(14, 26), action, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, ink)
	if main.boat.pump_fraction() > 0.0:
		draw_rect(Rect2(center + Vector2(0, 36), Vector2(390.0 * main.boat.pump_fraction(), 3)), Color("78dfcb"))
	var controls := "W/S — ДВИГАТЕЛЬ     A/D — РУЛЬ     ПРОБЕЛ — НАСОС     R — ПЕРЕРАБОТАТЬ     КОЛЕСО — МАСШТАБ"
	draw_string(font, Vector2(28, size.y - 28), controls, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, ink)
	if main.notice_time > 0.0:
		draw_string(font, Vector2(size.x * 0.5 - 230, size.y - 168), main.notice, HORIZONTAL_ALIGNMENT_CENTER, 460, 17, Color("f3c783"))
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
	if ticks == 70:
		Input.action_release("boat_forward")
		_check(main.boat.global_position.distance_to(origin) > 1.0, "мотор двигает лодку")
		var first := main.slicks[0]
		main.boat.global_position = first.global_position + Vector3(0.0, 0.0, 4.0)
		main.boat.speed = 0.0
		Input.action_press("boat_pump")
	if ticks == 185:
		Input.action_release("boat_pump")
		_check(main.raw[0] == 1 and main.slicks[0].depleted, "насос собирает одно пятно")
		main.receive_resource(0)
		main.receive_resource(0)
		_check(main.refine() == 1 and main.refined[0] == 1 and main.raw[0] == 0,
			"три единицы сырья превращаются в один очищенный материал")
		# В новом районе пятна должны появляться снова, не оставаясь навсегда
		# в стартовом круге. Уходим в открытое море, не заходя на берег.
		main.boat.global_position = origin + Vector3(-105.0, 0.0, 0.0)
		main.boat.speed = 0.0
		main._stream_resources()
		var nearby := 0
		for slick in main.slicks:
			if not slick.depleted and Vector2(slick.position.x, slick.position.z).distance_to(
				Vector2(main.boat.global_position.x, main.boat.global_position.z)) < 52.0:
				nearby += 1
		_check(nearby >= 4, "пятна появляются в новом районе после плавания")
		print("[BOAT SMOKE] итог: %s" % ("ВСЁ ПРОШЛО" if failures == 0 else "%d ОШИБОК" % failures))
		get_tree().quit(0 if failures == 0 else 1)


func _check(ok: bool, description: String) -> void:
	if ok:
		print("[BOAT SMOKE] PASS ", description)
	else:
		failures += 1
		push_error("[BOAT SMOKE] FAIL " + description)
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
	_mat.shader = load(SHADER_PATH)
	if game != null:
		_mat.set_shader_parameter("sun_dir", game.sun_dir)
		_mat.set_shader_parameter("fog_distance", game.FOG_DISTANCE)
	# уровень моря: шейдер вычисляет глубину у кромки берега
	_mat.set_shader_parameter("sea_level", level_y)
	material_override = _mat
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
	if t - _last_wake < 0.33:
		return
	_last_wake = t
	_add_ring(pos, 0.30 * clampf(strength, 0.0, 2.0))


## Высота воды в точке СЕЙЧАС: дыхание (мега-рябь) + все живые кольца.
## Зеркало шейдерной математики (mega_phase + кольца) — поплавок и физика
## качаются ровно на той воде, которую рисует шейдер.
func height_at(x: float, z: float) -> float:
	var h := _mega_h_cpu(x, z)
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
		h += RING_AMP * a * env * cos(ph) * dec
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


func _process(delta: float) -> void:
	t += delta
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


func _mega_h_cpu(x: float, z: float) -> float:
	var wdir := wind_dir.normalized() if wind_dir.length_squared() > 0.0001 else Vector2(0.32, -0.95)
	var wperp := Vector2(-wdir.y, wdir.x)
	var wp := Vector2(x, z)
	var u := wp.dot(wdir)
	var v := wp.dot(wperp)

	var rn := _vnoise(wp * 0.15)
	var rn2 := _vnoise(wp * 0.07 + Vector2(9.1, 3.3))

	var mph := v * 0.70 + u * 0.16 + rn * 2.6 + rn2 * 3.4 + t * 0.25

	return (cos(mph) * 0.62 + cos(mph * 2.63 + 1.7) * 0.30
			+ cos(mph * 0.47 + 0.8) * 0.22) * mega_amp * wind_power # ровно как в шейдере
```

## `shaders/water.gdshader`

```glsl
shader_type spatial;
// МОРЕ — отдельная стихия рядом с тёплым песком.
//
// Палитра намеренно НЕ песочная: мелководье — бирюза, глубина — синий
// индиго, под скользящим взглядом поверхность зеркалит небо и ловит
// солнечную дорожку. Поэтому суша и вода читаются как два разных
// материала даже на горизонте.
//
// Урез. Море получает от Coast карту высот поверхности (height_tex) —
// ровно ту, по которой построен меш берега. По ней:
//   • глубина честная и считается ПО ФРАГМЕНТУ (высота воды минус
//     высота песка в этом пикселе), поэтому кромка — ровная линия по
//     рельефу, а не граница треугольников;
//   • поверхность воды — ровная плоскость (море + дыхание), она
//     пересекает песок по мокрой кайме; никакой «плёнки», висящей над
//     бугристым пляжем, поэтому нет ни лоскутов, ни пластин;
//   • дыхание моря затухает к кромке, зато накат ползёт по пляжу;
//   • альфа растёт от нуля по глубине — переход вода↔суша плавный;
//   • пена двумя полосами по контуру глубины с рваным шумом.
//
// Кольца событий (всплеск поплавка, поклёвка, подмотка) — единственный
// «водный» слой, который отвечает на действия игрока.

render_mode diffuse_burley, specular_schlick_ggx, blend_mix, depth_draw_always;

// ---- Вода: своя палитра, не песок ----
uniform vec3 water_shallow : source_color = vec3(0.30, 0.66, 0.62);
uniform vec3 water_mid : source_color = vec3(0.10, 0.38, 0.48);
uniform vec3 water_deep : source_color = vec3(0.035, 0.150, 0.300);
uniform vec3 foam_col : source_color = vec3(0.95, 0.92, 0.86);
uniform vec3 sun_col : source_color = vec3(1.0, 0.80, 0.52);
uniform vec3 sun_dir = vec3(0.10, 0.26, -0.96); // к солнцу (как у песка)

// ---- Небо/дымка (общие с песком) ----
uniform vec3 horizon_col : source_color = vec3(0.96, 0.66, 0.55);
uniform vec3 sky_col : source_color = vec3(0.28, 0.24, 0.43);
uniform float fog_distance = 340.0;

// ---- Ветер: один вектор на всю игру ----
uniform vec2 wind_dir = vec2(0.32, -0.95);
uniform float wind_power = 1.0;

// ---- Дыхание моря: та же мега-рябь, что у песка (слой 2, ~9 м) ----
uniform float mega_amp = 0.055;

// ---- Мелкая рябь (только нормали) ----
uniform float ripple_freq = 1.35;
uniform float ripple_speed = 1.1;
uniform float ripple_strength = 0.34;
uniform float glitter_amount = 1.0; // общий мелкий глиттер поверхности
uniform float solar_glitter_amount = 1.0; // отдельные частицы солнечной дорожки
uniform float sun_path_amount = 1.0; // отдельный контроль широкого солнечного пятна
uniform float direct_specular_amount = 1.0; // яркость прямого GGX-отражения солнца
// Временный A/B-тест прямого света: Proxima diffuse + Schlick-GGX.
// По умолчанию выключен, солнечный глиттер от него не зависит.
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

// ---- Кольца событий ----
uniform float ring_amp = 0.055;
uniform float ring_speed = 1.5;
uniform float ring_len = 0.85;
uniform float ring_tau = 0.55;
uniform float ring_w0 = 0.30;
uniform float ring_wg = 0.18;
uniform float ring_boost = 1.4;

uniform float u_time = 0.0;

// ---- Берег: карта высот и мягкий стык ----
uniform sampler2D ground_tex : filter_linear, repeat_disable;
uniform vec2 ground_origin = vec2(-280.0, -450.0);
uniform float ground_cell = 1.184;
uniform float ground_n = 761.0;
uniform float sea_level = 0.0;
uniform float shore_fade = 0.03; // м, мягкость стыка с предметами по depth

uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform vec4 u_rings[24]; // x, z, t0, amp; amp <= 0.0005 — слот пуст

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

float mega_phase(vec2 wp, vec2 wdir, vec2 wperp) {
	float u = dot(wp, wdir);
	float v = dot(wp, wperp);
	float rn = vnoise(wp * 0.15);
	float rn2 = vnoise(wp * 0.07 + vec2(9.1, 3.3));
	return v * 0.70 + u * 0.16 + rn * 2.6 + rn2 * 3.4 + u_time * 0.25;
}

float swell_of(float mph) {
	return cos(mph) * 0.62 + cos(mph * 2.63 + 1.7) * 0.30
		+ cos(mph * 0.47 + 0.8) * 0.22;
}

// Высота поверхности берега: билинейная выборка той же карты, что у меша.
float ground_at(vec2 wp) {
	vec2 uv = (wp - ground_origin) / (ground_cell * (ground_n - 1.0));
	if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) {
		return -6.0; // за картой — глубокое море
	}
	return texture(ground_tex, uv).r;
}

void vertex() {
	w_pos = (MODEL_MATRIX * vec4(VERTEX.x, VERTEX.y, VERTEX.z, 1.0)).xyz;
	vec2 wdir_v = normalize(wind_dir);
	vec2 wperp_v = vec2(-wdir_v.y, wdir_v.x);

	// Волна плавно затухает к урезу. Большая амплитуда в открытом море
	// не раскачивает shoreline-сэмплы и не рвёт кромку на треугольники.
	float ground = ground_at(w_pos.xz);
	float shore_depth = max(sea_level - ground, 0.0);
	float shore_t = clamp(shore_depth / 4.0, 0.0, 1.0);
	float shore_wave_fade = shore_t * shore_t * (3.0 - 2.0 * shore_t);
	float hrip = swell_of(mega_phase(w_pos.xz, wdir_v, wperp_v))
		* mega_amp * wind_power * shore_wave_fade;
	float y = hrip;

	VERTEX.y += y;
	w_pos.y += y;
}

void fragment() {
	vec2 wp = w_pos.xz;
	vec2 wdir = normalize(wind_dir);
	vec2 wperp = vec2(-wdir.y, wdir.x);

	// ---------- берег под водой ----------
	// Глубина считается ПО ФРАГМЕНТУ: поверхность моря минус высота
	// песка в этом пикселе; кромка не зависит от рёбер сетки воды.
	float ground = ground_at(wp);
	float depth_m = w_pos.y - ground;
	// Оставляем небольшой переход по обе стороны уреза, чтобы прозрачность
	// сгладила субпиксельные расхождения между картой высот и сеткой берега.
	if (depth_m < -0.08) {
		discard;
	}
	float near_shore = 1.0 - smoothstep(-0.08, 0.9, depth_m);
	float mph = mega_phase(wp, wdir, wperp);

	vec3 L = normalize(sun_dir);
	vec3 N = vec3(0.0, 1.0, 0.0);

	float dist = length(CAMERA_POSITION_WORLD - w_pos);
	float detail = exp(-dist * 0.030);

	// ---------- слой 2: дыхание моря ----------
	float ms1 = sin(mph);
	float ms2 = sin(mph * 2.63 + 1.7);
	float ms3 = sin(mph * 0.47 + 0.8);
	float mdv = (-0.62 * 0.70 * ms1 - 0.30 * 2.63 * 0.70 * ms2
		- 0.22 * 0.47 * 0.70 * ms3) * mega_amp;
	float mdu = (-0.62 * 0.16 * ms1 - 0.30 * 2.63 * 0.16 * ms2
		- 0.22 * 0.47 * 0.16 * ms3) * mega_amp;
	vec2 mgrad = (wperp * mdv + wdir * mdu) * wind_power;
	// вдали волны должны сливаться в ровное зеркало, иначе получаются
	// бесконечные параллельные полосы «кордуроем» до горизонта
	float mega_fade = mix(0.30, 1.0, exp(-dist * 0.010));
	N = normalize(N - vec3(mgrad.x, 0.0, mgrad.y) * 0.42
		* (1.0 - 0.92 * near_shore) * mega_fade);

	// ---------- слой 1: ветровая рябь из трёх поездов ----------
	// Один поезд давал «кордурой» — длинные параллельные полосы. Три
	// направления под углом друг к другу + шум дают живую поверхность.
	float n1 = vnoise(wp * 0.33);
	float n2 = vnoise(wp * 0.90 + vec2(17.0, 9.0));
	vec2 d1 = wdir;
	vec2 d2 = normalize(wdir + vec2(0.62, -0.55));
	vec2 d3 = normalize(wdir + vec2(-0.78, -0.30));
	float ph1 = dot(wp, d1) * ripple_freq + n1 * 5.0 + u_time * ripple_speed;
	float ph2 = dot(wp, d2) * ripple_freq * 1.9 + n2 * 4.0 + u_time * ripple_speed * 1.5;
	float ph3 = dot(wp, d3) * ripple_freq * 3.4 + n1 * 3.0 + u_time * ripple_speed * 2.3;
	vec2 wgrad = d1 * cos(ph1) * 0.55 + d2 * cos(ph2) * 0.36
		+ d3 * cos(ph3) * 0.24;
	float amp = 0.40 + 0.60 * vnoise(wp * 0.11 + vec2(3.7, 1.3));
	wgrad *= ripple_strength * wind_power * detail * amp
		* (1.0 - 0.88 * near_shore);
	N = normalize(N - vec3(wgrad.x, 0.0, wgrad.y) * 0.42);

	// ---------- кольца событий ----------
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

	// ---------- цвет воды ----------
	vec3 base = mix(water_shallow, water_mid, smoothstep(0.0, 3.0, depth_m));
	base = mix(base, water_deep, smoothstep(1.0, 12.0, depth_m));
	base = mix(base, water_shallow * 1.22, near_shore * 0.45);
	float ndl = clamp(dot(N, L) * 0.5 + 0.5, 0.0, 1.0);
	base *= 0.80 + 0.32 * ndl;

	// ---------- френель: небо в воде ----------
	vec3 V = normalize(CAMERA_POSITION_WORLD - w_pos);
	vec3 R = reflect(-V, N);
	float fres = pow(1.0 - clamp(dot(N, V), 0.0, 1.0), 3.2);
	vec3 sky_ref = mix(horizon_col, sky_col, smoothstep(0.02, 0.42, R.y));
	// вода подкрашивает отражение в холод: тёплый закат не должен делать
	// море песочного цвета — иначе суша и вода сливаются на скользящем
	// ракурсе, где зеркало доминирует.
	sky_ref = mix(sky_ref, sky_ref * vec3(0.60, 0.80, 1.02), 0.62);
	// на скользящих ракурсах вода почти зеркалит небо — поэтому горизонт
	// светлый, а не тёмная полоса
	float mirror = clamp(0.05 + 0.92 * fres, 0.0, 0.88);
	mirror *= 1.0 - 0.18 * near_shore;
	base = mix(base, sky_ref, mirror);

	// Солнечный глиттер не обрывается у горизонта: ближние искры остаются
	// точечными, а вдали переходят в широкую мерцающую дорожку по солнцу.
	vec3 H = normalize(V + L);
	float far_glit = smoothstep(120.0, 900.0, dist);
	float need = 900.0 / max(dist, 0.001);
	float lod_density = pow(2.0, floor(log2(need / 3.0))) * 3.0;
	float density = clamp(lod_density, mix(6.0, 1.2, far_glit), 72.0);
	vec2 celluv = floor(wp * density);
	float cellid = hash12(celluv);
	float cellb = hash12(celluv + vec2(7.31, 1.77));
	float cellc = fract(cellid * 13.7);
	vec3 G = normalize(vec3(cellid - 0.5, 0.05 + 0.95 * cellb, cellc - 0.5));
	vec3 Hg = normalize(H + vec3(cellid - 0.5, cellb - 0.5, cellc - 0.5) * 0.55);
	float sun_lobe = pow(clamp(dot(N, Hg), 0.0, 1.0), mix(30.0, 110.0, cellb));
	float sky_lobe = pow(clamp(dot(G, V), 0.0, 1.0), mix(24.0, 80.0, cellc));
	float glit_chance = glitter_amount * mix(exp(-dist * 0.002), 0.42, far_glit);
	float glint = step(1.0 - glit_chance, cellid);
	float glit_fade = mix(exp(-dist * 0.0025), 0.38, far_glit)
		* (1.0 - 0.92 * near_shore);
	base += sun_col * (sun_lobe * 1.6 + sky_lobe * 0.26) * glint * glit_fade;

	float path_power = mix(180.0, 34.0, far_glit);
	float path = pow(clamp(dot(N, H), 0.0, 1.0), path_power);
	base += sun_col * path * 0.55 * sun_path_amount * (1.0 - 0.85 * near_shore);
	// СОЛНЕЧНЫЙ глиттер — не широкая полоса света: редкие отдельные
	// отражающие «частицы» собираются только в направлении солнечной дорожки.
	// Ячейки укрупняются вдаль, а размер искры держим в пикселях, чтобы
	// блики не исчезали на горизонте и не превращались в сплошную заливку.
	vec2 view_xz = V.xz / max(length(V.xz), 1e-4);
	vec2 sun_xz = L.xz / max(length(L.xz), 1e-4);
	float road_alignment = clamp(-dot(view_xz, sun_xz), 0.0, 1.0);
	float sun_road = pow(road_alignment, 8.0);
	float spark_cell_size = mix(3.2, 11.0, far_glit);
	vec2 spark_uv = wp / spark_cell_size;
	vec2 spark_cell = floor(spark_uv);
	vec2 spark_local = fract(spark_uv) - vec2(0.5);
	float spark_seed = hash12(spark_cell);
	vec2 spark_jitter = vec2(hash12(spark_cell + vec2(5.7, 2.3)),
		hash12(spark_cell + vec2(1.9, 8.1))) - vec2(0.5);
	vec2 spark_pos = (spark_local - spark_jitter * 0.54) * spark_cell_size;
	float pixel_world = max(0.35, dist * 2.0
		/ max(VIEWPORT_SIZE.y * PROJECTION_MATRIX[1][1], 1.0));
	float spark_radius = max(0.55, pixel_world * 0.95);
	float spark_core = 1.0 - smoothstep(spark_radius * 0.30, spark_radius,
		length(spark_pos));
	float ray_width = max(0.12, pixel_world * 0.12);
	float ray_v = (1.0 - smoothstep(ray_width, ray_width * 2.4, abs(spark_pos.x)))
		* (1.0 - smoothstep(spark_radius, spark_radius * 3.2, abs(spark_pos.y)));
	float ray_h = (1.0 - smoothstep(ray_width, ray_width * 2.4, abs(spark_pos.y)))
		* (1.0 - smoothstep(spark_radius, spark_radius * 3.2, abs(spark_pos.x)));
	float sparkle_shape = max(spark_core, max(ray_v, ray_h) * 0.72);
	float microfacet_seed = hash12(spark_cell + vec2(11.7, 4.1));
	vec3 microfacet_n = normalize(vec3((microfacet_seed - 0.5) * 0.38, 1.0,
		hash12(spark_cell + vec2(3.3, 15.1)) * 0.38 - 0.19));
	float microfacet_match = 0.45 + 0.55 * pow(
		clamp(dot(microfacet_n, H), 0.0, 1.0), 10.0);
	float spark_select = step(1.0 - solar_glitter_amount * 0.32, spark_seed);
	float spark_twinkle = 0.72 + 0.28 * sin(u_time * 3.4 + spark_seed * 71.0);
	vec3 spark_tint = mix(sun_col, vec3(1.0, 0.96, 0.82), spark_core * 0.82);
	vec3 distant_glitter = spark_tint * sparkle_shape * spark_select * sun_road
		* microfacet_match * spark_twinkle * far_glit * solar_glitter_amount
		* 9.0 * (1.0 - 0.70 * near_shore);
	base += distant_glitter;

	// ---------- пена прибоя ----------
	// Обе полосы идут по КОНТУРУ глубины: кромка на песке и вал чуть
	// дальше. Контур живой, потому что сама поверхность дышит накатом.
	float fn = vnoise(vec2(wp.x * 0.85 + u_time * 0.10, wp.y * 1.55));
	float fn2 = vnoise(vec2(wp.x * 3.2 - u_time * 0.38, wp.y * 2.35));
	float edge = exp(-pow((depth_m - 0.014 - 0.014 * sin(wp.x * 0.9 + u_time * 1.3)) / 0.075, 2.0));
	float edge2 = exp(-pow((depth_m - 0.17 - 0.03 * sin(wp.y * 0.21 + u_time * 1.15)) / 0.08, 2.0));
	float foam = edge * smoothstep(0.02, 0.40, fn) * (0.72 + 0.28 * fn2);
	foam += edge2 * smoothstep(0.45, 0.85, fn2) * 0.55;
	foam = clamp(foam, 0.0, 1.0);
	base = mix(base, foam_col * (0.80 + 0.20 * ndl), foam * 0.95);

	// ---------- дымка к горизонту ----------
	float fog = 1.0 - exp(-pow(dist / fog_distance, 2.1));
	float above = smoothstep(-2.0, 16.0, w_pos.y - CAMERA_POSITION_WORLD.y);
	vec3 fcol = mix(horizon_col, sky_col, above * 0.6);
	// Искры — отдельный HDR-слой: они остаются резкими поверх дымки,
	// а glow даёт им маленький ореол, не превращая дорожку в сплошную полосу.
	ALBEDO = mix(base - distant_glitter, fcol, fog);
	EMISSION = distant_glitter;

	NORMAL = normalize((VIEW_MATRIX * vec4(N.x, N.y, N.z, 0.0)).xyz);
	float rough = mix(0.16, 0.55, near_shore);
	ROUGHNESS = mix(rough, 0.88, foam);
	SPECULAR = mix(0.55, 0.18, near_shore);
	METALLIC = 0.0;

	// ---------- мягкий урез ----------
	// Альфа растёт от нуля по глубине: кромка получается градиентной,
	// а не ступенькой из полигонов.
	float shore_a = smoothstep(-0.08, 0.22, depth_m);
	// Открытое море непрозрачное: мягкий alpha нужен только на кромке,
	// иначе сквозь мелководье просвечивает дно и пропадает цвет воды.
	float sea_a = shore_a;
	float a = max(sea_a, foam * 0.92);
	// предметы (пирс, камни) закрывают воду мягко
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
		// Обычный Schlick-GGX для базового сравнения.
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
	// Diffuse Proxima: Fresnel tint, retroreflection и smooth terminator.
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

	// Specular Trowbridge-Reitz GGX + Smith + Schlick Fresnel.
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
