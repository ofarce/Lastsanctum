// Martyre de Byrsa, refonte 16 bits (planches/martyre-16bits-propositions.html), avec le moteur de l'Ingénieur
// (engineer-colosse.js : R, MAT, buf, blob, rect, px, render) et les rampes de refonte-16bits.js (or, crm, car, robe).
// Règles : paliers francs sans trame, contour coloré, lumière en haut à gauche, tête plus grosse que l'actuelle.
// Identité gardée : cornes de bélier, voile ivoire, visage pâle aux larmes de sang, armure d'automate d'or fendue
// (modèle C2 « L'armure cède »), cape sombre doublée de carmin, robe ivoire, bâton au soleil d'or et gemme rouge.
// Elle regarde vers la droite. Cadre du jeu : 150 × 120, ancre aux pieds (60, 114).
// Expose : MARTYRE16 = {VARIANTS, ANIMS, frame(variant, anim, t) → canvas 150 × 120, FW, FH, AX, AY}.
'use strict';
Object.assign(R,{
 horn:['#1a1006','#4a3016','#7a5628','#a88248','#d8b87e'],
 pale:['#3a2a2a','#8a7470','#c4b0a8','#e8dcd4','#fffaf4'],
 glow:['#5a0c04','#c22a08','#f26a1a','#ffb84a','#fff4c0'],
});
MAT.push('horn','pale','glow');

const MARTYRE16=(()=>{
const FW=150,FH=120,AX=60,AY=114,BW=110,BH=116,FX=46,FY=111;
const VARIANTS=[
 {id:'A',name:'A · Prêtresse d’or',desc:'Le gabarit de l’Ingénieur agrandi deux fois : 64 px de haut, tête de 15 px (un quart de la hauteur). Proche de l’actuelle en taille, beaucoup plus lisible.',s:1,head:1},
 {id:'B',name:'B · Colosse fendu',desc:'La taille actuelle (76 px), l’armure plus massive, épaulières énormes. Tête de 17 px. Elle domine l’écran comme aujourd’hui.',s:1.18,head:1},
 {id:'C',name:'C · Martyre ramassée',desc:'Proportions RPG franches : 54 px de haut, grosse tête de 16 px (près d’un tiers). Plus proche des soldats de Laetan, moins imposante.',s:.84,head:1.3},
];
const ANIMS=[
 {id:'idle',name:'Repos',len:4,desc:'Respiration lente, la cape ondule, la fêlure du plastron palpite.'},
 {id:'walk',name:'Marche',len:1.1,desc:'Pas lourd, robe qui balance, bâton en canne.'},
 {id:'attack',name:'Frappe',len:1,desc:'Elle lève le bâton puis l’abat devant elle ; impact à la moitié (départ de la fissure).'},
 {id:'cast',name:'Incantation',len:2.2,desc:'Bâton planté, main levée, une flamme d’or naît dans sa paume (larmes, rosace, litanie).'},
 {id:'hit',name:'Touchée',len:.5,desc:'Recul, éclair blanc, la fêlure jette une étincelle.'},
 {id:'death',name:'Mort',len:3.2,desc:'Elle chancelle, tombe à genoux, le bâton lui échappe, la fêlure s’embrase puis s’éteint.'},
];
const cl=v=>Math.max(0,Math.min(1,v)),lerp=(a,b,t)=>a+(b-a)*t,ease=t=>t*t*(3-2*t);

// trait épais : petites ellipses le long du segment
function seg(b,x0,y0,x1,y1,r,mat,bias=0){const n=Math.max(2,Math.ceil(Math.hypot(x1-x0,y1-y0)*1.5));for(let i=0;i<=n;i++){const t=i/n;blob(b,x0+(x1-x0)*t,y0+(y1-y0)*t,r,r,mat,bias)}}

// Pose d'après l'animation et le temps
function pose(anim,t){const P={bob:0,lean:0,crouch:0,sa:0,hx:0,hy:0,raise:0,glow:.5,step:0,flash:false,dead:0,drop:0,sway:0,spark:false,fade:1};
 if(anim==='idle'){const k=Math.sin(t/4*Math.PI*2*2);P.bob=k>.3?1:0;P.sway=Math.sin(t/4*Math.PI*2);P.glow=.45+.35*Math.sin(t*3)}
 else if(anim==='walk'){const ph=t/1.1*Math.PI*2;P.step=Math.sin(ph);P.bob=Math.abs(P.step)>.6?-1:0;P.sa=.08*P.step;P.hx=P.step*1.2;P.sway=-P.step*.6}
 else if(anim==='attack'){const u=t/1;
  if(u<.35){const e=ease(u/.35);P.sa=-.55*e;P.hy=11*e;P.hx=-2*e;P.lean=-2*e}
  else if(u<.5){const e=ease((u-.35)/.15);P.sa=lerp(-.55,1.0,e);P.hy=lerp(11,-4,e);P.hx=lerp(-2,7,e);P.lean=lerp(-2,3,e);P.crouch=2*e}
  else{const e=ease((u-.5)/.5);P.sa=lerp(1.0,0,e);P.hy=lerp(-4,0,e);P.hx=lerp(7,0,e);P.lean=lerp(3,0,e);P.crouch=lerp(2,0,e)}
  P.flash=u>.46&&u<.56;P.glow=.6}
 else if(anim==='cast'){const u=t/2.2;P.raise=u<.25?ease(u/.25):u>.82?1-ease((u-.82)/.18):1;P.glow=.4+.6*P.raise;P.sa=-.05;P.bob=Math.sin(t*6)>.6?1:0}
 else if(anim==='hit'){const u=t/.5,e=1-ease(cl(u/.8));P.lean=-3*e;P.hx=-2*e;P.flash=u<.2;P.spark=u<.5;P.glow=.9*e+.3}
 else if(anim==='death'){const u=t/3.2;
  if(u<.2){const e=ease(u/.2);P.lean=-3*e+Math.sin(t*20)*e;P.glow=.8}
  else if(u<.5){const e=ease((u-.2)/.3);P.lean=lerp(-3,2,e);P.crouch=16*e;P.sa=lerp(0,.9,e);P.drop=e;P.glow=.9}
  else if(u<.7){const e=ease((u-.5)/.2);P.lean=lerp(2,6,e);P.crouch=lerp(16,22,e);P.sa=lerp(.9,1.45,e);P.drop=1;P.glow=1}
  else{const e=ease((u-.7)/.3);P.lean=6;P.crouch=22;P.sa=1.45;P.drop=1;P.glow=1-e;P.dead=e;P.fade=1-.25*e}
 }
 return P}

function draw(V,anim,t){const b=buf(BW,BH),s=V.s,P=pose(anim,t);
 const Y=v=>FY-v*s, fx=FX;
 const ux=Math.round(P.lean), uy=Math.round(P.bob+P.crouch);              // décalage du haut du corps
 const U=v=>Y(v)+uy, kneel=P.crouch>6;
 // ---- cape (derrière), doublure carmin
 const capeTop=46,capeL=12,capeR=17;
 const cTop=Math.round(U(capeTop));
 for(let y=cTop;y<FY;y++){const k=(FY-y)/(FY-cTop),hw=lerp(capeR,capeL,k)*s,sw=Math.round(P.sway*(1-k)*2),ox=Math.round(ux*k);
  for(let x=Math.round(fx-hw+sw+ox);x<=Math.round(fx+hw+sw*.5+ox);x++){const u=(x-(fx-hw))/(2*hw);put(b,x,y,'robe',.62-u*.45-(y>FY-5?.1:0))}
  put(b,Math.round(fx+hw+sw*.5+ox)+1,y,'car',.6)}
 // ---- corne arrière (côté gauche, en retrait)
 const r=7*s*V.head, hx=fx+1*s+ux+2, hy=U(55)-(r-7*s)*.6;
 // cornes : montent du crâne, s'écartent puis la pointe retombe vers l'extérieur (courbe de Bézier)
 const horn=(bx,by,dir,L,th,bias)=>{const P0=[bx,by],P1=[bx+dir*.2*L,by-1.3*L],P2=[bx+dir*1.5*L,by-1.35*L],P3=[bx+dir*1.45*L,by+.05*L];
  for(let i=0;i<=40;i++){const k=i/40,q=1-k,x=q*q*q*P0[0]+3*q*q*k*P1[0]+3*q*k*k*P2[0]+k*k*k*P3[0],y=q*q*q*P0[1]+3*q*q*k*P1[1]+3*q*k*k*P2[1]+k*k*k*P3[1];
   const w=th*(1-.68*k);blob(b,x,y,w,w,'horn',bias+.12*Math.sin(k*9)+(k>.85?.2:0))}};
 horn(hx-r*.45,hy-r*.55,-1,r*1.3,3*s,-.12);
 // ---- robe ivoire (jupe évasée), plis, ourlet d'or
 const waist=30, skirtTop=kneel?Math.max(4,waist-P.crouch/s):waist;
 const sTop=Math.round(U(waist));
 for(let yy=sTop;yy<=FY;yy++){const k=(FY-yy)/Math.max(1,FY-sTop),hw=lerp(14,8,k)*s,dx=Math.round(P.step*(1-k)*2+ux*k),hem=FY-yy<2;
  for(let x=Math.round(fx-hw+dx);x<=Math.round(fx+hw+dx);x++){const u=(x-(fx-hw+dx))/(2*hw),fold=((x-dx-fx+60)%Math.max(4,Math.round(5*s)))===0&&!hem;
   put(b,x,yy,hem?'or':'crm',(hem?.7-u*.4:.82-u*.5)-(fold?.2:0))}}
 // pieds : solerets d'or
 if(!kneel){rect(b,Math.round(fx-7*s+P.step*2),FY-2,Math.round(6*s),3,'or',-.05);rect(b,Math.round(fx+2*s-P.step*2),FY-2,Math.round(6*s),3,'or',.05)}
 // ---- bras arrière (gauche écran) : levé pendant l'incantation
 const sl=[fx-10*s+ux,U(44)], sr=[fx+10*s+ux,U(44)];
 const back=P.raise>0?[sl[0]-4*s,lerp(U(30),U(64),P.raise)]:[sl[0]-2*s,U(30)];
 seg(b,sl[0],sl[1],back[0],back[1],1.9*s,'or',-.2);blob(b,back[0],back[1],2.2*s,2.2*s,'or',-.05);
 // ---- buste : plastron d'or bombé, tassettes, ceinture carmin
 rect(b,Math.round(fx-8*s+ux),Math.round(U(34)),Math.round(16*s),Math.round(5*s),'or',-.12);
 for(let i=0;i<4;i++)put(b,Math.round(fx-7*s+ux+i*4*s),Math.round(U(30)),'or',.15);
 rect(b,Math.round(fx-8*s+ux),Math.round(U(35)),Math.round(16*s),2,'car',.05);
 blob(b,fx+ux,U(41),9*s,8*s,'or',.08);
 blob(b,fx+ux-1,U(43),5*s,3.5*s,'or',.3);
 // fêlure : zigzag incandescent, plus vive avec glow
 const crack=[[-3,47],[-1,44],[-3,41],[1,38],[0,35]];
 for(let i=0;i<crack.length-1;i++){const[a0,b0]=crack[i],[a1,b1]=crack[i+1];const n=8;for(let j=0;j<=n;j++){const x=fx+ux+lerp(a0,a1,j/n)*s,y=U(lerp(b0,b1,j/n));
  px(b,Math.round(x),Math.round(y),'glow',.35+.6*P.glow);if(P.glow>.6)px(b,Math.round(x)+1,Math.round(y),'glow',.2+.4*P.glow)}}
 if(P.glow>.7)for(const[dx,dv]of[[-2,45],[2,39],[-1,37]])px(b,Math.round(fx+ux+dx*s),Math.round(U(dv)),'glow',P.glow);
 // ---- épaulières énormes, gemme carmin
 const pr=(V.id==='B'?6.4:5.6)*s;
 blob(b,sl[0],sl[1],pr,pr*.82,'or',.12);blob(b,sl[0]-1,sl[1]-2,pr*.5,pr*.35,'or',.35);px(b,Math.round(sl[0]),Math.round(sl[1]+1),'car',.9);
 // ---- tête : voile ivoire, visage pâle, larmes de sang, diadème
 blob(b,hx,hy+1,r+1.6*s,r+2.2*s,'crm',-.12);
 const fcx=hx+1.6*s,fcy=hy+1.6*s;
 blob(b,fcx,fcy,r*.72,r*.84,'robe',.05);
 blob(b,fcx+.3,fcy+.4,r*.6,r*.72,'pale',.25);
 const ey=Math.round(fcy-.4*s),e1=Math.round(fcx-2.6*s),e2=Math.round(fcx+1.6*s);
 for(const ex of[e1,e2]){const shut=P.dead>.3||anim==='hit'&&P.flash;px(b,ex,ey,shut?'pale':'hair',shut?.2:.05);px(b,ex+1,ey,shut?'pale':'hair',shut?.2:.1);if(!shut&&s>.95){px(b,ex,ey-1,'pale',.05);px(b,ex+1,ey-1,'pale',.05)}
  if(!shut){for(let k=1;k<=Math.round(3*s);k++)px(b,ex+(k>2?1:0),ey+k,'car',.75-k*.08)}}
 px(b,Math.round(fcx-.5*s),Math.round(fcy+3.2*s),'car',.3);px(b,Math.round(fcx+.5*s),Math.round(fcy+3.2*s),'car',.3);
 for(let k=-2;k<=3;k++)px(b,Math.round(hx+k*s),Math.round(hy-r*.55),'or',.75-k*.06);px(b,Math.round(hx+.6*s),Math.round(hy-r*.55-1),'car',.95);
 // ---- corne avant (côté droit), qui s'enroule vers l'avant
 horn(hx+r*.5,hy-r*.6,1,r*1.1,2.7*s,.05);
 // ---- épaulière avant
 blob(b,sr[0],sr[1],pr,pr*.82,'or',.02);blob(b,sr[0]-1,sr[1]-2,pr*.5,pr*.35,'or',.25);px(b,Math.round(sr[0]),Math.round(sr[1]+1),'car',.9);
 // ---- bras avant et bâton
 const hand=[fx+14*s+ux+P.hx*s,U(33)-P.hy*s];
 seg(b,sr[0]+1,sr[1]+2,hand[0],hand[1],2*s,'or',.0);
 const sa=P.sa, dx=Math.sin(sa), dy=-Math.cos(sa), up=40*s, down=P.drop?33*s*(1-P.drop)+8*s:33*s;
 const top=[hand[0]+dx*up,hand[1]+dy*up], bot=[hand[0]-dx*down,hand[1]-dy*down];
 const staff=(P.drop>0)?[[top[0]+P.drop*10*s,top[1]+P.drop*18*s],[bot[0]+P.drop*8*s,Math.min(FY,bot[1]+P.drop*4)]]:[top,bot];
 seg(b,staff[0][0],staff[0][1],staff[1][0],staff[1][1],.9*s,'wood',.05);
 const sun=staff[0];for(let i=0;i<8;i++){const a=i/8*Math.PI*2+.2;const L=(i%2?3.2:4.6)*s;seg(b,sun[0]+Math.cos(a)*3.6*s,sun[1]+Math.sin(a)*3.6*s,sun[0]+Math.cos(a)*(3.6*s+L),sun[1]+Math.sin(a)*(3.6*s+L),.55*s,'or',.25)}
 blob(b,sun[0],sun[1],4*s,4*s,'or',.15);blob(b,sun[0]-.3,sun[1]-.3,1.7*s,1.7*s,'car',.4+.4*P.glow);
 if(!P.drop)blob(b,hand[0],hand[1],2.3*s,2.1*s,'or',.18);
 // ---- flamme d'or dans la paume levée (incantation)
 if(P.raise>.3){const g=P.raise;blob(b,back[0],back[1]-3*s,2.2*s*g,3*s*g,'glow',.5+.4*Math.sin(t*14));px(b,Math.round(back[0]),Math.round(back[1]-6*s*g),'glow',1)}
 if(P.spark)for(const[a,d]of[[-.4,5],[.3,7],[-1,6]])px(b,Math.round(fx+ux+Math.cos(a)*d*s),Math.round(U(41)+Math.sin(a)*d*s),'glow',1);
 return {b,P}}

function frame(vid,anim,t){const V=VARIANTS.find(v=>v.id===vid)||VARIANTS[0];const{b,P}=draw(V,anim,t);
 const c=document.createElement('canvas');c.width=FW;c.height=FH;const g=c.getContext('2d');const img=render(b,1);
 g.globalAlpha=P.fade;g.drawImage(img,AX-FX,AY-FY);g.globalAlpha=1;
 if(P.flash){const k=document.createElement('canvas');k.width=FW;k.height=FH;const q=k.getContext('2d');q.drawImage(c,0,0);q.globalCompositeOperation='source-atop';q.fillStyle='rgba(255,246,220,.7)';q.fillRect(0,0,FW,FH);g.drawImage(k,0,0)}
 return c}
return{VARIANTS,ANIMS,frame,FW,FH,AX,AY,pose}})();
