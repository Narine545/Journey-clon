class_name VillageResident
extends Node3D
## Житель посёлка: тот же CC0 humanoid-риг Quaternius, что у рыбака в
## старой рыбалке, но переодетый под «Тихую бухту».
##
## У каждого человека свой цвет пальто и платка, своя шапка и свой предмет
## в руках: сеть, фонарь, поднос, ведро, молоток, книга, подзорная труба,
## колокольная верёвка. Он стоит там, где дом выходит на улицу, — не в
## центре двора, а у крыльца, как настоящий хозяин.
##
## Анимация — Idle_Loop из бесплатного набора; шаг вперёд/назад не нужен,
## потому что посёлок пока «живая декорация у причала», а не ходьба по
## улицам. Зато дыхание, поворот головы и свет фонаря дают жизнь без
## навигации и без риска, что житель застрянет в стене.

const MODEL_PATH := "res://assets/npc/AnimationLibrary_Godot_Standard.glb"
const STYLE_SHADER_PATH := "res://shaders/npc_sdf_style.gdshader"

var main: BoatMain
var person_id := "netmaker"
var person := {}
var _anim: AnimationPlayer
var _character: Node3D
var _skeleton: Skeleton3D
var _name_label: Label3D
var _style_materials: Array[ShaderMaterial] = []
var _lantern_light: OmniLight3D
var _prop: Node3D
var _time := 0.0
var _phase := 0.0


func setup(owner_main: BoatMain, id: String, at: Vector3, facing: Vector3) -> void:
	main = owner_main
	person_id = id
	person = VillagePeople.get_person(id)
	name = "Resident_" + id
	global_position = at
	_phase = float(hash(id) % 1000) * 0.01
	_build_character()
	if facing.length_squared() > 0.001:
		look_at(at + Vector3(facing.x, 0.0, facing.z), Vector3.UP)


func spoke() -> void:
	# Короткий жест: голова вскинулась, руки пошли. Клип Interact есть в
	# наборе, но он длинный; для разговора достаточно ускорить Idle на миг.
	if _anim == null:
		return
	var current := _anim.current_animation
	if current.is_empty():
		return
	_anim.speed_scale = 1.55
	var tween := create_tween()
	tween.tween_interval(0.9)
	tween.tween_callback(func() -> void:
		if _anim != null:
			_anim.speed_scale = 0.85)


func set_named(on: bool) -> void:
	if _name_label != null:
		_name_label.visible = on


func _build_character() -> void:
	var packed := load(MODEL_PATH) as PackedScene
	if packed == null:
		push_warning("VillageResident: cannot load humanoid pack")
		_build_fallback()
		return
	_character = packed.instantiate() as Node3D
	if _character == null:
		_build_fallback()
		return
	_character.name = "Humanoid"
	add_child(_character)
	_character.scale = Vector3(0.94, 0.94, 0.94)
	# Меш перекрашивается по поверхностям: тело — пальто, остальное — платок
	# и кожа. Импортированные материалы заменяются целиком, чтобы посёлок
	# не потерял свою палитру рядом со старой рыбалкой.
	var coat: Color = person.get("coat", Color("2f5f62"))
	var accent: Color = person.get("accent", Color("d9b06a"))
	var coat_mat := _solid_material(coat)
	# Поверхности GLB — обычный PBR-материал: шейдер стиля рассчитан на
	# процедурную геометрию и на скиннинге даёт артефакты.
	var skin_mat := _solid_material(Color("c99a76"))
	var accent_mat := _style_material(accent)
	for node in _character.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		for surface in range(mesh_instance.mesh.get_surface_count()):
			mesh_instance.set_surface_override_material(surface,
				skin_mat if surface == 0 else coat_mat)
		if _skeleton == null:
			_skeleton = _find_skeleton(mesh_instance.get_parent())
	_anim = _find_animation_player(_character)
	if _anim != null:
		_anim.root_node = _anim.get_path_to(_character)
		var clip := _find_idle()
		if not clip.is_empty():
			_anim.active = true
			_anim.play(clip)
			_anim.speed_scale = 0.72 + 0.26 * float(abs(hash(person_id)) % 5) * 0.1
			_anim.advance(_phase * 0.37)
	if _skeleton != null:
		_add_hat(accent_mat, coat_mat)
		_add_shoulders(coat_mat, accent)
	_prop = _add_prop(accent_mat)
	_add_name_label(accent)


func _build_fallback() -> void:
	# Если GLB не импортировался, житель всё равно должен стоять: силуэт из
	# простых форм, чтобы сцена не падала и smoke-тест не терял цели.
	var body := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.24
	capsule.height = 1.25
	body.mesh = capsule
	body.position.y = 0.85
	body.material_override = _style_material(person.get("coat", Color("2f5f62")))
	add_child(body)
	var head := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.19
	sphere.height = 0.38
	head.mesh = sphere
	head.position.y = 1.62
	head.material_override = _style_material(Color("c99a76"))
	add_child(head)
	_prop = _add_prop(_style_material(person.get("accent", Color("d9b06a"))))


func _solid_material(base: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = base
	mat.roughness = 0.88
	return mat


func _style_material(base: Color) -> Material:
	var shader := load(STYLE_SHADER_PATH) as Shader
	if shader == null:
		var fallback := StandardMaterial3D.new()
		fallback.albedo_color = base
		fallback.roughness = 0.92
		return fallback
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("base_color", base)
	mat.set_shader_parameter("night_amount", 0.0)
	mat.set_shader_parameter("sun_direction", Vector3(0.3, 0.9, 0.3))
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


func _find_idle() -> String:
	if _anim == null:
		return ""
	for fragment in ["Idle_Loop", "Idle_Talking_Loop", "Idle_Talking"]:
		for anim_name in _anim.get_animation_list():
			if str(anim_name).ends_with(fragment):
				return str(anim_name)
	for anim_name in _anim.get_animation_list():
		var lower := str(anim_name).to_lower()
		if "idle" in lower and not ("crouch" in lower or "sitting" in lower):
			return str(anim_name)
	return ""


func _add_hat(accent_mat: Material, coat_mat: Material) -> void:
	var hat := String(person.get("hat", "none"))
	if hat == "none":
		return
	var head_bone := _skeleton.find_bone("DEF-head")
	if head_bone < 0:
		return
	var anchor := BoneAttachment3D.new()
	anchor.bone_name = "DEF-head"
	_skeleton.add_child(anchor)
	var brim := MeshInstance3D.new()
	var brim_mesh := CylinderMesh.new()
	brim_mesh.top_radius = 0.155
	brim_mesh.bottom_radius = 0.175
	brim_mesh.height = 0.03
	brim_mesh.radial_segments = 12
	brim.mesh = brim_mesh
	brim.position = Vector3(0.0, 0.10, 0.0)
	brim.material_override = accent_mat
	anchor.add_child(brim)
	if hat == "cap":
		var crown := MeshInstance3D.new()
		var crown_mesh := CylinderMesh.new()
		crown_mesh.top_radius = 0.12
		crown_mesh.bottom_radius = 0.15
		crown_mesh.height = 0.10
		crown_mesh.radial_segments = 10
		crown.mesh = crown_mesh
		crown.position = Vector3(0.0, 0.16, 0.0)
		crown.material_override = coat_mat
		anchor.add_child(crown)
	elif hat == "kerchief":
		# Платок: низкий конус и узел сзади — читается и на маленьком экране.
		var knot := MeshInstance3D.new()
		var knot_mesh := SphereMesh.new()
		knot_mesh.radius = 0.055
		knot_mesh.height = 0.11
		knot.mesh = knot_mesh
		knot.position = Vector3(0.0, 0.09, 0.14)
		knot.material_override = accent_mat
		anchor.add_child(knot)
		var tail := MeshInstance3D.new()
		var tail_mesh := BoxMesh.new()
		tail_mesh.size = Vector3(0.12, 0.20, 0.02)
		tail.mesh = tail_mesh
		tail.position = Vector3(0.0, -0.06, 0.16)
		tail.rotation.x = -0.25
		tail.material_override = accent_mat
		anchor.add_child(tail)
	else:
		var hood := MeshInstance3D.new()
		var hood_mesh := SphereMesh.new()
		hood_mesh.radius = 0.20
		hood_mesh.height = 0.34
		hood.mesh = hood_mesh
		hood.position = Vector3(0.0, 0.10, -0.01)
		hood.material_override = coat_mat
		anchor.add_child(hood)


func _add_shoulders(coat_mat: Material, accent: Color) -> void:
	var torso_bone := _skeleton.find_bone("DEF-spine.002")
	if torso_bone < 0:
		return
	var anchor := BoneAttachment3D.new()
	anchor.bone_name = "DEF-spine.002"
	_skeleton.add_child(anchor)
	var shawl := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.20
	capsule.height = 0.34
	capsule.radial_segments = 10
	shawl.mesh = capsule
	shawl.scale = Vector3(1.12, 0.80, 0.82)
	shawl.position = Vector3(0.0, 0.06, 0.0)
	shawl.material_override = coat_mat
	anchor.add_child(shawl)
	# Цветной шарф: единственное яркое пятно, по нему жителя узнают.
	var scarf := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.13
	torus.outer_radius = 0.19
	torus.rings = 12
	torus.ring_segments = 6
	scarf.mesh = torus
	scarf.rotation.x = PI * 0.5
	scarf.position = Vector3(0.0, 0.20, 0.0)
	scarf.material_override = _style_material(accent)
	anchor.add_child(scarf)


func _add_prop(accent_mat: Material) -> Node3D:
	var prop := String(person.get("prop", "net"))
	var root := Node3D.new()
	root.name = "Prop"
	root.position = Vector3(0.36, 1.02, -0.30)
	add_child(root)
	match prop:
		"net":
			# Сеть на игле: тёмное полотно и деревянная игла.
			var net := MeshInstance3D.new()
			var quad := QuadMesh.new()
			quad.size = Vector2(0.70, 0.95)
			net.mesh = quad
			net.material_override = _style_material(Color("3b4a3a"))
			net.position = Vector3(-0.10, -0.10, 0.0)
			net.rotation.y = 0.3
			root.add_child(net)
			var needle := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3(0.035, 0.34, 0.035)
			needle.mesh = box
			needle.position = Vector3(0.20, 0.18, 0.06)
			needle.rotation.z = -0.45
			needle.material_override = accent_mat
			root.add_child(needle)
		"lantern", "lamp":
			var cage := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3(0.16, 0.22, 0.16)
			cage.mesh = box
			cage.position = Vector3(0.0, 0.0, 0.0)
			cage.material_override = accent_mat
			root.add_child(cage)
			_lantern_light = OmniLight3D.new()
			_lantern_light.light_color = Color("ffd2a1")
			_lantern_light.omni_range = 3.2
			_lantern_light.light_energy = 0.0
			_lantern_light.shadow_enabled = false
			root.add_child(_lantern_light)
		"tray":
			var tray := MeshInstance3D.new()
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.24
			cyl.bottom_radius = 0.20
			cyl.height = 0.05
			cyl.radial_segments = 10
			tray.mesh = cyl
			tray.position = Vector3(0.0, -0.05, 0.0)
			tray.material_override = _style_material(Color("cfc4b4"))
			root.add_child(tray)
			var mug := MeshInstance3D.new()
			var mug_mesh := CylinderMesh.new()
			mug_mesh.top_radius = 0.06
			mug_mesh.bottom_radius = 0.05
			mug_mesh.height = 0.12
			mug_mesh.radial_segments = 8
			mug.mesh = mug_mesh
			mug.position = Vector3(-0.08, 0.06, 0.0)
			mug.material_override = accent_mat
			root.add_child(mug)
		"bucket":
			var bucket := MeshInstance3D.new()
			var mesh := CylinderMesh.new()
			mesh.top_radius = 0.16
			mesh.bottom_radius = 0.12
			mesh.height = 0.26
			mesh.radial_segments = 10
			bucket.mesh = mesh
			bucket.position = Vector3(0.0, -0.14, 0.0)
			bucket.material_override = accent_mat
			root.add_child(bucket)
		"hammer":
			var handle := MeshInstance3D.new()
			var mesh := BoxMesh.new()
			mesh.size = Vector3(0.04, 0.40, 0.04)
			handle.mesh = mesh
			handle.position = Vector3(0.0, 0.02, 0.0)
			handle.rotation.z = 0.5
			handle.material_override = _style_material(Color("6b5544"))
			root.add_child(handle)
			var head := MeshInstance3D.new()
			var head_mesh := BoxMesh.new()
			head_mesh.size = Vector3(0.16, 0.08, 0.08)
			head.mesh = head_mesh
			head.position = Vector3(-0.10, 0.22, 0.0)
			head.material_override = _style_material(Color("2c2c33"))
			root.add_child(head)
		"book":
			var book := MeshInstance3D.new()
			var mesh := BoxMesh.new()
			mesh.size = Vector3(0.24, 0.30, 0.04)
			book.mesh = mesh
			book.position = Vector3(0.0, 0.04, 0.0)
			book.rotation.z = 0.15
			book.material_override = accent_mat
			root.add_child(book)
		"spyglass":
			var tube := MeshInstance3D.new()
			var mesh := CylinderMesh.new()
			mesh.top_radius = 0.035
			mesh.bottom_radius = 0.05
			mesh.height = 0.42
			mesh.radial_segments = 8
			tube.mesh = mesh
			tube.rotation.x = PI * 0.5
			tube.position = Vector3(0.0, 0.36, -0.05)
			tube.material_override = accent_mat
			root.add_child(tube)
		"rope":
			var rope := MeshInstance3D.new()
			var mesh := CylinderMesh.new()
			mesh.top_radius = 0.015
			mesh.bottom_radius = 0.015
			mesh.height = 1.05
			mesh.radial_segments = 6
			rope.mesh = mesh
			rope.position = Vector3(0.0, 0.10, 0.0)
			rope.material_override = _style_material(Color("a2967c"))
			root.add_child(rope)
		"crate":
			var crate := MeshInstance3D.new()
			var mesh := BoxMesh.new()
			mesh.size = Vector3(0.34, 0.28, 0.30)
			crate.mesh = mesh
			crate.position = Vector3(0.0, -0.10, 0.0)
			crate.material_override = _style_material(Color("6b5544"))
			root.add_child(crate)
	return root


func _add_name_label(accent: Color) -> void:
	_name_label = Label3D.new()
	_name_label.name = "NameTag"
	_name_label.text = String(person.get("name", ""))
	_name_label.font = TideTokens.title_font()
	_name_label.font_size = 44
	_name_label.pixel_size = 0.0055
	_name_label.modulate = accent.lightened(0.22)
	_name_label.outline_size = 12
	_name_label.outline_modulate = Color("0d1520")
	_name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_name_label.no_depth_test = false
	_name_label.position = Vector3(0.0, 2.12, 0.0)
	_name_label.visible = false
	add_child(_name_label)


func _process(delta: float) -> void:
	_time += delta
	if _style_materials.size() > 0 and main != null:
		for mat in _style_materials:
			mat.set_shader_parameter("night_amount", main.night01)
	if _lantern_light != null and main != null:
		_lantern_light.light_energy = maxf(0.0, main.night01 - 0.20) * 0.9
	# Едва заметное «дыхание» поверх клипа: житель не стоит как манекен,
	# но и не танцует на месте.
	if _character != null:
		_character.position.y = sin(_time * 1.35 + _phase) * 0.012
	# Фонарь в руке слегка качается на ремне.
	if _prop != null and String(person.get("prop", "")) in ["lantern", "lamp"]:
		_prop.rotation.z = sin(_time * 1.1 + _phase) * 0.07


func title() -> String:
	return String(person.get("name", ""))


func role() -> String:
	return String(person.get("role", ""))
