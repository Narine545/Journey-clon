"""Numerical reference of SlickFilm, not an engine/shader/visual test.

Standard library only. Samples several original contours and passes a capsule
through their particles. Checks two main connected density regions, retained
mass, rounding and eventual reunion. Godot RNG is not reproduced bit-for-bit.
"""
import math
import random
from pathlib import Path


def rest_distance(p, time, seed):
    x, y = p
    distance = math.hypot(x + math.sin(time) * .1, y + math.cos(time * .8) * .1) - .96
    for i in range(4):
        angle = i * 2.399963 + seed * 2.7
        radius = .68 + .15 * math.sin(time + i)
        lobe = math.hypot(x - math.cos(angle) * radius, y - math.sin(angle) * radius)
        lobe -= .52 + .12 * math.sin(time * 1.2 + i * 2)
        h = max(.48 - abs(distance - lobe), 0) / .48
        distance = min(distance, lobe) - h * h * .48 * .25
    return distance


class FilmReference:
    def __init__(self, seed=17, time=17):
        rng = random.Random(seed)
        self.positions = []
        for row in range(-7, 8):
            for column in range(-7, 8):
                point = [(column + .5 * (row & 1)) * .3 + rng.uniform(-.025, .025),
                         row * .3 * .8660254 + rng.uniform(-.025, .025)]
                if rest_distance([x * .82 for x in point], time, seed) < -.025:
                    self.positions.append(point)
        self.origins = [point[:] for point in self.positions]
        self.velocities = [[0., 0.] for _ in self.positions]

    def step(self, hull_y=None, idle=0, width=1.6, speed=4, half_length=4.7):
        dt, count = .025, len(self.positions)
        density = [1.] * count
        forces = [[0., 0.] for _ in self.positions]
        pairs = []
        for i in range(count):
            for j in range(i):
                offset = [a - b for a, b in zip(self.positions[i], self.positions[j])]
                distance = math.hypot(*offset)
                if .62 <= distance < 1.8:
                    attraction = -10 * (1 - distance / 1.8)**2 / distance
                    for k in range(2):
                        forces[i][k] += offset[k] * attraction
                        forces[j][k] -= offset[k] * attraction
                if .0001 < distance < .62:
                    q = 1 - distance / .62
                    density[i] += q * q
                    density[j] += q * q
                    pairs.append((i, j, offset, distance, q))
        for i, j, offset, distance, q in pairs:
            pressure = max(-8, min(24, (density[i] + density[j] - 5.1) * 16))
            factor = (pressure * q + max(.3 * .72 - distance, 0) * 180) / distance
            for k in range(2):
                force = offset[k] * factor + (self.velocities[j][k] - self.velocities[i][k]) * q * 3
                forces[i][k] += force
                forces[j][k] -= force
        t = max(0, min(1, (idle - 1.5) / 3.5))
        recovery = t * t * (3 - 2 * t) * .9
        for i in range(count):
            for k in range(2):
                force = forces[i][k] + (self.origins[i][k] - self.positions[i][k]) * recovery
                self.velocities[i][k] = (self.velocities[i][k] + force * dt) * math.exp(-2.4 * dt)
            length = math.hypot(*self.velocities[i])
            if length > 2:
                self.velocities[i] = [v * 2 / length for v in self.velocities[i]]
            self.positions[i] = [p + v * dt for p, v in zip(self.positions[i], self.velocities[i])]
            if hull_y is not None:
                self.collide(i, hull_y, width, speed, dt, half_length)
            radius = math.hypot(*self.positions[i])
            if radius > 3.55:
                self.positions[i] = [x * 3.55 / radius for x in self.positions[i]]
                self.velocities[i] = [v * .3 for v in self.velocities[i]]

    def collide(self, i, center_y, width, speed, dt, half_length):
        # Representative forward pass along -Y, half-length 4.7.
        spine = half_length - width
        nearest = max(center_y - spine, min(center_y + spine, self.positions[i][1]))
        offset = [self.positions[i][0], self.positions[i][1] - nearest]
        distance, radius = math.hypot(*offset), width + .14
        if distance < radius:
            normal = [x / max(distance, .0001) for x in offset]
            if distance < .001:
                normal = [-1 if i & 1 else 1, 0]
            penetration = radius - distance
            for k in range(2):
                self.positions[i][k] += normal[k] * penetration * min(1, dt * 22)
                self.velocities[i][k] += normal[k] * min(3, penetration * 8) * dt * 6
            self.velocities[i][1] -= min(speed, 8) * dt * .3
        for side in (-1, 1):
            rx = self.positions[i][0] - radius * side
            ry = self.positions[i][1] - (center_y + spine)
            r2 = rx * rx + ry * ry
            if r2 < 6:
                factor = side * math.exp(-r2 * .7) / (r2 + .4) * min(speed, 8) * dt * .35
                self.velocities[i][0] -= ry * factor
                self.velocities[i][1] += rx * factor

    def raster(self):
        pixels = [0.] * (64 * 64)
        for px, py in self.positions:
            xx, yy = (px + 4) / .125 - .5, (py + 4) / .125 - .5
            for y in range(max(0, round(yy) - 4), min(64, round(yy) + 5)):
                for x in range(max(0, round(xx) - 4), min(64, round(xx) + 5)):
                    q = max(0, 1 - ((x - xx)**2 + (y - yy)**2) * .125**2 / .43**2)
                    pixels[y * 64 + x] += q**3
        return pixels


def components(pixels):
    solid = {i for i, density in enumerate(pixels) if density > .7}
    result = []
    while solid:
        stack = [solid.pop()]
        region = set(stack)
        while stack:
            i = stack.pop()
            for j in (i - 1, i + 1, i - 64, i + 64):
                if j in solid:
                    solid.remove(j)
                    region.add(j)
                    stack.append(j)
        result.append(region)
    return sorted(result, key=len, reverse=True)


for seed, phase in ((17, 17), (0, 0), (1, 3), (4, 9), (7, 4), (2, 14)):
    film = FilmReference(seed, phase)
    count = len(film.positions)
    initial_mass = sum(film.raster())
    assert 40 < count <= 128
    assert len(components(film.raster())) == 1
    for tick in range(70):
        for _ in range(2):
            film.step(hull_y=6 - tick * .2)
    for tick in range(40):
        film.step(idle=tick * .025)
    pixels = film.raster()
    parts = components(pixels)
    assert len(parts) == 2, (seed, [len(part) for part in parts])
    assert min(map(len, parts)) > 80  # Two substantial blobs, not one blob plus a speck.
    for part in parts:
        xs, ys = [i % 64 for i in part], [i // 64 for i in part]
        box_area = (max(xs) - min(xs) + 1) * (max(ys) - min(ys) + 1)
        assert len(part) / box_area < .9  # Not a filled rectangle / planar pair of doors.
    assert len(film.positions) == count
    assert abs(sum(pixels) / initial_mass - 1) < .005  # Discrete splat integration tolerance.
    for tick in range(40, 360):
        film.step(idle=tick * .025)
    assert len(components(film.raster())) == 1, seed
    assert all(math.isfinite(v) and abs(v) <= 3.55 for p in film.positions for v in p)
    assert len(film.positions) == count

# The shorter barge also deforms matter. A stopped existing hull remains a
# barrier; this does not mean standing near an untouched slick starts a solver.
barge = FilmReference(17, 17)
barge_count = len(barge.positions)
for tick in range(70):
    for _ in range(2):
        barge.step(hull_y=6 - tick * .2, width=1.4, half_length=2.8)
assert len(components(barge.raster())) == 2
assert len(barge.positions) == barge_count
stopped = FilmReference(17, 17)
for _ in range(100):
    stopped.step(hull_y=0, speed=0)
assert all(abs(point[0]) > 1.3 for point in stopped.positions)
assert len(stopped.positions) == barge_count

# Guard correspondence with production constants and transport/recovery paths.
source = Path('scripts/slick_film.gd').read_text()
for guard in ('const RESOLUTION := 64', 'const SPACING := 0.30', 'const KERNEL := 0.62',
              'const REST_DENSITY := 2.55', 'const STEP := 0.05', '-8.0, 24.0',
              '(-10.0 * pow(1.0 - distance / 1.8, 2.0))', 'exp(-2.4 * dt)',
              '.limit_length(2.0)', 'smoothstep(1.5, 5.0, idle)', 'Image.FORMAT_RGBAF',
              'pixels[slot + 1] += weight * origins[i].x', 'texture.update(image)',
              '_hulls[source_id] = [from, to, heading, half_length, half_width, speed]',
              'STEP * 2.0'):
    assert guard in source, guard
assert 'split_axis' not in source and 'split_bias' not in source
print('OK: 6 film passes + barge form two rounded density regions; mass, reunion, standing barrier, bounds.')
