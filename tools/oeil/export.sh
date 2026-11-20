#!/bin/sh
# Exporte l'Œil de la Matrice : capture headless de planches/oeil-matrice-export.html, puis découpe (cut.py).
set -e
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
TMP=$(mktemp -d)
mkdir -p "$TMP/prof"
firefox --headless --no-remote --profile "$TMP/prof" --screenshot "$TMP/shot.png" --window-size=1600,4314 \
	"file://$ROOT/planches/oeil-matrice-export.html"
python3 "$ROOT/tools/oeil/cut.py" "$TMP/shot.png"
rm -rf "$TMP"
