class_name TargetDummy
extends Node3D
## Неподвижный временный робот-куб M1. Не имеет ИИ, попаданий или награды.

const CENTER_HEIGHT := 3.65
const DETAIL_DISTANCE := 300.0

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
	_add_box("DistantSilhouette", Vector3(0, 2.9, 0), Vector3(5.5, 5.8, 4.4), shell)
	var distant := get_node("DistantSilhouette") as MeshInstance3D
	distant.visibility_range_begin = DETAIL_DISTANCE
	# Одинаковый мировой центр AABB для частей и силуэта: единый порог LOD.
	for child in get_children():
		if child is MeshInstance3D:
			child.custom_aabb = AABB(Vector3(-2.9, 0.0, -2.3) - child.position, Vector3(5.8, 5.8, 4.6))
	distant.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _add_box(part_name: String, at: Vector3, size: Vector3, mat: Material) -> void:
	var node := MeshInstance3D.new()
	node.name = part_name
	var box := BoxMesh.new()
	box.size = size
	node.mesh = box
	node.material_override = mat
	node.position = at
	add_child(node)
