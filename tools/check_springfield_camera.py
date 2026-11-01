import runpy
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
import math
scene.frame_set(1)
obj=mesh.evaluated_get(bpy.context.evaluated_depsgraph_get()); geo=obj.to_mesh()
trans=cam.matrix_world.inverted()@obj.matrix_world
for label, predicate in [('gun', lambda v: any(g.group in weapon_groups and g.weight>0.5 for g in v.groups)), ('other', lambda v: not any(g.group in weapon_groups and g.weight>0.5 for g in v.groups))]:
    vals=[]; on=[]; f=1.30/14.285921
    for v in geo.vertices:
        if not predicate(v):continue
        pt=trans@v.co; d=-pt.z*f+0.18
        if d<=0.02:continue
        xp=pt.x*f*2.4/d/(math.tan(math.radians(37))*16/9)
        yp=pt.y*f*2.4/d/math.tan(math.radians(37))
        vals.append((xp,yp,d))
        if abs(xp)<=1 and abs(yp)<=1:on.append((xp,yp,d))
    def ext(i):
        if not vals:return None
        a=sorted(v[i] for v in vals);return [round(a[0],3),round(a[len(a)//2],3),round(a[-1],3)]
    print('::notice::SPRING_EXT_%s total=%s inside=%s x=%s y=%s depth=%s' %(label,len(vals),len(on),ext(0),ext(1),ext(2)))
obj.to_mesh_clear()
