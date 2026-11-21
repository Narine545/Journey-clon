class_name GiltProps
extends RefCounted
## Уличная мебель и «жизнь» посёлка: ворота, фонари, фонтан, прилавки,
## колокол у причала, сушильни, ограды, арка на площади.
##
## Всё процедурное (GiltShapes + MeshKit) и складывается в SurfaceTool по
## материалам, поэтому весь посёлок — это десятки сеток, а не тысячи узлов.
## Каждая функция принимает SurfaceTool-набор и точку на земле: рельеф
## посёлок не трогает, инстансы сами читают высоту.

const WATER_SHADER := "res://shaders/gilt_neon_water.gdshader"

var main: BoatMain
var host: Node3D
var _stone: SurfaceTool
var _gilt: SurfaceTool
var _wood: SurfaceTool
var _glass: SurfaceTool
var _dark: SurfaceTool
var _lights: Array[Dictionary] = []
var _time := 0.0


## host — узел посёлка: сюда вешаются источники света (они не геометрия
## и не могут жить в SurfaceTool).
func setup(owner_main: BoatMain, owner_host: Node3D) -> void:
	main = owner_main
	host = owner_host


func begin() -> void:
	_stone = GiltShapes.begin()
	_gilt = GiltShapes.begin()
	_wood = GiltShapes.begin()
	_glass = GiltShapes.begin()
	_dark = GiltShapes.begin()


## Точка на земле: (x, z) -> Vector3 с высотой рельефа.
func ground(x: float, z: float) -> Vector3:
	return Vector3(x, main.coast.ground_height(x, z), z)


func commit(parent: Node3D) -> void:
	_bake(parent, "PropsStone", _stone, _material(0.88, 0.02))
	_bake(parent, "PropsGilt", _gilt, _material(0.30, 0.70))
	_bake(parent, "PropsWood", _wood, _material(0.92, 0.0))
	_bake(parent, "PropsGlass", _glass, _glass_material())
	_bake(parent, "PropsIron", _dark, _material(0.55, 0.55))


func _bake(parent: Node3D, node_name: String, surface: SurfaceTool,
		material: Material) -> void:
	var mesh := surface.commit()
	if mesh == null or mesh.get_surface_count() == 0:
		return
	var visual := MeshInstance3D.new()
	# Имена уникальны внутри узла-хозяина: commit() вызывается несколько раз
	# (рынок, площадь, детали), и дубли имён Godot правил бы сам — но тогда
	# get_node_or_null() по имени перестал бы работать.
	visual.name = node_name if parent.get_node_or_null(NodePath(node_name)) == null \
		else "%s%d" % [node_name, parent.get_child_count()]
	visual.mesh = mesh
	visual.material_override = material
	parent.add_child(visual)


func _material(roughness: float, metallic: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color.WHITE
	mat.vertex_color_use_as_albedo = true
	mat.roughness = roughness
	mat.metallic = metallic
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat


func _glass_material() -> StandardMaterial3D:
	var mat := _material(0.18, 0.25)
	mat.emission_enabled = true
	mat.emission = GiltPalette.LAMP_NEON
	mat.emission_energy_multiplier = 0.0
	return mat


# --- Детали ---------------------------------------------------------------

## Кованые ворота с каменными столбами и золотыми фиалами: вход в посёлок.
func gate(at: Vector3, half_width: float, yaw := 0.0) -> void:
	var bx := Basis(Vector3.UP, yaw)
	for sx in [-1.0, 1.0]:
		var base: Vector3 = at + bx * Vector3(float(sx) * half_width, 0.0, 0.0)
		GiltShapes.box(_stone, base + Vector3(0.0, 1.35, 0.0), Vector3(0.52, 2.7, 0.52),
			Color("242936"))
		GiltShapes.box(_stone, base + Vector3(0.0, 2.78, 0.0), Vector3(0.66, 0.16, 0.66),
			GiltPalette.STONE_COLD * 0.62)
		GiltShapes.spire(_gilt, base + Vector3(0.0, 2.86, 0.0), 0.34, 0.62,
			GiltPalette.STONE_COLD * 0.68, 4, PI * 0.25)
		GiltShapes.spire(_gilt, base + Vector3(0.0, 3.46, 0.0), 0.16, 0.54,
			GiltPalette.GILT, 4, PI * 0.25)
		# Фонарь на столбе — вход читается ночью с причала.
		_light_at(base + Vector3(0.0, 2.25, 0.0), GiltPalette.LAMP_WARM, 0.55, 6.0)
		GiltShapes.box(_glass, base + Vector3(0.0, 2.25, 0.0), Vector3(0.18, 0.22, 0.18),
			GiltPalette.LAMP_WARM)
	# Кованая перекладина-арка между столбами и «надпись» из насечек.
	var span := bx * Vector3(half_width, 0.0, 0.0)
	GiltShapes.beam(_dark, at - span + Vector3(0.0, 2.94, 0.0),
		at + span + Vector3(0.0, 2.94, 0.0), 0.08, GiltPalette.IRON)
	for i in range(7):
		var t := (float(i) + 0.5) / 7.0
		var p: Vector3 = at + bx * Vector3(lerpf(-half_width, half_width, t), 3.02, 0.0)
		GiltShapes.box(_gilt, p, Vector3(0.10, 0.16, 0.03), GiltPalette.GILT)
	# Створки: вертикальные прутья с пиками, стоят «открытыми» к дороге.
	for sx in [-1.0, 1.0]:
		var leaf_at: Vector3 = at + bx * Vector3(float(sx) * (half_width - 0.30), 0.0, 0.0)
		for i in range(5):
			var off := float(i) * 0.20
			var p := leaf_at + bx * Vector3(float(sx) * off, 0.0, 0.0)
			GiltShapes.beam(_dark, p + Vector3(0.0, 0.10, 0.0), p + Vector3(0.0, 1.55, 0.0),
				0.045, GiltPalette.IRON)
			GiltShapes.spire(_dark, p + Vector3(0.0, 1.55, 0.0), 0.055, 0.20,
				GiltPalette.IRON, 4, PI * 0.25)


## Уличный фонарь: витая стойка, золотая клетка, тёплый свет.
func lamp_post(at: Vector3, height := 3.4, neon := false) -> void:
	GiltShapes.cylinder(_stone, at + Vector3(0.0, 0.14, 0.0), 0.22, 0.16, 0.28,
		GiltPalette.STONE_COLD * 0.52, 8)
	GiltShapes.cylinder(_dark, at + Vector3(0.0, height * 0.5, 0.0), 0.075, 0.055,
		height, GiltPalette.IRON, 8)
	GiltShapes.box(_gilt, at + Vector3(0.0, height * 0.45, 0.0), Vector3(0.13, 0.13, 0.13),
		GiltPalette.GILT * 0.8)
	# Клетка фонаря: четыре стойки и шатровая крышка.
	var top := at + Vector3(0.0, height + 0.10, 0.0)
	GiltShapes.box(_gilt, top, Vector3(0.34, 0.06, 0.34), GiltPalette.GILT * 0.86)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			GiltShapes.beam(_gilt, top + Vector3(float(sx) * 0.14, -0.02, float(sz) * 0.14),
				top + Vector3(float(sx) * 0.17, 0.30, float(sz) * 0.17), 0.03,
				GiltPalette.GILT * 0.8)
	GiltShapes.spire(_gilt, top + Vector3(0.0, 0.28, 0.0), 0.22, 0.24,
		GiltPalette.GILT * 0.8, 4, PI * 0.25)
	var tint: Color = GiltPalette.LAMP_NEON if neon else GiltPalette.LAMP_WARM
	GiltShapes.box(_glass, top + Vector3(0.0, -0.13, 0.0), Vector3(0.20, 0.26, 0.20), tint)
	_light_at(top + Vector3(0.0, -0.12, 0.0), tint, 0.45 if not neon else 0.55,
		6.5 if not neon else 7.5)


## Каменный фонтан на площади: чаша, вода-неон, обелиск с шаром.
func fountain(at: Vector3) -> void:
	var base := at
	for i in range(3):
		GiltShapes.cylinder(_stone, base + Vector3(0.0, 0.09 + float(i) * 0.16, 0.0),
			1.85 - float(i) * 0.12, 1.79 - float(i) * 0.12, 0.18,
			Color("262b38").darkened(0.05 * float(i)), 16)
	# Внешний борт чаши и вода внутри (плоский диск с неоновым шейдером).
	GiltShapes.cylinder(_stone, base + Vector3(0.0, 0.72, 0.0), 1.52, 1.62, 0.52,
		GiltPalette.STONE_COLD * 0.46, 18)
	GiltShapes.cylinder(_stone, base + Vector3(0.0, 0.96, 0.0), 1.66, 1.60, 0.10,
		GiltPalette.STONE_COLD * 0.58, 18)
	var water := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 1.46
	disc.bottom_radius = 1.46
	disc.height = 0.05
	disc.radial_segments = 24
	water.mesh = disc
	water.position = base + Vector3(0.0, 0.90, 0.0)
	var mat := ShaderMaterial.new()
	mat.shader = load(WATER_SHADER)
	water.material_override = mat
	water.name = "FountainWater"
	host.add_child(water)
	_water = water
	# Обелиск: сужающийся столб, золотые пояса, шар и фиал.
	GiltShapes.cylinder(_stone, base + Vector3(0.0, 1.55, 0.0), 0.34, 0.22, 1.25,
		Color("20242f"), 8)
	for i in range(3):
		GiltShapes.cylinder(_gilt, base + Vector3(0.0, 1.10 + float(i) * 0.36, 0.0),
			0.30 - float(i) * 0.03, 0.29 - float(i) * 0.03, 0.035, GiltPalette.GILT * 0.8, 8)
	GiltShapes.spire(_gilt, base + Vector3(0.0, 2.18, 0.0), 0.22, 0.85,
		GiltPalette.GILT, 4, PI * 0.25)
	var orb := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.30
	sphere.height = 0.60
	sphere.radial_segments = 14
	sphere.rings = 8
	orb.mesh = sphere
	var orb_mat := StandardMaterial3D.new()
	orb_mat.albedo_color = GiltPalette.LAMP_NEON
	orb_mat.emission_enabled = true
	orb_mat.emission = GiltPalette.LAMP_NEON
	orb_mat.emission_energy_multiplier = 0.0
	orb.material_override = orb_mat
	orb.position = base + Vector3(0.0, 3.12, 0.0)
	orb.name = "FountainOrb"
	host.add_child(orb)
	_orb = orb
	_light_at(base + Vector3(0.0, 3.10, 0.0), GiltPalette.LAMP_NEON, 0.55, 9.0)


var _water: MeshInstance3D
var _orb: MeshInstance3D


## Ограда: каменный цоколь, кованые прутья, пики. Тянится по отрезку.
func fence(a: Vector3, b: Vector3, posts := true) -> void:
	var length := Vector2(b.x - a.x, b.z - a.z).length()
	if length < 0.4:
		return
	var seg := maxi(1, int(ceil(length / 2.2)))
	for i in range(seg + 1):
		var t := float(i) / float(seg)
		var p := a.lerp(b, t)
		GiltShapes.box(_stone, Vector3(p.x, p.y + 0.22, p.z), Vector3(0.26, 0.44, 0.26),
			GiltPalette.STONE_COLD * 0.40)
		if posts and i < seg:
			GiltShapes.spire(_gilt, Vector3(p.x, p.y + 0.44, p.z), 0.10, 0.30,
				GiltPalette.GILT * 0.7, 4, PI * 0.25)
	GiltShapes.beam(_dark, a + Vector3(0.0, 0.62, 0.0), b + Vector3(0.0, 0.62, 0.0),
		0.05, GiltPalette.IRON)
	# Прутья через каждые 0.55 м — «частокол», как у готической ограды.
	var bars := maxi(2, int(length / 0.55))
	for i in range(bars):
		var t := (float(i) + 0.5) / float(bars)
		var p := a.lerp(b, t)
		GiltShapes.beam(_dark, p + Vector3(0.0, 0.10, 0.0), p + Vector3(0.0, 1.05, 0.0),
			0.032, GiltPalette.IRON)


## Бочка: обручи, клёпки, тёмное дно. Реквизит у прилавка и у дома.
func barrel(at: Vector3, height := 0.85, radius := 0.32) -> void:
	GiltShapes.cylinder(_wood, at + Vector3(0.0, height * 0.5, 0.0), radius * 0.92,
		radius * 0.92, height, GiltPalette.WOOD_WARM, 10)
	GiltShapes.cylinder(_wood, at + Vector3(0.0, height * 0.5, 0.0), radius, radius,
		height * 0.62, GiltPalette.WOOD_WARM.darkened(0.08), 10)
	for y in [0.22, height * 0.5, height - 0.22]:
		GiltShapes.cylinder(_dark, at + Vector3(0.0, y, 0.0), radius * 1.02, radius * 1.02,
			0.045, GiltPalette.IRON, 10)


## Прилавок под тентом: стол, товар, полосатый навес на двух столбах.
func stall(at: Vector3, yaw := 0.0) -> void:
	var bx := Basis(Vector3.UP, yaw)
	GiltShapes.box(_wood, at + bx * Vector3(0.0, 0.42, 0.0), Vector3(2.5, 0.12, 1.0),
		GiltPalette.WOOD_WARM)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			GiltShapes.beam(_wood, at + bx * Vector3(float(sx) * 1.15, 0.0, float(sz) * 0.42),
				at + bx * Vector3(float(sx) * 1.15, 1.95, float(sz) * 0.62), 0.07,
				GiltPalette.WOOD_DARK)
	# Тент: два ската с полосами — «ярмарка» в двух цветах, без картинок.
	# Скаты — это и есть полосы: каждый со своим цветом, поэтому второго
	# слоя полотна под ними не нужно (было бы z-fighting).
	var top_y := 2.05
	for sz in [-1.0, 1.0]:
		var a := at + bx * Vector3(-1.35, top_y, 0.0)
		var b := at + bx * Vector3(1.35, top_y, 0.0)
		var c := at + bx * Vector3(1.35, top_y - 0.42, float(sz) * 1.15)
		var d := at + bx * Vector3(-1.35, top_y - 0.42, float(sz) * 1.15)
		var inside := at + Vector3(0.0, 1.4, 0.0)
		GiltShapes.out_quad(_wood, a, b, c, d,
			GiltPalette.CLOTH if sz > 0.0 else GiltPalette.CLOTH_DYED, inside)
	# Полосы: чередование ткани идёт отдельными узкими досками по скату.
	for i in range(7):
		var t := (float(i) + 0.5) / 7.0
		var x := lerpf(-1.35, 1.35, t)
		for sz in [-1.0, 1.0]:
			GiltShapes.beam(_wood, at + bx * Vector3(x, top_y + 0.02, 0.0),
				at + bx * Vector3(x, top_y - 0.40, float(sz) * 1.12), 0.10,
				GiltPalette.CLOTH_DYED if i % 2 == 0 else GiltPalette.CLOTH)
	# Товар: корзины и бочонки на прилавке.
	for i in range(3):
		barrel(at + bx * Vector3(-0.8 + float(i) * 0.8, 0.48, 0.1), 0.34, 0.18)


## Колокол у причала: каменная арка, бронза, верёвка. Звук — в GiltLife.
func mooring_bell(at: Vector3) -> void:
	for sx in [-1.0, 1.0]:
		GiltShapes.box(_stone, at + Vector3(float(sx) * 1.10, 0.95, 0.0),
			Vector3(0.30, 1.90, 0.30), Color("262b38"))
		GiltShapes.box(_stone, at + Vector3(float(sx) * 1.10, 0.10, 0.0),
			Vector3(0.46, 0.20, 0.46), GiltPalette.STONE_COLD * 0.54)
	GiltShapes.beam(_stone, at + Vector3(-1.10, 1.90, 0.0), at + Vector3(1.10, 1.90, 0.0),
		0.22, Color("2b3040"))
	# Кронштейн с колесом и колоколом.
	GiltShapes.beam(_dark, at + Vector3(0.0, 1.90, 0.0), at + Vector3(0.0, 2.35, 0.0),
		0.07, GiltPalette.IRON)
	GiltShapes.beam(_dark, at + Vector3(-0.32, 2.35, 0.0), at + Vector3(0.32, 2.35, 0.0),
		0.06, GiltPalette.IRON)
	GiltShapes.cylinder(_gilt, at + Vector3(0.0, 2.10, 0.0), 0.34, 0.16, 0.42,
		GiltPalette.GILT * 0.92, 10)
	GiltShapes.box(_gilt, at + Vector3(0.0, 1.86, 0.0), Vector3(0.06, 0.18, 0.06),
		GiltPalette.GILT_HOT)
	GiltShapes.cylinder(_wood, at + Vector3(0.28, 1.90, 0.0), 0.025, 0.025, 0.90,
		GiltPalette.ROPE, 5)


## Сушильня для сетей: две стойки, перекладина, тёмная сеть полотном.
func drying_rack(at: Vector3, yaw := 0.0) -> void:
	var bx := Basis(Vector3.UP, yaw)
	for sx in [-1.0, 1.0]:
		GiltShapes.beam(_wood, at + bx * Vector3(float(sx) * 1.3, 0.0, 0.0),
			at + bx * Vector3(float(sx) * 1.3, 2.05, 0.0), 0.09, GiltPalette.WOOD_DARK)
		GiltShapes.beam(_wood, at + bx * Vector3(float(sx) * 1.3, 0.0, -0.45),
			at + bx * Vector3(float(sx) * 1.3, 1.10, 0.0), 0.05, GiltPalette.WOOD_DARK)
	GiltShapes.beam(_wood, at + bx * Vector3(-1.45, 2.03, 0.0),
		at + bx * Vector3(1.45, 2.03, 0.0), 0.08, GiltPalette.ROPE)
	# Сеть — не плоскость, а «провисшее» полотно из полос: видно, что мокрое.
	for i in range(14):
		var t := (float(i) + 0.5) / 14.0
		var x := lerpf(-1.25, 1.25, t)
		var sag := sin(t * PI) * 0.30
		GiltShapes.beam(_dark, at + bx * Vector3(x, 2.00, 0.0),
			at + bx * Vector3(x, 1.05 - sag, 0.05), 0.022, Color("3b4a3a"))


## Полосатая будка/склад у причала: контейнер в стиле посёлка. Стоит у
## съезда с пирса, поэтому «читается» с четырёх сторон: полосы и ланцет
## повторены на обеих длинных стенах, а торцы получили дверь и погрузочный
## помост — иначе с воды видна просто серая коробка.
func store_hut(at: Vector3, yaw := 0.0) -> void:
	var bx := Basis(Vector3.UP, yaw)
	GiltShapes.box(_stone, at + bx * Vector3(0.0, 1.15, 0.0), Vector3(2.6, 2.3, 2.0),
		Color("232838"), bx)
	# Цоколь и верхний пояс: две линии, по которым коробка читается объёмом.
	GiltShapes.box(_stone, at + bx * Vector3(0.0, 0.12, 0.0), Vector3(2.76, 0.24, 2.16),
		Color("1b1f2b"), bx)
	GiltShapes.box(_gilt, at + bx * Vector3(0.0, 2.22, 0.0), Vector3(2.72, 0.10, 2.12),
		GiltPalette.GILT * 0.55, bx)
	# Полосы эмали на обеих длинных стенах — «портовая» метка с любого борта.
	# Полосы разведены к рёбрам, окно — по центру: иначе ланцет прилипает
	# к углу и стена читается как «окно наугад».
	for face in [1.0, -1.0]:
		var depth := 1.01 * float(face)
		for i in range(2):
			GiltShapes.box(_gilt, at + bx * Vector3(-0.86 + float(i) * 1.72, 1.15, depth),
				Vector3(0.40, 2.10, 0.06), palette_stripe(i), bx)
	# Ланцет — на обеих длинных стенах: ночью будка светится на оба борта.
	# Стекло красим по ТЕКУЩЕМУ вечеру (_night), а не «ночь навсегда»:
	# днём это свинцовое стекло, ночью огонь даёт эмиссия общей сетки
	# PropsGlass — так же, как у домов и у фонарей.
	for face in [1.0, -1.0]:
		var face_bx := bx * (Basis.IDENTITY if face > 0.0 else Basis(Vector3.UP, PI))
		GiltShapes.lancet(_glass, _gilt,
			at + bx * Vector3(0.0, 0.66, 1.02 * float(face)),
			0.44, 1.06, GiltPalette.LAMP_NEON, GiltPalette.LEAD, _night, 0.05,
			face_bx)
	# Дверь с торца (+X): склад, куда что-то заносят. К ней — помост.
	var side_bx := bx * Basis(Vector3.UP, PI * 0.5)
	GiltShapes.extrude_z(_wood, GiltShapes.pointed_arch(0.52, 0.0, 0.70, 5),
		1.28, 1.37, GiltPalette.WOOD_DARK, at, side_bx)
	for i in range(3):
		GiltShapes.beam(_dark, at + side_bx * Vector3(-0.26, 0.30 + float(i) * 0.30, 1.33),
			at + side_bx * Vector3(0.26, 0.30 + float(i) * 0.30, 1.33), 0.022,
			GiltPalette.IRON)
	# Помост у двери: доски вплотную к стене (стена на 1.3 по X) и опора —
	# иначе от стены до настила остаётся щель, и помост «висит».
	GiltShapes.box(_wood, at + side_bx * Vector3(0.0, 0.12, 1.72), Vector3(1.30, 0.16, 0.84),
		GiltPalette.WOOD_WARM)
	GiltShapes.box(_stone, at + side_bx * Vector3(0.0, 0.02, 1.72), Vector3(1.10, 0.14, 0.66),
		Color("1d212c"))
	GiltShapes.pent_roof(_wood, at + bx * Vector3(0.0, 2.30, 0.10), 3.0, 2.4,
		0.22, 0.34, GiltPalette.SLATE, GiltPalette.LEAD)


func palette_stripe(index: int) -> Color:
	return GiltPalette.GILT * 0.85 if index == 0 else GiltPalette.LAMP_MAGENTA * 0.85


## Арка на въезде/площади — «сцена» посёлка, где сходятся все дорожки.
func arch(at: Vector3, half_width: float, yaw := 0.0) -> void:
	var bx := Basis(Vector3.UP, yaw)
	for sx in [-1.0, 1.0]:
		var base: Vector3 = at + bx * Vector3(float(sx) * half_width, 0.0, 0.0)
		GiltShapes.cylinder(_stone, base + Vector3(0.0, 1.70, 0.0), 0.24, 0.19, 3.40,
			Color("242936"), 8)
		GiltShapes.box(_stone, base + Vector3(0.0, 0.12, 0.0), Vector3(0.52, 0.24, 0.52),
			GiltPalette.STONE_COLD * 0.5)
	# Стрельчатая арка из сегментов между столбами.
	var span := half_width * 2.0
	var arch_profile := GiltShapes.pointed_arch(span, 3.30, 3.75, 8)
	GiltShapes.extrude_z(_stone, arch_profile, -0.16, 0.16, Color("2a2f3e"), at, bx)
	GiltShapes.spire(_gilt, at + bx * Vector3(0.0, 4.55, 0.0), 0.18, 0.72,
		GiltPalette.GILT, 4, PI * 0.25)


# --- Вечер ----------------------------------------------------------------

## Свет фонарей и неоновая вода: включаются вместе с окнами посёлка.
func set_night(amount: float) -> void:
	var night := clampf(amount, 0.0, 1.0)
	for entry in _lights:
		var light: OmniLight3D = entry["light"]
		var base_energy: float = entry["energy"]
		light.light_energy = maxf(0.0, night - float(entry["onset"])) * base_energy * 1.6
	if _water != null:
		var mat := _water.material_override as ShaderMaterial
		if mat != null:
			mat.set_shader_parameter("night01", night)
	if _orb != null:
		var mat := _orb.material_override as StandardMaterial3D
		if mat != null:
			mat.emission_energy_multiplier = maxf(0.0, night - 0.12) * 3.4
	# Мигающая «дыхание» ночного неона — раз в несколько секунд, едва.
	_night = night


var _night := 0.0


func _light_at(at: Vector3, color: Color, energy: float, light_range: float,
		onset := 0.30) -> void:
	var light := OmniLight3D.new()
	light.light_color = color
	light.omni_range = light_range
	light.light_energy = 0.0
	light.shadow_enabled = false
	light.light_volumetric_fog_energy = 0.7
	light.position = at
	light.name = "GiltLamp%d" % _lights.size()
	host.add_child(light)
	_lights.append({"light": light, "energy": energy, "onset": onset})


