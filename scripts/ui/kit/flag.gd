class_name TideFlag
extends Control
## Сигнальный флаг выбора на мачте. Полотно колышется вершинным шейдером,
## название и описание лежат на флаге, цифры «было → стало» висят биркой на
## фале под полотном. Мачта уходит за нижний край экрана, качка идёт от её
## основания — флаг ходит как топ мачты на волне.

signal flag_hovered(index: int)
signal flag_unhovered(index: int)
signal flag_pressed(index: int)

const SHADER := preload("res://shaders/flag_wave.gdshader")
const POLE_W := 18.0
const TITLE_MAX := 32
const TITLE_MIN := 16
const DESC_MAX := 23
const DESC_MIN := 15

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
## Длина мачты от верха полотна вниз.
var mast := 760.0
## Кегль заголовка после подгонки (экран выравнивает его между флагами).
var title_point := TITLE_MAX

var _cloth: Polygon2D
var _band: Polygon2D
var _shadow: Polygon2D
var _material: ShaderMaterial
var _title: Label
var _desc: Label
var _tag: TidePanelTorn
var _preview: Label
var _key: Label
var _hover := 0.0
var _lean := 0.0
var _time := 0.0
var _locked := false
var _tween: Tween
var _home := Vector2.ZERO
var _has_home := false


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
	title_text = title_value.to_upper()
	description = desc_value
	preview_text = preview_value.strip_edges()
	tint = color
	form = shape
	if _title == null:
		return
	_title.text = title_text
	_desc.text = description
	_preview.text = preview_text
	_key.text = str(order + 1)
	_rebuild_cloth()
	_layout_text(TITLE_MAX)


## Вернуть флаг на мачту после прошлого выбора (взлёт/падение).
func restore() -> void:
	if not _has_home:
		_home = position
		_has_home = true
	position = _home
	scale = Vector2.ONE
	rotation = deg_to_rad(rest_deg)
	modulate.a = 1.0
	_lean = 0.0
	_set_hover(0.0)


func _text_color() -> Color:
	return TideTokens.INK if tint.get_luminance() > 0.34 else TideTokens.FOAM


func _build() -> void:
	# Оттиск-подложка: плоский сдвинутый силуэт, волнуется тем же материалом.
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_material.set_shader_parameter("amplitude", 11.0)
	_material.set_shader_parameter("speed", 2.3)
	_material.set_shader_parameter("droop", 1.0)
	_material.set_shader_parameter("straighten", 0.0)
	_material.set_shader_parameter("time_offset", float(index) * 1.7)
	_shadow = Polygon2D.new()
	_shadow.color = TideTokens.ink_alpha(0.6)
	_shadow.material = _material
	add_child(_shadow)
	_cloth = Polygon2D.new()
	_cloth.material = _material
	add_child(_cloth)
	# Полоса у свободной кромки — рисунок сигнального флага.
	_band = Polygon2D.new()
	_band.material = _material
	_band.color = TideTokens.FOAM
	add_child(_band)

	_title = Label.new()
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_title.add_theme_constant_override("line_spacing", -2)
	add_child(_title)

	_desc = Label.new()
	_desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	add_child(_desc)

	_tag = TidePanelTorn.new()
	_tag.teeth = false
	_tag.cut = 0.0
	_tag.skew = 7.0
	_tag.paper = TideTokens.FOAM
	_tag.underprint = TideTokens.ink_alpha(0.6)
	_tag.underprint_offset = Vector2(5.0, 6.0)
	_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_tag)
	_preview = Label.new()
	_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_preview.autowrap_mode = TextServer.AUTOWRAP_OFF
	_preview.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	TideTokens.style_mono(_preview, 18, TideTokens.INK)
	_preview.add_theme_constant_override("line_spacing", 2)
	_tag.add_child(_preview)

	_key = Label.new()
	_key.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_key.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	TideTokens.style_mono(_key, 22, TideTokens.INK)
	add_child(_key)


func _cloth_size() -> Vector2:
	return Vector2(maxf(60.0, size.x - POLE_W), maxf(96.0, size.y))


func _cloth_origin() -> Vector2:
	return Vector2(POLE_W, 0.0)


func _rebuild_cloth() -> void:
	if _cloth == null:
		return
	var cloth := _cloth_size()
	var shifted := TideShapes.offset(TideShapes.flag_outline(form, cloth.x, cloth.y), _cloth_origin())
	_cloth.polygon = shifted
	_cloth.color = tint
	_shadow.polygon = TideShapes.offset(shifted, Vector2(9.0, 10.0))
	_band.visible = form == 0
	if form == 0:
		var strip := PackedVector2Array([
			Vector2(cloth.x * 0.84, 0.0), Vector2(cloth.x, 0.0),
			Vector2(cloth.x, cloth.y), Vector2(cloth.x * 0.84, cloth.y),
		])
		_band.polygon = TideShapes.offset(TideShapes.subdivide(strip), _cloth_origin())
	_material.set_shader_parameter("cloth_size", cloth + Vector2(POLE_W, 0.0))


func _on_resized() -> void:
	# Ось качки и масштаба — основание мачты.
	pivot_offset = Vector2(POLE_W * 0.5, mast)
	_rebuild_cloth()
	_layout_text(title_point)


func _widest_word(font: Font, value: String, point: int) -> float:
	var widest := 0.0
	for word in value.split(" ", false):
		widest = maxf(widest, font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, point).x)
	return widest


func _wrapped_height(font: Font, value: String, width: float, point: int) -> float:
	if value.is_empty():
		return 0.0
	return font.get_multiline_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, width, point).y


## Посадка текста: заголовок и описание целиком внутри безопасной зоны
## полотна. Кегль уменьшается, пока не поместятся и самое длинное слово,
## и вся колонка по высоте.
func _layout_text(title_cap: int) -> void:
	if _title == null:
		return
	var cloth := _cloth_size()
	var box := TideShapes.flag_text_box(form, cloth.x, cloth.y)
	box.position += _cloth_origin()
	var title_font := TideTokens.title_font()
	var body_font := TideTokens.body_font()
	var gap := 10.0
	var t_point := clampi(title_cap, TITLE_MIN, TITLE_MAX)
	var d_point := DESC_MAX
	for _attempt in range(40):
		var fits_word := _widest_word(title_font, title_text, t_point) <= box.size.x
		var total := (
			_wrapped_height(title_font, title_text, box.size.x, t_point)
			+ gap
			+ _wrapped_height(body_font, description, box.size.x, d_point)
		)
		if fits_word and total <= box.size.y:
			break
		if t_point > TITLE_MIN and (not fits_word or t_point >= d_point + 3):
			t_point -= 1
		elif d_point > DESC_MIN:
			d_point -= 1
		elif t_point > TITLE_MIN:
			t_point -= 1
		else:
			break
	title_point = t_point
	var ink := _text_color()
	TideTokens.style_title(_title, t_point, ink, 0)
	TideTokens.style_body(_desc, d_point, Color(ink, 0.9))
	var title_h := _wrapped_height(title_font, title_text, box.size.x, t_point)
	var desc_h := _wrapped_height(body_font, description, box.size.x, d_point)
	var top := box.position.y
	if form != 0:
		# На сходящихся полотнах колонка центрируется по высоте.
		top += maxf(0.0, (box.size.y - title_h - gap - desc_h) * 0.5)
	_title.position = Vector2(box.position.x, top)
	_title.size = Vector2(box.size.x, title_h + 4.0)
	_desc.position = Vector2(box.position.x, top + title_h + gap)
	_desc.size = Vector2(box.size.x, desc_h + 4.0)

	# Бирка на фале под полотном: «было → стало».
	_tag.visible = not preview_text.is_empty()
	var mono := TideTokens.mono_font()
	var lines := preview_text.split("\n", false)
	var widest := 0.0
	for line in lines:
		widest = maxf(widest, mono.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x)
	var tag_size := Vector2(widest + 44.0, float(maxi(1, lines.size())) * 27.0 + 20.0)
	_tag.position = Vector2(POLE_W + 26.0, size.y + 30.0)
	_tag.size = tag_size
	_tag.pivot_offset = Vector2.ZERO
	_tag.rotation = deg_to_rad(-2.0)
	_preview.position = Vector2(22.0, 0.0)
	_preview.size = Vector2(tag_size.x - 30.0, tag_size.y)
	# Номер клавиши — марка на мачте.
	_key.position = Vector2(POLE_W * 0.5 - 19.0, size.y + tag_size.y + 62.0)
	_key.size = Vector2(38.0, 38.0)
	queue_redraw()


func apply_title_point(point: int) -> void:
	_layout_text(point)


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


## Наведение: полотно выпрямляется, флаг подрастает (от основания мачты —
## значит, поднимается).
func _animate(target: float) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_method(_set_hover, _hover, target, TideTokens.HOVER_TIME * 2.0).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "scale", Vector2.ONE * (1.0 + 0.05 * target), TideTokens.HOVER_TIME * 2.0).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _set_hover(value: float) -> void:
	_hover = clampf(value, 0.0, 1.2)
	if _material != null:
		_material.set_shader_parameter("straighten", clampf(_hover, 0.0, 1.0))
		_material.set_shader_parameter("droop", 1.0 - clampf(_hover, 0.0, 1.0) * 0.8)


## Пригнуть и погасить флаг до 40 %, пока наведён соседний.
func dim(amount: bool) -> void:
	if _locked:
		return
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 0.4 if amount else 1.0, TideTokens.HOVER_TIME * 2.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_method(
		func(value: float) -> void: _lean = value, _lean, 2.4 if amount else 0.0, TideTokens.HOVER_TIME * 2.0
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func hover_from_keyboard(active: bool) -> void:
	if _locked:
		return
	_animate(1.0 if active else 0.0)


func set_locked(value: bool) -> void:
	_locked = value
	mouse_filter = Control.MOUSE_FILTER_IGNORE if value else Control.MOUSE_FILTER_STOP


## Выбранный флаг резко поднимают: рывок вверх, полотно натянуто, брызги.
func fly_up(rise: float = 70.0) -> void:
	_locked = true
	_lean = 0.0
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_set_hover(1.0)
	modulate.a = 1.0
	TideFx.splash(get_parent(), position + Vector2(size.x * 0.5, size.y), 16, TideTokens.FOAM)
	TideFx.splash(get_parent(), position + Vector2(size.x * 0.3, size.y * 0.6), 10, tint)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position:y", position.y - rise, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2.ONE * 1.06, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "rotation", 0.0, 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## Остальные флаги спускают: падают вниз и гаснут.
func fall_down() -> void:
	_locked = true
	if _tween != null and _tween.is_valid():
		_tween.kill()
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position:y", position.y + 420.0, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "modulate:a", 0.0, 0.26).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "rotation", rotation + deg_to_rad(4.0), 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)


## Мачта, топ и марка с номером — рисуются кодом, никаких картинок.
func _draw() -> void:
	var x := POLE_W * 0.5
	draw_line(Vector2(x, -22.0), Vector2(x, mast), TideTokens.FOAM, 8.0)
	# Топ мачты: гранёный, без скруглений.
	var cap := TideShapes.offset(TideShapes.link(Vector2(26.0, 14.0), 5.0), Vector2(x - 13.0, -34.0))
	TideShapes.fill(self, cap, TideTokens.FOAM)
	# Фал от полотна к бирке.
	if _tag != null and _tag.visible:
		draw_line(Vector2(POLE_W + 34.0, size.y - 4.0), Vector2(POLE_W + 34.0, size.y + 34.0), TideTokens.foam_alpha(0.45), 2.0)
	if _key != null:
		var plate := Rect2(_key.position, _key.size)
		draw_rect(plate, TideTokens.FOAM)
