"""Shader wiring/math guards. Does not compile shaders or measure GPU performance."""
import math
from pathlib import Path

root = Path(__file__).resolve().parents[1]
run = (root / 'scripts/raid_run.gd').read_text()
hud = (root / 'scripts/raid_hud.gd').read_text()
fx = (root / 'scripts/raid_weapon_fx.gd').read_text()
title = (root / 'shaders/raid_title.gdshader').read_text()
bar = (root / 'shaders/raid_progress.gdshader').read_text()
muzzle = (root / 'shaders/raid_muzzle.gdshader').read_text()
smoke = (root / 'scripts/boat_smoke.gd').read_text()

assert 'var effects_enabled := true' in run
assert run.count('weapon_fx.reset()') == 2
assert 'weapon_fx.step(delta)' in run and 'weapon_fx.render()' in run
assert run.index('weapon_fx.emit(weapon, aim)') < run.index('for pellet in range(')
assert 'instance_count = 6' in fx and 'use_custom_data = true' in fx
assert 'const LIFE := 0.09' in fx and 'visible_instance_count = 6 if active else 0' in fx
assert 'get_global_transform_interpolated()' in fx
assert 'if not run.effects_enabled' in fx
assert 'extra_cull_margin = 4.0' in fx
assert 'INSTANCE_CUSTOM.g' in muzzle and 'INSTANCE_CUSTOM.r' in muzzle
assert 'projected_length > 0.0001' in muzzle
assert 'depth_draw_never' in muzzle and 'depth_test_disabled' not in muzzle
assert 'face_weight' in muzzle and 'POSITION = PROJECTION_MATRIX' in muzzle
assert 'for _index in range(3)' in hud
assert 'preload("res://shaders/raid_progress.gdshader")' in hud
assert 'clampf(amount, 0.0, 1.0)' in hud
assert 'bar.visible = not run.modal()' in hud
assert '"effect_time", run.elapsed' in hud  # pause-safe UI fill animation
assert '_fx_toggle.toggled.connect(_set_effects)' in hud
assert '_title.material = _title_material if enabled else null' in hud
assert 'label_size' in title and '_title.resized.connect(_sync_title)' in hud
assert 'COLOR.rgb *=' in title and 'texture(' not in title
assert 'UV =' not in title and 'COLOR.a =' not in title  # don't corrupt font glyph masks
assert 'value <= 0.0' in bar and 'value >= 1.0' in bar
assert 'i < 4' in bar and 'if (motion > 0.0)' in bar
assert 'TIME' not in bar and 'TIME' not in muzzle
assert '_check_raid_fx()' in smoke
for token in ('OmniLight3D', 'SpotLight3D', 'SubViewport', 'texture_blit', 'hint_screen_texture'):
    assert token not in title + bar + muzzle + fx
for shader in (title, bar, muzzle):
    assert shader.count('{') == shader.count('}')


def smooth(a, b, x):
    t = max(0, min(1, (x - a) / (b - a)))
    return t * t * (3 - 2 * t)


# Exact empty/full endpoints despite moving wave; bounded in pixel rather than UV units.
for width in (100, 245, 768, 1920):
    for value in (0, 0.001, 0.5, 0.999, 1):
        for time in (0, 0.3, 5, 59):
            for y in (0, 0.5, 1):
                wave = math.sin(y * math.tau + time * 2) * 0.8 / width
                edge = max(0, min(1, value + wave))
                for x in (0, 0.5, 1):
                    filled = 1 - smooth(edge - 0.5 / width, edge + 0.5 / width, x)
                    if value <= 0:
                        filled = 0
                    if value >= 1:
                        filled = 1
                    assert 0 <= filled <= 1
                    if value in (0, 1):
                        assert filled == value

# Side/face alpha weights form a continuous partition, including head-on view.
for angle in range(181):
    z = math.cos(math.radians(angle))
    projected_length = abs(math.sin(math.radians(angle)))
    if projected_length > 0.0001:
        along = (math.sin(math.radians(angle)) / projected_length, 0)
    else:
        along = (1, 0)
    assert all(math.isfinite(v) for v in along)
    face = smooth(0.55, 0.9, abs(z))
    assert math.isclose(face + (1 - face), 1)
    assert 0 <= face <= 1
for fps in (19, 26, 60, 120):
    remaining = 0.09
    frames = 0
    while remaining > 0:
        remaining = max(0, remaining - 1 / fps)
        frames += 1
    assert frames <= math.ceil(0.09 * fps) + 1
print('PASS: UI/muzzle wiring, bounds, fill endpoints, billboard head-on safety and lifetime (not shader/runtime)')
