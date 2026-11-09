"""Control utility is measured per field/target, never inflated by pressure ticks."""
from pathlib import Path
s = Path('scripts/sphere_mines.gd').read_text()
stats = Path('scripts/raid_stats.gd').read_text()
r = Path('scripts/raid_run.gd').read_text()
h = Path('scripts/raid_hud.gd').read_text()
for name in ('sphere_dropped', 'sphere_opened', 'sphere_effective', 'sphere_contacts'):
    assert f'var {name} := 0' in stats and f'\t{name} = 0' in stats
assert 'sphere_unlocked_at = -1.0' in stats
assert 'stats.sphere_unlocked_at = elapsed' in r
assert '(after_push - before_push).dot(normal) >= 0.05' in s
assert 'if not measured.has(identity):' in s
assert 'if measured.is_empty():' in s
assert s.count('stats.sphere_dropped += 1') == 1
assert s.count('stats.sphere_opened += 1') == 1
assert 'контактов поле–цель' in h
assert 'record_damage' not in s
# Two fields, same enemy can count once per field, not once per pressure step.
def record(stream):
    measured = set()
    useful, contacts = 0, 0
    for enemy, dv in stream:
        if dv >= .05 and enemy not in measured:
            useful += not measured
            measured.add(enemy)
            contacts += 1
    return useful, contacts
assert record([(1, .5)]*120) == (1, 1)
assert record([(1, .01)]*120) == (0, 0)
assert record([(1, .5), (2, .5)]*120) == (1, 2)
assert record([(1, .5)])[1] + record([(1, .5)])[1] == 2
print('PASS sphere utility counters, real impulse threshold, per-field deduplication and reset')
