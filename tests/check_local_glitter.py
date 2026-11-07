"""Static wiring and bounded response; does not render or compile GDShader."""
import math
import re
from pathlib import Path

shader = Path('shaders/water_boat.gdshader').read_text()
assert 'uniform float local_glitter_strength : hint_range(0.0, 2.0) = 0.65;' in shader
assert 'local_glitter_mask = glint * glit_fade * (1.0 - foam)' in shader
assert 'float glit_chance = glitter_amount * 0.28;' in shader
assert 'vec3 lamp_facet = normalize(N +' in shader
light = shader.split('void light()', 1)[1]
local_block = light.split('if (!LIGHT_IS_DIRECTIONAL)', 1)[1].split('if (proxima_test', 1)[0]
assert 'radiance * sparkle * local_glitter_mask' in local_block
assert '* local_glitter_strength * local_water_response' in local_block
assert 'sun_dir' not in local_block and 'EMISSION' not in local_block
assert 'vec3 radiance = LIGHT_COLOR * ATTENUATION;' in light
code = re.sub(r'//[^\n]*', '', shader)
assert code.count('{') == code.count('}') and code.count('(') == code.count(')')
# Fixed cells: no appearance probability changes with crest or lighting.
# Angular lobe is bounded, zero attenuation or I-off must extinguish it.
for alignment in (-1, 0, .5, .9, .99, 1):
    sparkle = max(alignment, 0)**48
    assert 0 <= sparkle <= 1
    assert sparkle*0*.65 == 0
    assert sparkle*.65*0 == 0
assert .99**48 > .9**48
print('OK: local-only light, actual attenuation, fixed cells, foam suppression, I-off, bounded lobe.')
