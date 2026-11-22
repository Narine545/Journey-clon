class_name GiltHouse
extends Node3D
## Дом посёлка «Тихая бухта»: не коробка с краской, а отдельная постройка.
##
## Идея стиля. Деревня стоит на голом базальтовом острове, леса нет, зато
## после каждого шторма на берег выносит корабельный лес. Поэтому дома
## сложены из обломков: тарная обшивка внахлёст, шпангоуты по щипцам,
## мачтовые стойки, иллюминаторы вместо окон, створки из палубного настила.
## Камень (цоколь, трубы, причал) — местный; дерево — чужое, с моря.
## Это и есть «необычно, но аутентично»: такие дома правда строили на
## островах, куда не привозили лес, а прибивало его волной.
##
## Каждый дом получает ПЛАН (GiltHouse.PLANS): габарит, высоту, материал,
## силуэт и примету. Восемь домов — восемь разных построек, а не восемь
## копий с разной крышей:
##   netloft   — сетевой сарай в два света, наружная лестница, жерди с сетью;
##   keeper    — дом смотрителя маяка с фонарной будкой на крыше;
##   tavern    — таверна «Тихий вал»: широкий фасад, навес, скамьи, вывеска;
##   salthouse — солеварня: каменные стены, двойные ворота, журавль;
##   chandler  — лавка-школа: витрина, навес, ящики, колокольчик;
##   smithy    — кузня: горн, широкий дымоход, наковальня, чан;
##   parsonage — дом пастора: контрфорсы, роза-окно, сад за оградой;
##   pilot     — дом лоцмана: сигнальная мачта, фонарь, вёсельная лодка.
##
## Координаты: начало — центр пола, +Y вверх, вход в локальный +Z.
## Коллизия — BuildingCollision: StaticBody3D, размеры по факту плана.
## replacement_visual сохраняет старый крючок: назначьте GLB — процедурная
## часть уступит место модели, коллизия и расстановка останутся.

const PLANS := {
	"netloft": {
		"sign": "СЕТИ", "width": 6.4, "depth": 5.6, "eaves": 4.55, "ridge": 7.05,
		"wall": Color("b9ae95"), "roof": Color("2b2a2e"), "trim": Color("d8cdb6"),
		"door": Color("2b6f6c"), "glass": Color("ffc07a"), "stone": Color("2b2f38"),
		"storeys": 2, "roof_style": "gable", "chimney": 2, "feature": "loft",
	},
	"keeper": {
		"sign": "МАЯК", "width": 6.8, "depth": 5.8, "eaves": 3.55, "ridge": 6.35,
		"wall": Color("efe6d2"), "roof": Color("386b66"), "trim": Color("d9b06a"),
		"door": Color("8c3f34"), "glass": Color("8fe9dc"), "stone": Color("2a2e38"),
		"storeys": 1, "roof_style": "gable", "chimney": 1, "feature": "lantern",
	},
	"tavern": {
		"sign": "ТИХИЙ ВАЛ", "width": 8.6, "depth": 6.2, "eaves": 3.85, "ridge": 6.55,
		"wall": Color("8c4a3b"), "roof": Color("2c2724"), "trim": Color("e6dcc4"),
		"door": Color("d2a24c"), "glass": Color("ffb46a"), "stone": Color("2b2c33"),
		"storeys": 2, "roof_style": "gable", "chimney": 1, "feature": "tavern",
	},
	"salthouse": {
		"sign": "СОЛЬ", "width": 6.8, "depth": 5.4, "eaves": 3.15, "ridge": 5.35,
		"wall": Color("8d8577"), "roof": Color("3e4a44"), "trim": Color("cfc4b4"),
		"door": Color("355c63"), "glass": Color("a9e6c6"), "stone": Color("33343a"),
		"storeys": 1, "roof_style": "gable", "chimney": 1, "feature": "salting",
	},
	"chandler": {
		"sign": "ЛАВКА", "width": 8.2, "depth": 5.8, "eaves": 3.65, "ridge": 6.15,
		"wall": Color("c7b98f"), "roof": Color("2a3040"), "trim": Color("e0d5bd"),
		"door": Color("2c6d74"), "glass": Color("ffd08c"), "stone": Color("2c3039"),
		"storeys": 1, "roof_style": "gable", "chimney": 1, "feature": "shop",
	},
	"smithy": {
		"sign": "КУЗНЯ", "width": 6.2, "depth": 5.2, "eaves": 3.05, "ridge": 5.45,
		"wall": Color("4c4a45"), "roof": Color("4a3a30"), "trim": Color("b9a98f"),
		"door": Color("6b3a2c"), "glass": Color("ff8a4c"), "stone": Color("24252b"),
		"storeys": 1, "roof_style": "gable", "chimney": 1, "feature": "forge",
	},
	"parsonage": {
		"sign": "ПАСТОР", "width": 7.6, "depth": 6.0, "eaves": 3.65, "ridge": 6.45,
		"wall": Color("d6cdb8"), "roof": Color("2a2f3e"), "trim": Color("d9b06a"),
		"door": Color("4b3a6b"), "glass": Color("c9a9ff"), "stone": Color("2c2f39"),
		"storeys": 1, "roof_style": "gable", "chimney": 1, "feature": "parsonage",
	},
	"pilot": {
		"sign": "ЛОЦМАН", "width": 6.4, "depth": 5.4, "eaves": 3.35, "ridge": 5.85,
		"wall": Color("3f6660"), "roof": Color("232a38"), "trim": Color("e2d7bf"),
		"door": Color("b4543c"), "glass": Color("ffd2a1"), "stone": Color("292d36"),
		"storeys": 1, "roof_style": "gable", "chimney": 1, "feature": "pilot",
	},
}

@export var replacement_visual: PackedScene

var plan_name := "netloft"
var plan := {}
var width := 6.4
var depth := 5.6
var eaves := 3.6
var ridge := 6.0
var style := 0
var night01 := 0.0
var palette := {}
var person_id := ""
var resident := {}
var window_material: StandardMaterial3D

var _stone: SurfaceTool
var _roof: SurfaceTool
var _gilt: SurfaceTool
var _glass: SurfaceTool
var _wood: SurfaceTool
var _dark: SurfaceTool
var _glow: Array[MeshInstance3D] = []
var _light: OmniLight3D
var _foundation_bottom := 0.0
var _highlight: MeshInstance3D
var _highlight_mat: StandardMaterial3D
var _nameplate: Label3D
var _smoke_points: Array[Vector3] = []
var _painted_window := false


## Основная точка входа. data — запись из IslandVillage.HOUSE_SITES:
## plan, floor, resident и необязательные поправки габарита.
func build_site(data: Dictionary, foundation_bottom: float) -> void:
	plan_name = String(data.get("plan", "netloft"))
	plan = (PLANS.get(plan_name, PLANS["netloft"]) as Dictionary).duplicate(true)
	# Габариты можно уточнить в расстановке, не трогая сам план: улица
	# главнее красивой цифры, а дом остаётся собой.
	for key in ["width", "depth", "eaves", "ridge", "sign"]:
		if data.has(key):
			plan[key] = data[key]
	width = float(plan["width"])
	depth = float(plan["depth"])
	eaves = float(plan["eaves"])
	ridge = float(plan["ridge"])
	style = int(data.get("style", 0))
	person_id = String(data.get("resident", "netmaker"))
	resident = VillagePeople.get_person(person_id)
	_foundation_bottom = foundation_bottom
	palette = {
		"wall": plan["wall"], "roof": plan["roof"], "trim": plan["trim"],
		"door": plan["door"], "glass": plan["glass"], "stone": plan["stone"],
	}
	_collision()
	if replacement_visual != null:
		_replace_visual()
		_add_highlight()
		return
	_begin()
	_yard(foundation_bottom)
	_plinth(foundation_bottom)
	_walls()
	_roof_cover()
	_street_face()
	_side_faces()
	_match_feature(String(plan["feature"]))
	_details()
	_add_nameplate()
	_commit()
	set_night(night01)
	_add_highlight()


## Совместимость с прежним GiltCottage.build(style, foundation_bottom):
## старые пять силуэтов остаются доступны по номеру.
func build(variant: int, foundation_bottom: float) -> void:
	var names := ["netloft", "keeper", "tavern", "salthouse", "parsonage"]
	build_site({"plan": names[variant % names.size()], "style": variant}, foundation_bottom)


func _replace_visual() -> void:
	var replacement := replacement_visual.instantiate()
	replacement.name = "ReplacementVisual"
	add_child(replacement)
	window_material = _glass_material()


func _begin() -> void:
	_stone = GiltShapes.begin()
	_roof = GiltShapes.begin()
	_gilt = GiltShapes.begin()
	_glass = GiltShapes.begin()
	_wood = GiltShapes.begin()
	_dark = GiltShapes.begin()


func _collision() -> void:
	var solid := StaticBody3D.new()
	solid.name = "BuildingCollision"
	solid.set_meta("village_house", true)
	add_child(solid)
	var body := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(width + 0.6, ridge + 0.8, depth + 0.8)
	body.shape = shape
	body.position.y = (ridge + 0.8) * 0.5 - 0.1
	solid.add_child(body)


# --- Цоколь, двор и водоотвод ----------------------------------------------

## Двор — плоская каменная площадка на высоте пола: дом не «вспахивает»
## склон, а стоит на своей выровненной террасе, как положено по нормам.
func _yard(foundation_bottom: float) -> void:
	var y := -0.05
	var pad_front := depth * 0.5 + 1.45
	var pad_back := -depth * 0.5 - 0.95
	var pad := GiltShapes.begin()
	var bx := Basis.IDENTITY
	GiltShapes.box(pad, Vector3(0.0, y, (pad_front + pad_back) * 0.5),
		Vector3(width + 1.15, 0.16, pad_front - pad_back), Color("3a3a42"))
	# Брусчатка двора: светлые швы через каждые 0.9 м.
	var rows := maxi(3, int((pad_front - pad_back) / 0.9))
	for i in range(rows + 1):
		var z := lerpf(pad_back, pad_front, float(i) / float(rows))
		GiltShapes.box(pad, Vector3(0.0, y + 0.09, z),
			Vector3(width + 1.1, 0.012, 0.05), Color("6b6266"))
	for sx in [-1.0, 1.0]:
		GiltShapes.box(pad, Vector3(float(sx) * (width * 0.5 + 0.55), y + 0.12,
			(pad_front + pad_back) * 0.5), Vector3(0.10, 0.10, pad_front - pad_back),
			Color("57505a"))
	# Подпорная стенка дворовой террасы на склоне: камень до земли.
	var drop := maxf(0.16, -foundation_bottom + 0.06)
	if drop > 0.28:
		for i in range(3):
			var h := drop / 3.0
			var shrink := float(i) * 0.10
			GiltShapes.box(pad, Vector3(0.0, -drop + h * (float(i) + 0.5), pad_front + 0.04 - shrink),
				Vector3(width + 1.15 - shrink * 2.0, h, 0.22), Color("33333b").lightened(0.05 * float(i)))
	var mesh := MeshInstance3D.new()
	mesh.name = "Yard"
	mesh.mesh = pad.commit()
	mesh.material_override = _material(0.94, 0.0)
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh)
	# Ступенька с улицы: одна плита, а не порог «в воздухе».
	GiltShapes.box(_stone, Vector3(0.0, -0.10, pad_front + 0.18),
		Vector3(minf(2.4, width * 0.45), 0.22, 0.42), Color("57525c"))


func _plinth(foundation_bottom: float) -> void:
	var plinth_depth := maxf(0.40, -foundation_bottom + 0.18)
	var stone: Color = palette["stone"]
	GiltShapes.box(_stone, Vector3(0.0, -plinth_depth * 0.5 + 0.06, 0.0),
		Vector3(width + 0.18, plinth_depth, depth + 0.18), stone)
	# Кладка цоколя: горизонтальные швы, чтобы камень читался масштабом.
	var courses := maxi(3, int(plinth_depth / 0.28))
	for i in range(courses):
		var y := 0.06 - (float(i) + 0.5) * plinth_depth / float(courses)
		GiltShapes.box(_stone, Vector3(0.0, y, 0.0),
			Vector3(width + 0.22, 0.025, depth + 0.22), Color("191c23"))
	# Отлив: светлая кромка на уровне пола.
	GiltShapes.box(_stone, Vector3(0.0, 0.10, 0.0),
		Vector3(width + 0.30, 0.14, depth + 0.30), palette["trim"] * 0.62)


# --- Стены и кровля ---------------------------------------------------------

func _walls() -> void:
	var base_h := 0.72
	var body_w := width - 0.24
	var body_d := depth - 0.24
	var wall: Color = palette["wall"]
	# Каменный низ и деревянный верх — так строят на скале: камень ниже
	# линии прибоя, корабельный лес выше.
	GiltShapes.box(_stone, Vector3(0.0, 0.10 + base_h * 0.5, 0.0),
		Vector3(body_w + 0.12, base_h, body_d + 0.12), palette["stone"] * 1.18)
	GiltShapes.box(_stone, Vector3(0.0, 0.10 + base_h, 0.0),
		Vector3(body_w + 0.20, 0.10, body_d + 0.20), palette["trim"] * 0.55)
	GiltShapes.box(_wood, Vector3(0.0, base_h + (eaves - base_h) * 0.5 + 0.10, 0.0),
		Vector3(body_w, eaves - base_h, body_d), wall)
	# Обшивка внахлёст: тонкие пояса с шагом 0.30 м, каждый чуть темнее/светлее.
	var rows := maxi(4, int((eaves - base_h) / 0.30))
	for i in range(rows):
		var y := base_h + 0.10 + (float(i) + 0.5) * (eaves - base_h) / float(rows)
		var tone: Color = wall.lightened(0.06 + 0.03 * float(i % 3)) \
			if i % 2 == 0 else wall.darkened(0.10 + 0.02 * float((i + 1) % 3))
		GiltShapes.box(_wood, Vector3(0.0, y, 0.0),
			Vector3(body_w + 0.035, 0.045, body_d + 0.035), tone)
	# Мачтовые стойки по углам и шпангоуты по стенам: каркас виден.
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			GiltShapes.box(_wood, Vector3(float(sx) * body_w * 0.5, eaves * 0.5 + 0.10,
				float(sz) * body_d * 0.5), Vector3(0.22, eaves - 0.10, 0.22),
				wall.darkened(0.24))
	for sz in [-1.0, 1.0]:
		for i in range(3):
			var x := (float(i) - 1.0) * body_w * 0.30
			GiltShapes.box(_wood, Vector3(x, eaves * 0.5 + 0.10,
				float(sz) * (body_d * 0.5 + 0.015)),
				Vector3(0.07, eaves - 0.16, 0.012), wall.darkened(0.18))
	# Второй свет: поясок над первым этажом, если дом двухэтажный.
	if int(plan["storeys"]) > 1:
		var belt := base_h + (eaves - base_h) * 0.52
		GiltShapes.box(_wood, Vector3(0.0, belt, 0.0),
			Vector3(body_w + 0.10, 0.10, body_d + 0.10), palette["trim"] * 0.7)
		for sx in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				GiltShapes.box(_gilt, Vector3(float(sx) * body_w * 0.5, belt,
					float(sz) * body_d * 0.5), Vector3(0.26, 0.12, 0.26),
					GiltPalette.GILT * 0.72)


func _roof_cover() -> void:
	var roof_col: Color = palette["roof"]
	var rise := ridge - eaves
	var ridge_y := GiltShapes.gable_roof(_roof, Vector3.ZERO, width, depth, eaves, rise,
		roof_col, roof_col.lightened(0.18), palette["wall"].darkened(0.10), 0.46)
	# Карниз и водосток: два ската, две нити, четыре стояка.
	for sz in [-1.0, 1.0]:
		var z: float = float(sz) * (depth * 0.5 + 0.44)
		GiltShapes.beam(_wood, Vector3(-width * 0.5 - 0.44, eaves - 0.02, z),
			Vector3(width * 0.5 + 0.44, eaves - 0.02, z), 0.11, palette["trim"] * 0.55)
		GiltShapes.beam(_dark, Vector3(-width * 0.5 + 0.15, eaves - 0.16, z),
			Vector3(width * 0.5 - 0.15, eaves - 0.16, z), 0.05, GiltPalette.IRON)
		for sx in [-1.0, 1.0]:
			GiltShapes.beam(_dark, Vector3(float(sx) * (width * 0.5 - 0.10), eaves - 0.16, z),
				Vector3(float(sx) * (width * 0.5 - 0.10), 0.16, z + 0.10), 0.045,
				GiltPalette.IRON)
	# Конёк: тяжёлый брус, поверх — золотая нить, по краям фиалы.
	GiltShapes.beam(_wood, Vector3(-width * 0.5 - 0.42, ridge_y + 0.04, 0.0),
		Vector3(width * 0.5 + 0.42, ridge_y + 0.04, 0.0), 0.13, roof_col.lightened(0.22))
	GiltShapes.beam(_gilt, Vector3(-width * 0.5 + 0.10, ridge_y + 0.15, 0.0),
		Vector3(width * 0.5 - 0.10, ridge_y + 0.15, 0.0), 0.035, GiltPalette.GILT * 0.82)
	for sx in [-1.0, 1.0]:
		GiltShapes.spire(_gilt, Vector3(float(sx) * (width * 0.5 - 0.18), ridge_y + 0.16, 0.0),
			0.10, 0.48, GiltPalette.GILT * 0.9, 4, PI * 0.25)
	# Щипцы: шпангоуты и ветровые доски — «корабельный» силуэт.
	for sx in [-1.0, 1.0]:
		var x: float = float(sx) * (width * 0.5 - 0.03)
		var eave_y := eaves
		for i in range(3):
			var t := (float(i) + 0.5) / 4.0
			var y := lerpf(eave_y + 0.18, ridge_y - 0.12, t)
			var half := lerpf(depth * 0.5, 0.10, t)
			GiltShapes.beam(_wood, Vector3(x, y, -half), Vector3(x, y, half), 0.075,
				palette["wall"].darkened(0.20))
		GiltShapes.beam(_wood, Vector3(x, eaves, depth * 0.5),
			Vector3(x, ridge_y, 0.0), 0.10, palette["trim"] * 0.55)
		GiltShapes.beam(_wood, Vector3(x, eaves, -depth * 0.5),
			Vector3(x, ridge_y, 0.0), 0.10, palette["trim"] * 0.55)
	# Трубы: на коньке или у ската, всегда на 0.8 м выше конька (норма).
	var chimney_count := int(plan.get("chimney", 1))
	for i in range(chimney_count):
		var cx := lerpf(-width * 0.24, width * 0.24, float(i) / maxf(1.0, float(chimney_count - 1)))
		var cz := -depth * 0.18 + float(i) * 0.34
		var top := ridge_y + 0.95 + float(i) * 0.10
		var h := top - (eaves + 0.20)
		GiltShapes.box(_stone, Vector3(cx, eaves + 0.20 + h * 0.5, cz),
			Vector3(0.62, h, 0.54), palette["stone"] * 1.25)
		GiltShapes.chimney_top(_stone, Vector3(cx, top - 0.14, cz), 0.62,
			palette["trim"] * 0.66, GiltPalette.IRON)
		_smoke_points.append(Vector3(cx, top + 0.18, cz))
	# Моховой гребень на двух домах: старое дерево зеленеет с наветра.
	if plan_name in ["netloft", "salthouse"]:
		for i in range(9):
			var t := (float(i) + 0.5) / 9.0
			var x := lerpf(-width * 0.42, width * 0.42, t)
			GiltShapes.box(_wood, Vector3(x, ridge_y + 0.10, 0.16 + 0.06 * float(i % 2)),
				Vector3(0.34, 0.08, 0.24), GiltPalette.MOSS.lightened(0.08 * float(i % 3)))


# --- Фасад, окна и дверь ----------------------------------------------------

## Уличный фасад (+Z): дверь, окна, ставни, фонарь, вывеска с именем.
func _street_face() -> void:
	var front := depth * 0.5
	var door_x := 0.0
	if width > 7.4:
		door_x = -width * 0.16
	var door_w := 1.05
	var spring := 1.62
	var glass: Color = palette["glass"]
	# Дверь: палубные доски в эмалевой обвязке, стрельчатая арка.
	GiltShapes.extrude_z(_wood, GiltShapes.pointed_arch(door_w, 0.10, spring, 6),
		front + 0.02, front + 0.13, palette["door"].darkened(0.12),
		Vector3(door_x, 0.0, 0.0))
	GiltShapes.extrude_z(_wood, GiltShapes.pointed_arch(door_w + 0.30, -0.02, spring, 6),
		front - 0.04, front + 0.07, palette["door"].lightened(0.16),
		Vector3(door_x, 0.0, 0.0))
	for i in range(4):
		var x := door_x - door_w * 0.34 + float(i) * door_w * 0.22
		GiltShapes.beam(_dark, Vector3(x, 0.14, front + 0.145),
			Vector3(x, spring + 0.42, front + 0.145), 0.018, GiltPalette.IRON)
	# Петли и кольцо-стук: три золотые черты.
	for i in range(3):
		var y := 0.58 + float(i) * 0.46
		GiltShapes.beam(_gilt, Vector3(door_x - door_w * 0.46, y, front + 0.16),
			Vector3(door_x + door_w * 0.06, y, front + 0.16), 0.032, GiltPalette.GILT * 0.84)
	GiltShapes.ring(_gilt, Vector3(door_x + door_w * 0.30, 1.16, front + 0.17),
		0.075, 0.045, 0.03, GiltPalette.GILT, 10, Vector3(0.0, 0.0, 1.0))
	# Каменное крыльцо и навес над дверью.
	GiltShapes.box(_stone, Vector3(door_x, 0.06, front + 0.42), Vector3(1.55, 0.18, 0.72),
		palette["stone"] * 1.35)
	GiltShapes.beam(_wood, Vector3(door_x, spring + 0.62, front + 0.02),
		Vector3(door_x, spring + 0.55, front + 0.66), 0.06, palette["trim"] * 0.55)
	# Окна: два стрельчатых по бокам двери; у широких домов — по два с каждой.
	var window_y := 0.86
	var glass_positions: Array[float] = []
	if width > 7.4:
		glass_positions = [-width * 0.38, -width * 0.30, width * 0.28, width * 0.38]
	else:
		glass_positions = [-width * 0.31, width * 0.31]
	for i in range(glass_positions.size()):
		var x: float = glass_positions[i]
		if absf(x - door_x) < door_w * 0.7:
			continue
		var w := 0.62 if width < 7.4 else 0.54
		GiltShapes.lancet(_glass, _wood, Vector3(x, window_y, front + 0.01), w,
			1.42, glass, palette["trim"] * 0.55, night01, 0.09)
		# Ставни из палубного настила: одна створка открыта к стене.
		for sx in [-1.0, 1.0]:
			var shut_x: float = x + float(sx) * (w * 0.5 + 0.32)
			GiltShapes.box(_wood, Vector3(shut_x, window_y + 0.62, front + 0.16),
				Vector3(0.34, 1.32, 0.05), palette["door"].lightened(0.10))
			for k in range(4):
				GiltShapes.beam(_dark, Vector3(shut_x - 0.14, window_y + 0.10 + float(k) * 0.32,
					front + 0.19), Vector3(shut_x + 0.14, window_y + 0.10 + float(k) * 0.32,
					front + 0.19), 0.016, GiltPalette.IRON)
		# Ящик с цветами — пятно жизни на фасаде.
		GiltShapes.box(_wood, Vector3(x, window_y - 0.14, front + 0.24),
			Vector3(w + 0.36, 0.20, 0.24), GiltPalette.WOOD_WARM)
		for k in range(3):
			GiltShapes.spire(_wood, Vector3(x - 0.18 + float(k) * 0.18, window_y - 0.02,
				front + 0.25), 0.06, 0.22,
				[Color("b4543c"), Color("d2a24c"), GiltPalette.MOSS][k % 3], 5)
	# Фонарь у двери и вывеска-доска с именем дома.
	_door_lamp(Vector3(door_x - door_w * 0.9, 2.16, front + 0.32))
	_house_sign(Vector3(width * 0.34, 2.35, front + 0.16), String(plan["sign"]))


## Боковые и задний фасады: иллюминаторы вместо глухих стен.
func _side_faces() -> void:
	var body_w := width * 0.5
	var glass: Color = palette["glass"]
	for sx in [-1.0, 1.0]:
		var bx := GiltShapes.facing(Vector3(float(sx), 0.0, 0.0))
		for i in range(2):
			var z := lerpf(-depth * 0.24, depth * 0.24, float(i))
			_porthole(Vector3(float(sx) * (body_w + 0.01), 1.92, z), 0.34, glass, bx)
		# Кормовой иллюминатор второго света.
		_porthole(Vector3(float(sx) * (body_w + 0.01), eaves - 0.52, 0.0), 0.26, glass, bx)
	# Задняя стена: либо дверь на причал, либо два окна. У домов первой
	# линии задняя дверь выходит прямо на каменную набережную.
	var back := -depth * 0.5
	if plan_name in ["netloft", "salthouse", "tavern"]:
		GiltShapes.extrude_z(_wood, GiltShapes.pointed_arch(0.92, 0.10, 1.48, 5),
			back - 0.13, back - 0.02, palette["door"].darkened(0.18), Vector3(0.6, 0.0, 0.0))
		GiltShapes.box(_wood, Vector3(0.6, 1.55, back - 0.18), Vector3(1.25, 0.10, 0.40),
			palette["trim"] * 0.6)
	for i in range(2):
		var x := lerpf(-width * 0.24, width * 0.24, float(i))
		_porthole(Vector3(x, 1.76, back - 0.01), 0.30, glass,
			GiltShapes.facing(Vector3(0.0, 0.0, -1.0)))


func _porthole(at: Vector3, radius: float, glass: Color, bx: Basis) -> void:
	var normal := (bx * Vector3(0.0, 0.0, 1.0)).normalized()
	# Стекло — плоский диск, обод — литое кольцо, четыре болта.
	GiltShapes.cylinder(_glass, at, radius * 0.86, radius * 0.86, 0.045,
		glass.lerp(GiltPalette.GLASS_DAY, 1.0 - clampf(night01 * 1.3, 0.0, 1.0)),
		18, bx * Basis(Vector3.RIGHT, PI * 0.5))
	GiltShapes.ring(_stone, at, radius + 0.10, radius * 0.82, 0.11,
		palette["trim"] * 0.60, 18, normal)
	GiltShapes.ring(_dark, at + normal * 0.06, radius + 0.12, radius + 0.02, 0.035,
		GiltPalette.IRON, 18, normal)
	for i in range(4):
		var a := TAU * float(i) / 4.0 + PI * 0.25
		var p := at + (bx * Vector3(cos(a), sin(a), 0.0)) * (radius + 0.06) + normal * 0.08
		GiltShapes.box(_gilt, p, Vector3(0.055, 0.055, 0.035), GiltPalette.GILT * 0.8, bx)


func _door_lamp(at: Vector3) -> void:
	GiltShapes.beam(_dark, at + Vector3(-0.20, 0.10, -0.20), at, 0.045, GiltPalette.IRON)
	GiltShapes.box(_gilt, at, Vector3(0.18, 0.26, 0.18), GiltPalette.GILT * 0.82)
	GiltShapes.spire(_gilt, at + Vector3(0.0, 0.13, 0.0), 0.15, 0.14,
		GiltPalette.IRON, 4, PI * 0.25)
	var lamp := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.13, 0.17, 0.13)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = GiltPalette.LAMP_WARM
	mat.emission_enabled = true
	mat.emission = GiltPalette.LAMP_WARM
	mat.emission_energy_multiplier = 0.0
	lamp.mesh = box
	lamp.material_override = mat
	lamp.position = at
	add_child(lamp)
	_glow.append(lamp)
	_light = OmniLight3D.new()
	_light.light_color = GiltPalette.LAMP_WARM
	_light.omni_range = 6.0
	_light.light_energy = 0.0
	_light.shadow_enabled = false
	_light.light_volumetric_fog_energy = 0.55
	_light.position = at + Vector3(0.0, 0.25, 0.55)
	add_child(_light)


## Вывеска у двери. Висит всегда, но читается только в наведении:
## посёлок не должен превращаться в ряд подписанных коробок.
func _add_nameplate() -> void:
	var front := depth * 0.5
	var door_x := -width * 0.16 if width > 7.4 else 0.0
	_house_sign(Vector3(door_x, 2.32, front + 0.17), String(plan.get("sign", "ДОМ")))
	if _nameplate != null:
		_nameplate.visible = false


func _house_sign(at: Vector3, text: String) -> void:
	GiltShapes.beam(_dark, at + Vector3(-0.34, 0.22, -0.18), at + Vector3(-0.34, 0.30, 0.02),
		0.05, GiltPalette.IRON)
	GiltShapes.beam(_dark, at + Vector3(0.34, 0.22, -0.18), at + Vector3(0.34, 0.30, 0.02),
		0.05, GiltPalette.IRON)
	GiltShapes.box(_wood, at, Vector3(0.98, 0.40, 0.06), palette["door"].darkened(0.10))
	GiltShapes.beam(_gilt, at + Vector3(-0.48, 0.20, 0.04), at + Vector3(0.48, 0.20, 0.04),
		0.025, GiltPalette.GILT * 0.9)
	GiltShapes.beam(_gilt, at + Vector3(-0.48, -0.20, 0.04), at + Vector3(0.48, -0.20, 0.04),
		0.025, GiltPalette.GILT * 0.9)
	_nameplate = Label3D.new()
	_nameplate.name = "HouseName"
	_nameplate.text = text
	_nameplate.font = TideTokens.title_font()
	_nameplate.font_size = 40
	_nameplate.pixel_size = 0.0062
	_nameplate.modulate = GiltPalette.GILT_HOT
	_nameplate.outline_size = 10
	_nameplate.outline_modulate = Color("171a24")
	_nameplate.no_depth_test = false
	_nameplate.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	_nameplate.position = at + Vector3(0.0, 0.0, 0.05)
	_nameplate.rotation.y = 0.0
	add_child(_nameplate)


# --- Приметы домов ----------------------------------------------------------

func _match_feature(feature: String) -> void:
	match feature:
		"loft":
			_loft()
		"lantern":
			_lantern_room()
		"tavern":
			_tavern()
		"salting":
			_salting()
		"shop":
			_shop()
		"forge":
			_forge()
		"parsonage":
			_parsonage()
		"pilot":
			_pilot()
		_:
			_loft()


## Сетевой сарай: наружная лестница, большой люк, жерди для сетей.
func _loft() -> void:
	var front := depth * 0.5
	var side := width * 0.5
	# Люк на втором свете — во всю ширину щипца, с тельфером.
	GiltShapes.box(_wood, Vector3(side - 0.02, eaves + 0.55, 0.0),
		Vector3(0.14, 1.05, 1.55), palette["door"].darkened(0.24))
	GiltShapes.beam(_dark, Vector3(side + 0.10, eaves + 1.12, -0.78),
		Vector3(side + 0.10, eaves + 1.12, 0.78), 0.06, GiltPalette.IRON)
	GiltShapes.beam(_dark, Vector3(side + 0.10, eaves + 1.12, 0.0),
		Vector3(side + 1.10, eaves + 1.12, 0.0), 0.07, GiltPalette.IRON)
	GiltShapes.cylinder(_gilt, Vector3(side + 1.10, eaves + 0.92, 0.0),
		0.10, 0.10, 0.10, GiltPalette.GILT * 0.8, 8)
	GiltShapes.beam(_dark, Vector3(side + 1.10, eaves + 0.86, 0.0),
		Vector3(side + 1.10, eaves + 0.40, 0.0), 0.025, GiltPalette.ROPE)
	# Наружная лестница вдоль фасада на второй свет.
	for i in range(9):
		var t := float(i) / 8.0
		var x := lerpf(front * 0.0, -width * 0.38, t) + 0.9
		var y := 0.16 + t * (eaves - 0.20)
		GiltShapes.box(_wood, Vector3(x, y, front + 0.45), Vector3(0.62, 0.10, 0.52),
			GiltPalette.WOOD_WARM.darkened(0.05 * float(i % 2)))
		for sz in [-1.0, 1.0]:
			GiltShapes.beam(_dark, Vector3(x, y + 0.60, front + 0.45 + float(sz) * 0.28),
				Vector3(x, y + 0.05, front + 0.45 + float(sz) * 0.28), 0.035,
				GiltPalette.IRON)
	for i in range(3):
		var x := -width * 0.30 + float(i) * 0.52
		GiltShapes.beam(_wood, Vector3(x, 0.10, front + 0.95),
			Vector3(x, 2.60, front + 0.95), 0.06, GiltPalette.WOOD_DARK)
	GiltShapes.beam(_wood, Vector3(-width * 0.30, 2.58, front + 0.95),
		Vector3(-width * 0.30 + 1.04, 2.58, front + 0.95), 0.055, GiltPalette.ROPE)
	# Сеть: «провисшее» полотно из полос, как на прежних сушильнях.
	for i in range(12):
		var t := (float(i) + 0.5) / 12.0
		var x := lerpf(-width * 0.29, -width * 0.29 + 1.0, t)
		GiltShapes.beam(_dark, Vector3(x, 2.54, front + 0.95),
			Vector3(x, 1.55 - sin(t * PI) * 0.22, front + 1.02), 0.02, Color("3b4a3a"))
	# Бочки и канаты под лестницей.
	GiltShapes.cylinder(_wood, Vector3(width * 0.30, 0.44, front + 0.55),
		0.34, 0.34, 0.84, GiltPalette.WOOD_WARM, 10)
	for i in range(3):
		GiltShapes.cylinder(_dark, Vector3(width * 0.18, 0.28 + float(i) * 0.055, front + 0.90),
			0.28, 0.28, 0.04, GiltPalette.ROPE.darkened(0.10), 10)


## Фонарная будка смотрителя маяка на крыше: стеклянный фонарь под куполом.
func _lantern_room() -> void:
	var base_y := ridge + 0.12
	var h := 1.45
	# Барабан будки: восемь стоек и остекление между ними.
	for i in range(8):
		var a := TAU * float(i) / 8.0
		var p := Vector3(cos(a) * 0.78, 0.0, sin(a) * 0.78)
		GiltShapes.beam(_wood, Vector3(0.0, base_y, 0.0) + p,
			Vector3(0.0, base_y + h, 0.0) + p * 0.92, 0.075, palette["trim"] * 0.60)
	for i in range(8):
		var a0 := TAU * float(i) / 8.0
		var a1 := TAU * float(i + 1) / 8.0
		var p0 := Vector3(cos(a0) * 0.75, 0.0, sin(a0) * 0.75)
		var p1 := Vector3(cos(a1) * 0.75, 0.0, sin(a1) * 0.75)
		var mid := (p0 + p1) * 0.5 * 1.25
		GiltShapes.out_quad(_glass, Vector3(0.0, base_y + 0.12, 0.0) + p0,
			Vector3(0.0, base_y + 0.12, 0.0) + p1,
			Vector3(0.0, base_y + h - 0.12, 0.0) + p1 * 0.96,
			Vector3(0.0, base_y + h - 0.12, 0.0) + p0 * 0.96,
			palette["glass"].lerp(Color("fff2c9"), 0.35), Vector3(0.0, base_y + h * 0.5, 0.0))
	# Купол, шпиль и линза внутри.
	GiltShapes.hip_roof(_roof, Vector3(0.0, base_y + h - 0.02, 0.0), 1.90, 1.90,
		0.0, 0.62, palette["roof"], GiltPalette.GILT * 0.5, 0.10)
	GiltShapes.spire(_gilt, Vector3(0.0, base_y + h + 0.58, 0.0), 0.14, 0.86,
		GiltPalette.GILT, 4, PI * 0.25)
	GiltShapes.box(_dark, Vector3(0.0, base_y + h + 0.62, 0.0),
		Vector3(0.50, 0.05, 0.05), GiltPalette.IRON)
	var lens := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.20
	sphere.height = 0.40
	lens.mesh = sphere
	var lens_mat := StandardMaterial3D.new()
	lens_mat.albedo_color = palette["glass"]
	lens_mat.emission_enabled = true
	lens_mat.emission = palette["glass"]
	lens_mat.emission_energy_multiplier = 0.0
	lens.material_override = lens_mat
	lens.position = Vector3(0.0, base_y + h * 0.52, 0.0)
	add_child(lens)
	_glow.append(lens)
	# Галерея вокруг будки: перила и кронштейны.
	for i in range(8):
		var a := TAU * float(i) / 8.0
		var p := Vector3(cos(a) * 1.10, 0.0, sin(a) * 1.10)
		GiltShapes.beam(_dark, Vector3(0.0, base_y - 0.02, 0.0) + p,
			Vector3(0.0, base_y + 0.52, 0.0) + p, 0.035, GiltPalette.IRON)
		GiltShapes.beam(_dark, Vector3(0.0, base_y + 0.52, 0.0) + p,
			Vector3(0.0, base_y + 0.52, 0.0) + p * 1.02, 0.028, GiltPalette.IRON)
	GiltShapes.ring(_dark, Vector3(0.0, base_y + 0.52, 0.0), 1.12, 1.02, 0.035,
		GiltPalette.IRON, 16, Vector3.UP)


## Таверна: навес на столбах, длинный стол, скамьи, бочки, фонари.
func _tavern() -> void:
	var front := depth * 0.5
	var porch_y := 2.85
	# Навес во всю ширину фасада.
	GiltShapes.pent_roof(_roof, Vector3(0.0, porch_y, front + 0.95), width * 0.82, 1.85,
		0.10, 0.34, palette["roof"], GiltPalette.LEAD)
	for sx in [-1.0, 1.0]:
		var x: float = float(sx) * width * 0.36
		GiltShapes.cylinder(_wood, Vector3(x, 1.40, front + 1.72), 0.10, 0.08, 2.80,
			palette["trim"] * 0.55, 8)
		GiltShapes.box(_stone, Vector3(x, 0.10, front + 1.72), Vector3(0.34, 0.18, 0.34),
			palette["stone"] * 1.3)
		# Фонарь на столбе навеса.
		GiltShapes.box(_gilt, Vector3(x, porch_y - 0.18, front + 1.72),
			Vector3(0.16, 0.24, 0.16), GiltPalette.LAMP_WARM)
	# Стол и скамьи под навесом: место, где деревня разговаривает.
	GiltShapes.box(_wood, Vector3(0.0, 0.80, front + 1.20), Vector3(width * 0.50, 0.10, 0.86),
		GiltPalette.WOOD_WARM)
	for sx in [-1.0, 1.0]:
		GiltShapes.box(_wood, Vector3(float(sx) * width * 0.20, 0.46, front + 1.20),
			Vector3(0.12, 0.80, 0.76), GiltPalette.WOOD_DARK)
	for sz in [-1.0, 1.0]:
		GiltShapes.box(_wood, Vector3(0.0, 0.44, front + 1.20 + float(sz) * 0.80),
			Vector3(width * 0.46, 0.09, 0.34), GiltPalette.WOOD_WARM.darkened(0.10))
		for k in range(2):
			GiltShapes.box(_wood, Vector3(float(k * 2 - 1) * width * 0.18, 0.22,
				front + 1.20 + float(sz) * 0.80), Vector3(0.09, 0.44, 0.30),
				GiltPalette.WOOD_DARK)
	# Бочки у стены, кружки, доска объявлений.
	for i in range(3):
		GiltShapes.cylinder(_wood, Vector3(-width * 0.40 + float(i) * 0.52, 0.42,
			front + 0.55), 0.28, 0.28, 0.80, GiltPalette.WOOD_WARM, 10)
		GiltShapes.cylinder(_dark, Vector3(-width * 0.40 + float(i) * 0.52, 0.60,
			front + 0.55), 0.30, 0.30, 0.04, GiltPalette.IRON, 10)
	# Вывеска на кронштейне — качающийся «ТИХИЙ ВАЛ».
	GiltShapes.beam(_dark, Vector3(width * 0.5 + 0.04, 3.05, front + 0.10),
		Vector3(width * 0.5 + 0.90, 3.05, front + 0.10), 0.05, GiltPalette.IRON)
	GiltShapes.beam(_dark, Vector3(width * 0.5 + 0.86, 3.03, front + 0.10),
		Vector3(width * 0.5 + 0.86, 2.62, front + 0.10), 0.025, GiltPalette.IRON)
	GiltShapes.box(_wood, Vector3(width * 0.5 + 0.86, 2.32, front + 0.10),
		Vector3(0.62, 0.46, 0.06), palette["door"].darkened(0.20))
	GiltShapes.beam(_gilt, Vector3(width * 0.5 + 0.56, 2.52, front + 0.15),
		Vector3(width * 0.5 + 1.16, 2.52, front + 0.15), 0.02, GiltPalette.GILT * 0.8)


## Солеварня: каменные стены, двойные ворота, журавль, чан и соль.
func _salting() -> void:
	var front := depth * 0.5
	# Двойные ворота вместо двери: соль вносят тачкой.
	for sx in [-1.0, 1.0]:
		GiltShapes.box(_wood, Vector3(float(sx) * 0.58, 1.02, front + 0.10),
			Vector3(1.10, 2.00, 0.10), palette["door"].darkened(0.15))
		for k in range(5):
			GiltShapes.beam(_dark, Vector3(float(sx) * 0.58 - 0.44 + float(k) * 0.22, 0.10,
				front + 0.16), Vector3(float(sx) * 0.58 - 0.44 + float(k) * 0.22, 1.96,
				front + 0.16), 0.014, GiltPalette.IRON)
		GiltShapes.beam(_gilt, Vector3(float(sx) * 0.58 - 0.50, 1.74, front + 0.17),
			Vector3(float(sx) * 0.58 + 0.48, 1.74, front + 0.17), 0.028, GiltPalette.GILT * 0.8)
	# Журавль над воротами: поднимать мешки с солью.
	GiltShapes.beam(_wood, Vector3(0.0, 3.15, front + 0.10), Vector3(0.0, 3.55, front + 1.55),
		0.09, GiltPalette.WOOD_DARK)
	GiltShapes.beam(_wood, Vector3(0.0, 3.55, front + 1.55), Vector3(0.0, 3.55, front + 2.25),
		0.07, GiltPalette.WOOD_DARK)
	GiltShapes.cylinder(_dark, Vector3(0.0, 3.55, front + 2.25), 0.08, 0.08, 0.08,
		GiltPalette.IRON, 8, Basis(Vector3.RIGHT, PI * 0.5))
	GiltShapes.beam(_dark, Vector3(0.0, 3.55, front + 2.25), Vector3(0.0, 2.90, front + 2.25),
		0.022, GiltPalette.ROPE)
	GiltShapes.box(_wood, Vector3(0.0, 2.70, front + 2.25), Vector3(0.42, 0.30, 0.30),
		GiltPalette.CLOTH.darkened(0.15))
	# Чан для рассола, бочки, лопаты.
	GiltShapes.cylinder(_stone, Vector3(-width * 0.34, 0.42, front + 1.45),
		0.62, 0.56, 0.84, palette["stone"] * 1.3, 14)
	GiltShapes.ring(_gilt, Vector3(-width * 0.34, 0.78, front + 1.45), 0.58, 0.44, 0.05,
		GiltPalette.GILT * 0.55, 14, Vector3.UP)
	for i in range(4):
		GiltShapes.cylinder(_wood, Vector3(width * 0.28 + float(i % 2) * 0.56, 0.38,
			front + 0.70 + float(i / 2) * 0.56), 0.24, 0.24, 0.72,
			GiltPalette.CLOTH.darkened(0.25), 10)


## Лавка-школа: витрина, навес, ящики, колокольчик над дверью.
func _shop() -> void:
	var front := depth * 0.5
	# Витрина с переплётом и прилавком-подоконником.
	GiltShapes.box(_wood, Vector3(-width * 0.26, 1.48, front + 0.08),
		Vector3(2.30, 1.30, 0.10), Color("2a2a30"))
	for i in range(3):
		GiltShapes.box(_glass, Vector3(-width * 0.26, 1.48, front + 0.14),
			Vector3(0.66, 1.10, 0.02), palette["glass"])
		for k in range(2):
			GiltShapes.beam(_dark, Vector3(-width * 0.26 - 0.72 + float(k) * 1.34, 1.48,
				front + 0.18), Vector3(-width * 0.26 - 0.72 + float(k) * 1.34, 0.90,
				front + 0.18), 0.035, GiltPalette.IRON)
	GiltShapes.beam(_dark, Vector3(-width * 0.26 - 0.86, 1.52, front + 0.18),
		Vector3(-width * 0.26 + 0.90, 1.52, front + 0.18), 0.035, GiltPalette.IRON)
	GiltShapes.beam(_dark, Vector3(-width * 0.26, 0.88, front + 0.18),
		Vector3(-width * 0.26, 2.12, front + 0.18), 0.035, GiltPalette.IRON)
	GiltShapes.box(_wood, Vector3(-width * 0.26, 0.82, front + 0.34),
		Vector3(2.42, 0.12, 0.42), GiltPalette.WOOD_WARM)
	# Навес над витриной на двух кронштейнах.
	GiltShapes.pent_roof(_roof, Vector3(-width * 0.24, 2.42, front + 0.55), 2.90, 1.35,
		0.06, 0.26, palette["roof"].lightened(0.08), GiltPalette.LEAD)
	for sx in [-1.0, 1.0]:
		GiltShapes.beam(_dark, Vector3(-width * 0.26 + float(sx) * 1.30, 2.40, front + 0.10),
			Vector3(-width * 0.26 + float(sx) * 1.30, 2.16, front + 1.05), 0.045,
			GiltPalette.IRON)
	# Ящики, бочонок, доска объявлений — товар выставлен на улицу.
	for i in range(3):
		GiltShapes.box(_wood, Vector3(width * 0.20 + float(i) * 0.42, 0.30, front + 0.50),
			Vector3(0.38, 0.44, 0.38), GiltPalette.WOOD_WARM.darkened(0.06 * float(i)))
	GiltShapes.cylinder(_wood, Vector3(width * 0.38, 0.34, front + 1.10), 0.24, 0.24, 0.64,
		GiltPalette.WOOD_WARM, 10)
	# Колокольчик над дверью: лавка открыта, когда он на крючке.
	GiltShapes.beam(_dark, Vector3(0.0, 3.05, front + 0.10), Vector3(0.0, 3.05, front + 0.42),
		0.035, GiltPalette.IRON)
	GiltShapes.cylinder(_gilt, Vector3(0.0, 2.86, front + 0.40), 0.11, 0.06, 0.16,
		GiltPalette.GILT_HOT, 8)


## Кузня: широкий горн-дымоход, наковальня, чан, уголь, искры.
func _forge() -> void:
	var front := depth * 0.5
	# Горн: массивная каменная труба у задней стены, шире обычной.
	GiltShapes.box(_stone, Vector3(-width * 0.36, 2.55, -depth * 0.28),
		Vector3(1.10, 4.60, 1.10), palette["stone"] * 1.24)
	GiltShapes.chimney_top(_stone, Vector3(-width * 0.36, 4.70, -depth * 0.28),
		1.10, palette["trim"] * 0.55, GiltPalette.IRON)
	_smoke_points.append(Vector3(-width * 0.36, 4.95, -depth * 0.28))
	# Наковальня на пне и ящик с инструментом.
	GiltShapes.cylinder(_wood, Vector3(width * 0.36, 0.26, front + 1.05), 0.28, 0.24, 0.52,
		GiltPalette.WOOD_DARK, 8)
	GiltShapes.box(_dark, Vector3(width * 0.36, 0.64, front + 1.05), Vector3(0.62, 0.18, 0.26),
		GiltPalette.IRON)
	GiltShapes.beam(_dark, Vector3(width * 0.36 - 0.18, 0.64, front + 1.05),
		Vector3(width * 0.36 + 0.22, 0.64, front + 1.05), 0.10, GiltPalette.IRON)
	GiltShapes.box(_wood, Vector3(width * 0.46, 0.20, front + 1.70),
		Vector3(0.52, 0.36, 0.34), GiltPalette.WOOD_DARK)
	for i in range(4):
		GiltShapes.beam(_dark, Vector3(width * 0.30 + float(i) * 0.09, 0.18, front + 1.68),
			Vector3(width * 0.30 + float(i) * 0.09, 0.62, front + 1.66), 0.028,
			GiltPalette.IRON)
	# Чан для закалки (пар ночью), куча угля под навесом.
	GiltShapes.cylinder(_wood, Vector3(-width * 0.38, 0.44, front + 1.55), 0.42, 0.42, 0.88,
		palette["stone"] * 0.95, 12)
	GiltShapes.cylinder(_dark, Vector3(-width * 0.38, 0.86, front + 1.55), 0.42, 0.42, 0.04,
		GiltPalette.IRON, 12)
	for i in range(7):
		var a := TAU * float(i) / 7.0
		GiltShapes.spire(_wood, Vector3(-width * 0.10 + cos(a) * 0.42, 0.10,
			front + 0.72 + sin(a) * 0.34), 0.16, 0.28, Color("171a1e"), 5, a)


## Дом пастора: контрфорсы, роза-окно, сад с оградой и скамьёй.
func _parsonage() -> void:
	var front := depth * 0.5
	for sx in [-1.0, 1.0]:
		var x: float = float(sx) * (width * 0.5 - 0.32)
		for i in range(3):
			var y := 0.30 + float(i) * 0.72
			var w := 0.46 - float(i) * 0.10
			GiltShapes.box(_stone, Vector3(x, y, front + 0.10), Vector3(w, 0.72, 0.30),
				palette["stone"] * 1.35)
			GiltShapes.box(_gilt, Vector3(x, y + 0.36, front + 0.11),
				Vector3(w + 0.02, 0.025, 0.30), GiltPalette.GILT * 0.55)
		GiltShapes.spire(_gilt, Vector3(x, 2.50, front + 0.10), 0.12, 0.46,
			GiltPalette.GILT * 0.9, 4, PI * 0.25)
	# Роза-окно над дверью: кольцо, восемь спиц, витраж.
	var at := Vector3(0.0, eaves + 0.48, front + 0.02)
	GiltShapes.ring(_glass, at, 0.62, 0.48, 0.05, palette["glass"], 18, Vector3(0.0, 0.0, 1.0))
	GiltShapes.ring(_stone, at + Vector3(0.0, 0.0, 0.04), 0.78, 0.60, 0.16,
		palette["trim"] * 0.55, 18, Vector3(0.0, 0.0, 1.0))
	for i in range(8):
		var a := TAU * float(i) / 8.0
		GiltShapes.beam(_stone, at + Vector3(cos(a), sin(a), 0.06) * 0.18,
			at + Vector3(cos(a), sin(a), 0.06) * 0.58, 0.035, GiltPalette.LEAD)
	# Сад: ограда, скамья, яблоня-«ветер», дорожка.
	for sx in [-1.0, 1.0]:
		var a := Vector3(float(sx) * (width * 0.5 + 0.2), 0.0, front + 0.6)
		var b := Vector3(float(sx) * (width * 0.5 + 0.2), 0.0, front + 3.2)
		for i in range(6):
			var p := a.lerp(b, float(i) / 5.0)
			p.y = 0.0
			GiltShapes.box(_dark, p + Vector3(0.0, 0.34, 0.0), Vector3(0.06, 0.68, 0.06),
				GiltPalette.IRON)
		GiltShapes.beam(_dark, a + Vector3(0.0, 0.66, 0.0), b + Vector3(0.0, 0.66, 0.0),
			0.035, GiltPalette.IRON)
	GiltShapes.box(_wood, Vector3(width * 0.30, 0.44, front + 2.10), Vector3(1.20, 0.09, 0.38),
		GiltPalette.WOOD_WARM)
	for sx in [-1.0, 1.0]:
		GiltShapes.box(_wood, Vector3(width * 0.30 + float(sx) * 0.50, 0.22, front + 2.10),
			Vector3(0.09, 0.44, 0.34), GiltPalette.WOOD_DARK)


## Дом лоцмана: сигнальная мачта с флагами, фонарь, лодка у стены.
func _pilot() -> void:
	var side := width * 0.5
	# Мачта с реей и двумя флагами — её видно с моря раньше дома.
	GiltShapes.cylinder(_wood, Vector3(side + 0.75, 2.55, -depth * 0.20), 0.075, 0.045,
		5.10, GiltPalette.WOOD_DARK, 8)
	GiltShapes.beam(_wood, Vector3(side + 0.75, 4.20, -depth * 0.20),
		Vector3(side + 1.95, 4.20, -depth * 0.20), 0.05, GiltPalette.WOOD_DARK)
	var flag_a := Vector3(side + 1.92, 4.18, -depth * 0.20)
	GiltShapes.out_quad(_wood, flag_a, flag_a + Vector3(-0.62, -0.12, 0.0),
		flag_a + Vector3(-0.62, -0.52, 0.0), flag_a + Vector3(0.0, -0.34, 0.0),
		Color("b4543c"), flag_a + Vector3(-0.30, -0.20, 0.3))
	var flag_b := flag_a + Vector3(0.0, -0.62, 0.0)
	GiltShapes.out_quad(_wood, flag_b, flag_b + Vector3(-0.48, -0.06, 0.0),
		flag_b + Vector3(-0.48, -0.38, 0.0), flag_b + Vector3(0.0, -0.26, 0.0),
		Color("d2a24c"), flag_b + Vector3(-0.24, -0.16, 0.3))
	GiltShapes.cylinder(_gilt, Vector3(side + 0.75, 5.20, -depth * 0.20), 0.09, 0.03,
		0.22, GiltPalette.GILT, 8)
	# Фонарь на углу и лодка под стеной.
	GiltShapes.box(_gilt, Vector3(-side + 0.25, 2.55, depth * 0.5 + 0.18),
		Vector3(0.18, 0.26, 0.18), GiltPalette.LAMP_WARM)
	GiltShapes.beam(_dark, Vector3(-side + 0.25, 2.68, depth * 0.5 + 0.18),
		Vector3(-side + 0.25, 2.95, depth * 0.5 + 0.02), 0.035, GiltPalette.IRON)
	# Лодка килем вверх на козлах: ремонт, а не декорация.
	for i in range(2):
		var z := -depth * 0.10 + float(i) * 0.95
		for sx in [-1.0, 1.0]:
			GiltShapes.beam(_wood, Vector3(-side - 0.65 + float(sx) * 0.0, 0.0, z),
				Vector3(-side - 0.65, 0.55, z), 0.07, GiltPalette.WOOD_DARK)
		GiltShapes.beam(_wood, Vector3(-side - 1.05, 0.54, z),
			Vector3(-side - 0.25, 0.54, z), 0.07, GiltPalette.WOOD_DARK)
	for i in range(4):
		var x := -side - 1.05 + float(i) * 0.26
		GiltShapes.beam(_wood, Vector3(x, 0.60, -depth * 0.35),
			Vector3(x + 0.10, 1.28, -depth * 0.35), 0.08, GiltPalette.WOOD_WARM)


# --- Мелочи и «жизнь» -------------------------------------------------------

func _details() -> void:
	var front := depth * 0.5
	# Поленница и ящик для устриц под задней стеной.
	for row in range(3):
		for i in range(4 - row):
			GiltShapes.cylinder(_wood,
				Vector3(width * 0.30 + float(i) * 0.18, 0.14 + float(row) * 0.18,
					-depth * 0.5 - 0.35 + float(row) * 0.09),
				0.075, 0.075, 0.56, GiltPalette.WOOD_WARM.darkened(0.16), 6,
				Basis(Vector3.RIGHT, PI * 0.5))
	# Кошачья лежанка у двери и миска: дом обитаем и днём.
	GiltShapes.cylinder(_wood, Vector3(-width * 0.30, 0.16, front + 0.78), 0.32, 0.28, 0.14,
		Color("6b5a44"), 10)
	GiltShapes.cylinder(_stone, Vector3(-width * 0.30 + 0.55, 0.14, front + 0.78), 0.14, 0.11,
		0.10, Color("8d8577"), 8)
	# Флюгер на щипце: дом называет ветер.
	var ridge_y := ridge + 0.02
	GiltShapes.cylinder(_dark, Vector3(width * 0.5 - 0.30, ridge_y + 0.30, -depth * 0.2),
		0.02, 0.012, 0.55, GiltPalette.IRON, 5)
	GiltShapes.beam(_gilt, Vector3(width * 0.5 - 0.58, ridge_y + 0.56, -depth * 0.2),
		Vector3(width * 0.5 - 0.02, ridge_y + 0.56, -depth * 0.2), 0.028, GiltPalette.GILT)
	GiltShapes.spire(_gilt, Vector3(width * 0.5 - 0.58, ridge_y + 0.56, -depth * 0.2),
		0.06, 0.14, GiltPalette.GILT, 4, PI * 0.25)
	# Голуби на коньке: две фигурки, дешёвая, но живая деталь.
	for i in range(2):
		var x := -width * 0.10 + float(i) * 0.55
		GiltShapes.cylinder(_dark, Vector3(x, ridge_y + 0.22, 0.20), 0.06, 0.045, 0.18,
			Color("4a5468"), 6)
		GiltShapes.spire(_dark, Vector3(x, ridge_y + 0.34, 0.20), 0.07, 0.14,
			Color("4a5468"), 5)


func _commit() -> void:
	_bake("Stone", _stone, _material(0.9, 0.02))
	_bake("Roof", _roof, _material(0.95, 0.08))
	_bake("Gilt", _gilt, _material(0.30, 0.70))
	window_material = _glass_material()
	_bake("Glass", _glass, window_material)
	_bake("Wood", _wood, _material(0.92, 0.0))
	_bake("Iron", _dark, _material(0.55, 0.60))
	# Дым: одна сетка частиц на каждый дымоход.
	for point in _smoke_points:
		_smoke(point)


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


func _bake(node_name: String, surface: SurfaceTool, material: Material) -> void:
	var mesh := surface.commit()
	if mesh == null or mesh.get_surface_count() == 0:
		return
	var visual := MeshInstance3D.new()
	visual.name = node_name
	visual.mesh = mesh
	visual.material_override = material
	# Тени домов дают посёлку объём: без них крыши «наклеены» на землю.
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(visual)


func _smoke(at: Vector3) -> void:
	var particles := GPUParticles3D.new()
	particles.name = "ChimneySmoke"
	particles.amount = 12
	particles.lifetime = 6.5
	particles.preprocess = 3.0
	particles.position = at
	particles.visibility_aabb = AABB(Vector3(-3.0, -0.5, -3.0), Vector3(6.0, 9.0, 6.0))
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3(0.45, 1.0, 0.10)
	process.spread = 13.0
	process.initial_velocity_min = 0.22
	process.initial_velocity_max = 0.50
	process.gravity = Vector3(0.22, 0.10, -0.06)
	process.scale_min = 0.30
	process.scale_max = 0.78
	var scale_texture := CurveTexture.new()
	scale_texture.curve = _smoke_curve()
	process.scale_curve = scale_texture
	process.color = Color(0.72, 0.70, 0.82, 0.26)
	particles.process_material = process
	var quad := QuadMesh.new()
	quad.size = Vector2(0.55, 0.55)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.70, 0.68, 0.80, 0.20)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
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


# --- Ночь и взаимодействие -------------------------------------------------

func set_night(amount: float) -> void:
	night01 = clampf(amount, 0.0, 1.0)
	var glow := maxf(0.0, night01 - 0.18) * 1.7
	if window_material != null:
		window_material.emission_energy_multiplier = glow
	for node in _glow:
		if not is_instance_valid(node):
			continue
		var mat := node.material_override as StandardMaterial3D
		if mat != null and mat.emission_enabled:
			mat.emission_energy_multiplier = maxf(0.0, night01 - 0.22) * 2.4
	if _light != null:
		_light.light_energy = maxf(0.0, night01 - 0.28) * 0.65
	if _highlight_mat != null:
		_highlight_mat.emission_energy_multiplier = 0.55 + 0.45 * night01


## Кольцо на земле вокруг дома: единственный «интерфейс» в мире.
## Появляется только при наведении, пока лодка пришвартована.
func _add_highlight() -> void:
	var torus := TorusMesh.new()
	torus.inner_radius = maxf(width, depth) * 0.52
	torus.outer_radius = maxf(width, depth) * 0.58
	torus.rings = 32
	torus.ring_segments = 6
	_highlight_mat = StandardMaterial3D.new()
	_highlight_mat.albedo_color = GiltPalette.LAMP_NEON
	_highlight_mat.emission_enabled = true
	_highlight_mat.emission = GiltPalette.LAMP_NEON
	_highlight_mat.emission_energy_multiplier = 0.7
	_highlight_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_highlight_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_highlight_mat.albedo_color.a = 0.65
	_highlight = MeshInstance3D.new()
	_highlight.name = "HoverRing"
	_highlight.mesh = torus
	_highlight.material_override = _highlight_mat
	_highlight.position = Vector3(0.0, 0.10, 0.0)
	_highlight.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_highlight.visible = false
	add_child(_highlight)


func set_highlight(on: bool) -> void:
	if _highlight != null:
		_highlight.visible = on
	if _nameplate != null:
		_nameplate.visible = on


func house_label() -> String:
	return String(plan.get("sign", "ДОМ"))


## Точка, где стоит житель: перед домом, чуть в стороне от двери.
func resident_spot() -> Vector3:
	var x := width * 0.28 if width > 7.0 else width * 0.34
	return to_global(Vector3(x, 0.06, depth * 0.5 + 1.05))


## Пересечение луча с габаритом дома (для клика без физики).
## Возвращает дистанцию вдоль луча или -1.
func ray_distance(origin: Vector3, direction: Vector3) -> float:
	if not is_inside_tree():
		return -1.0
	var local_origin := to_local(origin)
	var local_dir := (global_transform.basis.inverse() * direction).normalized()
	var box := AABB(Vector3(-width * 0.5 - 0.2, -0.3, -depth * 0.5 - 0.35),
		Vector3(width + 0.4, ridge + 1.1, depth + 0.7))
	var hit = box.intersects_ray(local_origin, local_dir)
	if hit == null:
		return -1.0
	var world_hit := to_global(hit as Vector3)
	return origin.distance_to(world_hit)
