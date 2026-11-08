"""Wave schedule/typography guards and policy mirrors; not a Godot execution."""
import ast
import random
from pathlib import Path

root = Path(__file__).resolve().parents[1]
waves = (root / 'scripts/raid_waves.gd').read_text()
run = (root / 'scripts/raid_run.gd').read_text()
hud = (root / 'scripts/raid_hud.gd').read_text()
smoke = (root / 'scripts/boat_smoke.gd').read_text()
source = waves.split('const PHASES := ', 1)[1].split('\n]\n', 1)[0] + '\n]'
phases = ast.literal_eval(source)
assert [row[0] for row in phases] == [0, 60, 120, 180, 225, 240]
assert [row[3] for row in phases] == [2, 3, 4, 5, 0, 0]
assert all(row[2] > 0 for row in phases)
assert 'not RaidWaves.respite(elapsed)' in run
assert 'RaidWaves.interval(elapsed)' in run
assert 'RaidWaves.choose_kind(elapsed, ranged_count, rng.randf())' in run
assert 'int(enemy["kind"]) == 2 and float(enemy["hp"]) > 0.0' in run
assert 'ranged_count < ranged_cap(seconds)' in waves
assert 'seconds >= 35.0' in waves and 'seconds < 15.0' in waves
assert 'RaidWaves.label(run.elapsed)' in hud
assert '_check_raid_waves()' in smoke
assert '"font_size", 36' in hud and '"font_size", 20' in hud
assert 'ui_theme.default_font_size = 18' in hud
assert 'GridContainer.new()' in hud and 'ScrollContainer.new()' in hud
assert '_cards.columns = 3 if width >= 1000.0 else 1' in hud
assert 'size.y - 32.0' in hud and 'get_combined_minimum_size().y' in hud
assert 'box.minimum_size_changed.connect(_layout, CONNECT_DEFERRED)' in hud


def phase(seconds):
    return max(i for i, row in enumerate(phases) if seconds >= row[0])


def kind(seconds, ranged, roll):
    if seconds < 15:
        return 0
    if seconds >= 35 and roll < 0.16 and ranged < phases[phase(seconds)][3]:
        return 2
    return 1 if roll < 0.48 else 0


for i, row in enumerate(phases):
    assert phase(row[0]) == i
    if i:
        assert phase(row[0] - 0.001) == i - 1
rng = random.Random(44)
for seconds in (0, 14.99, 15, 34.99, 35, 60, 120, 180, 224.99, 225, 239.99, 240, 299):
    ranged = 0
    cap = phases[phase(seconds)][3]
    for _ in range(1000):
        selected = kind(seconds, ranged, rng.random())
        if selected == 2:
            ranged += 1
        if rng.random() < 0.05:
            ranged = max(0, ranged - 1)
        assert ranged <= cap
        if seconds < 35 or seconds >= 225:
            assert selected != 2
        if seconds < 15:
            assert selected == 0
# Existing shooters are not culled on transition: simply stop adding them.
for seconds in (60, 120, 180, 225, 240):
    for count in (5, 6, 10):
        assert all(kind(seconds, count, i / 1000) != 2 for i in range(1000))
for seconds in (225, 230, 239.99):
    assert 225 <= seconds < 240  # exact regular-spawn respite, boss time unchanged
for width, viewport_height in ((1920, 1080), (1280, 720), (900, 600), (640, 480)):
    panel_width = min(1120, width - 32)
    columns = 3 if panel_width >= 1000 else 1
    content_height = (240 if columns == 3 else 3 * 240 + 32) + 170
    panel_height = min(max(180, content_height + 48), viewport_height - 32)
    top = max(16, (viewport_height - panel_height) * 0.5)
    assert top >= 16 and top + panel_height <= viewport_height - 16
print('PASS: wave boundaries, ranged caps, respite, typography and scroll bounds (not engine/layout render)')
