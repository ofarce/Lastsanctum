'use strict';
// Planche « Défenses de l'Atelier » : poste de tir, barricade, chausse-trappe (objets posés, 1 case).
// Moteur repris de creuset-planches.js (vue 3/4 du jeu, 24 px par unité, 1 case = 4/3 unité de dessin = 32 px, jour/nuit).
const DEF=(()=>{
// ---------- couleurs ----------
const CM=new Map();
function ci(c){if(typeof c==='number')return c;let v=CM.get(c);if(v===undefined){v=parseInt(c.slice(1),16);CM.set(c,v)}return v}
const E=c=>ci(c)|0x1000000; // émissif : non assombri la nuit
function sh(c,k){const n=ci(c),em=n&0x1000000,f=v=>Math.max(0,Math.min(255,Math.round(k<0?v*(1+k):v+(255-v)*k)));return em|f(n>>16&255)<<16|f(n>>8&255)<<8|f(n&255)}
const R_=a=>a.map(ci);
const OUTL=ci('#0b0a0e');
function hash(x,y,s=0){let h=(Math.imul(x|0,374761393)+Math.imul(y|0,668265263)+Math.imul(s|0,982451653))|0;h=Math.imul(h^(h>>>13),1274126177);return((h^(h>>>16))>>>0)/4294967296}
function vnoise(x,y,s){const xi=Math.floor(x),yi=Math.floor(y),xf=x-xi,yf=y-yi,u=xf*xf*(3-2*xf),v=yf*yf*(3-2*yf),a=hash(xi,yi,s),b=hash(xi+1,yi,s),c=hash(xi,yi+1,s),d=hash(xi+1,yi+1,s);return a+(b-a)*u+(c-a)*v+(a-b-c+d)*u*v}
const BAY=[0,8,2,10,12,4,14,6,3,11,1,9,15,7,13,5].map(v=>(v+.5)/16),bay=(x,y)=>BAY[(y&3)*4+(x&3)];
function rp(R,v,x,y){const n=R.length-1,i=Math.floor(v*n+bay(x,y));return R[i<0?0:i>n?n:i]}

const GRASS=R_(['#1c3822','#244a29','#2d5d30','#387234','#47873b','#5c9e44','#7ab450']);
const DIRT=R_(['#3a281a','#523620','#6a4a2a','#836034','#9a7642','#b08c54']);
const MOSS=R_(['#22401f','#2f5528','#3e6c31','#52833a']);
const LEAF=R_(['#10261a','#173a20','#1f4f27','#2a652e','#387b35','#4b923c','#66aa48','#8cc45c']);
const BARK=R_(['#24160e','#3a2416','#52341f','#6b4629','#835a36']);
const WOOD=R_(['#2a1a10','#40281a','#5a3a24','#74502f','#8e663c','#a87e4c']);
const BASALT=R_(['#15131a','#1f1c25','#2a2631','#36313e','#443e4d','#554d5e','#6a6274']);
const SILVER=R_(['#4a4e5a','#6e7482','#9aa0ae','#c4c8d2','#e4e6ee']);
const MARBLE=R_(['#3c3c42','#535259','#6b6a72','#85848b','#9e9da3','#b4b2b6','#c6c4c6']);
const SLATE=R_(['#1e2430','#2a3240','#3a4454','#4c5868','#5e6c7e']);
const SAND=R_(['#3a2a1c','#54402a','#6e5638','#8a6e48','#a68a5c','#c2a674','#d8c08e']);
const COPPER=R_(['#3a1c0c','#5e3016','#84461f','#a8602c','#c47c3e','#dc9c5c']);
const ORNG=R_(['#5a1e06','#8a3410','#b8501a','#e07028','#f89a48']);
const MSTONE=R_(['#1e2622','#2a342f','#3a463e','#4c5a50','#617064','#7a887a','#96a294']);
const BONE=R_(['#6e6656','#948a74','#b8ad94','#d8cfb4','#ece6d2']);
const WATER=R_(['#0e2a24','#14403a','#1c5a50']);
// lumières de nuit
const VIOBLUE=[.62,.64,1.35],ORANGE=[1.3,.62,.22],GREEN=[.5,1.2,.5],WHITEC=[1.08,1.1,1.2];

// ---------- tampon de pixels ----------
class Pix{constructor(w,h){this.w=w;this.h=h;this.c=new Int32Array(w*h).fill(-1);this.bx0=w;this.by0=h;this.bx1=-1;this.by1=-1}
 set(x,y,c){x=Math.floor(x);y=Math.floor(y);if(x<0||y<0||x>=this.w||y>=this.h||c==null)return;if(typeof c!=='number')c=ci(c);if(c<0)return;this.c[y*this.w+x]=c;if(x<this.bx0)this.bx0=x;if(x>this.bx1)this.bx1=x;if(y<this.by0)this.by0=y;if(y>this.by1)this.by1=y}
 get(x,y){return x<0||y<0||x>=this.w||y>=this.h?-1:this.c[y*this.w+x]}
 rect(x,y,w,h,c){x=Math.round(x);y=Math.round(y);for(let j=y;j<y+Math.round(h);j++)for(let i=x;i<x+Math.round(w);i++)this.set(i,j,typeof c==='function'?c(i,j):c)}
 ell(cx,cy,rx,ry,c){const f=typeof c==='function';for(let j=Math.floor(cy-ry);j<=Math.ceil(cy+ry);j++)for(let i=Math.floor(cx-rx);i<=Math.ceil(cx+rx);i++){const dx=(i+.5-cx)/rx,dy=(j+.5-cy)/ry;if(dx*dx+dy*dy<=1)this.set(i,j,f?c(i,j,dx,dy):c)}}
 line(x0,y0,x1,y1,c){const n=Math.max(1,Math.ceil(Math.max(Math.abs(x1-x0),Math.abs(y1-y0))));for(let k=0;k<=n;k++)this.set(Math.round(x0+(x1-x0)*k/n),Math.round(y0+(y1-y0)*k/n),c)}
 outline(col=OUTL){if(this.bx1<0)return;const w=this.w,h=this.h,s=this.c,n=new Int32Array(s);
  for(let y=Math.max(0,this.by0-1);y<=Math.min(h-1,this.by1+1);y++)for(let x=Math.max(0,this.bx0-1);x<=Math.min(w-1,this.bx1+1);x++){const i=y*w+x;if(s[i]!==-1)continue;if((x>0&&s[i-1]!==-1)||(x<w-1&&s[i+1]!==-1)||(y>0&&s[i-w]!==-1)||(y<h-1&&s[i+w]!==-1))n[i]=col}
  this.c=n;this.bx0=Math.max(0,this.bx0-1);this.by0=Math.max(0,this.by0-1);this.bx1=Math.min(w-1,this.bx1+1);this.by1=Math.min(h-1,this.by1+1)}
 blit(s,dx,dy,mask){dx=Math.round(dx);dy=Math.round(dy);for(let y=s.by0;y<=s.by1;y++)for(let x=s.bx0;x<=s.bx1;x++){const v=s.c[y*s.w+x];if(v===-1)continue;const X=x+dx,Y=y+dy;if(X<0||Y<0||X>=this.w||Y>=this.h)continue;this.c[Y*this.w+X]=v;if(mask)mask[Y*this.w+X]=1;if(X<this.bx0)this.bx0=X;if(X>this.bx1)this.bx1=X;if(Y<this.by0)this.by0=Y;if(Y>this.by1)this.by1=Y}}}

// ---------- projection 3/4 (celle du jeu) ----------
let T=20,W=208,H=168,OX=104,OY=118;
function configure(t,w,h,ox,oy){T=t;W=w;H=h;OX=ox;OY=oy}
const P3=(x,y,z)=>[OX+x*T,OY+(z-y)*T];

// ---------- formes au sol (x, z) ----------
function shapeOf(pts){let a=0;for(let i=0;i<pts.length;i++){const[p,q]=pts[i],[r,s]=pts[(i+1)%pts.length];a+=p*s-r*q}const sg=a>0?1:-1;
 const edges=pts.map((p,i)=>{const q=pts[(i+1)%pts.length],dx=q[0]-p[0],dz=q[1]-p[1],l=Math.hypot(dx,dz);return{p,dx,dz,l,n:[sg*dz/l,-sg*dx/l]}});
 const ext=Math.max(...pts.map(p=>Math.hypot(p[0],p[1])));
 return{pts,ext,inside(x,z){let c=false;for(let i=0,j=pts.length-1;i<pts.length;j=i++){const[xi,zi]=pts[i],[xj,zj]=pts[j];if((zi>z)!==(zj>z)&&x<(xj-xi)*(z-zi)/(zj-zi)+xi)c=!c}return c},
  normal(x,z){let best=1e9,n=[0,1];for(const e of edges){const t=Math.max(0,Math.min(1,((x-e.p[0])*e.dx+(z-e.p[1])*e.dz)/(e.l*e.l))),d=Math.hypot(x-e.p[0]-e.dx*t,z-e.p[1]-e.dz*t);if(d<best){best=d;n=e.n}}return n}}}
const poly=(n,r,rot=0)=>shapeOf(Array.from({length:n},(_,i)=>{const a=rot+i*2*Math.PI/n;return[Math.cos(a)*r,Math.sin(a)*r]}));
const circle=r=>poly(40,r);
const square=h=>poly(4,h*Math.SQRT2,Math.PI/4);        // demi-côté h, aligné sur la grille
const diamond=r=>poly(4,r,0);                           // carré posé sur la pointe
const star=(n,r1,r2,rot=-Math.PI/2)=>shapeOf(Array.from({length:n*2},(_,i)=>{const a=rot+i*Math.PI/n,r=i&1?r2:r1;return[Math.cos(a)*r,Math.sin(a)*r]}));
const tri=r=>poly(3,r,Math.PI/2);                       // pointe vers le spectateur

// ---------- extrusion d'une forme : dessus éclairé, flancs ombrés selon la normale ----------
// o: {x,z,y0,y1,mat,taper:[s0,s1]}
function prism(L,shape,o){const cx=o.x||0,cz=o.z||0,y0=o.y0,y1=o.y1,m=o.mat,ta=o.taper||[1,1],hh=y1-y0||1,sc=y=>ta[0]+(ta[1]-ta[0])*(y-y0)/hh,ext=shape.ext*Math.max(ta[0],ta[1]);
 const sx0=Math.floor(OX+(cx-ext)*T)-1,sx1=Math.ceil(OX+(cx+ext)*T)+1,sy0=Math.floor(OY+(cz-ext-y1)*T)-1,sy1=Math.ceil(OY+(cz+ext-y0)*T)+1,st=.5/T,e=.9/T,tp=ta[1]<ta[0]?.1:0;
 for(let sy=sy0;sy<=sy1;sy++)for(let sx=sx0;sx<=sx1;sx++){const x=(sx+.5-OX)/T-cx,zb=(sy+.5-OY)/T-cz;let s=sc(y1);
  if(s>.02){const z=zb+y1,X=x/s,Z=z/s;if(shape.inside(X,Z)){const rim=!shape.inside((x-e)/s,Z)||!shape.inside((x+e)/s,Z)||!shape.inside(X,(z-e)/s)||!shape.inside(X,(z+e)/s);
   L.set(sx,sy,m({f:'top',x,z,y:y1,rim,sx,sy,X,Z,rad:Math.hypot(x,z),ang:Math.atan2(z,x)}));continue}}
  for(let y=y1-st;y>=y0-1e-6;y-=st){s=sc(y);if(s<=.01)continue;const z=zb+y,X=x/s,Z=z/s;if(shape.inside(X,Z)){const n=shape.normal(X,Z),b=.4+.32*Math.max(0,-.55*n[0]+.83*n[1])+tp;
   L.set(sx,sy,m({f:'side',x,z,y,v:(y-y0)/hh,b,lip:y>y1-1.2/T,foot:y<y0+1.2/T,n,sx,sy,X,Z,rad:Math.hypot(x,z),ang:Math.atan2(z,x)}));break}}}}

// ---------- matériaux ----------
// o: {courses, joint, trim:{R,v0,v1}, moss, veins, noise, seed, inlay(q), pave(q)}
function stone(R,o={}){return q=>{if(o.inlay){const c=o.inlay(q);if(c!=null)return c}
 let b=q.f==='top'?.84:q.b;
 if(q.f==='top'){if(q.rim)b+=.14;else if(o.pave){const d=o.pave(q);if(d)b-=d}}
 else{if(q.lip)b+=.16;if(q.foot)b-=.18;
  if(o.trim&&q.v>=o.trim.v0&&q.v<=o.trim.v1)return rp(o.trim.R,b+(q.lip?.1:0),q.sx,q.sy);
  if(o.courses&&!q.lip){const c=o.courses,row=Math.floor(q.y/c+1e-6),lv=q.y-row*c;if(lv<.9/T&&q.y>.05)b-=.2;else{const jw=o.joint||.6,u=q.ang*2.2+(row&1)*.5*jw/1.2;if(Math.abs(q.n[1])>.5){const ux=q.x+(row&1)*jw/2;if(((ux%jw)+jw)%jw<.9/T)b-=.16}else if(((u%jw)+jw)%jw<.9/T)b-=.16}}}
 if(o.veins){const n=vnoise(q.x*4.5+q.y*3,q.z*4.5,77);if(Math.abs(n-.5)<.018)b-=.3;b+=(n-.5)*.14}
 b+=(vnoise(q.x*7,(q.z+q.y)*7,o.seed||3)-.5)*(o.noise??.14);
 if(o.moss){const n=vnoise(q.x*3.1,(q.z+q.y*.5)*3.1,51);if(n>1-o.moss&&(q.f==='top'||q.v<.55))return rp(MOSS,b*.9,q.sx,q.sy)}
 return rp(R,b,q.sx,q.sy)}}
// incrustations (dessus)
const ringI=(r,w,c)=>q=>q.f==='top'&&Math.abs(q.rad-r)<w?c:null;
const dotsI=(r,n,c,ph=0)=>q=>{if(q.f!=='top')return null;for(let k=0;k<n;k++){const a=ph+k*2*Math.PI/n;if(Math.hypot(q.x-Math.cos(a)*r,q.z-Math.sin(a)*r)<.07)return c}return null};
function segD(x,z,a,b){const vx=b[0]-a[0],vz=b[1]-a[1],t=Math.max(0,Math.min(1,((x-a[0])*vx+(z-a[1])*vz)/(vx*vx+vz*vz)));return Math.hypot(x-a[0]-vx*t,z-a[1]-vz*t)}
const linesI=(segs,w,c)=>q=>{if(q.f!=='top')return null;for(const[a,b]of segs)if(segD(q.x,q.z,a,b)<w)return c;return null};
const spiralI=(r0,r1,turns,w,c)=>q=>{if(q.f!=='top'||q.rad<r0||q.rad>r1)return null;const t=(q.rad-r0)/(r1-r0);let a=q.ang-t*turns*2*Math.PI;a=((a%(2*Math.PI))+2*Math.PI)%(2*Math.PI);return a<w||a>2*Math.PI-w?c:null};
// incrustations (flancs)
const bandI=(v0,v1,c,step=.18,seed=1)=>q=>{if(q.f!=='side'||q.v<v0||q.v>v1||q.lip)return null;const u=Math.floor((q.x+5)/step),k=hash(u,0,seed);const lv=(q.v-v0)/(v1-v0),lu=((q.x+5)/step)-u;
 if(k<.25)return null;if(k<.55?lu>.25&&lu<.75&&lv>.15&&lv<.85:(lv>.2&&lv<.4)||(lv>.6&&lv<.8)?lu>.15&&lu<.85:lu>.4&&lu<.6)return c;return null};
const vlineI=(c,w=.05,v0=.1,v1=.9)=>q=>q.f==='side'&&Math.abs(q.x)<w&&q.n[1]>.5&&q.v>v0&&q.v<v1?c:null;
const anyI=(...fs)=>q=>{for(const f of fs){const c=f(q);if(c!=null)return c}return null};

// ---------- statues : grilles de pixels ----------
// 1-6 : rampe du corps · p-t : drapé · A/B : accent émissif · 0 : creux sombre
function legs(l,r,a='54',b='43'){return[[l,'s'+'r'.repeat(Math.max(0,7-l))+'qq'],[10,a],[12,'pp'],[14,b],[16,'qq'+'r'.repeat(Math.max(0,r-18))+'q']]}
function rep(n,row){return Array.from({length:n},()=>row)}
const ST={
 aether:{ax:12.5,rows:[
  [[2,'5.5.5'],[11,'A..A']],
  [[2,'6.6.6'],[9,'A.AAAA.A']],
  [[2,'4.4.4'],[10,'566554']],
  [[2,'4.4.4'],[10,'655444']],
  [[1,'34445'],[10,'665543']],
  [[1,'34544'],[10,'605043']],
  [[2,'444'],[10,'665543']],
  [[3,'44'],[10,'556443']],
  [[4,'44'],[11,'5543']],
  [[5,'44'],[12,'54']],
  [[6,'44'],[8,'r55544433r'],[18,'4']],
  [[5,'srr4'],[9,'56554433'],[17,'r44']],
  [[5,'srr'],[8,'4'],[9,'56654333'],[17,'r'],[18,'43'],[21,'5....5']],
  [[4,'srrr'],[8,'r'],[9,'55654332'],[17,'r'],[18,'43'],[21,'6....6']],
  [[4,'srrr'],[8,'r'],[9,'55543332'],[17,'rr'],[19,'43'],[21,'655556']],
  [[4,'srrr'],[8,'r'],[9,'45543322'],[17,'rrr'],[22,'BB'],[26,'5'],[20,'45']],
  [[3,'srrrr'],[8,'r'],[9,'44443322'],[17,'rrr'],[21,'5.BB.5']],
  [[3,'srrrr'],[8,'pqqqqqqqqp'],[18,'rr'],[21,'5.BB.5']],
  [[3,'srrrr'],[8,'tsqtsqtsqt'],[18,'rrr'],[22,'4BB4']],
  [[3,'srrrr'],[8,'tsqtsqtsqt'],[18,'rrrr'],[23,'44']],
  [[2,'srrrrr'],[8,'tsqtsqtsqt'],[18,'rrrrq']],
  [[2,'srrrrr'],[8,'tsqtsqtsqt'],[18,'rrrrq']],
  [[2,'srrrrr'],[8,'ts.ts.ts.t'],[18,'rrrrq']],
  ...rep(5,legs(2,22)),...rep(6,legs(1,23,'55','44')),
  [...legs(1,23),[9,'554'],[14,'433']],
  [[1,'pqqqqqqq'],[9,'443'],[12,'pp'],[14,'332'],[17,'qqqqqqp']]],
  lights:[{dx:0,dy:-34,r:34,i:.6},{dx:11,dy:-20,r:22,i:.5}]},
 indra:{ax:12.5,rows:[
  [[12,'ts']],
  [[5,'6'],[11,'tssr']],
  [[4,'565'],[11,'tssr']],
  [[4,'454'],[10,'5'],[11,'tssr'],[15,'4']],
  [[9,'56665544']],
  [[9,'66655443']],
  [[9,'65B55B43']],
  [[9,'65055043']],
  [[9,'55055043']],
  [[10,'453343']],
  [[11,'4433']],
  [[6,'r'],[7,'566'],[10,'554433'],[16,'544'],[19,'q']],
  [[6,'r'],[7,'65'],[9,'56654443'],[17,'54'],[19,'q']],
  [[6,'r'],[7,'54'],[9,'56654433'],[17,'43'],[19,'q']],
  [[6,'44'],[8,'r'],[9,'55654433'],[17,'4'],[18,'rq']],
  [[4,'454'],[7,'rr'],[9,'55543332'],[17,'rrq']],
  [[4,'444'],[7,'rr'],[9,'45543322'],[17,'rrq']],
  [[6,'srr'],[9,'44443322'],[17,'rrq']],
  [[6,'sr'],[8,'pqBqqqqBqp'],[18,'rq']],
  ...rep(5,[[6,'sr'],[8,'tsqtsqtsqt'],[18,'rq']]),
  [[6,'sr'],[8,'ts.ts.ts.t'],[18,'rq']],
  ...rep(5,[[6,'srqq'],[10,'55'],[12,'pp'],[14,'44'],[16,'qqrq']]),
  ...rep(5,[[6,'srqq'],[10,'65'],[12,'pp'],[14,'54'],[16,'qqrq']]),
  [[6,'pqq'],[9,'554'],[12,'pp'],[14,'433'],[17,'qqp']]],
  mid(P,c,o){for(let y=4;y<36;y++)if(y<15||y>16)P.set(5+o,y+1,c('3'))},
  over(P,c,o){const cx=17+o,cy=24;P.ell(cx,cy,5.3,5.6,(x,y,dx,dy)=>{const d=dx*dx+dy*dy;if(d>.7)return c(d>.86?'3':'5');if(d<.09)return c('6');if(d<.16)return c('4');return c(dx+dy<-.2?'s':dx+dy>.5?'q':'r')});
   P.line(19+o,21,22+o,17,c('5'));P.set(22+o,17,c('6'));P.set(21+o,17,c('s'));P.set(22+o,18,c('s'))},
  lights:[{dx:0,dy:-31,r:20,i:.5},{dx:4,dy:-13,r:24,i:.4}]},
 medeina:{ax:12.5,rows:[
  [[9,'r'],[12,'s'],[15,'r'],[21,'6']],
  [[8,'rq'],[11,'ts'],[14,'sr'],[17,'q'],[20,'565']],
  [[1,'4.4.4'],[7,'q'],[8,'rstssr'],[14,'rsrq'],[20,'565']],
  [[1,'54544'],[6,'qr'],[8,'stsssr'],[14,'srrq']],
  [[1,'5544'],[5,'q'],[6,'rs'],[8,'t'],[9,'s'],[10,'555544'],[16,'sr'],[18,'q']],
  [[2,'544'],[5,'rs'],[7,'s'],[8,'t'],[9,'s'],[10,'5B55B4'],[16,'srq']],
  [[3,'44'],[5,'r'],[6,'s'],[7,'r'],[8,'s'],[9,'s'],[10,'665543'],[16,'sr'],[18,'rq']],
  [[4,'44'],[6,'r'],[7,'s'],[8,'r'],[9,'s'],[10,'565543'],[16,'s'],[17,'rq']],
  [[5,'44'],[7,'rs'],[9,'r'],[11,'5543'],[15,'rs'],[17,'rq']],
  [[6,'44'],[8,'s'],[12,'54'],[16,'sr'],[18,'q']],
  [[7,'44'],[9,'s'],[10,'555443'],[16,'r'],[17,'4']],
  [[8,'4s'],[10,'5AAAA4'],[16,'r44']],
  [[8,'ss'],[10,'665543'],[16,'r'],[17,'r4']],
  [[8,'sr'],[10,'566543'],[16,'r'],[17,'r4']],
  [[8,'rr'],[10,'556543'],[16,'q'],[17,'r'],[18,'4']],
  [[8,'rq'],[10,'555443'],[16,'q'],[18,'44']],
  [[9,'q'],[10,'455433'],[16,'q'],[19,'454']],
  [[9,'q'],[10,'445433'],[16,'q'],[19,'444']],
  [[9,'pqAqqAqp']],
  [[11,'rssr']],[[11,'rssr']],[[11,'rAAr']],[[11,'rssr']],[[11,'rssr']],[[11,'rAAr']],[[11,'rssr']],[[11,'q..q']]],
  mid(P,c,o){for(let y=3;y<37;y++)if(y<16||y>17)P.set(21+o,y+1,c('3'))},
  under(P,c,o){const pts=[[12.5,19,3.4],[12.5,23,3.3],[13,27,3.1],[15.5,30,2.9],[17.5,33,2.7],[16,36,2.5],[12,37.4,2.3],[8,36.4,2.1],[5.8,33.6,1.9],[7.2,31,1.6],[9.6,30.4,1.3],[11,31.2,1]];
   for(let k=0;k<pts.length-1;k++){const[a,b,r]=pts[k],[d,e,s]=pts[k+1];for(let t=0;t<1;t+=.08){const x=a+(d-a)*t+o,y=b+(e-b)*t+1,R=r+(s-r)*t;P.ell(x,y,R,R*.92,(px,py,dx,dy)=>{const q=dx*dx+dy*dy;if(q>.72)return c('2');return c((px+py*2)%4===0?'3':dx<-.2?'5':'4')})}}},
  lights:[{dx:0,dy:-35,r:24,i:.55},{dx:0,dy:-28,r:16,i:.4}]},
 sigil:{ax:12.5,rows:[
  [[10,'tssssr']],
  [[9,'tssssssr']],
  [[4,'4.4'],[8,'t'],[9,'s'],[10,'433332'],[16,'r'],[17,'q'],[20,'4.4']],
  [[4,'545'],[8,'t'],[9,'s'],[10,'3B33B2'],[16,'r'],[17,'q'],[20,'544']],
  [[4,'44'],[8,'t'],[9,'s'],[10,'433332'],[16,'r'],[17,'q'],[20,'44']],
  [[4,'AA'],[8,'ts'],[10,'s3322r'],[16,'rq'],[20,'AA']],
  [[4,'ts'],[8,'tsss'],[12,'33'],[14,'ssrq'],[20,'rq']],
  [[4,'tssssssssssssssrrq']],
  [[4,'tsr'],[7,'tsssssssssrq'],[19,'rrq']],
  [[4,'tr'],[8,'tsss'],[12,'BB'],[14,'ssrq'],[20,'rq']],
  [[8,'tss'],[11,'B'],[12,'ss'],[14,'B'],[15,'srq']],
  [[8,'tsss'],[12,'BB'],[14,'ssrq']],
  [[8,'ts'],[10,'BBBBBB'],[16,'rq']],
  [[8,'tsss'],[12,'BB'],[14,'ssrq']],
  [[8,'tsss'],[12,'BB'],[14,'ssrq']],
  [[8,'pqqqAAqqqp']],
  [[8,'tsss'],[12,'AA'],[14,'ssrq']],
  [[8,'tsss'],[12,'AA'],[14,'ssrq']],
  ...Array.from({length:12},(_,k)=>{const l=k<6?8:7,r=k<6?17:18;let s='t';for(let x=l+1;x<r-1;x++)s+=(x-l)%3===0?'r':'s';return[[l,s+'rq']]}),
  [[7,'pqqqqqqqqqqp']],
  [[9,'554'],[14,'433']]],
  lights:[{dx:0,dy:-24,r:30,i:.55},{dx:-8,dy:-30,r:16,i:.5},{dx:8,dy:-30,r:16,i:.5}]}};

const SMAT={
 aether:{body:['#2e3248','#4c5270','#6e7494','#959bb8','#bcc0d6','#e0e2ee'],drape:['#1c1840','#28245c','#38347e','#4c4aa0','#6866be'],A:'#8a8eff',B:'#d0d4ff',dark:'#14121c'},
 aetherB:{body:['#121018','#1c1824','#2a2534','#3a3446','#4c455a','#605870'],drape:['#141024','#1e1838','#2a2450','#383068','#484082'],A:'#7a80ff',B:'#c8ccff',dark:'#08070c'},
 indra:{body:['#3a1c0c','#5e3016','#84461f','#a8602c','#c47c3e','#dc9c5c'],drape:['#5a1e06','#8a3410','#b8501a','#e07028','#f89a48'],A:'#ff8a2a',B:'#ffc890',dark:'#1a0c06'},
 indraS:{body:['#3a2a1c','#54402a','#6e5638','#8a6e48','#a68a5c','#c2a674'],drape:['#5a1e06','#8a3410','#b8501a','#e07028','#f89a48'],A:'#ff8a2a',B:'#ffc890',dark:'#1a0c06'},
 medeina:{body:['#2a3a32','#40564a','#5a7466','#7a9484','#9cb4a2','#c0d2c2'],drape:['#13301a','#1c4524','#265c2c','#337434','#468c3c'],A:'#7ae070',B:'#d0ffb8',dark:'#0a140e'},
 medeinaB:{body:['#3a3428','#5a5040','#7a6e58','#9a8e74','#bcb094','#dcd2b6'],drape:['#13301a','#1c4524','#265c2c','#337434','#468c3c'],A:'#7ae070',B:'#d0ffb8',dark:'#14100a'},
 sigil:{body:['#2c2c32','#535259','#6b6a72','#85848b','#a3a2a8','#c6c4c6'],drape:['#4a4a52','#64646c','#828189','#a2a1a7','#c0bfc2'],A:'#c4c8d4',B:'#f4f6ff',dark:'#141418'},
 sigilS:{body:['#161a22','#1e2430','#2a3240','#3a4454','#4c5868','#5e6c7e'],drape:['#1e2430','#2a3240','#3a4454','#4c5868','#5e6c7e'],A:'#c4c8d4',B:'#f4f6ff',dark:'#0c0e12'}};

const SPR=new Map();
function statue(god,matKey){const k=god+'/'+matKey;if(SPR.has(k))return SPR.get(k);const d=ST[god],M=SMAT[matKey||god],o=3,P=new Pix(36,d.rows.length+6);
 const col=ch=>{if(ch>='1'&&ch<='6')return ci(M.body[ch-1]);const i='pqrst'.indexOf(ch);if(i>=0)return ci(M.drape[i]);if(ch==='A')return E(M.A);if(ch==='B')return E(M.B);if(ch==='0')return ci(M.dark);return -1};
 if(d.under)d.under(P,col,o);
 d.rows.forEach((row,r)=>{for(const[c0,s]of row)for(let k=0;k<s.length;k++){const ch=s[k];if(ch!=='.')P.set(c0+k+o,r+1,col(ch))}});
 if(d.mid)d.mid(P,col,o);if(d.over)d.over(P,col,o);
 // la Gorgone : quelques têtes de serpent dans la chevelure
 if(god==='medeina')for(const[x,y]of[[9,0],[12,0],[15,0],[7,2],[18,3]]){P.set(x+o,y+1,col('s'));P.set(x+o,y,col('r'))}
 P.outline();let bot=0;for(let y=P.h-1;y>=0&&!bot;y--)for(let x=0;x<P.w;x++)if(P.get(x,y)>=0&&P.get(x,y)!==OUTL){bot=y;break}
 const r={P,ax:Math.round(d.ax+o),ay:bot,lights:d.lights};SPR.set(k,r);return r}

// ---------- scène ----------
const KEYS=[[0,[.27,.3,.48]],[4.5,[.29,.31,.49]],[6.5,[.8,.62,.66]],[8.5,[1,.96,.9]],[13,[1.05,1.02,.96]],[17,[1,.93,.82]],[19,[.95,.62,.5]],[20.5,[.44,.4,.58]],[24,[.27,.3,.48]]];
function ambient(h){h=((h%24)+24)%24;for(let k=1;k<KEYS.length;k++)if(h<=KEYS[k][0]){const[a,A]=KEYS[k-1],[b,B]=KEYS[k],t=(h-a)/(b-a);return A.map((v,i)=>v+(B[i]-v)*t)}return KEYS[0][1]}
class Scene{constructor(){this.P=new Pix(W,H);this.F=new Pix(W,H);this.sh=new Float32Array(W*H);this.mask=new Uint8Array(W*H);this.lights=[];this.dyn=[];this.L=[0,1,2].map(()=>new Float32Array(W*H));this.A=[0,1,2].map(()=>new Float32Array(W*H))}
 shadowShape(shape,cx,cz,h,a=.85){const dx=h*.5,dz=h*.22,ext=shape.ext;for(let sy=Math.floor(OY+(cz-ext)*T)-1;sy<=OY+(cz+ext+dz)*T+1;sy++)for(let sx=Math.floor(OX+(cx-ext)*T)-1;sx<=OX+(cx+ext+dx)*T+1;sx++){if(sx<0||sy<0||sx>=W||sy>=H)continue;const x=(sx+.5-OX)/T-cx,z=(sy+.5-OY)/T-cz;for(let k=0;k<=8;k++){const t=k/8;if(shape.inside(x-dx*t,z-dz*t)){const i=sy*W+sx;this.sh[i]=Math.max(this.sh[i],a);break}}}}
 shadowEll(cx,cy,rx,ry,a){for(let y=Math.floor(cy-ry);y<=cy+ry;y++)for(let x=Math.floor(cx-rx);x<=cx+rx;x++){if(x<0||y<0||x>=W||y>=H)continue;const dx=(x+.5-cx)/rx,dy=(y+.5-cy)/ry;if(dx*dx+dy*dy<=1){const i=y*W+x;this.sh[i]=Math.max(this.sh[i],a)}}}
 bake(ground,objs){for(let y=0;y<H;y++)for(let x=0;x<W;x++){const wx=(x+.5-OX)/T,wz=(y+.5-OY)/T;this.P.set(x,y,ground(wx,wz,x,y))}
  this.ground=new Int32Array(this.P.c);objs.sort((a,b)=>a.key-b.key);
  for(const o of objs){const L=new Pix(W,H),r=o.draw(L,this)||{};if(!r.noOutline)L.outline();if(r.post)r.post(L);this.P.blit(L,0,0,o.statue?this.mask:null);if(r.lights)this.lights.push(...r.lights);if(r.dyn)this.dyn.push(r.dyn)}
  return this}
 render(g,hour,t){const amb=ambient(hour),lum=.3*amb[0]+.59*amb[1]+.11*amb[2],night=Math.max(0,Math.min(1,(.9-lum)/.6)),day=Math.max(0,Math.min(1,(lum-.45)/.5)),[lr,lg,lb]=this.L,[ar,ag,ab]=this.A;
  const F=this.F;F.c.set(this.P.c);for(const d of this.dyn)d(F,t,this);
  lr.fill(0);lg.fill(0);lb.fill(0);ar.fill(0);ag.fill(0);ab.fill(0);
  if(night>.02)for(const L of this.lights){const add=L.add??(L.c===WHITEC?.2:L.c===VIOBLUE?.12:.04),fl=L.fl||0,I=L.i*night*(1+fl*(Math.sin(t*9.3+L.x)*.5+Math.sin(t*14.1+L.y*1.7)*.35)),R=L.r;
   for(let y=Math.max(0,Math.floor(L.y-R/1.3));y<=Math.min(H-1,L.y+R/1.3);y++)for(let x=Math.max(0,Math.floor(L.x-R));x<=Math.min(W-1,L.x+R);x++){const dx=x+.5-L.x,dy=(y+.5-L.y)*1.3,d=Math.sqrt(dx*dx+dy*dy)/R;if(d>=1)continue;let f=1-d;f=f*f*(3-2*f);const q=Math.floor(f*5+bay(x,y))/5;if(q<=0)continue;const i=y*W+x;lr[i]+=L.c[0]*I*q;lg[i]+=L.c[1]*I*q;lb[i]+=L.c[2]*I*q;if(add){const k=add*I*q*255;ar[i]+=L.c[0]*k;ag[i]+=L.c[1]*k;ab[i]+=L.c[2]*k}}}
  if(!this.img)this.img=g.createImageData(W,H);const d=this.img.data,P=F.c,G=this.ground,S=this.sh;
  for(let i=0,o=0;i<W*H;i++,o+=4){const v=P[i];if(v<0){d[o]=11;d[o+1]=18;d[o+2]=14;d[o+3]=255;continue}const r=v>>16&255,gg=v>>8&255,b=v&255;
   if(v&0x1000000){const k=1+night*.15;d[o]=Math.min(255,r*k);d[o+1]=Math.min(255,gg*k);d[o+2]=Math.min(255,b*k)}
   else{const s=v===G[i]?1-S[i]*day*.42:1;d[o]=Math.min(255,r*(amb[0]*s+lr[i])+ar[i]);d[o+1]=Math.min(255,gg*(amb[1]*s+lg[i])+ag[i]);d[o+2]=Math.min(255,b*(amb[2]*s+lb[i])+ab[i])}d[o+3]=255}
  g.putImageData(this.img,0,0)}}

// ---------- objets ----------
// palier/piton : forme extrudée posée en (x,z) entre y0 et y1
function slab(shape,y0,y1,mat,o={}){const x=o.x||0,z=o.z||0;return{statue:!!o.mask,key:o.key??(z-shape.ext*Math.max(...(o.taper||[1]))+y0*.01),draw(L,S){if(y0<.01&&y1-y0>.12)S.shadowShape(shape,x,z,y1-y0,o.shadow??.8);prism(L,shape,{x,z,y0,y1,mat,taper:o.taper});return{lights:projL(o.lights)}}}}
const projL=ls=>(ls||[]).map(l=>{const[sx,sy]=P3(l.x,l.y,l.z);return{...l,x:sx,y:sy}});
function statueObj(god,y,matKey,o={}){return{key:.02,statue:true,draw(L,S){const sp=statue(god,matKey),[sx,sy]=P3(o.x||0,y,o.z||0),ox=Math.round(sx)-sp.ax,oy=Math.round(sy)-sp.ay-(o.lift||0);
 const c=o.light;const lights=sp.lights.map(l=>({x:sx+l.dx,y:sy+l.dy-(o.lift||0),r:l.r,i:l.i,c,fl:.04}));
 if(o.float){for(let b=-2;b<=2;b++){const M=new Pix(W,H);M.blit(sp.P,ox,oy+b,S.mask)}return{noOutline:true,lights,dyn(F,t){const b=Math.round(Math.sin(t*1.6)*2);F.blit(sp.P,ox,oy+b);}}}
 L.blit(sp.P,ox,oy);return{noOutline:true,lights}}}}
// auréole sculptée derrière la statue (disque de pierre, rayons, incrustation lumineuse)
function haloObj(y,R,ringR,glow,o={}){return{key:-.05,statue:true,draw(L){const[sx,sy0]=P3(0,y,0),sy=sy0-(o.dy??34),cx=Math.round(sx),cy=Math.round(sy);
 if(o.stem)prism(L,square(.07),{x:0,z:-.18,y0:y-.1,y1:y+(o.dy??34)/T,mat:stone(o.stemR||R,{noise:.08})});
 L.ell(cx,cy,o.r||15,o.r||15,(x,y,dx,dy)=>{const d=Math.hypot(dx,dy);if(d>.84)return rp(ringR,.85-dx*.3-dy*.3,x,y);if(Math.abs(d-.7)<.05)return glow;if(o.rays&&d>.3){const a=Math.atan2(dy,dx);if(Math.abs(Math.sin(a*(o.rays/2)))<.13)return rp(ringR,.75-dy*.2,x,y)}if(o.moon)return rp(o.moon,.55-dx*.25-dy*.25+(vnoise(x*.4,y*.4,9)-.5)*.3,x,y);return rp(R,.32-dy*.18,x,y)});
 if(o.spikes)for(let k=0;k<o.spikes;k++){const a=k*2*Math.PI/o.spikes-Math.PI/2,r0=(o.r||15)+1,r1=r0+(k&1?3:6);L.line(cx+Math.cos(a)*r0,cy+Math.sin(a)*r0,cx+Math.cos(a)*r1,cy+Math.sin(a)*r1,k&1?ringR[3]:glow)}
 return{lights:[{x:cx,y:cy,r:(o.r||15)+16,i:.35,c:o.light}]}}}}

// ---------- accessoires ----------
const FL={vb:['#5a5cff','#9aa0ff','#e0e4ff'],orange:['#e06a20','#ff9a30','#ffe0a0'],green:['#3ab048','#7ae070','#d0ffb8'],white:['#a8b0c4','#dfe4f0','#ffffff']};
function flameDyn(sx,sy,kind,sz=1){const c=FL[kind].map(E);return(F,t)=>{const k=Math.floor(t*10+sx*.37)%4,h=Math.round((3+((k*5)%3))*sz);for(let j=0;j<h;j++){const w=Math.max(0,Math.round((h-j)*.45*sz)),sway=Math.round(Math.sin(t*7+j*.8+sx)*.6*(j/h));for(let i=-w;i<=w;i++)F.set(sx+i+sway,sy-j,j>h-2?c[2]:Math.abs(i)<w*.5?c[2]:c[1])}F.set(sx,sy-h,c[0])}}
function brazier(x,z,R,kind,light){return{key:z,draw(L,S){const[sx,sy]=P3(x,0,z);S.shadowEll(sx+2,sy+1,7,3,.8);prism(L,circle(.11),{x,z,y0:0,y1:.55,mat:stone(R,{noise:.06})});prism(L,circle(.24),{x,z,y0:.55,y1:.75,mat:stone(R,{noise:.06}),taper:[.7,1]});
 const[fx,fy]=P3(x,.75,z-.05);return{lights:[{x:fx,y:fy-4,r:42,i:.95,c:light,fl:.18}],dyn:flameDyn(Math.round(fx),Math.round(fy),kind,1.1)}}}}
function obelisk(x,z,h,R,glow,o={}){const w=o.w||.13,y0=o.y0||0;h+=y0;return{key:z,draw(L,S){prism(L,square(w),{x,z,y0,y1:h,mat:stone(R,{noise:.08,inlay:o.glyph?vlineI(glow,.03,.25,.8):null})});prism(L,square(w),{x,z,y0:h,y1:h+w*1.6,mat:stone(R,{noise:.04}),taper:[1,0]});
 const[a,b]=P3(x,h+w*1.6,z);if(glow){L.set(a,b-1,glow);L.set(a,b,glow)}if(!y0)S.shadowShape(square(w),x,z,h,.7);return{lights:glow?[{x:a,y:b,r:20,i:.6,c:o.light}]:[]}}}}
function menhir(x,z,h,glow,light){return{key:z,draw(L,S){S.shadowShape(poly(5,.2),x,z,h,.7);prism(L,poly(5,.2,.3),{x,z,y0:0,y1:h,mat:stone(MSTONE,{moss:.22,inlay:vlineI(glow,.035,.35,.75)}),taper:[1,.6]});const[a,b]=P3(x,h*.55,z+.2);return{lights:[{x:a,y:b,r:18,i:.45,c:light}]}}}}
function spear(x,z,y0,h,flag){return{key:z,draw(L,S){const[a,b]=P3(x,y0,z),[,c]=P3(x,y0+h,z);L.line(a,b,a,c,WOOD[3]);L.line(a+1,b,a+1,c,WOOD[1]);L.set(a,c-1,SILVER[3]);L.set(a,c-2,SILVER[4]);L.set(a+1,c-1,SILVER[2]);L.set(a,c-3,SILVER[3]);
 return{dyn:(F,t)=>{for(let i=0;i<7;i++){const wv=Math.round(Math.sin(t*4-i*.7+x)*1.2*(i/6));for(let j=0;j<4-Math.floor(i/3);j++)F.set(a+2+i,c+2+j+wv,j===0?flag[2]:(i+j)&1?flag[1]:flag[0])}}}}}}
function column(x,z,h,R,o={}){return{key:z,draw(L,S){S.shadowShape(circle(.16),x,z,h,.7);prism(L,square(.17),{x,z,y0:0,y1:.12,mat:stone(R,{noise:.05})});prism(L,circle(.12),{x,z,y0:.12,y1:h-.1,mat:stone(R,{veins:1,noise:.05})});prism(L,square(.17),{x,z,y0:h-.1,y1:h,mat:stone(R,{noise:.05})});
 if(!o.flame)return{};const[a,b]=P3(x,h,z-.02);return{lights:[{x:a,y:b-3,r:34,i:.8,c:o.light,fl:.12}],dyn:flameDyn(Math.round(a),Math.round(b),o.flame,.9)}}}}
function bush(x,z,seed,bloom){return{key:z,draw(L,S){const[a,b]=P3(x,0,z);S.shadowEll(a,b,8,3,.7);const R=mulberry(seed);for(let k=0;k<6;k++){const bx=a+(R()-.5)*10,by=b-3-R()*5,r=3+R()*2;L.ell(bx,by,r,r*.85,(px,py,dx,dy)=>rp(LEAF,.6-dx*.15-dy*.3+(hash(px,py,3)-.5)*.15,px,py))}
 if(bloom)for(let k=0;k<7;k++){const px=Math.round(a+(R()-.5)*12),py=Math.round(b-3-R()*8);if(L.get(px,py)>=0)L.set(px,py,k%2?'#fff4d8':'#e8a0c0')}return{}}}}
function bones(x,z,seed){return{key:z,draw(L,S){const[a,b]=P3(x,0,z);S.shadowEll(a,b,7,3,.6);const R=mulberry(seed);for(let k=0;k<4;k++){const bx=a+(R()-.5)*9,by=b-1-R()*3;L.line(bx-3,by,bx+3,by+(R()-.5)*3,BONE[3]);L.set(bx-3,by-1,BONE[4]);L.set(bx+3,by+1,BONE[2])}L.ell(a,b-4,3,2.6,(px,py,dx,dy)=>rp(BONE,.75-dx*.2-dy*.3,px,py));L.set(a-1,b-4,BONE[0]);L.set(a+1,b-4,BONE[0]);return{}}}}
function banner(x,z,cloth){return{key:z,draw(L,S){const[a,b]=P3(x,0,z);S.shadowEll(a+3,b,5,2,.7);L.rect(a,b-34,1,35,WOOD[3]);L.rect(a-4,b-34,10,1,WOOD[2]);L.set(a,b-36,SILVER[3]);
 for(let y=0;y<18;y++)for(let i=-3;i<=4;i++){if(y>14&&Math.abs(i-.5)<y-14)continue;L.set(a+i,b-33+y,i===-3?cloth[2]:i>2?cloth[0]:cloth[1])}L.rect(a-1,b-27,3,3,cloth[3]);return{}}}}
function mulberry(s){return()=>{s|=0;s=s+0x6D2B79F5|0;let t=Math.imul(s^s>>>15,1|s);t=t+Math.imul(t^t>>>7,61|t)^t;return((t^t>>>14)>>>0)/4294967296}}

// ---------- effets animés ----------
function motes(cx,cy,spread,h,cols,n=10,seed=1){const c=cols.map(E);return(F,t)=>{for(let k=0;k<n;k++){const p=((t*.5+hash(k,1,seed))%1),x=Math.round(cx+(hash(k,2,seed)-.5)*spread*2+Math.sin(t*1.3+k)*2),y=Math.round(cy-p*h);if(p<.92)F.set(x,y,c[p>.6?0:p>.3?1:2])}}}
function orbit(cx,cy,rx,ry,n,cols,speed=.7,size=1){const c=cols.map(E);return(F,t,S)=>{for(let k=0;k<n;k++){const a=t*speed+k*2*Math.PI/n,x=Math.round(cx+Math.cos(a)*rx),y=Math.round(cy+Math.sin(a)*ry),front=Math.sin(a)>0;
 for(let j=-size;j<=size;j++)for(let i=-size;i<=size;i++){if(Math.abs(i)+Math.abs(j)>size)continue;const X=x+i,Y=y+j;if(X<0||Y<0||X>=W||Y>=H)continue;if(!front&&S.mask[Y*W+X])continue;F.set(X,Y,i===0&&j===0?c[2]:c[1])}}}}
function ringDyn(cx,cy,R,cols,speed=.5){const c=cols.map(E);return(F,t,S)=>{const sx=Math.cos(t*speed);for(let k=0;k<64;k++){const a=k*2*Math.PI/64,x=Math.round(cx+Math.cos(a)*R*sx),y=Math.round(cy+Math.sin(a)*R),front=Math.cos(a)*Math.sign(sx||1)*Math.sin(t*speed)>=0;if(x<0||y<0||x>=W||y>=H)continue;if(!front&&S.mask[y*W+x])continue;F.set(x,y,k%8===0?c[2]:c[0])}}}
function glyphOrbit(cx,cy,rx,ry,n,col,speed=.5){const c=E(col),d=sh(E(col),-.35);const G=[[1,0,1,0,1,0,1,0,1],[1,1,1,0,1,0,0,1,0],[0,1,0,1,1,1,0,1,0],[1,0,0,1,1,0,1,1,1]];return(F,t,S)=>{for(let k=0;k<n;k++){const a=t*speed+k*2*Math.PI/n,x=Math.round(cx+Math.cos(a)*rx)-1,y=Math.round(cy+Math.sin(a)*ry+Math.sin(t*2+k)*1.5)-1,front=Math.sin(a)>0,g=G[k%4];
 for(let j=0;j<3;j++)for(let i=0;i<3;i++){const X=x+i,Y=y+j;if(X<0||Y<0||X>=W||Y>=H)continue;if(!front&&S.mask[Y*W+X])continue;F.set(X,Y,g[j*3+i]?c:d)}}}}
function ripple(cx,cy,r0,r1,col){const c=E(col);return(F,t)=>{for(let k=0;k<3;k++){const p=((t*.4+k/3)%1),r=r0+(r1-r0)*p;for(let a=0;a<40;a++){if(hash(a,k,Math.floor(t*.4+k/3))<.5)continue;const an=a*2*Math.PI/40;F.set(Math.round(cx+Math.cos(an)*r),Math.round(cy+Math.sin(an)*r),c)}}}}

// ---------- sols ----------
function groundOf(kind,o={}){const pr=o.r??2.6,shape=o.shape;return(x,z,sx,sy)=>{const n=vnoise(x*1.3,z*1.3,7),e=Math.hypot(x/pr,z/(pr*.8));
 const paved=shape?shape.inside(x,z):false;
 if(paved){const P=o.pave||SLATE,g=o.grid||.5,u=((x%g)+g)%g,v=((z+(Math.floor(x/g)&1)*g/2)%g+g)%g;let b=.5+(vnoise(x*5,z*5,3)-.5)*.3;if(u<1/T||v<1/T)b-=.3;if(o.moss&&vnoise(x*2.3,z*2.3,41)>.66)return rp(MOSS,b,sx,sy);return rp(P,b,sx,sy)}
 if(e<1+(n-.5)*.4){if(kind==='dirt'){return rp(DIRT,.5+(vnoise(x*4,z*4,5)-.5)*.5,sx,sy)}if(kind==='moss'){const m=vnoise(x*2,z*2,11);return m>.6?rp(MOSS,.5+(n-.5),sx,sy):rp(GRASS,.55+(n-.5)*.5,sx,sy)}return rp(GRASS,.42+(n-.5)*.35,sx,sy)}
 const t=vnoise(x*2.2,z*2.2,17);if(t>.68){const v=hash(sx>>1,sy>>1,3);return rp(LEAF,.25+v*.35,sx,sy)}return rp(GRASS,.28+(n-.5)*.4+(hash(sx,sy,9)<.04?.25:0),sx,sy)}}

// ---------- formes et accessoires du tour 2 ----------
const rect=(x0,z0,x1,z1)=>shapeOf([[x0,z0],[x1,z0],[x1,z1],[x0,z1]]);
const plus=(L,a)=>shapeOf([[-a,-L],[a,-L],[a,-a],[L,-a],[L,a],[a,a],[a,L],[-a,L],[-a,a],[-L,a],[-L,-a],[-a,-a]]);
function ringShape(r0,r1){return{ext:r1,inside:(x,z)=>{const r=Math.hypot(x,z);return r>=r0&&r<=r1},normal:(x,z)=>{const r=Math.hypot(x,z)||1;return Math.abs(r-r1)<Math.abs(r-r0)?[x/r,z/r]:[-x/r,-z/r]}}}
const ticksI=(r0,r1,n,c,w=.035,every=0,c2=null)=>q=>{if(q.f!=='top'||q.rad<r0||q.rad>r1)return null;const k=Math.round(q.ang*n/(2*Math.PI));if(Math.abs(q.ang-k*2*Math.PI/n)*q.rad<w)return every&&((k%every)+every)%every===0?c2:c;return null};
const lacingI=(c)=>q=>{if(q.f!=='side'||q.lip||q.foot||q.v<.18||q.v>.82)return null;const u=q.ang*10/Math.PI,f=((u%1)+1)%1,tri=Math.abs(f*2-1);return Math.abs(tri-(q.v-.18)/.64)<.08?c:null};
function shieldStand(x,z,y0=0){return{key:z,draw(L,S){const[a,b]=P3(x,y0,z);if(!y0)S.shadowEll(a+2,b,6,2,.7);L.rect(a,b-20,1,21,WOOD[3]);L.rect(a+1,b-20,1,21,WOOD[1]);const cy=b-14;
 L.ell(a+.5,cy,5.5,5.5,(px,py,dx,dy)=>{const d=dx*dx+dy*dy;if(d>.7)return rp(COPPER,.85-dx*.3-dy*.3,px,py);if(d<.1)return rp(COPPER,.95,px,py);return rp(ORNG,.62-dx*.25-dy*.25,px,py)});return{}}}}
function fireBowl(x,z,y0){return{key:z,draw(L){prism(L,circle(.14),{x,z,y0,y1:y0+.13,mat:stone(COPPER,{noise:.06}),taper:[.65,1]});const[a,b]=P3(x,y0+.13,z-.03);
 return{lights:[{x:a,y:b-3,r:26,i:.7,c:ORANGE,fl:.18}],dyn:flameDyn(Math.round(a),Math.round(b),'orange',.8)}}}}
function bookMat(k){const SP=[SLATE,WOOD,MARBLE,SLATE,WOOD];return q=>{if(q.f==='top'){if(q.rim)return rp(BONE,.55,q.sx,q.sy);return rp(BONE,.75+((q.sx+q.sy)%5===0?-.15:0),q.sx,q.sy)}
 if(Math.abs(q.n[0])>.6)return rp(BONE,q.b+.15-((q.sy&1)?.12:0),q.sx,q.sy);const R=SP[k%SP.length];if(Math.abs(q.v-.5)<.12&&Math.abs(q.x)<.12)return rp(BONE,.7,q.sx,q.sy);return rp(R,q.b+(q.lip?.15:0),q.sx,q.sy)}}

const DSTONE=R_(['#121418','#1a1d23','#23272e','#2d323a','#393f48','#474e58']);
const IRON=R_(['#15181d','#22272e','#323840','#464e58','#5e6772','#7c8692','#9ca5b0']);
const QZ=R_(['#5e5c58','#8a877e','#b4b0a4','#d6d2c6','#eeebe2']);
const LEATHER=R_(['#2a1810','#3e2418','#563422','#6e4630']);
const CYD=ci('#12596b'),CY=E('#5ce8ff'),CYP=E('#c8fbff');
const MOLT=['#7a3008','#c25412','#ec8424','#ffbc58','#ffeec0'].map(E);
const HOT=[1.4,.78,.32],CYL=[.45,1.1,1.3];
const tMat=o=>stone(SLATE,{courses:.2,joint:.6,noise:.1,...o});
const iMat=o=>stone(IRON,{noise:.06,...o});

// ================= DÉFENSES DE L'ATELIER =================
const G=4/3,HG=G/2; // une case, demi-case
configure(24,124,96,62,64);
const PALE=R_(['#6e5a40','#8e7656','#b09670','#cdb48c','#e4d0aa']); // bois écorcé, pointes taillées
const WICK=R_(['#2e2014','#46301c','#5e4428','#7a5a34','#94703f']);

// sol : ardoise de la salle ; les cases de pose sont légèrement plus claires, traits de la grille
function field(cells,o={}){return(x,z,sx,sy)=>{const n=vnoise(x*1.4,z*1.4,7);let b=.42+(n-.5)*.22+(vnoise(x*4,z*4,13)-.5)*.12;
 const u=((x+HG)%G+G)%G,v=((z+HG)%G+G)%G;if(u<1/T||v<1/T)b-=.14;
 const ci_=Math.round(x/G),cj=Math.round(z/G);if(cells.some(([a,c])=>a===ci_&&c===cj)){b+=.08;if(o.pit){const d=Math.max(Math.abs(x-ci_*G),Math.abs(z-cj*G));if(d<o.pit){const k=d/o.pit;return rp(DIRT,.05+k*.45+(hash(sx,sy,3)-.5)*.2,sx,sy)}}}
 return rp(DSTONE,b,sx,sy)}}

// ---------- pièces ----------
// pieu : de (x,y0,z) à (x+lx,y0+h,z+lz), pointe taillée claire
function stake(x,z,y0,h,lx=0,lz=0,o={}){return{key:o.key??z+Math.max(0,lz),draw(L,S){const[a,b]=P3(x,y0,z),[c,d]=P3(x+lx,y0+h,z+lz);if(y0<.05&&!o.noShadow)S.shadowEll(a+2,b,2.5,1.2,.7);
 const n=Math.max(1,Math.ceil(Math.hypot(c-a,d-b))),w=o.w||2,R=o.R||WOOD;for(let k=0;k<=n;k++){const p=k/n,X=Math.round(a+(c-a)*p),Y=Math.round(b+(d-b)*p),tip=k>=n-2;
  if(tip){L.set(X,Y,PALE[k===n?4:3]);if(k<n&&w>1)L.set(X+1,Y,PALE[2]);continue}for(let i=0;i<w;i++)L.set(X+i,Y,R[i===0?Math.min(R.length-1,4):i===w-1?1:3])}return{}}}}
// rondin couché le long de x
function hlog(x0,x1,y,z,r,o={}){return{key:o.key??z+r*.5,draw(L,S){if(y-r<.05)S.shadowShape(rect(x0,z-r,x1,z+r),0,0,r*2,.75);const[a,b]=P3(x0,y,z),[c]=P3(x1,y,z),R=Math.round(r*T*1.25);
 for(let X=Math.round(a);X<=Math.round(c);X++)for(let j=-R;j<=R;j++){const t=j/R;let v=.62-t*.38+(vnoise(X*.3,j*.9,5)-.5)*.25;if(X===Math.round(a)||X===Math.round(c))v=.25;L.set(X,Math.round(b)+j,rp(o.R||BARK,v,X,j))}
 if(o.cap)L.ell(Math.round(c)-1,Math.round(b),2,R,(px,py,dx,dy)=>rp(PALE,.75-Math.hypot(dx,dy)*.5,px,py));return{}}}}
// rondin couché le long de z (vers le spectateur) : face coupée visible devant
function zlog(x,z0,z1,y,r,o={}){return{key:o.key??z1,draw(L,S){if(y-r<.05)S.shadowShape(rect(-r,z0,r,z1),x,0,r*2,.75);const[a,b]=P3(x,y,z0),[,d]=P3(x,y,z1),R=Math.round(r*T);
 for(let Y=Math.round(b);Y<=Math.round(d);Y++)for(let i=-R;i<=R;i++){const t=i/R;L.set(Math.round(a)+i,Y,rp(o.R||BARK,.6-t*.35-Math.abs(t)**3*.2+(vnoise(i*.9,Y*.3,6)-.5)*.25,i,Y))}
 L.ell(Math.round(a),Math.round(d),R+.5,R+.5,(px,py,dx,dy)=>{const k=Math.hypot(dx,dy);return k>.82?BARK[1]:Math.abs(k-.5)<.08?PALE[1]:rp(PALE,.8-k*.4,px,py)});return{}}}}
// galets / pierres sèches
function rock(x,z,r,h,seed=1,o={}){return{key:o.key??z+r*.5,draw(L,S){if(!o.y0)S.shadowShape(poly(6,r),x,z,h,.7);prism(L,poly(6+(seed%3),r,seed),{x,z,y0:o.y0||0,y1:(o.y0||0)+h,mat:stone(o.R||MSTONE,{noise:.2,seed}),taper:[1,.55]});return{}}}}
// matériaux bois
const plankI=(w=.16)=>q=>{if(q.f==='top')return null;const s=Math.abs(q.n[1])>.5?q.x:q.z;return((s+5)%w+w)%w<1/T?WOOD[0]:null};
const bandIr=(...vs)=>q=>q.f==='side'&&vs.some(v=>Math.abs(q.v-v)<.06)?rp(IRON,q.b+.1,q.sx,q.sy):null;
const woodMat=o=>stone(WOOD,{noise:.12,...o});
const weave=q=>{if(q.f==='top')return rp(WICK,.75,q.sx,q.sy);const s=(Math.abs(q.n[1])>.5?q.x:q.z)+q.ang*.0,u=Math.floor((s+5)/.09),row=Math.floor(q.y/.075);if(((u%5)+5)%5===0)return rp(WOOD,q.b+.15,q.sx,q.sy);return rp(WICK,q.b+((u+row)&1?.18:-.08),q.sx,q.sy)};
const weaveC=q=>{if(q.f==='top')return null;const u=Math.floor((q.ang+7)/.32),row=Math.floor(q.y/.075);if(u%3===0)return rp(WOOD,q.b+.12,q.sx,q.sy);return rp(WICK,q.b+((u+row)&1?.18:-.08),q.sx,q.sy)};

// archer (échelle des unités), tourné vers la droite ; tir en boucle toutes les 2 s
function archer(x,z,y=0,o={}){return{actor:true,key:o.key??z,draw(L,S){const[a,b]=P3(x,y,z),A=Math.round(a),B=Math.round(b);if(!y)S.shadowEll(A+2,B,5,2,.7);
 const CL=R_(['#22262e','#323844','#454d5c','#5a6476']),SK=ci('#c49a74');
 L.rect(A-2,B-6,2,6,CL[1]);L.rect(A+1,B-6,2,6,CL[0]);L.rect(A-3,B-14,7,8,i=>rp(LEATHER,.75-(i-A)*.08,i,0));L.rect(A-3,B-8,7,1,CL[0]);
 L.ell(A+.5,B-17,2.6,2.8,(px,py,dx,dy)=>dy<-.2?CL[1]:SK);L.set(A+2,B-17,CL[0]);L.rect(A-4,B-13,2,6,LEATHER[1]);L.set(A-4,B-14,PALE[3]);L.set(A-3,B-15,PALE[3]);
 L.rect(A+4,B-12,3,2,SK);for(let j=-6;j<=6;j++)L.set(A+6+Math.round(1.6*(1-(j/6)**2)),B-11+j,WOOD[4]);L.line(A+6,B-17,A+6,B-5,BONE[2]);
 return{dyn:o.shoot===false?null:(F,t)=>{const p=(t%2)/.6;if(p>1){if(t%2>1.2)F.set(A+5,B-11,PALE[3]);return}const X=A+8+Math.round(p*70),Y=B-11-Math.round(p*10-p*p*4);F.set(X,Y,PALE[4]);F.set(X-1,Y,PALE[2]);F.set(X-2,Y,WOOD[3]);F.set(X-3,Y,BONE[3])}}}}}
// torche (objet de l'Atelier) plantée
function torch(x,z,y0=0){return{key:z,draw(L,S){const[a,b]=P3(x,y0,z),[,c]=P3(x,y0+.62,z);L.rect(Math.round(a),Math.round(c),2,Math.round(b-c),i=>i===Math.round(a)?WOOD[4]:WOOD[2]);L.rect(Math.round(a)-1,Math.round(c)-1,4,2,BARK[1]);
 return{lights:[{x:a+1,y:c-4,r:52,i:.95,c:[1.3,.66,.26],fl:.2}],dyn:flameDyn(Math.round(a)+1,Math.round(c)-2,'orange',.9)}}}}
// chausse-trappe à quatre pointes (tétrapode de bois)
function tetra(x,z,s){return{key:z,draw(L,S){const[a,b]=P3(x,0,z),A=Math.round(a),B=Math.round(b),k=hash(s,1,9)>.5;
 const arms=k?[[-3,1],[3,1],[0,-1]]:[[-3,-1],[3,0],[1,2]];for(const[dx,dy]of arms){L.line(A,B,A+dx,B+dy,WOOD[3]);L.set(A+dx,B+dy,PALE[3])}L.line(A,B,A,B-4,WOOD[4]);L.set(A,B-4,PALE[4]);L.set(A,B-3,PALE[2]);return{}}}}
// balise cyan : repère des Exilés pour ne pas marcher dessus
function beacon(x,z){return{key:z,draw(L,S){const[a,b]=P3(x,0,z),A=Math.round(a),B=Math.round(b);L.rect(A,B-12,1,12,WOOD[4]);L.rect(A+1,B-12,1,12,WOOD[1]);L.rect(A+2,B-12,4,3,CY);L.set(A+5,B-10,CYD);return{lights:[{x:A+3,y:B-11,r:16,i:.35,c:CYL}]}}}}

// ---------- propositions ----------
const at=(i,j)=>[i*G,j*G];
const ITEMS=[
 // ===== POSTE DE TIR =====
 {group:'post',name:'Mantelet à meurtrière',desc:'Un panneau de planches cerclé de fer, à hauteur de poitrine, calé par deux étais. L’archer tire par-dessus : la vue n’est pas coupée. Le plus simple et le plus lisible.',
  build(){const objs=[archer(-.05,-.32),
   slab(rect(-.56,-.05,.56,.05),0,.58,woodMat({inlay:anyI(plankI(.14),bandIr(.22,.78))}),{z:.28}),
   stake(-.42,.28,.0,.5,0,-.42,{key:-.1}),stake(.42,.28,0,.5,0,-.42,{key:-.1}),
   slab(rect(-.12,-.12,.12,.12),0,.16,woodMat(),{x:.45,z:-.45})];return{ground:field([[0,0]]),objs}}},
 {group:'post',name:'Estrade d’affût',desc:'Une petite estrade de planches sur quatre poteaux, garde-corps bas et montants d’échelle devant, torche au coin. L’archer surélevé : on comprend d’un coup d’œil pourquoi sa portée double.',
  build(){const h=.34,objs=[];for(const[x,z]of[[-.5,-.5],[.5,-.5]])objs.push(slab(square(.06),0,h,woodMat(),{x,z}));
   objs.push(slab(rect(-.6,-.6,.6,.6),h,h+.1,woodMat({inlay:q=>q.f==='top'&&((q.x+5)%.2+.2)%.2<1/T?WOOD[1]:plankI(.2)(q)}),{key:.1}));
   for(const[x,z]of[[-.5,.5],[.5,.5]])objs.push(slab(square(.06),0,h,woodMat(),{x,z,key:.6}));
   objs.push(archer(0,-.15,h+.1,{key:.2}),hlog(-.58,.58,h+.3,.52,.04,{key:.65,R:WOOD}),stake(-.55,.52,h+.1,.26,0,0,{key:.66,noShadow:1}),stake(.53,.52,h+.1,.26,0,0,{key:.66,noShadow:1}),stake(-.2,.62,0,h+.1,0,0,{key:.7,noShadow:1,w:1}),stake(.2,.62,0,h+.1,0,0,{key:.7,noShadow:1,w:1}),torch(.62,.62,0));
   return{ground:field([[0,0]]),objs}}},
 {group:'post',name:'Créneau de rondins',desc:'Trois rondins empilés en U, ouverts vers l’arrière, la face coupée des bois tournée vers la salle. Rustique, solide, se lit comme un abri de tir.',
  build(){const objs=[archer(0,-.2),zlog(-.5,-.55,.55,.1,.1,{key:.4}),zlog(-.5,-.5,.5,.3,.09,{key:.41}),zlog(.5,-.55,.55,.1,.1,{key:.4}),zlog(.5,-.5,.5,.3,.09,{key:.41}),
   hlog(-.58,.58,.1,.48,.1,{key:.6}),hlog(-.58,.58,.3,.48,.09,{key:.61}),hlog(-.5,.5,.48,.46,.08,{key:.62})];return{ground:field([[0,0]]),objs}}},
 {group:'post',name:'Claie tressée',desc:'Une claie d’osier courbe tenue par des piquets, un carquois planté à côté. Léger, végétal, laisse voir à travers les jours de la tresse.',
  build(){const arc=shapeOf(Array.from({length:12},(_,i)=>{const a=Math.PI*(.15+.7*i/11);return[Math.cos(a)*.62,Math.sin(a)*.62-.32]}).concat(Array.from({length:12},(_,i)=>{const a=Math.PI*(.85-.7*i/11);return[Math.cos(a)*.52,Math.sin(a)*.52-.32]})));
   const objs=[archer(0,-.28),slab(arc,0,.55,weaveC,{key:.3}),
    {key:-.4,draw(L,S){const[a,b]=P3(-.5,0,-.45),A=Math.round(a),B=Math.round(b);L.rect(A-1,B-9,4,9,LEATHER[2]);L.rect(A-1,B-9,4,1,LEATHER[3]);for(let k=0;k<3;k++){L.set(A+k,B-11,PALE[3]);L.set(A+k,B-10,WOOD[3])}return{}}}];
   return{ground:field([[0,0]]),objs}}},
 // ===== BARRICADE =====
 {group:'barr',name:'Cheval de frise',desc:'Une poutre traversée de pieux croisés, pointes vers l’ennemi. Basse et ajourée : elle barre le passage sans cacher la vue. Trois segments posés côte à côte se raccordent.',
  build(){const objs=[];for(const i of[-1,0,1]){const x0=i*G;objs.push(hlog(x0-HG+.04,x0+HG-.04,.28,0,.08,{key:.05,R:BARK}));
   for(const dx of[-.3,.08]){objs.push(stake(x0+dx-.15,-.04,0,.6,.42,.08,{key:-.1}));objs.push(stake(x0+dx+.27,.04,0,.6,-.42,-.08,{key:.1}))}}
   return{ground:field([[-1,0],[0,0],[1,0]]),objs}}},
 {group:'barr',name:'Muret hérissé',desc:'Un muret de pierres sèches (la roche) couronné de pieux taillés penchés vers l’ennemi (le bois). Les deux matières de la recette se lisent.',
  build(o={}){const objs=[];for(const i of(o.one?[0]:[-1,0,1])){const x0=i*G;objs.push(slab(rect(-HG+.02,-.2,HG-.02,.2),0,.34,stone(MSTONE,{courses:.11,joint:.26,noise:.2,seed:i+4}),{x:x0}));
   for(const dx of[-.45,-.15,.15,.45])objs.push(stake(x0+dx,0,.34,.36,.08,-.06,{key:.4,noShadow:1}))}
   return{ground:field([[-1,0],[0,0],[1,0]]),objs}}},
 {group:'barr',name:'Gabions d’osier',desc:'Des paniers d’osier tressé remplis de roche, deux par case, liés par une perche. Une forteresse de bricolage, typique d’Exilés qui font avec la caverne.',
  build(){const objs=[];for(const i of[-1,0,1])for(const dx of[-.3,.3]){const x=i*G+dx;objs.push(slab(circle(.27),0,.5,weaveC,{x,z:0}));
    for(let k=0;k<3;k++)objs.push(rock(x+(hash(i*7+k,dx*10|0,2)-.5)*.25,(hash(k,i,4)-.5)*.2,.09,.08,k+3,{y0:.5,key:.3}))}
   objs.push(hlog(-G-HG+.1,G+HG-.1,.42,.25,.03,{key:.5,R:WOOD}));return{ground:field([[-1,0],[0,0],[1,0]]),objs}}},
 {group:'barr',name:'Palissade de pieux',desc:'Des pieux plantés serrés dans un bourrelet de pierres, tous penchés vers l’ennemi, avec un jour entre chacun. Agressive, se lit comme « on ne passe pas ».',
  build(){const objs=[];for(const i of[-1,0,1]){const x0=i*G;for(let k=0;k<5;k++)objs.push(rock(x0-.48+k*.24,(hash(k,i,7)-.5)*.16,.14,.14,k+i*5+2,{key:.12}));
   for(let k=0;k<6;k++){const dx=-.52+k*.21;objs.push(stake(x0+dx,0,.05,.6+hash(k,i,3)*.2,.1+(hash(k,i,8)-.5)*.06,-.04,{key:.2,noShadow:1}))}}
   return{ground:field([[-1,0],[0,0],[1,0]]),objs}}},
 // ===== CHAUSSE-TRAPPE =====
 {group:'trap',name:'Lit de pieux',desc:'Des dizaines de pieux courts plantés de biais sur toute la case. Lisible de loin comme une zone hérissée ; aucune pièce de métal.',
  build(){const objs=[];for(let j=0;j<5;j++)for(let i=0;i<5;i++){const x=-.52+i*.26+(hash(i,j,1)-.5)*.1,z=-.52+j*.26+(hash(i,j,2)-.5)*.1;objs.push(stake(x,z,0,.16+hash(i,j,3)*.08,(hash(i,j,4)-.5)*.1,.06,{noShadow:1}))}
   return{ground:field([[0,0]]),objs}}},
 {group:'trap',name:'Fosse à pieux',desc:'La case est creusée : une fosse de terre où pointent des pieux, bordée de quelques planches. Le sol change de couleur, le piège se repère sans gêner.',
  build(){const objs=[];for(let j=0;j<4;j++)for(let i=0;i<4;i++){const x=-.36+i*.24+(hash(i,j,5)-.5)*.08,z=-.36+j*.24+(hash(i,j,6)-.5)*.08;objs.push(stake(x,z,-.05,.18,(hash(i,j,7)-.5)*.08,0,{noShadow:1}))}
   objs.push(slab(rect(-.6,-.07,.6,.07),0,.05,woodMat({inlay:plankI(.3)}),{z:-.56}),slab(rect(-.07,-.5,.07,.5),0,.05,woodMat(),{x:.58}));
   return{ground:field([[0,0]],{pit:.5}),objs}}},
 {group:'trap',name:'Planches hérissées',desc:'Trois planches posées à plat, garnies de rangées de dents de bois taillées. Ordonné et fabriqué : c’est un objet de l’Atelier, pas un accident de terrain.',
  build(){const objs=[];for(const z of[-.4,0,.4]){objs.push(slab(rect(-.58,-.15,.58,.15),0,.06,woodMat({inlay:plankI(.58)}),{z}));for(let k=0;k<5;k++)for(const dz of[-.07,.07])objs.push(stake(-.46+k*.23+(dz>0?.1:0),z+dz,.06,.13,0,0,{noShadow:1,w:1,key:z+dz+.05}))}
   return{ground:field([[0,0]]),objs}}},
 {group:'trap',name:'Chausse-trappes et balise',desc:'Des tétrapodes de bois semés au sol (une pointe toujours en l’air), et une petite balise cyan au coin pour que les Exilés l’évitent. Discret de jour, la balise luit la nuit.',
  build(){const objs=[];for(let k=0;k<16;k++){const x=(hash(k,1,11)-.5)*1.15,z=(hash(k,2,11)-.5)*1.15;objs.push(tetra(x,z,k))}objs.push(beacon(-.6,-.6));
   return{ground:field([[0,0]]),objs}}},
];
const GROUPS=[{id:'post',name:'Poste de tir',note:'1 case · 10 bois · double la portée de l’unité de tir postée derrière · ne bloque pas les lignes de vue'},
 {id:'barr',name:'Barricade',note:'1 case par segment (ici trois segments raccordés) · 10 bois + 10 roche · force les ennemis à faire le tour · ne bloque pas les lignes de vue'},
 {id:'trap',name:'Chausse-trappe',note:'1 case · 25 bois · 25 dégâts par seconde à chaque ennemi qui marche dessus'}];
// ---------- export vers le jeu ----------
// Objet posé seul (sans archer, un seul segment), sol transparent : sprite 320 × 240, ancre (160, 168) au centre de la case,
// échelle native (scale 1 : une case = 32 px), une image ; portrait 128 × 128 pour l'inventaire et le HUD.
const PICKS={firing_post:2,barricade:5,caltrops:10};
function exportSprite(id){configure(24,320,240,160,168);let S;try{const b=ITEMS[PICKS[id]].build({one:1});S=new Scene();S.bake(()=>-1,b.objs.filter(o=>!o.actor))}finally{configure(24,124,96,62,64)}
 const base=document.createElement('canvas');base.width=320;base.height=240;const g=base.getContext('2d'),img=g.createImageData(320,240),D=img.data;let top=240,bot=0;
 for(let k=0;k<320*240;k++){const v=S.P.c[k],o=k*4;if(v>=0){D[o]=v>>16&255;D[o+1]=v>>8&255;D[o+2]=v&255;D[o+3]=255;const y=(k/320)|0;if(y<top)top=y;if(y>bot)bot=y}else if(S.sh[k]>0)D[o+3]=Math.round(S.sh[k]*95)}
 g.putImageData(img,0,0);
 let x0=320,x1=0,y0=240,y1=0;for(let y=0;y<240;y++)for(let x=0;x<320;x++)if(D[(y*320+x)*4+3]===255){if(x<x0)x0=x;if(x>x1)x1=x;if(y<y0)y0=y;if(y>y1)y1=y}
 const por=document.createElement('canvas');por.width=por.height=128;const pg=por.getContext('2d'),w=x1-x0+1,h=y1-y0+1,k=Math.max(1,Math.floor(Math.min(3,112/w,112/h)));pg.imageSmoothingEnabled=false;
 pg.drawImage(base,x0,y0,w,h,Math.round(64-w*k/2),Math.round(64-h*k/2),w*k,h*k);
 return{base,portrait:por,pick:ITEMS[PICKS[id]].name,meta:{anchor:[160,168],top,bottom:bot,scale:1,anim:{frame_w:320,frame_h:240,cols:1,rows:1,count:1,seconds:1/12,fps:12,exact:true,seam_pixels:0}}}}
function vignette(i){const b=ITEMS[i].build(),S=new Scene();S.bake(b.ground,b.objs);if(b.fx)S.dyn.push(...b.fx(S));return S}
return{ITEMS,GROUPS,PICKS,vignette,exportSprite,ambient,get W(){return W},get H(){return H}}})();
