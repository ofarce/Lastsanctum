// Deterministic integration checks against the real game loop and right-click handler.
import fs from 'node:fs/promises';
import vm from 'node:vm';
import assert from 'node:assert/strict';
const root=new URL('../',import.meta.url);
const noop=()=>{};
const context2d=new Proxy({},{get:(o,p)=>o[p]??noop,set:(o,p,v)=>(o[p]=v,true)});
const elements=new Map();
function element(){return{style:{},listeners:{},classList:{toggle:noop},getContext:()=>context2d,addEventListener(type,fn){(this.listeners[type]??=[]).push(fn)},setPointerCapture:noop,setAttribute:noop,append:noop,getBoundingClientRect:()=>({left:0,top:0,width:1440,height:900})}}
const box={console,assert,innerWidth:1440,innerHeight:900,devicePixelRatio:1,document:{getElementById(id){if(!elements.has(id))elements.set(id,element());return elements.get(id)},createElement:element,querySelectorAll:()=>[]},addEventListener:noop,requestAnimationFrame:noop,closeCharacterDialogue:noop,greetEngineer:noop};box.window=box;
vm.createContext(box);
for(const file of ['assets/barracks-game.js','assets/sawmill-game.js','assets/foundry-game.js','assets/temple-game.js','assets/ballista.js','assets/ballista-ruins.js','assets/turret-game.js','assets/hud.js'])vm.runInContext(await fs.readFile(new URL(file,root),'utf8'),box,{filename:file});
const html=await fs.readFile(new URL('Index.html',root),'utf8'),inline=html.match(/<script>\s*([\s\S]*?)<\/script>/)[1],entry=inline.indexOf('buildPixelWorld();initDecorRenderer();');assert(entry>0);
vm.runInContext(inline.slice(0,entry),box,{filename:'Index.html'});
vm.runInContext(`
updateHUD=()=>{};drawMiniMap=()=>{};
function fresh(){init();units[0].hidden=false;units[0].x=-20;units[0].z=12;units[0].tx=-20;units[0].tz=12;spawnQueue=[{at:1e6,x:0,kind:'creep'}];enemies=[];spirit=123;}
function tick(seconds){for(let i=0;i<Math.ceil(seconds/.025);i++)update(.025)}
function rightClick(b){const p=project(b.x,0,b.z);canvas.listeners.contextmenu[0]({preventDefault(){},clientX:p.x,clientY:p.y-20*Z()/16})}
fresh();assert.equal(turrets.length,2);assert(turrets[0].x<core.x&&turrets[1].x>core.x);assert(turrets.every(b=>!b.complete&&b.progress===0));
// Actual right-click command, travel and eight seconds at the work point.
rightClick(turrets[0]);assert.equal(units[0].turretJob,turrets[0]);tick(1);assert.equal(turrets[0].progress,0);tick(10);assert(turrets[0].complete);assert(!units[0].turretJob);assert.equal(spirit,123);
// Reassignment pauses the first job; hold/move cancel without losing progress.
fresh();const b=turrets[0],u=units[0];Object.assign(u,turretWorkPoint(b));u.tx=u.x;u.tz=u.z;rightClick(b);tick(3);const progress=b.progress;assert(progress>=2.9&&progress<8);hold();tick(2);assert.equal(b.progress,progress);assert.equal(b.owner,null);rightClick(b);tick(5.2);assert(b.complete);assert.equal(spirit,123);
fresh();rightClick(turrets[0]);rightClick(turrets[1]);assert.equal(turrets[0].owner,null);assert.equal(units[0].turretJob,turrets[1]);issueMove({x:0,z:5});assert(!units[0].turretJob);assert.equal(turrets[1].owner,null);
// Dragging the camera does not issue repair orders.
fresh();PAN.moved=true;rightClick(turrets[0]);assert(!units[0].turretJob);
// Death releases ownership; hidden engineers cannot receive repair orders.
fresh();rightClick(turrets[0]);units[0].hp=0;updateTurrets(.1);assert.equal(turrets[0].owner,null);fresh();units[0].hidden=true;rightClick(turrets[0]);assert(!units[0].turretJob);
// Ruins never fire, repaired guns do not acquire out-of-range targets.
fresh();enemies=[{x:-23,z:-50,hp:48,max:48}];updateTurrets(10);assert.equal(turretBolts.length,0);
turrets[0].complete=true;turrets[0].cycleAge=3;enemies=[{x:-23,z:-140,hp:48,max:48}];updateTurrets(.01);assert.equal(turretBolts.length,0);
// Weak and medium enemies die from one actual projectile impact; brutes survive.
for(const hp of [35,48,110]){fresh();const gun=turrets[0];gun.complete=true;gun.cycleAge=3;const e={x:gun.x,z:gun.z-100,hp,max:hp};enemies=[e];updateTurrets(.01);assert.equal(turretBolts.length,1);assert.equal(e.hp,hp);assert.equal(gun.orientation,'NE');gun.complete=false;updateTurrets(2);assert.equal(e.hp,Math.max(0,hp-80));}
// Both guns coordinate so they do not waste two bolts on one weak enemy.
fresh();for(const gun of turrets){gun.complete=true;gun.cycleAge=3;}enemies=[{x:0,z:-50,hp:48,max:48}];updateTurrets(.01);assert.equal(turretBolts.length,1);
// Invalid construction sites include turret footprints; reset removes jobs and bolts.
assert.equal(validTempleSite({x:27,z:11}),false);fresh();rightClick(turrets[0]);init();assert.equal(turretBolts.length,0);assert(turrets.every(b=>!b.complete&&!b.owner));assert(units.every(u=>!u.turretJob));
// Exercise both rendering states, including the real engineer work pose.
fresh();drawTurret(turrets[0]);rightClick(turrets[0]);Object.assign(units[0],turretWorkPoint(turrets[0]));drawTurretEngineer(units[0]);turrets[1].complete=true;drawTurret(turrets[1]);
console.log('PASS: right-click, travel, free repair, interruption, death, restart, range, projectiles, one-hit damage, targeting and rendering.');
`,box,{filename:'turret-integration-assertions'});
