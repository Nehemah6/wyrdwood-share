# Wyrdwood Survivors – Teststand

Ein 3D-Survivors-Spiel (Top-Down, Dark-Fairytale-Wald): Du bist eine Elfen-Druidin, deine Waffen schießen von allein,
du sammelst Kristalle, steigst auf und wählst Karten. Überlebe 15 Minuten; bei 10:00 erscheint der Boss.

## Schnellstart (CachyOS / Arch Linux)
```bash
git clone https://github.com/Nehemah6/wyrdwood-share.git && cd wyrdwood-share && chmod +x install.sh start.sh && ./install.sh && ./start.sh
```
(Mit SSH-Schlüssel geht auch `git@github.com:Nehemah6/wyrdwood-share.git`; bei einem privaten Repo ist die Anmeldung bei GitHub nötig.
Ohne Git: auf GitHub „Code → Download ZIP“, entpacken, im Ordner `chmod +x install.sh start.sh && ./install.sh && ./start.sh`.)

- **`install.sh`** prüft, ob Godot 4.7 da ist, installiert es sonst per `pacman` (fragt nach dem sudo-Passwort) und importiert einmal die
  Modelle (1–3 Minuten, ruhig warten). Ist Godot zu alt, sagt das Skript, wie du aktualisierst; es macht kein ungefragtes System-Update.
  Probelauf ohne Änderungen: `DRY_RUN=1 ./install.sh`.
- **`start.sh`** startet das Spiel. Zusätze gehen an Godot, z. B. Fenstermodus: `./start.sh --windowed`.
- Andere Systeme: Godot 4.7 (Standard-Version, nicht .NET) von <https://godotengine.org/download> laden, `project.godot` importieren, F5.

Läuft mit Vulkan (auf AMD über Mesa/RADV); bei der Radeon RX 9070 XT sollte ein aktuelles System ohne weiteres reichen. Das Spiel startet
im Vollbild, **F11** wechselt ins Fenster. In 4K nutzt es automatisch FSR2 (67 % Renderauflösung). Bei Rucklern hilft ein kleineres Fenster.

## Aktualisieren (neuer Teststand)
Im Spielordner:
```bash
git pull && ./install.sh
```
`git pull` holt den neuen Stand, `install.sh` importiert geänderte Modelle neu (geht schnell, wenn sich wenig geändert hat) und prüft
nebenbei die Godot-Version. Danach wie gewohnt `./start.sh`.

- **Ohne Git (ZIP):** neues ZIP laden, entpacken (am besten in einen frischen Ordner) und dort `chmod +x install.sh start.sh && ./install.sh`.
- **Spielstand** (Wurzelsplitter, Verstärkungen, Freischaltungen) bleibt erhalten; er liegt nicht im Spielordner, sondern unter
  `~/.local/share/godot/app_userdata/Wyrdwood Survivors/`.
- **`git pull` meldet einen Konflikt** (z. B. weil du Dateien geändert hast): `git fetch && git reset --hard origin/main && ./install.sh`, das verwirft
  lokale Änderungen im Spielordner (nicht den Spielstand).
- **Modelle fehlen oder sehen falsch aus:** einmal den Import-Cache löschen und neu importieren: `rm -rf .godot && ./install.sh`.

## Steuerung
| | |
|---|---|
| WASD / Pfeiltasten | Bewegen |
| Maus (links oder rechts) | Auf den Boden klicken = dorthin laufen; Taste halten = dem Cursor folgen (WASD hat Vorrang) |
| Mausrad | Zoom (rein/raus) |
| Level-Up | Karte anklicken oder Taste 1–3 |
| Esc | Pause (auch: Lauf beenden, Vollbild) |
| F11 | Vollbild an/aus |

Angreifen geht automatisch. Nach jedem Lauf gibt es **Wurzelsplitter**; im Hauptmenü unter *Verstärkungen* kaufst du damit
dauerhafte Boni, ab 300 Splittern schaltest du das zweite Level (*Aschemoor*) frei. Der Spielstand liegt lokal bei dir.

## Rückmeldung (gern kurz)
Was war zu leicht/zu schwer? Welche Waffe/Karte hat Spaß gemacht, welche nicht? Gab es Ruckler, Abstürze, Fehler?
Notiere bitte ungefähr die Zeit im Lauf und was gerade los war.
