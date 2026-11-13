// Grand Arbre integration against actual game handlers, simulation and renderers.
import fs from 'node:fs/promises';
import vm from 'node:vm';
import assert from 'node:assert/strict';
const root=new URL('../',import.meta.url);
const noop=()=>{};
const context2d=new Proxy({createImageData:(w,h)=>({data:new Uint8ClampedArray(w*h*4)}),getImageData:(x,y,w,h)=>({data:new Uint8ClampedArray(w*h*4)})},{get:(o,p)=>o[p]??noop,set:(o,p,v)=>(o[p]=v,true)});
const elements=new Map();
function element(){return{style:{},listeners:{},classList:{toggle:noop},getContext:()=>context2d,addEventListener(type,fn){(this.listeners[type]??=[]).push(fn)},setPointerCapture:noop,setAttribute:noop,append:noop,getBoundingClientRect:()=>({left:0,top:0,width:1440,height:900})}}
const box={console,assert,innerWidth:1440,innerHeight:900,devicePixelRatio:1,document:{getElementById(id){if(!elements.has(id))elements.set(id,element());return elements.get(id)},createElement:element,querySelectorAll:()=>[]},addEventListener:noop,requestAnimationFrame:noop,closeCharacterDialogue:noop,greetEngineer:noop};box.window=box;
vm.createContext(box);
for(const file of ['assets/decor.js','assets/units.js','assets/temple.js','assets/sawmill.js','assets/sawmill-grand-arbre.js','assets/barracks-game.js','assets/sawmill-game.js','assets/foundry-game.js','assets/temple-game.js','assets/ballista.js','assets/ballista-ruins.js','assets/turret-game.js','assets/hud.js'])vm.runInContext(await fs.readFile(new URL(file,root),'utf8'),box,{filename:file});
const html=await fs.readFile(new URL('Index.html',root),'utf8'),inline=html.match(/<script>\s*([\s\S]*?)<\/script>/)[1],entry=inline.indexOf('buildPixelWorld();initDecorRenderer();');assert(entry>0);
vm.runInContext(inline.slice(0,entry),box,{filename:'Index.html'});
vm.runInContext(`
updateHUD=()=>{};drawMiniMap=()=>{};
init();units[0].hidden=false;const u=units[0];u.x=19;u.z=43;u.tx=19;u.tz=43;
spawnQueue=[{at:1e6,x:0,kind:'creep'}];enemies=[];
armSawmill();assert.equal(HUD.mode,'sawmill');
const click=project(27,0,40);canvas.listeners.pointerdown[0]({button:0,clientX:click.x,clientY:click.y});
assert.equal(sawmills.length,1);const b=sawmills[0];assert.equal(u.sawmillJob,b);
assert.equal(validTempleSite({x:27,z:40}),false);assert.equal(validFoundrySite({x:27,z:40}),false);
Object.assign(u,{x:b.x-8,z:b.z+3,tx:b.x-8,tz:b.z+3});
function tick(s){for(let i=0;i<Math.ceil(s/.025);i++)update(.025)}
tick(7);assert(!b.complete);drawSawmill(b);tick(1.1);assert(b.complete);assert(!u.sawmillJob);assert(b.worker.start.x> b.x);assert.equal(wood,0);
currentTime=b.workAt+3.99;updateSawmills(0);assert.equal(wood,0);
currentTime=b.workAt+4;updateSawmills(0);assert.equal(wood,10);assert.equal(woodPopups.length,1);drawSawmill(b);drawSawmillWorker(b);drawSawmillFeedback();assert.equal(woodPopups[0].x,core.x);
updateSawmills(0);assert.equal(wood,10);
temples.push({x:20,z:40,complete:true});currentTime=b.workAt+8;updateSawmills(0);assert.equal(wood,20);assert.equal(woodPopups.at(-1).x,20);
currentTime=b.workAt+40;updateSawmills(0);assert.equal(wood,100);assert.equal(sawmills.length,1);
// Orders cancel unfinished work while completed production persists.
placeSawmill({x:-30,z:40});assert(u.sawmillJob);hold();assert(!u.sawmillJob);assert.equal(sawmills.length,1);
placeSawmill({x:-30,z:40});issueMove({x:10,z:40});assert(!u.sawmillJob);assert.equal(sawmills.length,1);
placeSawmill({x:-30,z:40});u.hp=0;updateSawmills(.1);assert.equal(sawmills.length,1);
init();assert.equal(wood,0);assert.equal(sawmills.length,0);assert.equal(woodPopups.length,0);
console.log('PASS: scierie placement, collision, construction, artisan, gains, temple feedback, interruption, death and reset.');
`,box,{filename:'sawmill-integration-assertions'});
