#!/usr/bin/env bash
# Startet Wyrdwood Survivors. Zusätze gehen direkt an Godot, z. B. Fenstermodus:  ./start.sh --windowed
set -euo pipefail
cd "$(dirname "$0")"
if ! command -v godot >/dev/null 2>&1; then
    echo "Godot fehlt, starte zuerst die Installation ..."
    ./install.sh
fi
exec godot --path . "$@"
