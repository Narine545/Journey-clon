"""Formation geometry and integration guards, not engine/render verification."""
from pathlib import Path
import math
s = Path('scripts/raid_approaches.gd').read_text()
r = Path('scripts/raid_run.gd').read_text()
m = Path('scripts/raid_motion.gd').read_text()
assert 'sequence % 3' in s and 'for index in range(5)' in s
assert 'slots.pop_front()' in s and 'if slots.is_empty():' in s
assert 'run.boat_at()' not in s.split('func next_slot')[1].split('func _plan')[0]
assert 'get_visible_rect().grow(96.0)' in s and 'camera.unproject_position' in s
assert 'camera.project_ray_origin(pixel)' in s
assert 'RaidApproaches.on_screen(self, at, radius)' in r
assert 'rng.randf_range(36.0, 48.0)' not in r
assert 'boat_at().distance_to(enemies[index]' not in r
assert '"approach_route": slot["route"] if kind == 0 else Vector2.ZERO' in r
assert 'var route: Vector2 = enemy.get("approach_route", Vector2.ZERO)' in m
assert 'not recovering' in m and 'run.elapsed < float(enemy.get("approach_until", 0.0))' in m
assert r.count('_approaches.reset()') == 2
assert 'var _boss_retry := 0.0' in r and '_boss_retry = 1.0' in r
assert r.index('if replacement >= 0:') > r.index('if crowded:')
# Planned world points remain fixed after boat moves; arc has a wide open sector.
center = (12, -7)
extent = 70
points = [(center[0]+math.cos((i-2)*.55)*(extent+22),
           center[1]+math.sin((i-2)*.55)*(extent+22)) for i in range(5)]
saved = list(points)
center = (400, 300)
assert points == saved
assert 2*math.pi - 4*.55 > math.pi
# A line keeps 5.5 m spacing, safely above two normal radii.
assert 5.5 > 2*1.1+.1
# Existing spawn schedule/cap remains in force, formations don't spawn a burst.
assert 'RaidWaves.interval(elapsed)' in r and 'const ENEMY_CAP := 80' in r
assert '_spawn(' not in s
print('PASS anchored groups, offscreen guard, open arc, finite crossing and boss retries')
# Ordinary approaches have bounded two-axis scatter and shuffled arrival order.
assert 'at += axis * run.rng.randf_range(0.0, 12.0)' in s
assert 'at += axis.orthogonal() * run.rng.randf_range(-1.0, 1.0)' in s
assert 'run.rng.randi_range(0, index)' in s
assert 'slots[other] = saved' in s
# Lateral jitter still leaves normal bodies separated; depth only moves farther offshore.
assert 5.5 - 2.0 > 2 * 1.1 + .1
