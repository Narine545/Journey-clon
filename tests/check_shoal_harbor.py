"""Numeric reference/structural contracts only. Godot BoatSmoke tests are separate."""
import math
import struct
from pathlib import Path
from collections import defaultdict
from island_reference import height, site, BERTH, BOAT_START

ROOT = Path(__file__).resolve().parents[1]
DEPTH, GRID = 2.25, 12

def depth(p):
    return max(0, -height(*p))

def key(p):
    return round(p[0]*100), round(p[1]*100)

def lerp(a, b, t):
    return tuple(x+(y-x)*t for x,y in zip(a,b))

# Same marching-square topology used by ShoalMarkers; float32 field like Godot.
n = 75
values = [[struct.unpack('f', struct.pack('f', depth((-280+i*GRID, -450+j*GRID))-DEPTH))[0]
           for i in range(n+1)] for j in range(n+1)]
links, coords = defaultdict(list), {}
def link(a,b):
    ka,kb = key(a),key(b)
    if ka==kb:return
    coords[ka],coords[kb] = a,b
    links[ka].append(kb);links[kb].append(ka)

for j in range(n):
    for i in range(n):
        x,z = -280+i*GRID, -450+j*GRID
        corners = [(x,z),(x+GRID,z),(x+GRID,z+GRID),(x,z+GRID)]
        v = [values[j][i], values[j][i+1], values[j+1][i+1], values[j+1][i]]
        cross = [lerp(corners[k],corners[(k+1)%4],v[k]/(v[k]-v[(k+1)%4]))
                 for k in range(4) if (v[k]>0)!=(v[(k+1)%4]>0)]
        if len(cross)==2:link(*cross)
        elif len(cross)==4:
            same = (depth((x+6,z+6))>DEPTH)==(v[0]>0)
            for a,b in ((0,1),(2,3)) if same else ((0,3),(1,2)):link(cross[a],cross[b])
assert links and all(len(v)==2 for v in links.values())
start = next(iter(links));current,previous = start,None
path=[]
while True:
    path.append(coords[current]);a,b=links[current]
    nxt=a if a!=previous else b
    previous,current=current,nxt
    if current==start:break
    assert len(path)<=len(links)
assert len(path)==len(links), 'unexpected disconnected contours'
path.append(path[0])
length = sum(math.dist(a,b) for a,b in zip(path,path[1:]))
count = max(72,math.ceil(length/18))
points=[];segment=1;traversed=0
for i in range(count):
    target=length*(i+.37)/count
    while segment<len(path)-1 and traversed+math.dist(path[segment-1],path[segment])<target:
        traversed+=math.dist(path[segment-1],path[segment]);segment+=1
    p=lerp(path[segment-1],path[segment],(target-traversed)/math.dist(path[segment-1],path[segment]))
    for _ in range(5):
        x,z=p
        gx=depth((x+.5,z))-depth((x-.5,z));gz=depth((x,z+.5))-depth((x,z-.5))
        gl=math.hypot(gx,gz)
        if gl<.01:break
        correction=max(-4,min(4,(depth(p)-DEPTH)/gl))
        p=x-gx/gl*correction,z-gz/gl*correction
    assert abs(depth(p)-DEPTH)<.15
    points.append(p)
beacons = [site(a)[1] for a in (-145,-78,12,100)]
reefs = [(-142,-64),(-186,-78),(-136,22)]
for bearing in (-40,45,138):
    _,_,shore,normal=site(bearing)
    p=shore[0]+40*normal[0],shore[1]+40*normal[1]
    if depth(p)>=3.5 and all(math.dist(p,b)>=25 for b in beacons):reefs.append(p)
def profile(p):
    nearest=math.inf;dry=p;area=0
    for ix in range(-6,7):
        for iz in range(-6,7):
            off=ix*8,iz*8
            dist=math.hypot(*off)
            if dist>48:continue
            q=p[0]+off[0],p[1]+off[1]
            d=depth(q)
            if d<=.15 and dist<nearest:nearest,dry=dist,q
            elif .15<d<=2.6:area+=64
    width=48
    if math.isfinite(nearest):
        lo,hi=0,1
        for _ in range(12):
            mid=(lo+hi)/2
            if depth(lerp(p,dry,mid))<=.15:hi=mid
            else:lo=mid
        width=nearest*(lo+hi)/2
    return width,width+area*.003
candidates=[]
for i,p in enumerate(points):
    if any(math.dist(p,b)<16 for b in beacons):continue
    if any(math.dist(p,b)<14 for b in reefs):continue
    if any(math.dist(p,b)<r for b,r in [(BERTH,23),((-62,-55),18),((-62,-5),18)]):continue
    width,score=profile(p)
    candidates.append(dict(at=p,width=width,score=score,sector=min(11,int(i*12/count))))
candidates.sort(key=lambda x:x['score'],reverse=True)
accepted=[];widths=[]
def accept(c,separation):
    if any(math.dist(c['at'],p)<separation for p in accepted):return False
    accepted.append(c['at']);widths.append(c['width']);return True
for sector in range(12):
    for c in candidates:
        if c['sector']==sector and accept(c,55):break
median=candidates[len(candidates)//2]['score']
for c in candidates:
    if len(accepted)>=18:break
    if c['score']>=median*1.12:accept(c,72)
assert 10<=len(accepted)<=18
assert sum(widths)/len(widths)>sum(c['width'] for c in candidates)/len(candidates), 'must prioritise broader banks'
assert all(abs(depth(p)-2.25)<.15 for p in accepted)
# Predict the complete hull before grounding, including reverse travel.
def predicted(at,heading,speed):
    side=(-heading[1],heading[0]);travel=max(-12,min(28,speed*2.4))
    return min(depth((at[0]+heading[0]*(travel*t+i*4.4)+side[0]*j*1.6,
                      at[1]+heading[1]*(travel*t+i*4.4)+side[1]*j*1.6))
               for t in (0,.5,1) for i in (-1,0,1) for j in (-1,0,1))
for x,z in accepted:
    gx=depth((x+.5,z))-depth((x-.5,z));gz=depth((x,z+.5))-depth((x,z-.5))
    gl=math.hypot(gx,gz);normal=gx/gl,gz/gl
    assert predicted((x,z),(-normal[0],-normal[1]),7)<2.8
    assert predicted((x,z),normal,-5)<2.8
assert predicted(BOAT_START,(0,-1),0)>3.4
assert any(-80<x<160 and -120<z<60 for x,z in points), 'missing bay shallow boundary'
# The conservative no-slick region includes mouth/basin, with mesh-size guard.
def permits(p):
    x,z=p
    return not (-113<=x<198 and -132<=z<72)
assert permits(BOAT_START) and not permits(BERTH)
assert all(not permits((x,z)) for x in range(-100,160,5) for z in range(-100,41,5))
for x in range(-240,240,3):
    for z in range(-180,130,3):
        if permits((x,z)):
            # Entire 8m slick mesh is outside the protected unexpanded rectangle.
            assert x+4<=-105 or x-4>=190 or z+4<=-124 or z-4>=64
# Platform/circulation geometry MUST leave boat and trailer mooring footprint clear.
rects = [(109,-33,51,6),(118,-54,13,12),(131,-48,4,21)]
def blocked(x,z,yaw,half=4.4,radius=1.7):
    for offset in (-half,0,half):
        px,pz=x-math.sin(yaw)*offset,z-math.cos(yaw)*offset
        for rx,rz,rw,rh in rects:
            if math.hypot(px-max(rx,min(rx+rw,px)),pz-max(rz,min(rz+rh,pz)))<radius:return True
    return False
assert not blocked(*BERTH,math.pi/2)
assert not blocked(BERTH[0]+9.3,BERTH[1],math.pi/2,2.8,1.5)
for x in range(70,115):assert not blocked(x,-38,math.pi/2)
assert blocked(124,-49,0) and blocked(133,-37,0)
# A turn west of the berth stays away from all new construction.
for i in range(120):
    a=math.tau*i/120
    x,z=70+20*math.cos(a),-34+20*math.sin(a)
    assert depth((x,z))>3
    assert not blocked(x,z,math.pi-a)
# Camera framing at berth (same orthographic orientation, size32). Not occlusion/render proof.
x,y,z=21,26.2,30
l=math.sqrt(x*x+z*z);right=(z/l,0,-x/l)
full=math.sqrt(x*x+y*y+z*z)
up=(-x*y/(l*full),l/full,-z*y/(l*full))
for px in (119.25,128.75):
    for pz in (-52.8,-45.2):
        for py in (1.35,6.9):
            rel=(px-BERTH[0],py-.8,pz-BERTH[1])
            assert abs(sum(a*b for a,b in zip(rel,right)))<16*4/3 # fits 4:3 and default 16:9
            assert abs(sum(a*b for a,b in zip(rel,up)))<14
main=(ROOT/'scripts/boat_main.gd').read_text()
shoals=(ROOT/'scripts/shoal_markers.gd').read_text()
architecture=(ROOT/'scripts/harbor_architecture.gd').read_text()
harbor=(ROOT/'scripts/island_harbor.gd').read_text()
zones=(ROOT/'scripts/resource_zones.gd').read_text()
assert 'not IslandLayout.permits_slick(p)' in zones and 'resource_zones.setup(self)' in main
assert 'main.coast.water_depth' in shoals and 'const MAX_MARKERS := 18' in shoals
assert 'boat.speed * 2.4' in shoals and 'boat.has_trailer' in shoals
assert '3.4 if warning else 2.8' in shoals and 'main.harbor.moored' in shoals
assert '35.0 if _near[i] else 28.0' in shoals # local hull proximity + hysteresis, not global hazard state
assert 'OmniLight3D.new()' not in shoals # marks aren't a ring of costly point lights
assert 'mm.instance_count = transforms.size()' in architecture
assert 'Basis.from_euler(rot) * Basis.from_scale(size)' in architecture
assert '_gable(' in architecture and '_window(' in architecture
assert 'IslandLayout.HARBOR_APRON, IslandLayout.HARBOR_LINK' in harbor
print(f'OK: closed {length:.0f}m depth contour; {len(accepted)}/{count} bank-ranked marks at 2.25m; bay slick exclusion incl mesh; '
      'clear berth/trailer/departure/turn, nearby station camera bounds, warning wiring and batched architecture.')
