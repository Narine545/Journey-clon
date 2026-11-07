"""Orthographic near-plane safety and projection invariance; no Godot renderer."""
from pathlib import Path
import math
import random
from island_reference import height

root=Path(__file__).resolve().parents[1]
source=(root/'scripts/boat_camera_framing.gd').read_text()
main=(root/'scripts/boat_main.gd').read_text()
inspector=(root/'scripts/world_inspector.gd').read_text()
assert 'camera_framing.setup(coast)' in main
assert 'camera_framing.fit_offset(_camera_focus' in main
assert 'main.camera_framing.fit_offset(_focus' in inspector
assert 'camera.near +' in source and 'camera.keep_aspect == Camera3D.KEEP_WIDTH' in source
assert 'coast._grid.max()' in source and 'coast.sample_height' in source
assert 'for row in range(5)' in source and 'for column in range(9)' in source
assert 'camera.projection != Camera3D.PROJECTION_ORTHOGONAL' in source
assert 'minf(160.0, camera.size + 2.0)' in main  # 5x retained, not hidden by a smaller zoom limit.
assert 'camera.near = 0.2' in main and 'camera.far = 1500.0' in main


def add(a,b): return tuple(x+y for x,y in zip(a,b))
def mul(a,k): return tuple(x*k for x in a)
def dot(a,b): return sum(x*y for x,y in zip(a,b))
def length(a): return math.sqrt(dot(a,a))
def unit(a): return mul(a,1/length(a))
def cross(a,b): return a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0]
ceiling=max(height(x,z) for x in range(-280,621,5) for z in range(-450,451,5))+3


def fit(focus,preferred,size,aspect,keep_width=False):
    back=unit(preferred); right=unit(cross((0,1,0),back)); up=unit(cross(back,right))
    hh=size/2; hw=hh*aspect
    if keep_width: hw=size/2; hh=hw/aspect
    floor=2+min(ceiling,max(0,size-32)*.5)
    distance=max(length(preferred),.2+(floor-focus[1]+up[1]*hh)/back[1])
    center=add(focus,mul(back,distance-.2))
    blocked=False
    for row in range(5):
        row_center=add(center,mul(up,-hh+2*hh*row/4))
        if row_center[1]>=ceiling+2: continue
        for col in range(9):
            p=add(row_center,mul(right,-hw+2*hw*col/8))
            if p[1]<max(0,height(p[0],p[2]))+2:
                blocked=True; break
        if blocked: break
    if blocked: distance=max(distance,.2+(ceiling+2-focus[1]+up[1]*hh)/back[1])
    return mul(back,distance),back,right,up,hw,hh


# The screenshots used the default 27m eye and size160, not increased pitch.
old_back=unit((21,26.2,30)); old_up=unit(cross(old_back,unit(cross((0,1,0),old_back))))
assert .88+26.2-old_up[1]*80<0  # Lower near rectangle was below sea even with no mountain.
rng=random.Random(618)
routes=[(114,-38),(-160,-30),(-105,-30),(0,-30),(-200,-100),(410,20),(180,320)]
while len(routes)<70:
    x,z=rng.uniform(-260,610),rng.uniform(-420,420)
    if height(x,z)<-1.7: routes.append((x,z))
count=0
for x,z in routes:
    focus=(x,.88,z)
    for size in (32,60,76,160):
        for aspect in (4/3,16/9,21/9):
            for lift in (12,26.2,160):
                preferred=(21,lift,30)
                offset,back,right,up,hw,hh=fit(focus,preferred,size,aspect)
                center=add(add(focus,offset),mul(back,-.2))
                # Dense independent grid, not just the production probes.
                for row in range(9):
                    for col in range(17):
                        p=add(add(center,mul(up,-hh+2*hh*row/8)),mul(right,-hw+2*hw*col/16))
                        assert p[1]>max(0,height(p[0],p[2]))+.1,(focus,size,aspect,lift,p)
                # Movement only on the view axis: no screen-space jump, zoom,
                # recenter or altered angle, even for raised terrain landmarks.
                shift=add(offset,mul(preferred,-1))
                assert abs(dot(shift,right))<1e-10 and abs(dot(shift,up))<1e-10
                for landmark in ((0,0,0),(215,28,115),(124,7,-49)):
                    before=add(landmark,mul(add(focus,preferred),-1))
                    after=add(landmark,mul(add(focus,offset),-1))
                    assert math.isclose(dot(before,right),dot(after,right),abs_tol=1e-9)
                    assert math.isclose(dot(before,up),dot(after,up),abs_tol=1e-9)
                count+=1
# Unzoomed open-water framing remains at its existing eye position.
assert length(add(fit((-160,.88,-30),(21,26.2,30),32,16/9)[0],(-21,-26.2,-30)))<1e-9
for aspect in (.75,4/3,16/9):
    offset,back,right,up,hw,hh=fit((114,.88,-38),(21,26.2,30),160,aspect,True)
    assert math.isclose(hw,80) and math.isclose(hh,80/aspect)
    assert .88+offset[1]-.2*back[1]-up[1]*hh>=2-1e-8
print(f'OK: {count} route/zoom/pitch/aspect near planes against dense terrain probes; '
      '5x coverage and orthographic projection invariant; default open-water view preserved. No engine run.')
