"""Ночные киты — тот же SDF-рендер существ, что рыбы модуля рыбалки.

Проверяем не «нарисованы ли киты», а чем именно они нарисованы: никаких
мешей-примитивов и голых материалов, только SandFish + sand_sea_sdf.gdshader
(хребет из плавленых сфер, спинной гребень, хвостовая лопасть, брызги).
"""
from pathlib import Path

whales = Path('scripts/sea_whales.gd').read_text()
fish = Path('scripts/sand_fish.gd').read_text()
boat = Path('scripts/boat_main.gd').read_text()
shots = Path('scripts/light_shots.gd').read_text()
smoke = Path('scripts/boat_smoke.gd').read_text()
shader = Path('shaders/sand_sea_sdf.gdshader').read_text()

assert 'class_name SeaWhales' in whales
# Рендер — модуль рыбалки, а не собственный набор примитивов.
assert 'SandFish.new()' in whales
assert 'res://shaders/sand_sea_sdf.gdshader' in fish
assert '_fish.setup(main.game, main.water.level_y, main.water.field, null)' in whales
assert 'apply_night01' in whales and 'apply_sun' in whales
# Ни одного меша-примитива: тело целиком процедурное.
for banned in ('SphereMesh', 'BoxMesh', 'CapsuleMesh', 'CylinderMesh',
               'StandardMaterial3D', 'MeshInstance3D.new()'):
    assert banned not in whales, banned
# Ленивый слой: при запуске (день, гавань) китов не существует.
assert 'const NIGHT_ON := 0.16' in whales
assert 'if night01 < NIGHT_ON:' in whales
assert 'const WHALE_COUNT := 2' in whales
# Ночной полноэкранный проход дешевле рыбьего: крупному телу хватает грубее.
assert 'const SDF_STEPS := 48' in whales and 'const SDF_EPSILON := 0.03' in whales
assert 'set_shader_parameter("max_steps", SDF_STEPS)' in whales
assert 'const WHALE_SCALE := 1.9' in whales
# Стая ставится дугой перед точкой и переставляется, если судно ушло.
assert 'place_school(at, fwd, SCHOOL_RADIUS, TINT)' in whales
assert 'REGROUP_DIST' in whales
assert 'func place_school(' in fish
# Само тело в шейдере — плавленые сферы + эллипсоидная лопасть.
assert 'fish_sdf(' in shader
assert 'sd_ell(' in shader
# Проводка в игре, в головном тесте и в кадрах CI.
assert 'sea_whales.advance(delta, night01)' in boat
assert 'main.sea_whales.place_near(main._camera_focus, fwd.normalized())' in shots
assert 'light_21_whales_00' in shots
assert '_check_sea_whales()' in smoke
print('check_sea_whales: ok')
