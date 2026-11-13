'use strict';
// Selected Grand Arbre. Production follows simulation time and persists beyond the preview cycle.
let sawmills=[],wood=0,woodPopups=[];
function resetSawmills(){sawmills=[];wood=0;woodPopups=[]}
function cancelSawmill(u){if(!u)return;sawmills=sawmills.filter(b=>b.owner!==u||b.complete);delete u.sawmillJob}
function armSawmill(){if(ended||HUD.anchor||!templeBuilder())return;HUD.mode=HUD.mode==='sawmill'?null:'sawmill';updateHUD(true);if(HUD.mode)say('Scierie · Grand Arbre · gratuit. Choisissez un emplacement.',4)}
function validSawmillSite(p){return validTempleSite(p)}
function placeSawmill(p){const u=templeBuilder();if(ended||!u)return;if(!validSawmillSite(p)){say('Emplacement occupé : choisissez un espace libre.',2);return}cancelTemple(u);cancelFoundry(u);cancelBarracks(u);cancelTurretRepair(u);cancelSawmill(u);const b={x:p.x,z:p.z,owner:u,progress:0,complete:false,earned:0};sawmills.push(b);u.sawmillJob=b;u.tx=b.x-8;u.tz=b.z+3;u.stance='attack';HUD.mode=null;updateHUD(true);say('Construction du Grand Arbre · 8 secondes.',3)}
function updateSawmills(dt){for(const b of [...sawmills]){if(!b.complete){if(b.owner.hp<=0||b.owner.hidden){cancelSawmill(b.owner);continue}if(dist(b.owner,{x:b.x-8,z:b.z+3})>.5)continue;b.progress=Math.min(8,b.progress+dt);if(b.progress<8)continue;b.complete=true;b.finishedAt=currentTime;delete b.owner.sawmillJob;
// In this projection, increasing both coordinates heads to the bottom-right forest.
const start={x:55,z:42},target={x:b.x+2,z:b.z+1.5};b.worker={...start,start,target,duration:dist(start,target)/3.8};b.workAt=currentTime+b.worker.duration;say('Scierie achevée. Un artisan de Medeina arrive de la forêt.',3)}
const w=b.worker,f=Math.max(0,Math.min(1,(currentTime-b.finishedAt)/w.duration));w.x=w.start.x+(w.target.x-w.start.x)*f;w.z=w.start.z+(w.target.z-w.start.z)*f;const gains=Math.max(0,Math.floor((currentTime-b.workAt)/4));if(gains>b.earned){const amount=(gains-b.earned)*10;wood+=amount;b.earned=gains;const temple=temples.filter(t=>t.complete).sort((a,c)=>dist(a,b)-dist(c,b))[0];woodPopups.push({x:temple?.x??core.x,z:temple?.z??core.z,amount,at:currentTime})}}
woodPopups=woodPopups.filter(p=>currentTime-p.at<1.8)}
// Rendu pixel : Chantier de la souche (assets/pixel-buildings.js).
function drawSawmill(b){const p=project(b.x,0,b.z),s=Z()/16;if(!b.complete){ctx.save();ctx.translate(p.x-160*s,p.y-186*s);ctx.scale(s,s);TempleKit.footprint(ctx,currentTime);ctx.restore()}PixelBuildings.draw(ctx,'sawmill',p.x,p.y,Z()*.86/8,currentTime,b.complete?1:b.progress/8)}
function drawSawmillWorker(b){const w=b.worker,p=project(w.x,0,w.z);ctx.save();ctx.translate(p.x,p.y);ctx.scale(Z()/16,Z()/16);SawmillKit.worker(ctx,0,0,currentTime,currentTime<b.workAt?'walk':'work');ctx.restore()}
function drawSawmillFeedback(){for(const p of woodPopups){const a=currentTime-p.at,q=project(p.x,0,p.z),s=Z()/16;ctx.save();ctx.globalAlpha=a<.3?templeEase(a/.3):a<1.3?1:1-templeEase((a-1.3)/.5);ctx.translate(q.x,q.y-(100+16*templeEase(a/.3))*s);ctx.scale(s,s);SawmillKit.woodIcon(ctx,-24,0);ctx.textAlign='left';ctx.font='bold 17px Georgia';ctx.fillStyle='#f8e5b7';ctx.fillText('+'+p.amount,-4,5);ctx.restore()}}
function drawSawmillPreview(){if(HUD.mode!=='sawmill'||!templePointer)return;const p=project(templePointer.x,0,templePointer.z),s=Z()/16;ctx.save();ctx.translate(p.x-160*s,p.y-186*s);ctx.scale(s,s);TempleKit.footprint(ctx,currentTime,{color:validSawmillSite(templePointer)?'#a4f2ca':'#f28d80'});ctx.restore()}
