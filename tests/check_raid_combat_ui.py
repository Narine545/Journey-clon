"""Responsive/read-only HUD and hidden tools regression; no engine layout proof."""
from pathlib import Path
s = Path('scripts/raid_combat_ui.gd').read_text()
h = Path('scripts/raid_hud.gd').read_text()
sea = Path('scripts/sea_look_trial.gd').read_text()
assert 'weapons.columns = 6 if size.x >= 1400 else 3' in s
assert 'GridContainer.new()' in s and 'PanelContainer.new()' in s
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
for width,height in ((800,600),(1280,720),(1920,1080)):
    cols = 6 if width >= 1400 else 3
    rows = 1 if cols == 6 else 2
    card = (width-32-8*(cols-1))/cols
    top = height-16-rows*72-(rows-1)*8
    assert card >= 200 and top > 200
print('PASS read-only weapon cards, responsive bounds, preserved boss cues and collapsed tests')
