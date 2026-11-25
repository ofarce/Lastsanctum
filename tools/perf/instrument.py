#!/usr/bin/env python3
"""Enveloppe les fonctions choisies d'une COPIE du projet d'un chronomètre cumulé (Simulation.PROF).

    instrument.py <copie> [--extra fichier.gd:fonction ...] [--all-in fichier.gd ...]

Par défaut : _process, _physics_process, _draw de tous les scripts (hors tests/, addons/).
"""
import os
import re
import sys

root = sys.argv[1]
extra = {}
all_in = set()
args = sys.argv[2:]
i = 0
while i < len(args):
    if args[i] == "--extra":
        f, fn = args[i + 1].split(":")
        extra.setdefault(f, set()).add(fn)
        i += 2
    elif args[i] == "--all-in":
        all_in.add(args[i + 1])
        i += 2
    else:
        raise SystemExit("argument inconnu " + args[i])

DEFAULT = {"_process", "_physics_process", "_draw"}
FUNC = re.compile(r"^(static )?func (\w+)\((.*)\)( *-> *([\w.\[\], ]+))? *:(.*)$")


def split_params(s):
    out, depth, cur = [], 0, ""
    for ch in s:
        if ch in "([{":
            depth += 1
        elif ch in ")]}":
            depth -= 1
        if ch == "," and depth == 0:
            out.append(cur)
            cur = ""
        else:
            cur += ch
    if cur.strip():
        out.append(cur)
    return [re.split(r"[:=]", p.strip())[0].strip() for p in out]


count = 0
for dp, dn, fns in os.walk(root):
    rel_dir = os.path.relpath(dp, root)
    if rel_dir.split(os.sep)[0] in ("tests", "addons", ".godot", "build", "planches", "tools"):
        continue
    for fn in fns:
        if not fn.endswith(".gd"):
            continue
        path = os.path.join(dp, fn)
        rel = os.path.relpath(path, root)
        wanted = set(DEFAULT) | extra.get(rel, set())
        src = open(path, encoding="utf-8").read().split("\n")
        tail = []
        for n, line in enumerate(src):
            m = FUNC.match(line)
            if not m:
                continue
            static, name, params, _, ret, rest = m.groups()
            if name.startswith("__p_"):
                continue
            if name not in wanted and rel not in all_in:
                continue
            if rel == "sim/simulation.gd" and name in ("prof_add",):
                continue
            names = split_params(params)
            st = static or ""
            src[n] = f"{st}func __p_{name}({params}){' -> ' + ret if ret else ''}:{rest}"
            key = f"{rel}:{name}"
            call = f"__p_{name}({', '.join(names)})"
            tail.append(f"\n\n{st}func {name}({params}){' -> ' + ret if ret else ''}:")
            tail.append("\tvar __t := Time.get_ticks_usec()")
            if ret and ret != "void":
                tail.append(f"\tvar __r: {ret} = {call}")
                tail.append(f"\tSimulation.prof_add(\"{key}\", Time.get_ticks_usec() - __t)")
                tail.append("\treturn __r")
            elif ret == "void" or name in DEFAULT:
                tail.append(f"\t{call}")
                tail.append(f"\tSimulation.prof_add(\"{key}\", Time.get_ticks_usec() - __t)")
            else:
                tail.append(f"\tvar __r: Variant = {call}")
                tail.append(f"\tSimulation.prof_add(\"{key}\", Time.get_ticks_usec() - __t)")
                tail.append("\treturn __r")
            count += 1
        if tail:
            # les appels internes récursifs/directs passent aussi par l'enveloppe : temps inclusif
            open(path, "w", encoding="utf-8").write("\n".join(src) + "\n".join(tail) + "\n")

sim = os.path.join(root, "sim/simulation.gd")
s = open(sim, encoding="utf-8").read()
s += """

static var PROF: Dictionary = {}


static func prof_add(k: String, us: int) -> void:
	var r: Variant = PROF.get(k)
	if r == null:
		PROF[k] = [us, 1, us]
	else:
		r[0] += us
		r[1] += 1
		if us > r[2]:
			r[2] = us
"""
open(sim, "w", encoding="utf-8").write(s)

bench = os.path.join(root, "tests/perf/bench_run.gd")
b = open(bench, encoding="utf-8").read()
b = b.replace('\tvar f := FileAccess.open(_path("_summary.json"), FileAccess.WRITE)',
              '\tvar pf := FileAccess.open(_path("_prof.json"), FileAccess.WRITE)\n\tpf.store_string(JSON.stringify({"frames": frames.size(), "ticks": ticks.size(), "prof": Simulation.PROF}))\n\tpf.close()\n\tvar f := FileAccess.open(_path("_summary.json"), FileAccess.WRITE)')
open(bench, "w", encoding="utf-8").write(b)
print("fonctions enveloppées :", count)
