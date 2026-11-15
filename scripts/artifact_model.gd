class_name ArtifactModel
extends RefCounted
## Модели «артефактов из другого мира»: сфера-вход в рейд и приз за победу.
## Файл ищется по имени в нескольких папках; если его нет — заглушка из
## примитивов, чтобы игра работала и до появления модели.

const DIRS := ["res://assets/artifacts/", "res://assets/models/", "res://assets/", "res://"]
const ORB := "cyber_orb.glb"
const PRIZE := "food_collection_-_game_ready.glb"


static func find(file: String) -> String:
	for dir: String in DIRS:
		if ResourceLoader.exists(dir + file):
			return dir + file
	return ""


## Узел с моделью, вписанной в куб со стороной fit и поставленной центром в ноль.
static func build(file: String, fit: float) -> Node3D:
	var holder := Node3D.new()
	var model: Node3D = null
	var path := find(file)
	if not path.is_empty():
		var packed := load(path) as PackedScene
		if packed != null:
			model = packed.instantiate() as Node3D
	if model == null:
		model = _placeholder(file == ORB)
	holder.add_child(model)
	var box := _bounds(model, Transform3D.IDENTITY)
	var longest := maxf(box.size.x, maxf(box.size.y, box.size.z))
	if longest > 0.0001:
		var k := fit / longest
		model.scale = model.scale * k
		model.position = (model.position - box.get_center()) * k
	return holder


static func _bounds(node: Node, xform: Transform3D) -> AABB:
	var local := xform
	if node is Node3D:
		local = xform * (node as Node3D).transform
	var box := AABB()
	var has := false
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		box = local * (node as MeshInstance3D).mesh.get_aabb()
		has = true
	for child in node.get_children():
		var inner := _bounds(child, local)
		if inner.size == Vector3.ZERO:
			continue
		box = box.merge(inner) if has else inner
		has = true
	return box


static func _glow(color: Color, energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	material.roughness = 0.35
	return material


static func _placeholder(orb: bool) -> Node3D:
	var root := Node3D.new()
	if orb:
		var core := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.5
		sphere.height = 1.0
		core.mesh = sphere
		core.material_override = _glow(Color("35d0ba"), 2.4)
		root.add_child(core)
		for index in range(2):
			var ring := MeshInstance3D.new()
			var torus := TorusMesh.new()
			torus.inner_radius = 0.62
			torus.outer_radius = 0.7
			ring.mesh = torus
			ring.material_override = _glow(Color("efead8"), 1.2)
			ring.rotation_degrees = Vector3(62.0 if index == 0 else -48.0, 0.0, 30.0 * float(index))
			root.add_child(ring)
		return root
	# Приз: ящик с «провизией» — три цветных бруска на поддоне.
	var tones := [Color("e3212e"), Color("efead8"), Color("35d0ba")]
	var tray := MeshInstance3D.new()
	var slab := BoxMesh.new()
	slab.size = Vector3(1.5, 0.12, 1.0)
	tray.mesh = slab
	tray.material_override = _glow(Color("1b3a5c"), 0.3)
	root.add_child(tray)
	for index in range(3):
		var item := MeshInstance3D.new()
		var can := CylinderMesh.new()
		can.top_radius = 0.2
		can.bottom_radius = 0.2
		can.height = 0.5 + 0.12 * float(index)
		item.mesh = can
		item.material_override = _glow(tones[index], 0.5)
		item.position = Vector3(-0.48 + 0.48 * float(index), 0.06 + can.height * 0.5, 0.0)
		root.add_child(item)
	return root
