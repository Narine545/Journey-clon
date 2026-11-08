"""Tactical evolution source guards and timing/geometry mirrors, not Godot execution."""
import itertools
import math
from pathlib import Path

root = Path(__file__).resolve().parents[1]
run = (root / 'scripts/raid_run.gd').read_text()
mines = (root / 'scripts/raid_stern_charges.gd').read_text()
hud = (root / 'scripts/raid_hud.gd').read_text()
smoke = (root / 'scripts/boat_smoke.gd').read_text()
for flag, card in [('storm_broadside', 12), ('chain_mines', 13)]:
    assert run.count(f'{flag} = false') == 2  # start/leave
    assert f'available.append({card})' in run and f'{flag} = true' in run
    assert f'run.{flag}' in hud
assert 'not storm_broadside and pellets >= 3 and turn_rank >= 1' in run
assert 'not chain_mines and stern_rank >= 3 and pulse_radius >= 18.0' in run
assert '_weapon_hit_limit(weapon)' in run
assert 'if weapon > 0 and storm_broadside:\n\t\treturn 2' in run
assert 'return 3 if weapon == 0 and piercing_harpoon else 1' in run
assert 'var spread := 0.26 if storm_broadside else 0.13' in run
assert 'damage if weapon == 0 else damage * 0.7' in run
assert '"chain": run.chain_mines' in mines  # placement-time snapshot
assert 'const CAPACITY := 12' in mines and 'const CHAIN_DELAY := 0.20' in mines
assert 'neighbor["detonate_at"] = _clock + CHAIN_DELAY' in mines
for token in ('float(neighbor["blast"]) < 0.0', 'bool(neighbor.get("chain", false))',
              'float(neighbor["age"]) >= ARM_TIME',
              'float(neighbor.get("detonate_at", -1.0)) < 0.0',
              'at.distance_to(neighbor["at"]) <= reach', '_line_clear(at, neighbor["at"])'):
    assert token in mines, token
assert mines.count('charge["age"] = float(charge["age"]) + delta') == 1
assert mines.index('for charge in charges:\n\t\tif float(charge["blast"]) < 0.0:') < mines.index('for index in range(charges.size() - 1, -1, -1):')
assert '_clock = 0.0' in mines.split('func reset()', 1)[1].split('func drop_point()', 1)[0]
assert 'state != State.RUNNING or main.inspection_active()' in run
assert '_check_raid_tactical_evolutions()' in smoke
assert 'const ENEMY_CAP := 80' in run and 'const SHOT_CAP := 160' in run
for token in ('Time.', 'create_timer', 'OmniLight3D', 'SubViewport'):
    assert token not in mines

for pellets in range(1, 6):
    for turn in range(4):
        assert (pellets >= 3 and turn >= 1) == (pellets - 1 >= 2 and turn > 0)
    normal = [(i - (pellets - 1) / 2) * .13 for i in range(pellets)]
    storm = [(i - (pellets - 1) / 2) * .26 for i in range(pellets)]
    assert math.isclose(sum(storm), 0, abs_tol=1e-9)
    assert all(math.isclose(b, 2 * a) for a, b in zip(normal, storm))
    assert max(map(abs, storm)) <= .52  # <= 60 degrees total fan at five pellets
for nose, broadside in itertools.product((False, True), repeat=2):
    limits = [3 if nose else 1, 2 if broadside else 1, 2 if broadside else 1]
    for limit in limits:
        hp, seen = [100] * 4, set()
        for i in range(4):
            for _ in range(10):
                if i not in seen and len(seen) < limit:
                    seen.add(i)
                    hp[i] -= 22
        assert hp == [78] * limit + [100] * (4 - limit)


class Chain:
    def __init__(self, count=3, order=None):
        self.clock = 0.
        self.charges = [dict(id=i, x=i * 6., age=.65, chain=True, deadline=-1., fired=None)
                        for i in (order or range(count))]
        self.blocked = set()

    def fire(self, source):
        if source['fired'] is not None:
            return
        source['fired'] = self.clock
        if not source['chain']:
            return
        for target in self.charges:
            pair = frozenset((source['id'], target['id']))
            if (target['fired'] is None and target['chain'] and target['age'] >= .65
                    and target['deadline'] < 0 and abs(target['x'] - source['x']) <= 8
                    and pair not in self.blocked):
                target['deadline'] = self.clock + .2

    def tick(self, dt):
        self.clock += dt
        for c in self.charges:
            c['age'] += dt
        for c in reversed(self.charges):
            if c['deadline'] >= 0 and self.clock >= c['deadline'] and c['age'] >= .65:
                self.fire(c)


for order in itertools.permutations(range(3)):
    c = Chain(order=order)
    by_id = {x['id']: x for x in c.charges}
    c.fire(by_id[0])
    assert by_id[1]['deadline'] == .2 and by_id[2]['deadline'] == -1
    c.tick(.19)
    assert by_id[1]['fired'] is None
    c.tick(.02)
    assert by_id[1]['fired'] == .21 and math.isclose(by_id[2]['deadline'], .41)
    c.fire(by_id[0])  # repeat cannot re-arm or reset neighbors
    c.tick(.21)
    assert all(x['fired'] is not None for x in c.charges)
for reason in ('unarmed', 'old_normal', 'obstacle'):
    c = Chain()
    if reason == 'unarmed':
        c.charges[1]['age'] = 0.
    elif reason == 'old_normal':
        c.charges[1]['chain'] = False
    else:
        c.blocked.add(frozenset((0, 1)))
    c.fire(c.charges[0])
    assert all(x['deadline'] < 0 for x in c.charges[1:])
for fps in (19, 26, 60, 120):
    c = Chain(count=12)
    c.fire(c.charges[0])
    for _ in range(4 * fps):
        c.tick(1 / fps)
    assert all(x['fired'] is not None for x in c.charges)
    times = [x['fired'] for x in c.charges]
    assert all(.2 - 1e-9 <= b - a <= .2 + 1 / fps + 1e-9
               for a, b in zip(times, times[1:]))
print('PASS: tactical eligibility/reset, two-hit broadside fan and bounded delayed chain/arming/LoS mirrors (not runtime)')
