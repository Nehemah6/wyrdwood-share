#!/usr/bin/env bash
# Holt den neuesten Teststand von GitHub und importiert geänderte Modelle. Doppelklick im Dateimanager genügt:
# ohne Terminal öffnet sich das Skript selbst in einem, damit man sieht, was passiert.
# Der Spielstand bleibt erhalten (liegt unter ~/.local/share/godot/app_userdata/, nicht im Spielordner).
cd "$(dirname "$(readlink -f "$0")")" || exit 1

if [ ! -t 1 ] && [ -z "${WW_IN_TERM:-}" ]; then
    export WW_IN_TERM=1
    for t in konsole kitty alacritty foot gnome-terminal xfce4-terminal xterm; do
        command -v "$t" >/dev/null 2>&1 || continue
        case "$t" in
            kitty|foot) exec "$t" bash "$0" ;;
            gnome-terminal) exec gnome-terminal -- bash "$0" ;;
            *) exec "$t" -e bash "$0" ;;
        esac
    done
    # kein Terminal gefunden: trotzdem ausführen, Ergebnis als Benachrichtigung
fi

say() { printf '\n\033[1;32m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m %s\n' "$*" >&2; }
finish() {   # Fenster offen lassen, damit man das Ergebnis lesen kann
    command -v notify-send >/dev/null 2>&1 && notify-send "Wyrdwood" "$1"
    if [ -t 0 ]; then read -rp $'\nEnter drücken zum Schließen ... ' _; fi
    exit "${2:-0}"
}

say "Hole den neuesten Stand ..."
if ! git fetch origin; then
    warn "GitHub ist nicht erreichbar (Internet? Anmeldung?)."
    finish "Aktualisieren fehlgeschlagen: keine Verbindung zu GitHub." 1
fi
if ! git merge --ff-only origin/main; then
    # lokal geänderte Dateien im Spielordner: verwerfen und den GitHub-Stand nehmen (Spielstand bleibt unberührt)
    warn "Lokale Änderungen im Spielordner, nehme den Stand von GitHub."
    git reset --hard origin/main || finish "Aktualisieren fehlgeschlagen (git reset)." 1
fi
chmod +x install.sh start.sh update.sh 2>/dev/null
echo "Stand: $(git log -1 --format='%cd · %s' --date=format:'%d.%m.%Y %H:%M')"

./install.sh || finish "Aktualisiert, aber die Installation meldete einen Fehler (siehe Fenster)." 1

if [ -t 0 ]; then
    read -rp $'\nSpiel jetzt starten? [J/n] ' a
    case "$a" in
        n|N|nein|Nein) ;;
        *) setsid ./start.sh >/dev/null 2>&1 < /dev/null & exit 0 ;;
    esac
fi
finish "Wyrdwood ist auf dem neuesten Stand."
