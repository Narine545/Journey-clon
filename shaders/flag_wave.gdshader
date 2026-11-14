shader_type canvas_item;
render_mode blend_mix;

// TIDECUT · сигнальный флаг.
// Вершинная волна: полотно колышется сильнее к свободной кромке, у древка
// стоит как вкопанное. Цвет плоский, задаётся Polygon2D.

uniform float amplitude = 12.0;
uniform float speed = 2.4;
uniform float droop = 1.0;
uniform vec2 cloth_size = vec2(420.0, 300.0);
uniform float time_offset = 0.0;
uniform float straighten : hint_range(0.0, 1.0) = 0.0;

void vertex() {
	float t = TIME * speed + time_offset;
	float k = clamp(VERTEX.x / max(1.0, cloth_size.x), 0.0, 1.0);
	// У древка вес нулевой, к свободному краю растёт квадратично.
	float weight = k * k * (1.0 - 0.55 * straighten);
	VERTEX.y += sin(VERTEX.x * 0.034 - t) * amplitude * weight;
	VERTEX.x -= abs(sin(VERTEX.x * 0.028 - t)) * 3.5 * weight;
	// Провисание: флаг «висит», пока его не подняли.
	VERTEX.y += droop * 26.0 * weight * weight * (1.0 - straighten);
}
