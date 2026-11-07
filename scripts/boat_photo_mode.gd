class_name BoatPhotoMode
extends Control
## Lightweight photography controls inspired by TuniTem's CC0 camera example.
## One existing viewport/camera; shutter controls exposure, NOT frame stacking.
const POINTS := [Vector3(0.0, 2.25, -4.7), Vector3(0.0, 2.52, -2.48),
	Vector3(0.0, 2.45, 4.45), Vector3(0.0, 10.0, 0.0)]
const TITLES := ["Нос", "Перед рубкой", "Корма", "Над судном"]
var main: BoatMain
var active := false
var capturing := false
var _point := 0
var _yaw := 0.0
var _pitch := 0.0
var _height := 0.0
var _saved: Dictionary = {}
var _saved_projection := Camera3D.PROJECTION_ORTHOGONAL
var _attributes: CameraAttributesPractical
var _panel: PanelContainer
var _camera_readout: Label
var _status: Label
var _view: OptionButton
var _iso: OptionButton
var _aperture: OptionButton
var _shutter: OptionButton
var _ev: HSlider
var _zoom: HSlider
var _focus: HSlider
var _dof: CheckBox
var _task := -1


func setup(game: BoatMain) -> void:
	main = game
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_panel = PanelContainer.new()
	_panel.position = Vector2(18, 18)
	_panel.custom_minimum_size = Vector2(310, 0)
	add_child(_panel)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(310, 260)
	_panel.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	_label(box, "ФОТОКАМЕРА · F2 / Esc — выйти")
	_view = _choice(box, "Точка съёмки", TITLES, [0, 1, 2, 3], 0)
	_view.item_selected.connect(_select_point)
	_zoom = _slider(box, "Угол обзора (градусы)", 25, 100, 1, 65)
	_iso = _choice(box, "ISO", ["100", "200", "400", "800", "1600", "3200", "6400"], [100, 200, 400, 800, 1600, 3200, 6400], 2)
	_aperture = _choice(box, "Диафрагма", ["f/1.4", "f/2", "f/2.8", "f/4", "f/5.6", "f/8", "f/11", "f/16"], [1.4, 2.0, 2.8, 4.0, 5.6, 8.0, 11.0, 16.0], 3)
	_shutter = _choice(box, "Выдержка (только экспозиция)", ["1/1000", "1/250", "1/125", "1/60", "1/30", "1/15", "1/4", "1 сек"], [0.001, 0.004, 0.008, 1.0 / 60.0, 1.0 / 30.0, 1.0 / 15.0, 0.25, 1.0], 3)
	_ev = _slider(box, "Экспокоррекция EV", -3, 3, 0.25, 0)
	_focus = _slider(box, "Дистанция фокуса (м)", 1, 200, 1, 25)
	_dof = CheckBox.new()
	_dof.text = "Глубина резкости (дороже)"
	box.add_child(_dof)
	_dof.toggled.connect(func(_enabled: bool): _apply_settings())
	for option in [_iso, _aperture, _shutter]:
		option.item_selected.connect(func(_index: int): _apply_settings())
	var snap := Button.new()
	snap.text = "Снять фото · Space / Ctrl+S"
	snap.pressed.connect(capture)
	box.add_child(snap)
	var folder := Button.new()
	folder.text = "Открыть папку фотографий"
	folder.pressed.connect(func():
		DirAccess.make_dir_recursive_absolute("user://photos")
		OS.shell_open(ProjectSettings.globalize_path("user://photos")))
	box.add_child(folder)
	_label(box, "1–4 — точка · ПКМ — взгляд\nКолесо — зум · Q/E — высота\nShift — быстрее · R — сброс взгляда\nСетка не попадает на снимок.\nПогода и волны продолжают идти.")
	_camera_readout = _label(box, "")
	_camera_readout.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status = _label(box, "")


func _label(box: VBoxContainer, text: String) -> Label:
	var label := Label.new()
	label.text = text
	box.add_child(label)
	return label


func _choice(box: VBoxContainer, title: String, labels: Array, values: Array, selected: int) -> OptionButton:
	_label(box, title)
	var option := OptionButton.new()
	for i in range(labels.size()):
		option.add_item(str(labels[i]))
		option.set_item_metadata(i, values[i])
	option.select(selected)
	box.add_child(option)
	return option


func _slider(box: VBoxContainer, title: String, low: float, high: float, step: float, initial: float) -> HSlider:
	var caption := _label(box, "%s: %.2f" % [title, initial])
	var slider := HSlider.new()
	slider.min_value = low
	slider.max_value = high
	slider.step = step
	slider.value = initial
	slider.value_changed.connect(func(value: float):
		caption.text = "%s: %.2f" % [title, value]
		_apply_settings())
	box.add_child(slider)
	return slider


func set_active(enabled: bool) -> void:
	if enabled == active or capturing:
		return
	var camera := main.camera
	if enabled:
		main.inspector.set_free_camera(false)
		main.inspector.map_open = false
		_saved_projection = camera.projection
		_saved = {"projection": camera.projection, "near": camera.near, "far": camera.far,
			"size": camera.size, "fov": camera.fov, "attributes": camera.attributes,
			"transform": camera.global_transform}
		_attributes = CameraAttributesPractical.new()
		camera.attributes = _attributes
		camera.projection = Camera3D.PROJECTION_PERSPECTIVE
		camera.near = 0.08
		camera.far = 4000.0
		main.boat.speed = 0.0
	else:
		camera.projection = _saved_projection
		camera.near = float(_saved["near"])
		camera.far = float(_saved["far"])
		camera.size = float(_saved["size"])
		camera.fov = float(_saved["fov"])
		camera.attributes = _saved["attributes"]
		camera.global_transform = _saved["transform"]
	active = enabled
	visible = enabled
	if active:
		_apply_settings()
		update_camera(0.0)
	queue_redraw()


func _select_point(index: int) -> void:
	_point = index
	_view.select(index)
	_yaw = PI if index == 2 else 0.0
	_pitch = -0.65 if index == 3 else -0.05
	_height = 0.0


static func exposure_gain(iso: float, aperture: float, shutter: float, ev: float) -> float:
	return clampf((iso / 400.0) * (shutter * 60.0) * pow(4.0 / aperture, 2.0) * pow(2.0, ev), 1.0 / 64.0, 64.0)


func _apply_settings() -> void:
	if not active:
		return
	var aperture := float(_aperture.get_selected_metadata())
	_attributes.exposure_multiplier = exposure_gain(float(_iso.get_selected_metadata()), aperture, float(_shutter.get_selected_metadata()), _ev.value)
	_attributes.dof_blur_far_enabled = _dof.button_pressed
	_attributes.dof_blur_near_enabled = _dof.button_pressed
	_attributes.dof_blur_far_distance = _focus.value
	_attributes.dof_blur_near_distance = maxf(0.1, _focus.value * 0.5)
	_attributes.dof_blur_far_transition = maxf(1.0, _focus.value * 0.5)
	_attributes.dof_blur_near_transition = maxf(0.5, _focus.value * 0.25)
	_attributes.dof_blur_amount = clampf(0.12 * 4.0 / aperture, 0.0, 0.4)
	main.camera.fov = _zoom.value


func update_camera(delta: float) -> void:
	if not active:
		return
	var up := 1.0 if Input.is_physical_key_pressed(KEY_E) else 0.0
	var down := 1.0 if Input.is_physical_key_pressed(KEY_Q) else 0.0
	_height = clampf(_height + (up - down) * delta * (25.0 if Input.is_physical_key_pressed(KEY_SHIFT) else 4.0), -0.4, 1000.0)
	var body := main.boat._body.get_global_transform_interpolated()
	var local_point: Vector3 = POINTS[_point]
	main.camera.global_transform = Transform3D(body.basis * Basis.from_euler(Vector3(_pitch, _yaw, 0.0)), body * local_point + Vector3.UP * _height)


func _input(event: InputEvent) -> void:
	if main == null:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F2:
		set_active(not active)
		get_viewport().set_input_as_handled()
		return
	if not active:
		return
	if event is InputEventKey and event.pressed:
		if event.physical_keycode == KEY_F8:
			return
		if not capturing and not event.echo:
			match event.physical_keycode:
				KEY_ESCAPE: set_active(false)
				KEY_1, KEY_2, KEY_3, KEY_4: _select_point(int(event.physical_keycode - KEY_1))
				KEY_R: _select_point(_point)
				KEY_SPACE: capture()
				KEY_S:
					if event.ctrl_pressed: capture()
		get_viewport().set_input_as_handled()
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		if not _panel.get_global_rect().has_point(event.position):
			_yaw -= event.relative.x * 0.003
			_pitch = clampf(_pitch - event.relative.y * 0.003, -1.45, 1.45)
			get_viewport().set_input_as_handled()
	if event is InputEventMouseButton and event.pressed:
		if _panel.get_global_rect().has_point(event.position):
			return
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom.value -= 3.0
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom.value += 3.0
			get_viewport().set_input_as_handled()


func capture() -> void:
	if not active or capturing:
		return
	capturing = true
	visible = false
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var folder := "user://photos"
	var error := DirAccess.make_dir_recursive_absolute(folder)
	if error != OK:
		_capture_done(error, folder)
		return
	var stamp := Time.get_datetime_string_from_system().replace(":", "-")
	var base := "%s/photo_%s_%d" % [folder, stamp, Time.get_ticks_usec()]
	var at := main.camera.global_position
	var photo_rotation := main.camera.global_rotation
	var metadata := JSON.stringify({"point": TITLES[_point], "position": [at.x, at.y, at.z],
		"rotation": [photo_rotation.x, photo_rotation.y, photo_rotation.z], "fov": main.camera.fov,
		"iso": _iso.get_selected_metadata(), "fstop": _aperture.get_selected_metadata(),
		"shutter_seconds": _shutter.get_selected_metadata(), "ev": _ev.value,
		"focus_meters": _focus.value, "dof": _dof.button_pressed,
		"exposure_multiplier": _attributes.exposure_multiplier, "night01": main.night01,
		"camera_height_multiple": main.camera_height_multiple(),
		"shutter_is_exposure_only": true}, "\t")
	_task = WorkerThreadPool.add_task(_save_image.bind(image, base, metadata))


func _save_image(image: Image, base: String, metadata: String) -> void:
	var error := image.save_png(base + ".png")
	if error == OK:
		var file := FileAccess.open(base + ".json", FileAccess.WRITE)
		if file == null:
			error = FileAccess.get_open_error()
		else:
			file.store_string(metadata)
			error = file.get_error()
			file.close()
	call_deferred("_capture_done", error, base)


func _capture_done(error: int, path: String) -> void:
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
	capturing = false
	visible = active
	_status.text = "Фото сохранено в user://photos" if error == OK else "Ошибка сохранения: %d" % error
	print("[PHOTO] ", ProjectSettings.globalize_path(path), " · ", error)


func _exit_tree() -> void:
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)


func _process(_delta: float) -> void:
	if active:
		_panel.size = Vector2(330, clampf(size.y - 36.0, 260.0, 760.0))
		_camera_readout.text = main.camera_scale_text()
		queue_redraw()


func _draw() -> void:
	if not active:
		return
	for fraction in [1.0 / 3.0, 2.0 / 3.0]:
		draw_line(Vector2(size.x * fraction, 0), Vector2(size.x * fraction, size.y), Color(1, 1, 1, 0.18))
		draw_line(Vector2(0, size.y * fraction), Vector2(size.x, size.y * fraction), Color(1, 1, 1, 0.18))
