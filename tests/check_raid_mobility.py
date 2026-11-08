"""Mobility wiring and numeric mirrors; no Godot execution."""
import math
from pathlib import Path

root = Path(__file__).resolve().parents[1]
run = (root / 'scripts/raid_run.gd').read_text()
boat = (root / 'scripts/boat_vessel.gd').read_text()
smoke = (root / 'scripts/boat_smoke.gd').read_text()
assert 'const MOBILITY_MAX_RANK := 3' in run
assert 'const SPEED_PER_RANK := 0.12' in run
assert 'const TURN_PER_RANK := 0.15' in run
assert run.count('speed_rank = 0') == 2  # start and leave
assert run.count('turn_rank = 0') == 2
assert 'available.erase(6)' in run and 'available.erase(7)' in run
assert 'speed_rank = mini(MOBILITY_MAX_RANK, speed_rank + 1)' in run
assert 'turn_rank = mini(MOBILITY_MAX_RANK, turn_rank + 1)' in run
assert 'TURN_RATE * raid_turn_factor()' in boat
assert 'base * hp_factor * boost * raid_speed_factor()' in boat
assert 'REVERSE_SPEED * raid_speed_factor()' in boat
assert '(ACCELERATION if absf(throttle) > 0.01 else DRAG) * raid_speed_factor()' in boat
for method in ('raid_speed_factor', 'raid_turn_factor'):
    body = boat.split(f'func {method}()', 1)[1].split('\n\nfunc ', 1)[0]
    assert 'main.raid != null and main.raid.engaged():' in body
assert '_check_raid_mobility()' in smoke


def turn(steer, speed, dt, rank):
    return -steer * 0.95 * (1 + 0.15 * rank) * dt * min(abs(speed) / 3.5, 1) * (1 if speed >= 0 else -1)


for rank in range(4):
    speed_factor = 1 + 0.12 * rank
    turn_factor = 1 + 0.15 * rank
    assert 1 <= speed_factor <= 1.36
    assert 1 <= turn_factor <= 1.45
    for hp in (0, 15, 50, 100):
        hp_factor = 0.6 + 0.4 * hp / 100
        for trailer in (False, True):
            for boost in (1, 1.35):
                base = (12 if trailer else 10) * hp_factor * boost
                assert math.isclose(base * speed_factor / base, speed_factor)
    # Scaling acceleration and drag with top speed preserves ramp/braking time.
    assert math.isclose(10 * speed_factor / (3.2 * speed_factor), 10 / 3.2)
    assert math.isclose(10 * speed_factor / (1.8 * speed_factor), 10 / 1.8)
    for speed in (-10, -3.5, -1, 0, 1, 3.5, 10):
        for steer in (-1, 0, 1):
            for dt in (1 / 120, 1 / 60, 1 / 20):
                value = turn(steer, speed, dt, rank)
                assert math.isclose(value, turn(steer, speed, dt, 0) * turn_factor)
                assert math.isclose(value, -turn(-steer, speed, dt, rank))
                assert math.isclose(value, -turn(steer, -speed, dt, rank))
                if speed == 0:
                    assert value == 0

for speed_rank in range(4):
    for turn_rank in range(4):
        for full_hull in (False, True):
            pool = [0, 3, 4, 5, 6, 7]  # weapon reload and pellet branches already saturated
            if full_hull:
                pool.remove(4)
            if speed_rank >= 3:
                pool.remove(6)
            if turn_rank >= 3:
                pool.remove(7)
            assert len(pool) >= 3
print('PASS: raid mobility wiring, caps, speed/turn curves, reverse, stopping and upgrade eligibility (not engine)')
