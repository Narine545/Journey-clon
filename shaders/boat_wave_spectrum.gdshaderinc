// Три дисперсионные волны глубокой воды: omega^2 = g*k.
// Одни и те же амплитуды, направления и частоты используются CPU-зеркалом
// WaterField и вершинами воды/ресурсных пятен.
const float WAVE_TAU = 6.28318530718;

float spectrum_height(vec2 xz, float time, vec2 wind, float amplitude, float power) {
	vec2 d1 = normalize(wind);
	vec2 d2 = normalize(vec2(d1.x * 0.80 - d1.y * 0.60, d1.x * 0.60 + d1.y * 0.80));
	vec2 d3 = normalize(vec2(d1.x * 0.52 + d1.y * 0.85, -d1.x * 0.85 + d1.y * 0.52));
	float k1 = WAVE_TAU / 18.0;
	float k2 = WAVE_TAU / 9.5;
	float k3 = WAVE_TAU / 4.5;
	return amplitude * power * (
		0.75 * cos(k1 * dot(xz, d1) - sqrt(9.81 * k1) * time)
		+ 0.45 * cos(k2 * dot(xz, d2) - sqrt(9.81 * k2) * time + 1.7)
		+ 0.22 * cos(k3 * dot(xz, d3) - sqrt(9.81 * k3) * time + 3.1));
}

vec2 spectrum_gradient(vec2 xz, float time, vec2 wind, float amplitude, float power) {
	vec2 d1 = normalize(wind);
	vec2 d2 = normalize(vec2(d1.x * 0.80 - d1.y * 0.60, d1.x * 0.60 + d1.y * 0.80));
	vec2 d3 = normalize(vec2(d1.x * 0.52 + d1.y * 0.85, -d1.x * 0.85 + d1.y * 0.52));
	float k1 = WAVE_TAU / 18.0;
	float k2 = WAVE_TAU / 9.5;
	float k3 = WAVE_TAU / 4.5;
	return -amplitude * power * (
		0.75 * k1 * sin(k1 * dot(xz, d1) - sqrt(9.81 * k1) * time) * d1
		+ 0.45 * k2 * sin(k2 * dot(xz, d2) - sqrt(9.81 * k2) * time + 1.7) * d2
		+ 0.22 * k3 * sin(k3 * dot(xz, d3) - sqrt(9.81 * k3) * time + 3.1) * d3);
}
