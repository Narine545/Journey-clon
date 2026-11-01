import runpy
from mathutils import Vector
r=runpy.run_path('tools/export_nzp_game_rifle.py',run_name='__main__')
bpy=r['bpy']; rig=r['rig']; mesh=r['mesh']; cam=r['cam']; scene=r['scene']
rig.animation_data.action=bpy.data.actions['Kar98k.001']
weapon_groups={g.index for g in mesh.vertex_groups if g.name.lower() in {'rifle','bolt','slide','slideturn','popper','trigger','clip','round','rounds'}}
for frames,label in [(range(1,2),'idle'), (range(1,4),'shot'), (range(1,16),'reload')]:
    nearest_all=(float('inf'), None)
    nearest_gun=(float('inf'), None)
    for frame in frames:
        scene.frame_set(frame)
        obj=mesh.evaluated_get(bpy.context.evaluated_depsgraph_get());geo=obj.to_mesh()
        trans=cam.matrix_world.inverted()@obj.matrix_world
        for vertex in geo.vertices:
            pt=trans@vertex.co; depth=-pt.z
            candidate=(depth, (frame,tuple(round(float(c),4) for c in pt),vertex.index))
            if depth<nearest_all[0]:nearest_all=candidate
            if any(g.group in weapon_groups and g.weight>0.5 for g in vertex.groups) and depth<nearest_gun[0]: nearest_gun=candidate
        obj.to_mesh_clear()
    print('::notice::SPRING_DEPTH_%s all=%s gun=%s' % (label,nearest_all,nearest_gun))
