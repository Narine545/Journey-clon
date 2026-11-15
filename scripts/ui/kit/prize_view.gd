class_name TidePrizeView
extends Control
## Окно с трёхмерной находкой: модель медленно вращается в собственном мире,
## фон прозрачный — под ней обычная бумага интерфейса.

var _viewport: SubViewport
var _pivot: Node3D
var _time := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var frame := SubViewportContainer.new()
	frame.stretch = true
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(frame)
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.transparent_bg = true
	_viewport.msaa_3d = Viewport.MSAA_4X
	_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	frame.add_child(_viewport)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0, 0, 0, 0)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("efead8")
	environment.ambient_light_energy = 0.9
	var world := WorldEnvironment.new()
	world.environment = environment
	_viewport.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42.0, 36.0, 0.0)
	sun.light_energy = 1.6
	_viewport.add_child(sun)
	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 1.5, 4.0)
	camera.fov = 38.0
	_viewport.add_child(camera)
	camera.look_at_from_position(camera.position, Vector3.ZERO, Vector3.UP)
	_pivot = Node3D.new()
	_viewport.add_child(_pivot)
	show_item(-1)


## Показать одну вещь коллекции; -1 — вся коллекция (или заглушка).
func show_item(index: int) -> void:
	for child in _pivot.get_children():
		child.queue_free()
	if index < 0:
		_pivot.add_child(ArtifactModel.build(ArtifactModel.PRIZE, 2.3))
	else:
		_pivot.add_child(ArtifactModel.build_item(index, 2.1))


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_time += delta
	_pivot.rotation.y = _time * 0.7
	_pivot.position.y = 0.08 * sin(_time * 1.6)
