"""Static diagnostic wiring guards. Does not execute the renderer."""
from pathlib import Path
import re

main = Path('scripts/boat_main.gd').read_text()
shader = Path('shaders/boat_rme4_fog.gdshader').read_text()
assert 'debug_fog_diagnostic := 0' in main
assert '(debug_fog_diagnostic + 1) % 3' in main
assert 'KEY_U:' in main
assert 'world._env.volumetric_fog_density = 0.06 if global_test else 0.0' in main
assert '_rme4_volume.visible = not global_test' in main
assert 'world._env.volumetric_fog_enabled = _fog_diagnostic_saved_enabled' in main
assert 'world._env.volumetric_fog_emission = _fog_diagnostic_saved_emission' in main
assert 'world._env.volumetric_fog_emission_energy = _fog_diagnostic_saved_emission_energy' in main
assert 'if debug_fog_diagnostic != 0:\n\t\t_apply_fog_diagnostic()' in main
assert 'uniform bool diagnostic_volume = false;' in shader
assert 'EMISSION = vec3(0.05, 0.65, 0.75);' in shader
assert 'DENSITY = 0.08 * smoothstep(0.0, 2.0, -SDF);' in shader
code = re.sub(r'//[^\n]*', '', shader)
assert code.count('{') == code.count('}') and code.count('(') == code.count(')')
print('OK: global/volume isolation, persistent overrides, safe restore, shader bypass.')
