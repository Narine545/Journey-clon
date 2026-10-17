class_name ShotTaker
extends Node
## CI-кадры (JOURNEY_SHOT=1): берег, удочка, заброс, поклёвка, вываживание,
## пирс и прыжок песчаного кита. Сценарий ведёт себя как игрок и снимает
## кадр в момент события (а не по номеру кадра — рендер в CI медленный).
##
## Скриншоты кладутся в $SHOT_DIR и коммитятся CI: это единственный способ
## увидеть визуал без локального Godot. SDF-слой существ включается только
## на кадр с прыжком — программный рендер lavapipe не тянет его постоянно.
##
## Условия перехода учитывают и время, и число кадров: в софт-рендере
## один кадр может длиться секунду, а в игре — 16 мс.

var main
var _dir := ""
var _state := 0
var _t := 0.0 # время сценария (сек игрового времени, не стенного)
var _fs := 0
var _caught := 0.0


func setup(main_ref) -> void:
	main = main_ref
	_dir = OS.get_environment("SHOT_DIR")
	if _dir.is_empty():
		_dir = "."
	main.rod.fish_landed.connect(func(sz: float) -> void: _caught = sz)
	main.fish.set_sdf_enabled(false) # экономим программный рендер
	main.cam_rig.set_view(-PI * 0.5 + 0.34, -0.02)
	print("[SHOT] кадры в ", _dir)
	_go(0)


func _go(s: int) -> void:
	_state = s
	_t = 0.0
	_fs = 0


func _process(delta: float) -> void:
	_t += delta
	_fs += 1
	var rod: RodCast = main.rod
	var t := _t
	match _state:
		0: # стартовый вид: берег, пирс, море, удочка в руке
			if t > 0.8 and _fs > 2:
				_capture("shot_a_coast.png")
				Input.action_press("rod_cast")
				_go(1)
		1: # удочка достаётся
			if t > 0.25:
				Input.action_release("rod_cast")
			if t > 0.7 and _fs > 4:
				_capture("shot_b_rod.png")
				Input.action_press("rod_cast") # заряд
				_go(2)
		2:
			if t > 1.0 and _fs > 10:
				_capture("shot_c_charge.png")
				Input.action_release("rod_cast") # заброс
				_go(3)
		3: # ждём, пока поплавок ляжет на воду
			if rod.state == RodCast.S.FLOAT and _fs > 2:
				_capture("shot_d_bobber.png")
				Engine.time_scale = 2.0
				rod.debug_fast_lure()
				_go(4)
			elif t > 10.0:
				_finish("заброс не удался, state=%d" % rod.state)
		4: # ждём поклёвки
			if rod.state == RodCast.S.BITE and _fs > 1:
				_capture("shot_e_bite.png")
				Engine.time_scale = 1.0
				Input.action_press("rod_cast") # подсечка
				_go(5)
			elif t > 40.0:
				_finish("поклёвки не было, state=%d" % rod.state)
		5: # подсекли — вываживаем
			if t > 0.15:
				Input.action_release("rod_cast")
			if rod.state == RodCast.S.FIGHT and t > 0.6 and _fs > 3:
				_capture("shot_f_fight.png")
				_go(6)
			elif t > 3.0:
				_finish("подсечка не удалась, state=%d" % rod.state)
		6: # вываживание: мотаем в затишье
			if rod.is_pulling():
				Input.action_release("rod_cast")
			else:
				Input.action_press("rod_cast")
			if t > 2.0 and _fs > 8:
				_capture("shot_g_reel.png")
				_go(7)
		7:
			if rod.is_pulling():
				Input.action_release("rod_cast")
			else:
				Input.action_press("rod_cast")
			if _caught > 0.0 or rod.state == RodCast.S.RESTING or t > 30.0:
				Input.action_release("rod_cast")
				_go(8)
		8: # пирс: геройский вид с моря на берег
			if t > 0.3 and _fs > 1:
				var pier: Pier = main.pier
				var deck := pier.deck_height(pier.x_end + 2.0, pier.pz)
				main.player.global_position = Vector3(pier.x_end + 2.0, deck, pier.pz)
				main.player.vel = Vector3.ZERO
				main.player.grounded = true
				main.cam_rig.set_view(PI * 0.5, -0.06)
			if t > 0.8 and _fs > 5:
				_capture("shot_h_pier.png")
				_go(9)
		9: # прыжок песчаного кита у пирса (SDF включаем на пару кадров)
			var target := _breach_target()
			main.fish.set_sdf_enabled(true)
			main.fish.debug_breach_near(target)
			if _fs == 2:
				var d: Vector3 = target - main.cam_rig.cam.global_position
				main.cam_rig.set_view(atan2(d.x, d.z), -0.12)
			if t > 0.6 and _fs > 5:
				_capture("shot_i_breach.png")
				main.fish.set_sdf_enabled(false)
				_go(10)
		10:
			if t > 0.1 and _fs > 3:
				_finish("")


func _breach_target() -> Vector3:
	var pier: Pier = main.pier
	return Vector3(pier.x_end + 6.0, Coast.SEA_LEVEL, pier.pz - 10.0)


func _finish(reason: String) -> void:
	if reason != "":
		print("[SHOT] стоп: ", reason)
	_capture("shot_j_final.png")
	print("[SHOT] готово")
	get_tree().quit(0)


func _capture(fname: String) -> void:
	var img := get_viewport().get_texture().get_image()
	if img == null:
		push_warning("SHOT: viewport image недоступен")
		return
	var path := _dir.path_join(fname)
	var err := img.save_png(path)
	print("[SHOT] ", path, " -> ", err)
