class_name GameFpsCounter
extends CanvasLayer
## Небольшой независимый индикатор, доступный и на причале, и в рейде.
## F3 не привязан к корабельному HUD. Значение обновляется дважды в секунду.
var _label: Label
var _elapsed := 0.0


func _ready() -> void:
	layer = 60
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
	_update_value()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F3:
		visible = not visible
		get_viewport().set_input_as_handled()


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
