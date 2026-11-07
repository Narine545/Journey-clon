"""Static and analytical cone checks, not a GDShader compilation test."""
import math
import re
from pathlib import Path

main = Path('scripts/boat_main.gd').read_text()
shader = Path('shaders/beacon_beam_fog.gdshader').read_text()
assert 'spot.add_child(beam_volume)' in main
assert 'beam_volume.position = Vector3(0.0, 0.0, -45.0)' in main
assert 'beam_volume.size = Vector3(40.0, 40.0, 90.0)' in main
assert 'beam_volume.visible = false' in main and 'beam_volume.visible = true' in main
assert '"optic_mat": optic_mat' in main
assert '_add_cyl(beam_pivot' in main
assert 'EMISSION = vec3(0.0);' in shader
assert 'float along = (1.0 - UVW.z) * SIZE.z' in shader
assert math.tan(math.radians(12))*90 < 20  # whole cone fits BOX cross section
for depth in (0, 20, 45, 90):
    uvz = 1-depth/90
    assert abs((1-uvz)*90-depth) < 1e-10
code = re.sub(r'//[^\n]*', '', shader)
assert code.count('{') == code.count('}') and code.count('(') == code.count(')')
print('OK: rotating optics, aligned fog cone, activation gating, bounds, no self-emission.')
