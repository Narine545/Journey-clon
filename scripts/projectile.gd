class_name RifleProjectile
extends Node3D
## Летящий снаряд: скорость интегрируется каждый физический кадр.
## Пройденный отрезок проверяется на столкновение, чтобы не проскочить
## тонкую мишень при 620 м/с; рельеф проверяется отдельно по карте высот.
const MAX_LIFE := 3.5
var velocity := Vector3.ZERO
var age := 0.0
var gust_phase := 0.0
var coast: Coast
var game: GameState
var rifle: SniperRifle
var pierce := false
var penetrations_remaining := 0
var excluded: Array[RID] = []


func setup(origin: Vector3, direction: Vector3, speed: float, main: MainScene, owner_rifle: SniperRifle, armor_piercing: bool = false) -> void:
	global_position = origin
	velocity = direction.normalized() * speed
	coast = main.coast
	game = main.game
	rifle = owner_rifle
	pierce = armor_piercing
	penetrations_remaining = int(SupplyCatalog.SETTINGS["ap_pierce_limit"]) if pierce else 0
	gust_phase = randf_range(0.0, TAU)


func _physics_process(delta: float) -> void:
	if coast == null or game == null:
		return
	var start := global_position
	# Полунеявный шаг: изменение скорости от гравитации и порыва ветра.
	velocity += Ballistics.acceleration(game, age, gust_phase) * delta
	var end := start + velocity * delta
	# Бронебойный снаряд продолжает тот же физический отрезок за целью;
	# исключения хранятся до конца жизни пули, предотвращая повторные хиты.
	for step in range(int(SupplyCatalog.SETTINGS["ap_pierce_limit"]) + 1):
		var query := PhysicsRayQueryParameters3D.create(start, end, 2)
		query.collide_with_areas = false
		query.exclude = excluded
		var body_hit := get_world_3d().direct_space_state.intersect_ray(query)
		var ground_hit := Ballistics.terrain_hit(coast, start, end)
		if not ground_hit.is_empty() and (body_hit.is_empty() or start.distance_squared_to(ground_hit["position"]) <= start.distance_squared_to(body_hit["position"])):
			global_position = ground_hit["position"]
			queue_free()
			return
		if body_hit.is_empty():
			break
		global_position = body_hit["position"]
		var collider := body_hit.get("collider") as CollisionObject3D
		var target: TargetDummy = collider.get_parent() as TargetDummy if collider != null else null
		if target != null and is_instance_valid(rifle):
			rifle.on_projectile_hit(target, global_position)
		elif collider != null:
			var robot := collider.get_parent() as AmbientRobot
			if robot != null and robot.alive:
				if robot.apply_projectile_hit(pierce):
					if is_instance_valid(rifle):
						rifle.on_robot_hit(robot, global_position)
				elif is_instance_valid(rifle):
					rifle.on_armor_deflect(global_position)
					queue_free()
					return
		if not pierce or penetrations_remaining <= 0 or collider == null:
			queue_free()
			return
		penetrations_remaining -= 1
		excluded.append(collider.get_rid())
		start = global_position + velocity.normalized() * 0.01

	global_position = end
	age += delta
	if age >= MAX_LIFE:
		queue_free()
