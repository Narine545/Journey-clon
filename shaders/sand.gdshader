shader_type spatial;
render_mode unshaded, fog_disabled;

// =====================================================================
// Шейдер песка — сердце игры.
// По мотивам доклада GDC «Sand Rendering in Journey» и разбора Alan Zucconi.
// Всё считается во фрагменте по мировым координатам — никаких текстур.
// =====================================================================

// ---- Палитра (глава 1: тёплые дюны на закате) ----
uniform vec3 sun_dir = vec3(0.10, 0.26, -0.96); // к солнцу (туда же уходит путь)
uniform vec3 sand_sunny : source_color = vec3(0.93, 0.52, 0.30);
uniform vec3 sand_hot : source_color = vec3(1.00, 0.68, 0.36);
uniform vec3 sand_shade : source_color = vec3(0.40, 0.32, 0.52);
uniform vec3 horizon_col : source_color = vec3(0.96, 0.66, 0.55);
uniform vec3 sky_col : source_color = vec3(0.28, 0.24, 0.43);
uniform float fog_distance = 340.0;

// ---- Ветер: один вектор для ряби и струй ----
uniform vec2 wind_dir = vec2(0.32, -0.95); // нормализуется внутри
uniform float wind_power = 1.0;

uniform float ripple_freq = 2.2;      // плотность гребней поперёк ветра
uniform float ripple_speed = 1.5;     // скорость бега ряби по ветру
uniform float ripple_strength = 0.30; // глубина ряби (влияние на нормаль)
uniform float glitter_amount = 0.045; // доля блестящих песчинок
uniform float streak_amount = 0.32;   // сила ветровых струй

// ---- След путника: карта следов (SubViewport) ----
uniform sampler2D trail_map;
uniform vec4 trail_rect = vec4(-208.0, -468.0, 416.0, 520.0); // x0, z0, w, h (метры)

varying vec3 w_pos;
varying vec3 w_normal;
varying vec2 v_dune; // x — 0..1 высота дюны (приходит из геометрии через UV2)

// ---- детерминированный хеш и value-noise ----
float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	vec3 q = p3.yzx + vec3(33.33);
	p3 += vec3(dot(p3, q));
	return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash12(i);
	float b = hash12(i + vec2(1.0, 0.0));
	float c = hash12(i + vec2(0.0, 1.0));
	float d = hash12(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void vertex() {
	w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	w_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	v_dune = UV2;
}

void fragment() {
	vec2 wp = w_pos.xz;
	vec2 wdir = normalize(wind_dir);
	vec2 wperp = vec2(-wdir.y, wdir.x);
	float u = dot(wp, wdir);  // вдоль ветра
	float v = dot(wp, wperp); // поперёк ветра

	vec3 L = normalize(sun_dir);
	vec3 N = normalize(w_normal);

	// Дистанция до фрагмента: мелкая деталь гаснет с расстоянием,
	// чтобы дюны оставались шелковистыми, а не рябило муаром.
	float dist = length(CAMERA_POSITION_WORLD - w_pos);
	float detail = exp(-dist * 0.030);

	// ---------- 0. След путника ----------
	// Карта следов: 0 — нетронутый песок, 1 — глубоко примято.
	// Вне карты считаем нетронутым (края буфера всегда чистые).
	vec2 tuv = (wp - trail_rect.xy) / trail_rect.zw;
	float in_map = step(0.0, tuv.x) * step(tuv.x, 1.0) * step(0.0, tuv.y) * step(tuv.y, 1.0);
	float press = clamp(texture(trail_map, tuv).r * 1.9, 0.0, 1.0) * in_map;

	// ---------- 1. Рябь от ветра ----------
	// Гребни вытянуты вдоль ветра, рисунок медленно бежит по ветру.
	float n1 = vnoise(wp * 0.33);
	float n2 = vnoise(wp * 0.9 + vec2(17.0, 9.0));
	float ph1 = v * ripple_freq + u * 0.22 + n1 * 4.2 + TIME * ripple_speed;
	float ph2 = v * ripple_freq * 2.63 + u * 0.55 + n2 * 3.4 + TIME * ripple_speed * 1.6;
	float amp1 = 0.62;
	float amp2 = 0.38;
	float c1 = cos(ph1) * amp1;
	float c2 = cos(ph2) * amp2;
	// аналитический градиент волны по осям (v, u) -> возмущение нормали
	float dv = (c1 * ripple_freq + c2 * ripple_freq * 2.63) * ripple_strength * wind_power;
	float du = (c1 * 0.22 + c2 * 0.55) * ripple_strength * wind_power * 2.0;
	vec2 grad = (wperp * dv + wdir * du) * detail;
	// примятый след не рябит: песок уплотнён
	grad *= 1.0 - 0.8 * press;
	N = normalize(N - vec3(grad.x, 0.0, grad.y) * 0.5);

	// ---------- 2. Двухтоновый песок: N*L ----------
	// Склон к солнцу — тёплый, теневой — сиренево-синий. Главный мотив.
	float ndl = dot(N, L);
	float lit = smoothstep(-0.30, 0.62, ndl);
	float crest = smoothstep(0.60, 0.95, v_dune.x);        // гребни дюн
	float hollow = 1.0 - smoothstep(0.10, 0.38, v_dune.x); // ложбины

	vec3 base = mix(sand_shade, sand_sunny, lit);
	base = mix(base, sand_hot, lit * lit * (0.30 + 0.45 * crest));
	// солнечная кромка: склоны, отвесные к солнцу, светятся изнутри
	base += vec3(1.0, 0.62, 0.34) * pow(clamp(ndl, 0.0, 1.0), 2.2) * 0.16;
	// ложбины — холоднее и глубже
	base = mix(base, sand_shade, hollow * 0.25);
	// примятый след: заметная тёмная борозда с холодным отливом
	base = mix(base, base * vec3(0.64, 0.60, 0.74), press * 0.80);
	// крупный тональный шум: дюны не одинаковые
	base *= mix(0.92, 1.07, vnoise(wp * 0.013 + vec2(3.1, 7.7)));

	// ---------- 3. Глиттер ----------
	// Редкие песчинки дают резкий блик: сверкание живёт при движении камеры.
	vec3 V = normalize(CAMERA_POSITION_WORLD - w_pos);
	vec3 H = normalize(V + L);
	float spec = pow(clamp(dot(N, H), 0.0, 1.0), 110.0);
	float cellr = hash12(floor(wp * 9.0));
	float glint = step(1.0 - glitter_amount, cellr);
	glint *= 0.55 + 0.45 * sin(TIME * 9.0 + cellr * 37.0);
	glint *= 1.0 - 0.75 * press; // примятый песок не сверкает
	base += vec3(1.0, 0.88, 0.62) * spec * glint * 2.6 * detail;

	// ---------- 4. Ветровые струи ----------
	// Медленные светящиеся полосы: вытянуты по ветру и тянутся вдоль него.
	float sn1 = vnoise(vec2(u * 0.045 - TIME * 0.85, v * 0.5));
	float sn2 = vnoise(vec2(u * 0.11 - TIME * 1.35 + 40.0, v * 1.05));
	float streak = smoothstep(0.55, 0.92, sn1 * 0.65 + sn2 * 0.35);
	base += vec3(1.0, 0.80, 0.55) * streak * streak_amount * wind_power * (0.35 + 0.65 * lit);

	// ---------- 5. Дымка к горизонту ----------
	float fog = 1.0 - exp(-pow(dist / fog_distance, 2.1));
	float above = smoothstep(-2.0, 16.0, w_pos.y - CAMERA_POSITION_WORLD.y);
	vec3 fcol = mix(horizon_col, sky_col, above * 0.6);

	ALBEDO = mix(base, fcol, fog);
}
