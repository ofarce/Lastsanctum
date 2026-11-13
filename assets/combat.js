// Animations de combat (Paladin : 5 coups d'épée ; Tireur : 5 tirs d'arbalète). Dépend de decor.js et units.js.
'use strict';
const CombatKit=(()=>{const{figure,UNITS,TIREUR,K,fill,ell,seg,line,glowDots,outlineAll}=UnitKit;
const PAL=UNITS[0].list[0].s,EW=170,EH=84,PI=Math.PI;
const lerp=(a,b,u)=>a+(b-a)*u,ease=u=>u<.5?2*u*u:1-2*(1-u)*(1-u);
// interpolation de poses clés : [[instant, {main, angle, extension, puissance, dx}], ...]
function keyAt(keys,t){let i=0;while(i<keys.length-1&&keys[i+1][0]<=t)i++;const[a,A]=keys[i],[b,B]=keys[Math.min(i+1,keys.length-1)];const u=b>a?ease(Math.min(1,(t-a)/(b-a))):0,o={};for(const k in A)o[k]=lerp(A[k],B[k]??A[k],u);return o}
const IDLE={hand:1.66,ang:-PI/2,ext:16,pow:.5,dx:0};
function armPose(st){const sx=19,sy=32,h=[sx+Math.cos(st.hand)*st.ext,sy+Math.sin(st.hand)*st.ext],e=[sx+Math.cos(st.hand)*st.ext*.5-1.5,sy+Math.sin(st.hand)*st.ext*.5+3];return{hRo:h,eRo:e}}
/* ---------- effets ---------- */
function boom(E,x,y,p,size,R){if(p<0||p>1)return;const r=size*(.25+.75*Math.sqrt(p));
 for(let j=-r;j<=r;j++)for(let i=-r;i<=r;i++){const d=Math.hypot(i,j*1.15)/r;if(d>1)continue;const heat=(1-p)*(1-d*.7);if(BAYER[(Math.floor(y+j)&3)][(Math.floor(x+i)&3)]>1-p*.9+.1&&p>.5)continue;
  const c=heat>.75?'#ffffff':heat>.55?K.amber[4]:heat>.35?K.amber[3]:heat>.18?K.amber[2]:p>.55?'#4a4440':K.crim[3];E.set(x+i,y+j,c,60)}
 for(let k=0;k<10;k++){const a=R()*6.283,d=r*(1+p*.8)*(.8+R()*.4);if(p<.8)E.set(x+Math.cos(a)*d,y+Math.sin(a)*d*.8,p<.4?K.amber[4]:K.amber[2],61)}}
function bolt(E,x,y,col,trail){for(let i=0;i<trail;i++)if(BAYER[y&3][(x-i)&3]<1-i/trail)E.set(x-i-6,y+((i>>2)&1?0:0),i<4?K.amber[4]:K.amber[2],55);
 for(let i=0;i<7;i++)E.set(x-i,y,i<2?K.polish[6]:K.gun[4],56);E.set(x+1,y,col,57);E.set(x+2,y,col,57);E.set(x+1,y-1,K.amber[3],57);E.set(x+1,y+1,K.amber[3],57)}
function flash(E,x,y,p,R){if(p>1)return;const n=Math.round(6*(1-p));for(let k=0;k<n+4;k++){const a=(R()-.5)*1.6,d=1+R()*(4+8*(1-p));E.set(x+Math.cos(a)*d,y+Math.sin(a)*d,p<.3?'#ffffff':K.amber[3],58)}}
function smoke(E,x,y,p,R){for(let k=0;k<10;k++){const a=R()*6.283,d=p*8*R();if(R()>p)E.set(x+Math.cos(a)*d-p*6,y+Math.sin(a)*d-p*7,R()<.5?'#5e5a54':'#3e3a36',40)}}
/* ---------- paladin ---------- */
const SWORD=[
 {name:'P1 · Taille horizontale',desc:'Armé derrière l’épaule, balayage large vers l’avant avec traînée lumineuse. Rapide, lisible, polyvalent.',dur:1.3,
  keys:[[0,IDLE],[.3,{hand:2.7,ang:3.3,ext:11,pow:.6,dx:-1}],[.45,{hand:2.8,ang:3.4,ext:11,pow:.8,dx:-1}],[.58,{hand:.15,ang:.2,ext:15,pow:1,dx:2}],[.75,{hand:.5,ang:.7,ext:13,pow:.7,dx:1}],[1.3,IDLE]]},
 {name:'P2 · Frappe verticale',desc:'Lame levée au-dessus du casque, abattue d’un coup sec : onde de choc et poussière à l’impact.',dur:1.4,
  keys:[[0,IDLE],[.35,{hand:-1.9,ang:-2.4,ext:13,pow:.7,dx:-1}],[.5,{hand:-1.95,ang:-2.5,ext:13,pow:1,dx:-1}],[.6,{hand:.8,ang:.7,ext:16,pow:1,dx:2}],[.9,{hand:.85,ang:.75,ext:16,pow:.6,dx:2}],[1.4,IDLE]],
  fx:(E,t,R)=>{const p=(t-.6)/.35;if(p>=0&&p<=1){for(let i=-1;i<=1;i+=2)for(let k=0;k<12;k++){const x=46+i*(4+p*26)*(k/12+.3);E.set(x,80-(R()*3*(1-p)),R()<.5?'#8a7a5a':'#6a5a40',40)}for(let k=0;k<26;k++){const a=-PI*k/25,rr=4+p*20;if(R()>p)E.set(48+Math.cos(a)*rr,79+Math.sin(a)*rr*.35,K.eGold[3-(p>.5)],59)}}}},
 {name:'P3 · Estoc',desc:'Recul sur l’appui puis fente vers l’avant, pointe en ligne : un trait de lumière prolonge la lame.',dur:1.2,
  keys:[[0,IDLE],[.3,{hand:2.6,ang:0,ext:7,pow:.6,dx:-3}],[.42,{hand:2.6,ang:0,ext:7,pow:.9,dx:-3}],[.52,{hand:.05,ang:0,ext:19,pow:1,dx:4}],[.75,{hand:.05,ang:0,ext:18,pow:.7,dx:3}],[1.2,IDLE]],
  fx:(E,t,R)=>{const p=(t-.52)/.25;if(p>=0&&p<=1)for(let i=0;i<30*(1-p*.6);i++)if(R()<1-p)E.set(70+i+p*20,32+(R()-.5)*2,i<6?'#ffffff':K.eGold[3-(i>18)],58)}},
 {name:'P4 · Moulinet',desc:'Rotation complète de la lame autour du poing, cercle de lumière : coup de zone contre les assaillants groupés.',dur:1.5,
  spin:true,keys:[[0,IDLE],[.25,{hand:1,ang:-.6,ext:12,pow:.8,dx:0}],[.95,{hand:1,ang:-.6+PI*2,ext:12,pow:1,dx:0}],[1.5,IDLE]]},
 {name:'P5 · Frappe consacrée',desc:'L’épée est levée et se charge de lumière (particules aspirées), puis s’abat en libérant un croissant de lumière qui file vers l’ennemi.',dur:1.9,
  keys:[[0,IDLE],[.3,{hand:-1.57,ang:-1.57,ext:14,pow:.6,dx:0}],[.85,{hand:-1.57,ang:-1.57,ext:14,pow:1.6,dx:0}],[.98,{hand:.5,ang:.45,ext:16,pow:1.4,dx:3}],[1.3,{hand:.55,ang:.5,ext:16,pow:.6,dx:2}],[1.9,IDLE]],
  fx:(E,t,R)=>{if(t>.3&&t<.9){for(let k=0;k<18;k++){const a=R()*6.283,d=(1-((t*3+k*.13)%1))*16;E.set(19+Math.cos(-1.57)*30+Math.cos(a)*d,32+Math.sin(-1.57)*30+Math.sin(a)*d,K.eGold[3+(R()<.3)],58)}}
   const p=(t-.98)/.7;if(p>=0&&p<=1){const x=58+p*110;for(let j=-14;j<=14;j++){const xx=x-Math.abs(j)**1.6*.18;for(let w=0;w<3;w++)if(R()<1-p*.5)E.set(xx-w,40+j,w===0?'#ffffff':K.eGold[3-w],58)}}}},
];
/* ---------- tireur ---------- */
const XBOW=[
 {name:'T1 · Rafale à répétition',desc:'Trois carreaux tirés coup sur coup : recul bref, le tambour tourne d’un cran à chaque tir, trois petites explosions.',dur:1.6,
  shots:[.15,.35,.55],fx:(E,t,R,o)=>{for(const[i,s]of[.15,.35,.55].entries()){const q=t-s;if(q<0)continue;flash(E,55,41,q/.12,R);const x=56+q*420;if(x<150)bolt(E,Math.round(x),41,K.amber[4],10);else boom(E,152-i*6,40+i*3,(q-.22)/.35,7,R)}}},
 {name:'T2 · Tir lourd',desc:'Mise en charge (tambour qui rougeoie), puis tir unique très puissant : fort recul, fumée à la bouche, grosse explosion.',dur:2,
  shots:[.55],heavy:true,fx:(E,t,R)=>{if(t<.55)glowDots(E,48,45,5+t*6,K.amber[3],Math.floor(t*14),R);const q=t-.55;if(q<0)return;flash(E,55,41,q/.2,R);smoke(E,56,40,Math.min(1,q/.9),R);const x=56+q*340;if(x<145)bolt(E,Math.round(x),41,'#ffffff',22);else boom(E,148,42,(q-.26)/.6,15,R)}},
 {name:'T3 · Carreau à retardement',desc:'Le carreau se plante au sol, son voyant ambré clignote de plus en plus vite, puis explosion à fragmentation.',dur:2.2,
  shots:[.2],fx:(E,t,R)=>{const q=t-.2;if(q<0)return;flash(E,55,41,q/.12,R);const x=56+q*360,y=41+q*q*90;if(x<130)bolt(E,Math.round(x),Math.round(y),K.amber[4],8);
   else if(t<1.65){for(let i=0;i<6;i++)E.set(128-i*.6,74-i,K.gun[4],55);const f=6+(t-.5)*14;if(Math.sin(t*f*6)>0){E.set(129,73,K.amber[4],57);E.set(130,73,K.amber[3],57)}}
   else{boom(E,129,72,(t-1.65)/.55,13,R);const p=(t-1.65)/.55;for(let k=0;k<8;k++){const a=-PI*(.1+.8*k/7),d=p*26;E.set(129+Math.cos(a)*d,72+Math.sin(a)*d,K.gun[5],59)}}}},
 {name:'T4 · Carreau perforant',desc:'Le carreau chauffe à blanc dans le tambour, puis part en trait rectiligne qui traverse tout, anneau de souffle à la bouche.',dur:1.8,
  shots:[.7],fx:(E,t,R)=>{if(t<.7)for(let k=0;k<t*16;k++)E.set(46+R()*10,40+R()*4,t>.45?'#ffffff':K.amber[4],58);const q=t-.7;if(q<0||q>.5)return;const p=q/.5;
   for(let x=56;x<170;x++)if(R()<1-p)E.set(x,41,x<70||R()<.6?'#ffffff':K.eBlue[3],57);for(let a=0;a<20;a++){const aa=a/20*6.283,rr=3+p*9;E.set(57+Math.cos(aa)*rr*.4,41+Math.sin(aa)*rr,K.eWhite[3],58)}}},
 {name:'T5 · Carreau de fragmentation',desc:'Le carreau éclate en vol au-dessus des ennemis et projette six éclats qui explosent en éventail.',dur:2,
  shots:[.2],fx:(E,t,R)=>{const q=t-.2;if(q<0)return;flash(E,55,41,q/.12,R);const x=56+q*300;if(x<112)bolt(E,Math.round(x),41,K.amber[4],12);
   else{const p=(x-112)/300;boom(E,112,41,p*3.5,6,R);for(let k=0;k<6;k++){const a=-.55+k*.22,d=p*240,ex=112+Math.cos(a)*d,ey=41+Math.sin(a)*d+d*d*.004;if(ex<160&&ey<80){E.set(ex,ey,K.amber[4],58);E.set(ex-1,ey,K.amber[2],57)}else boom(E,Math.min(160,ex),Math.min(78,ey),(p-.22)*2.5,6,R)}}}},
];
function frameSword(A,t){const st=keyAt(A.keys,t),prev=keyAt(A.keys,Math.max(0,t-.07)),fast=Math.abs(st.ang-prev.ang)>.25;
 return{spec:{...PAL,right:null,over:[...(PAL.over||[]),'bladeAt'],ang:st.ang,pow:st.pow,power:Math.min(1.5,st.pow),trail:fast?[prev.ang,st.ang]:null,...armPose(st)},dx:Math.round(st.dx)}}
function frameXbow(A,t){let dx=0,rot=0;for(const s of A.shots){const q=t-s;if(q>=0){rot+=2;if(q<.18)dx=-Math.round((A.heavy?4:1.5)*(1-q/.18))}}
 return{spec:{...TIREUR,drumRot:rot,drumHot:A.heavy?Math.min(1,t/.55):0},dx}}
// Rendu d'une image : personnage + couche d'effets, à l'échelle k (0,5 = taille en jeu). fx=false masque les effets.
function render(A,t,kind,k=1,fx=true){const E0=new Px(Math.ceil(EW*k),Math.ceil(EH*k),true),E=k===1?E0:UnitKit.scaled(E0,k),R=rng(Math.floor(t*30)*31+7),f=kind==='s'?frameSword(A,t):frameXbow(A,t);
 if(fx===true&&A.fx)A.fx(E,t,R);else if(typeof fx==='function')fx(E,t,R);E0.flush();
 const fig=figure(f.spec,t,k),c=document.createElement('canvas');c.width=E0.w;c.height=E0.h;const g=c.getContext('2d');g.drawImage(fig,Math.round((4+f.dx)*k),0);g.drawImage(E0.c,Math.round(4*k),0);return c}
return{SWORD,XBOW,render,flash,boom,EW,EH}})();
