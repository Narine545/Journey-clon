#!/usr/bin/env python3
"""Inspect the untrusted upstream blend without enabling embedded scripts."""
from pathlib import Path
import json
import bpy

root = Path(__file__).resolve().parents[1]
folder = root / 'concepts/nzp_springfield'
bpy.context.preferences.filepaths.use_scripts_auto_execute = False
bpy.ops.wm.open_mainfile(filepath=str(folder / 'source/mesh.blend'), load_ui=False)

def animation_info(item):
    a = getattr(item, 'animation_data', None)
    if not a:
        return None
    return {'active_action': a.action.name if a.action else None,
            'nla_tracks': [{'name': t.name, 'mute': t.mute,
                            'strips': [{'name': s.name, 'action': s.action.name if s.action else None,
                                        'start': s.frame_start, 'end': s.frame_end} for s in t.strips]}
                           for t in a.nla_tracks],
            'drivers': len(a.drivers)}

report = {
    'blender_version': bpy.app.version_string,
    'file_version': list(bpy.data.version),
    'scenes': [{'name': s.name, 'fps': s.render.fps, 'fps_base': s.render.fps_base,
                'start': s.frame_start, 'end': s.frame_end, 'current': s.frame_current} for s in bpy.data.scenes],
    'objects': [{'name': o.name, 'type': o.type, 'visible': not o.hide_render,
                 'parent': o.parent.name if o.parent else None,
                 'vertices': len(o.data.vertices) if o.type == 'MESH' else None,
                 'polygons': len(o.data.polygons) if o.type == 'MESH' else None,
                 'materials': [s.material.name if s.material else None for s in o.material_slots],
                 'modifiers': [{'name': m.name, 'type': m.type,
                                'object': m.object.name if m.type == 'ARMATURE' and m.object else None}
                               for m in o.modifiers],
                 'bones': [b.name for b in o.data.bones] if o.type == 'ARMATURE' else None,
                 'shape_keys': [k.name for k in o.data.shape_keys.key_blocks] if o.type == 'MESH' and o.data.shape_keys else None,
                 'animation': animation_info(o),
                 'shape_key_animation': animation_info(o.data.shape_keys) if o.type == 'MESH' and o.data.shape_keys else None}
                for o in bpy.data.objects],
    'actions': [{'name': a.name, 'frame_start': a.frame_range[0], 'frame_end': a.frame_range[1],
                 'slots': [s.identifier for s in a.slots] if hasattr(a, 'slots') else []} for a in bpy.data.actions],
    'images': [{'name': i.name, 'filepath': i.filepath, 'exists': Path(bpy.path.abspath(i.filepath)).is_file(),
                'packed': bool(i.packed_file), 'size': list(i.size)} for i in bpy.data.images],
    'text_blocks': [t.name for t in bpy.data.texts],
    'libraries': [l.filepath for l in bpy.data.libraries],
}
(folder / 'inspection.json').write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
print(json.dumps(report, ensure_ascii=False, indent=2))
