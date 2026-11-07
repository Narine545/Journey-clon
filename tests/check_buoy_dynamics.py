"""Soft buoy contact / light-policy numerical mirrors, not a Godot render test."""
from pathlib import Path
import math
import random

root = Path(__file__).resolve().parents[1]
source = (root/'scripts/buoy_dynamics.gd').read_text()
ship = (root/'scripts/boat_vessel.gd').read_text()
marks = (root/'scripts/shoal_markers.gd').read_text()
main = (root/'scripts/boat_main.gd').read_text()
harbor = (root/'scripts/island_harbor.gd').read_text()
glare = (root/'shaders/buoy_glare.gdshader').read_text()
assert '"position": to, "yaw": new_yaw' in source and '"speed_factor": 1.0' in source
assert 'trial -=' not in source and 'penetration - yield_distance' not in source
assert '.limit_length(MAX_OFFSET)' not in source
assert 'normal.lerp(side * side_sign, 0.72)' in source
assert '15.0 if _near[i] else 13.0' in marks and 'or float(main.buoy_dynamics' not in marks
assert 'buoy_dynamics.overlaps(' not in ship
assert 'buoy_dynamics.step(delta)' in main and 'buoy_dynamics.render_nodes()' in main
for method, end in (('_physics_process', '_separate_trailer_from'),
                    ('_make_room_for_trailer', '_reset_trail'), ('_update_trailer', '_place_cable')):
    assert 'buoy_dynamics.resolve_motion(' in ship.split(f'func {method}(',1)[1].split(f'func {end}(',1)[0]
assert 'glare.set_shader_parameter("flash_strength", pulse)' in main
assert 'ShoalMarkers.flash_strength' in main and 'ShoalMarkers.flash_strength' in harbor
assert 'set_instance_custom_data(i, flash)' in marks and 'var _glows:' in marks
assert 'POSITION = PROJECTION_MATRIX' in glare and 'depth_draw_never' in glare
assert 'depth_test_disabled' not in glare and 'SCREEN_UV' not in glare
assert 'OmniLight3D.new()' not in marks


def add(a,b): return a[0]+b[0], a[1]+b[1]
def sub(a,b): return a[0]-b[0], a[1]-b[1]
def mul(a,s): return a[0]*s, a[1]*s
def dot(a,b): return a[0]*b[0]+a[1]*b[1]
def norm(a): return math.hypot(*a)
def unit(a): return mul(a,1/max(norm(a),1e-20))
def closest(p,at,yaw,half):
    heading = -math.sin(yaw), -math.cos(yaw)
    return add(at,mul(heading,max(-half,min(half,dot(sub(p,at),heading)))))


def sweep(start,end,yaw,half,radius):
    p = (0.,0.)
    motion = sub(end,start)
    steps = max(1,min(128,math.ceil(norm(motion)/.22)))
    hit = False
    for i in range(steps):
        at = add(start,mul(motion,(i+1)/steps))
        side = math.cos(yaw), -math.sin(yaw)
        gap = sub(p,closest(p,at,yaw,half))
        minimum = radius+.75+.003
        if norm(gap) >= minimum:
            continue
        hit = True
        normal = unit(gap) if dot(gap,gap)>1e-6 else side
        sign = 1 if dot(sub(p,at),side)>=0 else -1
        away = unit(add(mul(normal,.28),mul(side,sign*.72)))
        if dot(away,normal)<.15:
            away = normal
        p = add(p,mul(away,(minimum-norm(gap))/max(dot(away,normal),.15)))
        edge = closest(p,at,yaw,half)
        outward = sub(p,edge)
        if norm(outward)<minimum:
            p = add(edge,mul(unit(outward) if dot(outward,outward)>1e-6 else side,minimum))
        assert norm(sub(p,closest(p,at,yaw,half)))>=radius+.75-.001
    # Vessel travel is exactly the request, regardless of contact.
    return end,p,hit

rng = random.Random(812)
for half,radius in ((3.7,1.7),(1.6,1.5)):
    for sign in (-1,1):
        end,p,hit = sweep((-12*sign,0),(12*sign,0),math.pi/2,half,radius)
        assert hit and end == (12*sign,0) and abs(p[1])>radius*.5
    for _ in range(500):
        start=(-12,rng.uniform(-3,3)); target=(12,rng.uniform(-3,3))
        end,p,hit=sweep(start,target,rng.uniform(-math.pi,math.pi),half,radius)
        assert end==target

# Unclamped soft tether returns even from a large contact excursion.
for hz in (30,60,120):
    p,v=(4.,2.),(0.,0.)
    for _ in range(hz*10):
        count=max(1,math.ceil(60/hz)); dt=1/hz/count
        for _ in range(count):
            v=add(v,mul(add(mul(p,-5),mul(v,-3.4)),dt))
            p=add(p,mul(v,dt))
    assert norm(p)<.0001

# Tight proximity hysteresis: green immediately after 15m surface clearance.
near=False
for distance,expected in ((14,False),(12,True),(14,True),(15.1,False),(40,False)):
    near=distance<(15 if near else 13)
    assert near==expected
print('OK: yielding boat/trailer contacts, forward/reverse + 1000 sweep cases; unchanged vessel travel; '
      'soft tether return at 30/60/120Hz; prompt green reset; shared depth-tested flash halos. No engine run.')
