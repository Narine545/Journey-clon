class_name RaidCutPanel
extends PanelContainer
## Original print-cut silhouette. Only the backing is skewed; text/hit targets stay straight.
var paper := Color("111619f5")
var underprint := Color("e5553e")
var cut := 14.0


static func smooth_polygon(canvas: CanvasItem, points: PackedVector2Array, color: Color) -> void:
	canvas.draw_colored_polygon(points, color)
	var perimeter := points.duplicate()
	if not perimeter.is_empty():
		perimeter.append(perimeter[0])
		# Matching-color antialiased edge covers the hard fill boundary, no viewport MSAA needed.
		canvas.draw_polyline(perimeter, color, 1.0, true)


func _init() -> void:
	var spacing := StyleBoxEmpty.new()
	spacing.content_margin_left = 18
	spacing.content_margin_right = 18
	spacing.content_margin_top = 10
	spacing.content_margin_bottom = 10
	add_theme_stylebox_override("panel", spacing)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	var width := size.x
	var height := size.y
	var edge := minf(cut, width * 0.1)
	var shape := PackedVector2Array(
		[Vector2(edge, 0), Vector2(width, 3), Vector2(width - edge, height), Vector2(0, height - 3)]
	)
	var shadow := PackedVector2Array()
	for point in shape:
		shadow.append(point + Vector2(-5, 5))
	smooth_polygon(self, shadow, underprint)
	smooth_polygon(self, shape, paper)
	draw_line(Vector2(edge + 4, 3), Vector2(width - 3, 6), Color("efe8dc"), 1.0, true)
