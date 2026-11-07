"""CPU mirror of charge/hold/fade; run without Godot, no render assertion."""
from pathlib import Path


def update(charge, hold, dt, exposure=0, night=.88):
    if night <= .55:
        return 1., 5.
    if exposure > .05:
        return min(1, charge+dt*2*exposure), 5.
    fade_dt = max(0, dt-hold)
    return max(0, charge-fade_dt/6), max(0, hold-dt)


assert update(0, 0, .5, 1) == (1, 5)
assert update(0, 0, .1, 1)[0] == .2
assert update(0, 0, 1) == (0, 0)
assert update(1, 5, 5) == (1, 0)
assert update(1, 5, 8) == (.5, 0)
assert update(1, 5, 11) == (0, 0)
assert update(.2, 0, .2, 1) == (.6000000000000001, 5)
assert update(0, 0, 1, night=.45) == (1, 5)
for hz in (20, 30, 60, 144):
    c, h = 1., 5.
    for _ in range(8*hz):
        c, h = update(c, h, 1/hz)
    assert abs(c-.5) < 1e-10
source = Path('scripts/resource_slick.gd').read_text()
assert 'func _beam_exposure()' in source
assert 'func relocate_smoothly(new_pos: Vector3) -> void:\n\t_reset_afterglow()' in source
assert 'depleted = true\n\tremaining_mass = 0.0\n\t_reset_afterglow()' in source
shader = Path('shaders/resource_slick.gdshader').read_text()
assert 'max(flashlight, afterglow * 0.85)' in shader
print('OK: charge, daylight/evening, hold, fade, refresh, frame-rate independence, resets.')
