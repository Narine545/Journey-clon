"""Analytical edge continuity/static CPU-GPU contract. No Godot renderer."""
from pathlib import Path


def smooth(x):
    t = max(0, min(1, x/64))
    return t*t*(3-2*t)


def edge_height(dx, dz, raw):
    return -100+(raw+100)*smooth(dx)*smooth(dz)


for raw in (-65, -6, 0, 20, 75):
    for other in (0, .5, 12, 32, 64, 400):
        assert edge_height(0, other, raw) == -100
        assert edge_height(other, 0, raw) == -100
        assert abs(edge_height(1e-4, other, raw)+100) < 1e-7
    assert edge_height(64, 64, raw) == raw
    assert abs(edge_height(64-1e-4, 64, raw)-raw) < 1e-7
coast = Path('scripts/coast.gd').read_text()
assert 'const OUTER_SEABED := -100.0' in coast
assert 'const EDGE_TRANSITION := 64.0' in coast
assert '_grid[i] = lerpf(OUTER_SEABED, height_at(x, z), edge)' in coast
assert 'return OUTER_SEABED' in coast.split('func sample_height', 1)[1]
assert 'var ex := clampi(int(floor(fx)), 0, SEGMENTS - 1)' in coast
for shader in ('water', 'water_boat'):
    source = Path(f'shaders/{shader}.gdshader').read_text()
    assert 'return -100.0;' in source and 'return -6.0;' not in source
    assert '(uv * (ground_n - 1.0) + vec2(0.5)) / ground_n' in source
# Existing protections: fog walls well outside camera footprint; world-space waves.
main = Path('scripts/boat_main.gd').read_text()
assert 'RME4_BOX_SIZE := Vector3(320.0, 60.0, 320.0)' in main
assert 'spectrum_height(wp' in Path('shaders/water_boat.gdshader').read_text()
print('OK: four height-map edges/corners, matching CPU/GPU outside depth, texel centers, existing fog/wave guards.')
