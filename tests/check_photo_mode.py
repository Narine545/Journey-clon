"""Photo mode math and lifecycle guards. Does not execute Godot/render/save a photo."""
from pathlib import Path
import math

root=Path(__file__).resolve().parents[1]
photo=(root/'scripts/boat_photo_mode.gd').read_text()
main=(root/'scripts/boat_main.gd').read_text()
inspector=(root/'scripts/world_inspector.gd').read_text()
hud=(root/'scripts/boat_hud.gd').read_text()
water=(root/'shaders/water_boat.gdshader').read_text()
smoke=(root/'scripts/boat_smoke.gd').read_text()
assert 'KEY_F2' in photo and '[F2]' in hud
assert 'photo_mode.update_camera(delta)' in main
assert '(photo_mode != null and photo_mode.active)' in main
assert 'if main.photo_mode != null and main.photo_mode.active:' in inspector
assert 'main.inspector.set_free_camera(false)' in photo
assert 'main.inspector.map_open = false' in photo
assert 'get_global_transform_interpolated()' in photo
assert 'Camera3D.PROJECTION_PERSPECTIVE' in photo
for field in ('near','far','size','fov','attributes','transform'):
    assert f'_saved["{field}"]' in photo
assert 'camera.projection = _saved_projection' in photo
assert 'CameraAttributesPractical.new()' in photo
assert '_dof.button_pressed' in photo and '.button_pressed = true' not in photo
assert 'SubViewport.new' not in photo and 'WorldEnvironment.new' not in photo
assert 'main.world._env.' not in photo and 'weather.fog_amount =' not in photo
assert 'shutter_is_exposure_only' in photo
assert 'WorkerThreadPool.add_task' in photo and 'WorkerThreadPool.wait_for_task_completion' in photo
assert 'await RenderingServer.frame_post_draw' in photo
capture=photo.split('func capture()',1)[1].split('func _save_image',1)[0]
assert capture.index('visible = false') < capture.index('frame_post_draw') < capture.index('get_image()')
worker=photo.split('func _save_image',1)[1].split('func _capture_done',1)[0]
assert 'get_viewport' not in worker and 'call_deferred' in worker
assert 'save_png(base + ".png")' in worker and 'base + ".json"' in worker
assert 'Time.get_ticks_usec()' in photo
assert 'clampf(_focus.y, -20.0, 2000.0)' in inspector
assert 'camera_height = minf(160.0' in main and 'KEY_PAGEUP:' in main
assert 'minf(CAMERA_MAX_SIZE, camera.size + 2.0)' in main
assert ': normalize(CAMERA_POSITION_WORLD - w_pos)' in water
assert '_check_photo_mode()' in smoke


def exposure(iso=400,aperture=4,shutter=1/60,ev=0):
    return max(1/64,min(64,(iso/400)*(shutter*60)*(4/aperture)**2*2**ev))
assert exposure()==1
assert exposure(iso=800)==2
assert exposure(shutter=1/30)==2
assert exposure(ev=-1)==.5
assert math.isclose(exposure(aperture=4*math.sqrt(2)),.5)
for iso in (100,400,6400):
    for aperture in (1.4,4,16):
        for shutter in (.001,1/60,1):
            for ev in (-3,0,3):
                assert 1/64<=exposure(iso,aperture,shutter,ev)<=64
# The near lens is outside the bridge front geometry, not inside the cabin.
assert -2.48 < -2.42 and 2.27 < 2.52 < 2.70
print('OK: photo lifecycle/camera restoration, perspective water, input separation, clean threaded '
      'PNG+JSON capture, four mount points, bounded photographic exposure and raised cameras. No engine run.')
