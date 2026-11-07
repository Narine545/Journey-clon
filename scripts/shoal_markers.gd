class_name ShoalMarkers
extends Node3D
## Sparse marks on the REAL sampled depth contour, not a fixed shore offset.
const DEPTH := 3.8
const GRID := 12.0
const MAX_MARKERS := 20
const IDLE := Color("f3cf84")
const ALERT := Color("ff453d")
var main: BoatMain
var positions: Array[Vector2] = []
var warning := false
var predicted_depth := 100.0
var _danger_point := Vector2.ZERO
var _parts: Array[MultiMeshInstance3D] = []
var _offsets: Array[float] = []
var _lenses: MultiMeshInstance3D
var _colors: Array[Color] = []
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
	var count := mini(MAX_MARKERS, maxi(14, int(round(length / 85.0))))
	var segment := 1
	var traversed := 0.0
	for i in range(count):
		var target := length * (float(i) + 0.37) / float(count)
		while segment < path.size() - 1 and traversed + path[segment - 1].distance_to(path[segment]) < target:
			traversed += path[segment - 1].distance_to(path[segment])
			segment += 1
		var span := path[segment - 1].distance_to(path[segment])
		var p := _snap_depth(path[segment - 1].lerp(path[segment], (target - traversed) / maxf(span, 0.001)))
		var clear := absf(main.coast.water_depth(p.x, p.y) - DEPTH) < 0.15
		for beacon in main.beacons:
			var bp: Vector3 = beacon["buoy_pos"]
			if p.distance_to(Vector2(bp.x, bp.z)) < 30.0:
				clear = false
		for rf in main.reefs:
			var rp: Vector2 = rf["pos"]
			if p.distance_to(rp) < 14.0:
				clear = false
		for other in positions:
			if p.distance_to(other) < 36.0:
				clear = false
		# No extra mark inside the docking slip or next to red/green lateral marks.
		if p.distance_to(IslandLayout.BERTH) < 23.0 or p.distance_to(Vector2(-62, -55)) < 22.0 or p.distance_to(Vector2(-62, -5)) < 22.0:
			clear = false
		if clear:
			positions.append(p)
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
	shader.code = "shader_type spatial; render_mode unshaded; void fragment(){ ALBEDO=COLOR.rgb; EMISSION=COLOR.rgb*0.55; }"
	material.shader = shader
	_lenses = _add_part(lens, material, 2.12, true)
	for i in range(positions.size()):
		_colors.append(IDLE)


func _add_part(mesh: Mesh, material: Material, y: float, colors: bool = false) -> MultiMeshInstance3D:
	var node := MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = colors
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
	var boat_at := Vector2(main.boat.global_position.x, main.boat.global_position.z)
	for i in range(positions.size()):
		var p := positions[i]
		var danger := warning and p.distance_to(_danger_point) < 68.0 and p.distance_to(boat_at) < 85.0
		_colors[i] = _colors[i].lerp(ALERT if danger else IDLE, 1.0 - exp(-delta * 6.0))
		_lenses.multimesh.set_instance_color(i, _colors[i])
		var y := main.water.surface_height(p.x, p.y)
		for j in range(_parts.size()):
			_parts[j].multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY, Vector3(p.x, y + _offsets[j], p.y)))
