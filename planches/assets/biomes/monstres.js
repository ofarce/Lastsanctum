// Monstres des Veines de vert-de-gris (biome 2) : anguille des puits, tique de filon, chauve-souris patinée et
// Gorge-Cuivre (boss de fin). Cinq modèles chacun, au standard de la refonte 16 bits (moteur engineer-colosse.js :
// R, MAT, buf, blob, rect, px, render). Paliers francs sans trame, contour teinté, lumière en haut à gauche.
// Rigs procéduraux : corps en chaîne, pattes en cinématique inverse, ailes en éventail. Les lueurs vont sur un
// calque à part, sans contour ; la partie immergée de l'anguille est peinte à plat sous le sprite.
// Charte : cuivre et vert-de-gris ; pas d'or (Credo), pas de cyan (Exilés), pas de rouge (Bête).
// Expose : MONSTRE = {ROLES, sizeOf(clé), frame(clé, variante, anim, t) → {c, fx}}.
'use strict';
for(const[k,v]of Object.entries({
 vdg:['#0c2a26','#2f6a5c','#4f9a83','#8fd0b0','#d8f4e0'],     // vert-de-gris
 vdgD:['#061a16','#184038','#2a6052','#44826c','#74b094'],    // chair de vert-de-gris
 cu:['#2a120a','#7a4530','#c47b58','#f0b088','#ffe0c8'],      // cuivre
 cuS:['#1e1410','#5a4036','#8e6a58','#b8927c','#dcc0aa'],     // cuivre terni (membranes)
 roche:['#0a1012','#1b2629','#2c3d40','#415659','#5e7678'],
 vase:['#061014','#14323a','#205058','#357c80','#7cc8c0'],    // peau d'anguille
 ventre:['#22302c','#607e72','#98b8a6','#cce0cc','#f4fff0'],  // ventre pâle
 eauS:['#0c2428','#102e32','#143438','#173a3e','#1b4044'],    // corps vu sous l'eau
 ecume:['#3f8a8c','#6ab0b0','#a0d8d4','#d0f0ec','#ffffff'],
 volt:['#0a1440','#2a4ac0','#6a9aff','#c0dcff','#ffffff'],    // décharge
 gueule:['#080304','#22090e','#3c1218','#5c2028','#884048'],  // fond de gueule
 oeil:['#0a2a1a','#2a8a5a','#7ae0a0','#d0ffe0','#ffffff'],
 gorge:['#0c2a2a','#2a6a66','#58a49a','#98d8c8','#e0fff4'],   // abdomen gorgé, translucide
 pouss:['#2a2016','#4d3c29','#6e5a40','#8e7a5a','#b4a07a'],   // poussière, gravats
}))if(!R[k]){R[k]=v;MAT.push(k)}

const MONSTRE=(()=>{
const TAU=Math.PI*2,PI=Math.PI,cl=(v,a=0,b=1)=>Math.max(a,Math.min(b,v)),lerp=(a,b,t)=>a+(b-a)*t,ease=t=>t*t*(3-2*t);
const sm=(a,b,t)=>ease(cl((t-a)/(b-a))),L2=(p,q,t)=>[lerp(p[0],q[0],t),lerp(p[1],q[1],t)];
const hash=(x,y)=>{const v=Math.sin(x*12.9898+y*78.233)*43758.5453;return v-Math.floor(v)};
function seg(b,x0,y0,x1,y1,r0,r1,mat,bias=0){const n=Math.max(2,Math.ceil(Math.hypot(x1-x0,y1-y0)*2.2));
 for(let i=0;i<=n;i++){const t=i/n,r=Math.max(.6,lerp(r0,r1,t));blob(b,lerp(x0,x1,t),lerp(y0,y1,t),r,r,mat,bias)}}
function over(b,x,y,mat,s){x=Math.round(x);y=Math.round(y);if(x<0||y<0||x>=b.w||y>=b.h||b.m[y*b.w+x]<0)return;px(b,x,y,mat,s)}
function dot(b,x,y,mat,s=.9){px(b,Math.round(x),Math.round(y),mat,s)}
function ln(b,x0,y0,x1,y1,mat,l=.7){const n=Math.max(Math.abs(x1-x0),Math.abs(y1-y0))*2|0||1;
 for(let i=0;i<=n;i++){const t=i/n;dot(b,lerp(x0,x1,t),lerp(y0,y1,t),mat,typeof l==='function'?l(t):l)}}
function ik(a,c,l1,l2,bend){const dx=c[0]-a[0],dy=c[1]-a[1],d=cl(Math.hypot(dx,dy),Math.abs(l1-l2)+.05,l1+l2-.05),base=Math.atan2(dy,dx),
 al=Math.acos(cl((l1*l1+d*d-l2*l2)/(2*l1*d),-1,1)),an=base+bend*al;return[a[0]+Math.cos(an)*l1,a[1]+Math.sin(an)*l1]}
function gem(b,x,y,r,mat,l=0){x=Math.round(x);y=Math.round(y);for(let dy=-r;dy<=r;dy++){const w=r-Math.abs(dy);for(let dx=-w;dx<=w;dx++)px(b,x+dx,y+dy,mat,cl(.6-dx*.17-dy*.12+l,.05,.99))}}
function spike(b,x,y,th,len,mat,l=0,w=1){for(let i=0;i<len;i++){const q=i/len,xx=x+Math.cos(th)*i,yy=y+Math.sin(th)*i;dot(b,xx,yy,mat,cl(.9-q*.3+l,.05,.99));if(w>0&&q<.55){dot(b,xx-Math.sin(th),yy+Math.cos(th),mat,cl(.55+l,.05,.99))}}}
function poly(b,pts,mat,sh){let y0=1e9,y1=-1e9;for(const p of pts){y0=Math.min(y0,p[1]);y1=Math.max(y1,p[1])}
 for(let y=Math.ceil(y0);y<=Math.floor(y1);y++){const xs=[];for(let i=0;i<pts.length;i++){const a=pts[i],c=pts[(i+1)%pts.length];if((a[1]<=y&&c[1]>y)||(c[1]<=y&&a[1]>y))xs.push(a[0]+(y-a[1])/(c[1]-a[1])*(c[0]-a[0]))}
  xs.sort((p,q)=>p-q);for(let k=0;k+1<xs.length;k+=2)for(let x=Math.round(xs[k]);x<=Math.round(xs[k+1]);x++){const v=typeof sh==='function'?sh(x,y):sh;if(v>=0)px(b,x,y,mat,v)}}}
const fdot=(F,x,y,mat,l=.9)=>{F.push([Math.round(x),Math.round(y),mat,cl(l,0,.99)])};
function fring(F,cx,cy,rx,ry,mat,l,n,rot=0,skip=1){for(let i=0;i<n;i++){if(skip>1&&i%skip)continue;const a=i/n*TAU+rot;fdot(F,cx+Math.cos(a)*rx,cy+Math.sin(a)*ry,mat,l)}}
function fstar(F,x,y,mat,r){fdot(F,x,y,mat,.99);for(let i=1;i<=r;i++){const l=.95-i*.2;fdot(F,x+i,y,mat,l);fdot(F,x-i,y,mat,l);fdot(F,x,y+i,mat,l);fdot(F,x,y-i,mat,l)}}
function zap(F,x0,y0,x1,y1,seed,mat='volt'){const n=Math.max(3,Math.hypot(x1-x0,y1-y0)/3|0);let ax=x0,ay=y0;for(let i=1;i<=n;i++){const t=i/n,x=lerp(x0,x1,t)+(i<n?(hash(seed,i)-.5)*5:0),y=lerp(y0,y1,t)+(i<n?(hash(i,seed)-.5)*5:0);
  const m=Math.max(Math.abs(x-ax),Math.abs(y-ay))|0||1;for(let j=0;j<=m;j++)fdot(F,lerp(ax,x,j/m),lerp(ay,y,j/m),mat,j&&j<m?.99:.8);ax=x;ay=y}}
function dust(F,x,g,k,n=10,sp=10,mat='pouss'){for(let i=0;i<n;i++){const s=i%2?1:-1,d=2+k*(sp*.5+hash(i,3)*sp),h=Math.sin(k*PI)*(1+hash(i,7)*5);if(hash(i,11)<k*.5)continue;fdot(F,x+s*d,g-1-h,mat,.9-k*.5);if(i<6)fdot(F,x+s*(d-1),g-1,mat,.6-k*.3)}}
function flipV(b,g){let y0=b.h,y1=0;for(let y=0;y<b.h;y++)for(let x=0;x<b.w;x++)if(b.m[y*b.w+x]>=0){y0=Math.min(y0,y);y1=Math.max(y1,y)}
 const o=buf(b.w,b.h),sh=g-1-y1;for(let y=y0;y<=y1;y++)for(let x=0;x<b.w;x++){const i=y*b.w+x;if(b.m[i]<0)continue;const j=(y0+y1-y+sh)*b.w+x;o.m[j]=b.m[i];o.s[j]=cl(1.05-b.s[i]*.9)*.8}return o}
function dim(b,k){for(let i=0;i<b.s.length;i++)if(b.m[i]>=0)b.s[i]=Math.max(.02,b.s[i]-k)}

// =====================================================================================================
// Anguille des puits : ne quitte jamais l'eau. Cadre 64 × 44, surface de l'eau en y = 32.
// =====================================================================================================
const EW=64,EH=44,EAX=32,EG=32;
const EELS=[
 {id:'1',name:'L’Anguille-ruban',desc:'Longue et fine, une nageoire dorsale qui ondule d’un bout à l’autre, deux nœuds voltaïques sur le dos. Au repos seuls trois dos-d’âne et les yeux dépassent. La plus lisible en nuée.',
  len:42,r:2.7,m:{body:'vase',belly:'ventre'},fin:'vdg',finH:2,nodes:[9,21,32]},
 {id:'2',name:'La Murène cuirassée',desc:'Courte, épaisse, la tête et la nuque couvertes d’écailles de cuivre, mâchoire à crocs. Elle sort le cou très haut pour décharger. La plus menaçante, la moins « anguille ».',
  len:30,r:4.2,m:{body:'vdgD',belly:'ventre'},plates:9,jaw:true,nodes:[11]},
 {id:'3',name:'La Lamproie pâle',desc:'Blafarde, aveugle, une ventouse ronde garnie de dents à la place de la tête. Pas de nageoire : un tube qui glisse. La décharge part de la ventouse.',
  len:36,r:3.3,m:{body:'ventre',belly:'ventre'},sucker:true,nodes:[]},
 {id:'4',name:'Le Gymnote à lanternes',desc:'Une rangée d’organes lumineux court sur son flanc et s’allume en chenillard, même sous l’eau : on la voit venir de loin dans une salle noyée. Deux barbillons.',
  len:40,r:3,m:{body:'vase',belly:'ventre'},lanterns:true,whiskers:true,fin:'vase',finH:1,nodes:[]},
 {id:'5',name:'L’Anguille à crête',desc:'Une crête d’épines de cuivre lui sort du dos ; la décharge saute d’épine en épine avant de partir dans l’eau. Reprend le cuivre du biome, se confond le moins avec l’eau.',
  len:38,r:3.1,m:{body:'vdgD',belly:'ventre'},spines:true,nodes:[]},
];
function eel(V,anim,t){
 const b=buf(EW,EH),u=buf(EW,EH),F=[];b.fx=F;b.under=u;const L=V.len,HX=EAX+L/2-2,M=V.m;
 let A=1.5,k=.3,w=1.5,bias=-V.r*.5,lift=0,glow=0,dead=0,sink=0,drift=1.1;
 if(anim==='walk'){A=V.r*.9;k=.34;w=8;bias=-V.r*.15;drift=4}
 if(anim==='act'){const uu=t%2.6;lift=sm(.1,.55,uu)-sm(1.9,2.4,uu);glow=lift>.7?(.7+.3*Math.sin(t*40)):0;A=1.2;w=3}
 if(anim==='death'){dead=sm(.05,.5,t);sink=sm(1.3,2.7,t);A=1.5*(1-dead)+.6;w=1.2;bias=lerp(-V.r*.5,V.r*.55,dead)-sink*V.r*2.4;if(t<.45){lift=Math.sin(t/.45*PI)*.5;A=3}}
 const at=s=>{const x=HX-s,y=EG+Math.sin(s*.2-t*drift)*1.3;let h=A*Math.sin(s*k-t*w)*(.35+.65*Math.min(1,s/8))+bias+V.r*.45*Math.max(0,1-s/5);
  h+=lift*(V.jaw?17:14)*Math.pow(Math.max(0,1-s/(V.jaw?13:16)),1.4);return[x,y,h]};
 const rad=s=>Math.max(.9,V.r*(s<3?.82+.06*s:1-.72*Math.pow((s-3)/(L-3),1.7)));
 const body=dead>.5?M.belly:M.body;
 for(let s=L;s>=0;s-=.6){const[x,y,h]=at(s),r=rad(s),si=Math.round(s/.6);
  blob(u,x,y+Math.max(0,-h)*.3+1,r+.3,Math.max(.8,r*.62),'eauS',-.1);
  if(h+r<=0)continue;const cut=(X,Y)=>Y<=y;let mat=body,bz=0;
  if(V.plates&&s<V.plates&&dead<.5){mat=(Math.floor(s/1.6)%2)?'cu':'cu';bz=(Math.floor(s/1.8)%2)?-.18:.08}
  if(V.fin&&s>4&&s<L-2){const fh=V.finH*(.55+.45*Math.sin(s*.7-t*6));for(let j=1;j<=Math.round(fh);j++)if(y-h-r-j<y)dot(b,x,y-h-r-j+1,V.fin,.75-j*.1)}
  blob(b,x,y-h,r,r,mat,bz,cut);
  if(dead<.5&&h>-r*.3)blob(b,x,y-h+r*.62,r*.8,r*.5,M.belly,-.12,(X,Y)=>Y<=y&&Y>y-h+r*.2);
  if(V.spines&&si%6===0&&s>3&&s<L-5&&dead<.5){const sl=4+((si/6)&1)*2;spike(b,x,y-h-r+1,-PI/2-.25,sl,'cu',0,0);if(glow)fdot(F,x-1,y-h-r-sl+2,'volt',.99)}
  if(V.lanterns&&si%5===2&&s>4&&s<L-4){const on=glow||((si/5|0)+Math.floor(t*7))%5===0;if(h+r>1)over(b,x,y-h+.5,'volt',on?.99:.45);if(on)fdot(F,x,h+r>1?y-h+.5:y+1+Math.max(0,-h)*.3,'volt',h+r>1?.99:.7)}
  for(const ns of V.nodes)if(Math.abs(s-ns)<.3&&h+r>1){gem(b,x,y-h-r+1,1,'volt',glow?.4:-.25);if(glow)fstar(F,x,y-h-r+1,'volt',1)}
  if(si%4===0&&Math.abs(h)<r*.9&&!sink){fdot(F,x-r-1,y+1,'ecume',.55);fdot(F,x+r+1,y+1,'ecume',.75)}}
 // tête
 const[hx,hy0,hh]=at(0),hy=hy0-hh,r=rad(0)+.6,cutH=(X,Y)=>Y<=hy0,open=lift>.5||(anim==='idle'&&(t%4)>3.6);
 if(hh+r>0){
  if(V.sucker){blob(b,hx+1,hy,r+.4,r+.4,body,0,cutH);blob(b,hx+2.4,hy+.2,r-.9,r-.6,'gueule',.1,cutH);for(let i=0;i<8;i++){const a=i/8*TAU+t*(lift?6:0);over(b,hx+2.4+Math.cos(a)*(r-1.2),hy+.2+Math.sin(a)*(r-1),'bone',.95)}
   if(glow){fdot(F,hx+2,hy,'volt',.99);fdot(F,hx+3,hy+1,'volt',.9)}}
  else{blob(b,hx+1.2,hy-(open?.6:0),r,r*.9,V.plates&&dead<.5?'cu':body,.05,cutH);blob(b,hx+r*.9+1,hy+.3-(open?.8:0),r*.62,r*.55,V.plates&&dead<.5?'cu':body,.05,cutH);
   if(open){blob(b,hx+r*.7+1,hy+r*.75,r*.6,r*.4,dead>.5?M.belly:M.body,-.15,cutH);for(let i=0;i<r+1;i++)over(b,hx+1.5+i,hy+r*.35,'gueule',.3)}
   else for(let i=0;i<r+1.5;i++)over(b,hx+1.5+i,hy+r*.45,body,.02);
   if(V.jaw){for(let i=0;i<3;i++){over(b,hx+2.2+i*1.7,hy+r*.45-(open?1:0),'bone',.99);if(open)over(b,hx+3+i*1.6,hy+r*.9,'bone',.9)}}
   const ex=Math.round(hx+1.2),ey=Math.round(hy-r*.25-(open?.6:0));
   if(dead>.5){over(b,ex,ey,'gueule',.2);over(b,ex+1,ey,'gueule',.2)}else{over(b,ex,ey,'oeil',glow?.99:.8);over(b,ex+1,ey,'gueule',.05);if(hh+r>1.5)fdot(F,ex,ey,glow?'volt':'oeil',.99)}
   if(V.whiskers&&dead<.5){ln(b,hx+r+1.6,hy+.8,hx+r+4,hy+2.5+Math.sin(t*4),body,.6);ln(b,hx+r+1.2,hy+1.4,hx+r+2.4,hy+4+Math.sin(t*4+1),body,.45)}
   if(V.plates&&dead<.5){over(b,hx,hy-r*.6,'cu',.99);over(b,hx-2,hy-r*.5,'cu',.95)}}}
 // décharge : arcs autour de la tête, onde sur l'eau
 if(glow){const fr=Math.floor(t*18);for(let i=0;i<4;i++){const a=hash(fr,i)*TAU,d=9+hash(i,fr)*9;zap(F,hx+2,hy,hx+2+Math.cos(a)*d,Math.min(EG+3,hy+Math.sin(a)*d*.8),fr+i)}
  for(let i=0;i<2;i++){const p=(t*1.3+i/2)%1;fring(F,HX-L*.4,EG+2,8+p*20,2+p*5,'volt',.99-p*.7,34,0,2)}fstar(F,hx+2,hy,'volt',2)}
 if(anim==='death'&&sink>0&&sink<1)for(let i=0;i<5;i++){const p=(t*.8+i/5)%1;fdot(F,HX-L*.5+(hash(i,2)-.5)*L*.8,EG-1-p*7,'ecume',.9-p*.6)}
 if(anim==='walk')for(let i=0;i<4;i++){const p=(t*1.6+i/4)%1;fdot(F,HX-L-2-p*8,EG+1+Math.sin(i*2)*2,'ecume',.8-p*.6)}
 return b}

// =====================================================================================================
// Tique de filon. Cadre 48 × 40, sol en y = 34.
// =====================================================================================================
const TW=48,TH=40,TAX=23,TG=34;
const TICKS=[
 {id:'1',name:'La Tique à dos de minerai',desc:'Son abdomen est une croûte de roche semée de pépites de cuivre : collée sur un filon, elle en fait partie. C’est en frappant le filon qu’on la découvre.',
  h:6,arx:7.5,ary:5.6,l1:5,l2:6.5,reach:7.5,m:{ab:'roche',th:'vdgD',leg:'cu'},
  deco(b,F,c){const x=c.ax,y=c.ay;gem(b,x-3,y-3,2,'cu');gem(b,x+2,y-4,1,'cu');gem(b,x+3,y,1,'cu',-.1);gem(b,x-5,y+1,1,'cu',-.15);over(b,x-1,y+1,'vdg',.7);over(b,x+5,y-2,'vdg',.6);
   if(Math.sin(c.t*2.3)>.9)fdot(F,x-4,y-4,'cu',.99)}},
 {id:'2',name:'La Punaise plate',desc:'Une carapace basse et large en plaques de vert-de-gris, des pattes courtes. Elle se plaque au sol au repos et ne dépasse presque pas. Armure lisible : c’est un bouclier qui marche.',
  h:4,arx:9.5,ary:3.6,l1:4,l2:4.5,reach:7,m:{ab:'vdg',th:'vdgD',leg:'cu'},
  deco(b,F,c){const x=c.ax,y=c.ay;for(let i=-8;i<=8;i++)for(const j of[-1,1]){if((i+12)%4===0)over(b,x+i,y+j-1,'vdgD',.5)}for(let i=-9;i<=9;i++)over(b,x+i,y+2,'cu',.6-i*.02);over(b,x-4,y-2,'vdg',.99);over(b,x-3,y-3,'vdg',.99)}},
 {id:'3',name:'La Tique gorgée',desc:'Abdomen énorme, translucide, plein de cuivre fondu qui clapote quand elle marche. Lente, fragile d’aspect, mais c’est elle qui lâche le plus de cuivre. Sa morsure la dégonfle un instant.',
  h:8,arx:8,ary:7.6,l1:5.5,l2:7,reach:7.5,m:{ab:'gorge',th:'vdgD',leg:'cu'},
  deco(b,F,c){const x=c.ax,y=c.ay,sl=Math.sin(c.t*(c.anim==='walk'?9:2))*1.2;for(let j=0;j<=6;j++)for(let i=-7;i<=7;i++){if((i*i)/49+((j+1)*(j+1))/49>.72)continue;if(j<1+sl*(i/7))continue;over(b,x+i,y+j,'cu',cl(.75-j*.07-i*.03,.1,.99))}
   over(b,x-4,y-5,'gorge',.99);over(b,x-3,y-6,'gorge',.99);over(b,x-5,y-4,'gorge',.95);if(Math.sin(c.t*3)>.7)fdot(F,x-2,y+2,'cu',.99)}},
 {id:'4',name:'La Tique à rostre',desc:'Petit corps haut perché sur de longues pattes, un rostre de fer plus long qu’elle. Elle ne mord pas, elle perfore : le rostre part d’un coup et tourne. La silhouette la plus haute.',
  h:10,arx:4.8,ary:4.2,l1:7,l2:9.5,reach:9,m:{ab:'vdg',th:'vdgD',leg:'cu'},
  deco(b,F,c){over(b,c.ax-1,c.ay-2,'vdg',.99);over(b,c.ax+1,c.ay,'cu',.8);over(b,c.ax-2,c.ay+1,'cu',.7);
   const L=9+c.bite*7,sp=Math.floor(c.t*(c.bite>.2?30:0));for(let i=0;i<L;i++){dot(b,c.hx+2+i,c.hy+1+i*.12,'iron',(i+sp)%3===0?.4:.9);if(i<3)dot(b,c.hx+2+i,c.hy+2+i*.12,'iron',.4)}
   if(c.bite>.6)fstar(F,c.hx+2+L,c.hy+1+L*.12,'pouss',1)}},
 {id:'5',name:'La Tique-pince',desc:'Deux pinces de cuivre devant elle, abdomen en anneaux cuirassés. Au repos elle garde les pinces ouvertes ; pour mordre elle se jette et les referme. La plus « ennemi », la moins discrète.',
  h:6,arx:6.6,ary:5,l1:5,l2:6,reach:7,m:{ab:'vdgD',th:'vdgD',leg:'cu'},
  deco(b,F,c){for(let i=-6;i<=5;i+=3)for(let j=-5;j<=5;j++)over(b,c.ax+i+Math.abs(j)*.25,c.ay+j,'cu',.75-j*.06);
   const op=(1-c.bite)*(.55+.2*Math.sin(c.t*2.5));for(const s of[-1,1]){const ex=c.hx+2,ey=c.hy,kx=ex+3,ky=ey-2.5*s-1;seg(b,ex,ey,kx,ky,1.1,1.1,'cu',s>0?-.2:0);
    const a=s*(-op)-.05;seg(b,kx,ky,kx+Math.cos(a+s*.5)*5,ky+Math.sin(a+s*.5)*5+s*1.2,1.6,.9,'cu',s>0?-.2:.05);dot(b,kx+Math.cos(a+s*.5)*6,ky+Math.sin(a+s*.5)*6+s*1.2-s*.8,'bone',.95)}
   if(c.bite>.7)fstar(F,c.hx+8,c.hy-1,'bone',1)}},
];
function tick(V,anim,t){
 let b=buf(TW,TH);const F=[],M=V.m;let bx=TAX,by=TG-1-V.h,ph=0,curl=0,bite=0,br=0,moving=0;
 if(anim==='idle'){by+=Math.min(2.5,V.h-2.5);curl=.3;br=Math.sin(t*1.8)>.3?1:0}
 if(anim==='walk'){ph=t/.6;moving=1;by-=Math.abs(Math.sin(ph*TAU))>.75?1:0}
 if(anim==='act'){const u=t%1.5,back=sm(0,.35,u),go=sm(.38,.5,u),ret=sm(.7,1.2,u);bx+=-2.5*back*(1-go)+6.5*go*(1-ret);by+=1.5*back*(1-go)-go*(1-ret);bite=go*(1-ret)}
 if(anim==='death'){const j=sm(0,.12,t)*(1-sm(.12,.4,t));by-=j*5;curl=.25+.75*sm(.6,1.5,t)+(t>.4&&t<1.4?.18*Math.sin(t*34):0)}
 const hipX=V.arx*.3,ax=bx-V.arx*.5,ay=by-V.ary*.4-br,hx=bx+V.arx*.3+5.4,hy=by+1.2;
 const legs=(far)=>{for(let i=0;i<3;i++){const hxx=bx+hipX+(i-1)*2.4+(far?1.2:0),hyy=by+1.5-(far?.8:0),rest=TAX+hipX+[-1,-.12,.92][i]*V.reach+(far?2:0);
   let fx=rest,lift=0;if(moving){const p=(ph+((i%2)^(far?1:0)?.5:0))%1,S=4.5;if(p<.6)fx=rest+S*(.5-p/.6);else{const q=(p-.6)/.4;fx=rest+S*(q-.5);lift=Math.sin(q*PI)*2.6}}
   let f=[fx,TG-1-lift];f=L2(f,[hxx+(i-1)*2.6,hyy+3.2],cl(curl));const kn=ik([hxx,hyy],f,V.l1*.8,V.l2*.86,f[0]>hxx?-1:1);
   ln(b,hxx,hyy,kn[0],kn[1],'cuS',far?.2:.7);ln(b,kn[0],kn[1],f[0],f[1],'cuS',far?.15:.5);if(!far)dot(b,kn[0],kn[1],M.leg,.8)}};
 legs(true);
 blob(b,ax,ay,V.arx,V.ary+br*.5,M.ab,0);blob(b,bx+V.arx*.3+1.6,by+.6,3.3,2.8,M.th,.05);blob(b,hx,hy,2.2,1.9,M.th,.1);
 const c={bx,by,ax,ay,hx,hy,bite,t,anim};V.deco(b,F,c);
 if(V.id!=='4'&&V.id!=='5'){ln(b,hx+1.5,hy+.5,hx+3+bite*1.5,hy+2,'bone',.9);ln(b,hx+1,hy+1.2,hx+2.2+bite*1.5,hy+3,'bone',.7);if(bite>.7)fstar(F,hx+4,hy+2,'bone',1)}
 px(b,Math.round(hx)+1,Math.round(hy)-1,'oeil',.95);px(b,Math.round(hx)-1,Math.round(hy)-1,'oeil',.6);
 legs(false);
 if(anim==='death'&&t>.3){b=flipV(b,TG);if(t>1.6)dim(b,.12*sm(1.6,2.4,t))}
 else if(anim!=='death'||t>.02){if(anim==='idle'||anim==='walk'||anim==='act')fdot(F,hx+1,hy-1,'oeil',.99)}
 if(anim==='death'&&t>.28&&t<.7)dust(F,TAX,TG,(t-.28)/.42,8,7);
 b.fx=F;return b}

// =====================================================================================================
// Chauve-souris patinée, vue de face. Cadre 64 × 56, sol en y = 50, vol à 24 px du sol.
// =====================================================================================================
const BW=64,BH=56,BAX=32,BG=50;
const BATS=[
 {id:'1',name:'La Patinée commune',desc:'Fourrure vert-de-gris, ailes de cuivre terni, grandes oreilles. Le modèle de référence : lisible en nuée de cinq, battement nerveux.',
  bw:3.4,bh:4.2,hr:3,ear:4,l1:9,l2:11,flap:3.4,m:{fur:'vdg',wing:'cuS',bone:'cu'}},
 {id:'2',name:'L’Oreillard',desc:'Corps minuscule, oreilles plus hautes que lui, ailes longues et fines. Il vole haut et vite ; ce sont les oreilles qu’on voit d’abord.',
  bw:2.6,bh:3.3,hr:2.6,ear:8,l1:8,l2:14,flap:4.4,m:{fur:'vdgD',wing:'cuS',bone:'cu'}},
 {id:'3',name:'La Cuirassée',desc:'Poitrail et front plaqués de cuivre, ailes vert-de-gris trouées. Plus lourde, elle bat lentement et pique droit. Rappelle les écailles de la Murène et les pinces de la Tique.',
  bw:4,bh:4.6,hr:3.2,ear:3,l1:9,l2:10,flap:2.8,holes:true,plate:true,m:{fur:'vdgD',wing:'vdg',bone:'vdgD'}},
 {id:'4',name:'La Queue-lame',desc:'Ailes étroites en faux, longue queue terminée par une lame de cuivre qui fouette derrière elle. Son piqué finit par un coup de queue.',
  bw:2.8,bh:4,hr:2.7,ear:3,l1:7,l2:15,flap:4.6,tail:true,m:{fur:'vdg',wing:'cuS',bone:'cu'}},
 {id:'5',name:'La Roussette lourde',desc:'Grosse, museau long, ailes larges et rondes. Elle plane plus qu’elle ne bat et tient la lumière en respect : c’est celle qui éteint les torches. Cuivre au corps, vert-de-gris aux ailes.',
  bw:5,bh:5.6,hr:3.6,ear:3,l1:11,l2:12,flap:2.2,snout:true,m:{fur:'cu',wing:'vdgD',bone:'vdg'}},
];
function bat(V,anim,t){
 let b=buf(BW,BH);const F=[],M=V.m;b.fx=F;
 if(anim==='idle'){ // suspendue à un bout de roche, ailes refermées en manteau
  const cx=BAX,sw=Math.sin(t*1.3)*1.2,top=11,st=sm(2.2,2.6,t%5)-sm(3.2,3.7,t%5),bw=V.bw+1.2+st*3;
  blob(b,cx,5,9,4.5,'roche',0);blob(b,cx+5,7,4,3,'roche',-.1);blob(b,cx-6,6.5,3.5,2.6,'roche',-.05);
  const bot=top+V.bh*2+V.hr*2+3;px(b,cx-1,top-1,M.bone,.8);px(b,cx+1,top-1,M.bone,.8);px(b,cx-1,top-2,M.bone,.6);px(b,cx+1,top-2,M.bone,.6);
  blob(b,cx+sw*.3,top+V.bh+1,V.bw,V.bh+1,M.fur,0);
  poly(b,[[cx-2,top],[cx+2,top],[cx+bw+sw*.5,top+V.bh*1.2],[cx+bw*.6+sw,bot-V.hr],[cx+sw,bot-V.hr-1-st*3],[cx-bw*.6+sw,bot-V.hr],[cx-bw+sw*.5,top+V.bh*1.2]],M.wing,(x,y)=>cl(.62-(x-cx)*.07-(y-top)*.015-(((x-Math.round(cx+sw*.5)+40)%3===0)?.16:0),.05,.99));
  if(st>.3){blob(b,cx+sw*.6,top+V.bh+2,V.bw*.7,V.bh*.8,M.fur,.05)}
  const hx=cx+sw,hy=bot-V.hr+1;blob(b,hx,hy,V.hr,V.hr,M.fur,.05);if(V.snout)blob(b,hx,hy+V.hr*.7,1.8,1.8,M.fur,.1);if(V.plate)blob(b,hx,hy-.6,V.hr-.8,1.4,'cu',.1);
  for(const s of[-1,1])for(let i=0;i<V.ear;i++)dot(b,hx+s*(V.hr-.6)+s*(i>V.ear*.6?.5:0),hy+V.hr-.5+i,M.fur,.7-i*.05+(s<0?.1:0));
  const aw=(t%5)>2.2&&(t%5)<3.9;for(const s of[-1,1]){px(b,Math.round(hx+s*1.4),Math.round(hy),aw?'oeil':M.fur,aw?.99:.15);if(aw)fdot(F,hx+s*1.4,hy,'oeil',.99)}
  if(V.tail){ln(b,cx,top+2,cx+4+sw,top+12,M.fur,.5);spike(b,cx+4+sw,top+12,PI/2-.2,4,'cu',0,0)}
  return b}
 let cx=BAX,cy=BG-24,a=0,lag=0,dead=0,sq=0,fall=0,tilt=0,fast=1;
 if(anim==='walk'){const ph=t*V.flap*TAU;a=.2+.85*Math.sin(ph);lag=Math.sin(ph-.9);cy+=-Math.cos(ph)*2;cx+=Math.sin(t*1.7)*1.5}
 if(anim==='act'){const u=t%1.9,wd=sm(0,.35,u),dv=sm(.4,.78,u),up=sm(.95,1.7,u),ph=t*V.flap*1.5*TAU;cy+=-5*wd+19*dv-14*up;cx+=-4*wd+11*dv-7*up;
  const sweep=dv*(1-sm(.82,.95,u));a=lerp(.2+.85*Math.sin(ph),1.15,sweep);lag=lerp(Math.sin(ph-.9),1,sweep);tilt=sweep;if(u>.8&&u<.98){fstar(F,cx+3,cy+V.bh+2,'bone',2)}}
 if(anim==='death'){const j=sm(0,.1,t);fall=sm(.15,.75,t);cy+=-3*j*(1-fall)+(BG-4-cy)*fall*fall;a=lerp(.9,1.25+.2*Math.sin(t*40),sm(0,.15,t))*(1-sm(.75,.95,t))-.25*sm(.75,.95,t);lag=a;dead=1;sq=sm(.75,.95,t);cx+=fall*4}
 const wing=(s,bz)=>{const S=[cx+s*(V.bw-1),cy-1],W=[S[0]+s*V.l1*Math.cos(a),S[1]-V.l1*Math.sin(a)*(1-sq*.7)],a2=a*.9-.45+lag*.35-tilt*.2,T=[W[0]+s*V.l2*Math.cos(a2),W[1]-V.l2*Math.sin(a2)*(1-sq*.7)],
   hip=[cx+s*(V.bw-1.5),cy+V.bh],m1=L2(L2(T,hip,.36),W,.3),m2=L2(L2(T,hip,.7),W,.22);
  poly(b,s>0?[S,W,T,m1,m2,hip]:[S,hip,m2,m1,T,W],M.wing,(x,y)=>{if(V.holes&&hash(x>>1,y>>1)>.86)return-1;const d=Math.abs(x-S[0]);return cl(.66-d*.022-(y-S[1])*.02+bz,.05,.99)});
  ln(b,S[0],S[1],W[0],W[1],M.bone,.75+bz);ln(b,W[0],W[1],T[0],T[1],M.bone,.7+bz);ln(b,W[0],W[1],m1[0],m1[1],M.bone,.5+bz);ln(b,W[0],W[1],m2[0],m2[1],M.bone,.42+bz);dot(b,W[0],W[1]-1,M.bone,.95)};
 wing(-1,.08);wing(1,-.1);
 if(V.tail){const tw=Math.sin(t*(anim==='act'?14:5))*3,tx=cx+tw,ty=cy+V.bh+8;ln(b,cx,cy+V.bh-1,tx,ty,M.fur,.5);spike(b,tx,ty,PI/2+tw*.1,5,'cu',0,1)}
 blob(b,cx,cy+1,V.bw,V.bh,M.fur,0);if(V.plate){blob(b,cx,cy+.4,V.bw-.8,V.bh-2,'cu',.08);over(b,cx,cy+1,'cu',.3)}
 px(b,Math.round(cx)-1,Math.round(cy+V.bh)+1,M.bone,.7);px(b,Math.round(cx)+1,Math.round(cy+V.bh)+1,M.bone,.7);
 const hx=cx+tilt*1.5,hy=cy-V.bh+1+tilt;blob(b,hx,hy,V.hr,V.hr,M.fur,.06);if(V.snout)blob(b,hx,hy+V.hr*.6,1.9,1.7,M.fur,.12);if(V.plate)blob(b,hx,hy-1,V.hr-.6,1.5,'cu',.12);
 for(const s of[-1,1])for(let i=0;i<V.ear;i++)dot(b,hx+s*(V.hr-.7)+s*(i>V.ear*.5?.6:0),hy-V.hr+.6-i,M.fur,.8-i*.05+(s<0?.1:-.1));
 for(const s of[-1,1]){px(b,Math.round(hx+s*1.4),Math.round(hy),dead?'gueule':'oeil',dead?.2:.99);if(!dead)fdot(F,hx+s*1.4,hy,'oeil',.99)}
 if(!dead){px(b,Math.round(hx)-1,Math.round(hy+V.hr)-1,'bone',.95);px(b,Math.round(hx)+1,Math.round(hy+V.hr)-1,'bone',.95)}
 if(anim==='death'&&t>.75&&t<1.15)dust(F,cx,BG,(t-.75)/.4,8,8);
 if(anim==='death'&&t>1.4)dim(b,.12*sm(1.4,2.2,t));
 return b}

// =====================================================================================================
// Gorge-Cuivre, la Dévoreuse de filons. Cadre 104 × 88, sol en y = 80.
// =====================================================================================================
const WW=104,WH=88,WAX=44,WG=80;
// chaîne de segments partant de (x, y) dans la direction th0 ; renvoie le bout {x, y, th}
function chain(b,x,y,L,r0,r1,thf,band,dimk=0){let th=0;const pts=[];for(let s=0;s<=L;s+=.8){const q=s/L;th=thf(s,q);x+=Math.cos(th)*.8;y+=Math.sin(th)*.8;const r=lerp(r0,r1,q);if(y>WG-r*.8){y=WG-r*.8}
  const[mat,bz]=band(Math.round(s/.8),q);blob(b,x,y,r,r,mat,bz-dimk);pts.push([x,y,th,r])}return{x,y,th,pts}}
function maw(b,F,x,y,th,r,open,o={}){const cx=x+Math.cos(th)*2,cy=y+Math.sin(th)*2,ro=r*(.42+.5*open);blob(b,cx,cy,r+1,r+1,o.lip||'vdgD',.05);blob(b,cx+Math.cos(th),cy+Math.sin(th),ro,ro,'gueule',.05+open*.1);
 const n=o.teeth||9;for(let i=0;i<n;i++){const a=i/n*TAU+(o.rot||0),tx=cx+Math.cos(th)+Math.cos(a)*ro,ty=cy+Math.sin(th)+Math.sin(a)*ro;over(b,tx,ty,'bone',.99);if(i%2===0)over(b,tx-Math.cos(a),ty-Math.sin(a),'bone',.85)}
 if(open>.8){over(b,cx+Math.cos(th),cy+Math.sin(th),'gueule',.5)}}
const WORMS=[
 {id:'1',name:'Le Ver annelé',desc:'La forme attendue : un tronc de chair vert-de-gris cerclé d’anneaux de cuivre, une gueule ronde à deux rangs de dents. Les anneaux sont l’armure, la gueule le point faible : la règle de dégâts se lit sans texte.',
  r:9,L:50,band:(i,q)=>i%8<3?['cu',0]:['vdgD',0],head(b,F,T,o,t){maw(b,F,T.x,T.y,T.th,T.r,o,{rot:t*.6})}},
 {id:'2',name:'La Foreuse vivante',desc:'Sa tête est un cône de plaques de cuivre en spirale qui tourne sans arrêt ; pour mordre, le cône s’ouvre en deux mâchoires. Corps de roche. Elle perce plus qu’elle ne dévore : le plus fidèle à la « Foreuse » qu’elle lâche.',
  r:8,L:44,band:(i,q)=>i%7<2?['cu',-.05]:['roche',.05],
  head(b,F,T,o,t,sp){const n=17,dx=Math.cos(T.th),dy=Math.sin(T.th),nx=-dy,ny=dx,gap=o>.55?(o-.55)*9:0;for(let i=0;i<n;i++){const q=i/n,w=(T.r+1)*(1-q);for(let j=-Math.ceil(w);j<=Math.ceil(w);j++){if(Math.abs(j)>w)continue;const g=j<0?-gap*q:gap*q;
     const st=Math.floor((i*1.1+j*.7-t*(sp||10))%4+8)%4;dot(b,T.x+dx*(i+1)+nx*(j+g),T.y+dy*(i+1)+ny*(j+g),'cu',cl((st===0?.25:st===1?.95:.7)-j*.04,.05,.99))}}
   if(gap>1){for(let i=3;i<n-2;i+=3){dot(b,T.x+dx*(i+1)+nx*(gap*i/n-1),T.y+dy*(i+1)+ny*(gap*i/n-1),'bone',.99);dot(b,T.x+dx*(i+1)-nx*(gap*i/n-1),T.y+dy*(i+1)-ny*(gap*i/n-1),'bone',.99)}}}},
 {id:'3',name:'Le Mille-pattes mineur',desc:'Plus mince, plus long, cuirassé de plaques, bordé de dizaines de pattes de cuivre qui courent en vague. Mandibules et antennes au lieu d’une gueule ronde. Le plus rapide d’allure, le moins « ver ».',
  r:6.2,L:58,wave:1.5,band:(i,q)=>i%6<4?['vdg',-.05]:['vdgD',-.1],
  body(b,F,C,t){C.pts.forEach((p,i)=>{if(i%5||i<6)return;const nx=-Math.sin(p[2]),ny=Math.cos(p[2]),wv=Math.sin(i*.5-t*10)*1.6;for(const s of[-1,1]){const x0=p[0]+nx*s*(p[3]-1),y0=p[1]+ny*s*(p[3]-1),x1=p[0]+nx*s*(p[3]+4)+Math.cos(p[2])*wv,y1=p[1]+ny*s*(p[3]+4)+Math.sin(p[2])*wv;if(y1<WG)ln(b,x0,y0,x1,y1,'cu',s<0?.85:.5)}})},
  head(b,F,T,o,t){const dx=Math.cos(T.th),dy=Math.sin(T.th),nx=-dy,ny=dx;blob(b,T.x+dx*2,T.y+dy*2,T.r+1,T.r+.5,'cu',.05);for(const s of[-1,1]){const a=T.th+s*(.95-o*.6),bx=T.x+dx*4+nx*s*3,by=T.y+dy*4+ny*s*3;seg(b,bx,by,bx+Math.cos(a)*5,by+Math.sin(a)*5,1.4,1,'bone',s>0?-.15:0);
    const a2=a-s*1.1;seg(b,bx+Math.cos(a)*5,by+Math.sin(a)*5,bx+Math.cos(a)*5+Math.cos(a2)*4,by+Math.sin(a)*5+Math.sin(a2)*4,1,.7,'bone',s>0?-.15:0);
    const an=T.th+s*(1.9+.2*Math.sin(t*4+s));ln(b,T.x+nx*s*2,T.y+ny*s*2,T.x+nx*s*2+Math.cos(an)*9,T.y+ny*s*2+Math.sin(an)*9,'cu',.7);over(b,T.x+dx*3+nx*s*2.4,T.y+dy*3+ny*s*2.4,'oeil',.99);fdot(F,T.x+dx*3+nx*s*2.4,T.y+dy*3+ny*s*2.4,'oeil',.99)}
   blob(b,T.x+dx*5,T.y+dy*5,1.6+o*1.4,1.6+o*1.4,'gueule',.1)}},
 {id:'4',name:'La Gorge à collerette',desc:'Autour de la gueule, une collerette de cristaux de vert-de-gris qui se referme au repos et s’ouvre en étoile avant chaque attaque : l’annonce du coup est dans la silhouette. La plus spectaculaire.',
  r:8.5,L:46,band:(i,q)=>i%9<2?['cu',0]:['vdgD',q>.8?.08:0],
  head(b,F,T,o,t){const n=9,cx=T.x+Math.cos(T.th)*2,cy=T.y+Math.sin(T.th)*2;for(let i=0;i<n;i++){const a=i/n*TAU+.2,len=7+o*5+(i%2)*2,rr=T.r*(.6+.5*o);spike(b,cx+Math.cos(a)*rr,cy+Math.sin(a)*rr,lerp(T.th,a,.35+.65*o),len,'vdg',Math.sin(a+2.4)*.15,1)}
   maw(b,F,T.x,T.y,T.th,T.r-.5,o,{rot:-t*.5,teeth:8});if(o>.8)for(let i=0;i<n;i+=3){const a=i/n*TAU+.2;fdot(F,cx+Math.cos(a)*(T.r+11),cy+Math.sin(a)*(T.r+11),'vdg',.99)}}},
 {id:'5',name:'L’Hydre de filon',desc:'Un tronc court et massif qui se divise en trois cous, chacun avec sa gueule. Les têtes ondulent à contretemps et frappent l’une après l’autre. Trois gueules à viser : la phase « gueule ouverte » devient un choix.',
  r:10,L:24,hydra:true,band:(i,q)=>i%8<3?['cu',0]:['vdgD',0],head(){}},
];
function worm(V,anim,t){
 const b=buf(WW,WH),F=[];b.fx=F;let bx=WAX,e=1,lean=0,A=.32*(V.wave||1),w=1.5,open=.38+.16*Math.sin(t*2.4),dimk=0,spin=10,mound=0,str=[0,0,0];
 if(anim==='walk'){const T=3.8,u=t%T,side=Math.floor(t/T)%2?1:-1;e=1-sm(0,.7,u)+sm(2.3,3.0,u);bx+=side*lerp(-13,13,sm(.7,2.3,u));mound=e<.2?1:0;spin=26;open=.25;
  if(u<.8)dust(F,bx,WG,u/.8,14,V.r+8);if(u>2.25&&u<3.1)dust(F,bx,WG,(u-2.25)/.85,16,V.r+12);
  if(mound){blob(b,bx,WG-2.5,V.r+2,3.5,'roche',.05);blob(b,bx-4,WG-2,4,2.6,'roche',-.05);blob(b,bx+5,WG-1.6,3.5,2.2,'pouss',-.1);for(let i=0;i<6;i++){const p=(t*2+i/6)%1;fdot(F,bx+(hash(i,5)-.5)*(V.r*2+6),WG-4-Math.sin(p*PI)*5,'pouss',.9-p*.5)}
   for(let i=3;i<22;i+=3)fdot(F,bx-side*i-side*V.r,WG-1,'roche',.8-i*.03)}}
 if(anim==='act'){const u=t%2.7,back=sm(0,.5,u),go=sm(.74,.88,u),rec=sm(1.35,2.3,u);lean=-.42*back*(1-go)+2.35*go*(1-rec);open=lerp(.4,1,back)*(1-go*.75)+go*(1-rec)*.1;A*=1-back*.6;spin=10+back*26;
  if(u>.86&&u<1.4)dust(F,bx+V.L*.62,WG,(u-.86)/.54,16,14);
  if(V.hydra)str=[0,1,2].map(i=>{const v=(u+2.7-i*.32)%2.7;return sm(.74,.88,v)*(1-sm(1.35,2.0,v))})}
 if(anim==='death'){const thr=1-sm(.9,1.4,t),fall=sm(1.25,2.0,t);A=(.32+1.1*thr)*(t<1.4?1:.3)*(V.wave||1);w=t<1.4?10:1;lean=2.7*fall;open=.75*thr+.15;dimk=.22*sm(2.0,2.8,t);spin=10*thr;
  if(t>1.9&&t<2.5)dust(F,bx+V.L*.55,WG,(t-1.9)/.6,18,16)}
 const Lv=V.L*e;
 if(Lv>3){const thf=(s,q)=>-PI/2+lean*Math.pow(q,1.15)*1.25+A*Math.sin(s*.12-t*w)*q;
  const C=chain(b,bx,WG+2,Lv,V.r,V.r*(V.hydra?.9:.78),thf,V.band,0),T={x:C.x,y:C.y,th:C.th,r:V.r*(V.hydra?.9:.78)};
  if(V.body)V.body(b,F,C,t);
  if(V.hydra){[-1,0,1].forEach((s,i)=>{const o2=anim==='act'?lerp(.4,1,sm(0,.5,(t%2.7)))*(1-str[i]*.7):open+.12*Math.sin(t*2.4+i*2),ln2=str[i]*1.4;
    const N=chain(b,T.x+s*4,T.y+1,22,5,4,(ss,q)=>T.th+s*(.75-q*.35)+ln2*q+(lean>1?0:0)+.5*Math.sin(ss*.2-t*(w+.6)+i*2.1)*q,(k,q)=>k%7<2?['cu',s<0?.05:-.08]:['vdgD',s<0?.05:-.08],0);
    maw(b,F,N.x,N.y,N.th,4.2,cl(o2),{teeth:6,rot:t*.8+i})})}
  else V.head(b,F,T,cl(open),t,spin);
  if(dimk)dim(b,dimk)}
 // gravats au pied
 if(!mound&&e>.05){for(const[dx,rx,ry,m,bz]of[[-V.r-2,4,3,'roche',0],[V.r+2,4.5,3,'roche',-.1],[-V.r+3,3,2,'pouss',-.05],[V.r-4,3.2,2.2,'roche',.05],[0,3,1.8,'pouss',-.12]])blob(b,bx+dx,WG-1.6,rx,ry,m,bz);
  for(let i=-3;i<=3;i++){fdot(F,bx+i*(V.r*.6)+(i&1?1:0),WG-1,'roche',.3)}}
 return b}

const ROLES=[
 {key:'eel',name:'Anguille des puits',list:EELS,ground:'eau',noShadow:true},
 {key:'tick',name:'Tique de filon',list:TICKS},
 {key:'bat',name:'Chauve-souris patinée',list:BATS,scaleAnim:'walk'},
 {key:'worm',name:'Gorge-Cuivre',list:WORMS},
];
const SIZES={eel:{w:EW,h:EH,ax:EAX,ay:EG,gap:27,sh:0},tick:{w:TW,h:TH,ax:TAX,ay:TG,gap:15,sh:9},bat:{w:BW,h:BH,ax:BAX,ay:BG,gap:23,sh:6},worm:{w:WW,h:WH,ax:WAX,ay:WG,gap:27,sh:13}};
const DRAW={eel,tick,bat,worm},LIST=Object.fromEntries(ROLES.map(r=>[r.key,r.list]));
function paint(b){const c=document.createElement('canvas');c.width=b.w;c.height=b.h;const g=c.getContext('2d');
 if(b.under){const u=b.under;for(let y=0;y<u.h;y++)for(let x=0;x<u.w;x++){const i=y*u.w+x;if(u.m[i]<0)continue;g.fillStyle=R[MAT[u.m[i]]][1+Math.round(cl(u.s[i])*3)];g.fillRect(x,y,1,1)}}
 g.drawImage(render(b,1),0,0);const fx=document.createElement('canvas');fx.width=b.w;fx.height=b.h;const f=fx.getContext('2d');
 for(const[x,y,mat,l]of b.fx||[]){f.fillStyle=R[mat][Math.min(4,1+Math.round(l*3))];f.fillRect(x,y,1,1)}
 return{c,fx}}
const buffer=(key,vi,anim,t)=>{const len={eel:3.4,tick:3,bat:2.8,worm:3.6}[key];return DRAW[key](LIST[key][vi],anim,anim==='death'?t%len:t)};
return{ROLES,LIST,SIZE:SIZES.tick,sizeOf:k=>SIZES[k],frame:(key,vi,anim,t)=>paint(buffer(key,vi,anim,t)),buffer}})();
