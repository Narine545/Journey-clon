"""Structural regression: bounded debug ordnance + actual water field impulses."""
from pathlib import Path
s = Path('scripts/sphere_mines.gd').read_text()
r = Path('scripts/raid_run.gd').read_text()
h = Path('scripts/raid_hud.gd').read_text()
w = Path('shaders/water_boat.gdshader').read_text()
shader = Path('shaders/sphere_mine.gdshader').read_text()
assert 'const CAPACITY := 4' in s
assert 'var enabled := false' in s
assert 'if (enabled or run.sphere_rank > 0) and cooldown <= 0.0:' in s
assert s.count('water.field.splash(at, 2.0)') == 2
assert 'age >= FUSE and not bool(mine["opened"])' in s
assert 'age >= FUSE + FIELD_TIME' in s
assert 'run.navigable(at, 1.0)' in s and 'run._hull_distance(at)' in s
assert 'run.stats.debug_used = true' in s
assert 'enemy["hp"] =' not in s and 'record_damage' not in s
assert 'sphere_mines.step(delta)' in r and r.count('sphere_mines.reset()') == 2
assert 'toggled.connect(run.sphere_mines.set_enabled)' in h
assert 'event_ring_height(w_pos.xz) * shore_wave_fade' in w
assert 'height += ring_amp * rg.w' in w
assert 'hint_screen_texture' not in shader and 'ALPHA =' in shader
print('PASS sphere mines: debug switch, bounded lifecycle, dual physical impulses, mesh height')
