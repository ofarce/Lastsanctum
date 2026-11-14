/* BalisteTyrienne — cinq modèles d'arme élaborés, calculés en vraie 3D iso (faces pleines, ombrage tramé, contour).
   Repère local : x vers l'avant (tir), y latéral, z vers le haut ; pivot au sommet de la tour (z = 0).
   Rendu directement dans un tampon ImageData (pixels nets, même tramage de Bayer que decor.js). */
(function(global){
'use strict';
const BAY=[[0,8,2,10],[12,4,14,6],[3,11,1,9],[15,7,13,5]].map(r=>r.map(v=>(v+.5)/16));
const R={
 wood:['#1c120b','#2a1b10','#3d2918','#553a22','#6e4e2e','#8a663c','#a8834e'],
 iron:['#101316','#1d2226','#2e353a','#465056','#66727a','#94a0a4','#c4ccc8'],
 gold:['#3a2a12','#5a4320','#8a6a30','#c09a48','#e8c870','#fff0b0'],
 stone:['#22231f','#2c2c27','#3d3d35','#525046','#6a6858','#85826d','#a29e85','#c0bba0'],
 scale:['#08121e','#0e1e32','#15304e','#1f466e','#2c5e8e','#4078ac','#6a9ccc','#a4cce8'],
 bone:['#2a241a','#433a2a','#615641','#857a5e','#ab9f80','#cfc4a4','#ece4c8'],
 eye:['#4a3408','#8a6610','#d0a420','#f4d040','#fff2a0'],
 enon:['#0e2422','#1a3a36','#2a5a52','#428a7c','#6cbaa6','#a8e6d2','#e8fff6'],
 ancre:['#030207','#0a0712','#130e20','#1e1830','#2c2444'],
 orb:['#120a22','#24164a','#3c2a78','#5c46aa','#8a72d8','#c4b2ff','#ece4ff'],
 rope:['#3a2c18','#5a4628','#7a6236','#9a8048'],
 cloth:['#1a0508','#2e080d','#4c1018','#6e1a24','#922a30','#b23c3c'],
};
const hx={};const rgb=c=>hx[c]||(hx[c]=[1,3,5].map(i=>parseInt(c.substr(i,2),16)));
const clamp=(v,a=0,b=1)=>Math.max(a,Math.min(b,v));
const mod=(a,n)=>((a%n)+n)%n;
const sub=(a,b)=>[a[0]-b[0],a[1]-b[1],a[2]-b[2]],add=(a,b)=>[a[0]+b[0],a[1]+b[1],a[2]+b[2]],mul=(a,k)=>[a[0]*k,a[1]*k,a[2]*k];
const cross=(a,b)=>[a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0]];
const dotp=(a,b)=>a[0]*b[0]+a[1]*b[1]+a[2]*b[2];
const norm=a=>{const l=Math.hypot(...a)||1;return[a[0]/l,a[1]/l,a[2]/l]};
const LIGHT=norm([.35,.65,1]),VIEW=[1,1,1.25];
function hsh(x,y,s){let h=(x*374761393+y*668265263+s*1442695041)|0;h=(h^(h>>>13))*1274126177|0;return((h^(h>>>16))>>>0)/4294967296}

/* ---------- scène : collecte des primitives, tri du peintre, rastérisation ---------- */
function Scene(buf,W,H,cx,cy,yaw,K){
 const c=Math.cos(yaw),s=Math.sin(yaw),items=[];
 const rot=p=>[p[0]*c-p[1]*s,p[0]*s+p[1]*c,p[2]];
 const proj=p=>{const u=(p[0]*c-p[1]*s)*K,v=(p[0]*s+p[1]*c)*K;return[cx+u-v,cy+(u+v)/2-p[2]*K,u+v+p[2]*K*.5]};
 const S={K,yaw,proj,rot,items};
 S.put=(x,y,col,a=1)=>{x=Math.round(x);y=Math.round(y);if(x<0||y<0||x>=W||y>=H)return;const o=(y*W+x)*4,[r,g,b]=rgb(col);
  if(a>=1){buf[o]=r;buf[o+1]=g;buf[o+2]=b;buf[o+3]=255}else{buf[o]+= (r-buf[o])*a;buf[o+1]+=(g-buf[o+1])*a;buf[o+2]+=(b-buf[o+2])*a}};
 // face plane : pts locaux, ramp, options {base, tex, two, edge, glow}
 S.face=(pts,ramp,o={})=>{const w=pts.map(rot);let n=norm(cross(sub(w[1],w[0]),sub(w[2],w[0])));
  if(o.center){const ce=rot(o.center),fc=mul(w.reduce(add,[0,0,0]),1/w.length);if(dotp(n,sub(fc,ce))<0)n=mul(n,-1)}
  else if(o.two&&dotp(n,VIEW)<0)n=mul(n,-1);
  if(dotp(n,VIEW)<=0.001)return;const sp=pts.map(proj);
  const lit=o.flat??(.2+.72*Math.max(0,dotp(n,LIGHT)));
  items.push({k:'f',sp,ramp,v:lit+(o.base||0),tex:o.tex,edge:o.edge!==false,d:sp.reduce((a,p)=>a+p[2],0)/sp.length+(o.bias||0),glow:o.glow})};
 // hexaèdre (8 sommets : 0-3 bas, 4-7 haut)
 S.hexa=(v,ramp,o={})=>{const ce=mul(v.reduce(add,[0,0,0]),1/8);for(const f of[[0,1,2,3],[4,5,6,7],[0,1,5,4],[1,2,6,5],[2,3,7,6],[3,0,4,7]])S.face(f.map(i=>v[i]),ramp,{...o,center:ce})};
 S.box=(x0,y0,z0,x1,y1,z1,ramp,o={})=>{const ty=o.ty??1,tz=o.tz??1,my=(y0+y1)/2,mz=(z0+z1)/2,F=(y,z)=>[my+(y-my)*ty,mz+(z-mz)*tz];
  const[a0,b0]=F(y0,z0),[a1,b1]=F(y1,z1);
  S.hexa([[x0,y0,z0],[x1,a0,b0],[x1,a1,b0],[x0,y1,z0],[x0,y0,z1],[x1,a0,b1],[x1,a1,b1],[x0,y1,z1]].map(p=>o.tf?o.tf(p):p),ramp,o)};
 // poutre entre deux points, largeur w (latéral) et h (vertical)
 S.beam=(p,q,w,h,ramp,o={})=>{const d=sub(q,p);let sd=cross(d,[0,0,1]);if(Math.hypot(...sd)<1e-6)sd=[0,1,0];sd=mul(norm(sd),w/2);const up=mul(norm(cross(sd,d)),h/2*(o.flip?-1:1));
  const P=(b,sg,ug)=>add(add(b,mul(sd,sg)),mul(up,ug));
  S.hexa([P(p,-1,-1),P(q,-1,-1),P(q,1,-1),P(p,1,-1),P(p,-1,1),P(q,-1,1),P(q,1,1),P(p,1,1)],ramp,o)};
 // prisme à n côtés (cylindre)
 S.cyl=(x,y,z,r,h,n,ramp,o={})=>{const ring=(zz,rr)=>Array.from({length:n},(_,i)=>{const a=i/n*6.283+(o.rot||0);return[x+Math.cos(a)*rr,y+Math.sin(a)*rr,zz]});
  const b=ring(z,r),t=ring(z+h,o.rt??r),ce=[x,y,z+h/2];for(let i=0;i<n;i++){const j=(i+1)%n;S.face([b[i],b[j],t[j],t[i]],ramp,{...o,center:ce})}
  S.face(t,o.topRamp||ramp,{...o,center:ce,base:(o.base||0)+(o.topBase||0)});S.face(b,ramp,{...o,center:ce})};
 S.seg=(p,q,col,o={})=>{const a=proj(p),b=proj(q);items.push({k:'l',a,b,col,d:(a[2]+b[2])/2+(o.bias||0),alpha:o.alpha??1,w:o.w||1})};
 S.pt=(p,col,o={})=>{const a=proj(p);items.push({k:'p',a,col,d:a[2]+(o.bias||0),r:o.r||0,alpha:o.alpha??1})};
 // sphère en espace écran (rayon local r), ombrée
 S.sphere=(p,r,ramp,o={})=>{const a=proj(p);items.push({k:'s',a,r:r*K,ramp,d:a[2]+(o.bias||0),rim:o.rim})};
 S.render=()=>{items.sort((p,q)=>p.d-q.d);for(const it of items)draw(it)};
 function shade(ramp,v,x,y){const n=ramp.length;let i=Math.floor(clamp(v)*(n-1)+BAY[mod(y,4)][mod(x,4)]);return ramp[clamp(i,0,n-1)]}
 function tex(t,v,x,y){if(!t)return v;
  if(t==='wood'){if(mod(y+(x>>3),3)===0)v-=.1;return v+(hsh(x>>1,y,3)-.5)*.1}
  if(t==='scale'){const r=y>>1,q=(x+(r&1)*2)>>2,lx=mod(x+(r&1)*2,4),ly=y&1;v+=(hsh(q,r,7)-.5)*.16;if(ly===0&&lx===1)v+=.14;if(lx===3)v-=.16;return v}
  if(t==='stone'){const r=Math.floor(y/3),q=Math.floor((x+(r&1)*3)/6);v+=(hsh(q,r,5)-.5)*.14;if(mod(y,3)===0||mod(x+(r&1)*3,6)===0)v-=.12;return v}
  if(t==='metal'){return v+(mod(x+y,5)===0?.08:0)}
  if(t==='glyph'){if(mod(x,4)===1&&mod(y,3)!==0&&hsh(x>>2,y/3|0,11)>.45)return 1.3;return v}
  if(t==='vein'){const n=Math.sin(x*.7+y*1.3)+Math.sin(x*.31-y*.9);if(Math.abs(n)<.18)return 2;return v}
  return v}
 function inside(sp,x,y){let pos=0,neg=0;for(let i=0;i<sp.length;i++){const a=sp[i],b=sp[(i+1)%sp.length],cr=(b[0]-a[0])*(y-a[1])-(b[1]-a[1])*(x-a[0]);if(cr>0)pos++;else if(cr<0)neg++;if(pos&&neg)return false}return true}
 function draw(it){
  if(it.k==='f'){const sp=it.sp;let x0=1e9,y0=1e9,x1=-1e9,y1=-1e9;for(const p of sp){x0=Math.min(x0,p[0]);y0=Math.min(y0,p[1]);x1=Math.max(x1,p[0]);y1=Math.max(y1,p[1])}
   x0=Math.floor(x0);y0=Math.floor(y0);x1=Math.ceil(x1);y1=Math.ceil(y1);
   for(let y=y0;y<=y1;y++)for(let x=x0;x<=x1;x++)if(inside(sp,x+.5,y+.5)){const v=tex(it.tex,it.v,x,y);
    if(v>=1.9)S.put(x,y,it.glow||R.orb[5]);else if(v>=1.25)S.put(x,y,it.glow||R.enon[5]);else S.put(x,y,shade(it.ramp,v,x,y))}
   if(it.edge){const col=it.ramp[0];for(let i=0;i<sp.length;i++){const a=sp[i],b=sp[(i+1)%sp.length];line(a,b,col,.55)}}}
  else if(it.k==='l')line(it.a,it.b,it.col,it.alpha,it.w);
  else if(it.k==='p'){const[x,y]=it.a;if(it.r){for(let j=-it.r;j<=it.r;j++)for(let i=-it.r;i<=it.r;i++){const dd=Math.hypot(i,j)/it.r;if(dd<=1&&BAY[mod(y+j|0,4)][mod(x+i|0,4)]>dd*.9-.1)S.put(x+i,y+j,it.col,it.alpha*(1-dd*.6))}}else S.put(x,y,it.col,it.alpha)}
  else if(it.k==='s'){const[x,y]=it.a,r=it.r;for(let j=Math.floor(-r);j<=r;j++)for(let i=Math.floor(-r);i<=r;i++){const dd=Math.hypot(i,j)/r;if(dd>1)continue;
    const l=clamp(.55-(i*.35+j*.55)/r*.6-dd*.25);let col=shade(it.ramp,l,Math.round(x+i),Math.round(y+j));if(it.rim&&dd>.82)col=it.rim;S.put(x+i,y+j,col)}}}
 function line(a,b,col,alpha=1,w=1){const n=Math.max(1,Math.ceil(Math.max(Math.abs(b[0]-a[0]),Math.abs(b[1]-a[1]))));for(let i=0;i<=n;i++){const x=a[0]+(b[0]-a[0])*i/n,y=a[1]+(b[1]-a[1])*i/n;S.put(x,y,col,alpha);if(w>1)S.put(x,y-1,col,alpha)}}
 return S}

/* ---------- cycle commun ---------- */
// f ∈ [0,1) : alimentation .05–.25, tension .22–.66, verrouillage → .7, lâcher .7–.78, vol → .95
function cyc(f){const draw=f<.22?0:f<.66?(f-.22)/.44:f<.7?1:f<.78?1-(f-.7)/.08:0;const ease=draw*draw*(3-2*draw);
 return{f,draw:ease,feed:clamp((f-.05)/.2),loaded:f<.7||f>.97,release:f>=.7&&f<.78,flight:f>=.7&&f<.97?(f-.7)/.27:-1,recoil:f>=.7&&f<.9?Math.sin((f-.7)/.2*Math.PI)*(1-(f-.7)/.2):0}}
function mount(S,o={}){// affût : socle de pierre tyrienne, couronne de laiton, pivot
 S.cyl(0,0,-.5,9,1.6,12,R.stone,{tex:'stone',topRamp:R.stone});
 S.cyl(0,0,1.1,7.6,.9,16,R.gold,{tex:'metal'});
 S.cyl(0,0,2,3.2,o.post||4,8,R.iron,{tex:'metal'});
 for(let i=0;i<8;i++){const a=i/8*6.283;S.pt([Math.cos(a)*8.3,Math.sin(a)*8.3,.9],R.gold[5])}}
function curveArm(S,side,root,draw,o){// bras arqué : liste de points, poutres
 const n=o.n||6,step=o.step||2.5,bend=1-draw*(o.flex??.28),pts=[];
 for(let k=0;k<=n;k++)pts.push([root[0]-k*k*(o.sweep??.3)*bend,side*(root[1]+k*step),root[2]+(o.rise||0)*k]);
 for(let k=0;k<n;k++){const r=o.ramp?o.ramp(k):R.wood;S.beam(pts[k],pts[k+1],(o.w||1.8)*(1-k/n*.45),(o.h||1.4)*(1-k/n*.35),r,{tex:o.tex?.(k)})}
 return pts[n]}
function bolt(S,x,z,len,o={}){const col=o.shaft||R.wood;S.beam([x-len,0,z],[x,0,z],.55,.55,col,{edge:false,bias:o.bias||0});
 S.beam([x,0,z],[x+1.8,0,z],.8,.8,o.head||R.gold,{edge:false,ty:.1,tz:.1,bias:.1});
 for(const sg of[-1,1])S.seg([x-len,sg*.9,z],[x-len+2.2,0,z],o.fletch||R.cloth[4])}
function flight(S,st,z,o={}){if(st.flight<0)return;const d=st.flight*190+6;
 bolt(S,18+d,z,9,o);if(o.trail)for(let k=1;k<=o.trail;k++)S.seg([18+d-9-k*5,0,z],[18+d-9-k*5-4,0,z],o.trailCol||R.iron[5],{alpha:.55-k*.12});
 if(st.flight<.12)for(let k=0;k<8;k++)S.pt([20+hsh(k,1,4)*5,(hsh(k,2,4)-.5)*7,z+(hsh(k,3,4)-.5)*5],o.puff||R.stone[7],{alpha:.7})}

/* ================= 01 · MÂCHOIRE DE LACERTA ================= */
// Crâne de saurien en tête, mâchoires-bras en os, échine d'écailles bleues ; le trait sort de la gueule.
function m1(S,t,st){mount(S);
 const z=7,rc=-st.recoil*2.5,T=p=>[p[0]+rc,p[1],p[2]];
 // fût d'ébène cerclé de fer
 S.box(-15+rc,-2,z-1.5,13+rc,2,z+1.2,R.wood,{tex:'wood'});
 for(const x of[-11,-4,3,9])S.box(x+rc,-2.25,z-1.7,x+1.2+rc,2.25,z+1.4,R.iron);
 // échine : plaques d'écailles bleues + nageoires dorsales
 S.box(-13+rc,-2.6,z+1.2,10+rc,2.6,z+2,R.scale,{tex:'scale'});
 for(let i=0;i<6;i++){const x=-12+i*3.8+rc,hgt=2.8-Math.abs(i-2.2)*.5;S.hexa([[x,-.35,z+2],[x+2.6,-.35,z+2],[x+2.6,.35,z+2],[x,.35,z+2],[x+.4,-.2,z+2+hgt],[x+1.2,-.2,z+2+hgt*.6],[x+1.2,.2,z+2+hgt*.6],[x+.4,.2,z+2+hgt]],R.scale,{base:.1})}
 // treuil arrière, manivelle laiton qui tourne pendant la tension
 S.cyl(-14+rc,0,z-3.6,1.4,.1,8,R.iron);S.box(-15.5+rc,-3.2,z-3,-12.5+rc,-2.2,z+.5,R.wood);S.box(-15.5+rc,2.2,z-3,-12.5+rc,3.2,z+.5,R.wood);
 const wa=st.draw*12.6;S.beam([-14+rc,-3.6,z-1.2],[-14+rc+Math.cos(wa)*2,-3.6,z-1.2+Math.sin(wa)*2],.5,.5,R.gold);
 // crâne : museau effilé
 const jaw=st.release?.32:st.f<.86&&st.f>=.78?.32*(1-(st.f-.78)/.08):0;
 S.box(11+rc,-4,z-.8,23+rc,4,z+4.2,R.scale,{ty:.32,tz:.45,tex:'scale'});
 // arcade sourcilière et crête
 S.box(12+rc,-4.3,z+2.8,17+rc,-2.6,z+4.6,R.scale,{base:.08});S.box(12+rc,2.6,z+2.8,17+rc,4.3,z+4.6,R.scale,{base:.08});
 for(let i=0;i<4;i++)S.beam([12.5+i*1.6+rc,0,z+4.2],[11.5+i*1.6+rc,0,z+6.4-i*.4],.5,1,R.gold);
 // mâchoire inférieure articulée
 const J=p=>{const dx=p[0]-12,dz=p[2]-(z-1);return[12+dx*Math.cos(jaw)+rc,p[1],z-1-dx*Math.sin(jaw)+dz*Math.cos(jaw)]};
 S.box(12,-3.4,z-3,22,3.4,z-1,R.scale,{ty:.35,tz:.6,tex:'scale',tf:J});
 for(let i=0;i<5;i++)for(const sg of[-1,1]){S.pt(J([14+i*1.7,sg*(2.6-i*.35),z-.9]),R.bone[6]);S.pt(T([14+i*1.7,sg*(2.6-i*.35),z-.4]),R.bone[5])}
 // yeux jaunes : s'allument avec la tension
 for(const sg of[-1,1]){const e=T([15.2,sg*3.7,z+2.6]);S.box(14.6+rc,sg*3.55-.5,z+2.1,15.9+rc,sg*3.55+.5,z+3.1,R.eye,{base:.2+st.draw*.4,edge:false,bias:.3});
  if(st.draw>.3)S.pt(e,R.eye[4],{r:1+st.draw*1.5|0,alpha:.5*st.draw,bias:.4})}
 // bras-mâchoires en os, bagués de laiton
 const tips=[];for(const sg of[-1,1])tips.push(curveArm(S,sg,[13+rc,2.6,z+.6],st.draw,{n:6,step:2.6,sweep:.34,w:1.9,h:1.5,ramp:k=>k===1||k===4?R.gold:R.bone}));
 const pull=-10*st.draw+rc;for(const tp of tips)S.seg(tp,[pull,0,z+1.6],R.rope[3]);
 if(st.loaded)bolt(S,24+rc-(1-st.feed)*0,z+1.6,24*Math.max(st.feed,.05)+pull*0,{});
 flight(S,st,z+1.6,{trail:3})}

/* ================= 02 · ARC D'ÉNONCIATION ================= */
// Les branches flottent en segments disjoints tenus par l'Énonciation ; le trait est « suspendu » dans trois anneaux.
function m2(S,t,st){mount(S,{post:3.5});
 const z=6.5,rc=-st.recoil*1.5;
 S.box(-13+rc,-1.6,z-1.2,15+rc,1.6,z+1,R.stone,{tex:'stone',base:.05});
 S.box(-11+rc,-1.65,z-.2,13+rc,1.65,z+.4,R.stone,{tex:'glyph',base:-.05});
 // pylône d'émission à l'arrière : obélisque gravé
 S.box(-14+rc,-1.4,z-1,-11+rc,1.4,z+7,R.stone,{tz:1,ty:.6,tex:'glyph'});S.box(-13.4+rc,-.5,z+7,-11.6+rc,.5,z+8.5,R.gold);
 // branches : 4 segments séparés par des interstices lumineux
 const tips=[];for(const sg of[-1,1]){const bend=1-st.draw*.3;let prev=null;for(let k=0;k<4;k++){const a=[12-(k*1.1)**2*.55*bend+rc,sg*(2.8+k*3.4),z],b=[12-(k*1.1+.75)**2*.55*bend+rc,sg*(2.8+k*3.4+2.5),z];
   S.beam(a,b,1.8,1.6,R.stone,{tex:'stone'});S.beam([a[0],a[1],a[2]+.8],[b[0],b[1],b[2]+.8],1.2,.3,R.gold,{edge:false});
   if(prev){const m=mul(add(prev,a),.5);S.pt(m,R.enon[5],{r:1,alpha:.5+.5*Math.sin(t*9+k)})}prev=b}tips.push(prev)}
 const pull=-10*st.draw+rc;for(const tp of tips){S.seg(tp,[pull,0,z+1.5],R.enon[5]);S.seg([tp[0],tp[1],tp[2]+.3],[pull,0,z+1.8],R.enon[3],{alpha:.5})}
 // trois anneaux d'Énonciation qui tournent plus vite à mesure que la tension monte
 const sp=1+st.draw*6;for(const[x,rr]of[[3,3.6],[9,3],[15,2.4]]){const n=18,ph=t*sp*(x===9?-1:1);for(let i=0;i<n;i++){const a0=i/n*6.283+ph,a1=(i+.55)/n*6.283+ph;
   S.seg([x+rc,Math.cos(a0)*rr,z+1.6+Math.sin(a0)*rr],[x+rc,Math.cos(a1)*rr,z+1.6+Math.sin(a1)*rr],i%3?R.enon[4]:R.gold[4],{bias:Math.sin(a0)*.1})}}
 if(st.release)for(let k=0;k<10;k++)S.pt([4+k*1.5+rc,(hsh(k,5,t*10|0)-.5)*4,z+1.6+(hsh(k,6,t*10|0)-.5)*4],R.enon[6],{r:1});
 // trait suspendu : il oscille légèrement, figé par la Suspension
 if(st.loaded){const hov=Math.sin(t*5)*.25*(1-st.draw);bolt(S,22+rc,z+1.6+hov,22*Math.max(st.feed,.05),{head:R.enon,shaft:R.iron})}
 flight(S,st,z+1.6,{trail:5,trailCol:R.enon[5],head:R.enon,shaft:R.iron,puff:R.enon[5]})}

/* ================= 03 · QUEUE DU GARDIEN ================= */
// La tension vient d'une queue articulée de vertèbres en contrepoids, qui se lève puis fouette ; collerette d'écailles à l'avant.
function m3(S,t,st){mount(S);
 const z=7,rc=-st.recoil*2;
 S.box(-12+rc,-2.4,z-1.6,14+rc,2.4,z+1.2,R.wood,{tex:'wood'});
 S.box(-12+rc,-2.6,z+1.2,12+rc,2.6,z+1.8,R.iron,{tex:'metal'});
 // collerette (fan de plaques)
 for(let i=0;i<9;i++){const a=-1.25+i/8*2.5,ca=Math.cos(a),sa=Math.sin(a),L=i%2?7.5:8.6;
  S.hexa([[14,ca*2,z+sa*2+2],[14.4,ca*L,z+sa*L*.85+2],[14.4,Math.cos(a+.16)*L,z+Math.sin(a+.16)*L*.85+2],[14,Math.cos(a+.16)*2,z+Math.sin(a+.16)*2+2],
   [14.8,ca*2,z+sa*2+2],[15.2,ca*L,z+sa*L*.85+2],[15.2,Math.cos(a+.16)*L,z+Math.sin(a+.16)*L*.85+2],[14.8,Math.cos(a+.16)*2,z+Math.sin(a+.16)*2+2]].map(p=>[p[0]+rc,p[1],p[2]]),i%2?R.scale:R.gold,{tex:i%2?'scale':'metal'})}
 S.box(13+rc,-1.2,z+.6,16.5+rc,1.2,z+2.6,R.iron);// meurtrière
 // queue : 7 vertèbres
 const lift=st.release?-.15:st.draw*.32,whip=st.f>=.7&&st.f<.86?Math.sin((st.f-.7)/.16*Math.PI)*-.25:0;
 let p=[-12+rc,0,z],ang=Math.PI;for(let k=0;k<7;k++){ang-=lift+whip*(k/6);const L=3.2-k*.25,q=[p[0]+Math.cos(ang)*L,0,p[2]+Math.sin(ang)*-L*-.0+Math.sin(Math.PI-ang)*L];
  const w=2.6-k*.28;S.beam(p,q,w,w*.9,k===6?R.gold:R.scale,{tex:'scale'});S.beam([(p[0]+q[0])/2,0,(p[2]+q[2])/2+w*.45],[(p[0]+q[0])/2-.6,0,(p[2]+q[2])/2+w*.45+1.6-k*.15],.4,.8,R.bone);p=q}
 // masse de contrepoids au bout
 S.cyl(p[0],0,p[2]-1.3,1.6,2.6,8,R.iron,{tex:'metal'});
 // câble queue → noix
 S.seg([-12+rc,0,z+.4],p,R.iron[5]);
 const tips=[];for(const sg of[-1,1])tips.push(curveArm(S,sg,[12+rc,2.5,z],st.draw,{n:6,step:2.4,sweep:.3,ramp:k=>k<2?R.iron:R.wood,tex:k=>k<2?'metal':'wood'}));
 const pull=-10*st.draw+rc;for(const tp of tips)S.seg(tp,[pull,0,z+1.9],R.rope[3]);
 if(st.loaded)bolt(S,22+rc,z+1.9,22*Math.max(st.feed,.05));
 flight(S,st,z+1.9,{trail:2})}

/* ================= 04 · RELIQUAIRE DE L'ANCRE ================= */
// Un éclat d'Ancre lévite dans une cage de laiton ; les branches d'obsidienne en tirent leur tension. Seul usage du violet.
function m4(S,t,st){mount(S);
 const z=7,rc=-st.recoil*1.5,pulse=.5+.5*Math.sin(t*3+st.draw*4);
 S.box(-13+rc,-2,z-1.4,14+rc,2,z+1,R.ancre,{tex:'vein',glow:R.orb[3+(pulse>.6)]});
 for(const x of[-10,-2,6])S.box(x+rc,-2.2,z-1.6,x+1+rc,2.2,z+1.2,R.gold);
 // cage
 const cx0=-3+rc,cz=z+1;S.cyl(cx0,0,cz,3.6,.6,12,R.gold);for(let i=0;i<12;i++){const a0=i/12*6.283,a1=(i+1)/12*6.283;S.beam([cx0+Math.cos(a0)*3.2,Math.sin(a0)*3.2,cz+8],[cx0+Math.cos(a1)*3.2,Math.sin(a1)*3.2,cz+8],.6,.6,R.gold,{edge:false})}S.beam([cx0,0,cz+8],[cx0,0,cz+9.6],.5,.5,R.gold);S.pt([cx0,0,cz+9.8],R.orb[5],{r:1});
 for(let i=0;i<6;i++){const a=i/6*6.283+.3;S.beam([cx0+Math.cos(a)*3.4,Math.sin(a)*3.4,cz+.6],[cx0+Math.cos(a)*3.1,Math.sin(a)*3.1,cz+8],.45,.45,R.gold,{edge:false})}
 const hov=Math.sin(t*2)*.5;S.sphere([cx0,0,cz+4.4+hov],2.1,R.ancre,{rim:R.orb[2+(pulse>.5)]});
 for(let k=0;k<5;k++){const a=t*(1.5+st.draw*4)+k*1.257;S.pt([cx0+Math.cos(a)*2.9,Math.sin(a)*2.9,cz+4.4+Math.sin(a*2)*.8],R.orb[5],{alpha:.6+.4*pulse})}
 // flux violet vers les branches pendant la tension
 if(st.draw>.05)for(const sg of[-1,1])for(let k=0;k<4;k++){const q=mod(t*2+k*.25,1);S.pt([cx0+(14-cx0)*q,sg*q*2.5,cz+4-q*3],R.orb[4],{alpha:st.draw})}
 const tips=[];for(const sg of[-1,1])tips.push(curveArm(S,sg,[13+rc,2.4,z],st.draw,{n:6,step:2.6,sweep:.32,ramp:k=>k%2?R.gold:R.ancre,tex:()=> 'vein'}));
 const pull=-10*st.draw+rc;for(const tp of tips)S.seg(tp,[pull,0,z+1.6],R.orb[4]);
 // le trait se matérialise (tramé) avant d'être solide
 if(st.loaded){if(st.feed<1){for(let k=0;k<20;k++)if(hsh(k,t*20|0,2)<st.feed)S.pt([22-k*1.1+rc,0,z+1.6],R.orb[5])}else bolt(S,22+rc,z+1.6,21,{head:R.orb,shaft:R.ancre,fletch:R.orb[4]})}
 flight(S,st,z+1.6,{trail:4,trailCol:R.orb[4],head:R.orb,shaft:R.ancre,fletch:R.orb[4],puff:R.orb[5]})}

/* ================= 05 · TRIPLE ARC ÉCAILLÉ ================= */
// Arme lourde de première ligne : mantelet d'écailles, trois paires de bras superposées, salve de trois traits.
function m5(S,t,st){mount(S,{post:3});
 const z=5.5,rc=-st.recoil*1.8;
 S.box(-13+rc,-1.2,z-1.2,11+rc,1.2,z+7.5,R.wood,{tex:'wood'});for(const lz of[z,z+3,z+6])S.box(-12+rc,-2.4,lz,11+rc,2.4,lz+.7,R.wood,{tex:'wood',base:.08});
 for(const x of[-9,-1,7])S.box(x+rc,-2.6,z-1.4,x+1.1+rc,2.6,z+7.7,R.iron);
 // mantelet écaillé avec bordure d'or et crête
 S.box(11+rc,-8.5,z-2,13+rc,8.5,z+10,R.scale,{tex:'scale'});
 S.box(11.2+rc,-8.8,z+9.6,13.2+rc,8.8,z+10.6,R.gold);
 for(const sg of[-1,1])S.box(11.2+rc,sg*8.4-.4,z-2,13.2+rc,sg*8.4+.4,z+10,R.gold);
 S.hexa([[11.5,-.4,z+10.6],[13,-.4,z+10.6],[13,.4,z+10.6],[11.5,.4,z+10.6],[11,-.25,z+14],[11.8,-.25,z+13.2],[11.8,.25,z+13.2],[11,.25,z+14]].map(p=>[p[0]+rc,p[1],p[2]]),R.scale,{base:.12});
 // œil tyrien gravé au centre
 S.box(13+rc,-1,z+8,13.3+rc,1,z+9,R.eye,{base:.3,edge:false});
 const levels=[z,z+3,z+6],pull=-8*st.draw+rc;
 levels.forEach((lz,i)=>{const tips=[];for(const sg of[-1,1])tips.push(curveArm(S,sg,[12.5+rc,8.4,lz],st.draw,{n:4,step:1.9,sweep:.42,w:1.5,h:1.1,ramp:k=>k===0?R.iron:R.wood}));
  for(const tp of tips)S.seg(tp,[pull,0,lz+.9],R.rope[3]);
  const fi=st.f-i*.035;const s2=cyc(mod(fi,1));if(fi<.7||st.f>.97)bolt(S,20+rc,lz+.9,20*Math.max(st.feed,.05));flight(S,s2,lz+.9,{trail:1})});
 // embrasures du mantelet
 for(const lz of levels)S.box(12.9+rc,-1,lz+.2,13.4+rc,1,lz+1.6,R.iron,{base:-.3,edge:false,bias:.2})}

const MODELS=[
 {id:'machoire',name:'01 · Mâchoire de Lacerta',draw:m1,
  tag:'Le crâne saurien',desc:'La tête de l’arme est un crâne de Tyrien sculpté dans des plaques d’écailles bleues : le trait part de la gueule, la mâchoire inférieure s’ouvre au lâcher, les yeux jaunes s’allument avec la tension. Les bras sont des os bagués de laiton, l’échine porte des nageoires dorsales.',
  lore:'Écailles bleues et yeux jaunes (tradition du Kanka). Lacerta = le Sanctum Lacertae qu’elle garde.'},
 {id:'enonciation',name:'02 · Arc d’Énonciation',draw:m2,
  tag:'La technique, pas la magie',desc:'Les branches ne sont pas reliées : quatre segments de pierre flottent, tenus par l’Énonciation. Trois anneaux tournent de plus en plus vite pendant la tension et maintiennent le trait en Suspension ; au lâcher, l’Accélération laisse une traîne.',
  lore:'L’Énonciation altère localement espace, matière et mouvement : géométrie originale, aucun emprunt de SF.'},
 {id:'queue',name:'03 · Queue du Gardien',draw:m3,
  tag:'Le mécanisme anatomique',desc:'Une queue de sept vertèbres sert de contrepoids : elle se dresse pendant la tension, puis fouette au lâcher. À l’avant, une collerette d’écailles et d’or protège la meurtrière. L’arme se lit comme une bête accroupie.',
  lore:'Assemblage organique inspiré du corps saurien des bâtisseurs : savoir technique et arts guerriers.'},
 {id:'ancre',name:'04 · Reliquaire de l’Ancre',draw:m4,
  tag:'Le lien avec la sphère',desc:'Un éclat de l’Ancre lévite dans une cage de laiton et alimente des branches d’obsidienne veinée de violet. Le trait se matérialise pixel après pixel avant de devenir solide. Le violet reste réservé à l’Ancre.',
  lore:'Les tourelles puisent dans la sphère qu’elles défendent. Risque narratif : l’Ancre « dépensée » pour se défendre.'},
 {id:'triple',name:'05 · Triple arc écaillé',draw:m5,
  tag:'La première ligne',desc:'Arme lourde : grand mantelet d’écailles bordé d’or, crête dorsale, œil tyrien gravé. Trois paires de bras superposées tendent ensemble et lâchent une salve décalée de trois traits.',
  lore:'Arts guerriers tyriens ; silhouette massive qui annonce le rôle de rempart du Sanctum.'},
];
// rend un modèle dans un tampon RGBA (déjà rempli du décor) au pivot (cx,cy)
function render(buf,W,H,cx,cy,i,yaw,t,period=3.6,K=1.9,o={}){const f=o.f??mod(t,period)/period,st=cyc(f);if(o.noFlight)st.flight=-1;const S=Scene(buf,W,H,cx,cy,yaw,K);MODELS[i].draw(S,t,st);S.render()}
// en jeu : phase du cycle de tir du jeu (lâcher à .76) → cycle du modèle (lâcher à .7) ; le projectile est géré par le jeu
function drawGame(g,cx,cy,yaw,t,phase,i=0){const W=g.canvas.width,H=g.canvas.height,f=phase<.76?phase/.76*.7:.7+(phase-.76)/.24*.3;
 const x0=Math.max(0,Math.round(cx-70)),y0=Math.max(0,Math.round(cy-70)),w=Math.min(W-x0,140),h=Math.min(H-y0,100);
 const im=g.getImageData(x0,y0,w,h);render(im.data,w,h,cx-x0,cy-y0,i,yaw,t,3.6,1.9,{f:mod(f,1),noFlight:true});g.putImageData(im,x0,y0)}
global.BalisteTyrienne={MODELS,render,drawGame,R};
})(window);
