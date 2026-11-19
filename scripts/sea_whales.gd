class_name SeaWhales
extends Node3D
## Светящиеся киты ночью. Стая из трёх зверей ходит вокруг судна в открытом
## море: тела почти не видны, а читается свечение — пятно света под водой,
## россыпь огней по спине и кольца по воде за хвостом.
##
## Днём стаи нет совсем: включается по темноте, иначе пропадает
## магический контраст с обычным днём. Никаких источников света на кита нет —
## только самосвечение и аддитивные блики, чтобы ночь не дорожала.

const POD_SIZE := 3
## Радиус, внутри которого стая держится возле судна, в метрах.
const SWIM_RADIUS := 120.0
const SPEED := 4.2
const BODY_LEN := 3.4
const GLOW := Color(0.36, 0.96, 0.92)
const GLOW_DEEP := Color(0.16, 0.52, 0.88)
## С какого времени суток стая выходит. Днём её нет совсем.
const NIGHT_IN := 0.42
const NIGHT_OUT := 0.26

var main: BoatMain
var whales: Array[Dictionary] = []
var active := false
var _rng := RandomNumberGenerator.new()
var _shown := 0.0
var _ring_timer := 0.0
var _clock := 0.0
var _glow_tex: ImageTexture


func setup(main_ref: BoatMain) -> void:
	main = main_ref
	_rng.seed = 20261119
	_glow_tex = ProcTextures.radial(64, 2.1)
	visible = false
	for index in range(POD_SIZE):
		whales.append(_build_whale(index))


## Раз в кадр: стая живёт только в темноте и только в открытом море.
func advance(delta: float, night01: float) -> void:
	var want := night01 > NIGHT_IN if not active else night01 > NIGHT_OUT
	if want and not active:
		_emerge()
	elif not want and active:
		active = false
	_shown = move_toward(_shown, 1.0 if active else 0.0, delta * 0.55)
	visible = _shown > 0.01
	if not visible or main == null or main.boat == null:
		return
	_clock += delta
	var boat := Vector2(main.boat.global_position.x, main.boat.global_position.z)
	_ring_timer = maxf(0.0, _ring_timer - delta)
	for whale in whales:
		_swim(whale, delta, boat)
	if _ring_timer <= 0.0 and main.water != null and main.water.field != null:
		_ring_timer = 0.55
		# Кольца на воде за хвостом: след биолюминесценции, а не пена.
		for whale in whales:
			var at: Vector2 = whale["at"]
			main.water.field.splash(at - whale["dir"] * BODY_LEN * 0.5, 0.35)


## Вывести стаю: места вокруг судна, чтобы не появляться в кадре на глазах.
func _emerge() -> void:
	active = true
	var boat := Vector2(main.boat.global_position.x, main.boat.global_position.z)
	for whale in whales:
		var angle := _rng.randf() * TAU
		var distance := _rng.randf_range(42.0, 95.0)
		var at := boat + Vector2.from_angle(angle) * distance
		whale["at"] = at
		whale["dir"] = Vector2.from_angle(angle + PI * 0.5)
		whale["phase"] = _rng.randf() * TAU
		whale["speed"] = SPEED * _rng.randf_range(0.75, 1.25)
		whale["turn"] = _rng.randf_range(-0.14, 0.14)
		whale["surface"] = _rng.randf_range(0.0, 6.0)


## Для кадров и проверок: поставить стаю на виду, не ожидая ночи и случая.
func place_near(at: Vector2, forward: Vector2) -> void:
	active = true
	visible = true
	_shown = 1.0
	for index in range(whales.size()):
		var whale: Dictionary = whales[index]
		var side := float(index) - 1.0
		whale["at"] = at + forward * 8.0 + forward.orthogonal() * side * 13.0
		whale["dir"] = forward
		whale["phase"] = float(index) * 2.1
		whale["speed"] = SPEED * 0.6
		whale["turn"] = 0.0
		whale["surface"] = 0.0
		_place(whale, -0.55, 0.0)


func _swim(whale: Dictionary, delta: float, boat: Vector2) -> void:
	var time := _clock
	var at: Vector2 = whale["at"]
	var dir: Vector2 = whale["dir"]
	var phase: float = whale["phase"]
	# Медленный поворот: кит идёт дугой, а не по прямой.
	var wander := sin(time * 0.21 + phase) * 0.24 + float(whale["turn"])
	var heading := dir.rotated(wander * delta * SPEED * 0.1)
	# Держимся вокруг судна: ушёл далеко — плавно поворачиваем назад.
	var offset := at - boat
	if offset.length() > SWIM_RADIUS:
		var back := -offset.normalized()
		var want := back.angle()
		var turn_to := wrapf(want - heading.angle(), -PI, PI)
		heading = heading.rotated(clampf(turn_to, -0.02, 0.02))
	at += heading * float(whale["speed"]) * delta
	whale["at"] = at
	whale["dir"] = heading
	# Тело то всплывает, то уходит под воду: дыхание зверя.
	whale["surface"] = float(whale["surface"]) + delta
	var breathe := sin(float(whale["surface"]) * 0.42 + phase)
	var depth := -0.55 + breathe * 0.75
	_place(whale, depth, time)


func _place(whale: Dictionary, depth: float = -0.55, time: float = 0.0) -> void:
	var at: Vector2 = whale["at"]
	var dir: Vector2 = whale["dir"]
	var water_y := Coast.SEA_LEVEL
	if main != null and main.water != null:
		water_y = main.water.surface_height(at.x, at.y)
	var root: Node3D = whale["root"]
	root.position = Vector3(at.x, water_y + depth, at.y)
	root.rotation = Vector3(0.0, atan2(-dir.x, -dir.y), 0.0)
	# Свечение пульсирует: у каждого зверя свой ритм и своя фаза.
	var pulse := 0.55 + 0.45 * sin(time * 0.9 + float(whale["phase"]))
	var fade := _shown * pulse
	var glow: StandardMaterial3D = whale["glow_mat"]
	glow.emission_energy_multiplier = 3.4 * fade
	glow.albedo_color = GLOW.lerp(GLOW_DEEP, 0.35 * (1.0 - pulse))
	var halo: MeshInstance3D = whale["halo"]
	halo.visible = fade > 0.02
	var halo_mat: StandardMaterial3D = whale["halo_mat"]
	halo_mat.albedo_color = Color(GLOW.r, GLOW.g, GLOW.b, 0.34 * fade)
	var pool: MeshInstance3D = whale["pool"]
	# Пятно на воде гаснет вместе с глубиной: свет уходит под воду.
	var lit := clampf(1.0 + depth * 0.55, 0.0, 1.0) * fade
	pool.visible = lit > 0.02
	pool.position.y = -depth + 0.06
	var pool_mat: StandardMaterial3D = whale["pool_mat"]
	pool_mat.albedo_color = Color(GLOW.r, GLOW.g, GLOW.b, 0.5 * lit)
	var tail: Node3D = whale["tail"]
	tail.rotation.y = sin(time * 3.1 + float(whale["phase"])) * 0.35


func _build_whale(index: int) -> Dictionary:
	var root := Node3D.new()
	root.name = "Whale%d" % index
	add_child(root)
	# Позиции китов задаются в мировых координатах: узел стаи — просто контейнер.
	root.top_level = true
	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = Color(0.06, 0.10, 0.15)
	body_mat.roughness = 0.75
	body_mat.metallic = 0.05
	# Тело: вытянутая капля.
	var body := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	sphere.radial_segments = 12
	sphere.rings = 6
	body.mesh = sphere
	body.material_override = body_mat
	body.scale = Vector3(BODY_LEN * 0.34, BODY_LEN * 0.30, BODY_LEN * 1.0)
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(body)
	# Хвост: отдельный узел, чтобы вилять.
	var tail := Node3D.new()
	tail.position = Vector3(0.0, 0.0, BODY_LEN * 0.52)
	root.add_child(tail)
	var fluke := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(BODY_LEN * 0.52, 0.10, BODY_LEN * 0.26)
	fluke.mesh = box
	fluke.material_override = body_mat
	fluke.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	tail.add_child(fluke)
	# Свечение: полоса по спине и пара огней на боках.
	var glow_mat := StandardMaterial3D.new()
	glow_mat.albedo_color = GLOW
	glow_mat.emission_enabled = true
	glow_mat.emission = GLOW
	glow_mat.emission_energy_multiplier = 3.4
	glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow_mat.disable_receive_shadows = true
	var spots := [Vector3(0.0, 0.16, -0.35), Vector3(0.0, 0.18, 0.15), Vector3(0.0, 0.14, 0.62)]
	for spot in spots:
		var dot := MeshInstance3D.new()
		var dot_mesh := SphereMesh.new()
		dot_mesh.radius = 0.22
		dot_mesh.height = 0.44
		dot_mesh.radial_segments = 8
		dot_mesh.rings = 4
		dot.mesh = dot_mesh
		dot.material_override = glow_mat
		dot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		dot.scale = Vector3(1.0, 0.55, 1.5)
		dot.position = spot
		root.add_child(dot)
	# Ореол в воздухе: аддитивный билборд, ловит объёмный туман.
	var halo := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(BODY_LEN * 2.6, BODY_LEN * 2.6)
	halo.mesh = quad
	var halo_mat := StandardMaterial3D.new()
	halo_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	halo_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	halo_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	halo_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	halo_mat.albedo_texture = _glow_tex
	halo_mat.albedo_color = Color(GLOW.r, GLOW.g, GLOW.b, 0.3)
	halo_mat.disable_receive_shadows = true
	halo.material_override = halo_mat
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	halo.position = Vector3(0.0, 0.4, 0.0)
	root.add_child(halo)
	# Пятно света на самой воде.
	var pool := MeshInstance3D.new()
	var pool_quad := QuadMesh.new()
	pool_quad.size = Vector2(BODY_LEN * 4.2, BODY_LEN * 5.4)
	pool.mesh = pool_quad
	var pool_mat := StandardMaterial3D.new()
	pool_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pool_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	pool_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pool_mat.albedo_texture = _glow_tex
	pool_mat.albedo_color = Color(GLOW.r, GLOW.g, GLOW.b, 0.5)
	pool_mat.disable_receive_shadows = true
	pool.material_override = pool_mat
	pool.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pool.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
	root.add_child(pool)
	return {
		"root": root,
		"tail": tail,
		"halo": halo,
		"halo_mat": halo_mat,
		"pool": pool,
		"pool_mat": pool_mat,
		"glow_mat": glow_mat,
		"at": Vector2.ZERO,
		"dir": Vector2.DOWN,
		"phase": 0.0,
		"speed": SPEED,
		"turn": 0.0,
		"surface": 0.0,
	}
