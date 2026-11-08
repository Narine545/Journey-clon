"""Controlled inertia/push arithmetic and integration guards; not engine/FPS verification."""
from pathlib import Path
import math
import random
root = Path(__file__).resolve().parents[1]
source = (root / 'scripts/raid_motion.gd').read_text()
run = (root / 'scripts/raid_run.gd').read_text()
contacts = (root / 'scripts/raid_contacts.gd').read_text()
mines = (root / 'scripts/raid_stern_charges.gd').read_text()
smoke = (root / 'scripts/boat_smoke.gd').read_text()
assert 'const PUSH_DRAG := 4.5' in source and 'const MAX_PUSH := 5.0' in source
assert 'return 1.0 / (relative * relative)' in source
assert '.limit_length(MAX_PUSH)' in source
assert 'float(enemy["hp"]) <= 0.0' in source and 'float(enemy.get("born", 0.0)) > 0.0' in source
assert 'RaidContacts.mobility(enemy) <= 0.0' in source
assert 'enemy["push_velocity"] = Vector2.ZERO' in source
assert 'if dash or bool(enemy.get("motion_dash", false)):' in source
assert 'Vector2.ZERO if dash else enemy.get("push_velocity", Vector2.ZERO)' in source
assert 'push * ((1.0 - damping) / PUSH_DRAG)' in source
assert 'velocity - normal * maxf(0.0, velocity.dot(normal))' in source
assert 'RaidContacts.safe_move(at, at + displacement' in source
assert 'RaidContacts.slide_motion(run, enemy, requested.rotated(turn))' in source
assert 'feedback(enemy, requested - (Vector2(enemy["at"]) - at))' in source
assert 'RaidMotion.move_enemies(self, delta)' in run
assert 'RaidMotion.kick(enemy, boat_at(), 4.0, pulse_radius)' in run
assert 'RaidMotion.kick(enemy, at, 5.0, reach)' in mines
assert 'RaidMotion.from_contact(enemy, at - Vector2(enemy["at"]), run.main.boat.speed)' in contacts
assert 'absf(boat_speed) <= 1.0' in source
for forbidden in ('apply_impulse', 'boat.speed =', 'boat.global_position =', 'Time.', 'RigidBody3D'):
    assert forbidden not in source
assert '_check_raid_motion()' in smoke

# Exact exponential integration, not velocity-after-step Euler drift.
for response in (3., 6.):
    expected_v = 4 * (1 - math.exp(-response))
    expected_x = 4 * (1 - (1 - math.exp(-response)) / response)
    for fps in (19, 26, 60, 120):
        velocity, x = 0., 0.
        dt = 1 / fps
        for _ in range(fps):
            decay = math.exp(-response * dt)
            x += 4 * dt + (velocity - 4) * ((1 - decay) / response)
            velocity = 4 + (velocity - 4) * decay
        assert math.isclose(velocity, expected_v, abs_tol=1e-9)
        assert math.isclose(x, expected_x, abs_tol=1e-9)
for fps in (19, 26, 60, 120):
    velocity, x = 5., 0.
    for _ in range(2 * fps):
        decay = math.exp(-4.5 / fps)
        x += velocity * (1 - decay) / 4.5
        velocity *= decay
    assert x < 5 / 4.5 and math.isclose(x, 5 * (1 - math.exp(-9)) / 4.5, abs_tol=1e-9)
    assert velocity < .001
for radius in (1.1, 1.485, 1.7, 3.4):
    inverse_mass = 1 / max(1, radius / 1.1) ** 2
    assert 0 < inverse_mass <= 1
    velocity = 0
    for _ in range(100):
        velocity = min(5, velocity + 5 * inverse_mass)
        assert velocity <= 5
# Dissipative contact feedback cannot amplify or reflect the blocked component.
rng = random.Random(67)
for _ in range(2000):
    vx, vy = rng.uniform(-5, 5), rng.uniform(-5, 5)
    angle = rng.uniform(-math.pi, math.pi)
    nx, ny = math.cos(angle), math.sin(angle)
    projection = max(0, vx * nx + vy * ny)
    ux, uy = vx - nx * projection, vy - ny * projection
    assert ux * ux + uy * uy <= vx * vx + vy * vy + 1e-9
    assert ux * nx + uy * ny <= 1e-9
print('PASS: inertia/damping integration, bounded mass-scaled pushes, dissipative collisions and attack locks (not engine)')
