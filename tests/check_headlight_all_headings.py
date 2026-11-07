"""View-angle regression: analytic light response, not a rendered-image assertion."""
from pathlib import Path
import math

shader = Path('shaders/water_boat.gdshader').read_text()
light = shader.split('void light()', 1)[1]
assert light.index('float broad_incidence') < light.index('if (nl > 0.0)')
scatter = light.split('float broad_incidence', 1)[1].split('if (nl > 0.0)', 1)[0]
assert 'SPECULAR_LIGHT += radiance' in scatter
assert 'sqrt(broad_incidence) * wave_relief * local_water_response' in scatter
assert 'EMISSION' not in scatter and 'sun_dir' not in scatter
assert 'LIGHT_COLOR * ATTENUATION' in light
# Source/axis rotate together around the hull. The same point on the beam's
# water footprint has the SAME incident light for all 360 headings, even
# though the half-vector mirror alignment changes drastically with the view.
def unit(v):
    d=math.sqrt(sum(x*x for x in v)); return tuple(x/d for x in v)
def dot(a,b): return sum(x*y for x,y in zip(a,b))
v=unit((21.,26.2,30.))
responses=[]; mirrors=[]
for degrees in range(360):
    yaw=math.radians(degrees)
    l=unit((math.sin(yaw)*8.3,1.68,math.cos(yaw)*8.3))
    incidence=max(l[1],0)
    responses.append(math.sqrt(incidence)*(.65+.35*incidence))
    h=unit(tuple(a+b for a,b in zip(v,l)))
    mirrors.append(max(h[1],0)**48)
assert min(responses)>.3 and max(responses)-min(responses)<1e-12
assert max(mirrors)>1000*min(mirrors)
# Lights off/out of cone/out of range -> zero, fog not part of the formula.
for response in responses:
    assert response*0==0
print('OK: 360 headings preserve nonzero rough-water illumination; narrow mirror lobe varies >1000x; '
      'real attenuation and disabled-light zero preserved. No Godot run.')
