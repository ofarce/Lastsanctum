/* PixelBuildings — propositions de bâtiments dessinées avec le moteur pixel du décor (decor.js).
   Même grille iso (1 tuile = 32 unités), même palette, même tramage de Bayer, même contour.
   Chaque proposition = une base statique (Px) + une couche animée dessinée pixel par pixel. */
(function(global){
'use strict';
const W=320,H=240;
const PAL={
 wood:['#1c120b','#2a1b10','#3d2918','#553a22','#6e4e2e','#8a663c','#a8834e'],
 shingle:['#160e09','#22160e','#312014','#432c1b','#583a24','#6e4a2e'],
 thatch:['#2a200e','#3e3016','#56441e','#73602a','#937c38','#b39a4a'],
 clay:['#2e120c','#4a1e14','#6a2c1c','#8a3c24','#a85030','#c46a40'],
 water:['#0b1b22','#10303a','#184650','#205e66','#367e80','#6aa8a0','#a8d4c4'],
 fire:['#3a1006','#7a2408','#b8440e','#e8741c','#f8aa34','#ffe08a','#fffbe0'],
 iron:['#15181b','#252b2f','#394147','#525c62','#717d82','#9ea8aa'],
 smoke:['#4a4c46','#62645c','#7c7e74','#9a9a8e','#bcbcae'],
 rope:['#5a4628','#7a6236','#9a8048'],
 straw:['#5a4a1c','#7e6a28','#a48c3a','#c8b058'],
};
const rp=(r,v,x,y)=>Px.prototype.ramp(r,v,x,y);
const mod=(a,n)=>((a%n)+n)%n;
const clamp=v=>Math.max(0,Math.min(1,v));
const ISOP=(sx,sy)=>(u,v,h=0)=>[sx+u-v,sy+(u+v)/2-h];
// origine iso telle que le centre de l'emprise a×b tombe sur (cx,cy)
const origin=(a,b,cx=160,cy=172)=>[cx-(a-b)/2,cy-(a+b)/4];

/* ---------- primitives statiques ---------- */
function block(P,sx,sy,a,b,h,z,sh,{edges=true}={}){const X=ISOP(sx,sy);
 P.poly([X(0,b),X(a,b),X(a,b,h),X(0,b,h)],(x,y)=>sh('L',x,y),z);
 P.poly([X(a,0),X(a,b),X(a,b,h),X(a,0,h)],(x,y)=>sh('R',x,y),z);
 P.poly([X(0,0,h),X(a,0,h),X(a,b,h),X(0,b,h)],(x,y)=>sh('T',x,y),z+.01);
 if(edges){for(const[p,q]of[[X(0,b),X(a,b)],[X(a,b),X(a,0)],[X(0,b),X(0,b,h)],[X(a,0),X(a,0,h)],[X(0,0,h),X(a,0,h)],[X(0,0,h),X(0,b,h)],[X(0,b,h),X(a,b,h)],[X(a,0,h),X(a,b,h)]])P.line(...p,...q,C.outline,z+.02);
  P.line(...X(a,b),...X(a,b,h),rp(C.stone,.2,0,0),z+.021)}
 return X}
// planches : horizontales (bardage) ou verticales (palissade, portes)
function wood(ramp=PAL.wood,{vertical=false,base=0,w=4}={}){return(f,x,y)=>{let v=(f==='T'?.74:f==='L'?.56:.34)+base;const q=f==='R'?y+.5*x:y-.5*x,s=f==='T'?y+.5*x:x;
 if(vertical||f==='T'){const c=Math.floor(s/w);v+=(hash(c,7,1)-.5)*.18;if(mod(s,w)<1)v-=.3}
 else{const r=Math.floor(q/w);v+=(hash(r,3,2)-.5)*.18;if(mod(q,w)<1)v-=.3;if(mod(s+r*7,19)<1)v-=.22}
 v+=(fbm(x/2,y/8,4)-.5)*.14;return rp(ramp,v,x,y)}}
function stoneSh(base=0,moss=0){return(f,x,y)=>{let v=(f==='T'?.7:f==='L'?.48:.3)+base;const q=f==='R'?y+.5*x:y-.5*x,r=Math.floor(q/5),s=x+(r%2)*5,c=Math.floor(s/10);
 v+=(hash(r,c,5)-.5)*.16+(fbm(x/6,y/6,8)-.5)*.12;if(f!=='T'&&(mod(q,5)<1||mod(s,10)<1))v-=.22;
 if(moss&&fbm(x/8,y/5,2)>1-moss*.35)return rp(C.moss,v+.12,x,y);return rp(C.stone,v,x,y)}}
// pignon : faîtage selon u, pente avant visible, pignon à droite
function roof(P,sx,sy,a,b,h,r,o,z,kind='shingle',wall=wood()){const X=ISOP(sx,sy);
 P.poly([X(a,0,h),X(a,b,h),X(a,b/2,h+r)],(x,y)=>wall('R',x,y),z);
 const ramp=PAL[kind];
 const tex=(lit)=>(x,y)=>{const q=y-.5*x;let v=lit;if(kind==='thatch'){v+=(hash(Math.floor(y+.5*x),1,5)-.5)*.34;if(mod(q,6)<1)v-=.22}
  else{const row=Math.floor(q/3);v+=(hash(row,Math.floor((x+row*3)/6),4)-.5)*.2;if(mod(q,3)<1)v-=.26;if(mod(x+row*3,6)<1)v-=.15}
  return rp(ramp,v+(fbm(x/7,y/7,9)-.5)*.1,x,y)};
 const back=[X(-o,b/2,h+r),X(a+o,b/2,h+r),X(a+o,-o,h-1),X(-o,-o,h-1)],front=[X(-o,b/2,h+r),X(a+o,b/2,h+r),X(a+o,b+o,h-1),X(-o,b+o,h-1)];
 P.poly(back,tex(.42),z+.1);P.poly(front,tex(.7),z+.2);
 for(const[p,q]of[[front[2],front[3]],[front[3],front[0]],[front[1],front[2]],[back[1],back[2]],[back[0],back[3]]])P.line(...p,...q,C.outline,z+.25);
 P.line(...front[0],...front[1],rp(ramp,.98,0,0),z+.26);
 // ombre portée du débord sur le mur
 for(let u=0;u<=a;u+=.5){const[x,y]=X(u,b,h-2);P.dark(x,y,.55,z+.05);P.dark(x,y+1,.75,z+.05)}
 return X}
// ouverture rectangulaire sur une face (L : v=b, R : u=a)
function opening(P,X,face,k,s0,s1,h0,h1,z,fill,frame=PAL.wood[4]){const at=(s,h)=>face==='L'?X(s,k,h):X(k,s,h);
 const pts=[at(s0,h0),at(s1,h0),at(s1,h1),at(s0,h1)];P.poly(pts,typeof fill==='function'?fill:()=>fill,z);
 for(let i=0;i<4;i++)P.line(...pts[i],...pts[(i+1)%4],frame,z+.01);return pts}
function cylinder(P,cx,cy,r,h,z,side,top){const ry=r/2;
 for(let i=-r;i<=r;i++){const e=ry*Math.sqrt(Math.max(0,1-(i/r)**2));for(let y=Math.round(cy-h-e);y<=Math.round(cy+e);y++)P.set(cx+i,y,side(cx+i,y,i/r,cy+e-y),z);P.set(cx+i,Math.round(cy+e)+1,C.outline,z+.01)}
 for(let j=-ry;j<=ry;j++)for(let i=-r;i<=r;i++){const d=(i/r)**2+(j/ry)**2;if(d<=1)P.set(cx+i,cy-h+j,top(cx+i,cy-h+j,d,i/r,j/ry),z+.02)}
 for(let a=0;a<200;a++){const t=a/200*Math.PI*2;P.set(cx+Math.cos(t)*(r+.5),cy-h+Math.sin(t)*(ry+.5),C.outline,z+.015)}
 P.set(cx-r-1,cy-h,C.outline,z);for(let y=Math.round(cy-h);y<=cy;y++){P.set(cx-r-1,y,C.outline,z+.01);P.set(cx+r+1,y,C.outline,z+.01)}}
// rondin couché selon v (bout visible côté avant-gauche)
function logV(P,X,u,v0,len,hc,r,z){for(let v=v0;v<=v0+len;v+=.5){const[x,y]=X(u,v,hc);for(let j=-r;j<=r;j++){const l=.7-j/r*.4+(hash(Math.round(v),j,6)-.5)*.2;P.set(x,y+j,rp(C.bark,l,x,y+j),z+v*.001)}P.set(x,y-r-1,C.outline,z);P.set(x,y+r+1,C.outline,z)}
 const[ex,ey]=X(u,v0+len,hc);for(let j=-r-1;j<=r+1;j++)for(let i=-r-1;i<=r+1;i++){const d=Math.hypot(i,j*1.1);if(d>r+1)continue;const ring=Math.floor(d*1.4)%2;P.set(ex+i,ey+j,d>r?C.bark[1]:rp(PAL.wood,.95-ring*.18-d/r*.2,ex+i,ey+j),z+.1)}}
function logU(P,X,u0,len,v,hc,r,z){for(let u=u0;u<=u0+len;u+=.5){const[x,y]=X(u,v,hc);for(let j=-r;j<=r;j++)P.set(x,y+j,rp(C.bark,.6-j/r*.4+(hash(Math.round(u),j,7)-.5)*.2,x,y+j),z);P.set(x,y-r-1,C.outline,z);P.set(x,y+r+1,C.outline,z)}
 const[ex,ey]=X(u0+len,v,hc);for(let j=-r;j<=r;j++)for(let i=-r;i<=r;i++){const d=Math.hypot(i*1.1,j);if(d<=r)P.set(ex+i,ey+j,rp(PAL.wood,.85-Math.floor(d*1.4)%2*.18,ex+i,ey+j),z+.1)}}
function post(P,X,u,v,h,z,ramp=PAL.wood,w=3){return block(P,...X(u,v),w,w,h,z,wood(ramp,{vertical:true,w:2}))}
function bannerPole(P,x,y,h,z){for(let i=0;i<h;i++){P.set(x,y-i,PAL.wood[3],z);P.set(x+1,y-i,PAL.wood[1],z)}P.set(x,y-h,C.gold[3],z+.01);P.set(x+1,y-h,C.gold[2],z+.01)}
function stake(P,x,yb,h,z,s){for(let i=0;i<h;i++)for(let k=-1;k<=1;k++)P.set(x+k,yb-i,rp(PAL.wood,.62-k*.25+(hash(s,i>>1,3)-.5)*.2,x+k,yb-i),z);
 P.set(x,yb-h,PAL.wood[5],z);P.set(x-1,yb-h+1,PAL.wood[3],z);P.set(x+1,yb-h+1,PAL.wood[2],z);P.set(x-2,yb,C.outline,z-.01);P.set(x+2,yb,C.outline,z-.01)}
function pile(P,x,y,n,ramp,z,R,spread=10){for(let k=0;k<n;k++){const a=R()*6.28,d=Math.sqrt(R())*spread;pebble2(P,x+Math.cos(a)*d,y+Math.sin(a)*d*.5-(spread-d)*.4,1+R()*2|0,ramp,z+k*.001)}}
function pebble2(P,x,y,r,ramp,z){for(let j=-r;j<=r;j++)for(let i=-r*1.4;i<=r*1.4;i++){const d=(i/(r*1.4))**2+(j/r)**2;if(d>1)continue;P.set(x+i,y+j,rp(ramp,.75-(i*.2+j*.6)/r*.35-d*.2,x+i,y+j),z)}}
function brazier(P,x,y,z){for(let i=-3;i<=3;i++){P.set(x+i,y-4,PAL.iron[2],z);P.set(x+i,y-5,PAL.iron[3+(i<0)],z)}for(let i=-2;i<=2;i++)P.set(x+i,y-3,PAL.iron[1],z);for(let j=0;j<3;j++){P.set(x,y-j,PAL.iron[2],z);P.set(x-2+j*0,y-j+0,PAL.iron[1],z)}P.set(x-2,y,PAL.iron[1],z);P.set(x+2,y,PAL.iron[1],z)}

/* ---------- couche animée ---------- */
const dot=(g,x,y,c)=>{g.fillStyle=c;g.fillRect(Math.round(x),Math.round(y),1,1)};
const lineA=(g,x0,y0,x1,y1,c)=>{const n=Math.max(1,Math.ceil(Math.max(Math.abs(x1-x0),Math.abs(y1-y0))));for(let i=0;i<=n;i++)dot(g,x0+(x1-x0)*i/n,y0+(y1-y0)*i/n,c)};
function smoke(g,x,y,t,n=7,rise=46,seed=0){for(let k=0;k<n;k++){const p=mod(t*.32+k/n+seed*.13,1),cx=x+Math.sin(p*5+k+seed)*2.5+p*p*12,cy=y-p*rise,r=1.2+p*4.5,fade=1-p;
 for(let j=-r;j<=r;j++)for(let i=-r;i<=r;i++){const d=Math.hypot(i,j)/r;if(d>1)continue;const px=Math.round(cx+i),py=Math.round(cy+j);if(BAYER[mod(py,4)][mod(px,4)]>fade*(1.1-d*.6))continue;dot(g,px,py,PAL.smoke[Math.min(4,Math.max(0,Math.round(3-d*2-j/r+fade)))])}}}
function flame(g,x,y,t,s=1,seed=0){for(let j=0;j<7*s;j++){const w=(1-j/(7*s))*2.6*s+Math.sin(t*14+j+seed)*.6;for(let i=-w;i<=w;i++){const heat=1-j/(7*s)-Math.abs(i)/(w+1)*.6+Math.sin(t*20+i*3+j+seed)*.12;const px=Math.round(x+i+Math.sin(t*9+j*.8+seed)*j*.12),py=Math.round(y-j);if(heat<.12)continue;dot(g,px,py,rp(PAL.fire,heat+.2,px,py))}}}
function glowPool(g,x,y,rx,ry,t,col='#f8aa34',k=.5){for(let j=-ry;j<=ry;j++)for(let i=-rx;i<=rx;i++){const d=(i/rx)**2+(j/ry)**2;if(d>1)continue;const px=Math.round(x+i),py=Math.round(y+j);if(BAYER[mod(py,4)][mod(px,4)]<(1-d)*k*(.85+.15*Math.sin(t*7)))dot(g,px,py,col)}}
function sparks(g,x,y,t,n=6,seed=0){for(let k=0;k<n;k++){const p=mod(t*.9+k/n+seed,1),a=-1.57+(hash(k,Math.floor(t*.9+k/n+seed),2)-.5)*1.6;dot(g,x+Math.cos(a)*p*16,y+Math.sin(a)*p*14+p*p*10,p<.5?PAL.fire[6]:PAL.fire[4])}}
function flag(g,x,y,w,h,t,ramp=C.cloth){for(let i=0;i<w;i++){const wave=Math.sin(t*5-i*.7)*(i/w)*1.6;for(let j=0;j<h;j++){if(j>h-4&&Math.abs(i-w/2+.5)<(j-(h-4))*1.2)continue;const px=x+i,py=Math.round(y+j+wave);dot(g,px,py,rp(ramp,.75-i/w*.35-j/h*.2+Math.sin(t*5-i*.7)*.1,px,py))}}
 const cx=x+(w>>1),cy=y+(h>>1)-2+Math.round(Math.sin(t*5-w*.35)*.8);for(let k=-2;k<=2;k++){dot(g,cx,cy+k,C.gold[3]);dot(g,cx+k,cy,C.gold[3])}}

/* ---------- sol commun ---------- */
function ground(P,seed,dirt){const R=rng(seed);for(let s=-12;s<=12;s++)for(let i=-8;i<=8;i++){const j=s-i;if(Math.abs(j)>8)continue;const cx=160+(i-j)*32,ty=110+(i+j)*16;if(cx<-40||cx>360||ty<-40||ty>250)continue;
  const d=Math.abs(i)+Math.abs(j),fn=dirt&&dirt(i,j)?pathTile:grassTile;fn(P,cx,ty,R,-100+(i+j)*.01,seed)}
 return R}
function frame(R,P){bushDraw(P,22,226,R,500);fern(P,300,232,R,500);fern(P,14,120,R,-60)}

/* =============== SCIERIE =============== */
function sawmillA(P,R){const[sx,sy]=origin(88,60,150,166);
 shadow(P,sx+30,sy+66,80,22,-50);
 // bief : canal d'eau le long de la face droite
 const X0=ISOP(sx,sy);P.poly([X0(92,-30),X0(112,-30),X0(112,96),X0(92,96)],(x,y)=>rp(PAL.water,.35+(fbm(x/9,y/3,3)-.5)*.5+(mod(y-.5*x,7)<1?.2:0),x,y),-60);
 for(const u of[91,112])for(let v=-30;v<=96;v+=.5){const[x,y]=X0(u,v);P.set(x,y,rp(C.stone,.5+hash(x,y,1)*.3,x,y),-59);P.set(x,y+1,C.outline,-59)}
 const X=block(P,sx,sy,88,60,10,0,stoneSh(0,.6));
 const[wx,wy]=X(0,0,10);block(P,wx,wy,88,60,30,1,wood());
 const Xw=ISOP(wx,wy);
 opening(P,Xw,'L',60,26,42,0,22,1.5,'#120b07');for(let h=3;h<22;h+=4)opening(P,Xw,'L',60,26,42,h,h+.5,1.51,PAL.wood[2],PAL.wood[2]);
 opening(P,Xw,'L',60,58,70,12,22,1.5,(x,y)=>rp(PAL.fire,.55+(BAYER[mod(y,4)][mod(x,4)]-.5)*.3,x,y),PAL.wood[5]);
 opening(P,Xw,'R',88,22,36,12,22,1.5,'#1a110a',PAL.wood[5]);
 roof(P,wx,wy,88,60,30,24,6,2,'shingle');
 // axe de la roue
 const[ax,ay]=X(96,30,16);for(let i=-3;i<=10;i++)P.set(ax-i*.5+i,ay+i*.5-i*.5,PAL.iron[2],2.5);
 // grumes empilées à gauche
 const Xl=ISOP(...origin(30,46,64,190));for(const[u,hc]of[[0,4],[9,4],[18,4],[4.5,11],[13.5,11],[9,18]])logV(P,Xl,u,0,40,hc,4,3+hc*.01+u*.001);
 // chevalet et planches à droite
 const Xp=ISOP(...origin(28,14,250,204));for(let k=0;k<5;k++)block(P,...Xp(0,0,k*2.2),34,14,2,4+k*.1,wood(PAL.wood,{base:.08}));
 return{sx,sy,X,wheel:{u:101,v:30,h:14,R:20}}}
function sawmillAnim(g,s,t){const{u,v,h,R}=s.wheel,X=ISOP(s.sx,s.sy);
 const P2=(uu,ang,rr)=>X(uu,v+Math.cos(ang)*rr,h+Math.sin(ang)*rr);
 const rim=(uu,c1,c2)=>{for(let a=0;a<96;a++){for(const[dr,c]of[[0,c1],[-1.2,c2]]){const[x0,y0]=P2(uu,a/96*6.283,R+dr),[x1,y1]=P2(uu,(a+1)/96*6.283,R+dr);lineA(g,x0,y0,x1,y1,c)}}};
 rim(u-4,PAL.wood[1],PAL.wood[2]);
 for(let k=0;k<12;k++){const a=k/12*6.283-t*1.4;const[i0,j0]=P2(u-4,a,2),[o0,q0]=P2(u-4,a,R);lineA(g,i0,j0,o0,q0,PAL.wood[2])}
 for(let k=0;k<12;k++){const a=k/12*6.283-t*1.4;for(let d=0;d<=8;d++){const[x0,y0]=P2(u-4+d,a,R+1),[x1,y1]=P2(u-4+d,a,R-5);lineA(g,x0,y0,x1,y1,d===0||d===8?C.outline:rp(PAL.wood,.45+Math.cos(a)*.3,x0|0,y0|0))}}
 rim(u+4,PAL.wood[4],PAL.wood[3]);
 for(let k=0;k<12;k++){const a=k/12*6.283-t*1.4;const[i0,j0]=P2(u+4,a,2),[o0,q0]=P2(u+4,a,R);lineA(g,i0,j0,o0,q0,PAL.wood[5]);lineA(g,i0+1,j0,o0+1,q0,PAL.wood[3])}
 const[hx,hy]=P2(u,0,0);for(let j=-1;j<=1;j++)for(let i=-1;i<=1;i++)dot(g,hx+i,hy+j,PAL.iron[3]);
 // écume au pied de la roue
 for(let k=0;k<14;k++){const p=mod(t*1.3+k/14,1),[x,y]=X(u-4+k%7*1.6,v+R-2+p*14,1);if(BAYER[mod(Math.round(y),4)][mod(Math.round(x),4)]<1-p)dot(g,x,y,PAL.water[6])}
 for(let k=0;k<26;k++){const[x,y]=X(94+hash(k,1,3)*16,mod(hash(k,2,3)*126+t*16,126)-30,0);dot(g,x,y,PAL.water[5])}
 // sciure qui sort par la porte
 const[dx,dy]=X(34,62,4);for(let k=0;k<8;k++){const p=mod(t*.8+k/8,1);dot(g,dx+(hash(k,5,1)-.5)*14*p,dy+p*8-Math.sin(p*3)*6,PAL.straw[3])}}

function sawmillB(P,R){
 const sc=[112,132];shadow(P,sc[0]+6,sc[1]+4,44,16,-50);
 for(const[a,l]of[[2.5,18],[3.0,14],[.2,16],[.7,20],[1.6,10]])for(let k=0;k<l;k++){const x=sc[0]+Math.cos(a)*(34+k),y=sc[1]+Math.sin(a)*(14+k*.5)+k*.15;for(let j=-2;j<=1;j++)P.set(x,y+j,rp(C.bark,.6-j*.15-k/l*.2,x|0,y+j),-1+Math.sin(a)*.5)}
 cylinder(P,sc[0],sc[1],38,34,0,(x,y,n,hh)=>{let v=.62-n*.42+(hash(x>>1,y>>3,4)-.5)*.2;if(mod(x+Math.round(Math.sin(y*.3)*1.5),5)===0)v-=.2;if(hh<12&&fbm(x/5,y/4,2)>.58)return rp(C.moss,v+.15,x,y);return rp(C.bark,v,x,y)},
  (x,y,d,i,j)=>{const rr=Math.sqrt(d);if(rr>.92)return rp(C.bark,.5,x,y);return rp(PAL.wood,.92-Math.floor(rr*9)%2*.14-rr*.25+(i+j)*-.1,x,y)});
 const[sx,sy]=origin(84,64,178,184);const X=ISOP(sx,sy);shadow(P,180,192,74,24,-50);
 P.poly([X(-4,-4),X(88,-4),X(88,68),X(-4,68)],(x,y)=>rp(C.dirt,.4+(fbm(x/8,y/5,7)-.5)*.5,x,y),-80);
 for(const[u,v]of[[2,2],[40,2],[78,2]])post(P,X,u,v,40,1+u*.001);
 const at=(u,v,h)=>X(u,v,h);const pr=[at(-6,-6,44),at(88,-6,44),at(88,30,32),at(-6,30,32)];
 const Xp=ISOP(...X(6,8));for(let k=0;k<5;k++)block(P,...Xp(0,0,k*2.4),64,12,2,2+k*.1,wood(PAL.wood,{base:.1}));
 for(const[u,v]of[[2,26],[40,26],[78,26]])post(P,X,u,v,32,3+u*.001);
 P.poly(pr,(x,y)=>{let v=.66+(hash(Math.floor(y+.5*x),1,5)-.5)*.34;if(mod(y-.5*x,6)<1)v-=.22;return rp(PAL.thatch,v,x,y)},9);
 P.poly([at(88,-6,44),at(88,30,32),at(88,30,29),at(88,-6,41)],(x,y)=>rp(PAL.thatch,.3,x,y),9.1);
 for(let i=0;i<4;i++)P.line(...pr[i],...pr[(i+1)%4],C.outline,9.2);P.line(...pr[0],...pr[1],PAL.thatch[5],9.3);
 for(let u=-6;u<=88;u+=.5){const[x,y]=at(u,30,32);for(let k=1;k<4;k++)if(hash(Math.round(u*2),k,8)>.45)P.set(x,y+k,PAL.thatch[k<2?2:1],9.15)}
 for(const u of[18,56])for(const v of[42,52]){const[x,y]=X(u,v);for(let i=0;i<16;i++){P.set(x-4+i*.25,y-i,PAL.wood[3],10);P.set(x+4-i*.25,y-i,PAL.wood[2],10)}}
 logU(P,X,6,70,47,19,6,11);
 pile(P,...X(60,62),30,PAL.straw,12,R,12);
 return{sx,sy,X}}
function sawmillBAnim(g,s,t){const X=s.X,p=Math.sin(t*5);
 // scie de long à deux poignées
 const[x,y]=X(40+p*7,47,36),[x2,y2]=X(40+p*7,47,6);lineA(g,x,y,x2,y2,PAL.iron[4]);lineA(g,x+1,y,x2+1,y2,PAL.iron[2]);
 for(const[hx,hy]of[[x,y],[x2,y2]])for(let i=-3;i<=3;i++)dot(g,hx+i,hy,PAL.wood[5]);
 for(let k=0;k<10;k++){const q=mod(t*1.5+k/10,1);dot(g,x2+(hash(k,3,4)-.5)*10*q,y2+q*10,PAL.straw[2+(k%2)])}}

/* =============== PUITS DE FONDERIE =============== */
function foundryA(P,R){const c=[150,166];shadow(P,c[0]+6,c[1]+6,58,20,-50);
 cylinder(P,c[0],c[1],34,16,0,(x,y,n,hh)=>{const r=Math.floor((y+Math.round(Math.abs(n)*3))/4),q=x+(r%2)*4;let v=.6-n*.4+(hash(r,q>>3,5)-.5)*.18;if(mod(y,4)===0||mod(q,8)===0)v-=.22;if(hh<6&&fbm(x/6,y/4,3)>.62)return rp(C.moss,v+.1,x,y);return rp(C.stone,v,x,y)},
  (x,y,d)=>d>.55?rp(C.stone,.82-d*.25+(hash(x>>2,y>>1,9)-.5)*.2,x,y):rp(PAL.fire,(.55-d)*1.6+.05,x,y));
 for(let a=0;a<200;a++){const tt=a/200*6.283,x=c[0]+Math.cos(tt)*25,y=c[1]-16+Math.sin(tt)*12.5;P.set(x,y,C.outline,.03)}
 // chevalement en bois
 const X=ISOP(c[0],c[1]-8);
 for(const[u0,v0,u1,v1]of[[-34,0,-6,0],[34,0,6,0]])for(let w=0;w<3;w++)P.line(...X(u0+w,v0,-6),...X(u1+w*.3,v1,58),f=>rp(PAL.wood,.7-w*.25,0,0),1+w*.01+(u0>0?.5:0));
 const[a0,b0]=X(-8,0,58),[a1,b1]=X(8,0,58);for(let w=0;w<3;w++)P.line(a0-2,b0+w,a1+2,b1+w,PAL.wood[5-w],2);
 // poulie
 for(let a=0;a<60;a++){const tt=a/60*6.283;P.set(c[0]+Math.cos(tt)*5,c[1]-8-58-6+Math.sin(tt)*5,PAL.iron[3],2.1)}
 // forge annexe avec cheminée
 const[fx,fy]=origin(40,30,236,186),F=block(P,fx,fy,40,30,22,3,stoneSh(-.02,.4));roof(P,fx,fy,40,30,22,12,3,4,'clay',stoneSh());
 const[cx,cy]=F(6,6,22);block(P,cx-0,cy+4,10,10,30,5,stoneSh(.05));opening(P,F,'L',30,10,24,0,13,4.5,(x,y)=>rp(PAL.fire,.4+(BAYER[mod(y,4)][mod(x,4)])*.3,x,y),C.stone[5]);
 // enclume, minerai, chariot
 const[ex,ey]=[196,216];for(let i=-5;i<=6;i++){P.set(ex+i,ey-6,PAL.iron[4],6);P.set(ex+i,ey-5,PAL.iron[2],6)}for(let j=-4;j<=0;j++)for(let i=-2;i<=2;i++)P.set(ex+i,ey+j,PAL.iron[1+(i<0)],6);P.set(ex+7,ey-6,PAL.iron[3],6);
 pile(P,104,206,30,['#2a1a14','#4a2a1c','#6e3a24','#8a5a3a','#5a5650'],6,R,13);
 return{c,X,forge:F,chimney:[cx+5,cy-26+4]}}
function foundryAAnim(g,s,t){const[cx,cy]=s.c;glowPool(g,cx,cy-16,20,9,t,PAL.fire[5],.55);sparks(g,cx,cy-20,t,8);
 const d=(Math.sin(t*1.2)*.5+.5);const top=cy-8-58-6,by=cy-22-d*30;lineA(g,cx+5,top,cx+5,by,PAL.rope[1]);
 for(let j=0;j<6;j++)for(let i=-3;i<=3;i++)dot(g,cx+5+i,by+j,j===0?PAL.iron[4]:rp(PAL.iron,.5-i*.08,cx+i,by+j));if(d<.5)for(let i=-2;i<=2;i++)dot(g,cx+5+i,by,PAL.fire[4+(i&1)]);
 smoke(g,s.chimney[0],s.chimney[1],t,8,50);const[fx,fy]=s.forge(20,30,6);flame(g,fx+2,fy+4,t,.9)}

function foundryB(P,R){const[sx,sy]=origin(54,54,140,170);const X=ISOP(sx,sy);shadow(P,150,176,66,22,-50);
 // haut-fourneau en tronc de pyramide de pierre
 const lv=[[54,14],[46,14],[38,14],[30,12]];let o=0,hz=0;for(const[k,[s,h]]of lv.entries()){const d=(54-s)/2;block(P,...X(d,d,hz),s,s,h,k,stoneSh(-.03+k*.03,k<2?.5:0));hz+=h}
 const top=X(27,27,hz);cylinder(P,top[0],top[1]+0,9,12,5,(x,y,n)=>rp(C.stone,.55-n*.4+(mod(y,3)===0?-.2:0),x,y),(x,y,d)=>d>.45?rp(C.stone,.7,x,y):'#0e0806');
 // gueule du four
 for(let j=0;j<16;j++)for(let i=-8;i<=8;i++){const r=i*i/64+(j>10?((j-10)/6)**2:0);if(r>1)continue;const[x,y]=X(27+i,54,j);P.set(x,y,rp(PAL.fire,.9-j/24-Math.abs(i)/20,x,y),4.5)}
 for(let a=0;a<=40;a++){const tt=a/40*Math.PI,[x,y]=X(27+Math.cos(tt)*10,54,10+Math.sin(tt)*7);P.set(x,y,C.stone[7],4.6);P.set(x,y-1,C.outline,4.6)}
 // soufflet
 const B=ISOP(...X(40,62));block(P,...B(0,0),18,10,4,6,wood());
 // auvent sur poteaux
 const Wx=ISOP(...X(60,-4));for(const[u,v]of[[0,0],[34,0],[0,40],[34,40]])post(P,Wx,u,v,26,7+u*.001);
 roof(P,...Wx(0,0),37,43,26,10,3,8,'shingle',wood());
 // lingots et laitier
 const Li=ISOP(...X(4,66));for(let k=0;k<3;k++)for(let m=0;m<3-k;m++)block(P,...Li(m*10+k*5,0,k*3),8,4,3,10+k,(f,x,y)=>rp(PAL.iron,f==='T'?.85:f==='L'?.55:.3,x,y));
 pile(P,92,206,40,['#141010','#2a1e1a','#3e2a22','#5a3a2a','#7a6650'],10,R,14);
 return{X,top:[top[0],top[1]-14],B,mouth:X(27,56,0),bellow:B(9,5,4)}}
function foundryBAnim(g,s,t){const[mx,my]=s.mouth;glowPool(g,mx,my+6,28,9,t,PAL.fire[4],.42);flame(g,mx,my-1,t,1.4);flame(g,mx-4,my,t,.8,2);flame(g,mx+4,my,t,.9,4);
 smoke(g,s.top[0],s.top[1],t,9,56);sparks(g,s.top[0],s.top[1]+2,t,5,.3);
 const pump=Math.abs(Math.sin(t*2.4));const[bx,by]=s.bellow;for(let i=-8;i<=8;i++){const hh=Math.round((1-Math.abs(i)/8*.4)*(3+pump*5));for(let j=0;j<hh;j++)dot(g,bx+i,by-j,rp(['#2a1a10','#4a2c18','#6a4224','#8a5a30'],.7-j/hh*.4-i/16,bx+i,by-j))}
 for(let i=-9;i<=9;i++)dot(g,bx+i,by-Math.round(3+pump*5)-1,PAL.wood[5])}

/* =============== TEMPLE =============== */
function templeA(P,R){const[sx,sy]=origin(96,96,160,170);shadow(P,166,178,80,26,-50);
 const X=ISOP(sx,sy);masonry(P,sx,sy,96,96,6,0,{bh:6,bw:12,moss:1,cracks:1});const X1=ISOP(...X(10,10,6));masonry(P,...X(10,10,6),76,76,6,1,{bh:6,bw:12,moss:1});
 for(let k=0;k<2;k++){const p=X(30,96+k*6);masonry(P,p[0],p[1],36,6,4-k*2,2+k,{bh:4,bw:9})}
 const at=(u,v)=>X1(u,v,6);const cols=[[8,8,false],[68,8,false],[8,68,false],[68,68,true]];
 let elev=0;const order=cols.map(([u,v,br])=>({d:u+v,f:()=>{const[x,y]=at(u,v);const ty=column(P,x,y+8,38,10+(u+v)*.1,br,R);if(u===8&&v===8)elev=y-ty;if(!br&&u<20)vine(P,x+4,ty+4,18+R()*10|0,R,60)}}));
 order.push({d:76,f:()=>{const[x,y]=at(38,38);const al=masonry(P,x,y,20,20,10,20,{bh:4,bw:8});const[ax,ay]=al.top(10,10);brazier(P,ax,ay,21)}});
 order.sort((a,b)=>a.d-b.d).forEach(o=>o.f());
 // linteau sur les colonnes arrière
 const lo=X1(-2,2,6+elev+12);masonry(P,lo[0],lo[1],82,12,7,40,{bh:7,bw:12,moss:1});
 const[gx,gy]=X1(38,14,6+elev+15);for(let k=-3;k<=3;k++){P.set(gx+k,gy,C.gold[3],41);P.set(gx,gy+k,C.gold[3],41)}
 for(const[u,v]of[[0,96],[96,40]]){const[x,y]=X(u,v);fern(P,x-6,y+4,R,90)}
 return{X1,at,braziers:[at(-8+0,80),at(80,-8)],altar:at(48,48)}}
function templeAAnim(g,s,t){const[ax,ay]=s.altar;const by=ay-10-3-11;
 // flamme sacrée violette sur l'autel
 for(let j=0;j<16;j++){const w=(1-j/16)*4.5+Math.sin(t*12+j)*.6;for(let i=-w;i<=w;i++){const h=1-j/16-Math.abs(i)/(w+1)*.5;dot(g,ax+i+Math.sin(t*8+j)*j*.1-10,by-j+6,rp(C.orb,h+.3,ax+i,by-j))}}
 glowPool(g,ax-10,by+8,16,6,t,C.glow[1],.35);
 for(let k=0;k<6;k++){const p=mod(t*.4+k/6,1);dot(g,ax-10+Math.sin(p*6+k)*6,by-4-p*30,p<.6?C.orb[5]:C.orb[4])}
 flag(g,s.at(8,68)[0]-14,s.at(8,68)[1]-46,8,22,t);flag(g,s.at(68,8)[0]+8,s.at(68,8)[1]-46,8,22,t+1.3)}

function templeB(P,R){const c=[160,180];shadow(P,166,186,72,26,-50);
 cylinder(P,c[0],c[1],62,5,0,(x,y,n)=>rp(C.stone,.5-n*.3+(hash(x>>2,y,3)-.5)*.2,x,y),(x,y,d,i,j)=>{const a=Math.atan2(j,i),r=Math.sqrt(d),ring=Math.floor(r*4),seg=Math.floor((a+3.15)/6.3*(6+ring*6));let v=.62+(hash(ring,seg,6)-.5)*.2-r*.15+(-i-j)*.06;if(mod(r*4,1)<.1||mod((a+3.15)/6.3*(6+ring*6),1)<.06)v-=.24;if(fbm(x/7,y/4,12)>.68)return rp(C.moss,v,x,y);return rp(C.stone,v,x,y)});
 const X=ISOP(c[0],c[1]-5);
 // menhirs en cercle (arrière d'abord)
 const st=[];for(let k=0;k<7;k++){const a=k/7*6.283+.3,u=Math.cos(a)*50,v=Math.sin(a)*50;st.push([u,v,k])}st.sort((a,b)=>(a[0]+a[1])-(b[0]+b[1]));
 const obel=()=>{const lv=[[20,8],[14,46],[11,10]];let hz=0;for(const[k,[s,h]]of lv.entries()){block(P,...X(-s/2,-s/2,hz),s,s,h,20+k,stoneSh(.05,k===0?.6:.15));hz+=h}
  const tp=X(0,0,hz),pts=[X(-5.5,-5.5,hz),X(5.5,-5.5,hz),X(5.5,5.5,hz),X(-5.5,5.5,hz)];const apex=[tp[0],tp[1]-12];
  P.poly([pts[3],pts[2],apex],(x,y)=>rp(C.gold,.75,x,y),24);P.poly([pts[1],pts[2],apex],(x,y)=>rp(C.gold,.4,x,y),24);for(const p of[pts[1],pts[2],pts[3]])P.line(...p,...apex,C.outline,24.1);P.line(...pts[3],...pts[2],C.outline,24.1);P.line(...pts[1],...pts[2],C.outline,24.1)};
 let done=false;for(const[u,v,k]of st){if(!done&&u+v>0){obel();done=true}const h=12+hash(k,1,1)*10|0;block(P,...X(u-4,v-3),8,6,h,10+(u+v)*.01+(u+v>0?20:0),stoneSh(0,.7));if(hash(k,2,2)>.6)vine(P,X(u,v,h)[0],X(u,v,h)[1],8,R,61)}
 if(!done)obel();
 for(const[u,v]of[[-30,40],[40,-30]]){const[x,y]=X(u,v);P.set(x,y-2,C.flower[1],50);P.set(x+1,y-2,C.flower[1],50);P.set(x,y-1,C.flower[0],50)}
 fern(P,94,206,R,90);fern(P,232,212,R,90);
 return{X}}
function templeBAnim(g,s,t){const X=s.X;
 // runes qui s'allument de bas en haut sur les deux faces visibles
 for(let k=0;k<6;k++){const h=14+k*6.5,on=.5+.5*Math.sin(t*2-k*.7);if(on<.25)continue;const col=on>.75?C.orb[5]:C.glow[1];
  for(const[face,s0]of[['L',-2],['R',2]]){const pts=face==='L'?[[-3,7],[-1,7],[1,7],[-1,7]]:[[7,-3],[7,-1],[7,1],[7,-1]];const glyph=[[0,0],[0,1],[0,2],[1,1],[-1,1],[0,3]].filter((_,i)=>hash(k,i,face==='L'?1:2)>.3);
   const[bx,by]=face==='L'?X(-1,7,h):X(7,-1,h);for(const[i,j]of glyph)dot(g,bx+i,by-j,col)}}
 // orbe flottant au-dessus du pyramidion
 const[ox,oy]=X(0,0,82+Math.sin(t*1.6)*3);glowPool(g,ox,oy+20,10,4,t,C.glow[0],.4);
 for(let j=-4;j<=4;j++)for(let i=-4;i<=4;i++){const d=Math.hypot(i,j);if(d>4.3)continue;dot(g,ox+i,oy+j,d>3.6?C.outline:rp(C.orb,.6-(i+j)*.09+(1-d/4)*.2,ox+i,oy+j))}dot(g,ox-2,oy-2,C.orb[5]);
 for(let k=0;k<3;k++){const a=t*1.3+k*2.09;dot(g,ox+Math.cos(a)*8,oy+Math.sin(a)*3,C.glow[1])}}

/* =============== CASERNE =============== */
function barracksA(P,R){const S=100,[sx,sy]=origin(S,S,160,176);const X=ISOP(sx,sy);shadow(P,166,182,96,30,-50);
 P.poly([X(0,0),X(S,0),X(S,S),X(0,S)],(x,y)=>rp(C.dirt,.35+(fbm(x/8,y/5,7)-.5)*.5,x,y),-80);
 const stakes=[];for(let u=0;u<=S;u+=3.4){stakes.push([u,0]);stakes.push([u,S])}for(let v=3.4;v<S;v+=3.4){stakes.push([0,v]);stakes.push([S,v])}
 const gate=(u,v)=>v===S&&u>36&&u<64;
 // intérieur : tente et râtelier (dessinés entre la rangée arrière et la rangée avant)
 const inner=()=>{const Xi=ISOP(...X(18,16));block(P,...Xi(0,0),44,30,14,30,wood());roof(P,...Xi(0,0),44,30,14,14,4,31,'thatch');
  const[tx,ty]=X(74,24);for(let i=0;i<4;i++)for(let j=0;j<18;j++)P.set(tx+i*4,ty-j+i*2,j<3?PAL.iron[4]:PAL.wood[3],35);};
 const back=stakes.filter(([u,v])=>v===0||u===0).sort((a,b)=>a[0]+a[1]-b[0]-b[1]),front=stakes.filter(([u,v])=>!(v===0||u===0)&&!gate(u,v)).sort((a,b)=>a[0]+a[1]-b[0]-b[1]);
 for(const[u,v]of back){const[x,y]=X(u,v);stake(P,x,y,24+(hash(u|0,v|0,3)*5|0),u+v*1.0001*0+.001*(u+v),u*7+v)}
 // tour de guet au coin arrière
 const T=ISOP(...X(-4,-4));for(const[u,v]of[[0,0],[16,0],[0,16],[16,16]])post(P,T,u,v,52,5+u*.001+v*.001);
 for(const h of[18,36])for(const[a,b]of[[[0,16],[16,16]],[[16,0],[16,16]]])P.line(...T(...a,h),...T(...b,h+10),PAL.wood[2],6);
 block(P,...T(-3,-3,52),25,25,4,7,wood());for(const[u,v]of[[-3,-3],[22,-3],[-3,22],[22,22]])post(P,T,u,v,10,8);
 const tp=T(9.5,9.5,76);const rs=[T(-5,-5,62),T(24,-5,62),T(24,24,62),T(-5,24,62)];P.poly([rs[3],rs[2],tp],(x,y)=>{let v=.68+(hash(Math.floor(x),1,4)-.5)*.3;return rp(PAL.thatch,v,x,y)},9);P.poly([rs[1],rs[2],tp],(x,y)=>rp(PAL.thatch,.38+(hash(Math.floor(x),2,4)-.5)*.3,x,y),9);
 for(const p of[rs[1],rs[2],rs[3]])P.line(...p,...tp,C.outline,9.1);P.line(...rs[3],...rs[2],C.outline,9.1);P.line(...rs[1],...rs[2],C.outline,9.1);
 inner();
 for(const[u,v]of front){const[x,y]=X(u,v);stake(P,x,y,22+(hash(u|0,v|0,3)*5|0),100+(u+v)*.01,u*7+v)}
 // porte : deux battants entrouverts
 const g0=X(36,S),g1=X(64,S);for(const[u0,u1,o]of[[36,44,1],[56,64,-1]])P.poly([X(u0,S),X(u1,S+(o>0?8:-0),0),X(u1,S+(o>0?8:0),20),X(u0,S,20)].map((p,i)=>o<0&&i%3===0?X(u1,S+8,i?20:0):p),wood(PAL.wood,{vertical:true}).bind(null,'L'),110);
 for(const u of[35,65]){const[x,y]=X(u,S);for(let i=0;i<30;i++){P.set(x,y-i,PAL.wood[4],111);P.set(x+1,y-i,PAL.wood[2],111)}}
 const[hx,hy]=X(35,S,30),[kx,ky]=X(65,S,30);for(let w=0;w<3;w++)P.line(hx-1,hy+w,kx+1,ky+w,PAL.wood[5-w],112);
 return{X,T,gate:X(50,S,30)}}
function barracksAAnim(g,s,t){const[gx,gy]=s.gate;flag(g,gx-4,gy-1,9,14,t);const[tx,ty]=s.T(9.5,9.5,76);for(let i=0;i<16;i++){dot(g,tx,ty-i,PAL.wood[5]);dot(g,tx-1,ty-i,PAL.wood[3])}flag(g,tx+1,ty-15,10,8,t+.5);
 for(const u of[35,65]){const[x,y]=s.X(u,100,33);flame(g,x,y,t,.6,u)}}

function barracksB(P,R){const[sx,sy]=origin(112,50,154,170);const X=ISOP(sx,sy);shadow(P,160,178,100,26,-50);
 block(P,sx,sy,112,50,8,0,stoneSh(0,.5));const[wx,wy]=X(0,0,8);const Xw=ISOP(wx,wy);
 // colombage : enduit clair + poutres sombres
 const daub=(f,x,y)=>{let v=(f==='T'?.7:f==='L'?.62:.4)+(fbm(x/4,y/4,11)-.5)*.2;return rp(['#3a3424','#5a5038','#7a6e4c','#9a8c62','#b4a678'],v,x,y)};
 block(P,wx,wy,112,50,24,1,daub);
 for(let u=0;u<=112;u+=16){P.line(...Xw(u,50,0),...Xw(u,50,24),PAL.wood[1],1.5);P.line(...Xw(u+.6,50,0),...Xw(u+.6,50,24),PAL.wood[3],1.5)}
 for(const h of[0,12,24])P.line(...Xw(0,50,h),...Xw(112,50,h),PAL.wood[2],1.5);
 for(let u=0;u<112;u+=32){P.line(...Xw(u,50,0),...Xw(u+16,50,12),PAL.wood[2],1.5);P.line(...Xw(u+16,50,12),...Xw(u+32,50,0),PAL.wood[2],1.5)}
 for(let v=0;v<=50;v+=25)P.line(...Xw(112,v,0),...Xw(112,v,24),PAL.wood[1],1.5);P.line(...Xw(112,0,12),...Xw(112,50,12),PAL.wood[2],1.5);
 opening(P,Xw,'L',50,48,64,0,20,1.6,'#120b07',PAL.wood[5]);for(let u=50;u<64;u+=4)P.line(...Xw(u,50.01,0),...Xw(u,50.01,19),PAL.wood[2],1.61);
 for(const u of[20,84])opening(P,Xw,'L',50,u,u+8,13,20,1.6,(x,y)=>rp(PAL.fire,.6,x,y),PAL.wood[5]);
 roof(P,wx,wy,112,50,24,26,6,2,'thatch',daub);
 // mannequin d'entraînement et râtelier
 const[mx,my]=[262,214];shadow(P,mx+2,my,7,2,-40);for(let i=0;i<24;i++)P.set(mx,my-i,PAL.wood[3],5);for(let i=-7;i<=7;i++)P.set(mx+i,my-16,PAL.wood[4],5.1);
 for(let j=0;j<12;j++)for(let i=-3;i<=3;i++)P.set(mx+i,my-20+j-6,rp(PAL.straw,.75-i*.1+(hash(i,j,1)-.5)*.3,mx+i,my-26+j),5.2);for(let j=-2;j<=2;j++)for(let i=-2;i<=2;i++)if(i*i+j*j<6)P.set(mx+i,my-30+j,rp(PAL.straw,.8-(i+j)*.1,mx+i,my-30+j),5.3);
 const[rx,ry]=[56,214];for(let k=0;k<5;k++){for(let i=0;i<26;i++)P.set(rx+k*4+i*.08,ry-i,PAL.wood[4],5);P.set(rx+k*4+2,ry-27,PAL.iron[5],5.1);P.set(rx+k*4+2,ry-26,PAL.iron[4],5.1);P.set(rx+k*4+2,ry-28,PAL.iron[3],5.1)}for(let i=-2;i<22;i++){P.set(rx+i,ry-8,PAL.wood[2],5.2);P.set(rx+i,ry-20,PAL.wood[2],5.2)}
 // bouclier rond sur le mur
 const[bx,by]=Xw(30,50,8);for(let j=-5;j<=5;j++)for(let i=-5;i<=5;i++){const d=Math.hypot(i,j);if(d<=5)P.set(bx+i,by+j,d>4?PAL.iron[3]:d<1.5?C.gold[3]:rp(C.cloth,.7-(i+j)*.06,bx+i,by+j),1.7)}
 return{X,Xw,door:Xw(56,52,22),hole:Xw(30,25,24+20),dummy:[mx,my]}}
function barracksBAnim(g,s,t){const[dx,dy]=s.door;flag(g,dx-26,dy-2,8,18,t);flag(g,dx+14,dy+6,8,18,t+.8);smoke(g,s.hole[0],s.hole[1],t,7,40,1);
 const hit=mod(t,1.6)<.15;if(hit){const[mx,my]=s.dummy;for(let k=0;k<5;k++)dot(g,mx+4+k,my-24+hash(k,Math.floor(t/1.6),1)*6,PAL.straw[3])}}

/* =============== BALISTES =============== */
// arme dessinée en vraie 3D iso selon un cap, recalculée à chaque image
function ballistaWeapon(g,cx,cy,base,yaw,t,cycle,kind,phase,noFlight){const c=Math.cos(yaw),s=Math.sin(yaw),K=1.9;
 const W3=(a,b,h)=>{a*=K;b*=K;h*=K;const u=a*c-b*s,v=a*s+b*c;return[cx+u-v,cy+(u+v)/2-base-h]};
 const fire=phase===undefined?mod(t,cycle)/cycle:phase<.76?phase/.76*.7:.7+(phase-.76)/.24*.3,draw=fire<.7?fire/.7:0,release=fire>=.7&&fire<.78;
 const pts=[];const seg=(a,b,col,depthBias=0,w=1)=>pts.push({a,b,col,w,d:(a[0]+b[0])*.5*(c-s)+(a[1]+b[1])*.5*(s+c)+depthBias});
 // affût pivotant
 for(let a=0;a<24;a++){const t0=a/24*6.283,t1=(a+1)/24*6.283;seg([Math.cos(t0)*7,Math.sin(t0)*7,0],[Math.cos(t1)*7,Math.sin(t1)*7,0],PAL.iron[3])}
 for(const o of[-1,0,1])seg([o,0,0],[o,0,6],o<0?PAL.wood[4]:PAL.wood[2]);
 // bouclier de pierre tyrienne à l'avant
 for(let h=4;h<=10;h+=.5)seg([12,-5,h],[12,5,h],h>9.5?C.gold[2]:rp(C.stone,.4+h/20,0,0),-.2);
 // fût (crosse) de -14 à +18
 for(const w of[-1.5,-.75,0,.75,1.5])for(const hh of[0,1])seg([-14,w,7+hh],[18,w,8+hh],hh?(w<0?PAL.wood[6]:PAL.wood[5]):w<0?PAL.wood[4]:PAL.wood[2]);
 // bras arqués et corde
 const bend=1-draw*.25,pull=-10*draw;
 for(const side of[-1,1]){let prev=[14,side*2,8];for(let k=1;k<=6;k++){const q=[14-k*k*.32*bend,side*(2+k*2.6),8+k*.15];seg(prev,q,k<3?PAL.iron[4]:PAL.wood[5]);seg([prev[0],prev[1],prev[2]-.6],[q[0],q[1],q[2]-.6],k<3?PAL.iron[2]:PAL.wood[3]);prev=q}
  const tip=[14-36*.32*bend,side*17.6,8.9];seg(tip,[pull-2+ (release?6:0),0,8.4],PAL.rope[2])}
 // trait
 if(fire<.72)seg([pull,0,9],[pull+26,0,9.5],PAL.iron[5],.5);
 seg([-14,-3,6],[-14,3,6],PAL.wood[1]);
 pts.sort((p,q)=>p.d-q.d);for(const p of pts){const[x0,y0]=W3(...p.a),[x1,y1]=W3(...p.b);lineA(g,x0,y0,x1,y1,p.col)}
 for(let a=0;a<6;a++){const[x,y]=W3(-14+a*.5,0,8.5);dot(g,x,y-1,C.gold[2])}
 // pointe dorée
 if(fire<.72){const[x,y]=W3(pull+27,0,9.5);dot(g,x,y,C.gold[3]);dot(g,x+1,y,C.gold[2])}
 // trait en vol
 if(fire>=.7&&!noFlight){const f=(fire-.7)/.3;const[x0,y0]=W3(18+f*160,0,9+f*6),[x1,y1]=W3(10+f*160,0,9+f*6);lineA(g,x0,y0,x1,y1,PAL.iron[5]);dot(g,x0,y0,C.gold[3]);
  if(f<.25)for(let k=0;k<6;k++){const[x,y]=W3(20,0,9);dot(g,x+(hash(k,1,1)-.5)*8,y+(hash(k,2,1)-.5)*6,PAL.smoke[4])}}}

function ballistaA(P,R,repaired){const c=[160,196];shadow(P,168,202,62,20,-50);
 // tour basse octogonale de pierre tyrienne
 cylinder(P,c[0],c[1],40,repaired?44:30,0,(x,y,n,hh)=>{const r=Math.floor(y/5),q=x+(r%2)*5;let v=.6-n*.42+(hash(r,q>>3,5)-.5)*.16;if(mod(y,5)===0||mod(q,10)===0)v-=.22;if(fbm(x/7,y/4,2)>(repaired?.68:.55))return rp(C.moss,v+.1,x,y);return rp(C.stone,v,x,y)},
  (x,y,d,i,j)=>rp(C.stone,.74-d*.3+(hash(x>>2,y>>1,4)-.5)*.2+(Math.floor(Math.sqrt(d)*3)!==Math.floor(Math.sqrt(d)*3+.12)?-.2:0),x,y));
 const top=c[1]-(repaired?44:30);
 if(!repaired){// créneaux effondrés, gravats et ballista brisée
  for(const a of[3.6,4.4,5.6]){const x=c[0]+Math.cos(a)*32,y=top+Math.sin(a)*16;block(P,x-4,y-2,8,6,6+hash(a*9|0,1,1)*6|0,2+(a>4.5?1:0),stoneSh(.02,.6))}
  pile(P,112,214,24,C.stone,3,R,14);pile(P,214,216,18,C.stone,3,R,10);
  const X=ISOP(c[0],top);for(const[a,b,col]of[[[-12,-2],[16,3],PAL.wood[3]],[[-6,8],[14,-10],PAL.wood[2]],[[4,-12],[8,10],PAL.wood[4]]])P.line(...X(...a,2),...X(...b,4),col,4);
  for(const[a,b]of[[-20,6],[18,10]]){const[x,y]=X(a,b,0);for(let i=0;i<6;i++)P.set(x+i,y-i*.3,PAL.wood[3],4)}
  vine(P,c[0]-24,top+4,24,R,5);vine(P,c[0]+14,top+12,18,R,5);
  return{c,top,repaired}}
 for(let k=0;k<8;k++){const a=k/8*6.283+.2;if(Math.sin(a)<-.1)continue;}
 // merlons à l'arrière seulement pour laisser voir l'arme
 for(const a of[3.3,3.9,4.5,5.1,5.7]){const x=c[0]+Math.cos(a)*34,y=top+Math.sin(a)*17;block(P,x-4,y-1,8,6,9,1+(Math.sin(a)+1),stoneSh(.06,.2))}
 const X=ISOP(c[0],top);for(let a=0;a<64;a++){const tt=a/64*6.283;P.set(c[0]+Math.cos(tt)*16,top+Math.sin(tt)*8,C.gold[1+(a%4===0)],3)}
 return{c,top,repaired}}
function ballistaB(P,R,repaired){const c=[160,198];shadow(P,166,204,70,22,-50);
 // plate-forme carrée en gradins et arche de garde
 const[sx,sy]=origin(84,84,160,198);const X=ISOP(sx,sy);masonry(P,sx,sy,84,84,10,0,{bh:4,bw:10,moss:1,cracks:repaired?0:2});
 const X1=ISOP(...X(10,10,10));masonry(P,...X(10,10,10),64,64,repaired?14:7,1,{bh:5,bw:10,moss:1});
 const top=X1(32,32,repaired?14:7);
 if(!repaired){column(P,...X(4,4,10),36,2,true,R);pile(P,204,222,22,C.stone,4,R,12);pile(P,120,214,16,C.stone,4,R,10);
  const[x,y]=top;for(const[dx,dy,l,col]of[[-14,0,22,PAL.wood[3]],[2,-6,18,PAL.wood[2]]])for(let i=0;i<l;i++)P.set(x+dx+i,y+dy+i*.4,col,5);
  for(let i=0;i<10;i++)P.set(x+6+i*.6,y-2-i,PAL.iron[2],5.1);vine(P,top[0]-20,top[1]-2,16,R,6);return{c:top,top:top[1],repaired,X}}
 // deux piliers et linteau gravé à l'arrière
 column(P,...X(4,4,10),60,2,false,R);
 // anneau de rotation en laiton
 for(let a=0;a<80;a++){const tt=a/80*6.283;P.set(top[0]+Math.cos(tt)*18,top[1]+Math.sin(tt)*9,C.gold[2+(a%5===0)],4);P.set(top[0]+Math.cos(tt)*18,top[1]+Math.sin(tt)*9+1,C.gold[0],4)}
 const[cx0,cy0]=X(4,4,10);bannerDraw(P,cx0+9,cy0-58,8,24,5);
 return{c:top,top:top[1],repaired,X}}
function ballistaAnim(g,s,t,kind){if(!s.repaired){// étincelles bleues de l'ancienne énergie tyrienne
  for(let k=0;k<5;k++){const p=mod(t*.5+k/5,1);if(p<.7)dot(g,s.c[0]-10+hash(k,Math.floor(t*.5+k/5),2)*24,(kind?s.c[1]:s.top)-4-p*10,p<.3?C.orb[5]:C.glow[0])}return}
 const yaw=-t*.42;const cx=s.c[0],cy=kind?s.c[1]:s.top;ballistaWeapon(g,cx,cy,0,yaw,t,2.4,kind)}

/* =============== VARIANTES C · D · E =============== */
PAL.canvas=['#2e2618','#4a3e2a','#6a5c40','#8c7c5a','#ae9e7a','#ccc09c'];PAL.cloth=C.cloth;
function surf(kind,lit){const ramp=PAL[kind];return(x,y)=>{const q=y-.5*x;let v=lit;
 if(kind==='thatch'){v+=(hash(Math.floor(y+.5*x),1,5)-.5)*.34;if(mod(q,6)<1)v-=.22}
 else if(kind==='canvas'||kind==='cloth'){v+=(fbm(x/6,y/6,5)-.5)*.16;if(mod(y+.5*x,10)<1)v-=.14}
 else{const row=Math.floor(q/3);v+=(hash(row,Math.floor((x+row*3)/6),4)-.5)*.2;if(mod(q,3)<1)v-=.26;if(mod(x+row*3,6)<1)v-=.15}
 return rp(ramp,v+(fbm(x/7,y/7,9)-.5)*.1,x,y)}}
// toit à un seul pan, pente vers l'avant (v croissant)
function monoRoof(P,X,u0,u1,v0,v1,hB,hF,z,kind='shingle'){const pr=[X(u0,v0,hB),X(u1,v0,hB),X(u1,v1,hF),X(u0,v1,hF)];
 P.poly(pr,surf(kind,.66),z);P.poly([X(u1,v0,hB),X(u1,v1,hF),X(u1,v1,hF-2),X(u1,v0,hB-2)],(x,y)=>rp(PAL[kind],.25,x,y),z+.1);
 for(let i=0;i<4;i++)P.line(...pr[i],...pr[(i+1)%4],C.outline,z+.2);P.line(...pr[0],...pr[1],rp(PAL[kind],.95,0,0),z+.21);
 if(kind==='thatch')for(let u=u0;u<=u1;u+=.5){const[x,y]=X(u,v1,hF);for(let k=1;k<4;k++)if(hash(Math.round(u*2),k,8)>.45)P.set(x,y+k,PAL.thatch[k<2?2:1],z+.15)}}
function sawBlade(g,x,y,r,t){for(let a=0;a<48;a++){const tt=a/48*6.283+t*9;const rr=r+(a%3===0?1.2:0);dot(g,x+Math.cos(tt)*rr,y+Math.sin(tt)*rr*.5,a%3===0?PAL.iron[5]:PAL.iron[3])}
 for(let j=-r;j<=r;j++)for(let i=-r;i<=r;i++){const d=Math.hypot(i,j*2);if(d<r-.5)dot(g,x+i,y+j/1,d<2?C.gold[2]:rp(PAL.iron,.55-(i+j)*.05+Math.sin(t*20+d)*.08,x+i,y+j))}}
function tent(P,X,u,v,a,b,r,z,kind='canvas'){const[sx,sy]=X(u,v);const wall=(f,x,y)=>rp(PAL[kind],f==='R'?.4:.6,x,y);roof(P,sx,sy,a,b,0,r,1,z,kind,wall);
 // entrée sombre sur le pignon
 const Xs=ISOP(sx,sy);P.poly([Xs(a+.2,b/2-4,0),Xs(a+.2,b/2+4,0),Xs(a+.2,b/2,r*.7)],()=>'#140e08',z+.3)}
function campfire(P,x,y,z){for(let a=0;a<12;a++){const tt=a/12*6.283;pebble2(P,x+Math.cos(tt)*7,y+Math.sin(tt)*3.5,1.5,C.stone,z)}for(let i=-4;i<=4;i++){P.set(x+i,y-1+(i&1),PAL.wood[2],z+.1)}}
function target(P,x,y,z){for(let i=0;i<20;i++){P.set(x-5+i*.15,y-i,PAL.wood[2],z);P.set(x+5-i*.15,y-i,PAL.wood[2],z)}
 for(let j=-7;j<=7;j++)for(let i=-6;i<=6;i++){const d=Math.hypot(i/6,j/7);if(d>1)continue;const ring=Math.floor(d*4);P.set(x+i,y-14+j,ring===0?C.cloth[4]:ring===2?C.cloth[2]:rp(PAL.straw,.8-i*.04,x+i,y+j),z+.1)}}
function dummy(P,mx,my,z){shadow(P,mx+2,my,7,2,-40);for(let i=0;i<24;i++)P.set(mx,my-i,PAL.wood[3],z);for(let i=-7;i<=7;i++)P.set(mx+i,my-16,PAL.wood[4],z+.1);
 for(let j=0;j<12;j++)for(let i=-3;i<=3;i++)P.set(mx+i,my-26+j,rp(PAL.straw,.75-i*.1+(hash(i,j,1)-.5)*.3,mx+i,my-26+j),z+.2);for(let j=-2;j<=2;j++)for(let i=-2;i<=2;i++)if(i*i+j*j<6)P.set(mx+i,my-30+j,rp(PAL.straw,.8-(i+j)*.1,mx+i,my-30+j),z+.3)}

/* ---- Scierie ---- */
function sawmillC(P,R){const[sx,sy]=origin(72,56,164,170);const X=ISOP(sx,sy);shadow(P,170,180,76,24,-50);
 const posts=[];for(const u of[0,34,68])for(const v of[0,26,52])posts.push([u,v]);
 for(const[u,v]of posts.filter(([u,v])=>u+v<60))post(P,X,u,v,16,1+(u+v)*.001);
 for(const[k,u]of[6,15,24,33,42].entries())logU(P,X,u-6,54,20+(k%2)*10,4,4,2+k*.01);
 for(const[u,v]of posts.filter(([u,v])=>u+v>=60))post(P,X,u,v,16,3+(u+v)*.001);
 block(P,...X(-3,-3,16),78,62,3,4,wood(PAL.wood,{vertical:true,base:.05}));
 const[wx,wy]=X(0,0,19);block(P,wx,wy,72,56,24,5,wood(PAL.wood,{vertical:true,w:3}));const Xw=ISOP(wx,wy);
 opening(P,Xw,'R',72,18,38,0,18,5.5,'#130c07',PAL.wood[5]);opening(P,Xw,'L',56,12,22,10,18,5.5,(x,y)=>rp(PAL.fire,.6,x,y),PAL.wood[5]);
 roof(P,wx,wy,72,56,24,20,5,6,'clay',wood(PAL.wood,{vertical:true,w:3}));
 // rampe d'accès
 const rp0=[X(72,22,19),X(72,38,19),X(100,38,0),X(100,22,0)];P.poly(rp0,(x,y)=>{let v=.6+(hash(Math.floor((y+.5*x)/3),2,2)-.5)*.2;if(mod(y+.5*x,3)<1)v-=.25;return rp(PAL.wood,v,x,y)},8);for(let i=0;i<4;i++)P.line(...rp0[i],...rp0[(i+1)%4],C.outline,8.1);
 logV(P,ISOP(...origin(20,30,262,206)),0,0,26,4,4,9);logV(P,ISOP(...origin(20,30,262,206)),9,0,26,4,4,9.1);
 return{X,Xw}}
function sawmillCAnim(g,s,t){const X=s.X;for(let k=0;k<16;k++){const p=mod(t*.7+k/16,1);const[x,y]=X(10+hash(k,1,1)*50,8+hash(k,2,1)*40,16-p*16);dot(g,x,y,PAL.straw[2+(k&1)])}
 const[dx,dy]=s.Xw(74,28,6);sawBlade(g,dx+6,dy,6,t)}

function sawmillD(P,R){const[sx,sy]=origin(90,60,158,176);const X=ISOP(sx,sy);shadow(P,164,184,82,26,-50);
 P.poly([X(0,0),X(90,0),X(90,60),X(0,60)],(x,y)=>rp(C.dirt,.4+(fbm(x/8,y/5,7)-.5)*.5,x,y),-80);
 masonry(P,sx,sy,90,8,46,0,{bh:6,bw:12,moss:1,cracks:2});masonry(P,sx,sy,8,60,40,1,{bh:6,bw:12,moss:1,cracks:1});
 vine(P,...X(30,8,46),20,R,2);vine(P,...X(70,8,46),14,R,2);
 // atelier : établi + scie circulaire
 const[bx,by]=X(30,26);block(P,bx,by,36,14,10,3,wood());
 const Xp=ISOP(...X(14,40));for(let k=0;k<4;k++)block(P,...Xp(0,0,k*2.4),30,10,2,4+k*.1,wood(PAL.wood,{base:.1}));
 for(const[u,v]of[[86,40],[46,40]])post(P,X,u,v,28,5+u*.001);
 monoRoof(P,X,8,92,8,44,36,28,7,'shingle');
 // murs bas effondrés à l'avant
 for(const[u0,a,h]of[[0,16,18],[16,10,9],[64,26,12]])masonry(P,...X(u0,60),a,6,h,8+u0*.001,{bh:6,bw:12,moss:1});
 pile(P,...X(40,68),14,C.stone,9,R,8);logV(P,ISOP(...origin(26,30,268,210)),0,0,24,4,4,10);logV(P,ISOP(...origin(26,30,268,210)),9,0,24,4,4,10.1);logV(P,ISOP(...origin(26,30,268,210)),4.5,0,24,11,4,10.2);
 return{X,blade:X(48,33,14)}}
function sawmillDAnim(g,s,t){const[x,y]=s.blade;sawBlade(g,x,y,7,t);for(let k=0;k<10;k++){const p=mod(t*1.4+k/10,1);dot(g,x-8-p*14,y-2+p*6-Math.sin(p*3)*5,PAL.straw[3])}}

function sawmillE(P,R){const[sx,sy]=origin(80,44,156,178);const X=ISOP(sx,sy);shadow(P,162,186,80,24,-50);
 // fosse de sciage
 P.poly([X(10,16),X(70,16),X(70,28),X(10,28)],(x,y)=>rp(C.dirt,.08+(fbm(x/4,y/4,3))*.2,x,y),-70);for(const v of[16,28])for(let u=10;u<=70;u+=.5){const[x,y]=X(u,v);P.set(x,y,PAL.wood[4],-69)}
 const Xl=ISOP(...origin(30,46,64,198));for(const[u,hc]of[[0,5],[11,5],[22,5],[5.5,14],[16.5,14],[11,23]])logV(P,Xl,u,0,36,hc,5,1+hc*.01+u*.001);
 // portiques en A
 for(const u of[6,74]){for(const[v,w]of[[0,0],[44,1]])for(let k=0;k<5;k++)P.line(...X(u+k*.5,v),...X(u+k*.5,22,60),k===0||k===4?C.outline:k===1?PAL.wood[5]:PAL.wood[4-w],2+u*.01+v*.001+k*.0001);}
 for(let k=-1;k<5;k++)P.line(...X(2,22,58+k),...X(80,22,58+k),k<0||k===4?C.outline:PAL.wood[5-k],3);
 logU(P,X,14,52,22,4,5,3.5);
 const Xp=ISOP(...X(48,52));for(let k=0;k<4;k++)block(P,...Xp(0,0,k*2.4),36,10,2,4+k*.1,wood(PAL.wood,{base:.1}));
 pile(P,...X(40,34),16,PAL.straw,5,R,10);
 return{X}}
function sawmillEAnim(g,s,t){const X=s.X,p=(Math.sin(t*.6)*.5+.5),u=16+p*14,h=24+Math.sin(t*1.2)*6;
 for(const du of[6,40]){const[x0,y0]=X(u+du,22,60),[x1,y1]=X(u+du,22,h+5);lineA(g,x0,y0,x1,y1,PAL.rope[1])}
 for(let uu=u;uu<=u+46;uu+=.5){const[x,y]=X(uu,22,h);for(let j=-4;j<=4;j++)dot(g,x,y+j,rp(C.bark,.62-j/4*.4,x,y+j))}const[ex,ey]=X(u+46,22,h);for(let j=-4;j<=4;j++)for(let i=-4;i<=4;i++)if(i*i+j*j<17)dot(g,ex+i,ey+j,rp(PAL.wood,.85-Math.floor(Math.hypot(i,j)*1.4)%2*.18,ex+i,ey+j));
 const q=Math.sin(t*5);const[sx,sy]=X(40,22,10+q*5),[sx2,sy2]=X(40,22,-6+q*5);lineA(g,sx,sy,sx2,sy2,PAL.iron[4])}

/* ---- Fonderie ---- */
function foundryC(P,R){const[sx,sy]=origin(80,80,160,178);const X=ISOP(sx,sy);shadow(P,166,184,80,26,-50);
 for(const[u,v]of[[-4,-4],[30,-4],[64,-4]])post(P,X,u,v,40,0);
 masonry(P,sx,sy,80,80,5,1,{bh:5,bw:10,moss:1});const X1=ISOP(...X(0,0,5));
 P.poly([X1(12,12),X1(68,12),X1(68,68),X1(12,68)],(x,y)=>rp(['#120806','#24100a','#3a160c','#5a200e','#8a3210'],.15+fbm(x/5,y/4,6)*.5,x,y),2);
 for(const[p,q]of[[X1(12,12),X1(68,12)],[X1(12,12),X1(12,68)]])P.line(...p,...q,C.outline,2.1);
 const cr=[[26,30],[52,28],[40,52]];for(const[k,[u,v]]of cr.entries()){const[x,y]=X1(u,v,-2);cylinder(P,x,y,7,9,3+k,(xx,yy,n)=>rp(PAL.iron,.6-n*.4,xx,yy),(xx,yy,d)=>d>.6?PAL.iron[4]:rp(PAL.fire,1.05-d,xx,yy))}
 for(const[u,v]of[[-4,32],[64,32]])post(P,X,u,v,32,6);
 monoRoof(P,X,-8,72,-8,36,44,34,7,'clay');
 const Li=ISOP(...X(84,30));for(let k=0;k<3;k++)for(let m=0;m<3-k;m++)block(P,...Li(m*10+k*5,0,k*3),8,4,3,10+k,(f,x,y)=>rp(PAL.iron,f==='T'?.85:f==='L'?.55:.3,x,y));
 pile(P,92,212,26,['#2a1a14','#4a2a1c','#6e3a24','#8a5a3a','#5a5650'],10,R,12);
 return{X1,cr}}
function foundryCAnim(g,s,t){const X1=s.X1;const[cx,cy]=X1(40,40);glowPool(g,cx,cy,34,16,t,PAL.fire[2],.4);
 for(const[k,[u,v]]of s.cr.entries()){const[x,y]=X1(u,v,7);glowPool(g,x,y,6,3,t+k,PAL.fire[5],.6);for(let b=0;b<3;b++){const p=mod(t*1.3+b/3+k*.2,1);dot(g,x+Math.sin(b*7+k)*3,y-p*5,PAL.fire[6])}smoke(g,x,y-4,t,4,26,k)}
 sparks(g,cx,cy-4,t,6)}

function foundryD(P,R){const[sx,sy]=origin(70,44,150,184);const X=ISOP(sx,sy);shadow(P,160,188,80,24,-50);
 const ch=X(78,8);cylinder(P,ch[0],ch[1]-0,15,96,0,(x,y,n)=>{const r=Math.floor(y/3),q=x+(r%2)*3;let v=.55-n*.4+(hash(r,q>>2,5)-.5)*.16;if(mod(y,3)===0||mod(q,6)===0)v-=.2;return rp(PAL.clay,v+.1,x,y)},(x,y,d)=>d>.5?rp(PAL.clay,.6,x,y):'#0c0605');
 for(const h of[30,64,94])for(let a=0;a<120;a++){const tt=a/120*6.283;if(Math.sin(tt)<0)continue;P.set(ch[0]+Math.cos(tt)*16,ch[1]-h+Math.sin(tt)*8,PAL.iron[3],.5)}
 block(P,sx,sy,70,44,22,1,stoneSh(0,.5));const Xw=ISOP(...X(0,0));
 for(const u of[10,30,50])opening(P,Xw,'L',44,u,u+10,6,16,1.5,(x,y)=>rp(PAL.fire,.5+BAYER[mod(y,4)][mod(x,4)]*.3,x,y),C.stone[5]);
 opening(P,Xw,'R',70,14,30,0,16,1.5,'#120806',PAL.wood[4]);
 roof(P,sx,sy,70,44,22,16,4,2,'clay',stoneSh());
 const[ax,ay]=X(84,56);for(let i=-5;i<=6;i++){P.set(ax+i,ay-6,PAL.iron[4],5);P.set(ax+i,ay-5,PAL.iron[2],5)}for(let j=-4;j<=0;j++)for(let i=-2;i<=2;i++)P.set(ax+i,ay+j,PAL.iron[1+(i<0)],5);
 pile(P,70,212,30,['#2a1a14','#4a2a1c','#6e3a24','#8a5a3a','#5a5650'],6,R,13);
 return{top:[ch[0],ch[1]-104],X,Xw}}
function foundryDAnim(g,s,t){smoke(g,s.top[0],s.top[1],t,11,70);sparks(g,s.top[0],s.top[1]+3,t,6);for(const u of[15,35,55]){const[x,y]=s.Xw(u,46,0);glowPool(g,x,y+4,7,3,t+u,PAL.fire[4],.5)}}

function foundryE(P,R){const[sx,sy]=origin(84,40,160,182);const X=ISOP(sx,sy);shadow(P,166,188,80,24,-50);
 masonry(P,sx,sy,84,40,4,0,{bh:4,bw:10,moss:1});const X1=ISOP(...X(0,0,4));
 masonry(P,...X1(0,6),16,16,58,1,{bh:6,bw:10,moss:1,cracks:1});
 const[hx,hy]=X1(22,10);masonry(P,hx,hy,40,22,12,2,{bh:4,bw:8});
 const hp=ISOP(hx,hy);P.poly([hp(3,3,12),hp(37,3,12),hp(37,19,12),hp(3,19,12)],(x,y)=>rp(['#120806','#2a1008','#4a1a0a','#7a2a0c'],.2+fbm(x/3,y/3,4)*.6,x,y),2.5);
 masonry(P,...X1(68,6),16,16,58,3,{bh:6,bw:10,moss:1});
 masonry(P,...X1(-2,4,58),88,20,12,4,{bh:6,bw:12,moss:1,cracks:1});
 const[gx,gy]=X1(42,24,64);for(let k=-3;k<=3;k++){P.set(gx+k,gy,C.gold[3],5);P.set(gx,gy+k,C.gold[3],5)}
 // enclume et bac de trempe
 const[ax,ay]=X(50,52);for(let i=-6;i<=7;i++){P.set(ax+i,ay-8,PAL.iron[5],6);P.set(ax+i,ay-7,PAL.iron[3],6)}for(let j=-6;j<=0;j++)for(let i=-2;i<=2;i++)P.set(ax+i,ay+j,PAL.iron[1+(i<0)],6);P.set(ax+8,ay-8,PAL.iron[4],6);
 const T=ISOP(...X(70,46));block(P,...T(0,0),24,10,7,7,wood());P.poly([T(1,1,7),T(23,1,7),T(23,9,7),T(1,9,7)],(x,y)=>rp(PAL.water,.4+(fbm(x/4,y/2,5)-.5)*.4,x,y),7.1);
 vine(P,...X1(2,6,58),26,R,8);
 return{hearth:hp(20,11,12),anvil:[ax,ay-9],water:T(12,5,7)}}
function foundryEAnim(g,s,t){const[hx,hy]=s.hearth;glowPool(g,hx,hy,22,8,t,PAL.fire[3],.5);flame(g,hx-6,hy,t,.9,1);flame(g,hx+4,hy+1,t,1,3);flame(g,hx+12,hy,t,.7,5);
 const ph=mod(t,1.1);const[ax,ay]=s.anvil;for(let i=-4;i<=4;i++)dot(g,ax+i,ay,PAL.fire[4]);if(ph<.12)sparks(g,ax,ay,t*3,10);
 smoke(g,s.water[0],s.water[1],t*.8,5,24,3)}

/* ---- Temple ---- */
function templeC(P,R){const c=[160,186];shadow(P,166,190,74,26,-50);
 cylinder(P,c[0],c[1],64,10,0,(x,y,n)=>{const r=Math.floor(y/5);let v=.5-n*.35+(hash(r,x>>3,2)-.5)*.16;if(mod(y,5)===0||mod(x+r*4,10)===0)v-=.2;if(fbm(x/6,y/4,2)>.65)return rp(C.moss,v+.1,x,y);return rp(C.stone,v,x,y)},
  (x,y,d,i,j)=>{const r=Math.sqrt(d);let v=.64-r*.15+(hash(Math.floor(r*5),Math.floor(Math.atan2(j,i)*4),6)-.5)*.2;if(mod(r*5,1)<.1)v-=.25;if(fbm(x/7,y/4,12)>.7)return rp(C.moss,v,x,y);return rp(C.stone,v,x,y)});
 const X=ISOP(c[0],c[1]-10);const cols=[];for(let k=0;k<6;k++){const a=k/6*6.283+.52;cols.push([Math.cos(a)*44,Math.sin(a)*44,k])}cols.sort((a,b)=>a[0]+a[1]-b[0]-b[1]);
 let orb=false;for(const[u,v,k]of cols){if(!orb&&u+v>0){const[ox,oy]=X(0,0,0);masonry(P,ox-12,oy-12,24,24,8,30,{bh:4,bw:8});orb=true}const[x,y]=X(u,v);const ty=column(P,x,y+8,40,10+(u+v)*.1+(u+v>0?40:0),k===4,R);if(k%2===0&&k!==4)vine(P,x+4,ty+4,16,R,90)}
 return{c,X}}
function templeCAnim(g,s,t){const[ox,oy]=s.X(0,0,52+Math.sin(t*1.4)*3);glowPool(g,ox,oy+40,22,8,t,C.glow[0],.35);
 const r=10;for(let j=-r;j<=r;j++)for(let i=-r;i<=r;i++){const d=Math.hypot(i,j);if(d>r+.5)continue;dot(g,ox+i,oy+j,d>r-.5?C.outline:rp(C.orb,.55-(i*.5+j*.7)/r*.45+(1-d/r)*.2+(fbm((ox+i)/4,(oy+j)/4+t*.3,11)-.5)*.25,ox+i,oy+j))}
 dot(g,ox-4,oy-5,C.orb[5]);dot(g,ox-3,oy-5,C.orb[5]);for(let a=0;a<64;a++){const tt=a/64*6.283+t*.6;if(a%8<5)dot(g,ox+Math.cos(tt)*16,oy+Math.sin(tt)*6+2,C.glow[1])}}

function templeD(P,R){const[sx,sy]=origin(104,40,160,186);const X=ISOP(sx,sy);shadow(P,166,192,86,24,-50);
 masonry(P,sx,sy,104,40,6,0,{bh:6,bw:12,moss:1});for(let k=0;k<2;k++){const p=X(30,40+k*6);masonry(P,p[0],p[1],44,6,4-k*2,1+k,{bh:4,bw:9})}
 const X1=ISOP(...X(0,0,6));masonry(P,...X1(6,12),18,18,64,3,{bh:8,bw:9,moss:1,cracks:1});masonry(P,...X1(80,12),18,18,64,4,{bh:8,bw:9,moss:1});
 masonry(P,...X1(0,10,64),104,22,14,5,{bh:7,bw:12,moss:1,cracks:2});const pts=[X1(4,10,78),X1(100,10,78),X1(52,10,94)];
 P.poly([X1(30,10,78),X1(74,10,78),X1(52,10,90),],(x,y)=>rp(C.stone,.62+(fbm(x/5,y/5,3)-.5)*.2,x,y),6);P.poly([X1(30,10,78),X1(30,32,78),X1(52,21,90),X1(52,10,90)],(x,y)=>rp(C.stone,.72,x,y),6.05);
 const[gx,gy]=X1(52,33,71);for(let a=0;a<40;a++){const tt=a/40*6.283;P.set(gx+Math.cos(tt)*5,gy+Math.sin(tt)*5,C.gold[3],7)}for(let k=-3;k<=3;k++){P.set(gx+k,gy,C.gold[2],7);P.set(gx,gy+k,C.gold[2],7)}
 bannerDraw(P,...X1(15,30,52).map((v,i)=>v+(i?0:-4)),9,28,8);bannerDraw(P,...X1(89,30,52).map((v,i)=>v+(i?0:-4)),9,28,8);
 vine(P,...X1(8,30,64),22,R,9);brazier(P,...X(18,52),9);brazier(P,...X(92,52),9);fern(P,...X(0,40),R,10);
 return{X1,br:[X(18,52),X(92,52)]}}
function templeDAnim(g,s,t){const X1=s.X1;for(let u=24;u<=80;u+=.5)for(let h=0;h<=63;h++){const[x,y]=X1(u,22,h);const n=fbm(u/8,h/10-t*.6,13),px=Math.round(x),py=Math.round(y);if(BAYER[mod(py,4)][mod(px,4)]<n*.55+.05)dot(g,px,py,rp(C.orb,n*.9+.2,px,py))}
 for(const[x,y]of s.br)flame(g,x,y-6,t,.8,x)}

function templeE(P,R){const[sx,sy]=origin(100,100,160,186);const X=ISOP(sx,sy);shadow(P,166,190,86,30,-50);
 const tiers=[[0,100,12],[14,72,12],[28,44,12],[38,24,10]];let hz=0;for(const[k,[o,s,h]]of tiers.entries()){masonry(P,...X(o,o,hz),s,s,h,k*2,{bh:6,bw:12,moss:k<3?1:0,cracks:k===0?2:0});hz+=h}
 // escalier frontal
 for(let k=0;k<12;k++){const v=100-k*3.2,h=k*3.8;if(h>=46)break;masonry(P,...X(42,v-4,0),16,4,h+3.8,12-k*.2,{bh:4,bw:8})}
 const[tx,ty]=X(50,50,46);brazier(P,tx,ty-1,9);for(const[u,v]of[[2,60],[60,2],[16,40]]){const[x,y]=X(u,v,u===16?12:12);vine(P,x,y-12,16,R,10)}
 bannerDraw(P,...X(14,86,24),8,22,10);bannerDraw(P,...X(86,14,24),8,22,10);fern(P,...X(0,100),R,11);
 return{top:[tx,ty-6]}}
function templeEAnim(g,s,t){const[x,y]=s.top;for(let j=0;j<14;j++){const w=(1-j/14)*4+Math.sin(t*12+j)*.6;for(let i=-w;i<=w;i++)dot(g,x+i+Math.sin(t*8+j)*j*.1,y-j,rp(C.orb,1-j/14-Math.abs(i)/(w+1)*.5+.3,x+i,y-j))}glowPool(g,x,y+4,14,5,t,C.glow[1],.35);
 for(let k=0;k<5;k++){const p=mod(t*.4+k/5,1);dot(g,x+Math.sin(p*6+k)*5,y-8-p*30,C.orb[5])}}

/* ---- Caserne ---- */
function barracksC(P,R){const[sx,sy]=origin(110,90,160,180);const X=ISOP(sx,sy);shadow(P,166,186,92,30,-50);
 P.poly([X(0,0),X(110,0),X(110,90),X(0,90)],(x,y)=>rp(C.dirt,.36+(fbm(x/8,y/5,7)-.5)*.5,x,y),-80);
 tent(P,X,4,4,48,36,30,1,'cloth');tent(P,X,62,6,30,24,20,2,'canvas');tent(P,X,4,50,30,24,20,3,'canvas');
 const[fx,fy]=X(60,58);campfire(P,fx,fy,4);for(const[u,v]of[[48,58],[72,58]]){const[x,y]=X(u,v);for(let i=-5;i<=5;i++){P.set(x+i,y-2,PAL.wood[3],5);P.set(x+i,y-1,PAL.wood[2],5)}}
 const[rx,ry]=X(96,64);for(let k=0;k<4;k++){for(let i=0;i<24;i++)P.set(rx+k*4+i*.08,ry-i,PAL.wood[4],6);P.set(rx+k*4+2,ry-26,PAL.iron[5],6.1);P.set(rx+k*4+2,ry-25,PAL.iron[4],6.1)}for(let i=-2;i<18;i++)P.set(rx+i,ry-8,PAL.wood[2],6.2);
 const[px,py]=X(4,4,0);bannerPole(P,px-30,py+36,40,7);
 return{fire:[fx,fy-1],pole:[px-30,py+36-40]}}
function barracksCAnim(g,s,t){flame(g,s.fire[0],s.fire[1],t,1.1);glowPool(g,s.fire[0],s.fire[1]+2,16,6,t,PAL.fire[3],.3);smoke(g,s.fire[0],s.fire[1]-8,t,6,40,2);flag(g,s.pole[0]+2,s.pole[1]+1,12,9,t)}

function barracksD(P,R){const[sx,sy]=origin(56,56,150,186);const X=ISOP(sx,sy);shadow(P,160,190,70,24,-50);
 const As=ISOP(...X(56,4));block(P,...As(0,0),40,40,18,0,wood());roof(P,...As(0,0),40,40,18,14,3,1,'thatch',wood());
 masonry(P,sx,sy,56,56,62,2,{bh:6,bw:12,moss:1,cracks:2});
 const Xw=ISOP(...X(0,0));for(const h of[24,44])for(const u of[14,40])opening(P,Xw,'L',56,u,u+2,h,h+8,3,'#0c0806',C.stone[2]);
 for(let j=0;j<20;j++)for(let i=-6;i<=6;i++){const r=i*i/36+(j>14?((j-14)/6)**2:0);if(r>1)continue;const[x,y]=X(28+i,56,j);P.set(x,y,'#120b07',3)}
 block(P,...X(-4,-4,62),64,64,12,4,wood());const Xh=ISOP(...X(-4,-4,62));for(let u=4;u<64;u+=10)opening(P,Xh,'L',64,u,u+3,4,8,4.5,'#0c0806',PAL.wood[2]);
 roof(P,...X(-4,-4,62),64,64,12,22,4,5,'shingle',wood());
 return{X,flag:X(30,30,98)}}
function barracksDAnim(g,s,t){const[x,y]=s.flag;for(let i=0;i<18;i++){dot(g,x,y-i,PAL.wood[5]);dot(g,x-1,y-i,PAL.wood[3])}flag(g,x+1,y-17,12,10,t);const[tx,ty]=s.X(28,58,22);flame(g,tx-10,ty,t,.6,1);flame(g,tx+10,ty+0,t,.6,2)}

function barracksE(P,R){const[sx,sy]=origin(110,96,160,182);const X=ISOP(sx,sy);shadow(P,166,188,92,30,-50);
 P.poly([X(30,30),X(110,30),X(110,96),X(30,96)],(x,y)=>rp(['#5a4a30','#7a6642','#9a8456','#b4a06c'],.4+(fbm(x/6,y/4,5)-.5)*.4,x,y),-80);
 block(P,sx,sy,110,28,22,0,wood());roof(P,sx,sy,110,28,22,14,4,1,'thatch',wood());
 const Xb=ISOP(...X(0,28));block(P,...Xb(0,0),28,68,22,2,wood());const Xw=ISOP(...X(0,0));
 // pignon gauche (toit selon v) dessiné en pente simple
 monoRoof(P,Xb,-4,32,-2,72,30,22,3,'thatch');
 for(const u of[24,60,92])opening(P,Xw,'L',28,u,u+10,0,14,1.5,'#120b07',PAL.wood[5]);for(const v of[10,40])opening(P,Xb,'R',28,v,v+8,8,14,3.5,(x,y)=>rp(PAL.fire,.6,x,y),PAL.wood[5]);
 for(let u=30;u<=110;u+=3.4){const[x,y]=X(u,96);stake(P,x,y,10,6+u*.001,u)}for(let v=30;v<96;v+=3.4){const[x,y]=X(110,v);stake(P,x,y,10,5+v*.001,v)}
 target(P,...X(90,48),4);target(P,...X(96,64),4.5);dummy(P,...X(52,62),4.6);dummy(P,...X(66,78),4.7);
 return{X,from:X(40,70,14)}}
function barracksEAnim(g,s,t){const X=s.X,p=mod(t/1.6,1);const tg=X(90,48,14);const[x0,y0]=X(40,70,12);const f=Math.min(1,p*2);const x=x0+(tg[0]-x0)*f,y=y0+(tg[1]-y0)*f-Math.sin(f*Math.PI)*10;lineA(g,x-3,y+.5,x,y,PAL.wood[5]);dot(g,x+1,y,PAL.iron[5])}

/* ---- Balistes C · D · E ---- */
function ballistaC(P,R,repaired){const[sx,sy]=origin(40,40,160,206);const X=ISOP(sx,sy);shadow(P,166,210,46,16,-50);
 const h=repaired?56:30;masonry(P,sx,sy,40,40,h,0,{bh:6,bw:10,moss:1,cracks:repaired?1:3});
 for(const[u,v]of[[4,36],[36,4]]){const[x,y]=X(u,v,h*.5);for(let k=0;k<6;k++)P.set(x+(u<10?-k:k)*.2,y+k,C.glow[0],1)}
 if(!repaired){for(const[u,v,hh]of[[2,2,10],[22,4,7],[6,20,5]])masonry(P,...X(u,v,h),12,10,hh,1+u*.01,{bh:5,bw:8,moss:1});pile(P,120,214,26,C.stone,2,R,14);pile(P,208,216,18,C.stone,2,R,10);vine(P,...X(36,40,h),22,R,3);
  const[x,y]=X(20,20,h);for(let i=0;i<20;i++)P.set(x-10+i,y-4+i*.3,PAL.wood[3],3);return{c:X(20,20,h),repaired}}
 const X1=ISOP(...X(-6,-6,h));masonry(P,...X(-6,-6,h),52,52,5,1,{bh:5,bw:10});
 for(const[u,v]of[[0,0],[16,0],[32,0],[0,16],[0,32]])masonry(P,...X1(u+2,v+2,5),8,8,7,2+u*.01+v*.01,{bh:4,bw:8});
 const top=X1(26,26,5);for(let a=0;a<80;a++){const tt=a/80*6.283;P.set(top[0]+Math.cos(tt)*16,top[1]+Math.sin(tt)*8,C.gold[2+(a%5===0)],3)}
 for(const[u,v]of[[4,40],[40,4]]){const[x,y]=X(u,v,h-14);for(let j=0;j<6;j++)P.set(x,y-j,C.gold[3],1.1)}
 return{c:top,repaired}}
function ballistaD(P,R,repaired){const[sx,sy]=origin(56,56,160,206);const X=ISOP(sx,sy);shadow(P,166,210,56,20,-50);
 masonry(P,sx,sy,56,56,14,0,{bh:6,bw:10,moss:1,cracks:2});const X1=ISOP(...X(0,0,14));
 if(!repaired){for(const[u,v]of[[2,2]])post(P,X1,u,v,24,1);for(const[a,b,c2]of[[[4,40],[48,30],0],[[10,52],[40,48],1]])P.line(...X1(...a,1),...X1(...b,3),PAL.wood[3+c2],2);for(let k=0;k<3;k++)P.line(...X1(8,10+k*12,1),...X1(46,6+k*14,0),PAL.wood[2],2.1);
  pile(P,114,216,20,C.stone,2,R,12);vine(P,...X(56,40,14),12,R,3);return{c:X1(28,28,0),repaired}}
 for(const[u,v]of[[2,2],[50,2],[2,50]])post(P,X1,u,v,34,1+u*.001+v*.001,PAL.wood,4);
 for(const[a,b]of[[[2,2],[50,2]],[[2,2],[2,50]]]){P.line(...X1(...a,4),...X1(...b,30),PAL.wood[2],1.5);P.line(...X1(...b,4),...X1(...a,30),PAL.wood[2],1.5)}
 post(P,X1,50,50,34,3,PAL.wood,4);
 block(P,...X1(-4,-4,34),62,62,4,4,wood(PAL.wood,{vertical:true}));const X2=ISOP(...X1(-4,-4,38));
 for(let u=0;u<=62;u+=4){const[x,y]=X2(u,62);stake(P,x,y,7,5+u*.001,u);if(u<62){const[x2,y2]=X2(62,u);stake(P,x2,y2,7,5+u*.001,u+99)}}
 for(let u=0;u<=62;u+=4){const[x,y]=X2(u,0);stake(P,x,y,7,4.5,u+40);const[x2,y2]=X2(0,u);stake(P,x2,y2,7,4.5,u+70)}
 return{c:X2(31,31,0),repaired}}
function ballistaE(P,R,repaired){const[sx,sy]=origin(110,20,160,196);const X=ISOP(sx,sy);shadow(P,166,204,80,24,-50);
 if(!repaired){masonry(P,sx,sy,40,20,26,0,{bh:6,bw:10,moss:1,cracks:2});masonry(P,...X(70,0),40,20,20,1,{bh:6,bw:10,moss:1,cracks:1});
  cylinder(P,...X(55,34),20,10,2,(x,y,n)=>rp(C.stone,.55-n*.35+(mod(y,5)===0?-.2:0),x,y),(x,y,d)=>rp(C.stone,.7-d*.2+(hash(x>>1,y,3)-.5)*.3,x,y));
  pile(P,...X(55,24),30,C.stone,3,R,16);pile(P,...X(55,50),16,C.stone,3,R,10);vine(P,...X(20,20,26),18,R,4);return{c:X(55,34,10),repaired}}
 masonry(P,sx,sy,110,20,26,0,{bh:6,bw:10,moss:1,cracks:1});for(let u=0;u<110;u+=12)masonry(P,...X(u,0,26),7,6,7,1+u*.001,{bh:4,bw:7});
 cylinder(P,...X(55,34),24,32,2,(x,y,n,hh)=>{const r=Math.floor(y/5),q=x+(r%2)*5;let v=.58-n*.4+(hash(r,q>>3,5)-.5)*.16;if(mod(y,5)===0||mod(q,10)===0)v-=.22;if(hh<10&&fbm(x/6,y/4,2)>.6)return rp(C.moss,v+.1,x,y);return rp(C.stone,v,x,y)},(x,y,d)=>rp(C.stone,.74-d*.25+(hash(x>>2,y>>1,4)-.5)*.2,x,y));
 const top=X(55,34,32);for(let a=0;a<80;a++){const tt=a/80*6.283;P.set(top[0]+Math.cos(tt)*14,top[1]+Math.sin(tt)*7,C.gold[2+(a%5===0)],3)}
 bannerDraw(P,...X(20,20,24),8,20,3);bannerDraw(P,...X(96,20,24),8,20,3);
 return{c:top,repaired}}

/* =============== CASERNES D'INDRA =============== */
// lance d'Indra : hampe, fer, ruban rouge
function lance(P,x,y,h,z){for(let i=0;i<h;i++){P.set(x,y-i,PAL.wood[4],z);P.set(x+1,y-i,PAL.wood[2],z)}
 for(let j=0;j<7;j++){const w=j<2?0:j<5?1:0;for(let i=-w;i<=w+1;i++)P.set(x+i,y-h-7+j,rp(PAL.iron,.95-j*.06-(i>0?.3:0),x+i,y-h-7+j),z+.01)}
 for(let i=-2;i<=3;i++)P.set(x+i,y-h,C.gold[2+(i<1)],z+.02);P.set(x,y-h-8,PAL.iron[5],z+.02)}
function crenels(P,X,a,b,h,z,step=8){for(let u=2;u<a-2;u+=step)block(P,...X(u,b-4,h),4,4,5,z+u*.001,stoneSh(.05));for(let v=2;v<b-4;v+=step)block(P,...X(a-4,v,h),4,4,5,z+v*.001,stoneSh(.05))}
function plaza(P,X,a,b,z,ramp=C.stone){P.poly([X(0,0),X(a,0),X(a,b),X(0,b)],(x,y)=>{const r=Math.floor((y-.5*x)/6),c=Math.floor((y+.5*x)/6);let v=.42+(hash(r,c,9)-.5)*.2+(fbm(x/9,y/6,4)-.5)*.2;if(mod(y-.5*x,6)<1||mod(y+.5*x,6)<1)v-=.15;if(fbm(x/7,y/5,3)>.68)return rp(C.moss,v+.1,x,y);return rp(ramp,v,x,y)},z)}
function sand(P,X,a,b,z){P.poly([X(0,0),X(a,0),X(a,b),X(0,b)],(x,y)=>rp(C.dirt,.6+(fbm(x/6,y/4,5)-.5)*.4,x,y),z)}
function trident(P,x,y,z){for(let j=0;j<7;j++)P.set(x,y+j,C.gold[3],z);for(const i of[-2,2])for(let j=0;j<3;j++)P.set(x+i,y+j,C.gold[2],z);for(let i=-2;i<=2;i++)P.set(x+i,y+3,C.gold[2],z)}
function warrior(g,x,y,t,face=1,pose=0){// petit disciple d'Indra animé (couche animée)
 const c=C.cloth,lift=Math.round(Math.sin(pose)*1.2);
 for(let j=0;j<4;j++){dot(g,x,y-j,PAL.iron[2]);dot(g,x+1,y-j,PAL.iron[1])}
 for(let j=4;j<9;j++){dot(g,x,y-j,c[3]);dot(g,x+1,y-j,c[2])}
 dot(g,x,y-9,'#c99a72');dot(g,x+1,y-9,'#a07656');dot(g,x,y-10,PAL.iron[4]);dot(g,x+1,y-10,PAL.iron[3]);dot(g,x+(face>0?0:1),y-11,c[4]);
 const tip=[x+face*(6+lift*2),y-7-lift*2];lineA(g,x+.5-face*2,y-5+lift,tip[0],tip[1],PAL.wood[5]);dot(g,tip[0]+face,tip[1]-(lift>0?1:0),PAL.iron[5])}

function indraA(P,R){const[sx,sy]=origin(100,64,160,178);const X=ISOP(sx,sy);shadow(P,166,186,98,30,-50);plaza(P,X,100,64,-80);
 block(P,...X(20,0),60,12,26,0,stoneSh(0,.4));crenels(P,ISOP(...X(20,0)),60,12,26,.5);
 for(const u of[0,76]){const T=ISOP(...X(u,0));block(P,...X(u,0),24,24,52,1+u*.01,stoneSh(.04,.3));crenels(P,T,24,24,52,2+u*.01,6);
  for(const h of[22,38])opening(P,T,'L',24,10,13,h,h+6,2.5+u*.01,'#0d0806',PAL.stone?C.stone[5]:C.stone[5])}
 const G=ISOP(...X(36,0));block(P,...X(36,0),28,18,40,3,stoneSh(.08));crenels(P,G,28,18,40,3.5,6);
 opening(P,G,'L',18,7,21,0,24,3.6,'#0d0806',C.stone[6]);for(let u=7;u<=21;u+=.5){const a=(u-14)/7,hh=24+Math.round(Math.sqrt(Math.max(0,1-a*a))*4);P.line(...G(u,18.01,24),...G(u,18.01,hh),'#0d0806',3.61)}
 for(let i=0;i<9;i++)P.line(...G(4+i*2.6,18.02,30),...G(4+i*2.6,18.02,36),C.stone[2],3.62);
 const[ex,ey]=G(14,18.03,33);trident(P,ex,ey-3,3.7);
 for(const u of[0,76])bannerDraw(P,...ISOP(...X(u,0))(4,24,46),8,20,3);
 for(const u of[26,74]){const[x,y]=X(u,40);brazier(P,x,y,20)}
 const[lx,ly]=X(50,46);block(P,lx-6,ly-2,12,12,6,21,stoneSh(.1));lance(P,lx,ly-4,54,22);
 return{X,G,lt:[lx,ly-62],br:[X(26,40,5),X(74,40,5)],tw:[ISOP(...X(0,0))(12,12,57),ISOP(...X(76,0))(12,12,57)]}}
function indraAAnim(g,s,t){for(const[x,y]of s.br)flame(g,x,y,t,.8,x);for(const[i,[x,y]]of s.tw.entries()){for(let k=0;k<12;k++){dot(g,x,y-k,PAL.wood[4])}flag(g,x+1,y-12,10,7,t+i)}
 const[x,y]=s.lt;flag(g,x+1,y+10,7,10,t*1.3,C.cloth);if(mod(t,3)<.25){const k=mod(t,3)*16|0;dot(g,x+1-k%3,y-1,'#fffbe0');dot(g,x,y+1,'#fffbe0')}}

function indraB(P,R){const cx=160,cy=182;shadow(P,cx+4,cy+6,96,34,-50);
 cylinder(P,cx,cy,84,10,0,(x,y,n,hh)=>{const r=Math.floor(y/5),q=x+(r%2)*6;let v=.55-n*.35+(hash(r,q>>3,6)-.5)*.16;if(mod(y,5)===0||mod(q,12)===0)v-=.22;if(hh<5&&fbm(x/6,y/4,2)>.6)return rp(C.moss,v+.1,x,y);return rp(C.stone,v,x,y)},
  (x,y,d)=>d>.78?rp(C.stone,.78-(hash(x>>2,y>>1,4)-.5)*.2,x,y):d>.72?C.stone[2]:rp(C.dirt,.62+(fbm(x/6,y/4,5)-.5)*.35-(d>.6?.12:0),x,y));
 const top=cy-10,cols=[];for(let k=0;k<8;k++){const a=k/8*Math.PI*2+Math.PI/8,x=cx+Math.cos(a)*76,y=top+Math.sin(a)*34;cols.push([x,y,Math.sin(a)])}
 cols.sort((a,b)=>a[1]-b[1]);for(const[x,y,sn]of cols){const h=sn<0?34:28,broken=hash(x|0,1,3)>.8;cylinder(P,Math.round(x),Math.round(y),4,broken?14:h,(y-top)*.1+(sn>0?40:5),(xx,yy,n)=>rp(C.stone,.7-n*.45+(mod(xx,3)===0?-.1:0),xx,yy),(xx,yy,d)=>rp(C.stone,.85-d*.3,xx,yy));if(!broken&&sn<0){const[bx,by]=[Math.round(x)-3,Math.round(y)-h-1];bannerDraw(P,bx,by+4,7,16,(y-top)*.1+6)}}
 block(P,cx-10,top-6,14,14,8,20,stoneSh(.12));lance(P,cx,top-8,58,21);
 return{c:[cx,top],lt:[cx,top-66]}}
function indraBAnim(g,s,t){const[cx,cy]=s.c;for(const k of[0,1]){const a=t*.9+k*Math.PI,x=cx+Math.cos(a)*30,y=cy+6+Math.sin(a)*12;warrior(g,Math.round(x),Math.round(y),t,Math.cos(a+Math.PI/2)>0?1:-1,t*6+k*3)}
 for(let k=0;k<4;k++){const p=mod(t*.7+k/4,1);dot(g,cx-20+k*12+p*6,cy+10-p*4,C.dirt[4])}const[x,y]=s.lt;flag(g,x+1,y+10,7,10,t*1.3)}

function indraC(P,R){const[sx,sy]=origin(104,60,160,178);const X=ISOP(sx,sy);shadow(P,166,186,100,30,-50);
 block(P,sx,sy,104,60,4,0,stoneSh(.1,.3));block(P,...X(4,4,4),96,52,4,.5,stoneSh(.15));
 const[wx,wy]=X(10,8,8),W=ISOP(wx,wy);const plaster=(f,x,y)=>rp(C.stone,(f==='T'?.7:f==='L'?.62:.4)+(fbm(x/5,y/5,12)-.5)*.14+(mod(y,7)<1?-.08:0),x,y);
 block(P,wx,wy,84,40,26,1,plaster);
 for(let u=4;u<=80;u+=10.5){if(u>34&&u<50)continue;for(let h=0;h<26;h++){const[x,y]=W(u,44,h);for(let i=-1;i<=2;i++)P.set(x+i,y+(i>0?1:0),rp(C.stone,.85-i*.18,x+i,y),1.6)}}
 for(let i=0;i<2;i++)P.line(...W(-2,44,26+i),...W(86,44,26+i),C.stone[6-i*2],1.65);
 const roofX=roof(P,wx,wy,84,44,28,22,5,2,'clay',plaster);
 opening(P,W,'L',44,36,48,0,18,1.7,'#0f0907',C.gold[2]);
 const[tx,ty]=W(42,44,40);trident(P,tx,ty-1,3);for(let i=-9;i<=9;i++){P.set(tx+i,ty+8+Math.round(i*.5),C.gold[1],3);}
 for(const u of[-1,89]){const[x,y]=X(u<0?6:96,u<0?58:58);bannerPole(P,x,y,36,30);bannerDraw(P,x+2,y-34,8,22,30.1)}
 for(const u of[30,60]){const[x,y]=X(u,60,4);brazier(P,x,y+2,31)}
 return{br:[X(30,60,9),X(60,60,9)],door:W(42,44,10)}}
function indraCAnim(g,s,t){for(const[x,y]of s.br){flame(g,x,y,t,.9,x);glowPool(g,x,y+4,10,4,t,PAL.fire[3],.25)}
 const[dx,dy]=s.door;const p=mod(t/5,1);if(p<.6){warrior(g,Math.round(dx-4+p*30),Math.round(dy+8+p*15),t,1,t*8)}}

function indraD(P,R){const cx=150,cy=176;shadow(P,cx+12,cy+10,92,28,-50);
 const[sx,sy]=origin(60,40,196,198);const X=ISOP(sx,sy);block(P,sx,sy,60,40,22,0,stoneSh(0,.4));roof(P,sx,sy,60,40,22,16,4,1,'shingle',stoneSh(0));
 opening(P,X,'L',40,22,34,0,16,.8,'#0e0806',PAL.wood[4]);
 cylinder(P,cx,cy-6,30,92,2,(x,y,n,hh)=>{const r=Math.floor(y/6),q=x+(r%2)*6;let v=.6-n*.42+(hash(r,q>>3,5)-.5)*.16;if(mod(y,6)===0||mod(q,12)===0)v-=.22;if(hh<14&&fbm(x/6,y/4,2)>.55)return rp(C.moss,v+.1,x,y);return rp(C.stone,v,x,y)},(x,y,d)=>rp(C.stone,.7-d*.2,x,y));
 for(const h of[30,58]){for(let j=0;j<8;j++)for(let i=0;i<2;i++)P.set(cx-2+i,cy-6-h-j,'#0d0806',3)}
 const top=cy-98;for(let j=0;j<=34;j++){const w=Math.round(36*(1-j/36));for(let i=-w;i<=w;i++){const v=.72-i/w*.45+(mod(i+j,4)===0?-.08:0)+(mod(j,4)===0?-.12:0);P.set(cx+i,top-j,rp(PAL.clay,v,cx+i,top-j),4)}P.set(cx-w-1,top-j,C.outline,4.1);P.set(cx+w+1,top-j,C.outline,4.1)}
 for(let i=-36;i<=36;i++){P.set(cx+i,top+1,C.outline,4.1);P.set(cx+i,top,PAL.clay[1],4.05)}
 lance(P,cx,top-34,16,5);bannerDraw(P,cx-26,cy-62,9,22,3.2);
 const[gx,gy]=[cx-4,cy+14];opening(P,ISOP(gx,gy),'L',0,-6,6,0,20,3.3,'#0d0806',PAL.wood[4]);
 for(const dx of[-22,20])brazier(P,cx+dx,cy+22,30);
 return{win:[[cx-1,cy-40],[cx-1,cy-68]],br:[[cx-22,cy+17],[cx+20,cy+17]],tip:[cx,top-58]}}
function indraDAnim(g,s,t){for(const[x,y]of s.br)flame(g,x,y,t,.8,x);for(const[i,[x,y]]of s.win.entries()){const f=.5+.5*Math.sin(t*3+i*2);for(let j=0;j<6;j++)dot(g,x,y-j,rp(PAL.fire,.4+f*.4,x,y-j))}
 const[x,y]=s.tip;flag(g,x+2,y+6,12,8,t)}

function indraE(P,R){const[sx,sy]=origin(104,100,160,178);const X=ISOP(sx,sy);shadow(P,166,186,100,32,-50);
 block(P,sx,sy,104,100,4,-1,stoneSh(.05,.5));sand(P,ISOP(...X(0,0,4)),104,100,-.5);
 const tent=(u,v,a,b)=>{const[x,y]=X(u,v,4);const T=ISOP(x,y);block(P,x,y,a,b,4,u+v,(f,xx,yy)=>rp(C.cloth,f==='L'?.55:.35,xx,yy),{edges:false});roof(P,x,y,a,b,4,20,3,u+v+.5,'cloth',(f,xx,yy)=>rp(C.cloth,.4,xx,yy));opening(P,T,'L',b,a/2-4,a/2+4,0,10,u+v+.6,'#170508',C.gold[2]);return T};
 tent(6,6,34,24);tent(62,6,34,24);
 const[rx,ry]=X(12,60,4);for(let k=0;k<6;k++){lance(P,rx+k*4,ry-k*2,26,40+k*.01)}for(let i=-2;i<26;i++){P.set(rx+i,ry-6-i*.5+2,PAL.wood[2],40.1);P.set(rx+i,ry-18-i*.5+2,PAL.wood[2],40.1)}
 const[gx,gy]=X(80,62,4);for(const d of[-12,12])for(let j=0;j<30;j++)P.set(gx+d,gy-j,PAL.wood[3],41);for(let i=-13;i<=13;i++){P.set(gx+i,gy-30,PAL.wood[4],41.1);P.set(gx+i,gy-31,PAL.wood[2],41.1)}
 const[mx,my]=X(46,86,4);for(let i=0;i<20;i++)P.set(mx,my-i,PAL.wood[3],50);for(let i=-6;i<=6;i++)P.set(mx+i,my-14,PAL.wood[4],50.1);for(let j=0;j<10;j++)for(let i=-3;i<=3;i++)P.set(mx+i,my-24+j,rp(PAL.straw,.7-i*.08,mx+i,my-24+j),50.2);
 const[px,py]=X(94,94,4);bannerPole(P,px,py,44,60);
 return{gong:[gx,gy-17],pole:[px,py-44],dummy:[mx,my],sp:X(60,70,4)}}
function indraEAnim(g,s,t){const[gx,gy]=s.gong,p=mod(t,2.4),sh=p<.6?Math.sin(p*60)*(.6-p)*2:0;
 for(let j=-8;j<=8;j++)for(let i=-8;i<=8;i++){const d=Math.hypot(i,j);if(d<=8)dot(g,gx+i+sh,gy+j,d>7?C.gold[0]:rp(C.gold,.95-d*.06-(i+j)*.03,gx+i,gy+j))}
 if(p<.8)for(const r of[11,15]){const rr=r+p*10;for(let a=0;a<40;a++){const an=a/40*6.28;if(hash(a,r,1)>.5)dot(g,gx+Math.cos(an)*rr,gy+Math.sin(an)*rr*.9,C.gold[2])}}
 const[x,y]=s.pole;flag(g,x+2,y,12,16,t);const[sx,sy]=s.sp;const a=Math.sin(t*2.2);warrior(g,Math.round(sx-8+a*2),Math.round(sy),t,1,t*7);warrior(g,Math.round(sx+8-a*2),Math.round(sy-1),t,-1,t*7+2);
 const[mx,my]=s.dummy;if(mod(t,1.4)<.12)for(let k=0;k<4;k++)dot(g,mx+4+k,my-20+k,PAL.straw[3])}

/* ===== Anneau d'Istakhr : base détaillée + 5 animations ===== */
function ringB(P,R){const cx=160,cy=184,RX=84,RY=38;shadow(P,cx+4,cy+6,98,36,-50);
 cylinder(P,cx,cy,RX,12,0,(x,y,n,hh)=>{const r=Math.floor(y/5),q=x+(r%2)*6;let v=.55-n*.35+(hash(r,q>>3,6)-.5)*.16;if(mod(y,5)===0||mod(q,12)===0)v-=.22;if(hash(q>>3,r,8)>.93)v-=.3;if(hh<6&&fbm(x/6,y/4,2)>.58)return rp(C.moss,v+.1,x,y);return rp(C.stone,v,x,y)},
  (x,y,d,i,j)=>{if(d>.8)return rp(C.stone,.8-(hash(x>>2,y>>1,4)-.5)*.22-(mod(Math.atan2(j,i)*24/Math.PI,1)<.12?.2:0),x,y);if(d>.74)return C.stone[2];
   const rk=mod(Math.sqrt(d)*40,3)<.6?-.1:0;return rp(C.dirt,.64+(fbm(x/6,y/4,5)-.5)*.3+rk-(d>.6?.12:0),x,y)});
 const top=cy-12;
 // marches d'entrée à l'avant
 for(let s=0;s<3;s++){const w=18-s*2;for(let i=-w;i<=w;i++)for(let j=0;j<3;j++)P.set(cx+i,cy+RY-2-s*4+j+(-12+12),rp(C.stone,.75-j*.15-s*.05,cx+i,cy+RY-s*4+j),60+s)}
 // dalle centrale ronde et monument
 for(let j=-8;j<=8;j++)for(let i=-18;i<=18;i++){const d=(i/18)**2+(j/8)**2;if(d<=1)P.set(cx+i,top+j,d>.8?C.stone[2]:rp(C.stone,.68-(mod(i+j*2,6)===0?.12:0),cx+i,top+j),10)}
 for(let a=0;a<90;a++){const t=a/90*6.283;P.set(cx+Math.cos(t)*14,top+Math.sin(t)*6,C.gold[1+(a%6===0)],10.5)}
 block(P,cx-10,top-6,14,14,10,20,stoneSh(.12));for(let i=-6;i<=6;i++)P.set(cx+i,top-11+Math.round(Math.abs(i)*.5),C.gold[2],20.5);lance(P,cx,top-10,58,21);
 // râteliers et objets
 for(const[ox,oy,z]of[[cx-56,top-6,8],[cx+44,top-8,8]]){for(let k=0;k<5;k++){for(let i=0;i<20;i++)P.set(ox+k*3,oy-i,PAL.wood[4],z);P.set(ox+k*3,oy-21,PAL.iron[5],z+.1);P.set(ox+k*3,oy-22,PAL.iron[4],z+.1)}for(let i=-1;i<15;i++){P.set(ox+i,oy-5,PAL.wood[2],z+.2);P.set(ox+i,oy-15,PAL.wood[2],z+.2)}}
 for(const[x,y]of[[cx-30,top+20],[cx+34,top+16]]){for(let j=-4;j<=4;j++)for(let i=-4;i<=4;i++){const d=Math.hypot(i,j);if(d<=4)P.set(x+i,y+j-3,d>3?PAL.iron[3]:d<1.2?C.gold[3]:rp(C.cloth,.7-(i+j)*.05,x+i,y+j),30)}}
 pile(P,cx+60,cy+30,8,C.pebble,70,R,6);pile(P,cx-74,cy+20,6,C.pebble,70,R,5);
 const cols=[];for(let k=0;k<8;k++){const a=k/8*Math.PI*2+Math.PI/8;cols.push([cx+Math.cos(a)*(RX-8),top+Math.sin(a)*(RY-4),Math.sin(a),k])}
 cols.sort((a,b)=>a[1]-b[1]);const caps=[];
 for(const[x,y,sn,k]of cols){const X0=Math.round(x),Y0=Math.round(y),broken=k===6,h=broken?14:(sn<0?36:30),z=(y-top)*.1+(sn>0?40:5);
  cylinder(P,X0,Y0,5,h,z,(xx,yy,n)=>rp(C.stone,.72-n*.45+(mod(xx-X0,3)===0?-.12:0),xx,yy),(xx,yy,d)=>rp(C.stone,.88-d*.3,xx,yy));
  for(let i=-6;i<=6;i++){P.set(X0+i,Y0-h-1,C.stone[6],z+.1);P.set(X0+i,Y0-h,C.stone[3],z+.1);P.set(X0+i,Y0-1,C.stone[3],z+.1)}
  if(broken){for(let n=0;n<10;n++){P.set(X0+8+n%4*2,Y0+2-(n>>2),C.stone[4+(n%2)],z+.2)}continue}
  if(k%2===0&&sn<0)bannerDraw(P,X0-3,Y0-h+6,7,18,z+.3);caps.push([X0,Y0-h-2,sn])}
 return{c:[cx,top],lt:[cx,top-76],caps,RX,RY,cy}}
function big(g,x,y,fn){g.save();g.translate(Math.round(x),Math.round(y));g.scale(2,2);fn();g.restore()}
const warrior2=(g,x,y,t,f,p)=>big(g,x,y,()=>warrior(g,0,0,t,f,p));const horse2=(g,x,y,t,f)=>big(g,x,y,()=>horse(g,0,0,t,f));
const ringPos=(s,a,r=1)=>[s.c[0]+Math.cos(a)*48*r,s.c[1]+10+Math.sin(a)*20*r];
function ringBase(g,s,t){const[x,y]=s.lt;flag(g,x+1,y+10,7,10,t*1.3)}
// 1 Duel
function ringAnim1(g,s,t){ringBase(g,s,t);const ph=t*1.2;for(const k of[0,1]){const a=ph*.6+k*Math.PI,[x,y]=ringPos(s,a,.7);warrior2(g,Math.round(x),Math.round(y),t,k?-1:1,t*7+k*2.5)}
 const[a,b]=[ringPos(s,ph*.6,.7),ringPos(s,ph*.6+Math.PI,.7)];if(mod(t,.9)<.12){const mx=(a[0]+b[0])/2,my=(a[1]+b[1])/2-8;for(let k=0;k<6;k++)dot(g,mx+Math.cos(k)*3*(1+mod(t,.9)*20),my+Math.sin(k)*2*(1+mod(t,.9)*20),k%2?'#fffbe0':C.gold[3])}
 for(let k=0;k<5;k++){const p=mod(t*.8+k/5,1);dot(g,s.c[0]-24+k*12+p*4,s.c[1]+20-p*5,C.dirt[5])}}
// 2 Formation
function ringAnim2(g,s,t){ringBase(g,s,t);const beat=mod(t,1.2),thr=beat<.35?Math.sin(beat/.35*Math.PI)*1.6:0;
 for(let r=0;r<2;r++)for(let i=0;i<4;i++){const x=s.c[0]-34+i*14+r*7,y=s.c[1]+14+r*10;warrior2(g,x,y,t,1,thr*1.6-0.4)}
 const ix=s.c[0]+44,iy=s.c[1]+6;warrior2(g,ix,iy,t,-1,0);if(beat<.25){g.fillStyle='#e8d8a8';g.font='7px monospace';g.fillText('HA!',ix-6,iy-14)}}
// 3 Cavalier d'Istakhr
function horse(g,x,y,t,face){const leg=Math.sin(t*12),c=['#2a1a10','#4a3020','#6a4630','#8a6040'];
 for(let i=-6;i<=6;i++)for(let j=0;j<4;j++)dot(g,x+i,y-7-j,c[j===0?3:j<2?2:1]);for(let j=0;j<5;j++){dot(g,x+face*(7+(j>>1)),y-10-j,c[2]);dot(g,x+face*(8+(j>>1)),y-10-j,c[1])}
 dot(g,x+face*10,y-15,c[0]);dot(g,x+face*11,y-14,c[1]);for(let j=0;j<4;j++)dot(g,x-face*(7+j*.3),y-9+j,'#1a100a');
 for(const[o,p]of[[-5,leg],[-3,-leg],[4,-leg],[6,leg]])for(let j=0;j<4;j++)dot(g,x+o+Math.round(p*j*.4),y-3+j,c[1]);
 for(let j=0;j<5;j++){dot(g,x,y-11-j,C.cloth[3]);dot(g,x+1,y-11-j,C.cloth[2])}dot(g,x,y-16,'#c99a72');dot(g,x,y-17,PAL.iron[4]);dot(g,x+1,y-17,PAL.iron[3]);lineA(g,x-face*4,y-14,x+face*12,y-19,PAL.wood[5]);dot(g,x+face*13,y-19,PAL.iron[5]);
 for(let i=0;i<4;i++)dot(g,x+face*(9-i),y-19+Math.round(Math.sin(t*10+i)),C.cloth[4])}
function ringAnim3(g,s,t){ringBase(g,s,t);const a=t*.8,[x,y]=ringPos(s,a,1.05),f=Math.cos(a+Math.PI/2)>0?1:-1;
 for(let k=1;k<7;k++){const[px,py]=ringPos(s,a-k*.09,1.05);if(hash(k,Math.floor(t*10),2)>.4)dot(g,px+(hash(k,3,1)-.5)*4,py-k*.6,C.dirt[4+(k%2)])}
 const behind=Math.sin(a)<0;horse2(g,Math.round(x),Math.round(y),t,f);const[tx,ty]=[s.c[0]+32,s.c[1]+4];for(let i=0;i<6;i++)dot(g,tx,ty-i,PAL.wood[4]);for(let j=-2;j<=2;j++)for(let i=-2;i<=2;i++)if(i*i+j*j<6)dot(g,tx+i,ty-8+j,(i*i+j*j<2)?C.cloth[4]:PAL.straw[3])}
// 4 Veillée
function ringAnim4(g,s,t){g.fillStyle='rgba(8,10,30,.45)';g.fillRect(0,0,320,240);for(const[x,y]of s.caps){glowPool(g,x,y+4,14,6,t,PAL.fire[3],.35);flame(g,x,y,t,.75,x)}
 const[cx,cy]=s.c;glowPool(g,cx,cy+2,22,9,t,PAL.fire[4],.3);for(let k=0;k<3;k++){const a=k/3*6.28+.5,[x,y]=ringPos(s,a,.45);warrior2(g,Math.round(x),Math.round(y),t,Math.cos(a)>0?-1:1,0)}
 for(let k=0;k<10;k++){const p=mod(t*.5+k/10,1),[x,y]=s.caps[k%s.caps.length];dot(g,x+Math.sin(t*3+k)*3,y-6-p*24,p<.5?PAL.fire[5]:PAL.fire[3])}ringBase(g,s,t)}
// 5 Bénédiction de la Lance
function ringAnim5(g,s,t){const[cx,cy]=s.c,[lx,ly]=s.lt,p=mod(t/6,1),pulse=.5+.5*Math.sin(t*3);
 for(let k=0;k<6;k++){const a=k/6*6.283+.3,[x,y]=ringPos(s,a,.75);const kneel=p>.15&&p<.85;if(kneel){for(let j=0;j<5;j++){g.fillStyle=C.cloth[3];g.fillRect(x,y-j*2,4,2)}g.fillStyle='#c99a72';g.fillRect(x,y-12,4,2);g.fillStyle=PAL.iron[4];g.fillRect(x,y-14,4,2)}else warrior2(g,Math.round(x),Math.round(y),t,Math.cos(a)>0?-1:1,0)}
 if(p>.2&&p<.85){const k=Math.min(1,(p-.2)*5,(.85-p)*5);for(let i=0;i<46;i++){const a=t*2.4+i*.4,h=i*1.3,r=(10-i*.15)*k;dot(g,lx+Math.cos(a)*r,cy-10-h+Math.sin(a)*r*.4,i%2?C.gold[3]:C.cloth[4])}
  glowPool(g,lx,ly+6,8,8,t,C.gold[3],.5*k*pulse);for(let a=0;a<36;a++){const an=a/36*6.283;if(hash(a,Math.floor(t*6),2)>.5)dot(g,cx+Math.cos(an)*16,cy+Math.sin(an)*7,C.gold[3])}}
 ringBase(g,s,t)}

/* ===== Duel : 5 déclinaisons finales ===== */
const ease=x=>x<.5?2*x*x:1-(-2*x+2)**2/2;
function duelState(t,P=3){const p=mod(t,P)/P;let d,clash=-1;if(p<.35)d=26;else if(p<.47){d=26-ease((p-.35)/.12)*20}else if(p<.6){d=6+ease((p-.47)/.13)*16;clash=(p-.47)/.13}else d=22+ease((p-.6)/.4)*4;return{d,clash,p,lunge:p>.35&&p<.5}}
function sparks(g,x,y,k,col=C.gold[3]){for(let i=0;i<10;i++){const a=i*.63+k,r=2+k*14;dot(g,x+Math.cos(a)*r,y+Math.sin(a)*r*.6-k*4,i%3?col:'#fffbe0')}}
function fighter(g,x,y,t,f,pose,arm=C.cloth,champ=false){big(g,x,y,()=>{const c=champ?C.gold:arm;
 for(let j=0;j<4;j++){dot(g,0,-j,PAL.iron[2]);dot(g,1,-j,PAL.iron[1])}for(let j=4;j<9;j++){dot(g,0,-j,c[3]);dot(g,1,-j,c[2])}
 dot(g,0,-9,'#c99a72');dot(g,1,-9,'#a07656');dot(g,0,-10,PAL.iron[4]);dot(g,1,-10,PAL.iron[3]);dot(g,f>0?0:1,-11,champ?C.cloth[4]:c[4]);
 const reach=pose,tip=[f*(5+reach*3),-6-(reach<.2?2:0)];lineA(g,.5-f*2,-5,tip[0],tip[1],PAL.wood[5]);dot(g,tip[0]+f,tip[1],PAL.iron[5]);if(champ)dot(g,-f,-6,C.gold[2])})}
function fallen(g,x,y){g.fillStyle=PAL.iron[2];g.fillRect(x-8,y-2,6,3);g.fillStyle=C.cloth[3];g.fillRect(x-2,y-2,10,3);g.fillStyle='#c99a72';g.fillRect(x+8,y-2,2,3);lineA(g,x-6,y+3,x+12,y+1,PAL.wood[5])}
function spectator(g,x,y,t,cheer,k){big(g,x,y,()=>{for(let j=0;j<5;j++){dot(g,0,-j,C.cloth[2+(j>2)]);dot(g,1,-j,C.cloth[1])}dot(g,0,-5,'#c99a72');dot(g,0,-6,PAL.iron[3]);if(cheer){const u=Math.sin(t*10+k)>0;dot(g,-1,-5-u,'#c99a72');dot(g,2,-5-u,'#c99a72')}})}
function duelCore(g,s,t,o={}){const[cx,cy0]=s.c,cy=cy0+20,st=duelState(t,o.period||3),a=Math.sin(t*.25)*.5,ux=Math.cos(a),uy=Math.sin(a)*.45,dd=st.d*.7;
 const A=[cx-ux*dd,cy-uy*dd],B=[cx+ux*dd,cy+uy*dd];const fa=ux>0?1:-1;const pose=st.lunge?1:st.clash>=0?.5*(1-st.clash):0;
 const order=A[1]<B[1]?[[A,fa,0],[B,-fa,1]]:[[B,-fa,1],[A,fa,0]];
 for(let k=0;k<4;k++){const p=mod(t*.9+k/4,1);dot(g,cx-14+k*9+Math.sin(k+t)*3,cy+6-p*6,C.dirt[5])}
 for(const[[x,y],f,i]of order){if(o.fallen&&i===1&&o.fallen(st)){fallen(g,Math.round(x),Math.round(y));continue}fighter(g,Math.round(x),Math.round(y),t,f,pose,C.cloth,o.champ&&i===1)}
 if(st.clash>=0&&st.clash<.6){sparks(g,cx,cy-12,st.clash,o.spark);if(st.clash<.15){g.fillStyle='#fffbe0';g.fillRect(cx-1,cy-13,3,3)}}
 return st}
function duel1(g,s,t){ringBase(g,s,t);duelCore(g,s,t)}
function duel2(g,s,t){ringBase(g,s,t);const st=duelCore(g,s,t);const[cx,cy]=s.c;
 fighter(g,cx+50,cy+22,t,-1,0,C.gold);const cheer=st.clash>=0&&st.clash<.8;
 for(let k=0;k<4;k++){const a=Math.PI*.15+k*.28,x=cx+Math.cos(a)*-70,y=cy+18+Math.sin(a)*-28+k*4;spectator(g,Math.round(cx-66+k*10),Math.round(cy+30+k*3),t,cheer,k)}
 if(cheer){g.fillStyle='#e8d8a8';g.font='7px monospace';g.fillText('INDRA !',cx-78,cy+8)}}
function duel3(g,s,t){ringBase(g,s,t);const P=6,p=mod(t,P)/P;const st=duelCore(g,s,t,{period:2,fallen:()=>p>.66&&p<.92});
 const[cx,cy]=s.c;if(p>.66&&p<.7)sparks(g,cx+12,cy+6,(p-.66)*20,PAL.dirt?C.dirt[5]:C.dirt[5]);
 if(p>.84&&p<.92){g.fillStyle='#e8d8a8';g.font='7px monospace';g.fillText('Relève-toi.',cx-20,cy-30)}}
function duel4(g,s,t){ringBase(g,s,t);const st=duelCore(g,s,t,{champ:true,spark:C.gold[3]});const[cx,cy]=s.c;
 for(const[x,y]of s.caps){for(let i=0;i<5;i++)dot(g,x-2+i,y-2-Math.round(Math.sin(t*6+x+i)),C.cloth[4])}
 if(st.clash>=0&&st.clash<.5)for(let a=0;a<40;a++){const an=a/40*6.28,r=10+st.clash*40;if(hash(a,3,2)>.4)dot(g,cx+Math.cos(an)*r,cy+14+Math.sin(an)*r*.4,C.dirt[5])}}
function duel5(g,s,t){g.fillStyle='rgba(8,10,30,.5)';g.fillRect(0,0,320,240);for(const[x,y]of s.caps){glowPool(g,x,y+4,14,6,t,PAL.fire[3],.35);flame(g,x,y,t,.75,x)}
 const[cx,cy]=s.c;glowPool(g,cx,cy+14,30,12,t,PAL.fire[3],.22);const st=duelCore(g,s,t,{spark:PAL.fire[5]});
 if(st.clash>=0&&st.clash<.3)glowPool(g,cx,cy-12,14,8,t,'#fffbe0',.5*(1-st.clash*3));ringBase(g,s,t)}

/* ---------- catalogue ---------- */
const sets=[
 {id:'scierie',title:'Scierie',lede:'Bois brut des Exilés : du bardage, des bardeaux, une matière qui contraste avec la pierre tyrienne du temple.',items:[
  {name:'A · Le Moulin du bief',desc:'Socle de pierre récupéré, atelier en bardage, roue à aubes qui tourne dans un canal. Grumes empilées, planches séchées, sciure qui s’échappe de la porte.',seed:11,draw:sawmillA,anim:sawmillAnim},
  {name:'B · Le Chantier de la souche',desc:'Un appentis de chaume adossé à une souche géante. Deux scieurs de long invisibles actionnent la scie : silhouette basse et organique, très « camp de survie ».',seed:12,draw:sawmillB,anim:sawmillBAnim},
  {name:'C · La Halle sur pilotis',desc:'Atelier surélevé sur pieux, à l’abri des crues de la jungle. Les grumes sèchent dessous, une rampe monte au plancher, la sciure tombe entre les lattes.',seed:13,draw:sawmillC,anim:sawmillCAnim},
  {name:'D · L’Atelier dans la ruine',desc:'Deux murs tyriens encore debout servent d’appui à un toit de bardeaux. Une scie circulaire tourne sur l’établi ; le reste des murs gît au sol.',seed:14,draw:sawmillD,anim:sawmillDAnim},
  {name:'E · Le Portique des grumes',desc:'Deux portiques en A et une poutre : une grume suspendue va et vient au-dessus de la fosse de sciage. Lecture « chantier » immédiate.',seed:15,draw:sawmillE,anim:sawmillEAnim}]},
 {id:'fonderie',title:'Puits de fonderie',lede:'Le « puits » au sens propre : un ancien puits tyrien rouvert, dont la chaleur monte du sol. Lueur orange tramée, pas de halo flou.',items:[
  {name:'A · Le Puits rouvert',desc:'Margelle tyrienne moussue, gueule incandescente, chevalement en bois et seau de minerai qui monte et descend. Petite forge à cheminée sur le côté.',seed:21,draw:foundryA,anim:foundryAAnim},
  {name:'B · Le Haut-fourneau',desc:'Tronc de pyramide en pierre sèche, gueule en arc, soufflet de cuir qui pompe. Auvent de bardeaux, lingots empilés, tas de laitier.',seed:22,draw:foundryB,anim:foundryBAnim},
  {name:'C · La Fosse aux creusets',desc:'Une fosse de braises encadrée de pierre, trois creusets qui bouillonnent, un appentis de tuiles. Le puits devient un foyer à ciel ouvert.',seed:23,draw:foundryC,anim:foundryCAnim},
  {name:'D · La Cheminée de brique',desc:'Une haute cheminée cerclée de fer domine un atelier de pierre aux fenêtres rougeoyantes. Silhouette repérable de loin.',seed:24,draw:foundryD,anim:foundryDAnim},
  {name:'E · La Forge sous l’arche',desc:'Un foyer installé sous une arche tyrienne encore debout. Coups de marteau sur l’enclume, bac de trempe qui fume.',seed:25,draw:foundryE,anim:foundryEAnim}]},
 {id:'temple',title:'Temple',lede:'Même pierre, mêmes colonnes cannelées et bannières que le Sanctum : le temple construit par les Exilés doit sembler en être un fragment.',items:[
  {name:'A · L’Autel des Exilés',desc:'Un petit sanctuaire à quatre colonnes (une brisée), linteau moussu, bannières pourpres. Sur l’autel, une flamme violette fait écho à l’Ancre.',seed:31,draw:templeA,anim:templeAAnim},
  {name:'B · La Stèle de l’Ancre',desc:'Obélisque à pyramidion doré au centre d’un dallage circulaire et d’un cercle de menhirs. Les runes s’allument une à une, un éclat de l’Ancre flotte au sommet.',seed:32,draw:templeB,anim:templeBAnim},
  {name:'C · Le Cercle des colonnes',desc:'Six colonnes cannelées sur un dallage rond, l’une brisée. Au centre, une réplique de l’Ancre tourne lentement au-dessus de son socle.',seed:33,draw:templeC,anim:templeCAnim},
  {name:'D · La Porte du Sanctum',desc:'Deux piliers, un linteau à fronton et le sceau doré. Entre les piliers, un voile violet ondule comme un passage vers l’Ancre.',seed:34,draw:templeD,anim:templeDAnim},
  {name:'E · La Pyramide à gradins',desc:'Quatre gradins de pierre, un escalier frontal, un brasier violet au sommet. Le plus monumental, lisible même dézoomé.',seed:35,draw:templeE,anim:templeEAnim}]},
 {id:'caserne',title:'Caserne',lede:'Bâtiment militaire de colons : bois, chaume, rouge des bannières. Lecture immédiate « on forme des soldats ici ».',items:[
  {name:'A · Le Fortin',desc:'Palissade de pieux taillés, porte encadrée de torches, tour de guet au chaume pointu. À l’intérieur : une baraque et un râtelier.',seed:41,draw:barracksA,anim:barracksAAnim},
  {name:'B · La Longue maison',desc:'Soubassement de pierre, colombage, long toit de chaume qui fume. Bouclier pendu, râtelier de lances, mannequin de paille dans la cour.',seed:42,draw:barracksB,anim:barracksBAnim},
  {name:'C · Le Camp de tentes',desc:'Une grande tente pourpre de commandement, deux tentes de toile, un feu de camp et des bancs. Le plus « exilé », le moins coûteux.',seed:43,draw:barracksC,anim:barracksCAnim},
  {name:'D · Le Donjon',desc:'Tour carrée en pierre tyrienne coiffée d’un hourd de bois et d’un toit de bardeaux, avec une annexe de chaume. Meurtrières et torches.',seed:44,draw:barracksD,anim:barracksDAnim},
  {name:'E · La Cour d’armes',desc:'Baraquements en L autour d’une cour de sable fermée de pieux : cibles, mannequins, flèches qui partent vers la butte.',seed:45,draw:barracksE,anim:barracksEAnim}]},
 {id:'balistes',title:'Balistes · Garde tyrienne',lede:'Ruine au départ, réparée par l’Ingénieur. L’arme est calculée en 3D iso : elle pivote sur 360° (plus seulement 8 directions), tend la corde et décoche.',items:[
  {name:'A · La Tour de guet ronde',desc:'Ruine : tour éventrée, créneaux tombés, bois brisé, étincelles d’Aether. Réparée : tour rehaussée, merlons arrière, scorpion de bois et fer sur pivot de laiton.',seed:51,pair:true,draw:(P,R,r)=>ballistaA(P,R,r),anim:(g,s,t)=>ballistaAnim(g,s,t,0)},
  {name:'B · Le Bastion à colonne',desc:'Ruine : estrade fendue, colonne brisée, arme effondrée. Réparée : estrade relevée, colonne et bannière, anneau de rotation en laiton visible.',seed:52,pair:true,draw:(P,R,r)=>ballistaB(P,R,r),anim:(g,s,t)=>ballistaAnim(g,s,t,1)},
  {name:'C · Le Pylône',desc:'Ruine : pilier carré fendu, sommet effondré, failles d’Aether. Réparé : pylône rehaussé, plate-forme à merlons, anneau doré.',seed:53,pair:true,draw:(P,R,r)=>ballistaC(P,R,r),anim:(g,s,t)=>ballistaAnim(g,s,t,1)},
  {name:'D · Le Nid de bois',desc:'Réparation « à la manière des Exilés » : sur le socle tyrien, quatre poteaux contreventés portent une plate-forme bordée de pieux.',seed:54,pair:true,draw:(P,R,r)=>ballistaD(P,R,r),anim:(g,s,t)=>ballistaAnim(g,s,t,1)},
  {name:'E · Le Rempart',desc:'Ruine : mur brisé en deux, tour écroulée. Réparé : courtine crénelée, tour ronde en saillie, bannières : la défense devient un morceau de muraille.',seed:55,pair:true,draw:(P,R,r)=>ballistaE(P,R,r),anim:(g,s,t)=>ballistaAnim(g,s,t,1)}]},
 {id:'indra',title:'Casernes d’Indra',lede:'Les disciples d’Indra, ordre de combattants d’Istakhr, s’allient aux Exilés. Pierre tyrienne, bannières rouges au trident, la Lance d’Indra comme emblème.',items:[
  {name:'A · La Porte de la Lance',desc:'Deux tours crénelées et une porterie en arc, le trident doré au-dessus de l’entrée. Devant, la Lance d’Indra se dresse sur son socle entre deux braseros.',seed:61,draw:indraA,anim:indraAAnim},
  {name:'B · L’Anneau d’Istakhr',desc:'Une arène annulaire, en écho aux cités en anneaux d’Istakhr : colonnes, bannières et sable. Deux disciples s’entraînent à la lance autour du monument central.',seed:62,draw:indraB,anim:indraBAnim},
  {name:'C · La Salle des Serments',desc:'Une salle à colonnade sur un double soubassement, au toit de tuiles rouges. Les recrues prêtent serment sous le trident, puis sortent entre les braseros.',seed:63,draw:indraC,anim:indraCAnim},
  {name:'D · La Tour du Veilleur',desc:'Une haute tour ronde au toit conique, hommage au guerrier géant qui veille sur l’anneau intérieur. Une annexe de bardeaux abrite la chambrée. Silhouette repérable de loin.',seed:64,draw:indraD,anim:indraDAnim},
  {name:'E · Le Camp des Disciples',desc:'Une plate-forme de pierre couverte de sable : tentes rouges, râtelier de lances, gong de bronze qui rythme l’exercice, duel d’entraînement et mannequin.',seed:65,draw:indraE,anim:indraEAnim}]},
 {id:'anneau',title:'Anneau d’Istakhr · animations',lede:'Base enrichie : marches d’entrée, dalle centrale cerclée d’or, râteliers, boucliers, colonne effondrée, sable ratissé en cercles, joints et mousse. Cinq façons de faire vivre le bâtiment.',items:[
  {name:'1 · Le Duel',desc:'Deux disciples tournent l’un autour de l’autre à la lance. À chaque passe, les fers se croisent en gerbe d’étincelles et la poussière se soulève.',seed:71,draw:ringB,anim:ringAnim1},
  {name:'2 · La Formation',desc:'Huit recrues sur deux rangs portent la lance en rythme. Un instructeur leur fait face et donne la cadence : « HA ! ».',seed:71,draw:ringB,anim:ringAnim2},
  {name:'3 · Le Cavalier d’Istakhr',desc:'Istakhr, cité du cheval : un cavalier fait le tour de la piste au galop, la lance pointée, en soulevant le sable. Une cible de paille attend près du monument.',seed:71,draw:ringB,anim:ringAnim3},
  {name:'4 · La Veillée',desc:'Variante nocturne : les chapiteaux deviennent des braseros, des braises montent vers le ciel et trois sentinelles montent la garde autour de la Lance.',seed:71,draw:ringB,anim:ringAnim4},
  {name:'5 · La Bénédiction de la Lance',desc:'Les disciples s’agenouillent en cercle. Des rubans d’or et de pourpre s’enroulent autour de la Lance, qui s’illumine, puis ils se relèvent. Le cycle dure 6 s.',seed:71,draw:ringB,anim:ringAnim5}]},
 {id:'duel',title:'Le Duel · propositions finales',lede:'Cycle commun : les duellistes se jaugent en tournant, chargent, croisent le fer en gerbe d’étincelles, rompent puis recommencent. L’axe du duel pivote lentement autour de la Lance.',items:[
  {name:'1A · Le Duel pur',desc:'Lecture la plus nette : deux disciples face à face, charge, choc lumineux, recul. Rien d’autre ne bouge que la poussière et la bannière.',seed:71,draw:ringB,anim:duel1},
  {name:'1B · Sous l’œil du maître',desc:'Un maître d’armes en tunique dorée observe le duel. Quatre recrues assises sur le muret lèvent les bras à chaque choc : « INDRA ! ».',seed:71,draw:ringB,anim:duel2},
  {name:'1C · Les trois passes',desc:'Le récit en 6 s : deux passes égales, la troisième envoie un disciple au sol dans un nuage de sable. Le vainqueur l’aide à se relever (« Relève-toi. »), puis le cycle reprend.',seed:71,draw:ringB,anim:duel3},
  {name:'1D · Le Champion d’Indra',desc:'Un champion en armure dorée affronte un disciple. Chaque choc projette une onde de poussière, et les fanions rouges flottent sur les colonnes.',seed:71,draw:ringB,anim:duel4},
  {name:'1E · Le Duel de la Veillée',desc:'De nuit, à la lueur des braseros perchés sur les colonnes : chaque choc éclaire brièvement l’arène d’un flash blanc et projette des étincelles de feu.',seed:71,draw:ringB,anim:duel5}]},
];
/* ---------- intégration en jeu ---------- */
// Px transparent : les ombres deviennent un noir translucide au lieu d'assombrir l'herbe.
class TPx extends Px{constructor(w,h){super(w,h,true)}
 dark(x,y,k,z){x=Math.round(x);y=Math.round(y);if(x<0||y<0||x>=this.w||y>=this.h)return;const i=y*this.w+x;if(z<this.z[i])return;const o=i*4;
  if(this.d.data[o+3]===0)this.d.data[o+3]=Math.round((1-k)*230);else for(let c=0;c<3;c++)this.d.data[o+c]*=k}}
// Variantes retenues : point d'ancrage au sol (pixels natifs) qui tombe sur la position du bâtiment.
const PICKS={
 sawmill:{set:'scierie',i:1,anchor:[166,176]},
 foundry:{set:'fonderie',i:1,anchor:[152,174]},
 temple:{set:'temple',i:1,anchor:[160,180]},
 barracks:{set:'duel',i:1,anchor:[160,186]},
 ballista:{set:'balistes',i:0,anchor:[160,196]},
};
// sprites externes (temples de la charte, voir da-planches.js) : fn() → {img,anchor}
const EXTRA={};function register(kind,fn){EXTRA[kind]=fn;delete cache[kind]}
const cache={},scratch=document.createElement('canvas');scratch.width=W;scratch.height=H;const sg=scratch.getContext('2d');
function sprite(kind,variant){const key=kind+(variant===undefined?'':':'+variant);if(cache[key])return cache[key];
 if(EXTRA[kind]){const ex=EXTRA[kind](),d=ex.img.getContext('2d').getImageData(0,0,W,H).data,alpha=new Uint8Array(W*H);let top=H,bottom=0;for(let i=0;i<W*H;i++){alpha[i]=d[i*4+3];if(alpha[i]>200){const y=(i/W)|0;top=Math.min(top,y);bottom=Math.max(bottom,y)}}
  return cache[key]={img:ex.img,s:null,item:{anim(){}},anchor:ex.anchor,top,bottom,alpha}}const pk=PICKS[kind],item=sets.find(s=>s.id===pk.set).items[pk.i];
 const P=new TPx(W,H),s=item.draw(P,rng(item.seed),variant);P.flush();
 let top=H,bottom=0;const d=P.d.data;for(let y=0;y<H;y++)for(let x=0;x<W;x++)if(d[(y*W+x)*4+3]>200){top=Math.min(top,y);bottom=Math.max(bottom,y);break}
 const alpha=new Uint8Array(W*H);for(let i=0;i<W*H;i++)alpha[i]=d[i*4+3];return cache[key]={img:P.c,s,item,anchor:pk.anchor,top,bottom,alpha}}
// progress < 1 : chantier (fantôme + montée depuis le sol) ; opts.yaw/opts.phase : visée des balistes.
function draw(ctx,kind,px,py,k,time,progress=1,opts={}){const sp=sprite(kind,opts.variant),[ax,ay]=sp.anchor,x0=px-ax*k,y0=py-ay*k;
 sg.clearRect(0,0,W,H);sg.imageSmoothingEnabled=false;
 if(progress<1){sg.globalAlpha=.22;sg.drawImage(sp.img,0,0);sg.globalAlpha=1;const f=clamp(progress),cut=Math.round(sp.bottom-(sp.bottom-sp.top)*f);
  sg.drawImage(sp.img,0,cut,W,H-cut,0,cut,W,H-cut);for(let i=0;i<W;i+=2)if(sp.alpha[cut*W+i]>200&&hash(i,Math.floor(time*8),3)>.6)dot(sg,i,cut-(hash(i,Math.floor(time*8),5)*3|0),'#e8d8a8')}
 else{sg.drawImage(sp.img,0,0);if(kind==='ballista'){if(opts.variant){if(global.BalisteTyrienne)BalisteTyrienne.drawGame(sg,sp.s.c[0],sp.s.top,opts.yaw||0,time,opts.phase||0,0);else ballistaWeapon(sg,sp.s.c[0],sp.s.top,0,opts.yaw||0,time,1,0,opts.phase||0,true)}else ballistaAnim(sg,sp.s,time,0)}else sp.item.anim(sg,sp.s,time)}
 const smooth=ctx.imageSmoothingEnabled;ctx.imageSmoothingEnabled=false;ctx.drawImage(scratch,x0,y0,W*k,H*k);ctx.imageSmoothingEnabled=smooth}
function bake(item,variant){const P=new Px(W,H);const R=ground(P,item.seed);frame(R,P);const s=item.draw(P,R,variant);P.flush();return{img:P.c,s}}
global.PixelBuildings={W,H,sets,bake,draw,sprite,register,PICKS,lib:{PAL,rp,mod,clamp,ISOP,origin,block,wood,stoneSh,roof,opening,cylinder,logV,logU,post,stake,pile,pebble2,brazier,dot,lineA,smoke,flame,glowPool,sparks,flag,tent,campfire,monoRoof,surf,ground,frame}};
})(window);
