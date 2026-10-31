#!/usr/bin/env python3
"""Make an isolated GLB trial and contact-free individual frames of NZ:P's Springfield.

Original sources and license: concepts/nzp_springfield/README.md.
No scripts embedded in the source blend are enabled or executed.
"""
from pathlib import Path
import json
import bpy
from mathutils import Vector

root = Path(__file__).resolve().parents[1]
folder = root / 'concepts/nzp_springfield'
bpy.context.preferences.filepaths.use_scripts_auto_execute = False
bpy.ops.wm.open_mainfile(filepath=str(folder / 'source/mesh.blend'), load_ui=False)
scene = bpy.context.scene
for image in bpy.data.images:
    for i in range(2):
        if image.name == f'v_spring.mdl_{i}.png':
            image.filepath = str(folder / f'source/texture_{i}.png')
            image.reload()

rig = bpy.data.objects['ArmsRig']
assert rig.animation_data and rig.animation_data.action
assert len(rig.data.bones) > 30
meshes = [o for o in bpy.data.objects if o.type == 'MESH' and o.parent == rig]
assert len(meshes) >= 2

# Record what actually deforms, rather than inferring animation names from labels.
report = {}
for act in bpy.data.actions:
    rig.animation_data.action = act
    samples = []
    for frame in [int(act.frame_range[0]), int((act.frame_range[0] + act.frame_range[1]) / 2), int(act.frame_range[1])]:
        scene.frame_set(frame)
        samples.append({'frame': frame, 'bones': {name: [round(x, 5) for row in rig.pose.bones[name].matrix for x in row]
                             for name in ('hand.r', 'hand.l', 'rifle', 'bolt', 'trigger')}})
    report[act.name] = samples
(folder / 'pose_samples.json').write_text(json.dumps(report, indent=2)+'\n')

# Export just the rigged meshes and rig, excluding original cameras, lights and unparented spare parts.
rig.animation_data.action = bpy.data.actions['Kar98k.001']
scene.frame_set(1)
bpy.ops.object.select_all(action='DESELECT')
for obj in [rig] + meshes:
    obj.select_set(True)
bpy.context.view_layer.objects.active = rig
bpy.ops.export_scene.gltf(filepath=str(folder / 'springfield_animated.glb'), export_format='GLB',
                          use_selection=True, export_animations=True, export_animation_mode='ACTIONS')

# Render four separate frames from the source's first-person arms camera.
scene.camera = bpy.data.objects['ArmsCamera']
scene.render.engine = 'CYCLES'
scene.cycles.samples = 20
scene.cycles.use_denoising = True
scene.render.resolution_x = 1000
scene.render.resolution_y = 750
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = 'PNG'
scene.render.film_transparent = False
scene.world.color = (0.2, 0.2, 0.2)
# Keep only the export content in the presentation; the original camera/lights remain.
for obj in bpy.data.objects:
    if obj.type == 'MESH' and obj not in meshes:
        obj.hide_render = True
for frame in (1, 13, 25, 38):
    scene.frame_set(frame)
    scene.render.filepath = str(folder / f'preview_frame_{frame:02d}.png')
    bpy.ops.render.render(write_still=True)
print('Trial GLB and four first-person frames produced')
