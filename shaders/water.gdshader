shader_type spatial;
// МОРЕ — отдельная стихия рядом с тёплым песком.
//
// Палитра намеренно НЕ песочная: мелководье — бирюза, глубина — синий
// индиго, на закате поверхность ловит тёплый отблеск неба и солнечную
// дорожку. Песок остаётся медово-оранжевым, поэтому суша и вода читаются
// как два разных материала даже на горизонте.
//
// Урез — самая сложная часть. Море знает линию берега из Coast.shore_lut
// и по ней:
//   • гасит вертикальную волну у кромки (иначе вода «протыкает» пляж
//     треугольниками — те самые лоскуты);
//   • растворяет альфу на мелководье — мокрый песок виден сквозь воду,
//     стык получается мягким, без жёсткой линии;
//   • добавляет пену: две бегущие полосы прибоя с рваным шумом, они
//     прикрывают саму границу и читаются как накат.
// Плюс depth-фейд по буферу сцены — вода мягко обтекает пирс и камни.
//
// Кольца событий (всплеск поплавка, поклёвка, подмотка) остались: это
// единственный «водный» слой, который отвечает на действия игрока.

render_mode diffuse_burley, specular_schlick_ggx, blend_mix, depth_draw_always;

// ---- Вода: своя палитра, не песок ----
uniform vec3 water_shallow : source_color = vec3(0.26, 0.60, 0.56);
uniform vec3 water_mid : source_color = vec3(0.10, 0.36, 0.46);
uniform vec3 water_deep : source_color = vec3(0.030, 0.140, 0.280);
uniform vec3 foam_col : source_color = vec3(0.95, 0.92, 0.86);
uniform vec3 sun_col : source_color = vec3(1.0, 0.80, 0.52);
uniform vec3 sun_dir = vec3(0.10, 0.26, -0.96); // к солнцу (как у песка)

// ---- Небо/дымка (общие с песком) ----
uniform vec3 horizon_col : source_color = vec3(0.96, 0.66, 0.55);
uniform vec3 sky_col : source_color = vec3(0.28, 0.24, 0.43);
uniform float fog_distance = 340.0;

// ---- Ветер: один вектор на всю игру ----
uniform vec2 wind_dir = vec2(0.32, -0.95);
uniform float wind_power = 1.0;

// ---- Дыхание моря: та же мега-рябь, что у песка (слой 2, ~9 м) ----
uniform float mega_amp = 0.055;

// ---- Мелкая рябь (только нормали) ----
uniform float ripple_freq = 2.2;
uniform float ripple_speed = 1.5;
uniform float ripple_strength = 0.34;
uniform float glitter_amount = 0.16;

// ---- Кольца событий ----
uniform float ring_amp = 0.055;
uniform float ring_speed = 1.5;
uniform float ring_len = 0.85;
uniform float ring_tau = 0.55;
uniform float ring_w0 = 0.30;
uniform float ring_wg = 0.18;
uniform float ring_boost = 1.4;

uniform float u_time = 0.0;

// ---- Урез ----
uniform sampler2D shore_lut : filter_linear, repeat_disable;
uniform float shore_z0 = -460.0;
uniform float shore_z1 = 460.0;
uniform float beach_slope = 0.062; // уклон пляжа: высота волны → сдвиг кромки
uniform float shore_fade = 0.06;  // м, мягкость стыка с предметами по depth

uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform vec4 u_rings[24]; // x, z, t0, amp; amp <= 0.0005 — слот пуст

varying vec3 w_pos;

const float PI_2 = 6.28318530718;

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

float mega_phase(vec2 wp, vec2 wdir, vec2 wperp) {
	float u = dot(wp, wdir);
	float v = dot(wp, wperp);
	float rn = vnoise(wp * 0.15);
	float rn2 = vnoise(wp * 0.07 + vec2(9.1, 3.3));
	return v * 0.70 + u * 0.16 + rn * 2.6 + rn2 * 3.4 + u_time * 0.25;
}

float swell_of(float mph) {
	return cos(mph) * 0.62 + cos(mph * 2.63 + 1.7) * 0.30
		+ cos(mph * 0.47 + 0.8) * 0.22;
}

float shore_x_at(float z) {
	float zt = clamp((z - shore_z0) / (shore_z1 - shore_z0), 0.0, 1.0);
	return texture(shore_lut, vec2(zt, 0.5)).r;
}

void vertex() {
	w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 wdir_v = normalize(wind_dir);
	vec2 wperp_v = vec2(-wdir_v.y, wdir_v.x);

	// у самой кромки вертикальную волну гасим: иначе она протыкает пляж
	float sx_v = shore_x_at(w_pos.z);
	float inland_v = w_pos.x - sx_v;              // + суша, − море
	float lift_v = swell_of(mega_phase(w_pos.xz, wdir_v, wperp_v))
		* mega_amp * wind_power / beach_slope;
	float edge_v = smoothstep(-3.0, -0.4, inland_v - lift_v);
	float damp = 1.0 - 0.94 * edge_v;

	float hrip = swell_of(mega_phase(w_pos.xz, wdir_v, wperp_v))
		* mega_amp * wind_power;
	VERTEX.y += hrip * damp;
	w_pos.y += hrip * damp;
}

void fragment() {
	vec2 wp = w_pos.xz;
	vec2 wdir = normalize(wind_dir);
	vec2 wperp = vec2(-wdir.y, wdir.x);
	float u = dot(wp, wdir);
	float v = dot(wp, wperp);

	// ---------- где проходит урез ----------
	// Накат двигает кромку по пляжу: та же волна, что в vertex.
	float mph = mega_phase(wp, wdir, wperp);
	float lift = swell_of(mph) * mega_amp * wind_power / beach_slope;
	float dx = (w_pos.x - shore_x_at(w_pos.z)) - lift; // > 0 — суша
	float near_shore = smoothstep(-4.0, 0.0, dx);
	float sea01 = 1.0 - smoothstep(-0.7, 1.0, dx);
	if (dx > 1.1) {
		discard; // море не имеет права лезть на песок выше кромки
	}
	float depth_m = max(-dx, 0.0) * beach_slope + 0.02;
	// тонкая вода у кромки: 0 — прибой на песке, 1 — нормальная глубина
	float thin = smoothstep(0.0, 0.10, depth_m);

	vec3 L = normalize(sun_dir);
	vec3 N = vec3(0.0, 1.0, 0.0);

	float dist = length(CAMERA_POSITION_WORLD - w_pos);
	float detail = exp(-dist * 0.030);

	// ---------- слой 2: дыхание моря ----------
	float ms1 = sin(mph);
	float ms2 = sin(mph * 2.63 + 1.7);
	float ms3 = sin(mph * 0.47 + 0.8);
	float mdv = (-0.62 * 0.70 * ms1 - 0.30 * 2.63 * 0.70 * ms2
		- 0.22 * 0.47 * 0.70 * ms3) * mega_amp;
	float mdu = (-0.62 * 0.16 * ms1 - 0.30 * 2.63 * 0.16 * ms2
		- 0.22 * 0.47 * 0.16 * ms3) * mega_amp;
	vec2 mgrad = (wperp * mdv + wdir * mdu) * wind_power;
	N = normalize(N - vec3(mgrad.x, 0.0, mgrad.y) * 0.72 * (1.0 - 0.70 * near_shore));

	// ---------- слой 1: мелкая рябь ----------
	float n1 = vnoise(wp * 0.33);
	float n2 = vnoise(wp * 0.9 + vec2(17.0, 9.0));
	float ph1 = v * ripple_freq + u * 0.22 + n1 * 4.2 + u_time * ripple_speed;
	float ph2 = v * ripple_freq * 2.63 + u * 0.55 + n2 * 3.4 + u_time * ripple_speed * 1.6;
	float c1 = cos(ph1) * 0.62;
	float c2 = cos(ph2) * 0.38;
	float rshade = clamp(0.5 + 0.45 * (c1 + c2), 0.0, 1.0);
	float dv = (c1 * ripple_freq + c2 * ripple_freq * 2.63) * ripple_strength * wind_power;
	float du = (c1 * 0.22 + c2 * 0.55) * ripple_strength * wind_power * 2.0;
	// рваный ветровой рисунок: амплитуда ряби гуляет по крупному шуму,
	// иначе полосы читаются «кордуроем»
	float amp = 0.45 + 0.55 * vnoise(wp * 0.11 + vec2(3.7, 1.3));
	vec2 grad = (wperp * dv + wdir * du) * detail * amp * (1.0 - 0.65 * near_shore);
	N = normalize(N - vec3(grad.x, 0.0, grad.y) * 0.42);

	// ---------- кольца событий ----------
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
		float dhdd = a * (env * (-2.0 * x / bw) * cos(ph) - env * sin(ph) * rk);
		rgrad += (d / dd) * dhdd;
	}
	N = normalize(N - vec3(rgrad.x * ring_boost, 0.0, rgrad.y * ring_boost));

	// ---------- цвет воды ----------
	// Мелководье — бирюза, глубина — индиго. Никакого песочного тона:
	// граница суши и воды должна читаться даже на скриншоте.
	vec3 base = mix(water_shallow, water_mid, smoothstep(0.0, 4.0, depth_m));
	base = mix(base, water_deep, smoothstep(1.0, 12.0, depth_m));
	// тонкая вода у самой кромки светлее: мокрый песок просвечивает
	base = mix(base, water_shallow * 1.55, near_shore * (0.62 - 0.45 * thin));
	float ndl = clamp(dot(N, L) * 0.5 + 0.5, 0.0, 1.0);
	base *= 0.72 + 0.42 * ndl;
	base *= 0.92 + 0.16 * rshade * detail;

	// солнечные искры — тёплые, как отблеск заката на воде
	vec3 V = normalize(CAMERA_POSITION_WORLD - w_pos);
	vec3 H = normalize(V + L);
	float need = 900.0 / max(dist, 0.001);
	float density = clamp(pow(2.0, floor(log2(need / 3.0))) * 3.0, 6.0, 130.0);
	vec2 celluv = floor(wp * density);
	float cellid = hash12(celluv);
	float cellb = hash12(celluv + vec2(7.31, 1.77));
	float cellc = fract(cellid * 13.7);
	vec3 G = normalize(vec3(cellid - 0.5, 0.05 + 0.95 * cellb, cellc - 0.5));
	vec3 Hg = normalize(H + vec3(cellid - 0.5, cellb - 0.5, cellc - 0.5) * 0.55);
	float sun_lobe = pow(clamp(dot(N, Hg), 0.0, 1.0), mix(30.0, 110.0, cellb));
	float sky_lobe = pow(clamp(dot(G, V), 0.0, 1.0), mix(24.0, 80.0, cellc));
	float glint = step(1.0 - glitter_amount * exp(-dist * 0.0035), cellid);
	// у самой кромки искр нет: там мелководье и пена
	float glit_fade = exp(-dist * 0.004) * (1.0 - 0.92 * near_shore);
	base += sun_col * (sun_lobe * 1.8 + sky_lobe * 0.30) * glint * glit_fade;

	// отражение неба: у горизонта тёплый закат, под ногами — синяя вода
	float fres = pow(1.0 - clamp(dot(N, V), 0.0, 1.0), 4.0);
	vec3 R = reflect(-V, N);
	vec3 refl = mix(horizon_col * 0.82, sky_col * 0.95, clamp(R.y * 3.0, 0.0, 1.0));
	base = mix(base, refl, 0.10 + 0.55 * fres);
	// широкая солнечная дорожка
	float path = pow(clamp(dot(N, H), 0.0, 1.0), 220.0);
	base += sun_col * path * 0.50 * (1.0 - 0.85 * near_shore);

	// ---------- пена прибоя ----------
	// Две полосы: тонкая у самой кромки и вторая — накат чуть мористее.
	float fn = vnoise(vec2(w_pos.x * 0.85 + u_time * 0.12, w_pos.z * 1.55));
	float fn2 = vnoise(vec2(w_pos.x * 3.2 - u_time * 0.38, w_pos.z * 2.35));
	float band1 = exp(-pow((dx + 0.16) / 0.58, 2.0));
	float band2 = exp(-pow((dx + 2.3 + 0.70 * sin(w_pos.z * 0.21 + u_time * 1.15)) / 0.95, 2.0));
	float foam = band1 * smoothstep(0.12, 0.62, fn) * (0.70 + 0.30 * fn2);
	foam += band2 * smoothstep(0.48, 0.86, fn2) * 0.55;
	foam *= smoothstep(0.0, 0.55, -dx + 0.9); // на сухом песке пены нет
	foam = clamp(foam, 0.0, 1.0);
	base = mix(base, foam_col * (0.72 + 0.28 * ndl), foam * 0.92);

	// ---------- дымка к горизонту ----------
	float fog = 1.0 - exp(-pow(dist / fog_distance, 2.1));
	float above = smoothstep(-2.0, 16.0, w_pos.y - CAMERA_POSITION_WORLD.y);
	vec3 fcol = mix(horizon_col, sky_col, above * 0.6);
	ALBEDO = mix(base, fcol, fog);

	NORMAL = normalize((VIEW_MATRIX * vec4(N, 0.0)).xyz);
	float rough = mix(0.30, 0.72, near_shore);
	ROUGHNESS = mix(rough, 0.86, foam);
	SPECULAR = mix(0.48, 0.10, near_shore);
	METALLIC = 0.0;

	// ---------- мягкий урез ----------
	// Полупрозрачная тонкая вода над мокрым песком + пена, которая
	// прикрывает стык. У буфера сцены — мягкое пересечение с пирсом/камнями.
	float a = sea01 * (0.34 + 0.66 * thin);
	a = max(a, foam * sea01 * 0.95);
	float sd = texture(depth_tex, SCREEN_UV).r;
	vec4 ndc = vec4(SCREEN_UV * 2.0 - 1.0, sd, 1.0);
	vec4 vp = INV_PROJECTION_MATRIX * ndc;
	vp.xyz /= vp.w;
	float scene_z = -vp.z;
	float water_z = -VERTEX.z;
	// важно: гасим воду только ПЕРЕД предметом (пирс/камень). Мелкий
	// песок лежит ниже плоскости воды — он не должен делать воду прозрачной.
	float obj_a = smoothstep(0.0, shore_fade, scene_z - water_z);
	ALPHA = clamp(min(a, obj_a), 0.0, 1.0);
}
