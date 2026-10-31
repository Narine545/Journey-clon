class_name SniperRifle
extends Node3D
## Пятизарядная винтовка: короткий цикл между выстрелами и отдельная перезарядка;
## снаряд существует в мире, а очки выдаются только за видимое камерой попадание.
signal impact_confirmed(target: TargetDummy)
signal robot_impact_confirmed(robot: AmbientRobot)
signal reward_confirmed(amount: int)
enum Weapon { RIFLE, PISTOL }

const MUZZLE_SPEED: float = SupplyCatalog.SETTINGS["muzzle_speed"]
const CYCLE_TIME: float = SupplyCatalog.SETTINGS["bolt_seconds"]
const RELOAD_TIME: float = SupplyCatalog.SETTINGS["reload_seconds"]
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
var weapon := Weapon.RIFLE
var pistol_ammo: int = SupplyCatalog.SETTINGS["pistol_capacity"]
var infinite_ammo := false
var debug_ammo_type := "regular"
var regular_reserve: int = SupplyCatalog.SETTINGS["start_regular_reserve"]
var ap_reserve: int = SupplyCatalog.SETTINGS["start_ap_reserve"]
var ammo_type := "regular"
var zoom_multiplier := 1.0
var sway_multiplier := 1.0
var _deflect_flash := 0.0
var cycle_remaining := 0.0
var reload_remaining := 0.0
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
var _pistol_view_model: Node3D


func setup(main_ref: MainScene) -> void:
	main = main_ref
	cam_rig = main.cam_rig
	camera = cam_rig.cam
	audio = main.audio
	_build_view_model()
	_build_pistol_view_model()
	hud = ScopeHUD.new()
	add_child(hud)


func _input(event: InputEvent) -> void:
	if main != null and main.player_health != null and main.player_health.defeated:
		return
	if main != null and main.debug_menu != null and main.debug_menu.is_open:
		return
	if main != null and main.radio_tuner != null and main.radio_tuner.tuning:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_E:
			if main.lift != null and main.lift.try_collect_from_camera():
				get_viewport().set_input_as_handled()
				return
		elif event.physical_keycode == KEY_1:
			select_weapon(Weapon.RIFLE)
			get_viewport().set_input_as_handled()
			return
		elif event.physical_keycode == KEY_2:
			select_weapon(Weapon.PISTOL)
			get_viewport().set_input_as_handled()
			return
		elif event.physical_keycode == KEY_R:
			start_reload()
			get_viewport().set_input_as_handled()
			return
		elif event.physical_keycode == KEY_TAB:
			switch_ammo()
			get_viewport().set_input_as_handled()
			return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			aim_requested = event.pressed and weapon == Weapon.RIFLE and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
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
		if not _cycle_bolt_played and cycle_remaining <= CYCLE_TIME * 0.5:
			_cycle_bolt_played = true
			if weapon == Weapon.RIFLE:
				audio.on_bolt()
	if reload_remaining > 0.0:
		reload_remaining = maxf(0.0, reload_remaining - delta)
		if reload_remaining <= 0.0:
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
	_view_model.visible = weapon == Weapon.RIFLE and scope_amount < 0.45
	_pistol_view_model.visible = weapon == Weapon.PISTOL
	_update_view_model()
	crosswind = Ballistics.wind_velocity(main.game).dot(camera.global_basis.x)
	_range_clock -= delta
	if scope_amount > 0.5 and _range_clock <= 0.0:
		_range_clock = 0.2
		range_m = measure_range()
	hud.update_state(scope_amount, current_ammo(), can_fire(), range_m, crosswind, _hit_flash, _deflect_flash, selected_ammo_type(), regular_reserve, ap_reserve, Economy.points, main.lift.status_text() if main.lift != null else "", reload_remaining > 0.0, delta, magazine_capacity(), infinite_ammo, weapon == Weapon.PISTOL)


func current_ammo() -> int:
	return pistol_ammo if weapon == Weapon.PISTOL else ammo


func magazine_capacity() -> int:
	return int(SupplyCatalog.SETTINGS["pistol_capacity"]) if weapon == Weapon.PISTOL else int(SupplyCatalog.SETTINGS["magazine_capacity"])


func selected_ammo_type() -> String:
	if weapon == Weapon.PISTOL:
		return "regular"
	return debug_ammo_type if infinite_ammo else ammo_type


func set_infinite_ammo(value: bool) -> void:
	if value == infinite_ammo:
		return
	if value:
		# Настоящие магазины и резервы остаются нетронутыми; AP можно испытать
		# даже с нулевым запасом, отдельно от сохранённого выбора патронов.
		debug_ammo_type = ammo_type
		reload_remaining = 0.0
	infinite_ammo = value


func select_weapon(next_weapon: Weapon) -> void:
	if next_weapon == weapon:
		return
	weapon = next_weapon
	reload_remaining = 0.0 # незавершённая перезарядка не расходует запас
	aim_requested = false
	scope_amount = 0.0
	cam_rig.aim_offset = Vector2.ZERO
	if not infinite_ammo and current_ammo() == 0:
		start_reload()


func can_fire() -> bool:
	if main != null and main.player_health != null and main.player_health.defeated:
		return false
	return (infinite_ammo or current_ammo() > 0) and cycle_remaining <= 0.0 and reload_remaining <= 0.0


func fire() -> bool:
	if not can_fire():
		return false
	cam_rig.refresh_pose()
	var direction := -camera.global_basis.z
	var projectile := RifleProjectile.new()
	projectile.name = "Projectile"
	main.add_child(projectile)
	var pistol := weapon == Weapon.PISTOL
	var muzzle := float(SupplyCatalog.SETTINGS["pistol_muzzle_speed"]) if pistol else MUZZLE_SPEED
	projectile.setup(camera.global_position, direction, muzzle, main, self, not pistol and selected_ammo_type() == "ap")
	if not infinite_ammo:
		if pistol:
			pistol_ammo -= 1
		else:
			ammo -= 1
	cycle_remaining = float(SupplyCatalog.SETTINGS["pistol_cycle_seconds"]) if pistol else CYCLE_TIME
	_cycle_bolt_played = false
	_recoil = 0.010 if pistol else 0.018
	if pistol:
		audio.on_pistol_shot()
	else:
		audio.on_rifle_shot()
	if not infinite_ammo and current_ammo() == 0:
		start_reload()
	return true


func start_reload() -> bool:
	if infinite_ammo:
		return false
	var available := regular_reserve if weapon == Weapon.PISTOL or ammo_type == "regular" else ap_reserve
	if reload_remaining > 0.0 or current_ammo() >= magazine_capacity() or available <= 0:
		return false
	reload_remaining = float(SupplyCatalog.SETTINGS["pistol_reload_seconds"]) if weapon == Weapon.PISTOL else RELOAD_TIME
	audio.on_bolt()
	return true


func switch_ammo() -> void:
	if weapon == Weapon.PISTOL:
		return # пистолет всегда использует только обычные патроны
	if infinite_ammo:
		debug_ammo_type = "ap" if debug_ammo_type == "regular" else "regular"
		hud.notify_ammo_type(debug_ammo_type, 1)
		return
	reload_remaining = 0.0
	if ammo_type == "regular":
		regular_reserve += ammo
		ammo_type = "ap"
	else:
		ap_reserve += ammo
		ammo_type = "regular"
	ammo = 0
	_reload_selected()
	hud.notify_ammo_type(ammo_type, ammo)


func _reload_selected() -> void:
	if infinite_ammo:
		return
	if weapon == Weapon.PISTOL:
		var pistol_loaded := mini(magazine_capacity() - pistol_ammo, regular_reserve)
		pistol_ammo += pistol_loaded
		regular_reserve -= pistol_loaded
		return
	var capacity: int = SupplyCatalog.SETTINGS["magazine_capacity"]
	var available := regular_reserve if ammo_type == "regular" else ap_reserve
	var loaded := mini(capacity - ammo, available)
	ammo += loaded
	if ammo_type == "regular":
		regular_reserve -= loaded
	else:
		ap_reserve -= loaded


## Слот для сигнала доставки: источник не знает о винтовке напрямую.
func apply_delivery(item_id: String, effect: Dictionary) -> void:
	regular_reserve += int(effect.get("regular_ammo", 0))
	ap_reserve += int(effect.get("ap_ammo", 0))
	if effect.has("zoom_multiplier"):
		zoom_multiplier = float(effect["zoom_multiplier"])
	if effect.has("sway_multiplier"):
		sway_multiplier = float(effect["sway_multiplier"])
	if current_ammo() == 0:
		start_reload()
	if item_id == "stability":
		(_view_model.get_node("Stabilizer") as Node3D).visible = true
	if item_id == "scope":
		(_view_model.get_node("ScopeUpgrade") as Node3D).visible = true


func on_delivery_collected(items: Dictionary) -> void:
	hud.notify_batch(items)


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
	var local_player := camera.global_position - main.tower.global_position
	var safe_half := ObservationTower.HALF_DECK - RAIL_CLEARANCE
	var clearance := minf(safe_half - absf(local_player.x), safe_half - absf(local_player.z))
	var on_deck := local_player.y >= ObservationTower.DECK_HEIGHT and absf(local_player.x) <= ObservationTower.WALK_LIMIT and absf(local_player.z) <= ObservationTower.WALK_LIMIT
	var model_scale := clampf(clearance / VIEW_MODEL_RADIUS, 0.1, 1.0) if on_deck else 1.0
	_view_model.scale = Vector3.ONE * model_scale
	var reload_drop := 0.10 * sin(PI * (1.0 - reload_remaining / RELOAD_TIME)) if reload_remaining > 0.0 else 0.0
	_view_model.position = Vector3(0.28, -0.25 - reload_drop, -0.52 + _recoil * 2.0) * model_scale
	_pistol_view_model.scale = Vector3.ONE * model_scale
	_pistol_view_model.position = Vector3(0.25, -0.27 - reload_drop, -0.42 + _recoil * 2.0) * model_scale


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
	_box("Magazine", Vector3(0, -0.10, -0.24), Vector3(0.09, 0.10, 0.13), metal)
	_box("Barrel", Vector3(0, 0.015, -0.62), Vector3(0.045, 0.045, 0.65), metal)
	_box("Scope", Vector3(0, 0.13, -0.23), Vector3(0.105, 0.095, 0.32), metal)
	_box("ScopeMount", Vector3(0, 0.075, -0.23), Vector3(0.06, 0.08, 0.12), metal)
	_box("Bolt", Vector3(0.09, 0.0, -0.10), Vector3(0.06, 0.035, 0.035), metal)
	var accent := StandardMaterial3D.new()
	accent.albedo_color = Color(0.54, 0.42, 0.21)
	accent.metallic = 0.55
	_box("Stabilizer", Vector3(-0.07, -0.025, -0.25), Vector3(0.025, 0.045, 0.18), accent)
	_box("ScopeUpgrade", Vector3(0, 0.13, -0.38), Vector3(0.12, 0.11, 0.04), accent)
	(_view_model.get_node("Stabilizer") as Node3D).visible = false
	(_view_model.get_node("ScopeUpgrade") as Node3D).visible = false


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


func _build_pistol_view_model() -> void:
	# Временный силуэт вместо авторской модели и анимации.
	_pistol_view_model = Node3D.new()
	_pistol_view_model.name = "PistolPlaceholder"
	add_child(_pistol_view_model)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.12, 0.13, 0.12)
	material.metallic = 0.45
	material.roughness = 0.85
	for piece in [
		{"at": Vector3(0, 0, -0.10), "size": Vector3(0.10, 0.10, 0.30)},
		{"at": Vector3(0, -0.09, 0.0), "size": Vector3(0.09, 0.18, 0.10)},
	]:
		var part := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = piece["size"]
		part.mesh = mesh
		part.position = piece["at"]
		part.material_override = material
		part.layers = 2
		part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_pistol_view_model.add_child(part)
	_pistol_view_model.visible = false
