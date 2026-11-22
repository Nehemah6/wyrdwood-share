class_name Defs
extends RefCounted
## Alle Spieldaten an einer Stelle: Waffen (Werte pro Stufe), Passive, Gegner-Archetypen.
## Neue Waffe/Passiv = hier eintragen + Verhalten in main.gd / weapons_extra.gd; Karten, HUD-Symbole und Level-Up folgen automatisch.

const MAX_WEAPONS := 6
const MAX_PASSIVES := 6

# Waffen: name, max (Stufen), icon (Zeichen-Schlüssel / PNG ui/icons/<id>.png), desc, stat_labels (Anzeigename, Format)
const WEAPONS := {
	"thorn": {"name": "Dornenpfeil", "max": 8, "desc": "Schießt Dornen auf den nächsten Gegner.",
		"labels": {"dmg": ["Schaden", "%d"], "cd": ["Pause", "%.2fs"], "count": ["Pfeile", "%d"], "pierce": ["Durchschlag", "%s"]}},
	"acorn": {"name": "Eichelbombe", "max": 8, "desc": "Wirft Eicheln, die in einer Fläche explodieren.",
		"labels": {"dmg": ["Schaden", "%d"], "cd": ["Pause", "%.2fs"], "radius": ["Radius", "%.1fm"], "count": ["Bomben", "%d"]}},
	"orbs": {"name": "Geisterkugeln", "max": 8, "desc": "Kreisende Wisps schützen dich und verbrennen Gegner.",
		"labels": {"dmg": ["Schaden", "%d"], "count": ["Wisps", "%d"], "radius": ["Bahn", "%.1fm"]}},
	"roots": {"name": "Wurzelschlag", "max": 8, "desc": "Wurzeln brechen unter Gegnern hervor und halten sie fest.",
		"labels": {"dmg": ["Schaden", "%d"], "cd": ["Pause", "%.2fs"], "count": ["Ziele", "%d"], "radius": ["Radius", "%.1fm"]}},
	"scythe": {"name": "Mondsichel", "max": 8, "desc": "Eine Sichel fliegt durch alle Gegner und kehrt zurück.",
		"labels": {"dmg": ["Schaden", "%d"], "cd": ["Pause", "%.2fs"], "count": ["Sicheln", "%d"], "range": ["Reichweite", "%.0fm"]}},
	"chain": {"name": "Funkenkette", "max": 8, "desc": "Ein Blitz springt von Gegner zu Gegner.",
		"labels": {"dmg": ["Schaden", "%d"], "cd": ["Pause", "%.2fs"], "jumps": ["Sprünge", "%d"]}},
	"spores": {"name": "Sporenwolke", "max": 8, "desc": "Giftige Sporen um dich herum verlangsamen und schaden.",
		"labels": {"dps": ["Schaden/s", "%.0f"], "radius": ["Radius", "%.1fm"], "slow": ["Verlangsamung", "%d%%"]}},
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
}

# Gegner-Archetypen: Modell (Library), Leben, Tempo, Kontaktschaden, XP, Fallback-Farbe, Größe (Trefferradius ~ sz*0.8), Rolle
const ENEMIES := {
	"imp":    {"m": "creatures/thorn_imp_v2.glb",      "hp": 8.0,   "spd": 3.4, "dmg": 4.0,  "xp": 1,   "col": Color(0.6, 0.35, 0.1),  "sz": 0.5, "role": "rusher"},
	"toad":   {"m": "creatures/bog_toad_v3.glb",       "hp": 22.0,  "spd": 1.9, "dmg": 7.0,  "xp": 2,   "col": Color(0.3, 0.5, 0.2),   "sz": 0.5, "role": "rusher"},
	"wolf":   {"m": "creatures/moss_wolf_v2.glb",      "hp": 14.0,  "spd": 5.2, "dmg": 6.0,  "xp": 2,   "col": Color(0.2, 0.5, 0.5),   "sz": 0.5, "role": "rusher"},
	"tank":   {"m": "creatures/shell_tortoise.glb", "hp": 120.0, "spd": 1.3, "dmg": 12.0, "xp": 8,   "col": Color(0.45, 0.4, 0.3),  "sz": 0.9, "role": "tank", "armor": 0.5},
	"caster": {"m": "creatures/thorn_shaman.glb",   "hp": 30.0,  "spd": 2.2, "dmg": 4.0,  "xp": 5,   "col": Color(0.3, 0.8, 0.8),   "sz": 0.5, "role": "caster", "range": 10.0, "shot_dmg": 9.0, "shot_cd": 2.4},
	"healer": {"m": "creatures/spore_healer_v2.glb",   "hp": 26.0,  "spd": 1.8, "dmg": 3.0,  "xp": 6,   "col": Color(1.0, 0.55, 0.2),  "sz": 0.4, "role": "healer", "heal": 7.0, "heal_range": 7.0},
	"golem":  {"m": "creatures/root_golem_v2.glb",     "hp": 160.0, "spd": 1.6, "dmg": 16.0, "xp": 15,  "col": Color(0.4, 0.25, 0.15), "sz": 1.2, "role": "elite"},
	"stag":   {"m": "creatures/corrupted_stag_v2.glb", "hp": 2500.0, "spd": 2.6, "dmg": 28.0, "xp": 100, "col": Color(0.1, 0.4, 0.4),  "sz": 2.0, "role": "boss"},
}

static func weapon_stats(id: String, l: int) -> Dictionary:
	l = maxi(1, l)
	match id:
		"thorn":
			return {"dmg": 8.0 + 1.4 * l, "cd": maxf(0.32, 0.95 - 0.07 * l), "count": 1 + l / 3, "pierce": "ja" if l >= 5 else "nein"}
		"acorn":
			return {"dmg": 12.0 + 2.2 * l, "cd": maxf(0.9, 2.8 - 0.22 * l), "radius": 2.0 + 0.18 * l, "count": 1 + l / 5}
		"orbs":
			return {"dmg": 5.0 + 1.1 * l, "count": 1 + (l + 1) / 2, "radius": 2.2 + 0.1 * l, "speed": 2.4 + 0.12 * l}
		"roots":
			return {"dmg": 14.0 + 2.6 * l, "cd": maxf(1.4, 3.4 - 0.25 * l), "count": 2 + l / 2, "radius": 1.2 + 0.08 * l, "stun": 0.8 + 0.08 * l}
		"scythe":
			return {"dmg": 10.0 + 1.8 * l, "cd": maxf(1.6, 3.8 - 0.26 * l), "count": 1 + l / 4, "range": 8.0 + 0.5 * l}
		"chain":
			return {"dmg": 9.0 + 1.7 * l, "cd": maxf(0.9, 2.3 - 0.16 * l), "jumps": 3 + l / 2, "range": 5.0}
		"spores":
			return {"dps": 5.0 + 2.2 * l, "radius": 2.6 + 0.22 * l, "slow": 22 + 3 * l}
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

# ---------- Level als Daten ----------
# time: Siegzeit (s) · rate: Spawn-Faktor · env: Stimmung · tint: Bodenfarbe · props: [Datei, Gewicht, Fallbackfarbe, Fallbackgröße]
# spawn: [ab Minute, Typ, Gewicht] · boss: Typ/Zeitpunkt · elite: Typ, erster Auftritt (min), Abstand (s)
const LEVELS := {
	"wyrdwood": {
		"name": "Wyrdwood", "desc": "Der dunkle Märchenwald. Überlebe 15 Minuten.", "time": 900.0, "cost": 0, "rate": 1.0,
		"env": {"bg": Color(0.03, 0.05, 0.05), "ambient": Color(0.35, 0.45, 0.5), "fog": Color(0.05, 0.1, 0.1), "sun": Color(0.7, 0.85, 1.0), "vfog": Color(0.45, 0.7, 0.7)},
		"tint": Color(1, 1, 1),
		"props": [["nature/gnarled_tree.glb", 0.5, Color(0.25, 0.18, 0.1), 3.0], ["nature/mossy_boulder.glb", 0.2, Color(0.3, 0.35, 0.3), 1.5],
			["nature/glow_mushrooms.glb", 0.2, Color(0.2, 0.9, 0.8), 0.7], ["structures/standing_stone.glb", 0.1, Color(0.4, 0.4, 0.45), 2.5]],
		"spawn": [[0.0, "imp", 6.0], [1.5, "toad", 4.0], [3.0, "wolf", 4.0], [3.0, "tank", 1.2], [4.0, "caster", 1.2], [5.0, "healer", 0.8]],
		"boss": {"type": "stag", "time": 600.0, "name": "Der verderbte Hirsch", "banner": "Der verderbte Hirsch erwacht!"},
		"elite": {"type": "golem", "first": 2.0, "every": 45.0},
	},
	"ashen_marsh": {
		"name": "Aschemoor", "desc": "Ein verbrannter Sumpf voller Glut. Mehr Wölfe, früher Zauberer. (Eigene Assets folgen.)", "time": 900.0, "cost": 300, "rate": 1.15,
		"env": {"bg": Color(0.05, 0.035, 0.03), "ambient": Color(0.42, 0.38, 0.35), "fog": Color(0.1, 0.06, 0.05), "sun": Color(1.0, 0.82, 0.68), "vfog": Color(0.5, 0.4, 0.35)},
		"tint": Color(1.08, 0.88, 0.8),
		"props": [["nature/mossy_boulder.glb", 0.45, Color(0.3, 0.25, 0.22), 1.5], ["structures/standing_stone.glb", 0.2, Color(0.4, 0.35, 0.32), 2.5],
			["nature/gnarled_tree.glb", 0.2, Color(0.2, 0.12, 0.08), 3.0], ["nature/glow_mushrooms.glb", 0.15, Color(1.0, 0.5, 0.2), 0.7]],
		"spawn": [[0.0, "imp", 3.0], [0.5, "wolf", 6.0], [2.0, "tank", 2.0], [2.5, "caster", 2.0], [3.0, "toad", 3.0], [4.0, "healer", 1.0]],
		"boss": {"type": "stag", "time": 540.0, "name": "Der verderbte Hirsch", "banner": "Der verderbte Hirsch erwacht!"},
		"elite": {"type": "golem", "first": 1.5, "every": 35.0},
	},
}
