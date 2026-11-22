class_name IslandVillage
extends Node3D
## Небольшая гавань: открытый съезд, два ряда домов и чистые проходы.
## Дом стоит отдельно, в каждом свой житель; декор не перекрывает улицу.

const HOUSE_SITES := [
	{"name": "CottageNetmaker", "at": Vector2(171.2, -38.0), "yaw": PI * 0.5,
		"plan": "netloft", "style": 0, "floor": 4.10, "resident": "netmaker"},
	{"name": "CottageKeeper", "at": Vector2(183.8, -37.6), "yaw": -PI * 0.5,
		"plan": "keeper", "style": 1, "floor": 4.10, "resident": "keeper"},
	{"name": "CottageTavern", "at": Vector2(171.2, -23.0), "yaw": PI * 0.5,
		"plan": "tavern", "style": 2, "floor": 4.10, "resident": "tavern"},
	{"name": "CottageChandler", "at": Vector2(183.8, -28.3), "yaw": -PI * 0.5,
		"plan": "chandler", "style": 5, "floor": 4.10, "resident": "chandler"},
	{"name": "CottageSalt", "at": Vector2(171.2, -13.6), "yaw": PI * 0.5,
		"plan": "salthouse", "style": 3, "floor": 4.10, "resident": "saltmaker"},
	{"name": "CottageSmithy", "at": Vector2(183.8, -19.3), "yaw": -PI * 0.5,
		"plan": "smithy", "style": 6, "floor": 4.10, "resident": "smith"},
	{"name": "CottagePilot", "at": Vector2(183.8, -11.2), "yaw": -PI * 0.5,
		"plan": "pilot", "style": 7, "floor": 4.10, "resident": "pilot"},
	{"name": "CottageParsonage", "at": Vector2(195.8, -30.6), "yaw": -PI * 0.5,
		"plan": "parsonage", "style": 4, "floor": 4.20, "resident": "parson"},
]

## Город стоит на едином каменном основании, а не на лоскутках рельефа.
## Плита накрывает весь квартал; улицы — прямые полосы поверх неё.
const BASE_RECT := Rect2(168.45, -43.8, 42.05, 39.6)
const BASE_Y := 4.04
const STREET_Y := 4.065
## Прямые улицы: главная между фасадами и задний проезд.
const MAIN_STREET := Rect2(175.0, -40.8, 4.6, 33.8)
const BACK_STREET := Rect2(188.5, -40.4, 3.0, 32.6)
const PIER_Y := 1.42
const QUAY_Y := VillageProps.QUAY_Y
const BRIDGE_START := Vector3(159.8, PIER_Y, -30.0)
const BRIDGE_FINISH := Vector3(168.4, QUAY_Y, -30.0)

var main: BoatMain
var cottages: Array[GiltHouse] = []
var props: VillageProps
var _lamps: Array[OmniLight3D] = []
var _lamp_strength: Array[float] = []
var _day_night := -1.0
var _gulls: Array[Dictionary] = []
var _time := 0.0


func setup(owner_main: BoatMain) -> void:
	main = owner_main
	name = "HarborVillage"
	props = VillageProps.new()
	props.setup(main, self)
	_build_quay()
	_build_bridge()
	_build_foundation()
	for site in HOUSE_SITES:
		_build_house(site)
	_build_details()
	_build_harbour_life()
	_build_lighting()
	set_night(main.night01)


## Высота мостовой: на плите — её верх, за плитой — рельеф.
func _deck_height(x: float, z: float) -> float:
	if BASE_RECT.has_point(Vector2(x, z)):
		return BASE_Y + 0.02
	return main.coast.ground_height(x, z) + 0.02


# --- Набережная -------------------------------------------------------------

## Каменная терраса над водой. Высота QUAY_Y, кромка — VillageProps.quay_edge_x.
## Под настилом остаётся старый склон: его не видно, потому что набережная
## действительно стоит на массивной кладке, а не «накрывает» рельеф листом.
func _build_quay() -> void:
	props.begin()
	props.quay()
	props.commit(self)
	# Контрфорсы под набережной: с воды стена читается кладкой, а не экраном.
	var support := GiltShapes.begin()
	for z in [-40.0, -37.0, -34.0, -23.0, -20.0, -17.0, -14.0, -11.0, -8.0]:
		var edge := VillageProps.quay_edge_x(z)
		GiltShapes.box(support, Vector3(edge + 0.60, 1.55, z), Vector3(0.55, 4.9, 0.70),
			Color("34333b"))
		GiltShapes.box(support, Vector3(edge + 0.60, QUAY_Y - 0.05, z),
			Vector3(0.80, 0.22, 0.90), Color("666068"))
	var mesh := MeshInstance3D.new()
	mesh.name = "QuayButtresses"
	mesh.mesh = support.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.93
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.material_override = mat
	add_child(mesh)


# --- Съезд с пирса ----------------------------------------------------------

## Настил съезда строит HarborArchitecture (он же пирс); здесь — ограда,
## каменные опоры, ворота и фонари. Съезд поднимается на набережную
## в вырезе стены, поэтому не пробивает её и не висит над водой.
func _build_bridge() -> void:
	# Сам наклонный настил строит HarborArchitecture. Боковые стены съезда
	# уже построены вместе с набережной; повторные перила/опоры здесь бы
	# пересекались с ними. Открытая площадка соединяет настил с улицей.
	var surface := GiltShapes.begin()
	GiltShapes.box(surface, Vector3(169.0, QUAY_Y - 0.05, -30.0),
		Vector3(1.25, 0.12, 3.5), Color("625c62"))
	var mesh := MeshInstance3D.new()
	mesh.name = "PierBridge"
	mesh.mesh = surface.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.92
	mesh.material_override = mat
	add_child(mesh)


static func smoothstep01(t: float) -> float:
	var c := clampf(t, 0.0, 1.0)
	return c * c * (3.0 - 2.0 * c)


# --- Дома -------------------------------------------------------------------

func _build_house(site: Dictionary) -> void:
	var at: Vector2 = site["at"]
	var yaw: float = site["yaw"]
	# Весь квартал стоит на одной плите: пол дома — плоскость плиты плюс
	# слой кладки, без подгонки под рельеф под каждым углом.
	var floor_height := BASE_Y + 0.06
	if site.has("floor"):
		floor_height = maxf(float(site["floor"]), floor_height)
	var house := GiltHouse.new()
	house.name = site["name"]
	house.position = Vector3(at.x, floor_height, at.y)
	house.rotation.y = yaw
	add_child(house)
	house.build_site(site, BASE_Y - floor_height - 0.25)
	cottages.append(house)


func _build_foundation() -> void:
	var slab := SurfaceTool.new()
	slab.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Тёмный раствор под плиткой: швы читаются, а трава не проступает.
	_flat_quad(slab, BASE_RECT, BASE_Y - 0.008, Color("2a2832"))
	var tile := 2.0
	var ix := 0
	var x := BASE_RECT.position.x
	while x < BASE_RECT.end.x - 0.001:
		var x1 := minf(x + tile, BASE_RECT.end.x)
		var iz := 0
		var z := BASE_RECT.position.y
		while z < BASE_RECT.end.y - 0.001:
			var z1 := minf(z + tile, BASE_RECT.end.y)
			var tone := Color("625d67") if (ix + iz) % 2 == 0 else Color("56515b")
			if (ix * 3 + iz * 5) % 9 == 0:
				tone = Color("4a4650")
			_flat_quad(slab, Rect2(x + 0.016, z + 0.016, x1 - x - 0.032, z1 - z - 0.032),
				BASE_Y, tone)
			z = z1
			iz += 1
		x = x1
		ix += 1
	var slab_mesh := MeshInstance3D.new()
	slab_mesh.name = "VillageBase"
	slab_mesh.mesh = slab.commit()
	var slab_mat := StandardMaterial3D.new()
	slab_mat.vertex_color_use_as_albedo = true
	slab_mat.roughness = 0.95
	slab_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	slab_mesh.material_override = slab_mat
	slab_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(slab_mesh)
	# Кордон по краю и каменный подбой: квартал стоит на террасе.
	var edge := GiltShapes.begin()
	var lo := BASE_RECT.position
	var hi := BASE_RECT.end
	var cx := (lo.x + hi.x) * 0.5
	var cz := (lo.y + hi.y) * 0.5
	for z in [lo.y, hi.y]:
		GiltShapes.box(edge, Vector3(cx, BASE_Y + 0.045, z),
			Vector3(hi.x - lo.x + 0.5, 0.09, 0.5), Color("7b747d"))
		var low := minf(main.coast.ground_height(lo.x, z), main.coast.ground_height(hi.x, z))
		low = minf(low, main.coast.ground_height(cx, z)) - 0.35
		var h := maxf(0.40, BASE_Y - low)
		GiltShapes.box(edge, Vector3(cx, BASE_Y - h * 0.5, z),
			Vector3(hi.x - lo.x + 0.4, h, 0.34), Color("3d3943"))
	GiltShapes.box(edge, Vector3(hi.x, BASE_Y + 0.045, cz),
		Vector3(0.5, 0.09, hi.y - lo.y), Color("7b747d"))
	var east_low := minf(main.coast.ground_height(hi.x, lo.y), main.coast.ground_height(hi.x, hi.y))
	east_low = minf(east_low, main.coast.ground_height(hi.x, cz)) - 0.35
	var east_h := maxf(0.40, BASE_Y - east_low)
	GiltShapes.box(edge, Vector3(hi.x, BASE_Y - east_h * 0.5, cz),
		Vector3(0.34, east_h, hi.y - lo.y), Color("3d3943"))
	# Западный край плиты: только вне проёма съезда, иначе подбой закрыл бы
	# арку портала изнутри.
	var seg_a := Vector2(lo.y, VillageProps.RAMP_WELL.position.y)
	var seg_b := Vector2(VillageProps.RAMP_WELL.end.y, hi.y)
	for n in range(2):
		var seg: Vector2 = seg_a if n == 0 else seg_b
		var seg_mid := (seg.x + seg.y) * 0.5
		var west_low := minf(main.coast.ground_height(lo.x, seg.x),
			main.coast.ground_height(lo.x, seg.y)) - 0.35
		var west_h := maxf(0.40, BASE_Y - west_low)
		GiltShapes.box(edge, Vector3(lo.x, BASE_Y - west_h * 0.5, seg_mid),
			Vector3(0.34, west_h, seg.y - seg.x), Color("3d3943"))
	var edge_mesh := MeshInstance3D.new()
	edge_mesh.name = "VillageBaseEdge"
	edge_mesh.mesh = edge.commit()
	var edge_mat := StandardMaterial3D.new()
	edge_mat.vertex_color_use_as_albedo = true
	edge_mat.roughness = 0.94
	edge_mesh.material_override = edge_mat
	edge_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(edge_mesh)
	_build_streets()


func _build_streets() -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for rect in [MAIN_STREET, BACK_STREET]:
		var street: Rect2 = rect
		_flat_quad(surface, street, STREET_Y, Color("38353f"))
		# Кромки чуть светлее, по центру — вытертый шов.
		_flat_quad(surface, Rect2(street.position.x, street.position.y, 0.18, street.size.y),
			STREET_Y + 0.004, Color("7a737d"))
		_flat_quad(surface, Rect2(street.end.x - 0.18, street.position.y, 0.18, street.size.y),
			STREET_Y + 0.004, Color("7a737d"))
		_flat_quad(surface, Rect2(street.get_center().x - 0.035, street.position.y, 0.07, street.size.y),
			STREET_Y + 0.003, Color("26242d"))
	var mesh := MeshInstance3D.new()
	mesh.name = "VillageStreets"
	mesh.mesh = surface.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.93
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.material_override = mat
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh)


## Плоский прямоугольник на общей высоте: плита, улица, кромка.
func _flat_quad(surface: SurfaceTool, rect: Rect2, y: float, tone: Color) -> void:
	var a := Vector2(rect.position.x, rect.position.y)
	var b := Vector2(rect.end.x, rect.position.y)
	var c := Vector2(rect.end.x, rect.end.y)
	var d := Vector2(rect.position.x, rect.end.y)
	for p in [a, b, c, a, c, d]:
		surface.set_color(tone)
		surface.set_normal(Vector3.UP)
		surface.add_vertex(Vector3(p.x, y, p.y))


## Небольшое число фонарей на свободных участках набережной.
func _build_details() -> void:
	# Три фонаря на открытой набережной, вдали от фасадов и съезда.
	var details := Node3D.new()
	details.name = "VillageLife"
	add_child(details)
	props.begin()
	for p in [Vector2(157.0, -38.0), Vector2(157.0, -22.5), Vector2(157.0, -10.0)]:
		props.simple_lamp(Vector3(p.x, QUAY_Y - 0.02, p.y))
	props.commit(details)


func _build_harbour_life() -> void:
	# Чайки: шесть силуэтов над бухтой, круги разные.
	for i in range(6):
		_gulls.append(_make_gull(i))


func _make_gull(index: int) -> Dictionary:
	var root := Node3D.new()
	root.name = "Gull%d" % index
	add_child(root)
	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = Color("d8d2c4")
	body_mat.roughness = 0.85
	var tip_mat := StandardMaterial3D.new()
	tip_mat.albedo_color = Color("3a3a42")
	body_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	tip_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var body := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.075
	capsule.height = 0.40
	capsule.radial_segments = 6
	body.mesh = capsule
	body.material_override = body_mat
	body.rotation.x = PI * 0.5
	root.add_child(body)
	var wings: Array[Node3D] = []
	for side in [-1.0, 1.0]:
		var pivot := Node3D.new()
		pivot.position = Vector3(float(side) * 0.04, 0.02, 0.0)
		root.add_child(pivot)
		var wing := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.44, 0.02, 0.15)
		wing.mesh = box
		wing.position = Vector3(float(side) * 0.22, 0.0, 0.0)
		wing.material_override = body_mat
		pivot.add_child(wing)
		var tip := MeshInstance3D.new()
		var tip_box := BoxMesh.new()
		tip_box.size = Vector3(0.16, 0.022, 0.12)
		tip.mesh = tip_box
		tip.position = Vector3(float(side) * 0.50, 0.0, 0.0)
		tip.material_override = tip_mat
		pivot.add_child(tip)
		wings.append(pivot)
	# Голова и хвост — две точки, чтобы силуэт читался птицей.
	var head := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.065
	sphere.height = 0.13
	head.mesh = sphere
	head.position = Vector3(0.0, 0.03, -0.20)
	head.material_override = body_mat
	root.add_child(head)
	var tail := MeshInstance3D.new()
	var tail_box := BoxMesh.new()
	tail_box.size = Vector3(0.10, 0.015, 0.22)
	tail.mesh = tail_box
	tail.position = Vector3(0.0, 0.0, 0.24)
	tail.material_override = tip_mat
	root.add_child(tail)
	return {
		"node": root, "left": wings[0], "right": wings[1],
		"radius": 10.0 + float(index % 3) * 3.6,
		"radius_z": (10.0 + float(index % 3) * 3.6) * 0.62,
		"height": 12.4 + float(index) * 0.85,
		"speed": 0.115 + 0.018 * float(index % 3),
		"flap": 5.8 + 0.55 * float(index % 4),
		"phase": float(index) * 1.37,
		"center": Vector2(153.0 + float(index % 3) * 4.5, -30.0 - float(index % 2) * 6.0),
	}


# --- Ночной свет ------------------------------------------------------------

func _build_lighting() -> void:
	# Дополнительные тёплые пятна: входы домов светятся сами, а здесь —
	# редкие «фонарные» источники, чтобы улица не была чёрной между домами.
	for entry in [
		{"p": Vector2(172.0, -30.6), "color": GiltPalette.LAMP_WARM, "energy": 0.55},
		{"p": Vector2(165.5, -26.5), "color": GiltPalette.LAMP_NEON, "energy": 0.35},
		{"p": Vector2(180.0, -20.0), "color": GiltPalette.LAMP_WARM, "energy": 0.45},
		{"p": Vector2(190.0, -30.0), "color": GiltPalette.LAMP_VIOLET, "energy": 0.32},
	]:
		var p: Vector2 = entry["p"]
		var h := QUAY_Y if p.x < 168.4 else main.coast.ground_height(p.x, p.y)
		var lamp := OmniLight3D.new()
		lamp.position = Vector3(p.x, h + 3.0, p.y)
		lamp.light_color = entry["color"]
		lamp.omni_range = 8.0
		lamp.shadow_enabled = false
		lamp.light_volumetric_fog_energy = 0.55
		add_child(lamp)
		_lamps.append(lamp)
		_lamp_strength.append(float(entry["energy"]))


func set_night(amount: float) -> void:
	_day_night = amount
	for house in cottages:
		house.set_night(amount)
	if props != null:
		props.set_night(amount)
	for i in range(_lamps.size()):
		_lamps[i].light_energy = maxf(0.0, amount - 0.26) * _lamp_strength[i] * 1.7


func _process(delta: float) -> void:
	_time += delta
	if main == null:
		return
	if absf(main.night01 - _day_night) > 0.015:
		set_night(main.night01)
	# Чайки не «ездят по кругу»: птица смотрит по касательной, кренится
	# на повороте и чередует мах с коротким планированием.
	for entry in _gulls:
		var node: Node3D = entry["node"]
		if not is_instance_valid(node):
			continue
		var phase := float(entry["phase"])
		var angle := _time * float(entry["speed"]) + phase
		var center: Vector2 = entry["center"]
		var rx := float(entry["radius"])
		var rz := float(entry["radius_z"])
		var height := float(entry["height"]) + sin(angle * 1.7 + phase) * 0.45
		var pos := Vector3(center.x + cos(angle) * rx, height, center.y + sin(angle) * rz)
		var next_angle := angle + 0.05
		var ahead := Vector3(center.x + cos(next_angle) * rx,
			height, center.y + sin(next_angle) * rz)
		node.position = pos
		if pos.distance_squared_to(ahead) > 0.0001:
			node.look_at(ahead, Vector3.UP)
		# Левый крен на левом повороте: силуэт перестаёт быть плоским.
		node.rotate_object_local(Vector3(0.0, 0.0, 1.0), -0.20)
		# Длинные фазы планирования с редкими сериями взмахов.
		var glide := clampf(sin(_time * 0.21 + phase * 1.9) * 1.9, 0.0, 1.0)
		var amp := lerpf(0.06, 0.48, glide)
		var flap := sin(_time * float(entry["flap"]) + phase * 3.0) * amp
		(entry["left"] as Node3D).rotation.z = 0.10 + flap
		(entry["right"] as Node3D).rotation.z = -0.10 - flap
