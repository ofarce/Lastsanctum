// Chiens de la Bête (ennemi « beast », vomi par les pylônes) : refonte HD, planche planches/chiens-bete-propositions.html.
// Moteur de l'Ingénieur (engineer-colosse.js : R, MAT, buf, blob, rect, px, render) + rampes de refonte-16bits.js
// (bete, bone, fire). Règles de la charte : paliers francs sans trame, contour coloré, lumière en haut à gauche,
// rouge = la Bête. Profil tourné vers la droite (le jeu retourne le sprite).
// Rig procédural : squelette hanche / épaule / cou / tête / mâchoire / queue, pattes en cinématique inverse
// (jarret vers l'arrière, coude vers l'arrière), pieds d'appui fixés au sol pendant la marche (aucun glissement).
// Expose : CHIENS = {VARIANTS, ANIMS, frame(variant, anim, t) → canvas FW × FH, FW, FH, AX, AY, STRIDE}.
'use strict';
if(!R.pale){Object.assign(R,{pale:['#3a1c1e','#86524e','#bc8680','#e4b8ae','#fff0e6']});MAT.push('pale')}
Object.assign(R,{
 maw:['#0e0204','#360610','#640e18','#9a1c24','#cc3a3a'],     // intérieur des gueules
 gore:['#160204','#4a0a0e','#7a1216','#b02420','#e2503a'],    // muscle à vif, plus sombre que la peau de la Bête
 chair:['#2a1012','#64302e','#985a52','#c08a7c','#e2b8a6'],   // chair pâle de charognard (moins blanche que l'os)
});
Object.assign(R,{
 ash:['#121010','#36302c','#5c544e','#867c72','#b8aea2'],     // cendre tiède
 dust:['#2a2016','#4d3c29','#6e5a40','#8e7a5a','#b4a07a'],    // poussière du sol
});
MAT.push('maw','gore','chair','ash','dust');

const CHIENS=(()=>{
const FW=84,FH=48,AX=36,AY=44,G=44;
const STRIDE=33;              // px par cycle de course (4,125 unités du jeu à 8 px/unité)
const TAU=Math.PI*2,cl=(v,a=0,b=1)=>Math.max(a,Math.min(b,v)),lerp=(a,b,t)=>a+(b-a)*t,ease=t=>t*t*(3-2*t);
const sm=(a,b,t)=>ease(cl((t-a)/(b-a)));
const hash=(x,y)=>{const v=Math.sin(x*12.9898+y*78.233)*43758.5453;return v-Math.floor(v)};

const VARIANTS=[
 {id:'A',name:'A · Molosse écorché',
  desc:'Le chien de garde de la Bête : poitrail profond, muscle à vif strié, masque d’os sur le crâne, crête de piquants le long de l’échine, yeux de braise. Lourd et lisible, la silhouette la plus proche de l’actuel.',
  skin:'bete',raw:'gore',hipH:14,shH:17,L:9.5,hip:[5.6,5],chest:[7.2,6.2],chestDrop:1.6,loin:3.6,sag:.6,
  neck:6,neckR:3.4,neckA:-.55,head:4.4,snout:6.5,snoutR:2.1,jawR:1.3,
  fore:[8.5,7.5,2.6],hind:[8,8,4.2],legR:[2.8,1.9,1.4],tail:7,tailR:1.6,tailA:-.25,spikes:7,
  mask:true,stripes:true,ear:'torn',eyes:1,fangs:true},
 {id:'B',name:'B · Lévrier de chair',
  desc:'Long, sec, tout en jambes : cage thoracique ouverte sur une gueule intérieure, peau pâle tendue sur le rouge, museau effilé qui se fend en deux sur la morsure. Le plus rapide à l’œil, une meute nerveuse.',
  skin:'bete',raw:'pale',hipH:16.5,shH:18,L:10.5,hip:[4.6,4.2],chest:[6.2,5.8],chestDrop:1.8,loin:2.6,sag:1.2,
  neck:7.5,neckR:2.6,neckA:-.5,head:3.6,snout:8.5,snoutR:1.6,jawR:1.1,
  fore:[9.5,8.5,2.8],hind:[9,9,4.8],legR:[2.2,1.5,1.1],tail:11,tailR:1.2,tailA:-.05,spikes:0,
  ribs:true,split:true,ear:'long',eyes:2,fangs:false},
 {id:'C',name:'C · Charognard aux trois gueules',
  desc:'Bossu comme une hyène, garrot haut et arrière-train bas, chair pâle crevée de plaies rouges. Pas d’yeux sur la face mais une grappe de braises sur le front, et une seconde gueule sur l’épaule qui s’ouvre avec la première.',
  skin:'chair',raw:'bete',hipH:13,shH:18.5,L:8.5,hip:[5,4.4],chest:[7.6,6.8],chestDrop:1.2,loin:3.8,sag:-.4,
  neck:5,neckR:3.6,neckA:-.25,head:4.8,snout:4.6,snoutR:2.4,jawR:1.5,
  fore:[9.5,8.5,2.6],hind:[7.6,7.6,4],legR:[3,2,1.4],tail:5,tailR:1.4,tailA:.35,spikes:5,
  wounds:true,shoulderMaw:true,ear:'none',eyes:3,fangs:true},
];
const ANIMS=[
 {id:'idle',name:'Repos menaçant',len:2,frames:48,desc:'Boucle de 2 s : souffle du poitrail, tête qui flaire, grognement babines retroussées, bave qui goutte, poids qui passe d’une patte à l’autre.'},
 {id:'walk',name:'Charge',len:.5,frames:12,desc:'Reprise v4 : deux fois plus rapide que la v3 (66 px/s au lieu de 33). Cycle de 12 images (0,5 s), bonds plus longs (foulée 33 px = 4,125 unités), pattes qui vont chercher plus loin, échine qui se ploie davantage ; tête basse tendue vers la cible, oreilles couchées, gueules ouvertes. Pieds d’appui fixes au sol.'},
 {id:'attack',name:'Bond et morsure',len:.75,frames:18,impact:14,desc:'Reprise : il se ramasse, bondit de 12 px en cloche sur la cible, pattes avant tendues et gueules ouvertes, mord en retombant (image 15), secoue sa prise, puis revient d’un petit saut. 18 images (0,75 s, sous le temps de recharge de 1,15 s).'},
 {id:'death',name:'Mort',len:1.5,frames:36,desc:'Reprise v3 : il éclate dès le coup fatal. Image 1 : éclair blanc fendu de braise ; dès l’image 2, onde de braise au sol, éclats, volutes et flocons de cendre, os qui retombent, petit tas de cendre où les braises s’éteignent. 36 images (1,5 s).'},
];

// ---------- primitives ----------
function seg(b,x0,y0,x1,y1,r0,r1,mat,bias=0){const n=Math.max(2,Math.ceil(Math.hypot(x1-x0,y1-y0)*2.2));
 for(let i=0;i<=n;i++){const t=i/n,r=Math.max(.75,lerp(r0,r1,t));blob(b,lerp(x0,x1,t),lerp(y0,y1,t),r,r,mat,bias)}}
function over(b,x,y,mat,s){x|=0;y|=0;if(x<0||y<0||x>=b.w||y>=b.h||b.m[y*b.w+x]<0)return;put(b,x,y,mat,s)}
function dot(b,x,y,mat,s){put(b,Math.round(x),Math.round(y),mat,s)}
function ik(ax,ay,tx,ty,l1,l2,bend){const dx=tx-ax,dy=ty-ay,d=Math.hypot(dx,dy),dd=cl(d,Math.abs(l1-l2)+.05,l1+l2-.05),base=Math.atan2(dy,dx);
 const a=Math.acos(cl((l1*l1+dd*dd-l2*l2)/(2*l1*dd),-1,1)),ang=base+bend*a;
 return{jx:ax+Math.cos(ang)*l1,jy:ay+Math.sin(ang)*l1,ex:ax+Math.cos(base)*dd,ey:ay+Math.sin(base)*dd}}

// ---------- poses ----------
// pieds : [arrière loin, avant loin, arrière près, avant près] ; chaque pied {x,y,th} (th = inclinaison du métatarse / paturon)
const NEAR=[false,false,true,true],HIND=[true,false,true,false];
function neutral(V,i){return HIND[i]?-V.L+1.5:V.L+1.2}
function gait(V,t){
 const duty=.34,step=STRIDE*duty,off=[.08,.58,0,.5],lift=[5.4,6.6,5.4,6.6],reach=[5,7,5,7];
 return off.map((o,i)=>{const u=((t+o)%1+1)%1,nx=neutral(V,i);let x,y,th;
  if(u<duty){const s=u/duty;x=nx+step/2-step*s;y=0;th=HIND[i]?lerp(-.25,.6,sm(.55,1,s)):lerp(-.15,.5,sm(.6,1,s))}
  else{const w=(u-duty)/(1-duty);x=nx-step/2+step*ease(w)+reach[i]*Math.sin(Math.PI*Math.pow(w,HIND[i]?.9:.7));y=-lift[i]*Math.pow(Math.sin(Math.PI*w),.8)*(HIND[i]?1:lerp(1.15,.8,w));
   th=HIND[i]?lerp(.7,-.3,ease(w)):lerp(1.5,-.2,sm(.15,.85,w))}
  return{x,y,th}})}
function planted(V,dx){return[0,1,2,3].map(i=>({x:neutral(V,i)+(dx?dx[i]:0),y:0,th:HIND[i]?-.25:-.15}))}

function pose(V,anim,t){
 const P={dust:-1,glow:0,burst:-1,air:0,bob:0,pitch:0,flex:0,breath:1,neckA:0,headP:0,jaw:.15,tailA:0,tailW:0,feet:null,dropF:0,dropH:0,melt:0,flash:0,drool:-1,ear:0,snarl:0,maw2:0,kick:0,embers:0};
 if(anim==='walk'){ // charge : cycle de 0,5 s, tête basse tendue vers la cible
  t=t/.5;P.feet=gait(V,t);P.bob=2.6*Math.cos(TAU*2*(t-.13))-.6;P.pitch=.13*Math.sin(TAU*(t+.02));P.flex=1.45*Math.cos(TAU*(t-.9));P.rx=.8*Math.sin(TAU*(t-.2));
  P.neckA=-.02+.15*Math.sin(TAU*(t+.3));P.headP=.16-.08*Math.sin(TAU*(t+.3));P.dust=t;P.jaw=.5+.15*Math.sin(TAU*2*t);P.snarl=1;P.pitch-=.04;
  P.tailA=.5+.16*Math.sin(TAU*(t+.15));P.tailW=.4*Math.sin(TAU*(t+.4));P.ear=1;P.maw2=.45+.2*Math.sin(TAU*2*t);
 }else if(anim==='idle'){
  const ph=t/2;P.breath=1+.07*Math.sin(TAU*ph*3);P.bob=.6+.5*Math.sin(TAU*ph*3);P.rx=.6*Math.sin(TAU*ph);
  P.feet=planted(V,[1.2,1,-1.2,-.8]);
  const sniff=Math.sin(TAU*ph),growl=sm(.48,.6,ph)*(1-sm(.82,.94,ph));
  P.neckA=.08*sniff-.12*growl;P.headP=.12+.1*Math.max(0,-sniff)+.05*Math.sin(TAU*ph*6)*(1-growl)-.06*growl;
  P.jaw=.08+.35*growl+.06*Math.sin(TAU*ph*8)*growl;P.snarl=growl;P.pitch=-.03*growl;
  P.tailA=.15+.12*Math.sin(TAU*ph);P.tailW=.15*Math.sin(TAU*ph*2);P.ear=growl;P.maw2=.25*growl+.1*(1+Math.sin(TAU*ph*3))/2;
  P.drool=ph>.18&&ph<.46?(ph-.18)/.28:-1;
 }else if(anim==='attack'){ // ramassé, bond de 15 px en cloche, morsure à l'atterrissage, secousse, petit saut de retour
  const u=t/.75,c=sm(0,.3,u),a=cl((u-.3)/.3),air=u>.3&&u<.6,hold=sm(.6,.66,u)*(1-sm(.72,.78,u)),r=cl((u-.76)/.24);
  const J=12,H=8;const jx=J*ease(a)*(1-ease(r)),jy=-H*Math.sin(Math.PI*a)-2.4*Math.sin(Math.PI*r);
  P.rx=-2.4*c*(1-sm(.3,.36,u))+jx;P.bob=2.6*c*(1-sm(.28,.36,u))+jy+1.2*sm(.58,.62,u)*(1-sm(.62,.7,u));
  P.pitch=-.1*c*(1-a)+(air?.28*(1-a)-.16*a:0)-.08*hold+.05*Math.sin(Math.PI*r);
  P.flex=c*1.2-(air?1.4*Math.sin(Math.PI*a):0)+.4*hold;P.air=air?1:0;
  const base=planted(V);
  P.feet=[0,1,2,3].map(i=>{const pl=base[i],f=HIND[i];
   if(u<=.3){pl.x+=f?-1.8*c:-.6*c;pl.th=f?lerp(-.25,.5,c):-.15}
   else if(air){pl.x+=P.rx+(f?-4.5*Math.sin(Math.PI*Math.min(1,a*1.4))-1:5.5*Math.sin(Math.PI*Math.min(1,a*1.3+.1)));pl.y=P.bob+(f?-1.5:-3.5*Math.sin(Math.PI*a));pl.th=f?lerp(1.1,.2,a):lerp(1.3,-.2,a)}
   else if(u<.76){pl.x+=J+(f?-1.2:.8);pl.th=f?-.1:-.15}
   else{const k=ease(r),lift=Math.sin(Math.PI*cl(r*1.25-(f?.2:0)));pl.x+=J*(1-k)+(f?-1.2:.8)*(1-k);pl.y=-3*lift;pl.th=f?lerp(-.1,-.25,k):lerp(-.15,.6,lift)}
   return pl});
  P.neckA=.25*c-.3*(air?Math.sin(Math.PI*a):0)+.15*hold+.18*Math.sin(TAU*cl((u-.62)/.14)*1.5)*hold;
  P.headP=.25*c-.25*(air?a:0)+.3*hold*Math.sin(TAU*cl((u-.62)/.14)*1.5);
  P.jaw=.35*c+(air?1.1*sm(0,.5,a):0)*(u<.6?1:0)+(u>=.6?.05+.3*r:0);P.snarl=1-r*.6;P.ear=1;
  P.maw2=.3*c+(air?1:0)+.15*hold;P.tailA=.4+.7*(air?Math.sin(Math.PI*a):0);P.tailW=.35*Math.sin(TAU*u*2);
  P.dustAt=u>.28&&u<.4?{x:-V.L,k:(u-.28)/.12}:u>.6&&u<.72?{x:V.L+J,k:(u-.6)/.12}:null;
 }else if(anim==='death'){ // il éclate dès le coup fatal : une image d'éclair blanc fendu de braise, puis les cendres
  const BURST=1/24;
  if(t>=BURST){P.burst=t-BURST;return P}
  const hit=.5,rear=0,glow=1;
  P.flash=1;P.glow=glow;P.breath=1+.14*glow;
  P.rx=-2.2*hit+(t>.3?Math.sin(t*95)*.7*glow:0);P.dropH=.3*rear;P.pitch=.16*hit*(1-sm(.1,.25,t))+.14*rear;
  P.feet=planted(V,[-1.5*hit,-1*hit-1.2*rear,-1.5*hit,-.8*hit-1.6*rear]);
  P.feet[3].y=-1.8*rear;P.feet[3].th=.6*rear;
  P.neckA=-.3*hit*(1-sm(.1,.25,t))-.55*rear;P.headP=-.15*hit-.35*rear;P.jaw=.9*hit*(1-sm(.12,.22,t))+1.1*rear;
  P.ear=1;P.snarl=1;P.maw2=.6*hit+.9*rear;P.tailA=.2+.6*rear;P.tailW=.4*Math.sin(TAU*t*3);
 }
 return P}

// ---------- dessin ----------
function draw(V,anim,t){
 const P=pose(V,anim,t);
 if(P.burst>=0)return explode(V,P.burst);
 const b=buf(FW,FH);
 const cx=AX+P.rx,fl=1-.1*P.flex;
 const ps=P.pitch*V.L;
 const dropF=P.dropF*(V.shH-V.chestDrop-V.chest[1]-.5),dropH=P.dropH*(V.hipH-V.hip[1]+.2);
 const hip={x:cx-V.L*fl,y:G-V.hipH+P.bob+ps+dropH},sh={x:cx+V.L*fl,y:G-V.shH+P.bob-ps+dropF};
 const lying=Math.min(P.dropF,P.dropH);
 const feet=P.feet.map((f,i)=>({x:cx-P.rx+f.x+(NEAR[i]?.6:-.6),y:G+f.y-(NEAR[i]?0:1.2),th:f.th}));
 const farB=-.3;
 // queue
 const tail=()=>{let x=hip.x-V.hip[0]*.6,y=hip.y-V.hip[1]*.45,a=Math.PI+V.tailA+P.tailA*.5;const n=V.tail;const pts=[];
  for(let i=0;i<=n;i++){pts.push([x,y]);const k=i/n;a+=(-.06+P.tailW*.08*Math.sin(k*3))*(V.id==='C'?-1:1)+(V.id==='B'?.035:0);x+=Math.cos(a);y+=Math.sin(a)}
  for(let i=0;i<pts.length-1;i++){const k=i/n;seg(b,pts[i][0],pts[i][1],pts[i+1][0],pts[i+1][1],lerp(V.tailR,.8,k),lerp(V.tailR,.8,k+1/n),V.skin,.05-k*.2)}
  if(V.spikes)for(let i=1;i<pts.length-1;i+=2){const[x2,y2]=pts[i];dot(b,x2,y2-V.tailR*.9-.4,'bone',.9)}
  if(V.id==='B'){const[x3,y3]=pts[pts.length-1];dot(b,x3-1,y3,'bone',.8)}};
 // pattes
 const leg=i=>{const f=feet[i],near=NEAR[i],bias=near?0:farB,r=V.legR;
  if(HIND[i]){const[l1,l2,l3]=V.hind;const top={x:hip.x+(near?.4:-.4),y:hip.y+.6};
   const hk={x:f.x-1+Math.sin(f.th)*l3,y:f.y-.6-Math.cos(f.th)*l3};const k=ik(top.x,top.y,hk.x,hk.y,l1,l2,-1);
   seg(b,top.x,top.y,k.jx,k.jy,r[0]+.9,r[0]*.85,V.skin,bias+.05);seg(b,k.jx,k.jy,k.ex,k.ey,r[1],r[2],V.skin,bias);
   seg(b,k.ex,k.ey,f.x,f.y-.6,r[2]*.9,r[2]*.9,V.skin,bias-.05);
   if(V.stripes&&near)for(let s=.25;s<.8;s+=.25){const x=lerp(top.x,k.jx,s),y=lerp(top.y,k.jy,s);over(b,x+1,y,'gore',.35);over(b,x+2,y-1,'gore',.3)}
   if(V.id==='C'&&near)over(b,k.jx,k.jy,'bete',.55);
   paw(f,bias,r[2])}
  else{const[l1,l2,l3]=V.fore;const top={x:sh.x+(near?-.6:-1.4),y:sh.y+1.4};
   const wr={x:f.x-.6+Math.sin(f.th)*l3,y:f.y-.6-Math.cos(f.th)*l3};const k=ik(top.x,top.y,wr.x,wr.y,l1,l2,1);
   seg(b,top.x,top.y,k.jx,k.jy,r[0]+.5,r[1]+.2,V.skin,bias+.08);seg(b,k.jx,k.jy,k.ex,k.ey,r[1],r[2]+.1,V.skin,bias);
   seg(b,k.ex,k.ey,f.x,f.y-.6,r[2],r[2]*.9,V.skin,bias-.05);
   if(near&&V.id!=='B')dot(b,k.jx-1,k.jy,'bone',.6); // coude osseux
   paw(f,bias,r[2])}};
 const paw=(f,bias,r)=>{blob(b,f.x+.6,f.y-.7,r+.5,1.05,V.skin,bias-.05);
  const air=f.y<G-1.6;if(!air){dot(b,f.x+r+1.4,f.y-.4,'bone',.85+bias);dot(b,f.x+r+.6,f.y-.2,'bone',.7+bias)}else dot(b,f.x+r+1,f.y-.2,'bone',.7+bias)};
 // torse
 const torso=()=>{
  const mx=(hip.x+sh.x)/2,my=(hip.y+sh.y)/2+V.sag-P.flex*1.3+.5;
  blob(b,hip.x,hip.y,V.hip[0],V.hip[1],V.skin,.04);
  blob(b,mx,my+.3,Math.abs(sh.x-hip.x)/2+1,V.loin,V.skin,.06);
  const chy=sh.y+V.chestDrop,cry=V.chest[1]*P.breath;
  blob(b,sh.x-.4,chy,V.chest[0],cry,V.skin,.1);
  // ventre rentré
  blob(b,mx+1,my+V.loin*.9,Math.abs(sh.x-hip.x)/2-1.5,1.4,V.skin,-.22,(x,y)=>y>=my+V.loin*.7);
  if(V.stripes){ // fibres musculaires à vif sur l'épaule et la cuisse
   for(let s=0;s<5;s++){const a=-1.05+s*.08;for(let r=1;r<V.chest[1]+1;r++){const x=sh.x-3+s*1.7+Math.cos(a)*r*.3,y=chy-cry+1+r;if(s%2===0)over(b,x,y,'gore',.42-r*.02)}}
   for(let s=0;s<3;s++)for(let r=0;r<4;r++)over(b,hip.x-2+s*2+r*.4,hip.y-2+r,'gore',.4);
   for(let x=Math.ceil(hip.x+2);x<sh.x-2;x+=3)over(b,x,my+V.loin*.4,'gore',.35)}
  if(V.ribs){ // cage ouverte : gueule intérieure barrée de côtes
   const rx0=sh.x-V.chest[0]*.75,rx1=sh.x+V.chest[0]*.35;blob(b,(rx0+rx1)/2,chy+.6,(rx1-rx0)/2+.8,cry*.62,'maw',-.25);
   for(let x=rx0+.8;x<=rx1;x+=2){const h=cry*.62;for(let y=-h;y<=h+.4;y+=.5){const xx=x+Math.sin((y/h)*1.3)*.7;over(b,xx,chy+.6+y,'bone',.85-y*.06)}}
   for(let i=0;i<4;i++)over(b,lerp(rx0,rx1,i/3)+.5,chy+cry*.58,'bone',.95);
   // peau pâle tendue sur le dos et la croupe
   for(let x=Math.floor(hip.x-3);x<sh.x+2;x++){const k=(x-hip.x)/(sh.x-hip.x),top=lerp(hip.y-V.hip[1],sh.y+V.chestDrop-cry,k)+(V.sag-P.flex*1.3)*Math.sin(Math.PI*cl(k))+.2;
    for(let y=0;y<2;y++)over(b,x,top+y+1,'pale',.62-y*.12-k*.1)}}
  if(V.wounds){ // plaies rouges dans la chair pâle
   const W=[[hip.x+1,hip.y-1,2.2,1.6],[mx+2,my-1,1.6,1.2],[sh.x-2.5,chy+1.5,2.4,2],[hip.x-2,hip.y+2,1.2,1]];
   for(const[x,y,rx,ry]of W){for(let yy=-ry;yy<=ry;yy++)for(let xx=-rx;xx<=rx;xx++){if((xx*xx)/(rx*rx)+(yy*yy)/(ry*ry)>1)continue;over(b,x+xx,y+yy,yy<0?'bete':'gore',.55-yy*.08)}}
   // touffe de poils dressés sur le garrot
   for(let i=0;i<6;i++){const x=sh.x-4+i*1.3,y=sh.y-cry+V.chestDrop-.2-Math.sin(i/5*Math.PI)*.8;dot(b,x,y,'bete',.5);if(i%2)dot(b,x-.6,y-1,'bete',.4)}}
  // crête d'échine
  if(V.spikes){for(let i=0;i<V.spikes;i++){const k=(i+.5)/V.spikes,x=lerp(hip.x-1,sh.x+.5,k);
   const top=(k<.5?lerp(hip.y-V.hip[1],my-V.loin,k*2):lerp(my-V.loin,sh.y+V.chestDrop-V.chest[1]*P.breath,k*2-1))-.2;
   const h=(V.id==='C'?1.4:1.8)+Math.sin(k*Math.PI)*1.4+(i%2?0:.6);for(let j=0;j<h;j++)dot(b,x-j*.45,top-j,'bone',.92-j*.08);dot(b,x+1,top,'bone',.55)}}
  if(V.shoulderMaw){ // seconde gueule sur l'épaule
   const ox=sh.x-2.2,oy=chy-cry*.45,op=.8+2.4*P.maw2;
   for(let y=-op-1.2;y<=op+1.2;y+=.5)for(let x=-4;x<=4;x+=.5){if((x*x)/16+(y*y)/((op+1.2)*(op+1.2))>1)continue;over(b,ox+x,oy+y,'bete',.5-y*.08)} // lèvres rouges
   for(let y=-op;y<=op;y+=.5)for(let x=-3.2;x<=3.2;x+=.5){if((x*x)/10.2+(y*y)/(op*op)>1)continue;over(b,ox+x,oy+y,'maw',.22-Math.abs(y)*.06)}
   for(let x=-2.4;x<=2.4;x+=1.2){over(b,ox+x,oy-op+.4,'bone',.95);if(op>1.3)over(b,ox+x+.6,oy+op-.4,'bone',.8)}}
  return{mx,my,chy,cry}};
 // cou + tête
 const head=()=>{
  const nb={x:sh.x+V.chest[0]*.45,y:sh.y+V.chestDrop-V.chest[1]*.35};
  const na=V.neckA+P.neckA+P.pitch*-.6;const hc={x:nb.x+Math.cos(na)*V.neck,y:nb.y+Math.sin(na)*V.neck};
  seg(b,nb.x-1,nb.y+1,hc.x,hc.y,V.neckR+.6,V.neckR*.8,V.skin,.08);
  if(V.stripes)for(let s=0;s<3;s++)over(b,lerp(nb.x,hc.x,.3+s*.2),lerp(nb.y,hc.y,.3+s*.2)+V.neckR*.6,'gore',.35);
  const ha=.12+P.headP;const dx=Math.cos(ha),dy=Math.sin(ha);
  const tip={x:hc.x+dx*(V.snout+V.head*.6),y:hc.y+dy*(V.snout+V.head*.6)};
  const jaw=cl(P.jaw)*(V.split?1.05:.85);const ja=ha+jaw*.9;
  const hinge={x:hc.x-dx*.5+.6,y:hc.y+V.head*.35};const jl=V.snout+V.head*.5;
  const jtip={x:hinge.x+Math.cos(ja)*jl,y:hinge.y+Math.sin(ja)*jl+.5};
  // gueule : intérieur entre les deux mâchoires
  if(jaw>.12){const n=10;for(let i=1;i<=n;i++){const k=i/n;const ux=lerp(hinge.x,tip.x,k),uy=lerp(hc.y+V.snoutR*.6,tip.y+V.snoutR*.5,k),lx=lerp(hinge.x,jtip.x,k),ly=lerp(hinge.y,jtip.y-.6,k);seg(b,ux,uy,lx,ly,.8,.8,'maw',-.15+k*.1)}}
  // mâchoire inférieure
  seg(b,hinge.x,hinge.y,jtip.x,jtip.y,V.jawR+.4,V.jawR*.8,V.skin,-.08);
  // crâne et museau
  blob(b,hc.x,hc.y,V.head+.5,V.head,V.skin,.16);
  seg(b,hc.x+dx*1.5,hc.y+dy*1.5-.4,tip.x,tip.y,V.snoutR+.5,V.snoutR*.85,V.skin,.14);
  if(V.split&&jaw>.4){ // museau fendu : la lèvre supérieure s'ouvre aussi
   for(let k=.45;k<=1;k+=.08)over(b,lerp(hc.x,tip.x,k),lerp(hc.y,tip.y,k)-.2,'maw',.25)}
  dot(b,tip.x+V.snoutR*.8,tip.y-.4,V.skin,.02); // truffe
  // dents
  const nT=Math.max(2,Math.round(V.snout/1.6));
  for(let i=0;i<nT;i++){const k=(i+1)/(nT+.6),ux=lerp(hc.x+dx*2,tip.x,k),uy=lerp(hc.y+V.snoutR*.7,tip.y+V.snoutR*.6,k);
   if(jaw>.1||P.snarl>.3||V.id==='A')dot(b,ux,uy+.6,'bone',.96-k*.1);
   if(jaw>.18){const lx=lerp(hinge.x+1,jtip.x,k),ly=lerp(hinge.y,jtip.y,k)-V.jawR*.7;dot(b,lx,ly-.4,'bone',.85)}}
  if(V.fangs){dot(b,tip.x-1.2,tip.y+V.snoutR*.6+1.4,'bone',.95);if(jaw>.3)dot(b,tip.x-1.2,tip.y+V.snoutR*.6+2.4,'bone',.85);if(jaw>.18)dot(b,jtip.x-1,jtip.y-V.jawR-1,'bone',.9)}
  if(P.snarl>.2){for(let k=.35;k<.85;k+=.14)over(b,lerp(hc.x,tip.x,k),lerp(hc.y,tip.y,k)-V.snoutR*.2,V.id==='C'?'bete':'gore',.35)} // plis du grognement
  // masque d'os (A)
  if(V.mask){blob(b,hc.x+.6,hc.y-.8,V.head*.95,V.head*.75,'bone',.12,(x,y)=>y<=hc.y+.4+(x-hc.x)*.15);
   for(let k=.15;k<.7;k+=.12)over(b,lerp(hc.x+2,tip.x,k),lerp(hc.y-1,tip.y,k)-V.snoutR*.7,'bone',.82-k*.4);
   dot(b,hc.x-1.5,hc.y-V.head-.2,'bone',.95);dot(b,hc.x-2.4,hc.y-V.head-.6,'bone',.9);dot(b,hc.x-3.4,hc.y-V.head-.4,'bone',.75); // corne
   blob(b,hc.x+1.4,hc.y-.7,1.3,1,'maw',-.1)}
  // oreilles
  const eb={x:hc.x-V.head*.6,y:hc.y-V.head*.7};
  if(V.ear==='torn'){const a=-2.3-P.ear*.5;seg(b,eb.x,eb.y,eb.x+Math.cos(a)*3,eb.y+Math.sin(a)*3,1.2,.8,V.skin,.05);dot(b,eb.x+Math.cos(a)*3.4,eb.y+Math.sin(a)*3.4-.3,V.skin,-.1)}
  if(V.ear==='long'){const a=-2.6-P.ear*.45+(anim==='walk'?.2:0);seg(b,eb.x+.8,eb.y+.4,eb.x+Math.cos(a)*5,eb.y+Math.sin(a)*5+1,1.1,.6,'pale',.2)}
  // yeux
  const ex=hc.x+dx*1.8+.8,ey=hc.y-V.head*.25+dy;
  if(V.eyes===1){dot(b,ex,ey,'fire',1);dot(b,ex-1,ey,'fire',.7)}
  if(V.eyes===2){dot(b,ex+.4,ey,'fire',.95);dot(b,ex+2,ey+.4,'fire',.75)}
  if(V.eyes===3){for(const[ox,oy,s]of[[-1.2,-1.6,1],[.4,-2.2,.9],[1.6,-1.2,.85],[-.2,-.6,.7],[-2.4,-.4,.6]])dot(b,hc.x+ox,hc.y+oy,'fire',s)}
  // bave
  if(P.drool>=0){const x=tip.x-1.6,y0=tip.y+V.snoutR*.6+1;const L2=1+P.drool*4;for(let y=0;y<L2;y++)dot(b,x,y0+y,'pale',.85-y*.08);if(P.drool>.75)dot(b,x,y0+L2+1.5,'pale',.7)}
  return{hc,tip}};
 // ordre : patte loin, queue, corps, pattes près, tête
 leg(0);leg(1);tail();const T=torso();
 leg(2);
 if(anim==='death'&&lying>.5){head();leg(3)}else{leg(3);head()}
 // modelé : la peau perd ses hautes lumières sauf sur l'arête du dos, le dessous s'assombrit
 const sk=MAT.indexOf(V.skin),gi=MAT.indexOf('gore');let top=new Int16Array(FW).fill(99);
 for(let y=0;y<FH;y++)for(let x=0;x<FW;x++){const i=y*FW+x;if(b.m[i]>=0&&top[x]===99)top[x]=y}
 for(let y=0;y<FH;y++)for(let x=0;x<FW;x++){const i=y*FW+x;if(b.m[i]!==sk&&b.m[i]!==gi)continue;const d=y-top[x];b.s[i]=d<=1?Math.max(b.s[i],.72):b.s[i]-.12-(y>G-V.hipH+4&&b.m[i]===sk?.06:0)}
 // fêlures de braise (mort) : la chaleur monte dans la chair
 if(P.glow>0)for(let y=0;y<FH;y++)for(let x=0;x<FW;x++){const i=y*FW+x;if(b.m[i]<0||b.m[i]===MAT.indexOf('bone'))continue;
  const n=Math.abs(Math.sin(x*.83+y*1.61)+Math.sin(x*.41-y*1.13+1.7));b.s[i]+=.12*P.glow;
  if(n<.34*P.glow)put(b,x,y,'fire',.55+P.glow*.4)}
 // poussière soulevée aux appuis
 if(P.dust>=0)for(let i=0;i<4;i++){const off=[.08,.58,0,.5][i],u=((P.dust+off)%1),k=u/.3;if(k>1)continue;const f=feet[i];
  for(let j=0;j<4;j++){const a=hash(i,j)*Math.PI,r=1+k*3.5*(.6+hash(j,i));dot(b,f.x-1-Math.cos(a)*r*1.2-k*2,f.y-.5-Math.sin(a)*r*.6,'dust',.7-k*.45)}}
 if(P.dustAt){const{x,k}=P.dustAt;for(let j=0;j<9;j++){const a=hash(j,7)*Math.PI,r=1+k*6*(.5+hash(7,j));dot(b,AX+x+Math.cos(a)*r*(j%2?1:-1),G-.5-Math.sin(a)*r*.5,'dust',.75-k*.5)}}
 // éclair blanc de l'impact
 if(P.flash)for(let i=0;i<b.m.length;i++)if(b.m[i]>=0)b.s[i]=Math.min(1,b.s[i]+.5);
 let out=b;
 if(P.melt>0)out=melt(b,P.melt,V);
 if(P.embers){const k=P.embers;for(let i=0;i<7;i++){const seed=i*7.13,life=((k*1.2+hash(i,3))%1);
   const x=AX-12+hash(i,1)*26+Math.sin(seed+k*6)*1.5,y=G-2-life*18;if(life<.85)dot(out,x,y,'fire',.95-life*.6)}}
 return out}

// Explosion de cendres : chaque pixel de la pose d'avant éclate en particule (braise puis cendre) ;
// les lourdes retombent en tas au sol, les flocons montent et s'éteignent, l'os retombe en éclats.
const burstBase=new Map();
function explode(V,tau){
 let b0=burstBase.get(V.id);if(!b0){b0=draw(V,'death',0);burstBase.set(V.id,b0)}
 const o=buf(FW,FH),bi=MAT.indexOf('bone');let sx=0,sy=0,n=0;
 for(let y=0;y<FH;y++)for(let x=0;x<FW;x++)if(b0.m[y*FW+x]>=0){sx+=x;sy+=y;n++}
 const cx=sx/n,cy=sy/n;
 // volutes de cendre : quelques boules qui gonflent, montent, s'amincissent puis disparaissent
 for(let i=0;i<4;i++){const life=.4+hash(i,11)*.3,k=tau/life;if(k>=1)continue;
  const a=-Math.PI*(.15+.7*hash(i,12)),d=3+10*ease(Math.min(1,k*1.6))*(.6+hash(i,13));
  const x=cx+Math.cos(a)*d*1.5+(hash(i,14)-.5)*8,y=cy+Math.sin(a)*d-6*k,r=(2+3.5*hash(i,15))*(k<.3?.5+k/.6:1-(k-.3)/.7*.85);
  if(r>.8)blob(o,x,y,r*1.15,r,'ash',.42-k*.3)}
 // tas de cendre et braises qui s'éteignent dedans
 const pk=sm(.1,.45,tau),pw=4+7*pk;
 if(pk>0)for(let x=Math.floor(cx-pw-1);x<=cx+pw+1;x++){const u=(x-cx)/pw,h=pk*3.4*Math.max(0,1-u*u)+(hash(x,4)>.7?pk:0);
  for(let y=0;y<h;y++){const ember=hash(x,y+20)>.82&&tau<.9+hash(x,2)*.4;put(o,x,G-y,ember?'fire':'ash',ember?.7-tau*.35:.28+y*.13)}}
 // onde de braise au sol
 if(tau<.13){const r=5+tau*110;for(let a=0;a<TAU;a+=.04){const x=cx+Math.cos(a)*r,y=G-1+Math.sin(a)*r*.22;if(hash(Math.round(a*40),3)>.35)dot(o,x,y,'fire',.95-tau*3)}}
 // éclats : la pose d'avant découpée en morceaux de 2 × 2 qui volent, brûlent puis retombent en cendre
 for(let y=0;y<FH;y+=2)for(let x=0;x<FW;x+=2){let m=-1,bone=false;for(let j=0;j<4;j++){const i=(y+(j>>1))*FW+x+(j&1);if(i<b0.m.length&&b0.m[i]>=0){m=b0.m[i];if(m===bi)bone=true}}
  if(m<0)continue;const r=hash(x,y),r2=hash(y+.5,x+3.1);
  const flake=!bone&&r>.72,ember=r<.2;
  let dx=x-cx,dy=y-cy-2;const L=Math.hypot(dx,dy)||1;dx/=L;dy/=L;
  const sp=bone?40+30*r2:30+50*r;const vx=dx*sp+(r2-.5)*18,vy=dy*sp-30-22*r2;
  let X,Y,size=bone?2:(tau<.15?2:tau<.4?(r>.4?2:1):1);
  if(flake){const k=3.2;X=x+vx*(1-Math.exp(-k*tau))/k+Math.sin(tau*6+r*9)*1.4;Y=y+vy*(1-Math.exp(-k*tau))/k-9*tau;if(tau>.35+r2*.45)continue;size=1}
  else{const k=1.4;X=x+vx*(1-Math.exp(-k*tau))/k;Y=y+vy*(1-Math.exp(-k*tau))/k+.5*160*tau*tau;
   if(Y>=G-1){Y=G-1;if(!bone&&tau>.25+r*.3)continue;if(bone&&(Math.abs(X-cx)>pw+4||tau>.7+r*.5))continue}   // la cendre lourde rejoint le tas
   if(X<0||X>FW-2)continue}
  let mat,s2;
  if(tau<.05){mat='fire';s2=.98}
  else if(ember&&tau<.3+r2*.35){mat='fire';s2=.9-tau*.8}
  else if(bone){mat='bone';s2=.72-Math.min(.25,tau*.2)}
  else{mat='ash';s2=.6-r*.2-Math.min(.2,tau*.2)}
  for(let j=0;j<size*size;j++)put(o,X+(j%size),Y+Math.floor(j/size),mat,s2)}
 return o}

// La chair fond : chaque colonne s'affaisse vers le sol ; les os restent plus longtemps ; une flaque s'étale.
function melt(b,k,V){const o=buf(b.w,b.h);const bi=MAT.indexOf('bone'),fire=MAT.indexOf('fire');
 // flaque
 const pw=lerp(8,19,ease(k)),ph=lerp(1.5,3.2,ease(k));
 for(let y=Math.floor(G-ph);y<=G+1;y++)for(let x=Math.floor(AX-pw);x<=Math.ceil(AX+pw+2);x++){const dx=(x+.5-AX-1)/pw,dy=(y+.5-(G-.6))/ph;if(dx*dx+dy*dy>1)continue;
  put(o,x,y,(hash(x,9)>.86?'gore':'bete'),.18+(1-dy)*.12-Math.abs(dx)*.1+(hash(x,y)>.93?.35:0))}
 for(let x=0;x<b.w;x++){const sink=k*(.75+.35*hash(x,1)),wob=Math.sin(x*.9+k*7)*k*.6;
  for(let y=0;y<b.h;y++){const i=y*b.w+x;if(b.m[i]<0)continue;const isBone=b.m[i]===bi||b.m[i]===fire;
   const s2=isBone?sink*.55:sink;const ny=Math.round(G-(G-y)*(1-s2)+wob);
   if(!isBone&&hash(x,y)<k*k*.7)continue;
   put(o,x,Math.min(G,ny),MAT[b.m[i]],isBone?b.s[i]:b.s[i]*(1-k*.45))}}
 // bulles
 for(let i=0;i<4;i++){const ph2=(k*2.5+hash(i,5))%1;if(ph2<.7){const x=AX-pw*.6+hash(i,2)*pw*1.4,r=.6+ph2;blob(o,x,G-ph-.3+ph2*.2,r,r*.8,'gore',.5)}}
 return o}

const cache=new Map();
function frame(v,anim,t){const A=ANIMS.find(a=>a.id===anim),i=Math.min(A.frames-1,Math.floor(t*24+1e-6)%A.frames),key=v+'|'+anim+'|'+i;
 let c=cache.get(key);if(!c){const V=VARIANTS.find(x=>x.id===v);c=render(draw(V,anim,i/24),1);cache.set(key,c)}return c}
return{VARIANTS,ANIMS,frame,FW,FH,AX,AY,STRIDE,G};
})();
