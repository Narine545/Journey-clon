class_name TideHud
extends Control
## Боевой HUD «TIDECUT»: осадка корпуса вместо полоски HP, якорная цепь
## вместо XP-бара, иллюминатор вместо таймера, штамп-счётчик добычи.
## Все блоки повёрнуты на 2–6° и медленно качаются каждый в своей фазе.

signal start_pressed

var _hull: TideHullGauge
var _hull_plate: TidePanelTorn
var _hp_tag: TidePanelTorn
var _hp_value: Label
var _chain: TideChainBar
var _chain_note: Label
var _porthole: TidePorthole
var _wave_label: Label
var _level_plate: TidePanelTorn
var _level_value: Label
var _loot_plate: TidePanelTorn
var _loot_value: Label
var _weapons_plate: TidePanelTorn
var _weapons_label: Label
var _radar: TideRadar
var _radar_note: Label
var _boss_plate: TidePanelTorn
var _boss_label: Label
var _boss_bar: TideSegmentBar
var _boss_stamp: TideStamp
var _sos: TideStamp
var _launch: TideButton
var _launch_hint: Label
var _shoal: Label
var _bobs: Array[TideBob] = []
var _prev_filled := 0
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
	_hull_plate = TideKit.panel(
		self, Rect2(44, 780, 470, 254), TideTokens.deep_alpha(0.55), TideTokens.INK, true, -2.8
	)
	_hull = TideHullGauge.new()
	_hull.position = Vector2(74, 800)
	_hull.size = Vector2(400, 200)
	_hull.rotation = deg_to_rad(-1.5)
	add_child(_hull)
	_hp_tag = TideKit.panel(
		self, Rect2(360, 918, 196, 92), TideTokens.FOAM, TideTokens.INK, false, -4.6, false
	)
	TideKit.mono(_hp_tag, "ОСАДКА", Vector2(16, 8), 16, TideTokens.INK, -0.6)
	_hp_value = TideKit.mono(_hp_tag, "100%", Vector2(14, 30), 44, TideTokens.INK, -0.6)
	_sos = TideKit.stamp(self, "SOS", Rect2(118, 700, 214, 86), TideTokens.FLARE, 38, -12.0)

	# --- Якорная цепь (XP) во всю ширину сверху ---
	_chain = TideKit.CHAIN.instantiate()
	TideKit.place(_chain, Rect2(168, 12, 1560, 54), -1.2)
	add_child(_chain)
	_chain_note = TideKit.mono(self, "ОПЫТ 0 / 8", Vector2(172, 70), 20, TideTokens.foam_alpha(0.6), -1.2)

	_level_plate = TideKit.panel(
		self, Rect2(30, 92, 250, 108), TideTokens.deep_alpha(0.92), TideTokens.FLARE, true, -3.4
	)
	TideKit.mono(_level_plate, "УРОВЕНЬ", Vector2(22, 10), 18, TideTokens.foam_alpha(0.6), -0.8)
	_level_value = TideKit.mono(_level_plate, "01", Vector2(20, 36), 52, TideTokens.FOAM, -0.8)

	# --- Иллюминатор-таймер справа сверху ---
	_porthole = TideKit.PORTHOLE.instantiate()
	TideKit.place(_porthole, Rect2(1702, 66, 194, 194), 3.0)
	add_child(_porthole)
	_wave_label = TideKit.mono(self, "ФАЗА 1 · ЗЫБЬ", Vector2(1670, 268), 18, TideTokens.foam_alpha(0.55), 2.0)

	# --- Крупная цель: лента прочности ---
	_boss_plate = TideKit.panel(
		self, Rect2(596, 104, 728, 96), TideTokens.deep_alpha(0.92), TideTokens.FLARE, false, 1.7
	)
	_boss_label = TideKit.mono(_boss_plate, "КРУПНАЯ ЦЕЛЬ · ФАЗА 1", Vector2(22, 8), 20, TideTokens.FOAM, -0.8)
	_boss_bar = TideSegmentBar.new()
	TideKit.place(_boss_bar, Rect2(22, 48, 684, 26), 0.0)
	_boss_bar.tint = TideTokens.FLARE
	_boss_bar.segments = 14
	_boss_plate.add_child(_boss_bar)
	_boss_plate.hide()
	_boss_stamp = TideKit.stamp(self, "ЦЕЛЬ В БОЮ", Rect2(700, 214, 500, 108), TideTokens.FLARE, 40, -8.0)

	# --- Счёт добычи ---
	_loot_plate = TideKit.panel(
		self, Rect2(1508, 848, 366, 152), TideTokens.deep_alpha(0.92), TideTokens.FLARE, false, 3.6
	)
	_loot_plate.border_color = TideTokens.flare_alpha(0.9)
	_loot_plate.border_width = 3.0
	TideKit.mono(_loot_plate, "ДОБЫЧА", Vector2(24, 12), 18, TideTokens.foam_alpha(0.62), -0.8)
	_loot_value = TideKit.mono(_loot_plate, "000", Vector2(20, 40), 62, TideTokens.FOAM, -0.8)

	# --- Такелаж: готовность орудий ---
	_weapons_plate = TideKit.panel(
		self, Rect2(676, 980, 580, 62), TideTokens.deep_alpha(0.8), Color(0, 0, 0, 0), false, -1.4, false
	)
	_weapons_label = TideKit.mono(_weapons_plate, "НОС · БОРТА · Q · КОРМА", Vector2(22, 14), 20, TideTokens.FOAM, -0.6)

	# --- Сонар ---
	_radar = TideRadar.new()
	TideKit.place(_radar, Rect2(1710, 320, 178, 178), -2.2)
	add_child(_radar)
	_radar_note = TideKit.mono(self, "СОНАР · 55 М", Vector2(1734, 502), 15, TideTokens.foam_alpha(0.45), -2.2)

	_shoal = TideKit.mono(self, "ОТМЕЛЬ ПО КУРСУ — СНИЗЬТЕ ХОД", Vector2(612, 216), 20, TideTokens.FLARE, -1.2)
	_shoal.hide()

	# --- Старт рейда ---
	_launch = TideKit.button(
		self,
		"НАЧАТЬ РЕЙД",
		Rect2(1466, 780, 400, 96),
		TideButton.Variant.SOLID,
		TideTokens.SONAR,
		0,
		38,
		TideTokens.INK,
		-2.4
	)
	_launch.pressed.connect(func() -> void: start_pressed.emit())
	_launch_hint = TideKit.mono(
		self, "ВЫЙДИТЕ НА ГЛУБОКУЮ ВОДУ · ESC — ЖУРНАЛ", Vector2(1432, 890), 17, TideTokens.foam_alpha(0.55), -2.4
	)
	TideKit.mono(self, "ESC · ЖУРНАЛ     Q · ИМПУЛЬС", Vector2(58, 1034), 18, TideTokens.foam_alpha(0.4), -1.0)

	# --- Качка: у каждого блока своя фаза ---
	_add_bob(_hull_plate, 0, -2.8)
	_add_bob(_hp_tag, 1, -4.6)
	_add_bob(_chain, 2, -1.2)
	_add_bob(_level_plate, 3, -3.4)
	_add_bob(_porthole, 4, 3.0)
	_add_bob(_loot_plate, 5, 3.6)
	_add_bob(_weapons_plate, 6, -1.4)
	_set_engaged(false)


func _add_bob(target: Control, slot: int, base_deg: float) -> void:
	var bob := TideFx.bob(
		target,
		base_deg,
		TideTokens.BOB_AMP[slot % TideTokens.BOB_AMP.size()] * 0.8,
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
	_set_sos(hp01 < 0.25)

	var xp := float(state.get("xp", 0.0))
	var needed := maxf(1.0, float(state.get("xp_needed", 1.0)))
	_chain.set_values(xp, needed)
	_chain_note.text = "ОПЫТ %02d / %02d · ЦЕПЬ %d ЗВЕНЬЕВ" % [int(xp), int(needed), _chain.segments]
	var filled := int(floor(clampf(xp / needed, 0.0, 1.0) * float(_chain.segments)))
	if filled > _prev_filled:
		_chain.snap(mini(filled - 1, _chain.segments - 1))
	_prev_filled = filled
	_level_value.text = "%02d" % int(state.get("level", 1))

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

	_weapons_label.text = String(state.get("weapons", ""))
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
	_hull.visible = value
	_hp_tag.visible = value
	_loot_plate.visible = value
	_weapons_plate.visible = value
	_radar.visible = value
	_radar_note.visible = value
	_shoal.visible = false
	_boss_plate.visible = false
	_sos.visible = false
	_sos_active = false
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
	_sos.show()
	_sos_tween = create_tween().set_loops()
	_sos_tween.tween_property(_sos, "scale", Vector2.ONE * 1.08, 0.42).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_sos_tween.tween_property(_sos, "scale", Vector2.ONE, 0.42).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## Удар по корпусу: тряска HUD на 4–6 px, 0.12 с.
func shake_damage(strength: float = 5.0) -> void:
	TideFx.shake(self, clampf(strength, 4.0, 6.0), 0.12)


## Убийство: цифра добычи дёргается, из-под неё летят искры.
func bump_loot() -> void:
	if _loot_tween != null and _loot_tween.is_valid():
		_loot_tween.kill()
	_loot_value.pivot_offset = _loot_value.size * 0.5
	_loot_value.scale = Vector2(1.16, 0.88)
	_loot_tween = create_tween()
	_loot_tween.tween_property(_loot_value, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	TideFx.sparks(self, _loot_plate.position + Vector2(120, 96), 6)


## Момент выхода босса: штамп бьёт по кадру.
func flash_boss() -> void:
	_boss_stamp.hit(self)
