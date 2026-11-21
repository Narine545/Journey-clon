"""Посёлок «Золочёный прилив»: дома на суше, свой силуэт у каждого, площадь и
храмы на месте, замена визуала и коллизия сохранены.

Текст-пины, без запуска движка: тест ловит возврат к «пяти одинаковым
коробкам», поломку расстановки и потерянные крючки замены моделей.
"""
from pathlib import Path

main = Path('scripts/boat_main.gd').read_text()
village = Path('scripts/island_village.gd').read_text()
cottage = Path('scripts/village_cottage.gd').read_text()
chapel = Path('scripts/village_chapel.gd').read_text()
shrine = Path('scripts/village_shrine.gd').read_text()
scene = Path('scenes/village/cottage.tscn').read_text()
shots = Path('scripts/light_shots.gd').read_text()
smoke = Path('scripts/boat_smoke.gd').read_text()

# --- Расстановка ---------------------------------------------------------
assert 'village.setup(self)' in main
assert village.count('"at": Vector2(') == 7, 'семь домов: набережная и Верхняя улица'
assert 'main.coast.ground_height(p.x, p.z)' in village
assert 'GroundedUnpavedLane' in village and '_road_strip(surface, QUAY_LANE, 3.2, true)' in village
assert 'UPPER_LANE' in village and 'CHAPEL_WALK' in village
# Улицы — ломаные по рельефу, а не один отрезок и не прямоугольник.
assert village.count('Vector2(') > 40
assert 'PlazaPaving' in village and 'Plaza' in village
# Съезд с пирса: посёлок связан с причалом, а не висит на скале.
assert 'PierBridge' in village and '_build_bridge()' in village

# --- Разные дома, а не один крашеный ------------------------------------
assert 'func _palette_for' in cottage and 'palette["glass"]' in cottage
for silhouette in ('_oriel', '_corner_tower', '_belfry', '_porch', '_buttresses'):
    assert silhouette in cottage, silhouette
assert 'match style:' in cottage
# Старый MultiMesh из одинаковых кубиков возвращать нельзя: он и давал
# «роботизированный» ряд коробок.
assert 'MultiMesh' not in cottage
assert 'GiltShapes.pointed_arch' in cottage and 'lancet(' in cottage
# Замена визуала и коллизия — прежние крючки, они обязаны остаться.
assert '@export var replacement_visual: PackedScene' in cottage
assert 'replacement_visual.instantiate()' in cottage
assert 'StaticBody3D.new()' in cottage and 'BuildingCollision' in cottage
assert 'const WIDTH := 5.8' in cottage and 'const DEPTH := 4.3' in cottage
assert 'res://scripts/village_cottage.gd' in scene
assert 'class_name GiltCottage' in cottage

# --- Храмы и площадь -----------------------------------------------------
assert 'class_name GiltChapel' in chapel and 'class_name GiltShrine' in shrine
assert '_build_chapel()' in village and '_build_shrine()' in village
assert 'ChapelPodium' in village and 'ChapelSteps' in village
assert 'chapel.set_night(amount)' in village and 'shrine.set_night(amount)' in village
assert 'props.fountain(' in village and 'props.gate(' in village
assert 'props.mooring_bell(' in village and 'props.stall(' in village

# --- Земля посёлка -------------------------------------------------------
assert 'coast.set_gilt(IslandVillage.PLAZA' in main
coast = Path('scripts/coast.gd').read_text()
sand = Path('shaders/sand.gdshader').read_text()
assert 'func set_gilt(' in coast and '"gilt_center"' in coast
assert 'uniform vec2 gilt_center' in sand and 'gilt_mask' in sand
assert 'uniform vec3 gilt_tint' in sand

# --- Проверки и кадры ----------------------------------------------------
assert '_check_village()' in smoke
assert 'village.chapel' in smoke and 'village.shrine' in smoke
for shot in ('light_22_village_day', 'light_23_village_night', 'light_24_village_street',
             'light_25_village_dusk', 'light_26_shrine_night', 'light_27_shrine_day'):
    assert shot in shots, shot
assert 'HABS MA-857' in Path('docs/world/harbor_village.md').read_text()
# --- Ни одна вызванная локальная функция не должна «исчезнуть» ----------
# Ровно это уронило импорт в CI: _build_shrine() вызывался, а функции не было,
# и Godot валил компиляцию всей цепочки скриптов.
import re as _re
for name, source in (('island_village', village), ('cottage', cottage),
                     ('chapel', chapel), ('shrine', shrine)):
    defined = set(_re.findall(r'^(?:static )?func (\w+)\(', source, _re.M))
    called = set(_re.findall(r'(?<![\w.])(_\w+)\(', source))
    missing = sorted(called - defined)
    assert not missing, f'{name}: вызываются, но не определены: {missing}'
print('check_village: ok')
