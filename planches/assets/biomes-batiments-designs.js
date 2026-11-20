// ================= BIOMES 1 ET 2 : Église des Oublieux, École de magie cristallisée =================
// Assemblé par tools/biomes-batiments/build.py : moteur de creuset-planches.js + outils de batiments-v2-designs.js
// + préambule de batiments-v3-designs.js (avant GROUPS) + ce fichier. K = 1 au travail, 0 au repos.

const ASH=R_(['#1c1b22','#2a2832','#3a3844','#4e4b58','#64606e','#7e7a88','#9a96a4']);
const LIM=['#2a6a52','#58b890','#a8e8c8','#eafff4'].map(E);
const ash=o=>stone(ASH,{noise:.1,...o});
// cristal : prisme hexagonal + pointe, rampe émissive à 4 tons, lumière en haut à gauche
const cryst=R=>q=>q.f==='top'?R[3]:R[q.b>.62?2:q.b>.48?1:0];
function crystal(x,z,y0,h,r,R,rot=0){return[slab(poly(6,r,rot),y0,y0+h*.68,cryst(R),{x,z,taper:[1,.86],mask:true,shadow:.7}),slab(poly(6,r*.86,rot),y0+h*.68,y0+h,cryst(R),{x,z,taper:[1,.04],mask:true})]}
function glint(F,x,y,C,big){F.set(x,y,C[3]);for(const[i,j]of[[-1,0],[1,0],[0,-1],[0,1]])F.set(x+i,y+j,C[2]);if(big)for(const[i,j]of[[-2,0],[2,0],[0,-2],[0,2]])F.set(x+i,y+j,C[1])}
function arcDots(F,a,b,t,C,lift=10){const n=Math.max(8,Math.round(Math.hypot(b[0]-a[0],b[1]-a[1])/2));for(let k=0;k<=n;k++){if((k+Math.floor(t*10))%3===0)continue;const u=k/n;F.set(Math.round(a[0]+(b[0]-a[0])*u),Math.round(a[1]+(b[1]-a[1])*u-Math.sin(u*Math.PI)*lift),C[k%2?3:2])}}
// lanterne de quartz au bout d'une chaîne, qui se balance
function swingLantern(F,x,y,len,t,ph=0){const s=Math.round(Math.sin(t*1.6+ph)*2);F.line(x,y,x+s,y+len,IRON[3]);const X=x+s,Y=y+len;F.rect(X-1,Y,3,4,FWH[2]);F.set(X,Y+1,FWH[3]);F.rect(X-1,Y,3,1,IRON[4]);F.rect(X-1,Y+4,3,1,IRON[3])}
// linceul suspendu
function shroud(F,x,y,w,h,t,s=0){for(let j=0;j<h;j++){const dx=Math.round(Math.sin(t*1.8+j*.4+s)*1.3*(j/h));for(let i=0;i<w;i++)F.set(x+i+dx,y+j,CLOTH[i===0?3:i===w-1?1:(j%5===4?1:2)])}}
// trouvailles : petits objets ramassés
function trove(F,x,y,n,seed=1){const C=[COPPER[4],SILVER[3],BONE[3],REDC[3],VERDI[4],WOOD[4]];for(let k=0;k<n;k++){const dx=Math.round((hash(k,1,seed)-.5)*12),dy=-Math.round(hash(k,2,seed)*3)-Math.floor(k/3)*2,c=C[k%C.length];F.rect(x+dx,y+dy-2,3,2,c);F.set(x+dx,y+dy-3,sh(c,.35))}}

const GROUPS=[
 {id:'eglise',name:'Église des Oublieux',note:'Pierre de cendre, linceuls, lanternes de quartz blanc. Aucun or : ce n’est pas le Credo. « Au travail » = la nuit, quand l’Oublieux rapporte ses trouvailles.'},
 {id:'ecole',name:'École de magie cristallisée',note:'Marbre gris et cristal. Trois couleurs, une par mage : vert de Medeina (Guérisseuse), orange d’Indra (Chantre), bleu-violet d’Aether (Envoûteur).'}];

const ITEMS=[
// ======================= ÉGLISE DES OUBLIEUX =======================
 {g:'eglise',name:'Campanile sans cloche',desc:'Une tour étroite dont la chambre des cloches est vide : une lanterne de quartz y pend à la place et se balance. Au pied, la table où l’Oublieux dépose ce qu’il rapporte.',anims:['lanterne qui se balance','trouvailles sur la table','linceul au vent'],
  build(){const[lx,ly]=at(0,2.6,.28),[tx,ty]=at(0,.28,.98),[sx,sy]=at(-.34,1.55,.34);return{ground:floor(),objs:[disc(ASH,1.28,.1),slab(square(.46),.1,.3,ash(),{key:-8}),
   slab(square(.36),.3,2.0,ash({courses:.22,joint:.5,inlay:archI(0,.13,.3,.95,ASH[0])}),{key:-3,taper:[1,.88],mask:true}),
   box(-.24,0,.07,.27,2.0,2.62,ash(),{key:-2}),box(.24,0,.07,.27,2.0,2.62,ash(),{key:-2}),
   roof('pyr',0,0,.44,.4,2.62,.42,shingle(SLATE),{key:6,noShadow:1}),
   box(0,.98,.5,.18,0,.28,woodMat(),{}),
   column(-1.02,.85,.45,ASH,{flame:'white',light:WHITEC}),column(1.02,.85,.45,ASH,{flame:'white',light:WHITEC}),
   dyn(7,(F,t)=>{swingLantern(F,lx,ly,7,t);shroud(F,sx,sy,4,15,t,1);if(K)trove(F,tx,ty,7,3);else trove(F,tx,ty,2,3)},[LT(0,2.3,.28,48,.9,WHITEC)])]}}},
 {g:'eglise',name:'Cairn des trouvailles',desc:'Un cairn de pierres plates empilées à la main. Une lanterne brûle dans la niche, et chaque objet rapporté est glissé entre deux pierres : le cairn scintille quand la nuit a été bonne.',anims:['veilleuse dans la niche','éclats entre les pierres','linceuls aux piquets'],
  build(){const st=o=>stone(ASH,{noise:.16,moss:.14,...o}),[nx,ny]=at(0,.47,.86),SP=[[-.7,.3,.55],[.62,.3,.6],[-.4,.68,.45],[.45,.66,.42],[-.2,1.02,.3],[.26,1.0,.3],[0,1.36,.22],[.7,.22,.75],[-.78,.2,.7]],P1=at(-1.08,1.0,.62),P2=at(1.08,1.0,.62);
   return{ground:floor(),objs:[disc(MSTONE,1.26,.06,{moss:.3}),slab(poly(7,1.02,.2),.06,.4,st({inlay:archI(0,.15,.12,.72,FWH[0])}),{key:-6}),slab(poly(6,.84,.5),.4,.75,st(),{key:-5}),slab(poly(7,.64,.1),.75,1.1,st(),{key:-4}),
   slab(poly(5,.44,.4),1.1,1.45,st(),{key:-3,mask:true}),slab(poly(6,.25,.2),1.45,1.78,st(),{key:-2,taper:[1,.7],mask:true}),
   post(-1.08,.62,1.05,WOOD,.04),post(1.08,.62,1.05,WOOD,.04),bones(.72,1.12,3),
   dyn(7,(F,t)=>{flameDyn(nx,ny,'white',.9)(F,t);shroud(F,P1[0]+1,P1[1]+1,4,13,t,0);shroud(F,P2[0]-4,P2[1]+1,4,11,t,2);
    const n=K?SP.length:3;for(let k=0;k<n;k++){const[x,y]=at(...SP[k]);if(Math.sin(t*2.2+k*1.9)>-.3){F.set(x,y,[COPPER[5],SILVER[4],FWH[3]][k%3]);if(Math.sin(t*2.2+k*1.9)>.8)glint(F,x,y,FWH)}}},[LT(0,.5,.9,40,.85,WHITEC)])]}}},
 {g:'eglise',name:'Porte des Oublieux',desc:'Une porte funéraire sans mur. Des linceuls ferment le passage ; la nuit ils s’écartent sur une lueur blanche, et c’est par là que l’Oublieux sort et revient.',anims:['linceuls qui ondulent','passage qui s’ouvre','deux lanternes'],
  build(){const[cx,cy]=at(0,1.78,.06),[bx,by]=at(0,.14,.06),h=by-cy;return{ground:floor(),objs:[slab(rect(-1.28,-.85,1.28,1.1),0,.1,ash({noise:.06}),{key:-9}),slab(rect(-1.05,-.25,1.05,.7),.1,.18,ash({noise:.05}),{key:-8}),
   box(-.82,0,.2,.28,.1,1.8,ash({courses:.2,joint:.45}),{key:-1,mask:true}),box(.82,0,.2,.28,.1,1.8,ash({courses:.2,joint:.45}),{key:-1,mask:true}),
   box(0,0,1.08,.32,1.8,2.02,ash(),{key:5}),roof('gz',0,0,1.16,.38,2.02,.38,shingle(SLATE,{axis:'z',cw:.12,side:q=>rp(ASH,.7+(q.lip?.15:0),q.sx,q.sy)}),{key:6,noShadow:1}),
   lanternHang(-.82,1.45,.3),lanternHang(.82,1.45,.3),bones(-1.02,.95,5),
   dyn(4,(F,t)=>{const open=K?.5+.5*Math.sin(t*TAU/8):0,gap=Math.round(open*5);
    if(gap>0)for(let j=4;j<h;j++)for(let i=-gap;i<=gap;i++)F.set(cx+i,cy+j,FWH[Math.abs(i)<gap-1?(j%4?2:3):1]);
    for(let k=0;k<6;k++){const side=k<3?-1:1,idx=k<3?k:5-k,x0=cx+side*(3+idx*4+gap)-(side>0?3:0),s=k*1.3;for(let j=0;j<h;j++){const dx=Math.round(Math.sin(t*1.7+j*.3+s)*1.4*(j/h));for(let i=0;i<4;i++)F.set(x0+i+dx,cy+j,CLOTH[i===0?3:i===3?1:(j%6===5?1:2)])}}
    if(K&&open>.6)motes(cx,by,4,22,['#a8b0c4','#dfe4f0','#ffffff'],5,4)(F,t)},[LT(0,.9,.2,46,.75,WHITEC)])]}}},
 {g:'eglise',name:'Hémicycle des veilleuses',desc:'Cinq stèles sans nom en demi-cercle, une niche dans chacune. Les veilleuses s’allument une à une au fil de la nuit, autour de la pierre où s’entassent les trouvailles.',anims:['veilleuses en séquence','tas de trouvailles','braises blanches'],
  build(){const A=[0,1,2,3,4].map(k=>Math.PI+(k+.5)/5*Math.PI),objs=[disc(ASH,1.3,.1,{inlay:ringI(.78,.04,ASH[6])}),slab(circle(.44),.1,.34,ash({courses:.12,joint:.35}),{key:-1})],N=[],[px,py]=at(0,.34,.1);
   A.forEach((a,k)=>{const x=Math.cos(a)*1.02,z=Math.sin(a)*.82-.05,hh=1.0+.28*Math.sin((k+.5)/5*Math.PI);objs.push(box(x,z,.15,.09,.1,hh,ash({inlay:rectI(0,.07,hh-.42,hh-.16,ASH[0])}),{mask:true}),slab(rect(-.19,-.12,.19,.12),hh,hh+.07,ash(),{x,z}));N.push(at(x,hh-.36,z+.09))});
   objs.push(bones(.85,.95,7),dyn(7,(F,t)=>{const lit=K?1+Math.floor(t/1.5)%5:1;N.forEach(([x,y],k)=>{if(k<lit){flameDyn(x,y,'white',.7)(F,t+k)}else F.set(x,y,ASH[5])});trove(F,px,py,K?3+lit:2,5)},
    N.map(([x,y])=>({x,y,r:22,i:.5,c:WHITEC,fl:.1}))));return{ground:floor(),objs}}},
 {g:'eglise',name:'Puits des noms perdus',desc:'Un puits sec à margelle de pierre et son treuil. Le panier descend vide et remonte chargé : ce que la montagne avait gardé revient à la lumière.',anims:['panier au treuil','lanterne sous l’auvent','trouvailles au bord'],
  build(){const[ax,ay]=at(0,1.7,.02),[lx,ly]=at(.42,1.7,.06),[tx,ty]=at(-.92,0,.9);return{ground:floor(),objs:[disc(ASH,1.26,.08),
   slab(circle(.64),.08,.5,ash({courses:.14,joint:.4,inlay:q=>q.f==='top'&&q.rad<.47?ASH[0]:null}),{key:-3}),
   post(-.7,0,1.72,WOOD,.055),post(.7,0,1.72,WOOD,.055),box(0,0,.8,.05,1.7,1.8,woodMat(),{key:4}),
   roof('gx',0,0,.92,.36,1.8,.32,shingle(SLATE),{key:6,noShadow:1}),crate(.98,.82),bones(.55,1.15,9),
   dyn(5,(F,t)=>{if(K)hoistDyn(ax,ay,27,5,{sway:1})(F,t);else hoistDyn(ax,ay,27,5,{})(F,2.3);swingLantern(F,lx,ly,3,t,1);trove(F,tx,ty,K?6:2,8)},[LT(.42,1.5,.06,44,.85,WHITEC)])]}}},

// ======================= ÉCOLE DE MAGIE CRISTALLISÉE =======================
 {g:'ecole',name:'Triade de cristaux',desc:'Trois grands cristaux jaillis d’un socle octogonal, un par discipline. Ils s’éclairent tour à tour et des arcs de lumière passent de l’un à l’autre pendant les leçons.',anims:['cristaux en séquence','arcs entre les pointes','poussière de quartz'],
  build(){const TIP=[[at(-.55,1.76,.25),FGR],[at(.55,1.96,.25),FOR],[at(0,2.56,-.35),FVB]];return{ground:floor(),objs:[oct(MARBLE,.12),slab(poly(8,.92,Math.PI/8),.12,.26,mMat(),{key:-8}),
   ...crystal(0,-.35,.26,2.3,.25,FVB),...crystal(-.55,.25,.26,1.5,.2,FGR,.3),...crystal(.55,.25,.26,1.7,.2,FOR,.15),
   ...crystal(-.12,.62,.26,.55,.09,FWH),...crystal(.26,.68,.26,.4,.07,FWH,.4),...crystal(-.88,-.2,.12,.5,.09,FWH,.2),
   dyn(7,(F,t)=>{const k=Math.floor(t/1.2)%3;TIP.forEach(([p,C],i)=>{if(K?i===k:i===0&&Math.sin(t*1.5)>0)glint(F,p[0],p[1],C,1);else F.set(p[0],p[1],C[3])});
    if(K){const a=TIP[k],b=TIP[(k+1)%3];arcDots(F,a[0],b[0],t,a[1]);motes(TIP[2][0][0],TIP[2][0][1]+30,14,34,['#a8b0c4','#dfe4f0','#ffffff'],6,2)(F,t)}},
    [LT(-.55,1.3,.25,36,.7,GREEN),LT(.55,1.4,.25,36,.7,ORANGE),LT(0,1.9,-.35,44,.8,VIOBLUE)])]}}},
 {g:'ecole',name:'Géode ouverte',desc:'Une géode de basalte fendue par le devant. L’intérieur est tapissé de cristaux aux trois couleurs qui scintillent ; les élèves étudient au pupitre, face à l’ouverture.',anims:['scintillement intérieur','lueur qui respire','pupitre'],
  build(){const geo=q=>{if(q.f!=='side'||q.n[1]<.25)return null;const dx=q.x/.62,dy=(q.y-.58)/.45,r=dx*dx+dy*dy;if(r>1)return null;if(r>.8)return FWH[r>.92?1:2];
    const R=q.x<-.16?FGR:q.x>.16?FOR:FVB,k=hash(Math.floor(q.sx/2),Math.floor(q.sy/3),4);return R[k>.72?3:k>.4?2:k>.15?1:0]},[gx,gy]=at(0,.58,.9);
   return{ground:floor(),objs:[disc(BASALT,1.26,.08),slab(circle(.96),.08,1.05,stone(BASALT,{noise:.18,inlay:geo}),{key:-3,taper:[1,.86],mask:true}),
   roof('dome',0,0,.82,.82,1.05,.55,q=>rp(BASALT,q.f==='top'?q.b+(vnoise(q.x*4,q.z*4,3)-.5)*.2:.4,q.sx,q.sy),{key:-2,noShadow:1}),
   ...crystal(-1.0,.55,.08,.6,.1,FGR,.2),...crystal(1.02,.5,.08,.7,.11,FOR),...crystal(.2,-.2,1.5,.5,.09,FVB),lectern(0,1.12),
   dyn(7,(F,t)=>{const n=K?9:3;for(let k=0;k<n;k++){const ph=(t*.9+hash(k,1,6)*5)%1.6;if(ph<.35){const x=gx+Math.round((hash(k,2,6)-.5)*20),y=gy+Math.round((hash(k,3,6)-.5)*15);glint(F,x,y,[FGR,FVB,FOR][k%3],ph<.15)}}
    if(K)motes(gx,gy+4,8,20,['#a8b0c4','#dfe4f0','#ffffff'],4,7)(F,t)},[LT(-.3,.6,.9,34,.7,GREEN),LT(.3,.6,.9,34,.7,ORANGE),LT(0,.7,.9,40,.6,VIOBLUE)])]}}},
 {g:'ecole',name:'Orgue de cristal',desc:'Sept prismes de quartz rangés comme des tuyaux d’orgue, du plus court au plus long puis retour. Le maître joue au pupitre et les prismes s’allument en gamme.',anims:['gamme lumineuse','prisme qui vibre','pupitre de jeu'],
  build(){const RS=[FGR,FGR,FWH,FVB,FWH,FOR,FOR],objs=[slab(rect(-1.26,-.6,1.26,1.0),0,.12,mMat(),{key:-9}),slab(rect(-1.12,-.5,1.12,.15),.12,.3,mMat(),{key:-8}),box(0,.68,.5,.13,.12,.42,woodMat(),{}),box(0,.62,.42,.05,.42,.5,mMat(),{})],T_=[];
   for(let k=0;k<7;k++){const x=-.9+k*.3,hh=.95+1.2*Math.sin(Math.PI*(k+.5)/7);objs.push(...crystal(x,-.15,.3,hh,.125,RS[k],k*.2));T_.push([at(x,.3+hh,-.15),at(x,.36,-.03),RS[k]])}
   objs.push(dyn(7,(F,t)=>{const seq=[0,1,2,3,4,5,6,5,4,3,2,1],k=K?seq[Math.floor(t*3)%12]:seq[Math.floor(t*.5)%12];T_.forEach(([tp,bs,C],i)=>{if(i===k){glint(F,tp[0],tp[1],C,1);for(let y=tp[1]+3;y<bs[1];y+=2)F.set(tp[0],y,C[3])}});
    if(K){const[tp,,C]=T_[k];for(let j=0;j<3;j++){const p=((t*1.5+j/3)%1);F.set(tp[0]+Math.round(Math.sin(p*9+j)*3),tp[1]-3-Math.round(p*12),C[p>.6?1:3])}}},
    [LT(-.6,1.3,-.15,38,.65,GREEN),LT(0,1.9,-.15,44,.75,VIOBLUE),LT(.6,1.3,-.15,38,.65,ORANGE)]));return{ground:floor(),objs}}},
 {g:'ecole',name:'Cercle d’étude',desc:'Un cercle de marbre gravé, trois pupitres, et au centre un grand cristal qui flotte et tourne lentement. Trois éclats de couleur gravitent autour de lui, un par élève.',anims:['cristal flottant','trois éclats en orbite','faisceau au sol'],
  build(){return{ground:floor(),objs:[disc(MARBLE,1.3,.1,{inlay:anyI(ringI(1.0,.045,WHC[1]),ringI(.62,.03,MARBLE[1]))}),slab(circle(.36),.1,.22,mMat(),{key:-8}),
   lectern(0,1.02),lectern(-.9,-.42),lectern(.9,-.42),
   dyn(7,(F,t)=>{const bob=Math.sin(t*1.3)*.08,[cx,cy]=at(0,1.45+bob,0),[gx,gy]=at(0,.22,0),w=Math.abs(Math.sin(t*.8));
    for(let y=cy+13;y<gy;y+=2)if((y+Math.floor(t*8))%4<2)F.set(cx,y,FWH[1]);
    const S3=[FGR,FOR,FVB].map((C,i)=>{const a=(K?t*1.1:t*.25)+i*TAU/3;return[at(Math.cos(a)*.7,1.3+.15*Math.sin(a*2+i),Math.sin(a)*.7),C,Math.sin(a)]});
    const sat=([p,C])=>{for(let j=-3;j<=3;j++){const ww=Math.round((3-Math.abs(j))*.6);for(let i=-ww;i<=ww;i++)F.set(p[0]+i,p[1]+j,C[i<0?3:j<0?2:1])}};
    S3.filter(s=>s[2]<0).forEach(sat);
    for(let j=-12;j<=12;j++){const hw=Math.round((12-Math.abs(j))*(.42+.3*w));for(let i=-hw;i<=hw;i++)F.set(cx+i,cy+j,FWH[i<-hw*.3?3:i<hw*.35?2:j<0?1:0])}
    F.line(cx-Math.round(3*w),cy-8,cx-Math.round(3*w),cy+6,FWH[3]);glint(F,cx,cy-13,FWH,K);
    S3.filter(s=>s[2]>=0).forEach(sat)},[LT(0,1.4,0,50,.85,WHITEC),LT(0,.2,0,24,.4,WHITEC)])]}}},
 {g:'ecole',name:'Flèche du Fleuve',desc:'Une aiguille de quartz plantée dans un bassin. L’eau du Fleuve des Limbes, vert pâle, quitte le bassin et remonte en spirale autour de la flèche jusqu’à la pointe.',anims:['spirale d’eau des Limbes','rides dans le bassin','pointe qui luit'],
  build(){const[tx,ty]=at(0,2.78,0),[bx,by]=at(0,.3,0);return{ground:floor(),objs:[
   slab(circle(1.02),0,.3,stone(MARBLE,{noise:.06,courses:.15,joint:.5,inlay:q=>q.f==='top'&&q.rad<.84?(hash(q.sx>>1,q.sy,3)>.86?LIM[1]:LIM[0]):null}),{key:-8}),
   slab(poly(6,.24),.3,1.6,cryst(FWH),{key:-2,taper:[1,.62],mask:true}),slab(poly(6,.15),1.6,2.78,cryst(FWH),{key:-1,taper:[1,.03],mask:true}),
   ...crystal(-.62,.45,.3,.42,.07,LIM,.3),...crystal(.6,.5,.3,.34,.06,LIM),
   dyn(7,(F,t,S)=>{const B=behind(F,S),n=K?30:9;for(let k=0;k<n;k++){const p=((t*.22+k/n)%1),a=p*TAU*2.6+t*.4,r=.56*(1-p*.72),[x,y]=at(Math.cos(a)*r,.34+p*2.35,Math.sin(a)*r),L_=Math.sin(a)>0?F:B,c=LIM[p>.8?3:p>.4?2:1];L_.set(x,y,c);if(p<.7)L_.set(x+1,y,c)}
    for(let k=0;k<3;k++){const p=((t*.4+k/3)%1),rr=6+p*13;for(let a=0;a<28;a++){if((a+k)%2)continue;const an=a/28*TAU;F.set(Math.round(bx+Math.cos(an)*rr),Math.round(by+Math.sin(an)*rr*.42),LIM[p>.6?1:2])}}
    glint(F,tx,ty,K?LIM:FWH,K&&Math.sin(t*2)>0)},[LT(0,.3,.3,48,.7,GREEN),LT(0,2.6,0,34,.7,WHITEC)])]}}},
];
