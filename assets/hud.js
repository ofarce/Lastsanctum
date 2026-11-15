'use strict';
// HUD Commandement : état de présentation uniquement ; les valeurs de combat viennent du jeu.
const HUD={anchor:false,mode:null,lastUpdate:-Infinity,portraitKey:null,mapBackground:null,els:null};
const HUD_ICONS={
 skull:'<path d="M8 19v-4c-3-1-4-3-4-6a8 8 0 0 1 16 0c0 3-1 5-4 6v4zM10 19v-3m4 3v-3"/><circle cx="8.5" cy="9" r="1.5"/><circle cx="15.5" cy="9" r="1.5"/><path d="m11 13 1-2 1 2"/>',
 iron:'<path d="m3 10 12-6 6 4-12 6zM3 10v6l6 4 12-6V8M9 14v6"/>',
 wood:'<path d="m6 15 11-9m-9 13 11-9M4 12 15 3l6 6-11 10"/><ellipse cx="6" cy="16" rx="4" ry="5" transform="rotate(-40 6 16)"/><path d="m4 14 4 4m-3-3 2 2"/>',
 spirit:'<path d="m12 1 2 8 8 3-8 2-2 9-2-9-8-2 8-3zM4 4l5 5m6 6 5 5M4 20l5-5m6-6 5-5"/>',
 people:'<circle cx="12" cy="5" r="3"/><path d="M6 21v-6a6 6 0 0 1 12 0v6zM3 21H1v-6a4 4 0 0 1 3-4m17 10h2v-6a4 4 0 0 0-3-4"/><path d="M3 5a2 2 0 0 0 0 4m18-4a2 2 0 0 1 0 4"/>',
 heart:'<path d="M12 21 3 12C-4 3 8-1 12 6c4-7 16-3 9 6z"/>',
 sword:'<path d="m5 21 12-12 3-7-7 3L1 17m2-6 10 10m-9-1 3 3M10 8l6 6"/>',
 flame:'<path d="M12 22c-4 0-7-3-7-7 0-4 3-6 4-10 1 3 3 4 4 6 1-2 1-4 0-7 4 2 8 7 8 11 0 4-3 7-7 7z"/><path d="M12 22c-2 0-3-2-3-4s2-3 3-5c1 2 3 3 3 5s-1 4-3 4z"/>',
 bow:'<path d="M6 2c9 4 9 16 0 20M6 2v20M3 12h18m-4-3 4 3-4 3"/>',
 range:'<circle cx="12" cy="12" r="9"/><circle cx="12" cy="12" r="4"/><path d="M12 1v6m0 10v6M1 12h6m10 0h6"/>',
 shield:'<path d="M12 2 3 6v7c0 5 9 9 9 9s9-4 9-9V6zM12 5v13"/>',
 boot:'<path d="m10 3 9 2-3 10 5 3v3H3v-4l5-2zM9 7l8 2m-9 2 7 2M3 18h11"/>',
 rune:'<circle cx="12" cy="12" r="7"/><path d="M12 0v24M0 12h24m-12-9 3 9-3 9-3-9z"/>',
 hammer:'<path d="m3 21 12-12m-9 13 12-12M10 4l4-3 9 8-4 4zM2 20l2 3M9 5l4 4"/>',
 repair:'<path d="m14 5 5 5 4-4c1 6-4 9-8 7L6 22l-4-4 9-9c-2-4 1-9 7-8z"/><path d="m3 2 5 5m-7-3 3-3 3 3-3 3"/>',
 flag:'<path d="M5 23V2m0 1c5-4 9 4 16 0v11c-7 4-11-4-16 0"/>',
 move:'<path d="M12 2v20M2 12h20M8 6l4-4 4 4M8 18l4 4 4-4M6 8l-4 4 4 4m12-8 4 4-4 4"/>',
 book:'<path d="M4 4h6a3 3 0 0 1 2 1 3 3 0 0 1 2-1h6v15h-6a2 2 0 0 0-2 2 2 2 0 0 0-2-2H4zM12 5v16M7 8h2m-2 3h2m6-3h2m-2 3h2"/>',
 restart:'<path d="M4 8a9 9 0 1 1-1 8M4 2v7h7"/>'
};
const HUD_LORE={engineer:'Il relève les pierres pour que demeure le serment.',paladin:'Son bouclier porte le poids des serments oubliés.',healer:'Dans le silence de l’Ancre, il écoute les vivants.',shooter:'Une seule respiration, puis le silence.',guard:'La force tient dans les rangs qui ne cèdent pas.'};
function initHUD(){
 HUD.els={};for(const el of document.querySelectorAll('[id]'))HUD.els[el.id]=el;
 for(const el of document.querySelectorAll('[data-icon]'))el.innerHTML=iconSVG(el.dataset.icon);
 HUD.els.restart.onclick=init;
 HUD.els['portrait-button'].onclick=()=>{const u=HUD.anchor?core:selectedBuilding()||selected.find(u=>u.hp>0)||HUD.enemy;if(u){cam.x=u.x;cam.z=u.z;clampCam();drawMiniMap()}};
 const map=HUD.els.minimap;
 const pan=ev=>{const r=map.getBoundingClientRect();cam.x=WORLD.x0+(ev.clientX-r.left)/r.width*(WORLD.x1-WORLD.x0);cam.z=WORLD.z0+(ev.clientY-r.top)/r.height*(WORLD.z1-WORLD.z0);clampCam();drawMiniMap()};
 map.addEventListener('pointerdown',ev=>{if(ev.button!==0)return;pan(ev);map.setPointerCapture(ev.pointerId)});
 map.addEventListener('pointermove',ev=>{if(ev.buttons&1)pan(ev)});
 map.addEventListener('keydown',ev=>{const d={ArrowLeft:[-5,0],ArrowRight:[5,0],ArrowUp:[0,-5],ArrowDown:[0,5]}[ev.key];if(!d)return;ev.preventDefault();ev.stopPropagation();cam.x+=d[0];cam.z+=d[1];clampCam();drawMiniMap()});
 HUD.els['action-panel'].addEventListener('click',ev=>{const b=ev.target.closest('button[data-act]');if(!b||b.disabled)return;const a=HUD.actions.find(a=>a.id===b.dataset.act);if(a)a.run()});
 buildMiniMap();
}
const iconSVG=name=>'<svg class="icon" viewBox="0 0 24 24" aria-hidden="true">'+(HUD_ICONS[name]||HUD_ICONS.rune)+'</svg>';
function formatAssault(){
 if(ended)return coreHP<=0?'Sanctuaire perdu':'Assauts terminés';
 if(!ORB.active)return 'Au réveil de l’Ancre';
 const due=nextWave||(spawnQueue.length&&!enemies.some(e=>!e.beast)?spawnQueue[0].at:0);
 if(!due)return 'Assaut en cours';
 const t=Math.max(0,Math.ceil(due-currentTime));return String(Math.floor(t/60)).padStart(2,'0')+':'+String(t%60).padStart(2,'0');
}
// ----- Panneau d'ordres : boutons calculés selon la sélection (unité, bâtiment, Ancre) -----
HUD.actions=[];HUD.menu=null;HUD.building=null;HUD.buildType=null;HUD.enemy=null;
// fiches des ennemis affichées quand on en sélectionne un
const ENEMY_INFO={
 creep:{name:'Fanatique du Credo',kind:'ENNEMI · CREDO SOUILLÉ',lore:'Robe ivoire trempée d’ichor noir : il frappe au contact pour son maître caché.'},
 spitter:{name:'Thuriféraire souillé',kind:'ENNEMI · CREDO SOUILLÉ',lore:'Il projette de loin une lumière souillée par la Bête.'},
 brute:{name:'Automate de Byrsa',kind:'ENNEMI · CREDO SOUILLÉ',lore:'Un automate d’or fêlé ; ses coups lourds brisent les lignes.'},
 beast:{name:'Aberration du Dévoreur',kind:'ENNEMI · CHAIR DU DÉVOREUR',lore:'Chair pâle et gueules multiples, vomie par les galeries.'}};
const shortCost=c=>Object.values(c).join('+');
function panelActions(){const alive=selected.filter(u=>u.hp>0),u=alive[0],B=selectedBuilding(),A=[],act=o=>A.push(o);if(ended)return A;
 if(HUD.anchor){if(!ORB.active)act({id:'orb',icon:'rune',label:'Réactiver',key:'r',title:'Envoyer l’Ingénieur réactiver l’Ancre · '+ORB.time+' s',disabled:!units.some(o=>o.role==='engineer'&&o.hp>0&&!o.hidden),active:!!ORB.owner,run:()=>orderOrb()});
  act({id:'hero',icon:'sword',label:'Tireur · '+shortCost(HERO_COST),key:'t',title:'Invoquer le héros Tireur · '+costText(HERO_COST),disabled:!canSummonHero(),run:summonHero});return A}
 if(!u&&B){if(!B.complete)return A;const D=BUILDINGS[B.type];
  if(D.deity){const r=DEITY_RES[D.deity];act({id:'summon',icon:D.icon,label:'Adepte · '+SUMMON_COST,key:'i',title:'Invoquer un '+ADEPT[D.deity].name.toLowerCase()+' · '+SUMMON_COST+' '+RES_INFO[r].name+' · prie au temple : +1 '+RES_INFO[r].name+' / s',disabled:!canSummonAt(B),run:()=>summonAdept(B)})}
  if(B.type==='caserne')for(const t of CASERNE_UNITS)act({id:'train-'+t.id,icon:t.icon,label:t.label+' · '+shortCost(CASERNE_COST),key:t.key,title:'Entraîner un '+ADEPT[t.id].name.toLowerCase()+' · '+costText(CASERNE_COST)+' · '+CASERNE_TIME+' s',disabled:!canTrain(B),run:()=>trainUnit(B,t.id)});
  if(B.type==='soulwell')FALLEN.slice(-9).reverse().forEach((f,i)=>act({id:'revive-'+f.id,icon:'heart',label:f.name.replace(/^Adepte (de |d’)?/,'')+' ★'+lvl(f),key:String(i+1),title:'Ressusciter '+f.name+' (niveau '+lvl(f)+') · '+costText(REVIVE_COST),disabled:!canRevive(B),run:()=>reviveUnit(B,f)}));
  return A}
 if(!u||u.hidden)return A;
 if(u.role==='engineer'&&HUD.menu==='build'){for(const[type,D]of Object.entries(BUILDINGS)){const ok=unlocked(type);act({id:'b-'+type,icon:D.icon,label:D.name.replace(/^Temple (de |d’)/,'T. ')+' · '+shortCost(D.cost),key:D.key,
   title:D.name+' · '+costText(D.cost)+(ok?'':' · nécessite un '+BUILDINGS[D.requires].name)+(D.size===2?' · 2 × 2':''),disabled:!ok||!canPay(D.cost),active:HUD.mode==='build'&&HUD.buildType===type,run:()=>armBuild(type)})}
  act({id:'back',icon:'restart',label:'Retour',key:'b',title:'Revenir aux ordres de l’Ingénieur (B ou Échap)',run:()=>{HUD.menu=null;HUD.mode=null;updateHUD(true)}});return A}
 if(u.role==='engineer'){act({id:'menu-build',icon:'hammer',label:'Construire',key:'b',title:'Construire un temple ou un bâtiment',run:()=>{HUD.menu='build';updateHUD(true)}});
  if(ORB.active)act({id:'repair',icon:'repair',label:'Réparer',key:'r',title:'Réparer l’Ancre · +15 % d’intégrité',disabled:u.ability>0,cooldown:u.ability>0?Math.ceil(u.ability)+' s':'',run:runAbility});
  else act({id:'orb',icon:'rune',label:'Réactiver',key:'r',title:'Réactiver l’Ancre · '+ORB.time+' s',active:!!u.orbJob,run:()=>orderOrb(u)})}
 else if(prays(u))act({id:'pray',icon:'rune',label:'Prier',key:'y',title:'Prier au temple de son dieu',disabled:!alive.some(o=>prays(o)&&ownTemples(o).length),run:()=>{let n=0;for(const o of alive)if(sendToPray(o))n++;say(n?'Les adeptes rejoignent leur temple pour prier.':'Aucun temple de leur dieu n’est achevé.',2)}});
 else if(u.role==='shooter')act({id:'ability',icon:'flame',label:'Compétence',key:' ',title:'Tir de précision',disabled:u.ability>0,cooldown:u.ability>0?Math.ceil(u.ability)+' s':'',run:runAbility});
 act({id:'hold',icon:'flag',label:'Position',key:'h',title:'Tenir position',active:u.stance==='hold',run:hold});
 act({id:'move',icon:'move',label:'Déplacer',key:'m',title:'Déplacer : choisir une destination',active:HUD.mode==='move',run:armMove});
 return A}
// raccourci clavier d'un bouton visible ; renvoie vrai s'il a été utilisé
function hudKey(k){const a=HUD.actions.find(a=>a.key===k);if(!a)return false;if(!a.disabled)a.run();return true}
function renderActions(){const panel=HUD.els['action-panel'],A=HUD.actions=panelActions(),sig=A.map(a=>a.id).join('|');
 if(panel.dataset.sig!==sig){panel.dataset.sig=sig;panel.replaceChildren(...A.map(a=>{const b=document.createElement('button');b.className='action';b.dataset.act=a.id;b.innerHTML=iconSVG(a.icon).replace('<svg','<span data-icon><svg').replace('</svg>','</svg></span>')+'<span class="lbl"></span><kbd>'+(a.key===' '?'Espace':a.key.toUpperCase())+'</kbd><span class="cd" style="position:absolute;top:2px;right:4px;font:10px Georgia,serif;color:#d8bf8d"></span>';return b}))}
 [...panel.children].forEach((b,i)=>{const a=A[i];b.disabled=!!a.disabled;b.classList.toggle('active',!!a.active);b.setAttribute('aria-pressed',String(!!a.active));b.title=a.title||a.label;b.setAttribute('aria-label',a.title||a.label);
  const l=b.querySelector('.lbl');if(l.textContent!==a.label)l.textContent=a.label;b.querySelector('.cd').textContent=a.cooldown||''})}
function unitStatus(u){if(u.hidden)return'Franchit le portail…';if(isAdept(u))return adeptStatus(u);
 if(u.role==='engineer'){if(HUD.mode==='build'&&HUD.buildType){const D=BUILDINGS[HUD.buildType];return'Placez : '+D.name+' · '+costText(D.cost)}
  if(u.buildJob){const b=u.buildJob,D=BUILDINGS[b.type];return'Construction · '+D.name+' · '+Math.floor(b.progress/D.time*100)+' %'}
  if(u.orbJob)return'Réactivation de l’Ancre · '+Math.floor(ORB.progress/ORB.time*100)+' %';
  if(u.job&&u.job.type==='dig')return'Creuse la roche · '+(DIG_HITS_DONE.get(u.job.cell.i+','+u.job.cell.j)||0)+' / '+DIG_HITS;
  if(HUD.menu==='build')return'Choisissez un bâtiment à construire';
  if(!ORB.active)return'L’Ancre est éteinte · clic droit dessus (ou R) pour la réactiver'}
 if(HUD.mode==='move')return'Choisissez une destination';if(u.stance==='hold')return'Tient sa position';return'Prêt à recevoir vos ordres'}
function buildingStatus(b){const D=BUILDINGS[b.type];if(!b.complete)return'Construction · '+Math.floor(b.progress/D.time*100)+' % · l’Ingénieur doit rester sur le chantier';
 if(D.deity){const r=RES_INFO[DEITY_RES[D.deity]].name,n=units.filter(u=>u.hp>0&&u.working&&u.job&&u.job.temple===b).length;return'Adepte de '+DEITY_PORTALS.find(d=>d.id===D.deity).name+' · '+SUMMON_COST+' '+r+' · '+n+' en prière (+'+n+' '+r+' / s)'}
 if(b.type==='caserne')return'Entraînement · '+costText(CASERNE_COST)+' · '+CASERNE_TIME+' s · file '+b.queue.length+' / '+CASERNE_QUEUE;
 if(b.type==='soulwell')return FALLEN.length?FALLEN.length+' âme'+(FALLEN.length>1?'s':'')+' à rappeler · '+costText(REVIVE_COST)+' chacune':'Aucune unité tombée pour l’instant';
 return'Achevé · débloqué par le '+BUILDINGS[D.requires].name}
function updateHUD(force=false){
 if(!HUD.els)return;
 if(!force&&currentTime>=HUD.lastUpdate&&currentTime-HUD.lastUpdate<.1)return;HUD.lastUpdate=currentTime;
 if(HUD.enemy&&(HUD.enemy.hp<=0||!enemies.includes(HUD.enemy)))HUD.enemy=null;
 const e=HUD.els,alive=selected.filter(u=>u.hp>0),u=alive[0],anchor=HUD.anchor;
 for(const k of RES_ORDER)e['res-'+k].textContent=Math.floor(RES[k]);
 e.population.textContent=units.filter(u=>u.hp>0&&!u.hidden).length;
 e['command-bar'].classList.toggle('anchor-selected',anchor);
 if(HUD.building&&!buildings.includes(HUD.building))HUD.building=null;const B=!anchor&&!u?selectedBuilding():null;
 e.chosen.textContent=anchor?'Ancre tyrienne':alive.length>1?alive.length+' Exilés':u?.name||(B?BUILDINGS[B.type].name:'Aucune sélection');
 const lv=u&&alive.length===1&&!u.hidden?' · NIV. '+lvl(u)+' · '+Math.floor(u.xp||0)+' / '+xpNeed(lvl(u))+' XP':'';
 e['selection-kind'].textContent=anchor?'SANCTUAIRE · ANCRE':B?'BÂTIMENT'+(BUILDINGS[B.type].deity?' · TEMPLE':''):isAdept(u)?(FIGHT[u.role]&&ADEPT[u.role].task==='fight'?'COMBATTANT':'ADEPTE · '+u.role.toUpperCase())+lv:u?.hidden?'PORTAIL · ÉMERGENCE':u?.role==='engineer'?'EXILÉ · SOUTIEN'+lv:u?'EXILÉ · COMBATTANT'+lv:'SANCTUAIRE';
 const hp=anchor?coreHP:alive.reduce((n,u)=>n+u.hp,0),max=anchor?100:alive.reduce((n,u)=>n+u.max,0);
 const health=e['health-fill'].parentElement;health.setAttribute('aria-label',anchor?'Intégrité de l’Ancre':'Points de vie');health.setAttribute('aria-valuemax',max||100);health.setAttribute('aria-valuenow',Math.ceil(hp));
 e['health-fill'].style.width=(B?(B.complete?100:B.progress/BUILDINGS[B.type].time*100):max?Math.max(0,hp/max)*100:0)+'%';
 e['health-text'].textContent=anchor?'Intégrité : '+Math.ceil(hp)+' %':B?(B.complete?'Achevé':'En construction'):max?Math.ceil(hp)+' / '+max:'—';
 e['selection-status'].textContent=anchor?(ORB.active?'Éveillée · +1 Forge, Vie, Discipline et Savoir / s':ORB.owner?'Réactivation · '+Math.floor(ORB.progress/ORB.time*100)+' %':'Éteinte · l’Ingénieur doit la réactiver'):B?buildingStatus(B):u?unitStatus(u):'Cliquez une unité, un bâtiment ou l’Ancre';
 e['unit-details'].hidden=anchor;e['anchor-details'].hidden=!anchor;
 e['assault-time'].textContent=anchor?formatAssault():'';
 const base=u&&(FIGHT[u.role]?FIGHT[u.role].dmg:{paladin:30,shooter:19,healer:9,guard:12}[u.role]);
 e['unit-damage'].textContent=!u||B||!base?'—':String(base+lvlBonus(u));
 e['unit-range'].textContent=!u||B||!base?'—':unitReach(u).toLocaleString('fr-FR');
 e['unit-armor'].textContent=u&&!B?String(lvlBonus(u)):'—';e['unit-speed'].textContent=u&&!B?(u.role==='guard'?3.45:isAdept(u)?7.6:15.2).toLocaleString('fr-FR'):'—';
 e.lore.textContent=B?BUILDINGS[B.type].lore:u?(ADEPT[u.role]&&ADEPT[u.role].lore)||HUD_LORE[u.role]||HUD_LORE.guard:'Un serment veille encore sur ces pierres.';
 e['portrait-button'].disabled=!anchor&&!u&&!B;
 const foe=!anchor&&!u&&!B?HUD.enemy:null;e['command-bar'].classList.toggle('enemy-selected',!!foe);if(foe){const I=ENEMY_INFO[foe.kind]||ENEMY_INFO.creep;
  e.chosen.textContent=I.name;e['selection-kind'].textContent=I.kind;e['selection-status'].textContent=foe.stun>0?'Étourdi':foe.slowUntil>currentTime?'Ralenti par les flammes':'Marche sur l’Ancre';
  health.setAttribute('aria-valuemax',foe.max);health.setAttribute('aria-valuenow',Math.ceil(foe.hp));e['health-fill'].style.width=Math.max(0,foe.hp/foe.max)*100+'%';e['health-text'].textContent=Math.ceil(foe.hp)+' / '+foe.max;
  e['unit-damage'].textContent=String(foe.damage);e['unit-range'].textContent=foe.range.toLocaleString('fr-FR');e['unit-armor'].textContent='0';e['unit-speed'].textContent=foe.speed.toLocaleString('fr-FR');e.lore.textContent=I.lore;e['portrait-button'].disabled=false}
 renderActions();
 const key=foe?'enemy-'+foe.kind:anchor?'anchor':u?.role||(B?'bld-'+B.type:'empty');if(HUD.portraitKey!==key){HUD.portraitKey=key;drawHUDPortrait(key)}
 drawMiniMap();
}
function runAbility(){if(HUD.anchor||ended||!selected.some(u=>u.hp>0&&!u.hidden))return;ability();updateHUD(true)}
function armMove(){if(HUD.anchor||ended||!selected.some(u=>u.hp>0&&!u.hidden))return;HUD.mode=HUD.mode==='move'?null:'move';canvas.style.cursor=HUD.mode?'crosshair':'default';updateHUD(true)}
function issueMove(target){
 if(HUD.anchor||ended)return;
 const valid=selected.filter(u=>u.hp>0&&!u.hidden),cols=Math.min(4,valid.length);
 valid.forEach((u,i)=>{cancelWork(u);u.tx=target.x+(i%cols-(cols-1)/2)*1.5;u.tz=target.z+(Math.floor(i/cols)-(Math.ceil(valid.length/cols)-1)/2)*1.5;u.tx=clamp(u.tx,WORLD.x0+8,WORLD.x1-8);u.tz=clamp(u.tz,WORLD.z0+8,WORLD.z1-8);u.stance='attack';u.forceMove=!target.kind});
 HUD.mode=null;canvas.style.cursor='crosshair';updateHUD(true);
}
function drawHUDPortrait(key){
 const c=HUD.els.portrait,g=c.getContext('2d');g.clearRect(0,0,c.width,c.height);g.imageSmoothingEnabled=false;
 if(key==='anchor'){
  const gradient=g.createRadialGradient(64,65,8,64,65,55);gradient.addColorStop(0,'#9271c288');gradient.addColorStop(1,'#25173900');g.fillStyle=gradient;g.fillRect(0,0,128,128);
  const orb=PW.objs.find(o=>o.orb)?.spr;if(orb)g.drawImage(orb.c,12,3,40,40,0,0,128,128);
 }else if(key.startsWith('bld-')){const D=BUILDINGS[key.slice(4)];PixelBuildings.draw(g,D.art,64,108,D.size===2?.55:.42,0,1)}
 else if(key.startsWith('enemy-')&&ESPR[key.slice(6)]){const S=ESPR[key.slice(6)],n=Math.max(22,S.h+6);g.drawImage(S.frames[0],S.ax-n/2,S.ay+2-n,n,n,4,4,120,120)}
 else if(AdeptArt.LOOK[key]&&!SPR[key]){AdeptArt.draw(g,64,112,key,0,'idle',2.6)}else if(SPR[key]){const sprite=SPR[key].frames[0];g.drawImage(sprite,6,0,27,27,-7,8,142,142)}
 else{g.strokeStyle='#9e8047';g.lineWidth=1;g.strokeRect(35,35,58,58);g.beginPath();g.moveTo(64,20);g.lineTo(64,108);g.moveTo(20,64);g.lineTo(108,64);g.stroke()}
}
const mapPt=(x,z,w=240,h=160)=>[(x-WORLD.x0)/(WORLD.x1-WORLD.x0)*w,(z-WORLD.z0)/(WORLD.z1-WORLD.z0)*h];
function buildMiniMap(){
 const bg=document.createElement('canvas');bg.width=240;bg.height=160;const g=bg.getContext('2d'),pt=(x,z)=>mapPt(x,z);
 g.fillStyle='#233522';g.fillRect(0,0,240,160);
 const R=rng(775);for(let i=0;i<2400;i++){g.fillStyle=R()>.5?'#34472b':'#1b2b1e';g.fillRect(R()*240,R()*160,2,2)}
 // montagne, salle de la grotte, galeries découvertes, cases creusées, couloir et chemin vers le sud
 g.fillStyle='#3a342d';for(let x=WORLD.x0;x<WORLD.x1;x+=2){const[a,b]=pt(x,WORLD.z0),[c,d]=pt(x+2,mountainEdge(x+1));g.fillRect(a,b,c-a+.5,d-b)}
 g.fillStyle='#24262b';const cellPx=(x,z,s)=>{const[a,b]=pt(x,z),[c,d]=pt(x+s,z+s);g.fillRect(a,b,c-a+.4,d-b+.4)};
 for(const k of DUG){const[i,j]=k.split(',').map(Number);cellPx(i*4,j*4,4)}
 for(let x=-68;x<68;x+=1.5)for(let z=-170;z<-86;z+=1.5)if(inCave(x,z))cellPx(x,z,1.5);
 if(GAL.found)for(let z=WORLD.z0;z<WORLD.z1;z+=2)for(let x=WORLD.x0;x<WORLD.x1;x+=2)if(isGalleryOpen(x+1,z+1))cellPx(x,z,2);
 {const[e,f]=pt(-CAVE.gate,CAVE.z1),[h,i]=pt(CAVE.gate,mountainEdge(0));g.fillRect(e,f-1,h-e,i-f+1)}
 g.strokeStyle='#7e7956';g.lineWidth=3;{const[a,b]=pt(0,mountainEdge(0)),[c,d]=pt(0,72);g.beginPath();g.moveTo(a,b);g.lineTo(c,d);g.stroke()}
 for(const t of trees){const[x,y]=pt(t.x,t.z);g.fillStyle=t.h>4?'#162d1c':'#2f4c29';g.fillRect(x-1,y-1,2,2)}
 for(const d of DEITY_PORTALS){const[x,y]=pt(d.x,PORTAL.z);g.fillStyle=DEITY_LOOK[d.id].glow[3];g.fillRect(x-1,y,2,2)}{const[x,y]=pt(PORTAL.x,PORTAL.z);g.fillStyle='#ffc04a';g.fillRect(x-2,y,4,2)}
 HUD.mapBackground=bg;
}
function drawMiniMap(){
 if(!HUD.mapBackground||!HUD.els)return;const c=HUD.els.minimap,g=c.getContext('2d');g.drawImage(HUD.mapBackground,0,0);
 const pt=(x,z)=>mapPt(x,z,c.width,c.height);
 const dot=(x,z,color,size)=>{const[a,b]=pt(x,z);g.fillStyle=color;g.fillRect(a-size/2,b-size/2,size,size)};
 for(const b of buildings)dot(b.x,b.z,!b.complete?'#e3c685':BUILDINGS[b.type].deity?'#8de8ed':'#d0b376',4);
 for(const p of GAL.portals)if(p.active)dot(p.x,p.z,'#ff4020',4);dot(core.x,core.z,ORB.active?'#d2a5ff':'#6e5a86',4);for(const b of turrets)dot(b.x,b.z,b.complete?'#e3c48b':'#858d71',3);
 for(const u of units)if(u.hp>0&&!u.hidden)dot(u.x,u.z,selected.includes(u)?'#ffe0a0':'#a8cc7b',3);for(const u of enemies)dot(u.x,u.z,'#ee7055',3);
 const bottom=H-HUD.els['command-bar'].getBoundingClientRect().height-18;
 g.beginPath();[[0,0],[W,0],[W,bottom],[0,bottom]].forEach(([x,y],i)=>{const p=groundFromScreen(x,y),[a,b]=pt(p.x,p.z);i?g.lineTo(a,b):g.moveTo(a,b)});g.closePath();g.fillStyle='#fff1be0d';g.fill();g.strokeStyle='#f4e0a6cc';g.lineWidth=1;g.stroke();
}
