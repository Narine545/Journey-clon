class_name IslandVillage
extends Node3D
## «Тихая бухта» — островной рыбацкий посёлок, а не выставка крыш.
##
## План перестроен по трём правилам, которых не хватало прежней версии:
##   1. ВОДА ГЛАВНЕЕ УЛИЦЫ. Дома стоят ярусами над каменной набережной,
##      а не «кольцом вокруг площади». Набережная — настоящая стена в воду
##      с кордоном, тумбами, кольцами, трапами и сходнями: с моря видно,
##      что это порт, а не поляна.
##   2. УЛИЦА ПРЯМАЯ, ДОМА ПО КРАСНОЙ ЛИНИИ. Одна главная улица, один
##      задний проезд, переулок к часовне. Фасады выровнены, отступ от
##      дороги 1.4–2.6 м, разрывы между домами 1.2–2.7 м, трубы выше
##      конька, у каждого дома ровный двор с подпорной стенкой.
##   3. У КАЖДОГО ДОМА СВОЙ ЧЕЛОВЕК. Восемь домов — восемь разных
##      построек из корабельного леса (GiltHouse.PLANS) и восемь жителей
##      (VillagePeople). Пока лодка пришвартована, дом можно выбрать
##      мышью и постучать: VillageInteraction открывает судовую роль.
##
## Ничего не висит и не тонет: у домов либо общая каменная терраса
## набережной, либо собственный выровненный двор с подпорной стенкой до
## нижнего угла рельефа. Мыс, площадь и переулки — ломаные по земле.

const COTTAGE := preload("res://scenes/village/cottage.tscn")

## Восемь домов. at — центр пола, yaw — куда смотрит вход.
## Первая линия (x=171) — над набережной, вход на главную улицу;
## вторая (x=184) — напротив, через улицу; дом пастора — за задним
## проездом, ближе к часовне.
const HOUSE_SITES := [
	{"name": "CottageNetmaker", "at": Vector2(171.2, -38.0), "yaw": PI * 0.5,
		"plan": "netloft", "style": 0, "floor": 4.10, "resident": "netmaker"},
	{"name": "CottageKeeper", "at": Vector2(183.8, -37.6), "yaw": -PI * 0.5,
		"plan": "keeper", "style": 1, "floor": 4.10, "resident": "keeper"},
	{"name": "CottageTavern", "at": Vector2(171.2, -24.0), "yaw": PI * 0.5,
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
## Прямые улицы: главная между фасадами, задний проезд и переулок к часовне.
const MAIN_STREET := Rect2(175.0, -40.8, 4.6, 33.8)
const BACK_STREET := Rect2(188.5, -40.4, 3.0, 32.6)
const CHAPEL_STREET := Rect2(191.5, -36.6, 15.0, 2.0)
const PLAZA := Vector2(172.2, -31.6)
const PLAZA_RADIUS := 2.6
const CHAPEL_AT := Vector2(206.0, -38.6)
const SHRINE_AT := Vector2(160.4, -8.4)
const PIER_Y := 1.42
const QUAY_Y := VillageProps.QUAY_Y
const BRIDGE_START := Vector3(159.8, PIER_Y, -30.0)
const BRIDGE_FINISH := Vector3(168.4, QUAY_Y, -30.0)
const FOUNDATION_BOTTOM := -0.42
## Трубы должны быть выше конька минимум на 0.8 м — проверяется в smoke.
const CHIMNEY_ABOVE_RIDGE := 0.95

var main: BoatMain
var cottages: Array[GiltHouse] = []
var chapel: GiltChapel
var shrine: GiltShrine
var props: VillageProps
var plaza: Node3D
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
	_build_plaza()
	for site in HOUSE_SITES:
		_build_house(site)
	_build_chapel()
	_build_shrine()
	_build_market()
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
	var st := GiltShapes.begin()
	var length := Vector2(BRIDGE_FINISH.x - BRIDGE_START.x, 0.0).length()
	var rise := BRIDGE_FINISH.y - BRIDGE_START.y
	# Каменные пилоны до дна: съезд стоит, а не парит.
	for t in [0.35, 0.68]:
		var x := lerpf(BRIDGE_START.x, BRIDGE_FINISH.x, float(t))
		var y := lerpf(BRIDGE_START.y, BRIDGE_FINISH.y, float(t))
		for z in [-31.52, -28.48]:
			var bed := main.coast.ground_height(x, float(z)) - 0.6
			var h := maxf(0.5, y - bed)
			GiltShapes.box(st, Vector3(x, bed + h * 0.5, float(z)),
				Vector3(0.55, h, 0.55), Color("2c2f38"))
			GiltShapes.box(st, Vector3(x, y - 0.30, float(z)),
				Vector3(0.72, 0.24, 0.72), Color("5e5862"))
	# Перила по обеим сторонам: стойки, две нити, золотые навершия.
	var rails := 12
	for i in range(rails + 1):
		var t := float(i) / float(rails)
		var x := lerpf(BRIDGE_START.x, BRIDGE_FINISH.x, t)
		var y := lerpf(BRIDGE_START.y, BRIDGE_FINISH.y, t)
		for z in [-31.58, -28.42]:
			GiltShapes.beam(st, Vector3(x, y + 0.06, float(z)),
				Vector3(x, y + 1.02, float(z)), 0.06, GiltPalette.IRON)
			if i % 3 == 0:
				GiltShapes.spire(st, Vector3(x, y + 1.02, float(z)), 0.075, 0.18,
					GiltPalette.GILT * 0.82, 4, PI * 0.25)
	for z in [-31.58, -28.42]:
		GiltShapes.beam(st, Vector3(BRIDGE_START.x, BRIDGE_START.y + 0.92, float(z)),
			Vector3(BRIDGE_FINISH.x, BRIDGE_FINISH.y + 0.92, float(z)), 0.055,
			GiltPalette.IRON)
		GiltShapes.beam(st, Vector3(BRIDGE_START.x, BRIDGE_START.y + 0.48, float(z)),
			Vector3(BRIDGE_FINISH.x, BRIDGE_FINISH.y + 0.48, float(z)), 0.04,
			GiltPalette.IRON)
	var mesh := MeshInstance3D.new()
	mesh.name = "PierBridge"
	mesh.mesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.9
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.material_override = mat
	add_child(mesh)
	# Каменный порог между верхом съезда и площадью.
	var apron := GiltShapes.begin()
	GiltShapes.box(apron, Vector3(169.05, QUAY_Y - 0.03, -30.0),
		Vector3(1.70, 0.18, 3.6), Color("575159"))
	GiltShapes.beam(apron, Vector3(168.8, QUAY_Y + 0.07, -31.7),
		Vector3(169.9, QUAY_Y + 0.07, -31.7), 0.10, Color("6b656d"))
	GiltShapes.beam(apron, Vector3(168.8, QUAY_Y + 0.07, -28.3),
		Vector3(169.9, QUAY_Y + 0.07, -28.3), 0.10, Color("6b656d"))
	var apron_mesh := MeshInstance3D.new()
	apron_mesh.name = "BridgeApron"
	apron_mesh.mesh = apron.commit()
	var apron_mat := StandardMaterial3D.new()
	apron_mat.vertex_color_use_as_albedo = true
	apron_mat.roughness = 0.92
	apron_mesh.material_override = apron_mat
	add_child(apron_mesh)
	# Ворота на верхней площадке: вход в посёлок со стороны пирса.
	props.begin()
	props.gate(Vector3(BRIDGE_FINISH.x + 0.7, QUAY_Y + 0.02, -30.0), 1.9, PI * 0.5)
	props.lamp_post(Vector3(BRIDGE_FINISH.x + 0.8, QUAY_Y + 0.02, -32.3), 2.6, false)
	props.commit(self)


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


func _build_chapel() -> void:
	var min_ground := INF
	var max_ground := -INF
	for x in [-GiltChapel.LENGTH * 0.5, GiltChapel.LENGTH * 0.5]:
		for z in [-GiltChapel.WIDTH * 0.5, GiltChapel.WIDTH * 0.5]:
			var ground := main.coast.ground_height(CHAPEL_AT.x - float(x), CHAPEL_AT.y + float(z))
			min_ground = minf(min_ground, ground)
			max_ground = maxf(max_ground, ground)
	var floor_height := maxf(BASE_Y + 0.12, max_ground + 0.16)
	chapel = GiltChapel.new()
	chapel.name = "Chapel"
	chapel.position = Vector3(CHAPEL_AT.x, floor_height, CHAPEL_AT.y)
	chapel.rotation.y = PI
	add_child(chapel)
	chapel.build()
	var solid := StaticBody3D.new()
	solid.name = "ChapelCollision"
	solid.position = chapel.position
	add_child(solid)
	var box := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(GiltChapel.LENGTH + 1.4, GiltChapel.RIDGE + 2.0, GiltChapel.WIDTH + 1.2)
	box.shape = shape
	box.position = Vector3(0.0, (GiltChapel.RIDGE + 2.0) * 0.5, 0.0)
	solid.add_child(box)
	# Подклет: часовня стоит на склоне, западный фасад не должен парить.
	var podium := GiltShapes.begin()
	var lowest := minf(min_ground, BASE_Y - 0.35)
	var depth := maxf(0.55, floor_height - 0.30 - lowest)
	for i in range(3):
		var h := depth / 3.0
		var shrink := float(i) * 0.24
		GiltShapes.box(podium,
			Vector3(CHAPEL_AT.x, floor_height - 0.22 - h * (float(i) + 0.5), CHAPEL_AT.y),
			Vector3(GiltChapel.LENGTH + 1.0 - shrink, h + 0.02, GiltChapel.WIDTH + 1.0 - shrink),
			Color("22262f").darkened(0.06 * float(i)))
	GiltShapes.beam(podium, Vector3(CHAPEL_AT.x - 3.8, floor_height - 0.18, CHAPEL_AT.y - 2.6),
		Vector3(CHAPEL_AT.x - 3.8, floor_height - 0.18, CHAPEL_AT.y + 2.6), 0.05,
		GiltPalette.GILT * 0.7)
	# Парадная лестница с переулка: девять ступеней, балюстрада с фиалами.
	var steps := Node3D.new()
	steps.name = "ChapelSteps"
	add_child(steps)
	var count := 9
	for i in range(count):
		var t := float(i) / float(count - 1)
		var x := CHAPEL_AT.x - GiltChapel.LENGTH * 0.5 - 0.58 - float(i) * 0.34
		var step_y := lerpf(floor_height - 0.16, BASE_Y + 0.02, t)
		GiltShapes.box(podium, Vector3(x, step_y, CHAPEL_AT.y),
			Vector3(0.40, 0.30, 3.0 - t * 0.4), GiltPalette.STONE_COLD * (0.42 + 0.12 * t))
	for sz in [-1.0, 1.0]:
		for i in range(4):
			var t := (float(i) + 0.5) / 4.0
			var x := CHAPEL_AT.x - GiltChapel.LENGTH * 0.5 - 0.72 - t * 2.8
			var z: float = CHAPEL_AT.y + float(sz) * 1.58
			var y := lerpf(floor_height - 0.16, BASE_Y + 0.02, t)
			GiltShapes.box(podium, Vector3(x, y + 0.34, z), Vector3(0.30, 0.68, 0.30),
				Color("262a35"))
			GiltShapes.spire(podium, Vector3(x, y + 0.68, z), 0.16, 0.50,
				GiltPalette.GILT * 0.85, 4, PI * 0.25)
	var mesh := MeshInstance3D.new()
	mesh.name = "ChapelPodium"
	mesh.mesh = podium.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.9
	mat.metallic = 0.05
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.material_override = mat
	steps.add_child(mesh)


## Прибрежный храм-фонарь стоит на самом краю набережной, а не на склоне:
## у него своя каменная площадка, ступени с юга и фонарь над водой.
func _build_shrine() -> void:
	shrine = GiltShrine.new()
	shrine.name = "ShoreShrine"
	shrine.position = Vector3(SHRINE_AT.x, QUAY_Y + 0.10, SHRINE_AT.y)
	shrine.rotation.y = 0.34
	add_child(shrine)
	shrine.build()
	var solid := StaticBody3D.new()
	solid.name = "ShrineCollision"
	solid.position = shrine.position
	add_child(solid)
	var box := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(3.1, GiltShrine.HEIGHT + 1.4, 2.5)
	box.shape = shape
	box.position = Vector3(0.0, (GiltShrine.HEIGHT + 1.4) * 0.5, 0.0)
	solid.add_child(box)
	var st := GiltShapes.begin()
	# Плинт до настила и площадка вокруг: храм не «утоплен» в набережную.
	GiltShapes.box(st, Vector3(SHRINE_AT.x, QUAY_Y - 0.02, SHRINE_AT.y),
		Vector3(3.5, 0.20, 3.0), Color("2b2e37"))
	GiltShapes.box(st, Vector3(SHRINE_AT.x, QUAY_Y + 0.04, SHRINE_AT.y),
		Vector3(3.75, 0.12, 3.25), GiltPalette.STONE_COLD * 0.42)
	# Три ступени с юга, к дороге вдоль кромки.
	for i in range(3):
		var z := SHRINE_AT.y + 1.60 + float(i) * 0.30
		GiltShapes.box(st, Vector3(SHRINE_AT.x, QUAY_Y - 0.06 - float(i) * 0.06, z),
			Vector3(1.8, 0.12, 0.34), GiltPalette.STONE_COLD * 0.40)
	# Фонарный столб у входа — точка, по которой храм находят ночью.
	props.begin()
	props.lamp_post(Vector3(SHRINE_AT.x - 1.85, QUAY_Y + 0.02, SHRINE_AT.y + 1.6), 2.6, true)
	props.commit(self)
	var mesh := MeshInstance3D.new()
	mesh.name = "ShrinePlinth"
	mesh.mesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.9
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.material_override = mat
	add_child(mesh)


# --- Дороги и площадь -------------------------------------------------------

## Основание квартала: каменная плита с плиткой, кордоном и подбоем.
## Дороги больше не «лежат на рельефе» — они прямые полосы поверх плиты.
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
	for rect in [MAIN_STREET, BACK_STREET, CHAPEL_STREET]:
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


## Площадь у съезда: не «круг с фонтаном», а каменная площадка порта.
## В центре — роза ветров из светлого камня, по краю — кордон и тумбы.
func _build_plaza() -> void:
	plaza = Node3D.new()
	plaza.name = "Plaza"
	add_child(plaza)
	_build_plaza_paving()


func _build_plaza_paving() -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings := 10
	var segs := 36
	var center_h := BASE_Y + 0.06
	for r in range(rings):
		var r0 := PLAZA_RADIUS * float(r) / float(rings)
		var r1 := PLAZA_RADIUS * float(r + 1) / float(rings)
		for s in range(segs):
			var a0 := TAU * float(s) / float(segs)
			var a1 := TAU * float(s + 1) / float(segs)
			var tone := Color("4d4954") if (r + s) % 2 == 0 else Color("45414b")
			if r == rings - 1:
				tone = Color("3a3741")
			if r == 0:
				tone = Color("5b5661")
			var p00 := _plaza_point(PLAZA, r0, a0, center_h)
			var p10 := _plaza_point(PLAZA, r1, a0, center_h)
			var p11 := _plaza_point(PLAZA, r1, a1, center_h)
			var p01 := _plaza_point(PLAZA, r0, a1, center_h)
			for tri in [[p00, p10, p11], [p00, p11, p01]]:
				for p: Vector3 in tri:
					surface.set_color(tone)
					surface.set_normal(Vector3.UP)
					surface.add_vertex(p)
	# Роза ветров: восемь лучей светлого камня, длинный — на запад, к морю.
	for i in range(8):
		var ang := TAU * float(i) / 8.0 + PI * 0.5
		var long := i == 0
		var length := 2.0 if long else 1.35
		var width := 0.30 if long else 0.18
		var dir := Vector2(cos(ang), sin(ang))
		var side := Vector2(-dir.y, dir.x) * width * 0.5
		var a := PLAZA + side
		var b := PLAZA - side
		var c := PLAZA + dir * length - side * 0.4
		var d := PLAZA + dir * length + side * 0.4
		_plaza_quad(surface, a, b, d, c, Color("8d7a5e") if long else Color("6f666d"))
	var mesh := MeshInstance3D.new()
	mesh.name = "PlazaPaving"
	mesh.mesh = surface.commit()
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.95
	mesh.material_override = material
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	plaza.add_child(mesh)
	# Каменный подбой под настилом площади: с уровня улицы площадь —
	# приподнятая площадка, а не парящий лист.
	var skirt := MeshInstance3D.new()
	skirt.name = "PlazaSkirt"
	var skirt_mesh := CylinderMesh.new()
	skirt_mesh.top_radius = PLAZA_RADIUS - 0.03
	skirt_mesh.bottom_radius = PLAZA_RADIUS - 0.03
	skirt_mesh.height = 0.17
	skirt_mesh.radial_segments = 36
	skirt.mesh = skirt_mesh
	skirt.position = Vector3(PLAZA.x, center_h - 0.005, PLAZA.y)
	var skirt_mat := StandardMaterial3D.new()
	skirt_mat.albedo_color = Color("4a4650")
	skirt_mat.roughness = 0.96
	skirt.material_override = skirt_mat
	skirt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	plaza.add_child(skirt)
	# Латунное кольцо в центре и бордюр по краю площади.
	var rim := GiltShapes.begin()
	GiltShapes.ring(rim, Vector3(PLAZA.x, center_h + 0.08, PLAZA.y), 0.75, 0.58, 0.04,
		GiltPalette.GILT * 0.85, 28, Vector3.UP)
	var steps := 36
	for i in range(steps):
		var a0 := TAU * float(i) / float(steps)
		var a1 := TAU * float(i + 1) / float(steps)
		var p0 := _plaza_point(PLAZA, PLAZA_RADIUS - 0.05, a0, center_h)
		var p1 := _plaza_point(PLAZA, PLAZA_RADIUS - 0.05, a1, center_h)
		GiltShapes.beam(rim, p0, p1, 0.20, Color("6a646c"))
	var rim_mesh := MeshInstance3D.new()
	rim_mesh.name = "PlazaRim"
	rim_mesh.mesh = rim.commit()
	var rim_mat := StandardMaterial3D.new()
	rim_mat.vertex_color_use_as_albedo = true
	rim_mat.roughness = 0.5
	rim_mat.metallic = 0.35
	rim_mesh.material_override = rim_mat
	plaza.add_child(rim_mesh)


func _plaza_point(center: Vector2, radius: float, angle: float, height: float) -> Vector3:
	return Vector3(center.x + cos(angle) * radius, height + 0.08,
		center.y + sin(angle) * radius)


func _plaza_quad(surface: SurfaceTool, a: Vector2, b: Vector2, c: Vector2, d: Vector2,
		tone: Color) -> void:
	for p in [a, b, c, a, c, d]:
		surface.set_color(tone)
		surface.set_normal(Vector3.UP)
		surface.add_vertex(Vector3(p.x, QUAY_Y + 0.102, p.y))


# --- Рынок и вход -----------------------------------------------------------

func _build_market() -> void:
	var market := Node3D.new()
	market.name = "QuayMarket"
	add_child(market)
	props.begin()
	# Колокол у съезда: формальный «вход в порт».
	props.mooring_bell(Vector3(166.6, QUAY_Y + 0.02, -34.0))
	# Прилавки на площади: два под полосатыми тентами.
	props.stall(Vector3(165.4, QUAY_Y + 0.02, -25.6), -0.24)
	# Склад у воды: эмалевые полосы, дверь и помост.
	props.store_hut(Vector3(161.4, QUAY_Y + 0.02, -13.6), 0.16)
	props.commit(market)
	# Бочки и ящики — одной сеткой на весь рынок.
	props.begin()
	for p in [Vector2(159.2, -39.6), Vector2(160.4, -36.4), Vector2(165.2, -12.4)]:
		var h := QUAY_Y + 0.02
		if p.x > 168.0:
			h = main.coast.ground_height(p.x, p.y) + 0.02
		props.barrel(Vector3(p.x, h, p.y), 0.82, 0.30)
		if p.x < 168.0:
			props.barrel(Vector3(p.x + 0.62, h, p.y + 0.24), 0.72, 0.27)
	props.commit(market)


# --- Жители -----------------------------------------------------------------

# --- Детали и жизнь ---------------------------------------------------------

func _build_details() -> void:
	var details := Node3D.new()
	details.name = "VillageLife"
	add_child(details)
	props.begin()
	# Колодец и кабестан на площади и набережной: два центра притяжения.
	props.well(Vector3(171.4, BASE_Y + 0.08, -32.4))
	props.capstan(Vector3(162.2, QUAY_Y + 0.02, -33.0))
	props.fish_table(Vector3(161.0, QUAY_Y + 0.02, -24.2), 0.22)
	props.notice_board(Vector3(166.8, QUAY_Y + 0.02, -20.6), 0.42)
	props.flagpole(Vector3(172.6, BASE_Y + 0.06, -29.4), Color("7e4a63"))
	# Вешала для рыбы — главный «северный» силуэт посёлка.
	props.hjell(Vector3(163.0, QUAY_Y + 0.02, -38.0), PI * 0.5, 5.4)
	props.hjell(Vector3(161.2, QUAY_Y + 0.02, -17.0), PI * 0.5, 4.4)
	# Сети, ловушки, верёвки, вёсла: рабочий двор, а не витрина.
	props.lobster_pots(Vector3(164.6, QUAY_Y + 0.02, -21.2), 0.3)
	props.lobster_pots(Vector3(164.8, QUAY_Y + 0.02, -39.6), -0.2)
	props.bench(Vector3(165.9, QUAY_Y + 0.02, -35.6), -0.1)
	# Лодки: две вытащены на набережную, одна стоит в воде и качается.
	props.rowboat(Vector3(158.4, QUAY_Y + 0.44, -35.6), 1.35, Color("8c4a3b"))
	props.rowboat(Vector3(158.0, QUAY_Y + 0.44, -22.8), 0.28, Color("2b6f6c"))
	# Святой источник за часовней: маленькая вода, но своя.
	props.fountain(Vector3(212.6, main.coast.ground_height(212.6, -34.0) + 0.02, -34.0))
	props.commit(details)
	# Фонари вдоль улиц — ритм, по которому посёлок читается вечером.
	props.begin()
	var west_lamps := [Vector2(174.55, -37.0), Vector2(174.55, -28.8), Vector2(174.5, -21.6),
		Vector2(174.4, -14.4)]
	for i in range(west_lamps.size()):
		var p: Vector2 = west_lamps[i]
		var h := _deck_height(p.x, p.y)
		props.lamp_post(Vector3(p.x, h, p.y), 3.2, i % 3 == 1)
	var east_lamps := [Vector2(180.3, -33.4), Vector2(180.3, -25.6), Vector2(180.3, -17.8),
		Vector2(180.2, -10.6)]
	for i in range(east_lamps.size()):
		var p: Vector2 = east_lamps[i]
		var h := _deck_height(p.x, p.y)
		props.lamp_post(Vector3(p.x, h, p.y), 3.3, i % 2 == 0)
	# Фонари заднего проезда и переулка к часовне.
	for p in [Vector2(187.9, -25.0), Vector2(187.9, -17.4), Vector2(192.2, -37.1),
			Vector2(200.8, -37.1)]:
		var h := _deck_height(p.x, p.y)
		props.lamp_post(Vector3(p.x, h, p.y), 3.0, true)
	props.commit(details)
	# Ограды: только там, где не режут дорожку. Сад пастора, часовня, дворы.
	props.begin()
	props.fence(Vector3(201.2, _deck_height(201.2, -26.0) - 0.02, -26.0),
		Vector3(201.2, _deck_height(201.2, -34.4) - 0.02, -34.4), false)
	for p in [Vector2(174.6, -18.8), Vector2(180.6, -15.8), Vector2(180.6, -22.8),
			Vector2(174.5, -35.6), Vector2(180.0, -30.0)]:
		var h := _deck_height(p.x, p.y) - 0.02
		props.barrel(Vector3(p.x, h, p.y), 0.60, 0.36)
	props.commit(details)
	# Бельё между домами и во дворах: цветные пятна, которые видно с воды.
	props.begin()
	props.laundry(Vector3(174.1, _deck_height(174.1, -19.4) - 0.02, -19.4),
		Vector3(174.1, _deck_height(174.1, -16.9) - 0.02, -16.9))
	props.laundry(Vector3(187.6, _deck_height(187.6, -38.8) - 0.02, -38.8),
		Vector3(187.6, _deck_height(187.6, -35.0) - 0.02, -35.0))
	props.laundry(Vector3(192.2, _deck_height(192.2, -37.6) - 0.02, -37.6),
		Vector3(197.4, _deck_height(197.4, -37.6) - 0.02, -37.6))
	props.commit(details)
	# Трава по краям плиты: город не должен быть залит бетоном.
	props.begin()
	var tufts := [
		Vector2(211.2, -8.4), Vector2(212.4, -14.8), Vector2(211.6, -21.6),
		Vector2(212.8, -28.4), Vector2(211.4, -35.2), Vector2(212.6, -41.8),
		Vector2(207.0, -45.2), Vector2(211.8, -24.0), Vector2(210.8, -31.4),
		Vector2(213.0, -41.6), Vector2(169.0, -3.0), Vector2(170.2, -45.2),
	]
	for i in range(tufts.size()):
		var p: Vector2 = tufts[i]
		props.grass(Vector3(p.x, 0.0, p.y), 0.9 + 0.2 * float(i % 3), 11 + i)
	props.commit(details)


## Чайки над бухтой.
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
	if chapel != null:
		chapel.set_night(amount)
	if shrine != null:
		shrine.set_night(amount)
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
