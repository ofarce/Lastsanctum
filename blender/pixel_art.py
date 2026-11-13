"""Rendu pixel art du Tireur, à enchaîner après tireur_saurus.py (qui construit la scène) :

  blender -b --factory-startup --python blender/tireur_saurus.py --python blender/pixel_art.py -- --views none

Rend chaque vue en très basse résolution, sans anticrénelage, réduit les couleurs à une palette fixe,
ajoute un contour sombre puis agrandit au plus proche voisin. Sorties dans renders/pixel_*.png.
"""
import bpy, os, math
import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(bpy.data.filepath or __file__)))
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "renders")
scn = bpy.context.scene
RIG = bpy.data.objects["Tireur"]

PALETTE_HEX = """120d0c 1e1b1a 2c2826 3d3835 54504b 6e6a64 8f8a82 b3aea3 d6d2c8
4a2a1a 6e3e22 94562c 3a2414 5c3a20 7e5530 a07a3c
8c8170 b8ab92 ddd2b8 2a080b 3e0c10 4e1016 621820 741c26 8a2630 b03c40
c8641c f0a030 ffe08a""".split()
PAL = np.array([[int(h[i:i + 2], 16) for i in (0, 2, 4)] for h in PALETTE_HEX], dtype=np.float32) / 255
OUTLINE = np.array([0x0d, 0x09, 0x08], dtype=np.float32) / 255

for o in scn.objects:
    if o.name in ("Plane", "Sol") or (o.type == "MESH" and o.parent is None):
        o.hide_render = True
scn.render.film_transparent = True
scn.render.filter_size = 0.0
scn.view_settings.view_transform = "Standard"
scn.view_settings.look = "None"
scn.view_settings.exposure = -1.3
scn.camera.data.lens = 95
try:
    scn.eevee.taa_render_samples = 16
except Exception:
    pass

def render_small(view_deg, w, h, name):
    RIG.rotation_euler = (0, 0, math.radians(view_deg))
    scn.render.resolution_x, scn.render.resolution_y = w, h
    path = os.path.join(OUT, f"_raw_{name}.png")
    scn.render.filepath = path
    bpy.ops.render.render(write_still=True)
    img = bpy.data.images.load(path)
    a = np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4)[::-1]   # haut en premier
    bpy.data.images.remove(img); os.remove(path)
    return a

def pixelize(a):
    rgb, alpha = a[..., :3], a[..., 3] > 0.45
    flat = rgb.reshape(-1, 3)
    # légère hausse de contraste avant quantification, puis couleur de palette la plus proche
    flat = np.clip((flat - 0.5) * 1.12 + 0.5, 0, 1)
    d = ((flat[:, None, :] - PAL[None, :, :]) ** 2).sum(-1)
    q = PAL[d.argmin(1)].reshape(rgb.shape)
    # contour : pixel vide qui touche un pixel plein
    pad = np.pad(alpha, 1)
    near = pad[:-2, 1:-1] | pad[2:, 1:-1] | pad[1:-1, :-2] | pad[1:-1, 2:]
    edge = ~alpha & near
    out = np.zeros(a.shape, dtype=np.float32)
    out[alpha, :3], out[alpha, 3] = q[alpha], 1
    out[edge, :3], out[edge, 3] = OUTLINE, 1
    return out

def save(arr, name, scale, bg=None):
    big = arr.repeat(scale, 0).repeat(scale, 1)
    if bg is not None:
        base = np.ones_like(big); base[..., :3] = bg
        a = big[..., 3:4]
        big = np.concatenate([big[..., :3] * a + base[..., :3] * (1 - a), np.ones_like(a)], -1)
    h, w = big.shape[:2]
    img = bpy.data.images.new(name, w, h, alpha=True)
    img.pixels[:] = big[::-1].ravel()
    img.filepath_raw = os.path.join(OUT, name + ".png"); img.file_format = "PNG"; img.save()
    print("PIXEL", img.filepath_raw, w, "x", h)

BG = np.array([0.11, 0.105, 0.11], dtype=np.float32)
# héros 3/4 détaillé
save(pixelize(render_small(-40, 160, 200, "hero")), "pixel_tireur_34", 5, BG)
# planche 4 vues (sprites de jeu)
views = [render_small(d, 96, 120, n) for d, n in ((0, "face"), (-40, "34"), (-90, "profil"), (180, "dos"))]
sheet = np.concatenate([pixelize(v) for v in views], 1)
save(sheet, "pixel_tireur_planche", 5, BG)
save(np.concatenate([pixelize(v) for v in views], 1), "pixel_tireur_sprites", 1)
