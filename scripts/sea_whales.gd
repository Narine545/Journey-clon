class_name SeaWhales
extends Node3D
## Киты — те же SDF-существа, что рыбы модуля рыбалки (SandFish +
## sand_sea_sdf.gdshader), но живут по своим правилам, а не по «заводному»
## циклу: дыхание, нырок, гребок с планированием, объезд судна и мелководья.
##
## На чём построено поведение (реальные величины уменьшены под масштаб игры):
## • Горбач крейсирует 1.5–4 м/с, кормится нырками на десятки метров и
##   дышит серией выдохов на поверхности. Здесь: крейсер 1.5–2.7 м/с,
##   цикл «поверхность → нырок → глубина → всплытие» раз в 25–45 с.
## • Хвост работает толчками 0.2–0.5 Гц с фазами планирования: кит
##   разгоняется гребком и скользит. Поэтому фаза волны тела идёт не с
##   постоянной частотой, а с медленной модуляцией (glide).
## • Тело не прибито к уровню моря: высота следует за зыбью
##   (water.surface_height) через пружину с критическим демпфированием —
##   кит качается на волне, как судно, но без дёрганья.
## • Нырок физичен: нос идёт вниз вместе с падением (тангаж считается из
##   вертикальной скорости), хвост в это время бьёт чаще.
## • Объезд судна — по упреждению (DCPA): считаем точку наибольшего
##   сближения с курсом судна на 6 с вперёд и уходим в сторону расхождения.
##   Поворот ограничен 0.30 рад/с: кит разворачивается тяжело, поэтому
##   манёвр выглядит как решение животного, а не как радиоуправление.
## • Мелководье отталкивает: ближе 5 м глубины кит разворачивается в море
##   (выброситься на берег он не может).
##
## Слой ленивый: полноэкранный raymarch создаётся при первом появлении китов,
## а не при запуске игры.

## Класс одного животного: своё состояние, свой характер.
class Whale:
	var slot := 0
	var pos := Vector3.ZERO ## мировая точка центра тела (y — из пружины)
	var y := 0.0
	var vy := 0.0
	var heading := 0.0
	var speed := 1.8
	var target_speed := 1.8
	var depth_target := 0.0 ## м ниже поверхности, < 0 — спина над водой
	var state := 0
	var timer := 0.0
	var beat := 0.0 ## фаза волны тела (радианы)
	var glide_t := 0.0
	var bias := 0.0 ## медленный дрейф курса: животное не идёт по рельсам
	var pitch := 0.0
	var interest := 0.0 ## с: сколько ещё интересно судно
	var ignore := 0.0 ## с: сколько ещё судно безразлично
	var wake_t := 0.0
	var prev_depth := 9.0 ## для всплеска на пересечении поверхности
	var surface_contact := false
	var trail := PackedVector4Array()
	var trail_clock := 0.0


const SDF_LEN := 2.4 ## в шейдере длина тела L = 2.4 * s
const BODY_LEN := 6.0 ## м: молодой горбач рядом с 11-метровым судном
const BODY_SIZE := BODY_LEN / SDF_LEN ## s для шейдера
const WHALE_COUNT := 2
## Кожа: тёмная спина, брюхо вытягивает шейдерный контражур.
const TINT := Color(0.32, 0.44, 0.58)
const GLOW_MAX := 1.15 ## биолюминесценция в полную ночь (тело уходит в bloom)

const TURN_RATE := 0.30 ## рад/с: кит разворачивается тяжело
const CRUISE_MIN := 1.5
const CRUISE_MAX := 2.7
const SPRING := 1.7 ## жёсткость вертикальной пружины, 1/с²
const SURFACE_DEPTH := -0.35 ## спина и гребень на виду
const SHALLOW_DEPTH := 1.4 ## тело под поверхностью: спина у самой воды
const DEEP_DEPTH := 6.5

const DEEP_WATER := 5.0 ## м: ближе этого кит разворачивается в море
const SHORE_PROBE := 16.0 ## м: насколько вперёд смотрим глубину
const BOAT_CLEARANCE := 12.0 ## м: коридор, из которого кит уходит
const BOAT_PANIC := 7.0 ## м: уже под носом — уходить изо всех сил
const BOAT_LOOKAHEAD := 6.0 ## с: горизонт упреждения
const INTEREST_RANGE := 55.0 ## м: с какого расстояния судно любопытно
const INTEREST_SIDE := 15.0 ## м: кит идёт параллельным курсом в стороне

const TRAIL_POINTS := 12
const TRAIL_SAMPLE := 0.4
const WAKE_INTERVAL := 0.12 ## с: след в воде (как у судна)
const SDF_STEPS := 48
const SDF_EPSILON := 0.03
const BOUNDS_RADIUS := 60.0

const ST_SURFACE := 0
const ST_DIVE := 1
const ST_DEEP := 2
const ST_RISE := 3
const STATE_NAMES := ["дыхание", "нырок", "глубина", "всплытие"]

var main: BoatMain
var whales: Array[Whale] = []
var debug_on := false

var _fish: SandFish
var _glow := -1.0
var _markers: MeshInstance3D
var _marker_mesh: ImmediateMesh
var _labels: Array[Label3D] = []
var _panel: Label
var _marker_mat: StandardMaterial3D


## Ссылка на игру. Существа появятся при первом advance().
func setup(main_ref: BoatMain) -> void:
	main = main_ref


# ---------------------------------------------------------------------------
# Жизнь
# ---------------------------------------------------------------------------

func advance(delta: float, night01: float) -> void:
	if main == null or main.water == null:
		return
	_ensure()
	if _fish == null:
		return
	var want_glow := GLOW_MAX * clampf(night01, 0.0, 1.0)
	if absf(want_glow - _glow) > 0.01:
		_glow = want_glow
		_fish.push_glow(want_glow)
	var step := minf(delta, 0.1) # после паузы меню не телепортируем животных
	for w in whales:
		_step(w, step)
	_sync_water_effects(night01)
	# Полноэкранный raymarch нужен, только если кит реально в кадре: за
	# пределами обзора проход выключаем совсем (на этом экономится кадр).
	_fish.set_sdf_enabled(_any_in_view())
	if debug_on:
		_update_debug()


## Поставить стаю у точки (кадры CI и сюжетные сцены): один кит дышит,
## второй идёт под поверхностью — видно оба состояния сразу.
func place_near(at: Vector3, forward: Vector3) -> void:
	_ensure()
	if _fish == null:
		return
	var fwd := Vector2(forward.x, forward.z)
	if fwd.length() < 0.01:
		fwd = Vector2.UP
	fwd = fwd.normalized()
	var side := Vector2(-fwd.y, fwd.x)
	for w in whales:
		var sign_side := 1.0 if w.slot % 2 == 0 else -1.0
		var p := Vector2(at.x, at.z) + fwd * 9.0 + side * sign_side * 12.0
		w.pos = Vector3(p.x, 0.0, p.y)
		w.heading = atan2(fwd.y, fwd.x) + (0.25 if sign_side > 0.0 else -0.25)
		w.speed = 1.8
		w.target_speed = 1.8
		w.state = ST_SURFACE if w.slot == 0 else ST_DIVE
		w.depth_target = SURFACE_DEPTH if w.slot == 0 else SHALLOW_DEPTH
		w.timer = 6.0
		w.vy = 0.0
		w.pitch = 0.0
		w.y = main.water.surface_height(w.pos.x, w.pos.z) - w.depth_target
		w.pos.y = w.y
		w.prev_depth = w.depth_target
		w.surface_contact = w.depth_target < 0.2
		_reset_trail(w)
		_push(w)


## Есть ли тело в кадре (с запасом на габарит: 4 м в сторону камеры).
func _any_in_view() -> bool:
	if main == null or main.camera == null:
		return true
	for w in whales:
		var center := Vector3(w.pos.x, w.y, w.pos.z)
		var to_cam := main.camera.global_position - center
		var probe := center + to_cam.normalized() * 4.0
		if main.camera.is_position_in_frustum(probe):
			return true
	return false


## Ближайший кит к мировой точке (-1 — никого).
func nearest_to(at: Vector3) -> int:
	var best := -1
	var best_d := INF
	for i in range(whales.size()):
		var d := Vector2(whales[i].pos.x, whales[i].pos.z).distance_to(Vector2(at.x, at.z))
		if d < best_d:
			best_d = d
			best = i
	return best


func nearest_distance(at: Vector3) -> float:
	var index := nearest_to(at)
	if index < 0:
		return -1.0
	var w: Whale = whales[index]
	return Vector2(w.pos.x, w.pos.z).distance_to(Vector2(at.x, at.z))


func debug_toggle() -> void:
	debug_on = not debug_on
	if _panel != null:
		_panel.visible = debug_on
	for label in _labels:
		label.visible = debug_on
	if _markers != null:
		_markers.visible = debug_on
	print("[WHALES] отладка: %s · %s" % ["вкл" if debug_on else "выкл", _debug_line()])


func _debug_line() -> String:
	if whales.is_empty():
		return "китов нет"
	var parts: Array[String] = []
	for i in range(whales.size()):
		var w: Whale = whales[i]
		var surf := main.water.surface_height(w.pos.x, w.pos.z) if main != null and main.water != null else 0.0
		parts.append("%d: %s %.1fм %.1fм/с" % [i, STATE_NAMES[w.state],
			surf - w.y, w.speed])
	return " · ".join(parts)


# ---------------------------------------------------------------------------
# Шаг животного
# ---------------------------------------------------------------------------

func _step(w: Whale, delta: float) -> void:
	w.timer -= delta
	w.interest = maxf(0.0, w.interest - delta)
	w.ignore = maxf(0.0, w.ignore - delta)
	if w.timer <= 0.0:
		_next_state(w)

	var pos2 := Vector2(w.pos.x, w.pos.z)
	var desired := _desired_heading(w, pos2, delta)
	var diff := wrapf(desired - w.heading, -PI, PI)
	# Тяжёлый разворот: даже испугавшись, кит не меняет курс мгновенно.
	var rate := TURN_RATE * (1.0 + 0.5 * clampf(w.interest, 0.0, 1.0)) * delta
	w.heading += clampf(diff, -rate, rate)

	w.speed = lerpf(w.speed, w.target_speed, 1.0 - exp(-1.1 * delta))
	w.pos.x += cos(w.heading) * w.speed * delta
	w.pos.z += sin(w.heading) * w.speed * delta

	# Высота: пружина к «поверхность − глубина». Критическое демпфирование,
	# поэтому выход на новую глубину — плавная дуга, а не ступенька.
	var surf := main.water.surface_height(w.pos.x, w.pos.z)
	var target_y := surf - w.depth_target
	var damping := 2.0 * sqrt(SPRING)
	w.vy += (SPRING * (target_y - w.y) - damping * w.vy) * delta
	w.y += w.vy * delta
	w.pos.y = w.y

	# Тангаж — из вертикальной скорости: чем быстрее тонет, тем круче нос вниз.
	var pitch_want := clampf(atan2(w.vy, maxf(w.speed, 0.6)), -0.45, 0.45)
	w.pitch = lerpf(w.pitch, pitch_want, 1.0 - exp(-4.0 * delta))

	# Гребок с планированием: частота хвоста медленно дышит, а не звенит.
	w.glide_t += delta
	var glide := 0.40 + 0.60 * (0.5 + 0.5 * sin(w.glide_t * 0.37 + float(w.slot) * 2.1))
	w.beat += delta * (2.0 + 1.6 * w.speed) * glide

	_water_reaction(w, delta, surf)
	_push(w)


func _next_state(w: Whale) -> void:
	match w.state:
		ST_SURFACE:
			w.state = ST_DIVE
			w.depth_target = DEEP_DEPTH
			w.target_speed = CRUISE_MIN
			w.timer = randf_range(10.0, 18.0)
		ST_DIVE:
			w.state = ST_DEEP
			w.depth_target = DEEP_DEPTH + randf_range(-1.0, 2.0)
			w.target_speed = randf_range(CRUISE_MIN, CRUISE_MAX)
			w.timer = randf_range(10.0, 20.0)
		ST_DEEP:
			w.state = ST_RISE
			w.depth_target = SHALLOW_DEPTH
			w.target_speed = CRUISE_MAX
			w.timer = randf_range(5.0, 9.0)
		_:
			w.state = ST_SURFACE
			w.depth_target = SURFACE_DEPTH
			w.target_speed = randf_range(1.0, 1.5)
			w.timer = randf_range(3.0, 6.0)
			_blow(w)


## Выдох на поверхности: фонтан брызг и кольцо в воде.
func _blow(w: Whale) -> void:
	if _fish == null:
		return
	var head := Vector3(w.pos.x, w.y + 0.6, w.pos.z)
	_fish.splash_burst(head, 1.2)
	if main.water.field != null:
		main.water.field.splash(Vector2(w.pos.x, w.pos.z), 1.4)


## Взаимодействие с водой: след, кольца, брызги на пересечении поверхности.
func _water_reaction(w: Whale, delta: float, surf: float) -> void:
	var depth_now := surf - w.y
	var was := w.prev_depth
	w.prev_depth = depth_now
	# Гистерезис: небольшие волны не создают непрерывные ложные всплески.
	if not w.surface_contact and depth_now < 0.0:
		w.surface_contact = true
		if _fish != null and was > 0.0:
			_fish.splash_burst(Vector3(w.pos.x, surf, w.pos.z), 1.35)
	elif w.surface_contact and depth_now > 0.7:
		w.surface_contact = false
		if _fish != null:
			_fish.splash_burst(Vector3(w.pos.x, surf, w.pos.z), 1.0)
	_record_trail(w, delta, depth_now)
	if depth_now > 1.6:
		return
	w.wake_t -= delta
	if w.wake_t > 0.0:
		return
	w.wake_t = WAKE_INTERVAL
	if main.water.field != null:
		var strength := clampf(0.22 + 0.18 * w.speed + 0.25 * clampf(1.4 - depth_now, 0.0, 1.4),
			0.18, 0.85)
		main.water.field.wake(Vector2(w.pos.x, w.pos.z), strength)


## Независимая мировая история каждого кита; прошлые волны не приклеены к телу.
func _reset_trail(w: Whale) -> void:
	w.trail.resize(TRAIL_POINTS)
	w.trail.fill(Vector4(0.0, 0.0, -1000.0, 0.0))
	w.trail_clock = 0.0


func _record_trail(w: Whale, delta: float, depth: float) -> void:
	if w.trail.size() != TRAIL_POINTS:
		_reset_trail(w)
	w.trail_clock -= delta
	if w.trail_clock > 0.0 or depth > 1.6:
		return
	w.trail_clock = TRAIL_SAMPLE
	for i in range(TRAIL_POINTS - 1, 0, -1):
		w.trail[i] = w.trail[i - 1]
	var contact := clampf((1.6 - depth) / 1.6, 0.0, 1.0)
	w.trail[0] = Vector4(w.pos.x, w.pos.z, main.water.field.t, contact * clampf(w.speed / 1.8, 0.0, 1.0))


## Параметры на самом материале моря: свет сквозь воду, тень и след.
func _sync_water_effects(night01: float) -> void:
	var bodies := PackedVector4Array()
	var states := PackedVector4Array()
	var trails := PackedVector4Array()
	bodies.resize(WHALE_COUNT)
	states.resize(WHALE_COUNT)
	trails.resize(WHALE_COUNT * TRAIL_POINTS)
	trails.fill(Vector4(0.0, 0.0, -1000.0, 0.0))
	for w in whales:
		var surface := main.water.surface_height(w.pos.x, w.pos.z)
		bodies[w.slot] = Vector4(w.pos.x, w.pos.z, w.heading, surface - w.y)
		states[w.slot] = Vector4(w.speed, w.pitch, w.beat, 1.0)
		for i in range(w.trail.size()):
			trails[w.slot * TRAIL_POINTS + i] = w.trail[i]
	main.water.set_param("u_whale_bodies", bodies)
	main.water.set_param("u_whale_states", states)
	main.water.set_param("u_whale_trails", trails)
	main.water.set_param("u_whale_night", clampf(night01, 0.0, 1.0))


func _push(w: Whale) -> void:
	if _fish == null:
		return
	_fish.push_creature(w.slot, Vector3(w.pos.x, w.y, w.pos.z), w.heading,
		BODY_SIZE, w.beat, TINT, w.pitch)


# ---------------------------------------------------------------------------
# Курс: блуждание + правила
# ---------------------------------------------------------------------------

func _desired_heading(w: Whale, pos2: Vector2, delta: float) -> float:
	# Свой медленный дрейф курса — животное не идёт по рельсам.
	w.bias = clampf(w.bias + (randf() - 0.5) * 0.9 * delta, -0.55, 0.55)
	var dir := Vector2(cos(w.heading + w.bias), sin(w.heading + w.bias))

	dir += _shore_push(w, pos2) * 2.4
	dir += _reef_push(pos2) * 2.0
	var threat := _boat_threat(pos2)
	if threat.length() > 0.01:
		dir += threat * 3.0
		w.target_speed = maxf(w.target_speed, CRUISE_MAX * 1.15)
	else:
		dir += _curiosity(w, pos2, delta) * 1.1
	if dir.length() < 0.01:
		dir = Vector2(cos(w.heading), sin(w.heading))
	return atan2(dir.y, dir.x)


## Мелководье впереди: кит разворачивается в море задолго до берега.
func _shore_push(w: Whale, pos2: Vector2) -> Vector2:
	if main.coast == null:
		return Vector2.ZERO
	var here := main.coast.water_depth(pos2.x, pos2.y)
	var fwd := Vector2(cos(w.heading), sin(w.heading))
	var ahead := pos2 + fwd * SHORE_PROBE
	var depth_ahead := minf(here, main.coast.water_depth(ahead.x, ahead.y))
	if depth_ahead >= DEEP_WATER:
		return Vector2.ZERO
	var land := main.coast.land_dir(ahead.x, ahead.y)
	var sea := Vector2(-land.x, -land.z)
	if sea.length() < 0.01:
		return Vector2.ZERO
	var urgency := clampf((DEEP_WATER - depth_ahead) / DEEP_WATER, 0.0, 1.0)
	return sea.normalized() * (0.5 + urgency)


func _reef_push(pos2: Vector2) -> Vector2:
	var push := Vector2.ZERO
	if main.reefs.is_empty():
		return push
	for reef in main.reefs:
		var rp: Vector2 = reef["pos"]
		var radius: float = reef["radius"]
		var d := pos2.distance_to(rp)
		var reach := radius + 26.0
		if d > reach:
			continue
		var away := pos2 - rp
		if away.length() < 0.3:
			away = Vector2(1.0, 0.0)
		push += away.normalized() * (1.0 - d / reach)
	return push


## Упреждение: где судно окажется через BOAT_LOOKAHEAD секунд и насколько
## близко оно пройдёт. Уходим в сторону расхождения, а не «назад».
func _boat_threat(pos2: Vector2) -> Vector2:
	var boat := main.boat if main != null else null
	if boat == null:
		return Vector2.ZERO
	var bp := Vector2(boat.global_position.x, boat.global_position.z)
	var rel := pos2 - bp
	if rel.length() > BOAT_CLEARANCE + 45.0:
		return Vector2.ZERO
	var fwd3 := -boat.global_transform.basis.z
	var fwd := Vector2(fwd3.x, fwd3.z)
	if fwd.length() < 0.01:
		fwd = Vector2.RIGHT
	var vel := fwd.normalized() * boat.speed
	var v2 := vel.length_squared()
	var t_close := 0.0
	if v2 > 0.01:
		t_close = clampf(-rel.dot(vel) / v2, 0.0, BOAT_LOOKAHEAD)
	var miss := rel + vel * t_close
	var miss_d := miss.length()
	if miss_d > BOAT_CLEARANCE + 4.0:
		return Vector2.ZERO
	var away := miss / miss_d if miss_d > 0.3 else Vector2(-vel.y, vel.x)
	if away.length() < 0.01:
		away = Vector2.RIGHT
	var urgency := 1.0 - clampf((miss_d - 3.0) / (BOAT_CLEARANCE + 4.0), 0.0, 1.0)
	if rel.length() < BOAT_PANIC:
		urgency = maxf(urgency, 0.95)
	return away.normalized() * (0.6 + 2.2 * urgency)


## Любопытство: судно рядом — кит подходит параллельным курсом в стороне,
## потом теряет интерес. Это проявление характера, а не следование за игроком.
func _curiosity(w: Whale, pos2: Vector2, delta: float) -> Vector2:
	if main.boat == null or main.coast == null:
		return Vector2.ZERO
	var boat := main.boat
	var bp := Vector2(boat.global_position.x, boat.global_position.z)
	var dist := pos2.distance_to(bp)
	if w.interest <= 0.0 and w.ignore <= 0.0:
		if dist < INTEREST_RANGE and randf() < 0.25 * delta:
			w.interest = randf_range(9.0, 18.0)
			w.ignore = 0.0
		else:
			return Vector2.ZERO
	if w.interest <= 0.0:
		return Vector2.ZERO
	# Точка в стороне от курса судна: кит идёт рядом, но не под винт.
	var fwd3 := -boat.global_transform.basis.z
	var fwd := Vector2(fwd3.x, fwd3.z)
	if fwd.length() < 0.01:
		fwd = Vector2.RIGHT
	fwd = fwd.normalized()
	var side := Vector2(-fwd.y, fwd.x)
	var want := bp + fwd * 6.0 + side * INTEREST_SIDE * (1.0 if w.slot % 2 == 0 else -1.0)
	var to := want - pos2
	if to.length() < 4.0:
		w.interest = minf(w.interest, 2.0)
		if w.interest <= 0.0:
			w.ignore = randf_range(20.0, 45.0)
		return Vector2.ZERO
	return to.normalized() * 0.9


# ---------------------------------------------------------------------------
# Спавн и рендер
# ---------------------------------------------------------------------------

func _ensure() -> void:
	if _fish != null:
		return
	if main == null or main.water == null or main.coast == null:
		return
	_fish = SandFish.new()
	_fish.name = "WhaleSdf"
	_fish.fish_count = WHALE_COUNT
	_fish.bounds_radius = BOUNDS_RADIUS
	_fish.setup(main.game, main.water.level_y, main.water.field, null)
	add_child(_fish)
	_fish.set_external(true)
	if _fish.mat != null:
		_fish.mat.set_shader_parameter("max_steps", SDF_STEPS)
		_fish.mat.set_shader_parameter("epsilon", SDF_EPSILON)
	# Тело под водой рисует сам шейдер (сквозь поверхность), без квадов-заглушек.
	_fish.push_underwater(1.0)
	_fish.push_glow(0.0)
	_glow = 0.0
	_spawn_all()


func _spawn_all() -> void:
	whales.clear()
	for i in range(WHALE_COUNT):
		var w := Whale.new()
		w.slot = i
		_reset_trail(w)
		w.state = ST_SURFACE if i == 0 else ST_DIVE
		w.timer = randf_range(2.0, 6.0)
		w.interest = 0.0
		w.ignore = randf_range(0.0, 8.0)
		w.beat = randf() * TAU
		w.glide_t = randf() * 10.0
		_place_wild(w)
		whales.append(w)
		_push(w)


## Свободное место в море: недалеко от острова, на глубине, не под судном.
func _place_wild(w: Whale) -> void:
	var boat_at := Vector2.ZERO
	if main.boat != null:
		boat_at = Vector2(main.boat.global_position.x, main.boat.global_position.z)
	var z_center := boat_at.y
	var placed := false
	for _attempt in range(80):
		var z := z_center + randf_range(-150.0, 150.0)
		var shore := main.coast.shore_x(z)
		var x := shore - randf_range(45.0, 185.0)
		if main.coast.water_depth(x, z) < 6.0:
			continue
		var p := Vector2(x, z)
		if p.distance_to(boat_at) < 45.0:
			continue
		if w.slot == 1 and not whales.is_empty():
			if p.distance_to(Vector2(whales[0].pos.x, whales[0].pos.z)) < 30.0:
				continue
		w.pos = Vector3(x, 0.0, z)
		w.heading = randf() * TAU
		w.depth_target = SURFACE_DEPTH if w.state == ST_SURFACE else DEEP_DEPTH
		w.speed = randf_range(CRUISE_MIN, CRUISE_MAX)
		w.target_speed = w.speed
		w.y = main.water.surface_height(x, z) - w.depth_target
		w.vy = 0.0
		placed = true
		break
	if placed:
		return
	# Страховка: если свободного места не нашлось, ставим у берега на глубине.
	var z_fallback := z_center
	w.pos = Vector3(main.coast.shore_x(z_fallback) - 90.0, 0.0, z_fallback)
	w.heading = randf() * TAU
	w.depth_target = DEEP_DEPTH
	w.y = main.water.surface_height(w.pos.x, w.pos.z) - DEEP_DEPTH


# ---------------------------------------------------------------------------
# Отладка: маркеры в мире и панель, чтобы китов не приходилось искать
# ---------------------------------------------------------------------------

func _update_debug() -> void:
	if _fish == null:
		return
	if _markers == null:
		_build_debug_nodes()
	if _marker_mat == null:
		_marker_mat = _debug_material()
	_marker_mesh.clear_surfaces()
	_marker_mesh.surface_begin(Mesh.PRIMITIVE_LINES, _marker_mat)
	for i in range(whales.size()):
		var w: Whale = whales[i]
		var surf := main.water.surface_height(w.pos.x, w.pos.z)
		var base := Vector3(w.pos.x, surf + 0.05, w.pos.z)
		var body := Vector3(w.pos.x, w.y, w.pos.z)
		# Круг на воде + вертикаль до тела: сразу видно, на поверхности кит или под ней.
		_ring(base, 3.2, 20)
		_marker_mesh.surface_add_vertex(base)
		_marker_mesh.surface_add_vertex(body)
		# Курс — стрелка.
		var fwd := Vector3(cos(w.heading), 0.0, sin(w.heading))
		_marker_mesh.surface_add_vertex(body)
		_marker_mesh.surface_add_vertex(body + fwd * 6.0)
		_marker_mesh.surface_add_vertex(body + fwd * 6.0)
		_marker_mesh.surface_add_vertex(body + fwd * 4.0 + Vector3(fwd.z, 0.0, -fwd.x) * 1.2)
		if _labels.size() > i:
			var label: Label3D = _labels[i]
			label.visible = true
			label.global_position = body + Vector3(0.0, 4.2, 0.0)
			label.text = "%d · %s · %.1f м · %.1f м/с" % [i, STATE_NAMES[w.state],
				surf - w.y, w.speed]
	_marker_mesh.surface_end()
	if _panel != null:
		_panel.visible = true
		_panel.text = "КИТЫ [F9]  %s\n[F10] — судно к ближайшему киту" % _debug_line()


func _ring(center: Vector3, radius: float, segments: int) -> void:
	var prev := center + Vector3(radius, 0.0, 0.0)
	for s in range(1, segments + 1):
		var a := TAU * float(s) / float(segments)
		var p := center + Vector3(cos(a) * radius, 0.0, sin(a) * radius)
		_marker_mesh.surface_add_vertex(prev)
		_marker_mesh.surface_add_vertex(p)
		prev = p


func _build_debug_nodes() -> void:
	_marker_mesh = ImmediateMesh.new()
	_markers = MeshInstance3D.new()
	_markers.name = "WhaleDebug"
	_markers.mesh = _marker_mesh
	_markers.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_markers.visible = debug_on
	add_child(_markers)
	for i in range(WHALE_COUNT):
		var label := Label3D.new()
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		label.fixed_size = true
		label.pixel_size = 0.0016
		label.font_size = 64
		label.outline_size = 18
		label.modulate = Color(0.85, 1.0, 0.95)
		label.outline_modulate = Color(0.0, 0.0, 0.0, 0.85)
		label.visible = debug_on
		add_child(label)
		_labels.append(label)
	var layer := CanvasLayer.new()
	layer.name = "WhaleDebugUi"
	add_child(layer)
	_panel = Label.new()
	_panel.position = Vector2(24.0, 24.0)
	_panel.add_theme_color_override("font_color", Color(0.75, 1.0, 0.9))
	_panel.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0))
	_panel.add_theme_constant_override("outline_size", 6)
	_panel.add_theme_font_size_override("font_size", 22)
	_panel.visible = debug_on
	layer.add_child(_panel)


func _debug_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.no_depth_test = true
	m.albedo_color = Color(0.55, 1.0, 0.85)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color.a = 0.85
	return m
