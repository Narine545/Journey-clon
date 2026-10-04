shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled;

// =====================================================================
// Дальнее море барханов — SDF-реймарчинг с плавным CSG-объединением.
// По мотивам «Fullscreen SDF Raymarching with Smooth CSG» (vav-labs,
// CC0; функции расстояний — Inigo Quilez). Оригинал пишет глубину в
// конвенции reversed-Z и работает только в Forward+ — здесь техника
// адаптирована под Compatibility: реймарчим на дальнем квад-меше
// ПОЗАДИ террейна, взаимное перекрытие даёт обычный depth-тест.
//
// Гигантские дуги-барханы плавно сплавляются в песчаное море (smin),
// растворяются в дымке горизонта. Это «фоновой слой» песка.
// =====================================================================

uniform vec3 sun_dir = vec3(0.16, 0.44, -0.88);
uniform vec3 dune_col : source_color = vec3(0.50, 0.34, 0.33);
uniform vec3 dune_hot : source_color = vec3(0.90, 0.52, 0.32);
uniform vec3 haze_col : source_color = vec3(1.00, 0.70, 0.48);
uniform vec3 sky_col : source_color = vec3(0.27, 0.24, 0.44);

varying vec3 w_pos;

// плавное объединение (smooth CSG union) — «метаболы»
float smin(float a, float b, float k) {
	float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
	return mix(b, a, h) - k * h * (1.0 - h);
}

// эллипсоид (I. Quilez)
float sd_ellipsoid(vec3 p, vec3 r) {
	float k0 = length(p / r);
	float k1 = length(p / (r * r));
	return k0 * (k0 - 1.0) / k1;
}

// Поле дальних дюн: песчаное море + сплав барханов.
// Вся карта — вот эта функция (как map() у vav-labs).
float dune_field(vec3 p) {
	float d = p.y + 78.0; // песчаное «море» до горизонта
	d = smin(d, sd_ellipsoid(p - vec3(-430.0, -55.0, -980.0),  vec3(300.0, 92.0, 160.0)), 95.0);
	d = smin(d, sd_ellipsoid(p - vec3(-90.0,  -40.0, -1120.0), vec3(360.0, 118.0, 190.0)), 95.0);
	d = smin(d, sd_ellipsoid(p - vec3(270.0,  -62.0, -1020.0), vec3(280.0, 80.0, 150.0)), 95.0);
	d = smin(d, sd_ellipsoid(p - vec3(640.0,  -48.0, -1180.0), vec3(330.0, 96.0, 170.0)), 95.0);
	d = smin(d, sd_ellipsoid(p - vec3(-760.0, -40.0, -1240.0), vec3(310.0, 84.0, 165.0)), 95.0);
	d = smin(d, sd_ellipsoid(p - vec3(60.0,   -70.0, -1330.0), vec3(400.0, 124.0, 200.0)), 95.0);
	return d;
}

void fragment() {
	vec3 ro = CAMERA_POSITION_WORLD;
	vec3 rd = normalize(w_pos - ro);
	float t_max = length(w_pos - ro) + 60.0;

	// реймарч: шаг по SDF (дюны огромные — точность расслаблена)
	float t = 0.0;
	bool hit = false;
	for (int i = 0; i < 80; i++) {
		vec3 p = ro + rd * t;
		float d = dune_field(p);
		if (d < 0.8) {
			hit = true;
			break;
		}
		t += max(d * 0.9, 1.5);
		if (t > t_max) {
			break;
		}
	}
	if (!hit) {
		discard; // небо — честное небо
	}

	vec3 p = ro + rd * t;
	// нормаль тетраэдром (4 оценки поля)
	vec2 e = vec2(1.0, -1.0) * 0.7;
	vec3 n = normalize(
		e.xyy * dune_field(p + e.xyy)
		+ e.yyx * dune_field(p + e.yyx)
		+ e.yxy * dune_field(p + e.yxy)
		+ e.xxx * dune_field(p + e.xxx));

	// свет в духе игрового песка: wrap-солнце + небо + тёплая кромка
	float ndl = dot(n, normalize(sun_dir));
	float wrap = clamp((ndl + 0.45) / 1.05, 0.0, 1.0);
	vec3 col = dune_col;
	col += dune_hot * pow(wrap, 2.0) * 0.45;
	col += sky_col * clamp(n.y, 0.0, 1.0) * 0.30 * (1.0 - wrap);

	// дымка мягче игровой: дальние дюны — призраки в мареве
	float dist = length(p - ro);
	float fog = 1.0 - exp(-pow(dist / 760.0, 2.0));
	ALBEDO = mix(col, haze_col, fog);
}
