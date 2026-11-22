class_name VillageProps
extends GiltProps
## Реквизит «Тихой бухты»: каменная набережная, лодки, сушильни, сети,
## крабовые ловушки, колодец, рынок и трава на скалах.
##
## Всё, что делает посёлок посёлком, а не рядом крыш:
##   • quay()      — настоящая каменная набережная со стеной, откосами,
##                   кольцами, трапами и чёрным ходом к воде;
##   • hjell()     — вешала для рыбы: главный признак Северной Атлантики;
##   • rowboat()   — вёсельная лодка с обшивкой внахлёст (а не «ящик»);
##   • well(), capstan(), fish_table(), lobster_pots(), laundry(),
##     grass() — остальная уличная жизнь.
##
## Геометрия складывается в те же SurfaceTool-наборы, что у GiltProps:
## один материал — одна сетка, поэтому набережная не стоит сотен draw-call.

const QUAY_Y := 4.06
const QUAY_BACK_X := 168.6
const QUAY_MIN_Z := -41.0
const QUAY_MAX_Z := -6.0
const QUAY_EDGE_X := 154.6
const SLIP_MIN_Z := -33.9
const SLIP_MAX_Z := -26.1
const SLIP_EDGE_X := 160.7
const QUAY_BOTTOM := -1.35
## Проём в настиле, через который съезд с пирса поднимается на набережную.
## Без него настил накрывал бы подъём, и он превращался в тёмный тоннель.
const RAMP_WELL := Rect2(160.4, -31.8, 8.4, 3.6)


## Кромка набережной: плавная кривая с вырезом под конец пирса.
## Море в этом месте мелкое, поэтому стенка стоит в воде и видна с лодки.
static func quay_edge_x(z: float) -> float:
	var bevel := 1.4
	var north := smoothstep(SLIP_MIN_Z - bevel, SLIP_MIN_Z, z)
	var south := 1.0 - smoothstep(SLIP_MAX_Z, SLIP_MAX_Z + bevel, z)
	var notch := minf(north, south)
	return lerpf(QUAY_EDGE_X, SLIP_EDGE_X, clampf(notch, 0.0, 1.0))


static func smoothstep(a: float, b: float, x: float) -> float:
	var t := clampf((x - a) / maxf(0.001, b - a), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


## Каменная набережная: настил, стена, откосы, тумбы, кольца, трапы.
func _deck_quad(xa: float, xb: float, za: float, zb: float, tone: Color) -> void:
	if zb - za < 0.02 or xb - xa < 0.02:
		return
	GiltShapes.out_quad(_stone,
		Vector3(xa, QUAY_Y, za), Vector3(xb, QUAY_Y, za),
		Vector3(xb, QUAY_Y, zb), Vector3(xa, QUAY_Y, zb), tone,
		Vector3((xa + xb) * 0.5, QUAY_Y - 1.5, (za + zb) * 0.5))


func quay() -> void:
	# Сплошной настил с настоящим вырезом для съезда. Плитки у кромки
	# разрезаются по точным границам, а не по положению центра.
	var z := QUAY_MIN_Z
	var previous_edge := quay_edge_x(QUAY_MIN_Z + 0.5)
	while z < QUAY_MAX_Z:
		var z1 := minf(z + 1.0, QUAY_MAX_Z)
		for boundary in [RAMP_WELL.position.y, RAMP_WELL.end.y]:
			if z < boundary and z1 > boundary:
				z1 = boundary
		var x := quay_edge_x((z + z1) * 0.5)
		while x < QUAY_BACK_X:
			var x1 := minf(x + 1.0, QUAY_BACK_X)
			for boundary in [RAMP_WELL.position.x, RAMP_WELL.end.x]:
				if x < boundary and x1 > boundary:
					x1 = boundary
			var in_ramp := (x + x1) * 0.5 > RAMP_WELL.position.x \
				and (x + x1) * 0.5 < RAMP_WELL.end.x \
				and (z + z1) * 0.5 > RAMP_WELL.position.y \
				and (z + z1) * 0.5 < RAMP_WELL.end.y
			if not in_ramp:
				var tone := Color("57535c") if (int(floor(x)) + int(floor(z))) % 2 == 0 else Color("514d56")
				_deck_quad(x, x1, z, z1, tone)
			x = x1
		# Кромка целиком сплошная вне проёма, без перемычки над съездом.
		var mid := (z + z1) * 0.5
		if mid <= RAMP_WELL.position.y or mid >= RAMP_WELL.end.y:
			var edge := quay_edge_x(mid)
			var wall_h := QUAY_Y - QUAY_BOTTOM
			# Закрываем ступенчатые переходы между соседними секциями стены:
			# без торцевой вставки в изломе кромки оставалась сквозная щель.
			if absf(edge - previous_edge) > 0.001:
				GiltShapes.box(_stone, Vector3((edge + previous_edge) * 0.5 + 0.16,
					(QUAY_Y + QUAY_BOTTOM) * 0.5, z),
					Vector3(absf(edge - previous_edge) + 0.42, wall_h, 0.42), Color("45424a"))
			GiltShapes.box(_stone, Vector3(edge + 0.16, (QUAY_Y + QUAY_BOTTOM) * 0.5, mid),
				Vector3(0.42, wall_h, z1 - z + 0.03), Color("45424a"))
			GiltShapes.box(_stone, Vector3(edge + 0.16, QUAY_Y + 0.03, mid),
				Vector3(0.48, 0.12, z1 - z + 0.03), Color("777078"))
		previous_edge = quay_edge_x(mid)
		z = z1
	# Боковые стенки траншеи упираются в основание, не перекрывая съезд.
	var mid_x := (RAMP_WELL.position.x + QUAY_BACK_X) * 0.5
	var wall_length := QUAY_BACK_X - RAMP_WELL.position.x
	var bottom := QUAY_BOTTOM
	var wall_height := QUAY_Y - bottom
	for side_z in [RAMP_WELL.position.y - 0.14, RAMP_WELL.end.y + 0.14]:
		GiltShapes.box(_stone, Vector3(mid_x, (QUAY_Y + bottom) * 0.5, side_z),
			Vector3(wall_length, wall_height, 0.28), Color("5a555e"))
	# Несколько причальных тумб, вдали от прохода и въезда.
	for mooring_z in [-38.0, -23.0, -10.0]:
		var edge := quay_edge_x(mooring_z)
		GiltShapes.cylinder(_dark, Vector3(edge + 0.48, QUAY_Y + 0.25, mooring_z),
			0.14, 0.12, 0.50, GiltPalette.IRON, 8)
		GiltShapes.cylinder(_dark, Vector3(edge + 0.48, QUAY_Y + 0.52, mooring_z),
			0.20, 0.18, 0.10, GiltPalette.IRON, 8)


## Простой рабочий фонарь на собственном основании.
func simple_lamp(at: Vector3) -> void:
	GiltShapes.box(_stone, at + Vector3(0.0, 0.08, 0.0), Vector3(0.42, 0.16, 0.42), Color("5b5655"))
	GiltShapes.cylinder(_wood, at + Vector3(0.0, 1.34, 0.0), 0.08, 0.06, 2.55,
		Color("51473d"), 8)
	GiltShapes.box(_dark, at + Vector3(0.0, 2.63, 0.0), Vector3(0.32, 0.10, 0.32), Color("383838"))
	GiltShapes.box(_glass, at + Vector3(0.0, 2.40, 0.0), Vector3(0.20, 0.35, 0.20), Color("ffd2a1"))
	_light_at(at + Vector3(0.0, 2.40, 0.0), Color("ffd2a1"), 0.45, 6.5)


## Вешала для рыбы (hjell): A-образные рамы, перекладины, ряды рыбы.
## Именно этот силуэт читается как «северная рыбацкая деревня».
func hjell(at: Vector3, yaw: float, length := 6.0) -> void:
	var bx := Basis(Vector3.UP, yaw)
	var pairs := maxi(3, int(round(length / 1.8)) + 1)
	for i in range(pairs):
		var z := -length * 0.5 + length * float(i) / float(pairs - 1)
		for sx in [-1.0, 1.0]:
			var foot := at + bx * Vector3(float(sx) * 0.75, 0.0, z)
			var top := at + bx * Vector3(0.0, 2.35, z)
			GiltShapes.beam(_wood, foot, top, 0.09, GiltPalette.WOOD_DARK)
		GiltShapes.beam(_wood, at + bx * Vector3(-1.1, 1.55, z),
			at + bx * Vector3(1.1, 1.55, z), 0.06, GiltPalette.WOOD_DARK)
	for side in [-1.0, 0.0, 1.0]:
		GiltShapes.beam(_wood, at + bx * Vector3(float(side) * 0.75, 2.32, -length * 0.5),
			at + bx * Vector3(float(side) * 0.75, 2.32, length * 0.5), 0.055,
			GiltPalette.ROPE.darkened(0.25))
	# Рыба: тело-«лопата», хвост, подвес. Три нитки на пролёт.
	var fish_per_line := maxi(4, int(length / 0.55))
	for side in [-1.0, 0.0, 1.0]:
		for i in range(fish_per_line):
			var z := -length * 0.5 + 0.35 + float(i) * (length - 0.7) / float(maxi(1, fish_per_line - 1))
			var top := at + bx * Vector3(float(side) * 0.75, 2.30, z)
			GiltShapes.beam(_dark, top, top + Vector3(0.0, -0.28, 0.0), 0.012, GiltPalette.ROPE)
			var body := top + Vector3(0.0, -0.46, 0.0)
			GiltShapes.box(_wood, body, Vector3(0.075, 0.30, 0.20), Color("8d7a5e"))
			GiltShapes.spire(_wood, body + Vector3(0.0, -0.13, 0.02), 0.09, 0.18,
				Color("8d7a5e").darkened(0.12), 4, PI * 0.25)


## Вёсельная лодка: обшивка внахлёст, планширь, банки, вёсла.
## tint — краска борта; лодки в деревне разные, как и дома.
func rowboat(at: Vector3, yaw: float, tint: Color) -> void:
	var bx := Basis(Vector3.UP, yaw)
	var sections := [-2.15, -1.25, 0.0, 1.25, 2.15]
	var half := [0.06, 0.56, 0.72, 0.58, 0.06]
	var sheer := [0.52, 0.64, 0.70, 0.66, 0.58]
	var keel := [-0.10, -0.34, -0.42, -0.34, -0.10]
	var inside := at + bx * Vector3(0.0, -0.05, 0.0)
	for i in range(sections.size() - 1):
		for side in [-1.0, 1.0]:
			var z0: float = sections[i]
			var z1: float = sections[i + 1]
			var a := at + bx * Vector3(float(side) * half[i], sheer[i], z0)
			var b := at + bx * Vector3(float(side) * half[i + 1], sheer[i + 1], z1)
			var c := at + bx * Vector3(float(side) * half[i + 1] * 0.35, keel[i + 1], z1)
			var d := at + bx * Vector3(float(side) * half[i] * 0.35, keel[i], z0)
			GiltShapes.out_quad(_wood, a, b, c, d,
				GiltPalette.WOOD_WARM if i % 2 == 0 else GiltPalette.WOOD_WARM.darkened(0.12), inside)
			# Вторая доска обшивки — «внахлёст».
			var a2 := at + bx * Vector3(float(side) * half[i] * 0.78, (sheer[i] + keel[i]) * 0.5, z0)
			var b2 := at + bx * Vector3(float(side) * half[i + 1] * 0.78,
				(sheer[i + 1] + keel[i + 1]) * 0.5, z1)
			GiltShapes.beam(_wood, a2, b2, 0.045, GiltPalette.WOOD_DARK)
	# Планширь и цветная полоса.
	for side in [-1.0, 1.0]:
		for i in range(sections.size() - 1):
			var a := at + bx * Vector3(float(side) * half[i], sheer[i] + 0.02, sections[i])
			var b := at + bx * Vector3(float(side) * half[i + 1], sheer[i + 1] + 0.02, sections[i + 1])
			GiltShapes.beam(_wood, a, b, 0.08, GiltPalette.WOOD_DARK)
			GiltShapes.beam(_wood, a + Vector3(0.0, -0.16, 0.0), b + Vector3(0.0, -0.16, 0.0),
				0.035, tint)
	# Нос и корма: штевни.
	for side in [-1.0, 1.0]:
		var z: float = sections[-1] if side > 0.0 else sections[0]
		GiltShapes.beam(_wood, at + bx * Vector3(0.0, sheer[-1] if side > 0.0 else sheer[0], z),
			at + bx * Vector3(0.0, keel[-1] if side > 0.0 else keel[0], z), 0.08,
			GiltPalette.WOOD_DARK)
	# Банки и вёсла внутри.
	for i in range(3):
		var z := -1.30 + float(i) * 1.30
		GiltShapes.beam(_wood, at + bx * Vector3(-0.62, 0.50, z),
			at + bx * Vector3(0.62, 0.50, z), 0.09, GiltPalette.WOOD_WARM)
	for side in [-1.0, 1.0]:
		GiltShapes.beam(_wood, at + bx * Vector3(float(side) * 0.55, 0.60, -1.0),
			at + bx * Vector3(float(side) * 1.55, 0.34, 1.45), 0.05,
			GiltPalette.WOOD_WARM.lightened(0.08))


## Лодка в воде как отдельный узел — её можно покачать в _process().
func boat_node(at: Vector3, yaw: float, tint: Color) -> Node3D:
	var node := Node3D.new()
	node.name = "MooredBoat"
	node.position = at
	node.rotation.y = yaw
	var st := GiltShapes.begin()
	var saved_wood := _wood
	_wood = st
	# Местная система: строим лодку от нуля, а не от точки на земле.
	var base := at
	at = Vector3.ZERO
	rowboat(at, 0.0, tint)
	_wood = saved_wood
	var mesh := st.commit()
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.82
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	visual.material_override = mat
	node.add_child(visual)
	node.set_meta("base_y", base.y)
	return node


## Колодец: каменное кольцо, две стойки, ворот, ведро, навес.
func well(at: Vector3) -> void:
	GiltShapes.cylinder(_stone, at + Vector3(0.0, 0.34, 0.0), 1.10, 1.02, 0.70,
		Color("4a4850"), 14)
	GiltShapes.ring(_stone, at + Vector3(0.0, 0.70, 0.0), 1.14, 0.92, 0.12,
		Color("6b656d"), 14, Vector3.UP)
	GiltShapes.cylinder(_dark, at + Vector3(0.0, 0.60, 0.0), 0.92, 0.92, 0.04,
		Color("16202a"), 14)
	for sx in [-1.0, 1.0]:
		GiltShapes.beam(_wood, at + Vector3(float(sx) * 0.86, 0.70, 0.0),
			at + Vector3(float(sx) * 0.72, 2.28, 0.0), 0.085, GiltPalette.WOOD_DARK)
		GiltShapes.beam(_wood, at + Vector3(float(sx) * 0.72, 1.34, -0.70),
			at + Vector3(float(sx) * 0.72, 1.34, 0.70), 0.055, GiltPalette.WOOD_DARK)
	GiltShapes.beam(_wood, at + Vector3(0.0, 2.22, -0.78), at + Vector3(0.0, 2.22, 0.78),
		0.07, GiltPalette.WOOD_DARK)
	GiltShapes.cylinder(_wood, at + Vector3(0.0, 1.28, 0.0), 0.12, 0.12, 1.30,
		GiltPalette.WOOD_WARM, 8, Basis(Vector3.RIGHT, PI * 0.5))
	GiltShapes.beam(_dark, at + Vector3(0.0, 1.24, 0.0), at + Vector3(0.0, 0.82, 0.0),
		0.022, GiltPalette.ROPE)
	GiltShapes.cylinder(_wood, at + Vector3(0.0, 0.66, 0.0), 0.16, 0.13, 0.24,
		GiltPalette.WOOD_WARM.darkened(0.15), 8)
	GiltShapes.beam(_wood, at + Vector3(-0.34, 1.30, 0.0), at + Vector3(0.34, 1.20, 0.0),
		0.04, GiltPalette.IRON)
	GiltShapes.pent_roof(_stone, at + Vector3(0.0, 2.36, 0.0), 1.85, 1.55, 0.04, 0.42,
		Color("3e4a44"), GiltPalette.LEAD)
	GiltShapes.spire(_gilt, at + Vector3(0.0, 2.82, 0.0), 0.10, 0.30,
		GiltPalette.GILT * 0.8, 4, PI * 0.25)


## Кабестан: барабан, вымбовки, трос. Тянуть лодки и сети.
func capstan(at: Vector3) -> void:
	GiltShapes.cylinder(_stone, at + Vector3(0.0, 0.12, 0.0), 0.86, 0.78, 0.24,
		Color("4a4850"), 12)
	GiltShapes.cylinder(_wood, at + Vector3(0.0, 0.62, 0.0), 0.46, 0.40, 0.92,
		GiltPalette.WOOD_WARM.darkened(0.10), 12)
	GiltShapes.cylinder(_dark, at + Vector3(0.0, 1.10, 0.0), 0.52, 0.52, 0.12,
		GiltPalette.IRON, 12)
	for i in range(5):
		var a := TAU * float(i) / 5.0
		GiltShapes.beam(_wood, at + Vector3(cos(a) * 0.40, 1.16, sin(a) * 0.40),
			at + Vector3(cos(a) * 1.55, 1.16, sin(a) * 1.55), 0.07, GiltPalette.WOOD_DARK)
	GiltShapes.cylinder(_wood, at + Vector3(0.0, 0.56, 0.0), 0.60, 0.60, 0.18,
		GiltPalette.ROPE.darkened(0.10), 12)
	GiltShapes.beam(_dark, at + Vector3(0.0, 0.12, 0.0), at + Vector3(0.0, 0.14, 2.2),
		0.045, GiltPalette.ROPE)


## Рыбный стол-аукцион: плита, весы, ящики, лёд, чайки.
func fish_table(at: Vector3, yaw := 0.0) -> void:
	var bx := Basis(Vector3.UP, yaw)
	GiltShapes.box(_stone, at + bx * Vector3(0.0, 0.38, 0.0), Vector3(3.0, 0.16, 1.20),
		Color("7b7570"))
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			GiltShapes.beam(_wood, at + bx * Vector3(float(sx) * 1.34, 0.0, float(sz) * 0.48),
				at + bx * Vector3(float(sx) * 1.34, 0.32, float(sz) * 0.48), 0.09,
				GiltPalette.WOOD_DARK)
	# Весы: стойка, коромысло, две чаши.
	GiltShapes.beam(_dark, at + bx * Vector3(1.05, 0.46, 0.0),
		at + bx * Vector3(1.05, 1.65, 0.0), 0.045, GiltPalette.IRON)
	GiltShapes.beam(_dark, at + bx * Vector3(0.35, 1.60, 0.0),
		at + bx * Vector3(1.75, 1.60, 0.0), 0.035, GiltPalette.IRON)
	for sx in [-1.0, 1.0]:
		var p := at + bx * Vector3(1.05 + float(sx) * 0.55, 1.58, 0.0)
		GiltShapes.beam(_dark, p, p + Vector3(0.0, -0.20, 0.0), 0.015, GiltPalette.IRON)
		GiltShapes.cylinder(_dark, p + Vector3(0.0, -0.26, 0.0), 0.24, 0.20, 0.09,
			Color("3a3a42"), 10)
	# Рыба на столе и ящики рядом.
	for i in range(5):
		var p := at + bx * Vector3(-1.05 + float(i) * 0.42, 0.52, -0.12 + 0.12 * float(i % 2))
		GiltShapes.box(_wood, p, Vector3(0.16, 0.10, 0.46), Color("9a8a6e"))
		GiltShapes.spire(_wood, p + Vector3(0.0, 0.0, 0.25), 0.09, 0.16,
			Color("7d6f58"), 4, PI * 0.25)
	for i in range(3):
		GiltShapes.box(_wood, at + bx * Vector3(-1.55, 0.24 + float(i % 2) * 0.3, 1.05),
			Vector3(0.44, 0.34, 0.40), GiltPalette.WOOD_WARM.darkened(0.08 * float(i)))


## Крабовые ловушки: обручи, сетка, поплавки.
func lobster_pots(at: Vector3, yaw := 0.0) -> void:
	var bx := Basis(Vector3.UP, yaw)
	for i in range(3):
		var off := bx * Vector3(float(i) * 0.62, 0.0, float(i % 2) * 0.30)
		var p := at + off
		GiltShapes.cylinder(_dark, p + Vector3(0.0, 0.22, 0.0), 0.28, 0.28, 0.44,
			Color("3b3a35"), 8)
		for k in range(3):
			GiltShapes.ring(_wood, p + Vector3(0.0, 0.08 + float(k) * 0.16, 0.0),
				0.29, 0.27, 0.02, GiltPalette.ROPE.darkened(0.15), 8, Vector3.UP)
		GiltShapes.spire(_wood, p + Vector3(0.0, 0.44, 0.0), 0.10, 0.16,
			Color("b4543c") if i == 0 else Color("d2a24c"), 5)


## Бельевая верёвка между двумя стойками: цветные пятна над двором.
func laundry(a: Vector3, b: Vector3) -> void:
	var length := Vector2(b.x - a.x, b.z - a.z).length()
	if length < 1.4:
		return
	GiltShapes.beam(_wood, a, a + Vector3(0.0, 2.10, 0.0), 0.07, GiltPalette.WOOD_DARK)
	GiltShapes.beam(_wood, b, b + Vector3(0.0, 2.10, 0.0), 0.07, GiltPalette.WOOD_DARK)
	GiltShapes.beam(_dark, a + Vector3(0.0, 2.04, 0.0), b + Vector3(0.0, 2.04, 0.0),
		0.018, GiltPalette.ROPE)
	var side := Vector3(b.z - a.z, 0.0, a.x - b.x).normalized() * 0.18
	var colors: Array[Color] = [Color("cfc4b4"), Color("7e4a63"), Color("2b7f83"), Color("d9b06a")]
	var count := int(length / 0.72)
	for i in range(count):
		var t := (float(i) + 0.5) / float(count)
		var p := a.lerp(b, t) + Vector3(0.0, 2.02, 0.0)
		var sag := sin(t * PI) * 0.10
		var cloth := colors[i % colors.size()]
		GiltShapes.out_quad(_wood, p - side + Vector3(0.0, -sag, 0.0),
			p + side + Vector3(0.0, -sag, 0.0),
			p + side + Vector3(0.0, -0.62 + sag * 0.4, 0.0),
			p - side + Vector3(0.0, -0.62 + sag * 0.4, 0.0),
			cloth, p + Vector3(0.0, -0.30, 2.0))


## Трава: пучки жёстких северных былинок, гнущихся по ветру.
func grass(at: Vector3, scale_value := 1.0, seed_value := 3) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for i in range(5):
		var a := rng.randf_range(0.0, TAU)
		var r := rng.randf_range(0.0, 0.35) * scale_value
		var p := at + Vector3(cos(a) * r, 0.0, sin(a) * r)
		p.y = main.coast.ground_height(p.x, p.z) + 0.02
		var h := rng.randf_range(0.25, 0.62) * scale_value
		var lean := Vector3(0.20, 0.0, -0.12)
		var shade := Color("56663f").lightened(rng.randf_range(-0.10, 0.16))
		for k in range(3):
			var tip := p + lean * h * (0.5 + 0.2 * float(k)) + Vector3(
				rng.randf_range(-0.12, 0.12) * scale_value, h * (0.7 + 0.15 * float(k)),
				rng.randf_range(-0.12, 0.12) * scale_value)
			GiltShapes.beam(_wood, p, tip, 0.018 * scale_value, shade)


## Доска объявлений у площади: столбы, навес, «бумаги».
func notice_board(at: Vector3, yaw := 0.0) -> void:
	var bx := Basis(Vector3.UP, yaw)
	for sx in [-1.0, 1.0]:
		GiltShapes.beam(_wood, at + bx * Vector3(float(sx) * 0.85, 0.0, 0.0),
			at + bx * Vector3(float(sx) * 0.85, 2.36, 0.0), 0.085, GiltPalette.WOOD_DARK)
	GiltShapes.box(_wood, at + bx * Vector3(0.0, 1.55, 0.0), Vector3(1.95, 1.15, 0.09),
		GiltPalette.WOOD_WARM.darkened(0.08))
	for i in range(5):
		var col := Color("cfc4b4") if i % 2 == 0 else Color("b9ae95")
		GiltShapes.box(_wood, at + bx * Vector3(-0.62 + float(i % 3) * 0.62,
			1.68 - floorf(float(i) / 3.0) * 0.42, 0.07), Vector3(0.42, 0.34, 0.012), col)
	GiltShapes.pent_roof(_stone, at + bx * Vector3(0.0, 2.42, 0.0), 2.30, 0.85, 0.0, 0.30,
		Color("2b2a2e"), GiltPalette.LEAD)
	GiltShapes.spire(_gilt, at + bx * Vector3(0.0, 2.72, 0.0), 0.08, 0.24,
		GiltPalette.GILT * 0.8, 4, PI * 0.25)


## Скамья у дома или на набережной.
func bench(at: Vector3, yaw := 0.0) -> void:
	var bx := Basis(Vector3.UP, yaw)
	GiltShapes.box(_wood, at + bx * Vector3(0.0, 0.46, 0.0), Vector3(1.75, 0.10, 0.42),
		GiltPalette.WOOD_WARM)
	GiltShapes.box(_wood, at + bx * Vector3(0.0, 0.78, -0.22), Vector3(1.75, 0.30, 0.08),
		GiltPalette.WOOD_WARM.darkened(0.08))
	for sx in [-1.0, 1.0]:
		GiltShapes.beam(_dark, at + bx * Vector3(float(sx) * 0.70, 0.0, 0.0),
			at + bx * Vector3(float(sx) * 0.70, 0.46, 0.0), 0.07, GiltPalette.IRON)
		GiltShapes.beam(_dark, at + bx * Vector3(float(sx) * 0.70, 0.46, -0.22),
			at + bx * Vector3(float(sx) * 0.70, 0.92, -0.24), 0.05, GiltPalette.IRON)


## Флагшток с вымпелом у площади: вертикаль, по которой видно ветер.
func flagpole(at: Vector3, cloth: Color) -> void:
	GiltShapes.cylinder(_stone, at + Vector3(0.0, 0.14, 0.0), 0.34, 0.26, 0.28,
		Color("4a4850"), 8)
	GiltShapes.cylinder(_wood, at + Vector3(0.0, 4.20, 0.0), 0.075, 0.035, 8.10,
		GiltPalette.WOOD_DARK, 8)
	GiltShapes.spire(_gilt, at + Vector3(0.0, 8.28, 0.0), 0.10, 0.26,
		GiltPalette.GILT, 4, PI * 0.25)
	var p := at + Vector3(0.0, 7.55, 0.0)
	GiltShapes.out_quad(_wood, p, p + Vector3(1.55, -0.16, 0.0),
		p + Vector3(1.55, -0.62, 0.0), p + Vector3(0.0, -0.46, 0.0), cloth,
		p + Vector3(0.5, -0.3, 1.2))
	GiltShapes.out_quad(_wood, p + Vector3(0.0, -0.48, 0.0), p + Vector3(1.45, -0.64, 0.0),
		p + Vector3(1.30, -0.98, 0.0), p + Vector3(0.0, -0.86, 0.0), cloth.darkened(0.18),
		p + Vector3(0.5, -0.7, 1.2))
