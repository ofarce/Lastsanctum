#!/usr/bin/env python3
"""Exporte les pièces de la planche du sanctum en atlas pour le jeu : assets/sanctum/props.png + props.json.
Le gabarit de la planche est rejoué dans Firefox sans tête (mode EXPORT : ni ombres ni lumières, décalques opaques),
chaque pièce dans une case 96 × 64 sur fond magenta ; la capture est découpée ici.
JSON : nom → [x, y, w, h, ax, ay] (rectangle dans l'atlas, ancre relative au rectangle)."""
import json, pathlib, subprocess, sys, tempfile
from PIL import Image
root = pathlib.Path(__file__).resolve().parents[2]
CW, CH, COLS = 96, 64, 10
ANCHOR = {"foot": (48, 56), "top": (48, 6), "mid": (48, 32)}
F, G, T = "foot", "mid", "top"
MBL = "MB.concat([MB[3]])"
PIECES = [
    ("column", F, "column(48,56,20,false)"), ("column_broken", F, "column(48,56,12,true)"), ("column_stump", F, "column(47,56,6,true)"),
    ("column_marble", F, f"column(48,56,18,false,{MBL})"), ("column_marble_broken", F, f"column(48,56,8,true,{MBL})"),
    ("drum", F, "drum(48,56)"), ("rubble_a", F, "rubble(48,54,4,5)"), ("rubble_b", F, "rubble(48,54,9,4)"),
    ("boulder", F, "boulder(48,56,6)"), ("boulder_s", F, "boulder(48,56,4)"),
    ("brazier", F, "brazier(48,56,0)"), ("brazier_lit", F, "brazier(48,56,1)"),
    ("tuft_a", F, "tuft(48,56,1)"), ("tuft_b", F, "tuft(48,56,3)"), ("shrooms_a", F, "shrooms(48,54,5,4)"), ("shrooms_b", F, "shrooms(48,54,4,7)"),
    ("bones_a", F, "bones(48,54,1)"), ("bones_b", F, "bones(48,54,.2)"), ("sword", F, "sword(48,56,false)"), ("sword_rust", F, "sword(48,56,true)"),
    ("shield", F, "shield(48,54,false)"), ("shield_rust", F, "shield(48,54,true)"), ("crate", F, "crate(48,56,false)"), ("crate_broken", F, "crate(46,56,true)"),
    ("spear", F, "line(39,56,56,52,WD[2]);px(57,52,I[4]);px(58,51,I[4])"),
    ("quartz_s", F, "quartz(48,55,2,3,.8)"), ("quartz_m", F, "quartz(48,55,4,1)"), ("quartz_l", F, "quartz(48,55,5,5,1.2)"),
    ("stalag_s", F, "stalag(48,56,7)"), ("stalag_m", F, "stalag(48,56,10)"), ("stalag_l", F, "stalag(48,56,13)"),
    ("lamp", F, "lamp(48,56)"), ("sarco", F, "sarco(48,56,false)"), ("sarco_open", F, "sarco(44,56,true)"),
    ("chest", F, "chest(48,56)"),
    ("chest_open", F, "rect(42,50,13,6,S[2]);rect(42,49,13,1,I[0]);rect(42,42,13,7,S[3]);rect(42,42,13,1,S[5]);rect(42,48,13,1,S[1]);rect(53,51,2,5,S[1]);for(let i=-4;i<=4;i+=2)px(48+i,53,GLY)"),
    ("shelf_w", F, "shelf(31,56,34)"), ("shelf_n", F, "shelf(35,56,26)"), ("toppled", F, "toppled(48,52)"), ("lectern", F, "lectern(48,56)"),
    ("rack", F, "rack(48,56)"), ("dummy", F, "dummy(48,56)"), ("stand", F, "stand(48,56)"),
    ("stand_empty", F, "rect(48,44,1,12,WD[1]);rect(46,55,5,1,WD[0]);rect(45,45,7,1,WD[2])"),
    ("statue", F, "statue(48,56)"), ("menhir_a", F, "menhir(48,56,15)"), ("menhir_b", F, "menhir(48,56,17)"), ("menhir_c", F, "menhir(48,56,13)"),
    ("candle", F, "rect(48,53,1,3,Q[2])"), ("wheel", F, "wheel(48,56)"),
    ("wall_shield", F, "ell(48,52,3.6,3.6,0,(xx,yy,dx,dy)=>dx*dx+dy*dy>.55?I[3]:dx+dy<0?RU[2]:RU[1])"),
    ("slab_0", G, "slab(48,32,0)"), ("slab_1", G, "slab(48,32,1)"), ("slab_2", G, "slab(48,32,2)"), ("slab_lit", G, "slab(48,32,0,true)"),
    ("moss_a", G, "moss(48,32,16,7,1)"), ("moss_b", G, "moss(48,32,11,5,5)"), ("puddle", G, "puddle(48,32,9,4)"),
    ("sand", G, "gell(48,32,36,17,SAND,1);gring(48,32,36,17,S[1],1);gring(48,32,35,16.4,S[4],.6);for(let k=0;k<26;k++)blend(20+hs(k*1.9)*56,22+hs(k*4.1)*20,0x6a5c42,.8)"),
    ("dais", G, "dais(48,32,34,16)"),
    ("basin", G, "gell(48,32,13,6.5,S[1],1);gring(48,32,13,6.5,S[4],1);gell(48,32.5,10.5,4.8,WT[2],1);gell(46,31.5,5,2,WT[3],.8)"),
    ("scroll_a", G, "scroll(48,32,0)"), ("scroll_b", G, "scroll(48,32,1.1)"), ("scroll_c", G, "scroll(48,32,2.3)"),
    ("root_a", T, "root(48,6,24,30)"), ("root_b", T, "root(48,6,16,58)"), ("banner", T, "banner(48,6,13)"),
]
js = "EXPORT=true;const LIST=[" + ",".join(f"()=>{{{d}}}" for _, _, d in PIECES) + "];" + f"""
const CW={CW},CH={CH},COLS={COLS},ROWS=Math.ceil(LIST.length/COLS);
document.documentElement.style.cssText='margin:0;padding:0';document.body.style.cssText='margin:0;padding:0;background:#ff00ff';document.body.innerHTML='';
const cv=document.createElement('canvas');cv.width=COLS*CW;cv.height=ROWS*CH;cv.style.cssText='display:block;width:'+cv.width+'px;height:'+cv.height+'px;max-width:none;image-rendering:pixelated';
document.body.appendChild(cv);const cx=cv.getContext('2d');
LIST.forEach((d,i)=>{{W=CW;H=CH;buf=new Int32Array(W*H).fill(-1);const id=cx.createImageData(W,H);img=id.data;
 for(let k=0;k<W*H;k++){{img[k*4]=255;img[k*4+1]=0;img[k*4+2]=255;img[k*4+3]=255}}
 DK=1;T=0;M=()=>true;post.length=0;d();compose();cx.putImageData(id,(i%COLS)*CW,Math.floor(i/COLS)*CH)}});
"""
html = (root / "tools/sanctum/template.html").read_text() + "<script>" + js + "</script>"
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
(root / "assets/sanctum").mkdir(exist_ok=True)
atlas.save(root / "assets/sanctum/props.png")
(root / "assets/sanctum/props.json").write_text(json.dumps(out, separators=(",", ":")))
print("ok", len(out), atlas.size)
