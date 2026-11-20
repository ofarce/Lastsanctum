#!/usr/bin/env python3
"""Exporte les trois squelettes de planches/squelettes-planche.html vers le jeu.

    python3 tools/squelettes/export.py      # depuis la racine du dépôt, puis : godot --headless --import

Écrit assets/imported/enemies/<kind>_<idle|walk|attack|death|hit>.png pour skeleton (collier), skeleton_bubo
(bubons) et skeleton_bomb (explosif), et leurs entrées dans manifest.json. Le dessin est celui de la planche
(le script en est extrait tel quel) ; les effets que le jeu doit dessiner lui-même (éclats, onde de bile,
souffle, boules de feu) n'y sont pas. Firefox headless rend la page, qui renvoie les PNG à un petit serveur
local : la transparence est conservée (flaque de bile, trace de brûlé).
"""
from __future__ import annotations

import base64
import http.server
import json
import re
import subprocess
import tempfile
import threading
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
EN = ROOT / "assets" / "imported" / "enemies"
KINDS = {"skeleton": "col", "skeleton_bubo": "bub", "skeleton_bomb": "exp"}
ACTIONS = ("idle", "walk", "attack", "death", "hit")
PORT = 8183

PAGE = r"""<!doctype html><meta charset="utf-8"><body><script>
%(engine)s
// Cadre 64 × 52, tampon du squelette posé en (10, 10) : pieds en (32, 43). Tourné vers la droite.
const FW=64,FH=52,OX=10,OY=10,AX=OX+X,AY=OY+GY,COLS=12,KINDS=%(kinds)s;
const CYCLE={col:.8,bub:1,exp:.5},STRIDE={col:4,bub:4,exp:5};
// Attaque : l'atlas commence à l'image du coup (les dégâts partent au début dans la simulation), l'armé est à la fin.
const START={col:.4,bub:.3,exp:.35},LOOP={col:1.1,bub:1.3,exp:1};
const PLAN=k=>({
 idle:{n:48,fps:12,t:i=>i/12},
 walk:{n:24,fps:24,t:i=>(i%%12)/12*CYCLE[k]},
 attack:{n:24,fps:24,t:i=>(START[k]+i/24)%%LOOP[k],duration:1},
 death:{n:k==='exp'?24:36,fps:24,t:i=>i/24},
 hit:{n:6,fps:24,t:i=>i/24,duration:.25}});
const A={idle:'idle',walk:'walk',attack:'atk',death:'death',hit:'hit'};
function cell(k,a,t){const c=document.createElement('canvas');c.width=FW;c.height=FH;const g=c.getContext('2d');
 const F=frame(k,A[a],t,{atlas:true});F.pre.forEach(f=>f(g,OX,OY));g.drawImage(render(F.b),OX,OY);F.fx.forEach(f=>f(g,OX,OY));return c}
const send=(n,body)=>{const x=new XMLHttpRequest();x.open('POST','/out/'+n,false);x.send(body);if(x.status>=300)throw new Error(n+' : '+x.status)};
const META={};
for(const[kind,k]of Object.entries(KINDS)){const P=PLAN(k),m={ax:AX,ay:AY,stride:STRIDE[k],self_bob:true};
 for(const[a,p]of Object.entries(P)){const rows=Math.ceil(p.n/COLS),s=document.createElement('canvas');s.width=FW*COLS;s.height=FH*rows;const g=s.getContext('2d');
  for(let i=0;i<p.n;i++){const c=cell(k,a,p.t(i));g.drawImage(c,(i%%COLS)*FW,Math.floor(i/COLS)*FH);
   if(a==='idle'&&i===0){const d=c.getContext('2d').getImageData(0,0,FW,FH).data;let top=FH;for(let y=0;y<FH&&top===FH;y++)for(let x=0;x<FW;x++)if(d[(y*FW+x)*4+3]){top=y;break}m.h=AY-top}}
  send(kind+'_'+a+'.png',s.toDataURL('image/png'));
  m[a]={frame_w:FW,frame_h:FH,cols:COLS,rows,count:p.n,fps:p.fps};if(p.duration)m[a].duration=p.duration}
 META[kind]=m}
send('meta.json',JSON.stringify(META));
</script></body>"""


def page() -> bytes:
    src = (ROOT / "planches" / "squelettes-planche.html").read_text(encoding="utf-8")
    engine = src[src.index("<script>") + 8:src.index("// ---------- Fonds ----------")]
    return (PAGE % {"engine": engine, "kinds": json.dumps(KINDS)}).encode("utf-8")


class Handler(http.server.BaseHTTPRequestHandler):
    done = threading.Event()

    def log_message(self, *a) -> None:
        pass

    def do_GET(self) -> None:
        body = page()
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_POST(self) -> None:
        name = self.path.removeprefix("/out/")
        body = self.rfile.read(int(self.headers.get("Content-Length", 0)))
        m = re.fullmatch(r"(\w+)_(\w+)\.png", name)
        if m and m.group(1) in KINDS and m.group(2) in ACTIONS:
            data = base64.b64decode(body.split(b",", 1)[1])
            if not data.startswith(b"\x89PNG"):
                self.send_error(400, "PNG attendu")
                return
            (EN / name).write_bytes(data)
        elif name == "meta.json":
            path = EN / "manifest.json"
            man = json.loads(path.read_text(encoding="utf-8"))
            for kind, entry in json.loads(body).items():
                if kind in KINDS:
                    man["enemies"][kind] = entry
            man["squelettes"] = "planches/squelettes-planche.html (tools/squelettes/export.py) : " + ", ".join(KINDS)
            path.write_text(json.dumps(man, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
            Handler.done.set()
        else:
            self.send_error(403, "cible refusée")
            return
        self.send_response(204)
        self.end_headers()


def main() -> None:
    srv = http.server.ThreadingHTTPServer(("127.0.0.1", PORT), Handler)
    threading.Thread(target=srv.serve_forever, daemon=True).start()
    with tempfile.TemporaryDirectory() as tmp:
        t = Path(tmp)
        (t / "prof").mkdir()
        subprocess.run(["firefox", "--headless", "--no-remote", "--profile", str(t / "prof"), "--window-size=200,200",
                        "--screenshot", str(t / "x.png"), f"http://127.0.0.1:{PORT}/"], check=True, timeout=120, capture_output=True)
    srv.shutdown()
    if not Handler.done.is_set():
        raise SystemExit("Export incomplet : le manifeste n'a pas été reçu.")
    man = json.loads((EN / "manifest.json").read_text(encoding="utf-8"))["enemies"]
    for kind in KINDS:
        print(kind, "h =", man[kind]["h"], {a: man[kind][a]["count"] for a in ACTIONS})


if __name__ == "__main__":
    main()
