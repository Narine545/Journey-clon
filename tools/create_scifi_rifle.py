#!/usr/bin/env python3
"""Generate an editable science-fiction rifle concept in Blender.

Standalone presentation asset; this script does not alter the Godot weapon.
All lengths are in metres. Blender 4.5+ with the bpy Python module is needed.
"""
from __future__ import annotations

import math
from pathlib import Path

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "concepts" / "sniper_rifle"
OUT.mkdir(parents=True, exist_ok=True)

bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
for datablock in bpy.data.materials:
    bpy.data.materials.remove(datablock)
scene = bpy.context.scene
scene.unit_settings.system = "METRIC"
scene.unit_settings.length_unit = "METERS"
scene.unit_settings.scale_length = 1.0
scene.render.engine = "CYCLES"
scene.cycles.samples = 32
scene.cycles.use_denoising = True
scene.render.resolution_x = 1600
scene.render.resolution_y = 900
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = "PNG"
scene.render.film_transparent = False
scene.world.color = (0.075, 0.075, 0.075)
scene.view_settings.view_transform = "AgX"

rifle = bpy.data.collections.new("RIFLE - editable parts")
scene.collection.children.link(rifle)
studio = bpy.data.collections.new("STUDIO - hide for modelling")
scene.collection.children.link(studio)


def move_to(obj, collection):
    for old in list(obj.users_collection):
        old.objects.unlink(obj)
    collection.objects.link(obj)
    return obj


def material(name, color, metallic=0.0, roughness=0.5, emission=None):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1.0)
    mat.use_nodes = True
    node = mat.node_tree.nodes.get("Principled BSDF")
    node.inputs["Base Color"].default_value = (*color, 1.0)
    node.inputs["Metallic"].default_value = metallic
    node.inputs["Roughness"].default_value = roughness
    if emission:
        node.inputs["Emission Color"].default_value = (*emission, 1.0)
        node.inputs["Emission Strength"].default_value = 1.7
    return mat


mat_frame = material("01 - graphite chassis", (0.055, 0.071, 0.079), 0.65, 0.42)
mat_shell = material("02 - ceramic sand armor", (0.42, 0.39, 0.29), 0.30, 0.52)
mat_panel = material("03 - slate blue plates", (0.095, 0.15, 0.17), 0.57, 0.38)
mat_metal = material("04 - gunmetal", (0.13, 0.15, 0.15), 0.86, 0.31)
mat_black = material("05 - rubber and grips", (0.025, 0.031, 0.034), 0.08, 0.70)
mat_edge = material("06 - brass markings", (0.62, 0.36, 0.105), 0.64, 0.36)
mat_glow = material("07 - status light", (0.12, 0.48, 0.48), 0.1, 0.32, (0.04, 0.55, 0.55))
mat_glass = material("08 - scope glass", (0.025, 0.18, 0.22), 0.75, 0.16)


def assign(obj, name, mat):
    obj.name = name
    obj.data.materials.append(mat)
    move_to(obj, rifle)
    return obj


def bevel(obj, amount=0.008, segments=2):
    modifier = obj.modifiers.new("Machined edges (editable)", "BEVEL")
    modifier.width = amount
    modifier.segments = segments
    modifier.limit_method = "ANGLE"
    # Geometry remains editable in the .blend; exporter applies modifiers.
    obj.modifiers.new("Weighted corner normals", "WEIGHTED_NORMAL")
    return obj


def box(name, location, dimensions, mat, edge=0.005):
    bpy.ops.mesh.primitive_cube_add(size=1, location=location)
    obj = bpy.context.object
    obj.dimensions = dimensions
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    assign(obj, name, mat)
    if edge:
        bevel(obj, edge)
    return obj


def profile(name, outline, width, mat, center_y=0.0, edge=0.004):
    """Extrude a side-view X/Z outline symmetrically along Y."""
    verts = [(x, center_y + y, z) for y in (-width / 2, width / 2) for x, z in outline]
    count = len(outline)
    faces = [tuple(reversed(range(count))), tuple(range(count, 2 * count))]
    faces += [(i, (i + 1) % count, (i + 1) % count + count, i + count) for i in range(count)]
    mesh = bpy.data.meshes.new(name + " mesh")
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    rifle.objects.link(obj)
    obj.data.materials.append(mat)
    if edge:
        bevel(obj, edge)
    return obj


def cylinder_x(name, center_x, z, radius, length, mat, vertices=24, y=0.0):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=length,
                                       location=(center_x, y, z), rotation=(0, math.pi / 2, 0))
    obj = bpy.context.object
    assign(obj, name, mat)
    for p in obj.data.polygons:
        p.use_smooth = True
    bevel(obj, 0.002, 2)
    return obj


def rod(name, a, b, width, depth, mat):
    delta = Vector(b) - Vector(a)
    obj = box(name, (Vector(a) + Vector(b)) * 0.5, (width, depth, delta.length), mat, 0.003)
    obj.rotation_mode = "QUATERNION"
    obj.rotation_quaternion = delta.to_track_quat("Z", "Y")
    return obj


# Main body: long faceted shell with inset panels rather than one rectangular box.
profile("Chassis / primary receiver", [(-0.27, 0.055), (-0.30, 0.22), (-0.20, 0.29),
        (0.22, 0.29), (0.34, 0.23), (0.35, 0.11), (0.27, 0.055)], 0.105, mat_frame, edge=0.009)
profile("Upper armor / swept top", [(-0.27, 0.19), (-0.23, 0.285), (-0.12, 0.315),
        (0.27, 0.315), (0.36, 0.26), (0.27, 0.215), (-0.07, 0.225)], 0.126, mat_shell, edge=0.008)
profile("Forward shroud", [(0.26, 0.115), (0.31, 0.245), (0.48, 0.245),
        (0.56, 0.205), (0.56, 0.13), (0.48, 0.095)], 0.108, mat_panel, edge=0.009)
for side in (-1, 1):
    y = side * 0.066
    profile("Receiver side panel %s" % side, [(-0.18, 0.11), (-0.20, 0.205), (0.20, 0.205),
            (0.26, 0.18), (0.22, 0.115)], 0.009, mat_panel, y, 0.003)
    profile("Angular cheek strip %s" % side, [(-0.15, 0.22), (-0.10, 0.27), (0.18, 0.27),
            (0.23, 0.22)], 0.009, mat_metal, side * 0.068, 0.002)
    for index in range(4):
        box("Shroud vent %s %02d" % (side, index), (0.34 + index * 0.043, side * 0.056, 0.19),
            (0.018, 0.006, 0.053), mat_black, 0.002)
    box("Side serial plate %s" % side, (0.04, side * 0.072, 0.171), (0.10, 0.005, 0.026), mat_black, 0.002)
    for i in range(3):
        box("Indicator %s %s" % (side, i), (0.018 + 0.027 * i, side * 0.076, 0.171),
            (0.012, 0.003, 0.006), mat_glow if i == 0 else mat_edge, 0.001)

# Barrel is layered, with an angular outer shroud and muzzle brake.
cylinder_x("Barrel / steel core", 0.61, 0.18, 0.022, 0.46, mat_metal)
cylinder_x("Barrel sleeve", 0.56, 0.18, 0.032, 0.22, mat_frame)
cylinder_x("Barrel band front", 0.695, 0.18, 0.040, 0.035, mat_shell)
cylinder_x("Barrel band rear", 0.47, 0.18, 0.038, 0.030, mat_metal)
cylinder_x("Muzzle / brake", 0.858, 0.18, 0.036, 0.105, mat_metal, 12)
cylinder_x("Muzzle / dark front", 0.913, 0.18, 0.028, 0.006, mat_black, 24)
for i in range(3):
    for side in (-1, 1):
        box("Muzzle port %s %s" % (side, i), (0.829 + 0.026 * i, side * 0.032, 0.18),
            (0.011, 0.006, 0.018), mat_black, 0.001)

# Receiver bottom, detachable magazine, and hand grip silhouette.
profile("Magazine well", [(-0.15, 0.10), (0.09, 0.10), (0.065, 0.015), (-0.13, 0.015)], 0.09, mat_metal)
profile("Magazine", [(-0.13, 0.025), (0.055, 0.025), (0.025, -0.15), (-0.11, -0.15), (-0.145, -0.11)], 0.077, mat_panel, edge=0.008)
box("Magazine base plate", (-0.045, 0.0, -0.157), (0.175, 0.09, 0.018), mat_black, 0.004)
for side in (-1, 1):
    for j in range(3):
        box("Magazine grip line %s %s" % (side, j), (-0.05, side * 0.0395, -0.035 - j * 0.031),
            (0.11, 0.003, 0.005), mat_metal, 0.001)
profile("Pistol grip", [(-0.28, 0.10), (-0.17, 0.065), (-0.22, -0.11),
        (-0.28, -0.19), (-0.35, -0.17), (-0.31, -0.06)], 0.075, mat_black, edge=0.009)
for side in (-1, 1):
    profile("Grip inset %s" % side, [(-0.278, 0.035), (-0.205, 0.035), (-0.255, -0.12),
            (-0.32, -0.14)], 0.004, mat_panel, side * 0.039, 0.002)
# Open trigger guard with a distinct small trigger.
rod("Trigger guard / front", (-0.15, 0, 0.025), (-0.12, 0, -0.06), 0.009, 0.018, mat_metal)
rod("Trigger guard / bottom", (-0.12, 0, -0.06), (-0.23, 0, -0.065), 0.009, 0.018, mat_metal)
rod("Trigger guard / rear", (-0.23, 0, -0.065), (-0.25, 0, 0.015), 0.009, 0.018, mat_metal)
rod("Trigger", (-0.195, 0, 0.04), (-0.185, 0, -0.035), 0.007, 0.012, mat_edge)

# Skeletal stock: deliberately open underneath, broad cheek rest, soft butt pad.
profile("Stock main beam", [(-0.68, 0.16), (-0.68, 0.24), (-0.27, 0.24),
        (-0.25, 0.17)], 0.075, mat_frame, edge=0.006)
profile("Stock cheek rest", [(-0.63, 0.235), (-0.59, 0.275), (-0.39, 0.275),
        (-0.34, 0.24)], 0.11, mat_shell, edge=0.008)
rod("Stock lower rail", (-0.64, 0, 0.015), (-0.30, 0, 0.09), 0.032, 0.058, mat_panel)
rod("Stock butt strut", (-0.65, 0, 0.02), (-0.65, 0, 0.18), 0.038, 0.065, mat_metal)
profile("Butt pad", [(-0.72, -0.005), (-0.72, 0.25), (-0.66, 0.235),
        (-0.66, 0.02)], 0.105, mat_black, edge=0.008)
profile("Stock rear side plate", [(-0.61, 0.10), (-0.61, 0.17), (-0.40, 0.17),
        (-0.36, 0.13), (-0.46, 0.10)], 0.085, mat_panel, edge=0.005)

# Low-mounted precision optic with large objective, turrets and coloured lens.
for x in (-0.12, 0.14):
    box("Scope mount %.2f" % x, (x, 0, 0.328), (0.07, 0.070, 0.055), mat_metal, 0.005)
box("Optic mounting rail", (0.0, 0, 0.307), (0.43, 0.06, 0.016), mat_black, 0.003)
cylinder_x("Scope / central housing", 0.01, 0.405, 0.049, 0.37, mat_frame)
cylinder_x("Scope / objective bell", 0.235, 0.405, 0.072, 0.13, mat_panel)
cylinder_x("Scope / objective outer rim", 0.302, 0.405, 0.074, 0.014, mat_metal)
cylinder_x("Scope / objective glass", 0.310, 0.405, 0.060, 0.004, mat_glass)
cylinder_x("Scope / eyepiece", -0.205, 0.405, 0.056, 0.09, mat_black)
cylinder_x("Scope / rear rim", -0.252, 0.405, 0.058, 0.012, mat_metal)
cylinder_x("Scope / rear glass", -0.259, 0.405, 0.043, 0.004, mat_glass)
for x in (-0.08, 0.08):
    cylinder_x("Scope ring %.2f" % x, x, 0.405, 0.054, 0.028, mat_metal)
bpy.ops.mesh.primitive_cylinder_add(vertices=20, radius=0.033, depth=0.045, location=(0.025, 0, 0.469))
assign(bpy.context.object, "Scope elevation turret", mat_metal)
bpy.ops.mesh.primitive_cylinder_add(vertices=20, radius=0.035, depth=0.012, location=(0.025, 0, 0.495))
assign(bpy.context.object, "Scope turret cap", mat_black)
box("Scope top marker", (0.025, 0, 0.502), (0.024, 0.004, 0.003), mat_edge, 0.001)

# Small structural and sci-fi accents, no textures or downloaded components.
for side in (-1, 1):
    for x in (-0.20, 0.24, 0.48):
        bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=0.006, depth=0.004,
             location=(x, side * 0.069, 0.245), rotation=(math.pi / 2, 0, 0))
        assign(bpy.context.object, "Fastener %.2f side %s" % (x, side), mat_metal)
    box("Armor signal %s" % side, (0.435, side * 0.058, 0.136), (0.055, 0.004, 0.009), mat_edge, 0.001)

# Display lighting is kept separate so artists can delete it without touching the rifle.
ground = material("STUDIO - backdrop", (0.095, 0.11, 0.12), 0.0, 0.9)
bpy.ops.mesh.primitive_plane_add(size=200, location=(0, 0, -0.25))
plane = bpy.context.object
plane.name = "STUDIO / floor"
plane.data.materials.append(ground)
move_to(plane, studio)


def area_light(name, position, energy, size, color):
    data = bpy.data.lights.new(name, "AREA")
    data.energy = energy
    data.shape = "DISK"
    data.size = size
    data.color = color
    obj = bpy.data.objects.new(name, data)
    studio.objects.link(obj)
    obj.location = position
    obj.rotation_euler = (Vector((0, 0, 0.1)) - obj.location).to_track_quat("-Z", "Y").to_euler()


area_light("STUDIO / key", (0.3, -2.0, 2.6), 420, 3.1, (1.0, 0.90, 0.76))
area_light("STUDIO / cool rim", (-0.7, 1.3, 1.5), 320, 2.4, (0.68, 0.82, 1.0))
area_light("STUDIO / front fill", (1.8, 0.3, 1.0), 120, 1.4, (1.0, 0.85, 0.65))
cam_data = bpy.data.cameras.new("STUDIO / camera")
cam = bpy.data.objects.new("STUDIO / camera", cam_data)
studio.objects.link(cam)
cam.location = (1.85, -2.8, 1.35)
target = Vector((0.08, 0, 0.11))
cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()
cam_data.type = "ORTHO"
cam_data.ortho_scale = 2.05
scene.camera = cam

# Save scene with all components, then export just the weapon for portability.
bpy.ops.object.select_all(action="DESELECT")
for obj in rifle.objects:
    obj.select_set(True)
bpy.context.view_layer.objects.active = rifle.objects.get("Chassis / primary receiver")
blend_path = OUT / "scifi_sniper_concept.blend"
bpy.ops.wm.save_as_mainfile(filepath=str(blend_path))
bpy.ops.export_scene.gltf(filepath=str(OUT / "scifi_sniper_concept.glb"), export_format="GLB", use_selection=True)
scene.render.filepath = str(OUT / "scifi_sniper_preview.png")
bpy.ops.render.render(write_still=True)
print("[RIFLE] Saved editable model, GLB and preview in", OUT)
