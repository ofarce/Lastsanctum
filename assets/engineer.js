// Ingénieur exilé — sprite dédié (gabarit 80×84, ancre pieds en (30,80) comme UnitKit.figure).
// Pensé pour rester lisible à l'échelle 0,5 du jeu : grands aplats contrastés, détails d'au moins 2 px natifs,
// et animé de façon fluide : respiration au repos, vapeur du générateur, cape et écharpe au vent,
// cycle de marche (12 images conseillées) avec balancier des bras, rebond du buste et lanterne en pendule.
// Dépend de assets/decor.js et assets/units.js. Expose EngineerKit.draw(spec, temps, échelle).
'use strict';
const EngineerKit=(()=>{const{K,fill,ell,seg,line,outlineAll,glowDots,scaled}=UnitKit,LOOP=2.4,W0=Math.PI*2/LOOP;
const RUST=['#2a160c','#4a2a14','#6e4220','#94602c','#b8803c'];
const BRASS=['#3a2808','#6a4a14','#a07424','#d0a03c','#f0cc6a','#fff0b0'];
const IVORY=['#4a4232','#6e6450','#988c6e','#c0b490','#e0d6b4','#f6f0da'];
const rng=s=>()=>((s=Math.imul(s^s>>>15,1|s)+0x6d2b79f5|0)>>>0)/4294967296;
// décalage de tout un groupe de calques (buste qui respire / rebondit)
const off=(P,dx,dy)=>({set:(x,y,c,z)=>P.set(x+dx,y+dy,c,z),ramp:(r,v,x,y)=>P.ramp(r,v,x+dx,y+dy),
 poly:(pts,fn,z)=>P.poly(pts.map(([x,y])=>[x+dx,y+dy]),(x,y)=>fn(x-dx,y-dy),z),line:(a,b,c,d,col,z)=>P.line(a+dx,b+dy,c+dx,d+dy,col,z)});
const rect=(P,x0,y0,x1,y1,r,z,o)=>fill(P,[[x0,y0],[x1,y0],[x1,y1],[x0,y1]],r,z,o);

// --- casque rétractable : proxys de dessin (masque par pixel, déformation des sommets) ---
const proxy=(P,keep,map=(x,y)=>[x,y],tint)=>{const o={ramp:(r,v,x,y)=>P.ramp(r,v,x,y),
 set:(x,y,c,z)=>{const[u,w]=map(x,y);if(keep(Math.round(u),Math.round(w)))P.set(u,w,tint?tint(Math.round(u),Math.round(w),c):c,z)},
 line:(a,b,c,d,col,z)=>Px.prototype.line.call(o,a,b,c,d,col,z)};
 o.poly=(pts,fn,z)=>{const m=pts.map(([x,y])=>map(x,y));Px.prototype.poly.call({set:(x,y,c,zz)=>{if(keep(x,y))P.set(x,y,tint?tint(x,y,c):c,zz)}},m,fn,z)};return o};
const hash=(x,y)=>{let h=Math.imul(x*374761393+y*668265263,1274126177);h^=h>>>13;return((h>>>0)%1000)/1000};
const ALL=()=>true,SKIN=UnitKit.K.skin,HAIR=['#1a120c','#2e2016','#46321f','#5e4630'];
function face(P,x,y,z){// visage humanoïde de profil 3/4, regard vers la droite
 ell(P,x+3,y,6.5,8,SKIN,z,{v:.7});fill(P,[[x-4,y-8],[x+6,y-9],[x+10,y-6],[x+2,y-5],[x-3,y-1]],HAIR,z+.2,{v:.5});
 P.set(x+5,y-1,'#1a1410',z+.5);P.set(x+8,y-1,'#1a1410',z+.5);P.set(x+5,y-3,HAIR[1],z+.5);P.set(x+8,y-3,HAIR[1],z+.5);P.set(x+9,y-3,HAIR[1],z+.5);
 P.set(x+10,y+1,SKIN[2],z+.5);line(P,x+5,y+4,x+8,y+4,SKIN[1],z+.5)}
function helmetRetract(H,P,s,t,hx0,hy0,shell,pulse){
 const c=Math.max(0,Math.min(1,s.close||0)),st=s.helmet;face(H,hx0,hy0,29);
 if(st==='lamelles'){const n=4,k=Math.round(c*n*8)/8,x0=hx0-9,span=22,edge=x0+span*k/n;
  shell(proxy(H,(x)=>x<=edge));
  // bourrelet de nuque : plaques empilées
  fill(H,[[hx0-10,hy0-6],[hx0-6,hy0-8],[hx0-5,hy0+7],[hx0-9,hy0+7]],K.gun,33,{v:.62,tex:3});
  for(let i=1;i<n;i++){const xs=x0+span*i/n;if(xs<=edge)line(H,xs,hy0-7,xs,hy0+6,K.gun[1],33.5)}
  for(const y of[hy0-4,hy0+1,hy0+5])H.set(hx0-8,y,BRASS[4],34)}
 if(st==='col'){const f=Math.max(.06,c),base=hy0+9;
  shell(proxy(H,ALL,(x,y)=>[x,base-(base-y)*f]));
  fill(H,[[hx0-9,hy0+5],[hx0+12,hy0+5],[hx0+11,hy0+10],[hx0-8,hy0+10]],K.gun,34,{v:.58,tex:3});line(H,hx0-9,hy0+5,hx0+12,hy0+5,BRASS[4],34.5)}
 if(st==='visiere'){const cut=hy0-5,up=(1-c)*10;
  shell(proxy(H,(x,y)=>y<cut));
  shell(proxy(H,(x,y)=>y>=cut-up&&(c>.98||y>=cut-up),(x,y)=>[x,y-up]));
  // oreillettes : pivotent vers l'arrière
  const a=(1-c)*1.3,px=hx0-3,py=hy0-3;const R=(x,y)=>[px+(x-px)*Math.cos(a)-(y-py)*Math.sin(a),py+(x-px)*Math.sin(a)+(y-py)*Math.cos(a)];
  fill(proxy(H,ALL,R),[[hx0-4,hy0-3],[hx0+1,hy0-3],[hx0+2,hy0+9],[hx0-4,hy0+8]],K.gun,33,{v:.48,tex:3})}
 if(st==='nano'){const cxh=hx0+5,cyh=hy0-1,thr=c*1.35;
  const keep=(x,y)=>Math.hypot(x-cxh,(y-cyh)*1.2)/15+hash(x,y)*.35<thr;
  const tint=(x,y,col)=>{const d=Math.hypot(x-cxh,(y-cyh)*1.2)/15+hash(x,y)*.35;return c<.999&&thr-d<.12?(hash(y,x)<.5?'#5dcaa5':'#9fe1cb'):col};
  shell(proxy(H,keep,undefined,tint));
  // émetteur derrière l'oreille + particules errantes
  H.set(hx0-4,hy0+3,'#9fe1cb',35);H.set(hx0-5,hy0+3,'#1d9e75',35);
  if(c>.02&&c<.98)for(let i=0;i<8;i++){const q=hash(i,Math.floor(t*12));H.set(hx0-4+(q-.5)*20,hy0+3-q*12,'#9fe1cb',36)}}
 if(st==='bricole'){const cq=c>0&&c<1?Math.floor(c*4)/4:c,a=-(1-cq)*1.75,px=hx0-7,py=hy0+7;
  const R=(x,y)=>[px+(x-px)*Math.cos(a)-(y-py)*Math.sin(a),py+(x-px)*Math.sin(a)+(y-py)*Math.cos(a)];
  shell(proxy(H,ALL,R));
  // bras motorisé : piston de la nuque au casque
  const[tx,ty]=R(hx0-3,hy0-4);line(H,hx0-9,hy0+9,tx,ty,K.gun[4],35);H.set(hx0-9,hy0+9,BRASS[4],35.5);H.set(tx,ty,BRASS[4],35.5);
  // lunettes : descendent après le casque
  const g=Math.max(0,Math.min(1,(c-.7)/.3)),gy=hy0-8+g*7;
  for(const gx of[hx0+5,hx0+9]){rect(H,gx-2,gy-1,gx+1,gy+2,BRASS,38,{v:.75});rect(H,gx-1,gy,gx,gy+1,K.amber,38.5,{v:.6+pulse*.3})}
  line(H,hx0-3,gy,hx0+3,gy,K.leath[1],37);
  if(c>.72&&c<.95)for(let i=0;i<5;i++){const q=hash(i,Math.floor(t*20));H.set(hx0+13+q*5,hy0-9+hash(q*99|0,i)*6,i%2?K.amber[4]:'#fff0b0',40)}}
}

function draw(s={},t=0,k=1){
 const P0=new Px(Math.ceil(80*k),Math.ceil(84*k),true),P=k===1?P0:scaled(P0,k),cx=30;
 const WK=s.walk!=null,ph=WK?s.walk*Math.PI*2:0,sw=sd=>WK?Math.sin(ph+(sd>0?Math.PI:0)):0,lift=sd=>WK?Math.max(0,Math.cos(ph+(sd>0?Math.PI:0)))*3:0;
 const breath=Math.sin(t*W0),pulse=.5+.5*Math.sin(t*W0*2);
 // buste : 1 px (à l'échelle 0,5) de respiration, ou rebond au contact des pieds pendant la marche
 const uy=WK?(Math.abs(Math.sin(ph))>.6?2:0):(breath>0?0:1),U=off(P,0,uy),U2=off(P,0,WK?uy:breath>0?0:2);
 const wind=WK?Math.sin(ph*2)*2+2:Math.sin(t*W0+1)*1.2;

 // --- CAPE (fond) ---
 fill(U,[[cx-9,30],[cx+8,30],[cx+11-wind,77-uy],[cx-6-wind*1.6,78-uy],[cx-13-wind*1.4,72-uy]],K.crim,1,{v:.42,fold:1});
 line(U,cx-13-wind*1.4,72-uy,cx-6-wind*1.6,78-uy,K.crim[3],1.1);

 // --- GÉNÉRATEUR DORSAL ---
 rect(U,cx-20,15,cx-8,43,K.gun,2,{v:.62,tex:4});
 for(const y of[16,24,41])fill(U,[[cx-21,y],[cx-7,y-1],[cx-7,y+1],[cx-21,y+2]],BRASS,3,{v:.7});
 rect(U,cx-18,26,cx-10,38,K.amber,4,{v:.62+pulse*.35});
 for(const x of[cx-16,cx-14,cx-12])line(U,x,26,x,38,K.gun[1],5);
 for(const y of[29,33])P.set(cx-19,y+uy,BRASS[4],5);
 // cheminée + manomètre
 rect(U,cx-17,6,cx-13,15,K.gun,3,{v:.55});rect(U,cx-18,5,cx-12,7,BRASS,4,{v:.75});
 ell(U,cx-10,19,2.6,2.6,IVORY,5,{v:.9});line(U,cx-10,19,cx-10+Math.cos(t*W0*1.5)*1.6,19-1.6,K.crim[2],6);
 // panaches de vapeur qui montent en boucle
 for(let i=0;i<3;i++){const q=((t/LOOP)*1.5+i/3)%1,px=cx-15+Math.sin(q*5+i)*2-q*4,py=3-q*14+uy,r=1.4+q*2.6;
  if(q<.9)ell(P,px,py,r,r*.85,K.white,2.5,{v:.95-q*.5})}
 // câbles vers la ceinture
 for(let i=0;i<16;i++){const u=i/15;P.set(cx-9+u*8,42+Math.sin(u*3)*5+uy,RUST[2+(i%2)],4);P.set(cx-9+u*8,43+Math.sin(u*3)*5+uy,RUST[1],4)}

 // --- JAMBES ---
 for(const sd of[-1,1]){const x=cx+sd*4.5,dx=sw(sd)*5.5,ly=lift(sd),kx=x+dx*.45+(ly>0?1.5:0),dk=sd<0?.72:.52;
  fill(P,[[x-3.6,49],[x+3.6,49],[kx+3.3,61-ly*.4],[kx-3.3,61-ly*.4]],K.gun,5,{v:dk,tex:3});
  fill(P,[[kx-3.2,60-ly*.4],[kx+3.2,60-ly*.4],[x+dx+3,72-ly],[x+dx-3,72-ly]],K.gun,5,{v:dk-.04,tex:3});
  // bottes de cuir à coque de laiton
  fill(P,[[x+dx-4,70-ly],[x+dx+4,70-ly],[x+dx+6.5,80-ly],[x+dx-4,80-ly]],K.leath,6,{v:dk+.05});
  rect(P,x+dx+2,77-ly,x+dx+6,80-ly,BRASS,6.5,{v:dk+.1});line(P,x+dx-4,74-ly,x+dx+4,74-ly,K.leath[0],6.6);
  // genouillère ivoire
  ell(P,kx+.8,60.5-ly*.4,3.6,3,IVORY,7,{v:dk+.25});P.set(kx+1,60-ly*.4,BRASS[4],7.5)}

 // --- BUSTE ---
 fill(U,[[cx-10,29],[cx+10,29],[cx+8,49],[cx-8,49]],K.gun,10,{v:.68,tex:5});
 // plastron : arête lumineuse
 line(U,cx+6,31,cx+5,46,K.gun[5],10.5);
 // tabard ivoire au sceau de Sigil, ourlet qui flotte
 const tw=WK?Math.sin(ph*2):Math.sin(t*W0)*.4;
 fill(U,[[cx-5,33],[cx+6,33],[cx+7+tw,61],[cx+1,63],[cx-5+tw,61]],IVORY,12,{v:.78,fold:1});
 line(U,cx-5+tw,61,cx+7+tw,61,K.crim[3],12.5);
 {const y=43;for(let a=0;a<28;a++)P.set(cx+.5+Math.cos(a/28*6.283)*4,y-1+Math.sin(a/28*6.283)*4+uy,K.crim[3],13);
  rect(U,cx,y-7,cx+1,y+5,K.crim,13);rect(U,cx-5,y-1,cx+6,y,K.crim,13)}
 // ceinture, boucle, sacoches et marteau d'appoint
 rect(U,cx-9,46,cx+9,49,K.leath,14,{v:.5});rect(U,cx,46,cx+3,49,BRASS,15,{v:.85});P.set(cx+1,47+uy,K.leath[1],15.5);
 for(const sd of[-1,1])rect(U,cx+sd*6-2,47,cx+sd*6+3,54,K.leath,15,{v:sd<0?.45:.65});
 P.set(cx+6,49+uy,BRASS[4],15.5);P.set(cx-6,49+uy,BRASS[3],15.5);
 seg(U,[cx+9,48],[cx+12,58],1.6,RUST,14.5,{v:.7});rect(U,cx+10,56,cx+15,59,K.steel,14.6,{v:.8});

 // --- BRAS ---
 // arrière (écran gauche) : porte la lanterne, balance en opposition à la jambe
 const sR=[cx-9.5,32],eR=[cx-12.5-sw(1)*1.5,42],hR=[cx-11.5-sw(1)*4.5,51-Math.abs(sw(1))*1.2];
 // avant (écran droite) : clé lourde levée, suit la marche
 const sL=[cx+9.5,32],eL=[cx+13+sw(-1)*1.2,40],hL=[cx+12+sw(-1)*3,47-Math.abs(sw(-1))];
 // lanterne en pendule : retard de phase sur la main
 const swing=WK?Math.sin(ph+Math.PI-.9)*5:Math.sin(t*W0*.5)*1.2,lx=hR[0]+swing,ly=hR[1]+12+uy;
 line(P,hR[0],hR[1]+2+uy,lx,ly-6,K.gun[4],8.6);
 rect(P,lx-4.5,ly-6,lx+4.5,ly-4,K.gun,8.7,{v:.7});rect(P,lx-4,ly-4,lx+4,ly+6,K.gun,8.7,{v:.55});
 rect(P,lx-3,ly-3,lx+3,ly+5,K.amber,8.8,{v:.7+pulse*.3});line(P,lx,ly-3,lx,ly+5,K.gun[2],8.9);rect(P,lx-4.5,ly+6,lx+4.5,ly+7,BRASS,8.9,{v:.7});
 glowDots(P,lx,ly+1,7+pulse*3,K.amber[3],Math.round(5+pulse*6),rng(Math.floor(t*W0*3)+3));
 seg(U,sR,eR,5,K.gun,9,{v:.5});seg(U,eR,hR,4.5,K.gun,9,{v:.46});ell(U,hR[0],hR[1],2.6,2.4,K.leath,9.2,{v:.5});
 seg(U,sL,eL,5,K.gun,16,{v:.66});seg(U,eL,hL,4.5,K.gun,16,{v:.62});
 rect(U,eL[0]-2.5,eL[1]+2,eL[0]+2.5,eL[1]+5,K.leath,16.5,{v:.6});// brassard de cuir
 ell(U,hL[0],hL[1],2.8,2.6,K.leath,17,{v:.65});
 // outil de la main avant (s.tool) — la clé à molette a été retirée
 const tool=s.tool||'gauntlet',ta=WK?sw(-1)*.16:Math.sin(t*W0)*.04;
 if(tool==='gauntlet'){// gantelet de Sigil : main gainée de laiton, rune ambrée qui pulse
  ell(U,hL[0],hL[1],3.6,3.4,BRASS,51,{v:.8});rect(U,hL[0]-3,hL[1]-6,hL[0]+3,hL[1]-3,BRASS,50.5,{v:.6});
  U.set(hL[0],hL[1],K.amber[4],52);U.set(hL[0]+1,hL[1],K.amber[3],52);glowDots(U,hL[0],hL[1],5+pulse*3,K.amber[4],Math.round(3+pulse*5),rng(Math.floor(t*W0*3)+9))}
 if(tool==='hammer'){// marteau de bâtisseur porté bas, tête d'acier
  const a=2.6+ta,wx=Math.sin(a),wy=-Math.cos(a),tip=[hL[0]+wx*11,hL[1]+wy*11];seg(U,[hL[0]-wx*3,hL[1]-wy*3],tip,2.6,K.leath,50,{v:.7});
  fill(U,[[tip[0]-5,tip[1]-2],[tip[0]+6,tip[1]-3],[tip[0]+6,tip[1]+3],[tip[0]-5,tip[1]+3]],K.steel,51,{v:.85});line(U,tip[0]+6,tip[1]-3,tip[0]+6,tip[1]+3,K.steel[6],52)}
 if(tool==='plans'){// plans de Sigil roulés sous le bras, ruban cramoisi
  fill(U,[[hL[0]-11,hL[1]-8],[hL[0]-8,hL[1]-12],[hL[0]+10,hL[1]+1],[hL[0]+7,hL[1]+5]],IVORY,17.5,{v:.85});ell(U,hL[0]+8.5,hL[1]+3,2.6,2.6,IVORY,17.6,{v:.5});
  rect(U,hL[0]-2,hL[1]-4,hL[0],hL[1]+1,K.crim,17.7,{v:.8});line(U,hL[0]-1,hL[1]+1,hL[0]-2,hL[1]+5+Math.sin(t*W0*2),K.crim[3],17.7)}
 if(tool==='pick'){// pic de maçon levé, fer à deux pointes
  const a=.35+ta,wx=Math.sin(a),wy=-Math.cos(a),tip=[hL[0]+wx*20,hL[1]+wy*20];seg(U,[hL[0]-wx*4,hL[1]-wy*4],tip,2.6,K.leath,50,{v:.7});
  fill(U,[[tip[0]-10,tip[1]+4],[tip[0]-2,tip[1]-3],[tip[0]+2,tip[1]-3],[tip[0]+10,tip[1]+4],[tip[0]+1,tip[1]+1],[tip[0]-1,tip[1]+1]],K.steel,51,{v:.85});P.set(tip[0],tip[1]-1+uy,BRASS[4],52)}
 if(tool==='compass'){// compas de géomètre en laiton, pointes vers le sol
  const o=Math.sin(t*W0*.5)*.6,b=[hL[0],hL[1]-3];ell(U,b[0],b[1],2.2,2.2,BRASS,52,{v:.9});
  for(const d of[-1,1])seg(U,b,[b[0]+d*(4+o)+3,b[1]+17],1.8,BRASS,51,{v:d<0?.6:.85});line(U,b[0]-1+3,b[1]+10,b[0]+7,b[1]+10,BRASS[2],51.5)}

 // --- ÉPAULIÈRES IVOIRE ---
 for(const sd of[-1,1]){const x=cx+sd*10.5;for(let i=2;i>=1;i--)ell(U,x+sd*i*.6,31+i*2.2,(5.5+i)*1.15,(3.6+i*.4)*1.15,i%2?IVORY:K.gun,sd<0?11-i*.1:18+(3-i),{v:sd<0?.72:.68});
  U.set(x+sd*2,29,BRASS[4],22);U.set(x-sd*2,30,BRASS[4],22)}

 // --- ÉCHARPE CRAMOISIE ---
 fill(U,[[cx-9,24],[cx+10,24],[cx+12,31],[cx+4,35],[cx-4,34],[cx-12,31]],K.crim,27,{v:.66,fold:1});
 line(U,cx-9,24,cx+10,24,K.crim[5],27.5);
 fill(U,[[cx-12,30],[cx-7,32],[cx-9-wind,50],[cx-15-wind*1.3,46]],K.crim,3,{v:.5,fold:1});

 // --- CASQUE EN COIN --- (s.helmet : style rétractable, s.close : 0 visage visible → 1 fermé)
 const hx0=cx+1,hy0=18;
 const shell=H=>{
 fill(H,[[hx0-7,hy0+8],[hx0-8,hy0-3],[hx0-3,hy0-10],[hx0+11,hy0-8],[hx0+12,hy0-1],[hx0+8,hy0+8]],K.gun,30,{v:.74,tex:4});
 // crête de laiton
 fill(H,[[hx0-4,hy0-10],[hx0+11,hy0-8],[hx0+10,hy0-5],[hx0-5,hy0-7]],BRASS,31,{v:.78});
 line(H,hx0-2,hy0-10,hx0+9,hy0-8,BRASS[5],31.5);
 // fente de visée ambrée, épaisse et pulsante
 rect(H,hx0+2,hy0-2,hx0+11,hy0,K.amber,32,{v:.8+pulse*.2});line(H,hx0+3,hy0-2,hx0+10,hy0-2,pulse>.5?K.amber[4]:K.amber[3],32.5);
 for(let i=0;i<Math.round(2+pulse*2);i++)H.set(hx0+12+i,hy0-1-(i%2),K.amber[4],40);
 // rivets, protège-nuque, grille
 for(const[x,y]of[[hx0-5,hy0+2],[hx0-1,hy0+5],[hx0+6,hy0+5]])H.set(x,y,BRASS[4],32);
 fill(H,[[hx0-8,hy0+2],[hx0-4,hy0+3],[hx0-4,hy0+9],[hx0-9,hy0+7]],K.gun,29.5,{v:.5});
 for(const x of[hx0+5,hx0+7,hx0+9])line(H,x,hy0+2,x,hy0+6,K.gun[1],32);

 };
 if(!s.helmet)shell(U2);else helmetRetract(U2,P,s,t,hx0,hy0,shell,pulse);

 outlineAll(P0);P0.flush();return P0.c}
const SPEC={};
return{draw,SPEC}})();
