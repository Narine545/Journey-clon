class_name HarborViewControls
extends Control
## Небольшие подсказки в порту вместо приборной панели судна.
var main: BoatMain
var _group: Control
var _view: TideButton


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_group = TideKit.group(self, Rect2(0, 0, 920, 76))
	var panel := TideKit.panel(_group, Rect2(0, 0, 920, 76), TideTokens.ink_alpha(0.92), TideTokens.FLARE, false)
	panel.underprint_offset = Vector2(5, 5)
	_view = TideKit.button(_group, "", Rect2(14, 10, 300, 54), TideButton.Shape.SOLID,
		TideTokens.SONAR, 1, 19, TideTokens.INK)
	_view.pressed.connect(_toggle)
	TideKit.text(_group, "E · ОТЧАЛИТЬ     КЛИК ПО ДОМУ · ЖИТЕЛЬ", Vector2(335, 23),
		1, 18, TideTokens.FOAM, 570)
	resized.connect(_layout)
	_layout()


func _layout() -> void:
	var screen := Vector2(get_viewport().get_texture().get_size())
	var factor := minf(screen.x / 1920.0, screen.y / 1080.0)
	_group.scale = Vector2.ONE * factor
	_group.position = Vector2((screen.x - 920.0) * 0.5, screen.y - 100.0 * factor - 76.0 * (1.0 - factor) * 0.5)


func _process(_delta: float) -> void:
	if main == null:
		return
	visible = main.harbor != null and main.harbor.moored and not main.menu_open \
		and not main.village_panel_open and not main.inspection_active() \
		and not (main.raid != null and main.raid.engaged()) \
		and not (main.rest != null and main.rest.visible)
	if visible:
		_view.set_caption("V · К ПРИСТАНИ" if main.port_show_village else "V · К ПОСЁЛКУ")


func _toggle() -> void:
	if main != null:
		main.toggle_port_camera()
