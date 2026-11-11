// Independent transparent-shell prototype; concept reference AlexZero, see SHADER-CREDITS.md.
// No screen snapshot: transparent ocean remains visible beneath the shell.
shader_type spatial;
render_mode unshaded, cull_back, blend_mix, depth_draw_never;
uniform bool gravity_field = false;
void fragment() {
	float rim = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 3.0);
	// Smooth angle-based tint, no animated spatial bands.
	ALBEDO = mix(vec3(0.10, 0.65, 0.85), vec3(0.65, 0.38, 0.80), rim);
	if (gravity_field) {
		ALBEDO = mix(vec3(0.40, 0.15, 0.75), vec3(0.95, 0.45, 0.85), rim);
	}
	EMISSION = ALBEDO * rim * 0.5;
	ALPHA = 0.035 + rim * 0.65;
}
