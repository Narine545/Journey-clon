class_name FishingNpc
extends Node3D
## Причальный рыбак: импортированный CC0 humanoid rig + бесплатные idle/talk-анимации.
## Даёт короткие рыбацкие контракты и считает улов без отдельного дальнего квест-хаба.

const MODEL_PATH := "res://assets/npc/AnimationLibrary_Godot_Standard.glb"
const STYLE_SHADER_PATH := "res://shaders/npc_sdf_style.gdshader"
const EYE_SHADER_PATH := "res://shaders/npc_eye.gdshader"

const QUESTS := [
	{"title": "Утренний улов", "text": "Поймай любую рыбу × 3", "count": 3},
	{"title": "Трофей у причала", "text": "Поймай крупную рыбу (65 см+) × 1", "count": 1},
	{"title": "Ночной гость", "text": "Ночью поймай любую рыбу × 2", "count": 2},
]

var main: MainScene
var _anim: AnimationPlayer
var _talking := false
var _quest_idx := -1
var _quest_progress := 0
var _interact_action := "npc_interact"
var _quest_actions: Array[String] = ["npc_quest_1", "npc_quest_2", "npc_quest_3"]
var _hint: Label
var _dialogue: PanelContainer
var _dialogue_text: Label
var _progress_text: Label
var _near_player := false
var _style_materials: Array[ShaderMaterial] = []


func setup(main_ref: MainScene, pier: Pier) -> void:
	main = main_ref
	name = "FishingQuestGiver"
	# Shore end of the dock, within a few steps of the starting beach.
	var npc_x := pier.x_start - 1.35
	var npc_z := pier.pz + 0.62
	global_position = Vector3(npc_x, pier.deck_height(npc_x, npc_z) + 0.06, npc_z)
	rotation.y = PI * 0.5 # facing the sea along the pier
	_build_character()
	_build_ui()
	_ensure_actions()


func _build_character() -> void:
	var packed := load(MODEL_PATH) as PackedScene
	if packed == null:
		push_error("Fishing NPC: cannot load CC0 humanoid animation pack")
		return
	var character := packed.instantiate()
	character.name = "CC0Humanoid"
	add_child(character)
	character.scale = Vector3(0.92, 0.92, 0.92)

	var body_mat := _style_material(Color(0.78, 0.43, 0.25))
	var cloth_mat := _style_material(Color(0.13, 0.33, 0.35))
	var skeleton: Skeleton3D
	for node in character.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		for surface in range(mesh_instance.mesh.get_surface_count()):
			mesh_instance.set_surface_override_material(surface,
				body_mat if surface == 0 else cloth_mat)
		if skeleton == null:
			skeleton = _find_skeleton(mesh_instance.get_parent())

	_anim = _find_animation_player(character)
	if _anim != null:
		_anim.animation_finished.connect(_on_animation_finished)
		var idle := _find_animation("Idle_Talking_Loop")
		if idle.is_empty():
			idle = _find_animation("Idle_Loop")
		if not idle.is_empty():
			_anim.play(idle)
	else:
		push_warning("Fishing NPC: imported animation player was not found")

	if skeleton != null:
		_add_eyes(skeleton)
	else:
		push_warning("Fishing NPC: imported humanoid skeleton was not found")


func _style_material(base: Color) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load(STYLE_SHADER_PATH)
	mat.set_shader_parameter("base_color", base)
	mat.set_shader_parameter("night_amount", main.game.night01)
	mat.set_shader_parameter("sun_direction", main.game.sun_dir)
	_style_materials.append(mat)
	return mat


func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node as Skeleton3D
	for child in node.get_children():
		var found := _find_skeleton(child)
		if found != null:
			return found
	return null


func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found != null:
			return found
	return null


func _find_animation(fragment: String) -> String:
	if _anim == null:
		return ""
	for anim_name in _anim.get_animation_list():
		if str(anim_name).ends_with(fragment):
			return str(anim_name)
	return ""


func _add_eyes(skeleton: Skeleton3D) -> void:
	var bone := skeleton.find_bone("DEF-head")
	if bone < 0:
		return
	var anchor := BoneAttachment3D.new()
	anchor.name = "FishWorldEyes"
	anchor.bone_name = "DEF-head"
	skeleton.add_child(anchor)
	var eye_mat := ShaderMaterial.new()
	eye_mat.shader = load(EYE_SHADER_PATH)
	for side in [-1.0, 1.0]:
		var eye := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2(0.082, 0.050)
		eye.mesh = quad
		eye.material_override = eye_mat
		eye.position = Vector3(side * 0.043, 0.010, -0.091)
		eye.rotation.y = PI # local forward is -Z
		anchor.add_child(eye)


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 16
	add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)

	_hint = Label.new()
	_hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_hint.position = Vector2(-150.0, -108.0)
	_hint.size = Vector2(300.0, 36.0)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_font_size_override("font_size", 20)
	_hint.add_theme_color_override("font_color", Color(1.0, 0.84, 0.59))
	_hint.add_theme_color_override("font_shadow_color", Color(0.08, 0.06, 0.05, 0.9))
	_hint.add_theme_constant_override("shadow_offset_x", 2)
	_hint.add_theme_constant_override("shadow_offset_y", 2)
	_hint.visible = false
	root.add_child(_hint)

	_dialogue = PanelContainer.new()
	_dialogue.set_anchors_preset(Control.PRESET_CENTER)
	_dialogue.position = Vector2(-260.0, -165.0)
	_dialogue.size = Vector2(520.0, 330.0)
	_dialogue.visible = false
	_dialogue.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.055, 0.075, 0.09, 0.94)
	panel_style.border_color = Color(0.78, 0.53, 0.31, 0.95)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(10)
	panel_style.set_content_margin_all(22)
	_dialogue.add_theme_stylebox_override("panel", panel_style)
	root.add_child(_dialogue)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	_dialogue.add_child(column)
	var heading := Label.new()
	heading.text = "СТАРЫЙ РЫБАК"
	heading.add_theme_font_size_override("font_size", 23)
	heading.add_theme_color_override("font_color", Color(0.98, 0.72, 0.43))
	column.add_child(heading)
	_dialogue_text = Label.new()
	_dialogue_text.text = "Море сегодня щедрое. Выбери работу — снасть уже у тебя."
	_dialogue_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dialogue_text.add_theme_font_size_override("font_size", 17)
	_dialogue_text.add_theme_color_override("font_color", Color(0.90, 0.91, 0.85))
	column.add_child(_dialogue_text)
	for i in QUESTS.size():
		var choice := Label.new()
		choice.text = "%d   %s — %s" % [i + 1, QUESTS[i].title, QUESTS[i].text]
		choice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		choice.add_theme_font_size_override("font_size", 16)
		choice.add_theme_color_override("font_color", Color(0.82, 0.86, 0.79))
		column.add_child(choice)
	_progress_text = Label.new()
	_progress_text.add_theme_font_size_override("font_size", 16)
	_progress_text.add_theme_color_override("font_color", Color(0.98, 0.80, 0.48))
	column.add_child(_progress_text)
	var close_label := Label.new()
	close_label.text = "E — закрыть"
	close_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	close_label.add_theme_font_size_override("font_size", 14)
	close_label.add_theme_color_override("font_color", Color(0.67, 0.73, 0.72))
	column.add_child(close_label)


func _ensure_actions() -> void:
	_add_key_action(_interact_action, KEY_E)
	for i in _quest_actions.size():
		_add_key_action(_quest_actions[i], KEY_1 + i)


func _add_key_action(action: String, key: Key) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	var event := InputEventKey.new()
	event.physical_keycode = key
	InputMap.action_add_event(action, event)


func _process(_delta: float) -> void:
	if main == null or main.player == null:
		return
	for mat in _style_materials:
		mat.set_shader_parameter("night_amount", main.game.night01)
		mat.set_shader_parameter("sun_direction", main.game.sun_dir)
	var distance := global_position.distance_to(main.player.global_position)
	_near_player = distance < 5.2
	_hint.visible = _near_player and not _dialogue.visible
	if _hint.visible:
		if _quest_idx >= 0:
			var quest: Dictionary = QUESTS[_quest_idx]
			_hint.text = "E  Рыбак · %s (%d/%d)" % [
				quest.title, _quest_progress, int(quest.count)]
		else:
			_hint.text = "E  Поговорить с рыбаком"
	if not _near_player:
		_dialogue.visible = false
		return
	if Input.is_action_just_pressed(_interact_action):
		_dialogue.visible = not _dialogue.visible
		if _dialogue.visible:
			_update_quest_text()
	for i in _quest_actions.size():
		if _dialogue.visible and Input.is_action_just_pressed(_quest_actions[i]):
			_accept_quest(i)


func _accept_quest(index: int) -> void:
	if index < 0 or index >= QUESTS.size():
		return
	_quest_idx = index
	_quest_progress = 0
	_update_quest_text()
	_play_talk()


func _update_quest_text() -> void:
	if _quest_idx < 0:
		_dialogue_text.text = "Море сегодня щедрое. Выбери работу — снасть уже у тебя."
		_progress_text.text = ""
		return
	var quest: Dictionary = QUESTS[_quest_idx]
	if _quest_idx == 1:
		_dialogue_text.text = "Ищи покрупнее. Такой трофей долго помнят у костра."
	elif _quest_idx == 2:
		_dialogue_text.text = "После заката рыба подходит ближе. Возвращайся с двумя."
	else:
		_dialogue_text.text = "Никакой хитрости — просто принеси три рыбы."
	_progress_text.text = "Задание: %s  %d / %d" % [quest.title, _quest_progress, int(quest.count)]


func on_fish_caught(info: Dictionary) -> void:
	if _quest_idx < 0:
		return
	var counts := false
	match _quest_idx:
		0:
			counts = true
		1:
			counts = float(info.get("size_cm", 0.0)) >= 65.0
		2:
			counts = main.game.night01 >= 0.55
	if not counts:
		return
	_quest_progress += 1
	var target := int(QUESTS[_quest_idx].count)
	if _quest_progress >= target:
		_dialogue_text.text = "Вот это улов! Работа выполнена — возвращайся, как захочешь ещё."
		_quest_idx = -1
		_quest_progress = 0
	else:
		_update_quest_text()


func _play_talk() -> void:
	if _anim == null:
		return
	var talk := _find_animation("Interact")
	if talk.is_empty():
		talk = _find_animation("Idle_Talking_Loop")
	if not talk.is_empty():
		_talking = true
		_anim.play(talk)


func _on_animation_finished(_animation_name: StringName) -> void:
	if not _talking or _anim == null:
		return
	_talking = false
	var idle := _find_animation("Idle_Talking_Loop")
	if idle.is_empty():
		idle = _find_animation("Idle_Loop")
	if not idle.is_empty():
		_anim.play(idle)
