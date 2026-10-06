extends Node3D
## Точка входа. Этап 2+: настоящий песок (следы-геометрия), звук.
## Вся сцена собирается программно, чтобы ошибки всплывали при запуске.

var game
var world: GameWorld
var terrain: Terrain
var player: Player
var cam_rig: CameraRig
var arms: FpsArms
var sand: SandField
var audio
var wind: WindField
var color_grade: ColorGrader
var debug_panel: DebugPanel
var zombies: Array[SandZombie] = []


func _ready() -> void:
	game = get_node("/root/Game")

	world = GameWorld.new()
	add_child(world)
	world.setup(game)

	# колор-грейдинг поверх кадра (пресеты и крутилки — DEV-панель F3)
	color_grade = ColorGrader.new()
	add_child(color_grade)
	color_grade.setup()

	terrain = Terrain.new()
	add_child(terrain)
	terrain.setup(game)
	# тестовый «маяк»: огонёк в коридоре дюн — как свет играет в тумане
	world.build_beacon(terrain)

	# настоящий песок: поле смещений, скользящее окно за путником
	sand = SandField.new()
	add_child(sand)
	sand.setup(game)
	terrain.attach_sand(sand)

	player = Player.new()
	add_child(player)
	player.setup(game, terrain, sand)
	sand.player = player

	# Противники появляются силуэтами вдоль маршрута, а не у лица игрока.
	# В smoke-тесте отключены, чтобы AI не вмешивался в замеры движения.
	if OS.get_environment("JOURNEY_SMOKE") != "1":
		_spawn_zombies()

	# звук: шаги, скольжение, ветер, амбиент-пад — весь синтезируется кодом
	audio = SoundScape.new()
	add_child(audio)
	audio.setup(game, player)
	player.audio = audio

	# ветер: лёгкая взвесь вокруг путника, усиливается на сёрфе
	wind = WindField.new()
	add_child(wind)
	wind.setup(game, player, terrain)

	cam_rig = CameraRig.new()
	add_child(cam_rig)
	cam_rig.setup(self)
	arms = cam_rig.arms

	# headless-автотест геймплея: включается только переменной окружения
	if OS.get_environment("JOURNEY_SMOKE") == "1":
		var smoke := SmokeTest.new()
		add_child(smoke)
		smoke.setup(self)

	# ночь: красим небо/свет/песок/туман/грейдинг одним параметром
	world.apply_night01(game.night01)
	terrain.set_night01(game.night01)
	color_grade.set_param("night", 0.85 * game.night01)

	# DEV-панель крутилок: F3 (по умолчанию скрыта, в игре текста нет)
	debug_panel = DebugPanel.new()
	add_child(debug_panel)
	debug_panel.setup(self)

	# CI-скриншоты (запускается под xvfb с настоящим GL)
	if OS.get_environment("JOURNEY_SHOT") == "1":
		var shot := ShotTaker.new()
		add_child(shot)
		shot.setup(self)


func _spawn_zombies() -> void:
	for spawn in [Vector2(-13.0, -32.0), Vector2(18.0, -92.0), Vector2(-8.0, -142.0)]:
		var zombie := SandZombie.new()
		add_child(zombie)
		zombie.setup(player, terrain, spawn)
		zombies.append(zombie)


## Ближайший живой противник на линии выстрела до песка.
func shoot_zombie(origin: Vector3, direction: Vector3, max_distance: float) -> Dictionary:
	var best_distance := max_distance
	var best: SandZombie = null
	for zombie in zombies:
		if not is_instance_valid(zombie):
			continue
		var distance := zombie.ray_hit_distance(origin, direction, best_distance)
		if distance >= 0.0 and distance < best_distance:
			best_distance = distance
			best = zombie
	if best == null:
		return {}
	var hit_position := origin + direction * best_distance
	best.take_damage(hit_position)
	return {"position": hit_position, "distance": best_distance}
