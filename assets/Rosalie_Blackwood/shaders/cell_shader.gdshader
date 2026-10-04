shader_type spatial;
render_mode blend_mix, depth_draw_opaque, depth_test_default, cull_back, diffuse_burley, shadows_disabled, depth_prepass_alpha;

// Общие параметры
uniform sampler2D albedo_texture : source_color;
uniform vec3 albedo_color : source_color = vec3(1.0);
uniform float albedo_saturation : hint_range(0.0, 2.0) = 1;
uniform float gamma : hint_range(0.0, 2.0) = 1.0;
uniform float alpha : hint_range(0.0, 1.0) = 1.0;
uniform bool use_texture = true;
uniform sampler2D shadow_texture : source_color, filter_linear_mipmap_anisotropic;
uniform float shadow_softness : hint_range(0.0, 0.2) = 0.05;
uniform float shadow_saturation : hint_range(0.3, 1.5) = 1.0;

// Параметры рефлекса
uniform bool emission = true;
uniform float emission_border : hint_range(0.5, 0.99) = 0.85;
uniform vec3 emission_color : source_color = vec3(1.0);

// Параметры для SDF режима
uniform bool use_sdf = false;
uniform sampler2D sdf_map : source_color;
uniform bool hard_transition = false;

// Параметры статичных теней
uniform bool use_static_shadow = false;
uniform sampler2D static_shadow_map : source_color;

// Параметры бликов
uniform bool use_specular = false;
uniform sampler2D specular_map : source_color;
uniform float specular_intensity : hint_range(0.0, 2.0) = 1.0;
uniform float specular_threshold : hint_range(0.0, 1.0) = 0.3;
uniform vec3 specular_color : source_color = vec3(1.0, 0.95, 0.9);
uniform float specular_power : hint_range(1.0, 64.0) = 16.0; // Степень резкости блика

varying vec2 uv2_coords;

void vertex() {
    uv2_coords = UV2;
}

void fragment() {
    vec3 base_color;
    float final_alpha = alpha;
    
    if (use_texture) {
        vec4 tex_color = texture(albedo_texture, UV);
        base_color = tex_color.rgb;
        final_alpha *= tex_color.a;
    } else {
        base_color = albedo_color;
    }
    
    vec3 final_albedo = pow(base_color.rgb, vec3(albedo_saturation));
    final_albedo = clamp(final_albedo, 0.0, 1.0);
    
	if (emission) {
		vec3 world_normal = normalize(MODEL_NORMAL_MATRIX * vec3(NORMAL));
		vec3 up_direction = vec3(0.0, 1.0, 0.0);
		float up_factor = dot(world_normal, up_direction);
		float rim_emission = smoothstep(0.0, 0.3, up_factor);
		
		float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 1.0);
		float rim_mask = step (emission_border, fresnel);
		
		float final_mask = rim_mask * rim_emission;
    	vec3 emission_final = min(vec3(final_mask), emission_color);
		
		EMISSION = emission_final;
	}
    
    ALBEDO = final_albedo;
    ALPHA = final_alpha;
}

void light() {
    vec3 normal = normalize(NORMAL);
    vec3 light_dir = normalize(LIGHT);
    
    float NdotL = dot(normal, light_dir);
    float normalized = NdotL * 0.5 + 0.5;
    
    float is_light;
    vec3 final_color;
    
    // --- SDF РЕЖИМ ---
    if (use_sdf) {
		vec3 world_normal = mat3(INV_VIEW_MATRIX) * NORMAL;
		vec3 local_normal = mat3(inverse(MODEL_MATRIX)) * world_normal;
		vec3 model_forward_xz =  normalize(local_normal * vec3(1.0, 0.0,1.0));
		
		float correction = 0.3; // 0 = полный идеал (0,0,1), 1 = полная нормаль
    	vec3 ideal_forward = vec3(0.0, 0.0, 1.0);
    	model_forward_xz = normalize(mix(ideal_forward, model_forward_xz, correction));
		
		vec3 world_light = mat3(INV_VIEW_MATRIX) * LIGHT;
		vec3 local_light = mat3(inverse(MODEL_MATRIX)) * world_light;
        vec3 light_xz = normalize(local_light * vec3(1.0, 0.0, 1.0));
        
        float NdotL_sdf = dot(model_forward_xz, light_xz);
        float angle_for_sdf =  NdotL_sdf * 0.5 + 0.5;
        angle_for_sdf = clamp(angle_for_sdf, 0.0, 1.0);

        float steps = 15.0 / 180.0;
        float discretized;
        if (hard_transition) {
            discretized = floor(angle_for_sdf / steps) * steps;
        } else {
            discretized = angle_for_sdf;
        }
		
        vec3 sdf = texture(sdf_map, uv2_coords).rgb;
        float sdf_value;
        if (light_xz.x > 0.0) {
            sdf_value = 1.0 - sdf.r;
        } else {
            sdf_value = 1.0 - sdf.g;
        } 
        
		is_light = step(sdf_value, discretized);
        
        if (NdotL_sdf < -0.9) {
            is_light = 0.0;
        }
        if (NdotL_sdf > 0.90) {
            is_light = 1.0;
        }
    } 
    // --- ОБЫЧНЫЙ РЕЖИМ ---
    else {
        float shadow_center = 0.5;
        is_light = smoothstep(shadow_center, shadow_center + shadow_softness, normalized);
        
        if (NdotL <= 0.0) {
            is_light = 0.0;
        }
    }
    
    // --- СТАТИЧНАЯ ТЕНЬ ---
    if (use_static_shadow) {
        float static_shadow = texture(static_shadow_map, uv2_coords).r;
        float static_shadow_factor = (1.0 - static_shadow);
        float dynamic_shadow_factor = 1.0 - is_light;
        float combined_shadow_factor = max(dynamic_shadow_factor, static_shadow_factor);
        is_light = 1.0 - combined_shadow_factor;
    }
	// Уменьшаем насыщенность тени
    vec3 shadow_color_final = texture(shadow_texture, UV).rgb / shadow_saturation;
    final_color = 1.0 - (1.0 - vec3(is_light)) * (1.0 - shadow_color_final);
    
    // --- ЛОГИКА БЛИКОВ ---
    vec3 specular_output = vec3(0.0);
    
    if (use_specular) {
        float specular_map_value = texture(specular_map, uv2_coords).r;
        float spec_raw = pow(normalized, specular_power);
        float spec_mask = smoothstep(specular_threshold, specular_threshold, specular_map_value);
        specular_output = specular_color * spec_raw * specular_intensity * spec_mask * 5.0;
		specular_output = specular_output * 5.0;
    }
    vec3 light_color_final = pow(LIGHT_COLOR, vec3(gamma));
    DIFFUSE_LIGHT = light_color_final * final_color + specular_output;
}