shader_type canvas_item;
render_mode blend_mix;

// TIDECUT · переход волной с зубцами.
// Маска не «фейдит» экран, а накрывает его фронтом с регулярными зубцами:
// тот же шаг, что у кромок панелей. Пена отмечает гребень.

uniform vec4 wipe_color : source_color = vec4(0.051, 0.082, 0.125, 1.0);
uniform vec4 crest_color : source_color = vec4(0.937, 0.918, 0.847, 1.0);
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float teeth = 26.0;
uniform float tooth_depth : hint_range(0.0, 0.12) = 0.03;
uniform float direction = 1.0;
uniform float crest_width : hint_range(0.002, 0.08) = 0.012;

void fragment() {
	float zig = abs(fract(UV.x * teeth) - 0.5) * 2.0;
	float front = mix(-0.25, 1.25, clamp(progress, 0.0, 1.0));
	float edge = front - direction * zig * tooth_depth;
	float mask = direction > 0.0 ? step(UV.y, edge) : step(edge, UV.y);
	float crest = 1.0 - smoothstep(0.0, crest_width, abs(UV.y - edge));
	float crest_mask = crest * step(0.002, progress) * (1.0 - step(0.998, progress));
	vec3 rgb = mix(wipe_color.rgb, crest_color.rgb, crest_mask);
	float alpha = max(mask * wipe_color.a, crest_mask * crest_color.a);
	COLOR = vec4(rgb, clamp(alpha, 0.0, 1.0));
}
