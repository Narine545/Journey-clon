// Boat-local adaptation of the user's glitch: colored slice/channel echoes, not screen refraction.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;
uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform float effect_age = 0.0;
uniform mat4 boat_inverse;
varying vec3 boat_point;

float hash_value(vec2 point) {
	return fract(sin(dot(point, vec2(12.9898, 78.233))) * 43758.5453);
}

void vertex() {
	// One coordinate space across hull/cabin meshes, including the vessel's rocking pose.
	boat_point = (boat_inverse * MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float frame = floor(effect_age * 24.0);
	float band = floor(boat_point.z * 4.0 + boat_point.y * 2.0);
	float seed = hash_value(vec2(band, frame));
	float slice = step(0.60, seed);
	float scan = step(0.86, fract(boat_point.z * 9.0 + boat_point.y * 3.0 + frame * 0.11));
	float channel = fract(boat_point.x * 1.4 + frame * 0.19 + seed);
	vec3 ink = mix(vec3(1.0, 0.10, 0.18), vec3(0.10, 0.85, 1.0), step(0.5, channel));
	ink = mix(ink, vec3(0.35, 1.0, 0.60), scan * 0.5);
	ALBEDO = ink;
	ALPHA = clamp(intensity * (slice * 0.70 + scan * 0.20), 0.0, 0.72);
}
