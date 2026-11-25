#!/usr/bin/env python3
import json
import sys

d = json.load(open(sys.argv[1]))
n = int(sys.argv[2]) if len(sys.argv) > 2 else 40
per = d["frames"] or d["ticks"]
unit = "image" if d["frames"] else "tick"
rows = sorted(d["prof"].items(), key=lambda kv: -kv[1][0])[:n]
print(f"{'fonction':70s} ms/{unit:6s} appels/{unit:5s} µs/appel  max ms")
for k, (us, calls, mx) in rows:
    print(f"{k:70s} {us / 1000 / per:8.3f} {calls / per:10.1f} {us / calls:9.1f} {mx / 1000:8.2f}")
