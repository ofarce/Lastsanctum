// ================= ÉTABLI D'EXO (intro de la capsule, 2026-11-22, planches/intro-capsule-planche.html) =================
// Assemblé par tools/batiments-16bits/build_etabli.py : moteur et outils des bâtiments v4 + ce fichier.
// L'Établi fabrique les mods de l'Exilé d'après les plans retrouvés (premier : Analyse). Service d'Aether, mais
// matériel tyrien : ardoise et glyphes cyan, comme le Coffre Antique et la capsule. K = 1 au travail, 0 au repos.

const CYR=[CYD,ci('#1f9fb8'),ci('#5ce8ff'),ci('#c8fbff')];          // cyan tyrien, mat
const CYE=[E('#12596b'),E('#1f9fb8'),E('#5ce8ff'),E('#c8fbff')];    // cyan tyrien, lumineux
const CYANL=[.55,1.2,1.4];
// gros module flottant : cadre d'argent, plaque d'ardoise, lentille cyan et halo au sol (y0 : sol sous le module)
function bigModule(F,x,y,lit,y0){x=Math.round(x);y=Math.round(y);if(y0!=null)for(let i=-6;i<=6;i++)if(Math.abs(i)<5||lit)F.set(x+i,y0,lit?CYE[0]:SLATE[1]);
 for(let j=-5;j<=5;j++)for(let i=-8;i<=8;i++){const e=Math.abs(i)+Math.abs(j)*1.3;if(e>10.5)continue;const rim=e>8.6;F.set(x+i,y+j,rim?SILVER[j<0?4:i<0?3:1]:SLATE[j<-1?4:j<2?3:2])}
 pdisk(F,x,y,2.6,(i,j,d)=>d<1?(lit?CYE[3]:CYR[2]):d<2?(lit?CYE[2]:CYR[1]):(lit?CYE[1]:CYR[0]));for(const sx of[-6,6])F.set(x+sx,y,lit?CYE[2]:CYR[0])}
// module d'exo vu de 3/4 : plaque arrondie w × h, face avant, lentille centrale (lit : allumée)
function moduleS(F,x,y,w,h,lit,R=SILVER){x=Math.round(x);y=Math.round(y);
 for(let j=0;j<h;j++)for(let i=0;i<w;i++){if((i===0||i===w-1)&&(j===0||j===h-1))continue;F.set(x+i,y+j,R[j===0?4:j<2?3:i===0?3:2])}
 for(let i=1;i<w-1;i++)F.set(x+i,y+h,R[0]);
 const cx=x+Math.floor(w/2),cy=y+Math.floor(h/2);F.set(cx,cy,lit?CYE[3]:CYR[1]);F.set(cx-1,cy,lit?CYE[2]:CYR[0]);F.set(cx+1,cy,lit?CYE[2]:CYR[0]);F.set(cx,cy-1,lit?CYE[2]:CYR[0])}
// trame de plan au sol d'un plateau : lignes cyan, balayage en u (0..1, -1 : aucun)
function planGrid(F,x0,y0,w,h,u){for(let j=0;j<=h;j++)for(let i=0;i<=w;i++){const edge=i===0||j===0||i===w||j===h,grid=i%4===0||j%3===0;if(!edge&&!grid)continue;
 const near=u>=0&&Math.abs(i/w-u)<.08;F.set(x0+i,y0+j,near?CYE[3]:edge?CYE[1]:CYE[0])}}
// jarre d'ichor posée au sol
function ichorPot(x,z){return{key:z,draw(L,S){const[a,b]=P3(x,0,z),A=Math.round(a),B=Math.round(b);S.shadowEll(A,B+1,5,2,.6);
 for(let j=-9;j<=0;j++){const w=j<-7?2:j<-5?3:4;for(let i=-w;i<=w;i++)L.set(A+i,B+j,j<-7?LEATHER[2]:ci(i<-1?'#a8323e':i>2?'#4a1018':'#8a1f2c'))}L.set(A-2,B-5,ci('#d85a5a'));return{}}}}
// petite fiole d'ichor
function ichorVial(F,x,y){for(let j=0;j<5;j++)for(let i=0;i<3;i++)F.set(x+i,y+j,j<1?SILVER[3]:ci(j<3?'#8a1f2c':'#4a1018'));F.set(x+1,y-1,LEATHER[2])}

const GROUPS=[
 {id:'etabli',name:'Établi d’exo',note:'Nouveau bâtiment, service d’Aether, débloqué par la Scierie. On y assemble les modules d’exo de l’Exilé d’après les plans retrouvés (le premier : Analyse, 50 fibres, 50 planches, 5 ichor). Matériel tyrien : ardoise et glyphes cyan, comme le Coffre Antique et la capsule. L’animation montre un module qui prend forme.'}];

const ITEMS=[
 {g:'etabli',name:'Établi à plan lumineux',desc:'Un plateau d’ardoise sur pieds où le plan tyrien s’allume en trame cyan, sous une potence à lentille. Le balayage parcourt le plan ; planches, fibre et ichor montent du bord et se fondent en un module qui flotte sous la lentille.',anims:['trame du plan','balayage','pièces qui convergent','module qui s’allume'],
  build(){const[tx,ty]=at(0,.78,.05),[hx,hy]=at(0,2.05,-.05);return{ground:floor(),objs:[oct(SLATE,.1,{inlay:ringI(1.04,.035,CYD)}),
   post(-.62,-.28,.7,IRON,.06,.1),post(.62,-.28,.7,IRON,.06,.1),post(-.62,.32,.7,IRON,.06,.1),post(.62,.32,.7,IRON,.06,.1),
   slab(rect(-.78,-.4,.78,.42),.7,.82,stone(SLATE,{noise:.06,inlay:bandI(.1,.9,CYD,.14,3)}),{key:.1}),
   post(-.95,-.55,2.2,IRON,.07),box(-.45,-.55,.55,.05,2.12,2.24,iMat(),{key:-.5}),
   planks(.92,.92,3,.36),...logs(-.92,.85,2,.3),
   dyn(4,(F,t)=>{const per=6,u=K?(t%per)/per:0;planGrid(F,tx-22,ty-9,44,12,K?u:-1);
    for(let j=0;j<4;j++)F.set(hx,hy+j,IRON[4]);pdisk(F,hx,hy+6,3,(i,j,d)=>d>2.2?SILVER[3]:K?CYE[2]:CYR[1]);
    const gather=clamp((u-.2)/.45),fy=ty-22-Math.round(Math.sin(t*2)*1.5);
    if(K&&u>.55)for(let j=hy+9;j<fy-6;j+=2)F.set(hx,j,CYE[1]);
    if(K&&u<.7)for(let k=0;k<3;k++){const sx=tx-30+k*30,sy=ty-2,x=Math.round(sx+(tx-sx)*ease(gather)),y=Math.round(sy+(fy-sy)*ease(gather));
     if(k===0){for(let i=0;i<8;i++){F.set(x-4+i,y,WOOD[5]);F.set(x-4+i,y+1,WOOD[3])}}else if(k===1)curl(F,x,y,t);else ichorVial(F,x-1,y-2)}
    bigModule(F,tx,fy,K&&u>.55,ty-8);if(K&&u>.62&&u<.78)sparkC(tx,fy,['#1f9fb8','#5ce8ff','#c8fbff'],12,7,12,12)(F,t)},[LT(0,1.2,0,44,.75,CYANL,.12)])]}}},
 {g:'etabli',name:'Gabarit d’exo',desc:'Une armature d’exosquelette en argent dressée sur un socle d’ardoise, comme un mannequin de métal. Deux outils en lévitation y sertissent les modules ; les six logements du dos s’allument l’un après l’autre.',anims:['outils qui sertissent','logements qui s’allument','étincelles cyan','armature'],
  build(){const[mx,my]=at(0,1.45,0);return{ground:floor(),objs:[oct(BASALT,.12,{inlay:ringI(1.04,.04,CYD)}),slab(circle(.46),.12,.42,stone(SLATE,{noise:.08,inlay:bandI(.2,.8,CYD,.2,5)}),{key:-2}),
   ingotsObj(-.92,.85,IRON,2),planks(.92,.92,3,.32),crate(.98,-.85,.16),
   dyn(4,(F,t)=>{const per=4.8,u=K?(t%per)/per:1;
    // jambes, bassin, colonne, épaules, casque
    for(const s of[-1,1]){F.line(mx+s*4,my+8,mx+s*6,my+24,SILVER[2]);F.line(mx+s*5,my+8,mx+s*7,my+24,SILVER[3]);F.set(mx+s*7,my+25,SILVER[1])}
    for(let i=-6;i<=6;i++){F.set(mx+i,my+7,SILVER[3]);F.set(mx+i,my+8,SILVER[1])}
    for(let j=-14;j<=7;j++){F.set(mx,my+j,SILVER[4]);F.set(mx+1,my+j,SILVER[2])}
    for(let i=-13;i<=14;i++){F.set(mx+i,my-14,SILVER[i<0?4:3]);F.set(mx+i,my-13,SILVER[1])}
    for(let r=0;r<4;r++)for(let i=-10+r*2;i<=11-r*2;i++)F.set(mx+i,my-9+r*4,SILVER[r%2?2:3]);
    for(const s of[-1,1]){F.line(mx+s*13,my-14,mx+s*16,my+2,SILVER[3]);F.line(mx+s*16,my+2,mx+s*14,my+12,SILVER[2]);pdisk(F,mx+s*14,my-15,2,(i,j,d)=>SILVER[j<0?4:2])}
    pdisk(F,mx,my-20,4,(i,j,d)=>d>3.2?SILVER[3]:j<0?SLATE[4]:SLATE[2]);for(let i=-2;i<=2;i++)F.set(mx+i,my-20,K?CYE[2]:CYR[1]);
    for(let k=0;k<6;k++){const sx=mx-8+(k%2)*11,sy=my-11+Math.floor(k/2)*5,on=u>(k+1)/7;for(let i=0;i<5;i++){F.set(sx+i,sy,on?CYE[k===Math.floor(u*7)-1&&K?3:2]:CYR[0]);F.set(sx+i,sy+1,on?CYE[0]:SLATE[0])}}
    if(K)for(const s of[-1,1]){const ph=(t*1.6+(s>0?.5:0))%1,lift=ph<.7?Math.sin(ph/.7*Math.PI/2):1-(ph-.7)/.3,hx=mx+s*(20+Math.round(lift*6)),hy=my-10-Math.round(lift*8);
     floatHammer(F,hx,hy,s>0?-.6:-2.5,SILVER);if(ph>.94)sparkC(mx+s*9,my-8,['#1f9fb8','#5ce8ff','#c8fbff'],8,3+s,10,8)(F,t)}},[LT(0,1.4,0,42,.7,CYANL,.12)])]}}},
 {g:'etabli',name:'Banc d’optique',desc:'Un long rail d’ardoise sur tréteaux porte trois lentilles cerclées d’argent. Un faisceau cyan part de l’émetteur, se resserre à chaque lentille et vient graver le module posé au bout, qui tourne sur son support.',anims:['faisceau qui pulse','lentilles','module qui tourne','émetteur'],
  build(){const Y=1.05,[ax,ay]=at(-.85,Y,0),[bx,by]=at(.9,Y,0);return{ground:floor(),objs:[slab(square(1.28),0,.08,stone(SLATE,{noise:.08}),{key:-9}),
   post(-.8,-.12,.85,IRON,.06,.08),post(.8,-.12,.85,IRON,.06,.08),post(-.8,.12,.85,IRON,.06,.08),post(.8,.12,.85,IRON,.06,.08),
   box(0,0,1.05,.17,.85,.98,stone(SLATE,{noise:.06,inlay:bandI(.1,.9,CYD,.14,4)}),{key:.2}),
   crate(-.95,.85,.18),planks(.9,.92,3,.3),...logs(.95,-.85,2,.26),
   dyn(4,(F,t)=>{const pulse=K?.5+.5*Math.sin(t*6):0;
    pdisk(F,ax,ay-6,5,(i,j,d)=>d>4.2?IRON[5]:j<-1?IRON[4]:IRON[2]);pdisk(F,ax+3,ay-6,1.6,()=>K?CYE[3]:CYR[1]);for(let j=0;j<6;j++)F.set(ax,ay-1+j,IRON[3]);
    for(const lx of[-.4,.05,.5]){const[px,py]=at(lx,Y,0);for(let j=0;j<6;j++)F.set(px,py-1+j,IRON[4]);for(let k=0;k<28;k++){const a=k*TAU/28;F.set(Math.round(px+Math.cos(a)*3),Math.round(py-8+Math.sin(a)*7),Math.cos(a)<0?SILVER[4]:SILVER[2])}
     for(let j=-5;j<=5;j++)F.set(px,py-8+j,K?(Math.abs(j)<2?CYE[2]:CYE[0]):CYR[0])}
    if(K)for(let x=ax+6;x<bx-7;x++){F.set(x,ay-6,(x+Math.floor(t*12))%4?CYE[2]:CYE[3]);if(pulse>.4)F.set(x,ay-7,CYE[0])}
    for(let j=0;j<5;j++)F.set(bx,by-1+j,IRON[4]);const ang=K?t*2:0,cw=Math.max(2,Math.round(Math.abs(Math.cos(ang))*12));
    for(let j=-5;j<=5;j++)for(let i=-cw;i<=cw;i++){const rim=Math.abs(i)===cw||Math.abs(j)===5;F.set(bx+i,by-8+j,rim?SILVER[3]:SLATE[j<0?4:2])}
    if(cw>3)pdisk(F,bx,by-8,2,()=>K&&pulse>.3?CYE[3]:CYR[1]);if(K&&pulse>.8)sparkC(bx-cw,by-8,['#1f9fb8','#5ce8ff','#c8fbff'],6,9,6,6)(F,t)},[LT(0,1.1,0,40,.65,CYANL,.15)])]}}},
 {g:'etabli',name:'Armoire à modules',desc:'Une haute armoire d’ardoise aux six logements, à côté d’un plateau de travail. Un bras articulé va chercher un logement vide, y dépose le module fini et revient au plateau.',anims:['bras articulé','module transporté','logements allumés','glyphes de l’armoire'],
  build(){const[cx,cy]=at(-.5,2.2,-.45),[px,py]=at(.45,.62,.25),[jx,jy]=at(.05,1.9,-.05);return{ground:floor(),objs:[oct(SLATE,.1),
   box(-.5,-.45,.46,.28,.1,2.2,stone(SLATE,{noise:.06,inlay:bandI(.05,.97,CYD,.2,9)}),{key:-1.5}),box(-.5,-.45,.5,.32,2.2,2.32,iMat(),{key:-1.4}),
   slab(rect(.02,-.08,.88,.58),.1,.62,stone(SLATE,{noise:.08}),{key:.25}),post(.05,-.05,1.9,IRON,.07),planks(-.95,.92,3,.3),ichorPot(.98,-.85),
   dyn(4,(F,t)=>{const per=5,u=K?(t%per)/per:0,full=Math.floor(u*6);
    for(let k=0;k<6;k++){const sx=cx-10+(k%2)*11,sy=cy+5+Math.floor(k/2)*11;for(let j=0;j<8;j++)for(let i=0;i<9;i++)F.set(sx+i,sy+j,j===0||i===0?SLATE[0]:SLATE[1]);
     if(k<full||!K){moduleS(F,sx+1,sy+1,7,6,K)}}
    const go=u<.5?ease(u/.5):1-ease((u-.5)/.5),tx=Math.round(px+(cx-px)*go),ty=Math.round(py-10+(cy+12-py)*go),ex=Math.round((jx+tx)/2+6),ey=Math.round(Math.min(jy,ty)-8);
    thick(F,jx,jy,ex,ey,IRON[5],IRON[3]);thick(F,ex,ey,tx,ty-5,IRON[5],IRON[3]);pdisk(F,ex,ey,1.5,()=>CYE[K?2:0]);pdisk(F,jx,jy,2,()=>SILVER[3]);
    if(K&&u<.5)moduleS(F,tx-4,ty-4,9,6,true);planGrid(F,px-14,py-5,28,8,K?(t*.5)%1:-1)},[LT(-.3,1.4,-.2,44,.7,CYANL,.1)])]}}},
 {g:'etabli',name:'Reliquaire-établi',desc:'Le cousin du Coffre Antique : un coffre d’ardoise ouvert, mêmes glyphes et même œil, dont le grand couvercle relevé sert de pupitre. Au-dessus, le module du plan tourne en fil de lumière, puis se matérialise.',anims:['module en fil de lumière','matérialisation','œil du couvercle','glyphes du coffre'],
  build(){const[cx,cy]=at(0,.72,.1),[lx,ly]=at(0,1.75,-.38);return{ground:floor(),objs:[oct(SLATE,.1,{inlay:ringI(1.04,.035,CYD)}),
   box(0,.1,.66,.36,.1,.72,stone(SLATE,{noise:.06,inlay:bandI(.35,.7,CYD,.12,2)}),{key:-1}),
   box(0,-.34,.66,.06,.72,2.0,stone(SLATE,{noise:.05,inlay:bandI(.45,.85,CYD,.2,6)}),{key:-1.2}),
   planks(.95,.92,3,.32),...logs(-.95,.85,2,.28),ichorPot(-1.0,-.85),
   dyn(4,(F,t)=>{const per=6,u=K?(t%per)/per:0,a=t*1.4,mat=clamp((u-.55)/.25);
    for(let j=-3;j<=3;j++)for(let i=-5;i<=5;i++)if(i*i/25+j*j/9<=1)F.set(lx+i,ly+j,i*i/25+j*j/9<.3?(K?CYE[3]:CYR[2]):i*i/25+j*j/9<.7?(K?CYE[1]:CYR[1]):CYR[0]);
    const my=cy-24-Math.round(Math.sin(t*2)*1.5);
    if(K&&mat<1){const c=Math.cos(a),s=Math.sin(a);const P=[[-9,-4],[9,-4],[9,4],[-9,4]].map(([x,z])=>[Math.round(cx+x*c-z*s*.4),Math.round(my+z*.6+x*s*.3)]);
     for(let k=0;k<4;k++){const[a0,b0]=P[k],[a1,b1]=P[(k+1)%4];F.line(a0,b0,a1,b1,CYE[2]);F.line(a0,b0-6,a1,b1-6,CYE[1]);F.line(a0,b0,a0,b0-6,CYE[1])}}
    if(!K||mat>0)bigModule(F,cx,my-3,K,cy-6);if(K&&mat>0&&mat<.4)sparkC(cx,my,['#1f9fb8','#5ce8ff','#c8fbff'],14,11,10,14)(F,t)},[LT(0,1.3,0,46,.75,CYANL,.14)])]}}},
];
