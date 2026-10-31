class_name GrappleHook
extends Node3D
## Игровой прототип: невесомый трос с ограничением длины и сохраняемой
## инерцией игрока. Зацепляются только рельеф и отдельный прокси верхней
## кромки башни. Линия и метка — временная геометрия, не художественный ассет.
const MAX_RANGE := 90.0
const MIN_LENGTH := 1.9
const AUTO_REEL_SPEED := 18.0
const AUTO_ACCELERATION := 55.0
const ARRIVAL_DISTANCE := 0.9
const GROUND_ARRIVAL_DISTANCE := 2.3
const ARRIVAL_MOVE_SPEED := 3.0
const MANUAL_REEL_SPEED := 9.0
const PAY_OUT_SPEED := 7.0
const MAX_PULL_SPEED := 8.0
const ANCHOR_HEIGHT := 1.1

var main: MainScene
var attached := false
var manual_control := false
var arrived := false
var anchor_kind := ""
var launch_stage := 0
var anchor := Vector3.ZERO
var rope_length := 0.0
var pending_toggle := false
var candidate: Dictionary = {}
var _refresh_remaining := 0.0
var rope: MeshInstance3D
var hud: HookHUD


func setup(main_ref: MainScene) -> void:
	main = main_ref
	rope = MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.006
	cylinder.bottom_radius = 0.006
	cylinder.height = 1.0
	cylinder.radial_segments = 6
	rope.mesh = cylinder
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.68, 0.66, 0.52)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rope.material_override = material
	rope.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	rope.visible = false
	add_child(rope)
	var canvas := CanvasLayer.new()
	canvas.layer = 18
	add_child(canvas)
	hud = HookHUD.new()
	hud.hook = self
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(hud)


func _input(event: InputEvent) -> void:
	if not _controls_available():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_G:
			pending_toggle = true
			get_viewport().set_input_as_handled()
		elif event.physical_keycode == KEY_V and attached:
			manual_control = not manual_control
			arrived = false
			rope_length = maxf(MIN_LENGTH, attachment_point().distance_to(anchor))
			get_viewport().set_input_as_handled()


func _physics_process(delta: float) -> void:
	if main == null:
		return
	if pending_toggle:
		pending_toggle = false
		if _controls_available():
			if attached:
				detach()
			else:
				try_attach()
	if main.player_health != null and main.player_health.defeated:
		detach()
	if attached:
		_update_rope()
	elif _controls_available():
		_refresh_remaining -= delta
		if _refresh_remaining <= 0.0:
			_refresh_remaining = 0.16
			candidate = find_anchor()
	else:
		candidate.clear()
	if hud != null:
		hud.queue_redraw()


func _controls_available() -> bool:
	if main == null or main.cam_rig == null or main.player == null:
		return false
	if main.player_health != null and main.player_health.defeated:
		return false
	if main.debug_menu != null and main.debug_menu.is_open:
		return false
	if main.radio_tuner != null and main.radio_tuner.tuning:
		return false
	if main.shop != null and main.shop.is_open:
		return false
	return true


## Луч проверяет ближайшую допустимую цель и настоящие коллизии настила.
## Рельеф — существующая высотная функция, а не дорогая новая сетка физики.
func find_anchor() -> Dictionary:
	main.cam_rig.refresh_pose()
	var origin := main.cam_rig.cam.global_position
	var end := origin - main.cam_rig.cam.global_basis.z * MAX_RANGE
	var ground := Ballistics.terrain_hit(main.coast, origin, end, 2.0)
	var space := get_world_3d().direct_space_state
	var tower_query := PhysicsRayQueryParameters3D.create(origin, end, 32)
	var tower := space.intersect_ray(tower_query)
	var best: Dictionary = {}
	if not ground.is_empty():
		best = {"position": ground["position"], "kind": "ground"}
	if not tower.is_empty() and (best.is_empty() or origin.distance_squared_to(tower["position"]) < origin.distance_squared_to(best["position"])):
		best = {"position": tower["position"], "kind": "tower"}
	if best.is_empty():
		return {}
	# Не зацепиться за землю/башню через пол настила или радиостойку.
	var obstruction_query := PhysicsRayQueryParameters3D.create(origin, best["position"], 8)
	var obstruction := space.intersect_ray(obstruction_query)
	if not obstruction.is_empty() and origin.distance_squared_to(obstruction["position"]) + 0.04 < origin.distance_squared_to(best["position"]):
		return {}
	return best


func try_attach() -> bool:
	var hit := find_anchor()
	if hit.is_empty():
		return false
	anchor = hit["position"]
	anchor_kind = hit["kind"]
	var local := main.player.global_position - main.tower.global_position
	# От старта на площадке сначала поднимаемся над физическими перилами,
	# затем пересекаем край: прямая линия вниз упиралась бы в ограждение.
	launch_stage = 1 if anchor_kind == "ground" and local.y >= ObservationTower.DECK_HEIGHT - 0.1 and local.y < ObservationTower.DECK_HEIGHT + 1.55 and absf(local.x) < 6.0 and absf(local.z) < 6.0 else 0
	manual_control = false
	arrived = false
	rope_length = maxf(MIN_LENGTH, attachment_point().distance_to(anchor))
	attached = true
	main.player.safety_barriers_enabled = false
	main.player.collision_mask = 8
	_update_rope()
	return true


func detach() -> void:
	attached = false
	manual_control = false
	arrived = false
	anchor_kind = ""
	launch_stage = 0
	pending_toggle = false
	candidate.clear()
	if rope != null:
		rope.visible = false


func attachment_point() -> Vector3:
	return main.player.global_position + Vector3.UP * ANCHOR_HEIGHT


## В авторежиме гасим поперечную скорость и ограничиваем скорость сближения
## по тормозному пути. Это не оставляет скорости для кругового вращения у цели.
## В ручном режиме сохраняем старый маятник и отдельное управление длиной.
func constrain_velocity(current: Vector3, delta: float, direction: Vector3 = Vector3.ZERO) -> Vector3:
	if not attached or delta <= 0.0:
		return current
	var offset := anchor - attachment_point()
	var distance := offset.length()
	if manual_control:
		var release := Input.is_action_pressed("rope_release")
		var reel := Input.is_action_pressed("rope_reel")
		var change := PAY_OUT_SPEED if release and not reel else (-MANUAL_REEL_SPEED if reel and not release else 0.0)
		rope_length = clampf(rope_length + change * delta, MIN_LENGTH, MAX_RANGE)
		rope_length = maxf(rope_length, distance - 0.25)
		if distance > 0.001 and distance >= rope_length:
			var outward := -offset / distance
			var radial := current.dot(outward)
			if radial > 0.0:
				current -= outward * radial
			var pull := minf(MAX_PULL_SPEED, maxf(0.0, (distance - rope_length) / delta))
			current -= outward * pull
		return current.limit_length(20.0)
	if launch_stage > 0:
		var local := main.player.global_position - main.tower.global_position
		if launch_stage == 1:
			if local.y < ObservationTower.DECK_HEIGHT + 1.55:
				return current.move_toward(Vector3.UP * 8.0, AUTO_ACCELERATION * delta)
			launch_stage = 2
		if launch_stage == 2:
			if absf(local.x) > 6.65 or absf(local.z) > 6.65:
				launch_stage = 0
			else:
				var outward := Vector3(offset.x, 0.0, offset.z).normalized()
				return current.move_toward(outward * 14.0, AUTO_ACCELERATION * delta)
	if arrived:
		# При подходе трос не включает тягу повторно и не раскручивает игрока.
		# Вблизи якоря можно переступить на настил; дальше ограничиваем только
		# движение от него, не притягивая рывком обратно.
		var movement := Vector3(direction.x * ARRIVAL_MOVE_SPEED, 0.0, direction.z * ARRIVAL_MOVE_SPEED)
		var horizontal_out := Vector3(-offset.x, 0.0, -offset.z)
		if horizontal_out.length() > 3.0:
			var away := horizontal_out.normalized()
			movement -= away * maxf(0.0, movement.dot(away))
		return movement
	var target_distance := GROUND_ARRIVAL_DISTANCE if anchor_kind == "ground" else ARRIVAL_DISTANCE
	if distance <= target_distance + 0.15:
		if anchor_kind == "ground":
			detach()
			return Vector3.ZERO
		arrived = true
		return Vector3.ZERO
	if distance < 0.001:
		return Vector3.ZERO
	# v² = 2*a*s — начинаем тормозить до цели, а не после пролёта.
	var speed := minf(AUTO_REEL_SPEED, sqrt(2.0 * AUTO_ACCELERATION * maxf(0.0, distance - target_distance)))
	var desired := offset / distance * speed
	rope_length = maxf(MIN_LENGTH, distance)
	return current.move_toward(desired, AUTO_ACCELERATION * delta)


func _update_rope() -> void:
	if rope == null or main.cam_rig.cam == null:
		return
	var camera := main.cam_rig.cam
	var start := camera.global_position + camera.global_basis * Vector3(0.18, -0.24, -0.38)
	var span := anchor - start
	if span.length() < 0.01:
		rope.visible = false
		return
	rope.visible = true
	rope.global_position = (start + anchor) * 0.5
	rope.global_basis = Basis(Quaternion(Vector3.UP, span.normalized())).scaled_local(Vector3(1.0, span.length(), 1.0))


class HookHUD extends Control:
	var hook: GrappleHook

	func _draw() -> void:
		if hook == null or hook.main == null or hook.main.player_health.defeated:
			return
		if not hook._controls_available():
			return
		var font := ThemeDB.fallback_font
		var info := "G: КРЮК  ·  НАВЕДИТЕ НА ЗЕМЛЮ ИЛИ ВЕРХ БАШНИ"
		if hook.attached:
			info = "РУЧНОЙ  ·  V: АВТО  ·  Z / X: ТРОС  ·  G: ОТЦЕПИТЬ" if hook.manual_control else "АВТОТЯГА  ·  V: РУЧНОЙ РЕЖИМ  ·  G: ОТЦЕПИТЬ"

		draw_string_outline(font, Vector2(20, size.y - 58), info, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 3, Color(0.03, 0.02, 0.02, 0.9))
		draw_string(font, Vector2(20, size.y - 58), info, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.90, 0.84, 0.68))
		if not hook.attached and not hook.candidate.is_empty():
			draw_arc(size * 0.5, 9.0, 0.0, TAU, 24, Color(0.95, 0.77, 0.42, 0.9), 1.5)
