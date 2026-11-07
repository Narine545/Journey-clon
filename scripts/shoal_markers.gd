class_name ShoalMarkers
extends Node3D
## Sparse marks on the REAL sampled depth contour, not a fixed shore offset.
const DEPTH := 2.25
const GRID := 12.0
const MAX_MARKERS := 18
const SECTORS := 12
const IDLE := Color("06f51b")
const ALERT := Color("ff1008")
var main: BoatMain
var positions: Array[Vector2] = []
var shelf_widths: Array[float] = []
var warning := false
var predicted_depth := 100.0
var _danger_point := Vector2.ZERO
var _parts: Array[MultiMeshInstance3D] = []
var _offsets: Array[float] = []
var _glows: MultiMeshInstance3D
var _lenses: MultiMeshInstance3D
var _colors: Array[Color] = []
var _float_ids: Array[int] = []
var _near: Array[bool] = []
var _timer := 0.0
var _time := 0.0


func _key(p: Vector2) -> Vector2i:
	return Vector2i(roundi(p.x * 100.0), roundi(p.y * 100.0))


func _contour() -> Array[Vector2]:
	var origin := Coast.CENTER - Vector2.ONE * Coast.SIZE * 0.5
	var n := int(ceil(Coast.SIZE / GRID))
	var values := PackedFloat32Array()
	values.resize((n + 1) * (n + 1))
	for j in range(n + 1):
		for i in range(n + 1):
			var p := origin + Vector2(float(i), float(j)) * GRID
			values[j * (n + 1) + i] = main.coast.water_depth(p.x, p.y) - DEPTH
	var links: Dictionary = {}
	var coordinates: Dictionary = {}
	for j in range(n):
		for i in range(n):
			var base := origin + Vector2(float(i), float(j)) * GRID
			var corners: Array[Vector2] = [base, base + Vector2(GRID, 0), base + Vector2(GRID, GRID), base + Vector2(0, GRID)]
			var v: Array[float] = [values[j * (n + 1) + i], values[j * (n + 1) + i + 1],
				values[(j + 1) * (n + 1) + i + 1], values[(j + 1) * (n + 1) + i]]
			var crossings: Array[Vector2] = []
			for edge in range(4):
				var next := (edge + 1) % 4
				if (v[edge] > 0.0) != (v[next] > 0.0):
					crossings.append(corners[edge].lerp(corners[next], v[edge] / (v[edge] - v[next])))
			if crossings.size() == 2:
				_link(links, coordinates, crossings[0], crossings[1])
			elif crossings.size() == 4:
				var center := base + Vector2.ONE * GRID * 0.5
				var same := (main.coast.water_depth(center.x, center.y) > DEPTH) == (v[0] > 0.0)
				if same:
					_link(links, coordinates, crossings[0], crossings[1])
					_link(links, coordinates, crossings[2], crossings[3])
				else:
					_link(links, coordinates, crossings[0], crossings[3])
					_link(links, coordinates, crossings[1], crossings[2])
	var visited: Dictionary = {}
	var longest: Array[Vector2] = []
	var longest_length := 0.0
	for start in links:
		if visited.has(start):
			continue
		var path: Array[Vector2] = []
		var current: Vector2i = start
		var previous := Vector2i(999999, 999999)
		var closed := false
		for step in range(links.size() + 1):
			visited[current] = true
			path.append(coordinates[current])
			var adjacent: Array = links[current]
			if adjacent.size() != 2:
				break
			var next: Vector2i = adjacent[0] if adjacent[0] != previous else adjacent[1]
			previous = current
			current = next
			if current == start:
				path.append(coordinates[start])
				closed = true
				break
		var length := 0.0
		for k in range(1, path.size()):
			length += path[k].distance_to(path[k - 1])
		if closed and length > longest_length:
			longest = path
			longest_length = length
	return longest


func _link(links: Dictionary, coords: Dictionary, a: Vector2, b: Vector2) -> void:
	var ka := _key(a)
	var kb := _key(b)
	if ka == kb:
		return
	coords[ka] = a
	coords[kb] = b
	var aa: Array = links.get(ka, [])
	var bb: Array = links.get(kb, [])
	aa.append(kb)
	bb.append(ka)
	links[ka] = aa
	links[kb] = bb


func _snap_depth(p: Vector2) -> Vector2:
	for i in range(5):
		var gradient := Vector2(main.coast.water_depth(p.x + 0.5, p.y) - main.coast.water_depth(p.x - 0.5, p.y),
			main.coast.water_depth(p.x, p.y + 0.5) - main.coast.water_depth(p.x, p.y - 0.5))
		if gradient.length_squared() < 0.0001:
			break
		var error := main.coast.water_depth(p.x, p.y) - DEPTH
		p -= gradient.normalized() * clampf(error / gradient.length(), -4.0, 4.0)
	return p


func _clear_mark(p: Vector2) -> bool:
	if absf(main.coast.water_depth(p.x, p.y) - DEPTH) > 0.15:
		return false
	for beacon in main.beacons:
		var bp: Vector3 = beacon["buoy_pos"]
		if p.distance_to(Vector2(bp.x, bp.z)) < 16.0:
			return false
	for rf in main.reefs:
		var rp: Vector2 = rf["pos"]
		if p.distance_to(rp) < 14.0:
			return false
	return p.distance_to(IslandLayout.BERTH) >= 23.0 \
		and p.distance_to(Vector2(-62, -55)) >= 18.0 and p.distance_to(Vector2(-62, -5)) >= 18.0


func _shelf_profile(p: Vector2) -> Dictionary:
	# Actual nearest dry ground + shallow area, not distance to an elliptical island.
	var nearest := INF
	var dry := p
	var area := 0.0
	for ix in range(-6, 7):
		for iz in range(-6, 7):
			var offset := Vector2(float(ix), float(iz)) * 8.0
			if offset.length_squared() > 48.0 * 48.0:
				continue
			var q := p + offset
			var d := main.coast.water_depth(q.x, q.y)
			if d <= 0.15 and offset.length() < nearest:
				nearest = offset.length()
				dry = q
			elif d > 0.15 and d <= 2.6:
				area += 64.0
	var width := 48.0
	if is_finite(nearest):
		var lo := 0.0
		var hi := 1.0
		for _iteration in range(12):
			var mid := (lo + hi) * 0.5
			var q := p.lerp(dry, mid)
			if main.coast.water_depth(q.x, q.y) <= 0.15:
				hi = mid
			else:
				lo = mid
		width = nearest * (lo + hi) * 0.5
	return {"width": width, "area": area, "score": width + area * 0.003}


func _higher_score(a: Dictionary, b: Dictionary) -> bool:
	return float(a["score"]) > float(b["score"])


func _accept_mark(candidate: Dictionary, separation: float) -> bool:
	var p: Vector2 = candidate["at"]
	for other in positions:
		if p.distance_to(other) < separation:
			return false
	positions.append(p)
	shelf_widths.append(float(candidate["width"]))
	return true


func setup(game: BoatMain) -> void:
	main = game
	name = "ShoalContourMarks"
	var path := _contour()
	if path.size() < 3:
		push_warning("Shoal depth contour could not be traced")
		return
	var length := 0.0
	for i in range(1, path.size()):
		length += path[i - 1].distance_to(path[i])
	# Dense candidates first. Prefer wide banks in each coastal sector, then
	# use the remaining budget on the largest banks, not equal arc spacing.
	var count := maxi(72, int(ceil(length / 18.0)))
	var candidates: Array[Dictionary] = []
	var segment := 1
	var traversed := 0.0
	for i in range(count):
		var target := length * (float(i) + 0.37) / float(count)
		while segment < path.size() - 1 and traversed + path[segment - 1].distance_to(path[segment]) < target:
			traversed += path[segment - 1].distance_to(path[segment])
			segment += 1
		var span := path[segment - 1].distance_to(path[segment])
		var p := _snap_depth(path[segment - 1].lerp(path[segment], (target - traversed) / maxf(span, 0.001)))
		if not _clear_mark(p):
			continue
		var profile := _shelf_profile(p)
		profile["at"] = p
		profile["sector"] = mini(SECTORS - 1, int(float(i) * float(SECTORS) / float(count)))
		candidates.append(profile)
	candidates.sort_custom(_higher_score)
	for sector in range(SECTORS):
		for candidate in candidates:
			if int(candidate["sector"]) == sector and _accept_mark(candidate, 55.0):
				break
	if not candidates.is_empty():
		var median_index := int(float(candidates.size()) * 0.5)
		var median_score: float = candidates[median_index]["score"]
		for candidate in candidates:
			if positions.size() >= MAX_MARKERS:
				break
			if float(candidate["score"]) >= median_score * 1.12:
				_accept_mark(candidate, 72.0)
	var body := CylinderMesh.new()
	body.top_radius = 0.28
	body.bottom_radius = 0.60
	body.height = 0.9
	var belt := CylinderMesh.new()
	belt.top_radius = 0.46
	belt.bottom_radius = 0.54
	belt.height = 0.19
	var pole := CylinderMesh.new()
	pole.top_radius = 0.055
	pole.bottom_radius = 0.075
	pole.height = 1.4
	for mesh in [body, belt, pole]:
		mesh.radial_segments = 10
	_add_part(body, main._mat(Color("d2b66c"), 0.12, 0.0, 0.82), 0.3)
	_add_part(belt, main._mat(Color("333e3c"), 0.12, 0.0, 0.85), 0.33)
	_add_part(pole, main._mat(Color("bac2b6"), 0.1, 0.0, 0.75), 1.3)
	var lens := SphereMesh.new()
	lens.radius = 0.2
	lens.height = 0.4
	lens.radial_segments = 10
	lens.rings = 6
	var material := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = "shader_type spatial; render_mode unshaded; varying float flash; void vertex(){ flash=INSTANCE_CUSTOM.r; } void fragment(){ ALBEDO=COLOR.rgb*0.12; EMISSION=COLOR.rgb*mix(0.12,5.5,flash); }"
	material.shader = shader
	_lenses = _add_part(lens, material, 2.12, true)
	var halo := QuadMesh.new()
	halo.size = Vector2(1.1, 1.1)
	var glow_material := ShaderMaterial.new()
	glow_material.shader = preload("res://shaders/buoy_glare.gdshader")
	glow_material.set_shader_parameter("instanced_mode", true)
	_glows = _add_part(halo, glow_material, 2.12, true)
	_glows.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for i in range(positions.size()):
		_colors.append(IDLE)
		_near.append(false)
		_float_ids.append(main.buoy_dynamics.register(positions[i], 0.75))


func _add_part(mesh: Mesh, material: Material, y: float, colors: bool = false) -> MultiMeshInstance3D:
	var node := MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	node.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	mm.use_colors = colors
	mm.use_custom_data = colors
	mm.mesh = mesh
	mm.instance_count = positions.size()
	node.multimesh = mm
	node.material_override = material
	add_child(node)
	_parts.append(node)
	_offsets.append(y)
	return node


func _probe(at: Vector2) -> void:
	var d := main.coast.water_depth(at.x, at.y)
	if d < predicted_depth:
		predicted_depth = d
		_danger_point = at


func _footprint(at: Vector2, heading: Vector2, half: float, width: float) -> void:
	var side := Vector2(-heading.y, heading.x)
	for i in range(3):
		for j in range(3):
			_probe(at + heading * float(i - 1) * half + side * float(j - 1) * width)


func _check_course() -> void:
	predicted_depth = 100.0
	var boat := main.boat
	var at := Vector2(boat.global_position.x, boat.global_position.z)
	var forward := Vector2(-sin(boat.rotation.y), -cos(boat.rotation.y))
	var travel := forward * clampf(boat.speed * 2.4, -12.0, 28.0)
	for i in range(3):
		_footprint(at + travel * float(i) * 0.5, forward, 4.4, 1.6)
	if boat.has_trailer and boat._trailer != null:
		var trailer := boat._trailer
		var ta := Vector2(trailer.global_position.x, trailer.global_position.z)
		var th := Vector2(-sin(trailer.rotation.y), -cos(trailer.rotation.y))
		_footprint(ta, th, 2.8, 1.5)
		_footprint(ta + travel, th, 2.8, 1.5)
	warning = predicted_depth < (3.4 if warning else 2.8)
	if main.harbor != null and main.harbor.moored:
		warning = false


## Two distinct, short flashes per second, with a dim interval instead of a
## washed-out sinusoid. Custom data stays in [0,1]; HDR gain lives in shader.
static func flash_strength(time: float, phase: float = 0.0) -> float:
	var t := fposmod(time + phase, 1.05)
	var first := smoothstep(0.0, 0.025, t) * (1.0 - smoothstep(0.12, 0.18, t))
	var second := smoothstep(0.26, 0.285, t) * (1.0 - smoothstep(0.38, 0.44, t))
	return maxf(first, second)


func _process(delta: float) -> void:
	if main == null:
		return
	_time += delta
	_timer -= delta
	if _timer <= 0.0:
		_timer = 0.15
		_check_course()
	if _lenses == null:
		return
	var boat := main.boat
	var boat_at := Vector2(boat.global_position.x, boat.global_position.z)
	for i in range(positions.size()):
		var id := _float_ids[i]
		var distance := main.buoy_dynamics.hull_distance(id, boat_at, boat.rotation.y, 3.7, 1.7)
		if boat.has_trailer and boat._trailer != null:
			var trailer := boat._trailer
			var trailer_at := Vector2(trailer.global_position.x, trailer.global_position.z)
			distance = minf(distance, main.buoy_dynamics.hull_distance(id, trailer_at, trailer.rotation.y, 1.6, 1.5))
		_near[i] = distance < (15.0 if _near[i] else 13.0)
		_colors[i] = _colors[i].lerp(ALERT if _near[i] else IDLE, 1.0 - exp(-delta * 10.0))
		var flash := Color(flash_strength(_time, float(i) * 0.17), 0.0, 0.0, 1.0)
		_lenses.multimesh.set_instance_color(i, _colors[i])
		_lenses.multimesh.set_instance_custom_data(i, flash)
		_glows.multimesh.set_instance_color(i, _colors[i])
		_glows.multimesh.set_instance_custom_data(i, flash)
		var pose := main.buoy_dynamics.render_pose(id)
		for j in range(_parts.size()):
			var part_pose := pose
			part_pose.origin += pose.basis * Vector3(0.0, _offsets[j], 0.0)
			_parts[j].multimesh.set_instance_transform(i, part_pose)
