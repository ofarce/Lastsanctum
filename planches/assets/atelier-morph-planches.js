'use strict';
// Planche « Creuset des Exilés » : 5 propositions de bâtiment 2 × 2 cases.
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
function rp(R,v,x,y){const n=R.length-1,i=Math.round(v*n);return R[i<0?0:i>n?n:i]}

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
  for(let y=Math.max(0,this.by0-1);y<=Math.min(h-1,this.by1+1);y++)for(let x=Math.max(0,this.bx0-1);x<=Math.min(w-1,this.bx1+1);x++){const i=y*w+x;if(s[i]!==-1)continue;const nb=y<h-1&&s[i+w]!==-1?s[i+w]:x<w-1&&s[i+1]!==-1?s[i+1]:x>0&&s[i-1]!==-1?s[i-1]:y>0&&s[i-w]!==-1?s[i-w]:-1;if(nb!==-1)n[i]=sh(nb&0xffffff,-.68)}
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
 compose(t){const F=this.F,W=this.P.w,H=this.P.h;F.c.set(this.P.c);const D=this.D||(this.D=new Pix(W,H));D.c.fill(-1);D.bx0=W;D.by0=H;D.bx1=-1;D.by1=-1;for(const d of this.dyn)d(D,t,this);const s=D.c,o=new Int32Array(s),ok=i=>s[i]!==-1&&!(s[i]&0x1000000);for(let y=1;y<H-1;y++)for(let x=1;x<W-1;x++){const i=y*W+x;if(!ok(i))continue;let n=0;for(const k of[-W-1,-W,-W+1,-1,1,W-1,W,W+1])if(ok(i+k))n++;if(n<3)continue;for(const k of[-W,-1,1,W])if(s[i+k]===-1)o[i+k]=sh(s[i]&0xffffff,-.68)}for(let i=0;i<o.length;i++)if(o[i]!==-1)F.c[i]=o[i];return F}
 render(g,hour,t){const amb=ambient(hour),lum=.3*amb[0]+.59*amb[1]+.11*amb[2],night=Math.max(0,Math.min(1,(.9-lum)/.6)),day=Math.max(0,Math.min(1,(lum-.45)/.5)),[lr,lg,lb]=this.L,[ar,ag,ab]=this.A;
  const F=this.compose(t);
  lr.fill(0);lg.fill(0);lb.fill(0);ar.fill(0);ag.fill(0);ab.fill(0);
  if(night>.02)for(const L of this.lights){const add=L.add??(L.c===WHITEC?.2:L.c===VIOBLUE?.12:.04),fl=L.fl||0,I=L.i*night*(1+fl*(Math.sin(t*9.3+L.x)*.5+Math.sin(t*14.1+L.y*1.7)*.35)),R=L.r;
   for(let y=Math.max(0,Math.floor(L.y-R/1.3));y<=Math.min(H-1,L.y+R/1.3);y++)for(let x=Math.max(0,Math.floor(L.x-R));x<=Math.min(W-1,L.x+R);x++){const dx=x+.5-L.x,dy=(y+.5-L.y)*1.3,d=Math.sqrt(dx*dx+dy*dy)/R;if(d>=1)continue;let f=1-d;f=f*f*(3-2*f);const q=Math.floor(f*4+.5)/4;if(q<=0)continue;const i=y*W+x;lr[i]+=L.c[0]*I*q;lg[i]+=L.c[1]*I*q;lb[i]+=L.c[2]*I*q;if(add){const k=add*I*q*255;ar[i]+=L.c[0]*k;ag[i]+=L.c[1]*k;ab[i]+=L.c[2]*k}}}
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

// ================= BÂTIMENTS v3 : monuments et machines en plein air, finition 16 bits =================
// Assemblé par tools/batiments-16bits/build.py : moteur de creuset-planches.js + outils de batiments-v2-designs.js + ce fichier.
// K = 1 au travail, 0 au repos (réglé par la page via BAT.setWork).
let K=1;
const TAU=Math.PI*2,Eo=a=>a.map(E);
const FVB=Eo(['#34327a','#5a5cff','#9aa0ff','#e8ecff']),FOR=Eo(['#c23a08','#f2800e','#ffc83a','#fff6c0']),FGR=Eo(['#1c6a2e','#34a84a','#6ee07a','#d4ffd0']),FWH=Eo(['#8e8c98','#c8ccd8','#eef0f6','#ffffff']);
const INDC=R_(['#3a1606','#7a3008','#c25a12','#f08a2a','#ffc070']);
const SANDL=R_(['#6e5638','#8a6e48','#a68a5c','#c2a674','#d8c08e']);
const CLOTH=R_(['#7a6a50','#b8a684','#e2d6b4','#fffaea']);
const dyn=(key,f,lights)=>fx(key,()=>({dyn:f,lights:lights||[]}));
const LT=(x,y,z,r,i,c,fl)=>{const[a,b]=at(x,y,z);return{x:a,y:b,r,i,c,fl}};
const ease=p=>p*p*(3-2*p),clamp=(v,a=0,b=1)=>v<a?a:v>b?b:v;
// calque masqué : ce qui passe derrière un volume marqué « mask » n’est pas dessiné
const behind=(F,S)=>({set(x,y,c){const W=S.P.w,H=S.P.h;x=Math.round(x);y=Math.round(y);if(x<0||y<0||x>=W||y>=H||S.mask[y*W+x])return;F.set(x,y,c)},line(x0,y0,x1,y1,c){const n=Math.max(1,Math.ceil(Math.max(Math.abs(x1-x0),Math.abs(y1-y0))));for(let k=0;k<=n;k++)this.set(x0+(x1-x0)*k/n,y0+(y1-y0)*k/n,c)}});
function bigFlame(F,x,y,w,h,C,t,s=0){if(h<=0)return;for(let i=-w;i<=w;i++){const a=1-Math.pow(Math.abs(i)/(w+1),1.6),hh=Math.max(1,Math.round(h*a*(.6+.4*Math.sin(t*11+i*1.9+s*3))+(hash(i,Math.floor(t*12),s)>.7?1:0)));
 for(let j=0;j<hh;j++){const v=j/hh;F.set(x+i,y-j,C[v<.3&&Math.abs(i)<w?3:v<.6?2:v<.85?1:0])}}}
function sChest(F,x,y,R){for(let j=0;j<8;j++)for(let i=-4;i<=4;i++){const band=Math.abs(i)===3;F.set(x+i,y-7+j,band?IRON[j<3?5:3]:R[j===0?4:j<3?3:j===7?1:2])}F.set(x,y-4,SILVER[4])}
function sCrate(F,x,y,s=4){for(let j=0;j<2*s;j++)for(let i=-s;i<s;i++){const e=i===-s||i===s-1||j===2||j===2*s-1;F.set(x+i,y-2*s+1+j,j<2?WOOD[5]:e?WOOD[1]:(i+s===j-2||i+s===2*s+1-j)?WOOD[4]:WOOD[3])}}
const cargo=(F,x,y,k)=>k%3===0?sChest(F,x,y,BLUEC):k%3===1?sChest(F,x,y,REDC):sCrate(F,x,y);
const BOOKC=[BLUEC[2],REDC[2],VERDI[3],WOOD[3],SLATE[4]];
function sBook(F,x,y,c,fl){F.set(x,y,PARCH[1]);F.set(x,y+1,c);for(let i=1;i<=3;i++){const d=fl?Math.round(i*.8):-Math.round(i*.34);F.set(x-i,y-d,PARCH[4]);F.set(x+i,y-d,PARCH[4]);F.set(x-i,y-d+1,c);F.set(x+i,y-d+1,c)}}
function thick(F,x0,y0,x1,y1,a,b){F.line(x0,y0,x1,y1,a);F.line(x0,y0+1,x1,y1+1,b)}
function zz(F,x,y,t,C){for(let k=0;k<3;k++){const p=(((t*.2+k/3)%1)+1)%1,zx=Math.round(x+p*7+Math.sin(p*6)*2),zy=Math.round(y-p*16),s=k%2?4:5;if(p>.9)continue;for(let i=0;i<s;i++){F.set(zx+i,zy,C[3]);F.set(zx+i,zy+s-1,C[3]);F.set(zx+s-1-i,zy+i,C[3])}}}
function fireflies(F,t,n,s,cx,cy,rx,ry){for(let k=0;k<n;k++){const a=t*TAU/5*(1+k%2)+hash(k,s,2)*9;if(Math.sin(t*TAU*.6+k*2.1)>-.2)F.set(Math.round(cx+(hash(k,s,3)-.5)*2*rx+Math.sin(a)*5),Math.round(cy+(hash(k,s,4)-.5)*2*ry+Math.cos(a*1.3)*3),FGR[k%2?3:2])}}
function flag(F,x,y,w,h,R,t,dir=1){for(let i=0;i<w;i++){const a=t*TAU*.8-i*.9,dy=Math.round(Math.sin(a)*1.3*(i/w));for(let j=0;j<h-(i>w-4?i-w+4:0);j++)F.set(x+dir*i,y+dy+j,R[j===0?4:Math.cos(a)>0?3:2])}}
const oct=(R,h=.12,o={})=>slab(poly(8,1.32,Math.PI/8),0,h,stone(R,{noise:.08,...o}),{key:-9});
const disc=(R,r=1.28,h=.12,o={})=>slab(circle(r),0,h,stone(R,{noise:.08,...o}),{key:-9});
const mossy=o=>stone(MSTONE,{moss:.3,noise:.12,...o});
const sand=o=>stone(SAND,{courses:.2,joint:.55,noise:.1,...o});
const lac=o=>stone(INDC,{noise:.06,...o});

const GROUPS=[
 {id:'forge',name:'Forge',note:'Fer, basalte, flamme bleu-violet d’Aether ; seul le métal chauffé est orange. Des forges qui frappent, coulent et soufflent sans forgeron.'},
 {id:'workshop',name:'Atelier',note:'Bois, fer et mécanique d’Aether. Chaque piste est une machine à ciel ouvert, lisible de loin par son mouvement.'},
 {id:'library',name:'Bibliothèque',note:'Marbre veiné, parchemin, lumière blanche de Sigil. Les livres y circulent seuls.'},
 {id:'caserne',name:'Caserne',note:'Grès, laque orange et cuivre d’Indra. Feux, gongs, tambours et roues d’armes.'},
 {id:'bedroom',name:'Chambre à coucher',note:'Pierre moussue, feuillage et lueur verte de Medeina. Tout y bouge à la cadence d’un souffle.'},
 {id:'warehouse',name:'Entrepôt logistique',note:'Marbre de Sigil, coffres bleus et rouges du jeu. L’animation montre les marchandises qui circulent.'}];

const ITEMS=[
// ======================= FORGE =======================
 {g:'forge',name:'Enclume-monolithe',desc:'Une enclume géante taillée dans le basalte, sur un dais gravé. Le marteau lévite et frappe seul ; à chaque coup le cercle de glyphes s’allume.',anims:['marteau en lévitation','étincelles','cercle de glyphes','braseros'],
  build(){const[ax,ay]=at(-.08,1.08,.05);return{ground:floor(),objs:[oct(BASALT,.12,{inlay:ringI(1.04,.04,AEC[1])}),
   slab(rect(-.55,-.34,.55,.34),.12,.42,dMat(),{key:-2}),slab(rect(-.32,-.22,.32,.22),.42,.78,stone(BASALT,{noise:.08,inlay:vlineI(AEC[2],.03,.2,.8)}),{key:-1.9}),
   slab(rect(-.78,-.34,.62,.34),.78,1.08,iMat(),{key:-1.8}),slab(rect(-.2,-.16,.2,.16),.9,1.06,iMat(),{x:.82,key:-1.7,taper:[1,.5]}),
   brazier(-1.0,-.85,BASALT,'vb',VIOBLUE),brazier(1.0,-.85,BASALT,'vb',VIOBLUE),barrel(-.98,.82,WOOD,{water:1,h:.34}),
   dyn(5,(F,t,S)=>{const per=1.3,u=K?(t%per)/per:1,lift=K?(u<.72?Math.sin(u/.72*Math.PI/2):1-Math.min(1,(u-.72)/.1)):0,hy=ay-3-Math.round(lift*30),hit=K&&u>.82;
    for(let i=-7;i<=6;i++){F.set(ax+i,ay-2,MOLT[K?(hit?4:3):1]);F.set(ax+i,ay-1,MOLT[K?2:0])}
    for(const o of[0,1,2])F.line(ax+6,hy-7+o,ax+27,hy-15+o,WOOD[o===0?5:o===1?4:2]);for(let j=0;j<12;j++)for(let i=-9;i<=8;i++)F.set(ax+i,hy-12+j,IRON[j===0?6:i<-6?5:j===11?1:i>5?2:j<3?5:4]);for(let i=-9;i<=8;i++){F.set(ax+i,hy-7,AEC[K?2:0]);F.set(ax+i,hy-6,AEC[K?1:0])}
    if(hit){for(let k=0;k<120;k++){const a=k*TAU/120,[x,y]=at(Math.cos(a)*1.04,.12,Math.sin(a)*1.04);for(const d of[-1,0,1])if(S.P.get(x,y+d)===AEC[1])F.set(x,y+d,AEC[3])}}
    if(K)sparkC(ax,ay-3,['#f2800e','#ffc83a','#fff6c0'],10,3,15,13,per,.34)(F,t+per*.18)},[LT(-.08,1.2,.05,44,.8,HOT,.2)])]}}},
 {g:'forge',name:'Creuset suspendu',desc:'Deux pylônes de fer et une poutre portent un creuset au bout de ses chaînes, au-dessus d’une fosse de feu. Il se balance, bascule et verse dans le moule.',anims:['creuset qui se balance','coulée dans le moule','feu de la fosse','fumée'],
  build(){const[cx,cy]=at(0,2.28,-.3),[mx,my]=at(.78,.16,.85),[px,py]=at(0,.3,-.3);return{ground:floor(),objs:[slab(square(1.28),0,.1,stone(SLATE,{noise:.08}),{key:-9}),
   slab(circle(.56),.1,.3,dMat({inlay:q=>q.f==='top'&&q.rad<.42?rp(MOLT,.3+.4*(1-q.rad/.42),q.sx,q.sy):null}),{z:-.3,key:-3}),
   slab(square(.13),.1,2.3,iMat({inlay:vlineI(AEC[1],.025,.2,.85)}),{x:-1.02,z:-.3,key:-.4,taper:[1.3,.8]}),slab(square(.13),.1,2.3,iMat({inlay:vlineI(AEC[1],.025,.2,.85)}),{x:1.02,z:-.3,key:-.4,taper:[1.3,.8]}),
   box(0,-.3,1.16,.09,2.3,2.46,iMat(),{key:3}),moldTray(.78,.85),anvil(-.8,.85),
   dyn(4,(F,t)=>{bigFlame(F,px,py,7,K?13:4,FVB,t,1);const per=6,u=t%per,pour=K&&u>1.2&&u<3.8,sw=K?Math.sin(t*Math.PI)*(pour?.6:2.4):0,x=Math.round(cx+sw),y=cy+30,tilt=pour?3:0;
    F.line(cx-9,cy+4,x-7,y-9,IRON[2]);F.line(cx+9,cy+4,x+7,y-9+tilt,IRON[2]);
    for(let j=0;j<12;j++){const w=8-Math.round(j*.3);for(let i=-w;i<=w;i++)F.set(x+i,y-9+j+Math.round(tilt*(i/8+.5)*.6),j===0?IRON[6]:i<-w*.4?IRON[5]:i>w*.5?IRON[2]:IRON[4])}
    for(let i=-6;i<=6;i++)F.set(x+i,y-10+Math.round(tilt*(i/8+.5)*.6),MOLT[K?4:1]);for(let i=-8;i<=8;i++)F.set(x+i,y-5,AEC[K?2:0]);
    if(pour)pourDyn(x+8,y-8+tilt,mx,my,per,[1.2,3.8])(F,t);if(K)smokeDyn(cx,cy-4,22,6,3)(F,t*1.190476)},[LT(0,.6,-.3,50,.9,VIOBLUE,.2),LT(.78,.3,.85,26,.6,HOT)])]}}},
 {g:'forge',name:'Gueule de basalte',desc:'Une tête colossale des ruines tyriennes, reconvertie en four. Le feu d’Aether gronde dans la gueule, les yeux s’allument au rythme du tirage.',anims:['feu dans la gueule','yeux qui pulsent','braises','fumée du crâne'],
  build(){const face=frontI(q=>{const ax=Math.abs(q.x);if(q.y>1.05&&q.y<1.3&&ax>.28&&ax<.62)return AEC[1];if(q.y>1.3&&q.y<1.4&&ax>.2&&ax<.7)return rp(BASALT,.15,q.sx,q.sy);
    if(ax<.09&&q.y>.78&&q.y<1.2)return rp(BASALT,.85,q.sx,q.sy);const top=.72-.42+Math.sqrt(Math.max(0,.42*.42-q.x*q.x));if(ax<.42&&q.y<top)return q.y>top-.07||ax>.36?rp(BASALT,.9,q.sx,q.sy):(q.y<.2?rp(MOLT,.5,q.sx,q.sy):rp(DSTONE,.05,q.sx,q.sy));
    if(q.y<.75&&q.y>.6&&ax<.4&&((ax*T/3|0)&1))return rp(BASALT,.95,q.sx,q.sy);return null});
   const[fx_,fy]=at(0,.06,.62),[tx,ty]=at(0,1.9,-.2),[e1,ey]=at(-.45,1.18,.62),[e2]=at(.45,1.18,.62);return{ground:floor(),objs:[oct(BASALT,.1,{moss:.12}),
   slab(rect(-.95,-.6,.95,.6),.1,1.75,stone(BASALT,{courses:.3,joint:.7,noise:.12,moss:.1,inlay:face}),{key:-2,taper:[1,.9]}),
   slab(rect(-.8,-.5,.8,.5),1.75,1.9,stone(BASALT,{noise:.1}),{key:-1.5}),slab(rect(-.18,-.14,.18,.14),1.9,2.1,stone(BASALT),{x:-.5,key:-1.4}),slab(rect(-.18,-.14,.18,.14),1.9,2.1,stone(BASALT),{x:.5,key:-1.4}),slab(circle(.16),1.9,2.0,stone(DSTONE),{z:-.2,key:-1.3}),
   slab(rect(-.34,-.2,.34,.2),.1,.2,iMat(),{z:.95,key:1}),anvil(.92,1.0),crate(-.95,1.0,.15),
   dyn(4,(F,t)=>{const pu=K?.5+.5*Math.sin(t*4.4):0;bigFlame(F,fx_,fy,6,K?9+Math.round(pu*4):3,FVB,t,2);
    for(const ex of[e1,e2])for(let j=-2;j<=2;j++)for(let i=-3;i<=3;i++)F.set(ex+i,ey+j,AEC[K?(pu>.6?3:2):0]);
    if(K){motes(fx_,fy-4,7,26,['#c23a08','#f2800e','#ffc83a'],7,4)(F,t);smokeDyn(tx,ty-2,26,7,5)(F,t)}},[LT(0,.4,.7,52,.95,VIOBLUE,.2)])]}}},
 {g:'forge',name:'Anneau de forge',desc:'Un grand anneau de fer dressé, tendu d’une membrane de feu d’Aether. Les pièces brutes la traversent et ressortent trempées ; les glyphes du cercle tournent.',anims:['membrane de feu','lame qui traverse','glyphes en ronde','vapeur'],
  build(){const[cx,cy]=at(0,1.5,0),R=27;return{ground:floor(),objs:[oct(SLATE,.12),slab(rect(-.8,-.3,.8,.3),.12,.44,dMat({inlay:glyphLine()}),{key:-2}),
   {key:0,statue:true,draw(L){L.ell(cx,cy,R,R,(x,y,dx,dy)=>{const d=Math.hypot(dx,dy);if(d<.74)return null;const a=Math.atan2(dy,dx),seg=((a*8/Math.PI)%1+1)%1;return d>.94||d<.78?rp(IRON,.75-dx*.3-dy*.35,x,y):seg<.12?rp(IRON,.2,x,y):rp(IRON,.5-dx*.25-dy*.3,x,y)});return{}}},
   barrel(-1.0,.85,WOOD,{water:1,h:.36,r:.2}),anvil(.9,.9),
   dyn(4,(F,t)=>{const r=R*.74;for(let y=-r;y<=r;y++)for(let x=-r;x<=r;x++){if(x*x+y*y>r*r-6)continue;const n=vnoise(x*.2+Math.sin(t*.8)*2,y*.2-t*(K?1.6:.2),9)+.25*(1-Math.hypot(x,y)/r);F.set(cx+Math.round(x),cy+Math.round(y),K?FVB[n>.75?3:n>.55?2:n>.38?1:0]:(n>.8?FVB[1]:ci('#14123a')))}
    for(let k=0;k<16;k++){const a=k*Math.PI/8+Math.PI/16,on=K&&(k+Math.floor(t*6))%16<3;F.set(Math.round(cx+Math.cos(a)*R*.86),Math.round(cy+Math.sin(a)*R*.86),on?AEC[3]:AEC[0])}
    if(K){const u=(t%4)/4,y=cy+18-Math.round(u*40),hot=u<.5;if(u<.92)for(let j=0;j<14;j++){F.set(cx,y+j,hot?MOLT[4]:SILVER[4]);F.set(cx+1,y+j,hot?MOLT[2]:SILVER[2]);if(j>10)F.set(cx-1,y+j,WOOD[3]),F.set(cx+2,y+j,WOOD[2])}
     if(u>.5)steamDyn(cx,cy-R,14,2)(F,t)}},[LT(0,1.5,0,58,1,VIOBLUE,.15)])]}}},
 {g:'forge',name:'Colonne de coulée',desc:'Une haute cheminée conique entourée d’une rigole en spirale. Le métal en fusion y descend jusqu’au bassin de trempe, dans un nuage de vapeur.',anims:['coulée en spirale','vapeur du bassin','flammèche au sommet','fumée'],
  build(){const sp=(q)=>{if(q.f!=='side')return null;let a=q.ang+q.v*TAU*2.5;a=((a%TAU)+TAU)%TAU;return a<.5?rp(MOLT,.5,q.sx,q.sy):a<.62||a>TAU-.12?rp(DSTONE,.1,q.sx,q.sy):null};
   const[tx,ty]=at(0,2.7,0),[bx,by]=at(.62,.2,.95);return{ground:floor(),objs:[oct(BASALT,.1),slab(circle(.62),.1,.32,dMat(),{key:-3}),
   slab(circle(.5),.32,2.6,stone(DSTONE,{courses:.22,joint:.5,noise:.1,inlay:sp}),{key:-2,taper:[1,.6]}),slab(circle(.34),2.6,2.72,iMat(),{key:-1}),
   slab(circle(.4),0,.2,q=>q.f==='top'&&q.rad<.31?rp(WATER,.5+(vnoise(q.x*9,q.z*9,3)-.5),q.sx,q.sy):stone(DSTONE,{noise:.08})(q),{x:.62,z:.95,key:1}),
   slab(circle(.24),0,.18,stone(DSTONE,{noise:.3}),{x:-.9,z:.9,taper:[1,.4]}),anvil(-.3,1.05),
   dyn(4,(F,t)=>{bigFlame(F,tx,ty,3,K?8:2,FVB,t,3);if(!K)return;smokeDyn(tx,ty-8,24,6,2)(F,t);
    for(let k=0;k<26;k++){const v=((k/26)-t*.22)%1,vv=(v+1)%1,a=.25-vv*TAU*2.5,r=.5*(1-.4*vv)+.01;if(Math.sin(a)<.15)continue;const[x,y]=at(Math.cos(a)*r,.32+vv*2.28,Math.sin(a)*r);F.set(x,y,MOLT[4]);F.set(x+1,y,MOLT[3])}
    steamDyn(bx,by-2,20,7)(F,t);steamDyn(bx+3,by-4,16,8)(F,t);for(let i=-2;i<=2;i++)F.set(bx-6+i,by-1,MOLT[(i+Math.floor(t*8))%2?4:3])},[LT(0,1.4,.4,46,.8,HOT,.15),LT(0,2.8,0,30,.7,VIOBLUE,.2)])]}}},

// ======================= ATELIER =======================
 {g:'workshop',name:'Grand orrery d’atelier',desc:'Un mât central et trois bras qui tournent à des hauteurs différentes, chacun portant son outil. Les pièces passent d’un bras à l’autre.',anims:['trois bras tournants','engrenage de tête','lanterne d’Aether'],
  build(){const arms=[[1.2,.8,.55,0],[.98,1.3,-.8,2],[.72,1.8,1.2,4]];return{ground:floor(),objs:[oct(WOOD,.1,{}),slab(circle(.3),.1,.3,iMat(),{key:-3}),
   slab(circle(.1),.3,2.0,woodMat(WOOD),{key:-2,mask:true}),slab(circle(.16),2.0,2.1,iMat(),{key:-1}),
   box(-.85,.9,.36,.2,.1,.46,woodMat(WOOD,{along:'x'}),{key:.9}),crate(.9,.9,.16),planks(.2,1.08,3,.34),
   dyn(4,(F,t,S)=>{const B=behind(F,S);for(const[r,h,sp,k]of arms){const a=(K?t*sp:sp)+k,front=Math.sin(a)>0,D=front?F:B,[hx,hy]=at(0,h,0),[ex,ey]=at(Math.cos(a)*r,h,Math.sin(a)*r);
     D.line(hx,hy-1,ex,ey-1,WOOD[5]);D.line(hx,hy,ex,ey,WOOD[4]);D.line(hx,hy+1,ex,ey+1,WOOD[2]);D.line(ex,ey,ex,ey+6,IRON[4]);D.line(ex+1,ey,ex+1,ey+6,IRON[2]);
     if(k===0){for(let j=0;j<6;j++)for(let i=-5;i<=5;i++)D.set(ex+i,ey+6+j,IRON[j===0?6:i<-2?5:i>3?2:4])}else if(k===2){for(let i=-4;i<=4;i++){D.set(ex+i,ey+7,SILVER[4]);D.set(ex+i,ey+8,SILVER[(i+8)%2?2:4])}}else{for(let j=-3;j<=3;j++)for(let i=-3;i<=3;i++)if(i*i+j*j<11)D.set(ex+i,ey+9+j,AEC[i*i+j*j<3?3:i+j<0?2:1])}}
    const[gx,gy]=at(0,2.12,0);wheelDyn(gx,gy,8,6,K?1.2:0,IRON,{teeth:1})(F,t);F.set(gx,gy-1,AEC[3])},[LT(0,2.1,0,34,.7,VIOBLUE)])]}}},
 {g:'workshop',name:'Cabestan',desc:'Un grand treuil horizontal dont les barres tournent seules. Le câble passe par une chèvre et hisse la charge de madriers.',anims:['barres du cabestan','charge hissée','poulie'],
  build(){const[hx,hy]=at(1.0,2.0,-.75);return{ground:floor(),objs:[disc(WOOD,1.28,.08,{inlay:ringI(1.0,.05,WOOD[1])}),
   slab(circle(.3),.08,.92,woodMat(WOOD,{horiz:1,inlay:q=>q.f==='side'&&q.v>.2&&q.v<.55?rp(CANVAS,.5+((q.y*T|0)&1?.2:0),q.sx,q.sy):null}),{x:-.3,z:.2,key:0,mask:true}),slab(circle(.36),.92,1.0,iMat(),{x:-.3,z:.2,key:.1,mask:true}),
   post(1.0,-.75,2.05,WOOD,.07),box(.74,-.75,.36,.05,1.96,2.06,woodMat(WOOD,{along:'x'}),{key:2}),planks(.5,-.95,3,.3),
   dyn(4,(F,t,S)=>{const B=behind(F,S),a0=K?t*.9:.3,[cx,cy]=at(-.3,.66,.2);for(let k=0;k<4;k++){const a=a0+k*Math.PI/2,D=Math.sin(a)>0?F:B,[ex,ey]=at(-.3+Math.cos(a)*.98,.66,.2+Math.sin(a)*.98);D.line(cx,cy,ex,ey,WOOD[5]);D.line(cx,cy+1,ex,ey+1,WOOD[2]);D.set(ex,ey,IRON[5])}
    F.line(cx+6,cy+2,hx-14,hy+2,CANVAS[3]);wheelDyn(hx-14,hy+3,3,4,K?3:0,IRON)(F,t);hoistDyn(hx-14,hy+5,34,K?7:1e9,{sway:1.5,cargo:WOOD})(F,K?t:0)})]}}},
 {g:'workshop',name:'Bras d’assemblage',desc:'Une tourelle de fer et un bras articulé de bois. Il prend une caisse sur la pile, la pose sur l’établi, revient en chercher une autre.',anims:['bras articulé','caisse déplacée','cœur d’Aether'],
  build(){const[sx,sy]=at(-.2,1.15,-.35),[p1x,p1y]=at(-.85,.5,.75),[p2x,p2y]=at(.75,.62,.55),L1=34,L2=32;return{ground:floor(),objs:[oct(SLATE,.1),
   slab(circle(.36),.1,.38,iMat({inlay:cyLineA(.5)}),{x:-.2,z:-.35,key:-2}),slab(circle(.2),.38,.62,iMat(),{x:-.2,z:-.35,key:-1.9}),slab(circle(.1),.62,1.15,iMat({inlay:cyLineA(.5)}),{x:-.2,z:-.35,key:-1.8}),
   crate(-.98,.75,.17),crate(-.66,.82,.17),box(.75,.55,.45,.24,.1,.5,woodMat(WOOD,{along:'x'}),{key:.6}),
   slab(square(.04),.5,.9,woodMat(BARK),{x:.5,z:.5,key:.7,taper:[1,.3]}),slab(square(.04),.5,.9,woodMat(BARK),{x:.95,z:.5,key:.7,taper:[1,.3]}),
   dyn(4,(F,t)=>{const u=K?(t%5)/5:.05,ph=u<.4?ease(u/.4):u<.5?1:u<.9?1-ease((u-.5)/.4):0,dip=Math.sin(clamp(u<.5?u/.4:(u-.5)/.4)*Math.PI),tx=p1x+(p2x-p1x)*ph,ty=p1y+(p2y-p1y)*ph-dip*14;
    const dx=tx-sx,dy=ty-sy,d=Math.min(L1+L2-.5,Math.hypot(dx,dy)),a=Math.atan2(dy,dx),b=Math.acos(clamp((L1*L1+d*d-L2*L2)/(2*L1*d),-1,1)),ex=sx+Math.cos(a-b)*L1,ey=sy+Math.sin(a-b)*L1;
    for(const o of[-2,-1,0,1]){F.line(sx,sy+o,ex,ey+o,WOOD[o<-1?5:o<1?4:2]);F.line(ex,ey+o,tx,ty+o,WOOD[o<-1?5:o<1?4:2])}
    for(const[x,y]of[[sx,sy],[ex,ey]])for(let j=-2;j<=2;j++)for(let i=-2;i<=2;i++)if(Math.abs(i)+Math.abs(j)<4)F.set(Math.round(x)+i,Math.round(y)+j,i||j?IRON[4]:AEC[K?3:1]);
    const X=Math.round(tx),Y=Math.round(ty);F.line(X-4,Y,X+4,Y,IRON[5]);F.line(X-4,Y,X-4,Y+3,IRON[4]);F.line(X+4,Y,X+4,Y+3,IRON[4]);if(K&&u<.45)sCrate(F,X,Y+9,4)},[LT(-.2,.6,-.35,30,.6,VIOBLUE)])]}}},
 {g:'workshop',name:'Tour d’engrenages',desc:'Une horloge sans cadran : un grand panneau de bois couvert de roues dentées qui s’entraînent, un balancier en dessous, un petit toit dessus.',anims:['quatre engrenages','balancier','gemme d’Aether'],
  build(){const G=[[-.42,1.55,11,1],[.28,1.38,7,-1.57],[.5,.85,9,1.22],[-.25,.78,6,-1.83]];return{ground:floor(),objs:[oct(WOOD,.1),
   box(0,-.3,.95,.1,.1,2.15,woodMat(WOOD,{w:.2}),{key:-2}),post(-.95,-.22,2.2,BARK,.08),post(.95,-.22,2.2,BARK,.08),
   roof('gx',0,-.3,1.15,.4,2.15,.36,shingle(SLATE,{cw:.12}),{key:3,noShadow:1}),crate(-.9,.85,.16),barrel(.92,.85,WOOD,{h:.36}),
   dyn(4,(F,t)=>{for(const[x,y,r,s]of G){const[a,b]=at(x,y,-.19);wheelDyn(a,b,r,r>8?8:6,K?s:0,r>8?WOOD:IRON,{teeth:1,thick:1})(F,t)}
    const[px,py]=at(0,.62,-.19),an=K?Math.sin(t*3)*.5:0,bx=px+Math.sin(an)*14,by=py+Math.cos(an)*14;F.line(px,py,bx,by,IRON[4]);for(let j=-2;j<=2;j++)for(let i=-2;i<=2;i++)if(i*i+j*j<6)F.set(Math.round(bx)+i,Math.round(by)+j,IRON[i+j<0?6:3]);
    const[gx,gy]=at(.02,1.12,-.19);for(let j=-1;j<=1;j++)for(let i=-1;i<=1;i++)F.set(gx+i,gy+j,AEC[K?(i||j?2:3):1])},[LT(0,1.1,-.1,36,.6,VIOBLUE)])]}}},
 {g:'workshop',name:'Table d’énonciation',desc:'Une table de pierre gravée, héritée des ruines. Les madriers et les pieux se soulèvent, s’assemblent en l’air en barricade, puis l’ouvrage se dépose.',anims:['pièces qui s’assemblent','éclat d’Aether','glyphes de la table'],
  build(){const P=[[-9,0,1.57],[-3,0,1.57],[3,0,1.57],[9,0,1.57],[0,2,0]],[cx,cy]=at(0,1.45,0);return{ground:floor(),objs:[oct(SLATE,.1,{inlay:ringI(1.05,.035,AEC[0])}),
   slab(rect(-.9,-.5,.9,.5),.1,.5,stone(BASALT,{noise:.1,inlay:bandI(.35,.7,AEC[1],.16,5)}),{key:-2}),slab(rect(-.98,-.56,.98,.56),.5,.6,stone(BASALT,{noise:.06,inlay:ringI(.36,.03,AEC[1])}),{key:-1.9}),
   planks(-.85,1.05,3,.3),crate(.92,1.0,.15),
   dyn(4,(F,t)=>{morphDraw(F,t,cx,cy)},[LT(0,.9,0,44,.7,VIOBLUE,.1)])]}}},

// ======================= BIBLIOTHÈQUE =======================
 {g:'library',name:'Obélisque aux livres',desc:'Un obélisque de marbre gravé sur deux marches rondes. Les livres tournent autour de lui en hélice, pages battantes, et viennent s’y ranger au repos.',anims:['livres en orbite','pages qui battent','pyramidion lumineux'],
  build(){return{ground:floor(),objs:[disc(MARBLE,1.28,.12),slab(circle(.95),.12,.24,mMat(),{key:-8}),
   slab(square(.24),.24,2.5,mMat({inlay:vlineI(WHC[2],.035,.12,.92)}),{key:-2,taper:[1,.55],mask:true}),slab(square(.135),2.5,2.78,stone(QZ,{noise:.04}),{key:-1,taper:[1,0],mask:true}),
   column(-.98,.82,.5,MARBLE,{flame:'white',light:WHITEC}),column(.98,.82,.5,MARBLE,{flame:'white',light:WHITEC}),
   dyn(4,(F,t,S)=>{const B=behind(F,S);for(let k=0;k<7;k++){const a=(K?t*.7:0)+k*TAU/7,y=K?1.0+.55*Math.sin(a*.5+k)+k*.08:.3,r=K?.82:.72,[x,yy]=at(Math.cos(a)*r,y,Math.sin(a)*r);sBook(Math.sin(a)>0?F:B,x,yy,BOOKC[k%5],K&&Math.floor(t*7+k)%2)}
    const[px,py]=at(0,2.6,0);if(K)motes(px,py,5,18,['#a8b0c4','#dfe4f0','#ffffff'],5,3)(F,t)},[LT(0,2.6,0,48,.9,WHITEC)])]}}},
 {g:'library',name:'Arche des feuillets',desc:'Une arche isolée, comme une porte sans mur. Entre ses piliers les feuillets remontent en rideau, du pupitre vers le fronton.',anims:['rideau de feuillets','lueur du passage','veilleuses'],
  build(){const[cx,cy]=at(0,.15,.05);return{ground:floor(),objs:[slab(rect(-1.28,-.9,1.28,1.1),0,.12,stone(MARBLE,{noise:.06}),{key:-9}),slab(rect(-1.05,-.2,1.05,.75),.12,.2,stone(MARBLE,{noise:.05}),{key:-8}),
   box(-.82,0,.22,.3,.12,1.9,mMat({inlay:bandI(.2,.8,WHC[1],.2,4)}),{key:-1}),box(.82,0,.22,.3,.12,1.9,mMat({inlay:bandI(.2,.8,WHC[1],.2,6)}),{key:-1}),
   box(0,0,1.12,.34,1.9,2.14,mMat(),{key:5}),roof('gz',0,0,1.2,.4,2.14,.4,shingle(SLATE,{axis:'z',cw:.12,side:q=>rp(MARBLE,.75+(q.lip?.15:0),q.sx,q.sy)}),{key:6,noShadow:1}),
   lectern(0,.95),column(-1.05,.95,.4,MARBLE,{flame:'white',light:WHITEC}),column(1.05,.95,.4,MARBLE,{flame:'white',light:WHITEC}),
   dyn(4,(F,t)=>{const n=K?16:5;for(let k=0;k<n;k++){const p=K?((t*.3*(.7+.6*hash(k,3,2))+hash(k,1,2))%1):hash(k,1,2)*.06,x=Math.round(cx+(hash(k,2,2)-.5)*26+Math.sin(t*1.7+k*2)*2),y=Math.round(cy-p*42),fl=Math.floor(t*6+k)%3,C_=p>.85?PARCH[2]:PARCH[4];
     if(fl===0){F.set(x-1,y,C_);F.set(x,y,C_);F.set(x+1,y,C_)}else if(fl===1){F.set(x-1,y-1,C_);F.set(x,y,C_);F.set(x+1,y-1,C_)}else{F.set(x,y,C_);F.set(x,y-1,C_)}}
    if(K)for(let j=0;j<40;j++)if(hash(j,Math.floor(t*5),8)>.6)F.set(cx+((j*7)%25)-12,cy-j,WHC[1])},[LT(0,1.0,.1,50,.8,WHITEC)])]}}},
 {g:'library',name:'Cercle des stèles',desc:'Cinq stèles gravées en demi-cercle. Leurs inscriptions s’éclairent l’une après l’autre et un trait de lumière les relie au grand livre qui flotte au centre.',anims:['stèles en séquence','trait de lumière','livre flottant'],
  build(){const A=[200,235,270,305,340].map(d=>d*Math.PI/180),st=A.map((a,k)=>[Math.cos(a)*1.02,Math.sin(a)*1.02+.25,1.3+(k===2?.35:k%2?.15:0)]);return{ground:floor(),objs:[disc(MARBLE,1.3,.1,{inlay:anyI(ringI(.6,.03,WHC[0]),ringI(1.12,.03,WHC[0]))}),
   ...st.map(([x,z,h],k)=>slab(rect(-.17,-.07,.17,.07),.1,h,mMat({inlay:frontI(q=>q.y>.4&&q.y<h-.2&&Math.abs(q.x)<.1&&((q.y*T/3|0)&1)&&hash(q.x*T|0,q.y*T/3|0,k)>.3?rp(MARBLE,.2,q.sx,q.sy):null)}),{x,z,key:z,taper:[1,.85]})),
   slab(circle(.2),.1,.36,mMat(),{z:.35,key:.3}),
   dyn(4,(F,t)=>{const act=K?Math.floor(t*.8)%5:-1,bob=K?Math.round(Math.sin(t*1.6)*1.5):0,[bx,by0]=at(0,K?1.05:.4,.35),by=by0+bob;
    st.forEach(([x,z,h],k)=>{if(k!==act)return;for(let r=0;r<Math.floor((h-.6)*T/3);r++)if(r&1)for(let i=-2;i<=2;i++)if(hash(i,r,k)>.3){const[a,b]=at(x+i/T,.4+r*3/T,z+.07);F.set(a,b,WHC[3])}
     const[sx,sy]=at(x,h*.7,z+.07);for(let s=0;s<=10;s++)if((s+Math.floor(t*10))%2)F.set(Math.round(sx+(bx-sx)*s/10),Math.round(sy+(by-sy)*s/10),WHC[2])});
    for(let i=-6;i<=6;i++)for(let j=-2;j<=1;j++)if(i)F.set(bx+i,by+j-Math.round(Math.abs(i)*.25),PARCH[4-(j+2>2?1:0)]);F.set(bx,by-1,PARCH[1]);F.set(bx,by,PARCH[1]);for(let i=-6;i<=6;i++)F.set(bx+i,by+2-Math.round(Math.abs(i)*.25),BLUEC[2]);
    if(K&&(t*.8)%1<.3){const w=Math.round(Math.cos((t*.8)%1/.3*Math.PI)*5);for(let j=0;j<4;j++)F.set(bx+w,by-2-j,PARCH[4])}},[LT(0,1.0,.35,46,.8,WHITEC)])]}}},
 {g:'library',name:'Arbre à rouleaux',desc:'Un arbre pétrifié, veiné de quartz comme ceux du bosquet. On y a pendu les rouleaux : ils se balancent, se déroulent pour la lecture puis se referment.',anims:['rouleaux suspendus','rouleau qui se déroule','feuilles de quartz'],
  build(){const br=[[-1.0,2.0,-.1],[-.55,2.45,-.3],[.1,2.6,.1],[.65,2.35,-.2],[1.05,1.9,.1],[-.4,1.75,.4],[.5,1.7,.45]],[tx,ty]=at(0,1.3,0);return{ground:floor(),objs:[disc(MARBLE,1.28,.1),
   slab(ringShape(.86,1.08),.1,.3,mMat(),{key:-5}),slab(poly(7,.26,.2),.1,1.3,stone(QZ,{veins:1,noise:.14}),{key:-2,taper:[1.35,.7],mask:true}),
   {key:1,draw(L){for(const[x,y,z]of br){const[a,b]=at(x,y,z),mx=(tx+a)/2,my=Math.min(ty,b)-4;for(const o of[0,1]){L.line(tx+o,ty,mx+o,my,QZ[o?1:3]);L.line(mx+o,my,a+o,b,QZ[o?1:3])}for(let k=0;k<5;k++)L.set(a+((k*5)%7)-3,b-1-(k%3),k%2?WHC[2]:QZ[4])}return{}}},
   lectern(.85,.75),
   dyn(4,(F,t)=>{br.forEach(([x,y,z],k)=>{const[a,b]=at(x,y,z),sw=K?Math.round(Math.sin(t*1.6+k*1.3)*1.6):0,len=5+k%3*2,open=K&&Math.floor(t*.35+k*.37)%7===k?Math.round(Math.sin(((t*.35+k*.37)%1)*Math.PI)*9):0,X=a+sw,Y=b+len;
     F.line(a,b,X,Y,CANVAS[1]);for(let i=-3;i<=3;i++){F.set(X+i,Y,WOOD[4]);F.set(X+i,Y+1,PARCH[4]);F.set(X+i,Y+2,PARCH[3])}for(let j=0;j<open;j++)for(let i=-2;i<=2;i++)F.set(X+i,Y+3+j,j%2&&Math.abs(i)<2?PARCH[2]:PARCH[4]);if(open)for(let i=-3;i<=3;i++)F.set(X+i,Y+3+open,WOOD[3])});
    if(K)for(let k=0;k<4;k++){const p=(t*.14+hash(k,1,6))%1;F.set(Math.round(tx+(hash(k,2,6)-.5)*50+Math.sin(p*9+k)*4),Math.round(ty-28+p*52),k%2?WHC[2]:QZ[4])}},[LT(0,2.0,0,50,.6,WHITEC)])]}}},
 {g:'library',name:'Puits de lecture',desc:'Une margelle ronde garnie de livres, un sol sombre gravé en spirale. Une colonne de lumière en monte ; les livres s’y élèvent et redescendent.',anims:['colonne de lumière','livres qui montent','quatre veilleuses'],
  build(){const[cx,cy]=at(0,.1,0);return{ground:floor(),objs:[disc(MARBLE,1.3,.08),
   slab(circle(.84),.08,.1,q=>q.f==='top'?(spiralI(.1,.8,2.2,.2,WHC[0])(q)??rp(DSTONE,.2+(q.rad>.7?.2:0),q.sx,q.sy)):rp(DSTONE,.3,q.sx,q.sy),{key:-8}),
   slab(ringShape(.84,1.06),.08,.56,mMat({inlay:q=>q.f==='side'&&q.rad>.95&&q.n[1]>.25&&q.v>.15&&q.v<.85?(q.v>.46&&q.v<.54?rp(WOOD,.5,q.sx,q.sy):SPINE[Math.floor(hash(q.sx,q.v>.5?1:0,4)*SPINE.length)]):null}),{key:-3}),
   ...[[-.95,-.95],[.95,-.95],[-.95,.95],[.95,.95]].map(([x,z])=>column(x,z,.75,MARBLE,{flame:'white',light:WHITEC})),
   dyn(4,(F,t)=>{for(let j=0;j<78;j++)for(let i=-7;i<=7;i++)if(hash(i,j-Math.floor(t*(K?14:2)),3)>(K?.82:.95)&&Math.abs(i)<7-j*.03)F.set(cx+i,cy-j,WHC[Math.abs(i)<3?2:1]);
    if(K)for(let k=0;k<5;k++){const up=k%2===0,p=(t*.2+k/5)%1,y=cy-6-(up?p:1-p)*64,x=cx+(k-2)*3+Math.round(Math.sin(t*TAU*.4+k)*1.5);sBook(F,x,Math.round(y),BOOKC[k],Math.floor(t*6+k)%2)}},[LT(0,1.2,0,56,.95,WHITEC)])]}}},

// ======================= CASERNE =======================
 {g:'caserne',name:'Roue d’armes',desc:'L’esprit d’Indra est une roue : la caserne aussi. Un râtelier horizontal tourne lentement autour de son mât et présente lames, lances et écus.',anims:['râtelier tournant','armes qui pendent','feu du moyeu'],
  build(){return{ground:floor(),objs:[oct(SAND,.12,{inlay:ringI(1.05,.04,INDC[2])}),slab(circle(.34),.12,.3,sand(),{key:-3}),
   slab(circle(.1),.3,1.25,lac(),{key:-2,mask:true}),fireBowl(0,0,1.3),
   brazier(-1.02,.9,SAND,'orange',ORANGE),brazier(1.02,.9,SAND,'orange',ORANGE),
   dyn(4,(F,t,S)=>{const B=behind(F,S),a0=K?t*.45:.2,[hx,hy]=at(0,1.2,0);for(let k=0;k<8;k++){const a=a0+k*Math.PI/4,D=Math.sin(a)>-.1?F:B,[ex,ey]=at(Math.cos(a)*1.0,1.2,Math.sin(a)*1.0);D.line(hx,hy,ex,ey,INDC[3]);D.line(hx,hy+1,ex,ey+1,INDC[1])}
    for(let k=0;k<96;k++){const a=k*TAU/96,[x,y]=at(Math.cos(a)*1.0,1.2,Math.sin(a)*1.0),D=Math.sin(a)>-.1?F:B;D.set(x,y,INDC[Math.sin(a)<0?4:3]);D.set(x,y+1,INDC[2]);D.set(x,y+2,INDC[1])}
    const order=[...Array(8).keys()].sort((p,q)=>Math.sin(a0+p*Math.PI/4)-Math.sin(a0+q*Math.PI/4));for(const k of order){const a=a0+k*Math.PI/4,D=Math.sin(a)>-.1?F:B,[x,y]=at(Math.cos(a)*1.0,1.2,Math.sin(a)*1.0),sw=K?Math.round(Math.sin(t*2+k)*.7):0;
     if(k%3===0){for(let j=3;j<14;j++){D.set(x+sw*(j>8?1:0),y+j,SILVER[4]);D.set(x+1+sw*(j>8?1:0),y+j,SILVER[2])}for(let i=-2;i<=3;i++)D.set(x+i,y+5,WOOD[3])}
     else if(k%3===1){for(let j=3;j<17;j++)D.set(x+sw*(j>9?1:0),y+j,WOOD[4]);D.set(x+sw,y+17,SILVER[4]);D.set(x+sw,y+18,SILVER[3])}
     else for(let j=-4;j<=4;j++)for(let i=-3;i<=3;i++)if(i*i+j*j*.6<11)D.set(x+i+sw,y+8+j,i*i+j*j<2?IRON[5]:INDC[i+j<-1?4:i+j>2?2:3])}})]}}},
 {g:'caserne',name:'Arène de sable',desc:'Un muret de grès en anneau, du sable ratissé, des fanions d’Indra. La quintaine tourne sous les coups et la poussière se lève.',anims:['quintaine','poussière','fanions','braseros'],
  build(){const[qx,qy]=at(.42,.95,.1);return{ground:floor(),objs:[slab(circle(1.06),0,.05,stone(SANDL,{noise:.2,pave:q=>Math.abs(q.rad%.24-.12)<.02?.1:0}),{key:-9}),
   slab(ringShape(1.06,1.3),0,.3,sand({trim:{R:INDC,v0:.72,v1:1}}),{key:-8}),{key:.05,draw(L,S){const[a,b]=at(-.48,0,.05);S.shadowEll(a+4,b+1,8,3,.7);L.rect(a,b-24,2,25,BARK[3]);L.rect(a-8,b-19,18,2,BARK[4]);L.ell(a+1,b-14,5,7,(x,y,dx,dy)=>rp(SAND,.7-dx*.25-dy*.2+((x+y)%3?0:-.15),x,y));L.ell(a+1,b-25,3.4,3.4,(x,y,dx,dy)=>rp(SAND,.75-dx*.3-dy*.3,x,y));L.rect(a-3,b-17,8,2,INDC[2]);return{}}},post(.42,.1,.95,BARK,.05),rack(0,-.8,4),
   brazier(-.98,.98,SAND,'orange',ORANGE),brazier(.98,.98,SAND,'orange',ORANGE),post(-1.1,-.7,1.7,BARK,.04),post(1.1,-.7,1.7,BARK,.04),
   dyn(4,(F,t)=>{const c=(t*.4)%1,sp=K?(c<.7?Math.pow(1-c/.7,2)*14:0):0,a=sp+.5,hx=Math.cos(a)*11,hz=Math.sin(a)*3;thick(F,qx-hx,qy-hz,qx+hx,qy+hz,WOOD[5],WOOD[2]);
    for(let j=-3;j<=3;j++)for(let i=-3;i<=3;i++)if(i*i+j*j<11)F.set(Math.round(qx+hx)+i,Math.round(qy+hz)+j+1,INDC[i+j<-1?4:i+j>2?2:3]);for(let j=0;j<6;j++)for(let i=-2;i<=2;i++)F.set(Math.round(qx-hx)+i,Math.round(qy-hz)+2+j,CANVAS[i<0?3:1]);
    if(K&&c<.3)dustDyn(qx,qy+22,8,3)(F,c*3);for(const s of[-1,1]){const[fx_,fy]=at(s*1.1,1.7,-.7);flag(F,fx_+1,fy+1,11,6,INDC,t*s,1)}})]}}},
 {g:'caserne',name:'Portique du gong',desc:'Un portique laqué d’orange, à double linteau. Le bélier frappe le grand gong de cuivre qui appelle les recrues ; l’onde court sur le dallage.',anims:['bélier','gong qui vibre','onde sonore','lanternes'],
  build(){const[gx,gy]=at(0,1.05,-.2);return{ground:floor(),objs:[slab(rect(-1.3,-.9,1.3,1.1),0,.12,sand(),{key:-9}),
   slab(circle(.12),.12,2.1,lac(),{x:-.9,z:-.2,key:-.3,taper:[1.1,.9]}),slab(circle(.12),.12,2.1,lac(),{x:.9,z:-.2,key:-.3,taper:[1.1,.9]}),
   box(0,-.2,1.3,.12,2.1,2.26,lac(),{key:3}),box(0,-.2,1.08,.07,1.78,1.88,lac(),{key:2.5}),box(0,-.2,1.36,.16,2.26,2.34,stone(SLATE),{key:3.5}),
   column(-1.0,.9,.5,SAND,{flame:'orange',light:ORANGE}),column(1.0,.9,.5,SAND,{flame:'orange',light:ORANGE}),
   dyn(1,(F,t)=>{const per=2.4,u=K?(t%per)/per:.5,hit=K&&u<.12,sh=hit?Math.round(Math.sin(u*90)*1.5):0,X=gx+sh;F.line(gx-6,gy-20,X-6,gy-10,IRON[3]);F.line(gx+6,gy-20,X+6,gy-10,IRON[3]);
    for(let j=-11;j<=11;j++)for(let i=-11;i<=11;i++){const d=Math.hypot(i,j);if(d>11.3)continue;F.set(X+i,gy+j,d>9.5?COPPER[i+j<0?5:2]:d<3?COPPER[i+j<0?5:3]:COPPER[Math.abs(d-6.5)<.7?2:i+j<-4?4:3])}
    const sw=K?(u>.6?-(u-.6)/.4*10:u<.12?-10+u/.12*10:0):-4,rx=gx+15-Math.round(sw);F.line(gx+17,gy-22,rx+7,gy,CANVAS[1]);for(let j=-2;j<=1;j++)for(let i=0;i<14;i++)F.set(rx+i,gy+j,i<2?IRON[4]:WOOD[j<0?5:3]);
    if(K&&u<.6){const[ox,oy]=at(0,.12,.3),r=8+u/.6*26;for(let k=0;k<48;k++)if(k%2){const a=k*TAU/48;F.set(Math.round(ox+Math.cos(a)*r),Math.round(oy+Math.sin(a)*r),INDC[u<.3?4:3])}}})]}}},
 {g:'caserne',name:'Foyer des guerriers',desc:'Pas de murs : un grand feu dans son cercle de grès, les écus et les faisceaux de lances autour, des bancs de pierre. Le feu monte quand on forme une recrue.',anims:['grand feu','braises','fumée','écus dressés'],
  build(){const[fx_,fy]=at(0,.34,.05);return{ground:floor(),objs:[disc(SAND,1.3,.08,{inlay:ringI(.95,.04,INDC[1])}),slab(ringShape(.36,.6),.08,.34,sand(),{key:-3}),
   slab(circle(.36),.08,.2,q=>q.f==='top'?rp(MOLT,.2+.5*(1-q.rad/.36)+(hash(q.sx,q.sy,4)-.5)*.3,q.sx,q.sy):rp(DSTONE,.3,q.sx,q.sy),{key:-2.9}),
   shieldStand(-.95,-.5),shieldStand(.95,-.5),shieldStand(-.5,-1.0),shieldStand(.5,-1.0),rack(-.95,.75,2),
   slab(rect(-.3,-.1,.3,.1),.08,.26,sand(),{x:.8,z:.9,key:.9}),slab(rect(-.3,-.1,.3,.1),.08,.26,sand(),{x:0,z:1.12,key:1.1}),
   dyn(4,(F,t)=>{bigFlame(F,fx_,fy,7,K?24:7,FOR,t,1);bigFlame(F,fx_-3,fy,3,K?12:3,FOR,t,5);if(K){motes(fx_,fy-18,10,30,['#c23a08','#f2800e','#ffc83a'],9,6)(F,t);smokeDyn(fx_,fy-26,26,6,4)(F,t)}},[LT(0,.9,.05,70,1.1,ORANGE,.22)])]}}},
 {g:'caserne',name:'Tour-tambour',desc:'Une tour trapue de grès coiffée d’un tambour de guerre géant. Deux mailloches le battent en alternance ; on l’entend de toute la caverne.',anims:['mailloches','peau qui vibre','fanions'],
  build(){const[dx,dy]=at(0,1.72,0);return{ground:floor(),objs:[oct(SAND,.1),
   slab(circle(.86),.1,1.15,sand({trim:{R:INDC,v0:.86,v1:1},inlay:archI(0,.2,.1,.72,doorFill())}),{key:-3,taper:[1,.88]}),slab(ringShape(.6,.8),1.15,1.3,sand(),{key:-2}),
   slab(circle(.52),1.15,1.72,stone(INDC,{noise:.05,inlay:lacingI(BONE[3])}),{key:-1,taper:[.9,1]}),slab(circle(.52),1.72,1.74,q=>rp(BONE,q.f==='top'?(q.rim?.4:.8):.5,q.sx,q.sy),{key:-.9}),
   post(-.98,-.5,2.1,BARK,.04),post(.98,-.5,2.1,BARK,.04),brazier(-.98,.95,SAND,'orange',ORANGE),brazier(.98,.95,SAND,'orange',ORANGE),
   dyn(4,(F,t)=>{const per=.8,b=K?Math.floor(t/per)%2:0,u=K?(t%per)/per:1;for(const s of[-1,1]){const act=K&&(s<0?b===0:b===1),lift=act?(u<.25?1-u/.25:Math.min(1,(u-.25)/.75)):(K?1:.3),px=dx+s*22,py=dy-12,ex=dx+s*5,ey=dy-2-lift*15;thick(F,px,py,ex,ey,WOOD[5],WOOD[2]);for(let j=-2;j<=2;j++)for(let i=-2;i<=2;i++)if(i*i+j*j<6)F.set(Math.round(ex)+i,Math.round(ey)+j,CANVAS[i+j<0?4:2])}
    if(K&&u<.2)for(let k=0;k<40;k++){const a=k*TAU/40,r=5+u*40;F.set(Math.round(dx+Math.cos(a)*r),Math.round(dy+Math.sin(a)*r*.98),BONE[4])}
    for(const s of[-1,1]){const[fx_,fy]=at(s*.98,2.1,-.5);flag(F,fx_+1,fy+1,10,6,INDC,t,1)}})]}}},

// ======================= CHAMBRE =======================
 {g:'bedroom',name:'Fleur-dortoir',desc:'Un bouton de fleur géant posé sur un socle moussu. Quand on y dort, les pétales se referment et l’ensemble respire ; il se rouvre au réveil.',anims:['pétales qui respirent','lueur du cœur','lucioles'],
  build(){const[cx,cy]=at(0,.3,0);return{ground:floor(),objs:[oct(MSTONE,.1,{moss:.4}),slab(poly(6,.7),.1,.3,mossy(),{key:-3}),bush(-1.0,.8,3),bush(1.02,.7,8),bush(.9,-.9,5),
   dyn(4,(F,t)=>{const o=K?.22+.1*(.5+.5*Math.sin(t*1.25)):1,N=7,pet=(k,front)=>{const a=k*TAU/N+.2,sx=Math.cos(a),sz=Math.sin(a);if((sz>0)!==front)return;const reach=8+o*22,rise=34*(1-o)+8,tipx=cx+sx*reach,tipy=cy+sz*reach*.55-rise,bx=cx+sx*5,by=cy+sz*3;
      for(let s=0;s<=1;s+=.04){const w=Math.sin(s*Math.PI)*9+1,px=bx+(tipx-bx)*s,py=by+(tipy-by)*s-Math.sin(s*Math.PI)*4*(1-o);for(let i=-w;i<=w;i++){const X=px-sz*i*.9,Y=py+sx*i*.55+(front?0:-1);F.set(X,Y,LEAF[Math.abs(i)>w-1.2?2:i*sx<0===(sx>0)?(front?6:4):(front?5:3)])}}
      F.set(tipx,tipy,LEAF[7])};
    for(let k=0;k<N;k++)pet(k,false);for(let j=-6;j<=3;j++)for(let i=-6;i<=6;i++)if(i*i+j*j*1.6<36)F.set(cx+i,cy-4+j,FGR[i*i+j*j<8?3:i*i+j*j<20?2:1]);for(let k=0;k<N;k++)pet(k,true);
    fireflies(F,t,K?6:3,2,cx,cy-10,34,22);if(K)zz(F,cx+8,cy-28,t,FGR)},[LT(0,.6,0,46,.8,GREEN)])]}}},
 {g:'bedroom',name:'Cercle des hamacs',desc:'Quatre pieux sculptés, trois hamacs tendus entre eux, une flamme verte de Medeina au milieu. Les hamacs se balancent quand ils sont occupés.',anims:['hamacs qui se balancent','« z » du sommeil','flamme verte'],
  build(){const P=[[-1.0,-.75],[1.0,-.75],[-1.0,.85],[1.0,.85]],H_=[[0,1],[0,2],[1,3]];return{ground:floor(),objs:[disc(MSTONE,1.3,.08,{moss:.35}),
   ...P.map(([x,z])=>slab(poly(6,.09),.08,1.25,woodMat(BARK,{inlay:vlineI(FGR[1],.02,.5,.8)}),{x,z,key:z,taper:[1.2,.8]})),
   slab(circle(.22),.08,.22,mossy(),{z:.1,key:.1}),slab(circle(.13),.22,.36,mossy(),{z:.1,key:.11}),bush(0,-1.05,4,1),
   dyn(4,(F,t)=>{const[fx_,fy]=at(0,.36,.1);bigFlame(F,fx_,fy,2,6,FGR,t,2);H_.forEach(([a,b],k)=>{const[x0,y0]=at(P[a][0],1.1,P[a][1]),[x1,y1]=at(P[b][0],1.1,P[b][1]),sw=K?Math.sin(t*1.5+k*1.7)*2.5:0,n=Math.ceil(Math.hypot(x1-x0,y1-y0));
     for(let i=0;i<=n;i++){const u=i/n,sag=4*u*(1-u),x=x0+(x1-x0)*u+sw*sag*(k?1:0),y=y0+(y1-y0)*u+sag*(k?7:9)+(k?0:sw*sag*.5);for(let j=0;j<3;j++)F.set(x+(k?j:0),y+(k?0:j),k===1?CLOTH[j===0?3:i%4===0?0:2]:LEAF[j===0?7:i%4===0?3:5])}
     if(K){const mx=(x0+x1)/2+(k?sw:0),my=(y0+y1)/2+(k?7:9);for(let j=-1;j<=1;j++)for(let i=-2;i<=2;i++)F.set(mx+(k?j:i)+1,my+(k?i:j),SANDL[2+(j<0?1:0)]);zz(F,Math.round(mx)+4,Math.round(my)-4,t+k*1.3,FGR)}})},[LT(0,.5,.1,40,.75,GREEN,.15)])]}}},
 {g:'bedroom',name:'Tertre aux alcôves',desc:'Un tertre de pierre et de mousse percé de trois niches encadrées de racines. Chacune s’éclaire doucement, à son tour, comme trois dormeurs qui respirent.',anims:['alcôves qui respirent','lucioles','champignons-veilleuses'],
  build(){const AL=[Math.PI/2,Math.PI/2-.95,Math.PI/2+.95];const alc=q=>{if(q.f!=='side')return null;for(const a0 of AL){let d=q.ang-a0;const dx=d*1.1,top=.62-.2+Math.sqrt(Math.max(0,.04-dx*dx));if(Math.abs(dx)<.2&&q.y<top&&q.y>.12)return Math.abs(dx)>.15||q.y>top-.06?rp(BARK,.6,q.sx,q.sy):FGR[0]}return null};
   return{ground:floor(),objs:[disc(MSTONE,1.3,.06,{moss:.5}),slab(circle(1.12),.06,.95,mossy({moss:.5,inlay:alc}),{key:-3,taper:[1,.8]}),
   roof('dome',0,0,.92,.92,.95,.5,q=>q.f==='top'?(vnoise(q.x*3,q.z*3,5)>.42?rp(MOSS,q.b,q.sx,q.sy):rp(MSTONE,q.b,q.sx,q.sy)):rp(MSTONE,.4,q.sx,q.sy),{key:-2,noShadow:1}),
   slab(poly(5,.16,.3),1.4,1.75,mossy(),{key:-1,taper:[1,.5]}),bush(-1.05,.75,2,1),bush(1.05,.8,9),
   dyn(4,(F,t)=>{AL.forEach((a0,k)=>{const br=K?.5+.5*Math.sin(t*TAU/5-k*2.1):.1,[x,y]=at(Math.cos(a0)*1.08,.3,Math.sin(a0)*1.08),w=a0===Math.PI/2?3:2;for(let j=-5;j<=3;j++)for(let i=-w;i<=w;i++)if(i*i/(w*w+1)+j*j/22<1)F.set(x+i,y+j,FGR[br>.7?(i*i+j*j<4?3:2):br>.35?(i*i+j*j<4?2:1):1]);if(K&&br>.8)zz(F,x+2,y-8,t+k,FGR)});
    for(const[mx,mz,s]of[[-.5,1.15,1],[.62,1.12,2],[.2,1.25,3]]){const[x,y]=at(mx,.06,mz);F.set(x,y,CLOTH[2]);F.set(x,y-1,CLOTH[2]);for(let i=-1;i<=1;i++)F.set(x+i,y-2,FGR[Math.sin(t*TAU*.4+s)>0?3:2])}
    const[fcx,fcy]=at(0,1.35,0);fireflies(F,t,K?6:3,5,fcx,fcy,40,30)},[LT(0,.4,1.05,38,.7,GREEN),LT(.9,.4,.6,26,.5,GREEN),LT(-.9,.4,.6,26,.5,GREEN)])]}}},
 {g:'bedroom',name:'Lit sous les lianes',desc:'Une couche de pierre garnie de feuillage, quatre montants légers et un ciel de lit de lianes qui ondulent. Les lucioles tournent au-dessus du dormeur.',anims:['lianes au vent','ronde de lucioles','lanterne'],
  build(){const top=1.7,[cx,cy]=at(0,1.0,.05);return{ground:floor(),objs:[oct(MSTONE,.08,{moss:.3}),
   slab(rect(-.85,-.52,.85,.52),.08,.4,mossy(),{key:-3}),slab(rect(-.76,-.44,.76,.44),.4,.52,q=>rp(LEAF,q.f==='top'?.55+(vnoise(q.x*9,q.z*9,4)-.5)*.5:.35,q.sx,q.sy),{key:-2.9}),slab(rect(-.2,-.3,.2,.3),.52,.6,q=>rp(CLOTH,q.f==='top'?.8:.5,q.sx,q.sy),{x:-.48,key:-2.8}),
   ...[[-.95,-.6],[.95,-.6],[-.95,.6],[.95,.6]].map(([x,z])=>post(x,z,top,BARK,.045)),
   box(0,-.6,1.0,.04,top,top+.07,woodMat(BARK,{along:'x'}),{key:2}),box(0,.6,1.0,.04,top,top+.07,woodMat(BARK,{along:'x'}),{key:2.2}),box(-.95,0,.04,.62,top,top+.07,woodMat(BARK),{key:2.1}),box(.95,0,.04,.62,top,top+.07,woodMat(BARK),{key:2.1}),
   dyn(4,(F,t)=>{for(let k=0;k<17;k++){const side=k<11,x=side?-.95+k*.19:(k%2?-.95:.95),z=side?.6:-.6+(k-11)*.22,[a,b]=at(x,top,z),len=7+Math.floor(hash(k,1,4)*(side?10:16));for(let j=0;j<len;j++){const sw=Math.round(Math.sin(t*1.6+k*.9+j*.25)*1.5*(j/len));F.set(a+sw,b+j,LEAF[j%3?4:6]);if(j%4===2)F.set(a+sw+(k%2?1:-1),b+j,LEAF[6])}}
    const n=K?8:3;for(let k=0;k<n;k++){const a=t*.9+k*TAU/n,r=18+Math.sin(t+k)*4;F.set(Math.round(cx+Math.cos(a)*r),Math.round(cy+Math.sin(a)*r*.5),FGR[k%2?3:2])}
    if(K){const[sx,sy]=at(.1,.56,0);for(let j=-2;j<=2;j++)for(let i=-7;i<=7;i++)F.set(sx+i,sy+j,i<-5?SANDL[3]:LEAF[j<0?5:3]);zz(F,sx-4,sy-6,t,FGR)}},[LT(0,1.0,.05,44,.7,GREEN)])]}}},
 {g:'bedroom',name:'Bassin du sommeil',desc:'Un bassin rond aux pierres moussues, de la famille du Puits des Âmes. Trois grandes feuilles servent de couches ; la brume glisse sur l’eau et le lotus du centre bat.',anims:['ronds dans l’eau','brume','lotus qui bat','feuilles qui flottent'],
  build(){const pads=[[-.45,-.25],[.5,-.1],[-.05,.5]],[cx,cy]=at(0,.08,0);return{ground:floor(),objs:[
   slab(circle(.98),0,.06,q=>q.f==='top'?rp(WATER,.3+(vnoise(q.x*5,q.z*8,3)-.5)*1.2,q.sx,q.sy):rp(MSTONE,.3,q.sx,q.sy),{key:-9}),slab(ringShape(.98,1.24),0,.2,mossy({moss:.45}),{key:-8}),
   bush(-1.1,-.9,3,1),bush(1.12,.85,6),
   dyn(4,(F,t)=>{ripple(cx,cy,6,22,'#5aa0b8')(F,t);pads.forEach(([x,z],k)=>{const bob=Math.round(Math.sin(t*1.2+k*2)*.8),[a,b]=at(x,.08,z);for(let j=-4;j<=4;j++)for(let i=-7;i<=7;i++){const d=i*i/49+j*j/16;if(d<1&&!(i>3&&Math.abs(j)<2))F.set(a+i,b+j+bob,LEAF[d>.75?3:i+j<0?6:5])}
     if(K){for(let j=-1;j<=1;j++)for(let i=-4;i<=3;i++)F.set(a+i,b+j+bob-1,i<-2?SANDL[3]:CLOTH[j<0?3:2]);zz(F,a+3,b-5,t+k*1.1,FGR)}});
    const pu=.5+.5*Math.sin(t*1.25);for(let j=-4;j<=1;j++)for(let i=-3;i<=3;i++)if(Math.abs(i)<=3-Math.abs(j+1)*.6)F.set(cx+i,cy-2+j,i===0&&j<0?FGR[pu>.5?3:2]:MSTONE[i<0?6:4]);
    for(let k=0;k<7;k++){const p=(t*.06+hash(k,1,7))%1,x=Math.round(cx-34+p*68),y=Math.round(cy-6+(hash(k,2,7)-.5)*30);for(let i=0;i<5+k%3*2;i++)if((i+k)%3&&Math.hypot(x+i-cx,y-cy)<21)F.set(x+i,y,FWH[1])}},[LT(0,.3,0,44,.75,GREEN)])]}}},

// ======================= ENTREPÔT =======================
 {g:'warehouse',name:'Carrousel aux coffres',desc:'Un plateau de marbre gradué autour d’une colonne. Les coffres y tournent d’un cran à la fois : celui qu’on demande s’arrête devant, la lampe s’allume.',anims:['plateau qui tourne','lampe d’appel','repère gradué'],
  build(){const[lx,ly]=at(0,1.62,0);return{ground:floor(),objs:[disc(MARBLE,1.3,.1),slab(circle(1.08),.1,.24,mMat({inlay:ticksI(.9,1.06,24,rp(MARBLE,.15,0,0),.03)}),{key:-8}),
   slab(circle(.17),.24,1.5,mMat({inlay:vlineI(WHC[1],.03,.2,.9)}),{key:-2,mask:true}),slab(circle(.24),1.5,1.58,mMat(),{key:-1,mask:true}),
   slab(tri(.14),.1,.3,stone(SLATE),{z:1.2,key:1.2}),
   dyn(4,(F,t,S)=>{const B=behind(F,S),step=2,n=Math.floor(t/step),u=(t%step)/step,a0=K?(n+ease(clamp(u/.45)))*TAU/6:0,stop=!K||u>.5;
    const ord=[...Array(6).keys()].sort((p,q)=>Math.sin(a0+p*TAU/6)-Math.sin(a0+q*TAU/6));for(const k of ord){const a=a0+k*TAU/6+Math.PI/2,[x,y]=at(Math.cos(a)*.72,.24,Math.sin(a)*.72);cargo(Math.sin(a)>0?F:B,x,y,k)}
    for(let j=-2;j<=2;j++)for(let i=-2;i<=2;i++)if(i*i+j*j<6)F.set(lx+i,ly-3+j,K&&stop?FWH[i||j?2:3]:FWH[0])},[LT(0,1.6,0,40,.8,WHITEC)])]}}},
 {g:'warehouse',name:'Colonne flottante',desc:'Quatre bornes et un cercle gravé. Dans la colonne de lumière blanche, coffres et caisses montent en file, tournent sur eux-mêmes et disparaissent au sommet.',anims:['colis en lévitation','colonne de lumière','éclat au sommet'],
  build(){const[cx,cy]=at(0,.12,0);return{ground:floor(),objs:[slab(square(1.28),0,.12,stone(MARBLE,{noise:.06,inlay:anyI(ringI(.62,.04,WHC[1]),ringI(.9,.025,WHC[0]))}),{key:-9}),
   ...[[-1,-1],[1,-1],[-1,1],[1,1]].map(([x,z])=>obelisk(x,z,.7,MARBLE,WHC[2],{glyph:1,y0:.12})),
   dyn(4,(F,t)=>{for(let j=0;j<80;j++)for(let i=-9;i<=9;i++)if(hash(i,j-Math.floor(t*(K?16:2)),5)>(K?.86:.96))F.set(cx+i,cy-j,WHC[Math.abs(i)<4?2:1]);
    if(!K){cargo(F,cx-6,cy+1,0);cargo(F,cx+6,cy+2,1);sCrate(F,cx,cy-7,4);return}
    for(let k=3;k>=0;k--){const p=(t*.16+k/4)%1,y=cy-4-p*66,x=cx+Math.round(Math.sin(t*1.5+k*1.6)*3);if(p>.93){for(let i=-6;i<=6;i++){F.set(x+i,Math.round(y)-4,FWH[3]);F.set(x,Math.round(y)-4+i,FWH[3])}}else cargo(F,x,Math.round(y),k)}},[LT(0,1.3,0,58,.95,WHITEC)])]}}},
 {g:'warehouse',name:'Mur de casiers',desc:'Un columbarium à marchandises : douze niches de marbre sous une corniche d’ardoise. La niche demandée s’éclaire et son coffre avance.',anims:['niche qui s’éclaire','coffre qui avance','veilleuses'],
  build(){const cols=4,rows=3,W_=2.2,H0=.3,H1=1.8,cw=W_/cols,ch=(H1-H0)/rows,nic=frontI(q=>{const u=(q.x+W_/2)/cw,v=(q.y-H0)/ch,c=Math.floor(u),r=Math.floor(v);if(c<0||c>=cols||r<0||r>=rows)return null;const fu=u-c,fv=v-r;if(fu<.12||fu>.88||fv<.1||fv>.9)return null;return rp(DSTONE,.1+(fv>.75?.1:0),q.sx,q.sy)});
   return{ground:floor(),objs:[slab(rect(-1.3,-1.0,1.3,1.15),0,.1,stone(MARBLE,{noise:.06}),{key:-9}),box(0,-.45,W_/2+.08,.38,.1,H1+.08,mMat({inlay:nic}),{key:-2}),
   box(0,-.45,W_/2+.16,.46,H1+.08,H1+.2,mMat(),{key:3}),roof('shed',0,-.45,W_/2+.2,.5,H1+.2,.22,shingle(SLATE,{cw:.1}),{key:4,noShadow:1}),
   column(-1.05,.8,.45,MARBLE,{flame:'white',light:WHITEC}),column(1.05,.8,.45,MARBLE,{flame:'white',light:WHITEC}),crate(-.5,.75,.16),
   dyn(4,(F,t)=>{const step=1.8,n=Math.floor(t/step),u=(t%step)/step,act=K?Math.floor(hash(n,3,9)*12):-1;for(let k=0;k<12;k++){const c=k%cols,r=Math.floor(k/cols);if(hash(k,1,5)<.2&&k!==act)continue;const[x,y]=at(-W_/2+(c+.5)*cw,H0+r*ch+.06,-.07),out=k===act?Math.round(Math.sin(u*Math.PI)*4):0;
     if(k===act){const[a,b]=at(-W_/2+c*cw,H0+(r+1)*ch,-.07),w=Math.round(cw*T),h=Math.round(ch*T);for(let i=1;i<w;i++){F.set(a+i,b+1,FWH[3]);F.set(a+i,b+h-1,FWH[3])}for(let j=1;j<h;j++){F.set(a+1,b+j,FWH[3]);F.set(a+w-1,b+j,FWH[3])}}
     cargo(F,x,y+out,k)}},[LT(0,1.0,0,50,.6,WHITEC)])]}}},
 {g:'warehouse',name:'Grande balance',desc:'La balance de Sigil, à l’échelle d’un bâtiment : coffres bleus d’un côté, coffres rouges de l’autre. Le fléau penche selon ce qui entre et ce qui sort.',anims:['fléau qui penche','plateaux et chaînes','lampe de tête'],
  build(){const[px,py]=at(0,1.95,0);return{ground:floor(),objs:[disc(MARBLE,1.3,.1),slab(square(.5),.1,.3,mMat(),{key:-3}),
   slab(square(.16),.3,1.9,mMat({inlay:vlineI(WHC[1],.03,.15,.9)}),{key:-2,taper:[1.2,.8],mask:true}),slab(square(.2),1.9,1.98,mMat(),{key:-1}),
   crate(-.2,1.05,.15),crate(.15,1.1,.13),
   dyn(4,(F,t,S)=>{const a=K?Math.sin(t*.7)*.2+Math.sin(t*1.9)*.03:0,L=30;for(const s of[-1,1]){const ex=px+s*Math.cos(a)*L,ey=py+s*Math.sin(a)*L;thick(F,px,py,ex,ey,SILVER[4],IRON[3]);const X=Math.round(ex),Y=Math.round(ey)+20;
     F.line(X,ey,X-9,Y,IRON[4]);F.line(X,ey,X+9,Y,IRON[4]);for(let i=-11;i<=11;i++){F.set(X+i,Y,SILVER[4]);F.set(X+i,Y+1,IRON[i<0?5:3]);if(Math.abs(i)<9)F.set(X+i,Y+2,IRON[2])}
     const R=s<0?BLUEC:REDC;sChest(F,X-5,Y-1,R);sChest(F,X+5,Y-1,R);sChest(F,X,Y-9,R)}
    for(let j=-2;j<=2;j++)for(let i=-2;i<=2;i++)if(i*i+j*j<6)F.set(px+i,py-5+j,FWH[i||j?2:3])},[LT(0,2.1,0,36,.7,WHITEC)])]}}},
 {g:'warehouse',name:'Monte-charge',desc:'Une trappe à deux vantaux dans une margelle de marbre, sous une chèvre à poulie. Les vantaux s’écartent, le plateau remonte chargé, puis redescend.',anims:['vantaux de la trappe','plateau qui monte','poulie et câbles'],
  build(){const[cx,cy]=at(0,.2,.1),[wx,wy]=at(0,2.05,.1);return{ground:floor(),objs:[slab(square(1.3),0,.08,stone(MARBLE,{noise:.06}),{key:-9}),
   slab(rect(-.85,-.6,.85,.8),.08,.1,q=>rp(DSTONE,q.f==='top'?.05:.3,q.sx,q.sy),{key:-8}),
   box(0,-.7,.98,.1,.08,.3,mMat(),{key:-.8}),box(-.92,.1,.08,.7,.08,.3,mMat(),{key:-.7}),box(.92,.1,.08,.7,.08,.3,mMat(),{key:-.7}),box(0,.9,.98,.1,.08,.3,mMat(),{key:.9}),
   slab(square(.07),.08,2.1,woodMat(WOOD),{x:-1.05,z:.1,key:.1,taper:[1.2,.9]}),slab(square(.07),.08,2.1,woodMat(WOOD),{x:1.05,z:.1,key:.1,taper:[1.2,.9]}),box(0,.1,1.12,.06,2.1,2.22,woodMat(WOOD,{along:'x'}),{key:3}),
   dyn(.5,(F,t)=>{const per=8,u=K?(t%per)/per:0,open=K?(u<.12?u/.12:u<.88?1:1-(u-.88)/.12):0,lift=K?(u<.15?0:u<.4?ease((u-.15)/.25):u<.6?1:u<.85?1-ease((u-.6)/.25):0):0,hw=19,x0=cx-hw,y0=cy-14,hh=30;
     if(lift>0){const py=y0+Math.round((1-lift)*8)-Math.round(lift*12);for(let j=0;j<hh-4;j++)for(let i=2;i<2*hw-2;i++)F.set(x0+i,py+j,j>hh-8?WOOD[1]:(i%6===0?WOOD[2]:WOOD[j<2?5:4]));cargo(F,cx-9,py+12,0);cargo(F,cx+8,py+13,1);sCrate(F,cx,py+21,4);
      for(const s of[-1,1])F.line(wx+s*3,wy+3,cx+s*(hw-4),py,CANVAS[1])}
     const w=Math.round(hw*(1-open));for(let j=0;j<hh;j++)for(let i=0;i<w;i++){const c=j===0?MARBLE[6]:i===w-1?MARBLE[2]:(j%8===0?MARBLE[3]:MARBLE[5]);F.set(x0+i,y0+j,c);F.set(x0+2*hw-1-i,y0+j,c)}
     wheelDyn(wx,wy+2,4,4,K?(lift>0&&lift<1?4:0):0,IRON)(F,t)},[LT(0,.4,.1,40,.5,WHITEC)])]}}},
];
const glyphLine=()=>bandI(.3,.75,AEC[1],.15,7);
const cyLineA=v=>q=>q.f==='side'&&!q.lip&&Math.abs(q.v-v)<.08?AEC[1]:null;

function floorScene(){const S=new Scene();S.bake(floor(),[]);return S}
// ---------- Atelier : les pièces de bois prennent la forme de l'objet fabriqué ----------
// Injecté dans le moteur BAT par tools/atelier-morph/build.py, à la place des cinq madriers de la Table d'énonciation.
// Une pièce cible = [x0, y0, x1, y1, matière, épaisseur], en pixels autour du point d'assemblage (y vers le bas).
// Toutes partent du même bout de bois (longueur 16, épaisseur 2) et changent de longueur, d'épaisseur puis de matière.
const MO_MAT={
 W:[WOOD[4],WOOD[3],WOOD[2]],B:[BARK[3],BARK[2],BARK[1]],I:[IRON[5],IRON[4],IRON[2]],R:[SLATE[4],SLATE[3],SLATE[1]],
 F:[CANVAS[4],CANVAS[3],CANVAS[1]],G:[CANVAS[2],CANVAS[1],CANVAS[0]],L:R_(['#d8584a','#b03c34','#7a2424'])};
const MO_FLAME=['#ffe9a0','#ffb030','#e86a18'].map(E);
const caltrop=(x,y)=>[[x,y-5,x,y,'I',2],[x,y,x-4,y+4,'I',2],[x+1,y,x+5,y+4,'I',2]];
const arrow=(dx,dy)=>[[-9+dx,10+dy,7+dx,-8+dy,'W',2],[7+dx,-8+dy,9+dx,-11+dy,'I',3],[-9+dx,10+dy,-11+dx,13+dy,'L',3]];
const MO_SHAPES={
 torch:[[-7,12,-2,3,'W',3],[-2,3,2,-4,'W',3],[2,-4,5,-9,'G',5]],
 pickaxe:[[-8,12,-1,1,'W',3],[-1,1,5,-8,'W',3],[-9,-8,0,-11,'I',3],[0,-11,8,-9,'I',3],[8,-9,12,-3,'I',2]],
 arrows:[...arrow(-4,-3),...arrow(0,0),...arrow(4,3)],
 chest:[[-11,-8,11,-8,'W',4],[-11,-3,11,-3,'W',4],[-11,2,11,2,'W',4],[-11,7,11,7,'W',4],[-8,-8,-8,10,'I',2],[7,-8,7,10,'I',2],[-1,-3,-1,0,'I',3]],
 wood_fiber:[[-11,-7,11,-7,'F',3],[-11,-2,11,-2,'F',3],[-11,3,11,3,'F',3],[-11,8,11,8,'F',3],[-6,-9,-6,11,'G',2],[4,-9,4,11,'G',2]],
 firing_post:[[-12,-10,-12,10,'W',4],[-7,-7,-7,10,'W',4],[-2,-10,-2,10,'W',4],[3,-7,3,10,'W',4],[8,-10,8,10,'W',4],[-12,-3,11,-3,'B',2],[-12,5,11,5,'B',2]],
 barricade:[[-7,9,-1,9,'R',4],[1,8,7,8,'R',5],[-12,-9,12,7,'W',4],[-12,7,12,-9,'W',4],[-13,1,13,1,'W',3]],
 fishing_rod:[[-10,12,-3,3,'W',2],[-3,3,5,-7,'W',2],[5,-7,9,-12,'W',1],[-10,9,-8,11,'I',4],[9,-12,10,5,'F',1],[10,5,8,8,'I',2]],
 bow:[[-5,-12,2,-7,'W',3],[2,-7,4,0,'W',3],[4,0,2,7,'W',3],[2,7,-5,12,'W',3],[-5,-12,-5,12,'F',1]],
 caltrops:[...caltrop(-6,6),...caltrop(6,6),...caltrop(0,-6)]};
// MO : objet en cours, « figé » montre la silhouette assemblée sans la boucle, « icone » bascule sur l'icône du jeu après l'éclat.
const MO={id:'barricade',hold:0,icon:1,icons:{}};
function moBar(F,x0,y0,x1,y1,m,w){const flat=Math.abs(x1-x0)>=Math.abs(y1-y0);for(let k=0;k<w;k++){const c=m[k===0?0:k===w-1&&w>1?2:1];F.line(x0+(flat?0:k),y0+(flat?k:0),x1+(flat?0:k),y1+(flat?k:0),c)}}
function morphDraw(F,t,cx,cy){
 const S=MO_SHAPES[MO.id]||MO_SHAPES.barricade,n=S.length;
 if(!K){S.forEach((s,k)=>{const x=(hash(k,2,3)-.5)*30,y=20+(k%3)*2;moBar(F,cx+x-7,cy+y,cx+x+7,cy+y,MO_MAT.W,2)});return}
 if(MO.id==='none'){motes(cx,cy+18,14,22,['#5a5cff','#9aa0ff','#e0e4ff'],6,2)(F,t);return} // export vers le jeu : les pièces y sont dessinées par BuildingView
 const u=MO.hold?.56:(t%6)/6,rise=ease(clamp(u/.1)),shown=MO.icon&&u>=.62,flash=!MO.hold&&u>.56&&u<.68;
 if(!shown)S.forEach(([ax,ay,bx,by,mat,w],k)=>{
  const p=ease(clamp((u-.1-.14*k/n)/.3)),tx=(ax+bx)/2,ty=(ay+by)/2,ta=Math.atan2(by-ay,bx-ax),tl=Math.hypot(bx-ax,by-ay)/2;
  const a0=ta+(hash(k,1,3)-.5)*5+(1-p)*t*TAU/6,x0=(hash(k,2,3)-.5)*46,ys=(hash(k,3,3)-.5)*16-4+Math.sin(t*Math.PI+k)*2,y0=20+(ys-20)*rise;
  const x=x0+(tx-x0)*p,y=y0+(ty-y0)*p,a=a0+(ta-a0)*p,L=8+(tl-8)*p,ww=Math.max(1,Math.round(2+(w-2)*p)),dx=Math.cos(a)*L,dy=Math.sin(a)*L;
  moBar(F,cx+x-dx,cy+y-dy,cx+x+dx,cy+y+dy,MO_MAT[p>.6?mat:'W'],ww)});
 if(!shown&&MO.id==='torch'&&u>.5)for(let j=0;j<5;j++)for(let i=-1-(j<3?1:0);i<=1+(j<3?1:0);i++)if(hash(i,j+Math.floor(t*8),5)>.25)F.set(cx+5+i,cy-10-j,MO_FLAME[j>3?2:Math.abs(i)>1?2:j>1?1:0]);
 if(shown){const I=MO.icons[MO.id],fall=u>.82?ease((u-.82)/.18):0,bob=fall?0:Math.round(Math.sin(t*3)*1.2);
  if(I)for(let j=0;j<32;j++)for(let i=0;i<32;i++){const v=I[j*32+i];if(v>=0&&!(fall>.55&&(i+j)%2)&&fall<.95)F.set(cx-16+i,cy-16+j+bob+Math.round(fall*22),v|0x1000000)}}
 if(flash)for(let k=0;k<40;k++){const a=k*TAU/40,r=8+(u-.56)*170;F.set(Math.round(cx+Math.cos(a)*r),Math.round(cy+Math.sin(a)*r*.7),AEC[k%2?3:2])}
 motes(cx,cy+18,14,22,['#5a5cff','#9aa0ff','#e0e4ff'],6,2)(F,t)}
function vignette(i){const b=ITEMS[i].build(),S=new Scene();S.bake(b.ground,b.objs);if(b.fx)S.dyn.push(...b.fx(S));return S}
// ---------- export vers le jeu ----------
// Sprite 320 × 240, ancre (160, 168) au centre de l'emprise, 24 px par unité à l'échelle native (scale 1 : 2 × 2 cases = 64 px),
// sol transparent, boucle de 72 images à 12 i/s (la coulée dure 6 s), portrait 128 × 128 du HUD.
function exportSprite(i=0,frames=72,fps=12){configure(24,320,240,160,168);let S;try{const b=ITEMS[i].build();S=new Scene();S.bake(()=>-1,b.objs)}catch(e){configure(24,132,136,66,102);throw e}
 const cols=12,rows=Math.ceil(frames/cols),sheet=document.createElement('canvas');sheet.width=320*cols;sheet.height=240*rows;const g=sheet.getContext('2d');let top=240,bot=0;
 for(let f=0;f<frames;f++){const t=f/fps,F=S.compose(t);const img=g.createImageData(320,240),D=img.data;
  for(let k=0;k<320*240;k++){const v=F.c[k],o=k*4;if(v>=0){D[o]=v>>16&255;D[o+1]=v>>8&255;D[o+2]=v&255;D[o+3]=255;const y=(k/320)|0;if(y<top)top=y;if(y>bot)bot=y}else if(S.sh[k]>0)D[o+3]=Math.round(S.sh[k]*95)}
  g.putImageData(img,(f%cols)*320,((f/cols)|0)*240)}
 const base=document.createElement('canvas');base.width=320;base.height=240;base.getContext('2d').drawImage(sheet,0,0,320,240,0,0,320,240);
 const bd=base.getContext('2d').getImageData(0,0,320,240).data;let x0=320,x1=0,y0=240,y1=0;for(let y=0;y<240;y++)for(let x=0;x<320;x++)if(bd[(y*320+x)*4+3]===255){if(x<x0)x0=x;if(x>x1)x1=x;if(y<y0)y0=y;if(y>y1)y1=y}
 const por=document.createElement('canvas');por.width=por.height=128;const pg=por.getContext('2d'),w=x1-x0+1,h=y1-y0+1,k=Math.min(1.5,120/w,124/h);pg.imageSmoothingEnabled=false;
 pg.drawImage(base,x0,y0,w,h,Math.round(64-w*k/2),Math.round(128-h*k),Math.round(w*k),Math.round(h*k));
 configure(24,132,136,66,102);return{sheet,base,portrait:por,pick:ITEMS[i].name,meta:{anchor:[160,168],top,bottom:bot,scale:1,anim:{frame_w:320,frame_h:240,cols,rows,count:frames,seconds:frames/fps,fps,exact:true,seam_pixels:0}}}}
return{morph:MO,shapes:MO_SHAPES,setMorph(o){Object.assign(MO,o)},ITEMS,GROUPS,vignette,floorScene,setWork(v){K=v},ambient,exportSprite,get W(){return W},get H(){return H}}})();


