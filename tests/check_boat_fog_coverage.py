"""Top-down fog coverage math/source guards; not a Godot renderer reproduction."""
from pathlib import Path
import math
root = Path(__file__).resolve().parents[1]
source = (root / 'scripts/boat_fog_coverage.gd').read_text()
main = (root / 'scripts/boat_main.gd').read_text()
trial = (root / 'scripts/sea_look_trial.gd').read_text()
assert 'project_ray_origin(pixel)' in source and 'project_ray_normal(pixel)' in source
assert '-camera.to_local(point).z' in source
assert 'DEPTH_MARGIN := 16.0' in source and 'SIDE_MARGIN := 32.0' in source
assert 'MIN_LENGTH := 80.0' in source and 'MAX_LENGTH := 640.0' in source
assert 'camera.projection != Camera3D.PROJECTION_ORTHOGONAL' in source
assert 'main.inspection_active()' in source
assert 'volumetric_fog_length = required' in source
assert 'BoatMain.RME4_BOX_SIZE.y' in source
assert main.index('BoatFogCoverage.update(self, delta)') > main.index('camera.look_at(_camera_focus, Vector3.UP)', main.index('func _process('))
assert '_mist_toggle.set_pressed_no_signal(false)' in trial and '_set_mist(false)' in trial
for bad in ('volumetric_fog_density =', 'volumetric_fog_enabled =', 'camera.size =', 'camera.global_position ='):
    assert bad not in source
# Existing viewing direction and framing guard, analytic orthographic water intersection.
length = math.sqrt(21**2 + 27**2 + 30**2)
by = 27 / length
uy = math.sqrt(1 - by * by)
for size in (16, 32, 48, 64, 72):
    half_height = size / 2
    focus_y = .8
    zoom_guard = min(32, max(0, size - 32) * .5)
    eye_distance = max(length, .2 + (2 + zoom_guard - focus_y + uy * half_height) / by)
    depths = [eye_distance + (focus_y + uy * v) / by for v in (-half_height, half_height)]
    required = min(640, max(80, math.ceil((max(depths) + 16) / 8) * 8))
    assert required >= max(depths) + 16 - 1e-9
    if size == 72:
        assert max(depths) > 80  # former fixed limit cuts visible water
    if size == 32:
        assert max(depths) < 80
# Box padding is beyond the shader's 18 m horizontal edge fade.
for extent in (30, 100, 150, 250):
    half_box = max(320, 2 * (extent + 32)) / 2
    assert half_box - extent >= 32 > 18
print('PASS: fixed-80m regression, zoom-aware corner coverage, box fade padding and old-mist default (not GPU)')
