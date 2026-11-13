"""Test navigateur des tourelles : boucle de rendu Canvas et GPU, clic droit et réparation gratuite. Dépendances : Chromium et le module Python websockets.
Exécuter : python3 tests/turret_browser_smoke.py. Captures : /tmp/lastsanctum-hud-qa.
"""
import asyncio,base64,json,os,shutil,subprocess,tempfile,urllib.request,sys
from pathlib import Path
import websockets
ROOT=Path(__file__).resolve().parents[1]
OUT=Path('/tmp/lastsanctum-hud-qa');OUT.mkdir(exist_ok=True)
profile=tempfile.TemporaryDirectory(prefix='lastsanctum-turret-test-',ignore_cleanup_errors=True)
binary=os.environ.get('CHROMIUM_BINARY') or ('/snap/chromium/current/usr/lib/chromium-browser/chrome' if Path('/snap/chromium/current/usr/lib/chromium-browser/chrome').exists() else shutil.which('chromium') or shutil.which('google-chrome'))
if not binary:raise SystemExit('Chromium introuvable : définir CHROMIUM_BINARY.')
chrome=subprocess.Popen([binary,'--headless','--no-sandbox','--disable-dev-shm-usage','--user-data-dir='+profile.name,'--remote-debugging-port=0','--remote-allow-origins=*','--allow-file-access-from-files','--window-size=1440,900',*(['--disable-webgl'] if (os.environ.get('TEST_DISABLE_WEBGL') or '--disable-webgl' in sys.argv) else []),'about:blank'],stdout=(OUT/'chrome.log').open('w'),stderr=subprocess.STDOUT)
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
 await call('Runtime.enable');await call('Page.enable');await call('Emulation.setDeviceMetricsOverride',{'width':1440,'height':900,'deviceScaleFactor':1,'mobile':False});await call('Page.navigate',{'url':(ROOT/'Index.html').as_uri()+('?renderer=webgl' if os.environ.get('TEST_RENDERER')=='webgl' else '')})
 for _ in range(200):
  if await js("typeof HUD!=='undefined'&&HUD.els&&typeof currentTime!=='undefined'&&currentTime>3.2"):break
  await asyncio.sleep(.15)
 else:raise AssertionError('Jeu non démarré')
 await js("window.turretDrawCount=0;window.turretDrawOriginal=drawTurret;drawTurret=function(b){window.turretDrawCount++;return window.turretDrawOriginal(b)}")
 before=await js("currentTime")
 await asyncio.sleep(.4)
 after=await js("currentTime")
 print(json.dumps({'before':before,'after':after,'bootErrors':errors}),flush=True)
 assert after>before,'Frame loop stopped after startup'
 assert await js('window.turretDrawCount')>2,'Turrets missing from real render loop'
 if os.environ.get('TEST_RENDERER')!='webgl':
  assert await js("decorRenderer===null&&canvas.style.opacity==='1'"),'Default game must remain visible without WebGL'
 timing=await js("(async()=>{const t=[];for(let i=0;i<30;i++)t.push(await new Promise(requestAnimationFrame));return {meanFrameMs:(t.at(-1)-t[0])/29}})()")
 print(json.dumps({'frameTiming':timing}),flush=True)
 info=await js("""(()=>{const u=units[0];u.hidden=false;const b=turrets[0],p=turretWorkPoint(b);u.x=p.x;u.z=p.z;u.tx=p.x;u.tz=p.z;const q=project(b.x,0,b.z);canvas.dispatchEvent(new MouseEvent('contextmenu',{clientX:q.x,clientY:q.y-20*Z()/16,bubbles:true,cancelable:true}));if(u.turretJob!==b)throw Error('Right click did not assign engineer');b.progress=0;return {turrets:turrets.length,gpu:!!decorRenderer,time:currentTime,spirit}})()""")
 await asyncio.sleep(.3)
 print(json.dumps({'nearCompletion':info,'errors':errors}),flush=True)
 await shot('turret-repair-frame.png')
 for _ in range(200):
  if await js('turrets[0].complete'):break
  await asyncio.sleep(.15)
 result=await js("({time:currentTime,progress:turrets[0].progress,complete:turrets[0].complete,visible:document.getElementById('game').style.opacity})")
 print(json.dumps({'result':result,'errors':errors}),flush=True)
 assert result['time']>after,'Frame loop stopped during repair'
 assert result['complete'],'Repair never completed'
 assert result['time']-info['time']>=7.95,'Repair skipped its eight seconds of work'
 assert await js('spirit')==info['spirit'],'Repair charged resources'
 await js("""(()=>{const b=turrets[0];b.cycleAge=3;enemies=[{x:b.x,z:b.z-40,hp:48,max:48,speed:0,range:1,damage:1,kind:'spitter',cooldown:1}];spawnQueue=[{at:1e6,x:0,kind:'creep'}]})()""")
 await asyncio.sleep(1)
 await shot('turret-after-repair.png')
 assert await js("enemies.length===0"),'Projectile did not eliminate medium enemy'
 await js('init()')
 restart=await js('currentTime');await asyncio.sleep(.5)
 assert await js('currentTime')>restart,'Restart left the frame loop frozen'
 assert not errors,errors
 print('PASS: native browser startup, rendering, repair transition, projectile impact and frame loop',flush=True)
 await ws.close()
try:asyncio.run(test())
finally:chrome.terminate();chrome.wait(timeout=10);profile.cleanup()
