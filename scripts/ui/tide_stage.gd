class_name TideStage
extends Control
## Сцена интерфейса в авторских координатах 1920×1080.
##
## Весь UI рисуется в одном базисе, а на любое окно (1280×720, 1920×1080,
## ультраширокое) переносится единым масштабом — композиция не «разъезжается»,
## а просто уменьшается целиком, как афиша на стене.

var canvas: Control


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas = Control.new()
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.size = TideTokens.BASE
	canvas.pivot_offset = TideTokens.BASE * 0.5
	add_child(canvas)
	resized.connect(_fit)
	_fit()


func _fit() -> void:
	if canvas == null:
		return
	var viewport := size
	if viewport.x <= 1.0 or viewport.y <= 1.0:
		return
	var factor := minf(viewport.x / TideTokens.BASE.x, viewport.y / TideTokens.BASE.y)
	canvas.scale = Vector2(factor, factor)
	canvas.position = (viewport - TideTokens.BASE * factor) * 0.5


## Прямоугольник в авторских координатах с учётом текущего масштаба.
func to_authored(local: Vector2) -> Vector2:
	return local / maxf(0.0001, canvas.scale.x)
