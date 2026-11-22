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
assert village.count('"at": Vector2(') == 8, 'восемь домов: две линии улицы и дом пастора'
assert 'floor_height := BASE_Y + 0.06' in village
assert 'VillageBase' in village and 'VillageStreets' in village
assert 'BASE_RECT' in village and 'MAIN_STREET' in village and 'BACK_STREET' in village
# Улицы — прямые полосы на каменной плите, а не ленты по рельефу.
assert 'func _build_foundation(' in village and 'func _flat_quad(' in village
assert 'PlazaPaving' in village and 'Plaza' in village
# Съезд с пирса: посёлок связан с причалом, а не висит на скале.
assert 'PierBridge' in village and '_build_bridge()' in village
assert 'props.quay()' in village and 'VillageProps.QUAY_Y' in village
assert 'VillageResident' not in village and 'resident_nodes' not in village

# --- Новые дома, жители и клик -------------------------------------------
house = Path('scripts/village_house.gd').read_text()
people = Path('scripts/village_people.gd').read_text()
props = Path('scripts/village_props.gd').read_text()
portrait = Path('scripts/village_portrait.gd').read_text()
interaction = Path('scripts/village_interaction.gd').read_text()
assert 'class_name GiltHouse' in house and house.count('"width":') >= 8
assert 'func build_site(' in house and 'func ray_distance(' in house
assert 'class_name VillagePeople' in people and people.count('"house":') >= 10
assert 'func line_for(' in people and 'func scene_for(' in people
assert 'class_name VillageProps' in props and 'func quay(' in props and 'func hjell(' in props
assert 'func rowboat(' in props and 'func boat_node(' in props
assert not Path('scripts/village_resident.gd').exists(), '3D-заглушки жителей удалены'
assert 'class_name VillagePortrait' in portrait and 'func set_person(' in portrait
assert 'class_name VillageInteraction' in interaction and 'person_id' in interaction
assert 'func _on_talk(' in interaction and 'func _close(' in interaction
assert 'portrait_path' in portrait and 'portrait_texture' in portrait
assert '_apply_gift' not in interaction
assert 'main.village_panel_open = false' in interaction
assert 'main.harbor.moored' in interaction and 'village_panel_open' in interaction
assert 'village_interaction = VillageInteraction.new()' in main and 'village_panel_open' in main
assert 'PORT_VIEW_FOCUS' in main and 'PORT_VIEW_SIZE' in main
assert 'RAMP_WELL' in props and '_deck_quad' in props and 'BRIDGE_FINISH' in village
assert 'ЛКМ ПО ДОМУ' in Path('scripts/boat_hud.gd').read_text()

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
assert 'props.tree(' not in village and 'props.rocks(' not in village

# --- Земля посёлка -------------------------------------------------------
assert 'coast.set_gilt(IslandVillage.PLAZA' not in main
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
# Кадры посёлка — отдельный прогон (TIDE_LIGHT_SET): с ними серия света
# перестала укладываться в лимит шага CI и падала по таймауту.
assert 'TIDE_LIGHT_SET' in shots and 'func _village_shots()' in shots
_wf = Path('.github/workflows/validate.yml').read_text()
for _lane in ('village', 'harbor', 'sea', 'raid'):
    assert f'TIDE_LIGHT_SET={_lane}' in _wf, _lane
assert 'HABS MA-857' in Path('docs/world/harbor_village.md').read_text()
# --- Ни одна вызванная локальная функция не должна «исчезнуть» ----------
# Ровно это уронило импорт в CI: _build_shrine() вызывался, а функции не было,
# и Godot валил компиляцию всей цепочки скриптов.
import re as _re
for name, source in (('island_village', village), ('cottage', cottage),
                     ('chapel', chapel), ('shrine', shrine), ('house', house),
                     ('props', props), ('portrait', portrait),
                     ('interaction', interaction)):
    source = '\n'.join(line for line in source.splitlines() if not line.strip().startswith('#'))
    defined = set(_re.findall(r'^(?:static )?func (\w+)\(', source, _re.M))
    called = set(_re.findall(r'(?<![\w.])(_\w+)\(', source))
    missing = sorted(called - defined)
    assert not missing, f'{name}: вызываются, но не определены: {missing}'
print('check_village: ok')

# Габариты основных корпусов в метрах; у нынешней расстановки все дома
# повёрнуты на 90 градусов, поэтому ширина фасада идёт вдоль Z.
import re
plans = {name: (float(w), float(d)) for name, w, d in re.findall(
    r'"(\w+)": \{\s*"sign": [^\n]*?"width": ([\d.]+), "depth": ([\d.]+)', house)}
sites = re.findall(r'"at": Vector2\(([\d.]+),\s*([-\d.]+)\), "yaw": ([^,]+),\s*\n\s*"plan": "(\w+)"', village)
assert len(sites) == 8
for i, (x, z, yaw, name) in enumerate(sites):
    assert 'PI * 0.5' in yaw
    w, d = plans[name]
    for X, Z, _, other in sites[i + 1:]:
        W, D = plans[other]
        clearance_x = abs(float(x) - float(X)) - (d + D) / 2
        clearance_z = abs(float(z) - float(Z)) - (w + W) / 2
        assert max(clearance_x, clearance_z) >= 0.4, (name, other)
assert 'var y1 := y0 - course_h - 0.003' in props
assert 'Vector3(0.30, 3.30, RAMP_WELL.size.y)' not in props

# Диалоги должны оставаться частью визуального языка игры.
assert 'TideKit.panel(' in interaction and 'TideKit.button(' in interaction
assert 'TideTokens.style_body' in interaction
assert 'light_28_flagpole' in shots and 'light_29_village_dialog' in shots
assert 'props.flagpole(Vector3(166.7, QUAY_Y - 0.02, -18.4)' in village

# Регрессии из реального запуска: светильник часовни включён в запечённую
# геометрию, и полотно воротника состоит из простых треугольников.
commit_section = chapel.split('func _commit() -> void:', 1)[1].split('func _lantern(', 1)[0]
assert commit_section.index('_lantern(') < commit_section.index('_bake("Gilt"')
assert 'func collar_triangles(' in portrait and 'draw_colored_polygon(triangle, accent)' in portrait
assert 'var _painted_window' not in house
assert 'var _time := 0.0' not in Path('scripts/art/gilt_props.gd').read_text()
assert 'float(i / 3)' not in props and 'float(i / 2)' not in house
assert 'var basis := GiltShapes.facing' not in chapel
assert 'nose_top - nose_bottom' in props and 'nose_x + 0.55' in props
