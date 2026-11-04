class_name BoatHud
extends Control
## Лёгкий интерфейс без экранной цветокоррекции.
var main: BoatMain

func _draw() -> void:
	if main == null or main.boat == null:
		return
	var font := ThemeDB.fallback_font
	var ink := Color("e9f0e8")
	var muted := Color("9db8b7")
	var accent := Color("78dfcb")
	var warn := Color("f3c783")
	var backdrop := Color(0.035, 0.075, 0.10, 0.88)
	var panel := Rect2(22, 22, 396, 276)
	draw_rect(panel, backdrop)
	draw_rect(panel, Color("548c89"), false, 1.5)
	draw_string(font, Vector2(42, 53), "ПРИЛИВНАЯ ЛАБОРАТОРИЯ", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, ink)
	draw_string(font, Vector2(42, 78), "СКОРОСТЬ  %02.0f / %.0f     НАСОС (ЛЕВ. БОРТ)  %s" % [
		absf(main.boat.speed),
		main.boat.effective_max_speed(),
		"РАБОТАЕТ" if main.boat.pump_fraction() > 0.0 else "ГОТОВ"
	], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, muted)
	var required := 2 if main.boat.has_trailer else 3
	for i in range(ResourceSlick.COLORS.size()):
		var y := 105.0 + float(i) * 32.0
		draw_rect(Rect2(42, y - 15, 13, 13), ResourceSlick.COLORS[i])
		draw_string(font, Vector2(65, y - 3), ResourceSlick.NAMES[i].to_upper(), HORIZONTAL_ALIGNMENT_LEFT, 122, 15, ink)
		draw_string(font, Vector2(235, y - 3), "%02d сыр.  →  %02d гот." % [main.raw[i], main.refined[i]], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, muted)
		# Это прогресс следующей переработки, не «ёмкость»: запасы не ограничены.
		draw_rect(Rect2(235, y + 2, 158, 4), Color("273c41"))
		draw_rect(Rect2(235, y + 2, 158.0 * clampf(float(main.raw[i]) / float(required), 0.0, 1.0), 4),
			ResourceSlick.COLORS[i])
	draw_string(font, Vector2(42, 223), "ПОЛОСЫ: СЫРЬЁ ДО ПЕРЕРАБОТКИ (%d ШТ.)" % required,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 12, muted)

	var trailer_status := "ПЛАШКОУТ: НА БУКСИРЕ (2 сыр. → 1 гот.)" if main.boat.has_trailer else "ПЛАШКОУТ: НЕТ  [B — КУПИТЬ ЗА 2 ГОТ. / T — ТЕСТ]"
	draw_string(font, Vector2(42, 240), trailer_status, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, accent if main.boat.has_trailer else muted)

	var resource_name := main.boat.target_name()
	var action := "ИЩИТЕ СВЕТЯЩИЕСЯ ПЯТНА"
	var action_col := ink
	if not resource_name.is_empty():
		action = "ПРОБЕЛ — ЗАБРАТЬ (ЛЕВ. БОРТ): %s" % resource_name.to_upper()
		action_col = accent
	elif main.boat.wrong_side_target:
		action = "ПОВЕРНИТЕСЬ ЛЕВЫМ БОРТОМ К ПЯТНУ"
		action_col = warn

	var center := Vector2(size.x * 0.5 - 205.0, size.y - 134.0)
	draw_rect(Rect2(center, Vector2(410, 38)), backdrop)
	draw_string(font, center + Vector2(14, 26), action, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, action_col)
	if main.boat.pump_fraction() > 0.0:
		draw_rect(Rect2(center + Vector2(0, 36), Vector2(410.0 * main.boat.pump_fraction(), 3)), accent)
	var controls := "W/S — ХОД    A/D — РУЛЬ    ПРОБЕЛ — НАСОС    R — ПЕРЕРАБОТКА    B — ПЛАШКОУТ    T — ТЕСТ    КОЛЕСО — ЗУМ"
	draw_string(font, Vector2(28, size.y - 28), controls, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, ink)
	if main.notice_time > 0.0:
		draw_string(font, Vector2(size.x * 0.5 - 260, size.y - 168), main.notice, HORIZONTAL_ALIGNMENT_CENTER, 520, 17, warn)
