shader_type canvas_item;
// Отладочная адаптация «Fears to fathom Shader» (theCube, CC0):
// https://godotshaders.com/shader/fears-to-fathom-shader/
// Виньетка и сканлайны сознательно не перенесены: они уже были отклонены.
// Включается только по [V], не влияет на материалы воды и не покрывает HUD.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float aberration_px : hint_range(0.0, 8.0) = 4.0;
uniform float blur_mix : hint_range(0.0, 0.5) = 0.22;
uniform float grain : hint_range(0.0, 0.12) = 0.06;
uniform float ghost_mix : hint_range(0.0, 0.2) = 0.09;
uniform float desaturate : hint_range(0.0, 1.0) = 0.22;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 texel = 1.0 / vec2(textureSize(screen_tex, 0));
	// Несколько пикселей вдоль радиуса; в отличие от прошлой версии,
	// эффект виден и на обычном экране без сравнения кадров попиксельно.
	vec2 offset = normalize(uv - 0.5 + vec2(0.00001)) * texel *
		aberration_px * smoothstep(0.0, 0.5, length(uv - 0.5));
	vec3 col = vec3(texture(screen_tex, clamp(uv + offset, vec2(0.0), vec2(1.0))).r,
		texture(screen_tex, uv).g,
		texture(screen_tex, clamp(uv - offset, vec2(0.0), vec2(1.0))).b);
	col = mix(col, textureLod(screen_tex, uv, 2.0).rgb, blur_mix);
	col = mix(col, texture(screen_tex, clamp(uv - vec2(texel.x * 5.0, 0.0),
		vec2(0.0), vec2(1.0))).rgb, ghost_mix);
	col = mix(col, vec3(dot(col, vec3(0.2126, 0.7152, 0.0722))), desaturate);
	float noise = (hash21(floor(uv / texel) + floor(TIME * 24.0)) - 0.5) * grain;
	COLOR = vec4(clamp(col + vec3(noise), vec3(0.0), vec3(1.0)), 1.0);
}
