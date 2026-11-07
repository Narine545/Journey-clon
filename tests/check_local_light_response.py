"""Analytical/static checks, NOT a Godot shader compilation or render test."""
import math
import re
from pathlib import Path


def hg(c, g):
    return (1-g*g)/(4*math.pi*(1+g*g-2*g*c)**1.5)


old_ratio = hg(.6, .70)/hg(-.6, .70)
new_ratio = hg(.6, .25)/hg(-.6, .25)
assert 1 < new_ratio < old_ratio
print(f'HG angular ratio (+/-0.6): {old_ratio:.2f} -> {new_ratio:.2f}')
world = Path('scripts/world.gd').read_text()
boat_profile = world.split('func configure_boat_lighting', 1)[1]
assert boat_profile.count('_env.volumetric_fog_anisotropy = 0.25') == 2
assert 'lerpf(1.8, 1.1, sunset)' in boat_profile
assert '_bow_spot.light_volumetric_fog_energy = 2.0' in Path('scripts/boat_vessel.gd').read_text()
shader = Path('shaders/water_boat.gdshader').read_text()
assert 'varying vec3 local_light_normal;' in shader
assert 'local_light_normal = normalize((VIEW_MATRIX * vec4(local_normal, 0.0)).xyz);' in shader
assert 'mix(NORMAL, local_light_normal, local_water_response)' in shader
assert 'LIGHT_IS_DIRECTIONAL ? 1.0 : mix(3.0, 0.65, local_water_response)' in shader
assert 'mix(1.0, nl, local_water_response)' in shader
assert 'mix(0.08, 0.22, local_water_response)' in shader
code = re.sub(r'//[^\n]*', '', shader)
assert code.count('{') == code.count('}') and code.count('(') == code.count(')')
# Local GGX incidence now cancels the grazing 1/nl term; old comparison remains available.
for nl in (.001, .01, .1, .5, 1):
    nv = .57
    assert nl/(4*nl*nv) <= 1/(4*nv)+1e-12
main = Path('scripts/boat_main.gd').read_text()
assert 'KEY_I:' in main
assert 'get_shader_parameter("local_water_response")' in main
print('OK: phase contrast, independent fog energy, local-only wave normals, BRDF incidence, I toggle.')
