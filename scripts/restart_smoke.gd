class_name RestartSmoke
extends Node
## Отдельный прогон: настоящий перезапуск сцены не уничтожает этот узел в root.
func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	await get_tree().process_frame
	var old_main := get_tree().current_scene as MainScene
	if old_main == null:
		printerr("[RESTART] FAIL нет основной сцены")
		get_tree().quit(1)
		return
	old_main.ambient_spawner.set_process(false)
	Economy.add_points(500)
	old_main.rifle.ammo = 1
	old_main.radio_tuner.set_tuning(true)
	old_main.radio_tuner.set_transmitting(true)
	old_main.shop.set_open(true)
	if not old_main.player_health.take_damage(100) or not old_main.player_health.defeated:
		printerr("[RESTART] FAIL смертельный урон")
		get_tree().quit(1)
		return
	if old_main.shop.is_open or old_main.radio_tuner.tuning or old_main.radio_tuner.transmitting or old_main.rifle.can_fire() or not old_main.player_health.defeat_panel.visible:
		printerr("[RESTART] FAIL состояние поражения")
		get_tree().quit(1)
		return
	# Реальный сигнал кнопки и deferred-пересоздание сцены.
	old_main.player_health.restart_button.pressed.emit()
	await get_tree().scene_changed
	await get_tree().process_frame
	var fresh := get_tree().current_scene as MainScene
	var wind_bus := AudioServer.get_bus_index("Wind")
	if fresh == null or fresh.player_health.health != 100 or fresh.player_health.defeated or Economy.points != 0 or fresh.rifle.ammo != int(SupplyCatalog.SETTINGS["start_magazine"]) or fresh.radio_tuner.transmitting or fresh.lift.state != SupplyLift.State.IDLE or AudioServer.get_bus_effect_count(wind_bus) != 1:
		printerr("[RESTART] FAIL новое состояние после перезапуска")
		get_tree().quit(1)
		return
	print("[RESTART] ВСЁ ПРОШЛО")
	get_tree().quit(0)
