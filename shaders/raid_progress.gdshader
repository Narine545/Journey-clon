// Wave-front progress with four bounded procedural motes, no texture dependencies.
shader_type canvas_item;
uniform float progress : hint_range(0.0, 1.0) = 0.5;
uniform vec2 bar_size = vec2(200.0, 8.0);
uniform vec4 fill_color : source_color = vec4(0.47, 0.87, 0.80, 1.0);
uniform vec4 background_color : source_color = vec4(0.025, 0.06, 0.08, 0.90);
uniform float effect_time = 0.0;
uniform float motion : hint_range(0.0, 1.0) = 1.0;
void fragment() {
	float value = clamp(progress, 0.0, 1.0);
	vec2 dimensions = max(bar_size, vec2(1.0));
	float wave = sin(UV.y * 6.283185 + effect_time * 2.0) * 0.8 * motion / dimensions.x;
	float edge = clamp(value + wave, 0.0, 1.0);
	float filled = 1.0 - smoothstep(edge - 0.5 / dimensions.x, edge + 0.5 / dimensions.x, UV.x);
	// Strict endpoints: never show fill/motes at zero or holes at 100 percent.
	if (value <= 0.0) { filled = 0.0; }
	if (value >= 1.0) { filled = 1.0; }
	vec3 ink = fill_color.rgb * mix(0.78, 1.0, UV.x);
	float motes = 0.0;
	if (motion > 0.0) {
	for (int i = 0; i < 4; i++) {
		float id = float(i);
		vec2 point = vec2(value * dimensions.x - 2.0 - mod(effect_time * (5.0 + id) + id * 7.0, 26.0),
			dimensions.y * (0.5 + sin(effect_time + id * 2.3) * 0.22));
		float distance_px = length(UV * dimensions - point);
		motes += (1.0 - smoothstep(0.3, 1.3, distance_px)) * 0.18;
	}
	}
	vec4 result = mix(background_color, vec4(ink, fill_color.a), filled);
	result.rgb += fill_color.rgb * motes * filled * motion;
	COLOR *= result;
}
