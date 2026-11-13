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
 shield:'<path d="M12 2 3 6v7c0 5 9 9 9 9s9-4 9-9V6zM12 5v13"/>',
 boot:'<path d="m10 3 9 2-3 10 5 3v3H3v-4l5-2zM9 7l8 2m-9 2 7 2M3 18h11"/>',
 rune:'<circle cx="12" cy="12" r="7"/><path d="M12 0v24M0 12h24m-12-9 3 9-3 9-3-9z"/>',
 hammer:'<path d="m3 21 12-12m-9 13 12-12M10 4l4-3 9 8-4 4zM2 20l2 3M9 5l4 4"/>',
 repair:'<path d="m14 5 5 5 4-4c1 6-4 9-8 7L6 22l-4-4 9-9c-2-4 1-9 7-8z"/><path d="m3 2 5 5m-7-3 3-3 3 3-3 3"/>',
 flag:'<path d="M5 23V2m0 1c5-4 9 4 16 0v11c-7 4-11-4-16 0"/>',
 move:'<path d="M12 2v20M2 12h20M8 6l4-4 4 4M8 18l4 4 4-4M6 8l-4 4 4 4m12-8 4 4-4 4"/>',
 restart:'<path d="M4 8a9 9 0 1 1-1 8M4 2v7h7"/>'
};
const HUD_LORE={engineer:'Il relève les pierres pour que demeure le serment.',paladin:'Son bouclier porte le poids des serments oubliés.',healer:'Dans le silence de l’Ancre, il écoute les vivants.',shooter:'Une seule respiration, puis le silence.',guard:'La force tient dans les rangs qui ne cèdent pas.'};
function initHUD(){
 HUD.els={};for(const el of document.querySelectorAll('[id]'))HUD.els[el.id]=el;
 for(const el of document.querySelectorAll('[data-icon]'))el.innerHTML='<svg class="icon" viewBox="0 0 24 24" aria-hidden="true">'+HUD_ICONS[el.dataset.icon]+'</svg>';
 HUD.els['build-sawmill'].onclick=armSawmill;HUD.els['build-barracks'].onclick=armBarracks;HUD.els['train-indra'].onclick=trainIndra;HUD.els.build.onclick=armTemple;HUD.els['build-foundry'].onclick=armFoundry;HUD.els.special.onclick=runAbility;HUD.els.hold.onclick=hold;HUD.els.restart.onclick=init;HUD.els['move-command'].onclick=armMove;
 HUD.els['portrait-button'].onclick=()=>{const u=HUD.anchor?core:selected.find(u=>u.hp>0);if(u){cam.x=clamp(u.x,-98,98);cam.z=clamp(u.z,-148,44);drawMiniMap()}};
 const map=HUD.els.minimap;
 const pan=ev=>{const r=map.getBoundingClientRect();cam.x=clamp((ev.clientX-r.left)/r.width*256-128,-98,98);cam.z=clamp((ev.clientY-r.top)/r.height*244-172,-148,44);drawMiniMap()};
 map.addEventListener('pointerdown',ev=>{if(ev.button!==0)return;pan(ev);map.setPointerCapture(ev.pointerId)});
 map.addEventListener('pointermove',ev=>{if(ev.buttons&1)pan(ev)});
 map.addEventListener('keydown',ev=>{const d={ArrowLeft:[-5,0],ArrowRight:[5,0],ArrowUp:[0,-5],ArrowDown:[0,5]}[ev.key];if(!d)return;ev.preventDefault();ev.stopPropagation();cam.x=clamp(cam.x+d[0],-98,98);cam.z=clamp(cam.z+d[1],-148,44);drawMiniMap()});
 buildMiniMap();
}
function formatAssault(){
 if(ended)return coreHP<=0?'Sanctuaire perdu':'Assauts terminés';
 const due=nextWave||(spawnQueue.length&&!enemies.length?spawnQueue[0].at:0);
 if(!due)return 'Assaut en cours';
 const t=Math.max(0,Math.ceil(due-currentTime));return String(Math.floor(t/60)).padStart(2,'0')+':'+String(t%60).padStart(2,'0');
}
function updateHUD(force=false){
 if(!HUD.els)return;
 if(!force&&currentTime>=HUD.lastUpdate&&currentTime-HUD.lastUpdate<.1)return;HUD.lastUpdate=currentTime;
 const e=HUD.els,alive=selected.filter(u=>u.hp>0),u=alive[0],anchor=HUD.anchor;
 const active=!!u&&!u.hidden&&!anchor&&!ended;
 e.wood.textContent=wood;e['build-sawmill'].disabled=!active||u?.role!=='engineer';e['build-sawmill'].classList.toggle('active',HUD.mode==='sawmill');e['build-sawmill'].setAttribute('aria-pressed',String(HUD.mode==='sawmill'));e.iron.textContent=iron;e['build-foundry'].disabled=!active||u?.role!=='engineer';e['build-foundry'].classList.toggle('active',HUD.mode==='foundry');e['build-foundry'].setAttribute('aria-pressed',String(HUD.mode==='foundry'));e.spirit.textContent=spirit;e.build.disabled=!active||u?.role!=='engineer';e.build.classList.toggle('active',HUD.mode==='build');e.build.setAttribute('aria-pressed',String(HUD.mode==='build'));
 e.population.textContent=units.filter(u=>u.hp>0&&!u.hidden).length;
 e['command-bar'].classList.toggle('anchor-selected',anchor);
 e.chosen.textContent=anchor?'Ancre tyrienne':alive.length>1?alive.length+' Exilés':u?.name||'Aucune sélection';
 e['selection-kind'].textContent=anchor?'SANCTUAIRE · ANCRE':u?.hidden?'PORTAIL · ÉMERGENCE':u?.role==='engineer'?'EXILÉ · SOUTIEN':u?'EXILÉ · COMBATTANT':'SANCTUAIRE';
 const hp=anchor?coreHP:alive.reduce((n,u)=>n+u.hp,0),max=anchor?100:alive.reduce((n,u)=>n+u.max,0);
 const health=e['health-fill'].parentElement;health.setAttribute('aria-label',anchor?'Intégrité de l’Ancre':'Points de vie');health.setAttribute('aria-valuemax',max||100);health.setAttribute('aria-valuenow',Math.ceil(hp));
 e['health-fill'].style.width=(max?Math.max(0,hp/max)*100:0)+'%';
 e['health-text'].textContent=anchor?'Intégrité : '+Math.ceil(hp)+' %':max?Math.ceil(hp)+' / '+max:'—';
 e['selection-status'].textContent=anchor?'Cœur du sanctuaire':u?.hidden?'Franchit le portail…':u?HUD.mode==='sawmill'?'Placez la scierie · Gratuit':u.sawmillJob?'Construction du Grand Arbre · '+Math.floor(u.sawmillJob.progress/8*100)+' %':HUD.mode==='foundry'?'Placez la fonderie · Gratuit':u.foundryJob?'Construction de la fonderie · '+Math.floor(u.foundryJob.progress/8*100)+' %':HUD.mode==='build'?'Placez le temple · Gratuit':u.turretJob?'Tourelle · réparation gratuite · '+Math.floor(u.turretJob.progress/8*100)+' %':u.templeJob?'Construction du temple · Énonciation':HUD.mode==='move'?'Choisissez une destination':u.stance==='hold'?'Tient sa position':'Prêt à recevoir vos ordres':'Cliquez une unité ou l’Ancre';
 e['unit-details'].hidden=anchor;e['anchor-details'].hidden=!anchor;
 e['assault-time'].textContent=anchor?formatAssault():'';
 e['unit-damage'].textContent=!u||u.role==='engineer'?'—':({paladin:30,shooter:19,healer:9,guard:12,indra:12}[u.role]||'—');
 // Le prototype n’a pas de réduction d’armure : ne pas inventer de statistique.
 e['unit-armor'].textContent=u?'0':'—';e['unit-speed'].textContent=u?(u.role==='paladin'?3.6:u.role==='guard'?3.45:3.8).toLocaleString('fr-FR'):'—';
 e.lore.textContent=u?HUD_LORE[u.role]||HUD_LORE.guard:'Un serment veille encore sur ces pierres.';
 e.special.disabled=!active||(u?.ability||0)>0;e.hold.disabled=!active;e['move-command'].disabled=!active;
 e['ability-label'].textContent=u?.role==='engineer'?'Réparer':'Compétence';e.special.setAttribute('aria-label',u?.role==='engineer'?'Réparer l’Ancre':'Utiliser la compétence');
 e['ability-key'].textContent=u?.role==='engineer'?'R':'Espace';e.cooldown.textContent=active&&u.ability>0?Math.ceil(u.ability)+' s':'';
 e.hold.classList.toggle('active',active&&u.stance==='hold');e.hold.setAttribute('aria-pressed',String(active&&u.stance==='hold'));
 e['move-command'].classList.toggle('active',HUD.mode==='move');e['move-command'].setAttribute('aria-pressed',String(HUD.mode==='move'));
 e['portrait-button'].disabled=!anchor&&!u;
 const key=anchor?'anchor':u?.role||'empty';if(HUD.portraitKey!==key){HUD.portraitKey=key;drawHUDPortrait(key)}
 drawMiniMap();
}
function runAbility(){if(HUD.anchor||ended||!selected.some(u=>u.hp>0&&!u.hidden))return;ability();updateHUD(true)}
function armMove(){if(HUD.anchor||ended||!selected.some(u=>u.hp>0&&!u.hidden))return;HUD.mode=HUD.mode==='move'?null:'move';canvas.style.cursor=HUD.mode?'crosshair':'default';updateHUD(true)}
function issueMove(target){
 if(HUD.anchor||ended)return;
 const valid=selected.filter(u=>u.hp>0&&!u.hidden),cols=Math.min(4,valid.length);
 valid.forEach((u,i)=>{cancelTemple(u);cancelFoundry(u);cancelBarracks(u);cancelSawmill(u);cancelTurretRepair(u);u.tx=target.x+(i%cols-(cols-1)/2)*1.5;u.tz=target.z+(Math.floor(i/cols)-(Math.ceil(valid.length/cols)-1)/2)*1.5;u.tx=clamp(u.tx,-108,108);u.tz=clamp(u.tz,-160,50);u.stance='attack'});
 HUD.mode=null;canvas.style.cursor='crosshair';updateHUD(true);
}
function drawHUDPortrait(key){
 const c=HUD.els.portrait,g=c.getContext('2d');g.clearRect(0,0,c.width,c.height);g.imageSmoothingEnabled=false;
 if(key==='anchor'){
  const gradient=g.createRadialGradient(64,65,8,64,65,55);gradient.addColorStop(0,'#9271c288');gradient.addColorStop(1,'#25173900');g.fillStyle=gradient;g.fillRect(0,0,128,128);
  const orb=PW.objs.find(o=>o.orb)?.spr;if(orb)g.drawImage(orb.c,12,3,40,40,0,0,128,128);
 }else if(key==='indra'){BarracksKit.actor(g,64,115,0,'guard',2.5,true)}else if(SPR[key]){const sprite=SPR[key].frames[0];g.drawImage(sprite,6,0,27,27,-7,8,142,142)}
 else{g.strokeStyle='#9e8047';g.lineWidth=1;g.strokeRect(35,35,58,58);g.beginPath();g.moveTo(64,20);g.lineTo(64,108);g.moveTo(20,64);g.lineTo(108,64);g.stroke()}
}
function buildMiniMap(){
 const bg=document.createElement('canvas');bg.width=240;bg.height=160;const g=bg.getContext('2d');
 g.fillStyle='#233522';g.fillRect(0,0,240,160);
 const pt=(x,z)=>[(x+128)/256*240,(z+172)/244*160];
 const R=rng(775);for(let i=0;i<1800;i++){g.fillStyle=R()>.5?'#34472b':'#1b2b1e';g.fillRect(R()*240,R()*160,2,2)}
 const[a,b]=pt(-44,-8),[c,d]=pt(44,54);g.fillStyle='#586344';g.fillRect(a,b,c-a,d-b);
 g.strokeStyle='#7e7956';g.lineWidth=4;for(const x of[-12,12]){const[a,b]=pt(x,-172),[c,d]=pt(x,8);g.beginPath();g.moveTo(a,b);g.lineTo(c,d);g.stroke()}
 for(const t of trees){const[x,y]=pt(t.x,t.z);g.fillStyle=t.h>4?'#162d1c':'#2f4c29';g.beginPath();g.arc(x,y,1.3+t.r*.5,0,Math.PI*2);g.fill()}
 const[x,y]=pt(-18,8),[x1,y1]=pt(18,28);g.fillStyle='#8d8d72';g.fillRect(x,y,x1-x,y1-y);g.strokeStyle='#c7c5a0';g.strokeRect(x,y,x1-x,y1-y);
 HUD.mapBackground=bg;
}
function drawMiniMap(){
 if(!HUD.mapBackground||!HUD.els)return;const c=HUD.els.minimap,g=c.getContext('2d');g.drawImage(HUD.mapBackground,0,0);
 const pt=(x,z)=>[(x+128)/256*c.width,(z+172)/244*c.height];
 const dot=(x,z,color,size)=>{const[a,b]=pt(x,z);g.fillStyle=color;g.fillRect(a-size/2,b-size/2,size,size)};
 for(const b of sawmills){dot(b.x,b.z,b.complete?'#91b660':'#e3c685',5);if(b.worker)dot(b.worker.x,b.worker.z,'#a8cc7b',3)}for(const b of foundries){dot(b.x,b.z,b.complete?'#d0b376':'#e3c685',5);if(b.worker)dot(b.worker.x,b.worker.z,'#d5e7da',3)}dot(core.x,core.z,'#d2a5ff',5);for(const b of turrets)dot(b.x,b.z,b.complete?'#e3c48b':'#858d71',4);for(const b of temples){dot(b.x,b.z,b.complete?'#8de8ed':'#e3c685',5);if(b.priest)dot(b.priest.x,b.priest.z,'#d5e7da',3);}for(const u of units)if(u.hp>0&&!u.hidden)dot(u.x,u.z,selected.includes(u)?'#ffe0a0':'#a8cc7b',4);for(const u of enemies)dot(u.x,u.z,'#ee7055',3);
 const bottom=H-HUD.els['command-bar'].getBoundingClientRect().height-18;
 g.beginPath();[[0,0],[W,0],[W,bottom],[0,bottom]].forEach(([x,y],i)=>{const p=groundFromScreen(x,y),[a,b]=pt(p.x,p.z);i?g.lineTo(a,b):g.moveTo(a,b)});g.closePath();g.fillStyle='#fff1be0d';g.fill();g.strokeStyle='#f4e0a6cc';g.lineWidth=1;g.stroke();
}
