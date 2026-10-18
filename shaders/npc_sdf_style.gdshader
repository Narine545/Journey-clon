shader_type spatial;
render_mode diffuse_toon, specular_toon, cull_disabled;

// Warm, soft-edged clay/toon finish tuned to the sand-sea SDF fish palette.
uniform vec4 base_color : source_color = vec4(0.78, 0.43, 0.25, 1.0);
uniform float night_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec3 sun_direction = vec3(0.0, 1.0, 0.0);
varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float grain = fract(sin(dot(floor(world_pos * 38.0), vec3(12.9898, 78.233, 37.719))) * 43758.5453);
	float fleck = (grain - 0.5) * 0.035;
	ALBEDO = base_color.rgb * (1.0 + fleck);
	ROUGHNESS = 0.92;
	SPECULAR = 0.12;
}

void light() {
	float ndl = max(dot(normalize(NORMAL), normalize(LIGHT)), 0.0);
	float band = smoothstep(0.03, 0.42, ndl);
	vec3 warm = mix(vec3(0.36, 0.29, 0.42), vec3(1.0, 0.82, 0.60), band);
	vec3 night_fill = vec3(0.24, 0.34, 0.58) * night_amount * 0.28;
	DIFFUSE_LIGHT += (LIGHT_COLOR * ATTENUATION * warm * ALBEDO * ndl) + night_fill * ALBEDO;
}
