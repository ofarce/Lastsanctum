#!/usr/bin/env python3
"""Construit planches/galeries-reliees-propositions.html : injecte tools/galeries/maps.json (grilles de 4 u
exportées par le prototype de raccordement) à la place de @@MAPS@@ dans le gabarit."""
import pathlib

ROOT = pathlib.Path(__file__).resolve().parents[2]
SRC = ROOT / "tools/galeries/template.html"
OUT = ROOT / "planches/galeries-reliees-propositions.html"
html = SRC.read_text(encoding="utf-8").replace("@@MAPS@@", (ROOT / "tools/galeries/maps.json").read_text(encoding="utf-8"))
OUT.write_text(html, encoding="utf-8")
print(OUT.relative_to(ROOT), len(html) // 1024, "Ko")
