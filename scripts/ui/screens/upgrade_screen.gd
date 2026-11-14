class_name TideUpgradeScreen
extends Control
## Экран повышения уровня «ПОПУТНЫЙ ВЕТЕР» — витрина стиля TIDECUT.
##
## Три апгрейда — три сигнальных флага разных форм на трёх мачтах. Наведение
## поднимает флаг и пригибает остальные, выбор — флаг рывком поднимают,
## остальные спускают, по экрану бьёт штамп «ПОВЫШЕНИЕ».
## Тексты приходят снаружи: экран ничего не знает про RaidRun.

signal flag_chosen(index: int)
signal reroll_requested

## Три мачты разной высоты; наклон чередуется.
const LAYOUT := [
	{"rect": Rect2(118, 486, 478, 300), "deg": -2.2, "color": TideTokens.DEEP, "form": 0},
	{"rect": Rect2(690, 384, 600, 400), "deg": 1.6, "color": TideTokens.FLARE, "form": 1},
	{"rect": Rect2(1326, 468, 504, 310), "deg": -1.4, "color": TideTokens.SONAR, "form": 2},
]
const HEAD_RECT := Rect2(-70, 64, 1330, 236)
const HEAD_DEG := -4.0
const LEVEL_RECT := Rect2(1420, 92, 400, 168)
const LEVEL_DEG := 4.5

var _head: Control
var _title: TideTitleLabel
var _level: Control
var _level_text: Label
var _flags: Array[TideFlag] = []
var _stamp: TideStamp
var _reroll: TideButton
var _hint: Label
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

	# --- Шапка: рваная лента с заголовком, уходит за левый край ---
	_head = TideKit.group(self, HEAD_RECT, HEAD_DEG)
	var strip := TideKit.panel(
		_head, Rect2(0, 34, HEAD_RECT.size.x, 190), TideTokens.DEEP, TideTokens.FLARE, true
	)
	strip.hatch_color = TideTokens.foam_alpha(0.07)
	strip.hatch_spacing = 8.0
	strip.underprint_offset = Vector2(12.0, 14.0)
	TideKit.text(_head, "СИГНАЛ С МОСТИКА · ВЫБЕРИ ФЛАГ", Vector2(132, 0), 1, 21, TideTokens.SONAR)
	_title = TideKit.headline(
		_head, "ПОПУТНЫЙ ВЕТЕР", Vector2(124, 52), 1120.0, 118, TideTokens.FOAM, 10, -11.0
	)
	_title.position.y = 34.0 + (182.0 - _title.size.y) * 0.5

	# --- Плашка уровня: красный отрывной талон справа ---
	_level = TideKit.group(self, LEVEL_RECT, LEVEL_DEG)
	TideKit.panel(
		_level, Rect2(Vector2.ZERO, LEVEL_RECT.size), TideTokens.FLARE, TideTokens.FOAM, false
	).underprint_offset = Vector2(-10.0, 10.0)
	TideKit.text(_level, "УРОВЕНЬ", Vector2(34, 18), 1, 22, TideTokens.INK)
	_level_text = TideKit.text(
		_level, "05 → 06", Vector2(30, 52), 1, 64, TideTokens.FOAM, LEVEL_RECT.size.x - 60.0
	)

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

	_hint = TideKit.text(
		self, "1 · 2 · 3 — ПОДНЯТЬ ФЛАГ", Vector2(150, 1030), 1, 19, TideTokens.foam_alpha(0.45)
	)
	_reroll = TideKit.button(
		self,
		"ПЕРЕБРОСИТЬ · 2",
		Rect2(1440, 968, 380, 70),
		TideButton.Shape.OUTLINE,
		TideTokens.SONAR,
		1,
		24,
		TideTokens.SONAR,
		-1.5
	)
	_reroll.pressed.connect(_on_reroll_pressed)

	# Качка: шапка и талон плавают каждый в своей фазе (флаги качаются сами).
	add_child(TideFx.bob(_head, HEAD_DEG, 0.6, 3.0, 0.4))
	add_child(TideFx.bob(_level, LEVEL_DEG, 1.1, 2.5, 2.6))

	_stamp = TideKit.stamp(self, "ПОВЫШЕНИЕ", Rect2(660, 800, 760, 190), TideTokens.FLARE, 84, -12.0)


## entries: [{title, desc, preview}] — три карточки из RaidRun.
func open(entries: Array, level_from: int, level_to: int, rerolls: int, can_reroll: bool) -> void:
	_busy = false
	show()
	_level_text.text = "%02d → %02d" % [level_from, level_to]
	_reroll.set_caption("ПЕРЕБРОСИТЬ · %d" % rerolls)
	_reroll.disabled = not can_reroll
	_reroll.queue_redraw()
	_stamp.hide()
	var common := TideFlag.TITLE_MAX
	for index in range(_flags.size()):
		var flag := _flags[index]
		if index < entries.size():
			var entry: Dictionary = entries[index]
			var layout: Dictionary = LAYOUT[index]
			flag.rest_deg = float(layout["deg"])
			flag.restore()
			flag.set_content(
				index,
				String(entry.get("title", "")),
				String(entry.get("desc", "")),
				String(entry.get("preview", "")),
				layout["color"],
				int(layout["form"])
			)
			flag.set_locked(false)
			flag.show()
			common = mini(common, flag.title_point)
		else:
			flag.hide()
	# Один кегль названий на всех флагах: типографика ровная, а не «как влезло».
	for flag in _flags:
		if flag.visible:
			flag.apply_title_point(maxi(common, 20) + 4)
	_play_entrance()


func _play_entrance() -> void:
	TideKit.place(_head, HEAD_RECT, HEAD_DEG)
	_head.modulate.a = 1.0
	# Шапка влетает сверху с overshoot.
	TideFx.slide_in(_head, Vector2(-60, -330), 0.26)
	TideFx.splash(self, Vector2(620, 300), 12)
	_stagger(_level, 0.08, 0.5, -10.0)
	_stagger(_reroll, 0.14, 0.7, -8.0)
	_hint.modulate.a = 0.0
	var hint_tween := create_tween()
	hint_tween.tween_interval(0.3)
	hint_tween.tween_property(_hint, "modulate:a", 1.0, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	for index in range(_flags.size()):
		var flag := _flags[index]
		if not flag.visible:
			continue
		flag.modulate.a = 0.0
		var tween := create_tween()
		tween.tween_interval(0.1 + float(index) * 0.06)
		tween.tween_callback(_pop_flag.bind(flag))


## Мачта «вырастает» от основания: масштаб 0.5 → 1 с overshoot.
func _pop_flag(flag: TideFlag) -> void:
	var rest := flag.rest_deg
	flag.scale = Vector2.ONE * 0.5
	flag.rest_deg = rest - 10.0
	TideFx.splash(self, flag.position + Vector2(flag.size.x * 0.4, flag.size.y), 10)
	var tween := flag.create_tween()
	tween.set_parallel(true)
	tween.tween_property(flag, "modulate:a", 1.0, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(flag, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(flag, "rest_deg", rest, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _stagger(node: Control, delay: float, from_scale: float, from_deg: float) -> void:
	if node == null:
		return
	node.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_interval(delay)
	tween.tween_callback(func() -> void: TideFx.pop_in(node, from_scale, from_deg))


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


## Выбор: hit-stop 0.08 с → флаг поднят → остальные спущены → штамп.
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
	var chosen := _flags[index]
	chosen.fly_up()
	for other in _flags:
		if other.index != index:
			other.fall_down()
	await get_tree().create_timer(0.1, true, false, true).timeout
	# Штамп бьёт по центру, по воде под поднятым флагом (спущенные уже ушли).
	_stamp.hit(self)
	TideFx.shake(self, 4.0, 0.12)
	await get_tree().create_timer(0.3, true, false, true).timeout
	flag_chosen.emit(index)
