class_name RodCast
extends Node3D
## Удочка от первого лица: «достать» → заряд → заброс (Безье, нормировка
## длиной дуги, всё на delta) → поплавок на воде → поклёвка → подсечка →
## вываживание → рыба в руках.
##
## Вешается НА КАМЕРУ (вью-модель, как раньше руки с пистолетом):
##   var rod := RodCast.new()
##   cam_rig.cam.add_child(rod)
##   rod.setup(game, water, fish, coast, sand)
##
## Управление:
##   ЛКМ (удочка опущена) — достать удочку
##   ЛКМ зажать     — заряд силы (ходит туда-обратно, видно по позе удилища)
##   ЛКМ отпустить  — заброс туда, куда смотрит камера (6–48 м от силы)
##   ЛКМ в окно поклёвки (поплавок нырнул) — подсечка
##   ЛКМ держать в вываживании — мотать; в рывок рыбы нельзя: натяг растёт
##   ПКМ / R        — вернуть снасть / отменить заряд
##   Q              — убрать удочку
##
## HUD нет (конвенция проекта): сила читается по изгибу удилища, поклёвка —
## по нырку поплавка и кольцам на воде.
##
## Сигналы: cast_started(power), bobber_landed(pos), cast_landed_on_sand(pos),
## bite_window_started(), fish_hooked(), fish_landed(size), fish_escaped(),
## line_retrieved(), reel_tick().

signal cast_started(power: float)
signal bobber_landed(pos: Vector3)
signal cast_landed_on_sand(pos: Vector3)
signal bite_window_started()
signal fish_hooked()
signal fish_landed(size: float)
signal fish_escaped()
signal line_retrieved()
signal reel_tick()

enum S { RESTING, CHARGE, FLY, FLOAT, BITE, FIGHT, REEL_IN }

# --- заброс ---
const MIN_CAST := 6.0 # м, ближе не плюнет
const CAST_RANGE := 42.0 # м поверх минимума при полной силе
const CAST_SPEED := 26.0 # м/с полёта поплавка (путь нормирован длиной дуги)
const CHARGE_PERIOD := 1.7 # с на полный ход силы туда-обратно

# --- рыбалка ---
const BITE_WINDOW := 0.55 # с, окно подсечки (рыба держит 0.85 — с запасом)
const REEL_SPEED := 6.5 # м/с подмотки с зажатой ЛКМ
const REEL_ASSIST := 1.1 # м/с ленивая подмотка без ЛКМ — чтобы не зависало
const FIGHT_MAX_DIST := 34.0 # м, дальше рыба вырывает леску (но не рвёт)
const TENSION_RATE := 1.9 # натяг растёт, если мотать в момент рывка
const LAND_DIST := 3.2 # м — рыба у игрока
const REEL_TICK := 0.11 # с между щелчками катушки

# --- поза удилища (в пространстве камеры) ---
const GRIP_POS := Vector3(0.18, -0.17, -0.32)
const GRIP_ROT := Vector3(-0.42, 0.10, -0.14) # вперёд-вверх, чуть вправо
const STOW_POS := Vector3(0.30, -0.08, -0.40)
const STOW_ROT := Vector3(-2.25, 0.34, -0.42) # удилище вниз-вперёд, «в руке»
const TIP_LOCAL := Vector3(0.0, 0.56, 0.0) # кончик вершинки в шарнире _tip

var game: GameState # автозагрузка Game — только ветер для дрейфа поплавка
var water: WaterSurface # WaterSurface — уровень/высота воды
var fish: SandFish # SandFish — всплески, приманивание, подсечка
var coast: Coast # Coast — чтобы не забрасывать «в песок» вслепую
var sand: SandField # SandField — вмятины от поплавка на песке
var state: int = S.RESTING
var stowed := true # удочка опущена (в руке, но не наготове)
var on_land := false # поплавок лежит на песке

var _cam: Camera3D
var _t := 0.0
var _suppress := 0.35 # с тишины после старта (клик захвата курсора)

# удилище
var _root: Node3D # рукоять + комель
var _tip: Node3D # шарнир вершинки (изгиб)
var _bend := 0.03
var _bend_tgt := 0.03
var _pose01 := 0.0 # 0 — опущена, 1 — наготове

# мир (top_level: дети живут в мировых координатах)
var _world: Node3D
var _bobber: Node3D
var _line_mi: MeshInstance3D
var _line_mesh: ImmediateMesh

# заряд/заброс
var _power_t := 0.0
var _bez_a := Vector3.ZERO
var _bez_b := Vector3.ZERO
var _bez_c := Vector3.ZERO
var _lut := PackedFloat32Array()
var _bez_len := 1.0
var _fly_s := 0.0

# рыбалка
var _bite_t := 0.0
var _relure_t := 0.0
var _window_t := 0.0
var _lure_idx := -1
var _dive := 0.0
var _dive_tgt := 0.0
var _jiggle := 0.0
var _pulling := false
var _pull_t := 0.0
var _tension := 0.0
var _tick_t := 0.0


func _ready() -> void:
	_ensure_actions()
	_cam = get_parent() as Camera3D
	if _cam == null:
		push_error("ROD: RodCast должен висеть на Camera3D")
	_build_rod()
	_build_world()


## Подключение к игре. water: WaterSurface, fish: SandFish (можно null —
## тогда удочка работает, но рыбы клевать не будут).
func setup(game_ref, water_ref, fish_ref, coast_ref = null, sand_ref = null) -> void:
	game = game_ref
	water = water_ref
	fish = fish_ref
	coast = coast_ref
	sand = sand_ref
	if fish != null and not fish.nibbled.is_connected(_on_fish_nibbled):
		fish.nibbled.connect(_on_fish_nibbled)
		fish.biting.connect(_on_fish_biting)
		fish.fish_freed.connect(_on_fish_freed)


func _ensure_actions() -> void:
	_add_mouse_action("rod_cast", MOUSE_BUTTON_LEFT)
	_add_mouse_action("rod_recall", MOUSE_BUTTON_RIGHT)
	if InputMap.has_action("rod_recall"):
		var k := InputEventKey.new()
		k.physical_keycode = KEY_R
		InputMap.action_add_event("rod_recall", k)
	_add_key_action("rod_toggle", KEY_Q)


func _add_mouse_action(action: String, button: int) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)


func _add_key_action(action: String, key: int) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	var ev := InputEventKey.new()
	ev.physical_keycode = key
	InputMap.action_add_event(action, ev)


func _process(delta: float) -> void:
	_t += delta
	if _suppress > 0.0:
		_suppress -= delta
	match state:
		S.RESTING:
			_st_resting(delta)
		S.CHARGE:
			_st_charge(delta)
		S.FLY:
			_st_fly(delta)
		S.FLOAT:
			_st_float(delta)
		S.BITE:
			_st_bite(delta)
		S.FIGHT:
			_st_fight(delta)
		S.REEL_IN:
			_st_reel(delta)
	_update_pose(delta)
	_animate_rod(delta)
	_draw_line()


# ---------------------------------------------------------------------------
# Состояния
# ---------------------------------------------------------------------------

func _st_resting(_delta: float) -> void:
	_bend_tgt = 0.03 + 0.015 * sin(_t * 1.3)
	if _suppress > 0.0:
		return
	if stowed:
		# первый клик — достаём удочку (не забрасываем той же кнопкой)
		if Input.is_action_just_pressed("rod_cast") and water != null:
			stowed = false
		return
	if Input.is_action_just_pressed("rod_toggle"):
		stowed = true
		return
	if water != null and Input.is_action_just_pressed("rod_cast"):
		state = S.CHARGE
		_power_t = 0.0


func charge_power() -> float:
	# 0→1→0, период CHARGE_PERIOD (без глобального pingpong — совместимо везде)
	var t := fmod(_power_t / CHARGE_PERIOD, 2.0)
	return 1.0 - absf(t - 1.0)


func _st_charge(delta: float) -> void:
	_power_t += delta
	var p := charge_power()
	_bend_tgt = 0.06 + 0.34 * p # удилище откидывается назад
	if Input.is_action_just_released("rod_cast"):
		_cast(p)
	elif Input.is_action_just_pressed("rod_recall"):
		state = S.RESTING


## Целимся: сначала вода, но если по лучу раньше встречается песок —
## поплавок падает на песок (и рыбы туда не придут).
func _cast(power: float) -> void:
	if _cam == null or water == null:
		return
	var origin := _cam.global_position
	var fdir := -_cam.global_transform.basis.z
	var hd := Vector2(fdir.x, fdir.z)
	if hd.length_squared() < 1e-6:
		hd = Vector2(0.0, -1.0)
	hd = hd.normalized()

	var max_d := MIN_CAST + power * CAST_RANGE
	var water_d := INF
	if fdir.y < -0.02:
		var wd: float = (water.level_y - origin.y) / fdir.y
		if wd > 0.0:
			water_d = wd
	var land_d := INF
	if coast != null:
		land_d = _ray_ground(origin, fdir, max_d + 50.0)

	var dist := max_d
	on_land = false
	var land_point := Vector3.ZERO
	if land_d < water_d and land_d < max_d + 0.01:
		on_land = true
		land_point = origin + fdir * land_d
		dist = land_d
	elif water_d < INF:
		dist = minf(water_d, max_d)

	var target := Vector3(origin.x + hd.x * dist, water.level_y, origin.z + hd.y * dist)
	if not on_land and coast != null and not coast.is_water(target.x, target.z):
		# луч пересёк уровень моря НАД сушей (слабый заброс вдоль пляжа) —
		# это песок, а не вода: поплавок должен лечь на него, а не висеть
		on_land = true
		land_point = target
		dist = maxf(land_point.distance_to(origin), 0.5)
		target = Vector3(target.x, coast.ground_height(target.x, target.z) + 0.06, target.z)
	if on_land:
		var gh := coast.ground_height(land_point.x, land_point.z)
		target = Vector3(land_point.x, gh + 0.06, land_point.z)

	_bez_a = _tip.to_global(TIP_LOCAL)
	_bez_c = target
	_bez_b = (_bez_a + _bez_c) * 0.5 + Vector3.UP * (1.5 + 0.28 * dist)
	_build_lut()
	_bez_len = _lut[12]
	_fly_s = 0.0
	_bobber.visible = true
	state = S.FLY
	cast_started.emit(power)


func _st_fly(delta: float) -> void:
	_fly_s += delta * CAST_SPEED # путь нормирован длиной дуги — скорость честная
	var u := _lut_u(_fly_s)
	_bobber.global_position = _bez(_bez_a, _bez_b, _bez_c, u)
	_bend_tgt = -0.26 # хлыст вперёд
	if _fly_s >= _bez_len:
		_bobber.global_position = _bez_c
		if on_land:
			# шлёпнулся на песок: вмятина, никакой рыбы
			if sand != null:
				sand.stamp_foot(
					Vector2(_bez_c.x, _bez_c.z), Vector2(0.0, -1.0),
					0.16, 0.20, 0.022, 0.012
				)
			_bite_t = 999.0
			_lure_idx = -1
			cast_landed_on_sand.emit(_bez_c)
			state = S.FLOAT
		else:
			if fish != null:
				fish.splash_burst(_bez_c, 0.8) # капли + кольцо в WaterField
				_lure_idx = fish.lure_to(_bez_c)
			else:
				_lure_idx = -1
			if water != null and water.field != null:
				water.field.splash(Vector2(_bez_c.x, _bez_c.z), 0.8)
			_bite_t = randf_range(4.0, 9.0)
			_relure_t = 2.0
			bobber_landed.emit(_bez_c)
			state = S.FLOAT


func _st_float(delta: float) -> void:
	_dive_tgt = 0.0
	_bobber.global_position = _sit(delta)
	_bend_tgt = 0.10 + 0.02 * sin(_t * 1.1)
	if not on_land and fish != null:
		fish.lure_refresh(_bobber.global_position)
		_bite_t -= delta
		_relure_t -= delta
		if _lure_idx == -1 and _bite_t <= 0.0 and _relure_t <= 0.0:
			_lure_idx = fish.lure_to(_bobber.global_position)
			_relure_t = 2.0
	if Input.is_action_just_pressed("rod_recall"):
		_recall()


func _st_bite(delta: float) -> void:
	# рыба тащит поплавок под воду — окно подсечки
	_window_t -= delta
	_bobber.global_position = _sit(delta)
	_bend_tgt = 0.30
	if _window_t <= 0.0:
		state = S.FLOAT # прозевал — рыба сама выйдет из игры (fish_freed)
		return
	if _suppress <= 0.0 and Input.is_action_just_pressed("rod_cast"):
		if fish != null and _lure_idx != -1 and fish.hook(_lure_idx):
			state = S.FIGHT
			_pulling = false
			_pull_t = 0.8
			_tension = 0.0
			fish_hooked.emit()
	if Input.is_action_just_pressed("rod_recall"):
		_recall()


func _st_fight(delta: float) -> void:
	_pull_t -= delta
	if _pull_t <= 0.0:
		_pulling = not _pulling
		_pull_t = randf_range(0.8, 1.4) if _pulling else randf_range(0.9, 1.7)
		if _pulling and water != null and water.field != null:
			var b := _bobber.global_position
			water.field.splash(Vector2(b.x, b.z), 0.5) # рывок — кольцо
	var bp := _bobber.global_position
	var cp := _cam.global_position
	var to_cam := Vector2(cp.x - bp.x, cp.z - bp.z)
	var dcam := to_cam.length()
	var held := Input.is_action_pressed("rod_cast") and _suppress <= 0.0
	if fish != null:
		fish.hooked_refresh(bp) # рыба на крючке следует за поплавком
	_tick_t -= delta
	if _pulling:
		# рыба тянет ОТ игрока; мотать в этот момент — накапливать натяг
		if dcam < FIGHT_MAX_DIST:
			var away := Vector3(-to_cam.x, 0.0, -to_cam.y).normalized()
			bp += away * 2.3 * delta
		if held:
			_tension += delta * TENSION_RATE
			if _tick_t <= 0.0:
				_tick_t = REEL_TICK
				reel_tick.emit()
		else:
			_tension = maxf(0.0, _tension - delta * 1.1)
		if _tension >= 1.0:
			_escape()
			return
	else:
		# затишье — мотаем (с ЛКМ быстро, без неё лениво)
		var spd := REEL_SPEED if held else REEL_ASSIST
		if held and _tick_t <= 0.0:
			_tick_t = REEL_TICK
			reel_tick.emit()
		if dcam > LAND_DIST:
			var home := Vector3(to_cam.x, 0.0, to_cam.y).normalized()
			bp += home * spd * delta
			if water != null and water.field != null:
				water.field.wake(Vector2(bp.x, bp.z), 0.6)
		else:
			_land()
			return
	var dive := -0.12 if _pulling else -0.03
	if water != null:
		var wy := water.surface_height(bp.x, bp.z)
		if coast != null:
			wy = maxf(wy, coast.ground_height(bp.x, bp.z) + 0.03)
		bp.y = wy + 0.035 + dive
	_bobber.global_position = bp
	if _pulling:
		_bend_tgt = 0.46 + 0.06 * sin(_t * 31.0)
	else:
		_bend_tgt = 0.30 + 0.03 * sin(_t * 17.0)


func _st_reel(delta: float) -> void:
	var bp := _bobber.global_position
	var cp := _cam.global_position
	var to_cam := Vector2(cp.x - bp.x, cp.z - bp.z)
	if to_cam.length() > 2.6:
		var home := Vector3(to_cam.x, 0.0, to_cam.y).normalized()
		bp += home * 9.0 * delta
		if on_land and coast != null:
			bp.y = coast.ground_height(bp.x, bp.z) + 0.06
		elif water != null:
			bp.y = water.surface_height(bp.x, bp.z) + 0.035
		_bobber.global_position = bp
		if water != null and water.field != null and not on_land:
			water.field.wake(Vector2(bp.x, bp.z), 0.7)
		_bend_tgt = 0.22
	else:
		state = S.RESTING
		on_land = false
		_bobber.visible = false
		line_retrieved.emit()


# ---------------------------------------------------------------------------
# События рыб (SandFish)
# ---------------------------------------------------------------------------

func _on_fish_nibbled(idx: int) -> void:
	if state == S.FLOAT and idx == _lure_idx:
		_jiggle = 1.0
		_dive_tgt = -0.02


func _on_fish_biting(idx: int) -> void:
	if state == S.FLOAT and idx == _lure_idx:
		state = S.BITE
		_window_t = BITE_WINDOW
		_dive_tgt = -0.30
		bite_window_started.emit()


func _on_fish_freed(idx: int) -> void:
	if idx == _lure_idx:
		_lure_idx = -1
	if state == S.BITE:
		state = S.FLOAT
		_dive_tgt = 0.0
		_bite_t = randf_range(5.0, 10.0)
		_relure_t = 2.5


# ---------------------------------------------------------------------------
# Переходы
# ---------------------------------------------------------------------------

func _recall() -> void:
	if fish != null and _lure_idx != -1:
		fish.scare(_lure_idx)
		_lure_idx = -1
	_dive_tgt = 0.0
	state = S.REEL_IN


func _land() -> void:
	var sz := 0.0
	if fish != null and _lure_idx != -1:
		sz = fish.claim_catch(_lure_idx)
	_lure_idx = -1
	_dive_tgt = 0.0
	state = S.RESTING
	_bobber.visible = false
	on_land = false
	fish_landed.emit(sz)


func _escape() -> void:
	_tension = 0.0
	if fish != null and _lure_idx != -1:
		fish.splash_burst(_bobber.global_position, 1.2)
		fish.scare(_lure_idx)
	_lure_idx = -1
	_dive_tgt = 0.0
	state = S.FLOAT
	_bite_t = randf_range(6.0, 11.0)
	_relure_t = 3.0
	fish_escaped.emit()


# ---------------------------------------------------------------------------
# Утилиты
# ---------------------------------------------------------------------------

## Посадка поплавка: дрейф по ветру + высота поверхности + нырок.
func _sit(delta: float) -> Vector3:
	var bp := _bobber.global_position
	if game != null:
		var w2 := game.wind_dir()
		bp.x += w2.x * 0.12 * delta
		bp.z += w2.y * 0.12 * delta
	_dive = lerpf(_dive, _dive_tgt, 1.0 - exp(-9.0 * delta))
	_jiggle = maxf(0.0, _jiggle - delta * 2.4)
	if on_land and coast != null:
		bp.y = coast.ground_height(bp.x, bp.z) + 0.06 \
			+ sin(_t * 26.0) * 0.02 * _jiggle
	elif water != null:
		bp.y = water.surface_height(bp.x, bp.z) + 0.035 + _dive \
			+ sin(_t * 26.0) * 0.045 * _jiggle
	return bp


## Марш луча по берегу: где луч встречает песок (или INF).
func _ray_ground(from: Vector3, dir: Vector3, max_d: float) -> float:
	var t := 0.4
	var step := 0.7
	var prev := t
	while t < max_d:
		var p := from + dir * t
		if p.y <= coast.ground_height(p.x, p.z):
			var lo := prev
			var hi := t
			for _k in range(10):
				var mid := (lo + hi) * 0.5
				var pm := from + dir * mid
				if pm.y <= coast.ground_height(pm.x, pm.z):
					hi = mid
				else:
					lo = mid
			return hi
		prev = t
		t += step
		step = minf(step * 1.12, 4.0)
	return INF


func _bez(a: Vector3, b: Vector3, c: Vector3, u: float) -> Vector3:
	var w := 1.0 - u
	return a * (w * w) + b * (2.0 * w * u) + c * (u * u)


## LUT длины дуги Безье: 13 отсчётов, накопленная дистанция.
func _build_lut() -> void:
	_lut.resize(13)
	_lut[0] = 0.0
	var prev := _bez_a
	var acc := 0.0
	for i in range(1, 13):
		var p := _bez(_bez_a, _bez_b, _bez_c, float(i) / 12.0)
		acc += prev.distance_to(p)
		_lut[i] = acc
		prev = p


func _lut_u(s: float) -> float:
	var sc := clampf(s, 0.0, _bez_len)
	for i in range(1, 13):
		if _lut[i] >= sc:
			var lo := _lut[i - 1]
			var hi := _lut[i]
			var f := 0.0 if hi <= lo else (sc - lo) / (hi - lo)
			return (float(i - 1) + f) / 12.0
	return 1.0


# ---------------------------------------------------------------------------
# Вид: удилище, леска, поплавок
# ---------------------------------------------------------------------------

func _build_rod() -> void:
	_root = Node3D.new()
	add_child(_root)

	var mat_h := StandardMaterial3D.new()
	mat_h.albedo_color = Color(0.33, 0.22, 0.13) # тёплое дерево рукояти
	mat_h.roughness = 0.75
	var mat_r := StandardMaterial3D.new()
	mat_r.albedo_color = Color(0.16, 0.13, 0.11) # тёмный углепластик
	mat_r.roughness = 0.5
	var mat_metal := StandardMaterial3D.new()
	mat_metal.albedo_color = Color(0.55, 0.52, 0.46)
	mat_metal.roughness = 0.35
	mat_metal.metallic = 0.6

	var handle := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.017
	cm.bottom_radius = 0.020
	cm.height = 0.26
	handle.mesh = cm
	handle.material_override = mat_h
	handle.position = Vector3(0.0, 0.12, 0.0)
	_root.add_child(handle)

	var butt := MeshInstance3D.new()
	var cb := CylinderMesh.new()
	cb.top_radius = 0.0105
	cb.bottom_radius = 0.0125
	cb.height = 0.52
	butt.mesh = cb
	butt.material_override = mat_r
	butt.position = Vector3(0.0, 0.50, 0.0)
	_root.add_child(butt)

	_tip = Node3D.new()
	_tip.position = Vector3(0.0, 0.76, 0.0)
	_root.add_child(_tip)
	var top := MeshInstance3D.new()
	var ct := CylinderMesh.new()
	ct.top_radius = 0.0025
	ct.bottom_radius = 0.0102
	ct.height = 0.56
	top.mesh = ct
	top.material_override = mat_r
	top.position = Vector3(0.0, 0.28, 0.0)
	_tip.add_child(top)

	# катушка — плоское кольцо, повёрнутое к камере
	var reel := MeshInstance3D.new()
	var tr := TorusMesh.new()
	tr.inner_radius = 0.028
	tr.outer_radius = 0.042
	reel.mesh = tr
	reel.material_override = mat_metal
	reel.position = Vector3(-0.05, 0.14, 0.0)
	reel.rotation.x = PI * 0.5
	_root.add_child(reel)

	# «вертлюг» — маленькая серебристая гайка на комле
	var knot := MeshInstance3D.new()
	var ck := CylinderMesh.new()
	ck.top_radius = 0.014
	ck.bottom_radius = 0.014
	ck.height = 0.02
	knot.mesh = ck
	knot.material_override = mat_metal
	knot.position = Vector3(0.0, 0.25, 0.0)
	_root.add_child(knot)

	for mi in [handle, butt, top, knot]:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.layers = 2 # слой вью-модели: фонарь его не засвечивает


func _build_world() -> void:
	_world = Node3D.new()
	_world.top_level = true # дети — в мировых координатах, не в пространстве камеры
	add_child(_world)

	# поплавок: коралловый низ + светлый верх (палитра заката)
	_bobber = Node3D.new()
	_world.add_child(_bobber)
	var mat_lo := StandardMaterial3D.new()
	mat_lo.albedo_color = Color(0.86, 0.46, 0.33)
	mat_lo.roughness = 0.45
	var lo := MeshInstance3D.new()
	var sl := SphereMesh.new()
	sl.radius = 0.145
	sl.height = 0.29
	lo.mesh = sl
	lo.material_override = mat_lo
	_bobber.add_child(lo)
	var mat_hi := StandardMaterial3D.new()
	mat_hi.albedo_color = Color(0.97, 0.91, 0.80)
	mat_hi.roughness = 0.5
	var hi := MeshInstance3D.new()
	var sh := SphereMesh.new()
	sh.radius = 0.099
	sh.height = 0.198
	hi.mesh = sh
	hi.material_override = mat_hi
	hi.position = Vector3(0.0, 0.115, 0.0)
	_bobber.add_child(hi)
	_bobber.visible = false

	# леска — ImmediateMesh, перестраивается каждый кадр
	_line_mi = MeshInstance3D.new()
	_line_mesh = ImmediateMesh.new()
	_line_mi.mesh = _line_mesh
	var lm := StandardMaterial3D.new()
	lm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lm.albedo_color = Color(0.14, 0.11, 0.09)
	_line_mi.material_override = lm
	_line_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_world.add_child(_line_mi)


## Поза: плавный переход «опущена → наготове» и обратно.
func _update_pose(delta: float) -> void:
	var target := 0.0 if stowed else 1.0
	_pose01 = lerpf(_pose01, target, 1.0 - exp(-9.0 * delta))


func _animate_rod(delta: float) -> void:
	_bend = lerpf(_bend, _bend_tgt, 1.0 - exp(-8.0 * delta))
	_tip.rotation.x = _bend

	var k := smoothf01(_pose01)
	var pos: Vector3 = STOW_POS.lerp(GRIP_POS, k)
	var rot: Vector3 = STOW_ROT.lerp(GRIP_ROT, k)
	# дыхание рук
	pos += Vector3(sin(_t * 0.9) * 0.004, sin(_t * 1.3) * 0.005, 0.0) * k
	rot.z += sin(_t * 0.7) * 0.008 * k
	if state == S.CHARGE:
		var p := charge_power()
		pos += Vector3(-0.012, 0.035, 0.09) * p # замах на себя
		rot.x += 0.10 * p
	elif state == S.FIGHT:
		var shake := 0.006 * _tension + (0.004 if _pulling else 0.0)
		pos += Vector3(sin(_t * 37.0), cos(_t * 29.0), 0.0) * shake
	_root.position = pos
	_root.rotation = rot


func _draw_line() -> void:
	_line_mesh.clear_surfaces()
	var show := state in [S.FLY, S.FLOAT, S.BITE, S.FIGHT, S.REEL_IN]
	if not show or _cam == null or not _bobber.visible:
		return
	var tip := _tip.to_global(TIP_LOCAL)
	var end := _bobber.global_position + Vector3.UP * 0.10
	var sag := 0.06
	match state:
		S.FLOAT:
			sag = 0.10 + 0.03 * sin(_t * 1.7)
		S.BITE, S.FIGHT:
			sag = 0.02
			if state == S.FIGHT and _pulling:
				sag += sin(_t * 47.0) * 0.03 # вибрация натянутой лески
		S.REEL_IN:
			sag = 0.04
	var mid := (tip + end) * 0.5 - Vector3.UP * sag
	_line_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for i in range(15):
		_line_mesh.surface_add_vertex(_bez(tip, mid, end, float(i) / 14.0))
	_line_mesh.surface_end()


func smoothf01(t: float) -> float:
	var c := clampf(t, 0.0, 1.0)
	return c * c * (3.0 - 2.0 * c)


# ---------------------------------------------------------------------------
# Для тестов и скриншотов
# ---------------------------------------------------------------------------

func is_pulling() -> bool:
	return _pulling


func bobber_position() -> Vector3:
	return _bobber.global_position


## Ускорить приманивание (скриншоты/автотесты).
func debug_fast_lure() -> void:
	if state == S.FLOAT and not on_land and fish != null:
		if _lure_idx == -1:
			_lure_idx = fish.lure_to(_bobber.global_position)
		fish.debug_snap_to_lure(6.5)
		_bite_t = 0.1
		_relure_t = 0.0
