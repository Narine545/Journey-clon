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
	float tail = smoothstep(0.0, 2.9, -VERTEX.x);
	VERTEX.y += sin(swim_phase - VERTEX.x * 1.4) * tail * 0.18;
	VERTEX.z += sin(swim_phase * 0.52 - VERTEX.x) * tail * 0.07;
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
