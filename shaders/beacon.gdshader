shader_type spatial;
render_mode unshaded, fog_disabled, shadows_disabled, blend_add, cull_disabled;

// Столб света на горизонте — цель путешествия. Светится сквозь любую дымку.

uniform vec3 core_color : source_color = vec3(1.0, 0.88, 0.58);
uniform float intensity = 1.4;

varying vec2 v_uv;

void vertex() {
	v_uv = UV;
}

void fragment() {
	// UV: x — поперёк столба, y — вдоль (0 внизу)
	float edge = smoothstep(0.0, 0.35, v_uv.x) * smoothstep(1.0, 0.65, v_uv.x);
	float fade_top = pow(clamp(v_uv.y, 0.0, 1.0), 0.65); // гаснет к вершине
	float fade_bottom = smoothstep(0.0, 0.12, v_uv.y);
	// бегущие вверх волны света
	float rising = 0.5 + 0.5 * sin(v_uv.y * 46.0 - TIME * 2.4);
	float pulse = 0.88 + 0.12 * sin(TIME * 1.1);
	float a = edge * fade_top * fade_bottom * pulse * (0.45 + 0.55 * rising);
	ALBEDO = core_color * intensity;
	ALPHA = a * 0.9;
}
