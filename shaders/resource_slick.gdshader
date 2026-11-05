shader_type spatial;
// Цветные приливные пятна. Та же SDF-идея, что в sand_sea_sdf.gdshader:
// расстояния до примитивов, плавное объединение форм и цветов, а не текстура.
// Пятно лежит поверх существующего волнового моря и не заменяет его шейдер.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;

uniform vec3 pigment : source_color = vec3(0.20, 0.80, 0.77);
uniform float seed = 0.0;
uniform float pulse = 0.0;
uniform float fade = 1.0;
uniform float wave_time = 0.0;
uniform float wave_amp = 0.25;
uniform float wave_power = 1.0;
uniform vec2 wave_wind = vec2(0.32, -0.95);
// Два внутренних слоя вместо screen-texture: прозрачное море не обязано
// присутствовать в screen copy. Нулевая глубина отключает эффект.
uniform float parallax_depth : hint_range(0.0, 1.0) = 0.55;
varying vec2 local_pos;
varying vec2 world_xz;

#include "res://shaders/boat_wave_spectrum.gdshaderinc"

float hash21(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

float pigment_noise(vec2 p) {
    vec2 cell = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash21(cell), hash21(cell + vec2(1.0, 0.0)), f.x),
        mix(hash21(cell + vec2(0.0, 1.0)), hash21(cell + vec2(1.0)), f.x), f.y);
}

// IQ polynomial smooth-min: та же операция "плавления", что у SDF-рыб.
float smooth_union(float a, float b, float k) {
    float h = max(k - abs(a - b), 0.0) / k;
    return min(a, b) - h * h * k * 0.25;
}

void vertex() {
	local_pos = VERTEX.xz;
	// Сетка пятна повторяет тот же дисперсионный спектр, что и море.
	vec2 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
	vec2 center = MODEL_MATRIX[3].xz;
	world_xz = wp;
	VERTEX.y += spectrum_height(wp, wave_time, wave_wind, wave_amp, wave_power)
		- spectrum_height(center, wave_time, wave_wind, wave_amp, wave_power);
}

void fragment() {
    vec2 p = local_pos * 0.82;
    float t = TIME * 0.45 + seed;
    float d = length(p + vec2(sin(t) * 0.10, cos(t * 0.8) * 0.10)) - 0.96;
    for (int i = 0; i < 4; i++) {
        float a = float(i) * 2.399963 + seed * 2.7;
        vec2 center = vec2(cos(a), sin(a)) * (0.68 + 0.15 * sin(t + float(i)));
        float lobe = length(p - center) - (0.52 + 0.12 * sin(t * 1.2 + float(i) * 2.0));
        d = smooth_union(d, lobe, 0.48);
    }
    // Непериодическая граница без радиальных/диагональных полос и
    // скачущего floor(TIME)-шума.
    d += (pigment_noise(p * 3.0 + vec2(seed, t * 0.08)) - 0.5) * 0.16;
    float aa = max(fwidth(d), 0.012);
    float body = 1.0 - smoothstep(-aa, aa, d);
    // Параллельный вектор взгляда для ортографической камеры; перспективная
    // камера использует направление от фрагмента (VIEW в view space).
    vec3 view_direction = PROJECTION_MATRIX[3][3] > 0.5 ? vec3(0.0, 0.0, 1.0) : VIEW;
    vec3 view_world = normalize((INV_VIEW_MATRIX * vec4(view_direction, 0.0)).xyz);
    vec2 slope = spectrum_gradient(world_xz, wave_time, wave_wind, wave_amp, wave_power);
    vec3 surface_normal = normalize(vec3(-slope.x, 1.0, -slope.y));
    // Внутренняя граница вода/пигмент: IOR около 1.33. Луч идёт внутрь.
    vec3 inside_ray = refract(-view_world, surface_normal, 1.0 / 1.33);
    vec2 world_offset = inside_ray.xz / max(-inside_ray.y, 0.20) * parallax_depth;
    // Перевод world XZ в локальную плоскость пятна (учёт масштаба/поворота).
    vec3 offset_local = inverse(mat3(MODEL_MATRIX)) * vec3(world_offset.x, 0.0, world_offset.y);
    vec2 inner = p + offset_local.xz * 0.82;
    vec2 deep = p + offset_local.xz * 1.64;
    // Крупные сгустки на двух глубинах. Не sin(x+y): длинных полос нет.
    // Domain warp также непериодический и движется медленно.
    vec2 drift = vec2(t * 0.035, -t * 0.025);
    vec2 warp = vec2(pigment_noise(inner * 1.7 + seed),
        pigment_noise(inner * 1.7 + vec2(7.2, 3.8) + seed)) - 0.5;
    float upper_cloud = pigment_noise(inner * 2.8 + warp * 1.5 + drift + seed);
    float lower_cloud = pigment_noise(deep * 2.1 - warp + vec2(4.7, 9.1) + seed);
    float upper_mass = smoothstep(0.34, 0.70, upper_cloud);
    float lower_mass = smoothstep(0.28, 0.72, lower_cloud);
    // Независимый силуэт внутреннего скопления даёт видимую точку
    // отсчёта параллакса под фиксированной поверхностной кромкой.
    float core_radius = 0.88 + (pigment_noise(deep * 2.0 + seed) - 0.5) * 0.45;
    float core = 1.0 - smoothstep(core_radius - 0.22, core_radius + 0.12,
        length(deep + warp * 0.20));
    vec3 deep_color = pigment * vec3(0.22, 0.28, 0.36);
    vec3 suspended_color = mix(pigment * 0.62, pigment * 1.30, upper_mass);
    vec3 col = mix(deep_color, pigment * 0.75, lower_mass * 0.65);
    col = mix(col, suspended_color, core * (0.28 + upper_mass * 0.65));
    // Тонкая полупрозрачная кромка вместо прежнего пульсирующего неона.
    float rim = exp(-pow(d / 0.075, 2.0));
    col = mix(col, pigment * 1.15 + vec3(0.06), rim * 0.42);
    // Широкий слабый блик поверхности движется с общей нормалью волн.
    vec3 reflected = reflect(-view_world, surface_normal);
    float sheen = smoothstep(0.30, 0.85, reflected.y);
    col += vec3(0.10, 0.13, 0.15) * sheen * (0.3 + upper_mass * 0.7);
    ALBEDO = col;
    ALPHA = body * (0.48 + 0.30 * core + 0.10 * upper_mass) * fade;
    EMISSION = pigment * body * 0.06 * fade;
}
