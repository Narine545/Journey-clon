"""Evolution guards and projectile/interception policy mirrors; not engine tests."""
from pathlib import Path

root = Path(__file__).resolve().parents[1]
run = (root / 'scripts/raid_run.gd').read_text()
hud = (root / 'scripts/raid_hud.gd').read_text() + (root / 'scripts/raid_combat_ui.gd').read_text()
smoke = (root / 'scripts/boat_smoke.gd').read_text()
assert 'damage >= 46.0 and reload_scale <= 0.78' in run
assert 'pulse_radius >= 23.0 and salvage.magnet_range >= 16.0' in run
assert 'not piercing_harpoon' in run and 'not resonant_pulse' in run
assert 'available.append(10)' in run and 'available.append(11)' in run
assert run.count('piercing_harpoon = false') == 2
assert run.count('resonant_pulse = false') == 2
assert '3 if weapon == 0 and piercing_harpoon else 1' in run
assert '"hits_left": clampi(hit_limit, 1, 3)' in run
assert '"hit_ids": []' in run
assert 'enemies[index]["combat_id"] = _next_enemy_id' in run
assert 'not shot["hit_ids"].has(enemy["combat_id"])' in run
assert 'shot["hit_ids"].append(enemies[victim]["combat_id"])' in run
assert 'shot["hits_left"] = int(shot["hits_left"]) - 1' in run
assert 'if int(shot["hits_left"]) <= 0:' in run
assert '01  НОС · ГАРПУН' in hud and 'run.resonant_pulse' in hud
assert '_check_raid_evolutions()' in smoke
pulse = run.split('func pulse()', 1)[1].split('func _offer_upgrade()', 1)[0]
assert 'if resonant_pulse:' in pulse
assert 'bool(shots[index]["hostile"])' in pulse
assert 'distance_to(shots[index]["at"]) <= pulse_radius' in pulse
assert 'pulse_cooldown > 0.0' in pulse and 'pulse_cooldown = 9.0' in pulse
assert 'state != State.RUNNING or main.inspection_active()' in pulse
# No damage multiplier/global boost accidentally applied to ordinary shots.
assert 'float(enemies[victim]["hp"]) - float(shot["power"])' in run

for damage in (22, 30, 38, 46, 54):
    for reload in (1, .88, .7744, .681472):
        eligible = damage >= 46 and reload <= .78
        assert eligible == (damage >= 46 and reload <= .7744)
for radius in (13, 18, 23, 28):
    for magnet in (10, 13, 16, 19):
        eligible = radius >= 23 and magnet >= 16
        assert eligible == ((radius - 13) // 5 >= 2 and (magnet - 10) // 3 >= 2)

# Stable IDs, not compacted array indices, track which targets a shot already hit.
for limit in (1, 3):
    enemies = [{'id': i, 'hp': 100} for i in range(4)]
    hit_ids = []
    remaining = limit
    for enemy in enemies:
        for _substep in range(20):
            if remaining > 0 and enemy['id'] not in hit_ids:
                enemy['hp'] -= 22
                hit_ids.append(enemy['id'])
                remaining -= 1
    assert [e['hp'] for e in enemies] == ([78, 100, 100, 100] if limit == 1 else [78, 78, 78, 100])
    assert len(hit_ids) == limit

seen = {10}
compacted_enemies = [{'id': 11, 'hp': 100}, {'id': 12, 'hp': 100}]
assert all(e['id'] not in seen for e in compacted_enemies)
# New entity can reuse an array slot, but must not reuse the removed enemy's ID.
compacted_enemies.insert(0, {'id': 13, 'hp': 100})
assert compacted_enemies[0]['id'] not in seen
shots = [{'hostile': True, 'distance': 5}, {'hostile': True, 'distance': 23},
         {'hostile': True, 'distance': 24}, {'hostile': False, 'distance': 0}]
remaining = [s for s in shots if not (s['hostile'] and s['distance'] <= 23)]
assert remaining == [shots[2], shots[3]]
print('PASS: evolution prerequisites, reset, piercing identity/limits and selective pulse interception (not engine)')
