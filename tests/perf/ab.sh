#!/usr/bin/env bash
# A/B de non-régression sur copies figées du projet (le dossier de travail peut changer pendant la mesure).
#   tests/perf/ab.sh <dossier_temp> <fichier> [<fichier>...]
# A = projet tel quel ; B = même instantané, avec les fichiers donnés remis comme dans HEAD.
# Joue tests/perf/bench.gd en mode sim dans les deux et compare les empreintes d'état (compare.py).
# Code de sortie 1 si les parties divergent.
set -euo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
TMP="$1"; shift
GODOT="${GODOT_BIN:-godot}"
SECONDS_SIM="${AB_SECONDS:-900}"
rm -rf "$TMP"; mkdir -p "$TMP"
rsync -a --exclude=.git --exclude=tests/perf/out --exclude=tests/visual/out --exclude=build "$ROOT/" "$TMP/A/"
rsync -a "$TMP/A/" "$TMP/B/"
for f in "$@"; do
	if git -C "$ROOT" cat-file -e "HEAD:$f" 2>/dev/null; then
		git -C "$ROOT" show "HEAD:$f" > "$TMP/B/$f"
	else
		rm -f "$TMP/B/$f"
	fi
done
for v in A B; do
	(cd "$TMP/$v" && "$GODOT" --headless --path . -s res://tests/perf/bench.gd -- --mode=sim --seconds="$SECONDS_SIM" \
		--out=tests/perf/out/ab_$v 2>&1 | grep -E "^bench|SCRIPT ERROR" | cut -c1-140) &
done
wait
python3 "$ROOT/tests/perf/compare.py" "$TMP/B/tests/perf/out/ab_B_summary.json" "$TMP/A/tests/perf/out/ab_A_summary.json"
