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


// ================= BÂTIMENTS v4 : Scierie, Archerie, Armurerie (découpage de la fabrication, 2026-11-20) =================
// Assemblé par tools/batiments-16bits/build_v4.py : moteur de creuset-planches.js + outils v2 + outils v3 (avant GROUPS) + ce fichier.
// K = 1 au travail, 0 au repos (réglé par la page via BAT.setWork). Même rendu que la v3 : volumes en 3/4 finis en 16 bits.

// ---------- outils propres à la v4 ----------
const FIB=R_(['#7a6644','#a08a5e','#c8b080','#e6d6a8']);          // fibre de bois
const FEA=R_(['#8a8e98','#b8bcc6','#e2e4ea','#ffffff']);          // plumes
const STRING=E('#d8cfb4');
function pdisk(F,cx,cy,r,fn){for(let j=-Math.ceil(r);j<=Math.ceil(r);j++)for(let i=-Math.ceil(r);i<=Math.ceil(r);i++){const d=Math.hypot(i,j);if(d<=r+.3){const c=fn(i,j,d);if(c!=null)F.set(Math.round(cx)+i,Math.round(cy)+j,c)}}}
// lame circulaire vue de face : dents qui tournent avec l'angle a
function sawBlade(F,cx,cy,r,a,hot){pdisk(F,cx,cy,r+1,(i,j,d)=>{const an=Math.atan2(j,i)-a,tooth=((an*12/TAU)%1+1)%1;
 if(d>r-.4)return tooth<.45?SILVER[i+j<0?4:2]:null;if(d<2.2)return hot?AEC[3]:IRON[5];if(d<3.4)return IRON[3];
 const sp=((an*4/TAU)%1+1)%1;if(sp<.08&&d<r-2)return SILVER[1];return SILVER[i+j<-2?4:i+j>3?2:3]})}
// rondin couché le long de x (vu de côté) : x0..x1, axe en y, rayon r, bout coupé en x1
function logX(F,x0,x1,y,r,cut){x0=Math.round(x0);x1=Math.round(x1);for(let x=x0;x<=x1;x++)for(let j=-r;j<=r;j++){const v=j/r;F.set(x,Math.round(y)+j,j===-r?BARK[4]:j===r?BARK[0]:BARK[v<-.3?3:v<.4?2:1])}
 pdisk(F,x1,y,r,(i,j,d)=>i<0?null:d>r-1?BARK[1]:SAND[(Math.round(d)%2)?5:4]);if(cut!=null)for(let x=x0;x<=Math.min(cut,x1-1);x++)F.set(x,Math.round(y)-r+1,DSTONE[1])}
// flèche de (x0,y0) vers (x1,y1) : pointe en x1
function arrowL(F,x0,y0,x1,y1,fc=FEA,glow){F.line(x0,y0,x1,y1,WOOD[4]);const L=Math.hypot(x1-x0,y1-y0)||1,ux=(x1-x0)/L,uy=(y1-y0)/L;
 F.set(Math.round(x1),Math.round(y1),SILVER[4]);F.set(Math.round(x1-ux),Math.round(y1-uy),SILVER[2]);
 for(let k=0;k<3;k++){const bx=x0+ux*k,by=y0+uy*k;F.set(Math.round(bx-uy*1.5),Math.round(by+ux*1.5),glow?AEC[2]:fc[2]);F.set(Math.round(bx+uy*1.5),Math.round(by-ux*1.5),glow?AEC[3]:fc[3])}}
// arc vertical vu de face, corde tirée de `pull` px vers la gauche
function bowV(F,x,y,h,pull,R=WOOD){let px=x,py=y-h;for(let j=-h;j<=h;j++){const v=j/h,bx=Math.round(x+(1-v*v)*5);F.set(bx,y+j,R[4]);F.set(bx+1,y+j,R[2])}
 F.set(x,y-h-1,R[5]);F.set(x,y+h+1,R[5]);F.line(x,y-h,x-pull,y,STRING);F.line(x-pull,y,x,y+h,STRING)}
function ingot(F,x,y,R=COPPER){for(let i=0;i<7;i++){F.set(x+i,y-2,R[5]);F.set(x+i,y-1,R[i<1?3:4]);F.set(x+i,y,R[2])}F.set(x+7,y-1,R[1]);F.set(x+7,y,R[1])}
function ingotsObj(x,z,R=COPPER,n=3){return{key:z,draw(L,S){const[a,b]=P3(x,0,z),A=Math.round(a),B=Math.round(b);S.shadowEll(A+4,B+1,7,2,.6);
 for(let k=0;k<n;k++){const ox=A-4+(k%2)*4-(k>1?2:0),oy=B-(k>1?3:0)-(k%2?0:0);ingot(L,ox+(k>1?2:0),oy-(k===1?0:0),R)}return{}}}}
function curl(F,x,y,p,c=FIB){for(let k=0;k<7;k++){const a=k*.9+p*6,r=1+k*.35;F.set(Math.round(x+Math.cos(a)*r),Math.round(y+Math.sin(a)*r*.8),c[k%2?3:2])}}
// petit marteau en lévitation, tête en (x,y)
function floatHammer(F,x,y,ang,R=IRON){const c=Math.cos(ang),s=Math.sin(ang);F.line(x,y,Math.round(x+c*10),Math.round(y+s*10),WOOD[4]);for(let j=-2;j<=2;j++)for(let i=-3;i<=3;i++)F.set(x+i,y+j,j<0?R[6]:i<0?R[5]:R[3])}
function swordV(F,x,y,len,C=COLDB,hilt=true){for(let j=0;j<len;j++){F.set(x,y-j,C[j===len-1?0:1]);F.set(x+1,y-j,C[3])}if(hilt){for(let i=-3;i<=4;i++)F.set(x+i,y+1,IRON[5]);F.set(x,y+2,LEATHER[2]);F.set(x+1,y+2,LEATHER[1]);F.set(x,y+3,LEATHER[2]);F.set(x,y+4,COPPER[4])}}
const HOTB=[MOLT[4],MOLT[3],MOLT[2],MOLT[1]],COLDB=[SILVER[4],SILVER[3],SILVER[2],SILVER[1]];

const GROUPS=[
 {id:'scierie',name:'Scierie',note:'Nouveau bâtiment, service d’Aether. Le bois brut y devient planches et fibre de bois. Bois, fer et flamme bleu-violet ; l’animation montre le bois qui se découpe.'},
 {id:'archerie',name:'Archerie',note:'Nouveau bâtiment, service d’Aether. Arcs, flèches et, plus tard, munitions de l’Arbalestrie. Bois clair, cuir, plumes et empennages qui s’allument d’Aether.'},
 {id:'creuset',name:'Armurerie',note:'Ex-Creuset des Exilés : il ne coule plus, il façonne les lingots de la Fonderie en armes et armures. Fer, basalte et métal chauffé orange.'}];

const ITEMS=[
// ======================= SCIERIE =======================
 {g:'scierie',name:'Grande scie d’Aether',desc:'Une lame circulaire géante dressée sur un banc de fer. Le rondin avance seul dans la lame, qui le refend en planches dans une gerbe de sciure.',anims:['lame qui tourne','rondin qui avance','sciure','moyeu d’Aether'],
  build(){const[bx,by]=at(0,.95,0),[lx,ly]=at(0,.62,0);return{ground:floor(),objs:[oct(SLATE,.1,{inlay:ringI(1.04,.035,AEC[0])}),
   box(0,0,1.05,.24,.1,.48,woodMat(WOOD,{along:'x'}),{key:-1}),slab(rect(-.12,-.3,.12,.3),.1,.52,iMat(),{key:-.9}),
   ...logs(-.8,-.9,3,.28),planks(.62,.95,4,.42),barrel(-.98,.9,WOOD,{h:.34}),
   dyn(4,(F,t)=>{const per=6,u=K?(t%per)/per:.55,head=Math.round(lx-22+u*52),tail=Math.max(head-44,lx-30);
    sawBlade(F,bx,by,17,K?t*TAU*7/6:.3,K);if(head>tail+3)logX(F,tail,head,ly,6,lx);
    for(let i=-1;i<=1;i++)F.set(bx+i,ly+7,IRON[2]);
    if(K&&head>lx-2){sparkC(bx-2,ly-6,['#a08a5e','#c8b080','#e6d6a8'],12,4,11,10)(F,t);for(let k=0;k<5;k++)F.set(bx-10-k*2+Math.round(Math.sin(t*TAU*1.5+k)*1.5),ly+9+(k%2),FIB[k%3+1])}},[LT(0,.95,0,40,.7,VIOBLUE,.1)])]}}},
 {g:'scierie',name:'Scie de long à contrepoids',desc:'Un portique de bois et un cadre de scie qui monte et descend dans le tronc. Le contrepoids de basalte fait le travail ; le tronc glisse d’un cran à chaque passe.',anims:['cadre de scie','contrepoids','tronc qui avance','poulie d’Aether'],
  build(){const[px,py]=at(0,2.18,-.1),[tx,ty]=at(0,.62,-.1);return{ground:floor(),objs:[slab(square(1.28),0,.08,woodMat(WOOD),{key:-9}),
   post(-.62,-.1,2.2,BARK,.08),post(.62,-.1,2.2,BARK,.08),box(0,-.1,.78,.08,2.1,2.24,woodMat(WOOD,{along:'x'}),{key:2}),
   sawhorse(-.6,.15),sawhorse(.6,.15),...logs(.85,-.95,3,.26),planks(-.6,1.0,3,.4),
   dyn(4,(F,t)=>{const u=K?Math.sin(t*TAU*1.2):0,dy=Math.round(u*7),adv=K?Math.floor(t*1.2)%8:3,lx=tx-38+adv*3;
    logX(F,lx,tx+30,ty+4,6,tx);
    const fy=ty-12+dy;for(let j=0;j<30;j++){F.set(tx-8,fy+j-6,IRON[4]);F.set(tx+8,fy+j-6,IRON[3])}for(let i=-8;i<=8;i++){F.set(tx+i,fy-6,IRON[5]);F.set(tx+i,fy+24,IRON[3])}for(let j=0;j<29;j++)F.set(tx,fy+j-5,SILVER[(j+dy)%3?3:4]);
    F.line(tx,fy-6,px,py+3,IRON[1]);wheelDyn(px,py,4,4,K?2:0,IRON)(F,t);F.set(px,py,AEC[K?3:1]);
    const cx=px+14,cy=py+20-dy;F.line(px+4,py,cx,cy-4,IRON[1]);for(let j=0;j<7;j++)for(let i=-4;i<=4;i++)F.set(cx+i,cy-4+j,BASALT[j===0?6:i<-2?5:3]);F.set(cx,cy-1,AEC[K?2:0]);
    if(K&&u>.6)dustDyn(tx,ty+12,6,4)(F,t)},[LT(0,2.1,-.1,30,.6,VIOBLUE)])]}}},
 {g:'scierie',name:'Fendoir de basalte',desc:'Un coin de basalte gravé flotte au-dessus d’un billot. Il retombe, fend la bûche en deux, et les moitiés rejoignent le tas ; le cercle de glyphes s’allume à l’impact.',anims:['coin qui frappe','bûche fendue','éclats','cercle de glyphes'],
  build(){const[bx,by]=at(0,.42,.05);return{ground:floor(),objs:[oct(BASALT,.1,{inlay:ringI(.95,.04,AEC[1])}),
   slab(circle(.3),.1,.42,woodMat(BARK,{inlay:q=>q.f==='top'?rp(SAND,.6+((Math.round(q.rad*T)%2)?.15:0),q.sx,q.sy):null}),{z:.05,key:-1}),
   ...logs(-.82,-.85,3,.3),...logs(.82,-.85,3,.3),logs(-.95,.75,2,.22)[0],logs(-.75,.75,2,.22)[1],barrel(.95,.9,WOOD,{h:.3}),
   dyn(4,(F,t,S)=>{const per=2.2,u=K?(t%per)/per:.0,fall=u>.55&&u<.62,hit=u>=.62,lift=u<.55?Math.sin(u/.55*Math.PI/2):u<.62?1-(u-.55)/.07:0,wy=by-12-Math.round((K?lift:1)*22),sep=hit?Math.round(ease(clamp((u-.62)/.3))*9):0;
    // bûche (deux moitiés)
    if(!hit||u<.95)for(const s of[-1,1])for(let j=0;j<12;j++)for(let i=0;i<5;i++){const x=bx+s*(i+1+sep),y=by-12+j+(hit?Math.round(sep*.4):0);F.set(x,y,i===4?BARK[2]:i===0?SAND[5]:SAND[3+(j%3===0?1:0)])}
    // coin
    const wy2=hit?by-16:wy;for(let j=0;j<12;j++){const w=Math.max(0,6-Math.floor(j/2));for(let i=-w;i<=w;i++)F.set(bx+i,wy2-6+j,BASALT[j<2?6:i<-1?5:i>2?2:4])}for(let i=-5;i<=5;i++)F.set(bx+i,wy2-3,AEC[K?2:0]);
    if(K&&hit&&u<.75){for(let k=0;k<64;k++){const a=k*TAU/64,[x,y]=at(Math.cos(a)*.95,.1,Math.sin(a)*.95);for(const d of[-1,0,1])if(S.P.get(x,y+d)===AEC[1])F.set(x,y+d,AEC[3])}
     sparkC(bx,by-12,['#a08a5e','#c8b080','#e6d6a8'],10,6,10,14,per,.08)(F,t-per*.62)}},[LT(0,.6,0,40,.7,VIOBLUE,.15)])]}}},
 {g:'scierie',name:'Meule défibreuse',desc:'Une meule de pierre roule en rond dans une auge circulaire, entraînée par un bras d’Aether. Elle écrase les copeaux en fibre, qu’on suspend à sécher.',anims:['meule qui roule','bras tournant','fibre qui s’envole','séchoir'],
  build(){const[ax,ay]=at(0,1.05,-.1);return{ground:floor(),objs:[disc(DSTONE,1.28,.08),
   slab(ringShape(.42,.86),.08,.34,stone(SLATE,{noise:.1,inlay:q=>q.f==='top'&&q.rad>.5&&q.rad<.8?rp(FIB,.45+(hash(q.sx,q.sy,3)-.5)*.5,q.sx,q.sy):null}),{z:-.1,key:-3}),
   slab(circle(.12),.08,1.05,iMat({inlay:vlineI(AEC[1],.03,.2,.9)}),{z:-.1,key:-2,mask:true}),
   post(-1.05,.85,.9,WOOD,.04),post(-.45,.85,.9,WOOD,.04),box(-.75,.85,.34,.03,.84,.9,woodMat(WOOD,{along:'x'}),{key:.9}),
   dyn(4,(F,t,S)=>{const B=behind(F,S),a=K?t*.9:.6,front=Math.sin(a)>0,D=front?F:B,[wx,wy]=at(Math.cos(a)*.64,.46,-.1+Math.sin(a)*.64),hw=Math.max(2,Math.round(9*Math.abs(Math.sin(a))));
    D.line(ax,ay,wx,wy-2,WOOD[4]);D.line(ax,ay+1,wx,wy-1,WOOD[2]);
    for(let j=-9;j<=9;j++)for(let i=-hw;i<=hw;i++){const e=i*i/(hw*hw)+j*j/81;if(e>1)continue;const roll=K?Math.floor(t*8+j/3)%3:0;D.set(wx+i,wy+j,e>.7?QZ[0]:QZ[(i<0?4:2)-(roll===0&&Math.abs(i)<hw-1?1:0)])}
    const[hx,hy]=at(0,1.1,-.1);F.set(hx,hy,AEC[K?3:1]);
    const[rx,ry]=at(-.75,.86,.85);for(let k=0;k<5;k++){const sw=K?Math.round(Math.sin(t*2+k)*1):0;for(let j=1;j<9+k%3*2;j++)F.set(rx-10+k*5+(j>4?sw:0),ry+j,FIB[(j+k)%3+1])}
    if(K)for(let k=0;k<6;k++){const p=(t*.35+hash(k,1,8))%1;F.set(Math.round(wx+(hash(k,2,8)-.5)*16+p*6),Math.round(wy-6-p*16),FIB[p<.5?3:2])}},[LT(0,1.1,-.1,32,.6,VIOBLUE)])]}}},
 {g:'scierie',name:'Tour à bois',desc:'Un long banc de tour : le volant d’Aether entraîne le fût, le ciseau court le long de la pièce et en tire de longs copeaux qui s’enroulent et tombent.',anims:['fût qui tourne','ciseau qui court','copeaux en spirale','volant'],
  build(){const[hx,hy]=at(-.78,.98,-.05),[tx,ty]=at(0,.78,-.05);return{ground:floor(),objs:[slab(square(1.28),0,.08,stone(SLATE,{noise:.08}),{key:-9}),
   box(0,-.05,.95,.2,.08,.5,woodMat(WOOD,{along:'x'}),{key:-1}),box(-.78,-.05,.16,.22,.5,1.0,iMat(),{key:-.8}),box(.8,-.05,.1,.16,.5,.86,iMat(),{key:-.8}),
   planks(.55,.95,3,.42),...[[-.95,.95],[-.8,.95]].map(([x,z])=>slab(circle(.04),0,1.1,woodMat(SAND),{x,z,key:z})),
   dyn(4,(F,t)=>{const r=5,x0=hx+8,x1=tx+30,roll=K?Math.floor(t*14):0;for(let x=x0;x<=x1;x++)for(let j=-r;j<=r;j++){const v=j/r,s=((x+roll+j*2)%6+6)%6<1;F.set(x,ty+j,s?SAND[3]:SAND[v<-.4?6:v<.4?5:4])}
    wheelDyn(hx-2,hy,11,6,K?6:0,IRON,{thick:1})(F,t);F.set(hx-2,hy,AEC[K?3:1]);
    const u=K?(t%5)/5:.3,cx=Math.round(x0+4+(x1-x0-8)*(u<.8?u/.8:1-(u-.8)/.2));for(let j=0;j<8;j++){F.set(cx,ty+r+1+j,IRON[5]);F.set(cx+1,ty+r+1+j,IRON[3])}F.set(cx,ty+r,SILVER[4]);
    if(K&&u<.8){for(let k=0;k<3;k++){const p=((t*.9+k/3)%1);curl(F,cx-2-p*4,ty-r-2+p*24,p+k)}}
    for(let k=0;k<6;k++)curl(F,tx-20+k*8,ty+19+(k%2),k*.7)},[LT(-.78,1,0,30,.6,VIOBLUE)])]}}},

// ======================= ARCHERIE =======================
 {g:'archerie',name:'Butte de tir',desc:'Une butte de paille et sa cible, face à un grand arc d’essai dressé sur son chevalet. L’arc se tend seul, décoche, et la flèche va se planter dans la cible.',anims:['arc qui se tend','flèche en vol','cible qui tremble','empennage d’Aether'],
  build(){const[cx,cy]=at(.55,.78,-.55),[ax,ay]=at(-.7,.72,.55);return{ground:floor(),objs:[slab(square(1.28),0,.06,stone(SANDL,{noise:.2}),{key:-9}),
   slab(rect(-.38,-.24,.38,.24),.06,1.2,stone(SAND,{noise:.25,courses:.12,joint:.3}),{x:.55,z:-.7,key:-2}),
   post(-.7,.55,.75,WOOD,.05),post(-.86,.4,.55,WOOD,.04),post(-.54,.4,.55,WOOD,.04),rack(.4,.75,3),
   dyn(4,(F,t)=>{const per=2.5,u=K?(t%per)/per:0,shake=K&&u>.62&&u<.75?Math.round(Math.sin(u*120)):0;
    pdisk(F,cx+shake,cy,10,(i,j,d)=>d>9.3?WOOD[2]:d<2?REDC[3]:d<4.5?PARCH[4]:d<7?REDC[2]:PARCH[3]);
    const stuck=K?Math.min(3,Math.floor(t/per)%4):1;for(let k=0;k<stuck;k++){const sx=cx+shake-4+k*4,sy=cy-3+k*3;F.line(sx,sy,sx-7,sy+3,WOOD[4]);F.set(sx-7,sy+3,FEA[3]);F.set(sx-7,sy+2,FEA[2])}
    const pull=K?(u<.5?Math.round(ease(u/.5)*7):0):0;bowV(F,ax,ay,13,pull);
    if(K&&u<.5)arrowL(F,ax-pull-1,ay,ax+8,ay,FEA,true);
    if(K&&u>=.5&&u<.62){const p=(u-.5)/.12,x=ax+(cx-ax)*p,y=ay+(cy-ay)*p-Math.sin(p*Math.PI)*8;arrowL(F,x-10,y+Math.round((cy-ay)/30),x,y,FEA,true)}},[LT(-.7,.8,.55,26,.5,VIOBLUE)])]}}},
 {g:'archerie',name:'Carrousel d’empennage',desc:'Une roue horizontale porte les flèches debout. Elle tourne devant un panier de plumes : chaque flèche qui passe reçoit son empennage, qui s’éclaire d’Aether.',anims:['roue des flèches','plumes qui volent','empennages lumineux'],
  build(){return{ground:floor(),objs:[oct(WOOD,.1,{inlay:ringI(1.05,.035,AEC[0])}),slab(circle(.3),.1,.3,iMat(),{key:-3}),
   slab(circle(.07),.3,1.3,woodMat(WOOD),{key:-2,mask:true}),barrel(.92,.92,LEATHER,{h:.32,r:.17}),crate(-.95,.9,.15),
   dyn(4,(F,t,S)=>{const B=behind(F,S),a0=K?t*.6:.3,[hx,hy]=at(0,.7,0);
    for(let k=0;k<96;k++){const a=k*TAU/96,[x,y]=at(Math.cos(a)*.86,.7,Math.sin(a)*.86),D=Math.sin(a)>-.1?F:B;D.set(x,y,WOOD[Math.sin(a)<0?5:4]);D.set(x,y+1,WOOD[2])}
    const order=[...Array(10).keys()].sort((p,q)=>Math.sin(a0+p*TAU/10)-Math.sin(a0+q*TAU/10));
    for(const k of order){const a=a0+k*TAU/10,D=Math.sin(a)>-.1?F:B,[x,y]=at(Math.cos(a)*.86,.7,Math.sin(a)*.86),done=Math.cos(a)<.2;
     for(let j=0;j<18;j++)D.set(x,y-j,WOOD[4]);D.set(x,y-18,SILVER[4]);D.set(x,y-19,SILVER[3]);
     if(done){D.set(x-1,y-2,AEC[K?2:1]);D.set(x+1,y-2,AEC[K?3:1]);D.set(x-1,y-3,FEA[2]);D.set(x+1,y-3,FEA[3]);D.set(x-1,y-4,FEA[2]);D.set(x+1,y-4,FEA[3])}}
    D2:{const[bx,by]=at(.92,.32,.92);if(K)for(let k=0;k<5;k++){const p=(t*.4+hash(k,1,4))%1,x=Math.round(bx-p*16+Math.sin(t*3+k)*2),y=Math.round(by-p*14+Math.sin(p*7)*2);F.set(x,y,FEA[3]);F.set(x+1,y,FEA[2])}
     for(let i=-3;i<=3;i++)F.set(bx+i,by-1-(i&1),FEA[3])}
    F.set(hx,hy-14,AEC[K?3:1])},[LT(0,1.0,0,34,.6,VIOBLUE)])]}}},
 {g:'archerie',name:'Cintreuse à vapeur',desc:'Une étuve de planches crache sa vapeur ; à côté, un gabarit de pierre en croissant. La latte attendrie s’y plie en arc sous les serre-joints, puis rejoint le râtelier.',anims:['latte qui se cintre','vapeur de l’étuve','serre-joints','arcs suspendus'],
  build(){const[gx,gy]=at(.35,.62,.35),[sx,sy]=at(-.65,.75,-.55);return{ground:floor(),objs:[slab(square(1.28),0,.08,stone(SLATE,{noise:.08}),{key:-9}),
   box(-.6,-.55,.6,.2,.3,.72,woodMat(WOOD,{along:'x'}),{key:-2}),post(-1.1,-.55,.3,WOOD,.05),post(-.1,-.55,.3,WOOD,.05),barrel(-1.0,.6,IRON,{h:.4,water:1}),
   slab(rect(-.5,-.18,.5,.18),.08,.5,stone(BASALT,{noise:.08,inlay:bandI(.3,.7,AEC[1],.2,3)}),{x:.35,z:.35,key:.1}),
   {key:-1.5,draw(L){const[a,b]=at(.6,1.6,-.9);L.rect(a-24,b,40,2,WOOD[3]);for(let k=0;k<3;k++){const x=a-18+k*12;for(let j=0;j<16;j++){const v=(j-8)/8;L.set(x+Math.round((1-v*v)*4),b+3+j,WOOD[4]);L.set(x+1+Math.round((1-v*v)*4),b+3+j,WOOD[2])}L.line(x,b+3,x,b+18,STRING)}return{}}},
   post(.95,-.9,1.6,BARK,.04),post(.25,-.9,1.6,BARK,.04),
   dyn(4,(F,t)=>{const per=5,u=K?(t%per)/per:.0,bend=K?ease(clamp((u-.15)/.5)):0;
    for(let i=-20;i<=20;i++){const v=i/20,y=gy-8-Math.round(bend*(1-v*v)*-9)+0;const yy=gy-10-Math.round(bend*9)+Math.round(bend*v*v*9);F.set(gx+i,yy-1,SAND[6]);F.set(gx+i,yy,SAND[5]);F.set(gx+i,yy+1,WOOD[3])}
    for(const s of[-12,0,12]){const v=s/20,y=gy-8-Math.round(bend*9)+Math.round(bend*v*v*9);for(let j=-2;j<=3;j++)F.set(gx+s,y+j,IRON[j<0?5:3]);F.set(gx+s+1,y-2,IRON[6])}
    if(K){steamDyn(sx,sy-4,22,3)(F,t);steamDyn(sx+12,sy-3,18,6)(F,t);steamDyn(sx-12,sy-2,16,9)(F,t)}},[LT(.35,.6,.35,26,.5,VIOBLUE)])]}}},
 {g:'archerie',name:'Carquois-totem',desc:'Un carquois géant de bois cerclé de cuir, gravé d’Aether. Les flèches finies en jaillissent en gerbe, tournent au-dessus et y redescendent se ranger.',anims:['gerbe de flèches','flèches qui tournent','glyphes du fût'],
  build(){const[tx,ty]=at(0,1.75,-.1);return{ground:floor(),objs:[disc(WOOD,1.28,.1,{inlay:ringI(1.0,.04,LEATHER[2])}),
   slab(circle(.38),.1,1.75,woodMat(WOOD,{horiz:0,inlay:q=>q.f==='side'&&(Math.abs(q.v-.2)<.04||Math.abs(q.v-.8)<.04)?rp(LEATHER,.5+q.b*.3,q.sx,q.sy):q.f==='side'&&q.n[1]>.4&&Math.abs(q.x)<.04&&q.v>.3&&q.v<.7?AEC[1]:q.f==='top'?rp(DSTONE,.2,q.sx,q.sy):null}),{z:-.1,key:-2,taper:[.85,1.1]}),
   ...[[-1.0,.85],[1.0,.85]].map(([x,z])=>column(x,z,.5,WOOD,{flame:'vb',light:VIOBLUE})),crate(.9,-.95,.15),
   dyn(4,(F,t)=>{for(let k=0;k<6;k++){const x=tx-8+k*3;arrowL(F,x,ty-1,x+(k%2),ty-8-(k%3),FEA,false)}
    if(K){for(let k=0;k<8;k++){const p=(t*.25+k/8)%1,h=Math.sin(p*Math.PI),a=p*TAU*1.5+k,x=tx+Math.round(Math.cos(a)*16*h),y=ty-10-Math.round(h*30);
     arrowL(F,x,y+6,x+Math.round(Math.sin(a)*2),y-4,FEA,true)}}
    else F.set(tx,ty-12,AEC[1])},[LT(0,1.9,-.1,40,.7,VIOBLUE,.1)])]}}},
 {g:'archerie',name:'Corderie aux arcs',desc:'Deux poteaux et une corde tendue que la roue d’Aether torsade sans fin. La corde vibre ; les arcs prêts pendent aux poteaux, cordés un à un.',anims:['roue qui torsade','corde qui défile','corde qui vibre','arcs pendus'],
  build(){const[ax,ay]=at(-.95,1.05,-.2),[bx,by]=at(.95,1.05,-.2);return{ground:floor(),objs:[slab(rect(-1.28,-.6,1.28,1.0),0,.08,woodMat(WOOD,{along:'x'}),{key:-9}),
   post(-.95,-.2,1.5,BARK,.08),post(.95,-.2,1.5,BARK,.08),box(-.95,-.2,.12,.12,1.5,1.58,iMat(),{key:-.1}),
   barrel(-.6,.75,WOOD,{h:.28,r:.16}),crate(.55,.8,.15),
   {key:-.05,draw(L){for(const s of[-1,1]){const[a,b]=at(s*.95,1.3,-.08);for(let k=0;k<2;k++){const x=a+s*(5+k*5);for(let j=0;j<12;j++){const v=(j-6)/6;L.set(x+Math.round((1-v*v)*3),b+j,WOOD[4]);L.set(x+1+Math.round((1-v*v)*3),b+j,WOOD[2])}L.line(x,b,x,b+12,STRING)}}return{}}},
   dyn(4,(F,t)=>{wheelDyn(ax,ay,8,4,K?4:0,WOOD,{thick:1})(F,t);F.set(ax,ay,AEC[K?3:1]);const vib=K?Math.sin(t*40):0;
    for(let x=ax+8;x<=bx-2;x++){const v=(x-ax)/(bx-ax),y=ay+Math.round(Math.sin(v*Math.PI)*(2+vib*1.2)),tw=((x*2+(K?Math.floor(t*10):0))%4+4)%4;F.set(x,y,tw<2?BONE[4]:BONE[2]);F.set(x,y+1,BONE[1])}
    const[hx,hy]=at(-.95,1.05,-.2);F.line(hx-2,hy-8,hx-2,hy+8,WOOD[4]);if(K&&Math.floor(t*3)%2)F.set(hx-2,hy-8,AEC[3])},[LT(-.95,1.1,-.2,28,.6,VIOBLUE)])]}}},

// ======================= ARMURERIE =======================
 {g:'creuset',name:'Mannequin martelé',desc:'Un plastron sur son mannequin, au milieu d’un dais de basalte. Deux marteaux en lévitation le frappent tour à tour ; les lingots attendent sur le côté.',anims:['deux marteaux alternés','étincelles','plastron chauffé','lingots'],
  build(){const[mx,my]=at(0,1.0,0);return{ground:floor(),objs:[oct(BASALT,.12,{inlay:ringI(1.04,.04,AEC[1])}),slab(circle(.4),.12,.26,dMat(),{key:-2}),
   mannequin(0,0,{}),ingotsObj(-.85,.8,COPPER,3),ingotsObj(.85,.85,IRON,3),brazier(-1.0,-.85,BASALT,'vb',VIOBLUE),brazier(1.0,-.85,BASALT,'vb',VIOBLUE),
   dyn(4,(F,t)=>{const per=1.4,u=K?(t%per)/per:.3;for(const s of[-1,1]){const ph=(u+(s>0?.5:0))%1,lift=ph<.75?Math.sin(ph/.75*Math.PI/2):1-(ph-.75)/.25,hx=mx+s*(9+Math.round(lift*8)),hy=my-6-Math.round(lift*10);
     floatHammer(F,hx,hy,s>0?-.6:-2.5);if(K&&ph>.93)sparkC(mx+s*6,my-6,['#f2800e','#ffc83a','#fff6c0'],8,3+s,10,8)(F,t)}
    if(K)for(let j=0;j<4;j++)for(let i=-3;i<=3;i++)if(hash(i,j,Math.floor(t*6))>.6)F.set(mx+i,my-8+j,MOLT[2])},[LT(0,1.0,0,40,.7,HOT,.2)])]}}},
 {g:'creuset',name:'Grande meule',desc:'Une meule de grès dressée dans son bâti, les pieds dans une auge d’eau. Une lame s’y affûte seule, dans une longue gerbe d’étincelles.',anims:['meule qui tourne','lame qui va et vient','gerbe d’étincelles','eau de l’auge'],
  build(){const[cx,cy]=at(0,1.0,-.15);return{ground:floor(),objs:[slab(square(1.28),0,.08,stone(SLATE,{noise:.08}),{key:-9}),
   slab(rect(-.55,-.22,.55,.22),.08,.36,q=>q.f==='top'?rp(WATER,.5+(hash(q.sx,q.sy,2)-.5)*.4,q.sx,q.sy):stone(DSTONE,{noise:.1})(q),{z:-.15,key:-2}),
   post(-.42,-.15,1.15,WOOD,.06),post(.42,-.15,1.15,WOOD,.06),rack(.85,.75,3),ingotsObj(-.85,.85,IRON,3),
   dyn(4,(F,t)=>{const a=K?t*5:0;pdisk(F,cx,cy,19,(i,j,d)=>{if(d<2.5)return IRON[5];const an=Math.atan2(j,i)-a,s=((an*6/TAU)%1+1)%1;return d>17.5?SAND[i+j<0?6:3]:SAND[(s<.07?3:i+j<-6?6:i+j>8?4:5)]});
    for(let i=-21;i<=21;i++)F.set(cx+i,cy,IRON[4]);
    const u=K?Math.sin(t*2.4)*.5+.5:.5,lx=cx+14+Math.round(u*4),ly=cy-14-Math.round(u*6);for(let k=0;k<16;k++){F.set(lx+k,ly-Math.round(k*.6),SILVER[4]);F.set(lx+k,ly+1-Math.round(k*.6),SILVER[2])}for(let j=-3;j<=3;j++)F.set(lx+16,ly-10+j,IRON[5]);F.set(lx+17,ly-10,LEATHER[2]);
    if(K){for(let k=0;k<18;k++){const p=((t*2.2+hash(k,1,5))%1),ang=-2.6+(hash(k,2,5)-.5)*.7,r=p*34;F.set(Math.round(cx+13+Math.cos(ang)*r),Math.round(cy-13+Math.sin(ang)*r*-.6+p*p*18),MOLT[p<.3?4:p<.6?3:2])}}},[LT(0,1.0,-.1,36,.6,HOT,.25)])]}}},
 {g:'creuset',name:'Presse à emboutir',desc:'Deux colonnes de fer, une vis géante et son volant à bras. Le plateau descend sur la plaque de lingots : elle ressort bombée en bouclier et rejoint la pile.',anims:['volant de la vis','plateau qui descend','plaque emboutie','pile de boucliers'],
  build(){const[px,py]=at(0,.52,0),[tx,ty]=at(0,2.15,0);return{ground:floor(),objs:[oct(SLATE,.1),slab(rect(-.5,-.3,.5,.3),.1,.5,iMat({inlay:bandI(.2,.6,AEC[1],.18,7)}),{key:-2}),
   slab(square(.1),.1,2.1,iMat(),{x:-.62,key:-1.5}),slab(square(.1),.1,2.1,iMat(),{x:.62,key:-1.5}),box(0,0,.78,.16,1.9,2.1,iMat(),{key:2}),
   ingotsObj(-.9,.85,COPPER,3),{key:.85,draw(L){const[a,b]=at(.9,0,.85);for(let k=0;k<3;k++)L.ell(a,b-2-k*3,6,2.2,(x,y,dx,dy)=>rp(COPPER,.6-dx*.3-dy*.3,x,y));return{}}},
   dyn(4,(F,t,S)=>{const per=4,u=K?(t%per)/per:0,down=u<.35?ease(u/.35):u<.5?1:u<.8?1-ease((u-.5)/.3):0,pd=Math.round(down*20),pressed=u>.35&&u<.95;
    for(let j=ty+2;j<ty+2+(py-ty-22)+pd;j++){F.set(tx,j,IRON[(j%3)?4:2]);F.set(tx+1,j,IRON[2])}
    const B=behind(F,S),a=K?down*4:0;for(let k=0;k<4;k++){const an=a+k*Math.PI/2,D=Math.sin(an)>0?F:B,ex=tx+Math.round(Math.cos(an)*14),ey=ty-4+Math.round(Math.sin(an)*4);D.line(tx,ty-4,ex,ey,IRON[5]);D.set(ex,ey,AEC[K?3:1])}
    const yy=py-22+pd;for(let j=0;j<4;j++)for(let i=-13;i<=13;i++)F.set(px+i,yy+j,IRON[j===0?6:j===3?2:4]);
    if(!pressed||!K){for(let i=-7;i<=7;i++){F.set(px+i,py-2,COPPER[5]);F.set(px+i,py-1,COPPER[3])}}else for(let j=-3;j<=0;j++)for(let i=-8;i<=8;i++){if(i*i/64+j*j/9>1)continue;F.set(px+i,py-1+j,COPPER[j===-3?5:i<-3?5:i>4?2:4])}
    if(K&&u>.33&&u<.4)sparkC(px,py-3,['#f2800e','#ffc83a','#fff6c0'],10,9,8,16,per,.06)(F,t-per*.33)},[LT(0,.8,0,34,.6,VIOBLUE)])]}}},
 {g:'creuset',name:'Roue de trempe',desc:'Une grande roue de fer garnie de lames tourne lentement. Les lames sortent rouges du brasier, plongent dans le bassin dans un nuage de vapeur et remontent argentées.',anims:['roue des lames','lames qui refroidissent','vapeur du bassin','brasier'],
  build(){const[cx,cy]=at(0,1.05,-.2),[wx,wy]=at(0,.3,.35);return{ground:floor(),objs:[slab(square(1.28),0,.08,stone(BASALT,{noise:.08}),{key:-9}),
   slab(rect(-.7,-.3,.7,.3),.08,.32,q=>q.f==='top'&&Math.abs(q.x)<.6&&Math.abs(q.z)<.22?rp(WATER,.5+(hash(q.sx,q.sy,2)-.5)*.5,q.sx,q.sy):stone(DSTONE,{noise:.1})(q),{z:.35,key:1}),
   post(-.85,-.2,1.2,WOOD,.07),post(.85,-.2,1.2,WOOD,.07),brazier(-1.02,.9,BASALT,'orange',ORANGE),ingotsObj(1.0,.9,IRON,3),
   dyn(4,(F,t)=>{const a0=K?t*.7:.2,R=20;for(let k=0;k<72;k++){const a=k*TAU/72;F.set(Math.round(cx+Math.cos(a)*R),Math.round(cy+Math.sin(a)*R),IRON[Math.sin(a)<-.2?5:3])}
    for(let i=-24;i<=24;i++)F.set(cx+i,cy,WOOD[3]);F.set(cx,cy,AEC[K?3:1]);
    for(let k=0;k<8;k++){const a=a0+k*TAU/8,ex=cx+Math.cos(a)*R,ey=cy+Math.sin(a)*R;F.line(cx,cy,Math.round(ex),Math.round(ey),IRON[2]);
     const ph=((a%TAU)+TAU)%TAU,hot=ph>Math.PI*1.1&&ph<Math.PI*1.95,C=hot?HOTB:COLDB,ux=Math.cos(a),uy=Math.sin(a);for(let s=0;s<9;s++){F.set(Math.round(ex+ux*s),Math.round(ey+uy*s),C[s>6?0:1]);F.set(Math.round(ex+ux*s-uy),Math.round(ey+uy*s+ux),C[2])}}
    if(K){steamDyn(wx-6,wy-2,20,3)(F,t);steamDyn(wx+6,wy-3,18,7)(F,t)}},[LT(0,.5,.35,30,.6,HOT,.2)])]}}},
 {g:'creuset',name:'Autel de façonnage',desc:'Un autel de basalte aux glyphes d’Aether. Trois lingots s’élèvent, fondent en un ruban de métal, se reforment en lame qui se pose sur le râtelier.',anims:['lingots qui s’élèvent','ruban de métal','lame qui se forme','glyphes'],
  build(){const[ax,ay]=at(0,.62,0);return{ground:floor(),objs:[oct(BASALT,.1,{inlay:ringI(1.02,.035,AEC[0])}),
   slab(rect(-.55,-.32,.55,.32),.1,.52,stone(BASALT,{noise:.1,inlay:bandI(.3,.75,AEC[1],.16,5)}),{key:-2}),slab(rect(-.62,-.38,.62,.38),.52,.6,stone(BASALT,{noise:.06,inlay:ringI(.3,.03,AEC[1])}),{key:-1.9}),
   rack(.85,.8,3),ingotsObj(-.88,.85,COPPER,3),column(-1.0,-.9,.5,BASALT,{flame:'vb',light:VIOBLUE}),column(1.0,-.9,.5,BASALT,{flame:'vb',light:VIOBLUE}),
   dyn(4,(F,t)=>{const per=6,u=K?(t%per)/per:0;const rise=ease(clamp(u/.25)),melt=clamp((u-.3)/.2),form=clamp((u-.5)/.2);
    if(u<.5)for(let k=0;k<3;k++){const x=ax-12+k*9-Math.round(melt*(k-1)*9),y=ay-2-Math.round(rise*(16+k*2))-Math.round(melt*4);if(melt<1)for(let i=0;i<6-Math.round(melt*4);i++){F.set(x+i,y,MOLT[melt>.2?3:1]);F.set(x+i,y-1,melt>.2?MOLT[4]:COPPER[5]);F.set(x+i,y+1,COPPER[2])}}
    if(K&&u>=.4&&u<.7){for(let k=0;k<24;k++){const a=k/24*TAU+t*3,r=6*(1-form)+1;F.set(Math.round(ax+Math.cos(a)*r*1.6),Math.round(ay-22+Math.sin(a)*r),MOLT[k%3+2])}}
    if(K&&u>=.6){const p=clamp((u-.75)/.2),x=Math.round(ax+p*38),y=Math.round(ay-12-(1-form)*4+p*-6-Math.sin(p*Math.PI)*10);swordV(F,x,y,20,u<.75?HOTB:COLDB)}
    if(K&&u<.55)motes(ax,ay-2,14,24,['#5a5cff','#9aa0ff','#e0e4ff'],6,4)(F,t)},[LT(0,.9,0,44,.75,VIOBLUE,.12)])]}}},
];

function floorScene(){const S=new Scene();S.bake(floor(),[]);return S}
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
return{ITEMS,GROUPS,vignette,floorScene,setWork(v){K=v},ambient,exportSprite,get W(){return W},get H(){return H}}})();

