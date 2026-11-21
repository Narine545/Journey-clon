shader_type canvas_item;

// =====================================================================
// «ЗОЛОЧЁНЫЙ ПРИЛИВ» · общий стиль кадра: vaporwave × gothic.
//
// Не ещё один колор-грейд — их уже делает ColorGrader. Этот слой отвечает
// за ТО, ЧЕМ два стиля отличаются от «просто тёплой картинки»:
//
//   vaporwave  → хроматическая аберрация по краям, холодный неон в тенях
//                (бирюза слева, маджента справа), тонкая развёртка строк;
//   готика     → тяжёлый виньет-арка над кадром, холодный ключ в светах
//                и золото в полутенях — как свет из витража на камне.
//
// Всё управляется тремя числами и выключается в ноль. Сила по умолчанию
// намеренно мала: стиль должен читаться как «у этого мира есть характер»,
// а не как фильтр из соцсети. Ночь усиливает неон, день — золото.
// =====================================================================

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;

/** Общая сила слоя: 0 — выключен, 1 — полный. */
uniform float intensity : hint_range(0.0, 1.0) = 0.55;
/** 0 — день, 1 — ночь. Двигает баланс «золото ↔ неон». */
uniform float night01 : hint_range(0.0, 1.0) = 0.0;
/** Сила виньет-арки и неона по краям. */
uniform float structure : hint_range(0.0, 1.0) = 0.5;
/** Хроматическая аберрация, доля экрана. */
uniform float aberration : hint_range(0.0, 0.02) = 0.0022;

uniform vec3 gilt : source_color = vec3(0.851, 0.690, 0.416);
uniform vec3 neon_a : source_color = vec3(0.384, 1.0, 0.902);
uniform vec3 neon_b : source_color = vec3(1.0, 0.416, 0.835);
uniform vec3 shade : source_color = vec3(0.043, 0.078, 0.106);

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 centered = uv - 0.5;
	float radius = length(centered * vec2(1.0, 0.86));

	// --- Хроматическая аберрация: к краю сильнее, в центре ноль. --------
	float edge = smoothstep(0.20, 0.78, radius);
	vec2 shift = normalize(centered + vec2(0.0001)) * aberration * edge;
	vec3 col;
	col.r = texture(screen_tex, uv + shift * 1.15).r;
	col.g = texture(screen_tex, uv).g;
	col.b = texture(screen_tex, uv - shift * 1.15).b;

	// --- Разделённый тон: бирюза слева, маджента справа ---------------
	// Умножается на яркость, чтобы чёрное небо не стало цветным.
	float lum = dot(col, vec3(0.2126, 0.7152, 0.0722));
	float side = clamp(centered.x * 1.6, -1.0, 1.0);
	vec3 split = mix(neon_a, neon_b, side * 0.5 + 0.5);
	float split_amount = 0.055 * structure * (0.35 + 0.75 * night01) * edge;
	col += split * split_amount * smoothstep(0.05, 0.45, lum);

	// --- Золото в полутенях, холод в светах ---------------------------
	// «Свет витража на камне»: полутени греются золотом, света уходят
	// в синеву. Ночью золота меньше — его заменяет неон окон.
	float mid = smoothstep(0.06, 0.42, lum) * (1.0 - smoothstep(0.55, 0.95, lum));
	float high = smoothstep(0.60, 1.0, lum);
	float gilt_amount = 0.13 * structure * (1.0 - 0.55 * night01);
	col = mix(col, col * mix(vec3(1.0), gilt * 1.35, mid), gilt_amount);
	col = mix(col, col * vec3(0.93, 0.98, 1.10), high * 0.25 * structure);

	// --- Готическая арка: виньет держит взгляд в центре ----------------
	// Не круг: сверху вырез глубже, снизу мягче — кадр «в раме окна».
	float arch = 1.0 - smoothstep(0.34, 0.92, radius * (1.0 + 0.16 * (0.5 - uv.y)));
	col = mix(col * mix(shade, vec3(1.0), 1.0 - 0.55 * structure), col, arch);

	// --- Тонкая развёртка строк: очень слабая, только в тени ----------
	float scan = 0.985 + 0.015 * sin(uv.y * 1080.0 * 3.14159);
	col *= mix(1.0, scan, structure * 0.35);

	// --- Зерно: убирает «пластиковую» гладкость рендера ---------------
	float grain = hash12(uv * vec2(1920.0, 1080.0) + fract(TIME) * 91.7) - 0.5;
	col += grain * 0.012 * structure;

	COLOR = vec4(mix(texture(screen_tex, uv).rgb, col, clamp(intensity, 0.0, 1.0)), 1.0);
}
