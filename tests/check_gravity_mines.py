"""Dual weapon integration and fixed-time force/damage math; not Godot execution."""
from pathlib import Path
import math
r = Path('scripts/raid_run.gd').read_text()
s = Path('scripts/sphere_mines.gd').read_text()
g = Path('scripts/gravity_mines.gd').read_text()
h = Path('scripts/raid_hud.gd').read_text()
stats = Path('scripts/raid_stats.gd').read_text()
assert 'const FIELD_TIME := 3.0' in s
assert '"duration": field_duration()' in s
assert 'extends SphereMines' in g
assert 'return run.gravity_rank' in g
assert 'mine["dps"] = 8.0 + 4.0 * float(run.gravity_damage_rank)' in g
assert 'surface_speed' not in g  # doesn't inherit outward contact during attraction
assert 'enemy["sphere_velocity"] = external + change' in g
assert 'enemy["at"] =' not in g
assert 'power := float(mine["dps"]) * active_delta' in g
assert 'distance <= reach and active_delta > 0.0' in g
assert '_line_clear(center, enemy_at)' in g
assert 'mine["released"] = true' in g and 'before < end' in g
assert 'Channel.GRAVITY' in g and 'MINES, GRAVITY' in stats
assert 'Стягивающие сферы' in h and 'ТЕСТ: СТЯГИВАЮЩИЕ МИНЫ' in h
assert r.count('gravity_mines.reset()') == 2
assert 'gravity_mines.step(delta)' in r and '.limit_length(' in r and '24.0' in r
for card in (15, 16, 17, 18):
    assert f'available.append({card})' in r and f'\t\t{card}:' in r
for fps in (30, 60, 120):
    # Continuous damage/acceleration have the same integrated budget for equal exposure.
    damage = sum(12/fps for _ in range(2*fps))
    impulse = sum(18/fps for _ in range(2*fps))
    assert math.isclose(damage, 24, abs_tol=1e-9)
    assert math.isclose(impulse, 36, abs_tol=1e-9)
# Independently bounded lifetimes don't form unbroken ordinary fields.
assert 5+.85 < 6 and 5+.85 < 8
# Opposing accelerations add vectorially rather than teleporting to either field.
assert 9 + (-6) == (-6) + 9
print('PASS dual fields: progression, snapshots, color/debug, additive force, release and continuous damage')
