"""Visual-only fireball integration and screen-plane heading math; not shader render proof."""
from pathlib import Path
import math
s = Path('scripts/raid_fireballs.gd').read_text()
r = Path('scripts/raid_run.gd').read_text()
h = Path('scripts/raid_hud.gd').read_text()
shader = Path('shaders/raid_fireball.gdshader').read_text()
assert 'batch.instance_count = RaidRun.SHOT_CAP' in s
assert 'not bool(shot["hostile"])' in s
assert '== RaidStats.Channel.NOSE' in s
assert 'run.fireball_enabled' in s and 'and run.effects_enabled' in s
assert '"effect_time", run.elapsed' in s
assert 'batch.visible_instance_count = count' in s
assert r.count('fireballs.reset()') == 2
assert '0.001 if fireballs.applies(shot) else 1.0' in r
assert 'fireballs.render(blend)' in r
assert 'ОГНЕННЫЙ НОС · СРАВНЕНИЕ' in h
assert 'shader_type spatial' in shader and 'blend_mix' in shader
assert 'Muhammad Mujtaba' in shader and 'Permission is hereby granted' in shader
assert 'TIME' not in shader and 'hint_screen_texture' not in shader
for forbidden in ('shot["power"] =', 'shot["at"] =', 'stats.', 'Light3D', 'RigidBody3D'):
    assert forbidden not in s
# Camera-plane projection preserves the on-screen heading for all planar directions.
n = (0., .8, .6)
def dot(a,b): return sum(x*y for x,y in zip(a,b))
def cross(a,b): return (a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0])
for index in range(360):
    a = math.radians(index)
    v = (math.cos(a), 0., math.sin(a))
    p = tuple(v[i]-n[i]*dot(v,n) for i in range(3))
    size = math.sqrt(dot(p,p))
    x = tuple(c/size for c in p)
    y = cross(n,x)
    assert abs(dot(x,n)) < 1e-9 and dot(x,v) > 0
    assert math.isclose(dot(y,y),1,abs_tol=1e-9)
    assert all(math.isclose(c,d,abs_tol=1e-9) for c,d in zip(cross(x,y),n))
print('PASS fireball scope/fallback, bounded batch, pause time and direction basis')
