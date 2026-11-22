class_name GiltShrine
extends Node3D
## Прибрежный храм-фонарь: последняя точка посёлка перед водой.
##
## Появляется там, где набережная выходит к бухте: узкая каменная часовня
## на скале, стрельчатые проёмы, золочёный фонарь в нише и лестница из
## воды. Это «открытка» посёлка — её видно с лодки при заходе в бухту,
## а ночью она горит бирюзой и служит ориентиром.
##
## Стиль тот же, что у домов: готический камень + vaporwave-свет, поэтому
## храм не выглядит чужой постройкой, а завершает силуэт посёлка.

const HEIGHT := 3.6

var night01 := 0.0
var _glow: Array[MeshInstance3D] = []
var _lights: Array[OmniLight3D] = []
var _cold: Array[bool] = []


func build() -> void:
	var stone := GiltShapes.begin()
	var gilt := GiltShapes.begin()
	var glass := GiltShapes.begin()
	var roof := GiltShapes.begin()
	# Основание-скала: три ряда камня, как у часовни, но меньше.
	for i in range(3):
		GiltShapes.box(stone, Vector3(0.0, -0.12 - float(i) * 0.15, 0.0),
			Vector3(3.2 - float(i) * 0.34, 0.18, 2.6 - float(i) * 0.28),
			Color("242833").darkened(0.05 * float(i)))
	# Тело: узкий объём, лопатки по углам, карниз.
	var body_h := 2.55
	GiltShapes.box(stone, Vector3(0.0, body_h * 0.5, 0.0), Vector3(2.35, body_h, 1.72),
		Color("1d2130"))
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			GiltShapes.box(stone, Vector3(float(sx) * 1.12, body_h * 0.5, float(sz) * 0.80),
				Vector3(0.24, body_h, 0.24), GiltPalette.STONE_COLD * 0.48)
	# Крыша: шатёр с золотым крестом и крабами.
	GiltShapes.hip_roof(roof, Vector3(0.0, body_h, 0.0), 2.35, 1.72, 0.0, 1.10,
		GiltPalette.SLATE, GiltPalette.LEAD, 0.26)
	GiltShapes.crest(gilt, Vector3(-1.05, body_h + 0.34, 0.0), Vector3(1.05, body_h + 0.34, 0.0),
		3, 0.14, GiltPalette.GILT * 0.7)
	# Фонарь на вершине: главный ночной акцент берега.
	GiltShapes.cylinder(gilt, Vector3(0.0, body_h + 1.26, 0.0), 0.16, 0.05, 0.72,
		GiltPalette.GILT, 6)
	GiltShapes.box(gilt, Vector3(0.0, body_h + 1.72, 0.0), Vector3(0.06, 0.30, 0.06),
		GiltPalette.GILT_HOT)
	# Ниша с ланцетом и роза на «лице», обращённом к воде (−X).
	var face := Vector3(-1.19, 0.0, 0.0)
	GiltShapes.lancet(glass, gilt, face + Vector3(0.0, 0.75, 0.0), 0.62, 1.42,
		GiltPalette.LAMP_NEON, GiltPalette.LEAD, night01, 0.06,
		GiltShapes.facing(Vector3.LEFT))
	GiltShapes.ring(glass, face + Vector3(0.02, 2.18, 0.0), 0.34, 0.26, 0.04,
		GiltPalette.LAMP_MAGENTA, 14, Vector3.LEFT)
	GiltShapes.ring(stone, face + Vector3(0.05, 2.18, 0.0), 0.44, 0.34, 0.10,
		GiltPalette.STONE_COLD * 0.62, 14, Vector3.LEFT)
	GiltShapes.lancet(glass, gilt, Vector3(1.19, 0.75, 0.0), 0.50, 1.20,
		GiltPalette.LAMP_VIOLET, GiltPalette.LEAD, night01, 0.06,
		GiltShapes.facing(Vector3.RIGHT))
	# Дверь со стороны набережной (+Z): к ней ведут ступени.
	GiltShapes.extrude_z(stone, GiltShapes.pointed_arch(0.72, 0.0, 0.96, 6), 0.80, 0.94,
		GiltPalette.WOOD_DARK)
	for i in range(3):
		GiltShapes.beam(gilt, Vector3(-0.34, 0.46 + float(i) * 0.38, 0.96),
			Vector3(0.10, 0.46 + float(i) * 0.38, 0.96), 0.026, GiltPalette.GILT * 0.8)
	_commit(stone, roof, gilt, glass)
	# Фонарь в нише и вход: тёплый и холодный свет на камне.
	_lamp(Vector3(0.0, 2.05, 0.0), GiltPalette.LAMP_NEON, 4.0, 2, true)
	_lamp(Vector3(0.0, 1.10, 1.10), GiltPalette.LAMP_WARM, 3.4, 1, false)
	set_night(night01)


func _lamp(at: Vector3, tint: Color, light_range: float, count: int, cold: bool) -> void:
	for i in range(count):
		var light := OmniLight3D.new()
		light.light_color = tint
		light.omni_range = light_range
		light.light_energy = 0.0
		light.shadow_enabled = false
		light.light_volumetric_fog_energy = 0.8
		light.position = at + Vector3(0.0, 0.0, float(i) * 0.3)
		add_child(light)
		_lights.append(light)
		_cold.append(cold)


func _commit(stone: SurfaceTool, roof: SurfaceTool, gilt: SurfaceTool,
		glass: SurfaceTool) -> void:
	for entry in [["ShrineStone", stone, _solid(0.88, 0.02)],
			["ShrineRoof", roof, _solid(0.95, 0.1)],
			["ShrineGilt", gilt, _solid(0.28, 0.72)],
			["ShrineGlass", glass, _glass()]]:
		var mesh: ArrayMesh = (entry[1] as SurfaceTool).commit()
		if mesh == null or mesh.get_surface_count() == 0:
			continue
		var node := MeshInstance3D.new()
		node.name = entry[0]
		node.mesh = mesh
		node.material_override = entry[2]
		add_child(node)
		if entry[0] == "ShrineGlass":
			_glow.append(node)


func _solid(roughness: float, metallic: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color.WHITE
	mat.vertex_color_use_as_albedo = true
	mat.roughness = roughness
	mat.metallic = metallic
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat


func _glass() -> StandardMaterial3D:
	var mat := _solid(0.15, 0.3)
	mat.emission_enabled = true
	mat.emission = GiltPalette.LAMP_NEON
	mat.emission_energy_multiplier = 0.0
	return mat


func set_night(amount: float) -> void:
	night01 = clampf(amount, 0.0, 1.0)
	for node in _glow:
		var mat := node.material_override as StandardMaterial3D
		if mat != null and mat.emission_enabled:
			mat.emission_energy_multiplier = maxf(0.0, night01 - 0.16) * 2.4
	for i in range(_lights.size()):
		# Холодная ниша разгорается раньше тёплого входа: вечер начинается с неё.
		var is_cold := _cold[i]
		var onset := 0.20 if is_cold else 0.32
		_lights[i].light_energy = maxf(0.0, night01 - onset) * (0.9 if is_cold else 0.7)
