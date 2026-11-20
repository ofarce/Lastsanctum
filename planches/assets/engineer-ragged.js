// Ingénieur exilé, torse nu en pantalon déchiré, avant de recevoir sa combinaison
// (planches/ingenieur-pantalon-dechire-propositions.html). Même moteur 16 bits et même gabarit 32 × 34
// que engineer-colosse.js / engineer-exile.js (à charger avant). Expose RAGGED, ragged(), raggedPortrait().
'use strict';
R.rag=['#1a1712','#3a342a','#62594a','#8e836c','#bcb096'];   // toile écrue délavée
for(const m of['wool','brz','rag'])if(!MAT.includes(m))MAT.push(m);

// P = matière du pantalon ; foot = 'skin' (pieds nus) ou 'linen' (chiffons) ; trous = genou(x) percé(s).
const RAGGED={
 A:{name:'Chausses de l’Exil',sub:'torse nu, chausses de laine ardoise (celles du Templier) déchirées au genou et à mi-mollet, corde à la taille, pieds nus',
    P:'wool',foot:'skin',belt:'rope'},
 B:{name:'Le rescapé bandé',sub:'pantalon de toile écrue en lambeaux, bandage de lin en travers des côtes et à l’avant-bras, pieds enveloppés de chiffons',
    P:'rag',foot:'linen',belt:'rope',wrap:true},
 C:{name:'Le marqué',sub:'reste de la combinaison sarcelle arraché aux cuisses, cercle runique éteint tatoué sur la poitrine (là où viendra le plastron), pieds nus',
    P:'suit',foot:'skin',belt:'iron',mark:true},
};

// Options : dir 'd' | 's' | 'u', pose 'idle' | 'walk' | 'hurt' | 'kneel' | 'win',
// punch {ang, rec} = bras tendu poing nu ; hands 'pray' | 'knees' ; depth ; lotus ; blink ; ub.
function ragged(o){
 const{dir='d',f=0,pose='idle',v='A',punch=null,hands='',lotus=false,blink=false,ub=0}=o;const T=RAGGED[v],P=T.P;const b=buf(32,34);
 const step=pose==='walk'?[0,1,0,-1][f]:0, bob=pose==='walk'?(f%2?-1:0):0;
 const hurt=pose==='hurt', win=pose==='win';
 const depth=o.depth??(pose==='kneel'?4:0), kneel=depth>=2&&!lotus;
 const Yl=bob+depth+(hurt?1:0), Y=Yl+ub, X=16+(hurt?-1:0), S=dir==='s', U=dir==='u', D=dir==='d';
 // ---- jambes : pantalon déchiré, ourlet effiloché, tibia et pied nus
 const leg=(lx,ly,len,back,hole)=>{const s=back?-.25:0;
  rect(b,lx,ly,4,len,P,s);
  for(let x=0;x<4;x++)if((x+lx)%2===0)px(b,lx+x,ly+len,P,.35+s);            // franges de l'ourlet
  if(hole){px(b,lx+1,ly+2,'skin',.55+s);px(b,lx+2,ly+2,'skin',.4+s);px(b,lx+1,ly+1,P,.15+s)}  // genou percé
  for(let x=1;x<3;x++)if((x+lx)%2)px(b,lx+x,ly+len,'skin',.5+s);
  px(b,lx+1,ly+len+1,'skin',.6+s);px(b,lx+2,ly+len+1,'skin',.45+s);         // tibia
  rect(b,lx+(S?0:0),ly+len+2,S?5:4,1,T.foot,.1+s);if(S)px(b,lx+4,ly+len+2,T.foot,.7+s)}; // pied
 if(lotus){const k=Yl-2;rect(b,X-6,26+k,12,2,P,-.05);px(b,X-5,26+k,'skin',.5);rect(b,X-6,28+k,4,1,T.foot,-.1);rect(b,X+2,28+k,4,1,T.foot)}
 else if(!kneel){
  if(S){leg(X-2-step,22+Yl,5,true,false);leg(X-2+step,22+Yl,5,false,true)}
  else{leg(X-5,22+Yl+(step>0?-1:0),5-(step>0?1:0),false,!U);leg(X+1,22+Yl+(step<0?-1:0),5-(step<0?1:0),false,false)}
 }else{const k=Yl-2;rect(b,X-5,23+k,10,3,P,-.1);px(b,X+2,24+k,'skin',.5);rect(b,X-6,26+k,4,1,T.foot);rect(b,X+3,26+k,3,1,T.foot)}
 // ---- bras (peau), poing nu
 const arm=(ax,ay,dy,front)=>{const s=front?0:-.3;rect(b,ax-1,ay,3,4,'skin',s-.05);blob(b,ax+.5,ay+5+dy,1.7,1.6,'skin',s+.05);
  if(T.wrap&&front){px(b,ax-1,ay+3,'linen',.6+s);px(b,ax,ay+3,'linen',.75+s);px(b,ax+1,ay+3,'linen',.5+s)}};
 if(S&&!hands&&!punch)arm(X-2-step*.8,14+Y,0,false);
 // ---- bassin : haut du pantalon et ceinture (corde ou sangle de fer)
 const tw=S?4.5:6;
 rect(b,X-(S?4:5),20+Y,S?8:10,3,P,.05);
 if(T.belt==='rope'){for(let x=-(S?4:5);x<(S?4:5);x++)px(b,X+x,20+Y,'leath',(x&1)?.45:.7);if(!U){px(b,X+(S?2:1),21+Y,'leath',.6);px(b,X+(S?2:1),22+Y,'leath',.4)}}
 else{rect(b,X-(S?4:5),20+Y,S?8:10,1,'iron',.1);if(!U)px(b,X+(S?2:0),20+Y,'cy',.35)}
 // ---- torse nu
 blob(b,X+(S?.5:0),16.5+Y,tw,4.6,'skin',.02);
 if(D){ // pectoraux, sternum, abdominaux
  for(let x=1;x<=4;x++){px(b,X-x,16+Y,'skin',.2);px(b,X+x-1,16+Y,'skin',.25)}
  px(b,X,14+Y,'skin',.35);px(b,X,15+Y,'skin',.3);
  for(const yy of[18,19]){px(b,X-2,yy+Y,'skin',.3);px(b,X+1,yy+Y,'skin',.3)}
  px(b,X-5,18+Y,'scar',.55);px(b,X-4,19+Y,'scar',.45);                       // ecchymose aux côtes
 }else if(S){px(b,X+3,16+Y,'skin',.25);px(b,X+4,16+Y,'skin',.2);px(b,X+2,18+Y,'skin',.3);px(b,X-1,17+Y,'skin',.25)}
 else{for(let yy=13;yy<=19;yy++)px(b,X,yy+Y,'skin',.3);px(b,X-3,14+Y,'skin',.25);px(b,X+3,14+Y,'skin',.25);px(b,X-2,15+Y,'skin',.3);px(b,X+2,15+Y,'skin',.3);
  for(const[dx,dy]of[[-3,17],[-2,18],[2,16],[3,17]])px(b,X+dx,dy+Y,'scar',.55)} // marques de fouet dans le dos
 if(T.mark&&D){const cx=X,cy=16+Y;for(const[dx,dy]of[[0,-1],[1,0],[0,1],[-1,0]])px(b,cx+dx,cy+dy,'cy',.32);px(b,cx,cy,'cy',.5)}
 if(T.mark&&S){px(b,X+3,15+Y,'cy',.32);px(b,X+3,16+Y,'cy',.5)}
 if(T.wrap){ // bandage en écharpe : épaule gauche → hanche droite
  for(let i=0;i<9;i++){const sx=D?X-4+i:U?X+4-i:X-2+i*.6;if(S&&i<3)continue;px(b,sx,13+Y+i*.8,'linen',.7-i*.03);px(b,sx,14+Y+i*.8,'linen',.45)}}
 // ---- épaules nues et cou
 if(S)blob(b,X+1,13+Y,3,2.2,'skin',.15);
 else{blob(b,X-5.8,13+Y,2.8,2.2,'skin',.12);blob(b,X+5.8,13+Y,2.8,2.2,'skin',.08)}
 rect(b,X-2+(S?1:0),10+Y,S?3:4,3,'skin',.1);
 if(D){px(b,X-3,12+Y,'skin',.3);px(b,X-2,12+Y,'skin',.32);px(b,X+2,12+Y,'skin',.32);px(b,X+3,12+Y,'skin',.3)} // clavicules
 // ---- bras avant (face/dos)
 if(!S){
  const sw=pose==='walk'?step:0, L=X-8, Rr=X+7;
  arm(L,14+Y,sw,true);
  if(win){rect(b,Rr-1,9+Y,3,5,'skin',-.05);blob(b,Rr+.5,8+Y,1.7,1.6,'skin',.15)}
  else arm(Rr,14+Y,-sw,true);
 }
 // ---- tête : même visage, coupe à raie, tempes et nuque couvertes ; barbe de quelques jours
 const hx=X+(S?1:0),hy=6+Y+(hurt?1:0);
 if(U){blob(b,hx,hy,4.4,4.4,'skin',-.05);blob(b,hx,hy,4.8,4.6,'hair',.1,(x,y)=>y<=hy+3);px(b,hx-2,hy-4,'hair',1);px(b,hx-1,hy-4,'hair',.9);px(b,hx+2,hy-1,'hair',.85)}
 else{
  blob(b,hx,hy,4.4,4.3,'skin',.08);rect(b,hx-(S?2:3),hy+2,S?6:7,3,'skin',.05);
  if(S){blob(b,hx-.6,hy-1.2,4.8,3.8,'hair',.1,(x,y)=>y<=hy-1||x<=hx-1);rect(b,hx-4,hy+1,3,2,'hair',.05);px(b,hx+1,hy-4,'hair',1);px(b,hx+2,hy-4,'hair',.9);px(b,hx+3,hy-3,'hair',.7)}
  else{blob(b,hx,hy-1.2,4.9,3.8,'hair',.1,(x,y)=>y<=hy-2||(x<=hx-4||x>=hx+4)&&y<=hy+2);
   px(b,hx-2,hy-4,'hair',.05);px(b,hx-2,hy-3,'hair',.05);px(b,hx-1,hy-4,'hair',1);px(b,hx,hy-4,'hair',1);px(b,hx+1,hy-3,'hair',.85);px(b,hx+2,hy-2,'hair',.7)} // mèche tombante
  const eye=ex=>{if(blink){px(b,ex,hy,'skin',.12);px(b,ex+1,hy,'skin',.12)}else if(hurt){px(b,ex,hy,'eye',.1);px(b,ex+1,hy,'eye',.1)}else{px(b,ex,hy,'eye',.1);px(b,ex+1,hy,'eye',.98)}px(b,ex,hy-1,'hair',.05);px(b,ex+1,hy-1,'hair',.05)};
  if(S)eye(hx+2);else{eye(hx-3);eye(hx+1)}
  if(!S){px(b,hx-3,hy-2,'scar',.6);px(b,hx-2,hy+1,'scar',.6);px(b,hx-2,hy+2,'scar',.5)}else px(b,hx,hy+1,'scar',.6);
  // barbe naissante sur la mâchoire
  if(S){px(b,hx+1,hy+4,'hair',.45);px(b,hx+3,hy+4,'hair',.45);px(b,hx,hy+3,'hair',.35)}
  else for(const dx of[-3,-1,1,3])px(b,hx+dx,hy+4,'hair',.45);
  for(let x=-1;x<=1;x++)if(!S||x>=0)px(b,hx+x+(S?2:0),hy+3,'skin',.12);
  if(win&&!S){px(b,hx-2,hy+3,'skin',.12);px(b,hx+2,hy+3,'skin',.12)}
 }
 // ---- bras avant (profil)
 if(S&&hands==='pray'){rect(b,X+1,14+Y,3,3,'skin',-.05);blob(b,X+4,15.5+Y,1.7,1.6,'skin',.15)}
 else if(S&&hands==='knees'){rect(b,X+1,14+Y,3,4,'skin',-.05);blob(b,X+4.5,22+Yl-1,1.7,1.6,'skin',.1);blob(b,X-4.5,22+Yl-1,1.7,1.6,'skin',-.05)}
 else if(S&&punch){const c=Math.cos(punch.ang),sn=Math.sin(punch.ang),sx=X+1,sy=15+Y,r=punch.rec||0,L=6-r;
  for(let u=0;u<=L-1.5;u+=.5)for(let w=-1;w<=1;w+=.5)px(b,Math.round(sx+u*c-w*sn),Math.round(sy+u*sn+w*c),'skin',.55-w*.15);
  blob(b,sx+L*c,sy+L*sn,1.8,1.7,'skin',.15);
  if(T.wrap)px(b,Math.round(sx+(L-2)*c),Math.round(sy+(L-2)*sn),'linen',.7);
  if(punch.hit)for(const[dx,dy]of[[2,-2],[3,0],[2,2]])px(b,sx+(L+dx)*c,sy+L*sn+dy,'linen',1)}
 else if(S)arm(X+.5+step*.8,14+Y,0,true);
 if(hurt){px(b,X+8,1,'linen',1);px(b,X+9,0,'linen',.7);px(b,X+7,0,'linen',.7)}
 return b}

// Portrait 48 × 48 : même visage, épaules nues.
function raggedPortrait(v){const b=buf(48,48),cx=24,T=RAGGED[v];
 blob(b,cx,46,21,9,'skin',.02);blob(b,7,42,6,5,'skin',.12);blob(b,41,42,6,5,'skin',.02);rect(b,18,33,12,8,'skin',.08);
 for(let x=-9;x<=-3;x++)px(b,cx+x,40+(x>-6?1:0),'skin',.25);for(let x=3;x<=9;x++)px(b,cx+x,40+(x<6?1:0),'skin',.25); // clavicules
 px(b,cx,44,'skin',.3);px(b,cx,45,'skin',.3);
 if(T.wrap)for(let i=0;i<18;i++){px(b,10+i*1.4,38+i*.55,'linen',.75);px(b,10+i*1.4,39+i*.55,'linen',.5);px(b,10+i*1.4,40+i*.55,'linen',.3)}
 if(T.mark){for(const[dx,dy]of[[0,-2],[2,0],[0,2],[-2,0],[1,-1],[1,1],[-1,1],[-1,-1]])px(b,cx+dx,46+dy,'cy',.3);px(b,cx,46,'cy',.5)}
 if(!T.wrap&&!T.mark){px(b,12,45,'scar',.55);px(b,13,46,'scar',.45)}
 blob(b,cx,20,11,12,'skin',.08);rect(b,cx-10,22,20,10,'skin',.05);blob(b,cx,32,8,3,'skin',-.05);
 blob(b,cx,14,12,7,'hair',.1,(x,y)=>y<=15||((x<cx-9||x>cx+9)&&y<=27));
 for(let y=8;y<=13;y++)px(b,cx-4,y,'hair',.05);
 for(let x=-3;x<=6;x++)px(b,cx+x,8+(x>2?1:0),'hair',1);px(b,cx+5,12,'hair',.8);px(b,cx+6,13,'hair',.7);px(b,cx+6,15,'hair',.6);px(b,cx-8,11,'hair',.85);
 const eye=ex=>{for(let x=-1;x<4;x++){px(b,ex+x,19,'hair',.05);px(b,ex+x,20,'hair',.08)}for(let x=0;x<3;x++){px(b,ex+x,22,'eye',.15);px(b,ex+x,23,'eye',.35)}px(b,ex+1,22,'eye',.99);px(b,ex+2,23,'eye',.8)};
 eye(cx-8);eye(cx+5);
 for(let i=0;i<7;i++)px(b,cx-9+(i>>1),17+i,'scar',.6);
 px(b,cx,26,'skin',.15);px(b,cx+1,27,'skin',.12);for(let x=-3;x<=3;x++)px(b,cx+x,30,'skin',.08);
 for(let y=28;y<=34;y++)for(let x=-10;x<=10;x++){if(y<31&&Math.abs(x)<8)continue;if(y===34&&Math.abs(x)>7)continue;if(y===30&&Math.abs(x)<4)continue;
  px(b,cx+x,y,'skin',(x+y)&1?.2:.27)}                                                              // barbe de quelques jours (ombre de la mâchoire)
 for(let x=-3;x<=3;x++)px(b,cx+x,30,'skin',.06);
 px(b,cx+7,27,'scar',.5);px(b,cx+8,28,'scar',.4);                                                 // bleu à la pommette
 return b}
