class_name SniperRifle
extends Node3D
## Болтовая винтовка M3. Перезарядка — цикл затвора после каждого выстрела;
## снаряд существует в мире, а очки выдаются только за видимое камерой попадание.
signal impact_confirmed(target: TargetDummy)
signal robot_impact_confirmed(robot: AmbientRobot)
signal reward_confirmed(amount: int)

const MUZZLE_SPEED: float = SupplyCatalog.SETTINGS["muzzle_speed"]
const CYCLE_TIME: float = SupplyCatalog.SETTINGS["bolt_seconds"]
const HIT_POINTS: int = SupplyCatalog.SETTINGS["target_reward"]
const SCOPE_FOV := 18.0
const RANGE_LIMIT := 1500.0
# Самая дальняя вершина оружия в локальных координатах камеры < 1.6 м.
const VIEW_MODEL_RADIUS := 1.60
const RAIL_CLEARANCE := 0.16

var main: MainScene
var cam_rig: CameraRig
var camera: Camera3D
var audio: SoundScape
var hud: ScopeHUD
var ammo: int = SupplyCatalog.SETTINGS["start_magazine"]
var regular_reserve: int = SupplyCatalog.SETTINGS["start_regular_reserve"]
var ap_reserve: int = SupplyCatalog.SETTINGS["start_ap_reserve"]
var ammo_type := "regular"
var zoom_multiplier := 1.0
var sway_multiplier := 1.0
var _deflect_flash := 0.0
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
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_E:
			if main.lift != null and main.lift.try_collect_from_camera():
				get_viewport().set_input_as_handled()
				return
		elif event.physical_keycode == KEY_TAB:
			switch_ammo()
			get_viewport().set_input_as_handled()
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
		if cycle_remaining <= 0.0 and ammo == 0:
			_reload_selected()
	_recoil = move_toward(_recoil, 0.0, delta * 0.032)
	_hit_flash = maxf(0.0, _hit_flash - delta * 2.5)
	_deflect_flash = maxf(0.0, _deflect_flash - delta * 2.0)
	scope_amount = lerpf(scope_amount, 1.0 if aim_requested else 0.0, 1.0 - exp(-7.0 * delta))
	camera.fov = lerpf(CameraRig.FOV_BASE, SCOPE_FOV / zoom_multiplier, scope_amount)
	cam_rig.mouse_sensitivity_multiplier = lerpf(1.0, 0.30, scope_amount)
	# Дыхание в оптике плавное, маленькое и повторяемое; отдача затухает.
	var sway := Vector2(sin(_clock * 0.75) * 0.0010, sin(_clock * 1.10 + 0.8) * 0.0008) * scope_amount * sway_multiplier
	cam_rig.aim_offset = sway + Vector2(0.0, _recoil)
	cam_rig.refresh_pose()
	_view_model.visible = scope_amount < 0.45
	_update_view_model()
	crosswind = Ballistics.wind_velocity(main.game).dot(camera.global_basis.x)
	_range_clock -= delta
	if scope_amount > 0.5 and _range_clock <= 0.0:
		_range_clock = 0.2
		range_m = measure_range()
	hud.update_state(scope_amount, ammo, can_fire(), range_m, crosswind, _hit_flash, _deflect_flash, ammo_type, regular_reserve, ap_reserve, Economy.points, main.lift.status_text() if main.lift != null else "")


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
	projectile.setup(camera.global_position, direction, MUZZLE_SPEED, main, self, ammo_type == "ap")
	ammo -= 1
	cycle_remaining = CYCLE_TIME
	_cycle_bolt_played = false
	_recoil = 0.018
	audio.on_rifle_shot()
	return true


func switch_ammo() -> void:
	# При смене типа не теряем патроны из магазина.
	if ammo_type == "regular":
		regular_reserve += ammo
		ammo_type = "ap"
	else:
		ap_reserve += ammo
		ammo_type = "regular"
	ammo = 0
	_reload_selected()


func _reload_selected() -> void:
	var capacity: int = SupplyCatalog.SETTINGS["magazine_capacity"]
	var available := regular_reserve if ammo_type == "regular" else ap_reserve
	var loaded := mini(capacity - ammo, available)
	ammo += loaded
	if ammo_type == "regular":
		regular_reserve -= loaded
	else:
		ap_reserve -= loaded


## Слот для сигнала доставки: источник не знает о винтовке напрямую.
func apply_delivery(_item_id: String, effect: Dictionary) -> void:
	regular_reserve += int(effect.get("regular_ammo", 0))
	ap_reserve += int(effect.get("ap_ammo", 0))
	if effect.has("zoom_multiplier"):
		zoom_multiplier = float(effect["zoom_multiplier"])
	if effect.has("sway_multiplier"):
		sway_multiplier = float(effect["sway_multiplier"])
	if ammo == 0 and cycle_remaining <= 0.0:
		_reload_selected()


func on_armor_deflect(hit_position: Vector3) -> void:
	if not _is_visible_hit(hit_position):
		return
	_deflect_flash = 1.0
	audio.on_refused()


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
	if not _is_visible_hit(hit_position):
		return
	_show_hit_confirmation()
	impact_confirmed.emit(target)
	if target.claim_confirmed_hit():
		reward_confirmed.emit(HIT_POINTS)


func on_robot_hit(robot: AmbientRobot, hit_position: Vector3) -> void:
	if not _is_visible_hit(hit_position):
		return
	# Тот же тихий тик и маркер, что у мишеней, но без очков и звука смерти.
	_show_hit_confirmation()
	robot_impact_confirmed.emit(robot)
	if robot.claim_reward():
		var category := "scout" if robot.kind == AmbientRobot.Kind.SCOUT else ("carrier" if robot.kind == AmbientRobot.Kind.CARRIER else "walker")
		reward_confirmed.emit(int(SupplyCatalog.SETTINGS["robot_rewards"][category]))


func _show_hit_confirmation() -> void:
	_hit_flash = 1.0
	audio.on_hit_confirmed()


func _is_visible_hit(hit_position: Vector3) -> bool:
	# Камера подтверждает только то, что внутри кадра и не закрыто рельефом;
	# в оптике попадание также должно быть внутри круглого поля.
	if camera.is_position_behind(hit_position) or not camera.is_position_in_frustum(hit_position):
		return false
	if not Ballistics.terrain_hit(main.coast, camera.global_position, hit_position, 12.0).is_empty():
		return false
	if scope_amount > 0.15:
		var screen := camera.unproject_position(hit_position)
		var viewport_size := get_viewport().get_visible_rect().size
		if screen.distance_to(viewport_size * 0.5) > minf(viewport_size.x, viewport_size.y) * 0.44:
			return false
	return true


func _update_view_model() -> void:
	# Модель и её смещение к камере масштабируются одинаково. При перспективной
	# проекции видимый размер почти не меняется, но у самого края реальная
	# геометрия помещается перед перилами при любом повороте камеры.
	var local_player := main.player.position
	var safe_half := ObservationTower.HALF_DECK - RAIL_CLEARANCE
	var clearance := minf(safe_half - absf(local_player.x), safe_half - absf(local_player.z))
	var model_scale := clampf(clearance / VIEW_MODEL_RADIUS, 0.1, 1.0)
	_view_model.scale = Vector3.ONE * model_scale
	_view_model.position = Vector3(0.28, -0.25, -0.52 + _recoil * 2.0) * model_scale


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
