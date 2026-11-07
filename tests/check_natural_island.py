"""Numerical terrain/navigation contracts + static wiring; no renderer/engine claim."""
import math
from collections import deque
from pathlib import Path
from island_reference import height, distance, site, blocks_hull, BEARINGS, BERTH, BOAT_START

# Land and sea are each connected: no isolated fragments or landlocked bay.
step = 4
points = {(x, z) for x in range(-280, 621, step) for z in range(-450, 451, step)}
land = {p for p in points if distance(*p) > 0}
sea = points-land
for region in (land, sea):
    visited = {next(iter(region))}
    q = deque(visited)
    while q:
        x, z = q.popleft()
        for p in ((x-step, z), (x+step, z), (x, z-step), (x, z+step)):
            if p in region and p not in visited:
                visited.add(p)
                q.append(p)
    assert visited == region, ('disconnected land/sea', len(region-visited))
# NO land in the old edge-fade belt; the mesh boundary cannot crop dry land.
margin = min(min(x+280, 620-x, z+450, 450-z) for x, z in land)
assert margin > 90, margin
assert max(height(*p) for p in land) < 40
assert -height(*BOAT_START) >= 6
# Boat + trailer can enter together along a broad channel, then turn in the bowl.
for x in range(-160, 89, 2):
    for dz in range(-20, 21, 4):
        assert -height(x, -30+dz) >= 4.0, (x, dz)
for i in range(180):
    a = math.tau*i/180
    assert -height(88+20*math.cos(a), -30+20*math.sin(a)) > 5
    assert -height(88+32*math.cos(a), -30+32*math.sin(a)) > 2.8  # trailer/hull envelope
# Actual mooring pose: hull samples, trailer and pier clearance.
for x in [BERTH[0]+offset*.5 for offset in range(-10, 26)]:
    for z in (-40, -38, -36):
        assert -height(x, z) > 2.8, (x, z)
assert -height(*BERTH) > 4.5
assert not blocks_hull(*BERTH, math.pi/2)
assert not blocks_hull(BERTH[0]+9.3, BERTH[1], math.pi/2, 1.5, 2.8)
assert blocks_hull(110, -30, -math.pi/2)  # bow hits the jetty head
assert blocks_hull(137, -25, 0)           # longitudinal hull hits jetty side
# Check EACH headland, buoy and a safe seaward departure ray.
coords = []
for a in BEARINGS:
    tower, buoy, shore, normal = site(a)
    coords.append(tower)
    assert height(*tower) > .5
    assert -height(*buoy) >= 4.5
    for offset in range(0, 61, 3):
        assert -height(buoy[0]+normal[0]*offset, buoy[1]+normal[1]*offset) >= 4.4
    assert height(shore[0]-normal[0]*3, shore[1]-normal[1]*3) > 0
    assert height(shore[0]+normal[0]*3, shore[1]+normal[1]*3) < 0
assert coords[0][0] < 80 and coords[1][1] < -230 and coords[2][0] > 350 and coords[3][1] > 230
# No terrain cliffs hidden by the old rectangular fade. Sample land/beach gradients.
max_slope = 0
for x, z in land:
    h = height(x, z)
    slope = math.hypot((height(x+.5, z)-height(x-.5, z)),
                       (height(x, z+.5)-height(x, z-.5)))
    max_slope = max(max_slope, slope)
assert max_slope < 1.0, max_slope
# Verify shared CPU/GPU source and the new interaction, not only the mirror model.
coast = Path('scripts/coast.gd').read_text()
main = Path('scripts/boat_main.gd').read_text()
layout = Path('scripts/island_layout.gd').read_text()
harbor = Path('scripts/island_harbor.gd').read_text()
vessel = Path('scripts/boat_vessel.gd').read_text()
shader = Path('shaders/sand.gdshader').read_text()
assert 'return IslandLayout.height_at(Vector2(x, z))' in coast
assert 'BACK_DUNE' not in coast and 'shore_lut' not in shader
assert 'IslandLayout.BOAT_START.x' in main and 'coast.shore_x' not in main
assert main.count('"bearing":') == 4 and 'coast.ground_height(land.x, land.y)' in main
for a in BEARINGS:
    assert f'"bearing": {a}' in main
assert 'harbor.interact()' in main and 'harbor.moored' in vessel
assert 'blocks_hull(Vector2(next.x, next.z), rotation.y)' in vessel
assert '_harbor_blocks_trailer(next_xz)' in vessel
assert 'absf(main.boat.speed) > 1.2' in harbor
assert 'boat.set_trailer_enabled(true)' in harbor and 'moored = false' in harbor
assert 'w_pos.x - shore_x' not in shader and 'w_pos.y - sea_level' in shader
assert 'var channel := bay_distance - width - irregular' in layout
print(f'OK: connected natural island; land edge margin {margin}m; max land slope {max_slope:.2f}; '
      f'4 headlands/buoys, navigable bay, turn basin, boat+trailer berth, jetty blocking and mooring wiring.')
for a in BEARINGS:
    tower, buoy, _, _ = site(a)
    print(f'  {a:+.0f}°: tower ({tower[0]:.1f}, {height(*tower):.1f}, {tower[1]:.1f}); buoy depth {-height(*buoy):.1f}m')
