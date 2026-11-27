class_name RigAnim
extends RefCounted
## Prozeduraler Laufzyklus für SkinTokens-Skelette (generische Namen bone_N).
## Beine werden automatisch aus der Skelettgeometrie erkannt (Fuß-Blätter -> Kette bis zur Verzweigung).
## Pro Typ nur Datei, Maße und Gangart; Wurzel, Vorwärtsrichtung, Kopf-/Schwanz-/Arm-/Rumpfketten werden automatisch erkannt
## (jede Angabe in CFG überschreibt die Automatik, z. B. imp/stag).
## Typ-Daten werden einmal berechnet (Cache), pro Gegner nur Skeleton + Phase.

const CFG := {
	# Pro Typ nur Datei, echte Größe (längste Seite, m) und Gangart; der Rest kommt aus der Skelett-Erkennung.
	"imp": {
		"file": "res://models/creatures/thorn_imp_v2.glb", "longest": 0.9, "gait": "biped",
		"amp": 0.6, "freq": 2.6, "bob": 0.03, "lean": 0.15, "arm_amp": 0.8,
	},
	"toad": {
		"file": "res://models/creatures/bog_toad_v3.glb", "longest": 1.0, "gait": "hop",
		"amp": 0.7, "freq": 1.5, "bob": 0.16,
	},
	"wolf": {
		"file": "res://models/creatures/moss_wolf_v2.glb", "longest": 1.0, "gait": "diag",
		"amp": 0.75, "freq": 2.3, "bob": 0.03,
	},
	"tank": {
		"file": "res://models/creatures/shell_tortoise.glb", "longest": 1.8, "gait": "diag",
		"amp": 0.35, "freq": 1.6, "bob": 0.015,
	},
	"caster": {
		"file": "res://models/creatures/thorn_shaman.glb", "longest": 1.3, "gait": "biped",
		"amp": 0.45, "freq": 2.0, "bob": 0.03, "arm_amp": 0.35, "sway": 0.04,
	},
	"healer": {
		"file": "res://models/creatures/spore_healer_v2.glb", "longest": 0.8, "gait": "biped",
		"amp": 0.55, "freq": 2.4, "bob": 0.05, "arm_amp": 0.5, "sway": 0.06,
	},
	"golem": {
		"file": "res://models/creatures/root_golem_v2.glb", "longest": 2.4, "gait": "biped",
		"amp": 0.3, "freq": 2.0, "bob": 0.035, "lean": 0.0, "arm_amp": 0.45, "sway": 0.07,
	},
	"stag": {
		"file": "res://models/creatures/corrupted_stag_v2.glb", "longest": 4.0, "gait": "diag",
		"amp": 0.5, "freq": 1.7, "bob": 0.02,
	},
	# --- Totenacker (Dateien kommen aus dem Asset Desk; fehlt eine, nimmt main.gd den Platzhalter "alt")
	"ghoul": {"file": "res://models/creatures/grave_ghoul.glb", "longest": 1.3, "gait": "biped", "amp": 0.6, "freq": 2.5, "bob": 0.04, "lean": 0.25, "arm_amp": 0.9},
	"skeleton": {"file": "res://models/creatures/bone_soldier.glb", "longest": 1.6, "gait": "biped", "amp": 0.5, "freq": 2.1, "bob": 0.03, "arm_amp": 0.4, "sway": 0.05},
	"hound": {"file": "res://models/creatures/corpse_hound.glb", "longest": 1.2, "gait": "diag", "amp": 0.75, "freq": 2.5, "bob": 0.03},
	"flesh": {"file": "res://models/creatures/stitched_brute.glb", "longest": 2.0, "gait": "biped", "amp": 0.3, "freq": 1.6, "bob": 0.04, "arm_amp": 0.4, "sway": 0.08},
	"witch": {"file": "res://models/creatures/bone_witch.glb", "longest": 1.5, "gait": "biped", "amp": 0.45, "freq": 2.0, "bob": 0.03, "arm_amp": 0.35, "sway": 0.05},
	"priest": {"file": "res://models/creatures/plague_priest.glb", "longest": 1.4, "gait": "biped", "amp": 0.5, "freq": 2.2, "bob": 0.04, "arm_amp": 0.5, "sway": 0.06},
	"horror": {"file": "res://models/creatures/bone_abomination.glb", "longest": 2.6, "gait": "biped", "amp": 0.3, "freq": 1.8, "bob": 0.04, "arm_amp": 0.5, "sway": 0.08},
	"warden": {"file": "res://models/creatures/grave_warden.glb", "longest": 4.0, "gait": "biped", "amp": 0.35, "freq": 1.5, "bob": 0.03, "arm_amp": 0.3, "sway": 0.05},
}

static var types := {}   # Typ -> Dictionary (Cache)

var sk: Skeleton3D
var t: Dictionary
var phase := 0.0

# ---------- Typ-Vorbereitung ----------
# Gliedmaßen-Ketten aus einer Blattmenge: Blätter eines Endes (Zehen, Finger) = eine Gruppe, Kette vom tiefsten/äußersten Blatt
# aufwärts, bis der Elternknoten mehrere Gruppen trägt (= Abzweig vom Körper).
static func _limb_chains(s: Skeleton3D, leaves: Array, thr: float, pos: Array) -> Array:
	var n := s.get_bone_count()
	var kids := []
	for i in n:
		kids.append([])
	for i in n:
		var p := s.get_bone_parent(i)
		if p >= 0:
			kids[p].append(i)
	var group_of := {}
	var reps: Array = []
	for lf in leaves:
		var gid := -1
		for g in reps.size():
			if (pos[reps[g]] as Vector3).distance_to(pos[lf]) < thr:
				gid = g
				break
		if gid < 0:
			reps.append(lf)
			gid = reps.size() - 1
		group_of[lf] = gid
	var memo := {}
	var sub := func(self_fn: Callable, b: int) -> Array:
		if memo.has(b):
			return memo[b]
		var r := []
		if group_of.has(b):
			r.append(group_of[b])
		for c in kids[b]:
			for g in self_fn.call(self_fn, c):
				if not r.has(g):
					r.append(g)
		memo[b] = r
		return r
	var chains := []
	for g in reps.size():
		var cur: int = reps[g]
		while true:
			var p := s.get_bone_parent(cur)
			if p < 0 or (sub.call(sub, p) as Array).size() > 1:
				break
			cur = p
		var chain := []
		var b: int = reps[g]
		while b != s.get_bone_parent(cur):
			chain.push_front(b)
			b = s.get_bone_parent(b)
		chains.append(chain)
	return chains

static func _foot_groups(s: Skeleton3D, frac: float) -> Dictionary:
	var n := s.get_bone_count()
	var pos := []
	var has_kid := []
	for i in n:
		pos.append(s.get_bone_global_rest(i).origin)
		has_kid.append(false)
	for i in n:
		var p := s.get_bone_parent(i)
		if p >= 0:
			has_kid[p] = true
	var ymin := 1e9
	var ymax := -1e9
	for i in n:
		ymin = minf(ymin, pos[i].y)
		ymax = maxf(ymax, pos[i].y)
	var thr := ymin + frac * (ymax - ymin)
	var leaves := []
	for i in n:
		if not has_kid[i] and pos[i].y < thr:
			leaves.append(i)
	# tiefstes Blatt zuerst, damit die Kette am Fuß endet
	leaves.sort_custom(func(a, b): return pos[a].y < pos[b].y)
	return {"chains": _limb_chains(s, leaves, 0.07, pos)}

# Automatische Aufteilung: Vorwärtsrichtung, Wirbelsäule, Kopf, Schwanz, Arme (Zweibeiner) aus der Skelettgeometrie.
static func _auto_layout(s: Skeleton3D, cfg: Dictionary, leg_chains: Array) -> Dictionary:
	var n := s.get_bone_count()
	var pos := []
	var kids := []
	var has_kid := []
	for i in n:
		pos.append(s.get_bone_global_rest(i).origin)
		kids.append([])
	for i in n:
		var p := s.get_bone_parent(i)
		if p >= 0:
			kids[p].append(i)
	var root: int = cfg.get("root", -1)
	if root < 0:
		for i in n:
			if s.get_bone_parent(i) < 0:
				root = i
				break
	# Beinknochen + Zehen ausschließen
	var in_leg := {}
	var mark := func(self_fn: Callable, b: int) -> void:
		in_leg[b] = true
		for c in kids[b]:
			self_fn.call(self_fn, c)
	for c in leg_chains:
		mark.call(mark, c[0])
	var rest := []
	for i in n:
		if not in_leg.has(i) and i != root:
			rest.append(i)
	var f := Vector3(0, 0, 1)
	var gait: String = cfg["gait"]
	if cfg.has("fwd"):
		f = cfg["fwd"]
	elif cfg.has("fwd_bones"):
		f = pos[cfg["fwd_bones"][1]] - pos[cfg["fwd_bones"][0]]
	elif gait == "biped" and leg_chains.size() >= 2:
		# Seitenachse = Linie zwischen den Hüften (waagerecht), Vorne = senkrecht dazu, Vorzeichen: Knie zeigen nach vorn
		var hip_line: Vector3 = (pos[leg_chains[0][0]] as Vector3) - (pos[leg_chains[1][0]] as Vector3)
		hip_line.y = 0.0
		var fw := Vector3.UP.cross(hip_line.normalized())
		var knee := Vector3.ZERO
		var toe := Vector3.ZERO
		for c in leg_chains:
			if c.size() >= 3:
				var m: int = c[c.size() / 2]
				var mid: Vector3 = ((pos[c[0]] as Vector3) + (pos[c[c.size() - 1]] as Vector3)) * 0.5
				knee += (pos[m] as Vector3) - mid
			if c.size() >= 2:   # Zehen zeigen nach vorn: letzter Knochen gegenüber dem vorletzten (zuverlässiger als das Knie)
				toe += (pos[c[c.size() - 1]] as Vector3) - (pos[c[c.size() - 2]] as Vector3)
		toe.y = 0.0
		knee.y = 0.0
		var vote := toe if toe.length() > 0.03 else knee
		f = fw if (vote.length() < 1e-4 or fw.dot(vote) >= 0.0) else -fw
	else:
		# Hauptachse (PCA) der übrigen Knochen, Kopf-Seite = Seite mit mehr Knochen (Ohren, Kiefer, Geweih)
		var mean := Vector3.ZERO
		for b in rest:
			mean += pos[b]
		mean /= maxf(1.0, rest.size())
		var cxx := 0.0
		var czz := 0.0
		var cxz := 0.0
		for b in rest:
			var d: Vector3 = (pos[b] as Vector3) - mean
			cxx += d.x * d.x
			czz += d.z * d.z
			cxz += d.x * d.z
		var th := 0.5 * atan2(2.0 * cxz, cxx - czz)
		var ax := Vector3(cos(th), 0, sin(th))
		var pmax := -1e9
		var pmin := 1e9
		for b in rest:
			var pr := ((pos[b] as Vector3) - mean).dot(ax)
			pmax = maxf(pmax, pr)
			pmin = minf(pmin, pr)
		var hc := 0
		var tc := 0
		for b in rest:
			var pr := ((pos[b] as Vector3) - mean).dot(ax)
			if pr > 0.5 * pmax:
				hc += 1
			if pr < 0.5 * pmin:
				tc += 1
		f = ax if hc >= tc else -ax    # Rückfall: Kopf-Seite = mehr Knochen
		var toe_q := Vector3.ZERO      # besser: Pfoten zeigen nach vorn (Mehrheit der Beine)
		for c in leg_chains:
			if c.size() >= 2:
				toe_q += (pos[c[c.size() - 1]] as Vector3) - (pos[c[c.size() - 2]] as Vector3)
		toe_q.y = 0.0
		if absf(toe_q.dot(ax)) > 0.04:
			f = ax if toe_q.dot(ax) > 0.0 else -ax
	f.y = 0.0
	f = f.normalized()
	var side := Vector3.UP.cross(f).normalized()
	var path_to := func(b: int) -> Array:
		var r := []
		var c := b
		while c >= 0:
			r.push_front(c)
			c = s.get_bone_parent(c)
		return r
	var lay := {"root": root, "f": f, "spine": [], "head": [], "tail": [], "arms": []}
	# Kopf-Ende: vorderster (Vierbeiner) bzw. höchster Knochen (Zweibeiner)
	var head_end := -1
	var best := -1e9
	for b in rest:
		var sc: float = (pos[b] as Vector3).y if gait == "biped" else (pos[b] as Vector3).dot(f)
		if sc > best:
			best = sc
			head_end = b
	if head_end >= 0:
		var hp: Array = path_to.call(head_end)
		hp = hp.filter(func(x): return x != root)
		var nh := 2 if gait == "biped" else 3
		lay["head"] = hp.slice(maxi(0, hp.size() - nh))
		lay["spine"] = hp.slice(maxi(0, hp.size() - nh - 4), maxi(0, hp.size() - nh))
	if gait != "biped":
		var tail_end := -1
		best = 1e9
		for b in rest:
			var sc2: float = (pos[b] as Vector3).dot(f)
			if sc2 < best and not (lay["head"] as Array).has(b):
				best = sc2
				tail_end = b
		if tail_end >= 0:
			var tp: Array = path_to.call(tail_end)
			tp = tp.filter(func(x): return x != root)
			lay["tail"] = tp.slice(maxi(0, tp.size() - 4))
	else:
		# Arme: seitlich abstehende Blätter (ohne Kopf), Kette zum Abzweig, Schulter/Ellbogen nach Längenanteil
		var skip := {}
		if head_end >= 0:
			skip[head_end] = true     # nur das Kopf-Ende selbst, Arme zweigen oft an der Brust (Kopf-Kette) ab
		var arm_leaves := []
		for b in rest:
			if kids[b].is_empty() and not skip.has(b):
				var lower := head_end < 0 or (pos[b] as Vector3).distance_to(pos[head_end]) > 0.18   # Hörner/Haare am Kopf sind keine Arme
				if lower and absf(((pos[b] as Vector3) - (pos[root] as Vector3)).dot(side)) > 0.15:
					arm_leaves.append(b)
		arm_leaves.sort_custom(func(a, b): return absf(((pos[a] as Vector3) - (pos[root] as Vector3)).dot(side)) > absf(((pos[b] as Vector3) - (pos[root] as Vector3)).dot(side)))
		var by_side := {}
		for b2 in arm_leaves:
			var sd0 := signf(((pos[b2] as Vector3) - (pos[root] as Vector3)).dot(side))
			if not by_side.has(sd0):
				by_side[sd0] = []
			by_side[sd0].append(b2)
		var picked := {}   # je Seite: Kette vom Abzweig zum äußersten Blatt (Hand/Finger)
		for sd in by_side:
			var far: int = by_side[sd][0]
			var others := []
			for sd2 in by_side:
				if sd2 != sd:
					others.append_array(by_side[sd2])
			var cur: int = far
			while true:
				var p := s.get_bone_parent(cur)
				if p < 0 or p == root:
					break
				var hit := false
				for ob in others:
					if (path_to.call(ob) as Array).has(p):
						hit = true
						break
				if hit:
					break
				cur = p
			var ch: Array = path_to.call(far)
			picked[sd] = ch.slice(ch.find(cur))
		for sd in picked:
			var c: Array = picked[sd]
			var total := 0.0
			for i in range(1, c.size()):
				total += (pos[c[i]] as Vector3).distance_to(pos[c[i - 1]])
			var acc2 := 0.0
			var sh: int = c[0]
			var el: int = c[c.size() - 1]
			var got_sh := false
			for i in range(1, c.size()):
				acc2 += (pos[c[i]] as Vector3).distance_to(pos[c[i - 1]])
				if not got_sh and acc2 >= 0.2 * total:
					sh = c[i]
					got_sh = true
				if acc2 >= 0.55 * total:
					el = c[i]
					break
			lay["arms"].append([sh, el])
	return lay

static func get_type(type: String, cfg_in: Dictionary = {}) -> Dictionary:
	if types.has(type):
		return types[type]
	var cfg: Dictionary = cfg_in if not cfg_in.is_empty() else CFG[type]
	var d := {"ok": false}
	types[type] = d
	if not ResourceLoader.exists(cfg["file"]):
		return d
	var scene: PackedScene = load(cfg["file"])
	var tmp: Node3D = scene.instantiate()
	var sks := tmp.find_children("*", "Skeleton3D", true, false)
	var mis := tmp.find_children("*", "MeshInstance3D", true, false)
	if sks.is_empty() or mis.is_empty():
		tmp.free()
		return d
	var s: Skeleton3D = sks[0]
	var aabb := (mis[0] as MeshInstance3D).get_aabb()
	var ext := maxf(aabb.size.x, maxf(aabb.size.y, aabb.size.z))
	var sc: float = cfg["longest"] / ext
	var chains: Array = _foot_groups(s, cfg.get("foot_frac", 0.22))["chains"]
	var auto := _auto_layout(s, cfg, chains)
	var f: Vector3 = auto["f"]
	var side := Vector3.UP.cross(f).normalized()
	var lay := {}
	for k in ["spine", "head", "tail", "arms"]:
		lay[k] = cfg[k] if cfg.has(k) else auto[k]
	var centre := Vector3.ZERO
	for c in chains:
		centre += s.get_bone_global_rest(c[0]).origin
	centre /= maxf(1.0, chains.size())
	var legs := []
	for c in chains:
		var rel: Vector3 = s.get_bone_global_rest(c[0]).origin - centre
		legs.append({"bones": c.slice(0, 5), "front": signf(rel.dot(f)), "side": signf(rel.dot(side))})
	var bones := {}
	for i in s.get_bone_count():
		var rq := s.get_bone_rest(i).basis.orthonormalized().get_rotation_quaternion()
		var gq := s.get_bone_global_rest(i).basis.orthonormalized().get_rotation_quaternion()
		bones[i] = [rq, gq, gq.inverse()]
	var root: int = auto["root"]
	# Schulter nie im Rumpf: erster Knochen hinter der Wirbelsäule (sonst kippt beim Arm-Absenken der Oberkörper mit)
	var trunk: Array = (lay["spine"] as Array) + (lay["head"] as Array) + [auto["root"]]
	for a in lay["arms"]:
		var chain := []
		var b: int = a[1]
		while b >= 0 and not trunk.has(b):
			chain.push_front(b)
			b = s.get_bone_parent(b)
		if trunk.has(a[0]) and not chain.is_empty():
			a[0] = chain[0] if chain.size() > 1 or chain[0] != a[1] else a[1]
	var arm_sides := []
	var arm_drop := []    # [Achse, Winkel]: hebt die T-Pose auf (Arm hängt danach ~65° unter der Waagerechten)
	var hang: float = deg_to_rad(float(cfg.get("arm_hang", 65.0)))
	for a in lay["arms"]:
		arm_sides.append(signf((s.get_bone_global_rest(a[0]).origin - s.get_bone_global_rest(root).origin).dot(side)))
		var dir: Vector3 = s.get_bone_global_rest(a[1]).origin - s.get_bone_global_rest(a[0]).origin
		if dir.length() < 0.0001:
			arm_drop.append([Vector3.FORWARD, 0.0])
			continue
		dir = dir.normalized()
		var below := asin(clampf(-dir.y, -1.0, 1.0))        # Winkel unter der Waagerechten (Rest-Pose)
		var hz := Vector3(dir.x, 0.0, dir.z)
		var axis := hz.cross(Vector3.DOWN).normalized() if hz.length() > 0.01 else Vector3.FORWARD
		arm_drop.append([axis, clampf(hang - below, 0.0, 1.5)])
	d = {"ok": true, "scene": scene, "scale": sc, "yaw": -atan2(f.x, f.z), "y_off": -aabb.position.y * sc,
		"f": f, "s": side, "bones": bones, "legs": legs, "arm_sides": arm_sides, "arm_drop": arm_drop, "cfg": cfg, "lay": lay, "root": root,
		"root_origin": s.get_bone_rest(root).origin}
	types[type] = d
	tmp.free()
	return d

# Fertiges Modell (Pivot, +Z = vorn, Füße auf y=0, echte Größe) oder null
static func make_model(type: String) -> Node3D:
	var d := get_type(type)
	if not d["ok"]:
		return null
	var body: Node3D = (d["scene"] as PackedScene).instantiate()
	body.rotation.y = d["yaw"]
	body.scale = Vector3.ONE * d["scale"]
	body.position = Vector3(0, d["y_off"], 0)
	var pivot := Node3D.new()
	pivot.add_child(body)
	pivot.set_meta("rig", RigAnim.new(type, body))
	return pivot

func _init(type: String, body: Node3D) -> void:
	t = get_type(type)
	var sks := body.find_children("*", "Skeleton3D", true, false)
	sk = sks[0] if not sks.is_empty() else null
	phase = randf() * TAU

func _pose(i: int, r: Quaternion) -> void:
	var b: Array = t["bones"][i]
	sk.set_bone_pose_rotation(i, b[0] * (b[2] * r * b[1]))

func _chain(bones: Array, axis: Vector3, angle: float, falloff: float = 1.0) -> void:
	# Winkel auf mehrere Knochen einer Kette verteilen (z. B. Wirbelsäule/Kopf)
	var a := angle
	for b in bones:
		_pose(b, Quaternion(axis, a))
		a *= falloff

# Positiver Winkel um s = Bein nach hinten bzw. Nase nach unten, negativ = vor/oben
func update(delta: float, speed: float) -> void:
	if sk == null:
		return
	var cfg: Dictionary = t["cfg"]
	var gait: String = cfg["gait"]
	phase += delta * speed * cfg["freq"] * 1.6
	var p := phase
	var f: Vector3 = t["f"]
	var s: Vector3 = t["s"]
	var amp: float = cfg["amp"]
	var lay: Dictionary = t["lay"]
	var root: int = t["root"]
	var bob: float = cfg["bob"]
	var sinp := sin(p)

	for l in t["legs"]:
		var b: Array = l["bones"]
		var ph := p
		var a := amp
		match gait:
			"diag":   # Diagonalgang: vorne links + hinten rechts gleichzeitig
				ph += (0.0 if l["front"] > 0.0 else PI) + (0.0 if l["side"] > 0.0 else PI)
			"biped":
				ph += 0.0 if l["side"] > 0.0 else PI
			"hop":    # Hüpfer: alle Hinterbeine zusammen, Vorderbeine leicht versetzt
				ph += 0.0 if l["front"] < 0.0 else 0.9
				a = amp * (1.0 if l["front"] < 0.0 else 0.6)
		var flex_f := maxf(0.0, -cos(ph))
		if gait == "hop":
			flex_f = maxf(0.0, sin(ph))
			_pose(b[0], Quaternion(s, a * (cos(ph) if l["front"] < 0.0 else -cos(ph))))
		else:
			_pose(b[0], Quaternion(s, a * sin(ph)))
		if b.size() > 1:
			_pose(b[1], Quaternion(s, 0.55 * flex_f))
		if b.size() > 2:
			_pose(b[2], Quaternion(s, -0.45 * flex_f))
		if b.size() > 3:
			_pose(b[3], Quaternion(s, 0.25 * flex_f))

	var vert := bob * absf(sinp)
	match gait:
		"hop":
			vert = bob * maxf(0.0, sinp)
			_pose(root, Quaternion(s, -0.25 * sinp))
			_chain(lay["spine"], s, 0.05 * sinp)
			_chain(lay["head"], s, 0.12 * sinp)
		"diag":
			_pose(root, Quaternion(f, 0.05 * sinp) * Quaternion(s, 0.03 * sin(2.0 * p)))
			_chain(lay["spine"], Vector3.UP, 0.05 * sinp)
			for k in lay["head"].size():
				_pose(lay["head"][k], Quaternion(s, 0.10 * sin(2.0 * p + 0.5 * k)))
			var tail: Array = lay["tail"]
			for k in tail.size():
				_pose(tail[k], Quaternion(Vector3.UP, 0.35 * sin(p * 0.5 + 0.6 * k)))
		"biped":
			var sway: float = cfg.get("sway", 0.03)
			var lean: float = cfg.get("lean", 0.0)
			_pose(root, Quaternion(f, sway * sinp))
			_chain(lay["spine"], Vector3.UP, 0.12 * sinp)
			if lean != 0.0:
				_chain(lay["spine"], s, lean * 0.4)
			for k in lay["head"].size():
				_pose(lay["head"][k], Quaternion(Vector3.UP, -0.12 * sinp))
			var arms: Array = lay["arms"]
			var aa: float = cfg.get("arm_amp", 0.5)
			for i in arms.size():
				var ph2 := p + (PI if t["arm_sides"][i] > 0.0 else 0.0)
				var dr: Array = t["arm_drop"][i]
				# erst absenken (T-Pose -> hängend, leicht atmend), dann Laufschwung um die Seitenachse
				var drop_q := Quaternion(dr[0], float(dr[1]) - 0.06 * absf(sin(p)))
				_pose(arms[i][0], Quaternion(s, -aa * sin(ph2)) * drop_q)
				if arms[i].size() > 1:
					_pose(arms[i][1], Quaternion(s, -0.3 - 0.3 * maxf(0.0, -sin(ph2))))
	sk.set_bone_pose_position(root, t["root_origin"] + Vector3(0, vert, 0))
