class_name IslandHarbor
extends Node3D
## A real berth, with a reserved shore-side service terrace. No fake shop/NPC UI.
const DECK_Y := 1.35
const MOOR_RANGE := 11.0
var main: BoatMain
var moored := false
var _ropes: Array[MeshInstance3D] = []
var _entrance_buoys: Array[Node3D] = []
var _buoy_materials: Array[StandardMaterial3D] = []
var _time := 0.0
var _jetty_lamp: OmniLight3D


func _box(at: Vector3, dimensions: Vector3, material: Material, parent: Node3D = null) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	node.position = at
	if parent == null:
		parent = self
	parent.add_child(node)
	return node


func setup(game: BoatMain) -> void:
	main = game
	name = "QuietBayHarbor"
	var wood := main._mat(Color("66503e"), 0.0, 0.0, 0.88)
	var dark := main._mat(Color("343c39"), 0.12, 0.0, 0.86)
	var wall := main._mat(Color("a29c80"), 0.0, 0.0, 0.92)
	var roof := main._mat(Color("435b58"), 0.18, 0.0, 0.82)
	# West-facing jetty, parallel to the approach channel, not a wall across it.
	_box(Vector3(134.5, DECK_Y - 0.16, -30.0), Vector3(51.0, 0.32, 6.0), wood)
	for x in [111.0, 123.0, 135.0, 147.0, 157.0]:
		for z in [-32.5, -27.5]:
			var bed: float = main.coast.ground_height(float(x), float(z)) - 0.8
			var height: float = DECK_Y + 0.5 - bed
			main._add_cyl(self, Vector3(float(x), bed + height * 0.5, float(z)), 0.22, 0.28, height, dark)
	main._add_cyl(self, Vector3(116.0, 2.2, -30.0), 0.07, 0.09, 1.7, dark)
	var lamp_mat := main._mat(Color("edc796"), 0.0, 0.8, 0.3)
	main._add_cyl(self, Vector3(116.0, 3.15, -30.0), 0.16, 0.16, 0.3, lamp_mat)
	_jetty_lamp = OmniLight3D.new()
	_jetty_lamp.position = Vector3(116.0, 3.15, -30.0)
	_jetty_lamp.light_color = Color("edc796")
	_jetty_lamp.light_energy = 0.05
	_jetty_lamp.omni_range = 11.0
	_jetty_lamp.light_volumetric_fog_energy = 0.15
	add_child(_jetty_lamp)
	# Short rising shore ramp to the 4 m service terrace.
	var ramp := _box(Vector3(164.5, 2.675, -30.0), Vector3(25.0, 0.22, 4.0), wood)
	ramp.rotation.z = atan2(2.65, 25.0)
	# Modest storehouse; its plot and neighbouring clearing can host NPCs/trade later.
	_box(Vector3(194.0, 4.1, -30.0), Vector3(11.0, 0.2, 9.0), dark)
	_box(Vector3(194.0, 6.4, -30.0), Vector3(10.0, 4.4, 8.0), wall)
	for side in [-1.0, 1.0]:
		var roof_side := _box(Vector3(194.0, 9.1, -30.0 + float(side) * 2.15), Vector3(12.0, 0.22, 4.9), roof)
		roof_side.rotation.x = float(side) * 0.44
	_box(Vector3(188.94, 5.5, -30.0), Vector3(0.12, 2.6, 1.6), wood)
	for i in range(3):
		_box(Vector3(180.0 + float(i) * 1.4, 4.55, -35.0), Vector3(1.1, 1.1, 1.1), wood)
	var sign := Label3D.new()
	sign.text = "ТИХАЯ БУХТА\nПРИЧАЛ"
	sign.font_size = 48
	sign.pixel_size = 0.035
	sign.position = Vector3(188.8, 8.0, -30.0)
	sign.rotation.y = -PI * 0.5
	add_child(sign)
	# IALA A: entering from the west, red to port (north), green to starboard.
	for i in range(2):
		var buoy := Node3D.new()
		buoy.position = Vector3(-62.0, 0.0, -55.0 + float(i) * 50.0)
		add_child(buoy)
		main._add_cyl(buoy, Vector3(0.0, 0.25, 0.0), 0.35, 0.65, 0.9, dark)
		main._add_cyl(buoy, Vector3(0.0, 1.1, 0.0), 0.06, 0.07, 1.2, dark)
		var col := Color("ef6857") if i == 0 else Color("77cda5")
		var lens := main._mat(col, 0.0, 0.7, 0.3)
		main._add_cyl(buoy, Vector3(0.0, 1.8, 0.0), 0.14, 0.14, 0.23, lens)
		_entrance_buoys.append(buoy)
		_buoy_materials.append(lens)
	var rope_mat := main._mat(Color("4c473c"), 0.0, 0.0, 0.95)
	for i in range(2):
		var rope := main._add_cyl(self, Vector3.ZERO, 0.035, 0.035, 1.0, rope_mat, Vector3.ZERO, 6)
		rope.visible = false
		_ropes.append(rope)


func near_berth() -> bool:
	if main == null or main.boat == null:
		return false
	var at := Vector2(main.boat.global_position.x, main.boat.global_position.z)
	return at.distance_to(IslandLayout.BERTH) <= MOOR_RANGE


func interact() -> void:
	if moored:
		moored = false
		main.announce("ШВАРТОВЫ ОТДАНЫ. МОЖНО ВЫХОДИТЬ ИЗ БУХТЫ.")
		return
	if not near_berth():
		return
	if absf(main.boat.speed) > 1.2:
		main.announce("ДЛЯ ШВАРТОВКИ СБРОСЬТЕ СКОРОСТЬ ДО 1.2 М/С.")
		return
	# Explicit docking action only: align in the checked berth, never via map/camera.
	var boat := main.boat
	boat.global_position.x = IslandLayout.BERTH.x
	boat.global_position.z = IslandLayout.BERTH.y
	boat.rotation.y = PI * 0.5
	boat.speed = 0.0
	if boat.has_trailer:
		boat.set_trailer_enabled(true)
	boat._reset_trail(IslandLayout.BERTH)
	boat.reset_physics_interpolation()
	moored = true
	main.announce("ТИХАЯ БУХТА: ПРИШВАРТОВАНЫ. [E] — ОТЧАЛИТЬ. БЕРЕГ ОСТАВЛЕН ПОД БУДУЩИЕ СЛУЖБЫ.")


func blocks_hull(at: Vector2, yaw: float, radius: float = 1.7, half_length: float = 4.4) -> bool:
	var heading := Vector2(-sin(yaw), -cos(yaw))
	for i in range(3):
		var p := at + heading * (float(i - 1) * half_length)
		var closest := Vector2(clampf(p.x, IslandLayout.PIER_RECT.position.x, IslandLayout.PIER_RECT.end.x),
			clampf(p.y, IslandLayout.PIER_RECT.position.y, IslandLayout.PIER_RECT.end.y))
		if p.distance_squared_to(closest) < radius * radius:
			return true
	return false


func _process(delta: float) -> void:
	if main == null:
		return
	_time += delta
	_jetty_lamp.light_energy = 0.05 + 0.4 * main.night01
	for i in range(_entrance_buoys.size()):
		var buoy := _entrance_buoys[i]
		buoy.position.y = main.water.surface_height(buoy.position.x, buoy.position.z)
		_buoy_materials[i].emission_energy_multiplier = 0.7 * (0.6 + 0.4 * sin(_time * 2.2 + float(i) * PI))
	for i in range(_ropes.size()):
		var rope := _ropes[i]
		rope.visible = moored
		if not moored:
			continue
		var anchor := Vector3(111.0 + float(i) * 11.0, DECK_Y + 0.35, -33.0)
		var on_boat := main.boat.global_position + Vector3(-3.5 + float(i) * 7.0, 1.05, 1.5)
		var direction := on_boat - anchor
		rope.position = (on_boat + anchor) * 0.5
		rope.quaternion = Quaternion(Vector3.UP, direction.normalized())
		rope.scale = Vector3(1.0, direction.length(), 1.0)
