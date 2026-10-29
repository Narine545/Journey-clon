class_name TargetDummy
extends Node3D
## Временная неподвижная мишень без ИИ. Попадание подтверждается один раз.

const CENTER_HEIGHT := 3.65
const DETAIL_DISTANCE := 300.0
var _confirmed := false

func _ready() -> void:
	var shell := StandardMaterial3D.new()
	shell.albedo_color = Color(0.13, 0.15, 0.14)
	shell.roughness = 0.9
	var accent := StandardMaterial3D.new()
	accent.albedo_color = Color(0.72, 0.37, 0.12)
	accent.roughness = 0.8
	_add_box("Body", Vector3(0, CENTER_HEIGHT, 0), Vector3(5.5, 4.3, 4.4), shell)
	_add_box("LeftLeg", Vector3(0, 0.75, -1.6), Vector3(1.5, 1.5, 1.1), shell)
	_add_box("RightLeg", Vector3(0, 0.75, 1.6), Vector3(1.5, 1.5, 1.1), shell)
	# Оранжевая деталь направлена к башне, чтобы куб было легче различить.
	_add_box("FrontPlate", Vector3(-2.76, CENTER_HEIGHT, 0), Vector3(0.05, 1.1, 1.8), accent)
	# Текущая мишень рядом; на дальних дистанциях остаётся один простой объём.
	for child in get_children():
		if child is MeshInstance3D:
			child.visibility_range_end = DETAIL_DISTANCE
	# M3: объёмный туман полностью прятал тестовую цель на 600 м.
	# Дальняя упрощённая модель окрашена в приглушённый пыльный цвет и
	# исключена из тумана: видна в оптике, но не подсвечивается маркером.
	var distant_shell := StandardMaterial3D.new()
	distant_shell.albedo_color = Color(0.24, 0.19, 0.16)
	distant_shell.roughness = 1.0
	distant_shell.disable_fog = true
	_add_box("DistantSilhouette", Vector3(0, 2.9, 0), Vector3(5.5, 5.8, 4.4), distant_shell)
	var distant := get_node("DistantSilhouette") as MeshInstance3D
	distant.visibility_range_begin = DETAIL_DISTANCE
	# Одинаковый мировой центр AABB для частей и силуэта: единый порог LOD.
	for child in get_children():
		if child is MeshInstance3D:
			child.custom_aabb = AABB(Vector3(-2.9, 0.0, -2.3) - child.position, Vector3(5.8, 5.8, 4.6))
	distant.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Collision layer 2 зарезервирован для мишеней; попадание ищется только
	# на отрезке реально пройденного снарядом пути.
	var body := StaticBody3D.new()
	body.name = "Hitbox"
	body.collision_layer = 2
	body.collision_mask = 0
	add_child(body)
	var hitbox := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(5.5, 5.8, 4.4)
	hitbox.shape = box_shape
	hitbox.position.y = 2.9
	body.add_child(hitbox)


func claim_confirmed_hit() -> bool:
	if _confirmed:
		return false
	_confirmed = true
	return true


func _add_box(part_name: String, at: Vector3, size: Vector3, mat: Material) -> void:
	var node := MeshInstance3D.new()
	node.name = part_name
	var box := BoxMesh.new()
	box.size = size
	node.mesh = box
	node.material_override = mat
	node.position = at
	add_child(node)
