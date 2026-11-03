class_name BoatVessel
extends Node3D
## Лодка с мотором и насосом: управляемая инерция и качка на WaterField.
## Корпус и каюта пока наружные; интерьер и прицеп — следующие этапы.

const MAX_SPEED := 10.0
const REVERSE_SPEED := 4.0
const ACCELERATION := 3.2
const DRAG := 1.8
const TURN_RATE := 0.95
const PUMP_RANGE := 6.0
const PUMP_SECONDS := 1.4

var main: BoatMain
var water: WaterSurface
var coast: Coast
var speed := 0.0
var _wake_timer := 0.0
var _pump_progress := 0.0
var _target: ResourceSlick
var _body: Node3D
var _hose: MeshInstance3D
var _nozzle := Vector3(-1.65, 0.05, 0.3)


func setup(boat_main: BoatMain, water_ref: WaterSurface, coast_ref: Coast) -> void:
	main = boat_main
	water = water_ref
	coast = coast_ref
	_body = Node3D.new()
	_body.name = "HullAndCabin"
	add_child(_body)
	_build_appearance()


func _physics_process(delta: float) -> void:
	if water == null or coast == null:
		return
	var throttle := Input.get_axis("boat_reverse", "boat_forward")
	var steer := Input.get_axis("boat_left", "boat_right")
	var target_speed := throttle * (MAX_SPEED if throttle >= 0.0 else REVERSE_SPEED)
	speed = move_toward(speed, target_speed, (ACCELERATION if absf(throttle) > 0.01 else DRAG) * delta)
	# Направление поворота зависит от движения: задним ходом руль инвертируется.
	rotation.y += steer * TURN_RATE * delta * clampf(absf(speed) / 3.5, 0.0, 1.0) * (1.0 if speed >= 0.0 else -1.0)
	var heading := -global_transform.basis.z
	var next := global_position + heading * speed * delta
	if coast.water_depth(next.x, next.z) > 1.7:
		global_position = next
	else:
		speed = minf(speed, 0.0) # берег — преграда, а не невидимая телепортация
	var surface := water.surface_height(global_position.x, global_position.z)
	global_position.y = lerpf(global_position.y, surface + 0.10, minf(1.0, delta * 3.0))
	var bow := global_position + heading * 2.8
	var stern := global_position - heading * 2.8
	var right := global_transform.basis.x
	var port := global_position - right * 1.3
	var starboard := global_position + right * 1.3
	var pitch := atan2(water.surface_height(bow.x, bow.z) - water.surface_height(stern.x, stern.z), 5.6)
	var roll := atan2(water.surface_height(starboard.x, starboard.z) - water.surface_height(port.x, port.z), 2.6)
	_body.rotation.x = lerpf(_body.rotation.x, pitch, minf(1.0, delta * 3.0))
	_body.rotation.z = lerpf(_body.rotation.z, roll - steer * absf(speed) * 0.004, minf(1.0, delta * 3.0))
	_wake_timer -= delta
	if absf(speed) > 1.2 and _wake_timer <= 0.0:
		_wake_timer = 0.33
		var tail := global_position - heading * 3.0
		water.field.wake(Vector2(tail.x, tail.z), clampf(absf(speed) / 6.0, 0.2, 1.5))
	_update_pump(delta)


func _update_pump(delta: float) -> void:
	_target = main.nearest_resource(global_position, PUMP_RANGE)
	var drawing := Input.is_action_pressed("boat_pump") and _target != null and absf(speed) < 5.0
	if drawing:
		_pump_progress += delta
		var from := _body.to_global(_nozzle)
		var to := _target.global_position + Vector3.UP * 0.12
		_hose.visible = true
		_hose.global_position = (from + to) * 0.5
		_hose.global_basis = Basis(Quaternion(Vector3.UP, (to - from).normalized()))
		_hose.scale.y = from.distance_to(to)
		if _pump_progress >= PUMP_SECONDS:
			main.receive_resource(_target.kind)
			_target.collect()
			_pump_progress = 0.0
	else:
		_pump_progress = maxf(0.0, _pump_progress - delta * 2.0)
		_hose.visible = false


func pump_fraction() -> float:
	return clampf(_pump_progress / PUMP_SECONDS, 0.0, 1.0)


func target_name() -> String:
	return ResourceSlick.NAMES[_target.kind] if _target != null else ""


func _material(color: Color, metal := 0.0, glow := 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = metal
	mat.roughness = 0.58
	if glow > 0.0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = glow
	return mat


func _box(at: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	part.mesh = box
	part.position = at
	part.material_override = mat
	_body.add_child(part)
	return part


func _triangle(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	tool.add_vertex(a)
	tool.add_vertex(b)
	tool.add_vertex(c)


func _build_appearance() -> void:
	# Палитра: графитовый корпус, глубокий петроль, меловая каюта,
	# медная механика и четыре чистых акцентных цвета собранных ресурсов.
	var hull := _material(Color("203343"), 0.36)
	var hull_edge := _material(Color("315968"), 0.30)
	var cabin := _material(Color("eee5d1"), 0.07)
	var roof := _material(Color("318982"), 0.30)
	var glass := _material(Color("244956"), 0.20)
	var copper := _material(Color("d48d60"), 0.65)
	var dark := _material(Color("142833"), 0.55)
	_box(Vector3(0, -0.42, 0), Vector3(3.0, 0.85, 7.1), hull)
	_box(Vector3(0, 0.04, 0), Vector3(3.18, 0.14, 6.85), hull_edge)
	# Нос треугольный В ГОРИЗОНТАЛЬНОЙ плоскости. Готовый PrismMesh
	# после поворота давал вертикальный чёрный «парус» вместо носа.
	var prow := MeshInstance3D.new()
	var triangles := SurfaceTool.new()
	triangles.begin(Mesh.PRIMITIVE_TRIANGLES)
	var lp := Vector3(-1.5, 0.02, -3.25)
	var rp := Vector3(1.5, 0.02, -3.25)
	var tip := Vector3(0.0, 0.02, -5.0)
	var lp_low := lp + Vector3.DOWN * 0.75
	var rp_low := rp + Vector3.DOWN * 0.75
	var tip_low := tip + Vector3.DOWN * 0.75
	_triangle(triangles, lp, rp, tip) # палуба
	_triangle(triangles, lp_low, tip_low, rp_low) # днище
	_triangle(triangles, lp, tip, tip_low)
	_triangle(triangles, lp, tip_low, lp_low)
	_triangle(triangles, rp, rp_low, tip_low)
	_triangle(triangles, rp, tip_low, tip)
	triangles.generate_normals()
	prow.mesh = triangles.commit()
	prow.material_override = hull
	_body.add_child(prow)
	_box(Vector3(0, 0.13, -0.4), Vector3(2.83, 0.09, 5.9), _material(Color("8d7762")))
	# Каюта ближе к корме; окна визуально доступны при изометрическом взгляде.
	_box(Vector3(0, 0.90, 0.65), Vector3(2.35, 1.55, 2.75), cabin)
	_box(Vector3(0, 1.76, 0.65), Vector3(2.65, 0.23, 3.02), roof)
	_box(Vector3(0, 1.17, -0.76), Vector3(1.72, 0.73, 0.055), glass)
	for side in [-1.0, 1.0]:
		_box(Vector3(side * 1.19, 1.17, 0.56), Vector3(0.065, 0.68, 1.72), glass)
		_box(Vector3(side * 1.34, 0.23, -2.16), Vector3(0.055, 0.23, 2.4), copper)
		_box(Vector3(side * 1.34, 0.23, 2.45), Vector3(0.055, 0.23, 1.15), copper)
	_box(Vector3(0, 0.36, 3.30), Vector3(2.20, 0.6, 0.83), dark) # моторный кожух
	_box(Vector3(0, 0.62, 3.18), Vector3(0.38, 0.28, 0.52), copper)
	_box(Vector3(-1.53, 0.25, 0.30), Vector3(0.30, 0.62, 0.62), copper) # насос
	_box(Vector3(-1.79, 0.0, 0.30), Vector3(0.32, 0.11, 0.11), dark)
	var lantern := OmniLight3D.new()
	lantern.light_color = Color("ffc993")
	lantern.light_energy = 0.7
	lantern.omni_range = 7.0
	lantern.position = Vector3(0, 2.02, 0.66)
	_body.add_child(lantern)
	_hose = MeshInstance3D.new()
	var tube := CylinderMesh.new()
	tube.top_radius = 0.052
	tube.bottom_radius = 0.095
	tube.height = 1.0
	_hose.mesh = tube
	_hose.material_override = _material(Color("7ee1c9"), 0.08, 0.9)
	_hose.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_hose.visible = false
	add_child(_hose)
