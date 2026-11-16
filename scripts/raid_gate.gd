class_name RaidGate
extends Node3D
## Сфера из другого мира: случайная точка в океане, где начинается рейд.
## Подойти на RANGE метров и нажать E. После рейда сфера гаснет и всплывает
## в новом месте; за победу в рейде в трюм ложится артефакт.

const RANGE := 18.0
const MIN_DEPTH := 8.0
## Открытый океан к западу от острова (карта Coast: x −280…620, край 64 м).
const AREA := Rect2(-208.0, -330.0, 96.0, 660.0)
const FALLBACK := Vector2(-185.0, 95.0)
## Радиус сферы в метрах (модель вписана в 4.2 м).
const ORB_RADIUS := 2.1
## Глубина погружения перед взлётом: сфера сперва уходит под воду.
const DIVE_DEPTH := 8.0

var main: BoatMain
var artifacts := 0
## Номера уже найденных вещей (см. ArtifactModel.ITEMS).
var found: Array[int] = []
var _pending := -1
var _last_state := RaidRun.State.IDLE
var _launching := false
var _lift := 0.0
var _shrink := 1.0
var _spin := 0.0
var _flare := 0.0
var _fly: Tween
var _model: Node3D
var _light: OmniLight3D
var _time := 0.0
var _was_engaged := false
var _won := false
var _rng := RandomNumberGenerator.new()
# Отклик воды: брызги, кольца и свечение сквозь толщу.
var _spray: CPUParticles3D
var _foam: CPUParticles3D
var _glow_light: OmniLight3D
var _glow_disc: MeshInstance3D
var _glow_mat: ShaderMaterial
var _under := false
var _glow := 0.0
var _ring := 0.0
var _ring_alpha := 0.0
var _surface := 0.0


func setup(scene: BoatMain) -> void:
	main = scene
	_rng.randomize()
	_model = ArtifactModel.build(ArtifactModel.ORB, 4.2)
	add_child(_model)
	_light = OmniLight3D.new()
	_light.light_color = Color("35d0ba")
	_light.light_energy = 3.0
	_light.omni_range = 22.0
	_light.position = Vector3(0.0, 3.0, 0.0)
	add_child(_light)
	_build_water_fx()
	# У модели сферы своя анимация вращения колец — крутим её по кругу.
	var player := _model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if player != null:
		for clip in player.get_animation_list():
			if clip == "RESET":
				continue
			player.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
			player.play(clip)
			break
	relocate()


func at() -> Vector2:
	return Vector2(position.x, position.z)


func distance() -> float:
	if main == null or main.boat == null:
		return INF
	return at().distance_to(Vector2(main.boat.global_position.x, main.boat.global_position.z))


func in_range() -> bool:
	return visible and not _launching and distance() <= RANGE


## Новое случайное место: глубокая вода вокруг, не у старта и не у буёв.
func relocate() -> void:
	var spot := FALLBACK
	var avoid := Vector2(IslandLayout.BOAT_START)
	if main != null and main.boat != null and _was_engaged:
		avoid = Vector2(main.boat.global_position.x, main.boat.global_position.z)
	for attempt in range(60):
		var candidate := Vector2(
			_rng.randf_range(AREA.position.x, AREA.end.x), _rng.randf_range(AREA.position.y, AREA.end.y)
		)
		if candidate.distance_to(avoid) < 90.0:
			continue
		if _clear(candidate):
			spot = candidate
			break
	position = Vector3(spot.x, 0.0, spot.y)


func _clear(spot: Vector2) -> bool:
	if main == null or main.coast == null:
		return true
	for offset: Vector2 in [Vector2.ZERO, Vector2(14, 0), Vector2(-14, 0), Vector2(0, 14), Vector2(0, -14)]:
		if main.coast.water_depth(spot.x + offset.x, spot.y + offset.y) < MIN_DEPTH:
			return false
	for beacon in main.beacons:
		var buoy: Vector3 = beacon["buoy_pos"]
		if spot.distance_to(Vector2(buoy.x, buoy.z)) < 45.0:
			return false
	return true


## Войти в рейд. Возвращает true, если рейд начался.
func enter() -> bool:
	if main == null or main.raid == null or main.raid.engaged() or not in_range():
		return false
	# Сфера приседает, раскручивается и уходит свечой в небо; рейд начинается,
	# когда она скрылась.
	_launching = true
	if _fly != null and _fly.is_valid():
		_fly.kill()
	# Сперва медленное погружение — вода принимает сферу и светится изнутри,
	# — и только потом рывок в небо со всплеском на выходе.
	_fly = create_tween()
	_fly.tween_property(self, "_lift", 3.2 - DIVE_DEPTH - ORB_RADIUS, 0.75)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_fly.parallel().tween_property(self, "_spin", 7.0, 0.75)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_fly.chain().tween_property(self, "_lift", 95.0, 1.05)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_fly.parallel().tween_property(self, "_shrink", 0.12, 1.05)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_fly.parallel().tween_property(self, "_spin", 26.0, 1.05)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_fly.parallel().tween_property(self, "_flare", 9.0, 0.45)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_fly.chain().tween_callback(_launched)
	main.announce("СФЕРА ОТКЛИКНУЛАСЬ. ДЕРЖИТЕСЬ.")
	return true


func _launched() -> void:
	_launching = false
	_flare = 0.0
	main.raid.start()
	if not main.raid.engaged():
		# Рейд не начался (например, лодку унесло на мель): сфера возвращается.
		_arrive()


## Сфера опускается с неба на новое место.
func _arrive() -> void:
	if _fly != null and _fly.is_valid():
		_fly.kill()
	_lift = 90.0
	_shrink = 0.12
	_spin = 0.0
	_flare = 0.0
	# Падает с неба, уходит под воду с головой — брызги и свечение — и
	# всплывает уже на своём месте, тоже со всплеском.
	_fly = create_tween()
	_fly.set_parallel(true)
	_fly.tween_property(self, "_lift", 0.0, 1.9).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_fly.tween_property(self, "_shrink", 1.0, 1.9).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Вещь, которую покажет рапорт победы: сперва те, что ещё не попадались.
func claim_prize() -> int:
	if _pending >= 0:
		return _pending
	var pool: Array[int] = []
	for index in range(ArtifactModel.ITEMS.size()):
		if not found.has(index):
			pool.append(index)
	if pool.is_empty():
		_pending = _rng.randi_range(0, ArtifactModel.ITEMS.size() - 1)
	else:
		_pending = pool[_rng.randi_range(0, pool.size() - 1)]
	return _pending


func _bank() -> void:
	var prize := claim_prize()
	if not found.has(prize):
		found.append(prize)
	artifacts += 1
	_pending = -1


func _process(delta: float) -> void:
	_time += delta
	if main == null or main.raid == null:
		return
	var engaged := main.raid.engaged()
	var state := main.raid.state
	# Победа засчитывается, когда рапорт закрыт: выходом или новой вахтой.
	if _last_state == RaidRun.State.WON and state != RaidRun.State.WON:
		_bank()
		_won = true
	_last_state = state
	if _was_engaged and not engaged:
		# Рейд закончен: сфера опускается с неба в другом месте.
		if _won:
			main.announce("АРТЕФАКТ ИЗ ДРУГОГО МИРА — В ТРЮМЕ. СФЕРА ОПУСТИЛАСЬ В НОВОМ МЕСТЕ.")
		else:
			main.announce("СФЕРА ОПУСТИЛАСЬ В НОВОМ МЕСТЕ. СЛЕД — НА КОМПАСЕ.")
		_won = false
		relocate()
		_arrive()
	_was_engaged = engaged
	visible = not engaged
	if not visible:
		_under = false
		_glow = 0.0
		_ring_alpha = 0.0
		return
	# Парит над водой, медленно вращается и «дышит» светом; _lift, _shrink и
	# _spin ведёт анимация взлёта и посадки.
	_model.position.y = 3.2 + 0.55 * sin(_time * 1.3) + _lift
	_model.scale = Vector3.ONE * _shrink
	_model.rotation.y += (0.6 + _spin) * delta
	_model.rotation.x = 0.18 * sin(_time * 0.7)
	_light.position.y = 3.0 + _lift
	_light.light_energy = ((2.6 + 1.2 * sin(_time * 2.1)) * _shrink + _flare) * (1.0 - 0.72 * _glow)
	_water_reaction(delta)


## Построить эффекты воды: брызги, свет из-под воды и пятно на поверхности.
func _build_water_fx() -> void:
	_spray = CPUParticles3D.new()
	_spray.amount = 36
	_spray.lifetime = 0.95
	_spray.lifetime_randomness = 0.35
	_spray.one_shot = true
	_spray.emitting = false
	_spray.explosiveness = 0.95
	_spray.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_spray.emission_sphere_radius = ORB_RADIUS * 0.8
	_spray.direction = Vector3.UP
	_spray.spread = 42.0
	_spray.initial_velocity_min = 7.0
	_spray.initial_velocity_max = 14.0
	_spray.gravity = Vector3(0.0, -11.0, 0.0)
	_spray.damping_min = 0.4
	_spray.damping_max = 1.4
	_spray.scale_amount_min = 0.5
	_spray.scale_amount_max = 1.3
	_spray.scale_amount_curve = ProcTextures.grow_curve(0.35, 1.15)
	_spray.color_ramp = ProcTextures.fade_ramp()
	var drop := QuadMesh.new()
	drop.size = Vector2(0.85, 0.85)
	drop.material = ProcTextures.soft_material(Color(0.86, 0.96, 1.0, 0.85))
	_spray.mesh = drop
	_spray.position = Vector3(0.0, 0.0, 0.0)
	add_child(_spray)

	# Пена: медленные крупные клочья, которые ещё висят над водой, когда
	# капли уже улетели.
	_foam = CPUParticles3D.new()
	_foam.amount = 22
	_foam.lifetime = 1.5
	_foam.lifetime_randomness = 0.4
	_foam.one_shot = true
	_foam.emitting = false
	_foam.explosiveness = 0.9
	_foam.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_foam.emission_sphere_radius = ORB_RADIUS
	_foam.direction = Vector3.UP
	_foam.spread = 85.0
	_foam.initial_velocity_min = 1.0
	_foam.initial_velocity_max = 3.2
	_foam.gravity = Vector3(0.0, -1.2, 0.0)
	_foam.damping_min = 1.2
	_foam.damping_max = 2.4
	_foam.scale_amount_min = 1.2
	_foam.scale_amount_max = 2.4
	_foam.scale_amount_curve = ProcTextures.grow_curve(0.5, 1.5)
	_foam.color_ramp = ProcTextures.fade_ramp()
	var puff := QuadMesh.new()
	puff.size = Vector2(1.4, 1.4)
	puff.material = ProcTextures.soft_material(Color(0.72, 0.86, 0.90, 0.32))
	_foam.mesh = puff
	_foam.position = Vector3(0.0, 0.0, 0.0)
	add_child(_foam)

	# Свет уходит под воду вместе со сферой, но светит уже от поверхности:
	# так его видят и вода, и туман.
	_glow_light = OmniLight3D.new()
	_glow_light.light_color = Color("35d0ba")
	_glow_light.light_energy = 0.0
	_glow_light.omni_range = 26.0
	_glow_light.omni_attenuation = 1.4
	_glow_light.light_volumetric_fog_energy = 0.7
	_glow_light.shadow_enabled = false
	add_child(_glow_light)

	_glow_mat = ShaderMaterial.new()
	_glow_mat.shader = preload("res://shaders/orb_under_glow.gdshader")
	var quad := QuadMesh.new()
	quad.size = Vector2(1.0, 1.0)
	quad.material = _glow_mat
	_glow_disc = MeshInstance3D.new()
	_glow_disc.mesh = quad
	_glow_disc.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
	_glow_disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_glow_disc.visible = false
	add_child(_glow_disc)


## Сфера пересекла поверхность — вода отвечает: кольца, брызги, свет.
func _splash(into_water: bool) -> void:
	var at := Vector2(position.x, position.z)
	if main != null and main.water != null and main.water.field != null:
		main.water.field.splash(at, 2.0)
		if not into_water:
			# Выход обратно: короткая серия колец вдогонку.
			main.water.field.splash(at + Vector2(1.6, -1.1), 1.4)
	_spray.position = Vector3(0.0, _surface - position.y + ORB_RADIUS * 0.4, 0.0)
	_spray.restart()
	_spray.emitting = true
	_foam.position = _spray.position
	_foam.restart()
	_foam.emitting = true
	# Кольцо на поверхности: сила и скорость зависят от того, входит
	# сфера в воду или вырывается из неё.
	_ring = 0.06
	_ring_alpha = 1.35 if not into_water else 1.05
	_glow = maxf(_glow, 0.85)


## Свечение сквозь воду и кольцо на поверхности.
func _water_reaction(delta: float) -> void:
	_surface = 0.0
	if main != null and main.water != null:
		_surface = main.water.surface_height(position.x, position.z)
	var center := position.y + _model.position.y
	var depth := _surface - center
	var under := depth > ORB_RADIUS * 0.10
	if under != _under:
		_splash(under)
		_under = under
	# Чем глубже сфера, тем шире и мягче пятно света; у самой поверхности
	# оно ярче и плотнее.
	var target := 0.0
	if under:
		target = clampf(1.0 - (depth - ORB_RADIUS) / 12.0, 0.25, 1.0)
	_glow = lerpf(_glow, target, clampf(delta * 9.0, 0.0, 1.0))
	_ring = minf(_ring + delta * 2.4, 1.2)
	_ring_alpha = maxf(_ring_alpha - delta * 3.0, 0.0)
	var live := _glow > 0.01 or _ring_alpha > 0.01
	_glow_disc.visible = live
	_glow_light.visible = live
	if not live:
		return
	# Пока идёт всплеск, пятно шире: корона живёт на большом радиусе.
	var spread := lerpf(5.0, 11.0, clampf((depth - ORB_RADIUS) / 6.0, 0.0, 1.0))
	spread = maxf(spread, 7.5 * minf(_ring_alpha, 1.0))
	_glow_disc.position = Vector3(0.0, _surface - position.y + 0.12, 0.0)
	_glow_disc.scale = Vector3(spread, spread, 1.0)
	_glow_mat.set_shader_parameter("glow_strength", _glow * 0.55)
	_glow_mat.set_shader_parameter("ring_radius", _ring)
	_glow_mat.set_shader_parameter("ring_alpha", _ring_alpha * 0.4)
	_glow_light.position = Vector3(0.0, _surface - position.y + 1.4, 0.0)
	_glow_light.light_energy = 7.0 * _glow + 3.0 * _ring_alpha
	_glow_light.omni_range = 12.0 + 8.0 * _glow
