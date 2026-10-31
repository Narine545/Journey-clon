"""Temporary source mesh topology/weight inspection; embedded scripts disabled."""
import bpy
from collections import Counter, defaultdict
from pathlib import Path
from mathutils import Vector
bpy.context.preferences.filepaths.use_scripts_auto_execute = False
bpy.ops.wm.open_mainfile(filepath=str(Path('concepts/nzp_springfield/source/mesh.blend').resolve()),load_ui=False)
o=bpy.data.objects['ArmsMesh']; mesh=o.data
adj=defaultdict(set)
for e in mesh.edges:
 a,b=e.vertices;adj[a].add(b);adj[b].add(a)
comps=[]; todo=set(range(len(mesh.vertices)))
while todo:
 q=[todo.pop()]; vset=set(q)
 while q:
  i=q.pop()
  for j in adj[i]:
   if j in todo: todo.remove(j);vset.add(j);q.append(j)
 counts=Counter()
 for idx in vset:
  v=mesh.vertices[idx]
  if v.groups:
   g=max(v.groups,key=lambda x:x.weight);counts[o.vertex_groups[g.group].name]+=1
 lo=[min(mesh.vertices[i].co[k] for i in vset) for k in range(3)]
 hi=[max(mesh.vertices[i].co[k] for i in vset) for k in range(3)]
 comps.append((len(vset),counts.most_common(5),[round(x,2) for x in lo],[round(x,2) for x in hi]))
print('::notice::SPRING vertices=%d polygons=%d groups=%s' % (len(mesh.vertices),len(mesh.polygons),list(g.name for g in o.vertex_groups)))
for c in sorted(comps,reverse=True)[:22]:print('::notice::COMP '+str(c))
print('::notice::SPRING UV='+str([(u.name,len(u.data)) for u in mesh.uv_layers]))
