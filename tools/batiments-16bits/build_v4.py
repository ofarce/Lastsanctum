#!/usr/bin/env python3
"""Assemble planches/assets/batiments-v4-planches.js et planches/batiments-v4-propositions.html (Scierie, Archerie, Armurerie).

moteur de creuset-planches.js + outils de batiments-v2-designs.js (avant GROUPS)
+ modèles de batiments-v3-designs.js, puis finition 16 bits :
rampes sans trame, contour coloré, halos en paliers, contour des pièces animées.

    python3 tools/batiments-16bits/build_v4.py
"""
from pathlib import Path

R = Path(__file__).resolve().parents[2] / "planches/assets"
src = (R / "creuset-planches.js").read_text().split("\n")
i_prop = next(i for i, l in enumerate(src) if l.startswith("// ---------- propositions"))
i_vig = next(i for i, l in enumerate(src) if l.startswith("function vignette"))
head = "\n".join(src[:i_prop]).replace("const CRE=(()=>{", "const BAT=(()=>{", 1)
v2 = (R / "batiments-v2-designs.js").read_text().split("\n")
tools = "\n".join(v2[:next(i for i, l in enumerate(v2) if l.startswith("const GROUPS"))])
tail = "\n".join(src[i_vig:]).replace(
    "return{ITEMS,vignette,",
    "return{ITEMS,GROUPS,vignette,floorScene,setWork(v){K=v},", 1)
v3 = (R / "batiments-v3-designs.js").read_text()
v3h = v3[:v3.index("const GROUPS")]
js = "\n".join([head, tools, v3h, (R / "batiments-v4-designs.js").read_text(),
                "function floorScene(){const S=new Scene();S.bake(floor(),[]);return S}", tail])


def patch(a, b):
    global js
    assert a in js, a[:60]
    js = js.replace(a, b, 1)


# 1. rampes sans trame
patch("function rp(R,v,x,y){const n=R.length-1,i=Math.floor(v*n+bay(x,y));return R[i<0?0:i>n?n:i]}",
      "function rp(R,v,x,y){const n=R.length-1,i=Math.round(v*n);return R[i<0?0:i>n?n:i]}")
# 2. contour coloré : ton assombri du pixel voisin
patch("if((x>0&&s[i-1]!==-1)||(x<w-1&&s[i+1]!==-1)||(y>0&&s[i-w]!==-1)||(y<h-1&&s[i+w]!==-1))n[i]=col}",
      "const nb=y<h-1&&s[i+w]!==-1?s[i+w]:x<w-1&&s[i+1]!==-1?s[i+1]:x>0&&s[i-1]!==-1?s[i-1]:y>0&&s[i-w]!==-1?s[i-w]:-1;"
      "if(nb!==-1)n[i]=sh(nb&0xffffff,-.68)}")
# 3. halos de nuit en paliers francs
patch("Math.floor(f*5+bay(x,y))/5", "Math.floor(f*4+.5)/4")
# 4. pièces animées sur leur propre calque, contournées (sauf pixels lumineux et traits fins) : Scene.compose(t)
patch(" render(g,hour,t){",
      " compose(t){const F=this.F,W=this.P.w,H=this.P.h;F.c.set(this.P.c);const D=this.D||(this.D=new Pix(W,H));D.c.fill(-1);D.bx0=W;D.by0=H;D.bx1=-1;D.by1=-1;"
      "for(const d of this.dyn)d(D,t,this);"
      "const s=D.c,o=new Int32Array(s),ok=i=>s[i]!==-1&&!(s[i]&0x1000000);"
      "for(let y=1;y<H-1;y++)for(let x=1;x<W-1;x++){const i=y*W+x;if(!ok(i))continue;let n=0;"
      "for(const k of[-W-1,-W,-W+1,-1,1,W-1,W,W+1])if(ok(i+k))n++;if(n<3)continue;"
      "for(const k of[-W,-1,1,W])if(s[i+k]===-1)o[i+k]=sh(s[i]&0xffffff,-.68)}"
      "for(let i=0;i<o.length;i++)if(o[i]!==-1)F.c[i]=o[i];return F}\n render(g,hour,t){")
patch("const F=this.F;F.c.set(this.P.c);for(const d of this.dyn)d(F,t,this);", "const F=this.compose(t);")
patch("const t=f/fps,F=S.F;F.c.set(S.P.c);for(const d of S.dyn)d(F,t,S);", "const t=f/fps,F=S.compose(t);")

# 5. export : garder le repère 320 × 240 pendant le rendu des images (les animations projettent à chaque image)
patch("S.bake(()=>-1,b.objs)}finally{configure(24,132,136,66,102)}", "S.bake(()=>-1,b.objs)}catch(e){configure(24,132,136,66,102);throw e}")
patch(" return{sheet,base,portrait:por,", " configure(24,132,136,66,102);return{sheet,base,portrait:por,")

(R / "batiments-v4-planches.js").write_text(js + "\n")
print("ok", len(js))

# ---------- page autonome ----------
import base64, io, json
from PIL import Image
ROOT = R.parents[1]
ARTS = {"creuset": "da-creuset"}

def crop(art):  # ancre (160,168) du sprite placée en (66,102) dans la vignette 132 x 136
    im = Image.open(ROOT / "assets/baked/buildings" / f"{art}_base.png").convert("RGBA").crop((94, 66, 226, 202))
    buf = io.BytesIO(); im.save(buf, "PNG", optimize=True)
    return "data:image/png;base64," + base64.b64encode(buf.getvalue()).decode()

tpl = (Path(__file__).parent / "template_v4.html").read_text()
out = tpl.replace("/*ENGINE*/", js).replace("/*ACTUELS*/{}", json.dumps({k: crop(v) for k, v in ARTS.items()}))
dst = ROOT / "planches/batiments-v4-propositions.html"
dst.write_text(out)
print(dst, len(out))
