"""Сфера входа отвечает воде: всплеск при пересечении поверхности и свет под водой."""
from pathlib import Path

gate = Path('scripts/raid_gate.gd').read_text()
shader = Path('shaders/orb_under_glow.gdshader').read_text()
assert 'const ORB_RADIUS := 2.1' in gate
assert 'const DIVE_DEPTH := 8.0' in gate
# Погружение перед взлётом — отдельный шаг твина, а не побочный эффект Back.
assert '3.2 - DIVE_DEPTH - ORB_RADIUS, 0.75' in gate
assert 'func _splash(' in gate
assert '_water_reaction(delta)' in gate
assert 'main.water.field.splash(at, 2.0)' in gate
assert 'var under := depth > ORB_RADIUS * 0.10' in gate
# Свет под водой светит от поверхности: иначе вода и туман его не видят.
assert '_glow_light.position = Vector3(0.0, _surface - position.y + 1.4, 0.0)' in gate
assert '_glow_mat.set_shader_parameter("ring_alpha"' in gate
assert 'uniform float glow_strength' in shader
assert 'uniform float ring_radius' in shader
