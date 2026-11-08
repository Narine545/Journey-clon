"""Boss attack schedule/math and integration guards; not Godot execution."""
import math
from pathlib import Path

root = Path(__file__).resolve().parents[1]
boss = (root / 'scripts/raid_boss.gd').read_text()
run = (root / 'scripts/raid_run.gd').read_text()
hud = (root / 'scripts/raid_hud.gd').read_text()
smoke = (root / 'scripts/boat_smoke.gd').read_text()
assert 'const FAN_WARNING := 1.25' in boss
assert 'const RING_WARNING := 1.70' in boss
assert 'const ARRIVAL_GRACE := 1.20' in boss
assert 'enemy["boss_attack_phase"] = phase(enemy)' in boss
assert 'result = directions(enemy)' in boss
assert 'enemy["boss_cycle"] = int(enemy["boss_cycle"]) + 1' in boss
assert 'int(enemy["boss_cycle"]) % 2' in boss
assert 'var volley := RaidBoss.step(enemy, delta, target)' in run
assert 'for aim in volley:' in run and 'aim * RaidBoss.shell_speed(enemy)' in run
assert 'if RaidBoss.preparing(enemy):\n\t\t\t\t\tdirection = Vector2.ZERO' in run
assert 'if kind != 3:' in run  # no double decrement of boss recovery clock
assert 'RaidBoss.directions(enemy)' in hud and 'RaidBoss.warning_length(enemy)' in hud
assert 'RaidBoss.phase(enemy)' in hud and '_draw_boss_warning(enemy)' in hud
assert '_check_raid_boss()' in smoke
assert 'const ENEMY_CAP := 80' in run and 'const SHOT_CAP := 160' in run
assert 'elapsed >= 240.0' in run and 'const DURATION := 300.0' in run


def directions(pattern, phase, aim):
    if pattern == 0:
        half = 2 if phase == 2 else 1
        angles = [aim + i * .28 for i in range(-half, half + 1)]
    else:
        count = 12 if phase == 2 else 10
        angles = [aim + (i + .5) * math.tau / count for i in range(count)]
    return [(math.cos(a), math.sin(a)) for a in angles]


class BossMirror:
    def __init__(self):
        self.hp = 100
        self.timer = 1.2
        self.windup = 0
        self.cycle = 0
        self.pattern = 0
        self.attack_phase = 1
        self.aim = 0

    def tick(self, dt, aim):
        if self.windup > 0:
            self.windup = max(0, self.windup - dt)
            if self.windup == 0:
                volley = directions(self.pattern, self.attack_phase, self.aim)
                self.timer = 2.6 if self.attack_phase == 2 else 3.1
                self.cycle += 1
                return volley
            return []
        self.timer = max(0, self.timer - dt)
        if self.timer == 0:
            self.pattern = self.cycle % 2
            self.attack_phase = 2 if self.hp <= 50 else 1
            self.aim = aim
            self.windup = 1.25 if self.pattern == 0 else 1.7
        return []


for attack_phase in (1, 2):
    for pattern in (0, 1):
        for aim in (0, math.pi / 2, -math.pi, 2.7):
            rays = directions(pattern, attack_phase, aim)
            assert len(rays) == ((3 if attack_phase == 1 else 5) if pattern == 0 else (10 if attack_phase == 1 else 12))
            assert all(math.isclose(x*x + y*y, 1) for x, y in rays)
            if pattern == 1:
                assert abs(sum(x for x, _ in rays)) < 1e-10
                assert abs(sum(y for _, y in rays)) < 1e-10
                # Ring has a gap at the locked boat bearing, rather than a directly aimed shell.
                assert max(x * math.cos(aim) + y * math.sin(aim) for x, y in rays) < 0.999

state = BossMirror()
assert not state.tick(1.2, 0)
warning = directions(state.pattern, state.attack_phase, state.aim)
state.hp = 40
assert not state.tick(.25, math.pi / 2)
assert state.aim == 0 and state.attack_phase == 1
assert state.tick(1.0, math.pi / 2) == warning
assert not state.tick(3.1, 2)
assert state.pattern == 1 and state.attack_phase == 2
assert len(state.tick(1.7, 0)) == 12
assert not state.tick(2.6, 0)
assert len(state.tick(1.25, 1)) == 5
for dt in (1/120, 1/60, 1/20, .2):
    state = BossMirror()
    fires = []
    time = 0
    while time < 30:
        time += dt
        volley = state.tick(dt, time)
        if volley:
            fires.append((time, len(volley)))
    assert fires[0][0] >= 1.2 + 1.25 - 1e-9
    assert [count for _, count in fires] == [3 if i % 2 == 0 else 10 for i in range(len(fires))]
    assert all(b[0] - a[0] >= 3.1 + 1.25 - 1e-9 for a, b in zip(fires, fires[1:]))
print('PASS: boss boundaries, frozen warnings, phase transition, alternating volleys, ring gaps and pacing (not engine)')
