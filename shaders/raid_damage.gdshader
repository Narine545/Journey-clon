// Reactive adaptation of the user-provided canvas glitch idea: slices, RGB offsets, scanlines/noise.
// Screen pixels rather than TEXTURE; no periodic activation, negative image or global glow.
shader_type canvas_item;
render_mode unshaded;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform float effect_age = 0.0;

float hash_value(vec2 point) {
	return fract(sin(dot(point, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 pixel = SCREEN_PIXEL_SIZE;
	vec2 original_uv = SCREEN_UV;
	vec2 uv = original_uv;
	float frame = floor(effect_age * 30.0);
	float slice = floor(uv.y * 28.0);
	float seed = hash_value(vec2(slice, frame));
	float active_slice = step(0.82, seed);
	// At the strongest configured hit: <= 3.6 horizontal pixels, no vertical jump.
	uv.x += (seed - 0.5) * 12.0 * pixel.x * intensity * active_slice;
	uv.x += sin(uv.y * 100.0 + frame) * pixel.x * intensity;
	uv = clamp(uv, pixel, vec2(1.0) - pixel);
	float shift = 5.0 * pixel.x * intensity;
	vec3 base = textureLod(screen_texture, uv, 0.0).rgb;
	float red = textureLod(screen_texture, clamp(uv + vec2(shift, 0.0), pixel, vec2(1.0) - pixel), 0.0).r;
	float blue = textureLod(screen_texture, clamp(uv - vec2(shift, 0.0), pixel, vec2(1.0) - pixel), 0.0).b;
	vec3 result = vec3(red, base.g, blue);
	float scanline = sin(original_uv.y / pixel.y * 3.141593) * 0.5 + 0.5;
	result *= 1.0 - scanline * 0.06 * intensity;
	float grain = hash_value(floor(original_uv / pixel) + vec2(frame)) - 0.5;
	result += grain * 0.05 * intensity;
	COLOR = vec4(max(result, vec3(0.0)), 1.0);
}
