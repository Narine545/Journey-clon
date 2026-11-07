class_name WorldInspector
extends Control
## Карта и инструменты локализации дефектов. Не телепортируют судно и
## по умолчанию НЕ меняют атмосферу: дефект нужно видеть в исходном режиме.
const VERSION := "world-inspector-1"
const MAP_RESOLUTION := 192
const MAX_MARKERS := 32
const DEFAULT_PITCH := 0.621
const DEFAULT_YAW := 0.611

var main: BoatMain
var map_open := false
var free_camera := false
var clear_view := false
var markers: Array[Vector3] = []
var selected := -1
var _map_span := Coast.SIZE * 2.0
var _map_center := Coast.CENTER
var _map_texture: ImageTexture
var _focus := Vector3.ZERO
var _yaw := DEFAULT_YAW
var _pitch := DEFAULT_PITCH
var _entry_distance := 45.02
var _saved_size := 32.0
var _saved_far := 1500.0
var _saved_projection := Camera3D.PROJECTION_ORTHOGONAL
var _saved_fog := true
var _saved_volume := true
var _capture_busy := false


func setup(scene: BoatMain) -> void:
	main = scene
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF


func is_active() -> bool:
	return map_open or free_camera


static func map_bounds() -> Rect2:
	return Rect2(Coast.CENTER - Vector2.ONE * Coast.SIZE * 0.5, Vector2.ONE * Coast.SIZE)


func _map_rect() -> Rect2:
	var side := maxf(160.0, minf(size.y - 158.0, size.x * 0.62 - 56.0))
	return Rect2(Vector2(28.0, 92.0), Vector2.ONE * side)


static func world_to_map(point: Vector2, rect: Rect2, span: float = Coast.SIZE, center: Vector2 = Coast.CENTER) -> Vector2:
	var origin := center - Vector2.ONE * span * 0.5
	return rect.position + (point - origin) / span * rect.size


static func map_to_world(point: Vector2, rect: Rect2, span: float = Coast.SIZE, center: Vector2 = Coast.CENTER) -> Vector2:
	var origin := center - Vector2.ONE * span * 0.5
	return origin + (point - rect.position) / rect.size * span


func _build_map() -> void:
	if _map_texture != null:
		return
	var image := Image.create(MAP_RESOLUTION, MAP_RESOLUTION, false, Image.FORMAT_RGB8)
	var bounds := map_bounds()
	for y in range(MAP_RESOLUTION):
		for x in range(MAP_RESOLUTION):
			var at := bounds.position + Vector2(x + 0.5, y + 0.5) / MAP_RESOLUTION * Coast.SIZE
			# Именно конечная сетка с переходом краёв, не бесконечный height_at.
			var height := main.coast.sample_height(at.x, at.y)
			var color: Color
			if height < 0.0:
				color = Color("17434f").lerp(Color("398d90"), exp(height * 0.12))
			else:
				color = Color("ceb58a").lerp(Color("6c7855"), clampf(height / 35.0, 0.0, 1.0))
			image.set_pixel(x, y, color)
	_map_texture = ImageTexture.create_from_image(image)


func set_free_camera(enabled: bool) -> void:
	if enabled == free_camera:
		return
	if enabled:
		_saved_size = main.camera.size
		_saved_far = main.camera.far
		_saved_projection = main.camera.projection
		_focus = main._camera_focus
		var offset := main.camera.global_position - _focus
		_entry_distance = offset.length()
		_yaw = atan2(offset.x, offset.z)
		_pitch = atan2(offset.y, Vector2(offset.x, offset.z).length())
		main.camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		main.camera.far = 8000.0
		main.boat.speed = 0.0
	else:
		set_clear_view(false)
		main.camera.projection = _saved_projection
		main.camera.size = _saved_size
		main.camera.far = _saved_far
		main._camera_focus = main.boat.get_global_transform_interpolated().origin + Vector3.UP * 0.8
	free_camera = enabled
	map_open = false
	queue_redraw()


func set_clear_view(enabled: bool) -> void:
	if enabled == clear_view:
		return
	if enabled:
		_saved_fog = main.world._env.fog_enabled
		_saved_volume = main.world._env.volumetric_fog_enabled
	else:
		main.world._env.fog_enabled = _saved_fog
		main.world._env.volumetric_fog_enabled = _saved_volume
	clear_view = enabled
	main._apply_atmosphere(main.night01)


func apply_view_override() -> void:
	if not clear_view:
		return
	main.world._env.fog_enabled = false
	main.world._env.volumetric_fog_enabled = false
	main.water.set_param("fog_distance", 100000.0)
	main.coast.set_sand("fog_distance", 100000.0)


func overview() -> void:
	set_free_camera(true)
	map_open = false
	_focus = Vector3(Coast.CENTER.x, 0.0, Coast.CENTER.y)
	_pitch = 1.48
	_yaw = 0.0
	var aspect := size.x / maxf(size.y, 1.0)
	main.camera.size = minf(1800.0, Coast.SIZE * 1.15 * maxf(1.0, 1.0 / aspect))
	set_clear_view(true)
	update_camera(0.0)


func _focus_marker() -> void:
	if selected < 0:
		return
	set_free_camera(true)
	set_clear_view(false)
	_focus = markers[selected]
	_pitch = DEFAULT_PITCH
	_yaw = DEFAULT_YAW
	main.camera.size = 32.0
	map_open = false
	update_camera(0.0)


func update_camera(delta: float) -> void:
	if not free_camera or map_open:
		return
	var camera := main.camera
	var right := camera.global_basis.x
	right.y = 0.0
	right = right.normalized()
	var forward := -camera.global_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var horizontal := _axis(_down(KEY_D) or _down(KEY_RIGHT), _down(KEY_A) or _down(KEY_LEFT))
	var longitudinal := _axis(_down(KEY_W) or _down(KEY_UP), _down(KEY_S) or _down(KEY_DOWN))
	var vertical := _axis(_down(KEY_E), _down(KEY_Q))
	var movement := right * horizontal + forward * longitudinal + Vector3.UP * vertical
	if _down(KEY_CTRL):
		movement = Vector3.ZERO
	var speed := maxf(20.0, camera.size * 0.8) * (4.0 if _down(KEY_SHIFT) else 1.0)
	_focus += movement.limit_length(1.0) * speed * delta
	_focus.x = clampf(_focus.x, -2200.0, 2200.0)
	_focus.z = clampf(_focus.z, -2200.0, 2200.0)
	_focus.y = clampf(_focus.y, -20.0, 400.0)
	var distance := maxf(_entry_distance, camera.size * 0.9)
	var direction := Vector3(sin(_yaw) * cos(_pitch), sin(_pitch), cos(_yaw) * cos(_pitch))
	camera.global_position = _focus + direction * distance
	camera.look_at(_focus, Vector3.UP)


static func _axis(positive: bool, negative: bool) -> float:
	return (1.0 if positive else 0.0) - (1.0 if negative else 0.0)


static func _down(key: Key) -> bool:
	return Input.is_physical_key_pressed(key)


func surface_point(x: float, z: float) -> Vector3:
	return Vector3(x, maxf(Coast.SEA_LEVEL, main.coast.ground_height(x, z)), z)


func pick_surface(screen: Vector2) -> Dictionary:
	# CPU heightfield + уровень моря. Не попадание в корпуса, рифы или
	# прозрачные эффекты; именно стабильная координата под дефектом.
	var origin := main.camera.project_ray_origin(screen)
	var ray := main.camera.project_ray_normal(screen).normalized()
	if ray.y >= -0.00001:
		return {}
	if origin.y <= surface_point(origin.x, origin.z).y:
		return {}
	var end := minf(main.camera.far, maxf(0.0, (origin.y - Coast.SEA_LEVEL) / -ray.y) + 250.0)
	var previous := 0.0
	for step in range(1, 321):
		var t := end * float(step) / 320.0
		var at := origin + ray * t
		var height := surface_point(at.x, at.z).y
		if at.y <= height:
			var lo := previous
			var hi := t
			for iteration in range(20):
				var middle := (lo + hi) * 0.5
				var sample := origin + ray * middle
				if sample.y > surface_point(sample.x, sample.z).y:
					lo = middle
				else:
					hi = middle
			var hit := origin + ray * ((lo + hi) * 0.5)
			return {"point": surface_point(hit.x, hit.z)}
		previous = t
	return {}


func add_marker(point: Vector3) -> void:
	if markers.size() >= MAX_MARKERS:
		markers.pop_front()
	markers.append(point)
	selected = markers.size() - 1
	print("[WORLD MARKER] ", marker_text())
	queue_redraw()


func marker_text() -> String:
	if selected < 0:
		return "Метка не выбрана — ЛКМ на карте или в свободной камере"
	var point := markers[selected]
	return "#%d  X=%.2f  Y=%.2f  Z=%.2f" % [selected + 1, point.x, point.y, point.z]


static func _v3(value: Vector3) -> Array[float]:
	return [value.x, value.y, value.z]


func make_report() -> Dictionary:
	var camera := main.camera
	var report := {
		"inspector": VERSION,
		"timestamp": Time.get_datetime_string_from_system(),
		"engine": Engine.get_version_info(),
		"renderer_setting": ProjectSettings.get_setting("rendering/renderer/rendering_method"),
		"render_device": RenderingServer.get_rendering_device() != null,
		"compat_fallback": main.world.compat_fallback,
		"fps_sample": Engine.get_frames_per_second(),
		"gpu": RenderingServer.get_video_adapter_name(),
		"platform": OS.get_name(),
		"viewport": [int(size.x), int(size.y)],
		"map_span": _map_span,
		"map_center_xz": [_map_center.x, _map_center.y],
		"marker_index": selected + 1,
		"point": _v3(markers[selected]) if selected >= 0 else null,
		"camera_position": _v3(camera.global_position),
		"camera_rotation_degrees": _v3(camera.global_rotation * (180.0 / PI)),
		"camera_size": camera.size,
		"camera_projection": camera.projection,
		"camera_near": camera.near,
		"camera_far": camera.far,
		"free_camera": free_camera,
		"overview_without_fog": clear_view,
		"boat_position": _v3(main.boat.global_position),
		"boat_yaw_degrees": rad_to_deg(main.boat.rotation.y),
		"night01": main.night01,
		"weather": main.weather.label(),
		"weather_fog": main.weather.fog_amount,
		"weather_cloud": main.weather.cloud_amount,
		"sun_direction": _v3(main.game.sun_dir),
		"fog_enabled": main.world._env.fog_enabled,
		"volume_enabled": main.world._env.volumetric_fog_enabled,
		"fog_density": main.world._env.fog_density,
		"volume_density": main.world._env.volumetric_fog_density,
		"volume_length": main.world._env.volumetric_fog_length,
		"water_mesh_center": _v3(main.water.global_position),
		"water_dense_span": WaterSurface.DENSE_SPAN,
		"water_far_limit": WaterSurface.FAR_LIMIT,
		"wave_time": main.water.field.t,
		"wind_dir_xz": [main.water.field.wind_dir.x, main.water.field.wind_dir.y],
		"wind_power": main.water.field.wind_power,
		"wave_amplitude": main.water.field.mega_amp,
		"elapsed_ms": Time.get_ticks_msec(),
		"terrain_bounds_xz": [map_bounds().position.x, map_bounds().position.y, map_bounds().end.x, map_bounds().end.y],
		"terrain_edge_transition": Coast.EDGE_TRANSITION,
	}
	if main._rme4_volume != null:
		report["fog_box_center"] = _v3(main._rme4_volume.global_position)
		report["fog_box_size"] = _v3(main._rme4_volume.size)
		report["fog_box_visible"] = main._rme4_volume.visible
	if selected >= 0:
		var point := markers[selected]
		report["ground_height"] = main.coast.ground_height(point.x, point.z)
		report["water_depth"] = main.coast.water_depth(point.x, point.z)
		report["distance_to_boat"] = point.distance_to(main.boat.global_position)
		var bounds := map_bounds()
		report["distance_to_terrain_edge"] = minf(minf(point.x - bounds.position.x, bounds.end.x - point.x),
			minf(point.z - bounds.position.y, bounds.end.y - point.z))
	var optics: Array[float] = []
	for beacon in main.beacons:
		var pivot: Node3D = beacon["beam_pivot"]
		optics.append(pivot.rotation.y)
	report["beacon_yaws"] = optics
	report["island_layout"] = "closed-island-1"
	report["harbor_berth_xz"] = [IslandLayout.BERTH.x, IslandLayout.BERTH.y]
	report["harbor_moored"] = main.harbor != null and main.harbor.moored
	if main.shoals != null:
		report["shoal_warning"] = main.shoals.warning
		report["shoal_probe_depth"] = main.shoals.predicted_depth
		report["shoal_mark_count"] = main.shoals.positions.size()
	return report


func report_text(report: Dictionary) -> String:
	return "WORLD REPORT — %s\n%s\nКамера: %s; size=%.2f\nСумерки: %.3f; %s; fog=%.3f; cloud=%.3f\nБЕЗ ДЫМКИ: %s\n\n%s\n" % [
		VERSION, marker_text(), str(report["camera_position"]), main.camera.size,
		main.night01, main.weather.label(), main.weather.fog_amount, main.weather.cloud_amount,
		str(clear_view), JSON.stringify(report, "\t")]


func copy_report() -> void:
	DisplayServer.clipboard_set(report_text(make_report()))
	main.announce("ОТЧЁТ С КООРДИНАТАМИ СКОПИРОВАН")


func save_capture() -> void:
	if _capture_busy:
		return
	_capture_busy = true
	await RenderingServer.frame_post_draw
	var folder := "user://world_reports"
	var err := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	if err != OK:
		main.announce("НЕ УДАЛОСЬ СОЗДАТЬ ПАПКУ ОТЧЁТА: %d" % err)
		_capture_busy = false
		return
	var stamp := Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
	var base := folder + "/world_" + stamp + "_%d" % Time.get_ticks_msec()
	var report := make_report()
	var text := report_text(report)
	var png_error := get_viewport().get_texture().get_image().save_png(base + ".png")
	var text_error: int = OK
	var json_error: int = OK
	var file := FileAccess.open(base + ".txt", FileAccess.WRITE)
	if file != null:
		file.store_string(text)
		text_error = file.get_error()
		file.close()
	else:
		text_error = FileAccess.get_open_error()
	var json_file := FileAccess.open(base + ".json", FileAccess.WRITE)
	if json_file != null:
		json_file.store_string(JSON.stringify(report, "\t"))
		json_error = json_file.get_error()
		json_file.close()
	else:
		json_error = FileAccess.get_open_error()
	var path := ProjectSettings.globalize_path(base)
	DisplayServer.clipboard_set(text)
	print("[WORLD REPORT] ", path)
	if png_error == OK and text_error == OK and json_error == OK:
		main.announce("СНИМОК И ОТЧЁТ СОХРАНЕНЫ · Ctrl+O — открыть папку")
	else:
		main.announce("ОШИБКИ СОХРАНЕНИЯ: PNG=%d TXT=%d JSON=%d; %s" % [png_error, text_error, json_error, path])
	_capture_busy = false


func _input(event: InputEvent) -> void:
	if main == null:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var handled := true
		match event.physical_keycode:
			KEY_M:
				map_open = not map_open
				if map_open:
					main.boat.speed = 0.0
					_build_map()
			KEY_F:
				set_free_camera(not free_camera)
			KEY_ESCAPE:
				if map_open:
					map_open = false
				elif free_camera:
					set_free_camera(false)
				else:
					handled = false
			KEY_HOME:
				if is_active():
					overview()
				else:
					handled = false
			KEY_END:
				if map_open:
					_map_center = Vector2(main.boat.global_position.x, main.boat.global_position.z)
				else:
					handled = false
			KEY_ENTER:
				if is_active():
					_focus_marker()
				else:
					handled = false
			KEY_B:
				if free_camera:
					set_clear_view(not clear_view)
				else:
					handled = false
			KEY_TAB:
				if is_active() and not markers.is_empty():
					selected = (selected + 1) % markers.size()
				else:
					handled = false
			KEY_DELETE:
				if is_active() and selected >= 0:
					markers.remove_at(selected)
					selected = mini(selected, markers.size() - 1)
				else:
					handled = false
			KEY_O:
				if is_active() and event.ctrl_pressed:
					var folder := ProjectSettings.globalize_path("user://world_reports")
					DirAccess.make_dir_recursive_absolute(folder)
					OS.shell_open(folder)
				else:
					handled = false
			KEY_C:
				if is_active():
					copy_report()
				else:
					handled = false
			KEY_S:
				if is_active() and event.ctrl_pressed:
					save_capture()
				else:
					handled = false
			_:
				handled = false
		if handled:
			get_viewport().set_input_as_handled()
			queue_redraw()
	if not is_active():
		return
	if event is InputEventMouseMotion and map_open and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		_map_center -= event.relative / _map_rect().size * _map_span
		_map_center = _map_center.clamp(Vector2(-8000, -8000), Vector2(8000, 8000))
		get_viewport().set_input_as_handled()
	if event is InputEventMouseMotion and free_camera and not map_open:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
			_yaw -= event.relative.x * 0.004
			_pitch = clampf(_pitch + event.relative.y * 0.004, 0.20, 1.48)
			get_viewport().set_input_as_handled()
	if event is InputEventMouseButton and event.pressed:
		if map_open:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				_map_span = maxf(Coast.SIZE, _map_span / 1.25)
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_map_span = minf(7200.0, _map_span * 1.25)
			if event.button_index == MOUSE_BUTTON_LEFT and _map_rect().has_point(event.position):
				var world := map_to_world(event.position, _map_rect(), _map_span, _map_center)
				add_marker(surface_point(world.x, world.y))
				if event.double_click:
					_focus_marker()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			var hit := pick_surface(event.position)
			if not hit.is_empty():
				add_marker(hit["point"])
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			main.camera.size = maxf(8.0, main.camera.size / 1.18)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			main.camera.size = minf(1800.0, main.camera.size * 1.18)
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if is_active():
		queue_redraw()


func _text(at: Vector2, text: String, color: Color = Color("e0efea"), font_size: int = 14) -> void:
	draw_string(ThemeDB.fallback_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _draw() -> void:
	if main == null or not is_active():
		return
	if map_open:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.025, 0.045, 0.06, 0.96))
		_text(Vector2(28, 36), "КАРТА МИРА · X вправо, Z вниз · колесо — масштаб карты", Color("e0efea"), 19)
		_text(Vector2(28, 63), "M / Esc — закрыть · F — свободная камера · Home — общий вид · Ctrl+S — снимок и отчёт")
		var rect := _map_rect()
		draw_rect(rect, Color("17434f"))
		var terrain_rect := Rect2(world_to_map(map_bounds().position, rect, _map_span, _map_center), rect.size * Coast.SIZE / _map_span)
		var terrain_clip := terrain_rect.intersection(rect)
		if terrain_clip.has_area():
			if _map_texture != null:
				var texture_region := Rect2((terrain_clip.position - terrain_rect.position) / terrain_rect.size * MAP_RESOLUTION,
					terrain_clip.size / terrain_rect.size * MAP_RESOLUTION)
				draw_texture_rect_region(_map_texture, terrain_clip, texture_region)
			draw_rect(terrain_clip, Color("d8d3ad"), false, 1.5)
		var grid_step := 100 if _map_span <= 1800.0 else (500 if _map_span <= 4000.0 else 1000)
		var lower := _map_center - Vector2.ONE * _map_span * 0.5
		var upper := _map_center + Vector2.ONE * _map_span * 0.5
		var x_start := int(ceil(lower.x / grid_step)) * grid_step
		var z_start := int(ceil(lower.y / grid_step)) * grid_step
		for coordinate in range(x_start, int(upper.x) + 1, grid_step):
			var px := world_to_map(Vector2(coordinate, 0), rect, _map_span, _map_center).x
			draw_line(Vector2(px, rect.position.y), Vector2(px, rect.end.y), Color(1, 1, 1, 0.13))
			_text(Vector2(px - 10, rect.end.y + 20), str(coordinate), Color("9eb8b5"), 11)
		for coordinate in range(z_start, int(upper.y) + 1, grid_step):
			var pz := world_to_map(Vector2(0, coordinate), rect, _map_span, _map_center).y
			draw_line(Vector2(rect.position.x, pz), Vector2(rect.end.x, pz), Color(1, 1, 1, 0.13))
			_text(Vector2(rect.position.x + 3, pz - 3), str(coordinate), Color("9eb8b5"), 11)
		if main._rme4_volume != null:
			var volume := main._rme4_volume
			var corner := Vector2(volume.global_position.x - volume.size.x * 0.5,
				volume.global_position.z - volume.size.z * 0.5)
			var fog_rect := Rect2(world_to_map(corner, rect, _map_span, _map_center), Vector2(volume.size.x, volume.size.z) / _map_span * rect.size)
			var clipped := fog_rect.intersection(rect)
			if clipped.has_area():
				draw_rect(clipped, Color(1, 0.72, 0.3, 0.7), false, 2.0)
		var water_corner := Vector2(main.water.global_position.x, main.water.global_position.z) - Vector2.ONE * WaterSurface.DENSE_SPAN * 0.5
		var water_rect := Rect2(world_to_map(water_corner, rect, _map_span, _map_center), rect.size * WaterSurface.DENSE_SPAN / _map_span).intersection(rect)
		if water_rect.has_area():
			draw_rect(water_rect, Color(0.4, 0.7, 1.0, 0.7), false, 1.0)
		draw_rect(rect, Color("b5c6be"), false, 2.0)
		var boat_point := world_to_map(Vector2(main.boat.global_position.x, main.boat.global_position.z), rect, _map_span, _map_center)
		if rect.has_point(boat_point):
			draw_circle(boat_point, 5.0, Color("7ae3d0"))
		var camera_point := world_to_map(Vector2(main.camera.global_position.x, main.camera.global_position.z), rect, _map_span, _map_center)
		if rect.has_point(camera_point):
			draw_circle(camera_point, 4.0, Color("ffffff"))
		if main.shoals != null:
			for point in main.shoals.positions:
				var shoal := world_to_map(point, rect, _map_span, _map_center)
				if rect.has_point(shoal):
					draw_circle(shoal, 2.5, Color("d9b96f"))
		var harbor_point := world_to_map(IslandLayout.BERTH, rect, _map_span, _map_center)
		if rect.has_point(harbor_point):
			draw_rect(Rect2(harbor_point - Vector2(4, 4), Vector2(8, 8)), Color("9ad1ee"))
			_text(harbor_point + Vector2(8, 16), "БУХТА", Color("9ad1ee"), 12)
		for beacon in main.beacons:
			var bp: Vector3 = beacon["buoy_pos"]
			var tp: Vector3 = beacon["tower_pos"]
			var col: Color = beacon["color"]
			var pos := world_to_map(Vector2(bp.x, bp.z), rect, _map_span, _map_center)
			var tower := world_to_map(Vector2(tp.x, tp.z), rect, _map_span, _map_center)
			if rect.has_point(pos) and rect.has_point(tower):
				draw_line(tower, pos, Color(col.r, col.g, col.b, 0.6), 1.0)
			if rect.has_point(pos):
				draw_circle(pos, 3.0, col)
			if rect.has_point(tower):
				draw_circle(tower, 5.0, col)
				if _map_span <= 1800.0:
					_text(tower + Vector2(7, -7), str(beacon["name"]), col, 11)
		for index in range(markers.size()):
			var point := markers[index]
			var marker := world_to_map(Vector2(point.x, point.z), rect, _map_span, _map_center)
			if rect.has_point(marker):
				draw_circle(marker, 7.0 if index == selected else 4.0, Color("ff796f"))
				_text(marker + Vector2(6, -6), str(index + 1))
		var info := Vector2(rect.end.x + 28, 118)
		_text(info, "МЕТКА ПРОБЛЕМЫ", Color("ffae90"), 18)
		_text(info + Vector2(0, 33), marker_text(), Color("e0efea"), 13)
		_text(info + Vector2(0, 67), "ЛКМ — новая метка (до 32)")
		_text(info + Vector2(0, 93), "Двойной щелчок / Enter — осмотреть точку")
		_text(info + Vector2(0, 119), "C — копировать координаты и контекст")
		_text(info + Vector2(0, 145), "Ctrl+S — PNG + TXT + JSON; Ctrl+O — папка")
		_text(info + Vector2(0, 171), "Tab — выбрать метку; Delete — удалить")
		_text(info + Vector2(0, 192), "Бирюзовый — судно; белый — камера")
		_text(info + Vector2(0, 218), "Золотые точки — буи маяков")
		_text(info + Vector2(0, 244), "Золотая рамка — область низкого тумана")
		_text(info + Vector2(0, 270), "Синяя рамка — плотная сетка воды (620 м)")
		_text(info + Vector2(0, 296), "ПКМ — сдвиг карты; End — к судну")
		_text(info + Vector2(0, 318), "Светлая рамка — рельеф 900 м. Погода идёт.")
		_text(info + Vector2(0, 344), "Для дефекта: Enter → ЛКМ в сцене → Ctrl+S.")
	else:
		draw_rect(Rect2(14, 12, minf(size.x - 28, 1120), 144), Color(0.025, 0.045, 0.06, 0.9))
		_text(Vector2(28, 36), "ОСМОТР МИРА · F / Esc — к судну · M — карта · Home — весь мир сверху", Color("e0efea"), 16)
		_text(Vector2(28, 61), "WASD — движение · Q/E — высота · Shift — быстрее · ПКМ — поворот · колесо — масштаб", Color("b6c9c5"), 13)
		_text(Vector2(28, 85), "ЛКМ — метка · Enter — приблизить метку · C — копировать · Ctrl+S — снимок + отчёт · B — дымка", Color("b6c9c5"), 13)
		_text(Vector2(28, 114), marker_text(), Color("ffae90"), 14)
		_text(Vector2(28, 139), "Масштаб %.1f м · Сумерки %.2f · %s" % [main.camera.size, main.night01, main.weather.label()], Color("b6c9c5"), 12)
		if clear_view:
			_text(Vector2(28, 179), "ОБЗОР БЕЗ ДЫМКИ — это диагностический вид, не исходный рендер. B — вернуть атмосферу.", Color("ffae90"), 14)
		if selected >= 0 and not main.camera.is_position_behind(markers[selected]):
			var screen := main.camera.unproject_position(markers[selected])
			if Rect2(Vector2.ZERO, size).has_point(screen):
				draw_circle(screen, 7.0, Color("ff796f"), false, 2.0)
				draw_line(screen - Vector2(12, 0), screen + Vector2(12, 0), Color("ff796f"), 1.0)
				draw_line(screen - Vector2(0, 12), screen + Vector2(0, 12), Color("ff796f"), 1.0)
				_text(screen + Vector2(12, -10), "#%d" % (selected + 1), Color("ffae90"))
	if main.notice_time > 0.0:
		_text(Vector2(28, size.y - 22), main.notice, Color("ffda9a"), 13)
