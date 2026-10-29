class_name WastelandLandmarks
extends Node3D
## Небольшое число рукотворных силуэтов на разных планах. Каждый дальний
## объект — пара объединённых мешей; за порогом Visibility Range остаётся
## упрощённый силуэт, а не десятки отдельных мелких деталей.

const LOD_DISTANCE := 720.0
var detailed: Array[MeshInstance3D] = []
var simplified: Array[MeshInstance3D] = []
var _metal: StandardMaterial3D
var _wreck: StandardMaterial3D


func setup(coast: Coast, origin: Vector2) -> void:
	_metal = StandardMaterial3D.new()
	_metal.albedo_color = Color(0.16, 0.17, 0.16)
	_metal.roughness = 0.95
	_wreck = StandardMaterial3D.new()
	_wreck.albedo_color = Color(0.29, 0.20, 0.14)
	_wreck.roughness = 0.95
	_build_ship(coast, origin + Vector2(850.0, -150.0))
	_build_mast(coast, origin + Vector2(740.0, 330.0))
	_build_arch(coast, origin + Vector2(1050.0, -620.0))
	_build_wreck(coast, origin + Vector2(310.0, 155.0), -0.18)
	_build_wreck(coast, origin + Vector2(390.0, -205.0), 0.27)


func _part(pos: Vector3, size: Vector3, part_rotation: Vector3 = Vector3.ZERO) -> Dictionary:
	return {"position": pos, "size": size, "rotation": part_rotation}


func _mesh(parts: Array, material: Material) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for part in parts:
		var cube := BoxMesh.new()
		cube.size = part["size"]
		var euler: Vector3 = part["rotation"]
		var part_basis := Basis.from_euler(euler)
		surface.append_from(cube, 0, Transform3D(part_basis, part["position"]))
	surface.set_material(material)
	return surface.commit()


func _place_pair(label: String, coast: Coast, point: Vector2, high: Array, low: Array) -> void:
	var anchor := Node3D.new()
	anchor.name = label
	anchor.position = Vector3(point.x, coast.ground_height(point.x, point.y), point.y)
	add_child(anchor)
	var high_mesh := MeshInstance3D.new()
	high_mesh.name = "Detailed"
	high_mesh.mesh = _mesh(high, _metal)
	high_mesh.visibility_range_end = LOD_DISTANCE
	high_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	anchor.add_child(high_mesh)
	var low_mesh := MeshInstance3D.new()
	low_mesh.name = "DistantSilhouette"
	low_mesh.mesh = _mesh(low, _metal)
	low_mesh.visibility_range_begin = LOD_DISTANCE
	# Godot измеряет Visibility Range до центра AABB, а не до origin.
	# Общая рамка исключает щель/двойной показ при переключении уровней.
	var shared_bounds: AABB = high_mesh.mesh.get_aabb().merge(low_mesh.mesh.get_aabb())
	high_mesh.custom_aabb = shared_bounds
	low_mesh.custom_aabb = shared_bounds
	low_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	anchor.add_child(low_mesh)
	detailed.append(high_mesh)
	simplified.append(low_mesh)


func _build_ship(coast: Coast, point: Vector2) -> void:
	# Остов корабля поперёк горизонта; нос частично погребён песком.
	var low := [
		_part(Vector3(0, 40, 0), Vector3(32, 70, 235)),
		_part(Vector3(0, 92, 65), Vector3(26, 42, 70)),
		_part(Vector3(0, 132, 74), Vector3(18, 40, 30)),
		_part(Vector3(0, 62, -110), Vector3(28, 16, 70), Vector3(0.30, 0, 0))]
	var high := low.duplicate()
	for z in [-85.0, -48.0, -10.0, 28.0, 66.0, 103.0]:
		high.append(_part(Vector3(-17, 44, z), Vector3(3.5, 76, 4.0), Vector3(0.0, 0.0, -0.12)))
	high.append(_part(Vector3(-17, 75, 0), Vector3(3.0, 3.0, 220)))
	high.append(_part(Vector3(1, 165, 76), Vector3(3.0, 35, 3.0), Vector3(0, 0, 0.16)))
	_place_pair("BuriedShip", coast, point, high, low)


func _build_mast(coast: Coast, point: Vector2) -> void:
	var low := [
		_part(Vector3(0, 94, 0), Vector3(15, 188, 15)),
		_part(Vector3(0, 148, 0), Vector3(9, 7, 86)),
		_part(Vector3(0, 192, 0), Vector3(7, 34, 7))]
	var high := low.duplicate()
	for h in [38.0, 72.0, 106.0, 140.0]:
		high.append(_part(Vector3(-9, h, 0), Vector3(3, 5, 42)))
		high.append(_part(Vector3(-9, h + 17.0, 0), Vector3(3, 43, 3), Vector3(0.72, 0, 0)))
	high.append(_part(Vector3(0, 180, 20), Vector3(3, 46, 3), Vector3(0.6, 0, 0)))
	_place_pair("RadioMast", coast, point, high, low)


func _build_arch(coast: Coast, point: Vector2) -> void:
	var low := [
		_part(Vector3(0, 75, -72), Vector3(18, 150, 20), Vector3(0.06, 0, 0)),
		_part(Vector3(0, 70, 64), Vector3(18, 140, 20), Vector3(-0.11, 0, 0)),
		_part(Vector3(0, 145, -17), Vector3(18, 18, 110), Vector3(0.11, 0, 0))]
	var high := low.duplicate()
	for z in [-54.0, -17.0, 20.0, 57.0]:
		high.append(_part(Vector3(-10, 138, z), Vector3(3, 30, 3), Vector3(0.45, 0, 0)))
	high.append(_part(Vector3(0, 114, 75), Vector3(16, 50, 12), Vector3(-0.35, 0, 0)))
	_place_pair("BrokenRib", coast, point, high, low)


func _build_wreck(coast: Coast, point: Vector2, angle: float) -> void:
	var wreck := MeshInstance3D.new()
	wreck.name = "HalfBuriedWreck"
	wreck.position = Vector3(point.x, coast.ground_height(point.x, point.y), point.y)
	wreck.rotation.y = angle
	wreck.mesh = _mesh([
		_part(Vector3(0, 2.5, 0), Vector3(10, 5, 24)),
		_part(Vector3(1, 6.5, 4), Vector3(7, 4, 8)),
		_part(Vector3(-5, 4, -5), Vector3(2, 8, 2), Vector3(0, 0, 0.3))], _wreck)
	wreck.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(wreck)
