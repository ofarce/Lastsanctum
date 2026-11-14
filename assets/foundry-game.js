'use strict';
// Selected concept 02. Production follows simulation time and persists beyond the preview cycle.
let foundries=[],iron=0,ironPopups=[];
function resetFoundries(){foundries=[];iron=0;ironPopups=[]}
function cancelFoundry(u){if(!u)return;foundries=foundries.filter(b=>b.owner!==u||b.complete);delete u.foundryJob}
function armFoundry(){if(ended||HUD.anchor)return;if(!builderFor('foundry')){say('Fonderie : sélectionnez l’Ingénieur.',3);return}HUD.mode=HUD.mode==='foundry'?null:'foundry';updateHUD(true);if(HUD.mode)say('Fonderie · gratuite · construite par l’Ingénieur. Choisissez un emplacement.',4)}
function validFoundrySite(p){return validTempleSite(p)}
function placeFoundry(p){const u=builderFor('foundry');if(ended||!u)return;clearJob(u);if(!validFoundrySite(p)){say('Emplacement occupé : choisissez un espace libre.',2);return}cancelTemple(u);cancelTurretRepair(u);cancelFoundry(u);cancelBarracks(u);cancelSawmill(u);const b={x:p.x,z:p.z,owner:u,progress:0,complete:false,earned:0};foundries.push(b);u.foundryJob=b;u.tx=b.x-8;u.tz=b.z+3;u.stance='attack';HUD.mode=null;updateHUD(true);say('L’Ingénieur bâtit la fonderie · 4 secondes.',3)}
function updateFoundries(dt){for(const b of [...foundries]){if(!b.complete){if(b.owner.hp<=0||b.owner.hidden){cancelFoundry(b.owner);continue}if(dist(b.owner,{x:b.x-8,z:b.z+3})>.5)continue;b.progress=Math.min(BUILD_TIME,b.progress+dt);if(b.progress<BUILD_TIME)continue;b.complete=true;b.finishedAt=currentTime;delete b.owner.foundryJob;
// In this projection, increasing both coordinates heads to the bottom-right forest.
say('Fonderie achevée. Les adeptes d’Aether y apportent le minerai.',3)}}
ironPopups=ironPopups.filter(p=>currentTime-p.at<1.8)}
// Rendu pixel : Haut-fourneau (assets/pixel-buildings.js).
function drawFoundry(b){const p=project(b.x,0,b.z),s=Z()/16;if(!b.complete){ctx.save();ctx.translate(p.x-160*s,p.y-186*s);ctx.scale(s,s);TempleKit.footprint(ctx,currentTime);ctx.restore()}if(!b.complete&&window.TempleIncantation)b.stones=TempleIncantation.drawSite(ctx,p.x,p.y,Z()*.86/8,b.progress/BUILD_TIME,BUILD_TIME,'foundry');else PixelBuildings.draw(ctx,'foundry',p.x,p.y,Z()*.86/8,currentTime,b.complete?1:b.progress/BUILD_TIME)}
function drawFoundryWorker(b){const w=b.worker,p=project(w.x,0,w.z);ctx.save();ctx.translate(p.x,p.y);ctx.scale(Z()/16*BUILDING_CHAR_K,Z()/16*BUILDING_CHAR_K);FoundryKit.worker(ctx,0,0,currentTime,currentTime<b.workAt?'walk':'work');ctx.restore()}
function drawFoundryFeedback(){for(const p of ironPopups){const a=currentTime-p.at,q=project(p.x,0,p.z),s=Z()/16;ctx.save();ctx.globalAlpha=a<.3?templeEase(a/.3):a<1.3?1:1-templeEase((a-1.3)/.5);ctx.translate(q.x,q.y-(100+16*templeEase(a/.3))*s);ctx.scale(s,s);ctx.textAlign='right';ctx.font='bold 17px Georgia';ctx.fillStyle='#f8e5b7';ctx.fillText('+'+p.amount,-2,5);FoundryKit.ironIcon(ctx,4,0);ctx.restore()}drawWorkshopStatus(foundries)}
function drawFoundryPreview(){if(HUD.mode!=='foundry'||!templePointer)return;const p=project(templePointer.x,0,templePointer.z),s=Z()/16;ctx.save();ctx.translate(p.x-160*s,p.y-186*s);ctx.scale(s,s);TempleKit.footprint(ctx,currentTime,{color:validFoundrySite(templePointer)?'#a4f2ca':'#f28d80'});ctx.restore()}
