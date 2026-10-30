class_name SupplyCrate
extends StaticBody3D
## Простой ящик с отдельной коллизией взгляда (слой 4).
func _ready() -> void:
	var shell := StandardMaterial3D.new()
	shell.albedo_color = Color(0.38, 0.29, 0.18)
	shell.roughness = 0.9
	var mesh_part := MeshInstance3D.new()
	var cube := BoxMesh.new()
	cube.size = Vector3(1.35, 1.0, 1.0)
	mesh_part.mesh = cube
	mesh_part.material_override = shell
	add_child(mesh_part)
	var shape := BoxShape3D.new()
	shape.size = cube.size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	add_child(collision)
	var band := MeshInstance3D.new()
	var band_mesh := BoxMesh.new()
	band_mesh.size = Vector3(0.15, 1.02, 1.02)
	band.mesh = band_mesh
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.15, 0.15, 0.13)
	band.material_override = metal
	add_child(band)
