// ================= BÂTIMENTS v4 : Scierie, Archerie, Armurerie (découpage de la fabrication, 2026-11-20) =================
// Assemblé par tools/batiments-16bits/build_v4.py : moteur de creuset-planches.js + outils v2 + outils v3 (avant GROUPS) + ce fichier.
// K = 1 au travail, 0 au repos (réglé par la page via BAT.setWork). Même rendu que la v3 : volumes en 3/4 finis en 16 bits.

// ---------- outils propres à la v4 ----------
const FIB=R_(['#7a6644','#a08a5e','#c8b080','#e6d6a8']);          // fibre de bois
const FEA=R_(['#8a8e98','#b8bcc6','#e2e4ea','#ffffff']);          // plumes
const STRING=E('#d8cfb4');
function pdisk(F,cx,cy,r,fn){for(let j=-Math.ceil(r);j<=Math.ceil(r);j++)for(let i=-Math.ceil(r);i<=Math.ceil(r);i++){const d=Math.hypot(i,j);if(d<=r+.3){const c=fn(i,j,d);if(c!=null)F.set(Math.round(cx)+i,Math.round(cy)+j,c)}}}
// lame circulaire vue de face : dents qui tournent avec l'angle a
function sawBlade(F,cx,cy,r,a,hot){pdisk(F,cx,cy,r+1,(i,j,d)=>{const an=Math.atan2(j,i)-a,tooth=((an*12/TAU)%1+1)%1;
 if(d>r-.4)return tooth<.45?SILVER[i+j<0?4:2]:null;if(d<2.2)return hot?AEC[3]:IRON[5];if(d<3.4)return IRON[3];
 const sp=((an*4/TAU)%1+1)%1;if(sp<.08&&d<r-2)return SILVER[1];return SILVER[i+j<-2?4:i+j>3?2:3]})}
// rondin couché le long de x (vu de côté) : x0..x1, axe en y, rayon r, bout coupé en x1
function logX(F,x0,x1,y,r,cut){x0=Math.round(x0);x1=Math.round(x1);for(let x=x0;x<=x1;x++)for(let j=-r;j<=r;j++){const v=j/r;F.set(x,Math.round(y)+j,j===-r?BARK[4]:j===r?BARK[0]:BARK[v<-.3?3:v<.4?2:1])}
 pdisk(F,x1,y,r,(i,j,d)=>i<0?null:d>r-1?BARK[1]:SAND[(Math.round(d)%2)?5:4]);if(cut!=null)for(let x=x0;x<=Math.min(cut,x1-1);x++)F.set(x,Math.round(y)-r+1,DSTONE[1])}
// flèche de (x0,y0) vers (x1,y1) : pointe en x1
function arrowL(F,x0,y0,x1,y1,fc=FEA,glow){F.line(x0,y0,x1,y1,WOOD[4]);const L=Math.hypot(x1-x0,y1-y0)||1,ux=(x1-x0)/L,uy=(y1-y0)/L;
 F.set(Math.round(x1),Math.round(y1),SILVER[4]);F.set(Math.round(x1-ux),Math.round(y1-uy),SILVER[2]);
 for(let k=0;k<3;k++){const bx=x0+ux*k,by=y0+uy*k;F.set(Math.round(bx-uy*1.5),Math.round(by+ux*1.5),glow?AEC[2]:fc[2]);F.set(Math.round(bx+uy*1.5),Math.round(by-ux*1.5),glow?AEC[3]:fc[3])}}
// arc vertical vu de face, corde tirée de `pull` px vers la gauche
function bowV(F,x,y,h,pull,R=WOOD){let px=x,py=y-h;for(let j=-h;j<=h;j++){const v=j/h,bx=Math.round(x+(1-v*v)*5);F.set(bx,y+j,R[4]);F.set(bx+1,y+j,R[2])}
 F.set(x,y-h-1,R[5]);F.set(x,y+h+1,R[5]);F.line(x,y-h,x-pull,y,STRING);F.line(x-pull,y,x,y+h,STRING)}
function ingot(F,x,y,R=COPPER){for(let i=0;i<7;i++){F.set(x+i,y-2,R[5]);F.set(x+i,y-1,R[i<1?3:4]);F.set(x+i,y,R[2])}F.set(x+7,y-1,R[1]);F.set(x+7,y,R[1])}
function ingotsObj(x,z,R=COPPER,n=3){return{key:z,draw(L,S){const[a,b]=P3(x,0,z),A=Math.round(a),B=Math.round(b);S.shadowEll(A+4,B+1,7,2,.6);
 for(let k=0;k<n;k++){const ox=A-4+(k%2)*4-(k>1?2:0),oy=B-(k>1?3:0)-(k%2?0:0);ingot(L,ox+(k>1?2:0),oy-(k===1?0:0),R)}return{}}}}
function curl(F,x,y,p,c=FIB){for(let k=0;k<7;k++){const a=k*.9+p*6,r=1+k*.35;F.set(Math.round(x+Math.cos(a)*r),Math.round(y+Math.sin(a)*r*.8),c[k%2?3:2])}}
// petit marteau en lévitation, tête en (x,y)
function floatHammer(F,x,y,ang,R=IRON){const c=Math.cos(ang),s=Math.sin(ang);F.line(x,y,Math.round(x+c*10),Math.round(y+s*10),WOOD[4]);for(let j=-2;j<=2;j++)for(let i=-3;i<=3;i++)F.set(x+i,y+j,j<0?R[6]:i<0?R[5]:R[3])}
function swordV(F,x,y,len,C=COLDB,hilt=true){for(let j=0;j<len;j++){F.set(x,y-j,C[j===len-1?0:1]);F.set(x+1,y-j,C[3])}if(hilt){for(let i=-3;i<=4;i++)F.set(x+i,y+1,IRON[5]);F.set(x,y+2,LEATHER[2]);F.set(x+1,y+2,LEATHER[1]);F.set(x,y+3,LEATHER[2]);F.set(x,y+4,COPPER[4])}}
const HOTB=[MOLT[4],MOLT[3],MOLT[2],MOLT[1]],COLDB=[SILVER[4],SILVER[3],SILVER[2],SILVER[1]];

const GROUPS=[
 {id:'scierie',name:'Scierie',note:'Nouveau bâtiment, service d’Aether. Le bois brut y devient planches et fibre de bois. Bois, fer et flamme bleu-violet ; l’animation montre le bois qui se découpe.'},
 {id:'archerie',name:'Archerie',note:'Nouveau bâtiment, service d’Aether. Arcs, flèches et, plus tard, munitions de l’Arbalestrie. Bois clair, cuir, plumes et empennages qui s’allument d’Aether.'},
 {id:'creuset',name:'Armurerie',note:'Ex-Creuset des Exilés : il ne coule plus, il façonne les lingots de la Fonderie en armes et armures. Fer, basalte et métal chauffé orange.'}];

const ITEMS=[
// ======================= SCIERIE =======================
 {g:'scierie',name:'Grande scie d’Aether',desc:'Une lame circulaire géante dressée sur un banc de fer. Le rondin avance seul dans la lame, qui le refend en planches dans une gerbe de sciure.',anims:['lame qui tourne','rondin qui avance','sciure','moyeu d’Aether'],
  build(){const[bx,by]=at(0,.95,0),[lx,ly]=at(0,.62,0);return{ground:floor(),objs:[oct(SLATE,.1,{inlay:ringI(1.04,.035,AEC[0])}),
   box(0,0,1.05,.24,.1,.48,woodMat(WOOD,{along:'x'}),{key:-1}),slab(rect(-.12,-.3,.12,.3),.1,.52,iMat(),{key:-.9}),
   ...logs(-.8,-.9,3,.28),planks(.62,.95,4,.42),barrel(-.98,.9,WOOD,{h:.34}),
   dyn(4,(F,t)=>{const per=6,u=K?(t%per)/per:.55,head=Math.round(lx-22+u*52),tail=Math.max(head-44,lx-30);
    sawBlade(F,bx,by,17,K?t*TAU*7/6:.3,K);if(head>tail+3)logX(F,tail,head,ly,6,lx);
    for(let i=-1;i<=1;i++)F.set(bx+i,ly+7,IRON[2]);
    if(K&&head>lx-2){sparkC(bx-2,ly-6,['#a08a5e','#c8b080','#e6d6a8'],12,4,11,10)(F,t);for(let k=0;k<5;k++)F.set(bx-10-k*2+Math.round(Math.sin(t*TAU*1.5+k)*1.5),ly+9+(k%2),FIB[k%3+1])}},[LT(0,.95,0,40,.7,VIOBLUE,.1)])]}}},
 {g:'scierie',name:'Scie de long à contrepoids',desc:'Un portique de bois et un cadre de scie qui monte et descend dans le tronc. Le contrepoids de basalte fait le travail ; le tronc glisse d’un cran à chaque passe.',anims:['cadre de scie','contrepoids','tronc qui avance','poulie d’Aether'],
  build(){const[px,py]=at(0,2.18,-.1),[tx,ty]=at(0,.62,-.1);return{ground:floor(),objs:[slab(square(1.28),0,.08,woodMat(WOOD),{key:-9}),
   post(-.62,-.1,2.2,BARK,.08),post(.62,-.1,2.2,BARK,.08),box(0,-.1,.78,.08,2.1,2.24,woodMat(WOOD,{along:'x'}),{key:2}),
   sawhorse(-.6,.15),sawhorse(.6,.15),...logs(.85,-.95,3,.26),planks(-.6,1.0,3,.4),
   dyn(4,(F,t)=>{const u=K?Math.sin(t*TAU*1.2):0,dy=Math.round(u*7),adv=K?Math.floor(t*1.2)%8:3,lx=tx-38+adv*3;
    logX(F,lx,tx+30,ty+4,6,tx);
    const fy=ty-12+dy;for(let j=0;j<30;j++){F.set(tx-8,fy+j-6,IRON[4]);F.set(tx+8,fy+j-6,IRON[3])}for(let i=-8;i<=8;i++){F.set(tx+i,fy-6,IRON[5]);F.set(tx+i,fy+24,IRON[3])}for(let j=0;j<29;j++)F.set(tx,fy+j-5,SILVER[(j+dy)%3?3:4]);
    F.line(tx,fy-6,px,py+3,IRON[1]);wheelDyn(px,py,4,4,K?2:0,IRON)(F,t);F.set(px,py,AEC[K?3:1]);
    const cx=px+14,cy=py+20-dy;F.line(px+4,py,cx,cy-4,IRON[1]);for(let j=0;j<7;j++)for(let i=-4;i<=4;i++)F.set(cx+i,cy-4+j,BASALT[j===0?6:i<-2?5:3]);F.set(cx,cy-1,AEC[K?2:0]);
    if(K&&u>.6)dustDyn(tx,ty+12,6,4)(F,t)},[LT(0,2.1,-.1,30,.6,VIOBLUE)])]}}},
 {g:'scierie',name:'Fendoir de basalte',desc:'Un coin de basalte gravé flotte au-dessus d’un billot. Il retombe, fend la bûche en deux, et les moitiés rejoignent le tas ; le cercle de glyphes s’allume à l’impact.',anims:['coin qui frappe','bûche fendue','éclats','cercle de glyphes'],
  build(){const[bx,by]=at(0,.42,.05);return{ground:floor(),objs:[oct(BASALT,.1,{inlay:ringI(.95,.04,AEC[1])}),
   slab(circle(.3),.1,.42,woodMat(BARK,{inlay:q=>q.f==='top'?rp(SAND,.6+((Math.round(q.rad*T)%2)?.15:0),q.sx,q.sy):null}),{z:.05,key:-1}),
   ...logs(-.82,-.85,3,.3),...logs(.82,-.85,3,.3),logs(-.95,.75,2,.22)[0],logs(-.75,.75,2,.22)[1],barrel(.95,.9,WOOD,{h:.3}),
   dyn(4,(F,t,S)=>{const per=2.2,u=K?(t%per)/per:.0,fall=u>.55&&u<.62,hit=u>=.62,lift=u<.55?Math.sin(u/.55*Math.PI/2):u<.62?1-(u-.55)/.07:0,wy=by-12-Math.round((K?lift:1)*22),sep=hit?Math.round(ease(clamp((u-.62)/.3))*9):0;
    // bûche (deux moitiés)
    if(!hit||u<.95)for(const s of[-1,1])for(let j=0;j<12;j++)for(let i=0;i<5;i++){const x=bx+s*(i+1+sep),y=by-12+j+(hit?Math.round(sep*.4):0);F.set(x,y,i===4?BARK[2]:i===0?SAND[5]:SAND[3+(j%3===0?1:0)])}
    // coin
    const wy2=hit?by-16:wy;for(let j=0;j<12;j++){const w=Math.max(0,6-Math.floor(j/2));for(let i=-w;i<=w;i++)F.set(bx+i,wy2-6+j,BASALT[j<2?6:i<-1?5:i>2?2:4])}for(let i=-5;i<=5;i++)F.set(bx+i,wy2-3,AEC[K?2:0]);
    if(K&&hit&&u<.75){for(let k=0;k<64;k++){const a=k*TAU/64,[x,y]=at(Math.cos(a)*.95,.1,Math.sin(a)*.95);for(const d of[-1,0,1])if(S.P.get(x,y+d)===AEC[1])F.set(x,y+d,AEC[3])}
     sparkC(bx,by-12,['#a08a5e','#c8b080','#e6d6a8'],10,6,10,14,per,.08)(F,t-per*.62)}},[LT(0,.6,0,40,.7,VIOBLUE,.15)])]}}},
 {g:'scierie',name:'Meule défibreuse',desc:'Une meule de pierre roule en rond dans une auge circulaire, entraînée par un bras d’Aether. Elle écrase les copeaux en fibre, qu’on suspend à sécher.',anims:['meule qui roule','bras tournant','fibre qui s’envole','séchoir'],
  build(){const[ax,ay]=at(0,1.05,-.1);return{ground:floor(),objs:[disc(DSTONE,1.28,.08),
   slab(ringShape(.42,.86),.08,.34,stone(SLATE,{noise:.1,inlay:q=>q.f==='top'&&q.rad>.5&&q.rad<.8?rp(FIB,.45+(hash(q.sx,q.sy,3)-.5)*.5,q.sx,q.sy):null}),{z:-.1,key:-3}),
   slab(circle(.12),.08,1.05,iMat({inlay:vlineI(AEC[1],.03,.2,.9)}),{z:-.1,key:-2,mask:true}),
   post(-1.05,.85,.9,WOOD,.04),post(-.45,.85,.9,WOOD,.04),box(-.75,.85,.34,.03,.84,.9,woodMat(WOOD,{along:'x'}),{key:.9}),
   dyn(4,(F,t,S)=>{const B=behind(F,S),a=K?t*.9:.6,front=Math.sin(a)>0,D=front?F:B,[wx,wy]=at(Math.cos(a)*.64,.46,-.1+Math.sin(a)*.64),hw=Math.max(2,Math.round(9*Math.abs(Math.sin(a))));
    D.line(ax,ay,wx,wy-2,WOOD[4]);D.line(ax,ay+1,wx,wy-1,WOOD[2]);
    for(let j=-9;j<=9;j++)for(let i=-hw;i<=hw;i++){const e=i*i/(hw*hw)+j*j/81;if(e>1)continue;const roll=K?Math.floor(t*8+j/3)%3:0;D.set(wx+i,wy+j,e>.7?QZ[0]:QZ[(i<0?4:2)-(roll===0&&Math.abs(i)<hw-1?1:0)])}
    const[hx,hy]=at(0,1.1,-.1);F.set(hx,hy,AEC[K?3:1]);
    const[rx,ry]=at(-.75,.86,.85);for(let k=0;k<5;k++){const sw=K?Math.round(Math.sin(t*2+k)*1):0;for(let j=1;j<9+k%3*2;j++)F.set(rx-10+k*5+(j>4?sw:0),ry+j,FIB[(j+k)%3+1])}
    if(K)for(let k=0;k<6;k++){const p=(t*.35+hash(k,1,8))%1;F.set(Math.round(wx+(hash(k,2,8)-.5)*16+p*6),Math.round(wy-6-p*16),FIB[p<.5?3:2])}},[LT(0,1.1,-.1,32,.6,VIOBLUE)])]}}},
 {g:'scierie',name:'Tour à bois',desc:'Un long banc de tour : le volant d’Aether entraîne le fût, le ciseau court le long de la pièce et en tire de longs copeaux qui s’enroulent et tombent.',anims:['fût qui tourne','ciseau qui court','copeaux en spirale','volant'],
  build(){const[hx,hy]=at(-.78,.98,-.05),[tx,ty]=at(0,.78,-.05);return{ground:floor(),objs:[slab(square(1.28),0,.08,stone(SLATE,{noise:.08}),{key:-9}),
   box(0,-.05,.95,.2,.08,.5,woodMat(WOOD,{along:'x'}),{key:-1}),box(-.78,-.05,.16,.22,.5,1.0,iMat(),{key:-.8}),box(.8,-.05,.1,.16,.5,.86,iMat(),{key:-.8}),
   planks(.55,.95,3,.42),...[[-.95,.95],[-.8,.95]].map(([x,z])=>slab(circle(.04),0,1.1,woodMat(SAND),{x,z,key:z})),
   dyn(4,(F,t)=>{const r=5,x0=hx+8,x1=tx+30,roll=K?Math.floor(t*14):0;for(let x=x0;x<=x1;x++)for(let j=-r;j<=r;j++){const v=j/r,s=((x+roll+j*2)%6+6)%6<1;F.set(x,ty+j,s?SAND[3]:SAND[v<-.4?6:v<.4?5:4])}
    wheelDyn(hx-2,hy,11,6,K?6:0,IRON,{thick:1})(F,t);F.set(hx-2,hy,AEC[K?3:1]);
    const u=K?(t%5)/5:.3,cx=Math.round(x0+4+(x1-x0-8)*(u<.8?u/.8:1-(u-.8)/.2));for(let j=0;j<8;j++){F.set(cx,ty+r+1+j,IRON[5]);F.set(cx+1,ty+r+1+j,IRON[3])}F.set(cx,ty+r,SILVER[4]);
    if(K&&u<.8){for(let k=0;k<3;k++){const p=((t*.9+k/3)%1);curl(F,cx-2-p*4,ty-r-2+p*24,p+k)}}
    for(let k=0;k<6;k++)curl(F,tx-20+k*8,ty+19+(k%2),k*.7)},[LT(-.78,1,0,30,.6,VIOBLUE)])]}}},

// ======================= ARCHERIE =======================
 {g:'archerie',name:'Butte de tir',desc:'Une butte de paille et sa cible, face à un grand arc d’essai dressé sur son chevalet. L’arc se tend seul, décoche, et la flèche va se planter dans la cible.',anims:['arc qui se tend','flèche en vol','cible qui tremble','empennage d’Aether'],
  build(){const[cx,cy]=at(.55,.78,-.55),[ax,ay]=at(-.7,.72,.55);return{ground:floor(),objs:[slab(square(1.28),0,.06,stone(SANDL,{noise:.2}),{key:-9}),
   slab(rect(-.38,-.24,.38,.24),.06,1.2,stone(SAND,{noise:.25,courses:.12,joint:.3}),{x:.55,z:-.7,key:-2}),
   post(-.7,.55,.75,WOOD,.05),post(-.86,.4,.55,WOOD,.04),post(-.54,.4,.55,WOOD,.04),rack(.4,.75,3),
   dyn(4,(F,t)=>{const per=2.5,u=K?(t%per)/per:0,shake=K&&u>.62&&u<.75?Math.round(Math.sin(u*120)):0;
    pdisk(F,cx+shake,cy,10,(i,j,d)=>d>9.3?WOOD[2]:d<2?REDC[3]:d<4.5?PARCH[4]:d<7?REDC[2]:PARCH[3]);
    const stuck=K?Math.min(3,Math.floor(t/per)%4):1;for(let k=0;k<stuck;k++){const sx=cx+shake-4+k*4,sy=cy-3+k*3;F.line(sx,sy,sx-7,sy+3,WOOD[4]);F.set(sx-7,sy+3,FEA[3]);F.set(sx-7,sy+2,FEA[2])}
    const pull=K?(u<.5?Math.round(ease(u/.5)*7):0):0;bowV(F,ax,ay,13,pull);
    if(K&&u<.5)arrowL(F,ax-pull-1,ay,ax+8,ay,FEA,true);
    if(K&&u>=.5&&u<.62){const p=(u-.5)/.12,x=ax+(cx-ax)*p,y=ay+(cy-ay)*p-Math.sin(p*Math.PI)*8;arrowL(F,x-10,y+Math.round((cy-ay)/30),x,y,FEA,true)}},[LT(-.7,.8,.55,26,.5,VIOBLUE)])]}}},
 {g:'archerie',name:'Carrousel d’empennage',desc:'Une roue horizontale porte les flèches debout. Elle tourne devant un panier de plumes : chaque flèche qui passe reçoit son empennage, qui s’éclaire d’Aether.',anims:['roue des flèches','plumes qui volent','empennages lumineux'],
  build(){return{ground:floor(),objs:[oct(WOOD,.1,{inlay:ringI(1.05,.035,AEC[0])}),slab(circle(.3),.1,.3,iMat(),{key:-3}),
   slab(circle(.07),.3,1.3,woodMat(WOOD),{key:-2,mask:true}),barrel(.92,.92,LEATHER,{h:.32,r:.17}),crate(-.95,.9,.15),
   dyn(4,(F,t,S)=>{const B=behind(F,S),a0=K?t*.6:.3,[hx,hy]=at(0,.7,0);
    for(let k=0;k<96;k++){const a=k*TAU/96,[x,y]=at(Math.cos(a)*.86,.7,Math.sin(a)*.86),D=Math.sin(a)>-.1?F:B;D.set(x,y,WOOD[Math.sin(a)<0?5:4]);D.set(x,y+1,WOOD[2])}
    const order=[...Array(10).keys()].sort((p,q)=>Math.sin(a0+p*TAU/10)-Math.sin(a0+q*TAU/10));
    for(const k of order){const a=a0+k*TAU/10,D=Math.sin(a)>-.1?F:B,[x,y]=at(Math.cos(a)*.86,.7,Math.sin(a)*.86),done=Math.cos(a)<.2;
     for(let j=0;j<18;j++)D.set(x,y-j,WOOD[4]);D.set(x,y-18,SILVER[4]);D.set(x,y-19,SILVER[3]);
     if(done){D.set(x-1,y-2,AEC[K?2:1]);D.set(x+1,y-2,AEC[K?3:1]);D.set(x-1,y-3,FEA[2]);D.set(x+1,y-3,FEA[3]);D.set(x-1,y-4,FEA[2]);D.set(x+1,y-4,FEA[3])}}
    D2:{const[bx,by]=at(.92,.32,.92);if(K)for(let k=0;k<5;k++){const p=(t*.4+hash(k,1,4))%1,x=Math.round(bx-p*16+Math.sin(t*3+k)*2),y=Math.round(by-p*14+Math.sin(p*7)*2);F.set(x,y,FEA[3]);F.set(x+1,y,FEA[2])}
     for(let i=-3;i<=3;i++)F.set(bx+i,by-1-(i&1),FEA[3])}
    F.set(hx,hy-14,AEC[K?3:1])},[LT(0,1.0,0,34,.6,VIOBLUE)])]}}},
 {g:'archerie',name:'Cintreuse à vapeur',desc:'Une étuve de planches crache sa vapeur ; à côté, un gabarit de pierre en croissant. La latte attendrie s’y plie en arc sous les serre-joints, puis rejoint le râtelier.',anims:['latte qui se cintre','vapeur de l’étuve','serre-joints','arcs suspendus'],
  build(){const[gx,gy]=at(.35,.62,.35),[sx,sy]=at(-.65,.75,-.55);return{ground:floor(),objs:[slab(square(1.28),0,.08,stone(SLATE,{noise:.08}),{key:-9}),
   box(-.6,-.55,.6,.2,.3,.72,woodMat(WOOD,{along:'x'}),{key:-2}),post(-1.1,-.55,.3,WOOD,.05),post(-.1,-.55,.3,WOOD,.05),barrel(-1.0,.6,IRON,{h:.4,water:1}),
   slab(rect(-.5,-.18,.5,.18),.08,.5,stone(BASALT,{noise:.08,inlay:bandI(.3,.7,AEC[1],.2,3)}),{x:.35,z:.35,key:.1}),
   {key:-1.5,draw(L){const[a,b]=at(.6,1.6,-.9);L.rect(a-24,b,40,2,WOOD[3]);for(let k=0;k<3;k++){const x=a-18+k*12;for(let j=0;j<16;j++){const v=(j-8)/8;L.set(x+Math.round((1-v*v)*4),b+3+j,WOOD[4]);L.set(x+1+Math.round((1-v*v)*4),b+3+j,WOOD[2])}L.line(x,b+3,x,b+18,STRING)}return{}}},
   post(.95,-.9,1.6,BARK,.04),post(.25,-.9,1.6,BARK,.04),
   dyn(4,(F,t)=>{const per=5,u=K?(t%per)/per:.0,bend=K?ease(clamp((u-.15)/.5)):0;
    for(let i=-20;i<=20;i++){const v=i/20,y=gy-8-Math.round(bend*(1-v*v)*-9)+0;const yy=gy-10-Math.round(bend*9)+Math.round(bend*v*v*9);F.set(gx+i,yy-1,SAND[6]);F.set(gx+i,yy,SAND[5]);F.set(gx+i,yy+1,WOOD[3])}
    for(const s of[-12,0,12]){const v=s/20,y=gy-8-Math.round(bend*9)+Math.round(bend*v*v*9);for(let j=-2;j<=3;j++)F.set(gx+s,y+j,IRON[j<0?5:3]);F.set(gx+s+1,y-2,IRON[6])}
    if(K){steamDyn(sx,sy-4,22,3)(F,t);steamDyn(sx+12,sy-3,18,6)(F,t);steamDyn(sx-12,sy-2,16,9)(F,t)}},[LT(.35,.6,.35,26,.5,VIOBLUE)])]}}},
 {g:'archerie',name:'Carquois-totem',desc:'Un carquois géant de bois cerclé de cuir, gravé d’Aether. Les flèches finies en jaillissent en gerbe, tournent au-dessus et y redescendent se ranger.',anims:['gerbe de flèches','flèches qui tournent','glyphes du fût'],
  build(){const[tx,ty]=at(0,1.75,-.1);return{ground:floor(),objs:[disc(WOOD,1.28,.1,{inlay:ringI(1.0,.04,LEATHER[2])}),
   slab(circle(.38),.1,1.75,woodMat(WOOD,{horiz:0,inlay:q=>q.f==='side'&&(Math.abs(q.v-.2)<.04||Math.abs(q.v-.8)<.04)?rp(LEATHER,.5+q.b*.3,q.sx,q.sy):q.f==='side'&&q.n[1]>.4&&Math.abs(q.x)<.04&&q.v>.3&&q.v<.7?AEC[1]:q.f==='top'?rp(DSTONE,.2,q.sx,q.sy):null}),{z:-.1,key:-2,taper:[.85,1.1]}),
   ...[[-1.0,.85],[1.0,.85]].map(([x,z])=>column(x,z,.5,WOOD,{flame:'vb',light:VIOBLUE})),crate(.9,-.95,.15),
   dyn(4,(F,t)=>{for(let k=0;k<6;k++){const x=tx-8+k*3;arrowL(F,x,ty-1,x+(k%2),ty-8-(k%3),FEA,false)}
    if(K){for(let k=0;k<8;k++){const p=(t*.25+k/8)%1,h=Math.sin(p*Math.PI),a=p*TAU*1.5+k,x=tx+Math.round(Math.cos(a)*16*h),y=ty-10-Math.round(h*30);
     arrowL(F,x,y+6,x+Math.round(Math.sin(a)*2),y-4,FEA,true)}}
    else F.set(tx,ty-12,AEC[1])},[LT(0,1.9,-.1,40,.7,VIOBLUE,.1)])]}}},
 {g:'archerie',name:'Corderie aux arcs',desc:'Deux poteaux et une corde tendue que la roue d’Aether torsade sans fin. La corde vibre ; les arcs prêts pendent aux poteaux, cordés un à un.',anims:['roue qui torsade','corde qui défile','corde qui vibre','arcs pendus'],
  build(){const[ax,ay]=at(-.95,1.05,-.2),[bx,by]=at(.95,1.05,-.2);return{ground:floor(),objs:[slab(rect(-1.28,-.6,1.28,1.0),0,.08,woodMat(WOOD,{along:'x'}),{key:-9}),
   post(-.95,-.2,1.5,BARK,.08),post(.95,-.2,1.5,BARK,.08),box(-.95,-.2,.12,.12,1.5,1.58,iMat(),{key:-.1}),
   barrel(-.6,.75,WOOD,{h:.28,r:.16}),crate(.55,.8,.15),
   {key:-.05,draw(L){for(const s of[-1,1]){const[a,b]=at(s*.95,1.3,-.08);for(let k=0;k<2;k++){const x=a+s*(5+k*5);for(let j=0;j<12;j++){const v=(j-6)/6;L.set(x+Math.round((1-v*v)*3),b+j,WOOD[4]);L.set(x+1+Math.round((1-v*v)*3),b+j,WOOD[2])}L.line(x,b,x,b+12,STRING)}}return{}}},
   dyn(4,(F,t)=>{wheelDyn(ax,ay,8,4,K?4:0,WOOD,{thick:1})(F,t);F.set(ax,ay,AEC[K?3:1]);const vib=K?Math.sin(t*40):0;
    for(let x=ax+8;x<=bx-2;x++){const v=(x-ax)/(bx-ax),y=ay+Math.round(Math.sin(v*Math.PI)*(2+vib*1.2)),tw=((x*2+(K?Math.floor(t*10):0))%4+4)%4;F.set(x,y,tw<2?BONE[4]:BONE[2]);F.set(x,y+1,BONE[1])}
    const[hx,hy]=at(-.95,1.05,-.2);F.line(hx-2,hy-8,hx-2,hy+8,WOOD[4]);if(K&&Math.floor(t*3)%2)F.set(hx-2,hy-8,AEC[3])},[LT(-.95,1.1,-.2,28,.6,VIOBLUE)])]}}},

// ======================= ARMURERIE =======================
 {g:'creuset',name:'Mannequin martelé',desc:'Un plastron sur son mannequin, au milieu d’un dais de basalte. Deux marteaux en lévitation le frappent tour à tour ; les lingots attendent sur le côté.',anims:['deux marteaux alternés','étincelles','plastron chauffé','lingots'],
  build(){const[mx,my]=at(0,1.0,0);return{ground:floor(),objs:[oct(BASALT,.12,{inlay:ringI(1.04,.04,AEC[1])}),slab(circle(.4),.12,.26,dMat(),{key:-2}),
   mannequin(0,0,{}),ingotsObj(-.85,.8,COPPER,3),ingotsObj(.85,.85,IRON,3),brazier(-1.0,-.85,BASALT,'vb',VIOBLUE),brazier(1.0,-.85,BASALT,'vb',VIOBLUE),
   dyn(4,(F,t)=>{const per=1.4,u=K?(t%per)/per:.3;for(const s of[-1,1]){const ph=(u+(s>0?.5:0))%1,lift=ph<.75?Math.sin(ph/.75*Math.PI/2):1-(ph-.75)/.25,hx=mx+s*(9+Math.round(lift*8)),hy=my-6-Math.round(lift*10);
     floatHammer(F,hx,hy,s>0?-.6:-2.5);if(K&&ph>.93)sparkC(mx+s*6,my-6,['#f2800e','#ffc83a','#fff6c0'],8,3+s,10,8)(F,t)}
    if(K)for(let j=0;j<4;j++)for(let i=-3;i<=3;i++)if(hash(i,j,Math.floor(t*6))>.6)F.set(mx+i,my-8+j,MOLT[2])},[LT(0,1.0,0,40,.7,HOT,.2)])]}}},
 {g:'creuset',name:'Grande meule',desc:'Une meule de grès dressée dans son bâti, les pieds dans une auge d’eau. Une lame s’y affûte seule, dans une longue gerbe d’étincelles.',anims:['meule qui tourne','lame qui va et vient','gerbe d’étincelles','eau de l’auge'],
  build(){const[cx,cy]=at(0,1.0,-.15);return{ground:floor(),objs:[slab(square(1.28),0,.08,stone(SLATE,{noise:.08}),{key:-9}),
   slab(rect(-.55,-.22,.55,.22),.08,.36,q=>q.f==='top'?rp(WATER,.5+(hash(q.sx,q.sy,2)-.5)*.4,q.sx,q.sy):stone(DSTONE,{noise:.1})(q),{z:-.15,key:-2}),
   post(-.42,-.15,1.15,WOOD,.06),post(.42,-.15,1.15,WOOD,.06),rack(.85,.75,3),ingotsObj(-.85,.85,IRON,3),
   dyn(4,(F,t)=>{const a=K?t*5:0;pdisk(F,cx,cy,19,(i,j,d)=>{if(d<2.5)return IRON[5];const an=Math.atan2(j,i)-a,s=((an*6/TAU)%1+1)%1;return d>17.5?SAND[i+j<0?6:3]:SAND[(s<.07?3:i+j<-6?6:i+j>8?4:5)]});
    for(let i=-21;i<=21;i++)F.set(cx+i,cy,IRON[4]);
    const u=K?Math.sin(t*2.4)*.5+.5:.5,lx=cx+14+Math.round(u*4),ly=cy-14-Math.round(u*6);for(let k=0;k<16;k++){F.set(lx+k,ly-Math.round(k*.6),SILVER[4]);F.set(lx+k,ly+1-Math.round(k*.6),SILVER[2])}for(let j=-3;j<=3;j++)F.set(lx+16,ly-10+j,IRON[5]);F.set(lx+17,ly-10,LEATHER[2]);
    if(K){for(let k=0;k<18;k++){const p=((t*2.2+hash(k,1,5))%1),ang=-2.6+(hash(k,2,5)-.5)*.7,r=p*34;F.set(Math.round(cx+13+Math.cos(ang)*r),Math.round(cy-13+Math.sin(ang)*r*-.6+p*p*18),MOLT[p<.3?4:p<.6?3:2])}}},[LT(0,1.0,-.1,36,.6,HOT,.25)])]}}},
 {g:'creuset',name:'Presse à emboutir',desc:'Deux colonnes de fer, une vis géante et son volant à bras. Le plateau descend sur la plaque de lingots : elle ressort bombée en bouclier et rejoint la pile.',anims:['volant de la vis','plateau qui descend','plaque emboutie','pile de boucliers'],
  build(){const[px,py]=at(0,.52,0),[tx,ty]=at(0,2.15,0);return{ground:floor(),objs:[oct(SLATE,.1),slab(rect(-.5,-.3,.5,.3),.1,.5,iMat({inlay:bandI(.2,.6,AEC[1],.18,7)}),{key:-2}),
   slab(square(.1),.1,2.1,iMat(),{x:-.62,key:-1.5}),slab(square(.1),.1,2.1,iMat(),{x:.62,key:-1.5}),box(0,0,.78,.16,1.9,2.1,iMat(),{key:2}),
   ingotsObj(-.9,.85,COPPER,3),{key:.85,draw(L){const[a,b]=at(.9,0,.85);for(let k=0;k<3;k++)L.ell(a,b-2-k*3,6,2.2,(x,y,dx,dy)=>rp(COPPER,.6-dx*.3-dy*.3,x,y));return{}}},
   dyn(4,(F,t,S)=>{const per=4,u=K?(t%per)/per:0,down=u<.35?ease(u/.35):u<.5?1:u<.8?1-ease((u-.5)/.3):0,pd=Math.round(down*20),pressed=u>.35&&u<.95;
    for(let j=ty+2;j<ty+2+(py-ty-22)+pd;j++){F.set(tx,j,IRON[(j%3)?4:2]);F.set(tx+1,j,IRON[2])}
    const B=behind(F,S),a=K?down*4:0;for(let k=0;k<4;k++){const an=a+k*Math.PI/2,D=Math.sin(an)>0?F:B,ex=tx+Math.round(Math.cos(an)*14),ey=ty-4+Math.round(Math.sin(an)*4);D.line(tx,ty-4,ex,ey,IRON[5]);D.set(ex,ey,AEC[K?3:1])}
    const yy=py-22+pd;for(let j=0;j<4;j++)for(let i=-13;i<=13;i++)F.set(px+i,yy+j,IRON[j===0?6:j===3?2:4]);
    if(!pressed||!K){for(let i=-7;i<=7;i++){F.set(px+i,py-2,COPPER[5]);F.set(px+i,py-1,COPPER[3])}}else for(let j=-3;j<=0;j++)for(let i=-8;i<=8;i++){if(i*i/64+j*j/9>1)continue;F.set(px+i,py-1+j,COPPER[j===-3?5:i<-3?5:i>4?2:4])}
    if(K&&u>.33&&u<.4)sparkC(px,py-3,['#f2800e','#ffc83a','#fff6c0'],10,9,8,16,per,.06)(F,t-per*.33)},[LT(0,.8,0,34,.6,VIOBLUE)])]}}},
 {g:'creuset',name:'Roue de trempe',desc:'Une grande roue de fer garnie de lames tourne lentement. Les lames sortent rouges du brasier, plongent dans le bassin dans un nuage de vapeur et remontent argentées.',anims:['roue des lames','lames qui refroidissent','vapeur du bassin','brasier'],
  build(){const[cx,cy]=at(0,1.05,-.2),[wx,wy]=at(0,.3,.35);return{ground:floor(),objs:[slab(square(1.28),0,.08,stone(BASALT,{noise:.08}),{key:-9}),
   slab(rect(-.7,-.3,.7,.3),.08,.32,q=>q.f==='top'&&Math.abs(q.x)<.6&&Math.abs(q.z)<.22?rp(WATER,.5+(hash(q.sx,q.sy,2)-.5)*.5,q.sx,q.sy):stone(DSTONE,{noise:.1})(q),{z:.35,key:1}),
   post(-.85,-.2,1.2,WOOD,.07),post(.85,-.2,1.2,WOOD,.07),brazier(-1.02,.9,BASALT,'orange',ORANGE),ingotsObj(1.0,.9,IRON,3),
   dyn(4,(F,t)=>{const a0=K?t*.7:.2,R=20;for(let k=0;k<72;k++){const a=k*TAU/72;F.set(Math.round(cx+Math.cos(a)*R),Math.round(cy+Math.sin(a)*R),IRON[Math.sin(a)<-.2?5:3])}
    for(let i=-24;i<=24;i++)F.set(cx+i,cy,WOOD[3]);F.set(cx,cy,AEC[K?3:1]);
    for(let k=0;k<8;k++){const a=a0+k*TAU/8,ex=cx+Math.cos(a)*R,ey=cy+Math.sin(a)*R;F.line(cx,cy,Math.round(ex),Math.round(ey),IRON[2]);
     const ph=((a%TAU)+TAU)%TAU,hot=ph>Math.PI*1.1&&ph<Math.PI*1.95,C=hot?HOTB:COLDB,ux=Math.cos(a),uy=Math.sin(a);for(let s=0;s<9;s++){F.set(Math.round(ex+ux*s),Math.round(ey+uy*s),C[s>6?0:1]);F.set(Math.round(ex+ux*s-uy),Math.round(ey+uy*s+ux),C[2])}}
    if(K){steamDyn(wx-6,wy-2,20,3)(F,t);steamDyn(wx+6,wy-3,18,7)(F,t)}},[LT(0,.5,.35,30,.6,HOT,.2)])]}}},
 {g:'creuset',name:'Autel de façonnage',desc:'Un autel de basalte aux glyphes d’Aether. Trois lingots s’élèvent, fondent en un ruban de métal, se reforment en lame qui se pose sur le râtelier.',anims:['lingots qui s’élèvent','ruban de métal','lame qui se forme','glyphes'],
  build(){const[ax,ay]=at(0,.62,0);return{ground:floor(),objs:[oct(BASALT,.1,{inlay:ringI(1.02,.035,AEC[0])}),
   slab(rect(-.55,-.32,.55,.32),.1,.52,stone(BASALT,{noise:.1,inlay:bandI(.3,.75,AEC[1],.16,5)}),{key:-2}),slab(rect(-.62,-.38,.62,.38),.52,.6,stone(BASALT,{noise:.06,inlay:ringI(.3,.03,AEC[1])}),{key:-1.9}),
   rack(.85,.8,3),ingotsObj(-.88,.85,COPPER,3),column(-1.0,-.9,.5,BASALT,{flame:'vb',light:VIOBLUE}),column(1.0,-.9,.5,BASALT,{flame:'vb',light:VIOBLUE}),
   dyn(4,(F,t)=>{const per=6,u=K?(t%per)/per:0;const rise=ease(clamp(u/.25)),melt=clamp((u-.3)/.2),form=clamp((u-.5)/.2);
    if(u<.5)for(let k=0;k<3;k++){const x=ax-12+k*9-Math.round(melt*(k-1)*9),y=ay-2-Math.round(rise*(16+k*2))-Math.round(melt*4);if(melt<1)for(let i=0;i<6-Math.round(melt*4);i++){F.set(x+i,y,MOLT[melt>.2?3:1]);F.set(x+i,y-1,melt>.2?MOLT[4]:COPPER[5]);F.set(x+i,y+1,COPPER[2])}}
    if(K&&u>=.4&&u<.7){for(let k=0;k<24;k++){const a=k/24*TAU+t*3,r=6*(1-form)+1;F.set(Math.round(ax+Math.cos(a)*r*1.6),Math.round(ay-22+Math.sin(a)*r),MOLT[k%3+2])}}
    if(K&&u>=.6){const p=clamp((u-.75)/.2),x=Math.round(ax+p*38),y=Math.round(ay-12-(1-form)*4+p*-6-Math.sin(p*Math.PI)*10);swordV(F,x,y,20,u<.75?HOTB:COLDB)}
    if(K&&u<.55)motes(ax,ay-2,14,24,['#5a5cff','#9aa0ff','#e0e4ff'],6,4)(F,t)},[LT(0,.9,0,44,.75,VIOBLUE,.12)])]}}},
];
