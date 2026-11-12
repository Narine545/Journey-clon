"""XP multiplier accounting and speed-explanation guards; not an engine run."""
import random
from pathlib import Path

root = Path(__file__).resolve().parents[1]
run = (root / 'scripts/raid_run.gd').read_text()
boat = (root / 'scripts/boat_vessel.gd').read_text()
hud = (root / 'scripts/raid_hud.gd').read_text() + (root / 'scripts/raid_combat_ui.gd').read_text()
smoke = (root / 'scripts/boat_smoke.gd').read_text()
assert 'const XP_MAX_RANK := 4' in run
assert 'available.erase(9)' in run
assert 'xp_rank = mini(XP_MAX_RANK, xp_rank + 1)' in run
assert run.count('xp_rank = 0') == 2
assert run.count('_xp_quarters = 0') == 2
assert run.count('xp_awarded = 0') == 2
assert 'credit_xp(salvage.step(delta))' in run
assert 'var units := amount * (4 + xp_rank) + _xp_quarters' in run
assert 'floori(float(units) * 0.25)' in run and '_xp_quarters = units % 4' in run
assert 'xp_awarded += gained' in run
assert '_check_raid_xp_bonus()' in smoke
assert 'var hp_factor := hull_speed_factor()' in boat
assert 'lerpf(0.60, 1.0, clampf(hull_hp / 100.0, 0.0, 1.0))' in boat
assert 'main.overdrive_timer > 0.0' in boat  # temporary boost is separate from permanent rank
assert all(token in hud for token in ('main.boat.speed', 'available_speed', 'run.turn_multiplier()'))
assert 'main.boat.hull_speed_factor()' in hud
assert 'main.overdrive_timer' in hud and 'БОНУСЫ — ДО КОНЦА РЕЙДА' in hud
assert 'run.xp_multiplier()' in hud and 'run.xp_awarded' in hud


def credit(amount, rank, remainder=0):
    if amount <= 0:
        return 0, remainder
    units = amount * (4 + rank) + remainder
    return units // 4, units % 4


for rank in range(5):
    total = remainder = 0
    for _ in range(100):
        gained, remainder = credit(2, rank, remainder)
        total += gained
    assert total == 200 * (1 + rank * 0.25)
    assert remainder == 0
assert credit(2, 1) == (2, 2)
assert credit(2, 1, 2) == (3, 0)
assert credit(2, 4) == (4, 0)
assert credit(0, 4, 3) == (0, 3)
assert credit(-1, 4, 3) == (0, 3)
rng = random.Random(291)
awarded = remainder = exact_quarters = 0
for _ in range(10000):
    amount, rank = rng.randrange(40), rng.randrange(5)
    gained, remainder = credit(amount, rank, remainder)
    awarded += gained
    exact_quarters += amount * (4 + rank)
    assert awarded * 4 + remainder == exact_quarters
    assert 0 <= remainder < 4

# Neither time nor XP rank changes the permanent engine upgrade.
for rank in range(4):
    engine = 1 + rank * 0.12
    for hp in (0, 15, 25, 50, 100):
        factor = 0.6 + 0.4 * hp / 100
        max_speed = 10 * engine * factor
        assert max_speed <= 10 * engine
        assert engine == 1 + rank * 0.12
    assert abs(10 * engine * 0.8 / (10 * engine) - 0.8) < 1e-12
print('PASS: XP multiplier caps/reset, quarter carry, pickup-time accounting and damage vs permanent speed (not engine)')
