#!/usr/bin/env python3
"""Assemble planches/assets/autels-16bits.js : les autels retenus (autels-planches.js), finis en 16 bits.

Mêmes modèles, mêmes volumes ; seule la finition change, comme pour les bâtiments (tools/batiments-16bits) :
rampes sans trame, contour coloré, portrait net. Ajoute l'état « au repos » (AUT.setWork(0)) : incrustations
et yeux éteints, braises au lieu des flammes, un quart des lueurs. Le marbre de Sigil est assombri ici
(charte : gris veiné peu éclatant), ce que faisait après coup tools/charte/sigil_marbre.py.

    python3 tools/autels-16bits/build.py && python3 tools/autels-16bits/export.py
"""
from pathlib import Path

R = Path(__file__).resolve().parents[2] / "planches/assets"
js = (R / "autels-planches.js").read_text()


def patch(a, b, n=1):
    global js
    assert js.count(a) == n, (js.count(a), a[:70])
    js = js.replace(a, b)


# état : 1 = on prie à l'autel, 0 = au repos
patch("const AUT=(()=>{", "const AUT=(()=>{\nlet K=1;")
# 1. rampes sans trame
patch("function rp(R,v,x,y){const n=R.length-1,i=Math.floor(v*n+bay(x,y));return R[i<0?0:i>n?n:i]}",
      "function rp(R,v,x,y){const n=R.length-1,i=Math.round(v*n);return R[i<0?0:i>n?n:i]}")
# 2. contour coloré : ton assombri du pixel voisin
patch("if((x>0&&s[i-1]!==-1)||(x<w-1&&s[i+1]!==-1)||(y>0&&s[i-w]!==-1)||(y<h-1&&s[i+w]!==-1))n[i]=col}",
      "const nb=y<h-1&&s[i+w]!==-1?s[i+w]:x<w-1&&s[i+1]!==-1?s[i+1]:x>0&&s[i-1]!==-1?s[i-1]:y>0&&s[i-w]!==-1?s[i-w]:-1;"
      "if(nb!==-1)n[i]=sh(nb&0xffffff,-.68)}")
#    la statue cherchait ses pieds en écartant la couleur du contour : les chercher avant de la contourner
patch("P.outline();let bot=0;", "let bot=0;")
patch("P.get(x,y)!==OUTL){bot=y;break}", "P.get(x,y)!==OUTL){bot=y;break}\n P.outline();")
# 3. halos de nuit en paliers francs (aperçu seulement)
patch("Math.floor(f*5+bay(x,y))/5", "Math.floor(f*4+.5)/4")
# 4. marbre de Sigil assombri à la source
patch("const R_=a=>a.map(ci);",
      "const R_=a=>a.map(ci);\n"
      "function dk(c){const n=ci(c);let r=(n>>16&255)/255,g=(n>>8&255)/255,b=(n&255)/255;const v=Math.max(r,g,b),s=v>0?(v-Math.min(r,g,b))/v:0;"
      "if(s>=.16||v<=.42||v>=.92)return n;const k=(.42+(v-.42)*.55)/v,f=x=>Math.max(0,Math.min(255,Math.round(x*255)));"
      "return f(r*k*.97)<<16|f(g*k*.99)<<8|f(b*k*1.04)}")
patch("const MARBLE=R_(['#3c3c42','#535259','#6b6a72','#85848b','#9e9da3','#b4b2b6','#c6c4c6']);",
      "const MARBLE=R_(['#3c3c42','#535259','#6b6a72','#85848b','#9e9da3','#b4b2b6','#c6c4c6']).map(dk);")
patch("const SPR=new Map();", "for(const k of['body','drape'])SMAT.sigil[k]=SMAT.sigil[k].map(dk);\nconst SPR=new Map();")
# 5. boucles exactes sur 2 s, et repos : braises, un quart des lueurs
patch("return(F,t)=>{const k=Math.floor(t*10+sx*.37)%4,h=Math.round((3+((k*5)%3))*sz);for(let j=0;j<h;j++){const w=Math.max(0,Math.round((h-j)*.45*sz)),sway=Math.round(Math.sin(t*7+j*.8+sx)*.6*(j/h));",
      "return(F,t)=>{const z=K?sz*1.6:sz*.45,k=Math.floor(t*10+sx*.37)%4,h=Math.max(1,Math.round((3+((k*5)%3))*z));for(let j=0;j<h;j++){const w=Math.max(0,Math.round((h-j)*.45*z)),sway=Math.round(Math.sin(t*2*Math.PI+j*.8+sx)*.6*(j/h));")
patch("return(F,t)=>{for(let k=0;k<n;k++){const p=((t*.5+hash(k,1,seed))%1),x=Math.round(cx+(hash(k,2,seed)-.5)*spread*2+Math.sin(t*1.3+k)*2)",
      "return(F,t)=>{for(let k=0,N=K?n:Math.ceil(n/4);k<N;k++){const p=((t*.5+hash(k,1,seed))%1),x=Math.round(cx+(hash(k,2,seed)-.5)*spread*2+Math.sin(t*Math.PI+k)*2)")
# 6. export : incrustations et yeux éteints au repos, portrait net, échelle déclarée
patch("S.bake(()=>-1,b.objs);if(b.fx)S.dyn.push(...b.fx(S))}finally{",
      "S.bake(()=>-1,b.objs);if(b.fx)S.dyn.push(...b.fx(S));"
      "if(!K)for(let i=0;i<S.P.c.length;i++){const v=S.P.c[i];if(v>=0&&v&0x1000000)S.P.c[i]=sh(v,-.5)&0xffffff}}finally{")
patch("k=Math.min(.5,120/w,124/h);pg.imageSmoothingEnabled=true;pg.imageSmoothingQuality='high';",
      "k=Math.min(1,120/w,124/h);pg.imageSmoothingEnabled=k<1;pg.imageSmoothingQuality='high';")
patch("meta:{anchor:[160,168],top,bottom:bot,anim:", "meta:{anchor:[160,168],top,bottom:bot,scale:1,anim:")
patch("return{GODS,vignette,", "return{GODS,setWork(v){K=v},vignette,")
# 7. pas de l'unité au choix (24 : emprise 3 × 3 cases ; 16 : emprise 2 × 2 du jeu, dessinée directement)
patch("function exportSprite(god,frames=24,fps=12){", "function exportSprite(god,frames=24,fps=12,U=24){")
patch("configure(24,320,240,160,168);let S;", "configure(U,320,240,160,168);let S;")

(R / "autels-16bits.js").write_text("// Produit par tools/autels-16bits/build.py : ne pas modifier à la main.\n" + js)
print("ok", len(js))
