'use strict';
// Planche « Bâtiments secondaires v2 » (moteur copié de creuset-planches.js) : 5 propositions de bâtiment 2 × 2 cases.
// Moteur repris de autels-planches.js (vue 3/4 du jeu, extrusions, jour/nuit) ; 1 case = 4 unités = 2,67 unités de dessin.
const BAT=(()=>{
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

// ================= CREUSET DES EXILÉS =================
// Emprise : 2 × 2 cases, soit un carré de demi-côté C (1 case = 4 unités de jeu ; le disque de rayon 2 des autels couvre 3 cases).
const C=4/3;
configure(24,132,136,66,102);
const DSTONE=R_(['#121418','#1a1d23','#23272e','#2d323a','#393f48','#474e58']);
const IRON=R_(['#15181d','#22272e','#323840','#464e58','#5e6772','#7c8692','#9ca5b0']);
const QZ=R_(['#5e5c58','#8a877e','#b4b0a4','#d6d2c6','#eeebe2']);
const LEATHER=R_(['#2a1810','#3e2418','#563422','#6e4630']);
const CYD=ci('#12596b'),CY=E('#5ce8ff'),CYP=E('#c8fbff');
const MOLT=['#7a3008','#c25412','#ec8424','#ffbc58','#ffeec0'].map(E);
const HOT=[1.4,.78,.32],CYL=[.45,1.1,1.3];
const tMat=o=>stone(SLATE,{courses:.2,joint:.6,noise:.1,...o});
const iMat=o=>stone(IRON,{noise:.06,...o});
const moltenTop=r=>q=>q.f==='top'&&q.rad<r?rp(MOLT,.45+.45*(1-q.rad/r)+(hash(q.sx,q.sy,4)-.5)*.25,q.sx,q.sy):null;
const glyphs=(v0,v1,seed=7)=>bandI(v0,v1,CY,.15,seed);
const cyLine=(v)=>q=>q.f==='side'&&!q.lip&&Math.abs(q.v-v)<.04?CY:null;

// sol : ardoise de la salle, emprise dallée et limites des 2 × 2 cases
function floor(){return(x,z,sx,sy)=>{const n=vnoise(x*1.4,z*1.4,7);
 if(Math.abs(x)<=C&&Math.abs(z)<=C){const g=C/3,u=((x%g)+g)%g,v=((z+(Math.floor(x/g)&1)*g/2)%g+g)%g;let b=.5+(vnoise(x*5,z*5,3)-.5)*.3;if(u<1/T||v<1/T)b-=.25;
  if(Math.abs(x)<1/T||Math.abs(z)<1/T||Math.abs(Math.abs(x)-C)<1/T||Math.abs(Math.abs(z)-C)<1/T)b-=.32;return rp(SLATE,b,sx,sy)}
 const b=.42+(n-.5)*.22+(vnoise(x*4,z*4,13)-.5)*.12-Math.max(0,Math.max(Math.abs(x),Math.abs(z))-C)*.12;return rp(DSTONE,b,sx,sy)}}

// ---------- effets ----------
function sparkDyn(cx,cy,n=10,seed=1,up=14,spread=9){return(F,t)=>{for(let k=0;k<n;k++){const per=6/Math.round(6/(.9+hash(k,3,seed)*.7)),p=((t+hash(k,1,seed)*per)%per)/per,vx=(hash(k,2,seed)-.5)*spread*2,vy=up*(.6+hash(k,4,seed)*.6);
 const x=Math.round(cx+vx*p),y=Math.round(cy-vy*p+vy*1.4*p*p);if(p<.85)F.set(x,y,MOLT[p<.25?4:p<.55?3:2])}}}
function smokeDyn(cx,cy,h=34,n=9,seed=3){const G=R_(['#3a3e46','#4a4f58','#5c626c']);return(F,t)=>{for(let k=0;k<n;k++){const p=((t*.28+hash(k,1,seed))%1),x=Math.round(cx+Math.sin(t*.9+k*1.7)*2+p*6),y=Math.round(cy-p*h),r=p<.3?0:1;
 if(p>.9)continue;for(let j=-r;j<=r;j++)for(let i=-r;i<=r;i++)if(Math.abs(i)+Math.abs(j)<=r&&hash(k,i*3+j,seed+Math.floor(t*2))>.25)F.set(x+i,y+j,G[p<.4?2:p<.7?1:0])}}}
function bubbleDyn(cx,cy,rx,ry,n=4,seed=5){return(F,t)=>{const f=Math.floor(t*6);for(let k=0;k<n;k++){const a=hash(k,f,seed)*6.283,r=Math.sqrt(hash(k,f+7,seed)),x=Math.round(cx+Math.cos(a)*r*rx),y=Math.round(cy+Math.sin(a)*r*ry);F.set(x,y,MOLT[4]);if(hash(k,f,seed+1)>.6)F.set(x+1,y,MOLT[3])}}}
// coulée : filet de métal du bec (a) vers le moule (b), sur 2,6 s d'une boucle de 6 s
function pourDyn(ax,ay,bx,by,period=6,on=[1.2,3.8]){return(F,t)=>{const u=t%period;if(u<on[0]||u>on[1])return;const grow=Math.min(1,(u-on[0])/.35),end=Math.min(1,(on[1]-u)/.35),n=Math.ceil(Math.hypot(bx-ax,by-ay));
 for(let k=0;k<=n;k++){const p=k/n;if(p>grow||p<1-end)continue;const x=Math.round(ax+(bx-ax)*p+Math.sin(t*Math.PI*6+k*.7)*.4),y=Math.round(ay+(by-ay)*p);F.set(x,y,MOLT[(k+Math.floor(t*14))%3===0?4:3]);if(p>.2)F.set(x+1,y,MOLT[2])}
 if(grow>=1)for(let k=0;k<4;k++){const p=((t*3+k/4)%1);F.set(Math.round(bx+(k-1.5)*2*p),Math.round(by-3*p+4*p*p),MOLT[3])}}}
function scanDyn(cx,cy,w,h){return(F,t)=>{const p=(Math.sin(t*1.6)*.5+.5),y=Math.round(cy-h*p);for(let x=-w;x<=w;x++)if((x+Math.floor(t*8))%3)F.set(cx+x,y,x%2?CY:CYP)}}

// ---------- pièces ----------
function crucible(x,z,y0,r,h,o={}){return{key:o.key??z,draw(L,S){if(!y0)S.shadowShape(circle(r),x,z,h,.8);
 prism(L,circle(r),{x,z,y0,y1:y0+h,mat:iMat({inlay:anyI(moltenTop(r*.74),o.glyph?cyLine(.55):()=>null),trim:{R:IRON,v0:.82,v1:1}}),taper:[.72,1]});
 const[a,b]=P3(x,y0+h,z);return{lights:[{x:a,y:b-2,r:o.lr||44,i:.95,c:HOT,fl:.15}],dyn:bubbleDyn(Math.round(a),Math.round(b),r*T*.62,r*T*.5)}}}}
function anvil(x,z){return{key:z,draw(L,S){S.shadowShape(square(.16),x,z,.4,.7);prism(L,square(.16),{x,z,y0:0,y1:.08,mat:iMat()});prism(L,square(.1),{x,z,y0:.08,y1:.26,mat:iMat()});
 prism(L,rect(-.3,-.11,.26,.11),{x,z,y0:.26,y1:.38,mat:iMat({trim:{R:IRON,v0:.7,v1:1}})});prism(L,tri(.11),{x:x+.33,z,y0:.3,y1:.38,mat:iMat()});return{}}}}
function rack(x,z,n=3,o={}){return{key:z,draw(L,S){const[a,b]=P3(x,0,z);S.shadowEll(a+4,b+1,12,3,.7);const w=n*6+4;L.rect(a-w/2,b-22,2,23,WOOD[3]);L.rect(a+w/2-2,b-22,2,23,WOOD[2]);L.rect(a-w/2,b-20,w,2,WOOD[4]);L.rect(a-w/2,b-6,w,2,WOOD[2]);
 for(let k=0;k<n;k++){const sx=Math.round(a-w/2+5+k*6),two=o.two&&k===1;L.rect(sx,b-(two?27:22),1,two?22:18,SILVER[3]);L.rect(sx+1,b-(two?27:22),1,two?22:18,SILVER[1]);L.set(sx,b-(two?28:23),SILVER[4]);L.rect(sx-2,b-8,5,1,IRON[4]);L.rect(sx,b-7,2,3,LEATHER[2])}
 return{}}}}
function shieldOn(x,z,y,col){return{key:z+.01,draw(L){const[a,b]=P3(x,y,z);L.ell(a,b,4.5,5,(px,py,dx,dy)=>{const d=dx*dx+dy*dy;if(d>.68)return rp(IRON,.8-dx*.3-dy*.3,px,py);if(d<.08)return CY;return rp(col,.6-dx*.25-dy*.25,px,py)});return{}}}}
// armure posée sur un mannequin d'exosquelette (silhouette tyrienne, lueur cyan)
function mannequin(x,z,o={}){return{key:z,statue:true,draw(L,S){const[a,b]=P3(x,0,z);S.shadowEll(a+5,b+1,8,3,.75);const A=Math.round(a),B=Math.round(b);
 L.rect(A-1,B-14,3,14,IRON[2]);L.rect(A-5,B-1,11,2,IRON[3]);
 const M=o.mat||IRON;for(let y=0;y<13;y++){const w=y<3?6:y<9?5:4;for(let i=-w;i<=w;i++)L.set(A+i,B-27+y,rp(M,.62-i*.05-y*.02+(i===-w?.2:0),A+i,y))}
 L.rect(A-7,B-27,2,8,rp(M,.7,0,0));L.rect(A+6,B-27,2,8,rp(M,.45,0,0));L.ell(A+.5,B-31,3,3.2,(px,py,dx,dy)=>rp(IRON,.6-dx*.3-dy*.2,px,py));L.rect(A-1,B-31,3,1,CY);
 L.rect(A,B-24,1,6,CY);L.set(A-3,B-22,CY);L.set(A+3,B-22,CY);return{lights:[{x:A,y:B-24,r:22,i:.45,c:CYL}]}}}}
function moldTray(x,z,y0=0,o={}){return{key:o.key??z,draw(L,S){if(!y0)S.shadowShape(rect(-.5,-.22,.5,.22),x,z,.14,.7);
 prism(L,rect(-.5,-.22,.5,.22),{x,z,y0,y1:y0+.14,mat:tMat({courses:0,inlay:linesI(o.segs||[[[-.38,-.07],[.3,-.07]],[[-.38,.08],[.3,.08]]],.035,MOLT[3])})});return{}}}}
function chimney(x,z,h,w,o={}){return{key:z,draw(L,S){S.shadowShape(square(w),x,z,h,.75);prism(L,square(w),{x,z,y0:0,y1:h,mat:tMat({inlay:anyI(glyphs(.5,.62,o.seed||9),cyLine(.82))}),taper:[1.15,.9]});
 const[a,b]=P3(x,h,z);L.ell(a,b,w*T*.75,w*T*.45,IRON[0]);return{dyn:smokeDyn(Math.round(a),Math.round(b)-1)}}}}
function crystal(x,z,h,o={}){return{key:z,draw(L,S){S.shadowShape(poly(6,.1),x,z,h,.6);prism(L,poly(6,.11,.3),{x,z,y0:o.y0||0,y1:(o.y0||0)+h,mat:stone(QZ,{noise:.08,inlay:vlineI(CYP,.025,.25,.85)})});
 prism(L,poly(6,.11,.3),{x,z,y0:(o.y0||0)+h,y1:(o.y0||0)+h+.18,mat:stone(QZ,{noise:.04}),taper:[1,0]});const[a,b]=P3(x,(o.y0||0)+h+.1,z);return{lights:[{x:a,y:b,r:20,i:.5,c:CYL}]}}}}
function bellows(x,z){return{key:z,draw(L,S){const[a,b]=P3(x,0,z);S.shadowEll(a+3,b,9,3,.7);prism(L,rect(-.32,-.13,.22,.13),{x,z,y0:0,y1:.2,mat:stone(WOOD,{noise:.08})});
 return{dyn:(F,t)=>{const k=Math.round((Math.sin(t*2.4)*.5+.5)*3),[c,d]=P3(x-.05,.2,z);for(let j=0;j<3+k;j++)for(let i=-5+j%2;i<=4;i++)F.set(Math.round(c)+i,Math.round(d)-j,rp(LEATHER,.5+(j===2+k?.3:0)-i*.02,i,j));F.set(Math.round(c)+7,Math.round(d)-1,IRON[4])}}}}}

// ================= BÂTIMENTS SECONDAIRES v2 : Bibliothèque, Atelier, Forge, Entrepôt =================
// Assemblé avec le moteur de creuset-planches.js par tools/batiments-v2/build.py (voir batiments-v2-planches.js).
const AEC=['#34327a','#5a5cff','#9aa0ff','#e0e4ff'].map(E);
const WHC=['#8e8c94','#c8ccd8','#eef0f6','#ffffff'].map(E);
const BLUEC=R_(['#16244e','#20387c','#3054aa','#5a80d4','#9ab4ee']);
const REDC=R_(['#3e1010','#6a1a1a','#962828','#c44444','#e88080']);
const PARCH=R_(['#6e6250','#968a70','#bcb092','#ddd3b6','#f0e9d4']);
const PLASTER=R_(['#4e4a44','#6a645a','#868072','#a29a8a','#bab2a0']);
const VERDI=R_(['#17302c','#23463d','#305e4e','#427863','#5c937a']);
const CANVAS=R_(['#4a4234','#6a604a','#8a7e62','#a89c7c','#c4b896']);
const EARTH=R_(['#2a2018','#3a2c1e','#4c3a26','#5e4a30']);
const SPINE=R_(['#2e3a4c','#3e4c38','#5a4230','#4c3a3e','#6c6656','#3c4450','#5e5444']);
const WINW=E('#d6dae6'),WINV=E('#8c90f0');
const TERRE=R_(['#2c261e','#3a3228','#4a4032','#5a4e3c','#6a5c46']);

// ---------- heightfield : toits à pans, dômes, voûtes, cylindres couchés ----------
// o: {x,z,hw,hd,y0,ym,hf(lx,lz)->y|null,mat,th}
function hprism(L,o){const cx=o.x||0,cz=o.z||0,lo=o.y0-(o.th??.06),ym=o.ym,hf=o.hf,m=o.mat,st=.5/T,ep=.025;
 const sx0=Math.floor(OX+(cx-o.hw)*T)-1,sx1=Math.ceil(OX+(cx+o.hw)*T)+1,sy0=Math.floor(OY+(cz-o.hd-ym)*T)-1,sy1=Math.ceil(OY+(cz+o.hd-lo)*T)+1;
 const H=(lx,lz)=>Math.abs(lx)>o.hw||Math.abs(lz)>o.hd?null:hf(lx,lz);
 for(let sy=sy0;sy<=sy1;sy++)for(let sx=sx0;sx<=sx1;sx++){const lx=(sx+.5-OX)/T-cx;if(Math.abs(lx)>o.hw)continue;const s=(sy+.5-OY)/T-cz;let front=false,py=null;
  for(let y=ym;y>=lo-1e-6;y-=st){const lz=s+y;if(lz>o.hd){front=true;py=y;continue}if(lz<-o.hd)break;const h=H(lx,lz);
   if(h==null||h<y){front=false;py=y;continue}
   if(front&&h-y>.9/T){L.set(sx,sy,m({f:'side',x:lx,z:lz,y,v:(y-lo)/(ym-lo),b:.66,lip:h-y<1.6/T,foot:y<lo+1.2/T,n:[0,1],sx,sy,rad:Math.hypot(lx,lz),ang:Math.atan2(lz,lx)}));break}
   let hy=y;if(py!=null){let A=py,B=y;for(let k=0;k<7;k++){const mid=(A+B)/2,hm=H(lx,s+mid);if(hm!=null&&hm>=mid)B=mid;else A=mid}hy=B}
   const hz=s+hy,hh=H(lx,hz)??h,g=(dx,dz)=>{const p=H(lx+dx,hz+dz),q=H(lx-dx,hz-dz);return p==null||q==null?0:(p-q)/(2*(dx+dz))},gx=g(ep,0),gz=g(0,ep);
   if(Math.abs(gz)>9||Math.abs(gx)>9){L.set(sx,sy,m({f:'side',x:lx,z:hz,y:hy,v:(hy-lo)/(ym-lo),b:.66,lip:false,foot:false,n:[0,1],sx,sy,rad:Math.hypot(lx,hz),ang:Math.atan2(hz,lx)}));break}
   const nl=Math.hypot(gx,1,gz),d=(.5*gx+.75-.45*gz)/nl/1.007;
   L.set(sx,sy,m({f:'top',x:lx,z:hz,y:hh,gx,gz,b:.3+.62*Math.max(0,d),rim:false,eave:hh<o.y0+.04,ridge:hh>ym-.05,sx,sy,rad:Math.hypot(lx,hz),ang:Math.atan2(hz,lx)}));break}}}
const RF={
 gx:(hw,hd,y0,h)=>(lx,lz)=>y0+h*(1-Math.abs(lz)/hd),          // faîtage parallèle à x
 gz:(hw,hd,y0,h)=>(lx,lz)=>y0+h*(1-Math.abs(lx)/hw),          // faîtage parallèle à z (pignon en façade)
 hip:(hw,hd,y0,h)=>(lx,lz)=>y0+h*Math.min(hw-Math.abs(lx),hd-Math.abs(lz))/Math.min(hw,hd),
 pyr:(hw,hd,y0,h)=>(lx,lz)=>y0+h*Math.min(1-Math.abs(lx)/hw,1-Math.abs(lz)/hd),
 cone:(hw,hd,y0,h)=>(lx,lz)=>{const r=Math.hypot(lx/hw,lz/hd);return r>1?null:y0+h*(1-r)},
 dome:(hw,hd,y0,h)=>(lx,lz)=>{const r=Math.hypot(lx/hw,lz/hd);return r>1?null:y0+h*Math.sqrt(1-r*r)},
 bell:(hw,hd,y0,h)=>(lx,lz)=>{const r=Math.hypot(lx/hw,lz/hd);return r>1?null:y0+h*(1-r*r*r)},
 shed:(hw,hd,y0,h)=>(lx,lz)=>y0+h*(hd-lz)/(2*hd),             // monte vers le fond
 vault:(hw,hd,y0,h)=>(lx,lz)=>y0+h*Math.sqrt(Math.max(0,1-(lz/hd)**2)),
 logz:(hw,hd,y0)=>(lx,lz)=>{const r=hw;return Math.abs(lx)>r?null:y0+r+Math.sqrt(r*r-lx*lx)},
};
function roof(kind,x,z,hw,hd,y0,h,mat,o={}){return{key:o.key??z+hd,draw(L,S){if(o.shadow!==false&&!o.noShadow)S.shadowShape(rect(-hw,-hd,hw,hd),x,z,y0+h,o.shadow??.55);
 hprism(L,{x,z,hw,hd,y0,ym:y0+h+.02,hf:o.hf||RF[kind](hw,hd,y0,h,o.r),mat,th:o.th});return{lights:projL(o.lights)}}}}
// tuiles / bardeaux : rangs horizontaux (même hauteur), joints décalés
function shingle(R,o={}){const cw=o.cw??.15,jw=o.jw??.2,ax=o.axis||'x';return q=>{if(o.inlay){const c=o.inlay(q);if(c!=null)return c}
 if(q.f==='side')return o.side?o.side(q):rp(R,.5+(q.foot?-.2:.1),q.sx,q.sy);
 let b=q.b+(q.eave?.14:0)+(q.ridge?.12:0);const r=q.y/cw,row=Math.floor(r),f=r-row;if(f<.24)b-=.2;
 const w=ax==='x'?q.x:ax==='z'?q.z:q.ang*1.1,u=w/jw+(row&1)*.5;if(((u%1)+1)%1<.9/(T*jw))b-=.14;
 b+=(hash(Math.floor(u),row,o.seed||5)-.5)*.12;
 if(o.moss&&vnoise(q.x*2.5,q.z*2.5+q.y,61)>1-o.moss)return rp(MOSS,b*.85,q.sx,q.sy);return rp(R,b,q.sx,q.sy)}}
// bois : planches, poutres
function woodMat(R=WOOD,o={}){const w=o.w??.17;return q=>{if(o.inlay){const c=o.inlay(q);if(c!=null)return c}let b=q.f==='top'?.8+(q.rim?.1:0):q.b+(q.lip?.12:0)-(q.foot?.15:0);
 const u=q.f==='top'?(o.along==='z'?q.x:q.z):(o.horiz?q.y:q.x),f=((u/w)%1+1)%1;if(f<1/(T*w))b-=.24;
 b+=(hash(Math.floor(u/w),3,o.seed||2)-.5)*.16+(vnoise(q.x*11,q.y*4+q.z*11,5)-.5)*.1;return rp(R,b,q.sx,q.sy)}}
const frontI=fn=>q=>q.f==='side'&&q.n[1]>.5?fn(q):null;
// ouvertures en façade (coordonnées locales x, hauteur absolue y)
const archI=(cx,w,y0,y1,fill)=>frontI(q=>{const dx=q.x-cx;if(Math.abs(dx)>w||q.y<y0)return null;const top=y1-w+Math.sqrt(Math.max(0,w*w-dx*dx));if(q.y>top)return null;
 if(q.y>top-1.1/T||Math.abs(dx)>w-1.1/T)return rp(MARBLE,.9,q.sx,q.sy);return typeof fill==='function'?fill(q,dx):fill});
const rectI=(cx,w,y0,y1,fill)=>frontI(q=>{const dx=q.x-cx;if(Math.abs(dx)>w||q.y<y0||q.y>y1)return null;return typeof fill==='function'?fill(q,dx):fill});
const winFill=(c,mull=true)=>(q,dx)=>mull&&(Math.abs(dx)<.6/T)?rp(IRON,.3,q.sx,q.sy):c;
const doorFill=(R=WOOD)=>(q,dx)=>{let b=.5;if(((dx*T/3)%1+1)%1<.34)b-=.2;if(Math.abs(q.y%.3)<.04)b-=.1;return rp(R,b,q.sx,q.sy)};
// rayonnage de livres (ou de caisses) sur une façade : x0..x1 locaux, y0..y1 absolus
function booksI(x0,x1,y0,y1,rows,seed=1,o={}){return frontI(q=>{if(q.x<x0||q.x>x1||q.y<y0||q.y>y1)return null;const r=(q.y-y0)/(y1-y0)*rows,row=Math.floor(r),lv=r-row;
 if(lv<.16||Math.abs(q.x-x0)<1.2/T||Math.abs(q.x-x1)<1.2/T)return rp(o.frame||WOOD,lv<.08?.35:.62,q.sx,q.sy);
 const u=Math.floor((q.x-x0)*T/(o.w||2)+row*1.7),k=hash(u,row,seed),top=.16+.72*(.6+.4*hash(u,row+9,seed));
 if(o.crates){const cu=Math.floor((q.x-x0)*T/6+row*.5),ck=hash(cu,row,seed),lx=((q.x-x0)*T/6+row*.5)-cu;if(ck<.2||lv>.86)return rp(DSTONE,.15,q.sx,q.sy);const R=ck>.86?BLUEC:ck>.76?REDC:WOOD;
  return rp(R,(lx<.17||lx>.83||lv<.24||lv>.78)?.75:.45+(Math.abs(lx-.5)-Math.abs(lv-.5)<.05&&Math.abs(lx-.5)-Math.abs(lv-.5)>-.05&&R===WOOD?.15:0),q.sx,q.sy)}
 if(lv>top||k<.08)return rp(DSTONE,.12,q.sx,q.sy);if(o.scrolls)return rp(PARCH,.55+(Math.hypot(((q.x-x0)*T/3)%1-.5,(lv-.5)*2)<.3?.3:0),q.sx,q.sy);
 const c=SPINE[Math.floor(k*SPINE.length)];const fx=((q.x-x0)*T/(o.w||2))%1;return sh(c,fx<.5?.12:-.12)})}

// ---------- accessoires ----------
function box(x,z,hw,hd,y0,y1,mat,o={}){return slab(rect(-hw,-hd,hw,hd),y0,y1,mat,{x,z,...o})}
function post(x,z,y1,R=WOOD,w=.06,y0=0){return slab(square(w),y0,y1,woodMat(R),{x,z,key:z+.001})}
function crateMat(s,R=WOOD){return q=>{const b=q.f==='top'?.84:q.b,a=q.x/s,c=q.f==='top'?q.z/s:(q.v-.5)*2;if(Math.abs(a)>.74||Math.abs(c)>.74)return rp(R,b+.1,q.sx,q.sy);
 if(Math.abs(a-c)<.14)return rp(R,b+.04,q.sx,q.sy);return rp(R,b-.16+(hash(q.sx,q.sy>>1,4)-.5)*.1,q.sx,q.sy)}}
function crate(x,z,s=.17,y0=0,R=WOOD){return slab(square(s),y0,y0+s*1.7,crateMat(s,R),{x,z})}
function chestMat(R){return q=>{const b=q.f==='top'?.82:q.b;if(q.f==='side'){if(Math.abs(q.x)>.15||Math.abs(q.x)<.025)return rp(IRON,b+.1,q.sx,q.sy);if(Math.abs(q.v-.62)<.06)return rp(IRON,.3,q.sx,q.sy);if(Math.abs(q.x)<.06&&q.v>.38&&q.v<.58)return rp(SILVER,.8,q.sx,q.sy)}
 else if(Math.abs(q.x)>.15||Math.abs(q.x)<.025)return rp(IRON,b,q.sx,q.sy);return rp(R,b,q.sx,q.sy)}}
function chest(x,z,R){return slab(rect(-.19,-.12,.19,.12),0,.27,chestMat(R),{x,z})}
function barrel(x,z,R=WOOD,o={}){return slab(circle(o.r||.15),o.y0||0,(o.y0||0)+(o.h||.42),q=>{if(q.f==='top')return o.water?(q.rad<(o.r||.15)*.75?rp(WATER,.6+(hash(q.sx,q.sy,2)-.5)*.4,q.sx,q.sy):rp(R,.8,q.sx,q.sy)):rp(R,q.rim?.9:.62,q.sx,q.sy);
 if(Math.abs(q.v-.2)<.06||Math.abs(q.v-.8)<.06)return rp(IRON,q.b+.1,q.sx,q.sy);return rp(R,q.b+(Math.abs(q.v-.5)<.3?.06:0)+(((q.ang*6/Math.PI)%1+1)%1<.15?-.15:0),q.sx,q.sy)},{x,z})}
function planks(x,z,n=4,len=.5,o={}){return{key:z,draw(L,S){S.shadowShape(rect(-len,-.14,len,.14),x,z,n*.05,.6);for(let k=0;k<n;k++){const dx=(hash(k,1,o.seed||3)-.5)*.08;
 prism(L,rect(-len+dx,-.13,len+dx,.13),{x,z,y0:k*.055,y1:k*.055+.05,mat:woodMat(o.R||WOOD,{along:'x'})})}return{}}}}
function logs(x,z,n=3,len=.4){const objs=[];for(let k=0;k<n;k++){const lx=x+(k-(n-1)/2)*.2,y0=0;objs.push(roof('logz',lx,z,.1,len,y0,.2,logMat,{key:z+len+k*.001,noShadow:1,th:0}))}
 if(n>2)objs.push(roof('logz',x,z-.02,.1,len,.17,.2,logMat,{key:z+len+.01,noShadow:1,th:0}));return objs}
const logMat=q=>{if(q.f==='side'){const r=Math.hypot(q.x,q.y-(q.y>0?0:0));return rp(SAND,.5+((Math.floor(q.x*T*.6+q.y*T*.6)&1)?.12:-.05),q.sx,q.sy)}return rp(BARK,q.b-.05+(hash(q.sx,q.sy>>1,7)>.7?.15:0),q.sx,q.sy)};
function lectern(x,z,o={}){return{key:z,draw(L,S){const[a,b]=P3(x,o.y0||0,z);S.shadowEll(a+3,b,6,2,.7);prism(L,square(.05),{x,z,y0:o.y0||0,y1:(o.y0||0)+.42,mat:woodMat(WOOD)});
 prism(L,rect(-.16,-.1,.16,.1),{x,z,y0:(o.y0||0)+.42,y1:(o.y0||0)+.5,mat:woodMat(WOOD)});const[c,d]=P3(x,(o.y0||0)+.5,z);const C_=Math.round(c),D=Math.round(d);
 for(let j=-2;j<=1;j++)for(let i=-4;i<=4;i++)if(i)L.set(C_+i,D+j,rp(PARCH,.85-Math.abs(i)*.05-(j+2)*.04,i,j));L.set(C_,D-2,PARCH[1]);L.set(C_,D-1,PARCH[1]);return{}}}}
function sawhorse(x,z){return{key:z,draw(L,S){const[a,b]=P3(x,0,z);S.shadowEll(a+3,b,10,3,.6);const A=Math.round(a),B=Math.round(b);
 for(const s of[-7,6]){L.line(A+s-2,B,A+s,B-7,WOOD[2]);L.line(A+s+2,B,A+s,B-7,WOOD[3])}L.rect(A-9,B-9,19,2,WOOD[4]);L.rect(A-9,B-7,19,1,WOOD[1]);return{}}}}
function lanternHang(x,y,z,c=WHC,lc=WHITEC,R=IRON){return{key:z+.02,draw(L){const[a,b]=P3(x,y,z),A=Math.round(a),B=Math.round(b);L.rect(A,B,1,3,R[2]);L.rect(A-1,B+3,3,4,c[2]);L.set(A,B+4,c[3]);L.rect(A-1,B+3,3,1,R[3]);L.rect(A-1,B+7,3,1,R[2]);
 return{lights:[{x:A,y:B+5,r:34,i:.75,c:lc,fl:.08}]}}}}
function candleDyn(x,y,z,kind='white'){const[a,b]=P3(x,y,z);return flameDyn(Math.round(a),Math.round(b),kind,.6)}

// ---------- animations ----------
const sparkC=(cx,cy,cols,n=10,seed=1,up=14,spread=9,period=0,win=.5)=>{const c=cols.map(E);return(F,t)=>{if(period&&(t%period)>win*period)return;for(let k=0;k<n;k++){const per=period||6/Math.round(6/(.9+hash(k,3,seed)*.7)),p=period?(t%period)/(win*period):((t+hash(k,1,seed)*per)%per)/per,vx=(hash(k,2,seed)-.5)*spread*2,vy=up*(.6+hash(k,4,seed)*.6);
 const x=Math.round(cx+vx*p),y=Math.round(cy-vy*p+vy*1.4*p*p);if(p<.85)F.set(x,y,c[p<.25?c.length-1:p<.55?c.length-2:c.length-3])}}};
function wheelDyn(cx,cy,r,n,speed,R=WOOD,o={}){return(F,t)=>{const a0=t*speed;for(let k=0;k<n;k++){const a=a0+k*2*Math.PI/n;for(let s=2;s<r-1;s++)F.set(Math.round(cx+Math.cos(a)*s),Math.round(cy+Math.sin(a)*s*(o.sq||1)),R[3])}
 for(let k=0;k<72;k++){const a=k*2*Math.PI/72,x=Math.round(cx+Math.cos(a)*r),y=Math.round(cy+Math.sin(a)*r*(o.sq||1));F.set(x,y,Math.sin(a)<-.2?R[4]:R[2]);if(o.thick){F.set(Math.round(cx+Math.cos(a)*(r-1)),Math.round(cy+Math.sin(a)*(r-1)*(o.sq||1)),R[1])}
  if(o.teeth&&k%6===0)F.set(Math.round(cx+Math.cos(a+a0)*(r+1)),Math.round(cy+Math.sin(a+a0)*(r+1)*(o.sq||1)),R[3])}
 F.set(Math.round(cx),Math.round(cy),IRON[5]);F.set(Math.round(cx)+1,Math.round(cy),IRON[3])}}
function bladeDyn(cx,cy,r,speed){return(F,t)=>{for(let k=0;k<40;k++){const a=k*2*Math.PI/40;F.set(Math.round(cx+Math.cos(a)*r),Math.round(cy+Math.sin(a)*r*.45),SILVER[(k+Math.floor(t*speed))%4<2?4:2])}
 for(let i=-r+1;i<r;i++)F.set(Math.round(cx+i),Math.round(cy),SILVER[2]);F.set(Math.round(cx),Math.round(cy),IRON[1])}}
// marteau à bascule : pivot (px,py), tête au bout du bras ; frappe toutes les `per` s
function hammerDyn(px,py,len,per=1.1,dir=1,o={}){return(F,t)=>{const rest=o.rest??.12,amp=o.amp??.8,u=(t%per)/per,ang=u<.7?rest-amp*Math.sin(u/.7*Math.PI/2):rest-amp+amp*Math.min(1,(u-.7)/.12),c=Math.cos(ang),s=Math.sin(ang);
 const ex=px+dir*c*len,ey=py+s*len;F.line(Math.round(px),Math.round(py),Math.round(ex),Math.round(ey),WOOD[4]);F.line(Math.round(px),Math.round(py)+1,Math.round(ex),Math.round(ey)+1,WOOD[2]);
 for(let j=-2;j<=3;j++)for(let i=-2;i<=2;i++)F.set(Math.round(ex)+i,Math.round(ey)+j,j<0?IRON[5]:i<0?IRON[4]:IRON[2]);
 if(u>.82&&u<.95){const k=(u-.82)/.13;for(let m=0;m<8;m++){const a=-Math.PI*(.1+.8*hash(m,1,7)),r=2+k*9*hash(m,2,7);F.set(Math.round(ex+Math.cos(a)*r),Math.round(ey+4+Math.sin(a)*r*.7),(o.cols||MOLT)[m%2?3:4])}}}}
function hoistDyn(ax,ay,len,per=6,o={}){return(F,t)=>{const u=(t%per)/per,p=u<.4?u/.4:u<.5?1:u<.9?1-(u-.5)/.4:0,e=p*p*(3-2*p),y=Math.round(ay+(1-e)*len),sw=Math.round(Math.sin(t*2.3)*(o.sway||0));
 for(let j=ay;j<y-4;j++)F.set(ax+(j>ay+len*.6?sw:0),j,IRON[1]);const cx=ax+sw;for(let j=0;j<6;j++)for(let i=-3;i<=3;i++){const edge=Math.abs(i)===3||j===0||j===5;F.set(cx+i,y-4+j,o.cargo?o.cargo[edge?3:1]:edge?WOOD[4]:(i===j-2||i===2-j)?WOOD[3]:WOOD[2])}}}
function pageDyn(cx,cy,n=5,seed=3,h=26){return(F,t)=>{for(let k=0;k<n;k++){const p=((t*.22+hash(k,1,seed))%1),x=Math.round(cx+(hash(k,2,seed)-.5)*22+Math.sin(t*1.7+k*2)*4),y=Math.round(cy-p*h),fl=Math.floor(t*6+k)%3;
 if(p>.9)continue;const C_=p>.7?PARCH[2]:PARCH[4];if(fl===0){F.set(x-1,y,C_);F.set(x,y,C_);F.set(x+1,y,C_)}else if(fl===1){F.set(x-1,y-1,C_);F.set(x,y,C_);F.set(x+1,y-1,C_)}else{F.set(x,y,C_);F.set(x,y-1,C_)}}}}
function dustDyn(cx,cy,n=6,seed=4){return(F,t)=>{for(let k=0;k<n;k++){const p=((t*.5+hash(k,1,seed))%1),x=Math.round(cx+(hash(k,2,seed)-.5)*12+p*4),y=Math.round(cy-p*7+p*p*9);if(p<.8)F.set(x,y,SAND[k%2?5:4])}}}
function steamDyn(cx,cy,h=18,seed=5){const G=R_(['#8a8e98','#a8acb6','#c4c8d0']);return(F,t)=>{for(let k=0;k<6;k++){const p=((t*.4+hash(k,1,seed))%1),x=Math.round(cx+Math.sin(t*1.4+k)*2+(hash(k,3,seed)-.5)*6),y=Math.round(cy-p*h);if(p<.85&&hash(k,Math.floor(t*3),seed)>.2)F.set(x,y,G[p<.3?2:p<.6?1:0])}}}
const at=(x,y,z)=>{const[a,b]=P3(x,y,z);return[Math.round(a),Math.round(b)]};
const fx=(key,fn)=>({key,draw(){return fn()}});

// matériaux de base
const mMat=o=>stone(MARBLE,{veins:1,noise:.06,...o});
const sMat=o=>stone(SLATE,{courses:.2,joint:.6,noise:.1,...o});
const dMat=o=>stone(DSTONE,{courses:.18,joint:.45,noise:.12,...o});
const pMat=o=>stone(PLASTER,{noise:.1,...o});
const plinth=(R=SLATE,h=.12,s=1.28)=>slab(square(s),0,h,stone(R,{noise:.08}),{key:-9});

const GROUPS=[
 {id:'library',name:'Bibliothèque',staff:'Sigil',note:'Servie par les Livres ailés de Sigil : marbre gris veiné peu éclatant, ardoise, parchemin, lumière blanche. On y fait les recherches (Sceau de minage, Minicarte, Poste de tir, Arbalestrie).'},
 {id:'workshop',name:'Atelier',staff:'Aether',note:'Servi par les Orrery d’Aether : bois de charpente, fer, outils ; lueur bleu-violet. On y fabrique les défenses (poste de tir, barricade, chausse-trappes) et les pièces.'},
 {id:'forge',name:'Forge',staff:'Aether',note:'Servie par les Orrery d’Aether : pierre noircie, fer, feu bleu-violet (le feu d’Aether, comme la forge actuelle) ; le métal chauffé reste orangé.'},
 {id:'warehouse',name:'Entrepôt logistique',staff:'Sigil',note:'Servi par les Livres ailés de Sigil : caisses, coffres bleus et rouges, marbre et ardoise. Les adeptes y prennent et y déposent les objets.'}];

const ITEMS=[
// ======================= BIBLIOTHÈQUE =======================
 {g:'library',name:'Rotonde des rouleaux',desc:'Un tambour de marbre veiné coiffé d’un dôme d’ardoise et d’une lanterne de quartz. Entre les pilastres, des alvéoles garnies de rouleaux ; porte en arc au centre, pupitre devant. Des feuillets s’échappent de la lanterne.',
  build(){const drum=q=>{if(q.f!=='side')return null;const a=((q.ang*8/Math.PI)%2+2)%2;if(Math.abs(q.ang-Math.PI/2)<.32){return null}
    if(a<.22)return rp(MARBLE,q.b+.2,q.sx,q.sy);if(q.v>.25&&q.v<.78){const r=(q.v-.25)/.53*4,lv=r-Math.floor(r);if(lv<.18)return rp(WOOD,.5,q.sx,q.sy);return rp(PARCH,.5+(((q.sx*3+q.sy*7)%5)<2?.28:0),q.sx,q.sy)}return null};
   const door=q=>q.f==='side'&&Math.abs(q.ang-Math.PI/2)<.32?(q.y<.98&&Math.abs(q.ang-Math.PI/2)<.24-(q.y>.82?(q.y-.82)*1.3:0)?doorFill()(q,(q.ang-Math.PI/2)*.9):rp(MARBLE,q.b+.15,q.sx,q.sy)):null;
   const objs=[slab(poly(8,1.32,Math.PI/8),0,.14,stone(MARBLE,{noise:.06}),{key:-9}),slab(circle(.98),.14,.22,mMat(),{key:-8}),
    slab(circle(.9),.22,1.38,mMat({inlay:anyI(door,drum),trim:{R:MARBLE,v0:.9,v1:1}}),{key:-1}),
    roof('dome',0,0,1.0,1.0,1.38,.55,shingle(SLATE,{axis:'r',cw:.12}),{key:1,noShadow:1}),
    slab(circle(.17),1.86,2.14,stone(QZ,{noise:.05,inlay:q=>q.f==='side'&&((q.ang*4/Math.PI)%1+1)%1<.3?rp(MARBLE,.8,q.sx,q.sy):(q.f==='side'?WHC[2]:null)}),{key:2,lights:[{x:0,y:2.0,z:0,r:46,i:.8,c:WHITEC}]}),
    slab(circle(.2),2.14,2.26,stone(SLATE),{key:2.1,taper:[1,.2]}),
    slab(rect(-.3,-.12,.3,.12),.14,.2,stone(MARBLE),{z:1.0,key:.5}),lectern(.78,.9),barrel(-.86,.86,WOOD,{h:.32}),
    fx(3,()=>{const[a,b]=at(0,2.1,0);return{dyn:pageDyn(a,b,6,2,30)}})];
   return{ground:floor(),objs}}},
 {g:'library',name:'Galerie à portique',desc:'Le plan d’un petit temple : fronton d’ardoise sur quatre colonnes de marbre, et derrière elles le mur du fond tapissé de rayonnages. On lit les livres depuis la rue. Deux veilleuses blanches sur les marches.',
  build(){const objs=[slab(rect(-1.28,-1.28,1.28,1.28),0,.12,stone(MARBLE,{noise:.06}),{key:-9}),slab(rect(-1.15,.55,1.15,1.05),.12,.24,stone(MARBLE,{noise:.06}),{key:-8}),
    box(0,-.45,1.1,.62,.12,1.32,mMat({inlay:anyI(booksI(-1.0,1.0,.3,1.22,3,4),rectI(0,1.1,.12,.3,()=>rp(MARBLE,.75,0,0)))}),{key:-1}),
    ...[-.9,-.3,.3,.9].map(cx=>column(cx,.78,1.32,MARBLE)),
    roof('gz',0,-.18,1.24,1.1,1.32,.55,shingle(SLATE,{axis:'z',cw:.13,side:q=>Math.hypot(q.x,q.y-1.5)<.11?(Math.hypot(q.x,q.y-1.5)<.07?WINW:rp(MARBLE,.95,q.sx,q.sy)):rp(MARBLE,.72+(q.lip?.15:0),q.sx,q.sy)}),{key:2,noShadow:1}),
    box(0,.86,1.26,.07,1.24,1.34,mMat(),{key:2.5}),
    column(-.95,1.18,.36,MARBLE,{flame:'white',light:WHITEC}),column(.95,1.18,.36,MARBLE,{flame:'white',light:WHITEC}),
    fx(3,()=>{const[a,b]=at(0,.9,.2);return{dyn:pageDyn(a,b,3,6,16),lights:[{x:a,y:b,r:50,i:.4,c:WHITEC}]}})];
   return{ground:floor(),objs}}},
 {g:'library',name:'Tour du scribe',desc:'Une tour carrée de marbre à toit pyramidal d’ardoise, fenêtre haute éclairée où travaille le copiste ; à ses pieds une annexe basse à toit en appentis, porte ouverte sur des étagères. La plus verticale : elle se repère de loin.',
  build(){const objs=[plinth(SLATE,.1),
    box(-.42,-.42,.55,.55,.1,2.25,mMat({inlay:anyI(archI(0,.17,1.45,1.95,winFill(WINW)),archI(0,.13,.7,1.05,winFill(WINW)),frontI(q=>Math.abs(q.y-1.32)<.04?rp(MARBLE,.92,q.sx,q.sy):null))}),{key:-.4,lights:[{x:-.42,y:1.7,z:.2,r:40,i:.7,c:WHITEC}]}),
    roof('pyr',-.42,-.42,.68,.68,2.25,.78,shingle(SLATE,{axis:'r',cw:.13}),{key:.4,noShadow:1}),
    slab(square(.05),3.03,3.2,stone(IRON),{x:-.42,z:-.42,key:.5}),
    box(.62,.2,.55,.62,.1,.95,sMat({inlay:anyI(rectI(-.05,.3,.1,.75,q=>booksI(-.32,.22,.12,.74,2,9)(q)??rp(DSTONE,.2,q.sx,q.sy)))}),{key:.6}),
    roof('shed',.62,.2,.66,.72,.95,.42,woodMat(WOOD,{along:'x'}),{key:1,noShadow:1,th:.05}),
    crate(.15,1.05,.14),crate(-.12,1.12,.12),lectern(-.9,.8),lanternHang(.25,.86,.92),
    fx(2,()=>{const[a,b]=at(-.42,1.7,.14);return{dyn:pageDyn(a,b-8,3,8,18)}})];
   return{ground:floor(),objs}}},
 {g:'library',name:'Cloître aux rayonnages',desc:'Pas de toit fermé : trois murs-bibliothèques en U, chacun sous un auvent d’ardoise, entourent une table de lecture où un grand livre reste ouvert. Les pages tournent toutes seules et des feuillets flottent au-dessus.',
  build(){const ob=q=>q.f==='top'&&Math.abs(q.x)<.28&&Math.abs(q.z)<.18?(Math.abs(q.x)<.02?PARCH[1]:rp(PARCH,.85-Math.abs(q.x)*.6,q.sx,q.sy)):null;
   const objs=[slab(square(1.3),0,.1,stone(MARBLE,{noise:.06,pave:q=>(Math.floor(q.x/.33)+Math.floor(q.z/.33))&1?.06:0}),{key:-9}),
    box(0,-1.02,1.22,.2,.1,1.15,mMat({inlay:booksI(-1.12,1.12,.2,1.08,3,11)}),{key:-1}),
    roof('shed',0,-1.02,1.3,.3,1.15,.25,shingle(SLATE,{cw:.1}),{key:-.7,noShadow:1}),
    box(-1.08,0,.18,.85,.1,1.0,mMat({inlay:booksI(-.12,.12,.2,.95,3,5)}),{key:.85}),box(1.08,0,.18,.85,.1,1.0,mMat({inlay:booksI(-.12,.12,.2,.95,3,6)}),{key:.85}),
    roof('gz',-1.08,0,.26,.92,1.0,.2,shingle(SLATE,{axis:'z',cw:.1}),{key:.95,noShadow:1}),roof('gz',1.08,0,.26,.92,1.0,.2,shingle(SLATE,{axis:'z',cw:.1}),{key:.95,noShadow:1}),
    box(0,.1,.42,.28,.1,.5,woodMat(WOOD,{inlay:ob}),{key:.3,lights:[{x:0,y:.6,z:.1,r:48,i:.6,c:WHITEC}]}),
    fx(.9,()=>{const[a,b]=at(0,.5,.1);return{dyn:(F,t)=>{const u=(t%3)/3;if(u<.35){const p=u/.35,w=Math.round(Math.cos(p*Math.PI)*6);for(let j=0;j<4;j++)F.set(a+w,b-1-j-Math.round(Math.sin(p*Math.PI)*3),PARCH[4])}pageDyn(a,b-6,5,4,26)(F,t)}}}),
    column(-.75,.95,.6,MARBLE,{flame:'white',light:WHITEC}),column(.75,.95,.6,MARBLE,{flame:'white',light:WHITEC})];
   return{ground:floor(),objs}}},
 {g:'library',name:'Archive en gradins',desc:'Trois gradins de marbre dont chaque contremarche est un rayonnage de livres et de rouleaux ; un escalier au milieu mène au pupitre du sommet, où un grand livre lévite dans un rai de lumière blanche.',
  build(){const objs=[slab(square(1.24),0,.62,mMat({inlay:anyI(rectI(0,.16,.1,.62,q=>rp(MARBLE,.55+((q.y*T/3|0)&1?.2:0),q.sx,q.sy)),booksI(-1.14,-.2,.08,.56,2,2),booksI(.2,1.14,.08,.56,2,3,{scrolls:1}))}),{key:-3}),
    slab(square(.88),.62,1.12,mMat({inlay:anyI(rectI(0,.16,.62,1.12,q=>rp(MARBLE,.55+((q.y*T/3|0)&1?.2:0),q.sx,q.sy)),booksI(-.8,-.2,.68,1.08,2,7,{scrolls:1}),booksI(.2,.8,.68,1.08,2,8))}),{key:-2}),
    slab(square(.55),1.12,1.55,mMat({inlay:booksI(-.48,.48,1.17,1.5,2,12)}),{key:-1}),
    slab(square(.6),1.55,1.62,stone(MARBLE),{key:-.5}),lectern(0,0,{y0:1.62}),
    fx(1,()=>{const[a,b]=at(0,2.15,0);return{lights:[{x:a,y:b,r:58,i:.9,c:WHITEC}],dyn:(F,t)=>{const bob=Math.round(Math.sin(t*1.8)*1.5),y=b+bob;
     for(let j=-24;j<12;j++)if(hash(j,Math.floor(t*4),5)>.55)F.set(a+((j*7)%5)-2,y+j,WHC[1]);for(let i=-6;i<=6;i++)for(let j=-2;j<=1;j++)if(i)F.set(a+i,y+j-Math.round(Math.abs(i)*.25),rp(PARCH,.9-Math.abs(i)*.04,i,j));F.set(a,y-1,PARCH[1]);F.set(a,y,PARCH[1]);
     pageDyn(a,y-4,4,13,20)(F,t)}}})];
   return{ground:floor(),objs}}},
// ======================= ATELIER =======================
 {g:'workshop',name:'Hangar de charpente',desc:'Une charpente ouverte : quatre poteaux, un toit à pignon en bardeaux de bois. Dessous, l’établi et ses outils ; devant, un rondin sur chevalet qu’on scie (sciure), une pile de planches et de pieux. Lanterne d’Aether au faîtage.',
  build(){const objs=[slab(square(1.28),0,.08,woodMat(WOOD,{along:'x'}),{key:-9}),
    box(0,-.95,1.05,.12,.08,.95,woodMat(WOOD,{inlay:frontI(q=>{const k=Math.floor((q.x+1)*4.2);if(q.y>.45&&q.y<.8&&((q.x+1)*4.2)%1<.25)return rp(IRON,.75,q.sx,q.sy);if(q.y>.5&&q.y<.78&&k%3===1&&Math.abs(((q.x+1)*4.2)%1-.5)<.25)return rp(WOOD,.9,q.sx,q.sy);return null})}),{key:-1}),
    box(-.1,-.55,.7,.22,.08,.48,woodMat(WOOD,{along:'x'}),{key:-.4}),
    post(-1.08,-.9,1.25),post(1.08,-.9,1.25),post(-1.08,.75,1.25),post(1.08,.75,1.25),
    roof('gz',0,-.15,1.3,.98,1.25,.7,shingle(BARK,{axis:'z',cw:.12,side:q=>Math.abs(q.x)<.05||Math.abs(q.y-1.42)<.035?rp(WOOD,.8,q.sx,q.sy):rp(DSTONE,.18,q.sx,q.sy)}),{key:2,noShadow:1}),
    lanternHang(0,1.5,.85,AEC,VIOBLUE),
    sawhorse(.35,.9),roof('logz',.35,.9,.55,.11,.34,.22,logMat,{hf:(lx,lz)=>Math.abs(lx)>.55||Math.abs(lz)>.11?null:.34+.11+Math.sqrt(Math.max(0,.0121-lz*lz)),key:1.2,noShadow:1,th:0}),
    planks(-.8,.95,5,.38),post(-.25,1.05,.55,WOOD,.035),post(-.15,1.08,.62,WOOD,.035),
    fx(1.3,()=>{const[a,b]=at(.35,.38,.92);return{dyn:(F,t)=>{dustDyn(a,b+3,7,4)(F,t);const s=Math.round(Math.sin(t*6)*3);for(let i=0;i<6;i++)F.set(a+s+i-2,b-3-Math.round(i*.3),SILVER[i%2?2:4])}}})];
   return{ground:floor(),objs}}},
 {g:'workshop',name:'Atelier des instruments',desc:'Une maison de pierre au toit d’ardoise ; sur le faîtage tourne une petite sphère armillaire d’Aether qui sert de girouette. Fenêtre bleu-violet, porte de bois, établi extérieur avec étau et caisse de pièces.',
  build(){const objs=[plinth(SLATE,.1),
    box(0,-.3,1.05,.72,.1,1.0,dMat({inlay:anyI(rectI(-.45,.19,.1,.78,doorFill()),rectI(.42,.27,.42,.75,winFill(WINV)))}),{key:-1,lights:[{x:.42,y:.6,z:.45,r:40,i:.65,c:VIOBLUE}]}),
    roof('gx',0,-.3,1.16,.86,1.0,.72,shingle(SLATE,{cw:.13,moss:.12}),{key:1,noShadow:1}),
    slab(square(.04),1.72,2.02,stone(IRON),{z:-.3,key:1.2}),
    fx(1.3,()=>{const[a,b]=at(0,2.12,-.3);return{lights:[{x:a,y:b,r:30,i:.6,c:VIOBLUE}],dyn:(F,t,S)=>{ringDyn(a,b,7,['#5a5cff','#9aa0ff','#e0e4ff'],1.1)(F,t,S);ringDyn(a,b,5,['#34327a','#9aa0ff','#e0e4ff'],-.7)(F,t,S);F.set(a,b,AEC[3]);F.set(a,b-1,AEC[2])}}}),
    box(.75,.85,.36,.18,0,.4,woodMat(WOOD,{along:'x'}),{key:.85}),slab(rect(-.07,-.05,.07,.05),.4,.52,stone(IRON),{x:.55,z:.85,key:.9}),
    crate(-.78,.82,.17),crate(-.42,.95,.13),slab(circle(.06),.4,.44,stone(SILVER),{x:.88,z:.85,key:.91})];
   return{ground:floor(),objs}}},
 {g:'workshop',name:'Établi sous auvent',desc:'Un mur de pierre sèche porte le panneau d’outils ; devant, un auvent de toile tendu sur deux perches. Un tour à pédale fait tourner sa grande roue, des copeaux volent. Fagots de pieux et rouleau de corde pour les barricades.',
  build(){const tools=frontI(q=>{if(q.y<.35||q.y>.95)return null;const u=(q.x+1)*3.3,k=Math.floor(u),f=u-k;if(k<0||k>5)return null;if(k%2===0)return Math.abs(f-.5)<.08&&q.y<.9?rp(WOOD,.8,q.sx,q.sy):Math.abs(f-.5)<.25&&q.y>.82&&q.y<.9?rp(IRON,.85,q.sx,q.sy):null;return Math.abs(f-.5)<.06&&q.y>.45?rp(SILVER,.8,q.sx,q.sy):Math.abs(f-.5)<.2&&q.y<.5&&q.y>.42?rp(WOOD,.6,q.sx,q.sy):null});
   const stripe=q=>q.f==='top'?rp(((Math.floor((q.x+2)*3.5))&1)?CANVAS:R_(['#33345e','#43457a','#575aa0','#7174c4','#9396dc']),q.b+(q.eave?.1:0),q.sx,q.sy):rp(CANVAS,.5,q.sx,q.sy);
   const objs=[slab(square(1.28),0,.08,stone(TERRE,{noise:.14}),{key:-9}),
    box(0,-1.0,1.2,.22,.08,1.1,stone(MSTONE,{courses:.16,joint:.3,noise:.18,moss:.1,inlay:tools}),{key:-1}),
    post(-1.05,.05,1.12,WOOD,.05),post(1.05,.05,1.12,WOOD,.05),
    roof('shed',0,-.55,1.25,.62,1.08,.3,stripe,{key:.2,noShadow:1,th:.03,hf:(lx,lz)=>1.08+.3*(.62-lz)/1.24-.03*Math.sin((lx+1.25)*Math.PI*2.4)**2}),
    box(.2,-.45,.6,.2,.08,.46,woodMat(WOOD,{along:'x'}),{key:-.6}),box(-.7,.45,.2,.14,.08,.38,woodMat(WOOD),{key:.4}),
    fx(.6,()=>{const[a,b]=at(-.82,.62,.45);return{dyn:(F,t)=>{wheelDyn(a,b,8,6,2.2,WOOD,{thick:1})(F,t);dustDyn(a+12,b+2,5,8)(F,t);F.line(a+9,b-1,a+14,b-1,WOOD[4]);F.set(a+15,b-1,IRON[4])}}}),
    ...logs(.72,.7,3,.3),slab(circle(.13),.08,.2,stone(SAND,{noise:.2,inlay:ringI(.06,.03,SAND[1])}),{x:-.2,z:.95}),
    lanternHang(.95,1.02,.05,AEC,VIOBLUE)];
   return{ground:floor(),objs}}},
 {g:'workshop',name:'Chantier à la grue',desc:'Une petite remise de planches et, à côté, une grue de bois qui hisse une poutre : la poutre monte, se balance, redescend. Tas de madriers, chevalet, caisse de clous. Raconte « on construit les défenses ici ».',
  build(){const objs=[plinth(TERRE,.06,1.3),
    box(-.55,-.6,.62,.55,.06,.95,woodMat(WOOD,{inlay:rectI(.05,.22,.06,.7,q=>rp(DSTONE,.15,q.sx,q.sy))}),{key:-.8}),
    roof('gx',-.55,-.6,.72,.68,.95,.5,shingle(SLATE,{cw:.12}),{key:.1,noShadow:1}),
    post(.78,-.65,2.05,WOOD,.07),box(.78,-.65,.12,.12,0,.18,stone(SLATE),{key:-.6}),
    fx(-.5,()=>{const[a,b]=at(.78,2.0,-.65);return{dyn:(F,t)=>{F.line(a-3,b,a+22,b+2,WOOD[4]);F.line(a-3,b+1,a+22,b+3,WOOD[2]);F.line(a,b+1,a+20,b+3,WOOD[1]);F.line(a+1,b,a+1,b-3,IRON[3]);F.line(a+1,b-3,a+21,b+1,IRON[2]);
     const u=(t%7)/7,p=u<.4?u/.4:u<.55?1:u<.95?1-(u-.55)/.4:0,e=p*p*(3-2*p),y=Math.round(b+38-e*28),sw=Math.round(Math.sin(t*2.1)*1.6*e);for(let j=b+3;j<y;j++)F.set(a+20+(j>b+12?sw:0),j,IRON[1]);
     for(let i=-9;i<=9;i++)for(let j=0;j<3;j++)F.set(a+20+sw+i,y+j,j===0?WOOD[5]:WOOD[j===2?1:3]);F.set(a+20+sw,y-1,IRON[4])}}}),
    planks(.15,.95,6,.45,{seed:7}),...logs(-.75,.6,3,.35),crate(.95,.75,.14),sawhorse(.55,.25)];
   return{ground:floor(),objs}}},
 {g:'workshop',name:'Roue de l’atelier',desc:'Une grande roue à rayons, à hauteur d’homme, tourne contre le pignon de l’atelier et entraîne une scie circulaire sur l’établi : copeaux et étincelles bleutées. Le mécanisme fait le spectacle, même vu de loin.',
  build(){const objs=[plinth(SLATE,.1),
    box(.25,-.55,.95,.62,.1,.95,dMat({inlay:anyI(rectI(.45,.2,.1,.72,doorFill()),rectI(-.25,.18,.45,.72,winFill(WINV)))}),{key:-1,lights:[{x:0,y:.6,z:.1,r:36,i:.55,c:VIOBLUE}]}),
    roof('gz',.25,-.55,1.05,.72,.95,.62,shingle(SLATE,{axis:'z',cw:.12,side:q=>rp(WOOD,.55+(((q.x*T/3)|0)&1?.08:-.06),q.sx,q.sy)}),{key:.2,noShadow:1}),
    box(.35,.55,.62,.2,.1,.48,woodMat(WOOD,{along:'x'}),{key:.55}),
    box(-.98,.05,.08,.12,.1,.85,woodMat(WOOD),{key:.04}),
    fx(.6,()=>{const[a,b]=at(-1.0,.85,.12);const[c,d]=at(.35,.48,.55);return{lights:[{x:c,y:d-2,r:24,i:.5,c:VIOBLUE}],dyn:(F,t)=>{wheelDyn(a,b,15,8,1.1,WOOD,{thick:1,teeth:1})(F,t);
     F.line(a,b,c-6,d-2,IRON[3]);bladeDyn(c,d-1,5,10)(F,t);sparkC(c+4,d-2,['#34327a','#9aa0ff','#e0e4ff'],7,3,8,7)(F,t);dustDyn(c-5,d,4,2)(F,t)}}}),
    planks(.75,1.05,3,.32),crate(-.4,1.0,.13),barrel(-.55,.62,WOOD,{h:.36,r:.13})];
   return{ground:floor(),objs}}},
// ======================= FORGE =======================
 {g:'forge',name:'Forge à hotte',desc:'Un foyer ouvert sous une immense hotte de pierre qui se resserre en cheminée : le feu bleu-violet d’Aether brûle à hauteur de taille. Enclume, baquet de trempe qui fume, soufflet, râtelier de barres.',
  build(){const hearth=q=>q.f==='top'&&Math.abs(q.x)<.5&&Math.abs(q.z)<.22?rp(R_(['#1a1830','#2a2850','#3c3a7a']),.5+(hash(q.sx,q.sy,2)-.5)*.6,q.sx,q.sy):null;
   const objs=[plinth(DSTONE,.1),
    box(0,-.95,1.1,.3,.1,1.2,dMat(),{key:-2}),
    box(0,-.35,.72,.36,.1,.55,dMat({inlay:hearth}),{key:-.2,lights:[{x:0,y:.8,z:-.3,r:60,i:1,c:VIOBLUE,fl:.2}]}),
    roof('hip',0,-.6,1.02,.62,1.2,.72,stone(DSTONE,{courses:.16,joint:.4,noise:.12}),{key:.1,noShadow:1,hf:(lx,lz)=>{const f=Math.min(1-Math.abs(lx)/1.02,1-Math.abs(lz)/.62);return 1.2+Math.min(.62,f*1.05)}}),
    box(0,-.6,.26,.22,1.82,2.55,dMat(),{key:.15}),
    post(-.85,.05,1.2,DSTONE,.09),post(.85,.05,1.2,DSTONE,.09),
    fx(.12,()=>{const[a,b]=at(0,2.55,-.6);return{dyn:smokeDyn(a,b-1,36,10)}}),
    fx(.2,()=>{const p=[-.3,-.1,.1,.3].map(x=>at(x,.55,-.3));return{dyn:(F,t)=>{for(const[a,b]of p)flameDyn(a,b,'vb',1.05)(F,t);sparkC(p[1][0],p[1][1]-4,['#34327a','#9aa0ff','#e0e4ff'],6,9,10,8)(F,t)}}}),
    anvil(.4,.62),barrel(-.75,.65,WOOD,{water:1,h:.36,r:.17}),fx(.9,()=>{const[a,b]=at(-.75,.4,.65);return{dyn:steamDyn(a,b,14)}}),
    fx(.7,()=>{const[a,b]=at(.42,.4,.62);return{dyn:(F,t)=>{const k=Math.floor(t*3)%3;for(let i=-3;i<=3;i++)F.set(a+i,b-1,MOLT[k===0?4:3]);sparkC(a,b-2,['#7a3008','#ec8424','#ffeec0'],8,5,8,6,1,.35)(F,t)}}}),
    rack(1.05,.7,2)];
   return{ground:floor(),objs}}},
 {g:'forge',name:'Forge stellaire',desc:'Un four en dôme percé de petites étoiles qui laissent filer la lueur bleu-violette (une carte du ciel d’Aether). La gueule s’ouvre en arc sur le foyer ; trois étincelles en orbite. Enclume et lingots devant.',
  build(){const stars=q=>{if(q.f!=='top')return null;const k=hash(Math.floor(q.ang*9),Math.floor(q.y*9),4);if(k>.9&&((q.sx*7+q.sy*3)%5===0))return AEC[3];if(k>.84&&((q.sx+q.sy)%7===0))return AEC[2];return null};
   const mouth=q=>q.f==='side'&&Math.abs(q.ang-Math.PI/2)<.38&&q.y<.12+.5*Math.cos((q.ang-Math.PI/2)/.38*Math.PI/2)?rp(R_(['#2a2850','#5a5cff','#9aa0ff','#e0e4ff'].map(E)),.95-q.v*1.6+(hash(q.sx,q.sy,3)-.5)*.3,q.sx,q.sy):null;
   const objs=[slab(poly(8,1.3,Math.PI/8),0,.12,stone(DSTONE,{noise:.08}),{key:-9}),
    slab(circle(.92),.12,.62,dMat({inlay:anyI(mouth,q=>q.f==='side'&&Math.abs(q.v-.85)<.08?rp(IRON,q.b+.1,q.sx,q.sy):null)}),{key:-.5,lights:[{x:0,y:.4,z:.95,r:62,i:1,c:VIOBLUE,fl:.2}]}),
    roof('dome',0,0,.92,.92,.62,.62,((dm)=>q=>stars(q)??dm(q))(shingle(DSTONE,{axis:'r',cw:.14})),{key:.5,noShadow:1}),
    slab(circle(.16),1.18,1.46,dMat(),{key:.6}),
    fx(.7,()=>{const[a,b]=at(0,1.46,0);return{dyn:smokeDyn(a,b,30,8,7)}}),
    fx(.8,()=>{const[a,b]=at(0,1.05,0);return{dyn:orbit(a,b,30,10,3,['#5a5cff','#9aa0ff','#e0e4ff'],.8,1)}}),
    anvil(.55,.95),slab(rect(-.2,-.1,.2,.1),0,.1,stone(IRON),{x:-.7,z:.9}),slab(rect(-.2,-.1,.2,.1),.1,.2,stone(IRON),{x:-.68,z:.9}),
    fx(1.1,()=>{const[a,b]=at(0,.25,1.0);return{dyn:sparkC(a,b,['#34327a','#9aa0ff','#e0e4ff'],6,4,10,7)}})];
   return{ground:floor(),objs}}},
 {g:'forge',name:'Forge à martinet',desc:'La halle de forge, toit d’ardoise et cheminée ; devant, un martinet : une roue à cames soulève le grand marteau qui retombe sur l’enclume en gerbe d’étincelles, en cadence. Le plus vivant.',
  build(){const objs=[plinth(DSTONE,.1),
    box(-.15,-.6,1.0,.62,.1,1.0,dMat({inlay:anyI(rectI(.3,.3,.1,.72,q=>rp(R_(['#1a1830','#34327a','#5a5cff'].map(E)),.3+(1-(q.y-.1)/.62)*.7+(hash(q.sx,q.sy,5)-.5)*.3,q.sx,q.sy)),rectI(-.6,.18,.45,.75,winFill(WINV)))}),{key:-1,lights:[{x:.3,y:.4,z:.05,r:48,i:.85,c:VIOBLUE,fl:.2}]}),
    roof('gx',-.15,-.6,1.12,.76,1.0,.62,shingle(SLATE,{cw:.13}),{key:.2,noShadow:1}),
    slab(square(.2),0,2.2,dMat(),{x:-.75,z:-.75,taper:[1.15,.9],key:-.3}),fx(-.29,()=>{const[a,b]=at(-.75,2.2,-.75);return{dyn:smokeDyn(a,b,34,10,6)}}),
    box(.72,.55,.1,.1,.1,.8,woodMat(WOOD),{key:.5}),box(.72,.95,.1,.1,.1,.8,woodMat(WOOD),{key:.9}),
    anvil(.05,.75),
    fx(1.2,()=>{const[a,b]=at(.72,.6,.75);const[c,d]=at(.06,.38,.75);return{dyn:(F,t)=>{wheelDyn(a+6,b+4,7,4,2*Math.PI/1.1,WOOD,{thick:1})(F,t);hammerDyn(a-1,b-2,a-c-1,1.1,-1,{cols:MOLT})(F,t);
     const u=(t%1.1)/1.1;if(u>.8)for(let i=-3;i<=3;i++)F.set(c+i,d-1,MOLT[4]);else for(let i=-3;i<=3;i++)F.set(c+i,d-1,MOLT[2])}}}),
    barrel(-.85,.7,WOOD,{water:1,h:.34,r:.15}),rack(-.35,.25,2)];
   return{ground:floor(),objs}}},
 {g:'forge',name:'Forge de pierres sèches',desc:'Une forge de campagne à ciel ouvert : murets de pierres sèches en U, haute cheminée tronconique au fond, soufflet de cuir qui respire, foyer au feu bleu-violet. Discrète et rustique, entre ruine et bivouac.',
  build(){const dry=o=>stone(MSTONE,{courses:.14,joint:.26,noise:.22,moss:.16,...o});
   const objs=[slab(square(1.28),0,.06,stone(TERRE,{noise:.15}),{key:-9}),
    box(0,-1.02,1.18,.2,.06,.7,dry(),{key:-1.1}),box(-1.0,-.25,.18,.62,.06,.5,dry(),{key:-.2}),box(1.0,-.25,.18,.62,.06,.5,dry(),{key:-.2}),
    slab(circle(.42),.0,2.1,dry({courses:.14}),{z:-.8,key:-.9,taper:[1,.55]}),
    box(0,-.2,.48,.32,.06,.42,dry({inlay:q=>q.f==='top'&&Math.abs(q.x)<.32&&Math.abs(q.z)<.18?rp(R_(['#1a1830','#2a2850','#3c3a7a']),.6,q.sx,q.sy):null}),{key:-.1,lights:[{x:0,y:.7,z:-.2,r:58,i:1,c:VIOBLUE,fl:.22}]}),
    fx(-.05,()=>{const p=[-.15,.05,.2].map(x=>at(x,.42,-.2));return{dyn:(F,t)=>{for(const[a,b]of p)flameDyn(a,b,'vb',1.2)(F,t)}}}),
    fx(-.85,()=>{const[a,b]=at(0,2.1,-.8);return{dyn:smokeDyn(a,b,34,10,4)}}),
    bellows(-.65,.25),anvil(.55,.55),rack(.9,.85,3),fx(.6,()=>{const[a,b]=at(.55,.4,.55);return{dyn:sparkC(a,b-2,['#7a3008','#ec8424','#ffeec0'],7,8,9,6,1.6,.3)}})];
   return{ground:floor(),objs}}},
 {g:'forge',name:'Forge en cloche',desc:'Un four en forme de cloche de fer cerclée, autour duquel tournent deux anneaux d’Aether (l’astronomie du culte) ; une bouche en bas crache la lueur bleu-violette. Enclume, pince et lingots de part et d’autre. Le plus « Aether ».',
  build(){const mouth=q=>q.f==='side'&&Math.abs(q.ang-Math.PI/2)<.3&&q.v<.35?rp(R_(['#2a2850','#5a5cff','#9aa0ff','#e0e4ff'].map(E)),.95-q.v*2.2+(hash(q.sx,q.sy,3)-.5)*.3,q.sx,q.sy):null;
   const objs=[slab(circle(1.3),0,.12,stone(DSTONE,{noise:.08,inlay:anyI(ringI(1.1,.03,AEC[1]),dotsI(1.2,12,AEC[2]))}),{key:-9}),
    slab(circle(.72),.12,.5,iMat({inlay:anyI(mouth,q=>q.f==='side'&&Math.abs(q.v-.9)<.08?rp(IRON,q.b+.18,q.sx,q.sy):null)}),{key:-.5,lights:[{x:0,y:.3,z:.75,r:56,i:.95,c:VIOBLUE,fl:.2}]}),
    roof('bell',0,0,.72,.72,.5,1.15,stone(IRON,{noise:.06,inlay:q=>Math.abs(q.y-1.0)<.035||Math.abs(q.y-1.4)<.035?rp(IRON,q.b+.2,q.sx,q.sy):null}),{key:.3,noShadow:1}),
    slab(circle(.12),1.62,1.9,iMat(),{key:.4}),fx(.45,()=>{const[a,b]=at(0,1.9,0);return{dyn:smokeDyn(a,b,30,8,2)}}),
    fx(.5,()=>{const[a,b]=at(0,1.0,0);return{lights:[{x:a,y:b,r:50,i:.35,c:VIOBLUE}],dyn:(F,t,S)=>{ringDyn(a,b,26,['#5a5cff','#9aa0ff','#e0e4ff'],.6)(F,t,S);ringDyn(a,b-4,20,['#34327a','#9aa0ff','#e0e4ff'],-.45)(F,t,S)}}}),
    anvil(.8,.75),slab(rect(-.2,-.1,.2,.1),0,.1,stone(IRON),{x:-.85,z:.75}),slab(rect(-.18,-.09,.18,.09),.1,.2,stone(IRON),{x:-.84,z:.75}),
    fx(.9,()=>{const[a,b]=at(.8,.4,.75);return{dyn:sparkC(a,b-1,['#7a3008','#ec8424','#ffeec0'],6,2,8,6,1.4,.3)}})];
   return{ground:floor(),objs}}},
// ======================= ENTREPÔT LOGISTIQUE =======================
 {g:'warehouse',name:'Halle des rayonnages',desc:'Un haut rayonnage de caisses sous un appentis d’ardoise porté par quatre piliers de marbre ; devant, une cour dallée où s’alignent coffres bleus et rouges, une palette et des caisses à ranger. Lecture « stock » immédiate.',
  build(){const objs=[slab(square(1.28),0,.1,stone(MARBLE,{noise:.06,pave:q=>(Math.floor(q.x/.42)+Math.floor(q.z/.42))&1?.05:0}),{key:-9}),
    box(0,-.98,1.18,.2,.1,1.38,mMat({inlay:booksI(-1.08,1.08,.18,1.3,3,21,{crates:1})}),{key:-1.2}),
    ...[-1.08,-.36,.36,1.08].map(x=>column(x,-.5,1.38,MARBLE)),
    roof('shed',0,-.88,1.3,.46,1.38,.42,shingle(SLATE,{cw:.12}),{key:-.3,noShadow:1}),
    chest(-.75,-.05,BLUEC),chest(-.3,-.05,BLUEC),chest(.75,-.05,REDC),crate(.55,.55,.15),crate(.2,.72,.12),chest(-.55,.62,REDC),box(.1,.2,.32,.2,0,.05,woodMat(WOOD,{along:'x'})),crate(.05,.2,.13,.05),
    lanternHang(0,1.3,-.48),fx(1,()=>({dyn:pageDyn(...at(0,.6,.3),2,17,10)}))];
   return{ground:floor(),objs}}},
 {g:'warehouse',name:'Quai de transbordement',desc:'Un quai de pierre surélevé avec rampe d’accès et petit bureau du magasinier au fond ; un palan sur potence monte et descend une caisse entre le sol et le quai. Coffres bleus et rouges sur le quai.',
  build(){const objs=[slab(square(1.3),0,.05,stone(TERRE,{noise:.14}),{key:-9}),
    box(.1,-.35,1.15,.85,.05,.55,sMat({courses:.18}),{key:-1.3}),
    roof('shed',.1,.75,.5,.28,.05,.5,stone(SLATE,{noise:.1,inlay:q=>q.f==='top'&&((q.z*T/2.5|0)&1)?rp(SLATE,.6,q.sx,q.sy):null}),{key:.6,hf:(lx,lz)=>.05+.5*(.28-lz)/.56,noShadow:1}),
    box(-.5,-.85,.55,.35,.55,1.35,woodMat(WOOD,{inlay:anyI(rectI(.12,.15,.55,1.05,doorFill()),rectI(-.25,.14,.82,1.12,winFill(WINW)))}),{key:-1,lights:[{x:-.75,y:1.0,z:-.5,r:32,i:.6,c:WHITEC}]}),
    roof('gx',-.5,-.85,.65,.45,1.35,.4,shingle(SLATE,{cw:.12}),{key:-.4,noShadow:1}),
    {key:-.3,draw(L){prism(L,rect(-.19,-.12,.19,.12),{x:.3,z:-.6,y0:.55,y1:.82,mat:chestMat(BLUEC)});prism(L,rect(-.19,-.12,.19,.12),{x:.78,z:-.55,y0:.55,y1:.82,mat:chestMat(REDC)});return{}}},
    {key:-.1,draw(L){prism(L,square(.15),{x:.55,z:-.05,y0:.55,y1:.81,mat:crateMat(.15)});prism(L,rect(-.19,-.12,.19,.12),{x:-.5,z:-.1,y0:.55,y1:.82,mat:chestMat(BLUEC)});return{}}},
    post(1.05,.75,1.55,WOOD,.06),fx(.8,()=>{const[a,b]=at(1.05,1.5,.75);return{dyn:(F,t)=>{F.line(a,b,a-15,b+1,WOOD[4]);F.line(a,b+1,a-15,b+2,WOOD[2]);hoistDyn(a-14,b+2,22,6,{sway:1})(F,t)}}}),
    crate(.85,1.0,.15),chest(-.7,.95,REDC)];
   return{ground:floor(),objs}}},
 {g:'warehouse',name:'Réserve voûtée',desc:'Une voûte en berceau à demi enterrée, couverte de terre et de mousse ; façade de pierre taillée, porte cintrée à deux battants ferrés. Caisses et tonneaux attendent devant, sous une lanterne. Massive et sûre.',
  build(){const objs=[plinth(SLATE,.08),
    roof('vault',0,-.25,1.1,1.0,.08,1.25,q=>q.f==='top'?(vnoise(q.x*3,q.z*3+q.y,8)>.45?rp(MOSS,q.b,q.sx,q.sy):rp(EARTH,q.b+.1,q.sx,q.sy)):rp(EARTH,.4,q.sx,q.sy),{key:-1,shadow:.5,th:.02}),
    box(0,.62,1.05,.14,.08,1.18,sMat({courses:.16,joint:.42,inlay:anyI(archI(0,.4,.08,.95,(q,dx)=>Math.abs(dx)<.6/T?rp(IRON,.3,q.sx,q.sy):Math.abs(q.y-.35)<.03||Math.abs(q.y-.7)<.03?rp(IRON,.55,q.sx,q.sy):doorFill()(q,dx)),frontI(q=>q.y>1.02&&Math.abs(q.x)<.15?rp(MARBLE,.85,q.sx,q.sy):null))}),{key:.7}),
    lanternHang(.55,1.05,.8),
    crate(-.75,1.0,.16),crate(-.6,1.08,.12,.27),barrel(.85,1.0),barrel(.62,1.12,WOOD,{h:.38}),chest(-.25,1.12,BLUEC)];
   return{ground:floor(),objs}}},
 {g:'warehouse',name:'Grange aux silos',desc:'Deux silos ronds en pierre, coiffés de cônes d’ardoise, encadrent une grange à pignon ; porte de grange ouverte sur les caisses. Palettes de coffres devant. Se lit comme un dépôt de vivres et de matériaux.',
  build(){const objs=[plinth(SLATE,.08),
    box(0,-.45,.62,.72,.08,1.05,woodMat(WOOD,{inlay:rectI(0,.34,.08,.8,q=>booksI(-.32,.32,.1,.78,2,31,{crates:1})(q)??rp(DSTONE,.15,q.sx,q.sy))}),{key:-.9}),
    roof('gz',0,-.45,.74,.82,1.05,.62,shingle(SLATE,{axis:'z',cw:.13,side:q=>woodMat(WOOD)(q)}),{key:.3,noShadow:1}),
    slab(circle(.42),.08,1.55,stone(MSTONE,{courses:.18,joint:.4,noise:.12,moss:.08}),{x:-.88,z:-.55,key:-.4}),roof('cone',-.88,-.55,.48,.48,1.55,.55,shingle(SLATE,{axis:'r',cw:.12}),{key:-.05,noShadow:1}),
    slab(circle(.42),.08,1.55,stone(MSTONE,{courses:.18,joint:.4,noise:.12,moss:.08}),{x:.88,z:-.55,key:-.4}),roof('cone',.88,-.55,.48,.48,1.55,.55,shingle(SLATE,{axis:'r',cw:.12}),{key:-.05,noShadow:1}),
    box(-.6,.75,.32,.22,0,.06,woodMat(WOOD,{along:'x'})),chest(-.72,.75,BLUEC),chest(-.45,.78,BLUEC),
    box(.6,.75,.32,.22,0,.06,woodMat(WOOD,{along:'x'})),chest(.5,.75,REDC),crate(.78,.8,.12,.06),lanternHang(0,1.12,.3)];
   return{ground:floor(),objs}}},
 {g:'warehouse',name:'Magasin à étages',desc:'Un haut magasin de bois et de pierre sur deux niveaux, toit à pignon ; à l’étage, une porte de chargement sous une poutre à poulie : une caisse monte et descend au bout de sa corde. Coffres bleu et rouge de part et d’autre de la porte basse.',
  build(){const objs=[plinth(SLATE,.08),
    box(0,-.4,1.0,.75,.08,.75,sMat({courses:.18,joint:.5,inlay:rectI(0,.24,.08,.66,doorFill())}),{key:-1.2}),
    box(0,-.4,1.04,.79,.75,1.9,woodMat(WOOD,{inlay:anyI(rectI(0,.24,.95,1.55,q=>rp(DSTONE,.15,q.sx,q.sy)),rectI(-.65,.14,1.15,1.5,winFill(WINW)),rectI(.65,.14,1.15,1.5,winFill(WINW)),frontI(q=>q.y<.82?rp(WOOD,.8,q.sx,q.sy):null))}),{key:-1.1,lights:[{x:-.65,y:1.3,z:.4,r:30,i:.55,c:WHITEC},{x:.65,y:1.3,z:.4,r:30,i:.55,c:WHITEC}]}),
    roof('gx',0,-.4,1.14,.9,1.9,.62,shingle(SLATE,{cw:.13}),{key:.5,noShadow:1}),
    box(0,.55,.05,.18,1.95,2.03,woodMat(WOOD),{key:.6}),
    fx(.7,()=>{const[a,b]=at(0,1.95,.72);return{dyn:(F,t)=>{F.set(a,b,IRON[4]);F.set(a+1,b,IRON[2]);hoistDyn(a,b+1,30,6)(F,t)}}}),
    chest(-.62,.55,BLUEC),chest(.62,.55,REDC),crate(-.95,.95,.14),crate(.15,1.05,.13)];
   return{ground:floor(),objs}}},
];
function floorScene(){const S=new Scene();S.bake(floor(),[]);return S}

function vignette(i){const b=ITEMS[i].build(),S=new Scene();S.bake(b.ground,b.objs);if(b.fx)S.dyn.push(...b.fx(S));return S}
// ---------- export vers le jeu ----------
// Sprite 320 × 240, ancre (160, 168) au centre de l'emprise, 24 px par unité à l'échelle native (scale 1 : 2 × 2 cases = 64 px),
// sol transparent, boucle de 72 images à 12 i/s (la coulée dure 6 s), portrait 128 × 128 du HUD.
function exportSprite(i=0,frames=72,fps=12){configure(24,320,240,160,168);let S;try{const b=ITEMS[i].build();S=new Scene();S.bake(()=>-1,b.objs)}finally{configure(24,132,136,66,102)}
 const cols=12,rows=Math.ceil(frames/cols),sheet=document.createElement('canvas');sheet.width=320*cols;sheet.height=240*rows;const g=sheet.getContext('2d');let top=240,bot=0;
 for(let f=0;f<frames;f++){const t=f/fps,F=S.F;F.c.set(S.P.c);for(const d of S.dyn)d(F,t,S);const img=g.createImageData(320,240),D=img.data;
  for(let k=0;k<320*240;k++){const v=F.c[k],o=k*4;if(v>=0){D[o]=v>>16&255;D[o+1]=v>>8&255;D[o+2]=v&255;D[o+3]=255;const y=(k/320)|0;if(y<top)top=y;if(y>bot)bot=y}else if(S.sh[k]>0)D[o+3]=Math.round(S.sh[k]*95)}
  g.putImageData(img,(f%cols)*320,((f/cols)|0)*240)}
 const base=document.createElement('canvas');base.width=320;base.height=240;base.getContext('2d').drawImage(sheet,0,0,320,240,0,0,320,240);
 const bd=base.getContext('2d').getImageData(0,0,320,240).data;let x0=320,x1=0,y0=240,y1=0;for(let y=0;y<240;y++)for(let x=0;x<320;x++)if(bd[(y*320+x)*4+3]===255){if(x<x0)x0=x;if(x>x1)x1=x;if(y<y0)y0=y;if(y>y1)y1=y}
 const por=document.createElement('canvas');por.width=por.height=128;const pg=por.getContext('2d'),w=x1-x0+1,h=y1-y0+1,k=Math.min(1.5,120/w,124/h);pg.imageSmoothingEnabled=false;
 pg.drawImage(base,x0,y0,w,h,Math.round(64-w*k/2),Math.round(128-h*k),Math.round(w*k),Math.round(h*k));
 return{sheet,base,portrait:por,pick:ITEMS[i].name,meta:{anchor:[160,168],top,bottom:bot,scale:1,anim:{frame_w:320,frame_h:240,cols,rows,count:frames,seconds:frames/fps,fps,exact:true,seam_pixels:0}}}}
return{ITEMS,GROUPS,vignette,floorScene,ambient,exportSprite,get W(){return W},get H(){return H}}})();

