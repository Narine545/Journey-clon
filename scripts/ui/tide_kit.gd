class_name TideKit
extends RefCounted
## Фабрики «TIDECUT»: собрать экран из одинаковых деталей, не повторяя
## настройку шрифтов и форм в каждом скрипте.
##
## Порядок важен: свойства выставляются до add_child, иначе _ready()
## успевает собрать виджет со старыми значениями.

const PANEL := preload("res://scenes/ui/kit/PanelTorn.tscn")
const FLAG := preload("res://scenes/ui/kit/Flag.tscn")
const CHAIN := preload("res://scenes/ui/kit/ChainBar.tscn")
const STAMP := preload("res://scenes/ui/kit/Stamp.tscn")
const PORTHOLE := preload("res://scenes/ui/kit/Porthole.tscn")
const BUTTON := preload("res://scenes/ui/kit/TideButton.tscn")
const ISOBATHS := preload("res://scenes/ui/kit/IsobathBackdrop.tscn")
const WIPE := preload("res://scenes/ui/kit/WaveWipe.tscn")
const TITLE := preload("res://scenes/ui/kit/TitleLabel.tscn")


static func place(control: Control, rect: Rect2, deg: float = 0.0) -> Control:
	control.position = rect.position
	control.size = rect.size
	control.pivot_offset = rect.size * 0.5
	control.rotation = deg_to_rad(deg)
	return control


## Плоский полигон как отдельный узел — для мест, где рисовать нужно
## не в _draw(), а по событию (записи журнала, линейки, правила).
static func poly(
	parent: Node,
	points: PackedVector2Array,
	color: Color,
	offset: Vector2 = Vector2.ZERO
) -> Polygon2D:
	var node := Polygon2D.new()
	node.polygon = points
	node.color = color
	node.position = offset
	node.antialiased = false
	node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	parent.add_child(node)
	return node


static func panel(
	parent: Node,
	rect: Rect2,
	paper: Color,
	under: Color = Color(0.0, 0.0, 0.0, 0.0),
	hatch: bool = false,
	deg: float = 0.0,
	teeth: bool = true
) -> TidePanelTorn:
	var node: TidePanelTorn = PANEL.instantiate()
	place(node, rect, deg)
	node.paper = paper
	node.underprint = under
	node.hatch = hatch
	node.teeth = teeth
	parent.add_child(node)
	return node


static func isobaths(
	parent: Node, rect: Rect2, alpha_value: float = 0.06, step: float = 34.0
) -> TideIsobaths:
	var node: TideIsobaths = ISOBATHS.instantiate()
	place(node, rect, 0.0)
	node.line_alpha = alpha_value
	node.step_px = step
	parent.add_child(node)
	return node


static func label(
	parent: Node,
	text_value: String,
	rect: Rect2,
	kind: int = 0,
	point: int = 22,
	color: Color = TideTokens.FOAM,
	deg: float = 0.0,
	wrap: bool = true
) -> Label:
	var node := Label.new()
	node.text = text_value
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wrap else TextServer.AUTOWRAP_OFF
	match kind:
		1:
			TideTokens.style_mono(node, point, color)
		2:
			TideTokens.style_title(node, point, color, 0)
		_:
			TideTokens.style_body(node, point, color)
	place(node, rect, deg)
	parent.add_child(node)
	return node


static func mono(
	parent: Node,
	text_value: String,
	at: Vector2,
	point: int = 20,
	color: Color = TideTokens.FOAM,
	deg: float = 0.0
) -> Label:
	var measured := TideTokens.mono_font().get_string_size(
		text_value, HORIZONTAL_ALIGNMENT_LEFT, -1, point
	)
	return label(
		parent,
		text_value,
		Rect2(at, Vector2(measured.x + 10.0, float(point) * 1.6)),
		1,
		point,
		color,
		deg,
		false
	)


static func stamp(
	parent: Node, text_value: String, rect: Rect2, tint: Color, point: int = 40, deg: float = -12.0
) -> TideStamp:
	var node: TideStamp = STAMP.instantiate()
	place(node, rect, deg)
	node.text = text_value
	node.tint = tint
	node.point_size = point
	node.rest_deg = deg
	parent.add_child(node)
	node.hide()
	return node


static func button(
	parent: Node,
	text_value: String,
	rect: Rect2,
	variant: int = TideButton.Shape.SOLID,
	tint: Color = TideTokens.SONAR,
	font_kind: int = 0,
	point: int = 30,
	label_color: Color = TideTokens.INK,
	deg: float = 0.0
) -> TideButton:
	var node: TideButton = BUTTON.instantiate()
	place(node, rect, deg)
	node.variant = variant
	node.tint = tint
	node.font_kind = font_kind
	node.point_size = point
	node.label_color = label_color
	parent.add_child(node)
	node.set_caption(text_value)
	return node


static func flag(
	parent: Node, rect: Rect2, color: Color, shape: int, deg: float, order: int
) -> TideFlag:
	var node: TideFlag = FLAG.instantiate()
	place(node, rect, deg)
	node.tint = color
	node.form = shape
	node.rest_deg = deg
	node.index = order
	node.phase = float(order) * 1.9
	node.period = TideTokens.BOB_PERIOD[order % TideTokens.BOB_PERIOD.size()]
	node.amplitude = 0.8
	# Мачта уходит за нижний край экрана.
	node.mast = maxf(node.size.y + 120.0, TideTokens.BASE.y + 60.0 - rect.position.y)
	parent.add_child(node)
	return node


## Группа-контейнер: всё содержимое блока живёт в её координатах и
## поворачивается вместе с ней — подписи не разъезжаются с подложкой.
static func group(parent: Node, rect: Rect2, deg: float = 0.0) -> Control:
	var node := Control.new()
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	place(node, rect, deg)
	parent.add_child(node)
	return node


static func fit_point(font: Font, text_value: String, max_width: float, max_point: int, min_point: int = 10) -> int:
	return TideTokens.fit_point(font, text_value, max_width, max_point, min_point)


## Однострочная надпись точного размера. box_width > 0 — фиксированная
## колонка с выравниванием (для цифр, которые меняются на лету).
static func text(
	parent: Node,
	text_value: String,
	at: Vector2,
	kind: int = 1,
	point: int = 20,
	color: Color = TideTokens.FOAM,
	box_width: float = -1.0,
	align: int = HORIZONTAL_ALIGNMENT_LEFT
) -> Label:
	var font := TideTokens.font_of(kind)
	var node := Label.new()
	node.text = text_value
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.autowrap_mode = TextServer.AUTOWRAP_OFF
	node.add_theme_font_override("font", font)
	node.add_theme_font_size_override("font_size", point)
	node.add_theme_color_override("font_color", color)
	node.add_theme_constant_override("outline_size", 0)
	node.horizontal_alignment = align as HorizontalAlignment
	node.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var measured := font.get_string_size(text_value, HORIZONTAL_ALIGNMENT_LEFT, -1, point)
	node.position = at
	node.size = Vector2(box_width if box_width > 0.0 else measured.x + 4.0, font.get_height(point))
	node.pivot_offset = node.size * 0.5
	parent.add_child(node)
	return node


## Многострочный блок (протокол, показания): моно, свой интерлиньяж.
static func block(
	parent: Node,
	text_value: String,
	rect: Rect2,
	kind: int = 1,
	point: int = 20,
	color: Color = TideTokens.FOAM,
	line_gap: int = 8
) -> Label:
	var node := Label.new()
	node.text = text_value
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.autowrap_mode = TextServer.AUTOWRAP_OFF
	node.add_theme_font_override("font", TideTokens.font_of(kind))
	node.add_theme_font_size_override("font_size", point)
	node.add_theme_color_override("font_color", color)
	node.add_theme_constant_override("outline_size", 0)
	node.add_theme_constant_override("line_spacing", line_gap)
	node.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	node.position = rect.position
	node.size = rect.size
	parent.add_child(node)
	return node


## Наклонный заголовок, вписанный в ширину. Наклон — срез глифов, строка
## горизонтальна в координатах родителя.
static func headline(
	parent: Node,
	text_value: String,
	at: Vector2,
	max_width: float,
	max_point: int,
	color: Color = TideTokens.FOAM,
	outline: int = 8,
	slant: float = -10.0,
	misprint: Color = Color(0.0, 0.0, 0.0, 0.0)
) -> TideTitleLabel:
	var node: TideTitleLabel = TITLE.instantiate()
	node.text = text_value.to_upper()
	node.slant = slant
	node.outline = outline
	node.paper_color = color
	node.misprint = misprint
	node.max_width = max_width
	node.max_point = max_point
	node.position = at
	parent.add_child(node)
	node.refit()
	return node
