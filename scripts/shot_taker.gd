class_name ShotTaker
extends Node
## Служебный скрипт для CI-рендера (JOURNEY_SHOT=1): прогоняет путника
## вперёд и снимает скриншоты — обычный вид, вид сверху на следы.
## Скриншоты кладутся в $SHOT_DIR и коммитятся CI — можно проверять
## визуал без локального Godot.

var main
var _frames := 0
var _shot_dir := ""


func setup(main_ref) -> void:
	main = main_ref
	_shot_dir = OS.get_environment("SHOT_DIR")
	if _shot_dir.is_empty():
		_shot_dir = "."
	Input.action_press("move_forward")


func _physics_process(_delta: float) -> void:
	_frames += 1
	match _frames:
		150:
			_capture("shot_a_run.png") # игровой вид: бег к маяку (солнце в кадре)
		200:
			_look_back_camera() # взгляд НАЗАД, от солнца — теневая сторона дюн
		230:
			_capture("shot_d_back.png") # блёстки должны жить и здесь
		245:
			_side_camera() # взгляд Сбоку, поперёк пути
		275:
			_capture("shot_e_side.png") # и здесь тоже
		285:
			_game_camera() # вернуть игровую камеру
		375:
			_capture("shot_b_run2.png") # ещё игровой вид позднее
		385:
			_top_camera() # камера над тропой, взгляд на следы
		415:
			_capture("shot_c_trail.png") # следы сверху
		425:
			Input.action_release("move_forward")
			get_tree().quit(0)


func _capture(fname: String) -> void:
	var img := get_viewport().get_texture().get_image()
	if img == null:
		push_warning("SHOT: viewport image недоступен")
		return
	var path := _shot_dir.path_join(fname)
	var err := img.save_png(path)
	print("[SHOT] ", path, " -> ", err)


## Камера впереди путника, взгляд назад (от солнца): так проверяем,
## что блёстки не зависят от направления на солнце.
func _look_back_camera() -> void:
	var p: Player = main.player
	var fwd := Vector3(sin(p.heading), 0.0, cos(p.heading))
	var cam := Camera3D.new()
	main.add_child(cam)
	cam.global_position = p.global_position - fwd * 9.0 + Vector3.UP * 3.2
	cam.look_at(p.global_position + fwd * 8.0 + Vector3.UP * 1.2, Vector3.UP)
	cam.fov = 74.0
	cam.far = 1400.0
	cam.make_current()


## Камера сбоку от путника, взгляд поперёк пути.
func _side_camera() -> void:
	var p: Player = main.player
	var fwd := Vector3(sin(p.heading), 0.0, cos(p.heading))
	var right := Vector3(fwd.z, 0.0, -fwd.x)
	var cam := Camera3D.new()
	main.add_child(cam)
	cam.global_position = p.global_position + right * 9.0 + Vector3.UP * 3.0
	cam.look_at(p.global_position - right * 6.0 + Vector3.UP * 1.0, Vector3.UP)
	cam.fov = 74.0
	cam.far = 1400.0
	cam.make_current()


## Вернуть игровую камеру рига.
func _game_camera() -> void:
	if main.cam_rig != null and main.cam_rig.cam != null:
		main.cam_rig.cam.make_current()


## Камера позади и выше путника, смотрит на тропу следов за спиной.
func _top_camera() -> void:
	var p: Player = main.player
	var fwd := Vector3(sin(p.heading), 0.0, cos(p.heading))
	var pos: Vector3 = p.global_position - fwd * 11.0 + Vector3.UP * 8.0
	var look: Vector3 = p.global_position - fwd * 3.0
	var cam := Camera3D.new()
	main.add_child(cam)
	cam.global_position = pos
	cam.look_at(look, Vector3.UP)
	cam.fov = 70.0
	cam.far = 1400.0
	cam.make_current()
