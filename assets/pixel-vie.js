/* PixelVie — Chambre, Puits des Âmes, Bibliothèque, dans la vue du jeu (Index.html) :
   vue de dessus 3/4, sol carré 1:1 (8 px par unité en x et z), seules les faces sud sont visibles,
   hauteur 8·0,96/0,86 px par unité. Une case de construction = 4 unités = 32 px.
   Chambre et Puits : 2 cases (64×64 px au sol). Bibliothèque : 3 cases (96×96 px). */
(function(global){
'use strict';
const W=320,H=240,KH=8*.96/.86;
const L=PixelBuildings.lib,{PAL,rp,mod,dot,lineA,smoke,flame,glowPool,flag,pebble2,stake,campfire}=L;
let OX=160,OY=150;
const Q=(x,z,h=0)=>[Math.round(OX+x*8),Math.round(OY+z*8-h*KH)];
const LIFE=['#0c2416','#143c22','#1f5e30','#2f8a42','#56b860','#94e08a','#d6ffc4'];
const SAP=['#2a1606','#5a3010','#8a5416','#c08a2a','#e8bc48','#fff0a0'];
const SOUL=['#0a1c1a','#12342e','#1e5a48','#2f8a6a','#5cc49a','#a8f0cc','#e8fff4'];
const BOOK=['#6e1a24','#2c4466','#2f613a','#8a6a30','#4c1018','#3c2a78'];
const CAVE=['#4a3220','#5e4027','#74502e','#8a6036','#a0723f','#b8864b','#cf9c5a'];
const GOLD=['','','',C.gold[2],C.gold[3],'#fff0a0'];

/* ---------- textures (coordonnées écran ; u,w ∈ [0,1] sur la face) ---------- */
const T={
 stoneTop:(b=0)=>(x,y)=>rp(C.stone,.72+b+(fbm(x/6,y/6,6)-.5)*.2-((mod(x,10)===0||mod(y,10)===0)?.16:0),x,y),
 stone:(b=0,moss=.4)=>(x,y,u,w)=>{const r=Math.floor(y/5),off=r%2*5;let v=.46+b-w*.14+(hash(r,Math.floor((x+off)/10),5)-.5)*.14+(fbm(x/7,y/7,8)-.5)*.1;
  if(mod(y,5)===0||mod(x+off,10)===0)v-=.2;if(w>.7&&fbm(x/5,y/3,12)<moss*.6)return rp(C.moss,v+.15,x,y);return rp(C.stone,v,x,y)},
 woodTop:(r=PAL.wood,b=0)=>(x,y)=>{let v=.72+b+(hash(Math.floor(y/4),Math.floor(x/23),2)-.5)*.16;if(mod(y,4)===0)v-=.3;return rp(r,v,x,y)},
 wood:(r=PAL.wood,b=0)=>(x,y,u,w)=>{let v=.5+b-w*.12+(hash(Math.floor(x/4),3,1)-.5)*.16+(fbm(x/2,y/8,4)-.5)*.12;if(mod(x,4)===0)v-=.3;return rp(r,v,x,y)},
 bark:(b=0)=>(x,y,u)=>{let v=.6+b-Math.abs(u-.4)*.6+(hash(x,Math.floor(y/3),3)-.5)*.2;if(mod(x+Math.floor(fbm(0,y/9,2)*5),5)===0)v-=.2;return rp(C.bark,v,x,y)},
 flat:(r,v)=>(x,y)=>rp(r,v+(fbm(x/5,y/5,3)-.5)*.16,x,y),
 water:(r,lit=.5)=>(x,y)=>rp(r,lit+(fbm(x/7,y/4,4)-.5)*.35+(mod(y+Math.floor(fbm(x/9,0,5)*6),6)===0?.15:0),x,y),
};
/* ---------- primitives ---------- */
// boîte posée à l'altitude h0 : dessus (a×b) + face sud ; profondeur = bord sud
function box(P,x0,z0,a,b,h,top,front,{h0=0,edge=true,d}={}){const D=d??(z0+b);
 const[xa,y0]=Q(x0,z0,h0+h),[xb,y1]=Q(x0+a,z0+b,h0+h),y2=Q(0,z0+b,h0)[1];
 for(let y=Math.round(y0);y<Math.round(y1);y++)for(let x=Math.round(xa);x<Math.round(xb);x++)P.set(x,y,top(x,y,(x-xa)/(xb-xa),(y-y0)/Math.max(1,y1-y0)),D);
 for(let y=Math.round(y1);y<Math.round(y2);y++)for(let x=Math.round(xa);x<Math.round(xb);x++)P.set(x,y,front(x,y,(x-xa)/(xb-xa),(y-y1)/Math.max(1,y2-y1)),D);
 if(edge){for(let x=Math.round(xa);x<Math.round(xb);x++){P.set(x,Math.round(y0)-1,C.outline,D+.001);P.set(x,Math.round(y2),C.outline,D+.001);P.set(x,Math.round(y1),rp(C.stone,.9,0,0),D+.0005)}
  for(let y=Math.round(y0)-1;y<=Math.round(y2);y++){P.set(Math.round(xa)-1,y,C.outline,D+.001);P.set(Math.round(xb),y,C.outline,D+.001)}}
 return{xa,xb,y0,y1,y2}}
// toit à deux pans, faîtage selon x : le pan nord apparaît raccourci, le pan sud de face
function roof(P,x0,z0,a,b,h,r,kind='shingle',o=.6){const ramp=PAL[kind],D=z0+b+o+.01;
 const[xa,yb]=Q(x0-o,z0-o,h),[xb,yr]=Q(x0+a+o,z0+b/2,h+r),yf=Q(0,z0+b+o,h-.4)[1];
 const tex=(lit,x,y)=>{let v=lit;if(kind==='thatch'){v+=(hash(x,Math.floor(y/2),5)-.5)*.34;if(mod(y,5)===0)v-=.2}else{const row=Math.floor(y/3);v+=(hash(row,Math.floor((x+row*3)/6),4)-.5)*.2;if(mod(y,3)===0)v-=.26;if(mod(x+row*3,6)===0)v-=.15}return rp(ramp,v+(fbm(x/7,y/7,9)-.5)*.1,x,y)};
 for(let y=Math.round(Math.min(yb,yr));y<Math.round(yr);y++)for(let x=Math.round(xa);x<Math.round(xb);x++)P.set(x,y,tex(.82,x,y),D);
 for(let y=Math.round(yr);y<Math.round(yf);y++)for(let x=Math.round(xa);x<Math.round(xb);x++)P.set(x,y,tex(.58-(y-yr)/(yf-yr)*.12,x,y),D);
 for(let x=Math.round(xa);x<Math.round(xb);x++){P.set(x,Math.round(Math.min(yb,yr))-1,C.outline,D+.001);P.set(x,Math.round(yr),rp(ramp,.98,0,0),D+.001);P.set(x,Math.round(yf),C.outline,D+.001);P.dark(x,Math.round(yf)+1,.55,D-.5);P.dark(x,Math.round(yf)+2,.7,D-.5)}
 for(let y=Math.round(Math.min(yb,yr))-1;y<=Math.round(yf);y++){P.set(Math.round(xa)-1,y,C.outline,D+.001);P.set(Math.round(xb),y,C.outline,D+.001)}
 if(kind==='thatch')for(let x=Math.round(xa);x<Math.round(xb);x++)for(let k=1;k<3;k++)if(hash(x,k,8)>.5)P.set(x,Math.round(yf)+k,PAL.thatch[1],D+.002);
 return{yr,yf,xa,xb}}
// cylindre vertical (centre cx,cz ; rayon r unités) : face sud en bande + disque supérieur
function cyl(P,cx,cz,r,h,side,top,{h0=0,d}={}){const D=d??(cz+r),R8=r*8,[px,py]=Q(cx,cz,h0+h),bot=Q(cx,cz,h0)[1];
 for(let i=-R8;i<=R8;i++){const e=Math.sqrt(Math.max(0,R8*R8-i*i));for(let y=Math.round(py+e);y<=Math.round(bot+e);y++)P.set(px+i,y,side(px+i,y,i/R8,(y-py-e)/Math.max(1,bot-py)),D);P.set(px+i,Math.round(bot+e)+1,C.outline,D+.001)}
 for(let j=-R8;j<=R8;j++)for(let i=-R8;i<=R8;i++){const dd=(i*i+j*j)/(R8*R8);if(dd<=1)P.set(px+i,py+j,top(px+i,py+j,dd,i/R8,j/R8),D+.0005)}
 for(let a=0;a<400;a++){const t=a/400*6.283;P.set(px+Math.cos(t)*(R8+.6),py+Math.sin(t)*(R8+.6),C.outline,D+.001)}
 return[px,py]}
const ring=(rTop,rIn,inner)=>(x,y,dd,i,j)=>dd<rIn*rIn?inner(x,y,dd/(rIn*rIn)):rTop(x,y);
function pillar(P,x,z,h,R,broken=false){// colonne vue de 3/4 : fût cylindrique + chapiteau
 cyl(P,x,z,.7,h,(px,py,i,w)=>rp(C.stone,.62-i*.3-w*.1+(mod(px,3)===0?-.08:0),px,py),T.stoneTop(.08));
 if(!broken){box(P,x-.9,z-.9,1.8,1.8,.6,T.stoneTop(.12),T.stone(.1,0),{h0:h})}else for(let k=0;k<3;k++){const[a,b]=Q(x+(k-1)*.4,z+.2,h+.2);P.set(a,b-k%2,C.stone[6],z+1)}}
function post(P,x,z,h,r=PAL.wood){return box(P,x,z,.6,.6,h,T.woodTop(r,.1),T.wood(r,.05))}
function shade(P,x,z,rx,rz){const[a,b]=Q(x,z);shadow(P,a+6,b+4,rx*8,rz*8,-50)}
function bookRow(P,x0,x1,y0,y1,d){for(let y=y0;y<y1;y+=6){for(let x=x0;x<x1;x+=2){const c=BOOK[hash(x,y,3)*BOOK.length|0],hh=4+(hash(x,y,4)*2|0);for(let j=0;j<hh;j++){P.set(x,y+5-j,c,d);if(hash(x,y,7)>.3)P.set(x+1,y+5-j,c,d)}}for(let x=x0;x<x1;x++)P.set(x,y+5,PAL.wood[2],d)}}
/* ---------- animation ---------- */
function motes(g,x,y,w,rise,t,ramp,n=12,seed=0){for(let k=0;k<n;k++){const p=mod(t*.35+k/n+seed,1);const px=x+(hash(k,3,seed*7|0)-.5)*w+Math.sin(p*6+k)*3,py=y-p*rise;if(p<.85||hash(k,Math.floor(t*4),1)>.5)dot(g,px,py,ramp[Math.min(ramp.length-1,3+(p<.5)+(k%2))])}}
function page(g,x,y,t,k){const f=Math.sin(t*9+k)>0;for(let i=0;i<3;i++)dot(g,x+i,y+(f?i*.4:-i*.4),'#e8e0c0');dot(g,x+1,y+1,'#b8ac88')}
function zzz(g,x,y,t){for(let k=0;k<3;k++){const p=mod(t*.4+k/3,1),px=Math.round(x+p*10+Math.sin(p*6)*2),py=Math.round(y-p*22),s=1+(p>.5);if(p>.9)continue;
 for(let i=0;i<=s*2;i++){dot(g,px+i,py,'#c4b2ff');dot(g,px+i,py+s*2,'#c4b2ff');dot(g,px+s*2-i,py+i,'#c4b2ff')}}}
function rope(g,x0,y0,x1,y1,sag,col){for(let i=0;i<=40;i++){const t=i/40;dot(g,x0+(x1-x0)*t,y0+(y1-y0)*t+Math.sin(t*Math.PI)*sag,col)}}
function bucket(g,x,y){for(let j=0;j<5;j++)for(let i=-2;i<=2;i++)dot(g,x+i,y+j,rp(PAL.wood,.7-i*.12,x+i,y+j));for(let i=-2;i<=2;i++)dot(g,x+i,y+2,PAL.iron[3]);dot(g,x,y-1,PAL.rope[1])}
function ripple(g,x,y,r,p,col){for(let a=0;a<60;a++){const px=x+Math.cos(a/60*6.283)*r,py=y+Math.sin(a/60*6.283)*r;if(BAYER[mod(py|0,4)][mod(px|0,4)]<(1-p)*.7)dot(g,px,py,col)}}
function soul(g,x,y,t,k){const b=Math.sin(t*3+k);for(let j=0;j<6;j++)for(let i=-2;i<=2;i++){if(j>3&&Math.abs(i)>(5-j))continue;if(j<2&&Math.abs(i)>1)continue;dot(g,x+i+Math.round(Math.sin(t*4+j)*(j/6)),y+j,SOUL[j<2?6:5-(j>>1)])}if(b>0)dot(g,x,y-1,SOUL[6])}

/* =============== CHAMBRE · 2 cases =============== */
function roomA(P,R){shade(P,0,0,4.5,4);box(P,-4,-4,8,8,.3,T.stoneTop(-.05),T.stone(0,.2),{d:-20});
 box(P,-4,-4,8,1.4,5,T.stoneTop(.04),T.stone(.04,.6));box(P,-4,-2.6,1.2,6.6,4,T.stoneTop(.02),T.stone(0,.6));
 // alcôve voûtée dans le mur du fond
 const[ax,ay]=Q(-1.5,-2.6,0),aw=36,ah=Math.round(3.6*KH);for(let y=0;y<ah;y++)for(let x=0;x<aw;x++){const top=ah-Math.sin(x/aw*Math.PI)*8-ah+8;if(y<top)continue;P.set(ax+x,ay-ah+y,y<top+2?C.stone[1]:'#120d0a',-2.4)}
 box(P,-1,-2.4,4,2.2,.5,T.flat(PAL.straw,.7),T.flat(PAL.straw,.45),{h0:.3});box(P,.6,-2.4,2.4,2.2,.15,T.flat(C.cloth,.62),T.flat(C.cloth,.4),{h0:.8,edge:false});
 box(P,-.8,-2.2,1.2,.8,.2,T.flat(PAL.canvas,.8),T.flat(PAL.canvas,.5),{h0:.8,edge:false});
 box(P,2,1,1,1,1,T.woodTop(),T.wood());const[jx,jy]=Q(2.5,1.5,1.2);pebble2(P,jx,jy-1,1.5,PAL.clay,2.3);
 post(P,-2.4,2,4,PAL.iron);vine(P,...Q(-3.6,-2.6,5),18,R,3);return{lamp:Q(-2.1,2.3,4.4),bed:Q(1.6,-1.4,1.2)}}
function roomAAnim(g,s,t){const[lx,ly]=s.lamp;glowPool(g,lx,ly+20,24,16,t,PAL.fire[4],.3);flame(g,lx,ly,t,.6);zzz(g,s.bed[0],s.bed[1]-6,t)}

function roomB(P,R){shade(P,0,.5,4.5,3.5);const w=box(P,-4,-3,8,6,3.4,T.stoneTop(),T.stone(.04,.5));
 const[dx,dy]=Q(-.6,3,0);for(let y=-22;y<0;y++)for(let x=0;x<10;x++)P.set(dx+x,dy+y,y<-19?PAL.wood[4]:'#110c08',3.1);
 for(const x of[-3.2,-2,1.6,2.8]){const[wx,wy]=Q(x,3,2.2);for(let y=0;y<6;y++)for(let i=0;i<5;i++)P.set(wx+i,wy+y,i===0||y===0?C.stone[1]:rp(PAL.fire,.55+(BAYER[mod(wy+y,4)][mod(wx+i,4)]-.5)*.3,0,0),3.1)}
 const r=roof(P,-4,-3,8,6,3.4,2.4,'shingle');
 // lucarne-rosace sur le pan sud
 const[rx,ry]=Q(0,1.2,4.3);for(let j=-5;j<=5;j++)for(let i=-5;i<=5;i++){const d=Math.hypot(i,j);if(d<5.5)P.set(rx+i,ry+j,d>4.4?C.stone[2]:(i===0||j===0||i===j||i===-j)?C.stone[3]:'#3a2408',4)}
 box(P,1.8,-2.2,1,1,2.2,T.stoneTop(.1),T.stone(.1,0),{h0:4.6,d:-1});
 for(let k=0;k<3;k++)box(P,-3.4+k*2.6,3.6,1.8,.6,.5,T.flat(PAL.straw,.7),T.flat(PAL.straw,.45));
 return{rose:[rx,ry],chim:Q(2.3,-1.7,6.8),flags:[Q(-1.4,3.1,3),Q(.8,3.1,3)]}}
function roomBAnim(g,s,t){const[rx,ry]=s.rose;glowPool(g,rx,ry,5,5,t,PAL.fire[5],.55);for(const[fx,fy]of s.flags)flag(g,fx-4,fy,7,12,t+fx*.1);smoke(g,s.chim[0],s.chim[1],t,5,36)}

function roomC(P,R){shade(P,0,0,5,3);box(P,-3.4,-1.2,6.8,3.2,.4,T.woodTop(),T.wood(PAL.wood,-.05),{d:-20});
 for(const x of[-4,3.2]){box(P,x,-.6,.9,.9,8,T.flat(C.bark,.6),T.bark(),{d:.3})}
 const[c1x,c1y]=Q(-3.6,-.6,8.6),[c2x,c2y]=Q(3.6,-.6,8.6),[c3x,c3y]=Q(0,-1.6,9.4);canopy(P,c1x,c1y,30,20,R,6);canopy(P,c2x,c2y,30,20,R,6);canopy(P,c3x,c3y,34,18,R,6.5);
 for(let x=Math.round(Q(-3.5)[0]);x<=Q(3.5)[0];x++){const y=Q(0,-1.2,6.6)[1]+Math.sin((x-128)/64*Math.PI)*5;for(let j=0;j<4;j++)P.set(x,y+j,rp(C.leaf,.6-j*.12+(hash(x,j,1)-.5)*.3,x,y+j),6.2)}
 pebble2(P,...Q(2.8,2.6,.4),3,PAL.straw,2.5);return{a:Q(-3.1,-.2,4.2),b:Q(3.2,-.2,4.2)}}
function roomCAnim(g,s,t){const[ax,ay]=s.a,[bx,by]=s.b;for(let k=0;k<2;k++){const sw=Math.sin(t*1.4+k*1.7)*2,yo=k*14;
  rope(g,ax,ay+yo,bx,by+yo,8+sw,PAL.rope[0]);for(let i=8;i<=52;i++){const tt=i/60,x=ax+(bx-ax)*tt,y=ay+yo+Math.sin(tt*Math.PI)*(10+sw);for(let j=0;j<3;j++)dot(g,x,y+j,rp(k?PAL.canvas:C.cloth,.75-j*.2,x|0,y|0))}}
 for(let k=0;k<5;k++){const p=mod(t*.15+k/5,1),x=125+hash(k,1,4)*70+Math.sin(p*9)*5,y=70+p*110;dot(g,x,y,C.leaf[6]);dot(g,x+1,y,C.leaf[5])}}

function tentZ(P,x0,z0,a,b,r,kind='canvas'){const ramp=PAL[kind],xm=x0+a/2,D=z0+b;
 const L=[Q(x0,z0),Q(xm,z0,r),Q(xm,z0+b,r),Q(x0,z0+b)],Rr=[Q(xm,z0,r),Q(x0+a,z0),Q(x0+a,z0+b),Q(xm,z0+b,r)],F=[Q(x0,z0+b),Q(xm,z0+b,r),Q(x0+a,z0+b)];
 P.poly(L,(x,y)=>rp(ramp,.74+(fbm(x/6,y/6,5)-.5)*.16-(mod(y,9)===0?.1:0),x,y),D-.02);P.poly(Rr,(x,y)=>rp(ramp,.5+(fbm(x/6,y/6,5)-.5)*.16-(mod(y,9)===0?.1:0),x,y),D-.02);
 P.poly(F,(x,y)=>rp(ramp,.62+(fbm(x/6,y/6,5)-.5)*.14,x,y),D);const[ex,ey]=Q(xm,z0+b);P.poly([[ex-7,ey],[ex,ey-Math.round(r*KH*.65)],[ex+7,ey]],()=>'#140e08',D+.001);
 for(const[p,q]of[[F[0],F[1]],[F[1],F[2]],[F[0],F[2]],[L[0],L[1]],[L[1],L[2]],[L[0],L[3]],[Rr[1],Rr[2]],[Rr[0],Rr[1]]])P.line(...p,...q,C.outline,D+.002)}
function roomD(P,R){shade(P,-.6,0,4,3.5);tentZ(P,-3.4,-3.6,6,6.2,3.6);
 for(const[x,z,h]of[[-2.4,-1,1.2],[1.4,0,1.6],[-1.6,1.8,.8]]){const[a,b]=Q(x,z,h);for(let j=0;j<5;j++)for(let i=0;i<6;i++)P.set(a+i,b+j,rp(C.cloth,.55+((i+j)%2)*.12,0,0),2.1)}
 const[fx,fy]=Q(2.6,3.4);campfire(P,fx,fy,3.5);
 for(const[x,z]of[[-3.8,3],[-2.8,3.4]])pebble2(P,...Q(x,z,.4),3,PAL.straw,3.4);box(P,.6,3.6,2.2,.5,.5,T.woodTop(),T.wood());
 for(const[x,z]of[[-3.8,-3.8],[3,-3.8],[3,2.8]]){const[a,b]=Q(x,z);stake(P,a,b,8,z+1,x)}return{fire:[fx,fy-2]}}
function roomDAnim(g,s,t){const[fx,fy]=s.fire;glowPool(g,fx,fy+2,20,10,t,PAL.fire[4],.35);flame(g,fx,fy,t,1);smoke(g,fx,fy-10,t,6,46)}

function roomE(P,R){shade(P,0,0,4.5,4.5);box(P,-4,-4,8,8,.5,T.stoneTop(-.06),T.stone(-.04,.7),{d:-21});box(P,-3.4,-3.4,6.8,6.8,.3,T.stoneTop(.06),T.stone(.06,.2),{h0:.5,d:-20});
 for(const x of[-2.4,.8]){box(P,x,-1.6,1.6,4,.7,T.stoneTop(.14),T.stone(.12,0),{h0:.8});box(P,x+.3,-1.5,1,1,.4,T.stoneTop(.2),T.stone(.18,0),{h0:1.5})}
 box(P,-.5,-3.2,1,1,1.3,T.stoneTop(.1),T.stone(.1,0),{h0:.8});
 for(const[x,z,b]of[[-3.4,-3.4,0],[3.4,-3.4,1],[-3.4,3.2,1],[3.4,3.2,0]])pillar(P,x,z,b?2.6:5.6,R,!!b);
 return{orb:Q(0,-2.7,3.4),a:Q(-1.6,-1.2,2),b:Q(1.6,-1.2,2)}}
function roomEAnim(g,s,t){const[ox,oy]=s.orb,b=Math.sin(t*1.6);glowPool(g,ox,oy+10,30,20,t,C.glow[0],.26+b*.06);
 for(let j=-3;j<=3;j++)for(let i=-3;i<=3;i++)if(i*i+j*j<11)dot(g,ox+i,oy+j+Math.round(b),rp(C.orb,.8-(i+j)*.08+b*.1,ox+i,oy+j));motes(g,ox,oy,50,40,t,C.orb,10);zzz(g,s.a[0],s.a[1]-4,t+1.2)}

/* =============== PUITS DES ÂMES · 2 cases =============== */
function wellA(P,R){shade(P,0,.4,3.6,3);const c=cyl(P,0,.4,2.6,1.2,T.stone(.02,.8),ring(T.stoneTop(.04),.72,T.water(LIFE,.55)));
 for(let k=0;k<12;k++){const a=k/12*6.283;if(hash(k,1,1)>.5){const[x,y]=Q(Math.cos(a)*2.6,.4+Math.sin(a)*2.6,1.2);pebble2(P,x,y,1.5,C.moss,3+Math.sin(a))}}
 post(P,-3.4,.1,4.6);post(P,2.8,.1,4.6);box(P,-3.4,.1,6.8,.6,.5,T.woodTop(),T.wood(),{h0:4.6,d:1});
 const[hx,hy]=Q(3.6,.4,4.8);for(let j=-4;j<=4;j++)for(let i=-1;i<=1;i++)P.set(hx+i,hy+j,PAL.iron[3],1.1);return{c,top:Q(0,.4,4.6)}}
function wellAAnim(g,s,t){const[cx,cy]=s.c;glowPool(g,cx,cy,18,18,t,LIFE[5],.35);motes(g,cx,cy,30,50,t,LIFE,14);
 const[tx,ty]=s.top,by=ty+6+(1+Math.sin(t*.8))*12;lineA(g,tx,ty+2,tx,by,PAL.rope[1]);bucket(g,tx,by)}

function wellB(P,R){shade(P,.6,.6,3.8,3.4);const c=cyl(P,1,1,2.8,.7,T.stone(.04,.9),ring(T.stoneTop(),.8,T.water(SOUL,.5)));
 box(P,-4.2,-3.8,1.8,1.6,8,T.flat(C.bark,.6),T.bark(),{d:-2});const[kx,ky]=Q(-3.3,-3.4,8.6);canopy(P,kx,ky,30,22,R,6);
 const[r0x,r0y]=Q(-2.5,-3,6),[r1x,r1y]=Q(1,1,2.4);const pts=[];for(let i=0;i<=50;i++){const t=i/50;pts.push([r0x+(r1x-r0x)*t,r0y+(r1y-r0y)*t-Math.sin(t*Math.PI)*22])}
 pts.forEach(([x,y],i)=>{const w=5-i/50*3;for(let j=-w;j<=w;j++)P.set(x,y+j,rp(C.bark,.7-j/w*.4+(hash(x|0,j,2)-.5)*.2,x,y+j),4);P.set(x,y-w-1,C.outline,4);P.set(x,y+w+1,C.outline,4)});
 for(const[x,z]of[[-1.6,-1.8],[-3.6,-1.6]]){const[a,b]=Q(x,z);for(let k=0;k<7;k++)P.set(a+k,b-(k>>1),C.bark[2],-1)}
 return{c,tip:pts[50]}}
function wellBAnim(g,s,t){const[cx,cy]=s.c,[tx,ty]=s.tip;glowPool(g,cx,cy,20,20,t,SOUL[4],.3);
 for(let k=0;k<3;k++){const p=mod(t*.8+k/3,1);dot(g,tx,ty+3+p*(cy-ty-3),SOUL[6])}ripple(g,tx,cy,2+mod(t*.8,1)*14,mod(t*.8,1),SOUL[5]);
 for(let k=0;k<2;k++){const p=mod(t*.25+k/2,1);soul(g,cx-6+k*12+Math.sin(p*6+k)*3,cy-6-p*46,t,k)}}

function wellC(P,R){shade(P,0,.6,4,3.4);const c=cyl(P,0,.6,3.6,.8,T.stone(0,.7),ring(T.stoneTop(.04),.84,T.water(PAL.water,.5)));
 const st=[];for(let k=0;k<3;k++){const a=-1.57+(k-1)*2.094,x=Math.cos(a)*1.1,z=.6+Math.sin(a)*1.1;pillar(P,x,z,2.4,R,true);st.push(Q(x,z,3.2))}
 const v=cyl(P,0,.6,1.7,.5,T.stone(.1,0),ring(T.stoneTop(.1),.7,T.water(PAL.water,.62)),{h0:2.7,d:2.5});
 for(let i=0;i<7;i++)P.set(v[0]+5-i*.3,v[1]+11+i*.4,C.stone[1],2.6);return{c,st,v}}
function wellCAnim(g,s,t){const[cx,cy]=s.c,[vx,vy]=s.v;for(const[x,y]of s.st){for(let k=0;k<10;k++){const p=mod(t*1.2+k/10,1);const ox=(x-vx)*1.6,xx=vx+ox*(.6+p*.5),yy=vy+4+p*p*30;dot(g,xx,yy,PAL.water[5+(k%2)])}}
 for(let k=0;k<3;k++){const p=mod(t*.5+k/3,1);ripple(g,cx,cy+4,8+p*18,p,PAL.water[6])}}

function wellD(P,R){shade(P,0,0,3.8,3.8);const c=cyl(P,0,0,3.4,.3,T.stone(-.05,.5),(x,y,dd)=>{if(Math.abs(Math.sqrt(dd)-.62)<.05||Math.abs(Math.sqrt(dd)-.88)<.035)return C.gold[2];return T.stoneTop(-.06+(dd<.16?.1:0))(x,y)});
 for(let k=0;k<8;k++){const a=k/8*6.283,[x,y]=[c[0]+Math.cos(a)*20,c[1]+Math.sin(a)*20];for(let i=-1;i<=1;i++){P.set(x+i,y,C.gold[3],1);P.set(x,y+i,C.gold[3],1)}}
 for(const a of[.5,2.1,3.7,5.2]){const[x,y]=Q(Math.cos(a)*4,Math.sin(a)*4);rock(P,x,y,R,Math.sin(a)*4+.5,.5)}return{c}}
function wellDAnim(g,s,t){const[cx,cy]=s.c,top=20;glowPool(g,cx,cy,26,26,t,SOUL[4],.28);
 for(let y=cy;y>top;y--){const w=4+Math.sin(y*.3+t*6)*1.1+(cy-y)/50;for(let i=-w;i<=w;i++){const px=Math.round(cx+i),v=.55+.35*Math.cos(i/w*1.5)+Math.sin(y*.5+t*10)*.1;if(BAYER[mod(y,4)][mod(px,4)]<.8)dot(g,px,y,rp(SOUL,v,px,y))}}
 for(let k=0;k<18;k++){const p=mod(t*.6+k/18,1),a=k*2.4;dot(g,cx+Math.cos(a)*p*30,top-p*10+Math.sin(a)*p*6+p*p*26,SOUL[6])}
 const p=mod(t*.3,1);soul(g,cx+Math.sin(t)*2,cy-10-p*(cy-top),t,0)}

function wellE(P,R){shade(P,0,0,4,3.8);const c=cyl(P,0,.8,2.1,1.6,T.stone(.04,.6),ring(T.stoneTop(),.7,T.water(PAL.water,.35)));
 for(const x of[-3.6,3])post(P,x,-3.4,6.2);roof(P,-3.6,-3.6,7.2,2.4,6.2,1.6,'clay',.5);
 box(P,-3.2,-.2,6.4,.4,.4,T.woodTop(),T.wood(),{h0:5.4,d:.3});post(P,-3.6,-.4,5.4);post(P,3,-.4,5.4);
 for(const[x,z]of[[-3.8,2.6],[2.6,2.8]])box(P,x,z,1.2,1.2,.9,T.woodTop(),T.wood());return{c,beam:Q(0,0,5.4)}}
function wellEAnim(g,s,t){const[ax,ay]=s.beam;for(const[dx,ph]of[[-7,0],[7,Math.PI]]){const y=ay+6+(1+Math.sin(t*1.1+ph))*14;lineA(g,ax+dx,ay+2,ax+dx,y,PAL.rope[1]);bucket(g,ax+dx,y);
  if(Math.sin(t*1.1+ph)<-.7)for(let k=0;k<3;k++)dot(g,ax+dx+(k-1)*2,y+6+mod(t*20+k*3,6),PAL.water[6])}}

/* =============== BIBLIOTHÈQUE · 3 cases =============== */
function libA(P,R){shade(P,0,0,6,5);box(P,-6,1,5.2,4.6,2.6,T.stoneTop(),T.stone(.02,.6));roof(P,-6,1,5.2,4.6,2.6,1.8,'shingle',.4);
 const b=box(P,-1.6,-4.6,5,5,11,T.stoneTop(.04),(x,y,u,w)=>w<.5?T.wood(PAL.wood,.05)(x,y,u,w):T.stone(.04,.7)(x,y,u,w));
 for(const[h,lit]of[[3,1],[7.5,1]]){const[wx,wy]=Q(.4,.4,h);for(let y=0;y<8;y++)for(let i=0;i<6;i++)P.set(wx+i,wy+y,i===0||y===0?C.stone[1]:rp(PAL.fire,.55,0,0),.5)}
 const r=roof(P,-1.6,-4.6,5,5,11,3.4,'shingle',.5);
 box(P,-1.2,.4,4.2,1.2,.3,T.woodTop(),T.wood(),{h0:6});for(let x=Math.round(Q(-1.2)[0]);x<Q(3)[0];x+=4){const[_,y]=Q(0,1.6,6.3);for(let j=0;j<6;j++)P.set(x,y-j,PAL.wood[3],1.7)}
 for(const[x,z,h]of[[3.4,-1,5],[3.4,-3,9],[-1.6,-2,8]])for(let i=0;i<7;i++){const[a,bb]=Q(x+i*.12,z,h);P.set(a+i,bb,'#e8e0c0',.6);P.set(a+i,bb+1,'#b8ac88',.6)}
 return{bal:Q(.9,1,6.6),win:Q(.8,.4,8)}}
function libAAnim(g,s,t){const[bx,by]=s.bal;for(let k=0;k<5;k++){const p=mod(t*.18+k/5,1);page(g,bx+p*90+Math.sin(p*8+k)*8,by-4+p*30-Math.sin(p*3)*30,t,k)}glowPool(g,s.win[0],s.win[1],8,8,t,PAL.fire[5],.3)}

function libB(P,R){// fosse : paroi nord visible, rayonnages qui émergent
 const[x0,y0]=Q(-6,-5),[x1,y1]=Q(6,5),dep=Math.round(3*KH);
 for(let y=y0;y<y1;y++)for(let x=x0;x<x1;x++){const wall=y<y0+dep;P.set(x,y,wall?T.stone(-.15,.3)(x,y,0,(y-y0)/dep):rp(CAVE,.18+(fbm(x/8,y/8,2)-.5)*.3,x,y),-90)}
 for(let x=x0;x<x1;x++){P.set(x,y0-1,C.stone[6],-89);P.set(x,y1,C.stone[5],-89);P.set(x,y1+1,C.stone[2],-89)}for(let y=y0;y<=y1;y++){P.set(x0-1,y,C.stone[3],-89);P.set(x1,y,C.stone[3],-89)}
 for(const[x,z,h]of[[-5,-3.4,4.2],[-.6,-3.4,3.4],[3,-3.4,4],[-4.6,.6,2.8],[1.4,1.4,2]]){const b=box(P,x,z,3.4,1.2,h,T.woodTop(PAL.wood,-.05),T.wood(PAL.wood,-.15),{h0:-3});bookRow(P,Math.round(b.xa)+1,Math.round(b.xb)-1,Math.round(b.y1)+2,Math.round(b.y2)-4,z+1.21)}
 for(const[a,b2]of[[[-6.4,-2],[-2,3]],[[6.4,-4],[3,0]],[[-1,5.4],[2,2.6]]]){const[ax,ay]=Q(...a,0),[bx,by]=Q(...b2,0);for(let i=0;i<=40;i++){const t=i/40,x=ax+(bx-ax)*t,y=ay+(by-ay)*t+Math.sin(t*3)*5;for(let j=-2;j<=2;j++)P.set(x,y+j,rp(C.bark,.6-j*.15,x,y),5)}}
 for(const[x,z]of[[4.6,4],[-2.4,4.2]])pebble2(P,...Q(x,z,-2.6),3,['#3a3020','#6a5c40','#a89a78','#e8e0c0'],4.5);return{}}
function libBAnim(g,s,t){for(let k=0;k<7;k++){const p=mod(t*.22+k/7,1),[x,y]=Q(-5+hash(k,1,2)*10,-3+hash(k,2,2)*7,-2+p*7);page(g,x+Math.sin(p*5+k)*10,y,t,k)}}

function libC(P,R){shade(P,0,0,5.5,4);box(P,-2.6,-2.4,5.2,3.6,11,T.flat(C.bark,.6),T.bark(),{d:1.2});
 const[kx,ky]=Q(0,-1.6,12.4);canopy(P,kx,ky,58,30,R,6);canopy(P,kx-40,ky+14,28,18,R,5.5);canopy(P,kx+40,ky+12,28,18,R,5.5);
 for(const[x,h,w,hh]of[[-1.6,6.4,18,14],[.6,2.2,14,12],[-1.2,1.6,8,10]]){const[a,b]=Q(x,1.2,h);for(let j=0;j<hh;j++)for(let i=0;i<w;i++)P.set(a+i,b+j,'#140c06',1.3);bookRow(P,a+1,a+w-1,b+1,b+hh-4,1.31);
  for(let i=-1;i<=w;i++){P.set(a+i,b-1,C.bark[4],1.32);P.set(a+i,b+hh,C.bark[3],1.32)}}
 for(const[x,z]of[[-4.4,1.6],[3.6,1.8]]){const[a,b]=Q(x,z);for(let k=0;k<8;k++)P.set(a+k*(x<0?1:-1),b-(k>>1),C.bark[2],1.3)}
 const[lx,ly]=Q(3,1.4);for(let j=0;j<58;j++){P.set(lx,ly-j,PAL.wood[4],2);P.set(lx+7,ly-j,PAL.wood[3],2);if(j%7===0)for(let i=lx;i<=lx+7;i++)P.set(i,ly-j,PAL.wood[5],2)}
 return{lan:[Q(-4.8,-1,7),Q(-3,-.4,8.6),Q(3.6,-.4,8.4),Q(5,-1,7)]}}
function libCAnim(g,s,t){s.lan.forEach(([x,y],k)=>{const sw=Math.sin(t*1.3+k)*2;lineA(g,x,y-10,x+sw,y,PAL.rope[0]);glowPool(g,x+sw,y+4,9,8,t+k,PAL.fire[5],.35);
  for(let j=0;j<5;j++)for(let i=-2;i<=2;i++)dot(g,x+sw+i,y+j,Math.abs(i)===2||j===0||j===4?PAL.iron[2]:PAL.fire[5])});motes(g,160,120,110,60,t,GOLD,8)}

function libD(P,R){shade(P,0,0,6.2,5.5);box(P,-6,-5.4,12,10.8,.6,T.stoneTop(.02),T.stone(.02,.5),{d:-20});
 const w=box(P,-5.6,-5.2,11.2,1.8,5,T.stoneTop(.06),T.stone(.06,.2),{h0:.6});bookRow(P,Math.round(w.xa)+3,Math.round(w.xb)-3,Math.round(w.y1)+4,Math.round(w.y2)-6,-3.39);
 roof(P,-5.8,-5.6,11.6,2.4,5.6,1.8,'clay',.4);
 for(const x of[-4,-.8,2.4]){box(P,x,-1.4,2,1.2,1.2,T.woodTop(),T.wood(),{h0:.6});const[a,b]=Q(x+.4,-1.2,1.8);for(let i=0;i<6;i++)P.set(a+i,b+2,i<3?'#e8e0c0':C.cloth[2],-.2)}
 const[cx,cy]=Q(4.4,-1.2,1.8);for(let i=0;i<10;i++)P.set(cx+i*.5,cy+i,PAL.iron[4],-.1);
 for(const x of[-5.4,-2.6,.2,3,5.4-.6])pillar(P,x+.3,4.4,5,R,false);
 return{d:[Q(-3,-1.4,1.8),Q(.2,-1.4,1.8),Q(3.4,-1.4,1.8)]}}
function libDAnim(g,s,t){s.d.forEach(([x,y],k)=>{glowPool(g,x,y,10,7,t+k,C.gold[3],.4+Math.sin(t*2+k)*.1);motes(g,x,y,10,24,t,GOLD,4,k)})}

function libE(P,R){shade(P,0,0,6,5.5);const c=cyl(P,0,0,5.2,4.4,(x,y,i,w)=>{const v=T.stone(.04,.6)(x,y,i,w);if(w<.55&&w>.2&&Math.abs(i)<.85&&mod(Math.round((i+1)*9),3)===0)return'#1a120a';return v},T.stoneTop(.05));
 const R8=5.2*8;for(let a=3.3;a<6.1;a+=.04){const x=c[0]+Math.cos(a)*(R8-6),y=c[1]+Math.sin(a)*(R8-6);for(let j=0;j<9;j++)P.set(x,y-j,BOOK[hash(a*30|0,j>>2,3)*BOOK.length|0],5.3);P.set(x,y-9,PAL.wood[4],5.3)}
 // demi-coupole nord ouverte
 for(let a=3.14;a<6.29;a+=.008)for(let e=0;e<1.35;e+=.02){if(Math.abs(a-4.71)<.24)continue;const r=R8*Math.cos(e),x=c[0]+Math.cos(a)*r,y=c[1]+Math.sin(a)*r-Math.sin(e)*R8*.8;P.set(x,y,rp(PAL.iron,.38+Math.sin(e)*.4-Math.cos(a)*.15+(mod(a*20,1)<.12?-.2:0),x|0,y|0),5.1+e*.01)}
 box(P,-.6,-.6,1.2,1.2,1.6,T.stoneTop(.1),T.stone(.1,0),{h0:4.4,d:5.6});return{top:Q(0,0,8)}}
function libEAnim(g,s,t){const[x,y]=s.top;for(let r=0;r<3;r++){const Rr=9+r*4,tilt=.3+r*.5+t*(.4+r*.25);for(let a=0;a<80;a++){const th=a/80*6.283;dot(g,x+Math.cos(th)*Rr,y+Math.sin(th)*Rr*Math.cos(tilt)*.8,C.gold[r===1?3:2])}}
 for(let j=-1;j<=1;j++)for(let i=-1;i<=1;i++)dot(g,x+i,y+j,C.gold[3]);for(let k=0;k<14;k++)if(Math.sin(t*3+k*7)>.2)dot(g,30+hash(k,1,5)*260,6+hash(k,2,5)*30,k%3?'#e8e0c0':'#c4b2ff')}

/* ---------- sol de grotte à cases carrées + emprise ---------- */
function bake(item){const P=new Px(W,H);const sz=item.size;OX=160;OY=item.oy;const R=rng(item.seed),half=sz*2;
 for(let y=0;y<H;y++)for(let x=0;x<W;x++){const cx=Math.floor((x-OX)/32),cy=Math.floor((y-OY)/32),cell=cx*7+cy*13;let v=.62+(hash(cell,1,4)-.5)*.14+(fbm(x/9,y/6,21)-.5)*.34;if(fbm(x/3,y/2,23)>.74)v-=.2;P.set(x,y,P.ramp(CAVE,v,x,y),-100)}
 for(let k=0;k<160;k++){const x=R()*W|0,y=R()*H|0;P.set(x,y,CAVE[5],-99.9)}
 // grille de construction alignée sur l'emprise (comme drawBuildCells)
 for(let k=-8;k<=8;k++){const gx=Math.round(OX+(-half+k*4)*8),gy=Math.round(OY+(-half+k*4)*8);for(let i=0;i<W;i++)if(i%2===0)P.dark(i,gy,.82,-99);for(let j=0;j<H;j++)if(j%2===0)P.dark(gx,j,.82,-99)}
 const[a,b]=Q(-half,-half),[c,d]=Q(half,half);for(let x=a;x<=c;x++){P.set(x,b,C.gold[1],-98);P.set(x,d,C.gold[1],-98)}for(let y=b;y<=d;y++){P.set(a,y,C.gold[1],-98);P.set(c,y,C.gold[1],-98)}
 const s=item.draw(P,R);P.flush();return{img:P.c,s}}

const sets=[
 {id:'chambre',title:'Chambre à coucher · 2 cases',lede:'Repos des Exilés, accordé par Medeina. L’emprise de 2 × 2 cases (64 × 64 px) est tracée en or sur la grille de la grotte.',items:[
  {name:'A · Cellule de la nef',desc:'Une alcôve voûtée creusée dans un angle de murs tyriens : paillasse, couverture rouge, tabouret, cruche et lampe à huile.',seed:81,draw:roomA,anim:roomAAnim},
  {name:'B · Dortoir sous voûte',desc:'Une halle de pierre au toit de bardeaux, avec une rosace de lumière sur le pan sud, des fenêtres chaudes, une cheminée qui fume et des bannières à la porte.',seed:82,draw:roomB,anim:roomBAnim},
  {name:'C · Hamacs de canopée',desc:'Deux hamacs tendus entre deux troncs sous un auvent de feuilles, au-dessus d’un plancher. Ils se balancent, et des feuilles tombent.',seed:83,draw:roomC,anim:roomCAnim},
  {name:'D · Tente des exilés',desc:'Une toile rapiécée ouverte au sud, des pieux, des ballots, un banc et un feu de camp. La version nomade.',seed:84,draw:roomD,anim:roomDAnim},
  {name:'E · Sanctuaire du sommeil',desc:'Une crypte à ciel ouvert : deux gisants servent de couches, entre quatre colonnes dont deux brisées. Une veilleuse violette respire au fond.',seed:85,draw:roomE,anim:roomEAnim}]},
 {id:'puits',title:'Puits des Âmes · 2 cases',lede:'Medeina y rend leur souffle aux défunts. Chaque proposition a sa lumière de vie, et les âmes qui remontent annoncent la résurrection.',items:[
  {name:'A · Source sacrée',desc:'Une margelle moussue sous un treuil, avec un seau qui monte et descend. L’eau verte luminescente laisse s’élever des particules.',seed:91,draw:wellA,anim:wellAAnim},
  {name:'B · Racine-puits',desc:'Une racine géante s’arque au-dessus d’un bassin d’âmes. Chaque goutte fait une onde, et des âmes en montent.',seed:92,draw:wellB,anim:wellBAnim},
  {name:'C · Fontaine du vestige',desc:'Une vasque fissurée posée sur trois colonnes brisées. L’eau déborde en trois filets et ride le grand bassin.',seed:93,draw:wellC,anim:wellCAnim},
  {name:'D · Puits inversé',desc:'Un cercle runique doré d’où une colonne d’âmes monte vers le ciel, puis retombe en gerbe. C’est le négatif de l’Ancre.',seed:94,draw:wellD,anim:wellDAnim},
  {name:'E · Citerne des sœurs',desc:'Un puits devant un auvent de tuiles. Deux seaux montent et descendent en alternance, et le seau plein s’égoutte.',seed:95,draw:wellE,anim:wellEAnim}]},
 {id:'bibliotheque',title:'Bibliothèque · 3 cases',lede:'Les rouleaux de Sigil y sont rassemblés. Emprise de 3 × 3 cases (96 × 96 px), centrée sur une case comme dans le jeu.',items:[
  {name:'A · Tour du scribe',desc:'Une haute tour, en pierre en bas et en bois en haut, flanquée d’une annexe. Des pages s’envolent du balcon et des rouleaux dépassent des murs.',seed:101,draw:libA,anim:libAAnim},
  {name:'B · Archives englouties',desc:'Une fosse creusée dans la grotte, dont la paroi nord est visible. Des rayonnages en émergent, traversés par des racines, et des pages remontent.',seed:102,draw:libB,anim:libBAnim},
  {name:'C · Arbre-codex',desc:'Des niches à livres creusées dans un grand tronc, avec une échelle et des lanternes qui se balancent sous la canopée.',seed:103,draw:libC,anim:libCAnim},
  {name:'D · Scriptorium du temple',desc:'Une colonnade au sud, des tables de copistes qui s’illuminent d’or, et un mur-bibliothèque sous un auvent de tuiles. Un grimoire est enchaîné.',seed:104,draw:libD,anim:libDAnim},
  {name:'E · Observatoire-bibliothèque',desc:'Une rotonde au mur percé de fenêtres, une demi-coupole ouverte et des étagères en arc. Un astrolabe doré tourne au-dessus.',seed:105,draw:libE,anim:libEAnim}]},
];
for(const s of sets)for(const it of s.items){it.size=s.id==='bibliotheque'?3:2;it.oy=s.id==='bibliotheque'?160:140;const a=it.anim;it.anim=(g,st,t)=>{OX=160;OY=it.oy;a(g,st,t)}}
global.PixelVie={W,H,sets,bake};
})(window);
