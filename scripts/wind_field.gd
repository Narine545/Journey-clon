class_name WindField
extends Node3D
## Потоки песка по ветру: живые ленты, стелющиеся по рельефу дюн.
## Каждая песчинка пишет след своей недавней траектории (история позиций
## у самой земли), из следов собирается общий меш: ленты изгибаются
## по пути и по рельефу, ширина и яркость растут к «голове» и гаснут
## к хвосту. Частицы Godot так не умеют — рельеф и геометрию считаем сами.
## При сёрфе проявляется плотный золотой поток вдоль трейсы.


const AMBIENT_N := 0 # амбиентные ленты убраны по фидбеку — остался поток на сёрфе
const GUST_N := 104
const HIST := 8 # точек истории на ленту (7 сегментов)
const HIST_DT := 0.055 # шаг записи истории, сек
const SPAWN_R := 26.0
const KILL_R := 34.0

var game
var player: Player
var terrain: Terrain

var _ambient: Array[Wisp] = []
var _gust: Array[Wisp] = []
var _amb_mi: MeshInstance3D
var _gust_mi: MeshInstance3D
var _parity := 0


class Wisp:
	extends RefCounted
	## Одна песчинка со шлейфом: позиция, фаза жизни, лента-история.

	var x := 0.0
	var z := 0.0
	var life := 0.0
	var max_life := 2.0
	var phase := 0.0
	var freq := 1.0
	var hover := 0.3
	var speed := 8.0
	var lat := 0.5 # амплитуда бокового изгиба (м/с)
	var width := 0.14
	var alpha := 0.5
	var hist: Array[Vector3] = [] # позиции: старые -> новые
	var hist_t := 0.0


func setup(game_ref, player_ref: Player, terrain_ref: Terrain) -> void:
	game = game_ref
	player = player_ref
	terrain = terrain_ref

	_amb_mi = _make_mi(Color(0.62, 0.44, 0.24, 0.40))
	_gust_mi = _make_mi(Color(0.90, 0.60, 0.28, 0.55))
	add_child(_amb_mi)
	add_child(_gust_mi)

	# первый запуск: заполняем поле вокруг путника со случайной фазой жизни
	for _i in range(AMBIENT_N):
		_ambient.append(_spawn(false, true))
	for _i in range(GUST_N):
		_gust.append(_spawn(true, true))


func _physics_process(delta: float) -> void:
	_step_set(_ambient, false, delta)
	_step_set(_gust, true, delta)
	# геометрию лент пересобираем каждый второй кадр (30 Гц — достаточно:
	# ленты и так смазаны движением)
	_parity = 1 - _parity
	if _parity == 0:
		_amb_mi.mesh = _build_ribbons(_ambient, 1.0)
		_gust_mi.mesh = _build_ribbons(_gust, smoothstep(0.15, 0.55, game.surf01))


func _step_set(wisps: Array[Wisp], gusty: bool, delta: float) -> void:
	var wdir: Vector2 = game.wind_dir()
	var perp := Vector2(-wdir.y, wdir.x)
	var px: float = player.global_position.x
	var pz: float = player.global_position.z
	var t: float = game.elapsed

	for i in range(wisps.size()):
		var w: Wisp = wisps[i]
		w.life += delta
		var dx: float = w.x - px
		var dz: float = w.z - pz
		if w.life >= w.max_life or dx * dx + dz * dz > KILL_R * KILL_R:
			wisps[i] = _spawn(gusty, false)
			w = wisps[i]

		# движение: по ветру с боковым изгибом — ленты вьются, а не прямые
		var wiggle: float = cos(w.phase + t * w.freq) * w.lat
		w.x += (wdir.x * w.speed + perp.x * wiggle) * delta
		w.z += (wdir.y * w.speed + perp.y * wiggle) * delta

		# запись следа у самой поверхности дюны (вместе с промятостями песка)
		w.hist_t += delta
		if w.hist_t >= HIST_DT:
			w.hist_t -= HIST_DT
			w.hist.push_back(Vector3(w.x, terrain.ground_height(w.x, w.z) + w.hover, w.z))
			if w.hist.size() > HIST:
				w.hist.pop_front()


func _build_ribbons(wisps: Array[Wisp], vis: float) -> ArrayMesh:
	var n := wisps.size()
	var verts := PackedVector3Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	verts.resize(n * HIST * 2)
	cols.resize(n * HIST * 2)
	idx.resize(n * (HIST - 1) * 6)
	var vi := 0
	var ii := 0
	var side := Vector3.RIGHT
	var prev_ok := false

	for w in wisps:
		var m: int = w.hist.size()
		if m < 2:
			continue
		var k: float = sin(PI * clampf(w.life / w.max_life, 0.0, 1.0))
		prev_ok = false
		for j in range(m):
			var p: Vector3 = w.hist[j]
			# боковое направление ленты: перпендикуляр к пути, горизонтально
			var jn: int = mini(j + 1, m - 1)
			var jp: int = maxi(j - 1, 0)
			var dir: Vector3 = w.hist[jn] - w.hist[jp]
			if dir.length_squared() > 0.0001:
				var s: Vector3 = Vector3.UP.cross(dir)
				if s.length_squared() > 0.0001:
					side = s.normalized()
			# к голове лента шире и ярче, к хвосту — шильтик и тает
			var tt := float(j) / float(m - 1)
			var wid: float = w.width * lerpf(0.12, 1.0, tt)
			var a: float = w.alpha * k * pow(tt, 1.4) * vis
			verts[vi] = p + side * wid
			cols[vi] = Color(1.0, 1.0, 1.0, a)
			verts[vi + 1] = p - side * wid
			cols[vi + 1] = Color(1.0, 1.0, 1.0, a)
			vi += 2
			if prev_ok:
				# два треугольника на сегмент
				var a0: int = vi - 4
				var b0: int = vi - 3
				var c0: int = vi - 2
				var d0: int = vi - 1
				idx[ii] = a0
				idx[ii + 1] = b0
				idx[ii + 2] = c0
				idx[ii + 3] = b0
				idx[ii + 4] = d0
				idx[ii + 5] = c0
				ii += 6
			prev_ok = true
		# разрыв ленты между песчинками (не склеиваем соседние)
		prev_ok = false

	# обрезаем неиспользованное (могут быть короткие истории)
	verts.resize(vi)
	cols.resize(vi)
	idx.resize(ii)

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	if idx.size() > 0:
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _spawn(gusty: bool, anywhere: bool) -> Wisp:
	var w := Wisp.new()
	var wdir: Vector2 = game.wind_dir()
	var px: float = player.global_position.x
	var pz: float = player.global_position.z

	if anywhere:
		var a := randf() * TAU
		var r := lerpf(4.0, SPAWN_R, randf())
		w.x = px + cos(a) * r
		w.z = pz + sin(a) * r
	else:
		# с наветренной стороны: лента проносится мимо путника
		var r := lerpf(4.0, SPAWN_R * 0.85, randf())
		var side: float = randf() * 18.0 - 9.0
		var perp := Vector2(-wdir.y, wdir.x)
		w.x = px - wdir.x * r + perp.x * side
		w.z = pz - wdir.y * r + perp.y * side

	if gusty:
		w.max_life = lerpf(0.9, 1.5, randf())
		w.speed = lerpf(13.0, 19.0, randf())
		w.hover = lerpf(0.05, 0.45, randf())
		w.width = lerpf(0.16, 0.30, randf())
		w.alpha = 0.55
		w.lat = lerpf(0.2, 0.7, randf())
	else:
		w.max_life = lerpf(1.8, 3.4, randf())
		w.speed = lerpf(6.0, 12.0, randf())
		w.hover = lerpf(0.12, 0.75, randf())
		w.width = lerpf(0.08, 0.18, randf())
		w.alpha = 0.45
		w.lat = lerpf(0.4, 1.0, randf())
	w.phase = randf() * TAU
	w.freq = lerpf(0.6, 1.4, randf())
	w.life = randf() * w.max_life * 0.8 if anywhere else 0.0

	# предыстория: лента уже «жила» до появления — прямая по ветру
	var back := Vector3(-wdir.x, 0.0, -wdir.y)
	for j in range(HIST):
		var dt: float = float(HIST - 1 - j) * HIST_DT
		var hx: float = w.x + back.x * w.speed * dt
		var hz: float = w.z + back.z * w.speed * dt
		w.hist.push_back(Vector3(hx, terrain.sample_height(hx, hz) + w.hover, hz))
	return w


func _make_mi(tint: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.material_override = ProcTextures.streak_material(tint)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi
