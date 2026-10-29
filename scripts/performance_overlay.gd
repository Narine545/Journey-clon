class_name PerformanceOverlay
extends CanvasLayer
## Необязательная диагностика M2: скрыта до нажатия F3, игровой HUD не засоряет.
var _label: Label
var _refresh := 0.0


func _ready() -> void:
	layer = 21
	_label = Label.new()
	_label.position = Vector2(18.0, 16.0)
	_label.add_theme_font_size_override("font_size", 20)
	_label.add_theme_color_override("font_color", Color(1.0, 0.94, 0.78))
	_label.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.03, 0.95))
	_label.add_theme_constant_override("outline_size", 4)
	add_child(_label)
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F3:
		visible = not visible
		_refresh = 0.0


func _process(delta: float) -> void:
	if not visible:
		return
	_refresh -= delta
	if _refresh <= 0.0:
		_label.text = "FPS: %d" % Engine.get_frames_per_second()
		_refresh = 0.5
