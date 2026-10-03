class_name Scarf
extends MeshInstance3D
## Лента-шарф путника: верле-цепочка, ведомая ветром и движением игрока.
## Главная «фишка» силуэта — вместе с покачиванием шага оживляет героя.

const SEGMENTS := 13
const SEG_LEN := 0.16
const WIDTH := 0.15

var game
var player: Player

var _points: Array[Vector3] = []
var _prev: Array[Vector3] = []
var _imesh: ImmediateMesh


func setup(game_ref, player_ref: Player) -> void:
	game = game_ref
	player = player_ref

	_points.resize(SEGMENTS)
	_prev.resize(SEGMENTS)
	var anchor := player.neck_pos()
	for i in range(SEGMENTS):
		_points[i] = anchor + Vector3(0.0, 0.0, -float(i)) * SEG_LEN
		_prev[i] = _points[i]

	_imesh = ImmediateMesh.new()
	mesh = _imesh
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/cloth.gdshader")
	mat.set_shader_parameter("sun_dir", Game.SUN_DIR)
	mat.set_shader_parameter("cloth_main", Color(0.58, 0.11, 0.12))
	mat.set_shader_parameter("cloth_lit", Color(1.0, 0.56, 0.36))
	mat.set_shader_parameter("horizon_col", Game.HORIZON_COL)
	mat.set_shader_parameter("sky_col", Game.SKY_COL)
	mat.set_shader_parameter("fog_distance", Game.FOG_DISTANCE)
	mat.set_shader_parameter("tip_glow", 0.22) # лёгкое свечение кончика (задел под энергию)
	material_override = mat


func _physics_process(delta: float) -> void:
	_simulate(delta)
	_build()


func _simulate(delta: float) -> void:
	# якорь — шея путника
	_points[0] = player.neck_pos()

	var wind: Vector3 = game.wind_dir_3d() * game.wind_strength

	for i in range(1, SEGMENTS):
		var p: Vector3 = _points[i]
		var vel := (p - _prev[i]) * 0.94 # трение ткани
		_prev[i] = p

		var t01 := float(i) / float(SEGMENTS - 1)
		# трепет: чем дальше от шеи, тем свободнее
		var flutter: float = sin(game.elapsed * (6.0 + t01 * 5.0) + float(i) * 1.9) * (0.3 + t01)
		var accel: Vector3 = Vector3.DOWN * 3.2 + wind * (2.0 + flutter * 1.4) * (0.25 + t01 * 0.75)
		_points[i] = p + vel + accel * delta * delta

	# жёсткость ленты: держим длину сегментов
	for _pass in range(2):
		for i in range(1, SEGMENTS):
			var a: Vector3 = _points[i - 1]
			var b: Vector3 = _points[i]
			var d := b - a
			var len := d.length()
			if len < 0.0001:
				continue
			var dir := d / len
			var diff := (len - SEG_LEN) * 0.5
			if i == 1:
				_points[i] -= dir * diff * 2.0 # якорь не двигаем
			else:
				_points[i - 1] += dir * diff
				_points[i] -= dir * diff


func _build() -> void:
	_imesh.clear_surfaces()
	_imesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, material_override)

	for i in range(SEGMENTS - 1):
		var a: Vector3 = _points[i]
		var b: Vector3 = _points[i + 1]
		var t0 := float(i) / float(SEGMENTS - 1)
		var t1 := float(i + 1) / float(SEGMENTS - 1)
		var w0 := WIDTH * (1.0 - t0 * 0.8) # лента сужается к кончику
		var w1 := WIDTH * (1.0 - t1 * 0.8)

		var seg := (b - a).normalized()
		var side := Vector3.UP.cross(seg)
		if side.length() < 0.01:
			side = Vector3.RIGHT
		else:
			side = side.normalized()
		var nrm := seg.cross(side).normalized()

		var pa := a + side * w0
		var pb := a - side * w0
		var pc := b + side * w1
		var pd := b - side * w1

		_emit_tri(pa, pb, pc, nrm, t0, t1)
		_emit_tri(pb, pd, pc, nrm, t0, t1)

	_imesh.surface_end()


func _emit_tri(a: Vector3, b: Vector3, c: Vector3, nrm: Vector3, t0: float, t1: float) -> void:
	_imesh.surface_set_normal(nrm)
	_imesh.surface_set_uv(Vector2(t0, 0.0))
	_imesh.surface_add_vertex(a)
	_imesh.surface_set_normal(nrm)
	_imesh.surface_set_uv(Vector2(t1, 1.0))
	_imesh.surface_add_vertex(b)
	_imesh.surface_set_normal(nrm)
	_imesh.surface_set_uv(Vector2(t1, 0.5))
	_imesh.surface_add_vertex(c)
