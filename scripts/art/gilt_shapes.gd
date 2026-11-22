class_name GiltShapes
extends RefCounted
## Процедурная «резьба» посёлка: стрельчатая арка, шпиль, шатровая кровля,
## роза-окно, крабы на гребне. Всё складывается в SurfaceTool — как MeshKit
## у пирса, — поэтому сотня деталей остаётся сеткой на материал, а не сотней
## узлов.
##
## Цвет — вершинный (материал включает vertex_color_use_as_albedo), поэтому
## камень, золото и стекло могут жить в одной сетке и всё равно быть разными.
##
## Лицевая грань — там же, где у MeshKit. Чтобы не гадать с порядком вершин,
## замкнутые тела строятся через out_* с явной точкой «внутрь»: если нормаль
## смотрит во внутренность, обход разворачивается сам.
##
## Ориентация: local-пространство любой детали — +Y вверх, +Z наружу от
## стены. `facing(normal)` даёт базис, который это сохраняет, поэтому одно и
## то же окно ставится на любой фасад без второй реализации.


# --- Каркас ---------------------------------------------------------------

static func begin() -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	return st


static func finish(st: SurfaceTool) -> ArrayMesh:
	return st.commit()


## Базис детали, у которой local +Z смотрит по normal, +Y остаётся вверх.
static func facing(normal: Vector3) -> Basis:
	var n := normal.normalized()
	if n.length_squared() < 0.5:
		return Basis.IDENTITY
	var up := Vector3.UP
	if absf(n.dot(up)) > 0.98:
		up = Vector3(0.0, 0.0, 1.0)
	var right := up.cross(n).normalized()
	var true_up := n.cross(right).normalized()
	return Basis(right, true_up, n)


static func tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, col: Color) -> void:
	var n := (c - a).cross(b - a)
	if n.length_squared() < 1e-12:
		return
	n = n.normalized()
	for p in [a, b, c]:
		st.set_color(col)
		st.set_normal(n)
		st.add_vertex(p)


## Треугольник, гарантированно смотрящий НАРУЖУ от точки inside.
static func out_tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3,
		col: Color, inside: Vector3) -> void:
	var n := (c - a).cross(b - a)
	if n.dot((a + b + c) / 3.0 - inside) < 0.0:
		tri(st, a, c, b, col)
	else:
		tri(st, a, b, c, col)


static func out_quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3,
		col: Color, inside: Vector3) -> void:
	out_tri(st, a, b, c, col, inside)
	out_tri(st, a, c, d, col, inside)


# --- Готовые тела ---------------------------------------------------------

static func box(st: SurfaceTool, center: Vector3, size: Vector3, col: Color,
		bx := Basis.IDENTITY) -> void:
	MeshKit.add_box(st, center, size, bx, col)


## Брус между двумя точками: доска, стропило, кованая связь.
static func beam(st: SurfaceTool, a: Vector3, b: Vector3, thick: float, col: Color) -> void:
	var d := b - a
	if d.length() < 0.001:
		return
	var up := Vector3.UP if absf(d.normalized().y) < 0.98 else Vector3(0.0, 0.0, 1.0)
	var bx := Basis.looking_at(d, up)
	MeshKit.add_box(st, (a + b) * 0.5, Vector3(thick, thick, d.length()), bx, col)


static func cylinder(st: SurfaceTool, center: Vector3, r_bottom: float, r_top: float,
		height: float, col: Color, segs := 12, bx := Basis.IDENTITY,
		caps := true) -> void:
	MeshKit.add_cylinder(st, center, r_bottom, r_top, height, segs, col, caps, caps, bx)


## Пирамида/шпиль: многоугольник в основании, остриё сверху.
static func spire(st: SurfaceTool, base: Vector3, half: float, height: float,
		col: Color, sides := 4, twist := 0.0) -> void:
	var apex := base + Vector3(0.0, height, 0.0)
	var inside := base + Vector3(0.0, height * 0.25, 0.0)
	var ring_pts: Array[Vector3] = []
	for i in range(sides):
		var a := TAU * float(i) / float(sides) + twist
		ring_pts.append(base + Vector3(cos(a) * half, 0.0, sin(a) * half))
	for i in range(sides):
		out_tri(st, ring_pts[i], ring_pts[(i + 1) % sides], apex, col, inside)
	if sides == 4:
		# Донышко: без него шпиль «просвечивает» снизу на крутом ракурсе.
		for i in range(sides):
			out_tri(st, ring_pts[i], ring_pts[(i + 1) % sides], base, col,
				base + Vector3(0.0, -0.5, 0.0))


# --- Кровли ---------------------------------------------------------------

## Двускатная кровля: два ската, конёк, свесы, торцевые щипцы.
## Конёк идёт вдоль X, скаты смотрят в ±Z. Возвращает высоту конька.
static func gable_roof(st: SurfaceTool, center: Vector3, width: float, depth: float,
		eave_y: float, rise: float, col_roof: Color, col_edge: Color,
		col_gable: Color, overhang := 0.34, ridge_offset := 0.0) -> float:
	var hw := width * 0.5 + overhang
	var hd := depth * 0.5 + overhang
	var ridge := center.y + eave_y + rise
	var inside := center + Vector3(0.0, eave_y + rise * 0.3, ridge_offset)
	for side in [-1.0, 1.0]:
		var z_out: float = center.z + float(side) * hd
		var a := Vector3(center.x - hw, ridge, center.z + ridge_offset)
		var b := Vector3(center.x + hw, ridge, center.z + ridge_offset)
		var c := Vector3(center.x + hw, center.y + eave_y, z_out)
		var d := Vector3(center.x - hw, center.y + eave_y, z_out)
		out_quad(st, a, b, c, d, col_roof, inside)
		# Швы шифера: тонкие доски по скату, светлее кровли.
		var rows := maxi(3, int(rise / 0.40))
		for i in range(rows):
			var t := (float(i) + 0.5) / float(rows)
			var y := lerpf(ridge, center.y + eave_y, t) + 0.018
			var z := lerpf(center.z + ridge_offset, z_out, t)
			var shift := lerpf(hw, hw - 0.03, t)
			beam(st, Vector3(center.x - shift, y, z), Vector3(center.x + shift, y, z),
				0.022, col_edge)
	# Щипцы: треугольники по торцам ±X, закрывают скаты сбоку.
	for side in [-1.0, 1.0]:
		var x: float = center.x + float(side) * (width * 0.5 - 0.02)
		var a := Vector3(x, center.y + eave_y, center.z - depth * 0.5 + 0.02)
		var b := Vector3(x, center.y + eave_y, center.z + depth * 0.5 - 0.02)
		var c := Vector3(x, ridge, center.z + ridge_offset)
		out_tri(st, a, b, c, col_gable, center)
		# Ветровая доска по кромке щипца — характер готического силуэта.
		beam(st, a, c, 0.085, col_edge)
		beam(st, b, c, 0.085, col_edge)
	beam(st, Vector3(center.x - hw, ridge + 0.02, center.z + ridge_offset),
		Vector3(center.x + hw, ridge + 0.02, center.z + ridge_offset), 0.11, col_edge)
	return eave_y + rise


## Шатровая кровля: навес, звонница, башня.
static func hip_roof(st: SurfaceTool, center: Vector3, width: float, depth: float,
		eave_y: float, rise: float, col_roof: Color, col_edge: Color,
		overhang := 0.3) -> void:
	var hw := width * 0.5 + overhang
	var hd := depth * 0.5 + overhang
	var apex := center + Vector3(0.0, eave_y + rise, 0.0)
	var inside := center + Vector3(0.0, eave_y + rise * 0.25, 0.0)
	var corners := [
		center + Vector3(-hw, eave_y, -hd), center + Vector3(hw, eave_y, -hd),
		center + Vector3(hw, eave_y, hd), center + Vector3(-hw, eave_y, hd),
	]
	for i in range(4):
		var p: Vector3 = corners[i]
		var q: Vector3 = corners[(i + 1) % 4]
		out_tri(st, p, q, apex, col_roof, inside)
		beam(st, p.lerp(apex, 0.5), q.lerp(apex, 0.5), 0.032, col_edge)


## Одиночный скат вперёд: крыльцо, навес над дверью, портик.
static func pent_roof(st: SurfaceTool, center: Vector3, width: float, depth: float,
		back_y: float, drop: float, col: Color, col_edge: Color) -> void:
	var inside := center + Vector3(0.0, back_y - drop * 0.3, 0.0)
	var a := center + Vector3(-width * 0.5, back_y, -depth * 0.5)
	var b := center + Vector3(width * 0.5, back_y, -depth * 0.5)
	var c := center + Vector3(width * 0.5, back_y - drop, depth * 0.5)
	var d := center + Vector3(-width * 0.5, back_y - drop, depth * 0.5)
	out_quad(st, a, b, c, d, col, inside)
	beam(st, c, d, 0.07, col_edge)


# --- Экструзия профиля -----------------------------------------------------

## Выдавить 2D-профиль (x — вправо, y — вверх) вдоль local Z от z0 до z1.
static func extrude_z(st: SurfaceTool, profile: PackedVector2Array,
		z0: float, z1: float, col: Color, origin := Vector3.ZERO,
		bx := Basis.IDENTITY) -> void:
	if profile.size() < 3:
		return
	var pts := profile
	if _signed_area(pts) < 0.0:
		pts = PackedVector2Array(pts)
		pts.reverse()
	var z_lo := minf(z0, z1)
	var z_hi := maxf(z0, z1)
	for i in range(pts.size()):
		var p := pts[i]
		var q := pts[(i + 1) % pts.size()]
		var edge := q - p
		if edge.length_squared() < 1e-10:
			continue
		# Наружная нормаль ребра для CCW-профиля — (dy, -dx).
		var outward := (bx * Vector3(edge.y, -edge.x, 0.0)).normalized()
		var a := origin + bx * Vector3(p.x, p.y, z_lo)
		var b := origin + bx * Vector3(q.x, q.y, z_lo)
		var c := origin + bx * Vector3(q.x, q.y, z_hi)
		var d := origin + bx * Vector3(p.x, p.y, z_hi)
		var probe := (a + b + c) / 3.0 + outward * 0.05
		out_tri(st, a, b, c, col, probe)
		out_tri(st, a, c, d, col, probe)
	_cap(st, pts, z_lo, col, origin, bx, Vector3(0.0, 0.0, 1.0))
	_cap(st, pts, z_hi, col, origin, bx, Vector3(0.0, 0.0, -1.0))


static func _cap(st: SurfaceTool, pts: PackedVector2Array, z: float, col: Color,
		origin: Vector3, bx: Basis, inside_local: Vector3) -> void:
	var centroid := Vector2.ZERO
	for p in pts:
		centroid += p
	centroid /= float(pts.size())
	var inside := origin + bx * (Vector3(centroid.x, centroid.y, z) + inside_local * 2.0)
	for i in range(1, pts.size() - 1):
		out_tri(st,
			origin + bx * Vector3(pts[0].x, pts[0].y, z),
			origin + bx * Vector3(pts[i].x, pts[i].y, z),
			origin + bx * Vector3(pts[i + 1].x, pts[i + 1].y, z), col, inside)


static func _signed_area(pts: PackedVector2Array) -> float:
	var area := 0.0
	for i in range(pts.size()):
		var p := pts[i]
		var q := pts[(i + 1) % pts.size()]
		area += p.x * q.y - q.x * p.y
	return area * 0.5


# --- Готический словарь ----------------------------------------------------

## Стрельчатая арка: прямоугольник + два сегмента. Ширина w, низ base_y,
## начало закругления spring_y. Профиль CCW в локальных XY.
static func pointed_arch(width: float, base_y: float, spring_y: float,
		segments := 7) -> PackedVector2Array:
	var w := maxf(0.08, width)
	var hw := w * 0.5
	var cx := hw * 0.36
	var r := hw + cx
	var apex := spring_y + sqrt(maxf(r * r - cx * cx, 0.001))
	var pts := PackedVector2Array()
	pts.append(Vector2(-hw, base_y))
	pts.append(Vector2(-hw, spring_y))
	var a_apex := atan2(apex - spring_y, -cx)
	for i in range(segments + 1):
		var a := lerpf(PI, a_apex, float(i) / float(segments))
		pts.append(Vector2(cx + cos(a) * r, spring_y + sin(a) * r))
	for i in range(segments, -1, -1):
		var a := lerpf(PI, a_apex, float(i) / float(segments))
		pts.append(Vector2(-(cx + cos(a) * r), spring_y + sin(a) * r))
	pts.append(Vector2(hw, spring_y))
	pts.append(Vector2(hw, base_y))
	var clean := PackedVector2Array()
	for p in pts:
		if clean.is_empty() or clean[clean.size() - 1].distance_to(p) > 1e-4:
			clean.append(p)
	return clean


## Ланцетное окно: тёмный витраж + каменное обрамление + переплёт + роза.
## Стекло идёт в glass_st (эмиссивный материал), обрамление — в frame_st.
static func lancet(glass_st: SurfaceTool, frame_st: SurfaceTool, at: Vector3,
		width: float, height: float, glow: Color, frame: Color, night01: float,
		depth := 0.07, bx := Basis.IDENTITY) -> void:
	var spring_y := height - width * 0.62
	var glass_col := glow.lerp(GiltPalette.GLASS_DAY, 1.0 - clampf(night01 * 1.35, 0.0, 1.0))
	var glass := pointed_arch(width, 0.0, spring_y, 8)
	extrude_z(glass_st, glass, 0.0, depth, glass_col, at, bx)
	var outer := pointed_arch(width + 0.24, -0.12, spring_y, 8)
	extrude_z(frame_st, outer, -0.06, depth * 0.55, frame, at, bx)
	# Переплёт: центральная стойка и две перекладины, как в свинцовом стекле.
	var front := at + bx * Vector3(0.0, 0.0, depth + 0.012)
	box(frame_st, at + bx * Vector3(0.0, height * 0.28, depth + 0.012),
		Vector3(0.05, height * 0.5, 0.035), frame, bx)
	box(frame_st, at + bx * Vector3(0.0, spring_y * 0.42, depth + 0.012),
		Vector3(width * 0.92, 0.045, 0.035), frame, bx)
	box(frame_st, at + bx * Vector3(0.0, spring_y * 0.78, depth + 0.012),
		Vector3(width * 0.74, 0.045, 0.035), frame, bx)
	# Роза в голове арки: мелкая деталь, но именно она читается как «готика».
	var rose_at := at + bx * Vector3(0.0, spring_y + width * 0.24, depth + 0.014)
	ring(frame_st, rose_at, width * 0.30, width * 0.21, 0.028, frame, 12, bx * Vector3(0, 0, 1))
	for i in range(4):
		var ang := PI * 0.25 + float(i) * PI * 0.5
		beam(frame_st, rose_at + bx * Vector3(cos(ang), sin(ang), 0.0) * width * 0.21,
			rose_at + bx * Vector3(-cos(ang), -sin(ang), 0.0) * width * 0.21,
			0.028, frame)
	# Подоконник: без него окно «наклеено» на стену.
	box(frame_st, at + bx * Vector3(0.0, -0.09, depth * 0.4),
		Vector3(width + 0.34, 0.10, 0.20), frame, bx)
	if front.length_squared() < 0.0:
		return


## Кольцо (плоский тор) в плоскости с нормалью plane: роза, обод, окантовка.
static func ring(st: SurfaceTool, center: Vector3, r_out: float, r_in: float,
		width: float, col: Color, segs := 14, plane := Vector3(0.0, 0.0, 1.0)) -> void:
	var n := plane.normalized()
	var a := n.cross(Vector3.UP)
	if a.length_squared() < 1e-6:
		a = n.cross(Vector3.RIGHT)
	a = a.normalized()
	var b := n.cross(a).normalized()
	var half := n * width * 0.5
	var inner: Array[Vector3] = []
	var outer: Array[Vector3] = []
	for i in range(segs):
		var ang := TAU * float(i) / float(segs)
		var dir := a * cos(ang) + b * sin(ang)
		inner.append(center + dir * r_in)
		outer.append(center + dir * r_out)
	for i in range(segs):
		var j := (i + 1) % segs
		var probe: Vector3 = center + (((inner[i] + inner[j] + outer[j] + outer[i]) * 0.25) - center) * 0.5
		out_quad(st, outer[i] + half, outer[j] + half, inner[j] + half, inner[i] + half, col, probe)
		out_quad(st, outer[i] - half, inner[i] - half, inner[j] - half, outer[j] - half, col, probe)
		out_quad(st, outer[i] + half, outer[j] + half, outer[j] - half, outer[i] - half, col, probe)
		out_quad(st, inner[i] + half, inner[i] - half, inner[j] - half, inner[j] + half, col, probe)


## Гребень с крабами: ряд мелких шпилей по коньку.
static func crest(st: SurfaceTool, from: Vector3, to: Vector3, count: int,
		size: float, col: Color) -> void:
	for i in range(count):
		var t := (float(i) + 0.5) / float(maxi(count, 1))
		spire(st, from.lerp(to, t), size * 0.6, size, col, 4, PI * 0.25)


## Кованая связь: брус с поперечной планкой.
static func brace(st: SurfaceTool, a: Vector3, b: Vector3, thick: float, col: Color) -> void:
	beam(st, a, b, thick, col)
	var mid := (a + b) * 0.5
	var d := (b - a).normalized()
	var side := d.cross(Vector3.UP).normalized() * (thick * 2.2)
	beam(st, mid - side, mid + side, thick * 0.6, col)


## Труба с дымником и колпачком-«юбкой».
static func chimney_top(st: SurfaceTool, at: Vector3, size: float, col_stone: Color,
		col_iron: Color) -> void:
	box(st, at + Vector3(0.0, 0.10, 0.0), Vector3(size * 1.24, 0.10, size * 1.18), col_stone)
	box(st, at + Vector3(0.0, 0.22, 0.0), Vector3(size * 0.34, 0.26, size * 0.34), col_iron)
	spire(st, at + Vector3(0.0, 0.34, 0.0), size * 0.30, size * 0.34, col_iron, 4)
