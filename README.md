# Wyrdwood Survivors – Teststand

Ein 3D-Survivors-Spiel (Top-Down, Dark-Fairytale-Wald): Du bist eine Elfen-Druidin, deine Waffen schießen von allein,
du sammelst Kristalle, steigst auf und wählst Karten. Überlebe 15 Minuten; bei 10:00 erscheint der Boss.

## Starten (CachyOS / Arch Linux)
1. Godot und Git installieren: `sudo pacman -S godot git` (es muss **Godot 4.7** sein, nicht die .NET-Version; `godot --version` prüft das).
2. Spiel herunterladen: `git clone git@github.com:Nehemah6/wyrdwood-share.git` (oder auf GitHub „Code → Download ZIP“ und entpacken).
3. Starten: `godot --path wyrdwood-share` – oder `godot` öffnen, **Importieren**, `project.godot` wählen, dann **F5**.
   Beim ersten Mal importiert Godot die Modelle (1–3 Minuten, ruhig warten).

Läuft mit Vulkan (auf AMD über Mesa/RADV); bei der Radeon RX 9070 XT sollte ein aktuelles System ohne weiteres reichen. Das Spiel startet
im Vollbild, **F11** wechselt ins Fenster. In 4K nutzt es automatisch FSR2 (67 % Renderauflösung). Bei Rucklern hilft ein kleineres Fenster.

## Steuerung
| | |
|---|---|
| WASD / Pfeiltasten | Bewegen |
| Mausrad | Zoom (rein/raus) |
| Level-Up | Karte anklicken oder Taste 1–3 |
| Esc | Pause (auch: Lauf beenden, Vollbild) |
| F11 | Vollbild an/aus |

Angreifen geht automatisch. Nach jedem Lauf gibt es **Wurzelsplitter**; im Hauptmenü unter *Verstärkungen* kaufst du damit
dauerhafte Boni, ab 300 Splittern schaltest du das zweite Level (*Aschemoor*) frei. Der Spielstand liegt lokal bei dir.

## Rückmeldung (gern kurz)
Was war zu leicht/zu schwer? Welche Waffe/Karte hat Spaß gemacht, welche nicht? Gab es Ruckler, Abstürze, Fehler?
Notiere bitte ungefähr die Zeit im Lauf und was gerade los war.
