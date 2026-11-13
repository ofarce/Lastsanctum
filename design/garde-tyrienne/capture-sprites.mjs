// Appeler captureSprites(cheminAbsoluLastsanctum) sous Node.js, puis export-sprites.py.
export async function captureSprites(root){
const fs=await import('node:fs/promises'),vm=await import('node:vm'),zlib=await import('node:zlib');
const box={module:{exports:{}}};vm.runInNewContext(await fs.readFile(root+'/assets/ballista.js','utf8'),box);const K=box.module.exports;
function capture(orientation,phase,mode='cycle',active=1){const ops=[],ctx=new Proxy({},{get:(o,p)=>p in o?o[p]:(...args)=>ops.push([p,...args]),set:(o,p,v)=>(ops.push(['set',p,v]),o[p]=v,true)});K.draw(ctx,K.GUARD,{x:96,y:155,scale:1.1,time:0,phase,mode,active,orientation,projectile:false});return ops}
const data=K.DIRECTIONS.map(d=>({id:d.id,idle:capture(d.id,.73,'base'),inactive:capture(d.id,0,'cycle',0),frames:Array.from({length:96},(_,i)=>capture(d.id,i/96))}));
await fs.writeFile(root+'/design/garde-tyrienne/render-commands.json.gz',zlib.gzipSync(JSON.stringify(data)));
return {directions:data.length,framesPerDirection:96};
}
