class_name GiltHouse
extends Node3D
## Временные дома рыбацкого посёлка: размеры и цвета отличаются,
## но корпуса, двери и окна простые, без готических украшений.
## Координаты модели: центр пола, +Y вверх, вход в локальный +Z.
## replacement_visual позволяет заменить визуал сценой Blender.

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
		"sign": "ДОМ АННЫ", "width": 7.6, "depth": 6.0, "eaves": 3.65, "ridge": 6.45,
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
var window_material: StandardMaterial3D

var _stone: SurfaceTool
var _roof: SurfaceTool
var _gilt: SurfaceTool
var _glass: SurfaceTool
var _wood: SurfaceTool
var _dark: SurfaceTool
var _glow: Array[MeshInstance3D] = []
var _foundation_bottom := 0.0
var _highlight: MeshInstance3D
var _highlight_mat: StandardMaterial3D
var _nameplate: Label3D
var _smoke_points: Array[Vector3] = []


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
	_plinth(foundation_bottom)
	_walls()
	_roof_cover()
	_street_face()
	_side_faces()
	_workshop_details()
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


# --- Фасад, окна и дверь ----------------------------------------------------

## Уличный фасад (+Z): дверь, окна, ставни, фонарь, вывеска с именем.
func _street_face() -> void:
	var front := depth * 0.5
	# Прямоугольная деревянная дверь и два одинаковых окна: все элементы
	# находятся на одной плоскости фасада, не пересекают дорогу или соседа.
	GiltShapes.box(_wood, Vector3(0.0, 1.06, front + 0.02),
		Vector3(1.14, 2.04, 0.14), palette["trim"] * 0.65)
	GiltShapes.box(_wood, Vector3(0.0, 1.06, front + 0.10),
		Vector3(0.93, 1.90, 0.05), palette["door"])
	for side in [-1.0, 1.0]:
		var x := float(side) * width * 0.30
		_simple_window(Vector3(x, 1.45, front + 0.04), false)
	GiltShapes.box(_stone, Vector3(0.0, 0.04, front + 0.30),
		Vector3(1.45, 0.12, 0.48), palette["stone"].lightened(0.12))


func _side_faces() -> void:
	for side in [-1.0, 1.0]:
		_simple_window(Vector3(float(side) * (width * 0.5 + 0.03), 1.45, 0.0), true)


func _simple_window(at: Vector3, side_wall: bool) -> void:
	var frame_size := Vector3(0.11, 1.10, 0.90) if side_wall else Vector3(0.90, 1.10, 0.11)
	var glass_size := Vector3(0.12, 0.86, 0.66) if side_wall else Vector3(0.66, 0.86, 0.12)
	GiltShapes.box(_wood, at, frame_size, palette["trim"] * 0.80)
	GiltShapes.box(_glass, at, glass_size, palette["glass"])


## Отличительные рабочие детали каждого дома. Все крепятся к стене или
## крыше: не занимают соседние участки и не загромождают улицу.
func _workshop_details() -> void:
	var front := depth * 0.5
	var feature := String(plan.get("feature", ""))
	match feature:
		"loft":
			# Грузовой люк и кронштейн под коньком сетевого сарая.
			var x := width * 0.5 + 0.06
			GiltShapes.box(_wood, Vector3(x, eaves + 0.58, 0.0),
				Vector3(0.12, 0.90, 1.22), palette["door"].darkened(0.18))
			GiltShapes.beam(_wood, Vector3(x, eaves + 1.12, 0.0),
				Vector3(x + 0.75, eaves + 1.12, 0.0), 0.09, GiltPalette.WOOD_DARK)
			GiltShapes.beam(_dark, Vector3(x + 0.70, eaves + 1.1, 0.0),
				Vector3(x + 0.70, eaves + 0.60, 0.0), 0.025, GiltPalette.ROPE)
		"lantern":
			# Небольшая застеклённая смотровая будка, без шпиля.
			var y := ridge + 0.12
			GiltShapes.box(_wood, Vector3(0.0, y, 0.0), Vector3(1.55, 0.18, 1.55), palette["trim"] * 0.65)
			GiltShapes.box(_glass, Vector3(0.0, y + 0.57, 0.0), Vector3(1.10, 0.98, 1.10), palette["glass"])
			for sx in [-1.0, 1.0]:
				for sz in [-1.0, 1.0]:
					GiltShapes.beam(_wood, Vector3(float(sx) * 0.58, y + 0.08, float(sz) * 0.58),
						Vector3(float(sx) * 0.58, y + 1.10, float(sz) * 0.58), 0.09, palette["trim"])
			GiltShapes.hip_roof(_roof, Vector3(0.0, y + 1.08, 0.0), 1.55, 1.55,
				0.0, 0.40, palette["roof"], palette["trim"], 0.06)
		"tavern":
			# Рабочая веранда с обращённой к гавани стороны, отдельно от улицы.
			var back := -depth * 0.5
			GiltShapes.box(_wood, Vector3(0.0, 0.10, back - 0.65),
				Vector3(width * 0.72, 0.20, 1.35), GiltPalette.WOOD_WARM)
			GiltShapes.pent_roof(_roof, Vector3(0.0, 2.60, back - 0.62), width * 0.76,
				1.35, 0.08, 0.22, palette["roof"], GiltPalette.LEAD)
			for x in [-width * 0.33, width * 0.33]:
				GiltShapes.beam(_wood, Vector3(float(x), 0.20, back - 1.20),
					Vector3(float(x), 2.55, back - 1.20), 0.12, palette["trim"] * 0.65)
			# Небольшой крытый вход, без стола посреди дороги.
			GiltShapes.pent_roof(_roof, Vector3(0.0, 2.78, front + 0.52), 2.5, 1.10,
				0.08, 0.20, palette["roof"], GiltPalette.LEAD)
			for x in [-1.0, 1.0]:
				GiltShapes.beam(_wood, Vector3(x, 2.72, front + 0.95),
					Vector3(x, 2.32, front + 0.10), 0.07, palette["trim"])
		"shop":
			# Навес над витриной слева от входа.
			GiltShapes.pent_roof(_roof, Vector3(-width * 0.30, 2.34, front + 0.35),
				1.65, 0.72, 0.06, 0.18, palette["roof"].lightened(0.12), GiltPalette.LEAD)
		"salting":
			# Поперечины на широком складском входе.
			for y in [0.48, 1.55]:
				GiltShapes.box(_dark, Vector3(0.0, float(y), front + 0.15),
					Vector3(0.86, 0.07, 0.04), GiltPalette.IRON)
		"forge":
			# Характерная широкая труба и табличка мастерской на фасаде.
			GiltShapes.box(_stone, Vector3(width * 0.32, ridge + 0.25, 0.0),
				Vector3(0.92, 1.40, 0.90), palette["stone"].lightened(0.12))
		"pilot":
			# Небольшой сигнальный кронштейн над фасадом.
			GiltShapes.beam(_wood, Vector3(width * 0.38, eaves - 0.3, front + 0.04),
				Vector3(width * 0.38, eaves + 0.5, front + 0.04), 0.06, GiltPalette.WOOD_DARK)
			GiltShapes.box(_wood, Vector3(width * 0.38 + 0.25, eaves + 0.25, front + 0.05),
				Vector3(0.48, 0.28, 0.05), Color("b4543c"))
		_:
			pass
	# Второй этаж мастерской и таверны читается окнами, а не пустой коробкой.
	if int(plan["storeys"]) > 1:
		for side in [-1.0, 1.0]:
			_simple_window(Vector3(float(side) * width * 0.26, eaves - 0.66, front + 0.04), false)
	# Ставни и оконные перемычки дают фасадам масштаб, не закрывая стёкла.
	for side in [-1.0, 1.0]:
		var x := float(side) * width * 0.30
		for offset in [-0.59, 0.59]:
			GiltShapes.box(_wood, Vector3(x + float(offset), 1.45, front + 0.10),
				Vector3(0.21, 1.06, 0.08), palette["door"].darkened(0.10))
		GiltShapes.box(_wood, Vector3(x, 1.45, front + 0.12),
			Vector3(0.65, 0.045, 0.04), palette["trim"])


func _add_nameplate() -> void:
	var front := depth * 0.5
	var door_x := 0.0
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
