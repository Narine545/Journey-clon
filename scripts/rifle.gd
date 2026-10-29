class_name SniperRifle
extends Node3D
## Болтовая винтовка M3. Перезарядка — цикл затвора после каждого выстрела;
## снаряд существует в мире, а очки выдаются только за видимое камерой попадание.
signal impact_confirmed(target: TargetDummy)

const MUZZLE_SPEED := 620.0
const CYCLE_TIME := 2.4
const HIT_POINTS := 100
const SCOPE_FOV := 18.0
const RANGE_LIMIT := 1500.0

var main: MainScene
var cam_rig: CameraRig
var camera: Camera3D
var audio: SoundScape
var hud: ScopeHUD
var ammo := 12
var cycle_remaining := 0.0
var aim_requested := false
var scope_amount := 0.0
var range_m := -1.0
var crosswind := 0.0
var _cycle_bolt_played := false
var _recoil := 0.0
var _clock := 0.0
var _range_clock := 0.0
var _hit_flash := 0.0
var _view_model: Node3D


func setup(main_ref: MainScene) -> void:
	main = main_ref
	cam_rig = main.cam_rig
	camera = cam_rig.cam
	audio = main.audio
	_build_view_model()
	hud = ScopeHUD.new()
	add_child(hud)


func _input(event: InputEvent) -> void:
	if main != null and main.radio_tuner != null and main.radio_tuner.tuning:
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			aim_requested = event.pressed and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
		elif event.button_index == MOUSE_BUTTON_LEFT and event.pressed and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			fire()
	elif event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE:
		aim_requested = false


func _physics_process(delta: float) -> void:
	if camera == null:
		return
	_clock += delta
	if cycle_remaining > 0.0:
		cycle_remaining = maxf(0.0, cycle_remaining - delta)
		if not _cycle_bolt_played and cycle_remaining <= CYCLE_TIME - 0.65:
			_cycle_bolt_played = true
			audio.on_bolt()
	_recoil = move_toward(_recoil, 0.0, delta * 0.032)
	_hit_flash = maxf(0.0, _hit_flash - delta * 2.5)
	scope_amount = lerpf(scope_amount, 1.0 if aim_requested else 0.0, 1.0 - exp(-7.0 * delta))
	camera.fov = lerpf(CameraRig.FOV_BASE, SCOPE_FOV, scope_amount)
	cam_rig.mouse_sensitivity_multiplier = lerpf(1.0, 0.30, scope_amount)
	# Дыхание в оптике плавное, маленькое и повторяемое; отдача затухает.
	var sway := Vector2(sin(_clock * 0.75) * 0.0010, sin(_clock * 1.10 + 0.8) * 0.0008) * scope_amount
	cam_rig.aim_offset = sway + Vector2(0.0, _recoil)
	cam_rig.refresh_pose()
	_view_model.visible = scope_amount < 0.45
	_view_model.position.z = -0.52 + _recoil * 2.0
	crosswind = Ballistics.wind_velocity(main.game).dot(camera.global_basis.x)
	_range_clock -= delta
	if scope_amount > 0.5 and _range_clock <= 0.0:
		_range_clock = 0.2
		range_m = measure_range()
	hud.update_state(scope_amount, ammo, can_fire(), main.game.score, range_m, crosswind, _hit_flash)


func can_fire() -> bool:
	return ammo > 0 and cycle_remaining <= 0.0


func fire() -> bool:
	if not can_fire():
		return false
	# Сначала фиксируем направление из оптики, потом добавляем отдачу.
	cam_rig.refresh_pose()
	var direction := -camera.global_basis.z
	var projectile := RifleProjectile.new()
	projectile.name = "Projectile"
	main.add_child(projectile)
	projectile.setup(camera.global_position, direction, MUZZLE_SPEED, main, self)
	ammo -= 1
	cycle_remaining = CYCLE_TIME
	_cycle_bolt_played = false
	_recoil = 0.018
	audio.on_rifle_shot()
	return true


## Дальномер может использовать луч: попадание же считается исключительно
## летящим RifleProjectile с отдельной проверкой каждого физического шага.
func measure_range() -> float:
	var start := camera.global_position
	var end := start - camera.global_basis.z * RANGE_LIMIT
	var query := PhysicsRayQueryParameters3D.create(start, end, 2)
	var hit := camera.get_world_3d().direct_space_state.intersect_ray(query)
	var ground := Ballistics.terrain_hit(main.coast, start, end, 12.0)
	var distance := -1.0
	if not ground.is_empty():
		distance = start.distance_to(ground["position"])
	if not hit.is_empty():
		var body_distance := start.distance_to(hit["position"])
		if distance < 0.0 or body_distance < distance:
			distance = body_distance
	return distance


func on_projectile_hit(target: TargetDummy, hit_position: Vector3) -> void:
	# «Камера винтовки» подтверждает только то, что остаётся внутри кадра,
	# а в оптике — внутри круглого поля, а не в чёрной маске.
	if camera.is_position_behind(hit_position) or not camera.is_position_in_frustum(hit_position):
		return
	if not Ballistics.terrain_hit(main.coast, camera.global_position, hit_position, 12.0).is_empty():
		return
	if scope_amount > 0.15:
		var screen := camera.unproject_position(hit_position)
		var viewport_size := get_viewport().get_visible_rect().size
		if screen.distance_to(viewport_size * 0.5) > minf(viewport_size.x, viewport_size.y) * 0.44:
			return
	_hit_flash = 1.0
	impact_confirmed.emit(target)
	audio.on_hit_confirmed()
	if target.claim_confirmed_hit():
		main.game.add_confirmed_score(HIT_POINTS)


func _build_view_model() -> void:
	_view_model = Node3D.new()
	_view_model.position = Vector3(0.28, -0.25, -0.52)
	add_child(_view_model)
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.12, 0.13, 0.12)
	metal.metallic = 0.55
	metal.roughness = 0.78
	var stock := StandardMaterial3D.new()
	stock.albedo_color = Color(0.25, 0.19, 0.13)
	stock.roughness = 0.93
	_box("Receiver", Vector3(0, 0, -0.20), Vector3(0.12, 0.13, 0.42), metal)
	_box("Stock", Vector3(0, -0.055, 0.08), Vector3(0.11, 0.16, 0.35), stock)
	_box("Barrel", Vector3(0, 0.015, -0.62), Vector3(0.045, 0.045, 0.65), metal)
	_box("Scope", Vector3(0, 0.13, -0.23), Vector3(0.105, 0.095, 0.32), metal)
	_box("ScopeMount", Vector3(0, 0.075, -0.23), Vector3(0.06, 0.08, 0.12), metal)
	_box("Bolt", Vector3(0.09, 0.0, -0.10), Vector3(0.06, 0.035, 0.035), metal)


func _box(part_name: String, at: Vector3, dimensions: Vector3, material: Material) -> void:
	var part := MeshInstance3D.new()
	part.name = part_name
	var cube := BoxMesh.new()
	cube.size = dimensions
	part.mesh = cube
	part.material_override = material
	part.position = at
	part.layers = 2
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_view_model.add_child(part)
