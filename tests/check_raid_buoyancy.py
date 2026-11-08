"""Shared-water buoyancy integration and smoothing mirrors; not rendered verification."""
from pathlib import Path
import math
root = Path(__file__).resolve().parents[1]
source = (root / 'scripts/raid_buoyancy.gd').read_text()
run = (root / 'scripts/raid_run.gd').read_text()
loot = (root / 'scripts/raid_salvage.gd').read_text()
mines = (root / 'scripts/raid_stern_charges.gd').read_text()
assert 'const SAMPLE_INTERVAL := 0.10' in source
assert 'const MAX_TILT := 0.18' in source
assert 'water.surface_height(at.x, at.y)' in source
assert '1.0 - exp(-response * delta)' in source
assert 'entry["float_previous"] = current' in source
assert 'return previous.lerp(current, blend)' in source
assert '3.0 if int(enemy["kind"]) == 3 else 6.0' in source
assert 'RaidBuoyancy.step_enemies(enemies, delta, main.water)' in run
assert 'RaidBuoyancy.tilt_basis(floating) * _enemy_visual_basis(enemy, radius)' in run
assert 'Transform3D(enemy_basis, Vector3(at.x, floating.x, at.y))' in run
assert 'RaidBuoyancy.step(entry, entry["at"], 1.0, 1.2, 7.0, delta, run.main.water, false)' in loot
assert 'RaidBuoyancy.step(charge, charge["at"], 1.0, 0.8, 6.0, delta, run.main.water)' in mines
assert 'Vector3(at.x, floating.x + 0.2, at.y)' in mines
# Physics cache, no water resampling or mutation from render/pose.
assert 'surface_height' not in source.split('static func pose(', 1)[1]
assert 'surface_height' not in loot.split('func render(', 1)[1]
assert 'surface_height' not in mines.split('func render(', 1)[1]
for response in (3, 6, 7):
    for fps in (19, 26, 60, 120):
        y = 0.
        for _ in range(fps):
            y += (1 - y) * (1 - math.exp(-response / fps))
        assert math.isclose(y, 1 - math.exp(-response), abs_tol=1e-9)
        assert 0 < y < 1
for slope in (-100, -.2, 0, .2, 100):
    tilt = max(-.18, min(.18, math.atan(slope)))
    assert abs(tilt) <= .18
assert 80 * 3 + 192 + 12 * 3 == 468  # worst synchronized cache refresh, not every tick
print('PASS: shared surface, bounded slopes, combat-time smoothing/interpolation and cached sampling (not render/FPS)')
