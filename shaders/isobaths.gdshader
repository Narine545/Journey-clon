shader_type canvas_item;
render_mode blend_mix;

// TIDECUT · изобаты вместо полутонов.
// Тонкие замкнутые контуры глубины, как на морской карте: шаг 28–40 px,
// пена с alpha 6 %, медленный дрейф. Никакого растрового шума и градиентов.

uniform vec4 line_color : source_color = vec4(0.937, 0.918, 0.847, 0.06);
uniform vec2 field_size = vec2(1920.0, 1080.0);
uniform float step_px : hint_range(12.0, 80.0) = 34.0;
uniform float thickness : hint_range(0.2, 3.0) = 0.9;
uniform float drift : hint_range(0.0, 1.0) = 0.3;
uniform float wobble : hint_range(0.2, 2.0) = 1.0;
uniform float alpha : hint_range(0.0, 1.0) = 1.0;

float depth_field(vec2 p, float t) {
	float v = sin(p.x * 0.0037 + t * 0.42) * cos(p.y * 0.0031 - t * 0.33);
	v += 0.62 * sin((p.x * 0.9 + p.y * 1.2) * 0.0021 - t * 0.27);
	vec2 c = (p - field_size * vec2(0.34, 0.42)) / field_size.y;
	v += 0.5 * sin(length(c) * 5.2 - t * 0.5);
	vec2 d = (p - field_size * vec2(0.78, 0.72)) / field_size.y;
	v += 0.35 * sin(length(d) * 7.4 + t * 0.36);
	return v * wobble;
}

void fragment() {
	vec2 p = UV * field_size;
	float t = TIME * drift;
	float bands = depth_field(p, t) * 120.0 / max(4.0, step_px);
	// Расстояние до ближайшей изобаты в единицах полос.
	float dist = min(fract(bands), 1.0 - fract(bands));
	float aa = max(fwidth(bands), 0.0008) * 1.1;
	float line = 1.0 - smoothstep(0.0, aa * max(0.5, thickness), dist);
	// Каждая пятая линия — «материковая» изобата, чуть плотнее.
	float major_bands = bands / 5.0;
	float major_dist = min(fract(major_bands), 1.0 - fract(major_bands));
	float major = 1.0 - smoothstep(0.0, aa * 2.4, major_dist);
	float value = line * (0.75 + 0.6 * major);
	COLOR = vec4(line_color.rgb, clamp(line_color.a * value * alpha, 0.0, 1.0));
}
