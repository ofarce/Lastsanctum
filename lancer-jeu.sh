#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd -- "$PROJECT_DIR"

GODOT_BIN="${GODOT_BIN:-godot}"
if ! command -v "$GODOT_BIN" >/dev/null 2>&1; then
    echo "Godot est introuvable. Installez-le ou définissez GODOT_BIN." >&2
    exit 1
fi

mkdir -p build/linux
echo "Mise à jour du build Linux…"
"$GODOT_BIN" --headless --path "$PROJECT_DIR" --log-file "$PROJECT_DIR/build/export.log" --export-release Linux
echo "Lancement du jeu…"
exec "$PROJECT_DIR/build/linux/exiles.x86_64" "$@"
