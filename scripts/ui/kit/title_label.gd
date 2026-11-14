class_name TideTitleLabel
extends Label
## Заголовок «как графика»: Unbounded Black, капс, наклон −8…−12°,
## обводка ink 6–10. Наклоняется только форма, текст остаётся читаемым.

@export var point_size := 96:
	set(value):
		point_size = value
		_apply()
@export var slant := -9.0:
	set(value):
		slant = value
		_apply_slant()
@export var outline := 8:
	set(value):
		outline = value
		_apply()
@export var ink_color: Color = TideTokens.INK
@export var paper_color: Color = TideTokens.FOAM


func _ready() -> void:
	_apply()
	resized.connect(_apply_slant)


func _apply() -> void:
	add_theme_font_override("font", TideTokens.title_font())
	add_theme_font_size_override("font_size", point_size)
	add_theme_color_override("font_color", paper_color)
	add_theme_constant_override("outline_size", outline)
	add_theme_color_override("font_outline_color", ink_color)
	if is_inside_tree():
		queue_redraw()


func _apply_slant() -> void:
	rotation = deg_to_rad(slant)
	pivot_offset = size * 0.5


func play_in(from: Vector2 = Vector2(0, -140)) -> void:
	TideFx.slide_in(self, from, TideTokens.IN_TIME)
