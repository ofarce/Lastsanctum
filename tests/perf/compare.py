#!/usr/bin/env python3
"""Compare deux résumés de tests/perf/bench.gd : empreintes d'état (non-régression) et écarts de performance.

    python3 tests/perf/compare.py tests/perf/out/ref_render_summary.json tests/perf/out/apres_render_summary.json

Code de sortie 1 si une empreinte d'état diffère (comportement du jeu modifié) ; mode sim seulement.
"""
import json
import sys


def load(p):
    with open(p, encoding="utf-8") as f:
        return json.load(f)


def delta(a, b):
    if not a:
        return "   n/a"
    return f"{(b - a) / a * 100:+6.1f}%"


def main():
    if len(sys.argv) != 3:
        print(__doc__)
        return 2
    a, b = load(sys.argv[1]), load(sys.argv[2])
    ok = True
    ha, hb = a["hashes"], b["hashes"]
    n = min(len(ha), len(hb))
    first = next((i for i in range(n) if ha[i] != hb[i]), None)
    if a.get("mode") == "render" or b.get("mode") == "render":
        # Mode rendu : l'étincelle de l'Ancre est animée en temps réel, le début de la surcharge (et donc la
        # suite de la partie) varie d'une exécution à l'autre. La non-régression se vérifie en mode « sim ».
        print("Mode rendu : empreintes non comparées (partie non déterministe), voir le mode sim")
    elif first is not None:
        ok = False
        print(f"ÉTAT DIFFÉRENT à partir de t = {ha[first].split(':')[0]} s (empreinte {first + 1}/{n})")
    elif len(ha) != len(hb):
        ok = False
        print(f"ÉTAT : nombre d'empreintes différent ({len(ha)} contre {len(hb)})")
    else:
        print(f"État identique ({n} empreintes, toutes les 10 s de simulation)")
    print()
    print(f"{'mesure':34} {'avant':>10} {'après':>10}  écart")
    for key in ("frame_ms", "tick_ms", "think_ms"):
        for q in ("avg", "p50", "p95", "p99", "max"):
            va, vb = a[key][q], b[key][q]
            print(f"{key + ' ' + q:34} {va:10.3f} {vb:10.3f} {delta(va, vb)}")
    for k in a["peaks"]:
        va, vb = a["peaks"][k], b["peaks"].get(k, 0)
        print(f"{'pic ' + k:34} {va:10.1f} {vb:10.1f} {delta(va, vb)}")
    print()
    for phase, ra in a["sim_profile"].items():
        rb = b["sim_profile"].get(phase, {"avg_ms": 0, "max_ms": 0})
        print(f"{'sim ' + phase + ' avg':34} {ra['avg_ms']:10.4f} {rb['avg_ms']:10.4f} {delta(ra['avg_ms'], rb['avg_ms'])}")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
