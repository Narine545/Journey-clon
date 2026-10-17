class_name CatchFish
extends Node3D
## Видимая пойманная рыба: процедурная геометрия из примитивов, цвет и форма
## из каталога (FishCatalog). Живёт в двух экземплярах: в мире — прыгает
## в рывок и летит в руки при вываживании; на камере — «в руках» после поимки.
##
## Модель маленькая намеренно: это не таксономия, а силуэт и цвет, чтобы
## игрок видел, что именно вытащил. Тело вытянуто по Z, нос — в −Z.

var _body: MeshInstance3D
var _head: MeshInstance3D
var _belly: MeshInstance3D
var _eyes: Array[MeshInstance3D] = []
var _tail: Node3D
var _fins: Array[MeshInstance3D] = []
var _mat_body: StandardMaterial3D
var _mat_belly: StandardMaterial3D
var _mat_fin: StandardMaterial3D
var _t := 0.0
var _wiggle := 1.0


func _ready() -> void:
	_build()


func _build() -> void:
	_mat_body = StandardMaterial3D.new()
	_mat_body.roughness = 0.42
	_mat_body.metallic = 0.25
	_mat_belly = StandardMaterial3D.new()
	_mat_belly.roughness = 0.55
	_mat_belly.metallic = 0.1
	_mat_fin = StandardMaterial3D.new()
	_mat_fin.roughness = 0.72
	_mat_fin.metallic = 0.05
	_mat_fin.cull_mode = BaseMaterial3D.CULL_DISABLED

	# тело — вытянутый эллипсоид. У рыбы, как у сигары, оба конца
	# сужаются; поэтому тело — «капсула» из трёх долей с разным сжатием
	# по длине, а не шар с приклеенным хвостом-конусом.
	_body = MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.5
	sph.height = 1.0
	sph.radial_segments = 22
	sph.rings = 12
	_body.mesh = sph
	_body.scale = Vector3(0.19, 0.27, 0.72)
	_body.position = Vector3(0.0, 0.0, -0.10)
	_body.material_override = _mat_body
	add_child(_body)

	# голова — уже и круглее: нос не обрублен, силуэт узнаётся
	var head := MeshInstance3D.new()
	var hs := SphereMesh.new()
	hs.radius = 0.5
	hs.height = 1.0
	hs.radial_segments = 18
	hs.rings = 10
	head.mesh = hs
	head.scale = Vector3(0.17, 0.24, 0.30)
	head.position = Vector3(0.0, 0.01, -0.44)
	head.material_override = _mat_body
	add_child(head)
	_eyes.clear()
	_head = head

	# тело к хвосту сходит на конус — хвостовой стебель
	var ped := MeshInstance3D.new()
	var ps := SphereMesh.new()
	ps.radius = 0.5
	ps.height = 1.0
	ps.radial_segments = 14
	ps.rings = 8
	ped.mesh = ps
	ped.scale = Vector3(0.085, 0.11, 0.17)
	ped.position = Vector3(0.0, 0.0, 0.34)
	ped.material_override = _mat_body
	add_child(ped)

	# брюхо — светлее, чуть ниже и короче
	_belly = MeshInstance3D.new()
	var bs := SphereMesh.new()
	bs.radius = 0.5
	bs.height = 1.0
	bs.radial_segments = 16
	bs.rings = 8
	_belly.mesh = bs
	_belly.scale = Vector3(0.17, 0.15, 0.62)
	_belly.position = Vector3(0.0, -0.10, -0.10)
	_belly.material_override = _mat_belly
	add_child(_belly)

	# хвост: раздвоенный «ласточкин» плавник из двух тонких плоскостей,
	# а не приклеенный конус — по нему видно, что рыба плывёт
	_tail = Node3D.new()
	_tail.position = Vector3(0.0, 0.0, 0.42)
	add_child(_tail)
	for side in [-1.0, 1.0]:
		var lobe := MeshInstance3D.new()
		var lb := BoxMesh.new()
		lb.size = Vector3(0.014, 0.30, 0.30)
		lobe.mesh = lb
		lobe.material_override = _mat_fin
		lobe.position = Vector3(0.0, 0.09 * side, 0.14)
		lobe.rotation.x = side * 0.55
		lobe.rotation.z = side * 0.0
		lobe.scale = Vector3(1.0, 1.0, 0.55)
		_tail.add_child(lobe)

	# спинной плавник и два грудных — тонкие плоскости по бокам
	_add_fin(Vector3(0.0, 0.235, -0.10), Vector3(0.016, 0.14, 0.22), 0.0)
	_add_fin(Vector3(0.155, -0.03, -0.24), Vector3(0.012, 0.10, 0.13), -0.6)
	_add_fin(Vector3(-0.155, -0.03, -0.24), Vector3(0.012, 0.10, 0.13), 0.6)

	# глаза
	for side in [-1.0, 1.0]:
		var eye := MeshInstance3D.new()
		var es := SphereMesh.new()
		es.radius = 0.030
		es.height = 0.060
		es.radial_segments = 10
		es.rings = 6
		eye.mesh = es
		var em := StandardMaterial3D.new()
		em.albedo_color = Color(0.03, 0.025, 0.02)
		em.roughness = 0.16
		eye.material_override = em
		eye.position = Vector3(0.125 * side, 0.055, -0.40)
		add_child(eye)
		_eyes.append(eye)


func _add_fin(pos: Vector3, dims: Vector3, yaw: float) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = dims
	mi.mesh = bm
	mi.material_override = _mat_fin
	mi.position = pos
	mi.rotation.y = yaw
	add_child(mi)
	_fins.append(mi)


## Настроить вид под конкретную рыбу из FishCatalog.roll_fish().
func setup(info: Dictionary) -> void:
	var col_a: Color = info.get("col_a", Color(0.6, 0.62, 0.6))
	var col_b: Color = info.get("col_b", Color(0.8, 0.8, 0.75))
	var col_f: Color = info.get("col_fin", Color(0.4, 0.4, 0.35))
	_mat_body.albedo_color = col_a
	_mat_belly.albedo_color = col_b
	_mat_fin.albedo_color = col_f
	var glow: bool = info.get("glow", false)
	_mat_body.emission_enabled = glow
	_mat_body.emission = col_a * 0.35 if glow else Color.BLACK
	_mat_belly.emission_enabled = glow
	_mat_belly.emission = col_b * 0.25 if glow else Color.BLACK
	# форма: камбала/скат плоские и широкие, угорь — длинный и узкий
	var shape: String = info.get("shape", "standard")
	var sx := 1.0
	var sy := 1.0
	var sz := 1.0
	match shape:
		"flat":
			sx = 1.55
			sy = 0.55
			sz = 0.92
		"long":
			sx = 0.72
			sy = 0.72
			sz = 1.35
		"slim":
			sx = 0.80
			sy = 0.92
			sz = 1.12
		"billed":
			sx = 0.95
			sy = 1.0
			sz = 1.25
	_body.scale = Vector3(0.19 * sx, 0.27 * sy, 0.72 * sz)
	_head.scale = Vector3(0.17 * sx, 0.24 * sy, 0.30 * sz)
	_belly.scale = Vector3(0.17 * sx, 0.15 * sy, 0.62 * sz)
	_head.position.z = -0.44 * sz
	_belly.position.z = -0.10 * sz
	for i in range(_eyes.size()):
		var sd := -1.0 if i == 0 else 1.0
		_eyes[i].position = Vector3(0.125 * sx * sd, 0.055 * sy, -0.40 * sz)
	_tail.position.z = 0.42 * sz
	# 3.3-метровый марлин в кадре не должен занимать пол-экрана
	var size_cm: float = float(info.get("size_cm", 40.0))
	var s := clampf(size_cm / 100.0, 0.20, 1.15)
	scale = Vector3.ONE * s
	_wiggle = 1.0


func _process(delta: float) -> void:
	_t += delta
	if _tail != null:
		_tail.rotation.y = sin(_t * 9.0) * 0.28 * _wiggle


## Поставить рыбу в мир: позиция, курс и крен (для прыжков/полёта).
func pose_world(pos: Vector3, yaw: float, roll: float) -> void:
	global_position = pos
	rotation = Vector3(0.0, yaw, roll)
	visible = true


func set_wiggle(v: float) -> void:
	_wiggle = clampf(v, 0.0, 1.5)
