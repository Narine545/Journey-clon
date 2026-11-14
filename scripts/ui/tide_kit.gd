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


static func title(
	parent: Node,
	text_value: String,
	at: Vector2,
	point: int,
	slant: float = -9.0,
	color: Color = TideTokens.FOAM,
	outline: int = 8
) -> TideTitleLabel:
	var node: TideTitleLabel = TITLE.instantiate()
	node.text = text_value.to_upper()
	node.point_size = point
	node.slant = slant
	node.paper_color = color
	node.outline = outline
	node.position = at
	var measured := TideTokens.title_font().get_string_size(
		node.text, HORIZONTAL_ALIGNMENT_LEFT, -1, point
	)
	node.size = Vector2(measured.x + 12.0, float(point) * 1.5)
	node.pivot_offset = node.size * 0.5
	parent.add_child(node)
	node.rotation = deg_to_rad(slant)
	return node


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
	parent.add_child(node)
	return node


## Подгонка заголовка под ширину: крупно, но без обрезки.
static func fit_title(node: TideTitleLabel, max_width: float, point: int, min_point: int = 54) -> void:
	var current := point
	while current > min_point:
		var measured := TideTokens.title_font().get_string_size(
			node.text, HORIZONTAL_ALIGNMENT_LEFT, -1, current
		)
		if measured.x <= max_width:
			break
		current -= 4
	node.point_size = current
	var measured_final := TideTokens.title_font().get_string_size(
		node.text, HORIZONTAL_ALIGNMENT_LEFT, -1, current
	)
	node.size = Vector2(measured_final.x + 12.0, float(current) * 1.5)
	node.pivot_offset = node.size * 0.5
