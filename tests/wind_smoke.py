"""Test navigateur du vent : feuillage mobile, troncs et attaches fixes. Dépendances : Chromium et le module Python websockets.
Exécuter : python3 tests/wind_smoke.py. Captures : /tmp/lastsanctum-hud-qa.
"""
import asyncio,base64,json,os,shutil,subprocess,tempfile,urllib.request
from pathlib import Path
import websockets
ROOT=Path(__file__).resolve().parents[1]
OUT=Path('/tmp/lastsanctum-hud-qa');OUT.mkdir(exist_ok=True)
profile=tempfile.TemporaryDirectory(prefix='lastsanctum-wind-test-',ignore_cleanup_errors=True)
binary=os.environ.get('CHROMIUM_BINARY') or ('/snap/chromium/current/usr/lib/chromium-browser/chrome' if Path('/snap/chromium/current/usr/lib/chromium-browser/chrome').exists() else shutil.which('chromium') or shutil.which('google-chrome'))
if not binary:raise SystemExit('Chromium introuvable : définir CHROMIUM_BINARY.')
chrome=subprocess.Popen([binary,'--headless','--no-sandbox','--disable-dev-shm-usage','--user-data-dir='+profile.name,'--remote-debugging-port=0','--remote-allow-origins=*','--allow-file-access-from-files','--window-size=1440,900','about:blank'],stdout=(OUT/'chrome.log').open('w'),stderr=subprocess.STDOUT)
async def test():
 for _ in range(100):
  try:
   port=(Path(profile.name)/'DevToolsActivePort').read_text().splitlines()[0]
   tabs=json.load(urllib.request.urlopen('http://localhost:'+port+'/json'));break
  except Exception:await asyncio.sleep(.1)
 ws=await websockets.connect(next(t['webSocketDebuggerUrl'] for t in tabs if t['type']=='page'),max_size=30_000_000)
 seq=0;errors=[]
 async def call(method,params=None):
  nonlocal seq
  seq+=1;i=seq;await ws.send(json.dumps({'id':i,'method':method,'params':params or {}}))
  while True:
   msg=json.loads(await ws.recv())
   if msg.get('method')=='Runtime.exceptionThrown':errors.append(msg['params']['exceptionDetails'])
   if msg.get('id')==i:
    if 'error' in msg:raise RuntimeError(msg['error'])
    return msg.get('result',{})
 async def js(expr):
  r=await call('Runtime.evaluate',{'expression':expr,'returnByValue':True,'awaitPromise':True})
  if 'exceptionDetails' in r:raise RuntimeError(r['exceptionDetails'])
  return r.get('result',{}).get('value')
 async def click(x,y):
  for typ in ['mousePressed','mouseReleased']:await call('Input.dispatchMouseEvent',{'type':typ,'x':x,'y':y,'button':'left','clickCount':1})
 async def click_id(id):
  p=await js(f"(()=>{{const r=document.getElementById('{id}').getBoundingClientRect();return [r.x+r.width/2,r.y+r.height/2]}})()")
  await click(*p)
 async def shot(name):
  r=await call('Page.captureScreenshot',{'format':'png'});(OUT/name).write_bytes(base64.b64decode(r['data']))
 await call('Runtime.enable');await call('Page.enable');await call('Emulation.setDeviceMetricsOverride',{'width':1440,'height':900,'deviceScaleFactor':1,'mobile':False});await call('Page.navigate',{'url':(ROOT/'Index.html').as_uri()})
 for _ in range(200):
  if await js("typeof HUD!=='undefined'&&HUD.els&&typeof currentTime!=='undefined'&&currentTime>3.2"):break
  await asyncio.sleep(.15)
 else:raise AssertionError('Jeu non démarré')
 timing=await js("""(async()=>{let frames=[];for(let i=0;i<35;i++)frames.push(await new Promise(requestAnimationFrame));const intervals=frames.slice(1).map((t,i)=>t-frames[i]);return {renderScale:decorRenderer.renderScale,meanFrameMs:intervals.reduce((a,b)=>a+b,0)/intervals.length,maxFrameMs:Math.max(...intervals)}})()""")
 # Inspect pixels at native resolution; performance above uses the selected quality.
 await js('decorRenderer.renderScale=1')
 result=await js("""(()=>{
 const savedTime=currentTime,savedPX=PX;ctx.save();ctx.setTransform(1,0,0,1,0,0);PX=1;
 const diff=(a,b,from=0,to=a.length)=>{let n=0;for(let i=from;i<to;i+=4)if(a[i]!==b[i]||a[i+1]!==b[i+1]||a[i+2]!==b[i+2])n++;return n};
 const paint=(o,t,flag=false)=>{currentTime=t;if(decorRenderer)decorRenderer.begin();ctx.fillStyle='#000';ctx.fillRect(0,0,180,150);if(flag)drawWindBanner(o,30,30);else drawWindTree(o,70,115);flushDecor();if(decorRenderer)ctx.drawImage(decorRenderer.canvas,0,0,canvas.width,canvas.height);return ctx.getImageData(0,0,180,150).data};
 const changes={};for(const kind of ['big','cyp','palm','bush']){
 const o=PW.objs.find(o=>o.wind===kind),a=paint(o,0);let moving=0,roots=0;for(const t of [.7,1.7,3,4.5,6]){const b=paint(o,t);moving=Math.max(moving,diff(a,b));roots=Math.max(roots,diff(a,b,115*180*4))}changes[kind]={moving,rootChanges:kind==='bush'?null:roots};
 }
 const flags=PW.objs.filter(o=>o.flag);const f={...flags[0],flag:{...flags[0].flag,x:0,y:0}};const a=paint(f,0,true),b=paint(f,1.7,true);changes.banner={moving:diff(a,b),attachmentChanges:diff(a,b,30*180*4,33*180*4)};
 const palm={...PW.objs.find(o=>o.wind==='palm'),x:0,z:0};const fingerprints=new Set();for(let i=0;i<12;i++){const pixels=paint(palm,i/60);let hash=0;for(let j=0;j<pixels.length;j+=4)hash=(hash*31+pixels[j]+pixels[j+1]*3+pixels[j+2]*7)|0;fingerprints.add(hash)}
 const separated=PW.objs.filter(o=>o.wind).every(o=>o.spr.foliage&&o.spr.c!==o.spr.foliage.c);
 currentTime=savedTime;PX=savedPX;ctx.restore();draw();return {gpu:!!decorRenderer,renderScale:decorRenderer?.renderScale,continuousFrames:fingerprints.size,changes,flags:flags.length,separated,animatedTrees:PW.objs.filter(o=>o.wind).length};
 })()""")
 assert result['flags']==2,result
 assert result['separated'],result
 assert result['continuousFrames']>=6,result
 for kind,data in result['changes'].items():
  assert data['moving']>0,(kind,data)
  fixed=data.get('rootChanges',data.get('attachmentChanges'))
  if fixed is not None:assert fixed==0,(kind,data)
 # The spatial wave must be smooth and continuous; trees must not all move in lockstep.
 assert await js('Math.abs(windAt(0,0,1)-windAt(0,0,1.0001))<.001')
 assert await js('Math.abs(windAt(0,0,1)-windAt(40,25,1))>.01')
 await js('PX=2;cam.x=0;cam.z=2;resize();draw()');await shot('04-wind.png')
 await asyncio.sleep(1)
 await shot('05-wind.png')
 # The visible GPU layer must not intercept selection input.
 await js('closeCharacterDialogue();PX=1;cam.x=0;cam.z=2;resize();draw()')
 pos=await js('(()=>{const p=project(core.x,3+Math.sin(currentTime*1.7)*.2,core.z);return [p.x,p.y]})()');await click(*pos)
 assert await js('HUD.anchor')
 await js('selectIndex(0);coreHP=70;units[0].ability=0;updateHUD(true)')
 await click_id('special');assert await js('coreHP')==85
 await js('const retainedRenderer=decorRenderer;decorRenderer=null;retainedRenderer.canvas.style.display="none";canvas.style.opacity="1";draw();decorRenderer=retainedRenderer;draw()')
 # Also exercise the smooth rendering path.
 await js('PIXEL=false;PX=1;resize();draw()');await asyncio.sleep(.2)
 assert not errors,errors
 print(json.dumps({'result':'PASS',**result,'timing':timing,'errors':errors,'screenshot':str(OUT/'04-wind.png')},ensure_ascii=False))
 await ws.close()
try:asyncio.run(test())
finally:chrome.terminate();chrome.wait(timeout=10);profile.cleanup()
