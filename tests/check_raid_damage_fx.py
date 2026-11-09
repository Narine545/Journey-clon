"""Reactive damage-glitch source/math guards, not shader compilation or rendered proof."""
from pathlib import Path
root = Path(__file__).resolve().parents[1]
fx = (root / 'scripts/raid_damage_fx.gd').read_text()
shader = (root / 'shaders/raid_damage.gdshader').read_text()
run = (root / 'scripts/raid_run.gd').read_text()
boat = (root / 'scripts/boat_vessel.gd').read_text()
hud = (root / 'scripts/raid_hud.gd').read_text()
smoke = (root / 'scripts/boat_smoke.gd').read_text()
assert 'const LIFE := 0.40' in fx and 'layer = 19' in fx
assert 'layer.layer = 20' in run
assert run.count('damage_fx.reset()') == 2
assert 'main.raid.damage_fx.hit(maxf(0.0, hp_before - hull_hp))' in boat
body = boat.split('func apply_hull_damage(', 1)[1].split('func _physics_process(', 1)[0]
assert body.index('main.raid.debug_invulnerable') < body.index('main.raid.damage_fx.hit(')
for guard in ('actual <= 0.0 or not _allowed()', 'run.effects_enabled',
              'run.state == RaidRun.State.RUNNING', 'not run.main.inspection_active()'):
    assert guard in fx
assert 'BackBufferCopy.COPY_MODE_VIEWPORT' in fx  # capture existing lower-layer post FX
assert 'add_child(_copy)' in fx and fx.index('add_child(_copy)') < fx.index('add_child(_rect)')
assert '_copy.visible = _rect.visible' in fx
assert '_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE' in fx
assert '_rect.size = get_viewport().get_visible_rect().size' in fx
assert 'get_viewport().size_changed.connect(_resize_rect)' in fx
assert 'if run.modal():\n\t\trun.damage_fx.reset()' in hud
assert 'ГЛИТЧ АКТИВЕН' in hud and 'run.damage_fx.preview' in hud
assert 'if run._hurt_timer > 0.45:' not in hud
assert '_check_raid_damage_fx()' in smoke
assert 'hint_screen_texture, repeat_disable, filter_linear' in shader
assert 'SCREEN_UV' in shader and 'SCREEN_PIXEL_SIZE' in shader
assert shader.count('textureLod(') == 3
for bad in ('texture(TEXTURE', 'TIME', 'negative_intensity', 'glow', 'discard'):
    assert bad not in shader.split('shader_type', 1)[1], bad
preview = fx.split('func preview()', 1)[1].split('func _allowed()', 1)[0]
assert 'hit(12.0)' in preview
for bad in ('hull_hp =', 'apply_hull_damage', 'stats.', 'xp +='):
    assert bad not in preview
assert 'const PREVIEW_LIFE := 1.50' in fx
assert '_hold = 0.90' in fx
assert 'run.damage_fx.is_active()' in hud
for duration, hold in ((.4, .12), (1.5, .9)):
    for age in (0, hold, duration * .9, duration):
        envelope = min(1, max(0, (duration - age) / (duration - hold)))
        assert 0 <= envelope <= 1
    assert max(0, (duration - duration) / (duration - hold)) == 0
for actual in (1, 9, 12, 24, 100, 1000):
    peak = min(.80, max(.55, .55 + actual / 100))
    assert .55 <= peak <= .80
    assert 10 * peak <= 8.0
print('PASS: actual damage, 0.4s hit/1.5s visible preview, state/layer guards and CPU activation indicator (not render)')
