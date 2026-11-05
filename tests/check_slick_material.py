"""Static guards for pigment redesign; does NOT compile or render GDShader."""
from pathlib import Path

source = Path('shaders/resource_slick.gdshader').read_text()
fragment = source.split('void fragment()', 1)[1]
assert 'float veins' not in fragment
assert 'inner_ribbon' not in fragment
assert 'sin(inner' not in fragment
assert 'floor(t ' not in fragment
assert 'vec2 deep = p + offset_local.xz * 1.64' in fragment
assert 'vec2 inner = p + offset_local.xz * 0.82' in fragment
assert 'float body =' in fragment and 'ALPHA = body *' in fragment
assert 'spectrum_gradient(world_xz' in fragment
assert 'inverse(mat3(MODEL_MATRIX))' in fragment
assert 'float core =' in fragment
assert source.count('{') == source.count('}')
assert source.count('(') == source.count(')')
print('OK: stripe patterns removed, two shifted layers, anchored silhouette, wave normals.')
