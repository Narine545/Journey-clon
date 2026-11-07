"""Weather selection, bounded smooth fronts, independent clock + wiring.
Reference math only: does not run Godot or compile fog/sky shaders.
"""
import math
import random
from pathlib import Path

DAY = (.45, .30, .20, .05)
NIGHT = (.08, .12, .30, .50)
FOG = ((0, 0), (.03, .10), (.23, .42), (.78, 1))
CLOUD = ((0, .12), (.78, 1), (.25, .50), (.42, .72))


def smooth(a, b, x):
    t = max(0, min(1, (x-a)/(b-a)))
    return t*t*(3-2*t)


def weights(night):
    darkness = smooth(.25, .75, night)
    return tuple(a+(b-a)*darkness for a, b in zip(DAY, NIGHT))


def select(roll, night):
    cumulative = 0
    for index, probability in enumerate(weights(night)):
        cumulative += probability
        if roll < cumulative:
            return index
    return 3


class Weather:
    def __init__(self, seed):
        self.rng = random.Random(seed)
        self.fog = self.cloud = 0.
        self.state = 0
        self.hold = self.rng.uniform(45, 70)
        self.elapsed = self.duration = 0.
        self.start = self.target = (0., 0.)
        self.events = 0

    def advance(self, dt, night):
        remaining = max(0, dt)
        while remaining > 1e-6:
            if self.elapsed < self.duration:
                step = min(remaining, self.duration-self.elapsed)
                self.elapsed += step
                remaining -= step
                t = smooth(0, self.duration, self.elapsed)
                self.fog, self.cloud = (a+(b-a)*t for a,b in zip(self.start,self.target))
            else:
                step = min(remaining, self.hold)
                self.hold -= step
                remaining -= step
                if self.hold <= 1e-6:
                    self.state = select(self.rng.random(), night)
                    self.start = (self.fog, self.cloud)
                    self.target = (self.rng.uniform(*FOG[self.state]), self.rng.uniform(*CLOUD[self.state]))
                    self.duration = self.rng.uniform(18, 30)
                    self.elapsed = 0
                    self.hold = self.rng.uniform(80, 130) if self.state == 3 else self.rng.uniform(50, 100)
                    self.events += 1


for n in (0, .25, .45, .75, .88):
    p = weights(n)
    assert math.isclose(sum(p), 1)
    assert all(0 < value < 1 for value in p)
assert math.isclose(sum(weights(0)[2:]), .25)
assert math.isclose(sum(weights(.88)[2:]), .80)
for n, expected in ((0, DAY), (.88, NIGHT)):
    rng = random.Random(137)
    counts = [0]*4
    for _ in range(40000):
        counts[select(rng.random(), n)] += 1
    assert all(abs(count/40000-probability) < .012 for count, probability in zip(counts, expected))

# Same seeded weather, constant lighting time: no dependence on FPS.
for n in (0, .45, .88):
    coarse = Weather(845239)
    for _ in range(240):
        coarse.advance(5, n)
    for hz in (20, 60, 144):
        model = Weather(845239)
        previous = (model.fog, model.cloud)
        for _ in range(1200*hz):
            model.advance(1/hz, n)
            assert 0 <= model.fog <= 1 and 0 <= model.cloud <= 1
            # Smoothstep max derivative 1.5, smallest front 18 s.
            assert abs(model.fog-previous[0]) <= 1.5/18/hz+1e-7
            assert abs(model.cloud-previous[1]) <= 1.5/18/hz+1e-7
            previous = (model.fog, model.cloud)
        assert model.events == coarse.events and model.events > 5
        assert math.isclose(model.fog, coarse.fog, abs_tol=1e-6)
        assert math.isclose(model.cloud, coarse.cloud, abs_tol=1e-6)
# A late night still gets new weather. Changing lighting time alone cannot flash fog.
model = Weather(17)
model.advance(30, 0)
before = model.fog, model.cloud
model.advance(0, .88)
assert before == (model.fog, model.cloud)
model.advance(1200, .88)
assert model.events > 5

source = Path('scripts/sea_weather.gd').read_text()
main = Path('scripts/boat_main.gd').read_text()
world = Path('scripts/world.gd').read_text().split('func apply_boat_atmosphere',1)[1].split('func smoothf',1)[0]
shader = Path('shaders/boat_rme4_fog.gdshader').read_text()
for line in ('[0.45, 0.30, 0.20, 0.05]', '[0.08, 0.12, 0.30, 0.50]',
             'smoothstep(0.25, 0.75, night)', '_rng.randf_range(18.0, 30.0)',
             'smoothstep(0.0, _transition_time, _transition_elapsed)',
             'while remaining > 0.000001:', 'maxf(delta, 0.0)'):
    assert line in source, line
assert '_rng' not in source.split('func advance',1)[1]  # randomness only at front creation
assert 'weather.advance(delta, night01)' in main
assert '\tif OS.get_environment("JOURNEY_BOAT_SMOKE") != "1":\n\t\tweather.advance' in main
assert 'weather.fog_amount, weather.cloud_amount)' in main
assert 'set_shader_parameter("weather_fog", weather.fog_amount)' in main
assert 'coast.set_sand("fog_distance", haze_distance)' in main
assert 'water.set_param("fog_distance", haze_distance)' in main
assert 'weather_fog: float = 1.0' in world  # Other callers keep accepted baseline.
assert '_env.fog_density *= lerpf(0.35, 1.0, fog)' in world
assert '_env.volumetric_fog_density = lerpf(0.010, 0.018, n) * fog' in world
assert '_env.volumetric_fog_density = 0.0' in world  # No double density with RME4.
assert '"coverage", lerpf(lerpf(0.34, 0.48, n), 0.88, cloud)' in world
assert '* weather_fog;' in shader
assert 'if (diagnostic_volume)' in shader  # Diagnostic override deliberately bypasses climate.
assert 'main.weather.label()' in Path('scripts/boat_hud.gd').read_text()
assert 'KEY_F' not in main.split('func _unhandled_input',1)[1].split('func _process',1)[0]
print('OK: 25% day vs 80% night mist/fog selection, smooth bounded fronts, 20/60/144 Hz, frozen-clock weather, wiring.')
