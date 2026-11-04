# Ревью освещения лодочной сцены — материал для передачи разработчику

**Срез:** `d97c301` ветки `arena/c0cfd826-journey-clon` (04.11.2026). Godot 4.7.2, Forward+; основная сцена `res://scenes/boat_main.tscn`. Исходники этого среза приведены ниже **текстом, без архива**; ссылки на исходники: https://github.com/Narine545/Journey-clon/tree/d97c301 . Документ — анализ и передача задачи, **не** новая правка освещения.

## 1. Постановка задачи и ограничения

Пользователь сравнил режимы и сообщил: **Filmic выглядит просто более светлым, AgX тоже не решает проблему.** Освещение воспринимается плоским и плохо связанным между водой, лодкой, берегом, небом и туманом. Нужна не замена одного тонмаппера другим, а согласованная модель света, теней и атмосферы. Ранее пользователю не понравились искусственная лунная дорожка, засветка вокруг лодки и глобальное посветление при включении маяка. Ночью нужны темнота и туман, но различимая форма объектов.

**Не ломать без отдельного согласования:** видимый естественный глиттер (не пытаться скрыть проблему его приглушением); отсутствие сканирующих светлых полос, диагональной границы двух цветов моря, светящихся крестов и неподвижной «линзы»/виньетки в кадре; подтверждённую видимость цветных пятен, прежнюю береговую линию, насос слева, качку, прицеп, кильватер и рецепты маяков. Старая рыболовная сцена (`scenes/main.tscn`) использует общие `world.gd`, `coast.gd` и `water_surface.gd`, поэтому лодочные изменения лучше изолировать. Пользователь просил **не ждать долгих визуальных CI-прогонов** — ему удобно оценивать кадры в игре самому.

## 2. Краткий вывод: почему Filmic/AgX сами по себе не помогают

**Подтверждено чтением кода (не оценкой кадра):** материал песка уже вычисляет освещённость склонов от `sun_dir` и оттенок неба в `ALBEDO`, затем собственный `light()` снова прибавляет физический прямой свет. Море тоже формирует цвет, френель, «отражение неба», самостоятельную дымку и блёстки в `ALBEDO` до работы реального освещения. В финале его PBR-нормаль почти плоская. Поэтому коррекция HDR→LDR (Filmic/AgX) может поменять яркость/контраст, но не починит несогласованность источников или отсутствующую форму воды. У HDR-неба, WorldEnvironment и ручных цветов воды/песка **нет единой фотометрической привязки**. Нужен раздельный аудит каждого вклада.

**Критичная гипотеза для проверки:** в `sky_plus.gdshader:451–461,261` рассеяние атмосферы вычисляется с константным `vec3(1.0, 0.996, 0.98)` и отдельным `exposure`, а не масштабируется пропорционально `LIGHT0_ENERGY`. Поэтому уменьшение энергии направленного света до ночного уровня и выключение диска солнца **не обязаны** аналогично затемнить небо/окружающую среду. Сопоставить буфер sky radiance и итоговый кадр при `[5]`: если это источник рассинхронизации, исправлять именно связи «светило → радианс неба → ambient/reflection», а не просто глобальную экспозицию.

**Вторая критичная гипотеза:** море пишет `ALPHA` в `blend_mix` + `depth_draw_opaque`, выводится в прозрачном проходе с `render_priority=-10`/`sorting_offset=-4096` ради правильной видимости пятен. Screen-space SSAO/SSIL и буфер глубины при таком порядке **могут не учитывать воду так же, как непрозрачный берег и лодку**. Не утверждать без визуализации SSAO/SSIL/depth; не отменять эти параметры вслепую — прежняя ошибка глубины скрывала пятна.

## 3. Где формируется свет: карта данных

1. `project.godot:30–36` — Forward+ и MSAA; `scenes/boat_main.tscn` содержит **только** корневой `BoatMain`, все световые узлы создаются из скриптов.
2. `scripts/game.gd` (`GameState`) — `sun_dir`, `night01`, `wind_strength`; не задаёт HDR-экспозицию.
3. `scripts/boat_main.gd:56–113` — создаёт `GameWorld` → `Coast`/`SandField` → `WaterSurface` с **лодочным** `shaders/water_boat.gdshader` → `BoatVessel` → маяки, рифы → ортокамеру и HUD. Профиль AgX включён по умолчанию (`debug_lighting_profile=true`). Камера `PROJECTION_ORTHOGONAL` и `size=32`; ось камеры влияет на экранное восприятие бликов.
4. `scripts/boat_main.gd:116–146` — `_apply_atmosphere(night01)` до 0.88: в строгом порядке `world.apply_night01` → `coast.set_night01` → `water.apply_night01` → вычисление направления → `world.apply_sun` → `world.fade_boat_sun` → `coast.apply_sun` → `water.apply_sun` → **повторная установка** палитры и параметров воды. Последняя запись побеждает. Вызывается при старте и затем примерно раз в 0.15 с (`:753–760`). Пресеты `[5]`: 0, 0.45, 0.88; фиксация времени, `[7]` продолжает.
5. `scripts/world.gd` — `WorldEnvironment` с `Sky++`/fallback, DirectionalLight3D, sky-ambient, Filmic/AgX, glow, SSAO, SSIL, обычный + объёмный туман. Нет SDFGI и запечённого GI. `configure_boat_lighting([L])` **одновременно** меняет тонмаппер, корректировку цвета, ambient sky contribution, SSAO, SSIL и дальность теней; `[L]` не является чистым A/B-тестом **только** Filmic против AgX. `fade_boat_sun` после `apply_night01` снова записывает энергию света, ambient, exposure и туман. Конкретные значения — в коде ниже.
6. `scripts/coast.gd:449–478` + `shaders/sand.gdshader` — независимые дневная/ночная палитры, собственные `sun_dir`, имитация sky/ground bounce/AO в материале, собственная дистанционная дымка и `light()`. В лодке `orthographic_glitter=1.0`. Ночной цвет песка не определяется одной настройкой WorldEnvironment.
7. `scripts/water_surface.gd:36–70,112–156` + `shaders/water_boat.gdshader` — отдельная палитра, CPU/GPU-волны, глубина берега, shader-fog, ручное `sky_ref`, микроблики и `light()`. `apply_night01` назначает цвета/глиттер, но `BoatMain._apply_atmosphere` **перезаписывает** цвета и `glitter_amount` (на ночь до `0.18`); пена и `fog_distance` остаются из `WaterSurface`. Не путать три независимых вещи: `glitter_amount` (точки), `sun_path_amount` (широкая дорожка; к ночи 0) и `direct_specular_amount` (PBR-отклик; `0.018`).
8. `scripts/boat_vessel.gd:105–113,700–715,800–813` — тёплые SpotLight3D/OmniLight3D привязаны к качающемуся корпусу; ночью `spot_energy≈0.85` и range≈26 м, палубный omni≈0.28/range5.5. Разные материалы корпуса с собственными emission/metal/roughness; это не глобальная луна.
9. `scripts/boat_main.gd:165–268,601–625` — после `[E]` маяк меняет emissive-материалы, зажигает OmniLight3D (`1.4`, range28) и вращающийся SpotLight3D (`1.8`, range58, volumetric fog energy0.45). **Глобальный `night01` при `[E]` уже не уменьшается.** Форсаж меняет локальный свет судна, но тоже не отматывает время суток.
10. `shaders/sky_plus.gdshader` — отдельный радианс атмосферы, облака и необязательные ветки moon1–3; `GameWorld` создаёт только **один** DirectionalLight3D. Не объявлять сам moon-pass причиной засветки, пока не установлено наличие `LIGHT1/2/3_ENABLED`. Солнцеподобный вклад может быть результатом sky scattering при `LIGHT0` и ручных uniform-ов.
11. `shaders/resource_slick.gdshader` и `scripts/resource_slick.gd` — прозрачные emissive-пятна. Их порядок/глубина относительно моря ранее уже исправлялись; не использовать их как способ «осветить» море.

## 4. Наблюдения и приоритеты для разработчика

### P0 — изолировать эффекты вместо комбинированного переключателя

Факт: при `[L]` меняется не только `tonemap_mode`, но и контраст/насыщенность, `ambient_light_sky_contribution`, тени, SSAO/SSIL и `surface_light_detail` шейдера воды (`BoatMain.debug_toggle_lighting` → `World.configure_boat_lighting` → `_apply_atmosphere`). Поэтому наблюдение пользователя «Filmic просто делает всё светлее» **нельзя** трактовать как эффект Filmic в одиночку. Например, при `night01=0.88` формула `fade_boat_sun` задаёт ambient energy ≈**0.306** для AgX-профиля против ≈**0.386** для Filmic-профиля (при этом направленный ключ, sky contribution и прочее тоже различаются). Более светлый Filmic ожидаем **даже при одинаковом тонмаппере**. Попросить отдельные переключатели/профили или временно фиксировать остальные параметры при сравнении тонмапперов. Фиксировать экспозицию и кадр, сравнить зоны: небо, далёкое море, вода у корпуса, корпус, берег, тень.

### P0 — согласовать HDR-небо с источником света и фоном воды

`sky_plus.gdshader` получает цвет освещающего небо светила константой, `exposure` меняется независимо от `_sun.light_energy`; вода смешивает вручную `sky_ref` из двух цветов, **не читая** sky radiance карты. Дополнительно `BoatMain` интерполирует направление лишь до `dusk_sun.y=+0.22` (светило остаётся **над** горизонтом), даже когда его диск скрыт и сцена объявлена ночью. Это проверяемый источник дневного рисунка неба в ночной сцене. `WorldEnvironment.ambient_light_source=SKY` использует sky для ambient, но песок и море сверху ещё вручную подкрашены как от неба. Проверить характер избыточного света выключением **по одному**: sky ambient contribution, `shaders/water_boat` ручной `sky_ref`, песчаная заливка/отскок и PBR key. Договориться о едином цветовом бюджете для дня/сумерек/ночи; исключить двойное применение света в `ALBEDO` и `light()` там, где это подтверждается снимками буферов. Сохранять эстетическое решение (стилизация допустима), не навязывать фотометрический реализм из статьи.

### P0 — вода: настоящая форма, а не глобальная засветка

`water_boat.gdshader:287–355` использует **плоскую** `N_ambient=UP` для подсветки базового цвета и отражения неба; вычисленная волновая `N` идёт в глиттер и лишь на `0.16` в PBR-нормаль AgX-профиля; `direct_specular_amount=0.018`. Волны геометрически есть, но свет на них читается слабо. Поднимать энергию/экспозицию вместо проверки материала — вероятный источник плоского яркого кадра. Диагностировать в отдельном тесте: `ALBEDO` без ручного `sky_ref`, normal visualization, затем прямой/непрямой свет отдельно. Любое усиление нормали проверять во время **движения камеры и лодки**, чтобы не вернуть светлые полосы/круги/разрывы воды. Не приглушать глиттер вместо исправления геометрии/света.

### P1 — тени, ambient occlusion и screen space

`World._build_sun` включает тени; диапазон `directional_shadow_max_distance` 100 м в AgX-профиле и 180 м в Filmic. SSAO включён с радиусом 1.35/3 и intensity 1.8/2; light-affect 0.32/0, AO-channel-affect 0.45/0; SSIL 0.95/0.85. Это *несколько* источников изменения воспринимаемой «глубины» при `[L]`. Посмотреть в Godot debug viewport буферы SSAO и SSIL по отдельности, контактные тени корпуса и рифов, материалы воды в depth и нормали; проверить на углах экрана. Не включать SDFGI по умолчанию: динамика, цена и риск артефактов. Обратить внимание на `shaders/sand.gdshader:334–367`: в `light()` есть собственные ночные «звёзды в тенях», активируемые `night_amount`; это **отдельный художественный источник** и не часть SSAO. В лодке фокус/радиус этих звёзд явно не настраиваются (в рыбалке настраиваются).

### P1 — туман, тонмаппинг, glow

Туман задаётся одновременно Environment (`fog_density`, volumetric density, aerial perspective) и **вручную** внутри песка/воды через `fog_distance`/`horizon_col`/`sky_col`. Любая замена тонмаппера меняет результат сложения этих цветовых вкладов; аддитивный glow в Environment `intensity0.55`, `bloom0.08`, `threshold1.15` усиливает emissive-маяки/светящиеся детали. Для диагностики на одном пресете сравнить fog/off, shader-fog/off и glow/off **по одному**, не менять глиттер. Ночь должна быть тёмной и туманной, но локальные огни должны иметь ограниченное влияние. Применять AgX/Filmic после согласования HDR-света, а не вместо него.

### P2 — сигналы и кодовая надёжность

Предыдущее падение было вызвано путаницей имени метода `set_ssao_direct_light_affect` и зарегистрированного GDScript-свойства `ssao_light_affect`; в `d97c301` последнее исправлено и сверено с реестром свойств **Godot 4.7.2**. Это не доказательство, что весь рендер работает: после `d97c301` локальный Godot и визуальный CI не запускались, пользователь лишь сообщил о Filmic/AgX в игре. В коде комментарий `BoatVessel.update_night_lights` ещё упоминает «общий свет от луны», хотя в текущей логике лунный диск и дорожка гасятся: устаревший комментарий не принимать за функциональность. Добавить к проверкам инструментальные screenshots A/B и значения полного lighting-state, а не только `tonemap_mode`.

## 5. Воспроизведение и критерии принятия

- Запустить `res://scenes/boat_main.tscn` в **Forward+** и записать тип рендера/драйвер, FPS и разрешение. Режим Compatibility — отдельный контроль, объёмный туман там может отсутствовать.
- `[5]` — фиксация времени: первое нажатие 45%, второе 88%, третье 0%; `[7]` — возобновить время. `[L]` — переключить комплексный профиль AgX/Filmic (**не** чистый тонмаппер). `[8]/[9]` меняют ночную энергию направленного ключа; `[0]` скрывает отладочную панель. `[4]` — +3 готовых материала каждого цвета, `[6]` — перенос к следующему бую, `[E]` — зажечь маяк.
- Сравнить **одну и ту же позицию и пресет** для обеих настроек; в кадре должны быть лодка, несколько пятен воды, риф, дальняя вода и, отдельно, берег/маяк. Переключать только один параметр за раз; сохранять одинаковую экспозицию и HUD по возможности убирать `[0]`.
- Проверить: локальные тени и детали корпуса читаемы без белой ауры; море не полосит, не получает «линзу» или диагональную цветовую границу; маяк не осветляет весь мир; ночь остаётся тёмной и туманной; глиттер заметен, пятна не исчезают под водой; без регрессии FPS при движении.
- После правки запускать хотя бы импорт Godot 4.7.2 + `JOURNEY_BOAT_SMOKE=1`; headless/dummy не доказывает качество/компиляцию визуальных шейдеров. Длинный Vulkan/CI пользователь предпочитает не ждать — визуальную оценку делать вручную, малыми A/B-итерациями.

## 6. Связанные источники и статус

Статья, по которой делалась предыдущая настройка: https://habr.com/ru/articles/941320/ (энергия светила/ambient/экспозиция, AgX, SSAO/SSIL и ограничения SDFGI). **Не** слепо переносить её дневной фотореалистичный preset на стилизованную ночную лодку.

- `boat-code-review-2.md` — старый полный обзор предыдущего среза `493c20e`, **не** актуальный исходник ночной сцены.
- Срез этого документа — точный `d97c301`. До добавления этого документа рабочее дерево было чистым; ниже снимок кодовых файлов из указанного коммита. Гипотезы выше не являются подтверждёнными замерами GPU/скриншотами.

---

# Приложение: исходники освещения (точно из среза)

Ниже — полный текст главных файлов, чтобы программист мог читать их без бинарного архива. Остальные влияющие файлы даны фрагментами с оригинальными номерами строк; точные пути указаны над каждым блоком. **Считать строку в соответствующем исходном файле, а не номер строки этого документа.**

## Полный файл `scripts/world.gd`

GDScript: WorldEnvironment, Sky++, солнце, туман, HDR/AgX и тени. SHA-256 исходника: `78efc55edcdff70f65c50cd88a2a60f890d797b2d02a181a57b418a75cda2172`.

```gdscript
class_name GameWorld
extends Node3D
## Небо, луна и волюметрический туман (Forward+/Vulkan).
## Всё строится кодом в setup(). Горизонт закрыт настоящими дальними
## дюнами — карта террейна расширена (см. Coast), никаких подставок.

var game: GameState # автозагрузка Game

var _sky_mat: ShaderMaterial
var _sun: DirectionalLight3D
var _env: Environment
var _using_sky_plus := false
var _cloud_drift := 7.0
var compat_fallback := false # Vulkan не поднялся → Godot ушёл в Compatibility
var boat_lighting_profile := false


func setup(game_ref) -> void:
	game = game_ref
	_build_environment()
	_build_sun()


func _build_environment() -> void:
	# Полный Sky++ в Forward+: Rayleigh/Mie/Ozone + half-res raymarched
	# cumulus + cirrus. В Compatibility остаётся лёгкое прежнее небо.
	_using_sky_plus = RenderingServer.get_rendering_device() != null
	_sky_mat = ShaderMaterial.new()
	_sky_mat.shader = load("res://shaders/sky_plus.gdshader" if _using_sky_plus \
		else "res://shaders/sky.gdshader")
	if _using_sky_plus:
		_setup_sky_plus_material()
	else:
		_sky_mat.set_shader_parameter("sun_direction", game.sun_dir)

	var sky := Sky.new()
	sky.process_mode = Sky.PROCESS_MODE_REALTIME if _using_sky_plus else Sky.PROCESS_MODE_AUTOMATIC
	# Realtime Sky в Godot поддерживает только 256; явное значение убирает
	# предупреждение и совпадает с фактическим внутренним размером.
	sky.radiance_size = Sky.RADIANCE_SIZE_256 if _using_sky_plus else Sky.RADIANCE_SIZE_128
	sky.sky_material = _sky_mat

	_env = Environment.new()
	_env.background_mode = Environment.BG_SKY
	_env.sky = sky
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	_env.ambient_light_energy = 1.0

	# Киношный тонмаппинг: ночью чуть длиннее выдержка
	_env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_env.tonemap_exposure = 1.08
	_env.tonemap_white = 4.0

	# Свечение: солнце и искры песка (в Compatibility glow есть)
	_env.glow_enabled = true
	_env.glow_intensity = 0.55
	_env.glow_strength = 1.0
	_env.glow_bloom = 0.08
	_env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	_env.glow_hdr_threshold = 1.15

	# Контактная глубина и непрямой экранный свет: без них процедурные дюны
	# выглядят плоскими даже при хорошем небе и тумане.
	_env.ssao_enabled = true
	_env.ssao_radius = 3.0
	_env.ssao_intensity = 2.0
	_env.ssao_power = 1.35
	_env.ssil_enabled = true
	_env.ssil_radius = 6.0
	_env.ssil_intensity = 0.85

	# Дымка в цвет горизонта — для любых материалов со стандартным туманом.
	_env.fog_enabled = true
	_env.fog_light_color = Game.HORIZON_COL
	_env.fog_density = 0.0034
	# Небо тоже должно уходить в дымку у горизонта. Нулевое значение делало
	# стык неба и дюн резким и визуально выдавало пост-эффект.
	_env.fog_sky_affect = 0.35
	# Из ветки радиобашни: воздушная перспектива смягчает дальние планы.
	# Высотный туман оттуда НЕ берём — он спрятал бы воду на уровне 0.
	_env.fog_aerial_perspective = 0.25

	# ВОЛЮМЕТРИЧЕСКИЙ ТУМАН (Forward+/Vulkan): настоящий 3D-объём —
	# луч фонаря и огонь маяка видны в воздухе. Ночь пустыни: плотный
	# холодный туман гуляет по дюнам. Крутилки — в DEV-панели (F3).
	_env.volumetric_fog_enabled = true
	# 0.09 превращало весь кадр в равномерную серую стену и убивало глубину.
	# Более длинный и прозрачный объём даёт планы, силуэты и световые лучи.
	_env.volumetric_fog_density = 0.026
	_env.volumetric_fog_albedo = Color(0.46, 0.52, 0.64)
	_env.volumetric_fog_emission = Color(0.006, 0.009, 0.018)
	_env.volumetric_fog_emission_energy = 0.35
	_env.volumetric_fog_anisotropy = 0.72
	_env.volumetric_fog_length = 160.0
	_env.volumetric_fog_detail_spread = 1.5
	_env.volumetric_fog_ambient_inject = 0.22
	_env.volumetric_fog_gi_inject = 0.0
	_env.volumetric_fog_sky_affect = 0.30
	_env.volumetric_fog_temporal_reprojection_enabled = true

	var world_env := WorldEnvironment.new()
	world_env.environment = _env
	add_child(world_env)


## Sky++ preset: original look, but tuned from 64+64 marches to a practical
## 16 atmosphere / 24 cloud samples. Clouds render in the half-resolution pass.
func _setup_sky_plus_material() -> void:
	_sky_mat.set_shader_parameter("atmosphere_sample_count", 16)
	_sky_mat.set_shader_parameter("rayleigh_strength", 1.0)
	_sky_mat.set_shader_parameter("mie_strength", 0.82)
	_sky_mat.set_shader_parameter("ozone_strength", 1.0)
	_sky_mat.set_shader_parameter("mie_anisotropy_factor", 0.78)
	_sky_mat.set_shader_parameter("atmosphere_density", 1.0)
	_sky_mat.set_shader_parameter("exposure", 11.5)
	_sky_mat.set_shader_parameter("sundisc_intensity", 24.0)
	_sky_mat.set_shader_parameter("sun_disc_feather", 0.35)
	_sky_mat.set_shader_parameter("coverage", 0.43)
	_sky_mat.set_shader_parameter("cloud_smoothness", 0.075)
	_sky_mat.set_shader_parameter("cloud_marches", 24)
	_sky_mat.set_shader_parameter("light_marches", 6)
	_sky_mat.set_shader_parameter("density_coeff", 1.18)
	_sky_mat.set_shader_parameter("light_strength", 18.0)
	_sky_mat.set_shader_parameter("cloud_shape_size", 3.2)
	_sky_mat.set_shader_parameter("cloud_noise_size", 11.0)
	# В ветке радиобашни убрали клеточные кольца у облаков. Для морского
	# горизонта берём только этот выигрыш, а не игровой код того форка.
	_sky_mat.set_shader_parameter("cloud_noise_factor", 0.14)
	_sky_mat.set_shader_parameter("cloud_base_color", Color(0.58, 0.64, 0.76))
	_sky_mat.set_shader_parameter("cloud_overcast_color", Color(0.16, 0.20, 0.30))
	_sky_mat.set_shader_parameter("cloud_shape", _noise_3d(64, 2, 0.023, FastNoiseLite.TYPE_SIMPLEX_SMOOTH))
	_sky_mat.set_shader_parameter("cloud_noise", _noise_3d(64, 19, 0.045, FastNoiseLite.TYPE_SIMPLEX_SMOOTH))
	_sky_mat.set_shader_parameter("cloud_color_texture", _noise_2d(256, 41, 0.018, 3))
	_sky_mat.set_shader_parameter("use_cirrus", false) # без масляных разводов на горизонте
	_sky_mat.set_shader_parameter("cirrus_texture", _noise_2d(512, 73, 0.012, 4))
	_sky_mat.set_shader_parameter("cirrus_distortion_texture", _noise_2d(256, 7, 0.02, 2))
	_sky_mat.set_shader_parameter("cirrus_mask_texture", _noise_2d(256, 101, 0.008, 2))
	_sky_mat.set_shader_parameter("cirrus_scale", 0.22)
	_sky_mat.set_shader_parameter("cirrus_opacity", 0.16)
	_sky_mat.set_shader_parameter("use_rainbow", false)
	_sky_mat.set_shader_parameter("dim_stars_at_day", true)


func _noise_3d(px: int, seed_value: int, frequency: float, noise_type: int) -> NoiseTexture3D:
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.frequency = frequency
	noise.noise_type = noise_type as FastNoiseLite.NoiseType
	noise.fractal_octaves = 3
	var texture := NoiseTexture3D.new()
	texture.width = px
	texture.height = px
	texture.depth = px
	texture.seamless = true
	texture.noise = noise
	return texture


func _noise_2d(px: int, seed_value: int, frequency: float, octaves: int) -> NoiseTexture2D:
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.frequency = frequency
	noise.fractal_octaves = octaves
	var texture := NoiseTexture2D.new()
	texture.width = px
	texture.height = px
	texture.seamless = true
	texture.noise = noise
	return texture


func _build_sun() -> void:
	# Свет нужен в первую очередь небу (диск солнца).
	_sun = DirectionalLight3D.new()
	var forward: Vector3 = -(game.sun_dir as Vector3).normalized()
	_sun.basis = Basis.looking_at(forward, Vector3.UP)
	_sun.light_color = Color(1.0, 0.83, 0.66)
	_sun.light_energy = 1.15
	_sun.shadow_enabled = true
	_sun.directional_shadow_max_distance = 180.0
	_sun.directional_shadow_fade_start = 0.75
	_sun.light_volumetric_fog_energy = 0.75
	add_child(_sun)

	# Если Vulkan не поднялся, Godot молча уходит в Compatibility —
	# волюметрики там нет. Честно фиксируем и усиливаем depth-fog.
	compat_fallback = RenderingServer.get_rendering_device() == null
	if compat_fallback:
		print("WORLD: Vulkan недоступен — Compatibility-фолбэк, ",
			"волюметрический туман заменён плотной дымкой")


func _process(_delta: float) -> void:
	if _using_sky_plus and _sky_mat != null:
		# Два масштаба дрейфуют неодинаково — форма облаков эволюционирует,
		# а не ездит цельной маской по небу.
		var drift: Vector3 = (game.wind_dir_3d() as Vector3) \
			* float(game.elapsed) * _cloud_drift * 0.00018
		_sky_mat.set_shader_parameter("cloud_shape_offset", drift)
		_sky_mat.set_shader_parameter("cloud_noise_offset", -drift * 1.7)
		_sky_mat.set_shader_parameter("cirrus_offset", Vector2(drift.x, drift.z) * 0.35)


# ---------------------------------------------------------------------------
# API для DEV-панели (F3)
# ---------------------------------------------------------------------------

func set_sky(param: String, value) -> void:
	if not _using_sky_plus:
		_sky_mat.set_shader_parameter(param, value)
		return
	# Совместимость DEV-панели со словарём uniform-ов Sky++.
	match param:
		"sun_intensity": _sky_mat.set_shader_parameter("sundisc_intensity", float(value) * 0.48)
		"mie_scattering": _sky_mat.set_shader_parameter("mie_strength", clampf(float(value) * 100000.0, 0.0, 3.0))
		"rayleigh_scale_height": _sky_mat.set_shader_parameter("rayleigh_strength", float(value) / 8000.0)
		"rayleigh_multi_scattering": _sky_mat.set_shader_parameter("ozone_strength", 0.75 + float(value) * 10.0)
		"cloud_cover": _sky_mat.set_shader_parameter("coverage", value)
		"cloud_size": _sky_mat.set_shader_parameter("cloud_shape_size", float(value) * 2.5)
		"cloud_drift": _cloud_drift = float(value)
		_: _sky_mat.set_shader_parameter(param, value)


func get_exposure() -> float:
	return _env.tonemap_exposure


func set_exposure(v: float) -> void:
	_env.tonemap_exposure = v


func get_glow_threshold() -> float:
	return _env.glow_hdr_threshold


func set_glow_threshold(v: float) -> void:
	_env.glow_hdr_threshold = v


## Волюметрический туман: крутилки DEV-панели. В Compatibility-фолбэке
## плотность дополнительно уезжает в depth-fog — крутилки не мёртвые.
func set_vol_fog(param: String, value) -> void:
	_env.set(param, value)
	if param == "volumetric_fog_density" and compat_fallback:
		_env.fog_density = clampf(float(value) * 0.12, 0.002, 0.03)


## ГЛАВНЫЙ ПОЛЗУНОК «НОЧЬ» (0=день, 1=ночь): красит всё сразу —
## небо, свет, песок, туман, экспозицию, грейдинг.
func apply_night01(v: float) -> void:
	game.night01 = clampf(v, 0.0, 1.0)
	var n: float = game.night01
	# песок/вода сами пекут свет в ALBEDO, поэтому сцена даёт только
	# «добавку»: днём солнце и небо слабее, иначе всё уходит в белое
	_env.ambient_light_energy = lerpf(0.72, 0.42, n)
	_env.tonemap_exposure = lerpf(0.95, 1.15, n)
	_env.fog_light_color = Game.HORIZON_COL.lerp(Color(0.15, 0.20, 0.34), n)
	# днём дымка лёгкая (0.008 volumetric = белая пелена на полкадра),
	# к ночи туман сгущается — это и есть ночной хоррор-воздух
	_env.fog_density = lerpf(0.0011, 0.0042, n) if not compat_fallback \
		else lerpf(0.0011, 0.011, n)
	_env.volumetric_fog_density = lerpf(0.0016, 0.019, n)
	_env.volumetric_fog_albedo = Color(0.72, 0.72, 0.72).lerp(Color(0.46, 0.52, 0.64), n)
	if _using_sky_plus:
		_sky_mat.set_shader_parameter("exposure", lerpf(13.5, 8.5, n))
		_sky_mat.set_shader_parameter("sundisc_intensity", lerpf(32.0, 10.0, n))
		_sky_mat.set_shader_parameter("coverage", lerpf(0.34, 0.48, n))
	else:
		_sky_mat.set_shader_parameter("sun_intensity", lerpf(50.0, 8.0, n))
	_sun.light_energy = lerpf(0.85, 0.30, n)
	_sun.light_color = Color(1.0, 0.83, 0.66).lerp(Color(0.72, 0.78, 0.95), n)


## Смена солнца: небо + свет (базис и цвет по Кельвину — низкое солнце
## краснеет, высокое белеет).
func apply_sun(dir: Vector3) -> void:
	# Sky++ читает LIGHT0_DIRECTION напрямую; fallback получает uniform.
	if not _using_sky_plus:
		_sky_mat.set_shader_parameter("sun_direction", dir)
	_sun.basis = Basis.looking_at(-dir.normalized(), Vector3.UP)
	var elev01 := smoothf(dir.y, 0.05, 0.55)
	var daylight := Color(1.0, 0.83, 0.66).lerp(Color(1.0, 0.97, 0.92), elev01)
	# Без порога 0.5: резкая замена солнца белой «луной» была заметна
	# на всём мире при смене сумерек.
	_sun.light_color = daylight.lerp(Color(0.59, 0.72, 0.91), game.night01)


## Профиль лодки: реальные отношения направленного/фонового света, AgX,
## локальный SSAO и SSIL. Не включаем дорогой SDFGI в динамической сцене.
## Можно сравнить с прежним Filmic через [L], не затрагивая старую рыбалку.
func configure_boat_lighting(enabled: bool) -> void:
	boat_lighting_profile = enabled
	_env.tonemap_mode = Environment.TONE_MAPPER_AGX if enabled else Environment.TONE_MAPPER_FILMIC
	_env.adjustment_enabled = enabled
	_env.adjustment_contrast = 1.12 if enabled else 1.0
	_env.adjustment_saturation = 1.08 if enabled else 1.0
	_env.ambient_light_sky_contribution = 0.80 if enabled else 1.0
	_env.ambient_light_color = Color(0.20, 0.27, 0.36) if enabled else Color.WHITE
	_env.ssao_radius = 1.35 if enabled else 3.0
	_env.ssao_intensity = 1.8 if enabled else 2.0
	# В API Godot 4.7.2 сеттер называется set_ssao_direct_light_affect,
	# но зарегистрированное свойство GDScript — именно ssao_light_affect.
	_env.ssao_light_affect = 0.32 if enabled else 0.0
	_env.ssao_ao_channel_affect = 0.45 if enabled else 0.0
	_env.ssil_intensity = 0.95 if enabled else 0.85
	_sun.directional_shadow_max_distance = 100.0 if enabled else 180.0


## Только лодочный режим: диск солнца и дорожка исчезают, но оставляем
## очень слабый направленный свет неба, чтобы тени и рельеф не стали плоскими.
## Никакого локального «лунного прожектора» или повышения экспозиции.
func fade_boat_sun(n: float, fill_energy: float) -> void:
	var sunset := clampf((n - 0.18) / 0.60, 0.0, 1.0)
	# При том же низком общем уровне света усиливаем разницу между
	# направленным ключом и небесной заливкой: форма читается за счёт теней,
	# а не завышенной экспозиции/белого прожектора.
	var key := minf(0.42, fill_energy + 0.08) if boat_lighting_profile else fill_energy
	_sun.light_energy = lerpf(0.85, key, sunset)
	_sun.light_volumetric_fog_energy = 0.75 * (1.0 - sunset)
	_env.ambient_light_energy = lerpf(0.72, 0.25 if boat_lighting_profile else 0.34, n)
	_env.tonemap_exposure = lerpf(0.95, 1.05, n)
	_env.fog_density = lerpf(0.0011, 0.006, n) if not compat_fallback \
		else lerpf(0.0011, 0.012, n)
	_env.volumetric_fog_density = lerpf(0.0016, 0.016, n)
	_env.fog_aerial_perspective = lerpf(0.25, 0.42, n)
	if _using_sky_plus:
		_sky_mat.set_shader_parameter("sundisc_intensity", lerpf(32.0, 0.0, sunset))
	else:
		_sky_mat.set_shader_parameter("sun_intensity", lerpf(50.0, 0.0, sunset))


func smoothf(v: float, a: float, b: float) -> float:
	var t := clampf((v - a) / (b - a), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)
```

## Полный файл `scripts/boat_main.gd`

GDScript: последовательность и перезапись настроек, маяки, ночные пресеты, отладочные A/B. SHA-256 исходника: `3593090e427d044b7100791dcb34905f3523b59690917c53d10090541a4e7388`.

```gdscript
class_name BoatMain
extends Node3D
## Игровой цикл «To The Light»:
## - Сбор и переработка 4 пигментов, покупка буксируемого плашкоута
## - Наступающие сумерки (динамический night01)
## - Цепь из 3 Погасших Маяков с глубоководными причальными буями вдоль берега
## - Морские рифы, прочность корпуса и 3 активные судовые системы (Сонар, Ремонт, Форсаж)

const START_Z := Coast.SPAWN_Z
const START_SEAWARD := 95.0
const SLICK_RECYCLE_DISTANCE := 60.0
const SLICK_SPAWN_MIN := 38.0
const SLICK_SPAWN_MAX := 57.0
const TRAILER_COST := 2
const DOCK_RANGE := 13.5

var game: GameState
var world: GameWorld
var coast: Coast
var sand: SandField
var water: WaterSurface
var boat: BoatVessel
var camera: Camera3D
var hud: BoatHud
var slicks: Array[ResourceSlick] = []
var raw := PackedInt32Array([0, 0, 0, 0])
var refined := PackedInt32Array([0, 0, 0, 0])
var notice := ""
var notice_time := 0.0

# Состояние игрового цикла (Маяки, Сумерки, Рифы, Сонар)
var night01 := 0.0
var sonar_timer := 12.0 # со старта даём краткий пеленг, чтобы игрок сразу увидел цель
var overdrive_timer := 0.0
var beacons: Array[Dictionary] = []
var reefs: Array[Dictionary] = []
var all_beacons_lit := false

# Быстрый тест встроен в лодочную сцену, не требует внешних консольных команд.
var debug_panel_visible := true
var debug_night_paused := false
var debug_night_fill := 0.18
var debug_lighting_profile := true
var _debug_night_step := 0

var _capture_frames := 0
var _camera_focus := Vector3.ZERO
var _stream_timer := 0.0
var _stream_cursor := 0
var _beacon_anim_time := 0.0
var _atmosphere_timer := 0.0
var _slick_rng := RandomNumberGenerator.new()


func _ready() -> void:
	game = get_node("/root/Game") as GameState
	world = GameWorld.new()
	add_child(world)
	world.setup(game)
	world.configure_boat_lighting(debug_lighting_profile)
	coast = Coast.new()
	add_child(coast)
	coast.setup(game)
	sand = SandField.new()
	add_child(sand)
	sand.setup(game)
	coast.attach_sand(sand)
	coast.set_sand("orthographic_glitter", 1.0)
	water = WaterSurface.new()
	water.shader_path = "res://shaders/water_boat.gdshader"
	add_child(water)
	water.setup(game, Vector2(-150.0, 20.0), Coast.SEA_LEVEL)
	water.configure_boat_waves()
	water.set_ground(coast.height_tex, coast.grid_origin, coast.grid_cell, coast.grid_n, coast)
	game.water = water
	boat = BoatVessel.new()
	boat.name = "Vessel"
	add_child(boat)
	boat.global_position = Vector3(coast.shore_x(START_Z) - START_SEAWARD, 0.2, START_Z)
	boat.setup(self, water, coast)
	if OS.get_environment("JOURNEY_BOAT_SHOT_TRAILER") == "1":
		boat.set_trailer_enabled(true)
	_build_resources()
	_build_beacons()
	_build_reefs()
	_slick_rng.seed = 845239
	camera = Camera3D.new()
	camera.name = "IsometricCamera"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 32.0
	camera.near = 0.2
	camera.far = 1500.0
	add_child(camera)
	camera.current = true
	_camera_focus = boat.global_position + Vector3.UP * 0.8
	camera.position = boat.global_position + Vector3(21.0, 27.0, 30.0)
	camera.look_at(_camera_focus, Vector3.UP)
	hud = BoatHud.new()
	var layer := CanvasLayer.new()
	layer.layer = 12
	add_child(layer)
	hud.main = self
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(hud)
	_ensure_boat_input()
	if OS.get_environment("JOURNEY_BOAT_SHOT_DRIVE") == "1":
		Input.action_press("boat_forward")
	_apply_atmosphere(0.0)
	if OS.get_environment("JOURNEY_BOAT_SMOKE") == "1":
		var test := BoatSmoke.new()
		add_child(test)
		test.setup(self)


func _apply_atmosphere(n01: float) -> void:
	night01 = clampf(n01, 0.0, 0.88)
	world.apply_night01(night01)
	coast.set_night01(night01)
	water.apply_night01(night01)
	var day_sun := Vector3(-0.36, 0.76, -0.54).normalized()
	var dusk_sun := Vector3(-0.62, 0.22, -0.75).normalized()
	var sun := day_sun.lerp(dusk_sun, night01).normalized()
	game.sun_dir = sun
	world.apply_sun(sun)
	world.fade_boat_sun(night01, debug_night_fill)
	coast.apply_sun(sun)
	water.apply_sun(sun)
	# Уходит дневной свет, а не включается отдельная луна. Оставляем
	# тёмную воду и цвет тумана, не меняя настройки микробликов.
	water.set_param("water_shallow", Color("49a9a2").lerp(Color("163d42"), night01))
	water.set_param("water_mid", Color("258b91").lerp(Color("0b2530"), night01))
	water.set_param("water_deep", Color("0f5668").lerp(Color("04111c"), night01))
	water.set_param("horizon_col", Color("6996a0").lerp(Color("1d2c3b"), night01))
	water.set_param("sky_col", Color("447084").lerp(Color("0d1624"), night01))
	water.set_param("sun_col", Color("ffcc85").lerp(Color("a8c9e3"), night01))
	water.set_param("mega_amp", lerpf(0.25, 0.31, night01))
	water.set_param("ripple_strength", 0.10)
	water.set_param("glitter_amount", lerpf(0.32, 0.18, night01))
	# Это широкая искусственная дорожка, НЕ отдельные искры-глиттер.
	# Плавно убрать её до наступления полной темноты.
	water.set_param("sun_path_amount", 0.09 * (1.0 - clampf((night01 - 0.25) / 0.53, 0.0, 1.0)))
	water.set_param("direct_specular_amount", 0.018)
	water.set_param("surface_light_detail", 0.16 if debug_lighting_profile else 0.0)
	if boat != null:
		boat.update_night_lights(night01, overdrive_timer > 0.0)


# ---------------------------------------------------------------------------
# Постройка 3 береговых Маяков с причальными буями и морских рифов
# ---------------------------------------------------------------------------

func _mat(col: Color, metal := 0.0, glow := 0.0, rough := 0.68) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.metallic = metal
	m.roughness = rough
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = col
		m.emission_energy_multiplier = glow
	return m


func _build_beacons() -> void:
	var specs := [
		{
			"name": "Южный Створ",
			"z": START_Z - 105.0,
			"cost": PackedInt32Array([1, 0, 1, 0]), # 1 Бирюза + 1 Янтарь
			"color": Color("ffd485"),
		},
		{
			"name": "Рифовый Мыс",
			"z": START_Z + 18.0,
			"cost": PackedInt32Array([1, 1, 1, 0]), # 1 Бирюза + 1 Коралл + 1 Янтарь
			"color": Color("78f0dc"),
		},
		{
			"name": "Северный Бастион",
			"z": START_Z + 142.0,
			"cost": PackedInt32Array([1, 1, 1, 1]), # Все 4 очищенных пигмента
			"color": Color("f5b8ff"),
		},
	]
	var stone_mat := _mat(Color("3b4247"), 0.15, 0.0, 0.82)
	var tower_mat := _mat(Color("c9c2b4"), 0.08, 0.0, 0.68)
	var band_mat := _mat(Color("8f4636"), 0.18, 0.0, 0.62)
	var iron_mat := _mat(Color("1a2228"), 0.55, 0.0, 0.48)

	for i in range(specs.size()):
		var s: Dictionary = specs[i]
		var bz: float = s["z"]
		var shore_x := coast.shore_x(bz)
		var tower_pos := Vector3(shore_x + 10.0, Coast.SEA_LEVEL + 1.2, bz)
		# Ищем настоящую глубину, а не предполагаем, что 36 м от берега
		# автоматически дают обещанные 4.5 м (обычно там лишь ~3 м).
		var buoy_x := shore_x - 36.0
		while coast.water_depth(buoy_x, bz) < 4.5 and buoy_x > shore_x - 110.0:
			buoy_x -= 3.0
		var buoy_pos := Vector3(buoy_x, Coast.SEA_LEVEL, bz)

		var root := Node3D.new()
		root.name = "CoastalBeacon%d" % i
		add_child(root)

		# Каменная башня маяка на берегу
		var tower := Node3D.new()
		tower.position = tower_pos
		root.add_child(tower)
		_add_cyl(tower, Vector3(0.0, 1.4, 0.0), 2.3, 2.8, 3.2, stone_mat)
		_add_cyl(tower, Vector3(0.0, 5.2, 0.0), 1.45, 2.1, 4.6, tower_mat)
		_add_cyl(tower, Vector3(0.0, 8.2, 0.0), 1.25, 1.45, 1.8, band_mat)
		_add_cyl(tower, Vector3(0.0, 9.4, 0.0), 1.65, 1.55, 0.6, iron_mat)

		# Фонарная камера маяка (гаснет/зажигается)
		var lantern_mat := _mat(Color("26343b"), 0.2, 0.0, 0.25)
		var lantern_mesh := _add_cyl(tower, Vector3(0.0, 10.3, 0.0), 1.15, 1.15, 1.4, lantern_mat)
		_add_cyl(tower, Vector3(0.0, 11.4, 0.0), 0.1, 1.45, 1.0, iron_mat)

		var top_light := OmniLight3D.new()
		top_light.light_color = s["color"]
		top_light.light_energy = 0.0
		top_light.omni_range = 28.0
		top_light.position = Vector3(0.0, 10.4, 0.0)
		tower.add_child(top_light)

		# Вращающийся прожекторный луч маяка
		var beam_pivot := Node3D.new()
		beam_pivot.position = Vector3(0.0, 10.3, 0.0)
		tower.add_child(beam_pivot)
		var spot := SpotLight3D.new()
		spot.light_color = s["color"]
		spot.light_energy = 0.0
		spot.spot_range = 58.0
		spot.spot_angle = 20.0
		spot.light_volumetric_fog_energy = 0.45
		spot.rotation = Vector3(-0.22, PI * 0.5, 0.0)
		beam_pivot.add_child(spot)

		# Глубоководный причальный буй в море (где лодка безопасно швартуется)
		var buoy := Node3D.new()
		buoy.position = buoy_pos
		root.add_child(buoy)
		_add_cyl(buoy, Vector3(0.0, 0.15, 0.0), 1.25, 0.95, 0.55, band_mat)
		_add_cyl(buoy, Vector3(0.0, 0.95, 0.0), 0.18, 0.45, 1.2, iron_mat)
		var buoy_lamp_mat := _mat(Color("e88554"), 0.1, 1.4, 0.25)
		var buoy_lamp := _add_cyl(buoy, Vector3(0.0, 1.65, 0.0), 0.22, 0.22, 0.28, buoy_lamp_mat)

		beacons.append({
			"name": s["name"],
			"cost": s["cost"],
			"color": s["color"],
			"lit": false,
			"tower_pos": tower_pos,
			"buoy_node": buoy,
			"buoy_pos": buoy_pos,
			"lantern_mat": lantern_mat,
			"lantern_mesh": lantern_mesh,
			"buoy_lamp_mat": buoy_lamp_mat,
			"buoy_lamp": buoy_lamp,
			"top_light": top_light,
			"spot": spot,
			"beam_pivot": beam_pivot,
		})


func _build_reefs() -> void:
	# Координаты скал выбраны в стороне от стартового коридора автотеста boat_smoke.gd
	var offsets := [
		Vector2(18.0, -34.0),
		Vector2(-26.0, -48.0),
		Vector2(24.0, 52.0),
		Vector2(-38.0, 68.0),
		Vector2(12.0, -82.0),
		Vector2(22.0, 108.0),
	]
	var base := Vector2(boat.global_position.x, boat.global_position.z)
	var rock_mat := _mat(Color("222a30"), 0.12, 0.0, 0.88)
	var barnacle_mat := _mat(Color("3d4b4a"), 0.08, 0.0, 0.85)
	var warn_mat := _mat(Color("f06848"), 0.1, 1.5, 0.3)

	for i in range(offsets.size()):
		var rp: Vector2 = base + offsets[i]
		if coast.water_depth(rp.x, rp.y) < 3.5:
			continue
		var r_node := Node3D.new()
		r_node.name = "SeaReef%d" % i
		r_node.position = Vector3(rp.x, Coast.SEA_LEVEL, rp.y)
		add_child(r_node)

		# Главный скальный пик и боковые валуны
		_add_cyl(r_node, Vector3(0.0, 0.35, 0.0), 0.45, 2.25, 1.85, rock_mat, Vector3(0.12, float(i) * 1.1, -0.08), 7)
		_add_cyl(r_node, Vector3(1.15, 0.05, 0.65), 0.35, 1.45, 1.15, barnacle_mat, Vector3(-0.15, 0.5, 0.18), 6)
		_add_cyl(r_node, Vector3(-1.05, -0.05, -0.55), 0.30, 1.35, 0.95, rock_mat, Vector3(0.1, -0.7, -0.14), 6)
		# Предупреждающая навигационная веха на рифе
		_add_cyl(r_node, Vector3(0.0, 1.55, 0.0), 0.04, 0.05, 0.95, rock_mat)
		_add_cyl(r_node, Vector3(0.0, 2.08, 0.0), 0.10, 0.10, 0.16, warn_mat)

		reefs.append({
			"pos": rp,
			"radius": 2.65,
			"node": r_node,
		})


func _add_cyl(parent: Node3D, at: Vector3, rt: float, rb: float, h: float, mat: Material, rot := Vector3.ZERO, segs := 12) -> MeshInstance3D:
	var inst := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = rt
	c.bottom_radius = rb
	c.height = h
	c.radial_segments = segs
	inst.mesh = c
	inst.position = at
	inst.rotation = rot
	inst.material_override = mat
	parent.add_child(inst)
	return inst


func _build_resources() -> void:
	var base := Vector2(boat.global_position.x, boat.global_position.z)
	var samples := [
		Vector2(-3, -11), Vector2(-17, -13), Vector2(-20, 3),
		Vector2(-5, 21), Vector2(13, 28), Vector2(-29, 25),
		Vector2(-40, -9), Vector2(6, -30), Vector2(-32, -38),
		Vector2(-13, 42), Vector2(16, 45), Vector2(-47, 43),
	]
	for i in range(samples.size()):
		var at: Vector2 = base + samples[i]
		if coast.water_depth(at.x, at.y) < 3.0:
			continue
		var slick := ResourceSlick.new()
		slick.name = "PigmentSlick%d" % i
		add_child(slick)
		slick.setup(water, at, i % ResourceSlick.COLORS.size(), float(i) * 1.73)
		slicks.append(slick)


func _outside_boat_view(at: Vector2) -> bool:
	var relative := Vector3(at.x - boat.global_position.x, 0.0,
		at.y - boat.global_position.z)
	var viewport_size := get_viewport().get_visible_rect().size
	var half_height := camera.size * 0.5 + 4.0
	var half_width := camera.size * 0.5 * viewport_size.x / maxf(viewport_size.y, 1.0) + 4.0
	return absf(relative.dot(camera.global_transform.basis.x)) > half_width or \
		absf(relative.dot(camera.global_transform.basis.y)) > half_height


func _outside_camera_view(at: Vector2) -> bool:
	var screen_pos := camera.unproject_position(Vector3(at.x, Coast.SEA_LEVEL, at.y))
	var viewport_size := get_viewport().get_visible_rect().size
	return not Rect2(Vector2(-64.0, -64.0),
		viewport_size + Vector2(128.0, 128.0)).has_point(screen_pos)


func _stream_resources() -> void:
	var center := Vector2(boat.global_position.x, boat.global_position.z)
	var forward := Vector2(-boat.global_transform.basis.z.x,
		-boat.global_transform.basis.z.z)
	for offset in range(slicks.size()):
		var index := (_stream_cursor + offset) % slicks.size()
		var slick := slicks[index]
		if slick.depleted:
			continue
		var current := Vector2(slick.position.x, slick.position.z)
		if current.distance_to(center) <= SLICK_RECYCLE_DISTANCE or \
				not _outside_boat_view(current) or not _outside_camera_view(current):
			continue
		_stream_cursor = (index + 1) % slicks.size()
		for attempt in range(24):
			var angle := _slick_rng.randf_range(-PI, PI)
			var direction := Vector2.from_angle(angle)
			if attempt < 12 and boat.speed > 0.5 and direction.dot(forward) < -0.15:
				continue
			var distance := _slick_rng.randf_range(SLICK_SPAWN_MIN, SLICK_SPAWN_MAX)
			var candidate := center + direction * distance
			if not _outside_boat_view(candidate) or not _outside_camera_view(candidate) or \
					coast.water_depth(candidate.x, candidate.y) < 3.0:
				continue
			var clear := true
			for other in slicks:
				if other == slick or other.depleted:
					continue
				if candidate.distance_to(Vector2(other.position.x, other.position.z)) < 9.0:
					clear = false
					break
			if clear:
				slick.relocate_smoothly(Vector3(candidate.x,
					water.surface_height(candidate.x, candidate.y) + ResourceSlick.FLOAT_HEIGHT, candidate.y))
				break
		break


func nearest_resource(at: Vector3, radius: float) -> ResourceSlick:
	var candidate: ResourceSlick = null
	var closest := radius * radius
	for slick in slicks:
		if slick.depleted:
			continue
		var distance := Vector2(at.x, at.z).distance_squared_to(Vector2(slick.position.x, slick.position.z))
		if distance < closest:
			closest = distance
			candidate = slick
	return candidate


func receive_resource(kind: int) -> void:
	raw[kind] += 1
	announce("СОБРАНО: %s" % ResourceSlick.NAMES[kind].to_upper())


func total_refined() -> int:
	var sum := 0
	for count in refined:
		sum += count
	return sum


func refine() -> int:
	var needed := 2 if (boat != null and boat.has_trailer) else 3
	var produced := 0
	for i in range(raw.size()):
		var batches := int(raw[i] / float(needed))
		raw[i] -= batches * needed
		refined[i] += batches
		produced += batches
	if produced > 0 and boat != null:
		boat.trigger_refine_effect()
	announce("ПЕРЕРАБОТАНО: %d" % produced if produced > 0 else ("НУЖНО %d ПЯТНА ОДНОГО ЦВЕТА" % needed))
	return produced


func buy_trailer() -> void:
	if boat == null:
		return
	if boat.has_trailer:
		announce("ПЛАШКОУТ УЖЕ НА БУКСИРЕ")
		return
	if total_refined() < TRAILER_COST:
		announce("ДЛЯ ПЛАШКОУТА НУЖНО 2 ГОТ. МАТЕРИАЛА (ИЛИ НАЖМИТЕ T ДЛЯ ТЕСТА)")
		return
	var remaining := TRAILER_COST
	for i in range(refined.size()):
		var take := mini(refined[i], remaining)
		refined[i] -= take
		remaining -= take
		if remaining <= 0:
			break
	boat.set_trailer_enabled(true)
	announce("ПРИСТЫКОВАН БУКСИРУЕМЫЙ ПЛАШКОУТ! (+СКОРОСТЬ, ПЕРЕРАБОТКА 2→1)")


func toggle_trailer_free() -> void:
	if boat == null:
		return
	boat.set_trailer_enabled(not boat.has_trailer)
	announce("БУКСИРУЕМЫЙ ПЛАШКОУТ: %s" % ("ПРИСТЫКОВАН" if boat.has_trailer else "ОТСТЫКОВАН"))


# ---------------------------------------------------------------------------
# Игровые механики: Маяки и Активные умения 4 пигментов
# ---------------------------------------------------------------------------

## Тратит 1 готовый ресурс kind (или 1 Орхидею-катализатор, или 2 сырья этого типа)
func _consume_pigment_charge(kind: int) -> bool:
	if refined[kind] > 0:
		refined[kind] -= 1
		return true
	if raw[kind] >= 2:
		raw[kind] -= 2
		return true
	if refined[3] > 0: # Орхидея как универсальный катализатор
		refined[3] -= 1
		return true
	return false


## [1] БИРЮЗА — Гидроакустический сонар и пеленг Маяков
func activate_sonar() -> void:
	if not _consume_pigment_charge(0):
		announce("ДЛЯ СОНАРА НУЖНА 1 ГОТ. БИРЮЗА (ИЛИ 2 СЫР. БИРЮЗЫ)")
		return
	sonar_timer = 20.0
	if water != null and water.field != null and boat != null:
		water.field.splash(Vector2(boat.global_position.x, boat.global_position.z), 2.0)
	announce("ГИДРОЛОКАТОР АКТИВЕН: ПЕЛЕНГ НА МАЯКИ И ПЯТНА (20 С)")


## [2] КОРАЛЛ — Аварийный ремонт обшивки корпуса
func activate_hull_repair() -> void:
	if boat == null:
		return
	if boat.hull_hp >= 99.5:
		announce("КОРПУС СУДНА В ПОЛНОМ ПОРЯДКЕ (100%)")
		return
	if not _consume_pigment_charge(1):
		announce("ДЛЯ РЕМОНТА НУЖЕН 1 ГОТ. КОРАЛЛ (ИЛИ 2 СЫР. КОРАЛЛА)")
		return
	boat.hull_hp = minf(100.0, boat.hull_hp + 45.0)
	boat.trigger_refine_effect()
	announce("ОБШИВКА ОТРЕМОНТИРОВАНА: КОРПУС %d%%" % int(round(boat.hull_hp)))


## [3] ЯНТАРЬ — Форсаж реактора и прожектора + откат сумерек
func activate_overdrive() -> void:
	if not _consume_pigment_charge(2):
		announce("ДЛЯ ФОРСАЖА НУЖЕН 1 ГОТ. ЯНТАРЬ (ИЛИ 2 СЫР. ЯНТАРЯ)")
		return
	overdrive_timer = 16.0
	# Форсаж усиливает только судно, но не отматывает время суток назад.
	if boat != null:
		boat.update_night_lights(night01, true)
		boat.trigger_refine_effect()
	announce("ЯНТАРНЫЙ ФОРСАЖ: +35% ХОДА И ДАЛЬНИЙ СВЕТ ПРОЖЕКТОРА!")


func lit_beacon_count() -> int:
	var c := 0
	for b in beacons:
		if b["lit"]:
			c += 1
	return c


## Ближайший причальный буй Маяка (в пределах DOCK_RANGE)
func nearby_dock_beacon() -> Dictionary:
	if boat == null:
		return {}
	var boat_xz := Vector2(boat.global_position.x, boat.global_position.z)
	for b in beacons:
		var bp: Vector3 = b["buoy_pos"]
		if boat_xz.distance_to(Vector2(bp.x, bp.z)) <= DOCK_RANGE:
			return b
	return {}


## Следующий незажжённый Маяк для стрелки компаса
func next_unlit_beacon() -> Dictionary:
	if boat == null:
		return {}
	var boat_xz := Vector2(boat.global_position.x, boat.global_position.z)
	var best: Dictionary = {}
	var best_d := 1e9
	for b in beacons:
		if b["lit"]:
			continue
		var bp: Vector3 = b["buoy_pos"]
		var d := boat_xz.distance_to(Vector2(bp.x, bp.z))
		if d < best_d:
			best_d = d
			best = b
	return best


func format_beacon_recipe(cost: PackedInt32Array) -> String:
	var parts: Array[String] = []
	for i in range(cost.size()):
		if cost[i] > 0:
			parts.append("%d %s" % [cost[i], ResourceSlick.NAMES[i]])
	return " + ".join(parts)


## [E] Зажечь Маяк или отремонтироваться у зажжённого Маяка
func interact_with_beacon() -> void:
	var b := nearby_dock_beacon()
	if b.is_empty():
		var target_b := next_unlit_beacon()
		if not target_b.is_empty():
			var bp: Vector3 = target_b["buoy_pos"]
			var dist := int(round(Vector2(boat.global_position.x, boat.global_position.z).distance_to(Vector2(bp.x, bp.z))))
			announce("ДО БУЯ «%s» %d М. [E] РАБОТАЕТ В ПРЕДЕЛАХ 14 М; %d СЫРЬЯ = 1 ГОТОВЫЙ" % [target_b["name"].to_upper(), dist, 2 if boat.has_trailer else 3])
		return

	if b["lit"]:
		if boat != null and boat.hull_hp < 100.0:
			boat.hull_hp = 100.0
			announce("МАЯК «%s»: КОРПУС ПОЛНОСТЬЮ ВОССТАНОВЛЕН" % b["name"].to_upper())
		else:
			announce("МАЯК «%s» УЖЕ СВЕТИТ В ПОЛНУЮ СИЛУ" % b["name"].to_upper())
		return

	var cost: PackedInt32Array = b["cost"]
	var needed := 2 if boat.has_trailer else 3
	# E принимает как готовый материал, так и достаточно сырья. Сначала
	# проверяем ВЕСЬ рецепт: при нехватке ничего не списываем.
	for i in range(cost.size()):
		var available := refined[i] + int(raw[i] / float(needed))
		if available < cost[i]:
			announce("МАЯК: НУЖНО %d %s (ЕСТЬ %d ГОТ. И %d СЫР.; %d СЫР. = 1 ГОТ.)" % [
				cost[i], ResourceSlick.NAMES[i].to_upper(), refined[i], raw[i], needed])
			return

	for i in range(cost.size()):
		var missing := maxi(0, cost[i] - refined[i])
		raw[i] -= missing * needed
		refined[i] += missing
		refined[i] -= cost[i]

	b["lit"] = true
	var col: Color = b["color"]
	var l_mat: StandardMaterial3D = b["lantern_mat"]
	l_mat.albedo_color = col
	l_mat.emission_enabled = true
	l_mat.emission = col
	l_mat.emission_energy_multiplier = 3.2

	var b_mat: StandardMaterial3D = b["buoy_lamp_mat"]
	b_mat.albedo_color = Color("52f29c")
	b_mat.emission = Color("52f29c")

	var top_l: OmniLight3D = b["top_light"]
	top_l.light_energy = 1.4
	var spot_l: SpotLight3D = b["spot"]
	spot_l.light_energy = 1.8

	if boat != null:
		boat.hull_hp = 100.0
		boat.trigger_refine_effect()
	# Свет локального маяка и указатели видны в тумане, но ночь и всё
	# освещение мира НЕ становятся светлее при нажатии [E].
	sonar_timer = maxf(sonar_timer, 15.0)

	if lit_beacon_count() >= beacons.size():
		all_beacons_lit = true
		announce("ВСЕ МАЯКИ ЗАЖЖЕНЫ! БЕРЕГ ОЗАРЁН СВЕТОМ — ПОБЕДА!")
	else:
		announce("ЗАЖЖЁН МАЯК «%s»! (%d / %d)" % [b["name"].to_upper(), lit_beacon_count(), beacons.size()])


func announce(text: String) -> void:
	notice = text
	notice_time = 6.0


func debug_grant_materials() -> void:
	# Одно нажатие покрывает суммарные рецепты всех трёх маяков.
	for i in range(refined.size()):
		refined[i] += 3
	announce("ТЕСТ: +3 ГОТОВЫХ ПИГМЕНТА КАЖДОГО ЦВЕТА")


func debug_cycle_night() -> void:
	_debug_night_step = (_debug_night_step + 1) % 3
	debug_night_paused = true
	var presets := PackedFloat32Array([0.0, 0.45, 0.88])
	_apply_atmosphere(presets[_debug_night_step])
	announce("ТЕСТ: ВРЕМЯ СУТОК %d%% (ЗАФИКСИРОВАНО; [7] — ПРОДОЛЖИТЬ)" % int(round(night01 * 100.0)))


func debug_toggle_lighting() -> void:
	debug_lighting_profile = not debug_lighting_profile
	world.configure_boat_lighting(debug_lighting_profile)
	_apply_atmosphere(night01)
	announce("ТЕСТ: СВЕТ %s (AgX + КОНТАКТНЫЕ ТЕНИ / FILMIC)" % (
		"НОВЫЙ" if debug_lighting_profile else "СТАРЫЙ"))


func debug_adjust_fill(change: float) -> void:
	debug_night_fill = clampf(debug_night_fill + change, 0.02, 0.42)
	_apply_atmosphere(night01)
	announce("ТЕСТ: НОЧНОЙ БОКОВОЙ СВЕТ %.2f (БЕЗ ЛУННОЙ ДОРОЖКИ)" % debug_night_fill)


func debug_warp_to_beacon() -> void:
	var target_b := next_unlit_beacon()
	if target_b.is_empty() and not beacons.is_empty():
		target_b = beacons[0]
	if target_b.is_empty() or boat == null:
		return
	var bp: Vector3 = target_b["buoy_pos"]
	var at := Vector3(bp.x - 5.0, water.surface_height(bp.x - 5.0, bp.z) + 0.08, bp.z)
	boat.global_position = at
	boat.speed = 0.0
	boat._reset_trail(Vector2(at.x, at.z))
	if boat.has_trailer:
		boat.set_trailer_enabled(true)
	_camera_focus = at + Vector3.UP * 0.8
	camera.global_position = _camera_focus + Vector3(21.0, 26.2, 30.0)
	camera.look_at(_camera_focus, Vector3.UP)
	announce("ТЕСТ: У БУЯ «%s» — НАЖМИТЕ [E]" % target_b["name"].to_upper())


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_R:
				refine()
				get_viewport().set_input_as_handled()
			KEY_B:
				buy_trailer()
				get_viewport().set_input_as_handled()
			KEY_T:
				toggle_trailer_free()
				get_viewport().set_input_as_handled()
			KEY_E:
				interact_with_beacon()
				get_viewport().set_input_as_handled()
			KEY_1:
				activate_sonar()
				get_viewport().set_input_as_handled()
			KEY_2:
				activate_hull_repair()
				get_viewport().set_input_as_handled()
			KEY_3:
				activate_overdrive()
				get_viewport().set_input_as_handled()
			# Цифры не перехватываются редактором Godot: F6/F8 заняты
			# запуском/остановкой сцены при игре внутри редактора.
			KEY_0:
				debug_panel_visible = not debug_panel_visible
				get_viewport().set_input_as_handled()
			KEY_4:
				debug_grant_materials()
				get_viewport().set_input_as_handled()
			KEY_5:
				debug_cycle_night()
				get_viewport().set_input_as_handled()
			KEY_6:
				debug_warp_to_beacon()
				get_viewport().set_input_as_handled()
			KEY_7:
				debug_night_paused = false
				announce("ТЕСТ: ВРЕМЯ СУТОК СНОВА ИДЁТ")
				get_viewport().set_input_as_handled()
			KEY_8:
				debug_adjust_fill(-0.04)
				get_viewport().set_input_as_handled()
			KEY_9:
				debug_adjust_fill(0.04)
				get_viewport().set_input_as_handled()
			KEY_L:
				debug_toggle_lighting()
				get_viewport().set_input_as_handled()
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera.size = maxf(16.0, camera.size - 2.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera.size = minf(42.0, camera.size + 2.0)


func _process(delta: float) -> void:
	if boat == null or camera == null:
		return
	_beacon_anim_time += delta
	sonar_timer = maxf(0.0, sonar_timer - delta)
	var had_overdrive := overdrive_timer > 0.0
	overdrive_timer = maxf(0.0, overdrive_timer - delta)
	if had_overdrive and overdrive_timer <= 0.0:
		boat.update_night_lights(night01, false)

	# Плавное наступление сумерек (в режиме smoke-теста оставляем яркий день)
	if OS.get_environment("JOURNEY_BOAT_SMOKE") != "1" and not debug_night_paused:
		var night_rate := 0.0015 if all_beacons_lit else (0.0055 - float(lit_beacon_count()) * 0.0012)
		night01 = minf(0.88, night01 + night_rate * delta)
		_atmosphere_timer -= delta
		if _atmosphere_timer <= 0.0:
			_atmosphere_timer = 0.15
			_apply_atmosphere(night01)

	# Качка причальных буёв и вращение лучей зажжённых Маяков
	for b in beacons:
		var bp: Vector3 = b["buoy_pos"]
		var buoy_node: Node3D = b["buoy_node"]
		buoy_node.position.y = water.surface_height(bp.x, bp.z)
		buoy_node.rotation.z = sin(_beacon_anim_time * 2.0 + bp.z * 0.1) * 0.08
		if b["lit"]:
			var pivot: Node3D = b["beam_pivot"]
			pivot.rotation.y += delta * 0.85

	if absf(boat.global_position.x - water.position.x) > 100.0 or \
			absf(boat.global_position.z - water.position.z) > 100.0:
		water.position = Vector3(boat.global_position.x, Coast.SEA_LEVEL,
			boat.global_position.z)

	var target := boat.global_position + Vector3.UP * 0.8
	_camera_focus = _camera_focus.lerp(target, 1.0 - exp(-4.0 * delta))
	var desired := _camera_focus + Vector3(21.0, 26.2, 30.0)
	camera.global_position = camera.global_position.lerp(desired, 1.0 - exp(-3.0 * delta))
	camera.look_at(_camera_focus, Vector3.UP)
	notice_time = maxf(0.0, notice_time - delta)
	_stream_timer -= delta
	if _stream_timer <= 0.0:
		_stream_timer = 0.12
		_stream_resources()
	hud.queue_redraw()
	if OS.get_environment("JOURNEY_BOAT_SHOT") == "1":
		_capture_frames += 1
		var drive_shot := OS.get_environment("JOURNEY_BOAT_SHOT_DRIVE") == "1"
		if drive_shot and _capture_frames == 35:
			Input.action_press("boat_right")
		if drive_shot and _capture_frames == 72:
			Input.action_release("boat_right")
		if _capture_frames == (110 if drive_shot else 35):
			var output := OS.get_environment("JOURNEY_BOAT_SHOT_PATH")
			if output.is_empty():
				output = "user://boat.png"
			var err := get_viewport().get_texture().get_image().save_png(output)
			print("[BOAT] screenshot %s (%d)" % [output, err])
			get_tree().quit(0 if err == OK else 1)


func _ensure_boat_input() -> void:
	_add_action("boat_forward", [KEY_W, KEY_UP])
	_add_action("boat_reverse", [KEY_S, KEY_DOWN])
	_add_action("boat_left", [KEY_A, KEY_LEFT])
	_add_action("boat_right", [KEY_D, KEY_RIGHT])
	_add_action("boat_pump", [KEY_SPACE])


func _add_action(action: String, keys: Array) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	for key in keys:
		var input := InputEventKey.new()
		input.physical_keycode = key
		InputMap.action_add_event(action, input)
```

## Полный файл `scripts/water_surface.gd`

GDScript: параметры материала моря, CPU/GPU-волны, порядок прозрачной воды. SHA-256 исходника: `c8571e273311219ce8c0218e169194ece7da5ca251c48c7a8d10d7e56479072f`.

```gdscript
class_name WaterSurface
extends MeshInstance3D
## Море: меш + материал + поле колец, в одном узле.
##
## Поверхность плоская (уровень воды), «дыхание» и кольца считаются
## аналитически — и в шейдере, и в CPU-зеркале WaterField, поэтому поплавок
## качается ровно на той воде, которую рисует глаз.
##
## Сетка НЕОДНОРОДНАЯ: у берега ячейка ~1.2 м (волны «дыхания» ~9 м читаются
## гладко), дальше шаг геометрически растёт до километров — море уходит за
## горизонт, оставаясь дешёвым.
##
## Урез: карта высот читается по фрагментам, без подрезания вершин воды
## к рельефу и без висящей плёнки. Градиент прозрачности сглаживает кромку.

const SHADER_PATH := "res://shaders/water.gdshader"
# Выбирается до setup(): архивная рыбалка использует прежний шейдер,
# лодочная сцена — отдельный вариант с волнами от корпуса и винтов.
var shader_path := SHADER_PATH

const DENSE_SPAN := 620.0 # однородная зона вокруг берега, м
const DENSE_CELL := 1.25 # ячейка в ней, м
const FAR_LIMIT := 3600.0 # докуда доходит море
const FAR_GROWTH := 1.16 # рост шага вдали

var field: WaterField
var level_y := 0.0
var mesh_size := 240.0

var game: GameState # автозагрузка Game (ветер — общий с песком)
var coast: Coast
var _night01 := 0.0
var _mat: ShaderMaterial


func setup(game_ref, center: Vector2, p_level_y: float) -> void:
	game = game_ref
	level_y = p_level_y
	position = Vector3(center.x, level_y, center.y)

	_build_mesh()

	_mat = ShaderMaterial.new()
	_mat.shader = load(shader_path)
	if game != null:
		_mat.set_shader_parameter("sun_dir", game.sun_dir)
		_mat.set_shader_parameter("fog_distance", game.FOG_DISTANCE)
	# уровень моря: шейдер вычисляет глубину у кромки берега
	_mat.set_shader_parameter("sea_level", level_y)
	material_override = _mat
	if shader_path == "res://shaders/water_boat.gdshader":
		# В прозрачном проходе всегда рисовать море раньше ресурсных пятен.
		_mat.render_priority = -10
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# море непрозрачное в глубине, alpha используется только у мягкого уреза; рисуем ПЕРВЫМ:
	# SDF-квад существ читает u_screen с уже нарисованной водой (по ней
	# считается «вуаль» подводных китов) и рисуется поверх (у него 4096).
	# transparency = 0 выключает сортировку по глубине — порядок задаёт
	# sorting_offset, иначе море уплывало за SDF-слой.
	transparency = 0.0
	sorting_offset = -4096.0

	field = WaterField.new()
	field.name = "WaterField"
	add_child(field)
	field.mat = _mat
	field._push_uniforms() # сразу нулевые кольца, чтобы шейдер не ждал 1/30 с


## Усиленное CPU-зеркало волн только для изометрической лодочной сцены.
## Режим рыбалки остаётся на исходных значениях WaterField.
func configure_boat_waves() -> void:
	field.ring_amp = 0.065
	field.wake_interval = 0.12
	field.wake_strength = 0.45
	field.swell_time_rate = 0.55
	field.chop_strength = 0.0
	field.use_spectrum = true


## Высота поверхности моря в мировой точке (уровень + дыхание + кольца).
func surface_height(x: float, z: float) -> float:
	if field == null:
		return level_y
	var shore_fade := 1.0
	if coast != null:
		var depth := coast.water_depth(x, z)
		var t := clampf(depth / 4.0, 0.0, 1.0)
		shore_fade = t * t * (3.0 - 2.0 * t)
	return level_y + field.height_at(x, z) * shore_fade


func material() -> ShaderMaterial:
	return _mat


func set_param(param: String, value) -> void:
	if _mat != null:
		_mat.set_shader_parameter(param, value)


## Карта высот берега из Coast: по ней море кладёт плёнку прибоя на песок.
func set_ground(tex: Texture2D, origin: Vector2, cell: float, n: int,
		coast_ref: Coast = null) -> void:
	coast = coast_ref
	set_param("ground_tex", tex)
	set_param("ground_origin", origin)
	set_param("ground_cell", cell)
	set_param("ground_n", float(n))


func apply_sun(dir: Vector3) -> void:
	set_param("sun_dir", dir)


## Палитра моря: день — бирюза/индиго, ночь — почти чёрная глубина.
## Песок сюда НЕ подмешивается: у суши и воды разные материалы.
const DAY_SHALLOW := Color(0.30, 0.66, 0.62)
const DAY_MID := Color(0.10, 0.38, 0.48)
const DAY_DEEP := Color(0.035, 0.150, 0.300)
const DAY_FOAM := Color(0.95, 0.92, 0.86)
const NIGHT_SHALLOW := Color(0.045, 0.110, 0.120)
const NIGHT_MID := Color(0.012, 0.040, 0.060)
const NIGHT_DEEP := Color(0.003, 0.010, 0.022)
const NIGHT_FOAM := Color(0.30, 0.36, 0.42)


func apply_night01(v: float) -> void:
	_night01 = clampf(v, 0.0, 1.0)
	set_param("water_shallow", DAY_SHALLOW.lerp(NIGHT_SHALLOW, v))
	set_param("water_mid", DAY_MID.lerp(NIGHT_MID, v))
	set_param("water_deep", DAY_DEEP.lerp(NIGHT_DEEP, v))
	set_param("foam_col", DAY_FOAM.lerp(NIGHT_FOAM, v))
	set_param("horizon_col", Coast.DAY_HORIZON.lerp(Coast.NIGHT_HORIZON, v))
	set_param("sky_col", Coast.DAY_SKY.lerp(Coast.NIGHT_SKY, v))
	set_param("fog_distance", lerpf(340.0, 130.0, v))
	# На ночной воде гасим обычные микроблики и солнечные частицы:
	# редкие огни остаются, а звёзды на песке не превращаются в сплошную россыпь.
	set_param("glitter_amount", lerpf(1.0, 0.08, _night01))
	set_param("solar_glitter_amount", lerpf(1.0, 0.0, _night01))


func _process(_delta: float) -> void:
	if game == null or _mat == null:
		return
	# Погода усиливает море нелинейно; ночью дыхание чуть спокойнее.
	# F3 меняет базовый mega_amp, а этот множитель мягко следует ветру.
	var weather01 := clampf((game.wind_strength - 0.65) / 0.70, 0.0, 1.0)
	var weather_gain := lerpf(0.72, 1.28, weather01)
	var night_gain := lerpf(1.0, 0.84, _night01)
	var sea_power := clampf(game.wind_strength * weather_gain * night_gain, 0.45, 1.65)
	_mat.set_shader_parameter("wind_dir", game.wind_dir())
	_mat.set_shader_parameter("wind_power", sea_power)
	if field != null:
		field.wind_dir = game.wind_dir()
		field.wind_power = sea_power
		var ma: Variant = _mat.get_shader_parameter("mega_amp")
		if ma != null:
			field.mega_amp = ma # CPU-поплавок следует за F3 и морским состоянием


# ---------------------------------------------------------------------------
# Неоднородная сетка: плотно у берега, редко вдали
# ---------------------------------------------------------------------------

## Координаты оси: однородный центр + геометрически растущие хвосты.
func _axis() -> PackedFloat32Array:
	var half := DENSE_SPAN * 0.5
	var n := int(round(DENSE_SPAN / DENSE_CELL))
	var step := DENSE_SPAN / float(n)
	var tail := PackedFloat32Array()
	var x := half
	var s := step
	while x < FAR_LIMIT:
		s *= FAR_GROWTH
		x += s
		tail.append(x)
	var head := PackedFloat32Array()
	x = -half
	s = step
	while x > -FAR_LIMIT:
		s *= FAR_GROWTH
		x -= s
		head.append(x)

	var out := PackedFloat32Array()
	out.resize(head.size() + n + 1 + tail.size())
	var k := 0
	for i in range(head.size() - 1, -1, -1):
		out[k] = head[i]
		k += 1
	for i in range(n + 1):
		out[k] = -half + float(i) * step
		k += 1
	for i in range(tail.size()):
		out[k] = tail[i]
		k += 1
	return out


func _build_mesh() -> void:
	var xs := _axis()
	var zs := _axis()
	var nx := xs.size()
	var nz := zs.size()
	var count := nx * nz

	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	verts.resize(count)
	normals.resize(count)
	uvs.resize(count)
	for iz in range(nz):
		var lz := zs[iz]
		for ix in range(nx):
			var i := iz * nx + ix
			var lx := xs[ix]
			verts[i] = Vector3(lx, 0.0, lz)
			normals[i] = Vector3.UP
			uvs[i] = Vector2(lx, lz) * 0.01

	# Winding — тот же, что у берега (FACE_Y), иначе грань вывернута.
	var idx := PackedInt32Array()
	idx.resize((nx - 1) * (nz - 1) * 6)
	var w := 0
	for iz in range(nz - 1):
		for ix in range(nx - 1):
			var a := iz * nx + ix
			var b := a + 1
			var c := a + nx
			var d := c + 1
			idx[w] = d
			idx[w + 1] = c
			idx[w + 2] = b
			idx[w + 3] = c
			idx[w + 4] = a
			idx[w + 5] = b
			w += 6

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idx

	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh = m
```

## Полный файл `shaders/water_boat.gdshader`

Godot spatial shader: итоговый цвет моря, нормаль, свет и глубина. SHA-256 исходника: `88fd92c6a9532487efa7ddd6734ff260c64b8acd70e5b80d16a653289b4b3c8d`.

```gdshader
shader_type spatial;
// МОРЕ С ИСТОРИЧЕСКОЙ ТРАЕКТОРИЕЙ КИЛЬВАТЕРНОГО СЛЕДА В МИРОВЫХ КООРДИНАТАХ:
// - Кильватерная струя и волны Кельвина строятся вдоль кривой u_wake_trail[20],
//   поэтому след остаётся в мировых координатах воды и плавно изгибается при поворотах.

// Прозрачное море не должно записывать глубину поверх пятен ресурсов:
// depth_draw_always мог скрывать их всюду, кроме выреза под корпусом.
render_mode diffuse_burley, specular_schlick_ggx, blend_mix, depth_draw_opaque;

uniform vec3 water_shallow : source_color = vec3(0.30, 0.66, 0.62);
uniform vec3 water_mid : source_color = vec3(0.10, 0.38, 0.48);
uniform vec3 water_deep : source_color = vec3(0.035, 0.150, 0.300);
uniform vec3 foam_col : source_color = vec3(0.95, 0.92, 0.86);
uniform vec3 sun_col : source_color = vec3(1.0, 0.80, 0.52);
uniform vec3 sun_dir = vec3(0.10, 0.26, -0.96);

uniform vec3 horizon_col : source_color = vec3(0.96, 0.66, 0.55);
uniform vec3 sky_col : source_color = vec3(0.28, 0.24, 0.43);
uniform float fog_distance = 340.0;

uniform vec2 wind_dir = vec2(0.32, -0.95);
uniform float wind_power = 1.0;
uniform float mega_amp = 0.15;

uniform float ripple_strength = 0.38;
uniform float glitter_amount = 1.0;
uniform float sun_path_amount = 1.0;
uniform float direct_specular_amount = 1.0;
// Небольшая доля рассчитанной нормали волн в реальном освещении.
// 0 = прежний плоский PBR, 0.16 = мягкая форма без светлых полос.
uniform float surface_light_detail = 0.0;

uniform float proxima_test = 0.0;
uniform float proxima_specular_strength = 0.55;
uniform vec3 proxima_diffuse_fresnel_tint = vec3(1.0);
uniform float proxima_diffuse_fresnel = 1.0;
uniform float proxima_diffuse_fresnel_falloff = 0.75;
uniform float proxima_diffuse_tangent_falloff = 0.75;
uniform vec3 proxima_retroreflection_tint = vec3(1.0);
uniform float proxima_retroreflection = 1.0;
uniform float proxima_retroreflection_falloff = 0.75;
uniform float proxima_retroreflection_tangent_falloff = 0.75;
uniform float proxima_specular_fresnel_falloff = 0.5;
uniform float proxima_smooth_terminator = 0.0;
uniform float proxima_smooth_terminator_length = 0.5;

uniform float ring_amp = 0.065;
uniform float ring_speed = 1.5;
uniform float ring_len = 0.85;
uniform float ring_tau = 0.55;
uniform float ring_w0 = 0.30;
uniform float ring_wg = 0.18;
uniform float ring_boost = 1.4;

uniform float u_time = 0.0;

uniform sampler2D ground_tex : filter_linear, repeat_disable;
uniform vec2 ground_origin = vec2(-280.0, -450.0);
uniform float ground_cell = 1.184;
uniform float ground_n = 761.0;
uniform float sea_level = 0.0;
uniform float shore_fade = 0.03;

uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform vec4 u_rings[24];

// Текущее положение корпуса (x, z, yaw, speed) и массив мировых точек траектории
uniform vec4 u_vessel_state = vec4(0.0, 0.0, 0.0, 0.0);
uniform vec4 u_trailer_state = vec4(0.0, 0.0, 0.0, 0.0);
uniform vec4 u_wake_trail[20]; // xy = world_xz, z = birth_time, w = speed_at_birth

varying vec3 w_pos;

const float PI_2 = 6.28318530718;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	vec3 q = p3.yzx + vec3(33.33);
	p3 += vec3(dot(p3, q));
	return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash12(i);
	float b = hash12(i + vec2(1.0, 0.0));
	float c = hash12(i + vec2(0.0, 1.0));
	float d = hash12(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

#include "res://shaders/boat_wave_spectrum.gdshaderinc"

float ground_at(vec2 wp) {
	vec2 uv = (wp - ground_origin) / (ground_cell * (ground_n - 1.0));
	if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) {
		// За краем 900-метровой карты море должно оставаться ГЛУБОКИМ.
		// -6 м попадало в середину градиента цвета, давая резкую
		// диагональную границу, когда лодка выходила за карту дна.
		return -100.0;
	}
	return texture(ground_tex, uv).r;
}

vec2 to_ship_local(vec2 wp, vec2 center, float yaw) {
	vec2 d = wp - center;
	float c = cos(yaw);
	float s = sin(yaw);
	return vec2(d.x * c - d.y * s, d.x * s + d.y * c);
}

float hull_sdf(vec2 lp) {
	float z_norm = clamp((lp.y + 5.3) / 10.3, 0.0, 1.0);
	float half_w = mix(0.12, 1.62, pow(sin(z_norm * 2.65), 0.65));
	if (lp.y > 1.5) {
		half_w = mix(1.58, 1.25, clamp((lp.y - 1.5) / 3.5, 0.0, 1.0));
	}
	vec2 q = vec2(abs(lp.x) - half_w, abs(lp.y + 0.15) - 5.15);
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0);
}

void vertex() {
	w_pos = (MODEL_MATRIX * vec4(VERTEX.x, VERTEX.y, VERTEX.z, 1.0)).xyz;
	float ground = ground_at(w_pos.xz);
	float shore_depth = max(sea_level - ground, 0.0);
	float shore_t = clamp(shore_depth / 4.0, 0.0, 1.0);
	float shore_wave_fade = shore_t * shore_t * (3.0 - 2.0 * shore_t);
	float hrip = spectrum_height(w_pos.xz, u_time, wind_dir, mega_amp, wind_power)
		* shore_wave_fade;

	// Локальный бурун непосредственно перед носом судна и вытеснение внутри корпуса
	vec2 ship_lp = to_ship_local(w_pos.xz, u_vessel_state.xy, u_vessel_state.z);
	float spd01 = clamp(abs(u_vessel_state.w) / 10.0, 0.0, 1.2);
	float d_bow = length(ship_lp - vec2(0.0, -5.2));
	float bow_crest = exp(-d_bow * d_bow * 0.55) * 0.18 * spd01;
	float d_hull = hull_sdf(ship_lp);
	float hull_cut = -(1.0 - smoothstep(-0.35, 0.20, d_hull)) * 0.30;

	float y = hrip + bow_crest + hull_cut;
	VERTEX.y += y;
	w_pos.y += y;
}

void fragment() {
	vec2 wp = w_pos.xz;
	vec2 wdir = normalize(wind_dir);

	float ground = ground_at(wp);
	float depth_m = w_pos.y - ground;
	if (depth_m < -0.08) {
		discard;
	}
	float near_shore = 1.0 - smoothstep(-0.08, 0.9, depth_m);

	vec3 L = normalize(sun_dir);
	vec3 N = vec3(0.0, 1.0, 0.0);

	float dist = length(CAMERA_POSITION_WORLD - w_pos);

	// Дисперсионные волны: нормаль — производная тех же высот, что у вершин.
	vec2 wave_grad = spectrum_gradient(wp, u_time, wind_dir, mega_amp, wind_power);
	N = normalize(N - vec3(wave_grad.x, 0.0, wave_grad.y)
		* (1.0 - 0.92 * near_shore));

	// ---------- локальная микрорябь без песчаных «сканлайнов» ----------
	// Три параллельных cos(dot(wp, wind)) из старой воды образовывали
	// бегущие светлые полосы. Вместо них — градиент двумерного шума в
	// МИРОВЫХ координатах: он адвектируется ветром, но не создаёт гребней.
	// Крупные волны остаются в spectrum_height/gradient и CPU-плавучести.
	// Один слой вместо двух: 3 выборки шума на пиксель, а не 6.
	vec2 flow = wp * 0.68 + wdir * u_time * 0.22;
	float n = vnoise(flow);
	vec2 micro_grad = vec2(vnoise(flow + vec2(0.18, 0.0)) - n,
		vnoise(flow + vec2(0.0, 0.18)) - n) * 4.4;
	micro_grad *= ripple_strength * wind_power * (1.0 - 0.88 * near_shore);
	N = normalize(N - vec3(micro_grad.x, 0.0, micro_grad.y) * 0.44);

	// ---------- точечные кольца событий (только от сбора пятен) ----------
	float rk = PI_2 / ring_len;
	vec2 rgrad = vec2(0.0);
	for (int i = 0; i < 24; i++) {
		vec4 rg = u_rings[i];
		if (rg.w < 0.0005) {
			continue;
		}
		float age = u_time - rg.z;
		if (age < 0.0) {
			continue;
		}
		vec2 d = wp - rg.xy;
		float dd = max(length(d), 0.0001);
		float rf = ring_speed * age;
		float bw = ring_w0 + ring_wg * age;
		float x = (dd - rf) / bw;
		float env = exp(-x * x);
		float ph = rk * (dd - rf);
		float dec = exp(-age * ring_tau) / sqrt(max(rf, 0.6));
		float a = ring_amp * rg.w * dec;
		float dhdd = a * (env * (-2.0 * x / bw) * cos(ph) - env * sin(ph) * rk);
		rgrad += (d / dd) * dhdd;
	}
	N = normalize(N - vec3(rgrad.x * ring_boost, 0.0, rgrad.y * ring_boost));

	// ---------- МИРОВОЙ КИЛЬВАТЕРНЫЙ СЛЕД ПО ИСТОРИЧЕСКОЙ ТРАЕКТОРИИ ----------
	vec2 ship_lp = to_ship_local(wp, u_vessel_state.xy, u_vessel_state.z);
	float spd01 = clamp(abs(u_vessel_state.w) / 10.0, 0.0, 1.25);
	float d_hull = hull_sdf(ship_lp);
	float turb_noise = vnoise(wp * 2.6 + vec2(0.0, -u_time * 1.8));
	float fine_noise = vnoise(wp * 6.2 + vec2(u_time * 1.1, -u_time * 2.4));

	// 1. Пенное обтекание непосредственно вдоль бортов корпуса и носового буруна
	float hull_collar = exp(-pow((d_hull - 0.10) / (0.18 + 0.12 * spd01), 2.0)) * step(-0.06, d_hull);
	hull_collar *= smoothstep(0.22, 0.75, turb_noise * 0.65 + fine_noise * 0.35);

	// 2. Поиск ближайшей точки на мировой кривой пути u_wake_trail[20]
	float best_d2 = 1e9;
	float best_age = 100.0;
	float best_spd = 0.0;
	vec2 best_normal_xz = vec2(0.0);

	for (int i = 0; i < 19; i++) {
		vec4 p0 = u_wake_trail[i];
		vec4 p1 = u_wake_trail[i + 1];
		float age0 = u_time - p0.z;
		float age1 = u_time - p1.z;
		if (age0 < 0.0 || age0 > 5.5 || age1 > 6.0) {
			continue;
		}
		vec2 seg = p1.xy - p0.xy;
		float seg_len2 = dot(seg, seg);
		float h_proj = (seg_len2 > 0.0001) ? clamp(dot(wp - p0.xy, seg) / seg_len2, 0.0, 1.0) : 0.0;
		vec2 closest = p0.xy + seg * h_proj;
		vec2 diff = wp - closest;
		float d2 = dot(diff, diff);
		if (d2 < best_d2) {
			best_d2 = d2;
			best_age = mix(age0, age1, h_proj);
			best_spd = mix(p0.w, p1.w, h_proj);
			best_normal_xz = (d2 > 1e-5) ? (diff / sqrt(d2)) : vec2(0.0);
		}
	}

	float trail_foam = 0.0;
	float trail_aerated = 0.0;
	if (best_age < 5.2 && best_spd > 0.4) {
		float perp_d = sqrt(best_d2);
		float local_spd01 = clamp(best_spd / 10.0, 0.0, 1.2);
		float age_fade = exp(-best_age * 0.55) * local_spd01;

		// Центральная турбулентная струя от винтов (расширяется со временем вдоль кривой пути)
		float wash_w = 0.55 + best_age * 0.36;
		float wash_env = exp(-pow(perp_d / wash_w, 2.0)) * age_fade;
		trail_foam += wash_env * smoothstep(0.24, 0.78, fine_noise * 0.55 + turb_noise * 0.45) * 0.90;
		trail_aerated = wash_env * 0.55;

		// Расходящиеся боковые волны Кельвина (фронт уходит в стороны от мировой траектории со скоростью волны)
		float kelvin_front = 0.65 + best_age * (1.25 + local_spd01 * 0.95);
		float d_front = perp_d - kelvin_front;
		float k_band = 0.45 + best_age * 0.22;
		float k_env = exp(-pow(d_front / k_band, 2.0)) * age_fade;
		float k_phase = d_front * 4.6;
		// Наклон нормалей воды на расходящихся волнах
		float k_slope = -sin(k_phase) * k_env * 0.58;
		N = normalize(N - vec3(best_normal_xz.x * k_slope, 0.0, best_normal_xz.y * k_slope));
		trail_foam += max(0.0, cos(k_phase)) * k_env * smoothstep(0.28, 0.76, turb_noise) * 0.72;
	}

	// 3. Обтекание буксируемого плашкоута (если прицеплен)
	float trailer_foam = 0.0;
	if (u_trailer_state.w > 0.5) {
		vec2 tr_lp = to_ship_local(wp, u_trailer_state.xy, u_trailer_state.z);
		vec2 tq = abs(tr_lp) - vec2(1.32, 3.0);
		float d_tr = length(max(tq, 0.0)) + min(max(tq.x, tq.y), 0.0);
		trailer_foam = exp(-pow((d_tr - 0.10) / 0.20, 2.0)) * step(-0.05, d_tr) * smoothstep(0.25, 0.75, turb_noise);
	}

	float ship_wake_foam = clamp(hull_collar * (0.65 + 0.45 * spd01) + trail_foam + trailer_foam * 0.70, 0.0, 1.0);

	// ---------- цвет воды ----------
	vec3 base = mix(water_shallow, water_mid, smoothstep(0.0, 3.0, depth_m));
	base = mix(base, water_deep, smoothstep(1.0, 12.0, depth_m));
	base = mix(base, water_shallow * 1.22, near_shore * 0.45);
	base = mix(base, water_shallow * 1.28, clamp(trail_aerated, 0.0, 0.55));

	// Периодические склоны волн НЕ должны полосами перекрашивать небо.
	// Ровный базовый свет; полный наклон волн остаётся для мелких бликов
	// и кильватера, а геометрия и CPU-плавучесть не меняются.
	vec3 N_ambient = vec3(0.0, 1.0, 0.0);
	float ndl = clamp(dot(N_ambient, L) * 0.5 + 0.5, 0.0, 1.0);
	base *= 0.80 + 0.32 * ndl;

	// ---------- френель: небо в воде ----------
	// Ортографическая камера: все лучи параллельны. Вектор от точки до
	// положения камеры создавал ложную сферическую область бликов в кадре.
	vec3 V = normalize((INV_VIEW_MATRIX * vec4(0.0, 0.0, 1.0, 0.0)).xyz);
	vec3 R = reflect(-V, N_ambient);
	float fres = pow(1.0 - clamp(dot(N_ambient, V), 0.0, 1.0), 3.2);
	vec3 sky_ref = mix(horizon_col, sky_col, smoothstep(0.02, 0.42, R.y));
	sky_ref = mix(sky_ref, sky_ref * vec3(0.60, 0.80, 1.02), 0.62);
	float mirror = clamp(0.05 + 0.92 * fres, 0.0, 0.88);
	mirror *= 1.0 - 0.18 * near_shore;
	base = mix(base, sky_ref, mirror);

	// ---------- солнечный глиттер ----------
	vec3 H = normalize(V + L);
	// Плотность мировых ячеек постоянна на экране ортографической камеры:
	// ступенчатый LOD по расстоянию рисовал заметные концентрические зоны.
	float density = 4.0;
	vec2 celluv = floor(wp * density);
	float cellid = hash12(celluv);
	float cellb = hash12(celluv + vec2(7.31, 1.77));
	float cellc = fract(cellid * 13.7);
	vec3 G = normalize(vec3(cellid - 0.5, 0.05 + 0.95 * cellb, cellc - 0.5));
	vec3 Hg = normalize(H + vec3(cellid - 0.5, cellb - 0.5, cellc - 0.5) * 0.55);
	float sun_lobe = pow(clamp(dot(N, Hg), 0.0, 1.0), mix(30.0, 110.0, cellb));
	float sky_lobe = pow(clamp(dot(G, V), 0.0, 1.0), mix(24.0, 80.0, cellc));
	float glit_chance = glitter_amount * 0.28;
	float glint = step(1.0 - glit_chance, cellid);
	float glit_fade = 0.95 * (1.0 - 0.72 * near_shore);
	base += sun_col * (sun_lobe * 1.6 + sky_lobe * 0.26) * glint * glit_fade;

	float path = pow(clamp(dot(N_ambient, H), 0.0, 1.0), 180.0);
	base += sun_col * path * 0.55 * sun_path_amount * (1.0 - 0.85 * near_shore);

	// ---------- пена прибоя + мировая кильватерная пена ----------
	float fn = vnoise(vec2(wp.x * 0.85 + u_time * 0.10, wp.y * 1.55));
	float fn2 = vnoise(vec2(wp.x * 3.2 - u_time * 0.38, wp.y * 2.35));
	float edge = exp(-pow((depth_m - 0.014 - 0.014 * sin(wp.x * 0.9 + u_time * 1.3)) / 0.075, 2.0));
	float edge2 = exp(-pow((depth_m - 0.17 - 0.03 * sin(wp.y * 0.21 + u_time * 1.15)) / 0.08, 2.0));
	float foam = edge * smoothstep(0.02, 0.40, fn) * (0.72 + 0.28 * fn2);
	foam += edge2 * smoothstep(0.45, 0.85, fn2) * 0.55;
	foam = clamp(max(foam, ship_wake_foam), 0.0, 1.0);
	base = mix(base, foam_col * (0.82 + 0.18 * ndl), foam * 0.92);

	// ---------- дымка к горизонту ----------
	float fog = 1.0 - exp(-pow(dist / fog_distance, 2.1));
	float above = smoothstep(-2.0, 16.0, w_pos.y - CAMERA_POSITION_WORLD.y);
	vec3 fcol = mix(horizon_col, sky_col, above * 0.6);
	ALBEDO = mix(base, fcol, fog);

	// Прямое освещение равномерно: периодическая нормаль спектра раньше
	// давала «сканлайны» даже при малом весе. Полная N остаётся в
	// микробликах, высота волн — в геометрии, пена — в цвете.
	// Для PBR используем лишь малую часть уже рассчитанного рельефа.
	// Полная спектральная нормаль прежде рисовала сканлайны; плоская
	// полностью лишала воду реакции на свет и тени. Френель и глиттер выше
	// остаются прежними, а режим легко сравнить в игре клавишей L.
	vec3 lighting_normal = normalize(mix(vec3(0.0, 1.0, 0.0), N, surface_light_detail));
	NORMAL = normalize((VIEW_MATRIX * vec4(lighting_normal, 0.0)).xyz);
	float rough = mix(0.29, 0.55, near_shore); // зыбь не должна давать белые зеркальные прямоугольники
	ROUGHNESS = mix(rough, 0.88, foam);
	SPECULAR = mix(0.55, 0.18, near_shore);
	METALLIC = 0.0;

	float shore_a = smoothstep(-0.08, 0.22, depth_m);
	float sea_a = shore_a;
	float a = max(sea_a, foam * 0.92);
	float sd = texture(depth_tex, SCREEN_UV).r;
	vec2 ndc_xy = SCREEN_UV * 2.0 - 1.0;
	vec4 ndc = vec4(ndc_xy.x, ndc_xy.y, sd, 1.0);
	vec4 vp = INV_PROJECTION_MATRIX * ndc;
	vp.xyz /= vp.w;
	float scene_z = -vp.z;
	float water_z = -VERTEX.z;
	float obj_a = smoothstep(0.0, shore_fade, scene_z - water_z);
	ALPHA = clamp(min(a, obj_a), 0.0, 1.0);
}

// Адаптация формул Proxima Diffuse + Schlick-GGX для A/B-теста воды.
// Источник: ElSuicio, 2026; MIT, godotshaders.com/shader/
// proxima-ggx-the-callisto-protocol-light-model/.
// Copyright (c) 2026 ElSuicio. Permission is hereby granted, free of charge,
// to any person obtaining a copy of this software and associated files, to
// deal in the Software without restriction, including without limitation the
// rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
// sell copies, subject to inclusion of this copyright and permission notice.
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND.
float proxima_h(float ctheta, float n, float cphi, float m) {
	return clamp(pow(max(1.0 - ctheta, 0.0), 5.0 * n)
		* pow(max(cphi, 0.0), 5.0 * m), 0.0, 1.0);
}

float proxima_r(float x) {
	return 2.0 * (1.0 - x);
}

float proxima_t(float x) {
	return clamp(x, 0.0, 1.0);
}

void light() {
	vec3 n = normalize(NORMAL);
	vec3 l = normalize(LIGHT);
	vec3 v = normalize(VIEW);
	float nl = max(dot(n, l), 0.0);
	float nv = clamp(dot(n, v), 1e-3, 1.0);
	if (nl > 0.0) {
	vec3 h = normalize(v + l);
	float nh = clamp(dot(h, n), 0.0, 1.0);
	float hl = clamp(dot(h, l), 0.0, 1.0);
	vec3 radiance = LIGHT_COLOR * ATTENUATION;

	if (proxima_test < 0.5) {
		float a = max(ROUGHNESS * ROUGHNESS, 0.002);
		float a2 = a * a;
		float q = 1.0 + (a2 - 1.0) * nh * nh;
		float d = a2 / (PI * q * q);
		float k = pow(ROUGHNESS + 1.0, 2.0) * 0.125;
		float gl = nl / (nl * (1.0 - k) + k);
		float gv = nv / (nv * (1.0 - k) + k);
		vec3 f0 = mix(vec3(0.04 * proxima_specular_strength), ALBEDO, METALLIC);
		vec3 f = f0 + (1.0 - f0) * pow(1.0 - hl, 5.0);
		float fd90 = 0.5 + 2.0 * ROUGHNESS * hl * hl;
		float burley_l = 1.0 + (fd90 - 1.0) * pow(1.0 - nl, 5.0);
		float burley_v = 1.0 + (fd90 - 1.0) * pow(1.0 - nv, 5.0);
		DIFFUSE_LIGHT += radiance * ALBEDO * (1.0 / PI)
			* burley_l * burley_v * nl;
		SPECULAR_LIGHT += radiance * d * gl * gv * f * direct_specular_amount
			/ max(4.0 * nl * nv, 1e-3);
	} else {
	float alpha = ROUGHNESS * ROUGHNESS;
	float alpha2 = alpha * alpha;
	float vdl = max(dot(-v, l), 0.0);
	float theta_h = acos(nh);
	float theta_d = acos(hl);
	float alpha_f = proxima_h(hl, proxima_r(proxima_diffuse_fresnel_falloff),
		nh, proxima_r(proxima_diffuse_tangent_falloff));
	float alpha_r = proxima_h(nh, proxima_r(proxima_retroreflection_falloff),
		hl, proxima_r(proxima_retroreflection_tangent_falloff));
	float alpha_s = (1.0 - pow(1.0 - theta_d, 3.0))
		* (1.0 - pow(1.0 - theta_h, 3.0));
	vec3 rho_f = proxima_diffuse_fresnel * proxima_diffuse_fresnel_tint;
	vec3 rho_r = proxima_retroreflection * proxima_retroreflection_tint;
	vec3 c1 = mix(vec3(1.0), rho_f, alpha_f)
		* mix(vec3(1.0), rho_r, alpha_r);
	float smooth_term = mix(1.0, smoothstep(0.0,
		max(alpha_s * proxima_smooth_terminator_length, 1e-4), nl),
		alpha_s * proxima_smooth_terminator);
	vec3 fd = c1 * (1.0 / PI)
		* (alpha * (-0.55 + 0.19 / max(nl, 1e-3))
		* (1.0 - sqrt(vdl)) + 1.0) * smooth_term * nl;

	float t = 1.0 + (alpha2 - 1.0) * nh * nh;
	float d = alpha2 / (PI * t * t);
	float gl = 1.0 / (nl + sqrt(alpha2 + (1.0 - alpha2) * nl * nl));
	float gv = 1.0 / (nv + sqrt(alpha2 + (1.0 - alpha2) * nv * nv));
	vec3 f0 = mix(vec3(proxima_specular_strength * 0.08), ALBEDO, vec3(METALLIC));
	float fh = pow(clamp(1.0 - hl, 0.0, 1.0),
		5.0 * proxima_r(proxima_specular_fresnel_falloff));
	vec3 fresnel = f0 + proxima_t(2.0
		- proxima_r(proxima_specular_fresnel_falloff)) * (1.0 - f0) * fh;
	vec3 fs = d * gl * gv * fresnel * nl;
	DIFFUSE_LIGHT += radiance * fd;
	SPECULAR_LIGHT += radiance * fs * direct_specular_amount;
	}
	}
}
```

## Полный файл `shaders/boat_wave_spectrum.gdshaderinc`

Godot shader include: спектр волн, общий с CPU-волнами. SHA-256 исходника: `8b02a641b7190a17f4e5b43fec320779278c0084d23e41196417ff152f00aeac`.

```gdshader
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
```

## Полный файл `shaders/sand.gdshader`

Godot spatial shader: ручная палитра, свет, AO, glitter, туман, собственный light(). SHA-256 исходника: `3d785ef8a76958541efa3d627ebeafeeab592fe7f9896bc87b8c1c54979fe9d7`.

```gdshader
shader_type spatial;
// Материал участвует в настоящем освещении Forward+: тени, SSAO/SSIL,
// фонарь и volumetric fog. Раньше unshaded делал дюны неизбежно плоскими.
render_mode diffuse_burley, specular_schlick_ggx;

// =====================================================================
// Шейдер песка — сердце игры.
// По мотивам доклада GDC «Sand Rendering in Journey» и разбора Alan Zucconi.
// Всё считается во фрагменте по мировым координатам — текстур почти нет.
//
// Настоящий песок: карта смещений (R32F, тор) от SandField реально
// изгибает геометрию (vertex) и даёт настоящие нормали (fragment):
// стенки следов ловят солнце, валы выброшенного песка светятся,
// дно следа темнеет и холоднеет. Никаких «нарисованных» следов.
// =====================================================================

// ---- Палитра (глава 1: тёплые дюны на закате) ----
uniform vec3 sun_dir = vec3(0.10, 0.26, -0.96); // к солнцу (туда же уходит путь)
uniform vec3 sand_sunny : source_color = vec3(0.93, 0.52, 0.30);
uniform vec3 sand_hot : source_color = vec3(1.00, 0.68, 0.36);
uniform vec3 sand_shade : source_color = vec3(0.40, 0.32, 0.52);
uniform vec3 horizon_col : source_color = vec3(0.96, 0.66, 0.55);
uniform vec3 sky_col : source_color = vec3(0.28, 0.24, 0.43);
uniform float fog_distance = 340.0;

// ---- Ветер: один вектор для ряби и струй ----
uniform vec2 wind_dir = vec2(0.32, -0.95); // нормализуется внутри
uniform float wind_power = 1.0;

uniform float glitter_amount = 0.20; // доля блестящих песчинок
uniform float orthographic_glitter = 0.0; // только изометрическая сцена лодки
uniform float night_amount : hint_range(0.0, 1.0) = 0.0;
uniform float shadow_star_intensity : hint_range(0.0, 2.5) = 2.5;
uniform float shadow_star_density : hint_range(0.15, 0.98) = 0.30;
uniform float sea_swell = 0.055; // дыхание моря — как в water.gdshader

// Общий переключатель прямого света Proxima + Schlick-GGX (A/B).
uniform float proxima_test = 0.0;
uniform float proxima_specular_strength = 0.55;
uniform vec3 proxima_diffuse_fresnel_tint = vec3(1.0);
uniform float proxima_diffuse_fresnel = 1.0;
uniform float proxima_diffuse_fresnel_falloff = 0.75;
uniform float proxima_diffuse_tangent_falloff = 0.75;
uniform vec3 proxima_retroreflection_tint = vec3(1.0);
uniform float proxima_retroreflection = 1.0;
uniform float proxima_retroreflection_falloff = 0.75;
uniform float proxima_retroreflection_tangent_falloff = 0.75;
uniform float proxima_specular_fresnel_falloff = 0.5;
uniform float proxima_smooth_terminator = 0.0;
uniform float proxima_smooth_terminator_length = 0.5;


// ---- Урез воды: мокрая полоса и подводный песок ----
// Море лежит плоско на sea_level; там, где песок выше — вода спрятана
// depth-тестом. Мокрую полосу и подводный песок красит этот же шейдер:
// у уреза песок темнее, холоднее и глянцевее, искры гаснут.
uniform float sea_level = 0.0;   // мировой Y уровня моря
uniform sampler2D shore_lut : filter_linear, repeat_disable;
uniform float shore_lut_z_min = -460.0;
uniform float shore_lut_z_max = 460.0;
uniform vec2 shadow_star_focus = vec2(0.0);
uniform float shadow_star_radius = 0.0;
uniform float wet_band = 0.16;   // ВЫСОТА над водой (м), где песок ещё мокрый
uniform float wet_darken = 0.44; // сила мокрого затемнения

// ---- Настоящий песок: карта смещений ----
uniform sampler2D sand_map : filter_linear, repeat_enable;
uniform vec2 sand_origin = vec2(0.0, 0.0); // мировой угол окна карты (x, z)
uniform float sand_texel = 0.12;           // метров на тексель
uniform float sand_edge = 40.0;            // текселей мягкого заноса у края окна

varying vec3 w_pos;
varying vec3 w_normal;
varying vec2 v_dune; // x — 0..1 высота дюны (приходит из геометрии через UV2)

const float SAND_N = 800.0; // сторона карты в текселях

// ---- детерминированный хеш и value-noise ----
float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	vec3 q = p3.yzx + vec3(33.33);
	p3 += vec3(dot(p3, q));
	return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash12(i);
	float b = hash12(i + vec2(1.0, 0.0));
	float c = hash12(i + vec2(0.0, 1.0));
	float d = hash12(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// Смещение песка в мировой точке. Карта — тор: глобальные тексельные
// координаты заворачиваются mod(N), REPEAT склеивает шов. У края окна
// след плавно «заносится ветром» (за окном песок нетронут).
float sand_h(vec2 wp) {
	vec2 g = wp / sand_texel;               // глобальные непрерывные тексели
	vec2 l = g - sand_origin / sand_texel;  // локальные в окне [0..N]
	vec2 uv = (mod(floor(g), SAND_N) + fract(g)) / SAND_N;
	float m = min(min(l.x, l.y), SAND_N - max(l.x, l.y)); // текселей до края
	float edge = smoothstep(0.0, sand_edge, m);
	return texture(sand_map, uv).r * edge;
}

// Фаза мега-ряби (слой 2): одинакова в vertex (высота) и fragment (нормаль)
float mega_phase(vec2 wp, vec2 wdir, vec2 wperp) {
	float u = dot(wp, wdir);
	float v = dot(wp, wperp);
	float rn = vnoise(wp * 0.15);
	float rn2 = vnoise(wp * 0.07 + vec2(9.1, 3.3)); // вторая октава варпа
	return v * 0.70 + u * 0.16 + rn * 2.6 + rn2 * 3.4 + TIME * 0.25;
}

void vertex() {
	w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// песок реально проминается: смещаем вершину по карте (слой 3)
	float h = sand_h(w_pos.xz);
	// слой 2 (как в Journey): мега-рябь — НАСТОЯЩАЯ геометрия,
	// волны ~9 м гребнями поперёк ветра, медленно ползут по ветру
	vec2 wdir_v = normalize(wind_dir);
	vec2 wperp_v = vec2(-wdir_v.y, wdir_v.x);
	float mph = mega_phase(w_pos.xz, wdir_v, wperp_v);
	// Волновая геометрическая рябь отключена: формы берега задаёт Coast.
	VERTEX.y += h;
	w_pos.y += h;
	w_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	v_dune = UV2;
}

void fragment() {
	vec2 wp = w_pos.xz;
	vec2 wdir = normalize(wind_dir);
	vec2 wperp = vec2(-wdir.y, wdir.x);

	vec3 L = normalize(sun_dir);
	vec3 N = normalize(w_normal);

	// Дистанция до фрагмента: мелкая деталь гаснет с расстоянием,
	// чтобы дюны оставались шелковистыми, а не рябило муаром.
	// В перспективной рыбалке расстояние радиальное. Для ортографической
	// лодки оно рисовало неподвижную «линзу» на песке вокруг камеры:
	// затухание света/глиттера и пороги LOD шли концентрическими кругами.
	float view_depth = max(-(VIEW_MATRIX * vec4(w_pos, 1.0)).z, 0.0);
	float dist = mix(length(CAMERA_POSITION_WORLD - w_pos), view_depth,
		orthographic_glitter);
	float detail = exp(-dist * 0.030);

	// ---------- 0. Настоящий песок: карта смещений ----------
	// Градиент карты — это настоящий рельеф: стенки следов и валы.
	float t = sand_texel;
	float h = sand_h(wp);
	float hx1 = sand_h(wp + vec2(t, 0.0));
	float hx0 = sand_h(wp - vec2(t, 0.0));
	float hz1 = sand_h(wp + vec2(0.0, t));
	float hz0 = sand_h(wp - vec2(0.0, t));
	vec2 sgrad = vec2(hx1 - hx0, hz1 - hz0) / (2.0 * t);
	float churn = clamp(abs(h) * 10.0, 0.0, 1.0); // потревоженный песок
	N = normalize(N - vec3(sgrad.x, 0.0, sgrad.y));
	// Фазу ветра используем только для движения мокрой каймы;
	// на самой суше волновые нормали и полосы не рисуются.
	float mph = mega_phase(wp, wdir, wperp);

	// ---------- 2. Свет: солнце + небо + отблеск (три источника) ----------
	// Главный мотив тот же (тёплый склон к солнцу / сиреневая тень),
	// но тень теперь живая: сверху её заливает сиреневое небо,
	// снизу греет тёплый отблеск, отскочивший от соседних дюн.
	float ndl = dot(N, L);
	float crest = smoothstep(0.60, 0.95, v_dune.x);        // гребни дюн
	float hollow = 1.0 - smoothstep(0.10, 0.38, v_dune.x); // ложбины
	// запечённое ambient occlusion дюн (горизонтный AO по карте высот):
	// ложбины и подножия темнее, гребни открыты небу — форма объёма
	// читается с ЛЮБОГО ракурса, без SSAO
	float ao = mix(0.55, 1.0, clamp(v_dune.y, 0.0, 1.0));

	// ключевой свет: солнце с мягким переносом через кромку (wrap).
	// Порог освещённости щедрый: золотая сторона дюны занимает кадр,
	// сирень остаётся только глубокой тенью.
	float wrap = clamp((ndl + 0.45) / 1.05, 0.0, 1.0);
	vec3 base = mix(sand_shade, sand_sunny, smoothstep(0.0, 0.68, wrap));
	base = mix(base, sand_hot, pow(wrap, 2.0) * (0.35 + 0.50 * crest));
	// солнечная кромка: склоны, отвесные к солнцу, светятся изнутри
	base += vec3(1.0, 0.62, 0.34) * pow(clamp(ndl, 0.0, 1.0), 2.2) * 0.16;
	// прямое солнце AO почти не слушается, полусфера — целиком
	base *= mix(1.0, ao, 0.32);
	// заливка неба: сиреневая прохлада на теневых склонах
	base += sand_shade * clamp(N.y, 0.0, 1.0) * 0.22 * ao * (1.0 - wrap);
	// отблеск песка: тёплый свет, отскочивший от дюн, греет тень
	vec3 B = normalize(vec3(-L.x, 0.55, -L.z));
	base += vec3(1.00, 0.58, 0.32) * clamp(dot(N, B), 0.0, 1.0) * 0.28 * ao * (1.0 - wrap * 0.6);
	// ложбины — прохладнее тоном (глубину уже дал AO)
	base = mix(base, sand_shade, hollow * 0.18);
	// крупный тональный шум: дюны не одинаковые
	base *= mix(0.92, 1.07, vnoise(wp * 0.013 + vec2(3.1, 7.7)));
	// Мелкое зерно сохраняет фактуру песка без ветровых полос.
	base *= 1.0 + (vnoise(wp * 2.7) - 0.5) * 0.08 * detail;

	// ---------- 2a. Урез: прибой ----------
	// Высота воды в точке — ТА ЖЕ формула, что в vertex water.gdshader:
	// море дышит, и мокрая кайма ползёт по пляжу вместе с ним.
	float swash = (cos(mph) * 0.62 + cos(mph * 2.63 + 1.7) * 0.30
		+ cos(mph * 0.47 + 0.8) * 0.22) * sea_swell * wind_power;
	float above_sea = w_pos.y - (sea_level + swash);
	float wob = vnoise(wp * 0.35 + vec2(4.1, 8.3));
	// мокрая полоса: узкая, с рваным волокнистым краем
	float wet = 1.0 - smoothstep(-0.02, wet_band * (0.65 + 0.7 * wob), above_sea);
	wet *= 0.72 + 0.28 * wob;
	float sub = 1.0 - smoothstep(-1.6, 0.0, above_sea);
	// пена: узкая светлая кайма на самой кромке, вспенивается пятнами.
	// Полоса не должна читаться «лентой»: пятна рвут её на куски.
	float fw = 0.025 + 0.045 * vnoise(wp * 1.9 + vec2(2.0, 5.0));
	float foam = 1.0 - smoothstep(0.0, fw, abs(above_sea - 0.01));
	foam *= smoothstep(0.25, 0.75, vnoise(wp * 2.6 + vec2(TIME * 0.5, 0.0)));
	foam *= wet * (0.30 + 0.35 * vnoise(wp * 3.1 + vec2(TIME * 0.6, 0.0)));

	// ---------- 2b. След: настоящий рельеф красится как настоящий ----------
	float press = clamp(-h * 12.0, 0.0, 1.0); // дно следа
	float rise = clamp(h * 18.0, 0.0, 1.0);   // вал выброшенного песка
	// дно: свежий песок под песком — ТОТ ЖЕ цвет, лишь чуть плотнее;
	// глубину рисуют собственные нормали выемки, а не тёмная краска
	base = mix(base, base * vec3(0.92, 0.90, 0.99), press * 0.30);
	// вал: свежий сухой песок — светлее и теплее
	base = mix(base, base * vec3(1.18, 1.07, 0.88), rise * 0.5);
	// мокрый песок: темнее и холоднее, подводный — глуше и синее
	// мокрый песок — тот же тёплый песок, только плотнее и темнее; никакой
	// синевы (синева — признак воды, она теперь у моря, а не у берега)
	base = mix(base, base * vec3(0.62, 0.55, 0.50), wet * wet_darken);
	base = mix(base, base * vec3(0.34, 0.40, 0.48), sub * 0.55);
	// прибойная пена — тёплый свет, не белая краска
	base = mix(base, vec3(0.94, 0.90, 0.84), clamp(foam * 0.55, 0.0, 0.42));

	// ---------- 3. Глиттер (микрофасеты, по мотивам Zucconi) ----------
	// «Песчинки» размером с пиксель (LOD по дистанции). ДВА лба:
	//   • солнечный — искра вспыхивает ярче, когда солнце в кадре;
	//   • небесный — зерно ловит САМУ КАМЕРУ: песок сверкает и когда
	//     летишь боком, и когда солнце за спиной (как в Journey).
	vec3 perspective_view = normalize(CAMERA_POSITION_WORLD - w_pos);
	vec3 parallel_view = normalize((INV_VIEW_MATRIX * vec4(0.0, 0.0, 1.0, 0.0)).xyz);
	vec3 V = normalize(mix(perspective_view, parallel_view, orthographic_glitter));
	vec3 H = normalize(V + L);
	// Перспективная рыбалка оставляет прежний дистанционный LOD. Под
	// ортографической лодкой ступени LOD меняли масштаб искр кругом вокруг
	// камеры; теперь все ячейки песка одинакового размера в мировых метрах.
	float need = 900.0 / max(dist, 0.001);
	float perspective_density = clamp(pow(2.0, floor(log2(need / 3.0))) * 3.0, 6.0, 130.0);
	float density = mix(perspective_density, 12.0, orthographic_glitter);
	vec2 celluv = floor(wp * density);
	float cellid = hash12(celluv);
	float cellb = hash12(celluv + vec2(7.31, 1.77));
	float cellc = fract(cellid * 13.7);
	// «зеркало» песчинки: ВЕРХНЯЯ полусфера, азимут равномерный —
	// никакого предпочтения по сторонам света (ошибка была именно тут:
	// мировое смещение делало блёстки видимыми только в одну сторону).
	vec3 G = normalize(vec3(cellid - 0.5, 0.05 + 0.95 * cellb, cellc - 0.5));
	// солнечный блик (half-vector, шевелится от зерна к зерну)
	vec3 Hg = normalize(H + vec3(cellid - 0.5, cellb - 0.5, cellc - 0.5) * 0.55);
	float sun_lobe = pow(clamp(dot(N, Hg), 0.0, 1.0), mix(22.0, 80.0, cellb));
	// небесный блик: зерно поймало взгляд — работает в ЛЮБОМ направлении
	float sky_lobe = pow(clamp(dot(G, V), 0.0, 1.0), mix(20.0, 70.0, cellc));
	// вдаль искр меньше — далеко не «ковёр», а редкие вспышки
	float glint = step(1.0 - glitter_amount * exp(-dist * 0.0035), cellid);
	float rate = mix(2.0, 8.0, cellb);
	glint *= 0.40 + 0.60 * (0.5 + 0.5 * sin(TIME * rate + cellid * 71.0));
	glint *= 1.0 - 0.85 * churn; // потревоженный песок почти не сверкает
	float glit_fade = exp(-dist * 0.004); // искры живут далеко, до горизонта
	glint *= 1.0 - 0.85 * wet; // мокрый песок не сверкает
	glint *= 1.0 - smoothstep(0.12, 0.82, night_amount); // ночью оставляем только искры в тенях
	// искры бьют сильно (2+ единицы) — даже на ярком песке после
	// Filmic-тонмаппинга они остаются точками, а glow даёт им ореол
	base += vec3(1.0, 0.92, 0.70) * (sun_lobe * 2.0 + sky_lobe * 2.2)
		* glint * glit_fade * mix(0.75, 1.0, ao);
	// шёлковый отблеск с ФРЕНЕЛЕМ (PBR-отклик): у кромки дюн, под скользящим
	// взглядом, песок «мокро» блестит сильнее — независимо от солнца
	// шёлк живёт только вблизи: на дальних дюнах скользящий отблеск
	// выжигал песок в белую пелену — глиттеру негде было вспыхивать
	float near_gloss = exp(-dist * 0.012);
	float fres = 0.35 + 0.65 * pow(1.0 - clamp(dot(N, V), 0.0, 1.0), 3.0);
	float sheen = pow(clamp(dot(N, H), 0.0, 1.0), 16.0) * 0.7
		+ pow(clamp(dot(N, H), 0.0, 1.0), 48.0) * 0.3;
	base += vec3(1.0, 0.72, 0.45) * sheen * fres * 0.045 * near_gloss
		* smoothstep(0.0, 0.5, wrap) * (1.0 - churn * 0.5);
	// скользящий ракурс: ближний песок у кромки дюны слегка рдеет
	base += vec3(0.90, 0.55, 0.35) * (fres - 0.35) * 0.10 * ao * near_gloss;

	// ---------- 4. Дымка к горизонту ----------
	float fog = 1.0 - exp(-pow(dist / fog_distance, 2.1));
	float above = smoothstep(-2.0, 16.0, w_pos.y - CAMERA_POSITION_WORLD.y);
	vec3 fcol = mix(horizon_col, sky_col, above * 0.6);

	ALBEDO = mix(base, fcol, fog);
	// Аналитическая нормаль следов и ряби теперь питает реальный BRDF,
	// поэтому фонарь скользит по гребням, а впадины получают контактную тень.
	NORMAL = normalize((VIEW_MATRIX * vec4(N, 0.0)).xyz);
	ROUGHNESS = mix(0.95, 0.80, clamp(fres, 0.0, 1.0)) + churn * 0.05
		- wet * 0.16;
	SPECULAR = 0.16;
	METALLIC = 0.0;
}

// Адаптация формул Proxima Diffuse + Schlick-GGX для материалов моря и песка (переключатель глобального A/B).
// Источник: ElSuicio, 2026; MIT, godotshaders.com/shader/
// proxima-ggx-the-callisto-protocol-light-model/.
// Copyright (c) 2026 ElSuicio. Permission is hereby granted, free of charge,
// to any person obtaining a copy of this software and associated files, to
// deal in the Software without restriction, including without limitation the
// rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
// sell copies, subject to inclusion of this copyright and permission notice.
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND.
float proxima_h(float ctheta, float n, float cphi, float m) {
	return clamp(pow(max(1.0 - ctheta, 0.0), 5.0 * n)
		* pow(max(cphi, 0.0), 5.0 * m), 0.0, 1.0);
}

float proxima_r(float x) {
	return 2.0 * (1.0 - x);
}

float proxima_t(float x) {
	return clamp(x, 0.0, 1.0);
}

float shadow_star_shape(vec2 delta, float angle) {
	vec2 axis = vec2(cos(angle) * delta.x - sin(angle) * delta.y,
		sin(angle) * delta.x + cos(angle) * delta.y);
	float core = exp(-length(axis) * 28.0);
	float ray_x = exp(-abs(axis.x) * 13.0 - abs(axis.y) * 52.0);
	float ray_z = exp(-abs(axis.y) * 13.0 - abs(axis.x) * 52.0);
	return max(core, max(ray_x, ray_z) * 0.62);
}

void light() {
	vec3 n = normalize(NORMAL);
	vec3 l = normalize(LIGHT);
	vec3 v = normalize(VIEW);
	float nl = max(dot(n, l), 0.0);
	float nv = clamp(dot(n, v), 1e-3, 1.0);
	// ATTENUATION содержит настоящую тень от причала/камней. Каждая звезда
	// остаётся на песке в мировых координатах, а не перемещается с камерой.
	float cast_shadow = smoothstep(0.48, 0.84, 1.0 - clamp(ATTENUATION, 0.0, 1.0));
	float shore_u = clamp((w_pos.z - shore_lut_z_min)
		/ (shore_lut_z_max - shore_lut_z_min), 0.0, 1.0);
	float shore_x = texture(shore_lut, vec2(shore_u, 0.5)).r;
	float dry_sand = smoothstep(0.0, 1.5, w_pos.x - shore_x);
	float focus_dist = distance(w_pos.xz, shadow_star_focus);
	float star_zone = 1.0 - smoothstep(shadow_star_radius - 0.6,
		shadow_star_radius + 0.6, focus_dist);
	float night_stars = smoothstep(0.18, 0.85, night_amount);
	vec2 shadow_dir = normalize(-l.xz);
	vec2 shadow_side = vec2(-shadow_dir.y, shadow_dir.x);
	vec2 star_p1 = shadow_star_focus - shadow_side * 0.55 + shadow_dir * 0.50;
	vec2 star_p2 = shadow_star_focus + shadow_side * 0.47 + shadow_dir * 0.42;
	vec2 star_p3 = shadow_star_focus - shadow_side * 0.38 - shadow_dir * 0.38;
	vec2 star_p4 = shadow_star_focus + shadow_side * 0.61 - shadow_dir * 0.58;
	float star_1 = shadow_star_shape(w_pos.xz - star_p1, 0.35)
		* step(shadow_star_density, hash12(vec2(17.1, 2.4)));
	float star_2 = shadow_star_shape(w_pos.xz - star_p2, 1.20)
		* step(shadow_star_density, hash12(vec2(31.8, 8.7)));
	float star_3 = shadow_star_shape(w_pos.xz - star_p3, 2.10)
		* step(shadow_star_density, hash12(vec2(9.2, 47.3)));
	float star_4 = shadow_star_shape(w_pos.xz - star_p4, 0.78)
		* step(shadow_star_density, hash12(vec2(53.7, 16.5)));
	float stars_here = max(max(star_1, star_2), max(star_3, star_4));
	DIFFUSE_LIGHT += vec3(1.65, 1.90, 2.40) * stars_here
		* cast_shadow * dry_sand * star_zone * night_stars * shadow_star_intensity;
	if (nl > 0.0) {
	vec3 h = normalize(v + l);
	float nh = clamp(dot(h, n), 0.0, 1.0);
	float hl = clamp(dot(h, l), 0.0, 1.0);
	vec3 radiance = LIGHT_COLOR * ATTENUATION;

	if (proxima_test < 0.5) {
		// Обычный Schlick-GGX для базового сравнения.
		float a = max(ROUGHNESS * ROUGHNESS, 0.002);
		float a2 = a * a;
		float q = 1.0 + (a2 - 1.0) * nh * nh;
		float d = a2 / (PI * q * q);
		float k = pow(ROUGHNESS + 1.0, 2.0) * 0.125;
		float gl = nl / (nl * (1.0 - k) + k);
		float gv = nv / (nv * (1.0 - k) + k);
		vec3 f0 = mix(vec3(0.08 * 0.16), ALBEDO, METALLIC);
		vec3 f = f0 + (1.0 - f0) * pow(1.0 - hl, 5.0);
		float fd90 = 0.5 + 2.0 * ROUGHNESS * hl * hl;
		float burley_l = 1.0 + (fd90 - 1.0) * pow(1.0 - nl, 5.0);
		float burley_v = 1.0 + (fd90 - 1.0) * pow(1.0 - nv, 5.0);
		DIFFUSE_LIGHT += radiance * ALBEDO * (1.0 / PI)
			* burley_l * burley_v * nl;
		SPECULAR_LIGHT += radiance * d * gl * gv * f / max(4.0 * nl * nv, 1e-3);
	} else {
	// Diffuse Proxima: Fresnel tint, retroreflection и smooth terminator.
	float alpha = ROUGHNESS * ROUGHNESS;
	float alpha2 = alpha * alpha;
	float vdl = max(dot(-v, l), 0.0);
	float theta_h = acos(nh);
	float theta_d = acos(hl);
	float alpha_f = proxima_h(hl, proxima_r(proxima_diffuse_fresnel_falloff),
		nh, proxima_r(proxima_diffuse_tangent_falloff));
	float alpha_r = proxima_h(nh, proxima_r(proxima_retroreflection_falloff),
		hl, proxima_r(proxima_retroreflection_tangent_falloff));
	float alpha_s = (1.0 - pow(1.0 - theta_d, 3.0))
		* (1.0 - pow(1.0 - theta_h, 3.0));
	vec3 rho_f = proxima_diffuse_fresnel * proxima_diffuse_fresnel_tint;
	vec3 rho_r = proxima_retroreflection * proxima_retroreflection_tint;
	vec3 c1 = mix(vec3(1.0), rho_f, alpha_f)
		* mix(vec3(1.0), rho_r, alpha_r);
	float smooth_term = mix(1.0, smoothstep(0.0,
		max(alpha_s * proxima_smooth_terminator_length, 1e-4), nl),
		alpha_s * proxima_smooth_terminator);
	vec3 fd = c1 * (1.0 / PI)
		* (alpha * (-0.55 + 0.19 / max(nl, 1e-3))
		* (1.0 - sqrt(vdl)) + 1.0) * smooth_term * nl;

	// Specular Trowbridge-Reitz GGX + Smith + Schlick Fresnel.
	float t = 1.0 + (alpha2 - 1.0) * nh * nh;
	float d = alpha2 / (PI * t * t);
	float gl = 1.0 / (nl + sqrt(alpha2 + (1.0 - alpha2) * nl * nl));
	float gv = 1.0 / (nv + sqrt(alpha2 + (1.0 - alpha2) * nv * nv));
	vec3 f0 = mix(vec3(proxima_specular_strength * 0.08), ALBEDO, vec3(METALLIC));
	float fh = pow(clamp(1.0 - hl, 0.0, 1.0),
		5.0 * proxima_r(proxima_specular_fresnel_falloff));
	vec3 fresnel = f0 + proxima_t(2.0
		- proxima_r(proxima_specular_fresnel_falloff)) * (1.0 - f0) * fh;
	vec3 fs = d * gl * gv * fresnel * nl;
	DIFFUSE_LIGHT += radiance * fd;
	SPECULAR_LIGHT += radiance * fs;
	}
	}
}
```

## Полный файл `shaders/sky_plus.gdshader`

Godot sky shader: HDR-небо, scattering, облака, moon-pass. SHA-256 исходника: `204d15f015f9a4d8b3b6e32754c080c974a973457b0d1b8c5ef62cdefd539b83`.

```gdshader
// Sky++ by Andrey Soldatov (Ansol), CC0.
// Performance-tuned integration for To The Light.
shader_type sky;
render_mode use_quarter_res_pass, use_half_res_pass;

#define H(p)  fract(sin(mod(dot(p, vec2(12.9898, 78.233)),6.283)) * 43758.5453)

const float EPS = 1e-6;
const float INFINITY = 1.0 / 0.0;
const float PLANET_RADIUS = 6371000.0;
const vec3 PLANET_CENTER = vec3(0.0, -PLANET_RADIUS, 0.0);
const float ATMOSPHERE_HEIGHT = 100000.0;
const float RAYLEIGH_HEIGHT = (ATMOSPHERE_HEIGHT * 0.08);
const float MIE_HEIGHT = (ATMOSPHERE_HEIGHT * 0.012);

uniform bool use_debanding = true;

// ATMOSPHERE UNIFORMS
group_uniforms Atmosphere;
uniform int atmosphere_sample_count = 64;

uniform float elevation = 0.0;

uniform float rayleigh_strength : hint_range(0.0, 5.0) = 1.0;
uniform float mie_strength      : hint_range(0.0, 5.0) = 1.0;
uniform float ozone_strength    : hint_range(0.0, 5.0) = 1.0;

const vec3 C_RAYLEIGH = vec3(5.802, 13.558, 33.100) * 1e-6;
const vec3 C_MIE = vec3(3.996,  3.996,  3.996) * 1e-6;
const vec3 C_OZONE = vec3(0.650,  1.881,  0.085) * 1e-6;

uniform float mie_anisotropy_factor = 0.75;

uniform float atmosphere_density: hint_range(0.0, 5.0) = 1.0;
uniform float exposure = 10.0;

uniform float sun_disc_feather: hint_range(0.0, 1.0) = 0.5;
uniform float sundisc_intensity = 100.0;

// STAR UNIFORMS
group_uniforms Stars;
uniform samplerCube stars_hdr : filter_linear, source_color, hint_default_black;
uniform float stars_exposure: hint_range(0.0, 10.0) = 5.0;
uniform mat3 stars_rotation = mat3(1.0);
uniform bool dim_stars_at_day = true;

#define MAX_DIST 10000.0
#define MAX_MARCHES 64
#define SURF_DIST .01

// MOON UNIFORMS
group_uniforms Moons;
uniform float moon_dist[3];
uniform float moon_uv_x_offset[3];
uniform sampler2D moon_textures[3];

// CLOUD UNIFORMS
#define LOWER_PLANE_HEIGHT 3.0

group_uniforms CumulusClouds;
uniform bool hole_in_center = false;
uniform float hole_radius = 5.0;
uniform float hole_feather = 10.0;
uniform float cloud_falloff_coeff: hint_range(0.0, 1.0) = 0.3;
uniform float clouds_alpha_lower_bound = 0.0;
uniform float clouds_alpha_upper_bound = 0.15;

uniform sampler2D cloud_color_texture: hint_default_white;
uniform vec3 cloud_base_color: source_color = vec3(.85, .85, .9);
uniform vec3 cloud_overcast_color: source_color = vec3(.35, .4, .45);

uniform float coverage: hint_range(0.0, 1.0) = 0.35;
uniform float cloud_smoothness: hint_range(0.0, 0.2) = 0.05;

group_uniforms CumulusClouds.RayMarchParameters;
uniform bool apply_stochastic_jitter = false;
uniform float stochastic_jitter_amount: hint_range(0.0, 1.0) = 0.1;
uniform float cloud_base_march_dist = 10.0;
uniform int cloud_marches: hint_range(4, 64, 1) = 64;
uniform float density_coeff: hint_range(0.0, 2.0) = 1.0;

group_uniforms CumulusClouds.Textures;
uniform float cloud_noise_factor: hint_range(0.0, 1.0) = 0.5;
uniform sampler3D cloud_shape : filter_linear_mipmap_anisotropic, repeat_enable;
uniform float cloud_shape_size = 1.0;
uniform vec3 cloud_shape_offset = vec3(0.0);
uniform sampler3D cloud_noise: filter_linear_mipmap_anisotropic, repeat_enable;
uniform float cloud_noise_size = 1.0;
uniform vec3 cloud_noise_offset = vec3(0.0);

group_uniforms CumulusClouds.LightPass;
uniform float clouds_anisotropy_factor: hint_range(0.0, 1.0) = 0.25;
uniform int light_marches: hint_range(4, 32, 1) = 8;
uniform float light_max_dist = 5.0;
uniform float light_strength = 15.0;

group_uniforms CirrusClouds;
uniform bool use_cirrus = true;
uniform sampler2D cirrus_texture: hint_default_black;
uniform vec2 cirrus_squish = vec2(4.0, 1.0);
uniform float cirrus_scale = 1.0;
uniform float cirrus_treshold: hint_range(0.0, 1.0) = .75;
uniform float cirrus_feather: hint_range(0.0, 1.0) = .25;
uniform vec2 cirrus_offset = vec2(0.0);
uniform sampler2D cirrus_distortion_texture: hint_default_black;
uniform float cirrus_distortion_scale = 1.0;
uniform float cirrus_distortion_strength = .4;
uniform vec2 cirrus_distortion_offset = vec2(0.0);
uniform sampler2D cirrus_mask_texture: hint_default_white;
uniform float cirrus_mask_scale = 1.0;
uniform float cirrus_mask_treshold: hint_range(0.0, 1.0) = .6;
uniform float cirrus_mask_feather: hint_range(0.0, 1.0) = .4;
uniform float cirrus_opacity: hint_range(0.0, 1.0) = 0.2;

group_uniforms Rainbow;
uniform bool use_rainbow = false;
uniform bool behind_clouds = false;
uniform sampler2D rainbow_gradient: hint_default_white, filter_linear;
uniform float rainbow_width = .05;
uniform float rainbow_offset = .65;
uniform float rainbow_opacity: hint_range(0.0, 1.0) = .1;
uniform bool double_rainbow = true;


#define saturate(a) clamp(a, 0.0, 1.0)

vec2 sphere_intersection (vec3 rayStart, vec3 rayDir, vec3 sphereCenter, float sphereRadius)
{
	rayStart -= sphereCenter;
	float a = dot(rayDir, rayDir);
	float b = 2.0 * dot(rayStart, rayDir);
	float c = dot(rayStart, rayStart) - (sphereRadius * sphereRadius);
	float d = b * b - 4.0 * a * c;
	if (d < 0.0)
	{
		return vec2(-1.0);
	}
	else
	{
		d = sqrt(d);
		return vec2(-b - d, -b + d) / (2.0 * a);
	}
}

vec2 planet_intersection (vec3 rayStart, vec3 rayDir)
{
	return sphere_intersection(rayStart, rayDir, PLANET_CENTER, PLANET_RADIUS);
}

vec2 atmosphere_intersection (vec3 rayStart, vec3 rayDir)
{
	return sphere_intersection(rayStart, rayDir, PLANET_CENTER, PLANET_RADIUS + ATMOSPHERE_HEIGHT);
}

float phase_rayleigh (float costh)
{
	return 3.0 * (1.0 + costh*costh) / (16.0 * PI);
}

float phase_mie (float costh)
{
	float g = min(mie_anisotropy_factor, 0.9381);
	float k = 1.55*g - 0.55*g*g*g;
	float kcosth = k*costh;
	return (1.0 - k*k) / ((4.0 * PI) * (1.0-kcosth) * (1.0-kcosth));
}

float atmosphere_height (vec3 position_world_space) {
	return distance(position_world_space, PLANET_CENTER) - PLANET_RADIUS;
}
float density_rayleigh (float h) {
	return exp(-max(0.0, h / RAYLEIGH_HEIGHT));
}
float density_mie (float h) {
	return exp(-max(0.0, h / MIE_HEIGHT));
}
float density_ozone (float h) {
	return max(0.0, 1.0 - abs(h - 25000.0) / 15000.0);
}
vec3 density_atmosphere (float h) {
	return vec3(density_rayleigh(h), density_mie(h), density_ozone(h));
}

vec3 integrate_optical_depth (vec3 rayStart, vec3 rayDir)
{
	vec2 intersection = atmosphere_intersection(rayStart, rayDir);
	float  rayLength    = intersection.y;

	int    sampleCount  = 8;
	float  stepSize     = rayLength / float(sampleCount);

	vec3 opticalDepth = vec3(0.0);

	for (int i = 0; i < sampleCount; i++)
	{
		vec3 localPosition = rayStart + rayDir * (float(i) + 0.5) * stepSize;
		float localHeight  = atmosphere_height(localPosition);
		vec3 localDensity  = density_atmosphere(localHeight);

		opticalDepth += localDensity * stepSize;
	}

	return opticalDepth;
}

vec3 absorb (vec3 opticalDepth) {
	return exp(-(
		opticalDepth.x * C_RAYLEIGH * rayleigh_strength +
		opticalDepth.y * C_MIE * mie_strength +
		opticalDepth.z * C_OZONE * ozone_strength
	) * atmosphere_density);
}

vec3 integrate_scattering (vec3 rayStart, vec3 rayDir, float rayLength, vec3 lightDir, vec3 lightColor, out vec3 transmittance)
{
	float  rayHeight = atmosphere_height(rayStart);
	float  sampleDistributionExponent = 1.0 + saturate(1.0 - rayHeight / ATMOSPHERE_HEIGHT) * 8.0;

	vec2 intersection = atmosphere_intersection(rayStart, rayDir);
	rayLength = min(rayLength, intersection.y);
	if (intersection.x > 0.0)
	{
		rayStart += rayDir * intersection.x;
		rayLength -= intersection.x;
	}

	float  costh    = dot(rayDir, lightDir);
	float  phaseR   = phase_rayleigh(costh);
	float  phaseM   = phase_mie(costh);

	vec3 opticalDepth = vec3(0.0);
	vec3 rayleigh     = vec3(0.0);
	vec3 mie          = vec3(0.0);

	float  prevRayTime  = 0.0;

	for (int i = 0; i < atmosphere_sample_count; i++)
	{
		float  rayTime = pow(float(i) / float(atmosphere_sample_count), sampleDistributionExponent) * rayLength;
		float  stepSize = (rayTime - prevRayTime);

		vec3 localPosition = rayStart + rayDir * rayTime;
		float  localHeight   = atmosphere_height(localPosition);
		vec3 localDensity  = density_atmosphere(localHeight);

		opticalDepth += localDensity * stepSize;

		vec3 viewTransmittance = absorb(opticalDepth);

		vec3 opticalDepthlight  = integrate_optical_depth(localPosition, lightDir);
		vec3 lightTransmittance = absorb(opticalDepthlight);

		rayleigh += viewTransmittance * lightTransmittance * phaseR * localDensity.x * stepSize;
		mie      += viewTransmittance * lightTransmittance * phaseM * localDensity.y * stepSize;

		prevRayTime = rayTime;
	}

	transmittance = absorb(opticalDepth);

	return (rayleigh * C_RAYLEIGH * rayleigh_strength + mie * C_MIE * mie_strength) * lightColor * exposure;
}

float sun_disc(vec3 eyedir, vec3 sundir, float theta_r) {
	float cos_angle = dot(eyedir, sundir);
	float cos_inner = cos(theta_r * (1.0 - sun_disc_feather));
	float cos_outer = cos(theta_r * (1.0 + sun_disc_feather));
	return smoothstep(cos_outer, cos_inner, cos_angle);
}

float rand(vec2 co){
    return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

float sdf_sphere(vec3 ray_origin, vec3 sphere_origin, float sphere_radius) {
	return  length(sphere_origin - ray_origin) - sphere_radius;
}

struct Hit {
	float dist;
	int id;
};

Hit get_dist(vec3 marched_ray) {
	Hit closest = Hit(1e20, -1);

	if (LIGHT1_ENABLED) {
		vec3 moon_pos = LIGHT1_DIRECTION * moon_dist[0];
		float dist = sdf_sphere(marched_ray, moon_pos, LIGHT1_SIZE * 100.0);
		if (dist < closest.dist) {
			closest.dist = dist;
			closest.id = 0;
		}
	}
	if (LIGHT2_ENABLED) {
		vec3 moon_pos = LIGHT2_DIRECTION * moon_dist[1];
		float dist = sdf_sphere(marched_ray, moon_pos, LIGHT2_SIZE * 100.0);
		if (dist < closest.dist) {
			closest.dist = dist;
			closest.id = 1;
		}
	}
	if (LIGHT3_ENABLED) {
		vec3 moon_pos = LIGHT3_DIRECTION * moon_dist[2];
		float dist = sdf_sphere(marched_ray, moon_pos, LIGHT3_SIZE * 100.0);
		if (dist < closest.dist) {
			closest.dist = dist;
			closest.id = 2;
		}
	}

	return closest;
}

Hit raymarch_moons(vec3 ray_direction) {
	Hit distance_so_far = Hit(0.0, 0);

	for (int i = 0; i < MAX_MARCHES; i++) {
		vec3 marched_ray = ray_direction * distance_so_far.dist;
		Hit distance_to_scene = get_dist(marched_ray);
		distance_so_far.dist += distance_to_scene.dist;
		distance_so_far.id = distance_to_scene.id;
		if (distance_to_scene.dist < SURF_DIST || distance_so_far.dist > MAX_DIST) {
			break;
		}
	}

	return distance_so_far;
}

vec3 get_normal(vec3 point) {
	float dist = get_dist(point).dist;

	vec3 normal = dist - vec3(
		get_dist(point - vec3(0.01, 0.0, 0.0)).dist,
		get_dist(point - vec3(0.0, 0.01, 0.0)).dist,
		get_dist(point - vec3(0.0, 0.0, 0.01)).dist
	);

	return normalize(normal);
}

float shade(vec3 light_dir, vec3 point) {
	vec3 normal = get_normal(point);

	float shade = clamp(dot(normal, light_dir), 0.0, 1.0);
	return shade;
}

vec2 spherical_uv_projection(vec3 normal, float shift) {
    float u = 0.5 + atan(normal.z, normal.x) / (2.0 * PI) + shift;
    float v = 0.5 - asin(normal.y) / PI;
    return vec2(u, v);
}

float take_cloud_sample(vec3 coord) {
	float shape_sample = texture(cloud_shape, (coord * cloud_shape_size * 0.01) + cloud_shape_offset).r;
	float noise_sample = texture(cloud_noise, (coord * cloud_noise_size * 0.01) + cloud_noise_offset).r;

	float mixed_sample = shape_sample * (1.0 - cloud_noise_factor) + noise_sample * cloud_noise_factor;

	if (hole_in_center) {
		float hole_factor = smoothstep(hole_radius - hole_feather, hole_radius + hole_feather, length(coord.xz));
		mixed_sample *= hole_factor;
	}

	float invert_coverage = 1.0 - coverage;
	return smoothstep(invert_coverage - cloud_smoothness, invert_coverage + cloud_smoothness, mixed_sample);
}

float henyey_greenstein(float a, float g) {
    float g2 = g*g;
    return (1.0 - g2) / (4.0 * PI * pow(1.0 + g2 - 2.0*g*a, 1.5));
}

float light_march(vec3 ray_origin, vec3 ray_direction, vec3 sun_direction) {
	float optical_depth = 0.0;

	float step_size = light_max_dist / float(light_marches);

	for(float total_dist = 0.0; total_dist < light_max_dist; total_dist += step_size) {
		vec3 coords = ray_origin + sun_direction * total_dist;
		float density_sample = take_cloud_sample(coords);

		optical_depth += density_sample * step_size;
	}

	return exp(-optical_depth);
}

vec4 ray_march_clouds(vec3 start_point, vec3 direction, vec3 ambient_color, vec2 uv) {
	vec3 light_energy = vec3(ambient_color);
	float transmittance = 1.0;

	float march_dist = cloud_base_march_dist
		/ clamp(pow(dot(direction, vec3(0.0, 1.0, 0.0)), cloud_falloff_coeff), 0.05, 1.0);
	float step_size = (march_dist / float(cloud_marches)) - EPS;

	float cos_theta = dot(direction, LIGHT0_DIRECTION);
	float phase_cloud = henyey_greenstein(cos_theta, clouds_anisotropy_factor);

	if (apply_stochastic_jitter) {
		start_point += direction * (H(uv) - 0.5) * stochastic_jitter_amount;
	}

	vec3 cloud_color = vec3(0.0);

	for (float total_dist = 0.0; total_dist < march_dist; total_dist += step_size) {
		vec3 coords = start_point + direction * total_dist;

		float density_sample = take_cloud_sample(coords);

		cloud_color += mix(
			cloud_base_color,
			cloud_overcast_color,
			smoothstep( .4, .8, texture(cloud_color_texture, coords.xz * .01).r)
		);

		if (density_sample > 0.01) {
			transmittance *= exp(-density_sample * density_coeff * step_size);
			float luminance = light_march(coords, direction, LIGHT0_DIRECTION);

			light_energy +=
				density_sample *
				transmittance *
				density_coeff *
				step_size *
				luminance *
				phase_cloud *
				light_strength;
		}
	}

	cloud_color /= float(cloud_marches);
	vec3 cloud_col = cloud_color * light_energy * LIGHT0_COLOR * pow(LIGHT0_ENERGY, 2.0);

	transmittance = clamp(1.0 - transmittance, 0.0, 1.0);

	return vec4(cloud_col, transmittance);
}

vec3 jitter_ray_origin(vec3 origin, vec3 direction, vec2 noise_sample, float amount) {
    vec3 up = abs(direction.y) < 0.999 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0);
    vec3 tangent = normalize(cross(up, direction));
    vec3 bitangent = normalize(cross(direction, tangent));

    vec2 offset2D = (noise_sample - 0.5) * amount;
    return origin + tangent * offset2D.x + bitangent * offset2D.y;
}

void sky() {
	if (AT_CUBEMAP_PASS) {
		vec3 transmittance;
		COLOR = integrate_scattering(vec3(0.0, elevation, 0.0), EYEDIR, INFINITY, LIGHT0_DIRECTION, vec3(1.0, 0.996, 0.98), transmittance);
	} else if (AT_QUARTER_RES_PASS) {
		vec3 transmittance;
		integrate_scattering(vec3(0.0, elevation, 0.0), EYEDIR, INFINITY, LIGHT0_DIRECTION, vec3(1.0, 0.996, 0.98), transmittance);
		COLOR = transmittance;
	} else if (AT_HALF_RES_PASS) {
		COLOR = vec3(0.0);
		ALPHA = 0.0;

		if (EYEDIR.y > 0.0) {
			vec3 lower_plane_point = EYEDIR * (LOWER_PLANE_HEIGHT / EYEDIR.y);

			vec4 clouds = ray_march_clouds(
				lower_plane_point,
				EYEDIR,
				texture(RADIANCE, EYEDIR).rgb,
				SCREEN_UV
			);

			COLOR.rgb = clouds.rgb;
			ALPHA = clouds.a;

			ALPHA *= smoothstep(
				clouds_alpha_lower_bound,
				clouds_alpha_upper_bound,
				dot(EYEDIR, vec3(0.0, 1.0, 0.0))
			);
		}
	} else {
		vec3 transmittance = QUARTER_RES_COLOR.rgb;
		vec3 radiance = texture(RADIANCE, EYEDIR).rgb;

		float sun_mask = sun_disc(EYEDIR, LIGHT0_DIRECTION, LIGHT0_SIZE * 0.5);
		vec3 sundisc = vec3(sun_mask) * transmittance * sundisc_intensity;

		vec3 stars =
			texture(stars_hdr, EYEDIR * stars_rotation).rgb *
			stars_exposure *
			transmittance;

		if (dim_stars_at_day) {
			float stars_mult = smoothstep(
				-0.1,
				0.3,
				dot(LIGHT0_DIRECTION, vec3(0.0, -1.0, 0.0))
			);
			stars *= stars_mult;
		}

		// Moon pass
		float moon_mask = 1.0;
		vec3 moon_diff = vec3(0.0);

		Hit moon_hit = raymarch_moons(EYEDIR);

		if (
			moon_hit.dist < MAX_DIST &&
			get_dist(EYEDIR * moon_hit.dist).dist < SURF_DIST * 128.0
		) {
			moon_mask = 0.0;

			moon_diff = texture(
				moon_textures[moon_hit.id],
				spherical_uv_projection(get_normal(EYEDIR * moon_hit.dist), moon_uv_x_offset[moon_hit.id])
			).rgb;

			moon_diff *= shade(LIGHT0_DIRECTION, EYEDIR * moon_hit.dist);

			switch (moon_hit.id) {
				case 0:
					moon_diff *= LIGHT1_COLOR * LIGHT1_ENERGY;
					break;
				case 1:
					moon_diff *= LIGHT2_COLOR * LIGHT2_ENERGY;
					break;
				case 3:
					moon_diff *= LIGHT3_COLOR * LIGHT3_ENERGY;
					break;
			}

			moon_diff *= transmittance;
		}

		COLOR = radiance + (sundisc + stars) * moon_mask + moon_diff;

		// Cirrus Clouds
		if (EYEDIR.y > 0.0 && use_cirrus) {
			vec2 coords = EYEDIR.xz / EYEDIR.y;

			float cirrus_mask = smoothstep(
				cirrus_mask_treshold - cirrus_mask_feather,
				cirrus_mask_treshold + cirrus_mask_feather,
				texture(cirrus_mask_texture, coords * cirrus_mask_scale).r
			);
			vec2 cirrus_distortion = texture(cirrus_distortion_texture, coords * cirrus_distortion_scale + cirrus_distortion_offset).xy * cirrus_distortion_strength;

			float cirrus = smoothstep(
				cirrus_treshold - cirrus_feather,
				cirrus_treshold + cirrus_feather,
				texture(
					cirrus_texture,
					(coords * cirrus_scale + cirrus_offset) * cirrus_squish + cirrus_distortion
				).r
			) * cirrus_mask * cirrus_opacity * smoothstep(.5, 3.0, length(coords));

			COLOR += cirrus * transmittance * LIGHT0_COLOR * LIGHT0_ENERGY;
		}

		// Cumulus Clouds
		vec4 clouds = HALF_RES_COLOR;
		COLOR = mix(COLOR, clouds.rgb, clouds.a);

		// Rainbows
		if (use_rainbow) {
			// Main rainbow
			{
				float lower_bound = rainbow_offset - rainbow_width;
				float upper_bound = rainbow_offset + rainbow_width;
				float lower_mask = smoothstep(lower_bound, lower_bound + .02, EYEDIR.x);
				float upper_mask = smoothstep(upper_bound, upper_bound - .02, EYEDIR.x);
				COLOR += texture(
						rainbow_gradient,
						vec2(smoothstep(lower_bound, upper_bound, EYEDIR.x), 0.0)
					).rgb
					* lower_mask
					* upper_mask
					* rainbow_opacity
					* transmittance
					* (behind_clouds ? (1.0 - clouds.a) : 1.0);
			}

			// Double rainbow
			if (double_rainbow) {
				float lower_bound = rainbow_offset * 0.9 - rainbow_width * 1.5;
				float upper_bound = rainbow_offset * 0.9 + rainbow_width * 1.5;
				float lower_mask = smoothstep(lower_bound, lower_bound + .02, EYEDIR.x);
				float upper_mask = smoothstep(upper_bound, upper_bound - .02, EYEDIR.x);
				COLOR += texture(
						rainbow_gradient,
						vec2(smoothstep(lower_bound, upper_bound, EYEDIR.x), 0.0)
					).rgb
					* lower_mask
					* upper_mask
					* rainbow_opacity * .15
					* transmittance
					* (behind_clouds ? (1.0 - clouds.a) : 1.0);
			}
		}

		if (use_debanding) {
			COLOR += (rand(SKY_COORDS) - 0.5) * 0.001;
		}
	}
}
```

## Полный файл `shaders/resource_slick.gdshader`

Godot spatial shader: прозрачные пятна и emission. SHA-256 исходника: `444163e3f302457cfbccd66225c2454e8ab618bc6157a785daf581945171edff`.

```gdshader
shader_type spatial;
// Цветные приливные пятна. Та же SDF-идея, что в sand_sea_sdf.gdshader:
// расстояния до примитивов, плавное объединение форм и цветов, а не текстура.
// Пятно лежит поверх существующего волнового моря и не заменяет его шейдер.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;

uniform vec3 pigment : source_color = vec3(0.20, 0.80, 0.77);
uniform float seed = 0.0;
uniform float pulse = 0.0;
uniform float fade = 1.0;
uniform float wave_time = 0.0;
uniform float wave_amp = 0.25;
uniform float wave_power = 1.0;
uniform vec2 wave_wind = vec2(0.32, -0.95);
varying vec2 local_pos;

#include "res://shaders/boat_wave_spectrum.gdshaderinc"

float hash21(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

// IQ polynomial smooth-min: та же операция "плавления", что у SDF-рыб.
float smooth_union(float a, float b, float k) {
    float h = max(k - abs(a - b), 0.0) / k;
    return min(a, b) - h * h * k * 0.25;
}

void vertex() {
	local_pos = VERTEX.xz;
	// Сетка пятна повторяет тот же дисперсионный спектр, что и море.
	vec2 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
	vec2 center = MODEL_MATRIX[3].xz;
	VERTEX.y += spectrum_height(wp, wave_time, wave_wind, wave_amp, wave_power)
		- spectrum_height(center, wave_time, wave_wind, wave_amp, wave_power);
}

void fragment() {
    vec2 p = local_pos * 0.82;
    float t = TIME * 0.45 + seed;
    float d = length(p + vec2(sin(t) * 0.10, cos(t * 0.8) * 0.10)) - 0.96;
    for (int i = 0; i < 4; i++) {
        float a = float(i) * 2.399963 + seed * 2.7;
        vec2 center = vec2(cos(a), sin(a)) * (0.68 + 0.15 * sin(t + float(i)));
        float lobe = length(p - center) - (0.52 + 0.12 * sin(t * 1.2 + float(i) * 2.0));
        d = smooth_union(d, lobe, 0.48);
    }
    float ripple = sin(length(p) * 11.0 - t * 3.8 + atan(p.y, p.x) * 4.0);
    float angle = atan(p.y, p.x);
    d += sin(angle * 5.0 + t * 0.65) * 0.08
        + sin(angle * 9.0 - t * 0.25) * 0.035;
    d += ripple * 0.035 + (hash21(floor(p * 12.0) + floor(t * 0.2)) - 0.5) * 0.025;
    float aa = max(fwidth(d), 0.012);
    float body = 1.0 - smoothstep(-aa, aa, d);
    float edge = exp(-pow(d / 0.19, 2.0));
    float veins = 0.5 + 0.5 * sin(p.x * 7.0 + p.y * 9.0 + t * 2.4);
    vec3 col = pigment * (0.72 + 0.28 * veins);
    col += pigment * edge * (0.8 + 0.5 * sin(t * 2.0));
    col += vec3(0.85, 0.96, 0.90) * edge * pulse * 0.65;
    ALBEDO = col;
    ALPHA = body * (0.63 + 0.17 * veins) * fade;
    EMISSION = pigment * body * (0.10 + 0.20 * pulse) * fade;
}
```

## Полный файл `scripts/game.gd`

GDScript: общий sun_dir / night01 / ветер. SHA-256 исходника: `9a28a2d59c1d59df1d03632fb40855f45b2fd0e5fe8759a305b69cf11e610f0a`.

```gdscript
class_name GameState
extends Node
## Автозагрузка «Game»: глобальное состояние — ветер, солнце, время суток.
## Единственный источник истины о ветре: его читают шейдер песка, моря,
## существ и частицы. Ссылки water/main — для событий (круги на воде).
##
## Никакого HUD и текста не предусмотрено: сила заброса читается по
## удилищу, поклёвка — по поплавку, день/ночь — крутилкой F3.

# --- Светила и палитра (по умолчанию — золотой час над морем) ---
# Направление К солнцу — вар (меняется DEV-панелью F3)
var night01 := 0.0 # 0=день … 1=ночь: красит свет, песок, небо, море, туман
var sun_dir := Vector3(-0.55, 0.185, -0.30).normalized()

const SAND_SUNNY := Color(0.98, 0.62, 0.30)
const SAND_HOT := Color(1.00, 0.78, 0.42)
const SAND_SHADE := Color(0.47, 0.40, 0.56)
const HORIZON_COL := Color(1.00, 0.70, 0.48)
const SKY_COL := Color(0.27, 0.24, 0.44)

const FOG_DISTANCE := 340.0

# --- Ветер ---
var wind_base := 0.18 # дует с моря на берег (почти +X), чуть вдоль берега
var wind_angle := 0.18 # текущее (гуляет вокруг базы)
var wind_strength := 1.0
var elapsed := 0.0

# --- Состояние игрока (читают: камера, музыка, звук) ---
var sprint01 := 0.0 # 0..1 — насколько путник разогнался
var player_altitude := 0.0

# --- Ссылки на узлы (ставит main.gd) ---
var main = null
var water = null # WaterSurface — круги от шагов в воде


func _ready() -> void:
	_ensure_input()


func _process(delta: float) -> void:
	elapsed += delta
	# Ветер живёт: медленно гуляет направление и сила (сумма синусов).
	wind_angle = wind_base + 0.28 * sin(elapsed * 0.021) + 0.12 * sin(elapsed * 0.047 + 1.7)
	wind_strength = 1.0 + 0.22 * sin(elapsed * 0.033 + 4.0) + 0.10 * sin(elapsed * 0.081)


func wind_dir() -> Vector2:
	return Vector2(cos(wind_angle), sin(wind_angle))


func wind_dir_3d() -> Vector3:
	return Vector3(cos(wind_angle), 0.0, sin(wind_angle))


## Страховка: если action-ы из project.godot не подхватились — добавляем кодом.
func _ensure_input() -> void:
	_add_key_action("move_forward", [KEY_W, KEY_UP])
	_add_key_action("move_back", [KEY_S, KEY_DOWN])
	_add_key_action("move_left", [KEY_A, KEY_LEFT])
	_add_key_action("move_right", [KEY_D, KEY_RIGHT])
	_add_key_action("jump", [KEY_SPACE])
	_add_key_action("sprint", [KEY_SHIFT])
	_add_key_action("rod_toggle", [KEY_Q])
	_add_key_action("flashlight", [KEY_F])
	if not InputMap.has_action("rod_cast"):
		InputMap.add_action("rod_cast")
		var mouse := InputEventMouseButton.new()
		mouse.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event("rod_cast", mouse)
	if not InputMap.has_action("rod_recall"):
		InputMap.add_action("rod_recall")
		var mb := InputEventMouseButton.new()
		mb.button_index = MOUSE_BUTTON_RIGHT
		InputMap.action_add_event("rod_recall", mb)
		var k := InputEventKey.new()
		k.physical_keycode = KEY_R
		InputMap.action_add_event("rod_recall", k)


func _add_key_action(action: String, keys: Array) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)
```

## Полный файл `project.godot`

Настройки рендера и стартовой сцены. SHA-256 исходника: `b71c2de69df607c4bfd4f2498b2026de90a1d6ad6c38d7f5f64f113ee02ed376`.

```ini
; Engine configuration file.
; Лодка и цветные SDF-пятна в исходном песчаном море.
; Старую рыбалку можно запустить отдельно: res://scenes/main.tscn.
; Рендерер жёстко зафиксирован: Forward+ (Vulkan) для объёмного тумана,
; glow и SDF-существ. Ввод создаётся кодом (Game._ensure_input), поэтому
; секции [input] нет — действия живут в одном месте.

config_version=5

[application]

config/name="To The Light"
run/main_scene="res://scenes/boat_main.tscn"
config/features=PackedStringArray("4.7", "Forward Plus")
config/icon="res://icon.svg"

[autoload]

Game="*res://scripts/game.gd"

[display]

window/size/viewport_width=1920
window/size/viewport_height=1080

[editor_plugins]

enabled=PackedStringArray()

[rendering]

renderer/rendering_method="forward_plus"
renderer/rendering_method.mobile="gl_compatibility"
anti_aliasing/quality/msaa_3d=2
textures/vram_compression/import_etc2_astc=true
environment/defaults/default_clear_color=Color(0.35, 0.27, 0.38, 1)
```

## Полный файл `scenes/boat_main.tscn`

Сцена лодки (свет создаётся программно). SHA-256 исходника: `49fc65e0eb225a15e1cf2d210757e68ed28d9a4fd7b48ba210885abf746a0780`.

```ini
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/boat_main.gd" id="1_boat"]

[node name="BoatWorld" type="Node3D"]
script = ExtResource("1_boat")
```

## Полный файл `shaders/sky.gdshader`

Fallback sky shader для Compatibility. SHA-256 исходника: `a51ce0a8617a5569e1d14337b141f64c2ff37f4524c2283d10c89f3d82e86f53`.

```gdshader
shader_type sky;

// =====================================================================
// Физически достоверное небо: рассеяние Рэлея, Mie (двухдолевая фаза
// Хеньи-Гринштейна), поглощение озоном, диск солнца, планета.
// По мотивам «Freeman's Sky Shader» (NiwlGames, CC0) — адаптация под
// Compatibility: солнце передаётся uniform'ом (в GLES3-небе нет
// LIGHT0_DIRECTION), высота наблюдателя фиксирована (нет POSITION),
// half-res проход не используется (в GLES3 не заполняется для
// кастомных материалов неба — дали чёрный зенит; считаем напрямую,
// сэмплов меньше: 12×4).
// =====================================================================

group_uniforms Sun;

uniform float sun_intensity : hint_range(0.0, 314.159, 0.1) = 50.0;
uniform vec3 sun_wavelengths = vec3(0.680, 0.550, 0.480);
uniform vec3 sun_direction = vec3(0.16, 0.44, -0.88); // К солнцу (ставится из Game.SUN_DIR)

group_uniforms Atmosphere.Rayleigh;

/** Толщина слоя, где происходит рэлеевское рассеяние (красные закаты). */
uniform float rayleigh_scale_height : hint_range(0.0, 100000.0, 1.0) = 8000.0;
/** Мультирассеяние Рэлея: лёгкая «подсветка» теней, чтобы небо не чернело. */
uniform float rayleigh_multi_scattering : hint_range(0.0, 1.0, 0.001) = 0.025;

group_uniforms Atmosphere.Mie;

/** Толщина слоя Mie-рассеяния (ореол солнца, дымка). */
uniform float mie_scale_height : hint_range(0.0, 1e5, 1.0) = 1200.0;
/** Сила Mie — в пустыне воздуха «толще», ореол солнца богаче. */
uniform float mie_scattering : hint_range(0.0, 1.0, 1e-7) = 8e-6;
uniform float mie_albedo : hint_range(0.0, 1.0, 0.01) = 0.9;
/** Двухдолевая фаза Хеньи-Гринштейна: вперёд/назад и их вес. */
uniform float mie_g_forward : hint_range(0.0, 1.0, 0.01) = 0.85;
uniform float mie_g_backward : hint_range(-1.0, 0.0, 0.01) = -0.15;
uniform float mie_weight : hint_range(0.0, 1.0, 0.01) = 0.85;
/** Мультирассеяние Mie — мягкая вторая доля. */
uniform float mie_multi_scattering : hint_range(0.0, 1.0, 0.01) = 0.30;
uniform float multiscattering_mie_g_forward : hint_range(0.0, 1.0, 0.01) = 0.5;
uniform float multiscattering_mie_g_backward : hint_range(-1.0, 0.0, 0.01) = -0.05;
uniform float multiscattering_mie_weight : hint_range(0.0, 1.0, 0.01) = 0.75;

group_uniforms Atmosphere.Ozone;

const vec3 ozone_extinction = vec3(0.650, 1.881, 0.085) * 1e-6;
uniform float ozone_center : hint_range(0.0, 1e5, 1.0) = 25000.0;
uniform float ozone_width : hint_range(0.0, 1e5, 1.0) = 30000.0;

group_uniforms Planet;

uniform float planet_radius = 6360000.0;
uniform float atmosphere_height = 100000.0;
/** Высота наблюдателя (метры) — Compatibility-небо не даёт POSITION. */
uniform float base_altitude = 4.0;
/** Цвет «планеты» под ногами — золото песка. */
uniform vec3 ground_color = vec3(0.42, 0.28, 0.17);

group_uniforms Clouds;

/** Облака: покрытие неба (0 — чисто, 1 — плотно). */
uniform float cloud_cover : hint_range(0.0, 1.0, 0.01) = 0.5;
/** Резкость края: меньше — мягче и пушистее. */
uniform float cloud_softness : hint_range(0.05, 0.6, 0.01) = 0.22;
/** Размер облаков: больше — крупнее. */
uniform float cloud_size : hint_range(0.4, 3.0, 0.05) = 1.25;
/** Скорость дрейфа, м/с. */
uniform float cloud_drift : hint_range(0.0, 25.0, 0.5) = 7.0;
/** Непрозрачность облачных форм. */
uniform float cloud_opacity : hint_range(0.0, 1.0, 0.01) = 0.92;

group_uniforms Quality;

uniform int view_samples : hint_range(0, 256) = 12;
uniform int sun_samples : hint_range(0, 256) = 4;


float get_atmosphere_radius() {
	return planet_radius + atmosphere_height;
}

// Пересечение луча со сферой (Inigo Quilez)
vec2 ray_sphere_intersection(vec3 ray_origin, vec3 ray_direction, float sphere_radius) {
	float b = dot(ray_origin, ray_direction);
	float c = dot(ray_origin, ray_origin) - sphere_radius * sphere_radius;
	float discriminant = b * b - c;
	if (discriminant < 0.0) {
		return vec2(-1.0);
	}
	float root = sqrt(discriminant);
	return vec2(-b - root, -b + root);
}

// Рэлеевский коэффициент рассеяния: ~1/λ⁴ — вот откуда синева и закаты
vec3 get_rayleigh_scattering() {
	return (1.0 / (sun_wavelengths * sun_wavelengths * sun_wavelengths * sun_wavelengths)) * 1e-6;
}

float get_mie_extinction() {
	return mie_scattering / mie_albedo;
}

// Полная фаза Рэлея
float get_rayleigh_phase(float cos_theta) {
	return 0.05968310365 * (1.0 + cos_theta * cos_theta);
}

// Хеньи-Гринштейн
float henyey_greenstein_phase(float cos_theta, float g) {
	float g2 = g * g;
	return 0.07957747154 * (1.0 - g2) / pow(1.0 + g2 - 2.0 * g * cos_theta, 1.5);
}

float get_mie_phase(float cos_theta, float g_backward, float g_forward, float weight) {
	return mix(
		henyey_greenstein_phase(cos_theta, g_backward),
		henyey_greenstein_phase(cos_theta, g_forward),
		weight
	);
}

// Плотности: Рэлей / Mie / озон
vec3 get_optical_depth_at_point(vec3 position) {
	float altitude = length(position) - planet_radius;
	return vec3(
		exp(-altitude / rayleigh_scale_height),
		exp(-altitude / mie_scale_height),
		max(0.0, 1.0 - abs(altitude - ozone_center) / (ozone_width / 2.0))
	);
}

// Прозрачность пути (закон Ламберта, полушаг)
vec3 get_transmittance(vec3 origin, vec3 direction, float dist, int samples) {
	float step_length = dist / float(samples);
	vec3 accumulated_optical_depth = vec3(0.0);
	vec3 optical_depth_start = get_optical_depth_at_point(origin);
	for (int i = 0; i < samples; i++) {
		vec3 optical_depth_end = get_optical_depth_at_point(origin + direction * float(i + 1) * step_length);
		accumulated_optical_depth += mix(optical_depth_start, optical_depth_end, 0.5) * step_length;
		optical_depth_start = optical_depth_end;
	}
	return exp(-(
		get_rayleigh_scattering() * accumulated_optical_depth.x
		+ get_mie_extinction() * accumulated_optical_depth.y
		+ ozone_extinction * accumulated_optical_depth.z
	));
}

// Интеграл яркости вдоль взгляда
vec3 integrate_radiance(vec3 ray_origin, vec3 ray_direction, float target_distance, int samples, vec3 sun_dir) {
	float cos_theta = dot(ray_direction, sun_dir);
	float step_length = target_distance / float(samples);

	float rayleigh_phase = get_rayleigh_phase(cos_theta);
	float mie_phase = get_mie_phase(cos_theta, mie_g_backward, mie_g_forward, mie_weight);
	float ms_mie_phase = get_mie_phase(cos_theta, multiscattering_mie_g_backward, multiscattering_mie_g_forward, multiscattering_mie_weight);

	vec3 accumulated_optical_depth = vec3(0.0);
	vec3 accumulated_radiance = vec3(0.0);
	vec3 view_transmittance = vec3(0.0);
	vec3 optical_depth_start = get_optical_depth_at_point(ray_origin);

	for (int i = 0; i < samples; i++) {
		vec3 optical_depth_end = get_optical_depth_at_point(ray_origin + ray_direction * float(i + 1) * step_length);
		vec3 step_optical_depth = mix(optical_depth_start, optical_depth_end, 0.5) * step_length;
		accumulated_optical_depth += step_optical_depth;

		vec3 sample_point = ray_origin + ray_direction * (float(i) + 0.5) * step_length;
		view_transmittance = exp(-(
			get_rayleigh_scattering() * accumulated_optical_depth.x
			+ get_mie_extinction() * accumulated_optical_depth.y
			+ ozone_extinction * accumulated_optical_depth.z
		));

		vec3 sun_radiance = vec3(0.0);
		vec2 planet_hit = ray_sphere_intersection(sample_point, sun_dir, planet_radius);
		if (planet_hit.y <= 0.0) {
			vec2 atmosphere_hit = ray_sphere_intersection(sample_point, sun_dir, get_atmosphere_radius());
			vec3 sun_transmittance = get_transmittance(sample_point, sun_dir, atmosphere_hit.y, sun_samples);
			vec3 scattering_coeff = (
				step_optical_depth.x * get_rayleigh_scattering() * rayleigh_phase
				+ step_optical_depth.y * mie_scattering * mie_phase
			);
			sun_radiance = sun_transmittance * sun_intensity * scattering_coeff;
		}
		accumulated_radiance += sun_radiance * view_transmittance;

		// мультирассеяние: мягкая подсветка, чтобы тени дышали
		vec3 rayleigh_ambient = step_optical_depth.x * get_rayleigh_scattering() * rayleigh_multi_scattering;
		vec3 mie_ambient = vec3(step_optical_depth.y * mie_scattering * ms_mie_phase * mie_multi_scattering);
		accumulated_radiance += (rayleigh_ambient + mie_ambient) * view_transmittance;

		optical_depth_start = optical_depth_end;
	}

	// диск солнца (за атмосферой — с прозрачностью пути)
	vec3 sun_disk = vec3(0.0);
	float planet_hit = ray_sphere_intersection(ray_origin, ray_direction, planet_radius).y;
	if (planet_hit < 0.0) {
		sun_disk = smoothstep(0.99975, 1.0, cos_theta) * sun_intensity * view_transmittance;
	}
	return accumulated_radiance + sun_disk;
}

// ---------------------------------------------------------------------
// Облака: мягкий кучевой «потолок» — по мотивам Sunshine Clouds, но
// без композитора и compute (в Compatibility их нет): слой FBM-форм
// рисуется прямо в небе, дёшево и без единой текстуры. Светотень —
// пробой формы со стороны солнца, у кромки против солнца — серебро.
// ---------------------------------------------------------------------
float chash(vec2 p) {
	p = fract(p * vec2(127.1, 311.7));
	p += dot(p, p + 34.23);
	return fract(p.x * p.y);
}

float cnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(chash(i), chash(i + vec2(1.0, 0.0)), f.x),
		mix(chash(i + vec2(0.0, 1.0)), chash(i + vec2(1.0, 1.0)), f.x),
		f.y
	);
}

float fbm2(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	mat2 rot = mat2(vec2(0.80, 0.60), vec2(-0.60, 0.80));
	for (int i = 0; i < 4; i++) {
		v += a * cnoise(p);
		p = rot * p * 2.02;
		a *= 0.5;
	}
	return v;
}

/** Форма облака: низкочастотная масса + высокочастичная «кучевость» кромки. */
float cloud_shape(vec2 p) {
	return fbm2(p) + (fbm2(p * 2.6 + vec2(11.3, 7.1)) - 0.5) * 0.16;
}

vec4 cloud_layer(vec3 dir, vec3 sun_dir) {
	// только над горизонтом; у самого горизонта растворяются в даль
	float band = smoothstep(0.02, 0.16, dir.y);
	if (band <= 0.002) {
		return vec4(0.0);
	}
	vec2 uv = dir.xz / (dir.y + 0.10);
	vec2 p = uv * (3.0 / cloud_size)
		+ vec2(0.916, 0.401) * TIME * cloud_drift * 0.006;
	float shape = cloud_shape(p);
	float thr = mix(0.70, 0.34, cloud_cover);
	float density = smoothstep(thr, thr + cloud_softness, shape);
	if (density <= 0.003) {
		return vec4(0.0);
	}
	// тень/свет: со стороны солнца форма плотнее — значит, мы в тени
	float shape_sun = cloud_shape(p + normalize(sun_dir.xz + vec2(1e-4, 1e-4)) * 0.34);
	float lit = clamp(0.5 + (shape - shape_sun) * 2.1, 0.0, 1.0);
	// низкое солнце — облака теплеют (закатная краска)
	float elev = clamp(sun_dir.y * 1.7, 0.0, 1.0);
	vec3 sun_col = mix(vec3(1.06, 0.63, 0.40), vec3(1.02, 0.99, 0.95), elev);
	vec3 shade_col = mix(vec3(0.60, 0.50, 0.50), vec3(0.56, 0.60, 0.70), elev);
	vec3 col = mix(shade_col, sun_col, lit);
	// серебряная кромка: тонкий край облака против солнца светится
	float rim = 1.0 - smoothstep(0.0, 0.45, density);
	float towards = max(dot(dir, sun_dir), 0.0);
	col += vec3(1.0, 0.87, 0.68) * pow(rim, 3.0) * pow(towards, 5.0) * 1.35;
	return vec4(col, density * band * cloud_opacity);
}

void sky() {
	vec3 final_color = vec3(0.0);
	vec3 sun_dir = normalize(sun_direction);

	vec3 ray_origin = vec3(0.0, planet_radius + base_altitude, 0.0);
	vec3 ray_direction = EYEDIR;

	float atmosphere_radius = get_atmosphere_radius();
	vec2 atmosphere_hit = ray_sphere_intersection(ray_origin, ray_direction, atmosphere_radius);
	vec2 ground_hit = ray_sphere_intersection(ray_origin, ray_direction, planet_radius);
	bool hits_ground = ground_hit.y > 0.0;
	float atmosphere_distance = hits_ground ? ground_hit.x : atmosphere_hit.y;
	int samples = hits_ground ? view_samples / 2 : view_samples;

	final_color = integrate_radiance(ray_origin, ray_direction, atmosphere_distance, samples, sun_dir);

	// «планета» под ногами: золото песка в рассеянном свете
	if (hits_ground) {
		vec3 ground_point = ray_origin + ray_direction * atmosphere_distance;
		vec3 ground_normal = normalize(ground_point);
		float direct_light = max(dot(ground_normal, sun_dir), 0.0);
		vec3 sun_transmittance = vec3(0.0);
		if (direct_light > 0.0) {
			float ground_to_sun = ray_sphere_intersection(ground_point, sun_dir, atmosphere_radius).y;
			sun_transmittance = get_transmittance(ground_point, sun_dir, ground_to_sun, sun_samples);
		}
		vec3 ground_albedo = ground_color * (direct_light * sun_intensity * sun_transmittance) * (1.0 / PI);
		vec3 to_eye = get_transmittance(ray_origin, ray_direction, atmosphere_distance, view_samples);
		final_color += ground_albedo * to_eye;
	}
	// кучевые облака поверх атмосферы
	vec4 cl = cloud_layer(ray_direction, sun_dir);
	final_color = mix(final_color, cl.rgb, cl.a);

	// дебандинг: физический градиент не должен полосить
	// (EYEDIR вместо SCREEN_UV — одинаково работает в Forward+ и Compatibility)
	float dither = fract(sin(dot(EYEDIR.xz * 917.0, vec2(12.9898, 78.233))) * 43758.5453);
	COLOR = final_color + vec3((dither - 0.5) * (2.5 / 255.0));
}
```

# Дополнительные фрагменты (с оригинальными номерами строк)

## Фрагменты `scripts/coast.gd`

Берег: генерация и ночь; остальная часть — геометрия береговой линии и карта высот. Полный файл: https://github.com/Narine545/Journey-clon/blob/d97c301/scripts/coast.gd .

### Строки 1–95

```text
   1 | class_name Coast
   2 | extends MeshInstance3D
   3 | ## Берег: пляж, дюны за спиной и морское дно под водой — одна карта высот.
   4 | ##
   5 | ## Море — на уровне SEA_LEVEL (Y = 0), суша поднимается от уреза вглубь,
   6 | ## за пляжем встают дюны, а по краям залива — дюнные мысы, закрывающие
   7 | ## горизонт. Рельеф — непрерывная функция height_at(); по ней строится
   8 | ## сетка и по ней же (бикубически) ходит физика путника.
   9 | ##
  10 | ## ПОВЕРХНОСТЬ = берег + НАСТОЯЩИЙ ПЕСОК: SandField добавляет смещения
  11 | ## от следов, и физика/камера/ветер идут по этой сумме.
  12 | ##
  13 | ## Урез воды не рисуется по рёбрам сетки: море остаётся гладкой
  14 | ## поверхностью, а fragment-depth и мягкая прозрачность дают чистый
  15 | ## переход у берега. Узкую мокрую кайму красит шейдер песка.
  16 |
  17 | const SIZE := 900.0 # сторона мира (м)
  18 | const SEGMENTS := 760 # 761×761 вершин, ячейка ~1.18 м — урез не «лесенкой»
  19 | const CENTER := Vector2(170.0, 0.0) # центр плоскости
  20 |
  21 | const SEA_LEVEL := 0.0 # уровень моря, м
  22 | const SPAWN_Z := -14.0 # z стартовой точки на пляже
  23 | const SPAWN_INLAND := 26.0 # сколько метров вглубь от уреза
  24 |
  25 | # --- береговой профиль ---
  26 | const BEACH_SLOPE := 0.062 # подъём пляжа от уреза (≈3.5°)
  27 | const BEACH_BERM := 22.0 # где пляж выполаживается в берму (м от уреза)
  28 | const DUNE_FOOT := 34.0 # начало дюн (м от уреза)
  29 | const DUNE_SPAN := 64.0 # ширина подножия дюн (м)
  30 | const BACK_DUNE0 := 130.0 # дальняя стена дюн: начало (м от уреза)
  31 | const BACK_DUNE1 := 330.0 # дальняя стена дюн: полная высота
  32 | const SEABED_SLOPE := 0.085 # уклон дна у берега
  33 | const SEABED_DEEP := 0.17 # уклон дна дальше от берега
  34 |
  35 | # --- ambient occlusion (запекается по карте высот) ---
  36 | const SHORE_LUT_Z0 := -460.0
  37 | const SHORE_LUT_Z1 := 460.0
  38 | const SHORE_LUT_N := 1024
  39 |
  40 | const AO_STEP := 4
  41 | const AO_DIRS := 8
  42 | const AO_RAYS := [2.5, 6.0, 12.0]
  43 |
  44 | var game: GameState # автозагрузка Game
  45 | var sand: SandField # поле настоящего песка (может не быть)
  46 |
  47 | var _coast := FastNoiseLite.new() # изгиб линии уреза
  48 | var _dune := FastNoiseLite.new() # варп дюн
  49 | var _ridge := FastNoiseLite.new() # гребни дюн вдоль берега
  50 | var _macro := FastNoiseLite.new() # где дюны выше/ниже
  51 | var _fine := FastNoiseLite.new() # микродеталь пляжа
  52 | var _bars := FastNoiseLite.new() # песчаные отмели под водой
  53 |
  54 | var _grid := PackedFloat32Array()
  55 | var _dgrid := PackedFloat32Array() # 0 — пляж, 1 — дюны (для шейдера)
  56 | var _ao_grid := PackedFloat32Array()
  57 | ## Одномерная «карта уреза»: shore_x(z). Её читает море, чтобы плавно
  58 | ## растворяться у песка (иначе линия пересечения рвётся треугольниками).
  59 | var shore_lut: ImageTexture
  60 | ## Карта высот поверхности (та же, что у меша): шейдер моря кладёт
  61 | ## плёнку прибоя прямо на песок — иначе на буграх она рвётся лоскутами.
  62 | var height_tex: ImageTexture
  63 | var grid_n := 0
  64 | var grid_origin := Vector2.ZERO
  65 | var grid_cell := 1.0
  66 |
  67 | var _x0 := 0.0
  68 | var _z0 := 0.0
  69 | var _cell := 0.0
  70 | var _row := 0
  71 |
  72 |
  73 | func setup(game_ref) -> void:
  74 | 	game = game_ref
  75 | 	_x0 = CENTER.x - SIZE * 0.5
  76 | 	_z0 = CENTER.y - SIZE * 0.5
  77 | 	_cell = SIZE / float(SEGMENTS)
  78 | 	_row = SEGMENTS + 1
  79 |
  80 | 	_coast.seed = 733
  81 | 	_coast.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
  82 | 	_coast.frequency = 0.010
  83 | 	_coast.fractal_octaves = 2
  84 |
  85 | 	_dune.seed = 517
  86 | 	_dune.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
  87 | 	_dune.frequency = 0.006
  88 | 	_dune.fractal_octaves = 1
  89 |
  90 | 	_ridge.seed = 1373
  91 | 	_ridge.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
  92 | 	_ridge.frequency = 1.0
  93 | 	_ridge.fractal_octaves = 1
  94 |
  95 | 	_macro.seed = 991
```

### Строки 395–502

```text
 395 | 			var d := c + 1
 396 | 			idx[w] = d
 397 | 			idx[w + 1] = c
 398 | 			idx[w + 2] = b
 399 | 			idx[w + 3] = c
 400 | 			idx[w + 4] = a
 401 | 			idx[w + 5] = b
 402 | 			w += 6
 403 |
 404 | 	var arrays := []
 405 | 	arrays.resize(Mesh.ARRAY_MAX)
 406 | 	arrays[Mesh.ARRAY_VERTEX] = verts
 407 | 	arrays[Mesh.ARRAY_NORMAL] = normals
 408 | 	arrays[Mesh.ARRAY_TEX_UV] = uvs
 409 | 	arrays[Mesh.ARRAY_TEX_UV2] = uvs2
 410 | 	arrays[Mesh.ARRAY_INDEX] = idx
 411 |
 412 | 	var coast_mesh := ArrayMesh.new()
 413 | 	coast_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
 414 |
 415 | 	var mat := ShaderMaterial.new()
 416 | 	mat.shader = load("res://shaders/sand.gdshader")
 417 | 	mat.set_shader_parameter("sun_dir", game.sun_dir)
 418 | 	mat.set_shader_parameter("sand_sunny", Game.SAND_SUNNY)
 419 | 	mat.set_shader_parameter("sand_hot", Game.SAND_HOT)
 420 | 	mat.set_shader_parameter("sand_shade", Game.SAND_SHADE)
 421 | 	mat.set_shader_parameter("horizon_col", Game.HORIZON_COL)
 422 | 	mat.set_shader_parameter("sky_col", Game.SKY_COL)
 423 | 	mat.set_shader_parameter("fog_distance", Game.FOG_DISTANCE)
 424 | 	mat.set_shader_parameter("wind_dir", Game.wind_dir())
 425 | 	mat.set_shader_parameter("sand_map", ProcTextures.black_pixel())
 426 | 	mat.set_shader_parameter("sand_texel", SandField.TEXEL)
 427 | 	# мокрая полоса у уреза и подводный песок — красит шейдер
 428 | 	mat.set_shader_parameter("sea_level", SEA_LEVEL)
 429 | 	mat.set_shader_parameter("shore_lut", shore_lut)
 430 | 	# Узкая мокрая кайма сохраняет тёплую палитру суши; вода остаётся
 431 | 	# отдельным холодным материалом.
 432 | 	mat.set_shader_parameter("wet_band", 0.18)
 433 | 	mat.set_shader_parameter("wet_darken", 0.38)
 434 |
 435 | 	mesh = coast_mesh
 436 | 	material_override = mat
 437 | 	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 438 |
 439 |
 440 | func _process(_delta: float) -> void:
 441 | 	if material_override != null:
 442 | 		var m: ShaderMaterial = material_override
 443 | 		m.set_shader_parameter("wind_dir", game.wind_dir())
 444 | 		m.set_shader_parameter("wind_power", game.wind_strength)
 445 | 		if sand != null:
 446 | 			m.set_shader_parameter("sand_origin", Vector2(sand.win_x0, sand.win_z0))
 447 |
 448 |
 449 | func apply_sun(dir: Vector3) -> void:
 450 | 	if material_override != null:
 451 | 		(material_override as ShaderMaterial).set_shader_parameter("sun_dir", dir)
 452 |
 453 |
 454 | ## Ночь красит ПЕСОК: шейдер песка живёт на собственной палитре.
 455 | const DAY_SUNNY := Color(0.93, 0.52, 0.30)
 456 | const DAY_HOT := Color(1.00, 0.68, 0.36)
 457 | const DAY_SHADE := Color(0.40, 0.32, 0.52)
 458 | const DAY_HORIZON := Color(0.96, 0.66, 0.55)
 459 | const DAY_SKY := Color(0.28, 0.24, 0.43)
 460 | const NIGHT_SUNNY := Color(0.135, 0.155, 0.24)
 461 | const NIGHT_HOT := Color(0.19, 0.215, 0.32)
 462 | const NIGHT_SHADE := Color(0.055, 0.065, 0.115)
 463 | const NIGHT_HORIZON := Color(0.22, 0.27, 0.40)
 464 | const NIGHT_SKY := Color(0.04, 0.05, 0.10)
 465 |
 466 |
 467 | func set_night01(v: float) -> void:
 468 | 	if material_override == null:
 469 | 		return
 470 | 	var m: ShaderMaterial = material_override
 471 | 	m.set_shader_parameter("sand_sunny", DAY_SUNNY.lerp(NIGHT_SUNNY, v))
 472 | 	m.set_shader_parameter("sand_hot", DAY_HOT.lerp(NIGHT_HOT, v))
 473 | 	m.set_shader_parameter("sand_shade", DAY_SHADE.lerp(NIGHT_SHADE, v))
 474 | 	m.set_shader_parameter("horizon_col", DAY_HORIZON.lerp(NIGHT_HORIZON, v))
 475 | 	m.set_shader_parameter("sky_col", DAY_SKY.lerp(NIGHT_SKY, v))
 476 | 	m.set_shader_parameter("fog_distance", lerpf(340.0, 130.0, v))
 477 | 	m.set_shader_parameter("glitter_amount", lerpf(0.20, 0.06, v))
 478 | 	m.set_shader_parameter("night_amount", v)
 479 |
 480 |
 481 | func set_sand(param: String, value) -> void:
 482 | 	if material_override != null:
 483 | 		(material_override as ShaderMaterial).set_shader_parameter(param, value)
 484 |
 485 |
 486 | func attach_sand(sand_ref: SandField) -> void:
 487 | 	sand = sand_ref
 488 | 	var m: ShaderMaterial = material_override
 489 | 	m.set_shader_parameter("sand_map", sand_ref.get_texture())
 490 |
 491 |
 492 | func smoothf(v: float, a: float, b: float) -> float:
 493 | 	var t := clampf((v - a) / (b - a), 0.0, 1.0)
 494 | 	return t * t * (3.0 - 2.0 * t)
 495 |
 496 |
 497 | ## 0..1 «бугор» между a и b (нарастает, потом спадает).
 498 | func bump01(v: float, a: float, b: float) -> float:
 499 | 	if v <= a or v >= b:
 500 | 		return 0.0
 501 | 	var t := (v - a) / (b - a)
 502 | 	return sin(PI * t)
```

## Фрагменты `scripts/boat_vessel.gd`

Корпус: материалы, локальный свет и ночные параметры; остальная часть — лодка/прицеп/насос. Полный файл: https://github.com/Narine545/Journey-clon/blob/d97c301/scripts/boat_vessel.gd .

### Строки 1–140

```text
   1 | class_name BoatVessel
   2 | extends Node3D
   3 | ## Малое научно-исследовательское судно («Приливная лаборатория»).
   4 | ## Выверенная геометрия корпуса без выступающих планок на носу,
   5 | ## насос строго по левому борту, прочность корпуса, прожектор и запись мировой траектории следа.
   6 |
   7 | const MAX_SPEED := 10.0
   8 | const REVERSE_SPEED := 4.0
   9 | const ACCELERATION := 3.2
  10 | const DRAG := 1.8
  11 | const TURN_RATE := 0.95
  12 | const PUMP_RANGE := 6.5
  13 | const PUMP_SECONDS := 1.4
  14 |
  15 | const START_WITH_TRAILER := false
  16 | const TRAILER_DISTANCE := 9.3
  17 | const TRAILER_CLEARANCE := 9.15
  18 | const TRAIL_POINTS := 20
  19 | const TRAIL_STEP_TIME := 0.25
  20 |
  21 | var main: BoatMain
  22 | var water: WaterSurface
  23 | var coast: Coast
  24 | var speed := 0.0
  25 | var hull_hp := 100.0
  26 | var has_trailer := false
  27 | var wrong_side_target := false
  28 |
  29 | var _pump_progress := 0.0
  30 | var _anim_time := 0.0
  31 | var _steer_visual := 0.0
  32 | var _refine_flash := 0.0
  33 | var _impact_cooldown := 0.0
  34 |
  35 | var _heave_vel := 0.0
  36 | var _pitch_vel := 0.0
  37 | var _roll_vel := 0.0
  38 |
  39 | var _trail_buffer := PackedVector4Array()
  40 | var _trail_timer := 0.0
  41 | var _last_trail_pos := Vector2.ZERO
  42 |
  43 | var _target: ResourceSlick
  44 | var _body: Node3D
  45 | var _radar: Node3D
  46 | var _rudder: Node3D
  47 | var _prop_l: Node3D
  48 | var _prop_r: Node3D
  49 | var _bow_spot: SpotLight3D
  50 | var _deck_light: OmniLight3D
  51 |
  52 | var _crane_turret: Node3D
  53 | var _crane_boom: Node3D
  54 | var _crane_jib: Node3D
  55 | var _hose: MeshInstance3D
  56 | var _hose_mat: StandardMaterial3D
  57 | var _intake_head: MeshInstance3D
  58 | var _intake_mat: StandardMaterial3D
  59 |
  60 | var _vat_fills: Array[MeshInstance3D] = []
  61 | var _vat_mats: Array[StandardMaterial3D] = []
  62 |
  63 | var _trailer: Node3D
  64 | var _trailer_body: Node3D
  65 | var _tow_cable_l: MeshInstance3D
  66 | var _tow_cable_r: MeshInstance3D
  67 | var _trailer_sight_fills: Array[MeshInstance3D] = []
  68 |
  69 |
  70 | func setup(boat_main: BoatMain, water_ref: WaterSurface, coast_ref: Coast) -> void:
  71 | 	main = boat_main
  72 | 	water = water_ref
  73 | 	coast = coast_ref
  74 | 	_trail_buffer.resize(TRAIL_POINTS)
  75 | 	_reset_trail(Vector2(global_position.x, global_position.z))
  76 |
  77 | 	_body = Node3D.new()
  78 | 	_body.name = "HullAndCabin"
  79 | 	add_child(_body)
  80 | 	_build_appearance()
  81 | 	_build_trailer()
  82 | 	if START_WITH_TRAILER:
  83 | 		set_trailer_enabled(true)
  84 |
  85 |
  86 | func steering_yaw_delta(steer: float, current_speed: float, delta: float) -> float:
  87 | 	return -steer * TURN_RATE * delta * clampf(absf(current_speed) / 3.5, 0.0, 1.0) * (1.0 if current_speed >= 0.0 else -1.0)
  88 |
  89 |
  90 | func effective_max_speed() -> float:
  91 | 	var base := MAX_SPEED + (2.0 if has_trailer else 0.0)
  92 | 	var hp_factor := lerpf(0.60, 1.0, clampf(hull_hp / 100.0, 0.0, 1.0))
  93 | 	var boost := 1.35 if (main != null and main.overdrive_timer > 0.0) else 1.0
  94 | 	return base * hp_factor * boost
  95 |
  96 |
  97 | func effective_pump_range() -> float:
  98 | 	return PUMP_RANGE + (2.5 if has_trailer else 0.0)
  99 |
 100 |
 101 | func effective_pump_seconds() -> float:
 102 | 	return PUMP_SECONDS * (0.70 if has_trailer else 1.0)
 103 |
 104 |
 105 | func update_night_lights(night01: float, overdrive: bool) -> void:
 106 | 	# Локальное освещение — лишь тёплый навигационный акцент. Общий свет
 107 | 	# от луны теперь освещает и море, и берег, и судно одновременно.
 108 | 	if _bow_spot != null:
 109 | 		_bow_spot.light_energy = lerpf(0.12, 0.95, night01) * (1.6 if overdrive else 1.0)
 110 | 		_bow_spot.spot_range = lerpf(18.0, 27.0, night01) * (1.35 if overdrive else 1.0)
 111 | 	if _deck_light != null:
 112 | 		_deck_light.light_energy = lerpf(0.10, 0.30, night01)
 113 | 		_deck_light.omni_range = 5.5
 114 |
 115 |
 116 | func set_trailer_enabled(enabled: bool) -> void:
 117 | 	has_trailer = enabled
 118 | 	if _trailer != null:
 119 | 		_trailer.visible = enabled
 120 | 		var heading := -global_transform.basis.z
 121 | 		_trailer.global_position = global_position - heading * TRAILER_DISTANCE
 122 | 		_trailer.global_rotation = Vector3(0.0, rotation.y, 0.0)
 123 | 	if _tow_cable_l != null:
 124 | 		_tow_cable_l.visible = enabled
 125 | 	if _tow_cable_r != null:
 126 | 		_tow_cable_r.visible = enabled
 127 |
 128 |
 129 | func trigger_refine_effect() -> void:
 130 | 	_refine_flash = 1.0
 131 |
 132 |
 133 | func is_on_port_working_side(world_pos: Vector3) -> bool:
 134 | 	var local := to_local(world_pos)
 135 | 	return local.x < -0.30 and local.z > -4.8 and local.z < 4.8
 136 |
 137 |
 138 | func _physics_process(delta: float) -> void:
 139 | 	if water == null or coast == null:
 140 | 		return
```

### Строки 470–500

```text
 470 |
 471 |
 472 | # ---------------------------------------------------------------------------
 473 | # Инструменты процедурного судостроения
 474 | # ---------------------------------------------------------------------------
 475 |
 476 | func _material(color: Color, metal := 0.0, glow := 0.0, rough := 0.68) -> StandardMaterial3D:
 477 | 	var mat := StandardMaterial3D.new()
 478 | 	mat.albedo_color = color
 479 | 	mat.metallic = metal
 480 | 	mat.roughness = rough
 481 | 	if glow > 0.0:
 482 | 		mat.emission_enabled = true
 483 | 		mat.emission = color
 484 | 		mat.emission_energy_multiplier = glow
 485 | 	return mat
 486 |
 487 |
 488 | func _box_on(parent: Node3D, at: Vector3, size: Vector3, mat: Material, rot := Vector3.ZERO) -> MeshInstance3D:
 489 | 	var part := MeshInstance3D.new()
 490 | 	var box := BoxMesh.new()
 491 | 	box.size = size
 492 | 	part.mesh = box
 493 | 	part.position = at
 494 | 	part.rotation = rot
 495 | 	part.material_override = mat
 496 | 	parent.add_child(part)
 497 | 	return part
 498 |
 499 |
 500 | func _cyl_on(parent: Node3D, at: Vector3, r_top: float, r_bot: float, h: float, mat: Material, rot := Vector3.ZERO, segs := 14) -> MeshInstance3D:
```

### Строки 696–723

```text
 696 | 	_loft_segment(_body, -2.20, -2.40, -2.14, -2.34, 2.26, 2.72, 1.84, 1.96, 1.84, 1.96, bridge_glass)
 697 | 	for mx in [-0.58, 0.0, 0.58]:
 698 | 		_box_on(_body, Vector3(mx, 2.49, -2.31), Vector3(0.05, 0.50, 0.08), cabin_trim, Vector3(-0.38, 0.0, 0.0))
 699 | 	for side in [-1.0, 1.0]:
 700 | 		_box_on(_body, Vector3(side * 1.02, 2.48, -1.32), Vector3(0.06, 0.44, 1.52), bridge_glass)
 701 | 		_box_on(_body, Vector3(side * 1.03, 2.48, -1.32), Vector3(0.07, 0.48, 0.06), cabin_trim)
 702 | 	_box_on(_body, Vector3(-0.48, 2.48, -0.29), Vector3(0.72, 0.42, 0.06), bridge_glass)
 703 |
 704 | 	_loft_segment(_body, -2.62, -2.52, -0.18, -0.22, 2.82, 2.94, 2.28, 2.14, 2.16, 2.04, roof_ochre)
 705 |
 706 | 	# Прожектор, радар и сигнальная мачта
 707 | 	_cyl_on(_body, Vector3(0.0, 3.08, -2.28), 0.11, 0.13, 0.26, dark_iron, Vector3(PI * 0.5 - 0.28, 0.0, 0.0), 12)
 708 | 	_cyl_on(_body, Vector3(0.0, 3.12, -2.38), 0.09, 0.09, 0.06, _material(Color("ffdf9e"), 0.1, 2.0, 0.2), Vector3(PI * 0.5 - 0.28, 0.0, 0.0), 12)
 709 | 	_bow_spot = SpotLight3D.new()
 710 | 	_bow_spot.light_color = Color("ffe8ba")
 711 | 	_bow_spot.light_energy = 2.0
 712 | 	_bow_spot.spot_range = 24.0
 713 | 	_bow_spot.spot_angle = 30.0
 714 | 	_bow_spot.position = Vector3(0.0, 3.12, -2.45)
 715 | 	_bow_spot.rotation = Vector3(-0.34, 0.0, 0.0)
 716 | 	_body.add_child(_bow_spot)
 717 |
 718 | 	_cyl_on(_body, Vector3(0.0, 3.12, -1.35), 0.10, 0.14, 0.36, cabin_chalk)
 719 | 	_radar = Node3D.new()
 720 | 	_radar.position = Vector3(0.0, 3.32, -1.35)
 721 | 	_body.add_child(_radar)
 722 | 	_box_on(_radar, Vector3(0.0, 0.04, 0.0), Vector3(1.08, 0.10, 0.18), cabin_chalk)
 723 |
```

### Строки 798–820

```text
 798 | 	_rudder.position = Vector3(0.0, -0.12, 4.82)
 799 | 	_body.add_child(_rudder)
 800 | 	_box_on(_rudder, Vector3(0.0, 0.0, 0.20), Vector3(0.08, 0.54, 0.42), dark_iron)
 801 |
 802 | 	_prop_l = _build_propeller(Vector3(-0.65, -0.15, 4.72), aged_bronze)
 803 | 	_prop_r = _build_propeller(Vector3( 0.65, -0.15, 4.72), aged_bronze)
 804 |
 805 | 	_deck_light = OmniLight3D.new()
 806 | 	_deck_light.light_color = Color("ffd296")
 807 | 	_deck_light.light_energy = 0.90
 808 | 	_deck_light.omni_range = 9.5
 809 | 	_deck_light.position = Vector3(0.0, 2.35, 2.40)
 810 | 	_body.add_child(_deck_light)
 811 |
 812 | 	_hose = MeshInstance3D.new()
 813 | 	var tube := CylinderMesh.new()
 814 | 	tube.top_radius = 0.06
 815 | 	tube.bottom_radius = 0.085
 816 | 	tube.height = 1.0
 817 | 	_hose.mesh = tube
 818 | 	_hose_mat = _material(Color("2e524e"), 0.2, 0.8, 0.45)
 819 | 	_hose.material_override = _hose_mat
 820 | 	_hose.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
```

## Фрагменты `scripts/water_field.gd`

Волны CPU, синхронизация с шейдером и движение поля. Полный файл: https://github.com/Narine545/Journey-clon/blob/d97c301/scripts/water_field.gd .

### Строки 1–115

```text
   1 | class_name WaterField
   2 | extends Node
   3 | ## Песчаное море: поле СОБЫТИЙ вместо поля высот.
   4 | ##
   5 | ## У SandField высота хранится в торе 800×800 и штампуется следами. Морю
   6 | ## сетка не нужна (вариант А): каждое событие — расходящееся кольцо-пакет,
   7 | ## а «дыхание» моря (мега-рябь песка ~9 м) считается аналитически. Формулы
   8 | ## в точности те же, что в water.gdshader: шейдер рисует нормали, эта нода
   9 | ## даёт физике ВЫСОТУ воды в точке — поплавок качается на том же «одеяле»
  10 | ## и на тех же кольцах, что видит глаз.
  11 | ##
  12 | ## Кольца — ring buffer: при переполнении перезаписывается самый старый
  13 | ## слот (при 24 слотах и жизни 5 с даже спам-клики не вытесняют живое).
  14 | ## Uniform-ы пушатся в материал на 30 Гц — как карта песка у SandField.
  15 | ##
  16 | ## Вариант Б (настоящее волновое уравнение на compute) садится сюда же:
  17 | ## у WaterField тот же публичный API (height_at / splash / nibble / wake).
  18 |
  19 | const MAX_RINGS := 24
  20 | const RING_LIFE := 5.0 # с, после — слот освобождается
  21 |
  22 | const RING_SPEED := 1.5 # м/с, фронт (должно совпадать с шейдером)
  23 | const RING_WAVELEN := 0.85
  24 | const RING_TAU := 0.55
  25 | const RING_W0 := 0.30
  26 | const RING_WG := 0.18
  27 | const RING_AMP := 0.055
  28 |
  29 | const PUSH_HZ := 30.0 # частота пуша uniform-ов
  30 |
  31 | var t := 0.0 # время поля — ЕДИНОЕ с шейдерным u_time
  32 | var mat: ShaderMaterial # куда пушим кольца (назначает WaterSurface)
  33 |
  34 | # Живой ветер: WaterSurface обновляет каждый кадр из game (как у песка),
  35 | # чтобы физика поплавка качалась ровно на том «одеяле», что рисует шейдер.
  36 | var wind_dir := Vector2(0.32, -0.95)
  37 | var wind_power := 1.0
  38 | var mega_amp := 0.055 # дыхание моря — синхронно с uniform-ом шейдера
  39 | # Только лодочная сцена переопределяет эти параметры для штормового моря.
  40 | var ring_amp := RING_AMP
  41 | var wake_interval := 0.33
  42 | var wake_strength := 0.30
  43 | var swell_time_rate := 0.25
  44 | var chop_strength := 0.0
  45 | var use_spectrum := false # лодочное море: дисперсионные волны вместо песчаного шума
  46 |
  47 | var _pos := PackedVector2Array()
  48 | var _t0 := PackedFloat32Array()
  49 | var _amp := PackedFloat32Array()
  50 | var _cursor := 0
  51 | var _push_clock := 0.0
  52 | var _last_wake := -10.0
  53 |
  54 |
  55 | func _ready() -> void:
  56 | 	_pos.resize(MAX_RINGS)
  57 | 	_t0.resize(MAX_RINGS)
  58 | 	_t0.fill(-1000.0) # все слоты «давно умерли»
  59 | 	_amp.resize(MAX_RINGS)
  60 | 	_amp.fill(0.0)
  61 |
  62 |
  63 | # ---------------------------------------------------------------------------
  64 | # Публичное API
  65 | # ---------------------------------------------------------------------------
  66 |
  67 | ## Всплеск: посадка поплавка, прыжок рыбы, брошенный камень.
  68 | ## strength 1.0 — поплавок; 1.5–2.0 — что-то покрупнее.
  69 | func splash(pos: Vector2, strength := 1.0) -> void:
  70 | 	_add_ring(pos, clampf(strength, 0.1, 2.0))
  71 |
  72 |
  73 | ## Поклёвка: короткая серия из трёх убывающих колец — «буль-буль-буль».
  74 | func nibble(pos: Vector2) -> void:
  75 | 	_add_ring(pos, 0.45)
  76 | 	_add_ring(pos + Vector2(0.12, 0.05), 0.30)
  77 | 	_add_ring(pos + Vector2(-0.08, 0.10), 0.20)
  78 |
  79 |
  80 | ## След в воде: подмотка поплавка, брод путника. Тротлится по времени.
  81 | func wake(pos: Vector2, strength := 1.0) -> void:
  82 | 	if t - _last_wake < wake_interval:
  83 | 		return
  84 | 	_last_wake = t
  85 | 	_add_ring(pos, wake_strength * clampf(strength, 0.0, 2.0))
  86 |
  87 |
  88 | ## Высота воды в точке СЕЙЧАС: дыхание (мега-рябь) + все живые кольца.
  89 | ## Зеркало шейдерной математики (mega_phase + кольца) — поплавок и физика
  90 | ## качаются ровно на той воде, которую рисует шейдер.
  91 | func height_at(x: float, z: float) -> float:
  92 | 	var h := _spectrum_height(x, z) if use_spectrum else _mega_h_cpu(x, z)
  93 | 	for i in range(MAX_RINGS):
  94 | 		var a := _amp[i]
  95 | 		if a < 0.0005:
  96 | 			continue
  97 | 		var age := t - _t0[i]
  98 | 		if age < 0.0:
  99 | 			continue
 100 | 		var dd := Vector2(x, z).distance_to(_pos[i])
 101 | 		var rf := RING_SPEED * age
 102 | 		var bw := RING_W0 + RING_WG * age
 103 | 		var xx := (dd - rf) / bw
 104 | 		var env := exp(-xx * xx)
 105 | 		var ph := TAU / RING_WAVELEN * (dd - rf)
 106 | 		var dec := exp(-age * RING_TAU) / sqrt(maxf(rf, 0.6))
 107 | 		h += ring_amp * a * env * cos(ph) * dec
 108 | 	return h
 109 |
 110 |
 111 | ## Высота поверхности для ноды воды (уровень добавляет WaterSurface).
 112 | func surface_offset(x: float, z: float) -> float:
 113 | 	return height_at(x, z)
 114 |
 115 |
```

## Фрагменты `scripts/sand_field.gd`

Карта деформации песка: источник нормалей и следов. Полный файл: https://github.com/Narine545/Journey-clon/blob/d97c301/scripts/sand_field.gd .

### Строки 1–85

```text
   1 | class_name SandField
   2 | extends Node
   3 | ## Настоящий песок: поле смещений высоты (CPU-симуляция) + карта для шейдера.
   4 | ##
   5 | ## Путник РЕАЛЬНО продавливает песок: след — это геометрия (вершинное
   6 | ## смещение в шейдере террейна) и настоящие нормали (стенки следа ловят
   7 | ## солнце, вал выброшенного песка светится свежим песком). Физика ходит
   8 | ## по той же карте: путник ступает в собственные следы.
   9 | ##
  10 | ## Песок ведёт себя как песок:
  11 | ##   • свежевыкопанный ОСЕДАЕТ (релаксация пятен);
  12 | ##   • осыпается, если склон круче угла естественного откоса (талюс);
  13 | ##   • медленно ЗАНОСИТСЯ ветром (старение + плавное растворение у края
  14 | ##     окна — след «затягивается», когда путник уходит вперёд).
  15 | ##
  16 | ## Хранение: тор N×N текселей, привязанный к МИРОВОЙ сетке, — окно
  17 | ## скользит за путником без копирования: новые столбцы/строки просто
  18 | ## обнуляются. Карта отдаётся шейдеру как ImageTexture (R32F), шейдер
  19 | ## адресует её через mod() с REPEAT — шов тора незаметен.
  20 |
  21 | const N := 800 # текселей на сторону карты
  22 | const TEXEL := 0.12 # метров на тексель
  23 | const EXTENT := float(N) * TEXEL # окно 96×96 м вокруг путника
  24 |
  25 | const MAX_DEPTH := 0.26 # предельное продавливание, м
  26 | const MAX_RISE := 0.13 # предельная высота вала, м
  27 |
  28 | const SETTLE_BLEND := 0.26 # доля оседания за визит точки релаксации
  29 | const TALUS_STEP := 0.075 # перепад на тексель (~32°), после которого песок «течёт»
  30 | const TALUS_MOVE := 0.26 # доля переноса за визит
  31 |
  32 | # Занос ветром: 4 строки карты в кадр (полный проход 3.3 с), множитель за
  33 | # проход 0.86 → полураспад ~15 с: след visibly затягивается меньше чем за
  34 | # минуту. В порывы ветра (wind_strength до ~1.3) занос заметно быстрее.
  35 | const AGE_ROWS_PER_FRAME := 4
  36 | const AGE_ROW_FACTOR := 0.86 # ^wind_strength в рантайме
  37 | const AGE_SYNC_ROWS := 200 # строк старения, после которых карту всё же грузим
  38 |
  39 | const SPOT_VISITS := 128 # точек релаксации за кадр
  40 | const SPOT_TTL := 1.0 # жизнь точки релаксации, с
  41 | const SPOT_CAP := 420 # максимум точек (потом новые игнорируем)
  42 |
  43 | var stamp_count := 0 # диагностика / smoke-тест
  44 |
  45 | var game: GameState # автозагрузка Game (сила ветра для заноса)
  46 | var player: Player # за кем скользит окно
  47 |
  48 | var _grid := PackedFloat32Array() # тор: [sj * N + si], мировые смещения (м)
  49 | var _tex: ImageTexture
  50 | var _img: Image
  51 |
  52 | var _min_gi := 0 # глобальная ячейка края окна (мир замощен сеткой TEXEL)
  53 | var _min_gj := 0
  54 | var win_x0 := 0.0 # мировой угол окна — уходит в шейдер
  55 | var win_z0 := 0.0
  56 |
  57 | var _spots: Array[Vector2i] = [] # активные точки релаксации (глобальные ячейки)
  58 | var _spot_life: PackedFloat32Array = []
  59 | var _age_row := 0
  60 | var _age_since_upload := 0
  61 | var _upload_pending := false
  62 | var _upload_clock := 0.0
  63 | var _churn := FastNoiseLite.new()
  64 |
  65 | const _DIRS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
  66 |
  67 |
  68 | func setup(game_ref = null) -> void:
  69 | 	game = game_ref
  70 | 	_grid.resize(N * N)
  71 | 	_grid.fill(0.0)
  72 | 	_churn.seed = 4242
  73 | 	_churn.noise_type = FastNoiseLite.TYPE_SIMPLEX
  74 | 	_churn.frequency = 0.35
  75 | 	_churn.fractal_octaves = 1
  76 | 	_upload()
  77 |
  78 |
  79 | # ---------------------------------------------------------------------------
  80 | # Публичное API
  81 | # ---------------------------------------------------------------------------
  82 |
  83 | ## Текстура карты для шейдера террейна.
  84 | func get_texture() -> ImageTexture:
  85 | 	return _tex
```

## Фрагменты `scripts/boat_hud.gd`

Панель A/B: ночные пресеты, экспозиция и FPS. Полный файл: https://github.com/Narine545/Journey-clon/blob/d97c301/scripts/boat_hud.gd .

### Строки 78–110

```text
  78 |
  79 | 	# 2. КРУГОВОЙ ПЕЛЕНГАТОР-КОМПАС (справа от главной панели)
  80 | 	_draw_beacon_compass(font, Vector2(505, 102), 58.0, backdrop, accent, warn, muted, ink)
  81 |
  82 | 	# Отладка всегда доступна в лодочном режиме; [0] прячет только панель.
  83 | 	if main.debug_panel_visible:
  84 | 		var dbg := Vector2(size.x - 355.0, 22.0)
  85 | 		draw_rect(Rect2(dbg, Vector2(333, 214)), backdrop)
  86 | 		draw_rect(Rect2(dbg, Vector2(333, 214)), Color("548c89"), false, 1.0)
  87 | 		draw_string(font, dbg + Vector2(12, 23), "БЫСТРАЯ ПРОВЕРКА  •  %d FPS" % Engine.get_frames_per_second(),
  88 | 			HORIZONTAL_ALIGNMENT_LEFT, 309, 14, accent)
  89 | 		draw_string(font, dbg + Vector2(12, 47), "[0] — СКРЫТЬ / ПОКАЗАТЬ", HORIZONTAL_ALIGNMENT_LEFT, 309, 13, ink)
  90 | 		draw_string(font, dbg + Vector2(12, 70), "[4] — +3 ГОТОВЫХ КАЖДОГО ЦВЕТА", HORIZONTAL_ALIGNMENT_LEFT, 309, 13, ink)
  91 | 		draw_string(font, dbg + Vector2(12, 93), "[5] — ДЕНЬ / СУМЕРКИ / НОЧЬ", HORIZONTAL_ALIGNMENT_LEFT, 309, 13, ink)
  92 | 		draw_string(font, dbg + Vector2(12, 116), "[6] — К СЛЕДУЮЩЕМУ БУЮ", HORIZONTAL_ALIGNMENT_LEFT, 309, 13, ink)
  93 | 		draw_string(font, dbg + Vector2(12, 139), "[7] — ПРОДОЛЖИТЬ ВРЕМЯ", HORIZONTAL_ALIGNMENT_LEFT, 309, 13, ink)
  94 | 		draw_string(font, dbg + Vector2(12, 162), "[8] / [9] — НОЧНОЙ ОБЪЁМ - / +", HORIZONTAL_ALIGNMENT_LEFT, 309, 13, ink)
  95 | 		draw_string(font, dbg + Vector2(12, 185), "[L] — СВЕТ AgX / FILMIC: %s" % (
  96 | 			"AgX" if main.debug_lighting_profile else "FILMIC"),
  97 | 			HORIZONTAL_ALIGNMENT_LEFT, 309, 13, accent)
  98 | 		draw_string(font, dbg + Vector2(12, 207),
  99 | 			"НОЧЬ %d%%  %s  •  СВЕТ %.2f  ТУМАН %.3f" % [int(main.night01 * 100.0),
 100 | 				"ПАУЗА" if main.debug_night_paused else "ИДЁТ",
 101 | 				main.debug_night_fill, main.world._env.fog_density],
 102 | 			HORIZONTAL_ALIGNMENT_LEFT, 309, 11, muted)
 103 |
 104 | 	# 3. КОНТЕКСТНАЯ ПОДСКАЗКА ДЕЙСТВИЯ ВНИЗУ ЭКРАНА
 105 | 	var dock_b := main.nearby_dock_beacon()
 106 | 	var resource_name := main.boat.target_name()
 107 | 	var action := "ИЩИТЕ СВЕТЯЩИЕСЯ ПЯТНА И ЗАЖИГАЙТЕ МАЯКИ НА БЕРЕГУ"
 108 | 	var action_col := ink
 109 |
 110 | 	if not dock_b.is_empty():
```
