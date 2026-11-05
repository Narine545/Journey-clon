"""Fog profile math/reference + static guards, not a Godot rendering test."""
import math
import random
import re
from pathlib import Path


def smooth(a, b, x):
    t = max(0., min(1., (x-a)/(b-a)))
    return t*t*(3-2*t)


def density(y, patches, height_noise, profile, night=0):
    body = ((1-profile)*.34 + profile*.14)*(1-patches)+patches
    ceiling = 10+height_noise*12
    height = smooth(0, 1.2, y)*((1-profile)*(1-smooth(7, 15, y))
                             + profile*(1-smooth(ceiling-5, ceiling, y)))
    return .045*(1+.55*profile)*body*height*(.90+.22*night)


rng = random.Random(137)
for _ in range(300):
    y, patches, noise = rng.uniform(-8, 52), rng.random(), rng.random()
    legacy = .045*(.34+(1-.34)*patches)*smooth(0, 1.2, y)*(1-smooth(7, 15, y))*.9
    assert abs(density(y, patches, noise, 0)-legacy) < 1e-12
    for night in (0, .45, .88):
        assert 0 <= density(y, patches, noise, 1, night) <= .045*1.55*1.12
    assert density(-1, patches, noise, 1) == 0
    assert density(22, patches, noise, 1) == 0
# Camera is around y=26.4, always above the 10..22 m ceiling.
assert 10+12 < 26.4

def opacity(profile, patches):
    # Fixed representative column, neutral height-noise .5, downward ray dy=.57.
    tau = sum(density((i+.5)*.01, patches, .5, profile)*.01/.57 for i in range(2300))
    return 1-math.exp(-tau)

assert opacity(1, 0) < opacity(0, 0)  # clearer gaps, not uniform whiteout
assert opacity(1, 1) > opacity(0, 1)  # denser banks
for patches, label in ((0, 'gap'), (1, 'bank')):
    print(f'Reference {label}: old opacity {opacity(0, patches):.1%}, new {opacity(1, patches):.1%}')
shader = Path('shaders/boat_rme4_fog.gdshader').read_text()
assert shader.count('texture(density_noise,') == 4
assert 'mix(1.0, 0.25, profile)' in shader
assert 'mix(1.0, 0.35, profile)' in shader
assert 'float ceiling = 10.0 + height_noise * 12.0;' in shader
code = re.sub(r'//[^\n]*', '', shader)
assert code.count('{') == code.count('}') and code.count('(') == code.count(')')
main = Path('scripts/boat_main.gd').read_text()
uniforms = set(re.findall(r'uniform\s+\w+\s+(\w+)', shader))
for name in re.findall(r'_rme4_material.set_shader_parameter\("(\w+)"', main):
    assert name in uniforms, name
assert 'debug_mystery_atmosphere := true' in main
assert 'KEY_O:' in main and 'KEY_Y:' in main
print('OK: legacy profile parity, finite density, height bounds, contrast, uniform names.')
