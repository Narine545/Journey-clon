"""Sparse lamp-facet regression. Numerical/static checks, NOT a Godot render."""
from pathlib import Path
import math

shader = Path('shaders/water_boat.gdshader').read_text()
light = shader.split('void light()', 1)[1]
extra = light.split('if (!LIGHT_IS_DIRECTIONAL)', 1)[1].split('if (nl > 0.0)', 1)[0]
assert 'local_glitter_mask' in extra and 'local_glitter_strength' in extra
assert 'facet_light * facet_light' in extra
assert 'radiance / (1.0 + lamp_peak * 0.1)' in extra
assert 'facet_radiance * 0.09 * sqrt(facet_incidence)' in extra
assert 'wave_relief = 0.65' not in light and 'vec3(0.12, 0.17, 0.19)' not in light
assert 'EMISSION' not in extra and 'sun_dir' not in extra
assert 'LIGHT_COLOR * ATTENUATION' in light
assert 'local_glitter_mask = glint * glit_fade * (1.0 - foam)' in shader
assert 'float glit_chance = glitter_amount * 0.28;' in shader
assert 'radiance * sparkle * local_glitter_mask' in light  # Original narrow glints preserved.


def unit(v):
    d = math.sqrt(sum(x*x for x in v))
    return tuple(x/d for x in v)


def extra_return(energy, incidence, facet, mask=1., strength=.65):
    return energy/(1+energy*.1)*.09*math.sqrt(max(incidence, 0))*\
        (.12+.88*max(facet, 0)**2)*mask*strength


# Camera-facing half-vector is deliberately absent from the extra facet lobe.
# A flat selected facet has the same response for every light heading, while
# inclined wave facets change brightness with the incident direction.
flat, tilted = [], []
normal = unit((.28, 1., -.21))
for degrees in range(360):
    yaw = math.radians(degrees)
    l = unit((math.sin(yaw)*8.3, 1.68, math.cos(yaw)*8.3))
    flat.append(extra_return(35, l[1], l[1]))
    tilted.append(extra_return(35, l[1], sum(a*b for a,b in zip(normal,l))))
assert min(flat) > 0 and max(flat)-min(flat) < 1e-12
assert max(tilted) > min(tilted)*2  # Real incident-wave relief, not a fixed bright footprint.
for energy in (0, .1, 1, 35, 100, 1e6):
    assert extra_return(energy, .5, .8, mask=0) == 0  # Most water gets NO new fill.
    assert extra_return(energy, .5, .8, strength=0) == 0
    for incidence in (0, .05, .2, .7, 1):
        for facet in (0, .2, .5, 1):
            assert 0 <= extra_return(energy, incidence, facet) <= .585 + 1e-9
assert extra_return(0, .5, 1) == 0  # Off/out of cone/out of range.
assert extra_return(35, .2, .8) > extra_return(35, .2, .1)*3
print('OK: sparse bounded facet return at 360 headings; no continuous white fill; zero between '
      'existing glitter cells / light-off; wave-normal contrast; original narrow glints preserved. No Godot run.')
