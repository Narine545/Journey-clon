shader_type fog;
// Адаптация идеи атмосферной 3D-плотности / многомасштабного шума из
// patu, «RME4 - Crater»: https://www.shadertoy.com/view/MlSBDt
// НЕ переносим его кратер, skybox и raymarch-геометрию поверх нашего моря.
// Godot интегрирует плотность в собственном volumetric-fog froxel pass.

uniform sampler3D density_noise : repeat_enable, filter_linear;
uniform float night_factor : hint_range(0.0, 1.0) = 0.0;
uniform float density_scale : hint_range(0.0, 0.1) = 0.055;

void fog() {
	vec3 wind = vec3(TIME * 0.003, 0.0, -TIME * 0.002);
	float broad = texture(density_noise, WORLD_POSITION * 0.022 + wind).r;
	float detail = texture(density_noise, WORLD_POSITION * 0.073 - wind * 1.7).r;
	float patches = smoothstep(0.47, 0.66, broad * 0.72 + detail * 0.28);
	// Пятна разной плотности над водой: зазор у поверхности оставляет
	// ближние волны читаемыми; слой пересекает луч к берегу и лодке.
	float height_mask = smoothstep(-0.5, 1.5, WORLD_POSITION.y) *
		(1.0 - smoothstep(5.0, 12.0, WORLD_POSITION.y));
	// В Godot fog() SDF — скалярное signed distance, НЕ vec3.
	// Внутри объёма значение отрицательное; плавно гасим край бокса.
	float edge = smoothstep(0.0, 5.0, -SDF);
	DENSITY = density_scale * mix(0.75, 1.0, night_factor) * patches * height_mask * edge;
	ALBEDO = mix(vec3(0.28, 0.37, 0.39), vec3(0.10, 0.17, 0.23), night_factor);
}
