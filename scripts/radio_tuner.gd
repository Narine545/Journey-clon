class_name RadioTuner
extends Node3D
## Ручной приёмник. Архивные записи воспроизводятся редко, живой цифровой
## эфир существует сам по себе и не является надёжным индикатором роботов.
const MIN_FREQ := 80.0
const MAX_FREQ := 110.0
const INTERACT_DISTANCE := 2.4
const STATIONS := [88.5, 94.2, 103.1]
var main: MainScene
var rng := RandomNumberGenerator.new()
var frequency := 88.5
var powered := false
var transmitting := false
var _beacon_repeat := 0.0
var tuning := false
var live_on_air := false
var signal_strength := 0.0
var live_signal_multiplier := 1.0
var station_index := -1
var _last_station := -1
var _noise: AudioStreamPlayer3D
var _record: AudioStreamPlayer3D
var _live: AudioStreamPlayer3D
var _beacon: AudioStreamPlayer3D
var _recordings: Array[AudioStream] = []
var _packets: Array[AudioStream] = []
var _overlay: RadioOverlay


func setup(main_ref: MainScene) -> void:
	main = main_ref
	rng.randomize()
	live_on_air = rng.randf() < 0.5
	position = Vector3(-4.75, ObservationTower.DECK_HEIGHT + 1.18, -3.9)
	_noise = _make_player(main.audio._gen_radio_noise())
	_record = _make_player(null)
	_live = _make_player(null)
	_beacon = _make_player(load("res://assets/radio/beacon.wav") as AudioStream)
	_recordings = [load("res://assets/radio/post.wav") as AudioStream, load("res://assets/radio/weather.wav") as AudioStream]
	for i in range(4):
		_packets.append(main.audio._gen_radio_packet(7100 + i * 173))
	var layer := CanvasLayer.new()
	layer.layer = 18
	add_child(layer)
	_overlay = RadioOverlay.new()
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_overlay)


func _make_player(stream: AudioStream) -> AudioStreamPlayer3D:
	var player := AudioStreamPlayer3D.new()
	player.stream = stream
	player.volume_db = -80.0
	player.unit_size = 3.0
	player.max_distance = 18.0
	add_child(player)
	return player


func nearby() -> bool:
	if main == null:
		return false
	var player_pos := main.player.global_position + Vector3.UP * CameraRig.EYE
	return player_pos.distance_to(global_position) <= INTERACT_DISTANCE


func set_frequency(value: float) -> void:
	frequency = clampf(snappedf(value, 0.1), MIN_FREQ, MAX_FREQ)


func _input(event: InputEvent) -> void:
	if main == null or (main.shop != null and main.shop.is_open):
		return
	if event is InputEventKey and event.pressed:
		if event.physical_keycode == KEY_E and not event.echo and (tuning or nearby()):
			set_tuning(not tuning)
			get_viewport().set_input_as_handled()
			return
		if tuning:
			if event.physical_keycode == KEY_B and not event.echo:
				if powered:
					main.shop.set_open(true)
				else:
					main.audio.on_refused()
				get_viewport().set_input_as_handled()
				return
			match event.physical_keycode:
				KEY_ESCAPE:
					set_tuning(false)
				KEY_X:
					if not event.echo:
						set_powered(not powered)
				KEY_LEFT, KEY_A, KEY_Q:
					set_frequency(frequency - 0.1)
				KEY_RIGHT, KEY_D:
					set_frequency(frequency + 0.1)
				_:
					return
			get_viewport().set_input_as_handled()
	elif tuning and event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			set_frequency(frequency + 0.1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			set_frequency(frequency - 0.1)
		get_viewport().set_input_as_handled()


func set_tuning(value: bool) -> void:
	tuning = value
	if value:
		main.rifle.aim_requested = false
		if not powered:
			set_powered(true)
	main.rifle.hud.visible = not value


func set_powered(value: bool) -> void:
	powered = value
	if not value:
		set_transmitting(false)
	if value and not _noise.playing:
		_noise.play()
	elif not value:
		_noise.stop()
		_record.stop()
		_live.stop()
	_last_station = -1


## Маяк работает независимо от настройки принимаемой частоты и от открытой панели.
func set_transmitting(value: bool) -> void:
	transmitting = value and powered
	_beacon_repeat = 12.0
	if transmitting:
		_record.stop()
		_live.stop()
		_beacon.volume_db = linear_to_db(0.22)
		_beacon.play()
	else:
		_beacon.stop()
		if main != null and main.ambient_spawner != null:
			main.ambient_spawner.cancel_signal()
	_last_station = -1


## Непрерывная шкала приёма, а не бинарное попадание в фиксированный канал.
func update_signal() -> void:
	station_index = -1
	signal_strength = 0.0
	for i in range(STATIONS.size()):
		var available := i != 1 or live_on_air
		if not available:
			continue
		var antenna := live_signal_multiplier if i == 1 else 1.0
		var strength := clampf((1.0 - absf(frequency - float(STATIONS[i])) / (0.8 * antenna)) * antenna, 0.0, 1.0)
		if strength > signal_strength:
			station_index = i
			signal_strength = strength
	# Погода слегка меняет приём, не зашифровывая точное положение робота.
	signal_strength *= clampf(1.02 - (main.game.wind_strength - 1.0) * 0.15, 0.70, 1.0)


func apply_delivery(_item_id: String, effect: Dictionary) -> void:
	if effect.has("live_signal_multiplier"):
		live_signal_multiplier = float(effect["live_signal_multiplier"])
		_live.max_distance = 18.0 * live_signal_multiplier
		update_signal()


func _process(delta: float) -> void:
	if main == null or _overlay == null:
		return
	# Состояние передатчика независимо от ручки и от существования роботов.
	var mean_change := 40.0 if live_on_air else 100.0
	if rng.randf() < 1.0 - exp(-delta / mean_change):
		live_on_air = not live_on_air
	update_signal()
	var audible_station := station_index if powered and not transmitting and signal_strength > 0.4 else -1
	if transmitting and not _beacon.playing:
		_beacon_repeat -= delta
		if _beacon_repeat <= 0.0:
			_beacon.play()
			_beacon_repeat = 12.0
	if audible_station != _last_station:
		_record.stop()
		_live.stop()
		_last_station = audible_station
		if audible_station == 0 or audible_station == 2:
			_start_recording(audible_station)
	if audible_station == 0 or audible_station == 2:
		if not _record.playing and rng.randf() < 1.0 - exp(-delta / 35.0):
			_start_recording(audible_station)
	elif audible_station == 1 and not _live.playing:
		if rng.randf() < 1.0 - exp(-delta / 6.0):
			_live.stream = _packets[rng.randi_range(0, _packets.size() - 1)]
			_live.play()
	# Тихий шум остаётся между станциями, но только при включённом приёмнике.
	var noise_gain := (0.018 + (1.0 - signal_strength) * 0.035) if powered else 0.0
	_noise.volume_db = linear_to_db(maxf(noise_gain, 0.00001))
	_record.volume_db = linear_to_db(maxf(signal_strength * 0.24 if powered else 0.0, 0.00001))
	_live.volume_db = linear_to_db(maxf(signal_strength * 0.11 if powered else 0.0, 0.00001))
	_overlay.tuning = tuning
	_overlay.hint = nearby() and not tuning and main.rifle.scope_amount < 0.2
	_overlay.powered = powered
	_overlay.transmitting = transmitting
	_overlay.frequency = frequency
	_overlay.strength = signal_strength if powered else 0.0
	_overlay.station = audible_station
	_overlay.queue_redraw()


func _start_recording(index: int) -> void:
	_record.stream = _recordings[0 if index == 0 else 1]
	_record.play()


class RadioOverlay extends Control:
	var tuning := false
	var hint := false
	var powered := false
	var transmitting := false
	var frequency := 88.5
	var strength := 0.0
	var station := -1

	func _draw() -> void:
		var font := ThemeDB.fallback_font
		var scale_factor := clampf(size.y / 800.0, 0.8, 1.3)
		var center := size * 0.5
		var font_size := roundi(22.0 * scale_factor)
		var ink := Color(0.91, 0.85, 0.70, 0.94)
		if hint:
			draw_string(font, Vector2(center.x - 100.0 * scale_factor, size.y * 0.80), "E  ·  РАДИО", HORIZONTAL_ALIGNMENT_CENTER, 200.0 * scale_factor, font_size, ink)
		if not tuning:
			return
		var box_size := Vector2(620.0, 280.0) * scale_factor
		var rect := Rect2(center - box_size * 0.5, box_size)
		draw_rect(rect, Color(0.055, 0.052, 0.045, 0.92))
		draw_rect(rect, Color(0.49, 0.40, 0.28, 0.8), false, 2.0)
		var left := rect.position.x + 32.0 * scale_factor
		var top := rect.position.y
		draw_string(font, Vector2(left, top + 44.0 * scale_factor), "РАДИО   ·   %s" % ("ВКЛ" if powered else "ВЫКЛ"), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, ink)
		draw_string(font, Vector2(left, top + 89.0 * scale_factor), "%.1f МГц" % frequency, HORIZONTAL_ALIGNMENT_LEFT, -1, roundi(34.0 * scale_factor), ink)
		var x1 := left
		var x2 := rect.end.x - 32.0 * scale_factor
		var y := top + 118.0 * scale_factor
		draw_line(Vector2(x1, y), Vector2(x2, y), Color(0.55, 0.49, 0.39), 2.0 * scale_factor)
		for i in range(16):
			var tick_x := lerpf(x1, x2, float(i) / 15.0)
			draw_line(Vector2(tick_x, y - 4.0 * scale_factor), Vector2(tick_x, y + 4.0 * scale_factor), ink, 1.0)
		var needle := lerpf(x1, x2, (frequency - MIN_FREQ) / (MAX_FREQ - MIN_FREQ))
		draw_line(Vector2(needle, y - 13.0 * scale_factor), Vector2(needle, y + 13.0 * scale_factor), Color(0.82, 0.43, 0.22), 2.0 * scale_factor)
		var label := "ШУМ"
		if station == 0 or station == 2:
			label = "ЗАПИСЬ"
		elif station == 1:
			label = "ЖИВОЙ СИГНАЛ"
		if not powered:
			label = "ПРИЁМНИК ВЫКЛЮЧЕН"
		draw_string(font, Vector2(left, top + 155.0 * scale_factor), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, ink)
		var bar := Rect2(Vector2(rect.end.x - 175.0 * scale_factor, top + 140.0 * scale_factor), Vector2(140.0, 9.0) * scale_factor)
		draw_rect(bar, Color(0.25, 0.24, 0.20))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * strength, bar.size.y)), Color(0.76, 0.64, 0.42))
		var help_color := Color(0.77, 0.73, 0.64)
		draw_string(font, Vector2(left, top + 185.0 * scale_factor), "МАЯК: %s    ·    T: включить / выключить" % ("ПЕРЕДАЁТ" if transmitting else "ВЫКЛ"), HORIZONTAL_ALIGNMENT_LEFT, -1, roundi(17.0 * scale_factor), ink)
		draw_string(font, Vector2(left, top + 215.0 * scale_factor), "← / → или колесо: частота", HORIZONTAL_ALIGNMENT_LEFT, -1, roundi(17.0 * scale_factor), help_color)
		draw_string(font, Vector2(left, top + 245.0 * scale_factor), "B: снабжение      X: питание      E / Esc: закрыть", HORIZONTAL_ALIGNMENT_LEFT, -1, roundi(17.0 * scale_factor), help_color)
