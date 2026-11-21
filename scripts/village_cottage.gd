class_name VillageCottage
extends Node3D
## Replace just the visual with a Blender scene; origin at finished floor,
## +Z faces the lane. Dimensions, collision and placement remain independent.
@export var replacement_visual: PackedScene

const WIDTH := 5.8 # Micah Coffin House: about 19 ft
const DEPTH := 4.3 # about 14 ft
const EAVES := 2.35
const RIDGE := 4.2 # measured house: about 13.75 ft above ground

var window_material: StandardMaterial3D
var _groups: Dictionary = {}
var _cube := BoxMesh.new()


func build(variant: int, foundation_bottom: float) -> void:
	_cube.size = Vector3.ONE
	var wall_colors := [Color("b5b5a0"), Color("989f91"), Color("c7b89b"), Color("91a19c"), Color("a8a89a")]
	var roof_colors := [Color("535e5a"), Color("665d52"), Color("4e5a5c")]
	var siding := _material(wall_colors[variant % wall_colors.size()])
	siding.cull_mode = BaseMaterial3D.CULL_DISABLED
	var roof := _material(roof_colors[variant % roof_colors.size()])
	var trim := _material(Color("e0d4b7"))
	var dark := _material(Color("4a4a3e"))
	var door := _material([Color("5f7772"), Color("826953"), Color("7b8270")][variant % 3])
	var stone := _material(Color("77776a"))
	window_material = _material(Color("293d43"))
	window_material.emission_enabled = true
	window_material.emission = Color("e8b96d")
	window_material.emission_energy_multiplier = 0.0

	# A stable collision remains if the provisional art is replaced.
	var solid := StaticBody3D.new()
	solid.name = "BuildingCollision"
	add_child(solid)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(WIDTH, EAVES, DEPTH)
	collision.shape = shape
	collision.position.y = EAVES * 0.5
	solid.add_child(collision)

	if replacement_visual != null:
		var replacement := replacement_visual.instantiate()
		replacement.name = "ReplacementVisual"
		add_child(replacement)
		return

	# Low solid foundation reaches the uneven local ground, not a hovering pad.
	var foundation_depth := maxf(0.22, -foundation_bottom + 0.12)
	_box("foundation", Vector3(0, -foundation_depth * 0.5, 0), Vector3(WIDTH + 0.1, foundation_depth, DEPTH + 0.1), stone)
	_box("siding", Vector3(0, EAVES * 0.5, 0), Vector3(WIDTH, EAVES, DEPTH), siding)
	for x in [-WIDTH * 0.5, WIDTH * 0.5]:
		for z in [-DEPTH * 0.5, DEPTH * 0.5]:
			_box("trim", Vector3(float(x), EAVES * 0.5, float(z)), Vector3(0.10, EAVES, 0.10), trim)
	# Horizontal courses give small-scale weatherboard texture at camera range.
	for i in range(12):
		var y := 0.15 + float(i) * 0.19
		for z in [-DEPTH * 0.5 - 0.012, DEPTH * 0.5 + 0.012]:
			_box("seams", Vector3(0, y, float(z)), Vector3(WIDTH, 0.022, 0.035), dark)
		for x in [-WIDTH * 0.5 - 0.012, WIDTH * 0.5 + 0.012]:
			_box("seams", Vector3(float(x), y, 0), Vector3(0.035, 0.022, DEPTH), dark)

	# Gable + two pitched roof planes, with narrow shingle courses.
	_gable(-WIDTH * 0.5, siding)
	_gable(WIDTH * 0.5, siding)
	var run := DEPTH * 0.5 + 0.25
	var rise := RIDGE - EAVES
	var pitch := atan2(rise, run)
	var slope := sqrt(run * run + rise * rise)
	for side in [-1.0, 1.0]:
		var sign_side := float(side)
		_box("roof", Vector3(0, EAVES + rise * 0.5, sign_side * run * 0.5),
			Vector3(WIDTH + 0.65, 0.14, slope), roof, Vector3(sign_side * pitch, 0, 0))
		for i in range(7):
			var t := (float(i) + 0.5) / 7.0
			_box("roof_edges", Vector3(0, RIDGE - t * rise + 0.09, sign_side * run * t),
				Vector3(WIDTH + 0.7, 0.025, 0.035), dark)
	_box("chimney", Vector3(-1.65, 3.68, -0.40), Vector3(0.48, 1.35, 0.46), stone)
	_box("chimney", Vector3(-1.65, 4.38, -0.40), Vector3(0.62, 0.13, 0.58), stone)

	# Door, step and two small six-pane windows face the lane (+Z).
	var front := DEPTH * 0.5
	_box("door", Vector3(0.40, 1.02, front + 0.035), Vector3(0.95, 2.04, 0.10), door)
	for x in [-0.12, 0.92]:
		_box("trim", Vector3(float(x), 1.05, front + 0.105), Vector3(0.09, 2.12, 0.09), trim)
	_box("trim", Vector3(0.40, 2.12, front + 0.105), Vector3(1.13, 0.10, 0.09), trim)
	_box("step", Vector3(0.40, 0.04, front + 0.34), Vector3(1.35, 0.12, 0.62), dark)
	for x in [-1.85, 1.80]:
		_window(Vector3(float(x), 1.32, front + 0.04), trim)
	# The rear is also finished: there is no blank back when the camera moves.
	_window(Vector3(-1.05, 1.32, -front - 0.04), trim, PI)
	_window(Vector3(1.05, 1.32, -front - 0.04), trim, PI)
	# Individually optional lean-to, as in the measured Siasconset additions.
	if variant % 2 == 0:
		_box("siding", Vector3(-WIDTH * 0.5 - 0.8, 0.85, -0.35), Vector3(1.65, 1.7, 2.6), siding)
		_box("roof", Vector3(-WIDTH * 0.5 - 0.8, 1.82, -0.35), Vector3(1.9, 0.12, 2.8), roof, Vector3(0, 0, -0.18))
	_finish()


func set_night(amount: float) -> void:
	if window_material != null:
		window_material.emission_energy_multiplier = maxf(0.0, amount - 0.22) * 1.7


func _material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.85
	return mat


func _box(key: String, at: Vector3, size: Vector3, material: Material, angles := Vector3.ZERO) -> void:
	if not _groups.has(key):
		_groups[key] = {"material": material, "transforms": []}
	var group: Dictionary = _groups[key]
	var transforms: Array = group["transforms"]
	transforms.append(Transform3D(Basis.from_euler(angles) * Basis.from_scale(size), at))


func _window(at: Vector3, trim: Material, yaw := 0.0) -> void:
	var basis := Basis(Vector3.UP, yaw)
	_box("glass", at, Vector3(0.9, 0.9, 0.06), window_material, Vector3(0, yaw, 0))
	for x in [-0.50, 0.0, 0.50]:
		_box("trim", at + basis * Vector3(float(x), 0, 0.04), Vector3(0.065, 1.05, 0.08), trim, Vector3(0, yaw, 0))
	for y in [-0.50, 0.0, 0.50]:
		_box("trim", at + basis * Vector3(0, float(y), 0.04), Vector3(1.05, 0.065, 0.08), trim, Vector3(0, yaw, 0))


func _gable(x: float, material: StandardMaterial3D) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var normal := Vector3.RIGHT if x > 0.0 else Vector3.LEFT
	var points := [Vector3(x, EAVES, -DEPTH * 0.5), Vector3(x, RIDGE, 0), Vector3(x, EAVES, DEPTH * 0.5)]
	if x < 0.0:
		points.reverse()
	for point in points:
		surface.set_normal(normal)
		surface.add_vertex(point)
	var visual := MeshInstance3D.new()
	visual.mesh = surface.commit()
	visual.material_override = material
	add_child(visual)


func _finish() -> void:
	for key in _groups:
		var group: Dictionary = _groups[key]
		var transforms: Array = group["transforms"]
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = _cube
		multi.instance_count = transforms.size()
		for i in range(transforms.size()):
			multi.set_instance_transform(i, transforms[i])
		var visual := MultiMeshInstance3D.new()
		visual.name = str(key)
		visual.multimesh = multi
		visual.material_override = group["material"]
		add_child(visual)
	_groups.clear()
