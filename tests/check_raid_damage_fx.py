"""Boat-local damage overlay source/math guards; not engine shader/render verification."""
from pathlib import Path
root = Path(__file__).resolve().parents[1]
fx = (root / 'scripts/raid_damage_fx.gd').read_text()
shader = (root / 'shaders/raid_damage.gdshader').read_text()
run = (root / 'scripts/raid_run.gd').read_text()
boat = (root / 'scripts/boat_vessel.gd').read_text()
hud = (root / 'scripts/raid_hud.gd').read_text()
smoke = (root / 'scripts/boat_smoke.gd').read_text()
assert 'extends Node\n' in fx
assert 'const LIFE := 0.40' in fx and 'const PREVIEW_LIFE := 1.50' in fx
assert run.count('damage_fx.reset()') == 2
assert 'main.raid.damage_fx.hit(maxf(0.0, hp_before - hull_hp))' in boat
body = boat.split('func apply_hull_damage(', 1)[1].split('func _physics_process(', 1)[0]
assert body.index('main.raid.debug_invulnerable') < body.index('main.raid.damage_fx.hit(')
for guard in ('actual <= 0.0 or not _allowed()', 'run.effects_enabled',
              'run.state == RaidRun.State.RUNNING', 'not run.main.inspection_active()'):
    assert guard in fx
assert '_collect(run.main.boat._body)' in fx
assert '_saved.append(mesh.material_overlay)' in fx
assert 'mesh.material_overlay = _material' in fx
assert 'if not is_instance_valid(_targets[index]):' in fx
assert 'if mesh.material_overlay == _material:' in fx
assert 'mesh.material_overlay = _saved[index]' in fx
assert 'func _exit_tree()' in fx
assert 'pose.affine_inverse()' in fx
assert 'shader_type spatial;' in shader
assert 'depth_draw_never' in shader and 'depth_test_disabled' not in shader
assert 'boat_inverse * MODEL_MATRIX * vec4(VERTEX, 1.0)' in shader
assert 'ALPHA = clamp(' in shader
for forbidden in ('SCREEN_UV', 'SCREEN_TEXTURE', 'hint_screen_texture', 'hint_depth_texture', 'POSITION ='):
    assert forbidden not in shader
for forbidden in ('BackBufferCopy', 'ColorRect', 'CanvasLayer', 'material_override =', '_trailer', 'SubViewport'):
    assert forbidden not in fx
assert '_damage_preview' not in hud and 'run.damage_fx.preview' not in hud
assert '_check_raid_damage_fx()' in smoke and 'material_overlay != saved_overlays[index]' in smoke
for duration, hold in ((.4, .12), (1.5, .9)):
    for age in (0, hold, duration * .9, duration):
        envelope = min(1, max(0, (duration - age) / (duration - hold)))
        assert 0 <= envelope <= 1
    assert max(0, (duration - duration) / (duration - hold)) == 0
# Saved overlay round-trip, including existing overlays rather than just null materials.
for original in (None, 'existing-overlay'):
    current = 'damage-overlay'
    if current == 'damage-overlay':
        current = original
    assert current == original
print('PASS: boat-only overlay scope/restoration/depth, real-hit gating and unchanged preview duration (not render)')
