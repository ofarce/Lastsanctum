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
 barracks:{set:'caserne',i:4,anchor:[160,182]},
 ballista:{set:'balistes',i:0,anchor:[160,196]},
};
const cache={},scratch=document.createElement('canvas');scratch.width=W;scratch.height=H;const sg=scratch.getContext('2d');
function sprite(kind,variant){const key=kind+(variant===undefined?'':':'+variant);if(cache[key])return cache[key];const pk=PICKS[kind],item=sets.find(s=>s.id===pk.set).items[pk.i];
 const P=new TPx(W,H),s=item.draw(P,rng(item.seed),variant);P.flush();
 let top=H,bottom=0;const d=P.d.data;for(let y=0;y<H;y++)for(let x=0;x<W;x++)if(d[(y*W+x)*4+3]>200){top=Math.min(top,y);bottom=Math.max(bottom,y);break}
 const alpha=new Uint8Array(W*H);for(let i=0;i<W*H;i++)alpha[i]=d[i*4+3];return cache[key]={img:P.c,s,item,anchor:pk.anchor,top,bottom,alpha}}
// progress < 1 : chantier (fantôme + montée depuis le sol) ; opts.yaw/opts.phase : visée des balistes.
function draw(ctx,kind,px,py,k,time,progress=1,opts={}){const sp=sprite(kind,opts.variant),[ax,ay]=sp.anchor,x0=px-ax*k,y0=py-ay*k;
 sg.clearRect(0,0,W,H);sg.imageSmoothingEnabled=false;
 if(progress<1){sg.globalAlpha=.22;sg.drawImage(sp.img,0,0);sg.globalAlpha=1;const f=clamp(progress),cut=Math.round(sp.bottom-(sp.bottom-sp.top)*f);
  sg.drawImage(sp.img,0,cut,W,H-cut,0,cut,W,H-cut);for(let i=0;i<W;i+=2)if(sp.alpha[cut*W+i]>200&&hash(i,Math.floor(time*8),3)>.6)dot(sg,i,cut-(hash(i,Math.floor(time*8),5)*3|0),'#e8d8a8')}
 else{sg.drawImage(sp.img,0,0);if(kind==='ballista'){if(opts.variant)ballistaWeapon(sg,sp.s.c[0],sp.s.top,0,opts.yaw||0,time,1,0,opts.phase||0,true);else ballistaAnim(sg,sp.s,time,0)}else sp.item.anim(sg,sp.s,time)}
 const smooth=ctx.imageSmoothingEnabled;ctx.imageSmoothingEnabled=false;ctx.drawImage(scratch,x0,y0,W*k,H*k);ctx.imageSmoothingEnabled=smooth}
function bake(item,variant){const P=new Px(W,H);const R=ground(P,item.seed);frame(R,P);const s=item.draw(P,R,variant);P.flush();return{img:P.c,s}}
global.PixelBuildings={W,H,sets,bake,draw,sprite,PICKS};
})(window);
