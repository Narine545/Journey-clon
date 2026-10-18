shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque;

// Procedural spherical iris, dark limbal ring, pupil and twin catchlights.
// Based on the configurable procedural eye concept linked on Godot Shaders:
// https://godotshaders.com/shader/eye/ (code snippets there are MIT licensed).
uniform vec3 background_color : source_color = vec3(0.96, 0.89, 0.72);
uniform vec3 iris_color_outer : source_color = vec3(0.12, 0.53, 0.55);
uniform vec3 iris_color_inner : source_color = vec3(0.75, 0.57, 0.26);
uniform vec3 pupil_color : source_color = vec3(0.025, 0.032, 0.038);
uniform vec3 outline_color : source_color = vec3(0.07, 0.045, 0.035);
uniform vec3 highlight_color : source_color = vec3(1.0, 0.97, 0.84);
uniform float iris_radius : hint_range(0.05, 0.48) = 0.31;
uniform float pupil_radius : hint_range(0.02, 0.30) = 0.115;

float circle_mask(vec2 uv, float radius, float softness) {
	return 1.0 - smoothstep(radius - softness, radius + softness, length(uv - vec2(0.5)));
}

void fragment() {
	vec2 p = UV - vec2(0.5);
	float r = length(p);
	float eye = 1.0 - smoothstep(0.465, 0.50, r);
	float iris = circle_mask(UV, iris_radius, 0.012);
	float limbal = circle_mask(UV, iris_radius * 1.10, 0.008) - iris;
	float pupil = circle_mask(UV, pupil_radius, 0.009);
	float iris_gradient = smoothstep(-iris_radius, iris_radius, p.y);
	vec3 color = background_color;
	color = mix(color, outline_color, limbal);
	color = mix(color, mix(iris_color_outer, iris_color_inner, iris_gradient), iris);
	color = mix(color, pupil_color, pupil);
	float shine_a = 1.0 - smoothstep(0.043, 0.060, length(UV - vec2(0.385, 0.38)));
	float shine_b = 1.0 - smoothstep(0.017, 0.026, length(UV - vec2(0.62, 0.60)));
	color = mix(color, highlight_color, max(shine_a, shine_b) * iris);
	ALBEDO = color;
	ALPHA = eye;
}
