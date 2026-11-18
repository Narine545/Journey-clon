"""Климат тумана: воздух тёплый у берега и холодный над глубиной."""
from pathlib import Path

fog = Path('shaders/boat_rme4_fog.gdshader').read_text()
water = Path('shaders/water_boat.gdshader').read_text()
main = Path('scripts/boat_main.gd').read_text()

# Карта дна от Coast — та же, что у воды: шейдер знает, что под ним.
assert 'uniform sampler2D ground_tex : filter_linear, repeat_disable;' in fog
assert 'uniform vec2 ground_origin' in fog
assert 'uniform float ground_cell' in fog
assert 'uniform float ground_n' in fog
assert 'float ground_at(vec2 wp)' in fog
# За краем карты — глубина: там воздух самый холодный.
assert 'return -100.0;' in fog
assert 'vec2 sample_uv = (uv * (ground_n - 1.0) + vec2(0.5)) / ground_n;' in fog
# Та же выборка, что у воды, иначе урез и туман разойдутся.
assert 'float ground_at(vec2 wp)' in water

# Климат считается по настоящей глубине, а не по расстоянию до камеры.
assert 'uniform vec3 shore_warm' in fog and 'uniform vec3 sea_cold' in fog
assert 'float climate_strength' in fog
assert 'float shore_depth_full' in fog
assert 'float depth_here = max(0.0, -ground_at(wp.xz));' in fog
assert 'float warmth = 1.0 - smoothstep(2.0, shore_depth_full, depth_here);' in fog
# Тёплый/холодный оттенок — множитель: яркость задаёт свет, не климат.
assert 'vec3 tint = mix(sea_cold, shore_warm, warmth);' in fog
assert 'low_fog_albedo *= tint;' in fog
assert '(1.0 - 0.45 * night)' in fog
# У берега слой плотнее, но только в профиле низкого тумана.
assert 'float coastal_body = mix(0.88, 1.22, warmth * climate_strength);' in fog
assert '* mix(1.0, coastal_body, profile);' in fog
# Климат объявлен до плотности: warmth нужен и в DENSITY, и в ALBEDO.
assert fog.index('float warmth =') < fog.index('DENSITY = density_scale')

# Карта отдаётся в материал один раз, а не каждый кадр.
assert 'func _feed_fog_ground() -> void:' in main
assert 'var _fog_ground_ready := false' in main
assert 'if _fog_ground_ready or coast == null or coast.height_tex == null:' in main
assert '_rme4_material.set_shader_parameter("ground_tex", coast.height_tex)' in main
assert '_rme4_material.set_shader_parameter("ground_cell", coast.grid_cell)' in main
assert '_rme4_material.set_shader_parameter("ground_n", float(coast.grid_n))' in main
assert 'if _rme4_material != null:\n\t\t_feed_fog_ground()' in main

# Кадры сравнения: берег и открытая вода в один и тот же полдень.
shots = Path('scripts/light_shots.gd').read_text()
assert 'await _shot("light_18_day_fog_sea", 12.0, 1.0)' in shots
assert 'await _shot("light_19_day_fog_harbor", 12.0, 1.0)' in shots
