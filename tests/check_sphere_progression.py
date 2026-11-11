"""Sphere card is a bounded ordinary upgrade, separate from explosions and debug."""
from pathlib import Path
r = Path('scripts/raid_run.gd').read_text()
s = Path('scripts/sphere_mines.gd').read_text()
h = Path('scripts/raid_hud.gd').read_text()
assert '["Сферические мины"' in r
assert 'if sphere_rank < 3:' in r and 'available.append(14)' in r
assert 'sphere_rank = mini(3, sphere_rank + 1)' in r
assert r.count('sphere_rank = 0') == 2
assert 'if choices[index] >= 10 and choices[index] <= 13:' in r
assert '(enabled or weapon_rank() > 0)' in s
assert '(CAPACITY if enabled else 1)' in s
assert 'INTERVAL if enabled else release_interval()' in s
assert '"radius": radius(maxi(1, weapon_rank()))' in s
assert 'float(mine["radius"])' in s  # laid mine keeps the radius it was created with
assert 'run.stern_rank' not in s and 'record_damage' not in s
assert s.count('stats.debug_used = true') == 1
assert 'СФЕРА %d/3' in h and 'Сферические мины %d/3' in h
for rank in (1, 2, 3):
    radius = 4.5+.75*(rank-1)
    interval = 8-(rank-1)
    assert radius in (4.5, 5.25, 6)
    assert interval in (8, 7, 6)
    assert interval > .85+5.0  # no continuous field even at highest rank
print('PASS sphere card: ranks/reset, radius snapshot, one emitter and no evolution/debug leakage')
