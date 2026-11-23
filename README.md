# Wyrdwood Survivors – Teststand

Ein 3D-Survivors-Spiel im Dark-Fairytale-Look (Top-Down): Du bist eine Elfen-Druidin, deine Waffen schießen von allein. Du weichst aus, sammelst
Spirit-Kristalle, steigst auf und baust dir aus **12 Waffen** und **12 Ausrüstungsstücken** (je 6 Plätze) einen Build. Die Masse an Gegnern
ist die Herausforderung; am Ende wartet ein Boss.

| Level | Freischaltung | Besonderheit |
|---|---|---|
| **Wyrdwood** | von Anfang an | Dunkler Märchenwald, Boss: *Der verderbte Hirsch* (15:00), Ziel: 20 Minuten überleben |
| **Aschemoor** | 300 Wurzelsplitter | Ausgebrannter Sumpf, mehr Wölfe, früher Zauberer, härter |
| **Totenacker** | 500 Wurzelsplitter | Friedhof unter Blutmond, Ghule und Knochenhexen, Boss: *Der Grabwächter* |

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

Läuft mit Vulkan (AMD über Mesa/RADV, NVIDIA mit dem proprietären Treiber). Das Spiel startet im Vollbild, **F11** wechselt ins Fenster.

**Grafik** (*Optionen → Grafik*, wird gespeichert):
- **Supersampling 1,4×** (Standard): ruhigstes Bild ohne Nachziehen, braucht eine starke GPU.
- **Nativ:** volle Auflösung mit MSAA und FXAA, schärfer und leichter.
- **FSR 2 Quality:** spart die meiste Leistung, kann bei Bewegung etwas nachziehen.

Bei Rucklern auf „Nativ" oder „FSR 2" wechseln oder ein kleineres Fenster nutzen.

## Aktualisieren (neuer Teststand)
**Doppelklick auf `update.sh`** im Spielordner (im Dateimanager ggf. „Ausführen“ wählen). Es öffnet sich ein Fenster, das den neuen
Stand von GitHub holt, geänderte Modelle neu importiert und danach fragt, ob das Spiel starten soll.

Im Terminal geht dasselbe mit `./update.sh` oder von Hand mit `git pull && ./install.sh`.
(Gibt es `update.sh` bei dir noch nicht: einmal im Spielordner `git pull` ausführen, danach ist es da.)

- **Ohne Git (ZIP):** neues ZIP laden, entpacken (am besten in einen frischen Ordner) und dort `chmod +x install.sh start.sh && ./install.sh`.
- **Spielstand** (Wurzelsplitter, Verstärkungen, Freischaltungen) bleibt erhalten; er liegt nicht im Spielordner, sondern unter
  `~/.local/share/godot/app_userdata/Wyrdwood Survivors/`.
- **Lokale Änderungen im Spielordner** (z. B. eine Datei bearbeitet): `update.sh` verwirft sie und nimmt den Stand von GitHub; von Hand:
  `git fetch && git reset --hard origin/main && ./install.sh`. Der Spielstand bleibt dabei erhalten.
- **Modelle fehlen oder sehen falsch aus:** einmal den Import-Cache löschen und neu importieren: `rm -rf .godot && ./install.sh`.

## Steuerung
| | |
|---|---|
| WASD / Pfeiltasten / Controller-Stick | Bewegen |
| Maus (links oder rechts) | Auf den Boden klicken = dorthin laufen; Taste halten = dem Cursor folgen (WASD hat Vorrang) |
| Mausrad | Zoom (rein/raus) |
| Level-Up | Karte anklicken, Taste 1–3 oder Controller (A) – Waffen stehen immer links |
| Esc | Pause (auch: Lauf beenden, Vollbild) |
| F11 | Vollbild an/aus |
| Controller | Stick = laufen · A = wählen · B = zurück · LB/RB = Zoom · Start = Pause |

Angreifen geht automatisch. Herzbeeren, die Gegner fallen lassen, heilen dich (bei wenig Leben fallen sie öfter). Nach jedem Lauf gibt es
**Wurzelsplitter**; im Hauptmenü unter *Verstärkungen* kaufst du damit dauerhafte Boni und schaltest neue Level frei.
Unter *Optionen* wählst du außerdem die Figur (Druidin oder Elfe mit Schwert). Der Spielstand liegt lokal bei dir.

## Rückmeldung (gern kurz)
Was war zu leicht/zu schwer (Anfang, Mitte, Boss)? Welche Waffe/Karte hat Spaß gemacht, welche nicht? Gab es Ruckler, Abstürze, Fehler?
Notiere bitte ungefähr die Zeit im Lauf und was gerade los war.
