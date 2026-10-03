extends Node3D
## Точка входа. Этап 0 (каркас): небо, солнце, маяк на горизонте, камера.
## Вся сцена собирается программно, чтобы ошибки всплывали при запуске.

var _cam: Camera3D
var _t := 0.0


func _ready() -> void:
	var game := get_node("/root/Game")

	var world := GameWorld.new()
	add_child(world)
	world.setup(game)

	_cam = Camera3D.new()
	add_child(_cam)
	_cam.fov = 75.0
	# Взгляд с высоты дюны на столб света — задел композиции первого кадра.
	_cam.global_position = Vector3(2.0, 18.0, 46.0)
	_cam.look_at(Vector3(0.0, 30.0, -640.0), Vector3.UP)


func _process(delta: float) -> void:
	# Медленный дрейф камеры: картинка живёт даже без геймплея.
	_t += delta
	_cam.global_position = Vector3(
		2.0 + sin(_t * 0.11) * 3.0,
		18.0 + sin(_t * 0.07) * 1.5,
		46.0 + cos(_t * 0.09) * 3.0
	)
	_cam.look_at(Vector3(0.0, 30.0, -640.0), Vector3.UP)
