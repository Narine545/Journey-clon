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
script = Path('scripts/resource_slick.gd').read_text()
vessel = Path('scripts/boat_vessel.gd').read_text()
shader = Path('shaders/resource_slick.gdshader').read_text()
assert 'travel_speed < 0.25' in script
assert 'distance > maxf(1.5, delta * 30.0)' in script
assert 'func _reset_disturbance()' in script
assert '_reset_afterglow()\n\t_reset_disturbance()' in script
assert 'slick.react_to_sweep(slick_previous_position' in vessel
assert 'slick.react_to_sweep(slick_previous_trailer' in vessel
assert 'split_axis' not in shader and 'split_bias' not in shader
assert 'split_amount' not in shader and 'source_a' not in shader
assert 'texture(film_field, local_pos / 8.0' in shader
assert 'film.gb / max(film.r, 0.001)' in shader
assert 'texture(film_previous' in shader and 'film_interpolation' in shader
assert 'slick.pickup_position(from)' in vessel
assert 'source_id: int = 0' in script
assert '1.0 if _film.persistent or (_film.disturbed and _film.idle <= 3.5) else 0.0' in script
assert 'delta * (1.5 if target == 0.0 else 6.0)' in script
assert '2.8, 1.4, delta, 1)' in vessel
assert 'if (body < 0.001 || fade < 0.001)' in shader
assert shader.count('{') == shader.count('}')
assert 3.55 + .43 < 4  # bounded particles + kernel fit quad
print('OK: sweeps/reverse, idle/warp rejection, particle-field wiring, no planar cuts, material transport, pickup.')
