class_name HarborArchitecture
extends Node3D
## Stylised timber landing station: pile bents -> caps -> stringers -> deck.
## Repeated boards, braces and cladding are batched, not individual draw calls.
var main: BoatMain
var windows: StandardMaterial3D
var _groups: Dictionary = {}
var _timber: StandardMaterial3D
var _deck: StandardMaterial3D
var _paint: StandardMaterial3D
var _trim: StandardMaterial3D
var _iron: StandardMaterial3D
var _roof: StandardMaterial3D
var _unit_box := BoxMesh.new()
var _unit_post := CylinderMesh.new()


func _instance(key: String, mesh: Mesh, material: Material, instance_transform: Transform3D) -> void:
	if not _groups.has(key):
		_groups[key] = {"mesh": mesh, "material": material, "transforms": []}
	var group: Dictionary = _groups[key]
	var transforms: Array = group["transforms"]
	transforms.append(instance_transform)


func _box(key: String, at: Vector3, size: Vector3, material: Material, rot: Vector3 = Vector3.ZERO) -> void:
	_instance(key, _unit_box, material, Transform3D((Basis.from_euler(rot) * Basis.from_scale(size)), at))


func _beam(a: Vector3, b: Vector3, width: float, material: Material, key: String = "timber") -> void:
	var direction := b - a
	var beam_basis := Basis(Quaternion(Vector3.UP, direction.normalized())) * Basis.from_scale(Vector3(width, direction.length(), width))
	_instance(key, _unit_box, material, Transform3D(beam_basis, (a + b) * 0.5))


func _post(x: float, z: float, top: float) -> void:
	var bed := main.coast.ground_height(x, z) - 0.7
	var h := maxf(0.3, top - bed)
	_instance("piles", _unit_post, _timber, Transform3D(Basis.IDENTITY.scaled(Vector3(0.20, h, 0.20)), Vector3(x, bed + h * 0.5, z)))


func _decking(rect: Rect2) -> void:
	var count := int(ceil(rect.size.x / 0.25))
	for i in range(count):
		var x := rect.position.x + (float(i) + 0.5) * rect.size.x / float(count)
		var segments := int(ceil(rect.size.y / 3.0))
		for j in range(segments):
			var width := rect.size.y / float(segments)
			var z := rect.position.y + (float(j) + 0.5) * width
			_box("boards", Vector3(x, 1.29, z), Vector3(rect.size.x / float(count) - 0.015, 0.12, width - 0.012), _deck)
	for z in [rect.position.y + 0.3, rect.end.y - 0.3]:
		_box("timber", Vector3(rect.get_center().x, 0.91, float(z)), Vector3(rect.size.x, 0.38, 0.22), _timber)


func _rail(a: Vector2, b: Vector2) -> void:
	var length := a.distance_to(b)
	var segments := maxi(1, int(ceil(length / 2.6)))
	for i in range(segments + 1):
		var p := a.lerp(b, float(i) / float(segments))
		_box("timber", Vector3(p.x, 1.84, p.y), Vector3(0.10, 1.0, 0.10), _timber)
	for y in [1.78, 2.28]:
		_beam(Vector3(a.x, float(y), a.y), Vector3(b.x, float(y), b.y), 0.075, _timber)


func _window(center: Vector3, yaw: float = 0.0) -> void:
	var turn := Basis(Vector3.UP, yaw)
	_box("windows", center, Vector3(1.15, 1.0, 0.035), windows, Vector3(0, yaw, 0))
	for i in range(3):
		var x := float(i - 1) * 0.62
		_box("trim", center + turn * Vector3(x, 0, 0.04), Vector3(0.065, 1.15, 0.09), _trim, Vector3(0, yaw, 0))
		var y := float(i - 1) * 0.55
		_box("trim", center + turn * Vector3(0, y, 0.04), Vector3(1.3, 0.065, 0.09), _trim, Vector3(0, yaw, 0))


func _gable(x: float, normal: Vector3) -> void:
	var mesh := ArrayMesh.new()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(x, 4.6, -52.25), Vector3(x, 4.6, -45.75), Vector3(x, 6.8, -49.0)])
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([normal, normal, normal])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2] if normal.x > 0 else [2, 1, 0])
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = _paint
	add_child(node)


func _crate(at: Vector3, color: Material) -> void:
	_box("crates", at, Vector3(0.9, 0.48, 0.62), color)
	for side in [-1.0, 1.0]:
		_box("crate_trim", at + Vector3(0.0, 0.26, float(side) * 0.30), Vector3(0.95, 0.065, 0.065), _trim)


func setup(game: BoatMain) -> void:
	main = game
	name = "TimberFishingStation"
	_unit_box.size = Vector3.ONE
	_unit_post.height = 1.0
	_unit_post.top_radius = 1.0
	_unit_post.bottom_radius = 1.0
	_unit_post.radial_segments = 10
	_timber = main._mat(Color("4d4b40"), 0.0, 0.0, 0.9)
	_deck = main._mat(Color("8a806b"), 0.0, 0.0, 0.94)
	_paint = main._mat(Color("795951"), 0.0, 0.0, 0.92)
	_paint.cull_mode = BaseMaterial3D.CULL_DISABLED
	_trim = main._mat(Color("c4c0a5"), 0.0, 0.0, 0.9)
	_iron = main._mat(Color("374849"), 0.3, 0.0, 0.8)
	_roof = main._mat(Color("526c69"), 0.2, 0.0, 0.83)
	windows = main._mat(Color("324b4c"), 0.18, 0.12, 0.3)
	windows.emission = Color("e2b777")
	# Pile bents at 4 m centres, cross caps, longitudinal stringers and braces.
	_decking(IslandLayout.PIER_RECT)
	for i in range(13):
		var x := 110.0 + float(i) * 4.0
		_post(x, -32.5, 1.92)
		_post(x, -27.5, 1.92)
		_box("timber", Vector3(x, 0.68, -30.0), Vector3(0.26, 0.28, 5.7), _timber)
		if i % 2 == 0:
			_beam(Vector3(x, -1.7, -32.5), Vector3(x, 0.58, -27.5), 0.13, _timber)
			_beam(Vector3(x, -1.7, -27.5), Vector3(x, 0.58, -32.5), 0.13, _timber)
		if i < 12:
			_box("fenders", Vector3(x + 1.0, 0.68, -33.14), Vector3(0.18, 1.0, 0.17), _iron)
			# Mooring cleats, not continuous rail on the loading edge.
			_box("iron", Vector3(x + 1.0, 1.55, -32.75), Vector3(0.48, 0.08, 0.10), _iron)
			_box("iron", Vector3(x + 1.0, 1.43, -32.75), Vector3(0.10, 0.22, 0.10), _iron)
	_rail(Vector2(110, -27.2), Vector2(159, -27.2))
	# Side platform on stilts keeps the station INSIDE the ordinary boat camera.
	# The 9 m water slip remains between platform and pier, with room for trailer.
	_decking(IslandLayout.HARBOR_APRON)
	_decking(IslandLayout.HARBOR_LINK)
	for x in [118.5, 124.5, 130.5]:
		for z in [-53.4, -42.6]:
			_post(float(x), float(z), 1.4)
		_box("timber", Vector3(float(x), 0.68, -48.0), Vector3(0.3, 0.3, 11.6), _timber)
		_beam(Vector3(float(x), -1.8, -53.4), Vector3(float(x), 0.58, -42.6), 0.14, _timber)
	for z in [-46.5, -39.0, -31.0]:
		_post(131.5, float(z), 1.4)
		_post(134.5, float(z), 1.4)
	_rail(Vector2(118.2, -53.7), Vector2(130.8, -53.7))
	_rail(Vector2(118.2, -53.7), Vector2(118.2, -42.4))
	_rail(Vector2(134.8, -47.5), Vector2(134.8, -33.0))
	# Shore access: individual boards and side stringers rather than one slab.
	var rise := atan2(2.65, 25.0)
	for i in range(88):
		var t := (float(i) + 0.5) / 88.0
		_box("boards", Vector3(152.0 + 25.0 * t, 1.35 + 2.65 * t, -30.0), Vector3(0.27, 0.12, 3.8), _deck, Vector3(0, 0, rise))
	for z in [-31.8, -28.2]:
		_beam(Vector3(152, 1.02, float(z)), Vector3(177, 3.67, float(z)), 0.19, _timber)
	# Compact closed gear store with working verandah facing the berth/camera.
	_box("timber", Vector3(124.0, 1.43, -49.0), Vector3(8.2, 0.16, 6.7), _timber)
	_box("paint", Vector3(124.0, 3.05, -49.0), Vector3(8.0, 3.1, 6.5), _paint)
	for i in range(17):
		var y := 1.58 + float(i) * 0.178
		for z in [-52.28, -45.72]:
			_box("cladding", Vector3(124.0, y, float(z)), Vector3(8.0, 0.145, 0.055), _paint)
		for x in [119.97, 128.03]:
			_box("cladding", Vector3(float(x), y, -49.0), Vector3(0.055, 0.145, 6.5), _paint)
	for x in [119.92, 128.08]:
		for z in [-52.28, -45.72]:
			_box("trim", Vector3(float(x), 3.1, float(z)), Vector3(0.14, 3.2, 0.14), _trim)
	_gable(119.98, Vector3.LEFT)
	_gable(128.02, Vector3.RIGHT)
	# Exposed king-post/web framing on each gable, inspired by the FAO elevation.
	for x in [119.90, 128.10]:
		_beam(Vector3(float(x), 4.63, -52.25), Vector3(float(x), 4.63, -45.75), 0.09, _trim, "trim")
		_beam(Vector3(float(x), 4.63, -52.25), Vector3(float(x), 6.75, -49.0), 0.09, _trim, "trim")
		_beam(Vector3(float(x), 4.63, -45.75), Vector3(float(x), 6.75, -49.0), 0.09, _trim, "trim")
		_beam(Vector3(float(x), 4.63, -49.0), Vector3(float(x), 6.75, -49.0), 0.08, _trim, "trim")
		_beam(Vector3(float(x), 4.63, -49.0), Vector3(float(x), 5.68, -50.6), 0.07, _trim, "trim")
		_beam(Vector3(float(x), 4.63, -49.0), Vector3(float(x), 5.68, -47.4), 0.07, _trim, "trim")
	var pitch := atan2(2.35, 3.8)
	for side in [-1.0, 1.0]:
		_box("roof", Vector3(124, 5.625, -49 + float(side) * 1.9), Vector3(9.4, 0.14, 4.468), _roof, Vector3(float(side) * pitch, 0, 0))
		for i in range(27):
			var x := 119.4 + float(i) * 0.35
			_beam(Vector3(x, 6.89, -49.0), Vector3(x, 4.54, -49.0 + float(side) * 3.8), 0.035, _roof, "roof")
	_beam(Vector3(119.25, 6.88, -49), Vector3(128.75, 6.88, -49), 0.14, _iron, "iron")
	_window(Vector3(121.55, 3.12, -45.64))
	_window(Vector3(126.45, 3.12, -45.64))
	_window(Vector3(128.10, 3.12, -49.0), PI * 0.5)
	_box("iron", Vector3(124.0, 2.53, -45.61), Vector3(1.3, 2.0, 0.10), _iron)
	for x in [123.29, 124.71]:
		_box("trim", Vector3(float(x), 2.56, -45.52), Vector3(0.10, 2.1, 0.12), _trim)
	_box("trim", Vector3(124.0, 3.64, -45.52), Vector3(1.52, 0.11, 0.12), _trim)
	_box("iron", Vector3(124.42, 2.48, -45.42), Vector3(0.07, 0.21, 0.09), _iron)
	# Weather canopy, braces, sorting table and lidded catch boxes.
	_box("roof", Vector3(124, 4.04, -43.95), Vector3(8.9, 0.12, 3.55), _roof, Vector3(0.26, 0, 0))
	for x in [120.3, 127.7]:
		_box("timber", Vector3(float(x), 2.51, -42.4), Vector3(0.14, 2.34, 0.14), _timber)
		_beam(Vector3(float(x), 2.9, -42.4), Vector3(float(x), 3.65, -43.2), 0.09, _timber)
	_box("boards", Vector3(126.6, 2.22, -43.4), Vector3(2.3, 0.13, 0.8), _deck)
	for x in [125.7, 127.5]:
		for z in [-43.65, -43.15]:
			_box("timber", Vector3(float(x), 1.78, float(z)), Vector3(0.09, 0.82, 0.09), _timber)
	var crate_mat := main._mat(Color("85928b"), 0.0, 0.0, 0.88)
	_crate(Vector3(121.7, 1.65, -43.2), crate_mat)
	_crate(Vector3(122.8, 1.65, -43.2), crate_mat)
	_crate(Vector3(121.7, 2.13, -43.2), crate_mat)
	# Rope net on a compact repair rack; thin timber/rope instances share batches.
	for i in range(9):
		var x := 125.5 + float(i) * 0.23
		_beam(Vector3(x, 2.5, -44.85), Vector3(x, 3.55, -44.85), 0.016, _timber)
	for i in range(6):
		var y := 2.5 + float(i) * 0.21
		_beam(Vector3(125.5, y, -44.85), Vector3(127.35, y, -44.85), 0.016, _timber)
	# Life ring and coiled lines give readable fishing-station scale cues.
	var ring := TorusMesh.new()
	ring.inner_radius = 0.27
	ring.outer_radius = 0.43
	ring.rings = 16
	ring.ring_segments = 10
	var ring_node := MeshInstance3D.new()
	ring_node.mesh = ring
	ring_node.material_override = main._mat(Color("d49668"), 0.0, 0.0, 0.8)
	ring_node.position = Vector3(120.3, 2.75, -42.29)
	ring_node.rotation.x = PI * 0.5
	add_child(ring_node)
	var coil := TorusMesh.new()
	coil.inner_radius = 0.22
	coil.outer_radius = 0.30
	coil.rings = 14
	coil.ring_segments = 8
	for i in range(3):
		_instance("coil", coil, _deck, Transform3D(Basis.IDENTITY, Vector3(112.0, 1.4 + float(i) * 0.055, -31.8)))
	var label := Label3D.new()
	label.text = "ТИХАЯ БУХТА"
	label.font_size = 32
	label.pixel_size = 0.012
	label.position = Vector3(124.0, 3.6, -42.10)
	_box("timber", Vector3(124.0, 3.6, -42.20), Vector3(4.8, 0.44, 0.08), _timber)
	add_child(label)
	_box("timber", Vector3(116, 2.2, -30), Vector3(0.09, 1.7, 0.09), _timber)
	# Upload only once. Repeated parts cost one draw per material/mesh group.
	for key in _groups:
		var group: Dictionary = _groups[key]
		var transforms: Array = group["transforms"]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = group["mesh"]
		mm.instance_count = transforms.size()
		for i in range(transforms.size()):
			mm.set_instance_transform(i, transforms[i])
		var node := MultiMeshInstance3D.new()
		node.multimesh = mm
		node.material_override = group["material"]
		node.name = str(key)
		add_child(node)
	_groups.clear()
