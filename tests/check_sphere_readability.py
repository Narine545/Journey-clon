"""No sphere scanlines; event wave contrast is local, bounded and finite-lived."""
from pathlib import Path
sphere = Path('shaders/sphere_mine.gdshader').read_text()
water = Path('shaders/water_boat.gdshader').read_text()
assert 'sin(' not in sphere and 'TIME' not in sphere
assert 'bands' not in sphere.replace('no animated spatial bands', '')
assert 'vec3(0.65, 0.38, 0.80), rim' in sphere
assert 'float event_foam = 0.0;' in water
assert 'event_foam = max(event_foam, crest_line * ring_contrast)' in water
assert 'clamp(rg.w * 0.55, 0.0, 0.85)' in water
assert 'smoothstep(3.5, 5.0, age)' in water
assert 'event_foam *= (1.0 - near_shore)' in water
assert 'max(max(foam, ship_wake_foam), event_foam)' in water
assert 'event_ring_height(w_pos.xz) * shore_wave_fade' in water
print('PASS smooth shell and bounded wave-crest contrast')
