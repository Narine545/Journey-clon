class_name BoatMain
extends Node3D
## Первый самостоятельный игровой срез. Старая рыбалка сохранена в main.tscn.
## Небо/атмосфера, песчаный берег, вода и её CPU-зеркало волн — из проекта.

const START_Z := Coast.SPAWN_Z
const START_SEAWARD := 95.0

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
