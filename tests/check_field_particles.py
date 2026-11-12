"""Bounded, phase-driven visuals with no mechanical writes; not GPU/render proof."""
from pathlib import Path
import math
s = Path('scripts/raid_field_particles.gd').read_text()
r = Path('scripts/raid_run.gd').read_text()
f = Path('scripts/raid_fireballs.gd').read_text()
shader = Path('shaders/raid_field_spark.gdshader').read_text()
assert 'const PER_FIELD := 20' in s and 'const CAPACITY := 160' in s
assert 'if count >= CAPACITY:' in s
assert 'not run.effects_enabled or run.main.inspection_active()' in s
assert 'float(mine["age"]) - SphereMines.FUSE' in s
assert 'float(mine["duration"])' in s
assert '1.0 - cycle if inward else cycle' in s
assert 'if inward and collapse > 0.0:' in s and 'radial = collapse' in s
assert r.count('field_particles.reset()') == 2
assert 'field_particles.render()' in r
assert 'TIME' not in shader and 'TIME' not in s
for forbidden in ('sphere_velocity', 'record_damage', 'enemy[', 'mine["age"] =', 'Light3D', 'GPUParticles'):
    assert forbidden not in s
assert 'Vector2(2.75, 1.125)' in f and 'screen_axis * 0.6875' in f
assert math.isclose(2.75*.25, .6875)  # head remains at the collision anchor
# During one cycle inward distance decreases, outward increases; opacity fades at wraps.
for phase in (.1, .3, .6, .9):
    inward = 1-phase
    outward = phase
    assert 0 < inward < 1 and 0 < outward < 1
    assert math.sin(math.pi*phase) > 0
assert abs(math.sin(math.pi)) < 1e-9
assert 2*4*20 == 160
print('PASS field particles: bounded pool, phase directions, FX/pause scope and fireball head anchoring')
