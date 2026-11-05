"""Static configuration guards and fixed-tick/render-time reference model.
Does not run Godot or measure real frame times.
"""
from pathlib import Path
import math

assert 'common/physics_interpolation=true' in Path('project.godot').read_text()
for scene in ('boat_main', 'main'):
    assert 'physics_interpolation_mode = 2' in Path(f'scenes/{scene}.tscn').read_text()
main = Path('scripts/boat_main.gd').read_text()
vessel = Path('scripts/boat_vessel.gd').read_text()
assert 'boat.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON' in main
assert 'boat.get_global_transform_interpolated().origin' in main
assert 'camera.global_position = camera.global_position.lerp' not in main
assert 'boat.reset_physics_interpolation()' in main.split('func debug_warp_to_beacon', 1)[1]
assert '_trailer.reset_physics_interpolation()' in vessel
assert '_trailer.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON' in vessel
assert 'get_global_transform_interpolated()' in Path('scripts/resource_slick.gd').read_text()
# At 144 FPS, a raw 60 Hz position necessarily repeats; interpolation does not.
raw, interpolated = [], []
speed, tick = 12.0, 1/60
for frame in range(1, 145):
    t = frame/144
    index = math.floor(t/tick)
    fraction = t/tick-index
    raw.append(index*tick*speed)
    interpolated.append(((index-1)+fraction)*tick*speed)
assert any(abs(b-a) < 1e-10 for a,b in zip(raw, raw[1:]))
steps = [b-a for a,b in zip(interpolated, interpolated[1:])]
assert max(steps)-min(steps) < 1e-10
print('OK: interpolation scope, camera sampling, warp resets, 60/144 Hz reference.')
