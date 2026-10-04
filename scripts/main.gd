extends Node3D
## Точка входа. Этап 2+: настоящий песок (следы-геометрия), звук.
## Вся сцена собирается программно, чтобы ошибки всплывали при запуске.

var game
var world: GameWorld
var terrain: Terrain
var player: Player
var cam_rig: CameraRig
var sand: SandField
var audio
var wind: WindField
var color_grade: ColorGrader
var debug_panel: DebugPanel


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

	# настоящий песок: поле смещений, скользящее окно за путником
	sand = SandField.new()
	add_child(sand)
	sand.setup(game)
	terrain.attach_sand(sand)

	player = Player.new()
	add_child(player)
	player.setup(game, terrain, sand)
	sand.player = player

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
	cam_rig.setup(player, terrain)

	# headless-автотест геймплея: включается только переменной окружения
	if OS.get_environment("JOURNEY_SMOKE") == "1":
		var smoke := SmokeTest.new()
		add_child(smoke)
		smoke.setup(self)

	# DEV-панель крутилок: F3 (по умолчанию скрыта, в игре текста нет)
	debug_panel = DebugPanel.new()
	add_child(debug_panel)
	debug_panel.setup(self)

	# CI-скриншоты (запускается под xvfb с настоящим GL)
	if OS.get_environment("JOURNEY_SHOT") == "1":
		var shot := ShotTaker.new()
		add_child(shot)
		shot.setup(self)
