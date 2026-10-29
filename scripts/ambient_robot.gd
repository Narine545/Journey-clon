class_name AmbientRobot
extends Node3D
## Три мирных силуэта: обходят участок без преследования игрока.
## Попадание гасит механизм и валит его без звука, наград или эффектов.
enum Kind { SCOUT, CARRIER, WALKER }
const ROAM_RADIUS := 65.0
const PREVIEW_ROAM_RADIUS := 20.0
var kind: Kind
var coast: Coast
var origin: Vector3
var velocity := Vector2.ZERO
var destination := Vector2.ZERO
var alive := true
var preview := false
var age := 0.0
var lifetime := 480.0
var speed := 0.8
var body_size := Vector3.ONE
var visual: Node3D
var hitbox: CollisionShape3D
var rng := RandomNumberGenerator.new()


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
	_build()
	_choose_destination()


func _build() -> void:
	visual = Node3D.new()
	add_child(visual)
	var metal := StandardMaterial3D.new()
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
	var radius := rng.randf_range(8.0, PREVIEW_ROAM_RADIUS if preview else ROAM_RADIUS)
	destination = Vector2(origin.x, origin.z) + Vector2(cos(angle), sin(angle)) * radius


func _physics_process(delta: float) -> void:
	if coast == null:
		return
	age += delta
	if not alive:
		visual.rotation.z = move_toward(visual.rotation.z, PI * 0.5, delta * 0.45)
		return
	var here := Vector2(global_position.x, global_position.z)
	var to_goal := destination - here
	if to_goal.length() < 2.0:
		_choose_destination()
		to_goal = destination - here
	# Плавный разгон, без навигационной сетки и атак; высота всегда по рельефу.
	velocity = velocity.move_toward(to_goal.normalized() * speed, delta * 0.16)
	var next := here + velocity * delta
	global_position = Vector3(next.x, coast.ground_height(next.x, next.y), next.y)
	if velocity.length() > 0.05:
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(velocity.x, velocity.y), minf(1.0, delta * 0.5))


func apply_projectile_hit() -> void:
	if not alive:
		return
	alive = false
	velocity = Vector2.ZERO
	age = 0.0
	hitbox.set_deferred("disabled", true)
