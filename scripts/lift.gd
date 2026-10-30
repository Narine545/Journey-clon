class_name SupplyLift
extends Node3D
## Один оплаченный заказ за цикл. Состояние блокируется ДО списания,
## в том числе против повторного вызова из points_changed.
signal state_changed(new_state: int)
signal effect_applied(item_id: String, effect: Dictionary)
enum State { IDLE, CALLED, ASCENDING, ARRIVED, UNLOADED, DESCENDING }
const CRATE_SCENE := preload("res://scenes/Crate.tscn")
var state := State.IDLE
var main: MainScene
var pending_id := ""
var installed: Dictionary = {}
var elapsed := 0.0
var ascent_duration: float = SupplyCatalog.SETTINGS["lift_ascent_mean"]
var rng := RandomNumberGenerator.new()
var cage: Node3D
var crate: SupplyCrate
var _start_sfx: AudioStreamPlayer3D
var _arrival_sfx: AudioStreamPlayer3D
var _hum: AudioStreamPlayer3D


func setup(main_ref: MainScene) -> void:
	main = main_ref
	rng.randomize()
	cage = Node3D.new()
	cage.position = Vector3(-6.8, 1.0, 3.5)
	add_child(cage)
	# Визуальная кабина — часть модели пользователя; этот узел остаётся
	# только пространственным якорем звука, без второй платформы.
	_start_sfx = _make_sound(main.audio.make_lift_clank(false), -10.0)
	_arrival_sfx = _make_sound(main.audio.make_lift_clank(true), -9.0)
	_hum = _make_sound(main.audio.make_lift_hum(), -18.0)


func _make_sound(stream: AudioStream, volume: float) -> AudioStreamPlayer3D:
	var player := AudioStreamPlayer3D.new()
	player.stream = stream
	player.volume_db = volume
	player.unit_size = 45.0
	player.max_distance = 160.0
	cage.add_child(player)
	return player


func can_order(item_id: String) -> bool:
	var data := SupplyCatalog.item(item_id)
	return state == State.IDLE and not data.is_empty() and not is_installed(item_id) and Economy.can_afford(int(data["cost"]))


func is_installed(item_id: String) -> bool:
	return bool(installed.get(item_id, false))


func request_order(item_id: String) -> bool:
	var data := SupplyCatalog.item(item_id)
	if state != State.IDLE or data.is_empty() or is_installed(item_id):
		main.audio.on_refused()
		return false
	# Закрываем заказ до сигнала кошелька, чтобы даже reentrant-клик не
	# списал очки дважды; при отказе немедленно возвращаем IDLE.
	state = State.CALLED
	if not Economy.try_spend(int(data["cost"])):
		state = State.IDLE
		main.audio.on_refused()
		return false
	pending_id = item_id
	elapsed = 0.0
	ascent_duration = rng.randf_range(float(SupplyCatalog.SETTINGS["lift_ascent_mean"]) - float(SupplyCatalog.SETTINGS["lift_ascent_variance"]), float(SupplyCatalog.SETTINGS["lift_ascent_mean"]) + float(SupplyCatalog.SETTINGS["lift_ascent_variance"]))
	_start_sfx.play()
	main.audio.on_hit_confirmed()
	state_changed.emit(state)
	return true


func _process(delta: float) -> void:
	advance(delta)


## Детерминированный шаг используется и реальным процессом, и тестом.
func advance(delta: float) -> void:
	if state == State.IDLE:
		return
	elapsed += maxf(delta, 0.0)
	if state == State.ARRIVED:
		# Первую половину авторской анимации дверцы проигрываем один раз,
		# затем удерживаем открытой до принятия груза.
		main.tower.pose_door(4.0 + minf(elapsed, 1.0))
		if elapsed >= 1.0 and not is_instance_valid(crate):
			_spawn_crate()
		return
	match state:
		State.CALLED:
			if elapsed >= float(SupplyCatalog.SETTINGS["lift_called_seconds"]):
				_set_state(State.ASCENDING)
				_hum.play()
		State.ASCENDING:
			var progress := clampf(elapsed / ascent_duration, 0.0, 1.0)
			cage.position.y = lerpf(1.0, ObservationTower.DECK_HEIGHT - 0.15, progress)
			# Кадры 120–240: подъём, растянутый на конфигурируемую доставку.
			main.tower.pose_cage(2.0 + 2.0 * progress)
			if progress >= 1.0:
				_hum.stop()
				_arrival_sfx.play()
				_set_state(State.ARRIVED)
		State.UNLOADED:
			var closing := clampf(elapsed / float(SupplyCatalog.SETTINGS["lift_unloaded_seconds"]), 0.0, 1.0)
			main.tower.pose_door(5.0 + closing)
			if elapsed >= float(SupplyCatalog.SETTINGS["lift_unloaded_seconds"]):
				_set_state(State.DESCENDING)
				_start_sfx.play()
				_hum.play()
		State.DESCENDING:
			var progress := clampf(elapsed / float(SupplyCatalog.SETTINGS["lift_descent_seconds"]), 0.0, 1.0)
			cage.position.y = lerpf(ObservationTower.DECK_HEIGHT - 0.15, 1.0, progress)
			main.tower.pose_cage(4.0 - 2.0 * progress)
			if progress >= 1.0:
				_hum.stop()
				pending_id = ""
				_set_state(State.IDLE)


func _set_state(next_state: State) -> void:
	state = next_state
	elapsed = 0.0
	state_changed.emit(state)


func _spawn_crate() -> void:
	crate = CRATE_SCENE.instantiate() as SupplyCrate
	add_child(crate)
	# С шахты груз подан на настил; игрок может подойти и нажать взглядом.
	crate.position = Vector3(-4.65, ObservationTower.DECK_HEIGHT + 0.52, 3.5)


func try_collect_from_camera() -> bool:
	if state != State.ARRIVED or elapsed < 1.0 or not is_instance_valid(crate):
		return false
	var camera := main.cam_rig.cam
	var from := camera.global_position
	var to := from - camera.global_basis.z * float(SupplyCatalog.SETTINGS["crate_reach"])
	var query := PhysicsRayQueryParameters3D.create(from, to, 4)
	var result := camera.get_world_3d().direct_space_state.intersect_ray(query)
	if result.get("collider") != crate:
		return false
	return collect_crate()


func collect_crate() -> bool:
	if state != State.ARRIVED or elapsed < 1.0 or not is_instance_valid(crate):
		return false
	var data := SupplyCatalog.item(pending_id)
	if data.is_empty():
		return false
	# Меняем состояние прежде чем испустить сигнал эффекта: повторный клик
	# и обработчики сигнала не могут получить один и тот же груз дважды.
	_set_state(State.UNLOADED)
	if data["type"] == "Upgrade":
		installed[pending_id] = true
	crate.queue_free()
	crate = null
	effect_applied.emit(pending_id, data["effect_payload"])
	return true


func status_text() -> String:
	match state:
		State.IDLE: return "ЛИФТ ВНИЗУ"
		State.CALLED, State.ASCENDING, State.DESCENDING: return "ЛИФТ В ПУТИ"
		State.ARRIVED: return "ГРУЗ НА ПЛОЩАДКЕ"
		State.UNLOADED: return "ЛИФТ В ПУТИ"
	return "ЛИФТ ВНИЗУ"
