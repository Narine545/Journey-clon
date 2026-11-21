"""Посёлок привязан к суше, а визуальные прототипы заменяемы по одному."""
from pathlib import Path

main = Path('scripts/boat_main.gd').read_text()
village = Path('scripts/island_village.gd').read_text()
cottage = Path('scripts/village_cottage.gd').read_text()
scene = Path('scenes/village/cottage.tscn').read_text()
shots = Path('scripts/light_shots.gd').read_text()
smoke = Path('scripts/boat_smoke.gd').read_text()
assert 'village.setup(self)' in main
assert village.count('"at": Vector2(') == 5
assert 'main.coast.ground_height(p.x, p.z)' in village
assert 'GroundedUnpavedLane' in village and '_road_strip(surface, LANE, 3.0)' in village
assert '@export var replacement_visual: PackedScene' in cottage
assert 'replacement_visual.instantiate()' in cottage
assert 'StaticBody3D.new()' in cottage and 'BuildingCollision' in cottage
assert 'const WIDTH := 5.8' in cottage and 'const DEPTH := 4.3' in cottage
assert 'res://scripts/village_cottage.gd' in scene
assert '_check_village()' in smoke
assert 'light_22_village_day' in shots and 'light_23_village_night' in shots
assert 'HABS MA-857' in Path('docs/world/harbor_village.md').read_text()
print('check_village: ok')
