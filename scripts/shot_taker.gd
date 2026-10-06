class_name ShotTaker
extends Node
## Служебный скрипт для CI-рендера (JOURNEY_SHOT=1): прогоняет игрока
## вперёд и снимает скриншоты — ходьба с руками, выстрел со вспышкой,
## сёрф, луч фонаря в тумане, огонёк маяка, следы сверху.
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
	# первый отрезок — В ГОРКУ от спавна: чистая ходьба, руки в кадре.
	if main.cam_rig != null:
		main.cam_rig.set_view(0.0, -0.12)
	Input.action_press("move_forward")


func _physics_process(_delta: float) -> void:
	_frames += 1
	match _frames:
		150:
			_capture("shot_a_walk.png") # ходьба в гору: руки, дюны, туман
		168:
			Input.action_press("shoot")
		169:
			Input.action_release("shoot")
		171:
			_capture("shot_b_shoot.png") # вспышка выстрела в тумане
		200:
			Input.action_release("move_forward")
		220:
			# разворот к «маяку» и спуск: сёрф — только осознанный (Shift)
			if main.cam_rig != null:
				main.cam_rig.set_view(PI, -0.12)
			Input.action_press("move_forward")
			Input.action_press("slide_mod")
		268:
			_capture("shot_c_surf.png") # сёрф: FOV, борозда, туман
		300:
			Input.action_release("move_forward")
			Input.action_release("slide_mod")
		310:
			if main.cam_rig != null:
				main.cam_rig.set_view(PI, -0.55) # взгляд вниз по склону
		330:
			_capture("shot_d_flash.png") # луч фонарика в волюметрическом тумане
		360:
			if main.cam_rig != null:
				main.cam_rig.set_view(PI, 0.06) # взгляд вдоль коридора
		385:
			_capture("shot_e_beacon.png") # огонёк маяка сквозь туман
		430:
			_top_camera() # камера над тропой, взгляд на следы
		465:
			_capture("shot_f_trail.png") # следы сверху (шаги + борозда + кратеры)
		490:
			get_tree().quit(0)


func _capture(fname: String) -> void:
	var img := get_viewport().get_texture().get_image()
	if img == null:
		push_warning("SHOT: viewport image недоступен")
		return
	var path := _shot_dir.path_join(fname)
	var err := img.save_png(path)
	print("[SHOT] ", path, " -> ", err)


## Камера позади и выше игрока, смотрит на тропу следов за спиной.
func _top_camera() -> void:
	var p: Player = main.player
	var fwd := Vector3(sin(main.cam_rig.yaw), 0.0, cos(main.cam_rig.yaw))
	var pos: Vector3 = p.global_position - fwd * 11.0 + Vector3.UP * 8.0
	var look: Vector3 = p.global_position - fwd * 3.0
	var cam := Camera3D.new()
	main.add_child(cam)
	cam.global_position = pos
	cam.look_at(look, Vector3.UP)
	cam.fov = 70.0
	cam.far = 1800.0
	cam.near = 0.02
	cam.make_current()
