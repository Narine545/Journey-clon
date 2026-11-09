"""World-space crossing exit and obstruction fallback arithmetic, not engine proof."""
from pathlib import Path
plan = Path('scripts/raid_approaches.gd').read_text()
run = Path('scripts/raid_run.gd').read_text()
motion = Path('scripts/raid_motion.gd').read_text()
assert '"exit": at - axis * (2.0 * (extent + 22.0))' in plan
assert '"approach_exit": slot["exit"]' in run
assert 'at.distance_to(slot["exit"]) / 2.8 + 12.0' in run
assert '(at - exit_at).dot(route) >= 0.0' in motion
assert 'blocked >= 2.0' in motion
assert 'progress < speed * delta * 0.15' in motion
assert 'var following_route := false' in motion
assert 'if not recovering and kind == 0' in motion
# Axis +x, path from +extent to -extent; shifted lanes keep the same exit plane.
for extent in (40., 65., 110.):
    start = extent + 22
    end = start - 2*(extent+22)
    assert end < -extent
    for at in (start, 0, end+0.1):
        assert (at-end)*(-1) < 0
    assert (end-end)*(-1) >= 0
    timeout = min(100, abs(start-end)/2.8+12)
    assert timeout > abs(start-end)/2.8
# Only sustained obstruction expires the route; real forward progress clears the counter.
for fps in (30, 60, 120):
    blocked = 0
    for _ in range(2*fps+1):
        blocked += 1/fps
    assert blocked >= 2
    blocked = 0 if .1 >= 2.8/fps*.15 else blocked
    assert blocked == 0
print('PASS fixed exit plane, size-aware timeout and sustained obstruction release')
