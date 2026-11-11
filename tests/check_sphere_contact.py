"""Compliant boundary arithmetic + integration guards; not engine proof."""
from pathlib import Path
import math
s = Path('scripts/sphere_mines.gd').read_text()
m = Path('scripts/raid_motion.gd').read_text()
assert 'FUSE + float(mine["duration"]) - 0.4' in s
assert 'touched' not in s and 'old_gap' not in s
assert 'var position:' not in s
assert '_line_clear(center, enemy_at)' in s
assert 'surface_speed, penetration, contact_delta' in s
assert 'sphere_velocity' in m.split('static func feedback')[1].split('static func move_enemies')[0]
assert 'field_push * ((1.0 - field_decay) / 2.2)' in m
contact = m.split('static func sphere_contact')[1]
assert 'enemy["at"] =' not in contact and 'mobility' not in contact
assert 'enemy["sphere_velocity"] = external + normal * deficit * response' in contact
assert 'exp(-30.0 * inverse_mass(enemy) * delta)' in contact

def hit(vn, tangent, radius, growth=15, depth=1, dt=1/60):
    inv = 1 / max(1, radius/1.1)**2
    target = min(24, max(0, growth) + max(0, depth)*10)
    return vn + max(0, target-vn)*(1-math.exp(-30*inv*dt)), tangent
assert hit(-3, 2, 1.1)[0] > 0
assert hit(-3, 2, 1.1)[1] == 2
assert hit(30, 2, 1.1) == (30, 2)
assert hit(-3, 0, 3.4)[0] < hit(-3, 0, 1.1)[0]
assert hit(-14, 0, 1.1)[0] > -14
# Repeated interior contact moves even the heavy body, no one-hit latch.
for fps in (30, 60, 120):
    for radius in (1.1, 3.4):
        v = -3.
        for _ in range(fps):
            v, _ = hit(v, 0, radius, growth=0, depth=1, dt=1/fps)
        assert v > 9
# Closed-form relaxation for a constant contact target is independent of subdivision.
for fps in (30, 60, 120):
    v = -3.
    for _ in range(fps):
        v, _ = hit(v, 0, 3.4, growth=0, depth=1, dt=1/fps)
    expected = 10 + (-3-10)*math.exp(-30*(1.1/3.4)**2)
    assert math.isclose(v, expected, abs_tol=1e-9)
print('PASS sustained sphere boundary: interior, mass, tangential velocity, dash and timing')
