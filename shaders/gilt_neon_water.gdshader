shader_type spatial;
render_mode cull_disabled;

// «Золочёный прилив» · вода фонтана и неоновые надписи.
// Плоская поверхность, по которой бегут полосы-волны: днём это тёмная
// эмаль с холодным блеском, ночью — бирюзовый/розовый неон. Анимация
// медленная (0.7 Гц основы), чтобы это читалось как «жидкость», а не как
// мигающая лампочка. Никаких текстур: всё считается из UV и TIME.

uniform vec4 ink : source_color = vec4(0.043, 0.078, 0.106, 1.0);
uniform vec4 glow : source_color = vec4(0.384, 1.0, 0.902, 1.0);
uniform float night01 : hint_range(0.0, 1.0) = 0.0;
uniform float pulse_speed = 0.7;
uniform float stripes = 26.0;
uniform float brightness = 1.0;

void fragment() {
	float t = TIME * pulse_speed;
	vec2 uv = UV;
	// Две волны разной частоты: одна бежит вдоль, вторая «дышит» поперёк.
	float wave = sin(uv.y * stripes + t * 3.0 - sin(uv.x * 7.0 + t * 0.8) * 1.7);
	float breath = sin(uv.x * 3.4 - t * 1.3) * 0.5 + 0.5;
	float band = smoothstep(0.45, 1.0, wave) * (0.55 + 0.45 * breath);
	vec3 color = mix(ink.rgb, glow.rgb, band * (0.35 + 0.5 * night01));
	ALBEDO = color;
	EMISSION = glow.rgb * band * (0.20 + 0.85 * night01) * brightness;
	ROUGHNESS = mix(0.22, 0.55, band);
	METALLIC = 0.35;
}
