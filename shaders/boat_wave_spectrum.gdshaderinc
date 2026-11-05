// Семь направленных глубоководных компонент: omega² = g*k.
// Неравномерные длины, направления и фазы уменьшают видимую повторяемость.
// Сумма квадратов амплитуд сохранена относительно прежних трёх волн.
// CPU-зеркало: WaterField._spectrum_height().
const float WAVE_TAU = 6.28318530718;

float spectrum_height(vec2 xz, float time, vec2 wind, float amplitude, float power) {
	vec2 d = normalize(wind);
	vec2 d0 = vec2(d.x * 0.97814760 - d.y * -0.20791169, d.x * -0.20791169 + d.y * 0.97814760);
	float k0 = WAVE_TAU / 23.7;
	vec2 d1 = vec2(d.x * 0.99026807 - d.y * 0.13917310, d.x * 0.13917310 + d.y * 0.99026807);
	float k1 = WAVE_TAU / 17.3;
	vec2 d2 = vec2(d.x * 0.82903757 - d.y * 0.55919290, d.x * 0.55919290 + d.y * 0.82903757);
	float k2 = WAVE_TAU / 12.1;
	vec2 d3 = vec2(d.x * 0.77714596 - d.y * -0.62932039, d.x * -0.62932039 + d.y * 0.77714596);
	float k3 = WAVE_TAU / 8.3;
	vec2 d4 = vec2(d.x * 0.48480962 - d.y * 0.87461971, d.x * 0.87461971 + d.y * 0.48480962);
	float k4 = WAVE_TAU / 5.7;
	vec2 d5 = vec2(d.x * 0.39073113 - d.y * -0.92050485, d.x * -0.92050485 + d.y * 0.39073113);
	float k5 = WAVE_TAU / 3.9;
	vec2 d6 = vec2(d.x * 0.92050485 - d.y * 0.39073113, d.x * 0.39073113 + d.y * 0.92050485);
	float k6 = WAVE_TAU / 2.8;
	return amplitude * power * (
		0.49491911 * cos(k0 * dot(xz, d0) - sqrt(9.81 * k0) * time + 0.4)
		+ 0.44336503 * cos(k1 * dot(xz, d1) - sqrt(9.81 * k1) * time + 2.1)
		+ 0.39181096 * cos(k2 * dot(xz, d2) - sqrt(9.81 * k2) * time + 4.8)
		+ 0.31963526 * cos(k3 * dot(xz, d3) - sqrt(9.81 * k3) * time + 1.3)
		+ 0.25777037 * cos(k4 * dot(xz, d4) - sqrt(9.81 * k4) * time + 3.7)
		+ 0.18559467 * cos(k5 * dot(xz, d5) - sqrt(9.81 * k5) * time + 5.6)
		+ 0.12372978 * cos(k6 * dot(xz, d6) - sqrt(9.81 * k6) * time + 2.8));
}

vec2 spectrum_gradient(vec2 xz, float time, vec2 wind, float amplitude, float power) {
	vec2 d = normalize(wind);
	vec2 d0 = vec2(d.x * 0.97814760 - d.y * -0.20791169, d.x * -0.20791169 + d.y * 0.97814760);
	float k0 = WAVE_TAU / 23.7;
	vec2 d1 = vec2(d.x * 0.99026807 - d.y * 0.13917310, d.x * 0.13917310 + d.y * 0.99026807);
	float k1 = WAVE_TAU / 17.3;
	vec2 d2 = vec2(d.x * 0.82903757 - d.y * 0.55919290, d.x * 0.55919290 + d.y * 0.82903757);
	float k2 = WAVE_TAU / 12.1;
	vec2 d3 = vec2(d.x * 0.77714596 - d.y * -0.62932039, d.x * -0.62932039 + d.y * 0.77714596);
	float k3 = WAVE_TAU / 8.3;
	vec2 d4 = vec2(d.x * 0.48480962 - d.y * 0.87461971, d.x * 0.87461971 + d.y * 0.48480962);
	float k4 = WAVE_TAU / 5.7;
	vec2 d5 = vec2(d.x * 0.39073113 - d.y * -0.92050485, d.x * -0.92050485 + d.y * 0.39073113);
	float k5 = WAVE_TAU / 3.9;
	vec2 d6 = vec2(d.x * 0.92050485 - d.y * 0.39073113, d.x * 0.39073113 + d.y * 0.92050485);
	float k6 = WAVE_TAU / 2.8;
	return -amplitude * power * (
		0.49491911 * k0 * sin(k0 * dot(xz, d0) - sqrt(9.81 * k0) * time + 0.4) * d0
		+ 0.44336503 * k1 * sin(k1 * dot(xz, d1) - sqrt(9.81 * k1) * time + 2.1) * d1
		+ 0.39181096 * k2 * sin(k2 * dot(xz, d2) - sqrt(9.81 * k2) * time + 4.8) * d2
		+ 0.31963526 * k3 * sin(k3 * dot(xz, d3) - sqrt(9.81 * k3) * time + 1.3) * d3
		+ 0.25777037 * k4 * sin(k4 * dot(xz, d4) - sqrt(9.81 * k4) * time + 3.7) * d4
		+ 0.18559467 * k5 * sin(k5 * dot(xz, d5) - sqrt(9.81 * k5) * time + 5.6) * d5
		+ 0.12372978 * k6 * sin(k6 * dot(xz, d6) - sqrt(9.81 * k6) * time + 2.8) * d6);
}
