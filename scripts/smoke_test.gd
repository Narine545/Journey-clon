class_name SmokeTest
extends Node
## Автотест геймплея для headless-прогона (без графики).
## Включается переменной окружения JOURNEY_SMOKE=1; в обычной игре неактивен.
## Прогоняет фазы: покой → печать следа → бег к маяку → скатывание
## с крутой дюны → прыжок/парение. Проверяет, что следы — настоящие:
## песок реально проминается и физика это видит.

var main: Node3D
var phase := 0
var phase_frames := 0
var results: Array[String] = []
var _fail := false
var _peak_speed := 0.0
var _grounded_frames := 0


func setup(main_ref: Node3D) -> void:
	main = main_ref


func _physics_process(_delta: float) -> void:
	phase_frames += 1
	var p: Player = main.player
	var t: Terrain = main.terrain

	match phase:
		0: # покой: мир стабилен, персонаж прижат к песку
			if phase_frames == 1:
				_check_winding(t)
				_check_descent(t)
				_check_stamp(p, t)
			if phase_frames > 30:
				var gh: float = t.ground_height(p.global_position.x, p.global_position.z)
				_check(p.grounded and absf(p.global_position.y - gh) < 0.3, "idle: на земле")
				_next()

		1: # 240 кадров вперёд — путник уходит к маяку
			if phase_frames == 1:
				Input.action_press("move_forward")
			if phase_frames > 240:
				Input.action_release("move_forward")
				var dz: float = Terrain.SPAWN.y - p.global_position.z
				var spd := Vector3(p.vel.x, 0.0, p.vel.z).length()
				_check(dz > 20.0, "run: к маяку dz=%.1f м (ожидалось >20)" % dz)
				_check(spd > 3.0, "run: скорость %.1f м/с" % spd)
				var st: int = main.sand.stamp_count
				_check(st > 12, "run: следов отштамповано %d (ожидалось >12)" % st)
				_check_prints_real(p)
				_next()

		2: # телепорт на сёрф-склон (28–33°), без ввода — песок должен потянуть вниз
			if phase_frames == 1:
				var steep := _find_surf_spot(t)
				p.global_position = Vector3(steep.x, t.ground_height(steep.x, steep.y), steep.y)
				p.vel = Vector3.ZERO
				p.grounded = true
				_peak_speed = 0.0
				_grounded_frames = 0
			if p.grounded:
				_grounded_frames += 1
			_peak_speed = maxf(_peak_speed, p.vel.length())
			if phase_frames > 120:
				_check(_peak_speed > 11.0, "slide: пик разгона по склону %.1f м/с (ожидалось >11)" % _peak_speed)
				_check(_grounded_frames > 96, "slide: на склоне %d из 120 кадров на земле (липнем к дюне)" % _grounded_frames)
				_next()

		3: # прыжок, затем удержание — парение
			if phase_frames == 1:
				Input.action_press("jump")
			elif phase_frames == 15:
				Input.action_release("jump")
			elif phase_frames == 90:
				Input.action_press("jump")
			if phase_frames > 160:
				Input.action_release("jump")
				_check(not p.grounded or p.vel.length() > 0.5, "jump/glide: полёт был")
				_next()

		4:
			_finish()


func _next() -> void:
	phase += 1
	phase_frames = 0


## Ручная печать следа рядом с путником: песок реально продавлен,
## вокруг — вал, и физика (ground_height) это видит.
func _check_stamp(p: Player, t: Terrain) -> void:
	var sand: SandField = main.sand
	var pos := Vector2(p.global_position.x + 1.5, p.global_position.z)
	sand.stamp_foot(pos, Vector2(0.0, -1.0), 0.5, 0.26, 0.05, 0.02)
	var dmin := 0.0
	for k in range(5):
		dmin = minf(dmin, sand.disp_at(pos.x + float(k) * 0.05 - 0.1, pos.y))
	_check(dmin < -0.02, "stamp: дно отпечатка %.3f м (ожидалось < -0.02)" % dmin)
	var dmax := 0.0
	for k in range(8):
		var a := TAU * float(k) / 8.0
		dmax = maxf(dmax, sand.disp_at(pos.x + cos(a) * 0.22, pos.y + sin(a) * 0.22))
	_check(dmax > 0.0, "stamp: вал вокруг отпечатка %.4f м (ожидалось > 0)" % dmax)
	var gh := t.ground_height(pos.x, pos.y)
	var bh := t.sample_height(pos.x, pos.y)
	_check(gh < bh - 0.01, "stamp: физика видит след (ground_height на %.3f ниже дюн)" % (bh - gh))


## После пробежки позади путника должны остаться настоящие промятости.
func _check_prints_real(p: Player) -> void:
	var sand: SandField = main.sand
	var deepest := 0.0
	for k in range(2, 16):
		var zz := p.global_position.z + float(k) * 1.5
		for xo in [-0.4, 0.0, 0.4]:
			deepest = minf(deepest, sand.disp_at(p.global_position.x + xo, zz))
	_check(deepest < -0.008, "run: позади настоящие промятости %.3f м (ожидалось < -0.008)" % deepest)


## Регрессия winding: грань «вверх» у Godot даёт cross(e1,e2).y < 0
## (проверено по PlaneMesh). Иначе песок вывернут и просвечивает насквозь.
func _check_winding(t: Terrain) -> void:
	var arr: Array = t.mesh.surface_get_arrays(0)
	var tv: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var ti: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	var bad := 0
	for k in range(200): # выборочная проверка первых 200 треугольников
		var a: Vector3 = tv[ti[k * 3]]
		var b: Vector3 = tv[ti[k * 3 + 1]]
		var c: Vector3 = tv[ti[k * 3 + 2]]
		var nyz: float = (b - a).cross(c - a).y
		if nyz > 0.0:
			bad += 1
	_check(bad == 0, "winding: вывернутых граней %d из 200 (должно быть 0)" % bad)


## Форма «горнолыжного» спуска: по коридору трейсы средний уклон
## должен быть заметным и держаться длинными участками, а не рябить.
func _check_descent(t: Terrain) -> void:
	var slope_sum := 0.0
	var samples := 0
	var longest := 0
	var run := 0
	for x in [-40.0, 0.0, 40.0]:
		run = 0
		var z := -110.0
		while z >= -400.0:
			var ny: float = t.ground_normal(x, z).y
			var slope := rad_to_deg(acos(clampf(ny, -1.0, 1.0)))
			slope_sum += slope
			samples += 1
			if slope >= 10.0 and t.sample_height(x, z - 4.0) < t.sample_height(x, z):
				run += 4
				longest = maxi(longest, run)
			else:
				run = 0
			z -= 4.0
	var mean := slope_sum / float(samples)
	_check(mean > 8.0, "descent: средний уклон коридора %.1f° (ожидалось >8)" % mean)
	_check(longest >= 60, "descent: длиннейший спуск %d м без остановки (ожидалось ≥60)" % longest)
	print("[SMOKE] коридор спуска: средний уклон ", "%.1f" % mean, "°, длиннейший прогон ", longest, " м")


func _check(ok: bool, what: String) -> void:
	results.append(("PASS " if ok else "FAIL ") + what)
	if not ok:
		_fail = true


func _finish() -> void:
	for line in results:
		print("[SMOKE] ", line)
	print("[SMOKE] итог: ", "ЕСТЬ ПРОВАЛЫ" if _fail else "ВСЁ ПРОШЛО")
	get_tree().quit(1 if _fail else 0)


## Ищет типичный сёрф-склон 28–33° в игровой зоне (не стены и не мелочь).
func _find_surf_spot(t: Terrain) -> Vector2:
	var best := Vector2(0.0, -80.0)
	var best_d := 9.0
	var x := -90.0
	while x <= 90.0:
		var z := -160.0
		while z <= -40.0:
			var ny: float = t.ground_normal(x, z).y
			var d: float = absf(ny - 0.865) # ~30°
			if d < best_d:
				best_d = d
				best = Vector2(x, z)
			z += 10.0
		x += 10.0
	print("[SMOKE] сёрф-склон: ", best, " ny=", t.ground_normal(best.x, best.y).y)
	return best
