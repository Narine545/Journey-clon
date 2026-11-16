shader_type spatial;
// Свет сферы сквозь толщу воды: мягкое пятно на поверхности там, где сфера
// ушла под воду, плюс расходящееся кольцо от входа и выхода.
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 glow_tint : source_color = vec4(0.21, 0.82, 0.73, 1.0);
uniform vec4 ring_tint : source_color = vec4(0.86, 0.96, 1.0, 1.0);
uniform float glow_strength : hint_range(0.0, 3.0) = 0.0;
uniform float ring_radius : hint_range(0.0, 1.4) = 0.0;
uniform float ring_alpha : hint_range(0.0, 2.0) = 0.0;

float h12(vec2 p) {
	return fract(sin(dot(p, vec2(41.7, 289.3))) * 43758.5453);
}

float n2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h12(i), h12(i + vec2(1.0, 0.0)), f.x),
		mix(h12(i + vec2(0.0, 1.0)), h12(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	vec2 uv = UV - 0.5;
	float r = length(uv) * 2.0;
	float inside = clamp(1.0 - r, 0.0, 1.0);
	// Пятно дышит и переливается, как свет, преломлённый толщей воды.
	float swirl = n2(uv * 5.0 + vec2(TIME * 0.28, -TIME * 0.19))
		* n2(uv * 9.0 - vec2(TIME * 0.41, TIME * 0.33));
	float core = pow(inside, 3.0);
	float body = pow(inside, 1.4) * (0.30 + 0.70 * swirl);
	float glow = glow_strength * (body * 0.5 + core * 2.0);
	// Всплеск у входа в воду и у выхода обратно: не ровное кольцо, а «корона»
	// из водяных струй — по кадру сверху её видно сразу.
	float band = smoothstep(0.15, 0.01, abs(r - ring_radius));
	float ang = atan(uv.y, uv.x);
	float rays = 0.45 + 0.55 * abs(sin(ang * 9.0 + TIME * 0.7));
	float crown = ring_alpha * band * rays * (0.25 + 0.75 * inside);
	// Пена внутри короны — сразу за гребнем.
	float foam = ring_alpha * 0.35 * smoothstep(ring_radius, 0.0, r) * step(0.02, ring_radius);
	float total = glow + crown + foam;
	ALBEDO = mix(glow_tint.rgb, ring_tint.rgb, clamp((crown + foam) / max(total, 0.001), 0.0, 1.0));
	ALPHA = clamp(total, 0.0, 1.0);
}
