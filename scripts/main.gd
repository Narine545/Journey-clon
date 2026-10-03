extends Node3D
## Точка входа. Этап 1: дюны, шейдер песка, путник со скольжением и шарфом.
## Вся сцена собирается программно, чтобы ошибки всплывали при запуске.

var game
var terrain: Terrain
var player: Player
var cam_rig: CameraRig


func _ready() -> void:
	game = get_node("/root/Game")

	var world := GameWorld.new()
	add_child(world)
	world.setup(game)

	terrain = Terrain.new()
	add_child(terrain)
	terrain.setup(game)

	player = Player.new()
	add_child(player)
	player.setup(game, terrain)

	var scarf := Scarf.new()
	add_child(scarf)
	scarf.setup(game, player)

	cam_rig = CameraRig.new()
	add_child(cam_rig)
	cam_rig.setup(player, terrain)

	# временный дамп сетки высот и камеры для CPU-превью
	if OS.get_environment("JOURNEY_DUMP") == "1":
		await _dump_world(terrain, player, cam_rig)
	# headless-автотест геймплея: включается только переменной окружения
	if OS.get_environment("JOURNEY_SMOKE") == "1":
		var smoke := SmokeTest.new()
		add_child(smoke)
		smoke.setup(self)

func _dump_world(terrain: Terrain, player: Player, cam_rig: CameraRig) -> void:
	for i in range(5):
		await get_tree().physics_frame
	var f := FileAccess.open("/tmp/terrain_dump.bin", FileAccess.WRITE)
	f.store_32(terrain._row)
	for h in terrain._grid:
		f.store_float(h)
	f.close()
	var cf := FileAccess.open("/tmp/cam_dump.txt", FileAccess.WRITE)
	cf.store_line(str(cam_rig.cam.global_position))
	cf.store_line(str(player.global_position))
	cf.close()
	print("[DUMP] камера: ", cam_rig.cam.global_position, " игрок: ", player.global_position)
	get_tree().quit(0)
