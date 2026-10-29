class_name ObservationTower
extends Node3D
## Каркас и площадка M1. Начало координат — основание на песке.
## Игрок перемещается по прямоугольнику внутри перил (см. TowerPlayer).

const DECK_HEIGHT := 52.0
const HALF_DECK := 6.0
const WALK_LIMIT := 5.35

var _steel: StandardMaterial3D
var _dark: StandardMaterial3D
var _rust: StandardMaterial3D
var _paint: StandardMaterial3D
var _screen: StandardMaterial3D


func _ready() -> void:
	_steel = _material(Color(0.24, 0.22, 0.19), 0.55, 0.82)
	_dark = _material(Color(0.095, 0.10, 0.095), 0.45, 0.91)
	_rust = _material(Color(0.35, 0.19, 0.105), 0.35, 0.94)
	_paint = _material(Color(0.61, 0.47, 0.27), 0.25, 0.84)
	_screen = _material(Color(0.30, 0.34, 0.21), 0.15, 0.65)
	_build_tower()


func _material(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = metallic
	mat.roughness = roughness
	return mat


func _box(part_name: String, at: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = part_name
	var box := BoxMesh.new()
	box.size = size
	node.mesh = box
	node.material_override = mat
	node.position = at
	add_child(node)
	return node


## Прямоугольная балка соединяет две точки без отдельной модели.
func _beam(part_name: String, a: Vector3, b: Vector3, thickness: float, mat: Material) -> void:
	var axis := b - a
	var beam := _box(part_name, (a + b) * 0.5, Vector3(thickness, axis.length(), thickness), mat)
	beam.quaternion = Quaternion(Vector3.UP, axis.normalized())


func _build_tower() -> void:
	# Настил: ряд секций оставляет тонкие швы и читается под ногами.
	_box("DeckStructure", Vector3(0, DECK_HEIGHT - 0.32, 0), Vector3(12.3, 0.6, 12.3), _dark)
	for i in range(12):
		_box("DeckPanel", Vector3(0, DECK_HEIGHT - 0.025, -5.5 + float(i)), Vector3(11.85, 0.05, 0.96), _steel)
	# Краевые балки и нижний ферменный пояс.
	for side in [-1.0, 1.0]:
		_box("DeckRim", Vector3(side * 6.0, DECK_HEIGHT - 0.22, 0), Vector3(0.25, 0.5, 12.3), _rust)
		_box("DeckRim", Vector3(0, DECK_HEIGHT - 0.22, side * 6.0), Vector3(12.3, 0.5, 0.25), _rust)
	# Четыре опоры и раскосы: башня настоящая, а не плавающая платформа.
	for x in [-4.8, 4.8]:
		for z in [-4.8, 4.8]:
			_box("Support", Vector3(x, DECK_HEIGHT * 0.5 - 0.2, z), Vector3(0.65, DECK_HEIGHT, 0.65), _dark)
			_box("Footing", Vector3(x, 0.1, z), Vector3(2.0, 0.45, 2.0), _rust)
	for h in [10.0, 23.0, 36.0]:
		for side in [-4.8, 4.8]:
			_beam("CrossBrace", Vector3(-4.8, h, side), Vector3(4.8, h + 11.0, side), 0.24, _rust)
			_beam("CrossBrace", Vector3(side, h, -4.8), Vector3(side, h + 11.0, 4.8), 0.24, _rust)
			_box("SupportRing", Vector3(side, h, 0), Vector3(0.30, 0.30, 9.6), _steel)
			_box("SupportRing", Vector3(0, h, side), Vector3(9.6, 0.30, 0.30), _steel)
	# Перила на всех четырёх сторонах; нижние поручни не загораживают горизонт.
	for side in [-1.0, 1.0]:
		for h in [0.46, 1.26]:
			_box("Rail", Vector3(side * 5.95, DECK_HEIGHT + h, 0), Vector3(0.10, 0.10, 12.0), _steel)
			_box("Rail", Vector3(0, DECK_HEIGHT + h, side * 5.95), Vector3(12.0, 0.10, 0.10), _steel)
		for i in range(5):
			var p := -5.9 + 2.95 * float(i)
			_box("RailPost", Vector3(side * 5.95, DECK_HEIGHT + 0.62, p), Vector3(0.13, 1.24, 0.13), _dark)
			_box("RailPost", Vector3(p, DECK_HEIGHT + 0.62, side * 5.95), Vector3(0.13, 1.24, 0.13), _dark)
	# Лифтовая шахта снаружи платформы; пока неподвижная часть конструкции.
	for x in [-7.7, -5.9]:
		for z in [2.4, 4.6]:
			_box("LiftShaft", Vector3(x, DECK_HEIGHT * 0.5, z), Vector3(0.22, DECK_HEIGHT + 4.0, 0.22), _rust)
	for h in [5.0, 15.0, 25.0, 35.0, 45.0, 54.0]:
		_box("LiftCrossbar", Vector3(-6.8, h, 2.4), Vector3(2.0, 0.18, 0.18), _steel)
		_box("LiftCrossbar", Vector3(-6.8, h, 4.6), Vector3(2.0, 0.18, 0.18), _steel)
	_box("LiftCage", Vector3(-6.8, 1.0, 3.5), Vector3(1.7, 0.25, 2.0), _dark)
	# На столе работает приёмник M4; крепление винтовки декоративное.
	_box("RadioStand", Vector3(-4.75, DECK_HEIGHT + 0.46, -3.9), Vector3(1.15, 0.92, 1.0), _dark)
	_box("RadioBody", Vector3(-4.75, DECK_HEIGHT + 1.05, -3.9), Vector3(0.85, 0.32, 0.62), _paint)
	_box("RadioDial", Vector3(-4.75, DECK_HEIGHT + 1.22, -3.9), Vector3(0.52, 0.02, 0.25), _screen)
	_beam("Antenna", Vector3(-5.0, DECK_HEIGHT + 1.2, -4.05), Vector3(-5.1, DECK_HEIGHT + 2.8, -4.05), 0.035, _steel)
	_box("RifleRestPost", Vector3(5.15, DECK_HEIGHT + 0.48, 2.5), Vector3(0.14, 0.96, 0.14), _rust)
	_box("RifleRest", Vector3(5.15, DECK_HEIGHT + 1.0, 2.5), Vector3(0.55, 0.12, 0.55), _steel)
