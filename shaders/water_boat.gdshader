shader_type spatial;
// МОРЕ С ГИДРОДИНАМИКОЙ СУДНА:
// - Двухслойное волнение (длинная зыбь + ветровая толчея) синхронно с WaterField
// - 3D носовой бурун, волны Кельвина (V-клин), кильватерная струя винтов и пена обтекания корпуса
// - Честная глубина уреза по карте высот берега

render_mode diffuse_burley, specular_schlick_ggx, blend_mix, depth_draw_always;

uniform vec3 water_shallow : source_color = vec3(0.30, 0.66, 0.62);
uniform vec3 water_mid : source_color = vec3(0.10, 0.38, 0.48);
uniform vec3 water_deep : source_color = vec3(0.035, 0.150, 0.300);
uniform vec3 foam_col : source_color = vec3(0.95, 0.92, 0.86);
uniform vec3 sun_col : source_color = vec3(1.0, 0.80, 0.52);
uniform vec3 sun_dir = vec3(0.10, 0.26, -0.96);

uniform vec3 horizon_col : source_color = vec3(0.96, 0.66, 0.55);
uniform vec3 sky_col : source_color = vec3(0.28, 0.24, 0.43);
uniform float fog_distance = 340.0;

uniform vec2 wind_dir = vec2(0.32, -0.95);
uniform float wind_power = 1.0;
uniform float mega_amp = 0.22;

uniform float ripple_freq = 1.35;
uniform float ripple_speed = 1.1;
uniform float ripple_strength = 0.38;
uniform float glitter_amount = 1.0;
uniform float solar_glitter_amount = 1.0;
uniform float sun_path_amount = 1.0;
uniform float direct_specular_amount = 1.0;

uniform float proxima_test = 0.0;
uniform float proxima_specular_strength = 0.55;
uniform vec3 proxima_diffuse_fresnel_tint = vec3(1.0);
uniform float proxima_diffuse_fresnel = 1.0;
uniform float proxima_diffuse_fresnel_falloff = 0.75;
uniform float proxima_diffuse_tangent_falloff = 0.75;
uniform vec3 proxima_retroreflection_tint = vec3(1.0);
uniform float proxima_retroreflection = 1.0;
uniform float proxima_retroreflection_falloff = 0.75;
uniform float proxima_retroreflection_tangent_falloff = 0.75;
uniform float proxima_specular_fresnel_falloff = 0.5;
uniform float proxima_smooth_terminator = 0.0;
uniform float proxima_smooth_terminator_length = 0.5;

uniform float ring_amp = 0.095;
uniform float ring_speed = 1.5;
uniform float ring_len = 0.85;
uniform float ring_tau = 0.55;
uniform float ring_w0 = 0.30;
uniform float ring_wg = 0.18;
uniform float ring_boost = 1.8;

uniform float u_time = 0.0;

uniform sampler2D ground_tex : filter_linear, repeat_disable;
uniform vec2 ground_origin = vec2(-280.0, -450.0);
uniform float ground_cell = 1.184;
uniform float ground_n = 761.0;
uniform float sea_level = 0.0;
uniform float shore_fade = 0.03;

uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform vec4 u_rings[24];

// Состояние корабля (x, z, rotation_y, speed) и прицепа (x, z, rotation_y, active_01)
uniform vec4 u_vessel_state = vec4(0.0, 0.0, 0.0, 0.0);
uniform vec4 u_trailer_state = vec4(0.0, 0.0, 0.0, 0.0);

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
	return v * 0.70 + u * 0.16 + rn * 2.6 + rn2 * 3.4 + u_time * 0.55;
}

float swell_of(float mph, vec2 wp, vec2 wdir, vec2 wperp) {
	float primary = cos(mph) * 0.62 + cos(mph * 2.63 + 1.7) * 0.30 + cos(mph * 0.47 + 0.8) * 0.22;
	float chop_ph = dot(wp, wdir) * 1.15 - dot(wp, wperp) * 0.45 + u_time * 1.65;
	float chop = sin(chop_ph) * 0.22;
	return primary + chop;
}

float ground_at(vec2 wp) {
	vec2 uv = (wp - ground_origin) / (ground_cell * (ground_n - 1.0));
	if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) {
		return -6.0;
	}
	return texture(ground_tex, uv).r;
}

// Перевод мировой точки XZ в локальные координаты корабля (-Z нос, +Z корма)
vec2 to_ship_local(vec2 wp, vec2 center, float yaw) {
	vec2 d = wp - center;
	float c = cos(yaw);
	float s = sin(yaw);
	return vec2(d.x * c - d.y * s, d.x * s + d.y * c);
}

// Знаковое расстояние (SDF) до контура ватерлинии корабля
float hull_sdf(vec2 lp) {
	// Длина от -5.3 до +5.0, сужение к носу (-Z)
	float z_norm = clamp((lp.y + 5.3) / 10.3, 0.0, 1.0);
	float half_w = mix(0.12, 1.62, pow(sin(z_norm * 2.65), 0.65));
	if (lp.y > 1.5) {
		half_w = mix(1.58, 1.25, clamp((lp.y - 1.5) / 3.5, 0.0, 1.0));
	}
	vec2 q = vec2(abs(lp.x) - half_w, abs(lp.y + 0.15) - 5.15);
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0);
}

void vertex() {
	w_pos = (MODEL_MATRIX * vec4(VERTEX.x, VERTEX.y, VERTEX.z, 1.0)).xyz;
	vec2 wdir_v = normalize(wind_dir);
	vec2 wperp_v = vec2(-wdir_v.y, wdir_v.x);

	float ground = ground_at(w_pos.xz);
	float shore_depth = max(sea_level - ground, 0.0);
	float shore_t = clamp(shore_depth / 4.0, 0.0, 1.0);
	float shore_wave_fade = shore_t * shore_t * (3.0 - 2.0 * shore_t);
	float hrip = swell_of(mega_phase(w_pos.xz, wdir_v, wperp_v), w_pos.xz, wdir_v, wperp_v)
		* mega_amp * wind_power * shore_wave_fade;

	// Деформация поверхности воды самим кораблём (носовой бурун и волна Кельвина)
	vec2 ship_lp = to_ship_local(w_pos.xz, u_vessel_state.xy, u_vessel_state.z);
	float spd01 = clamp(abs(u_vessel_state.w) / 10.0, 0.0, 1.2);
	float d_bow = length(ship_lp - vec2(0.0, -5.1));
	float bow_crest = exp(-d_bow * d_bow * 0.45) * 0.24 * spd01;

	// Расходящийся V-образный гребень за носом
	float wake_z = max(0.0, ship_lp.y + 4.8);
	float wake_arm = abs(abs(ship_lp.x) - (0.35 + wake_z * 0.34));
	float kelvin_h = sin(wake_arm * 4.5 - u_time * 5.0) * exp(-wake_arm * 1.1) * exp(-wake_z * 0.11) * 0.14 * spd01;

	// Вытеснение воды внутри самого контура корпуса, чтобы вода не пробивала палубу
	float d_hull = hull_sdf(ship_lp);
	// smoothstep требует возрастающие границы; внутри корпуса опускаем воду.
	float hull_cut = -(1.0 - smoothstep(-0.35, 0.25, d_hull)) * 0.35;

	float y = hrip + bow_crest + kelvin_h + hull_cut;
	VERTEX.y += y;
	w_pos.y += y;
}

void fragment() {
	vec2 wp = w_pos.xz;
	vec2 wdir = normalize(wind_dir);
	vec2 wperp = vec2(-wdir.y, wdir.x);

	float ground = ground_at(wp);
	float depth_m = w_pos.y - ground;
	if (depth_m < -0.08) {
		discard;
	}
	float near_shore = 1.0 - smoothstep(-0.08, 0.9, depth_m);
	float mph = mega_phase(wp, wdir, wperp);

	vec3 L = normalize(sun_dir);
	vec3 N = vec3(0.0, 1.0, 0.0);

	float dist = length(CAMERA_POSITION_WORLD - w_pos);
	float detail = exp(-dist * 0.030);

	// ---------- слой 2: дыхание моря + второй каскад волн ----------
	float ms1 = sin(mph);
	float ms2 = sin(mph * 2.63 + 1.7);
	float ms3 = sin(mph * 0.47 + 0.8);
	float mdv = (-0.62 * 0.70 * ms1 - 0.30 * 2.63 * 0.70 * ms2
		- 0.22 * 0.47 * 0.70 * ms3) * mega_amp;
	float mdu = (-0.62 * 0.16 * ms1 - 0.30 * 2.63 * 0.16 * ms2
		- 0.22 * 0.47 * 0.16 * ms3) * mega_amp;
	vec2 mgrad = (wperp * mdv + wdir * mdu) * wind_power;
	float mega_fade = mix(0.30, 1.0, exp(-dist * 0.010));
	N = normalize(N - vec3(mgrad.x, 0.0, mgrad.y) * 0.55
		* (1.0 - 0.92 * near_shore) * mega_fade);

	// ---------- слой 1: ветровая рябь из трёх поездов ----------
	float n1 = vnoise(wp * 0.33);
	float n2 = vnoise(wp * 0.90 + vec2(17.0, 9.0));
	vec2 d1 = wdir;
	vec2 d2 = normalize(wdir + vec2(0.62, -0.55));
	vec2 d3 = normalize(wdir + vec2(-0.78, -0.30));
	float ph1 = dot(wp, d1) * ripple_freq + n1 * 5.0 + u_time * ripple_speed;
	float ph2 = dot(wp, d2) * ripple_freq * 1.9 + n2 * 4.0 + u_time * ripple_speed * 1.5;
	float ph3 = dot(wp, d3) * ripple_freq * 3.4 + n1 * 3.0 + u_time * ripple_speed * 2.3;
	vec2 wgrad = d1 * cos(ph1) * 0.55 + d2 * cos(ph2) * 0.36
		+ d3 * cos(ph3) * 0.24;
	float amp = 0.40 + 0.60 * vnoise(wp * 0.11 + vec2(3.7, 1.3));
	wgrad *= ripple_strength * wind_power * detail * amp
		* (1.0 - 0.88 * near_shore);
	N = normalize(N - vec3(wgrad.x, 0.0, wgrad.y) * 0.46);

	// ---------- кольца событий (с видимой пеной на гребнях) ----------
	float rk = PI_2 / ring_len;
	vec2 rgrad = vec2(0.0);
	float ring_foam_acc = 0.0;
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
		ring_foam_acc += max(0.0, cos(ph)) * env * dec * rg.w * 0.28;
	}
	N = normalize(N - vec3(rgrad.x * ring_boost, 0.0, rgrad.y * ring_boost));

	// ---------- ГИДРОДИНАМИЧЕСКИЙ СЛЕД КОРАБЛЯ И ПРИЦЕПА ----------
	vec2 ship_lp = to_ship_local(wp, u_vessel_state.xy, u_vessel_state.z);
	float spd01 = clamp(abs(u_vessel_state.w) / 10.0, 0.0, 1.25);
	float d_hull = hull_sdf(ship_lp);
	float turb_noise = vnoise(wp * 2.8 + vec2(0.0, -u_time * 2.4));
	float fine_noise = vnoise(wp * 6.5 + vec2(u_time * 1.3, -u_time * 3.1));

	// 1. Пенный воротник обтекания вокруг ватерлинии корабля
	float hull_collar = exp(-pow((d_hull - 0.12) / (0.22 + 0.14 * spd01), 2.0)) * step(-0.08, d_hull);
	hull_collar *= smoothstep(0.18, 0.72, turb_noise * 0.65 + fine_noise * 0.35);

	// 2. Носовой бурун и усы расходящейся волны Кельвина (V-Wake)
	float wake_z = max(0.0, ship_lp.y + 5.1);
	float arm_width = 0.28 + wake_z * 0.33;
	float arm_dist = abs(abs(ship_lp.x) - arm_width);
	float arm_env = exp(-arm_dist * arm_dist / (0.18 + wake_z * 0.045)) * exp(-wake_z * 0.095) * step(-5.1, ship_lp.y);
	float arm_phase = (abs(ship_lp.x) - arm_width) * 5.2 - u_time * 5.5;
	// Наклон нормалей воды на усах волны Кельвина
	float kelvin_slope = -sin(arm_phase) * arm_env * spd01 * 0.65;
	vec2 local_kgrad = vec2(sign(ship_lp.x) * kelvin_slope, -kelvin_slope * 0.33);
	float cy = cos(u_vessel_state.z);
	float sy = sin(u_vessel_state.z);
	vec2 world_kgrad = vec2(local_kgrad.x * cy + local_kgrad.y * sy, -local_kgrad.x * sy + local_kgrad.y * cy);
	N = normalize(N - vec3(world_kgrad.x, 0.0, world_kgrad.y));

	float kelvin_foam = max(0.0, cos(arm_phase)) * arm_env * spd01 * smoothstep(0.25, 0.78, turb_noise);

	// 3. Кильватерная турбулентная струя от двух винтов за кормой (Propeller Wash)
	float stern_z = max(0.0, ship_lp.y - 4.85);
	float wash_half_w = 0.65 + stern_z * 0.13;
	float wash_mask = exp(-pow(ship_lp.x / wash_half_w, 2.0)) * exp(-stern_z / (3.5 + 16.0 * spd01)) * step(4.8, ship_lp.y);
	float prop_foam = wash_mask * spd01 * smoothstep(0.22, 0.80, fine_noise * 0.6 + turb_noise * 0.5);

	// 4. Взаимодействие с буксируемым плашкоутом (если прицеплен)
	float trailer_foam = 0.0;
	if (u_trailer_state.w > 0.5) {
		vec2 tr_lp = to_ship_local(wp, u_trailer_state.xy, u_trailer_state.z);
		vec2 tq = abs(tr_lp) - vec2(1.32, 3.0);
		float d_tr = length(max(tq, 0.0)) + min(max(tq.x, tq.y), 0.0);
		trailer_foam = exp(-pow((d_tr - 0.10) / 0.22, 2.0)) * step(-0.05, d_tr) * smoothstep(0.25, 0.75, turb_noise);
	}

	float ship_wake_foam = clamp(hull_collar * (0.75 + 0.45 * spd01) + kelvin_foam * 0.90 + prop_foam * 0.95 + trailer_foam * 0.75 + ring_foam_acc, 0.0, 1.0);

	// ---------- цвет воды ----------
	vec3 base = mix(water_shallow, water_mid, smoothstep(0.0, 3.0, depth_m));
	base = mix(base, water_deep, smoothstep(1.0, 12.0, depth_m));
	base = mix(base, water_shallow * 1.22, near_shore * 0.45);
	// Аэрированная бирюзовая вода в кильватерной струе
	base = mix(base, water_shallow * 1.30, clamp(( wash_mask * spd01 * 0.55 + arm_env * spd01 * 0.25 ), 0.0, 0.65));

	float ndl = clamp(dot(N, L) * 0.5 + 0.5, 0.0, 1.0);
	base *= 0.80 + 0.32 * ndl;

	// ---------- френель: небо в воде ----------
	vec3 V = normalize(CAMERA_POSITION_WORLD - w_pos);
	vec3 R = reflect(-V, N);
	float fres = pow(1.0 - clamp(dot(N, V), 0.0, 1.0), 3.2);
	vec3 sky_ref = mix(horizon_col, sky_col, smoothstep(0.02, 0.42, R.y));
	sky_ref = mix(sky_ref, sky_ref * vec3(0.60, 0.80, 1.02), 0.62);
	float mirror = clamp(0.05 + 0.92 * fres, 0.0, 0.88);
	mirror *= 1.0 - 0.18 * near_shore;
	base = mix(base, sky_ref, mirror);

	// ---------- солнечный глиттер ----------
	vec3 H = normalize(V + L);
	float far_glit = smoothstep(120.0, 900.0, dist);
	float need = 900.0 / max(dist, 0.001);
	float lod_density = pow(2.0, floor(log2(need / 3.0))) * 3.0;
	float density = clamp(lod_density, mix(6.0, 1.2, far_glit), 72.0);
	vec2 celluv = floor(wp * density);
	float cellid = hash12(celluv);
	float cellb = hash12(celluv + vec2(7.31, 1.77));
	float cellc = fract(cellid * 13.7);
	vec3 G = normalize(vec3(cellid - 0.5, 0.05 + 0.95 * cellb, cellc - 0.5));
	vec3 Hg = normalize(H + vec3(cellid - 0.5, cellb - 0.5, cellc - 0.5) * 0.55);
	float sun_lobe = pow(clamp(dot(N, Hg), 0.0, 1.0), mix(30.0, 110.0, cellb));
	float sky_lobe = pow(clamp(dot(G, V), 0.0, 1.0), mix(24.0, 80.0, cellc));
	float glit_chance = glitter_amount * mix(exp(-dist * 0.002), 0.42, far_glit);
	float glint = step(1.0 - glit_chance, cellid);
	float glit_fade = mix(exp(-dist * 0.0025), 0.38, far_glit)
		* (1.0 - 0.92 * near_shore);
	base += sun_col * (sun_lobe * 1.6 + sky_lobe * 0.26) * glint * glit_fade;

	float path_power = mix(180.0, 34.0, far_glit);
	float path = pow(clamp(dot(N, H), 0.0, 1.0), path_power);
	base += sun_col * path * 0.55 * sun_path_amount * (1.0 - 0.85 * near_shore);

	vec2 view_xz = V.xz / max(length(V.xz), 1e-4);
	vec2 sun_xz = L.xz / max(length(L.xz), 1e-4);
	float road_alignment = clamp(-dot(view_xz, sun_xz), 0.0, 1.0);
	float sun_road = pow(road_alignment, 8.0);
	float spark_cell_size = mix(3.2, 11.0, far_glit);
	vec2 spark_uv = wp / spark_cell_size;
	vec2 spark_cell = floor(spark_uv);
	vec2 spark_local = fract(spark_uv) - vec2(0.5);
	float spark_seed = hash12(spark_cell);
	vec2 spark_jitter = vec2(hash12(spark_cell + vec2(5.7, 2.3)),
		hash12(spark_cell + vec2(1.9, 8.1))) - vec2(0.5);
	vec2 spark_pos = (spark_local - spark_jitter * 0.54) * spark_cell_size;
	float pixel_world = max(0.35, dist * 2.0
		/ max(VIEWPORT_SIZE.y * PROJECTION_MATRIX[1][1], 1.0));
	float spark_radius = max(0.55, pixel_world * 0.95);
	float spark_core = 1.0 - smoothstep(spark_radius * 0.30, spark_radius,
		length(spark_pos));
	float ray_width = max(0.12, pixel_world * 0.12);
	float ray_v = (1.0 - smoothstep(ray_width, ray_width * 2.4, abs(spark_pos.x)))
		* (1.0 - smoothstep(spark_radius, spark_radius * 3.2, abs(spark_pos.y)));
	float ray_h = (1.0 - smoothstep(ray_width, ray_width * 2.4, abs(spark_pos.y)))
		* (1.0 - smoothstep(spark_radius, spark_radius * 3.2, abs(spark_pos.x)));
	float sparkle_shape = max(spark_core, max(ray_v, ray_h) * 0.72);
	float microfacet_seed = hash12(spark_cell + vec2(11.7, 4.1));
	vec3 microfacet_n = normalize(vec3((microfacet_seed - 0.5) * 0.38, 1.0,
		hash12(spark_cell + vec2(3.3, 15.1)) * 0.38 - 0.19));
	float microfacet_match = 0.45 + 0.55 * pow(
		clamp(dot(microfacet_n, H), 0.0, 1.0), 10.0);
	float spark_select = step(1.0 - solar_glitter_amount * 0.32, spark_seed);
	float spark_twinkle = 0.72 + 0.28 * sin(u_time * 3.4 + spark_seed * 71.0);
	vec3 spark_tint = mix(sun_col, vec3(1.0, 0.96, 0.82), spark_core * 0.82);
	vec3 distant_glitter = spark_tint * sparkle_shape * spark_select * sun_road
		* microfacet_match * spark_twinkle * far_glit * solar_glitter_amount
		* 9.0 * (1.0 - 0.70 * near_shore);
	base += distant_glitter;

	// ---------- пена прибоя + кильватерная пена судна ----------
	float fn = vnoise(vec2(wp.x * 0.85 + u_time * 0.10, wp.y * 1.55));
	float fn2 = vnoise(vec2(wp.x * 3.2 - u_time * 0.38, wp.y * 2.35));
	float edge = exp(-pow((depth_m - 0.014 - 0.014 * sin(wp.x * 0.9 + u_time * 1.3)) / 0.075, 2.0));
	float edge2 = exp(-pow((depth_m - 0.17 - 0.03 * sin(wp.y * 0.21 + u_time * 1.15)) / 0.08, 2.0));
	float foam = edge * smoothstep(0.02, 0.40, fn) * (0.72 + 0.28 * fn2);
	foam += edge2 * smoothstep(0.45, 0.85, fn2) * 0.55;
	foam = clamp(max(foam, ship_wake_foam), 0.0, 1.0);
	base = mix(base, foam_col * (0.82 + 0.18 * ndl), foam * 0.92);

	// ---------- дымка к горизонту ----------
	float fog = 1.0 - exp(-pow(dist / fog_distance, 2.1));
	float above = smoothstep(-2.0, 16.0, w_pos.y - CAMERA_POSITION_WORLD.y);
	vec3 fcol = mix(horizon_col, sky_col, above * 0.6);
	ALBEDO = mix(base - distant_glitter, fcol, fog);
	EMISSION = distant_glitter;

	NORMAL = normalize((VIEW_MATRIX * vec4(N.x, N.y, N.z, 0.0)).xyz);
	float rough = mix(0.16, 0.55, near_shore);
	ROUGHNESS = mix(rough, 0.88, foam);
	SPECULAR = mix(0.55, 0.18, near_shore);
	METALLIC = 0.0;

	float shore_a = smoothstep(-0.08, 0.22, depth_m);
	float sea_a = shore_a;
	float a = max(sea_a, foam * 0.92);
	float sd = texture(depth_tex, SCREEN_UV).r;
	vec2 ndc_xy = SCREEN_UV * 2.0 - 1.0;
	vec4 ndc = vec4(ndc_xy.x, ndc_xy.y, sd, 1.0);
	vec4 vp = INV_PROJECTION_MATRIX * ndc;
	vp.xyz /= vp.w;
	float scene_z = -vp.z;
	float water_z = -VERTEX.z;
	float obj_a = smoothstep(0.0, shore_fade, scene_z - water_z);
	ALPHA = clamp(min(a, obj_a), 0.0, 1.0);
}

// Адаптация формул Proxima Diffuse + Schlick-GGX для A/B-теста воды.
// Источник: ElSuicio, 2026; MIT, godotshaders.com/shader/
// proxima-ggx-the-callisto-protocol-light-model/.
// Copyright (c) 2026 ElSuicio. Permission is hereby granted, free of charge,
// to any person obtaining a copy of this software and associated files, to
// deal in the Software without restriction, including without limitation the
// rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
// sell copies, subject to inclusion of this copyright and permission notice.
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND.
float proxima_h(float ctheta, float n, float cphi, float m) {
	return clamp(pow(max(1.0 - ctheta, 0.0), 5.0 * n)
		* pow(max(cphi, 0.0), 5.0 * m), 0.0, 1.0);
}

float proxima_r(float x) {
	return 2.0 * (1.0 - x);
}

float proxima_t(float x) {
	return clamp(x, 0.0, 1.0);
}

void light() {
	vec3 n = normalize(NORMAL);
	vec3 l = normalize(LIGHT);
	vec3 v = normalize(VIEW);
	float nl = max(dot(n, l), 0.0);
	float nv = clamp(dot(n, v), 1e-3, 1.0);
	if (nl > 0.0) {
	vec3 h = normalize(v + l);
	float nh = clamp(dot(h, n), 0.0, 1.0);
	float hl = clamp(dot(h, l), 0.0, 1.0);
	vec3 radiance = LIGHT_COLOR * ATTENUATION;

	if (proxima_test < 0.5) {
		float a = max(ROUGHNESS * ROUGHNESS, 0.002);
		float a2 = a * a;
		float q = 1.0 + (a2 - 1.0) * nh * nh;
		float d = a2 / (PI * q * q);
		float k = pow(ROUGHNESS + 1.0, 2.0) * 0.125;
		float gl = nl / (nl * (1.0 - k) + k);
		float gv = nv / (nv * (1.0 - k) + k);
		vec3 f0 = mix(vec3(0.04 * proxima_specular_strength), ALBEDO, METALLIC);
		vec3 f = f0 + (1.0 - f0) * pow(1.0 - hl, 5.0);
		float fd90 = 0.5 + 2.0 * ROUGHNESS * hl * hl;
		float burley_l = 1.0 + (fd90 - 1.0) * pow(1.0 - nl, 5.0);
		float burley_v = 1.0 + (fd90 - 1.0) * pow(1.0 - nv, 5.0);
		DIFFUSE_LIGHT += radiance * ALBEDO * (1.0 / PI)
			* burley_l * burley_v * nl;
		SPECULAR_LIGHT += radiance * d * gl * gv * f * direct_specular_amount
			/ max(4.0 * nl * nv, 1e-3);
	} else {
	float alpha = ROUGHNESS * ROUGHNESS;
	float alpha2 = alpha * alpha;
	float vdl = max(dot(-v, l), 0.0);
	float theta_h = acos(nh);
	float theta_d = acos(hl);
	float alpha_f = proxima_h(hl, proxima_r(proxima_diffuse_fresnel_falloff),
		nh, proxima_r(proxima_diffuse_tangent_falloff));
	float alpha_r = proxima_h(nh, proxima_r(proxima_retroreflection_falloff),
		hl, proxima_r(proxima_retroreflection_tangent_falloff));
	float alpha_s = (1.0 - pow(1.0 - theta_d, 3.0))
		* (1.0 - pow(1.0 - theta_h, 3.0));
	vec3 rho_f = proxima_diffuse_fresnel * proxima_diffuse_fresnel_tint;
	vec3 rho_r = proxima_retroreflection * proxima_retroreflection_tint;
	vec3 c1 = mix(vec3(1.0), rho_f, alpha_f)
		* mix(vec3(1.0), rho_r, alpha_r);
	float smooth_term = mix(1.0, smoothstep(0.0,
		max(alpha_s * proxima_smooth_terminator_length, 1e-4), nl),
		alpha_s * proxima_smooth_terminator);
	vec3 fd = c1 * (1.0 / PI)
		* (alpha * (-0.55 + 0.19 / max(nl, 1e-3))
		* (1.0 - sqrt(vdl)) + 1.0) * smooth_term * nl;

	float t = 1.0 + (alpha2 - 1.0) * nh * nh;
	float d = alpha2 / (PI * t * t);
	float gl = 1.0 / (nl + sqrt(alpha2 + (1.0 - alpha2) * nl * nl));
	float gv = 1.0 / (nv + sqrt(alpha2 + (1.0 - alpha2) * nv * nv));
	vec3 f0 = mix(vec3(proxima_specular_strength * 0.08), ALBEDO, vec3(METALLIC));
	float fh = pow(clamp(1.0 - hl, 0.0, 1.0),
		5.0 * proxima_r(proxima_specular_fresnel_falloff));
	vec3 fresnel = f0 + proxima_t(2.0
		- proxima_r(proxima_specular_fresnel_falloff)) * (1.0 - f0) * fh;
	vec3 fs = d * gl * gv * fresnel * nl;
	DIFFUSE_LIGHT += radiance * fd;
	SPECULAR_LIGHT += radiance * fs * direct_specular_amount;
	}
	}
}
