class_name GameFpsCounter
extends CanvasLayer
## Небольшой независимый индикатор, доступный и на причале, и в рейде.
## F3 не привязан к корабельному HUD. Значение обновляется дважды в секунду.
var _label: Label
var _elapsed := 0.0
var _mode_label: Label
var test_mode := 0
var _original_scale := 1.0
var _original_msaa := Viewport.MSAA_DISABLED


func _ready() -> void:
	layer = 60
	_original_scale = get_viewport().scaling_3d_scale
	_original_msaa = get_viewport().msaa_3d
	_label = Label.new()
	_label.name = "FpsLabel"
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_label.offset_left = -120.0
	_label.offset_right = -12.0
	_label.offset_top = 12.0
	_label.offset_bottom = 40.0
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_label.add_theme_font_size_override("font_size", 20)
	_label.add_theme_color_override("font_color", Color("f5f1e7"))
	_label.add_theme_color_override("font_shadow_color", Color("121820"))
	_label.add_theme_constant_override("shadow_offset_x", 2)
	_label.add_theme_constant_override("shadow_offset_y", 2)
	_label.add_theme_constant_override("outline_size", 3)
	_label.add_theme_color_override("font_outline_color", Color("121820"))
	add_child(_label)
	_mode_label = Label.new()
	_mode_label.name = "ComparisonMode"
	_mode_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mode_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_mode_label.offset_left = -275.0
	_mode_label.offset_right = -12.0
	_mode_label.offset_top = 41.0
	_mode_label.offset_bottom = 63.0
	_mode_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_mode_label.add_theme_font_size_override("font_size", 14)
	_mode_label.add_theme_color_override("font_color", Color("f5f1e7"))
	_mode_label.add_theme_constant_override("outline_size", 3)
	_mode_label.add_theme_color_override("font_outline_color", Color("121820"))
	add_child(_mode_label)
	_update_value()
	_update_mode_label()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_F3:
			visible = not visible
			get_viewport().set_input_as_handled()
		elif event.physical_keycode == KEY_F4:
			set_test_mode((test_mode + 1) % 3)
			get_viewport().set_input_as_handled()


## Сравниваем факторы по одному, не сохраняя тестовый режим в настройках.
## UI остаётся в исходном разрешении. Для возврата — третье нажатие F4.
func set_test_mode(mode: int) -> void:
	test_mode = clampi(mode, 0, 2)
	var viewport := get_viewport()
	viewport.scaling_3d_scale = _original_scale * 0.70 if test_mode == 1 else _original_scale
	viewport.msaa_3d = Viewport.MSAA_DISABLED if test_mode == 2 else _original_msaa
	_update_mode_label()


func set_base_settings(scale_value: float, msaa_value: Viewport.MSAA) -> void:
	_original_scale = scale_value
	_original_msaa = msaa_value
	set_test_mode(0)


func _update_mode_label() -> void:
	if _mode_label == null:
		return
	var modes := ["ВЫБРАННОЕ", "3D ×0.7", "MSAA ВЫКЛ"]
	_mode_label.text = "F4 · %s" % modes[test_mode]


func _exit_tree() -> void:
	# Не переносить тестовое качество в другую игровую сцену.
	if get_viewport() != null:
		get_viewport().scaling_3d_scale = _original_scale
		get_viewport().msaa_3d = _original_msaa


func _process(delta: float) -> void:
	if not visible:
		return
	_elapsed += delta
	if _elapsed >= 0.5:
		_elapsed = 0.0
		_update_value()


func _update_value() -> void:
	if _label != null:
		_label.text = "%d FPS" % Engine.get_frames_per_second()
