class_name PlayerHealth
extends CanvasLayer
## Контактный урон: один источник здоровья, короткая защита от наложения ударов.
const MAX_HEALTH := 100
const INVULNERABILITY := 0.8
var main: MainScene
var health := MAX_HEALTH
var defeated := false
var restarting := false
var invulnerability := 0.0
var damage_flash := 0.0
var warning_time := 0.0
var hud: HealthHUD
var defeat_panel: ColorRect
var restart_button: Button


func setup(main_ref: MainScene) -> void:
	main = main_ref
	layer = 25
	hud = HealthHUD.new()
	hud.owner_health = self
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hud)
	defeat_panel = ColorRect.new()
	defeat_panel.color = Color(0.035, 0.012, 0.012, 0.88)
	defeat_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	defeat_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	defeat_panel.visible = false
	add_child(defeat_panel)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	defeat_panel.add_child(center)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	center.add_child(column)
	var title := Label.new()
	title.text = "ВАС ОДОЛЕЛИ"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	column.add_child(title)
	var description := Label.new()
	description.text = "Новая попытка начнётся с начальным боезапасом и без очков."
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	description.add_theme_font_size_override("font_size", 17)
	column.add_child(description)
	restart_button = Button.new()
	restart_button.text = "НАЧАТЬ ЗАНОВО  ·  ENTER"
	restart_button.custom_minimum_size = Vector2(400, 50)
	restart_button.add_theme_font_size_override("font_size", 19)
	restart_button.pressed.connect(restart)
	column.add_child(restart_button)


func _physics_process(delta: float) -> void:
	invulnerability = maxf(0.0, invulnerability - delta)
	damage_flash = maxf(0.0, damage_flash - delta * 1.7)
	if main == null or main.debug_menu == null or not main.debug_menu.is_open:
		warning_time = maxf(0.0, warning_time - delta)
	if hud != null:
		hud.queue_redraw()


func warn_attack(duration: float) -> void:
	if defeated:
		return
	warning_time = maxf(warning_time, duration)
	main.audio.on_robot_warning()


func take_damage(amount: int) -> bool:
	if defeated or amount <= 0 or invulnerability > 0.0:
		return false
	health = maxi(0, health - amount)
	invulnerability = INVULNERABILITY
	damage_flash = 1.0
	main.audio.on_player_hit()
	if health == 0:
		_defeat()
	return true


func _defeat() -> void:
	defeated = true
	# Поражение не оставляет открытыми взаимодействующие панели и передачу.
	if main.debug_menu != null:
		if main.debug_menu.is_open:
			main.debug_menu.set_open(false)
		main.debug_menu.hint.visible = false
	if main.ambient_spawner != null:
		main.ambient_spawner.set_process(false)
	if main.shop != null and main.shop.is_open:
		main.shop.set_open(false)
	if main.radio_tuner != null:
		main.radio_tuner.set_tuning(false)
		main.radio_tuner.set_transmitting(false)
	main.rifle.aim_requested = false
	defeat_panel.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _input(event: InputEvent) -> void:
	if defeated and event is InputEventKey and event.pressed and not event.echo and event.physical_keycode in [KEY_ENTER, KEY_KP_ENTER]:
		restart()
		get_viewport().set_input_as_handled()


func restart() -> void:
	if not defeated or restarting:
		return
	restarting = true
	# Все покупки и ресурсы принадлежат попытке; аутозагрузки очищаем отдельно.
	Economy.reset_run()
	main.game.reset_run()
	get_tree().call_deferred("reload_current_scene")


class HealthHUD extends Control:
	var owner_health: PlayerHealth

	func _draw() -> void:
		if owner_health == null:
			return
		if owner_health.damage_flash > 0.0:
			draw_rect(Rect2(Vector2.ZERO, size), Color(0.55, 0.03, 0.015, owner_health.damage_flash * 0.19))
		var font := ThemeDB.fallback_font
		if owner_health.warning_time > 0.0 and not owner_health.defeated:
			draw_string_outline(font, Vector2(size.x * 0.5 - 240.0, size.y * 0.20), "РОБОТ ГОТОВИТ УДАР", HORIZONTAL_ALIGNMENT_CENTER, 480.0, 20, 3, Color(0.03, 0.02, 0.02, 0.95))
			draw_string(font, Vector2(size.x * 0.5 - 240.0, size.y * 0.20), "РОБОТ ГОТОВИТ УДАР", HORIZONTAL_ALIGNMENT_CENTER, 480.0, 20, Color(1.0, 0.63, 0.35))
		var hp := owner_health.health
		var color := Color(0.95, 0.40, 0.32) if hp <= 30 else Color(0.91, 0.86, 0.74)
		draw_string_outline(font, Vector2(20, 76), "ЗДОРОВЬЕ: %d / %d" % [hp, PlayerHealth.MAX_HEALTH], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, 3, Color(0.03, 0.02, 0.02, 0.9))
		draw_string(font, Vector2(20, 76), "ЗДОРОВЬЕ: %d / %d" % [hp, PlayerHealth.MAX_HEALTH], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, color)
