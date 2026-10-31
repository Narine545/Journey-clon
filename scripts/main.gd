class_name MainScene
extends Node3D
## M4: башня, баллистика, радио и редкие встречи без волн.

const TOWER_SCENE := preload("res://scenes/Tower.tscn")
const RIFLE_SCENE := preload("res://scenes/Rifle.tscn")
const LIFT_SCENE := preload("res://scenes/Lift.tscn")
const SHOP_SCENE := preload("res://scenes/ShopUI.tscn")

var game: GameState
var world: GameWorld
var coast: Coast
var sand: SandField
var tower: ObservationTower
var landmarks: WastelandLandmarks
var target: TargetDummy
var long_target: TargetDummy
var rifle: SniperRifle
var player: TowerPlayer
var cam_rig: CameraRig
var audio: SoundScape
var color_grade: ColorGrader
var performance_overlay: PerformanceOverlay
var radio_tuner: RadioTuner
var ambient_spawner: AmbientSpawner
var lift: SupplyLift
var shop: ShopUI
var debug_menu: DebugMenu
var player_health: PlayerHealth


func _ready() -> void:
	game = get_node("/root/Game") as GameState
	world = GameWorld.new()
	add_child(world)
	world.setup(game)
	color_grade = ColorGrader.new()
	add_child(color_grade)
	color_grade.preset_idx = 2
	color_grade.intensity = 0.5
	color_grade.setup()
	performance_overlay = PerformanceOverlay.new()
	add_child(performance_overlay)
	coast = Coast.new()
	add_child(coast)
	coast.setup(game)
	sand = SandField.new()
	add_child(sand)
	sand.setup(game)
	coast.attach_sand(sand)

	var spawn := coast.spawn_point()
	landmarks = WastelandLandmarks.new()
	add_child(landmarks)
	landmarks.setup(coast, spawn)
	tower = TOWER_SCENE.instantiate() as ObservationTower
	tower.position = Vector3(spawn.x, coast.ground_height(spawn.x, spawn.y), spawn.y)
	add_child(tower)
	player = TowerPlayer.new()
	player.name = "TowerPlayer"
	tower.add_child(player)
	# У края площадки робот внизу виден без необходимости перелезать перила.
	player.position = Vector3(4.7, ObservationTower.DECK_HEIGHT, -1.4)
	sand.set_tracking_target(player)

	target = TargetDummy.new()
	target.name = "TargetDummy"
	add_child(target)
	var target_x := spawn.x + 90.0
	var target_z := spawn.y - 1.4
	target.global_position = Vector3(target_x, coast.ground_height(target_x, target_z), target_z)

	# Дальняя мишень за противоположным краем башни, более 500 м.
	long_target = TargetDummy.new()
	long_target.name = "LongTarget"
	add_child(long_target)
	var far_x := spawn.x - 600.0
	var far_z := spawn.y - 1.4
	long_target.global_position = Vector3(far_x, coast.ground_height(far_x, far_z), far_z)

	audio = SoundScape.new()
	add_child(audio)
	audio.setup(game, player)
	player.audio = audio
	cam_rig = CameraRig.new()
	add_child(cam_rig)
	cam_rig.setup(self)
	player.camera_rig = cam_rig
	var aim: Vector3 = target.global_position + Vector3(0.0, TargetDummy.CENTER_HEIGHT, 0.0) - (player.global_position + Vector3.UP * CameraRig.EYE)
	cam_rig.set_view(atan2(aim.x, aim.z), atan2(aim.y, Vector2(aim.x, aim.z).length()))
	rifle = RIFLE_SCENE.instantiate() as SniperRifle
	camera_add_rifle()
	radio_tuner = RadioTuner.new()
	radio_tuner.name = "RadioTuner"
	tower.add_child(radio_tuner)
	radio_tuner.setup(self)
	player.radio = radio_tuner
	lift = LIFT_SCENE.instantiate() as SupplyLift
	tower.add_child(lift)
	lift.setup(self)
	lift.effect_applied.connect(rifle.apply_delivery)
	lift.effect_applied.connect(radio_tuner.apply_delivery)
	lift.delivery_collected.connect(rifle.on_delivery_collected)
	shop = SHOP_SCENE.instantiate() as ShopUI
	add_child(shop)
	shop.setup(self)
	player_health = PlayerHealth.new()
	add_child(player_health)
	player_health.setup(self)
	player.health = player_health
	ambient_spawner = AmbientSpawner.new()
	ambient_spawner.name = "AmbientSpawner"
	add_child(ambient_spawner)
	ambient_spawner.setup(self)
	debug_menu = DebugMenu.new()
	add_child(debug_menu)
	debug_menu.setup(self)
	player.debug_menu = debug_menu
	set_time(game.night01)
	apply_sun(game.sun_dir)
	if OS.get_environment("JOURNEY_SMOKE") == "1":
		# Обычный случайный спавн отключён только в CI, чтобы остальные тесты
		# не зависели от случайной встречи в соседнем физическом кадре.
		ambient_spawner.set_process(false)
		var smoke := SmokeTest.new()
		add_child(smoke)
		smoke.setup(self)
	elif OS.get_environment("JOURNEY_RESTART_SMOKE") == "1":
		if get_tree().root.get_node_or_null("RestartSmoke") == null:
			var restart_test := RestartSmoke.new()
			restart_test.name = "RestartSmoke"
			get_tree().root.call_deferred("add_child", restart_test)
	elif OS.get_environment("JOURNEY_SHOT") == "1":
		var shot := ScreenshotCapture.new()
		add_child(shot)


func camera_add_rifle() -> void:
	cam_rig.cam.add_child(rifle)
	rifle.setup(self)
	rifle.reward_confirmed.connect(Economy.add_points)


func set_time(value: float) -> void:
	game.night01 = clampf(value, 0.0, 1.0)
	world.apply_night01(game.night01)
	coast.set_night01(game.night01)
	color_grade.set_param("night", 0.85 * game.night01)


func apply_sun(dir: Vector3) -> void:
	game.sun_dir = dir
	world.apply_sun(dir)
	coast.apply_sun(dir)
