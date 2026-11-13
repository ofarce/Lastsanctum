"""Vérifie les cinq casernes, les transitions et le curseur dans Chromium."""
import asyncio,base64,json,os,shutil,subprocess,tempfile,urllib.request
from pathlib import Path
import websockets
ROOT=Path(__file__).resolve().parents[1]
OUT=Path('/tmp/lastsanctum-hud-qa');OUT.mkdir(exist_ok=True)
profile=tempfile.TemporaryDirectory(prefix='lastsanctum-turret-test-',ignore_cleanup_errors=True)
binary=os.environ.get('CHROMIUM_BINARY') or ('/snap/chromium/current/usr/lib/chromium-browser/chrome' if Path('/snap/chromium/current/usr/lib/chromium-browser/chrome').exists() else shutil.which('chromium') or shutil.which('google-chrome'))
if not binary:raise SystemExit('Chromium introuvable : définir CHROMIUM_BINARY.')
chrome=subprocess.Popen([binary,'--headless','--no-sandbox','--disable-dev-shm-usage','--user-data-dir='+profile.name,'--remote-debugging-port=0','--remote-allow-origins=*','--allow-file-access-from-files','--window-size=1440,900','about:blank'],stdout=(OUT/'chrome.log').open('w'),stderr=subprocess.STDOUT)
async def test():
 for _ in range(100):
  try:
   port=(Path(profile.name)/'DevToolsActivePort').read_text().splitlines()[0]
   tabs=json.load(urllib.request.urlopen('http://localhost:'+port+'/json'));break
  except Exception:await asyncio.sleep(.1)
 else:raise RuntimeError('Chromium ne démarre pas ; consulter /tmp/lastsanctum-hud-qa/chrome.log')
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
 await call('Runtime.enable')
 await call('Page.enable')
 await call('Page.navigate',{'url':(ROOT/'caserne-propositions.html').as_uri()})
 await asyncio.sleep(1)
 assert await js('cards.length')==5
 result=await js("""(()=>{let results=[];for(const D of BarracksKit.DESIGNS)for(const t of [0,3,5.99,6,8,10.99,11,16.99,17,23,29,31.99]){const g=document.createElement('canvas').getContext('2d');const s=BarracksKit.render(g,D,t);if(t===6&&(!s.instructor||s.instructor.x!==300))throw Error('spawn');if(t===11&&(s.instructor.x!==160||s.instructor.y!==177))throw Error('centre');if(t===29&&s.soldiers!==3)throw Error('soldats');results.push(s.phase)}return results.length})()""")
 await js("seek.value=19;seek.oninput()")
 await asyncio.sleep(.2)
 shot=await call('Page.captureScreenshot',{'format':'png','captureBeyondViewport':True})
 (ROOT/'design/caserne/apercu.png').write_bytes(base64.b64decode(shot['data']))
 assert await js('paused && t===19')
 assert not errors,errors
 print({'renders':result,'errors':errors,'controls':'PASS'})
 await ws.close()
try:asyncio.run(test())
finally:chrome.terminate();chrome.wait(timeout=10);profile.cleanup()
