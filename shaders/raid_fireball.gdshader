// Noise adapted from FIREBALL SHADER by Muhammad Mujtaba, MIT License.
// https://godotshaders.com/shader/fireball-or-candle-fire-shader/
// Copyright (c) Muhammad Mujtaba
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;
uniform float effect_time = 0.0;

vec2 random2(vec2 st, float seed) {
	st = vec2(dot(st, vec2(127.1, 311.7)), dot(st, vec2(269.5, 183.3)));
	return -1.0 + 2.0 * fract(sin(st) * 43758.5453123 * seed * 0.753421);
}
float fire_noise(vec2 st, float seed) {
	vec2 i = floor(st);
	vec2 f = fract(st);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(dot(random2(i, seed), f), dot(random2(i + vec2(1, 0), seed), f - vec2(1, 0)), u.x),
		mix(dot(random2(i + vec2(0, 1), seed), f - vec2(0, 1)),
		dot(random2(i + vec2(1, 1), seed), f - vec2(1, 1)), u.x), u.y);
}
void fragment() {
	vec2 p = vec2(UV.x, UV.y * 2.0 - 1.0);
	vec2 flow = vec2(p.x * 5.0 + effect_time * 9.0, p.y * 2.2);
	float noise = fire_noise(flow, 24.0) * 0.5
		+ fire_noise(flow * 2.0, 12.0) * 0.25
		+ fire_noise(flow * 4.0, 33.0) * 0.125;
	float head = 1.0 - smoothstep(0.12, 0.29, length(vec2((p.x - 0.75) * 2.4, p.y)));
	float tail_width = mix(0.02, 0.38, smoothstep(0.04, 0.70, p.x));
	float tail = (1.0 - smoothstep(tail_width * 0.3, tail_width, abs(p.y + noise * 0.18)))
		* smoothstep(0.02, 0.32, p.x) * (1.0 - smoothstep(0.70, 0.84, p.x));
	float flame = clamp(max(head, tail * clamp(0.65 + noise, 0.15, 1.0)), 0.0, 1.0);
	float core = head * (1.0 - smoothstep(0.0, 0.17, abs(p.y)));
	ALBEDO = mix(vec3(1.0, 0.16, 0.025), vec3(1.0, 0.78, 0.25), clamp(core + tail * 0.35, 0.0, 1.0));
	EMISSION = ALBEDO * flame * 0.45;
	ALPHA = flame * 0.92;
}
