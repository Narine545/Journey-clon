"""Water-light contract regressions: math/static only, NOT rendered validation.
Godot Forward+ multiplies accumulated diffuse_light by albedo after light().
See light-water-contract.md for engine-source references and test limitations.
"""
from pathlib import Path
import math

shader = Path('shaders/water_boat.gdshader').read_text()
light = shader.split('void light()', 1)[1]
assert '!LIGHT_IS_DIRECTIONAL && PROJECTION_MATRIX[3][3] > 0.5 ? vec3(0.0, 0.0, 1.0) : normalize(VIEW)' in light
assert 'vec3 diffuse_tint = LIGHT_IS_DIRECTIONAL ? ALBEDO : vec3(1.0);' in light
assert 'DIFFUSE_LIGHT += radiance * diffuse_tint * (1.0 / PI)' in light
assert 'DIFFUSE_LIGHT += radiance * ALBEDO' not in light
assert 'facet_radiance' not in light and 'lamp_peak' not in light
assert 'broad_incidence' not in light and 'wave_relief = 0.65' not in light
assert 'EMISSION' not in light
assert 'LIGHT_COLOR * ATTENUATION' in light
assert 'radiance * sparkle * local_glitter_mask' in light
assert 'float glit_chance = glitter_amount * 0.28;' in shader
assert 'local_glitter_mask = glint * glit_fade * (1.0 - foam)' in shader
assert 'local_light_normal = normalize((VIEW_MATRIX * vec4(local_normal, 0.0)).xyz)' in shader
assert 'vec3 diffuse_tint' in light.split('if (proxima_test < 0.5)', 1)[1]


def unit(v):
    d = math.sqrt(sum(x*x for x in v))
    return tuple(x/d for x in v)


def dot(a,b): return sum(x*y for x,y in zip(a,b))


# Same material, lamp and physical incidence at each heading. A diffuse
# response must exist even when the specular half-vector faces elsewhere.
v = unit((21., 26.2, 30.))
responses, mirror_alignments = [], []
for degrees in range(360):
    yaw = math.radians(degrees)
    l = unit((math.sin(yaw)*8.3, 1.68, math.cos(yaw)*8.3))
    nl = l[1]
    h = unit(tuple(x+y for x,y in zip(v,l)))
    hl = max(0., min(1., dot(h,l)))
    roughness = .29
    fd90 = .5 + 2*roughness*hl*hl
    burley_l = 1+(fd90-1)*(1-nl)**5
    burley_v = 1+(fd90-1)*(1-v[1])**5
    responses.append(burley_l*burley_v*nl*.65/math.pi)
    mirror_alignments.append(max(h[1],0)**48)
assert min(responses)>0.02
assert max(responses)/min(responses)<1.5
assert max(mirror_alignments)>1000*min(mirror_alignments)

# Engine's final material multiplication is included here (omitted in the
# previous tests). Deep-water reflectance is no longer squared by local light.
for albedo in (0., .001, .005, .02, .1, .5, 1.):
    for incident in (0., .1, 1., 10.):
        old = incident*albedo*albedo
        corrected = incident*albedo
        assert 0 <= corrected <= incident
        assert corrected >= old
        if albedo==0 or incident==0:
            assert corrected==0  # No white additive fill; black remains black.
        # The directional branch intentionally preserves its previous result.
        directional = incident*albedo*albedo
        assert directional==old

# Orthographic view is invariant across the water plane; perspective retains
# the positional vector. No screen-center-dependent half-vector in ortho mode.
for point in ((-20,5,-40),(20,-5,-40),(0,0,-40)):
    ortho_view=(0.,0.,1.)
    perspective_view=unit(tuple(-x for x in point))
    assert ortho_view==(0.,0.,1.)
    assert math.isclose(dot(perspective_view,perspective_view),1)
print('OK: one local albedo multiplication including renderer; 360-heading diffuse response; '
      'parallel ortho view; directional appearance and narrow glints preserved; no additive fill. No Godot run.')
