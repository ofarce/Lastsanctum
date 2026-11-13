"""Version allégée du Tireur pour le jeu : assets/tireur_saurus.glb -> assets/tireur_saurus_lite.glb.

Décime chaque matériau vers un budget total de faces, réduit les textures et les exporte en JPEG.
Usage : blender -b --factory-startup --python blender/alleger_glb.py -- [--faces 7000] [--tex 512]
"""
import bpy, os, sys
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
FACES = int(argv[argv.index("--faces") + 1]) if "--faces" in argv else 7000
TEX = int(argv[argv.index("--tex") + 1]) if "--tex" in argv else 512

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=os.path.join(ROOT, "assets", "tireur_saurus.glb"))
meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
total = sum(len(o.data.polygons) for o in meshes)
ratio = min(1.0, FACES / total)

for o in meshes:
    # les petites pièces (rivets, lueurs) supportent mal la décimation : on les épargne un peu
    r = min(1.0, ratio * (1.6 if len(o.data.polygons) < 3000 else 1.0))
    d = o.modifiers.new("Decimate", "DECIMATE")
    d.decimate_type, d.ratio, d.use_collapse_triangulate = "COLLAPSE", r, True
    with bpy.context.temp_override(object=o, active_object=o):
        bpy.ops.object.modifier_apply(modifier=d.name)

for img in bpy.data.images:
    if img.size[0] > TEX:
        img.scale(TEX, TEX)

after = sum(len(o.data.polygons) for o in meshes)
out = os.path.join(ROOT, "assets", "tireur_saurus_lite.glb")
bpy.ops.export_scene.gltf(filepath=out, export_image_format="JPEG", export_jpeg_quality=82)
print(f"LITE {total} -> {after} faces, {os.path.getsize(out) / 1e6:.2f} Mo")
