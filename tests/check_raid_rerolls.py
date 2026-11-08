"""Reroll integration/source guards and bounded deal mirrors; not Godot execution."""
from pathlib import Path
import random
import itertools
import re

root = Path(__file__).resolve().parents[1]
run = (root / 'scripts/raid_run.gd').read_text()
hud = (root / 'scripts/raid_hud.gd').read_text()
smoke = (root / 'scripts/boat_smoke.gd').read_text()
assert 'const REROLLS := 2' in run
assert run.count('rerolls_left = REROLLS') == 2
assert 'state != State.CHOOSING or rerolls_left <= 0' in run
assert 'if not choices.has(kind):' in run
assert 'available.erase(forced)' in run and 'choices.append(forced)' in run
reroll = run.split('func _reroll_choices()', 1)[1].split('func _offer_upgrade()', 1)[0]
assert reroll.index('if not _can_reroll():') < reroll.index('_deal_choices(previous)')
assert reroll.index('_deal_choices(previous)') < reroll.index('rerolls_left -= 1')
for token in ('xp -=', 'level +=', 'elapsed +=', '_spawn(', 'credit_xp('):
    assert token not in reroll
assert '_reroll.disabled = not run._can_reroll()' in hud
assert '_reroll.visible = run.state == RaidRun.State.CHOOSING' in hud
assert '_check_raid_rerolls()' in smoke
# Guard the actual class-field shadow reported by Godot; syntax parsing misses it.
fields = set(re.findall(r'^var (\w+)', smoke, re.M))
locals_ = set(re.findall(r'^\s+var (\w+)', smoke, re.M))
assert not fields & locals_, fields & locals_

rng = random.Random(321)

def deal(pool, previous=()):
    available = list(pool)
    fresh = [kind for kind in available if kind not in previous]
    assert not previous or fresh
    result = []
    if previous:
        forced = rng.choice(fresh)
        result.append(forced)
        available.remove(forced)
    while len(result) < 3:
        chosen = rng.choice(available)
        result.append(chosen)
        available.remove(chosen)
    return result

for size in range(3, 15):
    pool = list(range(size))
    for _ in range(200):
        previous = deal(pool)
        assert len(set(previous)) == 3
        can_reroll = any(k not in previous for k in pool)
        assert can_reroll == (size > 3)
        if not can_reroll:
            continue  # same three cards: button disabled, attempt not consumed
        for remaining in (2, 1):
            new = deal(pool, previous)
            assert len(set(new)) == 3 and set(new) <= set(pool)
            assert set(new) - set(previous)
            previous = new
# Sample every possible old triple in a small saturated pool: always retain uniqueness.
for previous in itertools.combinations(range(6), 3):
    for _ in range(20):
        new = deal(range(6), previous)
        assert len(set(new)) == 3 and set(new) - set(previous)
print('PASS: reroll limits/state/reset/no XP cost/new candidate/unique draws and smoke shadow guard (not runtime)')
