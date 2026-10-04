class_name SdfDunes
extends MeshInstance3D
## Дальнее море барханов: квад-меш на горизонте с SDF-реймарчингом
## (плавное CSG-объединение дюн, по мотивам vav-labs / I. Quilez).
## Квад стоит ПОЗАДИ террейна — взаимное перекрытие даёт обычный
## depth-тест, поэтому техника работает в Compatibility.
## Шейдер: shaders/sdf_dunes.gdshader.

const QUAD_Z := -1500.0 # за всеми барханами и стенами мира
const QUAD_W := 4600.0
const QUAD_H := 1100.0


func setup() -> void:
	var quad := PlaneMesh.new()
	quad.orientation = PlaneMesh.FACE_Z # лицом к игроку (+Z)
	quad.size = Vector2(QUAD_W, QUAD_H)
	mesh = quad
	position = Vector3(0.0, QUAD_H * 0.30, QUAD_Z)
	extra_cull_margin = 6000.0
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/sdf_dunes.gdshader")
	mat.set_shader_parameter("sun_dir", Game.SUN_DIR)
	mat.set_shader_parameter("dune_col", Color(0.50, 0.34, 0.33))
	mat.set_shader_parameter("dune_hot", Color(0.90, 0.52, 0.32))
	mat.set_shader_parameter("haze_col", Game.HORIZON_COL)
	mat.set_shader_parameter("sky_col", Game.SKY_COL)
	material_override = mat
