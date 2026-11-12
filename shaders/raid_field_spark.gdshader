// Independent small soft spark; no Particle Process v2 code imported.
shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;
void fragment() {
	float distance = length(UV * 2.0 - 1.0);
	float mask = 1.0 - smoothstep(0.15, 1.0, distance);
	ALBEDO = COLOR.rgb;
	EMISSION = COLOR.rgb * 0.25 * mask;
	ALPHA = COLOR.a * mask;
}
