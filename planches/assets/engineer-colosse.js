// Ingénieur « colosse en combinaison », dessin 16 bits partagé par planches/ingenieur-mana-planche.html
// et planches/ingenieur-colosse-export.html (sprites du jeu). Expose R, MAT, buf, render, hero, mirror, portrait.
'use strict';
// ---------- Palettes (rampes sombre → clair) ----------
const R={
 skin:['#5a2c1c','#a0583a','#d88e62','#f4c093','#ffe2bf'],
 hair:['#0e0a08','#1e1610','#2e2218','#423226','#5e4a3a'],
 linen:['#3a2a20','#8a6a48','#c8a676','#ecd6a4','#fff4d6'],
 sash:['#2a0e14','#6a1e2a','#a8323a','#d85a4a','#f6906a'],
 stone:['#1c1e26','#4a4c5a','#7a7e8c','#a8acb8','#dcdee6'],
 leath:['#20120a','#5a3418','#8a5428','#b67a3c','#dca460'],
 cy:['#0a3a48','#1f9fb8','#5ce8ff','#c8fbff','#ffffff'],
 eye:['#10101e','#1e2850','#3a5aa8','#7aa8f0','#ffffff'],
 suit:['#0e1a20','#1e3a44','#2f5a66','#4a8290','#8cc4cc'],
 scar:['#5a2c1c','#8a4030','#b05a44','#c87458','#e09070'],
 iron:['#141820','#3a4250','#646e80','#98a2b4','#d6dce8'],
};
const MAT=Object.keys(R);
// ---------- Tampon de pixels ----------
function buf(w,h){return{w,h,m:new Int8Array(w*h).fill(-1),s:new Float32Array(w*h)}}
function put(b,x,y,mat,s){x|=0;y|=0;if(x<0||y<0||x>=b.w||y>=b.h)return;b.m[y*b.w+x]=MAT.indexOf(mat);b.s[y*b.w+x]=s}
// ellipse ombrée : lumière en haut à gauche
function blob(b,cx,cy,rx,ry,mat,bias=0,cut){
 for(let y=Math.floor(cy-ry);y<=Math.ceil(cy+ry);y++)for(let x=Math.floor(cx-rx);x<=Math.ceil(cx+rx);x++){
  const dx=(x+.5-cx)/rx,dy=(y+.5-cy)/ry,d=dx*dx+dy*dy;if(d>1)continue;if(cut&&!cut(x,y))continue;
  const nz=Math.sqrt(1-Math.min(d,1));const l=(-dx*.55-dy*.65+nz*.75)*.62+.28+bias;put(b,x,y,mat,l)}}
function rect(b,x0,y0,w,h,mat,bias=0){for(let y=y0;y<y0+h;y++)for(let x=x0;x<x0+w;x++){const u=(x-x0+.5)/w,v=(y-y0+.5)/h;put(b,x,y,mat,.75-u*.45-v*.2+bias)}}
function px(b,x,y,mat,s){put(b,x,y,mat,s)}
// ---------- Rendu ----------
function render(b,scale){
 const c=document.createElement('canvas');c.width=b.w*scale;c.height=b.h*scale;c.style.background='transparent';
 const g=c.getContext('2d');const BY=[[0,8,2,10],[12,4,14,6],[3,11,1,9],[15,7,13,5]];
 const col=(i,x,y)=>{const r=R[MAT[b.m[i]]];let v=Math.max(0,Math.min(.999,b.s[i]))*(r.length-1.0001);let k=Math.floor(v);
  if(v-k>(BY[y&3][x&3]+.5)/16*0+.5)k++; /* pas de trame : paliers francs, à la manière 16 bits */
  return r[Math.min(Math.max(k,1),r.length-1)]};
 // remplissage
 for(let y=0;y<b.h;y++)for(let x=0;x<b.w;x++){const i=y*b.w+x;if(b.m[i]<0)continue;g.fillStyle=col(i,x,y);g.fillRect(x*scale,y*scale,scale,scale)}
 // contour sélectif : pixel vide touchant une matière → ton sombre de cette matière
 for(let y=0;y<b.h;y++)for(let x=0;x<b.w;x++){if(b.m[y*b.w+x]>=0)continue;let best=-1;
  for(const[dx,dy]of[[0,1],[1,0],[-1,0],[0,-1]]){const X=x+dx,Y=y+dy;if(X<0||Y<0||X>=b.w||Y>=b.h)continue;const j=Y*b.w+X;if(b.m[j]>=0){best=b.m[j];if(dy===-1||dx===-1)break}}
  if(best>=0){g.fillStyle=R[MAT[best]][0];g.fillRect(x*scale,y*scale,scale,scale)}}
 // liseré intérieur entre matières (bas/droite)
 for(let y=0;y<b.h-1;y++)for(let x=0;x<b.w-1;x++){const i=y*b.w+x,a=b.m[i];if(a<0)continue;
  const d=b.m[i+b.w],r=b.m[i+1];if((d>=0&&d!==a&&b.s[i+b.w]<b.s[i])){g.fillStyle=R[MAT[d]][1];g.fillRect(x*scale,(y+1)*scale,scale,scale)}}
 return c}
// ---------- Personnage (gabarit 32×34, pieds y≈31) ----------
// Colosse au visage nu (crâne rasé, mâchoire carrée, cicatrice) dans une combinaison blindée lisse :
// épaulières rondes surdimensionnées, plastron bombé, bras droit = canon lance-pitons, glyphes cyan.
// Options du jeu (vue de profil) : gun {ang (rad), rec, flash, pulse} = bolter orienté ; slung = bolter dans le dos ;
// hands 'pray' | 'knees' ; depth 0..4 = agenouillement ; lotus = assis en tailleur ; blink = yeux clos ; ub = buste décalé.
function hero(o){
 const{dir='d',f=0,pose='idle',gun=null,slung=false,hands='',lotus=false,blink=false,ub=0}=o;const b=buf(32,34);
 const step=pose==='walk'?[0,1,0,-1][f]:0, bob=pose==='walk'?(f%2?-1:0):0;
 const hurt=pose==='hurt', win=pose==='win', atk=pose==='atk';
 const depth=o.depth??(pose==='kneel'?4:0), kneel=depth>=2&&!lotus;
 const Yl=bob+depth+(hurt?1:0), Y=Yl+ub, X=16+(hurt?-1:0);
 // jambes blindées : cuisse, genouillère, botte massive
 const leg=(lx,ly,len,back)=>{const s=back?-.25:0;rect(b,lx,ly,4,len,'suit',s);px(b,lx+1,ly+2,'iron',.8+s);rect(b,lx-(dir==='s'?0:0),ly+len,dir==='s'?5:4,3,'iron',s);px(b,lx+1,ly+len+2,'cy',.5+s)};
 if(lotus){rect(b,X-6,26+Yl-2,12,2,'suit',-.05);rect(b,X-6,28+Yl-2,5,2,'iron',-.1);rect(b,X+1,28+Yl-2,5,2,'iron');px(b,X+4,28+Yl-2,'cy',.6)}
 else if(!kneel){
  if(dir==='s'){leg(X-2-step,22+Yl,5,true);leg(X-2+step,22+Yl,5,false)}
  else{leg(X-5,22+Yl+(step>0?-1:0),5-(step>0?1:0),false);leg(X+1,22+Yl+(step<0?-1:0),5-(step<0?1:0),false)}
 }else{const k=Yl-2;rect(b,X-5,23+k,10,3,'suit',-.1);rect(b,X-6,25+k,5,3,'iron');rect(b,X+2,25+k,4,3,'iron')}
 // bassin
 rect(b,X-5,20+Y,10,3,'iron',-.05);if(dir!=='u')px(b,X,21+Y,'cy',.8);
 // bras gauche (gant) et bras droit (canon)
 const fist=(ax,ay,front)=>{rect(b,ax-1,ay,3,4,'suit',front?0:-.3);blob(b,ax+.5,ay+5,1.9,1.7,'iron',front?0:-.25)};
 // bolter : boîtier massif, chargeur, bouche large ; tenu à deux mains
 const bolter=(x,y,ang,L,sh=0)=>{const c=Math.cos(ang),sn=Math.sin(ang);
  const P=(u,v,m,l)=>px(b,Math.round(x+u*c-v*sn),Math.round(y+u*sn+v*c),m,l);
  for(let u=0;u<=L;u++)for(let v=-1.5;v<=1.5;v+=.5){const top=v<-.9;P(u,v,u<3?'leath':(u>L-2?'iron':(top?'suit':'iron')),(top?.8:.55-v*.12)+sh)}
  for(let u=L*.35;u<=L*.55;u+=.5)for(let v=1.5;v<=3.5;v+=.5)P(u,v,'iron',.35+sh);   // chargeur
  for(let v=-1;v<=1;v+=.5)P(L+1,v,'iron',.15+sh);P(L+1,0,'cy',.9);P(L*.7,-1.5,'cy',.7)}; // bouche, voyant
 const grip=(x,y)=>blob(b,x,y,1.8,1.6,'iron',.15);
 if(dir==='s'&&slung)bolter(X-6,21+Y,-1.15,12,-.3);
 if(dir==='s')rect(b,X-3,14+Y,3,4,'suit',-.3);
 // plastron bombé
 const tw=dir==='s'?5:6.5;
 blob(b,X,17+Y,tw,5,'suit',.05);
 if(dir!=='u'){blob(b,X+(dir==='s'?1:0),16+Y,tw-2.5,3,'suit',.25);px(b,X+(dir==='s'?2:0),17+Y,'cy',.9);px(b,X+(dir==='s'?2:0)-1,17+Y,'cy',.5);px(b,X+(dir==='s'?2:0)+1,17+Y,'cy',.5)}
 else{rect(b,X-3,13+Y,6,6,'iron',.05);px(b,X-1,15+Y,'cy',.8);px(b,X+1,15+Y,'cy',.8);px(b,X,17+Y,'cy',.6)} // module dorsal
 // bras de face/dos
 if(dir==='d'){
  if(win){rect(b,X-9,14+Y,3,4,'suit');rect(b,X+6,12+Y,3,4,'suit');bolter(X+7,13+Y,-Math.PI/2,11);grip(X+7.5,12+Y);grip(X+7.5,17+Y)}
  else if(atk){rect(b,X-8,14+Y,3,4,'suit');rect(b,X+5,14+Y,3,4,'suit');bolter(X-4,19+Y,-.25,13);grip(X-3,19+Y);grip(X+6,17+Y)}
  else{const sw=pose==='walk'?step*.5:0;rect(b,X-9,14+Y,3,4,'suit');rect(b,X+6,14+Y,3,4,'suit');bolter(X-7,21+Y+sw,-.55,13);grip(X-6.5,19.5+Y+sw);grip(X+3,15.5+Y+sw)}
 }else if(dir==='u'){
  rect(b,X-9,14+Y,3,4,'suit',-.1);rect(b,X+6,14+Y,3,4,'suit',-.1);
  if(atk)bolter(X-10,15+Y,Math.PI+.1,4,-.2);else bolter(X+9,13+Y,-.6,3,-.2);
 }
 // épaulières rondes surdimensionnées
 const pauld=(cx,cy,s)=>{blob(b,cx,cy,3.6,3,'suit',.12+s);px(b,cx-1,cy-2,'suit',1);px(b,cx,cy+1,'cy',.55+s)};
 if(dir==='s'){pauld(X+1,12.5+Y,0)}else{pauld(X-6.5,12.5+Y,0);pauld(X+6.5,12.5+Y,0)}
 // col
 rect(b,X-3,10+Y,6,2,'iron',.1);
 // tête nue : crâne rasé, mâchoire carrée
 const hx=X+(dir==='s'?1:0),hy=6+Y+(hurt?1:0);
 // coupe classique : raie sur le côté, tempes et nuque couvertes
 if(dir==='u'){blob(b,hx,hy,4.4,4.4,'skin',-.05);blob(b,hx,hy,4.8,4.6,'hair',.1,(x,y)=>y<=hy+3);px(b,hx-2,hy-4,'hair',1);px(b,hx-1,hy-4,'hair',.9);px(b,hx+2,hy+1,'scar',.6)}
 else{
  blob(b,hx,hy,4.4,4.3,'skin',.08);rect(b,hx-(dir==='s'?2:3),hy+2,dir==='s'?6:7,3,'skin',.05); // mâchoire
  if(dir==='s'){blob(b,hx-.6,hy-1.2,4.8,3.8,'hair',.1,(x,y)=>y<=hy-1||x<=hx-1);rect(b,hx-4,hy+1,3,2,'hair',.05);px(b,hx-4,hy+1,'hair',.3);px(b,hx+1,hy-4,'hair',1);px(b,hx+2,hy-4,'hair',.9)}
  else{blob(b,hx,hy-1.2,4.9,3.8,'hair',.1,(x,y)=>y<=hy-2||(x<=hx-4||x>=hx+4)&&y<=hy+2);
   px(b,hx-2,hy-4,'hair',.05);px(b,hx-2,hy-3,'hair',.05);px(b,hx-1,hy-4,'hair',1);px(b,hx,hy-4,'hair',1);px(b,hx+1,hy-3,'hair',.85)} // raie + mèche
  const eye=ex=>{if(blink){px(b,ex,hy,'skin',.12);px(b,ex+1,hy,'skin',.12)}else{px(b,ex,hy,'eye',.1);px(b,ex+1,hy,'eye',.98)}px(b,ex,hy-1,'hair',.05);px(b,ex+1,hy-1,'hair',.05)};
  if(hurt){for(const ex of dir==='s'?[hx+2]:[hx-3,hx+1]){px(b,ex,hy,'eye',.1);px(b,ex+1,hy,'eye',.1)}}
  else if(dir==='s')eye(hx+2);else{eye(hx-3);eye(hx+1)}
  // cicatrice sur l'arcade gauche et bouche serrée
  if(dir!=='s'){px(b,hx-3,hy-2,'scar',.6);px(b,hx-2,hy+1,'scar',.6);px(b,hx-2,hy+2,'scar',.5)}else px(b,hx,hy+1,'scar',.6);
  for(let x=-1;x<=1;x++)if(dir!=='s'||x>=0)px(b,hx+x+(dir==='s'?2:0),hy+3,'skin',.12);
  if(win&&dir!=='s'){px(b,hx-2,hy+3,'skin',.12);px(b,hx+2,hy+3,'skin',.12)}
  // micro-oreillette cyan
  px(b,dir==='s'?hx-2:hx+4,hy,'cy',.7);
 }
 if(dir==='s'&&slung){if(hands==='pray'){grip(X+4,15.5+Y);px(b,X+4,13+Y,'cy',.7)}else if(hands==='knees'){grip(X-4,24+Yl-2);grip(X+5,24+Yl-2)}else grip(X+1,19+Y)}
 else if(dir==='s'&&gun){const c=Math.cos(gun.ang),sn=Math.sin(gun.ang),sx=X+1,sy=15+Y,r=gun.rec||0;
  bolter(sx-(3+r)*c,sy-(3+r)*sn,gun.ang,12);grip(sx+(1-r)*c,sy+1+(1-r)*sn);grip(sx+(6-r)*c,sy+1+(6-r)*sn);
  const mx=sx+(10-r)*c,my=sy+(10-r)*sn;if(gun.pulse)px(b,mx,my,'cy',1);
  if(gun.flash){for(const[dx,dy,l]of[[1,0,1],[2,0,.9],[1,-1,.8],[1,1,.8],[3,0,.6]])px(b,mx+dx*c-dy*sn,my+dx*sn+dy*c,'cy',l)}}
 else if(dir==='s'){if(atk){bolter(X-1,14+Y,0,13);grip(X+1,15.5+Y);grip(X+6,16+Y);px(b,X+15,13+Y,'cy',1);px(b,X+16,14+Y,'cy',.8);px(b,X+15,15+Y,'cy',1)}
  else{bolter(X-3,19+Y+step*.3,-.3,13);grip(X-1,18.5+Y+step*.3);grip(X+5,16.5+Y+step*.3)}}
 if(dir==='d'&&atk){px(b,X+9,14+Y,'cy',1);px(b,X+10,13+Y,'cy',.8);px(b,X+10,15+Y,'cy',.8)}
 if(hurt){px(b,X+8,1,'cy',1);px(b,X+9,0,'cy',.7);px(b,X+7,0,'cy',.7)}
 return b}
function mirror(b){const o=buf(b.w,b.h);for(let y=0;y<b.h;y++)for(let x=0;x<b.w;x++){const i=y*b.w+x,j=y*b.w+(b.w-1-x);o.m[j]=b.m[i];o.s[j]=b.m[i]>=0?b.s[i]*.9+.05:0}return o}
// ---------- Portrait 48×48 ----------
function portrait(){const b=buf(48,48),cx=24;
 blob(b,8,44,9,7,'suit',.15);blob(b,40,44,9,7,'suit',.05);rect(b,14,40,20,8,'suit',.1);px(b,24,44,'cy',.9);px(b,23,44,'cy',.5);px(b,25,44,'cy',.5);
 rect(b,17,35,14,5,'iron',.1);
 blob(b,cx,20,11,12,'skin',.08);rect(b,cx-10,22,20,10,'skin',.05);blob(b,cx,32,8,3,'skin',-.05);
 blob(b,cx,14,12,7,'hair',.1,(x,y)=>y<=15||((x<cx-9||x>cx+9)&&y<=27));
 for(let y=8;y<=13;y++)px(b,cx-4,y,'hair',.05);
 for(let x=-3;x<=6;x++)px(b,cx+x,8+(x>2?1:0),'hair',1);px(b,cx+5,12,'hair',.8);px(b,cx+6,13,'hair',.7);px(b,cx-8,11,'hair',.85);
 const eye=ex=>{for(let x=-1;x<4;x++){px(b,ex+x,19,'hair',.05);px(b,ex+x,20,'hair',.08)}for(let x=0;x<3;x++){px(b,ex+x,22,'eye',.15);px(b,ex+x,23,'eye',.35)}px(b,ex+1,22,'eye',.99);px(b,ex+2,23,'eye',.8)};
 eye(cx-8);eye(cx+5);
 for(let i=0;i<7;i++)px(b,cx-9+(i>>1),17+i,'scar',.6);
 px(b,cx,26,'skin',.15);px(b,cx+1,27,'skin',.12);for(let x=-3;x<=3;x++)px(b,cx+x,30,'skin',.08);
 for(let x=-8;x<=8;x+=3)px(b,cx+x,33,'skin',.25);
 px(b,cx+11,22,'cy',.8);px(b,cx+11,23,'cy',.5);
 return b}
