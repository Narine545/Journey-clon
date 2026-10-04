class_name DebugPanel
extends CanvasLayer
## DEV-панель крутилок (F3): небо, песок, пост-обработка, ветер.
## По умолчанию скрыта — в игре игрока никакого текста нет.
## Живые значения применяются к материалам сразу же.

var main

var _box: VBoxContainer
var _fps_label: Label
var _sun_elev := 26.1 # градусы
var _sun_azim := 10.3


func setup(main_ref) -> void:
	main = main_ref
	layer = 20
	visible = false
	_build_ui()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_F3:
			visible = not visible


func _process(_delta: float) -> void:
	if visible and _fps_label != null:
		_fps_label.text = "FPS: %d" % Engine.get_frames_per_second()


# ---------------------------------------------------------------------------
# UI
# ---------------------------------------------------------------------------

func _build_ui() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	panel.offset_left = -460.0
	panel.offset_top = 12.0
	panel.offset_right = -12.0
	panel.offset_bottom = 900.0
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel)

	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 4)
	panel.add_child(_box)

	_fps_label = _label("FPS: —")
	_box.add_child(_fps_label)

	var world: GameWorld = main.world
	var terrain: Terrain = main.terrain

	_section("НЕБО")
	_slider("Солнце: высота°", 5.0, 85.0, _sun_elev, 0.5,
		func(v): _on_sun_changed(v, null))
	_slider("Солнце: азимут°", -180.0, 180.0, _sun_azim, 1.0,
		func(v): _on_sun_changed(null, v))
	_slider("Яркость солнца", 5.0, 140.0, 50.0, 1.0,
		func(v): world.set_sky("sun_intensity", v))
	_slider("Mie (дымка)", 0.0, 30.0, 8.0, 0.5,
		func(v): world.set_sky("mie_scattering", v * 0.000001))
	_slider("Слой Рэлея", 2000.0, 14000.0, 8000.0, 100.0,
		func(v): world.set_sky("rayleigh_scale_height", v))
	_slider("Мультирассеяние", 0.0, 0.2, 0.025, 0.002,
		func(v): world.set_sky("rayleigh_multi_scattering", v))
	_slider("Облака: покрытие", 0.0, 1.0, 0.5, 0.01,
		func(v): world.set_sky("cloud_cover", v))
	_slider("Облака: размер", 0.4, 3.0, 1.25, 0.05,
		func(v): world.set_sky("cloud_size", v))
	_slider("Облака: дрейф, м/с", 0.0, 25.0, 7.0, 0.5,
		func(v): world.set_sky("cloud_drift", v))

	_section("ПЕСОК")
	_slider("Блёстки (доля)", 0.0, 0.5, 0.20, 0.01,
		func(v): terrain.set_sand("glitter_amount", v))
	_slider("Рябь (сила)", 0.0, 1.0, 0.50, 0.02,
		func(v): terrain.set_sand("ripple_strength", v))
	_slider("Мега-рябь (амплитуда)", 0.0, 0.12, 0.055, 0.005,
		func(v): terrain.set_sand("mega_amp", v))
	_slider("Дымка песка (м)", 100.0, 900.0, 340.0, 10.0,
		func(v): terrain.set_sand("fog_distance", v))

	_section("ПОСТ")
	_slider("Экспозиция", 0.5, 2.0, world.get_exposure(), 0.02,
		func(v): world.set_exposure(v))
	_slider("Порог glow", 0.5, 1.5, world.get_glow_threshold(), 0.02,
		func(v): world.set_glow_threshold(v))

	_section("ЦВЕТ (ГРЕЙДИНГ)")
	_preset_slider()
	_slider("Сила грейда", 0.0, 1.0, main.color_grade.intensity, 0.01,
		func(v): main.color_grade.set_intensity(v))
	_slider("Тепло", -1.0, 1.0, 0.15, 0.01,
		func(v): main.color_grade.set_param("temperature", v))
	_slider("Контраст", 0.6, 1.7, 1.04, 0.01,
		func(v): main.color_grade.set_param("contrast", v))
	_slider("Вибранс", -0.6, 0.6, 0.12, 0.01,
		func(v): main.color_grade.set_param("vibrance", v))
	_slider("Ночь (Пуркинье)", 0.0, 1.0, 0.0, 0.01,
		func(v): main.color_grade.set_param("night", v))

	_section("ВЕТЕР")
	_slider("Направление°", -180.0, 180.0, rad_to_deg(main.game.wind_base), 1.0,
		func(v): main.game.wind_base = deg_to_rad(v))

	_label("F3 — скрыть панель")


## Строка выбора пресета грейдинга (целые шаги + имя пресета).
func _preset_slider() -> void:
	var grade: ColorGrader = main.color_grade
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	_box.add_child(row)

	var l := _label("Пресет")
	l.custom_minimum_size = Vector2(170.0, 0)
	row.add_child(l)

	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = float(grade.preset_count() - 1)
	s.step = 1.0
	s.value = grade.preset_idx
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.custom_minimum_size = Vector2(150.0, 20.0)
	row.add_child(s)

	var vlabel := _label(grade.preset_name(grade.preset_idx))
	vlabel.custom_minimum_size = Vector2(130.0, 0)
	row.add_child(vlabel)
	s.value_changed.connect(func(v): grade.apply_preset(int(v)))
	s.value_changed.connect(func(v): vlabel.text = grade.preset_name(int(v)))


func _section(title: String) -> void:
	var l := _label(title)
	l.add_theme_color_override("font_color", Color(1.0, 0.8, 0.5))
	_box.add_child(l)


func _label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 13)
	return l


func _slider(text: String, min_v: float, max_v: float, val: float, step: float, cb: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	_box.add_child(row)

	var l := _label(text)
	l.custom_minimum_size = Vector2(170.0, 0)
	row.add_child(l)

	var s := HSlider.new()
	s.min_value = min_v
	s.max_value = max_v
	s.step = step
	s.value = val
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.custom_minimum_size = Vector2(150.0, 20.0)
	s.value_changed.connect(cb)
	row.add_child(s)

	var vlabel := _label("%.2f" % val)
	vlabel.custom_minimum_size = Vector2(52.0, 0)
	row.add_child(vlabel)
	s.value_changed.connect(func(v): vlabel.text = "%.2f" % v)


# ---------------------------------------------------------------------------
# Применение
# ---------------------------------------------------------------------------

func _on_sun_changed(elev: Variant, azim: Variant) -> void:
	if elev != null:
		_sun_elev = float(elev)
	if azim != null:
		_sun_azim = float(azim)
	var el := deg_to_rad(_sun_elev)
	var az := deg_to_rad(_sun_azim)
	var dir := Vector3(sin(az) * cos(el), sin(el), -cos(az) * cos(el)).normalized()
	main.game.sun_dir = dir
	main.world.apply_sun(dir)
	main.terrain.apply_sun(dir)
	main.player.apply_sun(dir)
