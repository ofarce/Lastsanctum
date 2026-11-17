// Pièces des soldats d'Indra (épée et bouclier, archer, lance-flammes) pour planches/soldats-propositions.html.
// S'appuie sur UnitKit (assets/units.js, gabarit 80×84, pieds en (30,80), regard vers la droite).
// Charte : orange = Indra ; pas d'or, de cyan, de rouge ni de pourpre chez ces alliés ; contour noir franc.
'use strict';
const Soldats=(()=>{
const U=UnitKit,{K,HEAD,W,X,fill,ell,seg,line,OUT}=U;
K.gold=K.steel.slice(1); // la boucle de ceinture du gabarit passe en acier (l'or est réservé au Credo)
const R={
 ash:['#100e0e','#1c1918','#2a2524','#3a3331','#4e4542','#665a55'],
 ember:['#2a0e06','#5a1e08','#a2400c','#e0701a','#ffa83a','#ffe08a'],
 fire:['#3a2a22','#8a3008','#d85a0e','#f8901e','#ffc848','#fff4c0'],
 smoke:['#24201d','#38322d','#4e4740'],
 terra:['#2a140c','#4a2414','#6e3a1e','#92542c','#b0703c'],
 bamboo:['#2a2410','#4a4020','#6e6232','#948646','#b8aa60'],
 lacq:['#160d08','#2a1508','#4a240c','#6e3812','#94501c','#b86c2c'],
};
const fr=x=>x-Math.floor(x);
const flick=(t,k)=>.5+.5*Math.sin(t*23+k*1.7)*Math.sin(t*9.3+k);

/* ---------- têtes (cx, cy = centre de la tête ; le visage regarde à droite) ---------- */
const face=(P,cx,cy,s,z=30)=>{ell(P,cx+2,cy+2,4,4.6,s.skin||K.skin2,z,{v:.72});P.set(cx+2,cy+1,OUT,z+1);P.set(cx+5,cy+1,OUT,z+1)};
Object.assign(HEAD,{
 // casque à bol, couvre-nuque lamellaire lacé, nasal ; panache optionnel
 lamHelm:(P,cx,cy,s)=>{const hr=s.hr||K.steel,la=s.lace||K.saff;face(P,cx,cy,s);
  fill(P,[[cx-7,cy-3],[cx-1,cy-3],[cx,cy+7],[cx-8,cy+6]],hr,31,{v:.5});for(let y=cy-1;y<=cy+5;y+=2)line(P,cx-7,y,cx-1,y,la[3],32);
  ell(P,cx,cy-4.5,6.8,4.6,hr,33,{v:.82});fill(P,[[cx-7,cy-1],[cx+7,cy-2],[cx+7,cy],[cx-7,cy+1]],s.band||hr,34,{v:.7});line(P,cx+4,cy-1,cx+4,cy+3,hr[5],35);
  P.set(cx,cy-10,hr[5],34);
  if(s.plume)for(let i=0;i<8;i++)ell(P,cx-1-i*1,cy-10-i*.35+i*i*.14,1.7-i*.08,1.6,s.plume,34.5,{v:.85-i*.05})},
 // casque à cimier haut : la silhouette qui dit « mur »
 hornHelm:(P,cx,cy,s)=>{HEAD.lamHelm(P,cx,cy,{...s,plume:null});const c=s.crest||K.saff;
  for(let i=0;i<10;i++){const x=cx-1-i*.7+i*i*.03,y=cy-9-i;fill(P,[[x-1.5,y],[x+2+i*.15,y],[x+2+i*.15,y+1.2],[x-1.5,y+1.2]],c,34.6,{v:.8-i*.03})}
  for(const d of[-1,1])seg(P,[cx+d*5,cy-6],[cx+d*8,cy-13],2,K.steel,34.4,{v:.85})},
 // casque à bol surmonté d'un cimier en éventail (avant → arrière), rayons alternés
 fanHelm:(P,cx,cy,s)=>{HEAD.lamHelm(P,cx,cy,{...s,plume:null});const c=s.crest||K.saff,R0=s.fanR||9,oy=cy-8;
  for(let y=Math.floor(oy-R0*1.05);y<=oy;y++)for(let x=Math.floor(cx-R0-1);x<=cx+R0;x++){const dx=(x+.5-cx+.5)/R0,dy=(y+.5-oy)/(R0*1.05),d=dx*dx+dy*dy;if(d>1)continue;
   const a=Math.atan2(dy,dx),st=Math.floor((a+Math.PI)/(Math.PI/7))%2;P.set(x,y,P.ramp(c,(st?.78:.55)-d*.25+(-dx)*.12,x,y),34.6)}
  line(P,cx-R0,oy,cx+R0-1,oy,K.steel[3],34.7)},
 // casque clos à masque respiratoire et verres ambrés
 maskHelm:(P,cx,cy,s)=>{const hr=s.hr||K.gun;ell(P,cx,cy-3,6.8,6,hr,32,{v:.75});fill(P,[[cx-6,cy],[cx+7,cy-1],[cx+8,cy+6],[cx-5,cy+7]],hr,32,{v:.6});
  if(s.band)fill(P,[[cx-7,cy-6],[cx+6,cy-7],[cx+6,cy-5],[cx-7,cy-4]],s.band,33,{v:.7});
  const e=s.eye||K.amber;ell(P,cx+3,cy-1,1.8,1.6,e,34,{v:.92});ell(P,cx+7,cy-1.5,1.4,1.4,e,34,{v:.85});
  ell(P,cx+7,cy+4,2.6,2.2,K.steel,34,{v:.8});P.set(cx+8,cy+4,OUT,35);P.set(cx+7,cy+5,OUT,35)},
 // capuche longue : pan arrière flottant, cagoule ou lunettes en option
 hoodLong:(P,cx,cy,s)=>{const hc=s.hc||K.saff;face(P,cx,cy,s);const pk=s.peak?[cx-6-(s.peak-1)*3,cy-15-(s.peak-1)*4]:[cx-3,cy-10];
  fill(P,[[cx-8,cy+8],[cx-8,cy-2],pk,[cx+3,cy-10],[cx+7,cy-6],[cx+8,cy],[cx+3,cy-4],[cx-1,cy-3],[cx-3,cy+8]],hc,32,{v:.66,fold:1});
  fill(P,[[cx-8,cy-3],[cx-15,cy+3],[cx-13,cy+6],[cx-7,cy+3]],hc,28,{v:.45,fold:1});
  if(s.mask)fill(P,[[cx+1,cy+3],[cx+7,cy+2],[cx+7,cy+6],[cx+1,cy+7]],s.mask,33,{v:.6});
  if(s.goggles){ell(P,cx+2.5,cy+1,1.5,1.4,s.eye||K.amber,34,{v:.9});ell(P,cx+5.5,cy+1,1.3,1.3,s.eye||K.amber,34,{v:.85});line(P,cx-1,cy,cx+1,cy+1,K.gun[2],34)}},
 // chignon de moine de la cour, bandeau orange, voile de bouche optionnel
 topknotM:(P,cx,cy,s)=>{HEAD.topknot(P,cx,cy,s);if(s.mask)fill(P,[[cx+1,cy+3],[cx+7,cy+2],[cx+7,cy+7],[cx+1,cy+8]],s.mask,32,{v:.6})},
 // casque noirci à fente de braise, étincelles qui montent
 ashHelm:(P,cx,cy,s)=>{const hr=R.ash,t=s.t||0;ell(P,cx,cy-3,6.8,6,hr,32,{v:.8});fill(P,[[cx-6,cy],[cx+7,cy-1],[cx+8,cy+6],[cx-5,cy+7]],hr,32,{v:.62});
  fill(P,[[cx-7,cy-2],[cx-1,cy-2],[cx,cy+8],[cx-8,cy+7]],hr,31,{v:.4});for(let y=cy;y<=cy+6;y+=2)line(P,cx-7,y,cx-1,y,R.ember[2],31.5);
  const a=flick(t,1);line(P,cx+1,cy-1,cx+8,cy-2,R.ember[a>.5?5:4],34);line(P,cx+1,cy,cx+7,cy-1,R.ember[3],34);
  for(let i=0;i<6;i++){const x=cx-2-i*.4,y=cy-9-i;fill(P,[[x-1,y],[x+3,y],[x+3,y+1.2],[x-1,y+1.2]],R.ash,34.6,{v:.7})}
  if(s.sparks)for(let k=0;k<4;k++){const u=fr(t*.7+k*.27);P.set(cx-3+Math.sin(k*2.1+t*3)*3,cy-12-u*12,R.ember[u<.5?4:3],36)}},
});

/* ---------- corps (appelés par figure() via s.under ; le tampon de profondeur range tout) ---------- */
Object.assign(X,{
 lamellar:(P,o,s)=>{const cx=o.cx,B=o.B,la=s.lace||K.saff,to=s.torso||K.steel;for(let y=31;y<=44;y+=3){const hw=10*B-(y-29)/19*3*B;
  for(let x=Math.ceil(cx-hw+1);x<cx+hw-1;x++){P.set(x,y,(x+y)%2?la[3]:to[2],11.5);if((Math.round(x-cx)+y)%3===0)P.set(x,y+1,to[1],11.4)}}},
 skirtLam:(P,o,s)=>{const cx=o.cx,B=o.B,c=s.skirtC||K.steel,la=s.lace||K.saff;fill(P,[[cx-9*B,46],[cx+9*B,46],[cx+10*B,60],[cx-10*B,60]],c,9,{v:.62});
  for(let y=49;y<=58;y+=3){const hw=9*B+(y-46)/14*B;for(let x=Math.ceil(cx-hw);x<cx+hw;x++)P.set(x,y,la[(x+y)%2?3:2],9.5)}line(P,cx,47,cx,60,OUT,9.6)},
 tankBack:(P,o,s,t)=>{const cx=o.cx,c=s.tankC||K.steel;
  if(s.tankShape==='sphere'){const r=s.tankR||11;ell(P,cx-9,24,r,r,c,2,{v:.78});for(let a=0;a<40;a++)P.set(cx-9+Math.cos(a/40*6.283)*r,24+Math.sin(a/40*6.283)*r*.32,(s.bandC||K.steel)[2],2.2);
   if(s.straps)for(const y of[29,31])line(P,cx-9-r*.6,y,cx-2,y+5,K.leath[2],2.6);
   fill(P,[[cx-11,10],[cx-7,10],[cx-7,14],[cx-11,14]],K.steel,2.3,{v:.8});ell(P,cx-9,9,3,1.2,K.steel,2.4,{v:.9});if(s.gauge)ell(P,cx-15,22,2,2,s.gauge,2.5,{v:.9});return}
  const n=s.tanks||1;for(let i=n-1;i>=0;i--){const x0=cx-18+i*4,y0=21-i*1,z=2+i*.1;
   fill(P,[[x0,y0],[x0+8,y0],[x0+8,y0+25],[x0,y0+25]],c,z,{v:.85,lx:.75});ell(P,x0+4,y0,4,2.2,c,z+.01,{v:.95});ell(P,x0+4,y0+25,4,2,c,z,{v:.5});
   for(const y of[y0+5,y0+19])line(P,x0,y,x0+8,y,s.bandC?s.bandC[3]:K.steel[2],z+.02);
   fill(P,[[x0+3,y0-4],[x0+5,y0-4],[x0+5,y0-1],[x0+3,y0-1]],K.steel,z+.03,{v:.8});line(P,x0+1,y0-4,x0+7,y0-4,K.steel[4],z+.04);
   if(s.gauge){ell(P,x0+4,y0+12,1.8,1.8,s.gauge,z+.05,{v:.9});P.set(x0+4,y0+12,OUT,z+.06)}}},
 potBack:(P,o,s,t)=>{const cx=o.cx;ell(P,cx-13,34,6.5,9,R.terra,2,{v:.75});fill(P,[[cx-16,23],[cx-10,23],[cx-9,27],[cx-17,27]],R.terra,2.1,{v:.6});
  for(const y of[30,38])line(P,cx-19,y,cx-7,y,K.leath[3],2.2);const a=flick(t||0,3);ell(P,cx-13,23,3,1.3,R.ember,2.3,{v:.7+a*.3});
  for(let k=0;k<5;k++){const u=fr((t||0)*.5+k*.21);P.set(cx-13+Math.sin(k*2+u*5)*2*u,21-u*16,R.smoke[u<.5?2:1],2.4)}},
 quiverS:(P,o,s)=>{const cx=o.cx,qc=s.qC||K.leath;seg(P,[cx-10,22],[cx-15,46],5,qc,2,{v:.6});if(s.qBand)for(const k of[.25,.7])line(P,cx-13-k*5+2,22+k*24,cx-9-k*5,22+k*24,s.qBand[3],2.1);
  for(let i=0;i<4;i++){line(P,cx-11+i,22,cx-10+i*1.2,15+i*.6,K.leath[4],2.2);P.set(cx-10+i*1.2,14+i*.6,(s.fl||K.ivory)[4],2.3);P.set(cx-10+i*1.2,15+i*.6,(s.fl||K.ivory)[3],2.3)}},
 capeS:(P,o,s,t)=>{const cx=o.cx,B=o.B,fl=Math.sin((t||0)*2.5)*1.5;fill(P,[[cx-10*B,29],[cx+5*B,29],[cx+2*B,s.capeY||70],[cx-16*B+fl,s.capeY||70]],s.capeC||K.saff,1,{v:.5,fold:1});
  if(s.capeHem)for(let x=Math.round(cx-16*B);x<cx+2*B;x++)P.set(x+fl*.3,(s.capeY||70)-((x*7)%3===0?1:0),s.capeHem[(x%2)+3],1.1)},
 banner:(P,o,s,t)=>{const cx=o.cx,x0=cx-12,fl=Math.sin((t||0)*4)*.8,c=s.flagC||K.saff,g=s.glyphC||R.lacq;line(P,x0,48,x0,1,K.leath[3],1.4);P.set(x0,0,K.steel[5],1.5);
  for(let y=2;y<=21;y++){const w=10+Math.sin(y*.45+(t||0)*5)*.8*((22-y)/19+.3);for(let x=x0-Math.round(w);x<x0;x++)P.set(x,y,P.ramp(c,.72-(x0-x)/w*.3+(y%7===0?-.1:0),x,y),1.3)}
  line(P,x0-10,2,x0,2,K.steel[3],1.45);const gx=x0-5,gy=11,G=s.glyph||'shield';
  if(G==='shield')fill(P,[[gx-3,gy-5],[gx+3,gy-5],[gx+3,gy],[gx,gy+5],[gx-3,gy]],g,1.4,{v:.4});
  else if(G==='bow'){for(let k=-5;k<=5;k++)P.set(gx-1+Math.cos(k/5*1.2)*3,gy+k,g[1],1.4);line(P,gx-1,gy-5,gx-1,gy+5,g[2],1.4);line(P,gx-3,gy,gx+3,gy,g[1],1.4)}
  else fill(P,[[gx-3,gy+5],[gx+3,gy+5],[gx+3,gy],[gx+1,gy-5],[gx,gy-1],[gx-2,gy-3]],g,1.4,{v:.4})},
 wraps:(P,o,s)=>{for(const h of[o.hR,o.hL])if(h)for(let i=0;i<3;i++)line(P,h[0]-2,h[1]-3-i*2,h[0]+2,h[1]-4-i*2,K.ivory[4-(i%2)],16.5)},
});

/* ---------- emblèmes ---------- */
const EMB={
 sun:(P,x,y,z,c=K.saff)=>{ell(P,x,y,2.2,2.4,c,z,{v:.85});for(let a=0;a<8;a++)P.set(x+Math.cos(a/8*6.283)*4,y+Math.sin(a/8*6.283)*4.4,c[3],z)},
 flame:(P,x,y,z,c=R.ember)=>{fill(P,[[x-2.5,y+3],[x+2.5,y+3],[x+2,y-1],[x+.5,y-5],[x,y-1],[x-1.5,y-3]],c,z,{v:.85})},
 bars:(P,x,y,z,c=K.saff)=>{for(const d of[-3,0,3])fill(P,[[x-3,y+d-.8],[x+4,y+d-.8],[x+4,y+d+.8],[x-3,y+d+.8]],c,z,{v:.7})},
 stripe:(P,x,y,z,c=K.saff)=>{fill(P,[[x-1.5,y-15],[x+1.5,y-15],[x+2,y+14],[x-1,y+14]],c,z,{v:.7})},
};
const sunTab=(P,cx,y)=>EMB.sun(P,cx+.5,y-4,13);

/* ---------- armes ---------- */
Object.assign(W,{
 // lame tenue à l'angle s.ang ; s.bl : droite, dao (courbe) ou couperet ; s.trail = arc de frappe
 bladeS:(P,hx,hy,s,t)=>{const a=s.ang??-1.9,L=s.blade||24,ux=Math.cos(a),uy=Math.sin(a),px=-uy,py=ux,z=s.bz||50,bl=s.bl||'straight',st=s.steel||K.polish;
  if(s.trail){const[a0,a1]=s.trail,n=Math.ceil(Math.abs(a1-a0)*L);for(let i=0;i<=n;i++){const aa=a0+(a1-a0)*i/n,f=i/n;for(let r=L*.72;r<=L+1;r++){if(BAYER[Math.floor(r)&3][i&3]>Math.min(1,f*1.4)*(s.trailA??1))continue;P.set(hx+Math.cos(aa)*r,hy+Math.sin(aa)*r,f>.6?st[6]:st[4],z-1)}}}
  for(let i=3;i<L;i++){const u=i/L,cv=bl==='dao'?u*u*2:0,hw=bl==='dao'?1+u*.7:bl==='cleaver'?2:1,tip=L-i<3?(L-i)/3:1;
   for(let k=-Math.ceil(hw*tip);k<=Math.ceil(hw*tip);k++){const c=k===0?st[5]:k>0?(s.heat?R.ember[3+(i%3===0)]:st[6]):st[3];P.set(hx+ux*i+px*(k-cv),hy+uy*i+py*(k-cv),c,z)}}
  for(let k=-3;k<=3;k++)P.set(hx+ux*3+px*k,hy+uy*3+py*k,(s.guardC||K.steel)[4-(Math.abs(k)>2)],z+1);
  for(let i=-3;i<3;i++)P.set(hx+ux*i,hy+uy*i,K.leath[3],z+1);P.set(hx-ux*4,hy-uy*4,K.steel[5],z+1)},
 roundS:(P,hx,hy,s)=>{const r=s.shR||9,cx=hx+1,cy=hy-3;ell(P,cx,cy,r*.78,r,s.sh||K.saff,55,{v:.75});
  for(let a=0;a<56;a++)P.set(cx+Math.cos(a/56*6.283)*r*.78,cy+Math.sin(a/56*6.283)*r,(s.rim||K.steel)[3+(a<28)],56);
  if(s.emb)EMB[s.emb](P,cx,cy,57,s.embC);ell(P,cx,cy,1.6,1.8,K.steel,58,{v:.9})},
 bucklerS:(P,hx,hy,s)=>{ell(P,hx+1,hy-2,4,5,s.sh||K.steel,55,{v:.8});ell(P,hx+1,hy-2,1.8,2,s.embC||K.saff,56,{v:.85})},
 kiteS:(P,hx,hy,s)=>{const k=s.shS||1,pts=[[-6,-18],[7,-19],[8,-6],[1,15],[-5,-5]].map(([x,y])=>[hx+x*k,hy+y*k]);fill(P,pts,s.sh||K.steel,55,{v:.78,lx:.5});
  for(let i=0;i<pts.length;i++){const a=pts[i],b=pts[(i+1)%pts.length];line(P,a[0],a[1],b[0],b[1],(s.rim||K.saff)[3],56)}
  if(s.emb)EMB[s.emb](P,hx+1,hy-5*k,57,s.embC)},
 towerS:(P,hx,hy,s)=>{fill(P,[[hx-6,hy-22],[hx+8,hy-23],[hx+9,hy+16],[hx-5,hy+17]],s.sh||K.gun,55,{v:.72});line(P,hx-4,hy-16,hx+7,hy-17,OUT,56);line(P,hx-4,hy-15,hx+7,hy-16,(s.eye||K.amber)[3],56);
  if(s.emb)EMB[s.emb](P,hx+1.5,hy,56.5,s.embC);for(const[a,b]of[[-5,-21],[7,-22],[8,15],[-4,16]])P.set(hx+a,hy+b,K.steel[5],57)},
});

/* ---------- arc (s.pose 'aim' : bandé ; sinon tenu bas dans la main avant) ---------- */
X.bowS=(P,o,s,t)=>{const h=o.hL,r=o.hR,Hh=s.bowH||20,bc=s.bow||K.leath,ty=s.bowT||'recurve';
 const limb=(k,bulge)=>{let x=Math.cos(k/Hh*1.25)*bulge;const e=Math.abs(k)-(Hh-3);if(ty==='recurve'&&e>0)x+=e*1.1;return x};
 if(s.pose!=='aim'){const bx=h[0]+1,by=h[1]-2;for(let k=-Hh;k<=Hh;k++){const x=bx+limb(k,3);P.set(x,by+k,bc[4-(Math.abs(k)>Hh-5)],54);P.set(x-1,by+k,bc[2],54)}
  line(P,bx+limb(-Hh,3),by-Hh,bx+limb(Hh,3),by+Hh,K.white[3],53);
  if(ty==='compound')for(const d of[-1,1])ell(P,bx+limb(d*Hh,3),by+d*Hh,1.6,1.6,K.steel,55,{v:.9});return}
 const d=s.loosed?0:(s.draw??1),vib=s.loosed?(s.loosed===1?1.6:-.8):0,bx=h[0]+2;
 for(let k=-Hh;k<=Hh;k++){const x=bx+limb(k,3.5+d*2.5)+vib*(1-Math.abs(k)/Hh);P.set(x,h[1]+k,bc[4-(Math.abs(k)>Hh-5)],48);P.set(x+1,h[1]+k,bc[2],48)}
 const tp=[bx+limb(-Hh,3.5+d*2.5),h[1]-Hh],bt=[bx+limb(Hh,3.5+d*2.5),h[1]+Hh];
 if(ty==='compound')for(const q of[tp,bt])ell(P,q[0],q[1],1.8,1.8,K.steel,49,{v:.9});
 if(s.loosed){const nx=bx+vib*1.5;line(P,tp[0],tp[1],nx,h[1],K.white[3],47);line(P,bt[0],bt[1],nx,h[1],K.white[3],47);return}
 line(P,tp[0],tp[1],r[0],r[1],K.white[3],47);line(P,bt[0],bt[1],r[0],r[1],K.white[3],47);if(d<.15)return;
 line(P,r[0],r[1],h[0]+12,h[1]-1,K.leath[4],51);fill(P,[[h[0]+12,h[1]-3],[h[0]+16,h[1]-1],[h[0]+12,h[1]+1]],s.fireTip?R.ember:K.polish,52,{v:.9});
 for(const dd of[-1,1])line(P,r[0],r[1],r[0]-3,r[1]+dd*2,(s.fl||K.ivory)[4],51);
 if(s.fireTip)for(let k=0;k<5;k++){const u=fr(t*1.3+k*.2);P.set(h[0]+14-u*3+Math.sin(k*3+t*9),h[1]-3-u*6,R.ember[u<.4?5:4],53)}};

/* ---------- lance-flammes : corps tenu à deux mains, embout selon s.noz ; écrit s._tip / s._dir ---------- */
X.flamer=(P,o,s,t)=>{const hR=o.hR,hL=o.hL;let dx=hL[0]-hR[0],dy=hL[1]-hR[1];const l=Math.hypot(dx,dy)||1;dx/=l;dy/=l;const px=-dy,py=dx;
 const at=(u,v,b=e)=>[b[0]+dx*u+px*v,b[1]+dy*u+py*v],a=at(-8,0,hR),e=at(s.lanceL||13,0,hL);
 // tuyau souple depuis le réservoir dorsal
 if(!s.noHose){const h0=[o.cx-12,46],c=[o.cx-8,58];for(let i=0;i<=16;i++){const u=i/16,q=[(1-u)*(1-u)*h0[0]+2*(1-u)*u*c[0]+u*u*a[0],(1-u)*(1-u)*h0[1]+2*(1-u)*u*c[1]+u*u*a[1]];P.set(q[0],q[1],(s.hoseC||K.leath)[2+(i%3===0)],15);P.set(q[0],q[1]+1,(s.hoseC||K.leath)[1],15)}}
 seg(P,a,e,3.6,s.lanceC||K.steel,52,{v:.6});let tip;const n=s.noz||'pipe';
 if(n==='pipe'){seg(P,e,at(6,0),5.6,K.steel,53,{v:.85});for(const u of[1,3,5])line(P,...at(u,-3),...at(u,3),K.steel[2],53.5);tip=at(7,0)}
 else if(n==='spear'){seg(P,at(-11,1),at(1,1),5,s.tubeC||R.bamboo,53,{v:.75});for(const u of[-8,-4])line(P,...at(u,-1.5),...at(u,3.5),K.leath[2],53.5);
  fill(P,[at(-1,-2.2),at(12,-.4),at(-1,1.2)],K.polish,54,{v:.9});tip=at(2,1.5)}
 else if(n==='dragon'){const c=s.headC||R.ash;fill(P,[at(-1,-3),at(4,-4.5),at(9,-2.5),at(9,-1),at(-1,-.5)],c,54,{v:.75});fill(P,[at(-1,.8),at(7,1.6),at(6,3.2),at(-1,3.2)],c,54,{v:.55});
  fill(P,[at(0,-3),at(-4,-7),at(2,-4)],c,54.2,{v:.7});P.set(...at(3,-2.6),R.ember[4],55);for(let u=3;u<9;u++)P.set(...at(u,0),R.ember[2+(u%2)],53.8);tip=at(9,0)}
 if(s.ports)for(const u of[-2,0])P.set(...at(u,-2),R.ember[3],55);
 s._tip=tip;s._dir=[dx,dy];
 if(!s.firing){const f=flick(t,2);P.set(tip[0]+dx,tip[1]+dy,R.fire[f>.5?5:4],60);P.set(tip[0]+dx*2,tip[1]+dy*2-1,R.fire[3],60);if(f>.6)P.set(tip[0]+dx*2,tip[1]-2,R.fire[4],60)}};

/* ---------- animations (u ∈ [0,1[ sur la boucle) ---------- */
const cl=v=>Math.max(0,Math.min(1,v)),sm=v=>{v=cl(v);return v*v*(3-2*v)},lerp=(a,b,k)=>a+(b-a)*k,L2=(a,b,k)=>[lerp(a[0],b[0],k),lerp(a[1],b[1],k)];
function keys(seq,a){for(let i=1;i<seq.length;i++)if(a<=seq[i][0]){const[a0,p0]=seq[i-1],[a1,p1]=seq[i],k=sm((a-a0)/(a1-a0)),o={};for(const key in p1)o[key]=Array.isArray(p1[key])?L2(p0[key],p1[key],k):typeof p1[key]==='number'?lerp(p0[key],p1[key],k):p1[key];return o}return{...seq[seq.length-1][1]}}
const IDLE=.32; // part de la boucle au repos
function anim(kind,base,u,t){const s={...base,t,under:[...(base.under||[])],over:[...(base.over||[])]},cx=30,B=base.bulk||1,a=u<IDLE?0:(u-IDLE)/(1-IDLE),fx={};
 if(kind==='lame'){const r=base.restAng??-1.95,o2=r>0?Math.PI*2:0,rest={hRo:base.restH||[cx-11*B,50],eRo:[cx-12.5*B,42],ang:r},rest1={...rest,ang:r+o2},wind={hRo:[cx-12,30],eRo:[cx-15,38],ang:-2.55+o2},hit={hRo:[cx+7,43],eRo:[cx-2,40],ang:.4+o2};
  const p=a===0?rest:keys([[0,rest],[.28,wind],[.42,hit],[.66,hit],[1,rest1]],a);Object.assign(s,p);s.right='bladeS';
  if(a>.3&&a<.62){const k=cl((a-.3)/.12);s.trail=[wind.ang,lerp(wind.ang,hit.ang,k)];s.trailA=a<.42?1:1-(a-.42)/.2;s.bz=60}
  if(a>.36&&a<.66){s.hLo=[cx+12*B+1.5,47];s.eLo=[cx+13*B+1,40]}}
 else if(kind==='archer'){if(a>.04&&a<.9){s.pose='aim';s.draw=sm((a-.08)/.34);if(a>=.6)s.loosed=a<.7?1:2;if(a>=.6)fx.arrow=(a-.6)/.3}}
 else if(kind==='flammes'){const rest={hRo:[cx-6,50],eRo:[cx-11*B,43],hLo:[cx+8,53],eLo:[cx+12*B,45]},up={hRo:[cx-4,44],eRo:[cx-10*B,40],hLo:[cx+9,42],eLo:[cx+13*B,37]};
  const p=a===0?rest:keys([[0,rest],[.12,up],[.88,up],[1,rest]],a);Object.assign(s,p);
  if(a>.14&&a<.86){s.firing=1;const j=Math.sin(t*40)*.5;s.hRo=[s.hRo[0]-.5+j,s.hRo[1]];s.hLo=[s.hLo[0]-.5+j,s.hLo[1]];fx.jet=Math.min(1,(a-.14)/.12)*Math.min(1,(.86-a)/.08)}}
 if(u<IDLE&&Math.floor(t*2)%2)fx.bob=1;return{s,fx}}
// Choix retenu (2026-11-17) : 4.1 · Affinage direct. Source de l'export en jeu (soldats-export.html).
const B4={torso:K.steel,arms:K.steel,fore:K.steel,legs:K.gun,boots:K.gun,hands:K.gun,tabard:K.saff,tabY:66,cross:sunTab,seed:41};
const V41={base:B4,
 lame:{head:'fanHelm',crest:K.saff,pauld:1,lames:2,pr:K.steel,pr2:K.steel,left:'kiteS',shS:1.25,sh:K.steel,rim:K.saff,emb:'sun',restAng:1.95,bulk:1.2,seed:41},
 archer:{head:'hoodLong',hc:K.saff,peak:1.4,torso:K.leath,arms:K.leath,fore:K.leath,tabard:null,under:['capeS','quiverS'],capeC:K.saff,fl:K.ivory,over:['bowS'],bow:K.leath,bowT:'long',bowH:26,bulk:.85,seed:42},
 flammes:{head:'maskHelm',hr:K.steel,band:K.saff,pauld:.95,lames:2,pr:K.steel,pr2:K.steel,under:['tankBack'],tankShape:'sphere',tankR:10,straps:1,tankC:K.saff,bandC:K.steel,gauge:K.steel,over:['flamer'],noz:'pipe',bulk:1.3,seed:43}};
const spec=(V,kind)=>{const s={...V.base,...V[kind]};s.under=V[kind].under||V.base.under;s.over=V[kind].over||V.base.over;return s};
return{R,EMB,sunTab,anim,flick,V41,spec,IDLE}})();
