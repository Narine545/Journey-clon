class_name TideTitleLabel
extends Label
## Заголовок «как графика»: Unbounded Black, капс, наклон −8…−12° (срез
## глифов), обводка ink 6–10. Сам вписывается в отведённую ширину, поэтому
## не вылезает из панели, какой бы длинной ни была строка.

@export var max_point := 96
@export var min_point := 28
@export var max_width := 900.0
@export var slant := -10.0
@export var outline := 8
@export var ink_color: Color = TideTokens.INK
@export var paper_color: Color = TideTokens.FOAM
## Второй прогон печати: сдвинутая плоская копия под буквами (не тень).
@export var misprint := Color(0.0, 0.0, 0.0, 0.0)
@export var misprint_offset := Vector2(6.0, 6.0)

var point_size := 96
var _echo: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	autowrap_mode = TextServer.AUTOWRAP_OFF
	vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	refit()


func set_title(value: String) -> void:
	text = value.to_upper()
	refit()


## Подобрать кегль под ширину и пересчитать размер узла.
func refit() -> void:
	var font := TideTokens.title_italic(slant)
	point_size = TideTokens.fit_point(font, text, max_width, max_point, min_point)
	_style(self, paper_color, outline)
	var measured := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, point_size)
	size = Vector2(measured.x + 4.0, font.get_height(point_size))
	pivot_offset = size * 0.5
	if misprint.a > 0.001:
		if _echo == null:
			_echo = Label.new()
			_echo.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_echo.show_behind_parent = true
			_echo.autowrap_mode = TextServer.AUTOWRAP_OFF
			_echo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			add_child(_echo)
		_echo.text = text
		_style(_echo, misprint, 0)
		_echo.position = misprint_offset
		_echo.size = size
	elif _echo != null:
		_echo.hide()


func _style(label: Label, color: Color, outline_px: int) -> void:
	label.add_theme_font_override("font", TideTokens.title_italic(slant))
	label.add_theme_font_size_override("font_size", point_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_constant_override("outline_size", outline_px)
	label.add_theme_color_override("font_outline_color", ink_color)


## Влёт сверху с overshoot.
func play_in(from: Vector2 = Vector2(0, -140)) -> void:
	TideFx.slide_in(self, from, TideTokens.IN_TIME)
