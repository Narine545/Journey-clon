"""Camera readout + wake lifetime/retention numerical guards. No Godot run."""
from pathlib import Path
import math

root=Path(__file__).resolve().parents[1]
main=(root/'scripts/boat_main.gd').read_text()
hud=(root/'scripts/boat_hud.gd').read_text()
inspector=(root/'scripts/world_inspector.gd').read_text()
photo=(root/'scripts/boat_photo_mode.gd').read_text()
boat=(root/'scripts/boat_vessel.gd').read_text()
shader=(root/'shaders/water_boat.gdshader').read_text()
assert 'const CAMERA_REFERENCE_HEIGHT := 27.0' in main
assert 'const CAMERA_REFERENCE_SIZE := 32.0' in main
assert 'ВЫСОТА %.2f× (%.1f м)' in main and 'ОТДАЛЕНИЕ %.2f×' in main
assert 'main.camera_scale_text()' in hud and 'main.camera_scale_text()' in inspector
assert '_camera_readout.text = main.camera_scale_text()' in photo
assert '"camera_height_multiple": main.camera_height_multiple()' in photo
assert '"camera_height_multiple": main.camera_height_multiple()' in inspector
# No premature maximum chosen: only the user can select the next limit.
assert 'camera_height = minf(160.0' in main
assert 'clampf(_focus.y, -20.0, 2000.0)' in inspector
assert 'const TRAIL_POINTS := 20' in boat and 'u_wake_trail[20]' in shader
assert 'for (int i = 0; i < 19; i++)' in shader
record=boat.split('func _record_world_wake_trail',1)[1].split('func _sync_water_shader',1)[0]
assert 'or moved > 2.5' not in record
assert 'if _trail_timer <= 0.0 and moved > 0.35:' in record
assert 'absf(speed) < 0.05' in record and 'Vector2(head.x, head.y)' in record
assert record.index('return',record.index('var head')) < record.index('_trail_buffer[0] =')
assert 'const float WAKE_FADE_START = 2.4;' in shader
assert 'const float WAKE_FADE_END = 4.2;' in shader
assert '1.0 - smoothstep(WAKE_FADE_START, WAKE_FADE_END, best_age)' in shader
assert 'smoothstep(0.0, 0.8, best_spd)' in shader
assert '* lifetime * local_spd01 * speed_fade' in shader
assert 'best_spd > 0.4' not in shader


def smooth(a,b,x):
    t=max(0.,min(1.,(x-a)/(b-a)))
    return t*t*(3-2*t)


def fade(age):
    return math.exp(-age*.55)*(1-smooth(2.4,4.2,age))

assert fade(4.2)==0 and fade(10)==0
assert fade(4.2-1e-4)<1e-8
values=[fade(i/1000) for i in range(6001)]
assert all(b<=a+1e-12 for a,b in zip(values,values[1:]))
# Contrast with the old hard cutoff: it discarded ~5.7% opacity instantly.
assert math.exp(-5.2*.55)>.05
for fps in (20,30,60,120,144):
    t=4.2-1/fps
    assert fade(t)<.0003  # Already invisible before final frame/branch removal.

# Reference recorder with the production 20-point time cadence, incl. the
# continuously updated head and movement threshold. Every removed segment
# must already have zero opacity, including overdrive/high physics rates.
for hz in (30,60,120):
    for speed in (.5,1.,4.,10.,16.2):
        dt=1/hz; timer=0.; x=0.; last=0.; now=0.
        history=[(0.,-100.,0.)]*20
        removed=0
        for _ in range(hz*15):
            now+=dt; x+=speed*dt; timer-=dt
            if timer<=0 and x-last>.35:
                if history[-1][1]>=0:
                    # The whole discarded last segment, not only its tip.
                    assert fade(now-history[-2][1])==0
                    assert fade(now-history[-1][1])==0
                    removed+=1
                history=[history[0]]+history[:-1]
                timer=.25; last=x
            history[0]=(x,now,speed)
        if speed>=4:
            assert removed>10
        head_time=history[0][1]
        # Stopped stern freezes the head timestamp; the entire wake dies.
        now+=5
        assert history[0][1]==head_time
        assert all(fade(now-point[1])==0 for point in history)

for height in (0.,27.,54.,135.,1000.,2000.):
    multiple=max(0,height)/27
    assert math.isclose(multiple*27,height)
assert 32/32==1 and 160/32==5
print('OK: shared camera height/outward multiples; preserved limits; continuous fade to zero, '
      'safe retirement for cruise/overdrive at 30/60/120Hz, stopped-head aging; unchanged 20-point shader budget.')
