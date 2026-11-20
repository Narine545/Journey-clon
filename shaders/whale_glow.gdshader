shader_type spatial;
// Мягкое биолюминесцентное свечение вокруг тела кита.
// Это не «пятно вместо существа»: тело рисует SDF-реймарчер, а здесь только
// аура света — она появляется ночью и гаснет днём.
render_mode blend_add, unshaded, depth_draw_never, cull_disabled, fog_disabled;

uniform vec3 glow_color : source_color = vec3(0.36, 0.78, 0.98);
uniform float strength = 0.5;

void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	float r = length(uv);
	// Ядро мягкое, край не обрезается в круг — иначе виден «диск».
	float falloff = exp(-r * r * 3.0) * (1.0 - smoothstep(0.80, 1.0, r));
	ALBEDO = glow_color;
	ALPHA = falloff * strength;
}
