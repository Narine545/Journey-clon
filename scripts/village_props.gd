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
	var stone := Color("3d3c44")
	var deck_a := Color("57535c")
	var deck_b := Color("49464f")
	# --- Настил: плиты 1.1 × 1.1 м с тёмными швами -------------------------
	var z := QUAY_MIN_Z
	while z < QUAY_MAX_Z:
		var z1 := minf(z + 1.1, QUAY_MAX_Z)
		var x0 := quay_edge_x(z) + 0.12
		var x1 := QUAY_BACK_X
		if x1 - x0 > 0.15:
			var steps := maxi(1, int(ceil((x1 - x0) / 1.1)))
			for i in range(steps):
				var xa := lerpf(x0, x1, float(i) / float(steps))
				var xb := lerpf(x0, x1, float(i + 1) / float(steps))
				var tone := deck_a if (i + int(floor(z))) % 2 == 0 else deck_b
				var za := z
				var zb := z1
				var cx := (xa + xb) * 0.5
				var in_well_x := cx > RAMP_WELL.position.x and cx < RAMP_WELL.end.x
				if in_well_x and zb > RAMP_WELL.position.y and za < RAMP_WELL.end.y:
					# Ровный проём под съезд: ряд распиливается на две
					# полосы, а не выкусывается целыми плитами.
					if za < RAMP_WELL.position.y:
						_deck_quad(xa, xb, za, RAMP_WELL.position.y, tone)
					if zb > RAMP_WELL.end.y:
						_deck_quad(xa, xb, RAMP_WELL.end.y, zb, tone)
				else:
					_deck_quad(xa, xb, za, zb, tone)
		z = z1
	# Швы настила: тёмные бруски по сетке, чтобы плита читалась плитой.
	var zz := QUAY_MIN_Z
	while zz <= QUAY_MAX_Z:
		if zz <= RAMP_WELL.position.y or zz >= RAMP_WELL.end.y:
			var xa := quay_edge_x(zz) + 0.15
			GiltShapes.box(_stone, Vector3((xa + QUAY_BACK_X) * 0.5, QUAY_Y + 0.012, zz),
				Vector3(QUAY_BACK_X - xa, 0.012, 0.055), Color("2f2e35"))
		zz += 1.1
	var xx := QUAY_EDGE_X + 1.2
	while xx < QUAY_BACK_X:
		GiltShapes.box(_stone, Vector3(xx, QUAY_Y + 0.012, -23.5),
			Vector3(0.055, 0.012, 34.8), Color("2f2e35"))
		xx += 1.1
	# --- Стена в воду: курсы кладки и светлая кромка ------------------------
	var courses := 13
	var course_h := (QUAY_Y - QUAY_BOTTOM) / float(courses)
	z = QUAY_MIN_Z
	while z < QUAY_MAX_Z:
		var z1 := minf(z + 0.7, QUAY_MAX_Z)
		var edge := (quay_edge_x(z) + quay_edge_x(z1)) * 0.5
		var portal := (z + z1) * 0.5 > RAMP_WELL.position.y \
			and (z + z1) * 0.5 < RAMP_WELL.end.y
		for course in range(courses):
			var y0 := QUAY_Y - float(course) * course_h
			var y1 := y0 - course_h + 0.012
			# Нижние курсы в проёме не кладём: съезд входит в стену
			# через настоящую арку, а не сквозь камень.
			if portal and y1 < 2.92:
				continue
			var tone := stone.lightened(0.03 + 0.035 * float(course % 3)) \
				if (course + int(floor(z))) % 2 == 0 else stone.darkened(0.06)
			if course == 0:
				tone = Color("6b656d") # кромка-кордон
			var a := Vector3(edge, y0, z)
			var b := Vector3(edge, y0, z1)
			var c := Vector3(edge, y1, z1)
			var d := Vector3(edge, y1, z)
			GiltShapes.out_quad(_stone, a, b, c, d, tone,
				Vector3(edge + 2.0, (y0 + y1) * 0.5, (z + z1) * 0.5))
		z = z1
	# Откосы только по концам набережной. Края выреза под съезд закрыты
	# полноценными стенами портала ниже, а не одной повёрнутой плоскостью.
	for edge_z in [QUAY_MIN_Z, QUAY_MAX_Z]:
		var facing := -1.0 if edge_z == QUAY_MIN_Z else 1.0
		var xa := quay_edge_x(edge_z) - 0.05
		var xb := QUAY_BACK_X
		var a := Vector3(xa, QUAY_Y, edge_z)
		var b := Vector3(xb, QUAY_Y, edge_z)
		var c := Vector3(xb, QUAY_BOTTOM, edge_z)
		var d := Vector3(xa, QUAY_BOTTOM, edge_z)
		GiltShapes.out_quad(_stone, a, b, c, d, stone.darkened(0.06),
			Vector3((xa + xb) * 0.5, 1.0, edge_z - facing * 2.0))
	# Задняя подпорная стена: с улицы набережная — тоже камень, а не
	# открытая полость под настилом. В проёме съезда её нет.
	var bz := QUAY_MIN_Z
	while bz < QUAY_MAX_Z:
		var bz1 := minf(bz + 1.4, QUAY_MAX_Z)
		var mid := (bz + bz1) * 0.5
		if mid <= RAMP_WELL.position.y or mid >= RAMP_WELL.end.y:
			var g0 := ground(QUAY_BACK_X + 0.10, bz).y
			var g1 := ground(QUAY_BACK_X + 0.10, bz1).y
			var bottom := minf(g0, g1) - 0.35
			var h := maxf(0.4, QUAY_Y - bottom)
			GiltShapes.box(_stone, Vector3(QUAY_BACK_X + 0.08, bottom + h * 0.5, mid),
				Vector3(0.40, h, bz1 - bz + 0.02), stone.darkened(0.04))
			if int(floor(mid * 0.7)) % 2 == 0:
				GiltShapes.box(_stone, Vector3(QUAY_BACK_X + 0.09, bottom + h * 0.5, mid),
					Vector3(0.44, 0.10, 0.05), stone.lightened(0.16))
		bz = bz1
	# Портал съезда — не дыра, а каменные ворота: стены траншеи во всю
	# глубину, пол, задняя стена, наличники и свет внутри.
	var px := 160.66
	var well_mid := (RAMP_WELL.position.x + RAMP_WELL.end.x) * 0.5
	var z_mid := (RAMP_WELL.position.y + RAMP_WELL.end.y) * 0.5
	var wall_bottom := 0.55
	var wall_top := QUAY_Y + 0.50
	var wall_h := wall_top - wall_bottom
	for pz in [RAMP_WELL.position.y - 0.14, RAMP_WELL.end.y + 0.14]:
		GiltShapes.box(_stone, Vector3(well_mid, wall_bottom + wall_h * 0.5, pz),
			Vector3(RAMP_WELL.size.x, wall_h, 0.28), Color("5a555e"))
		GiltShapes.box(_stone, Vector3(well_mid, wall_top + 0.05, pz),
			Vector3(RAMP_WELL.size.x + 0.12, 0.10, 0.38), Color("6b656d"))
		var zf: float = pz + (0.15 if pz > -30.0 else -0.15)
		for i in range(4):
			var cy := wall_bottom + 0.85 + float(i) * 0.82
			GiltShapes.beam(_stone, Vector3(RAMP_WELL.position.x + 0.08, cy, zf),
				Vector3(RAMP_WELL.end.x - 0.08, cy, zf), 0.035, Color("45414a"))
		for k in range(4):
			var cx := RAMP_WELL.position.x + 1.15 + float(k) * 2.15
			GiltShapes.box(_stone, Vector3(cx, wall_bottom + wall_h * 0.5, zf),
				Vector3(0.16, wall_h, 0.06), Color("66616a"))
	# Пол траншеи и задняя стена закрывают подклет: из портала видно
	# продолжение съезда, а не чёрную пустоту.
	GiltShapes.box(_stone, Vector3(well_mid, 1.14, z_mid),
		Vector3(RAMP_WELL.size.x - 0.1, 0.22, RAMP_WELL.size.y - 0.1), Color("3a3840"))
	GiltShapes.box(_stone, Vector3(RAMP_WELL.end.x - 0.16, 2.30, z_mid),
		Vector3(0.30, 3.30, RAMP_WELL.size.y), Color("4a4650"))
	# Наличники портала: пилоны, перемычка, карниз, замок и золотая нить.
	for pz in [RAMP_WELL.position.y - 0.18, RAMP_WELL.end.y + 0.18]:
		GiltShapes.box(_stone, Vector3(px - 0.08, 2.15, pz),
			Vector3(0.66, 2.85, 0.42), Color("6b656d"))
		GiltShapes.box(_gilt, Vector3(px - 0.42, 2.15, pz),
			Vector3(0.05, 2.70, 0.28), GiltPalette.GILT * 0.55)
	GiltShapes.box(_stone, Vector3(px - 0.06, 3.18, z_mid),
		Vector3(0.72, 0.46, RAMP_WELL.size.y + 0.9), Color("6b656d"))
	GiltShapes.box(_stone, Vector3(px - 0.02, 3.46, z_mid),
		Vector3(0.84, 0.12, RAMP_WELL.size.y + 1.1), Color("575159"))
	GiltShapes.box(_gilt, Vector3(px - 0.44, 3.00, z_mid),
		Vector3(0.05, 0.05, RAMP_WELL.size.y + 0.5), GiltPalette.GILT * 0.8)
	GiltShapes.box(_gilt, Vector3(px - 0.46, 3.22, z_mid),
		Vector3(0.20, 0.34, 0.38), GiltPalette.GILT * 0.7)
	# Тёплый фонарь в горле портала: чёрный проём читается как вход.
	var portal_lamp := MeshInstance3D.new()
	var bulb := SphereMesh.new()
	bulb.radius = 0.11
	bulb.height = 0.22
	bulb.radial_segments = 10
	portal_lamp.mesh = bulb
	var bulb_mat := StandardMaterial3D.new()
	bulb_mat.albedo_color = Color("ffd2a1")
	bulb_mat.emission_enabled = true
	bulb_mat.emission = Color("ffd2a1")
	bulb_mat.emission_energy_multiplier = 1.5
	portal_lamp.material_override = bulb_mat
	portal_lamp.position = Vector3(px + 0.20, 2.86, z_mid)
	host.add_child(portal_lamp)
	var portal_light := OmniLight3D.new()
	portal_light.position = Vector3(px + 1.40, 2.70, z_mid)
	portal_light.light_color = Color("ffd2a1")
	portal_light.light_energy = 0.85
	portal_light.omni_range = 6.5
	portal_light.shadow_enabled = false
	host.add_child(portal_light)
	# Кордон: тяжёлый камень по кромке, на нём и стоят тумбы.
	z = QUAY_MIN_Z
	while z < QUAY_MAX_Z:
		var z1 := minf(z + 0.9, QUAY_MAX_Z)
		var x0 := quay_edge_x(z)
		var x1 := quay_edge_x(z1)
		GiltShapes.beam(_stone, Vector3(x0, QUAY_Y + 0.10, z), Vector3(x1, QUAY_Y + 0.10, z1),
			0.34, Color("6b656d"))
		z = z1
	# --- Тумбы, кольца, трапы, отбойники ----------------------------------
	z = QUAY_MIN_Z + 1.8
	while z < QUAY_MAX_Z - 1.0:
		var edge := quay_edge_x(z)
		if not (z > SLIP_MIN_Z - 0.6 and z < SLIP_MAX_Z + 0.6):
			# Чугунная тумба с грибовидной головой.
			GiltShapes.cylinder(_dark, Vector3(edge + 0.42, QUAY_Y + 0.32, z),
				0.16, 0.13, 0.54, GiltPalette.IRON, 8)
			GiltShapes.cylinder(_dark, Vector3(edge + 0.42, QUAY_Y + 0.60, z),
				0.21, 0.18, 0.10, GiltPalette.IRON, 8)
			GiltShapes.beam(_gilt, Vector3(edge + 0.42, QUAY_Y + 0.66, z),
				Vector3(edge + 0.42, QUAY_Y + 0.70, z), 0.10, GiltPalette.GILT * 0.6)
			# Кольцо в стене и деревянный отбойник.
			GiltShapes.ring(_dark, Vector3(edge - 0.03, QUAY_Y - 0.55, z), 0.18, 0.12,
				0.05, GiltPalette.IRON, 12, Vector3(-1.0, 0.0, 0.0))
			GiltShapes.cylinder(_wood, Vector3(edge - 0.10, QUAY_Y - 1.55, z), 0.14, 0.14,
				1.5, GiltPalette.WOOD_DARK, 8)
		z += 3.6
	for ladder_z in [-38.4, -20.4, -12.0]:
		var edge := quay_edge_x(ladder_z)
		for sx in [-1.0, 1.0]:
			GiltShapes.beam(_dark, Vector3(edge - 0.12, QUAY_Y + 0.10, ladder_z + float(sx) * 0.24),
				Vector3(edge - 0.12, 0.32, ladder_z + float(sx) * 0.24), 0.045, GiltPalette.IRON)
		var k := 0
		while k < 11:
			var y := 0.45 + float(k) * 0.30
			GiltShapes.beam(_dark, Vector3(edge - 0.12, y, ladder_z - 0.24),
				Vector3(edge - 0.12, y, ladder_z + 0.24), 0.035, GiltPalette.IRON)
			k += 1
	# Сходни на воду: короткий деревянный помост на сваях у южного конца.
	var stage_z := -18.5
	var stage_x := quay_edge_x(stage_z) - 1.6
	GiltShapes.box(_wood, Vector3(stage_x, 0.42, stage_z), Vector3(3.0, 0.14, 2.4),
		GiltPalette.WOOD_WARM.darkened(0.10))
	for sx in [-1.0, 1.0]:
		GiltShapes.cylinder(_wood, Vector3(stage_x + float(sx) * 1.2, -0.35, stage_z - 0.9),
			0.11, 0.11, 1.8, GiltPalette.WOOD_DARK, 8)
		GiltShapes.cylinder(_wood, Vector3(stage_x + float(sx) * 1.2, -0.35, stage_z + 0.9),
			0.11, 0.11, 1.8, GiltPalette.WOOD_DARK, 8)
	# Лестница с набережной на помост.
	for i in range(8):
		var t := float(i) / 7.0
		GiltShapes.box(_stone, Vector3(lerpf(quay_edge_x(stage_z), stage_x + 1.1, t),
			lerpf(QUAY_Y - 0.18, 0.50, t), stage_z + 1.35 - t * 0.1),
			Vector3(0.52, 0.18, 1.15), Color("4a4852").lightened(0.03 * float(i % 3)))
	# --- Наковальня-«носик»: бетонный выступ с фонарём ---------------------
	var nose_z := -39.6
	var nose_x := quay_edge_x(nose_z) - 1.1
	GiltShapes.cylinder(_stone, Vector3(nose_x, QUAY_Y - 0.10, nose_z), 1.05, 0.95, 0.30,
		Color("55525b"), 10)
	# Фонарь на кромке: точка, по которой ночью находят вход в бухту.
	lamp_post(Vector3(nose_x, QUAY_Y + 0.06, nose_z), 3.2, true)
	# Пара старых пушек-«кнехтов» у входа: остров жил не только рыбой.
	for i in range(2):
		var px := nose_x - 1.2 + float(i) * 0.55
		GiltShapes.cylinder(_dark, Vector3(px, QUAY_Y + 0.20, nose_z + 0.9), 0.18, 0.13,
			0.40, GiltPalette.IRON, 10)
		GiltShapes.cylinder(_dark, Vector3(px, QUAY_Y + 0.42, nose_z + 0.9), 0.09, 0.07,
			0.42, GiltPalette.IRON, 8, Basis(Vector3.RIGHT, PI * 0.42))


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
			1.68 - float(i / 3) * 0.42, 0.07), Vector3(0.42, 0.34, 0.012), col)
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
