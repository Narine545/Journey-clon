"""Numerical stock policy + static wiring. Not an engine/GDScript semantic test."""
import math
import random
import re
from pathlib import Path
from island_reference import height, site, BOAT_START

root = Path(__file__).resolve().parents[1]
source = (root/'scripts/resource_zones.gd').read_text()
main = (root/'scripts/boat_main.gd').read_text()
slick = (root/'scripts/resource_slick.gd').read_text()
inspector = (root/'scripts/world_inspector.gd').read_text()
arch = (root/'scripts/harbor_architecture.gd').read_text()
zones = [(float(x),float(z),float(r),int(k)) for x,z,r,k in re.findall(
    r'"center": Vector2\((-?[\d.]+), (-?[\d.]+)\), "radius": ([\d.]+), "kind": (\d)',source)]
assert len(zones)==4 and sorted(k for _,_,_,k in zones)==list(range(4))
assert 'const SLOTS_PER_ZONE := 3' in source
# The closest possible deposit is still outside the opening boat viewport.
assert all(math.dist((x,z),BOAT_START)-(r-6)>50 for x,z,r,_ in zones)

def permits(x,z):
    return not (-113<=x<198 and -132<=z<72)

beacons=[site(a)[1] for a in (-145,-78,12,100)]
reefs=[(-142,-64),(-186,-78),(-136,22)]
for a in (-40,45,138):
    _,_,shore,n=site(a);p=shore[0]+40*n[0],shore[1]+40*n[1]
    if -height(*p)>=3.5 and all(math.dist(p,b)>=25 for b in beacons):reefs.append(p)

# Rejection sampler fits the real terrain and never moves a zone with the boat.
def pick(rng,zone,others):
    x,z,r,_=zone
    for _ in range(64):
        a=rng.uniform(-math.pi,math.pi);d=math.sqrt(rng.random())*(r-6)
        p=x+math.cos(a)*d,z+math.sin(a)*d
        if not permits(*p) or -height(*p)<4:continue
        if any(math.dist(p,q)<12 for q in others):continue
        if any(math.dist(p,q)<11 for q in reefs):continue
        return p
    raise AssertionError('zone has insufficient usable water')
for seed in range(120):
    rng=random.Random(seed);points=[]
    for zone in zones:
        for _ in range(3):
            p=pick(rng,zone,points);points.append(p)
            assert math.dist(p,zone[:2])<=zone[2]-6+1e-8
    assert len(points)==12

# Controller policy model: partial stock cannot be shuffled or topped up;
# exhausted stock stays empty for its cooldown and while being observed.
class Slot:
    def __init__(self):
        self.mass=1.;self.depleted=False;self.was_depleted=False
        self.cooldown=0;self.due=False;self.moves=0;self.renewals=0
    def step(self,dt,observed=False):
        if self.depleted:
            if not self.was_depleted:self.was_depleted=True;self.cooldown=100
            else:self.cooldown-=dt
            if self.cooldown>0:return
        elif not self.due:return
        elif self.mass<1:self.due=False;return
        if observed:return
        if self.depleted:self.mass=1.;self.depleted=False;self.renewals+=1
        self.moves+=1;self.was_depleted=False;self.due=False
p=Slot();p.mass=.25;p.due=True
for _ in range(600):p.step(.5)
assert p.mass==.25 and p.moves==0
p=Slot();p.mass=0;p.depleted=True
for _ in range(200):p.step(.5)
assert p.depleted and p.renewals==0 # no old 35 second self-respawn
for _ in range(400):p.step(.5,observed=True)
assert p.depleted and p.renewals==0
p.step(.5)
assert p.mass==1 and p.renewals==1
p=Slot();p.due=True
for _ in range(300):p.step(.5,observed=True)
assert p.moves==0
p.step(.5)
assert p.moves==1 and p.mass==1

sample_source=source.split('func _pick_position',1)[1].split('func _unobserved',1)[0]
assert 'main.boat' not in sample_source and 'main.camera' not in sample_source
assert 'center + Vector2.from_angle' in sample_source
assert 'radius - 6.0' in sample_source and 'permits_slick(p)' in sample_source
assert '_stream_resources' not in main and 'SLICK_SPAWN_' not in main and '_slick_rng' not in main
assert 'resource_zones.setup(self)' in main and 'resource_zones.update(delta)' in main
assert 'ResourceSlick.new()' not in source.split('func update',1)[1]
assert 'if not _unobserved(current)' in source and 'if not _unobserved(candidate)' in source
assert 'Keep candidate' in source and 'if changed:' in source
assert 'remaining_mass >= 1.0' in slick.split('func can_zone_shuffle',1)[1].split('func renew_in_zone',1)[0]
renew=slick.split('func renew_in_zone',1)[1].split('func _process',1)[0]
assert 'if not zone_managed or not depleted:' in renew
process=slick.split('func _process',1)[1].split('func collect()',1)[0]
assert 'if zone_managed:\n\t\t\treturn\n\t\t_respawn -= delta' in process
assert 'main.resource_zones.zones' in inspector and 'main.resource_zones.summary()' in inspector
# Scan ALL GDScript, including smoke/debug scripts parsed when the game loads.
# A deleted member in an optional test script can prevent the whole scene loading.
removed_members = re.compile(r'\b(?:SLICK_RECYCLE_DISTANCE|SLICK_SPAWN_MIN|SLICK_SPAWN_MAX|_stream_resources|_slick_rng|_stream_cursor|_stream_timer)\b')
for gdscript in (root/'scripts').rglob('*.gd'):
    assert not removed_members.search(gdscript.read_text()), f'stale streaming member in {gdscript.name}'
# Exact reported warnings have their causes removed, not silenced globally.
assert 'material: Material, transform: Transform3D' not in arch
assert re.search(r'\bvar basis\b',arch) is None
assert '_v3(markers[selected]) if selected >= 0 else null' not in inspector
assert '"point": null' in inspector and 'report["point"] = _v3(markers[selected])' in inspector
print('OK: 120 seeds x 12 world-bound deposits; four regional pigments; bay/terrain/reef/spacing checks; '
      'cooldown, observation deferral and partial mass policy; no player-centred generation; warning causes removed.')
