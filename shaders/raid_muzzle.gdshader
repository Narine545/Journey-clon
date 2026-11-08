// Original procedural, axis-aligned side/face muzzle flash.
// Reference idea: shadecore_dev's Z-axis billboard; no texture asset required.
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, fog_disabled;
uniform float flash_scale : hint_range(1.0, 1.6) = 1.0;
varying float flash_strength;
varying float face_pass;
void vertex() {
	vec3 shot_axis = normalize(MODEL_MATRIX[2].xyz);
	vec3 view_axis = (VIEW_MATRIX * vec4(shot_axis, 0.0)).xyz;
	float projected_length = length(view_axis.xy);
	vec2 along = vec2(1.0, 0.0);
	if (projected_length > 0.0001) { along = view_axis.xy / projected_length; }
	vec2 across = vec2(-along.y, along.x);
	float face_weight = smoothstep(0.55, 0.90, abs(view_axis.z));
	face_pass = INSTANCE_CUSTOM.g;
	flash_strength = INSTANCE_CUSTOM.r * mix(1.0 - face_weight, face_weight, face_pass);
	vec2 side_offset = along * ((VERTEX.x + 0.5) * 3.6) + across * VERTEX.y * 1.6;
	vec2 face_offset = VERTEX.xy * 2.0;
	vec3 center_view = (MODELVIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	POSITION = PROJECTION_MATRIX * vec4(center_view + vec3(mix(side_offset, face_offset, face_pass) * flash_scale, 0.0), 1.0);
}
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float width = (1.0 - UV.x) * 0.8 + 0.06;
	width *= 0.92 + sin(UV.x * 24.0) * 0.08;
	float side = (1.0 - smoothstep(width * 0.35, width, abs(p.y))) * (1.0 - smoothstep(0.3, 1.0, UV.x));
	float face = exp(-dot(p, p) * 5.0) * (1.0 - smoothstep(0.55, 1.0, length(p)));
	float shape = mix(side, face, face_pass);
	ALBEDO = vec3(0.0);
	EMISSION = mix(vec3(1.0, 0.42, 0.10), vec3(1.0, 0.88, 0.48), shape) * 1.6;
	ALPHA = shape * flash_strength;
}
