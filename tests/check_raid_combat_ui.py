"""Responsive/read-only HUD and hidden tools regression; no engine layout proof."""
from pathlib import Path
s = Path('scripts/raid_combat_ui.gd').read_text()
h = Path('scripts/raid_hud.gd').read_text()
sea = Path('scripts/sea_look_trial.gd').read_text()
assert 'weapons.columns = 5 if size.x >= 1600 else (3 if size.x >= 1000 else 2)' in s
assert 'GridContainer.new()' in s and 'RaidCutPanel.new()' in s
assert 'run._bow_timer' in s and 'run._side_timer' in s
assert 'run.pulse_cooldown' in s and 'run.stern_charges.cooldown' in s
assert 'run.sphere_mines.cooldown' in s and 'run.gravity_mines.cooldown' in s
assert 'НЕ УСТАНОВЛЕНО' in s
assert 'not run.modal()' in s and 'not run.main.inspection_active()' in s
assert '_tools_panel.hide()' in h and 'control.reparent(column)' in h
assert 'if not _tools_panel.visible:' in h
assert 'debug_tools_open()' in sea
assert '_draw_boss_objective(enemy)' in h
assert '"РЕЗОНАНС"' not in s or 'run.resonant_pulse' in s
for flag in ('piercing_harpoon','storm_broadside','resonant_pulse','chain_mines'):
    assert f'run.{flag}' in s
for forbidden in ('run.damage =', 'run.state =', 'run.stats.', 'record_damage', 'run.sphere_rank ='):
    assert forbidden not in s
assert 'weapon_cards[2].reparent(self)' in s
assert 'weapon_cards[3].visible = run.stern_rank > 0' in s
assert 'weapon_cards[4].visible = run.sphere_rank > 0' in s
assert 'weapon_cards[5].visible = run.gravity_rank > 0' in s
for width,height in ((800,600),(1280,720),(1920,1080)):
    cols = 5 if width >= 1600 else (3 if width >= 1000 else 2)
    for active in (2,3,4,5):
        rows = (active+cols-1)//cols
        card = (width-280-8*(cols-1))/cols
        top = height-24-rows*66-(rows-1)*8
        assert card >= 200 and top > 200
print('PASS read-only weapon cards, responsive bounds, preserved boss cues and collapsed tests')
