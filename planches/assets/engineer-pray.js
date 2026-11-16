// Ingénieur sans armure : squelette de poses libre (planche ingenieur-priere-propositions.html).
// Même gabarit et même tenue que EngineerBare (80×84, pieds en (30,80), tourné vers la droite), mais chaque articulation
// est une donnée : hanches, genoux, chevilles, orteils, bassin, épaules, mains, tête (décalage + inclinaison).
// Les poses se mélangent articulation par articulation (EngineerPray.blend), ce qui donne des transitions continues.
// Dépend de assets/decor.js, assets/units.js et assets/engineer-bare.js.
'use strict';
const EngineerPray=(()=>{const UK=UnitKit.K,{fill,ell,seg,line,outlineAll}=UnitKit,{shirt,head,scarf,ik,off,canvasFor}=EngineerBare.parts,OUTFIT=EngineerBare.OUTFIT;
const SKN=UK.skin,SCR='#7a2e22';
const cl=(v,a=0,b=1)=>Math.max(a,Math.min(b,v)),mix=(a,b,t)=>a+(b-a)*t,mix2=(a,b,t)=>[mix(a[0],b[0],t),mix(a[1],b[1],t)];
const norm=v=>{const l=Math.hypot(v[0],v[1])||1;return[v[0]/l,v[1]/l]},add=(a,b,k=1)=>[a[0]+b[0]*k,a[1]+b[1]*k];

// b* = jambe arrière, f* = jambe avant (h hanche, k genou, a cheville, t orteils) ; bH / fH = mains ; Hp bassin, S haut du buste ;
// hb décalage de la tête, ha inclinaison (radians, > 0 = penchée vers l'avant), fz profondeur de la jambe avant, lift lévitation.
const POSES={
 stand:{Hp:[30,48],S:[31,30],bh:[26,49],bk:[26,61],ba:[26,75],bt:[31,79],fh:[34,49],fk:[34.5,61],fa:[34,75],ft:[39,79],bH:[21,51],fH:[41,50],hb:[0,0],ha:0,fz:6,lift:0},
 crouch:{Hp:[28,60],S:[33,42],bh:[25,61],bk:[26,72],ba:[22,78],bt:[18,79],fh:[30,60],fk:[40,64],fa:[38,77],ft:[43,79],bH:[25,60],fH:[42,62],hb:[1,1],ha:.15,fz:12,lift:0},
 kneel:{Hp:[29,58],S:[33,38],bh:[26,58],bk:[21,78],ba:[10,77],bt:[6,79],fh:[31,57],fk:[44,57],fa:[46,75],ft:[51,79],bH:[27,57],fH:[46,55],hb:[0,1],ha:.05,fz:12,lift:0},
 seiza:{Hp:[26,66],S:[30,48],bh:[23,67],bk:[35,77],ba:[24,78],bt:[18,78],fh:[28,67],fk:[39,76],fa:[27,78],ft:[21,78],bH:[38,53],fH:[40,52],hb:[1,2],ha:.3,fz:12,lift:0},
 prostrate:{Hp:[28,63],S:[45,62],bh:[24,64],bk:[35,77],ba:[24,78],bt:[18,78],fh:[28,64],fk:[39,76],fa:[27,78],ft:[21,78],bH:[55,77],fH:[58,77],hb:[1,3],ha:1.1,fz:12,lift:0},
 raise:{Hp:[30,48],S:[30.5,30],bh:[25.5,49],bk:[25,61],ba:[24,75],bt:[29,79],fh:[34.5,49],fk:[35.5,61],fa:[36,75],ft:[41,79],bH:[29,1],fH:[49,7],hb:[-.5,-1],ha:-.3,fz:6,lift:0},
 lotus:{Hp:[30,72],S:[30,53],bh:[26,71],bk:[16,76],ba:[31,78],bt:[36,78],fh:[34,71],fk:[46,76],fa:[30,79],ft:[25,79],bH:[18,72],fH:[45,71],hb:[0,1.5],ha:.15,fz:12,lift:0}};
function blend(a,b,t){const o={};for(const k in a){const A=a[k],B=b[k]??A;o[k]=Array.isArray(A)?[mix(A[0],B[0],t),mix(A[1],B[1],t)]:typeof A==='number'?mix(A,B,typeof B==='number'?t:0):(t<.5?A:B)}return o}
// suite d'images clés [[pose, instant 0..1], …] échantillonnée en t avec un lissage par segment
function keys(list,t,ease=x=>.5-.5*Math.cos(Math.PI*cl(x))){t=cl(t);for(let i=1;i<list.length;i++)if(t<=list[i][1]){const[a,ta]=list[i-1],[b,tb]=list[i];return blend(a,b,ease((t-ta)/(tb-ta||1)))}return list[list.length-1][0]}
const shift=(p,dx,dy,keysToMove)=>{const o={...p};for(const k of keysToMove)o[k]=[p[k][0]+dx,p[k][1]+dy];return o};
// pose de marche (même cinématique que EngineerBare.stand) : ph = phase 0..1
function walkPose(w){const ph=w*Math.PI*2,sw=sd=>Math.sin(ph+(sd>0?Math.PI:0)),lift=sd=>Math.max(0,Math.cos(ph+(sd>0?Math.PI:0)))*3,uy=Math.abs(Math.sin(ph))>.6?2:0;
 const p={...POSES.stand,Hp:[30,48+uy*.5],S:[31,30+uy]};
 for(const sd of[-1,1]){const x=30+sd*4,dx=sw(sd)*5.5,ly=lift(sd),kx=x+dx*.45+(ly>0?1.5:0),L=sd<0?'b':'f';
  p[L+'h']=[x,49];p[L+'k']=[kx,61-ly*.4];p[L+'a']=[x+dx,75-ly];p[L+'t']=[x+dx+5,79-ly]}
 p.bH=[21-sw(1)*4.5,52+uy-Math.abs(sw(1))*1.2];p.fH=[41+sw(-1)*3,51+uy-Math.abs(sw(-1))];return p}

// rotation d'un tracé autour de c (la tête nue est dessinée droite par EngineerBare : on l'incline en tournant ses points)
function rot(P,c,a){if(!a)return P;const co=Math.cos(a),si=Math.sin(a),R=(x,y)=>[c[0]+(x-c[0])*co-(y-c[1])*si,c[1]+(x-c[0])*si+(y-c[1])*co],
 Ri=(x,y)=>[c[0]+(x-c[0])*co+(y-c[1])*si,c[1]-(x-c[0])*si+(y-c[1])*co];
 return{set:(x,y,col,z)=>{const q=R(x,y);P.set(q[0],q[1],col,z)},ramp:(r,v,x,y)=>P.ramp(r,v,x,y),
  poly:(pts,fn,z)=>P.poly(pts.map(([x,y])=>R(x,y)),(x,y)=>{const q=Ri(x,y);return fn(q[0],q[1])},z),
  line:(x0,y0,x1,y1,col,z)=>{const a=R(x0,y0),b=R(x1,y1);P.line(a[0],a[1],b[0],b[1],col,z)}}}
const sg=(P,a,b,w,r,z,o)=>{if(Math.hypot(b[0]-a[0],b[1]-a[1])>.05)seg(P,a,b,w,r,z,o)};

// joints utiles aux effets (repère du gabarit) : mains, tête, poitrine
function joints(p){const d=norm([p.S[0]-p.Hp[0],p.S[1]-p.Hp[1]]),n=[-d[1],d[0]],hd=add(add(add(p.S,d,9.5),n,1.5),p.hb),ly=-p.lift;
 const up=q=>[q[0],q[1]+ly];return{hd:up(hd),fH:up(p.fH),bH:up(p.bH),chest:up(add(add(p.S,d,-4),n,3)),S:up(p.S)}}

function draw(p,t,k=.5,opt={}){const o=opt.o||OUTFIT,pad=opt.pad??0,{P0,PS}=canvasFor(k,pad),P=off(PS,pad,pad-(p.lift||0)),PA=o.pants,SHI=o.shirt;
 const Hp=p.Hp,S=p.S,d=norm([S[0]-Hp[0],S[1]-Hp[1]]),n=[-d[1],d[0]],u=Math.abs(n[0]);
 // jambes : pantalon effiloché, chevilles et pieds nus, genou avant troué
 const leg=(h,kn,a,tt,z,v,front)=>{sg(P,h,kn,7.4,PA,z,{v,tex:3});ell(P,kn[0],kn[1],3.6,3.1,PA,z+.1,{v:v+.04});
  const hem=mix2(kn,a,.8);sg(P,kn,hem,6,PA,z,{v:v-.04,tex:3});sg(P,hem,a,4.4,SKN,z-.05,{v:v+.1});sg(P,a,tt,4.2,SKN,z+.05,{v:v+.1});ell(P,a[0],a[1],2.3,2,SKN,z+.04,{v:v+.1});
  for(let i=0;i<3;i++){const q=mix2(hem,kn,.05+i*.02);P.set(q[0]-2+i*2,q[1]+(i%2),PA[1],z+.2)}
  if(front){ell(P,kn[0]+.8,kn[1]+.4,2.2,1.8,SKN,z+.3,{v:.75});P.set(kn[0]+1,kn[1]+.6,SCR,z+.4)}};
 leg(p.bh,p.bk,p.ba,p.bt,4,.42,false);leg(p.fh,p.fk,p.fa,p.ft,p.fz,.6,true);
 // épaules : écartées quand le buste est droit, ramenées sur le dos quand il se penche
 const base=add(S,n,-3*(1-u)),bS=[base[0]-6*u,base[1]+1-(1-u)],fS=[base[0]+6*u,base[1]+1],B=ik(bS,p.bH),F=ik(fS,p.fH);
 sg(P,bS,B.e,4.6,SKN,5,{v:.45});sg(P,B.e,B.h,4.2,SKN,5,{v:.42});ell(P,B.h[0],B.h[1],2.4,2.2,SKN,5.2,{v:.45});sg(P,bS,mix2(bS,B.e,.5),5.8,SHI,5.1,{v:.42});
 // bassin, buste, t-shirt troué
 fill(P,[[Hp[0]-8,Hp[1]-4],[Hp[0]+8,Hp[1]-4],[Hp[0]+8.5,Hp[1]+3],[Hp[0]-8,Hp[1]+3]],PA,8,{v:.55,tex:3});line(P,Hp[0]-8,Hp[1]-3,Hp[0]+8,Hp[1]-3,PA[1],8.2);
 const TL=add(add(S,n,-8.6),d,1.2),TR=add(add(S,n,8.6),d,.5),BR=add(add(Hp,n,7.8),d,1.5),BL=add(add(Hp,n,-7.8),d,1.5);
 fill(P,[TL,TR,BR,BL],SKN,10,{v:.62});
 const hem=[];for(let i=0;i<7;i++){const q=mix2(BR,BL,i/6);hem.push(add(q,d,-(EngineerBare.OUTFIT.hemTorn?hash(i,3,o.seed)*2.5:0)-(i%2)))}
 shirt(P,o,S,[TL,TR,...hem],t,0,11);
 if(o.scarf)scarf(P,add(S,n,-2*(1-u)),t);
 // bras avant
 sg(P,fS,F.e,4.8,SKN,20,{v:.66});sg(P,F.e,F.h,4.4,SKN,20,{v:.62});ell(P,F.h[0],F.h[1],2.6,2.4,SKN,21,{v:.66});
 line(P,mix(F.e[0],F.h[0],.3),mix(F.e[1],F.h[1],.3),mix(F.e[0],F.h[0],.55),mix(F.e[1],F.h[1],.55)-1,SCR,20.6);
 sg(P,fS,mix2(fS,F.e,.5),6,SHI,20.5,{v:.62});
 // cou et tête (inclinée)
 const hd=add(add(add(S,d,9.5),n,1.5),p.hb);
 sg(P,add(add(S,d,-.5),n,.8),add(add(hd,d,-4),n,-1),4.6,SKN,24,{v:.55});
 head(rot(P,hd,p.ha||0),hd,o,{open:opt.open,mouth:opt.mouth});
 outlineAll(P0);P0.flush();return P0.c}
return{POSES,blend,keys,shift,walkPose,joints,draw}})();
