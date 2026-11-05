"""Static CPU/GPU spectrum parity and finite-difference gradient checks.
Run from repository root: python3 tests/check_wave_spectrum.py
Not a substitute for compiling the Godot shader.
"""
import math
import random
import re
from pathlib import Path

shader = Path('shaders/boat_wave_spectrum.gdshaderinc').read_text()
cpu = Path('scripts/water_field.gd').read_text().split('func _spectrum_height', 1)[1].split('func _mega_h_cpu', 1)[0]
height, gradient = shader.split('vec2 spectrum_gradient', 1)
rows = []
for i in range(7):
    for source in (height, gradient, cpu):
        assert f'9.81 * k{i}' in source
    def numbers(source, pattern):
        return tuple(float(x) for x in re.search(pattern, source).groups())
    lengths = [numbers(s, rf'k{i} (?:=|:=) (?:WAVE_TAU|TAU) / ([\d.]+)')[0] for s in (height, gradient, cpu)]
    assert lengths[0] == lengths[1] == lengths[2]
    directions = [numbers(s, rf'd{i} (?:=|:=) (?:vec2|Vector2)\(d.x \* ([-\d.]+) - d.y \* ([-\d.]+)') for s in (height, gradient, cpu)]
    assert directions[0] == directions[1] == directions[2]
    weights = [numbers(s, rf'([\d.]+) \* cos\(k{i}')[0] for s in (height, cpu)]
    assert weights[0] == weights[1]
    assert f'{weights[0]:.8f} * k{i} * sin' in gradient
    phases = [numbers(s, rf'sqrt\(9.81 \* k{i}\) \* (?:time|t) \+ ([\d.]+)')[0] for s in (height, gradient, cpu)]
    assert phases[0] == phases[1] == phases[2]
    rows.append((math.tau / lengths[0], *directions[0], weights[0], phases[0]))

def sample(x, z, t):
    h = gx = gz = 0.0
    for k, dx, dz, w, phase in rows:
        a = k * (x * dx + z * dz) - math.sqrt(9.81 * k) * t + phase
        h += w * math.cos(a)
        gx -= w * k * math.sin(a) * dx
        gz -= w * k * math.sin(a) * dz
    return h, gx, gz

rng = random.Random(137)
for _ in range(200):
    x, z, t = [rng.uniform(-100, 100) for _ in range(3)]
    _, gx, gz = sample(x, z, t)
    e = 1e-4
    assert abs(gx - (sample(x+e, z, t)[0]-sample(x-e, z, t)[0])/(2*e)) < 1e-6
    assert abs(gz - (sample(x, z+e, t)[0]-sample(x, z-e, t)[0])/(2*e)) < 1e-6
assert abs(sum(r[3]**2 for r in rows) - (.75**2+.45**2+.22**2)) < 1e-7
print('OK: 7 CPU/GPU components match; 200 gradient checks; original RMS preserved.')
