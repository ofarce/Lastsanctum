#!/usr/bin/env python3
"""Planche « grotte vivante » : insère la capture et l'atlas du Temple dans le gabarit.
python3 tools/grotte/build.py  (capture : godot --path . res://tests/visual/grotte_capture.tscn)"""
import base64, json, pathlib

ROOT = pathlib.Path(__file__).resolve().parents[2]
KEYS = ["brazier", "column", "rubble_a", "rubble_b", "quartz_s", "quartz_m", "puddle", "moss_a", "moss_b",
        "shrooms_a", "shrooms_b", "tuft_a"]


def uri(p):
    return "data:image/png;base64," + base64.b64encode(p.read_bytes()).decode()


rects = json.loads((ROOT / "assets/sanctum/props.json").read_text())
html = (ROOT / "tools/grotte/template.html").read_text()
html = html.replace("__BG__", uri(ROOT / "tests/visual/out/grotte/grotte_px3.png"))
html = html.replace("__ATLAS__", uri(ROOT / "assets/sanctum/props.png"))
html = html.replace("__RECTS__", json.dumps({k: rects[k] for k in KEYS}))
out = ROOT / "planches/grotte-vivante-propositions.html"
out.write_text(html)
print(out, len(html))
