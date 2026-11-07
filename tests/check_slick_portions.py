"""Reference component removal + mass/inventory accounting. Not a Godot run."""
import math
import sys
from pathlib import Path
sys.dont_write_bytecode = True
from check_slick_fluid import FilmReference, components


def take_component(film, point):
    if not film.positions:
        return 0
    nearest = min(range(len(film.positions)), key=lambda i: math.dist(film.positions[i], point))

    def cell(p):
        return min(63, max(0, int((p[1]+4)*8))) * 64 + min(63, max(0, int((p[0]+4)*8)))

    regions = components(film.raster())
    chosen = next(region for region in regions if cell(film.positions[nearest]) in region)
    before = len(film.positions)
    keep = [i for i, p in enumerate(film.positions) if cell(p) not in chosen]
    film.positions = [film.positions[i] for i in keep]
    film.origins = [film.origins[i] for i in keep]
    film.velocities = [film.velocities[i] for i in keep]
    return (before-len(keep))/before


for seed, phase in ((17, 17), (0, 0), (1, 3), (4, 9), (7, 4), (2, 14)):
    film = FilmReference(seed, phase)
    initial_count = len(film.positions)
    for tick in range(70):
        for _ in range(2):
            film.step(hull_y=6-tick*.2)
    for tick in range(40):
        film.step(idle=tick*.025)
    assert len(components(film.raster())) == 2
    fraction = take_component(film, (-3, 0))
    remaining = 1-fraction
    assert .1 < fraction < .9
    assert 0 < len(film.positions) < initial_count
    assert len(components(film.raster())) == 1
    assert math.isclose(remaining, len(film.positions)/initial_count)
    # Split the remaining mass again. Its new portions must be relative to the
    # REMAINING amount, not to a newly-created full unit.
    count = len(film.positions)
    cut = count//2
    film.positions = [[(-1.4 if i < cut else 1.4) + (i % 4)*.2,
                       ((i if i < cut else i-cut)//4)*.2-.5] for i in range(count)]
    assert len(components(film.raster())) == 2
    smaller = remaining * take_component(film, (-3, 0))
    remaining -= smaller
    assert math.isclose(remaining, len(film.positions)/initial_count)
    last = remaining * take_component(film, (3, 0))
    assert not film.positions
    assert math.isclose(fraction+smaller+last, 1, abs_tol=1e-12)
    assert take_component(film, (0, 0)) == 0

# Density compression changes apparent area, but not quantity of matter.
film = FilmReference()
film.positions = [[-1.6+(i % 6)*.14, (i//6)*.14-.5] for i in range(50)]
film.positions += [[1.2+(i % 4)*.25, (i//4)*.25-.5] for i in range(20)]
film.origins = [p[:] for p in film.positions]
film.velocities = [[0, 0] for _ in film.positions]
assert math.isclose(take_component(film, (-3, 0)), 50/70)
assert len(film.positions) == 20

# Float64 stock stores fractional units. Recipes still consume whole batches.
def receive(stock, amount):
    if amount <= 0:
        return stock
    stock += amount
    return float(round(stock)) if abs(stock-round(stock)) < 1e-8 else stock

assert receive(receive(0, .6), .4) == 1
stock = 0
for _ in range(3):
    for i in range(79):
        stock = receive(stock, 1/79)
assert stock == 3
batches = int(stock/3)
assert batches == 1 and stock-batches*3 == 0
assert receive(.25, 0) == .25

film_source = Path('scripts/slick_film.gd').read_text()
resource = Path('scripts/resource_slick.gd').read_text()
vessel = Path('scripts/boat_vessel.gd').read_text()
main = Path('scripts/boat_main.gd').read_text()
hud = Path('scripts/boat_hud.gd').read_text()
assert 'func remove_component_near(point: Vector2) -> float:' in film_source
assert '_last_image.get_pixel(neighbor.x, neighbor.y).r >= 0.70' in film_source
assert 'float(removed) / float(positions.size())' in film_source
assert 'origins = remaining_origins' in film_source
assert 'rest_positions = positions.duplicate()' in film_source
assert 'persistent and idle > 3.5 and _hulls.is_empty()' in film_source
assert 'previous_texture.update(_last_image)' in film_source
assert 'var amount := remaining_mass * fraction' in resource
assert 'remaining_mass = maxf(0.0, remaining_mass - amount)' in resource
assert 'if remaining_mass >= 1.0:\n\t\t_reset_disturbance()' in resource
assert 'not _film.persistent and _film_blend <= 0.0' in resource
assert '_target.collect_portion(to)' in vessel
assert '_trailer_target.collect_portion(to)' in vessel
assert '_target.collect()' not in vessel
assert 'PackedFloat64Array([0.0, 0.0, 0.0, 0.0])' in main
assert 'func receive_resource(kind: int, amount: float = 1.0)' in main
assert 'raw[kind] += amount' in main
assert 'main.resource_amount_text(main.raw[i])' in hud
print('OK: connected portion only, repeated splits conserve mass, remainder persists, fractional stock and recipes.')
