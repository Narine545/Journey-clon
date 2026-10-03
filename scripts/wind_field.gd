class_name WindField
extends Node3D
## Потоки песка по ветру вокруг путника. Спавн-бокс узла частиц «ездит»
## за игроком, но сами частицы живут в мировых координатах
## (local_coords по умолчанию false): путник проходит сквозь них,
## песок не таскается следом.
## При сёрфе включается плотный поток (gust) — песок летит потоком.


var game
var player: Player

var _ambient: CPUParticles3D
var _gust: CPUParticles3D


func setup(game_ref, player_ref: Player) -> void:
	game = game_ref
	player = player_ref

	var tex := ProcTextures.radial(32, 1.9)

	# лёгкая взвесь — всегда вокруг путника
	_ambient = _make_particles(
		220, 3.4, 0.5, Vector3(30.0, 7.0, 30.0), 6.0, 11.0, 0.06, 0.16,
		tex, Color(1.0, 0.84, 0.62, 0.35)
	)
	add_child(_ambient)

	# плотный поток — только на сёрфе
	_gust = _make_particles(
		260, 1.2, 0.3, Vector3(15.0, 4.0, 15.0), 10.0, 16.0, 0.05, 0.13,
		tex, Color(1.0, 0.90, 0.70, 0.80)
	)
	_gust.emitting = false
	add_child(_gust)


func _physics_process(_delta: float) -> void:
	var p: Vector3 = player.global_position + Vector3(0.0, 1.5, 0.0)
	_ambient.global_position = p
	_gust.global_position = p
	var w: Vector3 = game.wind_dir_3d()
	_ambient.direction = w
	_gust.direction = w
	# Плотный поток — только когда путник сёрфит
	_gust.emitting = game.surf01 > 0.25


func _make_particles(
	amount: int, lifetime: float, life_rand: float,
	box: Vector3, vmin: float, vmax: float, smin: float, smax: float,
	tex: ImageTexture, tint: Color
) -> CPUParticles3D:
	var cp := CPUParticles3D.new()
	cp.amount = amount
	cp.lifetime = lifetime
	cp.lifetime_randomness = life_rand
	cp.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	cp.emission_box_extents = box
	cp.spread = 12.0
	cp.initial_velocity_min = vmin
	cp.initial_velocity_max = vmax
	cp.gravity = Vector3.ZERO
	cp.scale_amount_min = smin
	cp.scale_amount_max = smax
	cp.mesh = _particle_quad(tex, tint)
	# частицы уносятся ветром до ~55 м от узла — не давать их срезать
	cp.visibility_aabb = AABB(Vector3(-70.0, -40.0, -70.0), Vector3(140.0, 80.0, 140.0))
	cp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return cp


func _particle_quad(tex: ImageTexture, tint: Color) -> QuadMesh:
	var quad := QuadMesh.new()
	quad.size = Vector2(1.0, 1.0)
	quad.material = ProcTextures.particle_material(tex, tint)
	return quad
