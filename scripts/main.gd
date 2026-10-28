class_name MainScene
extends Node3D
## M0: прежние процедурные окружение и камера, без рыбалки и движения.
## Позиция на земле временная — башня появится только в M1.

var game: GameState
var world: GameWorld
var coast: Coast
var sand: SandField
var player: Node3D
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
	player = Node3D.new()
	player.name = "ViewAnchor"
	add_child(player)
	var spawn := coast.spawn_point()
	player.global_position = Vector3(spawn.x, coast.ground_height(spawn.x, spawn.y), spawn.y)
	sand.player = player
	audio = SoundScape.new()
	add_child(audio)
	audio.setup(game, player)
	cam_rig = CameraRig.new()
	add_child(cam_rig)
	cam_rig.setup(self)
	# Смотреть на дюны, а не в пустое бывшее море.
	cam_rig.set_view(PI * 0.5, -0.05)
	set_time(game.night01)
	apply_sun(game.sun_dir)
	if OS.get_environment("JOURNEY_SMOKE") == "1":
		var smoke := SmokeTest.new()
		add_child(smoke)
		smoke.setup(self)


func set_time(value: float) -> void:
	game.night01 = clampf(value, 0.0, 1.0)
	world.apply_night01(game.night01)
	coast.set_night01(game.night01)
	color_grade.set_param("night", 0.85 * game.night01)


func apply_sun(dir: Vector3) -> void:
	game.sun_dir = dir
	world.apply_sun(dir)
	coast.apply_sun(dir)
