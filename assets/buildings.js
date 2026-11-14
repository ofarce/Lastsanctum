'use strict';
// Bâtiments du sanctuaire : un temple par dieu, puis les bâtiments que chaque temple débloque.
// Ressources, réactivation de l'Ancre, invocation des adeptes, Caserne et Puits des Âmes.
// Toutes les durées suivent le temps de simulation.

const CELL=4; // une case de construction = 4 × 4 unités
// ----- Ressources -----
const RES={forge:0,vie:0,discipline:0,savoir:0};
const RES_INFO={forge:{name:'Forge',icon:'iron'},vie:{name:'Vie',icon:'heart'},discipline:{name:'Discipline',icon:'shield'},savoir:{name:'Savoir',icon:'book'}};
const RES_ORDER=['forge','vie','discipline','savoir'];
const DEITY_RES={sigil:'savoir',aether:'forge',medeina:'vie',indra:'discipline'};
const canPay=c=>Object.entries(c).every(([k,v])=>RES[k]>=v);
const pay=c=>{for(const[k,v]of Object.entries(c))RES[k]-=v};
const refund=c=>{for(const[k,v]of Object.entries(c))RES[k]+=v};
const costText=c=>Object.entries(c).map(([k,v])=>v+' '+RES_INFO[k].name).join(' + ');
function resetResources(){for(const k of RES_ORDER)RES[k]=0}

// ----- Catalogue -----
// size : côté en cases de 4 unités (3 par défaut, 2 pour les petits bâtiments) ; art : sprite de pixel-buildings.js
const BUILDINGS={
 sigil:{name:'Temple de Sigil',cost:{savoir:20},deity:'sigil',art:'temple',key:'g',icon:'rune',verse:'templeJob',time:4,lore:'Ses adeptes y prient pour le Savoir.'},
 aether:{name:'Temple d’Aether',cost:{forge:20},deity:'aether',art:'foundry',key:'e',icon:'iron',verse:'foundryJob',time:4,lore:'Ses adeptes y prient pour la Forge.'},
 medeina:{name:'Temple de Medeina',cost:{vie:20},deity:'medeina',art:'sawmill',key:'v',icon:'wood',verse:'sawmillJob',time:4,lore:'Ses adeptes y prient pour la Vie.'},
 indra:{name:'Temple d’Indra',cost:{discipline:20},deity:'indra',art:'barracks',key:'i',icon:'sword',verse:'barracksJob',time:4,lore:'Ses adeptes y prient pour la Discipline.'},
 library:{name:'Bibliothèque',cost:{savoir:200},requires:'sigil',art:'library',key:'l',icon:'book',verse:'templeJob',time:8,lore:'Les rouleaux de Sigil y sont rassemblés.'},
 forge:{name:'Forge',cost:{forge:200},requires:'aether',art:'forge',key:'f',icon:'hammer',verse:'foundryJob',time:8,lore:'L’enclume d’Aether y résonne.'},
 workshop:{name:'Atelier',cost:{forge:200},requires:'aether',art:'workshop',key:'t',icon:'repair',verse:'foundryJob',time:8,lore:'Établis et outils des artisans d’Aether.'},
 bedroom:{name:'Chambre à coucher',cost:{vie:200},requires:'medeina',art:'bedroom',size:2,key:'n',icon:'people',verse:'sawmillJob',time:8,lore:'Le repos que Medeina accorde aux Exilés.'},
 soulwell:{name:'Puits des Âmes',cost:{vie:200},requires:'medeina',art:'soulwell',size:2,key:'u',icon:'spirit',verse:'sawmillJob',time:8,lore:'Medeina y rend leur souffle aux défunts, avec toute leur expérience.'},
 caserne:{name:'Caserne',cost:{discipline:200},requires:'indra',art:'caserne',key:'c',icon:'shield',verse:'barracksJob',time:8,lore:'Les disciples d’Indra y forment les combattants.'}};
const TEMPLE_TYPES=['sigil','aether','medeina','indra'];
// sprites retenus pour les nouveaux bâtiments (planches de pixel-buildings.js)
Object.assign(PixelBuildings.PICKS,{
 library:{set:'indra',i:2,anchor:[160,178]},forge:{set:'fonderie',i:4,anchor:[160,182]},workshop:{set:'scierie',i:3,anchor:[158,176]},
 bedroom:{set:'caserne',i:2,anchor:[160,180]},soulwell:{set:'fonderie',i:0,anchor:[150,166]},caserne:{set:'caserne',i:4,anchor:[160,182]}});
const SUMMON_COST=50,CASERNE_COST={discipline:100},CASERNE_TIME=6,CASERNE_QUEUE=5,REVIVE_COST={vie:200};
const CASERNE_UNITS=[{id:'flammes',label:'Lance-flammes',key:'l',icon:'flame'},{id:'archer',label:'Archer',key:'u',icon:'bow'},{id:'lame',label:'Épée et bouclier',key:'e',icon:'shield'}];

let buildings=[],templePointer=null,FALLEN=[],prayPopups=[];
const half=b=>(BUILDINGS[b.type||b].size||3)*CELL/2;
const isTemple=b=>!!BUILDINGS[b.type].deity;
const unlocked=type=>{const r=BUILDINGS[type].requires;return!r||buildings.some(b=>b.type===r&&b.complete)};
function resetBuildings(){buildings=[];templePointer=null;FALLEN=[];prayPopups=[];for(const u of units){delete u.buildJob;delete u.orbJob}resetOrb()}

// ----- Placement -----
function snapFor(type,p){if(!p||!Number.isFinite(p.x)||!Number.isFinite(p.z))return p;const odd=(BUILDINGS[type].size||3)%2;
 return odd?{x:Math.floor(p.x/CELL)*CELL+CELL/2,z:Math.floor(p.z/CELL)*CELL+CELL/2}:{x:Math.round(p.x/CELL)*CELL,z:Math.round(p.z/CELL)*CELL}}
// sol constructible : praticable, hors couloir, chemin de la jungle, allée centrale et rangée des portails
function buildableGround(x,z){if(!walkable(x,z)||inTunnel(x,z)||inPath(x,z))return false;if(inCave(x,z)&&(Math.abs(x)<12||z<-140))return false;return true}
function validSite(type,p){if(!p||!Number.isFinite(p.x)||!Number.isFinite(p.z))return false;const h=(BUILDINGS[type].size||3)*CELL/2;
 for(let x=p.x-h+.5;x<=p.x+h-.4;x+=2)for(let z=p.z-h+.5;z<=p.z+h-.4;z+=2)if(!buildableGround(x,z))return false;
 if(buildings.some(b=>Math.abs(b.x-p.x)<half(b)+h&&Math.abs(b.z-p.z)<half(b)+h))return false;
 if(turrets.some(t=>Math.abs(t.x-p.x)<h+5&&Math.abs(t.z-p.z)<h+5))return false;
 if(Math.abs(core.x-p.x)<h+4&&Math.abs(core.z-p.z)<h+4)return false;
 return!units.some(u=>u.hp>0&&!u.hidden&&Math.abs(u.x-p.x)<h+.6&&Math.abs(u.z-p.z)<h+.6)}
function builder(){return selected.find(u=>u.role==='engineer'&&u.hp>0&&!u.hidden)}
function armBuild(type){if(ended||!builder())return;const D=BUILDINGS[type];
 if(!unlocked(type)){say(D.name+' : construisez d’abord un '+BUILDINGS[D.requires].name+'.',3);return}
 if(!canPay(D.cost)){say(D.name+' : '+costText(D.cost)+' requis.',3);return}
 HUD.mode='build';HUD.buildType=type;canvas.style.cursor='crosshair';updateHUD(true);say(D.name+' · '+costText(D.cost)+' · cliquez un emplacement libre. Échap : annuler.',4)}
// côté libre où l'Ingénieur se tient pendant l'Énonciation
function workSpot(type,p){const h=(BUILDINGS[type].size||3)*CELL/2;for(const q of[{x:p.x-h-2,z:p.z+3},{x:p.x+h+2,z:p.z+3},{x:p.x,z:p.z+h+2},{x:p.x,z:p.z-h-2}])if(walkable(q.x,q.z))return q;return{x:p.x-h-2,z:p.z+3}}
function placeBuilding(p){const u=builder(),type=HUD.buildType;if(ended||!u||!type||HUD.mode!=='build')return;const D=BUILDINGS[type];p=snapFor(type,p);
 if(!validSite(type,p)){say('Emplacement impossible : il faut un sol dégagé (grotte, galerie creusée ou jungle).',2);return}
 if(!canPay(D.cost)){say(D.name+' : '+costText(D.cost)+' requis.',3);HUD.mode=null;updateHUD(true);return}
 cancelWork(u);pay(D.cost);const b={id:buildings.length?Math.max(...buildings.map(o=>o.id))+1:0,type,x:p.x,z:p.z,owner:u,progress:0,complete:false,queue:[],train:0};b.spot=workSpot(type,p);
 buildings.push(b);u.buildJob=b;u.tx=b.spot.x;u.tz=b.spot.z;u.stance='attack';HUD.mode=null;HUD.menu=null;updateHUD(true);say('L’Ingénieur rejoint le chantier · '+D.name+' · Énonciation : '+D.time+' s.',3)}
function cancelBuild(u){if(!u)return;const b=u.buildJob;if(b&&!b.complete){buildings=buildings.filter(o=>o!==b);refund(BUILDINGS[b.type].cost);if(HUD.building===b)HUD.building=null}delete u.buildJob}
function cancelWork(u){if(!u)return;cancelBuild(u);cancelOrb(u);if(typeof cancelTurretRepair==='function')cancelTurretRepair(u);if(typeof clearJob==='function')clearJob(u)}
function updateBuildings(dt){updateOrb(dt);
 for(const b of[...buildings]){const D=BUILDINGS[b.type];
  if(!b.complete){const u=b.owner;if(!u||u.hp<=0||u.hidden||u.buildJob!==b){if(u)cancelBuild(u);else buildings=buildings.filter(o=>o!==b);continue}
   if(Math.hypot(u.x-b.spot.x,u.z-b.spot.z)>.5)continue;b.progress=Math.min(D.time,b.progress+dt);if(b.progress<D.time)continue;
   b.complete=true;b.finishedAt=currentTime;delete u.buildJob;zone(b.x,b.z,half(b),'#e8d9a8');
   say(D.name+' achevé.'+(D.deity?' Sélectionnez-le pour invoquer un adepte de '+DEITY_PORTALS.find(d=>d.id===D.deity).name+' ('+SUMMON_COST+' '+RES_INFO[DEITY_RES[D.deity]].name+').':unlockText(b.type)),4);updateHUD(true);continue}
  if(b.type==='caserne'&&b.queue.length){b.train+=dt;if(b.train>=CASERNE_TIME){b.train=0;spawnTrained(b,b.queue.shift())}}}
 prayPopups=prayPopups.filter(p=>currentTime-p.at<1.8)}
function unlockText(type){const next=Object.entries(BUILDINGS).filter(([,D])=>D.requires===type).map(([,D])=>D.name);return next.length?' Nouveau : '+next.join(', ')+'.':''}
function hitBuilding(p){return[...buildings].sort((a,b)=>b.z-a.z).find(b=>{const h=half(b);return Math.abs(b.x-p.x)<h&&p.z>b.z-h-h*1.1&&p.z<b.z+h})}
function selectedBuilding(){const b=HUD.building;return b&&buildings.includes(b)?b:null}

// ----- Temples : invocation d'un adepte du dieu, qui part aussitôt prier -----
function summonCost(b){return{[DEITY_RES[BUILDINGS[b.type].deity]]:SUMMON_COST}}
function canSummonAt(b){return!ended&&b&&b.complete&&isTemple(b)&&canPay(summonCost(b))}
function summonAdept(b){if(ended||!b)return;const id=BUILDINGS[b.type].deity;if(!b.complete||!id)return;const cost=summonCost(b);
 if(!canPay(cost)){say('Invocation : '+costText(cost)+' requis.',3);return}pay(cost);
 const d=DEITY_PORTALS.find(p=>p.id===id);d.activeUntil=currentTime+3.5;
 const u=soldier(ADEPT[id].name,d.x,PORTAL.z+1.8,id);u.hp=u.max=ADEPT[id].hp;u.radius=.55;flash(d.x,PORTAL.z+1,DEITY_LOOK[id].glow[3]);
 setJob(u,{type:'pray',temple:b});say(ADEPT[id].name+' franchit le portail et rejoint son temple pour prier.',2);updateHUD(true)}

// ----- Caserne : entraînement des trois combattants -----
function canTrain(b){return!ended&&b&&b.complete&&b.type==='caserne'&&b.queue.length<CASERNE_QUEUE&&canPay(CASERNE_COST)}
function trainUnit(b,id){if(!b||b.type!=='caserne'||!b.complete)return;if(b.queue.length>=CASERNE_QUEUE){say('File d’entraînement pleine.',2);return}
 if(!canPay(CASERNE_COST)){say('Entraînement : '+costText(CASERNE_COST)+' requis.',3);return}pay(CASERNE_COST);b.queue.push(id);
 say(ADEPT[id].name+' à l’entraînement · '+CASERNE_TIME+' s.',2);updateHUD(true)}
function spawnTrained(b,id){const h=half(b),u=soldier(ADEPT[id].name,b.x+(Math.random()-.5)*2,b.z+h+1,id);u.hp=u.max=ADEPT[id].hp;u.radius=.55;
 const out={x:b.x+(Math.random()-.5)*5,z:b.z+h+4};u.tx=out.x;u.tz=out.z;pushOutOfRock(u);flash(u.x,u.z,'#f0dba4');say(ADEPT[id].name+' sort de la caserne.',2);updateHUD(true)}

// ----- Puits des Âmes : les unités tombées reviennent avec toute leur expérience -----
function onUnitDeath(u){if(u.role==='engineer')return;cancelWork(u);u.forceMove=false;selected=selected.filter(o=>o!==u);if(!FALLEN.includes(u))FALLEN.push(u);
 say(u.name+' est tombé'+(buildings.some(b=>b.type==='soulwell'&&b.complete)?' · le Puits des Âmes peut le rappeler.':'.'),2.5)}
function canRevive(b){return!ended&&b&&b.complete&&b.type==='soulwell'&&FALLEN.length>0&&canPay(REVIVE_COST)}
function reviveUnit(b,u){if(!b||b.type!=='soulwell'||!b.complete||!FALLEN.includes(u))return;if(!canPay(REVIVE_COST)){say('Résurrection : '+costText(REVIVE_COST)+' requis.',3);return}
 pay(REVIVE_COST);FALLEN=FALLEN.filter(o=>o!==u);const h=half(b);u.hp=u.max;u.dead=false;u.x=b.x;u.z=b.z+h+1;u.tx=b.x;u.tz=b.z+h+3.5;u._lx=u.x;u._lz=u.z;u._path=null;u.attack=0;u.stance='attack';pushOutOfRock(u);
 zone(u.x,u.z,2.5,'#9be27a');flash(u.x,u.z,'#effde0');say(u.name+' revient du Puits des Âmes · niveau '+(u.level||1)+'.',3);updateHUD(true)}

// ----- L'Ancre : l'Ingénieur doit la réactiver ; elle éveille les tourelles et produit les quatre ressources -----
const ORB={active:false,progress:0,owner:null,complete:false,finishedAt:null,stones:[],time:8,spot:null};
function resetOrb(){Object.assign(ORB,{active:false,progress:0,owner:null,complete:false,finishedAt:null,stones:[]});ORB.spot={x:core.x-5,z:core.z+4}}
function cancelOrb(u){if(!u)return;if(ORB.owner===u&&!ORB.active)ORB.owner=null;delete u.orbJob}
function orderOrb(u=builder()||units.find(o=>o.role==='engineer'&&o.hp>0&&!o.hidden)){if(ended)return;
 if(ORB.active){say('L’Ancre est éveillée · +1 de chaque ressource par seconde.',2);return}
 if(!u){say('Attendez la sortie de l’Ingénieur.',2);return}cancelWork(u);ORB.owner=u;u.orbJob=ORB;u.tx=ORB.spot.x;u.tz=ORB.spot.z;u.stance='attack';
 selected=[u];HUD.anchor=false;HUD.menu=null;updateHUD(true);say('L’Ingénieur rejoint l’Ancre pour la réactiver · '+ORB.time+' s d’Énonciation.',3)}
function updateOrb(dt){if(ORB.active){for(const k of RES_ORDER)RES[k]+=dt;return}const u=ORB.owner;if(!u)return;
 if(u.hp<=0||u.hidden||u.orbJob!==ORB){ORB.owner=null;return}if(Math.hypot(u.x-ORB.spot.x,u.z-ORB.spot.z)>.6)return;
 ORB.progress=Math.min(ORB.time,ORB.progress+dt);if(ORB.progress<ORB.time)return;
 ORB.active=ORB.complete=true;ORB.finishedAt=currentTime;delete u.orbJob;zone(core.x,core.z,7,'#bba7ff');zone(core.x,core.z,12,'#8777ac');
 if(typeof activateTurrets==='function')activateTurrets();nextWave=currentTime+20;
 say('L’Ancre s’éveille ! Les gardes tyriennes de l’entrée se rallument · premier assaut dans 20 s.',5);updateHUD(true)}

// ----- Énonciation : miroir et bulle de l'Ingénieur sur chaque chantier -----
function incantationSites(){const T=typeof TURRET_CONFIG!=='undefined'?TURRET_CONFIG.repairTime:8;
 return[...buildings.map(b=>({b,at:b.spot,tol:.5,dur:BUILDINGS[b.type].time,owner:b.owner,verse:BUILDINGS[b.type].verse,job:'buildJob'})),
  {b:ORB,at:ORB.spot,tol:.6,dur:ORB.time,owner:ORB.owner,verse:'turretJob',job:'orbJob'},
  ...(typeof turrets!=='undefined'?turrets:[]).map(b=>({b,at:turretWorkPoint(b),tol:.6,dur:T,owner:b.owner,verse:'turretJob',job:'turretJob'}))]}
function incantationActive(c){const u=c.owner,b=c.b;return!!(u&&!b.complete&&b.progress>0&&u[c.job]===b&&Math.hypot(u.x-c.at.x,u.z-c.at.z)<=c.tol)}
function templeKneeling(u){if(!window.TempleIncantation)return false;const job=u.buildJob||u.orbJob||u.turretJob;if(!job)return false;const c=incantationSites().find(c=>c.b===job);return!!c&&incantationActive(c)}
function drawTempleOverlays(){if(!window.TempleIncantation)return;const k=Z()*.86/8;
 for(const c of incantationSites()){const b=c.b,u=c.owner;if(!u)continue;const fin=b.complete&&b.finishedAt!=null?currentTime-b.finishedAt:Infinity,active=incantationActive(c);if(!active&&!(fin<2.4))continue;
  const[nx,ny]=natP(u.x,0,u.z),fx=nx*PX,fy=ny*PX,face=u._face||1,act=active?Math.min(1,b.progress/.8):0;
  TempleIncantation.drawMirror(ctx,fx,fy,k,currentTime,act,active?b.stones||[]:[],fin,face);
  TempleIncantation.drawSpeech(ctx,fx,fy-58*k,k,TempleIncantation.verse(b.complete?1:b.progress/c.dur,c.dur,fin,c.verse),currentTime)}}

// ----- Rendu -----
function footprintPath(x,z,h){const c=[[x-h,z-h],[x+h,z-h],[x+h,z+h],[x-h,z+h]].map(([a,b])=>project(a,0,b));ctx.beginPath();c.forEach((q,i)=>i?ctx.lineTo(q.x,q.y):ctx.moveTo(q.x,q.y));ctx.closePath()}
function drawFootprint(x,z,h,stroke,fill){ctx.save();footprintPath(x,z,h);if(fill){ctx.fillStyle=fill;ctx.fill()}ctx.lineWidth=Math.max(1,Z()*.12);ctx.strokeStyle=stroke;ctx.stroke();ctx.restore()}
function drawBuildGrid(){for(const b of buildings)drawFootprint(b.x,b.z,half(b),b.complete?(HUD.building===b?'#ffe0a0cc':'#e8d9a866'):'#c79cff99','#1a120a2a')}
// mode construction : cases libres visibles, puis empreinte sous le pointeur
function drawBuildCells(){if(HUD.mode!=='build'||!HUD.buildType)return;const a=groundFromScreen(0,0),b=groundFromScreen(W,H);ctx.save();ctx.lineWidth=1;
 for(let x=Math.floor(a.x/CELL)*CELL;x<b.x;x+=CELL)for(let z=Math.floor(a.z/CELL)*CELL;z<b.z;z+=CELL){const cx=x+CELL/2,cz=z+CELL/2;if(!buildableGround(cx,cz)||!buildableGround(x+.5,z+.5)||!buildableGround(x+3.5,z+3.5))continue;
  const busy=buildings.some(o=>Math.abs(o.x-cx)<half(o)&&Math.abs(o.z-cz)<half(o));footprintPath(cx,cz,CELL/2);ctx.strokeStyle=busy?'#f28d8040':'#a4f2ca40';ctx.stroke()}
 ctx.restore();const p=templePointer&&snapFor(HUD.buildType,templePointer);if(p&&Number.isFinite(p.x)){const ok=validSite(HUD.buildType,p);drawFootprint(p.x,p.z,half(HUD.buildType),ok?'#a4f2ca':'#f28d80',ok?'#a4f2ca30':'#f28d8030')}}
function drawBuildPreview(){if(HUD.mode!=='build'||!HUD.buildType||!templePointer)return;const p=snapFor(HUD.buildType,templePointer),q=project(p.x,0,p.z),f=(BUILDINGS[HUD.buildType].size||3)/3,s=Z()/16*f;
 ctx.save();ctx.translate(q.x-160*s,q.y-186*s);ctx.scale(s,s);TempleKit.footprint(ctx,currentTime,{color:validSite(HUD.buildType,p)?'#a4f2ca':'#f28d80'});ctx.restore()}
function drawBuilding(b){const D=BUILDINGS[b.type],p=project(b.x,0,b.z),f=(D.size||3)/3,k=Z()*.86/8*f,s=Z()/16*f;
 if(!b.complete){ctx.save();ctx.translate(p.x-160*s,p.y-186*s);ctx.scale(s,s);TempleKit.footprint(ctx,currentTime);ctx.restore();
  if(window.TempleIncantation)b.stones=TempleIncantation.drawSite(ctx,p.x,p.y,k,b.progress/D.time,D.time,D.art);else PixelBuildings.draw(ctx,D.art,p.x,p.y,k,currentTime,b.progress/D.time)}
 else PixelBuildings.draw(ctx,D.art,p.x,p.y,k,currentTime,1);
 const kk=Z()*.86/8;ctx.save();ctx.textAlign='center';ctx.font='bold 10px system-ui';ctx.fillStyle='#ead6a5';
 const y=p.y+half(b)*kk*7.3;ctx.fillText(!b.complete?D.name.toUpperCase()+' · '+Math.floor(b.progress/D.time*100)+' %':D.name.toUpperCase(),p.x,y);
 if(b.complete&&b.type==='caserne'&&b.queue.length){ctx.fillStyle='#ffb050';ctx.fillText('ENTRAÎNEMENT · '+ADEPT[b.queue[0]].name.toUpperCase()+' · '+Math.ceil(CASERNE_TIME-b.train)+' s'+(b.queue.length>1?' · +'+(b.queue.length-1):''),p.x,y+13)}
 if(b.complete&&b.type==='soulwell'&&FALLEN.length){ctx.fillStyle='#9be27a';ctx.fillText(FALLEN.length+' ÂME'+(FALLEN.length>1?'S':'')+' EN ATTENTE',p.x,y+13)}
 if(b.complete&&isTemple(b)){const n=units.filter(u=>u.hp>0&&u.working&&u.job&&u.job.type==='pray'&&u.job.temple===b).length;if(n){ctx.fillStyle='#bfe8ff';ctx.fillText(n+' EN PRIÈRE · +'+n+' '+RES_INFO[DEITY_RES[D.deity]].name.toUpperCase()+' / s',p.x,y+13)}}
 ctx.restore()}
function drawPrayFeedback(){for(const p of prayPopups){const a=currentTime-p.at,q=project(p.x,0,p.z),s=Z()/16;ctx.save();ctx.globalAlpha=a<.3?a/.3:a<1.3?1:Math.max(0,1-(a-1.3)/.5);
 ctx.translate(q.x,q.y-(90+20*Math.min(1,a/.6))*s);ctx.scale(s,s);ctx.textAlign='center';ctx.font='bold 16px Georgia';ctx.fillStyle='#f8e5b7';ctx.fillText('+'+p.amount+' '+RES_INFO[p.res].name,0,0);ctx.restore()}}
