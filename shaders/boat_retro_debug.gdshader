shader_type canvas_item;
// Отладочный вариант по мотивам «Fears to fathom Shader» (theCube, CC0):
// https://godotshaders.com/shader/fears-to-fathom-shader/
// Не переносим виньетку, сканлайны и искажение волн: пользователь их убрал.
// Эффект работает ТОЛЬКО по [V] и не затрагивает HUD/материалы мира.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float aberration : hint_range(0.0, 2.0) = 0.55;
uniform float blur_mix : hint_range(0.0, 0.5) = 0.08;
uniform float grain : hint_range(0.0, 0.05) = 0.014;
uniform float ghost_mix : hint_range(0.0, 0.1) = 0.025;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 texel = 1.0 / vec2(textureSize(screen_tex, 0));
	vec2 offset = (uv - 0.5) * texel * aberration * 2.0;
	vec3 col = vec3(texture(screen_tex, clamp(uv + offset, vec2(0.0), vec2(1.0))).r,
		texture(screen_tex, uv).g,
		texture(screen_tex, clamp(uv - offset, vec2(0.0), vec2(1.0))).b);
	vec3 soft = textureLod(screen_tex, uv, 1.0).rgb;
	col = mix(col, soft, blur_mix);
	col = mix(col, texture(screen_tex, clamp(uv - vec2(texel.x * 2.0, 0.0),
		vec2(0.0), vec2(1.0))).rgb, ghost_mix);
	float noise = (hash21(floor(uv / texel) + floor(TIME * 30.0)) - 0.5) * grain;
	COLOR = vec4(clamp(col + vec3(noise), vec3(0.0), vec3(1.0)), 1.0);
}
