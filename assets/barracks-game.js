'use strict';
// Proposition 01 : la Cour du Trident. Timings tied to simulation, no preview reset.
let barracks=[];
const BARRACKS_BUILD_TIME=3,INDRA_TRAIN_TIME=6;
function resetBarracks(){barracks=[];resetBarracksResearch();for(const u of units)delete u.barracksJob}
function cancelBarracks(u){if(!u)return;barracks=barracks.filter(b=>b.owner!==u||b.complete);delete u.barracksJob}
function armBarracks(){if(ended||HUD.anchor)return;if(!builderFor('barracks')){say('Caserne : sélectionnez l’Ingénieur.',3);return}HUD.mode=HUD.mode==='barracks'?null:'barracks';updateHUD(true);if(HUD.mode)say('Caserne · gratuite · construite par l’Ingénieur. Choisissez un emplacement.',3)}
function placeBarracks(p){const u=builderFor('barracks');if(ended||!u)return;clearJob(u);if(!validTempleSite(p)){say('Emplacement occupé : choisissez un espace libre.',2);return}cancelTemple(u);cancelFoundry(u);cancelSawmill(u);cancelTurretRepair(u);cancelBarracks(u);const b={x:p.x,z:p.z,owner:u,complete:false,progress:0,queue:0,training:0};barracks.push(b);u.barracksJob=b;u.tx=b.x-8;u.tz=b.z+3;u.stance='attack';HUD.mode=null;updateHUD(true);say('L’Ingénieur bâtit la caserne · 3 s.',3)}
function readyBarracks(){return barracks.filter(b=>b.complete&&currentTime>=b.trainAt&&b.queue<5).sort((a,b)=>a.queue-b.queue)[0]}
function trainIndra(){if(ended)return;const b=readyBarracks();if(!b){say('Attendez un instructeur au centre d’une caserne et une place dans la file.',3);return}b.queue++;updateHUD(true);say('Soldat d’Indra ajouté à la file · gratuit · 6 s.',2)}
function updateBarracks(dt){updateBarracksResearch(dt);for(const b of [...barracks]){if(!b.complete){const u=b.owner;if(u.hp<=0||u.hidden||u.barracksJob!==b){cancelBarracks(u);continue}if(dist(u,{x:b.x-8,z:b.z+3})>.5)continue;b.progress=Math.min(BARRACKS_BUILD_TIME,b.progress+dt);if(b.progress<BARRACKS_BUILD_TIME)continue;b.complete=true;b.finishedAt=currentTime;delete u.barracksJob;say('Caserne d’Indra achevée.',3)}}}
// Rendu pixel : Cour d'armes (assets/pixel-buildings.js).
function drawBarracks(b){const p=project(b.x,0,b.z),s=Z()/16;if(b.complete&&HUD.barracks===b)circle3(b.x,b.z,FOOT,'#ead08c44');if(!b.complete){ctx.save();ctx.translate(p.x-160*s,p.y-186*s);ctx.scale(s,s);TempleKit.footprint(ctx,currentTime);ctx.restore()}if(!b.complete&&window.TempleIncantation)b.stones=TempleIncantation.drawSite(ctx,p.x,p.y,Z()*.86/8,b.progress/BARRACKS_BUILD_TIME,BARRACKS_BUILD_TIME,'barracks');else PixelBuildings.draw(ctx,'barracks',p.x,p.y,Z()*.86/8,currentTime,b.complete?1:b.progress/BARRACKS_BUILD_TIME);ctx.save();ctx.translate(p.x-160*s,p.y-186*s);ctx.scale(s,s);if(b.complete&&b.queue){ctx.strokeStyle='#e1c58b';ctx.lineWidth=2;ctx.beginPath();ctx.ellipse(160,177,36,18,0,-Math.PI/2,-Math.PI/2+b.training/INDRA_TRAIN_TIME*Math.PI*2);ctx.stroke()}ctx.restore();ctx.save();ctx.textAlign='center';ctx.fillStyle='#ead6a5';ctx.font='bold 10px system-ui';ctx.fillText(!b.complete?'CASERNE · '+Math.floor(b.progress/BARRACKS_BUILD_TIME*100)+' %':'CASERNE D’INDRA',p.x,p.y+(Z()*.86/8)*44);if(b.complete&&b.research){ctx.fillStyle='#ffb050';ctx.fillText('RECHERCHE · '+BARRACKS_UNITS.find(t=>t.id===b.research.id).label.toUpperCase()+' · '+Math.floor(b.research.progress/BARRACKS_RESEARCH.time*100)+' %',p.x,p.y+(Z()*.86/8)*44+13)}ctx.restore()}
function drawBarracksInstructor(b){if(currentTime>=b.trainAt)return;const w=b.instructor,p=project(w.x,0,w.z);ctx.save();ctx.translate(p.x,p.y);ctx.scale(Z()/16*BUILDING_CHAR_K,Z()/16*BUILDING_CHAR_K);BarracksKit.actor(ctx,0,0,currentTime,'walk');ctx.restore()}
function drawBarracksPreview(){if(HUD.mode!=='barracks'||!templePointer)return;const p=project(templePointer.x,0,templePointer.z),s=Z()/16;ctx.save();ctx.translate(p.x-160*s,p.y-186*s);ctx.scale(s,s);TempleKit.footprint(ctx,currentTime,{color:validTempleSite(templePointer)?'#a4f2ca':'#f28d80'});ctx.restore()}
function drawIndraSoldier(u){const p=project(u.x,0,u.z);if(selected.includes(u))circle3(u.x,u.z,.9,'#ead08c55');ctx.save();ctx.translate(p.x,p.y);ctx.scale(Z()/16*BUILDING_CHAR_K,Z()/16*BUILDING_CHAR_K);if(u._face<0)ctx.scale(-1,1);const walking=Math.hypot(u.x-u.tx,u.z-u.tz)>.3;BarracksKit.actor(ctx,0,0,currentTime,u.attack>.6?'train':walking?'walk':'guard',1,true);ctx.restore()}

// Constructeur requis : l'Ingénieur pour le temple, l'adepte du dieu correspondant pour les autres bâtiments.
function builderFor(kind){const role=BUILDER_ROLE[kind];return selected.find(u=>u.role===role&&u.hp>0&&!u.hidden)}

// ----- Recherches de la caserne : chaque adepte combattant se débloque une fois (fer), puis s'invoque par le portail d'Indra -----
const BARRACKS_UNITS=[
 {id:'flammes',label:'Lance-flammes',key:'l',icon:'flame'},
 {id:'archer',label:'Arc',key:'u',icon:'bow'},
 {id:'lame',label:'Épée et bouclier',key:'e',icon:'shield'}];
const BARRACKS_RESEARCH={iron:1,time:5},BARRACKS_SUMMON={iron:10};
// seek : rayon de détection ; reach : portée d'attaque ; splash : rayon de brûlure ; guard : part des dégâts subis
const FIGHT={
 flammes:{seek:9,reach:4.5,dmg:6,cd:.3,splash:2.2,status:'Garde l’Ancre · flammes à courte portée'},
 archer:{seek:17,reach:14,dmg:11,cd:.95,status:'Garde l’Ancre · tir à l’arc'},
 lame:{seek:7,reach:2.2,dmg:16,cd:.85,guard:.55,status:'Garde l’Ancre · mêlée, bouclier levé'}};
let researched={};
function resetBarracksResearch(){researched={};if(typeof HUD!=='undefined')HUD.barracks=null}
function hitBarracks(p){return barracks.find(b=>b.complete&&Math.abs(b.x-p.x)<FOOT&&p.z>b.z-FOOT-7&&p.z<b.z+FOOT)}
function selectedBarracks(){const b=HUD.barracks;return b&&barracks.includes(b)&&b.complete?b:null}
function researchingAnywhere(id){return barracks.some(b=>b.research&&b.research.id===id)}
function canBarracksAct(id){const b=selectedBarracks();if(ended||!b)return false;
 return researched[id]?iron>=BARRACKS_SUMMON.iron:!b.research&&!researchingAnywhere(id)&&iron>=BARRACKS_RESEARCH.iron}
function barracksAct(id){if(ended)return;const b=selectedBarracks(),T=BARRACKS_UNITS.find(t=>t.id===id);if(!b){say('Cliquez sur une caserne achevée.',3);return}
 if(!researched[id]){
  if(researchingAnywhere(id)){say('Recherche déjà en cours : '+T.label+'.',2);return}
  if(b.research){say('Cette caserne mène déjà une recherche.',2);return}
  if(iron<BARRACKS_RESEARCH.iron){say('Recherche : '+BARRACKS_RESEARCH.iron+' fer requis.',3);return}
  iron-=BARRACKS_RESEARCH.iron;b.research={id,progress:0};say('Recherche lancée · '+ADEPT[id].name+' · '+BARRACKS_RESEARCH.time+' s.',2);updateHUD(true);return}
 if(iron<BARRACKS_SUMMON.iron){say('Invocation : '+BARRACKS_SUMMON.iron+' fer requis.',3);return}
 iron-=BARRACKS_SUMMON.iron;const d=DEITY_PORTALS.find(p=>p.id==='indra');d.activeUntil=currentTime+3.5;
 const u=soldier(ADEPT[id].name,d.x,PORTAL.z+1.8,id);u.hp=u.max=ADEPT[id].hp;u.radius=.55;flash(d.x,PORTAL.z+1,DEITY_LOOK.indra.glow[3]);
 u.tx=d.x;u.tz=PORTAL.z+6;say(ADEPT[id].name+' franchit le portail d’Indra · en attente de vos ordres.',2);updateHUD(true)}
function updateBarracksResearch(dt){for(const b of barracks){const r=b.research;if(!b.complete||!r)continue;r.progress+=dt;if(r.progress<BARRACKS_RESEARCH.time)continue;
 researched[r.id]=true;b.research=null;say('Recherche achevée : '+ADEPT[r.id].name+' · invocable par le portail ('+BARRACKS_SUMMON.iron+' fer).',3);updateHUD(true)}}
function barracksStatus(b){if(b.research)return'Recherche · '+ADEPT[b.research.id].name+' · '+Math.floor(b.research.progress/BARRACKS_RESEARCH.time*100)+' %';
 return'Recherche : '+BARRACKS_RESEARCH.iron+' fer · '+BARRACKS_RESEARCH.time+' s · Invocation : '+BARRACKS_SUMMON.iron+' fer par le portail d’Indra'}
// attaque d'un adepte de la caserne ; le lance-flammes brûle tous les ennemis proches de la cible
function barracksStrike(u,e){const F=FIGHT[u.role],k=u.buff>0?1.5:1;u.attack=F.cd;u._face=e.x-u.x<0?-1:1;
 if(u.role==='flammes'){for(const o of enemies)if(o.hp>0&&dist(o,e)<F.splash)damage(o,F.dmg*k);blast(u,e,'#ff9a30');flash(e.x,e.z,'#ffb050');return}
 damage(e,F.dmg*k);if(u.role==='archer')arrow(u,e);else{flash(e.x,e.z,'#f0dba4');swordStrike(u,e)}}
function fightBusy(u){const F=FIGHT[u.role];return F?u.attack>(u.role==='flammes'?-.05:F.cd*.45):u.attack>.25}
