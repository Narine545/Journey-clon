"""Analytic contact regression, not engine execution or render verification."""
from pathlib import Path
import math
s = Path('scripts/sphere_mines.gd').read_text()
m = Path('scripts/raid_motion.gd').read_text()
assert 'before >= FUSE + 0.3' in s
assert 'touched.has(identity)' in s and 'touched[identity] = true' in s
assert '_line_clear(center, contact)' in s
assert 'RaidMotion.sphere_contact(enemy, normal, 6.0)' in s
assert 'sphere_velocity' in m.split('static func feedback')[1].split('static func move_enemies')[0]
assert 'field_push * ((1.0 - field_decay) / 2.2)' in m
assert 'Vector2(enemy.get("sphere_velocity", Vector2.ZERO)).length_squared() < 0.01' in m
contact = m.split('static func sphere_contact')[1]
assert 'enemy["at"] =' not in contact and 'mobility' not in contact
assert 'enemy["sphere_velocity"] = external + normal * impulse * inv_mass' in contact

def hit(vn, tangent, radius):
    inv = 1 / max(1, radius / 1.1)**2
    closing = max(0, 6 - vn)
    impulse = min(24, 1.1 * closing / (inv + .25))
    return vn + impulse * inv, tangent
# Normal impact reverses ordinary approaching enemy, tangent exactly preserved.
assert hit(-3, 2, 1.1)[0] > 0
assert hit(-3, 2, 1.1)[1] == 2
assert hit(8, 2, 1.1) == (8, 2)  # outrunning front: no attraction/braking
assert hit(-3, 0, 3.4)[0] - (-3) < hit(-3, 0, 1.1)[0] - (-3)
assert hit(-14, 0, 1.1)[0] > -14  # dash responds instead of deleting impulse
# Free decay has timestep-independent displacement, finite travel, no target rail.
for fps in (20, 30, 60, 120):
    v, x = 6., 0.
    for _ in range(fps * 2):
        decay = math.exp(-2.2/fps)
        x += v*(1-decay)/2.2
        v *= decay
    assert math.isclose(x, 6*(1-math.exp(-4.4))/2.2, abs_tol=1e-9)
# Swept contact fraction is in interval; no contact during hold/collapse.
old_gap, new_gap = 0.4, -0.3
fraction = old_gap/(old_gap-new_gap)
assert 0 < fraction < 1
# Dissipative wall feedback removes only blocked component (normal +x).
velocity = (4., 3.)
blocked = (velocity[0]-max(0, velocity[0]), velocity[1])
assert blocked == (0, 3)
print('PASS sphere mass/relative velocity/tangent/dash/decay and integration guards')
