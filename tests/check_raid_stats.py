"""Bounded combat-stat source guards and arithmetic mirrors, not engine execution."""
from pathlib import Path
import random
import math
root = Path(__file__).resolve().parents[1]
source = (root / 'scripts/raid_stats.gd').read_text()
run = (root / 'scripts/raid_run.gd').read_text()
mines = (root / 'scripts/raid_stern_charges.gd').read_text()
boat = (root / 'scripts/boat_vessel.gd').read_text()
hud = (root / 'scripts/raid_hud.gd').read_text()
smoke = (root / 'scripts/boat_smoke.gd').read_text()
assert run.count('stats.reset()') == 2
assert 'minf(maxf(0.0, hp_before), maxf(0.0, power))' in source
assert 'channel < 0 or channel >= dealt.size()' in source
assert 'evolution_times[index] < 0.0' in source
assert '"channel": channel' in run
assert 'RaidStats.Channel.NOSE if weapon == 0 else RaidStats.Channel.SIDES' in run
assert 'int(shot.get("channel", RaidStats.Channel.NOSE))' in run
assert 'stats.record_damage(RaidStats.Channel.PULSE' in run
assert 'RaidStats.Channel.MINES, float(enemy["hp"]), float(charge["power"])' in mines
assert 'stats.record_evolution(choices[index], elapsed)' in run
assert 'main.raid.stats.received += maxf(0.0, hp_before - hull_hp)' in boat
assert 'stats.debug_used = stats.debug_used or debug_invulnerable or debug_clear_screen' in run
assert hud.count('run.stats.debug_used = run.stats.debug_used or enabled') == 2
assert 'ОТЛАДОЧНЫЙ РЕЙД' in hud and '_combat_summary()' in hud
assert 'total > 0.0 else 0.0' in hud
assert '_check_raid_stats()' in smoke
for forbidden in ('FileAccess', 'Time.', 'Node3D', 'create_timer', 'append('):
    assert forbidden not in source  # fixed-size totals, no hit history/storage

rng = random.Random(44)
for _ in range(2000):
    hp = rng.uniform(.01, 500)
    initial = hp
    totals = [0.] * 4
    for hit in range(20):
        channel = hit % 4
        power = rng.uniform(0, 100)
        actual = min(max(0, hp), max(0, power))
        totals[channel] += actual
        hp -= power  # gameplay overkill behavior unchanged
    assert math.isclose(sum(totals), initial - max(0, hp), abs_tol=1e-8)
    assert all(v >= 0 for v in totals)
    total = sum(totals)
    assert math.isclose(sum(v * 100 / total for v in totals), 100, abs_tol=1e-8)
assert min(max(0, -10), max(0, 100)) == 0
assert min(max(0, 50), max(0, -10)) == 0
# Repairs allow more than 100 received across a raid, but each hit counts real loss only.
hp, received = 100., 0.
for action, value in [('hit', 70), ('repair', 30), ('hit', 1000)]:
    before = hp
    hp = max(0, hp - value) if action == 'hit' else min(100, hp + value)
    if action == 'hit':
        received += max(0, before - hp)
assert received == 130 and hp == 0
print('PASS: damage channels, overkill/dead-hit exclusion, hull accounting, evo clocks and debug marking (not runtime)')
