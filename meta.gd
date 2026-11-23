extends Node
## Autoload "Meta": Speicherstand (Wurzelsplitter, Verstärkungen, Bestzeiten), aktuelles Level, Menü-/Lauf-Zustand.

const SAVE_PATH := "user://wyrdwood_save.json"

var shards := 0
var upgrades := {}            # id -> Stufe
var best := {}                # level_id -> beste Überlebenszeit (s)
var unlocked := ["wyrdwood"]
var runs := 0
var total_kills := 0
var level_id := "wyrdwood"
var skin := "druid"           # Spielfigur: Schlüssel in Main.SKINS (Optionen)
var in_menu := true           # true = Hauptmenü zeigen, false = Lauf starten

func _ready() -> void:
	load_save()

func load_save() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var d = JSON.parse_string(f.get_as_text())
	if typeof(d) != TYPE_DICTIONARY:
		return
	shards = int(d.get("shards", 0))
	upgrades = d.get("upgrades", {})
	best = d.get("best", {})
	unlocked = d.get("unlocked", ["wyrdwood"])
	runs = int(d.get("runs", 0))
	total_kills = int(d.get("total_kills", 0))
	skin = str(d.get("skin", "druid"))

func save() -> void:
	if (OS.has_environment("WW_SHOT") or OS.has_environment("WW_BOT")) and not OS.has_environment("WW_SAVE"):
		return      # Testläufe fassen den echten Speicherstand nicht an
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({"shards": shards, "upgrades": upgrades, "best": best, "unlocked": unlocked, "runs": runs, "total_kills": total_kills, "skin": skin}, "\t"))

func lvl(id: String) -> int:
	return int(upgrades.get(id, 0))

func upgrade_cost(id: String) -> int:
	return int(Defs.META_UPGRADES[id]["cost"]) * (lvl(id) + 1)

func can_buy(id: String) -> bool:
	return lvl(id) < int(Defs.META_UPGRADES[id]["max"]) and shards >= upgrade_cost(id)

func buy(id: String) -> bool:
	if not can_buy(id):
		return false
	shards -= upgrade_cost(id)
	upgrades[id] = lvl(id) + 1
	save()
	return true

func unlock_level(id: String) -> bool:
	var cost: int = Defs.LEVELS[id]["cost"]
	if unlocked.has(id) or shards < cost:
		return false
	shards -= cost
	unlocked.append(id)
	save()
	return true

# Ergebnis eines Laufs verbuchen; liefert verdiente Splitter
func finish_run(seconds: float, kills: int, level_reached: int, victory: bool, bonus: int = 0) -> int:
	var base := kills * 0.1 + seconds / 60.0 * 12.0 + level_reached * 3.0 + (150.0 if victory else 0.0) + bonus
	var earned := int(round(base * (1.0 + 0.08 * lvl("m_shards"))))
	shards += earned
	runs += 1
	total_kills += kills
	if seconds > float(best.get(level_id, 0.0)):
		best[level_id] = seconds
	save()
	return earned
