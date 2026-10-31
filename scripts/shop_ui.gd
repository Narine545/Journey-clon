class_name ShopUI
extends CanvasLayer
## Корзина — только выбор. Денежное списание происходит одним заказом.
var main: MainScene
var is_open := false
var selected := 0
var cart: Dictionary = {}
var feedback := ""
var previous_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_CAPTURED
var panel: ShopPanel


func setup(main_ref: MainScene) -> void:
	main = main_ref
	panel = ShopPanel.new()
	panel.shop = self
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.visible = false
	add_child(panel)
	Economy.points_changed.connect(_refresh_points)
	main.lift.state_changed.connect(_refresh_state)
	main.lift.cargo_ready.connect(_refresh_cargo)


func _refresh_points(_points: int, _delta: int) -> void:
	panel.queue_redraw()


func _refresh_state(_state: int) -> void:
	panel.queue_redraw()


func _refresh_cargo() -> void:
	panel.queue_redraw()


func set_open(value: bool) -> void:
	if value == is_open:
		return
	is_open = value
	if value:
		feedback = ""
	panel.visible = value
	if value:
		previous_mouse_mode = Input.mouse_mode
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = previous_mouse_mode
	panel.queue_redraw()


func _input(event: InputEvent) -> void:
	if not is_open or not event is InputEventKey or not event.pressed:
		return
	match event.physical_keycode:
		KEY_ESCAPE, KEY_B:
			if not event.echo:
				set_open(false)
		KEY_UP:
			selected = posmod(selected - 1, SupplyCatalog.ORDER.size())
		KEY_DOWN:
			selected = posmod(selected + 1, SupplyCatalog.ORDER.size())
		KEY_LEFT:
			change_quantity(selected, -1)
		KEY_RIGHT:
			change_quantity(selected, 1)
		KEY_ENTER, KEY_KP_ENTER:
			if not event.echo:
				attempt_order()
		_:
			return
	panel.queue_redraw()
	get_viewport().set_input_as_handled()


func change_quantity(index: int, delta: int) -> void:
	var id := String(SupplyCatalog.ORDER[index])
	var data := SupplyCatalog.item(id)
	if main.lift.is_installed(id) and (delta > 0 or not cart.has(id)):
		feedback = "УЛУЧШЕНИЕ УЖЕ УСТАНОВЛЕНО"
		return
	var limit := 1 if data["type"] == "Upgrade" else 99
	var count := clampi(int(cart.get(id, 0)) + delta, 0, limit)
	if count == 0:
		cart.erase(id)
	else:
		cart[id] = count
	feedback = ""
	panel.queue_redraw()


func attempt_order() -> bool:
	var total := main.lift.order_total(cart)
	if cart.is_empty():
		feedback = "КОРЗИНА ПУСТА"
	elif main.lift.state != SupplyLift.State.IDLE:
		feedback = "ЛИФТ ЗАНЯТ · ДОЖДИТЕСЬ ЕГО ВОЗВРАЩЕНИЯ"
	elif total < 0:
		feedback = "СОСТАВ НЕДОСТУПЕН · ПРОВЕРЬТЕ КОРЗИНУ"
	elif not Economy.can_afford(total):
		feedback = "НЕДОСТАТОЧНО ОЧКОВ ДЛЯ ВСЕГО ЗАКАЗА"
	elif main.lift.request_batch(cart):
		cart.clear()
		feedback = "ЗАКАЗ ПРИНЯТ · ВСЁ ПРИБУДЕТ В ОДНОМ ЯЩИКЕ"
		panel.queue_redraw()
		return true
	else:
		feedback = "ЗАКАЗ НЕ ПРИНЯТ"
	main.audio.on_refused()
	panel.queue_redraw()
	return false


class ShopPanel extends Control:
	var shop: ShopUI
	const ROW_HEIGHT := 65.0

	func box() -> Rect2:
		var width := maxf(1.0, minf(820.0, size.x - 32.0))
		var height := 545.0
		return Rect2(Vector2((size.x - width) * 0.5, (size.y - height) * 0.5), Vector2(width, height))

	func row(index: int) -> Rect2:
		var frame := box()
		return Rect2(frame.position + Vector2(22.0, 112.0 + ROW_HEIGHT * index), Vector2(maxf(1.0, frame.size.x - 44.0), ROW_HEIGHT - 5.0))

	func minus_button(index: int) -> Rect2:
		var rect := row(index)
		return Rect2(Vector2(rect.end.x - 132.0, rect.position.y + 12.0), Vector2(35.0, 35.0))

	func plus_button(index: int) -> Rect2:
		var rect := row(index)
		return Rect2(Vector2(rect.end.x - 45.0, rect.position.y + 12.0), Vector2(35.0, 35.0))

	func order_button() -> Rect2:
		var frame := box()
		return Rect2(frame.end - Vector2(205.0, 76.0), Vector2(180.0, 38.0))

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if order_button().has_point(event.position):
				shop.attempt_order()
			else:
				for i in range(SupplyCatalog.ORDER.size()):
					if row(i).has_point(event.position):
						shop.selected = i
						var id := String(SupplyCatalog.ORDER[i])
						var item := SupplyCatalog.item(id)
						var remove := minus_button(i).has_point(event.position)
						# Щелчок по названию улучшения переключает его, + и − явные.
						if item["type"] == "Upgrade" and not plus_button(i).has_point(event.position) and int(shop.cart.get(id, 0)) > 0:
							remove = true
						shop.change_quantity(i, -1 if remove else 1)
						break
			queue_redraw()
			accept_event()

	func _draw() -> void:
		if shop == null or shop.main == null:
			return
		var font := ThemeDB.fallback_font
		var frame := box()
		var light := Color(0.87, 0.84, 0.71)
		var muted := Color(0.48, 0.49, 0.45)
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.015, 0.018, 0.018, 0.68))
		draw_rect(frame, Color(0.035, 0.05, 0.048, 0.97))
		draw_rect(frame, Color(0.39, 0.46, 0.40, 0.9), false, 1.5)
		draw_string(font, frame.position + Vector2(24, 36), "ТЕРМИНАЛ СНАБЖЕНИЯ", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, light)
		draw_string(font, frame.position + Vector2(24, 67), "%d ОЧКОВ   •   %s" % [Economy.points, shop.main.lift.status_text()], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, light)
		draw_string(font, frame.position + Vector2(24, 94), "ВЫБЕРИТЕ КОЛИЧЕСТВО, ЗАТЕМ НАЖМИТЕ ЗАКАЗАТЬ", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, muted)
		for i in range(SupplyCatalog.ORDER.size()):
			var id := String(SupplyCatalog.ORDER[i])
			var item := SupplyCatalog.item(id)
			var rect := row(i)
			var installed := shop.main.lift.is_installed(id)
			var col := muted if installed else light
			if i == shop.selected:
				draw_rect(rect, Color(0.21, 0.27, 0.22, 0.45))
			draw_rect(rect, Color(0.27, 0.32, 0.27, 0.7), false, 1.0)
			var label := "%s  —  %d" % [item["name"], item["cost"]]
			if installed:
				label += "  •  УСТАНОВЛЕНО"
			draw_string(font, rect.position + Vector2(12, 22), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, col)
			draw_string(font, rect.position + Vector2(12, 45), String(item["description_one_liner"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, col)
			var minus := minus_button(i)
			var plus := plus_button(i)
			draw_rect(minus, Color(0.18, 0.24, 0.20, 0.9))
			draw_rect(plus, Color(0.18, 0.24, 0.20, 0.9))
			draw_string(font, minus.position + Vector2(0, 25), "−", HORIZONTAL_ALIGNMENT_CENTER, minus.size.x, 20, col)
			draw_string(font, plus.position + Vector2(0, 25), "+", HORIZONTAL_ALIGNMENT_CENTER, plus.size.x, 20, col)
			draw_string(font, Vector2(minus.end.x, minus.position.y + 25), str(shop.cart.get(id, 0)), HORIZONTAL_ALIGNMENT_CENTER, plus.position.x - minus.end.x, 18, col)
		var total := shop.main.lift.order_total(shop.cart)
		var total_text := "ИТОГО: %d" % maxi(0, total) if total >= 0 or shop.cart.is_empty() else "СОСТАВ НЕДОСТУПЕН"
		var total_color := Color(0.92, 0.52, 0.38) if total > Economy.points else light
		draw_string(font, frame.position + Vector2(24, 496), total_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 19, total_color)
		var order := order_button()
		var enabled := shop.main.lift.can_order_batch(shop.cart)
		draw_rect(order, Color(0.28, 0.39, 0.29, 1.0) if enabled else Color(0.18, 0.20, 0.18, 1.0))
		draw_rect(order, Color(0.55, 0.59, 0.45, 0.8), false, 1.0)
		draw_string(font, order.position + Vector2(0, 26), "ЗАКАЗАТЬ", HORIZONTAL_ALIGNMENT_CENTER, order.size.x, 18, light if enabled else muted)
		draw_string(font, frame.position + Vector2(24, 458), shop.feedback, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.88, 0.78, 0.49))
		draw_string(font, frame.end - Vector2(frame.size.x - 24, 14), "↑↓ — выбор   ← / → или ЛКМ + / − — количество   ENTER — заказать   B / ESC — выход", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, muted)
