class_name VillagePortrait
extends Control
## Портрет жителя в бумажной манере TIDECUT: не фотография и не 3D-рендер,
## а вырезка — тёмный овал, пальто, платок, шапка и один инструмент.
## Пять цветов интерфейса и ни одного градиента: портрет должен читаться
## как гравюра на судовой роли, а не как «аватарка».

var person := {}
var portrait_texture: Texture2D


func set_person(data: Dictionary) -> void:
	person = data
	portrait_texture = null
	var path := String(data.get("portrait_path", ""))
	if not path.is_empty() and ResourceLoader.exists(path):
		portrait_texture = load(path) as Texture2D
	queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	if portrait_texture != null:
		draw_texture_rect(portrait_texture, Rect2(Vector2.ZERO, size), false)
		return
	var w := size.x
	var h := size.y
	var cx := w * 0.5
	var head_r := minf(w, h) * 0.20
	var head_y := h * 0.34
	# Фон: глубокая вода и штриховка «гравюры».
	draw_rect(Rect2(Vector2.ZERO, size), TideTokens.INK)
	draw_circle(Vector2(cx, head_y + head_r * 0.55), w * 0.44, TideTokens.DEEP)
	for i in range(9):
		var y := h * 0.62 + float(i) * 9.0
		draw_line(Vector2(12.0, y), Vector2(w - 12.0, y), TideTokens.deep_alpha(0.55), 1.0)
	# Золотая рама-иллюминатор: две дуги и заклёпки.
	var rim := Vector2(cx, h * 0.46)
	var rim_r := minf(w, h) * 0.47
	draw_arc(rim, rim_r, 0.0, TAU, 64, TideTokens.FOAM, 3.0, true)
	draw_arc(rim, rim_r - 7.0, 0.0, TAU, 64, TideTokens.deep_alpha(0.9), 7.0, true)
	for i in range(8):
		var a := TAU * float(i) / 8.0 + PI * 0.125
		draw_circle(rim + Vector2(cos(a), sin(a)) * (rim_r - 2.0), 3.0, TideTokens.FOAM)
	# Плечи и пальто.
	var coat: Color = person.get("coat", TideTokens.DEEP)
	var accent: Color = person.get("accent", TideTokens.SONAR)
	var shoulder := h * 0.72
	var points := PackedVector2Array([
		Vector2(cx - w * 0.40, h),
		Vector2(cx - w * 0.34, shoulder),
		Vector2(cx - w * 0.16, shoulder - h * 0.05),
		Vector2(cx + w * 0.16, shoulder - h * 0.05),
		Vector2(cx + w * 0.34, shoulder),
		Vector2(cx + w * 0.40, h),
	])
	draw_colored_polygon(points, coat)
	# Воротник-платок и шарф: единственный яркий цвет.
	var collar := PackedVector2Array([
		Vector2(cx - w * 0.20, shoulder - h * 0.04),
		Vector2(cx, shoulder + h * 0.10),
		Vector2(cx + w * 0.20, shoulder - h * 0.04),
		Vector2(cx + w * 0.12, shoulder + h * 0.04),
		Vector2(cx, shoulder + h * 0.02),
		Vector2(cx - w * 0.12, shoulder + h * 0.04),
	])
	draw_colored_polygon(collar, accent)
	# Шея и голова — простые пятна, без черт лица, кроме двух штрихов.
	draw_rect(Rect2(cx - head_r * 0.30, head_y + head_r * 0.45, head_r * 0.60, head_r * 0.65),
		Color("c99a76"))
	draw_circle(Vector2(cx, head_y), head_r, Color("c99a76"))
	# Тень половины лица: поворот к свету.
	var shade := PackedVector2Array([
		Vector2(cx, head_y - head_r),
		Vector2(cx + head_r * 0.9, head_y - head_r * 0.3),
		Vector2(cx + head_r * 0.75, head_y + head_r * 0.75),
		Vector2(cx, head_y + head_r * 0.98),
	])
	draw_colored_polygon(shade, Color("a87c5c"))
	draw_line(Vector2(cx - head_r * 0.42, head_y - head_r * 0.10),
		Vector2(cx - head_r * 0.12, head_y - head_r * 0.12), TideTokens.INK, 3.0)
	draw_line(Vector2(cx + head_r * 0.12, head_y - head_r * 0.12),
		Vector2(cx + head_r * 0.42, head_y - head_r * 0.10), TideTokens.INK, 3.0)
	draw_line(Vector2(cx - head_r * 0.16, head_y + head_r * 0.48),
		Vector2(cx + head_r * 0.16, head_y + head_r * 0.48), TideTokens.INK, 2.0)
	# Головной убор: платок, картуз или капюшон.
	var hat := String(person.get("hat", "none"))
	if hat == "kerchief":
		draw_colored_polygon(PackedVector2Array([
			Vector2(cx - head_r, head_y - head_r * 0.30),
			Vector2(cx, head_y - head_r * 1.28),
			Vector2(cx + head_r, head_y - head_r * 0.30),
			Vector2(cx + head_r * 0.15, head_y + head_r * 0.10),
			Vector2(cx - head_r * 0.15, head_y + head_r * 0.10),
		]), accent)
	elif hat == "cap":
		draw_rect(Rect2(cx - head_r * 1.05, head_y - head_r * 0.55, head_r * 2.10, head_r * 0.30),
			coat.darkened(0.15))
		draw_colored_polygon(PackedVector2Array([
			Vector2(cx - head_r * 0.85, head_y - head_r * 0.50),
			Vector2(cx, head_y - head_r * 1.10),
			Vector2(cx + head_r * 0.85, head_y - head_r * 0.50),
		]), coat)
	elif hat == "hood":
		draw_colored_polygon(PackedVector2Array([
			Vector2(cx - head_r * 1.18, head_y + head_r * 0.40),
			Vector2(cx - head_r * 0.95, head_y - head_r * 0.75),
			Vector2(cx, head_y - head_r * 1.22),
			Vector2(cx + head_r * 0.95, head_y - head_r * 0.75),
			Vector2(cx + head_r * 1.18, head_y + head_r * 0.40),
			Vector2(cx + head_r * 0.55, head_y - head_r * 0.10),
			Vector2(cx - head_r * 0.55, head_y - head_r * 0.10),
		]), coat.darkened(0.10))
	# Инструмент в углу: сеть, фонарь, молоток, книга, труба.
	_draw_tool(w, h, String(person.get("prop", "")), accent)
	# Подпись-штамп «ЖИВЁТ ЗДЕСЬ» по нижней кромке.
	draw_rect(Rect2(0.0, h - 34.0, w, 34.0), TideTokens.INK)
	var font := TideTokens.mono_font()
	var caption := "ЖИВЁТ ЗДЕСЬ"
	var text_size := font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 17)
	draw_string(font, Vector2((w - text_size.x) * 0.5, h - 11.0), caption,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 17, TideTokens.foam_alpha(0.78))


func _draw_tool(w: float, h: float, tool: String, accent: Color) -> void:
	var at := Vector2(w - 62.0, h * 0.30)
	match tool:
		"net":
			for i in range(4):
				draw_line(at + Vector2(-26.0, -18.0 + float(i) * 12.0),
					at + Vector2(24.0, -18.0 + float(i) * 12.0),
					TideTokens.foam_alpha(0.5), 2.0)
			for i in range(4):
				draw_line(at + Vector2(-14.0 + float(i) * 12.0, -24.0),
					at + Vector2(-14.0 + float(i) * 12.0, 22.0),
					TideTokens.foam_alpha(0.5), 2.0)
		"lantern", "lamp":
			draw_rect(Rect2(at - Vector2(13.0, 18.0), Vector2(26.0, 34.0)), accent)
			draw_arc(at, 22.0, PI, TAU, 16, TideTokens.FOAM, 3.0, true)
			draw_circle(at, 5.0, TideTokens.FOAM)
		"hammer":
			draw_line(at + Vector2(-18.0, 24.0), at + Vector2(10.0, -20.0),
				TideTokens.FOAM, 5.0)
			draw_rect(Rect2(at + Vector2(2.0, -28.0), Vector2(26.0, 12.0)), accent)
		"book":
			draw_rect(Rect2(at - Vector2(22.0, 18.0), Vector2(44.0, 36.0)), accent)
			draw_line(at + Vector2(-16.0, -6.0), at + Vector2(16.0, -6.0),
				TideTokens.INK, 3.0)
			draw_line(at + Vector2(-16.0, 4.0), at + Vector2(10.0, 4.0),
				TideTokens.INK, 3.0)
		"spyglass":
			draw_line(at + Vector2(-24.0, 18.0), at + Vector2(22.0, -18.0),
				TideTokens.FOAM, 8.0)
			draw_circle(at + Vector2(22.0, -18.0), 8.0, accent)
		"rope":
			for i in range(3):
				draw_arc(at, 14.0 + float(i) * 5.0, 0.0, TAU, 24, accent, 3.0, true)
		"tray":
			draw_line(at + Vector2(-24.0, 4.0), at + Vector2(24.0, 4.0), accent, 4.0)
			draw_rect(Rect2(at + Vector2(-8.0, -14.0), Vector2(14.0, 16.0)),
				TideTokens.foam_alpha(0.8))
		"bucket":
			draw_colored_polygon(PackedVector2Array([
				at + Vector2(-16.0, -12.0), at + Vector2(16.0, -12.0),
				at + Vector2(11.0, 18.0), at + Vector2(-11.0, 18.0),
			]), accent)
		"crate":
			draw_rect(Rect2(at - Vector2(20.0, 16.0), Vector2(40.0, 32.0)), accent)
			draw_line(at + Vector2(-20.0, -16.0), at + Vector2(20.0, 16.0),
				TideTokens.INK, 3.0)
