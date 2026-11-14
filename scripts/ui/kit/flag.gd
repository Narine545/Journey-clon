class_name TideFlag
extends Control
## Сигнальный флаг выбора: полотно колышется вершинным шейдером,
## название и описание лежат на самом флаге. Наведение поднимает флаг,
## выбор — резкий взлёт вверх с брызгами.

signal flag_hovered(index: int)
signal flag_unhovered(index: int)
signal flag_pressed(index: int)

const SHADER := preload("res://shaders/flag_wave.gdshader")
const POLE_W := 18.0

var index := 0
var title_text := ""
var description := ""
var preview_text := ""
var tint: Color = TideTokens.DEEP
var form := 0 # 0 — прямоугольный, 1 — треугольный, 2 — вымпел
var rest_deg := 0.0
var period := 2.8
var phase := 0.0
var amplitude := 0.75

var _cloth: Polygon2D
var _material: ShaderMaterial
var _title: Label
var _desc: Label
var _plate: TidePanelTorn
var _preview: Label
var _hover := 0.0
var _lean := 0.0
var _time := 0.0
var _locked := false
var _tween: Tween
var _ink_text := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	resized.connect(_on_resized)
	mouse_entered.connect(_on_enter)
	mouse_exited.connect(_on_exit)
	_build()
	_on_resized()


func set_content(
	order: int,
	title_value: String,
	desc_value: String,
	preview_value: String,
	color: Color,
	shape: int
) -> void:
	index = order
	title_text = title_value
	description = desc_value
	preview_text = preview_value
	tint = color
	form = shape
	_ink_text = tint.get_luminance() > 0.34
	if _title == null:
		return
	_title.text = title_text.to_upper()
	_desc.text = description
	_preview.text = preview_text
	_apply_text_colors()
	_rebuild_cloth()
	_layout_text()


func _build() -> void:
	_cloth = Polygon2D.new()
	_cloth.name = "Cloth"
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_material.set_shader_parameter("amplitude", 13.0)
	_material.set_shader_parameter("speed", 2.3)
	_material.set_shader_parameter("droop", 1.0)
	_material.set_shader_parameter("straighten", 0.0)
	_material.set_shader_parameter("time_offset", float(index) * 1.7)
	_cloth.material = _material
	_cloth.color = tint
	add_child(_cloth)

	_title = Label.new()
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	add_child(_title)

	_desc = Label.new()
	_desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_desc)

	_plate = TidePanelTorn.new()
	_plate.teeth = false
	_plate.cut = 10.0
	_plate.paper = TideTokens.FOAM
	_plate.underprint = TideTokens.ink_alpha(0.55)
	_plate.underprint_offset = Vector2(5.0, 6.0)
	_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_plate)

	_preview = Label.new()
	_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_preview.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	TideTokens.style_mono(_preview, 19, TideTokens.INK)
	_plate.add_child(_preview)


func _apply_text_colors() -> void:
	var ink := TideTokens.INK if _ink_text else TideTokens.FOAM
	TideTokens.style_title(_title, 34, ink, 0)
	TideTokens.style_body(_desc, 23, Color(ink, 0.92))


func _rebuild_cloth() -> void:
	if _cloth == null:
		return
	var cloth_width := maxf(60.0, size.x - POLE_W - 8.0)
	var cloth_height := maxf(80.0, size.y - 8.0)
	var data := TideShapes.cloth(form, cloth_width, cloth_height, 16, 10)
	var polygon: PackedVector2Array = data["polygon"]
	var shifted := PackedVector2Array()
	for point in polygon:
		shifted.append(point + Vector2(POLE_W, 4.0))
	_cloth.polygon = shifted
	_cloth.uv = shifted
	var triangles: Array[PackedInt32Array] = []
	triangles.assign(data["triangles"])
	_cloth.polygons = triangles
	_cloth.color = tint
	_material.set_shader_parameter("cloth_size", Vector2(cloth_width, cloth_height))


func _on_resized() -> void:
	pivot_offset = size * 0.5
	_rebuild_cloth()
	_layout_text()


func _layout_text() -> void:
	if _title == null:
		return
	var pad := 34.0
	var width := maxf(120.0, size.x - POLE_W - pad * 2.0)
	if form == 1:
		width = maxf(120.0, width * 0.62)
	_title.position = Vector2(POLE_W + pad, 30.0)
	_title.size = Vector2(width, 92.0)
	_title.pivot_offset = _title.size * 0.5
	_title.rotation = deg_to_rad(-1.2)
	_desc.position = Vector2(POLE_W + pad, 118.0)
	_desc.size = Vector2(width, 96.0)
	_desc.rotation = deg_to_rad(0.6)
	var plate_width := minf(320.0, maxf(150.0, size.x * 0.56))
	_plate.position = Vector2(POLE_W + pad * 0.55, size.y - 92.0)
	_plate.size = Vector2(plate_width, 66.0)
	_plate.pivot_offset = _plate.size * 0.5
	_plate.rotation = deg_to_rad(-2.4)
	_plate.queue_redraw()
	_preview.position = Vector2(12.0, 8.0)
	_preview.size = Vector2(plate_width - 24.0, 50.0)
	_preview.vertical_alignment = VERTICAL_ALIGNMENT_CENTER


func _process(delta: float) -> void:
	_time += delta
	if _locked:
		return
	var sway := sin(TAU * _time / period + phase) * amplitude * (1.0 - _hover * 0.85)
	rotation = deg_to_rad(rest_deg * (1.0 - _hover) + _lean + sway)


func _on_enter() -> void:
	if _locked:
		return
	flag_hovered.emit(index)
	_animate(1.0)


func _on_exit() -> void:
	if _locked:
		return
	flag_unhovered.emit(index)
	_animate(0.0)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index == MOUSE_BUTTON_LEFT and mouse.pressed and not _locked:
			accept_event()
			flag_pressed.emit(index)


func _animate(target: float) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_method(_set_hover, _hover, target, TideTokens.HOVER_TIME * 2.0).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "scale", Vector2.ONE * (1.0 + 0.06 * target), TideTokens.HOVER_TIME * 2.0).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _set_hover(value: float) -> void:
	_hover = clampf(value, 0.0, 1.2)
	if _material != null:
		_material.set_shader_parameter("straighten", clampf(_hover, 0.0, 1.0))
		_material.set_shader_parameter("droop", 1.0 - clampf(_hover, 0.0, 1.0) * 0.8)


## Пригнуть и погасить флаг, пока наведён соседний.
func dim(amount: bool) -> void:
	if _locked:
		return
	var target_alpha := 1.0
	var lean := 0.0
	if amount:
		target_alpha = 0.4
		lean = 2.2
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", target_alpha, TideTokens.HOVER_TIME * 2.0)
	tween.tween_method(
		func(value: float) -> void: _lean = value, _lean, lean, TideTokens.HOVER_TIME * 2.0
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func hover_from_keyboard(active: bool) -> void:
	if _locked:
		return
	_animate(1.0 if active else 0.0)


func set_locked(value: bool) -> void:
	_locked = value
	mouse_filter = Control.MOUSE_FILTER_IGNORE if value else Control.MOUSE_FILTER_STOP


## Выбранный флаг резко взлетает вверх, полотно выпрямляется, брызги.
func fly_up() -> void:
	_locked = true
	_lean = 0.0
	if _material != null:
		_material.set_shader_parameter("straighten", 1.0)
		_material.set_shader_parameter("droop", 0.0)
	TideFx.splash(get_parent(), position + size * 0.5, 16, TideTokens.FOAM)
	TideFx.splash(get_parent(), position + size * 0.5, 10, tint)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position:y", position.y - 250.0, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2.ONE * 1.1, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "rotation", 0.0, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## Остальные падают вниз и гаснут.
func fall_down() -> void:
	_locked = true
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position:y", position.y + 210.0, 0.34).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.tween_property(self, "rotation", rotation + deg_to_rad(13.0), 0.34).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)


## Древко, фал и наконечник — рисуются кодом, никаких картинок.
func _draw() -> void:
	draw_line(
		Vector2(POLE_W * 0.5, 2.0),
		Vector2(POLE_W * 0.5, size.y),
		TideTokens.FOAM,
		7.0,
		true
	)
	draw_circle(Vector2(POLE_W * 0.5, 6.0), 9.0, TideTokens.FOAM)
	draw_circle(Vector2(POLE_W * 0.5, 6.0), 4.0, TideTokens.INK)
	if _hover > 0.05:
		var halo := PackedVector2Array()
		var inset := 6.0
		halo.append(Vector2(POLE_W + inset, inset))
		halo.append(Vector2(size.x - inset, inset))
		halo.append(Vector2(size.x - inset, size.y - inset - 10.0))
		halo.append(Vector2(POLE_W + inset, size.y - inset))
		draw_polyline(TideShapes.closed(halo), TideTokens.foam_alpha(0.5 * _hover), 2.0, true)
