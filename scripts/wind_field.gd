class_name WindField
extends Node3D
## Потоки песка по ветру у самой земли. Частицы — вытянутые штрихи,
## ориентированные по скорости (particle_flag_align_y): песок летит
## длинными тёплыми росчерками, как в Journey, а не белыми точками.
## Спавн-бокс узла «ездит» за игроком, но сами частицы живут в мировых
## координатах (local_coords по умолчанию false) — путник проходит
## сквозь них. При сёрфе включается плотный золотой поток.


var game
var player: Player

var _ambient: CPUParticles3D
var _gust: CPUParticles3D


func setup(game_ref, player_ref: Player) -> void:
	game = game_ref
	player = player_ref

	# лёгкая взвесь у земли — всегда, редкая и деликатная
	_ambient = _make_streaks(
		130, 2.6, 0.5, Vector3(26.0, 2.2, 26.0), 7.0, 13.0,
		0.025, 1.7, Color(0.50, 0.35, 0.18, 0.55)
	)
	add_child(_ambient)

	# золотой поток — только на сёрфе: река песка мчится мимо путника
	_gust = _make_streaks(
		220, 1.1, 0.35, Vector3(10.0, 1.6, 10.0), 13.0, 19.0,
		0.03, 2.4, Color(0.85, 0.55, 0.25, 0.50)
	)
	_gust.emitting = false
	add_child(_gust)


func _physics_process(_delta: float) -> void:
	# спавн у самой земли, у ног путника — песок стелется, а не летит в лицо
	var p: Vector3 = player.global_position + Vector3(0.0, 0.55, 0.0)
	_ambient.global_position = p
	_gust.global_position = p + Vector3(0.0, -0.15, 0.0)
	var w: Vector3 = game.wind_dir_3d()
	_ambient.direction = w
	_gust.direction = w
	# Плотный поток — только когда путник сёрфит
	_gust.emitting = game.surf01 > 0.25


func _make_streaks(
	amount: int, lifetime: float, life_rand: float,
	box: Vector3, vmin: float, vmax: float,
	thickness: float, length: float, tint: Color
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
	cp.particle_flag_align_y = true
	cp.scale_amount_min = 0.6
	cp.scale_amount_max = 1.3
	cp.color_ramp = ProcTextures.swell_ramp()
	cp.mesh = _streak_mesh(thickness, length, tint)
	# штрихи уносятся ветром на десятки метров — не давать их срезать
	cp.visibility_aabb = AABB(Vector3(-60.0, -35.0, -60.0), Vector3(120.0, 70.0, 140.0))
	cp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return cp


func _streak_mesh(thickness: float, length: float, tint: Color) -> BoxMesh:
	var mesh := BoxMesh.new()
	# вытянут по Y: align_y повернёт его вдоль скорости
	mesh.size = Vector3(thickness, length, thickness)
	mesh.material = ProcTextures.streak_material(tint)
	return mesh
