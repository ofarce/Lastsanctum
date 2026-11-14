import base64,re,subprocess,pathlib,sys
root=pathlib.Path(__file__).resolve().parent.parent
out=sys.argv[1] if len(sys.argv)>1 else root/'assets/portal-atlas.png'
dom=subprocess.run(['chromium','--headless','--disable-gpu','--allow-file-access-from-files','--virtual-time-budget=60000','--dump-dom',(root/'tests/bake-portal.html').as_uri()],capture_output=True,text=True).stdout
m=re.search(r'data:image/png;base64,([A-Za-z0-9+/=]+)',dom);pathlib.Path(out).write_bytes(base64.b64decode(m.group(1)));print('ok',out)
