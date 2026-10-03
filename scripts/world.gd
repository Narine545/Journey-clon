class_name GameWorld
extends Node3D
## Небо, солнце, дымка, маяк на горизонте. Всё строится кодом в setup().

const BEACON_XZ := Vector2(0.0, -640.0) # далеко за стеной дюн — цель путешествия
const PILLAR_HEIGHT := 200.0

var game # автозагрузка Game


func setup(game_ref) -> void:
	game = game_ref
	_build_environment()
	_build_sun()
	_build_beacon()


func _build_environment() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.24, 0.20, 0.39)
	sky_mat.sky_horizon_color = Color(0.97, 0.63, 0.46)
	sky_mat.ground_bottom_color = Color(0.20, 0.15, 0.28)
	sky_mat.ground_horizon_color = Color(0.94, 0.60, 0.48)
	sky_mat.sun_angle_max = 6.0
	sky_mat.sun_curve = 0.10
	sky_mat.sky_energy_multiplier = 1.0

	var sky := Sky.new()
	sky.sky_material = sky_mat

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.0

	# Мягкое свечение солнца и маяка (в Compatibility glow доступен).
	env.glow_enabled = true
	env.glow_intensity = 0.45
	env.glow_strength = 1.0
	env.glow_bloom = 0.06
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.glow_hdr_threshold = 0.85

	# Дымка в цвет горизонта — для любых материалов со стандартным туманом.
	env.fog_enabled = true
	env.fog_light_color = Game.HORIZON_COL
	env.fog_density = 0.0034
	env.fog_sky_affect = 0.0

	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)


func _build_sun() -> void:
	# Свет нужен в первую очередь небу (диск солнца) и будущим объектам.
	var sun := DirectionalLight3D.new()
	var forward := -Game.SUN_DIR.normalized()
	sun.basis = Basis.looking_at(forward, Vector3.UP)
	sun.light_color = Color(1.0, 0.83, 0.66)
	sun.light_energy = 1.15
	sun.shadow_enabled = false
	add_child(sun)


func _build_beacon() -> void:
	# Дальние пики-силуэты, за которые «садится» свет.
	var silhouette_mat := ShaderMaterial.new()
	silhouette_mat.shader = load("res://shaders/silhouette.gdshader")

	var peaks := [
		[Vector2(-170.0, -660.0), 150.0, 120.0],
		[Vector2(0.0, -690.0), 180.0, 165.0],
		[Vector2(150.0, -650.0), 130.0, 105.0],
	]
	for peak in peaks:
		var cone := MeshInstance3D.new()
		var cone_mesh := CylinderMesh.new()
		cone_mesh.top_radius = 0.0 # конус
		cone_mesh.bottom_radius = peak[1]
		cone_mesh.height = peak[2]
		cone_mesh.radial_segments = 7
		cone.mesh = cone_mesh
		cone.material_override = silhouette_mat
		cone.position = Vector3(peak[0].x, peak[2] * 0.5 - 24.0, peak[0].y)
		cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(cone)

	# Столб света над центральным пиком — виден издалека сквозь дымку.
	var pillar_mat := ShaderMaterial.new()
	pillar_mat.shader = load("res://shaders/beacon.gdshader")

	for rotation_deg in [0.0, 90.0]:
		var quad := MeshInstance3D.new()
		var plane := PlaneMesh.new()
		plane.orientation = PlaneMesh.FACE_Z
		plane.size = Vector2(26.0, PILLAR_HEIGHT)
		quad.mesh = plane
		quad.material_override = pillar_mat
		quad.position = Vector3(BEACON_XZ.x, PILLAR_HEIGHT * 0.42, BEACON_XZ.y)
		quad.rotate_y(deg_to_rad(rotation_deg))
		quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(quad)
