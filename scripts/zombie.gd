class_name SandZombie
extends Node3D
## Zombie De Goma: простой хоррор-противник на аналитическом рельефе.
## Состояния: ожидание → тревога → погоня → атака → урон → смерть.

# glTF уже содержит цепочку 34.27 × 0.01; при прежних 0.20 итоговый рост
# был около 64 см. 0.58 даёт человеческие ~1.87 м.
const MODEL_SCALE := 0.58
const MAX_HEALTH := 3
const NOTICE_DISTANCE := 42.0
const LOSE_DISTANCE := 64.0
const ATTACK_DISTANCE := 1.75
const WALK_SPEED := 1.15
const RUN_SPEED := 3.4

var health := MAX_HEALTH
var dead := false
var player: Player
var terrain: Terrain

var _anim: AnimationPlayer
var _state: StringName = &"idle"
var _state_time := 0.0
var _attack_cooldown := 0.0
var _hurt_time := 0.0
var _action_lock := 0.0
var _attack_hit_pending := false
var _attack_variant := false
var _model: Node3D


func setup(player_ref: Player, terrain_ref: Terrain, spawn_xz: Vector2) -> void:
	player = player_ref
	terrain = terrain_ref
	global_position = Vector3(spawn_xz.x, terrain.ground_height(spawn_xz.x, spawn_xz.y), spawn_xz.y)

	var packed: PackedScene = load("res://assets/zombie_de_goma/scene.gltf")
	if packed == null:
		push_error("ZOMBIE: не найден assets/zombie_de_goma/scene.gltf")
		return
	_model = packed.instantiate()
	add_child(_model)
	_model.scale = Vector3.ONE * MODEL_SCALE
	# Модель смотрит вдоль +Z, а Node3D.look_at ориентирует -Z.
	_model.rotation.y = PI
	_anim = _find_anim(_model)
	_prepare_loops()
	_play(&"idle01")


func _find_anim(root: Node) -> AnimationPlayer:
	if root is AnimationPlayer:
		return root
	for child in root.get_children():
		var found := _find_anim(child)
		if found != null:
			return found
	return null


func _prepare_loops() -> void:
	if _anim == null:
		return
	for clip_name in [&"idle01", &"idle02", &"walk01", &"walk02", &"run"]:
		var clip := _anim.get_animation(clip_name)
		if clip != null:
			clip.loop_mode = Animation.LOOP_LINEAR


func _physics_process(delta: float) -> void:
	if _anim == null or player == null or terrain == null:
		return
	_state_time += delta
	_attack_cooldown = maxf(0.0, _attack_cooldown - delta)
	_hurt_time = maxf(0.0, _hurt_time - delta)
	_action_lock = maxf(0.0, _action_lock - delta)
	if dead:
		return

	var to_player := player.global_position - global_position
	var horizontal := Vector3(to_player.x, 0.0, to_player.z)
	# Атака и damage — одноразовые клипы. Пока они идут, locomotion не имеет
	# права перезаписать AnimationPlayer на run/walk.
	if _state == &"attack" and _action_lock > 0.0:
		_face_player(horizontal, delta)
		if _attack_hit_pending and _action_lock <= 0.82:
			_attack_hit_pending = false
			_apply_attack_hit(horizontal)
		return
	if _hurt_time > 0.0:
		return

	var distance := horizontal.length()

	if distance > LOSE_DISTANCE:
		_set_state(&"idle")
		return
	if distance > NOTICE_DISTANCE and _state == &"idle":
		return
	if _state == &"idle":
		_set_state(&"caution")
		return
	if _state == &"caution" and _state_time < 1.2:
		_face_player(horizontal, delta)
		return
	if distance <= ATTACK_DISTANCE:
		_attack(horizontal)
		return

	_set_state(&"chase")
	_face_player(horizontal, delta)
	var speed := RUN_SPEED if distance < 24.0 else WALK_SPEED
	_play(&"run" if speed == RUN_SPEED else &"walk01")
	var direction := horizontal.normalized()
	global_position += direction * speed * delta
	global_position.y = terrain.ground_height(global_position.x, global_position.z)


func _face_player(horizontal: Vector3, delta: float) -> void:
	if horizontal.length_squared() < 0.001:
		return
	var target_yaw := atan2(-horizontal.x, -horizontal.z)
	rotation.y = lerp_angle(rotation.y, target_yaw, 1.0 - exp(-7.0 * delta))


func _attack(horizontal: Vector3) -> void:
	_face_player(horizontal, 1.0 / 60.0)
	if _attack_cooldown > 0.0:
		return
	_set_state(&"attack")
	_attack_variant = not _attack_variant
	_play(&"attack02" if _attack_variant else &"attack01", true)
	_action_lock = 1.20
	_attack_cooldown = 1.55
	_attack_hit_pending = true


func _apply_attack_hit(horizontal: Vector3) -> void:
	# Урон приходится на замах в анимации, а не на первый кадр. Если игрок
	# успел отступить, удар промахивается.
	if horizontal.length() > ATTACK_DISTANCE + 0.45:
		return
	if horizontal.length_squared() > 0.001:
		player.vel += horizontal.normalized() * 4.5 + Vector3.UP * 1.4


func take_damage(_hit_position: Vector3) -> void:
	if dead:
		return
	health -= 1
	if health <= 0:
		dead = true
		_state = &"dead"
		_play(&"death", true)
		return
	_hurt_time = 0.75
	_set_state(&"hurt")
	_play(&"damage", true)


## Пересечение луча с вертикальной капсулой, достаточно точное для FPS.
## Возвращает дистанцию или -1.
func ray_hit_distance(origin: Vector3, direction: Vector3, max_distance: float) -> float:
	if dead and _state_time > 3.0:
		return -1.0
	var center := global_position + Vector3(0.0, 1.02, 0.0)
	var radius := 0.72
	var oc := origin - center
	var b := oc.dot(direction)
	var c := oc.length_squared() - radius * radius
	var discriminant := b * b - c
	if discriminant < 0.0:
		return -1.0
	var t := -b - sqrt(discriminant)
	if t < 0.0:
		t = -b + sqrt(discriminant)
	return t if t >= 0.0 and t <= max_distance else -1.0


func _set_state(next: StringName) -> void:
	if _state == next:
		return
	_state = next
	_state_time = 0.0
	match next:
		&"idle": _play(&"idle02")
		&"caution": _play(&"caution", true)


func _play(clip_name: StringName, restart := false) -> void:
	if _anim == null or not _anim.has_animation(clip_name):
		return
	if restart or _anim.current_animation != clip_name or not _anim.is_playing():
		_anim.play(clip_name, 0.16)
