'use strict';
// Galeries aléatoires dans la montagne et déplacement des unités.
// Les galeries sont scellées : aucune ne touche la salle de départ, son couloir ni la jungle.
// Elles restent invisibles (roche) jusqu'à ce que l'Ingénieur creuse jusqu'à elles.

// Limites du monde (multiples de 4 : une case de roche = 4 × 4 unités).
const WORLD={x0:-232,x1:232,z0:-336,z1:72};
const clampCam=()=>{cam.x=clamp(cam.x,WORLD.x0+30,WORLD.x1-30);cam.z=clamp(cam.z,WORLD.z0+20,WORLD.z1-28)};

// ----- Galeries : masque à 1 unité de résolution (0 = roche, 1 = galerie) ; open = déjà découverte -----
const GAL={w:WORLD.x1-WORLD.x0,h:WORLD.z1-WORLD.z0,mask:null,open:null,count:0,found:0,seed:0,portals:[]};
const galIdx=(x,z)=>{const i=Math.floor(x-WORLD.x0),j=Math.floor(z-WORLD.z0);return i<0||j<0||i>=GAL.w||j>=GAL.h?-1:j*GAL.w+i};
function isGallery(x,z){const k=galIdx(x,z);return k>=0&&GAL.mask[k]===1}
function isGalleryOpen(x,z){if(!GAL.found)return false;const k=galIdx(x,z);return k>=0&&GAL.open[k]===1}
// marge de roche autour de la salle de départ, de son couloir et du flanc de la montagne
function galleryAllowed(x,z){if(x<WORLD.x0+10||x>WORLD.x1-10||z<WORLD.z0+10||z>mountainEdge(x)-12)return false;
 if(x>-76&&x<76&&z>CAVE.z0-16)return false;return true}
function generateGalleries(seed=(Math.random()*1e9)>>>0){GAL.seed=seed;const R=rng(seed);GAL.mask=new Uint8Array(GAL.w*GAL.h);GAL.open=new Uint8Array(GAL.w*GAL.h);GAL.found=0;
 const stamp=(cx,cz,r)=>{for(let z=Math.floor(cz-r);z<=cz+r;z++)for(let x=Math.floor(cx-r);x<=cx+r;x++){const dx=x+.5-cx,dz=z+.5-cz;if(dx*dx+dz*dz>r*r||!galleryAllowed(x+.5,z+.5))continue;const k=galIdx(x,z);if(k>=0)GAL.mask[k]=1}};
 const worm=(x,z,a,steps,r)=>{for(let s=0;s<steps;s++){stamp(x,z,r*(.8+R()*.45));
   if(R()<.05)stamp(x+(R()-.5)*3,z+(R()-.5)*3,r*(1.9+R()*.9)); // salle plus large
   if(R()<.025&&steps>20)worm(x,z,a+(R()<.5?1:-1)*(1+R()*.8),Math.floor(steps*.45),r*.85); // embranchement
   a+=(R()-.5)*.75;let nx=x+Math.cos(a)*1.7,nz=z+Math.sin(a)*1.7;
   if(!galleryAllowed(nx,nz)){a+=Math.PI*(.5+R()*.5);continue}x=nx;z=nz}};
 const n=12+Math.floor(R()*5);
 for(let g=0;g<n;g++){let x=0,z=0;for(let t=0;t<200;t++){x=WORLD.x0+14+R()*(GAL.w-28);z=WORLD.z0+14+R()*(GAL.h-28);if(galleryAllowed(x,z))break}
  worm(x,z,R()*Math.PI*2,34+Math.floor(R()*46),2.1+R()*1.4)}
 // nombre réel de galeries : les vers qui se croisent n'en forment qu'une
 const comp=new Int16Array(GAL.mask.length);GAL.count=0;for(let k0=0;k0<GAL.mask.length;k0++){if(!GAL.mask[k0]||comp[k0])continue;const id=++GAL.count,st=[k0];
  while(st.length){const k=st.pop();if(k<0||k>=GAL.mask.length||!GAL.mask[k]||comp[k])continue;comp[k]=id;const i=k%GAL.w;if(i>0)st.push(k-1);if(i<GAL.w-1)st.push(k+1);st.push(k-GAL.w,k+GAL.w)}}
 // un portail maléfique par réseau : de préférence adossé à une paroi nord, devant un espace dégagé
 const m=(i,j)=>i>=0&&j>=0&&i<GAL.w&&j<GAL.h&&GAL.mask[j*GAL.w+i]===1,best=[];
 for(let k=0;k<GAL.mask.length;k++){const id=comp[k];if(!id)continue;const i=k%GAL.w,j=(k-i)/GAL.w;let sc=0;for(let a=-3;a<=3;a++)for(let b=0;b<=5;b++)if(m(i+a,j+b))sc++;
  if(!m(i,j-1)&&!m(i-1,j-1)&&!m(i+1,j-1))sc+=100;if(!best[id]||sc>best[id].sc)best[id]={sc,x:i+WORLD.x0+.5,z:j+WORLD.z0+.5}}
 GAL.portals=best.filter(Boolean).map((b,n)=>({id:n,x:b.x,z:b.z,active:false,next:0}))}

// Révélation : remplissage de la galerie connexe touchée, peinture du sol et des parois, décor.
function revealGalleriesNear(x0,z0,x1,z1){let any=false;for(let z=Math.floor(z0);z<=z1;z++)for(let x=Math.floor(x0);x<=x1;x++){const k=galIdx(x,z);if(k>=0&&GAL.mask[k]===1&&!GAL.open[k]){revealGallery(x,z);any=true}}return any}
function revealGallery(sx,sz){const stack=[galIdx(sx,sz)];let i0=1e9,i1=-1e9,j0=1e9,j1=-1e9,n=0;
 while(stack.length){const k=stack.pop();if(k<0||GAL.mask[k]!==1||GAL.open[k])continue;GAL.open[k]=1;n++;const i=k%GAL.w,j=(k-i)/GAL.w;
  if(i<i0)i0=i;if(i>i1)i1=i;if(j<j0)j0=j;if(j>j1)j1=j;
  if(i>0)stack.push(k-1);if(i<GAL.w-1)stack.push(k+1);if(j>0)stack.push(k-GAL.w);if(j<GAL.h-1)stack.push(k+GAL.w)}
 if(!n)return;GAL.found++;const woke=GAL.portals.filter(p=>!p.active&&isGalleryOpen(p.x,p.z));
 const X0=Math.floor((i0+WORLD.x0)/4)*4-4,X1=Math.ceil((i1+WORLD.x0+1)/4)*4+4,Z0=Math.floor((j0+WORLD.z0)/4)*4-4,Z1=Math.ceil((j1+WORLD.z0+1)/4)*4+4;
 // éboulis du dos de la montagne posés sur la galerie : retirés
 PW.objs=PW.objs.filter(o=>o.portal||o.dportal||o.orb||o.deityFx||o.evil||o.bx!==undefined||!isGalleryOpen(o.x,o.z));
 paintRegion(X0,Z0,X1,Z1);
 // parois vues de face au nord de chaque ouverture, cristaux le long des murs
 const R=rng(GAL.seed+n),objs=PW.objs;
 for(let x=X0;x<X1;x+=4)for(let z=Z0;z<Z1;z+=4){const cx=x+2,cz=z+2;if(walkable(cx,cz)||!walkable(cx,cz+4)||inCave(cx,cz+4))continue;
  let bz=z+4;for(let t=z+4;t<z+8;t+=.5)if(isGalleryOpen(cx,t)){bz=t;break}const v=Math.floor(R()*6);objs.push({x,z:bz,d:bz,dz:bz,bx:x,bz,spr:faceSprite(5,rng(v*41+5)),gal:true})}
 for(let k=0;k<Math.max(2,n/90);k++){for(let t=0;t<40;t++){const x=X0+R()*(X1-X0),z=Z0+R()*(Z1-Z0);if(!isGalleryOpen(x,z)||isGalleryOpen(x,z-2.5))continue;const v=Math.floor(R()*6);
   objs.push({x,z,d:x+z,spr:sprite(28,44,14,40,(S,ax,ay)=>caveSpire(S,ax,ay,rng(v*17+3),v%2===0)),light:v%2===0,gal:true});break}}
 for(const p of woke){p.active=true;p.next=currentTime+5;objs.push({evil:p,x:p.x,z:p.z,d:p.z+.5,dz:p.z+.5});zone(p.x,p.z+1,4,'#ff5030')}
 objs.sort((a,b)=>a.d-b.d);WALK.version++;WALK.cache.fill(0);if(HUD.els)buildMiniMap();
 zone((X0+X1)/2,(Z0+Z1)/2,6,'#8fd6f0');say('Galerie découverte ! ('+GAL.found+' / '+GAL.count+')'+(woke.length?' · un portail maléfique s’y éveille : les rejetons de la Bête en sortent sans fin.':''),woke.length?5:3)}

// ----- Portails maléfiques : chaque réseau découvert crache en permanence des rejetons de la Bête -----
const EVIL={interval:7,cap:8,look:['#1a0404','#4a0a0a','#a01818','#f04020','#ffb080','#ffffff'],frames:null,scale:.7};
function updateEvilPortals(){if(ended)return;for(const p of GAL.portals){if(!p.active||currentTime<p.next)continue;p.next=currentTime+EVIL.interval;
 if(enemies.filter(e=>e.portal===p&&e.hp>0).length>=EVIL.cap)continue;
 const e={x:p.x+(Math.random()-.5)*2,z:p.z+2+Math.random(),hp:22,max:22,speed:2.6,range:1.5,damage:4,kind:'beast',cooldown:random(.3,1),target:null,beast:true,portal:p};pushOutOfRock(e);enemies.push(e);flash(e.x,e.z,'#ff5030')}}
function drawEvilPortal(o){flushDecor();const[nx,ny]=natP(o.x,0,o.z);if(nx<-90||nx>W/PX+90||ny<-30||ny>H/PX+120)return;
 if(!EVIL.frames){const D={...PortalKit.DESIGNS[0],glow:EVIL.look},S={glyph:.8,seals:1,open:1,field:.9,rim:1,arcs:.8,unit:null};EVIL.frames=Array.from({length:12},(_,k)=>PortalKit.render(D,S,k/12*Math.PI/2))}
 const f=EVIL.frames[Math.floor(currentTime*12/(Math.PI/2))%12],k=EVIL.scale*PX;ctx.save();ctx.translate(nx*PX,ny*PX);ctx.transform(k,k*.5,0,k,0,0);ctx.drawImage(f,-PortalKit.OX,-PortalKit.OY);ctx.restore();
 // braises qui s'échappent du portail
 for(let i=0;i<6;i++){const u=(currentTime*.6+i/6)%1;npx(nx+Math.sin(currentTime*2+i*2.1)*9,ny-6-u*34,u<.5?EVIL.look[4]:EVIL.look[3])}captureDecorLayer()}
// Repeint le sol (cases de 4 × 4) d'une zone : roche, sol de grotte et bords, comme à la création du monde.
function paintRegion(X0,Z0,X1,Z1){const g=PW.ground.getContext('2d'),hol=(a,b)=>isGalleryOpen(a,b)||isDug(a,b)||inCave(a,b)||inTunnel(a,b);
 for(let x=X0;x<X1;x+=4)for(let z=Z0;z<Z1;z+=4)paintGroundTile(g,x,z,hol)}
// Repeint une case 4 × 4 (coin x,z) du sol. Le bruit est calculé en coordonnées de la texture du monde, comme à sa création :
// le sol repeint se raccorde sans couture au sol voisin. Les bords de roche ne sont dessinés que sur les pixels de roche.
// Une case sans aucun pixel creux est laissée telle quelle.
function paintGroundTile(g,x,z,hol){const[a,b]=natW(x,0,z),sx=a+PW.gx0,sy=b+PW.gy0,open=new Uint8Array(34*34);let n=0;
 for(let py=-1;py<33;py++)for(let px=-1;px<33;px++){const v=hol(x+(px+.5)/NAT.kx,z+(py+.5)/NAT.kx)?1:0;open[(py+1)*34+px+1]=v;if(v&&px>=0&&px<32&&py>=0&&py<32)n++}
 if(!n)return;const at=(px,py)=>px<-1||py<-1||px>32||py>32?hol(x+(px+.5)/NAT.kx,z+(py+.5)/NAT.kx):open[(py+1)*34+px+1]===1;
 const T=new Px(32,32,true),R=rng((x*977+z*31)>>>0),W2={set:(px,py,c,k)=>T.set(px-sx,py-sy,c,k),dark:(px,py,f,k)=>T.dark(px-sx,py-sy,f,k),ramp:T.ramp.bind(T)},old=diamond;diamond=squareTile;
 try{if(n===1024)caveTile(W2,sx+16,sy,R,0);else{const M={set:(px,py,c,k)=>{if(at(px-sx,py-sy))W2.set(px,py,c,k)},ramp:W2.ramp,dark:(px,py,f,k)=>{if(at(px-sx,py-sy))W2.dark(px,py,f,k)}};
   rockTile(W2,sx+16,sy,R,0);caveTile(M,sx+16,sy,R,.1);
   for(let py=0;py<32;py++)for(let px=0;px<32;px++){if(at(px,py))continue;if(at(px,py+2)&&!at(px,py-3))T.dark(px,py,.55,.6);else if(at(px,py-2))T.set(px,py,CAVE_C.rock[at(px,py-1)?7:5],.6);else if(at(px-2,py)||at(px+2,py))T.set(px,py,at(px-1,py)||at(px+1,py)?CAVE_C.rock[0]:CAVE_C.rock[6],.6)}}}
 finally{diamond=old}T.flush();g.clearRect(sx,sy,32,32);g.drawImage(T.c,sx,sy)}

// ----- Déplacement : grille de 2 unités, A* à 8 directions, lissage par ligne de vue -----
const WALK={cell:2,w:(WORLD.x1-WORLD.x0)/2,h:(WORLD.z1-WORLD.z0)/2,cache:null,version:0};WALK.cache=new Uint8Array(WALK.w*WALK.h);
function walkCell(i,j){if(i<0||j<0||i>=WALK.w||j>=WALK.h)return false;const k=j*WALK.w+i;let v=WALK.cache[k];if(!v){v=walkable(WORLD.x0+i*2+1,WORLD.z0+j*2+1)?1:2;WALK.cache[k]=v}return v===1}
const cellOf=p=>[Math.floor((p.x-WORLD.x0)/2),Math.floor((p.z-WORLD.z0)/2)];
function clearLine(a,b){const d=Math.hypot(b.x-a.x,b.z-a.z),n=Math.ceil(d/.6);for(let s=1;s<=n;s++){const t=s/n,x=a.x+(b.x-a.x)*t,z=a.z+(b.z-a.z)*t;if(!walkCell(Math.floor((x-WORLD.x0)/2),Math.floor((z-WORLD.z0)/2)))return false}return true}
function nearestWalkCell(i,j,r=6){if(walkCell(i,j))return[i,j];for(let d=1;d<=r;d++)for(let a=-d;a<=d;a++)for(const[di,dj]of[[a,-d],[a,d],[-d,a],[d,a]])if(walkCell(i+di,j+dj))return[i+di,j+dj];return null}
function findPath(from,to){const s=nearestWalkCell(...cellOf(from),3),g=nearestWalkCell(...cellOf(to),8);if(!s||!g)return null;
 const W_=WALK.w,start=s[1]*W_+s[0],goal=g[1]*W_+g[0];if(start===goal)return[];
 const gs=new Map([[start,0]]),came=new Map(),heap=[[0,start]],closed=new Set(),hx=k=>{const i=k%W_,j=(k-i)/W_,dx=Math.abs(i-g[0]),dz=Math.abs(j-g[1]);return Math.max(dx,dz)+.414*Math.min(dx,dz)};
 const push=n=>{heap.push(n);let c=heap.length-1;while(c>0){const p=(c-1)>>1;if(heap[p][0]<=heap[c][0])break;[heap[p],heap[c]]=[heap[c],heap[p]];c=p}};
 const pop=()=>{const top=heap[0],last=heap.pop();if(heap.length){heap[0]=last;let c=0;for(;;){const l=c*2+1,r=l+1;let m=c;if(l<heap.length&&heap[l][0]<heap[m][0])m=l;if(r<heap.length&&heap[r][0]<heap[m][0])m=r;if(m===c)break;[heap[m],heap[c]]=[heap[c],heap[m]];c=m}}return top};
 let found=false,budget=60000;
 while(heap.length&&budget-->0){const[,k]=pop();if(k===goal){found=true;break}if(closed.has(k))continue;closed.add(k);const i=k%W_,j=(k-i)/W_,base=gs.get(k);
  for(let di=-1;di<=1;di++)for(let dj=-1;dj<=1;dj++){if(!di&&!dj)continue;const ni=i+di,nj=j+dj;if(!walkCell(ni,nj))continue;if(di&&dj&&(!walkCell(i+di,j)||!walkCell(i,j+dj)))continue;
   const nk=nj*W_+ni,cost=base+(di&&dj?1.414:1);if(cost<(gs.get(nk)??Infinity)){gs.set(nk,cost);came.set(nk,k);push([cost+hx(nk),nk])}}}
 if(!found)return null;const cells=[];for(let k=goal;k!==start;k=came.get(k)){const i=k%W_,j=(k-i)/W_;cells.push({x:WORLD.x0+i*2+1,z:WORLD.z0+j*2+1})}cells.reverse();
 // lissage : on saute directement au point le plus lointain visible
 const out=[];let cur=from,i=0;while(i<cells.length){let j=i;for(let k=Math.min(cells.length-1,i+24);k>i;k--)if(clearLine(cur,cells[k])){j=k;break}out.push(cells[j]);cur=cells[j];i=j+1}
 out.pop();return out}
// Prochain point à rejoindre pour atteindre (tx,tz) ; le chemin est mis en cache tant que la cible ne bouge pas.
function steer(u,goal){if(clearLine(u,goal)){u._path=null;return goal}
 if(!u._path||u._pv!==WALK.version||Math.hypot(u._pg.x-goal.x,u._pg.z-goal.z)>2){u._pg={x:goal.x,z:goal.z};u._pv=WALK.version;u._path=findPath(u,goal)||[]}
 const P=u._path;while(P.length&&(Math.hypot(P[0].x-u.x,P[0].z-u.z)<.6||P.length>1&&clearLine(u,P[1])))P.shift();return P.length?P[0]:goal}
