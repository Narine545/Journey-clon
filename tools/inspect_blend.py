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
print('INSPECTION_JSON='+json.dumps(result,ensure_ascii=False))
