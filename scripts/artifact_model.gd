class_name ArtifactModel
extends RefCounted
## Модели «артефактов из другого мира»: сфера-вход в рейд и приз за победу.
## Файл ищется по имени в нескольких папках; если его нет — заглушка из
## примитивов, чтобы игра работала и до появления модели.

const DIRS := ["res://assets/artifacts/", "res://assets/models/", "res://assets/", "res://"]
const ORB := "cyber_orb.glb"
const PRIZE := "food_collection_-_game_ready.glb"
## Вещи коллекции: имя узла в модели и подпись. В бухте таких вещей не делают,
## поэтому названия — как их описала бы Мимо.
const ITEMS := [
	["SM_Beer_Bottle_01", "БУТЫЛКА ТЁМНОГО СТЕКЛА"],
	["SM_Beer_Can_01", "ЖЕСТЯНКА С ШИПУЧКОЙ"],
	["SM_Beer_Can_02", "ЖЕСТЯНКА С ШИПУЧКОЙ, ВТОРАЯ"],
	["SM_Bleach_01", "БЕЛАЯ ЕДКАЯ ЖИДКОСТЬ"],
	["SM_Bottle_01", "ПРОЗРАЧНАЯ БУТЫЛЬ"],
	["SM_Bottles_Pack_01", "СВЯЗКА БУТЫЛОК"],
	["SM_Candies_01", "ПАКЕТ СЛАДКИХ КАМЕШКОВ"],
	["SM_Canned_Food_05", "КОНСЕРВА БЕЗ ЭТИКЕТКИ"],
	["SM_Canned_Food_06", "КОНСЕРВА С РЫБОЙ"],
	["SM_Canned_Food_07", "КОНСЕРВА С БОБАМИ"],
	["SM_Canned_Food_08", "КОНСЕРВА С ЧЕМ-ТО КРАСНЫМ"],
	["SM_Canned_Food_09", "ПЛОСКАЯ КОНСЕРВА"],
	["SM_Canned_Food_10", "ВЫСОКАЯ КОНСЕРВА"],
	["SM_Canned_Food_11", "КОНСЕРВА С КОЛЬЦОМ"],
	["SM_Canned_Food_12", "МЯТАЯ КОНСЕРВА"],
	["SM_Canned_Food_13", "КОНСЕРВА НА ЧЁРНЫЙ ДЕНЬ"],
	["SM_Cereal_01", "КОРОБКА ХРУСТЯЩИХ ХЛОПЬЕВ"],
	["SM_Chewing_Gum_01", "ЖЕВАТЕЛЬНЫЕ ПЛАСТИНКИ"],
	["SM_Chocolate_Bar_01", "ПЛИТКА ШОКОЛАДА"],
	["SM_Chocolate_Bar_02", "ШОКОЛАД С ОРЕХАМИ"],
	["SM_Coffee_Box_01", "КОРОБКА КОФЕ"],
	["SM_Detergent_Liquid_01", "ЖИДКОСТЬ ДЛЯ СТИРКИ"],
	["SM_Detergent_Powder_01", "СТИРАЛЬНЫЙ ПОРОШОК"],
	["SM_Detergent_Powder_02", "ПОРОШОК В СИНЕЙ КОРОБКЕ"],
	["SM_Detergent_Powder_03", "ПОРОШОК В БОЛЬШОЙ КОРОБКЕ"],
	["SM_Dishwashing_Liquid_01", "СРЕДСТВО ДЛЯ ПОСУДЫ"],
	["SM_Glue_01", "ТЮБИК КЛЕЯ"],
	["SM_Juice_Carton_01", "КАРТОННЫЙ СОК"],
	["SM_Matches_Box_01", "КОРОБОК СПИЧЕК"],
	["SM_Milk_Bottle_01", "БУТЫЛКА МОЛОКА"],
	["SM_Olive_Oil_01", "ЗЕЛЁНОЕ МАСЛО"],
	["SM_Pasta_01", "ПАЧКА МАКАРОН"],
	["SM_Pills_Box_01", "КОРОБОЧКА ПИЛЮЛЬ"],
	["SM_Porridge_01", "КАША БЫСТРОЙ ВАРКИ"],
	["SM_Protein_Jar_01", "БАНКА ПОРОШКА СИЛЫ"],
	["SM_Salt_02", "СОЛЬ"],
	["SM_Sausages_01", "СВЯЗКА СОСИСОК"],
	["SM_Sause_01", "БУТЫЛОЧКА СОУСА"],
	["SM_Snack_01", "ХРУСТЯЩАЯ ЗАКУСКА"],
	["SM_Wine_Bottle_01", "БУТЫЛКА ВИНА"],
]


static func find(file: String) -> String:
	for dir: String in DIRS:
		if ResourceLoader.exists(dir + file):
			return dir + file
	return ""


## Узел с моделью, вписанной в куб со стороной fit и поставленной центром в ноль.
static func build(file: String, fit: float) -> Node3D:
	var model := _load(file)
	if model == null:
		model = _placeholder(file == ORB)
	return _fitted(model, fit)


## Одна вещь из коллекции находок: остальные предметы и подставка убираются.
static func build_item(index: int, fit: float) -> Node3D:
	var model := _load(PRIZE)
	if model == null or index < 0 or index >= ITEMS.size():
		return build(PRIZE, fit)
	var wanted := String(ITEMS[index][0])
	var keep: Node = null
	var extra: Array[Node] = []
	for node in model.find_children("SM_*", "Node3D", true, false):
		# Предметы — прямые дети общего корня; их собственные сетки не трогаем.
		if String(node.get_parent().name).begins_with("SM_"):
			continue
		if keep == null and String(node.name) == wanted:
			keep = node
		else:
			extra.append(node)
	if keep == null:
		model.free()
		return build(PRIZE, fit)
	for node in model.find_children("Plane*", "Node3D", true, false):
		extra.append(node)
	for node in extra:
		if is_instance_valid(node):
			node.get_parent().remove_child(node)
			node.free()
	return _fitted(model, fit)


static func item_name(index: int) -> String:
	if index < 0 or index >= ITEMS.size():
		return "АРТЕФАКТ"
	return String(ITEMS[index][1])


static func _load(file: String) -> Node3D:
	var path := find(file)
	if path.is_empty():
		return null
	var packed := load(path) as PackedScene
	if packed == null:
		return null
	return packed.instantiate() as Node3D


static func _fitted(model: Node3D, fit: float) -> Node3D:
	var holder := Node3D.new()
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
