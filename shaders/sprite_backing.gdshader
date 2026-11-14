shader_type canvas_item;
render_mode blend_mix;

// TIDECUT · белая подложка-силуэт под спрайтом персонажа.
// Рисует сам спрайт, а под ним — его же силуэт, расширенный на spread px и
// залитый одним цветом (как белая кайма у наклейки). Недовырезанные белые
// точки в прядях и полостях волос сливаются с подложкой и перестают читаться
// как брак. Плоско, без размытия.

uniform vec4 backing_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float spread : hint_range(0.0, 40.0) = 14.0;
uniform float cutoff : hint_range(0.0, 1.0) = 0.35;

const int RING = 16;

void fragment() {
	vec4 sprite = texture(TEXTURE, UV);
	float cover = step(cutoff, sprite.a);
	// Два кольца выборок: силуэт расширяется и заодно закрывает узкие полости.
	for (int i = 0; i < RING; i++) {
		float angle = 6.2831853 * float(i) / float(RING);
		vec2 dir = vec2(cos(angle), sin(angle)) * TEXTURE_PIXEL_SIZE;
		cover = max(cover, step(cutoff, texture(TEXTURE, UV + dir * spread).a));
		cover = max(cover, step(cutoff, texture(TEXTURE, UV + dir * spread * 0.5).a));
	}
	vec3 rgb = mix(backing_color.rgb, sprite.rgb, sprite.a);
	COLOR = vec4(rgb, max(cover * backing_color.a, sprite.a)) * COLOR;
}
