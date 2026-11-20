// ================= BÂTIMENTS v3 : monuments et machines en plein air, finition 16 bits =================
// Assemblé par tools/batiments-16bits/build.py : moteur de creuset-planches.js + outils de batiments-v2-designs.js + ce fichier.
// K = 1 au travail, 0 au repos (réglé par la page via BAT.setWork).
let K=1;
const TAU=Math.PI*2,Eo=a=>a.map(E);
const FVB=Eo(['#34327a','#5a5cff','#9aa0ff','#e8ecff']),FOR=Eo(['#c23a08','#f2800e','#ffc83a','#fff6c0']),FGR=Eo(['#1c6a2e','#34a84a','#6ee07a','#d4ffd0']),FWH=Eo(['#8e8c98','#c8ccd8','#eef0f6','#ffffff']);
const INDC=R_(['#3a1606','#7a3008','#c25a12','#f08a2a','#ffc070']);
const SANDL=R_(['#6e5638','#8a6e48','#a68a5c','#c2a674','#d8c08e']);
const CLOTH=R_(['#7a6a50','#b8a684','#e2d6b4','#fffaea']);
const dyn=(key,f,lights)=>fx(key,()=>({dyn:f,lights:lights||[]}));
const LT=(x,y,z,r,i,c,fl)=>{const[a,b]=at(x,y,z);return{x:a,y:b,r,i,c,fl}};
const ease=p=>p*p*(3-2*p),clamp=(v,a=0,b=1)=>v<a?a:v>b?b:v;
// calque masqué : ce qui passe derrière un volume marqué « mask » n’est pas dessiné
const behind=(F,S)=>({set(x,y,c){const W=S.P.w,H=S.P.h;x=Math.round(x);y=Math.round(y);if(x<0||y<0||x>=W||y>=H||S.mask[y*W+x])return;F.set(x,y,c)},line(x0,y0,x1,y1,c){const n=Math.max(1,Math.ceil(Math.max(Math.abs(x1-x0),Math.abs(y1-y0))));for(let k=0;k<=n;k++)this.set(x0+(x1-x0)*k/n,y0+(y1-y0)*k/n,c)}});
function bigFlame(F,x,y,w,h,C,t,s=0){if(h<=0)return;for(let i=-w;i<=w;i++){const a=1-Math.pow(Math.abs(i)/(w+1),1.6),hh=Math.max(1,Math.round(h*a*(.6+.4*Math.sin(t*11+i*1.9+s*3))+(hash(i,Math.floor(t*12),s)>.7?1:0)));
 for(let j=0;j<hh;j++){const v=j/hh;F.set(x+i,y-j,C[v<.3&&Math.abs(i)<w?3:v<.6?2:v<.85?1:0])}}}
function sChest(F,x,y,R){for(let j=0;j<8;j++)for(let i=-4;i<=4;i++){const band=Math.abs(i)===3;F.set(x+i,y-7+j,band?IRON[j<3?5:3]:R[j===0?4:j<3?3:j===7?1:2])}F.set(x,y-4,SILVER[4])}
function sCrate(F,x,y,s=4){for(let j=0;j<2*s;j++)for(let i=-s;i<s;i++){const e=i===-s||i===s-1||j===2||j===2*s-1;F.set(x+i,y-2*s+1+j,j<2?WOOD[5]:e?WOOD[1]:(i+s===j-2||i+s===2*s+1-j)?WOOD[4]:WOOD[3])}}
const cargo=(F,x,y,k)=>k%3===0?sChest(F,x,y,BLUEC):k%3===1?sChest(F,x,y,REDC):sCrate(F,x,y);
const BOOKC=[BLUEC[2],REDC[2],VERDI[3],WOOD[3],SLATE[4]];
function sBook(F,x,y,c,fl){F.set(x,y,PARCH[1]);F.set(x,y+1,c);for(let i=1;i<=3;i++){const d=fl?Math.round(i*.8):-Math.round(i*.34);F.set(x-i,y-d,PARCH[4]);F.set(x+i,y-d,PARCH[4]);F.set(x-i,y-d+1,c);F.set(x+i,y-d+1,c)}}
function thick(F,x0,y0,x1,y1,a,b){F.line(x0,y0,x1,y1,a);F.line(x0,y0+1,x1,y1+1,b)}
function zz(F,x,y,t,C){for(let k=0;k<3;k++){const p=(((t*.2+k/3)%1)+1)%1,zx=Math.round(x+p*7+Math.sin(p*6)*2),zy=Math.round(y-p*16),s=k%2?4:5;if(p>.9)continue;for(let i=0;i<s;i++){F.set(zx+i,zy,C[3]);F.set(zx+i,zy+s-1,C[3]);F.set(zx+s-1-i,zy+i,C[3])}}}
function fireflies(F,t,n,s,cx,cy,rx,ry){for(let k=0;k<n;k++){const a=t*TAU/5*(1+k%2)+hash(k,s,2)*9;if(Math.sin(t*TAU*.6+k*2.1)>-.2)F.set(Math.round(cx+(hash(k,s,3)-.5)*2*rx+Math.sin(a)*5),Math.round(cy+(hash(k,s,4)-.5)*2*ry+Math.cos(a*1.3)*3),FGR[k%2?3:2])}}
function flag(F,x,y,w,h,R,t,dir=1){for(let i=0;i<w;i++){const a=t*TAU*.8-i*.9,dy=Math.round(Math.sin(a)*1.3*(i/w));for(let j=0;j<h-(i>w-4?i-w+4:0);j++)F.set(x+dir*i,y+dy+j,R[j===0?4:Math.cos(a)>0?3:2])}}
const oct=(R,h=.12,o={})=>slab(poly(8,1.32,Math.PI/8),0,h,stone(R,{noise:.08,...o}),{key:-9});
const disc=(R,r=1.28,h=.12,o={})=>slab(circle(r),0,h,stone(R,{noise:.08,...o}),{key:-9});
const mossy=o=>stone(MSTONE,{moss:.3,noise:.12,...o});
const sand=o=>stone(SAND,{courses:.2,joint:.55,noise:.1,...o});
const lac=o=>stone(INDC,{noise:.06,...o});

const GROUPS=[
 {id:'forge',name:'Forge',note:'Fer, basalte, flamme bleu-violet d’Aether ; seul le métal chauffé est orange. Des forges qui frappent, coulent et soufflent sans forgeron.'},
 {id:'workshop',name:'Atelier',note:'Bois, fer et mécanique d’Aether. Chaque piste est une machine à ciel ouvert, lisible de loin par son mouvement.'},
 {id:'library',name:'Bibliothèque',note:'Marbre veiné, parchemin, lumière blanche de Sigil. Les livres y circulent seuls.'},
 {id:'caserne',name:'Caserne',note:'Grès, laque orange et cuivre d’Indra. Feux, gongs, tambours et roues d’armes.'},
 {id:'bedroom',name:'Chambre à coucher',note:'Pierre moussue, feuillage et lueur verte de Medeina. Tout y bouge à la cadence d’un souffle.'},
 {id:'warehouse',name:'Entrepôt logistique',note:'Marbre de Sigil, coffres bleus et rouges du jeu. L’animation montre les marchandises qui circulent.'}];

const ITEMS=[
// ======================= FORGE =======================
 {g:'forge',name:'Enclume-monolithe',desc:'Une enclume géante taillée dans le basalte, sur un dais gravé. Le marteau lévite et frappe seul ; à chaque coup le cercle de glyphes s’allume.',anims:['marteau en lévitation','étincelles','cercle de glyphes','braseros'],
  build(){const[ax,ay]=at(-.08,1.08,.05);return{ground:floor(),objs:[oct(BASALT,.12,{inlay:ringI(1.04,.04,AEC[1])}),
   slab(rect(-.55,-.34,.55,.34),.12,.42,dMat(),{key:-2}),slab(rect(-.32,-.22,.32,.22),.42,.78,stone(BASALT,{noise:.08,inlay:vlineI(AEC[2],.03,.2,.8)}),{key:-1.9}),
   slab(rect(-.78,-.34,.62,.34),.78,1.08,iMat(),{key:-1.8}),slab(rect(-.2,-.16,.2,.16),.9,1.06,iMat(),{x:.82,key:-1.7,taper:[1,.5]}),
   brazier(-1.0,-.85,BASALT,'vb',VIOBLUE),brazier(1.0,-.85,BASALT,'vb',VIOBLUE),barrel(-.98,.82,WOOD,{water:1,h:.34}),
   dyn(5,(F,t,S)=>{const per=1.3,u=K?(t%per)/per:1,lift=K?(u<.72?Math.sin(u/.72*Math.PI/2):1-Math.min(1,(u-.72)/.1)):0,hy=ay-3-Math.round(lift*30),hit=K&&u>.82;
    for(let i=-7;i<=6;i++){F.set(ax+i,ay-2,MOLT[K?(hit?4:3):1]);F.set(ax+i,ay-1,MOLT[K?2:0])}
    for(const o of[0,1,2])F.line(ax+6,hy-7+o,ax+27,hy-15+o,WOOD[o===0?5:o===1?4:2]);for(let j=0;j<12;j++)for(let i=-9;i<=8;i++)F.set(ax+i,hy-12+j,IRON[j===0?6:i<-6?5:j===11?1:i>5?2:j<3?5:4]);for(let i=-9;i<=8;i++){F.set(ax+i,hy-7,AEC[K?2:0]);F.set(ax+i,hy-6,AEC[K?1:0])}
    if(hit){for(let k=0;k<120;k++){const a=k*TAU/120,[x,y]=at(Math.cos(a)*1.04,.12,Math.sin(a)*1.04);for(const d of[-1,0,1])if(S.P.get(x,y+d)===AEC[1])F.set(x,y+d,AEC[3])}}
    if(K)sparkC(ax,ay-3,['#f2800e','#ffc83a','#fff6c0'],10,3,15,13,per,.34)(F,t+per*.18)},[LT(-.08,1.2,.05,44,.8,HOT,.2)])]}}},
 {g:'forge',name:'Creuset suspendu',desc:'Deux pylônes de fer et une poutre portent un creuset au bout de ses chaînes, au-dessus d’une fosse de feu. Il se balance, bascule et verse dans le moule.',anims:['creuset qui se balance','coulée dans le moule','feu de la fosse','fumée'],
  build(){const[cx,cy]=at(0,2.28,-.3),[mx,my]=at(.78,.16,.85),[px,py]=at(0,.3,-.3);return{ground:floor(),objs:[slab(square(1.28),0,.1,stone(SLATE,{noise:.08}),{key:-9}),
   slab(circle(.56),.1,.3,dMat({inlay:q=>q.f==='top'&&q.rad<.42?rp(MOLT,.3+.4*(1-q.rad/.42),q.sx,q.sy):null}),{z:-.3,key:-3}),
   slab(square(.13),.1,2.3,iMat({inlay:vlineI(AEC[1],.025,.2,.85)}),{x:-1.02,z:-.3,key:-.4,taper:[1.3,.8]}),slab(square(.13),.1,2.3,iMat({inlay:vlineI(AEC[1],.025,.2,.85)}),{x:1.02,z:-.3,key:-.4,taper:[1.3,.8]}),
   box(0,-.3,1.16,.09,2.3,2.46,iMat(),{key:3}),moldTray(.78,.85),anvil(-.8,.85),
   dyn(4,(F,t)=>{bigFlame(F,px,py,7,K?13:4,FVB,t,1);const per=6,u=t%per,pour=K&&u>1.2&&u<3.8,sw=K?Math.sin(t*Math.PI)*(pour?.6:2.4):0,x=Math.round(cx+sw),y=cy+30,tilt=pour?3:0;
    F.line(cx-9,cy+4,x-7,y-9,IRON[2]);F.line(cx+9,cy+4,x+7,y-9+tilt,IRON[2]);
    for(let j=0;j<12;j++){const w=8-Math.round(j*.3);for(let i=-w;i<=w;i++)F.set(x+i,y-9+j+Math.round(tilt*(i/8+.5)*.6),j===0?IRON[6]:i<-w*.4?IRON[5]:i>w*.5?IRON[2]:IRON[4])}
    for(let i=-6;i<=6;i++)F.set(x+i,y-10+Math.round(tilt*(i/8+.5)*.6),MOLT[K?4:1]);for(let i=-8;i<=8;i++)F.set(x+i,y-5,AEC[K?2:0]);
    if(pour)pourDyn(x+8,y-8+tilt,mx,my,per,[1.2,3.8])(F,t);if(K)smokeDyn(cx,cy-4,22,6,3)(F,t*1.190476)},[LT(0,.6,-.3,50,.9,VIOBLUE,.2),LT(.78,.3,.85,26,.6,HOT)])]}}},
 {g:'forge',name:'Gueule de basalte',desc:'Une tête colossale des ruines tyriennes, reconvertie en four. Le feu d’Aether gronde dans la gueule, les yeux s’allument au rythme du tirage.',anims:['feu dans la gueule','yeux qui pulsent','braises','fumée du crâne'],
  build(){const face=frontI(q=>{const ax=Math.abs(q.x);if(q.y>1.05&&q.y<1.3&&ax>.28&&ax<.62)return AEC[1];if(q.y>1.3&&q.y<1.4&&ax>.2&&ax<.7)return rp(BASALT,.15,q.sx,q.sy);
    if(ax<.09&&q.y>.78&&q.y<1.2)return rp(BASALT,.85,q.sx,q.sy);const top=.72-.42+Math.sqrt(Math.max(0,.42*.42-q.x*q.x));if(ax<.42&&q.y<top)return q.y>top-.07||ax>.36?rp(BASALT,.9,q.sx,q.sy):(q.y<.2?rp(MOLT,.5,q.sx,q.sy):rp(DSTONE,.05,q.sx,q.sy));
    if(q.y<.75&&q.y>.6&&ax<.4&&((ax*T/3|0)&1))return rp(BASALT,.95,q.sx,q.sy);return null});
   const[fx_,fy]=at(0,.06,.62),[tx,ty]=at(0,1.9,-.2),[e1,ey]=at(-.45,1.18,.62),[e2]=at(.45,1.18,.62);return{ground:floor(),objs:[oct(BASALT,.1,{moss:.12}),
   slab(rect(-.95,-.6,.95,.6),.1,1.75,stone(BASALT,{courses:.3,joint:.7,noise:.12,moss:.1,inlay:face}),{key:-2,taper:[1,.9]}),
   slab(rect(-.8,-.5,.8,.5),1.75,1.9,stone(BASALT,{noise:.1}),{key:-1.5}),slab(rect(-.18,-.14,.18,.14),1.9,2.1,stone(BASALT),{x:-.5,key:-1.4}),slab(rect(-.18,-.14,.18,.14),1.9,2.1,stone(BASALT),{x:.5,key:-1.4}),slab(circle(.16),1.9,2.0,stone(DSTONE),{z:-.2,key:-1.3}),
   slab(rect(-.34,-.2,.34,.2),.1,.2,iMat(),{z:.95,key:1}),anvil(.92,1.0),crate(-.95,1.0,.15),
   dyn(4,(F,t)=>{const pu=K?.5+.5*Math.sin(t*4.4):0;bigFlame(F,fx_,fy,6,K?9+Math.round(pu*4):3,FVB,t,2);
    for(const ex of[e1,e2])for(let j=-2;j<=2;j++)for(let i=-3;i<=3;i++)F.set(ex+i,ey+j,AEC[K?(pu>.6?3:2):0]);
    if(K){motes(fx_,fy-4,7,26,['#c23a08','#f2800e','#ffc83a'],7,4)(F,t);smokeDyn(tx,ty-2,26,7,5)(F,t)}},[LT(0,.4,.7,52,.95,VIOBLUE,.2)])]}}},
 {g:'forge',name:'Anneau de forge',desc:'Un grand anneau de fer dressé, tendu d’une membrane de feu d’Aether. Les pièces brutes la traversent et ressortent trempées ; les glyphes du cercle tournent.',anims:['membrane de feu','lame qui traverse','glyphes en ronde','vapeur'],
  build(){const[cx,cy]=at(0,1.5,0),R=27;return{ground:floor(),objs:[oct(SLATE,.12),slab(rect(-.8,-.3,.8,.3),.12,.44,dMat({inlay:glyphLine()}),{key:-2}),
   {key:0,statue:true,draw(L){L.ell(cx,cy,R,R,(x,y,dx,dy)=>{const d=Math.hypot(dx,dy);if(d<.74)return null;const a=Math.atan2(dy,dx),seg=((a*8/Math.PI)%1+1)%1;return d>.94||d<.78?rp(IRON,.75-dx*.3-dy*.35,x,y):seg<.12?rp(IRON,.2,x,y):rp(IRON,.5-dx*.25-dy*.3,x,y)});return{}}},
   barrel(-1.0,.85,WOOD,{water:1,h:.36,r:.2}),anvil(.9,.9),
   dyn(4,(F,t)=>{const r=R*.74;for(let y=-r;y<=r;y++)for(let x=-r;x<=r;x++){if(x*x+y*y>r*r-6)continue;const n=vnoise(x*.2+Math.sin(t*.8)*2,y*.2-t*(K?1.6:.2),9)+.25*(1-Math.hypot(x,y)/r);F.set(cx+Math.round(x),cy+Math.round(y),K?FVB[n>.75?3:n>.55?2:n>.38?1:0]:(n>.8?FVB[1]:ci('#14123a')))}
    for(let k=0;k<16;k++){const a=k*Math.PI/8+Math.PI/16,on=K&&(k+Math.floor(t*6))%16<3;F.set(Math.round(cx+Math.cos(a)*R*.86),Math.round(cy+Math.sin(a)*R*.86),on?AEC[3]:AEC[0])}
    if(K){const u=(t%4)/4,y=cy+18-Math.round(u*40),hot=u<.5;if(u<.92)for(let j=0;j<14;j++){F.set(cx,y+j,hot?MOLT[4]:SILVER[4]);F.set(cx+1,y+j,hot?MOLT[2]:SILVER[2]);if(j>10)F.set(cx-1,y+j,WOOD[3]),F.set(cx+2,y+j,WOOD[2])}
     if(u>.5)steamDyn(cx,cy-R,14,2)(F,t)}},[LT(0,1.5,0,58,1,VIOBLUE,.15)])]}}},
 {g:'forge',name:'Colonne de coulée',desc:'Une haute cheminée conique entourée d’une rigole en spirale. Le métal en fusion y descend jusqu’au bassin de trempe, dans un nuage de vapeur.',anims:['coulée en spirale','vapeur du bassin','flammèche au sommet','fumée'],
  build(){const sp=(q)=>{if(q.f!=='side')return null;let a=q.ang+q.v*TAU*2.5;a=((a%TAU)+TAU)%TAU;return a<.5?rp(MOLT,.5,q.sx,q.sy):a<.62||a>TAU-.12?rp(DSTONE,.1,q.sx,q.sy):null};
   const[tx,ty]=at(0,2.7,0),[bx,by]=at(.62,.2,.95);return{ground:floor(),objs:[oct(BASALT,.1),slab(circle(.62),.1,.32,dMat(),{key:-3}),
   slab(circle(.5),.32,2.6,stone(DSTONE,{courses:.22,joint:.5,noise:.1,inlay:sp}),{key:-2,taper:[1,.6]}),slab(circle(.34),2.6,2.72,iMat(),{key:-1}),
   slab(circle(.4),0,.2,q=>q.f==='top'&&q.rad<.31?rp(WATER,.5+(vnoise(q.x*9,q.z*9,3)-.5),q.sx,q.sy):stone(DSTONE,{noise:.08})(q),{x:.62,z:.95,key:1}),
   slab(circle(.24),0,.18,stone(DSTONE,{noise:.3}),{x:-.9,z:.9,taper:[1,.4]}),anvil(-.3,1.05),
   dyn(4,(F,t)=>{bigFlame(F,tx,ty,3,K?8:2,FVB,t,3);if(!K)return;smokeDyn(tx,ty-8,24,6,2)(F,t);
    for(let k=0;k<26;k++){const v=((k/26)-t*.22)%1,vv=(v+1)%1,a=.25-vv*TAU*2.5,r=.5*(1-.4*vv)+.01;if(Math.sin(a)<.15)continue;const[x,y]=at(Math.cos(a)*r,.32+vv*2.28,Math.sin(a)*r);F.set(x,y,MOLT[4]);F.set(x+1,y,MOLT[3])}
    steamDyn(bx,by-2,20,7)(F,t);steamDyn(bx+3,by-4,16,8)(F,t);for(let i=-2;i<=2;i++)F.set(bx-6+i,by-1,MOLT[(i+Math.floor(t*8))%2?4:3])},[LT(0,1.4,.4,46,.8,HOT,.15),LT(0,2.8,0,30,.7,VIOBLUE,.2)])]}}},

// ======================= ATELIER =======================
 {g:'workshop',name:'Grand orrery d’atelier',desc:'Un mât central et trois bras qui tournent à des hauteurs différentes, chacun portant son outil. Les pièces passent d’un bras à l’autre.',anims:['trois bras tournants','engrenage de tête','lanterne d’Aether'],
  build(){const arms=[[1.2,.8,.55,0],[.98,1.3,-.8,2],[.72,1.8,1.2,4]];return{ground:floor(),objs:[oct(WOOD,.1,{}),slab(circle(.3),.1,.3,iMat(),{key:-3}),
   slab(circle(.1),.3,2.0,woodMat(WOOD),{key:-2,mask:true}),slab(circle(.16),2.0,2.1,iMat(),{key:-1}),
   box(-.85,.9,.36,.2,.1,.46,woodMat(WOOD,{along:'x'}),{key:.9}),crate(.9,.9,.16),planks(.2,1.08,3,.34),
   dyn(4,(F,t,S)=>{const B=behind(F,S);for(const[r,h,sp,k]of arms){const a=(K?t*sp:sp)+k,front=Math.sin(a)>0,D=front?F:B,[hx,hy]=at(0,h,0),[ex,ey]=at(Math.cos(a)*r,h,Math.sin(a)*r);
     D.line(hx,hy-1,ex,ey-1,WOOD[5]);D.line(hx,hy,ex,ey,WOOD[4]);D.line(hx,hy+1,ex,ey+1,WOOD[2]);D.line(ex,ey,ex,ey+6,IRON[4]);D.line(ex+1,ey,ex+1,ey+6,IRON[2]);
     if(k===0){for(let j=0;j<6;j++)for(let i=-5;i<=5;i++)D.set(ex+i,ey+6+j,IRON[j===0?6:i<-2?5:i>3?2:4])}else if(k===2){for(let i=-4;i<=4;i++){D.set(ex+i,ey+7,SILVER[4]);D.set(ex+i,ey+8,SILVER[(i+8)%2?2:4])}}else{for(let j=-3;j<=3;j++)for(let i=-3;i<=3;i++)if(i*i+j*j<11)D.set(ex+i,ey+9+j,AEC[i*i+j*j<3?3:i+j<0?2:1])}}
    const[gx,gy]=at(0,2.12,0);wheelDyn(gx,gy,8,6,K?1.2:0,IRON,{teeth:1})(F,t);F.set(gx,gy-1,AEC[3])},[LT(0,2.1,0,34,.7,VIOBLUE)])]}}},
 {g:'workshop',name:'Cabestan',desc:'Un grand treuil horizontal dont les barres tournent seules. Le câble passe par une chèvre et hisse la charge de madriers.',anims:['barres du cabestan','charge hissée','poulie'],
  build(){const[hx,hy]=at(1.0,2.0,-.75);return{ground:floor(),objs:[disc(WOOD,1.28,.08,{inlay:ringI(1.0,.05,WOOD[1])}),
   slab(circle(.3),.08,.92,woodMat(WOOD,{horiz:1,inlay:q=>q.f==='side'&&q.v>.2&&q.v<.55?rp(CANVAS,.5+((q.y*T|0)&1?.2:0),q.sx,q.sy):null}),{x:-.3,z:.2,key:0,mask:true}),slab(circle(.36),.92,1.0,iMat(),{x:-.3,z:.2,key:.1,mask:true}),
   post(1.0,-.75,2.05,WOOD,.07),box(.74,-.75,.36,.05,1.96,2.06,woodMat(WOOD,{along:'x'}),{key:2}),planks(.5,-.95,3,.3),
   dyn(4,(F,t,S)=>{const B=behind(F,S),a0=K?t*.9:.3,[cx,cy]=at(-.3,.66,.2);for(let k=0;k<4;k++){const a=a0+k*Math.PI/2,D=Math.sin(a)>0?F:B,[ex,ey]=at(-.3+Math.cos(a)*.98,.66,.2+Math.sin(a)*.98);D.line(cx,cy,ex,ey,WOOD[5]);D.line(cx,cy+1,ex,ey+1,WOOD[2]);D.set(ex,ey,IRON[5])}
    F.line(cx+6,cy+2,hx-14,hy+2,CANVAS[3]);wheelDyn(hx-14,hy+3,3,4,K?3:0,IRON)(F,t);hoistDyn(hx-14,hy+5,34,K?7:1e9,{sway:1.5,cargo:WOOD})(F,K?t:0)})]}}},
 {g:'workshop',name:'Bras d’assemblage',desc:'Une tourelle de fer et un bras articulé de bois. Il prend une caisse sur la pile, la pose sur l’établi, revient en chercher une autre.',anims:['bras articulé','caisse déplacée','cœur d’Aether'],
  build(){const[sx,sy]=at(-.2,1.15,-.35),[p1x,p1y]=at(-.85,.5,.75),[p2x,p2y]=at(.75,.62,.55),L1=34,L2=32;return{ground:floor(),objs:[oct(SLATE,.1),
   slab(circle(.36),.1,.38,iMat({inlay:cyLineA(.5)}),{x:-.2,z:-.35,key:-2}),slab(circle(.2),.38,.62,iMat(),{x:-.2,z:-.35,key:-1.9}),slab(circle(.1),.62,1.15,iMat({inlay:cyLineA(.5)}),{x:-.2,z:-.35,key:-1.8}),
   crate(-.98,.75,.17),crate(-.66,.82,.17),box(.75,.55,.45,.24,.1,.5,woodMat(WOOD,{along:'x'}),{key:.6}),
   slab(square(.04),.5,.9,woodMat(BARK),{x:.5,z:.5,key:.7,taper:[1,.3]}),slab(square(.04),.5,.9,woodMat(BARK),{x:.95,z:.5,key:.7,taper:[1,.3]}),
   dyn(4,(F,t)=>{const u=K?(t%5)/5:.05,ph=u<.4?ease(u/.4):u<.5?1:u<.9?1-ease((u-.5)/.4):0,dip=Math.sin(clamp(u<.5?u/.4:(u-.5)/.4)*Math.PI),tx=p1x+(p2x-p1x)*ph,ty=p1y+(p2y-p1y)*ph-dip*14;
    const dx=tx-sx,dy=ty-sy,d=Math.min(L1+L2-.5,Math.hypot(dx,dy)),a=Math.atan2(dy,dx),b=Math.acos(clamp((L1*L1+d*d-L2*L2)/(2*L1*d),-1,1)),ex=sx+Math.cos(a-b)*L1,ey=sy+Math.sin(a-b)*L1;
    for(const o of[-2,-1,0,1]){F.line(sx,sy+o,ex,ey+o,WOOD[o<-1?5:o<1?4:2]);F.line(ex,ey+o,tx,ty+o,WOOD[o<-1?5:o<1?4:2])}
    for(const[x,y]of[[sx,sy],[ex,ey]])for(let j=-2;j<=2;j++)for(let i=-2;i<=2;i++)if(Math.abs(i)+Math.abs(j)<4)F.set(Math.round(x)+i,Math.round(y)+j,i||j?IRON[4]:AEC[K?3:1]);
    const X=Math.round(tx),Y=Math.round(ty);F.line(X-4,Y,X+4,Y,IRON[5]);F.line(X-4,Y,X-4,Y+3,IRON[4]);F.line(X+4,Y,X+4,Y+3,IRON[4]);if(K&&u<.45)sCrate(F,X,Y+9,4)},[LT(-.2,.6,-.35,30,.6,VIOBLUE)])]}}},
 {g:'workshop',name:'Tour d’engrenages',desc:'Une horloge sans cadran : un grand panneau de bois couvert de roues dentées qui s’entraînent, un balancier en dessous, un petit toit dessus.',anims:['quatre engrenages','balancier','gemme d’Aether'],
  build(){const G=[[-.42,1.55,11,1],[.28,1.38,7,-1.57],[.5,.85,9,1.22],[-.25,.78,6,-1.83]];return{ground:floor(),objs:[oct(WOOD,.1),
   box(0,-.3,.95,.1,.1,2.15,woodMat(WOOD,{w:.2}),{key:-2}),post(-.95,-.22,2.2,BARK,.08),post(.95,-.22,2.2,BARK,.08),
   roof('gx',0,-.3,1.15,.4,2.15,.36,shingle(SLATE,{cw:.12}),{key:3,noShadow:1}),crate(-.9,.85,.16),barrel(.92,.85,WOOD,{h:.36}),
   dyn(4,(F,t)=>{for(const[x,y,r,s]of G){const[a,b]=at(x,y,-.19);wheelDyn(a,b,r,r>8?8:6,K?s:0,r>8?WOOD:IRON,{teeth:1,thick:1})(F,t)}
    const[px,py]=at(0,.62,-.19),an=K?Math.sin(t*3)*.5:0,bx=px+Math.sin(an)*14,by=py+Math.cos(an)*14;F.line(px,py,bx,by,IRON[4]);for(let j=-2;j<=2;j++)for(let i=-2;i<=2;i++)if(i*i+j*j<6)F.set(Math.round(bx)+i,Math.round(by)+j,IRON[i+j<0?6:3]);
    const[gx,gy]=at(.02,1.12,-.19);for(let j=-1;j<=1;j++)for(let i=-1;i<=1;i++)F.set(gx+i,gy+j,AEC[K?(i||j?2:3):1])},[LT(0,1.1,-.1,36,.6,VIOBLUE)])]}}},
 {g:'workshop',name:'Table d’énonciation',desc:'Une table de pierre gravée, héritée des ruines. Les madriers et les pieux se soulèvent, s’assemblent en l’air en barricade, puis l’ouvrage se dépose.',anims:['pièces qui s’assemblent','éclat d’Aether','glyphes de la table'],
  build(){const P=[[-9,0,1.57],[-3,0,1.57],[3,0,1.57],[9,0,1.57],[0,2,0]],[cx,cy]=at(0,1.45,0);return{ground:floor(),objs:[oct(SLATE,.1,{inlay:ringI(1.05,.035,AEC[0])}),
   slab(rect(-.9,-.5,.9,.5),.1,.5,stone(BASALT,{noise:.1,inlay:bandI(.35,.7,AEC[1],.16,5)}),{key:-2}),slab(rect(-.98,-.56,.98,.56),.5,.6,stone(BASALT,{noise:.06,inlay:ringI(.36,.03,AEC[1])}),{key:-1.9}),
   planks(-.85,1.05,3,.3),crate(.92,1.0,.15),
   dyn(4,(F,t)=>{const u=K?(t%6)/6:0,p=K?ease(clamp((u-.12)/.4)):0,fall=u>.8?ease((u-.8)/.2):0,fl=K&&u>.52&&u<.62;
    P.forEach(([tx,ty,ta],k)=>{const a0=hash(k,1,3)*6+t*(K?TAU/6:0),x0=(hash(k,2,3)-.5)*46,y0=K?(hash(k,3,3)-.5)*16-4+Math.sin(t*Math.PI+k)*2:20,x=x0+(tx-x0)*p,y=y0+(ty-y0)*p+fall*22,a=a0+(ta-a0)*p,L=k===4?13:8,dx=Math.cos(a)*L,dy=Math.sin(a)*L;
     thick(F,cx+x-dx,cy+y-dy,cx+x+dx,cy+y+dy,WOOD[fl?5:4],WOOD[2]);if(k<4&&p>.9)F.set(Math.round(cx+x),Math.round(cy+y-L-1),WOOD[5])});
    if(fl)for(let k=0;k<40;k++){const a=k*TAU/40,r=10+(u-.52)*160;F.set(Math.round(cx+Math.cos(a)*r),Math.round(cy+Math.sin(a)*r*.7),AEC[k%2?3:2])}
    if(K)motes(cx,cy+18,14,22,['#5a5cff','#9aa0ff','#e0e4ff'],6,2)(F,t)},[LT(0,.9,0,44,.7,VIOBLUE,.1)])]}}},

// ======================= BIBLIOTHÈQUE =======================
 {g:'library',name:'Obélisque aux livres',desc:'Un obélisque de marbre gravé sur deux marches rondes. Les livres tournent autour de lui en hélice, pages battantes, et viennent s’y ranger au repos.',anims:['livres en orbite','pages qui battent','pyramidion lumineux'],
  build(){return{ground:floor(),objs:[disc(MARBLE,1.28,.12),slab(circle(.95),.12,.24,mMat(),{key:-8}),
   slab(square(.24),.24,2.5,mMat({inlay:vlineI(WHC[2],.035,.12,.92)}),{key:-2,taper:[1,.55],mask:true}),slab(square(.135),2.5,2.78,stone(QZ,{noise:.04}),{key:-1,taper:[1,0],mask:true}),
   column(-.98,.82,.5,MARBLE,{flame:'white',light:WHITEC}),column(.98,.82,.5,MARBLE,{flame:'white',light:WHITEC}),
   dyn(4,(F,t,S)=>{const B=behind(F,S);for(let k=0;k<7;k++){const a=(K?t*.7:0)+k*TAU/7,y=K?1.0+.55*Math.sin(a*.5+k)+k*.08:.3,r=K?.82:.72,[x,yy]=at(Math.cos(a)*r,y,Math.sin(a)*r);sBook(Math.sin(a)>0?F:B,x,yy,BOOKC[k%5],K&&Math.floor(t*7+k)%2)}
    const[px,py]=at(0,2.6,0);if(K)motes(px,py,5,18,['#a8b0c4','#dfe4f0','#ffffff'],5,3)(F,t)},[LT(0,2.6,0,48,.9,WHITEC)])]}}},
 {g:'library',name:'Arche des feuillets',desc:'Une arche isolée, comme une porte sans mur. Entre ses piliers les feuillets remontent en rideau, du pupitre vers le fronton.',anims:['rideau de feuillets','lueur du passage','veilleuses'],
  build(){const[cx,cy]=at(0,.15,.05);return{ground:floor(),objs:[slab(rect(-1.28,-.9,1.28,1.1),0,.12,stone(MARBLE,{noise:.06}),{key:-9}),slab(rect(-1.05,-.2,1.05,.75),.12,.2,stone(MARBLE,{noise:.05}),{key:-8}),
   box(-.82,0,.22,.3,.12,1.9,mMat({inlay:bandI(.2,.8,WHC[1],.2,4)}),{key:-1}),box(.82,0,.22,.3,.12,1.9,mMat({inlay:bandI(.2,.8,WHC[1],.2,6)}),{key:-1}),
   box(0,0,1.12,.34,1.9,2.14,mMat(),{key:5}),roof('gz',0,0,1.2,.4,2.14,.4,shingle(SLATE,{axis:'z',cw:.12,side:q=>rp(MARBLE,.75+(q.lip?.15:0),q.sx,q.sy)}),{key:6,noShadow:1}),
   lectern(0,.95),column(-1.05,.95,.4,MARBLE,{flame:'white',light:WHITEC}),column(1.05,.95,.4,MARBLE,{flame:'white',light:WHITEC}),
   dyn(4,(F,t)=>{const n=K?16:5;for(let k=0;k<n;k++){const p=K?((t*.3*(.7+.6*hash(k,3,2))+hash(k,1,2))%1):hash(k,1,2)*.06,x=Math.round(cx+(hash(k,2,2)-.5)*26+Math.sin(t*1.7+k*2)*2),y=Math.round(cy-p*42),fl=Math.floor(t*6+k)%3,C_=p>.85?PARCH[2]:PARCH[4];
     if(fl===0){F.set(x-1,y,C_);F.set(x,y,C_);F.set(x+1,y,C_)}else if(fl===1){F.set(x-1,y-1,C_);F.set(x,y,C_);F.set(x+1,y-1,C_)}else{F.set(x,y,C_);F.set(x,y-1,C_)}}
    if(K)for(let j=0;j<40;j++)if(hash(j,Math.floor(t*5),8)>.6)F.set(cx+((j*7)%25)-12,cy-j,WHC[1])},[LT(0,1.0,.1,50,.8,WHITEC)])]}}},
 {g:'library',name:'Cercle des stèles',desc:'Cinq stèles gravées en demi-cercle. Leurs inscriptions s’éclairent l’une après l’autre et un trait de lumière les relie au grand livre qui flotte au centre.',anims:['stèles en séquence','trait de lumière','livre flottant'],
  build(){const A=[200,235,270,305,340].map(d=>d*Math.PI/180),st=A.map((a,k)=>[Math.cos(a)*1.02,Math.sin(a)*1.02+.25,1.3+(k===2?.35:k%2?.15:0)]);return{ground:floor(),objs:[disc(MARBLE,1.3,.1,{inlay:anyI(ringI(.6,.03,WHC[0]),ringI(1.12,.03,WHC[0]))}),
   ...st.map(([x,z,h],k)=>slab(rect(-.17,-.07,.17,.07),.1,h,mMat({inlay:frontI(q=>q.y>.4&&q.y<h-.2&&Math.abs(q.x)<.1&&((q.y*T/3|0)&1)&&hash(q.x*T|0,q.y*T/3|0,k)>.3?rp(MARBLE,.2,q.sx,q.sy):null)}),{x,z,key:z,taper:[1,.85]})),
   slab(circle(.2),.1,.36,mMat(),{z:.35,key:.3}),
   dyn(4,(F,t)=>{const act=K?Math.floor(t*.8)%5:-1,bob=K?Math.round(Math.sin(t*1.6)*1.5):0,[bx,by0]=at(0,K?1.05:.4,.35),by=by0+bob;
    st.forEach(([x,z,h],k)=>{if(k!==act)return;for(let r=0;r<Math.floor((h-.6)*T/3);r++)if(r&1)for(let i=-2;i<=2;i++)if(hash(i,r,k)>.3){const[a,b]=at(x+i/T,.4+r*3/T,z+.07);F.set(a,b,WHC[3])}
     const[sx,sy]=at(x,h*.7,z+.07);for(let s=0;s<=10;s++)if((s+Math.floor(t*10))%2)F.set(Math.round(sx+(bx-sx)*s/10),Math.round(sy+(by-sy)*s/10),WHC[2])});
    for(let i=-6;i<=6;i++)for(let j=-2;j<=1;j++)if(i)F.set(bx+i,by+j-Math.round(Math.abs(i)*.25),PARCH[4-(j+2>2?1:0)]);F.set(bx,by-1,PARCH[1]);F.set(bx,by,PARCH[1]);for(let i=-6;i<=6;i++)F.set(bx+i,by+2-Math.round(Math.abs(i)*.25),BLUEC[2]);
    if(K&&(t*.8)%1<.3){const w=Math.round(Math.cos((t*.8)%1/.3*Math.PI)*5);for(let j=0;j<4;j++)F.set(bx+w,by-2-j,PARCH[4])}},[LT(0,1.0,.35,46,.8,WHITEC)])]}}},
 {g:'library',name:'Arbre à rouleaux',desc:'Un arbre pétrifié, veiné de quartz comme ceux du bosquet. On y a pendu les rouleaux : ils se balancent, se déroulent pour la lecture puis se referment.',anims:['rouleaux suspendus','rouleau qui se déroule','feuilles de quartz'],
  build(){const br=[[-1.0,2.0,-.1],[-.55,2.45,-.3],[.1,2.6,.1],[.65,2.35,-.2],[1.05,1.9,.1],[-.4,1.75,.4],[.5,1.7,.45]],[tx,ty]=at(0,1.3,0);return{ground:floor(),objs:[disc(MARBLE,1.28,.1),
   slab(ringShape(.86,1.08),.1,.3,mMat(),{key:-5}),slab(poly(7,.26,.2),.1,1.3,stone(QZ,{veins:1,noise:.14}),{key:-2,taper:[1.35,.7],mask:true}),
   {key:1,draw(L){for(const[x,y,z]of br){const[a,b]=at(x,y,z),mx=(tx+a)/2,my=Math.min(ty,b)-4;for(const o of[0,1]){L.line(tx+o,ty,mx+o,my,QZ[o?1:3]);L.line(mx+o,my,a+o,b,QZ[o?1:3])}for(let k=0;k<5;k++)L.set(a+((k*5)%7)-3,b-1-(k%3),k%2?WHC[2]:QZ[4])}return{}}},
   lectern(.85,.75),
   dyn(4,(F,t)=>{br.forEach(([x,y,z],k)=>{const[a,b]=at(x,y,z),sw=K?Math.round(Math.sin(t*1.6+k*1.3)*1.6):0,len=5+k%3*2,open=K&&Math.floor(t*.35+k*.37)%7===k?Math.round(Math.sin(((t*.35+k*.37)%1)*Math.PI)*9):0,X=a+sw,Y=b+len;
     F.line(a,b,X,Y,CANVAS[1]);for(let i=-3;i<=3;i++){F.set(X+i,Y,WOOD[4]);F.set(X+i,Y+1,PARCH[4]);F.set(X+i,Y+2,PARCH[3])}for(let j=0;j<open;j++)for(let i=-2;i<=2;i++)F.set(X+i,Y+3+j,j%2&&Math.abs(i)<2?PARCH[2]:PARCH[4]);if(open)for(let i=-3;i<=3;i++)F.set(X+i,Y+3+open,WOOD[3])});
    if(K)for(let k=0;k<4;k++){const p=(t*.14+hash(k,1,6))%1;F.set(Math.round(tx+(hash(k,2,6)-.5)*50+Math.sin(p*9+k)*4),Math.round(ty-28+p*52),k%2?WHC[2]:QZ[4])}},[LT(0,2.0,0,50,.6,WHITEC)])]}}},
 {g:'library',name:'Puits de lecture',desc:'Une margelle ronde garnie de livres, un sol sombre gravé en spirale. Une colonne de lumière en monte ; les livres s’y élèvent et redescendent.',anims:['colonne de lumière','livres qui montent','quatre veilleuses'],
  build(){const[cx,cy]=at(0,.1,0);return{ground:floor(),objs:[disc(MARBLE,1.3,.08),
   slab(circle(.84),.08,.1,q=>q.f==='top'?(spiralI(.1,.8,2.2,.2,WHC[0])(q)??rp(DSTONE,.2+(q.rad>.7?.2:0),q.sx,q.sy)):rp(DSTONE,.3,q.sx,q.sy),{key:-8}),
   slab(ringShape(.84,1.06),.08,.56,mMat({inlay:q=>q.f==='side'&&q.rad>.95&&q.n[1]>.25&&q.v>.15&&q.v<.85?(q.v>.46&&q.v<.54?rp(WOOD,.5,q.sx,q.sy):SPINE[Math.floor(hash(q.sx,q.v>.5?1:0,4)*SPINE.length)]):null}),{key:-3}),
   ...[[-.95,-.95],[.95,-.95],[-.95,.95],[.95,.95]].map(([x,z])=>column(x,z,.75,MARBLE,{flame:'white',light:WHITEC})),
   dyn(4,(F,t)=>{for(let j=0;j<78;j++)for(let i=-7;i<=7;i++)if(hash(i,j-Math.floor(t*(K?14:2)),3)>(K?.82:.95)&&Math.abs(i)<7-j*.03)F.set(cx+i,cy-j,WHC[Math.abs(i)<3?2:1]);
    if(K)for(let k=0;k<5;k++){const up=k%2===0,p=(t*.2+k/5)%1,y=cy-6-(up?p:1-p)*64,x=cx+(k-2)*3+Math.round(Math.sin(t*TAU*.4+k)*1.5);sBook(F,x,Math.round(y),BOOKC[k],Math.floor(t*6+k)%2)}},[LT(0,1.2,0,56,.95,WHITEC)])]}}},

// ======================= CASERNE =======================
 {g:'caserne',name:'Roue d’armes',desc:'L’esprit d’Indra est une roue : la caserne aussi. Un râtelier horizontal tourne lentement autour de son mât et présente lames, lances et écus.',anims:['râtelier tournant','armes qui pendent','feu du moyeu'],
  build(){return{ground:floor(),objs:[oct(SAND,.12,{inlay:ringI(1.05,.04,INDC[2])}),slab(circle(.34),.12,.3,sand(),{key:-3}),
   slab(circle(.1),.3,1.25,lac(),{key:-2,mask:true}),fireBowl(0,0,1.3),
   brazier(-1.02,.9,SAND,'orange',ORANGE),brazier(1.02,.9,SAND,'orange',ORANGE),
   dyn(4,(F,t,S)=>{const B=behind(F,S),a0=K?t*.45:.2,[hx,hy]=at(0,1.2,0);for(let k=0;k<8;k++){const a=a0+k*Math.PI/4,D=Math.sin(a)>-.1?F:B,[ex,ey]=at(Math.cos(a)*1.0,1.2,Math.sin(a)*1.0);D.line(hx,hy,ex,ey,INDC[3]);D.line(hx,hy+1,ex,ey+1,INDC[1])}
    for(let k=0;k<96;k++){const a=k*TAU/96,[x,y]=at(Math.cos(a)*1.0,1.2,Math.sin(a)*1.0),D=Math.sin(a)>-.1?F:B;D.set(x,y,INDC[Math.sin(a)<0?4:3]);D.set(x,y+1,INDC[2]);D.set(x,y+2,INDC[1])}
    const order=[...Array(8).keys()].sort((p,q)=>Math.sin(a0+p*Math.PI/4)-Math.sin(a0+q*Math.PI/4));for(const k of order){const a=a0+k*Math.PI/4,D=Math.sin(a)>-.1?F:B,[x,y]=at(Math.cos(a)*1.0,1.2,Math.sin(a)*1.0),sw=K?Math.round(Math.sin(t*2+k)*.7):0;
     if(k%3===0){for(let j=3;j<14;j++){D.set(x+sw*(j>8?1:0),y+j,SILVER[4]);D.set(x+1+sw*(j>8?1:0),y+j,SILVER[2])}for(let i=-2;i<=3;i++)D.set(x+i,y+5,WOOD[3])}
     else if(k%3===1){for(let j=3;j<17;j++)D.set(x+sw*(j>9?1:0),y+j,WOOD[4]);D.set(x+sw,y+17,SILVER[4]);D.set(x+sw,y+18,SILVER[3])}
     else for(let j=-4;j<=4;j++)for(let i=-3;i<=3;i++)if(i*i+j*j*.6<11)D.set(x+i+sw,y+8+j,i*i+j*j<2?IRON[5]:INDC[i+j<-1?4:i+j>2?2:3])}})]}}},
 {g:'caserne',name:'Arène de sable',desc:'Un muret de grès en anneau, du sable ratissé, des fanions d’Indra. La quintaine tourne sous les coups et la poussière se lève.',anims:['quintaine','poussière','fanions','braseros'],
  build(){const[qx,qy]=at(.42,.95,.1);return{ground:floor(),objs:[slab(circle(1.06),0,.05,stone(SANDL,{noise:.2,pave:q=>Math.abs(q.rad%.24-.12)<.02?.1:0}),{key:-9}),
   slab(ringShape(1.06,1.3),0,.3,sand({trim:{R:INDC,v0:.72,v1:1}}),{key:-8}),{key:.05,draw(L,S){const[a,b]=at(-.48,0,.05);S.shadowEll(a+4,b+1,8,3,.7);L.rect(a,b-24,2,25,BARK[3]);L.rect(a-8,b-19,18,2,BARK[4]);L.ell(a+1,b-14,5,7,(x,y,dx,dy)=>rp(SAND,.7-dx*.25-dy*.2+((x+y)%3?0:-.15),x,y));L.ell(a+1,b-25,3.4,3.4,(x,y,dx,dy)=>rp(SAND,.75-dx*.3-dy*.3,x,y));L.rect(a-3,b-17,8,2,INDC[2]);return{}}},post(.42,.1,.95,BARK,.05),rack(0,-.8,4),
   brazier(-.98,.98,SAND,'orange',ORANGE),brazier(.98,.98,SAND,'orange',ORANGE),post(-1.1,-.7,1.7,BARK,.04),post(1.1,-.7,1.7,BARK,.04),
   dyn(4,(F,t)=>{const c=(t*.4)%1,sp=K?(c<.7?Math.pow(1-c/.7,2)*14:0):0,a=sp+.5,hx=Math.cos(a)*11,hz=Math.sin(a)*3;thick(F,qx-hx,qy-hz,qx+hx,qy+hz,WOOD[5],WOOD[2]);
    for(let j=-3;j<=3;j++)for(let i=-3;i<=3;i++)if(i*i+j*j<11)F.set(Math.round(qx+hx)+i,Math.round(qy+hz)+j+1,INDC[i+j<-1?4:i+j>2?2:3]);for(let j=0;j<6;j++)for(let i=-2;i<=2;i++)F.set(Math.round(qx-hx)+i,Math.round(qy-hz)+2+j,CANVAS[i<0?3:1]);
    if(K&&c<.3)dustDyn(qx,qy+22,8,3)(F,c*3);for(const s of[-1,1]){const[fx_,fy]=at(s*1.1,1.7,-.7);flag(F,fx_+1,fy+1,11,6,INDC,t*s,1)}})]}}},
 {g:'caserne',name:'Portique du gong',desc:'Un portique laqué d’orange, à double linteau. Le bélier frappe le grand gong de cuivre qui appelle les recrues ; l’onde court sur le dallage.',anims:['bélier','gong qui vibre','onde sonore','lanternes'],
  build(){const[gx,gy]=at(0,1.05,-.2);return{ground:floor(),objs:[slab(rect(-1.3,-.9,1.3,1.1),0,.12,sand(),{key:-9}),
   slab(circle(.12),.12,2.1,lac(),{x:-.9,z:-.2,key:-.3,taper:[1.1,.9]}),slab(circle(.12),.12,2.1,lac(),{x:.9,z:-.2,key:-.3,taper:[1.1,.9]}),
   box(0,-.2,1.3,.12,2.1,2.26,lac(),{key:3}),box(0,-.2,1.08,.07,1.78,1.88,lac(),{key:2.5}),box(0,-.2,1.36,.16,2.26,2.34,stone(SLATE),{key:3.5}),
   column(-1.0,.9,.5,SAND,{flame:'orange',light:ORANGE}),column(1.0,.9,.5,SAND,{flame:'orange',light:ORANGE}),
   dyn(1,(F,t)=>{const per=2.4,u=K?(t%per)/per:.5,hit=K&&u<.12,sh=hit?Math.round(Math.sin(u*90)*1.5):0,X=gx+sh;F.line(gx-6,gy-20,X-6,gy-10,IRON[3]);F.line(gx+6,gy-20,X+6,gy-10,IRON[3]);
    for(let j=-11;j<=11;j++)for(let i=-11;i<=11;i++){const d=Math.hypot(i,j);if(d>11.3)continue;F.set(X+i,gy+j,d>9.5?COPPER[i+j<0?5:2]:d<3?COPPER[i+j<0?5:3]:COPPER[Math.abs(d-6.5)<.7?2:i+j<-4?4:3])}
    const sw=K?(u>.6?-(u-.6)/.4*10:u<.12?-10+u/.12*10:0):-4,rx=gx+15-Math.round(sw);F.line(gx+17,gy-22,rx+7,gy,CANVAS[1]);for(let j=-2;j<=1;j++)for(let i=0;i<14;i++)F.set(rx+i,gy+j,i<2?IRON[4]:WOOD[j<0?5:3]);
    if(K&&u<.6){const[ox,oy]=at(0,.12,.3),r=8+u/.6*26;for(let k=0;k<48;k++)if(k%2){const a=k*TAU/48;F.set(Math.round(ox+Math.cos(a)*r),Math.round(oy+Math.sin(a)*r),INDC[u<.3?4:3])}}})]}}},
 {g:'caserne',name:'Foyer des guerriers',desc:'Pas de murs : un grand feu dans son cercle de grès, les écus et les faisceaux de lances autour, des bancs de pierre. Le feu monte quand on forme une recrue.',anims:['grand feu','braises','fumée','écus dressés'],
  build(){const[fx_,fy]=at(0,.34,.05);return{ground:floor(),objs:[disc(SAND,1.3,.08,{inlay:ringI(.95,.04,INDC[1])}),slab(ringShape(.36,.6),.08,.34,sand(),{key:-3}),
   slab(circle(.36),.08,.2,q=>q.f==='top'?rp(MOLT,.2+.5*(1-q.rad/.36)+(hash(q.sx,q.sy,4)-.5)*.3,q.sx,q.sy):rp(DSTONE,.3,q.sx,q.sy),{key:-2.9}),
   shieldStand(-.95,-.5),shieldStand(.95,-.5),shieldStand(-.5,-1.0),shieldStand(.5,-1.0),rack(-.95,.75,2),
   slab(rect(-.3,-.1,.3,.1),.08,.26,sand(),{x:.8,z:.9,key:.9}),slab(rect(-.3,-.1,.3,.1),.08,.26,sand(),{x:0,z:1.12,key:1.1}),
   dyn(4,(F,t)=>{bigFlame(F,fx_,fy,7,K?24:7,FOR,t,1);bigFlame(F,fx_-3,fy,3,K?12:3,FOR,t,5);if(K){motes(fx_,fy-18,10,30,['#c23a08','#f2800e','#ffc83a'],9,6)(F,t);smokeDyn(fx_,fy-26,26,6,4)(F,t)}},[LT(0,.9,.05,70,1.1,ORANGE,.22)])]}}},
 {g:'caserne',name:'Tour-tambour',desc:'Une tour trapue de grès coiffée d’un tambour de guerre géant. Deux mailloches le battent en alternance ; on l’entend de toute la caverne.',anims:['mailloches','peau qui vibre','fanions'],
  build(){const[dx,dy]=at(0,1.72,0);return{ground:floor(),objs:[oct(SAND,.1),
   slab(circle(.86),.1,1.15,sand({trim:{R:INDC,v0:.86,v1:1},inlay:archI(0,.2,.1,.72,doorFill())}),{key:-3,taper:[1,.88]}),slab(ringShape(.6,.8),1.15,1.3,sand(),{key:-2}),
   slab(circle(.52),1.15,1.72,stone(INDC,{noise:.05,inlay:lacingI(BONE[3])}),{key:-1,taper:[.9,1]}),slab(circle(.52),1.72,1.74,q=>rp(BONE,q.f==='top'?(q.rim?.4:.8):.5,q.sx,q.sy),{key:-.9}),
   post(-.98,-.5,2.1,BARK,.04),post(.98,-.5,2.1,BARK,.04),brazier(-.98,.95,SAND,'orange',ORANGE),brazier(.98,.95,SAND,'orange',ORANGE),
   dyn(4,(F,t)=>{const per=.8,b=K?Math.floor(t/per)%2:0,u=K?(t%per)/per:1;for(const s of[-1,1]){const act=K&&(s<0?b===0:b===1),lift=act?(u<.25?1-u/.25:Math.min(1,(u-.25)/.75)):(K?1:.3),px=dx+s*22,py=dy-12,ex=dx+s*5,ey=dy-2-lift*15;thick(F,px,py,ex,ey,WOOD[5],WOOD[2]);for(let j=-2;j<=2;j++)for(let i=-2;i<=2;i++)if(i*i+j*j<6)F.set(Math.round(ex)+i,Math.round(ey)+j,CANVAS[i+j<0?4:2])}
    if(K&&u<.2)for(let k=0;k<40;k++){const a=k*TAU/40,r=5+u*40;F.set(Math.round(dx+Math.cos(a)*r),Math.round(dy+Math.sin(a)*r*.98),BONE[4])}
    for(const s of[-1,1]){const[fx_,fy]=at(s*.98,2.1,-.5);flag(F,fx_+1,fy+1,10,6,INDC,t,1)}})]}}},

// ======================= CHAMBRE =======================
 {g:'bedroom',name:'Fleur-dortoir',desc:'Un bouton de fleur géant posé sur un socle moussu. Quand on y dort, les pétales se referment et l’ensemble respire ; il se rouvre au réveil.',anims:['pétales qui respirent','lueur du cœur','lucioles'],
  build(){const[cx,cy]=at(0,.3,0);return{ground:floor(),objs:[oct(MSTONE,.1,{moss:.4}),slab(poly(6,.7),.1,.3,mossy(),{key:-3}),bush(-1.0,.8,3),bush(1.02,.7,8),bush(.9,-.9,5),
   dyn(4,(F,t)=>{const o=K?.22+.1*(.5+.5*Math.sin(t*1.25)):1,N=7,pet=(k,front)=>{const a=k*TAU/N+.2,sx=Math.cos(a),sz=Math.sin(a);if((sz>0)!==front)return;const reach=8+o*22,rise=34*(1-o)+8,tipx=cx+sx*reach,tipy=cy+sz*reach*.55-rise,bx=cx+sx*5,by=cy+sz*3;
      for(let s=0;s<=1;s+=.04){const w=Math.sin(s*Math.PI)*9+1,px=bx+(tipx-bx)*s,py=by+(tipy-by)*s-Math.sin(s*Math.PI)*4*(1-o);for(let i=-w;i<=w;i++){const X=px-sz*i*.9,Y=py+sx*i*.55+(front?0:-1);F.set(X,Y,LEAF[Math.abs(i)>w-1.2?2:i*sx<0===(sx>0)?(front?6:4):(front?5:3)])}}
      F.set(tipx,tipy,LEAF[7])};
    for(let k=0;k<N;k++)pet(k,false);for(let j=-6;j<=3;j++)for(let i=-6;i<=6;i++)if(i*i+j*j*1.6<36)F.set(cx+i,cy-4+j,FGR[i*i+j*j<8?3:i*i+j*j<20?2:1]);for(let k=0;k<N;k++)pet(k,true);
    fireflies(F,t,K?6:3,2,cx,cy-10,34,22);if(K)zz(F,cx+8,cy-28,t,FGR)},[LT(0,.6,0,46,.8,GREEN)])]}}},
 {g:'bedroom',name:'Cercle des hamacs',desc:'Quatre pieux sculptés, trois hamacs tendus entre eux, une flamme verte de Medeina au milieu. Les hamacs se balancent quand ils sont occupés.',anims:['hamacs qui se balancent','« z » du sommeil','flamme verte'],
  build(){const P=[[-1.0,-.75],[1.0,-.75],[-1.0,.85],[1.0,.85]],H_=[[0,1],[0,2],[1,3]];return{ground:floor(),objs:[disc(MSTONE,1.3,.08,{moss:.35}),
   ...P.map(([x,z])=>slab(poly(6,.09),.08,1.25,woodMat(BARK,{inlay:vlineI(FGR[1],.02,.5,.8)}),{x,z,key:z,taper:[1.2,.8]})),
   slab(circle(.22),.08,.22,mossy(),{z:.1,key:.1}),slab(circle(.13),.22,.36,mossy(),{z:.1,key:.11}),bush(0,-1.05,4,1),
   dyn(4,(F,t)=>{const[fx_,fy]=at(0,.36,.1);bigFlame(F,fx_,fy,2,6,FGR,t,2);H_.forEach(([a,b],k)=>{const[x0,y0]=at(P[a][0],1.1,P[a][1]),[x1,y1]=at(P[b][0],1.1,P[b][1]),sw=K?Math.sin(t*1.5+k*1.7)*2.5:0,n=Math.ceil(Math.hypot(x1-x0,y1-y0));
     for(let i=0;i<=n;i++){const u=i/n,sag=4*u*(1-u),x=x0+(x1-x0)*u+sw*sag*(k?1:0),y=y0+(y1-y0)*u+sag*(k?7:9)+(k?0:sw*sag*.5);for(let j=0;j<3;j++)F.set(x+(k?j:0),y+(k?0:j),k===1?CLOTH[j===0?3:i%4===0?0:2]:LEAF[j===0?7:i%4===0?3:5])}
     if(K){const mx=(x0+x1)/2+(k?sw:0),my=(y0+y1)/2+(k?7:9);for(let j=-1;j<=1;j++)for(let i=-2;i<=2;i++)F.set(mx+(k?j:i)+1,my+(k?i:j),SANDL[2+(j<0?1:0)]);zz(F,Math.round(mx)+4,Math.round(my)-4,t+k*1.3,FGR)}})},[LT(0,.5,.1,40,.75,GREEN,.15)])]}}},
 {g:'bedroom',name:'Tertre aux alcôves',desc:'Un tertre de pierre et de mousse percé de trois niches encadrées de racines. Chacune s’éclaire doucement, à son tour, comme trois dormeurs qui respirent.',anims:['alcôves qui respirent','lucioles','champignons-veilleuses'],
  build(){const AL=[Math.PI/2,Math.PI/2-.95,Math.PI/2+.95];const alc=q=>{if(q.f!=='side')return null;for(const a0 of AL){let d=q.ang-a0;const dx=d*1.1,top=.62-.2+Math.sqrt(Math.max(0,.04-dx*dx));if(Math.abs(dx)<.2&&q.y<top&&q.y>.12)return Math.abs(dx)>.15||q.y>top-.06?rp(BARK,.6,q.sx,q.sy):FGR[0]}return null};
   return{ground:floor(),objs:[disc(MSTONE,1.3,.06,{moss:.5}),slab(circle(1.12),.06,.95,mossy({moss:.5,inlay:alc}),{key:-3,taper:[1,.8]}),
   roof('dome',0,0,.92,.92,.95,.5,q=>q.f==='top'?(vnoise(q.x*3,q.z*3,5)>.42?rp(MOSS,q.b,q.sx,q.sy):rp(MSTONE,q.b,q.sx,q.sy)):rp(MSTONE,.4,q.sx,q.sy),{key:-2,noShadow:1}),
   slab(poly(5,.16,.3),1.4,1.75,mossy(),{key:-1,taper:[1,.5]}),bush(-1.05,.75,2,1),bush(1.05,.8,9),
   dyn(4,(F,t)=>{AL.forEach((a0,k)=>{const br=K?.5+.5*Math.sin(t*TAU/5-k*2.1):.1,[x,y]=at(Math.cos(a0)*1.08,.3,Math.sin(a0)*1.08),w=a0===Math.PI/2?3:2;for(let j=-5;j<=3;j++)for(let i=-w;i<=w;i++)if(i*i/(w*w+1)+j*j/22<1)F.set(x+i,y+j,FGR[br>.7?(i*i+j*j<4?3:2):br>.35?(i*i+j*j<4?2:1):1]);if(K&&br>.8)zz(F,x+2,y-8,t+k,FGR)});
    for(const[mx,mz,s]of[[-.5,1.15,1],[.62,1.12,2],[.2,1.25,3]]){const[x,y]=at(mx,.06,mz);F.set(x,y,CLOTH[2]);F.set(x,y-1,CLOTH[2]);for(let i=-1;i<=1;i++)F.set(x+i,y-2,FGR[Math.sin(t*TAU*.4+s)>0?3:2])}
    const[fcx,fcy]=at(0,1.35,0);fireflies(F,t,K?6:3,5,fcx,fcy,40,30)},[LT(0,.4,1.05,38,.7,GREEN),LT(.9,.4,.6,26,.5,GREEN),LT(-.9,.4,.6,26,.5,GREEN)])]}}},
 {g:'bedroom',name:'Lit sous les lianes',desc:'Une couche de pierre garnie de feuillage, quatre montants légers et un ciel de lit de lianes qui ondulent. Les lucioles tournent au-dessus du dormeur.',anims:['lianes au vent','ronde de lucioles','lanterne'],
  build(){const top=1.7,[cx,cy]=at(0,1.0,.05);return{ground:floor(),objs:[oct(MSTONE,.08,{moss:.3}),
   slab(rect(-.85,-.52,.85,.52),.08,.4,mossy(),{key:-3}),slab(rect(-.76,-.44,.76,.44),.4,.52,q=>rp(LEAF,q.f==='top'?.55+(vnoise(q.x*9,q.z*9,4)-.5)*.5:.35,q.sx,q.sy),{key:-2.9}),slab(rect(-.2,-.3,.2,.3),.52,.6,q=>rp(CLOTH,q.f==='top'?.8:.5,q.sx,q.sy),{x:-.48,key:-2.8}),
   ...[[-.95,-.6],[.95,-.6],[-.95,.6],[.95,.6]].map(([x,z])=>post(x,z,top,BARK,.045)),
   box(0,-.6,1.0,.04,top,top+.07,woodMat(BARK,{along:'x'}),{key:2}),box(0,.6,1.0,.04,top,top+.07,woodMat(BARK,{along:'x'}),{key:2.2}),box(-.95,0,.04,.62,top,top+.07,woodMat(BARK),{key:2.1}),box(.95,0,.04,.62,top,top+.07,woodMat(BARK),{key:2.1}),
   dyn(4,(F,t)=>{for(let k=0;k<17;k++){const side=k<11,x=side?-.95+k*.19:(k%2?-.95:.95),z=side?.6:-.6+(k-11)*.22,[a,b]=at(x,top,z),len=7+Math.floor(hash(k,1,4)*(side?10:16));for(let j=0;j<len;j++){const sw=Math.round(Math.sin(t*1.6+k*.9+j*.25)*1.5*(j/len));F.set(a+sw,b+j,LEAF[j%3?4:6]);if(j%4===2)F.set(a+sw+(k%2?1:-1),b+j,LEAF[6])}}
    const n=K?8:3;for(let k=0;k<n;k++){const a=t*.9+k*TAU/n,r=18+Math.sin(t+k)*4;F.set(Math.round(cx+Math.cos(a)*r),Math.round(cy+Math.sin(a)*r*.5),FGR[k%2?3:2])}
    if(K){const[sx,sy]=at(.1,.56,0);for(let j=-2;j<=2;j++)for(let i=-7;i<=7;i++)F.set(sx+i,sy+j,i<-5?SANDL[3]:LEAF[j<0?5:3]);zz(F,sx-4,sy-6,t,FGR)}},[LT(0,1.0,.05,44,.7,GREEN)])]}}},
 {g:'bedroom',name:'Bassin du sommeil',desc:'Un bassin rond aux pierres moussues, de la famille du Puits des Âmes. Trois grandes feuilles servent de couches ; la brume glisse sur l’eau et le lotus du centre bat.',anims:['ronds dans l’eau','brume','lotus qui bat','feuilles qui flottent'],
  build(){const pads=[[-.45,-.25],[.5,-.1],[-.05,.5]],[cx,cy]=at(0,.08,0);return{ground:floor(),objs:[
   slab(circle(.98),0,.06,q=>q.f==='top'?rp(WATER,.3+(vnoise(q.x*5,q.z*8,3)-.5)*1.2,q.sx,q.sy):rp(MSTONE,.3,q.sx,q.sy),{key:-9}),slab(ringShape(.98,1.24),0,.2,mossy({moss:.45}),{key:-8}),
   bush(-1.1,-.9,3,1),bush(1.12,.85,6),
   dyn(4,(F,t)=>{ripple(cx,cy,6,22,'#5aa0b8')(F,t);pads.forEach(([x,z],k)=>{const bob=Math.round(Math.sin(t*1.2+k*2)*.8),[a,b]=at(x,.08,z);for(let j=-4;j<=4;j++)for(let i=-7;i<=7;i++){const d=i*i/49+j*j/16;if(d<1&&!(i>3&&Math.abs(j)<2))F.set(a+i,b+j+bob,LEAF[d>.75?3:i+j<0?6:5])}
     if(K){for(let j=-1;j<=1;j++)for(let i=-4;i<=3;i++)F.set(a+i,b+j+bob-1,i<-2?SANDL[3]:CLOTH[j<0?3:2]);zz(F,a+3,b-5,t+k*1.1,FGR)}});
    const pu=.5+.5*Math.sin(t*1.25);for(let j=-4;j<=1;j++)for(let i=-3;i<=3;i++)if(Math.abs(i)<=3-Math.abs(j+1)*.6)F.set(cx+i,cy-2+j,i===0&&j<0?FGR[pu>.5?3:2]:MSTONE[i<0?6:4]);
    for(let k=0;k<7;k++){const p=(t*.06+hash(k,1,7))%1,x=Math.round(cx-34+p*68),y=Math.round(cy-6+(hash(k,2,7)-.5)*30);for(let i=0;i<5+k%3*2;i++)if((i+k)%3&&Math.hypot(x+i-cx,y-cy)<21)F.set(x+i,y,FWH[1])}},[LT(0,.3,0,44,.75,GREEN)])]}}},

// ======================= ENTREPÔT =======================
 {g:'warehouse',name:'Carrousel aux coffres',desc:'Un plateau de marbre gradué autour d’une colonne. Les coffres y tournent d’un cran à la fois : celui qu’on demande s’arrête devant, la lampe s’allume.',anims:['plateau qui tourne','lampe d’appel','repère gradué'],
  build(){const[lx,ly]=at(0,1.62,0);return{ground:floor(),objs:[disc(MARBLE,1.3,.1),slab(circle(1.08),.1,.24,mMat({inlay:ticksI(.9,1.06,24,rp(MARBLE,.15,0,0),.03)}),{key:-8}),
   slab(circle(.17),.24,1.5,mMat({inlay:vlineI(WHC[1],.03,.2,.9)}),{key:-2,mask:true}),slab(circle(.24),1.5,1.58,mMat(),{key:-1,mask:true}),
   slab(tri(.14),.1,.3,stone(SLATE),{z:1.2,key:1.2}),
   dyn(4,(F,t,S)=>{const B=behind(F,S),step=2,n=Math.floor(t/step),u=(t%step)/step,a0=K?(n+ease(clamp(u/.45)))*TAU/6:0,stop=!K||u>.5;
    const ord=[...Array(6).keys()].sort((p,q)=>Math.sin(a0+p*TAU/6)-Math.sin(a0+q*TAU/6));for(const k of ord){const a=a0+k*TAU/6+Math.PI/2,[x,y]=at(Math.cos(a)*.72,.24,Math.sin(a)*.72);cargo(Math.sin(a)>0?F:B,x,y,k)}
    for(let j=-2;j<=2;j++)for(let i=-2;i<=2;i++)if(i*i+j*j<6)F.set(lx+i,ly-3+j,K&&stop?FWH[i||j?2:3]:FWH[0])},[LT(0,1.6,0,40,.8,WHITEC)])]}}},
 {g:'warehouse',name:'Colonne flottante',desc:'Quatre bornes et un cercle gravé. Dans la colonne de lumière blanche, coffres et caisses montent en file, tournent sur eux-mêmes et disparaissent au sommet.',anims:['colis en lévitation','colonne de lumière','éclat au sommet'],
  build(){const[cx,cy]=at(0,.12,0);return{ground:floor(),objs:[slab(square(1.28),0,.12,stone(MARBLE,{noise:.06,inlay:anyI(ringI(.62,.04,WHC[1]),ringI(.9,.025,WHC[0]))}),{key:-9}),
   ...[[-1,-1],[1,-1],[-1,1],[1,1]].map(([x,z])=>obelisk(x,z,.7,MARBLE,WHC[2],{glyph:1,y0:.12})),
   dyn(4,(F,t)=>{for(let j=0;j<80;j++)for(let i=-9;i<=9;i++)if(hash(i,j-Math.floor(t*(K?16:2)),5)>(K?.86:.96))F.set(cx+i,cy-j,WHC[Math.abs(i)<4?2:1]);
    if(!K){cargo(F,cx-6,cy+1,0);cargo(F,cx+6,cy+2,1);sCrate(F,cx,cy-7,4);return}
    for(let k=3;k>=0;k--){const p=(t*.16+k/4)%1,y=cy-4-p*66,x=cx+Math.round(Math.sin(t*1.5+k*1.6)*3);if(p>.93){for(let i=-6;i<=6;i++){F.set(x+i,Math.round(y)-4,FWH[3]);F.set(x,Math.round(y)-4+i,FWH[3])}}else cargo(F,x,Math.round(y),k)}},[LT(0,1.3,0,58,.95,WHITEC)])]}}},
 {g:'warehouse',name:'Mur de casiers',desc:'Un columbarium à marchandises : douze niches de marbre sous une corniche d’ardoise. La niche demandée s’éclaire et son coffre avance.',anims:['niche qui s’éclaire','coffre qui avance','veilleuses'],
  build(){const cols=4,rows=3,W_=2.2,H0=.3,H1=1.8,cw=W_/cols,ch=(H1-H0)/rows,nic=frontI(q=>{const u=(q.x+W_/2)/cw,v=(q.y-H0)/ch,c=Math.floor(u),r=Math.floor(v);if(c<0||c>=cols||r<0||r>=rows)return null;const fu=u-c,fv=v-r;if(fu<.12||fu>.88||fv<.1||fv>.9)return null;return rp(DSTONE,.1+(fv>.75?.1:0),q.sx,q.sy)});
   return{ground:floor(),objs:[slab(rect(-1.3,-1.0,1.3,1.15),0,.1,stone(MARBLE,{noise:.06}),{key:-9}),box(0,-.45,W_/2+.08,.38,.1,H1+.08,mMat({inlay:nic}),{key:-2}),
   box(0,-.45,W_/2+.16,.46,H1+.08,H1+.2,mMat(),{key:3}),roof('shed',0,-.45,W_/2+.2,.5,H1+.2,.22,shingle(SLATE,{cw:.1}),{key:4,noShadow:1}),
   column(-1.05,.8,.45,MARBLE,{flame:'white',light:WHITEC}),column(1.05,.8,.45,MARBLE,{flame:'white',light:WHITEC}),crate(-.5,.75,.16),
   dyn(4,(F,t)=>{const step=1.8,n=Math.floor(t/step),u=(t%step)/step,act=K?Math.floor(hash(n,3,9)*12):-1;for(let k=0;k<12;k++){const c=k%cols,r=Math.floor(k/cols);if(hash(k,1,5)<.2&&k!==act)continue;const[x,y]=at(-W_/2+(c+.5)*cw,H0+r*ch+.06,-.07),out=k===act?Math.round(Math.sin(u*Math.PI)*4):0;
     if(k===act){const[a,b]=at(-W_/2+c*cw,H0+(r+1)*ch,-.07),w=Math.round(cw*T),h=Math.round(ch*T);for(let i=1;i<w;i++){F.set(a+i,b+1,FWH[3]);F.set(a+i,b+h-1,FWH[3])}for(let j=1;j<h;j++){F.set(a+1,b+j,FWH[3]);F.set(a+w-1,b+j,FWH[3])}}
     cargo(F,x,y+out,k)}},[LT(0,1.0,0,50,.6,WHITEC)])]}}},
 {g:'warehouse',name:'Grande balance',desc:'La balance de Sigil, à l’échelle d’un bâtiment : coffres bleus d’un côté, coffres rouges de l’autre. Le fléau penche selon ce qui entre et ce qui sort.',anims:['fléau qui penche','plateaux et chaînes','lampe de tête'],
  build(){const[px,py]=at(0,1.95,0);return{ground:floor(),objs:[disc(MARBLE,1.3,.1),slab(square(.5),.1,.3,mMat(),{key:-3}),
   slab(square(.16),.3,1.9,mMat({inlay:vlineI(WHC[1],.03,.15,.9)}),{key:-2,taper:[1.2,.8],mask:true}),slab(square(.2),1.9,1.98,mMat(),{key:-1}),
   crate(-.2,1.05,.15),crate(.15,1.1,.13),
   dyn(4,(F,t,S)=>{const a=K?Math.sin(t*.7)*.2+Math.sin(t*1.9)*.03:0,L=30;for(const s of[-1,1]){const ex=px+s*Math.cos(a)*L,ey=py+s*Math.sin(a)*L;thick(F,px,py,ex,ey,SILVER[4],IRON[3]);const X=Math.round(ex),Y=Math.round(ey)+20;
     F.line(X,ey,X-9,Y,IRON[4]);F.line(X,ey,X+9,Y,IRON[4]);for(let i=-11;i<=11;i++){F.set(X+i,Y,SILVER[4]);F.set(X+i,Y+1,IRON[i<0?5:3]);if(Math.abs(i)<9)F.set(X+i,Y+2,IRON[2])}
     const R=s<0?BLUEC:REDC;sChest(F,X-5,Y-1,R);sChest(F,X+5,Y-1,R);sChest(F,X,Y-9,R)}
    for(let j=-2;j<=2;j++)for(let i=-2;i<=2;i++)if(i*i+j*j<6)F.set(px+i,py-5+j,FWH[i||j?2:3])},[LT(0,2.1,0,36,.7,WHITEC)])]}}},
 {g:'warehouse',name:'Monte-charge',desc:'Une trappe à deux vantaux dans une margelle de marbre, sous une chèvre à poulie. Les vantaux s’écartent, le plateau remonte chargé, puis redescend.',anims:['vantaux de la trappe','plateau qui monte','poulie et câbles'],
  build(){const[cx,cy]=at(0,.2,.1),[wx,wy]=at(0,2.05,.1);return{ground:floor(),objs:[slab(square(1.3),0,.08,stone(MARBLE,{noise:.06}),{key:-9}),
   slab(rect(-.85,-.6,.85,.8),.08,.1,q=>rp(DSTONE,q.f==='top'?.05:.3,q.sx,q.sy),{key:-8}),
   box(0,-.7,.98,.1,.08,.3,mMat(),{key:-.8}),box(-.92,.1,.08,.7,.08,.3,mMat(),{key:-.7}),box(.92,.1,.08,.7,.08,.3,mMat(),{key:-.7}),box(0,.9,.98,.1,.08,.3,mMat(),{key:.9}),
   slab(square(.07),.08,2.1,woodMat(WOOD),{x:-1.05,z:.1,key:.1,taper:[1.2,.9]}),slab(square(.07),.08,2.1,woodMat(WOOD),{x:1.05,z:.1,key:.1,taper:[1.2,.9]}),box(0,.1,1.12,.06,2.1,2.22,woodMat(WOOD,{along:'x'}),{key:3}),
   dyn(.5,(F,t)=>{const per=8,u=K?(t%per)/per:0,open=K?(u<.12?u/.12:u<.88?1:1-(u-.88)/.12):0,lift=K?(u<.15?0:u<.4?ease((u-.15)/.25):u<.6?1:u<.85?1-ease((u-.6)/.25):0):0,hw=19,x0=cx-hw,y0=cy-14,hh=30;
     if(lift>0){const py=y0+Math.round((1-lift)*8)-Math.round(lift*12);for(let j=0;j<hh-4;j++)for(let i=2;i<2*hw-2;i++)F.set(x0+i,py+j,j>hh-8?WOOD[1]:(i%6===0?WOOD[2]:WOOD[j<2?5:4]));cargo(F,cx-9,py+12,0);cargo(F,cx+8,py+13,1);sCrate(F,cx,py+21,4);
      for(const s of[-1,1])F.line(wx+s*3,wy+3,cx+s*(hw-4),py,CANVAS[1])}
     const w=Math.round(hw*(1-open));for(let j=0;j<hh;j++)for(let i=0;i<w;i++){const c=j===0?MARBLE[6]:i===w-1?MARBLE[2]:(j%8===0?MARBLE[3]:MARBLE[5]);F.set(x0+i,y0+j,c);F.set(x0+2*hw-1-i,y0+j,c)}
     wheelDyn(wx,wy+2,4,4,K?(lift>0&&lift<1?4:0):0,IRON)(F,t)},[LT(0,.4,.1,40,.5,WHITEC)])]}}},
];
const glyphLine=()=>bandI(.3,.75,AEC[1],.15,7);
const cyLineA=v=>q=>q.f==='side'&&!q.lip&&Math.abs(q.v-v)<.08?AEC[1]:null;
