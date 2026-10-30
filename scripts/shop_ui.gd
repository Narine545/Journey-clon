class_name ShopUI
extends CanvasLayer
## Текстовый терминал: мышь или стрелки + Enter, без экрана успеха.
var main: MainScene
var is_open := false
var selected := 0
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


func _refresh_points(_points: int, _delta: int) -> void:
	panel.queue_redraw()


func _refresh_state(_state: int) -> void:
	panel.queue_redraw()


func set_open(value: bool) -> void:
	if value == is_open:
		return
	is_open = value
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
		KEY_ENTER, KEY_KP_ENTER:
			if not event.echo:
				attempt_selected()
		_:
			return
	panel.queue_redraw()
	get_viewport().set_input_as_handled()


func attempt_selected() -> bool:
	return main.lift.request_order(String(SupplyCatalog.ORDER[selected]))


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

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			for i in range(SupplyCatalog.ORDER.size()):
				if row(i).has_point(event.position):
					shop.selected = i
					shop.attempt_selected()
					queue_redraw()
					break
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
		for i in range(SupplyCatalog.ORDER.size()):
			var id := String(SupplyCatalog.ORDER[i])
			var item := SupplyCatalog.item(id)
			var rect := row(i)
			var available := shop.main.lift.can_order(id)
			var installed := shop.main.lift.is_installed(id)
			var col := light if available else muted
			if i == shop.selected:
				draw_rect(rect, Color(0.21, 0.27, 0.22, 0.45))
			draw_rect(rect, Color(0.27, 0.32, 0.27, 0.7), false, 1.0)
			var label := "%s  —  %d" % [item["name"], item["cost"]]
			if installed:
				label += "  •  УСТАНОВЛЕНО"
			draw_string(font, rect.position + Vector2(12, 22), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, col)
			draw_string(font, rect.position + Vector2(12, 45), String(item["description_one_liner"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, col)
		draw_string(font, frame.end - Vector2(frame.size.x - 24, 35), "ЛКМ / ↑↓ + ENTER — заказ     B / ESC — к радио", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, muted)
