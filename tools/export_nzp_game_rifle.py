#!/usr/bin/env python3
"""Export NZ:P's rigged first-person Springfield and its framing reference camera."""
from pathlib import Path
import json
import bpy

ROOT = Path(__file__).resolve().parents[1]
source = ROOT / 'concepts/nzp_springfield/source'
out = ROOT / 'assets/weapons'
out.mkdir(exist_ok=True, parents=True)
bpy.context.preferences.filepaths.use_scripts_auto_execute = False
bpy.ops.wm.open_mainfile(filepath=str(source / 'mesh.blend'), load_ui=False)
for image in bpy.data.images:
    for i in range(2):
        if image.name == f'v_spring.mdl_{i}.png':
            image.filepath = str(source / f'texture_{i}.png')
            image.reload()
rig = bpy.data.objects['ArmsRig']
mesh = bpy.data.objects['ArmsMesh']
cam = bpy.data.objects['ArmsCamera']
scene = bpy.context.scene
# Bound all evaluated animation poses in source-camera space. This lets the
# Godot view model be shrunk with its offset near railings without popping.
max_distance = 0.0
for action in bpy.data.actions:
    rig.animation_data.action = action
    for frame in range(int(action.frame_range[0]), int(action.frame_range[1]) + 1):
        scene.frame_set(frame)
        evaluated = mesh.evaluated_get(bpy.context.evaluated_depsgraph_get())
        geo = evaluated.to_mesh()
        transform = cam.matrix_world.inverted() @ evaluated.matrix_world
        for vertex in geo.vertices:
            max_distance = max(max_distance, (transform @ vertex.co).length)
        evaluated.to_mesh_clear()
rig.animation_data.action = bpy.data.actions['Kar98k.001']
scene.frame_set(1)
bpy.ops.object.select_all(action='DESELECT')
for obj in (rig, mesh, cam): obj.select_set(True)
bpy.context.view_layer.objects.active = rig
bpy.ops.export_scene.gltf(filepath=str(out / 'nzp_springfield.glb'), export_format='GLB', use_selection=True,
                          export_cameras=True, export_animations=True, export_animation_mode='ACTIONS')
report = {'max_source_camera_distance': max_distance, 'camera_angle_x_degrees': cam.data.angle_x * 180 / 3.141592653589793,
          'original_frames_per_second': scene.render.fps / scene.render.fps_base}
(out / 'nzp_springfield_framing.json').write_text(json.dumps(report, indent=2) + '\n')
print('[SPRINGFIELD]', report)
