class_name GiltCottage
extends Node3D
## Дом посёлка «Золочёный прилив»: ОДНА процедурная постройка, но у каждого
## места свой характер. Пять одинаковых коробок с разной краской — это и
## было главное «роботизированное» впечатление старого посёлка.
##
## Что делает дом отдельным:
##   • силуэт — эркер, угловая башня, звонница, портик, контрфорсы;
##   • примета — флюгер, вывеска, роза-окно, колокол, крабы на гребне;
##   • свет — своя краска витража (розовый, бирюза, сирень) и свой фонарь;
##   • жизнь — поленница, горшки на подоконнике, крыльцо, дым из трубы.
##
## Геометрия собирается в SurfaceTool по материалам и запекается в пять
## сеток. Цвет — вершинный, поэтому камень, шифер и золото делят материал,
## но не выглядят одинаково.
##
## Координаты прежние (docs/world/harbor_village.md): начало — центр пола,
## +Y вверх, вход в локальную +Z, +X влево по фасаду. Габарит WIDTH × DEPTH
## и коллизия не изменились — расстановку можно двигать независимо.

const WIDTH := 5.8
const DEPTH := 4.3
const EAVES := 2.35
const RIDGE := 4.2

## Замена всей процедурной части готовой сценой (Blender) — прежний крючок.
@export var replacement_visual: PackedScene

var window_material: StandardMaterial3D
var style := 0
var night01 := 0.0
var palette := {}

var _stone: SurfaceTool
var _roof: SurfaceTool
var _gilt: SurfaceTool
var _glass: SurfaceTool
var _wood: SurfaceTool
var _glow_nodes: Array[MeshInstance3D] = []
var _light: OmniLight3D
var _foundation_bottom := 0.0


## Точка входа, как у прежнего VillageCottage: вариант стиля и насколько
## земля ниже пола (фундамент дотягивается до неё, а не висит).
func build(variant: int, foundation_bottom: float) -> void:
	style = variant % 5
	_foundation_bottom = foundation_bottom
	palette = _palette_for(style)
	_collision()
	if replacement_visual != null:
		var replacement := replacement_visual.instantiate()
		replacement.name = "ReplacementVisual"
		add_child(replacement)
		window_material = _glass_material()
		return
	_stone = GiltShapes.begin()
	_roof = GiltShapes.begin()
	_gilt = GiltShapes.begin()
	_glass = GiltShapes.begin()
	_wood = GiltShapes.begin()
	_foundation(foundation_bottom)
	_walls()
	_roof_and_eaves()
	match style:
		0:
			_oriel()
			_dormer(Vector3(1.72, 3.50, 1.42))
		1:
			_corner_tower()
		2:
			_belfry()
		3:
			_porch()
			_rose_window(Vector3(0.0, EAVES + 0.62, DEPTH * 0.5 + 0.03), 0.56)
		4:
			_buttresses()
			_rose_window(Vector3(0.0, EAVES + 0.58, DEPTH * 0.5 + 0.03), 0.62)
	_details()
	_commit()
	set_night(night01)


## Палитра дома: камень, шифер, эмаль, краска витража. Три дома вечерние
## (розовый, сирень, бордо), два — бирюзовые: посёлок перестаёт быть
## рядом одинаковых хат, но палитра остаётся одной семьёй.
func _palette_for(variant: int) -> Dictionary:
	var walls := [
		Color("1a1e29"), Color("232839"), Color("1d2130"), Color("241f2e"), Color("1c2630"),
	]
	var roofs := [GiltPalette.SLATE, Color("1f2735"), Color("26303c"), Color("22202e"), GiltPalette.SLATE]
	var glass := [
		GiltPalette.LAMP_MAGENTA, GiltPalette.LAMP_NEON, GiltPalette.LAMP_VIOLET,
		Color("ff9bb0"), Color("b8ffe8"),
	]
	var enamel := [
		GiltPalette.ENAMEL, Color("1f5f6b"), Color("2f4a6b"), Color("6b2f4a"), Color("4a3a6b"),
	]
	return {
		"wall": walls[variant % walls.size()],
		"roof": roofs[variant % roofs.size()],
		"glass": glass[variant % glass.size()],
		"enamel": enamel[variant % enamel.size()],
	}


func _collision() -> void:
	var solid := StaticBody3D.new()
	solid.name = "BuildingCollision"
	add_child(solid)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	# Запас до конька: под крышу нельзя пролезть, а лопатки и эркер входят
	# в габарит с небольшим выступом.
	shape.size = Vector3(WIDTH + 0.5, RIDGE + 0.6, DEPTH + 0.7)
	collision.shape = shape
	collision.position.y = (RIDGE + 0.6) * 0.5 - 0.1
	solid.add_child(collision)


func _foundation(foundation_bottom: float) -> void:
	# Цоколь доходит до неровной земли и читается как скала, а не как плинт.
	var depth := maxf(0.30, -foundation_bottom + 0.16)
	GiltShapes.box(_stone, Vector3(0.0, -depth * 0.5, 0.0),
		Vector3(WIDTH + 0.20, depth, DEPTH + 0.22), palette["wall"].darkened(0.35))
	# На склоне цоколь высокий. Горизонтальные швы кладки превращают его из
	# «растянутой коробки» в каменный подклет — так строят на уклоне.
	if depth > 0.55:
		var courses := maxi(2, int(depth / 0.34))
		for i in range(courses):
			var y := -0.04 - (float(i) + 0.5) * depth / float(courses)
			GiltShapes.box(_stone, Vector3(0.0, y, 0.0),
				Vector3(WIDTH + 0.24, 0.03, DEPTH + 0.26), GiltPalette.LEAD * 0.55)
	# Поясок: светлая кромка камня на уровне пола — дом «сидит».
	GiltShapes.box(_stone, Vector3(0.0, 0.07, 0.0),
		Vector3(WIDTH + 0.34, 0.14, DEPTH + 0.36), GiltPalette.STONE_COLD * 0.62)


func _walls() -> void:
	var wall: Color = palette["wall"]
	var body_w := WIDTH - 0.34
	var body_d := DEPTH - 0.34
	GiltShapes.box(_stone, Vector3(0.0, EAVES * 0.5, 0.0), Vector3(body_w, EAVES, body_d), wall)
	# Лопатки по рёбрам + горизонтальные швы: каменная кладка, а не сайдинг.
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var x: float = float(sx) * body_w * 0.5
			var z: float = float(sz) * body_d * 0.5
			GiltShapes.box(_stone, Vector3(x, EAVES * 0.5, z), Vector3(0.30, EAVES, 0.30),
				GiltPalette.STONE_COLD * 0.56)
			for i in range(7):
				var y := 0.20 + float(i) * (EAVES - 0.26) / 7.0
				GiltShapes.box(_stone, Vector3(x, y, z), Vector3(0.34, 0.032, 0.34),
					GiltPalette.LEAD * 0.5)
	# Выступ цоколя по периметру: тень по низу стены.
	GiltShapes.box(_stone, Vector3(0.0, 0.32, 0.0),
		Vector3(body_w + 0.10, 0.16, body_d + 0.10), wall.darkened(0.22))


## Крыша: готика начинается с силуэта. Скаты, щипцы, гребень, крабы, фиал.
func _roof_and_eaves() -> void:
	var roof_col: Color = palette["roof"]
	var ridge_h := GiltShapes.gable_roof(_roof, Vector3.ZERO, WIDTH, DEPTH,
		EAVES, RIDGE - EAVES, roof_col, GiltPalette.LEAD,
		palette["wall"].lightened(0.14), 0.36)
	# Карниз: золотая нить по свесу — «золочёный прилив» в одном жесте.
	for sz in [-1.0, 1.0]:
		GiltShapes.beam(_gilt, Vector3(-WIDTH * 0.5 - 0.36, EAVES - 0.02,
			float(sz) * (DEPTH * 0.5 + 0.34)),
			Vector3(WIDTH * 0.5 + 0.36, EAVES - 0.02, float(sz) * (DEPTH * 0.5 + 0.34)),
			0.045, GiltPalette.GILT * 0.82)
	# Крабы по коньку: резной силуэт вместо гладкой «крышки».
	var half_w := WIDTH * 0.5
	GiltShapes.crest(_gilt, Vector3(-half_w + 0.34, ridge_h + 0.10, 0.0),
		Vector3(half_w - 0.34, ridge_h + 0.10, 0.0), 5, 0.21, GiltPalette.GILT * 0.78)
	# Фиал на коньке — вертикаль, которую издалека читаешь как «готика».
	GiltShapes.box(_gilt, Vector3(half_w - 0.26, ridge_h + 0.14, 0.0),
		Vector3(0.20, 0.28, 0.20), GiltPalette.STONE_COLD * 0.66)
	GiltShapes.spire(_gilt, Vector3(half_w - 0.26, ridge_h + 0.28, 0.0),
		0.13, 0.66, GiltPalette.GILT, 4, PI * 0.25)
	# Труба смещена от центра: силуэт не симметричная игрушка.
	var chimney_x := -half_w * 0.54
	GiltShapes.box(_stone, Vector3(chimney_x, ridge_h - 0.10, -0.38),
		Vector3(0.46, 1.56, 0.44), palette["wall"].lightened(0.10))
	GiltShapes.chimney_top(_stone, Vector3(chimney_x, ridge_h + 0.66, -0.38), 0.46,
		GiltPalette.STONE_COLD * 0.6, GiltPalette.IRON)


## Эркер: консольный объём на кронштейнах, шатровая кровля, три ланцета.
func _oriel() -> void:
	# Эркер висит НАД дверью: фасад читается как «вход + балкон над ним»,
	# и он не спорит с ланцетом правого окна.
	var at := Vector3(0.40, 1.58, DEPTH * 0.5)
	var w := 1.62
	var h := 1.45
	GiltShapes.box(_stone, at + Vector3(0.0, h * 0.5, 0.42), Vector3(w, h, 0.95),
		palette["wall"].lightened(0.12))
	for sx in [-0.55, 0.55]:
		GiltShapes.beam(_stone, at + Vector3(float(sx), 0.06, 0.30),
			at + Vector3(float(sx) * 0.8, -0.36, -0.30), 0.10,
			GiltPalette.STONE_COLD * 0.58)
	GiltShapes.hip_roof(_roof, at + Vector3(0.0, h, 0.42), w + 0.24, 1.10,
		0.0, 0.50, palette["roof"], GiltPalette.LEAD, 0.18)
	var face := at + Vector3(0.0, 0.10, 0.90)
	for i in range(3):
		var x := face.x + (float(i) - 1.0) * w * 0.30
		GiltShapes.lancet(_glass, _gilt, Vector3(x, face.y, face.z), 0.30, 1.02,
			palette["glass"], GiltPalette.LEAD, night01, 0.05)
	# Золотая полка под эркером — единственная яркая линия на фасаде.
	GiltShapes.beam(_gilt, at + Vector3(-w * 0.52, -0.30, 0.90),
		at + Vector3(w * 0.52, -0.30, 0.90), 0.05, GiltPalette.GILT * 0.8)


## Слуховое окно в кровле: ещё один «глаз» в силуэте.
func _dormer(at: Vector3) -> void:
	GiltShapes.box(_stone, at + Vector3(0.0, 0.05, 0.0), Vector3(0.86, 0.72, 0.70),
		palette["wall"].lightened(0.16))
	GiltShapes.pent_roof(_roof, at + Vector3(0.0, 0.42, -0.10), 1.02, 0.86,
		0.16, 0.34, palette["roof"], GiltPalette.LEAD)
	GiltShapes.lancet(_glass, _gilt, at + Vector3(0.0, -0.02, 0.36), 0.36, 0.62,
		palette["glass"], GiltPalette.LEAD, night01, 0.05)
	GiltShapes.spire(_gilt, at + Vector3(0.0, 0.58, 0.14), 0.09, 0.30,
		GiltPalette.GILT * 0.86, 4, PI * 0.25)


## Угловая башня со шпилем и флюгером — «дом-маяк» посёлка.
func _corner_tower() -> void:
	var at := Vector3(-WIDTH * 0.5 + 0.55, 0.0, DEPTH * 0.5 - 0.55)
	var tower_h := 6.10
	GiltShapes.cylinder(_stone, at + Vector3(0.0, tower_h * 0.5, 0.0),
		0.92, 0.78, tower_h, palette["wall"].lightened(0.06), 14)
	for i in range(3):
		GiltShapes.cylinder(_stone, at + Vector3(0.0, 1.10 + float(i) * 1.55, 0.0),
			0.96, 0.96, 0.09, GiltPalette.STONE_COLD * 0.58, 14)
	# Ланцеты по кругу: к дороге и во двор, сзади — глухая стена.
	for i in range(6):
		var ang := 0.30 + float(i) * TAU / 6.0
		var dir := Vector3(cos(ang), 0.0, sin(ang))
		if dir.z < -0.25:
			continue
		GiltShapes.lancet(_glass, _gilt,
			at + dir * 0.84 + Vector3(0.0, 2.55, 0.0), 0.26, 0.92,
			palette["glass"], GiltPalette.LEAD, night01, 0.05,
			GiltShapes.facing(dir))
	GiltShapes.cylinder(_stone, at + Vector3(0.0, tower_h + 0.12, 0.0),
		0.98, 0.90, 0.22, GiltPalette.STONE_COLD * 0.66, 12)
	GiltShapes.spire(_roof, at + Vector3(0.0, tower_h + 0.22, 0.0), 0.84, 2.30,
		palette["roof"], 4, PI * 0.25)
	GiltShapes.crest(_gilt, at + Vector3(-0.58, tower_h + 0.30, 0.0),
		at + Vector3(0.58, tower_h + 0.30, 0.0), 3, 0.16, GiltPalette.GILT * 0.72)
	GiltShapes.cylinder(_gilt, at + Vector3(0.0, tower_h + 2.60, 0.0),
		0.045, 0.018, 0.60, GiltPalette.GILT, 6)
	# Флюгер: стрелка с пером, ловит свет в любой час.
	var vane := at + Vector3(0.0, tower_h + 2.78, 0.0)
	GiltShapes.beam(_gilt, vane + Vector3(-0.44, 0.0, 0.0), vane + Vector3(0.34, 0.0, 0.0),
		0.035, GiltPalette.GILT)
	GiltShapes.spire(_gilt, vane + Vector3(-0.44, -0.05, 0.0), 0.07, 0.16,
		GiltPalette.GILT, 4, PI * 0.25)
	GiltShapes.box(_gilt, vane + Vector3(0.24, 0.0, 0.0), Vector3(0.20, 0.14, 0.018),
		GiltPalette.GILT_HOT)


## Звонница над коньком: столбы, аркада, колокол, шатёр и шпиль.
func _belfry() -> void:
	var base_y := RIDGE + 0.05
	var span := 2.65
	var h := 1.40
	for sx in [-0.5, 0.5]:
		for sz in [-0.5, 0.5]:
			var x: float = float(sx) * span
			var z: float = float(sz) * 1.35
			GiltShapes.box(_stone, Vector3(x, base_y + h * 0.5, z), Vector3(0.28, h, 0.28),
				GiltPalette.STONE_COLD * 0.68)
	# Аркады по торцам: сквозной силуэт, через который видно небо.
	for sz in [-1.0, 1.0]:
		var z: float = float(sz) * 1.35
		for i in range(3):
			var w := span * 2.0 / 3.0 - 0.10
			var x0 := -span + float(i) * (span * 2.0 / 3.0) + w * 0.5
			var arch := GiltShapes.pointed_arch(w, 0.42, 0.78, 5)
			GiltShapes.extrude_z(_stone, arch, z - 0.07, z + 0.07, GiltPalette.BASALT,
				Vector3(x0, base_y, 0.0))
	# Колокол: конус, язык и золото — силуэт «звенит» на солнце.
	GiltShapes.cylinder(_gilt, Vector3(0.0, base_y + h - 0.30, 0.0),
		0.32, 0.17, 0.36, GiltPalette.GILT * 0.92, 10)
	GiltShapes.box(_gilt, Vector3(0.0, base_y + h - 0.52, 0.0),
		Vector3(0.05, 0.16, 0.05), GiltPalette.GILT_HOT)
	GiltShapes.hip_roof(_roof, Vector3(0.0, base_y + h, 0.0), span * 2.0 + 0.42, 2.7,
		0.0, 0.58, palette["roof"], GiltPalette.LEAD, 0.16)
	GiltShapes.spire(_roof, Vector3(0.0, base_y + h + 0.58, 0.0), 0.32, 1.15,
		palette["roof"], 4, PI * 0.25)
	GiltShapes.cylinder(_gilt, Vector3(0.0, base_y + h + 1.92, 0.0),
		0.035, 0.012, 0.46, GiltPalette.GILT, 6)
	GiltShapes.beam(_gilt, Vector3(-0.18, base_y + h + 2.02, 0.0),
		Vector3(0.18, base_y + h + 2.02, 0.0), 0.03, GiltPalette.GILT)


## Портик: две колонны, стрельчатый фронтон с крабами, ступени.
func _porch() -> void:
	var cx := 0.35
	var front_z := DEPTH * 0.5 + 0.78
	for sx in [-1.0, 1.0]:
		var x: float = cx + float(sx) * 1.10
		GiltShapes.cylinder(_stone, Vector3(x, 1.02, front_z), 0.14, 0.115, 2.04,
			GiltPalette.STONE_COLD * 0.76, 8)
		GiltShapes.box(_stone, Vector3(x, 0.11, front_z), Vector3(0.44, 0.22, 0.44),
			GiltPalette.STONE_COLD * 0.60)
		GiltShapes.box(_gilt, Vector3(x, 2.10, front_z), Vector3(0.34, 0.10, 0.34),
			GiltPalette.GILT * 0.76)
	GiltShapes.pent_roof(_roof, Vector3(cx, 2.14, front_z - 0.42), 3.0, 1.20,
		0.12, 0.54, palette["roof"], GiltPalette.LEAD)
	GiltShapes.box(_stone, Vector3(cx, 2.48, front_z + 0.02), Vector3(3.0, 0.32, 0.16),
		palette["wall"].lightened(0.14))
	for i in range(3):
		var t := (float(i) + 0.5) / 3.0
		GiltShapes.spire(_gilt, Vector3(cx + lerpf(-1.36, 1.36, t), 2.64, front_z + 0.02),
			0.10, 0.32, GiltPalette.GILT * 0.84, 4, PI * 0.25)
	GiltShapes.spire(_gilt, Vector3(cx, 2.64, front_z + 0.02), 0.12, 0.64,
		GiltPalette.GILT, 4, PI * 0.25)
	for i in range(3):
		GiltShapes.box(_stone, Vector3(cx, 0.07 + float(i) * 0.10,
			front_z + 0.30 + float(i) * 0.26),
			Vector3(2.2 - float(i) * 0.16, 0.14, 0.30), GiltPalette.STONE_COLD * 0.54)


## Контрфорсы по фасаду: ступенчатые выступы, кверху сходят на нет.
func _buttresses() -> void:
	for sx in [-1.0, 1.0]:
		var x: float = float(sx) * (WIDTH * 0.5 - 0.52)
		for i in range(3):
			var y := 0.40 + float(i) * 0.64
			var w := 0.52 - float(i) * 0.13
			GiltShapes.box(_stone, Vector3(x, y, DEPTH * 0.5 + 0.10),
				Vector3(w, 0.60, 0.32), palette["wall"].lightened(0.10))
			GiltShapes.box(_gilt, Vector3(x, y + 0.30, DEPTH * 0.5 + 0.11),
				Vector3(w + 0.03, 0.03, 0.32), GiltPalette.GILT * 0.5)
		# Фиал наверху контрфорса — вертикальный акцент на фасаде.
		GiltShapes.spire(_gilt, Vector3(x, 2.02, DEPTH * 0.5 + 0.10), 0.13, 0.52,
			GiltPalette.GILT * 0.9, 4, PI * 0.25)


## Роза-окно: кольцо, восемь спиц и витраж за ними.
func _rose_window(at: Vector3, radius: float) -> void:
	GiltShapes.ring(_glass, at, radius * 0.94, radius * 0.78, 0.05,
		palette["glass"], 18, Vector3(0.0, 0.0, 1.0))
	GiltShapes.ring(_stone, at + Vector3(0.0, 0.0, 0.04), radius * 1.18, radius * 0.94,
		0.18, GiltPalette.STONE_COLD * 0.68, 18, Vector3(0.0, 0.0, 1.0))
	for i in range(8):
		var ang := TAU * float(i) / 8.0
		GiltShapes.beam(_stone, at + Vector3(cos(ang), sin(ang), 0.05) * radius * 0.16,
			at + Vector3(cos(ang), sin(ang), 0.05) * radius * 0.96, 0.042,
			GiltPalette.LEAD)
	GiltShapes.cylinder(_gilt, at + Vector3(0.0, 0.0, 0.07), 0.085, 0.085, 0.06,
		GiltPalette.GILT, 8, Basis(Vector3.RIGHT, PI * 0.5))


## Дверь, окна, фонарь, вывеска и «жизнь» у стены.
func _details() -> void:
	var front := DEPTH * 0.5
	var door_x := 0.42 if style != 3 else 0.35
	# Дверь под стрельчатой аркой: тёмное дерево в эмалевой обвязке.
	var door_w := 0.94
	var spring := 1.24
	var door_profile := GiltShapes.pointed_arch(door_w, 0.0, spring, 6)
	GiltShapes.extrude_z(_wood, door_profile, front + 0.02, front + 0.11,
		GiltPalette.WOOD_DARK, Vector3(door_x, 0.0, 0.0))
	var frame := GiltShapes.pointed_arch(door_w + 0.30, -0.10, spring, 6)
	GiltShapes.extrude_z(_stone, frame, front - 0.05, front + 0.08,
		palette["enamel"].darkened(0.20), Vector3(door_x, 0.0, 0.0))
	# Кованые петли и кольцо-стук: три золотые черты на двери.
	for i in range(3):
		var y := 0.46 + float(i) * 0.44
		GiltShapes.beam(_gilt, Vector3(door_x - 0.42, y, front + 0.12),
			Vector3(door_x + 0.06, y, front + 0.12), 0.032, GiltPalette.GILT * 0.8)
	GiltShapes.ring(_gilt, Vector3(door_x + 0.30, 1.00, front + 0.13), 0.075, 0.042, 0.03,
		GiltPalette.GILT, 10, Vector3(0.0, 0.0, 1.0))
	# Крыльцо: каменная плита перед дверью.
	GiltShapes.box(_stone, Vector3(door_x, 0.06, front + 0.36), Vector3(1.34, 0.14, 0.62),
		GiltPalette.STONE_COLD * 0.52)
	# Окна фасада: два ланцета по бокам от двери. У дома с угловой башней
	# левое окно «уехало» бы внутрь башни — там фасад держит сама башня.
	if style != 1:
		GiltShapes.lancet(_glass, _gilt, Vector3(-1.62, 0.74, front + 0.01), 0.64, 1.44,
			palette["glass"], GiltPalette.LEAD, night01, 0.08)
	GiltShapes.lancet(_glass, _gilt, Vector3(1.94, 0.74, front + 0.01), 0.64, 1.44,
		palette["glass"], GiltPalette.LEAD, night01, 0.08)
	# Торцевые окна: дом не «слепой» сбоку.
	for sz in [-1.0, 1.0]:
		GiltShapes.lancet(_glass, _gilt, Vector3(float(sz) * (WIDTH * 0.5 - 0.01), 0.88, 0.62),
			0.52, 1.22, palette["glass"], GiltPalette.LEAD, night01, 0.06,
			GiltShapes.facing(Vector3(float(sz), 0.0, 0.0)))
	# Задняя стена тоже закончена: нет «пустой коробки» с обратной стороны.
	GiltShapes.lancet(_glass, _gilt, Vector3(-1.10, 0.80, -front - 0.01), 0.50, 1.16,
		palette["glass"], GiltPalette.LEAD, night01, 0.06,
		GiltShapes.facing(Vector3(0.0, 0.0, -1.0)))
	GiltShapes.lancet(_glass, _gilt, Vector3(1.10, 0.80, -front - 0.01), 0.50, 1.16,
		palette["glass"], GiltPalette.LEAD, night01, 0.06,
		GiltShapes.facing(Vector3(0.0, 0.0, -1.0)))
	# Угловой фонарь у двери: тёплая точка входа, единственный «уютный» свет.
	_lamp(Vector3(door_x - 0.76, 2.04, front + 0.28))
	# Вывеска-примета: доска с золотой каймой у каждого дома.
	_sign(Vector3(1.30, 1.32, front + 0.15))
	# Жизнь: горшки на подоконниках и поленница под стеной.
	var pots := [1.94] if style == 1 else [-1.62, 1.94]
	for sx in pots:
		GiltShapes.box(_wood, Vector3(float(sx), 0.70, front + 0.22),
			Vector3(0.74, 0.12, 0.22), GiltPalette.WOOD_WARM)
		for i in range(3):
			GiltShapes.spire(_wood, Vector3(float(sx) - 0.24 + float(i) * 0.24, 0.76, front + 0.22),
				0.07, 0.24, GiltPalette.MOSS * (1.0 + float(i) * 0.06), 5)
	_log_stack(Vector3(0.6, _foundation_bottom + 0.02, -DEPTH * 0.5 - 0.62))
	# Дым из трубы: посёлок живой даже когда на него не смотрят.
	_smoke(Vector3(-WIDTH * 0.27, RIDGE + 1.05, -0.38))


func _lamp(at: Vector3) -> void:
	GiltShapes.beam(_stone, at + Vector3(0.0, 0.0, -0.18), at, 0.05, GiltPalette.IRON)
	GiltShapes.box(_gilt, at, Vector3(0.20, 0.26, 0.20), GiltPalette.GILT * 0.84)
	GiltShapes.spire(_gilt, at + Vector3(0.0, 0.13, 0.0), 0.16, 0.16,
		GiltPalette.IRON, 4, PI * 0.25)
	var lamp := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.15, 0.19, 0.15)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = GiltPalette.LAMP_WARM
	mat.emission_enabled = true
	mat.emission = GiltPalette.LAMP_WARM
	mat.emission_energy_multiplier = 0.0
	lamp.mesh = box
	lamp.material_override = mat
	lamp.position = at
	add_child(lamp)
	_glow_nodes.append(lamp)
	# Один тусклый тёплый источник на дом: окна и крыльцо читаются ночью.
	_light = OmniLight3D.new()
	_light.light_color = GiltPalette.LAMP_WARM
	_light.omni_range = 5.2
	_light.light_energy = 0.0
	_light.shadow_enabled = false
	_light.position = at + Vector3(0.0, 0.15, 0.55)
	add_child(_light)


func _sign(at: Vector3) -> void:
	GiltShapes.beam(_stone, at + Vector3(-0.30, 0.06, -0.14), at + Vector3(-0.30, 0.06, 0.02),
		0.04, GiltPalette.IRON)
	GiltShapes.box(_wood, at, Vector3(0.62, 0.34, 0.05), palette["enamel"])
	GiltShapes.beam(_gilt, at + Vector3(-0.32, 0.19, 0.03), at + Vector3(0.32, 0.19, 0.03),
		0.028, GiltPalette.GILT * 0.9)
	GiltShapes.beam(_gilt, at + Vector3(-0.32, -0.19, 0.03), at + Vector3(0.32, -0.19, 0.03),
		0.028, GiltPalette.GILT * 0.9)
	# Три «буквы» — золотые насечки: читаются как надпись, не тратят шрифт.
	for i in range(3):
		GiltShapes.box(_gilt, at + Vector3(-0.16 + float(i) * 0.16, 0.0, 0.035),
			Vector3(0.07, 0.11, 0.02), GiltPalette.GILT_HOT * 0.8)


func _log_stack(at: Vector3) -> void:
	for row in range(3):
		for i in range(4 - row):
			GiltShapes.cylinder(_wood,
				at + Vector3(0.0, 0.12 + float(row) * 0.20,
					-0.28 + float(i) * 0.19 + float(row) * 0.095),
				0.085, 0.085, 0.62, GiltPalette.WOOD_WARM.darkened(0.18), 6,
				Basis(Vector3.RIGHT, PI * 0.5))


## Дым: простой поток частиц без шейдера. В headless-тесте он не мешает,
## а в кадре даёт ту самую «жизнь», которой не было у коробок.
func _smoke(at: Vector3) -> void:
	var particles := GPUParticles3D.new()
	particles.name = "ChimneySmoke"
	particles.amount = 14
	particles.lifetime = 6.0
	particles.preprocess = 3.0
	particles.position = at
	particles.visibility_aabb = AABB(Vector3(-3.0, -0.5, -3.0), Vector3(6.0, 9.0, 6.0))
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3(0.35, 1.0, 0.15)
	process.spread = 12.0
	process.initial_velocity_min = 0.25
	process.initial_velocity_max = 0.55
	process.gravity = Vector3(0.18, 0.12, -0.05)
	process.scale_min = 0.35
	process.scale_max = 0.85
	# scale_curve у ParticleProcessMaterial — это CurveTexture, не Curve:
	# Curve здесь только заполняет текстуру.
	var scale_texture := CurveTexture.new()
	scale_texture.curve = _smoke_curve()
	process.scale_curve = scale_texture
	process.color = Color(0.72, 0.70, 0.82, 0.30)
	particles.process_material = process
	var quad := QuadMesh.new()
	quad.size = Vector2(0.55, 0.55)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.70, 0.68, 0.80, 0.22)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	# Мягкий диск вместо плоского квадрата: иначе дым читается «салфетками».
	mat.albedo_texture = ProcTextures.radial(48, 1.6)
	mat.disable_receive_shadows = true
	quad.material = mat
	particles.draw_pass_1 = quad
	add_child(particles)


func _smoke_curve() -> Curve:
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.35))
	curve.add_point(Vector2(0.45, 0.85))
	curve.add_point(Vector2(1.0, 1.30))
	return curve


# --- Ночь -----------------------------------------------------------------

## Стекло ночью не «красится ярче», а светится; фонарь зажигается позже.
func set_night(amount: float) -> void:
	night01 = clampf(amount, 0.0, 1.0)
	var glow := maxf(0.0, night01 - 0.18) * 1.6
	if window_material != null:
		window_material.emission_energy_multiplier = glow
	for node in _glow_nodes:
		var mat := node.material_override as StandardMaterial3D
		if mat != null and mat.emission_enabled:
			mat.emission_energy_multiplier = maxf(0.0, night01 - 0.22) * 2.2
	if _light != null:
		_light.light_energy = maxf(0.0, night01 - 0.30) * 0.55


# --- Запекание ------------------------------------------------------------

func _commit() -> void:
	_bake("Stone", _stone, _material(0.86, 0.0), false)
	_bake("Roof", _roof, _material(0.95, 0.10), false)
	_bake("Gilt", _gilt, _material(0.30, 0.70), false)
	window_material = _glass_material()
	_bake("Glass", _glass, window_material, false)
	_bake("Wood", _wood, _material(0.92, 0.0), false)


func _glass_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color.WHITE
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.18
	mat.metallic = 0.25
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.emission_enabled = true
	mat.emission = palette.get("glass", GiltPalette.LAMP_MAGENTA)
	mat.emission_energy_multiplier = 0.0
	return mat


func _material(roughness: float, metallic: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color.WHITE
	mat.vertex_color_use_as_albedo = true
	mat.roughness = roughness
	mat.metallic = metallic
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat


func _bake(node_name: String, surface: SurfaceTool, material: Material,
		shadows := true) -> void:
	if surface == null:
		return
	var mesh := surface.commit()
	if mesh == null or mesh.get_surface_count() == 0:
		return
	var visual := MeshInstance3D.new()
	visual.name = node_name
	visual.mesh = mesh
	visual.material_override = material
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows \
		else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(visual)
