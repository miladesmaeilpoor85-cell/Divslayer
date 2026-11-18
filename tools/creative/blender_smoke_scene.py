"""Build a first-pass Persian-fantasy relic concept in Blender for Divslayer."""
from __future__ import annotations

import sys
from pathlib import Path

import bpy


def material(
    name: str,
    color: tuple[float, float, float, float],
    *,
    metallic: float = 0.0,
    roughness: float = 0.5,
    emission: float = 0.0,
):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = color
    mat.use_nodes = True
    shader = mat.node_tree.nodes.get("Principled BSDF")
    if shader:
        shader.inputs["Base Color"].default_value = color
        shader.inputs["Metallic"].default_value = metallic
        shader.inputs["Roughness"].default_value = roughness
        if "Emission Color" in shader.inputs:
            shader.inputs["Emission Color"].default_value = color
            shader.inputs["Emission Strength"].default_value = emission
    return mat


def make_flame(name: str, points: list[tuple[float, float]], z_back: float, z_front: float, mat):
    count = len(points)
    vertices = [(x, y, z_front) for x, y in points] + [(x, y, z_back) for x, y in points]
    faces = [tuple(range(count)), tuple(reversed(range(count, count * 2)))]
    for index in range(count):
        nxt = (index + 1) % count
        faces.append((index, nxt, nxt + count, index + count))
    mesh = bpy.data.meshes.new(name + "Mesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.materials.append(mat)
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    bevel = obj.modifiers.new("Soft forged edges", "BEVEL")
    bevel.width = 0.025
    bevel.segments = 3
    obj.modifiers.new("Weighted corner normals", "WEIGHTED_NORMAL")
    return obj


args = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
if not args:
    raise SystemExit("Expected output directory after --")
out = Path(args[0]).resolve()
out.mkdir(parents=True, exist_ok=True)

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene

bronze = material("Antique Persian bronze", (0.30, 0.115, 0.035, 1.0), metallic=0.86, roughness=0.28)
gold = material("Hammered old gold", (0.78, 0.48, 0.15, 1.0), metallic=0.82, roughness=0.24)
dark = material("Charcoal patinated metal", (0.035, 0.045, 0.052, 1.0), metallic=0.72, roughness=0.36)
ember = material("Molten ember enamel", (0.8, 0.11, 0.018, 1.0), metallic=0.2, roughness=0.3, emission=0.35)
flame_gold = material("Inner flame gold", (1.0, 0.49, 0.055, 1.0), metallic=0.25, roughness=0.26, emission=0.65)

# Main medallion: forged bronze disk with a dark inset and two concentric rims.
bpy.ops.mesh.primitive_cylinder_add(vertices=64, radius=0.92, depth=0.24, location=(0.0, 0.0, 0.0))
medallion = bpy.context.object
medallion.name = "Flame Seal — forged bronze body"
medallion.data.materials.append(bronze)
bevel = medallion.modifiers.new("Rounded hammered edge", "BEVEL")
bevel.width = 0.075
bevel.segments = 4
medallion.modifiers.new("Weighted normals", "WEIGHTED_NORMAL")

bpy.ops.mesh.primitive_cylinder_add(vertices=64, radius=0.77, depth=0.028, location=(0.0, 0.0, 0.137))
inset = bpy.context.object
inset.name = "Dark inset enamel"
inset.data.materials.append(dark)
bevel = inset.modifiers.new("Inset bevel", "BEVEL")
bevel.width = 0.025
bevel.segments = 3
inset.modifiers.new("Inset normals", "WEIGHTED_NORMAL")

for radius, minor, z, material_slot, name in (
    (0.82, 0.045, 0.17, gold, "Outer gold rim"),
    (0.70, 0.018, 0.19, bronze, "Inner bronze fillet"),
):
    bpy.ops.mesh.primitive_torus_add(
        major_segments=64,
        minor_segments=12,
        location=(0.0, 0.0, z),
        major_radius=radius,
        minor_radius=minor,
    )
    ring = bpy.context.object
    ring.name = name
    ring.data.materials.append(material_slot)
    for polygon in ring.data.polygons:
        polygon.use_smooth = True

# A stylized, unmistakable flame silhouette rather than a generic sphere.
outer_flame = [
    (-0.35, -0.36), (-0.43, -0.12), (-0.34, 0.13), (-0.18, 0.38),
    (-0.10, 0.17), (0.04, 0.48), (0.13, 0.23), (0.32, 0.39),
    (0.40, 0.08), (0.34, -0.19), (0.20, -0.38), (0.0, -0.45),
]
inner_flame = [
    (-0.19, -0.27), (-0.24, -0.06), (-0.12, 0.15),
    (-0.03, 0.02), (0.08, 0.27), (0.13, 0.02),
    (0.21, -0.14), (0.11, -0.30), (0.0, -0.34),
]
make_flame("Ember-red flame", outer_flame, 0.19, 0.30, ember)
make_flame("Golden inner flame", inner_flame, 0.31, 0.37, flame_gold)

# Eight studs and small engraved-like bars around the rim.
for index in range(8):
    angle = index * 3.141592653589793 / 4.0
    x, y = 0.58 * __import__("math").cos(angle), 0.58 * __import__("math").sin(angle)
    bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=8, radius=0.045, location=(x, y, 0.205))
    stud = bpy.context.object
    stud.name = f"Rim stud {index + 1}"
    stud.scale = (1.0, 1.0, 0.48)
    stud.data.materials.append(gold)
    for polygon in stud.data.polygons:
        polygon.use_smooth = True

# Four radial marks give the icon a handcrafted seal motif.
for index in range(4):
    angle = index * 3.141592653589793 / 2.0
    bpy.ops.mesh.primitive_cube_add(size=1, location=(0.0, 0.0, 0.205))
    mark = bpy.context.object
    mark.name = f"Seal engraving {index + 1}"
    mark.location.x = 0.72 * __import__("math").cos(angle)
    mark.location.y = 0.72 * __import__("math").sin(angle)
    mark.rotation_euler.z = angle
    mark.scale = (0.055, 0.012, 0.012)
    mark.data.materials.append(gold)

# Camera is orthographic and faces the front of the medallion for a readable 2D-game icon.
bpy.ops.object.camera_add(location=(0.0, 0.0, 5.0))
camera = bpy.context.object
camera.name = "Relic icon camera"
camera.data.type = "ORTHO"
camera.data.ortho_scale = 2.36
camera.rotation_euler = (0.0, 0.0, 0.0)
scene.camera = camera

for name, location, energy, size, color in (
    ("Warm key", (1.8, -1.8, 3.2), 520, 3.0, (1.0, 0.72, 0.43)),
    ("Cool fill", (-2.1, 0.9, 2.6), 380, 2.5, (0.28, 0.45, 1.0)),
    ("Top softbox", (0.0, 2.3, 3.5), 300, 2.0, (1.0, 0.84, 0.62)),
):
    bpy.ops.object.light_add(type="AREA", location=location)
    light = bpy.context.object
    light.name = name
    light.data.energy = energy
    light.data.shape = "DISK"
    light.data.size = size
    light.data.color = color

scene.render.engine = "BLENDER_EEVEE_NEXT" if bpy.app.version >= (4, 2, 0) else "BLENDER_EEVEE"
scene.render.resolution_x = 512
scene.render.resolution_y = 512
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = "PNG"
scene.render.image_settings.color_mode = "RGBA"
scene.render.film_transparent = True
scene.render.filepath = str(out / "flame-seal-relic-blender.png")
scene.camera.data.dof.use_dof = False
scene.render.image_settings.color_depth = "8"

if scene.world:
    scene.world.use_nodes = True
    background = scene.world.node_tree.nodes.get("Background")
    if background:
        background.inputs["Color"].default_value = (0.025, 0.032, 0.048, 1.0)
        background.inputs["Strength"].default_value = 0.15

bpy.ops.wm.save_as_mainfile(filepath=str(out / "flame-seal-relic.blend"))
bpy.ops.render.render(write_still=True)
