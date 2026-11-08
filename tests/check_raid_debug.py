"""Debug toggles integration guards; camera/render and native smoke not executed."""
from pathlib import Path
root = Path(__file__).resolve().parents[1]
run = (root / 'scripts/raid_run.gd').read_text()
boat = (root / 'scripts/boat_vessel.gd').read_text()
hud = (root / 'scripts/raid_hud.gd').read_text()
smoke = (root / 'scripts/boat_smoke.gd').read_text()
for flag in ('debug_invulnerable', 'debug_clear_screen'):
    assert f'var {flag} := false' in run
    assert run.count(f'{flag} = false') == 2  # start/leave
assert 'if debug_invulnerable or _hurt_timer > 0.0:' in run
hurt = boat.split('func apply_hull_damage(', 1)[1].split('func _physics_process(', 1)[0]
assert 'main.raid.engaged() and main.raid.debug_invulnerable' in hurt
assert hurt.index('main.raid.debug_invulnerable') < hurt.index('hull_hp = maxf(')
clear = run.split('func _debug_clear_visible()', 1)[1].split('func _step_elites()', 1)[0]
assert 'not debug_clear_screen or state != State.RUNNING or main.inspection_active()' in clear
assert 'main.camera.is_position_in_frustum(world_at)' in clear
assert 'enemy["hp"] = 0.0' in clear
for forbidden in ('enemies.clear()', 'remove_at(', '_finish(', 'salvage.drop(', 'kind'):
    assert forbidden not in clear  # no direct deletion/double rewards or boss exemption
physics = run.split('func _physics_process(', 1)[1].split('func _debug_clear_visible()', 1)[0]
assert physics.index('_debug_clear_visible()') < physics.index('_move_enemies(delta)')
assert 'salvage.drop(enemies[index]["at"], RaidElites.reward(enemies[index]))' in physics
assert '_finish(State.WON)' in physics and 'elapsed >= DURATION' in physics
for text in ('БЕССМЕРТИЕ', 'ЗАЧИСТКА ЭКРАНА', 'set_pressed_no_signal(run.debug_invulnerable)',
             'set_pressed_no_signal(run.debug_clear_screen)'):
    assert text in hud
assert '_check_raid_debug()' in smoke
print('PASS: debug defaults/reset, all-damage gate, frustum/state guards and normal kill cleanup (not runtime)')
