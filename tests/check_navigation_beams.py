"""Static controls and flat-sea lighthouse geometry. No render/FPS assertion."""
import math
from pathlib import Path

main = Path('scripts/boat_main.gd').read_text()
vessel = Path('scripts/boat_vessel.gd').read_text()
assert 'nav_mat := _material(nav_col, 0.1, 0.65, 0.24)' in vessel
assert 'nav_col, 0.10, 1.1, nav_mat' in vessel
assert 'spot.spot_range = 90.0' in main
assert 'spot.spot_angle = 12.0' in main
assert 'spot_l.light_energy = 18.0' in main
assert 'beam_pivot.rotation.y = atan2(-outward.x, -outward.y)' in main
# All headlands start facing seaward, rather than assuming the sea lies west.
for nx, nz in ((1, 0), (0, -1), (-1, 0), (0, 1)):
    yaw = math.atan2(-nx, -nz)
    assert math.isclose(-math.sin(yaw), nx, abs_tol=1e-9)
    assert math.isclose(-math.cos(yaw), nz, abs_tol=1e-9)
assert 'spot.position = Vector3(0.0, 0.0, -1.3)' in main
assert 'spot.rotation = Vector3(-atan2(tower_pos.y + 10.3, 32.0), 0.0, 0.0)' in main
assert 'delta * TAU / 18.0' in main
assert 'buoy_signal.light_energy = 0.35 * pulse' in main
assert 'buoy_lens.emission_energy_multiplier = 1.4 * pulse' in main
height = 1.2+10.3
old_horizontal = height/math.tan(.22)
old_slant = math.hypot(height, old_horizontal)
new_slant = math.hypot(height, 32)
assert new_slant/90 < .4 < old_slant/58
# Tower is 10 m inland; source 1.3 m seaward and axis extends another 32 m.
assert 10-1.3-32 < 0
assert 0 < math.atan2(height, 32) < math.pi/4
phase = 0.
for _ in range(18*60):
    phase = (phase+(1/60)*math.tau/18)%math.tau
assert abs(math.sin(phase)) < 1e-10
print(f'OK: reduced steady sidelights; beacon axis range ratio {old_slant/58:.2f} -> {new_slant/90:.2f}; 18s rotation; synced buoy pulse.')
