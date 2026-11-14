class_name TideFx
extends RefCounted
## Моушн-кит «TIDECUT»: брызги, overshoot, hit-stop, качка, тряска.
##
## Все пружины идут через TRANS_BACK / EASE_OUT — LINEAR на появлениях
## запрещён арт-дирекцией, поэтому здесь его нет вообще.

const RNG_SEED := 20261114
static var _rng := RandomNumberGenerator.new()


static func rng() -> RandomNumberGenerator:
	if _rng.seed == 0:
		_rng.seed = RNG_SEED
	return _rng


## Появление с overshoot: scale 0.5→1 и поворот от −10° к финальному.
static func pop_in(target: Control, from_scale: float = 0.5, from_deg: float = -10.0) -> void:
	if target == null or not target.is_inside_tree():
		return
	var final_rotation := target.rotation
	var final_scale := target.scale
	target.rotation = final_rotation + deg_to_rad(from_deg)
	target.scale = final_scale * from_scale
	target.modulate.a = 0.0
	var tween := target.create_tween()
	tween.set_parallel(true)
	tween.tween_property(target, "scale", final_scale, TideTokens.IN_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(target, "rotation", final_rotation, TideTokens.IN_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(target, "modulate:a", 1.0, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## Влёт сверху/сбоку: смещение + overshoot, без прозрачных «плывунов».
static func slide_in(target: Control, from: Vector2, duration: float = TideTokens.IN_TIME) -> void:
	if target == null or not target.is_inside_tree():
		return
	var final_position := target.position
	target.position = final_position + from
	var tween := target.create_tween()
	tween.tween_property(target, "position", final_position, duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Нажатие: 0.93 на 0.06 с и отскок TRANS_BACK.
static func press(target: Control) -> void:
	if target == null or not target.is_inside_tree():
		return
	var base := target.scale
	var tween := target.create_tween()
	tween.tween_property(target, "scale", base * 0.93, TideTokens.PRESS_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(target, "scale", base, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Тряска 4–6 px на 0.12 с — «получил удар».
static func shake(target: Control, pixels: float = 5.0, duration: float = 0.12) -> void:
	if target == null or not target.is_inside_tree():
		return
	var base := target.position
	var generator := rng()
	var tween := target.create_tween()
	var steps := maxi(2, int(duration / 0.02))
	for step in steps:
		var fade := 1.0 - float(step) / float(steps)
		var offset := Vector2(
			generator.randf_range(-pixels, pixels), generator.randf_range(-pixels, pixels)
		) * fade
		tween.tween_property(target, "position", base + offset, duration / float(steps))
	tween.tween_property(target, "position", base, duration / float(steps))


## Брызги: 8–16 белых пенных капель, жизнь 0.3–0.5 с.
static func splash(parent: Node, at: Vector2, count: int = 12, color: Color = TideTokens.FOAM) -> CPUParticles2D:
	var particles := _particles(parent, at, color, count, 0.42)
	particles.direction = Vector2.UP
	particles.spread = 62.0
	particles.initial_velocity_min = 90.0
	particles.initial_velocity_max = 320.0
	particles.gravity = Vector2(0.0, 760.0)
	particles.scale_amount_min = 2.0
	particles.scale_amount_max = 6.0
	return particles


## Искры цепи: сонарь, узкий конус, короткая жизнь.
static func sparks(parent: Node, at: Vector2, count: int = 10) -> CPUParticles2D:
	var particles := _particles(parent, at, TideTokens.SONAR, count, 0.34)
	particles.direction = Vector2.UP
	particles.spread = 180.0
	particles.initial_velocity_min = 60.0
	particles.initial_velocity_max = 240.0
	particles.gravity = Vector2(0.0, 180.0)
	particles.scale_amount_min = 1.5
	particles.scale_amount_max = 4.0
	return particles


static func _particles(
	parent: Node, at: Vector2, color: Color, count: int, life: float
) -> CPUParticles2D:
	var particles := CPUParticles2D.new()
	particles.amount = maxi(4, count)
	particles.lifetime = life
	particles.one_shot = true
	particles.explosiveness = 0.95
	particles.emitting = true
	particles.position = at
	particles.color = color
	particles.direction = Vector2.UP
	particles.gravity = Vector2(0.0, 620.0)
	particles.angular_velocity_min = -240.0
	particles.angular_velocity_max = 240.0
	particles.damping_min = 20.0
	particles.damping_max = 90.0
	# Плоские квадратные капли: без размытых спрайтов и без картинок.
	var gradient := Gradient.new()
	gradient.set_color(0, Color(color, 1.0))
	gradient.set_color(1, Color(color, 0.0))
	particles.color_ramp = gradient
	particles.finished.connect(particles.queue_free)
	# Родитель может быть занят (скрытие экрана, сборка детей) — тогда прямой
	# add_child падает с ошибкой, поэтому узел добавляется отложенно.
	parent.add_child.call_deferred(particles)
	return particles


## Hit-stop: кадр замирает на 0.08 с. Экран сам ждёт таймер с
## ignore_time_scale, потому что при остановленном мире обычные таймеры стоят.
static func freeze() -> void:
	Engine.time_scale = 0.0


static func unfreeze() -> void:
	Engine.time_scale = 1.0


## Качка: синус, период 2.4–3.2 с, амплитуда 0.5–1.2°, своя фаза.
static func bob(target: Control, base_deg: float, amplitude_deg: float, period: float, phase: float) -> TideBob:
	var node := TideBob.new()
	node.setup(target, base_deg, amplitude_deg, period, phase)
	return node
