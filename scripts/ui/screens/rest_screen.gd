class_name TideRest
extends Control
## Отдых у причала: побездельничать, вздремнуть или проспать до утра.
## Сутки идут медленно, а отдых — способ быстро перевести часы.
##
## 1 / 2 / 3 или клик — выбрать, Esc — закрыть. После выбора картинка
## раскрывается кинополосой, часы на глазах пробегают нужное время.

signal rested(hours: float)
signal closed

const OPTIONS := [
	{
		"file": "rest_laze", "title": "ПОБЕЗДЕЛЬНИЧАТЬ", "hours": 1.0,
		"line": "Мимо считает облака. Час как не бывало.",
	},
	{
		"file": "rest_nap", "title": "ВЗДРЕМНУТЬ", "hours": 3.0,
		"line": "Шляпа на лицо — и трёх часов как не бывало.",
	},
	{
		"file": "rest_sleep", "title": "СПАТЬ ДО УТРА", "hours": -1.0,
		"line": "Тётя Форнэль разбудит. Наверное.",
	},
]
const WAKE_HOUR := 7.0
const CARD := Vector2(540, 560)
const BAND := Rect2(0, 170, 1920, 700)

var _hour := 12.0
var _busy := false
var _menu: Control
var _cards: Array[Control] = []
var _subs: Array[Label] = []
var _pictures: Array[TextureRect] = []
var _now: Label
var _play: Control
var _play_shot: TextureRect
var _play_clock: Label
var _play_line: Label
var _play_title: Label
var _tween: Tween


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_build()


static func clock_text(hour: float) -> String:
	var total := int(round(fposmod(hour, 24.0) * 60.0)) % 1440
	return "%02d:%02d" % [int(total / 60.0), total % 60]


func _hours_of(index: int) -> float:
	var hours := float(OPTIONS[index]["hours"])
	if hours > 0.0:
		return hours
	# До утра: до ближайших 07:00, но не меньше часа сна.
	var until := fposmod(WAKE_HOUR - _hour, 24.0)
	return until + 24.0 if until < 1.0 else until


func _build() -> void:
	var shade := ColorRect.new()
	shade.color = TideTokens.ink_alpha(0.9)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	TideKit.place(shade, Rect2(Vector2(-400, -300), TideTokens.BASE + Vector2(800, 600)))
	add_child(shade)
	TideKit.isobaths(self, Rect2(Vector2.ZERO, TideTokens.BASE), 0.06, 36.0)

	_menu = TideKit.group(self, Rect2(Vector2.ZERO, TideTokens.BASE))
	TideKit.text(_menu, "ТИХАЯ БУХТА · У ПРИЧАЛА", Vector2(102, 70), 1, 22, TideTokens.SONAR)
	TideKit.headline(_menu, "ПЕРЕДОХНУТЬ", Vector2(96, 100), 900.0, 88, TideTokens.FOAM, 8, -10.0)
	_now = TideKit.text(
		_menu, "", Vector2(1120, 120), 1, 30, TideTokens.FOAM, 700.0, HORIZONTAL_ALIGNMENT_RIGHT
	)
	for index in range(OPTIONS.size()):
		var at := Vector2(96.0 + (CARD.x + 54.0) * float(index), 300.0 + 26.0 * float(index % 2))
		var card := TideKit.group(_menu, Rect2(at, CARD), -1.5 + 1.5 * float(index))
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var paper := TideKit.panel(
			card, Rect2(Vector2.ZERO, CARD), TideTokens.FOAM,
			[TideTokens.SONAR, TideTokens.FLARE, TideTokens.DEEP][index], true
		)
		paper.hatch_color = TideTokens.deep_alpha(0.1)
		var window := Control.new()
		window.mouse_filter = Control.MOUSE_FILTER_IGNORE
		window.clip_contents = true
		TideKit.place(window, Rect2(24, 24, CARD.x - 48.0, 277))
		card.add_child(window)
		var picture := TextureRect.new()
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		TideKit.place(picture, Rect2(Vector2.ZERO, window.size))
		window.add_child(picture)
		_pictures.append(picture)
		TideKit.headline(
			card, String(OPTIONS[index]["title"]), Vector2(26, 322), CARD.x - 52.0, 40, TideTokens.INK, 4, -8.0
		)
		var sub := TideKit.text(card, "", Vector2(30, 392), 1, 24, TideTokens.ink_alpha(0.8))
		_subs.append(sub)
		TideKit.poly(
			card, TideShapes.plate(Vector2(64, 64), 10.0), TideTokens.INK, Vector2(CARD.x - 94.0, 436.0)
		)
		TideKit.text(
			card, str(index + 1), Vector2(CARD.x - 94.0, 448.0), 1, 34, TideTokens.FOAM, 64.0,
			HORIZONTAL_ALIGNMENT_CENTER
		)
		card.gui_input.connect(_on_card_input.bind(index))
		card.mouse_entered.connect(_hover.bind(card, 1.04))
		card.mouse_exited.connect(_hover.bind(card, 1.0))
		add_child(TideFx.bob(card, -1.5 + 1.5 * float(index), 0.5, 2.7 + 0.3 * float(index), 1.3 * float(index)))
		_cards.append(card)
	TideKit.text(
		_menu, "1 · 2 · 3 — ВЫБРАТЬ        ESC — НЕ СЕЙЧАС", Vector2(102, 986), 1, 20,
		TideTokens.foam_alpha(0.8)
	)

	# Сцена отдыха: картинка кинополосой, часы и подпись под ней.
	_play = TideKit.group(self, Rect2(Vector2.ZERO, TideTokens.BASE))
	var ink := ColorRect.new()
	ink.color = TideTokens.INK
	ink.mouse_filter = Control.MOUSE_FILTER_IGNORE
	TideKit.place(ink, Rect2(Vector2(-400, -300), TideTokens.BASE + Vector2(800, 600)))
	_play.add_child(ink)
	var clip := Control.new()
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip.clip_contents = true
	TideKit.place(clip, BAND)
	_play.add_child(clip)
	_play_shot = TextureRect.new()
	_play_shot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_play_shot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_play_shot.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	TideKit.place(_play_shot, Rect2(Vector2.ZERO, BAND.size))
	clip.add_child(_play_shot)
	for edge in range(2):
		var rule := ColorRect.new()
		rule.color = TideTokens.FLARE if edge == 0 else TideTokens.SONAR
		rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
		TideKit.place(rule, Rect2(-400, BAND.position.y - 8.0 if edge == 0 else BAND.end.y, 2720, 8))
		_play.add_child(rule)
	_play_title = TideKit.text(_play, "", Vector2(102, 64), 1, 24, TideTokens.SONAR)
	_play_clock = TideKit.text(
		_play, "", Vector2(1120, 40), 1, 84, TideTokens.FOAM, 700.0, HORIZONTAL_ALIGNMENT_RIGHT
	)
	_play_line = TideKit.block(_play, "", Rect2(160, BAND.end.y + 50.0, 1600, 120), 0, 46, TideTokens.FOAM, 2)
	_play_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_play.hide()


func _hover(card: Control, factor: float) -> void:
	if _busy:
		return
	var tween := card.create_tween()
	tween.tween_property(card, "scale", Vector2(factor, factor), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_card_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		choose(index)


func open(hour: float) -> void:
	_hour = hour
	_busy = false
	show()
	mouse_filter = Control.MOUSE_FILTER_STOP
	modulate.a = 0.0
	_menu.show()
	_play.hide()
	_now.text = "СЕЙЧАС %s" % clock_text(hour)
	for index in range(OPTIONS.size()):
		_pictures[index].texture = TideStory.picture(String(OPTIONS[index]["file"]))
		var hours := _hours_of(index)
		_subs[index].text = "+%d Ч  →  %s" % [roundi(hours), clock_text(hour + hours)]
		if float(OPTIONS[index]["hours"]) < 0.0:
			_subs[index].text = "ДО %s  ·  +%.1f Ч" % [clock_text(WAKE_HOUR), hours]
		_cards[index].scale = Vector2.ONE
		TideFx.pop_in(_cards[index], 0.6, -10.0)
	_fade_to(1.0, 0.3)


func _fade_to(alpha: float, duration: float) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", alpha, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func close() -> void:
	hide()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false
	if _tween != null and _tween.is_valid():
		_tween.kill()
	for picture in _pictures:
		picture.texture = null
	_play_shot.texture = null
	closed.emit()


func choose(index: int) -> void:
	if _busy or index < 0 or index >= OPTIONS.size():
		return
	_busy = true
	var hours := _hours_of(index)
	_menu.hide()
	_play.show()
	_play_shot.texture = _pictures[index].texture
	_play_shot.pivot_offset = BAND.size * 0.5
	_play_shot.scale = Vector2(1.14, 1.14)
	_play_title.text = "ТИХАЯ БУХТА · %s" % String(OPTIONS[index]["title"])
	_play_line.text = String(OPTIONS[index]["line"])
	_play_line.visible_ratio = 0.0
	_set_play_clock(_hour)
	TideFx.pop_in(_play, 0.92, 0.0)
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(_play_shot, "scale", Vector2.ONE, 3.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_play_line, "visible_ratio", 1.0, 0.9)
	# Часы пробегают время отдыха: разгон и мягкая остановка.
	_tween.tween_method(_set_play_clock, _hour, _hour + hours, 2.2).set_delay(0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_tween.chain().tween_interval(0.5)
	_tween.chain().tween_callback(func() -> void: rested.emit(hours))
	_tween.chain().tween_property(self, "modulate:a", 0.0, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_tween.chain().tween_callback(close)


func _set_play_clock(hour: float) -> void:
	_play_clock.text = clock_text(hour)


## Кадр сцены отдыха без ожидания (витрина).
func show_play(index: int) -> void:
	choose(index)
	if _tween != null and _tween.is_valid():
		_tween.kill()
	modulate.a = 1.0
	_play.scale = Vector2.ONE
	_play.rotation = 0.0
	_play_shot.scale = Vector2.ONE
	_play_line.visible_ratio = 1.0
	_set_play_clock(_hour + _hours_of(index))


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_1, KEY_2, KEY_3:
				choose(int(event.physical_keycode) - KEY_1)
				get_viewport().set_input_as_handled()
			KEY_ESCAPE, KEY_Z:
				if not _busy:
					close()
				get_viewport().set_input_as_handled()
			_:
				# Пока идёт отдых, игра клавиш не получает.
				get_viewport().set_input_as_handled()
