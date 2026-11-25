#!/usr/bin/env python3
"""Exporte les pièces de la planche des Forges mortes (planches/forges-mortes-decor-propositions.html, recommandation
acceptée le 2026-11-25 : F1–F6, L2, R1, R3, R4, A1–A4) en atlas : assets/forges/props.png + props.json, au format
de tools/salles-oubliees/export.py (nom → [x, y, w, h, ax, ay]), cases 96 × 64, sol à y = 56, paroi de 48 px.

Les animations passent en jeu (contrairement aux Salles oubliées, où l'export ne gardait que l'image figée) :
- une pièce marquée « glow » ou « flow » reçoit un calque « <nom>_glow » : les pixels que les effets animés de la
  planche ajoutent (braises, fissures, lave, métal chaud), sans les halos (les lumières du jeu s'en chargent) ;
- assets/forges/fx.json donne, par pièce, les effets de world/sanctum/prop_anim.gd : glow (le calque bat), flow (la
  lave glisse le long du calque), embers (braises qui montent), steam (vapeur), swing (balancement autour d'un
  pivot, en pixels depuis l'ancre), flame (flamme de bougie, en pixels depuis l'ancre).
Les noms commencent par « f_ » (un nom n'existe que dans un atlas).

    python3 tools/forges-decor/build.py && python3 tools/forges-decor/export.py
"""
import json, pathlib, subprocess, sys, tempfile
from PIL import Image
root = pathlib.Path(__file__).resolve().parents[2]
CW, CH, COLS = 96, 64, 10
ANCHOR = {"foot": (48, 56), "mid": (48, 32)}
F, G = "foot", "mid"
# Paroi du jeu : 48 px au-dessus du pied (wallTop = 9 dans la case).
TOP = [0, -48]
# (nom, ancre, dessin, effets)
PIECES = [
    # F1 halle des fours
    ("f_furnace", F, "furnace(48,1,0)", []),
    ("f_furnace_ember", F, "furnace(48,2,1)", [{"m": "glow"}]),
    ("f_bellows", F, "bellows(50,56,false,1,1,1.3)", []), ("f_bellows_flat", F, "bellows(50,56,true,2,1,1.3)", []),
    ("f_tongs", F, "tongs(48,55)", []), ("f_hammer", F, "hammer(44,55)", []),
    # F2 rigoles de coulée (à plat)
    ("f_rigole", G, "rigole(8,88,32,false,1)", []), ("f_rigole_hot", G, "rigole(8,88,32,true,2)", [{"m": "flow"}]),
    # F3 lingotières et outils
    ("f_moulds", F, "moulds(35,56,5,1,1)", []), ("f_moulds_stack", F, "moulds(37,56,4,2,3)", []),
    ("f_bars", F, "ironBars(48,56,5,4)", []), ("f_bars_big", F, "ironBars(46,56,9,3);ironBars(56,54,3,5)", []),
    # F4 palans et chaînes (pendus à la poutre, en haut de la paroi)
    ("f_beam", F, "beam(8,88)", []),
    ("f_hoist_hook", F, "hoist(48,16,0,'hook')", [{"m": "swing", "p": TOP}]),
    ("f_hoist_pot", F, "hoist(48,22,0,'pot')", [{"m": "swing", "p": TOP}]),
    ("f_hoist_s", F, "hoist(48,10,0,'hook')", [{"m": "swing", "p": TOP}]),
    # F5 scories et rouille
    ("f_slag", F, "slag(48,56,8,1,false)", []), ("f_slag_b", F, "slag(48,56,6,3,false)", []),
    ("f_slag_warm", F, "slag(48,56,9,2,true)", [{"m": "glow"}]),
    ("f_rust", F, "rustRun(48,1)", []), ("f_rust_b", F, "rustRun(48,3)", []),
    ("f_scrap", F, "scrap(46,56,1)", []), ("f_scrap_b", F, "scrap(46,56,5)", []),
    # F6 fissures de lave
    ("f_crack", F, "crackW(48,1)", [{"m": "glow"}, {"m": "embers", "o": [0, -45], "s": 6, "r": 14, "n": 3}]),
    ("f_crack_b", F, "crackW(48,4)", [{"m": "glow"}, {"m": "embers", "o": [0, -45], "s": 6, "r": 14, "n": 3}]),
    ("f_crackf", G, "crackF(16,80,32,4)", [{"m": "glow"}]),
    ("f_coolflow", G, "coolFlow(48,32,14,4,6)", []),
    # L2 lanternes de fondeur (fixes)
    ("f_lamp", F, "cageLamp(43,true,1)", [{"m": "flame", "o": [0, -40]}]), ("f_lamp_off", F, "cageLamp(43,false,2)", []),
    # R1 trempe, R3 esprits enchaînés, R4 magasin
    ("f_blades", F, "blades(38,56,6,1)", []),
    ("f_anvil", F, "fAnvil(48,56)", []),
    ("f_chained", F, "fAnvil(58,56);chainTo(53,50,40,51);spirit(40,56,false,0)", []),
    ("f_unchained", F, "fAnvil(58,56);looseLinks(46,55,4,3)", []),
    # A1–A4 arènes (exportées pour les boss du biome 3, pas encore posées)
    ("f_anvil_big", F, "bigAnvil(48,56,true)", [{"m": "glow"}]),
    ("f_ring", F, "anchorRing(38,54,1,1)", []),
    ("f_blast", F, "blastFurnace(48,1)", [{"m": "glow"}, {"m": "embers", "o": [0, -26], "s": 12, "r": 16, "n": 4},
                                          {"m": "flame", "o": [-3, -3]}, {"m": "flame", "o": [3, -3]}]),
    ("f_valve", F, "steamValve(48,56,false,1)", [{"m": "steam", "o": [7, -8]}]),
    ("f_crucible", F, "bigCrucible(48,56,false,1)", [{"m": "glow"}]), ("f_crucible_tip", F, "bigCrucible(38,56,true,2)", []),
    ("f_cage", F, "cage(48,12,0)", [{"m": "swing", "p": TOP}]),
    ("f_penitent", F, "penitent(48,56,1)", []), ("f_links", G, "looseLinks(48,32,5,1)", []), ("f_billot", F, "billot(48,56)", []),
    ("f_seal", G, "fSeal(48,32,30)", [{"m": "glow"}]),
    ("f_tr_hammer", F, "trophyHammer(48,56)", []), ("f_tr_link", F, "trophyLink(48,56)", []),
    ("f_tr_heart", F, "trophyHeart(48,56)", [{"m": "glow"}]),
    ("f_arch", F, "archF(48,56,'R',1)", []),
]
GLOWS = [i for i, p in enumerate(PIECES) if any(f["m"] in ("glow", "flow") for f in p[3])]
js = ("EXPORT=true;wallTop=x=>ft(x)-47;light=()=>{};embers=()=>{};flames=()=>{};const LIST=["
      + ",".join(f"()=>{{{d}}}" for _, _, d, _ in PIECES) + "];const GLOWS=" + json.dumps(GLOWS) + ";" + f"""
const CW={CW},CH={CH},COLS={COLS},N=LIST.length+GLOWS.length,ROWS=Math.ceil(N/COLS);
document.documentElement.style.cssText='margin:0;padding:0';document.body.style.cssText='margin:0;padding:0;background:#ff00ff';document.body.innerHTML='';
const cv=document.createElement('canvas');cv.width=COLS*CW;cv.height=ROWS*CH;cv.style.cssText='display:block;width:'+cv.width+'px;height:'+cv.height+'px;max-width:none;image-rendering:pixelated';
document.body.appendChild(cv);const cx=cv.getContext('2d');views.length=0;
function render(d,withPost){{W=CW;H=CH;buf=new Int32Array(W*H).fill(-1);const id=cx.createImageData(W,H);img=id.data;
 for(let k=0;k<W*H;k++){{img[k*4]=255;img[k*4+1]=0;img[k*4+2]=255;img[k*4+3]=255}}
 DK=1;T=1;M=(x,y)=>y>=56;post.length=0;d();compose();const base=new Uint8ClampedArray(img);if(withPost)for(const f of post)f();return [id,base]}}
const put=(id,i)=>cx.putImageData(id,(i%COLS)*CW,Math.floor(i/COLS)*CH);
LIST.forEach((d,i)=>put(render(d,false)[0],i));
GLOWS.forEach((gi,g)=>{{const[id,base]=render(LIST[gi],true);const a=id.data;
 for(let k=0;k<W*H;k++){{const q=k*4;if(Math.abs(a[q]-base[q])+Math.abs(a[q+1]-base[q+1])+Math.abs(a[q+2]-base[q+2])<24){{a[q]=255;a[q+1]=0;a[q+2]=255}}}}
 put(id,LIST.length+g)}});
""")
html = (root / "planches/forges-mortes-decor-propositions.html").read_text().replace("</script>", "</script><script>" + js + "</script>", 1)
html = html.replace("requestAnimationFrame(loop)", "0")
total = len(PIECES) + len(GLOWS)
rows = -(-total // COLS)
with tempfile.TemporaryDirectory() as tmp:
    t = pathlib.Path(tmp)
    (t / "export.html").write_text(html)
    (t / "profil").mkdir()
    subprocess.run(["firefox", "--headless", "--no-remote", "--profile", str(t / "profil"), f"--window-size={COLS * CW},{rows * CH}",
                    "--screenshot", str(t / "shot.png"), (t / "export.html").as_uri()], check=True, timeout=120, capture_output=True)
    shot = Image.open(t / "shot.png").convert("RGB").crop((0, 0, COLS * CW, rows * CH))
atlas = Image.new("RGBA", shot.size, (0, 0, 0, 0))
src, dst = shot.load(), atlas.load()
for y in range(shot.size[1]):
    for x in range(shot.size[0]):
        c = src[x, y]
        if not (c[0] > 240 and c[1] < 16 and c[2] > 240) and (y // CH) * COLS + x // CW < total:
            dst[x, y] = c + (255,)


def cell(i):
    ox, oy = (i % COLS) * CW, (i // COLS) * CH
    return ox, oy, atlas.crop((ox, oy, ox + CW, oy + CH)).getbbox()


out, fx = {}, {}
glow_of = {gi: len(PIECES) + g for g, gi in enumerate(GLOWS)}
for i, (name, anchor, _, effects) in enumerate(PIECES):
    ox, oy, box = cell(i)
    if box is None:
        sys.exit("pièce vide : " + name)
    ax, ay = ANCHOR[anchor]
    if i in glow_of:
        gx, gy, gbox = cell(glow_of[i])
        if gbox is None:
            sys.exit("calque de lueur vide : " + name)
        # Même rectangle pour la pièce et son calque : les deux sprites se superposent avec la même ancre.
        box = (min(box[0], gbox[0]), min(box[1], gbox[1]), max(box[2], gbox[2]), max(box[3], gbox[3]))
        out[name + "_glow"] = [gx + box[0], gy + box[1], box[2] - box[0], box[3] - box[1], ax - box[0], ay - box[1]]
    out[name] = [ox + box[0], oy + box[1], box[2] - box[0], box[3] - box[1], ax - box[0], ay - box[1]]
    if effects:
        fx[name] = effects
(root / "assets/forges").mkdir(exist_ok=True)
atlas.save(root / "assets/forges/props.png")
(root / "assets/forges/props.json").write_text(json.dumps(out, separators=(",", ":")))
(root / "assets/forges/fx.json").write_text(json.dumps(fx, separators=(",", ":"), ensure_ascii=False))
print("ok", len(PIECES), "pièces,", len(GLOWS), "calques", atlas.size)
