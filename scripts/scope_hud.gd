class_name ScopeHUD
extends CanvasLayer
## Полноэкранная маска и тихий HUD. Текст/сетка не перехватывают ввод.
var _mask_material: ShaderMaterial
var _drawing: ScopeDrawing


func _ready() -> void:
	layer = 15
	var mask := ColorRect.new()
	mask.set_anchors_preset(Control.PRESET_FULL_RECT)
	mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mask_material = ShaderMaterial.new()
	_mask_material.shader = load("res://shaders/scope_mask.gdshader")
	mask.material = _mask_material
	add_child(mask)
	_drawing = ScopeDrawing.new()
	_drawing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drawing.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_drawing)


func update_state(amount: float, ammo: int, is_ready: bool, range_m: float, wind_cross: float, hit_flash: float) -> void:
	_mask_material.set_shader_parameter("scope_amount", amount)
	_drawing.amount = amount
	_drawing.ammo = ammo
	_drawing.ready_to_fire = is_ready
	_drawing.range_m = range_m
	_drawing.wind_cross = wind_cross
	_drawing.hit_flash = hit_flash
	_drawing.queue_redraw()


class ScopeDrawing extends Control:
	var amount := 0.0
	var ammo := 0
	var ready_to_fire := true
	var range_m := -1.0
	var wind_cross := 0.0
	var hit_flash := 0.0

	func _draw() -> void:
		var font := ThemeDB.fallback_font
		var center := size * 0.5
		var radius := minf(size.x, size.y) * 0.45
		var ink := Color(0.08, 0.08, 0.07, 0.88 * amount)
		if amount > 0.02:
			# Центральные волосы и простые угловые деления без подсветки/аркады.
			var gap := radius * 0.018
			draw_line(center + Vector2(-radius * 0.85, 0), center + Vector2(-gap, 0), ink, 1.5)
			draw_line(center + Vector2(gap, 0), center + Vector2(radius * 0.85, 0), ink, 1.5)
			draw_line(center + Vector2(0, -radius * 0.85), center + Vector2(0, -gap), ink, 1.5)
			draw_line(center + Vector2(0, gap), center + Vector2(0, radius * 0.85), ink, 1.5)
			for i in range(-4, 5):
				if i == 0:
					continue
				var offset := float(i) * radius * 0.11
				draw_line(center + Vector2(offset, -radius * 0.013), center + Vector2(offset, radius * 0.013), ink, 1.0)
				draw_line(center + Vector2(-radius * 0.013, offset), center + Vector2(radius * 0.013, offset), ink, 1.0)
			draw_arc(center, radius * 0.447 / 0.45, 0.0, TAU, 128, Color(0.08, 0.07, 0.06, amount), 2.0)
			var text_col := Color(0.89, 0.84, 0.68, 0.86 * amount)
			var distance_text := "ДИСТ. ~%d М" % roundi(range_m) if range_m >= 0.0 else "ДИСТ. —"
			var wind_text := "ВЕТЕР %s %.1f М/С" % ["→" if wind_cross >= 0.0 else "←", absf(wind_cross)]
			var font_size := clampi(roundi(radius * 0.045), 12, 22)
			draw_string(font, center + Vector2(-radius * 0.58, radius * 0.54), distance_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_col)
			draw_string(font, center + Vector2(-radius * 0.58, radius * 0.61), wind_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_col)
			var status := "ГОТОВА" if ready_to_fire and ammo > 0 else ("НЕТ ПАТРОНОВ" if ammo <= 0 else "ЗАТВОР")
			draw_string(font, center + Vector2(radius * 0.15, radius * 0.61), status, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_col)
		if hit_flash > 0.0:
			var tick := Color(0.94, 0.82, 0.57, clampf(hit_flash, 0.0, 1.0) * 0.7)
			draw_arc(center, maxf(7.0, radius * 0.022), 0.0, TAU, 24, tick, 1.5)
		# Без числовых счётчиков: остаётся только состояние оружия.
		var hud_alpha := 0.68 * (1.0 - amount)
		if hud_alpha > 0.02:
			var status := "ГОТОВА" if ready_to_fire and ammo > 0 else ("НЕТ ПАТРОНОВ" if ammo <= 0 else "ЗАТВОР")
			draw_string(font, Vector2(size.x - 300.0, size.y - 32.0), status, HORIZONTAL_ALIGNMENT_RIGHT, 270, 18, Color(0.92, 0.84, 0.68, hud_alpha))
