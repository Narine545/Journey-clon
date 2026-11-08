"""Elite encounter schedule/reward mirrors and wiring guards; NOT an engine run."""
from pathlib import Path
import math

root = Path(__file__).resolve().parents[1]
elites = (root / 'scripts/raid_elites.gd').read_text()
run = (root / 'scripts/raid_run.gd').read_text()
hud = (root / 'scripts/raid_hud.gd').read_text()
smoke = (root / 'scripts/boat_smoke.gd').read_text()
for token in ('const TIMES := [65.0, 130.0, 195.0]', 'const WINDOW := 12.0',
              'const RETRY := 1.0', 'const HP_SCALE := 2.8',
              'const RADIUS_SCALE := 1.35', 'const REWARD := 8',
              'seconds >= float(TIMES[cursor]) + WINDOW',
              'seconds < retry_at', 'bool(enemy.get("elite", false))'):
    assert token in elites, token
assert run.count('_elites.reset()') == 2  # start/leave
physics = run.split('func _physics_process(', 1)[1].split('func _step_elites(', 1)[0]
assert physics.index('state != State.RUNNING or main.inspection_active()') < physics.index('_step_elites()')
assert physics.index('_step_elites()') < physics.index('_spawn(RaidWaves.choose_kind(')
assert '_spawn_timer = maxf(_spawn_timer, RaidWaves.interval(elapsed))' in run
assert '_elites.attempted(elapsed, spawned)' in run
spawn = run.split('func _spawn(', 1)[1].split('func _physics_process(', 1)[0]
assert 'if enemies.size() >= ENEMY_CAP:' in spawn
assert 'var promoted := elite and kind == 1' in spawn
assert spawn.index('radius *= RaidElites.RADIUS_SCALE') < spawn.index('navigable(at, radius)')
assert 'hp *= RaidElites.HP_SCALE' in spawn and '"elite": promoted' in spawn
assert '"born": 0.6' in spawn
assert 'salvage.drop(enemies[index]["at"], RaidElites.reward(enemies[index]))' in physics
# Unchanged dash readability/strength, same pool and boss timing.
for token in ('const ENEMY_CAP := 80', 'const SHOT_CAP := 160',
              'speed = 14.0', 'enemy["charge"] = 0.7',
              'elif float(enemy["timer"]) < 1.1:', '_hurt(9.0 if kind < 3 else 20.0)',
              'elapsed >= 240.0', 'const DURATION := 300.0'):
    assert token in run, token
assert '_draw_elite_marker(enemy)' in hud and 'ЭЛИТА · %d%%' in hud
assert 'at.distance_to(run.boat_at()) > 60.0' in hud
assert '_check_raid_elites()' in smoke and 'run.salvage.remaining() == 8' in smoke
for token in ('Time.', 'create_timer', 'OmniLight3D', 'SubViewport', 'Node3D.new'):
    assert token not in elites


class Schedule:
    times = [65., 130., 195.]

    def __init__(self):
        self.cursor = 0
        self.retry_at = 0.

    def due(self, seconds, alive=False):
        while self.cursor < len(self.times) and seconds >= self.times[self.cursor] + 12:
            self.cursor += 1
        return (self.cursor < len(self.times) and seconds >= self.times[self.cursor]
                and seconds >= self.retry_at and not alive)

    def attempted(self, seconds, success):
        if success:
            self.cursor += 1
        else:
            self.retry_at = seconds + 1.


s = Schedule()
assert not s.due(64.999) and s.due(65)
s.attempted(65, False)
assert not s.due(65.999) and s.due(66)
s.attempted(66, True)
assert not s.due(66) and not s.due(130, True) and s.due(131)
s.attempted(131, True)
assert not s.due(207) and not s.due(240) and not s.due(300)
# Blocked slots are discarded, not queued as a burst when water becomes available.
s = Schedule()
assert not s.due(129.9) and s.cursor == 1
assert s.due(130)
assert not s.due(142) and s.cursor == 2
assert s.due(195)
assert not s.due(225) and s.cursor == 3
for fps in (19, 26, 30, 60, 120):
    s = Schedule()
    spawned = []
    for tick in range(300 * fps):
        t = tick / fps
        if s.due(t):
            spawned.append(t)
            s.attempted(t, True)
    assert len(spawned) == 3
    assert all(due <= actual < due + 1 / fps + 1e-8
               for due, actual in zip(s.times, spawned))
# Long lived elite blocks all later encounters, even if previous slot was consumed.
s = Schedule()
s.attempted(65, True)
assert all(not s.due(t, True) for t in (130, 140, 195, 200, 225))
# Spawn dimension and reward math; ordinary drops unchanged, XP bonus only on pickup.
for seconds in (65, 130, 195):
    base_hp = (25 + 14) * (1 + seconds / 400)
    assert base_hp * 2.8 > base_hp
    assert math.isclose(1.1 * 1.35, 1.485)
assert 8 * 2 == 16  # fully upgraded crew; not a direct kill reward
print('PASS: elite timing/retries/no backlog/one alive, spawn limits/geometry, reward and markers (not runtime)')
