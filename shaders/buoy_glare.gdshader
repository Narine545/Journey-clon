shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
uniform vec4 tint : source_color = vec4(1.0);
uniform float flash_strength = 0.0;
uniform bool instanced_mode = false;
varying vec3 glare_color;
varying float glare_flash;
void vertex() {
	glare_color = instanced_mode ? COLOR.rgb : tint.rgb;
	glare_flash = instanced_mode ? INSTANCE_CUSTOM.r : flash_strength;
	// World-sized, depth-tested soft halo centered on the actual lens.
	// Facing the camera avoids a subpixel edge-on lens disappearing.
	vec3 center_view = (MODELVIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	POSITION = PROJECTION_MATRIX * vec4(center_view + vec3(VERTEX.xy, 0.0), 1.0);
}
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r2 = dot(p, p);
	float halo = exp(-r2 * 5.0) * (1.0 - smoothstep(0.6, 1.0, r2));
	ALBEDO = vec3(0.0);
	EMISSION = glare_color * 3.2;
	ALPHA = halo * glare_flash;
}
