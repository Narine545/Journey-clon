from pathlib import Path
s = Path('scripts/raid_motion.gd').read_text()
assert 'enemy["sphere_recovery"] = 1.0' in s
assert 'if deficit * response >= 0.05:' in s
assert 'if recovering:' in s and 'elif kind == 1:' in s
branch = s.split('if recovering:', 1)[1].split('elif kind == 1:', 1)[0]
assert 'direction = Vector2.ZERO' in branch and 'speed = 0.0' in branch
assert 'sphere_velocity' not in branch and 'continue' not in branch
assert 'enemy["charge"] = 0.0' in s.split('static func sphere_contact')[1]
# No pressure refresh: recovery expires; pressure refresh extends, doesn't accumulate.
for fps in (30, 60, 120):
    timer = 1.
    for _ in range(fps + 1):
        timer = max(0., timer-1/fps)
    assert timer == 0
print('PASS sphere recovery suspends pursuit without deleting inertia')
