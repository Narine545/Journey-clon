shader_type canvas_item;
render_mode unshaded, blend_mix;

// Luminance-mask transition adapted from null_builds, CC0:
// https://godotshaders.com/shader/luminance-mask-transition/
// The mask is project-authored; cutoff is swept beyond the [0,1] luminance
// range so the endpoints are guaranteed fully transparent / fully covered.
uniform sampler2D mask_texture : filter_linear, repeat_disable;
uniform vec4 ink : source_color = vec4(0.051, 0.082, 0.125, 1.0);
uniform float coverage : hint_range(0.0, 1.0) = 0.0;
uniform float softness : hint_range(0.001, 0.1) = 0.035;
uniform bool reverse_mask = false;

void fragment() {
	vec2 coords = reverse_mask ? vec2(1.0 - UV.x, UV.y) : UV;
	vec3 mask_color = texture(mask_texture, coords).rgb;
	float luminance = dot(mask_color, vec3(0.2126, 0.7152, 0.0722));
	float cutoff = mix(-0.1, 1.1, clamp(coverage, 0.0, 1.0));
	float alpha = 1.0 - smoothstep(cutoff - softness, cutoff + softness, luminance);
	COLOR = vec4(ink.rgb, ink.a * alpha);
}
