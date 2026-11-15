// Ingénieur exilé sans équipement (planche ancre-surcharge-propositions.html, proposition 5 « Rupture du sceau ») :
// t-shirt bleu ardoise troué, pantalon gris déchiré, lambeau d'écharpe cramoisie, pieds nus.
// Même gabarit que EngineerKit (80×84, pieds en (30,80)). Expose EngineerBare.stand / kneel / OUTFIT.
// Dépend de assets/decor.js et assets/units.js.
'use strict';
const EngineerBare=(()=>{const UK=UnitKit.K,{fill,ell,seg,line,outlineAll,scaled}=UnitKit,LOOP=2.4,W0=Math.PI*2/LOOP;
// set() tolère une couleur nulle (pixels « troués » des vêtements)
{const s=Px.prototype.set;if(!s.bare){Px.prototype.set=function(x,y,c,z){if(c)s.call(this,x,y,c,z)};Px.prototype.set.bare=1}}
const SKN=UK.skin,AMB=UK.amber,HAIR=['#1a120c','#2e2016','#46321f','#5e4630'],BURN='#140c08',SCR='#7a2e22';
const OUTFIT={shirt:['#161c24','#202a36','#2c3a4a','#3a4c5e','#4c6074'],pants:['#1c1c1e','#2a2a2e','#3a3a40','#4c4c54','#60606a'],sleeve:'short',thr:.71,hemTorn:1,rips:['knee','hem'],scarf:1,seed:53};
const cl=(v,a=0,b=1)=>Math.max(a,Math.min(b,v)),mix=(a,b,t)=>a+(b-a)*t,mix2=(a,b,t)=>[mix(a[0],b[0],t),mix(a[1],b[1],t)];
const eio=t=>.5-.5*Math.cos(Math.PI*cl(t)),ein=t=>{t=cl(t);return t*t*t},eout=t=>{t=1-cl(t);return 1-t*t*t};
const off=(P,dx,dy)=>({set:(x,y,c,z)=>P.set(x+dx,y+dy,c,z),ramp:(r,v,x,y)=>P.ramp(r,v,x+dx,y+dy),
 poly:(pts,fn,z)=>P.poly(pts.map(([x,y])=>[x+dx,y+dy]),(x,y)=>fn(x-dx,y-dy),z),line:(a,b,c,d,col,z)=>P.line(a+dx,b+dy,c+dx,d+dy,col,z)});
function ik(s,h,l1=10,l2=9.5){const dx=h[0]-s[0],dy=h[1]-s[1];let d=Math.hypot(dx,dy)||.01,hh=h;const L=l1+l2-.2;if(d>L){hh=[s[0]+dx/d*L,s[1]+dy/d*L];d=L}
 const a=Math.acos(cl((l1*l1+d*d-l2*l2)/(2*l1*d),-1,1)),b=Math.atan2(dy,dx),e1=[s[0]+l1*Math.cos(b+a),s[1]+l1*Math.sin(b+a)],e2=[s[0]+l1*Math.cos(b-a),s[1]+l1*Math.sin(b-a)];
 return{e:e1[1]>e2[1]?e1:e2,e2:e1[1]>e2[1]?e2:e1,h:hh}}
const canvasFor=(k,pad)=>{const P0=new Px(Math.ceil((80+pad*2)*k),Math.ceil((84+pad*2)*k),true);return{P0,PS:k===1?P0:scaled(P0,k)}};

// t-shirt troué : trous et brûlures dans le repère du buste (S = milieu des épaules)
function shirt(P,o,S,pts,t,ember,z){const x0=S[0]-9;
 P.poly(pts,(x,y)=>{const lx=x-S[0],ly=y-S[1],n=fbm(lx/2.4+40,ly/2.4+40,o.seed);
  if(n>o.thr)return null;if(n>o.thr-.07){if(ember>0&&hash(x|0,y|0,5)<.6*ember)return(Math.floor(t*8+x)%3)?AMB[3]:AMB[4];return BURN}
  let v=.7-(x-x0)/18*.4-ly/22*.12;if((((x|0)*3+(y|0))%8)===0)v-=.1;if(fbm(lx/4,ly/4,o.seed+9)>.63)v-=.2;return P.ramp(o.shirt,v,x,y)},z)}
function head(P,hd,o,s){// tête nue, profil 3/4 tourné vers la droite
 ell(P,hd[0]+2,hd[1],6,7,SKN,26,{v:.72});
 fill(P,[[hd[0]-5,hd[1]-6],[hd[0]+5,hd[1]-8],[hd[0]+8,hd[1]-5],[hd[0]+1,hd[1]-3],[hd[0]-3,hd[1]+3],[hd[0]-5,hd[1]+1]],HAIR,26.5,{v:.5});
 for(const[dx,dy]of[[-3,-8],[-1,-9],[2,-9],[5,-9],[-6,-4]])P.set(hd[0]+dx,hd[1]+dy,HAIR[2],26.6);
 P.set(hd[0]-1,hd[1]+1,SKN[2],26.8);
 if(s.open){P.set(hd[0]+5,hd[1],'#1a1410',27);P.set(hd[0]+8,hd[1],'#1a1410',27)}else line(P,hd[0]+4,hd[1],hd[0]+6,hd[1]+1,'#1a1410',27);
 line(P,hd[0]+3,hd[1]-2,hd[0]+7,hd[1]-1,HAIR[1],27);P.set(hd[0]+8,hd[1]+2,SKN[2],27);
 if(s.mouth){P.set(hd[0]+6,hd[1]+4,'#2a1410',27);P.set(hd[0]+7,hd[1]+4,'#2a1410',27)}else line(P,hd[0]+5,hd[1]+4,hd[0]+7,hd[1]+4,SKN[1],27);
 for(const[dx,dy]of[[3,2],[4,3],[1,3]])P.set(hd[0]+dx,hd[1]+dy,'#4a3024',27.1)}
function scarf(P,S,t){const w=Math.sin(t*2.2)*1.2;fill(P,[[S[0]-6,S[1]-3],[S[0]+5,S[1]-3],[S[0]+6,S[1]+1],[S[0]-5,S[1]+1]],UK.crim,24.5,{v:.6,fold:1});
 fill(P,[[S[0]-6,S[1]],[S[0]-3,S[1]+1],[S[0]-5-w,S[1]+10],[S[0]-8-w,S[1]+8]],UK.crim,24.4,{v:.45});P.set(S[0]-7-w,S[1]+10,UK.crim[1],24.5)}

// ================= À GENOUX (essaie de se relever, tremble, retombe) =================
function kState(sp,t){const s={b:0,lean:5,sway:0,slump:0,rise:0,hd:2.5,cough:0};
 const br=(per,inh)=>{const ph=(t%per)/per;return ph<inh?eout(ph/inh):1-eio((ph-inh)/(1-inh))};
 switch(sp.style){
  case'heavy':s.b=br(1.7,.35);s.hd=2.5+(1-s.b);break;
  case'calm':s.b=br(2.4,.45)*.6;s.lean=2;s.hd=1.5;break;
  case'pant':s.b=br(.72,.42)*.85;s.lean=8;s.hd=4.5;s.slump=1;break;
  case'sway':s.b=br(1.35,.4);s.sway=Math.sin(t*1.4)*1.3;s.lean=4;s.hd=3;break;
  case'cough':{s.b=br(1.6,.35);const c=(t%2.9)/2.9;if(c<.14){const k=Math.sin(Math.PI*c/.14);s.slump+=2.5*k;s.lean+=2*k;s.hd+=2.5*k;s.cough=k}break}
  case'push':{const P=sp.per||3.6;s.b=br(sp.breath||1.5,.35);const a=(t%P)/P;s.rise=a<.4?eio(a/.4)*3.2:a<.62?3.2:a<.82?3.2*(1-ein((a-.62)/.2)):0;if(a>.3&&a<.66)s.sway=Math.sin(t*50)*.5;s.lean=5-s.rise*.6;break}}
 if(sp.age!=null&&sp.age<.4){const k=1-sp.age/.4;s.slump+=3*k;s.lean+=2*k;s.hd+=2*k}
 return s}
function kneel(sp,t,k=.5){
 const st=kState(sp,t),o=sp.o||OUTFIT,pad=sp.pad??0,{P0,PS}=canvasFor(k,pad),P=off(PS,pad,pad+(sp.drop||0));
 const rise=st.rise,Hp=[29+st.sway*.4,58-rise],S=[Hp[0]+st.lean+st.sway,38-st.b*2.6+st.slump-rise*1.1],PA=o.pants,SHI=o.shirt,FT=o.feet||SKN;
 const bK=[21,78-rise*.5],bA=[9,77],fK=[44,57],fA=[46,75];
 seg(P,[Hp[0]-3,Hp[1]],bK,8,PA,4,{v:.42,tex:3});ell(P,bK[0],bK[1]-.5,4,3.4,PA,4.2,{v:.42});seg(P,bK,bA,6,PA,3.6,{v:.36,tex:3});
 fill(P,[[bA[0]-4,77],[bA[0]+2,74],[bA[0]+3,80],[bA[0]-4,80]],FT,3.4,{v:.4});
 if(o.rips.includes('thigh'))for(let i=0;i<6;i++)P.set(mix(Hp[0]-3,bK[0],.3+i*.07)+(i%2),mix(Hp[1],bK[1],.3+i*.07),i%3?SKN[3]:SKN[2],4.5);
 seg(P,[Hp[0]+2,Hp[1]-1],fK,8.5,PA,12,{v:.62,tex:3});seg(P,fK,fA,6.5,PA,12.2,{v:.56,tex:3});ell(P,fK[0]+.5,fK[1],4,3.6,PA,12.5,{v:.66});
 fill(P,[[fA[0]-3,74],[fA[0]+3,74],[fA[0]+9,78],[fA[0]+9,80],[fA[0]-3,80]],FT,12.4,{v:.62});
 if(o.rips.includes('hem')){fill(P,[[fA[0]-3.4,fA[1]-4],[fA[0]+3.4,fA[1]-5],[fA[0]+3.4,fA[1]+.5],[fA[0]-3.4,fA[1]+.5]],SKN,12.3,{v:.62});
  for(let i=0;i<4;i++)P.set(fA[0]-3+i*2,fA[1]-4.5+(i%2)*1.5,PA[1],12.35);if(o.feet)fill(P,[[fA[0]-3,74],[fA[0]+3,74],[fA[0]+9,78],[fA[0]+9,80],[fA[0]-3,80]],o.feet,12.45,{v:.5})}
 if(o.rips.includes('knee')){ell(P,fK[0]+1,fK[1]+.5,2.8,2.4,SKN,12.7,{v:.78});P.set(fK[0]+1,fK[1]+1,SCR,12.8);for(const[dx,dy]of[[-2,-2],[1,-3],[3,-1],[-2,2],[2,3]])P.set(fK[0]+1+dx,fK[1]+.5+dy,PA[4],12.75)}
 fill(P,[[Hp[0]-8,Hp[1]-5],[Hp[0]+8,Hp[1]-5],[Hp[0]+9,Hp[1]+3],[Hp[0]-8,Hp[1]+3]],PA,9,{v:.55,tex:3});line(P,Hp[0]-8,Hp[1]-4,Hp[0]+8,Hp[1]-4,PA[1],9.2);
 const bS=[S[0]-6,S[1]+1],fS=[S[0]+6,S[1]+1],HA={knee:[[47,53],[26,56]],two:[[48,53],[45,51]],ribs:[[S[0]+6,S[1]+12],[S[0]-8,S[1]+18]],push:[[41,56],[26,56]],pray:[[44,50],[42,50]]}[sp.pose||'push'];
 const fH=HA[0],bH=HA[1],B=ik(bS,bH),Fa=ik(fS,fH),bE=B.e,fE=sp.pose==='ribs'?Fa.e2:Fa.e;
 seg(P,bS,bE,4.6,SKN,5,{v:.45});seg(P,bE,B.h,4.2,SKN,5,{v:.42});ell(P,B.h[0],B.h[1],2.4,2.2,SKN,5.2,{v:.45});
 if(o.sleeve!=='none')seg(P,bS,mix2(bS,bE,.5),5.8,SHI,5.1,{v:.42});
 fill(P,[[S[0]-8,S[1]-1],[S[0]+8,S[1]],[Hp[0]+8,Hp[1]-4],[Hp[0]-7,Hp[1]-4]],SKN,10,{v:.62});
 const hem=[];for(let i=0;i<7;i++)hem.push([mix(Hp[0]+8.6,Hp[0]-7.6,i/6),Hp[1]-3.5+(o.hemTorn?hash(i,3,o.seed)*3.5:0)+(i%2)*1.2]);
 const top=o.sleeve==='none'?[[S[0]-6.5,S[1]-1],[S[0]-3.5,S[1]+1.5],[S[0]+3,S[1]+1.5],[S[0]+6.5,S[1]]]:[[S[0]-8.6,S[1]-1.8],[S[0]-2,S[1]-2.4],[S[0]+3,S[1]-2.2],[S[0]+8.6,S[1]-.8]];
 shirt(P,o,S,[...top,[Hp[0]+8.8,Hp[1]-4],...hem,[Hp[0]-7.8,Hp[1]-4]],t,sp.ember||0,11);
 if(o.sleeve==='none')for(const sd of[-1,1])line(P,S[0]+sd*5,S[1]-1,S[0]+sd*4,S[1]+2,SHI[2],11.2);
 if(o.scarf)scarf(P,S,t);
 seg(P,fS,fE,4.8,SKN,20,{v:.66});seg(P,fE,Fa.h,4.4,SKN,20,{v:.62});ell(P,Fa.h[0],Fa.h[1],2.6,2.4,SKN,21,{v:.66});
 line(P,mix(fE[0],Fa.h[0],.3),mix(fE[1],Fa.h[1],.3),mix(fE[0],Fa.h[0],.55),mix(fE[1],Fa.h[1],.55)-1,SCR,20.6);
 if(o.sleeve==='short')seg(P,fS,mix2(fS,fE,.5),6,SHI,20.5,{v:.62});
 if(o.sleeve==='tornF'){seg(P,fS,mix2(fS,fE,.22),6,SHI,20.5,{v:.62});const m=mix2(fS,fE,.3);P.set(m[0],m[1],SHI[2],20.6);P.set(m[0]+1,m[1]+1,SHI[1],20.6)}
 const hd=[S[0]+3,S[1]-8+st.hd];
 seg(P,[S[0]+1,S[1]-1],[hd[0]-1,hd[1]+4],4.6,SKN,24,{v:.55});
 head(P,hd,o,{mouth:st.b>.45||st.cough>.3});
 if(sp.sweat){const p=(t%1.9)/1.9;if(p<.75)P.set(hd[0]+6,hd[1]+6+(p>.45?(p-.45)*28:0),'#dfe6e6',28)}
 outlineAll(P0);P0.flush();return P0.c}

// ================= DEBOUT : repos (respiration) et marche (sp.walk = phase 0..1) =================
// sp.aim = {d:[dx,dy] direction du tir, rc: recul, glow: lueur 0..1} : pose de tir du lance-pitons, mêmes
// épaule, main et bouche que la pose armée (planche ingenieur-creusage-propositions.html, makeSusp.poseFor).
const SL=[39.5,32];
function aimArm(a){const bx=-a.rc*.35,s=[SL[0]+bx,SL[1]],h=[s[0]+a.d[0]*(13-a.rc),s[1]+a.d[1]*(13-a.rc)-a.rc*.4],A=ik(SL,[h[0]-bx,h[1]]);
 return{bx,s:SL,e:A.e,h:A.h,muzzle:[h[0]+a.d[0]*4,h[1]+a.d[1]*4-1]}}
function launcher(U,A,glow){const d0=[A.h[0]-A.e[0],A.h[1]-A.e[1]],l=Math.hypot(d0[0],d0[1])||1,d=[d0[0]/l,d0[1]/l],n=[-d[1],d[0]],Q=(a,b)=>[A.h[0]+d[0]*a+n[0]*b,A.h[1]+d[1]*a+n[1]*b];
 const BR=['#3a2808','#6a4a14','#a07424','#d0a03c','#f0cc6a','#fff0b0'];
 fill(U,[Q(-7,-4),Q(1,-4),Q(1,-1),Q(-7,-1)],BR,20.7,{v:.72});for(let k=-6;k<=0;k+=2)U.set(...Q(k,-2.5),glow>.7?'#c8fbff':'#5ce8ff',20.8);U.set(...Q(1.5,-2.5),'#101012',20.8);
 // sangles de cuir : le lance-pitons est récupéré et noué sur l'avant-bras nu
 for(const a of[-5,-1])line(U,...Q(a,-1),...Q(a,.8),'#3e2a18',20.75)}
function stand(sp,t,k=.5){
 const o=sp.o||OUTFIT,pad=sp.pad??0,{P0,PS}=canvasFor(k,pad),cx=30,PA=o.pants,SHI=o.shirt,FT=o.feet||SKN,AIM=sp.aim?aimArm(sp.aim):null;
 const P=off(PS,pad,pad);
 const WK=sp.walk!=null,ph=WK?sp.walk*Math.PI*2:0,sw=sd=>WK?Math.sin(ph+(sd>0?Math.PI:0)):0,lift=sd=>WK?Math.max(0,Math.cos(ph+(sd>0?Math.PI:0)))*3:0;
 const breath=AIM?1:Math.sin(t*W0),uy=WK?(Math.abs(Math.sin(ph))>.6?2:0):(breath>0?0:1),bx=AIM?AIM.bx:0,U=off(P,1+bx,uy+1),H2=off(P,1+bx,(WK?uy:breath>0?0:2)+1);
 // jambes : arrière plus sombre, pantalon effiloché aux chevilles, pieds nus
 for(const sd of[-1,1]){const x=cx+sd*4,dx=sw(sd)*5.5,ly=lift(sd),kx=x+dx*.45+(ly>0?1.5:0),dk=sd<0?.42:.6,z=sd<0?4:6;
  fill(P,[[x-3.4,49],[x+3.4,49],[kx+3,61-ly*.4],[kx-3,61-ly*.4]],PA,z,{v:dk,tex:3});
  fill(P,[[kx-3,60-ly*.4],[kx+3,60-ly*.4],[x+dx+2.8,74-ly],[x+dx-2.8,74-ly]],PA,z,{v:dk-.04,tex:3});
  fill(P,[[x+dx-2.4,73-ly],[x+dx+2.4,73-ly],[x+dx+2.4,77-ly],[x+dx-2.4,77-ly]],SKN,z+.05,{v:dk+.1});
  fill(P,[[x+dx-3,77-ly],[x+dx+3,77-ly],[x+dx+6,80-ly],[x+dx-3,80-ly]],FT,z+.1,{v:dk+.1});
  for(let i=0;i<3;i++)P.set(x+dx-2+i*2,73.5-ly+(i%2),PA[1],z+.2);
  if(sd>0){ell(P,kx+.8,60.5-ly*.4,2.4,2,SKN,z+.3,{v:.75});P.set(kx+1,61-ly*.4,SCR,z+.4)}}
 // bras arrière, balancier opposé à la jambe
 const sR=[cx-8,32],eR=[cx-10-sw(1)*1.5,42],hR=[cx-10-sw(1)*4.5,51-Math.abs(sw(1))*1.2];
 seg(U,sR,eR,4.4,SKN,3,{v:.45});seg(U,eR,hR,4,SKN,3,{v:.42});ell(U,hR[0],hR[1],2.3,2.2,SKN,3.2,{v:.45});
 seg(U,sR,mix2(sR,eR,.5),5.6,SHI,3.1,{v:.42});
 // bassin, buste, t-shirt troué
 fill(P,[[cx-8,45],[cx+8,45],[cx+8.5,52],[cx-8,52]],PA,8,{v:.55,tex:3});line(P,cx-8,46,cx+8,46,PA[1],8.2);
 const S=[cx+1,30];
 fill(U,[[cx-8,29],[cx+8,29],[cx+7,47],[cx-7,47]],SKN,10,{v:.62});
 const hem=[];for(let i=0;i<7;i++)hem.push([mix(cx+7.8,cx-7.8,i/6),46.5+(o.hemTorn?hash(i,3,o.seed)*2.5:0)+(i%2)]);
 shirt(U,o,S,[[cx-8.6,28.6],[cx-2,28],[cx+3,28],[cx+8.6,28.8],[cx+8,46],...hem,[cx-8,46]],t,0,11);
 if(o.scarf)scarf(U,S,t);
 // bras avant
 let sL=[cx+8,32],eL=[cx+10+sw(-1)*1.2,41],hL=[cx+10+sw(-1)*3,50-Math.abs(sw(-1))];
 // pose de tir : bras avant donné dans le repère de la pose armée (décalé de (1, 1) ici)
 if(AIM){const m=([x,y])=>[x-1,y-1];sL=m(AIM.s);eL=m(AIM.e);hL=m(AIM.h)}
 seg(U,sL,eL,4.6,SKN,20,{v:.66});seg(U,eL,hL,4.2,SKN,20,{v:.62});ell(U,hL[0],hL[1],2.5,2.3,SKN,21,{v:.66});
 line(U,mix(eL[0],hL[0],.3),mix(eL[1],hL[1],.3),mix(eL[0],hL[0],.6),mix(eL[1],hL[1],.6),SCR,20.6);
 seg(U,sL,mix2(sL,eL,.5),5.8,SHI,20.5,{v:.62});
 if(AIM)launcher(U,{e:eL,h:hL},sp.aim.glow||0);
 // cou et tête
 const hd=[cx+1,19];seg(H2,[cx+1,29],[hd[0]-1,hd[1]+5],4.6,SKN,24,{v:.55});head(H2,hd,o,{open:1});
 outlineAll(P0);P0.flush();return P0.c}
return{stand,kneel,OUTFIT,kState,aimArm}})();
