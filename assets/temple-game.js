'use strict';
// Free Astral Seal temple; all timings use simulation time, never wall time.
let temples=[],spirit=0,templePointer=null;
const TEMPLE_RADIUS=6;
const templeEase=v=>{v=Math.max(0,Math.min(1,v));return v*v*(3-2*v)};
const templeSurface=document.createElement('canvas');templeSurface.width=320;templeSurface.height=240;
const templeContext=templeSurface.getContext('2d');
const CELL=4,FOOT=6,BUILD_TIME=4; // durée de construction des bâtiments (s)
// Zone constructible : la salle de la grotte, hors rangée des portails et hors allée centrale menant à l’Ancre.
function inBuildZone(c){return c.x>-46&&c.x<46&&c.z>-138&&c.z<-104&&Math.abs(c.x)>14}
function snapSite(p){if(!p||!Number.isFinite(p.x)||!Number.isFinite(p.z))return p;return{x:Math.floor(p.x/CELL)*CELL+CELL/2,z:Math.floor(p.z/CELL)*CELL+CELL/2}}
function footprintPath(x,z,h=FOOT){const c=[[x-h,z-h],[x+h,z-h],[x+h,z+h],[x-h,z+h]].map(([a,b])=>project(a,0,b));ctx.beginPath();c.forEach((q,i)=>i?ctx.lineTo(q.x,q.y):ctx.moveTo(q.x,q.y));ctx.closePath()}
function drawFootprint(x,z,stroke,fill){ctx.save();footprintPath(x,z);if(fill){ctx.fillStyle=fill;ctx.fill()}ctx.lineWidth=Math.max(1,Z()*.12);ctx.strokeStyle=stroke;ctx.stroke();ctx.restore()}
function drawBuildGrid(){for(const b of [...temples,...foundries,...sawmills,...barracks])drawFootprint(b.x,b.z,b.complete?'#e8d9a866':'#c79cff99','#1a120a2a')}
function drawBuildCells(){if(!['build','foundry','sawmill','barracks'].includes(HUD.mode))return;const X0=-48,X1=48,Z0=-144,Z1=-100;ctx.save();ctx.lineWidth=1;
 for(let x=X0;x<X1;x+=CELL)for(let z=Z0;z<Z1;z+=CELL){const c={x:x+CELL/2,z:z+CELL/2};const inZone=inBuildZone(c);if(!inZone)continue;const busy=[...temples,...foundries,...sawmills,...barracks].some(b=>Math.max(Math.abs(b.x-c.x),Math.abs(b.z-c.z))<FOOT);footprintPath(c.x,c.z,CELL/2);ctx.strokeStyle=busy?'#f28d8040':'#a4f2ca50';ctx.stroke()}
 ctx.restore();const p=templePointer;if(p&&Number.isFinite(p.x)){const ok=validTempleSite(p);drawFootprint(p.x,p.z,ok?'#a4f2ca':'#f28d80',ok?'#a4f2ca30':'#f28d8030')}}
function resetTemples(){temples=[];spirit=0;templePointer=null}
function templeBuilder(){return selected.find(u=>u.role==='engineer'&&u.hp>0&&!u.hidden)}
function armTemple(){if(ended||HUD.anchor||!templeBuilder())return;HUD.mode=HUD.mode==='build'?null:'build';canvas.style.cursor='crosshair';updateHUD(true);if(HUD.mode)say('Temple de Sigil — gratuit. Cliquez dans la grotte. Échap : annuler.',4)}
function overlapsFoot(b,p){return Math.max(Math.abs(b.x-p.x),Math.abs(b.z-p.z))<FOOT*2}
function validTempleSite(p){return Number.isFinite(p.x)&&Number.isFinite(p.z)&&inBuildZone(p)&&![...temples,...sawmills,...barracks,...foundries].some(b=>overlapsFoot(b,p))&&!turrets.some(b=>dist(b,p)<TEMPLE_RADIUS+4)&&!(typeof blocks!=='undefined'&&blocksOverlap(p,FOOT+1.5))&&!units.some(u=>u.hp>0&&!u.hidden&&dist(u,p)<TEMPLE_RADIUS+1)}
function cancelTemple(u){temples=temples.filter(b=>b.owner!==u||b.complete);delete u.templeJob}
function placeTemple(p){const u=templeBuilder();if(ended||!u)return;if(!validTempleSite(p)){say('Emplacement occupé : choisissez un espace libre dans la grotte.',2);return}cancelTurretRepair(u);cancelFoundry(u);cancelBarracks(u);cancelSawmill(u);cancelTemple(u);const b={x:p.x,z:p.z,owner:u,progress:0,complete:false,finishedAt:0,earned:0,popupAt:-Infinity};temples.push(b);u.templeJob=b;u.tx=p.x-8;u.tz=p.z+3;u.stance='attack';HUD.mode=null;updateHUD(true);say('L’Ingénieur rejoint le chantier. Temple gratuit · Énonciation : 4 s.',3)}
// A world-space visitor starts beyond the southern clearing, inside the jungle.
function summonTemplePriest(b){const target={x:b.x+2,z:b.z+1.5},start={x:b.x,z:60},duration=Math.hypot(target.x-start.x,target.z-start.z)/3.8;b.priest={x:start.x,z:start.z,start,target,duration};b.prayerAt=b.finishedAt+duration}
function advanceTemplePriest(b){const p=b.priest,u=Math.max(0,Math.min(1,(currentTime-b.finishedAt)/p.duration));p.x=p.start.x+(p.target.x-p.start.x)*u;p.z=p.start.z+(p.target.z-p.start.z)*u}
function drawTemplePriest(b){const p=b.priest,q=project(p.x,0,p.z);ctx.save();ctx.translate(q.x,q.y);const s=Z()/16*BUILDING_CHAR_K;ctx.scale(s,s);TempleKit.priest(ctx,0,0,currentTime,currentTime<b.prayerAt?'walk':'pray');ctx.restore()}
function updateTemples(dt){for(const b of [...temples]){if(!b.complete){if(b.owner.hp<=0){cancelTemple(b.owner);continue}if(Math.hypot(b.owner.x-(b.x-8),b.owner.z-(b.z+3))>.5)continue;b.progress=Math.min(BUILD_TIME,b.progress+dt);if(b.progress>=BUILD_TIME){b.complete=true;b.finishedAt=currentTime;b.prayerAt=Infinity;delete b.owner.templeJob;say('Temple achevé. Invoquez des adeptes par les portails (20 Esprit).',4)}}}}
// Rendu pixel : Stèle de l'Ancre (assets/pixel-buildings.js).
function drawTemple(b){

const p=project(b.x,0,b.z),s=Z()/16;if(!b.complete){ctx.save();ctx.translate(p.x-160*s,p.y-186*s);ctx.scale(s,s);TempleKit.footprint(ctx,currentTime);ctx.restore()}if(!b.complete&&window.TempleIncantation)b.stones=TempleIncantation.drawSite(ctx,p.x,p.y,Z()*.86/8,b.progress/BUILD_TIME);else PixelBuildings.draw(ctx,'temple',p.x,p.y,Z()*.86/8,currentTime,b.complete?1:b.progress/BUILD_TIME);
// Draw directly at display resolution: no nearest-neighbour quantization of motion.
if(b.complete){const elapsed=currentTime-b.prayerAt;ctx.save();ctx.translate(p.x-160*s,p.y-186*s);ctx.scale(s,s);TempleKit.feedback(ctx,{progress:Math.max(0,elapsed%4)/4,age:currentTime-b.popupAt,active:elapsed>=0});ctx.restore()}
if(!window.TempleIncantation&&!b.complete&&b.progress>0){const eng=project(b.owner.x,1.7,b.owner.z);ctx.save();ctx.strokeStyle='#f6d38b';ctx.globalAlpha=.4+.2*Math.sin(currentTime*4);ctx.beginPath();ctx.moveTo(eng.x,eng.y);ctx.quadraticCurveTo(eng.x,p.y-80*s,p.x,p.y-65*s);ctx.stroke();for(let i=0;i<3;i++){ctx.beginPath();ctx.ellipse(eng.x+10*s,eng.y,((currentTime*15+i*9)%30+3)*s,((currentTime*15+i*9)%30+3)*s*.5,0,-.8,.8);ctx.stroke()}ctx.restore()}}
function drawTemplePreview(){if(HUD.mode!=='build'||!templePointer)return;const p=templePointer,q=project(p.x,0,p.z),s=Z()/16;ctx.save();ctx.translate(q.x-160*s,q.y-186*s);ctx.scale(s,s);TempleKit.footprint(ctx,currentTime,{color:validTempleSite(p)?'#a4f2ca':'#f28d80'});ctx.restore()}


function drawEnunciation(u){const job=window.TempleIncantation?null:u.templeJob||u.foundryJob||u.barracksJob||u.sawmillJob;if(!job||job.progress<=0)return;const p=project(u.x,1.5,u.z),s=Z()/16;ctx.save();ctx.strokeStyle='#d7cfb4';ctx.lineWidth=3*s;ctx.beginPath();ctx.moveTo(p.x+2*s,p.y);ctx.lineTo(p.x+11*s,p.y-5*s-Math.sin(currentTime*3)*2*s);ctx.lineTo(p.x+16*s,p.y-6*s);ctx.stroke();ctx.fillStyle='#ffe6ae';ctx.fillRect(p.x+15*s,p.y-8*s,3*s,3*s);ctx.restore()}

// M1 · L'incantation : même chantier pour le temple, la fonderie, la scierie et les balistes tyriennes.
function incantationSites(){const base=b=>({x:b.x-8,z:b.z+3}),T=typeof TURRET_CONFIG!=='undefined'?TURRET_CONFIG.repairTime:8;
 return[...temples.map(b=>({b,job:'templeJob',at:base(b),tol:.5,dur:BUILD_TIME,owner:b.owner})),
  ...(typeof foundries!=='undefined'?foundries:[]).map(b=>({b,job:'foundryJob',at:base(b),tol:.5,dur:BUILD_TIME,owner:b.owner})),
  ...(typeof sawmills!=='undefined'?sawmills:[]).map(b=>({b,job:'sawmillJob',at:base(b),tol:.5,dur:BUILD_TIME,owner:b.owner})),
  ...(typeof barracks!=='undefined'?barracks:[]).map(b=>({b,job:'barracksJob',at:base(b),tol:.5,dur:typeof BARRACKS_BUILD_TIME!=='undefined'?BARRACKS_BUILD_TIME:6,owner:b.owner})),
  ...(typeof turrets!=='undefined'?turrets:[]).map(b=>({b,job:'turretJob',at:turretWorkPoint(b),tol:.6,dur:T,owner:b.owner||b.builder}))]}
function incantationActive(c){const u=c.owner,b=c.b;return!!(u&&!b.complete&&b.progress>0&&u[c.job]===b&&Math.hypot(u.x-c.at.x,u.z-c.at.z)<=c.tol)}
function templeKneeling(u){if(!window.TempleIncantation)return false;for(const j of['templeJob','foundryJob','sawmillJob','barracksJob','turretJob'])if(u[j]){const c=incantationSites().find(c=>c.b===u[j]&&c.job===j);return!!c&&incantationActive(c)}return false}
// Miroir de l'Ancre et bulle d'incantation, dessinés au-dessus des unités.
function drawTempleOverlays(){if(!window.TempleIncantation)return;const k=Z()*.86/8;
 for(const c of incantationSites()){const b=c.b,u=c.owner;if(!u)continue;const fin=b.complete&&b.finishedAt!=null?currentTime-b.finishedAt:Infinity,active=incantationActive(c);if(!active&&!(fin<2.4))continue;
  const[nx,ny]=natP(u.x,0,u.z),fx=nx*PX,fy=ny*PX,face=u._face||1,act=active?Math.min(1,b.progress/.8):0;
  TempleIncantation.drawMirror(ctx,fx,fy,k,currentTime,act,active?b.stones||[]:[],fin,face);
  TempleIncantation.drawSpeech(ctx,fx,fy-58*k,k,TempleIncantation.verse(b.complete?1:b.progress/c.dur,c.dur,fin,c.job),currentTime)}}
