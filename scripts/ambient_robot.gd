class_name AmbientRobot
extends Node3D
## Три силуэта: вызванные роботы подходят и поднимаются по опорам башни.
## Поднявшиеся роботы преследуют игрока и предупреждают перед ударом.
enum Kind { SCOUT, CARRIER, WALKER }
enum ClimbState { NONE, TO_SUPPORT, CLIMBING, AT_TOP }
const SUPPORT_COORD := 4.8 # реальные четыре опоры пользовательской GLB-башни
const BASE_CLIMB_SPEED := 2.2
const FALL_GRAVITY := 20.0
const DECK_SPEED := 1.15
const ATTACK_WINDUP := 2.0
const ATTACK_COOLDOWN := 3.5
const ATTACK_DAMAGE := 15
const ARM_REACH := 2.4 # дополнительный вылет телескопического привода
const ROAM_RADIUS := 65.0
const PREVIEW_ROAM_RADIUS := 20.0
var kind: Kind
var coast: Coast
var origin: Vector3
var velocity := Vector2.ZERO
var destination := Vector2.ZERO
var alive := true
var _reward_claimed := false
var preview := false
var call_slot := -1
var signal_called := false
var approaching_signal := false
var age := 0.0
var lifetime := 480.0
var speed := 0.8
var signal_fast := false
var climb_state := ClimbState.NONE
var climb_speed := BASE_CLIMB_SPEED
var signal_tower := Vector3.ZERO
var support_target := Vector2.ZERO
var falling := false
var fall_speed := 0.0
var body_size := Vector3.ONE
var visual: Node3D
var hitbox: CollisionShape3D
var rng := RandomNumberGenerator.new()
var player_ref: TowerPlayer
var health_ref: PlayerHealth
var attack_windup := 0.0
var attack_cooldown := 0.0
var metal: StandardMaterial3D
var attack_arm: MeshInstance3D
var attack_beacon: MeshInstance3D


func setup(robot_kind: Kind, coast_ref: Coast, at: Vector3, seed_value: int) -> void:
	kind = robot_kind
	coast = coast_ref
	origin = at
	global_position = at
	rng.seed = seed_value
	lifetime = rng.randf_range(300.0, 600.0)
	match kind:
		Kind.SCOUT:
			body_size = Vector3(3.0, 4.8, 3.0)
			speed = 1.05
		Kind.CARRIER:
			body_size = Vector3(6.2, 4.4, 4.8)
			speed = 0.42
		Kind.WALKER:
			body_size = Vector3(4.5, 5.6, 3.0)
			speed = 0.72
	global_position.y = support_height(global_position.x, global_position.z)
	origin = global_position
	_build()
	_choose_destination()


## Девять проб под опорой; диагональ даёт запас при повороте силуэта.
## Это не навигация по препятствиям, но уменьшает проваливание ног в дюну.
func support_height(x: float, z: float) -> float:
	var radius := Vector2(body_size.x, body_size.z).length() * 0.5
	var height := coast.ground_height(x, z)
	for dx in [-radius, 0.0, radius]:
		for dz in [-radius, 0.0, radius]:
			height = maxf(height, coast.ground_height(x + dx, z + dz))
	return height + 0.03


func _build() -> void:
	visual = Node3D.new()
	add_child(visual)
	metal = StandardMaterial3D.new()
	metal.albedo_color = Color(0.22, 0.19, 0.16)
	metal.metallic = 0.35
	metal.roughness = 0.94
	# Как и у дальней учебной мишени M3: тонкий силуэт не исчезает в тумане.
	metal.disable_fog = true
	var s := body_size
	match kind:
		Kind.SCOUT:
			_box(Vector3(0, s.y * 0.62, 0), Vector3(s.x, s.y * 0.52, s.z), metal)
			_box(Vector3(0, s.y * 0.94, 0), Vector3(s.x * 0.45, s.y * 0.20, s.z * 0.55), metal)
			for side in [-1.0, 1.0]:
				_box(Vector3(side * s.x * 0.34, s.y * 0.18, 0), Vector3(0.45, s.y * 0.36, 0.5), metal)
		Kind.CARRIER:
			_box(Vector3(0, s.y * 0.55, 0), Vector3(s.x, s.y * 0.55, s.z), metal)
			_box(Vector3(0, s.y * 0.88, 0), Vector3(s.x * 0.52, s.y * 0.16, s.z * 0.65), metal)
			for side in [-1.0, 1.0]:
				_box(Vector3(side * s.x * 0.36, s.y * 0.15, 0), Vector3(1.0, s.y * 0.30, s.z * 0.7), metal)
		Kind.WALKER:
			_box(Vector3(0, s.y * 0.7, 0), Vector3(s.x, s.y * 0.34, s.z), metal)
			_box(Vector3(0, s.y * 0.92, 0), Vector3(s.x * 0.35, s.y * 0.15, s.z * 0.55), metal)
			for side in [-1.0, 1.0]:
				for depth in [-0.3, 0.3]:
					_box(Vector3(side * s.x * 0.38, s.y * 0.28, s.z * depth), Vector3(0.42, s.y * 0.56, 0.45), metal)
	# Простой выдвижной привод показывает направление и дальность удара.
	attack_arm = MeshInstance3D.new()
	var arm_mesh := BoxMesh.new()
	arm_mesh.size = Vector3(0.28, 0.28, ARM_REACH)
	attack_arm.mesh = arm_mesh
	attack_arm.material_override = metal
	attack_arm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	attack_arm.visible = false
	visual.add_child(attack_arm)
	attack_beacon = MeshInstance3D.new()
	var lamp_mesh := SphereMesh.new()
	lamp_mesh.radius = 0.18
	lamp_mesh.height = 0.36
	attack_beacon.mesh = lamp_mesh
	attack_beacon.position = Vector3(0, s.y + 0.15, 0)
	var lamp_material := StandardMaterial3D.new()
	lamp_material.albedo_color = Color(1.0, 0.35, 0.04)
	lamp_material.emission_enabled = true
	lamp_material.emission = Color(1.0, 0.20, 0.015)
	lamp_material.emission_energy_multiplier = 1.5
	attack_beacon.material_override = lamp_material
	attack_beacon.visible = false
	visual.add_child(attack_beacon)
	var body := StaticBody3D.new()
	body.name = "Hitbox"
	body.collision_layer = 2
	body.collision_mask = 0
	add_child(body)
	hitbox = CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = body_size
	hitbox.shape = shape
	hitbox.position.y = body_size.y * 0.5
	body.add_child(hitbox)


func _box(at: Vector3, dimensions: Vector3, material: Material) -> void:
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material
	mesh_instance.position = at
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visual.add_child(mesh_instance)


func _choose_destination() -> void:
	var angle := rng.randf_range(0.0, TAU)
	var radius := rng.randf_range(8.0, PREVIEW_ROAM_RADIUS if preview or signal_called else ROAM_RADIUS)
	destination = Vector2(origin.x, origin.z) + Vector2(cos(angle), sin(angle)) * radius


## Быстрота назначается один раз при появлении: уже видимый робот не меняет
## скорость внезапно, в том числе при выключении маяка.
func configure_signal_speed(pressure: float, roll: float) -> void:
	var level := clampf(pressure, 0.0, 1.0)
	signal_fast = roll < lerpf(0.10, 0.60, level)
	if signal_fast:
		var boost := lerpf(1.15, 1.65, level)
		speed *= boost
		climb_speed *= boost


## Зовущие роботы идут к подножию, а не к самому центру башни.
func respond_to_signal(tower_position: Vector3, slot: int) -> void:
	call_slot = slot
	signal_called = true
	approaching_signal = true
	signal_tower = tower_position
	var tower_2d := Vector2(tower_position.x, tower_position.z)
	var from_tower := Vector2(global_position.x, global_position.z) - tower_2d
	if from_tower.is_zero_approx():
		from_tower = Vector2.RIGHT
	destination = tower_2d + from_tower.normalized() * 18.0
	# Ближайший угловой столб; центр объёмного робота снаружи, чтобы
	# его силуэт не проходил насквозь через опору. Настоящей IK-анимации нет.
	var corner := Vector2(SUPPORT_COORD if from_tower.x >= 0.0 else -SUPPORT_COORD, SUPPORT_COORD if from_tower.y >= 0.0 else -SUPPORT_COORD)
	var body_radius := Vector2(body_size.x, body_size.z).length() * 0.5
	support_target = tower_2d + corner + corner.normalized() * (body_radius + 0.35)
	climb_state = ClimbState.NONE


func _physics_process(delta: float) -> void:
	if coast == null:
		return
	age += delta
	if not alive:
		visual.rotation.z = move_toward(visual.rotation.z, PI * 0.5, delta * 0.45)
		if falling:
			# Выведенная из строя машина не зависает в воздухе.
			fall_speed += FALL_GRAVITY * delta
			var floor_y := support_height(global_position.x, global_position.z)
			var next_y := global_position.y - fall_speed * delta
			if next_y <= floor_y:
				global_position.y = floor_y
				falling = false
			else:
				global_position.y = next_y
		return
	if climb_state == ClimbState.CLIMBING:
		global_position.y = move_toward(global_position.y, signal_tower.y + ObservationTower.DECK_HEIGHT, climb_speed * delta)
		if global_position.y >= signal_tower.y + ObservationTower.DECK_HEIGHT:
			climb_state = ClimbState.AT_TOP
		return
	if climb_state == ClimbState.AT_TOP:
		_advance_deck(delta)
		return
	var here := Vector2(global_position.x, global_position.z)
	if climb_state == ClimbState.TO_SUPPORT:
		# На последних метрах плавно подходим к точке, не перескакивая её
		# при низком FPS или ускоренном тесте.
		var next_support := here.move_toward(support_target, speed * delta)
		var support_motion := next_support - here
		if support_motion.length_squared() > 0.001:
			visual.rotation.y = lerp_angle(visual.rotation.y, atan2(support_motion.x, support_motion.y), minf(1.0, delta * 0.5))
		global_position = Vector3(next_support.x, support_height(next_support.x, next_support.y), next_support.y)
		if next_support.distance_squared_to(support_target) < 0.001:
			velocity = Vector2.ZERO
			climb_state = ClimbState.CLIMBING
		return
	var to_goal := destination - here
	if to_goal.length() < 2.0:
		if approaching_signal:
			approaching_signal = false
			age = 0.0
			origin = global_position
			climb_state = ClimbState.TO_SUPPORT
			return
		_choose_destination()
		to_goal = destination - here
	# Плавный разгон, без навигационной сетки и атак; высота всегда по рельефу.
	velocity = velocity.move_toward(to_goal.normalized() * speed, delta * 0.16)
	var next := here + velocity * delta
	global_position = Vector3(next.x, support_height(next.x, next.y), next.y)
	if velocity.length() > 0.05:
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(velocity.x, velocity.y), minf(1.0, delta * 0.5))


## На площадке нет навигационной сетки: робот направляется к игроку и
## останавливается на расстоянии своего корпуса, не проходя сквозь камеру.
func _advance_deck(delta: float) -> void:
	if player_ref == null or health_ref == null or health_ref.defeated:
		_set_warning(false)
		attack_windup = 0.0
		return
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	var here := Vector2(global_position.x, global_position.z)
	var target := Vector2(player_ref.global_position.x, player_ref.global_position.z)
	var difference := target - here
	var distance := difference.length()
	# Диагональ корпуса безопасна при его произвольном повороте.
	var reach := Vector2(body_size.x, body_size.z).length() * 0.5 + ARM_REACH
	var in_height := absf(player_ref.global_position.y - global_position.y) <= 3.0
	if distance > reach + 0.08 or not in_height:
		attack_windup = 0.0
		_set_warning(false)
		if distance > reach:
			var step := minf(DECK_SPEED * delta, distance - reach)
			var next := here + difference.normalized() * step
			global_position.x = next.x
			global_position.z = next.y
		if distance > 0.01:
			visual.rotation.y = lerp_angle(visual.rotation.y, atan2(difference.x, difference.y), minf(1.0, delta * 2.0))
		return
	if distance > 0.01:
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(difference.x, difference.y), minf(1.0, delta * 3.0))
	if attack_windup > 0.0:
		attack_windup = maxf(0.0, attack_windup - delta)
		_set_arm_extension(1.0 - attack_windup / ATTACK_WINDUP)
		if attack_windup <= 0.0:
			_set_warning(false)
			health_ref.take_damage(ATTACK_DAMAGE)
			attack_cooldown = ATTACK_COOLDOWN
	elif attack_cooldown <= 0.0:
		attack_windup = ATTACK_WINDUP
		_set_warning(true)
		health_ref.warn_attack(ATTACK_WINDUP)


func _set_warning(active: bool) -> void:
	if attack_arm != null:
		attack_arm.visible = active
	if attack_beacon != null:
		attack_beacon.visible = active
	if metal != null:
		metal.emission_enabled = active
		if active:
			metal.emission = Color(0.18, 0.045, 0.008)
			metal.emission_energy_multiplier = 0.7
			_set_arm_extension(0.05)


func _set_arm_extension(amount: float) -> void:
	if attack_arm == null:
		return
	var extension := clampf(amount, 0.05, 1.0)
	attack_arm.scale.z = extension
	attack_arm.position = Vector3(0, body_size.y * 0.55, body_size.z * 0.5 + ARM_REACH * extension * 0.5)


func apply_projectile_hit(pierce: bool = false) -> bool:
	if not alive or (kind == Kind.CARRIER and not pierce):
		return false
	alive = false
	approaching_signal = false
	falling = climb_state == ClimbState.CLIMBING or climb_state == ClimbState.AT_TOP
	# На самом настиле корпус остаётся на площадке, снаружи — падает на песок.
	if climb_state == ClimbState.AT_TOP:
		var local_x := absf(global_position.x - signal_tower.x)
		var local_z := absf(global_position.z - signal_tower.z)
		if local_x <= ObservationTower.HALF_DECK and local_z <= ObservationTower.HALF_DECK:
			falling = false
	attack_windup = 0.0
	_set_warning(false)
	fall_speed = 0.0
	climb_state = ClimbState.NONE
	velocity = Vector2.ZERO
	age = 0.0
	hitbox.set_deferred("disabled", true)
	return true


func claim_reward() -> bool:
	if _reward_claimed:
		return false
	_reward_claimed = true
	return true
