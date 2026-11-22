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

## Главная улица: от северного конца через площадь к съезду с пирса.
const QUAY_LANE := [
	Vector2(177.2, -40.4), Vector2(177.0, -36.0), Vector2(176.8, -33.0),
	Vector2(176.4, -32.4),
]
## Южная половина главной улицы: от развилки у площади к лоцманскому дому.
const SOUTH_LANE := [
	Vector2(176.8, -32.4), Vector2(177.0, -28.0), Vector2(177.0, -22.0),
	Vector2(176.8, -16.0), Vector2(176.2, -8.2),
]
## Задний проезд: хозяйственные дворы, поленницы, сушильни, дом пастора.
const UPPER_LANE := [
	Vector2(184.4, -41.0), Vector2(188.0, -38.0), Vector2(190.2, -34.0),
	Vector2(190.2, -28.0), Vector2(190.2, -22.0), Vector2(190.2, -16.0),
	Vector2(190.0, -9.0),
]
## Переулок к часовне: поднимается по восточному склону.
const CHAPEL_WALK := [
	Vector2(190.2, -33.6), Vector2(194.4, -35.4), Vector2(198.2, -37.4),
	Vector2(201.8, -38.6),
]
const PLAZA := Vector2(173.0, -31.6)
const PLAZA_RADIUS := 3.2
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
var resident_nodes: Dictionary = {}
var chapel: GiltChapel
var shrine: GiltShrine
var props: VillageProps
var plaza: Node3D
var _lamps: Array[OmniLight3D] = []
var _lamp_strength: Array[float] = []
var _day_night := -1.0
var _boats: Array[Dictionary] = []
var _gulls: Array[Dictionary] = []
var _time := 0.0


func setup(owner_main: BoatMain) -> void:
	main = owner_main
	name = "HarborVillage"
	props = VillageProps.new()
	props.setup(main, self)
	_build_quay()
	_build_bridge()
	_build_roads()
	_build_plaza()
	for site in HOUSE_SITES:
		_build_house(site)
	_build_chapel()
	_build_shrine()
	_build_market()
	_build_residents()
	_build_details()
	_build_harbour_life()
	_build_lighting()
	set_night(main.night01)


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
	var plan := (GiltHouse.PLANS.get(String(site["plan"])) as Dictionary)
	var hw := float(plan["width"]) * 0.5
	var hd := float(plan["depth"]) * 0.5
	var rotation_basis := Basis(Vector3.UP, yaw)
	var min_ground := INF
	var max_ground := -INF
	for x in [-hw, hw]:
		for z in [-hd, hd]:
			var p := Vector3(at.x, 0.0, at.y) + rotation_basis * Vector3(float(x), 0.0, float(z))
			var ground := main.coast.ground_height(p.x, p.z)
			min_ground = minf(min_ground, ground)
			max_ground = maxf(max_ground, ground)
	# Первая линия стоит на каменной террасе набережной, остальные — на своём
	# выровненном дворе, но не ниже самой высокой точки рельефа.
	var floor_height := max_ground + 0.10
	if site.has("floor"):
		floor_height = maxf(float(site["floor"]), floor_height - 0.02)
	var house := GiltHouse.new()
	house.name = site["name"]
	house.position = Vector3(at.x, floor_height, at.y)
	house.rotation.y = yaw
	add_child(house)
	house.build_site(site, min_ground - floor_height)
	cottages.append(house)


func _build_chapel() -> void:
	var min_ground := INF
	var max_ground := -INF
	for x in [-GiltChapel.LENGTH * 0.5, GiltChapel.LENGTH * 0.5]:
		for z in [-GiltChapel.WIDTH * 0.5, GiltChapel.WIDTH * 0.5]:
			var ground := main.coast.ground_height(CHAPEL_AT.x - float(x), CHAPEL_AT.y + float(z))
			min_ground = minf(min_ground, ground)
			max_ground = maxf(max_ground, ground)
	var floor_height := max_ground + 0.16
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
	var lowest := floor_height
	for x in [-GiltChapel.LENGTH * 0.5, GiltChapel.LENGTH * 0.5]:
		for z in [-GiltChapel.WIDTH * 0.5, GiltChapel.WIDTH * 0.5]:
			lowest = minf(lowest, main.coast.ground_height(CHAPEL_AT.x - float(x),
				CHAPEL_AT.y + float(z)))
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
		var step_y := lerpf(floor_height - 0.16,
			main.coast.ground_height(x, CHAPEL_AT.y) + 0.06, t)
		GiltShapes.box(podium, Vector3(x, step_y, CHAPEL_AT.y),
			Vector3(0.40, 0.30, 3.0 - t * 0.4), GiltPalette.STONE_COLD * (0.42 + 0.12 * t))
	for sz in [-1.0, 1.0]:
		for i in range(4):
			var t := (float(i) + 0.5) / 4.0
			var x := CHAPEL_AT.x - GiltChapel.LENGTH * 0.5 - 0.72 - t * 2.8
			var z: float = CHAPEL_AT.y + float(sz) * 1.58
			var y := lerpf(floor_height - 0.16, main.coast.ground_height(x, z) + 0.06, t)
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

func _build_roads() -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Набережная: 3.4 м, две полосы брусчатки со швом по центру.
	_road_strip(surface, QUAY_LANE, 3.2, true)
	_road_strip(surface, SOUTH_LANE, 3.2, true)
	# Задний проезд уже и без шва: хозяйственный переулок.
	_road_strip(surface, UPPER_LANE, 2.2, false)
	_road_strip(surface, CHAPEL_WALK, 2.4, false)
	# Дорожки к дверям: заканчиваются у крыльца, а не бьют в стену.
	for site in HOUSE_SITES:
		var at: Vector2 = site["at"]
		var yaw: float = site["yaw"]
		var front := Vector3(0.0, 0.0, float((GiltHouse.PLANS[site["plan"]] as Dictionary)["depth"]) * 0.5 + 0.55)
		var world_front := Vector3(at.x, 0.0, at.y) + Basis(Vector3.UP, yaw) * front
		var anchor := _nearest_on_lane(at, yaw)
		_road_strip(surface, [anchor, Vector2(world_front.x, world_front.z)], 1.15, false)
	var road := MeshInstance3D.new()
	road.name = "GroundedUnpavedLane"
	road.mesh = surface.commit()
	var material := StandardMaterial3D.new()
	material.albedo_color = Color.WHITE
	material.roughness = 0.97
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	road.material_override = material
	road.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(road)
	# Бордюр и лоток: дорога перестаёт быть «нарисованной лентой».
	_build_kerbs()


func _nearest_on_lane(at: Vector2, yaw: float) -> Vector2:
	var front := Vector3(at.x, 0.0, at.y) + Basis(Vector3.UP, yaw) * Vector3(0.0, 0.0, 3.2)
	var best := Vector2(front.x, front.z)
	var best_d := INF
	for lane in [QUAY_LANE, SOUTH_LANE, UPPER_LANE, CHAPEL_WALK]:
		for i in range(lane.size() - 1):
			var a: Vector2 = lane[i]
			var b: Vector2 = lane[i + 1]
			var p := Geometry2D.get_closest_point_to_segment(Vector2(front.x, front.z), a, b)
			var d := p.distance_to(Vector2(front.x, front.z))
			if d < best_d:
				best_d = d
				best = p
	return best


func _road_strip(surface: SurfaceTool, points: Array, width: float, seam: bool) -> void:
	# Короткие сегменты повторяют рельеф; больших висящих прямоугольников нет.
	for i in range(points.size() - 1):
		var a: Vector2 = points[i]
		var b: Vector2 = points[i + 1]
		var forward := (b - a).normalized()
		var side := Vector2(-forward.y, forward.x)
		var steps := maxi(1, int(ceil(a.distance_to(b) / 0.8)))
		for j in range(steps):
			var p0 := a.lerp(b, float(j) / float(steps))
			var p1 := a.lerp(b, float(j + 1) / float(steps))
			# Пять полос: кромки темнее, центр — вытертый камень.
			for band in range(5):
				var d0 := lerpf(-width * 0.5, width * 0.5, float(band) / 5.0)
				var d1 := lerpf(-width * 0.5, width * 0.5, float(band + 1) / 5.0)
				var edge := band == 0 or band == 4
				var c0 := Color("3d3a44") if edge else Color("4d4954")
				var c1 := Color("3d3a44") if edge else Color("4d4954")
				if not edge:
					c0 = c0.lerp(Color("5b5661"), 0.35)
					c1 = c1.lerp(Color("5b5661"), 0.35)
				_road_triangle(surface, p0 + side * d0, p1 + side * d0, p1 + side * d1, c0, c0, c1)
				_road_triangle(surface, p0 + side * d0, p1 + side * d1, p0 + side * d1, c0, c1, c1)
			# Шов по центру: тёмная нить стыка мостовой.
			if seam:
				var t := float(j) / float(steps)
				var shade := Color("35323c") if int(t * 4.0) % 2 == 0 else Color("3a3640")
				_road_triangle(surface, p0 - side * 0.05, p1 - side * 0.05, p1 + side * 0.05,
					shade, shade, shade)
				_road_triangle(surface, p0 - side * 0.05, p1 + side * 0.05, p0 + side * 0.05,
					shade, shade, shade)
			# Поперечные швы брусчатки — каждые ~1.6 м.
			if j % 2 == 0:
				_road_triangle(surface, p0 - side * width * 0.5, p0 + side * width * 0.5,
					p0 + side * width * 0.45, Color("34313a"), Color("34313a"), Color("34313a"))


func _road_triangle(surface: SurfaceTool, a: Vector2, b: Vector2, c: Vector2,
		ca: Color, cb: Color, cc: Color) -> void:
	for entry in [[a, ca], [b, cb], [c, cc]]:
		var p: Vector2 = entry[0]
		surface.set_color(entry[1])
		surface.set_normal(main.coast.ground_normal(p.x, p.y))
		surface.add_vertex(Vector3(p.x, main.coast.ground_height(p.x, p.y) + 0.055, p.y))


## Бордюрные камни по обеим кромкам главной улицы и площадь — отдельной
## сеткой камня. Они дают дороге толщину и тень, которой не было у ленты.
func _build_kerbs() -> void:
	var st := GiltShapes.begin()
	for lane in [QUAY_LANE, SOUTH_LANE]:
		_kerb_strip(st, lane, 3.2)
	_kerb_strip(st, UPPER_LANE, 2.2)
	var mesh := MeshInstance3D.new()
	mesh.name = "StreetKerbs"
	mesh.mesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.94
	mesh.material_override = mat
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh)


func _kerb_strip(st: SurfaceTool, points: Array, width: float) -> void:
	for i in range(points.size() - 1):
		var a: Vector2 = points[i]
		var b: Vector2 = points[i + 1]
		var forward := (b - a).normalized()
		var side := Vector2(-forward.y, forward.x)
		var steps := maxi(1, int(ceil(a.distance_to(b) / 0.75)))
		for j in range(steps):
			var t0 := float(j) / float(steps)
			var t1 := float(j + 1) / float(steps)
			for edge in [-1.0, 1.0]:
				var p0 := a.lerp(b, t0) + side * float(edge) * (width * 0.5 + 0.09)
				var p1 := a.lerp(b, t1) + side * float(edge) * (width * 0.5 + 0.09)
				var h0 := main.coast.ground_height(p0.x, p0.y)
				var h1 := main.coast.ground_height(p1.x, p1.y)
				GiltShapes.beam(st, Vector3(p0.x, h0 + 0.11, p0.y),
					Vector3(p1.x, h1 + 0.11, p1.y), 0.16, Color("6a646c"))
				GiltShapes.beam(st, Vector3(p0.x, h0 + 0.02, p0.y),
					Vector3(p1.x, h1 + 0.02, p1.y), 0.20, Color("403d46"))


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
	var center_h := QUAY_Y + 0.02
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
		var length := 3.6 if long else 2.2
		var width := 0.34 if long else 0.20
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
	GiltShapes.ring(rim, Vector3(PLAZA.x, center_h + 0.08, PLAZA.y), 0.95, 0.70, 0.04,
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
	props.stall(Vector3(171.0, QUAY_Y + 0.10, -33.2), 0.18)
	props.stall(Vector3(165.4, QUAY_Y + 0.02, -25.6), -0.24)
	# Склад у воды: эмалевые полосы, дверь и помост.
	props.store_hut(Vector3(161.4, QUAY_Y + 0.02, -13.6), 0.16)
	props.commit(market)
	# Бочки и ящики — одной сеткой на весь рынок.
	props.begin()
	for p in [Vector2(166.2, -37.2), Vector2(166.8, -26.6), Vector2(159.2, -39.6),
			Vector2(160.4, -36.4), Vector2(165.2, -12.4)]:
		var h := QUAY_Y + 0.02
		if p.x > 168.0:
			h = main.coast.ground_height(p.x, p.y) + 0.02
		props.barrel(Vector3(p.x, h, p.y), 0.82, 0.30)
		if p.x < 168.0:
			props.barrel(Vector3(p.x + 0.62, h, p.y + 0.24), 0.72, 0.27)
	props.commit(market)


# --- Жители -----------------------------------------------------------------

func _build_residents() -> void:
	for house in cottages:
		var id := house.person_id
		if id.is_empty():
			continue
		var resident := VillageResident.new()
		add_child(resident)
		# Житель стоит у своего крыльца, лицом к улице.
		var facing := house.to_global(Vector3(0.0, 0.0, 1.0)) - house.global_position
		facing.y = 0.0
		var spot := house.resident_spot()
		# Житель стоит на земле/настиле, а не на полу дома: иначе у
		# приподнятого цоколя он висит в воздухе на 20 см.
		spot.y = main.coast.ground_height(spot.x, spot.z) + 0.04
		resident.setup(main, id, spot, facing.normalized())
		resident_nodes[id] = resident
	# Звонарь у часовни и фонарщик у прибрежного храма — тоже жители.
	var bell := VillageResident.new()
	add_child(bell)
	bell.setup(main, "bellringer",
		Vector3(CHAPEL_AT.x - GiltChapel.LENGTH * 0.5 - 2.0, main.coast.ground_height(
			CHAPEL_AT.x - GiltChapel.LENGTH * 0.5 - 2.0, CHAPEL_AT.y) + 0.06, CHAPEL_AT.y + 1.6),
		Vector3(0.7, 0.0, -0.2))
	resident_nodes["bellringer"] = bell
	var lamp := VillageResident.new()
	add_child(lamp)
	lamp.setup(main, "lanternkeeper",
		Vector3(SHRINE_AT.x - 1.1, QUAY_Y + 0.06, SHRINE_AT.y + 2.1),
		Vector3(-1.0, 0.0, 0.4))
	resident_nodes["lanternkeeper"] = lamp


# --- Детали и жизнь ---------------------------------------------------------

func _build_details() -> void:
	var details := Node3D.new()
	details.name = "VillageLife"
	add_child(details)
	props.begin()
	# Колодец и кабестан на площади и набережной: два центра притяжения.
	props.well(Vector3(173.8, QUAY_Y + 0.10, -33.3))
	props.capstan(Vector3(161.0, QUAY_Y + 0.02, -34.4))
	props.fish_table(Vector3(161.0, QUAY_Y + 0.02, -24.2), 0.22)
	props.notice_board(Vector3(166.8, QUAY_Y + 0.02, -20.6), 0.42)
	props.flagpole(Vector3(175.0, QUAY_Y + 0.10, -32.4), Color("7e4a63"))
	# Вешала для рыбы — главный «северный» силуэт посёлка.
	props.hjell(Vector3(163.0, QUAY_Y + 0.02, -38.0), PI * 0.5, 5.4)
	props.hjell(Vector3(157.8, QUAY_Y + 0.02, -17.0), PI * 0.5, 4.4)
	# Сети, ловушки, верёвки, вёсла: рабочий двор, а не витрина.
	props.lobster_pots(Vector3(164.6, QUAY_Y + 0.02, -21.2), 0.3)
	props.lobster_pots(Vector3(157.0, QUAY_Y + 0.02, -36.8), -0.2)
	props.bench(Vector3(165.9, QUAY_Y + 0.02, -35.6), -0.1)
	props.bench(Vector3(165.0, QUAY_Y + 0.02, -27.6), 1.4)
	props.bench(Vector3(161.8, QUAY_Y + 0.02, -27.2), 1.4)
	# Лодки: две вытащены на набережную, одна стоит в воде и качается.
	props.rowboat(Vector3(158.4, QUAY_Y + 0.44, -35.6), 1.35, Color("8c4a3b"))
	props.rowboat(Vector3(158.0, QUAY_Y + 0.44, -22.8), 0.28, Color("2b6f6c"))
	# Святой источник за часовней: маленькая вода, но своя.
	props.fountain(Vector3(210.4, main.coast.ground_height(210.4, -34.0) + 0.02, -34.0))
	props.commit(details)
	# Фонари вдоль улиц — ритм, по которому посёлок читается вечером.
	props.begin()
	var west_lamps := [Vector2(175.3, -37.0), Vector2(175.3, -28.8), Vector2(175.2, -21.6),
		Vector2(175.0, -14.4)]
	for i in range(west_lamps.size()):
		var p: Vector2 = west_lamps[i]
		var h := main.coast.ground_height(p.x, p.y)
		props.lamp_post(Vector3(p.x, h, p.y), 3.2, i % 3 == 1)
	var east_lamps := [Vector2(179.0, -33.4), Vector2(179.0, -25.6), Vector2(178.8, -17.8),
		Vector2(178.4, -10.6)]
	for i in range(east_lamps.size()):
		var p: Vector2 = east_lamps[i]
		var h := main.coast.ground_height(p.x, p.y)
		props.lamp_post(Vector3(p.x, h, p.y), 3.3, i % 2 == 0)
	# Фонари заднего проезда и переулка к часовне.
	for p in [Vector2(188.3, -25.0), Vector2(188.3, -17.4), Vector2(191.8, -36.6),
			Vector2(200.6, -36.6)]:
		var h := main.coast.ground_height(p.x, p.y)
		props.lamp_post(Vector3(p.x, h, p.y), 3.0, true)
	props.commit(details)
	# Ограды: только там, где не режут дорожку. Сад пастора, часовня, дворы.
	props.begin()
	props.fence(Vector3(201.2, main.coast.ground_height(201.2, -26.0), -26.0),
		Vector3(201.2, main.coast.ground_height(201.2, -34.4), -34.4), false)
	for p in [Vector2(174.6, -18.8), Vector2(180.6, -15.8), Vector2(180.6, -22.8),
			Vector2(174.8, -35.6), Vector2(179.4, -30.0)]:
		var h := main.coast.ground_height(p.x, p.y)
		props.barrel(Vector3(p.x, h, p.y), 0.60, 0.36)
	props.commit(details)
	# Бельё между домами и во дворах: цветные пятна, которые видно с воды.
	props.begin()
	props.laundry(Vector3(174.5, main.coast.ground_height(174.5, -19.4), -19.4),
		Vector3(174.5, main.coast.ground_height(174.5, -16.9), -16.9))
	props.laundry(Vector3(188.4, main.coast.ground_height(188.4, -38.8), -38.8),
		Vector3(188.4, main.coast.ground_height(188.4, -35.0), -35.0))
	props.laundry(Vector3(192.2, main.coast.ground_height(192.2, -37.6), -37.6),
		Vector3(197.4, main.coast.ground_height(197.4, -37.6), -37.6))
	props.commit(details)
	# Трава и камни: остров не должен быть «залит бетоном».
	props.begin()
	var tufts := [
		Vector2(174.8, -40.0), Vector2(174.6, -35.6), Vector2(180.2, -40.0),
		Vector2(187.4, -40.2), Vector2(188.8, -36.4), Vector2(188.0, -30.8),
		Vector2(188.6, -23.4), Vector2(188.4, -15.0), Vector2(188.2, -9.4),
		Vector2(180.0, -8.6), Vector2(174.4, -9.4), Vector2(174.6, -12.2),
		Vector2(191.8, -8.6), Vector2(196.0, -12.6), Vector2(198.6, -17.4),
		Vector2(199.4, -22.8), Vector2(200.2, -27.8), Vector2(201.0, -41.4),
		Vector2(196.2, -42.0), Vector2(192.8, -43.4), Vector2(169.2, -43.2),
		Vector2(169.4, -4.6), Vector2(197.4, -6.2), Vector2(204.0, -10.4),
		Vector2(212.0, -24.0), Vector2(211.0, -31.0), Vector2(213.0, -41.6),
	]
	for i in range(tufts.size()):
		var p: Vector2 = tufts[i]
		props.grass(Vector3(p.x, 0.0, p.y), 0.9 + 0.2 * float(i % 3), 11 + i)
	props.commit(details)
	props.begin()
	props.rocks(Vector3(169.0, 0.0, -43.4), 2.2, 6, 3)
	props.rocks(Vector3(169.4, 0.0, -4.2), 2.0, 5, 9)
	props.rocks(Vector3(197.0, 0.0, -44.0), 2.6, 6, 17)
	props.rocks(Vector3(211.0, 0.0, -44.0), 3.0, 7, 23)
	props.rocks(Vector3(204.0, 0.0, -8.0), 2.2, 5, 31)
	props.commit(details)
	# Кривые деревья на восточном склоне: силуэт над крышами.
	props.begin()
	props.tree(Vector3(199.6, 0.0, -11.2), 1.15, 0.3)
	props.tree(Vector3(200.2, 0.0, -21.0), 1.0, 1.2)
	props.tree(Vector3(202.0, 0.0, -31.6), 1.25, -0.4)
	props.tree(Vector3(212.6, 0.0, -26.0), 0.9, 0.8)
	props.tree(Vector3(191.0, 0.0, -43.6), 0.85, 1.7)
	props.commit(details)


## Лодки в воде и чайки: единственное, что движется само.
func _build_harbour_life() -> void:
	# Одна лодка на воде у набережной.
	var boat := VillageProps.new()
	boat.setup(main, self)
	var node := boat.boat_node(Vector3(148.0, 0.26, -19.0), 1.15, Color("8c4a3b"))
	add_child(node)
	_boats.append({"node": node, "base_y": 0.26, "phase": 0.4, "amp": 0.035})
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
		"radius": 9.0 + float(index % 4) * 3.2,
		"height": 9.5 + float(index) * 1.15,
		"speed": 0.10 + 0.025 * float(index % 3),
		"phase": float(index) * 1.3,
		"center": Vector2(164.0 + float(index % 3) * 5.0, -24.0 - float(index) * 1.8),
	}


# --- Ночной свет ------------------------------------------------------------

func _build_lighting() -> void:
	# Дополнительные тёплые пятна: входы домов светятся сами, а здесь —
	# редкие «фонарные» источники, чтобы улица не была чёрной между домами.
	for entry in [
		{"p": Vector2(172.0, -30.6), "color": GiltPalette.LAMP_WARM, "energy": 0.55},
		{"p": Vector2(165.0, -29.0), "color": GiltPalette.LAMP_NEON, "energy": 0.35},
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
	# Лодка на воде качается на собственной волне.
	for entry in _boats:
		var node: Node3D = entry["node"]
		if not is_instance_valid(node):
			continue
		var phase := float(entry["phase"])
		node.position.y = float(entry["base_y"]) + sin(_time * 0.9 + phase) * float(entry["amp"])
		node.rotation.z = sin(_time * 0.7 + phase) * 0.025
		node.rotation.x = cos(_time * 0.55 + phase) * 0.018
	# Чайки ходят кругами и машут крыльями — дешёвая, но настоящая жизнь.
	for entry in _gulls:
		var node: Node3D = entry["node"]
		if not is_instance_valid(node):
			continue
		var angle := _time * float(entry["speed"]) + float(entry["phase"])
		var center: Vector2 = entry["center"]
		var radius := float(entry["radius"])
		node.position = Vector3(center.x + cos(angle) * radius,
			float(entry["height"]) + sin(angle * 2.1) * 0.35,
			center.y + sin(angle) * radius)
		node.rotation.y = -angle - PI * 0.5
		var flap := sin(_time * 7.5 + float(entry["phase"])) * 0.55
		(entry["left"] as Node3D).rotation.z = flap
		(entry["right"] as Node3D).rotation.z = -flap
