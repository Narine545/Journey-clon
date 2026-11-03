class_name BoatHud
extends Control
## Лёгкий интерфейс без экранной цветокоррекции: чистые пигменты остаются чистыми.
var main: BoatMain

func _draw() -> void:
	if main == null or main.boat == null:
		return
	var font := ThemeDB.fallback_font
	var ink := Color("e9f0e8")
	var muted := Color("9db8b7")
	var backdrop := Color(0.035, 0.075, 0.10, 0.88)
	var panel := Rect2(22, 22, 380, 244)
	draw_rect(panel, backdrop)
	draw_rect(panel, Color("548c89"), false, 1.5)
	draw_string(font, Vector2(42, 53), "ПРИЛИВНАЯ ЛАБОРАТОРИЯ", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, ink)
	draw_string(font, Vector2(42, 78), "СКОРОСТЬ  %02.0f / 10     НАСОС  %s" % [absf(main.boat.speed), "АКТИВЕН" if main.boat.pump_fraction() > 0.0 else "ГОТОВ"], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, muted)
	for i in range(ResourceSlick.COLORS.size()):
		var y := 105.0 + float(i) * 32.0
		draw_rect(Rect2(42, y - 15, 13, 13), ResourceSlick.COLORS[i])
		draw_string(font, Vector2(65, y - 3), ResourceSlick.NAMES[i].to_upper(), HORIZONTAL_ALIGNMENT_LEFT, 122, 15, ink)
		draw_string(font, Vector2(235, y - 3), "%02d сыр.  →  %02d гот." % [main.raw[i], main.refined[i]], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, muted)
	var resource_name := main.boat.target_name()
	var action := "ПРОБЕЛ — ЗАБРАТЬ: %s" % resource_name.to_upper() if not resource_name.is_empty() else "ИЩИТЕ СВЕТЯЩИЕСЯ ПЯТНА"
	var center := Vector2(size.x * 0.5 - 195.0, size.y - 134.0)
	draw_rect(Rect2(center, Vector2(390, 38)), backdrop)
	draw_string(font, center + Vector2(14, 26), action, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, ink)
	if main.boat.pump_fraction() > 0.0:
		draw_rect(Rect2(center + Vector2(0, 36), Vector2(390.0 * main.boat.pump_fraction(), 3)), Color("78dfcb"))
	var controls := "W/S — ДВИГАТЕЛЬ     A/D — РУЛЬ     ПРОБЕЛ — НАСОС     R — ПЕРЕРАБОТАТЬ     КОЛЕСО — МАСШТАБ"
	draw_string(font, Vector2(28, size.y - 28), controls, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, ink)
	if main.notice_time > 0.0:
		draw_string(font, Vector2(size.x * 0.5 - 230, size.y - 168), main.notice, HORIZONTAL_ALIGNMENT_CENTER, 460, 17, Color("f3c783"))
