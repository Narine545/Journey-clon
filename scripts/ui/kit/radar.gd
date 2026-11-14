class_name TideRadar
extends Control
## Сонарный круг: плоские точки целей и добычи, без свечения и градиентов.

var contacts: Array = [] # [{offset: Vector2, kind: int, elite: bool}]
var loot: Array = [] # [Vector2]
var forward := Vector2.UP
var range_meters := 55.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func push(contacts_value: Array, loot_value: Array, forward_value: Vector2) -> void:
	contacts = contacts_value
	loot = loot_value
	forward = forward_value
	queue_redraw()


func _draw() -> void:
	var radius := minf(size.x, size.y) * 0.5 - 2.0
	if radius <= 6.0:
		return
	var center := size * 0.5
	draw_circle(center, radius, TideTokens.ink_alpha(0.78))
	draw_arc(center, radius, 0.0, TAU, 56, TideTokens.foam_alpha(0.4), 2.0, true)
	draw_arc(center, radius * 0.62, 0.0, TAU, 48, TideTokens.foam_alpha(0.16), 1.0, true)
	draw_line(center - Vector2(radius, 0.0), center + Vector2(radius, 0.0), TideTokens.foam_alpha(0.1), 1.0, true)
	draw_line(center - Vector2(0.0, radius), center + Vector2(0.0, radius), TideTokens.foam_alpha(0.1), 1.0, true)
	var factor := radius / maxf(1.0, range_meters)
	for at in loot:
		var offset: Vector2 = at * factor
		if offset.length() < radius - 2.0:
			draw_circle(center + offset, 1.6, TideTokens.sonar_alpha(0.7))
	for contact in contacts:
		var offset: Vector2 = Vector2(contact["offset"]) * factor
		if offset.length() >= radius - 2.0:
			continue
		var kind := int(contact.get("kind", 0))
		var colors := [TideTokens.FLARE, TideTokens.FOAM, TideTokens.SONAR, TideTokens.FLARE]
		var tint: Color = colors[clampi(kind, 0, 3)]
		draw_circle(center + offset, 3.0 if kind < 3 else 5.0, tint)
		if bool(contact.get("elite", false)):
			draw_arc(center + offset, 6.0, 0.0, TAU, 16, TideTokens.FOAM, 1.6, true)
	# Курс корабля.
	draw_line(center, center + forward * radius * 0.36, TideTokens.SONAR, 3.0, true)
	draw_circle(center, 3.0, TideTokens.SONAR)
