// Independent transparent-shell prototype; concept reference AlexZero, see SHADER-CREDITS.md.
// No screen snapshot: transparent ocean remains visible beneath the shell.
shader_type spatial;
render_mode unshaded, cull_back, blend_mix, depth_draw_never;
void fragment() {
	float rim = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 3.0);
	float bands = 0.5 + 0.5 * sin(VERTEX.y * 5.0 + TIME * 3.0);
	ALBEDO = mix(vec3(0.10, 0.65, 0.85), vec3(0.85, 0.25, 0.65), bands);
	EMISSION = ALBEDO * rim * 0.5;
	ALPHA = 0.035 + rim * 0.65;
}
