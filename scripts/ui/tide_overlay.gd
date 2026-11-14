class_name TideOverlay
extends Control
## Мировые подсказки боя в стиле TIDECUT: кольца элит, секторы тревоги босса,
## метки рывка/выстрела и кольцо импульса. Работает в пикселях экрана,
## поэтому телеграфы не «плывут» вместе с масштабом панелей.

var run = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	if run != null and run.engaged() and run.state == RaidRun.State.RUNNING:
		queue_redraw()


func _draw() -> void:
	if run == null or not run.engaged() or run.state != RaidRun.State.RUNNING:
		return
	if run.main == null or run.main.camera == null:
		return
	var camera: Camera3D = run.main.camera
	for enemy in run.enemies:
		if float(enemy["hp"]) <= 0.0:
			continue
		if bool(enemy.get("elite", false)):
			_draw_elite(enemy, camera)
		var kind: int = enemy["kind"]
		if kind == 3:
			_draw_boss_warning(enemy, camera)
			continue
		var timer: float = enemy["timer"]
		if not ((kind == 1 and timer < 1.1) or (kind >= 2 and timer < 0.9)):
			continue
		var world := Vector3(float(enemy["at"].x), Coast.SEA_LEVEL + 1.5, float(enemy["at"].y))
		if camera.is_position_behind(world):
			continue
		var screen := camera.unproject_position(world)
		draw_arc(screen, 18.0, 0.0, TAU, 22, TideTokens.FLARE, 2.0, true)
		if kind == 1:
			var aim: Vector2 = enemy["aim"]
			var end := world + Vector3(aim.x, 0.0, aim.y) * 10.0
			if not camera.is_position_behind(end):
				draw_line(screen, camera.unproject_position(end), TideTokens.flare_alpha(0.7), 2.0, true)
	_draw_pulse(camera)
	_draw_boss_arrow(camera)
	if run.main.shoals != null and run.main.shoals.warning:
		_text(Vector2(size.x * 0.5 - 210.0, 214.0), "ОТМЕЛЬ ПО КУРСУ — СНИЗЬТЕ ХОД", 18, TideTokens.FLARE)


func _draw_pulse(camera: Camera3D) -> void:
	if run._pulse_flash <= 0.0:
		return
	var at: Vector3 = run.main.boat.global_position
	var screen := camera.unproject_position(at)
	var edge := camera.unproject_position(at + camera.global_basis.x * run.pulse_radius)
	draw_arc(
		screen,
		screen.distance_to(edge) * (1.0 - run._pulse_flash / 0.5),
		0.0,
		TAU,
		64,
		TideTokens.sonar_alpha(clampf(run._pulse_flash * 2.0, 0.0, 0.9)),
		2.0,
		true
	)


func _draw_elite(enemy: Dictionary, camera: Camera3D) -> void:
	var at: Vector2 = enemy["at"]
	if at.distance_to(run.boat_at()) > 60.0:
		return
	var world := Vector3(at.x, Coast.SEA_LEVEL + 2.0, at.y)
	if camera.is_position_behind(world):
		return
	var screen := camera.unproject_position(world)
	draw_arc(screen, 26.0, 0.0, TAU, 24, TideTokens.FLARE, 2.0, true)
	var percent := int(ceil(100.0 * float(enemy["hp"]) / float(enemy["max_hp"])))
	_text(screen + Vector2(30.0, -28.0), "ЭЛИТА · %d%%" % percent, 17, TideTokens.FLARE)


func _draw_boss_warning(enemy: Dictionary, camera: Camera3D) -> void:
	if not RaidBoss.preparing(enemy):
		return
	var at: Vector2 = enemy["at"]
	var origin := Vector3(at.x, Coast.SEA_LEVEL + 1.5, at.y)
	if camera.is_position_behind(origin):
		return
	var screen := camera.unproject_position(origin)
	var progress := 1.0 - float(enemy["boss_windup"]) / RaidBoss.warning_length(enemy)
	draw_arc(
		screen,
		26.0,
		-PI * 0.5,
		-PI * 0.5 + TAU * clampf(progress, 0.0, 1.0),
		40,
		TideTokens.FLARE,
		3.0,
		true
	)
	for direction in RaidBoss.directions(enemy):
		var end := origin + Vector3(direction.x, 0.0, direction.y) * 26.0
		if not camera.is_position_behind(end):
			draw_line(screen, camera.unproject_position(end), TideTokens.flare_alpha(0.45), 2.0, true)
	_text(
		screen + Vector2(32.0, -24.0),
		"ВЕЕР" if int(enemy["boss_pattern"]) == 0 else "КОЛЬЦО",
		17,
		TideTokens.FLARE
	)


func _draw_boss_arrow(camera: Camera3D) -> void:
	for enemy in run.enemies:
		if int(enemy["kind"]) != 3 or float(enemy["hp"]) <= 0.0:
			continue
		var at: Vector2 = enemy["at"]
		var world := Vector3(at.x, Coast.SEA_LEVEL + 1.0, at.y)
		var screen := camera.unproject_position(world)
		var behind := camera.is_position_behind(world)
		var viewport := Rect2(Vector2.ZERO, size)
		if not behind and viewport.grow(-34.0).has_point(screen):
			return
		var center := size * 0.5
		var direction := screen - center
		if behind:
			direction = -direction
		if direction.length_squared() < 0.0001:
			direction = Vector2.UP
		direction = direction.normalized()
		var half := Vector2(maxf(30.0, size.x * 0.5 - 110.0), maxf(30.0, size.y * 0.5 - 210.0))
		var travel := minf(
			half.x / maxf(absf(direction.x), 0.0001), half.y / maxf(absf(direction.y), 0.0001)
		)
		var anchor := center + direction * travel
		var side := direction.orthogonal()
		var arrow := PackedVector2Array(
			[
				anchor + direction * 20.0,
				anchor - direction * 12.0 + side * 11.0,
				anchor - direction * 12.0 - side * 11.0
			]
		)
		TideShapes.fill(self, arrow, TideTokens.FLARE)
		_text(anchor + Vector2(-72.0, 42.0), "БОСС · %.0f М" % at.distance_to(run.boat_at()), 18, TideTokens.FLARE)
		return


func _text(at: Vector2, text: String, point: int, color: Color) -> void:
	var font := TideTokens.mono_font()
	draw_string(font, at + Vector2(1.0, 1.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, point, TideTokens.ink_alpha(0.9))
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, point, color)
