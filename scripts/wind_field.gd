class_name WindField
extends Node3D
## Ветровые штрихи песка, стелющиеся по рельефу дюн. Своя система на
## MultiMesh: каждый штрих каждый кадр прижимается к поверхности
## (частицы Godot не умеют читать рельеф). Штрихи изогнуты боковым
## синусом и наклонены по склону — песок «обтекает» дюны, а не летит
## прямыми линиями сквозь них.
## Рождаются с наветренной стороны путника и проносятся мимо:
## при сёрфе включается плотный золотой поток.


const AMBIENT_N := 110
const GUST_N := 170
const SPAWN_R := 26.0 # радиус жизни вокруг путника
const KILL_R := 36.0

var game
var player: Player
var terrain: Terrain

var _ambient: Array[Wisp] = []
var _gust: Array[Wisp] = []
var _amm: MultiMesh
var _gmm: MultiMesh


class Wisp:
	extends RefCounted
	## Один штрих: позиция, фаза жизни, параметры движения.

	var x := 0.0
	var z := 0.0
	var life := 0.0
	var max_life := 2.0
	var phase := 0.0
	var freq := 1.0
	var hover := 0.3
	var speed := 8.0
	var lat := 0.5 # амплитуда бокового изгиба (м/с)
	var length := 1.5
	var dir := Vector3(1.0, 0.0, 0.0) # вдоль склона


func setup(game_ref, player_ref: Player, terrain_ref: Terrain) -> void:
	game = game_ref
	player = player_ref
	terrain = terrain_ref

	_amm = _make_mm(AMBIENT_N, 0.028, Color(0.55, 0.38, 0.20, 0.50))
	_gmm = _make_mm(GUST_N, 0.034, Color(0.85, 0.55, 0.25, 0.55))

	var ammi := MultiMeshInstance3D.new()
	ammi.multimesh = _amm
	ammi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ammi)

	var gmmi := MultiMeshInstance3D.new()
	gmmi.multimesh = _gmm
	gmmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(gmmi)

	# первый запуск: заполняем поле вокруг путника со случайной фазой жизни
	for _i in range(AMBIENT_N):
		_ambient.append(_spawn(false, true))
	for _i in range(GUST_N):
		_gust.append(_spawn(true, true))


func _physics_process(delta: float) -> void:
	# поток проявляется плавно вместе с сёрфом
	_update_set(_ambient, _amm, false, delta, 1.0)
	_update_set(_gust, _gmm, true, delta, smoothstep(0.15, 0.55, game.surf01))


func _update_set(wisps: Array[Wisp], mm: MultiMesh, gusty: bool, delta: float, vis: float) -> void:
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
			if vis <= 0.01:
				# поток скрыт — штрих живёт «вхолостую», не рисуем
				mm.set_instance_color(i, Color(1.0, 1.0, 1.0, 0.0))
				continue

		# движение: по ветру с боковым изгибом — штрихи не прямые
		var wiggle: float = cos(w.phase + t * w.freq) * w.lat
		var vx: float = wdir.x * w.speed + perp.x * wiggle
		var vz: float = wdir.y * w.speed + perp.y * wiggle
		w.x += vx * delta
		w.z += vz * delta

		# прижимаем к дюне: высота — поверхность + парение
		var y: float = terrain.sample_height(w.x, w.z) + w.hover

		# жизнь: мягко разгорается и тает
		var k: float = sin(PI * clampf(w.life / w.max_life, 0.0, 1.0))
		if k <= 0.02 or vis <= 0.01:
			mm.set_instance_color(i, Color(1.0, 1.0, 1.0, 0.0))
			continue

		# ориентация: Y меша вдоль направления склона
		var x_ax := Vector3.UP.cross(w.dir)
		if x_ax.length_squared() < 0.001:
			x_ax = Vector3.RIGHT
		else:
			x_ax = x_ax.normalized()
		var z_ax := x_ax.cross(w.dir)
		var thick: float = 0.5 + 0.5 * k
		var bb := Basis(x_ax * thick, w.dir * (w.length * (0.35 + 0.65 * k)), z_ax * thick)
		mm.set_instance_transform(i, Transform3D(bb, Vector3(w.x, y, w.z)))
		mm.set_instance_color(i, Color(1.0, 1.0, 1.0, k * vis))


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
		# с наветренной стороны: штрих пролетает мимо путника
		var r := lerpf(4.0, SPAWN_R * 0.85, randf())
		var side: float = randf() * 18.0 - 9.0
		var perp := Vector2(-wdir.y, wdir.x)
		w.x = px - wdir.x * r + perp.x * side
		w.z = pz - wdir.y * r + perp.y * side

	if gusty:
		w.max_life = lerpf(0.8, 1.4, randf())
		w.speed = lerpf(13.0, 19.0, randf())
		w.hover = lerpf(0.05, 0.45, randf())
		w.length = lerpf(2.2, 3.2, randf())
		w.lat = lerpf(0.1, 0.5, randf())
	else:
		w.max_life = lerpf(1.8, 3.4, randf())
		w.speed = lerpf(6.0, 12.0, randf())
		w.hover = lerpf(0.12, 0.75, randf())
		w.length = lerpf(1.2, 2.0, randf())
		w.lat = lerpf(0.4, 0.9, randf())
	w.phase = randf() * TAU
	w.freq = lerpf(0.6, 1.4, randf())
	w.life = randf() * w.max_life * 0.8 if anywhere else 0.0

	# направление штриха — ветер, положенный на плоскость склона
	var wd := Vector3(wdir.x, 0.0, wdir.y)
	var n := terrain.ground_normal(w.x, w.z)
	w.dir = (wd - n * wd.dot(n)).normalized()
	return w


func _make_mm(count: int, thickness: float, tint: Color) -> MultiMesh:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(thickness, 1.0, thickness)
	mesh.material = ProcTextures.streak_material(tint)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = count
	return mm
