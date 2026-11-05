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
    float ripple = sin(length(p) * 11.0 - t * 3.8 + atan(p.y, p.x) * 4.0);
    float angle = atan(p.y, p.x);
    d += sin(angle * 5.0 + t * 0.65) * 0.08
        + sin(angle * 9.0 - t * 0.25) * 0.035;
    d += ripple * 0.035 + (hash21(floor(p * 12.0) + floor(t * 0.2)) - 0.5) * 0.025;
    float aa = max(fwidth(d), 0.012);
    float body = 1.0 - smoothstep(-aa, aa, d);
    float edge = exp(-pow(d / 0.19, 2.0));
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
    float veins = 0.5 + 0.5 * sin(inner.x * 7.0 + inner.y * 9.0 + t * 2.4);
    float pockets = smoothstep(0.30, 0.78,
        pigment_noise(deep * 2.5 + vec2(seed)));
    // Рисунок смещается под неподвижным поверхностным контуром.
    // Маска тела НЕ сдвигается: край не отрывается от волновой сетки.
    float inner_ribbon = 0.5 + 0.5 * sin(deep.x * 4.0 - deep.y * 6.0 + seed);
    float depth_mix = smoothstep(0.0, 0.20, parallax_depth);
    veins = mix(veins, veins * 0.60 + inner_ribbon * 0.25 + pockets * 0.15, depth_mix);
    vec3 col = pigment * (0.72 + 0.28 * veins);
    col += pigment * edge * (0.8 + 0.5 * sin(t * 2.0));
    col += vec3(0.85, 0.96, 0.90) * edge * pulse * 0.65;
    ALBEDO = col;
    ALPHA = body * (0.63 + 0.17 * veins) * fade;
    EMISSION = pigment * body * (0.10 + 0.20 * pulse) * fade;
}
