class_name TidePorthole
extends Control
## Иллюминатор: круг с 8 заклёпками и цифрами JetBrains Mono.
## Дуга по ободу показывает остаток вахты; последние 30 с — flare.

@export var seconds := 0.0:
	set(value):
		seconds = value
		queue_redraw()
@export var duration := 300.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func display_time(seconds_value: float) -> void:
	seconds = maxf(0.0, seconds_value)


func _draw() -> void:
	var radius := minf(size.x, size.y) * 0.5 - 4.0
	if radius <= 6.0:
		return
	var center := size * 0.5
	# Корпус иллюминатора: тёмная вода в стекле, пена по ободу.
	draw_circle(center, radius, TideTokens.INK)
	draw_arc(center, radius - 1.0, 0.0, TAU, 72, TideTokens.FOAM, 5.0, true)
	draw_arc(center, radius - 9.0, 0.0, TAU, 72, TideTokens.DEEP, 9.0, true)
	draw_arc(center, radius - 16.0, 0.0, TAU, 72, TideTokens.FOAM, 1.5, true)
	# 8 заклёпок по ободу.
	for index in range(8):
		var angle := TAU * float(index) / 8.0 + PI * 0.125
		var at := center + Vector2(cos(angle), sin(angle)) * (radius - 5.0)
		draw_circle(at, 3.4, TideTokens.FOAM)
		draw_circle(at, 1.2, TideTokens.DEEP)
	# Остаток вахты: дуга сонаря, к концу — flare.
	var remaining := clampf(1.0 - seconds / maxf(1.0, duration), 0.0, 1.0)
	var danger := remaining < 0.16
	var arc_color := TideTokens.FLARE if danger else TideTokens.SONAR
	draw_arc(
		center,
		radius - 13.0,
		-PI * 0.5,
		-PI * 0.5 + TAU * remaining,
		64,
		arc_color,
		4.0,
		true
	)
	var font := TideTokens.mono_font()
	var clock := TideTokens.clock(seconds)
	var text_size := font.get_string_size(clock, HORIZONTAL_ALIGNMENT_LEFT, -1, 34)
	draw_string(
		font,
		center + Vector2(-text_size.x * 0.5, 12.0),
		clock,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		34,
		TideTokens.FOAM
	)
	var caption := font.get_string_size("ВАХТА", HORIZONTAL_ALIGNMENT_LEFT, -1, 13)
	draw_string(
		font,
		center + Vector2(-caption.x * 0.5, 30.0),
		"ВАХТА",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		13,
		TideTokens.foam_alpha(0.6)
	)
