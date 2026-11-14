'use strict';
// Deux défenses fixes du sanctum ; toutes les durées suivent la simulation.
const TURRET_CONFIG=Object.freeze({range:70,damage:40,repairTime:8,cycle:3.6,boltSpeed:85});
let turrets=[],turretBolts=[];
function resetTurrets(){for(const u of units)delete u.turretJob;turretBolts=[];turrets=[-11,11].map((x,i)=>({id:i,x,z:-71,progress:0,complete:false,owner:null,orientation:'SO',cycleAge:0,firing:false,target:null}))}
function cancelTurretRepair(u){if(!u)return;const b=u.turretJob;if(b&&b.owner===u)b.owner=null;delete u.turretJob}
function turretWorkPoint(b){return{x:b.x,z:b.z+5}}
// Les tourelles en ruine se rallument d'elles-mêmes quand l'Ingénieur réactive l'Ancre.
function orderTurretRepair(b){if(ended)return;if(b.complete){say('Garde tyrienne active · portée '+TURRET_CONFIG.range+' · dégâts '+TURRET_CONFIG.damage+'.',2);return}
 say('Garde tyrienne endormie · elle s’éveillera quand l’Ingénieur aura réactivé l’Ancre.',3)}
function activateTurrets(){for(const b of turrets){if(b.complete)continue;b.complete=true;b.progress=TURRET_CONFIG.repairTime;b.cycleAge=0;b.finishedAt=currentTime;b.owner=null;zone(b.x,b.z,4,'#dccc9e');flash(b.x,b.z,'#ffe6ae')}}
function hitTurret(sx,sy){return [...turrets].sort((a,b)=>b.x+b.z-a.x-a.z).find(b=>{const p=project(b.x,0,b.z),s=Z()/16;const k=Z()*.86/8;return Math.abs(sx-p.x)<44*k&&sy>p.y-100*k&&sy<p.y+24*k})}
function turretHeading(b,target){const p=project(b.x,0,b.z),q=project(target.x,0,target.z),angle=Math.atan2(q.y-p.y,q.x-p.x);let best='NE',score=Infinity;for(const d of BallistaKit.DIRECTIONS){const a=Math.atan2(d.y,d.x),diff=Math.abs(Math.atan2(Math.sin(angle-a),Math.cos(angle-a)));if(diff<score){score=diff;best=d.id}}return best}
function turretPending(e){return turretBolts.reduce((n,p)=>n+(p.target===e?TURRET_CONFIG.damage:0),0)}
function updateTurrets(dt){
 for(const p of turretBolts){p.age+=dt;if(!p.hit&&p.age>=p.duration){p.hit=true;if(p.target.hp>0){damage(p.target,TURRET_CONFIG.damage);flash(p.target.x,p.target.z,'#dccc9e')}}}turretBolts=turretBolts.filter(p=>!p.hit);
 for(const b of turrets){if(!b.complete){const u=b.owner;if(!u)continue;if(u.hp<=0||u.hidden||u.turretJob!==b){cancelTurretRepair(u);b.owner=null;continue}if(dist(u,turretWorkPoint(b))>.6)continue;b.progress=Math.min(TURRET_CONFIG.repairTime,b.progress+dt);if(b.progress>=TURRET_CONFIG.repairTime){b.complete=true;b.cycleAge=0;b.finishedAt=currentTime;b.builder=u;cancelTurretRepair(u);say('Garde tyrienne restaurée · défense automatique à très longue portée.',3);updateHUD(true)}continue}
  if(b.firing){b.cycleAge+=dt;if(b.cycleAge>=TURRET_CONFIG.cycle){b.cycleAge=0;b.firing=false;b.target=null}continue}
  b.cycleAge=Math.min(TURRET_CONFIG.cycle*.73,b.cycleAge+dt);
  const candidates=enemies.filter(e=>e.hp>0&&e.hp-turretPending(e)>0&&dist(b,e)<=TURRET_CONFIG.range),target=targetClosest(b,candidates,TURRET_CONFIG.range+.001);if(target){b.orientation=turretHeading(b,target);b.aim=target}
  if(!target||b.cycleAge<TURRET_CONFIG.cycle*.73)continue;
  b.target=target;b.firing=true;b.cycleAge=TURRET_CONFIG.cycle*.76;const duration=Math.max(.12,dist(b,target)/TURRET_CONFIG.boltSpeed);turretBolts.push({x:b.x,z:b.z,target,tx:target.x,tz:target.z,age:0,duration,hit:false});
 }
}
function turretLayer(g,alpha,draw){g.save();const layer=new Proxy(g,{get:(o,p)=>typeof o[p]==='function'?o[p].bind(o):o[p],set:(o,p,v)=>(o[p]=p==='globalAlpha'?v*alpha:v,true)});layer.globalAlpha=1;draw(layer);g.restore()}
// Rendu pixel : Tour de guet ronde (assets/pixel-buildings.js). L'arme suit sa cible sur 360°.
function turretYaw(b){const t=b.target?.hp>0?b.target:b.aim?.hp>0?b.aim:null;if(b.yaw===undefined)b.yaw=Math.PI/4;if(t){const want=Math.atan2(t.z-b.z,t.x-b.x);b.yaw+=Math.atan2(Math.sin(want-b.yaw),Math.cos(want-b.yaw))*.2}return b.yaw}
function drawTurret(b){const p=project(b.x,0,b.z),s=Z()/16,k=Z()*.86/8;if(b.complete)PixelBuildings.draw(ctx,'ballista',p.x,p.y,k,currentTime,1,{variant:true,yaw:turretYaw(b),phase:b.cycleAge/TURRET_CONFIG.cycle});else{PixelBuildings.draw(ctx,'ballista',p.x,p.y,k,currentTime,1,{variant:false});if(window.TempleIncantation&&(b.owner||b.progress>0))b.stones=TempleIncantation.drawSite(ctx,p.x,p.y,k,b.progress/TURRET_CONFIG.repairTime,TURRET_CONFIG.repairTime,'ballista',{variant:true});else if(b.progress>0)PixelBuildings.draw(ctx,'ballista',p.x,p.y,k,currentTime,b.progress/TURRET_CONFIG.repairTime,{variant:true})}
 ctx.save();if(!b.complete&&b.progress>0){ctx.fillStyle='#172522';ctx.fillRect(p.x-35*s,p.y+26*k,70*s,4*s);ctx.fillStyle='#ddc084';ctx.fillRect(p.x-35*s,p.y+26*k,70*s*b.progress/8,4*s)}ctx.restore()}
function drawTurretBolts(){for(const b of turretBolts){const t=Math.min(1,b.age/b.duration),target=b.target.hp>0?b.target:{x:b.tx,z:b.tz},p=project(b.x,6.5,b.z),q=project(target.x,1.3,target.z),dx=q.x-p.x,dy=q.y-p.y,length=Math.hypot(dx,dy)||1,ux=dx/length,uy=dy/length,x=p.x+dx*t,y=p.y+dy*t;ctx.save();ctx.strokeStyle='#dec79b';ctx.lineWidth=Math.max(2,Z()*.09);ctx.beginPath();ctx.moveTo(x-ux*16,y-uy*16);ctx.lineTo(x,y);ctx.stroke();ctx.fillStyle='#c8d0c5';ctx.beginPath();ctx.moveTo(x+ux*5,y+uy*5);ctx.lineTo(x-ux*3+uy*3,y-uy*3-ux*3);ctx.lineTo(x-ux*3-uy*3,y-uy*3+ux*3);ctx.closePath();ctx.fill();ctx.restore()}}
function drawTurretEngineer(u){const b=u.turretJob;if(window.TempleIncantation||!b||b.complete||dist(u,turretWorkPoint(b))>.6)return;const p=project(u.x,1.5,u.z),s=Z()/16,swing=Math.max(0,Math.sin(currentTime*12));ctx.save();ctx.strokeStyle='#c7b07a';ctx.lineWidth=2*s;ctx.beginPath();ctx.moveTo(p.x+5*s,p.y);ctx.lineTo(p.x+13*s,p.y-(8+swing*12)*s);ctx.stroke();ctx.fillStyle='#b4bdb0';ctx.fillRect(p.x+8*s,p.y-(12+swing*12)*s,11*s,5*s);if(b.progress>2&&b.progress<5.1){const q=project(b.x,4,b.z);ctx.strokeStyle='#ae9865';ctx.lineWidth=s;ctx.beginPath();ctx.moveTo(p.x,p.y-16*s);ctx.lineTo(q.x,q.y);ctx.stroke()}ctx.restore()}
