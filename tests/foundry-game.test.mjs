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
for(const file of ['assets/foundry-game.js','assets/temple-game.js','assets/ballista.js','assets/ballista-ruins.js','assets/turret-game.js','assets/hud.js'])vm.runInContext(await fs.readFile(new URL(file,root),'utf8'),box,{filename:file});
const html=await fs.readFile(new URL('Index.html',root),'utf8'),inline=html.match(/<script>\s*([\s\S]*?)<\/script>/)[1],entry=inline.indexOf('buildPixelWorld();initDecorRenderer();');assert(entry>0);
vm.runInContext(inline.slice(0,entry),box,{filename:'Index.html'});
vm.runInContext(`
updateHUD=()=>{};drawMiniMap=()=>{};
init();const u=units[0];u.hidden=false;u.x=-40;u.z=10;selected=[u];
armFoundry();assert.equal(HUD.mode,'foundry');placeFoundry({x:-30,z:25});
assert.equal(foundries.length,1);const b=foundries[0];assert.equal(u.foundryJob,b);
assert.equal(validTempleSite(b),false);assert.equal(validFoundrySite({x:NaN,z:20}),false);
updateFoundries(8);assert.equal(b.progress,0); // Travel must finish before building.
u.x=b.x-8;u.z=b.z+3;currentTime=8;updateFoundries(8);
assert(b.complete);assert(b.worker);assert(!u.foundryJob);assert.equal(iron,0);
currentTime=b.workAt+3.99;updateFoundries(0);assert.equal(iron,0);
currentTime=b.workAt+4;updateFoundries(0);assert.equal(iron,10);assert.equal(ironPopups[0].x,core.x);
updateFoundries(0);assert.equal(iron,10); // No duplicate gain at the same timestamp.
temples.push({x:-30,z:10,complete:true});
currentTime=b.workAt+8;updateFoundries(0);assert.equal(iron,20);assert.equal(ironPopups[0].x,-30);assert.equal(ironPopups[0].z,10);
currentTime=b.workAt+12;updateFoundries(0);assert.equal(iron,30);
currentTime=b.workAt+13.81;updateFoundries(0);assert.equal(ironPopups.length,0);
placeFoundry({x:30,z:30});assert(u.foundryJob);hold();assert(!u.foundryJob);assert.equal(foundries.length,1);
placeFoundry({x:30,z:30});u.hp=0;updateFoundries(.1);assert.equal(foundries.length,1);
resetFoundries();assert.equal(foundries.length,0);assert.equal(iron,0);assert.equal(ironPopups.length,0);
console.log('PASS: foundry placement, footprint, travel, construction, arrival, production, popup target, interruption, death and reset.');
`,box,{filename:'foundry-integration-assertions'});
