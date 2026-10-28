class_name MainScene
extends Node3D
## M1: окружение M0, башня, ограниченная ходьба и временная мишень.

const TOWER_SCENE := preload("res://scenes/Tower.tscn")

var game: GameState
var world: GameWorld
var coast: Coast
var sand: SandField
var tower: ObservationTower
var target: TargetDummy
var player: TowerPlayer
var cam_rig: CameraRig
var audio: SoundScape
var color_grade: ColorGrader


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
	coast = Coast.new()
	add_child(coast)
	coast.setup(game)
	sand = SandField.new()
	add_child(sand)
	sand.setup(game)
	coast.attach_sand(sand)

	var spawn := coast.spawn_point()
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
	set_time(game.night01)
	apply_sun(game.sun_dir)
	if OS.get_environment("JOURNEY_SMOKE") == "1":
		var smoke := SmokeTest.new()
		add_child(smoke)
		smoke.setup(self)
	elif OS.get_environment("JOURNEY_SHOT") == "1":
		var shot := ScreenshotCapture.new()
		add_child(shot)


func set_time(value: float) -> void:
	game.night01 = clampf(value, 0.0, 1.0)
	world.apply_night01(game.night01)
	coast.set_night01(game.night01)
	color_grade.set_param("night", 0.85 * game.night01)


func apply_sun(dir: Vector3) -> void:
	game.sun_dir = dir
	world.apply_sun(dir)
	coast.apply_sun(dir)
