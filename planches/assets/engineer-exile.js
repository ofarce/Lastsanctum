// Ingénieur à mains nues, tenues mêlant médiéval fantastique et technologie (planches/ingenieur-exil-propositions.html).
// Réutilise le moteur 16 bits de engineer-colosse.js (buf, blob, rect, px, render, mirror) ; expose EXILE, exile(), exilePortrait().
'use strict';
R.wool=['#141519','#272a33','#3e4250','#5a5f72','#848a9e'];   // drap de laine gris ardoise
R.brz=['#1e140e','#4a3020','#7a5236','#a8784e','#d4a878'];    // cuir bouilli / cuivre patiné (pas d'or)
MAT.push('wool','brz');

// Tenues : chaque piste combine une pièce « d'avant » (tabard, manteau, jaque) et une pièce tyrienne lumineuse.
const EXILE={
 A:{name:'Chevalier de l’Exil',sub:'tabard de laine à glyphe, épaulières de plates à rivets cyan, grèves d’acier',
    leg:'wool',boot:'iron',torso:'wool',sleeve:'suit',glove:'iron'},
 B:{name:'Templier technomancien',sub:'capuche de lin rabattue, plastron runique, manteau fendu, gantelets à circuits',
    leg:'wool',boot:'iron',torso:'suit',sleeve:'wool',glove:'iron'},
 C:{name:'Arpenteur des ruines',sub:'jaque de cuir sanglé, une grande épaulière tyrienne, écharpe, ceinture à outils',
    leg:'leath',boot:'leath',torso:'leath',sleeve:'linen',glove:'skin'},
};

// Options du jeu (vue de profil) : aim {ang (rad), rec, flash, pulse} = bras tendu, gantelet vers l'angle ;
// hands 'pray' | 'knees' ; depth 0..6 = agenouillement ; lotus = assis en tailleur ; blink = yeux clos ; ub = buste décalé.
function exile(o){
 const{dir='d',f=0,pose='idle',v='A',aim=null,hands='',lotus=false,blink=false,ub=0}=o;const T=EXILE[v];const b=buf(32,34);
 const step=pose==='walk'?[0,1,0,-1][f]:0, bob=pose==='walk'?(f%2?-1:0):0;
 const hurt=pose==='hurt', win=pose==='win';
 const depth=o.depth??(pose==='kneel'?4:0), kneel=depth>=2&&!lotus;
 const Yl=bob+depth+(hurt?1:0), Y=Yl+ub, X=16+(hurt?-1:0), S=dir==='s', U=dir==='u', D=dir==='d';
 // ---- jambes : chausses + bottes (grèves d'acier ou cuir à coque de fer)
 const leg=(lx,ly,len,back)=>{const s=back?-.25:0;rect(b,lx,ly,4,len,T.leg,s);rect(b,lx,ly+len,S?5:4,3,T.boot,s);
  if(T.boot==='iron'){px(b,lx+1,ly+len-1,'iron',.9+s);px(b,lx+1,ly+len+1,'cy',.55+s)}else{px(b,lx+(S?4:3),ly+len+2,'iron',.7+s);px(b,lx+1,ly+len,'brz',.8+s)}};
 if(lotus){const k=Yl-2;rect(b,X-6,26+k,12,2,T.leg,-.05);rect(b,X-6,28+k,5,2,T.boot,-.1);rect(b,X+1,28+k,5,2,T.boot);px(b,X+3,28+k,'cy',.55)}
 else if(!kneel){
  if(S){leg(X-2-step,22+Yl,5,true);leg(X-2+step,22+Yl,5,false)}
  else{leg(X-5,22+Yl+(step>0?-1:0),5-(step>0?1:0),false);leg(X+1,22+Yl+(step<0?-1:0),5-(step<0?1:0),false)}
 }else{const k=Yl-2;rect(b,X-5,23+k,10,3,T.leg,-.1);rect(b,X-6,25+k,5,3,T.boot);rect(b,X+2,25+k,4,3,T.boot)}
 // ---- bras arrière (profil)
 const arm=(ax,ay,dy,front)=>{const s=front?0:-.3;rect(b,ax-1,ay,3,4,T.sleeve,s);
  if(T.glove==='skin')blob(b,ax+.5,ay+5+dy,1.7,1.6,'skin',s);else{blob(b,ax+.5,ay+5+dy,1.9,1.7,T.glove,.1+s);if(v==='B')px(b,ax+.5,ay+5+dy,'cy',.7+s)}};
 if(S&&!hands)arm(X-2-step*.8,14+Y,0,false);
 // ---- B : manteau fendu sous la taille (dessiné derrière les jambes avant)
 if(v==='B'&&!kneel&&!lotus){if(S)rect(b,X-5,21+Y,3,5,'wool',-.1);else for(const sx of[-1,1])blob(b,X+sx*3.2,23.5+Y,3,3.5,'wool',-.05,(x,y)=>y>=21+Y)}
 // ---- torse
 const tw=S?5:6.5;
 blob(b,X,17+Y,tw,5,T.torso,.05);
 if(v==='A'){ // tabard : bande de lin centrale, glyphe cyan, ceinture de cuir, pans jusqu'aux genoux
  if(!S){rect(b,X-1,13+Y,3,8,'linen',.15);px(b,X,15+Y,'cy',.95);px(b,X-1,16+Y,'cy',.5);px(b,X+1,16+Y,'cy',.5);px(b,X,17+Y,'cy',.7)}
  rect(b,X-tw+1|0,20+Y,(tw*2-1)|0,2,'leath',.05);px(b,X+(S?2:0),20+Y,'iron',.9);
  if(!kneel){rect(b,X-(S?1:3),22+Y,S?4:6,4,'wool',.05);if(!S)rect(b,X-1,22+Y,3,4,'linen',.1)}
 }else if(v==='B'){ // plastron tyrien : cercle runique
  if(!U){const cx=X+(S?2:0);for(const[dx,dy]of[[0,-1],[1,0],[0,1],[-1,0]])px(b,cx+dx,16+Y+dy,'cy',.7);px(b,cx,16+Y,'cy',1)}
  else{rect(b,X-2,14+Y,4,5,'iron',.05);px(b,X,16+Y,'cy',.8)}
  rect(b,X-tw+1|0,20+Y,(tw*2-1)|0,2,'iron',-.05);
 }else{ // jaque de cuir : baudrier en diagonale, boucle de fer, ceinture à outils
  for(let i=0;i<8;i++){const sx=U?X+3-i:X-3+i;if(!S||i>2)px(b,sx,13+Y+i*.8,'brz',.55)}
  if(!U)px(b,X+(S?2:1),16+Y,'iron',.95);
  rect(b,X-tw+1|0,20+Y,(tw*2-1)|0,2,'brz',.1);
  if(!U){blob(b,X-(S?0:4),22+Y,1.5,1.4,'leath',.1);if(!S)blob(b,X+4,22+Y,1.5,1.4,'leath',.1);px(b,X+(S?1:-2),21+Y,'cy',.6)}
 }
 // ---- bras avant
 if(!S){
  const sw=pose==='walk'?step:0, L=X-8, Rr=X+7;
  arm(L,14+Y,sw,true);
  const r=aim?(aim.rec||0):0;
  if(win||(U&&aim)){ // bras levé ; tir vers le nord (de dos) : décharge au-dessus du gantelet
   rect(b,Rr-1,9+Y+r,3,5,T.sleeve);blob(b,Rr+.5,8+Y+r,1.9,1.7,T.glove==='skin'?'skin':T.glove,.15);if(v==='C'||aim)px(b,Rr,8+Y+r,'cy',.9);
   if(aim&&aim.flash)for(const[dx,dy,l]of[[0,-2,1],[1,-2,.9],[0,-3,.8],[-1,-3,.7],[1,-3,.7],[0,-4,.6]])px(b,Rr+dx,8+Y+r+dy,'cy',l)}
  else if(D&&aim){ // tir vers le sud (de face) : poing tendu vers le spectateur, décharge dessous
   rect(b,X+3,15+Y,3,3,T.sleeve);blob(b,X+4.5,19+Y-r*.5,2.2,2,T.glove==='skin'?'skin':T.glove,.2);px(b,X+4,19+Y-r*.5,'cy',aim.pulse?1:.8);
   if(aim.flash)for(const[dx,dy,l]of[[0,3,1],[1,3,.9],[0,4,.8],[-1,4,.7],[2,4,.7],[0,5,.6]])px(b,X+4+dx,19+Y-r*.5+dy,'cy',l)}
  else arm(Rr,14+Y,-sw,true);
  if(v==='C'&&!win)px(b,Rr,19+Y-sw,'cy',.8); // gantelet tyrien
 }
 // ---- épaules
 if(v==='A'){ // plates superposées, rivet cyan
  const pl=(cx,cy)=>{blob(b,cx,cy,3.4,2.6,'iron',.15);blob(b,cx,cy+2,3,1.4,'iron',-.05,(x,y)=>y>=cy+2);px(b,cx,cy,'cy',.75)};
  if(S)pl(X+1,12.5+Y);else{pl(X-6.5,12.5+Y);pl(X+6.5,12.5+Y)}
 }else if(v==='B'){ // mantelet de lin et capuche rabattue
  blob(b,X+(S?0:0),12.5+Y,S?5:8.5,2.8,'linen',.1);
  if(!U)for(let x=-2;x<=2;x++)px(b,X+x+(S?1:0),11+Y,'linen',.55);
  else blob(b,X,11+Y,3.4,2.4,'linen',.2);
 }else{ // une grande épaulière tyrienne côté gauche, cuir à droite ; écharpe de laine
  const big=D?X+6.5:X-6.5, small=D?X-6.5:X+6.5;
  if(S){blob(b,X+1,12.5+Y,2.8,2.2,'leath',.1)}
  else{blob(b,big,12+Y,4,3.2,'suit',.15);px(b,big-1,10+Y,'suit',1);px(b,big,13+Y,'cy',.8);px(b,big+(D?1:-1),12+Y,'cy',.5);blob(b,small,12.8+Y,2.6,2,'leath',.1)}
  blob(b,X+(S?1:0),11+Y,S?3.2:4.2,1.8,'wool',.2);if(!U&&!S)rect(b,X+1,12+Y,2,4,'wool',.1);
 }
 // ---- col
 if(v!=='B')rect(b,X-3,10+Y,6,1,v==='A'?'iron':'wool',.1);
 // ---- tête : coupe classique, raie sur le côté, tempes et nuque couvertes
 const hx=X+(S?1:0),hy=6+Y+(hurt?1:0);
 if(U){blob(b,hx,hy,4.4,4.4,'skin',-.05);blob(b,hx,hy,4.8,4.6,'hair',.1,(x,y)=>y<=hy+3);px(b,hx-2,hy-4,'hair',1);px(b,hx-1,hy-4,'hair',.9)}
 else{
  blob(b,hx,hy,4.4,4.3,'skin',.08);rect(b,hx-(S?2:3),hy+2,S?6:7,3,'skin',.05);
  if(S){blob(b,hx-.6,hy-1.2,4.8,3.8,'hair',.1,(x,y)=>y<=hy-1||x<=hx-1);rect(b,hx-4,hy+1,3,2,'hair',.05);px(b,hx+1,hy-4,'hair',1);px(b,hx+2,hy-4,'hair',.9)}
  else{blob(b,hx,hy-1.2,4.9,3.8,'hair',.1,(x,y)=>y<=hy-2||(x<=hx-4||x>=hx+4)&&y<=hy+2);
   px(b,hx-2,hy-4,'hair',.05);px(b,hx-2,hy-3,'hair',.05);px(b,hx-1,hy-4,'hair',1);px(b,hx,hy-4,'hair',1);px(b,hx+1,hy-3,'hair',.85)}
  const eye=ex=>{if(blink){px(b,ex,hy,'skin',.12);px(b,ex+1,hy,'skin',.12)}else if(hurt){px(b,ex,hy,'eye',.1);px(b,ex+1,hy,'eye',.1)}else{px(b,ex,hy,'eye',.1);px(b,ex+1,hy,'eye',.98)}px(b,ex,hy-1,'hair',.05);px(b,ex+1,hy-1,'hair',.05)};
  if(S)eye(hx+2);else{eye(hx-3);eye(hx+1)}
  if(!S){px(b,hx-3,hy-2,'scar',.6);px(b,hx-2,hy+1,'scar',.6);px(b,hx-2,hy+2,'scar',.5)}else px(b,hx,hy+1,'scar',.6);
  for(let x=-1;x<=1;x++)if(!S||x>=0)px(b,hx+x+(S?2:0),hy+3,'skin',.12);
  if(win&&!S){px(b,hx-2,hy+3,'skin',.12);px(b,hx+2,hy+3,'skin',.12)}
  if(v==='A')px(b,S?hx-2:hx+4,hy,'cy',.7);           // oreillette
  if(v==='C'){px(b,S?hx+3:hx+1,hy-1,'cy',.85);px(b,S?hx+4:hx+2,hy-1,'cy',.6)} // monocle-capteur
 }
 // ---- bras avant (profil), mains nues
 const glove=(x,y,l)=>{if(T.glove==='skin')blob(b,x,y,1.7,1.6,'skin');else{blob(b,x,y,1.9,1.7,T.glove,.12);px(b,x,y,'cy',l)}};
 if(S&&hands==='pray'){rect(b,X+1,14+Y,3,3,T.sleeve);glove(X+4,15.5+Y,.9)}
 else if(S&&hands==='knees'){rect(b,X+1,14+Y,3,4,T.sleeve);glove(X+4.5,22+Yl-1,.6);glove(X-4.5,22+Yl-1,.5)}
 else if(S&&aim){const c=Math.cos(aim.ang),sn=Math.sin(aim.ang),sx=X+1,sy=15+Y,r=aim.rec||0,L=6-r;
  for(let u=0;u<=L-1.5;u+=.5)for(let w=-1;w<=1;w+=.5)px(b,Math.round(sx+u*c-w*sn),Math.round(sy+u*sn+w*c),T.sleeve,.6-w*.15);
  const hx2=sx+L*c,hy2=sy+L*sn;glove(hx2,hy2,aim.pulse?1:.75);
  const mx=sx+(L+1.5)*c,my=sy+(L+1.5)*sn;if(aim.pulse)px(b,mx,my,'cy',1);
  if(aim.flash)for(const[dx,dy,l]of[[0,0,1],[1,0,.9],[0,-1,.8],[0,1,.8],[2,0,.6]])px(b,mx+dx*c-dy*sn,my+dx*sn+dy*c,'cy',l)}
 else if(S){arm(X+.5+step*.8,14+Y,0,true);if(v==='C')px(b,X+1+step*.8,19+Y,'cy',.8)}
 if(hurt){px(b,X+8,1,'cy',1);px(b,X+9,0,'cy',.7);px(b,X+7,0,'cy',.7)}
 return b}

// Portrait 48 × 48 : même visage, épaules selon la tenue.
function exilePortrait(v){const b=buf(48,48),cx=24;
 if(v==='A'){blob(b,8,43,9,6,'iron',.2);blob(b,40,43,9,6,'iron',.05);px(b,8,41,'cy',.9);px(b,40,41,'cy',.8);rect(b,14,39,20,9,'wool',.05);rect(b,21,39,6,9,'linen',.15);px(b,24,43,'cy',1);px(b,23,44,'cy',.6);px(b,25,44,'cy',.6);rect(b,17,35,14,4,'iron',.1)}
 else if(v==='B'){blob(b,24,44,22,7,'linen',.1);blob(b,24,38,11,4,'linen',.25);rect(b,18,42,12,6,'suit',.15);for(const[dx,dy]of[[0,-2],[2,0],[0,2],[-2,0]])px(b,24+dx,45+dy,'cy',.8);px(b,24,45,'cy',1)}
 else{blob(b,40,42,9,7,'suit',.15);px(b,39,39,'cy',.9);px(b,41,42,'cy',.6);blob(b,8,44,7,5,'leath',.1);rect(b,13,40,22,8,'leath',.05);for(let i=0;i<10;i++)px(b,16+i,47-i*.8,'brz',.6);blob(b,24,37,10,3.5,'wool',.2)}
 blob(b,cx,20,11,12,'skin',.08);rect(b,cx-10,22,20,10,'skin',.05);blob(b,cx,32,8,3,'skin',-.05);
 blob(b,cx,14,12,7,'hair',.1,(x,y)=>y<=15||((x<cx-9||x>cx+9)&&y<=27));
 for(let y=8;y<=13;y++)px(b,cx-4,y,'hair',.05);
 for(let x=-3;x<=6;x++)px(b,cx+x,8+(x>2?1:0),'hair',1);px(b,cx+5,12,'hair',.8);px(b,cx+6,13,'hair',.7);px(b,cx-8,11,'hair',.85);
 const eye=ex=>{for(let x=-1;x<4;x++){px(b,ex+x,19,'hair',.05);px(b,ex+x,20,'hair',.08)}for(let x=0;x<3;x++){px(b,ex+x,22,'eye',.15);px(b,ex+x,23,'eye',.35)}px(b,ex+1,22,'eye',.99);px(b,ex+2,23,'eye',.8)};
 eye(cx-8);eye(cx+5);
 for(let i=0;i<7;i++)px(b,cx-9+(i>>1),17+i,'scar',.6);
 px(b,cx,26,'skin',.15);px(b,cx+1,27,'skin',.12);for(let x=-3;x<=3;x++)px(b,cx+x,30,'skin',.08);
 for(let x=-8;x<=8;x+=3)px(b,cx+x,33,'skin',.25);
 if(v==='A'){px(b,cx+11,22,'cy',.8);px(b,cx+11,23,'cy',.5)}
 if(v==='C'){for(const[dx,dy]of[[0,-1],[1,0],[0,1],[-1,0],[1,-1],[-1,1],[1,1],[-1,-1]])px(b,cx+6+dx,22+dy,'cy',.6);px(b,cx+6,22,'cy',1)}
 return b}
