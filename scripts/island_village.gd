class_name IslandVillage
extends Node3D
## A small working village behind the harbour. Each house is its own scene so
## Blender replacements can be assigned without moving the road or collision.
const COTTAGE := preload("res://scenes/village/cottage.tscn")
const HOUSE_SITES := [
	{"name": "CottageWest", "at": Vector2(182.0, -38.5), "yaw": 0.0, "style": 0},
	{"name": "CottageNorth", "at": Vector2(195.0, -38.8), "yaw": 0.0, "style": 1},
	{"name": "CottageEast", "at": Vector2(208.0, -39.0), "yaw": 0.0, "style": 2},
	{"name": "CottageSouthWest", "at": Vector2(188.0, -21.4), "yaw": PI, "style": 3},
	{"name": "CottageSouthEast", "at": Vector2(203.0, -21.2), "yaw": PI, "style": 4},
]
const LANE := [Vector2(176.7, -30.0), Vector2(184.0, -30.0), Vector2(195.0, -30.0),
	Vector2(205.0, -30.1), Vector2(215.0, -31.1), Vector2(224.0, -33.5)]

var main: BoatMain
var cottages: Array[VillageCottage] = []
var _lamps: Array[OmniLight3D] = []
var _day_night := -1.0


func setup(owner_main: BoatMain) -> void:
	main = owner_main
	name = "HarborVillage"
	_build_roads()
	for site in HOUSE_SITES:
		_build_house(site)
	_build_details()
	set_night(main.night01)


func _build_house(site: Dictionary) -> void:
	var at: Vector2 = site["at"]
	var yaw: float = site["yaw"]
	var rotation_basis := Basis(Vector3.UP, yaw)
	var min_ground := INF
	var max_ground := -INF
	# Sample all corners before placing the house; no sinking walls or stilts in mid-air.
	for x in [-VillageCottage.WIDTH * 0.5, VillageCottage.WIDTH * 0.5]:
		for z in [-VillageCottage.DEPTH * 0.5, VillageCottage.DEPTH * 0.5]:
			var p := Vector3(at.x, 0.0, at.y) + rotation_basis * Vector3(float(x), 0.0, float(z))
			var ground := main.coast.ground_height(p.x, p.z)
			min_ground = minf(min_ground, ground)
			max_ground = maxf(max_ground, ground)
	var floor_height := max_ground + 0.10
	var cottage := COTTAGE.instantiate() as VillageCottage
	cottage.name = site["name"]
	cottage.position = Vector3(at.x, floor_height, at.y)
	cottage.rotation.y = yaw
	add_child(cottage)
	cottage.build(int(site["style"]), min_ground - floor_height)
	cottages.append(cottage)


func _build_roads() -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("c1ae88")
	material.roughness = 1.0
	material.vertex_color_use_as_albedo = true
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Unpaved lane joins the pier's boardwalk, bends gently into the settlement.
	_road_strip(surface, LANE, 3.0)
	# Footpaths terminate at individual doors instead of intersecting buildings.
	for site in HOUSE_SITES:
		var at: Vector2 = site["at"]
		var front_z := at.y + (VillageCottage.DEPTH * 0.5 + 0.62) * (1.0 if float(site["yaw"]) == 0.0 else -1.0)
		_road_strip(surface, [Vector2(at.x, -30.0), Vector2(at.x, front_z)], 1.1)
	var road := MeshInstance3D.new()
	road.name = "GroundedUnpavedLane"
	road.mesh = surface.commit()
	road.material_override = material
	road.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(road)


func _road_strip(surface: SurfaceTool, points: Array, width: float) -> void:
	# Short segments follow the existing terrain; no large floating rectangle.
	for i in range(points.size() - 1):
		var a: Vector2 = points[i]
		var b: Vector2 = points[i + 1]
		var forward := (b - a).normalized()
		var side := Vector2(-forward.y, forward.x)
		var steps := maxi(1, int(ceil(a.distance_to(b) / 1.0)))
		for j in range(steps):
			var p0 := a.lerp(b, float(j) / float(steps))
			var p1 := a.lerp(b, float(j + 1) / float(steps))
			# Three bands give the edges a subdued, irregular sandy transition.
			for band in range(3):
				var d0 := lerpf(-width * 0.5, width * 0.5, float(band) / 3.0)
				var d1 := lerpf(-width * 0.5, width * 0.5, float(band + 1) / 3.0)
				var c0 := Color("888e70") if band == 0 else Color("c7b58f")
				var c1 := Color("888e70") if band == 2 else Color("c7b58f")
				_road_triangle(surface, p0 + side * d0, p1 + side * d0, p1 + side * d1, c0, c0, c1)
				_road_triangle(surface, p0 + side * d0, p1 + side * d1, p0 + side * d1, c0, c1, c1)


func _road_triangle(surface: SurfaceTool, a: Vector2, b: Vector2, c: Vector2,
		ca: Color, cb: Color, cc: Color) -> void:
	# Godot's front face is clockwise when viewed from above.
	for entry in [[a, ca], [b, cb], [c, cc]]:
		var p: Vector2 = entry[0]
		surface.set_color(entry[1])
		surface.set_normal(main.coast.ground_normal(p.x, p.y))
		surface.add_vertex(Vector3(p.x, main.coast.ground_height(p.x, p.y) + 0.055, p.y))


func _build_details() -> void:
	var wood := main._mat(Color("665e4c"), 0.0, 0.0, 0.90)
	var rope := main._mat(Color("b6aa89"), 0.0, 0.0, 0.95)
	var crate := main._mat(Color("82775e"), 0.0, 0.0, 0.90)
	var cloth := main._mat(Color("d7d3bb"), 0.0, 0.0, 0.95)
	# A simple drying line and fish boxes make the buildings feel used.
	var ground := main.coast.ground_height(199.0, -43.3)
	for x in [197.4, 200.6]:
		main._add_cyl(self, Vector3(float(x), ground + 1.05, -43.3), 0.055, 0.055, 2.1, wood)
	_detail_box(Vector3(199.0, ground + 2.0, -43.3), Vector3(3.25, 0.025, 0.025), rope)
	for i in range(3):
		var sheet := _detail_box(Vector3(198.0 + float(i) * 0.9, ground + 1.65, -43.3),
			Vector3(0.58, 0.68, 0.035), cloth)
		sheet.rotation.z = (float(i) - 1.0) * 0.04
	for p in [Vector2(179.8, -35.0), Vector2(211.0, -35.3), Vector2(190.0, -25.5)]:
		var h := main.coast.ground_height(p.x, p.y)
		_detail_box(Vector3(p.x, h + 0.30, p.y), Vector3(0.75, 0.60, 0.65), crate)
	# Two restrained lamps, switched with the same time of day as the harbour.
	for p in [Vector2(182.4, -35.9), Vector2(203.4, -24.0)]:
		var h := main.coast.ground_height(p.x, p.y)
		var lamp := OmniLight3D.new()
		lamp.position = Vector3(p.x, h + 2.0, p.y)
		lamp.light_color = Color("f0c68a")
		lamp.omni_range = 5.0
		lamp.shadow_enabled = false
		add_child(lamp)
		_lamps.append(lamp)


func _detail_box(at: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	visual.mesh = mesh
	visual.material_override = material
	visual.position = at
	add_child(visual)
	return visual


func set_night(amount: float) -> void:
	_day_night = amount
	for house in cottages:
		house.set_night(amount)
	for lamp in _lamps:
		lamp.light_energy = maxf(0.0, amount - 0.25) * 0.40


func _process(_delta: float) -> void:
	if main != null and absf(main.night01 - _day_night) > 0.015:
		set_night(main.night01)
