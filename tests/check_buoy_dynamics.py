"""Numerical geometry/spring mirrors + integration guards, NOT a Godot run.
The actual production methods also have prepared BoatSmoke coverage.
"""
import math
import random
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
source = (ROOT / 'scripts/buoy_dynamics.gd').read_text()
ship = (ROOT / 'scripts/boat_vessel.gd').read_text()
marks = (ROOT / 'scripts/shoal_markers.gd').read_text()
main = (ROOT / 'scripts/boat_main.gd').read_text()
harbor = (ROOT / 'scripts/island_harbor.gd').read_text()
smoke = (ROOT / 'scripts/boat_smoke.gd').read_text()
assert 'const MAX_OFFSET := 1.35' in source
assert 'const SWEEP_STEP := 0.22' in source
assert 'const MAX_SWEEP_STEPS := 128' in source
assert 'absf(angle) * (half_segment + radius)' in source
assert 'restore floats touched by this rejected substep' in source
assert '_clear_of_hull(moved, float(item["radius"]), not is_trailer)' in source
assert 'previous_offset' in source and 'get_physics_interpolation_fraction()' in source
assert 'surface_height(p.x + 0.65' in source and 'surface_height(p.x, p.y + 0.65' in source
assert 'buoy_dynamics.step(delta)' in main and 'buoy_dynamics.render_nodes()' in main
assert '1.32, buoy)' in main and '0.72, buoy)' in harbor
assert 'buoy_node.rotation.z = sin' not in main and 'buoy.position.y = main.water' not in harbor
for method, end in (('_physics_process', '_separate_trailer_from'),
                    ('_make_room_for_trailer', '_reset_trail'),
                    ('_update_trailer', '_place_cable')):
    section = ship.split(f'func {method}(', 1)[1].split(f'func {end}(', 1)[0]
    assert 'buoy_dynamics.resolve_motion(' in section, method
assert 'resolved.distance_to(Vector2(boat_next.x, boat_next.z)) < TRAILER_CLEARANCE' in ship
assert 'resolved.distance_to(Vector2(global_position.x, global_position.z)) < TRAILER_CLEARANCE' in ship
assert 'Color("06f51b")' in marks and 'Color("ff1008")' in marks
assert '35.0 if _near[i] else 28.0' in marks and 'boat.has_trailer' in marks
assert 'EMISSION=COLOR.rgb*mix(0.12,5.5,flash)' in marks
assert 'mm.use_custom_data = colors' in marks and 'set_instance_custom_data' in marks
assert 'OmniLight3D.new()' not in marks and 'RigidBody3D.new()' not in source
assert 'part_pose.origin += pose.basis *' in marks
assert 'func _check_buoy_dynamics()' in smoke and '_check_buoy_dynamics()' in smoke.split('if ticks == 1:', 1)[1]


def add(a, b): return a[0]+b[0], a[1]+b[1]
def sub(a, b): return a[0]-b[0], a[1]-b[1]
def mul(a, s): return a[0]*s, a[1]*s
def dot(a, b): return a[0]*b[0]+a[1]*b[1]
def length(a): return math.hypot(*a)
def limit(a, r): return mul(a, min(1., r/max(length(a), 1e-30)))


def closest(p, at, yaw, half):
    direction = -math.sin(yaw), -math.cos(yaw)
    t = max(-half, min(half, dot(sub(p, at), direction)))
    return add(at, mul(direction, t))


def sweep(start, end, old_yaw, new_yaw, half, radius, anchors):
    """Same capsule/disc solver in open water (no terrain/other vessel)."""
    offsets = [(0., 0.) for _ in anchors]
    angle = (new_yaw-old_yaw+math.pi) % math.tau-math.pi
    motion = sub(end, start)
    steps = max(1, math.ceil((length(motion)+abs(angle)*(half+radius))/.22))
    if steps > 128:
        return start, old_yaw, offsets, True
    at, yaw, hit = start, old_yaw, False
    for _ in range(steps):
        trial, trial_yaw = add(at, mul(motion, 1/steps)), yaw+angle/steps
        saved = offsets[:]
        for _ in range(4):
            for i, anchor in enumerate(anchors):
                p = add(anchor, offsets[i])
                gap = sub(p, closest(p, trial, trial_yaw, half))
                minimum = radius+.75+.003
                gap_length = length(gap)
                if gap_length >= minimum:
                    continue
                hit = True
                normal = mul(gap, 1/gap_length) if gap_length > 1e-3 else (math.cos(trial_yaw), -math.sin(trial_yaw))
                penetration = minimum-gap_length
                proposed = limit(add(offsets[i], mul(normal, penetration)), 1.35)
                yielded = max(0., dot(sub(proposed, offsets[i]), normal))
                offsets[i] = proposed
                trial = sub(trial, mul(normal, max(0., penetration-yielded)))
        if any(length(sub(add(a, o), closest(add(a, o), trial, trial_yaw, half))) < radius+.75-.001
               for a, o in zip(anchors, offsets)):
            offsets = saved
            break
        at, yaw = trial, trial_yaw
    return at, yaw, offsets, hit


for half, radius in ((3.7, 1.7), (1.6, 1.5)):
    for sign in (-1, 1):
        at, yaw, offsets, hit = sweep((-12*sign, 0), (12*sign, 0), math.pi/2, math.pi/2, half, radius, [(0, 0)])
        assert hit and at[0]*sign < 0  # Cannot emerge on the other side.
        assert length(offsets[0]) > .1
        assert length(sub(offsets[0], closest(offsets[0], at, yaw, half))) >= radius+.75-.001
    at, yaw, offsets, hit = sweep((0, 4.2), (0, 4.2), math.pi/2, 0, half, radius, [(0, 0)])
    assert length(sub(offsets[0], closest(offsets[0], at, yaw, half))) >= radius+.75-.001

rng = random.Random(24601)
for _ in range(1000):
    half, radius = rng.choice(((3.7, 1.7), (1.6, 1.5)))
    anchors = [(0., 0.), (rng.uniform(-3, 3), rng.uniform(3, 6))]
    old_yaw = rng.uniform(-math.pi, math.pi)
    at, yaw, offsets, _hit = sweep((-13, rng.uniform(-4, 4)), (10, rng.uniform(-4, 4)),
                                 old_yaw, old_yaw+rng.uniform(-.7, .7), half, radius, anchors)
    for anchor, offset in zip(anchors, offsets):
        assert length(offset) <= 1.350001
        p = add(anchor, offset)
        assert length(sub(p, closest(p, at, yaw, half))) >= radius+.75-.001001

# Spring remains bounded, returns to its anchor without a fixed per-frame kick.
for frequency in (30, 60, 120):
    offset, velocity = (1.35, 0.), (0., 0.)
    dt = 1/frequency
    for _ in range(frequency*10):
        count = max(1, math.ceil(dt/(1/60)))
        h = dt/count
        for _ in range(count):
            velocity = add(velocity, mul(sub(mul(offset, -5), mul(velocity, 3.4)), h))
            offset = limit(add(offset, mul(velocity, h)), 1.35)
            if length(offset) >= 1.35-1e-5 and dot(velocity, offset) > 0:
                normal = mul(offset, 1/length(offset))
                velocity = sub(velocity, mul(normal, dot(velocity, normal)))
            assert length(offset) <= 1.350001
    assert length(offset) < .00001


def smooth(a, b, x):
    v = max(0., min(1., (x-a)/(b-a)))
    return v*v*(3-2*v)

samples = []
for i in range(1050):
    t = i/1000
    samples.append(max(smooth(0, .025, t)*(1-smooth(.12, .18, t)),
                       smooth(.26, .285, t)*(1-smooth(.38, .44, t))))
assert sum(a < .9 <= b for a, b in zip(samples, samples[1:])) == 2
assert max(samples) == 1 and sum(v < .01 for v in samples) > len(samples)*.6
print('OK: boat/trailer forward, reverse and yaw contact; 1000 swept multi-contact cases; '
      'bounded anchor return at 30/60/120 Hz; double flashes; production integration guards. No engine run.')
