// Bibliothèque de décor pixel art « Jungle sacrée » (extraite de decor-pixel-jungle.html).
'use strict';
const BAYER=[[0,8,2,10],[12,4,14,6],[3,11,1,9],[15,7,13,5]].map(r=>r.map(v=>(v+.5)/16));
const C={
 bg:'#0b120e',outline:'#08100b',
 grass:['#122619','#173020','#1d3b25','#24472b','#2d5532','#38653a','#4a7a44','#629352'],
 blade:['#2f5c34','#477a40','#6a9a50','#8db464'],
 dirt:['#2e2619','#3e3322','#51432c','#665538','#7c6a47','#93805a'],
 pebble:['#4c4a40','#6c695a','#8f8b76','#b3ad94'],
 stone:['#2c2c27','#3d3d35','#525046','#6a6858','#85826d','#a29e85','#c0bba0','#dad4b8'],
 moss:['#1e3a22','#2c5230','#41703c','#5c8c48'],
 leaf:['#0a1d12','#0f2a18','#163a20','#1f4c28','#2b6131','#3b783b','#529248','#71ac58','#94c66a'],
 cyp:['#0b1d14','#11291b','#193a24','#224c2e','#2f613a','#427a48'],
 palm:['#14301c','#1e4426','#2b5c30','#3e763c','#5a924a'],
 bark:['#1e150e','#2c2016','#3c2c1e','#4f3b28','#644c34'],
 cloth:['#2e080d','#4c1018','#6e1a24','#922a30','#b23c3c'],
 gold:['#5a4320','#8a6a30','#c09a48','#e8c870'],
 orb:['#040306','#08050c','#0e0814','#170c20','#6a2088','#c060e0'], // Ancre : noir, reflets pourpres
 ancreGlow:['#3e1050','#9a3ab8'],
 glow:['#6a52c0','#9a80f0'],flower:['#d8c26a','#e4e0c8','#c8607a'],
};
function rng(seed){return()=>{seed=(1664525*seed+1013904223)>>>0;return seed/4294967296}}
function hash(x,y,s){let h=(x*374761393+y*668265263+s*1442695041)|0;h=(h^(h>>>13))*1274126177|0;return((h^(h>>>16))>>>0)/4294967296}
function vnoise(x,y,s){const xi=Math.floor(x),yi=Math.floor(y),xf=x-xi,yf=y-yi,u=xf*xf*(3-2*xf),v=yf*yf*(3-2*yf);
 const a=hash(xi,yi,s),b=hash(xi+1,yi,s),c=hash(xi,yi+1,s),d=hash(xi+1,yi+1,s);return a+(b-a)*u+(c-a)*v+(a-b-c+d)*u*v}
function fbm(x,y,s){return vnoise(x,y,s)*.6+vnoise(x*2.1,y*2.1,s+7)*.28+vnoise(x*4.3,y*4.3,s+13)*.12}
const hexC={};const hex=c=>hexC[c]||(hexC[c]=[1,3,5].map(i=>parseInt(c.substr(i,2),16)));
function inside(p,x,y){let r=false;for(let i=0,j=p.length-1;i<p.length;j=i++){const[xi,yi]=p[i],[xj,yj]=p[j];if((yi>y)!==(yj>y)&&x<(xj-xi)*(y-yi)/(yj-yi)+xi)r=!r}return r}

class Px{
 constructor(w,h,transparent=false){this.w=w;this.h=h;this.c=document.createElement('canvas');this.c.width=w;this.c.height=h;this.g=this.c.getContext('2d',{willReadFrequently:true});this.d=this.g.createImageData(w,h);this.z=new Float32Array(w*h).fill(-1e9);if(!transparent){const b=hex(C.bg);new Uint32Array(this.d.data.buffer).fill(((255<<24)|(b[2]<<16)|(b[1]<<8)|b[0])>>>0)}}
 set(x,y,col,z=0){x=Math.round(x);y=Math.round(y);if(x<0||y<0||x>=this.w||y>=this.h)return;const i=y*this.w+x;if(z<this.z[i])return;this.z[i]=z;const h=hex(col),d=this.d.data,o=i*4;d[o]=h[0];d[o+1]=h[1];d[o+2]=h[2];d[o+3]=255}
 dark(x,y,k,z){x=Math.round(x);y=Math.round(y);if(x<0||y<0||x>=this.w||y>=this.h)return;const i=y*this.w+x;if(z<this.z[i])return;const o=i*4;for(let c=0;c<3;c++)this.d.data[o+c]*=k}
 ramp(r,v,x,y){x=Math.floor(x);y=Math.floor(y);v=Math.max(0,Math.min(.999,v))*(r.length-1);let i=Math.floor(v);if(v-i>BAYER[((y%4)+4)%4][((x%4)+4)%4])i++;return r[Math.min(i,r.length-1)]}
 poly(pts,fn,z){let x0=1e9,x1=-1e9,y0=1e9,y1=-1e9;for(const[x,y]of pts){x0=Math.min(x0,x);x1=Math.max(x1,x);y0=Math.min(y0,y);y1=Math.max(y1,y)}
  for(let y=Math.floor(y0);y<=y1;y++)for(let x=Math.floor(x0);x<=x1;x++)if(inside(pts,x+.5,y+.5))this.set(x,y,fn(x,y),z)}
 line(x0,y0,x1,y1,col,z){const n=Math.max(1,Math.ceil(Math.max(Math.abs(x1-x0),Math.abs(y1-y0))));for(let t=0;t<=n;t++)this.set(x0+(x1-x0)*t/n,y0+(y1-y0)*t/n,typeof col==='function'?col(t/n):col,z)}
 flush(){this.g.putImageData(this.d,0,0)}
}

/* ================= SOL ================= */
const TW=64,TH=32;
function diamond(cx,ty,fn){for(let r=0;r<TH;r++){const hw=r<TH/2?(r+1)*2:(TH-r)*2;for(let x=cx-hw;x<cx+hw;x++)fn(x,ty+r,r,x-cx)}}
function grassTile(P,cx,ty,R,z,seed){
 diamond(cx,ty,(x,y,r,dx)=>{let v=.18+fbm(x/14,y/9,1)*.62;P.set(x,y,P.ramp(C.grass,v,x,y),z)});
 // brins d'herbe : petites touffes verticales avec pointe claire
 for(let k=0;k<70;k++){const x=cx+(R()-.5)*TW*.9|0,y=ty+4+R()*(TH-8)|0,rr=y-ty,hw=rr<TH/2?(rr+1)*2:(TH-rr)*2;if(Math.abs(x-cx)>hw-3)continue;
  const h=2+R()*3|0,lean=R()<.5?-1:1;for(let i=0;i<h;i++)P.set(x+(i>1?lean:0),y-i,C.blade[Math.min(3,i+(R()<.3))],z+.01)}
 if(R()<.6)for(let k=0;k<3+R()*4;k++){const x=cx+(R()-.5)*40|0,y=ty+8+R()*16|0;const f=C.flower[R()*3|0];P.set(x,y,f,z+.02);if(R()<.5){P.set(x+1,y,f,z+.02);P.set(x,y+1,C.blade[0],z+.015)}}
 if(R()<.35){const x=cx+(R()-.5)*30|0,y=ty+12+R()*8|0;pebble(P,x,y,2+R()*2|0,z+.02)}
}
function pebble(P,x,y,r,z){for(let j=-r;j<=r;j++)for(let i=-r*1.5;i<=r*1.5;i++){const d=(i/(r*1.5))**2+(j/r)**2;if(d>1)continue;const v=.7-(i*.25+j*.6)/r*.35-d*.2;P.set(x+i,y+j,P.ramp(C.pebble,v,x+i,y+j),z)}
 for(let i=-r*1.5;i<=r*1.5;i++)P.dark(x+i,y+r+1,.6,z-1)}
function pathTile(P,cx,ty,R,z,seed){
 diamond(cx,ty,(x,y)=>{let v=.2+fbm(x/10,y/7,2)*.55;P.set(x,y,P.ramp(C.dirt,v,x,y),z)});
 for(let k=0;k<9;k++){const x=cx+(R()-.5)*44|0,y=ty+7+R()*18|0;const rr=y-ty,hw=rr<TH/2?(rr+1)*2:(TH-rr)*2;if(Math.abs(x-cx)<hw-6)pebble(P,x,y,1+R()*3|0,z+.01)}
 for(let k=0;k<14;k++){const x=cx+(R()-.5)*50|0,y=ty+4+R()*24|0;const rr=y-ty,hw=rr<TH/2?(rr+1)*2:(TH-rr)*2;if(Math.abs(x-cx)<hw-2)P.set(x,y,C.dirt[5],z+.01)}
}
// ombre portée tramée au sol
function shadow(P,x,y,rx,ry,z){x=Math.round(x);y=Math.round(y);rx=Math.round(rx);ry=Math.max(1,Math.round(ry));for(let j=-ry;j<=ry;j++)for(let i=-rx;i<=rx;i++){const d=(i/rx)**2+(j/ry)**2;if(d<1&&BAYER[((y+j)%4+4)%4][((x+i)%4+4)%4]<.85-d*.6)P.dark(x+i,y+j,.62,z)}}

/* ================= VÉGÉTATION ================= */
// feuillage : nombreuses grappes de feuilles, chacune ombrée, assombries vers le bas/arrière
function canopy(P,cx,cy,rx,ry,R,z,ramp=C.leaf,n=26){
 const cl=[];for(let k=0;k<n;k++){const a=R()*Math.PI*2,d=Math.sqrt(R());cl.push([cx+Math.cos(a)*rx*d,cy+Math.sin(a)*ry*d,3.2+R()*3.6])}
 cl.sort((a,b)=>a[1]-b[1]);
 const mask=new Map();
 for(const[x,y,r]of cl){for(let j=-r-1;j<=r+1;j++)for(let i=-r-1;i<=r+1;i++){const d=Math.hypot(i,j*1.1);if(d>r)continue;const px=Math.round(x+i),py=Math.round(y+j);
  const g=((py-cy)/ry)*.35+((px-cx)/rx)*.12; // éclairage global haut-gauche
  const l=-(i*.55+j*.8)/r*.42;                  // relief de la grappe
  let v=.55+l-g-(d/r)*.12;
  P.set(px,py,P.ramp(ramp,v,px,py),z+(y-cy)*.001);mask.set(px+','+py,1)}}
 // contour sombre
 for(const k of mask.keys()){const[x,y]=k.split(',').map(Number);for(const[dx,dy]of[[1,0],[-1,0],[0,1],[0,-1]])if(!mask.has((x+dx)+','+(y+dy)))P.set(x+dx,y+dy,C.outline,z-.01)}
 // reflets : quelques feuilles très claires en haut
 for(let k=0;k<n*.6;k++){const a=R()*Math.PI*2,d=Math.sqrt(R());const x=Math.round(cx+Math.cos(a)*rx*d*.8-rx*.15),y=Math.round(cy+Math.sin(a)*ry*d*.6-ry*.3);if(mask.has(x+','+y)){P.set(x,y,ramp[ramp.length-1],z+.05);if(R()<.5)P.set(x+1,y,ramp[ramp.length-2],z+.05)}}
}
function trunkDraw(P,x,yb,h,w,R,z,roots=true){
 for(let y=yb-h;y<=yb;y++){const t=(yb-y)/h,ww=w+(t<.15?(.15-t)*14:0);for(let i=-ww/2;i<ww/2;i++){const u=(i+ww/2)/ww;let v=.75-u*.6+(hash(x+i|0,y>>1,3)-.5)*.25;if(((i+y*.3)|0)%3===0)v-=.12;P.set(x+i,y,P.ramp(C.bark,v,x+i|0,y),z)}
  P.set(x-ww/2-1,y,C.outline,z-.01);P.set(x+ww/2,y,C.outline,z-.01)}
 if(roots)for(const s of[-1,1]){for(let i=0;i<5;i++)P.set(x+s*(w/2+1+i),yb-1+(i>>1),C.bark[1+(i<2)],z)}}
function treeBig(P,x,yb,R,z,s=1,L=P){shadow(P,x+4,yb,22*s,8*s,z-50);trunkDraw(P,x,yb,30*s,6*s,R,z);
 for(const b of[-1,1]){P.line(x,yb-22*s,x+b*12*s,yb-34*s,C.bark[2],z+.01);P.line(x,yb-21*s,x+b*12*s,yb-33*s,C.bark[1],z+.01)}
 canopy(L,x-2,yb-48*s,26*s,18*s,R,z+.1,C.leaf,34);canopy(L,x+10*s,yb-38*s,14*s,10*s,R,z+.12,C.leaf,12)}
function cypress(P,x,yb,R,z,L=P){shadow(P,x+3,yb,9,4,z-50);trunkDraw(P,x,yb,8,3,R,z,false);for(let k=0;k<5;k++)canopy(L,x,yb-12-k*9,8-k*1.1,7,R,z+.1+k*.01,C.cyp,8)}
function palm(P,x,yb,R,z,L=P){shadow(P,x+6,yb,12,4,z-50);const H=44;
 for(let i=0;i<H;i++){const xx=x+Math.round(Math.sin(i/16)*5);for(let k=-1;k<=1;k++)P.set(xx+k,yb-i,P.ramp(C.bark,(i%4===0?.25:.6)-k*.2,xx+k,yb-i),z);P.set(xx-2,yb-i,C.outline,z-.01);P.set(xx+2,yb-i,C.outline,z-.01)}
 const tx=x+Math.round(Math.sin(H/16)*5),ty=yb-H;
 for(const[a,l]of[[-2.9,22],[-2.3,24],[-1.7,20],[-1.1,18],[-.5,22],[.1,24],[.7,20],[2.6,16]]){
  for(let t=0;t<l;t++){const px=tx+Math.cos(a)*t,py=ty+Math.sin(a)*t*.55+t*t*.03;L.set(px,py,C.palm[1],z+.2);
   if(t>3&&t%2===0)for(const s of[-1,1]){const lx=px+Math.cos(a+s*1.4)*3,ly=py+Math.sin(a+s*1.4)*2+2;L.line(px,py,lx,ly,f=>P.ramp(C.palm,.85-t/l*.6-f*.3,px|0,py|0),z+.19)}}}
 L.set(tx,ty,C.bark[3],z+.3);L.set(tx+1,ty+1,C.bark[2],z+.3)}
function fern(P,x,yb,R,z){for(let k=0;k<7;k++){const a=-Math.PI/2+(k-3)*.45,l=13+R()*6;for(let t=0;t<l;t++){const px=x+Math.cos(a)*t,py=yb+Math.sin(a)*t*.9+t*t*.04;P.set(px,py,P.ramp(C.leaf,.75-t/l*.5,px|0,py|0),z);if(t%2)for(const s of[-1,1])P.set(px+s,py+1,C.leaf[3+(s>0)],z-.01)}}}
function bushDraw(P,x,yb,R,z,L=P){shadow(P,x+2,yb,12,4,z-50);canopy(L,x,yb-7,11,7,R,z,C.leaf,12)}
function rock(P,x,yb,R,z,s=1){shadow(P,x+3,yb,11*s,4,z-50);const pts=[[x-10*s,yb],[x-8*s,yb-7*s],[x-2*s,yb-11*s],[x+6*s,yb-9*s],[x+10*s,yb-3*s],[x+8*s,yb+1]];
 P.poly(pts,(px,py)=>{let v=.75-(px-x)/(10*s)*.25-(py-yb+11*s)/(12*s)*.35+(hash(px,py,9)-.5)*.15;if(fbm(px/5,py/5,4)>.62&&py<yb-5*s)return P.ramp(C.moss,v,px,py);return P.ramp(C.stone,v*.8,px,py)},z);
 for(let i=0;i<pts.length;i++){const[a,b]=[pts[i],pts[(i+1)%pts.length]];P.line(a[0],a[1],b[0],b[1],C.outline,z+.01)}}

/* ================= TEMPLE ================= */
const ISO=(sx,sy)=>(u,v)=>[sx+u-v,sy+(u+v)/2];
// bloc maçonné : briques décalées, joints, usure, fissures, mousse sur les arêtes hautes
function masonry(P,sx,sy,a,b,h,z,opt={}){const X=ISO(sx,sy),up=p=>[p[0],p[1]-h];
 const p0=X(0,0),px=X(a,0),pz=X(0,b),pxz=X(a,b);
 const face=(base,dirx)=>(x,y)=>{const yy=y-sy,row=Math.floor((yy+200)/(opt.bh||6)),off=row%2?(opt.bw||10)/2:0;
  const along=dirx?(x-sx):(sx-x);const col=Math.floor((along*1+off+400)/(opt.bw||10));
  const inRowJoint=((yy+200)%(opt.bh||6))===0, inColJoint=((Math.floor(along+off+400))%(opt.bw||10))===0;
  let v=base+(hash(row,col,5)-.5)*.16+(fbm(x/6,y/6,8)-.5)*.12;
  if(inRowJoint||inColJoint)v-=.22;
  if(opt.moss&&fbm(x/9,y/5,2)>.7)return P.ramp(C.moss,v+.15,x,y);
  return P.ramp(C.stone,v,x,y)};
 P.poly([pz,pxz,up(pxz),up(pz)],face(.42,false),z);
 P.poly([px,pxz,up(pxz),up(px)],face(.26,true),z);
 P.poly([up(p0),up(px),up(pxz),up(pz)],(x,y)=>{let v=.72+(fbm(x/7,y/4,6)-.5)*.2+((x+y*2)%11===0?-.15:0);if(opt.moss&&fbm(x/8,y/6,3)>.7)return P.ramp(C.moss,v,x,y);return P.ramp(C.stone,v,x,y)},z+.01);
 // arêtes : claire en haut, sombre en contour
 P.line(...up(pz),...up(pxz),C.stone[7],z+.02);P.line(...up(pxz),...up(px),C.stone[6],z+.02);
 for(const[e0,e1]of[[pz,pxz],[pxz,px],[up(pz),pz],[up(px),px],[up(p0),up(px)],[up(p0),up(pz)]])P.line(...e0,...e1,C.outline,z+.015);
 // occlusion au pied
 for(let t=0;t<=1;t+=.01){const[x,y]=[pz[0]+(pxz[0]-pz[0])*t,pz[1]+(pxz[1]-pz[1])*t];P.dark(x,y+1,.55,z-1);const[x2,y2]=[px[0]+(pxz[0]-px[0])*t,px[1]+(pxz[1]-px[1])*t];P.dark(x2,y2+1,.55,z-1)}
 // fissures
 if(opt.cracks)for(let k=0;k<opt.cracks;k++){let[x,y]=lerp2(pz,pxz,.2+k*.3);y-=h*.8;for(let i=0;i<h*.7;i++){x+=(hash(k,i,1)-.5)*2;y+=1;P.set(x,y,C.stone[0],z+.02)}}
 return{top:(u,v)=>{const p=X(u,v);return[p[0],p[1]-h]}}}
const lerp2=(a,b,t)=>[a[0]+(b[0]-a[0])*t,a[1]+(b[1]-a[1])*t];
// pilier cannelé : socle, fût, chapiteau ; brisé optionnel
function column(P,x,yb,H,z,broken,R){
 const r=7,X=(u)=>u;
 masonry(P,x,yb-4-8,16,16,5,z,{bh:5,bw:8});
 const sy=yb-4-8-5+8; // centre du sommet du socle
 const top=broken?H*.55:H;
 for(let y=0;y<top;y++){for(let i=-r;i<=r;i++){const n=i/r,lit=.55-n*.45;let v=lit+(Math.abs(Math.sin((i+.5)*1.1))<.25?-.18:0)+(hash(i,y>>2,2)-.5)*.08;
  if(y<top*.35&&fbm((x+i)/5,(sy-y)/6,5)>.64)P.set(x+i,sy-y,P.ramp(C.moss,v+.2,x+i,sy-y),z+.1);else P.set(x+i,sy-y,P.ramp(C.stone,v,x+i,sy-y),z+.1)}
  P.set(x-r-1,sy-y,C.outline,z+.09);P.set(x+r+1,sy-y,C.outline,z+.09)}
 if(!broken){masonry(P,x,sy-top-6,18,18,5,z+.2,{bh:5,bw:9});masonry(P,x,sy-top-12,14,14,3,z+.3,{bh:3,bw:7})}
 else{for(let i=-r;i<=r;i++){const yy=sy-top-Math.round(Math.abs(Math.sin(i*1.7))*4);for(let y=yy;y<sy-top+2;y++)P.set(x+i,y,P.ramp(C.stone,.7-i/r*.3,x+i,y),z+.15);P.set(x+i,yy-1,C.outline,z+.16)}
  rock(P,x+16,yb+4,R,z+.5,.55);rock(P,x-14,yb+6,R,z+.5,.4)}
 return sy-top}
function vine(P,x,y,len,R,z){let xx=x;for(let i=0;i<len;i++){xx+=(R()-.5)*1.2;P.set(xx,y+i,C.leaf[3],z);if(i%3===0){P.set(xx+1,y+i,C.leaf[5],z);P.set(xx-1,y+i+1,C.leaf[4],z)}}}
function bannerDraw(P,x,y,w,h,z){for(let j=0;j<h;j++)for(let i=0;i<w;i++){if(j>h-4&&Math.abs(i-w/2+.5)<(j-(h-4))*1.2)continue;const v=.75-i/w*.45-j/h*.2+(Math.sin(i*.9+j*.15)*.06);P.set(x+i,y+j,P.ramp(C.cloth,v,x+i,y+j),z)}
 for(let i=-1;i<=w;i++)P.set(x+i,y-1,C.gold[2],z+.01);
 const cx=x+(w>>1),cy=y+(h>>1)-2;for(let k=-3;k<=3;k++){P.set(cx,cy+k,C.gold[3],z+.02);P.set(cx+k,cy,C.gold[3],z+.02)}}
function orbDraw(P,x,y,z,t=0){
 for(let r=22;r>9;r--)for(let a=0;a<180;a++){const xx=Math.round(x+Math.cos(a/180*6.283)*r),yy=Math.round(y+Math.sin(a/180*6.283)*r*.42+14);if(BAYER[(yy%4+4)%4][(xx%4+4)%4]<(23-r)/14*.6)P.set(xx,yy,C.ancreGlow[r<15?1:0],z-.5)}
 // anneau runique
 for(let a=0;a<64;a++){const xx=x+Math.cos(a/64*6.283)*15,yy=y+Math.sin(a/64*6.283)*6+14;if(a%8<5)P.set(xx,yy,C.ancreGlow[1],z+.4)}
 const r=10;for(let j=-r;j<=r;j++)for(let i=-r;i<=r;i++){const d=Math.hypot(i,j);if(d>r)continue;const n=[i/r,j/r];let v=.42-(n[0]*.5+n[1]*.7)*.3+(fbm((x+i)/4,(y+j)/4,11)-.5)*.15;if(d>r-1.6&&n[0]+n[1]>-.2)v=d>r-.8?.95:.8;P.set(x+i,y+j,P.ramp(C.orb,Math.min(v,d>r-1.6?1:.7),x+i,y+j),z+.5)}
 for(let a=0;a<80;a++){const xx=x+Math.cos(a/80*6.283)*(r+1),yy=y+Math.sin(a/80*6.283)*(r+1);P.set(xx,yy,C.outline,z+.45)}
 P.set(x-4,y-5,C.orb[5],z+.6);P.set(x-3,y-5,C.orb[5],z+.6);P.set(x-4,y-4,C.orb[4],z+.6)}
function temple(P,sx,sy,R,z){
 // plateforme principale, marches en avant
 const plat=masonry(P,sx,sy,128,96,16,z,{bh:6,bw:12,moss:1,cracks:2});
 for(let s=0;s<3;s++){const[x0,y0]=plat.top(0,0);}
 const steps=[[0,96,128,10,10],[0,106,128,10,5]];
 for(const[i,[u,v,a,b,h]]of steps.entries()){const p=ISO(sx,sy)(u,v);masonry(P,p[0],p[1],a,b,h,z+5+i,{bh:5,bw:10,moss:1})}
 // piliers
 const cols=[[10,10,false],[118,10,true],[10,86,false],[118,86,false]];
 const out=[];for(const[u,v,br]of cols){const[x,y]=plat.top(u,v);out.push({d:u+v,f:()=>{const ty=column(P,x,y+8,58,z+20+(u+v)*.1,br,R);if(!br&&u<60)vine(P,x+4,ty+4,24+R()*14|0,R,z+60)}})}
 // autel et Ancre
 out.push({d:100,f:()=>{const[x,y]=plat.top(52,36);const al=masonry(P,x,y,30,30,12,z+30,{bh:4,bw:8});const[ax,ay]=al.top(15,15);orbDraw(P,ax,ay-26,z+40)}});
 // bannières sur les piliers avant
 out.push({d:300,f:()=>{const[x1,y1]=plat.top(10,86);bannerDraw(P,x1-14,y1-50,9,26,z+80);const[x2,y2]=plat.top(118,86);bannerDraw(P,x2+7,y2-50,9,26,z+80)}});
 out.sort((a,b)=>a.d-b.d).forEach(o=>o.f());
 // mousse et fougères au pied
 const[fx,fy]=ISO(sx,sy)(0,96);fern(P,fx-6,fy+4,R,z+90);const[gx,gy]=ISO(sx,sy)(128,40);fern(P,gx+6,gy+2,R,z+90);
}


/* dalle de pierre iso (sol du temple, parvis) */
function flagTile(P,cx,ty,R,z){diamond(cx,ty,(x,y,r,dx)=>{const u=(dx/2+r),v=(r-dx/2);const ju=((u%16)+16)%16<1,jv=((v%16)+16)%16<1;
 const cell=Math.floor(u/16)*7+Math.floor(v/16)*13;let w=.5+(hash(cell,0,4)-.5)*.25+(fbm(x/8,y/5,6)-.5)*.2;if(ju||jv)w-=.28;
 if(fbm(x/7,y/4,12)>.72)return P.set(x,y,P.ramp(C.moss,w+.1,x,y),z);P.set(x,y,P.ramp(C.stone,w+.12,x,y),z)})}
