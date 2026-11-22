"""Пути привязаны к реальной суше и точкам маяков, а не к отдельным мешам."""
from pathlib import Path
from math import dist, ceil
from island_reference import distance, height, site, BEARINGS
routes = [
    [(200.3,-30),(208,-30),(205,-46),(104,-120),(24,-128),(11.4,-141.81)],
    [(200.3,-30),(208,-30),(215.87,-282.97)],
    [(200.3,-30),(208,-30),(304,-16),(384,40),(398.78,57.77)],
    [(200.3,-30),(208,-30),(205,-4),(128,88),(131.18,255.06)],
]
for bearing, route in zip(BEARINGS, routes):
    assert dist(route[-1], site(bearing)[0]) < .05
    for a, b in zip(route, route[1:]):
        steps = ceil(dist(a,b)/2)
        for i in range(steps+1):
            p = tuple(a[k]+(b[k]-a[k])*i/steps for k in range(2))
            assert distance(*p) > 5, (bearing, p)
            assert height(*p) > .6, (bearing,p,height(*p))
shader = Path('shaders/sand.gdshader').read_text()
assert 'beacon_trails(warped)' in shader
assert 'DirtLane' not in Path('scripts/island_village.gd').read_text()
architecture = Path('scripts/harbor_architecture.gd').read_text()
assert 'var stair_count := 16' in architecture and 'riser' in architecture
print('check_village_paths: ok')
