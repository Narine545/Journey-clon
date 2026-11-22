"""План посёлка: чистые проходы, отдельные жители и открытый съезд."""
from pathlib import Path
import re

village = Path('scripts/island_village.gd').read_text()
house = Path('scripts/village_house.gd').read_text()
props = Path('scripts/village_props.gd').read_text()
people = Path('scripts/village_people.gd').read_text()
interaction = Path('scripts/village_interaction.gd').read_text()
shots = Path('scripts/light_shots.gd').read_text()
smoke = Path('scripts/boat_smoke.gd').read_text()

assert 'village.setup(self)' in Path('scripts/boat_main.gd').read_text()
assert 'VillageBase' in village and 'VillageStreets' in village and 'DirtLane' in village
assert 'PierBridge' in village and 'props.quay()' in village
assert 'RAMP_WELL' in props and '_deck_quad' in props
assert 'portal_bulb' not in props and 'portal_x' not in props
assert '_build_chapel()' not in village and '_build_shrine()' not in village
assert 'GiltShapes.pointed_arch' not in house and 'GiltShapes.spire' not in house
assert '_match_feature(' not in house and '_yard(' not in house
assert '_simple_window(' in house
assert not Path('scripts/village_portrait.gd').exists()
assert not Path('scripts/village_chapel.gd').exists()
assert not Path('scripts/village_shrine.gd').exists()
assert 'VillagePortrait' not in interaction and 'TideKit.panel(' in interaction
assert 'TideKit.button(' in interaction and 'main.harbor.moored' in interaction
assert '@export var replacement_visual: PackedScene' in house
assert 'func ray_distance(' in house and 'BuildingCollision' in house
assert 'func line_for(' in people and 'func _on_talk(' in interaction
assert '_check_village()' in smoke
for shot in ('light_22_village_day', 'light_23_village_night', 'light_24_village_street',
             'light_25_village_dusk', 'light_26_village_entry', 'light_27_village_lane',
             'light_29_village_dialog'):
    assert shot in shots, shot

# Габарит включает свес крыши 0.46 м с каждой стороны. Все восемь домов
# повёрнуты на 90°, поэтому ширина фасада расположена вдоль Z.
plans = {name: (float(w), float(d)) for name, w, d in re.findall(
    r'"(\w+)": \{\s*"sign": [^\n]*?"width": ([\d.]+), "depth": ([\d.]+)', house)}
sites = re.findall(r'"at": Vector2\(([\d.]+),\s*([-\d.]+)\), "yaw": ([^,]+),\s*\n\s*"plan": "(\w+)"', village)
assert len(sites) == 8
for i, (x, z, yaw, name) in enumerate(sites):
    assert 'PI * 0.5' in yaw
    w, d = plans[name]
    for X, Z, _, other in sites[i + 1:]:
        W, D = plans[other]
        clearance_x = abs(float(x) - float(X)) - (d + D) / 2 - 0.92
        clearance_z = abs(float(z) - float(Z)) - (w + W) / 2 - 0.92
        assert max(clearance_x, clearance_z) >= 0.4, (name, other)
    assert f'"resident": ' in village
# Проём съезда свободен не только от корпусов, но и от свесов крыш.
for x, z, _, name in sites:
    w, d = plans[name]
    box = (float(x) - d/2 - .46, float(x) + d/2 + .46,
           float(z) - w/2 - .46, float(z) + w/2 + .46)
    intersects_entry = box[0] < 169.65 and box[1] > 159.8 and box[2] < -28.25 and box[3] > -31.75
    assert not intersects_entry, (name, box)
print('check_village: ok')
