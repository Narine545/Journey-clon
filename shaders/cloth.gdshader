shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled;

// Ткань путника: тот же двухтоновый мотив, что у песка, + тёплое контурное
// свечение. UV.x ленты шарфа используется как градиент к кончику.

uniform vec3 sun_dir = vec3(0.10, 0.26, -0.96);
uniform vec3 cloth_main : source_color = vec3(0.52, 0.16, 0.15);
uniform vec3 cloth_lit : source_color = vec3(1.0, 0.60, 0.40);
uniform vec3 horizon_col : source_color = vec3(0.96, 0.66, 0.55);
uniform vec3 sky_col : source_color = vec3(0.28, 0.24, 0.43);
uniform float fog_distance = 340.0;
uniform float glow_amount = 0.0; // энергия (появится на этапе 3)
uniform float tip_glow = 0.0;    // свечение кончика шарфа

varying vec3 w_pos;
varying vec3 w_normal;
varying vec2 v_uv;

void vertex() {
	w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	w_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	v_uv = UV;
}

void fragment() {
	vec3 N = normalize(w_normal);
	vec3 L = normalize(sun_dir);

	// двухтон: к солнцу — тёплая ткань, от солнца — глубокая
	float lit = smoothstep(-0.35, 0.75, dot(N, L));
	vec3 col = mix(cloth_main, cloth_lit, lit * 0.8);

	// контурное свечение против солнца — силуэт читается на фоне дюн
	vec3 V = normalize(CAMERA_POSITION_WORLD - w_pos);
	float rim = pow(1.0 - clamp(dot(N, V), 0.0, 1.0), 2.2);
	col += cloth_lit * rim * 0.5;

	// энергия/шарф: свет к кончику
	col += vec3(1.0, 0.92, 0.7) * glow_amount * (0.35 + 0.65 * v_uv.x);
	col += vec3(1.0, 0.92, 0.7) * tip_glow * pow(v_uv.x, 2.0);

	// ручная дымка — та же, что у песка
	float dist = length(CAMERA_POSITION_WORLD - w_pos);
	float fog = 1.0 - exp(-pow(dist / fog_distance, 2.1));
	float above = smoothstep(-2.0, 16.0, w_pos.y - CAMERA_POSITION_WORLD.y);
	vec3 fcol = mix(horizon_col, sky_col, above * 0.6);

	ALBEDO = mix(col, fcol, fog);
}
