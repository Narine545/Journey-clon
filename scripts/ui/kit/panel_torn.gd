class_name TidePanelTorn
extends Control
## Панель-вырезка: срезанный угол 45°, зубцы-волна по нижней кромке,
## второй слой-подложка и гравюрная штриховка. Никаких скруглений.

@export var paper := TideTokens.FOAM
@export var underprint := TideTokens.FLARE
@export var underprint_offset := Vector2(9.0, 11.0)
@export var cut := TideTokens.CUT
@export var tooth_w := TideTokens.TOOTH_W
@export var tooth_h := TideTokens.TOOTH_H
@export var skew := 0.0
@export var teeth := true
@export var teeth_on_top := false
@export var hatch := false
@export var hatch_color := TideTokens.deep_alpha(0.35)
@export var hatch_spacing := 7.0
@export var border_color := Color(0.0, 0.0, 0.0, 0.0)
@export var border_width := 0.0
## Двойная телеграфная рамка внутри листа (рапорт, бланки).
@export var double_frame := false
@export var frame_color := TideTokens.INK
@export var frame_inset := 18.0

var _polygon := PackedVector2Array()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(_rebuild)
	_rebuild()


func configure(
	paper_color: Color,
	under_color: Color = Color(0, 0, 0, 0),
	with_hatch: bool = false,
	under_delta: Vector2 = Vector2(9.0, 11.0)
) -> TidePanelTorn:
	paper = paper_color
	underprint = under_color
	hatch = with_hatch
	underprint_offset = under_delta
	_rebuild()
	return self


func _rebuild() -> void:
	pivot_offset = size * 0.5
	if teeth:
		_polygon = (
			TideShapes.torn_rect_top(size, cut, tooth_w, tooth_h)
			if teeth_on_top
			else TideShapes.torn_rect(size, cut, tooth_w, tooth_h, skew)
		)
	else:
		_polygon = TideShapes.plate(size, skew, cut)
	queue_redraw()


func _draw() -> void:
	if _polygon.size() < 3:
		return
	if underprint.a > 0.001:
		TideShapes.fill(self, TideShapes.offset(_polygon, underprint_offset), underprint)
	TideShapes.fill(self, _polygon, paper)
	if hatch:
		TideShapes.hatch(self, _polygon, hatch_spacing, hatch_color, 1.0, 58.0)
	if border_width > 0.0 and border_color.a > 0.001:
		TideShapes.stroke(self, _polygon, border_color, border_width)
	if double_frame:
		var bottom := tooth_h if teeth and not teeth_on_top else 0.0
		var outer := Rect2(
			Vector2(frame_inset, frame_inset),
			Vector2(size.x - frame_inset * 2.0, size.y - frame_inset * 2.0 - bottom)
		)
		draw_rect(outer, frame_color, false, 4.0)
		draw_rect(outer.grow(-9.0), frame_color, false, 1.5)


## Лёгкий вход панели: 0.22 с, overshoot, без LINEAR.
func play_in(from_deg: float = -10.0) -> void:
	TideFx.pop_in(self, 0.72, from_deg)
