shader_type fog;
// Атмосферный слой моря по мотивам patu, «RME4 - Crater»:
// https://www.shadertoy.com/view/MlSBDt
//
// Оттуда берём ПРИНЦИП, а не картинку: плотность собирается из нескольких
// масштабов шума (broad / mid / detail), и воздух становится густым и
// слоистым. Кратер, skybox и raymarch-геометрию НЕ переносим — плотность
// интегрирует собственный froxel-pass Godot (volumetric_fog.glsl).
//
// ВАЖНО: это не постэффект. DENSITY попадает в 3D-текстуру объёма, и по ней
// считаются солнце, прожектор и огни маяков. Именно поэтому свет здесь
// «работает на атмосферу», а не просто осветляет кадр.
//
// Два ограничения Godot, о которые ломалась прошлая версия:
//  1) Весь pass (включая FogVolume) пропускается, если
//     Environment.volumetric_fog_enabled == false — см.
//     render_forward_clustered.cpp, _update_volumetric_fog().
//  2) DENSITY уходит в целочисленную карту с множителем 1024 и порогом
//     отсечения 0.001: слишком слабые значения теряют точность.

uniform sampler3D density_noise : repeat_enable, filter_linear;

// 0 = день, 1 = ночь. Двигает плотность, цвет и собственное свечение.
uniform float night_factor : hint_range(0.0, 1.0) = 0.0;
// Погода управляет наличием низкого тумана, не формой принятого профиля.
uniform float weather_fog : hint_range(0.0, 1.0) = 1.0;
// [O]: 0 — прежний высокий слой, 1 — низкий туман у ватерлинии.
uniform float mystery_profile : hint_range(0.0, 1.0) = 1.0;
// [U] диагностика: обходим шум, высоту и зависимость видимости от света.
uniform bool diagnostic_volume = false;
// Масштаб плотности прежнего профиля. Новый профиль повышает пики,
// но уменьшает заполняющую дымку; итог зависит от пути луча.
uniform float density_scale : hint_range(0.0, 0.15) = 0.045;
// Порог пятна. Ниже — туман сплошной, выше — рваные облака.
uniform float patch_threshold : hint_range(0.0, 1.0) = 0.42;
// Доля «базовой дымки»: слой никогда не становится полностью пустым,
// иначе между пятнами проваливается в ноль и читается как дырки.
uniform float base_fill : hint_range(0.0, 1.0) = 0.34;
// Скорость дрейфа слоя, условные м/с.
uniform float wind_speed : hint_range(0.0, 4.0) = 1.0;

// Направление НА солнце. Нужно, чтобы красить воздух на низком солнце.
uniform vec3 sun_direction = vec3(-0.36, 0.76, -0.54);
uniform vec3 day_albedo : source_color = vec3(0.55, 0.60, 0.67);
uniform vec3 night_albedo : source_color = vec3(0.20, 0.26, 0.36);
uniform vec3 dusk_tint : source_color = vec3(0.72, 0.48, 0.34);
// Собственное свечение тумана. Годот умножает его на плотность, поэтому
// число выглядит большим, а в кадре даёт лишь лёгкое ночное дыхание воздуха.
uniform float night_emission : hint_range(0.0, 0.6) = 0.16;

void fog() {
	vec3 wp = WORLD_POSITION;
	float profile = clamp(mystery_profile, 0.0, 1.0);
	vec3 wind = vec3(TIME * 0.0045, 0.0, -TIME * 0.0031)
		* wind_speed * mix(1.0, 0.35, profile);

	// Три масштаба — тот самый приём RME4: крупные массы задают силуэт,
	// средние рвут их на клочья, мелкие дают зерно на ближнем плане.
	// Дрейфуют с разной скоростью, поэтому слой эволюционирует, а не едет.
	float broad = texture(density_noise, wp * 0.0105 + wind * 0.6).r;
	float mid = texture(density_noise, wp * 0.0330 + wind * 1.3).r;
	float detail = texture(density_noise, wp * 0.0910 - wind * 2.1).r;
	float n = broad * 0.55 + mid * 0.30 + detail * 0.15;

	float patches = smoothstep(patch_threshold, patch_threshold + 0.24, n);
	// Более тёмные просветы между массами, а не рост равномерной пелены.
	float body = mix(mix(base_fill, 0.20, profile), 1.0, patches);

	// Одна дополнительная выборка: независимое от высоты поле потолка.
	// Медленный мировой дрейф, без привязки к камере или лодке.
	float height_noise = texture(density_noise,
		vec3(wp.x * 0.024, 0.37, wp.z * 0.024) + wind * 0.45).r;
	float ceiling = 1.2 + height_noise * 1.4;
	float legacy_height = 1.0 - smoothstep(7.0, 15.0, wp.y);
	// Верх корпуса входит в слой частично, рубка/мачта остаются выше.
	float bank_height = smoothstep(-0.15, 0.25, wp.y)
		* (1.0 - smoothstep(ceiling - 0.65, ceiling, wp.y));
	float height_mask = mix(smoothstep(0.0, 1.2, wp.y) * legacy_height,
		bank_height, profile);

	// Высоту уже задаёт bank_height. Полный SDF коробки у воды включает
	// расстояние до нижней грани и дополнительно срезает тонкий слой.
	// В новом профиле гасим ТОЛЬКО боковые стенки (UVW — координаты BOX).
	vec2 side_distance = min(UVW.xz, vec2(1.0) - UVW.xz) * SIZE.xz;
	float horizontal_edge = smoothstep(0.0, 18.0, min(side_distance.x, side_distance.y));
	float edge = mix(smoothstep(0.0, 18.0, -SDF), horizontal_edge, profile);

	float night = clamp(night_factor, 0.0, 1.0);
	DENSITY = density_scale * mix(1.0, 4.0, profile)
		* body * height_mask * edge * mix(0.90, 1.12, night) * weather_fog;

	// Альбедо однократного рассеяния (НЕ домноженное на плотность — это
	// сделает сам Godot). Тёплое на низком солнце, холодное ночью.
	float low_sun = clamp(1.0 - sun_direction.y * 2.2, 0.0, 1.0);
	vec3 albedo = mix(day_albedo, dusk_tint, low_sun * (1.0 - night));
	vec3 legacy_albedo = mix(albedo, night_albedo, night);
	// Туман, а не чёрный дым: оставляем достаточно рассеяния для фонаря.
	vec3 low_fog_albedo = mix(vec3(0.75, 0.80, 0.82), vec3(0.58, 0.65, 0.73), night);
	ALBEDO = mix(legacy_albedo, low_fog_albedo, profile);

	// Собственное свечение раньше заполняло ночные тени. Сохраняем лишь
	// четверть в новом профиле: главный акцент должен давать реальный свет.
	EMISSION = night_albedo * night_emission * mix(1.0, 0.25, profile) * night;
	if (diagnostic_volume) {
		DENSITY = 0.08 * smoothstep(0.0, 2.0, -SDF);
		ALBEDO = vec3(0.7);
		EMISSION = vec3(0.05, 0.65, 0.75);
	}
}
