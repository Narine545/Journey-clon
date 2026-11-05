"""CPU mirror of night reveal math. Does not compile/render GDShader."""
import math
from pathlib import Path


def smooth(a, b, v):
    t = max(0, min(1, (v-a)/(b-a)))
    return t*t*(3-2*t)


def visible(night, angle, distance, enabled=True, reach=28):
    cone = smooth(math.cos(math.radians(30)), math.cos(math.radians(24)),
                  math.cos(math.radians(angle)))
    beam = cone*(1-smooth(reach*.78, reach, distance))*enabled
    return 1+(beam-1)*smooth(.40, .78, night)


assert visible(0, 90, 100, False) == 1
assert visible(.88, 0, 10) == 1
assert visible(.88, 45, 10) == 0
assert visible(.88, 180, 10) == 0
assert visible(.88, 0, 29) == 0
assert visible(.88, 0, 10, False) == 0
assert visible(.88, 0, 29, reach=33.6) > 0
assert 0 < visible(.60, 90, 10) < 1
assert 0 < visible(.88, 27, 10) < 1
shader = Path('shaders/resource_slick.gdshader').read_text()
assert 'surface_world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz' in shader
assert 'ALPHA = body * (0.48 + 0.30 * core + 0.10 * upper_mass) * fade * visibility;' in shader
assert 'EMISSION = pigment * body * 0.06 * fade * visibility;' in shader
print('OK: day/night, disabled light, cone, behind, range, boost, soft boundaries.')
