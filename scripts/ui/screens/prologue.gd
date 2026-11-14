class_name TidePrologue
extends Control
## Пролог перед выходом в рейс: героиня справа во весь рост, реплики — на
## рваном листе слева. Мама остаётся за кадром: её слова приходят «со второго
## этажа» на красной плашке, а на экране — реакция героини.
##
## Пробел / Enter / клик — дальше (или допечатать реплику), Esc — пропустить.

signal finished

const BOX_RECT := Rect2(96, 600, 1040, 340)
const BOX_DEG := -1.6
const BACK_RECT := Rect2(1090, -80, 720, 1300)
const BACK_DEG := 4.0
const FACE_RECT := Rect2(1000, 30, 800, 1434)
const TYPE_SPEED := 52.0

var lines: Array = TideStory.PROLOGUE
var _index := -1
var _active := false
var _back: TidePanelTorn
var _face: TextureRect
var _face_name := ""
var _box: Control
var _name_plate: Polygon2D
var _name: Label
var _body: Label
var _counter: Label
var _hint: Label
var _skip: TideButton
var _type: Tween


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_build()


func _build() -> void:
	var shade := ColorRect.new()
	shade.color = TideTokens.ink_alpha(0.88)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	TideKit.place(shade, Rect2(Vector2(-400, -300), TideTokens.BASE + Vector2(800, 600)))
	add_child(shade)
	TideKit.isobaths(self, Rect2(Vector2.ZERO, TideTokens.BASE), 0.06, 36.0)

	# Полоса-задник за героиней: уходит за верх и низ кадра.
	_back = TideKit.panel(self, BACK_RECT, TideTokens.DEEP, TideTokens.FLARE, true, BACK_DEG, false)
	_back.hatch_color = TideTokens.foam_alpha(0.07)
	_back.hatch_spacing = 8.0
	_back.underprint_offset = Vector2(-18.0, 0.0)

	_face = TextureRect.new()
	_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	TideKit.place(_face, FACE_RECT)
	_face.pivot_offset = Vector2(FACE_RECT.size.x * 0.5, FACE_RECT.size.y * 0.72)
	add_child(_face)

	# Шапка сцены.
	var head := TideKit.group(self, Rect2(96, 70, 900, 200), -3.0)
	TideKit.text(head, "ПРОЛОГ · СУББОТА, 05:40", Vector2(6, 0), 1, 22, TideTokens.SONAR)
	TideKit.headline(head, "ПЕРЕД ОТХОДОМ", Vector2(0, 34), 860.0, 96, TideTokens.FOAM, 8, -10.0)

	# Лист с репликой.
	_box = TideKit.group(self, BOX_RECT, BOX_DEG)
	var sheet := TideKit.panel(
		_box, Rect2(Vector2.ZERO, BOX_RECT.size), TideTokens.FOAM, TideTokens.FLARE, true
	)
	sheet.hatch_color = TideTokens.ink_alpha(0.05)
	_name_plate = TideKit.poly(_box, PackedVector2Array(), TideTokens.SONAR, Vector2(34, -30))
	_name = TideKit.text(_box, "", Vector2(62, -24), 2, 26, TideTokens.INK)
	_body = TideKit.block(
		_box, "", Rect2(60, 66, BOX_RECT.size.x - 120.0, 210), 0, 46, TideTokens.INK, 4
	)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_counter = TideKit.text(
		_box, "01 / 09", Vector2(60, BOX_RECT.size.y - 62.0), 1, 20, TideTokens.ink_alpha(0.7),
		BOX_RECT.size.x - 120.0, HORIZONTAL_ALIGNMENT_RIGHT
	)
	_hint = TideKit.text(
		self, "ПРОБЕЛ · КЛИК — ДАЛЬШЕ", Vector2(110, 980), 1, 20,
		TideTokens.foam_alpha(0.8)
	)
	_hint.rotation = deg_to_rad(BOX_DEG)
	_skip = TideKit.button(
		self, "ESC · ПРОПУСТИТЬ", Rect2(560, 966, 330, 56), TideButton.Shape.GHOST, TideTokens.SONAR,
		1, 20, TideTokens.SONAR, BOX_DEG
	)
	_skip.focus_mode = Control.FOCUS_NONE
	_skip.pressed.connect(skip)

	add_child(TideFx.bob(_box, BOX_DEG, 0.6, 2.9, 0.4))
	add_child(TideFx.bob(_back, BACK_DEG, 0.7, 3.1, 2.1))
	add_child(TideFx.bob(head, -3.0, 0.5, 2.6, 4.0))


func open() -> void:
	show()
	mouse_filter = Control.MOUSE_FILTER_STOP
	_active = true
	_index = -1
	TideFx.pop_in(_back, 0.8, -8.0)
	TideFx.pop_in(_box, 0.6, -8.0)
	TideFx.splash(self, BOX_RECT.position + Vector2(BOX_RECT.size.x * 0.5, BOX_RECT.size.y), 14)
	_advance()


func close() -> void:
	_active = false
	hide()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_face.texture = null
	_face_name = ""


func skip() -> void:
	if not _active:
		return
	close()
	finished.emit()


## Показать реплику по номеру сразу целиком (витрина и проверки).
func show_line(number: int) -> void:
	_finish_typing()
	_index = clampi(number, 0, lines.size() - 1) - 1
	_advance()
	_finish_typing()


func _typing() -> bool:
	return _type != null and _type.is_running()


func _finish_typing() -> void:
	if _type != null and _type.is_valid():
		_type.kill()
	_body.visible_ratio = 1.0


func _advance() -> void:
	if _typing():
		_finish_typing()
		return
	_index += 1
	if _index >= lines.size():
		skip()
		return
	var entry: Dictionary = lines[_index]
	var mother := int(entry.get("who", 0)) == 1
	_set_speaker(TideStory.MOTHER if mother else TideStory.HEROINE, mother)
	_set_face(String(entry.get("face", "")))
	_body.text = ("«%s»" % String(entry.get("line", "")))
	_body.visible_ratio = 0.0
	_counter.text = "%02d / %02d" % [_index + 1, lines.size()]
	var duration := maxf(0.2, float(_body.text.length()) / TYPE_SPEED)
	_type = create_tween()
	_type.tween_property(_body, "visible_ratio", 1.0, duration)


func _set_speaker(value: String, mother: bool) -> void:
	_name.text = value
	var width := TideTokens.font_of(2).get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
	_name.size.x = width + 8.0
	_name.add_theme_color_override("font_color", TideTokens.FOAM if mother else TideTokens.INK)
	_name_plate.color = TideTokens.FLARE if mother else TideTokens.SONAR
	_name_plate.polygon = TideShapes.plate(Vector2(width + 64.0, 58.0), 10.0, 10.0)
	# Плашка говорящего «шлёпается» на лист.
	_name_plate.scale = Vector2(1.18, 1.18)
	var tween := create_tween()
	tween.tween_property(_name_plate, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _set_face(face: String) -> void:
	if face.is_empty() or face == _face_name:
		return
	var texture := TideStory.portrait(face)
	if texture == null:
		return
	_face_name = face
	_face.texture = texture
	# Смена эмоции: короткий рывок с перелётом, без затуханий.
	_face.scale = Vector2(0.955, 0.955)
	_face.position = FACE_RECT.position + Vector2(22.0, 0.0)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_face, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_face, "position", FACE_RECT.position, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _gui_input(event: InputEvent) -> void:
	if not _active:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_advance()
		accept_event()


func _input(event: InputEvent) -> void:
	if not _active or not is_visible_in_tree():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_E:
				_advance()
				get_viewport().set_input_as_handled()
			KEY_ESCAPE:
				skip()
				get_viewport().set_input_as_handled()
