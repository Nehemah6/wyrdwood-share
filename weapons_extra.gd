class_name WeaponsExtra
extends RefCounted
## Waffen jenseits der drei Basiswaffen: Wurzelschlag, Mondsichel, Funkenkette, Sporenwolke.
## `g` ist main.gd (Zugriff auf enemies, vfx, player, weapons, _damage_enemy ...).

var g
var cd := {"roots": 0.0, "scythe": 0.0, "chain": 0.0}
var roots_pending: Array = []   # {pos, t, dur, st, spikes, phase}
var scythes: Array = []         # {node, origin, dir, t, dur, range, dmg, hit}
var bolts: Array = []           # {node, t}
var aura: Node3D
var aura_mat: StandardMaterial3D
var aura_particles: GPUParticles3D
var aura_acc := 0.0
var aura_radius := 0.0

func update(delta: float) -> void:
	var w: Dictionary = g.weapons
	if w.has("roots"):
		_roots_fire(delta, w["roots"])
	_roots_update(delta)
	if w.has("scythe"):
		_scythe_fire(delta, w["scythe"])
	_scythes_update(delta)
	if w.has("chain"):
		_chain_fire(delta, w["chain"])
	_bolts_update(delta)
	_spores(delta, w.get("spores", 0))

# ---------- Wurzelschlag ----------
func _roots_fire(delta: float, lvl: int) -> void:
	cd["roots"] -= delta
	if cd["roots"] > 0.0:
		return
	var st := Defs.weapon_stats("roots", lvl)
	var cands: Array = []
	for e in g.enemies:
		if ((e["node"] as Node3D).position - g.player.position).length() < 11.0:
			cands.append(e)
	if cands.is_empty():
		return
	cands.shuffle()
	cd["roots"] = st["cd"] * g.cd_mult
	g.play_cast("slam", 0.6)
	for k in mini(int(st["count"]) + g.proj_bonus, cands.size()):
		var p: Vector3 = (cands[k]["node"] as Node3D).position
		p.y = 0.0
		roots_pending.append({"pos": p, "t": 0.0, "dur": 0.55, "st": st, "spikes": [], "phase": 0})
		g.vfx.ring(p, 0.2, st["radius"] * g.area_mult, 0.55, Color(0.75, 0.55, 0.3, 0.8))

func _roots_update(delta: float) -> void:
	for i in range(roots_pending.size() - 1, -1, -1):
		var r: Dictionary = roots_pending[i]
		r["t"] += delta
		if r["phase"] == 0 and r["t"] >= r["dur"]:
			r["phase"] = 1
			var st: Dictionary = r["st"]
			var rad: float = st["radius"] * g.area_mult
			for e in g.enemies.duplicate():
				if ((e["node"] as Node3D).position - r["pos"]).length() < rad + e["r"]:
					g._damage_enemy(e, st["dmg"])
					e["stun"] = maxf(e["stun"], st["stun"])
			g.vfx.burst("leaf", r["pos"] + Vector3(0, 0.4, 0))
			g.vfx.add_shake(0.12)
			var n := 7
			for k in n:
				var a := TAU * k / n
				var spike := MeshInstance3D.new()
				var cm := CylinderMesh.new()
				cm.top_radius = 0.0
				cm.bottom_radius = 0.14
				cm.height = 1.5
				spike.mesh = cm
				var m := StandardMaterial3D.new()
				m.albedo_color = Color(0.42, 0.3, 0.18)
				m.roughness = 0.9
				spike.material_override = m
				spike.position = r["pos"] + Vector3(cos(a), -0.75, sin(a)) * Vector3(rad * 0.55, 1.0, rad * 0.55) + Vector3(0, 0, 0)
				spike.rotation = Vector3(sin(a) * 0.25, 0, -cos(a) * 0.25)
				g.add_child(spike)
				(r["spikes"] as Array).append(spike)
		if r["phase"] == 1:
			var k: float = clampf((r["t"] - r["dur"]) / 0.7, 0.0, 1.0)
			var up := sin(k * PI) * 0.9
			for sp in r["spikes"]:
				(sp as Node3D).position.y = -0.75 + up
			if k >= 1.0:
				for sp in r["spikes"]:
					(sp as Node3D).queue_free()
				roots_pending.remove_at(i)

# ---------- Mondsichel ----------
func _scythe_fire(delta: float, lvl: int) -> void:
	cd["scythe"] -= delta
	if cd["scythe"] > 0.0:
		return
	var st := Defs.weapon_stats("scythe", lvl)
	var t: Dictionary = g._nearest(g.player.position, 12.0)
	if t.is_empty():
		return
	cd["scythe"] = st["cd"] * g.cd_mult
	var base: Vector3 = (t["node"] as Node3D).position - g.player.position
	base.y = 0.0
	base = base.normalized()
	var cnt: int = int(st["count"]) + g.proj_bonus
	g.aim_dir = base
	g.aim_t = 0.6
	g.play_cast("sweep", 0.45)
	for k in cnt:
		var d := base.rotated(Vector3.UP, (k - (cnt - 1) * 0.5) * 0.7)
		var n: Node3D = g._make_model("weapons/moon_scythe.glb", Color(0.7, 0.9, 1.0), 0.9)
		if g._scene_or_null(g.M + "weapons/moon_scythe.glb") == null:
			var mi := MeshInstance3D.new()
			var tm := TorusMesh.new()
			tm.inner_radius = 0.28
			tm.outer_radius = 0.42
			mi.mesh = tm
			mi.scale = Vector3(1, 0.15, 1)
			mi.material_override = g._glow_mat(Color(0.7, 0.9, 1.0))
			n.add_child(mi)
		n.position = g.player.position + Vector3(0, 1.1, 0)
		g.add_child(n)
		g.vfx.attach_trail(n, Color(0.7, 0.9, 1.0), 0.13, 22, 0.4)
		g.vfx.glow_sprite(n, Color(0.6, 0.85, 1.0, 0.45), 1.1)
		var rng_: float = st["range"] * g.area_mult
		scythes.append({"node": n, "origin": g.player.position + Vector3(0, 1.1, 0), "dir": d, "t": 0.0, "dur": rng_ / 7.5 + 0.8,
			"range": rng_, "dmg": st["dmg"], "hit": {}})

func _scythes_update(delta: float) -> void:
	for i in range(scythes.size() - 1, -1, -1):
		var s: Dictionary = scythes[i]
		s["t"] += delta
		var k: float = clampf(s["t"] / s["dur"], 0.0, 1.0)
		var n: Node3D = s["node"]
		var end: Vector3 = (s["origin"] as Vector3) + (s["dir"] as Vector3) * s["range"]
		var home: Vector3 = g.player.position + Vector3(0, 1.1, 0)
		var p: Vector3
		if k < 0.5:
			var u := k * 2.0
			p = g._fold_arena((s["origin"] as Vector3).lerp(end, 1.0 - pow(1.0 - u, 2.0)))   # prallt an Wänden ab
		else:
			var u2 := (k - 0.5) * 2.0
			p = (g._fold_arena(end) as Vector3).lerp(home, u2 * u2)
		n.position = p
		n.rotation.y += delta * 16.0
		for e in g.enemies.duplicate():
			var ep: Vector3 = (e["node"] as Node3D).position
			var flat := Vector2(ep.x - p.x, ep.z - p.z).length()
			if flat < 1.0 + e["r"]:
				var last: float = s["hit"].get(e["id"], -9.0)
				if g.time - last > 0.45:
					s["hit"][e["id"]] = g.time
					g._damage_enemy(e, s["dmg"])
		if k >= 1.0:
			n.queue_free()
			scythes.remove_at(i)

# ---------- Funkenkette ----------
func _chain_fire(delta: float, lvl: int) -> void:
	cd["chain"] -= delta
	if cd["chain"] > 0.0:
		return
	var st := Defs.weapon_stats("chain", lvl)
	var first: Dictionary = g._nearest(g.player.position, 11.0)
	if first.is_empty():
		return
	cd["chain"] = st["cd"] * g.cd_mult
	var used: Array = []
	var n_chains: int = int(st["chains"]) + g.proj_bonus
	for ci in n_chains:   # weitere Ketten starten beim nächsten noch nicht getroffenen Gegner
		if ci > 0:
			first = {}
			var bd0 := 11.0 * 11.0
			for e in g.enemies:
				if e in used:
					continue
				var d0: float = ((e["node"] as Node3D).position).distance_squared_to(g.player.position)
				if d0 < bd0:
					bd0 = d0
					first = e
			if first.is_empty():
				break
		used += _chain_one(first, st)

func _chain_one(first: Dictionary, st: Dictionary) -> Array:
	var visited: Array = [first]
	var pts: Array = [g.player.position + Vector3(0, 1.4, 0), (first["node"] as Node3D).position + Vector3(0, 0.9, 0)]
	var cur: Dictionary = first
	for j in int(st["jumps"]):
		var best: Dictionary = {}
		var bd: float = (st["range"] as float) * g.area_mult
		bd *= bd
		for e in g.enemies:
			if e in visited:
				continue
			var d := ((e["node"] as Node3D).position).distance_squared_to((cur["node"] as Node3D).position)
			if d < bd:
				bd = d
				best = e
		if best.is_empty():
			break
		visited.append(best)
		pts.append((best["node"] as Node3D).position + Vector3(0, 0.9, 0))
		cur = best
	g.aim_dir = (((first["node"] as Node3D).position - g.player.position) * Vector3(1, 0, 1)).normalized()
	g.aim_t = 0.5
	g.play_cast("point", 0.3)
	for e in visited:
		g._damage_enemy(e, st["dmg"])
		g.vfx.burst("gem", (e["node"] as Node3D).position + Vector3(0, 0.9, 0))
	_make_bolt(pts)
	g.vfx.flash(pts[1], Color(0.7, 0.85, 1.0), 3.0, 6.0, 0.2)
	g.vfx.add_shake(0.08)
	return visited

func _make_bolt(pts: Array) -> void:
	var node := MeshInstance3D.new()
	var im := ImmediateMesh.new()
	for pass_i in 3:   # drei leicht versetzte Linien = dickerer Blitz
		im.surface_begin(Mesh.PRIMITIVE_LINES)
		for i in range(pts.size() - 1):
			var a: Vector3 = pts[i]
			var b: Vector3 = pts[i + 1]
			var segs := 6
			var prev := a
			for s in range(1, segs + 1):
				var q := a.lerp(b, float(s) / segs)
				if s < segs:
					q += Vector3(randf_range(-0.25, 0.25), randf_range(-0.2, 0.2), randf_range(-0.25, 0.25))
				var off := Vector3(0.015, 0.015, 0.0) * pass_i
				im.surface_add_vertex(prev + off)
				im.surface_add_vertex(q + off)
				prev = q
		im.surface_end()
	node.mesh = im
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.75, 0.9, 1.0)
	m.emission_enabled = true
	m.emission = Color(0.6, 0.85, 1.0)
	m.emission_energy_multiplier = 4.0
	node.material_override = m
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	g.add_child(node)
	bolts.append({"node": node, "t": 0.0})

func _bolts_update(delta: float) -> void:
	for i in range(bolts.size() - 1, -1, -1):
		var b: Dictionary = bolts[i]
		b["t"] += delta
		if b["t"] >= 0.16:
			(b["node"] as Node3D).queue_free()
			bolts.remove_at(i)

# ---------- Sporenwolke ----------
func _spores(delta: float, lvl: int) -> void:
	if lvl <= 0:
		if aura != null:
			aura.queue_free()
			aura = null
		return
	var st := Defs.weapon_stats("spores", lvl)
	var radius: float = st["radius"] * g.area_mult
	if aura == null:
		aura = Node3D.new()
		g.player.add_child(aura)
		var disc := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(1, 1)
		disc.mesh = pm
		aura_mat = StandardMaterial3D.new()
		aura_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		aura_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		aura_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		aura_mat.albedo_texture = g.vfx.soft_tex
		aura_mat.albedo_color = Color(0.45, 0.9, 0.35, 0.22)
		aura_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		disc.material_override = aura_mat
		disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		disc.position.y = 0.08
		aura.add_child(disc)
		aura_particles = GPUParticles3D.new()
		aura_particles.amount = 60
		aura_particles.lifetime = 2.2
		aura_particles.local_coords = false
		aura_particles.visibility_aabb = AABB(Vector3(-14, -2, -14), Vector3(28, 8, 28))
		var pmat := ParticleProcessMaterial.new()
		pmat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		pmat.emission_sphere_radius = radius
		pmat.direction = Vector3(0, 1, 0)
		pmat.spread = 40.0
		pmat.initial_velocity_min = 0.2
		pmat.initial_velocity_max = 0.8
		pmat.gravity = Vector3(0, 0.1, 0)
		pmat.scale_min = 0.6
		pmat.scale_max = 1.6
		pmat.color_ramp = g.vfx._ramp([Color(0.55, 1.0, 0.4, 0.0), Color(0.6, 1.0, 0.45, 0.8), Color(0.4, 0.8, 0.3, 0.0)], [0.0, 0.35, 1.0])
		aura_particles.process_material = pmat
		aura_particles.draw_pass_1 = g.vfx._quad(0.22)
		aura_particles.position.y = 0.3
		aura.add_child(aura_particles)
		aura_radius = -1.0
	if absf(radius - aura_radius) > 0.01:
		aura_radius = radius
		(aura.get_child(0) as Node3D).scale = Vector3(radius * 2.1, 1.0, radius * 2.1)
		(aura_particles.process_material as ParticleProcessMaterial).emission_sphere_radius = radius
	aura_mat.albedo_color.a = 0.18 + 0.05 * sin(g.time * 3.0)
	aura_acc += delta
	if aura_acc >= 0.25:
		aura_acc = 0.0
		var dmg: float = st["dps"] * 0.25
		var slow: float = st["slow"] / 100.0
		for e in g.enemies.duplicate():
			if ((e["node"] as Node3D).position - g.player.position).length() < radius + e["r"]:
				e["slow"] = slow
				e["slow_until"] = g.time + 0.45
				g._damage_enemy(e, dmg, false)
