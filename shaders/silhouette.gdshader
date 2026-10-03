shader_type spatial;
render_mode unshaded, fog_disabled, shadows_disabled;

// Дальние пики-силуэты: чуть темнее дымки, с тёплой кромкой к солнцу.

uniform vec3 haze_color : source_color = vec3(0.96, 0.66, 0.55);
uniform vec3 peak_color : source_color = vec3(0.34, 0.24, 0.42);
uniform float haze_amount = 0.72; // насколько пик утопает в дымке

varying vec3 w_pos;
varying vec3 w_normal;

void vertex() {
	w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	w_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 col = peak_color;
	// тёплая кромка на склонах, обращённых к солнцу
	float sun_side = smoothstep(0.1, 0.8, dot(normalize(w_normal), normalize(vec3(0.1, 0.26, -0.96))));
	col = mix(col, haze_color * 1.05, sun_side * 0.35);
	// дымка: пик почти растворён, но читается силуэтом
	col = mix(col, haze_color, haze_amount);
	// чуть темнее к подножию
	col *= mix(1.06, 0.9, smoothstep(60.0, -10.0, w_pos.y));
	ALBEDO = col;
}
