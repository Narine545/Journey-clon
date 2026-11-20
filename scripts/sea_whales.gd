class_name SeaWhales
extends Node3D
## Ночные киты — тот же самый рендер существ, что рисует рыб в модуле
## рыбалки: scripts/sand_fish.gd + shaders/sand_sea_sdf.gdshader.
##
## Никаких примитивов и «голых» материалов: тело — SDF-сцена из шести
## плавленых сфер хребта, морды, спинного гребня и хвостовой лопасти
## (два сплюснутых эллипсоида), smooth union, волна бежит к хвосту,
## всплески — капли-метаболы, свет и туман — из общей палитры мира
## (apply_night01 берёт ночные цвета Coast, как вода и песок).
##
## Слой ленивый: полноэкранный raymarch появляется только тогда, когда
## ночь реально наступила, поэтому запуск игры (день, гавань) он не
## утяжеляет вовсе.
##
## Стая держится своей мировой территории: место обитания задаётся один
## раз (перед камерой при первом появлении или явно через place_near),
## и обновляется, только если судно ушло далеко.

const NIGHT_ON := 0.16 ## порог ночи, с которого киты выходят из глубины
const WHALE_COUNT := 2 ## пара: третья туша в кадре уже тесно
const WHALE_SCALE := 1.35 ## SDF-тело ≈ 4 м на единицу размера: кит 3–5 м
const SCHOOL_RADIUS := 30.0 ## насколько широко пара ходит вокруг точки
const BOUNDS_RADIUS := 110.0 ## радиус raymarch-culling вокруг камеры, м
const REGROUP_DIST := 80.0 ## дальше этого стаю переносим ближе к судну, м
## Тёмная спина с холодным отливом — кит, а не рыбка из закатной палитры.
const TINT := Color(0.62, 0.76, 0.86)

var main: BoatMain
var _fish: SandFish
var _applied := -1.0 ## последнее применённое значение ночи
var _home := Vector2.ZERO
var _has_home := false


## Ссылка на игру. Существа создаются не здесь, а при наступлении ночи.
func setup(main_ref: BoatMain) -> void:
	main = main_ref


## Ночь: включить/выключить стаю. Днём слоя не существует как такового.
func advance(_delta: float, night01: float) -> void:
	if night01 < NIGHT_ON:
		if _fish != null and _applied >= 0.0:
			_fish.set_sdf_enabled(false)
			_fish.set_process(false)
			_applied = -1.0
		return
	_ensure()
	if _fish == null:
		return
	if _applied < 0.0:
		_fish.set_process(true)
		_fish.set_sdf_enabled(true)
	if absf(night01 - _applied) > 0.01:
		_applied = night01
		_fish.apply_night01(night01)
	# Ключевой свет сцены — тот же, что у воды и корпуса: иначе существа
	# светились бы «своим» солнцем поверх ночного мира.
	if main != null and main.world != null:
		_fish.apply_sun(main.world.boat_key_dir(night01))
	if not _has_home or _camera_xz().distance_to(_home) > REGROUP_DIST:
		_place_default()


## Поставить стаю у заданной точки (кадры CI и сюжетные сцены).
## forward — куда смотрит камера: киты идут поперёк луча зрения.
func place_near(at: Vector3, forward: Vector3) -> void:
	_ensure()
	if _fish == null:
		return
	_fish.set_process(true)
	_fish.set_sdf_enabled(true)
	_fish.place_school(at, forward, SCHOOL_RADIUS, TINT)
	_home = Vector2(at.x, at.z)
	_has_home = true


## Диагностика/автотесты: слой существует и включён.
func is_alive() -> bool:
	return _fish != null and _applied >= 0.0


## Киты выходят перед судном: в кадре, но не в упор.
func _place_default() -> void:
	var at := Vector3.ZERO
	var fwd := Vector3.FORWARD
	if main != null and main.camera != null:
		at = main.camera.global_position
		fwd = -main.camera.global_transform.basis.z
		fwd.y = 0.0
	if fwd.length() < 0.01:
		fwd = Vector3.FORWARD
	fwd = fwd.normalized()
	at += fwd * (SCHOOL_RADIUS * 0.85)
	_fish.place_school(at, fwd, SCHOOL_RADIUS, TINT)
	_home = Vector2(at.x, at.z)
	_has_home = true


func _camera_xz() -> Vector2:
	if main == null or main.camera == null:
		return Vector2.ZERO
	return Vector2(main.camera.global_position.x, main.camera.global_position.z)


func _ensure() -> void:
	if _fish != null:
		return
	if main == null or main.water == null:
		return
	_fish = SandFish.new()
	_fish.name = "WhaleSdf"
	_fish.fish_count = WHALE_COUNT
	_fish.size_mul = WHALE_SCALE
	_fish.bounds_radius = BOUNDS_RADIUS
	_fish.jump_mul = 1.1
	# Берег не нужен: киты живут в открытом море, ограничитель — не суша.
	_fish.setup(main.game, main.water.level_y, main.water.field, null)
	add_child(_fish)
	_applied = 0.0
	_fish.apply_night01(NIGHT_ON)
