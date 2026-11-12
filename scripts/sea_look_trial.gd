class_name SeaLookTrial
extends CanvasLayer
## Gradient palette inspiration: Koaleszenz (MIT), see SHADER-CREDITS.md.
## Session-only sea comparisons and instant fog preview. No new volume or screen pass.
var main: BoatMain
var _panel: PanelContainer
var _depth_toggle: CheckButton
var _mist_toggle: CheckButton
var _palette: GradientTexture1D


func setup(scene: BoatMain) -> void:
	main = scene
	layer = 21
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.16, 0.43, 1.0])
	gradient.colors = PackedColorArray(
		[
			Color(0.30, 0.62, 0.52),
			Color(0.18, 0.48, 0.48),
			Color(0.075, 0.28, 0.36),
			Color(0.03, 0.12, 0.25)
		]
	)
	_palette = GradientTexture1D.new()
	_palette.width = 256
	_palette.gradient = gradient
	main.water.set_param("depth_palette", _palette)
	_panel = PanelContainer.new()
	var skin := StyleBoxFlat.new()
	skin.bg_color = Color(0.025, 0.06, 0.08, 0.9)
	skin.content_margin_left = 12
	skin.content_margin_right = 12
	skin.content_margin_top = 8
	skin.content_margin_bottom = 8
	_panel.add_theme_stylebox_override("panel", skin)
	add_child(_panel)
	var box := VBoxContainer.new()
	_panel.add_child(box)
	var caption := Label.new()
	caption.text = "МОРЕ · СРАВНЕНИЕ"
	caption.add_theme_font_size_override("font_size", 16)
	box.add_child(caption)
	_depth_toggle = CheckButton.new()
	_depth_toggle.text = "Цвет по глубине"
	_depth_toggle.add_theme_font_size_override("font_size", 18)
	_depth_toggle.tooltip_text = "Палитра по настоящей глубине дна. Выкл. — прежний цвет воды."
	_depth_toggle.toggled.connect(_set_depth)
	box.add_child(_depth_toggle)
	_mist_toggle = CheckButton.new()
	_mist_toggle.text = "Низкие клочья тумана"
	_mist_toggle.add_theme_font_size_override("font_size", 18)
	_mist_toggle.tooltip_text = "Более редкие низкие банки. Выкл. — прежний туман. Зависит от погоды."
	_mist_toggle.toggled.connect(_set_mist)
	box.add_child(_mist_toggle)
	var fog_toggle := CheckButton.new()
	fog_toggle.text = "Туман сразу"
	fog_toggle.add_theme_font_size_override("font_size", 18)
	fog_toggle.tooltip_text = "Туман без ожидания погоды, днём и ночью. Выкл. — текущая погода."
	fog_toggle.toggled.connect(_set_instant_fog)
	box.add_child(fog_toggle)
	_depth_toggle.set_pressed_no_signal(true)
	_set_depth(true)
	var supported := main._rme4_material != null
	_mist_toggle.disabled = not supported
	_mist_toggle.set_pressed_no_signal(false)
	if not supported:
		_mist_toggle.tooltip_text = "Объёмный туман недоступен в текущем рендерере."
	_set_mist(false)
	get_viewport().size_changed.connect(_layout)
	_layout()


func _set_depth(enabled: bool) -> void:
	main.water.set_param("depth_palette_strength", 1.0 if enabled else 0.0)


func _set_mist(enabled: bool) -> void:
	if main._rme4_material != null:
		main._rme4_material.set_shader_parameter("mist_pockets", 1.0 if enabled else 0.0)


func _set_instant_fog(enabled: bool) -> void:
	main.debug_instant_fog = enabled
	main._apply_atmosphere(main.night01)


func _layout() -> void:
	_panel.position = Vector2(24, maxf(420.0, get_viewport().get_visible_rect().size.y - 275.0))
	_panel.custom_minimum_size = Vector2(300, 0)


func _process(_delta: float) -> void:
	visible = (
		not main.inspection_active()
		and (main.raid == null or not main.raid.modal())
		and (main.raid == null or not main.raid.engaged() or main.raid.hud.debug_tools_open())
	)
