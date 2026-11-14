"""Structured upgrade cards preserve native selection, focus and complete numeric preview."""
from pathlib import Path
s = Path('scripts/raid_upgrade_card.gd').read_text()
h = Path('scripts/raid_hud.gd').read_text()
assert 'extends Button' in s
assert 'func set_content(' in s
for label in ('caption', 'heading', 'description', 'effect'):
    assert f'var {label}: Label' in s
assert 'heading.text = name_text' in s
assert 'effect.text = values' in s
assert 'AUTOWRAP_WORD_SMART' in s
assert 'is_hovered() or has_focus()' in s
assert 'focus_entered.connect(queue_redraw)' in s
assert 'node.mouse_filter = Control.MOUSE_FILTER_IGNORE' in s
assert '_margin.minimum_size_changed.connect(_sync_minimum, CONNECT_DEFERRED)' in s
assert 'card.pressed.connect(run.choose.bind(index))' in h
assert '_card_buttons[0].grab_focus.call_deferred()' in h
assert 'run.upgrade_preview(run.choices[index])' in h
assert 'run.choices[index] <= 13' in h  # extra sphere cards aren't mislabelled evolutions
assert '_modal = RaidCutPanel.new()' in h
assert 'report_panel.add_child(column)' in h
assert '_title_material' not in h
for forbidden in ('run.', 'rotation', 'Tween', 'Time.', '_gui_input'):
    assert forbidden not in s
print('PASS cut-paper cards: distinct typography, wrapped previews, native focus/input and modal continuity')
