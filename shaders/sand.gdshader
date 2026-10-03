shader_type spatial;
render_mode unshaded, fog_disabled;

// =====================================================================
// Шейдер песка — сердце игры.
// По мотивам доклада GDC «Sand Rendering in Journey» и разбора Alan Zucconi.
// Всё считается во фрагменте по мировым координатам — текстур почти нет.
//
// Настоящий песок: карта смещений (R32F, тор) от SandField реально
// изгибает геометрию (vertex) и даёт настоящие нормали (fragment):
// стенки следов ловят солнце, валы выброшенного песка светятся,
// дно следа темнеет и холоднеет. Никаких «нарисованных» следов.
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

// ---- Настоящий песок: карта смещений ----
uniform sampler2D sand_map : filter_linear, repeat_enable;
uniform vec2 sand_origin = vec2(0.0, 0.0); // мировой угол окна карты (x, z)
uniform float sand_texel = 0.12;           // метров на тексель
uniform float sand_edge = 40.0;            // текселей мягкого заноса у края окна

varying vec3 w_pos;
varying vec3 w_normal;
varying vec2 v_dune; // x — 0..1 высота дюны (приходит из геометрии через UV2)

const float SAND_N = 800.0; // сторона карты в текселях

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

// Смещение песка в мировой точке. Карта — тор: глобальные тексельные
// координаты заворачиваются mod(N), REPEAT склеивает шов. У края окна
// след плавно «заносится ветром» (за окном песок нетронут).
float sand_h(vec2 wp) {
	vec2 g = wp / sand_texel;               // глобальные непрерывные тексели
	vec2 l = g - sand_origin / sand_texel;  // локальные в окне [0..N]
	vec2 uv = (mod(floor(g), SAND_N) + fract(g)) / SAND_N;
	float m = min(min(l.x, l.y), SAND_N - max(l.x, l.y)); // текселей до края
	float edge = smoothstep(0.0, sand_edge, m);
	return texture(sand_map, uv).r * edge;
}

void vertex() {
	w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// песок реально проминается: смещаем вершину по карте
	float h = sand_h(w_pos.xz);
	VERTEX.y += h;
	w_pos.y += h;
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

	// ---------- 0. Настоящий песок: карта смещений ----------
	// Градиент карты — это настоящий рельеф: стенки следов и валы.
	float t = sand_texel;
	float h = sand_h(wp);
	float hx1 = sand_h(wp + vec2(t, 0.0));
	float hx0 = sand_h(wp - vec2(t, 0.0));
	float hz1 = sand_h(wp + vec2(0.0, t));
	float hz0 = sand_h(wp - vec2(0.0, t));
	vec2 sgrad = vec2(hx1 - hx0, hz1 - hz0) / (2.0 * t);
	float churn = clamp(abs(h) * 10.0, 0.0, 1.0); // потревоженный песок
	N = normalize(N - vec3(sgrad.x, 0.0, sgrad.y));

	// ---------- 1. Рябь от ветра ----------
	// Гребни вытянуты вдоль ветра, рисунок медленно бежит по ветру.
	// На потревоженном песке рябь стирается (песок перепахан).
	float n1 = vnoise(wp * 0.33);
	float n2 = vnoise(wp * 0.9 + vec2(17.0, 9.0));
	float ph1 = v * ripple_freq + u * 0.22 + n1 * 4.2 + TIME * ripple_speed;
	float ph2 = v * ripple_freq * 2.63 + u * 0.55 + n2 * 3.4 + TIME * ripple_speed * 1.6;
	float amp1 = 0.62;
	float amp2 = 0.38;
	float c1 = cos(ph1) * amp1;
	float c2 = cos(ph2) * amp2;
	// лёгкое самозатенение: ложбинки ряби чуть темнее гребней
	float rshade = clamp(0.5 + 0.45 * (c1 + c2), 0.0, 1.0);
	// аналитический градиент волны по осям (v, u) -> возмущение нормали
	float dv = (c1 * ripple_freq + c2 * ripple_freq * 2.63) * ripple_strength * wind_power;
	float du = (c1 * 0.22 + c2 * 0.55) * ripple_strength * wind_power * 2.0;
	vec2 grad = (wperp * dv + wdir * du) * detail;
	grad *= 1.0 - 0.75 * churn; // вытоптанный песок не рябит
	N = normalize(N - vec3(grad.x, 0.0, grad.y) * 0.5);

	// ---------- 2. Свет: солнце + небо + отблеск (три источника) ----------
	// Главный мотив тот же (тёплый склон к солнцу / сиреневая тень),
	// но тень теперь живая: сверху её заливает сиреневое небо,
	// снизу греет тёплый отблеск, отскочивший от соседних дюн.
	float ndl = dot(N, L);
	float crest = smoothstep(0.60, 0.95, v_dune.x);        // гребни дюн
	float hollow = 1.0 - smoothstep(0.10, 0.38, v_dune.x); // ложбины

	// ключевой свет: солнце с мягким переносом через кромку (wrap)
	float wrap = clamp((ndl + 0.30) / 1.30, 0.0, 1.0);
	vec3 base = mix(sand_shade, sand_sunny, smoothstep(0.0, 0.82, wrap));
	base = mix(base, sand_hot, pow(wrap, 2.0) * (0.30 + 0.45 * crest));
	// солнечная кромка: склоны, отвесные к солнцу, светятся изнутри
	base += vec3(1.0, 0.62, 0.34) * pow(clamp(ndl, 0.0, 1.0), 2.2) * 0.16;
	// заливка неба: сиреневая прохлада ложится на теневые склоны
	base += sand_shade * clamp(N.y, 0.0, 1.0) * 0.42 * (1.0 - wrap);
	// отблеск песка: тёплый свет, отскочивший от дюн, подсвечивает тень
	vec3 B = normalize(vec3(-L.x, 0.55, -L.z));
	base += vec3(0.95, 0.50, 0.30) * clamp(dot(N, B), 0.0, 1.0) * 0.20 * (1.0 - wrap * 0.7);
	// ложбины — холоднее и глубже
	base = mix(base, sand_shade, hollow * 0.25);
	// крупный тональный шум: дюны не одинаковые
	base *= mix(0.92, 1.07, vnoise(wp * 0.013 + vec2(3.1, 7.7)));
	// рябь самозатеняется, песчинки дают видимое зерно
	base *= 1.0 - 0.06 * (1.0 - rshade) * detail * (1.0 - 0.5 * churn);
	base *= 1.0 + (vnoise(wp * 2.7) - 0.5) * 0.08 * detail;

	// ---------- 2b. След: настоящий рельеф красится как настоящий ----------
	float press = clamp(-h * 12.0, 0.0, 1.0); // дно следа
	float rise = clamp(h * 18.0, 0.0, 1.0);   // вал выброшенного песка
	// дно: темнее и холоднее (песок уплотнён и в тени собственной стенки)
	base = mix(base, base * vec3(0.60, 0.56, 0.72), press * 0.75);
	// вал: свежий сухой песок — светлее и теплее
	base = mix(base, base * vec3(1.18, 1.07, 0.88), rise * 0.5);

	// ---------- 3. Глиттер (микрофасеты, по мотивам Zucconi) ----------
	// «Песчинки» размером с пиксель: плотность клеток падает с дистанцией
	// пропорционально пиксельному следу — вблизи зерно ~5 мм, вдали не
	// мельче пикселя. Ни гигантских бликов, ни стробинга, а сверкание
	// видно по всему склону, а не только под заветным углом.
	vec3 V = normalize(CAMERA_POSITION_WORLD - w_pos);
	vec3 H = normalize(V + L);
	float density = clamp(1000.0 / max(dist, 0.001), 22.0, 200.0);
	vec2 celluv = floor(wp * density);
	float cellid = hash12(celluv);
	float cellb = hash12(celluv + vec2(7.31, 1.77));
	// у каждой песчинки своё «зеркало» (стабильно во времени) и свой блеск
	vec3 Hg = normalize(H + vec3(cellid - 0.5, cellb - 0.5, fract(cellid * 7.0) - 0.5) * 0.55);
	float spec = pow(clamp(dot(N, Hg), 0.0, 1.0), mix(28.0, 110.0, cellb));
	float glint = step(1.0 - glitter_amount, cellid);
	float rate = mix(2.0, 8.0, cellb);
	glint *= 0.40 + 0.60 * (0.5 + 0.5 * sin(TIME * rate + cellid * 71.0));
	glint *= 1.0 - 0.85 * churn; // потревоженный песок почти не сверкает
	float glit_fade = exp(-dist * 0.008); // искры живут далеко, до горизонта
	base += vec3(1.0, 0.88, 0.62) * spec * glint * 1.8 * glit_fade;
	// широкий шёлковый отблеск («океанский» спекуляр — песок как жидкость)
	float sheen = pow(clamp(dot(N, H), 0.0, 1.0), 16.0);
	base += vec3(1.0, 0.72, 0.45) * sheen * 0.11 * smoothstep(0.0, 0.5, wrap) * (1.0 - churn * 0.5);

	// ---------- 4. Ветровые струи ----------
	// Медленные светящиеся полосы: вытянуты по ветру и тянутся вдоль него.
	float sn1 = vnoise(vec2(u * 0.045 - TIME * 0.85, v * 0.5));
	float sn2 = vnoise(vec2(u * 0.11 - TIME * 1.35 + 40.0, v * 1.05));
	float streak = smoothstep(0.55, 0.92, sn1 * 0.65 + sn2 * 0.35);
	base += vec3(1.0, 0.80, 0.55) * streak * streak_amount * wind_power * (0.35 + 0.65 * smoothstep(0.0, 0.5, wrap));

	// ---------- 5. Дымка к горизонту ----------
	float fog = 1.0 - exp(-pow(dist / fog_distance, 2.1));
	float above = smoothstep(-2.0, 16.0, w_pos.y - CAMERA_POSITION_WORLD.y);
	vec3 fcol = mix(horizon_col, sky_col, above * 0.6);

	ALBEDO = mix(base, fcol, fog);
}
