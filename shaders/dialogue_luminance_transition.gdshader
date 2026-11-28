shader_type canvas_item;
render_mode unshaded, blend_mix;

// Luminance masks inspired by null_builds (CC0):
// https://godotshaders.com/shader/luminance-mask-transition/
// The old frame is captured once; the screen texture is the new live scene.
uniform sampler2D screen_texture : hint_screen_texture, filter_linear, repeat_disable;
uniform sampler2D old_frame : filter_linear, repeat_disable;
uniform sampler2D mask_texture : filter_linear, repeat_disable;
uniform bool has_old_frame = false;
uniform float coverage : hint_range(0.0, 1.0) = 0.0;
uniform float softness : hint_range(0.001, 0.1) = 0.075;
uniform bool reverse_mask = false;
uniform int mask_style : hint_range(0, 2) = 0;

vec2 rotate_point(vec2 p, float a) {
	float c = cos(a);
	float s = sin(a);
	return vec2(c * p.x - s * p.y, s * p.x + c * p.y);
}

void fragment() {
	float t = clamp(coverage, 0.0, 1.0);
	vec2 coords = reverse_mask ? vec2(1.0 - UV.x, UV.y) : UV;
	vec3 mask_color = texture(mask_texture, coords).rgb;
	float luminance = dot(mask_color, vec3(0.2126, 0.7152, 0.0722));
	vec2 aspect = vec2(SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x, 1.0);
	vec2 p = (coords - vec2(0.5)) * aspect;
	float radius = length(p);
	if (mask_style == 1) {
		float angle = atan(p.y, p.x);
		float arms = 0.5 + 0.5 * sin(2.0 * angle - radius * 13.0);
		luminance = clamp(radius * 0.52 + arms * 0.46, 0.0, 1.0);
	} else if (mask_style == 2) {
		luminance = clamp(radius * 0.83 + 0.045 * sin(p.x * 19.0 + p.y * 12.0), 0.0, 1.0);
	}
	float cutoff = mix(-0.1, 1.1, t);
	float reveal = 1.0 - smoothstep(cutoff - softness, cutoff + softness, luminance);

	vec2 center = vec2(0.5);
	vec2 old_p = (SCREEN_UV - center) * aspect;
	vec2 new_p = old_p;
	float envelope = sin(3.14159265 * t);
	if (mask_style == 1) {
		// Rotate pixels progressively more near the centre to curl the picture.
		old_p = rotate_point(old_p, envelope * 1.9 * exp(-length(old_p) * 2.0));
		new_p = rotate_point(new_p, -envelope * 1.2 * exp(-length(new_p) * 2.0));
	} else if (mask_style == 0) {
		old_p.x += envelope * 0.065 * sin(old_p.y * 15.0);
		new_p.x -= envelope * 0.045 * sin(new_p.y * 15.0);
	}
	// Outgoing image contracts, incoming image settles back to its normal size.
	old_p *= 1.0 + 0.20 * t;
	new_p *= 1.0 - 0.16 * (1.0 - t);
	vec2 old_uv = old_p / aspect + center;
	vec2 new_uv = new_p / aspect + center;
	// Feather beyond the sampled image rather than exposing a hard rectangular
	// edge. Vary the falloff slightly so the boundary never reads as a frame.
	float edge_distance = min(min(old_uv.x, 1.0 - old_uv.x), min(old_uv.y, 1.0 - old_uv.y));
	float ripple = 0.018 * sin(SCREEN_UV.x * 17.0 + SCREEN_UV.y * 13.0);
	float edge_reveal = (1.0 - smoothstep(-0.08, 0.12, edge_distance + ripple)) * smoothstep(0.0, 0.15, t);
	vec4 incoming = texture(screen_texture, clamp(new_uv, vec2(0.0), vec2(1.0)));
	vec4 outgoing = has_old_frame ? texture(old_frame, clamp(old_uv, vec2(0.0), vec2(1.0))) : incoming;
	COLOR = vec4(mix(outgoing.rgb, incoming.rgb, max(reveal, edge_reveal)), 1.0);
}
