// Refonte 16 bits des personnages, alignée sur l'Ingénieur (Templier technomancien).
// Réutilise le moteur de engineer-colosse.js (R, MAT, buf, blob, rect, px, render, mirror) :
// rampes de 5 tons sans trame, contour coloré (ton le plus sombre de la matière), lumière en haut à gauche,
// même gabarit que l'Ingénieur (tête ~9 px, épaules rondes, pieds au même niveau, ~31 px de haut).
// Expose : FIG (fiches), fig(o) humanoïde, QUAD (fiches), quad(o) quadrupède, dedither(canvas) aperçu automatique.
'use strict';
Object.assign(R,{
 ind:['#2a0e04','#7a3008','#c25a12','#f08a2a','#ffc070'],   // orange d'Indra (caserne)
 or:['#2a1a04','#6e4a0c','#b08218','#e2b83a','#fff0a0'],    // or de Laetan (Credo Divin) — ennemis seulement
 crm:['#2e2418','#7a6a50','#b8a684','#e2d6b4','#fffaea'],   // lin crème des soldats de Laetan
 car:['#1e060c','#58101e','#8e1e2c','#c2384a','#ec6a74'],   // carmin de Laetan
 robe:['#121216','#2c2c34','#4a4a56','#706e7c','#a2a0ae'],  // bure grise des fidèles
 bete:['#1a0406','#5a0e12','#9a1c1c','#d83c2e','#ff8a66'],  // rouge de la Bête
 bone:['#2a2418','#6a5e46','#aa9c7c','#dcd2b4','#fffbe8'],
 fur:['#2a1606','#6e3e12','#ae6a24','#dc9a44','#ffd690'],   // félin fauve
 croc:['#0c1608','#24401a','#3e6a2a','#6a9a3e','#a8cc6a'],
 wood:['#1c1008','#4a2c14','#7a4c24','#a8743a','#d4a462'],
 fire:['#5a1404','#c23a08','#f2800e','#ffc83a','#fff6c0'],
 clay:['#24180e','#5e4024','#946a3c','#c49a5e','#ecd09a'],  // golem de terre (Brute)
});
MAT.push('ind','or','crm','car','robe','bete','bone','fur','croc','wood','fire','clay');

function line(b,x0,y0,x1,y1,mat,l){const n=Math.max(Math.abs(x1-x0),Math.abs(y1-y0))*2|0||1;
 for(let i=0;i<=n;i++){const t=i/n;px(b,Math.round(x0+(x1-x0)*t),Math.round(y0+(y1-y0)*t),mat,typeof l==='function'?l(t):l)}}
// écu : bord droit en haut, pointe en bas
function ecu(b,cx,y0,w,h,mat,trim,emb){for(let y=0;y<h;y++){const v=y/h,hw=v<.55?w/2:w/2*(1-(v-.55)/.45*.85);
 for(let x=Math.round(cx-hw);x<=Math.round(cx+hw)-1;x++){const u=(x-cx+hw)/(2*hw),edge=x===Math.round(cx-hw)||x===Math.round(cx+hw)-1||y===0;
  px(b,x,y0+y,edge&&trim?trim:mat,edge?.75-u*.3:.78-u*.45-v*.2)}}
 if(emb){const ey=y0+(h*.38|0);px(b,cx,ey-1,emb,.95);px(b,cx,ey,emb,.9);px(b,cx,ey+1,emb,.8);px(b,cx-1,ey,emb,.8);px(b,cx+1,ey-0,emb,.75)}}

// ---------- Fiches humanoïdes ----------
// head: bare | hood | helm | crest | sallet ; weapon: sword | bow | staff | dagger | flamer | spear
const FIG={
 lame:{name:'Épée et bouclier',side:'allié · caserne',skin:'skin',hair:'hair',head:'sallet',helm:'ind',visor:'iron',
  torso:'iron',tabard:'ind',sleeve:'iron',glove:'iron',leg:'wool',boot:'iron',paul:'iron',belt:'leath',
  weapon:'sword',shield:{mat:'ind',trim:'iron',emb:'iron'},tall:2},
 archer:{name:'Archer',side:'allié · caserne',skin:'skin',hair:'hair',head:'hood',hood:'ind',
  torso:'leath',sleeve:'leath',glove:'leath',leg:'wool',boot:'leath',cape:'ind',belt:'brz',weapon:'bow',quiver:true,tall:2},
 flammes:{name:'Lance-flammes',side:'allié · caserne',skin:'skin',head:'helm',helm:'iron',visor:'ind',
  torso:'ind',sleeve:'iron',glove:'iron',leg:'iron',boot:'iron',paul:'iron',bigpaul:true,belt:'leath',weapon:'flamer',tank:true,tall:2},
 creep:{name:'Fidèle',side:'Laetan · bas rang',skin:'skin',head:'hood',hood:'robe',torso:'robe',sleeve:'robe',glove:'skin',
  leg:'robe',boot:'leath',robe:'robe',belt:'car',weapon:'dagger'},
 spitter:{name:'Prêtre du Credo',side:'Laetan · sort à distance, portée moyenne (10)',skin:'skin',head:'hood',hood:'or',torso:'or',sleeve:'or',glove:'skin',
  leg:'car',boot:'leath',robe:'or',stole:'car',belt:'car',weapon:'staff'},
 scout:{name:'Éclaireur',side:'Laetan · rapide',skin:'skin',hair:'hair',head:'helm',helm:'crm',torso:'leath',sleeve:'crm',glove:'leath',
  leg:'leath',boot:'leath',belt:'car',sash:true,weapon:'sword',scarf:'car'},
 soldier:{name:'Soldat',side:'Laetan · pilum lancé, portée courte (5)',skin:'skin',head:'crest',helm:'crm',crest:'car',torso:'crm',sleeve:'crm',glove:'leath',
  leg:'crm',boot:'leath',skirt:'car',paul:'crm',belt:'or',weapon:'spear',pike:true},
 shield:{name:'Porte-bouclier',side:'Laetan · tank',skin:'skin',head:'crest',helm:'or',crest:'car',torso:'crm',sleeve:'crm',glove:'leath',
  leg:'crm',boot:'leath',skirt:'car',paul:'or',belt:'or',weapon:'sword',shield:{mat:'or',trim:'or',emb:'car',pavois:true}},
 larcher:{name:'Archer de Laetan',side:'Laetan · arc, portée moyenne (10)',skin:'skin',hair:'hair',head:'helm',helm:'crm',torso:'leath',sleeve:'crm',glove:'leath',
  leg:'car',boot:'leath',belt:'or',weapon:'bow',quiver:true,longbow:true},
};
// Formes-signatures des soldats de Laetan (planches/unites-maj-propositions.html, L2) : scarf = cape courte au vent
// (éclaireur), pike = pilum porté droit devant, plus haut que le cimier (soldat), pavois = grand bouclier du menton
// aux genoux (porte-bouclier), longbow = arc de la tête aux tibias (archer). tall = jambes allongées de n px
// (caserne, dessinée à l'échelle 1 dans le jeu).

function fig(o){
 const{k,dir='d',f=0,pose='idle'}=o;const T=FIG[k];const PAD=o.pad||[0,0],b=buf(40+2*PAD[0],38+PAD[1]);
 // o.pad [px, py] : marge autour du cadre (gestes amples). o.step : écart des pieds imposé (fente).
 // o.free {fa:[a1,a2], ba:[a1,a2], len, st} : bras articulés libres, de profil (animations de tir, tools/lanceurs).
 // Angles en degrés : 0 = vers le bas, 90 = devant, 180 = en haut, négatif = derrière ; len = longueur d'un segment ;
 // st = inclinaison du bâton (0 = droit, 90 = couché vers l'avant) ; la dague prolonge l'avant-bras.
 // Le tampon rendu porte b.an = {hand, handB, top} (main avant, main arrière, pointe du bâton ou de la dague).
 const FR=dir==='s'?o.free:null,RAD=Math.PI/180;
 const walk=pose==='walk',atk=pose==='atk',strike=pose==='strike',thr=pose==='throw',nw=!!o.nowpn;
 // Marche : 4 poses (f, caserne) ou phase continue o.ph ∈ [0, 1) (ennemis, 12 poses : pas de 2 px, appuis tenus).
 // Chaque phase est distincte : pied levé sur la jambe qui passe, bras en retard de 30°, choc de la tête au contact.
 const PH=walk&&o.ph!==undefined,phi=PH?o.ph*2*Math.PI:0,cs=Math.cos(phi);
 const step=o.step!==undefined?o.step:walk?(PH?Math.round(2*Math.sin(phi)):[0,1,0,-1][f]):0;
 const bob=walk?(PH?(Math.abs(cs)>.7?-1:0):(f%2?-1:0)):0;
 const liftF=PH&&cs>0&&Math.abs(step)<=1?1:0,liftB=PH&&cs<=0&&Math.abs(step)<=1?1:0;
 const armS=PH?1.6*Math.sin(phi-Math.PI/6):step*.8;
 if(PH&&Math.round(o.ph*12)%6===3)o={...o,hd:(o.hd||0)+1};
 const tall=T.tall||0,Yl=bob+3-tall+PAD[1],Y=Yl+(o.ub||0),X=20+PAD[0],S=dir==='s',D=!S;
 // o.hd : la tête descend d'autant de plus que le buste (respiration en trois temps, sans jour au cou).
 const hx=X+(S?1:0),hy=6+Y+(o.hd||0);
 // ---- dos : cape, réservoir
 // cape courte de l'éclaireur : flotte derrière les épaules (o.fl : battement 0 à 3)
 if(T.scarf&&S){const fl=o.fl!==undefined?o.fl:(walk?Math.round(1.5+1.5*Math.sin(phi*2)):0);
  for(let i=0;i<8;i++){const t=i/7,yy=12+Y+t*(3+[0,1,2,1][fl%4])+(i>4?[0,0,1,-1][fl%4]:0),th=i<3?3:i<6?2:1;
   for(let d=0;d<th;d++)px(b,X-3-i,Math.round(yy)+d,T.scarf,.7-t*.3-d*.12)}}
 if(T.scarf&&D)rect(b,X-5,12+Y,10,3,T.scarf,-.2);
 if(T.cape){if(D)rect(b,X-6,13+Y,12,13,T.cape,-.3);else blob(b,X-3,19+Y,3.5,7,T.cape,-.15,(x,y)=>y>=12+Y)}
 if(T.tank){if(D){rect(b,X-5,9+Y,3,6,'iron',-.2);rect(b,X+2,9+Y,3,6,'iron',-.2);px(b,X-4,9+Y,'ind',.8);px(b,X+3,9+Y,'ind',.8)}
  else{blob(b,X-5.5,16+Y,2.6,5,'iron',.05);px(b,X-6,13+Y,'ind',.9);px(b,X-6,18+Y,'ind',.6)}}
 if(T.quiver){if(D){line(b,X+3,8+Y,X+5,12+Y,'leath',.5);px(b,X+3,7+Y,'wood',.9);px(b,X+4,7+Y,'bone',.95)}
  else{rect(b,X-6,11+Y,3,8,'leath',-.05);px(b,X-6,10+Y,'bone',.95);px(b,X-5,10+Y,'wood',.9);px(b,X-4,9+Y,'bone',.9)}}
 // ---- jambes
 const leg=(lx,ly,len,back)=>{const s=back?-.25:0;rect(b,lx,ly,4,len,T.leg,s);rect(b,lx,ly+len,S?5:4,3,T.boot,s);
  if(T.boot==='iron')px(b,lx+1,ly+len-1,'iron',.9+s)};
 if(S){leg(X-2-step,22+Yl,5+tall-liftB,true);leg(X-2+step,22+Yl,5+tall-liftF,false)}
 else{leg(X-5,22+Yl+(step>0?-1:0),5+tall-(step>0?1:0),false);leg(X+1,22+Yl+(step<0?-1:0),5+tall-(step<0?1:0),false)}
 // ---- bras arrière (profil)
 const arm=(ax,ay,dy,s=0)=>{rect(b,ax-1,ay,3,4,T.sleeve,s);blob(b,ax+.5,ay+5+dy,1.8,1.6,T.glove,.1+s)};
 const farm=(sx,sy,a,s)=>{const L=FR.len||2.4,ex=sx+L*Math.sin(a[0]*RAD),ey=sy+L*Math.cos(a[0]*RAD),hx=ex+L*Math.sin(a[1]*RAD),hy=ey+L*Math.cos(a[1]*RAD);
  for(const[x0,y0,x1,y1]of[[sx,sy,ex,ey],[ex,ey,hx,hy]]){const n=Math.ceil(L*2);for(let i=0;i<=n;i++)blob(b,x0+(x1-x0)*i/n,y0+(y1-y0)*i/n,1.5,1.5,T.sleeve,s)}
  blob(b,hx,hy,1.8,1.6,T.glove,.1+s);return[hx,hy]};
 const an={};
 if(FR)an.handB=farm(X-1,14.5+Y,FR.ba,-.3);
 else if(S&&!(T.weapon==='bow'))arm(X-2-armS,14+Y,0,-.3);
 // ---- robe longue ou jupe
 if(T.robe){for(let y=19;y<=29;y++){const hw=(S?4.5:5.5)+(y-19)*.32;for(let x=Math.round(X-hw);x<Math.round(X+hw);x++){const u=(x-X+hw)/(2*hw);
   const fold=D&&((x-X+40)%4===0)&&y>22?-.12:0;px(b,x+(S?(y-19)*.1|0:0),y+Y,T.robe,.72-u*.45-(y-19)*.02+fold)}}}
 if(T.skirt&&!T.robe)for(let y=20;y<=24;y++){const hw=(S?4:6)+(y-20)*.3;for(let x=Math.round(X-hw);x<Math.round(X+hw);x++){const u=(x-X+hw)/(2*hw);px(b,x,y+Y,T.skirt,(x-X)%2?.55-u*.3:.7-u*.4)}}
 // ---- torse
 const tw=S?5:6.5;
 blob(b,X,17+Y,tw,5,T.torso,.05);
 if(T.tabard&&D){rect(b,X-2,13+Y,5,11,T.tabard,.1);px(b,X,16+Y,'iron',.9);px(b,X,17+Y,'iron',.6)}
 if(T.tabard&&S)rect(b,X+1,13+Y,3,11,T.tabard,.05);
 if(T.stole){if(D){rect(b,X-3,12+Y,2,14,T.stole,.1);rect(b,X+2,12+Y,2,14,T.stole,.05);px(b,X-3,17+Y,'or',.95);px(b,X+2,17+Y,'or',.9)}else rect(b,X+2,12+Y,2,13,T.stole,.1)}
 if(T.sash)line(b,X-4,13+Y,X+4,20+Y,'car',.6);
 if(k==='flammes'&&D){px(b,X,16+Y,'fire',.9);px(b,X-1,16+Y,'fire',.5);px(b,X+1,16+Y,'fire',.5)}
 if(T.belt)rect(b,X-tw+1|0,20+Y,(tw*2-1)|0,2,T.belt,.05);
 // ---- bras avant
 const W=T.weapon;
 const hand=D?[X+7.5,19+Y]:[X+1.5,19+Y]; // main d'arme
 if(D){
  const sw=walk?step:0;
  if(!T.shield&&!(W==='bow'))arm(X-8,14+Y,sw);
  if(atk&&(W==='sword'||W==='spear'||W==='staff'||W==='dagger')){rect(b,X+6,9+Y,3,5,T.sleeve);blob(b,X+7.5,8+Y,1.8,1.6,T.glove,.15);hand[1]=8+Y}
  else if(W!=='bow'&&W!=='flamer')arm(X+7,14+Y,-sw);
 }else{
  // o.mid : bras à mi-hauteur, en avant (élan ou armé) ; o.rec : retour de garde, main basse en avant.
  if(FR){}
  else if(atk&&o.mid&&W!=='bow'&&W!=='flamer'){rect(b,X+1,13+Y,3,3,T.sleeve);blob(b,X+4.5,12+Y,1.8,1.6,T.glove,.15);hand[0]=X+4.5;hand[1]=12+Y}
  else if(o.rec&&!strike&&!thr&&!atk&&W!=='bow'&&W!=='flamer'){rect(b,X+1,15+Y,3,3,T.sleeve);blob(b,X+4.5,18+Y,1.8,1.6,T.glove,.15);hand[0]=X+4.5;hand[1]=18+Y}
  else if(strike&&(W==='sword'||W==='dagger')){rect(b,X+1,15+Y,5,2,T.sleeve);blob(b,X+6.5,16+Y,1.8,1.6,T.glove,.15);hand[0]=X+6.5;hand[1]=16+Y}
  else if(thr){rect(b,X+1,12+Y,5,2,T.sleeve);blob(b,X+6.5,11+Y,1.8,1.6,T.glove,.15)}
  else if(atk&&W!=='bow'&&W!=='flamer'){rect(b,X,9+Y,3,5,T.sleeve);blob(b,X+1.5,8+Y,1.8,1.6,T.glove,.15);hand[1]=8+Y}
  else if(T.pike&&!nw){rect(b,X+1,15+Y,4,3,T.sleeve);blob(b,X+5.5,17+Y,1.8,1.6,T.glove,.15);hand[0]=X+5.5;hand[1]=17+Y}
  else if(W!=='bow'&&W!=='flamer'&&!T.shield)arm(X+.5+armS,14+Y,0);
 }
 // ---- épaules
 if(T.paul){const r=T.bigpaul?3.8:3.2;const pl=(cx,cy)=>{blob(b,cx,cy,r,T.bigpaul?3:2.5,T.paul,.15);if(T.bigpaul)px(b,cx,cy,'ind',.8)};
  if(S)pl(X+1,12.5+Y);else{pl(X-6.5,12.5+Y);pl(X+6.5,12.5+Y)}}
 else if(T.head!=='hood'){if(S)blob(b,X+1,12.8+Y,2.6,2,T.sleeve,.15);else{blob(b,X-6,13+Y,2.6,2,T.sleeve,.15);blob(b,X+6,13+Y,2.6,2,T.sleeve,.15)}}
 // ---- tête
 const face=()=>{blob(b,hx,hy,4.4,4.3,T.skin,.08);rect(b,hx-(S?2:3),hy+2,S?6:7,3,T.skin,.05)};
 const eyes=(m='eye')=>{if(S){px(b,hx+2,hy,m,.1);px(b,hx+3,hy,m,.95)}else for(const ex of[hx-3,hx+1]){px(b,ex,hy,m,.1);px(b,ex+1,hy,m,.95)}};
 const mouth=()=>{for(let x=-1;x<=1;x++)if(D||x>=0)px(b,hx+x+(S?2:0),hy+3,T.skin,.12)};
 if(T.head==='hood'){ // capuche : visage dans l'ombre, yeux visibles
  blob(b,hx-(S?1:0),hy-.5,5.4,5.2,T.hood,.12);
  blob(b,hx+(S?1.5:0),hy+1,S?2.6:3.4,3,T.skin,-.2);
  if(S){px(b,hx+3,hy+1,'eye',.95);px(b,hx+2,hy+1,'eye',.1)}else{px(b,hx-2,hy+1,'eye',.95);px(b,hx+2,hy+1,'eye',.95)}
  blob(b,hx,hy+5.5,S?3:5.5,1.6,T.hood,.05); // camail
  if(k==='spitter'){px(b,hx,hy-4,'car',.9);px(b,hx,hy-5,'or',1)}
 }else if(T.head==='bare'){face();eyes();mouth()}
 else{ // casques
  face();eyes();mouth();
  const H=T.helm;
  blob(b,hx,hy-1.6,4.9,3.6,H,.15,(x,y)=>y<=hy-1||(S?x<=hx-2:(x<=hx-4||x>=hx+4))&&y<=hy+2);
  rect(b,hx-(S?3:5),hy-1,S?8:10,1,H,.45); // bord du casque
  if(T.head==='crest'){for(let i=-3;i<=(S?1:3);i++)px(b,hx+(S?i-1:0),hy-5+(S?Math.abs(i+1)>2?1:0:0),T.crest,.85-(S?0:Math.abs(i)*.04));
   if(D){px(b,hx,hy-5,T.crest,.95);px(b,hx,hy-6,T.crest,.8);px(b,hx-1,hy-5,T.crest,.6);px(b,hx+1,hy-5,T.crest,.6)}
   else{for(let i=0;i<6;i++)px(b,hx-3+i,hy-5-(i<2?0:1),T.crest,.9-i*.06);px(b,hx-4,hy-4,T.crest,.6);px(b,hx-5,hy-3,T.crest,.5)}}
  if(T.head==='sallet'||T.visor){ // visière fermée
   for(let x=(S?0:-4);x<=(S?4:4);x++)px(b,hx+x,hy,T.visor||'iron',T.visor==='ind'?(x%2?.7:.95):.25);
   if(T.head==='sallet'){rect(b,hx-(S?1:4),hy+1,S?5:8,2,T.visor,.45);px(b,hx+(S?2:0),hy-4,T.helm,1)}
  }
 }
 // ---- armes et boucliers (au premier plan)
 // bras libres : bâton incliné tenu par la main avant, ou dague dans le prolongement de l'avant-bras ; le bras avant passe devant la tête
 if(FR){const W2=T.weapon,sa=(FR.st||0)*RAD,L=FR.len||2.4,h=[X+1.5+L*Math.sin(FR.fa[0]*RAD)+L*Math.sin(FR.fa[1]*RAD),14.5+Y+L*Math.cos(FR.fa[0]*RAD)+L*Math.cos(FR.fa[1]*RAD)];
  if(W2==='staff'){const tx=h[0]+13*Math.sin(sa),ty=h[1]-13*Math.cos(sa);line(b,h[0]-9*Math.sin(sa),h[1]+9*Math.cos(sa),tx,ty,'wood',.6);
   blob(b,tx,ty,1.8,1.8,'or',.25);px(b,Math.round(tx),Math.round(ty),'fire',FR.glow?1:.8);an.top=[tx,ty]}
  if(W2==='dagger'){const da=FR.fa[1]*RAD,tx=h[0]+5*Math.sin(da),ty=h[1]+5*Math.cos(da);line(b,h[0]+1.5*Math.sin(da),h[1]+1.5*Math.cos(da),tx,ty,'iron',.9);an.top=[tx,ty]}
  an.hand=farm(X+1.5,14.5+Y,FR.fa,0);b.an=an;return b}
 const [hx2,hy2]=hand;
 if(W==='sword'&&!strike&&!nw){if(atk){line(b,hx2,hy2-1,hx2+2,hy2-8,'iron',t=>.95-t*.2);px(b,hx2-1,hy2,'leath',.6);px(b,hx2+1,hy2,'leath',.6);px(b,hx2+2,hy2-9,'iron',1)}
  else{line(b,hx2+.5,hy2+1,hx2+3,hy2+8,'iron',t=>.9-t*.25);px(b,hx2-1,hy2+1,'leath',.55);px(b,hx2+2,hy2+1,'leath',.55)}}
 if(W==='dagger'&&!strike&&!nw){if(atk)line(b,hx2,hy2-1,hx2+1,hy2-4,'iron',.9);else line(b,hx2+.5,hy2+1,hx2+1.5,hy2+4,'iron',.85)}
 if(W==='spear'&&!thr&&!nw){const wy=o.wy||0,top=(atk?hy2-12:hy2-(T.pike&&S?19:15))+wy,xx=hx2+(atk?1:0);line(b,xx,hy2+(atk?4:9)+wy,xx,top+3,'wood',.6);
  px(b,xx,top+2,'iron',.95);px(b,xx,top+1,'iron',.9);px(b,xx,top,'iron',.8);px(b,xx-1,top+3,'iron',.6);px(b,xx+1,top+3,'iron',.6);px(b,xx,top+4,'car',.8)}
 if(W==='staff'){const xx=hx2+.5,top=atk?hy2-10:hy2-14;line(b,xx,hy2+9,xx,top+3,'wood',.6);
  blob(b,xx,top+1,1.8,1.8,'or',.25);px(b,xx,top+1,'fire',atk?1:.8);if(atk&&!o.mid){const fl=o.flick||0,sway=[0,1,0,-1][fl%4];for(const[dx,dy,l]of[[0,-2,1],[2,0,.9],[-2,0,.9],[0,-3,.7],[1,-2,.8],[-1,-2,.8]])px(b,xx+dx+(dy<-1?sway:0),top+1+dy,'fire',l);
  if(fl%3===1)px(b,xx+sway,top-3,'fire',.6);if(fl%3===2){px(b,xx+2,top-1,'fire',.75);px(b,xx-2,top-2,'fire',.55)}
  // o.burst : gerbe qui se dissipe après le sort (rayon croissant, de plus en plus clairsemée)
  if(o.burst){const r=o.burst;for(let a=0;a<8;a++){if(r>3&&a%2)continue;const an=a*Math.PI/4+r*.4;px(b,xx+Math.cos(an)*r,top+1+Math.sin(an)*r*.8,'fire',1-r*.1)}}}
  if(o.ember&&!atk){px(b,xx,top-1,'fire',.9);if(o.ember>1){px(b,xx-1,top,'fire',.7);px(b,xx+1,top-2,'fire',.6)}}}
 if(W==='bow'){ // arc tenu devant, corde
  const bx=D?X+7:X+6,by=16+Y,pull=atk?3:(o.pull||0); // pull < 0 : corde qui vibre en avant
  const BL=T.longbow?12:8,BC=T.longbow?4:3;
  for(let i=-BL;i<=BL;i++){const c=Math.round((1-(i/BL)**2)*BC);px(b,bx+c,by+i,'wood',.75-i*.02);if(T.longbow&&Math.abs(i)<2)px(b,bx+c+1,by+i,'car',.7)}
  for(let i=-BL+1;i<=BL-1;i++)px(b,bx-pull*(1-Math.abs(i)/(BL-1))|0,by+i,'bone',.95);
  if(D){arm(X-8,14+Y,0);rect(b,X+4,15+Y,3,2,T.sleeve);blob(b,bx+3,by,1.6,1.5,T.glove,.15)}
  else{rect(b,X+1,14+Y,bx-X,2,T.sleeve);blob(b,bx+3,by,1.6,1.5,T.glove,.15);if(pull>0||o.nock){blob(b,bx-pull,by,1.5,1.4,T.glove,.1);line(b,bx-pull,by,bx+6-pull,by,'wood',.7);px(b,bx+7-pull,by,'iron',.95)}
   // o.quiv : la main arrière va chercher une flèche au carquois (1 = à mi-chemin, 2 = au carquois)
   else if(o.quiv){const qx=o.quiv>1?X-4:X-1,qy=o.quiv>1?11+Y:13+Y;rect(b,Math.min(qx,X),13+Y,Math.abs(X-qx)+2,2,T.sleeve,-.1);blob(b,qx,qy,1.5,1.4,T.glove,.1);if(o.quiv>2){line(b,qx,qy,qx+1,qy-4,'wood',.7);px(b,qx+1,qy-5,'bone',.95)}}}
 }
 if(W==='flamer'){ // lance au niveau de la hanche, tuyau vers le réservoir
  if(D){rect(b,X+3,15+Y,3,4,T.sleeve);blob(b,X+4.5,20+Y,1.8,1.6,T.glove,.15);rect(b,X-7,15+Y,3,4,T.sleeve);blob(b,X-5.5,20+Y,1.8,1.6,T.glove,.1);
   rect(b,X-4,20+Y,10,2,'iron',.15);px(b,X+6,20+Y,'ind',.8);px(b,X+6,21+Y,'fire',.7);
   if(atk)for(const[dx,dy,l]of[[1,1,1],[2,2,.95],[2,3,.9],[3,4,.8],[1,3,.85],[3,2,.7],[4,5,.6]])px(b,X+5+dx,20+Y+dy,'fire',l)}
  else{rect(b,X,15+Y,3,4,T.sleeve);blob(b,X+2,20+Y,1.8,1.6,T.glove,.15);rect(b,X-1,19+Y,12,2,'iron',.2);rect(b,X+10,19+Y,2,2,'ind',.6);
   line(b,X-5,18+Y,X-1,20+Y,'leath',.4);
   if(o.pilot&&!atk){px(b,X+12,19+Y,'fire',.95);if(o.pilot>1)px(b,X+13,18+Y,'fire',.7);if(o.pilot>2)px(b,X+12,18+Y,'fire',.8)}
   if(atk)for(let i=0,fl=o.flick||0;i<6+fl%3;i++){px(b,X+12+i,19+Y+(i>3?(i&1):0),'fire',1-i*.07);if(i>1)px(b,X+12+i,20+Y-(i>4?1:0),'fire',.8-i*.06);if(i>4)px(b,X+12+i,18+Y,'fire',.6)}}}
 if(T.shield){const s=T.shield;
  const sy=o.sy||0;
  if(s.pavois){if(D)ecu(b,X-6,11+Y+sy,11,17,s.mat,s.trim,s.emb);
   else{ecu(b,X+6,11+Y+sy,9,17,s.mat,s.trim,s.emb);for(let y=3;y<13;y++)px(b,X+6,11+Y+sy+y,s.emb,.8-y*.02)}}
  else if(D)ecu(b,X-7,13+Y+sy,8,11,s.mat,s.trim,s.emb);
  else{ecu(b,X+5,13+Y+sy,5,11,s.mat,s.trim,null);px(b,X+6,17+Y+sy,s.emb,.85)}}
 // estoc (profil) : lame à l'horizontale devant le bouclier, traînée claire
 if(strike&&(W==='sword'||W==='dagger')){const L=W==='sword'?9:4;line(b,hx2+1,hy2,hx2+L,hy2+1,'iron',t=>.95-t*.15);px(b,hx2,hy2-1,'leath',.6);px(b,hx2,hy2+1,'leath',.6);
  if(o.swoosh)for(let a=-1.3;a<=.5;a+=.12){const r=W==='sword'?11:7,t=(a+1.3)/1.8;if(t<o.swoosh&&t>=(o.fade||0))px(b,X+1+Math.cos(a)*r,16+Y+Math.sin(a)*r,'bone',.6+t*.4)}}
 return b}

// Penche un tampon vers l'avant (lean > 0) ou l'arrière : chaque rangée glisse d'un nombre entier de pixels, de 0 au sol
// (gy) à lean px à h px de haut. Les pixels restent nets ; les repères b.an suivent.
function shear(b,lean,gy,h=19){if(!lean)return b;const o=buf(b.w,b.h),sh=y=>Math.round(lean*Math.max(0,gy-y)/h);
 for(let y=0;y<b.h;y++){const d=sh(y);for(let x=0;x<b.w;x++){const X=x+d;if(X<0||X>=b.w)continue;o.m[y*b.w+X]=b.m[y*b.w+x];o.s[y*b.w+X]=b.s[y*b.w+x]}}
 if(b.an){o.an={};for(const k in b.an)o.an[k]=[b.an[k][0]+lean*Math.max(0,gy-b.an[k][1])/h,b.an[k][1]]}return o}

// ---------- Quadrupèdes (profil) ----------
const QUAD={
 beast:{name:'La Bête',side:'Bête · meute',body:'bete',belly:'bone',rx:8,ry:4.4,hx:7,head:3.6,snout:3,spikes:'bone',eye:'fire',tail:7,leg:'bete',claw:'bone'},
 feline:{name:'Félin',side:'jungle · embuscade',body:'fur',belly:'bone',rx:8.5,ry:3.6,hx:8,head:3.2,snout:1.5,spots:'leath',ears:true,eye:'croc',tail:10,leg:'fur',claw:'fur',rich:true},
 croc:{name:'Crocodile',side:'rivière',body:'croc',belly:'bone',rx:11,ry:3.4,hx:10,head:2.8,snout:7,scutes:'croc',eye:'or',tail:12,leg:'croc',claw:'bone',low:true,rich:true},
};
function quad(o){const{k,f=0,pose='idle'}=o;const T=QUAD[k];const b=buf(48,28);
 const walk=pose==='walk',atk=pose==='atk';
 // Marche : 4 poses (f) ou phase continue o.ph (12 poses, pattes jusqu'à 2 px) ; o.tw : balancement de la queue.
 const sw=walk?(o.ph!==undefined?2*Math.sin(o.ph*2*Math.PI):[0,1,0,-1][f]):0;
 const PH=walk&&o.ph!==undefined,cs=PH?Math.cos(o.ph*2*Math.PI):0;
 const bob=walk?(PH?(Math.abs(sw)>=1.5?-1:0):(f%2?-1:0)):0,tw=(o.tw||0)+(PH?sw*.6:0);
 // patte qui passe levée d'un pixel (groupe 1 en avant quand cs > 0), tête qui accuse l'appui
 const lift1=PH&&cs>0&&Math.abs(sw)<1.5?1:0,lift0=PH&&cs<=0&&Math.abs(sw)<1.5?1:0,nod=PH&&Math.round(o.ph*12)%6===3?1:0;
 const br=o.br||0,cx=21,cy0=(T.low?20:15)+bob,cy=cy0+br,legH=T.low?3:6,G=cy0+T.ry+legH-1;
 // queue
 for(let i=0;i<=T.tail;i++){const t=i/T.tail;px(b,Math.round(cx-T.rx+1-i),Math.round(cy-1+(T.low?t*1.5:-Math.sin(t*2.4)*3+sw*.3*t+tw*t*t)),T.body,.6-t*.25);if(i<T.tail*.5)px(b,Math.round(cx-T.rx+1-i),Math.round(cy+(T.low?t*1.5:-Math.sin(t*2.4)*3)),T.body,.35);
  if(T.rich&&T.low&&i<T.tail-2){px(b,Math.round(cx-T.rx+1-i),Math.round(cy-1+t*1.5)+1,T.body,.3);if(i%2===0)px(b,Math.round(cx-T.rx+1-i),Math.round(cy-2+t*1.5),T.scutes,.95)}
  if(T.rich&&!T.low&&i>=T.tail-2)px(b,Math.round(cx-T.rx+1-i),Math.round(cy-1-Math.sin(t*2.4)*3+sw*.3*t+tw*t*t),'leath',.4)}
 // pattes arrière (sombres)
 const leg=(x,ph,back)=>{const s=back?-.3:0,o=Math.round(sw*(ph?1:-1)),lf=ph?lift1:lift0;for(let y=0;y<legH-br-lf;y++){px(b,x+o*(y/legH),cy+T.ry-2+y,T.leg,.5+s);px(b,x+1+o*(y/legH),cy+T.ry-2+y,T.leg,.35+s);if(T.rich)px(b,x-1+o*(y/legH),cy+T.ry-2+y,T.leg,(T.low?.7:.75)+s)}
  px(b,x+o+1,G-lf,T.claw,.85+s);px(b,x+o+2,G-lf,T.claw,.7+s)};
 leg(cx-T.rx+3,1,true);leg(cx+T.rx-4,0,true);
 // corps
 blob(b,cx,cy,T.rx,T.ry,T.body,.1);
 blob(b,cx+1,cy+T.ry*.55,T.rx*.75,T.ry*.4,T.belly,-.1,(x,y)=>y>=cy+T.ry*.4);
 if(T.spots)for(const[dx,dy]of[[-4,-1],[-1,-2],[2,-1],[5,-2],[-6,1],[0,0],[3,1]])px(b,cx+dx,cy+dy,T.spots,.5);
 if(T.spikes)for(let i=0;i<5;i++){const x=cx-5+i*2.6|0;px(b,x,cy-T.ry,T.spikes,.9);px(b,x+1,cy-T.ry-1,T.spikes,.95);if(i%2)px(b,x+1,cy-T.ry-2,T.spikes,.8)}
 if(T.scutes)for(let x=cx-T.rx+2;x<cx+T.rx-1;x+=2)px(b,x,cy-T.ry,T.scutes,.95);
 if(T.rich&&T.low){ // crocodile : crête dorsale en dents de scie, bande sombre sous la crête, plaques du flanc
  for(let x=cx-T.rx+2;x<cx+T.rx-2;x++){px(b,x,cy-T.ry+1,T.body,.28);if((x-cx+40)%3===0)px(b,x,cy-T.ry-1,T.scutes,1);if((x-cx+40)%4===1)px(b,x,cy,T.body,.5)}}
 if(T.rich&&!T.low){ // félin : épaule et cuisse en plans clairs, rosettes à deux tons, poitrail pâle
  blob(b,cx+T.rx-3,cy-.5,2.6,2.6,T.body,.28);blob(b,cx-T.rx+3.5,cy,3,2.8,T.body,.2);
  for(const[dx,dy]of[[-4,-1],[-1,-2],[2,-1],[5,-2],[-6,1],[0,0],[3,1]]){px(b,cx+dx,cy+dy,T.spots,.35);px(b,cx+dx+1,cy+dy,T.spots,.7)}
  px(b,cx+T.rx-1,cy+2,T.belly,.8);px(b,cx+T.rx,cy+1,T.belly,.9)}
 leg(cx-T.rx+4,0,false);leg(cx+T.rx-3,1,false);
 // tête
 const reach=o.reach!==undefined?o.reach:(atk?2:0),jaw=o.jaw!==undefined?o.jaw:atk;
 const hx=cx+T.rx+1+reach,hy=cy-(T.low?0:T.ry*.6)+(reach>0?1:0)+(o.nod||0)+nod;
 blob(b,hx,hy,T.head+.4,T.head,T.body,.18);
 const sn=T.snout;rect(b,hx+1,hy-(T.low?1:0),sn+2,T.low?2:2,T.body,.2);
 if(jaw||k==='beast'){rect(b,hx+1,hy+(T.low?1:2),sn+1,1,T.body,-.15);for(let x=0;x<=sn;x+=2)px(b,hx+2+x,hy+(T.low?1:2),'bone',.95)}
 if(jaw&&k==='croc')for(let x=0;x<sn;x+=2)px(b,hx+2+x,hy-2,'bone',.9);
 if(T.rich&&T.low){if(!jaw)for(let x=1;x<sn;x+=2)px(b,hx+2+x,hy+1,'bone',.9);px(b,hx,hy-T.head,T.body,.85);px(b,hx+1,hy-T.head,T.body,.7);px(b,hx+sn+2,hy-2,T.body,.8)}
 if(T.rich&&!T.low){px(b,hx+sn+1,hy+1,'bone',.9);px(b,hx+sn+2,hy+1,'bone',.8);px(b,hx-1,hy-T.head,'bone',.7)}
 px(b,hx+sn+3,hy-(T.low?1:0),T.body,.05); // truffe
 if(T.ears){px(b,hx-1,hy-T.head-1,T.body,.8);px(b,hx-1,hy-T.head,T.body,.6);px(b,hx+1,hy-T.head-1,T.body,.7)}
 if(k==='beast'){px(b,hx-2,hy-T.head,'bone',.95);px(b,hx-3,hy-T.head-1,'bone',.9);px(b,hx-4,hy-T.head-1,'bone',.75)}
 px(b,hx+1,hy-1-(T.low?1:0),T.eye,1);
 return b}

// ---------- Aperçu automatique pour les assets « à texture » (bâtiments, décor) ----------
// 1. dé-tramage : chaque pixel prend la couleur médoïde de son voisinage 3×3 (les grains isolés disparaissent) ;
// 2. paliers : luminosité ramenée à 5 paliers par teinte ;
// 3. contour coloré : le contour noir franc devient le ton sombre de la matière voisine.
function dedither(src,scale){
 const w=src.width,h=src.height,g=src.getContext('2d'),I=g.getImageData(0,0,w,h).data;
 const O=new Uint8ClampedArray(I.length);const A=(x,y)=>I[(y*w+x)*4+3];
 const lum=(r,gg,b2)=>.3*r+.59*gg+.11*b2;
 for(let y=0;y<h;y++)for(let x=0;x<w;x++){const i=(y*w+x)*4;if(I[i+3]<128){O[i]=I[i];O[i+1]=I[i+1];O[i+2]=I[i+2];O[i+3]=I[i+3];continue} // ombres portées gardées
  const n=[];for(let dy=-1;dy<=1;dy++)for(let dx=-1;dx<=1;dx++){const X=x+dx,Y=y+dy;if(X<0||Y<0||X>=w||Y>=h||A(X,Y)<128)continue;const j=(Y*w+X)*4;n.push([I[j],I[j+1],I[j+2]])}
  let best=n[0],bd=1e18;for(const a of n){let d=0;for(const c of n)d+=Math.abs(a[0]-c[0])+Math.abs(a[1]-c[1])+Math.abs(a[2]-c[2]);if(d<bd){bd=d;best=a}}
  // garde les petits détails lumineux (glyphes, braises) : écart fort et pixel plus clair que le médoïde
  const me=[I[i],I[i+1],I[i+2]];if(lum(...me)-lum(...best)>70)best=me;
  // paliers de luminosité (HSL)
  let[r,gg,b2]=best.map(v=>v/255);const mx=Math.max(r,gg,b2),mn=Math.min(r,gg,b2);let L=(mx+mn)/2;
  const q=Math.round(L*6)/6,k2=L>0?q/L:1;r=Math.min(1,r*k2);gg=Math.min(1,gg*k2);b2=Math.min(1,b2*k2);
  O[i]=r*255;O[i+1]=gg*255;O[i+2]=b2*255;O[i+3]=255}
 // contour : pixel presque noir au bord → ton sombre de la matière voisine
 const P=new Uint8ClampedArray(O);
 for(let y=0;y<h;y++)for(let x=0;x<w;x++){const i=(y*w+x)*4;if(!O[i+3])continue;if(lum(O[i],O[i+1],O[i+2])>34)continue;
  let edge=false,col=null;for(const[dx,dy]of[[1,0],[-1,0],[0,1],[0,-1]]){const X=x+dx,Y=y+dy;if(X<0||Y<0||X>=w||Y>=h||!O[(Y*w+X)*4+3]){edge=true;continue}
   const j=(Y*w+X)*4;if(lum(O[j],O[j+1],O[j+2])>40)col=[O[j],O[j+1],O[j+2]]}
  if(edge&&col){P[i]=col[0]*.38;P[i+1]=col[1]*.38;P[i+2]=col[2]*.42}}
 const c=document.createElement('canvas');c.width=w*scale;c.height=h*scale;const q2=c.getContext('2d');
 const t=document.createElement('canvas');t.width=w;t.height=h;t.getContext('2d').putImageData(new ImageData(P,w,h),0,0);
 q2.imageSmoothingEnabled=false;q2.drawImage(t,0,0,w*scale,h*scale);return c}
