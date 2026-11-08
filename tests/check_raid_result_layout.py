"""Responsive result layout guards and bounds mirror; not a rendered UI test."""
from pathlib import Path
root = Path(__file__).resolve().parents[1]
hud = (root / 'scripts/raid_hud.gd').read_text()
smoke = (root / 'scripts/boat_smoke.gd').read_text()
assert 'var _result_columns: Array[Label] = []' in hud
assert '_results.columns = 2 if width >= 1000.0 else 1' in hud
assert 'minf(1280.0 if is_result else 1120.0, size.x - 32.0)' in hud
assert '_result_columns[0].text = _combat_summary().strip_edges()' in hud
assert '_build_summary() + "\n" + _evolution_summary()' in hud.replace('\\n', '\n')
assert '_results.visible = run.state in [RaidRun.State.WON, RaidRun.State.LOST]' in hud
assert 'column.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART' in hud
assert 'column.add_theme_font_size_override("font_size", 20)' in hud
assert 'column.size_flags_vertical = Control.SIZE_SHRINK_BEGIN' in hud
assert '_modal_scroll.set_deferred("scroll_vertical", 0)' in hud
assert 'shell.add_child(scroll)' in hud and 'shell.add_child(_modal_footer)' in hud
for name in ('_retry', '_leave', '_resume', '_reroll'):
    assert f'_modal_footer.add_child({name})' in hud
    assert f'box.add_child({name})' not in hud
assert '_modal_footer.get_combined_minimum_size().y' in hud
summary = hud.split('func _summary()', 1)[1].split('func _combat_summary()', 1)[0]
assert '_combat_summary()' not in summary
assert 'run.xp_awarded' in summary and 'ОТЛАДОЧНЫЙ РЕЙД' in summary
assert '_check_raid_result_layout()' in smoke
for viewport in (640, 800, 1024, 1143, 1280, 1920, 2560):
    width = min(1280, viewport - 32)
    columns = 2 if width >= 1000 else 1
    assert width <= viewport - 32
    if viewport == 1143:
        assert columns == 2
    if columns == 2:
        per_column = (width - 48 - 24) / 2
        assert per_column >= 464
    else:
        assert width < 1000
print('PASS: two-column results, narrow fallback, fixed footer, preserved sections and scroll reset (not render)')
