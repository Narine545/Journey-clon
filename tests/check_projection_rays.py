"""Projection-independent near/far ray math regression (no Godot required)."""
import math
from pathlib import Path


def sub(a, b):
    return tuple(x-y for x, y in zip(a, b))


def dot(a, b):
    return sum(x*y for x, y in zip(a, b))


def normalize(a):
    return tuple(x/math.sqrt(dot(a, a)) for x in a)


for orthographic in (False, True):
    rays = []
    for x, y in ((0, 0), (.8, -.5), (-.7, .4)):
        near = (x, y, -.2)
        far = (x, y, -100) if orthographic else (x*500, y*500, -100)
        ray = normalize(sub(far, near))
        rays.append(ray)
        # A point on the ray must reconstruct the same distance from near.
        scene = tuple(a+25*b for a, b in zip(near, ray))
        assert abs(dot(sub(scene, near), ray)-25) < 1e-10
    if orthographic:
        assert rays[0] == rays[1] == rays[2]
    else:
        assert rays[0] != rays[1]
shader = Path('shaders/sand_sea_sdf.gdshader').read_text()
assert 'scene_t = max(dot(dview.xyz - near_view.xyz, view_ray), 0.0)' in shader
assert 'scene_t = length(dview.xyz)' not in shader
assert '? pixel_angle :' in shader
for name in ('resource_slick', 'sand_sea_sdf', 'water_boat'):
    text = Path(f'shaders/{name}.gdshader').read_text()
    assert text.count('{') == text.count('}')
    assert text.count('(') == text.count(')')
print('OK: orthographic parallel rays, perspective rays, depth distance, static guards.')
