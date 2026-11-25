#!/usr/bin/env python3
"""Exporte les pièces de la planche des Salles oubliées (planches/salles-oubliees-decor-propositions.html, choix du
2026-11-25 : V1–V6, L1, R1, R3, A1–A4) en atlas : assets/oubliees/props.png + props.json, au même format que
tools/salles-decor/export.py (nom → [x, y, w, h, ax, ay]). Chaque pièce est dessinée dans une case 96 × 64 dont le
sol commence en y = 56 ; la paroi du jeu fait environ 48 px (13 sur la planche) : l'export la redéfinit (wallTop)
pour que les pièces murales la remplissent. Les noms commencent par « o_ » (un nom n'existe que dans un atlas).

Animations (2026-11-25, même système que tools/forges-decor/export.py) : une pièce marquée « glow » reçoit un calque
« <nom>_glow » (les pixels que la lueur animée de la planche ajoute) ; assets/oubliees/fx.json donne les effets de
world/sanctum/prop_anim.gd : drip (gouttes des suintements et des stalactites), leak (fuite du tuyau), spill (eau sous
la vanne murale), needle (aiguille du manomètre), glow (lueur cyan des glyphes), swing (fanaux et chaînes, autour de
leur crochet en haut de la paroi), flame (flamme du fanal). Les morceaux animés ne sont plus figés dans l'image.

    python3 tools/salles-oubliees/build.py && python3 tools/salles-oubliees/export.py
"""
import json, pathlib, subprocess, sys, tempfile
from PIL import Image
root = pathlib.Path(__file__).resolve().parents[2]
CW, CH, COLS = 96, 64, 10
ANCHOR = {"foot": (48, 56), "mid": (48, 32)}
F, G = "foot", "mid"
TOP = [0, -48]
VERT, EAU = "#8ec8b0", "#4a8088"
GLYPH_GLOW = [{"m": "glow", "lo": -0.55, "hi": 0.55, "sp": 0.9}]
# (nom, ancre, dessin, effets) ; positions des effets en pixels depuis l'ancre, relevées sur les dessins ci-dessous.
PIECES = [
    # V1 galerie tyrienne rongée
    ("o_col", F, "vcol(48,56,18,false,1)", []), ("o_col_broken", F, "vcol(48,56,11,true,2)", []), ("o_drum", F, "drum(48,56,VS)", []),
    ("o_glyph", F, "glyphW(46,3);for(const[i,j]of[[0,0],[2,0],[1,1],[0,2],[2,2],[1,3],[1,4]])px(46+i,wallTop(46)+4+j,0x4a8a8c)", GLYPH_GLOW),
    ("o_glyph_b", F, "glyphW(46,7);for(const[i,j]of[[0,0],[1,0],[2,0],[0,1],[0,2],[1,2],[2,2],[2,3],[0,4],[1,4],[2,4]])px(46+i,wallTop(46)+4+j,0x4a8a8c)", GLYPH_GLOW),
    # V2 suintements : la goutte part de la veine (seep : t = paroi + 5 + arrondi(2 sin(0,21 x + graine))) et ride la flaque
    ("o_seam", F, "seam(16,80,1)", []),
    ("o_seep", F, "seep(48,1)", [{"m": "drip", "o": [0, -44], "d": 47, "sp": 0.55, "rip": True, "col": VERT}]),
    ("o_seep_b", F, "seep(48,5)", [{"m": "drip", "o": [0, -41], "d": 44, "sp": 0.55, "rip": True, "col": VERT}]),
    ("o_stal", F, "stalV(48,9,1)", [{"m": "drip", "o": [0, -38], "d": 14, "sp": 0.4, "cut": 0.6, "fade": True, "col": VERT}]),
    ("o_stal_s", F, "stalV(48,5,2)", [{"m": "drip", "o": [0, -42], "d": 14, "sp": 0.4, "cut": 0.6, "fade": True, "col": VERT}]),
    # V3 portes murées
    ("o_walled", F, "walled(48,1,false)", []), ("o_walled_b", F, "walled(48,2,false)", []), ("o_walled_broken", F, "walled(48,3,true)", []),
    ("o_plaque", F, "plaque(44,4)", []), ("o_niche", F, "emptyNiche(48,6,false)", []), ("o_niche_stat", F, "emptyNiche(48,6,true)", []),
    # V4 canalisations de Byrsa : fuite au joint (x 40, y 18), aiguille du manomètre en (52, 25)
    ("o_pipe", F, "pipe(16,80,8,1)", []), ("o_pipe2", F, "pipe(16,80,8,2);pipe(16,80,13,3)", []),
    ("o_pipe_leak", F, "pipe(16,80,8,4,40)", [{"m": "leak", "o": [-8, -38], "d": 41, "w": 5, "n": 7, "sp": 1.3, "col": EAU}]),
    ("o_pipe_valve", F, "pipe(16,80,8,5);valve(48,wallTop(48)+9)", []),
    ("o_pipe_gauge", F, "pipe(16,80,8,6);gauge(52,wallTop(52)+16)", [{"m": "needle", "o": [4, -31]}]),
    ("o_sluice", F, "sluice(48,3)", [{"m": "spill", "o": [-5, 0], "w": 9.6, "d": 6, "n": 7, "sp": 0.9, "col": EAU}]),
    # V5 rigoles noyées
    ("o_channel", G, "water(8,29,88,35)", []), ("o_plank", G, "rect(42,28,12,8,WD[1]);rect(42,28,12,1,WD[3]);rect(42,31,12,1,WD[0])", []),
    # V6 voie des wagonnets
    ("o_rails", G, "rails(8,88,29)", []), ("o_rails_broken", G, "rails(8,88,29,44)", []),
    ("o_cart", F, "cart(48,56,false,1)", []), ("o_cart_tip", F, "cart(42,56,true,2)", []), ("o_helmet", F, "helmet(48,56)", []),
    # L1 fanaux de Byrsa : dessinés droits (graine 0), pendus 48 px au-dessus du pied ; la flamme est celle du jeu
    ("o_fanal", F, "fanal(48,16,0,true)", [{"m": "swing", "p": TOP}, {"m": "flame", "o": [0, -28]}]),
    ("o_fanal_off", F, "fanal(48,13,0,false)", [{"m": "swing", "p": TOP}]),
    # R1 citerne, R3 atelier
    ("o_pump", F, "pumpP(48,56,false)", []),
    ("o_pump_held", F, "pumpP(48,56,true)", [{"m": "drip", "o": [5, -2], "d": 3, "sp": 2.0, "fade": True, "col": EAU}]),
    ("o_bench", F, "bench(31,56,34);ingots(42,51,3)", []), ("o_anvil", F, "anvil(48,56)", []), ("o_crucible", F, "crucible(48,56)", []),
    ("o_ingots", F, "ingots(48,56,7)", []), ("o_ingots_s", F, "ingots(48,56,3)", []),
    # A1–A4 arènes
    ("o_chain", F, "chainH(48,16,0)", [{"m": "swing", "p": TOP}]), ("o_chain_s", F, "chainH(48,10,0)", [{"m": "swing", "p": TOP}]),
    ("o_organ", F, "organ(34,7,1)", []), ("o_organ_b", F, "organ(34,7,2)", []),
    ("o_chandelier", F, "chandelierDown(48,54)", []), ("o_lode", F, "lodeHole(48,1)", []), ("o_gnaw", F, "gnaw(43,1)", []),
    ("o_plate", F, "plate(48,53,.3,1)", []), ("o_plate_b", F, "plate(48,53,-.5,2)", []), ("o_husk", F, "tick(48,55,1)", []),
    ("o_burrow", G, "burrow(48,32,6)", []), ("o_arch", F, "archQ(48,56,'R',2)", []),
    ("o_tr_port", F, "trophyPort(48,56)", []), ("o_tr_helm", F, "trophyHelm(48,56)", []), ("o_tr_ring", F, "trophyRing(48,56)", []),
]
GLOWS = [i for i, p in enumerate(PIECES) if any(f["m"] == "glow" for f in p[3])]
# Les lueurs de la planche sont faibles (alpha 0,55 au plus) : pour le calque, tout pixel qu'elles touchent est pris en
# plein ; le jeu remet l'intensité (lo, hi).
js = ("EXPORT=true;wallTop=x=>ft(x)-47;light=()=>{};const LIST=["
      + ",".join(f"()=>{{{d}}}" for _, _, d, _ in PIECES) + "];const GLOWS=" + json.dumps(GLOWS) + ";" + f"""
const CW={CW},CH={CH},COLS={COLS},N=LIST.length+GLOWS.length,ROWS=Math.ceil(N/COLS);
document.documentElement.style.cssText='margin:0;padding:0';document.body.style.cssText='margin:0;padding:0;background:#ff00ff';document.body.innerHTML='';
const cv=document.createElement('canvas');cv.width=COLS*CW;cv.height=ROWS*CH;cv.style.cssText='display:block;width:'+cv.width+'px;height:'+cv.height+'px;max-width:none;image-rendering:pixelated';
document.body.appendChild(cv);const cx=cv.getContext('2d');views.length=0;const plain=blend;
const full=(x,y,c,a)=>{{if(a<.08)return;x=Math.round(x);y=Math.round(y);if(x<0||y<0||x>=W||y>=H)return;const i=(y*W+x)*4;img[i]=c>>16&255;img[i+1]=c>>8&255;img[i+2]=c&255}};
function render(d,withPost){{W=CW;H=CH;buf=new Int32Array(W*H).fill(-1);const id=cx.createImageData(W,H);img=id.data;
 for(let k=0;k<W*H;k++){{img[k*4]=255;img[k*4+1]=0;img[k*4+2]=255;img[k*4+3]=255}}
 DK=1;T=1;M=(x,y)=>y>=56;post.length=0;d();compose();const base=new Uint8ClampedArray(img);
 if(withPost){{blend=full;for(const f of post)f();blend=plain}}return [id,base]}}
const put=(id,i)=>cx.putImageData(id,(i%COLS)*CW,Math.floor(i/COLS)*CH);
LIST.forEach((d,i)=>put(render(d,false)[0],i));
GLOWS.forEach((gi,g)=>{{const[id,base]=render(LIST[gi],true);const a=id.data;
 for(let k=0;k<W*H;k++){{const q=k*4;if(Math.abs(a[q]-base[q])+Math.abs(a[q+1]-base[q+1])+Math.abs(a[q+2]-base[q+2])<24){{a[q]=255;a[q+1]=0;a[q+2]=255}}}}
 put(id,LIST.length+g)}});
""")
html = (root / "planches/salles-oubliees-decor-propositions.html").read_text().replace("</script>", "</script><script>" + js + "</script>", 1)
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
        box = (min(box[0], gbox[0]), min(box[1], gbox[1]), max(box[2], gbox[2]), max(box[3], gbox[3]))
        out[name + "_glow"] = [gx + box[0], gy + box[1], box[2] - box[0], box[3] - box[1], ax - box[0], ay - box[1]]
    out[name] = [ox + box[0], oy + box[1], box[2] - box[0], box[3] - box[1], ax - box[0], ay - box[1]]
    if effects:
        fx[name] = effects
(root / "assets/oubliees").mkdir(exist_ok=True)
atlas.save(root / "assets/oubliees/props.png")
(root / "assets/oubliees/props.json").write_text(json.dumps(out, separators=(",", ":")))
(root / "assets/oubliees/fx.json").write_text(json.dumps(fx, separators=(",", ":"), ensure_ascii=False))
print("ok", len(PIECES), "pièces,", len(GLOWS), "calques", atlas.size)
