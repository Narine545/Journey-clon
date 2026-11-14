class_name TideUi
extends Control
## Корневой интерфейс рейда в стиле TIDECUT.
##
## Держит HUD, мировые телеграфы и три модальных экрана, читает RaidRun
## только на чтение (кроме явных действий игрока) и ничего не рисует сам.
## Старый RaidHud больше не создаётся: это единственный видимый UI рейда.

var run = null

var stage: TideStage
var hud: TideHud
var overlay: TideOverlay
var upgrade: TideUpgradeScreen
var journal: TidePauseJournal
var report: TideGameOverReport
var wipe: TideWaveWipe

var _state := -1
var _kills := 0
var _hp := 100.0
var _boss := false
var _wipe_busy := false


func setup() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage = TideStage.new()
	add_child(stage)
	var canvas := stage.canvas

	hud = TideHud.new()
	canvas.add_child(hud)
	hud.start_pressed.connect(_on_start)

	upgrade = TideUpgradeScreen.new()
	canvas.add_child(upgrade)
	upgrade.flag_chosen.connect(_on_flag_chosen)
	upgrade.reroll_requested.connect(_on_reroll)

	journal = TidePauseJournal.new()
	canvas.add_child(journal)
	journal.resume_requested.connect(_on_resume)
	journal.menu_requested.connect(_on_leave)
	journal.debug_toggled.connect(_on_debug_toggled)

	report = TideGameOverReport.new()
	canvas.add_child(report)
	report.restart_requested.connect(_on_restart)
	report.menu_requested.connect(_on_leave)

	overlay = TideOverlay.new()
	add_child(overlay)
	wipe = TideKit.WIPE.instantiate()
	add_child(wipe)

	overlay.run = run
	overlay.hide()
	_refresh_now()


## RaidRun вызывает это после каждого изменения состояния.
func refresh() -> void:
	_refresh_now()


func debug_tools_open() -> bool:
	return journal.visible or report.visible or upgrade.visible


func _refresh_now() -> void:
	if run == null:
		return
	_sync(true)


func _process(_delta: float) -> void:
	if run == null:
		return
	_sync(false)
	_track_events()
	hud.push(_hud_state())


func _sync(force: bool) -> void:
	var state: int = run.state
	if state == _state and not force:
		return
	_state = state
	match state:
		RaidRun.State.IDLE:
			_close_screens()
			overlay.hide()
			hud.show()
			_reset_counters()
		RaidRun.State.RUNNING:
			_close_screens()
			overlay.show()
			hud.show()
		RaidRun.State.CHOOSING:
			overlay.hide()
			if not upgrade.visible:
				_open_upgrade()
		RaidRun.State.PAUSED:
			overlay.hide()
			if not journal.visible:
				_open_journal()
		RaidRun.State.WON, RaidRun.State.LOST:
			overlay.hide()
			if not report.visible:
				_open_report()


func _close_screens() -> void:
	upgrade.hide()
	journal.hide()
	report.hide()


func _reset_counters() -> void:
	_kills = 0
	_hp = 100.0
	_boss = false


func _track_events() -> void:
	if run.main == null or run.main.boat == null:
		return
	var kills := int(run.kills)
	if kills > _kills and run.engaged():
		hud.bump_loot()
	_kills = kills
	var hp := float(run.main.boat.hull_hp)
	if hp < _hp - 0.05 and run.engaged():
		hud.shake_damage(6.0 if _hp - hp > 8.0 else 4.0)
	_hp = hp
	if run.boss_spawned and not _boss:
		_boss = true
		hud.flash_boss()
	elif not run.boss_spawned:
		_boss = false


func _with_wipe(action: Callable) -> void:
	if _wipe_busy:
		action.call()
		return
	_wipe_busy = true
	wipe.cover_then(
		func() -> void:
			action.call()
			wipe.reveal()
			_wipe_busy = false
	)


func _open_upgrade() -> void:
	_with_wipe(
		func() -> void:
			upgrade.open(
				_choices_payload(), run.level, run.level + 1, run.rerolls_left, run._can_reroll()
			)
	)


func _open_journal() -> void:
	_with_wipe(func() -> void: journal.open(_journal_payload()))


func _open_report() -> void:
	_with_wipe(func() -> void: report.open(_report_payload()))


func _on_start() -> void:
	if run != null:
		run.start()


func _on_restart() -> void:
	if run == null:
		return
	report.hide()
	run.restart()
	_refresh_now()


func _on_leave() -> void:
	if run == null:
		return
	_close_screens()
	run.leave()
	_refresh_now()


func _on_resume() -> void:
	if run == null:
		return
	journal.hide()
	run.toggle_pause()


func _on_flag_chosen(index: int) -> void:
	if run == null:
		return
	run.choose(index)
	_refresh_now()


func _on_reroll() -> void:
	if run == null or run.state != RaidRun.State.CHOOSING:
		return
	run._reroll_choices()
	upgrade.open(_choices_payload(), run.level, run.level + 1, run.rerolls_left, run._can_reroll())


func _on_debug_toggled(key: String, value: bool) -> void:
	if run == null:
		return
	match key:
		"god":
			run.debug_invulnerable = value
			run.stats.debug_used = run.stats.debug_used or value
		"clear":
			run.debug_clear_screen = value
			run.stats.debug_used = run.stats.debug_used or value
		"spheres":
			run.sphere_mines.set_enabled(value)
		"gravity":
			run.gravity_mines.set_enabled(value)
		"effects":
			run.effects_enabled = value
			if not value:
				run.damage_fx.reset()
		"fireballs":
			run.fireball_enabled = value


# --- Сборка данных для экранов ---


func _choices_payload() -> Array:
	var payload := []
	for kind in run.choices:
		var data: Array = RaidRun.UPGRADES[int(kind)]
		payload.append(
			{
				"title": String(data[0]),
				"desc": String(data[1]),
				"preview": run.upgrade_preview(int(kind)),
			}
		)
	return payload


func _hud_state() -> Dictionary:
	var payload := {
		"engaged": run.engaged(),
		"hp01": 1.0,
		"xp": run.xp,
		"xp_needed": run.xp_needed,
		"level": run.level,
		"seconds": run.elapsed,
		"duration": RaidRun.DURATION,
		"wave": RaidWaves.label(run.elapsed),
		"loot": run.salvage.collected,
		"weapons": _weapons_line(),
		"contacts": [],
		"loot_dots": [],
		"forward": run.forward(),
		"shoal": false,
		"boss": {},
	}
	if run.main == null or run.main.boat == null:
		return payload
	payload["hp01"] = clampf(float(run.main.boat.hull_hp) / 100.0, 0.0, 1.0)
	if run.main.shoals != null:
		payload["shoal"] = bool(run.main.shoals.warning)
	var boat: Vector2 = run.boat_at()
	var contacts := []
	for enemy in run.enemies:
		if float(enemy["hp"]) <= 0.0:
			continue
		var offset: Vector2 = enemy["at"] - boat
		if offset.length() > 55.0:
			continue
		contacts.append(
			{
				"offset": offset,
				"kind": int(enemy["kind"]),
				"elite": bool(enemy.get("elite", false)),
			}
		)
	payload["contacts"] = contacts
	var loot_dots := []
	for entry in run.salvage.drops:
		var offset: Vector2 = entry["at"] - boat
		if offset.length() <= 55.0:
			loot_dots.append(offset)
	payload["loot_dots"] = loot_dots
	for enemy in run.enemies:
		if int(enemy["kind"]) != 3 or float(enemy["hp"]) <= 0.0:
			continue
		payload["boss"] = {
			"ratio": clampf(float(enemy["hp"]) / maxf(1.0, float(enemy["max_hp"])), 0.0, 1.0),
			"phase": RaidBoss.phase(enemy),
			"remaining": maxi(0, int(ceil(RaidRun.DURATION - run.elapsed))),
		}
		break
	return payload


func _weapons_line() -> String:
	return "НОС %s · БОРТА %s · Q %s · КОРМА %s" % [
		_cooldown_text(run._bow_timer),
		_cooldown_text(run._side_timer),
		_cooldown_text(run.pulse_cooldown),
		"ГОТОВ" if run.stern_rank <= 0 else _cooldown_text(run.stern_charges.cooldown),
	]


func _cooldown_text(seconds: float) -> String:
	if seconds <= 0.05:
		return "ГОТОВ"
	return "%.1f с" % seconds


func _journal_payload() -> Dictionary:
	var entries := []
	var log: Array = run.upgrade_log
	for entry in log:
		var kind := int(entry["kind"])
		entries.append(
			{
				"clock": TideTokens.clock(float(entry["at"])),
				"title": String(RaidRun.UPGRADES[kind][0]),
				"evolution": kind >= 10 and kind <= 13,
			}
		)
	entries.reverse()
	var clock := TideTokens.clock(run.elapsed)
	var hull := 100.0
	if run.main != null and run.main.boat != null:
		hull = float(run.main.boat.hull_hp)
	var stats := ""
	stats += _leader("ВРЕМЯ", clock) + "\n"
	stats += _leader("УРОВЕНЬ", "%02d" % run.level) + "\n"
	stats += _leader("УНИЧТОЖЕНО", "%d" % run.kills) + "\n"
	stats += _leader("ДОБЫЧА", "%d" % run.salvage.collected) + "\n"
	stats += _leader("КОРПУС", "%d%%" % roundi(hull)) + "\n"
	stats += _leader("ФАЗА", RaidWaves.label(run.elapsed).split("·")[0].strip_edges()) + "\n"
	stats += _leader("ПЕРЕБРОСЫ", "%d" % run.rerolls_left) + "\n"
	stats += "\nЗАПИСЕЙ В ЖУРНАЛЕ: %d" % log.size()
	return {
		"entries": entries,
		"stats": stats,
		"clock": clock,
		"debug":
		{
			"god": run.debug_invulnerable,
			"clear": run.debug_clear_screen,
			"spheres": run.sphere_mines.enabled,
			"gravity": run.gravity_mines.enabled,
			"effects": run.effects_enabled,
			"fireballs": run.fireball_enabled,
		},
	}


func _report_payload() -> Dictionary:
	var win := run.state == RaidRun.State.WON
	var hull := 0.0
	if run.main != null and run.main.boat != null:
		hull = maxf(0.0, float(run.main.boat.hull_hp))
	var causes := ["КОНТАКТ", "СНАРЯД", "РИФ", "МЕЛЬ", "ПРОЧЕЕ"]
	var cause := "—"
	if run.stats.last_cause >= 0 and run.stats.last_cause < causes.size():
		cause = causes[run.stats.last_cause]
	var verdict := "КОРПУС ДОСТАВЛЕН В ПОРТ"
	if not win:
		verdict = "КОРПУС ПОТЕРЯН" if hull <= 0.0 else "ВРЕМЯ ВАХТЫ ИСТЕКЛО"
	var protocol := ""
	protocol += _leader("ВРЕМЯ ВАХТЫ", TideTokens.clock(run.elapsed)) + "\n"
	protocol += _leader("ДОБЫЧА", "%d" % run.salvage.collected) + "\n"
	protocol += _leader("УРОВЕНЬ", "%02d" % run.level) + "\n"
	protocol += _leader("УНИЧТОЖЕНО", "%d" % run.kills) + "\n"
	protocol += _leader("ПОЛУЧЕНО КОРПУСОМ", "%.0f" % run.stats.received) + "\n"
	protocol += _leader("ВЗЯТО МОДУЛЕЙ", "%d" % run.upgrade_log.size()) + "\n"
	protocol += _leader("ПОСЛЕДНИЙ УДАР", cause) + "\n"
	protocol += _leader("КОРПУС", "%d%%" % roundi(hull))
	var build := ""
	build += "СБОРКА\n"
	build += "УРОН НОС     %.0f\n" % run.damage
	build += "УРОН БОРТ    %.1f\n" % (run.damage * 0.7)
	build += "КАРТЕЧЬ      ×%d\n" % run.pellets
	build += "ПЕРЕЗАРЯДКА  %.2f / %.2f\n" % [0.65 * run.reload_scale, 1.25 * run.reload_scale]
	build += "ДВИГАТЕЛЬ    %d/3\n" % run.speed_rank
	build += "РУЛЬ         %d/3\n" % run.turn_rank
	build += "Q            %.0f / %.0f М\n" % [run.pulse_damage, run.pulse_radius]
	build += "КОРМА        %d/3\n" % run.stern_rank
	build += "СФЕРЫ        %d/3\n" % run.sphere_rank
	build += "СТЯГИВАНИЕ  %d/3\n" % run.gravity_rank
	var log_lines := ""
	var taken: Array = run.upgrade_log
	for index in range(maxi(0, taken.size() - 5), taken.size()):
		var entry: Dictionary = taken[index]
		log_lines += "%s · %s\n" % [
			TideTokens.clock(float(entry["at"])), String(RaidRun.UPGRADES[int(entry["kind"])][0])
		]
	if log_lines.is_empty():
		log_lines = "ЖУРНАЛ ПУСТ"
	return {
		"win": win,
		"title": "ЦЕЛЬ УНИЧТОЖЕНА" if win else "ПРОПАЛ БЕЗ ВЕСТИ",
		"kicker": "РАПОРТ КАПИТАНА · ВАХТА ЗАКРЫТА",
		"verdict": verdict,
		"protocol": protocol,
		"build": build,
		"log": "ПОСЛЕДНИЕ ЗАПИСИ\n" + log_lines.strip_edges(),
		"stamp": "ЗАЧТЕНО" if win else "SOS",
	}


## Дополнить строку точками до ровной колонки — как в судовом протоколе.
func _leader(name: String, value: String, width: int = 34) -> String:
	var dots := maxi(2, width - name.length() - value.length())
	return "%s %s %s" % [name, ".".repeat(dots), value]
