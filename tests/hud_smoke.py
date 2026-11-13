"""Test navigateur du HUD. Dépendances : Chromium et le module Python websockets.
Exécuter : python3 tests/hud_smoke.py. Captures : /tmp/lastsanctum-hud-qa.
"""
import asyncio,base64,json,os,shutil,subprocess,tempfile,urllib.request
from pathlib import Path
import websockets
ROOT=Path(__file__).resolve().parents[1]
OUT=Path('/tmp/lastsanctum-hud-qa');OUT.mkdir(exist_ok=True)
profile=tempfile.TemporaryDirectory(prefix='lastsanctum-hud-test-')
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
  r=await call('Runtime.evaluate',{'expression':expr,'returnByValue':True})
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
 assert await js("document.getElementById('chosen').textContent")=='Ingénieur Exilé'
 assert await js("document.getElementById('anchor-details').hidden")
 assert await js("document.querySelectorAll('#action-panel [title]').length")==0
 assert await js("document.getElementById('build').disabled")
 dims=await js("[...document.querySelectorAll('.hud-module')].map(e=>{const r=e.getBoundingClientRect();return [r.top,r.height]})")
 assert len(set(tuple(x) for x in dims))==1,dims
 assert abs(await js("document.getElementById('command-bar').getBoundingClientRect().height")-120)<1
 await shot('01-engineer.png')
 pos=await js('(()=>{const p=project(core.x,3+Math.sin(currentTime*1.7)*.2,core.z);return [p.x,p.y]})()');await click(*pos)
 assert await js('HUD.anchor')
 assert await js("document.getElementById('chosen').textContent")=='Ancre tyrienne'
 assert not await js("document.getElementById('anchor-details').hidden")
 assert await js("document.getElementById('health-text').textContent")=='Intégrité : 100 %'
 await js('nextWave=currentTime+65;updateHUD(true)')
 assert await js("document.getElementById('assault-time').textContent")=='01:05'
 await shot('02-anchor.png')
 await js('nextWave=0;coreHP=70')
 await call('Input.dispatchKeyEvent',{'type':'keyDown','key':'1','code':'Digit1'});await call('Input.dispatchKeyEvent',{'type':'keyUp','key':'1','code':'Digit1'})
 assert not await js('HUD.anchor')
 await click_id('special')
 assert await js('coreHP')==85
 assert await js('units[0].ability>17')
 await click_id('hold');assert await js("units[0].stance==='hold'")
 await click_id('move-command');assert await js("HUD.mode==='move'")
 p=await js('(()=>{const p=project(-9,0,10);return [p.x,p.y]})()');await click(*p)
 assert await js("HUD.mode===null&&units[0].stance==='attack'&&Math.abs(units[0].tx+9)<.01")
 old=await js('[cam.x,cam.z]');await click_id('minimap');assert await js('[cam.x,cam.z]')!=old
 # Restart and invalid selection keys must remain safe.
 await click_id('restart');assert await js('units.length===1&&!HUD.anchor&&currentTime<1')
 await call('Input.dispatchKeyEvent',{'type':'keyDown','key':'9','code':'Digit9'});await call('Input.dispatchKeyEvent',{'type':'keyUp','key':'9','code':'Digit9'})
 # Narrow layouts must keep the strip on screen and preserve a level baseline.
 for width in [1024,800,600,390]:
  await call('Emulation.setDeviceMetricsOverride',{'width':width,'height':780,'deviceScaleFactor':1,'mobile':False})
  await asyncio.sleep(.15)
  overflow=await js("document.documentElement.scrollWidth>innerWidth")
  assert not overflow,('overflow',width)
  boxes=await js("[...document.querySelectorAll('.hud-module')].filter(e=>getComputedStyle(e).display!=='none').map(e=>{let r=e.getBoundingClientRect();return [r.top,r.height,r.right]})")
  assert max(b[2] for b in boxes)<=width,(width,boxes)
  assert len(set((b[0],b[1]) for b in boxes))==1,(width,boxes)
  if width==390:await shot('03-mobile.png')
 assert not errors,errors
 print(json.dumps({'result':'PASS','framesRunning':True,'anchorClick':True,'repair':True,'holdAndMove':True,'minimap':True,'uniformStrip':True,'viewports':[1440,1024,800,600,390],'errors':errors,'screenshots':str(OUT)},ensure_ascii=False))
 await ws.close()
try:asyncio.run(test())
finally:chrome.terminate();chrome.wait(timeout=10);profile.cleanup()
