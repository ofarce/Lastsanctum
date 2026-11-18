// Martyre de Byrsa v3 (habillage C « fendue », attaques 4 et 5) : raffinements du modèle, animations
// complètes (incantations, touchée, mort), fissures et sceaux en relief avec dégradés de chaleur.
// S'appuie sur martyre-v2.js (figure, tampon pixel, poses).
'use strict';
const MartyreV3=(()=>{
const M=MartyreV2,{Px,ell,glow,ring,disc,rng,cl,ease,lerp,poly,line,seg,glyph,easeOut,back,FW,FH,CX,FY,SW,SH,GY,BX,BY,EX}=M,PAL=M.PAL;
const B4=[[0,8,2,10],[12,4,14,6],[3,11,1,9],[15,7,13,5]],bay=(x,y)=>(B4[y&3][x&3]+.5)/16;
// rampe de chaleur, du rouge sombre de la Bête au blanc incandescent
const HEAT=['#1a0204','#3e080c','#6e1014','#a41a1a','#d63a22','#f26a2a','#ffa846','#ffdc8c','#fff6dc'];
const LIGHT=['#3a280c','#6a4a16','#a07424','#d0a038','#f0cc66','#fff2b0','#fffbe8'];
const STONE=['#140e0a','#211812','#30241a','#423224','#55432f','#6a563c'];
// tirage tramé dans une rampe : v ∈ [0,1]
const ramp=(r,v,x,y)=>{v=cl(v);const f=v*(r.length-1),i=Math.floor(f);return r[Math.min(r.length-1,f-i>bay(Math.round(x),Math.round(y))?i+1:i)]};
const fxr=(P,x,y,r,v,a=1)=>P.fxs(x,y,ramp(r,v,x,y),a);

/* ================= modèle C : trois raffinements cumulatifs ================= */
const DULL=['#2e220e','#56401a','#82642a','#a88438','#c8a654','#e4d090'],LIT=['#3e1a0c','#78341a','#b05a2a','#d8823a','#f0aa5a','#ffd8a0'];
const DULL_I={};DULL.forEach((c,i)=>DULL_I[c]=i);
// M1 : la lumière coule dans les fêlures (pouls qui remonte vers les épaules) et rougeoie l'or autour
function liveCracks(P,info,s,amp=1){const t=s.t,pts=[];
 for(const c of info.cracks)for(let i=0;i+1<c.length;i++){const[a,b]=c[i],[e,f]=c[i+1],n=Math.ceil(Math.hypot(e-a,f-b));for(let j=0;j<n;j++)pts.push([lerp(a,e,j/n),lerp(b,f,j/n)])}
 // la lueur large de l'habillage C est remplacée par un tracé net
 for(const[x,y]of pts)for(let dy=-3;dy<=3;dy++)for(let dx=-3;dx<=3;dx++){const X=Math.round(x+dx),Y=Math.round(y+dy);if(X>=0&&Y>=0&&X<P.w&&Y<P.h)P.fx[Y*P.w+X]=null}
 pts.forEach(([x,y],i)=>{const pulse=.5+.5*Math.sin(i*.45-t*5);
  P.fxs(x+1,y,HEAT[1]);P.fxs(x-1,y,HEAT[2],.7);disc(P,x,y,2.2,HEAT[3],.18+.25*pulse*amp);fxr(P,x,y,HEAT,.5+.45*pulse*amp);
  if(pulse>.7)for(let dy=-2;dy<=2;dy++)for(let dx=-2;dx<=2;dx++){if(dx*dx+dy*dy>4)continue;const X=Math.round(x+dx),Y=Math.round(y+dy);if(X<0||Y<0||X>=P.w||Y>=P.h)continue;
   const k=Y*P.w+X,ci=DULL_I[P.c[k]];if(ci!=null)P.c[k]=LIT[ci]}})}
// M2 : l'armure cède — éclats manquants sur la cuirasse et une épaulière, cœur incandescent, fragments en orbite
function brokenArmor(P,info,s){const t=s.t,Q=info.Q;
 for(const[cx,cy,r]of[[56,59,2.6],[65,68,2],[71,57,2.2]]){const[x,y]=Q(cx,cy);for(let j=-r-1;j<=r+1;j++)for(let i=-r-1;i<=r+1;i++){const d=Math.hypot(i,j)/r;if(d>1.05)continue;
  const X=Math.round(x+i),Y=Math.round(y+j);if(d>.8){P.set(X,Y,STONE[1],true);continue}P.set(X,Y,ramp(HEAT,.95-d*.55+.08*Math.sin(t*4+cx),X,Y),true)}}
 for(let k=0;k<4;k++){const g=t*.9+k*1.57,[ox,oy]=Q(k<2?44:76,55),x=ox+Math.cos(g)*(4+k%2*2),y=oy-6+Math.sin(g)*2.2-Math.sin(t*2+k)*1.5;
  poly(P,[[x-2,y-1],[x+1.5,y-2],[x+2,y+.5],[x-1,y+1.5]],info.gold,{v:.7,edge:.3});P.set(x+1,y+1.5,info.gold[1]);P.fxs(x,y+3,HEAT[4],.4)}}
// M3 : possédée — fumée carmin qui monte des failles et des épaules, traînées des yeux, ichor qui goutte
function possessed(P,info,s){const t=s.t,Q=info.Q,R=rng(41);
 for(let k=0;k<26;k++){const base=info.cracks[k%info.cracks.length][0],per=1.6+R()*1.4,u=((t+R()*per)%per)/per,x=base[0]+(R()-.5)*8+Math.sin(u*5+k)*2.5,y=base[1]-u*26-R()*4;
  P.fxs(x,y,u<.4?HEAT[3]:HEAT[1+(k%2)],(1-u)*.75);if(u<.5)P.fxs(x+1,y,HEAT[2],(1-u)*.5)}
 for(const ex of[info.hx-1.5,info.hx+2.5])for(let i=1;i<5;i++)P.fxs(ex-i*.8-(s.lean||0)*.3,info.hy-i*.4,HEAT[i<2?6:4],.8-i*.15);
 for(let k=0;k<3;k++){const[x,y]=Q(53.5+k*6.5,85.5),d=((t*.6+k*.37)%1);if(d<.8)P.fxs(x,y+d*10,PAL.ichor[3]);P.set(x,y,PAL.ichor[2])}}
const MODELS=[
 {id:'m1',name:'C1 · Failles vivantes',desc:'Le C retenu, où la lumière se met à couler : un pouls remonte les fêlures, du rouge sombre au blanc, et l’or autour s’échauffe par vagues. C’est le socle des deux suivantes.',post:(P,i,s)=>liveCracks(P,i,s)},
 {id:'m2',name:'C2 · L’armure cède',desc:'C1, plus des éclats arrachés à la cuirasse et à l’épaulière droite, qui laissent voir un cœur incandescent. Quatre fragments d’or flottent en orbite autour des épaules. Prépare la mort : c’est cette armure qui éclate.',post:(P,i,s)=>{liveCracks(P,i,s);brokenArmor(P,i,s)}},
 {id:'m3',name:'C3 · Possédée',desc:'C1, plus une fumée carmin qui monte des failles en volutes, des traînées de lumière derrière les yeux et de l’ichor qui goutte des tassettes. Le plus « Bête » ; très lisible de nuit.',post:(P,i,s)=>{liveCracks(P,i,s);possessed(P,i,s)}},
];
let MODEL=0;

/* ================= poses supplémentaires ================= */
// incantation des sceaux : bâton planté, main gauche levée, glyphe qui se forme
function castSeal(a,t){const I=M.idle(t),up=a<.35?ease(a/.35):a<.85?1:1-ease(cl((a-.85)/.15));
 return{...I,crouch:-.8*up,lean:-.6*up,armL:[lerp(45,41,up),lerp(79,44,up)],cast:up,eyes:up,ang:-.06*up}}
// touchée : recul, épaules relevées, retour amorti
function hit(a,t){const I=M.idle(t),k=Math.exp(-a*6)*Math.cos(a*14);return{...I,lean:-3.2*k,crouch:-1.2*k,eyes:a<.4?1:0,hand:[78-2*k,73-2*k],ang:-.12*k,flash:a<.12}}
// mort : chancelle, s'agenouille, le bâton tombe, la lumière perce, puis tout s'éteint
function death(d,t){const I=M.idle(t);
 if(d<.2){const e=ease(d/.2);return{...I,lean:-2.6*e,eyes:1,k:1}}
 if(d<.45){const e=ease((d-.2)/.25);return{...I,lean:lerp(-2.6,1.5,e),crouch:lerp(0,13,e),hand:[lerp(78,82,e),lerp(73,80+6*e,e)],ang:lerp(0,1.35,e*e),eyes:1,k:1}}
 return{...I,lean:1.5,crouch:13,hand:[82,86],ang:1.35+cl((d-.45)/.1)*.2,eyes:d<.6?1:0,k:1,plates:d<.5?1:0}}
function heap(P,k){if(k<=0)return;const g=DULL;
 ell(P,60,FY-3,15*k+1,4*k+1,PAL.robe,{v:.5});for(const[x,y,r]of[[52,FY-5,4],[67,FY-4,4.5],[60,FY-6,5]])ell(P,x,y,r*k+.5,r*.65*k+.5,g,{v:.5});
 seg(P,[40,FY-1],[92,FY-4],2.4,PAL.shaft,{v:.5});ell(P,95,FY-5,4.5*k+.5,3.5*k+.5,g,{v:.62});P.set(95,FY-5,HEAT[3]);M.horn(P,[[47,FY-4],[44,FY-8],[40,FY-8],[38,FY-5]],2.2*k+.4,.7,PAL.horn,{bands:6})}

/* rendu d'une animation du modèle courant dans un tampon 150 × 120 */
const ANIMS=[
 {id:'idle',name:'Repos',len:4,desc:'Boucle de 4 s, 96 images. Respiration, cape et cheveux en retard, rubans, pouls des failles.'},
 {id:'walk',name:'Marche',len:2.2,desc:'Pas lourd, bâton en canne ; corps penché, la cape traîne derrière.'},
 {id:'fissure',name:'Frappe et fissure',len:1.6,desc:'Anticipation, élévation, abattage avec traînée, impact et secousse ; la fissure part du point d’impact.'},
 {id:'seal',name:'Incantation des sceaux',len:2,desc:'Bâton planté, main gauche levée : un glyphe d’or se forme puis s’éteint quand les sceaux sont posés.'},
 {id:'hit',name:'Touchée',len:1,desc:'Recul amorti en 0,4 s, éclair sur l’armure, étincelles. Jouée au plus une fois par seconde.'},
 {id:'death',name:'Mort',len:3.2,desc:'Elle chancelle, tombe à genoux, lâche le bâton ; la lumière perce par les failles, l’armure éclate, le corps s’efface en braises.'},
];
function anim(id,u,t){const P=new Px(FW,FH),post=MODELS[MODEL].post;let s,fxs=null;
 if(id==='walk')s=M.walk(u);
 else if(id==='fissure'){s=u<1?M.strike(u,t):M.idle(t);if(u>=.5&&u<1.1)fxs=k=>impactFx(k,118,FY-1,(u-.5)/.6,t)}
 else if(id==='seal')s=castSeal(u/2,t);
 else if(id==='hit')s=hit(u,t);
 else if(id==='death')s=death(u/3.2,t);
 else s=M.idle(t);
 s.v=2;s.t=t;
 const d=id==='death'?u/3.2:-1;
 s.post=(Q,info,ss)=>{post(Q,info,ss);
  if(ss.flash)for(let i=0;i<Q.c.length;i++){const ci=DULL_I[Q.c[i]];if(ci!=null)Q.c[i]=LIT[Math.min(5,ci+2)]}
  if(d>=.45){// rayons de lumière par les failles, puis dissolution tramée du haut vers le bas
   const g=cl((d-.45)/.2),gone=cl((d-.58)/.32);for(const c of info.cracks){const[x,y]=c[0];for(let r=0;r<7;r++){const an=r/7*Math.PI*2+.3;for(let l=2;l<g*26;l++)fxr(Q,x+Math.cos(an)*l,y+Math.sin(an)*l*.8,HEAT,.95-l/30,g*(1-gone))}}
   if(gone>0)for(let y=0;y<Q.h;y++)for(let x=0;x<Q.w;x++){const i=y*Q.w+x;if(Q.c[i]&&gone*1.3-(y/Q.h)*.3>bay(x,y)){Q.c[i]=null;if(bay(x,y)>gone*1.3-(y/Q.h)*.3-.08)Q.fx[i]=HEAT[5]}}}};
 M.figure(P,s);if(id==='death'&&d>=.58)heap(P,ease(cl((d-.58)/.3)));if(s.smear)M.smearFx(P,s.smear,0,0);if(fxs)fxs(P);
 if(id==='hit'&&u<.35){const R=rng(Math.floor(t*30));for(let i=0;i<9;i++){const g=R()*6.28,l=u*30*R();P.fxs(60+Math.cos(g)*l,63+Math.sin(g)*l*.7,LIGHT[4+(i%3)])}}
 if(id==='death'&&d>=.48&&d<.75){const R=rng(7),k=(d-.48)/.27;for(let i=0;i<7;i++){const g=-2.6+R()*2.2,v=20+R()*16,x=60+Math.cos(g)*v*k,y=60+Math.sin(g)*v*k+k*k*40;poly(P,[[x-2,y-1],[x+2,y-1.5],[x+1.5,y+1.5],[x-1.5,y+1]],DULL,{v:.6,edge:.3})}}
 if(id==='death'&&d>.6){const R=rng(13);for(let i=0;i<30;i++){const u2=cl((d-.6-R()*.2)/.35);if(u2<=0||u2>=1)continue;P.fxs(48+R()*24+Math.sin(u2*6+i)*2,FY-6-R()*40-u2*30,HEAT[u2<.5?6:4],1-u2)}}
 return{c:M.raster(P),shake:id==='fissure'&&u>=.5&&u<.6?Math.round(Math.sin(u*90)):0}}
function impactFx(P,x,y,k,t){ring(P,x,y,4+k*26,1.5+k*7,LIGHT[4],(1-k)*.9);ring(P,x,y,2+k*14,1+k*4,HEAT[6],(1-k));
 const R=rng(3);for(let i=0;i<8;i++){const g=-Math.PI*R(),v=14+R()*10,px=x+Math.cos(g)*v*k,py=y+Math.sin(g)*v*k*.6+k*k*16;P.fxs(px,py,STONE[3+(i%2)]);P.fxs(px+1,py,STONE[2])}}

/* ================= fissures : chemin, trois rendus en relief ================= */
function path(x0,x1,y,seed,amp=3){const R=rng(seed),pts=[];let off=0,v=0;for(let x=x0;x<=x1;x++){v+=(R()-.5)*.9;v*=.9;off=cl(off+v*.6,-amp,amp);pts.push([x,y+off])}
 const br=[];for(let k=0;k<5;k++){const i=Math.floor((k+.5)/5*pts.length),dir=R()<.5?-1:1,L=4+R()*7,b=[];let[x,yy]=pts[i];for(let j=0;j<L;j++){x+=.8+R()*.6;yy+=dir*(.3+R()*.5);b.push([x,yy])}br.push({at:i,pts:b})}
 return{pts,br}}
const wAt=(i,n,wmax)=>Math.max(.6,wmax*Math.pow(Math.sin(Math.PI*cl((i+2)/(n+4))),.5));
// F1 : faille en relief — lèvres de pierre, paroi du fond, lit incandescent en dégradé, halo au sol, braises
function faultTrench(P,pth,u,cool,t,wmax=3.2){const N=pth.pts.length,n=Math.floor(u*N);
 for(let i=0;i<n;i+=2){const[x,y]=pth.pts[i],open=cl((n-i)/14),hw=wAt(i,N,wmax)*open;disc(P,x,y+.5,hw+5,HEAT[3],.22*(1-cool));disc(P,x,y+.5,hw+2.5,HEAT[4],.22*(1-cool))}
 for(let i=0;i<n;i++){const[x,y]=pth.pts[i],open=cl((n-i)/14),hw=wAt(i,N,wmax)*open,flow=.1*Math.sin(i*.35-t*9);
  const top=Math.round(y-hw),bot=Math.round(y+hw),depth=Math.max(1,Math.round(hw*.9));
  P.fxs(x,top-1,STONE[4]);if(i%3)P.fxs(x,top-2,STONE[5],.5);
  for(let yy=top;yy<top+depth&&yy<bot;yy++)P.fxs(x,yy,ramp(STONE,.15+(yy-top)/depth*.25,x,yy));
  for(let yy=top+depth;yy<=bot;yy++){const c=1-Math.abs(yy-(top+depth+bot)/2)/Math.max(1,(bot-top-depth)/2+.5);P.fxs(x,yy,ramp(HEAT,(.45+.5*c+flow)*(1-cool*.7),x,yy))}
  P.fxs(x,bot+1,STONE[1]);P.fxs(x,bot+2,STONE[3],.6)}
 for(const b of pth.br){if(b.at>=n)continue;const k=cl((n-b.at)/20);b.pts.forEach(([x,y],j)=>{if(j/b.pts.length<k){P.fxs(x,y,ramp(HEAT,(.75-j/b.pts.length*.4)*(1-cool*.7),x,y));P.fxs(x,y-1,STONE[4],.7)}})}
 if(u<1){const[x,y]=pth.pts[Math.max(0,n-1)];glow(P,x,y,5,[HEAT[4],HEAT[6],HEAT[8]],1)}
 const R=rng(5);for(let k=0;k<18;k++){const i=Math.floor(R()*n),per=.8+R(),ph=((t+R()*per)%per)/per;if(!n)break;const[x,y]=pth.pts[i];P.fxs(x+Math.sin(ph*6+k)*1.5,y-ph*14,HEAT[ph<.5?7:5],(1-ph)*(1-cool))}}
// F2 : dalles soulevées — le sol se casse en plaques qui basculent ; tranche visible, lumière entre les plaques
function faultSlabs(P,pth,u,cool,t){const N=pth.pts.length,n=Math.floor(u*N),R=rng(17);
 for(let i=0;i<n;i+=2){const[x,y]=pth.pts[i];disc(P,x,y,6,HEAT[3],.22*(1-cool))}
 for(let i=0;i<n;i++){const[x,y]=pth.pts[i];P.fxs(x,y,ramp(HEAT,(.85+.1*Math.sin(i*.4-t*8))*(1-cool*.7),x,y));P.fxs(x,y+1,HEAT[4])}
 for(let i=4;i<n;i+=7){const[x,y]=pth.pts[i],lift=cl((n-i)/18)*(3.5+R()*1.5),tilt=(R()-.5)*.6,side=R()<.5?-1:1,w=5.5,h=3.2;
  const cy=y+side*3.2-lift,pts=[[x-w/2,cy-h/2+tilt*3],[x+w/2,cy-h/2-tilt*3],[x+w/2,cy+h/2-tilt*3],[x-w/2,cy+h/2+tilt*3]];
  poly(P,[[pts[3][0],pts[3][1]],[pts[2][0],pts[2][1]],[pts[2][0],pts[2][1]+lift],[pts[3][0],pts[3][1]+lift]],STONE,{v:.4,edge:.1});
  for(let xx=Math.round(pts[3][0]);xx<=pts[2][0];xx++)P.fxs(xx,Math.round(pts[3][1]+lift+1),HEAT[5],.8*(1-cool));
  poly(P,pts,['#35291c','#4d3c29','#5c4932','#6e5a40','#83704f','#9a8662'],{v:.62,edge:.22,l:.4})}
 if(u<1){const[x,y]=pth.pts[Math.max(0,n-1)];glow(P,x,y,5,[HEAT[4],HEAT[6],HEAT[8]],1)}}
// F3 : pics de cristal — fil incandescent, et des prismes de lumière rouge qui jaillissent derrière la pointe
function prism(P,x,y,h,w,k){if(h<1)return;const tipx=x+(k-.5)*2;poly(P,[[x-w,y],[x,y+1],[tipx,y-h]],[HEAT[2],HEAT[3],HEAT[4],HEAT[5],HEAT[6],HEAT[7]],{v:.75,edge:.15,l:.2});poly(P,[[x,y+1],[x+w,y],[tipx,y-h]],[HEAT[1],HEAT[2],HEAT[3],HEAT[4],HEAT[5]],{v:.45,edge:.15,l:.2});line(P,x,y,tipx,y-h,HEAT[8],true,.8)}
function faultCrystal(P,pth,u,cool,t){const N=pth.pts.length,n=Math.floor(u*N),R=rng(29);
 for(let i=0;i<n;i++){const[x,y]=pth.pts[i];P.fxs(x,y,ramp(HEAT,(.7+.2*Math.sin(i*.5-t*10))*(1-cool*.8),x,y));if(i%2)P.fxs(x,y-1,STONE[4],.6)}
 for(let i=6;i<n;i+=9){const[x,y]=pth.pts[i],age=(n-i)/N,h=(age<.15?age/.15:Math.max(0,1-(age-.15)*3))*(7+R()*6)*(1-cool);prism(P,x,y,h,2.2,R());disc(P,x,y,4,HEAT[4],.3*h/10)}
 if(u<1){const[x,y]=pth.pts[Math.max(0,n-1)];glow(P,x,y,4,[HEAT[4],HEAT[6],HEAT[8]],1)}}
// éruptions au bout de la fissure (e ∈ [0,1])
function eruptTrench(P,x,y,e,t){const R=rng(61),w=7*(1-e*.6),h=lerp(70,90,e)*(e<.12?e/.12:1);
 for(let yy=0;yy<h;yy++){const ww=w*(1-yy/h*.5);for(let xx=-ww;xx<=ww;xx++){const c=1-Math.abs(xx)/ww;fxr(P,x+xx,y-yy,HEAT,(.4+.6*c)*(1-yy/h*.35)+.05*Math.sin(yy*.3-t*20),(1-e)*(1-yy/h*.6))}}
 for(let i=0;i<9;i++){const g=-Math.PI*(.1+.8*R()),v=20+R()*30,px=x+Math.cos(g)*v*e,py=y+Math.sin(g)*v*e*1.4+e*e*55;if(py>y+2)continue;poly(P,[[px-2.5,py-1.5],[px+2,py-2],[px+2.5,py+1],[px-2,py+1.5]],STONE,{v:.55,edge:.3});P.fxs(px,py+2.5,HEAT[5],.6)}
 ring(P,x,y,4+e*22,1.5+e*6,HEAT[6],(1-e))}
function eruptSlabs(P,x,y,e,t){const R=rng(71);disc(P,x,y,10*(1-e)+2,HEAT[5],.6*(1-e));disc(P,x,y,5*(1-e)+1,HEAT[8],.8*(1-e));
 for(let i=0;i<7;i++){const g=-Math.PI*(.15+.7*R()),v=18+R()*20,px=x+Math.cos(g)*v*e,py=y+Math.sin(g)*v*e*1.6+e*e*60,sz=2.5+R()*2;if(py>y+3)continue;
  poly(P,[[px-sz,py-sz*.6],[px+sz,py-sz*.8],[px+sz,py+sz*.4],[px-sz,py+sz*.6]],['#2a2016','#35291c','#413222','#4d3c29','#5c4932'],{v:.6,edge:.25});P.fxs(px,py+sz,HEAT[5])}
 for(let yy=0;yy<40*(1-e);yy++)fxr(P,x+Math.sin(yy*.4)*1.5,y-yy,HEAT,.9-yy/50,1-e)}
function eruptCrystal(P,x,y,e,t){const grow=ease(cl(e/.3)),shat=cl((e-.45)/.4);
 if(shat<=0){for(const[dx,h,w]of[[-7,16,3],[-2,28,4],[4,22,3.5],[9,13,2.6],[0,10,3]])prism(P,x+dx,y,h*grow,w,.5+dx*.03);glow(P,x,y-8,9,[HEAT[3],HEAT[5],HEAT[7]],.5*grow)}
 else{const R=rng(81);for(let i=0;i<16;i++){const g=-Math.PI*R(),v=10+R()*28,px=x+Math.cos(g)*v*shat,py=y-14+Math.sin(g)*v*shat+shat*shat*30;poly(P,[[px,py-2],[px+1.5,py],[px,py+2],[px-1.5,py]],[HEAT[3],HEAT[4],HEAT[5],HEAT[6],HEAT[7]],{v:.7,edge:.2})}
  disc(P,x,y-12,14*(1-shat)+2,HEAT[7],.7*(1-shat))}}
const FISSURES=[
 {id:'f1',name:'4.1 · Faille en relief',draw:faultTrench,erupt:eruptTrench,
  desc:'La fissure est une vraie tranchée : lèvres de pierre claires, paroi du fond dans l’ombre, et au fond un lit en fusion en dégradé (rouge sombre sur les bords, orange, puis jaune et blanc au centre) qui coule. Elle s’ouvre derrière la pointe, qui reste fine et éclatante. Halo au sol, petites ramifications, braises. Au bout : une colonne de lumière en dégradé et des pierres projetées. Puis la faille refroidit et s’éteint en 1 s.'},
 {id:'f2',name:'4.2 · Dalles soulevées',draw:faultSlabs,erupt:eruptSlabs,
  desc:'Le sol se casse en plaques qui basculent de chaque côté du trait et se soulèvent : on voit leur tranche sombre, et la lumière fuit en dessous. Un relief plus « physique », qui se lit bien comme un obstacle qui avance. Au bout, les plaques sautent.'},
 {id:'f3',name:'4.3 · Pics de cristal',draw:faultCrystal,erupt:eruptCrystal,
  desc:'Un fil incandescent court au sol ; derrière la pointe jaillissent des prismes de lumière rouge, une face claire et une face sombre, qui retombent aussitôt. Au bout, une gerbe de cinq prismes pousse puis vole en éclats. Le plus « magique » des trois.'},
];

/* ================= sceaux : trois rendus en relief ================= */
const SR=13;
function sealBase(P,cx,cy,t,i,a=1){for(let k=0;k<72;k++){const g=k/72*Math.PI*2+(i%2?-1:1)*t*.8;P.fxs(cx+Math.cos(g)*SR,cy+Math.sin(g)*SR*.42,LIGHT[k%9<6?4:2],a);if(k%2)P.fxs(cx+Math.cos(g)*(SR-2),cy+Math.sin(g)*(SR-2)*.42,LIGHT[3],a*.8)}
 for(let k=0;k<6;k++){const g=k/6*Math.PI*2-t*.5;glyph(P,cx+Math.cos(g)*SR*.62-1,cy-2+Math.sin(g)*SR*.26,k+i,LIGHT[4],a)}}
function fillDisc(P,cx,cy,r,fill,a){for(let y=-r*.42;y<=r*.42;y++)for(let x=-r;x<=r;x++){const d=Math.sqrt(x*x/(r*r)+y*y/(r*r*.176));if(d>1)continue;const on=d<fill;if(on)fxr(P,cx+x,cy+y,LIGHT,.35+.5*(1-Math.abs(d-fill)*3),a*.7)}}
// S1 : anneaux qui s'élèvent, puis colonne cylindrique ombrée (bords dorés sombres, cœur blanc), bandes qui montent
function sealRings(P,cx,cy,fill,boom,t,i){if(boom<0){sealBase(P,cx,cy,t,i);fillDisc(P,cx,cy,SR-1,fill,.8);for(let r=0;r<3;r++){const h=fill*(6+r*7),w=SR*(1-r*.15)*fill;ring(P,cx,cy-h,w,w*.42,LIGHT[4-r],fill*.8,1)}return}
 const k=boom,h=96,w=SR*.85*(1-k*.4);for(let y=0;y<h;y++)for(let x=-w;x<=w;x++){const c=Math.sqrt(1-(x/w)**2);fxr(P,cx+x,cy-y,LIGHT,(.25+.75*c)*(1-y/h*.3)+.08*Math.sin((y+t*80)*.35),(1-k)*(1-y/h*.75))}
 for(let r=0;r<3;r++)ring(P,cx,cy-(k*60+r*20)%h,w+2,(w+2)*.42,LIGHT[5],(1-k)*.9);ring(P,cx,cy,SR+k*10,(SR+k*10)*.42,HEAT[6],1-k)}
// S2 : sceau qui tombe — une médaille d'or épaisse descend du ciel, son ombre grandit au sol, impact
function coin(P,cx,cy,t){const r=SR,th=4;for(let y=0;y<th;y++)for(let x=-r;x<=r;x++){const yy=Math.sqrt(Math.max(0,1-(x/r)**2))*r*.42;fxr(P,cx+x,cy+yy+y,LIGHT,.25+.25*(1-Math.abs(x)/r))}
 for(let y=-r*.42;y<=r*.42;y++)for(let x=-r;x<=r;x++){const d=Math.sqrt(x*x/(r*r)+y*y/(r*r*.176));if(d>1)continue;fxr(P,cx+x,cy+y,LIGHT,d>.85?.45:.6+.25*(-x/r-y/(r*.42))*.5)}
 for(let k=0;k<12;k++){const g=k/12*Math.PI*2+t*.4;P.fxs(cx+Math.cos(g)*r*.55,cy+Math.sin(g)*r*.55*.42,LIGHT[2])}P.fxs(cx,cy,HEAT[4]);P.fxs(cx-1,cy,HEAT[3])}
function sealFall(P,cx,cy,fill,boom,t,i){if(boom<0){const sh=ease(fill);for(let y=-SR*.42*sh;y<=SR*.42*sh;y++)for(let x=-SR*sh;x<=SR*sh;x++)if(x*x/(SR*SR*sh*sh)+y*y/(SR*SR*.176*sh*sh)<1)P.fxs(cx+x,cy+y,'#140c08',.55);
  sealBase(P,cx,cy,t,i,.4+.6*fill);coin(P,cx,cy-lerp(110,4,fill*fill),t);for(let y=0;y<lerp(110,4,fill*fill)-4;y+=3)P.fxs(cx+Math.sin(y)*.5,cy-y,LIGHT[3],.25);return}
 const k=boom;if(k<.25)coin(P,cx,cy-2,t);ring(P,cx,cy,SR+k*30,(SR+k*30)*.42,LIGHT[5],1-k,1.6);ring(P,cx,cy,SR*.6+k*16,(SR*.6+k*16)*.42,HEAT[6],1-k);
 const R=rng(i*9+3);for(let j=0;j<6;j++){const g=R()*Math.PI*2,L=(6+R()*10)*Math.min(1,k*4);let x=cx,y=cy;for(let s=0;s<L;s++){x+=Math.cos(g);y+=Math.sin(g)*.42;fxr(P,x,y,HEAT,.8-s/L*.4,1-k)}}
 for(let j=0;j<10;j++){const g=-Math.PI*R(),v=8+R()*14;P.fxs(cx+Math.cos(g)*v*k*1.5,cy+Math.sin(g)*v*k-k*6,STONE[4],1-k)}disc(P,cx,cy-3,SR*(1-k),LIGHT[6],(1-k)*.8)}
// S3 : rai du ciel — un fil vertical tremblant vise le cercle, puis la lumière tombe en colonne et brûle le sol
function sealSky(P,cx,cy,fill,boom,t,i){if(boom<0){sealBase(P,cx,cy,t,i);if(Math.sin(t*40+i)>-.4)for(let y=0;y<cy;y++)P.fxs(cx+Math.sin(y*.2+t*10)*.6*(1-fill),y,LIGHT[3+(fill>.6?2:0)],.35+.5*fill);fillDisc(P,cx,cy,SR-1,fill,.6);return}
 const k=boom,w=SR*.7*(k<.1?k/.1:1)*(1-k*.5);for(let y=0;y<=cy;y++){const ww=w*(.6+.4*y/cy);for(let x=-ww;x<=ww;x++){const c=1-Math.abs(x)/ww;fxr(P,cx+x,y,LIGHT,.3+.7*c,(1-k)*(.5+.5*y/cy))}}
 for(let y=-SR*.42;y<=SR*.42;y++)for(let x=-SR;x<=SR;x++){const d=Math.sqrt(x*x/(SR*SR)+y*y/(SR*SR*.176));if(d<1)fxr(P,cx+x,cy+y,HEAT,(1-d)*.9*(1-k*.5)+.2,.9)}
 const R=rng(i+5);for(let j=0;j<12;j++){const u=((k*2+R())%1);P.fxs(cx+(R()-.5)*SR*1.6,cy-u*30,HEAT[u<.5?6:4],1-u)}}
const SEALS=[
 {id:'s1',name:'5.1 · Anneaux qui s’élèvent',draw:sealRings,
  desc:'Le cercle gravé se remplit de lumière depuis le centre, en dégradé, tandis que trois anneaux d’or s’élèvent l’un au-dessus de l’autre et donnent la hauteur. Quand il est plein : une colonne ombrée comme un cylindre (bords dorés sombres, cœur blanc), parcourue de bandes qui montent.'},
 {id:'s2',name:'5.2 · Sceau qui tombe',draw:sealFall,
  desc:'Une médaille d’or épaisse, gravée d’un soleil, descend du ciel au-dessus de chaque cercle ; son ombre grandit au sol, c’est le compte à rebours. Elle frappe : onde de choc, fissures carmin rayonnantes, éclats de pierre. Le plus lisible pour esquiver.'},
 {id:'s3',name:'5.3 · Rai du ciel',draw:sealSky,
  desc:'Un fil de lumière tremblant tombe du ciel sur le cercle et se raffermit pendant le remplissage. Puis la lumière s’abat en colonne évasée, en dégradé, et le sol brûle (rampe carmin → blanc), avec des braises qui montent.'},
];

/* ================= scènes d'attaque ================= */
const FPATH=path(BX+120,EX,GY-2,4);
function fissureScene(P,F,a,t){const pose=a<1?M.strike(cl(a),t):M.idle(t);pose.v=2;pose.post=MODELS[MODEL].post;M.figure(P,pose,BX,BY);M.smearFx(P,pose.smear,BX,BY);
 if(a>=.5&&a<1.1)impactFx(P,BX+118,GY-1,(a-.5)/.6,t);
 const u=cl((a-.5)/.8),cool=cl((a-2.1)/.9);if(a>=.5)F.draw(P,FPATH,u,cool,t);
 let hit=false;if(a>=1.3&&a<2.2){const e=(a-1.3)/.9;F.erupt(P,EX,GY-2,e,t);hit=e<.35}return{hit}}
function sealScene(P,S,a,t){const pose=a<2.2?castSeal(a/2.2,t):M.idle(t);pose.v=2;pose.post=MODELS[MODEL].post;const info=M.figure(P,pose,BX,BY);
 if(a<2.2&&pose.cast>.2){const[x,y]=info.lh;glyph(P,x-1,y-8,Math.floor(t*4),LIGHT[5],pose.cast)}
 const fill=cl((a-.6)/1.3),boom=a>=1.9&&a<2.8?(a-1.9)/.9:-1;let hit=false;
 if(a>=.6&&a<2.8)[[EX-40,0],[EX,1],[EX+36,2]].forEach(([cx,i])=>{S.draw(P,cx,GY-2,fill,boom,t,i)});hit=boom>=0&&boom<.35;return{hit}}

return{HEAT,LIGHT,MODELS,ANIMS,FISSURES,SEALS,anim,fissureScene,sealScene,path,setModel:m=>{MODEL=m},
 closeFissure(P,F,a,t){const pth=closeFissure.p||(closeFissure.p=path(6,128,34,12,4));const u=cl(a/1.2),cool=cl((a-2)/.8);F.draw(P,pth,u,cool,t);if(a>=1.2&&a<2)F.erupt(P,128,34,(a-1.2)/.8,t)}};
function closeFissure(){}
})();
