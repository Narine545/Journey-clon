class_name TideTokens
extends RefCounted
## «TIDECUT» — единый арт-директорский словарь интерфейса.
##
## Пять цветов, три шрифта, один ритм. Никаких градиентов, размытий и
## скруглений: всё плоско, как вырезка из судового журнала на чёрной воде.
## Любой новый виджет обязан брать значения отсюда, а не из воздуха.

# --- Палитра (только эти пять цветов) ---
const INK := Color("0d1520") # морской чёрный: фон, текст на светлых панелях
const DEEP := Color("1b3a5c") # тёмная волна: второй слой панелей, тени
const FOAM := Color("efead8") # пена/бумага: основной текст, светлые панели
const FLARE := Color("e3212e") # алая вспышка: опасность, штампы, праздник
const SONAR := Color("35d0ba") # сонарь: интерактив, прогресс, готовность

# --- Сетка ---
const BASE := Vector2(1920.0, 1080.0)
## Шаг и высота зубцов-волн: регулярные, не случайные (14–22 / 6–10).
const TOOTH_W := 18.0
const TOOTH_H := 8.0
## Срез угла: 45–60° даёт «отрезанную» кромку.
const CUT := 30.0
## Наклон блоков: чередуется, каждый крупный узел живёт со своим знаком.
const TILT := [-3.4, 2.6, -1.9, 3.8, -2.4, 1.6, -2.9]
## Периоды качки: 2.4–3.2 с, фазы разные.
const BOB_PERIOD := [2.4, 2.7, 3.0, 3.2, 2.55, 2.85, 3.15]
const BOB_AMP := [0.75, 1.05, 0.9, 1.2, 0.6, 1.1, 0.8]
const BOB_PHASE := [0.0, 1.1, 2.3, 3.4, 4.2, 5.1, 0.7]

# --- Тайминги (ни одного LINEAR на появлении, fade короче 0.5 с) ---
const IN_TIME := 0.22
const HOVER_TIME := 0.09
const PRESS_TIME := 0.06
const STAMP_TIME := 0.16
const WIPE_TIME := 0.34
const HITSTOP := 0.08

# --- Шрифты ---
const TITLE_FONT_PATH := "res://assets/fonts/Unbounded-Black.ttf"
const MONO_FONT_PATH := "res://assets/fonts/JetBrainsMono-ExtraBold.ttf"
const BODY_FONT_PATH := "res://assets/fonts/Oswald-Medium.ttf"

static var _title_font: Font
static var _mono_font: Font
static var _body_font: Font


static func title_font() -> Font:
	if _title_font == null:
		_title_font = load(TITLE_FONT_PATH)
	return _title_font


static func mono_font() -> Font:
	if _mono_font == null:
		_mono_font = load(MONO_FONT_PATH)
	return _mono_font


static func body_font() -> Font:
	if _body_font == null:
		_body_font = load(BODY_FONT_PATH)
	return _body_font


# --- Приглушение делается прозрачностью foam, серого в палитре нет ---
static func foam_alpha(alpha: float) -> Color:
	return Color(FOAM, clampf(alpha, 0.0, 1.0))


static func ink_alpha(alpha: float) -> Color:
	return Color(INK, clampf(alpha, 0.0, 1.0))


static func deep_alpha(alpha: float) -> Color:
	return Color(DEEP, clampf(alpha, 0.0, 1.0))


static func flare_alpha(alpha: float) -> Color:
	return Color(FLARE, clampf(alpha, 0.0, 1.0))


static func sonar_alpha(alpha: float) -> Color:
	return Color(SONAR, clampf(alpha, 0.0, 1.0))


## «Приглушить» цвет до пены заданной прозрачности (без серого).
static func dim(color: Color, alpha: float) -> Color:
	return Color(color, clampf(alpha, 0.0, 1.0))


# --- Готовые надписи: заголовок / тех-текст / тело ---
static func title_settings(point_size: int, color: Color = FOAM, outline: int = 8) -> LabelSettings:
	var settings := LabelSettings.new()
	settings.font = title_font()
	settings.font_size = point_size
	settings.font_color = color
	settings.outline_size = outline
	settings.outline_color = INK
	return settings


static func mono_settings(point_size: int, color: Color = FOAM) -> LabelSettings:
	var settings := LabelSettings.new()
	settings.font = mono_font()
	settings.font_size = point_size
	settings.font_color = color
	return settings


static func body_settings(point_size: int, color: Color = FOAM) -> LabelSettings:
	var settings := LabelSettings.new()
	settings.font = body_font()
	settings.font_size = point_size
	settings.font_color = color
	return settings


## Наклонный заголовок: капс Unbounded, обводка ink, −8…−12°.
static func style_title(label: Label, point_size: int, color: Color = FOAM, outline: int = 8) -> Label:
	label.add_theme_font_override("font", title_font())
	label.add_theme_font_size_override("font_size", point_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_constant_override("outline_size", outline)
	label.add_theme_color_override("font_outline_color", INK)
	return label


static func style_mono(label: Label, point_size: int, color: Color = FOAM) -> Label:
	label.add_theme_font_override("font", mono_font())
	label.add_theme_font_size_override("font_size", point_size)
	label.add_theme_color_override("font_color", color)
	return label


static func style_body(label: Label, point_size: int, color: Color = FOAM) -> Label:
	label.add_theme_font_override("font", body_font())
	label.add_theme_font_size_override("font_size", point_size)
	label.add_theme_color_override("font_color", color)
	return label


## «Записать» время вахты как на настоящем мостике: 04:12, не 4:12.
static func clock(seconds: float) -> String:
	var total := maxi(0, int(floor(seconds)))
	return "%02d:%02d" % [int(total / 60.0), total % 60]
