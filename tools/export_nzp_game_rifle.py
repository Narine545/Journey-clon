#!/usr/bin/env python3
"""Export NZ:P's rigged first-person Springfield and its framing reference camera."""
from pathlib import Path
import json
import bpy
import bmesh

ROOT = Path(__file__).resolve().parents[1]
source = ROOT / 'concepts/nzp_springfield/source'
out = ROOT / 'assets/weapons'
out.mkdir(exist_ok=True, parents=True)
bpy.context.preferences.filepaths.use_scripts_auto_execute = False
bpy.ops.wm.open_mainfile(filepath=str(source / 'mesh.blend'), load_ui=False)
for image in bpy.data.images:
    for i in range(2):
        if image.name == f'v_spring.mdl_{i}.png':
            image.filepath = str((out / 'nzp_springfield_texture.png') if i == 0 else (source / f'texture_{i}.png'))
            image.reload()
rig = bpy.data.objects['ArmsRig']
mesh = bpy.data.objects['ArmsMesh']
cam = bpy.data.objects['ArmsCamera']
scene = bpy.context.scene
# Subdivide only the rigged hands and round rigid rifle edges. The original
# armature and UV islands stay in place; Blender interpolates deform weights
# and UVs for newly created vertices. Avoid smoothing the entire firearm.
original_vertices = len(mesh.data.vertices)
original_polygons = len(mesh.data.polygons)
original_unweighted = sum(1 for vertex in mesh.data.vertices if not vertex.groups)
bm = bmesh.new()
bm.from_mesh(mesh.data)
bm.verts.ensure_lookup_table()
deform = bm.verts.layers.deform.active
assert deform is not None
hand_groups = {v.index for v in mesh.vertex_groups if any(token in v.name for token in
    ('hand.', 'thumb', 'pinkie', 'ring', 'middle', 'index'))}
rifle_group = mesh.vertex_groups['rifle'].index

def hand_weight(v):
    return sum(weight for group, weight in v[deform].items() if group in hand_groups)

hand_edges = [edge for edge in bm.edges if all(hand_weight(v) > 0.5 for v in edge.verts)]
assert len(hand_edges) > 50
bmesh.ops.subdivide_edges(bm, edges=hand_edges, cuts=1, smooth=0.18, use_grid_fill=True)
# Rigid rifle vertices are all controlled by the same bone. Only bevel edges
# wholly belonging to that bone; this must not affect hands or moving parts.
rifle_edges = [edge for edge in bm.edges if edge.is_manifold and
               all(v[deform].get(rifle_group, 0.0) > 0.99 for v in edge.verts) and
               edge.calc_face_angle(0.0) > 0.45]
assert len(rifle_edges) > 10
result = bmesh.ops.bevel(bm, geom=rifle_edges, offset=0.018, segments=2,
                         affect='EDGES', clamp_overlap=True)
for face in result['faces']:
    face.smooth = True
for v in bm.verts:
    # New bevel vertices should inherit the rigid bone, but verify rather than
    # letting a missing group leave visible geometry behind in animation.
    if not v[deform] and any(face in result['faces'] for face in v.link_faces):
        v[deform][rifle_group] = 1.0
for face in bm.faces:
    if all(hand_weight(v) > 0.5 for v in face.verts):
        face.smooth = True
bm.to_mesh(mesh.data)
bm.free()
mesh.data.update()
print('[SPRINGFIELD] verts %d -> %d; polygons %d -> %d' %
      (original_vertices, len(mesh.data.vertices), original_polygons, len(mesh.data.polygons)))
assert len(mesh.data.vertices) > original_vertices
assert sum(1 for vertex in mesh.data.vertices if not vertex.groups) <= original_unweighted, 'a refined vertex lost its bone weights'
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
          'original_frames_per_second': scene.render.fps / scene.render.fps_base,
          'original_vertices': original_vertices, 'refined_vertices': len(mesh.data.vertices),
          'original_polygons': original_polygons, 'refined_polygons': len(mesh.data.polygons)}
(out / 'nzp_springfield_framing.json').write_text(json.dumps(report, indent=2) + '\n')
print('[SPRINGFIELD]', report)
