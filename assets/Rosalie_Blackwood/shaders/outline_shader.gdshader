shader_type spatial;
render_mode blend_mix, depth_draw_never, depth_test_default, cull_front, diffuse_toon, specular_disabled, unshaded, shadows_disabled, ambient_light_disabled;

uniform sampler2D albedo_texture : source_color;

uniform float min_thickness : hint_range(0.001,0.01) = 0.005;
uniform float max_thickness : hint_range(0.01,0.1) = 0.01;

varying vec2 uv_interp;

void vertex() {
    // Увеличиваем размер меша
    vec3 normal_normalized = normalize(NORMAL);
    vec3 base_normal_scaling = normal_normalized / vec3(10.0);

	// Переводим в пространство камеры
    vec3 view_space_pos = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// В пространстве камеры Z отрицательно направлена, поэтому ее следует развернуть
    float z_depth_positive = view_space_pos.z * -1.0;

    // Рассчитаем толщину в зависимости от расстояния до камеры
    float depth_thickness = z_depth_positive * 0.05;
    // ограничим размеры, чтобы толщина не была слишком большой или малой
    float clamped_thickness = clamp(depth_thickness, min_thickness, max_thickness);

    // Рассчет вуинального смещения
    vec3 final_offset = base_normal_scaling * vec3(clamped_thickness);
    VERTEX = final_offset + VERTEX;
	
	uv_interp = UV;
}

void fragment() {
    // Умножаем на томно-розовый цвет, чтобы цвет линии был темнее цвета текстуры
    ALBEDO = texture(albedo_texture, uv_interp).rgb * vec3(0.46, 0.33, 0.4);
}