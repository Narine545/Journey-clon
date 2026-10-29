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


func setup(origin: Vector3, direction: Vector3, speed: float, main: MainScene, owner_rifle: SniperRifle) -> void:
	global_position = origin
	velocity = direction.normalized() * speed
	coast = main.coast
	game = main.game
	rifle = owner_rifle
	gust_phase = randf_range(0.0, TAU)


func _physics_process(delta: float) -> void:
	if coast == null or game == null:
		return
	var start := global_position
	# Полунеявный шаг: изменение скорости от гравитации и порыва ветра.
	velocity += Ballistics.acceleration(game, age, gust_phase) * delta
	var end := start + velocity * delta
	var query := PhysicsRayQueryParameters3D.create(start, end, 2)
	query.collide_with_areas = false
	var body_hit := get_world_3d().direct_space_state.intersect_ray(query)
	var ground_hit := Ballistics.terrain_hit(coast, start, end)
	if not ground_hit.is_empty() and (body_hit.is_empty() or start.distance_squared_to(ground_hit["position"]) <= start.distance_squared_to(body_hit["position"])):
		global_position = ground_hit["position"]
		queue_free()
		return
	if not body_hit.is_empty():
		global_position = body_hit["position"]
		var collider := body_hit.get("collider") as Node
		var target: TargetDummy = collider.get_parent() as TargetDummy if collider != null else null
		if target != null and is_instance_valid(rifle):
			rifle.on_projectile_hit(target, global_position)
		queue_free()
		return
	global_position = end
	age += delta
	if age >= MAX_LIFE:
		queue_free()
