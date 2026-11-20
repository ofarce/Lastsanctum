// L'Oublieux (Église des Oublieux) et les trois mages cristallisés (École de magie cristallisée) :
// cinq modèles chacun, au standard de la refonte 16 bits (moteur engineer-colosse.js : R, MAT, buf, blob, rect, px,
// render ; rampes de refonte-16bits.js). Paliers francs sans trame, contour teinté, lumière en haut à gauche.
// Profil tourné vers la droite (le jeu retourne le sprite). Rig procédural : poses continues, membres en cinématique
// inverse, tissus en retard sur le corps. Les lueurs et particules vont sur un calque à part, sans contour.
// Charte : pas d'or (Credo), pas de cyan (Exilés) ; cendre et lueur pâle pour l'Oublieux, vert de Medeina pour la
// Guérisseuse, orange d'Indra pour le Chantre, bleu-violet d'Aether pour l'Envoûteur.
// Expose : PERSO = {ROLES, LIST, ANIMS, SIZE, frame(rôle, variante, anim, t) → {c, fx}}.
'use strict';
for(const[k,v]of Object.entries({
 wool:['#141519','#272a33','#3e4250','#5a5f72','#848a9e'],
 ash:['#131218','#33313c','#55525f','#807c8a','#b6b2be'],     // bure cendre
 lin2:['#26262c','#68666c','#a2a0a2','#d0cec8','#f6f4ea'],    // linceul blême
 lueur:['#1e4034','#5cb088','#b0f0cc','#e8fff2','#ffffff'],   // lueur des Limbes (veilleuses)
 nuit:['#0a0a12','#1a1a28','#2c2c40','#464664','#6c6c98'],    // drap de nuit
 osier:['#22160a','#5a3e1c','#8e6a34','#bc9650','#e2c682'],
 med:['#0a2212','#1c5a2e','#32924a','#6cc870','#c8f6b0'],     // vert de Medeina
 foret:['#08160c','#143a20','#22582e','#3a7c40','#64a45a'],   // manteau vert sombre
 cmed:['#0a3a2a','#1f9a6a','#5ce8a8','#c0ffe0','#ffffff'],    // cristal vert
 cind:['#4a1a04','#c25a12','#ff9a3a','#ffd68a','#fffbe0'],    // cristal orange
 aet:['#100a2a','#2a1e66','#4a3aa8','#7a6ae0','#b8b0ff'],     // bleu-violet d'Aether
 caet:['#1e0a4a','#5a3ac8','#9a7aff','#d6c8ff','#ffffff'],    // cristal violet
 hairw:['#3a3a44','#8a8a96','#b8b8c2','#dcdce2','#ffffff'],   // cheveux blancs
 hairr:['#2a0e06','#6a2a10','#a04a1c','#c8742e','#e8a050'],   // cheveux roux
}))if(!R[k]){R[k]=v;MAT.push(k)}

const PERSO=(()=>{
const TAU=Math.PI*2,cl=(v,a=0,b=1)=>Math.max(a,Math.min(b,v)),lerp=(a,b,t)=>a+(b-a)*t,ease=t=>t*t*(3-2*t);
const sm=(a,b,t)=>ease(cl((t-a)/(b-a))),L2=(p,q,t)=>[lerp(p[0],q[0],t),lerp(p[1],q[1],t)];
const hash=(x,y)=>{const v=Math.sin(x*12.9898+y*78.233)*43758.5453;return v-Math.floor(v)};
const W=64,H=56,AX=28,G=50;   // cadre, pieds en (AX, G)

// ---------- primitives ----------
function seg(b,x0,y0,x1,y1,r0,r1,mat,bias=0){const n=Math.max(2,Math.ceil(Math.hypot(x1-x0,y1-y0)*2.2));
 for(let i=0;i<=n;i++){const t=i/n,r=Math.max(.75,lerp(r0,r1,t));blob(b,lerp(x0,x1,t),lerp(y0,y1,t),r,r,mat,bias)}}
function over(b,x,y,mat,s){x=Math.round(x);y=Math.round(y);if(x<0||y<0||x>=b.w||y>=b.h||b.m[y*b.w+x]<0)return;px(b,x,y,mat,s)}
function dot(b,x,y,mat,s=.9){px(b,Math.round(x),Math.round(y),mat,s)}
function ln(b,x0,y0,x1,y1,mat,l=.7){const n=Math.max(Math.abs(x1-x0),Math.abs(y1-y0))*2|0||1;
 for(let i=0;i<=n;i++){const t=i/n;dot(b,lerp(x0,x1,t),lerp(y0,y1,t),mat,typeof l==='function'?l(t):l)}}
function ik(a,c,l1,l2,bend){const dx=c[0]-a[0],dy=c[1]-a[1],d=cl(Math.hypot(dx,dy),Math.abs(l1-l2)+.05,l1+l2-.05),base=Math.atan2(dy,dx),
 al=Math.acos(cl((l1*l1+d*d-l2*l2)/(2*l1*d),-1,1)),an=base+bend*al;return[a[0]+Math.cos(an)*l1,a[1]+Math.sin(an)*l1]}
function gem(b,x,y,r,mat,l=0){x=Math.round(x);y=Math.round(y);for(let dy=-r;dy<=r;dy++){const w=r-Math.abs(dy);for(let dx=-w;dx<=w;dx++)px(b,x+dx,y+dy,mat,cl(.6-dx*.17-dy*.12+l,.05,.99))}}
function shard(b,x,y,h,mat,l=0,w=1){x=Math.round(x);y=Math.round(y);for(let i=0;i<h;i++){const ww=(i===0||i===h-1)?0:w;for(let dx=0;dx<=ww;dx++)px(b,x+dx,y-h+1+i,mat,cl(.95-i/h*.4-dx*.3+l,.05,.99))}}
// calque des lueurs : F = liste de [x, y, matière, clarté], peinte sans contour par-dessus le sprite
const fdot=(F,x,y,mat,l=.9)=>{F.push([Math.round(x),Math.round(y),mat,cl(l,0,.99)])};
function fplus(F,x,y,mat,l=.95){fdot(F,x,y,mat,l);fdot(F,x-1,y,mat,l-.25);fdot(F,x+1,y,mat,l-.25);fdot(F,x,y-1,mat,l-.25);fdot(F,x,y+1,mat,l-.25)}
function fring(F,cx,cy,rx,ry,mat,l,n,rot=0,skip=1){for(let i=0;i<n;i++){if(skip>1&&i%skip)continue;const a=i/n*TAU+rot;fdot(F,cx+Math.cos(a)*rx,cy+Math.sin(a)*ry,mat,l)}}
function farc(F,cx,cy,r,a0,a1,mat,l){const n=Math.max(2,Math.ceil(r*(a1-a0)*1.2));for(let i=0;i<=n;i++){const a=lerp(a0,a1,i/n);fdot(F,cx+Math.cos(a)*r,cy+Math.sin(a)*r,mat,l)}}
function fstar(F,x,y,mat,r){fdot(F,x,y,mat,.99);for(let i=1;i<=r;i++){const l=.95-i*.2;fdot(F,x+i,y,mat,l);fdot(F,x-i,y,mat,l);fdot(F,x,y+i,mat,l);fdot(F,x,y-i,mat,l)}}
function lantern(b,F,x,y,glow,mat='lueur'){x=Math.round(x);y=Math.round(y);px(b,x,y,'iron',.6);rect(b,x-1,y+1,3,1,'iron',.1);rect(b,x-1,y+2,3,3,mat,.15+glow*.3);rect(b,x-1,y+5,3,1,'iron',-.15);
 fdot(F,x,y+3,mat,.99);if(glow>.42){fdot(F,x-1,y+3,mat,.8);fdot(F,x+1,y+3,mat,.8)}}
function panier(b,x,y,w,h){x=Math.round(x);y=Math.round(y);for(let j=0;j<h;j++){const k=j>h-3?1:0;for(let i=k;i<w-k;i++)px(b,x+i,y+j,'osier',((i+j)&1?.68:.44)-i*.02)}rect(b,x-1,y,w+2,1,'osier',.2)}

// ---------- tête ----------
function headBack(b,V,J,P){const M=V.m,hx=J.hd[0],hy=J.hd[1],sw=P.sw||0;
 if(V.hair==='braid'){let x=hx-4,y=hy;for(let i=0;i<8;i++){const t=i/7;blob(b,x-t*2-sw*t*t*1.6,y+i*1.9,1.5-(t>.8?.4:0),1.4,M.hair,-.05-(i&1)*.12)}dot(b,hx-6-sw*1.6,hy+15,V.cry||'lin2',.9)}
 if(V.hair==='long')for(let i=0;i<10;i++){const t=i/9;blob(b,hx-3.4-sw*t*t,hy+1+i*1.2,3-t*.8,1.6,M.hair,-.12)}
 if(V.head==='veil')for(let y=-3;y<=14;y++){const t=(y+3)/17,x0=hx-5.6-t*1.6-sw*t*t*1.4,x1=hx-1+(y>5?-1:0);for(let x=Math.round(x0);x<=x1;x++)px(b,x,Math.round(hy+y),M.veil,.55-t*.2-(x1-x)*.03-((x&1)&&y>4?.1:0))}
 if(V.peak){const tx=hx-8-sw*1.2,ty=hy-6+Math.abs(sw)*.6;seg(b,hx-3,hy-3.5,tx,ty,2.4,.8,M.hood,-.05)}
 if(V.cape){const top=J.sh[1]-1,bot=G-4;for(let y=Math.round(top);y<=bot;y++){const t=(y-top)/(bot-top),x0=J.sh[0]-4-t*4.5-sw*t*t*1.8,x1=lerp(J.sh[0],J.hip[0],cl(t*2))+1;
   for(let x=Math.round(x0);x<=x1;x++)px(b,x,y,V.cape,.5-t*.12-(x1-x)*.02-(((x+y)%4===0)&&t>.3?.1:0))}}}
function head(b,V,J,P){const M=V.m,hx=J.hd[0],hy=J.hd[1],K=V.head,sk=M.skin||'skin';
 const face=()=>{blob(b,hx,hy,4.3,4.3,sk,.08);rect(b,Math.round(hx)-2,Math.round(hy)+2,6,3,sk,.05)};
 const eye=(dy=0)=>{if(V.blind)return;const ex=Math.round(hx)+2,ey=Math.round(hy)+dy;if(P.blink){px(b,ex,ey,sk,.18);px(b,ex+1,ey,sk,.18)}else{px(b,ex,ey,'eye',.1);px(b,ex+1,ey,'eye',.95)}};
 const mouth=()=>{const mx=Math.round(hx)+2,my=Math.round(hy)+3;if(P.sing){px(b,mx+1,my,'eye',.05);px(b,mx+1,my+1,'eye',.05);px(b,mx,my,'eye',.05)}else{px(b,mx,my,sk,.12);px(b,mx+1,my,sk,.12)}};
 if(K==='hood'){blob(b,hx-1,hy-.5,5.4,5.2,M.hood,.12);
  if(V.mask){blob(b,hx+1.6,hy+1,2.7,3.3,V.mask,.25);px(b,Math.round(hx)+3,Math.round(hy),'eye',.05);px(b,Math.round(hx)+3,Math.round(hy)+1,'eye',.05)}
  else{blob(b,hx+1.5,hy+1,2.6,3,sk,-.2);eye(1);if(P.sing){px(b,Math.round(hx)+3,Math.round(hy)+3,'eye',.05)}}
  blob(b,hx,hy+5.5,3.2,1.6,M.hood,.05)}
 else{face();eye();mouth();
  if(V.beard){blob(b,hx+1.6,hy+4.6,2.9,2.7,M.beard||M.hair,-.05,(x,y)=>y>=hy+2);if(P.sing)px(b,Math.round(hx)+3,Math.round(hy)+3,'eye',.05)}
  if(V.blind){rect(b,Math.round(hx)-4,Math.round(hy)-1,9,2,'lin2',.15);px(b,Math.round(hx)-5,Math.round(hy),'lin2',.5);px(b,Math.round(hx)-6,Math.round(hy)+1,'lin2',.4)}
  if(K==='bare'&&M.hair){blob(b,hx-.6,hy-1.2,4.9,4.5,M.hair,.1,(x,y)=>y<=hy-2.2||(x<=hx-2&&y<=hy+2.5));
   if(V.hair==='bun')blob(b,hx-5.2,hy-2.6,2.3,2.3,M.hair,.05);
   if(V.hair==='long'||V.hair==='braid')blob(b,hx-3.6,hy+1,2,3,M.hair,-.05)}
  if(K==='veil')blob(b,hx-.6,hy-1.6,5.1,4.6,M.veil,.15,(x,y)=>y<=hy-2.2||x<=hx-2.2);
  if(K==='hat'){blob(b,hx-.4,hy-4.6,4,3.4,M.hat,.12,(x,y)=>y<=hy-3);rect(b,Math.round(hx)-8,Math.round(hy)-3,16,1,M.hat,.25);rect(b,Math.round(hx)-7,Math.round(hy)-2,14,1,M.hat,-.15)}
  if(K==='turban'){blob(b,hx-.4,hy-3,5.1,3.5,M.turban,.15,(x,y)=>y<=hy-1.6);for(let i=-3;i<=3;i+=2)over(b,hx+i,hy-3+((i+3)>>1&1),M.turban,.3);
   px(b,Math.round(hx)+3,Math.round(hy)-3,V.cry,.99);blob(b,hx-5,hy,1.4,2.4,M.turban,-.1)}
  if(V.halfc)for(let y=-5;y<=1;y++)for(let x=-5;x<=4;x++){if(x+y*.6>-1.2)continue;over(b,hx+x,hy+y,V.cry,cl(.55-x*.07-y*.07+(hash(x,y)>.6?.25:0),.1,.99))}
  if(V.halfc){shard(b,hx-3,hy-4,3,V.cry,.05,0);shard(b,hx-1,hy-4.6,2,V.cry,.05,0)}}}

// ---------- corps ----------
function man(V,P){
 const b=buf(W,H),F=[],M=V.m,X=AX+(P.x||0),a=P.lean||0,LL=11+(V.tall??1),TL=9;b.fx=F;
 const hip=[X-Math.sin(a)*2,G-2-LL+(P.crouch||0)+(P.bob||0)];
 const sh=[hip[0]+Math.sin(a)*TL,hip[1]-Math.cos(a)*TL+(P.ub||0)];
 const hd=[sh[0]+.5+Math.sin(a)*5.5,sh[1]-Math.cos(a)*5.5+(P.hy||0)],sj=[sh[0],sh[1]+1.5];
 let hF=[sj[0]+P.hf[0],sj[1]+P.hf[1]],hB=[sj[0]+P.hb[0],sj[1]+P.hb[1]];
 if(P.reach)hF=L2(hF,[X+P.reach[0],P.reach[1]],P.reach[2]);
 if(P.stow)hF=L2(hF,[sj[0]+P.stow[0],sj[1]+P.stow[1]],P.stow[2]);
 const fF=[X+P.ff[0],G-2-P.ff[1]],fB=[X+P.fb[0],G-2-P.fb[1]];
 const J={X,hip,sh,hd,sj,hF,hB,fF,fB};
 const arm=(h,s,ms,mg)=>{const el=ik(sj,h,5,5,1);seg(b,sj[0],sj[1],el[0],el[1],1.9,1.7,ms,s);seg(b,el[0],el[1],h[0],h[1],1.6,1.5,ms,s);blob(b,h[0],h[1],1.8,1.7,mg,.1+s)};
 const boot=(f,s)=>rect(b,Math.round(f[0])-2,Math.round(f[1])-1,5,3,M.boot,s);
 const leg=(f,s)=>{const kn=ik(hip,f,LL/2+.3,LL/2+.3,-1);seg(b,hip[0],hip[1],kn[0],kn[1],2.3,2,M.leg,s);seg(b,kn[0],kn[1],f[0],f[1],1.9,1.6,M.leg,s);boot(f,s)};
 headBack(b,V,J,P);
 if(V.back)V.back(b,J,P,F,V);
 arm(hB,-.28,M.sleeveB||M.sleeve,M.gloveB||M.glove);
 if(V.robe===2){boot(fB,-.25);boot(fF,0)}else{leg(fB,-.25);leg(fF,0)}
 if(V.robe){const y0=Math.round(hip[1])-1,y1=V.robe===2?G-4:Math.round(hip[1])+6,cx1=V.robe===2?(fF[0]+fB[0])/2:hip[0],sp=Math.abs(fF[0]-fB[0]);
  for(let y=y0;y<=y1;y++){const v=(y-y0)/Math.max(1,y1-y0),hw=3.7+v*(V.robeW||2.4)+v*sp*(V.robe===2?.3:.12),cx=lerp(hip[0],cx1,v)+(P.sw||0)*v*v*(V.robe===2?1:.5),xc=Math.round(cx);
   for(let x=Math.round(cx-hw);x<Math.round(cx+hw);x++){const u=(x-cx+hw)/(2*hw),fold=((x-xc+40)%3===0&&v>.3)?-.1:0;
    px(b,x,y,(V.hem&&y>=y1-1)?V.hem:M.robe,cl(.74-u*.48-v*.06+fold,.05,.99))}}}
 seg(b,hip[0],hip[1]-1,sh[0],sh[1]+1.5,V.slim?3.6:4.2,V.slim?3.9:4.6,M.torso);
 if(M.belt)rect(b,Math.round(hip[0])-4,Math.round(hip[1])-2,8,2,M.belt,.05);
 if(V.mid)V.mid(b,J,P,F,V);
 head(b,V,J,P);
 if(hB[0]>sj[0]+3)blob(b,hB[0],hB[1],1.8,1.7,M.gloveB||M.glove,-.1);
 blob(b,sj[0],sj[1]-.6,2.6,2.2,M.armF||M.sleeve,.15);
 arm(hF,0,M.armF||M.sleeve,M.handF||M.glove);
 if(V.front)V.front(b,J,P,F,V);
 if(P.item){let ix,iy;if(P.item==='sol'){ix=X+13;iy=G-2;if(Math.sin(P.t*9)>.5)fdot(F,ix+1,iy-2,'lin2',.99)}
  else{const o=V.reachOff||[0,1],w=P.reach?P.reach[2]:0;ix=hF[0]+o[0]*w+.5;iy=hF[1]+o[1]*w}
  rect(b,Math.round(ix)-1,Math.round(iy)-1,2,2,'bone',.25);px(b,Math.round(ix)-1,Math.round(iy)-1,'bone',.99)}
 return b}

// ---------- poses ----------
const HOLD={free:{f:[1.5,9],b:[-1,9]},staff:{f:[5.5,4],b:[-1,9]},lantern:{f:[6,5],b:[-1,9]},carry:{f:[5.5,4.5],b:[4,5.5]},pray:{f:[4.5,3],b:[3.5,3.5]},
 pole:{f:[3,-1],b:[-1,9]},palmup:{f:[6,3],b:[-1,9]},dangle:{f:[6,1],b:[-1,9]},drum:{f:[6,5],b:[4,6]},horn:{f:[4,7],b:[-1,9]}};
const CAST={palm:{f:[9.5,0],b:[6,3],lean:.1},raise:{f:[5,-4.5],b:[-2,8],lean:-.04},open:{f:[8,-4],b:[-7,-3],lean:-.1,rise:1},lift:{f:[7,-5],b:[5.5,-4],lean:-.05},
 horn:{f:[6,-4.5],b:[-3,7],lean:-.14},drum:{f:[6,5],b:[4,6],lean:.05},swing:{f:[7.5,-1],b:[-1,9],lean:.05},threads:{f:[9,-3],b:[7,0],lean:.08},
 mirror:{f:[8.5,-2],b:[7,1],lean:.05},pray:{f:[4.5,1.5],b:[3.5,2],lean:0,rise:1},palmup:{f:[7.5,0],b:[-2,8],lean:0}};
function pose(role,V,anim,t){
 const Hd=HOLD[V.hold||'free'],P={hf:Hd.f.slice(),hb:Hd.b.slice(),ff:[2.5,0],fb:[-2,0],t,anim,glow:.35,k:0,sw:0,lean:0};
 P.blink=(t%3.7)<.13;
 if(anim==='idle'){const s=Math.sin(t/2.8*TAU),s2=Math.sin(t/2.8*TAU-.8);P.ub=s>.25?1:0;P.hy=(s2>.25?1:0)-P.ub;P.sw=Math.sin(t*1.1)*.5;P.glow=.35+.15*Math.sin(t*2.2)}
 else if(anim==='walk'){const len=V.pace||.85,phi=(t/len%1)*TAU,s=Math.sin(phi),c=Math.cos(phi),S=4;
  P.ff=[S*s+.5,Math.max(0,c)*2.2];P.fb=[-S*s+.5,Math.max(0,-c)*2.2];P.bob=Math.abs(s)>.8?1:0;P.lean=.07;P.sw=-Math.sin(phi-.9)*1.3;
  P.hy=(Math.abs(Math.sin(phi-.7))>.8?1:0)-P.bob;
  if(!V.hold||V.hold==='free')P.hf=[Hd.f[0]-3.2*s,Hd.f[1]-Math.abs(s)];
  if(Hd.b[1]===9)P.hb=[Hd.b[0]+3.2*s,Hd.b[1]-Math.abs(s)];P.glow=.4}
 else if(anim==='act'&&role==='obl'){const u=t%2.6,bd=V.bend??1,d=sm(.15,.6,u)-sm(1.0,1.45,u),st=sm(1.45,1.7,u)-sm(1.95,2.25,u),o=V.reachOff||[0,1];
  P.crouch=d*4.5*bd;P.lean=d*.8*bd;P.ff=[3.5,0];P.fb=[-3,0];P.reach=[13-o[0],G-2-o[1],d];if(V.stow)P.stow=[V.stow[0],V.stow[1],st];
  P.hb=[Hd.b[0]+d*4*bd,Hd.b[1]-d*2];P.hy=d>.5?1:0;P.item=u<.62?'sol':u<1.82?'main':u>2.3?'sol':null;P.sw=d*.8;P.glow=.4}
 else if(anim==='act'){const u=t%2.8,k=sm(.1,.5,u)-sm(2.0,2.4,u),C=CAST[V.cast];P.k=k;P.u=u;
  P.hf=L2(Hd.f,C.f,k);P.hb=L2(Hd.b,C.b,k);P.glow=k*(.75+.25*Math.sin(t*9));P.lean=(C.lean||0)*k;if(C.rise)P.bob=-Math.round(k*.9);
  P.sing=role==='chant'&&k>.6&&Math.sin(t*7)>-.5;P.sw=-k*.8+Math.sin(t*3)*.4*k;
  if(V.cast==='drum'){const bt=(u*2.5)%1;P.beat=bt;P.hf=[C.f[0],C.f[1]-4.5*Math.sin(bt*Math.PI)*k];P.hb=[C.b[0],C.b[1]-3*Math.sin(((bt+.5)%1)*Math.PI)*k];P.ub=bt<.12&&k>.5?1:0}}
 else if(anim==='death'){const r=sm(0,.1,t)*(1-sm(.14,.45,t));P.lean=-.24*r;P.hf=[Hd.f[0]+r*2,Hd.f[1]-r*4];P.hb=[Hd.b[0]-r*2,Hd.b[1]-r*3];P.blink=t>.08;P.glow=.3*(1-sm(0,.6,t));P.dead=1;P.hy=-Math.round(r)}
 return P}

// ---------- fins ----------
function crystallize(b,k,mat){const m=MAT.indexOf(mat),top=lerp(G,6,k);for(let y=0;y<b.h;y++){if(y<top)continue;for(let x=0;x<b.w;x++){const i=y*b.w+x;if(b.m[i]<0)continue;
  b.m[i]=m;b.s[i]=cl(b.s[i]*.55+.3+(hash(x>>1,y>>1)>.72?.25:0)+(y-top<1.5?.4:0),.05,.99)}}}
function shatter(b,k){const o=buf(b.w,b.h);for(let y=0;y<b.h;y++)for(let x=0;x<b.w;x++){const i=y*b.w+x;if(b.m[i]<0)continue;const bx=x>>2,by=y>>2,h1=hash(bx,by),h2=hash(by+7,bx+3),h3=hash(x,y);
  if(h3<k*.82)continue;const vx=(h1-.5)*26,vy=-(3+h2*12);let nx=x+vx*k,ny=y+vy*k+34*k*k;const fl=G-1-Math.floor(h3*3);if(ny>fl){ny=fl}
  const j=Math.round(ny)*b.w+Math.round(nx);if(nx<0||nx>=b.w||ny<0)continue;o.m[j]=b.m[i];o.s[j]=b.s[i]}return o}
function squash(b,k){if(k<=0)return b;const o=buf(b.w,b.h),sy=1-k*.8,sx=1+k*.3,cx=AX-k*2;for(let y=0;y<G;y++){const syy=G-(G-y)/sy;if(syy<0)continue;for(let x=0;x<b.w;x++){const sxx=Math.round(cx+(x-cx)/sx),i=Math.round(syy)*b.w+sxx;
  if(sxx<0||sxx>=b.w||b.m[i]<0)continue;o.m[y*b.w+x]=b.m[i];o.s[y*b.w+x]=b.s[i]}}return o}

// ---------- accessoires partagés ----------
function sangle(b,J,mat='leath'){for(let i=0;i<=7;i++)over(b,J.sh[0]-2+i*.7,J.sh[1]+1+i,mat,.45)}
function etole(b,J,mat,x0=1,w=3){const y0=Math.round(J.sh[1])+2,y1=Math.round(J.hip[1])+8;for(let y=y0;y<=y1;y++){const t=(y-y0)/(y1-y0),cx=lerp(J.sh[0],J.hip[0],cl(t*1.6));for(let i=0;i<w;i++)over(b,cx+x0+i,y,mat,.7-i*.15-t*.1)}}
function tablier(b,J,mat){const y0=Math.round(J.hip[1])-5,y1=Math.round(J.hip[1])+7;for(let y=y0;y<=y1;y++){const t=(y-y0)/(y1-y0),cx=lerp(J.sh[0],J.hip[0],cl(t*2+.4));for(let i=0;i<=4+(t>.5?1:0);i++)px(b,Math.round(cx)+i,y,mat,.72-i*.1-t*.12)}}

// ---------- Oublieux ----------
const OBL=[
 {id:'1',name:'Le Glaneur à la hotte',desc:'Bure cendre à capuche, grande hotte d’osier sur le dos, veilleuse au bout du bras. Il se penche, ramasse et jette par-dessus l’épaule. La silhouette la plus simple à lire de nuit.',
  head:'hood',robe:2,hold:'lantern',stow:[-6,-4],m:{hood:'ash',robe:'ash',torso:'ash',sleeve:'ash',glove:'lin2',boot:'leath',belt:'leath'},
  back(b,J){const x=Math.round(J.sh[0])-10,y=Math.round(J.sh[1])-2;panier(b,x,y,6,12);px(b,x+1,y-1,'bone',.9);px(b,x+2,y-1,'iron',.7);px(b,x+4,y-1,'lin2',.9);px(b,x+4,y-2,'lin2',.8)},
  mid(b,J){sangle(b,J)},
  front(b,J,P,F){lantern(b,F,J.hF[0]+(P.sw||0)*.8,J.hF[1]+2,P.glow)}},
 {id:'2',name:'Le Gaffeur',desc:'Chapeau à large bord, manteau de nuit, longue gaffe à crochet : il accroche l’objet sans presque se baisser, le fait glisser jusqu’à sa main puis dans la besace. Veilleuse à la ceinture.',
  head:'hat',beard:true,robe:1,robeW:1.6,hold:'staff',bend:.3,reachOff:[7,9],stow:[-2,7],m:{hat:'nuit',hair:'hairw',robe:'nuit',torso:'nuit',sleeve:'nuit',glove:'leath',leg:'ash',boot:'leath',belt:'leath'},
  back(b,J){blob(b,J.hip[0]-5.5,J.hip[1]+2.5,3.6,5,'lin2',-.1);px(b,Math.round(J.hip[0])-5,Math.round(J.hip[1])-3,'leath',.6)},
  mid(b,J){sangle(b,J,'lin2')},
  front(b,J,P,F){const d=P.reach?P.reach[2]:0,th=lerp(-Math.PI/2,.91,d),c=Math.cos(th),s=Math.sin(th),h=J.hF,bl=lerp(Math.min(15,G-1-h[1]),6,d),tl=lerp(18,12,d),tx=h[0]+c*tl,ty=h[1]+s*tl;
   ln(b,h[0]-c*bl,h[1]-s*bl,tx,ty,'wood',.62);dot(b,tx,ty,'iron',.9);dot(b,tx-s,ty+c,'iron',.95);dot(b,tx-s*2,ty+c*2,'iron',.85);dot(b,tx-s*2-c,ty+c*2-s,'iron',.7);dot(b,tx-s*2-c*2,ty+c*2-s*2,'iron',.6);
   blob(b,h[0],h[1],1.8,1.7,'leath',.1);lantern(b,F,J.hip[0]+3,J.hip[1]-1,P.glow)}},
 {id:'3',name:'Le Porte-noms',desc:'Crâne nu, yeux bandés, linceul blême sous un scapulaire cendre. Un collier de plaques de noms lui pend sur la poitrine et tinte à la marche. Pas de lumière : il trouve à tâtons. Besace de cuir à la hanche.',
  head:'bald',blind:true,robe:2,hold:'free',stow:[-3,8],m:{robe:'lin2',torso:'lin2',sleeve:'lin2',glove:'skin',boot:'leath',belt:'ash'},
  back(b,J){blob(b,J.hip[0]-5,J.hip[1]+3,3.4,4.2,'leath',-.1)},
  mid(b,J,P,F){etole(b,J,'ash',0,3);sangle(b,J);const sw=P.sw||0;for(let i=0;i<5;i++){const x=J.sh[0]+2.5+i*.4+sw*i*.35,y=J.sh[1]+1+i*1.7;px(b,Math.round(x),Math.round(y),'iron',i&1?.95:.6)}
   if(Math.sin(P.t*5)>.8)fdot(F,J.sh[0]+4+sw,J.sh[1]+7,'lin2',.99)},
  front(b,J,P){over(b,J.hip[0]-4,J.hip[1]+1,'iron',.9)}},
 {id:'4',name:'Le Fossoyeur',desc:'Tête nue, barbe, tablier de cuir sur une tunique cendre, pelle en travers du dos et sac de toile. Le seul sans robe : il marche vite, on voit ses jambes. Veilleuse à la ceinture.',
  head:'bare',beard:true,hold:'free',stow:[-5,1],pace:.72,m:{hair:'hair',torso:'ash',sleeve:'ash',glove:'leath',leg:'nuit',boot:'leath',belt:'leath'},
  back(b,J){const x0=J.hip[0]-9,y0=J.hip[1]+5,x1=J.sh[0]-5,y1=J.sh[1]-9;ln(b,x0,y0,x1,y1,'wood',.6);rect(b,Math.round(x1)-2,Math.round(y1)-5,5,5,'iron',.05);rect(b,Math.round(x1)-1,Math.round(y1)-6,3,1,'iron',.2);
   blob(b,J.sh[0]-6,J.sh[1]+5.5,3.4,4.6,'lin2',-.08)},
  mid(b,J){tablier(b,J,'leath');sangle(b,J,'lin2')},
  front(b,J,P,F){lantern(b,F,J.hip[0]-1+(P.sw||0)*.4,J.hip[1],P.glow)}},
 {id:'5',name:'Le Pèlerin à la palanche',desc:'Voile de linceul, bure cendre, une perche en travers de l’épaule avec deux paniers qui se balancent. Il pose ce qu’il trouve dans le panier de devant, où brûle sa veilleuse. La silhouette la plus large, reconnaissable de loin.',
  head:'veil',robe:2,hold:'pole',stow:[9,2],m:{veil:'lin2',robe:'ash',torso:'ash',sleeve:'ash',glove:'skin',boot:'leath',belt:'lin2'},
  front(b,J,P,F){const y=Math.round(J.sh[1])-1,x=J.sh[0],sw=P.sw||0;ln(b,x-12,y+1,x+12,y,'wood',.62);
   for(const[s,ph]of[[-1,.6],[1,0]]){const ex=x+s*11,dx=Math.round(sw*(s>0?1:.7)*.9+ph*sw);ln(b,ex,y+1,ex-2+dx,y+6,'leath',.4);ln(b,ex,y+1,ex+2+dx,y+6,'leath',.4);panier(b,ex-3+dx,y+6,6,5);
    if(s>0){rect(b,Math.round(ex)-1+dx,y+4,2,2,'lueur',.3+P.glow*.3);fdot(F,ex+dx,y+4,'lueur',.99);if(P.glow>.42)fdot(F,ex-1+dx,y+5,'lueur',.8)}else{px(b,Math.round(ex)-1+dx,y+5,'bone',.9);px(b,Math.round(ex)+1+dx,y+5,'iron',.7)}}
   blob(b,J.hF[0],J.hF[1],1.8,1.7,'skin',.1)}},
];

// ---------- Guérisseuse cristallisée ----------
const soin=(F,x,y,t,k,n=5)=>{for(let i=0;i<n;i++){const p=(t*.7+i/n)%1;if(p>k)continue;const xx=x+Math.sin(i*2.4+p*5)*5,yy=y-p*16;if(i%2)fplus(F,xx,yy,'cmed',.95-p*.5);else fdot(F,xx,yy,'cmed',.95-p*.5)}};
const HEAL=[
 {id:'1',name:'La Main de cristal',desc:'Robe de lin, étole verte, chignon. Son bras d’avant est devenu cristal jusqu’à l’épaule : elle soigne paume tendue, un filet de lumière part de la main vers le blessé.',
  head:'bare',hair:'bun',robe:2,slim:true,hold:'free',cast:'palm',cry:'cmed',m:{hair:'hair',robe:'linen',torso:'linen',sleeve:'linen',glove:'skin',armF:'cmed',handF:'cmed',boot:'leath',belt:'med'},
  mid(b,J){etole(b,J,'med',0,3)},
  front(b,J,P,F){const h=J.hF,t=P.t;if(P.k>.3){fstar(F,h[0]+2,h[1],'cmed',P.glow>.8?2:1);for(let i=0;i<7;i++){const p=(t*1.3+i/7)%1;if(p>P.k)continue;fdot(F,h[0]+3+p*18,h[1]+Math.sin(p*7+i)*1.6-p*2,'cmed',.99-p*.5)}fplus(F,h[0]+22,h[1]-3+Math.sin(t*4),'cmed',.9)}
   else if(Math.sin(t*1.7)>.93)fdot(F,J.sj[0]+1,J.sj[1]+3,'cmed',.99)}},
 {id:'2',name:'La Porteuse de géode',desc:'Voile vert, robe de lin. Elle porte à deux mains une demi-géode comme un calice ; pour soigner elle l’élève et la lumière en déborde en croix vertes. Deux éclats lui ont poussé sur l’épaule.',
  head:'veil',robe:2,slim:true,hold:'carry',cast:'lift',cry:'cmed',m:{veil:'med',robe:'linen',torso:'linen',sleeve:'linen',glove:'skin',boot:'leath',belt:'med'},
  mid(b,J){shard(b,J.sh[0]-3,J.sh[1]+1,4,'cmed');shard(b,J.sh[0]-5,J.sh[1]+2,3,'cmed',-.1,0)},
  front(b,J,P,F){const x=Math.round(J.hF[0])+1,y=Math.round(J.hF[1])-2;rect(b,x-3,y-3,7,1,'cmed',.2+P.glow*.3);rect(b,x-3,y-2,7,1,'stone',.1);rect(b,x-2,y-1,5,1,'stone',-.05);rect(b,x-1,y,3,1,'stone',-.15);
   fdot(F,x,y-3,'cmed',.99);if(P.k>.2){fdot(F,x-2,y-3,'cmed',.9);fdot(F,x+2,y-3,'cmed',.9);soin(F,x,y-4,P.t,P.k,6)}else if(Math.sin(P.t*2)>.6)fdot(F,x+1,y-4,'cmed',.8)}},
 {id:'3',name:'La Couronne d’éclats',desc:'Cheveux blancs dénoués, robe verte. Cinq éclats tournent lentement derrière sa tête. Elle soigne mains jointes : la couronne s’élargit, accélère et sème des croix autour d’elle.',
  head:'bare',hair:'long',robe:2,slim:true,hold:'pray',cast:'pray',cry:'cmed',m:{hair:'hairw',robe:'med',torso:'med',sleeve:'med',glove:'skin',boot:'leath',belt:'linen'},hem:'linen',
  back(b,J,P,F){const r=8+P.k*4,rot=P.t*.5+P.k*P.t*2;for(let i=0;i<5;i++){const a=i/5*TAU+rot,x=J.hd[0]-1+Math.cos(a)*r,y=J.hd[1]-1+Math.sin(a)*r*.9;shard(b,x,y+1,3,'cmed',P.glow*.2,0);if(P.k>.5)fdot(F,x,y-1,'cmed',.99)}},
  front(b,J,P,F){if(P.k>.2){soin(F,J.X+2,J.sh[1]+4,P.t,P.k,6);fring(F,J.X,G-1,10+4*Math.sin(P.t*3),3,'cmed',.7,20,P.t,2)}}},
 {id:'4',name:'La Source',desc:'Natte rousse, tablier d’herboriste sur une robe verte, bâton coiffé d’une goutte de cristal. Elle lève le bâton : la goutte perle, des gouttes de lumière tombent devant elle et font des ronds au sol.',
  head:'bare',hair:'braid',robe:2,slim:true,hold:'staff',cast:'raise',cry:'cmed',m:{hair:'hairr',robe:'med',torso:'med',sleeve:'linen',glove:'skin',boot:'leath',belt:'leath'},
  mid(b,J){tablier(b,J,'leath')},
  front(b,J,P,F){const h=J.hF,x=h[0]+.5,top=h[1]-13,bot=Math.min(G-1,h[1]+13);ln(b,x,bot,x,top+3,'wood',.6);gem(b,x,top,2,'cmed',P.glow*.3);px(b,Math.round(x),Math.round(top)-3,'cmed',.99);blob(b,h[0],h[1],1.8,1.7,'skin',.1);
   fdot(F,x,top,'cmed',.99);if(P.k>.3){fstar(F,x,top,'cmed',1);for(let i=0;i<4;i++){const p=(P.t*.9+i/4)%1,xx=x+3+p*12,yy=top+p*p*(G-2-top);fdot(F,xx,yy,'cmed',.99);fdot(F,xx,yy-1,'cmed',.7)}
    const rp=(P.t*.9)%1;fring(F,x+15,G-1,2+rp*6,.8+rp*1.6,'cmed',.9-rp*.6,14,0,1)}}},
 {id:'5',name:'Les Larmes figées',desc:'Manteau vert sombre, cheveux dénoués. Le cristal lui a pris la moitié du crâne, une larme de cristal lui tourne autour à hauteur de poitrine. Pour soigner elle ouvre les bras : la larme monte en spirale et laisse une traînée.',
  head:'bare',hair:'long',halfc:true,robe:2,slim:true,hold:'free',cast:'open',cry:'cmed',cape:'foret',m:{hair:'hair',robe:'med',torso:'foret',sleeve:'foret',glove:'skin',boot:'leath',belt:'linen'},
  orb(J,P,dt=0){const t=P.t-dt,w=t*(1.6+P.k*2.4),r=11-P.k*2;return[J.X+Math.cos(w)*r,J.sh[1]+3-P.k*(12+3*Math.sin(t*2))+Math.sin(w)*2.5,Math.sin(w)]},
  back(b,J,P,F,V){const o=V.orb(J,P);if(o[2]<0){gem(b,o[0],o[1],1,'cmed',.2);fdot(F,o[0],o[1],'cmed',.99)}},
  front(b,J,P,F,V){const o=V.orb(J,P);if(o[2]>=0){gem(b,o[0],o[1],1,'cmed',.2);fdot(F,o[0],o[1],'cmed',.99)}
   for(let i=1;i<=5;i++){const q=V.orb(J,P,i*.05);if(q[2]>=0||P.k>.3)fdot(F,q[0],q[1],'cmed',.8-i*.13)}if(P.k>.4)soin(F,J.X+2,J.sh[1]-4,P.t,P.k,4)}},
];

// ---------- Chantre cristallisé ----------
const ondes=(F,x,y,t,k,a0=-.6,a1=.6)=>{for(let i=0;i<3;i++){const p=(t*1.1+i/3)%1;if(p>k)continue;farc(F,x,y,3+p*17,a0,a1,'cind',.99-p*.6)}};
const aura=(F,X,t,k)=>{if(k>.3){const p=(t*.8)%1;fring(F,X,G-1,6+p*14,1.5+p*3.5,'cind',.9-p*.6,26,0,2)}};
const CHANT=[
 {id:'1',name:'La Gorge de cristal',desc:'Tête nue, tunique orange, bras ouverts. Sa gorge et le haut de sa poitrine sont de cristal et s’allument quand il chante : les ondes sortent de sa bouche.',
  head:'bare',robe:1,hold:'free',cast:'open',cry:'cind',m:{hair:'hair',robe:'ind',torso:'ind',sleeve:'ind',glove:'skin',leg:'wool',boot:'leath',belt:'leath'},
  mid(b,J,P,F){const x=J.sh[0]+2,y=J.sh[1]+1;for(let j=0;j<6;j++)for(let i=-1-(j>>1);i<=2;i++)if(hash(i,j)>.25)over(b,x+i,y+j,'cind',cl(.5+P.glow*.4-i*.08-j*.05,.1,.99));
   gem(b,x+1,y-1,1,'cind',P.glow*.4);if(P.glow>.4){fdot(F,x+1,y-1,'cind',.99);fdot(F,x,y+2,'cind',.9)}},
  front(b,J,P,F){if(P.k>.5)ondes(F,J.hd[0]+5,J.hd[1]+3,P.t,P.k);aura(F,J.X,P.t,P.k)}},
 {id:'2',name:'Le Porte-diapason',desc:'Capuche orange, robe grise à étole. Son bâton est un grand diapason de cristal : il le lève, les deux branches vibrent et des ondes s’en écartent des deux côtés.',
  head:'hood',robe:2,hold:'staff',cast:'raise',cry:'cind',m:{hood:'ind',robe:'robe',torso:'robe',sleeve:'robe',glove:'skin',boot:'leath',belt:'ind'},
  mid(b,J){etole(b,J,'ind',1,2)},
  front(b,J,P,F){const h=J.hF,x=Math.round(h[0]+.5),y=Math.round(h[1]),bot=Math.min(G-1,y+13),vib=P.k>.5?((P.t*24|0)&1):0;ln(b,x,bot,x,y-5,'iron',.55);rect(b,x-2,y-6,5,1,'cind',.1);
   for(let i=0;i<10;i++){px(b,x-2-(i>2?vib:0),y-7-i,'cind',.95-i*.04);px(b,x+2+(i>2?vib:0),y-7-i,'cind',.7-i*.03)}blob(b,h[0],h[1],1.8,1.7,'skin',.1);
   if(P.k>.5){fdot(F,x-2-vib,y-16,'cind',.99);fdot(F,x+2+vib,y-16,'cind',.99);for(let i=0;i<3;i++){const p=(P.t*1.2+i/3)%1,r=4+p*14;farc(F,x,y-12,r,-.5,.5,'cind',.99-p*.6);farc(F,x,y-12,r,Math.PI-.5,Math.PI+.5,'cind',.99-p*.6)}}aura(F,J.X,P.t,P.k)}},
 {id:'3',name:'Le Tambour de géode',desc:'Crâne rasé, barbe, bras nus. Il porte à la hanche un tambour taillé dans une géode et le frappe à deux mains : chaque coup allume la peau du tambour et lance un cercle au sol. Le rayon de l’aura se lit tout seul.',
  head:'bald',beard:true,robe:1,hold:'drum',cast:'drum',cry:'cind',m:{hair:'hair',robe:'wool',torso:'ind',sleeve:'skin',glove:'skin',leg:'leath',boot:'leath',belt:'leath'},
  mid(b,J){sangle(b,J)},
  front(b,J,P,F){const x=J.hip[0]+6.5,y=J.hip[1]+1,hit=P.beat!==undefined&&P.beat<.14&&P.k>.4;blob(b,x,y+1,4.2,4.8,'stone',-.05);for(let i=-4;i<=4;i++){px(b,Math.round(x+i),Math.round(y-3-(Math.abs(i)>3?-1:0)),'cind',hit?.99:.6-i*.04)}
   for(let i=-2;i<=2;i+=2)over(b,x+i,y+2,'cind',.5);if(hit)for(let i=-3;i<=3;i++)fdot(F,x+i,y-3,'cind',.99);
   blob(b,J.hF[0],J.hF[1],1.8,1.7,'skin',.1);
   if(P.k>.4&&P.beat!==undefined){const p=P.beat;fring(F,J.X+2,G-1,5+p*18,1.4+p*4,'cind',.99-p*.7,30,0,2);if(p<.5)farc(F,x,y-3,3+p*10,-2.2,-.9,'cind',.9-p)}}},
 {id:'4',name:'Le Cor de cristal',desc:'Turban orange, manteau de cuir. Un cor de cristal lui pend à la main ; il le porte à la bouche, se cambre et souffle : les ondes partent du pavillon, plus larges et plus loin que la voix.',
  head:'turban',robe:1,hold:'horn',cast:'horn',cry:'cind',cape:'leath',m:{turban:'ind',hair:'hair',robe:'ind',torso:'ind',sleeve:'leath',glove:'skin',leg:'wool',boot:'leath',belt:'leath'},
  front(b,J,P,F){const h=J.hF,th0=lerp(1.25,-.45,P.k);let x=h[0],y=h[1],th=th0;for(let i=0;i<11;i++){const r=.7+i*.19;blob(b,x,y,r,r,'cind',.1+P.glow*.15-(i&1)*.06);x+=Math.cos(th)*1.25;y+=Math.sin(th)*1.25;th-=.07}
   blob(b,h[0],h[1],1.7,1.6,'skin',.1);if(P.k>.6){fdot(F,x,y,'cind',.99);ondes(F,x,y,P.t,P.k,th-.7,th+.7)}aura(F,J.X,P.t,P.k)}},
 {id:'5',name:'Le Chœur d’éclats',desc:'Haute capuche pointue, robe orange. Trois éclats flottent au-dessus de ses épaules et chantent à sa place, l’un après l’autre : chacun s’allume, monte et laisse tomber une colonne de lumière.',
  head:'hood',peak:true,robe:2,hold:'pray',cast:'open',cry:'cind',m:{hood:'ind',robe:'ind',torso:'ind',sleeve:'ind',glove:'skin',boot:'leath',belt:'wool'},
  mid(b,J){etole(b,J,'wool',1,2)},
  front(b,J,P,F){const lit=P.k>.5?Math.floor(P.t*3.5)%3:-1;[[-9,-6,0],[1,-17,1.3],[11,-7,2.6]].forEach(([dx,dy,ph],i)=>{const on=i===lit,x=J.sh[0]+dx,y=J.sh[1]+dy+Math.sin(P.t*2+ph)*1.3-P.k*3-(on?1:0);
    shard(b,x,y,i===1?6:5,'cind',on?.3:-.05);fdot(F,x,y-(i===1?5:4),'cind',on?.99:.8);if(on){fstar(F,x,y-2,'cind',1);for(let j=2;j<12;j+=2)fdot(F,x,y+j,'cind',.95-j*.06)}});aura(F,J.X,P.t,P.k)}},
];

// ---------- Envoûteur cristallisé ----------
// marque d'armure brisée au-dessus de la cible (bouclier fendu)
let NOMARK=false;
const brise=(F,x,y,t,k)=>{if(NOMARK||k<.5||Math.sin(t*10)<-.7)return;const l=.95;for(const[dx,dy]of[[-3,-3],[-2,-3],[-1,-3],[1,-3],[2,-3],[3,-3],[-3,-2],[3,-2],[-3,-1],[3,-1],[-3,0],[3,0],[-2,1],[2,1],[-1,2],[1,2],[0,3],[0,-2],[-1,-1],[0,0],[1,1]])fdot(F,x+dx,y+dy,'caet',dx===0||Math.abs(dx)===1&&Math.abs(dy)<2?.6:l)};
const HEX=[
 {id:'1',name:'Le Masque',desc:'Capuche et manteau de nuit doublé de violet. Son visage est un masque de cristal lisse, ses mains aussi. Il tend la paume : un trait part du masque et la marque d’armure brisée se forme sur la cible.',
  head:'hood',mask:'caet',robe:2,hold:'pray',cast:'palm',cry:'caet',m:{hood:'nuit',robe:'nuit',torso:'nuit',sleeve:'nuit',glove:'caet',boot:'leath',belt:'aet'},hem:'aet',
  mid(b,J){etole(b,J,'aet',2,1)},
  front(b,J,P,F){const hx=J.hd[0]+4,hy=J.hd[1];fdot(F,hx,hy,'caet',.6+P.glow*.39);if(P.k>.3){for(let i=0;i<9;i++){const p=(P.t*1.6+i/9)%1;if(p<P.k)fdot(F,hx+1+p*20,hy+p*3,'caet',.99-p*.4)}brise(F,J.X+26,J.sh[1]-3,P.t,P.k)}}},
 {id:'2',name:'Le Marionnettiste',desc:'Cheveux blancs, col haut, long manteau violet. Des fils de lumière lui pendent des doigts ; il avance les deux mains, les fils descendent, se balancent et s’accrochent.',
  head:'bare',hair:'long',robe:2,hold:'free',cast:'threads',cry:'caet',m:{hair:'hairw',robe:'aet',torso:'nuit',sleeve:'aet',glove:'skin',boot:'leath',belt:'nuit'},
  mid(b,J){rect(b,Math.round(J.sh[0])-3,Math.round(J.sh[1])-2,3,3,'aet',-.1);rect(b,Math.round(J.sh[0])+1,Math.round(J.sh[1])-1,3,2,'aet',.1)},
  front(b,J,P,F){const fil=(h,n,len,ph)=>{for(let i=0;i<n;i++){const x0=h[0]-1+i*2;let x=x0;for(let j=1;j<=len;j++){x=x0+Math.sin(P.t*3+ph+i+j*.35)*j*.14;if(j%2||j===len)fdot(F,x,h[1]+1+j,'caet',.95-j*.03)}gem(b,x,h[1]+2+len,0,'caet');fdot(F,x,h[1]+2+len,'caet',.99)}};
   fil(J.hF,2,Math.round(3+P.k*11),0);if(P.k>.3){fil(J.hB,2,Math.round(P.k*9),2);brise(F,J.X+24,J.sh[1]-8,P.t,P.k)}}},
 {id:'3',name:'Le Miroir',desc:'Turban violet à pierre, robe de nuit. Il porte un miroir de cristal poli ; il le tourne vers l’ennemi, le miroir éclate de lumière et un rayon haché file vers la cible.',
  head:'turban',robe:2,hold:'carry',cast:'mirror',cry:'caet',m:{turban:'aet',hair:'hair',robe:'nuit',torso:'nuit',sleeve:'nuit',glove:'skin',boot:'leath',belt:'aet'},hem:'aet',
  mid(b,J){etole(b,J,'aet',1,2)},
  front(b,J,P,F){const x=J.hF[0]+2.5,y=J.hF[1]-4.5;blob(b,x,y,3,4.6,'iron',-.1);blob(b,x+.3,y,2,3.6,'caet',.15+P.glow*.3);px(b,Math.round(x)-1,Math.round(y)-2,'caet',.99);ln(b,x-.5,y+5,x-.5,y+7,'iron',.5);
   blob(b,J.hF[0],J.hF[1]+1,1.8,1.7,'skin',.1);if(P.k>.5){fstar(F,x+1,y,'caet',P.glow>.8?3:2);for(let i=0;i<24;i++){if(((i+(P.t*20|0))%4)<2)fdot(F,x+4+i,y+i*.1,'caet',.99-i*.02)}brise(F,J.X+27,J.sh[1]-10,P.t,P.k)}
   else if(Math.sin(P.t*1.3)>.95)fdot(F,x,y-1,'caet',.99)}},
 {id:'4',name:'L’Œil prismatique',desc:'Crâne à demi pris par le cristal, mantelet de nuit sur une robe violette. Un prisme flotte au-dessus de sa paume ; il le laisse monter, le prisme tourne et lâche trois rayons en éventail.',
  head:'bald',halfc:true,robe:2,hold:'palmup',cast:'palmup',cry:'caet',m:{robe:'aet',torso:'aet',sleeve:'aet',glove:'skin',boot:'leath',belt:'nuit'},
  mid(b,J){blob(b,J.sh[0]-.5,J.sh[1]+2,5.2,3,'nuit',.05)},
  front(b,J,P,F){const x=J.hF[0]+.5,y=J.hF[1]-5-Math.sin(P.t*2.2)*1.2-P.k*7,r=P.k>.5&&Math.sin(P.t*12)>0?3:2;gem(b,x,y,2,'caet',P.glow*.3+Math.sin(P.t*5)*.1);fdot(F,x-1,y-1,'caet',.99);
   if(P.k>.4){fstar(F,x,y,'caet',r-1);[.15,.5,.85].forEach((an,i)=>{for(let j=3;j<22*P.k;j++){if((j+(P.t*18|0)+i)%3===0)continue;fdot(F,x+Math.cos(an)*j,y+Math.sin(an)*j,'caet',.99-j*.03-i*.1)}})}}},
 {id:'5',name:'Le Pendule',desc:'Capuche violette pointue, robe violette. Il laisse pendre un éclat au bout d’une chaîne et le balance lentement. Pour envoûter, le balancier s’emballe, laisse des images fantômes et une spirale se referme sur la cible.',
  head:'hood',peak:true,robe:2,hold:'dangle',cast:'swing',cry:'caet',m:{hood:'aet',robe:'aet',torso:'aet',sleeve:'aet',glove:'skin',boot:'leath',belt:'nuit'},hem:'nuit',
  pend(J,P,dt=0){const t=P.t-dt,A=.28+P.k*.8,an=A*Math.sin(t*(2.2+P.k*3.8));return[J.hF[0]+Math.sin(an)*10,J.hF[1]+Math.cos(an)*10]},
  front(b,J,P,F,V){const e=V.pend(J,P);for(let i=1;i<=4;i++)if(P.k>.3){const q=V.pend(J,P,i*.045);fdot(F,q[0],q[1]+1,'caet',.75-i*.14)}
   ln(b,J.hF[0],J.hF[1]+1,e[0],e[1],'iron',.5);gem(b,e[0],e[1]+1,1,'caet',.2);fdot(F,e[0],e[1]+1,'caet',.99);
   if(P.k>.4){const cx=J.X+25,cy=J.sh[1]+2;for(let i=0;i<16;i++){const a=i*.55-P.t*5,r=1+i*.55;fdot(F,cx+Math.cos(a)*r,cy+Math.sin(a)*r*.8,'caet',.99-i*.04)}}}},
];

const ROLES=[
 {key:'obl',name:'L’Oublieux',act:'Ramasse',list:OBL},
 {key:'heal',name:'Guérisseuse cristallisée',act:'Soigne',list:HEAL},
 {key:'chant',name:'Chantre cristallisé',act:'Chante',list:CHANT},
 {key:'hex',name:'Envoûteur cristallisé',act:'Envoûte',list:HEX},
];
const LIST=Object.fromEntries(ROLES.map(r=>[r.key,r.list]));
const ANIMS={idle:{len:2.8,loop:true},walk:{len:.85,loop:true},act:{len:2.8,loop:true},death:{len:2.0,loop:false}};

function paint(b){const c=render(b,1),fx=document.createElement('canvas');fx.width=b.w;fx.height=b.h;const g=fx.getContext('2d');
 for(const[x,y,mat,l]of b.fx||[]){const r=R[mat];g.fillStyle=r[Math.min(4,1+Math.round(l*3))];g.fillRect(x,y,1,1)}
 return{c,fx}}
function buffer(role,vi,anim,t){const V=LIST[role][vi];
 if(anim!=='death')return man(V,pose(role,V,anim,t));
 if(role==='obl'){ // s'affaisse en tas de bure, une lueur s'en échappe, puis il se relève (il revient la nuit suivante)
  const u=t%4.2,k=sm(.25,1.05,u)-sm(2.5,3.4,u);let b=man(V,pose(role,V,'death',u<2?u:9));const F=u<2.4?b.fx.filter(()=>k<.5):b.fx;b=squash(b,k);b.fx=k>.5?[]:F;
  if(k>.6){const w=u-1;for(let i=0;i<5;i++){const y=G-6-((w*9+i*4)%20),x=AX-2+Math.sin(w*3+i*1.3)*(3+i*.4);fdot(b.fx,x,y,'lueur',.99-i*.12)}fplus(b.fx,AX-2+Math.sin(w*2)*2,G-28-Math.sin(w*1.5)*2,'lueur',.95)}
  return b}
 // mages : le cristal les gagne des pieds à la tête, un éclair, puis ils volent en éclats
 const u=t%3.1,V2=V,c=sm(.2,.9,u);let b=man(V2,pose(role,V2,'death',u));b.fx=[];
 if(c>0)crystallize(b,c,V.cry);if(u>.9&&u<1.0)for(let i=0;i<b.s.length;i++)if(b.m[i]>=0)b.s[i]=.99;
 const s=sm(1.0,1.8,u);if(s>0){const fx=[];b=shatter(b,s);b.fx=fx;if(u<1.25)fstar(fx,AX,G-18,V.cry,4)}
 else if(c>0&&c<1){const top=lerp(G,6,c);for(let x=AX-9;x<AX+9;x++)if(hash(x,Math.floor(u*24))>.6)fdot(b.fx,x,top,V.cry,.99)}
 return b}
const frame=(role,vi,anim,t)=>paint(buffer(role,vi,anim,t));
// setExport(true) : sans la marque posée sur la cible (le jeu la dessine lui-même sur l'ennemi envoûté).
return{ROLES,LIST,ANIMS,SIZE:{w:W,h:H,ax:AX,ay:G},frame,buffer,setExport(v){NOMARK=!!v}}})();
