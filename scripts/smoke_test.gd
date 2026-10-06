class_name SmokeTest
extends Node
## Автотест геймплея для headless-прогона (без графики).
## Включается переменной окружения JOURNEY_SMOKE=1; в обычной игре неактивен.
## Фазы: покой → печать следа → ходьба в гору → крутая дюна БЕЗ Shift
## (песок держит) и СО Shift (сёрф) → прыжок/парение → СТРЕЛЬБА
## (патроны, кратер в песке, перезарядка, мышь) → занос следов.
## Проверяет, что следы — настоящие: песок реально проминается.

var main: Node3D
var phase := 0
var phase_frames := 0
var results: Array[String] = []
var _fail := false
var _peak_speed := 0.0
var _grounded_frames := 0
var _walk_samples := 0
var _walk_speed_ok := 0
var _max_surf01 := 0.0
var _path: Array[Vector2] = [] # запись пути для проверки следов
var _depth0 := 0.0 # глубина свежего следа для проверки заноса
var _fill_pos := Vector2.ZERO # где штампнули след для проверки заноса
var _yaw0 := 0.0
var _pitch0 := 0.0
var _shoot_frame := 0
var _shots_checked := false


func setup(main_ref: Node3D) -> void:
	main = main_ref
	# головной прогон без графики: главный цикл не должен обгонять физику,
	# иначе --quit-after убьёт игру раньше конца теста
	Engine.max_fps = 60


func _physics_process(_delta: float) -> void:
	phase_frames += 1
	var p: Player = main.player
	var t: Terrain = main.terrain
	var arms: FpsArms = main.arms

	match phase:
		0: # покой: мир стабилен, игрок прижат к песку
			if phase_frames == 1:
				_check_winding(t)
				_check_descent(t)
				_check_stamp(p, t)
			if phase_frames > 30:
				var gh: float = t.ground_height(p.global_position.x, p.global_position.z)
				_check(p.grounded and absf(p.global_position.y - gh) < 0.3, "idle: на земле")
				_next()

		1: # ходьба В ГОРУ от спавна (yaw=0 = +Z, в гору): скорость шага
			# в норме, отпечатки остаются, отпуск — песок останавливает.
			if phase_frames == 1:
				main.cam_rig.set_view(0.0, -0.2)
				Input.action_press("move_forward")
			if phase_frames % 12 == 0 and phase_frames <= 130:
				_path.append(Vector2(p.global_position.x, p.global_position.z))
			if phase_frames % 10 == 0 and phase_frames >= 30 and phase_frames <= 110:
				var spd := Vector3(p.vel.x, 0.0, p.vel.z).length()
				_walk_samples += 1
				if spd < 4.6 and spd >= 0.4:
					_walk_speed_ok += 1
				print("[SMOKE] ходьба: кадр %d pos=(%.1f, %.1f) spd=%.2f" % [
					phase_frames, p.global_position.x, p.global_position.z, spd])
			if phase_frames == 130:
				Input.action_release("move_forward")
			if phase_frames > 260:
				_check(_walk_speed_ok >= _walk_samples - 2,
					"walk: скорость шага в норме %d из %d проверок" % [_walk_speed_ok, _walk_samples])
				_check(p.vel.length() < 1.0, "stop: без ввода остановился (%.2f м/с)" % p.vel.length())
				_check(p.grounded, "stop: на земле")
				_check_prints_real(p)
				_next()

		2: # телепорт на сёрф-склон (28–33°). БЕЗ Shift песок обязан держать
			# намертво — никакого самовольного скольжения; с зажатым Shift —
			# сёрф-разгон по склону.
			if phase_frames == 1:
				var steep := _find_surf_spot(t)
				p.global_position = Vector3(steep.x, t.ground_height(steep.x, steep.y), steep.y)
				p.vel = Vector3.ZERO
				p.grounded = true
				_peak_speed = 0.0
				_grounded_frames = 0
				_max_surf01 = 0.0
			_peak_speed = maxf(_peak_speed, p.vel.length())
			if phase_frames == 90:
				# БЕЗ SHIFT: стоим на крутой дюне — скольжения быть не должно
				_check(_peak_speed < 3.5,
					"slide-off: без Shift не скользит (пик %.1f м/с)" % _peak_speed)
				_check(p.vel.length() < 1.0,
					"slide-off: без Shift остановился (%.2f м/с)" % p.vel.length())
				_check(p.grounded, "slide-off: на земле")
				Input.action_press("slide_mod")
				_peak_speed = 0.0
				_grounded_frames = 0
			elif phase_frames > 90 and p.grounded:
				_grounded_frames += 1
				_max_surf01 = maxf(_max_surf01, p.surf01)
			if phase_frames > 210:
				Input.action_release("slide_mod")
				_check(_peak_speed > 11.0, "slide: пик разгона по склону %.1f м/с (ожидалось >11)" % _peak_speed)
				_check(_grounded_frames > 96, "slide: на склоне %d из 120 кадров на земле (липнем к дюне)" % _grounded_frames)
				_check(_max_surf01 > 0.5, "slide: сёрф-режим активен (surf01 до %.2f)" % _max_surf01)
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

		4: # СТРЕЛЬБА: три выстрела в дюну — патроны тратятся, в песке
			# кратер; перезарядка восстанавливает магазин; мышь вертит взгляд.
			# Тайминги анимаций ассета неизвестны — стреляем по busy().
			if phase_frames == 1:
				# возвращаемся на стартовое плато и целимся в дюну перед собой
				p.global_position = Vector3(
					Terrain.SPAWN.x,
					t.ground_height(Terrain.SPAWN.x, Terrain.SPAWN.y),
					Terrain.SPAWN.y
				)
				p.vel = Vector3.ZERO
				p.grounded = true
				main.cam_rig.set_view(0.0, -1.0)
				_shoot_frame = 0
				_shots_checked = false
				if arms == null:
					_check(false, "shoot: руки не загрузились")
					_next()
			elif arms != null and arms.shots_fired < 3:
				if arms.busy() <= 0.0 and phase_frames - _shoot_frame > 5:
					_shoot_frame = phase_frames
					Input.action_press("shoot")
				if Input.is_action_pressed("shoot") and phase_frames - _shoot_frame >= 2:
					Input.action_release("shoot")
			elif arms != null and not _shots_checked:
				_shots_checked = true
				Input.action_release("shoot")
				_check(arms.ammo == FpsArms.MAG - 3,
					"shoot: патроны потрачены (%d из %d)" % [arms.ammo, FpsArms.MAG])
				_check(arms.shots_fired == 3, "shoot: выстрелов сделано %d" % arms.shots_fired)
				_check(arms.last_hit_valid, "shoot: попадание в песок зафиксировано")
				if arms.last_hit_valid:
					var d: float = main.sand.disp_at(arms.last_hit.x, arms.last_hit.z)
					# диагностика: точка попадания и песок вокруг неё
					var px: float = arms.last_hit.x
					var pz: float = arms.last_hit.z
					var dmin: float = 0.0
					for off in [Vector2(0, 0), Vector2(0.15, 0), Vector2(-0.15, 0), Vector2(0, 0.15), Vector2(0, -0.15)]:
						dmin = minf(dmin, main.sand.disp_at(px + off.x, pz + off.y))
					print("[SMOKE] shoot: hit=(%.2f, %.2f) disp=%.4f (мин. вокруг %.4f), игрок=(%.1f, %.1f)" % [
						px, pz, d, dmin, p.global_position.x, p.global_position.z])
					_check(dmin < -0.002, "shoot: кратер в песке %.3f м (ожидалось < -0.002)" % dmin)
				else:
					_check(false, "shoot: кратер в песке — попадания не было")
			elif arms != null and not Input.is_action_pressed("reload") \
					and arms.current_animation_name() != "Reload" and arms.ammo != FpsArms.MAG:
				# перезарядка ещё не принята (руки могли быть заняты выстрелом):
				# циклим нажатие, пока AnimationPlayer не возьмёт Reload
				if phase_frames % 4 == 0:
					Input.action_press("reload")
				elif phase_frames % 4 == 2:
					Input.action_release("reload")
			elif arms != null and (arms.busy() > 0.0 or arms.ammo != FpsArms.MAG):
				# перезарядка идёт (анимация может быть длинной)
				Input.action_release("reload")
				if phase_frames > 800:
					_check(false, "reload: перезарядка не завершилась (ammo=%d)" % arms.ammo)
					_next()
			elif arms != null:
				Input.action_release("reload")
				_check(arms.ammo == FpsArms.MAG,
					"reload: магазин полон (%d из %d)" % [arms.ammo, FpsArms.MAG])
				# мышь: apply_mouse_motion — тот же путь, что и настоящий ввод
				_yaw0 = main.cam_rig.yaw
				_pitch0 = main.cam_rig.pitch
				main.cam_rig.apply_mouse_motion(Vector2(220.0, -130.0))
				var dy: float = absf(main.cam_rig.yaw - _yaw0)
				var dp: float = main.cam_rig.pitch - _pitch0
				_check(dy > 0.2, "mouse: yaw слушается мыши (Δ%.2f рад)" % dy)
				_check(dp > 0.1, "mouse: pitch слушается мыши (Δ%.2f рад)" % dp)
				_next()

		5: # занос: свежий след должен затягиваться песком за ~15 секунд
			# игрок закреплён на месте (тест!), точка штампа — фиксированная
			p.vel = Vector3.ZERO
			if phase_frames == 1:
				# возвращаемся на стартовое плато и замираем
				p.global_position = Vector3(
					Terrain.SPAWN.x,
					t.ground_height(Terrain.SPAWN.x, Terrain.SPAWN.y - 4.0),
					Terrain.SPAWN.y - 4.0
				)
				p.grounded = true
			if phase_frames == 3:
				# кадр ждём: окно песка переезжает к игроку только в _process
				_fill_pos = Vector2(p.global_position.x + 1.2, p.global_position.z + 1.2)
				main.sand.stamp_foot(_fill_pos, Vector2(0.0, -1.0), 0.5, 0.26, 0.05, 0.02)
				for k in range(6):
					_depth0 = minf(_depth0, main.sand.disp_at(_fill_pos.x + float(k) * 0.06 - 0.15, _fill_pos.y))
				print("[SMOKE] занос: свежий след %.3f м" % _depth0)
			if phase_frames == 783: # ~13 с
				var d1 := 0.0
				for k in range(6):
					d1 = minf(d1, main.sand.disp_at(_fill_pos.x + float(k) * 0.06 - 0.15, _fill_pos.y))
				var pct := 100.0 * d1 / _depth0 if _depth0 < -0.001 else 999.0
				print("[SMOKE] занос: через 13 с %.3f м (%.0f%% глубины)" % [d1, pct])
				_check(d1 > _depth0 * 0.75 and d1 < -0.002, "занос: след затягивается, но не мгновенно (осталось %.0f%%)" % pct)
			if phase_frames > 805:
				_next()

		6:
			_finish()


func _next() -> void:
	phase += 1
	phase_frames = 0


## Ручная печать следа рядом с игроком: песок реально продавлен,
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


## После пробежки позади игрока должны остаться настоящие промятости.
## Проверяем вдоль ЗАПИСАННОГО пути (рельеф увывает бег в стороны).
func _check_prints_real(p: Player) -> void:
	var sand: SandField = main.sand
	var deepest := 0.0
	var n_path := _path.size()
	for k in range(2, maxi(3, n_path - 8)): # свежий хвост пропускаем
		var pt: Vector2 = _path[k]
		for off in [Vector2(0, 0), Vector2(0.3, 0), Vector2(-0.3, 0), Vector2(0, 0.3), Vector2(0, -0.3)]:
			deepest = minf(deepest, sand.disp_at(pt.x + off.x, pt.y + off.y))
	_check(deepest < -0.008, "run: промятости вдоль пути %.3f м (ожидалось < -0.008)" % deepest)

	# диагностика: самое глубокое место в квадрате 36×36 м вокруг игрока
	var cx := p.global_position.x
	var cz := p.global_position.z
	var dmin := 0.0
	var gx := cx - 18.0
	while gx <= cx + 18.0:
		var gz := cz - 18.0
		while gz <= cz + 18.0:
			dmin = minf(dmin, sand.disp_at(gx, gz))
			gz += 0.5
		gx += 0.5
	print("[SMOKE] диагностика: глубочайшая промятость в зоне ±18 м: ", "%.3f" % dmin)


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
