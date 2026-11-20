shader_type spatial;
// Тень тела под поверхностью: тёмный вытянутый силуэт на воде.
// Нужна ровно для одного — чтобы было видно, идёт кит под водой или по ней:
// SDF-тело под плоскостью моря луч не рисует (он обрывается на поверхности).
render_mode blend_mix, unshaded, depth_draw_never, cull_disabled, fog_disabled;

uniform vec4 tint : source_color = vec4(0.02, 0.05, 0.08, 1.0);
uniform float strength = 0.35;

void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	// Поперёк тела силуэт уже, чем вдоль.
	float r = length(vec2(uv.x, uv.y * 1.75));
	float a = (1.0 - smoothstep(0.45, 1.0, r)) * strength;
	ALBEDO = tint.rgb;
	ALPHA = clamp(a, 0.0, 0.75);
}
