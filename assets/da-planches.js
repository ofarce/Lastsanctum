'use strict';
// Planches de direction artistique : petit moteur pixel (sprites, volumes projetés en 3/4 ou en isométrique,
// contour noir franc, éclairage jour/nuit avec halos en paliers tramés).
const DA=(()=>{
// ---------- couleurs ----------
const CM=new Map();
function ci(c){if(typeof c==='number')return c;let v=CM.get(c);if(v===undefined){v=parseInt(c.slice(1),16);CM.set(c,v)}return v}
const E=c=>ci(c)|0x1000000; // couleur émissive : non assombrie la nuit
function sh(c,k){const n=ci(c),em=n&0x1000000,f=v=>Math.max(0,Math.min(255,Math.round(k<0?v*(1+k):v+(255-v)*k)));return em|f(n>>16&255)<<16|f(n>>8&255)<<8|f(n&255)}
const R_=a=>a.map(ci);
const OUTL=ci('#0b0a0e'),EYE=ci('#1a120e');
function hash(x,y,s=0){let h=(Math.imul(x|0,374761393)+Math.imul(y|0,668265263)+Math.imul(s|0,982451653))|0;h=Math.imul(h^(h>>>13),1274126177);return((h^(h>>>16))>>>0)/4294967296}
function vnoise(x,y,s){const xi=Math.floor(x),yi=Math.floor(y),xf=x-xi,yf=y-yi,u=xf*xf*(3-2*xf),v=yf*yf*(3-2*yf),a=hash(xi,yi,s),b=hash(xi+1,yi,s),c=hash(xi,yi+1,s),d=hash(xi+1,yi+1,s);return a+(b-a)*u+(c-a)*v+(a-b-c+d)*u*v}
const BAY=[0,8,2,10,12,4,14,6,3,11,1,9,15,7,13,5].map(v=>(v+.5)/16),bay=(x,y)=>BAY[(y&3)*4+(x&3)];
function rp(R,v,x,y){const n=R.length-1,i=Math.floor(v*n+bay(x,y));return R[i<0?0:i>n?n:i]}
function rng(s){return()=>{s|=0;s=s+0x6D2B79F5|0;let t=Math.imul(s^s>>>15,1|s);t=t+Math.imul(t^t>>>7,61|t)^t;return((t^t>>>14)>>>0)/4294967296}}

// ---------- palettes ----------
const GRASS=R_(['#1c3822','#244a29','#2d5d30','#387234','#47873b','#5c9e44','#7ab450']);
const DIRT=R_(['#3a281a','#523620','#6a4a2a','#836034','#9a7642','#b08c54']);
const STONE=R_(['#232a35','#313a47','#424d5b','#55626f','#6b7885','#86929e','#a2acb6']);
const MOSS=R_(['#22401f','#2f5528','#3e6c31','#52833a']);
const LEAF=R_(['#10261a','#173a20','#1f4f27','#2a652e','#387b35','#4b923c','#66aa48','#8cc45c']);
const BARK=R_(['#24160e','#3a2416','#52341f','#6b4629','#835a36']);
const WOOD=R_(['#2a1a10','#40281a','#5a3a24','#74502f','#8e663c','#a87e4c']);
const THATCH=R_(['#3a2e16','#54441e','#6e5a26','#8a7232','#a68a40','#c0a452']);
const PALE=R_(['#4a4438','#655c4c','#807663','#9b907a','#b5aa92','#cdc3aa','#e2dac4']);
const TILE=R_(['#3c2216','#57311c','#724424','#8e582c','#a86e38','#c08648']);
const DARK=R_(['#15121b','#1f1a27','#2b2435','#383044','#463c54','#574b66']);
const GOLD=R_(['#5a4318','#80621e','#a88228','#c8a040','#e2c266','#f4dc94']);
const PRUNE=R_(['#140e18','#1e1424','#2a1c32','#382640','#48304e','#5a3c5e']);
const BASALT=R_(['#1a1816','#26221f','#342f2a','#433c35','#544b42','#675c50']);
const COPPER=R_(['#4a2410','#6e3a1a','#94522a','#b86c3a','#d48a50','#ecb070']);
const BRONZE=R_(['#5a3a18','#80562a','#a87a3a','#c89a50','#e2c27a']);
const WHITEL=[1.1,1.04,.88];
const CYAN=[.35,.95,1.15],AMBER=[1.2,.72,.3],GOLDL=[1.15,.95,.55],RED=[1.2,.22,.18],VIOLET=[.8,.4,1.2],GREEN=[.5,1.2,.5],ORANGE=[1.3,.62,.22],WHITEC=[1.08,1.1,1.2],VIOBLUE=[.62,.64,1.35];
const MARBLE=R_(['#3c3c42','#535259','#6b6a72','#85848b','#9e9da3','#b4b2b6','#c6c4c6']);
function marbleV(v,x,y){const n=vnoise(x*.09,y*.09,77),m=vnoise(x*.21,y*.21,78);if(Math.abs(n-.5)<.016||Math.abs(m-.5)<.008)return rp(MARBLE,Math.max(0,v-.32),x,y);return rp(MARBLE,v+(n-.5)*.16,x,y)}
const SLATE=R_(['#1e2430','#2a3240','#3a4454','#4c5868','#5e6c7e']);
const ORNG=R_(['#5a1e06','#8a3410','#b8501a','#e07028','#f89a48']);
const SILVER=R_(['#4a4e5a','#6e7482','#9aa0ae','#c4c8d2','#e4e6ee']);
const DOMEV=R_(['#1a1630','#262044','#342c5a','#443a72','#58508c']);
const EX={olive:'#5c623f',olive2:'#4b5245',steel:'#8b939d',steelD:'#4a515a',gun:'#2f343b',cy:E('#5ce8ff'),cyD:E('#2fb8d8'),skin:'#d6a37f',boot:'#2b2824'};

// ---------- tampon de pixels ----------
class Pix{constructor(w,h){this.w=w;this.h=h;this.c=new Int32Array(w*h).fill(-1);this.bx0=w;this.by0=h;this.bx1=-1;this.by1=-1}
 set(x,y,c){x=Math.floor(x);y=Math.floor(y);if(x<0||y<0||x>=this.w||y>=this.h||c==null)return;if(typeof c!=='number')c=ci(c);if(c<0)return;this.c[y*this.w+x]=c;if(x<this.bx0)this.bx0=x;if(x>this.bx1)this.bx1=x;if(y<this.by0)this.by0=y;if(y>this.by1)this.by1=y}
 del(x,y){if(x>=0&&y>=0&&x<this.w&&y<this.h)this.c[y*this.w+x]=-1}
 get(x,y){return x<0||y<0||x>=this.w||y>=this.h?-1:this.c[y*this.w+x]}
 rect(x,y,w,h,c){x=Math.round(x);y=Math.round(y);w=Math.round(w);h=Math.round(h);const f=typeof c==='function';for(let j=y;j<y+h;j++)for(let i=x;i<x+w;i++)this.set(i,j,f?c(i,j):c)}
 ell(cx,cy,rx,ry,c){const f=typeof c==='function';for(let j=Math.floor(cy-ry);j<=Math.ceil(cy+ry);j++)for(let i=Math.floor(cx-rx);i<=Math.ceil(cx+rx);i++){const dx=(i+.5-cx)/rx,dy=(j+.5-cy)/ry;if(dx*dx+dy*dy<=1)this.set(i,j,f?c(i,j,dx,dy):c)}}
 line(x0,y0,x1,y1,c){const n=Math.max(1,Math.ceil(Math.max(Math.abs(x1-x0),Math.abs(y1-y0))));for(let k=0;k<=n;k++)this.set(Math.round(x0+(x1-x0)*k/n),Math.round(y0+(y1-y0)*k/n),c)}
 outline(col=OUTL){if(this.bx1<0)return;const w=this.w,h=this.h,s=this.c,n=new Int32Array(s);
  for(let y=Math.max(0,this.by0-1);y<=Math.min(h-1,this.by1+1);y++)for(let x=Math.max(0,this.bx0-1);x<=Math.min(w-1,this.bx1+1);x++){const i=y*w+x;if(s[i]!==-1)continue;if((x>0&&s[i-1]!==-1)||(x<w-1&&s[i+1]!==-1)||(y>0&&s[i-w]!==-1)||(y<h-1&&s[i+w]!==-1))n[i]=col}
  this.c=n;this.bx0=Math.max(0,this.bx0-1);this.by0=Math.max(0,this.by0-1);this.bx1=Math.min(w-1,this.bx1+1);this.by1=Math.min(h-1,this.by1+1)}
 blit(s,dx,dy){dx=Math.round(dx);dy=Math.round(dy);for(let y=s.by0;y<=s.by1;y++)for(let x=s.bx0;x<=s.bx1;x++){const v=s.c[y*s.w+x];if(v!==-1)this.set(x+dx,y+dy,v)}}}
// rectangle ombré : lumière en haut à gauche
function sr(P,x,y,w,h,c,k=.18){x=Math.round(x);y=Math.round(y);w=Math.round(w);h=Math.round(h);if(w<=0||h<=0)return;P.rect(x,y,w,h,c);if(w>2){P.rect(x,y,1,h,sh(c,k));P.rect(x+w-1,y,1,h,sh(c,-k*1.5))}if(h>3)P.rect(x+(w>2?1:0),y+h-1,w-(w>2?2:0),1,sh(c,-k*1.3))}

// ---------- projections ----------
let CT=20;
function proj34(T,ox,oy){return{iso:false,T,p:(x,y,z)=>[ox+x*T,oy+z*T-y*T],inv:(sx,sy)=>[(sx-ox)/T,(sy-oy)/T],depth:(x,z)=>z*100+x*.01}}
function projIso(T,ox,oy){return{iso:true,T,p:(x,y,z)=>[ox+(x-z)*T,oy+(x+z)*T/2-y*T],inv:(sx,sy)=>{const a=(sx-ox)/T,b=(sy-oy)/(T/2);return[(a+b)/2,(b-a)/2]},depth:(x,z)=>(x+z)*100+x*.01}}
function quad(L,O,A,B,fn,tri){const ax=A[0]-O[0],ay=A[1]-O[1],bx=B[0]-O[0],by=B[1]-O[1],det=ax*by-ay*bx;if(Math.abs(det)<.01)return;const xs=[O[0],A[0],B[0],A[0]+bx],ys=[O[1],A[1],B[1],A[1]+by];
 for(let y=Math.floor(Math.min(...ys));y<=Math.ceil(Math.max(...ys));y++)for(let x=Math.floor(Math.min(...xs));x<=Math.ceil(Math.max(...xs));x++){const px=x+.5-O[0],py=y+.5-O[1],u=(px*by-py*bx)/det,v=(ax*py-ay*px)/det;if(u<-1e-6||v<-1e-6||u>1+1e-6||v>1+1e-6||(tri&&u+v>1+1e-6))continue;const c=fn(u,v,x,y);if(c!=null&&c>=0)L.set(x,y,c)}}
const FB={top:.92,south:.68,east:.5,roofS:.82,roofN:.55,gable:.62,roofW:.82,roofE:.6};
function box(L,ctx,x0,z0,x1,z1,y0,h,mat){const p=ctx.p,Y=y0+h,W=x1-x0,D=z1-z0;
 if(h>0){quad(L,p(x0,Y,z1),p(x1,Y,z1),p(x0,y0,z1),(u,v,x,y)=>mat('south',u*W,v*h,x,y));if(ctx.iso)quad(L,p(x1,Y,z1),p(x1,Y,z0),p(x1,y0,z1),(u,v,x,y)=>mat('east',u*D,v*h,x,y))}
 quad(L,p(x0,Y,z0),p(x1,Y,z0),p(x0,Y,z1),(u,v,x,y)=>mat('top',u*W,v*D,x,y))}
function gableZ(L,ctx,x0,z0,x1,z1,y,rh,ov,roof,wall,ridge){const p=ctx.p,xm=(x0+x1)/2,X0=x0-ov,X1=x1+ov,Z0=z0-ov,Z1=z1+ov,ey=y-rh*ov/(xm-x0),ry=y+rh,sl=Math.hypot(xm-X0,ry-ey),Dd=Z1-Z0;
 quad(L,p(xm,ry,Z0),p(xm,ry,Z1),p(X0,ey,Z0),(u,v,x,yy)=>roof('roofW',u*Dd,v*sl,x,yy));quad(L,p(xm,ry,Z0),p(xm,ry,Z1),p(X1,ey,Z0),(u,v,x,yy)=>roof('roofE',u*Dd,v*sl,x,yy));
 quad(L,p(x0,y,z1),p(x1,y,z1),p(xm,ry,z1),(u,v,x,yy)=>wall('gable',u*(x1-x0),v*rh,x,yy),true);const a=p(xm,ry,Z0),b=p(xm,ry,Z1);L.line(a[0],a[1],b[0],b[1],ridge)}
function gable(L,ctx,x0,z0,x1,z1,y,rh,ov,roof,wall,ridge){const p=ctx.p,zm=(z0+z1)/2,X0=x0-ov,X1=x1+ov,Z0=z0-ov,Z1=z1+ov,Wd=X1-X0,ey=y-rh*ov/(zm-z0),ry=y+rh,sl=Math.hypot(zm-Z0,ry-ey);
 quad(L,p(X0,ry,zm),p(X1,ry,zm),p(X0,ey,Z0),(u,v,x,yy)=>roof('roofN',u*Wd,v*sl,x,yy));
 if(ctx.iso)quad(L,p(x1,y,z1),p(x1,y,z0),p(x1,ry,zm),(u,v,x,yy)=>wall('gable',u*(z1-z0),(1-v)*rh,x,yy),true);
 quad(L,p(X0,ry,zm),p(X1,ry,zm),p(X0,ey,Z1),(u,v,x,yy)=>roof('roofS',u*Wd,v*sl,x,yy));
 const a=p(X0,ry,zm),b=p(X1,ry,zm);L.line(a[0],a[1],b[0],b[1],ridge)}

// ---------- matières ----------
function blocks(R,bw,bh,seed,o={}){return(f,u,v,x,y)=>{const px=1/CT,fb=FB[f]??.7;
 if(o.band&&f!=='top'&&v<o.band[0])return rp(o.bandR||GOLD,.55+fb*.3,x,y);
 if(o.moss&&vnoise(x*.18,y*.18,seed+5)>1-o.moss&&(f==='top'||hash(x,y,seed)>.45))return rp(MOSS,fb*.85+(hash(x,y,seed+1)-.5)*.3,x,y);
 const row=Math.floor(v/bh),off=(row&1)*bw*.5,col=Math.floor((u+off)/bw),lu=u+off-col*bw,lv=v-row*bh;
 if(lu<px||lv<px)return R[1];let b=fb*(.8+(hash(col,row,seed)-.5)*.3)+(vnoise(x*.4,y*.4,seed)-.5)*.12;if(lv<px*2)b+=.1;if(lu>bw-px*1.5)b-=.08;return rp(R,b,x,y)}}
function logs(R,lh,seed){return(f,u,v,x,y)=>{const fb=FB[f]??.7,px=1/CT;if(f==='top')return rp(R,fb*.75,x,y);const row=Math.floor(v/lh),lv=(v-row*lh)/lh;
 let b=fb*(.5+.55*Math.sin(Math.PI*Math.min(1,lv*1.05)))+(hash(Math.floor(u*CT/4),row,seed)-.5)*.14;if(lv*lh<px)b=.05;if(hash(Math.floor(u*CT/2),row,seed+3)>.95)b-=.25;return rp(R,b,x,y)}}
function thatch(R,seed,mt=.66){return(f,u,v,x,y)=>{const fb=FB[f]??.7,px=1/CT,col=Math.floor(u*CT),layer=Math.floor((v+hash(col,0,seed)*.05)/.24),lv=v-layer*.24;
 let b=fb*(.78+(hash(col,layer,seed)-.5)*.4)+(lv<px*1.5?-.3:0)+(lv>.24-px*2?.08:0);if(vnoise(u*2.4,v*2.4,seed+7)>mt)return rp(MOSS,b*.95+.1,x,y);return rp(R,b,x,y)}}
function vlogs(R,lw,seed){return(f,u,v,x,y)=>{const fb=FB[f]??.7,px=1/CT;if(f==='top')return rp(R,fb*.75,x,y);const col=Math.floor(u/lw),lu=(u-col*lw)/lw;let b=fb*(.5+.55*Math.sin(Math.PI*Math.min(1,lu*1.05)))+(hash(col,Math.floor(v*CT/4),seed)-.5)*.14;if(lu*lw<px)b=.05;if(v<px*2)b-=.2;return rp(R,b,x,y)}}
function tiles(R,seed){return(f,u,v,x,y)=>{const fb=FB[f]??.7,px=1/CT,row=Math.floor(v/.2),lv=(v-row*.2)/.2,off=(row&1)*.12,col=Math.floor((u+off)/.24),lu=(u+off-col*.24)/.24;
 let b=fb*(.45+.6*lv)+(hash(col,row,seed)-.5)*.15;if(lv*.2<px)b=.05;if(Math.abs(lu-.5)>.44)b-=.22;return rp(R,b,x,y)}}
// motif de glyphes sur une face : cellules de 2 px, allumées (émissives) ou gravées
function glyph(mat,face,u0,v0,w,h,col,seed,dark){return(f,u,v,x,y)=>{if(f===face&&u>=u0&&u<u0+w&&v>=v0&&v<v0+h){const gx=Math.floor((u-u0)*CT/2),gy=Math.floor((v-v0)*CT/2),cw=Math.floor(w*CT/2);
 const on=gx===Math.floor(cw/2)||(hash(gx,gy,seed)>.5&&gy%2===0);if(on&&((x+y)&1)===0)return E(col);if(on)return E(sh(col,-.25));return dark}return mat(f,u,v,x,y)}}

// ---------- scène et éclairage ----------
const KEYS=[[0,[.27,.3,.48]],[4.5,[.29,.31,.49]],[6.5,[.8,.62,.66]],[8.5,[1,.96,.9]],[13,[1.05,1.02,.96]],[17,[1,.93,.82]],[19,[.95,.62,.5]],[20.5,[.44,.4,.58]],[24,[.27,.3,.48]]];
function ambient(h){h=((h%24)+24)%24;for(let k=1;k<KEYS.length;k++)if(h<=KEYS[k][0]){const[a,A]=KEYS[k-1],[b,B]=KEYS[k],t=(h-a)/(b-a);return A.map((v,i)=>v+(B[i]-v)*t)}return KEYS[0][1]}
class Scene{constructor(w,h){this.w=w;this.h=h;this.P=new Pix(w,h);this.sh=new Float32Array(w*h);this.lights=[];this.L=[new Float32Array(w*h),new Float32Array(w*h),new Float32Array(w*h)];this.A=[new Float32Array(w*h),new Float32Array(w*h),new Float32Array(w*h)]}
 shadowEll(cx,cy,rx,ry,a){for(let y=Math.floor(cy-ry);y<=cy+ry;y++)for(let x=Math.floor(cx-rx);x<=cx+rx;x++){if(x<0||y<0||x>=this.w||y>=this.h)continue;const dx=(x+.5-cx)/rx,dy=(y+.5-cy)/ry;if(dx*dx+dy*dy<=1){const i=y*this.w+x;this.sh[i]=Math.max(this.sh[i],a)}}}
 shadowRect(ctx,x0,z0,x1,z1,a){const c=[[x0,z0],[x1,z0],[x0,z1],[x1,z1]].map(([x,z])=>ctx.p(x,0,z)),xs=c.map(p=>p[0]),ys=c.map(p=>p[1]);
  for(let y=Math.max(0,Math.floor(Math.min(...ys)));y<=Math.min(this.h-1,Math.max(...ys));y++)for(let x=Math.max(0,Math.floor(Math.min(...xs)));x<=Math.min(this.w-1,Math.max(...xs));x++){const[wx,wz]=ctx.inv(x+.5,y+.5);if(wx>=x0&&wx<=x1&&wz>=z0&&wz<=z1){const i=y*this.w+x;this.sh[i]=Math.max(this.sh[i],a)}}}
 shadowBox(ctx,x0,z0,x1,z1,h,a){const dx=h*.5,dz=h*.22,c=[[x0,z0],[x1+dx,z0],[x0,z1+dz],[x1+dx,z1+dz]].map(([x,z])=>ctx.p(x,0,z)),xs=c.map(p=>p[0]),ys=c.map(p=>p[1]);
  for(let y=Math.max(0,Math.floor(Math.min(...ys)));y<=Math.min(this.h-1,Math.max(...ys));y++)for(let x=Math.max(0,Math.floor(Math.min(...xs)));x<=Math.min(this.w-1,Math.max(...xs));x++){const[wx,wz]=ctx.inv(x+.5,y+.5);for(let k=0;k<=10;k++){const t=k/10,u=wx-dx*t,v=wz-dz*t;if(u>=x0&&u<=x1&&v>=z0&&v<=z1){const i=y*this.w+x;this.sh[i]=Math.max(this.sh[i],a);break}}}}
 bake(ctx,ground,objs){const{w,h}=this;CT=ctx.T;if(ground)for(let y=0;y<h;y++)for(let x=0;x<w;x++){const[wx,wz]=ctx.inv(x+.5,y+.5);this.P.set(x,y,ground(wx,wz,x,y))}
  this.ground=new Int32Array(this.P.c);const key=o=>o.key?o.key(ctx):ctx.depth(o.x,o.z);objs.sort((a,b)=>key(a)-key(b));
  for(const o of objs){let r;if(o.layer){const L=new Pix(w,h);r=o.draw(L,ctx,this)||{};L.outline();if(r.post)r.post(L);this.P.blit(L,0,0)}else r=o.draw(this.P,ctx,this)||{};if(r.lights)this.lights.push(...r.lights)}
  return this}
 render(g,hour,t){const{w,h}=this,amb=ambient(hour),lum=.3*amb[0]+.59*amb[1]+.11*amb[2],night=Math.max(0,Math.min(1,(.9-lum)/.6)),day=Math.max(0,Math.min(1,(lum-.45)/.5)),[lr,lg,lb]=this.L;
  lr.fill(0);lg.fill(0);lb.fill(0);const[ar,ag,ab]=this.A;ar.fill(0);ag.fill(0);ab.fill(0);
  if(night>.02)for(const L of this.lights){const add=L.add??(L.c===WHITEC?.2:L.c===VIOBLUE?.1:0),fl=L.fl||0,I=L.i*night*(1+fl*(Math.sin(t*9.3+L.x)*.5+Math.sin(t*14.1+L.y*1.7)*.35)),R=L.r*(1+fl*.12*Math.sin(t*6.1+L.x*.7));
   for(let y=Math.max(0,Math.floor(L.y-R/1.3));y<=Math.min(h-1,L.y+R/1.3);y++)for(let x=Math.max(0,Math.floor(L.x-R));x<=Math.min(w-1,L.x+R);x++){const dx=x+.5-L.x,dy=(y+.5-L.y)*1.3,d=Math.sqrt(dx*dx+dy*dy)/R;if(d>=1)continue;let f=1-d;f=f*f*(3-2*f);const q=Math.floor(f*5+bay(x,y))/5;if(q<=0)continue;const i=y*w+x;lr[i]+=L.c[0]*I*q;lg[i]+=L.c[1]*I*q;lb[i]+=L.c[2]*I*q;if(add){const k=add*I*q*255;ar[i]+=L.c[0]*k;ag[i]+=L.c[1]*k;ab[i]+=L.c[2]*k}}}
  if(!this.img||this.img.width!==w)this.img=g.createImageData(w,h);const d=this.img.data,P=this.P.c,G=this.ground,S=this.sh;
  for(let i=0,o=0;i<w*h;i++,o+=4){const v=P[i];if(v<0){d[o]=11;d[o+1]=18;d[o+2]=14;d[o+3]=255;continue}const r=v>>16&255,gg=v>>8&255,b=v&255;
   if(v&0x1000000){const k=1+night*.15;d[o]=Math.min(255,r*k);d[o+1]=Math.min(255,gg*k);d[o+2]=Math.min(255,b*k)}
   else{const s=v===G[i]?1-S[i]*day*.42:1;d[o]=Math.min(255,r*(amb[0]*s+lr[i])+ar[i]);d[o+1]=Math.min(255,gg*(amb[1]*s+lg[i])+ag[i]);d[o+2]=Math.min(255,b*(amb[2]*s+lb[i])+ab[i])}d[o+3]=255}
  g.putImageData(this.img,0,0);if(this.fx)this.fx(g,t,night)}}

// ---------- objets de scène ----------
const projL=(ctx,ls)=>(ls||[]).map(l=>{const[sx,sy]=ctx.p(l.x,l.y,l.z);return{...l,x:sx,y:sy}});
function sprObj(x,z,make,o={}){return{x,z,draw(P,ctx,S){const sp=make(),[sx,sy]=ctx.p(x,0,z),ox=Math.round(sx)-sp.ax,oy=Math.round(sy)-sp.ay;if(ox>S.w||oy>S.h||ox+sp.P.w<0||oy+sp.P.h<0)return;
 if(o.shadow!==0)S.shadowEll(sx,sy,sp.sw*.55*(o.shadow||1),sp.sw*.2*(o.shadow||1),.9);P.blit(sp.P,ox,oy);return{lights:sp.lights.map(l=>({...l,x:l.x+ox,y:l.y+oy}))}}}}
function boxObj(x0,z0,x1,z1,h,mat,o={}){return{layer:true,key:ctx=>ctx.iso?ctx.depth((x0+x1)/2,(z0+z1)/2):ctx.depth((x0+x1)/2,z1),draw(L,ctx,S){CT=ctx.T;if(h>.2)S.shadowBox(ctx,x0,z0,x1,z1,h,.85);box(L,ctx,x0,z0,x1,z1,0,h,mat);return{lights:projL(ctx,o.lights)}}}}

// ---------- personnages ----------
const SCALES={
 trapu:{id:'trapu',label:'Trapus (~26 px)',head:11,hw:11,torso:9,leg:7,sw:13,arm:3},
 inter:{id:'inter',label:'Intermédiaires (~36 px)',head:11,hw:10,torso:13,leg:13,sw:15,arm:3},
 real:{id:'real',label:'Réalistes (~46 px)',head:10,hw:8,torso:17,leg:20,sw:15,arm:3}};
function anchors(P,S){const aw=S.arm,tw=S.sw-2*aw,cx=P.w>>1,fy=P.h-4,lt=fy-S.leg+1,tt=lt-S.torso,ht=tt-S.head+1,x0=cx-(tw>>1);return{aw,tw,cx,fy,lt,tt,ht,x0,x1:x0+tw,lw:Math.max(2,(tw-1)>>1),hx:cx-(S.hw>>1)}}
const SPR=new Map();
function mk(key,S,fn,W=64){const k=key+'/'+S.id;if(SPR.has(k))return SPR.get(k);const P=new Pix(W,S.head+S.torso+S.leg+34),a=anchors(P,S),post=[];const lights=fn(P,a,post)||[];P.outline();for(const g of post)g(P);const r={P,ax:a.cx,ay:a.fy,sw:S.sw,lights};SPR.set(k,r);return r}
function legs(P,a,S,o){const bh=Math.max(2,Math.round(S.leg*.24)),L=a.fy-a.lt+1-bh;
 for(const[k,x]of[[0,a.x0],[1,a.x1-a.lw]]){sr(P,x,a.lt,a.lw,L+1,o.pant,.14);if(o.knee)P.rect(x,a.lt+Math.round(L*.45),a.lw,Math.max(1,Math.round(S.leg*.12)),o.knee);
  if(o.strut){const sx=k?x+a.lw:x-1;P.rect(sx,a.lt+1,1,L,o.strut);P.set(sx,a.lt+Math.round(L*.5),o.joint||o.strut)}sr(P,x-(k?0:1),a.fy-bh+1,a.lw+1,bh,o.boot,.14)}}
function arms(P,a,S,o){const len=Math.round(S.torso*.85+S.leg*.15),sl=Math.round(len*(o.sleeve??.6));
 for(const[k,x]of[[0,a.x0-a.aw],[1,a.x1]]){sr(P,x,a.tt+1,a.aw,sl,o.cloth,.15);if(len-sl-1>0)sr(P,x,a.tt+1+sl,a.aw,len-sl-1,o.fore||o.cloth,.15);P.rect(x,a.tt+len,a.aw,2,o.hand)}return len}
function eyes(P,a,S,c=EYE){const ey=a.ht+Math.round(S.head*.58),d=S.hw>=10?1:0;P.set(a.cx-2-d,ey,c);P.set(a.cx+1+d,ey,c);if(S.head>=11){P.set(a.cx-2-d,ey+1,c);P.set(a.cx+1+d,ey+1,c)}return ey}
function face(P,a,S,skin){sr(P,a.hx,a.ht+1,S.hw,S.head-1,skin,.12);return eyes(P,a,S)}
function hair(P,a,S,c,style){const hx=a.hx,hw=S.hw,ht=a.ht,H=S.head,top=Math.ceil(H*.32);P.rect(hx,ht,hw,top,c);P.rect(hx+1,ht,hw-3,1,sh(c,.2));P.rect(hx,ht,1,Math.round(H*.55),c);P.rect(hx+hw-1,ht,1,Math.round(H*.5),c);
 if(style==='tied'){P.rect(hx-1,ht+1,1,Math.round(H*.45),sh(c,-.15));P.rect(hx-2,ht+2,1,Math.round(H*.5),sh(c,-.25));P.rect(a.cx-1,ht+top,3,1,c)}
 if(style==='short'){P.set(a.cx+1,ht+top,c);P.set(a.cx-2,ht+top,c)}}

function recrue(S){return mk('recrue',S,(P,a)=>{const fh=Math.max(3,Math.round(S.head*.4)),pL=a.x0-a.aw-1,pR=a.x1+a.aw,fy=a.tt-fh;
 P.rect(pL,fy,2,fh+Math.round(S.torso*.6),EX.steelD);P.rect(pR-1,fy,2,fh+Math.round(S.torso*.6),EX.steelD);P.rect(pL,fy,pR-pL+1,2,EX.steelD);P.rect(pL+1,fy,pR-pL-1,1,EX.steel);
 legs(P,a,S,{pant:EX.olive,boot:EX.boot,knee:EX.steel,strut:EX.steel,joint:EX.cy});
 sr(P,a.x0,a.tt+1,a.tw,a.lt-a.tt,EX.olive,.16);P.rect(a.x0,a.lt-1,a.tw,2,EX.steelD);P.rect(a.cx-1,a.lt-1,2,1,EX.cy);
 const ph=Math.round(S.torso*.5);sr(P,a.x0+1,a.tt+1,a.tw-2,ph,EX.steel,.2);P.rect(a.cx,a.tt+2,1,ph-2,EX.cyD);P.set(a.cx-1,a.tt+2,EX.cy);
 const len=arms(P,a,S,{cloth:EX.olive,fore:EX.steel,hand:EX.skin,sleeve:.5});
 sr(P,a.x0-a.aw-1,a.tt+1,a.aw+1,3,EX.steel);sr(P,a.x1,a.tt+1,a.aw+1,3,EX.steel);
 face(P,a,S,EX.skin);hair(P,a,S,'#3a2a1e','short');
 const gy=a.tt+len-3;sr(P,a.x1-1,gy,a.aw+5,3,EX.gun,.2);P.rect(a.x1+a.aw+4,gy+1,3,1,EX.gun);P.set(a.x1+a.aw+7,gy+1,EX.cy);P.set(a.x1+1,gy+1,EX.cy);
 sr(P,pL-3,fy-3,5,4,EX.gun,.2);P.rect(pL-4,fy-2,1,2,EX.gun);P.set(pL-4,fy-2,EX.cy);
 return[{x:a.cx,y:a.tt+4,c:CYAN,r:20,i:.6}]})}
function veterane(S){return mk('veterane',S,(P,a)=>{const fh=2,pL=a.x0-a.aw,pR=a.x1+a.aw-1;
 P.rect(pL,a.tt-fh,1,fh+Math.round(S.torso*.5),EX.steelD);P.rect(pR,a.tt-fh,1,fh+Math.round(S.torso*.5),EX.steelD);P.rect(pL,a.tt-fh,pR-pL+1,1,EX.steelD);
 legs(P,a,S,{pant:EX.olive2,boot:EX.boot,knee:EX.steelD,strut:EX.steel,joint:EX.cy});
 sr(P,a.x0,a.tt+1,a.tw,a.lt-a.tt,EX.olive2,.16);P.rect(a.x0,a.lt-1,a.tw,1,EX.steelD);
 const ph=Math.round(S.torso*.42);sr(P,a.x0+1,a.tt+1,a.tw-2,ph,EX.steelD,.25);P.set(a.cx,a.tt+2,EX.cy);P.set(a.cx,a.tt+ph-1,EX.cy);
 const len=arms(P,a,S,{cloth:EX.olive2,fore:EX.steelD,hand:EX.skin,sleeve:.45});
 sr(P,a.x0-a.aw-1,a.tt+1,a.aw+1,3,EX.steel);
 face(P,a,S,'#dcae8a');hair(P,a,S,'#9b5a34','tied');
 const hy=a.tt+len,bc=a.x1+(a.aw>>1),bw=S.sw>=15?4:3,bx=bc-(bw>>1),top=a.ht-Math.round(S.head*.55),gy=hy-1;
 for(let y=top;y<gy;y++)for(let i=0;i<bw;i++)P.set(bx+i,y,i===0?'#e6ecf2':i===bw-1?'#6e7882':'#b9c2cc');
 for(let y=top+2;y<gy-1;y+=3)P.set(bx+(bw>>1),y,EX.cy);P.del(bx+(bw>>1),top);P.set(bx,top-1,'#e6ecf2');
 P.rect(bx-1,gy,bw+2,1,EX.gun);P.rect(bc,gy+1,1,3,'#3a2a20');P.rect(a.x1,hy,a.aw,2,EX.skin);
 return[{x:bc,y:Math.round((top+gy)/2),c:CYAN,r:18,i:.5}]})}
function soldat(S){return mk('soldat',S,(P,a)=>{
 legs(P,a,S,{pant:EX.olive,boot:EX.boot,knee:EX.steel,strut:EX.steel,joint:EX.cy});
 sr(P,a.x0-1,a.tt-1,a.tw+2,4,EX.steelD);
 sr(P,a.x0,a.tt+1,a.tw,a.lt-a.tt,EX.olive,.16);P.rect(a.x0,a.lt-1,a.tw,2,EX.steelD);sr(P,a.x0+1,a.tt+1,a.tw-2,Math.round(S.torso*.55),EX.steel,.2);
 const len=arms(P,a,S,{cloth:EX.olive,fore:EX.steel,hand:EX.skin,sleeve:.5});sr(P,a.x0-a.aw-1,a.tt+1,a.aw+1,3,EX.steel);sr(P,a.x1,a.tt+1,a.aw+1,3,EX.steel);
 const hx=a.hx,hw=S.hw,H=S.head;sr(P,hx-1,a.ht-1,hw+2,H,EX.steel,.22);P.rect(hx,a.ht+H-3,hw,2,EX.steelD);const ey=a.ht+Math.round(H*.55);P.rect(hx,ey-1,hw,2,EX.gun);P.rect(hx+1,ey-1,hw-2,1,EX.cy);P.set(a.cx,a.ht-2,EX.steelD);
 const hy=a.tt+len;P.line(a.x0-a.aw-1,hy,a.x1+a.aw+4,a.tt+4,EX.gun);P.line(a.x0-a.aw,hy,a.x1+a.aw+4,a.tt+5,EX.gun);P.set(a.x1+a.aw+5,a.tt+4,EX.cy);P.set(a.cx,Math.round((hy+a.tt+4)/2)+1,EX.cy);
 return[{x:a.cx,y:ey,c:CYAN,r:16,i:.5}]})}

// adeptes : robe en trapèze, coiffe et accessoire selon la variante
function adept(key,v){return S=>mk(key,S,(P,a,post)=>{const cx=a.cx,lights=[],skin=v.skin||'#c69a76';
 const back=(Q,x,y,c)=>{const o=Q.get(x,y);if(o===-1||o===OUTL)Q.set(x,y,c)};
 if(v.head==='halo'){const hy=a.ht+(S.head>>1)-1,r=(S.hw>>1)+3;post.push(Q=>{for(let k=0;k<56;k++){const an=k/56*Math.PI*2;back(Q,Math.round(cx-.5+Math.cos(an)*r),Math.round(hy+Math.sin(an)*r*.9),E(k%7?(v.haloCol||'#7a80ff'):'#e0e2ff'))}});lights.push({x:cx,y:hy,c:VIOBLUE,r:22,i:.6})}
 let bot=a.fy-1;if(v.short){legs(P,a,S,{pant:'#4a3a28',boot:'#2a1e16'});bot=a.lt+Math.round(S.leg*.35)}else{P.rect(a.x0+1,a.fy-1,a.lw,2,'#2a1e16');P.rect(a.x1-a.lw-1,a.fy-1,a.lw,2,'#2a1e16')}
 const top=a.tt+1,flare=S.sw*(v.short?.08:.2);
 for(let y=top;y<=bot;y++){const t=(y-top)/(bot-top),hw=a.tw/2+.5+t*flare,xl=Math.round(cx-hw),xr=Math.round(cx+hw)-1;
  for(let x=xl;x<=xr;x++){let c=ci(v.robe);if(x===xl)c=sh(c,.16);else if(x>=xr-1)c=sh(c,-.3);else if(t>.35&&((x-cx)%3===0)&&hash(x,7,1)>.3)c=sh(c,-.18);
   if(v.stripe&&Math.abs(x-cx+.5)<(S.sw>=15?1.5:1))c=ci(v.trim);if(y>=bot-1&&v.trim)c=y===bot?sh(v.trim,-.25):ci(v.trim);if(v.stars&&t>.2&&hash(x,y,9)>.95)c=ci(v.trim);P.set(x,y,c)}}
 if(v.mantle){const mh=Math.round(S.torso*.42);for(let y=top;y<top+mh;y++){const w=a.tw+2,xl=cx-(w>>1)-1;for(let x=xl;x<xl+w+2;x++){if(y===top+mh-1&&v.jag&&(x&1))continue;P.set(x,y,x===xl?sh(v.mantle,.15):x>=xl+w?sh(v.mantle,-.3):ci(v.mantle))}}}
 if(v.apron){const ay=a.tt+Math.round(S.torso*.4);sr(P,a.x0+1,ay,a.tw-2,bot-1-ay,v.apron,.15);P.rect(a.x0+1,bot-2,a.tw-2,1,sh(v.apron,-.3))}
 if(v.armor){const ar=v.armor;for(let y=a.tt+2;y<a.lt-1;y++)for(let x=a.x0;x<a.x1;x++)P.set(x,y,(y-a.tt)%3===0?sh(ar,-.38):((x+((y-a.tt)/3|0))%2?sh(ar,.14):ci(ar)));
  if(v.short)for(let y=a.lt-1;y<bot;y++)for(let x=a.x0-1;x<=a.x1;x++)P.set(x,y,(y-a.lt)%2?sh(ar,-.32):((x&1)?ci(ar):sh(ar,.12)));
  if(v.sash){const n=a.lt-a.tt;for(let k=0;k<n;k++){const x=a.x0+Math.round(k*(a.tw-1)/n);P.set(x,a.tt+1+k,v.sash);P.set(x+1,a.tt+1+k,sh(v.sash,-.22))}}}
 P.rect(a.x0+1,a.lt-2,a.tw-2,1,v.belt||'#6a4a2a');if(v.armor&&v.sash){P.rect(a.x0,a.lt-2,a.tw,2,v.sash);P.rect(a.x0,a.lt-1,a.tw,1,sh(v.sash,-.3));P.set(a.x1-2,a.lt,v.sash);P.set(a.x1-2,a.lt+1,sh(v.sash,-.2))}
 const len=arms(P,a,S,{cloth:v.sleeve||v.robe,fore:v.fore,hand:skin,sleeve:v.fore?.5:1}),hy=a.tt+len,px=a.x1+(a.aw>>1),lx=a.x0-a.aw+(a.aw>>1);
 const sy=a.tt+Math.round(S.torso*.45);
 if(v.pauldron){sr(P,a.x0-a.aw-1,a.tt,a.aw+2,3,v.pauldron,.25);sr(P,a.x1-1,a.tt,a.aw+2,3,v.pauldron,.25);P.rect(a.x0-a.aw-1,a.tt+1,a.aw+2,1,sh(v.pauldron,-.3));P.rect(a.x1-1,a.tt+1,a.aw+2,1,sh(v.pauldron,-.3));P.set(a.x0-a.aw-1,a.tt+3,v.sash);P.set(a.x0-a.aw-1,a.tt+4,sh(v.sash,-.2));P.set(a.x1+a.aw,a.tt+3,v.sash);P.set(a.x1+a.aw,a.tt+4,sh(v.sash,-.2))}
 if(v.toga){const n=a.lt-a.tt+2;for(let k=0;k<n;k++){const x=a.x0-1+Math.round(k*(a.tw)/n),y=a.tt+1+k;P.set(x,y,sh(v.toga,.1));P.set(x+1,y,v.toga);P.set(x+2,y,v.toga);P.set(x+3,y,sh(v.toga,-.2))}
  sr(P,a.x0-a.aw,a.tt+1,a.aw,Math.round(len*.75),v.toga,.15);for(let y=a.tt+3;y<a.tt+len*.75;y+=3)P.set(a.x0-a.aw+1,y,sh(v.toga,-.18));for(let y=bot-6;y<bot;y++)P.set(a.x0+1,y,sh(v.toga,-.25))}
 if(v.symbol==='sun'){P.rect(cx-1,sy,3,3,'#e2c266');P.set(cx,sy+1,'#fff0b8');P.set(cx,sy-1,'#e2c266');P.set(cx,sy+3,'#e2c266');P.set(cx-2,sy+1,'#e2c266');P.set(cx+2,sy+1,'#e2c266')}
 if(v.symbol==='rune'){P.set(cx,sy,E('#ffb347'));P.set(cx,sy+1,E('#ffb347'));P.set(cx-1,sy+2,E('#ff9a30'));P.set(cx+1,sy+2,E('#ff9a30'))}
 if(v.symbol==='flame'){P.set(cx,sy-1,E('#fff4d8'));P.set(cx,sy,E('#ffffff'));P.set(cx-1,sy+1,E('#fff0c8'));P.set(cx,sy+1,E('#ffe6b0'));P.set(cx+1,sy+1,E('#fff0c8'))}
 if(v.symbol==='sunmoon'){P.rect(cx-2,sy,2,2,'#d8dce4');P.set(cx-2,sy,'#ffffff');P.set(cx+1,sy-1,'#a0a8ff');P.set(cx+2,sy,'#a0a8ff');P.set(cx+1,sy+1,'#a0a8ff')}
 if(v.symbol==='sprout'){P.set(cx,sy+2,'#5a3a20');P.set(cx,sy+1,E('#7ae070'));P.set(cx-1,sy,E('#b8f0a0'));P.set(cx+1,sy,E('#7ae070'))}
 if(v.symbol==='spear'){P.rect(cx,sy-1,1,4,'#a87a3a');P.set(cx,sy-2,'#e2c266')}
 if(v.symbol==='cross'){P.rect(cx,sy-1,1,5,'#c0182a');P.rect(cx-1,sy,3,1,'#c0182a')}
 // coiffes
 const hx=a.hx,hw=S.hw,ht=a.ht,H=S.head;
 if(v.head==='hood'||v.head==='antlers'){const hc=v.hood;sr(P,hx-1,ht-1,hw+2,H+1,hc,.15);P.set(cx,ht-2,hc);const fx=hx+1,fw=hw-2,f0=ht+2,fh=H-3;
  if(v.mask){P.rect(fx,f0,fw,fh,v.mask);P.rect(fx,f0+fh-1,fw,1,sh(v.mask,-.2));P.rect(cx-1+(hw&1?0:0),f0+2,1,fh-3,sh(v.mask,-.15));eyes(P,a,S,v.maskEyes||EYE)}
  else{P.rect(fx,f0,fw,fh,sh(skin,-.3));P.rect(fx,f0,fw,1,sh(hc,-.45));eyes(P,a,S,v.eyes||EYE)}
  if(v.head==='antlers')for(const s of[-1,1]){const bx=s<0?hx:hx+hw-1;P.line(bx,ht,bx+s*3,ht-6,'#ddd2b4');P.line(bx+s*2,ht-3,bx+s*4,ht-4,'#ddd2b4');P.line(bx+s,ht-5,bx,ht-8,'#cfc3a2')}}
 if(v.head==='tonsure'){face(P,a,S,skin);P.rect(hx,ht+2,1,4,v.hair);P.rect(hx+hw-1,ht+2,1,4,v.hair);P.rect(hx+1,ht+2,hw-2,1,v.hair);P.rect(hx+2,ht+1,hw-4,1,sh(skin,.12))}
 if(v.head==='crown'){face(P,a,S,skin);P.rect(hx,ht,hw,3,v.hair);P.rect(hx-1,ht+2,hw+2,1,LEAF[5]);for(let x=hx-1;x<=hx+hw;x+=2){P.set(x,ht+1,LEAF[6]);P.set(x,ht,LEAF[4])}}
 if(v.head==='tallhat'){face(P,a,S,skin);P.rect(hx,ht+1,hw,2,v.hair||'#2a1a14');const hh=Math.round(H*1.1);for(let k=0;k<hh;k++){const w=Math.max(1,Math.round(hw*(1-k/hh)+1));P.rect(cx-(w>>1)-(k>hh*.7?k-Math.round(hh*.7):0)*0,ht+1-k,w,1,k===0?sh(v.hat,-.2):ci(v.hat))}
  P.rect(hx-2,ht+2,hw+4,1,sh(v.hat,-.25));P.set(cx,ht-3,'#e2c266');P.set(cx-2,ht-1,'#e2c266');P.set(cx+1,ht-6,'#e2c266')}
 if(v.head==='kettle'){face(P,a,S,skin);sr(P,hx,ht-1,hw,3,'#8b939d',.22);P.rect(hx-2,ht+2,hw+4,1,'#5a616a')}
 if(v.head==='veil'){face(P,a,S,skin);sr(P,hx-1,ht-1,hw+2,Math.round(H*.45),v.hood,.15);P.rect(hx-1,ht,1,H,v.hood);P.rect(hx+hw,ht,1,H,v.hood);const ey=eyes(P,a,S),vy=ey+(H>=11?2:1);for(let y=vy;y<ht+H;y++)for(let x=hx;x<hx+hw;x++)P.set(x,y,(x+y)&1?v.veil:sh(v.veil,-.2));P.set(cx,ht+2,E('#ffd27a'))}
 if(v.head==='helmMask'){sr(P,hx-1,ht-1,hw+2,H+1,v.hood,.18);P.rect(hx+1,ht+2,hw-2,H-3,v.veil);P.rect(hx+1,ht+2,hw-2,1,sh(v.veil,.25));const ey=ht+Math.round(H*.58);P.rect(hx+1,ey,(hw-2)/2-1,1,EYE);P.rect(cx+1,ey,(hw-2)/2-1,1,EYE);P.rect(cx-1,ht-4,2,3,v.veil)}
 if(v.head==='hoodRed'){const hc=v.hood;sr(P,hx-1,ht-1,hw+2,H+1,hc,.15);P.set(cx,ht-2,hc);P.rect(hx+1,ht+2,hw-2,H-3,sh(skin,-.4));eyes(P,a,S,v.eyeCol||E('#ff5040'))}
 if(v.head==='bronzeHelm'){const ey=face(P,a,S,skin);P.rect(hx+1,ey+1,hw-2,1,'#c88a30');P.rect(hx+1,ht+H-3,hw-2,2,'#5a3a20');sr(P,hx-1,ht-1,hw+2,Math.round(H*.42),'#a87a3a',.25);P.rect(cx-1,ht+1,1,Math.round(H*.48),'#8a5e2a');P.rect(hx-1,ht+2,1,Math.round(H*.55),'#8a5e2a');P.rect(hx+hw,ht+2,1,Math.round(H*.55),'#8a5e2a');P.rect(cx-2,ht-5,3,4,'#e8e0c8');P.set(cx-1,ht-6,'#c8a060');P.set(cx-2,ht-3,'#c8a060')}
 if(v.head==='warpaint'){const ey=face(P,a,S,skin);P.rect(hx,ht,hw,3,v.hair);P.rect(hx,ht,1,Math.round(H*.5),v.hair);P.rect(hx+hw-1,ht,1,Math.round(H*.5),v.hair);P.rect(cx-2,ht-3,3,3,v.hair);P.set(cx-1,ht-4,'#a87a3a');P.rect(hx+1,ey+1,2,1,'#c88a30');P.rect(hx+hw-3,ey+1,2,1,'#c88a30');P.rect(hx+1,ht+H-3,hw-2,2,v.hair);P.set(cx-1,ht+H-1,v.hair)}
 if(v.head==='halo'){face(P,a,S,skin);P.rect(hx,ht,hw,2,v.hair);P.rect(hx,ht,1,Math.round(H*.4),v.hair);P.rect(hx+hw-1,ht,1,Math.round(H*.4),v.hair)}
 if(v.hoodLeaves){for(let x=hx-1;x<=hx+hw;x+=2)P.set(x,ht-1,LEAF[5]);P.set(hx,ht-2,LEAF[6]);P.set(hx+hw-1,ht-2,LEAF[6]);P.set(hx+2,ht-1,'#e8a0c0');P.set(hx+hw-3,ht-1,'#fff4d8')}
 if(v.head==='crestHelm'){face(P,a,S,skin);sr(P,hx-1,ht-1,hw+2,Math.round(H*.45),v.helm,.25);P.rect(hx-1,ht+2,2,Math.round(H*.62),sh(v.helm,-.15));P.rect(hx+hw-1,ht+2,2,Math.round(H*.62),sh(v.helm,-.15));P.rect(hx+1,ht+Math.round(H*.45)-2,hw-2,1,sh(v.helm,-.38));P.rect(cx-1,ht+1,1,Math.round(H*.55),sh(v.helm,-.1));
  for(let k=0;k<8;k++){const y=ht-3-(k>1&&k<6?1:0);P.set(cx-4+k,y,k%2?ci(v.crest):sh(v.crest,.25));P.set(cx-4+k,y+1,sh(v.crest,-.2))}P.rect(cx+3,ht-2,2,6,v.crest);P.rect(cx+4,ht+4,1,2,sh(v.crest,-.25));P.set(hx+hw,ht+1,BRONZE[4])}
 if(v.head==='topknot'){const ey=face(P,a,S,skin);P.rect(hx,ht,hw,3,v.hair);P.rect(hx,ht,1,Math.round(H*.5),v.hair);P.rect(hx+hw-1,ht,1,Math.round(H*.5),v.hair);P.rect(cx-2,ht-3,3,3,v.hair);P.set(cx-1,ht-4,sh(v.hair,.2));P.rect(hx,ht+2,hw,1,v.band);P.set(hx+hw,ht+3,v.band);P.set(hx+hw,ht+4,v.band);P.set(hx+hw+1,ht+5,sh(v.band,-.2));P.rect(hx+1,ey+1,2,1,v.band);P.rect(hx+hw-3,ey+1,2,1,v.band)}
 if(v.head==='scholar'){face(P,a,S,skin);P.rect(hx,ht+1,hw,1,v.hair);P.rect(hx,ht+1,1,5,v.hair);P.rect(hx+hw-1,ht+1,1,5,v.hair);P.rect(hx+2,ht+1,hw-4,1,sh(skin,.12));if(v.beard){P.rect(hx+1,ht+H-4,hw-2,3,v.hair);P.rect(hx+2,ht+H-1,hw-4,2,v.hair);P.set(cx-1,ht+H+1,v.hair)}}
 if(v.head==='band'){face(P,a,S,skin);P.rect(hx,ht,hw,3,v.hair);P.rect(hx,ht,1,Math.round(H*.7),v.hair);P.rect(hx+hw-1,ht,1,Math.round(H*.7),v.hair);P.rect(hx,ht+2,hw,1,v.band);P.rect(hx-1,ht+3,1,Math.round(H*.6),sh(v.hair,-.15))}
 // accessoires
 const top2=ht-5;
 if(v.prop==='staff'){P.rect(px,top2,1,a.fy-top2+1,WOOD[3]);P.set(px-1,top2,WOOD[3]);P.set(px-1,top2-1,WOOD[2]);P.set(px+1,top2-1,WOOD[3]);P.set(px+1,top2-2,WOOD[2]);P.rect(a.x1,hy,a.aw,2,skin);
  const gc=v.glowCol||['#ffb347','#ffe0a0','#ff9a30'];post.push(Q=>{Q.set(px,top2-2,E(gc[0]));Q.set(px,top2-3,E(gc[1]));Q.set(px-1,top2-2,E(gc[2]));if(v.glowCol){Q.set(px,top2-4,E(gc[1]));Q.set(px+1,top2-3,E(gc[2]))}});lights.push({x:px,y:top2-2,c:v.light||AMBER,r:30,i:.9,fl:.15})}
 if(v.prop==='censer'){P.line(px,hy+2,px,hy+5,'#6a5a40');sr(P,px-1,hy+6,3,3,'#a8823a',.25);post.push(Q=>{Q.set(px,hy+7,E('#ff8a2a'));Q.set(px+1,hy+4,E('#ffd27a'))});lights.push({x:px,y:hy+7,c:AMBER,r:26,i:.8,fl:.3})}
 if(v.prop==='candle'){P.rect(px,hy-3,1,3,'#e8dcc0');post.push(Q=>{Q.set(px,hy-4,E('#ffd27a'));Q.set(px,hy-5,E('#fff0c0'))});lights.push({x:px,y:hy-4,c:GOLDL,r:24,i:.85,fl:.3});sr(P,lx-2,hy-3,4,5,'#6a2e1c',.2);P.rect(lx-1,hy-3,2,1,'#e8dcc0')}
 if(v.prop==='axe'){P.line(px,hy+3,px+2,hy-7,WOOD[3]);sr(P,px+1,hy-8,4,3,'#a0a6ac',.25)}
 if(v.prop==='spear'||v.prop==='halberd'){P.rect(px,top2-2,1,a.fy-top2+3,WOOD[3]);P.rect(a.x1,hy,a.aw,2,skin);if(v.prop==='spear'){P.rect(px-1,top2-1,3,3,'#b8bec6');P.set(px,top2-3,'#d8dee4')}else{P.rect(px,top2-5,1,4,'#c8ced6');sr(P,px+1,top2-3,3,4,'#a0a6ac',.25)}}
 if(v.prop==='glaive'){P.rect(px,top2,1,a.fy-top2+1,'#2a2030');P.rect(a.x1,hy,a.aw,2,skin);P.line(px,top2,px+2,top2-5,'#e2c266');P.line(px+1,top2,px+3,top2-5,'#c8a040');P.set(px+3,top2-6,'#f4dc94')}
 if(v.prop==='crystal'){P.rect(a.x1,hy-1,a.aw,2,skin);const cy=hy-7;post.push(Q=>{Q.set(px+1,cy-2,E('#ffe8a0'));Q.rect(px,cy-1,3,3,E('#ffc860'));Q.set(px+1,cy+2,E('#e09030'));Q.set(px+1,cy,E('#fff6d0'))});lights.push({x:px+1,y:cy,c:GOLDL,r:30,i:.9,fl:.12})}
 if(v.prop==='astro'){const cy=hy+1;for(const[dx,dy]of[[0,-2],[1,-2],[2,-1],[2,0],[1,1],[0,1],[-1,0],[-1,-1]])P.set(px+dx+1,cy+dy,'#c4c8d2');P.set(px+1,cy-1,E('#a0a8ff'));lights.push({x:px+1,y:cy-1,c:VIOBLUE,r:16,i:.6})}
 if(v.prop==='torch'){P.rect(px,hy-6,1,8,WOOD[3]);const fc=v.flame||['#ff5a30','#ffb070','#d02818'];post.push(Q=>{Q.set(px,hy-7,E(fc[0]));Q.set(px,hy-8,E(fc[1]));Q.set(px+1,hy-7,E(fc[2]))});lights.push({x:px,y:hy-7,c:v.light||RED,r:30,i:1,fl:.35})}
 if(v.prop==='seal'){P.rect(a.x1,hy-1,a.aw,2,skin);const sy2=hy-8,sx2=px+1;post.push(Q=>{for(let k=0;k<22;k++){const an=k/22*Math.PI*2;Q.set(Math.round(sx2+Math.cos(an)*3.2),Math.round(sy2+Math.sin(an)*3.2),E(k%5?'#e2c266':'#fff0b8'))}Q.set(sx2,sy2,E('#ffd27a'));Q.set(sx2-1,sy2,E('#c8a040'));Q.set(sx2+1,sy2-1,E('#c8a040'));Q.set(sx2,sy2+1,E('#c8a040'))});lights.push({x:sx2,y:sy2,c:GOLDL,r:28,i:.85,fl:.08})}
 if(v.scroll){sr(P,lx-1,hy-4,3,6,'#e8dcc0',.15);P.rect(lx-1,hy-4,3,1,'#6a4a2a');P.rect(lx-1,hy+1,3,1,'#6a4a2a')}
 if(v.prop==='hammer'){P.line(px,hy+2,px+1,hy-6,WOOD[3]);sr(P,px-1,hy-8,5,3,'#4a4448',.25);post.push(Q=>{Q.set(px+3,hy-7,E('#a0a8ff'));Q.set(px+3,hy-8,E('#e0e2ff'))});lights.push({x:px+3,y:hy-7,c:VIOBLUE,r:16,i:.55,fl:.2})}
 if(v.prop==='drumsticks'){const dy=a.lt-1;sr(P,cx-4,dy,8,5,'#8a6a40',.2);P.rect(cx-4,dy,8,1,'#e8dcc0');P.rect(cx-4,dy+2,8,1,'#a87a3a');P.line(a.x0-a.aw+1,hy,cx-2,dy-2,WOOD[4]);P.line(a.x1+1,hy,cx+2,dy-2,WOOD[4])}
 if(v.shield==='bronze'){P.ell(lx,hy-2,a.aw+2,a.aw+2.5,(x,y,dx,dy)=>rp(BRONZE,.6-dx*.3-dy*.3,x,y));P.set(lx,hy-2,'#f4dc94');P.set(lx-1,hy-2,'#e2c266')}
 if(v.prop==='sword'){const bx=px,tp=a.tt-Math.round(S.head*.35);for(let y=tp;y<hy-1;y++){P.set(bx,y,'#e6ecf2');P.set(bx+1,y,'#9aa0a8')}P.set(bx,tp-1,'#e6ecf2');P.rect(bx-1,hy-1,4,1,BRONZE[3]);P.rect(bx,hy,2,3,'#3a2a20');P.rect(a.x1,hy,a.aw,2,skin);P.set(bx,hy+3,v.sash||BRONZE[3]);P.set(bx,hy+4,v.sash||BRONZE[3])}
 if(v.sheath){P.line(a.x0,a.lt-1,a.x0-4,a.lt+7,'#3a2a20');P.line(a.x0+1,a.lt-1,a.x0-3,a.lt+7,'#5a4030');P.rect(a.x0-1,a.lt-3,3,1,BRONZE[3]);P.set(a.x0+1,a.lt-4,'#3a2a20')}
 if(v.prop==='openScroll'){const yy=hy-1;sr(P,cx-4,yy-2,9,4,'#ece4cc',.12);P.rect(cx-5,yy-3,1,6,'#8a6a40');P.rect(cx+5,yy-3,1,6,'#8a6a40');for(let x=cx-3;x<=cx+3;x+=2){P.set(x,yy-1,'#8a8a96');P.set(x,yy+1,'#8a8a96')}P.rect(cx-7,yy,2,2,skin);P.rect(cx+6,yy,2,2,skin)}
 if(v.prop==='books'){sr(P,lx-2,hy-5,5,2,'#5a6a8a',.2);sr(P,lx-2,hy-3,5,2,'#7a5a40',.2);sr(P,lx-2,hy-1,5,2,'#c8cad2',.2);P.line(px,hy+1,px+2,hy-5,'#f4f4f8');P.set(px+2,hy-6,'#ffffff');P.set(px+3,hy-6,'#dde2ee')}
 if(v.shield==='orange'){P.ell(lx,hy-2,a.aw+2.5,a.aw+3,(x,y,dx,dy)=>dx*dx+dy*dy>.62?rp(BRONZE,.62-dx*.3,x,y):rp(ORNG,.7-dx*.3-dy*.3,x,y));P.rect(lx,hy-5,1,6,BRONZE[4]);P.set(lx,hy-6,'#f0f0f0');P.set(lx-1,hy-4,'#f0f0f0');P.set(lx+1,hy-4,'#f0f0f0')}
 if(v.shield==='wood'){P.ell(lx,hy-2,a.aw+1.5,a.aw+2.5,(x,y,dx,dy)=>rp(WOOD,.65-dx*.25-dy*.2,x,y));P.set(lx,hy-2,E('#ffb347'))}
 if(v.shield==='almond'){sr(P,lx-2,hy-6,5,8,'#b08a4a',.2);P.set(lx,hy-3,'#f4dc94');P.set(lx,hy-4,'#e2c266');P.set(lx-1,hy-3,'#e2c266');P.set(lx+1,hy-3,'#e2c266');P.set(lx,hy-2,'#e2c266')}
 if(v.eyesGlow)lights.push({x:cx,y:ht+Math.round(H*.58),c:AMBER,r:12,i:.6});
 return lights})}

const DEITIES={
 medeina:{name:'Medeina',domain:'Vie, mort et renaissance',temple:'Sanctuaire du Cycle',register:'Druidique · le cycle',
  text:'Le cycle de la vie, de la mort et de la renaissance. Un arbre traverse le toit de la loge : à gauche il est en fleurs, à droite il est mort mais rebourgeonne. Le chaume est vivant (mousse, herbes, fleurs) et des bois de cerf coiffent le faîtage. Devant : un bassin d’eau des âmes, un cairn d’os d’où sort une jeune pousse, une spirale de pierres gravée au sol et des champignons. La lueur verte vient des gousses suspendues et de la porte en arc.',
  pal:['#2f4a26','#4c5a30','#6a5a2a','#74502f','#e2d8bc','#e8a0c0','#3fa83a','#7ae070'],
  portal:['#0d3010','#1f6420','#3fa83a','#7ae070','#c8f5b0','#f4fff0'],
  adepts:[{id:'a',name:'Gardienne du cycle',v:{robe:'#4c5a30',mantle:'#2f4a26',jag:1,trim:'#6a5a2a',belt:'#8a6a3a',head:'hood',hood:'#2f4a26',hoodLeaves:1,mask:'#e2d8bc',maskEyes:E('#b8f0a0'),prop:'staff',glowCol:['#7ae070','#c8f5b0','#3fa83a'],light:GREEN,symbol:'sprout'}},
          {id:'b',name:'Tailleuse de bois',v:{robe:'#5a4a2a',mantle:'#3e6a30',jag:1,trim:'#3e4a26',belt:'#3a2a18',head:'crown',hair:'#4a3020',prop:'axe',symbol:'sprout'}}]},
 indra:{name:'Indra',domain:'Guerriers martiaux, discipline',temple:'Salle d’armes',register:'Druidique · la discipline',
  text:'Un ordre martial : longue maison de rondins sur un soubassement de pierre, rythmée par des poutres. Toit de bardeaux, cornes aux pignons, fanions orange sur le faîtage. Quatre boucliers peints sur la façade et une tenture orange au linteau. Devant : une cour d’entraînement en terre battue avec un cercle de combat, un râtelier d’armes, un mannequin, un tambour et des bannières.',
  pal:['#3a2a1a','#5a3a20','#8a6a3a','#a87a3a','#6a6e78','#b8501a','#e07028','#ff8a2a'],
  portal:['#3a1404','#7a3008','#c85a10','#ff8a2a','#ffc890','#fff4e8'],
  adepts:[{id:'a',name:'Lancier',v:{robe:'#5a3a20',short:1,armor:'#8a6a3a',sash:'#e07028',pauldron:'#a87a3a',fore:'#6a5030',belt:'#3a2a18',head:'crestHelm',helm:'#9aa0a8',crest:'#ff8a2a',prop:'spear',shield:'orange'}},
          {id:'b',name:'Maître d’armes',v:{robe:'#3a2a1a',short:1,armor:'#6a6e78',sash:'#e07028',pauldron:'#b8501a',fore:'#4a4e56',belt:'#2a1e16',head:'topknot',hair:'#2a1a10',band:'#ff8a2a',prop:'sword',sheath:1}}]},
 sigil:{name:'Sigil',domain:'Savoir, mémoire, recherche',temple:'Athénée',register:'Ésotérique · le savoir',
  text:'Un lieu d’étude plutôt que de magie : temple de marbre gris pâle veiné sur deux degrés, six colonnes cannelées, fronton orné d’un sceau, frise de glyphes lumineux. Derrière les colonnes, la salle est tapissée de rayonnages de livres. Devant : un parvis dallé, un lutrin et son livre ouvert, des jarres à rouleaux, un tableau d’ardoise couvert de calculs, une stèle gravée.',
  pal:['#3c3c42','#6b6a72','#85848b','#9e9da3','#b4b2b6','#c6c4c6','#5a6a8a','#e4e8f0'],
  portal:['#3a3e4a','#6a7080','#a8b0c0','#dde2ee','#f4f6ff','#ffffff'],
  adepts:[{id:'a',name:'Érudit au rouleau',v:{robe:'#cfd0d4',trim:'#7e8698',toga:'#b4b6be',belt:'#9aa4bc',head:'scholar',hair:'#d8d8dc',beard:1,prop:'openScroll',skin:'#c89a78'}},
          {id:'b',name:'Archiviste',v:{robe:'#bfc1c8',trim:'#6a7488',toga:'#d6d7da',belt:'#6a7488',head:'band',hair:'#5a3a24',band:'#d6d7da',prop:'books'}}]},
 aether:{name:'Aether',domain:'Astronomie, lumière, jour et nuit',temple:'Grand Astrolabe',register:'Ésotérique · les astres',
  text:'Un astrolabe monumental dressé entre deux montants de basalte, sur un socle à gradins. Une mère d’argent graduée porte un tympan gravé de cercles de hauteur, et l’araignée lumineuse fait tourner l’écliptique et ses pointeurs d’étoiles. Une alidade traverse le disque, coiffé du trône et de son anneau. Devant : une carte du ciel incrustée dans le sol, une sphère armillaire et une lunette sur trépied.',
  pal:['#1a1816','#342f2a','#24203a','#2c2690','#4a48d0','#7a80ff','#c0c4ff','#d8dce4'],
  portal:['#140f40','#2c2690','#4a48d0','#7a80ff','#c0c4ff','#f0f0ff'],
  adepts:[{id:'a',name:'Forgeron des astres',v:{robe:'#2e2a3a',apron:'#4a3a30',trim:'#4a48d0',belt:'#6a70a0',head:'halo',hair:'#8a8278',prop:'hammer',symbol:'sunmoon',sleeve:'#3a3648'}},
          {id:'b',name:'Veilleuse des astres',v:{robe:'#24203a',mantle:'#3a3660',trim:'#a0a8ff',stripe:1,head:'halo',hair:'#d8dce4',prop:'astro',symbol:'sunmoon'}}]}};
const deityMakers={};for(const[k,d]of Object.entries(DEITIES))for(const it of d.adepts)deityMakers[k+'.'+it.id]=adept(k+'.'+it.id,it.v);
const fanatique=adept('credo',{robe:'#e8dfc6',mantle:'#c8a040',trim:'#a88228',stripe:1,symbol:'sun',head:'hoodRed',hood:'#a88228',eyeCol:E('#ffd27a'),prop:'torch',flame:['#ffd27a','#fff0b8','#e0a030'],light:GOLDL});
function bete(S){return mk('bete',S,(P,a,post)=>{const k=S.H?1:S.sw/15,cx=a.cx,fy=a.fy,bw=Math.round(13*k),bh=Math.round(9*k),by=fy-Math.round(6*k)-bh;
 for(const dx of[-bw+2,-bw+5,bw-6,bw-3])sr(P,cx+dx,by+bh-2,2,fy-(by+bh-2)+1,'#2a1418',.2);
 P.ell(cx,by+bh/2,bw,bh/2+1,(x,y,dx,dy)=>rp(R_(['#1a0e10','#2a1418','#3c1c22','#56282e']),.55-dx*.2-dy*.35,x,y));
 for(let i=-bw+3;i<bw-2;i+=3){P.line(cx+i,by+1,cx+i+1,by-3,'#d8cdb0')}
 const hx=cx+bw-2,hy=by+2;P.ell(hx+3,hy+2,4,3.5,(x,y,dx,dy)=>rp(R_(['#1a0e10','#2a1418','#3c1c22']),.6-dx*.2-dy*.3,x,y));P.line(hx+5,hy-2,hx+8,hy-5,'#d8cdb0');P.line(hx+1,hy-2,hx,hy-5,'#cfc3a2');
 post.push(Q=>{Q.set(hx+4,hy+1,E('#ff3346'));Q.set(hx+6,hy+1,E('#ff3346'));for(let i=-bw+4;i<bw-4;i+=5){Q.set(cx+i,by+bh/2|0,E('#c01828'));Q.set(cx+i+1,(by+bh/2|0)+1,E('#ff3346'))}});
 return[{x:hx+5,y:hy+1,c:RED,r:22,i:.8,fl:.2}]},72)}

// ---------- décor ----------
const TREES=new Map();
function treeSprite(seed,size,bloom){const k=seed+'/'+size+(bloom||'');if(TREES.has(k))return TREES.get(k);const R=rng(seed),W=Math.round(44*size)+8,H=Math.round(56*size)+8,P=new Pix(W,H),cx=W>>1,fy=H-4,th=Math.round((7+R()*5)*size),tw=Math.max(3,Math.round(4*size));
 for(let y=fy-th;y<=fy;y++)for(let x=cx-(tw>>1);x<cx-(tw>>1)+tw;x++){const t=(x-(cx-(tw>>1)))/(tw-1);P.set(x,y,rp(BARK,.8-t*.65+(hash(x,y,seed)-.5)*.2,x,y))}
 P.set(cx-(tw>>1)-1,fy,BARK[2]);P.set(cx-(tw>>1)+tw,fy,BARK[1]);
 const Rr=(12+R()*4)*size,cy=fy-th-Rr*.72,bl=[[cx,cy,Rr*.72]];const n=6+Math.floor(R()*3);for(let i=0;i<n;i++){const an=R()*Math.PI*2,d=R()*Rr*.55;bl.push([cx+Math.cos(an)*d,cy+Math.sin(an)*d*.8,Rr*(.42+R()*.24)])}
 bl.sort((a,b)=>b[1]-a[1]);for(const[bx,by,br]of bl)P.ell(bx,by,br,br*.92,(x,y,dx,dy)=>{const g=(cy+Rr-y)/(2*Rr);let v=.28+g*.4-dx*.12-dy*.2+(hash(x,y,seed)-.5)*.12;if(dy>.72)v-=.14;return rp(LEAF,v,x,y)});
 for(let i=0;i<n*3;i++){const x=Math.round(cx+(R()-.62)*Rr*1.1),y=Math.round(cy+(R()-.75)*Rr);if(P.get(x,y)>=0&&P.get(x,y-1)>=0&&P.get(x+1,y)>=0){P.set(x,y,LEAF[7]);P.set(x+1,y,LEAF[6])}}
 if(bloom)for(let i=0;i<n*6;i++){const x=Math.round(cx+(R()-.5)*Rr*1.8),y=Math.round(cy+(R()-.6)*Rr*1.6);if(P.get(x,y)>=0)P.set(x,y,i%3?ci('#fff4d8'):ci('#e8a0c0'))}
 if(R()<.4){for(let y=Math.round(cy+Rr*.3);y<fy-2;y++)if(hash(y,1,seed)>.3)P.set(cx+(tw>>1)+1,y,LEAF[3])}
 P.outline();const r={P,ax:cx,ay:fy,sw:Rr*1.3,lights:[]};TREES.set(k,r);return r}
function bushSprite(seed){const k='b'+seed;if(TREES.has(k))return TREES.get(k);const R=rng(seed),P=new Pix(26,18),cx=13,fy=15;
 for(let i=0;i<5;i++){const bx=cx+(R()-.5)*12,by=fy-4-R()*4,br=3+R()*2.5;P.ell(bx,by,br+1,br,(x,y,dx,dy)=>rp(LEAF,.42-dx*.15-dy*.25+(hash(x,y,seed)-.5)*.12,x,y))}
 if(R()<.5){const fc=R()<.5?'#e8a0c0':'#f0d060';for(let i=0;i<3;i++){const x=Math.round(cx+(R()-.5)*10),y=Math.round(fy-6-R()*4);if(P.get(x,y)>=0)P.set(x,y,fc)}}
 P.outline();const r={P,ax:cx,ay:fy,sw:12,lights:[]};TREES.set(k,r);return r}
const FLAMES={amber:{c:['#ff8a2a','#ffb347','#ffd27a','#ff9a30','#ffe0a0','#e06a20'],l:AMBER},
 green:{c:['#3fa83a','#7ae070','#c8f5b0','#7ae070','#e8ffe0','#2a8030'],l:GREEN},
 orange:{c:['#e05a10','#ff8a2a','#ffc890','#ff7a20','#fff0d0','#b84008'],l:ORANGE},
 white:{c:['#c8d0e0','#eef2ff','#ffffff','#dde2ee','#ffffff','#a8b0c0'],l:WHITEC},
 vb:{c:['#4a48d0','#7a80ff','#c0c4ff','#6a70f0','#f0f0ff','#2c2690'],l:VIOBLUE}};
function torchSprite(kind='amber',stand='pole'){const key='torch'+kind+stand;if(TREES.has(key))return TREES.get(key);const P=new Pix(12,32),cx=6,fy=28,F=FLAMES[kind];
 if(stand==='marble'){sr(P,cx-1,fy-16,4,17,MARBLE[4],.2);P.rect(cx-2,fy-18,6,3,MARBLE[3]);P.rect(cx-2,fy,6,1,MARBLE[2])}
 else if(stand==='basalt'){sr(P,cx-1,fy-16,4,17,BASALT[3],.2);P.rect(cx-2,fy-18,6,3,BASALT[2]);P.rect(cx-2,fy-18,6,1,SILVER[3])}
 else{P.rect(cx,fy-16,1,17,WOOD[3]);P.rect(cx+1,fy-16,1,17,WOOD[1]);P.rect(cx-2,fy-18,6,3,'#3a3030');P.rect(cx-1,fy-18,4,1,'#5a4a40')}P.outline();
 for(const[x,y,i]of[[cx,fy-19,0],[cx+1,fy-19,1],[cx,fy-20,2],[cx+1,fy-21,3],[cx,fy-22,4],[cx-1,fy-19,5]])P.set(x,y,E(F.c[i]));
 const r={P,ax:cx,ay:fy,sw:5,lights:[{x:cx,y:fy-20,c:F.l,r:52,i:1.1,fl:kind==='white'||kind==='vb'?.08:.35}]};TREES.set(key,r);return r}
function spr(key,w,h,ax,ay,fn){if(TREES.has(key))return TREES.get(key);const P=new Pix(w,h),post=[];const o=fn(P,post)||{};P.outline();for(const g of post)g(P);const r={P,ax,ay,sw:o.sw||w*.6,lights:o.lights||[]};TREES.set(key,r);return r}
const drumSprite=()=>spr('drum',20,22,10,19,P=>{const cx=10,fy=19;P.line(cx-6,fy,cx-4,fy-6,WOOD[2]);P.line(cx+6,fy,cx+4,fy-6,WOOD[2]);
 sr(P,cx-6,fy-13,12,8,'#8a6a40',.2);P.rect(cx-6,fy-12,12,1,ORNG[3]);P.rect(cx-6,fy-7,12,1,BRONZE[2]);for(let i=0;i<11;i+=2){P.set(cx-5+i,fy-11,'#e8dcc0');P.set(cx-4+i,fy-9,'#e8dcc0')}P.ell(cx,fy-13,6,2,'#e8dcc0');P.ell(cx,fy-13,4,1.2,'#d4c4a0');return{sw:12}});
const stakeSprite=()=>spr('stake',24,30,12,27,P=>{const fy=27;for(let k=0;k<5;k++){const x=2+k*4,h=16+((k*7)%5)*2;for(let y=fy-h;y<=fy;y++)for(let i=0;i<3;i++){if(y<fy-h+2&&i!==1)continue;P.set(x+i,y,rp(WOOD,.75-i*.3+(hash(x+i,y,2)-.5)*.15,x+i,y))}P.rect(x,fy-h+6,3,1,BRONZE[1])}return{sw:16}});
const BANNERS={ochre:['#e0a040','#c88a30','#8a5a1c'],orange:['#ff9a48','#e07028','#a8400e']};
function bannerSprite(kind='ochre'){const[c1,c2,c3]=BANNERS[kind];return spr('banner'+kind,16,44,4,41,P=>{const cx=4,fy=41;P.rect(cx,fy-36,1,37,WOOD[3]);P.set(cx,fy-38,'#c8ced6');P.set(cx,fy-37,'#a0a6ac');P.rect(cx-1,fy-36,9,1,WOOD[2]);
 for(let y=fy-35;y<fy-18;y++)for(let x=cx+1;x<cx+8;x++){if(y>fy-21&&((x-cx)%3)===((y-(fy-21))%3))continue;P.set(x,y,x===cx+1?c1:x===cx+7?c3:c2)}
 P.rect(cx+4,fy-32,1,9,BRONZE[4]);P.set(cx+4,fy-33,'#f0f0f0');P.rect(cx+3,fy-31,3,1,BRONZE[3]);return{sw:6}})}
const basinSprite=()=>spr('basin',28,18,14,15,(P,post)=>{const cx=14,fy=15;P.rect(cx-11,fy-7,23,6,STONE[2]);P.rect(cx-11,fy-7,1,6,STONE[3]);for(let x=cx-10;x<cx+12;x+=3)P.set(x,fy-3,STONE[1]);
 P.ell(cx+.5,fy-8,11.5,4.5,(x,y,dx,dy)=>rp(STONE,.62-dx*.2-dy*.3+(hash(x,y,1)-.5)*.2,x,y));P.ell(cx-6,fy-8,2,1,MOSS[2]);
 post.push(Q=>Q.ell(cx+.5,fy-8.5,8,2.6,(x,y)=>E(hash(x,y,7)>.82?'#e8ffe0':((x+y)&1?'#3fa83a':'#7ae070'))));return{sw:22,lights:[{x:cx,y:fy-8,c:GREEN,r:38,i:.85,fl:.1}]}});
const cairnSprite=()=>spr('cairn',22,28,11,25,(P,post)=>{const cx=11,fy=25;for(const[dx,dy,r]of[[-5,-2,3.2],[4,-2,3.5],[0,-3,3.8],[-2,-7,3],[3,-7,2.8],[0,-10,2.6]])P.ell(cx+dx,fy+dy,r,r*.85,(x,y,ddx,ddy)=>rp(STONE,.62-ddx*.2-ddy*.3,x,y));
 P.rect(cx-2,fy-15,5,4,'#e2d8bc');P.rect(cx-2,fy-12,5,1,'#c8bc9c');P.set(cx-1,fy-14,'#2a2018');P.set(cx+1,fy-14,'#2a2018');P.set(cx-5,fy-4,'#e2d8bc');P.set(cx-4,fy-4,'#e2d8bc');P.line(cx+3,fy-15,cx+3,fy-21,'#5a3a20');P.line(cx+3,fy-18,cx+5,fy-20,'#5a3a20');
 post.push(Q=>{Q.set(cx+2,fy-21,E('#7ae070'));Q.set(cx+3,fy-22,E('#b8f0a0'));Q.set(cx+5,fy-21,E('#7ae070'));Q.set(cx+6,fy-20,E('#3fa83a'))});return{sw:14,lights:[{x:cx+3,y:fy-21,c:GREEN,r:20,i:.6}]}});
const mushSprite=()=>spr('mush',14,10,7,8,(P,post)=>{for(const[x,h]of[[3,3],[7,4],[10,2]]){P.rect(x,8-h,1,h,'#d8cfb0');P.rect(x-1,7-h,3,1,'#b8b0a0');P.set(x,6-h,'#e8e0c8')}post.push(Q=>{Q.set(7,3,E('#b8f0a0'));Q.set(3,4,E('#7ae070'))});return{sw:8,lights:[{x:7,y:3,c:GREEN,r:12,i:.4}]}});
const rackSprite=()=>spr('rack',30,36,15,33,P=>{const fy=33;P.rect(3,fy-16,2,17,WOOD[2]);P.rect(25,fy-16,2,17,WOOD[2]);P.rect(2,fy-14,26,2,WOOD[3]);P.rect(2,fy-5,26,2,WOOD[3]);
 for(const x of[6,10,14]){P.line(x,fy,x+2,fy-28,WOOD[4]);P.rect(x+1,fy-31,2,3,'#c8ced6');P.set(x+2,fy-32,'#e6ecf2');P.set(x+1,fy-27,ORNG[3])}P.rect(19,fy-24,1,18,'#d0d6de');P.rect(20,fy-24,1,18,'#8a9098');P.rect(18,fy-7,4,1,BRONZE[3]);P.rect(19,fy-6,2,3,'#3a2a20');
 P.ell(24,fy-9,3.5,4.5,(x,y,dx,dy)=>dx*dx+dy*dy>.6?BRONZE[2]:ORNG[3]);return{sw:22}});
const dummySprite=()=>spr('dummy',22,32,11,29,P=>{const cx=11,fy=29;P.rect(cx,fy-24,2,25,WOOD[2]);P.rect(cx-8,fy-19,18,2,WOOD[3]);P.ell(cx+1,fy-13,5,7,(x,y,dx,dy)=>rp(R_(['#7a6030','#a08040','#c8a860','#e0c880']),.6-dx*.3-dy*.2+(hash(x,y,2)-.5)*.3,x,y));
 P.ell(cx+1,fy-23,3.5,3.5,(x,y,dx,dy)=>rp(R_(['#8a7a5a','#b0a07a','#cfc29a']),.6-dx*.3-dy*.3,x,y));for(let k=0;k<10;k++){P.set(cx-4+k,fy-18+k,ORNG[3]);P.set(cx-3+k,fy-18+k,ORNG[2])}P.line(cx-1,fy-11,cx+3,fy-14,'#4a3020');P.line(cx,fy-8,cx+4,fy-10,'#4a3020');return{sw:14}});
const lecternSprite=()=>spr('lectern',18,26,9,23,(P,post)=>{const cx=9,fy=23;P.rect(cx-3,fy-1,7,2,MARBLE[2]);P.rect(cx,fy-12,2,12,MARBLE[4]);P.rect(cx+1,fy-12,1,12,MARBLE[2]);P.rect(cx-5,fy-15,12,2,WOOD[3]);
 P.rect(cx-5,fy-18,5,3,'#f4f0e4');P.rect(cx+1,fy-19,5,3,'#ece6d6');P.set(cx,fy-18,'#8a8070');for(let x=cx-4;x<cx+5;x+=2)P.set(x,fy-17,'#9a9aa4');post.push(Q=>{Q.set(cx-2,fy-19,E('#ffffff'));Q.set(cx+3,fy-20,E('#eef2ff'))});return{sw:10,lights:[{x:cx,y:fy-19,c:WHITEC,r:20,i:.6,fl:.05}]}});
const jarSprite=()=>spr('jar',16,24,8,21,P=>{const cx=8,fy=21;P.ell(cx,fy-6,5,6,(x,y,dx,dy)=>rp(R_(['#5a4a3a','#7a6450','#9a8064','#b89c7c']),.6-dx*.3-dy*.2,x,y));P.rect(cx-3,fy-13,7,2,'#7a6450');
 for(const[dx,h]of[[-2,5],[0,7],[2,4],[1,6]]){P.rect(cx+dx,fy-13-h,2,h,'#ece4cc');P.set(cx+dx,fy-13-h,'#c8bc9c')}P.rect(cx-4,fy-7,9,1,'#d8dbe4');return{sw:10}});
const boardSprite=()=>spr('board',26,30,13,27,P=>{const fy=27;P.line(4,fy,8,fy-24,WOOD[2]);P.line(22,fy,18,fy-24,WOOD[2]);P.line(13,fy,13,fy-20,WOOD[1]);sr(P,3,fy-25,20,14,'#2a3038',.1);P.rect(3,fy-25,20,1,WOOD[3]);P.rect(3,fy-12,20,1,WOOD[3]);
 for(let k=0;k<14;k++){const a=k/14*Math.PI*2;P.set(Math.round(9+Math.cos(a)*3.3),Math.round(fy-18+Math.sin(a)*3.3),'#e8ecf2')}P.line(9,fy-18,19,fy-22,'#c8ccd4');P.line(14,fy-15,20,fy-15,'#c8ccd4');P.line(14,fy-17,18,fy-17,'#a8acb4');P.set(17,fy-20,'#ffffff');P.set(9,fy-18,'#ffffff');return{sw:16}});
const armillarySprite=()=>spr('armil',26,38,13,35,(P,post)=>{const cx=13,fy=35;P.rect(cx-4,fy-3,9,3,BASALT[3]);P.rect(cx-4,fy-3,9,1,SILVER[3]);P.rect(cx-1,fy-12,3,9,BASALT[2]);P.rect(cx-2,fy-13,5,1,SILVER[2]);const oy=fy-22;
 post.push(Q=>{for(let k=0;k<64;k++){const t=k/64*Math.PI*2;[[Math.cos(t)*8,Math.sin(t)*8],[Math.cos(t)*8,Math.sin(t)*2.6],[Math.cos(t)*2.6,Math.sin(t)*8]].forEach(([x,y],i)=>Q.set(Math.round(cx+.5+x),Math.round(oy+y),i===0?SILVER[3]:E(i===1?'#7a80ff':'#a0a8ff')))}Q.rect(cx-1,oy-1,3,3,E('#c0c4ff'));Q.set(cx,oy,E('#ffffff'))});
 return{sw:16,lights:[{x:cx,y:oy,c:VIOBLUE,r:30,i:.8,fl:.05}]}});
const telescopeSprite=()=>spr('scope',26,30,13,27,(P,post)=>{const cx=13,fy=27;P.line(cx,fy-10,cx-6,fy,WOOD[2]);P.line(cx,fy-10,cx+6,fy,WOOD[2]);P.line(cx,fy-10,cx+1,fy,WOOD[1]);for(let k=-1;k<=1;k++)P.line(cx-8,fy-6+k,cx+9,fy-20+k,k?SILVER[2]:SILVER[3]);P.rect(cx-9,fy-7,3,3,SILVER[1]);
 post.push(Q=>{Q.set(cx+9,fy-21,E('#a0a8ff'));Q.set(cx+10,fy-21,E('#7a80ff'))});return{sw:14}});
function flowerSprite(seed){const k='f'+seed;if(TREES.has(k))return TREES.get(k);const R=rng(seed),P=new Pix(16,10),fy=8;for(let i=0;i<5;i++){const x=Math.round(3+R()*10),h=2+Math.floor(R()*3);P.rect(x,fy-h,1,h,LEAF[4]);P.set(x,fy-h-1,R()<.5?'#fff4d8':'#e8a0c0')}
 const r={P,ax:8,ay:fy,sw:6,lights:[]};TREES.set(k,r);return r}
function segDist(x,z,pts){let m=1e9;for(let k=1;k<pts.length;k++){const[a,b]=pts[k-1],[c,d]=pts[k],vx=c-a,vz=d-b,t=Math.max(0,Math.min(1,((x-a)*vx+(z-b)*vz)/(vx*vx+vz*vz)));m=Math.min(m,Math.hypot(x-a-vx*t,z-b-vz*t))}return m}
function jungleGround(o){return(x,z,sx,sy)=>{if(o.overlay){const c=o.overlay(x,z,sx,sy);if(c!=null)return c}const e=((x-o.cx)/o.rx)**2+((z-o.cz)/o.rz)**2,n=vnoise(x*1.3,z*1.3,7),tx=Math.floor(x),tz=Math.floor(z);
 if(o.ruin){const[r0,q0,r1,q1]=o.ruin;if(x>r0&&x<r1&&z>q0&&z<q1&&hash(tx*3,tz*7,11)>.16){const u=x-tx,v=z-tz,px=1/CT;if(vnoise(x*1.6,z*1.6,9)>.64)return rp(MOSS,.55+(hash(sx,sy,2)-.5)*.4,sx,sy);if(u<px||v<px)return STONE[1];return rp(STONE,.5+(hash(tx,tz,5)-.5)*.3+(n-.5)*.2+(v<px*2?.1:0),sx,sy)}}
 if(o.path){const d=segDist(x,z,o.path);if(d<.5+n*.3){if(hash(sx,sy,4)>.985)return DIRT[5];return rp(DIRT,.55+(n-.5)*.4-(d>.45+n*.3?.2:0),sx,sy)}}
 if(o.grid){const u=x-tx,v=z-tz;if((u<1/CT||v<1/CT)&&((sx+sy)&1))return GRASS[2]}
 let v=.6+(n-.5)*.35;if(e>1)v-=.3*Math.min(1,(e-1)*1.6);const h=hash(sx,sy,3);
 if(h>.965&&hash(sx,sy-1,3)<.5)v+=.22;if(e<1&&h>.996)return hash(sx,sy,8)>.5?ci('#f0d060'):ci('#e8a0c0');if(e>1&&h<.03)return BARK[2];return rp(GRASS,v,sx,sy)}}
function forest(objs,b,inside,seed,step=1.3){const R=rng(seed);for(let z=b[1];z<b[3];z+=step*.8)for(let x=b[0];x<b[2];x+=step){const X=x+(R()-.5)*step*.8,Z=z+(R()-.5)*step*.6;if(inside(X,Z))continue;const r=R();
 if(r<.78)objs.push(sprObj(X,Z,()=>treeSprite(1+Math.floor(R()*0)+(Math.floor(hash(Math.round(X*10),Math.round(Z*10),3)*8)),[.85,1,1.15][Math.floor(hash(Math.round(X*7),Math.round(Z*7),4)*3)]),{shadow:1}));
 else objs.push(sprObj(X,Z,()=>bushSprite(Math.floor(hash(Math.round(X*9),Math.round(Z*9),5)*6)),{shadow:.6}))}}

// ---------- bâtiments (même langage que les adeptes) ----------
const ember=E('#4a2a10');
function druidHut(x0,z0){const x1=x0+3.4,z1=z0+2.2,h=1.9,wall=logs(WOOD,.24,3),mid=(x1-x0)/2;
 const mat=(f,u,v,x,y)=>{if(f==='south'&&Math.abs(u-mid)<.42&&v>h-1.45){if(Math.abs(u-mid)>.34||v<h-1.38)return WOOD[0];return(x+y)&1?ember:E('#2e1a0c')}if((f==='south'||f==='east')&&(u<.14||u>(f==='south'?x1-x0:z1-z0)-.14))return rp(BARK,.5+(FB[f]||.6)*.3,x,y);return wall(f,u,v,x,y)};
 return{layer:true,key:ctx=>ctx.iso?ctx.depth(x0+mid,z0+1.1):ctx.depth(x0+mid,z1),draw(L,ctx,S){CT=ctx.T;S.shadowBox(ctx,x0,z0,x1,z1,h+1.3,.85);box(L,ctx,x0,z0,x1,z1,0,h,mat);gable(L,ctx,x0,z0,x1,z1,h,1.3,.26,thatch(THATCH,5),mat,THATCH[0]);
  const p=ctx.p;for(const u of[.6,x1-x0-.6]){const[a,b]=p(x0+u,h-.2,z1+.26);L.rect(a,b,1,4,'#3a2a1a');L.set(a,b+4,'#e2d8bc');L.set(a-1,b+5,'#e2d8bc')}
  for(const u of[.07,x1-x0-.07]){const[a,b]=p(x0+u,h*.55,z1);L.set(a,b,E('#ffb347'));L.set(a,b+2,E('#ff9a30'))}
  return{lights:projL(ctx,[{x:x0+mid,y:.5,z:z1+.2,c:AMBER,r:34,i:.7,fl:.25}])}}}}
function menhir(x,z,col='#ffb347',L=AMBER){return boxObj(x,z,x+.55,z+.45,1.7,glyph(blocks(STONE,.55,.42,21,{moss:.3}),'south',.12,.3,.32,1.1,col,4,STONE[1]),{lights:[{x:x+.27,y:1,z:z+.5,c:L,r:26,i:.7,fl:.1}]})}
// ---- Medeina : sanctuaire du cycle (vie, mort, renaissance)
function medeinaTemple(x0,z0){const W=4.2,D=2.6,x1=x0+W,z1=z0+D,b0=.35,h=2.0,rh=1.5,ov=.32,mid=W/2,Y=b0+h;
 const plinth=blocks(STONE,.5,.18,41,{moss:.45}),wallL=logs(WOOD,.22,3),th=thatch(THATCH,6,.52);
 const glowG=(x,y)=>E(hash(x,y,5)>.55?'#7ae070':((x+y)&1?'#3fa83a':'#b8f0a0'));
 const wall=(f,u,v,x,y)=>{if(f==='south'){const du=u-mid;
   if(Math.abs(du)<.5&&v>h-1.25){const top=h-1.25+.28*(1-Math.sqrt(Math.max(0,1-(du/.5)**2)));if(v>=top){if(Math.abs(du)>.42||v<top+.07)return rp(BARK,.6,x,y);return glowG(x,y)}}
   for(const wu of[.85,W-.85]){const dx=u-wu,dy=v-1.1,r2=dx*dx+dy*dy;if(r2<.05){if(r2>.028)return rp(BARK,.55,x,y);return glowG(x,y)}}
   if(u<.16||u>W-.16){if(Math.abs(v-1.2)<.2&&((Math.round(v*CT)+(u<.16?0:1))&1))return E('#7ae070');return rp(BARK,.6,x,y)}}
  return wallL(f,u,v,x,y)};
 const roof=(f,u,v,x,y)=>{const hh=hash(x,y,17);if(hh>.982)return hh>.991?ci('#e8a0c0'):ci('#fff4d8');if(hh<.025)return LEAF[6];return th(f,u,v,x,y)};
 const hallO={layer:true,key:ctx=>ctx.depth(x0+mid,z1+.2),draw(L,ctx,S){CT=ctx.T;const p=ctx.p,zm=(z0+z1)/2;S.shadowBox(ctx,x0-.2,z0-.2,x1+.2,z1+.2,Y+rh,.85);
  box(L,ctx,x0-.2,z0-.2,x1+.2,z1+.2,0,b0,plinth);box(L,ctx,x0+mid-.6,z1+.2,x0+mid+.6,z1+.55,0,.18,plinth);
  box(L,ctx,x0,z0,x1,z1,b0,h,wall);gable(L,ctx,x0,z0,x1,z1,Y,rh,ov,roof,wall,THATCH[0]);
  for(const xe of[x0-ov,x1+ov]){const[a,c]=p(xe,Y+rh,zm),s=xe<x0?-1:1;L.line(a,c,a+s*3,c-5,'#e2d8bc');L.line(a+s*2,c-3,a+s*5,c-4,'#e2d8bc');L.line(a+s,c-4,a,c-8,'#d4c8a8')}
  const[tx,ty]=p(x0+mid,Y+rh,zm);for(let y=ty-16;y<=ty+1;y++){const w=y>ty-4?5:3;for(let i=0;i<w;i++)L.set(tx-1+i-(w>3?1:0),y,rp(BARK,.8-i*.22,tx+i,y))}
  const R=rng(9);for(let k=0;k<11;k++){const bx=tx-4-R()*17,by=ty-17-R()*17,br=6+R()*4;L.ell(bx,by,br,br*.9,(x,y,dx,dy)=>rp(LEAF,.58-dx*.15-dy*.25+(hash(x,y,3)-.5)*.12,x,y))}
  for(let k=0;k<60;k++){const x=Math.round(tx-4-R()*24),y=Math.round(ty-12-R()*30);if(L.get(x,y)>=0)L.set(x,y,k%3?ci('#fff4d8'):ci('#e8a0c0'))}
  for(const[a1,b1,a2,b2]of[[1,-15,8,-26],[8,-26,16,-30],[8,-26,10,-37],[2,-19,14,-18],[14,-18,21,-24],[3,-27,2,-38],[16,-30,19,-35]])L.line(tx+a1,ty+b1,tx+a2,ty+b2,BARK[1]);
  const buds=[[16,-30],[10,-37],[21,-24],[2,-38],[19,-35]];
  return{post:Q=>{for(const[xx,yy]of buds){Q.set(tx+xx,ty+yy,E('#7ae070'));Q.set(tx+xx+1,ty+yy-1,E('#b8f0a0'))}
    const ey=Y-rh*ov/(D/2);for(const u of[.35,1.25,W-1.25,W-.35]){const[a,c]=p(x0+u,ey,z1+ov);Q.set(a,c+1,ci('#3a2a1a'));Q.set(a,c+2,ci('#3a2a1a'));Q.set(a,c+3,E('#7ae070'));Q.set(a,c+4,E('#3fa83a'))}},
   lights:[...projL(ctx,[{x:x0+mid,y:b0+.4,z:z1+.2,c:GREEN,r:42,i:.85,fl:.12},{x:x0+.85,y:Y-1.1,z:z1,c:GREEN,r:18,i:.5},{x:x1-.85,y:Y-1.1,z:z1,c:GREEN,r:18,i:.5},...[.35,1.25,W-1.25,W-.35].map(u=>({x:x0+u,y:Y-.6,z:z1+ov,c:GREEN,r:14,i:.45}))]),{x:tx+12,y:ty-30,c:GREEN,r:30,i:.5,fl:.1}]}}};
 return[hallO,menhir(x0-1.1,z0+1.5,'#7ae070',GREEN),menhir(x1+.55,z0+1.5,'#7ae070',GREEN),sprObj(x0-.3,z1+1.3,basinSprite),sprObj(x1+.3,z1+1.2,cairnSprite),
  sprObj(x0+.9,z1+2.3,()=>flowerSprite(1),{shadow:0}),sprObj(x1-1,z1+2.4,()=>flowerSprite(2),{shadow:0}),sprObj(x0-.7,z1+.3,mushSprite,{shadow:0}),sprObj(x1+.9,z1+.1,mushSprite,{shadow:0}),sprObj(x0+.3,z0-.6,mushSprite,{shadow:0})]}
function medeinaGround(x0,z0){const cx=x0+2.1,cz=z0+2.6+1.9;return(x,z,sx,sy)=>{const dx=x-cx,dz=(z-cz)*1.15,r=Math.hypot(dx,dz);if(r>1.25)return null;let a=Math.atan2(dz,dx);if(a<0)a+=Math.PI*2;
 for(let k=0;k<4;k++){const rr=.12+(a+k*Math.PI*2)*.042;if(Math.abs(r-rr)<.055)return hash(Math.round(a*6),k,4)>.8?E('#7ae070'):rp(STONE,.55+(hash(sx,sy,2)-.5)*.3,sx,sy)}if(r<.12)return E('#b8f0a0');return null}}

// ---- Indra : salle d'armes (discipline martiale)
function indraTemple(x0,z0){const W=4.6,D=2.6,x1=x0+W,z1=z0+D,b0=.45,h=1.9,rh=1.7,ov=.36,mid=W/2,Y=b0+h;
 const base=blocks(STONE,.6,.22,51,{moss:.15}),vl=vlogs(WOOD,.2,4),shingle=tiles(WOOD,9);
 const wall=(f,u,v,x,y)=>{if(f==='south'){const du=Math.abs(u-mid);if(du<.55&&v>h-1.3){if(du>.47||v<h-1.23||du<.03)return WOOD[0];if(Math.round(v*CT)%4===0&&Math.round(du*CT)%3===1)return BRONZE[3];return(x+y)&1?E('#5a2a0c'):E('#3a1a08')}}
  if(f!=='top'&&(Math.abs(v-1.0)<.05||v>h-.09))return rp(WOOD,.22,x,y);if((f==='south'&&(u<.15||u>W-.15))||(f==='east'&&(u<.15||u>D-.15)))return rp(BARK,.65,x,y);return vl(f,u,v,x,y)};
 const hallO={layer:true,key:ctx=>ctx.depth(x0+mid,z1),draw(L,ctx,S){CT=ctx.T;const p=ctx.p,zm=(z0+z1)/2;S.shadowBox(ctx,x0-.15,z0-.15,x1+.15,z1+.15,Y+rh,.85);
  box(L,ctx,x0-.15,z0-.15,x1+.15,z1+.15,0,b0,base);box(L,ctx,x0+mid-.7,z1+.15,x0+mid+.7,z1+.5,0,.22,base);
  box(L,ctx,x0,z0,x1,z1,b0,h,wall);gable(L,ctx,x0,z0,x1,z1,Y,rh,ov,shingle,wall,WOOD[0]);
  for(const xe of[x0-ov,x1+ov]){const[a,c]=p(xe,Y+rh,zm),s=xe<x0?-1:1;L.line(a,c,a+s*4,c-6,'#e8e0c8');L.line(a,c,a-s,c-6,'#e8e0c8');L.set(a+s*4,c-7,'#d8d0b8')}
  for(const u of[1.1,mid,W-1.1]){const[a,c]=p(x0+u,Y+rh,zm);L.rect(a,c-10,1,10,WOOD[1]);L.rect(a+1,c-10,5,3,'#ff8a2a');L.rect(a+1,c-9,4,1,'#e07028');L.set(a+6,c-9,'#b8501a');L.set(a,c-11,BRONZE[4])}
  for(const u of[.55,1.35,W-1.35,W-.55]){const[a,c]=p(x0+u,b0+h-1.05,z1);L.ell(a,c,4,4,(x,y,dx,dy)=>dx*dx+dy*dy>.62?rp(BRONZE,.65-dx*.3,x,y):rp(ORNG,.7-dx*.3-dy*.3,x,y));L.rect(Math.floor(a),c-3,1,6,BRONZE[4]);L.set(Math.floor(a),c-4,'#f0f0f0')}
  const[la,lc]=p(x0+mid-.6,b0+h-.64,z1);for(let i=0;i<24;i++)for(let j=0;j<3+(i%4===0?2:0);j++)L.set(la+i,lc+j,j===0?ci('#b8501a'):i%4===0?ci('#ffc890'):ci('#e07028'));
  return{lights:projL(ctx,[{x:x0+mid,y:b0+.5,z:z1+.25,c:ORANGE,r:38,i:.75,fl:.3}])}}};
 return[hallO,sprObj(x0-1.0,z1+.9,rackSprite),sprObj(x1+1.0,z1+1.0,dummySprite),sprObj(x1+.9,z0+.9,stakeSprite),sprObj(x0-.9,z0+.9,stakeSprite),
  sprObj(x0-.5,z1+2.4,()=>bannerSprite('orange'),{shadow:.5}),sprObj(x1+.4,z1+2.5,()=>bannerSprite('orange'),{shadow:.5}),sprObj(x0+mid+1.6,z1+.8,drumSprite)]}
function indraGround(x0,z0){const X0=x0-.5,X1=x0+5.1,Z0=z0+3.1,Z1=z0+6,cx=x0+2.3,cz=z0+4.6;return(x,z,sx,sy)=>{if(x<X0||x>X1||z<Z0||z>Z1)return null;const px=1/CT;
 if(x-X0<.12||X1-x<.12||Z1-z<.12)return rp(STONE,.5+(hash(Math.floor(x*4),Math.floor(z*4),3)-.5)*.4,sx,sy);const r=Math.hypot(x-cx,(z-cz)*1.2);if(Math.abs(r-1.05)<.05)return DIRT[5];
 let v=.6+(vnoise(x*2,z*2,5)-.5)*.25;if(r<1.05&&(Math.floor((x+z)*CT/3)%3===0))v+=.08;if(r>1.05&&Math.floor(z*CT)%5===0&&hash(sx>>2,sy,4)>.4)v-=.12;return rp(DIRT,v,sx,sy)}}

// ---- Sigil : athénée (recherche du savoir)
function sigilTemple(x0,z0){const W=4.4,D=2.6,x1=x0+W,z1=z0+D,s1=.18,s2=.38,ch=2.0,mid=W/2,zr=z1-.1,cz1=zr-.55,Y=s2+ch,eh=.32,rh=.95;
 const step=blocks(MARBLE,.7,.18,61),plain=(f,u,v,x,y)=>marbleV((FB[f]??.7)*.92+(hash(x,y,2)-.5)*.06,x,y);
 const SP=['#5a6a8a','#7a5a40','#c8cad2','#6a7a5a','#3a4458','#8a7a6a','#4a5a70'].map(ci),cw=W-.5;
 const cella=(f,u,v,x,y)=>{if(f!=='south')return plain(f,u,v,x,y);const du=Math.abs(u-cw/2);
  if(du<.4&&v>ch-1.5){if(du>.33||v<ch-1.43)return MARBLE[2];return E((x+y)&1?'#c4c8d4':'#8a90a0')}
  if(v>.3&&v<ch-.08&&u>.15&&u<cw-.15&&du>.5){const sv=(v-.3)/((ch-.38)/4),row=Math.floor(sv),lv=sv-row;if(lv<.2)return WOOD[1];const col=Math.floor(u*CT/1.5);if(hash(col,row,3)>.9)return WOOD[0];return sh(SP[Math.floor(hash(col,row,5)*SP.length)],lv>.85?-.3:(col&1?-.08:.08))}
  return plain(f,u,v,x,y)};
 const colM=(f,u,v,x,y)=>f==='top'?MARBLE[5]:marbleV((FB[f]??.7)*(Math.floor(u*CT)%2?.82:1.0),x,y);
 const frieze=(f,u,v,x,y)=>{if(f==='south'&&v>.09&&v<.24){const gx=Math.floor(u*CT/2);if(hash(gx,1,8)>.55&&gx%4!==0)return E((x&1)?'#d8dce6':'#a8aebc');return MARBLE[2]}if(f==='south'&&v>.27)return MARBLE[3];return plain(f,u,v,x,y)};
 const ped=(f,u,v,x,y)=>marbleV(.78+(hash(x,y,2)-.5)*.06,x,y),slate=tiles(SLATE,63);
 const ob=boxObj(x0-1.3,z0+1.6,x0-.8,z0+2.0,1.8,glyph(blocks(MARBLE,.5,.4,64),'south',.1,.3,.3,1.2,'#ffffff',6,MARBLE[2]),{lights:[{x:x0-1.05,y:1,z:z0+2.05,c:WHITEC,r:22,i:.55,fl:.04}]});
 return[{layer:true,key:ctx=>ctx.depth(x0+mid,z1+.3),draw(L,ctx,S){CT=ctx.T;const p=ctx.p;S.shadowBox(ctx,x0,z0,x1,zr,Y+eh+rh,.85);
  box(L,ctx,x0-.35,z0-.1,x1+.35,z1+.35,0,s1,step);box(L,ctx,x0-.18,z0-.05,x1+.18,z1+.15,s1,s2-s1,step);
  box(L,ctx,x0+.25,z0+.1,x1-.25,cz1,s2,ch,cella);
  for(let k=0;k<6;k++){const c=x0+.3+k*(W-.6)/5;box(L,ctx,c-.19,zr-.42,c+.19,zr-.04,s2,.08,colM);box(L,ctx,c-.13,zr-.36,c+.13,zr-.1,s2+.08,ch-.2,colM);box(L,ctx,c-.21,zr-.45,c+.21,zr-.01,Y-.12,.12,colM)}
  box(L,ctx,x0,z0,x1,zr,Y,eh,frieze);gableZ(L,ctx,x0,z0,x1,zr,Y+eh,rh,.12,slate,ped,SLATE[0]);
  const[ax,ay]=p(x0+mid,Y+eh+rh,zr);L.rect(ax-1,ay-3,3,3,MARBLE[5]);L.set(ax,ay-4,MARBLE[6]);for(const xe of[x0,x1]){const[a,c]=p(xe,Y+eh,zr);L.rect(a-1,c-2,3,2,MARBLE[5])}
  const[sx,sy]=p(x0+mid,Y+eh+rh*.36,zr);
  return{post:Q=>{for(let k=0;k<20;k++){const an=k/20*Math.PI*2;Q.set(Math.round(sx+Math.cos(an)*3.5),Math.round(sy+Math.sin(an)*2.6),E(k%5?'#b8bece':'#e4e8f0'))}Q.set(sx,sy,E('#e4e8f0'));Q.set(sx-1,sy,E('#9aa2b4'));Q.set(sx+1,sy,E('#9aa2b4'))},
   lights:[{x:sx,y:sy,c:WHITEC,r:22,i:.45,fl:.04},...projL(ctx,[{x:x0+mid,y:s2+.5,z:cz1+.1,c:WHITEC,r:36,i:.65,fl:.05},{x:x0+1,y:Y+.15,z:zr,c:WHITEC,r:18,i:.3},{x:x1-1,y:Y+.15,z:zr,c:WHITEC,r:18,i:.3}])]}}},
  ob,sprObj(x0-.5,z1+1.2,lecternSprite),sprObj(x1+.5,z1+.9,jarSprite),sprObj(x1+.95,z1+1.25,jarSprite),sprObj(x1+.8,z1+2.3,boardSprite),sprObj(x0+.2,z1+2.5,lecternSprite)]}
function sigilGround(x0,z0){const X0=x0-.7,X1=x0+5.1,Z0=z0+2.9,Z1=z0+5.8;return(x,z,sx,sy)=>{if(x<X0||x>X1||z<Z0||z>Z1)return null;if(vnoise(x*1.7,z*1.7,13)>.7&&(x-X0<.6||X1-x<.6||Z1-z<.5))return null;
 const tx=Math.floor((x-X0)/.55),tz=Math.floor((z-Z0)/.42),u=(x-X0)-tx*.55,v=(z-Z0)-tz*.42,px=1/CT;if(u<px||v<px)return MARBLE[1];return rp(MARBLE,.62+(hash(tx,tz,7)-.5)*.2+(v<px*2?.08:0),sx,sy)}}

// ---- Aether : observatoire (astronomie)
function aetherTemple(x0,z0){const W=4.6,mid=W/2,x1=x0+W,z1=z0+2.4,cx=x0+mid,dz=z0+1.2,R=1.55,cy=R+1.0;
 const bas=blocks(BASALT,.55,.28,71,{band:[.06],bandR:SILVER}),plat=blocks(BASALT,.7,.35,72);
 return[{layer:true,key:ctx=>ctx.depth(cx,z1),draw(L,ctx,S){CT=ctx.T;const p=ctx.p,T=ctx.T;S.shadowBox(ctx,x0-.2,z0-.2,x1+.2,z1+.2,.6,.85);S.shadowBox(ctx,cx-R,dz-.15,cx+R,dz+.15,cy+R+.4,.7);
  const dais=m=>(f,u,v,x,y)=>{if(f!=='top')return m(f,u,v,x,y);const px=1/CT,tu=u%.6,tv=v%.45;if(tu<px||tv<px)return BASALT[1];const r=Math.hypot(x-ox0,(y-oy0)*1.6);if(Math.abs(r-22)<.8||Math.abs(r-34)<.8)return SILVER[2];return rp(BASALT,.5+(hash(Math.floor(u/.6),Math.floor(v/.45),9)-.5)*.2,x,y)};
  const[ox0,oy0]=p(cx,.6,(z0+z1)/2);box(L,ctx,x0-.2,z0-.2,x1+.2,z1+.2,0,.3,dais(plat));box(L,ctx,x0+.4,z0+.3,x1-.4,z1-.3,.3,.3,dais(bas));
  box(L,ctx,cx-R-.5,dz-.25,cx-R-.12,dz+.25,.6,cy+.3-.6,bas);box(L,ctx,cx+R+.12,dz-.25,cx+R+.5,dz+.25,.6,cy+.3-.6,bas);
  const[ox,oy]=p(cx,cy,dz+.25),r=R*T;
  for(const s of[-1,1]){const[ax,ay]=p(cx+s*(R+.3),cy,dz+.25);L.rect(Math.min(ax,ox+s*r),ay-1,Math.abs(ax-(ox+s*r))+1,3,SILVER[2])}
  L.ell(ox,oy,r+.5,r+.5,(x,y,dx,dy)=>{const d=Math.hypot(dx,dy);if(d>.88){const a=Math.atan2(dy,dx);if(d>.92&&Math.abs(Math.sin(a*36))<.22)return SILVER[0];return rp(SILVER,.78-dx*.25-dy*.25,x,y)}
   for(const k of[.22,.4,.56,.7])if(Math.abs(Math.hypot(dx,dy+.22)-k)<.022&&dy<.5)return DOMEV[4];if(Math.abs(dx)<.014||Math.abs(dy)<.014)return DOMEV[3];return rp(DOMEV,.38-dx*.12-dy*.12+(hash(x,y,5)-.5)*.1,x,y)});
  L.rect(ox-4,oy-r-5,9,5,SILVER[2]);L.rect(ox-3,oy-r-5,7,1,SILVER[4]);L.ell(ox+.5,oy-r-9,4,4,(x,y,dx,dy)=>Math.hypot(dx,dy)>.5?SILVER[3]:-1);
  for(let k=-1;k<=1;k++)L.line(ox-r*.86,oy+r*.5+k,ox+r*.86,oy-r*.5+k,k?SILVER[2]:SILVER[4]);
  for(const s of[-1,1]){const ex=Math.round(ox+s*r*.8),ey=Math.round(oy-s*r*.46);L.rect(ex-1,ey-2,3,4,SILVER[3])}
  return{post:Q=>{const ex=ox,ey=oy-r*.2,er=r*.58;for(let k=0;k<96;k++){const a=k/96*Math.PI*2;Q.set(Math.round(ex+Math.cos(a)*er),Math.round(ey+Math.sin(a)*er),E(k%8?'#7a80ff':'#c0c4ff'))}
    for(let k=0;k<48;k++){const a=k/48*Math.PI*2;Q.set(Math.round(ox+Math.cos(a)*r*.3),Math.round(oy+Math.sin(a)*r*.3),E('#4a48d0'))}
    const R2=rng(4);for(let k=0;k<10;k++){const a=R2()*Math.PI*2,d=r*(.36+R2()*.46),sx=Math.round(ox+Math.cos(a)*d),sy=Math.round(oy+Math.sin(a)*d);Q.line(sx,sy,Math.round(sx-Math.cos(a)*5),Math.round(sy-Math.sin(a)*5),E('#4a48d0'));Q.set(sx,sy,E('#f0f0ff'));Q.set(sx+1,sy,E('#a0a8ff'))}
    Q.rect(ox-1,oy-1,3,3,SILVER[4]);Q.set(ox,oy,E('#ffffff'))},
   lights:[{x:ox,y:oy,c:VIOBLUE,r:60,i:.9,fl:.05},...projL(ctx,[{x:cx,y:.6,z:z1,c:VIOBLUE,r:24,i:.35}])]}}},
  sprObj(x0-.6,z1+1.4,armillarySprite),sprObj(x1+.7,z1+1.3,telescopeSprite)]}
function aetherGround(x0,z0){const cx=x0+2.3,cz=z0+4.7;return(x,z,sx,sy)=>{const dx=x-cx,dz=(z-cz)*1.15,r=Math.hypot(dx,dz);if(r>1.55)return null;
 if(r>1.42)return rp(SILVER,.6,sx,sy);if(Math.abs(r-.9)<.035)return SILVER[2];const a=Math.atan2(dz,dx);if(r>1.1&&r<1.42&&Math.abs(Math.sin(a*6))<.05)return SILVER[2];
 if(hash(sx,sy,21)>.975)return E(hash(sx,sy,22)>.5?'#c0c4ff':'#7a80ff');return rp(BASALT,.45+(hash(Math.floor(x*3),Math.floor(z*3),5)-.5)*.2,sx,sy)}}
const pillarMat=(seed,glyphOn)=>{const m=blocks(STONE,.5,.33,seed,{moss:.32});return glyphOn?glyph(m,'south',.25,.4,.3,1.2,'#5ce8ff',seed,STONE[1]):m};
const pillar=(x,z,h,seed,g)=>boxObj(x,z,x+.8,z+.8,h,pillarMat(seed,g),{lights:g?[{x:x+.4,y:.9,z:z+.85,c:CYAN,r:24,i:.55}]:[]});

// ---------- planches ----------
const sprAt=(x,z,f,o)=>sprObj(x,z,f,o);
function perspective(iso,S=SCALES.inter){const W=320,H=224,ctx=iso?projIso(18,124,22):proj34(20,20,30);const sc=new Scene(W,H);
 const ruin=[8,2.2,12.4,5.6],path=[[-2,9.8],[2,8.4],[5,6.8],[7.5,5.6],[9,4.6]];
 const ground=jungleGround({cx:7,cz:5.2,rx:6.6,rz:4.5,path,ruin});const objs=[];
 objs.push(druidHut(1.2,1.4),menhir(5.1,3.2));
 objs.push(sprAt(1.3,4.3,torchSprite,{shadow:0}),sprAt(4.8,4.3,torchSprite,{shadow:0}));
 objs.push(pillar(8.1,2.3,2.6,31,1),pillar(11.5,2.3,1.5,32,0),pillar(8.1,4.7,1.0,33,0),pillar(11.5,4.7,2.3,34,1),boxObj(9,2.3,11.4,2.8,.7,blocks(STONE,.6,.35,35,{moss:.4})));
 objs.push(sprAt(9.6,4.7,()=>recrue(S)),sprAt(10.9,6.3,()=>veterane(S)),sprAt(9.3,6.6,()=>soldat(S)));
 objs.push(sprAt(2.4,5.3,()=>deityMakers['medeina.a'](S)),sprAt(3.8,5.7,()=>deityMakers['indra.a'](S)));
 objs.push(sprAt(12.6,7.7,()=>bete(S)));
 forest(objs,[-7,-8,20,17],(x,z)=>((x-7)/6.6)**2+((z-5.2)/4.5)**2<1.12||segDist(x,z,path)<1.2,77);
 return sc.bake(ctx,ground,objs)}
function lineup(W,H,T,items,o={}){const ctx=proj34(T,0,o.oy??0),sc=new Scene(W,H);const ground=jungleGround({cx:W/T/2,cz:H/T/2,rx:99,rz:99,grid:o.grid});const objs=items.map(([x,z,f,opt])=>typeof f==='function'?sprAt(x,z,f,opt):f);return sc.bake(ctx,ground,objs)}
function scalePlate(S){return lineup(320,92,20,[[1.3,5.2,()=>recrue(S)],[3.1,5.2,()=>veterane(S)],[4.9,5.2,()=>soldat(S)],[6.4,5.2,()=>deityMakers['medeina.a'](S)],[7.9,5.2,()=>deityMakers['indra.a'](S)],[9.4,5.2,()=>deityMakers['sigil.a'](S)],[10.9,5.2,()=>deityMakers['aether.a'](S)],[12.6,5.2,()=>bete(S)],
 [0,0,pillar(13.9,4.5,2,41,1)],[0,0,sprObj(15.6,5.4,()=>treeSprite(3,1))]],{grid:1,oy:-24})}
function exilesPlate(S=SCALES.inter){return lineup(180,72,20,[[1.6,4.4,()=>recrue(S)],[4.4,4.4,()=>veterane(S)],[7.2,4.4,()=>soldat(S)]],{oy:-24})}
function deityPair(k,S=SCALES.inter){return lineup(110,76,20,DEITIES[k].adepts.map((it,i)=>[1.7+i*2,4.4,()=>deityMakers[k+'.'+it.id](S)]),{oy:-22})}
function deityLineup(S=SCALES.inter){const items=[];Object.keys(DEITIES).forEach((k,g)=>DEITIES[k].adepts.forEach((it,j)=>items.push([1.1+g*4+j*1.8,4.4,()=>deityMakers[k+'.'+it.id](S)])));return lineup(320,76,20,items,{oy:-22})}
function templeVignette(k,S=SCALES.inter){const ctx=proj34(20,0,90),sc=new Scene(320,256),path=[[8,16],[8,4.6]];
 const B={medeina:[5.9,1.0],indra:[5.7,1.0],sigil:[5.8,1.0],aether:[5.7,1.0]}[k],[bx,bz]=B;
 const overlay={medeina:medeinaGround,indra:indraGround,sigil:sigilGround,aether:aetherGround}[k](bx,bz);
 const ground=jungleGround({cx:8,cz:4.6,rx:7.4,rz:4.7,path,overlay});
 const objs=[...{medeina:medeinaTemple,indra:indraTemple,sigil:sigilTemple,aether:aetherTemple}[k](bx,bz)];
 const fl={medeina:'green',indra:'orange',sigil:'white',aether:'vb'}[k],st={medeina:'pole',indra:'pole',sigil:'marble',aether:'basalt'}[k];
 objs.push(sprAt(2.6,5.6,()=>torchSprite(fl,st),{shadow:0}),sprAt(13.4,5.6,()=>torchSprite(fl,st),{shadow:0}));
 DEITIES[k].adepts.forEach((it,i)=>objs.push(sprAt([4.4,11.6][i],[7.6,7.7][i],()=>deityMakers[k+'.'+it.id](S))));
 forest(objs,[-3,-5,19,14],(x,z)=>((x-8)/7.4)**2+((z-4.6)/4.7)**2<1.1||segDist(x,z,path)<1||(k==='medeina'&&x>bx-2&&x<bx+6&&z>bz-4&&z<bz+1),90+k.length);return sc.bake(ctx,ground,objs)}
function enemyPlate(S=SCALES.inter){return lineup(240,74,20,[[1.4,4.4,()=>recrue(S)],[3.4,4.4,()=>deityMakers['medeina.a'](S)],[5.4,4.4,()=>deityMakers['sigil.a'](S)],[7.6,4.4,()=>fanatique(S)],[10.2,4.4,()=>bete(S)]],{oy:-24})}

// Temple en sprite de jeu : 320×240 transparent, centre de l'emprise sur l'ancre, couleurs de jour (le jeu gère la nuit).
function templeSprite(k,T=18){const W=320,H=240,ax=160,ay=168,ctx=proj34(T,ax,ay),sc=new Scene(W,H);
 const B={medeina:[-2.1,-1.3],indra:[-2.3,-1.3],sigil:[-2.2,-1.4],aether:[-2.3,-1.2]}[k],[x0,z0]=B;
 const objs=({medeina:medeinaTemple,indra:indraTemple,sigil:sigilTemple,aether:aetherTemple})[k](x0,z0).filter(o=>o.z===undefined||o.z<z0+4.4);
 sc.bake(ctx,null,objs);const c=document.createElement('canvas');c.width=W;c.height=H;const g=c.getContext('2d'),img=g.createImageData(W,H),d=img.data;
 for(let i=0;i<W*H;i++){const v=sc.P.c[i],o=i*4;if(v>=0){d[o]=v>>16&255;d[o+1]=v>>8&255;d[o+2]=v&255;d[o+3]=255}else if(sc.sh[i]>0){d[o+3]=Math.round(sc.sh[i]*95)}}
 g.putImageData(img,0,0);return{img:c,anchor:[ax,ay]}}
function anchorPlate(){const ctx=proj34(20,0,6),sc=new Scene(220,150),px=5.5,pz=4.7,oyW=2.2;
 const ground=jungleGround({cx:5.5,cz:4,rx:99,rz:99,ruin:[1.5,2.4,9.5,7.6]});
 const ped={layer:true,key:c=>c.depth(px,pz+.7),draw(L,c,S){CT=c.T;S.shadowBox(c,px-1.1,pz-.7,px+1.1,pz+.7,1,.8);
  box(L,c,px-1.1,pz-.7,px+1.1,pz+.7,0,.3,blocks(STONE,.6,.3,82,{moss:.3}));box(L,c,px-.8,pz-.5,px+.8,pz+.5,.3,.7,glyph(blocks(STONE,.5,.25,81,{moss:.15}),'south',.25,.15,1.1,.5,'#9a3ab8',8,STONE[1]));
  const[ox,oy]=c.p(px,oyW,pz);
  return{post:Q=>{Q.ell(ox,oy+15,9,2.5,(x,y)=>((x+y)&1)?E('#2a0a34'):-1);
   Q.ell(ox,oy,13,13,(x,y,dx,dy)=>{const d=Math.hypot(dx,dy),fres=Math.max(0,d-.7)/.3,spec=Math.hypot(dx+.38,dy+.42);
    if(spec<.12)return E(spec<.05?'#f4d8ff':'#c060e0');if(spec<.22&&((x+y)&1))return E('#6a2088');
    if(fres>.5&&dx+dy>-.3)return E(fres>.85?'#9a3ab8':'#3e1050');if(fres>.7&&((x*3+y)%5===0))return E('#5a1a70');
    return E(rp(R_(['#040306','#08050c','#0e0814','#170c20']),.55-dx*.3-dy*.3,x,y))})},
   lights:[{x:ox,y:oy,c:[.85,.28,1.1],r:64,i:.95,fl:.3,add:.14}]}}};
 sc.bake(ctx,ground,[ped]);const[ox,oy]=ctx.p(px,oyW,pz);
 sc.fx=(g,t)=>{const R=rng(Math.floor(t*10)*7+3),n=3+Math.floor(R()*3);
  for(let b=0;b<n;b++){let a=R()*Math.PI*2,x=ox+Math.cos(a)*13,y=oy+Math.sin(a)*13;const len=10+R()*22,pts=[],br=[];
   for(let i=0;i<len;i++){a+=(R()-.5)*1.2;x+=Math.cos(a)*1.3;y+=Math.sin(a)*1.3;pts.push([Math.round(x),Math.round(y)]);if(i>4&&R()<.07){let ba=a+(R()<.5?-1:1),bx=x,by=y;for(let j=0;j<6;j++){ba+=(R()-.5);bx+=Math.cos(ba)*1.3;by+=Math.sin(ba)*1.3;br.push([Math.round(bx),Math.round(by)])}}}
   const all=pts.concat(br);g.fillStyle='rgba(154,58,184,.6)';for(const[x2,y2]of all){g.fillRect(x2-1,y2,1,1);g.fillRect(x2+1,y2,1,1);g.fillRect(x2,y2-1,1,1);g.fillRect(x2,y2+1,1,1)}
   g.fillStyle='#0a0010';for(const[x2,y2]of all)g.fillRect(x2,y2,1,1);g.fillStyle='#d080f0';const e=pts[pts.length-1];g.fillRect(e[0],e[1],1,1)}};
 return sc}
// ================= Bâtiments secondaires : planche de propositions (deux pistes par bâtiment) =================
const glowG=(x,y)=>E(hash(x,y,5)>.55?'#7ae070':((x+y)&1?'#3fa83a':'#b8f0a0'));
const glowW=(x,y)=>E((x+y)&1?'#c4c8d4':'#8a90a0');
const glowV=(x,y)=>E(hash(x,y,9)>.86?'#f0f0ff':((x+y)&1?'#4a48d0':'#2c2690'));
const fireV=(x,y)=>E(hash(x,y,11)>.7?'#c0c4ff':((x+y)&1?'#7a80ff':'#4a48d0'));
const fireO=(x,y)=>E(hash(x,y,12)>.7?'#ffc890':((x+y)&1?'#ff8a2a':'#c85a10'));
const WATER=R_(['#0a1620','#10222e','#18303e','#24445a']);
function lay(kx,kz,fn){return{layer:true,key:c=>c.depth(kx,kz),draw(L,c,S){CT=c.T;return fn(L,c,S,c.p)||{}}}}
const fillAt=(f,x,y)=>typeof f==='function'?f(x,y):f;
// ouverture sur une face sud (v mesuré depuis le haut de la face, H = hauteur de la face)
function doorAt(u,v,x,y,cu,w,hd,H,frame,fill,arch){const du=Math.abs(u-cu);if(du>w/2||v<H-hd)return null;const top=H-hd+(arch?.22*(1-Math.sqrt(Math.max(0,1-(du/(w/2))**2))):0);if(v<top)return null;if(du>w/2-.08||v<top+.07)return fillAt(frame,x,y);return fillAt(fill,x,y)}
function winAt(u,v,x,y,cu,cv,w,h,frame,fill,round){const du=u-cu,dv=v-cv;if(round){const r=Math.hypot(du,dv);if(r>w/2)return null;if(r>w/2-.07)return fillAt(frame,x,y);return fillAt(fill,x,y)}if(Math.abs(du)>w/2||Math.abs(dv)>h/2)return null;if(Math.abs(du)>w/2-.07||Math.abs(dv)>h/2-.07)return fillAt(frame,x,y);return fillAt(fill,x,y)}
const M=(base,...fs)=>(f,u,v,x,y)=>{if(f==='south')for(const g of fs){const c=g(u,v,x,y);if(c!=null)return c}return base(f,u,v,x,y)};
const roofY=(Z0,ey,zm,ry,z)=>ey+(ry-ey)*Math.max(0,Math.min(1,(z-Z0)/(zm-Z0)));

// petits accessoires
const anvilSprite=()=>spr('anvil',18,14,9,11,P=>{P.rect(5,8,8,3,BASALT[2]);P.rect(7,5,4,3,'#3a3e46');P.rect(3,3,12,2,'#5a606a');P.rect(3,3,12,1,'#8a909a');P.rect(1,3,2,1,'#5a606a');P.rect(6,10,6,1,WOOD[2]);return{sw:12}});
const benchSprite=()=>spr('bench',30,20,15,17,(P,post)=>{P.rect(3,9,2,9,WOOD[2]);P.rect(25,9,2,9,WOOD[2]);sr(P,1,6,28,3,WOOD[4],.2);
 for(let k=0;k<16;k++){const a=k/16*Math.PI*2;P.set(Math.round(8+Math.cos(a)*2.5),Math.round(3+Math.sin(a)*2.5),k%2?SILVER[3]:SILVER[1])}P.rect(13,3,7,2,SILVER[2]);P.rect(13,3,7,1,SILVER[4]);
 post.push(Q=>{Q.set(23,4,E('#a0a8ff'));Q.set(24,4,E('#7a80ff'));Q.set(23,3,E('#c0c4ff'));Q.set(8,3,E('#7a80ff'))});return{sw:22,lights:[{x:23,y:4,c:VIOBLUE,r:16,i:.5}]}});
function lanternSprite(kind){const F=FLAMES[kind];return spr('lant'+kind,12,30,6,27,(P,post)=>{P.rect(5,4,1,24,WOOD[3]);P.rect(5,4,5,1,WOOD[2]);P.rect(9,5,1,2,'#3a3030');P.rect(8,7,3,4,'#3a3030');
 post.push(Q=>{Q.set(9,8,E(F.c[2]));Q.set(9,9,E(F.c[1]))});return{sw:5,lights:[{x:9,y:9,c:F.l,r:30,i:.8,fl:.1}]}})}
const wheelSprite=()=>spr('wheel',24,22,12,19,(P,post)=>{P.rect(4,12,16,2,WOOD[3]);P.rect(5,14,2,6,WOOD[2]);P.rect(17,14,2,6,WOOD[2]);P.ell(10,8,5,5,(x,y,dx,dy)=>Math.hypot(dx,dy)>.7?SILVER[3]:SILVER[1]);P.set(10,8,SILVER[4]);P.rect(16,9,4,3,'#5a606a');
 post.push(Q=>{Q.set(18,8,E('#a0a8ff'));Q.set(19,8,E('#c0c4ff'))});return{sw:14,lights:[{x:18,y:8,c:VIOBLUE,r:14,i:.4}]}});
const tubesSprite=()=>spr('tubes',26,14,13,11,P=>{for(let k=0;k<4;k++){const y=9-k*2-(k>1?1:0),x=2+k*2;for(let i=0;i<18-k*3;i++){P.set(x+i,y,SILVER[3]);P.set(x+i,y+1,SILVER[1])}P.set(x,y,DOMEV[4])}return{sw:18}});
const lensRackSprite=()=>spr('lensrack',22,26,11,23,(P,post)=>{P.rect(2,4,1,20,WOOD[2]);P.rect(19,4,1,20,WOOD[2]);P.rect(2,4,18,1,WOOD[3]);P.rect(2,23,18,1,WOOD[3]);
 const pts=[[6,9],[11,9],[16,9],[8,16],[14,16]];for(const[x,y]of pts)for(let k=0;k<12;k++){const a=k/12*Math.PI*2;P.set(Math.round(x+Math.cos(a)*2),Math.round(y+Math.sin(a)*2),SILVER[3])}
 post.push(Q=>{for(const[x,y]of pts){Q.set(x,y,E('#7a80ff'));Q.set(x-1,y-1,E('#c0c4ff'))}});return{sw:16,lights:[{x:11,y:12,c:VIOBLUE,r:18,i:.45}]}});

// ---------- Bibliothèque (Sigil) ----------
function libraryA(x0,z0){const W=4.4,D=2.4,x1=x0+W,z1=z0+D,b=.25,h=2.0,rh=1.1,ov=.22,mid=W/2,wall=blocks(MARBLE,.55,.25,91,{moss:.06});
 const niche=(u,v,x,y)=>{if(v<.55||v>1.55||Math.abs(u-mid)<.62||u<.2||u>W-.2)return null;const cu=(u-.2)%.52,cv=(v-.55)%.5;if(cu<.07||cv<.07||cu>.45||cv>.44)return null;
  return hash(x>>1,y>>1,4)>.35?((x+y)&1?ci('#e8e0c8'):ci('#c8bc9c')):ci('#1e1e24')};
 const mat=M(wall,(u,v,x,y)=>doorAt(u,v,x,y,mid,1.0,1.25,h,MARBLE[2],glowW,true),niche);
 return[lay(x0+mid,z1,(L,c,S,p)=>{S.shadowBox(c,x0-.2,z0-.2,x1+.2,z1+.3,h+b+rh,.85);box(L,c,x0-.25,z0-.2,x1+.25,z1+.35,0,b,blocks(MARBLE,.7,.2,92));box(L,c,x0,z0,x1,z1,b,h,mat);gable(L,c,x0,z0,x1,z1,b+h,rh,ov,tiles(SLATE,93),mat,SLATE[0]);
  const[lx,ly]=p(x0+mid,b+h-.55,z1+.05);return{post:Q=>{Q.rect(lx-1,ly,3,3,E('#e4e8f0'));Q.set(lx,ly-1,'#6a6a72')},lights:[{x:lx,y:ly+1,c:WHITEC,r:30,i:.7},...projL(c,[{x:x0+mid,y:b+.4,z:z1+.1,c:WHITEC,r:30,i:.6}])]}}),
  sprObj(x0-.5,z1+.9,lecternSprite),sprObj(x1+.5,z1+.7,jarSprite),sprObj(x1+.9,z1+1.1,jarSprite)]}
function libraryB(x0,z0){const W=3.6,D=2.4,x1=x0+W,z1=z0+D,mid=W/2,wall=s=>blocks(MARBLE,.5,.25,s,{moss:.05});
 const lv=[[x0,z0,x1,z1,0,1.5],[x0+.45,z0+.25,x1-.45,z1-.45,1.5,1.2],[x0+.9,z0+.45,x1-.9,z1-.85,2.7,1.0]];
 const slits=(w,n)=>(u,v,x,y)=>{if(v<.3||v>.8)return null;for(let k=0;k<n;k++)if(Math.abs(u-(k+.5)*w/n)<.08)return glowW(x,y);return null};
 const frieze=(u,v,x,y)=>v<.12?((Math.floor(u*CT/2)%3===0)?E('#c4c8d4'):MARBLE[2]):null;
 return[lay(x0+mid,z1,(L,c,S,p)=>{S.shadowBox(c,x0,z0,x1,z1,3.7,.85);
  box(L,c,...lv[0],M(wall(94),(u,v,x,y)=>doorAt(u,v,x,y,mid,.8,1.05,1.5,MARBLE[2],glowW,true),frieze,slits(W,4)));
  box(L,c,...lv[1],M(wall(95),frieze,slits(W-.9,3)));box(L,c,...lv[2],M(wall(96),frieze,slits(W-1.8,2)));
  const[tx,ty]=p(x0+mid,3.7,(lv[2][1]+lv[2][3])/2);L.rect(tx-2,ty-6,4,6,MARBLE[4]);L.rect(tx-2,ty-6,4,1,MARBLE[6]);
  return{post:Q=>{Q.set(tx,ty-8,E('#ffffff'));Q.set(tx-1,ty-7,E('#c4c8d4'));Q.set(tx,ty-7,E('#e4e8f0'))},lights:[{x:tx,y:ty-7,c:WHITEC,r:34,i:.7,fl:.06},...projL(c,[{x:x0+mid,y:.5,z:z1+.1,c:WHITEC,r:26,i:.6},{x:x0+mid,y:2.1,z:lv[1][3],c:WHITEC,r:22,i:.4}])]}}),
  sprObj(x1+.6,z1+.9,boardSprite),sprObj(x0-.5,z1+.8,jarSprite),sprObj(x0-.2,z1+1.4,lecternSprite)]}

// ---------- Forge (Aether) ----------
function forgeA(x0,z0){const W=3.6,D=2.2,x1=x0+W,z1=z0+D,b=.2,h=1.6,rh=1.1,ov=.25,mid=W/2,bas=blocks(BASALT,.55,.28,101,{band:[.06],bandR:SILVER});
 const mat=M(bas,(u,v,x,y)=>doorAt(u,v,x,y,mid,1.5,1.25,h,rp(SILVER,.55,x,y),(xx,yy)=>v>h-.35?fireV(xx,yy):((xx+yy)&1?ci('#14121c'):ci('#1c1830')),true));
 const fx0=x1+.25,fz0=z1-.9,fx1=fx0+1.1,fz1=z1+.1;const fmat=M(bas,(u,v,x,y)=>doorAt(u,v,x,y,.55,.6,.5,.9,SILVER[2],fireV,true));
 const water=(f,u,v,x,y)=>f==='top'&&u>.06&&v>.06&&u<.74&&v<.54?(hash(x,y,3)>.92?WATER[3]:rp(WATER,.45,x,y)):bas(f,u,v,x,y);
 return[lay(x0+mid,z1,(L,c,S,p)=>{S.shadowBox(c,x0,z0,x1,z1,h+b+rh,.85);box(L,c,x0-.15,z0-.15,x1+.15,z1+.2,0,b,blocks(BASALT,.7,.3,102));box(L,c,x0,z0,x1,z1,b,h,mat);
  const zm=(z0+z1)/2,ey=b+h-rh*ov/(D/2),ry=b+h+rh;gable(L,c,x0,z0,x1,z1,b+h,rh,ov,tiles(SLATE,103),mat,SLATE[0]);
  const cz0=z0+.35,cz1=z0+.75,cy0=roofY(z0-ov,ey,zm,ry,cz1);box(L,c,x0+.5,cz0,x0+.9,cz1,cy0,ry+.7-cy0,blocks(BASALT,.4,.25,104,{band:[.08],bandR:SILVER}));
  const[sx,sy]=p(x0+.7,ry+.7,(cz0+cz1)/2);return{post:Q=>{for(let k=0;k<6;k++)Q.set(sx-1+((k*7)%3),sy-2-k*2,E(k%2?'#7a80ff':'#c0c4ff'))},lights:[{x:sx,y:sy-3,c:VIOBLUE,r:20,i:.6,fl:.3},...projL(c,[{x:x0+mid,y:b+.3,z:z1+.1,c:VIOBLUE,r:44,i:.95,fl:.3}])]}}),
  lay(fx0+.5,fz1,(L,c,S,p)=>{S.shadowBox(c,fx0,fz0,fx1,fz1,1.6,.8);box(L,c,fx0,fz0,fx1,fz1,0,.9,fmat);const[dx,dy]=p((fx0+fx1)/2,.9,(fz0+fz1)/2),r=(fx1-fx0)/2*c.T;
   L.ell(dx,dy,r,r*.9,(x,y,ddx,ddy)=>ddy>.3?-1:rp(BASALT,.6-ddx*.3-ddy*.3,x,y));L.rect(dx-1,dy-r*.9-1,3,2,SILVER[3]);return{lights:projL(c,[{x:fx0+.55,y:.3,z:fz1,c:VIOBLUE,r:30,i:.8,fl:.35}])}}),
  boxObj(x0-1.0,z1-.3,x0-.2,z1+.3,.35,water),sprObj(x0+mid+.2,z1+1.0,anvilSprite)]}
function forgeB(x0,z0){const W=4.4,x1=x0+W,z1=z0+2.2,bas=blocks(BASALT,.5,.28,111,{band:[.06],bandR:SILVER}),tx0=x0+.2,tx1=x0+1.8,tz0=z0,tz1=z0+1.4,th=2.8;
 const crescent=(u,v,x,y)=>{const a=Math.hypot(u-.8,v-.8),bq=Math.hypot(u-.95,v-.72);if(a<.38&&bq>.3)return a>.33?SILVER[2]:SILVER[4];if(Math.abs(u-.8)<.06&&v>1.5&&v<2.3)return glowV(x,y);return null};
 const wood=logs(WOOD,.22,113),sx0=x0+2.0,sz0=z0+.3,sz1=z0+1.6;const water=(f,u,v,x,y)=>f==='top'&&u>.06&&v>.06&&u<1.6&&v<.54?rp(WATER,.45+(hash(x,y,3)>.9?.4:0),x,y):bas(f,u,v,x,y);
 const mould=(f,u,v,x,y)=>{if(f==='top'){const cu=u%.4,cv=v%.3;if(cu>.08&&cu<.32&&cv>.07&&cv<.23)return fireV(x,y)}return bas(f,u,v,x,y)};
 return[lay(tx0+.8,tz1,(L,c,S,p)=>{S.shadowBox(c,tx0,tz0,tx1,tz1,th+.8,.85);box(L,c,tx0,tz0,tx1,tz1,0,th,M(bas,crescent));gable(L,c,tx0,tz0,tx1,tz1,th,.8,.15,tiles(SLATE,112),bas,SLATE[0]);
  const[ax,ay]=p(tx0+.8,1.0,tz1),[bx,by]=p(tx0+.8,.25,z1-.2);return{post:Q=>{for(let y=ay;y<=by;y++){Q.set(ax,y,fireV(ax,y));if(y%3===0)Q.set(ax+1,y,E('#c0c4ff'))}},
   lights:[{x:ax,y:(ay+by)/2,c:VIOBLUE,r:34,i:.8,fl:.3},...projL(c,[{x:tx0+.8,y:2.0,z:tz1,c:VIOBLUE,r:20,i:.5}])]}}),
  lay(sx0+1.2,sz1,(L,c,S)=>{S.shadowBox(c,sx0,sz0,x1,sz1,2.0,.85);box(L,c,sx0,sz0,x1,sz1,0,1.2,M(wood,(u,v,x,y)=>doorAt(u,v,x,y,1.2,.7,1.0,1.2,WOOD[0],WOOD[1])));gable(L,c,sx0,sz0,x1,sz1,1.2,.8,.2,tiles(SLATE,114),wood,SLATE[0])}),
  boxObj(x0+.3,z1-.5,x0+2.3,z1+.1,.25,mould,{lights:[{x:x0+1.3,y:.3,z:z1,c:VIOBLUE,r:30,i:.6,fl:.2}]}),boxObj(x0+2.6,z1-.4,x1,z1+.2,.3,water),sprObj(x1+.4,z1+.9,anvilSprite)]}

// ---------- Atelier (Aether) ----------
function workshopA(x0,z0){const W=4.2,D=2.4,x1=x0+W,z1=z0+D,h=1.8,rh=1.1,mid=W/2,bas=blocks(BASALT,.5,.28,121),wood=logs(WOOD,.22,122);
 const wall=(f,u,v,x,y)=>v>1.05?bas(f,u,v,x,y):wood(f,u,v,x,y);
 const inner=(x,y)=>{const a=((x>>2)+(y>>2))&1;return hash(x>>1,y>>1,6)>.82?E('#7a80ff'):a?ci('#14121c'):ci('#1c1830')};
 const mat=M(wall,(u,v,x,y)=>winAt(u,v,x,y,1.3,1.0,1.6,.75,SILVER[2],inner),(u,v,x,y)=>doorAt(u,v,x,y,3.15,.75,1.15,h,SILVER[1],WOOD[1]));
 return[lay(x0+mid,z1,(L,c,S,p)=>{S.shadowBox(c,x0,z0,x1,z1,h+rh,.85);box(L,c,x0,z0,x1,z1,0,h,mat);gable(L,c,x0,z0,x1,z1,h,rh,.25,tiles(SLATE,123),wall,SLATE[0]);
  const[sx,sy]=p(x0+3.8,h-.5,z1+.2);L.rect(sx,sy-4,1,3,WOOD[1]);return{post:Q=>{for(let k=0;k<14;k++){const a=k/14*Math.PI*2;Q.set(Math.round(sx+Math.cos(a)*2.5),Math.round(sy+1+Math.sin(a)*2.5),SILVER[3])}Q.set(sx,sy+1,E('#a0a8ff'))},
   lights:projL(c,[{x:x0+1.3,y:.9,z:z1+.05,c:VIOBLUE,r:30,i:.65}])}}),sprObj(x0-.2,z1+1.0,benchSprite),sprObj(x1+.5,z1+.9,telescopeSprite),sprObj(x0+mid+.3,z1+1.4,()=>lanternSprite('vb'),{shadow:0})]}
function workshopB(x0,z0){const W=4.2,D=2.6,x1=x0+W,z1=z0+D,h=1.5,rh=1.2,mid=W/2,bas=blocks(BASALT,.5,.28,131,{band:[.06],bandR:SILVER});
 const glass=(f,u,v,x,y)=>{const cu=u%.45,cv=v%.38;if(cu<.06||cv<.06)return SILVER[f==='roofN'?1:2];const k=Math.floor(u/.45)*7+Math.floor(v/.38);if(hash(k,1,7)>.72)return glowV(x,y);return rp(DOMEV,.45+(cu+cv)*.4,x,y)};
 const mat=M(bas,(u,v,x,y)=>doorAt(u,v,x,y,mid,.8,1.1,h,SILVER[2],glowV,true),(u,v,x,y)=>winAt(u,v,x,y,.8,.7,.5,.5,SILVER[2],glowV,true),(u,v,x,y)=>winAt(u,v,x,y,W-.8,.7,.5,.5,SILVER[2],glowV,true));
 return[lay(x0+mid,z1,(L,c,S)=>{S.shadowBox(c,x0,z0,x1,z1,h+rh,.85);box(L,c,x0,z0,x1,z1,0,h,mat);gable(L,c,x0,z0,x1,z1,h,rh,.2,glass,bas,SILVER[1]);
  return{lights:projL(c,[{x:x0+mid,y:h+.6,z:(z0+z1)/2,c:VIOBLUE,r:46,i:.7,fl:.05},{x:x0+mid,y:.5,z:z1+.1,c:VIOBLUE,r:26,i:.5}])}}),
  sprObj(x0-.3,z1+1.0,wheelSprite),sprObj(x1+.5,z1+.8,lensRackSprite),sprObj(x0+mid+1.3,z1+.9,tubesSprite)]}

// ---------- Chambre à coucher (Medeina) ----------
function bedroomA(x0,z0){const W=3.0,D=2.2,x1=x0+W,z1=z0+D,h=1.85,rh=1.3,mid=W/2;
 const weave=(f,u,v,x,y)=>{if(f==='top')return rp(BARK,.5,x,y);const a=Math.floor((u+v)*CT/3),b2=Math.floor((u-v)*CT/3);return rp(((a+b2)&1)?WOOD:BARK,(FB[f]??.7)*.85+(((a+b2)&1)?.05:-.1),x,y)};
 const th=thatch(THATCH,141,.45),roof=(f,u,v,x,y)=>{const hh=hash(x,y,17);if(hh>.982)return hh>.991?ci('#e8a0c0'):ci('#fff4d8');return th(f,u,v,x,y)};
 const mat=M(weave,(u,v,x,y)=>doorAt(u,v,x,y,mid,.8,1.0,h,BARK[1],glowG,true),(u,v,x,y)=>winAt(u,v,x,y,.55,1.0,.36,.36,BARK[1],glowG,true),(u,v,x,y)=>winAt(u,v,x,y,W-.55,1.0,.36,.36,BARK[1],glowG,true));
 return[lay(x0+mid,z1,(L,c,S)=>{S.shadowBox(c,x0,z0,x1,z1,h+rh,.85);box(L,c,x0-.1,z0-.1,x1+.1,z1+.1,0,.15,blocks(STONE,.5,.15,142,{moss:.5}));box(L,c,x0,z0,x1,z1,.15,h,mat);gable(L,c,x0,z0,x1,z1,h+.15,rh,.3,roof,mat,THATCH[0]);
  return{lights:projL(c,[{x:x0+mid,y:.4,z:z1+.1,c:GREEN,r:34,i:.75,fl:.1}])}}),
  lay(x1+1.1,z1+.6,(L,c,S,p)=>{const[ax,ay]=p(x1+.4,1.1,z1+.6),[bx,by]=p(x1+1.8,1.1,z1+.6),[gx,gy]=p(x1+.4,0,z1+.6),[hx,hy]=p(x1+1.8,0,z1+.6);L.rect(ax,ay,1,gy-ay+1,WOOD[2]);L.rect(bx,by,1,hy-by+1,WOOD[2]);
   for(let k=0;k<=bx-ax;k++){const t=k/(bx-ax),sag=Math.round(Math.sin(t*Math.PI)*6);L.set(ax+k,ay+2+sag,'#6a8a3a');L.set(ax+k,ay+3+sag,'#4c6a2a');if(k%3===0)L.set(ax+k,ay+1+sag,'#8a6a3a')}
   return{post:Q=>{Q.set(ax,ay-1,E('#7ae070'));Q.set(bx,by-1,E('#7ae070'))},lights:[{x:ax,y:ay,c:GREEN,r:18,i:.5},{x:bx,y:by,c:GREEN,r:18,i:.5}]}}),
  sprObj(x0-.4,z1+.6,()=>flowerSprite(3),{shadow:0}),sprObj(x0+.6,z1+1.1,mushSprite,{shadow:0}),sprObj(x0-.6,z0+.6,()=>lanternSprite('green'),{shadow:0})]}
function bedroomB(x0,z0){const W=3.0,D=1.8,x1=x0+W,z1=z0+D,h=1.1,rh=.8,mid=W/2,roots=vlogs(BARK,.16,151),turf=thatch(THATCH,152,.25);
 const mat=M(roots,(u,v,x,y)=>doorAt(u,v,x,y,mid,.7,.95,h,BARK[0],glowG,true),(u,v,x,y)=>winAt(u,v,x,y,.55,.5,.3,.3,BARK[0],glowG,true),(u,v,x,y)=>winAt(u,v,x,y,W-.55,.5,.3,.3,BARK[0],glowG,true));
 return[sprObj(x0+mid+.2,z0-.1,()=>treeSprite(7,2.1,1),{shadow:1.4}),
  lay(x0+mid,z1,(L,c,S,p)=>{S.shadowBox(c,x0,z0,x1,z1,h+rh,.85);box(L,c,x0,z0,x1,z1,0,h,mat);gable(L,c,x0,z0,x1,z1,h,rh,.25,turf,roots,MOSS[1]);
   const[tx,ty]=p(x0+mid,h+rh,(z0+z1)/2);for(const s of[-1,1]){let x=tx,y=ty;for(let k=0;k<18;k++){x+=s*(1+(k%3===0));y+=k<6?0:1;L.set(x,y,BARK[2]);L.set(x,y+1,BARK[1])}}
   return{post:Q=>{for(const s of[-1,1]){const[lx,ly]=p(s<0?x0-.1:x1+.1,h-.1,z1+.2);Q.set(lx,ly,ci('#3a2a1a'));Q.set(lx,ly+1,E('#7ae070'));Q.set(lx,ly+2,E('#3fa83a'))}},
    lights:[...projL(c,[{x:x0+mid,y:.4,z:z1+.1,c:GREEN,r:32,i:.75,fl:.1},{x:x0-.1,y:h-.2,z:z1+.2,c:GREEN,r:16,i:.45},{x:x1+.1,y:h-.2,z:z1+.2,c:GREEN,r:16,i:.45}])]}}),
  sprObj(x1+.5,z1+.5,mushSprite,{shadow:0}),sprObj(x0-.5,z1+.8,()=>flowerSprite(4),{shadow:0})]}

// ---------- Puits des Âmes (Medeina) ----------
function soulwellA(x0,z0){const cx=x0+1.5,cz=z0+1.5,R=.95;
 return[lay(cx,cz+R,(L,c,S,p)=>{S.shadowEll(...p(cx+.3,0,cz+.2),R*c.T+4,R*c.T+2,.8);const T=c.T,[gx,gy]=p(cx,0,cz),[tx,ty]=p(cx,.6,cz),r=R*T;
   for(const s of[-1,1]){const[px,py]=p(cx+s*1.25,2.1,cz-.05),[,qy]=p(cx+s*1.25,0,cz-.05);L.rect(px-1,py,2,qy-py+1,WOOD[2]);L.rect(px-1,py,1,qy-py+1,WOOD[3])}
   L.ell(gx,gy,r,r,(x,y)=>rp(STONE,.35,x,y));for(let y=ty;y<=gy;y++)for(let x=Math.round(gx-r);x<=Math.round(gx+r);x++){const dx=(x-gx)/r;if(Math.abs(dx)<=1)L.set(x,y,rp(STONE,.6-dx*.3+((Math.floor((y-ty)/3)+(x>>2))&1?.06:-.06),x,y))}
   L.ell(tx,ty,r,r,(x,y,dx,dy)=>Math.hypot(dx,dy)>.78?rp(STONE,.82-dx*.2-dy*.2,x,y):(hash(x,y,7)>.85?E('#e8ffe0'):glowG(x,y)));
   const[ax,ay]=p(cx-1.35,2.15,cz-.05),[bx]=p(cx+1.35,2.15,cz-.05);L.rect(ax,ay,bx-ax+1,2,WOOD[3]);L.rect(ax,ay,bx-ax+1,1,WOOD[4]);
   L.line(tx-2,ay-1,tx-5,ay-6,'#e2d8bc');L.line(tx+2,ay-1,tx+5,ay-6,'#e2d8bc');L.line(tx-4,ay-4,tx-7,ay-5,'#e2d8bc');L.line(tx+4,ay-4,tx+7,ay-5,'#e2d8bc');L.rect(tx+5,ay+2,1,8,'#8a7a5a');
   return{post:Q=>{Q.rect(tx+4,ay+10,3,3,E('#7ae070'));Q.set(tx+5,ay+11,E('#e8ffe0'));Q.set(tx-6,ay+3,E('#7ae070'))},lights:[{x:tx,y:ty,c:GREEN,r:46,i:.95,fl:.12},{x:tx+5,y:ay+11,c:GREEN,r:20,i:.5}]}}),
  sprObj(x0-.2,z0+2.9,cairnSprite),sprObj(x0+3.1,z0+2.8,mushSprite,{shadow:0}),sprObj(x0+2.6,z0+3.2,()=>flowerSprite(5),{shadow:0})]}
function soulwellB(x0,z0){const cx=x0+1.6,cz=z0+1.7,R=1.15;
 return[sprObj(cx+.3,z0-.2,()=>treeSprite(8,1.5,1),{shadow:1.2}),
  lay(cx,cz+R,(L,c,S,p)=>{const T=c.T,[gx,gy]=p(cx,0,cz),r=R*T;L.ell(gx,gy,r+3,r+3,(x,y,dx,dy)=>Math.hypot(dx,dy)>.88?rp(STONE,.7-dx*.2-dy*.2+(hash(x>>1,y>>1,3)-.5)*.2,x,y):(hash(x,y,7)>.9?E('#e8ffe0'):glowG(x,y)));
   for(let k=0;k<7;k++){const a=k*.9,d=(.15+k*.11)*T;L.ell(gx+Math.cos(a)*d,gy+Math.sin(a)*d,2.2,1.6,(x,y,dx,dy)=>rp(STONE,.6-dx*.2-dy*.3,x,y))}
   return{post:Q=>{const R2=rng(3);for(let k=0;k<10;k++){const x=Math.round(gx+(R2()-.5)*r*1.6),y=Math.round(gy-4-R2()*14);Q.set(x,y,E(k%2?'#b8f0a0':'#7ae070'));if(k%3===0)Q.set(x,y-1,E('#e8ffe0'))}},
    lights:[{x:gx,y:gy,c:GREEN,r:56,i:1,fl:.12}]}}),
  menhir(x0-.4,z0+1.1,'#7ae070',GREEN),menhir(x0+3.3,z0+1.1,'#7ae070',GREEN),menhir(x0-.8,z0+3.0,'#7ae070',GREEN),menhir(x0+3.5,z0+3.0,'#7ae070',GREEN)]}

// ---------- Caserne (Indra) ----------
function caserneA(x0,z0){const W=4.6,D=1.8,x1=x0+W,z1=z0+D,h=1.5,rh=1.4,mid=W/2,vl=vlogs(WOOD,.2,161),gz=z1+.9;
 const mat=M(vl,(u,v,x,y)=>doorAt(u,v,x,y,mid,.8,1.1,h,WOOD[0],(xx,yy)=>((xx+yy)&1)?E('#5a2a0c'):E('#3a1a08')),(u,v,x,y)=>winAt(u,v,x,y,.9,.55,.4,.3,WOOD[0],fireO),(u,v,x,y)=>winAt(u,v,x,y,W-.9,.55,.4,.3,WOOD[0],fireO));
 const objs=[lay(x0+mid,z1,(L,c,S)=>{S.shadowBox(c,x0,z0,x1,z1,h+rh,.85);box(L,c,x0,z0,x1,z1,0,h,mat);gable(L,c,x0,z0,x1,z1,h,rh,.3,tiles(WOOD,162),mat,WOOD[0]);return{lights:projL(c,[{x:x0+mid,y:.5,z:z1+.1,c:ORANGE,r:30,i:.6,fl:.3}])}}),
  lay(x0+mid,gz+.2,(L,c,S,p)=>{const post=xx=>box(L,c,xx-.15,gz-.15,xx+.15,gz+.15,0,2.1,vlogs(WOOD,.15,163));post(x0+mid-.75);post(x0+mid+.75);box(L,c,x0+mid-.95,gz-.12,x0+mid+.95,gz+.12,2.1,.25,vlogs(WOOD,.15,164));
   for(const s of[-1,1]){const[a,b2]=p(x0+mid+s*.45,2.0,gz+.13);L.ell(a,b2,3,3,(x,y,dx,dy)=>dx*dx+dy*dy>.6?rp(BRONZE,.65-dx*.3,x,y):rp(ORNG,.7-dx*.3,x,y))}
   for(const s of[-1,1]){const[a,b2]=p(x0+mid+s*.75,1.9,gz+.16);for(let y=0;y<14;y++)for(let i=0;i<4;i++)L.set(a-2+i,b2+y,y>11&&((i+y)&1)?-1:i===0?ci('#ff9a48'):i===3?ci('#a8400e'):ci('#e07028'))}
   const[wx,wy]=p(x1-.3,2.1,z1+.4),[,wg]=p(x1-.3,0,z1+.4);for(const dx of[-6,6])L.rect(wx+dx,wy,1,wg-wy,WOOD[2]);L.rect(wx-8,wy-2,17,3,WOOD[3]);L.rect(wx-8,wy-2,17,1,WOOD[4]);L.rect(wx,wy-12,1,10,WOOD[1]);L.rect(wx+1,wy-12,5,3,'#ff8a2a');L.rect(wx+1,wy-11,4,1,'#e07028');
   return{lights:projL(c,[{x:x0+mid,y:1.8,z:gz+.2,c:ORANGE,r:24,i:.5}])}})];
 for(let x=x0-.4;x<=x1+.4;x+=1.0)if(Math.abs(x+.5-(x0+mid))>1.1)objs.push(sprObj(x+.5,gz,stakeSprite,{shadow:.6}));
 objs.push(sprObj(x0-.6,z1-.2,rackSprite));return objs}
function caserneB(x0,z0){const W=4.6,D=2.4,x1=x0+W,z1=z0+D,b=.4,h=2.1,rh=1.3,ov=.42,mid=W/2,base=blocks(STONE,.6,.22,171,{moss:.1});
 const panel=(f,u,v,x,y)=>{if(f==='top')return rp(WOOD,.6,x,y);const fu=u%.55;if(fu<.07||v<.08||v>h-.08||Math.abs(v-h*.45)<.04)return rp(WOOD,.25,x,y);return rp(PALE,.62+(hash(x,y,2)-.5)*.08+(f==='east'?-.15:0),x,y)};
 const mat=M(panel,(u,v,x,y)=>doorAt(u,v,x,y,mid,1.1,1.25,h,WOOD[0],(xx,yy)=>((xx>>2)&1)?ci('#2a1a10'):fireO(xx,yy)));
 return[lay(x0+mid,z1+.5,(L,c,S,p)=>{S.shadowBox(c,x0-.2,z0-.2,x1+.2,z1+.5,b+h+rh,.85);box(L,c,x0-.25,z0-.2,x1+.25,z1+.6,0,b,base);box(L,c,x0+mid-.7,z1+.6,x0+mid+.7,z1+.9,0,.2,base);box(L,c,x0,z0,x1,z1,b,h,mat);
   for(let k=0;k<5;k++){const px=x0+.1+k*(W-.2)/4;box(L,c,px-.1,z1+.35,px+.1,z1+.55,b,h,vlogs(WOOD,.1,172))}
   gable(L,c,x0,z0,x1,z1,b+h,rh,ov,tiles(WOOD,173),panel,ORNG[2]);
   const ey=b+h-rh*ov/(D/2);for(let k=0;k<4;k++){const u0=x0+.2+k*(W-.2)/4,[a,b2]=p(u0,ey,z1+ov),[a2]=p(u0+(W-.2)/4-.2,ey,z1+ov);for(let x=a;x<=a2;x++)for(let y=1;y<7;y++)if(!(y>5&&(x-a)%3===0))L.set(x,b2+y,y===1?ci('#a8400e'):(x-a)%5===0?ci('#ffc890'):ci('#e07028'))}
   return{lights:projL(c,[{x:x0+mid,y:b+.4,z:z1+.2,c:ORANGE,r:38,i:.75,fl:.3}])}}),
  sprObj(x0-.6,z1+.9,dummySprite),sprObj(x1+.7,z1+.6,rackSprite),sprObj(x0+mid+1.6,z1+1.1,drumSprite)]}

const SECONDARY={
 library:{name:'Bibliothèque',cult:'sigil',size:3,items:[
  {name:'Galerie des rouleaux',f:libraryA,W:4.4,desc:'Longue salle de marbre veiné sur un soubassement : la façade entière est un casier de niches où sont rangés les rouleaux. Porte en arc éclairée de blanc, lanterne au fronton, lutrin et jarres à rouleaux devant.'},
  {name:'Tour des archives',f:libraryB,W:3.6,desc:'Trois étages de marbre en retrait, chacun percé de fentes lumineuses et ceint d’une frise de glyphes. Une flamme blanche veille au sommet. Devant : tableau de calculs, jarre et lutrin.'}]},
 forge:{name:'Forge',cult:'aether',size:3,items:[
  {name:'Forge stellaire',f:forgeA,W:4.7,desc:'Halle de basalte ouverte par une grande arche sur un foyer bleu-violet, cheminée d’où s’échappent des étincelles. À côté, un four à dôme. Devant : enclume et bac de trempe.'},
  {name:'Fonderie lunaire',f:forgeB,W:4.4,desc:'Tour-fourneau ornée d’un croissant d’argent ; une coulée de métal stellaire descend vers les moules au sol. Appentis de bois, bac de trempe et enclume.'}]},
 workshop:{name:'Atelier',cult:'aether',size:3,items:[
  {name:'Atelier des instruments',f:workshopA,W:4.2,desc:'Soubassement de basalte, étage de bois, grande verrière où brillent des lentilles. Enseigne circulaire d’argent. Devant : établi aux engrenages, lunette et lanterne.'},
  {name:'Atelier des lentilles',f:workshopB,W:4.2,desc:'Murs de basalte et toit entièrement vitré : la lumière bleu-violet des fours filtre à travers les carreaux la nuit. Devant : meule de polissage, râtelier de lentilles, tubes de lunettes.'}]},
 bedroom:{name:'Chambre à coucher',cult:'medeina',size:2,items:[
  {name:'Hutte-cocon',f:bedroomA,W:3.0,desc:'Hutte de branches tressées sur un socle moussu, chaume fleuri, porte et hublots verts. Un hamac entre deux poteaux à lanternes, fleurs et champignons.'},
  {name:'Dortoir des racines',f:bedroomB,W:3.0,desc:'Logis semi-enterré sous un arbre en fleurs : murs de racines, toit de gazon, racines qui retombent sur les flancs, gousses lumineuses.'}]},
 soulwell:{name:'Puits des Âmes',cult:'medeina',size:2,items:[
  {name:'Puits du cycle',f:soulwellA,W:3.0,desc:'Margelle de pierre sur une eau verte lumineuse, portique de bois coiffé de bois de cerf, lanterne suspendue. Un cairn d’os bourgeonne à côté.'},
  {name:'Source des âmes',f:soulwellB,W:3.2,desc:'Bassin circulaire où une spirale de pierres mène au centre ; des âmes en lueurs vertes s’élèvent de l’eau. Quatre pierres levées et un arbre en fleurs l’entourent.'}]},
 caserne:{name:'Caserne',cult:'indra',size:3,items:[
  {name:'Caserne palissadée',f:caserneA,W:4.6,desc:'Longue maison de rondins derrière une palissade. Porte charpentée avec boucliers et tentures orange, tour de guet à fanion, râtelier d’armes.'},
  {name:'Dojo de discipline',f:caserneB,W:4.6,desc:'Salle sur soubassement de pierre, murs à colombages, véranda à poteaux et larges avant-toits bordés de tentures orange. Cour avec mannequin, râtelier et tambour.'}]}};
function secondaryVignette(id,i,S=SCALES.inter){const d=SECONDARY[id],pr=d.items[i],ctx=proj34(20,0,92),sc=new Scene(256,200),cx=6.4,z0=1.4,x0=cx-pr.W/2,path=[[cx,12],[cx,z0+2]];
 const ground=jungleGround({cx,cz:3.4,rx:5.8,rz:3.5,path});const objs=[...pr.f(x0,z0)];
 const fl={sigil:['white','marble'],aether:['vb','basalt'],medeina:['green','pole'],indra:['orange','pole']}[d.cult];
 objs.push(sprAt(1.0,4.2,()=>torchSprite(...fl),{shadow:0}),sprAt(11.8,4.2,()=>torchSprite(...fl),{shadow:0}),sprAt(2.0,5.0,()=>deityMakers[d.cult+'.a'](S)));
 forest(objs,[-3,-5,16,13],(x,z)=>((x-cx)/5.9)**2+((z-3.4)/3.7)**2<1.1||segDist(x,z,path)<.9||(x>x0-1.4&&x<x0+pr.W+1.4&&z>z0-3.2&&z<z0+1.2),200+id.length*7+i);return sc.bake(ctx,ground,objs)}

const PALETTES=[
 {name:'Exilés',rule:'Acier, kaki, treillis. Lueur cyan tyrienne : la technologie des Exilés est la seule source cyan du jeu.',c:['#2f343b','#4a515a','#8b939d','#4b5245','#5c623f','#d6a37f','#2fb8d8','#5ce8ff']},
 {name:'Cultes : socle commun',rule:'Terre, bois, pierre et tissus naturels. Chaque culte y ajoute la couleur de son portail : vert pour Medeina, orange pour Indra, blanc pour Sigil, bleu-violet pour Aether. Jamais d’or, de rouge ni de cyan.',c:['#5c3e26','#74502f','#55626f','#7ae070','#ff8a2a','#f4f6ff','#7a80ff','#e2d8bc']},
 {name:'Jungle et ruines tyriennes',rule:'Verts profonds et saturés de Core Keeper. La pierre tyrienne est une ardoise bleutée, et ses glyphes reprennent le cyan des Exilés.',c:['#173a20','#2a652e','#4b923c','#8cc45c','#6a4a2a','#313a47','#55626f','#86929e']},
 {name:'Ancre',rule:'Noir profond, reflets et halo pourpres, éclairs noirs ourlés de pourpre. Le pourpre (violet tirant vers le rouge) lui est réservé et se distingue du bleu-violet d’Aether.',c:['#040306','#0e0814','#170c20','#3e1050','#6a2088','#9a3ab8','#c060e0','#f4d8ff']},
 {name:'Ennemis : la Bête',rule:'Le rouge carmin marque la corruption de la Bête.',c:['#1a0e10','#3c1c22','#9c1c2a','#c01828','#ff3346']},
 {name:'Ennemis : Laetan',rule:'L’or est réservé au Credo Divin et aux forces de Laetan : ivoire, or et lumière dorée. Aucun allié ne porte d’or.',c:['#5a4318','#a88228','#c8a040','#e2c266','#f4dc94','#e8dfc6']},
 {name:'Nuit',rule:'Ambiance bleu nuit claire : le décor reste lisible, et les lumières dessinent les zones d’intérêt.',c:['#0b120e','#2a3350','#3a4468','#56608a']}];

return{SECONDARY,secondaryVignette,templeSprite,anchorPlate,SCALES,DEITIES,PALETTES,perspective,scalePlate,exilesPlate,deityPair,deityLineup,templeVignette,enemyPlate,ambient}})();
