shader_type spatial;
// ПЕСЧАНОЕ МОРЕ — вода в оригинальном облике sand.gdshader.
//
// Идея: море выглядит ТОЧНО как твой песок — тот же свет (тёплый склон к
// солнцу / сиреневая ложбина), та же мега-рябь-«одеяло» (дыхание), та же
// мелкая рябь и тот же двухлепестковый глиттер. Отличий от суши три:
//   • поверхность плоская (нет карты дюн, AO и гребней — они не нужны);
//   • по ней бегут КОЛЬЦА от событий рыбалки: всплеск поплавка, поклёвка,
//     подмотка — расходящиеся волновые пакеты с аналитическим градиентом,
//     как следы в песке ловят солнце своими стенками;
//   • это геометрия уровня воды: disp/height_at дают поплавку высоту.
//
// ЧТО УБРАНО по сравнению с «классической» водой (water_classic.gdshader):
//   • ветровые валы — они убивали облик (фаза поперёк песка, чужая пластика);
//   • глубина/поглощение/прозрачность/пена — морю из песка они не нужны,
//     берег срастается с водой сам, потому что это один и тот же материал.
//
// render_mode — ровно как у песка: diffuse_burley + specular_schlick_ggx,
// шероховатость песочная (0.88..0.62). Солнце рисует шёлк само.

render_mode diffuse_burley, specular_schlick_ggx, blend_mix, depth_draw_never;

// ---- Палитра — ТО ЖЕ, что у песка (оригинал без изменений) ----
uniform vec3 sun_dir = vec3(0.10, 0.26, -0.96); // к солнцу (как у песка)
uniform vec3 sand_sunny : source_color = vec3(0.93, 0.52, 0.30);
uniform vec3 sand_hot : source_color = vec3(1.00, 0.68, 0.36);
uniform vec3 sand_shade : source_color = vec3(0.40, 0.32, 0.52);
uniform vec3 horizon_col : source_color = vec3(0.96, 0.66, 0.55);
uniform vec3 sky_col : source_color = vec3(0.28, 0.24, 0.43);
uniform float fog_distance = 340.0;

// ---- Ветер: один вектор на всю игру (как у песка) ----
uniform vec2 wind_dir = vec2(0.32, -0.95); // нормализуется внутри
uniform float wind_power = 1.0;

// ---- Дыхание моря: мега-рябь песка (слой 2, «одеяло» ~9 м) ----
uniform float mega_amp = 0.055; // амплитуда мега-ряби — как у песка

// ---- Мелкая рябь песка (слой 1, только нормали) ----
uniform float ripple_freq = 2.2;      // плотность гребней поперёк ветра
uniform float ripple_speed = 1.5;     // скорость бега ряби по ветру
uniform float ripple_strength = 0.50; // глубина ряби (влияние на нормаль)
uniform float glitter_amount = 0.16;  // доля блестящих гранул — как у песка

// ---- Кольца событий (всплеск / поклёвка / подмотка) ----
uniform float ring_amp = 0.055;  // м при силе 1.0
uniform float ring_speed = 1.5;  // м/с, скорость фронта
uniform float ring_len = 0.85;   // м, длина волны пакета
uniform float ring_tau = 0.55;   // 1/с, затухание по времени
uniform float ring_w0 = 0.30;    // м, ширина пакета при рождении
uniform float ring_wg = 0.18;    // м/с, расползание ширины
uniform float ring_boost = 1.4;  // крутизна нормалей колец (художественный)

uniform float u_time = 0.0;
// Мягкий урез: вода растворяется над песком по разнице глубин сцены.
// Это убирает жёсткую (и рваную на треугольниках) линию пересечения.
uniform float shore_fade = 0.45; // м глубины, на которых вода прозрачна
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
// Карта уреза (shore_x(z)), строится в Coast: вода гаснет по РАССТОЯНИЮ
// до линии песка, а не по глубине сцены — на скользящем ракурсе depth
// не даёт мягкой кромки, а эта карта даёт.
uniform sampler2D shore_lut : filter_linear, repeat_disable;
uniform float shore_z0 = -460.0;
uniform float shore_z1 = 460.0;
uniform vec4 u_rings[24]; // x, z, t0, amp; amp <= 0.0005 — слот пуст

varying vec3 w_pos;

const float PI_2 = 6.28318530718;

// ---- детерминированный хеш и value-noise (ТЕ ЖЕ, что у песка) ----
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

// Фаза мега-ряби (слой 2 песка): одинакова в vertex (высота) и fragment
// (нормаль). Формула и коэффициенты — 1:1 из sand.gdshader; единственное
// отличие — u_time вместо TIME: время пушит WaterField, чтобы CPU-зеркало
// (физика поплавка) жило в той же фазе, что и картинка.
float mega_phase(vec2 wp, vec2 wdir, vec2 wperp) {
	float u = dot(wp, wdir);
	float v = dot(wp, wperp);
	float rn = vnoise(wp * 0.15);
	float rn2 = vnoise(wp * 0.07 + vec2(9.1, 3.3)); // вторая октава варпа
	return v * 0.70 + u * 0.16 + rn * 2.6 + rn2 * 3.4 + u_time * 0.25;
}

void vertex() {
	w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// дыхание моря — НАСТОЯЩАЯ геометрия (как мега-рябь у песка):
	// «одеяло» ~9 м медленно приподнимается и опускается
	vec2 wdir_v = normalize(wind_dir);
	vec2 wperp_v = vec2(-wdir_v.y, wdir_v.x);
	float mph = mega_phase(w_pos.xz, wdir_v, wperp_v);
	float hrip = (cos(mph) * 0.62 + cos(mph * 2.63 + 1.7) * 0.30
		+ cos(mph * 0.47 + 0.8) * 0.22) * mega_amp * wind_power;
	VERTEX.y += hrip;
	w_pos.y += hrip;
}

void fragment() {
	vec2 wp = w_pos.xz;
	vec2 wdir = normalize(wind_dir);
	vec2 wperp = vec2(-wdir.y, wdir.x);
	float u = dot(wp, wdir);  // вдоль ветра
	float v = dot(wp, wperp); // поперёк ветра

	vec3 L = normalize(sun_dir);
	vec3 N = vec3(0.0, 1.0, 0.0); // у моря нет нормали дюн — только слои ниже

	// Дистанция до фрагмента: мелкая деталь гаснет с расстоянием,
	// чтобы море оставалось шелковистым, а не рябило муаром (как у песка).
	float dist = length(CAMERA_POSITION_WORLD - w_pos);
	float detail = exp(-dist * 0.030);

	// Расстояние до настоящей линии уреза (карта берега из Coast).
	// shallow: 1 — на суше, 0 — в открытом море. У кромки вода обязана
	// гаснуть и «песочнеть», иначе над песком висит светлая лента.
	float zt = clamp((w_pos.z - shore_z0) / (shore_z1 - shore_z0), 0.0, 1.0);
	float shore_xw = texture(shore_lut, vec2(zt, 0.5)).r;
	float shore_dx = w_pos.x - shore_xw;
	float shallow = 1.0 - smoothstep(-2.6, 0.4, shore_dx);

	// ---------- слой 2: мега-рябь («дыхание»-одеяло) ----------
	// Нормаль геометрической мега-ряби — та же фаза, что в vertex.
	float mph = mega_phase(wp, wdir, wperp);
	float ms1 = sin(mph);
	float ms2 = sin(mph * 2.63 + 1.7);
	float ms3 = sin(mph * 0.47 + 0.8);
	float mdv = (-0.62 * 0.70 * ms1 - 0.30 * 2.63 * 0.70 * ms2 - 0.22 * 0.47 * 0.70 * ms3) * mega_amp;
	float mdu = (-0.62 * 0.16 * ms1 - 0.30 * 2.63 * 0.16 * ms2 - 0.22 * 0.47 * 0.16 * ms3) * mega_amp;
	vec2 mgrad = (wperp * mdv + wdir * mdu) * wind_power;
	N = normalize(N - vec3(mgrad.x, 0.0, mgrad.y));

	// ---------- слой 1: мелкая рябь песка ----------
	// Гребни вытянуты вдоль ветра, рисунок медленно бежит по ветру.
	float n1 = vnoise(wp * 0.33);
	float n2 = vnoise(wp * 0.9 + vec2(17.0, 9.0));
	float ph1 = v * ripple_freq + u * 0.22 + n1 * 4.2 + u_time * ripple_speed;
	float ph2 = v * ripple_freq * 2.63 + u * 0.55 + n2 * 3.4 + u_time * ripple_speed * 1.6;
	float c1 = cos(ph1) * 0.62;
	float c2 = cos(ph2) * 0.38;
	// лёгкое самозатенение: ложбинки ряби чуть темнее гребней
	float rshade = clamp(0.5 + 0.45 * (c1 + c2), 0.0, 1.0);
	// аналитический градиент волны по осям (v, u) -> возмущение нормали
	float dv = (c1 * ripple_freq + c2 * ripple_freq * 2.63) * ripple_strength * wind_power;
	float du = (c1 * 0.22 + c2 * 0.55) * ripple_strength * wind_power * 2.0;
	vec2 grad = (wperp * dv + wdir * du) * detail;
	N = normalize(N - vec3(grad.x, 0.0, grad.y) * 0.5);

	// ---------- кольца событий: расходящиеся пакеты ----------
	// Единственный «водный» слой: всплеск поплавка, поклёвка, подмотка.
	// Работает как следы в песке — нормали ловят солнце стенками пакета.
	float rk = PI_2 / ring_len;
	vec2 rgrad = vec2(0.0);
	for (int i = 0; i < 24; i++) {
		vec4 rg = u_rings[i];
		if (rg.w < 0.0005) {
			continue;
		}
		float age = u_time - rg.z;
		if (age < 0.0) {
			continue;
		}
		vec2 d = wp - rg.xy;
		float dd = max(length(d), 0.0001);
		float rf = ring_speed * age;
		float bw = ring_w0 + ring_wg * age;
		float x = (dd - rf) / bw;
		float env = exp(-x * x);
		float ph = rk * (dd - rf);
		float dec = exp(-age * ring_tau) / sqrt(max(rf, 0.6));
		float a = ring_amp * rg.w * dec;
		// dh/ddist: производная пакета env*cos по радиусу
		float dhdd = a * (env * (-2.0 * x / bw) * cos(ph) - env * sin(ph) * rk);
		rgrad += (d / dd) * dhdd;
	}
	N = normalize(N - vec3(rgrad.x * ring_boost, 0.0, rgrad.y * ring_boost));

	// ---------- Свет: та же модель, что у песка ----------
	// У моря нет дюн, поэтому crest/hollow/AO = покой (0/0/1), а весь
	// рельеф делают нормали мега-ряби и ряби: тёплый склон к солнцу,
	// сиреневая ложбина — тот самый ключевой мотив.
	float ndl = dot(N, L);
	float wrap = clamp((ndl + 0.45) / 1.05, 0.0, 1.0);
	vec3 base = mix(sand_shade, sand_sunny, smoothstep(0.0, 0.68, wrap));
	base = mix(base, sand_hot, pow(wrap, 2.0) * 0.35);
	// солнечная кромка: склоны, отвесные к солнцу, светятся изнутри
	base += vec3(1.0, 0.62, 0.34) * pow(clamp(ndl, 0.0, 1.0), 2.2) * 0.16;
	// заливка неба: сиреневая прохлада на теневых склонах
	base += sand_shade * clamp(N.y, 0.0, 1.0) * 0.22 * (1.0 - wrap);
	// отблеск «берега»: тёплый свет, отскочивший от соседних дюн
	vec3 B = normalize(vec3(-L.x, 0.55, -L.z));
	base += vec3(1.00, 0.58, 0.32) * clamp(dot(N, B), 0.0, 1.0) * 0.28 * (1.0 - wrap * 0.6);
	// крупный тональный шум: море не однотонное
	base *= mix(0.92, 1.07, vnoise(wp * 0.013 + vec2(3.1, 7.7)));
	// рябь самозатеняется, песчинки дают видимое зерно
	base *= 1.0 - 0.06 * (1.0 - rshade) * detail;
	base *= 1.0 + (vnoise(wp * 2.7) - 0.5) * 0.08 * detail;

	// ---------- Глиттер (микрофасеты, по мотивам Zucconi) — 1:1 из песка ----------
	// ДВА лба: солнечный (half-vector) и небесный (зерно ловит САМУ КАМЕРУ).
	vec3 V = normalize(CAMERA_POSITION_WORLD - w_pos);
	vec3 H = normalize(V + L);
	// LOD «мип-уровнями»: плотность меняется СТУПЕНЯМИ (3·2^k клеток/м) —
	// сетка прибита к миру, блёстки не «плывут» при движении камеры.
	float need = 900.0 / max(dist, 0.001);
	float density = clamp(pow(2.0, floor(log2(need / 3.0))) * 3.0, 6.0, 130.0);
	vec2 celluv = floor(wp * density);
	float cellid = hash12(celluv);
	float cellb = hash12(celluv + vec2(7.31, 1.77));
	float cellc = fract(cellid * 13.7);
	// «зеркало» гранулы: ВЕРХНЯЯ полусфера, азимут равномерный
	vec3 G = normalize(vec3(cellid - 0.5, 0.05 + 0.95 * cellb, cellc - 0.5));
	// солнечный блик (half-vector, шевелится от зерна к зерну)
	vec3 Hg = normalize(H + vec3(cellid - 0.5, cellb - 0.5, cellc - 0.5) * 0.55);
	float sun_lobe = pow(clamp(dot(N, Hg), 0.0, 1.0), mix(22.0, 80.0, cellb));
	// небесный блик: зерно поймало взгляд — работает в ЛЮБОМ направлении
	float sky_lobe = pow(clamp(dot(G, V), 0.0, 1.0), mix(20.0, 70.0, cellc));
	// вдаль искр меньше — далеко не «ковёр», а редкие вспышки
	float glint = step(1.0 - glitter_amount * exp(-dist * 0.0035), cellid);
	float rate = mix(2.0, 8.0, cellb);
	glint *= 0.40 + 0.60 * (0.5 + 0.5 * sin(u_time * rate + cellid * 71.0));
	float glit_fade = exp(-dist * 0.004); // искры живут до горизонта
	glit_fade *= 1.0 - shallow; // у берега искр нет: там мелководье, а не гладь
	base += vec3(1.0, 0.92, 0.70) * (sun_lobe * 2.0 + sky_lobe * 2.2)
		* glint * glit_fade;
	// шёлковый отблеск с ФРЕНЕЛЕМ: под скользящим взглядом поверхность
	// «мокро» блестит — у песчаного моря это выглядит как солнечная дорожка
	float near_gloss = exp(-dist * 0.012);
	float fres = 0.35 + 0.65 * pow(1.0 - clamp(dot(N, V), 0.0, 1.0), 3.0);
	float sheen = pow(clamp(dot(N, H), 0.0, 1.0), 16.0) * 0.7
		+ pow(clamp(dot(N, H), 0.0, 1.0), 48.0) * 0.3;
	base += vec3(1.0, 0.72, 0.45) * sheen * fres * 0.22 * near_gloss
		* smoothstep(0.0, 0.5, wrap) * (1.0 - shallow);
	// скользящий ракурс: ближняя кромка слегка рдеет
	base += vec3(0.90, 0.55, 0.35) * (fres - 0.35) * 0.22 * near_gloss * (1.0 - shallow);
	// прохладная наплыв: море всё-таки вода, а не песок — иначе урез не читается
	base = mix(base, base * vec3(0.74, 0.86, 1.02) + vec3(0.02, 0.05, 0.09), 0.35);
	// мелководье: тонкая вода на песке — темнее, матовее, без бликов
	base = mix(base, base * vec3(0.40, 0.33, 0.27), shallow * 0.92);

	// ---------- Дымка к горизонту — та же, что у песка ----------
	float fog = 1.0 - exp(-pow(dist / fog_distance, 2.1));
	float above = smoothstep(-2.0, 16.0, w_pos.y - CAMERA_POSITION_WORLD.y);
	vec3 fcol = mix(horizon_col, sky_col, above * 0.6);

	ALBEDO = mix(base, fcol, fog);
	NORMAL = normalize((VIEW_MATRIX * vec4(N, 0.0)).xyz);
	// вода глаже песка: длинная солнечная дорожка читается как жидкость
	ROUGHNESS = mix(mix(0.68, 0.40, clamp(fres, 0.0, 1.0)), 0.94, shallow);
	SPECULAR = mix(0.42, 0.06, shallow);
	METALLIC = 0.0;

	// ---- Мягкий урез ----
	// 1) та же линия уреза, с поправкой на накат: кромка ползёт по пляжу
	float swash_h = (cos(mph) * 0.62 + cos(mph * 2.63 + 1.7) * 0.30
		+ cos(mph * 0.47 + 0.8) * 0.22) * mega_amp * wind_power;
	float lift = swash_h / 0.062; // насколько накат сдвинул кромку по пляжу
	float dx = shore_dx - lift; // >0 — суша, <0 — море
	// в открытом море alpha 1; у самой кромки — полупрозрачная тёмная вода
	float shore_a = (1.0 - smoothstep(-1.5, 0.12, dx)) * (1.0 - 0.45 * shallow);
	// 2) мягкое пересечение с любыми предметами (depth-буфер сцены)
	float sd = texture(depth_tex, SCREEN_UV).r;
	vec4 ndc = vec4(SCREEN_UV * 2.0 - 1.0, sd, 1.0);
	vec4 vp = INV_PROJECTION_MATRIX * ndc;
	vp.xyz /= vp.w;
	float scene_z = -vp.z;
	float water_z = -VERTEX.z;
	float obj_a = smoothstep(0.0, shore_fade, scene_z - water_z);
	ALPHA = min(shore_a, obj_a);
}
