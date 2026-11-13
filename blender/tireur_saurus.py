"""Tireur « Saurus » — modélisation procédurale, rendus 4 vues et export .glb.

Usage :  blender -b --factory-startup --python blender/tireur_saurus.py -- [--views face,34,profil,dos] [--glb]
Repère : Z vers le haut, le personnage regarde vers -Y, sa droite est en -X. Unités en mètres.
"""
import bpy, bmesh, math, os, sys
from mathutils import Vector, Matrix

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "renders")
argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
VIEWS = {"face": 0, "34": -40, "profil": -90, "dos": 180}
want = argv[argv.index("--views") + 1].split(",") if "--views" in argv else list(VIEWS)
EXPORT_GLB = "--glb" in argv
LITE = "--lite" in argv          # version basse définition pour le jeu
SFX = "_lite" if LITE else ""
LV = lambda n, mn=6: max(mn, n // 2) if LITE else n

# ---------------------------------------------------------------- scène
bpy.ops.wm.read_factory_settings(use_empty=True)
scn = bpy.context.scene
RIG = bpy.data.objects.new("Tireur", None)
scn.collection.objects.link(RIG)

# ---------------------------------------------------------------- matériaux
def mat(name, color, metal=0.0, rough=0.5, rust=0.0, emit=0.0, noise_scale=18.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (*color, 1)
    bsdf.inputs["Metallic"].default_value = metal
    bsdf.inputs["Roughness"].default_value = rough
    if emit:
        bsdf.inputs["Emission Color"].default_value = (*color, 1)
        bsdf.inputs["Emission Strength"].default_value = emit
    if rust:
        # usure : bruit qui mélange la couleur de base et une rouille brun-orangé, plus rugueuse
        tex = nt.nodes.new("ShaderNodeTexNoise")
        tex.inputs["Scale"].default_value = noise_scale
        tex.inputs["Detail"].default_value = 8
        ramp = nt.nodes.new("ShaderNodeValToRGB")
        ramp.color_ramp.elements[0].position = 0.18 + rust * 0.2
        ramp.color_ramp.elements[1].position = 0.26 + rust * 0.2
        mix = nt.nodes.new("ShaderNodeMix")
        mix.data_type = "RGBA"
        mix.inputs[6].default_value = (0.23, 0.11, 0.05, 1)
        mix.inputs[7].default_value = (*color, 1)
        nt.links.new(tex.outputs["Fac"], ramp.inputs["Fac"])
        nt.links.new(ramp.outputs["Color"], mix.inputs["Factor"])
        nt.links.new(mix.outputs[2], bsdf.inputs["Base Color"])
        inv = nt.nodes.new("ShaderNodeMapRange")
        inv.inputs["To Min"].default_value = 0.85
        inv.inputs["To Max"].default_value = rough
        nt.links.new(ramp.outputs["Color"], inv.inputs["Value"])
        nt.links.new(inv.outputs["Result"], bsdf.inputs["Roughness"])
        bump = nt.nodes.new("ShaderNodeBump")
        bump.inputs["Strength"].default_value = 0.25
        nt.links.new(tex.outputs["Fac"], bump.inputs["Height"])
        nt.links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])
    return m

M = {
    "steel": mat("Acier", (0.24, 0.235, 0.23), 0.9, 0.4, rust=0.25, noise_scale=25),
    "gun":   mat("AcierGuerre", (0.075, 0.07, 0.065), 0.85, 0.5, rust=0.45, noise_scale=25),
    "black": mat("NoirMat", (0.025, 0.025, 0.028), 0.4, 0.62),
    "rust":  mat("Rouille", (0.26, 0.13, 0.06), 0.6, 0.6, rust=0.3, noise_scale=40),
    "leath": mat("Cuir", (0.13, 0.07, 0.035), 0.0, 0.62),
    "leath2":mat("CuirSombre", (0.07, 0.04, 0.02), 0.0, 0.7),
    "ivory": mat("Ivoire", (0.55, 0.48, 0.37), 0.0, 0.92),
    "crim":  mat("Cramoisi", (0.12, 0.014, 0.018), 0.0, 0.9),
    "brass": mat("Laiton", (0.55, 0.38, 0.16), 1.0, 0.35),
    "amber": mat("LueurAmbre", (1.0, 0.45, 0.08), 0.0, 0.4, emit=12.0),
    "wood":  mat("Bois", (0.09, 0.05, 0.03), 0.0, 0.6),
}

# ---------------------------------------------------------------- primitives
def finish(o, m, bevel=0.0, smooth=False, parent=RIG):
    o.data.materials.append(M[m])
    o.parent = parent
    if bevel and not LITE:
        b = o.modifiers.new("Bevel", "BEVEL")
        b.width, b.segments, b.limit_method = bevel, 2, "ANGLE"
    if smooth:
        for p in o.data.polygons:
            p.use_smooth = True
        try:
            with bpy.context.temp_override(object=o, active_object=o, selected_objects=[o], selected_editable_objects=[o]):
                bpy.ops.object.shade_smooth_by_angle(angle=math.radians(40))
        except Exception:
            pass
    return o

def box(name, loc, size, m, rot=(0, 0, 0), bevel=0.006):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc, rotation=rot)
    o = bpy.context.object; o.name = name; o.scale = size
    bpy.ops.object.transform_apply(scale=True)
    return finish(o, m, bevel)

def cyl(name, loc, r1, r2, depth, m, rot=(0, 0, 0), verts=24, scale=(1, 1, 1), bevel=0.004):
    bpy.ops.mesh.primitive_cone_add(vertices=LV(verts), radius1=r1, radius2=r2, depth=depth, location=loc, rotation=rot)
    o = bpy.context.object; o.name = name; o.scale = scale
    bpy.ops.object.transform_apply(scale=True)
    return finish(o, m, bevel, smooth=True)

def seg(name, a, b, r1, r2, m, verts=20, squash=1.0, bevel=0.003):
    a, b = Vector(a), Vector(b)
    d = b - a
    bpy.ops.mesh.primitive_cone_add(vertices=LV(verts), radius1=r1, radius2=r2, depth=d.length, location=(a + b) / 2)
    o = bpy.context.object; o.name = name
    o.scale = (1, squash, 1)
    o.rotation_mode = "QUATERNION"
    o.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(d.normalized())
    bpy.ops.object.transform_apply(scale=True, rotation=True)
    return finish(o, m, bevel, smooth=True)

def sphere(name, loc, r, m, scale=(1, 1, 1)):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=LV(32), ring_count=LV(16), radius=r, location=loc)
    o = bpy.context.object; o.name = name; o.scale = scale
    bpy.ops.object.transform_apply(scale=True)
    return finish(o, m, smooth=True)


def loft(name, rings, m, verts=24, sub=2, dx=0.0):
    if LITE: verts, sub = max(8, verts * 2 // 3), max(0, sub - 1)
    """Volume organique : anneaux elliptiques (z, rx, ry, dy) reliés puis lissés en subdivision."""
    me = bpy.data.meshes.new(name); bm = bmesh.new(); R = []
    for z, rx, ry, dy in rings:
        R.append([bm.verts.new((dx + math.cos(i / verts * math.tau) * rx, dy + math.sin(i / verts * math.tau) * ry, z)) for i in range(verts)])
    for a, b in zip(R, R[1:]):
        for i in range(verts):
            j = (i + 1) % verts
            bm.faces.new((a[i], a[j], b[j], b[i]))
    bm.faces.new(R[0][::-1]); bm.faces.new(R[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    bm.to_mesh(me); bm.free()
    o = bpy.data.objects.new(name, me); scn.collection.objects.link(o)
    sd = o.modifiers.new("Sub", "SUBSURF"); sd.levels = sd.render_levels = sub
    for pl in me.polygons: pl.use_smooth = True
    return finish(o, m)

def shell(name, loc, r, m, axis=(0, 0, 1), cut=0.0, scale=(1, 1, 1), rot=(0, 0, 0), thick=0.01):
    """Coque d'armure : calotte de sphère (partie où dot(v, axis) > cut*r), épaissie et lissée."""
    me = bpy.data.meshes.new(name); bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=LV(32), v_segments=LV(16), radius=r)
    ax = Vector(axis).normalized()
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.dot(ax) < cut * r], context="VERTS")
    bm.to_mesh(me); bm.free()
    o = bpy.data.objects.new(name, me); scn.collection.objects.link(o)
    o.location, o.scale, o.rotation_euler = loc, scale, rot
    so = o.modifiers.new("Solid", "SOLIDIFY"); so.thickness = thick; so.offset = 1
    if not LITE:
        b = o.modifiers.new("Bevel", "BEVEL"); b.width, b.segments = thick * 0.4, 2; b.limit_method = "ANGLE"
    for pl in me.polygons: pl.use_smooth = True
    return finish(o, m)

def blade(name, pts, thick, m):
    """Plaque plate extrudée à partir d'un contour (liste de points 3D dans un plan)."""
    me = bpy.data.meshes.new(name); bm = bmesh.new()
    vs = [bm.verts.new(p) for p in pts]
    f = bm.faces.new(vs)
    bmesh.ops.recalc_face_normals(bm, faces=[f])
    n = f.normal.copy()
    ext = bmesh.ops.extrude_face_region(bm, geom=[f])
    bmesh.ops.translate(bm, vec=n * thick, verts=[v for v in ext["geom"] if isinstance(v, bmesh.types.BMVert)])
    bmesh.ops.translate(bm, vec=-n * thick / 2, verts=bm.verts[:])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    bm.to_mesh(me); bm.free()
    o = bpy.data.objects.new(name, me); scn.collection.objects.link(o)
    return finish(o, m, bevel=min(0.004, thick * 0.4))

def cloth_strip(name, ang, w, z0, z1, r0, r1, m, wave=0.022):
    """Lé de tunique : bande subdivisée qui s'évase et ondule, avec épaisseur."""
    me = bpy.data.meshes.new(name); bm = bmesh.new()
    rows, cols = 8, 4
    grid = []
    for i in range(rows + 1):
        t = i / rows
        z = z0 + (z1 - z0) * t
        r = r0 + (r1 - r0) * t
        ww = w * (1 + 0.3 * t)
        row = []
        for j in range(cols + 1):
            s = (j / cols - 0.5) * ww
            a = ang + s / r
            rr = r + wave * math.sin(j * 2.1 + i * 0.9) * t
            row.append(bm.verts.new((math.sin(a) * rr, -math.cos(a) * rr * 0.86, z)))
        grid.append(row)
    for i in range(rows):
        for j in range(cols):
            bm.faces.new((grid[i][j], grid[i][j + 1], grid[i + 1][j + 1], grid[i + 1][j]))
    bm.to_mesh(me); bm.free()
    o = bpy.data.objects.new(name, me); scn.collection.objects.link(o)
    s = o.modifiers.new("Solid", "SOLIDIFY"); s.thickness = 0.006
    sub = o.modifiers.new("Sub", "SUBSURF"); sub.levels = sub.render_levels = 0 if LITE else 1
    for p in me.polygons:
        p.use_smooth = True
    return finish(o, m)

# ================================================================ PERSONNAGE
# ---- jambes
for sd in (-1, 1):
    x = sd * 0.12
    loft(f"Soleret{sd}", [(0.0, 0.05, 0.12, -0.04), (0.05, 0.055, 0.13, -0.04), (0.09, 0.05, 0.1, -0.02), (0.13, 0.05, 0.065, 0.0)], "black", dx=x)
    for i in range(3):
        box(f"SoleretLame{sd}{i}", (x, -0.13 + i * 0.055, 0.085 + i * 0.018), (0.125, 0.07, 0.035), "steel" if i % 2 == 0 else "gun", rot=(math.radians(-25), 0, 0))
    box(f"Talon{sd}", (x, 0.08, 0.07), (0.1, 0.07, 0.11), "gun")
    loft(f"Jambe{sd}", [(0.1, 0.055, 0.06, 0), (0.2, 0.06, 0.07, 0.005), (0.32, 0.068, 0.082, 0.01), (0.44, 0.06, 0.065, 0), (0.53, 0.066, 0.07, -0.005), (0.62, 0.08, 0.085, 0), (0.75, 0.095, 0.095, 0), (0.88, 0.105, 0.105, 0)], "gun", dx=x)
    box(f"Tibia{sd}", (x, -0.07, 0.3), (0.095, 0.03, 0.34), "steel", rot=(math.radians(4), 0, 0), bevel=0.01)
    for z in (0.18, 0.42):
        for q in (-1, 1):
            sphere(f"Rivet{sd}{z}{q}", (x + q * 0.035, -0.087, z), 0.007, "rust")
    cyl(f"Genou{sd}", (x, -0.075, 0.53), 0.06, 0.045, 0.06, "steel", rot=(math.radians(90), 0, 0))
    box(f"GenouAile{sd}", (x + sd * 0.06, -0.06, 0.53), (0.025, 0.06, 0.1), "gun", rot=(0, 0, math.radians(sd * 20)))
    box(f"Cuissard{sd}", (x * 1.05, -0.08, 0.7), (0.12, 0.03, 0.22), "steel", rot=(math.radians(-5), 0, 0), bevel=0.01)
# poche de cuisse (droite)
box("PocheCuisse", (-0.23, -0.02, 0.66), (0.05, 0.12, 0.14), "leath")
box("PocheCuisseRabat", (-0.255, -0.02, 0.72), (0.015, 0.125, 0.05), "leath2")
cyl("SangleCuisse", (-0.14, 0, 0.64), 0.11, 0.11, 0.025, "leath2", verts=24)

# ---- tunique en lés
T = [(0, 0.11, "ivory", 0.28), (0.12, 0.1, "crim", 0.36), (-0.12, 0.1, "crim", 0.38)]
for sd in (-1, 1):
    T += [(sd * 0.75, 0.1, "crim", 0.36), (sd * 1.35, 0.09, "ivory", 0.42), (sd * 2.0, 0.1, "crim", 0.3), (sd * 2.6, 0.1, "ivory", 0.25)]
T += [(math.pi, 0.14, "ivory", 0.22)]
for k, (a, w, m, zb) in enumerate(T):
    cloth_strip(f"Le{k}", a, w * 2.2, 0.88, zb, 0.225 + k * 0.004, 0.27 + k * 0.006, m)

# ---- torse
loft("Torse", [(0.83, 0.165, 0.125, 0), (0.95, 0.158, 0.12, 0), (1.05, 0.175, 0.135, 0), (1.15, 0.215, 0.155, -0.005), (1.25, 0.255, 0.165, -0.01), (1.33, 0.27, 0.155, 0), (1.39, 0.22, 0.125, 0.01), (1.43, 0.13, 0.09, 0.01)], "gun")
for i in range(3):
    box(f"LameAbdo{i}", (0, -0.15, 0.93 + i * 0.05), (0.24, 0.03, 0.05), "steel" if i % 2 == 0 else "gun", rot=(math.radians(-10), 0, 0), bevel=0.008)
for sd in (-1, 1):
    shell(f"Plastron{sd}", (sd * 0.075, -0.035, 1.22), 0.16, "steel", axis=(sd * 0.35, -1, 0.1), cut=0.45, scale=(0.95, 0.85, 1.15), thick=0.012)
    for z in (1.12, 1.3):
        sphere(f"RivetP{sd}{z}", (sd * 0.15, -0.19, z), 0.008, "rust")
    box(f"ProtegeCou{sd}", (sd * 0.1, 0.01, 1.48), (0.03, 0.15, 0.1), "gun", rot=(0, math.radians(sd * 18), 0))
box("Arete", (0, -0.19, 1.22), (0.025, 0.02, 0.24), "rust")
shell("Dossiere", (0, 0.03, 1.2), 0.2, "gun", axis=(0, 1, 0), cut=0.5, scale=(1.25, 0.8, 1.1), thick=0.012)
seg("Gorgerin", (0, 0, 1.35), (0, 0, 1.48), 0.15, 0.11, "steel")

# ---- ceinturon et sacoches
cyl("Ceinturon", (0, 0, 0.88), 0.225, 0.225, 0.06, "leath", verts=40, scale=(1, 0.82, 1))
box("Boucle", (0, -0.19, 0.88), (0.06, 0.012, 0.05), "brass")
for a in (0.6, -0.6, 1.2, -1.2, 2.1, -2.1):
    px, py = math.sin(a) * 0.235, -math.cos(a) * 0.235 * 0.82
    rz = -a
    box(f"Sacoche{a}", (px, py, 0.83), (0.08, 0.05, 0.11), "leath", rot=(0, 0, rz), bevel=0.008)
    box(f"Rabat{a}", (px * 1.04, py * 1.04, 0.875), (0.085, 0.052, 0.035), "leath2", rot=(0, 0, rz))
    box(f"Fermoir{a}", (px * 1.13, py * 1.13, 0.86), (0.014, 0.006, 0.018), "brass", rot=(0, 0, rz))

# ---- épaulières en coques superposées
for sd in (-1, 1):
    sx, sz = sd * 0.29, 1.36
    tilt = (0, math.radians(sd * 28), 0)
    shell(f"EpauleDome{sd}", (sx, 0, sz), 0.115, "steel", axis=(0, 0, 1), cut=-0.15, scale=(1.0, 1.1, 0.85), rot=tilt, thick=0.012)
    for i in range(3):
        shell(f"EpauleLame{sd}{i}", (sx + sd * (0.035 + i * 0.022), 0, sz - 0.045 - i * 0.045), 0.12 + i * 0.008, "gun" if i % 2 == 0 else "steel",
              axis=(0, 0, 1), cut=0.25, scale=(1.0, 1.12, 0.9), rot=(0, math.radians(sd * (34 + i * 8)), 0), thick=0.01)
    for q in (-1, 1):
        sphere(f"RivetE{sd}{q}", (sx + sd * 0.05, q * 0.08, sz + 0.06), 0.008, "rust")

# ---- casque saurus
HZ = 1.63
loft("Casque", [(HZ - 0.13, 0.07, 0.09, -0.08), (HZ - 0.07, 0.1, 0.15, -0.05), (HZ, 0.112, 0.165, -0.04), (HZ + 0.06, 0.115, 0.15, -0.02), (HZ + 0.11, 0.1, 0.125, 0.0), (HZ + 0.15, 0.055, 0.075, 0.01)], "gun", verts=8, sub=1)
loft("Calotte", [(HZ + 0.085, 0.108, 0.14, -0.005), (HZ + 0.125, 0.09, 0.115, 0.002), (HZ + 0.155, 0.04, 0.06, 0.01)], "steel", verts=8, sub=1)
for i in range(4):
    box(f"Barreau{i}", ((i - 1.5) * 0.022, -0.205 + abs(i - 1.5) * 0.02, HZ - 0.06), (0.008, 0.012, 0.07), "steel", bevel=0.002)
seg("Machoire", (0, -0.05, HZ - 0.08), (0, -0.18, HZ - 0.12), 0.085, 0.025, "steel", verts=6)
for sd in (-1, 1):
    for i in range(3):
        box(f"Fente{sd}{i}", (sd * 0.065, -0.14 - i * 0.03, HZ + 0.005 - i * 0.008), (0.02, 0.02, 0.006), "black", rot=(0, 0, math.radians(sd * -15)))
    box(f"Joue{sd}", (sd * 0.1, -0.06, HZ - 0.07), (0.025, 0.14, 0.11), "steel", rot=(0, math.radians(sd * 12), math.radians(sd * 10)), bevel=0.01)
for i in range(5):
    y = -0.12 + i * 0.055
    z = HZ + 0.1 - (0.02 if i == 0 else 0)
    h = 0.15 * (1 - i * 0.12)
    blade(f"Crete{i}", [(0, y - 0.03, z), (0, y + 0.05, z), (0, y + 0.12, z + h)], 0.012, "steel" if i % 2 == 0 else "gun")
for sd in (-1, 1):
    for i in range(2):
        blade(f"AileronLat{sd}{i}", [(sd * 0.115, -0.02 + i * 0.06, HZ + 0.03 - i * 0.03), (sd * 0.115, 0.05 + i * 0.06, HZ + 0.03 - i * 0.03), (sd * 0.15, 0.18 + i * 0.05, HZ + 0.08)], 0.01, "gun")
seg("Cou", (0, 0, 1.44), (0, 0, 1.56), 0.075, 0.07, "black")

# ================================================================ ARBALÈTE
WX, WZ = -0.05, 1.08         # axe de l'arme, parallèle à -Y
def W(x, y, z): return (WX + x, y, WZ + z)
box("Crosse", W(0, 0.0, 0), (0.06, 0.24, 0.1), "gun", bevel=0.01)
box("Plaque", W(0, 0.13, -0.01), (0.07, 0.025, 0.14), "black")
box("Poignee", W(0, -0.17, -0.09), (0.045, 0.05, 0.13), "black", rot=(math.radians(-18), 0, 0))
box("Corps", W(0, -0.33, 0.01), (0.085, 0.3, 0.09), "gun", bevel=0.008)
box("PanneauCorps", W(0, -0.33, 0.0), (0.088, 0.22, 0.045), "rust")
box("Rail", W(0, -0.47, 0.065), (0.04, 0.56, 0.02), "black")
for i in range(9):
    box(f"Cran{i}", W(0, -0.24 - i * 0.055, 0.08), (0.045, 0.012, 0.012), "gun")
cyl("Viseur", W(0, -0.36, 0.13), 0.028, 0.028, 0.17, "black", rot=(math.radians(90), 0, 0))
for y in (-0.31, -0.41):
    box(f"Monture{y}", W(0, y, 0.095), (0.025, 0.02, 0.04), "gun")
cyl("Lentille", W(0, -0.446, 0.13), 0.022, 0.022, 0.004, "amber", rot=(math.radians(90), 0, 0))
box("Levier", W(0.05, -0.5, 0.04), (0.012, 0.16, 0.02), "steel")
box("LevierTete", W(0.06, -0.42, 0.04), (0.025, 0.025, 0.04), "black")
DY, DZ, DR = -0.34, -0.13, 0.12
cyl("Tambour", W(0, DY, DZ), DR, DR, 0.11, "gun", rot=(0, math.radians(90), 0), verts=32)
cyl("Moyeu", W(0, DY, DZ), 0.03, 0.03, 0.13, "black", rot=(0, math.radians(90), 0))
for i in range(12):
    a = i / 12 * math.tau
    box(f"Cerclage{i}", W(0, DY + math.cos(a) * DR, DZ + math.sin(a) * DR), (0.118, 0.016, 0.016), "steel", rot=(a, 0, 0))
for sd in (-1, 1):
    for i in range(4):
        box(f"Fente{sd}{i}", W(sd * 0.056, DY, DZ - 0.06 + i * 0.04), (0.004, 0.14, 0.016), "amber", bevel=0)
box("Fut", W(0, -0.64, 0), (0.07, 0.26, 0.075), "gun", bevel=0.008)
box("PoigneeAvant", W(0, -0.62, -0.09), (0.04, 0.045, 0.12), "black")
box("Arc", W(0, -0.8, 0.01), (0.15, 0.06, 0.13), "gun", bevel=0.01)
box("ArcPlaque", W(0, -0.834, 0.01), (0.1, 0.008, 0.09), "rust")
tips = []
for sd in (-1, 1):
    p = [W(sd * 0.07, -0.8, 0.01), W(sd * 0.22, -0.84, 0.01), W(sd * 0.36, -0.78, 0.01), W(sd * 0.45, -0.66, 0.01)]
    for k in range(3):
        seg(f"Branche{sd}{k}", p[k], p[k + 1], 0.026 - k * 0.003, 0.023 - k * 0.003, "gun", verts=12, squash=0.6)
    box(f"BrancheRenfort{sd}", tuple((Vector(p[0]) + Vector(p[1])) / 2 + Vector((0, 0, 0.02))), (0.1, 0.04, 0.02), "steel", rot=(0, 0, math.radians(-sd * 15)))
    cyl(f"Came{sd}", p[3], 0.03, 0.03, 0.04, "steel")
    seg(f"Corde{sd}", p[3], W(0, -0.5, 0.05), 0.003, 0.003, "ivory", verts=6)
    seg(f"Cable{sd}", tuple((Vector(p[1]) + Vector(p[2])) / 2), W(sd * 0.03, -0.62, -0.03), 0.006, 0.006, "black", verts=6)
seg("Carreau", W(0, -0.5, 0.06), W(0, -0.92, 0.06), 0.007, 0.007, "steel", verts=8)
for sd in (-1, 1):
    blade(f"Empenne{sd}", [W(0, -0.5, 0.06), W(0, -0.56, 0.06), W(sd * 0.025, -0.5, 0.075)], 0.003, "ivory")
cyl("Ogive", W(0, -0.95, 0.06), 0.02, 0.022, 0.06, "black", rot=(math.radians(90), 0, 0))
cyl("Pointe", W(0, -1.0, 0.06), 0.022, 0.0, 0.05, "amber", rot=(math.radians(90), 0, 0))

# ================================================================ BRAS
GRIP_R = Vector(W(0, -0.17, -0.12))
GRIP_L = Vector(W(0, -0.62, -0.1))
def arm(sd, shoulder, elbow, hand):
    shoulder, elbow, hand = Vector(shoulder), Vector(elbow), Vector(hand)
    loft_mid = shoulder.lerp(elbow, 0.45)
    seg(f"BrasHaut{sd}", shoulder, loft_mid, 0.058, 0.066, "black")
    seg(f"BrasHaut2{sd}", loft_mid, elbow, 0.066, 0.052, "black")
    seg(f"Brassard{sd}", shoulder.lerp(elbow, 0.3), shoulder.lerp(elbow, 0.85), 0.072, 0.066, "gun")
    sphere(f"Coude{sd}", elbow, 0.058, "steel", scale=(1, 1, 1))
    seg(f"Canon{sd}", elbow.lerp(hand, 0.12), elbow.lerp(hand, 0.78), 0.06, 0.05, "steel")
    seg(f"Manchette{sd}", elbow.lerp(hand, 0.72), elbow.lerp(hand, 0.86), 0.055, 0.068, "gun")
    box(f"Gant{sd}", hand + Vector((0, 0, 0.035)), (0.07, 0.08, 0.06), "black")
    box(f"GantPlaque{sd}", hand + Vector((sd * 0.03, 0, 0.05)), (0.02, 0.07, 0.045), "gun")
    for f in range(4):
        box(f"Doigt{sd}{f}", hand + Vector((-sd * 0.04, -0.03 + f * 0.02, 0.0)), (0.025, 0.017, 0.05), "black")
arm(-1, (-0.3, 0.0, 1.3), (-0.33, 0.02, 1.05), GRIP_R)
arm(1, (0.3, 0.0, 1.3), (0.2, -0.3, 1.1), GRIP_L)

# ---- proportions : jambes allongées (déformation globale par tranche de hauteur)
HIP, LEG_K = 0.88, 1.16
for o in [o for o in scn.objects if o.parent is RIG and o.type == "MESH"]:
    mw = o.matrix_world.copy()
    o.data.transform(mw)
    o.matrix_world = Matrix.Identity(4)
    o.parent = RIG
    for v in o.data.vertices:
        z = v.co.z
        v.co.z = z * LEG_K if z < HIP else z + HIP * (LEG_K - 1)

# ================================================================ STUDIO
bpy.ops.mesh.primitive_plane_add(size=12, location=(0, 0, 0))
floor = bpy.context.object
fm = mat("Sol", (0.02, 0.02, 0.021), 0.0, 1.0)
floor.data.materials.append(fm)
world = bpy.data.worlds.new("Monde"); scn.world = world
world.use_nodes = True
world.node_tree.nodes["Background"].inputs[0].default_value = (0.045, 0.045, 0.05, 1)
world.node_tree.nodes["Background"].inputs[1].default_value = 1.0

def area(name, loc, energy, color, size):
    d = bpy.data.lights.new(name, "AREA"); d.energy = energy; d.color = color; d.size = size
    o = bpy.data.objects.new(name, d); scn.collection.objects.link(o); o.location = loc
    tr = o.constraints.new("TRACK_TO"); tr.target = TARGET; tr.track_axis = "TRACK_NEGATIVE_Z"; tr.up_axis = "UP_Y"
TARGET = bpy.data.objects.new("Cible", None); scn.collection.objects.link(TARGET); TARGET.location = (0, -0.15, 1.05)
area("Cle", (-2.2, -2.6, 3.0), 550, (1.0, 0.95, 0.88), 2.0)
area("Debouchage", (2.6, -1.8, 1.4), 160, (0.8, 0.86, 1.0), 2.5)
area("Contre", (0.6, 3.0, 2.8), 650, (1.0, 0.82, 0.62), 1.5)

cam_d = bpy.data.cameras.new("Cam"); cam_d.lens = 70
cam = bpy.data.objects.new("Cam", cam_d); scn.collection.objects.link(cam); scn.camera = cam
cam.location = (0, -6.2, 1.45)
tr = cam.constraints.new("TRACK_TO"); tr.target = TARGET; tr.track_axis = "TRACK_NEGATIVE_Z"; tr.up_axis = "UP_Y"

scn.render.engine = "BLENDER_EEVEE"
scn.render.resolution_x, scn.render.resolution_y = 900, 1200
scn.render.film_transparent = False
try:
    scn.eevee.taa_render_samples = 32
    scn.eevee.use_shadows = True
except Exception:
    pass
scn.view_settings.view_transform = "AgX"
scn.view_settings.look = "AgX - Medium High Contrast"
scn.view_settings.exposure = -1.0

os.makedirs(OUT, exist_ok=True)
for v in [v for v in want if v in VIEWS]:
    RIG.rotation_euler = (0, 0, math.radians(VIEWS[v]))
    scn.render.filepath = os.path.join(OUT, f"tireur_{v}.png")
    bpy.ops.render.render(write_still=True)
    print("RENDU", scn.render.filepath)

def bake_for_gltf(tex_size=1024):
    """Fusionne les pièces par matériau, déplie les UV et cuit couleur + rugosité procédurales en images,
    pour que la rouille survive à l'export glTF (qui ignore les textures procédurales)."""
    import addon_utils
    addon_utils.enable("cycles", default_set=True)
    scn.render.engine = "CYCLES"
    scn.cycles.samples = 8
    scn.cycles.device = "CPU"
    RIG.rotation_euler = (0, 0, 0)
    dg = bpy.context.evaluated_depsgraph_get()
    parts = {}
    for o in [o for o in scn.objects if o.parent is RIG and o.type == "MESH"]:
        me = bpy.data.meshes.new_from_object(o.evaluated_get(dg), depsgraph=dg)
        me.transform(o.matrix_world)
        parts.setdefault(o.active_material.name, []).append(me)
        bpy.data.objects.remove(o)
    out = []
    for mname, meshes in parts.items():
        bm = bmesh.new()
        for me in meshes:
            bm.from_mesh(me)
        me = bpy.data.meshes.new(mname); bm.to_mesh(me); bm.free()
        me.materials.clear(); me.materials.append(bpy.data.materials[mname])
        while me.uv_layers:
            me.uv_layers.remove(me.uv_layers[0])
        for at in [at.name for at in me.attributes if not at.name.startswith(".") and at.name not in ("position", "sharp_face", "sharp_edge")]:
            me.attributes.remove(me.attributes[at])
        if not me.polygons:
            continue
        o = bpy.data.objects.new(mname, me); scn.collection.objects.link(o); out.append(o)
        nt = bpy.data.materials[mname].node_tree
        bsdf = nt.nodes["Principled BSDF"]
        me.validate()
        if not bsdf.inputs["Base Color"].is_linked:
            continue
        me.uv_layers.new(name="UVMap")
        with bpy.context.temp_override(active_object=o, object=o, selected_objects=[o], selected_editable_objects=[o]):
            bpy.ops.object.mode_set(mode="EDIT"); bpy.ops.mesh.select_all(action="SELECT")
            bpy.ops.uv.smart_project(island_margin=0.003)
            bpy.ops.object.mode_set(mode="OBJECT")
        imgs = {}
        for kind in ("DIFFUSE", "ROUGHNESS"):
            path = os.path.join(ROOT, "assets", "textures", f"{mname}_{kind.lower()}{SFX}.png")
            node = nt.nodes.new("ShaderNodeTexImage")
            imgs[kind] = node
            if os.path.exists(path) and "--rebake" not in argv:
                node.image = bpy.data.images.load(path)
                if kind == "ROUGHNESS": node.image.colorspace_settings.name = "Non-Color"
                continue
            img = bpy.data.images.new(f"{mname}_{kind}", tex_size, tex_size, is_data=(kind == "ROUGHNESS"))
            node.image = img
            nt.nodes.active = node
            for ob in scn.objects: ob.select_set(ob is o)
            bpy.context.view_layer.objects.active = o
            if kind == "DIFFUSE":
                bpy.ops.object.bake(type="DIFFUSE", pass_filter={"COLOR"}, margin=4)
            else:
                bpy.ops.object.bake(type="ROUGHNESS", margin=4)
            img.filepath_raw = path
            os.makedirs(os.path.dirname(img.filepath_raw), exist_ok=True)
            img.file_format = "PNG"; img.save()
            imgs[kind] = node
        for l in list(bsdf.inputs["Base Color"].links) + list(bsdf.inputs["Roughness"].links) + list(bsdf.inputs["Normal"].links):
            nt.links.remove(l)
        nt.links.new(imgs["DIFFUSE"].outputs["Color"], bsdf.inputs["Base Color"])
        nt.links.new(imgs["ROUGHNESS"].outputs["Color"], bsdf.inputs["Roughness"])
        print("CUIT", mname)
    return out

if EXPORT_GLB:
    baked = bake_for_gltf(512 if LITE else 1024)
    for o in scn.objects:
        o.select_set(o in baked)
    bpy.ops.export_scene.gltf(filepath=os.path.join(ROOT, "assets", f"tireur_saurus{SFX}.glb"), use_selection=True, export_apply=False, export_image_format="JPEG" if LITE else "AUTO")
    print("GLB exporté", sum(len(o.data.polygons) for o in baked), "faces,", len(baked), "matériaux")
