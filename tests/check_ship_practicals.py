"""Geometry/light wiring guards, not a renderer or gameplay execution."""
from pathlib import Path
import re

main = Path('scripts/boat_main.gd').read_text()
hud = Path('scripts/boat_hud.gd').read_text()
vessel = Path('scripts/boat_vessel.gd').read_text()
inputs = main.split('func _unhandled_input', 1)[1].split('func _process', 1)[0]
for key in 'L U O Y P K I G V J'.split():
    assert f'KEY_{key}:' not in inputs
    assert f'[{key}]' not in hud
assert 'KEY_H:' in inputs
assert 'BridgeFrontWindow%d' in vessel and 'for wi in range(3):' in vessel
assert '2.04, 2.82, 1.98, 2.12' not in vessel  # former full opaque bridge solid
assert 'bridge_glass.cull_mode = BaseMaterial3D.CULL_DISABLED' in vessel
assert 'window_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF' in vessel
for name in ('_intake_light', '_trailer_intake_light', '_cargo_light'):
    assert f'{name} = _practical_light(' in vessel
    assert f'_practical_lights.erase({name})' in vessel
assert 'lamp.shadow_enabled = false' in vessel
assert 'lamp.omni_attenuation = 2.0' in vessel
assert '"rated_energy", energy' in vessel
assert 'lamp.light_energy = float(lamp.get_meta("rated_energy"))' in vessel
assert 'boat.update_headlight_lens()' in main
assert 'if _bow_spot.visible else 0.0' in vessel
assert '"buoy_light": buoy_light' in main
assert 'buoy_light.light_color = Color("52f29c")' in main
# Front panes above lower wall and below header; no original upper opaque volume.
assert '2.04, 2.25' in vessel and '2.72, 2.82' in vessel
print('OK: retired comparison keys, front opening, paired lights, dynamic pump/cargo, lens switch, buoy color.')
