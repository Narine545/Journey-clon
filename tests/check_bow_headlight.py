"""Static placement and approximate flat-water beam check, not a render test."""
from pathlib import Path
import math
import re

vessel = Path('scripts/boat_vessel.gd').read_text()
match = re.search(r'_bow_spot.position = Vector3\(([-\d.]+), ([-\d.]+), ([-\d.]+)\)', vessel)
x, height, z = map(float, match.groups())
angle = float(re.search(r'_bow_spot.rotation = Vector3\(([-\d.]+),', vessel).group(1))
assert x == 0 and -6 < z < -5.7 and 1.4 < height < 2
assert -.3 < angle < -.1
# Source has forward/downward -Z axis, mounted in front of visible lens.
assert z < -5.78
flat_water_distance = height/math.tan(-angle)
assert 6 < flat_water_distance < 12
main = Path('scripts/boat_main.gd').read_text()
assert 'var debug_local_water_response := true' in main
callback = main.split('func debug_toggle_local_water_response()', 1)[1].split('func ', 1)[0]
assert 'float(' not in callback and 'get_shader_parameter' not in callback
atmosphere = main.split('func _apply_atmosphere', 1)[1].split('\nfunc ', 1)[0]
assert 'water.set_param("local_water_response", 1.0 if debug_local_water_response else 0.0)' in atmosphere
print(f'OK: safe I toggle, persistent explicit material state, bow source, beam axis reaches water ~{flat_water_distance:.1f} m ahead.')
