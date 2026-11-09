"""Approach patterns must never replace ordinary combat AI with a passing route."""
from pathlib import Path
plan = Path('scripts/raid_approaches.gd').read_text()
run = Path('scripts/raid_run.gd').read_text()
motion = Path('scripts/raid_motion.gd').read_text()
for key in ('approach_route', 'approach_exit', 'approach_until', 'approach_blocked', 'following_route'):
    assert key not in run and key not in motion
assert '"route":' not in plan and '"exit":' not in plan
assert 'axis.rotated(-0.5 if index % 2 == 0 else 0.5)' in plan
assert 'direction * run.rng.randf_range(0.0, 12.0)' in plan
assert 'direction.orthogonal() * run.rng.randf_range(-4.0, 4.0)' in plan
assert 'var to_boat := target - at' in motion
assert 'var direction := to_boat.normalized()' in motion
assert 'if recovering:' in motion and 'sphere_recovery' in motion
assert 'RaidApproaches.on_screen(self, at, radius)' in run
assert 'const ENEMY_CAP := 80' in run
# Five assigned slots split 3/2, not extra enemies or a complete enclosure.
flanks = [-.5 if i % 2 == 0 else .5 for i in range(5)]
assert flanks.count(-.5) == 3 and flanks.count(.5) == 2
print('PASS flank patterns preserve role AI, immediate pursuit and sphere recovery')
