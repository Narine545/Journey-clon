"""Detailed report accounting and integration guards, not native engine execution."""
from pathlib import Path
import math
import random
root = Path(__file__).resolve().parents[1]
stats = (root / 'scripts/raid_stats.gd').read_text()
run = (root / 'scripts/raid_run.gd').read_text()
boat = (root / 'scripts/boat_vessel.gd').read_text()
mines = (root / 'scripts/raid_stern_charges.gd').read_text()
hud = (root / 'scripts/raid_hud.gd').read_text()
assert 'enum Cause { CONTACT, SHELL, REEF, SHOAL, OTHER }' in stats
assert 'func _hurt(amount: float, cause: int = RaidStats.Cause.CONTACT)' in run
assert '_hurt(float(shot["power"]), RaidStats.Cause.SHELL)' in run
assert 'main.boat.apply_hull_damage(amount, cause)' in run
assert 'cause: int = RaidStats.Cause.OTHER' in boat
assert 'apply_hull_damage(dmg, RaidStats.Cause.REEF)' in boat
assert 'apply_hull_damage(8.0, RaidStats.Cause.SHOAL)' in boat
assert 'stats.record_received(cause, maxf(0.0, hp_before - hull_hp), main.raid.elapsed)' in boat
body = stats.split('func record_received(', 1)[1]
assert body.index('if actual <= 0.0:') < body.index('received += actual')
assert 'incoming[index] += actual' in body and 'incoming_hits[index] += 1' in body
assert 'else Cause.OTHER' in body and 'last_hit_at = seconds' in body
reset = stats.split('func reset()', 1)[1].split('func record_damage(', 1)[0]
for field in ('incoming.fill(0.0)', 'incoming_hits.fill(0)', 'last_cause = -1',
              'last_hit_at = -1.0', 'repairs = 0', 'repaired = 0.0',
              'stern_unlocked_at = -1.0', 'charges_dropped = 0', 'charges_exploded = 0', 'pulses = 0'):
    assert field in reset, field
assert 'stats.repaired += minf(30.0, 100.0 - main.boat.hull_hp)' in run
assert 'if stern_rank == 0:\n\t\t\t\tstats.stern_unlocked_at = elapsed' in run
assert 'stats.pulses += 1' in run
assert 'run.stats.charges_dropped += 1' in mines
blast = mines.split('func _detonate(', 1)[1].split('func render()', 1)[0]
assert blast.index('if float(charge["blast"]) >= 0.0:') < blast.index('run.stats.charges_exploded += 1')
for token in ('_incoming_summary()', '_build_summary()', 'Последний урон:',
              'run.stats.incoming_hits[index]', 'run.stats.repairs', 'run.stats.repaired',
              'run.stats.charges_dropped', 'run.stats.charges_exploded', 'run.stats.pulses',
              'run.reload_scale', 'run.turn_rank', 'run.speed_rank', 'run.xp_rank',
              'run.salvage.magnet_range', 'run.stats.stern_unlocked_at'):
    assert token in hud, token

rng = random.Random(8)
for _ in range(1000):
    hp, total, repaired = 100., 0., 0.
    by_cause, hits = [0.] * 5, [0] * 5
    last = None
    for tick in range(100):
        if rng.random() < .2:
            restored = min(30, 100 - hp)
            hp += restored
            repaired += restored
            continue
        cause = rng.randrange(5)
        power = rng.uniform(0, 120)
        blocked = rng.random() < .1
        before = hp
        if not blocked:
            hp = max(0, hp - power)
        actual = max(0, before - hp)
        if actual > 0:
            total += actual
            by_cause[cause] += actual
            hits[cause] += 1
            last = (cause, tick)
    assert math.isclose(total, sum(by_cause), abs_tol=1e-8)
    assert math.isclose(100 + repaired - hp, total, abs_tol=1e-8)
    assert all((n > 0) == (amount > 0) for n, amount in zip(hits, by_cause))
    assert last is not None
print('PASS: received causes/hits/last damage, repairs, final build and ordnance counters (not runtime)')
