class_name MainScene
extends Node3D
## Точка входа: берег, песчаное море, существа, пирс и удочка.
## Вся сцена собирается программно, чтобы ошибки всплывали при запуске.
##
## Порядок важен (каждый следующий шаг пользуется предыдущим):
##   небо → берег → пирс/декор → песок → море → рыбы → путник → камера →
##   удочка (на камере) → звук → ветер → день/ночь.

var game: GameState
var world: GameWorld
var coast: Coast
var pier: Pier
var props: CoastProps
var water: WaterSurface
var fish: SandFish
var sand: SandField
var player: Player
var cam_rig: CameraRig
var rod: RodCast
var audio
var color_grade: ColorGrader
var debug_panel: DebugPanel
var catch_card: CatchCard
var hud: FishingHud

var night01 := 0.0


func _ready() -> void:
	game = get_node("/root/Game") as GameState
	game.main = self

	world = GameWorld.new()
	add_child(world)
	world.setup(game)

	# колор-грейдинг поверх кадра (пресеты и крутилки — DEV-панель F3)
	color_grade = ColorGrader.new()
	add_child(color_grade)
	color_grade.preset_idx = 2 # «Золотой час» — под берег и закат
	color_grade.intensity = 0.5
	color_grade.setup()

	coast = Coast.new()
	add_child(coast)
	coast.setup(game)

	# пирс: настоящий настил над водой, по нему можно ходить
	pier = Pier.new()
	add_child(pier)
	pier.setup(coast, game, -40.0)

	# каменные пальцы, коряги и камни — берег не пустой
	props = CoastProps.new()
	add_child(props)
	props.setup(coast, game)

	# настоящий песок: следы-геометрия, скользящее окно за путником
	sand = SandField.new()
	add_child(sand)
	sand.setup(game)
	coast.attach_sand(sand)

	# песчаное море: уровень 0, уходит за горизонт
	water = WaterSurface.new()
	add_child(water)
	water.setup(game, Vector2(-150.0, 20.0), Coast.SEA_LEVEL)
	water.set_ground(coast.height_tex, coast.grid_origin, coast.grid_cell, coast.grid_n)
	game.water = water

	# песчаные киты под водой и их прыжки
	fish = SandFish.new()
	fish.fish_count = 5
	add_child(fish)
	fish.setup(game, water.level_y, water.field, coast)

	player = Player.new()
	add_child(player)
	player.setup(game, coast, sand, pier)
	sand.player = player

	# звук: шаги, вода, ветер, амбиент-пад — весь синтезируется кодом
	audio = SoundScape.new()
	add_child(audio)
	audio.setup(game, player)
	player.audio = audio

	cam_rig = CameraRig.new()
	add_child(cam_rig)
	cam_rig.setup(self)
	cam_rig.set_view(-PI * 0.5 + 0.10, -0.02)

	# удочка живёт НА камере (вью-модель); мир — в мировых координатах
	rod = RodCast.new()
	cam_rig.cam.add_child(rod)
	rod.setup(game, water, fish, coast, sand)
	_connect_fishing()

	# headless-автотест геймплея: включается только переменной окружения
	if OS.get_environment("JOURNEY_SMOKE") == "1":
		var smoke := SmokeTest.new()
		add_child(smoke)
		smoke.setup(self)

	# день/ночь: красим небо, свет, песок, море, существ и грейдинг
	set_time(game.night01)
	# солнце: небо + свет + шейдеры песка/моря/существ (без этого они
	# остались бы на дефолтном uniform-е «низкое солнце»)
	apply_sun(game.sun_dir)

	# HUD рыбалки: что нажать, сила заброса, окно подсечки, натяг/прогресс
	hud = FishingHud.new()
	add_child(hud)
	hud.setup(self)

	# карточка улова: всплывает на несколько секунд после поимки и гаснет
	catch_card = CatchCard.new()
	add_child(catch_card)
	catch_card.setup()

	# DEV-панель крутилок: F3 (по умолчанию скрыта, в игре текста нет)
	debug_panel = DebugPanel.new()
	add_child(debug_panel)
	debug_panel.setup(self)

	# CI-скриншоты (запускается под xvfb с настоящим GL)
	if OS.get_environment("JOURNEY_SHOT") == "1":
		var shot := ShotTaker.new()
		add_child(shot)
		shot.setup(self)


## Сигналы удочки → звук. Счёт/инвентарь/квесты подключаются здесь же.
func _connect_fishing() -> void:
	rod.cast_started.connect(func(p: float) -> void: audio.on_cast(p))
	rod.bobber_landed.connect(func(_pos: Vector3) -> void: audio.on_splash(0.9))
	rod.cast_landed_on_sand.connect(func(_pos: Vector3) -> void: audio.on_sand_plop())
	rod.bite_window_started.connect(func() -> void: audio.on_bite())
	rod.fish_hooked.connect(func() -> void: audio.on_hooked())
	rod.fish_landed.connect(func(sz: float) -> void: audio.on_catch(sz))
	rod.fish_escaped.connect(func() -> void: audio.on_escape())
	rod.line_retrieved.connect(func() -> void: audio.on_reel_tick())
	rod.reel_tick.connect(func() -> void: audio.on_reel_tick())
	rod.bite_missed.connect(func() -> void: audio.on_reel_tick())
	rod.line_snap.connect(func() -> void: audio.on_escape())
	rod.surge_telegraph.connect(func() -> void: audio.on_splash(0.5))
	rod.fish_caught.connect(_on_fish_caught)


var seen_species: Dictionary = {}


## Пойманная рыба: карточка улова и «новый вид» (журнал — на будущее).
func _on_fish_caught(info: Dictionary) -> void:
	var id := str(info.get("id", ""))
	var is_new := not seen_species.has(id)
	seen_species[id] = true
	if catch_card != null:
		catch_card.show_fish(info, is_new)
	print("[FISH] %s (%.0f см, %.2f кг) — %s" % [
		info.get("name", "?"), float(info.get("size_cm", 0.0)),
		float(info.get("weight_kg", 0.0)), "новый вид" if is_new else "уже в журнале"])


## Время суток одним числом: 0 — золотой час, 1 — ночь.
func set_time(v: float) -> void:
	night01 = clampf(v, 0.0, 1.0)
	game.night01 = night01
	world.apply_night01(night01)
	coast.set_night01(night01)
	if water != null:
		water.apply_night01(night01)
	if fish != null:
		fish.apply_night01(night01)
	if color_grade != null:
		color_grade.set_param("night", 0.85 * night01)


## Солнце: небо + свет + шейдеры песка/моря/существ.
func apply_sun(dir: Vector3) -> void:
	game.sun_dir = dir
	world.apply_sun(dir)
	coast.apply_sun(dir)
	if water != null:
		water.apply_sun(dir)
	if fish != null:
		fish.apply_sun(dir)


## Ближайшая к камере рыба (диагностика/будущие квесты).
func nearest_fish_distance() -> float:
	if fish == null or cam_rig == null:
		return -1.0
	return fish.nearest_distance(cam_rig.cam.global_position)
