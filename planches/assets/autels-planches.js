'use strict';
// Planche « Autels des dieux » : 5 propositions par culte.
// Socle géométrique extrudé (vue 3/4 du jeu, 1 case = 20 px), piton central, statue du dieu au sommet.
const AUT=(()=>{
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

// ---------- cultes et propositions ----------
const VB=E('#7a80ff'),VBB=E('#c8ccff'),OR=E('#ff8a2a'),ORB=E('#ffc890'),GR=E('#7ae070'),GRB=E('#c8ffb0'),WH=E('#dfe4f0'),WHB=E('#ffffff');
// socle commun d'Aether : trois paliers de basalte cerclés d'argent
const aMat=o=>stone(BASALT,{courses:.18,joint:.55,trim:{R:SILVER,v0:.72,v1:1},...o});
const aBands=q=>q.f==='side'&&(Math.abs(q.v-.3)<.06||Math.abs(q.v-.6)<.06)?rp(SILVER,q.b+.2,q.sx,q.sy):null;
function aDiscs(o={}){return[slab(circle(2.0),0,.2,aMat({inlay:o.t1||anyI(dotsI(1.78,14,VB),ringI(1.62,.03,VBB))})),slab(circle(1.55),.2,.4,aMat({inlay:o.t2})),slab(circle(1.1),.4,.6,aMat({inlay:o.t3||anyI(dotsI(.9,8,VBB,.2),ringI(.8,.025,VB))}))]}
const aGround=()=>groundOf('grass',{shape:circle(2.35),pave:BASALT,grid:.45});
const sMat=o=>stone(MARBLE,{veins:1,courses:.18,joint:.6,noise:.08,...o});
const sGround=sh=>groundOf('grass',{shape:sh,pave:MARBLE,grid:.55});
const iMat=o=>stone(SAND,{courses:.18,joint:.6,trim:{R:COPPER,v0:.82,v1:1},...o});
const iGround=sh=>groundOf('dirt',{shape:sh,pave:SAND,grid:.5,r:2.8});
const STW=['#a8b0c4','#dfe4f0','#ffffff'],STV=['#7a80ff','#9aa0ff','#e0e4ff'];
const GODS={
 aether:{name:'Aether',color:'#7a80ff',light:VIOBLUE,epithet:'le dieu à la lyre',round:2,
  statue:'Jeune dieu debout, couronne de rayons, lyre tenue contre le flanc, faisceau de flèches levé, cape tombant jusqu’aux pieds.',
  intro:'Variations autour du Disque des sphères, toutes sans auréole derrière la tête : le dieu se découpe directement sur le décor.',
  items:[
  {chosen:true,name:'Disque des sphères',desc:'La proposition retenue du premier tour, sans l’auréole : trois paliers circulaires de basalte cerclés d’argent, anneau de constellations, colonne ronde à bagues d’argent.',
   build(){return{ground:aGround(),objs:[...aDiscs(),slab(circle(.3),.6,1.7,stone(BASALT,{trim:{R:SILVER,v0:.88,v1:1},inlay:aBands}),{taper:[1.15,1]}),statueObj('aether',1.7,'aether',{light:VIOBLUE})],
    fx:S=>[motes(OX,OY-10,40,40,STV,12,1)]}}},
  {name:'Sphères et pylônes',desc:'Le même disque, gardé par quatre pylônes d’argent posés en diagonale sur le premier palier, chacun coiffé d’une étoile.',
   build(){const objs=[...aDiscs(),slab(circle(.3),.6,1.7,stone(BASALT,{trim:{R:SILVER,v0:.88,v1:1},inlay:aBands}),{taper:[1.15,1]}),statueObj('aether',1.7,'aether',{light:VIOBLUE})];
    for(let i=0;i<4;i++){const a=Math.PI/4+i*Math.PI/2;objs.push(obelisk(Math.cos(a)*1.76,Math.sin(a)*1.76,.55,BASALT,VBB,{w:.1,light:VIOBLUE,y0:.2,glyph:1}))}
    return{ground:aGround(),objs,fx:S=>[motes(OX,OY-10,40,40,STV,10,2)]}}},
  {name:'Cadran céleste',desc:'Le premier palier devient un cadran gradué : trente-six graduations d’argent, une sur trois allumée. La colonne est plus fine, le dieu plus haut.',
   build(){return{ground:aGround(),objs:[...aDiscs({t1:anyI(ticksI(1.6,1.92,36,ci(SILVER[3]),.035,3,VBB),ringI(1.55,.025,VB)),t2:ticksI(1.2,1.45,12,VB,.04)}),
    slab(circle(.24),.6,1.85,stone(BASALT,{trim:{R:SILVER,v0:.9,v1:1},inlay:q=>q.f==='side'&&Math.abs(q.v-.45)<.05?rp(SILVER,q.b+.2,q.sx,q.sy):null})),statueObj('aether',1.85,'aether',{light:VIOBLUE})],
    fx:S=>[motes(OX,OY-10,40,40,STV,10,3)]}}},
  {name:'Disque des planètes',desc:'Disque des sphères, et trois petites planètes qui tournent autour de la colonne, à mi-hauteur, sous les pieds du dieu.',
   build(){return{ground:aGround(),objs:[...aDiscs(),slab(circle(.3),.6,1.7,stone(BASALT,{trim:{R:SILVER,v0:.88,v1:1},inlay:aBands}),{taper:[1.15,1],mask:1}),statueObj('aether',1.7,'aether',{light:VIOBLUE})],
    fx:S=>[orbit(OX,OY-20,30,10,3,['#5a5cff','#9aa0ff','#ffffff'],.6,2),orbit(OX,OY-14,40,13,2,['#8a90b0','#c4c8d2','#e4e6ee'],-.4,2)]}}},
  {name:'Vasque d’étoiles',desc:'La colonne s’évase en vasque remplie de lumière bleu-violet ; le dieu se tient debout dans la lumière, des étincelles montent autour de lui.',
   build(){const starW=q=>q.f==='top'&&!q.rim?(hash(q.sx,q.sy,7)<.1?VBB:hash(q.sx,q.sy,8)<.5?VB:E('#4a4cc8')):null;
    return{ground:aGround(),objs:[...aDiscs(),slab(circle(.2),.6,1.3,stone(BASALT,{trim:{R:SILVER,v0:.85,v1:1}})),slab(circle(.78),1.3,1.62,stone(SILVER,{noise:.06,inlay:starW}),{taper:[.3,1]}),
     statueObj('aether',1.62,'aether',{light:VIOBLUE}),{key:-9,draw(){const[a,b]=P3(0,1.62,0);return{lights:[{x:a,y:b,r:40,i:.7,c:VIOBLUE}]}}}],
    fx:S=>[motes(OX,OY-32,14,30,STV,14,5)]}}}]},
 indra:{name:'Indra',color:'#ff8a2a',light:ORANGE,epithet:'le dieu au bouclier',round:2,
  statue:'Guerrier au casque à cimier, lance tenue droite contre lui, bouclier rond serré sur le flanc, cape étroite : silhouette resserrée.',
  intro:'Statue resserrée : bouclier plus petit tenu contre le corps, lance collée au flanc, cape étroite. Cinq nouveaux autels.',
  items:[
  {name:'Arène',desc:'Dais rond de sable cerné d’un muret bas, comme une petite arène d’entraînement. Deux lances plantées derrière le muret, le dieu sur un piton rond au centre.',
   build(){return{ground:iGround(circle(2.3)),objs:[slab(circle(2.0),0,.15,iMat({courses:0,inlay:anyI(ringI(1.0,.035,OR),dotsI(1.25,8,ci(COPPER[4]),.2))})),
    slab(ringShape(1.55,1.9),.15,.5,iMat({courses:.17}),{key:-1.9}),slab(circle(.3),.15,1.6,stone(SAND,{trim:{R:COPPER,v0:.88,v1:1},inlay:q=>q.f==='side'&&Math.abs(q.v-.5)<.06?rp(ORNG,q.b+.1,q.sx,q.sy):null})),
    statueObj('indra',1.6,'indra',{light:ORANGE}),spear(-1.1,-1.95,0,1.9,[ORNG[2],ORNG[3],ORNG[4]]),spear(1.1,-1.95,0,1.9,[ORNG[2],ORNG[3],ORNG[4]])],
    fx:S=>[motes(OX,OY-20,30,30,['#ff8a2a','#ffb347','#ffe0a0'],5,3)]}}},
  {name:'Pavois',desc:'Dais carré à deux degrés ; six boucliers ronds sur poteaux l’entourent comme un mur de boucliers. Piton carré ceint d’orange.',
   build(){return{ground:iGround(square(2.2)),objs:[slab(square(1.6),0,.25,iMat()),slab(square(1.1),.25,.5,iMat({inlay:linesI([[[-.8,0],[.8,0]],[[0,-.8],[0,.8]]],.03,OR)})),
    slab(square(.28),.5,1.6,stone(SAND,{trim:{R:COPPER,v0:.88,v1:1},inlay:q=>q.f==='side'&&q.v>.4&&q.v<.58?rp(ORNG,q.b+.1,q.sx,q.sy):null})),statueObj('indra',1.6,'indra',{light:ORANGE}),
    ...[[-1.0,-1.95],[1.0,-1.95],[-2.0,-.6],[2.0,-.6],[-2.0,.9],[2.0,.9]].map(([x,z])=>shieldStand(x,z))]}}},
  {name:'Tambour de guerre',desc:'Le dais est un grand tambour : peau claire cerclée de cuivre, flancs laqués d’orange lacés de cordes. Le dieu se dresse sur un piton planté dans la peau.',
   build(){const drum=q=>{if(q.f==='top')return q.rad>1.55?rp(COPPER,.8,q.sx,q.sy):rp(BONE,.62+(vnoise(q.x*5,q.z*5,4)-.5)*.2,q.sx,q.sy);const l=lacingI(ci(BONE[3]))(q);if(l!=null)return l;if(q.v>.85||q.v<.12)return rp(COPPER,q.b+.1,q.sx,q.sy);return rp(ORNG,q.b-.1,q.sx,q.sy)};
    return{ground:iGround(circle(2.1)),objs:[slab(circle(1.75),0,.6,drum),slab(circle(.28),.6,1.6,stone(WOOD,{noise:.08,trim:{R:COPPER,v0:.85,v1:1}})),statueObj('indra',1.6,'indra',{light:ORANGE}),
     brazier(-2.15,.6,COPPER,'orange',ORANGE),brazier(2.15,.6,COPPER,'orange',ORANGE)]}}},
  {name:'Croix des lances',desc:'Plinthe en croix à deux degrés, orientée sur les quatre directions. Une lance plantée au bout de chaque bras arrière, une coupe de feu au bout du bras avant.',
   build(){return{ground:iGround(square(2.2)),objs:[slab(plus(1.95,.55),0,.28,iMat({courses:.14})),slab(plus(1.2,.38),.28,.5,iMat({inlay:ringI(.25,.03,OR)})),
    slab(square(.26),.5,1.6,stone(SAND,{trim:{R:COPPER,v0:.88,v1:1},inlay:bandI(.25,.6,OR,.09,3)})),statueObj('indra',1.6,'indra',{light:ORANGE}),
    spear(0,-1.7,.28,1.8,[ORNG[2],ORNG[3],ORNG[4]]),spear(-1.7,0,.28,1.8,[ORNG[2],ORNG[3],ORNG[4]]),spear(1.7,0,.28,1.8,[ORNG[2],ORNG[3],ORNG[4]]),fireBowl(0,1.7,.28)]}}},
  {chosen:true,name:'Foyer des guerriers',desc:'Octogone bas ; six coupes de feu en couronne sur le dessus entourent le piton, comme les feux d’un camp de guerriers.',
   build(){const objs=[slab(poly(8,1.95,Math.PI/8),0,.35,iMat({courses:.17,inlay:ringI(1.15,.03,OR)})),slab(circle(.3),.35,1.6,stone(SAND,{trim:{R:COPPER,v0:.88,v1:1},inlay:bandI(.3,.6,OR,.1,8)})),statueObj('indra',1.6,'indra',{light:ORANGE})];
    for(let i=0;i<6;i++){const a=-Math.PI/2+Math.PI/6+i*Math.PI/3;objs.push(fireBowl(Math.cos(a)*1.45,Math.sin(a)*1.45,.35))}
    return{ground:iGround(poly(8,2.25,Math.PI/8)),objs,fx:S=>[motes(OX,OY-14,34,40,['#ff8a2a','#ffb347','#ffe0a0'],8,4)]}}}]},
 medeina:{name:'Medeina',color:'#7ae070',light:GREEN,epithet:'la déesse à la lance',
  statue:'Gorgone à la chevelure de serpents, yeux verts luisants, lance tenue droite, main levée aux griffes, queue de serpent lovée au pied.',
  intro:'Choix retenu.',
  items:[{name:'Cercle de pierres',chosen:true,desc:'Dais rond de pierre moussue, entouré de six menhirs aux veines vertes. Colonne ronde ; la déesse de jade se dresse au centre, fleurs et champignons au pied des pierres.',
   build(){const objs=[slab(circle(1.75),0,.25,stone(MSTONE,{courses:.25,joint:.5,moss:.25,inlay:ringI(1.45,.03,GR)})),slab(circle(1.2),.25,.45,stone(MSTONE,{moss:.18,inlay:dotsI(.95,6,GRB,.5)})),
    slab(circle(.3),.45,1.6,stone(MSTONE,{moss:.25,courses:.2})),statueObj('medeina',1.6,'medeina',{light:GREEN})];
    for(let i=0;i<6;i++){const a=-Math.PI/2+.52+i*Math.PI/3;objs.push(menhir(Math.cos(a)*2.25,Math.sin(a)*1.95,.75+(i%2)*.2,GR,GREEN))}
    objs.push(bush(-2.6,1.4,3,1),bush(2.5,1.6,5,0));return{ground:groundOf('moss',{shape:circle(2.0),pave:MSTONE,grid:.5,moss:1}),objs,fx:S=>[motes(OX,OY-20,60,40,['#3ab048','#7ae070','#d0ffb8'],10,7)]}}}]},
 sigil:{name:'Sigil',color:'#f4f6ff',light:WHITEC,epithet:'celui à la capuche',round:2,
  statue:'Figure humaine encapuchonnée, debout sur ses pieds : visage dans l’ombre aux yeux blancs, bras levés coudes pliés, paumes ouvertes, bracelets et ankh lumineux.',
  intro:'La statue ne flotte plus : elle se tient debout, proportions humaines, pieds posés sur le piton. Cinq nouveaux autels de marbre gris veiné.',
  items:[
  {name:'Pile de livres',desc:'Trois degrés carrés de marbre ; le piton est une pile de grimoires légèrement décalés, tranches de parchemin et dos d’ardoise et de cuir. Le maître du savoir se tient dessus.',
   build(){const objs=[slab(square(1.7),0,.18,sMat()),slab(square(1.25),.18,.36,sMat()),slab(square(.8),.36,.52,sMat({inlay:ringI(.55,.03,WH)}))];let y=.52;
    for(let k=0;k<6;k++){const h=.14+hash(k,1,3)*.08,r=(.3+hash(k,2,3)*.07)*Math.SQRT2;objs.push(slab(poly(4,r,Math.PI/4+(hash(k,3,3)-.5)*.35),y,y+h,bookMat(k)));y+=h}
    objs.push(statueObj('sigil',y,'sigil',{light:WHITEC}));return{ground:sGround(square(2.05)),objs,fx:S=>[motes(OX,OY-30,26,40,STW,8,14)]}}},
  {chosen:true,name:'Rotonde',desc:'Dais rond à deux degrés ; huit colonnettes de marbre forment une rotonde basse autour du piton, sans toit.',
   build(){const objs=[slab(circle(2.0),0,.2,sMat({inlay:ringI(1.82,.03,WH)})),slab(circle(1.55),.2,.38,sMat({courses:0,inlay:dotsI(.8,8,WHB,Math.PI/8)})),
    slab(circle(.28),.38,1.6,stone(MARBLE,{noise:.05,inlay:q=>q.f==='side'&&(((q.ang*8/Math.PI)%1+1)%1)<.2?rp(MARBLE,q.b-.25,q.sx,q.sy):null})),statueObj('sigil',1.6,'sigil',{light:WHITEC})];
    for(let i=0;i<8;i++){const a=Math.PI/8+i*Math.PI/4,x=Math.cos(a)*1.3,z=Math.sin(a)*1.3;objs.push({key:z,draw(L){const R=MARBLE;prism(L,square(.13),{x,z,y0:.38,y1:.46,mat:stone(R,{noise:.05})});prism(L,circle(.085),{x,z,y0:.46,y1:1.0,mat:stone(R,{veins:1,noise:.05})});prism(L,square(.12),{x,z,y0:1.0,y1:1.08,mat:stone(R,{noise:.05})});return{}}})}
    return{ground:sGround(circle(2.3)),objs,fx:S=>[motes(OX,OY-14,26,36,STW,6,15)]}}},
  {name:'Escalier du savoir',desc:'Un bloc de marbre sur une large dalle, un escalier de trois marches y monte depuis le visiteur. Le piton carré, gravé d’une colonne de glyphes, porte la statue.',
   build(){const m=sMat();return{ground:sGround(square(2.15)),objs:[slab(square(1.85),0,.2,m),slab(rect(-.8,-1.0,.8,.45),.2,1.0,sMat({inlay:bandI(.25,.75,WH,.13,21)}),{key:-1.0}),
    ...[0,1,2].map(i=>slab(rect(-.5,.45+i*.3,.5,.75+i*.3),.2,1.0-(i+1)*.2,m,{key:.45+i*.3})),
    slab(square(.24),1.0,1.65,stone(MARBLE,{veins:1,inlay:vlineI(WH,.03,.15,.85)}),{x:0,z:-.25,key:-.3}),statueObj('sigil',1.65,'sigil',{light:WHITEC,z:-.25})],
    fx:S=>[motes(OX,OY-30,30,30,STW,6,16)]}}},
  {name:'Tablettes',desc:'Plateforme octogonale ; quatre stèles gravées de glyphes lumineux se dressent aux points cardinaux, tournées vers le centre. Piton octogonal.',
   build(){const st=(x,z,w,d)=>slab(rect(x-w,z-d,x+w,z+d),.28,1.15,stone(MARBLE,{veins:1,inlay:bandI(.25,.8,WH,.1,Math.round(x*7+z*13+40))}),{key:z+d});
    return{ground:sGround(poly(8,2.3,Math.PI/8)),objs:[slab(poly(8,2.0,Math.PI/8),0,.28,sMat({courses:.14,inlay:ringI(1.05,.03,WH)})),
     slab(poly(8,.33,Math.PI/8),.28,1.55,stone(MARBLE,{veins:1,inlay:bandI(.3,.7,WH,.11,17)})),statueObj('sigil',1.55,'sigil',{light:WHITEC}),
     st(0,-1.5,.32,.07),st(-1.5,0,.07,.32),st(1.5,0,.07,.32),st(0,1.5,.32,.07)]}}},
  {name:'Cadran solaire',desc:'Dais rond gravé en cadran : douze lignes horaires rayonnent du piton, qui sert de gnomon. Marques d’heures lumineuses sur le pourtour.',
   build(){return{ground:sGround(circle(2.3)),objs:[slab(circle(2.0),0,.22,sMat({courses:.22,inlay:anyI(ticksI(.5,1.62,12,ci(SLATE[1]),.025),dotsI(1.78,12,WHB,0),ringI(1.68,.025,WH))})),
    slab(circle(.3),.22,.38,sMat({courses:0})),slab(square(.2),.38,1.6,stone(SLATE,{noise:.06,trim:{R:MARBLE,v0:.9,v1:1}}),{taper:[1.2,.9]}),statueObj('sigil',1.6,'sigil',{light:WHITEC})]}}}]}};


function vignette(god,i){const g=GODS[god],b=g.items[i].build(),S=new Scene();
 // halo coloré au pied pour la nuit
 const objs=[...b.objs,{key:-9,draw(){const[a,c]=P3(0,0,0);return{lights:[{x:a,y:c-20,r:70,i:.25,c:g.light,add:.03}]}}}];
 S.bake(b.ground,objs);if(b.fx)S.dyn.push(...b.fx(S));return S}

// ---------- export vers le jeu ----------
// Sprite 320 × 240, ancre (160, 168) = centre de l’emprise au sol, 24 px par unité : le disque de rayon 2 couvre les 3 × 3 cases (96 px) ;
// pas de sol, ombres portées en noir translucide, couleurs non éclairées. Boucle de 24 images à 12 i/s.
const PICKS={aether:0,indra:4,sigil:1};
function exportSprite(god,frames=24,fps=12){const i=god==='medeina'?GODS.medeina.items.findIndex(it=>it.chosen):PICKS[god];
 configure(24,320,240,160,168);let S;try{const b=GODS[god].items[i].build();S=new Scene();S.bake(()=>-1,b.objs);if(b.fx)S.dyn.push(...b.fx(S))}finally{configure(20,208,168,104,118)}
 const cols=6,rows=Math.ceil(frames/cols),sheet=document.createElement('canvas');sheet.width=320*cols;sheet.height=240*rows;const g=sheet.getContext('2d');let top=240,bot=0;
 for(let f=0;f<frames;f++){const t=f/fps,F=S.F;F.c.set(S.P.c);for(const d of S.dyn)d(F,t,S);const img=g.createImageData(320,240),D=img.data;
  for(let k=0;k<320*240;k++){const v=F.c[k],o=k*4;if(v>=0){D[o]=v>>16&255;D[o+1]=v>>8&255;D[o+2]=v&255;D[o+3]=255;const y=(k/320)|0;if(y<top)top=y;if(y>bot)bot=y}else if(S.sh[k]>0)D[o+3]=Math.round(S.sh[k]*95)}
  g.putImageData(img,(f%cols)*320,((f/cols)|0)*240)}
 const base=document.createElement('canvas');base.width=320;base.height=240;base.getContext('2d').drawImage(sheet,0,0,320,240,0,0,320,240);
 // portrait du HUD : sprite réduit, centré, posé en bas d'un carré de 128 px
 const bd=base.getContext('2d').getImageData(0,0,320,240).data;let x0=320,x1=0,y0=240,y1=0;for(let y=0;y<240;y++)for(let x=0;x<320;x++)if(bd[(y*320+x)*4+3]===255){if(x<x0)x0=x;if(x>x1)x1=x;if(y<y0)y0=y;if(y>y1)y1=y}
 const por=document.createElement('canvas');por.width=por.height=128;const pg=por.getContext('2d'),w=x1-x0+1,h=y1-y0+1,k=Math.min(.5,120/w,124/h);pg.imageSmoothingEnabled=true;pg.imageSmoothingQuality='high';
 pg.drawImage(base,x0,y0,w,h,Math.round(64-w*k/2),Math.round(128-h*k),Math.round(w*k),Math.round(h*k));
 return{sheet,base,portrait:por,meta:{anchor:[160,168],top,bottom:bot,anim:{frame_w:320,frame_h:240,cols,rows,count:frames,seconds:frames/fps,fps,exact:true,seam_pixels:0}},pick:GODS[god].items[i].name}}

return{GODS,vignette,ambient,statue,exportSprite,get W(){return W},get H(){return H}}})();
