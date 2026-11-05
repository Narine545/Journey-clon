"""Static guards for pigment redesign; does NOT compile or render GDShader."""
from pathlib import Path

source = Path('shaders/resource_slick.gdshader').read_text()
fragment = source.split('void fragment()', 1)[1]
assert 'float veins' not in fragment
assert 'inner_ribbon' not in fragment
assert 'sin(inner' not in fragment
assert 'floor(t ' not in fragment
assert 'vec2 deep = p + offset_local.xz * 1.64' in fragment
assert 'vec2 inner = p + offset_local.xz * 0.82' in fragment
assert 'float body =' in fragment and 'ALPHA = body *' in fragment
assert 'spectrum_gradient(world_xz' in fragment
assert 'inverse(mat3(MODEL_MATRIX))' in fragment
assert 'float core =' in fragment
assert source.count('{') == source.count('}')
assert source.count('(') == source.count(')')
print('OK: stripe patterns removed, two shifted layers, anchored silhouette, wave normals.')

# Supplied single-face formula must use a perturbed, orthonormal frame.
assert 'vec3 view_tangent = vec3(dot(view_world, projection_tangent)' in fragment
assert '-view_tangent.xy / max(view_tangent.z, 0.30)' in fragment
assert 'mapped_normal * dot(surface_tangent, mapped_normal)' in fragment
assert 'refract(-view_world' not in fragment
assert 'lens_gradient' in fragment

import math

def dot(a, b):
    return sum(x*y for x, y in zip(a, b))

def norm(a):
    return tuple(x/math.sqrt(dot(a, a)) for x in a)

def cross(a, b):
    return (a[1]*b[2]-a[2]*b[1], a[2]*b[0]-a[0]*b[2], a[0]*b[1]-a[1]*b[0])

def project(tilt, depth):
    n = norm((tilt, 1, 0))
    t = norm(tuple(x-n[i]*n[0] for i, x in enumerate((1, 0, 0))))
    b = norm(cross(n, t))
    v = norm((21, 26.2, 30))
    assert abs(dot(n, t)) < 1e-12 and abs(dot(n, b)) < 1e-12
    offset = (-dot(v, t)/max(dot(v, n), .30)*depth,
              -dot(v, b)/max(dot(v, n), .30)*depth)
    limiter = max(1, math.hypot(*offset)/1.25)
    return tuple((t[i]*offset[0]+b[i]*offset[1])/limiter for i in range(3))

flat = project(0, .55)
left, right = project(-.3, .55), project(.3, .55)
assert math.dist(left, right) > .15
assert project(.3, 0) == (0, 0, 0)
assert math.sqrt(dot(project(.8, 1), project(.8, 1))) <= 1.25 + 1e-10
print(f'OK: tangent-frame math; opposite lens tilts change offset by {math.dist(left, right):.3f} m.')
