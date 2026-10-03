class_name SmokeTest
extends Node
## Автотест геймплея для headless-прогона (без графики).
## Включается переменной окружения JOURNEY_SMOKE=1; в обычной игре неактивен.
## Прогоняет фазы: покой → бег к маяку → скатывание с крутой дюны → прыжок/парение.

var main: Node3D
var phase := 0
var phase_frames := 0
var results: Array[String] = []
var _fail := false
var _peak_speed := 0.0


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
			if phase_frames > 30:
				var gh: float = t.sample_height(p.global_position.x, p.global_position.z)
				_check(p.grounded and absf(p.global_position.y - gh) < 0.3, "idle: на земле")
				_next()

		1: # 240 кадров вперёд — путник уходит к маяку
			if phase_frames == 1:
				Input.action_press("move_forward")
			if phase_frames > 240:
				Input.action_release("move_forward")
				var dz: float = Terrain.SPAWN.y - p.global_position.z
				var spd := Vector3(p.vel.x, 0.0, p.vel.z).length()
				_check(dz > 25.0, "run: к маяку dz=%.1f м (ожидалось >25)" % dz)
				_check(spd > 3.0, "run: скорость %.1f м/с" % spd)
				var st: int = main.trail.stamp_count
				_check(st > 20, "run: следов отштамповано %d (ожидалось >20)" % st)
				_next()

		2: # телепорт на крутой склон, без ввода — песок должен потянуть вниз
			if phase_frames == 1:
				var steep := _find_steep_spot(t)
				p.global_position = Vector3(steep.x, t.sample_height(steep.x, steep.y), steep.y)
				p.vel = Vector3.ZERO
				p.grounded = true
				_peak_speed = 0.0
			_peak_speed = maxf(_peak_speed, p.vel.length())
			if phase_frames > 120:
				_check(_peak_speed > 7.0, "slide: пик разгона по склону %.1f м/с (ожидалось >7)" % _peak_speed)
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


func _check(ok: bool, what: String) -> void:
	results.append(("PASS " if ok else "FAIL ") + what)
	if not ok:
		_fail = true


func _finish() -> void:
	for line in results:
		print("[SMOKE] ", line)
	print("[SMOKE] итог: ", "ЕСТЬ ПРОВАЛЫ" if _fail else "ВСЁ ПРОШЛО")
	get_tree().quit(1 if _fail else 0)


## Ищет самый крутой участок дюн в игровой зоне.
func _find_steep_spot(t: Terrain) -> Vector2:
	var best := Vector2(0.0, -80.0)
	var best_ny := 1.0
	var x := -90.0
	while x <= 90.0:
		var z := -160.0
		while z <= -40.0:
			var ny: float = t.ground_normal(x, z).y
			if ny < best_ny:
				best_ny = ny
				best = Vector2(x, z)
			z += 10.0
		x += 10.0
	print("[SMOKE] крутой склон: ", best, " ny=", best_ny)
	return best
