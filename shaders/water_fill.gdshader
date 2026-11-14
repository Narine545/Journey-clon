shader_type canvas_item;
render_mode blend_mix;

// TIDECUT · HP = осадка корпуса.
// Вода поднимается по силуэту лодки снизу вверх, поверхность живая (синус),
// при опасности вода пульсирует flare. Всё плоско: три цвета и одна линия.

uniform vec4 hull_color : source_color = vec4(0.051, 0.082, 0.125, 1.0);
uniform vec4 water_color : source_color = vec4(0.208, 0.816, 0.729, 1.0);
uniform vec4 crest_color : source_color = vec4(0.937, 0.918, 0.847, 1.0);
uniform vec4 danger_color : source_color = vec4(0.890, 0.129, 0.180, 1.0);
uniform vec4 hatch_color : source_color = vec4(0.937, 0.918, 0.847, 1.0);
uniform vec2 poly_size = vec2(420.0, 210.0); // размер силуэта в пикселях

// Полигон не имеет текстуры, поэтому UV пустой: локальную координату
// передаём из вершинного шейдера как varying.
varying vec2 local;
uniform float fill : hint_range(0.0, 1.0) = 0.3;
uniform float danger : hint_range(0.0, 1.0) = 0.0;
uniform float wave_amp = 4.5;
uniform float wave_speed = 1.7;
uniform float hatch_step = 7.0;

void vertex() {
	local = VERTEX;
}

void fragment() {
	vec2 uv = local; // пиксели внутри силуэта
	float surface = mix(poly_size.y - 4.0, 4.0, clamp(fill, 0.0, 1.0));
	float wave = sin(uv.x * 0.055 + TIME * wave_speed) * wave_amp
		+ sin(uv.x * 0.021 - TIME * wave_speed * 0.7) * wave_amp * 0.55;
	surface += wave;
	float in_water = step(surface, uv.y);

	vec3 color = mix(hull_color.rgb, water_color.rgb, in_water);

	// Гравюрная штриховка на сухой части корпуса.
	float hatch = step(0.5, fract((uv.x + uv.y) / max(2.0, hatch_step)));
	color = mix(color, hatch_color.rgb, hatch * (1.0 - in_water) * 0.22);

	// Пенная кромка ватерлинии.
	float crest = 1.0 - smoothstep(0.0, 2.4, abs(uv.y - surface));
	color = mix(color, mix(crest_color.rgb, danger_color.rgb, danger), crest);

	// Опасная осадка: вода краснеет и пульсирует.
	float pulse = 0.5 + 0.5 * sin(TIME * 6.2);
	color = mix(color, danger_color.rgb, in_water * danger * (0.3 + 0.45 * pulse));

	COLOR = vec4(color, 1.0);
}
