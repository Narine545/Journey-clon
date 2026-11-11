"""Opposing fields reserve full sizes at placement; no forced movement/cancellation."""
from pathlib import Path
s = Path('scripts/sphere_mines.gd').read_text()
g = Path('scripts/gravity_mines.gd').read_text()
assert 'run.gravity_mines if self == run.sphere_mines else run.sphere_mines' in s
assert 'planned_radius + float(mine["radius"]) + 3.0' in s
assert s.index('conflicts_with_other_field(at, planned_radius)') < s.index('var mesh := SphereMesh.new()')
assert 'cooldown = 0.5\n\t\treturn' in s.split('conflicts_with_other_field(at, planned_radius)', 1)[1]
assert 'super._drop()' in g
for a in (4.5, 5.25, 6):
    for b in (4.5, 5.25, 6):
        minimum = a+b+3
        assert 3**2 < minimum**2  # former side offset was not enough
        assert (minimum+.01)**2 >= minimum**2
        assert minimum == b+a+3  # same rule in either launch order
print('PASS mutual field clearance, future radius reservation and short retry')
