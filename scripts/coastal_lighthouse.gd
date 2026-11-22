class_name CoastalLighthouse
extends RefCounted
## Стилизованная деревянная башня с галереей по мотивам маяков Ньюфаундленда.
## Это не обмер конкретного памятника; свет и игровая логика принадлежат BoatMain.

static func build(parent: Node3D, outward: Vector2) -> void:
	var visual := Node3D.new()
	visual.name = "LighthouseArchitecture"
	# Вход направлен в глубь острова, а луч остаётся в мировом направлении.
	visual.rotation.y = atan2(-outward.x, -outward.y)
	parent.add_child(visual)
	var st := GiltShapes.begin()
	var white := Color("d3cfc1")
	var trim := Color("e6dfce")
	var red := Color("984b3e")
	var iron := Color("303b40")
	var stone := Color("545a59")
	# Цоколь и замкнутый сужающийся ствол, не ступенчатые цилиндры.
	GiltShapes.box(st, Vector3(0, -0.15, 0), Vector3(5.5, 1.0, 5.5), stone)
	var bottom := 2.52
	var top := 1.43
	var low := 0.35
	var high := 9.0
	var inside := Vector3(0, 4.5, 0)
	for side in range(4):
		var a := float(side) * PI * 0.5 + PI * 0.25
		var b := float(side + 1) * PI * 0.5 + PI * 0.25
		var v1 := Vector3(cos(a) * bottom * sqrt(2.0), low, sin(a) * bottom * sqrt(2.0))
		var v2 := Vector3(cos(b) * bottom * sqrt(2.0), low, sin(b) * bottom * sqrt(2.0))
		var v3 := Vector3(cos(b) * top * sqrt(2.0), high, sin(b) * top * sqrt(2.0))
		var v4 := Vector3(cos(a) * top * sqrt(2.0), high, sin(a) * top * sqrt(2.0))
		GiltShapes.out_quad(st, v1, v2, v3, v4, white, inside)
	# Угловые доски повторяют наклон стен.
	for x in [-1.0, 1.0]:
		for z in [-1.0, 1.0]:
			GiltShapes.beam(st, Vector3(x * bottom, low, z * bottom),
				Vector3(x * top, high, z * top), 0.12, trim)
	# Горизонтальные стыки обшивки — на плоскости каждой стороны.
	for row in range(1, 28):
		var t := float(row) / 28.0
		var y := lerpf(low, high, t)
		var r := lerpf(bottom, top, t) + 0.012
		for side in [-1.0, 1.0]:
			GiltShapes.beam(st, Vector3(-r, y, side * r), Vector3(r, y, side * r), 0.024, white.darkened(0.12))
			GiltShapes.beam(st, Vector3(side * r, y, -r), Vector3(side * r, y, r), 0.024, white.darkened(0.12))
	# Вход с навесом и окно на той же наклонной стене.
	GiltShapes.box(st, Vector3(0, 1.48, 2.43), Vector3(1.12, 2.24, 0.13), trim)
	GiltShapes.box(st, Vector3(0, 1.47, 2.51), Vector3(0.91, 2.01, 0.06), red.darkened(0.24))
	GiltShapes.gable_roof(st, Vector3(0, 2.55, 2.40), 1.38, 0.48, 0.0, 0.27, red, red.darkened(0.2), trim, 0.05)
	GiltShapes.box(st, Vector3(0, 4.85, 1.97), Vector3(0.83, 1.13, 0.12), trim)
	GiltShapes.box(st, Vector3(0, 4.85, 2.05), Vector3(0.62, 0.90, 0.05), iron)
	GiltShapes.box(st, Vector3(0, 4.85, 2.08), Vector3(0.05, 0.90, 0.04), trim)
	GiltShapes.box(st, Vector3(0, 4.85, 2.08), Vector3(0.62, 0.05, 0.04), trim)
	# Галерея с кронштейнами и ограждением, квадратная фонарная камера.
	GiltShapes.box(st, Vector3(0, 9.10, 0), Vector3(3.9, 0.23, 3.9), trim)
	for side in [-1.0, 1.0]:
		for n in [-1.15, 1.15]:
			GiltShapes.beam(st, Vector3(n, 8.45, side * 1.50), Vector3(n, 8.98, side * 1.91), 0.10, iron)
			GiltShapes.beam(st, Vector3(side * 1.50, 8.45, n), Vector3(side * 1.91, 8.98, n), 0.10, iron)
		for n in [-1.82, 0.0, 1.82]:
			GiltShapes.beam(st, Vector3(n, 9.22, side * 1.82), Vector3(n, 10.03, side * 1.82), 0.055, red)
			GiltShapes.beam(st, Vector3(side * 1.82, 9.22, n), Vector3(side * 1.82, 10.03, n), 0.055, red)
		for y in [9.62, 10.03]:
			GiltShapes.beam(st, Vector3(-1.82, y, side * 1.82), Vector3(1.82, y, side * 1.82), 0.055, red)
			GiltShapes.beam(st, Vector3(side * 1.82, y, -1.82), Vector3(side * 1.82, y, 1.82), 0.055, red)
		for n in [-1.06, 1.06]:
			GiltShapes.beam(st, Vector3(n, 9.42, side * 1.06), Vector3(n, 11.07, side * 1.06), 0.10, iron)
	GiltShapes.box(st, Vector3(0, 9.43, 0), Vector3(2.4, 0.18, 2.4), red)
	GiltShapes.box(st, Vector3(0, 11.06, 0), Vector3(2.5, 0.14, 2.5), red)
	GiltShapes.spire(st, Vector3(0, 11.12, 0), 1.92, 0.85, red, 4, PI * 0.25)
	GiltShapes.cylinder(st, Vector3(0, 12.1, 0), 0.14, 0.10, 0.27, iron, 8)
	var mesh := MeshInstance3D.new()
	mesh.name = "TimberTowerAndGallery"
	mesh.mesh = GiltShapes.finish(st)
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.82
	mesh.material_override = material
	visual.add_child(mesh)
