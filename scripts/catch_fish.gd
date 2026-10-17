class_name CatchFish
extends Node3D
## Видимая пойманная рыба: процедурная геометрия из примитивов, цвет и форма
## из каталога (FishCatalog). Живёт в двух экземплярах: в мире — прыгает
## в рывок и летит в руки при вываживании; на камере — «в руках» после поимки.
##
## Модель маленькая намеренно: это не таксономия, а силуэт и цвет, чтобы
## игрок видел, что именно вытащил. Тело вытянуто по Z, нос — в −Z.

var _body: MeshInstance3D
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

	# тело: сфера, растянутая в длину (1 м по Z)
	_body = MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.5
	sph.height = 1.0
	sph.radial_segments = 18
	sph.rings = 10
	_body.mesh = sph
	_body.scale = Vector3(0.34, 0.40, 1.0)
	_body.material_override = _mat_body
	add_child(_body)

	# брюхо — светлее, чуть ниже и короче
	_belly = MeshInstance3D.new()
	var bs := SphereMesh.new()
	bs.radius = 0.5
	bs.height = 1.0
	bs.radial_segments = 14
	bs.rings = 8
	_belly.mesh = bs
	_belly.scale = Vector3(0.30, 0.24, 0.82)
	_belly.position = Vector3(0.0, -0.09, 0.02)
	_belly.material_override = _mat_belly
	add_child(_belly)

	# хвост: конус, раструбом к телу, остриём назад
	_tail = Node3D.new()
	_tail.position = Vector3(0.0, 0.0, 0.46)
	add_child(_tail)
	var tail_fin := MeshInstance3D.new()
	var tc := CylinderMesh.new()
	tc.top_radius = 0.015
	tc.bottom_radius = 0.17
	tc.height = 0.30
	tc.radial_segments = 10
	tail_fin.mesh = tc
	tail_fin.material_override = _mat_fin
	tail_fin.position = Vector3(0.0, 0.0, 0.13)
	tail_fin.rotation.x = PI * 0.5
	tail_fin.scale = Vector3(0.20, 1.0, 1.0)
	_tail.add_child(tail_fin)

	# спинной плавник и два грудных
	_add_fin(Vector3(0.0, 0.20, -0.02), Vector3(0.018, 0.16, 0.26), 0.0)
	_add_fin(Vector3(0.16, -0.02, -0.18), Vector3(0.012, 0.12, 0.14), -0.5)
	_add_fin(Vector3(-0.16, -0.02, -0.18), Vector3(0.012, 0.12, 0.14), 0.5)

	# глаза
	for side in [-1.0, 1.0]:
		var eye := MeshInstance3D.new()
		var es := SphereMesh.new()
		es.radius = 0.026
		es.height = 0.052
		es.radial_segments = 8
		es.rings = 5
		eye.mesh = es
		var em := StandardMaterial3D.new()
		em.albedo_color = Color(0.04, 0.035, 0.03)
		em.roughness = 0.2
		eye.material_override = em
		eye.position = Vector3(0.13 * side, 0.045, -0.27)
		add_child(eye)
		_eyes.append(eye)


func _add_fin(pos: Vector3, size: Vector3, yaw: float) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
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
	_body.scale = Vector3(0.34 * sx, 0.40 * sy, sz)
	_belly.scale = Vector3(0.30 * sx, 0.24 * sy, 0.82 * sz)
	_tail.position.z = 0.46 * sz
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
