class_name SlickFilm
extends RefCounted
## Локальная 2D particle-fluid модель тонкой пигментной плёнки.
## Давление, вязкость и короткодействующее сцепление; не объёмная вода.
const RESOLUTION := 64
const EXTENT := 4.0
const SPACING := 0.30
const KERNEL := 0.62
const REST_DENSITY := 2.55
const STEP := 0.05
const MAX_PARTICLES := 128
const CELL_NEIGHBORS: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]

var positions := PackedVector2Array()
var origins := PackedVector2Array()
var rest_positions := PackedVector2Array()
var velocities := PackedVector2Array()
var densities := PackedFloat32Array()
var forces := PackedVector2Array()
var texture: ImageTexture
var previous_texture: ImageTexture
var _last_image: Image
var idle := 0.0
var disturbed := false
var persistent := false
var _sleeping := false
var _rest_forces := PackedVector2Array()
var _accumulator := 0.0
var _hulls: Dictionary = {}
var _neighbors := PackedVector4Array()


func setup(variation: float, shape_time: float) -> void:
	# Гексагональная укладка с малым стабильным джиттером: нет линии разреза
	# и нет заранее назначенных левой/правой половин.
	var rng := RandomNumberGenerator.new()
	rng.seed = int(absf(variation) * 10000.0) + 41
	for row in range(-7, 8):
		for column in range(-7, 8):
			var at := Vector2((column + 0.5 * (row & 1)) * SPACING,
				row * SPACING * 0.8660254)
			at += Vector2(rng.randf_range(-0.025, 0.025), rng.randf_range(-0.025, 0.025))
			if _rest_distance(at * 0.82, shape_time, variation) < -0.025:
				positions.append(at)
				origins.append(at)
				velocities.append(Vector2.ZERO)
	assert(positions.size() <= MAX_PARTICLES)
	rest_positions = positions.duplicate()
	densities.resize(positions.size())
	forces.resize(positions.size())
	_compute_forces()
	_rest_forces = forces.duplicate()
	_upload()


static func _rest_distance(p: Vector2, t: float, variation: float) -> float:
	var d := (p + Vector2(sin(t), cos(t * 0.8)) * 0.10).length() - 0.96
	for i in range(4):
		var a := float(i) * 2.399963 + variation * 2.7
		var center := Vector2(cos(a), sin(a)) * (0.68 + 0.15 * sin(t + float(i)))
		var lobe := p.distance_to(center) - (0.52 + 0.12 * sin(t * 1.2 + float(i) * 2.0))
		var h := maxf(0.48 - absf(d - lobe), 0.0) / 0.48
		d = minf(d, lobe) - h * h * 0.48 * 0.25
	return d


func push_hull(from: Vector2, to: Vector2, heading: Vector2,
		half_length: float, half_width: float, speed: float, source_id: int) -> void:
	# Объединяем физические кадры до очередного шага плёнки. Судно и баржа
	# имеют разные id: более поздний источник не стирает предыдущий.
	if _hulls.has(source_id):
		from = _hulls[source_id][0]
	_hulls[source_id] = [from, to, heading, half_length, half_width, speed]


func advance(delta: float) -> bool:
	idle += delta
	# Остаток частично собранного пятна сохраняет собственную форму,
	# но без корпуса поблизости не требует вечного CPU-решателя.
	if persistent and idle > 3.5 and _hulls.is_empty():
		if not _sleeping:
			velocities.fill(Vector2.ZERO)
			_accumulator = 0.0
		_sleeping = true
		return false
	_sleeping = false
	_accumulator = minf(_accumulator + delta, STEP * 2.0)
	if _accumulator < STEP:
		return false
	var hulls: Array = _hulls.values()
	_hulls.clear()
	while _accumulator >= STEP:
		_accumulator -= STEP
		# Два шага интеграции, одна загрузка текстуры. Ограниченный catch-up.
		_integrate(STEP * 0.5, hulls)
		_integrate(STEP * 0.5, hulls)
	_upload()
	return true


func interpolation() -> float:
	if _sleeping:
		return 1.0
	return clampf(_accumulator / STEP, 0.0, 1.0)


func _compute_forces() -> void:
	var count := positions.size()
	densities.fill(1.0)
	forces.fill(Vector2.ZERO)
	_neighbors.clear()
	for i in range(count):
		for j in range(i):
			var offset := positions[i] - positions[j]
			var distance := offset.length()
			# Капиллярное сцепление соседних фрагментов одной плёнки.
			# Оно собирает вытянутые струи обратно в сгустки, не делит их по оси.
			if distance >= KERNEL and distance < 1.8:
				var cohesion := offset / distance * (-10.0 * pow(1.0 - distance / 1.8, 2.0))
				forces[i] += cohesion
				forces[j] -= cohesion
			if distance < KERNEL:
				var q := 1.0 - distance / KERNEL
				densities[i] += q * q
				densities[j] += q * q
				if distance > 0.0001:
					_neighbors.append(Vector4(i, j, offset.x, offset.y))
	# Второй проход только по соседям, а не повторный перебор всех пар.
	for pair in _neighbors:
		var i := int(pair.x)
		var j := int(pair.y)
		var offset := Vector2(pair.z, pair.w)
		var distance := offset.length()
		var q := 1.0 - distance / KERNEL
		# Слабое отрицательное давление у свободной границы стягивает
		# плёнку в округлые сгустки; мягкое ядро не даёт частицам слипнуться.
		var pressure := clampf((densities[i] + densities[j] - 2.0 * REST_DENSITY) * 16.0,
			-8.0, 24.0)
		var repulsion := maxf(SPACING * 0.72 - distance, 0.0) * 180.0
		var force := offset / distance * (pressure * q + repulsion)
		force += (velocities[j] - velocities[i]) * q * 3.0
		forces[i] += force
		forces[j] -= force


func _integrate(dt: float, hulls: Array) -> void:
	_compute_forces()
	var recovery := smoothstep(0.2, 1.2, idle) * 3.2
	for i in range(positions.size()):
		# Художественное возвращение к исходной области после затихания:
		# это сила, а не crossfade двух готовых половин.
		var displacement := positions[i].distance_to(rest_positions[i])
		var activity := smoothstep(0.02, 0.35, displacement)
		# Well-balanced старт: компенсируем собственное давление исходного
		# контура, иначе сцепление округляет пятно ещё до удара носом.
		var force := forces[i] - _rest_forces[i] * (1.0 - activity)
		force += (rest_positions[i] - positions[i]) * recovery
		velocities[i] = ((velocities[i] + force * dt) * exp(-2.4 * dt)).limit_length(2.0)
		positions[i] += velocities[i] * dt
		for hull in hulls:
			_collide(i, hull, dt)
		# Домен закрыт: ни удалений частиц, ни потери массы за границей.
		var bounded := positions[i].limit_length(3.55)
		if bounded != positions[i]:
			positions[i] = bounded
			velocities[i] *= 0.3


func _collide(index: int, hull: Array, dt: float) -> void:
	var direction: Vector2 = hull[2]
	var spine := maxf(float(hull[3]) - float(hull[4]), 0.0)
	var a: Vector2 = hull[0] - direction * spine
	var b: Vector2 = hull[1] + direction * spine
	var ab := b - a
	var at := positions[index]
	var closest := a + ab * clampf((at - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
	var offset := at - closest
	var distance := offset.length()
	var radius: float = hull[4] + 0.14
	if distance < radius + 0.1:
		idle = 0.0
	if distance < radius:
		if radius - distance > 0.02:
			disturbed = true
		var normal := offset / maxf(distance, 0.0001)
		if distance < 0.001:
			normal = Vector2(-direction.y, direction.x) * (-1.0 if index & 1 else 1.0)
		var penetration := radius - distance
		positions[index] += normal * penetration * minf(1.0, dt * 22.0)
		velocities[index] += normal * minf(3.0, penetration * 8.0) * dt * 6.0
		velocities[index] += direction * minf(float(hull[5]), 8.0) * dt * 0.3
	# Пара противовращающихся вихрей за кормой, а не одинаковый сдвиг
	# всей стороны. Деформация зависит от положения каждой частицы.
	var lateral := Vector2(-direction.y, direction.x)
	for side_index in range(2):
		var side: float = -1.0 if side_index == 0 else 1.0
		var center: Vector2 = hull[1] - direction * spine + lateral * radius * side
		var r := positions[index] - center
		var r2 := r.length_squared()
		if r2 < 6.0:
			var curl: Vector2 = Vector2(-r.y, r.x) * side * exp(-r2 * 0.7) / (r2 + 0.4)
			velocities[index] += curl * minf(float(hull[5]), 8.0) * dt * 0.35


func rest_for_relocation() -> void:
	_hulls.clear()
	velocities.fill(Vector2.ZERO)
	_accumulator = 0.0
	idle = 4.0
	_sleeping = true


func _cell(at: Vector2) -> Vector2i:
	var pixel := (at + Vector2.ONE * EXTENT) * (RESOLUTION / (2.0 * EXTENT))
	return Vector2i(clampi(int(pixel.x), 0, RESOLUTION - 1),
		clampi(int(pixel.y), 0, RESOLUTION - 1))


func remove_component_near(point: Vector2) -> float:
	# Компонента видимой плотности, а не произвольные левая/правая доли.
	# Тот же порог, что у film_distance в шейдере. Масса = число частиц,
	# а не площадь на экране, зависящая от ракурса/плотности/сжатия.
	if positions.is_empty():
		return 0.0
	var nearest := 0
	var best := INF
	for i in range(positions.size()):
		var distance := positions[i].distance_squared_to(point)
		if distance < best:
			best = distance
			nearest = i
	var start := _cell(positions[nearest])
	var visited := PackedByteArray()
	visited.resize(RESOLUTION * RESOLUTION)
	var pending: Array[Vector2i] = [start]
	visited[start.y * RESOLUTION + start.x] = 1
	var cursor := 0
	while cursor < pending.size():
		var cell := pending[cursor]
		cursor += 1
		for direction in CELL_NEIGHBORS:
			var neighbor: Vector2i = cell + direction
			if neighbor.x < 0 or neighbor.y < 0 or neighbor.x >= RESOLUTION or neighbor.y >= RESOLUTION:
				continue
			var slot := neighbor.y * RESOLUTION + neighbor.x
			if visited[slot] == 0 and _last_image.get_pixel(neighbor.x, neighbor.y).r >= 0.70:
				visited[slot] = 1
				pending.append(neighbor)
	var remaining_positions := PackedVector2Array()
	var remaining_origins := PackedVector2Array()
	var removed := 0
	for i in range(positions.size()):
		var cell := _cell(positions[i])
		if visited[cell.y * RESOLUTION + cell.x] != 0:
			removed += 1
		else:
			remaining_positions.append(positions[i])
			remaining_origins.append(origins[i])
	var fraction := float(removed) / float(positions.size())
	if removed == 0 or removed == positions.size():
		return fraction
	positions = remaining_positions
	origins = remaining_origins # Сохраняем исходные координаты рисунка.
	rest_positions = positions.duplicate() # Остаток не тянется в исчезнувшую долю.
	velocities.resize(positions.size())
	velocities.fill(Vector2.ZERO)
	densities.resize(positions.size())
	forces.resize(positions.size())
	_compute_forces()
	_rest_forces = forces.duplicate()
	persistent = true
	_sleeping = false
	disturbed = true
	idle = 0.0
	_upload()
	# Не интерполировать через старую текстуру с уже собранной массой.
	previous_texture.update(_last_image)
	return fraction


func _upload() -> void:
	# R — плотность; GB — первые моменты исходных координат пигмента.
	# Деление GB/R в шейдере переносит прежние облака и линзы с веществом.
	var pixels := PackedFloat32Array()
	pixels.resize(RESOLUTION * RESOLUTION * 4)
	pixels.fill(0.0)
	var texel := 2.0 * EXTENT / RESOLUTION
	var radius := 0.43
	for i in range(positions.size()):
		var pixel := (positions[i] + Vector2.ONE * EXTENT) / texel - Vector2.ONE * 0.5
		var reach := int(ceil(radius / texel))
		var cx := int(round(pixel.x))
		var cy := int(round(pixel.y))
		for y in range(maxi(0, cy - reach), mini(RESOLUTION, cy + reach + 1)):
			for x in range(maxi(0, cx - reach), mini(RESOLUTION, cx + reach + 1)):
				var offset := (Vector2(x, y) - pixel) * texel
				var q := maxf(1.0 - offset.length_squared() / (radius * radius), 0.0)
				var weight := q * q * q
				var slot := (y * RESOLUTION + x) * 4
				pixels[slot] += weight
				pixels[slot + 1] += weight * origins[i].x
				pixels[slot + 2] += weight * origins[i].y
	var image := Image.create_from_data(RESOLUTION, RESOLUTION, false, Image.FORMAT_RGBAF,
		pixels.to_byte_array())
	if texture == null:
		texture = ImageTexture.create_from_image(image)
		previous_texture = ImageTexture.create_from_image(image)
	else:
		previous_texture.update(_last_image)
		texture.update(image)
	_last_image = image
