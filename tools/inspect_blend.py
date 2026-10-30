import bpy, json, sys
from mathutils import Vector
bpy.ops.wm.open_mainfile(filepath=sys.argv[-1])
scene = bpy.context.scene
result = {"blender": bpy.app.version_string, "fps":scene.render.fps / scene.render.fps_base,
          "frame_start":scene.frame_start, "frame_end":scene.frame_end,
          "markers": [(m.name,m.frame) for m in scene.timeline_markers], "objects":[], "actions": []}
for o in bpy.data.objects:
    a=o.animation_data
    corners = [o.matrix_world @ Vector(v) for v in o.bound_box] if o.type=='MESH' else []
    bounds = [[round(min(v[i] for v in corners), 3),round(max(v[i] for v in corners), 3)] for i in range(3)] if corners else []
    result['objects'].append({'name':o.name,'type':o.type,'parent':o.parent.name if o.parent else None,
        'loc':[round(x,3) for x in o.location], 'dimensions':[round(x,3) for x in o.dimensions], 'bounds':bounds,
        'action':a.action.name if a and a.action else None,
        'nla':[[t.name,[(s.name,s.action.name if s.action else None, s.frame_start,s.frame_end) for s in t.strips]] for t in a.nla_tracks] if a else [],
        'material':[m.name for m in o.data.materials if m] if o.type=='MESH' else []})
for a in bpy.data.actions:
    result['actions'].append({'name':a.name,'range':list(a.frame_range),'slots':[(s.identifier,s.target_id_type) for s in a.slots]})
result["samples"] = {}
for frame in [0, 1, 39, 127, 120, 180, 239, 240, 270, 300, 330, 360]:
    scene.frame_set(frame)
    row = {}
    for name in ["ANCHOR_LIFT_CAGE_center.001", "ANCHOR_LIFT_door_center.001", "Cube", "Cube.001", "Cube.002", "LiftFloorPanel.004"]:
        obj = bpy.data.objects.get(name)
        if obj:
            row[name] = {"location": [round(v,3) for v in obj.matrix_world.translation],
                         "rotation": [round(v,3) for v in obj.matrix_world.to_euler()],
                         "local_rotation": [round(v,3) for v in obj.rotation_euler]}
    result["samples"][frame] = row
print('INSPECTION_JSON='+json.dumps(result,ensure_ascii=False))
scene.frame_start=0
scene.frame_end=360
scene.frame_set(0)
bpy.ops.object.select_all(action='DESELECT')
for obj in scene.objects:
    if obj.type not in {'CAMERA','LIGHT'} and obj.name not in {'GROUND_REF','WALK_LIMIT_area'}:
        obj.select_set(True)
bpy.ops.export_scene.gltf(filepath='assets/tower/animated_tower.glb', export_format='GLB', use_selection=True,
                          export_animation_mode='SCENE', export_frame_range=True, export_force_sampling=True)
print('GLB_EXPORTED')
