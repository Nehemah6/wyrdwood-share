#!/usr/bin/env bash
# Richtet alles ein, was Wyrdwood Survivors braucht: Godot 4.7 (über pacman) und einmal den Import der Modelle.
# Für CachyOS / Arch Linux. Aufruf im Spielordner:  ./install.sh      (Probelauf ohne Änderungen: DRY_RUN=1 ./install.sh)
set -euo pipefail
cd "$(dirname "$0")"

run() { if [ -n "${DRY_RUN:-}" ]; then echo "[Probelauf] $*"; else "$@"; fi; }
say() { printf '\n\033[1;32m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m %s\n' "$*" >&2; }

WHY=""            # warum version_ok fehlschlug: mono | old
version_ok() {   # Godot >= 4.7 und nicht die .NET-Version
    local v major minor
    WHY="old"
    v="$(godot --version 2>/dev/null | head -n1)" || return 1
    case "$v" in *mono*|*dotnet*) WHY="mono"; return 1 ;; esac
    major="$(echo "$v" | cut -d. -f1)"; minor="$(echo "$v" | cut -d. -f2)"
    [[ "$major" =~ ^[0-9]+$ && "$minor" =~ ^[0-9]+$ ]] || return 1
    [ "$major" -gt 4 ] || { [ "$major" -eq 4 ] && [ "$minor" -ge 7 ]; }
}

say "Prüfe Godot ..."
if command -v godot >/dev/null 2>&1 && version_ok; then
    echo "Godot ist da: $(godot --version | head -n1)"
else
    if ! command -v pacman >/dev/null 2>&1; then
        warn "pacman nicht gefunden. Bitte Godot 4.7 (Standard-Version) selbst installieren: https://godotengine.org/download"
        exit 1
    fi
    if command -v godot >/dev/null 2>&1; then
        if [ "$WHY" = "mono" ]; then
            warn "Installiert ist die .NET-Version ($(godot --version | head -n1)); gebraucht wird die Standard-Version."
            warn "Tausche sie aus mit:  sudo pacman -S godot   (ersetzt godot-mono)"
        else
            warn "Die installierte Godot-Version ist zu alt ($(godot --version | head -n1)). Aktualisiere mit:  sudo pacman -Syu godot"
            warn "(das aktualisiert das ganze System; das mache ich nicht ungefragt)"
        fi
        exit 1
    fi
    say "Installiere Godot und Git (sudo-Passwort nötig) ..."
    run sudo pacman -S --needed --noconfirm godot git || {
        warn "Installation fehlgeschlagen. Falls die Paketliste veraltet ist:  sudo pacman -Syu godot"
        exit 1
    }
    if [ -z "${DRY_RUN:-}" ] && ! version_ok; then
        warn "Godot ist installiert, aber nicht in Version 4.7 oder neuer: $(godot --version | head -n1)"
        warn "Ein System-Update (sudo pacman -Syu) bringt die aktuelle Version."
        exit 1
    fi
fi

say "Importiere die Spielmodelle (einmalig, 1-3 Minuten) ..."
run godot --headless --audio-driver Dummy --path . --import >/dev/null 2>&1 || warn "Import meldete einen Fehler; beim Start versucht Godot es nochmal."

chmod +x start.sh install.sh 2>/dev/null || true
say "Fertig. Starten mit:  ./start.sh"
