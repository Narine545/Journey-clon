shader_type spatial;
// ПЕСЧАНЫЕ СУЩЕСТВА — полноэкранный SDF-реймарчинг поверх «песчаного моря».
//
// Ядро взято из шейдера «Fullscreen SDF Raymarching with Smooth CSG and
// Depth» (CC0 1.0, Stratos / vav-labs, godotshaders.com): квад, пришпиленный
// к near-плоскости, sphere tracing по SDF-сцене, окклюзия по depth-буферу
// сцены, запись НАСТОЯЩЕЙ глубины и антиалиасные силуэты через конус
// пикселя. Distance functions after Inigo Quilez.
//
// Что здесь «сценой» (map()) вместо демо-фигур:
//   • РЫБЫ-«ПЕСЧАНЫЕ КИТЫ» (как существа Journey): хребет из 6 сфер +
//     морда + спинной гребень + хвостовая лопасть (2 эллипсоида), всё
//     через smooth union — тело плавится в жидкую ленту, цвета плавятся
//     вместе с формой. Сфера тут не единственная форма: SDF умеет любые
//     примитивы (капсулы, конусы, торы) — см. rot2()/sd_ell() ниже.
//     Волна бежит по хребту к хвосту (хвост виляет сильнее) — фазу пушит
//     sand_fish.gd;
//   • БРЫЗГИ: кластеры капель (парбол на CPU), плавящиеся друг с другом
//     и с телом выпрыгнувшей рыбы — тот самый «metaball melt»;
//   • «ВУАЛЬ»: рыбы, скользящие ПОД поверхностью моря. Реймарчинг их не
//     видит (depth-тест моря прячет всё, что ниже), поэтому подповерхност-
//     ных рыб рисуем отдельным слоем: точка, где луч касается плоскости
//     моря, затемняется и слегка тонируется — под песком ползёт тёмный
//     бугор. В момент прыжка SDF-тело и «вуаль» срастаются в одно.
//
// Окклюзия делает всё остальное: часть тела ниже уровня моря автоматически
// прячется за морем, часть выше — стоит перед ним и пишет свою глубину
// (прозрачные объекты после неё тестируются уже против рыбы).
//
// Согласование с водой: палитра/туман — те же uniform-ы, что у water.gdshader;
// глубину для «вуали» берем из depth-текстуры, уровень моря — uniform.
//
// Требования: Godot 4.3+ (reversed-Z), Forward+. Квад создаёт sand_fish.gd,
// он же пушит все uniform-ы (рыбы, капли, центр обитания — за камерой).

render_mode unshaded, fog_disabled, depth_test_disabled, depth_draw_always, cull_disabled;

// ===== Качество реймарчинга (как у оригинала) =====
uniform float epsilon = 0.01;
uniform float max_ray_distance = 512.0;
uniform int max_steps = 96;

// ===== Свет — та же закатная палитра, что у воды/песка =====
uniform vec3 sun_dir = vec3(0.10, 0.26, -0.96); // к солнцу (как у песка)
uniform vec3 sand_sunny : source_color = vec3(0.93, 0.52, 0.30);
uniform vec3 sand_hot : source_color = vec3(1.00, 0.68, 0.36);
uniform vec3 sand_shade : source_color = vec3(0.40, 0.32, 0.52);
uniform vec3 horizon_col : source_color = vec3(0.96, 0.66, 0.55);
uniform vec3 sky_col : source_color = vec3(0.28, 0.24, 0.43);
uniform float fog_distance = 340.0;

// ===== Сцена =====
uniform float u_water_level = 0.0;
uniform float u_time = 0.0;
uniform vec2 u_center = vec2(0.0, 0.0); // центр обитания (идёт за камерой)
uniform float u_bounds_r = 130.0;       // радиус обитания, м

// Рыбы: 6 слотов стаи + 1 слот пойманной рыбы; meta.x <= 0.001 — пусто
uniform vec4 u_fish_state[7]; // xyz — центр тела, w — курс (рад)
uniform vec2 u_fish_meta[7];  // x — размер (м), y — фаза волны тела
uniform vec3 u_fish_tint[7];  // базовый цвет существа
uniform float u_catch_flex = 1.0; // улов в центре экрана: меньше перегиба тела

// Брызги: 12 слотов; w <= 0.004 — слот пуст (анимация целиком на CPU)
uniform vec4 u_drops[12]; // xyz — центр, w — радиус
uniform vec3 u_drop_tint : source_color = vec3(0.98, 0.62, 0.38);

// «Вуаль» — силуэты под поверхностью
uniform float u_veil_strength = 0.42;

uniform sampler2D depth_texture : hint_depth_texture, filter_nearest;
uniform sampler2D u_screen : hint_screen_texture, filter_linear;

// ---- детерминированный хеш (ТЕ ЖЕ, что у воды/песка) ----
float hash12(vec2 p) {
        vec3 p3 = fract(vec3(p.xyx) * 0.1031);
        vec3 q = p3.yzx + vec3(33.33);
        p3 += vec3(dot(p3, q));
        return fract((p3.x + p3.y) * p3.z);
}

// ===== CSG на парах (цвет, дистанция) — из оригинала (CC0, vav-labs) =====
// IQ smooth min: плавятся и форма, и цвет. Результат <= min(a, b),
// т.е. дистанция остаётся консервативной — sphere tracing безопасен.
vec4 sdf_smooth_union(vec4 a, float d, vec3 col, float k) {
        k = max(k, 1e-6);
        float h = clamp(0.5 + 0.5 * (d - a.w) / k, 0.0, 1.0);
        return vec4(mix(col, a.rgb, h), mix(d, a.w, h) - k * h * (1.0 - h));
}

// ===== Примитивы плавников (сфера — не единственная форма в SDF!) =====
// Поворот точки в плоскости (dir, up) — локальные координаты хвоста.
vec2 rot2(vec2 v, float a) {
        float c = cos(a);
        float sn = sin(a);
        return vec2(c * v.x - sn * v.y, sn * v.x + c * v.y);
}

// Сплюснутый эллипсоид (Inigo Quilez). Оценка консервативна
// (<= настоящей дистанции), так что sphere tracing остаётся безопасным.
float sd_ell(vec3 p, vec3 r) {
        float k0 = length(p / r);
        return min(r.x, min(r.y, r.z)) * (k0 - 1.0);
}

// ===== Тело существа i в точке p =====
// Хребет: 6 сфер от морды к хвосту; волна sin(phase - t*4.2) бежит назад,
// амплитуда растёт к хвосту (0.05s -> 0.43s) — та же пластика, что у
// «дыхания» моря, только быстрая. Плюс морда, спинной гребень и хвостовая
// лопасть-«ласта» из двух сплюснутых эллипсоидов.
vec4 fish_sdf(vec3 p, vec3 C, float s, float heading, float phase, vec3 tint,
        float body_flex) {
        vec3 dir = vec3(cos(heading), 0.0, sin(heading));
        vec3 side = vec3(-dir.z, 0.0, dir.x);
        vec3 up = vec3(0.0, 1.0, 0.0);
        float L = 2.4 * s;

        vec4 acc = vec4(0.0, 0.0, 0.0, 1e9);

        // хребет (морда -> хвост)
        for (int k = 0; k < 6; k++) {
                float t = float(k) / 5.0;
                float lat = sin(phase - t * 4.2) * s * (0.05 + 0.38 * t) * body_flex;
                float vert = sin(phase - t * 3.1 + 1.3) * s * 0.10 * t * body_flex;
                vec3 c = C + dir * ((0.5 - t) * L) + side * lat + up * vert;
                float r = s * (0.40 - 0.18 * t);
                vec3 col = mix(tint * 1.15, tint * 0.70, t); // спина светлее хвоста
                acc = sdf_smooth_union(acc, length(p - c) - r, col, 0.46 * s);
        }

        // морда
        vec3 sn = C + dir * (0.74 * L);
        acc = sdf_smooth_union(acc, length(p - sn) - s * 0.16, tint * 0.92, 0.22 * s);

        // спинной плавник: толстый тор без «дырки» — цельный гребень
        vec3 q = p - (C + dir * (0.12 * L) + up * (0.30 * s));
        vec2 tq = vec2(length(vec2(dot(q, dir), dot(q, up))) - 0.17 * s, dot(q, side));
        acc = sdf_smooth_union(acc, length(tq) - 0.085 * s, tint * 1.08, 0.12 * s);

        // хвостовая лопасть: два сплюснутых эллипсоида, растущих из стебля
        // назад-вверх и назад-вниз. Стебель НАСЛЕДУЕТ волну хребта (та же
        // формула при t = 1: lat 0.43s, vert 0.10s) — хвост приклеен к
        // последней сфере хребта и больше не отстаёт на вилях.
        vec3 stem = C - dir * (0.5 * L)
                + side * (sin(phase - 4.2) * 0.43 * s * body_flex)
                + up * (sin(phase - 1.8) * 0.10 * s * body_flex);
        vec3 qt = p - stem;
        vec3 ql = vec3(dot(qt, dir), dot(qt, up), dot(qt, side));
        // поворот в (dir, up): +угол валит лопасть назад-вверх,
        // -угол — назад-вниз; по боку эллипсоид тонкий (ql.z)
        vec2 qu = rot2(ql.xy, 0.62) + vec2(0.36 * s, 0.0);
        vec2 qd = rot2(ql.xy, -0.50) + vec2(0.32 * s, 0.0);
        float du = sd_ell(vec3(qu.x, qu.y, ql.z), vec3(0.34 * s, 0.095 * s, 0.038 * s));
        float dl = sd_ell(vec3(qd.x, qd.y, ql.z), vec3(0.30 * s, 0.085 * s, 0.034 * s));
        acc = sdf_smooth_union(acc, du, tint * 0.90, 0.15 * s);
        acc = sdf_smooth_union(acc, dl, tint * 0.90, 0.15 * s);

        return acc;
}

// ===== СЦЕНА — единственная функция, знающая мир =====
// Возвращает (цвет.rgb, дистанция.w). Дистанция консервативна: пропущенные
// (далёкие) объекты учитываются через dskips — их сферическая граница,
// чтобы ray не переступил через невидимую рыбу.
vec4 map(vec3 p) {
        vec4 acc = vec4(0.0, 0.0, 0.0, 1e9);
        float dskips = 1e9;

        for (int i = 0; i < 7; i++) {
                float s = u_fish_meta[i].x;
                if (s < 0.001) {
                        continue;
                }
                vec3 C = u_fish_state[i].xyz;
                float bd = length(p - C) - 2.1 * s; // до сферической границы тела
                if (bd > 0.7 * s + 0.1) {
                        dskips = min(dskips, bd);
                        continue;
                }
                float body_flex = (i == 6) ? u_catch_flex : 1.0;
                vec4 f = fish_sdf(p, C, s, u_fish_state[i].w, u_fish_meta[i].y,
                        u_fish_tint[i], body_flex);
                acc = sdf_smooth_union(acc, f.w, f.rgb, 0.42 * s);
        }

        for (int j = 0; j < 12; j++) {
                vec4 d = u_drops[j];
                if (d.w < 0.004) {
                        continue;
                }
                float dd = length(p - d.xyz) - d.w;
                if (dd > 0.35) {
                        dskips = min(dskips, dd);
                        continue;
                }
                acc = sdf_smooth_union(acc, dd, u_drop_tint, 0.07);
        }

        return vec4(acc.rgb, min(acc.w, dskips));
}

float map_dist(vec3 p) { return map(p).w; }

// Тетраэдральный градиент (4 касания) — из оригинала.
vec3 estimate_normal(vec3 p) {
        float e = max(epsilon * 0.5, 0.002);
        vec2 k = vec2(1.0, -1.0);
        return normalize(
                k.xyy * map_dist(p + k.xyy * e) +
                k.yyx * map_dist(p + k.yyx * e) +
                k.yxy * map_dist(p + k.yxy * e) +
                k.xxx * map_dist(p + k.xxx * e));
}

void vertex() {
        // Пришиваем квад к near-плоскости -> полноэкранность
        // (reversed-Z: near = 1.0). Позиция ноды не важна.
        POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

void fragment() {
        float eps = max(epsilon, 1e-4);
        int steps = clamp(max_steps, 1, 512);
        vec2 ndc_xy = SCREEN_UV * 2.0 - 1.0;
        // Луч через пиксель — через far-плоскость (reversed-Z: far = 0).
        vec4 far_view = INV_PROJECTION_MATRIX * vec4(ndc_xy, 0.0, 1.0);
        far_view.xyz /= far_view.w;
        vec3 cam_pos = INV_VIEW_MATRIX[3].xyz;
        vec3 rd = normalize((INV_VIEW_MATRIX * vec4(normalize(far_view.xyz), 0.0)).xyz);
        float max_dist = min(max(max_ray_distance, 0.01), length(far_view.xyz));

        // Окклюзия: геометрия сцены останавливает луч.
        float depth_raw = texture(depth_texture, SCREEN_UV).r;
        float scene_t = -1.0;
        vec3 scene_pos = vec3(0.0);
        if (depth_raw > 0.0001) {
                vec4 dview = INV_PROJECTION_MATRIX * vec4(ndc_xy, depth_raw, 1.0);
                dview.xyz /= dview.w;
                scene_t = length(dview.xyz);
                scene_pos = cam_pos + rd * scene_t;
                max_dist = min(max_dist, scene_t);
        }

        float alpha = 0.0;
        vec3 out_col = vec3(0.0);
        float out_depth = depth_raw;

        // Сфера обитания: вне её делать нечего (и дёшево, и без артефактов).
        vec3 bc = vec3(u_center.x, u_water_level, u_center.y);
        vec3 oc = cam_pos - bc;
        float bb = dot(oc, rd);
        float cc = dot(oc, oc) - u_bounds_r * u_bounds_r;
        float disc = bb * bb - cc;

        if (disc > 0.0) {
                float sq = sqrt(disc);
                float t_near = max(-bb - sq, 0.0);
                float t_far = min(-bb + sq, max_dist);

                if (t_near < t_far) {
                        // Конус пикселя — для антиалиасных силуэтов.
                        float pixel_angle = 2.0 / (VIEWPORT_SIZE.y * PROJECTION_MATRIX[1][1]);
                        float t = t_near;
                        bool hit = false;
                        float coverage = 1e9;
                        float t_edge = t_near;
                        for (int s = 0; s < steps; s++) {
                                if (t + eps > t_far) {
                                        break;
                                }
                                float d = map_dist(cam_pos + rd * t);
                                if (d < eps) {
                                        hit = true;
                                        break;
                                }
                                float ratio = d / max(t * pixel_angle, 1e-6);
                                if (ratio < coverage) {
                                        coverage = ratio;
                                        t_edge = t;
                                }
                                t += max(d, 0.001);
                        }

                        if (hit || coverage < 1.0) {
                                // ---- попадание: свет «мокрого песка» ----
                                float shade_t = t;
                                if (hit) {
                                        alpha = 1.0;
                                } else {
                                        alpha = clamp(1.0 - coverage, 0.0, 1.0);
                                        shade_t = t_edge;
                                }
                                vec3 p = cam_pos + rd * shade_t;
                                vec4 sc = map(p);
                                vec3 albedo = sc.rgb;
                                vec3 n = estimate_normal(p);
                                vec3 v = -rd;
                                vec3 l = normalize(sun_dir);

                                float ndl = dot(n, l);
                                float wrap = clamp((ndl + 0.45) / 1.05, 0.0, 1.0);
                                vec3 col = albedo * (sky_col * 0.55
                                        + sand_sunny * (0.22 + 0.95 * wrap));
                                // солнечная кромка — как у моря
                                col += sand_hot * pow(clamp(ndl, 0.0, 1.0), 2.2) * 0.26;
                                // тёплый отсвет снизу, отскочивший от дюн
                                vec3 B = normalize(vec3(-l.x, 0.55, -l.z));
                                col += vec3(1.00, 0.58, 0.32)
                                        * clamp(dot(n, B), 0.0, 1.0) * 0.20 * (1.0 - wrap * 0.6);
                                // блик + сиреневый рим
                                vec3 h = normalize(l + v);
                                float ndv = clamp(dot(n, v), 0.0, 1.0);
                                col += vec3(1.0, 0.85, 0.60)
                                        * pow(clamp(dot(n, h), 0.0, 1.0), 42.0) * 0.55;
                                col += sand_shade * pow(1.0 - ndv, 3.0) * 0.30;

                                // глиттер «мокрого песка»: редкие вспышки на теле
                                vec2 gp = floor(p.xz * 5.0);
                                float gid = hash12(gp);
                                float gsel = step(1.0 - 0.15, gid);
                                vec3 Hg = normalize(h + vec3(
                                        hash12(gp + vec2(3.1, 7.7)),
                                        hash12(gp + vec2(5.7, 1.3)),
                                        hash12(gp + vec2(9.2, 4.4))) - 1.5);
                                float glit = pow(clamp(dot(n, Hg), 0.0, 1.0), 50.0) * gsel
                                        * (0.5 + 0.5 * sin(u_time * 6.0 + gid * 71.0));
                                col += vec3(1.0, 0.92, 0.70) * glit * 1.2 * exp(-shade_t * 0.004);

                                // дымка — та же формула, что у моря
                                float fog = 1.0 - exp(-pow(shade_t / fog_distance, 2.1));
                                float above = smoothstep(-2.0, 16.0, p.y - cam_pos.y);
                                vec3 fcol = mix(horizon_col, sky_col, above * 0.6);
                                col = mix(col, fcol, fog);

                                out_col = col;
                                vec4 clip = PROJECTION_MATRIX * (VIEW_MATRIX * vec4(p, 1.0));
                                out_depth = clip.z / clip.w;
                        } else {
                                // ---- «вуаль»: силуэты под поверхностью моря ----
                                // Морько видно там, где сцена в этой точке — плоскость
                                // уровня воды (допуск покрывает «дыхание» и кольца).
                                if (scene_t > 0.0 && cam_pos.y > u_water_level + 0.05
                                                && rd.y < -0.02
                                                && abs(scene_pos.y - u_water_level) < 0.45) {
                                        float fz = 1.0 - exp(-pow(scene_t / fog_distance, 2.1));
                                        if (fz < 0.97) {
                                                float m = 0.0;
                                                vec3 tw = vec3(0.0);
                                                for (int i = 0; i < 7; i++) {
                                                        float s = u_fish_meta[i].x;
                                                        if (s < 0.001) {
                                                                continue;
                                                        }
                                                        vec3 C = u_fish_state[i].xyz;
                                                        float sub = u_water_level - C.y;
                                                        if (sub < 0.05) {
                                                                continue; // центр над водой — тело видно само
                                                        }
                                                        float vis = exp(-sub / max(s * 1.0, 0.25));
                                                        vec2 e = scene_pos.xz - C.xz;
                                                        vec2 dir2 = vec2(cos(u_fish_state[i].w),
                                                                sin(u_fish_state[i].w));
                                                        vec2 prp2 = vec2(-dir2.y, dir2.x);
                                                        // вытянутый бугор вдоль курса
                                                        float d2 = length(vec2(dot(e, dir2),
                                                                dot(e, prp2) * 1.8));
                                                        float R = s * 1.5 + sub * 0.6;
                                                        // 1 - smoothstep с возрастающими краями
                                                        // (edge0 >= edge1 в GLSL — UB)
                                                        float mi = (1.0 - smoothstep(R * 0.25, R, d2))
                                                                * vis * (1.0 - fz);
                                                        m = max(m, mi);
                                                        tw += u_fish_tint[i] * mi;
                                                }
                                                if (m > 0.003) {
                                                        vec3 avg = tw / max(m, 1e-4);
                                                        vec3 scene_col = texture(u_screen, SCREEN_UV).rgb;
                                                        out_col = scene_col
                                                                * mix(1.0, 0.66, clamp(m * 0.9, 0.0, 1.0))
                                                                + avg * 0.20 * m;
                                                        alpha = clamp(m * u_veil_strength * 0.85, 0.0, 0.42);
                                                }
                                        }
                        }
                }
        }
        }

        ALBEDO = out_col;
        ALPHA = alpha;
        DEPTH = out_depth;
}
