class_name IslandVillage
extends Node3D
## Посёлок «Золочёный прилив» — перестроен из пяти коробок в настоящую
## улицу при бухте.
##
## Что изменилось по сравнению со старой сеткой (docs/world/harbor_village.md):
##   • ДВЕ улицы вместо одной: набережная идёт от причала вдоль берега (так
##     её видно с воды), а Верхняя поднимается на плато к часовне;
##   • ПЛОЩАДЬ с фонтаном, аркой и прилавками — там сходятся обе улицы;
##   • ЧАСОВНЯ на восточном подъёме даёт силуэт: шпиль, роза, звонница;
##   • дома больше не одинаковые: пять разных построек, у каждой своя
##     надстройка, своя краска витража и своя вывеска;
##   • дороги — не две полосы, а мостовая со швами, бордюром и брусчаткой
##     на площади; переходы, фонари, ограды, сушильни, бочки;
##   • у причала — рынок, колокол и склад, у храма — часовня и лестница.
##
## Всё ставится по настоящему рельефу (coast.ground_height): ничего не висит
## и не тонет. Расстановка читает HOUSE_SITES — тест проверяет именно её.

const COTTAGE := preload("res://scenes/village/cottage.tscn")

## Семь домов: набережная + Верхняя улица. style — какой силуэт строить,
## yaw — куда смотрит вход (0 = на юг, к набережной).
## Верхний ряд смотрит входами на набережную (на юг, yaw = 0), нижний —
## на верхнюю улицу (на север, yaw = PI). Дом-башня и звонница стоят на
## площади как её фасады. Дома-склады уходят к урезу, за рынок.
const HOUSE_SITES := [
	{"name": "CottageLane", "at": Vector2(178.5, -22.6), "yaw": 0.0, "style": 0},
	{"name": "CottageQuay", "at": Vector2(187.0, -22.4), "yaw": 0.0, "style": 3},
	{"name": "CottageUpper", "at": Vector2(206.0, -12.6), "yaw": PI, "style": 2},
	{"name": "CottageTower", "at": Vector2(205.4, -24.6), "yaw": -0.62, "style": 1},
	{"name": "CottageParsonage", "at": Vector2(198.0, -12.0), "yaw": PI, "style": 4},
	{"name": "CottageNetmaker", "at": Vector2(189.0, -12.0), "yaw": PI, "style": 0},
	{"name": "CottageHill", "at": Vector2(213.0, -29.4), "yaw": PI * 0.5, "style": 3},
]

## Набережная: от причала вдоль бухты и вверх к площади.
## Набережная идёт по краю плато: с воды видно и дорогу, и дома за ней.
## Высота плато 4 м держится до z ≈ −13, поэтому улица не сползает на пляж.
const QUAY_LANE := [
	Vector2(167.4, -28.4), Vector2(170.6, -24.8), Vector2(176.0, -20.4),
	Vector2(183.0, -17.0), Vector2(190.0, -15.0), Vector2(197.0, -14.6),
	Vector2(203.0, -14.8), Vector2(208.6, -16.6), Vector2(212.6, -19.6),
	Vector2(215.0, -23.4), Vector2(216.2, -27.8),
]
## Верхняя улица: от площади на плато к часовне и дальше на восток.
## Верхняя улица поднимается от площади вдоль внутренней стороны домов.
const UPPER_LANE := [
	Vector2(196.0, -25.4), Vector2(197.4, -22.0), Vector2(199.6, -19.4),
	Vector2(203.0, -18.2), Vector2(207.0, -18.6), Vector2(211.0, -20.4),
	Vector2(214.4, -23.0),
]
## Проулок к домам у храма.
## Проулок к часовне: от восточного конца набережной вверх на скалу.
const CHAPEL_WALK := [
	Vector2(213.6, -21.4), Vector2(214.6, -23.2), Vector2(215.6, -25.2),
]
const PLAZA := Vector2(198.0, -24.6)
## Мост от причала: остров живёт на 4 м над морем, и без съезда с пирса
## посёлок был бы «картинкой на скале». Три пролёта + разворотная площадка.
const PIER_Y := 1.42
const BRIDGE_END := Vector2(166.4, -28.6)
const BRIDGE_SEGMENTS := 3
const PLAZA_RADIUS := 5.6
const CHAPEL_AT := Vector2(210.8, -40.2)
## Прибрежный храм-фонарь: набережная выходит к воде, там посёлок и
## «прощается» с морем. Виден с лодки при заходе в бухту.
const SHRINE_AT := Vector2(173.2, -18.4)
const FOUNDATION_BOTTOM := -0.42


var main: BoatMain
var cottages: Array[GiltCottage] = []
var chapel: GiltChapel
var shrine: GiltShrine
var props: GiltProps
var plaza: Node3D
var _lamps: Array[OmniLight3D] = []
var _lamp_strength: Array[float] = []
var _day_night := -1.0


func setup(owner_main: BoatMain) -> void:
	main = owner_main
	name = "HarborVillage"
	props = GiltProps.new()
	props.setup(main, self)
	_build_bridge()
	_build_roads()
	_build_plaza()
	for site in HOUSE_SITES:
		_build_house(site)
	_build_chapel()
	_build_shrine()
	_build_market()
	_build_details()
	_build_lighting()
	set_night(main.night01)


# --- Съезд с причала -------------------------------------------------------

## Съезд-мост от края пирса (x = 159) на плато посёлка: три пролёта на
## каменных опорах, перила и фонари. Море здесь поднимается к берегу на
## 3 м за 7 м пути, поэтому настил идёт «ступенями террасы» — так строят
## съезды на скалистых причалах; автомобильного геймплея нет, это
## архитектура, которая объясняет связь посёлка с пирсом.
func _build_bridge() -> void:
	var start := Vector3(159.4, PIER_Y, -28.6)
	var finish := Vector3(BRIDGE_END.x, main.coast.ground_height(BRIDGE_END.x, BRIDGE_END.y) + 0.12,
		BRIDGE_END.y)
	var st := GiltShapes.begin()
	# Настил: поперечные доски; высота — по рельефу с запасом 0.35 м, чтобы
	# доска не тонула в склоне (иначе мост «пропадает» на середине).
	var planks := 30
	for i in range(planks):
		var t := (float(i) + 0.5) / float(planks)
		var p := start.lerp(finish, t)
		var deck := maxf(lerpf(start.y, finish.y, smoothstep01(t)),
			main.coast.ground_height(p.x, p.z) + 0.34)
		GiltShapes.box(st, Vector3(p.x, deck, p.z), Vector3(0.36, 0.10, 3.4),
			GiltPalette.WOOD_WARM.darkened(0.08 + 0.08 * float(i % 3) / 3.0))
	# Продольные балки под настилом: три нити, «двойное» дерево.
	for side in [-1.0, 0.0, 1.0]:
		var z: float = -28.6 + float(side) * 1.5
		var prev := Vector3.ZERO
		for k in range(0, 9):
			var t := float(k) / 8.0
			var p := start.lerp(finish, t)
			var deck := maxf(lerpf(start.y, finish.y, smoothstep01(t)),
				main.coast.ground_height(p.x, p.z) + 0.34) - 0.16
			if k > 0:
				GiltShapes.beam(st, prev, Vector3(p.x, deck, z), 0.14, GiltPalette.WOOD_DARK)
			prev = Vector3(p.x, deck, z)
	# Опоры: каменные пилоны на пролётах, каждый — до земли.
	for k in range(1, BRIDGE_SEGMENTS):
		var t := float(k) / float(BRIDGE_SEGMENTS)
		var p := start.lerp(finish, t)
		var deck := maxf(lerpf(start.y, finish.y, smoothstep01(t)),
			main.coast.ground_height(p.x, p.z) + 0.34)
		var ground := main.coast.ground_height(p.x, p.z)
		for z in [-29.9, -27.3]:
			var h := maxf(0.4, deck - ground)
			GiltShapes.box(st, Vector3(p.x, ground + h * 0.5, float(z)),
				Vector3(0.46, h, 0.46), Color("262b38"))
			GiltShapes.box(st, Vector3(p.x, deck - 0.30, float(z)),
				Vector3(0.62, 0.22, 0.62), GiltPalette.STONE_COLD * 0.5)
	# Перила: стойки, две нити, золотые навершия. Высота — над настилом.
	var rails := 26
	for i in range(rails + 1):
		var t := float(i) / float(rails)
		var p := start.lerp(finish, t)
		var deck := maxf(lerpf(start.y, finish.y, smoothstep01(t)),
			main.coast.ground_height(p.x, p.z) + 0.34)
		for z in [-30.2, -27.0]:
			GiltShapes.beam(st, Vector3(p.x, deck + 0.04, float(z)),
				Vector3(p.x, deck + 0.92, float(z)), 0.055, GiltPalette.IRON)
			if i % 3 == 0:
				GiltShapes.spire(st, Vector3(p.x, deck + 0.92, float(z)), 0.07, 0.16,
					GiltPalette.GILT * 0.8, 4, PI * 0.25)
	for z in [-30.2, -27.0]:
		var prev := Vector3(0.0, start.y + 0.86, float(z))
		for k in range(0, 9):
			var t := float(k) / 8.0
			var p := start.lerp(finish, t)
			var deck := maxf(lerpf(start.y, finish.y, smoothstep01(t)),
				main.coast.ground_height(p.x, p.z) + 0.34) + 0.86
			if k > 0:
				GiltShapes.beam(st, prev, Vector3(p.x, deck, float(z)), 0.07, GiltPalette.IRON)
			prev = Vector3(p.x, deck, float(z))
	var mesh := MeshInstance3D.new()
	mesh.name = "PierBridge"
	mesh.mesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.9
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.material_override = mat
	add_child(mesh)
	# Фонари на съезде: их видно с воды раньше, чем дома.
	props.begin()
	for t in [0.32, 0.74]:
		var p := start.lerp(finish, t)
		var deck := maxf(lerpf(start.y, finish.y, smoothstep01(t)),
			main.coast.ground_height(p.x, p.z) + 0.34)
		props.lamp_post(Vector3(p.x, deck, -30.35), 2.5, true)
	props.commit(self)


static func smoothstep01(t: float) -> float:
	var c := clampf(t, 0.0, 1.0)
	return c * c * (3.0 - 2.0 * c)


# --- Дома -----------------------------------------------------------------

func _build_house(site: Dictionary) -> void:
	var at: Vector2 = site["at"]
	var yaw: float = site["yaw"]
	var rotation_basis := Basis(Vector3.UP, yaw)
	var min_ground := INF
	var max_ground := -INF
	# Обойти все углы до установки: ни утонувших стен, ни свай в воздухе.
	for x in [-GiltCottage.WIDTH * 0.5, GiltCottage.WIDTH * 0.5]:
		for z in [-GiltCottage.DEPTH * 0.5, GiltCottage.DEPTH * 0.5]:
			var p := Vector3(at.x, 0.0, at.y) + rotation_basis * Vector3(float(x), 0.0, float(z))
			var ground := main.coast.ground_height(p.x, p.z)
			min_ground = minf(min_ground, ground)
			max_ground = maxf(max_ground, ground)
	var floor_height := max_ground + 0.10
	var cottage := COTTAGE.instantiate() as GiltCottage
	cottage.name = site["name"]
	cottage.position = Vector3(at.x, floor_height, at.y)
	cottage.rotation.y = yaw
	add_child(cottage)
	cottage.build(int(site["style"]), min_ground - floor_height)
	cottages.append(cottage)


func _build_chapel() -> void:
	# Углы считаем через поворот: часовня стоит фасадом к площади (запад),
	# а её длина идёт по оси X, поэтому rotate(PI) меняет знак у LENGTH.
	var min_ground := INF
	var max_ground := -INF
	for x in [-GiltChapel.LENGTH * 0.5, GiltChapel.LENGTH * 0.5]:
		for z in [-GiltChapel.WIDTH * 0.5, GiltChapel.WIDTH * 0.5]:
			var ground := main.coast.ground_height(CHAPEL_AT.x - float(x), CHAPEL_AT.y + float(z))
			min_ground = minf(min_ground, ground)
			max_ground = maxf(max_ground, ground)
	var floor_height := max_ground + 0.12
	chapel = GiltChapel.new()
	chapel.name = "Chapel"
	chapel.position = Vector3(CHAPEL_AT.x, floor_height, CHAPEL_AT.y)
	# Фасад смотрит на площадь (−X мира), алтарь — на восток, к морю.
	chapel.rotation.y = PI
	add_child(chapel)
	chapel.build()
	# Коллизия: объём нефа с запасом до конька.
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
	# Подземный ярус: часовня стоит на скале, склон уходит вниз на 1.8 м.
	# Каменный подиум в два отступа — готический «андеркрофт», а не газон под
	# домом: без него западный фасад висел бы над склоном, а ступени парили.
	var podium := GiltShapes.begin()
	var lowest := floor_height
	for x in [-GiltChapel.LENGTH * 0.5, GiltChapel.LENGTH * 0.5]:
		for z in [-GiltChapel.WIDTH * 0.5, GiltChapel.WIDTH * 0.5]:
			lowest = minf(lowest, main.coast.ground_height(CHAPEL_AT.x - float(x),
				CHAPEL_AT.y + float(z)))
	var depth := maxf(0.55, floor_height - 0.30 - lowest)
	var courses := 3
	for i in range(courses):
		var h := depth / float(courses)
		var shrink := float(i) * 0.24
		GiltShapes.box(podium,
			Vector3(CHAPEL_AT.x, floor_height - 0.22 - h * (float(i) + 0.5), CHAPEL_AT.y),
			Vector3(GiltChapel.LENGTH + 1.0 - shrink, h + 0.02, GiltChapel.WIDTH + 1.0 - shrink),
			Color("22262f").darkened(0.06 * float(i)))
	# Золотая нить по кромке подиума: читается, что это архитектура.
	GiltShapes.beam(podium, Vector3(CHAPEL_AT.x - 3.9, floor_height - 0.18, CHAPEL_AT.y - 2.6),
		Vector3(CHAPEL_AT.x - 3.9, floor_height - 0.18, CHAPEL_AT.y + 2.6), 0.05,
		GiltPalette.GILT * 0.7)
	# Парадная лестница с площади: ступени идут вниз к тропе и не висят.
	var steps := Node3D.new()
	steps.name = "ChapelSteps"
	add_child(steps)
	var count := 9
	for i in range(count):
		var t := float(i) / float(count - 1)
		var x := CHAPEL_AT.x - GiltChapel.LENGTH * 0.5 - 0.58 - float(i) * 0.34
		var step_y := lerpf(floor_height - 0.16, main.coast.ground_height(x, CHAPEL_AT.y) + 0.06, t)
		GiltShapes.box(podium, Vector3(x, step_y, CHAPEL_AT.y),
			Vector3(0.40, 0.30, 3.0 - t * 0.4), GiltPalette.STONE_COLD * (0.42 + 0.12 * t))
	# Балюстрада по бокам лестницы: ряд фиалов на подъёме.
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


## Прибрежный храм-фонарь: посёлок «прощается» с морем в этой точке.
## Стоит на склоне, поэтому у него свой каменный плинт и ступени от улицы.
func _build_shrine() -> void:
	var min_ground := INF
	var max_ground := -INF
	for x in [-1.6, 1.6]:
		for z in [-1.3, 1.3]:
			var ground := main.coast.ground_height(SHRINE_AT.x + float(x), SHRINE_AT.y + float(z))
			min_ground = minf(min_ground, ground)
			max_ground = maxf(max_ground, ground)
	var floor_height := max_ground + 0.16
	shrine = GiltShrine.new()
	shrine.name = "ShoreShrine"
	shrine.position = Vector3(SHRINE_AT.x, floor_height, SHRINE_AT.y)
	# Фасад с дверью (+Z) смотрит на набережную: к нему ведут ступени.
	shrine.rotation.y = 0.20
	add_child(shrine)
	shrine.build()
	# Коллизия: габарит храма с запасом на крышу.
	var solid := StaticBody3D.new()
	solid.name = "ShrineCollision"
	solid.position = shrine.position
	add_child(solid)
	var box := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.9, GiltShrine.HEIGHT + 1.4, 2.3)
	box.shape = shape
	box.position = Vector3(0.0, (GiltShrine.HEIGHT + 1.4) * 0.5, 0.0)
	solid.add_child(box)
	# Плинт до нижнего угла склона + ступени с улицы: ничего не парит.
	var st := GiltShapes.begin()
	var depth := maxf(0.35, floor_height - min_ground + 0.20)
	GiltShapes.box(st, Vector3(SHRINE_AT.x, floor_height - depth * 0.5 - 0.06, SHRINE_AT.y),
		Vector3(3.1, depth + 0.12, 2.6), Color("22262f"))
	GiltShapes.box(st, Vector3(SHRINE_AT.x, floor_height - 0.02, SHRINE_AT.y),
		Vector3(3.35, 0.16, 2.85), GiltPalette.STONE_COLD * 0.48)
	for i in range(4):
		var z := SHRINE_AT.y + 1.45 + float(i) * 0.34
		var h := main.coast.ground_height(SHRINE_AT.x, z)
		var step_y := lerpf(floor_height - 0.20, h + 0.06, float(i) / 3.0)
		GiltShapes.box(st, Vector3(SHRINE_AT.x, step_y, z), Vector3(1.5, 0.26, 0.36),
			GiltPalette.STONE_COLD * 0.44)
	# Фонарный столб у ступеней — точка, по которой храм находят ночью.
	props.begin()
	var lamp_y := main.coast.ground_height(SHRINE_AT.x - 1.1, SHRINE_AT.y + 2.1)
	props.lamp_post(Vector3(SHRINE_AT.x - 1.1, lamp_y, SHRINE_AT.y + 2.1), 2.8, true)
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


# --- Дороги и площадь ------------------------------------------------------

func _build_roads() -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Набережная: 3.2 м, две полосы брусчатки со швом по центру.
	_road_strip(surface, QUAY_LANE, 3.2, true)
	# Верхняя улица уже и без шва: «переулок».
	_road_strip(surface, UPPER_LANE, 2.4, false)
	_road_strip(surface, CHAPEL_WALK, 2.0, false)
	# Дорожки к дверям: не бьют в стены, а заканчиваются у крыльца.
	for site in HOUSE_SITES:
		var at: Vector2 = site["at"]
		var yaw: float = site["yaw"]
		var front := Vector3(0.0, 0.0, GiltCottage.DEPTH * 0.5 + 0.5)
		var world_front := Vector3(at.x, 0.0, at.y) + Basis(Vector3.UP, yaw) * front
		var anchor := _nearest_on_lane(at, yaw)
		_road_strip(surface, [anchor, Vector2(world_front.x, world_front.z)], 1.05, false)
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


## Точка улицы, ближайшая к дому: дорожка всегда приходит «с улицы».
func _nearest_on_lane(at: Vector2, yaw: float) -> Vector2:
	var front := Vector3(at.x, 0.0, at.y) + Basis(Vector3.UP, yaw) * Vector3(0.0, 0.0, 2.6)
	var best := Vector2(front.x, front.z)
	var best_d := INF
	for lane in [QUAY_LANE, UPPER_LANE, CHAPEL_WALK]:
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
		var steps := maxi(1, int(ceil(a.distance_to(b) / 1.0)))
		for j in range(steps):
			var p0 := a.lerp(b, float(j) / float(steps))
			var p1 := a.lerp(b, float(j + 1) / float(steps))
			# Пять полос: кромки темнее, центр светлее — мостовая, а не краска.
			for band in range(5):
				var d0 := lerpf(-width * 0.5, width * 0.5, float(band) / 5.0)
				var d1 := lerpf(-width * 0.5, width * 0.5, float(band + 1) / 5.0)
				var edge := band == 0 or band == 4
				var c0 := Color("4a4a58") if edge else Color("6d6a74")
				var c1 := Color("4a4a58") if edge else Color("6d6a74")
				if not edge:
					c0 = c0.lerp(Color("8a8490"), 0.35)
					c1 = c1.lerp(Color("8a8490"), 0.35)
				_road_triangle(surface, p0 + side * d0, p1 + side * d0, p1 + side * d1, c0, c0, c1)
				_road_triangle(surface, p0 + side * d0, p1 + side * d1, p0 + side * d1, c0, c1, c1)
			# Шов по центру: тёмная нить, которая читается как стык мостовой.
			if seam:
				var t := float(j) / float(steps)
				var shade := Color("3c3c48") if int(t * 4.0) % 2 == 0 else Color("474754")
				_road_triangle(surface, p0 - side * 0.05, p1 - side * 0.05, p1 + side * 0.05,
					shade, shade, shade)
				_road_triangle(surface, p0 - side * 0.05, p1 + side * 0.05, p0 + side * 0.05,
					shade, shade, shade)
			# Поперечные швы брусчатки — каждые ~1.2 м.
			if j % 2 == 0:
				_road_triangle(surface, p0 - side * width * 0.5, p0 + side * width * 0.5,
					p0 + side * width * 0.45, Color("3a3a46"), Color("3a3a46"), Color("3a3a46"))


func _road_triangle(surface: SurfaceTool, a: Vector2, b: Vector2, c: Vector2,
		ca: Color, cb: Color, cc: Color) -> void:
	for entry in [[a, ca], [b, cb], [c, cc]]:
		var p: Vector2 = entry[0]
		surface.set_color(entry[1])
		surface.set_normal(main.coast.ground_normal(p.x, p.y))
		surface.add_vertex(Vector3(p.x, main.coast.ground_height(p.x, p.y) + 0.055, p.y))


## Площадь: брусчатка кругом, бордюр, фонтан, арка, фонари по осям.
func _build_plaza() -> void:
	plaza = Node3D.new()
	plaza.name = "Plaza"
	add_child(plaza)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings := 9
	var segs := 28
	var center_h := main.coast.ground_height(PLAZA.x, PLAZA.y)
	for r in range(rings):
		var r0 := PLAZA_RADIUS * float(r) / float(rings)
		var r1 := PLAZA_RADIUS * float(r + 1) / float(rings)
		for s in range(segs):
			var a0 := TAU * float(s) / float(segs)
			var a1 := TAU * float(s + 1) / float(segs)
			# Шахматный рисунок брусчатки: два оттенка по (r + s).
			var tone := Color("726c78") if (r + s) % 2 == 0 else Color("635e6b")
			if r == rings - 1:
				tone = Color("4b4b58") # бордюр по краю
			var p00 := _plaza_point(PLAZA, r0, a0)
			var p10 := _plaza_point(PLAZA, r1, a0)
			var p11 := _plaza_point(PLAZA, r1, a1)
			var p01 := _plaza_point(PLAZA, r0, a1)
			for tri in [[p00, p10, p11], [p00, p11, p01]]:
				for p: Vector3 in tri:
					surface.set_color(tone)
					surface.set_normal(Vector3.UP)
					surface.add_vertex(p)
	var mesh := MeshInstance3D.new()
	mesh.name = "PlazaPaving"
	mesh.mesh = surface.commit()
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.95
	mesh.material_override = material
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	plaza.add_child(mesh)
	# Фонтан в центре, арка на выходе к часовне и четыре фонаря по осям.
	props.begin()
	props.fountain(Vector3(PLAZA.x, center_h + 0.02, PLAZA.y))
	props.arch(Vector3(PLAZA.x + 3.9, center_h, PLAZA.y + 3.2), 1.9, -0.72)
	for i in range(4):
		var ang := TAU * float(i) / 4.0 + 0.4
		var p := _plaza_xy(PLAZA_RADIUS - 0.9, ang)
		var h := main.coast.ground_height(p.x, p.y)
		props.lamp_post(Vector3(p.x, h, p.y), 3.3, i % 2 == 0)
	props.commit(plaza)


func _plaza_point(center: Vector2, radius: float, angle: float) -> Vector3:
	var p := _plaza_xy_around(center, radius, angle)
	return Vector3(p.x, main.coast.ground_height(p.x, p.y) + 0.06, p.y)


func _plaza_xy(radius: float, angle: float) -> Vector2:
	return _plaza_xy_around(PLAZA, radius, angle)


func _plaza_xy_around(center: Vector2, radius: float, angle: float) -> Vector2:
	return Vector2(center.x + cos(angle) * radius, center.y + sin(angle) * radius)


# --- Рынок у причала -------------------------------------------------------

func _build_market() -> void:
	var market := Node3D.new()
	market.name = "QuayMarket"
	add_child(market)
	props.begin()
	# Ворота посёлка — там, где дорожка выходит с причала на берег.
	props.gate(Vector3(BRIDGE_END.x, main.coast.ground_height(BRIDGE_END.x, BRIDGE_END.y) + 0.05,
		BRIDGE_END.y), 2.6, 0.30)
	# Прилавки вдоль набережной: два под тентами, один склад.
	props.stall(Vector3(174.2, main.coast.ground_height(174.2, -26.6), -26.6), 0.0)
	props.stall(Vector3(180.6, main.coast.ground_height(180.6, -26.2), -26.2), 0.0)
	props.store_hut(Vector3(170.0, main.coast.ground_height(170.0, -31.6), -31.6), -0.12)
	# Колокол у съезда с причала: формальный «вход в порт».
	props.mooring_bell(Vector3(168.0, main.coast.ground_height(168.0, -23.4), -23.4))
	# Ограда между рынком и водой: посёлок не «стекает» в бухту.
	for i in range(4):
		var x := 169.0 + float(i) * 3.4
		var a := Vector3(x, main.coast.ground_height(x, -32.2), -32.2)
		var b := Vector3(x + 3.4, main.coast.ground_height(x + 3.4, -32.2), -32.2)
		props.fence(a, b)
	props.commit(market)
	# Бочки и ящики — одной сеткой на весь рынок.
	props.begin()
	for p in [Vector2(172.8, -25.4), Vector2(177.4, -29.8), Vector2(183.2, -24.2)]:
		var h := main.coast.ground_height(p.x, p.y)
		props.barrel(Vector3(p.x, h, p.y), 0.82, 0.30)
		props.barrel(Vector3(p.x + 0.62, h, p.y + 0.24), 0.72, 0.27)
	props.commit(market)


# --- Детали и «жизнь» ------------------------------------------------------

func _build_details() -> void:
	var details := Node3D.new()
	details.name = "VillageLife"
	add_child(details)
	props.begin()
	# Фонари вдоль набережной: ритм, по которому улица читается вечером.
	for i in range(4):
		var t := (float(i) + 0.5) / 4.0
		var p := _lane_point(QUAY_LANE, t)
		var side := 2.1 if i % 2 == 0 else -2.1
		var q := p + Vector2(0.0, side)
		var h := main.coast.ground_height(q.x, q.y)
		props.lamp_post(Vector3(q.x, h, q.y), 3.2, i % 3 == 1)
	# Фонари Верхней улицы — холоднее (бирюза), это «новый» свет посёлка.
	for i in range(2):
		var t := (float(i) + 1.0) / 3.0
		var p := _lane_point(UPPER_LANE, t)
		var q := p + Vector2(1.5, 0.0)
		var h := main.coast.ground_height(q.x, q.y)
		props.lamp_post(Vector3(q.x, h, q.y), 3.4, true)
	# Сушильни для сетей у домов на набережной.
	props.drying_rack(Vector3(184.4, main.coast.ground_height(184.4, -19.0), -19.0), 0.1)
	props.drying_rack(Vector3(203.6, main.coast.ground_height(203.6, -20.6), -20.6), -0.2)
	# Ограды палисадников: камень + ковка, по два пролёта у каждого дома.
	for site in HOUSE_SITES:
		if int(site["style"]) not in [0, 2, 3]:
			continue
		var at: Vector2 = site["at"]
		var yaw: float = site["yaw"]
		var bx := Basis(Vector3.UP, yaw)
		for sx in [-1.0, 1.0]:
			var a := Vector3(at.x, 0.0, at.y) + bx * Vector3(float(sx) * 2.45, 0.0, 2.55)
			var b := Vector3(at.x, 0.0, at.y) + bx * Vector3(float(sx) * 3.75, 0.0, 2.55)
			a.y = main.coast.ground_height(a.x, a.z)
			b.y = main.coast.ground_height(b.x, b.z)
			props.fence(a, b, false)
	# Деревянные уличные «палисадники» с цветами: пятна цвета на мостовой.
	for p in [Vector2(174.8, -22.4), Vector2(182.6, -22.8), Vector2(194.4, -21.6)]:
		var h := main.coast.ground_height(p.x, p.y)
		props.barrel(Vector3(p.x, h, p.y), 0.55, 0.42)
	# Бочки и ящики у домов — посёлок живёт, а не позирует.
	for p in [Vector2(181.6, -25.6), Vector2(196.4, -27.8), Vector2(209.0, -21.4),
			Vector2(211.2, -33.2), Vector2(193.2, -17.4)]:
		var h := main.coast.ground_height(p.x, p.y)
		props.barrel(Vector3(p.x, h, p.y), 0.80, 0.30)
	props.commit(details)


## Точка на ломаной в доле t (по длине сегментов) — для фонарей вдоль улиц.
func _lane_point(lane: Array, t: float) -> Vector2:
	var total := 0.0
	for i in range(lane.size() - 1):
		total += (lane[i + 1] as Vector2).distance_to(lane[i] as Vector2)
	var target := total * clampf(t, 0.0, 1.0)
	var walked := 0.0
	for i in range(lane.size() - 1):
		var a: Vector2 = lane[i]
		var b: Vector2 = lane[i + 1]
		var seg := a.distance_to(b)
		if walked + seg >= target:
			return a.lerp(b, (target - walked) / maxf(seg, 0.001))
		walked += seg
	return lane[lane.size() - 1] as Vector2


# --- Ночной свет -----------------------------------------------------------

func _build_lighting() -> void:
	# Дополнительные тёплые пятна: входы домов уже светятся сами, а здесь —
	# редкие «фонарные» источники, чтобы улица не была чёрной между домами.
	for p in [Vector2(172.4, -26.2), Vector2(206.4, -18.8)]:
		var h := main.coast.ground_height(p.x, p.y)
		var lamp := OmniLight3D.new()
		lamp.position = Vector3(p.x, h + 2.4, p.y)
		lamp.light_color = GiltPalette.LAMP_WARM
		lamp.omni_range = 6.5
		lamp.shadow_enabled = false
		lamp.light_volumetric_fog_energy = 0.5
		add_child(lamp)
		_lamps.append(lamp)
		_lamp_strength.append(0.42)


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
		_lamps[i].light_energy = maxf(0.0, amount - 0.26) * _lamp_strength[i] * 1.6


func _process(_delta: float) -> void:
	if main == null:
		return
	if absf(main.night01 - _day_night) > 0.015:
		set_night(main.night01)
