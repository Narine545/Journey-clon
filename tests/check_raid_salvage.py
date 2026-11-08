"""Loot integration guards and policy mirrors, NOT an engine execution."""
import math
import random
import re
from pathlib import Path

root = Path(__file__).resolve().parents[1]
loot = (root / 'scripts/raid_salvage.gd').read_text()
run = (root / 'scripts/raid_run.gd').read_text()
hud = (root / 'scripts/raid_hud.gd').read_text()
smoke = (root / 'scripts/boat_smoke.gd').read_text()
assert 'const CAPACITY := 192' in loot
assert 'MultiMesh.new()' in loot
assert 'drops.size() >= CAPACITY' in loot
assert 'int(drops[nearest]["amount"]) + amount' in loot
assert 'collected += gained' in loot
assert 'clearance <= PICKUP_CLEARANCE' in loot
assert 'run._hull_distance(at)' in loot and 'run.main.boat._trailer' in loot
assert 'run.navigable(next, 0.15)' in loot and 'travel / 0.4' in loot
assert 'salvage.drop(enemies[index]["at"], RaidElites.reward(enemies[index]))' in run
assert 'return 4 if int(enemy["kind"]) == 2 else 2' in (root / "scripts/raid_elites.gd").read_text()
assert 'credit_xp(salvage.step(delta))' in run
assert 'xp += 4 if kind == 2 else 2' not in run
assert run.count('salvage.reset()') == 2  # start and leave
assert 'salvage.render(blend, elapsed)' in run
assert 'upgrade_preview(run.choices[index])' in hud
assert 'run.salvage.collected' in hud and 'run.salvage.remaining()' in hud
assert 'available.erase(4)' in run  # no wasted repair card at full health
assert 'salvage.magnet_range += 3.0' in run
assert '_check_raid_salvage()' in smoke
for token in ('refined', 'raw[', 'OmniLight3D', 'SpotLight3D', 'SubViewport', 'queue_free'):
    assert token not in loot

# The GDScript parser/linter alone did not catch the prior Node3D.basis warning.
base_properties = {'basis', 'position', 'rotation', 'rotation_degrees', 'scale',
                   'quaternion', 'transform', 'global_position', 'global_transform',
                   'global_basis', 'global_rotation', 'visible', 'name', 'owner'}
for path in root.glob('scripts/raid_*.gd'):
    declared = set(re.findall(r'\bvar\s+(\w+)', path.read_text()))
    assert not declared & base_properties, (path.name, declared & base_properties)


class LootMirror:
    def __init__(self):
        self.drops = []
        self.collected = 0

    def drop(self, at, amount):
        if amount <= 0:
            return
        nearest = min(range(len(self.drops)), key=lambda i: math.dist(at, self.drops[i][0]), default=None)
        if nearest is not None and (math.dist(at, self.drops[nearest][0]) < 2 or len(self.drops) >= 192):
            self.drops[nearest][1] += amount
        else:
            self.drops.append([at, amount])

    def collect(self, origin, radius):
        gained = sum(amount for at, amount in self.drops if math.dist(at, origin) <= radius)
        self.drops = [[at, amount] for at, amount in self.drops if math.dist(at, origin) > radius]
        self.collected += gained
        return gained

    def remaining(self):
        return sum(amount for _, amount in self.drops)


rng = random.Random(821)
world = LootMirror()
issued = 0
for step in range(5000):
    amount = rng.randint(1, 4)
    issued += amount
    world.drop(tuple(rng.uniform(-500, 500) for _ in range(2)), amount)
    if step % 7 == 0:
        world.collect(tuple(rng.uniform(-500, 500) for _ in range(2)), 15)
    assert len(world.drops) <= 192
    assert world.remaining() + world.collected == issued
remaining_before = world.remaining()
assert world.collect((0, 0), 10000) == remaining_before
assert world.remaining() == 0 and world.collected == issued
assert world.collect((0, 0), 10000) == 0  # never awards twice
world.drop((0, 0), 0)
world.drop((0, 0), -2)
assert not world.drops

# At least three useful card candidates even when weapon branches are saturated.
for pellets in (1, 5):
    for reload in (1, 0.35):
        for hp in (10, 99, 100):
            pool = [0, 1, 2, 3, 4, 5]
            if pellets >= 5:
                pool.remove(2)
            if reload <= 0.38:
                pool.remove(1)
            if hp >= 100:
                pool.remove(4)
            assert len(pool) >= 3
            assert (4 in pool) == (hp < 100)

for dt in (1/120, 1/60, 0.1, 0.5):
    travel = min(10, 18 * dt)
    steps = max(1, math.ceil(travel / 0.4))
    assert travel / steps <= 0.4 + 1e-12
    assert 10 - travel >= 0  # attraction never overshoots its chosen hull center
print('PASS: loot integration, conservation, hard cap, shadowing guard, substeps and card availability (not engine)')
