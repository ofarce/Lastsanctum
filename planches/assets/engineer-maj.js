// Ingénieur, mise à jour des sprites et des animations (planches/ingenieur-maj-propositions.html).
// Mêmes tenues validées (Templier technomancien, Chausses de l'Exil), même gabarit que l'export actuel :
// images 48 × 48, pieds en (24, 45), tourné vers la droite. Ce qui change : membres articulés (cuisse, tibia,
// bras, avant-bras) posés par cinématique inverse, pieds ancrés au sol, buste qui penche, manteau qui traîne.
// Dépend de engineer-colosse.js (R, MAT, buf, put, blob, rect, px), engineer-exile.js, engineer-ragged.js,
// engineer-cannon.js (cannonA). Expose eng(o), ENG_ANIMS, engFrame(nom, i, corps).
'use strict';
const DEG=Math.PI/180;
function capsule(b,x0,y0,x1,y1,r,mat,bias=0){const dx=x1-x0,dy=y1-y0,L2=dx*dx+dy*dy;
 for(let y=Math.floor(Math.min(y0,y1)-r);y<=Math.ceil(Math.max(y0,y1)+r);y++)for(let x=Math.floor(Math.min(x0,x1)-r);x<=Math.ceil(Math.max(x0,x1)+r);x++){
  const cx=x+.5,cy=y+.5;let t=L2?((cx-x0)*dx+(cy-y0)*dy)/L2:0;t=Math.max(0,Math.min(1,t));
  const ex=cx-(x0+t*dx),ey=cy-(y0+t*dy);if(Math.hypot(ex,ey)>r)continue;
  put(b,x,y,mat,.55+(-ex*.55-ey*.3)/r*.3+bias)}}
// Deux segments de x0,y0 vers x1,y1 : renvoie l'articulation (k) et l'extrémité atteinte (e). dir = côté du pli.
function ik2(x0,y0,x1,y1,l1,l2,dir){let dx=x1-x0,dy=y1-y0,d=Math.hypot(dx,dy)||.001;const m=l1+l2-.01;if(d>m){dx*=m/d;dy*=m/d;d=m}
 const a=(l1*l1-l2*l2+d*d)/(2*d),h=Math.sqrt(Math.max(0,l1*l1-a*a));
 return{kx:x0+dx*a/d+dir*h*dy/d,ky:y0+dy*a/d-dir*h*dx/d,ex:x0+dx,ey:y0+dy}}
const lerp=(a,b,t)=>a+(b-a)*t,lerp2=(p,q,t)=>[lerp(p[0],q[0],t),lerp(p[1],q[1],t)],ease=t=>t<.5?2*t*t:1-2*(1-t)*(1-t);

// ---------- Tête (visage validé, inchangé) ----------
function engHead(b,hx,hy,dir,o,exil){const S=dir==='s',U=dir==='u';
 if(U){blob(b,hx,hy,4.4,4.4,'skin',-.05);blob(b,hx,hy,4.8,4.6,'hair',.1,(x,y)=>y<=hy+3);px(b,hx-2,hy-4,'hair',1);px(b,hx-1,hy-4,'hair',.9);if(exil)px(b,hx+2,hy-1,'hair',.85);return}
 blob(b,hx,hy,4.4,4.3,'skin',.08);rect(b,hx-(S?2:3),hy+2,S?6:7,3,'skin',.05);
 if(S){blob(b,hx-.6,hy-1.2,4.8,3.8,'hair',.1,(x,y)=>y<=hy-1||x<=hx-1);rect(b,hx-4,hy+1,3,2,'hair',.05);px(b,hx+1,hy-4,'hair',1);px(b,hx+2,hy-4,'hair',.9);if(exil)px(b,hx+3,hy-3,'hair',.7)}
 else{blob(b,hx,hy-1.2,4.9,3.8,'hair',.1,(x,y)=>y<=hy-2||(x<=hx-4||x>=hx+4)&&y<=hy+2);
  px(b,hx-2,hy-4,'hair',.05);px(b,hx-2,hy-3,'hair',.05);px(b,hx-1,hy-4,'hair',1);px(b,hx,hy-4,'hair',1);px(b,hx+1,hy-3,'hair',.85);if(exil)px(b,hx+2,hy-2,'hair',.7)}
 const eye=ex=>{if(o.blink){px(b,ex,hy,'skin',.12);px(b,ex+1,hy,'skin',.12)}else if(o.hurt){px(b,ex,hy,'eye',.1);px(b,ex+1,hy,'eye',.1)}else{px(b,ex,hy,'eye',.1);px(b,ex+1,hy,'eye',.98)}px(b,ex,hy-1,'hair',.05);px(b,ex+1,hy-1,'hair',.05)};
 if(S)eye(hx+2);else{eye(hx-3);eye(hx+1)}
 if(!S){px(b,hx-3,hy-2,'scar',.6);px(b,hx-2,hy+1,'scar',.6);px(b,hx-2,hy+2,'scar',.5)}else px(b,hx,hy+1,'scar',.6);
 if(exil){if(S){px(b,hx+1,hy+4,'hair',.45);px(b,hx+3,hy+4,'hair',.45);px(b,hx,hy+3,'hair',.35)}else for(const dx of[-3,-1,1,3])px(b,hx+dx,hy+4,'hair',.45)}
 for(let x=-1;x<=1;x++)if(!S||x>=0)px(b,hx+x+(S?2:0),hy+3,'skin',.12)}

// ---------- Profil ----------
// o : body 'templier' | 'exil' ; dy = bassin abaissé (px) ; ub = buste abaissé ; lean = épaules avancées (px) ;
// hd [dx, dy] = tête ; legF / legB {x, lift, tilt} (pied par rapport au bassin) ou {K, A, lie} (points imposés) ;
// armF / armB {a, e} (angles en degrés depuis la verticale, + = vers l'avant), {to:[x, y]} ou {aim:{ang, rec, pulse, flash}} ;
// coat = traîne du pan arrière (px) ; rune, glow = éclat du cercle runique et du gantelet ; lotus ; blink ; hurt ;
// cannon {ang (deg), rec, flash} = Arbalestrie en main ; fx [[x, y, matière, lumière]…].
function engSide(o){
 const b=buf(48,48),TP=(o.body||'templier')==='templier',X=24;
 const dy=Math.round(o.dy||0),Yb=dy+(o.ub||0),lean=Math.round(o.lean||0),tx=X+Math.trunc(lean/2),hd=o.hd||[0,0];
 const glow=o.glow??.7,rune=o.rune??.7,hip=[X,37+dy],lotus=!!o.lotus,SL=TP?'wool':'skin';
 const leg=(L,far)=>{L=L||{};const s=far?-.25:0;let K,A;
  if(L.K){K=L.K;A=L.A}else{const r=ik2(hip[0],hip[1],hip[0]+(L.x||0),42-(L.lift||0),2.6,2.6,1);K=[r.kx,r.ky];A=[r.ex,r.ey]}
  const ax=Math.round(A[0]),ay=Math.round(A[1]),tl=c=>L.tilt>0?(c>=3?-1:0):L.tilt<0?(c<=1?-1:0):0;
  capsule(b,hip[0],hip[1],K[0],K[1],2.4,'wool',s);
  if(TP){capsule(b,K[0],K[1],A[0],A[1]+(L.lie?0:1),2.05,'wool',s);
   if(L.lie){rect(b,ax-2,ay-1,3,3,'iron',s-.1);px(b,ax-1,ay,'cy',.5+s)}
   else{for(let c=0;c<5;c++)for(let r=0;r<3;r++)put(b,ax-2+c,ay+r+tl(c),'iron',.75-c/5*.45-r/3*.2+s);
    px(b,ax-1,ay-1,'iron',.9+s);px(b,ax-1,ay+1,'cy',.55+s)}}
  else{const mx=(K[0]+A[0])/2,my=(K[1]+A[1])/2;
   capsule(b,K[0],K[1],A[0],A[1]+(L.lie?0:1),1.45,'skin',s-.05);capsule(b,K[0],K[1],mx,my,2.1,'wool',s);
   if(!L.lie){px(b,Math.round(mx)-2,Math.round(my)+2,'wool',.35+s);px(b,Math.round(mx),Math.round(my)+2,'wool',.35+s)}
   if(!far)px(b,Math.round(K[0]),Math.round(K[1]),'skin',.5);
   if(L.lie)rect(b,ax-2,ay,3,1,'skin',s);else for(let c=0;c<5;c++)put(b,ax-2+c,ay+2+tl(c),'skin',(c===4?.7:.45)+s)}};
 const hand=(x,y,far,l)=>{const s=far?-.3:0;if(TP){blob(b,x,y,2.1,1.9,'iron',.1+s);px(b,x,y,'cy',(l??glow)+s)}else blob(b,x,y,1.9,1.8,'skin',s+.05)};
 const arm=(A,far)=>{A=A||{};const s=far?-.3:0,sx=(far?X-2.5:X+.5)+lean,sy=29.5+Yb;
  if(A.aim){ // même géométrie que l'export actuel : épaule (25, 30), bras tendu de 6 − recul px, bouche à 7,5 px
   const m=A.aim,c=Math.cos(m.ang),sn=Math.sin(m.ang),ax=X+1+lean,ay=30+Yb,L=6-(m.rec||0);
   for(let u=0;u<=L-1.5;u+=.5)for(let w=-1.5;w<=1.5;w+=.5)px(b,Math.round(ax+u*c-w*sn),Math.round(ay+u*sn+w*c),u>L-3.2&&TP?'iron':SL,(TP?.6:.55)-w*.13+s);
   hand(ax+L*c,ay+L*sn,far,m.pulse?1:.75);
   const mx=ax+(L+1.5)*c,my=ay+(L+1.5)*sn;if(m.pulse&&TP)px(b,mx,my,'cy',1);
   if(m.flash)for(const[u,v,l]of[[0,0,1],[1,0,1],[0,-1,.85],[0,1,.85],[2,0,.8],[3,0,.6],[1,-2,.55],[1,2,.55]])px(b,mx+u*c-v*sn,my+u*sn+v*c,TP?'cy':'linen',l);
   return}
  let E,H;
  if(A.to){const r=ik2(sx,sy,A.to[0],A.to[1],2.7,2.7,-1);E=[r.kx,r.ky];H=[r.ex,r.ey]}
  else{const a=(A.a||0)*DEG,e=a+(A.e||0)*DEG;E=[sx+2.6*Math.sin(a),sy+2.6*Math.cos(a)];H=[E[0]+2.6*Math.sin(e),E[1]+2.6*Math.cos(e)]}
  if(!TP&&!far){capsule(b,sx-1,sy,E[0]-1,E[1],1.9,'skin',-.4);capsule(b,E[0]-1,E[1],H[0]-1,H[1]+.5,1.7,'skin',-.4)} // ombre qui détache le bras nu du torse
  capsule(b,sx,sy,E[0],E[1],1.9,SL,s);capsule(b,E[0],E[1],H[0],H[1],1.65,SL,s-.03);
  if(TP)capsule(b,(E[0]+H[0])/2,(E[1]+H[1])/2,H[0],H[1],1.75,'iron',s);     // manchette du gantelet
  hand(H[0],H[1],far)};
 // ---- plan arrière : bras et jambe éloignés
 if(!o.cannon)arm(o.armB,true);
 if(!lotus)leg(o.legB,true);
 // ---- pan arrière du manteau fendu (Templier) : suit le bassin, traîne à la marche, s'étale au sol à genoux
 if(TP&&!lotus){let ex=19.5-(o.coat||0),ey=40.5+dy;if(ey>43){ex-=1.5+(ey-43)*.6;ey=43}capsule(b,19.8+lean*.3,36.5+Yb,ex,ey,1.8,'wool',-.12)}
 if(!lotus)leg(o.legF,false);
 // ---- buste
 if(TP){
  blob(b,tx+.5,32+Yb,6.2,5.3,'suit',.05);blob(b,tx+2.5,30.5+Yb,3.4,2.6,'suit',.14);    // plastron bombé
  const cx=tx+3,cy=31+Yb;for(const[u,v]of[[0,-1],[1,0],[0,1],[-1,0]])px(b,cx+u,cy+v,'cy',rune);px(b,cx,cy,'cy',Math.min(1,rune+.3));
  rect(b,X-5,35+Yb,11,2,'iron',-.05);
  blob(b,X-4.2+lean,27+Yb,2.5,2.3,'linen',-.08);                             // capuche rabattue sur la nuque
  blob(b,X+.3+lean,27.6+Yb,6.3,3.1,'linen',.1);for(let x=-3;x<=3;x++)px(b,X+x+1+lean,26+Yb,'linen',.55);
 }else{
  rect(b,X-5,35+Yb,10,3,'wool',.05);for(let x=-5;x<5;x++)px(b,X+x,35+Yb,'leath',(x&1)?.45:.7);px(b,X+3,36+Yb,'leath',.6);px(b,X+3,37+Yb,'leath',.4);
  blob(b,tx+.3,31.4+Yb,5.7,4.9,'skin',.02);blob(b,tx+2.6,30+Yb,3.3,2.5,'skin',.1);                // dos large, pectoral
  for(let x=1;x<=5;x++)px(b,tx+x,32+Yb,'skin',.25);px(b,tx+3,34+Yb,'skin',.3);px(b,tx+4,34+Yb,'skin',.28);px(b,tx-3,31+Yb,'skin',.25);px(b,tx-3,33+Yb,'skin',.25);
  blob(b,X+.3+lean,28.3+Yb,4,2.9,'skin',.15);rect(b,X-1+lean,25+Yb,4,3,'skin',.08);
 }
 // ---- assis en tailleur : jambes croisées devant le bassin, manteau étalé derrière
 if(lotus){const gy=43;if(TP)blob(b,X-5,gy+.2,3.2,1.6,'wool',-.15);
  blob(b,X+1,gy-.3,7,2.2,'wool',-.22);blob(b,X+6,gy-1,2.4,2,'wool',-.1);
  if(TP){rect(b,X-2,gy,4,2,'iron',-.05);px(b,X,gy,'cy',.55);rect(b,X-7,gy,2,2,'iron',-.25)}
  else{rect(b,X-2,gy+1,4,1,'skin',.1);px(b,X+2,gy+1,'skin',.7);px(b,X+5,gy-1,'skin',.5);rect(b,X-7,gy+1,2,1,'skin',-.15)}}
 engHead(b,X+1+lean+hd[0],21+Yb+hd[1],'s',o,!TP);
 // ---- bras proche, Arbalestrie
 if(o.cannon){const m=o.cannon,c=Math.cos(m.ang*DEG),sn=Math.sin(m.ang*DEG),L=6-(m.rec||0),ax=X+1+lean,ay=30+Yb,hx=ax+L*c,hy=ay+L*sn;
  arm({aim:{ang:m.ang*DEG,rec:m.rec,pulse:m.flash}},false);
  for(let y=0;y<48;y++)for(let x=0;x<48;x++){const u=x+.5-hx,v=y+.5-hy,r=cannonA(u*c+v*sn,-u*sn+v*c);if(r)px(b,x,y,r[0],r[1])}
  blob(b,hx,hy,1.6,1.5,'iron',.15);px(b,hx,hy,'cy',m.flash?1:.7);
  blob(b,hx+4.5*c+1*sn,hy+4.5*sn+1.2*c,1.5,1.4,'iron',-.1);                // main gauche sous le tube
  if(m.flash){const mx=hx+11.5*c,my=hy+11.5*sn;for(const[u,v,l]of[[0,0,1],[1,0,1],[2,0,.85],[1,-1,.8],[1,1,.8],[3,0,.6],[2,-2,.5],[2,2,.5]])px(b,mx+u*c-v*sn,my+u*sn+v*c,'cy',l)}}
 else arm(o.armF,false);
 for(const[x,y,m,l]of o.fx||[])px(b,x,y,m,l);
 return b}

// ---------- Face et dos ----------
// o : dir 'd' | 'u' ; dy (négatif = se hausse) ; ub ; hd ; liftL, liftR = pied levé (px) ; sw = balancement des bras (px) ;
// sway = pans du manteau ; aim {rec, pulse, flash} ; rune ; glow ; blink.
function engFront(o){
 const b=buf(48,48),TP=(o.body||'templier')==='templier',U=o.dir==='u',D=!U,X=24;
 const dy=o.dy||0,Yb=dy+(o.ub||0),hd=o.hd||[0,0],glow=o.glow??.7,rune=o.rune??.7,sw=o.sw||0,sway=o.sway||0,aim=o.aim,r=aim?(aim.rec||0):0;
 const leg=(lx,lift,hole)=>{const ly=37+dy,len=5-dy-lift;
  if(TP){rect(b,lx,ly,4,len,'wool');rect(b,lx,ly+len,4,3,'iron');px(b,lx+1,ly+len-1,'iron',.9);px(b,lx+1,ly+len+1,'cy',.55);if(lift>=2)px(b,lx+1,ly+2,'wool',.95)}
  else{rect(b,lx,ly,4,len,'wool');for(let x=0;x<4;x++)if((x+lx)%2===0)px(b,lx+x,ly+len,'wool',.35);
   if(hole){px(b,lx+1,ly+2,'skin',.55);px(b,lx+2,ly+2,'skin',.4);px(b,lx+1,ly+1,'wool',.15)}
   for(let x=1;x<3;x++)if((x+lx)%2)px(b,lx+x,ly+len,'skin',.5);
   px(b,lx+1,ly+len+1,'skin',.6);px(b,lx+2,ly+len+1,'skin',.45);rect(b,lx,ly+len+2,4,1,'skin',.1)}};
 leg(X-5,o.liftL||0,!U);leg(X+1,o.liftR||0,false);
 const arm=(ax,d)=>{if(TP){rect(b,ax-1,29+Yb,3,4+Math.max(0,d),'wool');blob(b,ax+.5,34+Yb+d,1.9,1.7,'iron',.1);px(b,ax+.5,34+Yb+d,'cy',glow)}
  else{rect(b,ax-1,29+Yb,3,4+Math.max(0,d),'skin',-.05);blob(b,ax+.5,34+Yb+d,1.7,1.6,'skin',.05)}};
 if(TP){
  for(const s of[-1,1])blob(b,X+s*3.2+(s>0?Math.max(0,sway):Math.min(0,sway)),38.5+Yb,3,3.5,'wool',-.05,(x,y)=>y>=36+Yb);
  blob(b,X,32+Yb,6.5,5,'suit',.05);
  if(D){for(const[u,v]of[[0,-1],[1,0],[0,1],[-1,0]])px(b,X+u,31+Yb+v,'cy',rune);px(b,X,31+Yb,'cy',Math.min(1,rune+.3))}
  else{rect(b,X-2,29+Yb,4,5,'iron',.05);px(b,X,31+Yb,'cy',Math.min(1,rune+.1))}
  rect(b,X-6,35+Yb,12,2,'iron',-.05);
 }else{
  rect(b,X-5,35+Yb,10,3,'wool',.05);for(let x=-5;x<5;x++)px(b,X+x,35+Yb,'leath',(x&1)?.45:.7);if(D){px(b,X+1,36+Yb,'leath',.6);px(b,X+1,37+Yb,'leath',.4)}
  blob(b,X,31.5+Yb,6,4.6,'skin',.02);
  if(D){for(let x=1;x<=4;x++){px(b,X-x,31+Yb,'skin',.2);px(b,X+x-1,31+Yb,'skin',.25)}px(b,X,29+Yb,'skin',.35);px(b,X,30+Yb,'skin',.3);
   for(const yy of[33,34]){px(b,X-2,yy+Yb,'skin',.3);px(b,X+1,yy+Yb,'skin',.3)}px(b,X-5,33+Yb,'scar',.55);px(b,X-4,34+Yb,'scar',.45)}
  else{for(let yy=28;yy<=34;yy++)px(b,X,yy+Yb,'skin',.3);px(b,X-3,29+Yb,'skin',.25);px(b,X+3,29+Yb,'skin',.25);px(b,X-2,30+Yb,'skin',.3);px(b,X+2,30+Yb,'skin',.3);
   for(const[u,v]of[[-3,32],[-2,33],[2,31],[3,32]])px(b,X+u,v+Yb,'scar',.55)}
  blob(b,X-5.8,28+Yb,2.8,2.2,'skin',.12);blob(b,X+5.8,28+Yb,2.8,2.2,'skin',.08);rect(b,X-2,25+Yb,4,3,'skin',.1);
  if(D){px(b,X-3,27+Yb,'skin',.3);px(b,X-2,27+Yb,'skin',.32);px(b,X+2,27+Yb,'skin',.32);px(b,X+3,27+Yb,'skin',.3)}
 }
 const L=X-8,Rr=X+7,GL=TP?'iron':'skin',FL=TP?'cy':'linen';
 arm(L,sw);
 if(U&&aim){rect(b,Rr-1,24+Yb+r,3,5,TP?'wool':'skin');blob(b,Rr+.5,23+Yb+r,1.9,1.7,GL,.15);if(TP)px(b,Rr,23+Yb+r,'cy',.9);
  if(aim.flash)for(const[u,v,l]of[[0,-2,1],[1,-2,.9],[0,-3,.8],[-1,-3,.7],[1,-3,.7],[0,-4,.6],[-2,-4,.5],[2,-4,.5]])px(b,Rr+u,23+Yb+r+v,FL,l)}
 else if(D&&aim){rect(b,X+3,30+Yb,3,3,TP?'wool':'skin');blob(b,X+4.5,34+Yb-r*.5,2.2,2,GL,.2);if(TP)px(b,X+4,34+Yb-r*.5,'cy',aim.pulse?1:.8);
  if(aim.flash)for(const[u,v,l]of[[0,3,1],[1,3,.9],[0,4,.8],[-1,4,.7],[2,4,.7],[0,5,.6],[-2,5,.5],[3,5,.5]])px(b,X+4+u,34+Yb-r*.5+v,FL,l)}
 else arm(Rr,-sw);
 if(TP){blob(b,X,27.5+Yb,8.5,2.8,'linen',.1);if(D)for(let x=-2;x<=2;x++)px(b,X+x,26+Yb,'linen',.55);else blob(b,X,26+Yb,3.4,2.4,'linen',.2)}
 engHead(b,X+hd[0],21+Yb+hd[1],o.dir,o,!TP);
 for(const[x,y,m,l]of o.fx||[])px(b,x,y,m,l);
 return b}
function eng(o){return o.dir==='d'||o.dir==='u'?engFront(o):engSide(o)}

// ---------- Animations ----------
// Pied d'une jambe au fil du pas (p ∈ [0, 1)) : appui qui recule de +3,5 à −3,5 px, puis passage levé de 2 px.
function walkLeg(p){p=((p%1)+1)%1;if(p<.5)return{x:3.5-14*p,lift:0,tilt:p<.07?1:p>.42?-1:0};
 const s=(p-.5)*2;return{x:-3.5+7*s*s*(3-2*s),lift:2.2*Math.sin(Math.PI*s),tilt:s<.3?-1:s>.8?1:0}}
// Respiration en quatre temps : la tête mène, le buste suit.
function breath(i,n){const q=(i%n)/n;return q<.34?{ub:0,hd:[0,0]}:q<.5?{ub:0,hd:[0,1]}:q<.84?{ub:1,hd:[0,0]}:{ub:1,hd:[0,-1]}}
// Un genou à terre, assis sur le talon : bassin 5 px plus bas, genou avant relevé, tibia arrière couché, buste penché.
const KNEEL={dy:5,lean:2,legF:{x:4},legB:{K:[22.5,43.2],A:[18,43.2],lie:true}};
const REST_H=[24.5,34.7],ANGLES=[];for(let a=-90;a<=90;a+=10)ANGLES.push(a);
const pulse=(i,n)=>.6+.35*Math.sin(i/n*2*Math.PI);
function walkPose(i){const ph=i/12,c=Math.cos(2*Math.PI*ph-.4);
 return{legF:walkLeg(ph),legB:walkLeg(ph+.5),dy:Math.cos(4*Math.PI*ph)>.3?1:0,lean:1,coat:1+.9*Math.cos(4*Math.PI*ph-1),
  armF:{a:-30*c,e:14+14*Math.max(0,-c)},armB:{a:30*c,e:14+14*Math.max(0,c)}}}
const ENG_ANIMS={
 idle:{n:72,cols:12,fps:12,note:'repos : souffle en quatre temps, cercle runique qui bat, clignements, geste d’attente toutes les 6 s',
  f:(i,TP)=>{const o={...breath(i,24),blink:i===30||i===31||i===67,rune:pulse(i,24)};
   if(i>=38&&i<62){const t=i-38,k=ease(Math.min(1,t/5,(24-t)/5));
    if(TP){o.armF={to:lerp2(REST_H,[28.2,30.6],k)};if(k>.9){o.hd=[0,1];o.ub=0}const hot=t>=8&&t<15;o.glow=hot?1:.7;
     if(hot)o.fx=[[28+(t%2),28-((t-8)>>1),'cy',1-(t-8)*.08],[29-(t%3),27-((t-8)>>1),'cy',.7]]}
    else{o.armF={to:lerp2(REST_H,[27.6,26.4],k)};if(k>.9)o.blink=t%8<5}}
   return o}},
 walk:{n:12,cols:12,note:'marche : 12 poses, foulée de 7 px, pied levé, bras opposés, pan du manteau qui traîne',f:i=>walkPose(i)},
 kneel:{n:36,cols:12,fps:12,note:'un genou à terre, tête basse, souffle court (24), puis se relève (12)',
  f:i=>{if(i<24){const q=i%12;return{...KNEEL,ub:q<5?0:1,hd:[1,q<3?2:q<5?1:q<10?2:3],blink:q>8,armF:{to:[28.5,40+(q<5?0:1)]},armB:{to:[24.5,42]},
    fx:q>=6&&q<=9?[[33+(q-6),31+(q<8?0:-1),'stone',.95-(q-6)*.1]]:[]}}
   const t=1-ease((i-23)/12),o={dy:5*t,lean:Math.round(2*t),legF:{x:4*t},hd:[t>.5?1:0,Math.round(2*t)]};
   o.legB=t>.4?{K:lerp2([24.5,39.5],[22.5,43.2],t),A:lerp2([24,42],[18,43.2],t),lie:true}:{x:-2*t};
   if(t>.2){o.armF={to:lerp2(REST_H,[28.5,40],t)};o.armB={to:lerp2([21.5,34.7],[24.5,42],t)}}
   return o}},
 pray:{n:24,cols:12,fps:12,note:'un genou à terre, mains jointes : gantelets et cercle qui montent en lumière',
  f:(i,TP)=>{const g=pulse(i,24),q=i%24;return{...KNEEL,lean:1,ub:q<12?0:1,hd:[0,1],blink:true,armF:{to:[29.5,35.5]},armB:{to:[28.5,36]},glow:g,rune:g,
   fx:TP&&g>.75?[[30,32-(q&3),'cy',.9],[31+(q&1),30-(q&3),'cy',.6]]:[]}}},
 settle:{n:10,cols:12,fps:12,note:'s’assoit en tailleur (jouée à l’envers pour se relever)',
  f:i=>i<6?{dy:i,lean:i>1&&i<5?1:0,legF:{x:i>2?1.5:0},legB:{x:i>2?-1.5:0},coat:i*.4}:{dy:5,lotus:true,armF:i>=7?{to:[29,40.5]}:{to:[26.5,38]},armB:{to:[23,40]},hd:[0,i===6?1:0]}},
 lotus:{n:48,cols:12,fps:12,note:'méditation en tailleur, yeux clos, souffle lent',
  f:i=>({dy:5,lotus:true,...breath(i,48),blink:true,armF:{to:[29,40.5]},armB:{to:[23,40]},rune:pulse(i,48)})},
 slash1:{n:14,cols:14,fps:21,note:'direct : épaule armée, pas en avant, buste qui part avec le poing, retour en garde',
  f:i=>{const o={lean:[0,-1,-1,-1,0,2,2,2,1,1,0,0,0,0][i],dy:[0,0,0,0,0,1,1,1,1,0,0,0,0,0][i],coat:[0,-1,-1,0,1,2,2,1,1,0,0,0,0,0][i],
    legF:{x:[0,0,0,0,1,3,3,3,2,2,1,0,0,0][i]},legB:{x:[0,0,-1,-1,-1,-2,-2,-2,-1,-1,0,0,0,0][i],tilt:i>=5&&i<=7?-1:0}};
   o.armF=i<3?{a:-60,e:120}:i<11?{aim:{ang:0,rec:[3,4,4,2,0,-2,-2,-1,0,1,2][i],pulse:i>=4&&i<=6,flash:i===5||i===6}}:{a:(13-i)*8,e:(13-i)*30};
   o.armB=i<4?{a:35,e:95}:i<10?{a:-45,e:70}:{a:(13-i)*10,e:(13-i)*25};return o}},
 slash2:{n:16,cols:16,fps:18,note:'marteau des deux poings : se grandit, s’abat en pliant les genoux, onde au sol',
  f:(i,TP)=>{let a,ly,ln,d;
   if(i<5){const t=i/4;a=lerp(-15,-150,ease(t));ln=i>1?-1:0;d=0}
   else if(i<9){const t=ease((i-5)/3.5>1?1:(i-5)/3.5);a=lerp(-150,62,t);ln=lerp(-1,2,t);d=lerp(0,2,t)}
   else if(i<13){a=62;ln=2;d=2}else{const t=(i-12)/3;a=lerp(62,0,t);ln=lerp(2,0,t);d=lerp(2,0,t)}
   const o={lean:ln,dy:d,armF:{a,e:i<5?25:8},armB:{a:a+10,e:i<5?25:8},legF:{x:d>.5?2:0},legB:{x:d>.5?-1.5:0},coat:i>=5&&i<10?-1.5:0,hd:[0,i>=8&&i<13?1:0]};
   if(i>=8&&i<13){const k=i-8,m=TP?'cy':'rag';o.glow=1;o.fx=k?[[31-2*k,44,m,1-k*.15],[34+2*k,44,m,1-k*.15],[32-k,42-k,m,.9-k*.15],[33+k,43-k,m,.7]]:[[30,44,m,1],[31,44,m,1],[32,44,m,1],[33,44,m,1],[34,44,m,1],[35,44,m,.9]]}
   return o}},
 shoot:{n:6,cols:6,fps:12,note:'décharge du gantelet : main gauche en appui, recul du buste, pied arrière qui cale',
  f:i=>({lean:[0,-1,-1,0,0,0][i],legB:{x:[0,-1,-1.5,-1,0,0][i]},coat:[0,1,2,1,0,0][i],rune:i<2?1:.7,hd:[i===1?-1:0,0],
   armF:{aim:{ang:0,rec:[0,2,1.5,1,.5,0][i],flash:i<2,pulse:i<3}},armB:{to:[27.5-[0,2,1.5,1,.5,0][i],31.5]}})},
 aim:{n:76,cols:19,note:'visée : la tête et le buste suivent l’angle du gantelet (géométrie de la bouche inchangée)',
  f:i=>{const r=Math.floor(i/19),a=ANGLES[i%19];return{armF:{aim:{ang:a*DEG,rec:[0,1.5,3,0][r],pulse:r===3}},hd:a<=-50?[-1,0]:a>=50?[0,1]:[0,0],
   legB:{x:r===2?-1:0},armB:a<-30?{a:-20,e:10}:{a:10,e:20}}}},
 shoot_d:{n:6,cols:6,fps:12,note:'décharge vers le sud (de face)',f:i=>({dir:'d',aim:{rec:[0,2,1.5,1,.5,0][i],flash:i<2,pulse:i<3},ub:i===1||i===2?1:0,rune:i<2?1:.7})},
 shoot_u:{n:6,cols:6,fps:12,note:'décharge vers le nord (de dos)',f:i=>({dir:'u',aim:{rec:[0,2,1.5,1,.5,0][i],flash:i<2,pulse:i<3},ub:i===1||i===2?1:0})},
 idle_d:{n:24,cols:12,fps:12,note:'repos de face : souffle en quatre temps',f:i=>({dir:'d',...breath(i,24),blink:i===19||i===20,rune:pulse(i,24)})},
 walk_d:{n:12,cols:12,note:'marche de face : pied levé de 2 px, hanches qui montent, bras et pans du manteau en opposition',f:i=>frontWalk(i,'d')},
 idle_u:{n:24,cols:12,fps:12,note:'repos de dos',f:i=>({dir:'u',...breath(i,24),rune:pulse(i,24)})},
 walk_u:{n:12,cols:12,note:'marche de dos',f:i=>frontWalk(i,'u')},
 hit:{n:6,cols:6,fps:12,note:'touché (nouveau) : buste rejeté en arrière, pied qui recule',
  f:i=>({hurt:i<3,lean:[-2,-2,-1,-1,0,0][i],dy:[0,1,1,0,0,0][i],hd:[[-1,0],[-1,-1],[0,0],[0,1],[0,0],[0,0]][i],legB:{x:[-2,-2,-2,-1,0,0][i]},
   armF:{a:[55,65,40,20,8,0][i],e:25},armB:{a:[-45,-50,-30,-15,-5,0][i],e:10},coat:[-1,-2,-1,0,0,0][i]})},
 c_idle:{n:48,cols:12,fps:12,note:'repos, Arbalestrie baissée, tenue à deux mains',f:i=>({...breath(i,24),blink:i===30||i===31,cannon:{ang:12+((i%24)>11?1:0)},rune:pulse(i,24)})},
 c_walk:{n:12,cols:12,note:'marche, Arbalestrie baissée qui balance',f:i=>{const w=walkPose(i);return{...w,lean:0,cannon:{ang:12+3*Math.sin(i/12*4*Math.PI)}}}},
 c_shoot:{n:6,cols:6,fps:12,note:'tir de l’Arbalestrie : pied arrière qui cale, manteau soufflé',
  f:i=>({cannon:{ang:[0,-4,-2,-1,0,0][i],rec:[0,2,1.5,1,.5,0][i],flash:i<2},legB:{x:[0,-1.5,-2,-1.5,-1,0][i]},coat:[0,2,2,1,0,0][i],dy:i===1||i===2?1:0,rune:i<2?1:.7})},
};
function frontWalk(i,dir){const p=i/12*2*Math.PI,s=Math.sin(p);
 return{dir,liftL:Math.round(2.4*Math.max(0,s)),liftR:Math.round(2.4*Math.max(0,-s)),dy:Math.abs(s)>.5?-1:0,sw:Math.round(2*Math.sin(p-.5)),sway:Math.round(Math.sin(p-.8)),hd:[0,i%6===1?1:0]}}
// Image i de l'animation, pour le corps « templier » ou « exil ».
function engFrame(name,i,body='templier'){const a=ENG_ANIMS[name];return eng({body,...a.f(i%a.n,body==='templier')})}
