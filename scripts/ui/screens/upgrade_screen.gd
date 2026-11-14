class_name TideUpgradeScreen
extends Control
## Экран повышения уровня «ПОПУТНЫЙ ВЕТЕР» — витрина стиля TIDECUT.
##
## Три апгрейда — три сигнальных флага разных форм. Наведение поднимает флаг
## и пригибает остальные, выбор «взлетает» с брызгами и штампом.
## Тексты приходят снаружи: экран ничего не знает про RaidRun.

signal flag_chosen(index: int)
signal reroll_requested

const LAYOUT := [
	{"rect": Rect2(92, 404, 456, 338), "deg": -3.2, "color": TideTokens.DEEP, "form": 0},
	{"rect": Rect2(614, 346, 492, 402), "deg": 2.7, "color": TideTokens.FLARE, "form": 1},
	{"rect": Rect2(1174, 412, 512, 346), "deg": -1.9, "color": TideTokens.SONAR, "form": 2},
]

var _title: TideTitleLabel
var _title_strip: TidePanelTorn
var _level_plate: TidePanelTorn
var _level_text: Label
var _flags: Array[TideFlag] = []
var _stamp: TideStamp
var _reroll: TideButton
var _hint: Label
var _kicker: Label
var _busy := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build()


func _build() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = TideTokens.ink_alpha(0.78)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	TideKit.place(backdrop, Rect2(Vector2.ZERO, TideTokens.BASE))
	add_child(backdrop)

	TideKit.isobaths(self, Rect2(Vector2.ZERO, TideTokens.BASE), 0.085, 32.0)

	# Обрывки карт по краям: коллаж, а не центрированная рамка.
	TideKit.panel(
		self, Rect2(-52, 612, 322, 520), TideTokens.deep_alpha(0.55), TideTokens.flare_alpha(0.9), true, 4.4
	)
	TideKit.panel(
		self, Rect2(1652, -46, 330, 402), TideTokens.deep_alpha(0.5), Color(0, 0, 0, 0), true, -6.2
	)

	_title_strip = TideKit.panel(
		self, Rect2(36, 92, 1264, 216), TideTokens.deep_alpha(0.94), TideTokens.FLARE, false, -7.0
	)
	_title = TideKit.title(self, "ПОПУТНЫЙ ВЕТЕР", Vector2(74, 116), 112, -8.0, TideTokens.FOAM, 10)
	TideKit.fit_title(_title, 1180.0, 112, 62)

	_kicker = TideKit.mono(self, "ВАХТА 03 · ШТОРМОВОЙ ЖУРНАЛ", Vector2(64, 38), 22, TideTokens.SONAR, -2.5)

	_level_plate = TideKit.panel(
		self, Rect2(1342, 148, 352, 142), TideTokens.FLARE, TideTokens.ink_alpha(0.85), false, 6.2
	)
	TideKit.mono(_level_plate, "УРОВЕНЬ", Vector2(24, 12), 20, TideTokens.INK, -1.0)
	_level_text = TideKit.mono(_level_plate, "05 → 06", Vector2(22, 46), 46, TideTokens.INK, -1.0)

	for index in range(LAYOUT.size()):
		var entry: Dictionary = LAYOUT[index]
		var flag := TideKit.flag(
			self, entry["rect"], entry["color"], int(entry["form"]), float(entry["deg"]), index
		)
		flag.flag_hovered.connect(_on_flag_hovered)
		flag.flag_unhovered.connect(_on_flag_unhovered)
		flag.flag_pressed.connect(_on_flag_pressed)
		flag.hide()
		_flags.append(flag)

	_stamp = TideKit.stamp(self, "ПОВЫШЕНИЕ", Rect2(658, 296, 604, 170), TideTokens.FLARE, 66, -13.0)

	_reroll = TideKit.button(
		self,
		"ПЕРЕБРОСИТЬ · 2",
		Rect2(1442, 938, 356, 68),
		TideButton.Shape.OUTLINE,
		TideTokens.SONAR,
		1,
		24,
		TideTokens.SONAR,
		-1.5
	)
	_reroll.pressed.connect(_on_reroll_pressed)

	_hint = TideKit.mono(
		self, "1 · 2 · 3 — ПОДНЯТЬ ФЛАГ · ВЫБОР ОСТАНАВЛИВАЕТ ВАХТУ", Vector2(86, 1006), 20, TideTokens.foam_alpha(0.5), -1.2
	)
	TideKit.mono(self, "БОЙ НА ПАУЗЕ", Vector2(1370, 60), 20, TideTokens.foam_alpha(0.42), 2.2)


## entries: [{title, desc, preview}] — три карточки из RaidRun.
func open(entries: Array, level_from: int, level_to: int, rerolls: int, can_reroll: bool) -> void:
	_busy = false
	show()
	_level_text.text = "%02d → %02d" % [level_from, level_to]
	_reroll.set_caption("ПЕРЕБРОСИТЬ · %d" % rerolls)
	_reroll.disabled = not can_reroll
	_stamp.hide()
	for index in range(_flags.size()):
		var flag := _flags[index]
		if index < entries.size():
			var entry: Dictionary = entries[index]
			var layout: Dictionary = LAYOUT[index]
			flag.rest_deg = float(layout["deg"])
			flag.set_content(
				index,
				String(entry.get("title", "")),
				String(entry.get("desc", "")),
				String(entry.get("preview", "")),
				layout["color"],
				int(layout["form"])
			)
			flag.set_locked(false)
			flag.modulate.a = 0.0
			flag.scale = Vector2.ONE * 0.62
			flag.show()
		else:
			flag.hide()
	_play_entrance()
	_hint.modulate.a = 0.0
	var hint_tween := create_tween()
	hint_tween.tween_interval(0.26)
	hint_tween.tween_property(_hint, "modulate:a", 1.0, 0.18)


func _play_entrance() -> void:
	_title.modulate.a = 1.0
	_title.position = Vector2(74, 116)
	TideFx.slide_in(_title, Vector2(0, -210), 0.26)
	_stagger(_title_strip, 0.0, 0.9, -6.0)
	_stagger(_kicker, 0.02, 0.9, -4.0)
	_stagger(_level_plate, 0.06, 0.72, -12.0)
	_stagger(_reroll, 0.10, 0.8, -8.0)
	for index in range(_flags.size()):
		if not _flags[index].visible:
			continue
		var flag := _flags[index]
		var delay := 0.04 + float(index) * 0.05
		var tween := create_tween()
		tween.tween_interval(delay)
		tween.tween_callback(_pop_flag.bind(flag))


func _pop_flag(flag: TideFlag) -> void:
	var rest := flag.rest_deg
	flag.modulate.a = 0.0
	flag.scale = Vector2.ONE * 0.62
	flag.rest_deg = rest - 10.0
	TideFx.splash(self, flag.position + flag.size * 0.5, 9)
	var tween := flag.create_tween()
	tween.set_parallel(true)
	tween.tween_property(flag, "modulate:a", 1.0, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(flag, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(flag, "rest_deg", rest, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _stagger(node: Control, delay: float, from_scale: float, from_deg: float) -> void:
	if node == null:
		return
	node.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_interval(delay)
	tween.tween_callback(
		func() -> void:
			node.modulate.a = 1.0
			TideFx.pop_in(node, from_scale, from_deg)
	)


func _on_flag_hovered(index: int) -> void:
	if _busy:
		return
	for flag in _flags:
		flag.dim(flag.index != index)


func _on_flag_unhovered(_index: int) -> void:
	if _busy:
		return
	for flag in _flags:
		flag.dim(false)


func _on_flag_pressed(index: int) -> void:
	_pick(index)


func _on_reroll_pressed() -> void:
	if _busy or _reroll.disabled:
		return
	TideFx.press(_reroll)
	reroll_requested.emit()


func _input(event: InputEvent) -> void:
	if not visible or _busy:
		return
	if event is InputEventKey:
		var key := event as InputEventKey
		if not key.pressed or key.echo:
			return
		match key.physical_keycode:
			KEY_1:
				_pick(0)
			KEY_2:
				_pick(1)
			KEY_3:
				_pick(2)
			KEY_R:
				_on_reroll_pressed()
			_:
				return
		get_viewport().set_input_as_handled()


## Выбор: hit-stop 0.08 с → взлёт флага → падение остальных → штамп.
func _pick(index: int) -> void:
	if _busy or index < 0 or index >= _flags.size() or not _flags[index].visible:
		return
	_busy = true
	for flag in _flags:
		flag.set_locked(true)
	# Hit-stop: мир замирает на 0.08 с, таймер идёт в реальном времени.
	TideFx.freeze()
	await get_tree().create_timer(TideTokens.HITSTOP, true, false, true).timeout
	TideFx.unfreeze()
	_flags[index].fly_up()
	for other in _flags:
		if other.index != index:
			other.fall_down()
	await get_tree().create_timer(0.1, true, false, true).timeout
	_stamp.hit(self)
	TideFx.shake(self, 4.0, 0.12)
	await get_tree().create_timer(0.3, true, false, true).timeout
	flag_chosen.emit(index)
