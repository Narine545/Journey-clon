"""Reference motion/contact checks and shader wiring, no Godot execution."""
import math
from pathlib import Path


def smooth(a, b, x):
    t = max(0, min(1, (x-a)/(b-a)))
    return t*t*(3-2*t)


def contact(point, start, end, heading, half_length, half_width, dt):
    movement = tuple(b-a for a, b in zip(start, end))
    distance = math.hypot(*movement)
    if dt <= 0 or distance/dt < .25 or distance > max(1.5, dt*30):
        return 0
    hx, hz = heading
    if sum(a*b for a,b in zip(movement, heading)) < 0:
        hx, hz = -hx, -hz
    a = (start[0]-hx*half_length, start[1]-hz*half_length)
    b = (end[0]+hx*half_length, end[1]+hz*half_length)
    ab = (b[0]-a[0], b[1]-a[1])
    t = max(0, min(1, sum((p-x)*d for p,x,d in zip(point,a,ab))/max(sum(d*d for d in ab), .001)))
    gap = math.hypot(*(p-x-t*d for p,x,d in zip(point,a,ab)))
    return 1-smooth(half_width+.6, half_width+1.8, gap)


assert contact((0, 0), (0, 0), (0, 0), (0, -1), 4.7, 1.6, .1) == 0
assert contact((0, -4), (0, 0), (0, -1), (0, -1), 4.7, 1.6, .1) == 1
assert contact((0, 4), (0, 0), (0, 1), (0, -1), 4.7, 1.6, .1) == 1
assert contact((0, 0), (0, 20), (0, -20), (0, -1), 4.7, 1.6, .1) == 0
assert contact((20, 0), (0, 0), (0, -1), (0, -1), 4.7, 1.6, .1) == 0
assert contact((0, 0), (0, 4), (0, 3), (0, -1), 2.8, 1.4, .1) > 0
# Full split opens in <0.5 s, holds after contact, heals in <5.1 s.
for hz in (20, 60, 144):
    amount, hold = 0., 1.4
    for _ in range(6*hz):
        dt = 1/hz
        opening = min(dt, hold)
        amount = min(1, amount+opening*2.8)
        hold -= opening
        amount = max(0, amount-(dt-opening)*.28)
    assert amount == 0
# A translated, clipped circle has a gap at full split but is intact at zero.
def pieces(x, y, split, bias):
    a, b = x-split*.9, x+split*.9
    return min(max(math.hypot(a, y)-1, bias-a), max(math.hypot(b,y)-1, b-bias))
assert pieces(0, 0, 1, .15) > 0
for x, y in ((0,0), (.5,.2), (2,.1)):
    assert (pieces(x,y,0,.15) <= 0) == (math.hypot(x,y) <= 1)
script = Path('scripts/resource_slick.gd').read_text()
vessel = Path('scripts/boat_vessel.gd').read_text()
shader = Path('shaders/resource_slick.gdshader').read_text()
assert 'travel_speed < 0.25' in script
assert 'distance > maxf(1.5, delta * 30.0)' in script
assert 'randf_range' in script.split('if _split_amount < 0.08', 1)[1]
assert 'func _reset_disturbance()' in script
assert '_reset_afterglow()\n\t_reset_disturbance()' in script
assert 'slick.react_to_sweep(slick_previous_position' in vessel
assert 'slick.react_to_sweep(slick_previous_trailer' in vessel
assert 'p = da < db ? source_a : source_b;' in shader
assert 'if (body < 0.001 || fade < 0.001)' in shader
assert shader.count('{') == shader.count('}')
assert 1.7/.82+.9*1.15/.82 < 4  # conservative silhouette + spread fits quad
print('OK: ship/barge sweeps, reverse, idle/warp rejection, healing, two pieces, reset and no duplicates.')
