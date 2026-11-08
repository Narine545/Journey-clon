"""Readability/flash policy guards; not shader compilation or a render test."""
import math
import re
from pathlib import Path

root = Path(__file__).resolve().parents[1]
run = (root / 'scripts/raid_run.gd').read_text()
fx = (root / 'scripts/raid_weapon_fx.gd').read_text()
hud = (root / 'scripts/raid_hud.gd').read_text()
muzzle = (root / 'shaders/raid_muzzle.gdshader').read_text()
enemy_shader = (root / 'shaders/raid_enemy.gdshader').read_text()
smoke = (root / 'scripts/boat_smoke.gd').read_text()
assert 'const LIFE := 0.16' in fx
assert 'material.render_priority = 10' in fx
assert '_body.get_global_transform_interpolated()' in fx
assert 'Color(strength, float(face)' in fx and 'strength * strength' not in fx
assert 'clampf(_remaining[weapon] / LIFE * 2.0, 0.0, 1.0)' in fx
assert 'Vector3(0, 2.0, -6.4)' in fx and 'Vector3(2.4, 1.9, 1.0)' in fx
assert 'flash_scale' in muzzle and '"flash_scale"' in fx
assert 'depth_test_disabled' not in muzzle
assert '* 3.6)' in muzzle and 'VERTEX.y * 1.6' in muzzle
assert 'run.weapon_fx.preview()' in hud
assert 'run.state != RaidRun.State.RUNNING' in fx
assert 'fog_disabled' in enemy_shader and 'enemy_tint = COLOR.rgb' in enemy_shader
assert 'ALPHA' not in enemy_shader and 'depth_test_disabled' not in enemy_shader
assert 'tint.lerp(Color.WHITE, 0.25)' in run
assert 'Color.WHITE if float(enemy["flash"])' not in run
assert '_enemy_visual_basis(enemy, radius)' in run
assert 'shape.y.length()' in smoke and '_check_raid_colors()' in smoke
assert 'roles[kind], 16, RaidRun.COLORS[kind]' in hud
assert 'OmniLight3D' not in fx and 'SpotLight3D' not in fx
colors_source = run.split('const COLORS := ', 1)[1].split('\n', 1)[0]
hexes = re.findall(r'Color\("([0-9a-f]{6})"\)', colors_source)
assert hexes == ['ff4b35', 'ffe144', 'be62ff', '39a9ff']
colors = [tuple(int(h[i:i+2], 16) / 255 for i in (0, 2, 4)) for h in hexes]
for hit in (False, True):
    shades = [tuple(.75 * channel + .25 for channel in c) if hit else c for c in colors]
    for i, a in enumerate(shades):
        assert a != (1, 1, 1)
        for b in shades[i+1:]:
            assert math.dist(a, b) > .40
# At 19-26 FPS the new 0.16s lifetime has a useful bright plateau, not a squared tiny tail.
for fps in (19, 26, 60, 120):
    strengths = []
    remaining = .16
    while remaining > 0:
        strengths.append(min(1, remaining / .16 * 2))
        remaining = max(0, remaining - 1 / fps)
    assert sum(s >= .8 for s in strengths) >= 2
    assert all(0 <= s <= 1 for s in strengths)
for zoom in (16, 32, 48, 72):
    scale = max(1, min(1.6, zoom / 32))
    # Full side-plane height before procedural cutout; no unbounded screen-space sprite.
    pixels = 1.6 * scale / zoom * 1080
    assert pixels >= 38
    assert 1 <= scale <= 1.6
print('PASS: role palettes, hit hue retention, flash plateau/mounts/zoom bounds and preview guards (not render)')
