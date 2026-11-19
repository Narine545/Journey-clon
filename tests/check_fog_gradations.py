"""Туман не бывает одинаковым: полосы, высота и дыхание меняются в пространстве."""
from pathlib import Path

fog = Path('shaders/boat_rme4_fog.gdshader').read_text()

# Крупное региональное поле: полосы густого и чистого воздуха.
assert 'float region = texture(density_noise,' in fog
assert 'vec3(wp.x * 0.0041, 0.63, wp.z * 0.0041)' in fog
# Поле мировое и дрейфует медленнее облаков, а не едет за камерой.
assert '+ wind * 0.12 + vec3(0.0, TIME * 0.0016, 0.0)).r;' in fog

# Порог пятен и высота банка зависят от региона, а не одни на весь мир.
assert 'float threshold = patch_threshold + (region - 0.5) * 0.26 * profile;' in fog
assert 'float patches = smoothstep(threshold, threshold + 0.24, n);' in fog
assert '1.5 + height_noise * 2.2 + (region - 0.5) * 1.1, profile);' in fog

# Медленное дыхание: минуты, а не кадры; соседние полосы — вразнобой.
assert 'float breath = 1.0 + 0.16 * sin(TIME * 0.11 + region * 6.283);' in fog
assert '* mix(1.0, breath, profile);' in fog

# Прежний профиль остаётся ровным: все градации включены только в низком.
assert '(region - 0.5) * 0.26 * profile;' in fog
assert fog.index('float region =') < fog.index('float threshold =')
assert fog.index('float breath =') < fog.index('DENSITY = density_scale')
print('OK: туман получает градации по месту и времени.')
