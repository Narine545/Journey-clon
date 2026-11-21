"""Слой стиля «Золочёный прилив»: vaporwave × gothic.

Проверяется не «красиво ли», а то, что слой подключён, питается тем же
временем суток, что и мир, не лезет поверх бумажного HUD и умеет
выключаться одним числом (фото-режим и сравнение «до/после»).
"""
from pathlib import Path

main = Path('scripts/boat_main.gd').read_text()
style = Path('scripts/gilt_style.gd').read_text()
shader = Path('shaders/gilt_style.gdshader').read_text()
palette = Path('scripts/art/palette.gd').read_text()
cot = Path('scripts/village_cottage.gd').read_text()
cha = Path('scripts/village_chapel.gd').read_text()

# --- Подключение ---------------------------------------------------------
assert 'var style_layer: GiltStyle' in main
assert 'style_layer = GiltStyle.new()' in main
assert 'style_layer.setup()' in main
assert 'style_layer.set_night(night01)' in main
# Слой — отдельный CanvasLayer НИЖЕ HUD (слой 12) и выше мира.
assert 'layer = 11' in style
# Сравнение «до/после» на ходу: одна клавиша, четыре ступени, ноль = выкл.
assert 'KEY_C:' in main and 'set_intensity' in main

# --- Шейдер: два стиля, три ручки, ноль при intensity = 0 ----------------
for knob in ('intensity', 'night01', 'structure', 'aberration'):
    assert f'uniform float {knob}' in shader, knob
assert 'neon_a' in shader and 'neon_b' in shader and 'gilt' in shader
assert 'hint_screen_texture' in shader
# При нулевой силе кадр возвращается как есть — без «остаточного» фильтра.
assert 'mix(texture(screen_tex, uv).rgb, col, clamp(intensity, 0.0, 1.0))' in shader
# Днём золото, ночью неон: баланс задаётся одним параметром.
assert 'gilt_amount' in shader and 'night01' in shader

# --- Палитра: один словарь на весь мир --------------------------------
for token in ('BASALT', 'SLATE', 'GILT', 'ENAMEL', 'LAMP_NEON',
              'LAMP_MAGENTA', 'LAMP_VIOLET', 'STONE_COLD'):
    assert f'const {token}' in palette, token
assert 'class_name GiltPalette' in palette
assert 'GiltPalette.LAMP_MAGENTA' in cot and 'GiltPalette.LAMP_NEON' in cot
assert 'GiltPalette.LAMP_NEON' in cha
# Пять домов — пять красок стекла: посёлок не должен снова стать однотонным.
for tint in ('LAMP_MAGENTA', 'LAMP_NEON', 'LAMP_VIOLET', 'ff9bb0', 'b8ffe8'):
    assert tint in cot, tint

# --- Геометрия: своя библиотека вместо кубиков -------------------------
shapes = Path('scripts/art/gilt_shapes.gd').read_text()
assert 'class_name GiltShapes' in shapes
for func in ('pointed_arch', 'lancet', 'gable_roof', 'hip_roof', 'spire',
             'ring', 'crest', 'extrude_z', 'facing'):
    assert f'static func {func}' in shapes, func
# Ориентация деталей: окно ставится на любой фасад через базис, без второй
# реализации «окна на север».
assert 'static func facing' in shapes and 'bx * Vector3' in shapes
props = Path('scripts/art/gilt_props.gd').read_text()
for piece in ('gate', 'lamp_post', 'fountain', 'stall', 'fence', 'barrel',
              'mooring_bell', 'drying_rack', 'arch', 'store_hut'):
    assert f'func {piece}(' in props, piece
assert 'gilt_neon_water.gdshader' in props
# Стекло будки-склада не «ночь навсегда»: днём ланцет не горит бирюзой.
# Стекло props должно загораться со всем посёлком: сеток несколько,
# поэтому set_night помнит их все, а не одну.
assert '_glow.append(glass)' in props
assert 'for node in _glow:' in props
hut = props.split('func store_hut(', 1)[1].split('\nfunc ', 1)[0]
assert 'GiltPalette.LEAD, _night,' in hut, 'store_hut: стекло по текущему вечеру'
assert ', 1.0, 0.05' not in hut, 'store_hut: night01 не должен быть константой'
# Будка стоит у съезда: окна и полосы на обеих длинных стенах.
assert 'for face in [1.0, -1.0]' in hut, 'store_hut: ланцет только на одной стене'
print('check_gilt_style: ok')
