// Brute (Automate doré de Byrsa) et Strazhar (champion de Byrsa) au standard de la refonte 16 bits :
// planche planches/brute-strazhar-propositions.html (piste G1 de planches/unites-maj-propositions.html).
// Moteur de l'Ingénieur (engineer-colosse.js : R, MAT, buf, blob, rect, px, render) + rampes de refonte-16bits.js
// (or, car, bone, iron). Charte : paliers francs sans trame, contour teinté, lumière en haut à gauche, or = Laetan.
// Profil tourné vers la droite (le jeu retourne le sprite). Rigs procéduraux : poses clés interpolées, membres en
// cinématique inverse. Attaques avec armement tenu (coups annoncés : 0,4 s pour la Brute, 0,25 s pour le Strazhar).
// Expose : G1 = {BRUTES, STRAZ, ANIMS, frame(unit, variante, anim, t) → canvas, SIZE}.
'use strict';
for(const[k,v]of Object.entries({
 mag:['#2a0618','#7a1248','#c22a7a','#f066a8','#ffd0e6'],     // lueur magenta du Strazhar (yeux, emblèmes)
 brz2:['#140c02','#382404','#5a3c08','#80590e','#a67c20'],    // or bruni des articulations et des ombres d'armure
 core:['#0a1a3a','#1e4a90','#4a90e0','#a0d4ff','#ffffff'],    // noyau de l'Automate
 dust2:['#2a2016','#4d3c29','#6e5a40','#8e7a5a','#b4a07a'],   // poussière du choc
}))if(!R[k]){R[k]=v;MAT.push(k)}

const G1=(()=>{
const TAU=Math.PI*2,cl=(v,a=0,b=1)=>Math.max(a,Math.min(b,v)),lerp=(a,b,t)=>a+(b-a)*t,ease=t=>t*t*(3-2*t);
const sm=(a,b,t)=>ease(cl((t-a)/(b-a))),L2=(p,q,t)=>[lerp(p[0],q[0],t),lerp(p[1],q[1],t)];
const hash=(x,y)=>{const v=Math.sin(x*12.9898+y*78.233)*43758.5453;return v-Math.floor(v)};
function seg(b,x0,y0,x1,y1,r0,r1,mat,bias=0){const n=Math.max(2,Math.ceil(Math.hypot(x1-x0,y1-y0)*2.2));
 for(let i=0;i<=n;i++){const t=i/n,r=Math.max(.75,lerp(r0,r1,t));blob(b,lerp(x0,x1,t),lerp(y0,y1,t),r,r,mat,bias)}}
// pixel posé seulement sur de la matière déjà dessinée (gravures, fissures, rivets)
function over(b,x,y,mat,s){x=Math.round(x);y=Math.round(y);if(x<0||y<0||x>=b.w||y>=b.h||b.m[y*b.w+x]<0)return;px(b,x,y,mat,s)}
function dot(b,x,y,mat,s){px(b,Math.round(x),Math.round(y),mat,s)}
function ik(a,c,l1,l2,bend){const dx=c[0]-a[0],dy=c[1]-a[1],d=cl(Math.hypot(dx,dy),Math.abs(l1-l2)+.05,l1+l2-.05),base=Math.atan2(dy,dx),
 al=Math.acos(cl((l1*l1+d*d-l2*l2)/(2*l1*d),-1,1)),an=base+bend*al;return[a[0]+Math.cos(an)*l1,a[1]+Math.sin(an)*l1]}
function star(b,x,y,mat,r){dot(b,x,y,mat,1);for(let i=1;i<=r;i++){dot(b,x+i,y,mat,1-i*.15);dot(b,x-i,y,mat,1-i*.15);dot(b,x,y+i,mat,1-i*.15);dot(b,x,y-i,mat,1-i*.15)}}
function shock(b,x,g,k){for(let i=0;i<10;i++){const s=i%2?1:-1,d=3+k*(6+hash(i,3)*9),h=Math.sin(k*Math.PI)*(1+hash(i,7)*4);if(hash(i,11)<k*.6)continue;
  dot(b,x+s*d,g-1-h,'dust2',.9-k*.5);if(i<6)dot(b,x+s*(d-1),g-1,'dust2',.6-k*.3)}}

// =====================================================================================================
// Brute · Automate doré de Byrsa (cadre 48 × 46, pieds en (24, 43))
// =====================================================================================================
const BW=48,BH=46,BAX=24,BG=43;
const BRUTES=[
 {id:'A',name:'A · Automate à noyau',desc:'Le plus proche de l’actuel : une sphère d’or sans tête, noyau de cristal bleu serti au centre, ceinture rivetée, deux poings énormes. Tramé remplacé par des plaques franches.'},
 {id:'B',name:'B · Colosse cuirassé',desc:'Un casque-dôme enfoncé entre deux épaulières massives, le noyau derrière une grille, des lambrequins carmin de Byrsa à la taille. Se lit comme un soldat géant plus que comme une machine.',head:true,grille:true,pagne:true,paul:6.6},
 {id:'C',name:'C · Golem fêlé',desc:'Carcasse bossue et fendue : la lumière du noyau fuit par les fissures. Asymétrique, un bras-marteau de fer pour frapper, un bras grêle pour s’appuyer. Le plus menaçant, le moins « doré ».',cracks:true,hammer:true,hump:true},
];
function brutePose(anim,t){
 const rF=[13,-9],rB=[-11,-8];
 if(anim==='idle'){const s=Math.sin(t/2*TAU),d=s>.25?1:0,h=s>.6?1:0;
  return{bob:d,fF:[rF[0],rF[1]+d+h],fB:[rB[0],rB[1]+d],lF:[0,0],lB:[0,0],glow:.5+.5*Math.sin(t*TAU)}}
 if(anim==='walk'){const ph=(t/.9)%1,s=Math.sin(ph*TAU),c=Math.cos(ph*TAU),up=Math.abs(s)<.75;
  return{bob:Math.abs(s)>.85?1:0,sway:Math.round(s*1.2),fF:[rF[0]-3.5*s,rF[1]-Math.max(0,-s)*2],fB:[rB[0]+3.5*s,rB[1]-Math.max(0,s)*2],
   lF:[3.5*s,c>0&&up?2:0],lB:[-3.5*s,c<=0&&up?2:0],glow:.55,step:Math.abs(s)>.93?1:0}}
 if(anim==='hit'){const k=Math.sin(cl(t/.25)*Math.PI);return{bob:Math.round(k),lean:-Math.round(k*2),fF:[rF[0]-k*2,rF[1]-k*3],fB:[rB[0]-k*2,rB[1]-k*2],lF:[0,0],lB:[0,0],glow:1}}
 // mort : sursaut, le noyau clignote, les bras tombent, la carcasse s'affaisse sur ses jambes et s'éteint
 if(anim==='death'){const f=sm(0,.12,t),d=sm(.2,.95,t),dn=ease(d);
  return{bob:Math.round(-f*2*(1-d)+dn*9),lean:Math.round(-f*2*(1-d)+dn*3),fF:L2(L2(rF,[11,-13],f),[16,5],dn),fB:L2(L2(rB,[-12,-12],f),[-14,5],dn),lF:[dn*3,0],lB:[-dn*3,0],
   glow:t<.9?(Math.floor(t*14)%2?1:.15)*(1-d*.7):0,dead:t>=.9,shock:t>.8&&t<1.05?(t-.8)/.25:0}}
 // attaque : lève les deux poings (0 à 0,12 s), les tient (jusqu'à 0,40 s), s'abat (0,46 s), se redresse (1,05 s)
 const up=sm(0,.12,t),down=sm(.40,.46,t),rec=sm(.62,1.05,t),hiF=[7,-31],hiB=[-3,-30],loF=[17,4],loB=[9,5];
 const fF=t<.40?L2(rF,hiF,up):rec>0?L2(loF,rF,rec):L2(hiF,loF,down),fB=t<.40?L2(rB,hiB,up):rec>0?L2(loB,rB,rec):L2(hiB,loB,down);
 const hold=t>.12&&t<.40;
 return{bob:t<.40?-Math.round(up*2):Math.round(2*down*(1-rec)),lean:t<.40?-Math.round(up):Math.round(3*down*(1-rec)),fF,fB,lF:[0,0],lB:[0,0],
  glow:hold?1:.6,glint:hold?(t-.12)/.28:0,shock:t>.46&&t<.66?(t-.46)/.2:0,hit:t>.44&&t<.5}}
function brute(V,anim,t){const b=buf(BW,BH),p=brutePose(anim,t),cx=BAX+(p.sway||0)+(p.lean||0),cy=BG-18+(p.bob||0),g=BG;
 const leg=(s,l,bias)=>{const fx=BAX+s*6+l[0],fy=g-1-l[1];seg(b,cx+s*5,cy+9,fx,fy-3,3.3,3.5,'brz2',bias+.05);blob(b,fx+1,fy-1,4.6,2.6,bias<0?'brz2':'or',bias<0?.25:-.05);over(b,fx-2,fy,'brz2',.4)};
 const arm=(s,f,bias)=>{const S=[cx+s*(V.hump&&s<0?8:9.5),cy-5],F=[cx+f[0],cy+9+f[1]+ -(p.bob||0)],thin=V.hammer&&s<0,ham=V.hammer&&s>0;
  const E=ik(S,F,10,10,s>0?-1:1);
  const far=bias<0,fm=far?'brz2':'or',fb=far?.3:.02;
  seg(b,S[0],S[1],E[0],E[1],thin?2.4:3.4,thin?2:2.9,'brz2',bias+.1);blob(b,E[0],E[1],thin?2:2.8,thin?2:2.8,fm,fb);
  seg(b,E[0],E[1],F[0],F[1],thin?2:2.9,thin?2.2:3.4,'brz2',bias+.05);
  if(ham){const a=Math.atan2(F[1]-E[1],F[0]-E[0]);for(let u=-5;u<=5;u++)for(let v=-4;v<=4;v++){const x=F[0]+Math.cos(a)*v*.0+u,y=F[1]+v;dot(b,x,y,'iron',.8-(u+5)*.035-(v+4)*.04+bias)}
   for(let u=-5;u<=5;u++){dot(b,F[0]+u,F[1]-4,'brz2',.75+bias);dot(b,F[0]+u,F[1]+4,'brz2',.4+bias)}dot(b,F[0],F[1],'or',.9)}
  else{blob(b,F[0],F[1],thin?3.2:5.2,thin?3:4.8,fm,fb);for(let i=-2;i<=2;i++)over(b,F[0]+i*1.7,F[1]+(thin?2:3),'brz2',.3);for(let i=-1;i<=1;i++)over(b,F[0]+i*2.4,F[1]-1,'brz2',.6)}
  blob(b,S[0],S[1]-1,V.paul||5.4,(V.paul||5.4)*.82,fm,far?.3:.12);for(let i=-3;i<=3;i++)over(b,S[0]+i,S[1]+2,'brz2',.5);
  return F};
 // arrière-plan : jambe et bras du fond
 leg(-1,p.lB,-.22);const FB=arm(-1,p.fB,-.2);
 // corps
 if(V.hump)blob(b,cx-4,cy-7,9,7,'or',-.02);
 blob(b,cx,cy,V.hump?11.5:12.5,V.hump?12:12.5,'or',.04);
 // ceinture rivetée et plaques
 for(let x=-12;x<=12;x++){over(b,cx+x,cy+6+Math.round(Math.abs(x)*-.08),'brz2',.55-Math.abs(x)*.02);if((x+12)%4===1)over(b,cx+x,cy+5+Math.round(Math.abs(x)*-.08),'or',.98)}
 for(let x=-12;x<=12;x++)over(b,cx+x,cy+7+Math.round(Math.abs(x)*-.1),'brz2',.35);
 for(let y=-12;y<=12;y++){over(b,cx-6+Math.round(y*.12),cy+y,'brz2',.6);if(y>7)over(b,cx+2,cy+y,'brz2',.5)}
 for(let x=-12;x<=12;x++)over(b,cx+x,cy+11,'brz2',.5+Math.abs(x)*.01);for(let x=-11;x<=11;x++)over(b,cx+x,cy+12,'brz2',.4);
 if(V.pagne)for(const[dx,len]of[[-6,6],[-2,8],[2,7],[6,5]]){rect(b,cx+dx-1,cy+8,3,len,'car',dx*.01);dot(b,cx+dx,cy+8+len,'or',.9)}
 // noyau
 const kx=cx+4,ky=cy-2,gl=p.glow||.5;
 blob(b,kx,ky,5.6,5.6,'brz2',.1);if(p.dead){blob(b,kx,ky,4.2,4.2,'iron',-.25);dot(b,kx-1,ky-2,'iron',.6)}else{blob(b,kx,ky,4.2,4.2,'core',-.08+gl*.3);dot(b,kx-1,ky-2,'core',1);dot(b,kx-2,ky-1,'core',.95);if(gl>.8){dot(b,kx,ky,'core',1);dot(b,kx+1,ky+1,'core',.9)}}
 if(V.grille)for(let i=-3;i<=3;i+=2)for(let y=-4;y<=4;y++)over(b,kx+i,ky+y,'brz2',.5);
 if(V.cracks){const cr=[[kx-5,ky-4,-1,-1,7],[kx+3,ky+5,1,1,6],[kx-6,ky+3,-1,1,6],[kx+1,ky-6,0,-1,5]];
  for(const[x0,y0,dx,dy,n]of cr)for(let i=0;i<n;i++){const x=x0+dx*i+(i%3===1?(dy?1:0):0),y=y0+dy*i+(i%3===2?(dx?1:0):0);over(b,x,y,'core',gl>.8?.95:.55+gl*.3-i*.04)}}
 if(V.head){blob(b,cx+2,cy-13,4.8,4,'or',.12);for(let x=0;x<=4;x++)over(b,cx+1+x,cy-13,x%2&&!p.dead?'core':'brz2',x%2?.5+gl*.5:.3);over(b,cx+2,cy-17,'car',.8);dot(b,cx+2,cy-18,'car',.9)}
 // premier plan
 leg(1,p.lF,0);const FF=arm(1,p.fF,0);
 if(p.glint){const k=p.glint,on=Math.floor(k*6)%2===0;if(on){star(b,FF[0]+1,FF[1]-5,'core',2);star(b,FB[0],FB[1]-5,'core',1)}}
 if(p.hit)star(b,FF[0]+2,g-2,'core',3);
 if(p.shock)shock(b,(FF[0]+FB[0])/2+2,g,p.shock);
 if(p.step)for(let i=0;i<3;i++)dot(b,BAX-8+i*8+hash(i,2)*3,g-1-(i%2),'dust2',.7);
 return b}

// =====================================================================================================
// Strazhar · champion de Byrsa, à quatre pattes partout (cadre 68 × 48, pieds en (33, 45))
// =====================================================================================================
const SW=68,SH=48,SAX=33,SG=45;
const STRAZ=[
 {id:'A',name:'A · Champion couronné',desc:'Le plus proche de l’actuel : heaume à couronne de pointes, pavois sanglé à l’avant-bras sur lequel il s’appuie, cape carmin, yeux magenta. Tout ce qui existait debout, replié à quatre pattes.',crown:true,shield:true,cape:1},
 {id:'B',name:'B · Lion de Byrsa',desc:'Une crinière de lames d’or du heaume aux reins, des gantelets plus gros que la tête, cape en lambeaux. Pas de bouclier : il frappe des deux poings. La silhouette la plus bestiale.',mane:true,cape:2,fist:5.2},
 {id:'C',name:'C · Bélier du Credo',desc:'Cornes de bélier enroulées, épaules de taureau, tête basse. Pas de cape, des bannières carmin à la ceinture. L’attaque devient un coup de tête : le plus facile à lire comme « ça charge ».',horns:true,banner:true,paul:7.6,low:true},
];
const SREST={hip:[21,SG-13],sh:[38,SG-19],fist:[45,SG-3],fistB:[39,SG-3],foot:[20,SG-2],footB:[25,SG-2],head:[10,-2]};
const mixPose=(a,b,t)=>{const o={};for(const k in a)o[k]=L2(a[k],b[k],t);return o};
function strazPose(V,anim,t){const R0=SREST;
 if(anim==='idle'){const br=Math.sin(t/3*TAU*1.5)>.2?1:0,look=t%3>2?Math.round(Math.sin((t%3-2)*Math.PI)*2):0,paw=t%3>.9&&t%3<1.5?Math.sin((t%3-.9)/.6*Math.PI):0;
  return{...R0,sh:[R0.sh[0],R0.sh[1]+br],head:[R0.head[0]-look,R0.head[1]+br+(look?-1:0)],fist:[R0.fist[0]+paw*2,R0.fist[1]-paw*3],eye:.6+.4*Math.sin(t*TAU/1.5),cape:br*.3}}
 if(anim==='walk'){const ph=(t/.56)%1,pair=(q,x0,reach,back)=>{const u=(ph+q)%1;if(u<.45){const k=u/.45;return[x0+reach-(reach+back)*k,0]}const k=(u-.45)/.55;return[x0-back+(reach+back)*ease(k),Math.sin(k*Math.PI)*7]};
  const f=pair(0,R0.sh[0],13,7),h=pair(.5,R0.hip[0],9,6),rock=Math.sin(ph*TAU);
  return{hip:[R0.hip[0],R0.hip[1]+1+rock*2],sh:[R0.sh[0]+1,R0.sh[1]+2-rock*2.5],fist:[f[0],SG-3-f[1]],fistB:[f[0]-4,SG-3-f[1]*.8],foot:[h[0],SG-2-h[1]],footB:[h[0]+4,SG-2-h[1]*.8],
   head:[11,1-rock],eye:.9,cape:1,run:1,land:(ph<.08)?1:0}}
 if(anim==='hit'){const k=Math.sin(cl(t/.25)*Math.PI);return{...R0,sh:[R0.sh[0]-2*k,R0.sh[1]-2*k],head:[R0.head[0]-k,R0.head[1]-2*k],eye:1.4,cape:-.3*k}}
 // mort : sursaut en arrière, puis les bras cèdent et il s'écrase de tout son long, les yeux s'éteignent
 if(anim==='death'){const FL={...R0,sh:[R0.sh[0]-3,R0.sh[1]-5],head:[R0.head[0]-1,R0.head[1]-3],fist:[R0.fist[0]-1,R0.fist[1]-4]};
  const DOWN={hip:[21,SG-7],sh:[40,SG-8],fist:[54,SG-3],fistB:[49,SG-3],foot:[11,SG-2],footB:[15,SG-2],head:[10,4]};
  const q=t<.2?mixPose(R0,FL,sm(0,.12,t)):mixPose(FL,DOWN,ease(sm(.2,.8,t)));
  return{...q,eye:t<.7?(Math.floor(t*12)%2?1.2:.2):-1,cape:0,shock:t>.72&&t<.95?(t-.72)/.23:0}}
 // attaque : se cabre (0 à 0,09 s), tient (jusqu'à 0,25 s), s'abat (0,31 s), revient à quatre pattes (0,8 s)
 const REAR=V.horns?{hip:[23,SG-14],sh:[33,SG-25],fist:[36,SG-14],fistB:[31,SG-13],foot:[20,SG-2],footB:[25,SG-2],head:[4,-7]}
                  :{hip:[24,SG-14],sh:[34,SG-29],fist:[41,SG-39],fistB:[34,SG-38],foot:[20,SG-2],footB:[25,SG-2],head:[5,-4]};
 const SLAM=V.horns?{hip:[26,SG-13],sh:[45,SG-15],fist:[50,SG-3],fistB:[45,SG-3],foot:[21,SG-2],footB:[26,SG-2],head:[11,3]}
                  :{hip:[23,SG-12],sh:[42,SG-15],fist:[56,SG-3],fistB:[50,SG-3],foot:[20,SG-2],footB:[25,SG-2],head:[9,2]};
 const p=t<.25?mixPose(R0,REAR,sm(0,.09,t)):t<.45?mixPose(REAR,SLAM,sm(.25,.31,t)):mixPose(SLAM,R0,sm(.45,.8,t));
 const hold=t>.09&&t<.25;
 return{...p,eye:hold?1.4:.8,glint:hold?(t-.09)/.16:0,shock:t>.31&&t<.5?(t-.31)/.19:0,hit:t>.29&&t<.35,cape:t<.25?-.6*sm(0,.09,t):.6*(1-sm(.45,.8,t))}}
function straz(V,anim,t){const b=buf(SW,SH),p=strazPose(V,anim,t),g=SG,hip=p.hip,sh=p.sh,hd=[sh[0]+p.head[0],sh[1]+p.head[1]+(V.low?2:0)];
 const leg=(F,bias)=>{const K=ik(hip,F,8.5,8.5,-1),far=bias<0,m=far?'brz2':'or',mb=far?.28:0;
  seg(b,hip[0],hip[1],K[0],K[1],3.8,2.8,'brz2',bias+.1);blob(b,K[0],K[1],2.7,2.7,m,mb+.05);seg(b,K[0],K[1],F[0],F[1],2.6,2.3,m,mb-.03);blob(b,F[0]+1.5,F[1]+.5,3.6,2,m,mb-.06);over(b,F[0]+3,F[1]+1,'brz2',.3)};
 const arm=(F,bias,front)=>{const E=ik(sh,F,11,11,1),fr=V.fist||4.2;
  const far=bias<0,m=far?'brz2':'or',mb=far?.28:0;
  seg(b,sh[0],sh[1],E[0],E[1],3.6,2.9,'brz2',bias+.1);blob(b,E[0],E[1],2.8,2.8,m,mb+.05);seg(b,E[0],E[1],F[0],F[1],3,3.5,m,mb-.02);
  for(let v=-3;v<=3;v++)over(b,(E[0]+F[0])/2+v*.3,(E[1]+F[1])/2+v,'brz2',.5);
  blob(b,F[0],F[1],fr,fr*.9,m,mb+.03);for(let i=-1;i<=1;i++){over(b,F[0]+i*2,F[1]+fr*.55,'brz2',.3);over(b,F[0]+i*2.2,F[1]-1,'brz2',.55)}
  if(front&&V.shield){const mx=(E[0]+F[0])/2+2,my=(E[1]+F[1])/2-1.5;blob(b,mx,my,5.6,8.2,'or',.1);blob(b,mx,my,4,6.6,'car',.05);
   for(let y=-4;y<=4;y++)over(b,mx,my+y,'mag',.95-Math.abs(y)*.06);for(const[ox,oy]of[[-1,-2],[1,-2],[-2,-3],[2,-3],[-1,2],[1,2]])over(b,mx+ox,my+oy,'mag',.75)}
  return E};
 // cape : part des épaules, file au-dessus des reins, retombe derrière (ou claque droit en arrière à la course)
 // cape : posée sur le dos des épaules aux reins, puis retombe derrière (claque droit en arrière à la course)
 const cape=()=>{if(!V.cape)return;const span=sh[0]-hip[0],len=Math.round(span+(p.run?20:11)),fl=p.cape||0;
  for(let i=0;i<=len;i++){const x=sh[0]-1-i,on=cl(i/Math.max(1,span+3)),u=i/len,past=Math.max(0,i-span-3);
   const top=lerp(sh[1]-8.5,hip[1]-7.5,on)-Math.sin(on*Math.PI)*.8,drop=p.run?past*.12:past*past*.16,wave=Math.sin(i*.55+t*TAU*(p.run?3.2:.6))*(p.run?1.4:.5)*(past>0?1:0);
   const y=top+drop+wave-fl*past*.7,th=past>0?Math.round(lerp(8,4,past/(len-span))):6;
   if(V.cape===2&&past>2&&i%4===0)continue;
   for(let d=0;d<th-(V.cape===2&&past>0&&i%3===1?3:0);d++)dot(b,x,y+d,'car',.8-u*.22-d*.07);
   if(i%5===2&&past<=0)dot(b,x,y,'or',.95)}};
 leg(p.footB,-.22);arm(p.fistB,-.2,false);
 // torse : des reins aux épaules, plaques
 seg(b,hip[0],hip[1],sh[0],sh[1],6.2,8,'brz2',.12);
 const dx=sh[0]-hip[0],dy=sh[1]-hip[1],n=Math.hypot(dx,dy);
 for(const[u,r]of[[.18,5.6],[.5,6.4],[.82,7.4]])blob(b,hip[0]+dx*u+dy/n*1.2,hip[1]+dy*u-dx/n*-1.2,r*.62,r,'or',.06);
 // reins : jupe carmin ou bannières
 if(V.banner){for(const[o,l]of[[-3,9],[1,11],[5,8]]){const x=hip[0]+o,y=hip[1]+3;for(let i=0;i<l;i++)for(let d=0;d<3;d++)dot(b,x+d-(p.run?i*.6:0),y+i,'car',.75-i*.04-d*.08);dot(b,x+1-(p.run?l*.6:0),y+l,'or',.9)}}
 else blob(b,hip[0]-1,hip[1]+3,7.2,6.4,'car',-.02,(x,y)=>y>=hip[1]);
 cape();
 if(V.mane){const A=[hd[0]-2,hd[1]-5],B=[hip[0]+2,hip[1]-7];for(let i=0;i<=8;i++){const u=i/8,x=lerp(A[0],B[0],u),y=lerp(A[1],B[1],u)-Math.sin(u*Math.PI)*2,L=5-Math.abs(u-.3)*4;
   for(let k=0;k<L;k++)dot(b,x-k*.9-(p.run?k*.5:0),y-k*(p.run?.45:.9),'or',.98-k*.1);dot(b,x,y+1,'brz2',.5)}}
 leg(p.foot,0);
 // tête : heaume, fente, yeux
 seg(b,sh[0]+2,sh[1]-2,hd[0]-2,hd[1]+1,3.2,2.8,'brz2',.05);
 blob(b,hd[0],hd[1],5.4,5,'or',.12);blob(b,hd[0]+3,hd[1]+2.5,3.2,2.6,'or',0);
 for(let x=-1;x<=5;x++){over(b,hd[0]+x,hd[1],'brz2',.2);over(b,hd[0]+x,hd[1]+1,'brz2',.3)}for(let y=2;y<=4;y++)over(b,hd[0]+3,hd[1]+y,'brz2',.4);
 const ey=cl(p.eye||.7,0,1.5);if(!(p.eye<0)){over(b,hd[0]+4,hd[1],'mag',.8+ey*.2);over(b,hd[0]+3,hd[1],'mag',.95);over(b,hd[0]+1,hd[1],'mag',.6+ey*.2)}if(ey>1){dot(b,hd[0]+6,hd[1],'mag',.9);dot(b,hd[0]+4,hd[1]-1,'mag',.8)}
 if(V.crown)for(let i=0;i<4;i++){const x=hd[0]-4+i*2.6,L=[4,7,8,5][i];for(let k=0;k<L;k++){dot(b,x-k*.3,hd[1]-5-k,'or',.98-k*.05);if(k<L-2)dot(b,x+1-k*.3,hd[1]-5-k,'or',.7)}}
 if(V.crown)for(let x=-4;x<=4;x++)over(b,hd[0]+x,hd[1]-4,'brz2',.5);
 if(V.horns){for(let a=0;a<=10;a++){const an=-2.4+a*.36,r=5.8-a*.16,x=hd[0]-2+Math.cos(an)*r,y=hd[1]-2+Math.sin(an)*r*.95;blob(b,x,y,1.9-a*.07,1.9-a*.07,'bone',.2-a*.03)}dot(b,hd[0]+3,hd[1]+2,'bone',1)}
 if(V.mane)for(let i=0;i<3;i++)dot(b,hd[0]-1+i*2,hd[1]-5-(i===1?1:0),'or',1);
 const E=arm(p.fist,0,true);
 blob(b,sh[0],sh[1]-2,V.paul||6,(V.paul||6)*.8,'or',.13);for(let i=-3;i<=3;i++)over(b,sh[0]+i,sh[1]+2-Math.abs(i)*.3,'brz2',.6);if(!(p.eye<0))over(b,sh[0]-1,sh[1]-3,'mag',.8);
 if(p.glint&&Math.floor(p.glint*4)%2===0){if(V.horns)star(b,hd[0]+4,hd[1]-2,'mag',2);else{star(b,p.fist[0]+1,p.fist[1]-5,'mag',2);star(b,p.fistB[0],p.fistB[1]-5,'mag',1)}}
 if(p.hit)star(b,p.fist[0]+3,g-2,'mag',3);
 if(p.shock)shock(b,(p.fist[0]+p.fistB[0])/2+2,g,p.shock);
 if(p.land)for(let i=0;i<4;i++)dot(b,p.fist[0]-4+i*3,g-1-(i%2),'dust2',.75);
 return b}

const ANIMS={
 brute:{idle:{name:'Repos',len:2,loop:true},walk:{name:'Marche',len:.9,loop:true},attack:{name:'Attaque',len:1.2,impact:.4},hit:{name:'Touché',len:.25},death:{name:'Mort',len:1.875}},
 straz:{idle:{name:'Repos',len:3,loop:true},walk:{name:'Ruée',len:.56,loop:true},attack:{name:'Attaque',len:.875,impact:.25},hit:{name:'Touché',len:.25},death:{name:'Mort',len:1.875}},
};
const cache=new Map();
// Image n (à 24 i/s) de l'animation, rendue à l'échelle 1 ; mise en cache.
function frame(unit,vi,anim,t){const A=ANIMS[unit][anim],n=Math.round(A.len*24),i=A.loop?((Math.floor(t*24)%n)+n)%n:Math.min(n-1,Math.max(0,Math.floor(t*24))),key=unit+vi+anim+i;
 if(!cache.has(key))cache.set(key,render(unit==='brute'?brute(BRUTES[vi],anim,i/24):straz(STRAZ[vi],anim,i/24),1));return cache.get(key)}
// Image à l'instant t exact (export : phases de marche régulières), sans cache.
const at=(unit,vi,anim,t)=>render(unit==='brute'?brute(BRUTES[vi],anim,t):straz(STRAZ[vi],anim,t),1);
return{BRUTES,STRAZ,ANIMS,frame,at,SIZE:{brute:{w:BW,h:BH,ax:BAX,ay:BG},straz:{w:SW,h:SH,ax:SAX,ay:SG}}}})();
