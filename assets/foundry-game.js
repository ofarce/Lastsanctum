'use strict';
// Selected concept 02. Production follows simulation time and persists beyond the preview cycle.
let foundries=[],iron=0,ironPopups=[];
function resetFoundries(){foundries=[];iron=0;ironPopups=[]}
function cancelFoundry(u){if(!u)return;foundries=foundries.filter(b=>b.owner!==u||b.complete);delete u.foundryJob}
function armFoundry(){if(ended||HUD.anchor||!templeBuilder())return;HUD.mode=HUD.mode==='foundry'?null:'foundry';updateHUD(true);if(HUD.mode)say('Puits de fonderie · Halle des creusets · gratuit. Choisissez un emplacement.',4)}
function validFoundrySite(p){return validTempleSite(p)}
function placeFoundry(p){const u=templeBuilder();if(ended||!u)return;if(!validFoundrySite(p)){say('Emplacement occupé : choisissez un espace libre.',2);return}cancelTemple(u);cancelTurretRepair(u);cancelFoundry(u);cancelBarracks(u);cancelSawmill(u);const b={x:p.x,z:p.z,owner:u,progress:0,complete:false,earned:0};foundries.push(b);u.foundryJob=b;u.tx=b.x-8;u.tz=b.z+3;u.stance='attack';HUD.mode=null;updateHUD(true);say('Construction de la Halle des creusets · 8 secondes.',3)}
function updateFoundries(dt){for(const b of [...foundries]){if(!b.complete){if(b.owner.hp<=0||b.owner.hidden){cancelFoundry(b.owner);continue}if(dist(b.owner,{x:b.x-8,z:b.z+3})>.5)continue;b.progress=Math.min(8,b.progress+dt);if(b.progress<8)continue;b.complete=true;b.finishedAt=currentTime;delete b.owner.foundryJob;
// In this projection, increasing both coordinates heads to the bottom-right forest.
const start={x:55,z:42},target={x:b.x+2,z:b.z+1.5};b.worker={...start,start,target,duration:dist(start,target)/3.8};b.workAt=currentTime+b.worker.duration;say('Fonderie achevée. Un forgeron d’Aether arrive de la forêt.',3)}
const w=b.worker,f=Math.max(0,Math.min(1,(currentTime-b.finishedAt)/w.duration));w.x=w.start.x+(w.target.x-w.start.x)*f;w.z=w.start.z+(w.target.z-w.start.z)*f;const gains=Math.max(0,Math.floor((currentTime-b.workAt)/4));if(gains>b.earned){const amount=(gains-b.earned)*10;iron+=amount;b.earned=gains;const temple=temples.filter(t=>t.complete).sort((a,c)=>dist(a,b)-dist(c,b))[0];ironPopups.push({x:temple?.x??core.x,z:temple?.z??core.z,amount,at:currentTime})}}
ironPopups=ironPopups.filter(p=>currentTime-p.at<1.8)}
// Rendu pixel : Haut-fourneau (assets/pixel-buildings.js).
function drawFoundry(b){const p=project(b.x,0,b.z),s=Z()/16;if(!b.complete){ctx.save();ctx.translate(p.x-160*s,p.y-186*s);ctx.scale(s,s);TempleKit.footprint(ctx,currentTime);ctx.restore()}PixelBuildings.draw(ctx,'foundry',p.x,p.y,Z()*.86/8,currentTime,b.complete?1:b.progress/8)}
function drawFoundryWorker(b){const w=b.worker,p=project(w.x,0,w.z);ctx.save();ctx.translate(p.x,p.y);ctx.scale(Z()/16,Z()/16);FoundryKit.worker(ctx,0,0,currentTime,currentTime<b.workAt?'walk':'work');ctx.restore()}
function drawFoundryFeedback(){for(const p of ironPopups){const a=currentTime-p.at,q=project(p.x,0,p.z),s=Z()/16;ctx.save();ctx.globalAlpha=a<.3?templeEase(a/.3):a<1.3?1:1-templeEase((a-1.3)/.5);ctx.translate(q.x,q.y-(100+16*templeEase(a/.3))*s);ctx.scale(s,s);FoundryKit.ironIcon(ctx,-24,0);ctx.textAlign='left';ctx.font='bold 17px Georgia';ctx.fillStyle='#f8e5b7';ctx.fillText('+'+p.amount,-4,5);ctx.restore()}}
function drawFoundryPreview(){if(HUD.mode!=='foundry'||!templePointer)return;const p=project(templePointer.x,0,templePointer.z),s=Z()/16;ctx.save();ctx.translate(p.x-160*s,p.y-186*s);ctx.scale(s,s);TempleKit.footprint(ctx,currentTime,{color:validFoundrySite(templePointer)?'#a4f2ca':'#f28d80'});ctx.restore()}
