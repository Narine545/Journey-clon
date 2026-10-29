shader_type canvas_item;

// Радиус рассчитывается в единицах высоты экрана: круг не растягивается
// при любом соотношении сторон. Альфа позволяет плавно входить в оптику.
uniform float scope_amount : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 p = SCREEN_UV - vec2(0.5);
	p.x *= SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	float r = length(p);
	float black = smoothstep(0.442, 0.452, r);
	float vignette = smoothstep(0.27, 0.45, r) * 0.24;
	COLOR = vec4(0.008, 0.008, 0.007, max(black, vignette) * scope_amount);
}
