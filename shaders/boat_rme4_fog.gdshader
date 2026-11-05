shader_type fog;
// Адаптация идеи атмосферной 3D-плотности / многомасштабного шума из
// patu, «RME4 - Crater»: https://www.shadertoy.com/view/MlSBDt
// НЕ переносим его кратер, skybox и raymarch-геометрию поверх нашего моря.
// Godot интегрирует плотность в собственном volumetric-fog froxel pass.

uniform sampler3D density_noise : repeat_enable, filter_linear;
uniform float night_factor : hint_range(0.0, 1.0) = 0.0;
uniform float density_scale : hint_range(0.0, 0.2) = 0.065;

void fog() {
	vec3 wind = vec3(TIME * 0.003, 0.0, -TIME * 0.002);
	float broad = texture(density_noise, WORLD_POSITION * 0.022 + wind).r;
	float detail = texture(density_noise, WORLD_POSITION * 0.073 - wind * 1.7).r;
	float patches = smoothstep(0.36, 0.70, broad * 0.72 + detail * 0.28);
	// Морской туман идёт по поверхности, но оставляет свободный воздух
	// над камерой; нет плоской маски, привязанной к экрану.
	float height_mask = smoothstep(-4.0, -1.0, WORLD_POSITION.y) *
		(1.0 - smoothstep(2.0, 13.0, WORLD_POSITION.y));
	float edge = smoothstep(0.0, 4.0, min(-SDF.x, min(-SDF.y, -SDF.z)));
	DENSITY = density_scale * mix(0.75, 1.0, night_factor) * patches * height_mask * edge;
	ALBEDO = mix(vec3(0.48, 0.62, 0.65), vec3(0.21, 0.31, 0.39), night_factor);
}
