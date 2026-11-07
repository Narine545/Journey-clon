"""Reef proximity/night flash policy mirror + wiring, not an engine run."""
import math
from pathlib import Path

root=Path(__file__).resolve().parents[1]
main=(root/'scripts/boat_main.gd').read_text()
smoke=(root/'scripts/boat_smoke.gd').read_text()
setup=main.split('func _build_reefs()',1)[1].split('func _reef_signal_clearance',1)[0]
update=main.split('func _update_reef_signals()',1)[1].split('func _add_cyl',1)[0]
clearance=main.split('func _reef_signal_clearance',1)[1].split('func _update_reef_signals',1)[0]
assert setup.index('for i in range(locations.size())') < setup.index('var warn_mat :=')
assert '"signal_material": warn_mat' in setup and '"signal_phase":' in setup
assert 'BuoyDynamics.add_glare(r_node, 2.08' in setup
assert 'OmniLight3D.new()' not in setup+update
assert 'smoothstep(0.25, 0.45, night01)' in update
assert '24.0 if was_near else 20.0' in update
assert 'ShoalMarkers.flash_strength' in update
assert '5.5 * pulse' in update and '"flash_strength", pulse' in update
assert 'weather.fog_amount' not in update and 'camera.' not in clearance
assert 'boat.has_trailer and boat._trailer != null' in clearance
assert '3.7' in clearance and '1.6' in clearance
assert '_update_reef_signals()' in main.split('func _process',1)[1]
assert '_check_reef_signals()' in smoke


def smooth(a,b,x):
    t=max(0.,min(1.,(x-a)/(b-a)))
    return t*t*(3-2*t)


def flash(t,phase=0):
    t=(t+phase)%1.05
    return max(smooth(0,.025,t)*(1-smooth(.12,.18,t)),
               smooth(.26,.285,t)*(1-smooth(.38,.44,t)))


def signal(night,distance,time,was_near=False):
    dusk=smooth(.25,.45,night)
    near=distance<(24 if was_near else 20)
    pulse=flash(time)*dusk*(1-smooth(20,24,distance)) if near else 0
    return near,.08*dusk+5.5*pulse,pulse

for distance in (-2,0,5,19,21,25,100):
    for frame in range(126):
        for near in (False,True):
            _,emission,halo=signal(0,distance,frame/60,near)
            assert emission==halo==0  # Even in fog, day means no emission/glare.
for night in (.45,.6,.88):
    _,peak,halo=signal(night,10,.08)
    _,dark,_=signal(night,10,.6)
    assert peak>5 and halo==1 and dark<.1
    assert signal(night,100,.08,True)[1]<.1
assert signal(.35,10,.08)[1]<signal(.45,10,.08)[1]
assert signal(.25,10,.08)[1]==0
near=False
for distance,expected in ((25,False),(19,True),(22,True),(24.1,False)):
    near,_,_=signal(.88,distance,.08,near)
    assert near==expected


def hull_clearance(reef,at,yaw,half,radius):
    heading=(-math.sin(yaw),-math.cos(yaw))
    delta=(reef[0]-at[0],reef[1]-at[1])
    along=max(-half,min(half,sum(a*b for a,b in zip(delta,heading))))
    p=(at[0]+heading[0]*along,at[1]+heading[1]*along)
    return math.dist(reef,p)-radius-2.65

assert hull_clearance((0,0),(100,0),0,3.7,1.7)>24
assert min(hull_clearance((0,0),(100,0),0,3.7,1.7),
           hull_clearance((0,0),(15,0),0,1.6,1.5))<20
print('OK: individual reef lamps, hull/trailer proximity and hysteresis; zero daytime glow; '
      'twilight ramp, double flashes and bounded distant idle; no new point lights. No engine run.')
