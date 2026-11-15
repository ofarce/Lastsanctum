'use strict';
// Adeptes des quatre dieux (prière au temple de leur dieu), combattants de la caserne,
// creusement de la roche par l'Ingénieur, combat et expérience. Toutes les durées suivent le temps de simulation.

const ADEPT={
 sigil:{name:'Adepte de Sigil',task:'pray',hp:90,lore:'Sa prière au temple de Sigil nourrit le Savoir.'},
 medeina:{name:'Adepte de Medeina',task:'pray',hp:95,lore:'Sa prière au temple de Medeina nourrit la Vie.'},
 aether:{name:'Adepte d’Aether',task:'pray',hp:100,lore:'Sa prière au temple d’Aether nourrit la Forge.'},
 indra:{name:'Adepte d’Indra',task:'pray',hp:110,lore:'Sa prière au temple d’Indra nourrit la Discipline.'},
 // combattants entraînés à la caserne
 flammes:{name:'Adepte lance-flammes',task:'fight',hp:120,lore:'Le feu de sa lance ne laisse derrière lui que des cendres.'},
 archer:{name:'Adepte archer',task:'fight',hp:85,lore:'Sa flèche part avant que l’ennemi ne l’ait vu.'},
 lame:{name:'Adepte d’épée et bouclier',task:'fight',hp:170,lore:'Son bouclier est un mur que la meute ne franchit pas.'}};
// seek : rayon de détection ; reach : portée d'attaque ; splash : rayon de brûlure ; guard : part des dégâts subis
const MELEE_ADEPT={seek:6,reach:1.9,dmg:4,cd:1.1,status:'En attente · petite attaque au corps à corps'};
const FIGHT={
 flammes:{seek:18,reach:9,dmg:6,cd:.3,splash:2.2,status:'Garde l’Ancre · flammes ; sillon de feu toutes les 4 s'},
 archer:{seek:68,reach:56,dmg:11,cd:.95,melee:{reach:2.3,dmg:13,cd:.6},status:'Garde l’Ancre · arc, puis Charge du Lac au contact'},
 lame:{seek:7,reach:2.2,dmg:16,cd:.85,guard:.55,status:'Garde l’Ancre · mêlée ; moulinet d’orage toutes les 3 frappes'},
 sigil:MELEE_ADEPT,medeina:MELEE_ADEPT,aether:MELEE_ADEPT,indra:MELEE_ADEPT,
 // dégâts et portée de l'Ingénieur multipliés par 10 (8 → 80, 8,6 → 86)
 engineer:{seek:86,reach:86,dmg:80,cd:1.15,ranged:true,status:'Prêt à recevoir vos ordres'}};
const isAdept=u=>!!(u&&ADEPT[u.role]);
const prays=u=>!!(u&&DEITY_RES[u.role]);

// ----- Expérience : chaque niveau donne +1 dégât et +1 défense ; le palier suivant croît de façon exponentielle -----
const KILL_XP={creep:10,spitter:15,brute:35,beast:6};
const xpNeed=level=>Math.round(20*1.6**(level-1));
const lvl=u=>(u&&u.level)||1,lvlBonus=u=>lvl(u)-1;
function gainXP(u,n){if(!u||!u.role||u.hp<=0)return;u.level=lvl(u);u.xp=(u.xp||0)+n;
 while(u.xp>=xpNeed(u.level)){u.xp-=xpNeed(u.level);u.level++;zone(u.x,u.z,1.6,'#ffe08a');flash(u.x,u.z,'#ffe08a');say(u.name+' passe au niveau '+u.level+' · +1 dégât, +1 défense.',2)}}
// dégâts subis par une unité après sa défense (au moins 15 % des dégâts d'origine)
const afterArmor=(u,dmg)=>Math.max(dmg*.15,dmg-lvlBonus(u));
// attaque d'une unité ; le lance-flammes brûle tous les ennemis proches de la cible
function barracksStrike(u,e){const F=FIGHT[u.role],k=u.buff>0?1.5:1,dmg=(F.dmg+lvlBonus(u))*k;u.attack=F.cd;u._face=e.x-u.x<0?-1:1;
 if(u.role==='flammes'&&currentTime>=(u.sillonAt||0))sillon(u,e);
 if(u.role==='flammes'){for(const o of enemies)if(o.hp>0&&dist(o,e)<F.splash)damage(o,dmg,u);blast(u,e,'#ff9a30');flash(e.x,e.z,'#ffb050');return}
 if(u.role==='lame'&&moulinet(u,dmg))return;
 damage(e,dmg,u);if(u.role==='archer')arrow(u,e);else if(u.role==='engineer'&&typeof rivet==='function')rivet(u,e);else if(F.ranged){blast(u,e,'#bed7df');flash(e.x,e.z,'#bed7df')}else{flash(e.x,e.z,'#f0dba4');swordStrike(u,e)}}
// ----- Charge du Lac (proposition VI) : l'archer tire de loin ; quand un ennemi entre à moins de CHARGE.trigger,
// il charge une fois par engagement (dash, dégâts ×2, étourdit), puis enchaîne des estocs de mêlée.
// L'engagement se réinitialise quand plus aucun ennemi n'est à moins de CHARGE.reset.
const CHARGE={trigger:5,reset:8,speed:16,dmg:22,stun:.5,maxT:.6};
function archerTick(u,e,dt){
 if(u.dash){const t=u.dash.e;if(t.hp<=0){u.dash=null;return false}
  const dx=t.x-u.x,dz=t.z-u.z,l=Math.hypot(dx,dz)||1;u._face=dx<0?-1:1;flash(u.x,u.z,'#64a2f4');
  if(l>1.4&&currentTime-u.dash.t0<CHARGE.maxT){const s=Math.min(l-1.3,CHARGE.speed*dt);u.x+=dx/l*s;u.z+=dz/l*s;return true}
  damage(t,(CHARGE.dmg+lvlBonus(u))*(u.buff>0?1.5:1),u);t.stun=CHARGE.stun;flash(t.x,t.z,'#bcdcff');zone(t.x,t.z,1.4,'#64a2f4');swordStrike(u,t);
  u.attack=FIGHT.archer.melee.cd;u.dash=null;return true}
 if(!e||dist(u,e)>CHARGE.reset){u.charged=false;return false}
 if(u.stance==='hold'||u.forceMove)return false;
 const d=dist(u,e);if(d>=CHARGE.trigger)return false;
 if(!u.charged){u.charged=true;u.dash={e,t0:currentTime};return true}
 const M=FIGHT.archer.melee;if(d>M.reach){move(u,steer(u,e),dt,.65);return true}
 if(u.attack<=0){u.attack=M.cd;u._face=e.x-u.x<0?-1:1;damage(e,(M.dmg+lvlBonus(u))*(u.buff>0?1.5:1),u);flash(e.x,e.z,'#f0dba4');swordStrike(u,e)}
 return true}
// ----- Moulinet d'Indra (L4) : chaque frappe charge la lame d'orage ; à 3 charges, la frappe suivante est un moulinet
// qui touche tous les ennemis dans MOULINET.r. Retourne true si le moulinet a remplacé la frappe.
const MOULINET={charges:3,r:2.8,dmg:24};
function moulinet(u,dmg){if((u.orage||0)<MOULINET.charges){u.orage=(u.orage||0)+1;return false}
 u.orage=0;const k=dmg/(FIGHT.lame.dmg+lvlBonus(u)),hit=(MOULINET.dmg+lvlBonus(u))*k;
 for(const o of enemies)if(o.hp>0&&dist(o,u)<MOULINET.r){damage(o,hit,u);flash(o.x,o.z,'#bcdcff')}
 zone(u.x,u.z,MOULINET.r,'#64a2f4');swordStrike(u,u);return true}
// ----- Sillon de flammes (F4) : toutes les SILLON.cd s, une ligne de feu file vers la cible (dégâts au passage),
// puis reste en mur SILLON.wall s : les ennemis dedans brûlent et sont ralentis de 40 %.
const SILLON={cd:4,len:8,w:.9,dmg:12,wall:2,burn:3,slow:.6};let fireWalls=[];
function onWall(w,o){const px=o.x-w.x,pz=o.z-w.z,t=Math.max(0,Math.min(w.len,px*w.dx+pz*w.dz));return Math.hypot(px-w.dx*t,pz-w.dz*t)<SILLON.w}
function sillon(u,e){u.sillonAt=currentTime+SILLON.cd;const dx=e.x-u.x,dz=e.z-u.z,l=Math.hypot(dx,dz)||1;
 const w={x:u.x+dx/l*.6,z:u.z+dz/l*.6,dx:dx/l,dz:dz/l,len:SILLON.len,t0:currentTime,until:currentTime+SILLON.wall+.4};fireWalls.push(w);
 for(const o of enemies)if(o.hp>0&&onWall(w,o))damage(o,SILLON.dmg+lvlBonus(u),u)}
function updateFireWalls(dt){fireWalls=fireWalls.filter(w=>w.until>currentTime);
 for(const w of fireWalls){if(currentTime-w.t0<.4)continue;for(const o of enemies)if(o.hp>0&&onWall(w,o)){damage(o,SILLON.burn*dt);o.slowUntil=currentTime+.15}}}
function drawFireWalls(){const F=['#5a1408','#a82a10','#e85a18','#ff9a30','#ffd060','#fff4c0'];
 for(const w of fireWalls){const age=currentTime-w.t0,head=Math.min(1,age/.4)*w.len,fade=Math.min(1,(w.until-currentTime)/.5),s=Math.max(2,Z()*.12);
  for(let d=0;d<head;d+=.22){const p=project(w.x+w.dx*d,0,w.z+w.dz*d),fl=Math.sin(currentTime*23+d*7)*.5+.5,hgt=(head-d<1?1.6:.9)*fade;
   for(let k=0;k<3;k++){const y=p.y-(k*.35+fl*.3)*hgt*Z();ctx.fillStyle=F[Math.max(0,Math.min(5,Math.round(5-k*1.5-fl-(1-fade)*3)))];ctx.fillRect(p.x-s/2+Math.sin(d*13+k)*s,y,s,s)}}}}
function fightBusy(u){const F=FIGHT[u.role];return F?u.attack>(u.role==='flammes'?-.05:F.cd*.45):u.attack>.25}

// Pas de filons ni de rochers dans la salle : seul l'Ingénieur creuse la roche de la montagne.
let blocks=[];
function resetBlocks(){blocks=[];DIG_HITS_DONE.clear();DUG.clear();for(const d of DEITY_PORTALS)d.activeUntil=0}
function blockAt(){return null}
function hitBlock(){return null}
function blocksOverlap(){return false}
function drawBlock(){}

// ----- Roche creusable : cases de 4 × 4 unités de la montagne, creusées par l'Ingénieur -----
const DUG=new Set(),DIG_HITS_DONE=new Map(),DIG_HITS=4,HIT_TIME=1,ENGINEER_DIG=1;// ENGINEER_DIG : cases déblayées par seconde
// l'Ingénieur enchaîne sur une case de roche voisine de celle qu'il vient de déblayer
function nextDig(u){const c=u.job.cell;let best=null,bd=1e9;for(const[di,dj]of[[1,0],[-1,0],[0,1],[0,-1]]){const n=digCellAt(c.i+di,c.j+dj,u);if(!n)continue;const d=Math.hypot(n.at.x-u.x,n.at.z-u.z);if(d<bd){bd=d;best=n}}
 if(!best)return false;u.job.cell=best;u.job.at=best.at;u.job.work=0;return true}
function isDug(x,z){return DUG.size>0&&DUG.has(Math.floor(x/4)+','+Math.floor(z/4))}
// case de roche visée : dans les limites du monde, hors du mur des portails, et accessible depuis un sol praticable voisin
function diggableCell(p){if(walkable(p.x,p.z))return null;const i0=Math.floor(p.x/4),j0=Math.floor(p.z/4);let best=null,bd=1e9;
 for(let di=-1;di<=1;di++)for(let dj=-1;dj<=1;dj++){const c=digCellAt(i0+di,j0+dj,p);if(!c)continue;const d=(di||dj?1:0)*100+Math.hypot(c.at.x-p.x,c.at.z-p.z);if(d<bd){bd=d;best=c}}return best}
// case de roche destructible (accessible ou non) : pas encore creusée, pas entièrement praticable, hors des limites interdites
function isDiggableRock(i,j){const x=i*4,z=j*4;if(DUG.has(i+','+j)||walkable(x+2,z+2)&&walkable(x+.5,z+.5)&&walkable(x+3.5,z+3.5))return false;
 return!(x<WORLD.x0+8||x+4>WORLD.x1-8||z<WORLD.z0+8||Math.abs(x+2)<52&&z<CAVE.z0+1)}
function digCellAt(i,j,p){const x=i*4,z=j*4;if(!isDiggableRock(i,j))return null;
 // accessible : un point praticable touche l'un des bords de la case ; l'Ingénieur s'y place pour creuser
 let at=null,best=1e9;for(const t of[.3,1,2,3,3.7])for(const q of[{x:x-.6,z:z+t},{x:x+4.6,z:z+t},{x:x+t,z:z-.6},{x:x+t,z:z+4.6}]){if(!walkable(q.x,q.z))continue;const d=Math.hypot(q.x-p.x,q.z-p.z);if(d<best){best=d;at=q}}
 return at?{i,j,at}:null}
function digCell(i,j){const key=i+','+j;if(DUG.has(key))return;DUG.add(key);DIG_HITS_DONE.delete(key);const x=i*4,z=j*4;
 // sol de grotte repeint en continuité avec le sol voisin (même bruit, coordonnées du monde) : aucune jonction visible.
 // Les cases voisines déjà en partie creuses sont repeintes aussi, pour que leur bord de roche disparaisse côté case creusée.
 const hol=(a,b)=>isGalleryOpen(a,b)||isDug(a,b)||inCave(a,b)||inTunnel(a,b),g=PW.ground.getContext('2d');
 for(let di=-1;di<=1;di++)for(let dj=-1;dj<=1;dj++)paintGroundTile(g,x+di*4,z+dj*4,hol);
 // rien ne reste sur la case : décors posés dessus et rochers voisins qui la recouvrent ; nouvelle falaise au fond si la case au nord reste de la roche
 PW.objs=PW.objs.filter(o=>o.portal||o.dportal||o.orb||o.deityFx||o.evil||!(o.x>=x-.01&&o.x<x+4&&o.z>=z-.01&&o.z<=z+4.01||o.r&&o.x+o.r>x&&o.x-o.r<x+4&&o.z>z-.2&&o.z-o.r*1.1<z+4));
 if(!walkable(x+2,z-2)){const v=(i*7+j*3&7)%6;PW.objs.push({x,z,d:z,spr:faceSprite(5,rng(v*41+5)),bx:x,bz:z,dz:z})}
 PW.objs.sort((a,b)=>a.d-b.d);WALK.version++;WALK.cache.fill(0);zone(x+2,z+2,2,'#a89c86');
 // une galerie touche la case : elle est découverte
 if(!revealGalleriesNear(x-1.5,z-1.5,x+5.5,z+5.5))say('Roche creusée : la grotte s’agrandit.',1.5);if(HUD.els)buildMiniMap()}

// ----- Survol : contour carré de la case de roche destructible sous le curseur -----
const DIG_HOVER={x:0,y:0,on:false},GAME_CANVAS=document.getElementById('game');
GAME_CANVAS.addEventListener('pointermove',ev=>{DIG_HOVER.x=ev.clientX;DIG_HOVER.y=ev.clientY;DIG_HOVER.on=true});
GAME_CANVAS.addEventListener('pointerleave',()=>{DIG_HOVER.on=false});
function drawDigHover(){if(!DIG_HOVER.on||ended||HUD.mode||typeof PAN!=='undefined'&&PAN.moved)return;
 const p=groundFromScreen(DIG_HOVER.x,DIG_HOVER.y),i=Math.floor(p.x/4),j=Math.floor(p.z/4);if(!isDiggableRock(i,j))return;
 const a=project(i*4,0,j*4),b=project(i*4+4,0,j*4+4),lw=Math.max(2,Math.round(PX)),x0=Math.round(a.x)+lw/2,y0=Math.round(a.y)+lw/2,w=Math.round(b.x)-Math.round(a.x)-lw,h=Math.round(b.y)-Math.round(a.y)-lw;
 ctx.save();ctx.lineWidth=lw;ctx.strokeStyle='#0009';ctx.strokeRect(x0+lw,y0+lw,w,h);
 ctx.globalAlpha=.75+.25*Math.sin(currentTime*6);ctx.strokeStyle='#f8df93';ctx.strokeRect(x0,y0,w,h);ctx.restore();
 captureDecorLayer(x0-lw*2,y0-lw*2,w+lw*5,h+lw*5)}

// ----- Tâches -----
function nearestOf(p,list){let best=null,d=1e9;for(const o of list){const nd=Math.hypot(o.x-p.x,o.z-p.z);if(nd<d){d=nd;best=o}}return best}
function setJob(u,job){cancelBuild(u);cancelOrb(u);cancelTurretRepair(u);u.job={phase:'go',carry:0,work:0,...job};u.stance='attack';u.forceMove=false}
function clearJob(u){if(!u)return;delete u.job}
function ownTemples(u){return buildings.filter(b=>b.complete&&BUILDINGS[b.type].deity===u.role)}
function sendToPray(u,t=nearestOf(u,ownTemples(u))){if(!t||!prays(u))return false;setJob(u,{type:'pray',temple:t});return true}

// ----- Ordres du clic droit : roche (Ingénieur) ou temple (adeptes) -----
function orderAdepts(p){const engs=selected.filter(u=>u.role==='engineer'&&u.hp>0&&!u.hidden),crew=selected.filter(u=>prays(u)&&u.hp>0);
 if(engs.length){const cell=diggableCell(p);if(cell){for(const u of engs)setJob(u,{type:'dig',cell,at:cell.at});say('Creusement · l’Ingénieur déblaie une case par seconde puis attaque la case voisine.',2);return true}}
 const t=buildings.find(b=>b.complete&&isTemple(b)&&Math.abs(b.x-p.x)<half(b)&&Math.abs(b.z-p.z)<half(b));
 if(t&&crew.length){const own=crew.filter(u=>u.role===BUILDINGS[t.type].deity);for(const u of own)sendToPray(u,t);
  if(own.length){const r=RES_INFO[DEITY_RES[own[0].role]].name;say('Prière au '+BUILDINGS[t.type].name+' · +1 '+r+' / s par adepte.',2)}
  else say('Un adepte ne prie qu’au temple de son propre dieu.',2);return!!own.length||crew.length===selected.length}
 return false}

// ----- Simulation des tâches -----
function prayerSpot(u,t){const i=Math.max(0,units.filter(o=>o.job&&o.job.type==='pray'&&o.job.temple===t&&o.hp>0).indexOf(u)),h=half(t);
 let s={x:t.x-4+(i%5)*2,z:t.z+h+1+Math.floor(i/5)*1.6};if(!walkable(s.x,s.z))s={x:t.x-4+(i%5)*2,z:t.z-h-1-Math.floor(i/5)*1.6};return s}
function updateAdepts(dt){updateFireWalls(dt);
 for(const u of units){const j=u.job;u.working=false;if(!j||u.hp<=0)continue;
  const at=p=>Math.hypot(u.x-p.x,u.z-p.z)<.7,go=p=>{u.tx=p.x;u.tz=p.z};
  if(j.type==='pray'){const t=j.temple;if(!buildings.includes(t)||!t.complete){clearJob(u);continue}const s=prayerSpot(u,t);go(s);if(!at(s))continue;u.working=true;
   const r=DEITY_RES[u.role];RES[r]+=dt;t._acc=(t._acc||0)+dt;if(t._acc>=5){t._acc-=5;prayPopups.push({x:t.x,z:t.z,amount:5,res:r,at:currentTime})}continue}
  if(j.type==='dig'){const c=j.cell,key=c.i+','+c.j,eng=u.role==='engineer';if(DUG.has(key)){if(!(eng&&nextDig(u)))clearJob(u);continue}go(j.at);if(!at(j.at))continue;u.working=true;j.work+=dt*(eng?ENGINEER_DIG*DIG_HITS:.25);
   while(j.work>=HIT_TIME){j.work-=HIT_TIME;const h=(DIG_HITS_DONE.get(key)||0)+1;DIG_HITS_DONE.set(key,h);flash(c.i*4+2,c.j*4+2,'#a89c86');if(h>=DIG_HITS){digCell(c.i,c.j);if(!(eng&&nextDig(u)))clearJob(u);break}}continue}
  clearJob(u)}
 for(const d of DEITY_PORTALS)d.active=currentTime<(d.activeUntil||0)}
function adeptStatus(u){if(!isAdept(u))return null;const j=u.job;
 if(!j)return FIGHT[u.role]?FIGHT[u.role].status:'En attente d’ordres';
 if(j.type==='pray')return u.working?'Prie au '+BUILDINGS[j.temple.type].name+' · +1 '+RES_INFO[DEITY_RES[u.role]].name+' / s':'Se rend au '+BUILDINGS[j.temple.type].name;
 if(j.type==='dig')return'Creuse la roche · '+(DIG_HITS_DONE.get(j.cell.i+','+j.cell.j)||0)+' / '+DIG_HITS;
 return'En attente d’ordres'}

// ----- Rendu des adeptes (personnages des bâtiments, agrandis) -----
function drawAdept(u){const p=project(u.x,0,u.z),moving=Math.hypot(u.x-(u._ax??u.x),u.z-(u._az??u.z))>.001;if(Math.abs(u.x-(u._ax??u.x))>.001)u._face=u.x<u._ax?-1:1;u._ax=u.x;u._az=u.z;
 circle3(u.x,u.z,.7,'#0b1615a0');if(selected.includes(u)){circle3(u.x,u.z,1.45,'#ead08c55')}
 ctx.save();ctx.translate(p.x,p.y);const s=Z()/16*BUILDING_CHAR_K;ctx.scale(s,s);if(u._face<0)ctx.scale(-1,1);const t=currentTime+u.id*.37;
 const busy=u.working||fightBusy(u);AdeptArt.draw(ctx,0,0,u.role,t,moving?'walk':busy?'work':'idle');
 ctx.restore();
 const q=project(u.x,3.9,u.z);if(u.hp<u.max){ctx.fillStyle='#000a';ctx.fillRect(q.x-12,q.y,24,3);ctx.fillStyle='#8fd16a';ctx.fillRect(q.x-12,q.y,24*u.hp/u.max,3)}
 drawLevelBadge(u,q.x,q.y-3)}
function drawLevelBadge(u,x,y){if(lvl(u)<2)return;ctx.save();ctx.textAlign='center';ctx.font='bold 10px system-ui';ctx.fillStyle='#0b0a09cc';ctx.fillText('★'+lvl(u),x+1,y+1);ctx.fillStyle='#ffe08a';ctx.fillText('★'+lvl(u),x,y);ctx.restore()}

// ----- Héros Tireur : invoqué depuis l'Ancre, franchit le portail central -----
const HERO_COST={forge:100,vie:100,discipline:100,savoir:100};
function canSummonHero(){return!ended&&ORB.active&&canPay(HERO_COST)}
function summonHero(){if(ended)return;if(!HUD.anchor){say('Cliquez sur l’Ancre pour invoquer le héros Tireur.',3);return}
 if(!ORB.active){say('L’Ancre doit d’abord être réactivée par l’Ingénieur.',3);return}
 if(!canPay(HERO_COST)){say('Héros Tireur : '+costText(HERO_COST)+' requis.',3);return}pay(HERO_COST);
 // même séquence que l'arrivée de l'Ingénieur : le portail s'active, le Tireur en sort, il se referme
 const u=soldier('Tireur',PORTAL.x,PORTAL.z+.8,'shooter');u.hidden=true;u.exit={x:PORTAL.x+3,z:core.z+4};u.arrival='Le héros Tireur franchit le portail.';openPortal();
 say('Le portail s’éveille…',2);updateHUD(true)}
