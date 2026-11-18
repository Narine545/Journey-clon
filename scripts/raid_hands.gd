class_name RaidHands
extends Node3D
## Гигантские руки по бортам. Куплены в рейде — растут из корпуса и работают
## сами: тянутся к ближайшему врагу, сжимают пальцы, швыряют его в сторону и
## возвращаются в покой.
##
## Геометрия процедурная: плечо — бедро руки, локтевой изгиб — та же
## двухзвенная IK, что у ног; ладонь и пальцы — коробки, пальцы сжимаются
## при хватке. Всё в системе координат лодки: нос — −Z, правый борт — +X.

const SHOULDER_X := 2.5
const SHOULDER_Y := 0.35
const SHOULDER_Z := 0.0
const UPPER := 4.0
const LOWER := 4.0
const SIDES := [-1.0, 1.0]
const GROW_TIME := 0.4
## Сколько длится один жест: дотянуться, схватить, вернуться.
const REACH_TIME := 0.85
const SKIN := Color(0.90, 0.72, 0.60)
const SKIN_SHADE := Color(0.78, 0.60, 0.51)

var main: BoatMain
var _arms: Array[Dictionary] = []
var _grow := 0.0
var _want := false
var _hair_texture: ImageTexture


func setup(main_ref: BoatMain) -> void:
	main = main_ref
	visible = false
	_hair_texture = _make_hair_texture()
	_build()


func _process(delta: float) -> void:
	_flex(delta)


func set_active(value: bool) -> void:
	_want = value
	if value:
		visible = true


## Руки заняты, пока хоть одна тянется или возвращается.
func busy() -> bool:
	for arm in _arms:
		if bool(arm["busy"]):
			return true
	return false


## Схватить: рука со стороны side (−1 левая, +1 правая) тянется к точке в мире.
## on_hit выстреливает ровно в момент сжатия пальцев — урон приходит с задержкой
## на дотягивание, чтобы удар совпадал с движением.
func grab(side: float, at_world: Vector3, on_hit: Callable) -> void:
	for arm in _arms:
		if is_equal_approx(float(arm["side"]), side):
			arm["target"] = at_world
			arm["clock"] = 0.0
			arm["busy"] = true
			arm["fired"] = false
			arm["on_hit"] = on_hit


func _flex(delta: float) -> void:
	_grow = move_toward(_grow, 1.0 if _want else 0.0, delta / GROW_TIME)
	if _grow <= 0.01:
		visible = false
		return
	visible = true
	var grow := maxf(_grow, 0.02)
	scale = Vector3(0.55 + 0.45 * grow, grow, 0.55 + 0.45 * grow)
	for arm in _arms:
		_pose(arm, delta)


func _pose(arm: Dictionary, delta: float) -> void:
	var side: float = arm["side"]
	var shoulder: Vector3 = arm["shoulder"]
	var idle := shoulder + Vector3(side * 1.0, -1.25, 0.55)
	# В покое рука спрятана: видна только когда тянется, иначе торчит у борта.
	var shown := bool(arm["busy"])
	for node in arm["nodes"]:
		(node as MeshInstance3D).visible = shown
	var wrist_world := global_transform * idle
	if bool(arm["busy"]):
		arm["clock"] = float(arm["clock"]) + delta
		var k := clampf(float(arm["clock"]) / REACH_TIME, 0.0, 1.0)
		# Дотянуться (0…0,4), схватить и дёрнуть (0,4…0,6), вернуться.
		var out := smoothstep(0.0, 0.40, k)
		var back := smoothstep(0.62, 1.0, k)
		var blend := out * (1.0 - back)
		var target: Vector3 = arm["target"]
		wrist_world = (global_transform * idle).lerp(target, blend)
		arm["grip"] = smoothstep(0.30, 0.46, k) * (1.0 - smoothstep(0.55, 0.68, k))
		if not bool(arm.get("fired", false)) and k >= 0.40:
			arm["fired"] = true
			var on_hit: Callable = arm.get("on_hit", Callable())
			if on_hit.is_valid():
				on_hit.call()
		if k >= 1.0:
			arm["busy"] = false
			arm["grip"] = 0.0
			arm["on_hit"] = Callable()
	var wrist := _reach(shoulder, to_local(wrist_world))
	var pole := Vector3(side * 1.0, 1.0, 0.35)
	var elbow := _elbow(shoulder, wrist, pole)
	var upper: MeshInstance3D = arm["upper"]
	var lower: MeshInstance3D = arm["lower"]
	_segment(upper, shoulder, elbow)
	_segment(lower, elbow, wrist)
	_hand(arm, wrist, side)


## Кисть: ладонь и четыре пальца. Открытая — пальцы торчат наружу от борта,
## сжатая — сгибаются вниз, к воде, как при хватке.
func _hand(arm: Dictionary, wrist: Vector3, side: float) -> void:
	var grip := float(arm.get("grip", 0.0))
	var outward := Vector3(side, 0.0, 0.0)
	var palm_pos := wrist + outward * 0.20
	var palm: MeshInstance3D = arm["palm"]
	palm.transform = Transform3D(Basis.IDENTITY, palm_pos)
	var curl := lerpf(0.12, 1.30, grip)
	var fingers: Array = arm["fingers"]
	for index in range(fingers.size()):
		var finger: MeshInstance3D = fingers[index]
		var across := (float(index) - 1.5) * 0.42
		var root := palm_pos + outward * 0.14 + Vector3(0.0, 0.0, across)
		var dir := (outward * cos(curl) + Vector3.DOWN * sin(curl)).normalized()
		_segment(finger, root, root + dir * 1.50)


func _reach(shoulder: Vector3, wrist: Vector3) -> Vector3:
	var delta := wrist - shoulder
	var limit := UPPER + LOWER - 0.04
	if delta.length() <= limit:
		return wrist
	if delta.length() < 0.001:
		return shoulder + Vector3.DOWN * limit
	return shoulder + delta.normalized() * limit


func _elbow(shoulder: Vector3, wrist: Vector3, pole: Vector3) -> Vector3:
	var delta := wrist - shoulder
	var distance := clampf(delta.length(), absf(UPPER - LOWER) + 0.05, UPPER + LOWER - 0.05)
	if distance < 0.001:
		return shoulder + Vector3.DOWN * UPPER
	var direction := delta.normalized()
	var cos_a := clampf(
		(UPPER * UPPER + distance * distance - LOWER * LOWER) / (2.0 * UPPER * distance), -1.0, 1.0
	)
	var bend := direction.cross(pole)
	if bend.length_squared() < 0.0001:
		bend = direction.cross(Vector3.FORWARD)
	if bend.length_squared() < 0.0001:
		return shoulder + direction * UPPER
	bend = bend.normalized()
	return shoulder + direction.rotated(bend, acos(cos_a)) * UPPER


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


func _build() -> void:
	var hair := _skin(SKIN, true)
	for side_index in range(SIDES.size()):
		var side: float = SIDES[side_index]
		var arm := {
			"side": side,
			"shoulder": Vector3(side * SHOULDER_X, SHOULDER_Y, SHOULDER_Z),
			"busy": false,
			"clock": 0.0,
			"grip": 0.0,
			"fired": false,
			"on_hit": Callable(),
			"target": Vector3.ZERO,
		}
		arm["upper"] = _limb(0.72, 0.56, hair)
		arm["lower"] = _limb(0.54, 0.42, hair)
		arm["palm"] = _box(Vector3(0.55, 1.60, 1.20), SKIN)
		var nodes: Array[MeshInstance3D] = [arm["upper"], arm["lower"], arm["palm"]]
		var fingers: Array[MeshInstance3D] = []
		for _index in range(4):
			fingers.append(_box(Vector3(0.42, 0.42, 0.50), SKIN_SHADE))
		arm["fingers"] = fingers
		nodes.append_array(fingers)
		arm["nodes"] = nodes
		_arms.append(arm)


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


func _box(size: Vector3, tint: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = _skin(tint, false)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	return node


func _skin(tint: Color, hairy: bool) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.roughness = 0.9 if hairy else 0.8
	material.metallic = 0.0
	if hairy:
		material.albedo_texture = _hair_texture
	return material


## Кожа с волосами: тёмные пряди вдоль руки.
func _make_hair_texture() -> ImageTexture:
	var width := 32
	var height := 64
	var image := Image.create(width, height, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7717
	for x in range(width):
		var strand := rng.randf()
		var dark := rng.randf_range(0.35, 1.0)
		for y in range(height):
			var wobble := sin(float(y) * 0.55 + strand * TAU) * 0.5 + 0.5
			var cover := clampf(dark * (0.55 + 0.75 * wobble) - 0.74, 0.0, 1.0)
			var skin := SKIN.lerp(SKIN_SHADE, 0.35 * sin(float(y) * 0.12 + strand * 3.0) * 0.5 + 0.5)
			image.set_pixel(x, y, skin.lerp(Color(0.26, 0.20, 0.17), cover))
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)
