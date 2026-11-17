'use strict';
// Strazhar à quatre pattes : cinq allures procédurales dessinées avec le kit des ennemis du jeu
// (mêmes palettes, même contour, dessin en coordonnées ×2 réduit à l'échelle native).
// Règle commune : les deux poings se posent ensemble, puis les deux pieds. Jamais de pas alterné.
const StrazharQuad=(()=>{
const {K,fill,ell,seg,line,outlineAll,scaled}=ProjectUnitKit;
const TAU=Math.PI*2,clamp=(x,a=0,b=1)=>Math.max(a,Math.min(b,x)),lerp=(a,b,t)=>a+(b-a)*t,ease=x=>{x=clamp(x);return x*x*(3-2*x)};
const PINK=['#3a0820','#7a1040','#c8206a','#ff5aa0','#ffd0e4'],GOLD=K.gold,CRIM=K.crim,DUST=['#3e3a34','#5e584e','#857d6e','#a89e8a'];
const S=2,NW=68,NH=48,G=NH*S-6,FRAMES=24;
const ARM=[15,17],LEG=[16,16];

// Paramètres en coordonnées virtuelles (×2). fore/hind = [début d'appui, durée d'appui] dans le cycle.
const VARIANTS=[
 {id:'pilon',num:'01',name:'Le pilon',sub:'Marche lourde de gorille',
  desc:'Épaules hautes et dominantes, bassin bas. Les poings tombent lourdement, le corps bascule par-dessus, les pieds se reposent sous le ventre.',
  dur:1.25,stride:34,sh:31,hp:26,fore:[0,.5],hind:[.46,.5],foreLift:6,hindLift:5,bob:3.2,fly:0,surge:1.5,headFwd:0,headUp:0,spread:4,flow:.4,dust:2,Sx:80,Hx:46},
 {id:'ressort',num:'02',name:'Le ressort',sub:'Bondissement',
  desc:'Poussée des deux jambes, brève suspension, réception sur les deux poings. Les pieds reviennent loin sous le corps avant de relancer.',
  dur:.8,stride:54,sh:29,hp:28,fore:[0,.3],hind:[.44,.3],foreLift:10,hindLift:13,bob:2.5,fly:7,surge:3.5,headFwd:1,headUp:1,spread:5,flow:1,dust:1,Sx:80,Hx:46},
 {id:'traque',num:'03',name:'La traque',sub:'Rampée basse',
  desc:'Coudes et genoux très fléchis, ventre près du sol, tête tendue en avant. Presque aucun mouvement vertical : une approche de prédateur.',
  dur:1.45,stride:26,sh:21,hp:20,fore:[0,.56],hind:[.5,.56],foreLift:3,hindLift:3,bob:1,fly:0,surge:1,headFwd:5,headUp:-5,spread:3,flow:.25,dust:0,Sx:82,Hx:46},
 {id:'ruee',num:'04',name:'La ruée',sub:'Charge bestiale',
  desc:'Dos à plat, tête basse, très grande allonge et cadence rapide. Les poings frappent le sol, la cape est tirée vers l’arrière.',
  dur:.56,stride:66,sh:27,hp:30,fore:[0,.26],hind:[.48,.24],foreLift:8,hindLift:12,bob:2,fly:5,surge:4.5,headFwd:4,headUp:-3,spread:5,flow:1.6,dust:3,Sx:84,Hx:46},
 {id:'ressac',num:'05',name:'Le ressac',sub:'Démarche royale',
  desc:'Poitrine haute et tête relevée au-dessus d’un corps bas. Pas mesurés, poings levés haut avant chaque appui, cape qui ondule.',
  dur:1.15,stride:30,sh:31,hp:25,fore:[0,.48],hind:[.5,.46],foreLift:9,hindLift:5,bob:1.8,fly:0,surge:1,headFwd:-2,headUp:6,spread:4,flow:.6,dust:1,Sx:78,Hx:46},
];

const wrap=x=>((x%1)+1)%1;
function limb(v,pair,q,far){
 const[s,len]=v[pair],lift=pair==='fore'?v.foreLift:v.hindLift,c=pair==='fore'?v.Sx+4:v.Hx+4,half=v.stride*len/2;
 const u=wrap(q-s-(far?.025:0));let x,y,planted=false;
 if(u<len){x=c+half-v.stride*u;y=G-3;planted=true}
 else{const p=(u-len)/(1-len);x=c-half+2*half*ease(p);y=G-3-lift*Math.sin(Math.PI*p)}
 if(far){x+=v.spread;y-=3}
 return{x,y,planted,u,len};
}
function girdle(v,pair,q){const[s,len]=v[pair],u=wrap(q-s);return u<len?-v.bob*Math.sin(Math.PI*u/len):v.bob*.35*Math.sin(Math.PI*(u-len)/(1-len))}
function flight(v,q){
 const gaps=[[v.fore[0]+v.fore[1],v.hind[0]],[v.hind[0]+v.hind[1],1+v.fore[0]]];
 for(const[a,b]of gaps){if(b-a<=.001)continue;const t=wrap(q-a)/(b-a);if(t<1)return Math.sin(Math.PI*t)}return 0;
}
function ik(R,T,l1,l2,bend){
 let dx=T[0]-R[0],dy=T[1]-R[1],d=Math.hypot(dx,dy);const max=l1+l2-.5,min=Math.abs(l1-l2)+.5;
 const dd=clamp(d,min,max),base=Math.atan2(dy,dx),a=Math.acos(clamp((l1*l1+dd*dd-l2*l2)/(2*l1*dd),-1,1)),ang=base+bend*a;
 const J=[R[0]+Math.cos(ang)*l1,R[1]+Math.sin(ang)*l1],E=[R[0]+Math.cos(base)*dd,R[1]+Math.sin(base)*dd];
 return[J,E];
}
function pose(v,q){
 const fl=flight(v,q)*v.fly,surge=v.surge*Math.sin(TAU*(q-v.hind[0]-v.hind[1]*.8));
 const Sh=[v.Sx+surge,G-v.sh+girdle(v,'fore',q)-fl],Hp=[v.Hx+surge,G-v.hp+girdle(v,'hind',q)-fl];
 const lagged=girdle(v,'fore',q-.08);
 const head=[Sh[0]+10+v.headFwd,Sh[1]-5-v.headUp+lagged*.4];
 return{Sh,Hp,head,fl,
  fore:[limb(v,'fore',q,false),limb(v,'fore',q,true)],hind:[limb(v,'hind',q,false),limb(v,'hind',q,true)]};
}

/* ---------- dessin ---------- */
const add=(a,b,k=1)=>[a[0]+b[0]*k,a[1]+b[1]*k];
function frame(P,o,pts){return pts.map(([u,w])=>[o.o[0]+o.d[0]*u+o.n[0]*w,o.o[1]+o.d[1]*u+o.n[1]*w])}
function arm(P,R,T,far,z){
 const[J,E]=ik(R,[T.x,T.y],ARM[0],ARM[1],1),v=far?.3:.7;
 seg(P,R,J,8,GOLD,z,{v});
 ell(P,J[0],J[1],4,4,GOLD,z+2,{v:v+.12});
 // avant-bras massif en gantelet évasé, poing fermé phalanges au sol
 const d=[E[0]-J[0],E[1]-J[1]],l=Math.hypot(...d)||1,u=[d[0]/l,d[1]/l],nn=[-u[1],u[0]];
 fill(P,[add(add(J,nn,3.5),u,1),add(add(J,nn,-3.5),u,1),add(add(E,nn,-5.5),u,-3),add(add(E,nn,5.5),u,-3)],GOLD,z+1,{v:v+.06,lx:.5});
 if(!far){const a1=add(add(J,nn,-1),u,4),a2=add(add(E,nn,-2),u,-5);line(P,...a1,...a2,GOLD[5],z+1.5)}
 ell(P,E[0]+1.5,E[1],5.5,4.2,GOLD,z+3,{v:v+.1});
 if(!far){for(let i=0;i<3;i++)P.set(E[0]+3+i*1.2,E[1]-2+i*1.4,GOLD[1],z+4);line(P,E[0]-3,E[1]+2.5,E[0]+5,E[1]+2.5,GOLD[1],z+4)}
 return E;
}
function leg(P,R,T,far,z){
 const[J,E]=ik(R,[T.x,T.y-2],LEG[0],LEG[1],-1),v=far?.3:.66;
 seg(P,R,J,8,GOLD,z,{v});seg(P,J,E,6,GOLD,z+1,{v:v+.04});
 ell(P,J[0],J[1],3.6,3.4,GOLD,z+2,{v:v+.14});
 if(!far){line(P,R[0]-2,R[1]+2,J[0]-1,J[1]-2,PINK[1],z+1.5);line(P,R[0]-1,R[1]+4,J[0]-2,J[1],PINK[2],z+1.5)}
 // solleret : talon sous la cheville, pointe vers l'avant
 fill(P,[[E[0]-4,E[1]-2],[E[0]+3,E[1]-2],[E[0]+7,E[1]+1.5],[E[0]+7,E[1]+3.5],[E[0]-4,E[1]+3.5]],GOLD,z+2,{v:v+.02,ly:.4});
 line(P,E[0]-4,E[1]+3,E[0]+7,E[1]+3,GOLD[0],z+3);
 return E;
}
function head(P,x,y,dead){
 fill(P,[[x-6,y-8],[x+5,y-10],[x+8,y-4],[x+7,y+3],[x+5,y+8],[x-5,y+7]],GOLD,60,{v:.8});
 line(P,x-2,y-1,x+7,y-2,PINK[4],63);line(P,x-1,y,x+7,y-1,PINK[3],62);
 for(let i=0;i<3;i++)fill(P,[[x-7+i*5,y-6],[x-9+i*5,y-17-i%2*3],[x-2+i*5,y-9]],GOLD,61,{v:.88});
 line(P,x+2,y+1,x+2,y+6,GOLD[1],63);line(P,x-5,y+4,x+1,y+6,GOLD[2],62);
}
function halo(P,x,y,t){
 const r=10.5;
 for(let k=0;k<44;k++){const a=k/44*TAU;P.set(x+Math.cos(a)*r,y+Math.sin(a)*r*.96,k%3?GOLD[4]:GOLD[5],4)}
 for(let k=0;k<8;k++){const a=k/8*TAU+.2+t*.6;line(P,x+Math.cos(a)*(r+1),y+Math.sin(a)*(r+1),x+Math.cos(a)*(r+4),y+Math.sin(a)*(r+4),GOLD[5],4)}
}
// Trait intérieur : sépare les pièces proches (membres, tête, épaulière) de ce qu'elles recouvrent.
function innerLines(P0){
 const w=P0.w,h=P0.h,z=P0.z,a=P0.d.data,ink=[0x2e,0x1e,0x0a],front=v=>v>=40,mark=new Uint8Array(w*h);
 for(let y=0;y<h;y++)for(let x=0;x<w;x++){const i=y*w+x;if(a[i*4+3]===0)continue;
  for(const[dx,dy]of[[1,0],[-1,0],[0,1],[0,-1]]){const X=x+dx,Y=y+dy;if(X<0||Y<0||X>=w||Y>=h)continue;const j=Y*w+X;
   if(a[j*4+3]&&front(z[j])&&z[j]>=z[i]+6){mark[i]=1;break}}}
 for(let i=0;i<w*h;i++)if(mark[i])a.set(ink,i*4);
}
function draw(v,q){
 const P0=new Px(NW,NH,true),P=scaled(P0,1/S),p=pose(v,q),{Sh,Hp}=p;
 const dx=Sh[0]-Hp[0],dy=Sh[1]-Hp[1],dl=Math.hypot(dx,dy),d=[dx/dl,dy/dl],n=[d[1],-d[0]];
 const B={o:Hp,d,n},len=dl,wave=Math.sin(TAU*(q*2-.2))*1.6*v.flow,flow=v.flow;
 halo(P,p.head[0]-2,p.head[1]-9,q);
 // membres du côté éloigné, plus sombres et légèrement plus hauts à l'écran
 leg(P,add(Hp,[2,-2]),p.hind[1],true,8);
 arm(P,add(Sh,[3,-2]),p.fore[1],true,10);
 // buste de gorille : bosse énorme aux épaules, poitrail profond, croupe basse
 const torso=frame(P,B,[[-7,-2],[-5,7],[2,9],[len*.45,11],[len*.8,16],[len+2,17],[len+8,12],[len+10,3],[len+8,-8],[len+2,-13],[len*.6,-10],[len*.3,-7],[4,-7]]);
 fill(P,torso,GOLD,20,{v:.6,tex:3,ly:.3});
 for(const t of[.3,.58]){const a=frame(P,B,[[len*t,10+t*5],[len*t-2,-7-t*4]]);line(P,...a[0],...a[1],GOLD[1],21)}
 const belt=frame(P,B,[[4,8],[2,-6]]);line(P,...belt[0],...belt[1],K.bronze[2],21);
 // coutures organiques de la Bête sur le flanc
 for(let i=0;i<3;i++){const a=frame(P,B,[[len*.4+i*4,1+i],[len*.5+i*4,-4+i*.5],[len*.47+i*3,-8]]);line(P,...a[0],...a[1],PINK[1],22);line(P,...a[1],...a[2],PINK[2],22)}
 // cœur pectoral magenta, au poitrail
 const core=frame(P,B,[[len+7,-4]])[0];
 ell(P,core[0],core[1],3.8,3.8,GOLD,24,{v:.85});ell(P,core[0],core[1],2.3,2.5,PINK,25,{v:.72+.18*Math.sin(q*TAU*2)});
 // cape courte posée sur les reins, flotte derrière la croupe
 const cape=frame(P,B,[[len*.62,13.5],[len*.3,11],[2,9.5],[-9-flow*4,6+wave*.4],[-15-flow*7,0+wave],[-11-flow*4,-5+wave*.6],[-3,-3],[len*.25,0],[len*.5,4],[len*.66,8]]);
 fill(P,cape,CRIM,30,{v:.6,fold:1});
 const hem=cape.slice(5);for(let i=0;i<hem.length-1;i++)line(P,...hem[i],...hem[i+1],GOLD[3],31);
 // fourreau rangé en diagonale sur le dos, garde à l'épaule
 const sw=frame(P,B,[[-11-flow*2,9],[len*.7,16],[len*.88,18.5],[len*.7,13],[len*.72,19]]);
 seg(P,sw[0],sw[1],3,K.leath,32,{v:.7});line(P,...sw[0],...sw[1],GOLD[2],33);
 line(P,...sw[1],...sw[2],K.leath[4],33);line(P,...sw[3],...sw[4],GOLD[4],34);
 // bouclier solaire sanglé sur la bosse, œil de la Bête vers le ciel
 const sc=frame(P,B,[[len*.62,17]])[0],ang=Math.atan2(d[1],d[0]);
 const shp=[[-10,-1],[-5,-5],[6,-6],[11,-1],[6,4],[-5,4]].map(([u,w])=>[sc[0]+u*Math.cos(ang)-w*Math.sin(ang),sc[1]+u*Math.sin(ang)+w*Math.cos(ang)]);
 fill(P,shp,GOLD,36,{v:.86,lx:.5});
 for(let i=0;i<shp.length;i++)line(P,...shp[i],...shp[(i+1)%shp.length],GOLD[1],37);
 line(P,...shp[1],...shp[2],GOLD[5],37.5);
 ell(P,sc[0],sc[1],3.2,1.7,PINK,38,{v:.85});P.set(sc[0]+.5,sc[1],K.gun[1],39);
 // épaulière proche, énorme, par-dessus tout le buste
 const pa=add(Sh,[-1,-6]);
 ell(P,pa[0],pa[1],9,7.5,GOLD,44,{v:.8});
 line(P,pa[0]-8,pa[1]-1,pa[0]+5,pa[1]-6,GOLD[5],45);line(P,pa[0]-7,pa[1]+4,pa[0]+7,pa[1]+1,GOLD[2],45);line(P,pa[0]-6,pa[1]+5,pa[0]+5,pa[1]+3,PINK[1],45);
 // membres proches ; tête enfoncée entre les épaules, devant la bosse
 leg(P,Hp,p.hind[0],false,40);
 arm(P,Sh,p.fore[0],false,52);
 head(P,p.head[0],p.head[1]);
 innerLines(P0);
 outlineAll(P0);
 // poussière d'impact, posée après le contour (effet au sol)
 if(v.dust)for(const[list,k]of[[p.fore,1],[p.hind,.7]])for(const L of list){
  const t=L.u/L.len;if(!L.planted||t>.3)continue;const n=Math.round(v.dust*3*k),age=t/.3;
  for(let i=0;i<n;i++){const s=(i%2?1:-1)*(2+i*1.5+age*5),x=Math.round(L.x/S+s/S*1.4),y=Math.round(L.y/S+1-age*1.5-(i%3===0?1:0));
   if(x>=0&&y>=0&&x<NW&&y<NH){const o=(y*NW+x)*4,c=DUST[Math.min(3,1+(i%3))],h=[1,3,5].map(j=>parseInt(c.substr(j,2),16));if(P0.d.data[o+3]===0){P0.d.data.set(h,o);P0.d.data[o+3]=age<.6?255:150}}}
 }
 P0.flush();
 const contacts=[...p.fore.map((L,i)=>({kind:'fore',far:!!i,x:L.x/S,y:L.y/S,planted:L.planted})),...p.hind.map((L,i)=>({kind:'hind',far:!!i,x:L.x/S,y:(L.y+3)/S,planted:L.planted}))];
 return{canvas:P0.c,contacts};
}
const cache=new Map();
function get(v,f){const k=v.id+':'+f;if(!cache.has(k))cache.set(k,draw(v,f/FRAMES));return cache.get(k)}
return{VARIANTS,FRAMES,NW,NH,ground:G/S,get};
})();
