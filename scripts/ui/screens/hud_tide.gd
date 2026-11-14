class_name TideHud
extends Control
## Боевой HUD «TIDECUT»: осадка корпуса вместо полоски HP, якорная цепь
## вместо XP-бара, иллюминатор вместо таймера, штамп-счётчик добычи.
## Каждый блок — группа: подложка и подписи повёрнуты вместе (2–6°) и
## качаются в своей фазе, поэтому текст никогда не съезжает с плашки.

signal start_pressed

const HULL_RECT := Rect2(34, 792, 500, 250)
const LEVEL_RECT := Rect2(30, 22, 150, 112)
const CHAIN_RECT := Rect2(206, 30, 1450, 46)
const PORT_RECT := Rect2(1694, 22, 196, 196)
const RADAR_RECT := Rect2(1722, 286, 160, 160)
const BOSS_RECT := Rect2(560, 118, 800, 96)
const LOOT_RECT := Rect2(1540, 872, 330, 164)
const WEAPON_RECT := Rect2(600, 962, 720, 56)

var _hull: TideHullGauge
var _hull_plate: Control
var _hp_value: Label
var _chain: TideChainBar
var _chain_note: Label
var _porthole: TidePorthole
var _wave_label: Label
var _level_plate: Control
var _level_value: Label
var _loot_plate: Control
var _loot_value: Label
var _weapons_plate: Control
var _weapons_label: Label
var _radar: TideRadar
var _radar_note: Label
var _boss_plate: Control
var _boss_label: Label
var _boss_bar: TideSegmentBar
var _boss_stamp: TideStamp
var _sos: TideStamp
var _launch: TideButton
var _launch_hint: Label
var _keys_hint: Label
var _shoal: Label
var _bobs: Array[TideBob] = []
var _prev_filled := 0
var _prev_level := -1
var _loot_tween: Tween
var _sos_tween: Tween
var _engaged := false
var _sos_active := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_build()


func _build() -> void:
	# --- Осадка корпуса (HP), внизу слева ---
	_hull_plate = TideKit.group(self, HULL_RECT, -3.0)
	var hull_back := TideKit.panel(
		_hull_plate, Rect2(Vector2.ZERO, HULL_RECT.size), TideTokens.DEEP, TideTokens.INK, true
	)
	hull_back.hatch_color = TideTokens.foam_alpha(0.07)
	hull_back.hatch_spacing = 8.0
	TideKit.text(_hull_plate, "ОСАДКА КОРПУСА", Vector2(28, 14), 1, 17, TideTokens.foam_alpha(0.62))
	_hp_value = TideKit.text(
		_hull_plate, "100%", Vector2(300, 2), 1, 40, TideTokens.FOAM, 174.0, HORIZONTAL_ALIGNMENT_RIGHT
	)
	_hull = TideHullGauge.new()
	_hull.position = Vector2(30, 66)
	_hull.size = Vector2(430, 156)
	_hull_plate.add_child(_hull)
	_sos = TideKit.stamp(self, "SOS", Rect2(296, 686, 236, 104), TideTokens.FLARE, 48, -12.0)

	# --- Уровень: талон в начале цепи ---
	_level_plate = TideKit.group(self, LEVEL_RECT, -3.4)
	TideKit.panel(
		_level_plate, Rect2(Vector2.ZERO, LEVEL_RECT.size), TideTokens.FLARE, TideTokens.FOAM, false
	).underprint_offset = Vector2(6.0, 7.0)
	TideKit.text(_level_plate, "УРОВЕНЬ", Vector2(18, 8), 1, 16, TideTokens.INK)
	_level_value = TideKit.text(_level_plate, "01", Vector2(14, 26), 1, 58, TideTokens.FOAM, 122.0)

	# --- Якорная цепь (XP) во всю ширину сверху ---
	_chain = TideKit.CHAIN.instantiate()
	_chain.segments = 20
	TideKit.place(_chain, CHAIN_RECT, -0.8)
	add_child(_chain)
	_chain_note = TideKit.text(
		self, "ОПЫТ 00 / 08", Vector2(214, 82), 1, 20, TideTokens.foam_alpha(0.85), 420.0
	)

	# --- Иллюминатор-таймер справа сверху, под ним фаза и сонар ---
	_porthole = TideKit.PORTHOLE.instantiate()
	TideKit.place(_porthole, PORT_RECT, 3.0)
	add_child(_porthole)
	_wave_label = TideKit.text(
		self, "", Vector2(1440, 230), 1, 18, TideTokens.FOAM, 446.0, HORIZONTAL_ALIGNMENT_RIGHT
	)
	_wave_label.rotation = deg_to_rad(2.0)
	_radar = TideRadar.new()
	TideKit.place(_radar, RADAR_RECT, -2.2)
	add_child(_radar)
	_radar_note = TideKit.text(
		self, "СОНАР · 55 М", Vector2(1640, 452), 1, 18, TideTokens.foam_alpha(0.85), 246.0,
		HORIZONTAL_ALIGNMENT_RIGHT
	)
	_radar_note.rotation = deg_to_rad(-2.2)

	# --- Крупная цель: лента прочности ---
	_boss_plate = TideKit.group(self, BOSS_RECT, 1.6)
	TideKit.panel(
		_boss_plate, Rect2(Vector2.ZERO, BOSS_RECT.size), TideTokens.DEEP, TideTokens.FLARE, false
	)
	_boss_label = TideKit.text(
		_boss_plate, "КРУПНАЯ ЦЕЛЬ", Vector2(40, 8), 1, 19, TideTokens.FOAM, 720.0
	)
	_boss_bar = TideSegmentBar.new()
	TideKit.place(_boss_bar, Rect2(40, 44, 728, 26), 0.0)
	_boss_bar.tint = TideTokens.FLARE
	_boss_bar.segments = 16
	_boss_plate.add_child(_boss_bar)
	_boss_stamp = TideKit.stamp(self, "ЦЕЛЬ В БОЮ", Rect2(680, 250, 560, 130), TideTokens.FLARE, 52, -8.0)

	# --- Счёт добычи: наклонный штамп-счётчик ---
	_loot_plate = TideKit.group(self, LOOT_RECT, 4.0)
	var loot_back := TideKit.panel(
		_loot_plate, Rect2(Vector2.ZERO, LOOT_RECT.size), TideTokens.FOAM, TideTokens.FLARE, false
	)
	loot_back.double_frame = true
	loot_back.frame_color = TideTokens.FLARE
	loot_back.frame_inset = 12.0
	TideKit.text(_loot_plate, "ДОБЫЧА", Vector2(34, 26), 1, 18, TideTokens.FLARE)
	_loot_value = TideKit.text(
		_loot_plate, "000", Vector2(30, 46), 1, 76, TideTokens.INK, LOOT_RECT.size.x - 60.0,
		HORIZONTAL_ALIGNMENT_RIGHT
	)

	# --- Такелаж: готовность орудий ---
	_weapons_plate = TideKit.group(self, WEAPON_RECT, -1.2)
	var weapons_back := TideKit.panel(
		_weapons_plate, Rect2(Vector2.ZERO, WEAPON_RECT.size), TideTokens.DEEP,
		Color(0, 0, 0, 0), false, 0.0, false
	)
	weapons_back.skew = 12.0
	weapons_back.cut = 0.0
	weapons_back._rebuild()
	_weapons_label = TideKit.text(
		_weapons_plate, "", Vector2(24, 0), 1, 19, TideTokens.FOAM, WEAPON_RECT.size.x - 48.0,
		HORIZONTAL_ALIGNMENT_CENTER
	)
	_weapons_label.size.y = WEAPON_RECT.size.y
	_keys_hint = TideKit.text(
		self, "ESC · ЖУРНАЛ И ОТЛАДКА     Q · ИМПУЛЬС     F5–F7 · ТЕСТ", Vector2(480, 1028), 1, 19,
		TideTokens.foam_alpha(0.8), 960.0, HORIZONTAL_ALIGNMENT_CENTER
	)

	_shoal = TideKit.text(
		self, "ОТМЕЛЬ ПО КУРСУ — СНИЗЬТЕ ХОД", Vector2(560, 236), 1, 22, TideTokens.FLARE, 800.0,
		HORIZONTAL_ALIGNMENT_CENTER
	)
	_shoal.hide()

	# --- Старт рейда ---
	_launch = TideKit.button(
		self,
		"НАЧАТЬ РЕЙД",
		Rect2(1420, 840, 430, 104),
		TideButton.Shape.PENNANT,
		TideTokens.SONAR,
		0,
		38,
		TideTokens.INK,
		-2.4
	)
	_launch.pressed.connect(func() -> void: start_pressed.emit())
	_launch_hint = TideKit.text(
		self, "ВЫЙДИТЕ НА ГЛУБОКУЮ ВОДУ · ESC — МЕНЮ", Vector2(1250, 966), 1, 17,
		TideTokens.foam_alpha(0.85), 600.0, HORIZONTAL_ALIGNMENT_RIGHT
	)
	_launch_hint.rotation = deg_to_rad(-2.4)

	# --- Качка: у каждого блока своя фаза ---
	_add_bob(_hull_plate, 0, -3.0)
	_add_bob(_chain, 2, -0.8, 0.35)
	_add_bob(_level_plate, 3, -3.4)
	_add_bob(_porthole, 4, 3.0)
	_add_bob(_loot_plate, 5, 4.0)
	_add_bob(_weapons_plate, 6, -1.2, 0.6)
	_add_bob(_boss_plate, 1, 1.6, 0.6)
	_set_engaged(false)


func _add_bob(target: Control, slot: int, base_deg: float, amplitude_scale: float = 0.8) -> void:
	var bob := TideFx.bob(
		target,
		base_deg,
		TideTokens.BOB_AMP[slot % TideTokens.BOB_AMP.size()] * amplitude_scale,
		TideTokens.BOB_PERIOD[slot % TideTokens.BOB_PERIOD.size()],
		TideTokens.BOB_PHASE[slot % TideTokens.BOB_PHASE.size()]
	)
	add_child(bob)
	_bobs.append(bob)


## push() вызывается каждый кадр из TideUi: HUD — чистая функция состояния.
func push(state: Dictionary) -> void:
	var engaged: bool = state.get("engaged", false)
	if engaged != _engaged:
		_set_engaged(engaged)
	if not _engaged:
		return
	var hp01 := clampf(float(state.get("hp01", 1.0)), 0.0, 1.0)
	_hull.set_hp(hp01)
	_hull.set_danger(hp01 < 0.25)
	_hp_value.text = "%d%%" % roundi(hp01 * 100.0)
	_hp_value.add_theme_color_override(
		"font_color", TideTokens.FLARE if hp01 < 0.25 else TideTokens.FOAM
	)
	_set_sos(hp01 < 0.25)

	var xp := float(state.get("xp", 0.0))
	var needed := maxf(1.0, float(state.get("xp_needed", 1.0)))
	_chain.set_values(xp, needed)
	_chain_note.text = "ОПЫТ %02d / %02d" % [int(xp), int(needed)]
	var filled := int(floor(clampf(xp / needed, 0.0, 1.0) * float(_chain.segments)))
	if filled > _prev_filled:
		_chain.snap(mini(filled - 1, _chain.segments - 1))
	_prev_filled = filled
	var level := int(state.get("level", 1))
	_level_value.text = "%02d" % level
	if _prev_level >= 0 and level > _prev_level:
		_bump(_level_plate)
	_prev_level = level

	_porthole.display_time(float(state.get("seconds", 0.0)))
	_porthole.duration = maxf(1.0, float(state.get("duration", 300.0)))
	_wave_label.text = String(state.get("wave", ""))

	var boss: Dictionary = state.get("boss", {})
	if boss.is_empty():
		_boss_plate.hide()
	else:
		_boss_plate.show()
		_boss_bar.set_ratio(float(boss.get("ratio", 1.0)))
		_boss_label.text = "КРУПНАЯ ЦЕЛЬ · ФАЗА %d · %d С" % [
			int(boss.get("phase", 1)), int(boss.get("remaining", 0))
		]

	var loot := int(state.get("loot", 0))
	if _loot_value.text != "%03d" % loot:
		_loot_value.text = "%03d" % loot

	var weapons := String(state.get("weapons", ""))
	if weapons != _weapons_label.text:
		_weapons_label.text = weapons
		_weapons_label.add_theme_font_size_override(
			"font_size",
			TideTokens.fit_point(TideTokens.mono_font(), weapons, WEAPON_RECT.size.x - 64.0, 19, 12)
		)
	_radar.push(state.get("contacts", []), state.get("loot_dots", []), state.get("forward", Vector2.UP))
	_shoal.visible = bool(state.get("shoal", false))


func _set_engaged(value: bool) -> void:
	_engaged = value
	_launch.visible = not value
	_launch_hint.visible = not value
	_chain.visible = value
	_chain_note.visible = value
	_level_plate.visible = value
	_porthole.visible = value
	_wave_label.visible = value
	_hull_plate.visible = value
	_loot_plate.visible = value
	_weapons_plate.visible = value
	_keys_hint.visible = value
	_radar.visible = value
	_radar_note.visible = value
	_shoal.visible = false
	_boss_plate.visible = false
	_sos.visible = false
	_sos_active = false
	_prev_level = -1
	if not value:
		_boss_stamp.hide()


func _set_sos(active: bool) -> void:
	if active == _sos_active:
		return
	_sos_active = active
	if _sos_tween != null and _sos_tween.is_valid():
		_sos_tween.kill()
	if not active:
		_sos.hide()
		return
	_sos.hit(self)
	_sos_tween = create_tween().set_loops()
	_sos_tween.tween_interval(TideTokens.STAMP_TIME + 0.05)
	_sos_tween.tween_property(_sos, "scale", Vector2.ONE * 1.08, 0.42).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_sos_tween.tween_property(_sos, "scale", Vector2.ONE, 0.42).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _bump(target: Control) -> void:
	target.scale = Vector2.ONE * 1.25
	var tween := target.create_tween()
	tween.tween_property(target, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Удар по корпусу: тряска HUD на 4–6 px, 0.12 с.
func shake_damage(strength: float = 5.0) -> void:
	TideFx.shake(self, clampf(strength, 4.0, 6.0), 0.12)


## Убийство: цифра добычи дёргается, из-под неё летят искры.
func bump_loot() -> void:
	if _loot_tween != null and _loot_tween.is_valid():
		_loot_tween.kill()
	_loot_value.pivot_offset = _loot_value.size * 0.5
	_loot_value.scale = Vector2(1.2, 0.84)
	_loot_value.rotation = deg_to_rad(-4.0)
	_loot_tween = create_tween().set_parallel(true)
	_loot_tween.tween_property(_loot_value, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_loot_tween.tween_property(_loot_value, "rotation", 0.0, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	TideFx.sparks(self, LOOT_RECT.position + LOOT_RECT.size * Vector2(0.6, 0.55), 6)


## Момент выхода босса: штамп бьёт по кадру.
func set_keys_hint(value: String, alert: bool = false) -> void:
	_keys_hint.text = value
	_keys_hint.add_theme_color_override(
		"font_color", TideTokens.FLARE if alert else TideTokens.foam_alpha(0.8)
	)


func flash_boss() -> void:
	_boss_stamp.hit(self)
	# Оттиск держится секунду и срывается — не висит над боем весь рейд.
	var tween := _boss_stamp.create_tween()
	tween.tween_interval(1.2)
	tween.tween_property(_boss_stamp, "scale", Vector2.ONE * 0.5, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_callback(_boss_stamp.hide)
