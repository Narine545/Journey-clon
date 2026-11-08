// Gameplay-only palette: local fog cannot wash every archetype into the same grey.
// Depth testing and opaque depth writing remain enabled. No emitted world light.
shader_type spatial;
render_mode unshaded, fog_disabled;
varying vec3 enemy_tint;
void vertex() {
	enemy_tint = COLOR.rgb;
}
void fragment() {
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	ALBEDO = enemy_tint * (0.72 + 0.28 * facing);
}
