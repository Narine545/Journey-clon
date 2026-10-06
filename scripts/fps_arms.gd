class_name FpsArms
extends Node3D
## Руки с пистолетом Mark 23 (Sketchfab, BarcodeGames): анимации Draw /
## Shoot / Reload из ассета. Стрельба — лучом по аналитическому рельефу:
## попадание в песок штампует маленький кратер и поднимает пыль.
## HUD не предусмотрено: счёт патронов «в руках» — пустой магазин щёлкает.

const MAG := 12
const SCALE := 0.01 # ассет в сантиметрах
const TARGET_CENTER := Vector3(0.18, -0.30, -0.46) # центр модели относительно камеры
const ROT_Y := PI # Sketchfab-модели смотрят на камеру — разворачиваем от себя
const RAY_MAX := 140.0
const RAY_STEP := 0.6

var ammo := MAG
var shots_fired := 0
var last_hit := Vector3.ZERO
var last_hit_valid := false
var suppress_shoot_frames := 0 # после захвата курсора клик не должен стрелять

var _anim: AnimationPlayer
var _busy_t := 0.0 # анимация занимает руки
var _reloading := false
var _flash: OmniLight3D
var _dust: CPUParticles3D
var _main
var _rig: CameraRig


func setup(main_ref, rig_ref: CameraRig) -> void:
	_main = main_ref
	_rig = rig_ref

	var scene: PackedScene = load("res://assets/mark_23_animated/scene.gltf")
	if scene == null:
		push_error("ARMS: нет модели res://assets/mark_23_animated/scene.gltf")
		return
	var inst: Node3D = scene.instantiate()
	_anim = _find_anim(inst)
	if _anim == null:
		push_error("ARMS: в модели нет AnimationPlayer")
		return

	# авто-посадка: меряем общий AABB модели и ставим её центр в TARGET_CENTER
	add_child(inst)
	inst.scale = Vector3(SCALE, SCALE, SCALE)
	inst.rotation.y = ROT_Y
	var aabb := _union_aabb(inst, Transform3D.IDENTITY)
	var center := (aabb.position + aabb.end) * 0.5 * SCALE
	inst.position = TARGET_CENTER - center + Vector3(0.0, 0.0, 0.0)

	# вспышка выстрела у среза ствола
	_flash = OmniLight3D.new()
	add_child(_flash)
	_flash.position = TARGET_CENTER + Vector3(0.0, 0.10, -0.35)
	_flash.light_color = Color(1.0, 0.82, 0.45)
	_flash.omni_range = 10.0
	_flash.light_energy = 0.0
	_flash.shadow_enabled = false

	# пыль от попадания в песок (мировые координаты, переезжает к точке)
	_dust = CPUParticles3D.new()
	_main.add_child(_dust)
	_dust.amount = 12
	_dust.one_shot = true
	_dust.explosiveness = 1.0
	_dust.lifetime = 0.5
	_dust.lifetime_randomness = 0.3
	_dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_dust.emission_sphere_radius = 0.06
	_dust.spread = 180.0
	_dust.initial_velocity_min = 0.8
	_dust.initial_velocity_max = 2.2
	_dust.gravity = Vector3(0.0, -3.0, 0.0)
	_dust.damping_min = 4.0
	_dust.damping_max = 7.0
	_dust.scale_amount_min = 0.4
	_dust.scale_amount_max = 0.8
	_dust.scale_amount_curve = ProcTextures.grow_curve(0.3, 1.0)
	_dust.color_ramp = ProcTextures.fade_ramp()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.3, 0.3)
	quad.material = ProcTextures.soft_material(Color(0.95, 0.75, 0.52, 0.34))
	_dust.mesh = quad
	_dust.visibility_aabb = AABB(Vector3(-3.0, -2.0, -3.0), Vector3(6.0, 4.0, 6.0))
	_dust.emitting = false
	_dust.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	_play(&"Draw")


func _find_anim(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for c in node.get_children():
		var r := _find_anim(c)
		if r != null:
			return r
	return null


func _union_aabb(node: Node, xform: Transform3D) -> AABB:
	var out := AABB()
	var has_box := false
	if node is MeshInstance3D:
		var mi: MeshInstance3D = node
		if mi.mesh != null:
			var b: AABB = xform * mi.get_aabb()
			out = b
			has_box = true
	for c in node.get_children():
		# AnimationPlayer и прочие не-3D узлы трансформа не имеют
		var cb := _union_aabb(c, xform * Transform3D((c as Node3D).transform)) if c is Node3D \
			else _union_aabb(c, xform)
		if not cb.size == Vector3.ZERO:
			if has_box:
				out = out.merge(cb)
			else:
				out = cb
				has_box = true
	return out


func _physics_process(delta: float) -> void:
	if _anim == null:
		return
	if _busy_t > 0.0:
		_busy_t -= delta
		if _busy_t <= 0.0 and _reloading:
			_reloading = false
			ammo = MAG
	if _flash != null and _flash.light_energy > 0.01:
		_flash.light_energy *= exp(-38.0 * delta)
	elif _flash != null:
		_flash.light_energy = 0.0
	if suppress_shoot_frames > 0:
		suppress_shoot_frames -= 1
		return
	if Input.is_action_just_pressed("shoot"):
		try_shoot()
	elif Input.is_action_just_pressed("reload"):
		try_reload()


## Выстрел: анимация, вспышка, звук; луч по рельефу — кратер в песке.
func try_shoot() -> void:
	if _anim == null or _busy_t > 0.0:
		return
	if ammo <= 0:
		if _main.audio != null:
			_main.audio.on_gun_empty()
		_busy_t = 0.3
		return
	ammo -= 1
	shots_fired += 1
	_play(&"Shoot")
	_busy_t = _anim_len() * 0.55 # полуавто: темп чуть быстрее анимации
	if _flash != null:
		_flash.light_energy = 7.0
	if _main.audio != null:
		_main.audio.on_shot()

	# луч: из камеры вперёд, до встречи с дюнами (аналитический марш)
	var cam: Camera3D = _rig.cam
	var from := cam.global_position
	var dir := -cam.global_transform.basis.z
	var hit: Variant = _ray_sand(from, dir)
	last_hit_valid = hit != null
	if hit != null:
		last_hit = hit
		if _main.sand != null:
			var d2 := Vector2(dir.x, dir.z)
			if d2.length() > 0.01:
				d2 = d2.normalized()
			# кратер шире текселя сетки песка (0.12 м): пуля выбивает
			# песок всплеском, полширины 0.13 перекрывает центры текселей
			_main.sand.stamp_foot(
				Vector2(hit.x, hit.z), d2,
				0.18, 0.26, 0.030, 0.014
			)
		if _dust != null:
			_dust.global_position = hit + Vector3(0.0, 0.10, 0.0)
			_dust.restart()
		if _main.audio != null:
			_main.audio.on_step(0.55) # пуле отвечает песок


## Перезарядка: полная анимация, магазин — полный.
func try_reload() -> void:
	if _anim == null or _busy_t > 0.0 or ammo == MAG or _reloading:
		return
	_reloading = true
	_play(&"Reload")
	_busy_t = _anim_len()
	if _main.audio != null:
		_main.audio.on_reload()


func _play(anim_name: StringName) -> void:
	_anim.stop()
	_anim.play(anim_name)


func _anim_len() -> float:
	return maxf(_anim.current_animation_length, 0.25)


## Аналитический луч по полю высот: марш с шагом, затем бисекция.
## Физического коллайдера у дюн нет — рельеф и есть физика.
func _ray_sand(from: Vector3, dir: Vector3) -> Variant:
	var t := 0.0
	var prev_t := 0.0
	var terrain: Terrain = _main.terrain
	while t < RAY_MAX:
		t += RAY_STEP
		var p := from + dir * t
		var gh := terrain.ground_height(p.x, p.z)
		if p.y <= gh:
			# бисекция между prev_t и t
			var lo := prev_t
			var hi := t
			for k in range(10):
				var mid := (lo + hi) * 0.5
				var pm := from + dir * mid
				if pm.y <= terrain.ground_height(pm.x, pm.z):
					hi = mid
				else:
					lo = mid
			return from + dir * hi
		prev_t = t
	return null


## Заняты ли руки анимацией (для тестов: темп стрельбы/перезарядки).
func busy() -> float:
	return _busy_t


## Текущая анимация (для тестов/диагностики).
func anim_name() -> String:
	if _anim == null:
		return ""
	return _anim.current_animation
