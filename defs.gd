class_name Defs
extends RefCounted
## Alle Spieldaten an einer Stelle: Waffen (Werte pro Stufe), Passive, Gegner-Archetypen.
## Neue Waffe/Passiv = hier eintragen + Verhalten in main.gd / weapons_extra.gd; Karten, HUD-Symbole und Level-Up folgen automatisch.

const MAX_WEAPONS := 6
const MAX_PASSIVES := 6

# Waffen: name, max (Stufen), icon (Zeichen-Schlüssel / PNG ui/icons/<id>.png), desc, stat_labels (Anzeigename, Format)
const WEAPONS := {
	"thorn": {"name": "Dornenpfeil", "max": 8, "desc": "Schießt Dornen auf den nächsten Gegner. Ab Stufe 3 prallen sie an Wänden ab.",
		"labels": {"dmg": ["Schaden", "%d"], "cd": ["Pause", "%.2fs"], "count": ["Pfeile", "%d"], "pierce": ["Durchschlag", "%s"], "bounce": ["Abpraller", "%d"]}},
	"acorn": {"name": "Eichelbombe", "max": 8, "desc": "Wirft Eicheln, die in einer Fläche explodieren.",
		"labels": {"dmg": ["Schaden", "%d"], "cd": ["Pause", "%.2fs"], "radius": ["Radius", "%.1fm"], "count": ["Bomben", "%d"]}},
	"orbs": {"name": "Geisterkugeln", "max": 8, "desc": "Kreisende Wisps schützen dich und verbrennen Gegner.",
		"labels": {"dmg": ["Schaden", "%d"], "count": ["Wisps", "%d"], "radius": ["Bahn", "%.1fm"]}},
	"roots": {"name": "Wurzelschlag", "max": 8, "desc": "Wurzeln brechen unter Gegnern hervor und halten sie fest.",
		"labels": {"dmg": ["Schaden", "%d"], "cd": ["Pause", "%.2fs"], "count": ["Ziele", "%d"], "radius": ["Radius", "%.1fm"]}},
	"scythe": {"name": "Mondsichel", "max": 8, "desc": "Eine Sichel fliegt durch alle Gegner, prallt an Wänden ab und kehrt zurück.",
		"labels": {"dmg": ["Schaden", "%d"], "cd": ["Pause", "%.2fs"], "count": ["Sicheln", "%d"], "range": ["Reichweite", "%.0fm"]}},
	"chain": {"name": "Funkenkette", "max": 8, "desc": "Ein Blitz springt von Gegner zu Gegner.",
		"labels": {"dmg": ["Schaden", "%d"], "cd": ["Pause", "%.2fs"], "jumps": ["Sprünge", "%d"], "chains": ["Ketten", "%d"]}},
	"spores": {"name": "Sporenwolke", "max": 8, "desc": "Giftige Sporen um dich herum verlangsamen und schaden.",
		"labels": {"dps": ["Schaden/s", "%.0f"], "radius": ["Radius", "%.1fm"], "slow": ["Verlangsamung", "%d%%"]}},
	"fireflies": {"name": "Glühkäferschwarm", "max": 8, "desc": "Leuchtkäfer suchen sich selbst ihr Ziel und lenken nach.",
		"labels": {"dmg": ["Schaden", "%d"], "cd": ["Pause", "%.2fs"], "count": ["Käfer", "%d"]}},
	"bramble": {"name": "Dornenpfad", "max": 8, "desc": "Wo du läufst, wachsen Dornen. Sie verlangsamen und verletzen.",
		"labels": {"dps": ["Schaden/s", "%.0f"], "dur": ["Dauer", "%.1fs"], "radius": ["Radius", "%.1fm"]}},
	"beam": {"name": "Sternenstrahl", "max": 8, "desc": "Ein Lichtstrahl trifft alles in einer Linie.",
		"labels": {"dmg": ["Schaden", "%d"], "cd": ["Pause", "%.2fs"], "len": ["Länge", "%.0fm"], "width": ["Breite", "%.1fm"], "count": ["Strahlen", "%d"]}},
	"frost": {"name": "Raureif-Nova", "max": 8, "desc": "Eisiger Ring: stößt Gegner zurück und friert sie kurz ein.",
		"labels": {"dmg": ["Schaden", "%d"], "cd": ["Pause", "%.2fs"], "radius": ["Radius", "%.1fm"], "freeze": ["Frost", "%.1fs"]}},
	"bark": {"name": "Rindenschild", "max": 8, "desc": "Fängt Treffer ab. Bricht er, fliegen Splitter um dich.",
		"labels": {"charges": ["Ladungen", "%d"], "recharge": ["Aufladen", "%.1fs"], "burst": ["Splitter", "%d"]}},
}

# Passive: name, max, desc (pro Stufe)
const PASSIVES := {
	"might": {"name": "Wutwurzel", "max": 10, "desc": "+5% Schaden"},
	"swift": {"name": "Waldläufer-Stiefel", "max": 8, "desc": "+4% Tempo"},
	"vigor": {"name": "Lebensbaum", "max": 10, "desc": "+10 Max-Leben"},
	"magnet": {"name": "Kristallmagnet", "max": 6, "desc": "+15% Sammelreichweite"},
	"haste": {"name": "Mondtau", "max": 8, "desc": "-4% Abklingzeit"},
	"area": {"name": "Weite Wurzeln", "max": 8, "desc": "+6% Wirkungsbereich"},
	"regen": {"name": "Moosherz", "max": 6, "desc": "+0,25 Leben pro Sekunde"},
	"greed": {"name": "Glückspilz", "max": 8, "desc": "+6% Erfahrung"},
	"armor": {"name": "Eisenrinde", "max": 8, "desc": "-5% erlittener Schaden"},
	"dodge": {"name": "Nebelmantel", "max": 6, "desc": "+4% Chance, Treffern auszuweichen"},
	"crit": {"name": "Sternensplitter", "max": 8, "desc": "+5% Chance auf kritische Treffer (doppelter Schaden)"},
	"twin": {"name": "Zwillingssaat", "max": 2, "desc": "+1 Geschoss für Pfeile, Bomben, Sicheln, Käfer, Wurzeln, Strahlen und Ketten"},
}

# Gesamtwirkung einer Passiv-Stufe (für Tooltip/Karten)
static func passive_total(id: String, l: int) -> String:
	match id:
		"might": return "+%d%% Schaden" % (5 * l)
		"swift": return "+%d%% Tempo" % (4 * l)
		"vigor": return "+%d Max-Leben" % (10 * l)
		"magnet": return "+%d%% Sammelreichweite" % (15 * l)
		"haste": return "-%d%% Abklingzeit" % (4 * l)
		"area": return "+%d%% Wirkungsbereich" % (6 * l)
		"regen": return "+%.2f Leben pro Sekunde" % (0.25 * l)
		"greed": return "+%d%% Erfahrung" % (6 * l)
		"armor": return "-%d%% erlittener Schaden" % (5 * l)
		"dodge": return "%d%% Ausweichen" % (4 * l)
		"crit": return "%d%% Krit-Chance" % (5 * l)
		"twin": return "+%d Geschoss%s" % [l, "e" if l > 1 else ""]
	return ""

# Gegner-Archetypen: Modell (Library), Leben, Tempo, Kontaktschaden, XP, Fallback-Farbe, Größe (Trefferradius ~ sz*0.8), Rolle
const ENEMIES := {
	"imp":    {"m": "creatures/thorn_imp_v2.glb",      "hp": 8.0,   "spd": 3.4, "dmg": 4.0,  "xp": 1,   "col": Color(0.6, 0.35, 0.1),  "sz": 0.5, "role": "rusher"},
	"toad":   {"m": "creatures/bog_toad_v3.glb",       "hp": 22.0,  "spd": 1.9, "dmg": 7.0,  "xp": 2,   "col": Color(0.3, 0.5, 0.2),   "sz": 0.5, "role": "rusher", "cap": 60},
	"wolf":   {"m": "creatures/moss_wolf_v2.glb",      "hp": 14.0,  "spd": 5.2, "dmg": 6.0,  "xp": 2,   "col": Color(0.2, 0.5, 0.5),   "sz": 0.5, "role": "rusher"},
	"tank":   {"m": "creatures/shell_tortoise.glb", "hp": 120.0, "spd": 1.3, "dmg": 12.0, "xp": 8,   "col": Color(0.45, 0.4, 0.3),  "sz": 0.9, "role": "tank", "armor": 0.5, "cap": 20},
	"caster": {"m": "creatures/thorn_shaman.glb",   "hp": 22.0,  "spd": 2.2, "dmg": 4.0,  "xp": 5,   "col": Color(0.3, 0.8, 0.8),   "sz": 0.5, "role": "caster", "range": 9.0, "shot_dmg": 7.0, "shot_cd": 3.0, "cap": 18},
	"healer": {"m": "creatures/spore_healer_v2.glb",   "hp": 26.0,  "spd": 1.8, "dmg": 3.0,  "xp": 6,   "col": Color(1.0, 0.55, 0.2),  "sz": 0.4, "role": "healer", "heal": 7.0, "heal_range": 7.0, "cap": 6},
	"golem":  {"m": "creatures/root_golem_v2.glb",     "hp": 160.0, "spd": 1.6, "dmg": 16.0, "xp": 15,  "col": Color(0.4, 0.25, 0.15), "sz": 1.2, "role": "elite"},
	"stag":   {"m": "creatures/corrupted_stag_v2.glb", "hp": 2500.0, "spd": 2.6, "dmg": 28.0, "xp": 100, "col": Color(0.1, 0.4, 0.4),  "sz": 2.0, "role": "boss"},
	# --- Totenacker (Horror) · "alt" = Platzhalter-Typ, bis das eigene Modell aus dem Asset Desk da ist
	"ghoul":    {"m": "creatures/grave_ghoul.glb",     "hp": 10.0,  "spd": 3.2, "dmg": 5.0,  "xp": 1,   "col": Color(0.45, 0.5, 0.42), "sz": 0.5, "role": "rusher", "alt": "imp"},
	"skeleton": {"m": "creatures/bone_soldier.glb",    "hp": 18.0,  "spd": 2.4, "dmg": 7.0,  "xp": 2,   "col": Color(0.85, 0.82, 0.7), "sz": 0.5, "role": "rusher", "alt": "caster", "cap": 70},
	"hound":    {"m": "creatures/corpse_hound.glb",    "hp": 12.0,  "spd": 5.8, "dmg": 6.0,  "xp": 2,   "col": Color(0.5, 0.2, 0.2),   "sz": 0.5, "role": "rusher", "alt": "wolf"},
	"flesh":    {"m": "creatures/stitched_brute.glb",  "hp": 150.0, "spd": 1.2, "dmg": 14.0, "xp": 9,   "col": Color(0.6, 0.4, 0.4),   "sz": 0.9, "role": "tank", "armor": 0.45, "alt": "tank", "cap": 20},
	"witch":    {"m": "creatures/bone_witch.glb",      "hp": 24.0,  "spd": 2.2, "dmg": 4.0,  "xp": 5,   "col": Color(0.6, 0.3, 0.8),   "sz": 0.5, "role": "caster", "range": 9.5, "shot_dmg": 8.0, "shot_cd": 2.8, "alt": "caster", "cap": 18},
	"priest":   {"m": "creatures/plague_priest.glb",   "hp": 28.0,  "spd": 1.8, "dmg": 3.0,  "xp": 6,   "col": Color(0.5, 0.7, 0.3),   "sz": 0.45, "role": "healer", "heal": 8.0, "heal_range": 7.0, "alt": "healer", "cap": 6},
	"horror":   {"m": "creatures/bone_abomination.glb", "hp": 190.0, "spd": 1.7, "dmg": 18.0, "xp": 16, "col": Color(0.55, 0.3, 0.3),  "sz": 1.2, "role": "elite", "alt": "golem"},
	"warden":   {"m": "creatures/grave_warden.glb",    "hp": 3000.0, "spd": 2.4, "dmg": 30.0, "xp": 100, "col": Color(0.4, 0.15, 0.2), "sz": 2.0, "role": "boss", "alt": "stag"},
}

# ---------- Schwierigkeit pro Minute (gilt für alle Level; Level-Faktor "rate" kommt obendrauf) ----------
# rate = Gegner/s, hp/dmg = Multiplikator auf die Grundwerte
static func difficulty(minute: float) -> Dictionary:
	return {
		"rate": 1.0 + 0.45 * minute + 0.018 * minute * minute,
		"hp": 1.0 + 0.14 * minute + 0.04 * minute * minute,
		"dmg": 1.0 + 0.1 * minute + 0.004 * minute * minute,
		"spd": 1.0 + 0.015 * minute,
	}

# XP bis zur nächsten Stufe (Stufe 1 -> 2 = 5)
static func xp_need(level: int) -> int:
	var k := level - 1
	return int(5 + 6 * k + 0.15 * k * k)

static func weapon_stats(id: String, l: int) -> Dictionary:
	l = maxi(1, l)
	match id:
		"thorn":
			return {"dmg": 9.0 + 2.0 * l, "cd": maxf(0.32, 0.9 - 0.07 * l), "count": 1 + (l + 1) / 3, "pierce": "ja" if l >= 3 else "nein", "bounce": l / 3}
		"acorn":
			return {"dmg": 12.0 + 2.2 * l, "cd": maxf(0.9, 2.8 - 0.22 * l), "radius": 2.0 + 0.18 * l, "count": 1 + l / 4}
		"orbs":
			return {"dmg": 5.0 + 1.1 * l, "count": 1 + (l + 1) / 2, "radius": 2.2 + 0.1 * l, "speed": 2.4 + 0.12 * l}
		"roots":
			return {"dmg": 14.0 + 2.6 * l, "cd": maxf(1.4, 3.4 - 0.25 * l), "count": 2 + l / 2, "radius": 1.2 + 0.08 * l, "stun": 0.8 + 0.08 * l}
		"scythe":
			return {"dmg": 10.0 + 1.8 * l, "cd": maxf(1.6, 3.8 - 0.26 * l), "count": 1 + l / 4, "range": 9.0 + 0.5 * l}
		"chain":
			return {"dmg": 11.0 + 2.6 * l, "cd": maxf(0.8, 2.0 - 0.15 * l), "jumps": 4 + l, "range": 5.5, "chains": 1 + l / 6}
		"spores":
			return {"dps": 5.0 + 2.2 * l, "radius": 2.6 + 0.22 * l, "slow": 22 + 3 * l}
		"fireflies":
			return {"dmg": 9.0 + 2.4 * l, "cd": maxf(0.6, 1.6 - 0.12 * l), "count": 3 + l / 2, "speed": 9.0 + 0.4 * l}
		"bramble":
			return {"dps": 7.0 + 2.4 * l, "dur": 2.5 + 0.25 * l, "radius": 0.9 + 0.07 * l, "every": maxf(0.9, 1.6 - 0.08 * l)}
		"beam":
			return {"dmg": 14.0 + 3.0 * l, "cd": maxf(1.4, 3.2 - 0.22 * l), "len": 9.0 + 0.6 * l, "width": 0.45 + 0.05 * l, "count": 1 + l / 6}
		"frost":
			return {"dmg": 8.0 + 2.0 * l, "cd": maxf(2.2, 5.0 - 0.32 * l), "radius": 3.2 + 0.25 * l, "freeze": 0.8 + 0.12 * l, "knock": 1.6 + 0.1 * l}
		"bark":
			return {"charges": 1 + l / 3, "recharge": maxf(3.0, 9.0 - 0.7 * l), "burst": 12.0 + 4.0 * l, "burst_r": 2.6 + 0.12 * l}
	return {}

# Text "Schaden 12 → 15" für die Karte (Unterschiede zwischen Stufe l und l+1)
static func weapon_diff_lines(id: String, l: int) -> Array:
	var a := weapon_stats(id, l) if l > 0 else {}
	var b := weapon_stats(id, l + 1)
	var labels: Dictionary = WEAPONS[id]["labels"]
	var out := []
	for k in labels:
		if not b.has(k):
			continue
		var fmt: String = labels[k][1]
		var nb: String = fmt % b[k]
		if l <= 0:
			out.append("%s %s" % [labels[k][0], nb])
		elif a.get(k) != b[k]:
			out.append("%s %s → %s" % [labels[k][0], fmt % a[k], nb])
	return out

# ---------- Meta-Fortschritt: dauerhafte Verstärkungen (Kosten = base * (Stufe+1)) ----------
const META_UPGRADES := {
	"m_hp": {"name": "Zähe Rinde", "max": 10, "cost": 40, "desc": "+5 Max-Leben", "icon": "vigor"},
	"m_dmg": {"name": "Alte Wut", "max": 10, "cost": 60, "desc": "+2% Schaden", "icon": "might"},
	"m_speed": {"name": "Leichter Tritt", "max": 5, "cost": 50, "desc": "+2% Tempo", "icon": "swift"},
	"m_magnet": {"name": "Sammlerblick", "max": 5, "cost": 40, "desc": "+10% Sammelreichweite", "icon": "magnet"},
	"m_xp": {"name": "Schnelles Lernen", "max": 5, "cost": 70, "desc": "+3% Erfahrung", "icon": "greed"},
	"m_shards": {"name": "Erntezeit", "max": 5, "cost": 80, "desc": "+8% Wurzelsplitter", "icon": "regen"},
	"m_revive": {"name": "Wiedergeburt", "max": 1, "cost": 400, "desc": "Einmal pro Lauf mit halbem Leben wiederaufstehen", "icon": "area"},
}

# ---------- Arena: Halbe Breite/Tiefe (m). 1 Bildschirm bei Zoom 1 ≈ 24 × 14 m -> 3 × 3 Bildschirme ----------
const ARENA_HALF := Vector2(36.0, 21.0)
const WALL_INSET := 1.4      # so weit vor der Wandlinie ist Schluss (Figur/Gegner)

# ---------- Kollision: Radius (m) des Fußes pro Prop-Modell; nicht gelistete Props sind begehbar ----------
const PROP_COLLIDE := {
	"nature/gnarled_tree.glb": 0.7, "nature/mossy_boulder.glb": 0.8, "structures/standing_stone.glb": 0.85,
	"nature/dead_oak.glb": 0.55, "structures/crooked_gravestone.glb": 0.45, "structures/broken_crypt.glb": 1.8,
}

# ---------- Level als Daten ----------
# time: Siegzeit (s) · rate: Spawn-Faktor · env: Stimmung · tint: Bodenfarbe · props: [Datei, Gewicht, Fallbackfarbe, Fallbackgröße]
# spawn: [ab Minute, Typ, Gewicht] · boss: Typ/Zeitpunkt · elite: Typ, erster Auftritt (min), Abstand (s)
const LEVELS := {
	"wyrdwood": {
		"name": "Wyrdwood", "desc": "Der dunkle Märchenwald. Überlebe 20 Minuten.", "time": 1200.0, "cost": 0, "rate": 1.0,
		"env": {"bg": Color(0.03, 0.05, 0.05), "ambient": Color(0.35, 0.45, 0.5), "fog": Color(0.05, 0.1, 0.1), "sun": Color(0.7, 0.85, 1.0), "vfog": Color(0.45, 0.7, 0.7)},
		"tint": Color(1, 1, 1), "ground": "forest_floor_v3", "diff": 1, "boss_icon": "stag",
		"wall": [["nature/bramble_hedge.glb", 0.0, Color(0.2, 0.25, 0.12), 4.0], ["nature/gnarled_tree.glb", 0.45, Color(0.25, 0.18, 0.1), 5.0], ["nature/mossy_boulder.glb", 0.4, Color(0.3, 0.35, 0.3), 1.8], ["structures/standing_stone.glb", 0.15, Color(0.4, 0.4, 0.45), 3.0]],
		"props": [["nature/gnarled_tree.glb", 0.5, Color(0.25, 0.18, 0.1), 3.0], ["nature/mossy_boulder.glb", 0.2, Color(0.3, 0.35, 0.3), 1.5],
			["nature/glow_mushrooms.glb", 0.2, Color(0.2, 0.9, 0.8), 0.7], ["structures/standing_stone.glb", 0.1, Color(0.4, 0.4, 0.45), 2.5]],
		"spawn": [[0.0, "imp", 6.0], [1.5, "toad", 4.0], [3.0, "wolf", 4.0], [3.0, "tank", 1.2], [4.0, "caster", 1.2], [5.0, "healer", 0.8]],
		"boss": {"type": "stag", "time": 900.0, "name": "Der verderbte Hirsch", "banner": "Der verderbte Hirsch erwacht!"},
		"elite": {"type": "golem", "first": 2.0, "every": 45.0},
	},
	"ashen_marsh": {
		"name": "Aschemoor", "desc": "Ein ausgebrannter Sumpf aus Asche und verkohltem Schilf. Mehr Wölfe, früher Zauberer.", "time": 1200.0, "cost": 300, "rate": 1.1, "hp_mult": 1.25, "dmg_mult": 1.15,
		"env": {"bg": Color(0.05, 0.035, 0.03), "ambient": Color(0.42, 0.38, 0.35), "fog": Color(0.1, 0.06, 0.05), "sun": Color(1.0, 0.82, 0.68), "vfog": Color(0.5, 0.4, 0.35)},
		"tint": Color(1.0, 0.95, 0.9), "ground": "ashen_ground", "diff": 2,
		"wall": [["nature/gnarled_tree.glb", 0.4, Color(0.2, 0.12, 0.08), 5.0], ["nature/mossy_boulder.glb", 0.6, Color(0.3, 0.25, 0.22), 1.8]],
		"props": [["nature/mossy_boulder.glb", 0.45, Color(0.3, 0.25, 0.22), 1.5], ["structures/standing_stone.glb", 0.2, Color(0.4, 0.35, 0.32), 2.5],
			["nature/gnarled_tree.glb", 0.2, Color(0.2, 0.12, 0.08), 3.0], ["nature/glow_mushrooms.glb", 0.15, Color(1.0, 0.5, 0.2), 0.7]],
		"spawn": [[0.0, "imp", 3.0], [0.5, "wolf", 6.0], [2.0, "tank", 2.0], [2.5, "caster", 2.0], [3.0, "toad", 3.0], [4.0, "healer", 1.0]],
		"boss": {"type": "stag", "time": 840.0, "name": "Der verderbte Hirsch", "banner": "Der verderbte Hirsch erwacht!"},
		"elite": {"type": "golem", "first": 1.5, "every": 35.0},
	},
	"totenacker": {
		"name": "Totenacker", "desc": "Ein verfluchter Friedhof unter dem Blutmond. Die Toten stehen auf, Ghule und Knochenhexen jagen dich.", "time": 1200.0, "cost": 500, "rate": 1.1, "hp_mult": 1.5, "dmg_mult": 1.3,
		"env": {"bg": Color(0.015, 0.015, 0.025), "ambient": Color(0.46, 0.47, 0.6), "fog": Color(0.06, 0.06, 0.09), "sun": Color(0.72, 0.78, 1.0), "sun_energy": 1.05, "vfog": Color(0.42, 0.42, 0.5), "vfog_emit": Color(0.02, 0.0, 0.0), "saturation": 0.75},
		"tint": Color(1.0, 1.0, 1.05), "ground": "grave_soil", "diff": 3,
		"wall": [["structures/graveyard_fence.glb", 0.0, Color(0.15, 0.15, 0.17), 4.0], ["nature/dead_oak.glb", 0.35, Color(0.15, 0.12, 0.12), 4.5, "nature/gnarled_tree.glb"],
			["structures/crooked_gravestone.glb", 0.4, Color(0.35, 0.35, 0.38), 1.3, "structures/standing_stone.glb"], ["structures/broken_crypt.glb", 0.25, Color(0.3, 0.3, 0.33), 4.0, "nature/mossy_boulder.glb"]], "lantern": Color(0.75, 0.9, 1.0), "embers": Color(1.0, 0.3, 0.2),
		"props": [["nature/dead_oak.glb", 0.3, Color(0.15, 0.12, 0.12), 4.5, "nature/gnarled_tree.glb"],
			["structures/crooked_gravestone.glb", 0.32, Color(0.35, 0.35, 0.38), 1.3, "structures/standing_stone.glb"],
			["decor/bone_pile.glb", 0.14, Color(0.8, 0.78, 0.7), 1.0, "nature/mossy_boulder.glb"],
			["lighting/grave_candles.glb", 0.12, Color(1.0, 0.7, 0.3), 0.6, "nature/glow_mushrooms.glb"],
			["structures/broken_crypt.glb", 0.12, Color(0.3, 0.3, 0.33), 4.0, "structures/standing_stone.glb"]],
		"spawn": [[0.0, "ghoul", 6.0], [1.0, "skeleton", 4.0], [2.5, "hound", 4.0], [3.0, "flesh", 1.3], [3.5, "witch", 1.4], [5.0, "priest", 0.9]],
		"boss": {"type": "warden", "time": 900.0, "name": "Der Grabwächter", "banner": "Der Grabwächter erhebt sich!"},
		"elite": {"type": "horror", "first": 2.0, "every": 40.0},
	},
}
