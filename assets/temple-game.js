'use strict';
// Free Astral Seal temple; all timings use simulation time, never wall time.
let temples=[],spirit=0,templePointer=null;
const TEMPLE_RADIUS=6;
const templeEase=v=>{v=Math.max(0,Math.min(1,v));return v*v*(3-2*v)};
const templeSurface=document.createElement('canvas');templeSurface.width=320;templeSurface.height=240;
const templeContext=templeSurface.getContext('2d');
function resetTemples(){temples=[];spirit=0;templePointer=null}
function templeBuilder(){return selected.find(u=>u.role==='engineer'&&u.hp>0&&!u.hidden)}
function armTemple(){if(ended||HUD.anchor||!templeBuilder())return;HUD.mode=HUD.mode==='build'?null:'build';canvas.style.cursor='crosshair';updateHUD(true);if(HUD.mode)say('Temple de Sigil — gratuit. Cliquez dans la clairière. Échap : annuler.',4)}
function validTempleSite(p){return Number.isFinite(p.x)&&Number.isFinite(p.z)&&p.x>-36&&p.x<36&&p.z>0&&p.z<43&&!(p.x>-24&&p.x<24&&p.z>1&&p.z<35)&&!temples.some(b=>dist(b,p)<TEMPLE_RADIUS*2+2)&&!sawmills.some(b=>dist(b,p)<TEMPLE_RADIUS*2+2)&&!barracks.some(b=>dist(b,p)<TEMPLE_RADIUS*2+2)&&!foundries.some(b=>dist(b,p)<TEMPLE_RADIUS*2+2)&&!turrets.some(b=>dist(b,p)<TEMPLE_RADIUS+4)&&!units.some(u=>u.hp>0&&!u.hidden&&dist(u,p)<TEMPLE_RADIUS+1)}
function cancelTemple(u){temples=temples.filter(b=>b.owner!==u||b.complete);delete u.templeJob}
function placeTemple(p){const u=templeBuilder();if(ended||!u)return;if(!validTempleSite(p)){say('Emplacement occupé : choisissez un espace libre dans la clairière.',2);return}cancelTurretRepair(u);cancelFoundry(u);cancelBarracks(u);cancelSawmill(u);cancelTemple(u);const b={x:p.x,z:p.z,owner:u,progress:0,complete:false,finishedAt:0,earned:0,popupAt:-Infinity};temples.push(b);u.templeJob=b;u.tx=p.x-8;u.tz=p.z+3;u.stance='attack';HUD.mode=null;updateHUD(true);say('L’Ingénieur rejoint le chantier. Temple gratuit · Énonciation : 8 s.',3)}
// A world-space visitor starts beyond the southern clearing, inside the jungle.
function summonTemplePriest(b){const target={x:b.x+2,z:b.z+1.5},start={x:b.x,z:60},duration=Math.hypot(target.x-start.x,target.z-start.z)/3.8;b.priest={x:start.x,z:start.z,start,target,duration};b.prayerAt=b.finishedAt+duration}
function advanceTemplePriest(b){const p=b.priest,u=Math.max(0,Math.min(1,(currentTime-b.finishedAt)/p.duration));p.x=p.start.x+(p.target.x-p.start.x)*u;p.z=p.start.z+(p.target.z-p.start.z)*u}
function drawTemplePriest(b){const p=b.priest,q=project(p.x,0,p.z);ctx.save();ctx.translate(q.x,q.y);const s=Z()/16;ctx.scale(s,s);TempleKit.priest(ctx,0,0,currentTime,currentTime<b.prayerAt?'walk':'pray');ctx.restore()}
function updateTemples(dt){for(const b of [...temples]){if(!b.complete){if(b.owner.hp<=0){cancelTemple(b.owner);continue}if(Math.hypot(b.owner.x-(b.x-8),b.owner.z-(b.z+3))>.5)continue;b.progress=Math.min(8,b.progress+dt);if(b.progress>=8){b.complete=true;b.finishedAt=currentTime;summonTemplePriest(b);delete b.owner.templeJob;say('Temple achevé. Un prêtre de Sigil sort de la jungle au sud.',3)}}else{advanceTemplePriest(b);const gains=Math.max(0,Math.floor((currentTime-b.prayerAt)/4));if(gains>b.earned){spirit+=(gains-b.earned)*10;b.earned=gains;b.popupAt=b.prayerAt+gains*4}}}}
function drawTemple(b){const anchor=project(b.x,0,b.z),scale=Z()/16,voice=project(b.owner.x,1.7,b.owner.z);templeContext.clearRect(0,0,320,240);if(!b.complete){TempleConstructionKit.render(templeContext,TempleConstructionKit.DESIGNS[0],b.progress,{showEngineer:false,showFootprint:false,ritualTime:currentTime,voiceOrigin:[(voice.x-anchor.x)/scale+160,(voice.y-anchor.y)/scale+186]})}else{TempleKit.building(templeContext,TempleKit.DESIGNS[0],currentTime);}

const p=project(b.x,0,b.z),s=Z()/16;if(!b.complete){ctx.save();ctx.translate(p.x-160*s,p.y-186*s);ctx.scale(s,s);TempleKit.footprint(ctx,currentTime);ctx.restore()}ctx.drawImage(templeSurface,p.x-160*s,p.y-186*s,320*s,240*s);
// Draw directly at display resolution: no nearest-neighbour quantization of motion.
if(b.complete){const elapsed=currentTime-b.prayerAt;ctx.save();ctx.translate(p.x-160*s,p.y-186*s);ctx.scale(s,s);TempleKit.feedback(ctx,{progress:Math.max(0,elapsed%4)/4,age:currentTime-b.popupAt,active:elapsed>=0});ctx.restore()}
if(!b.complete&&b.progress>0){const eng=project(b.owner.x,1.7,b.owner.z);ctx.save();ctx.strokeStyle='#f6d38b';ctx.globalAlpha=.4+.2*Math.sin(currentTime*4);ctx.beginPath();ctx.moveTo(eng.x,eng.y);ctx.quadraticCurveTo(eng.x,p.y-80*s,p.x,p.y-65*s);ctx.stroke();for(let i=0;i<3;i++){ctx.beginPath();ctx.ellipse(eng.x+10*s,eng.y,((currentTime*15+i*9)%30+3)*s,((currentTime*15+i*9)%30+3)*s*.5,0,-.8,.8);ctx.stroke()}ctx.restore()}}
function drawTemplePreview(){if(HUD.mode!=='build'||!templePointer)return;const p=templePointer,q=project(p.x,0,p.z),s=Z()/16;ctx.save();ctx.translate(q.x-160*s,q.y-186*s);ctx.scale(s,s);TempleKit.footprint(ctx,currentTime,{color:validTempleSite(p)?'#a4f2ca':'#f28d80'});ctx.restore()}


function drawEnunciation(u){const job=u.templeJob||u.foundryJob||u.barracksJob||u.sawmillJob;if(!job||job.progress<=0)return;const p=project(u.x,1.5,u.z),s=Z()/16;ctx.save();ctx.strokeStyle='#d7cfb4';ctx.lineWidth=3*s;ctx.beginPath();ctx.moveTo(p.x+2*s,p.y);ctx.lineTo(p.x+11*s,p.y-5*s-Math.sin(currentTime*3)*2*s);ctx.lineTo(p.x+16*s,p.y-6*s);ctx.stroke();ctx.fillStyle='#ffe6ae';ctx.fillRect(p.x+15*s,p.y-8*s,3*s,3*s);ctx.restore()}
