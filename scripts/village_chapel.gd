class_name GiltChapel
extends Node3D
## Часовня посёлка — вертикальная доминанта «Золочёного прилива».
##
## Дома дают улицу; часовня даёт СИЛУЭТ, по которому посёлок узнаётся с
## воды: стрельчатый западный фасад с розой, звонница на гребне, шпиль с
## золочёным крестом, контрфорсы с фиалами и витражи, которые ночью горят
## розовым и бирюзовым.
##
## Локальные координаты: +X — вход (западный фасад), +Y — вверх, начало —
## центр пола. Узел ставится поворотом PI: фасад смотрит на площадь (−X
## мира). Поэтому вся геометрия живёт в локальных +X и не знает про мир.

const LENGTH := 7.2
const WIDTH := 4.8
const WALL_H := 3.30
const RIDGE := 5.10

var night01 := 0.0
var window_material: StandardMaterial3D

var _stone: SurfaceTool
var _roof: SurfaceTool
var _gilt: SurfaceTool
var _glass: SurfaceTool
var _glow: Array[MeshInstance3D] = []
var _lights: Array[OmniLight3D] = []


func build() -> void:
	_stone = GiltShapes.begin()
	_roof = GiltShapes.begin()
	_gilt = GiltShapes.begin()
	_glass = GiltShapes.begin()
	_plinth()
	_nave()
	_apse()
	_buttresses()
	_west_facade()
	_bellcote()
	_commit()


func _plinth() -> void:
	# Ступенчатый цоколь: часовня стоит на скале, а не на газоне.
	for i in range(3):
		GiltShapes.box(_stone, Vector3(0.0, -0.10 - float(i) * 0.18, 0.0),
			Vector3(LENGTH + 1.5 - float(i) * 0.36, 0.20, WIDTH + 1.5 - float(i) * 0.36),
			Color("2a2c38").darkened(0.06 * float(i)))
	GiltShapes.box(_stone, Vector3(0.0, 0.06, 0.0),
		Vector3(LENGTH + 0.7, 0.16, WIDTH + 0.7), GiltPalette.STONE_COLD * 0.50)


func _nave() -> void:
	# Стены + вертикальные лопатки: длинный фасад читается как неф, а не сарай.
	GiltShapes.box(_stone, Vector3(0.0, WALL_H * 0.5, 0.0),
		Vector3(LENGTH, WALL_H, WIDTH), Color("1b1f2b"))
	for i in range(5):
		var x := lerpf(-LENGTH * 0.5 + 0.4, LENGTH * 0.5 - 0.4, float(i) / 4.0)
		for sz in [-1.0, 1.0]:
			GiltShapes.box(_stone, Vector3(x, WALL_H * 0.5, float(sz) * (WIDTH * 0.5 + 0.06)),
				Vector3(0.34, WALL_H, 0.16), GiltPalette.STONE_COLD * 0.44)
	# Крыша: крутой скат, шифер, гребень и крабы по коньку.
	var ridge_h := GiltShapes.gable_roof(_roof, Vector3.ZERO, LENGTH, WIDTH,
		WALL_H, RIDGE - WALL_H, GiltPalette.SLATE, GiltPalette.LEAD,
		Color("242433"), 0.42)
	GiltShapes.crest(_gilt, Vector3(-LENGTH * 0.5 + 1.0, ridge_h + 0.08, 0.0),
		Vector3(LENGTH * 0.5 - 1.0, ridge_h + 0.08, 0.0), 7, 0.20, GiltPalette.GILT * 0.7)
	# Витражи по длинным сторонам: по три на сторону, розовые и бирюзовые.
	for sz in [-1.0, 1.0]:
		for i in range(3):
			var x := (float(i) - 1.0) * 2.05
			var tint: Color = GiltPalette.LAMP_MAGENTA if i % 2 == 0 else GiltPalette.LAMP_NEON
			GiltShapes.lancet(_glass, _gilt, Vector3(x, 1.05, float(sz) * (WIDTH * 0.5 + 0.01)),
				0.62, 1.62, tint, GiltPalette.LEAD, night01, 0.08,
				GiltShapes.facing(Vector3(0.0, 0.0, float(sz))))
	# Карниз из золотой нити по свесу — общий мотив с домами.
	for sz in [-1.0, 1.0]:
		GiltShapes.beam(_gilt, Vector3(-LENGTH * 0.5 - 0.30, WALL_H - 0.02,
			float(sz) * (WIDTH * 0.5 + 0.30)),
			Vector3(LENGTH * 0.5 + 0.30, WALL_H - 0.02, float(sz) * (WIDTH * 0.5 + 0.30)),
			0.05, GiltPalette.GILT * 0.8)


func _apse() -> void:
	# Полукруглая апсида на востоке: каменный барабан и коническая кровля.
	var cx := -LENGTH * 0.5
	GiltShapes.cylinder(_stone, Vector3(cx, WALL_H * 0.5, 0.0), WIDTH * 0.46,
		WIDTH * 0.46, WALL_H, Color("1b1f2b"), 14)
	GiltShapes.cylinder(_stone, Vector3(cx, WALL_H + 0.06, 0.0), WIDTH * 0.50,
		WIDTH * 0.50, 0.16, GiltPalette.STONE_COLD * 0.52, 14)
	GiltShapes.spire(_roof, Vector3(cx, WALL_H + 0.12, 0.0), WIDTH * 0.50, 1.85,
		GiltPalette.SLATE, 12, 0.0)
	# Фиал апсиды: золотая точка на восточном краю — читается с моря.
	GiltShapes.spire(_gilt, Vector3(cx, WALL_H + 1.92, 0.0), 0.11, 0.52,
		GiltPalette.GILT, 4, PI * 0.25)
	# Узкие ланцеты в апсиде: три, по кругу.
	for i in range(3):
		var ang := PI + float(i) * TAU / 3.0 - 0.6
		var dir := Vector3(cos(ang), 0.0, sin(ang))
		GiltShapes.lancet(_glass, _gilt, Vector3(cx, 1.15, 0.0) + dir * (WIDTH * 0.44),
			0.34, 1.30, GiltPalette.LAMP_VIOLET, GiltPalette.LEAD, night01, 0.06,
			GiltShapes.facing(dir))


func _buttresses() -> void:
	# Контрфорсы с фиалами — то, что делает силуэт готическим.
	for sz in [-1.0, 1.0]:
		for i in range(2):
			var x := lerpf(-1.9, 1.9, float(i))
			var z: float = float(sz) * (WIDTH * 0.5 + 0.10)
			for k in range(3):
				var y := 0.45 + float(k) * 0.86
				var w := 0.56 - float(k) * 0.14
				GiltShapes.box(_stone, Vector3(x, y, z + 0.10),
					Vector3(w, 0.84, 0.40), Color("20242f"))
			GiltShapes.spire(_gilt, Vector3(x, 2.30, z + 0.14), 0.17, 0.78,
				GiltPalette.STONE_COLD * 0.7, 4, PI * 0.25)
			GiltShapes.spire(_gilt, Vector3(x, 3.02, z + 0.14), 0.09, 0.36,
				GiltPalette.GILT, 4, PI * 0.25)
	# Аркбутан: наклонная связь от контрфорса к стене — узнаваемый элемент.
	for sz in [-1.0, 1.0]:
		var z: float = float(sz) * (WIDTH * 0.5 + 0.18)
		GiltShapes.beam(_stone, Vector3(-1.9, 2.55, z), Vector3(-1.0, 2.98, float(sz) * (WIDTH * 0.5)),
			0.14, GiltPalette.STONE_COLD * 0.5)
		GiltShapes.beam(_stone, Vector3(1.9, 2.55, z), Vector3(1.0, 2.98, float(sz) * (WIDTH * 0.5)),
			0.14, GiltPalette.STONE_COLD * 0.5)


func _west_facade() -> void:
	# Западный фасад: роза над стрельчатым порталом, фиалы по краям.
	var face_x := LENGTH * 0.5
	var facade_basis := GiltShapes.facing(Vector3.RIGHT)
	# Портальная арка в три обвода: глубина, а не наклейка.
	for i in range(3):
		var w := 2.05 - float(i) * 0.30
		var arch := GiltShapes.pointed_arch(w, -0.10, 1.45 - float(i) * 0.10, 7)
		GiltShapes.extrude_z(_stone, arch, -0.02 - float(i) * 0.09, 0.10,
			Color("2c3040").lightened(0.04 * float(i)),
			Vector3(face_x, 0.0, 0.0), facade_basis)
	# Дверь: тёмное дерево, золотые петли, кольцо.
	var door := GiltShapes.pointed_arch(1.05, 0.0, 1.34, 6)
	GiltShapes.extrude_z(_stone, door, 0.02, 0.12, GiltPalette.WOOD_DARK,
		Vector3(face_x, 0.0, 0.0), facade_basis)
	for i in range(4):
		var y := 0.42 + float(i) * 0.40
		GiltShapes.beam(_gilt, Vector3(face_x + 0.13, y, -0.50),
			Vector3(face_x + 0.13, y, 0.14), 0.03, GiltPalette.GILT * 0.78)
	GiltShapes.ring(_gilt, Vector3(face_x + 0.14, 1.02, 0.0), 0.085, 0.05, 0.03,
		GiltPalette.GILT, 10, Vector3.RIGHT)
	# Роза над порталом: главный витраж посёлка.
	var rose_at := Vector3(face_x + 0.06, 3.55, 0.0)
	GiltShapes.ring(_glass, rose_at, 0.90, 0.70, 0.06, GiltPalette.LAMP_MAGENTA, 20,
		Vector3.RIGHT)
	GiltShapes.ring(_stone, rose_at + Vector3(0.05, 0.0, 0.0), 1.14, 0.90, 0.20,
		GiltPalette.STONE_COLD * 0.62, 20, Vector3.RIGHT)
	for i in range(12):
		var ang := TAU * float(i) / 12.0
		GiltShapes.beam(_stone, rose_at + Vector3(0.10, sin(ang) * 0.12, cos(ang) * 0.12),
			rose_at + Vector3(0.10, sin(ang) * 0.88, cos(ang) * 0.88), 0.04,
			GiltPalette.LEAD)
	GiltShapes.cylinder(_gilt, rose_at + Vector3(0.10, 0.0, 0.0), 0.12, 0.12, 0.06,
		GiltPalette.GILT, 10, Basis(Vector3.BACK, PI * 0.5))
	# Фиалы по краям фасада: пара вертикалей, держащих композицию.
	for sz in [-1.0, 1.0]:
		var z: float = float(sz) * (WIDTH * 0.5 + 0.06)
		GiltShapes.box(_stone, Vector3(face_x - 0.15, 1.65, z), Vector3(0.42, 3.30, 0.42),
			Color("20242f"))
		GiltShapes.spire(_gilt, Vector3(face_x - 0.15, 3.30, z), 0.24, 0.92,
			GiltPalette.STONE_COLD * 0.66, 4, PI * 0.25)
		GiltShapes.spire(_gilt, Vector3(face_x - 0.15, 4.22, z), 0.12, 0.46,
			GiltPalette.GILT, 4, PI * 0.25)
	# Ступени к порталу и золотой крест над розой.
	for i in range(3):
		GiltShapes.box(_stone, Vector3(face_x + 0.34 + float(i) * 0.26, 0.05 + float(i) * 0.09, 0.0),
			Vector3(0.30, 0.16, 2.5 - float(i) * 0.20), GiltPalette.STONE_COLD * 0.48)
	_cross(Vector3(face_x + 0.02, RIDGE + 0.10, 0.0), 0.95, 0.10)


func _cross(at: Vector3, height: float, thick: float) -> void:
	GiltShapes.box(_gilt, at + Vector3(0.0, height * 0.5, 0.0),
		Vector3(thick, height, thick), GiltPalette.GILT)
	GiltShapes.box(_gilt, at + Vector3(0.0, height * 0.70, 0.0),
		Vector3(thick, thick, height * 0.52), GiltPalette.GILT)
	GiltShapes.spire(_gilt, at + Vector3(0.0, height, 0.0), thick * 0.9, thick * 2.4,
		GiltPalette.GILT_HOT, 4, PI * 0.25)


func _bellcote() -> void:
	# Звонница на гребне у фасада: столбы, арка, колокол, шпиль.
	var x := LENGTH * 0.5 - 0.95
	var base_y := RIDGE + 0.05
	for sz in [-1.0, 1.0]:
		GiltShapes.box(_stone, Vector3(x, base_y + 0.62, float(sz) * 0.62),
			Vector3(0.30, 1.24, 0.30), GiltPalette.STONE_COLD * 0.60)
		GiltShapes.box(_stone, Vector3(x, base_y + 1.24, float(sz) * 0.62),
			Vector3(0.42, 0.14, 0.42), GiltPalette.STONE_COLD * 0.68)
		GiltShapes.spire(_gilt, Vector3(x, base_y + 1.31, float(sz) * 0.62), 0.16, 0.62,
			GiltPalette.STONE_COLD * 0.66, 4, PI * 0.25)
	var arch := GiltShapes.pointed_arch(1.10, base_y + 0.30, base_y + 0.86, 6)
	GiltShapes.extrude_z(_stone, arch, -0.07, 0.07, Color("262a38"),
		Vector3(x, 0.0, 0.0), GiltShapes.facing(Vector3.RIGHT))
	GiltShapes.cylinder(_gilt, Vector3(x, base_y + 0.52, 0.0), 0.30, 0.16, 0.34,
		GiltPalette.GILT * 0.92, 10)
	GiltShapes.box(_gilt, Vector3(x, base_y + 0.32, 0.0), Vector3(0.05, 0.16, 0.05),
		GiltPalette.GILT_HOT)
	_cross(Vector3(x, base_y + 1.36, 0.0), 0.62, 0.075)


## Вечер: витражи и звонница зажигаются, у портала появляется тёплый свет.
func set_night(amount: float) -> void:
	night01 = clampf(amount, 0.0, 1.0)
	var glow := maxf(0.0, night01 - 0.15) * 2.0
	if window_material != null:
		window_material.emission_energy_multiplier = glow
	for node in _glow:
		var mat := node.material_override as StandardMaterial3D
		if mat != null and mat.emission_enabled:
			mat.emission_energy_multiplier = maxf(0.0, night01 - 0.20) * 2.6
	for light in _lights:
		light.light_energy = maxf(0.0, night01 - 0.26) * 1.15


func _commit() -> void:
	# Кронштейн и раму нужно добавить до запекания материала.
	_lantern(Vector3(LENGTH * 0.5 + 0.55, 2.35, 0.0))
	_bake("Stone", _stone, _solid_material(0.88, 0.0))
	_bake("Roof", _roof, _solid_material(0.95, 0.12))
	_bake("Gilt", _gilt, _solid_material(0.28, 0.72))
	window_material = _glass_material()
	_bake("Glass", _glass, window_material)
	# Два витражных «дышащих» пятна: роза на фасаде и апсида.
	# Плоскость витража повёрнута вместе с поворотом узла: роза смотрит на
	# площадь, апсидный витраж — на море.
	_glow_plate(Vector3(LENGTH * 0.5 + 0.16, 3.55, 0.0), Vector2(1.45, 1.45),
		GiltPalette.LAMP_MAGENTA)
	_glow_plate(Vector3(-LENGTH * 0.5 - WIDTH * 0.40, 1.55, 0.0), Vector2(0.9, 1.1),
		GiltPalette.LAMP_VIOLET)
	set_night(night01)


func _lantern(at: Vector3) -> void:
	# Стальной кронштейн связывает светильник с фасадом часовни.
	GiltShapes.beam(_gilt, Vector3(LENGTH * 0.5 + 0.04, at.y + 0.24, at.z),
		at + Vector3(0.0, 0.24, 0.0), 0.06, GiltPalette.GILT * 0.75)
	GiltShapes.beam(_gilt, at + Vector3(0.0, 0.24, 0.0),
		at + Vector3(0.0, 0.13, 0.0), 0.06, GiltPalette.GILT * 0.75)
	GiltShapes.box(_gilt, at, Vector3(0.22, 0.28, 0.22), GiltPalette.GILT * 0.85)
	var post := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.16, 0.20, 0.16)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = GiltPalette.LAMP_WARM
	mat.emission_enabled = true
	mat.emission = GiltPalette.LAMP_WARM
	mat.emission_energy_multiplier = 0.0
	post.mesh = box
	post.material_override = mat
	post.position = at
	add_child(post)
	_glow.append(post)
	for offset in [Vector3(0.8, 0.4, 1.4), Vector3(0.8, 0.4, -1.4)]:
		var light := OmniLight3D.new()
		light.light_color = GiltPalette.LAMP_WARM
		light.omni_range = 7.5
		light.light_energy = 0.0
		light.shadow_enabled = false
		light.position = at + offset
		light.light_volumetric_fog_energy = 0.6
		add_child(light)
		_lights.append(light)
	# Второй источник — цветной, от розы: холодный неон на камне.
	var rose_light := OmniLight3D.new()
	rose_light.light_color = GiltPalette.LAMP_MAGENTA
	rose_light.omni_range = 6.0
	rose_light.light_energy = 0.0
	rose_light.shadow_enabled = false
	rose_light.position = at + Vector3(-0.2, 1.2, 0.0)
	rose_light.light_volumetric_fog_energy = 0.5
	add_child(rose_light)
	_lights.append(rose_light)


func _glow_plate(at: Vector3, extent: Vector2, tint: Color) -> void:
	var node := MeshInstance3D.new()
	var quad := BoxMesh.new()
	quad.size = Vector3(extent.x, extent.y, 0.03)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = tint
	mat.emission_enabled = true
	mat.emission = tint
	mat.emission_energy_multiplier = 0.0
	node.mesh = quad
	node.material_override = mat
	node.position = at
	node.rotation.y = PI * 0.5
	add_child(node)
	_glow.append(node)


func _solid_material(roughness: float, metallic: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color.WHITE
	mat.vertex_color_use_as_albedo = true
	mat.roughness = roughness
	mat.metallic = metallic
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat


func _glass_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color.WHITE
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.16
	mat.metallic = 0.30
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.emission_enabled = true
	mat.emission = GiltPalette.LAMP_MAGENTA
	mat.emission_energy_multiplier = 0.0
	return mat


func _bake(node_name: String, surface: SurfaceTool, material: Material) -> void:
	var mesh := surface.commit()
	if mesh == null or mesh.get_surface_count() == 0:
		return
	var visual := MeshInstance3D.new()
	visual.name = node_name
	visual.mesh = mesh
	visual.material_override = material
	add_child(visual)
