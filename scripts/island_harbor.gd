class_name IslandHarbor
extends Node3D
## Mooring controller; HarborArchitecture builds the adjacent fishing station.
const DECK_Y := 1.35
const MOOR_RANGE := 11.0
var main: BoatMain
var moored := false
var _ropes: Array[MeshInstance3D] = []
var _entrance_buoys: Array[Node3D] = []
var _buoy_materials: Array[StandardMaterial3D] = []
var _time := 0.0
var _jetty_lamp: OmniLight3D
var _porch_lamp: OmniLight3D
var _architecture: HarborArchitecture


func setup(game: BoatMain) -> void:
	main = game
	name = "QuietBayHarbor"
	_architecture = HarborArchitecture.new()
	add_child(_architecture)
	_architecture.setup(main)
	var dark := main._mat(Color("343c39"), 0.12, 0.0, 0.86)
	var lamp_mat := main._mat(Color("edc796"), 0.0, 0.8, 0.3)
	main._add_cyl(self, Vector3(116.0, 3.15, -30.0), 0.16, 0.16, 0.3, lamp_mat)
	_jetty_lamp = OmniLight3D.new()
	_jetty_lamp.position = Vector3(116.0, 3.15, -30.0)
	_jetty_lamp.light_color = Color("edc796")
	_jetty_lamp.light_energy = 0.05
	_jetty_lamp.omni_range = 11.0
	_jetty_lamp.light_volumetric_fog_energy = 0.15
	add_child(_jetty_lamp)
	main._add_cyl(self, Vector3(124.0, 3.8, -45.4), 0.12, 0.12, 0.22, lamp_mat)
	_porch_lamp = OmniLight3D.new()
	_porch_lamp.position = Vector3(124.0, 3.8, -45.4)
	_porch_lamp.light_color = Color("edc796")
	_porch_lamp.omni_range = 7.0
	_porch_lamp.light_volumetric_fog_energy = 0.1
	add_child(_porch_lamp)
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
		for rect in [IslandLayout.PIER_RECT, IslandLayout.HARBOR_APRON, IslandLayout.HARBOR_LINK]:
			var r: Rect2 = rect
			var closest := Vector2(clampf(p.x, r.position.x, r.end.x), clampf(p.y, r.position.y, r.end.y))
			if p.distance_squared_to(closest) < radius * radius:
				return true
	return false


func _process(delta: float) -> void:
	if main == null:
		return
	_time += delta
	_jetty_lamp.light_energy = 0.05 + 0.4 * main.night01
	_porch_lamp.light_energy = 0.03 + 0.35 * main.night01
	_architecture.windows.emission_energy_multiplier = 0.03 + 0.4 * main.night01
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
