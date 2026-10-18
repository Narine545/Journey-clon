shader_type canvas_item;
render_mode unshaded, blend_add;

// Shadow mask uses scene luminance (Stars in Shadows); star field is
// generated entirely in shader (Star shaders v2.0-inspired), with no image.
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float night_amount : hint_range(0.0, 1.0) = 0.0;
uniform float intensity : hint_range(0.0, 2.0) = 0.72;
uniform float start_stars : hint_range(0.0, 1.0) = 0.38;
uniform float brightness_max : hint_range(0.0, 1.0) = 0.72;
uniform float star_size : hint_range(12.0, 240.0) = 92.0;
uniform float star_frequency : hint_range(0.01, 0.5) = 0.08;
uniform float drift_speed : hint_range(0.0, 1.0) = 0.035;
uniform float twinkle_speed : hint_range(0.0, 12.0) = 3.8;
uniform float seed = 11.7;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 345.45) + seed);
	p += dot(p, p + 34.345);
	return fract(p.x * p.y);
}

vec3 star_palette(float value) {
	vec3 cool = vec3(0.40, 0.66, 1.00);
	vec3 white = vec3(1.00, 0.91, 0.78);
	vec3 warm = vec3(1.00, 0.50, 0.30);
	return mix(mix(cool, white, smoothstep(0.15, 0.72, value)), warm,
		smoothstep(0.82, 1.0, value) * 0.50);
}

vec3 star_layer(vec2 pixel, float layer_id) {
	float scale = max(star_size / exp2(layer_id), 8.0);
	vec2 drift = vec2(0.73, -0.41) * TIME * drift_speed * (0.35 + layer_id * 0.31);
	vec2 grid = (pixel + drift * scale) / scale;
	vec2 cell = floor(grid);
	vec2 local = fract(grid) - 0.5;
	float key = hash21(cell + vec2(layer_id * 17.13, seed));
	if (key > star_frequency * exp2(-layer_id * 1.8)) {
		return vec3(0.0);
	}

	vec2 jitter = vec2(hash21(cell + 4.7 + layer_id),
		hash21(cell + 19.1 + layer_id)) - 0.5;
	vec2 delta = (local - jitter * 0.70) * scale;
	float distance_px = length(delta);
	float phase = TIME * twinkle_speed * (0.45 + hash21(cell + 8.9) * 1.3)
		+ key * 6.2831853;
	float pulse = 0.58 + 0.42 * (0.5 + 0.5 * sin(phase));
	float core = exp(-distance_px / max(0.75, scale * 0.025));
	float ray_x = exp(-abs(delta.x) / max(0.65, scale * 0.012))
		* exp(-abs(delta.y) / max(2.0, scale * 0.16));
	float ray_y = exp(-abs(delta.y) / max(0.65, scale * 0.012))
		* exp(-abs(delta.x) / max(2.0, scale * 0.16));
	float shape = max(core, max(ray_x, ray_y) * 0.38);
	float size_weight = 1.0 / (1.0 + layer_id * 0.60);
	return star_palette(hash21(cell + 31.2)) * shape * pulse * size_weight;
}

float luminance_at(vec2 uv) {
	vec3 c = texture(screen_texture, clamp(uv, vec2(0.001), vec2(0.999))).rgb;
	return dot(c, vec3(0.2126, 0.7152, 0.0722));
}

void fragment() {
	vec4 scene = texture(screen_texture, SCREEN_UV);
	float luminance = dot(scene.rgb, vec3(0.2126, 0.7152, 0.0722));
	float darkness = 1.0 - luminance;
	float mask_low = 1.0 - brightness_max;
	float mask_high = max(1.0 - start_stars, mask_low + 0.001);
	float darkness_mask = smoothstep(mask_low, mask_high, darkness);

	// Require a dark pixel to be visibly darker than its local surroundings.
	// This approximates cast-shadow regions and prevents stars over the whole
	// night sky / uniformly dark screen like a full-screen HUD overlay.
	vec2 r = vec2(0.034, 0.025);
	float bright_neighbour = luminance;
	bright_neighbour = max(bright_neighbour, luminance_at(SCREEN_UV + vec2(r.x, 0.0)));
	bright_neighbour = max(bright_neighbour, luminance_at(SCREEN_UV - vec2(r.x, 0.0)));
	bright_neighbour = max(bright_neighbour, luminance_at(SCREEN_UV + vec2(0.0, r.y)));
	bright_neighbour = max(bright_neighbour, luminance_at(SCREEN_UV - vec2(0.0, r.y)));
	bright_neighbour = max(bright_neighbour, luminance_at(SCREEN_UV + vec2(r.x, r.y)));
	bright_neighbour = max(bright_neighbour, luminance_at(SCREEN_UV + vec2(-r.x, r.y)));
	bright_neighbour = max(bright_neighbour, luminance_at(SCREEN_UV + vec2(r.x, -r.y)));
	bright_neighbour = max(bright_neighbour, luminance_at(SCREEN_UV - vec2(r.x, r.y)));
	float local_shadow = smoothstep(0.07, 0.22, bright_neighbour - luminance);
	float world_region = smoothstep(0.38, 0.52, SCREEN_UV.y);
	float shadow_mask = darkness_mask * local_shadow * world_region;
	float night = smoothstep(0.12, 0.82, night_amount);

	vec3 stars = vec3(0.0);
	for (int i = 0; i < 4; i++) {
		stars += star_layer(FRAGCOORD.xy, float(i));
	}
	// Sparse pinpricks remain visible at every scale, while the four layers
	// carry the slow drift and cross-ray twinkle.
	vec2 tiny_cell = floor(FRAGCOORD.xy / 3.0);
	float tiny_key = hash21(tiny_cell + 87.1);
	float tiny_pulse = 0.45 + 0.55 * (0.5 + 0.5 * sin(TIME * twinkle_speed * 1.7 + tiny_key * 31.0));
	float pin = step(0.9990, tiny_key) * tiny_pulse;
	stars += vec3(0.62, 0.78, 1.0) * pin;

	float mask = shadow_mask * night * intensity;
	COLOR = vec4(stars * mask, 1.0);
}
