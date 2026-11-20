#!/usr/bin/env python3
"""Exporte vers le jeu les bâtiments retenus sur planches/biomes-batiments-finaux.html (boucles travail et repos).

    python3 tools/biomes-batiments/export.py      # puis : godot --headless --path . --import

Écrit planches/biomes-batiments-export.html (moteur embarqué), l'ouvre dans Firefox headless avec ?save=sync, et
reçoit les fichiers par le serveur de tools/batiments-16bits/export.py : assets/baked/buildings/da-<type>_{anim,rest,base}.png,
hud/portraits/bld-<type>.png et buildings.arts.da-<type> du manifeste. Pour l'Église, « travail » = la nuit.
"""
from __future__ import annotations

import http.server, importlib.util, json, subprocess, sys, tempfile, threading
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
# type du jeu, art, nom du modèle retenu, durée de la boucle (s)
PICKS = [["eglise", "da-eglise", "Campanile sans cloche", 6], ["ecole", "da-ecole", "Géode ouverte", 6]]


def load(path: Path, name: str):
    spec = importlib.util.spec_from_file_location(name, path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def main() -> None:
    build = load(HERE / "build.py", "bb_build")          # réécrit aussi la planche, à l'identique
    srv_mod = load(ROOT / "tools/batiments-16bits/export.py", "b16_export")
    srv_mod.TARGETS.clear()
    for t, art, _n, _l in PICKS:
        for k in ("anim", "rest", "base"):
            srv_mod.TARGETS[f"{art}_{k}.png"] = srv_mod.BAKED / "buildings" / f"{art}_{k}.png"
        srv_mod.TARGETS[f"bld-{t}.png"] = srv_mod.BAKED / "hud" / "portraits" / f"bld-{t}.png"
        srv_mod.TARGETS[f"meta-{art}.json"] = srv_mod.BAKED / "manifest.json"
    page = """<!doctype html>
<html lang="fr"><head><meta charset="utf-8"><title>Export des bâtiments des biomes</title>
<style>body{margin:0;padding:16px;background:#0b120e;color:#dcd8bc;font:14px/1.4 system-ui,sans-serif}canvas{image-rendering:pixelated;background:#223}figure{display:inline-block;margin:6px}</style></head><body>
<h1 style="font-size:18px;margin:0">Export des bâtiments des biomes (choix du 2026-11-20)</h1>
<p>Sprites 320 × 240, ancre (160, 168), échelle 1. Deux boucles : <code>_anim</code> (au travail) et <code>_rest</code> (au repos), 12 i/s. <code>?save=sync</code> est lancé par <code>tools/biomes-batiments/export.py</code>.</p>
<p id="log"></p><div id="out"></div>
<script>
/*ENGINE*/
</script>
<script>
'use strict';
const PICKS=/*PICKS*/;
const save=new URLSearchParams(location.search).get('save'),log=document.querySelector('#log'),out=document.querySelector('#out');
const post=(n,b)=>{const x=new XMLHttpRequest();x.open('POST','/out/'+n,false);x.send(b);if(x.status>=300)throw new Error(n+' '+x.status)};
try{for(const[type,art,name,L]of PICKS){const i=BAT.ITEMS.findIndex(it=>it.name===name);if(i<0)throw new Error('modèle introuvable : '+name);
  BAT.setWork(1);const w=BAT.exportSprite(i,Math.round(L*12),12);BAT.setWork(0);const r=BAT.exportSprite(i,Math.round(L*12),12);BAT.setWork(1);
  const meta={...w.meta,top:Math.min(w.meta.top,r.meta.top),bottom:Math.max(w.meta.bottom,r.meta.bottom),rest:r.meta.anim,pick:name};
  for(const[c,cap]of[[w.base,name+' · travail'],[r.base,'repos'],[w.portrait,'portrait']]){const f=document.createElement('figure');f.append(c,document.createElement('br'),cap);out.append(f)}
  if(save){post(art+'_anim.png',w.sheet.toDataURL('image/png'));post(art+'_rest.png',r.sheet.toDataURL('image/png'));post(art+'_base.png',w.base.toDataURL('image/png'));post('bld-'+type+'.png',w.portrait.toDataURL('image/png'));post('meta-'+art+'.json',JSON.stringify(meta))}}
 log.textContent=save?'Écrit : travail, repos, base, portrait, manifeste.':'Aperçu seulement.'}catch(e){log.textContent='Erreur : '+e.message;if(save)post('erreur.txt',String(e&&e.stack||e));throw e}
</script></body></html>
"""
    page = page.replace("/*ENGINE*/", build.js.replace("</script", "<\\/script")).replace("/*PICKS*/", json.dumps(PICKS, ensure_ascii=False))
    (ROOT / "planches/biomes-batiments-export.html").write_text(page)
    srv = http.server.ThreadingHTTPServer(("127.0.0.1", 0), srv_mod.Handler)
    threading.Thread(target=srv.serve_forever, daemon=True).start()
    with tempfile.TemporaryDirectory() as tmp:
        (Path(tmp) / "prof").mkdir()
        subprocess.run(["firefox", "--headless", "--no-remote", "--profile", str(Path(tmp) / "prof"), "--window-size=1400,900",
                        "--screenshot", str(HERE / "export-apercu.png"),
                        f"http://127.0.0.1:{srv.server_address[1]}/biomes-batiments-export.html?save=sync"],
                       check=True, timeout=300, capture_output=True)
    srv.shutdown()
    print(len(srv_mod.WRITTEN), "fichiers écrits :", ", ".join(srv_mod.WRITTEN))
    if srv_mod.ERRORS or len(srv_mod.WRITTEN) != len(srv_mod.TARGETS):
        sys.exit("ÉCHEC : " + ("; ".join(srv_mod.ERRORS) or "export incomplet"))


if __name__ == "__main__":
    main()
