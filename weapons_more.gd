class_name WeaponsMore
extends RefCounted
## Fünf Waffen mit eigener Mechanik:
##   fireflies – Glühkäferschwarm: zielsuchende Geschosse (lenken nach)
##   bramble   – Dornenpfad: hinterlässt beim Laufen Dornenfelder (Fläche über Zeit + Verlangsamung)
##   beam      – Sternenstrahl: kurzer Strahl, trifft alles in einer Linie, schwenkt mit
##   frost     – Raureif-Nova: Ring um die Druidin, stößt zurück und friert kurz ein
##   bark      – Rindenschild: fängt Treffer ab; zerbricht er, gibt es eine Splitter-Explosion
## `g` ist main.gd.

var g
var cd := {"fireflies": 0.0, "beam": 0.0, "frost": 0.0}
var flies: Array = []      # {node, vel, t, dmg, target}
var patches: Array = []    # {node, mat, pos, t, dur, radius, dps, acc}
var bramble_acc := 0.0
var last_pos := Vector3.ZERO
var beams: Array = []      # {node, mat, t, dur, dir, len, width, dmg, hit}
var novas: Array = []      # {node, mat, t, dur, radius, st, hit}
# Rindenschild
var shield_charges := 0
var shield_max := 0
var shield_t := 0.0
var shield_node: Node3D
var shield_mat: StandardMaterial3D
static var beam_tex: GradientTexture2D

static func _beam_texture() -> GradientTexture2D:
	if beam_tex == null:   # quer weicher Verlauf, längs an den Enden ausgeblendet
		beam_tex = GradientTexture2D.new()
		var gr := Gradient.new()
		gr.offsets = PackedFloat32Array([0.0, 0.35, 0.5, 0.65, 1.0])
		gr.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 0.55), Color(1, 1, 1, 1), Color(1, 1, 1, 0.55), Color(1, 1, 1, 0)])
		beam_tex.gradient = gr
		beam_tex.fill_from = Vector2(0, 0.5)
		beam_tex.fill_to = Vector2(1, 0.5)
		beam_tex.width = 64
		beam_tex.height = 8
	return beam_tex

func update(delta: float) -> void:
	var w: Dictionary = g.weapons
	for k in cd:
		cd[k] -= delta
	if w.has("fireflies"):
		_flies_fire(w["fireflies"])
	_flies_update(delta)
	if w.has("bramble"):
		_bramble_drop(delta, w["bramble"])
	_patches_update(delta)
	if w.has("beam"):
		_beam_fire(w["beam"])
	_beams_update(delta)
	if w.has("frost"):
		_frost_fire(w["frost"])
	_novas_update(delta)
	_shield_update(delta, w.get("bark", 0))
	last_pos = g.player.position

func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

func _additive(col: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_texture = g.vfx.soft_tex
	m.albedo_color = col
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m

# ---------- Glühkäferschwarm (zielsuchend) ----------
func _flies_fire(lvl: int) -> void:
	if cd["fireflies"] > 0.0 or g.enemies.is_empty():
		return
	var st := Defs.weapon_stats("fireflies", lvl)
	var first: Dictionary = g._nearest(g.player.position, 13.0)
	if first.is_empty():
		return
	cd["fireflies"] = st["cd"] * g.cd_mult
	g.play_cast("throw", 0.3)
	for k in int(st["count"]) + g.proj_bonus:
		var n := Node3D.new()
		n.position = g.player.position + Vector3(0, 1.3, 0)
		g.add_child(n)
		g.vfx.glow_sprite(n, Color(1.0, 0.85, 0.35, 0.95), 0.55)
		g.vfx.attach_trail(n, Color(1.0, 0.8, 0.3), 0.06, 16, 0.35)
		var a := randf() * TAU   # fliegen erst seitlich auseinander, dann aufs Ziel
		var vel := Vector3(cos(a), 0.6, sin(a)) * 5.0
		flies.append({"node": n, "vel": vel, "t": 0.0, "dmg": st["dmg"], "speed": st["speed"], "target": {}})

func _flies_update(delta: float) -> void:
	for i in range(flies.size() - 1, -1, -1):
		var f: Dictionary = flies[i]
		var n: Node3D = f["node"]
		f["t"] += delta
		var tgt: Dictionary = f["target"]
		if tgt.is_empty() or not g.enemies.has(tgt):
			tgt = g._nearest(n.position, 14.0)
			f["target"] = tgt
		var vel: Vector3 = f["vel"]
		if not tgt.is_empty():
			var want: Vector3 = ((tgt["node"] as Node3D).position + Vector3(0, 0.8, 0) - n.position).normalized() * float(f["speed"])
			vel = vel.lerp(want, 1.0 - exp(-4.5 * delta))     # Nachlenken = weiche Kurven
		vel.y += sin(f["t"] * 14.0 + i) * 0.3                  # Taumeln wie ein Käfer
		f["vel"] = vel
		n.position += vel * delta
		var hit := false
		for e in g.enemies:
			if ((e["node"] as Node3D).position + Vector3(0, 0.8, 0)).distance_to(n.position) < e["r"] + 0.35:
				g._damage_enemy(e, f["dmg"])
				g.vfx.burst("gem_y", n.position)
				hit = true
				break
		if hit or f["t"] > 3.5:
			n.queue_free()
			flies.remove_at(i)

# ---------- Dornenpfad (Spur) ----------
func _bramble_drop(delta: float, lvl: int) -> void:
	var st := Defs.weapon_stats("bramble", lvl)
	bramble_acc += _flat(g.player.position, last_pos)
	if bramble_acc < float(st["every"]):
		return
	bramble_acc = 0.0
	var pos: Vector3 = g.player.position
	pos.y = 0.0
	var radius: float = st["radius"] * g.area_mult
	var root := Node3D.new()
	root.position = pos
	g.add_child(root)
	var disc := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(radius * 2.1, radius * 2.1)
	disc.mesh = pm
	var mat := _additive(Color(0.4, 0.6, 0.15, 0.0))
	disc.material_override = mat
	disc.position.y = 0.06
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(disc)
	var thorn_mat := StandardMaterial3D.new()
	thorn_mat.albedo_color = Color(0.3, 0.42, 0.16)
	thorn_mat.roughness = 0.8
	for k in 6:   # kleine Dornen, die aus dem Boden wachsen
		var sp := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.0
		cm.bottom_radius = 0.07
		cm.height = 0.55
		sp.mesh = cm
		sp.material_override = thorn_mat
		var a := TAU * k / 6.0 + randf() * 0.6
		var rr := radius * randf_range(0.2, 0.75)
		sp.position = Vector3(cos(a) * rr, -0.3, sin(a) * rr)
		sp.rotation = Vector3(randf_range(-0.35, 0.35), 0, randf_range(-0.35, 0.35))
		root.add_child(sp)
	patches.append({"node": root, "mat": mat, "t": 0.0, "dur": st["dur"], "radius": radius, "dps": st["dps"], "acc": 0.0})

func _patches_update(delta: float) -> void:
	for i in range(patches.size() - 1, -1, -1):
		var p: Dictionary = patches[i]
		p["t"] += delta
		var k: float = p["t"] / p["dur"]
		var grow: float = clampf(p["t"] / 0.25, 0.0, 1.0) * clampf((1.0 - k) / 0.15, 0.0, 1.0)
		var root: Node3D = p["node"]
		for c in root.get_children():
			if c is MeshInstance3D and (c as MeshInstance3D).mesh is CylinderMesh:
				(c as Node3D).position.y = -0.3 + 0.32 * grow
		(p["mat"] as StandardMaterial3D).albedo_color.a = 0.12 * grow
		p["acc"] += delta
		if p["acc"] >= 0.3:
			p["acc"] = 0.0
			for e in g.enemies.duplicate():
				if _flat((e["node"] as Node3D).position, root.position) < float(p["radius"]) + e["r"] * 0.5:
					e["slow"] = maxf(float(e["slow"]), 0.3)
					e["slow_until"] = g.time + 0.4
					g._damage_enemy(e, float(p["dps"]) * 0.3, false)
		if k >= 1.0:
			root.queue_free()
			patches.remove_at(i)

# ---------- Sternenstrahl (Linie) ----------
func _beam_fire(lvl: int) -> void:
	if cd["beam"] > 0.0:
		return
	var st := Defs.weapon_stats("beam", lvl)
	var t: Dictionary = g._nearest(g.player.position, float(st["len"]))
	if t.is_empty():
		return
	cd["beam"] = st["cd"] * g.cd_mult
	var dir: Vector3 = ((t["node"] as Node3D).position - g.player.position) * Vector3(1, 0, 1)
	dir = dir.normalized()
	g.aim_dir = dir
	g.aim_t = 0.8
	g.play_cast("point", 0.6)
	var n_beams: int = int(st["count"]) + g.proj_bonus
	for bi in n_beams:
		var bdir := dir.rotated(Vector3.UP, (bi - (n_beams - 1) * 0.5) * 0.55)   # mehrere Strahlen fächern auf
		_spawn_beam(bdir, st)

func _spawn_beam(dir: Vector3, st: Dictionary) -> void:
	var len_: float = st["len"] * g.area_mult
	var width: float = st["width"] * g.area_mult
	var node := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(width * 2.2, len_)
	q.orientation = PlaneMesh.FACE_Y
	node.mesh = q
	var mat := _additive(Color(0.85, 0.75, 1.0, 0.0))
	mat.albedo_texture = _beam_texture()
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var core := MeshInstance3D.new()   # heller Kern
	var q2 := QuadMesh.new()
	q2.size = Vector2(width * 0.6, len_)
	q2.orientation = PlaneMesh.FACE_Y
	core.mesh = q2
	var cmat := _additive(Color(1.0, 1.0, 1.0, 0.0))
	cmat.albedo_texture = _beam_texture()
	core.material_override = cmat
	core.position.y = 0.01
	node.add_child(core)
	g.add_child(node)
	beams.append({"node": node, "mat": mat, "cmat": cmat, "t": 0.0, "dur": 0.55, "dir": dir, "len": len_, "width": width,
		"dmg": st["dmg"], "hit": {}, "sweep": randf_range(-0.5, 0.5)})
	g.vfx.flash(g.player.position + Vector3(0, 1.2, 0) + dir * 0.6, Color(0.85, 0.75, 1.0), 4.0, 7.0, 0.3)

func _beams_update(delta: float) -> void:
	for i in range(beams.size() - 1, -1, -1):
		var b: Dictionary = beams[i]
		b["t"] += delta
		var k: float = b["t"] / b["dur"]
		var dir: Vector3 = (b["dir"] as Vector3).rotated(Vector3.UP, float(b["sweep"]) * (k - 0.5))   # Strahl schwenkt leicht
		var origin: Vector3 = g.player.position + Vector3(0, 1.0, 0)
		var node: MeshInstance3D = b["node"]
		node.position = origin + dir * float(b["len"]) * 0.5
		node.basis = Basis(Vector3.UP, atan2(dir.x, dir.z))
		var a := sin(clampf(k, 0.0, 1.0) * PI)
		(b["mat"] as StandardMaterial3D).albedo_color.a = 0.45 * a
		(b["cmat"] as StandardMaterial3D).albedo_color.a = 0.9 * a
		node.scale = Vector3(0.6 + 0.4 * a, 1, 1)
		for e in g.enemies.duplicate():
			var rel: Vector3 = (e["node"] as Node3D).position - g.player.position
			rel.y = 0.0
			var along := rel.dot(dir)
			if along < 0.0 or along > float(b["len"]):
				continue
			if (rel - dir * along).length() < float(b["width"]) + e["r"] * 0.5:
				var last: float = b["hit"].get(e["id"], -9.0)
				if g.time - last > 0.25:
					b["hit"][e["id"]] = g.time
					g._damage_enemy(e, b["dmg"])
		if k >= 1.0:
			node.queue_free()
			beams.remove_at(i)

# ---------- Raureif-Nova (Rückstoß + Einfrieren) ----------
func _frost_fire(lvl: int) -> void:
	if cd["frost"] > 0.0:
		return
	var st := Defs.weapon_stats("frost", lvl)
	var radius: float = st["radius"] * g.area_mult
	var any := false
	for e in g.enemies:
		if _flat((e["node"] as Node3D).position, g.player.position) < radius + 1.0:
			any = true
			break
	if not any:
		return
	cd["frost"] = st["cd"] * g.cd_mult
	g.play_cast("slam", 0.5)
	var node := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(2, 2)
	node.mesh = pm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture = g.vfx.ring_tex
	mat.albedo_color = Color(0.6, 0.9, 1.0, 0.5)
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.position = g.player.position + Vector3(0, 0.1, 0)
	g.add_child(node)
	novas.append({"node": node, "mat": mat, "t": 0.0, "dur": 0.45, "radius": radius, "st": st, "hit": {}, "origin": g.player.position})
	g.vfx.flash(g.player.position + Vector3(0, 1.0, 0), Color(0.6, 0.9, 1.0), 5.0, radius + 3.0, 0.35)
	g.vfx.add_shake(0.15)

func _novas_update(delta: float) -> void:
	for i in range(novas.size() - 1, -1, -1):
		var nv: Dictionary = novas[i]
		nv["t"] += delta
		var k: float = clampf(nv["t"] / nv["dur"], 0.0, 1.0)
		var r: float = float(nv["radius"]) * (1.0 - pow(1.0 - k, 2.0))
		var node: MeshInstance3D = nv["node"]
		node.scale = Vector3(r, 1, r)
		(nv["mat"] as StandardMaterial3D).albedo_color.a = 0.5 * (1.0 - k) * (1.0 - k)
		var st: Dictionary = nv["st"]
		var origin: Vector3 = nv["origin"]
		for e in g.enemies.duplicate():
			if nv["hit"].has(e["id"]):
				continue
			var en: Node3D = e["node"]
			if _flat(en.position, origin) < r + e["r"]:
				nv["hit"][e["id"]] = true
				var push: Vector3 = (en.position - origin) * Vector3(1, 0, 1)
				var kb: float = float(st["knock"]) * (0.35 if e["role"] == "boss" or e["role"] == "tank" else 1.0)
				en.position += push.normalized() * kb
				e["stun"] = maxf(float(e["stun"]), float(st["freeze"]) * (0.3 if e["role"] == "boss" else 1.0))
				g.vfx.burst("gem_b", en.position + Vector3(0, 0.6, 0))
				g._damage_enemy(e, st["dmg"], false)
		if k >= 1.0:
			node.queue_free()
			novas.remove_at(i)

# ---------- Rindenschild (Abwehr) ----------
func _shield_update(delta: float, lvl: int) -> void:
	if lvl <= 0:
		if shield_node != null:
			shield_node.queue_free()
			shield_node = null
		return
	var st := Defs.weapon_stats("bark", lvl)
	shield_max = st["charges"]
	if shield_node == null:
		shield_node = MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 1.0
		sm.height = 2.0
		(shield_node as MeshInstance3D).mesh = sm
		shield_mat = StandardMaterial3D.new()
		shield_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		shield_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		shield_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		shield_mat.albedo_color = Color(0.95, 0.7, 0.35, 0.0)
		shield_mat.rim_enabled = true
		shield_mat.cull_mode = BaseMaterial3D.CULL_BACK
		(shield_node as MeshInstance3D).material_override = shield_mat
		(shield_node as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		shield_node.position = Vector3(0, 0.9, 0)
		shield_node.scale = Vector3(0.9, 1.05, 0.9)
		g.player.add_child(shield_node)
		shield_charges = shield_max
	if shield_charges < shield_max:
		shield_t += delta
		if shield_t >= float(st["recharge"]):
			shield_t = 0.0
			shield_charges += 1
			g.vfx.ring(g.player.position, 0.2, 1.4, 0.35, Color(1.0, 0.75, 0.4, 0.8))
	var a := 0.0 if shield_charges <= 0 else 0.025 + 0.015 * shield_charges + 0.01 * sin(g.time * 4.0)
	shield_mat.albedo_color.a = a

## Von main._hurt aufgerufen: true = Treffer abgefangen
func absorb(amount: float) -> bool:
	if shield_node == null or shield_charges <= 0:
		return false
	shield_charges -= 1
	shield_t = 0.0
	var st := Defs.weapon_stats("bark", g.weapons.get("bark", 1))
	var pos: Vector3 = g.player.position
	g.vfx.burst("leaf", pos + Vector3(0, 1.0, 0))
	g.vfx.burst("hit", pos + Vector3(0, 1.0, 0))
	g.vfx.ring(pos, 0.4, float(st["burst_r"]) * g.area_mult, 0.4, Color(1.0, 0.7, 0.35, 0.9))
	g.vfx.add_shake(0.15)
	for e in g.enemies.duplicate():   # Splitter-Explosion
		if _flat((e["node"] as Node3D).position, pos) < float(st["burst_r"]) * g.area_mult + e["r"]:
			g._damage_enemy(e, st["burst"])
	return true
