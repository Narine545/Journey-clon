"""World-map inverse transforms, heightfield picking and source wiring.
No Godot execution, shader compilation, GUI or clipboard assertions.
"""
import math
from pathlib import Path


def world_to_map(point, origin, size, span=900, center=(170, 0)):
    return tuple(o+(p-(c-span/2))/span*s for p,o,s,c in zip(point,origin,size,center))


def map_to_world(point, origin, size, span=900, center=(170, 0)):
    return tuple(c-span/2+(p-o)/s*span for p,o,s,c in zip(point,origin,size,center))


for span in (900, 1800, 7200):
    for center in ((170, 0), (-600, 700), (3000, -2000)):
        for point in ((-280, -450), (620, 450), (170,0), (-700,300), (1200,-1200)):
            screen = world_to_map(point, (28,92), (600,600), span, center)
            back = map_to_world(screen, (28,92), (600,600), span, center)
            assert math.dist(back,point) < 1e-9
assert world_to_map((-280,-450),(28,92),(600,600)) == (28,92)
assert world_to_map((620,450),(28,92),(600,600)) == (628,692)
# +Z goes down, +X goes right.
a = world_to_map((170,0),(28,92),(600,600))
b = world_to_map((171,1),(28,92),(600,600))
assert b[0] > a[0] and b[1] > a[1]


def pick(origin, ray, height, far=8000):
    def surface(x,z):
        return max(0,height(x,z))
    length = math.sqrt(sum(v*v for v in ray))
    ray = tuple(v/length for v in ray)
    if ray[1] >= -1e-5 or origin[1] <= surface(origin[0],origin[2]):
        return None
    end = min(far, max(0, origin[1]/-ray[1])+250)
    previous = 0
    for step in range(1,321):
        t = end*step/320
        at = tuple(p+d*t for p,d in zip(origin,ray))
        if at[1] <= surface(at[0],at[2]):
            lo,hi = previous,t
            for _ in range(20):
                middle = (lo+hi)/2
                sample = tuple(p+d*middle for p,d in zip(origin,ray))
                if sample[1] > surface(sample[0],sample[2]):
                    lo = middle
                else:
                    hi = middle
            hit = tuple(p+d*(lo+hi)/2 for p,d in zip(origin,ray))
            return hit[0],surface(hit[0],hit[2]),hit[2]
        previous = t
    return None


flat = lambda x,z: -100
assert math.dist(pick((21,26.2,30),(-21,-26.2,-30),flat),(0,0,0)) < 1e-4
assert math.dist(pick((-100,200,0),(0,-1,0),flat),(-100,0,0)) < 1e-4
land = lambda x,z: 10
assert math.dist(pick((0,50,0),(0,-1,0),land),(0,10,0)) < 1e-4
assert pick((0,50,0),(1,0,0),flat) is None
assert pick((0,-5,0),(0,-1,0),flat) is None
assert pick((0,200,0),(0,-1,0),flat,far=50) is None

inspector = Path('scripts/world_inspector.gd').read_text()
main = Path('scripts/boat_main.gd').read_text()
vessel = Path('scripts/boat_vessel.gd').read_text()
for field in ('point','camera_position','camera_rotation_degrees','camera_size','night01',
              'weather_fog','weather_cloud','fog_box_size','volume_length','water_mesh_center',
              'distance_to_terrain_edge','ground_height','overview_without_fog','engine','gpu'):
    assert '"'+field+'"' in inspector, field
assert 'main.coast.sample_height(at.x, at.y)' in inspector
assert 'main.coast.height_at' not in inspector  # Analytical outside terrain != finite mesh.
assert 'await RenderingServer.frame_post_draw' in inspector
assert '"user://world_reports"' in inspector
assert 'save_png(base + ".png")' in inspector
assert 'FileAccess.open(base + ".json", FileAccess.WRITE)' in inspector
assert 'DisplayServer.clipboard_set' in inspector
assert 'main.boat.global_position =' not in inspector  # View-only navigation, no teleport.
assert 'main.weather.fog_amount =' not in inspector  # Override doesn't mutate climate.
assert '_saved_fog = main.world._env.fog_enabled' in inspector
assert 'main.world._env.volumetric_fog_enabled = _saved_volume' in inspector
assert 'set_clear_view(false)' in inspector.split('func _focus_marker',1)[1].split('func update_camera',1)[0]
assert 'minf(1800.0, main.camera.size * 1.18)' in inspector
assert 'Input.is_physical_key_pressed' in inspector
assert 'func inspection_active() -> bool:' in main
assert 'inspector.update_camera(delta)' in main
assert 'if not inspection_active():\n\t\t\t_stream_resources()' in main
assert 'if main != null and main.inspection_active()' in vessel
pump = vessel.split('func _update_pump',1)[1].split('func _update_trailer_pump',1)[0]
assert 'if main.inspection_active()' in pump and '_trailer_pump_progress = 0.0' in pump
assert 'KEY_F8' not in inspector
print('OK: world/map transforms, finite terrain/water picking, view-only controls, overrides restore, report/screenshot wiring.')
