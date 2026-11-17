class_name RaidLegs
extends Node3D
## Временный бонус рейда: по бортам вырастают волосатые ноги, судно идёт по
## поверхности воды шагом, а ноги пинают всё, что подошло к борту.
##
## Геометрия процедурная и дешёвая: бедро, голень и ступня — цилиндры и
## коробка, которые каждый кадр выставляются между суставами (двухзвенная
## IK). Ноги живут в системе координат лодки: нос — −Z, правый борт — +X.
## Каждый шаг ступня остаётся в мире, поэтому по воде идут настоящие шаги,
## а не «бег на месте».

const SIDE_X := 1.65
const HIP_Y := 0.15
const HIP_Z := [-2.45, 2.45]
const HIP_SIDE := [-1.0, 1.0]
const THIGH := 3.4
const SHIN := 3.5
const STRIDE := 1.8
## Доля цикла, когда ступня стоит на воде (остальное — перенос).
const STANCE := 0.55
const LIFT := 0.85
const GROW_TIME := 0.45
const SKIN := Color(0.79, 0.63, 0.52)
const SKIN_SHADE := Color(0.66, 0.50, 0.42)

var main: BoatMain
var _legs: Array[Dictionary] = []
var _cycle := 0.0
var _grow := 0.0
var _want := false
var _kick_energy := 0.0
var _kick_leg := -1
var _splash_cd := 0.0
var _hair_texture: ImageTexture


func setup(main_ref: BoatMain) -> void:
	main = main_ref
	visible = false
	_hair_texture = _make_hair_texture()
	_build()


## Анимация живёт своим кадром: рейд только сообщает, подняты ноги или нет.
func _process(delta: float) -> void:
	var speed := 0.0
	if main != null and main.boat != null:
		speed = main.boat.speed
	step(delta, speed)


func set_active(value: bool) -> void:
	_want = value
	if value:
		visible = true


func grown() -> bool:
	return _grow > 0.55


## Пинок ногой с указанного борта (−1 левый, +1 правый).
func kick(side: float) -> void:
	_kick_energy = 1.0
	_kick_leg = 0 if side < 0.0 else 2
	for index in range(_legs.size()):
		var leg: Dictionary = _legs[index]
		if is_equal_approx(float(leg["side"]), side) and float(leg["hip_z"]) < 0.0:
			_kick_leg = index


## Шаг ног. Вызывается из RaidRun каждый физический кадр.
func step(delta: float, speed: float) -> void:
	var target := 1.0 if _want else 0.0
	_grow = move_toward(_grow, target, delta / GROW_TIME)
	scale = Vector3(0.35 + 0.65 * _grow, _grow, 0.35 + 0.65 * _grow)
	if _grow <= 0.01:
		visible = false
		_cycle = 0.0
		return
	visible = true
	_splash_cd = maxf(0.0, _splash_cd - delta)
	_kick_energy = maxf(0.0, _kick_energy - delta * 3.2)
	var pace := 0.75 + clampf(absf(speed), 0.0, 12.0) * 0.20
	_cycle = fposmod(_cycle + delta * pace, 1.0)
	for index in range(_legs.size()):
		_pose_leg(index, delta)


func _pose_leg(index: int, _delta: float) -> void:
	var leg: Dictionary = _legs[index]
	var side: float = leg["side"]
	var hip: Vector3 = leg["hip"]
	var hip_world: Vector3 = global_transform * hip
	var offset: float = leg["offset"]
	var phase := fposmod(_cycle + offset, 1.0)
	var anchor: Vector3 = leg["anchor"]
	var plant := false
	if phase < STANCE:
		# Опора: ступня стоит там, куда её поставили, — судно уходит вперёд.
		if not bool(leg["planted"]):
			leg["planted"] = true
			plant = true
			anchor = leg["next"]
	else:
		if bool(leg["planted"]):
			leg["planted"] = false
			leg["from"] = anchor
			leg["next"] = _landing_point(hip_world, side)
		var swing := (phase - STANCE) / (1.0 - STANCE)
		var from: Vector3 = leg["from"]
		var to: Vector3 = leg["next"]
		var eased := smoothstep(0.0, 1.0, swing)
		anchor = from.lerp(to, eased)
		anchor.y = _water_y(anchor) + sin(swing * PI) * LIFT
	leg["anchor"] = anchor
	var foot_world := anchor
	if _kick_leg == index and _kick_energy > 0.01:
		# Пинок: ступня уходит вперёд и вверх, нога распрямляется.
		var forward := -global_transform.basis.z
		var aim := hip_world + forward * (3.6 * _kick_energy) + Vector3.UP * (1.9 * _kick_energy)
		foot_world = foot_world.lerp(aim, clampf(_kick_energy * 1.35, 0.0, 1.0))
	var foot := to_local(foot_world)
	var pole := Vector3(side * 0.55, 0.35, -1.0)
	var knee := _knee(hip, foot, pole)
	var thigh: MeshInstance3D = leg["thigh"]
	var shin: MeshInstance3D = leg["shin"]
	var shoe: MeshInstance3D = leg["foot"]
	_segment(thigh, hip, knee)
	_segment(shin, knee, foot)
	_set_foot(shoe, foot_world)
	if plant:
		_splash(foot_world)


## Куда нога встанет в следующий раз: впереди бедра, с небольшим выносом.
func _landing_point(hip_world: Vector3, side: float) -> Vector3:
	var forward := -global_transform.basis.z
	var side_dir := global_transform.basis.x
	var land := hip_world + forward * STRIDE + side_dir * (0.9 * side)
	land.y = _water_y(land)
	return land


func _water_y(at: Vector3) -> float:
	if main == null or main.water == null:
		return 0.0
	return main.water.surface_height(at.x, at.z)


func _splash(at: Vector3) -> void:
	if _splash_cd > 0.0:
		return
	_splash_cd = 0.16
	if main == null:
		return
	if main.water != null and main.water.field != null:
		main.water.field.splash(Vector2(at.x, at.z), 0.85)
	if main.sound != null:
		main.sound.splash(Vector3(at.x, _water_y(at), at.z), 0.35)


## Колено двухзвенной ноги: бедро и голень фиксированной длины, изгиб — в
## сторону вектора pole (вперёд и немного наружу).
func _knee(hip: Vector3, foot: Vector3, pole: Vector3) -> Vector3:
	var delta := foot - hip
	var distance := clampf(delta.length(), absf(THIGH - SHIN) + 0.05, THIGH + SHIN - 0.05)
	if distance < 0.001:
		return hip + Vector3.DOWN * THIGH
	var direction := delta.normalized()
	var cos_a := clampf(
		(THIGH * THIGH + distance * distance - SHIN * SHIN) / (2.0 * THIGH * distance), -1.0, 1.0
	)
	var bend := direction.cross(pole)
	if bend.length_squared() < 0.0001:
		bend = direction.cross(Vector3.RIGHT)
	if bend.length_squared() < 0.0001:
		return hip + direction * THIGH
	bend = bend.normalized()
	return hip + direction.rotated(bend, acos(cos_a)) * THIGH


## Цилиндр высотой 1 растягивается между двумя точками.
func _segment(node: MeshInstance3D, from: Vector3, to: Vector3) -> void:
	var delta := to - from
	var length := delta.length()
	if length < 0.001:
		return
	var up := delta / length
	var reference := Vector3.UP if absf(up.dot(Vector3.UP)) < 0.94 else Vector3.RIGHT
	var right := up.cross(reference).normalized()
	var forward := right.cross(up).normalized()
	node.transform = Transform3D(Basis(right, up * length, forward), (from + to) * 0.5)


func _set_foot(node: MeshInstance3D, at_world: Vector3) -> void:
	var local := to_local(at_world)
	node.transform = Transform3D(Basis.IDENTITY, local + Vector3(0.0, -0.06, 0.0))


func _build() -> void:
	var hair := _hair_material()
	for side_index in range(HIP_SIDE.size()):
		var side: float = HIP_SIDE[side_index]
		for z_index in range(HIP_Z.size()):
			var hip_z: float = HIP_Z[z_index]
			var leg := {
				"side": side,
				"hip": Vector3(side * SIDE_X, HIP_Y, hip_z),
				"hip_z": hip_z,
				"offset": 0.0 if z_index == 0 else 0.5,
				"anchor": Vector3.ZERO,
				"from": Vector3.ZERO,
				"next": Vector3.ZERO,
				"planted": true,
			}
			if side < 0.0:
				leg["offset"] = 0.25 if z_index == 0 else 0.75
			leg["thigh"] = _limb(0.52, 0.40, hair)
			leg["shin"] = _limb(0.38, 0.28, hair)
			leg["foot"] = _foot()
			_legs.append(leg)


func _limb(top: float, bottom: float, material: Material) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = 1.0
	mesh.radial_segments = 10
	mesh.rings = 2
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	return node


func _foot() -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.62, 0.26, 1.15)
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = _skin_material(SKIN_SHADE)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	return node


func _skin_material(tint: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.roughness = 0.82
	material.metallic = 0.0
	return material


## Кожа с волосами: тёмные пряди вдоль ноги, частота — по UV цилиндра.
func _hair_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_texture = _hair_texture
	material.roughness = 0.94
	material.metallic = 0.0
	return material


func _make_hair_texture() -> ImageTexture:
	var width := 32
	var height := 64
	var image := Image.create(width, height, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5150
	for x in range(width):
		var strand := rng.randf()
		var dark := rng.randf_range(0.35, 1.0)
		for y in range(height):
			# Прядь то появляется, то пропадает: волосы, а не полосы.
			var wobble := sin(float(y) * 0.55 + strand * TAU) * 0.5 + 0.5
			var cover := clampf(dark * (0.55 + 0.75 * wobble) - 0.52, 0.0, 1.0)
			var skin := SKIN.lerp(SKIN_SHADE, 0.35 * sin(float(y) * 0.12 + strand * 3.0) * 0.5 + 0.5)
			var color := skin.lerp(Color(0.13, 0.10, 0.09), cover)
			image.set_pixel(x, y, color)
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)
