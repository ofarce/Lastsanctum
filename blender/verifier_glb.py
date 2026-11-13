"""Réimporte assets/tireur_saurus.glb dans une scène vide et le rend en 3/4 (renders/glb_check.png)."""
import bpy, os, math, sys
NAME = (sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "tireur_saurus")
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
bpy.ops.wm.read_factory_settings(use_empty=True)
scn = bpy.context.scene
bpy.ops.import_scene.gltf(filepath=os.path.join(ROOT, "assets", NAME + ".glb"))
for o in scn.objects:
    if o.parent is None:
        o.rotation_mode = "XYZ"; o.rotation_euler = (0, 0, math.radians(-40))
w = bpy.data.worlds.new("W"); scn.world = w; w.use_nodes = True
w.node_tree.nodes["Background"].inputs[0].default_value = (0.05, 0.05, 0.055, 1)
for name, loc, e in (("K", (-2.2, -2.6, 3.0), 550), ("R", (0.6, 3.0, 2.8), 650), ("F", (2.6, -1.8, 1.4), 160)):
    d = bpy.data.lights.new(name, "AREA"); d.energy = e; d.size = 2
    o = bpy.data.objects.new(name, d); scn.collection.objects.link(o); o.location = loc
    t = bpy.data.objects.new(name + "t", None); scn.collection.objects.link(t); t.location = (0, -0.15, 1.05)
    c = o.constraints.new("TRACK_TO"); c.target = t; c.track_axis = "TRACK_NEGATIVE_Z"; c.up_axis = "UP_Y"
cd = bpy.data.cameras.new("C"); cd.lens = 70
cam = bpy.data.objects.new("C", cd); scn.collection.objects.link(cam); scn.camera = cam
cam.location = (0, -6.2, 1.45)
c = cam.constraints.new("TRACK_TO"); c.target = scn.objects["Kt"]; c.track_axis = "TRACK_NEGATIVE_Z"; c.up_axis = "UP_Y"
scn.render.engine = "BLENDER_EEVEE"
scn.render.resolution_x, scn.render.resolution_y = 600, 800
scn.view_settings.view_transform = "AgX"; scn.view_settings.exposure = -1.0
scn.render.filepath = os.path.join(ROOT, "renders", NAME + "_check.png")
bpy.ops.render.render(write_still=True)
print("OBJETS", len([o for o in scn.objects if o.type == "MESH"]))
