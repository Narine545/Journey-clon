"""Static regression guard; no claim of visual brightness or shader compilation."""
from pathlib import Path
water = Path('shaders/water_boat.gdshader').read_text()
slick = Path('shaders/resource_slick.gdshader').read_text()
main = Path('scripts/boat_main.gd').read_text()
assert 'EMISSION = base * night_surface_fill;' in water
assert 'reveal_enabled' not in water and 'flashlight' not in water
assert 'ALPHA = clamp(min(a, obj_a), 0.0, 1.0);' in water
assert 'night_surface_fill' not in slick
assert 'fade * visibility;' in slick
assert 'water.set_param("night_surface_fill", 0.18 * water_night)' in main
assert water.count('{') == water.count('}') and water.count('(') == water.count(')')
print('OK: independent water night floor; alpha unchanged; pigment cone remains separate.')
