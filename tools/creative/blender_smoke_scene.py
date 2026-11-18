"""Create a deterministic, temporary Blender scene for CI smoke testing."""
from __future__ import annotations

import sys
from pathlib import Path

import bpy
from mathutils import Vector


def material(name: str, color: tuple[float, float, float, float], roughness: float = 0.7):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = color
    mat.use_nodes = True
    shader = mat.node_tree.nodes.get("Principled BSDF")
    if shader:
        shader.inputs["Base Color"].default_value = color
        shader.inputs["Roughness"].default_value = roughness
    return mat


arguments = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
if not arguments:
    raise SystemExit("Expected output directory after --")
output_dir = Path(arguments[0]).resolve()
output_dir.mkdir(parents=True, exist_ok=True)

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene

# A simple bronze sphere and dark plinth are only a renderer smoke-test scene.
bpy.ops.mesh.primitive_uv_sphere_add(
    segments=48,
    ring_count=24,
    radius=1.0,
    location=(0.0, 0.0, 1.15),
)
orb = bpy.context.object
orb.name = "CI_Ember_Orb"
orb.data.materials.append(material("CI_Ember_Bronze", (0.72, 0.20, 0.055, 1.0), 0.32))
for polygon in orb.data.polygons:
    polygon.use_smooth = True

bpy.ops.mesh.primitive_cylinder_add(
    vertices=64,
    radius=0.9,
    depth=0.28,
    location=(0.0, 0.0, 0.12),
)
plinth = bpy.context.object
plinth.name = "CI_Stone_Plinth"
plinth.data.materials.append(material("CI_Charcoal_Stone", (0.075, 0.065, 0.06, 1.0), 0.88))

bpy.ops.mesh.primitive_plane_add(size=200, location=(0.0, 0.0, -0.04))
floor = bpy.context.object
floor.name = "CI_Ground"
floor.data.materials.append(material("CI_Backdrop", (0.018, 0.026, 0.045, 1.0), 0.95))

bpy.ops.object.camera_add(location=(3.7, -6.8, 3.1))
camera = bpy.context.object
camera.name = "CI_Camera"
camera.rotation_euler = (Vector((0.0, 0.0, 0.9)) - camera.location).to_track_quat("-Z", "Y").to_euler()
camera.data.lens = 55
scene.camera = camera

bpy.ops.object.light_add(type="AREA", location=(1.8, -3.5, 5.2))
key = bpy.context.object
key.name = "CI_Key_Light"
key.data.energy = 850
key.data.shape = "DISK"
key.data.size = 4.0

bpy.ops.object.light_add(type="AREA", location=(-3.0, 1.0, 2.6))
rim = bpy.context.object
rim.name = "CI_Rim_Light"
rim.data.energy = 1100
rim.data.color = (0.12, 0.32, 1.0)
rim.data.size = 3.0

scene.render.engine = "BLENDER_EEVEE_NEXT" if bpy.app.version >= (4, 2, 0) else "BLENDER_EEVEE"
scene.render.resolution_x = 640
scene.render.resolution_y = 360
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = "PNG"
scene.render.image_settings.color_mode = "RGBA"
scene.render.film_transparent = False
scene.render.filepath = str(output_dir / "blender-procedural-preview.png")
scene.camera.data.dof.use_dof = False
scene.render.image_settings.color_depth = "8"

if scene.world:
    scene.world.use_nodes = True
    background = scene.world.node_tree.nodes.get("Background")
    if background:
        background.inputs["Color"].default_value = (0.012, 0.018, 0.035, 1.0)
        background.inputs["Strength"].default_value = 0.35

# Save an editable QA scene alongside the rendered preview.
bpy.ops.wm.save_as_mainfile(filepath=str(output_dir / "blender-smoke-scene.blend"))
bpy.ops.render.render(write_still=True)
