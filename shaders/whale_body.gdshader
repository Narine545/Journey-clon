shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

// One opaque, shadow-casting body in the ordinary world lighting pass.
uniform float swim_phase = 0.0;
uniform float glow_strength : hint_range(0.0, 4.0) = 0.0;
uniform vec4 back_color : source_color = vec4(0.13, 0.25, 0.31, 1.0);
uniform vec4 belly_color : source_color = vec4(0.36, 0.47, 0.48, 1.0);
uniform vec4 glow_color : source_color = vec4(0.14, 0.78, 1.0, 1.0);
varying vec3 body_pos;

float hash_whale(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
float noise_whale(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash_whale(i), hash_whale(i + vec2(1.0, 0.0)), f.x),
		mix(hash_whale(i + vec2(0.0, 1.0)), hash_whale(i + vec2(1.0, 1.0)), f.x), f.y);
}
void vertex() {
	body_pos = VERTEX;
	// Мягкая волна проходит вдоль задней половины тела, а не шарнир в одном
	// месте. Аналитически поворачиваем нормали вместе с деформацией: иначе
	// блики остаются неподвижными и создают впечатление дёрганья.
	float x = VERTEX.x;
	float u = clamp(-x / 2.9, 0.0, 1.0);
	float tail = u * u * (3.0 - 2.0 * u);
	float tail_dx = (x < 0.0 && x > -2.9) ? -6.0 * u * (1.0 - u) / 2.9 : 0.0;
	float phase_y = swim_phase - x * 0.8;
	float phase_z = swim_phase * 0.55 - x * 0.65;
	float dy_dx = 0.16 * (cos(phase_y) * -0.8 * tail + sin(phase_y) * tail_dx);
	float dz_dx = 0.035 * (cos(phase_z) * -0.65 * tail + sin(phase_z) * tail_dx);
	VERTEX.y += sin(phase_y) * tail * 0.16;
	VERTEX.z += sin(phase_z) * tail * 0.035;
	NORMAL = normalize(vec3(NORMAL.x - dy_dx * NORMAL.y - dz_dx * NORMAL.z, NORMAL.y, NORMAL.z));
}
void fragment() {
	float back = smoothstep(-0.35, 0.42, body_pos.y);
	float mottling = noise_whale(body_pos.xz * 2.0 + body_pos.y * 1.2);
	ALBEDO = mix(belly_color.rgb, back_color.rgb, back) * mix(0.82, 1.18, mottling);
	ROUGHNESS = 0.36;
	SPECULAR = 0.48;
	// Emission comes from the skin itself; HDR lets the existing world bloom
	// spread from the actual silhouette. It is not a separate transparent disc.
	float pattern = smoothstep(0.42, 0.76, noise_whale(body_pos.xz * 1.4 + body_pos.y * 2.1));
	EMISSION = glow_color.rgb * glow_strength * (0.15 + 0.85 * pattern);
}
