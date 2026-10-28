class_name TargetDummy
extends Node3D
## Неподвижный временный робот-куб M1. Не имеет ИИ, попаданий или награды.

func _ready() -> void:
	var shell := StandardMaterial3D.new()
	shell.albedo_color = Color(0.13, 0.15, 0.14)
	shell.roughness = 0.9
	var accent := StandardMaterial3D.new()
	accent.albedo_color = Color(0.72, 0.37, 0.12)
	accent.roughness = 0.8
	_add_box("Body", Vector3(0, 2.65, 0), Vector3(3.5, 2.8, 3.1), shell)
	_add_box("LeftLeg", Vector3(0, 0.65, -1.15), Vector3(1.1, 1.3, 0.8), shell)
	_add_box("RightLeg", Vector3(0, 0.65, 1.15), Vector3(1.1, 1.3, 0.8), shell)
	# Оранжевая деталь направлена к башне, чтобы куб было легче различить.
	_add_box("FrontPlate", Vector3(-1.76, 2.65, 0), Vector3(0.05, 0.65, 1.2), accent)


func _add_box(part_name: String, at: Vector3, size: Vector3, mat: Material) -> void:
	var node := MeshInstance3D.new()
	node.name = part_name
	var box := BoxMesh.new()
	box.size = size
	node.mesh = box
	node.material_override = mat
	node.position = at
	add_child(node)
