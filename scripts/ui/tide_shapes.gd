class_name TideShapes
extends RefCounted
## Геометрия «TIDECUT»: срезанные углы, зубцы-волны, штриховка гравюры.
##
## Всё считается кодом в локальных координатах Control. Никаких картинок:
## форма — это полигон, тень — второй полигон со сдвигом, текстура — линии.

## Панель с двумя срезанными углами и зубцами по нижней кромке.
## Возвращает замкнутый полигон в координатах (0,0)…size.
static func torn_rect(
	size: Vector2,
	cut: float = TideTokens.CUT,
	tooth_w: float = TideTokens.TOOTH_W,
	tooth_h: float = TideTokens.TOOTH_H,
	skew: float = 0.0
) -> PackedVector2Array:
	var w := maxf(16.0, size.x)
	var h := maxf(16.0, size.y)
	var c := clampf(cut, 2.0, minf(w, h) * 0.45)
	var step := clampf(tooth_w, 8.0, 40.0)
	var depth := clampf(tooth_h, 2.0, 22.0)
	var points := PackedVector2Array()
	# верхняя кромка: срез левого верхнего угла 45°
	points.append(Vector2(0.0, c))
	points.append(Vector2(c, 0.0))
	points.append(Vector2(w, 0.0))
	# правый нижний срез
	points.append(Vector2(w, h - c))
	# нижняя кромка: регулярные треугольные зубцы справа налево
	var x := w - c
	while x > c + step * 0.5:
		points.append(Vector2(x, h))
		points.append(Vector2(maxf(c, x - step * 0.5), h - depth))
		x -= step
	points.append(Vector2(c, h))
	points.append(Vector2(0.0, h * 0.55))
	points.append(Vector2(0.0, h - c * 0.0))
	if not is_zero_approx(skew):
		for index in points.size():
			var t := points[index].y / h
			points[index] = Vector2(points[index].x + skew * (1.0 - t), points[index].y)
	return points


## Зубцы по верхней кромке — для «отрывных» лент и язычков.
static func torn_rect_top(
	size: Vector2,
	cut: float = TideTokens.CUT,
	tooth_w: float = TideTokens.TOOTH_W,
	tooth_h: float = TideTokens.TOOTH_H
) -> PackedVector2Array:
	var w := maxf(16.0, size.x)
	var h := maxf(16.0, size.y)
	var c := clampf(cut, 2.0, minf(w, h) * 0.45)
	var step := clampf(tooth_w, 8.0, 40.0)
	var depth := clampf(tooth_h, 2.0, 22.0)
	var points := PackedVector2Array()
	var x := c
	while x < w - step * 0.5:
		points.append(Vector2(x, 0.0))
		points.append(Vector2(x + step * 0.5, depth))
		x += step
	points.append(Vector2(w, 0.0))
	points.append(Vector2(w, h - c))
	points.append(Vector2(w - c, h))
	points.append(Vector2(0.0, h))
	points.append(Vector2(0.0, c))
	return points


## Скошенная плашка (кнопки, ярлыки, флаги-прямоугольники).
static func plate(size: Vector2, skew_px: float, cut: float = 0.0) -> PackedVector2Array:
	var w := maxf(8.0, size.x)
	var h := maxf(8.0, size.y)
	var c := clampf(cut, 0.0, minf(w, h) * 0.4)
	return PackedVector2Array(
		[
			Vector2(skew_px + c, 0.0),
			Vector2(w + skew_px, 0.0),
			Vector2(w - skew_px, h),
			Vector2(-skew_px - c, h),
		]
	)


## Треугольный вымпел (флаг №2) — «парус» без прямых углов внизу.
static func pennant(size: Vector2, tail: float = 0.0) -> PackedVector2Array:
	var w := maxf(8.0, size.x)
	var h := maxf(8.0, size.y)
	return PackedVector2Array(
		[
			Vector2(0.0, 0.0),
			Vector2(w, 0.0),
			Vector2(w - w * tail, h * 0.5),
			Vector2(w, h),
			Vector2(0.0, h),
		]
	)


static func hull(size: Vector2) -> PackedVector2Array:
	var w := maxf(20.0, size.x)
	var h := maxf(20.0, size.y)
	# Полуширина корпуса по длине: острый нос, полная середина, срезанная корма.
	var profile := [0.02, 0.16, 0.3, 0.4, 0.46, 0.48, 0.48, 0.46, 0.42, 0.4, 0.4]
	var steps := profile.size()
	var points := PackedVector2Array()
	for index in steps:
		points.append(Vector2(w * (0.5 + float(profile[index])), h * float(index) / float(steps - 1)))
	for index in range(steps - 1, -1, -1):
		points.append(Vector2(w * (0.5 - float(profile[index])), h * float(index) / float(steps - 1)))
	return points


## Стадион (звено якорной цепи, иллюминаторная скоба).
static func stadium(size: Vector2, segments: int = 12) -> PackedVector2Array:
	var w := maxf(4.0, size.x)
	var h := maxf(4.0, size.y)
	var r := minf(w, h) * 0.5
	var points := PackedVector2Array()
	var cy := h * 0.5
	for index in range(segments + 1):
		var angle := -PI * 0.5 + PI * float(index) / float(segments)
		points.append(Vector2(w - r + cos(angle) * r, cy + sin(angle) * r))
	for index in range(segments + 1):
		var angle := PI * 0.5 + PI * float(index) / float(segments)
		points.append(Vector2(r + cos(angle) * r, cy + sin(angle) * r))
	return points


## Закрытая копия полигона (для draw_polyline нужен замкнутый контур).
static func closed(points: PackedVector2Array) -> PackedVector2Array:
	var result := points.duplicate()
	if not result.is_empty():
		result.append(result[0])
	return result


static func offset(points: PackedVector2Array, delta: Vector2) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point in points:
		result.append(point + delta)
	return result


## Плоская заливка + сглаженная кромка тем же цветом: без MSAA и без размытия.
static func fill(canvas: CanvasItem, points: PackedVector2Array, color: Color) -> void:
	if points.size() < 3:
		return
	canvas.draw_colored_polygon(points, color)
	canvas.draw_polyline(closed(points), color, 1.0, true)


static func stroke(canvas: CanvasItem, points: PackedVector2Array, color: Color, width: float = 2.0) -> void:
	if points.size() < 2:
		return
	canvas.draw_polyline(closed(points), color, width, true)


## Гравюрная штриховка: диагональные линии, обрезанные полигоном панели.
static func hatch(
	canvas: CanvasItem,
	polygon: PackedVector2Array,
	spacing: float,
	color: Color,
	width: float = 1.0,
	angle_deg: float = 58.0
) -> void:
	if polygon.size() < 3:
		return
	var bounds := bounds_of(polygon)
	var direction := Vector2.from_angle(deg_to_rad(angle_deg))
	var normal := direction.orthogonal()
	var reach := bounds.size.length() + 16.0
	var center := bounds.get_center()
	var lines := int(ceil(reach / maxf(3.0, spacing))) + 1
	for index in range(-lines, lines + 1):
		var base := center + normal * float(index) * maxf(3.0, spacing)
		var segment := PackedVector2Array([base - direction * reach, base + direction * reach])
		for piece in Geometry2D.intersect_polyline_with_polygon(segment, polygon):
			if piece.size() >= 2:
				canvas.draw_line(piece[0], piece[piece.size() - 1], color, width, true)


static func bounds_of(points: PackedVector2Array) -> Rect2:
	if points.is_empty():
		return Rect2()
	var rect := Rect2(points[0], Vector2.ZERO)
	for point in points:
		rect = rect.expand(point)
	return rect


## Точный контур сигнального флага: 0 — прямоугольный, 1 — треугольный
## (остриё к свободной кромке), 2 — вымпел: сужающийся, с вырезом «ласточкин
## хвост». Кромки нарезаны шагом ~13 px, чтобы вершинный шейдер волны гнул
## полотно плавно, а силуэт оставался ровным.
static func flag_outline(form: int, width: float, height: float) -> PackedVector2Array:
	var w := maxf(48.0, width)
	var h := maxf(48.0, height)
	var corners := PackedVector2Array()
	match form:
		1:
			corners = PackedVector2Array([Vector2(0, 0), Vector2(w, h * 0.5), Vector2(0, h)])
		2:
			corners = PackedVector2Array([
				Vector2(0, 0), Vector2(w, h * 0.15), Vector2(w * 0.78, h * 0.5),
				Vector2(w, h * 0.85), Vector2(0, h)
			])
		_:
			corners = PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, h), Vector2(0, h)])
	return subdivide(corners, 13.0)


## Нарезать замкнутый контур на короткие отрезки.
static func subdivide(corners: PackedVector2Array, step: float = 13.0) -> PackedVector2Array:
	var outline := PackedVector2Array()
	for index in corners.size():
		var a := corners[index]
		var b := corners[(index + 1) % corners.size()]
		var steps := maxi(2, int(ceil(a.distance_to(b) / step)))
		for part in steps:
			outline.append(a.lerp(b, float(part) / float(steps)))
	return outline


## Безопасная зона текста внутри полотна. У треугольника и вымпела кромки
## сходятся, поэтому зона — вписанный прямоугольник, а не «на глаз».
static func flag_text_box(form: int, width: float, height: float) -> Rect2:
	var w := maxf(48.0, width)
	var h := maxf(48.0, height)
	match form:
		1:
			return Rect2(w * 0.05, h * 0.26, w * 0.45, h * 0.48)
		2:
			return Rect2(w * 0.05, h * 0.15, w * 0.66, h * 0.70)
		_:
			return Rect2(w * 0.06, h * 0.10, w * 0.72, h * 0.80)


## Боковой силуэт лодки (нос вправо): рубка, труба, палуба, киль.
static func hull_side(size: Vector2) -> PackedVector2Array:
	var profile := [
		Vector2(0.02, 0.44), Vector2(0.22, 0.44), Vector2(0.22, 0.17), Vector2(0.29, 0.17),
		Vector2(0.29, 0.03), Vector2(0.37, 0.03), Vector2(0.37, 0.17), Vector2(0.50, 0.17),
		Vector2(0.57, 0.44), Vector2(0.88, 0.44), Vector2(1.00, 0.34), Vector2(0.86, 0.97),
		Vector2(0.11, 0.97), Vector2(0.05, 0.80),
	]
	var points := PackedVector2Array()
	for point in profile:
		points.append(Vector2(point.x * size.x, point.y * size.y))
	return points


## Звено цепи анфас: прямоугольник со срезанными углами (без скруглений).
static func link(size: Vector2, chamfer: float) -> PackedVector2Array:
	var w := maxf(6.0, size.x)
	var h := maxf(6.0, size.y)
	var c := clampf(chamfer, 1.0, minf(w, h) * 0.45)
	return PackedVector2Array(
		[
			Vector2(c, 0.0), Vector2(w - c, 0.0), Vector2(w, c), Vector2(w, h - c),
			Vector2(w - c, h), Vector2(c, h), Vector2(0.0, h - c), Vector2(0.0, c),
		]
	)


static func contour(center: Vector2, radius: Vector2, wobble: float, seed_offset: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var count := 42
	for index in range(count):
		var angle := TAU * float(index) / float(count)
		var wave := 1.0 + sin(angle * 3.0 + seed_offset) * wobble + sin(angle * 5.0 - seed_offset) * wobble * 0.45
		points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y) * wave)
	return points
