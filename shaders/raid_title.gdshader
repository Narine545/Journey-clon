// Original lightweight adaptation of the user's animated-text/liquid references.
// Font UVs and glyph alpha stay untouched: safe for Cyrillic font atlases.
shader_type canvas_item;
uniform vec2 label_size = vec2(900.0, 32.0);
uniform vec4 fluid_top : source_color = vec4(0.65, 1.0, 0.88, 1.0);
uniform vec4 fluid_bottom : source_color = vec4(0.18, 0.60, 0.78, 1.0);
uniform float motion_strength : hint_range(0.0, 1.0) = 0.5;
varying vec2 text_local;
void vertex() {
	text_local = VERTEX;
	vec2 center = label_size * 0.5;
	float angle = sin(TIME * 1.7) * 0.0015 * motion_strength;
	float pulse = 1.0 + sin(TIME * 2.2) * 0.0015 * motion_strength;
	vec2 p = (VERTEX - center) * pulse;
	float c = cos(angle);
	float s = sin(angle);
	vec2 jitter = floor(vec2(sin(TIME * 7.0), sin(TIME * 5.0 + 1.2)) * 1.1 + 0.5);
	VERTEX = center + mat2(vec2(c, s), vec2(-s, c)) * p + jitter * 0.5 * motion_strength;
}
void fragment() {
	vec2 p = text_local / max(label_size, vec2(1.0));
	float flow = TIME * motion_strength;
	float surface = 0.48 + sin(p.x * 10.0 + flow * 1.5) * 0.13;
	surface += sin(p.x * 23.0 - flow) * 0.04;
	float liquid = smoothstep(surface - 0.09, surface + 0.09, p.y);
	// COLOR already includes the font texture and modulate. Do not resample its atlas.
	COLOR.rgb *= mix(fluid_top.rgb, fluid_bottom.rgb, liquid);
}
