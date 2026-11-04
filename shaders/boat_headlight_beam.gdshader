shader_type spatial;
// Короткий видимый объём носового прожектора, не экранный эффект.
// Тест глубины оставлен включённым: корпус/берег перекрывают луч.
// Глубину не записываем, чтобы не скрывать воду и ресурсные пятна.
render_mode unshaded, blend_add, depth_draw_never, cull_back, fog_disabled;

uniform vec3 beam_color : source_color = vec3(1.0, 0.80, 0.57);
uniform float beam_strength : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	// Сгладить силуэт конуса и растворить оба конца без жёсткого среза.
	float soft_side = pow(abs(dot(normalize(NORMAL), normalize(VIEW))), 0.7);
	float along = smoothstep(0.02, 0.38, UV.y)
		* (1.0 - smoothstep(0.72, 0.99, UV.y));
	ALBEDO = beam_color;
	ALPHA = 0.19 * beam_strength * soft_side * along;
}
