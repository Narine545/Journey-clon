"""Stern charge integration and numerical policy mirrors, not a Godot run."""
import math
from pathlib import Path

root = Path(__file__).resolve().parents[1]
source = (root / 'scripts/raid_stern_charges.gd').read_text()
run = (root / 'scripts/raid_run.gd').read_text()
hud = (root / 'scripts/raid_hud.gd').read_text()
smoke = (root / 'scripts/boat_smoke.gd').read_text()
assert 'const CAPACITY := 12' in source
assert 'const ARM_TIME := 0.65' in source and 'const LIFETIME := 9.0' in source
assert 'charges.size() >= CAPACITY' in source
assert 'float(charge["blast"]) >= 0.0' in source
assert 'and _line_clear(at, enemy["at"])' in source
assert '_line_clear(at, enemy_at)' in source
assert 'run._hull_distance(at) < 0.8' in source
assert 'not run.navigable(at, 0.7)' in source
assert 'at.distance_squared_to(charge["at"]) < 9.0' in source
assert 'trailer.global_rotation.y' in source and 'axis * 4.5' in source
assert 'run.boat_at() - run.forward() * 6.5' in source
assert 'mesh.material = material' in source and 'MultiMesh.new()' in source
assert '"power": power(run.stern_rank)' in source  # upgrade does not mutate already-laid charges
assert 'cooldown = interval(run.stern_rank) if _try_drop() else 0.5' in source
assert 'run._near(at, reach + 4.0)' in source
assert 'enemies[enemy_index]' in source and 'float(enemy["hp"]) - float(charge["power"])' in source
assert run.count('stern_rank = 0') == 2
assert run.count('stern_charges.reset()') == 2
assert 'available.erase(8)' in run and 'stern_rank = mini(3, stern_rank + 1)' in run
physics = run.split('func _physics_process', 1)[1].split('func _move_enemies', 1)[0]
assert physics.index('_rebuild_grid()') < physics.index('stern_charges.step(delta)') < physics.index('_move_shots(delta)')
assert 'state != State.RUNNING or main.inspection_active()' in physics
assert 'stern_charges.render()' in run
assert 'run.stern_charges.cooldown' in hud
assert '_check_raid_stern()' in smoke
for forbidden in ('OmniLight3D', 'SpotLight3D', 'RigidBody3D', 'SubViewport', 'queue_free', 'hull_hp =', 'raw[', 'refined['):
    assert forbidden not in source


def power(rank):
    return 0 if rank <= 0 else 42 + (rank - 1) * 18


def radius(rank):
    return 0 if rank <= 0 else 6 + rank - 1


assert [power(r) for r in range(4)] == [0, 42, 60, 78]
assert [radius(r) for r in range(4)] == [0, 6, 7, 8]
for rank in range(1, 4):
    interval = 3.2 - (rank - 1) * 0.5
    assert interval > 0.65
    # Natural stationary lifetime plus explosion is below pool capacity at fastest cooldown.
    assert math.ceil((9 + 0.38) / interval) < 12
    for angle in range(360):
        yaw = math.radians(angle)
        forward = (-math.sin(yaw), -math.cos(yaw))
        boat = (23, -18)
        aft = tuple(boat[i] - forward[i] * 6.5 for i in range(2))
        assert math.isclose(math.dist(aft, boat), 6.5)
        trailer = tuple(boat[i] - forward[i] * 9.3 for i in range(2))
        trailer_aft = tuple(trailer[i] - forward[i] * 4.5 for i in range(2))
        assert math.isclose(math.dist(trailer_aft, trailer), 4.5)
        assert math.dist(trailer_aft, boat) > math.dist(aft, boat)

# Model a single charge: armed delay, single AoE, occlusion and immutable launch stats.
charge = {'age': 0, 'blast': -1, 'power': power(1), 'radius': radius(1)}
enemies = [{'hp': 200, 'distance': 1, 'blocked': False},
           {'hp': 200, 'distance': 3, 'blocked': True},
           {'hp': 200, 'distance': 20, 'blocked': False}]

def detonate():
    if charge['blast'] >= 0:
        return
    charge['blast'] = 0
    for enemy in enemies:
        if enemy['distance'] <= charge['radius'] + 1.1 and not enemy['blocked']:
            enemy['hp'] -= charge['power']

charge['age'] += 0.1
assert charge['age'] < 0.65 and enemies[0]['hp'] == 200
charge['age'] += 0.65
detonate()
assert [e['hp'] for e in enemies] == [158, 200, 200]
detonate()
assert [e['hp'] for e in enemies] == [158, 200, 200]
assert charge['power'] == 42 and power(3) == 78
print('PASS: stern module wiring, ranks, arming, pool bounds, occlusion, single hit and trailer offsets (not engine)')
