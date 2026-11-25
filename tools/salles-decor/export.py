#!/usr/bin/env python3
"""Exporte les pièces de la planche du monastère (planches/couloirs-boss-decor-propositions.html) en atlas :
assets/monastere/props.png + props.json, au même format que tools/sanctum/export.py (nom → [x, y, w, h, ax, ay]).
Chaque pièce est dessinée dans une case 96 × 64 dont le sol commence en y = 56 : les pièces murales (arcades,
niches, portes, ossuaire, rosace) se dessinent sur la paroi au-dessus, ancrées au pied du mur. La paroi du jeu
fait environ 48 px (13 sur la planche) : l'export la redéfinit (wallTop) pour que ces pièces la remplissent."""
import json, pathlib, subprocess, sys, tempfile
from PIL import Image
root = pathlib.Path(__file__).resolve().parents[2]
CW, CH, COLS = 96, 64, 10
ANCHOR = {"foot": (48, 56), "top": (48, 6), "mid": (48, 32), "wtop": (48, 9)}
F, G, T, WT = "foot", "mid", "top", "wtop"
PIECES = [
    # couloirs
    ("arcade", F, "arcade(32,64)"), ("well", F, "well(48,56)"), ("herbs", G, "herbs(38,28,20,8,1)"), ("herbs_b", G, "herbs(36,28,24,9,2)"),
    ("niche", F, "niche(48,0,1)"), ("niche_lit", F, "niche(48,1,2)"), ("offering", F, "offering(46,56,3)"),
    ("celldoor", F, "cellDoor(48,1,false)"), ("celldoor_broken", F, "cellDoor(46,1,true)"),
    ("pallet", F, "pallet(48,56)"), ("jug", F, "jug(48,56)"), ("stool", F, "stool(48,56,false)"), ("stool_top", F, "stool(48,56,true)"),
    ("bowl", F, "ell(48,55,2,1,CL[1]);px(47,54,CL[2])"),
    ("table", F, "table(16,56,64,1)"), ("table_s", F, "table(26,56,44,2)"), ("cauldron", F, "cauldron(48,56)"),
    ("bell", F, "bell(46,54)"), ("rope_s", WT, "rope(48,24,1)"), ("rope_l", WT, "rope(48,36,2)"), ("timber", F, "fallenTimber(48,53,.25)"),
    ("ossuary", F, "ossuary(33,63,1)"), ("ossuary_b", F, "ossuary(33,63,2)"), ("bonepile", F, "bonepile(48,55,1)"), ("bonepile_b", F, "bonepile(48,55,2)"),
    # arènes
    ("stalls", F, "stalls(30,56,36,1)"), ("stalls_b", F, "stalls(30,56,36,2)"), ("candelabra", F, "candelabra(48,56)"),
    ("priedieu", F, "priedieu(48,56,false)"), ("priedieu_top", F, "priedieu(46,55,true)"),
    ("shards_a", G, "shards(48,32,1,6)"), ("shards_b", G, "shards(48,32,2,5)"), ("rose", F, "rose(48)"), ("gbanner", F, "gbanner(48,22,24)"),
    ("runner", G, "runner(36,4,60,24)"), ("altar", F, "altar(48,56)"),
    ("bench_h", F, "chapterBench(32,64,52)"), ("bench_v", G, "chapterSide(46,16,48)"),
    ("gisant", F, "gisant(48,56,false)"), ("gisant_open", F, "gisant(48,56,true)"),
    ("vein_a", T, "vein(48,6,28,1,.4)"), ("vein_b", T, "vein(48,6,28,2,.2)"), ("vein_c", T, "vein(48,6,28,3,-.2)"), ("vein_d", T, "vein(48,6,28,4,-.4)"),
    ("flesh_a", G, "flesh(48,32,26,10,3)"), ("flesh_b", G, "flesh(48,32,12,5,1)"), ("crater", G, "crater(48,32,10)"),
    ("pustule", F, "pustule(48,56,3,1)"), ("pustule_l", F, "pustule(48,56,3.5,2)"), ("ichor", G, "ichor(48,32,7,3)"),
    ("skull_big", F, "skullBig(48,56)"), ("mitre", F, "mitre(48,56)"), ("veil", F, "veil(48,56)"),
    ("seal_ring", G, "sealRing(48,32,26)"), ("plinth", G, "dais(48,32,22,10)"), ("arch", F, "arch(48,56,64)"),
]
js = "EXPORT=true;wallTop=x=>ft(x)-47;const LIST=[" + ",".join(f"()=>{{{d}}}" for _, _, d in PIECES) + "];" + f"""
const CW={CW},CH={CH},COLS={COLS},ROWS=Math.ceil(LIST.length/COLS);
document.documentElement.style.cssText='margin:0;padding:0';document.body.style.cssText='margin:0;padding:0;background:#ff00ff';document.body.innerHTML='';
const cv=document.createElement('canvas');cv.width=COLS*CW;cv.height=ROWS*CH;cv.style.cssText='display:block;width:'+cv.width+'px;height:'+cv.height+'px;max-width:none;image-rendering:pixelated';
document.body.appendChild(cv);const cx=cv.getContext('2d');views.length=0;
LIST.forEach((d,i)=>{{W=CW;H=CH;buf=new Int32Array(W*H).fill(-1);const id=cx.createImageData(W,H);img=id.data;
 for(let k=0;k<W*H;k++){{img[k*4]=255;img[k*4+1]=0;img[k*4+2]=255;img[k*4+3]=255}}
 DK=1;T=0;M=(x,y)=>y>=56;post.length=0;d();compose();cx.putImageData(id,(i%COLS)*CW,Math.floor(i/COLS)*CH)}});
"""
html = (root / "planches/couloirs-boss-decor-propositions.html").read_text().replace("</script>", "</script><script>" + js + "</script>", 1)
html = html.replace("requestAnimationFrame(loop)", "0")
rows = -(-len(PIECES) // COLS)
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
        if not (c[0] > 240 and c[1] < 16 and c[2] > 240):
            dst[x, y] = c + (255,)
out = {}
for i, (name, anchor, _) in enumerate(PIECES):
    ox, oy = (i % COLS) * CW, (i // COLS) * CH
    box = atlas.crop((ox, oy, ox + CW, oy + CH)).getbbox()
    if box is None:
        sys.exit("pièce vide : " + name)
    ax, ay = ANCHOR[anchor]
    out[name] = [ox + box[0], oy + box[1], box[2] - box[0], box[3] - box[1], ax - box[0], ay - box[1]]
(root / "assets/monastere").mkdir(exist_ok=True)
atlas.save(root / "assets/monastere/props.png")
(root / "assets/monastere/props.json").write_text(json.dumps(out, separators=(",", ":")))
print("ok", len(out), atlas.size)
