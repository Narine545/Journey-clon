"""Boss UI tracks actual arrival and camera bearing, never changes combat."""
from pathlib import Path
import math
r = Path('scripts/raid_run.gd').read_text()
h = Path('scripts/raid_hud.gd').read_text()
assert 'var boss_arrived_at := -1.0' in r
assert 'if kind == 3:\n\t\t\tboss_arrived_at = elapsed' in r
assert 'run.elapsed - run.boss_arrived_at < 5.0' in h
assert 'camera.unproject_position(world_at)' in h
assert 'camera.is_position_behind(world_at)' in h
assert 'viewport.grow(-30.0).has_point(screen)' in h
assert 'ЦЕЛЬ: УНИЧТОЖИТЬ БОССА' in h
assert 'БОСС ВСТУПИЛ В БОЙ' in h
assert '_draw_boss_objective(enemy)' in h
body = h.split('func _draw_boss_objective')[1].split('func _draw_telegraphs')[0]
for forbidden in ('enemy["hp"] =', '_spawn(', 'boss_spawned =', 'Time.'):
    assert forbidden not in body
# Inset arrow remains on the safe rectangle boundary for all bearings.
for w,height in ((1280,720),(1920,1080),(800,600)):
    hx,hy=max(30,w/2-100),max(30,height/2-195)
    for a in range(360):
        x,y=math.cos(math.radians(a)),math.sin(math.radians(a))
        t=min(hx/max(abs(x),.0001),hy/max(abs(y),.0001))
        assert abs(x*t)<=hx+1e-6 and abs(y*t)<=hy+1e-6
print('PASS boss arrival banner, persistent objective and offscreen camera-bearing cue')
