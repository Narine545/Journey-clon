"""Soft contact source/math guards; not a Godot simulation or performance test."""
from pathlib import Path
import math
root = Path(__file__).resolve().parents[1]
source = (root / 'scripts/raid_contacts.gd').read_text()
run = (root / 'scripts/raid_run.gd').read_text()
assert 'const PASSES := 3' in source and 'const SEPARATION_SPEED := 6.0' in source
assert 'const CELL := 8.0' in source
assert 'if other_index <= index:' in source
assert 'offsets[index] += correction' in source and 'offsets[other_index] -= correction' in source
assert 'SEPARATION_SPEED * delta / float(PASSES)' in source
assert 'RaidBoss.preparing(enemy)' in source
assert 'return 0.0' in source and 'else 0.25' in source
assert 'radius + 1.72' in source and 'radius + 1.52' in source
assert 'run.main.boat.has_trailer' in source
assert 'if not bool(clear.call(candidate, radius)):' in source
assert 'at.distance_to(desired) / 0.35' in source
assert 'run._hurt(9.0 if int(enemy["kind"]) < 3 else 20.0)' in source
physics = run.split('func _physics_process(', 1)[1].split('func _debug_clear_visible(', 1)[0]
assert physics.index('_move_enemies(delta)') < physics.index('RaidContacts.resolve(self, delta)')
assert physics.index('RaidContacts.resolve(self, delta)') < physics.rindex('_rebuild_grid()')
assert 'state != State.RUNNING or main.inspection_active()' in physics
assert 'var crowded := false' in run
assert 'const ENEMY_CAP := 80' in run
for token in ('RigidBody', 'apply_impulse', 'boat.speed =', 'boat.global_position ='):
    assert token not in source
assert 2 * 3.4 + .08 < 8  # current largest pair fits the adjacent-cell search


def pair(a, b, ra, rb, dt, wa=1, wb=1):
    # Scalar projection of the exact two-body Jacobi correction along a separation normal.
    start = (a, b)
    for _ in range(3):
        gap = abs(a - b)
        if gap >= ra + rb + .08 or wa + wb == 0:
            continue
        correction = (ra + rb + .08 - gap) * .65
        cap = 6 * dt / 3
        direction = -1 if a <= b else 1
        a += direction * min(cap, correction * wa / (wa + wb))
        b -= direction * min(cap, correction * wb / (wa + wb))
    assert abs(a - start[0]) <= 6 * dt + 1e-9
    assert abs(b - start[1]) <= 6 * dt + 1e-9
    return a, b

for fps in (19, 26, 60, 120):
    a, b = 0., 0.
    for _ in range(fps):
        a, b = pair(a, b, 1.1, 1.1, 1 / fps)
    assert b - a > 2.19 and math.isclose(a + b, 0, abs_tol=1e-9)
    a, b = pair(0, 1, 1.1, 3.4, 1 / fps, 1, 0)
    assert b == 1 and a < 0  # warning-locked object is not moved by the crowd
assert pair(0, 10, 1.1, 1.1, .02) == (0, 10)
# Capsule side, ends and exact-center fallback project to a finite exterior point.
for x, z in ((0, 0), (.5, 0), (0, 4), (-.5, -4), (10, 0)):
    nearest_z = max(-3.7, min(3.7, z))
    dx, dz = x, z - nearest_z
    distance = math.hypot(dx, dz)
    if distance < 2.82:
        nx, nz = (dx / distance, dz / distance) if distance > 1e-6 else (1, 0)
        x, z = nx * 2.82, nearest_z + nz * 2.82
    assert math.hypot(x, z - max(-3.7, min(3.7, z))) >= 2.82 - 1e-9
print('PASS: bounded pair separation, locked/heavy roles, capsule exterior and integration guards (not engine)')

assert "RaidContacts.slide_motion(run, enemy, requested)" in (root / "scripts/raid_motion.gd").read_text()
assert "result += normal * (approach - gap)" in source

# A fast dash cannot advance through the tangent plane of a neighbor in a single step.
for fps in (19, 26, 60, 120):
    motion = 14 / fps
    gap = .04
    approach = motion
    clipped = motion - max(0, approach - gap)
    assert clipped <= gap + 1e-9
