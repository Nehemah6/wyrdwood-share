class_name Vfx
extends Node3D
## Effekte: gepoolte Partikel-Bursts, Trails, Schockwellen, Licht-Blitze, Schaden-Zahlen, Kamerawackeln, Vignette.
## Alles prozedural (weiche Glow-Sprites aus GradientTexture2D), keine externen Texturen nötig.

var soft_tex: GradientTexture2D
var ring_tex: GradientTexture2D
var spark_tex: GradientTexture2D     # scharfer kleiner Punkt (Funken), im Gegensatz zum weichen Glow
var pools := {}          # Typ -> {nodes: Array, i: int}
var rings: Array = []    # {node, t, dur, r0, r1, col}
var ring_pool: Array = []
var lights: Array = []   # {node, t, dur, e0}
var texts: Array = []    # {node, t, vy}
var text_pool: Array = []
var shake := 0.0
var overlay: ColorRect
var overlay_mat: ShaderMaterial
var hurt := 0.0
var low_hp := false
const FIREWORK_COLORS := {"gold": Color(1.0, 0.8, 0.25), "teal": Color(0.3, 1.0, 0.9), "pink": Color(1.0, 0.45, 0.75), "green": Color(0.55, 1.0, 0.35), "violet": Color(0.7, 0.5, 1.0)}
var low_k := 1.0
var motes: GPUParticles3D
var cam: Camera3D

const OVERLAY_SHADER := """
shader_type canvas_item;
uniform float hurt = 0.0;
uniform float base = 0.35;
void fragment() {
	vec2 uv = UV - 0.5;
	float d = length(uv * vec2(1.15, 1.0));
	float v = smoothstep(0.30, 0.85, d);
	vec3 col = mix(vec3(0.0, 0.02, 0.03), vec3(0.8, 0.05, 0.05), clamp(hurt * 2.0, 0.0, 1.0));
	COLOR = vec4(col, v * (base + hurt * 0.38));
}
"""

func _init() -> void:
	soft_tex = GradientTexture2D.new()
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.45), Color(1, 1, 1, 0)])
	soft_tex.gradient = g
	soft_tex.fill = GradientTexture2D.FILL_RADIAL
	soft_tex.fill_from = Vector2(0.5, 0.5)
	soft_tex.fill_to = Vector2(1.0, 0.5)
	soft_tex.width = 128
	soft_tex.height = 128
	spark_tex = GradientTexture2D.new()
	var sg := Gradient.new()
	sg.offsets = PackedFloat32Array([0.0, 0.3, 0.65, 1.0])
	sg.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.95), Color(1, 1, 1, 0.3), Color(1, 1, 1, 0)])
	spark_tex.gradient = sg
	spark_tex.fill = GradientTexture2D.FILL_RADIAL
	spark_tex.fill_from = Vector2(0.5, 0.5)
	spark_tex.fill_to = Vector2(1.0, 0.5)
	spark_tex.width = 64
	spark_tex.height = 64
	ring_tex = GradientTexture2D.new()
	var rg := Gradient.new()
	rg.offsets = PackedFloat32Array([0.0, 0.6, 0.82, 0.93, 1.0])
	rg.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 0.05), Color(1, 1, 1, 1), Color(1, 1, 1, 0.25), Color(1, 1, 1, 0)])
	ring_tex.gradient = rg
	ring_tex.fill = GradientTexture2D.FILL_RADIAL
	ring_tex.fill_from = Vector2(0.5, 0.5)
	ring_tex.fill_to = Vector2(1.0, 0.5)
	ring_tex.width = 256
	ring_tex.height = 256

func setup(camera: Camera3D, ui: CanvasLayer) -> void:
	cam = camera
	# Bursts: Anzahl, Lebensdauer, Tempo min/max, Größe, Gravitation, Farbverlauf (Start -> Ende)
	_make_pool("hit", 24, 10, 0.35, 2.0, 5.0, 0.12, Vector3(0, -6, 0), Color(1.0, 0.95, 0.7), Color(1.0, 0.78, 0.25, 0.0), true)
	_make_pool("death", 16, 22, 0.7, 1.5, 4.5, 0.26, Vector3(0, 1.5, 0), Color(0.5, 1.0, 0.85), Color(0.2, 0.7, 0.4, 0.0))
	_make_pool("leaf", 16, 10, 1.0, 1.0, 3.5, 0.22, Vector3(0, -2.5, 0), Color(0.55, 0.85, 0.25), Color(0.3, 0.5, 0.1, 0.0))
	_make_pool("gem", 16, 8, 0.45, 1.0, 3.0, 0.1, Vector3(0, 0.5, 0), Color(0.5, 1.0, 1.0), Color(0.1, 0.6, 1.0, 0.0), true)
	_make_pool("gem_y", 16, 8, 0.45, 1.0, 3.0, 0.1, Vector3(0, 0.5, 0), Color(1.0, 0.95, 0.55), Color(1.0, 0.7, 0.1, 0.0), true)
	_make_pool("gem_b", 16, 8, 0.45, 1.0, 3.0, 0.1, Vector3(0, 0.5, 0), Color(0.75, 0.95, 1.0), Color(0.3, 0.65, 1.0, 0.0), true)
	_make_pool("gem_v", 8, 10, 0.55, 1.0, 3.2, 0.11, Vector3(0, 0.5, 0), Color(0.95, 0.85, 1.0), Color(0.7, 0.4, 1.0, 0.0), true)
	_make_pool("bomb", 6, 40, 0.6, 3.0, 9.0, 0.2, Vector3(0, 2.0, 0), Color(1.0, 0.92, 0.55), Color(1.0, 0.62, 0.12, 0.0))
	_make_pool("level", 3, 80, 1.1, 3.0, 8.0, 0.22, Vector3(0, 1.0, 0), Color(0.7, 1.0, 0.95), Color(0.3, 0.9, 0.5, 0.0))
	_make_pool("heal", 6, 14, 0.8, 0.8, 2.2, 0.18, Vector3(0, 2.5, 0), Color(0.7, 1.0, 0.65), Color(0.3, 0.9, 0.4, 0.0))
	_make_pool("ehit", 12, 10, 0.4, 2.0, 5.0, 0.13, Vector3(0, -6, 0), Color(1.0, 0.45, 0.4), Color(0.85, 0.05, 0.05, 0.0), true)
	_make_pool("dust", 10, 7, 0.55, 0.4, 1.3, 0.13, Vector3(0, 0.6, 0), Color(0.75, 0.7, 0.5), Color(0.5, 0.5, 0.35, 0.0))
	# Feuerwerk: eine Burst-Art pro Farbe (Kugel aus Funken, fallen langsam, verglühen)
	for fw in FIREWORK_COLORS:
		var c: Color = FIREWORK_COLORS[fw]
		_make_pool("fw_" + fw, 8, 56, 1.25, 2.4, 6.0, 0.06, Vector3(0, -2.6, 0), c.lerp(Color(1, 1, 1), 0.12), Color(c.r, c.g, c.b, 0.0), true)
	# Ringe + Lichter vorbereiten
	for i in 8:
		var mi := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(1, 1)
		mi.mesh = pm
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_texture = ring_tex
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		mi.material_override = m
		mi.visible = false
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		ring_pool.append(mi)
	for i in 4:
		var l := OmniLight3D.new()
		l.visible = false
		l.shadow_enabled = false
		add_child(l)
		lights.append({"node": l, "t": 0.0, "dur": 0.0, "e0": 0.0})
	for i in 48:
		var lb := Label3D.new()
		lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lb.no_depth_test = true
		lb.fixed_size = false
		lb.pixel_size = 0.012
		lb.font_size = 64
		lb.outline_size = 14
		lb.outline_modulate = Color(0, 0, 0, 0.9)
		lb.shaded = false
		lb.visible = false
		add_child(lb)
		text_pool.append(lb)
	# Vignette / Treffer-Overlay
	overlay = ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = OVERLAY_SHADER
	overlay_mat = ShaderMaterial.new()
	overlay_mat.shader = sh
	overlay.material = overlay_mat
	ui.add_child(overlay)
	ui.move_child(overlay, 0)
	# Ambient: Sporen / Glühwürmchen um den Spieler
	motes = GPUParticles3D.new()
	motes.amount = 160
	motes.lifetime = 7.0
	motes.local_coords = false
	motes.preprocess = 7.0
	motes.visibility_aabb = AABB(Vector3(-30, -2, -30), Vector3(60, 14, 60))
	var pmat := ParticleProcessMaterial.new()
	pmat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pmat.emission_box_extents = Vector3(22, 3, 22)
	pmat.direction = Vector3(0.2, 1, 0.1)
	pmat.spread = 60.0
	pmat.initial_velocity_min = 0.1
	pmat.initial_velocity_max = 0.5
	pmat.gravity = Vector3(0, 0.05, 0)
	pmat.scale_min = 0.6
	pmat.scale_max = 1.5
	pmat.turbulence_enabled = true
	pmat.turbulence_noise_strength = 0.4
	pmat.color_ramp = _ramp([Color(0.5, 1.0, 0.8, 0.0), Color(0.6, 1.0, 0.85, 0.9), Color(1.0, 0.85, 0.4, 0.0)], [0.0, 0.4, 1.0])
	motes.process_material = pmat
	motes.draw_pass_1 = _quad(0.09)
	motes.position = Vector3(0, 1.5, 0)
	add_child(motes)

func _ramp(cols: Array, offs: Array) -> GradientTexture1D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array(offs)
	g.colors = PackedColorArray(cols)
	var t := GradientTexture1D.new()
	t.gradient = g
	return t

func _quad(size: float, crisp: bool = false) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.billboard_keep_scale = true
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = spark_tex if crisp else soft_tex
	m.disable_receive_shadows = true
	q.material = m
	return q

func _make_pool(name: String, count: int, amount: int, life: float, vmin: float, vmax: float, size: float, grav: Vector3, c0: Color, c1: Color, crisp: bool = false) -> void:
	var nodes: Array = []
	for i in count:
		var p := GPUParticles3D.new()
		p.amount = amount
		p.lifetime = life
		p.one_shot = true
		p.explosiveness = 0.95
		p.emitting = false
		p.local_coords = false
		p.visibility_aabb = AABB(Vector3(-10, -3, -10), Vector3(20, 14, 20))
		var pm := ParticleProcessMaterial.new()
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		pm.emission_sphere_radius = 0.15
		pm.direction = Vector3(0, 0.6, 0)
		pm.spread = 180.0
		pm.initial_velocity_min = vmin
		pm.initial_velocity_max = vmax
		pm.gravity = grav
		pm.damping_min = 1.5
		pm.damping_max = 3.0
		pm.scale_min = 0.6
		pm.scale_max = 1.4
		var sc := Curve.new()
		sc.add_point(Vector2(0, 1.0))
		sc.add_point(Vector2(1, 0.1))
		var sct := CurveTexture.new()
		sct.curve = sc
		pm.scale_curve = sct
		pm.color_ramp = _ramp([Color(c0.r, c0.g, c0.b, 1.0), c1], [0.0, 1.0])
		p.process_material = pm
		p.draw_pass_1 = _quad(size * 2.0, crisp)
		add_child(p)
		nodes.append(p)
	pools[name] = {"nodes": nodes, "i": 0}

func burst(type: String, pos: Vector3, tint: Color = Color.WHITE) -> void:
	var pl: Dictionary = pools[type]
	var p: GPUParticles3D = pl["nodes"][pl["i"]]
	pl["i"] = (pl["i"] + 1) % pl["nodes"].size()
	p.global_position = pos
	(p.process_material as ParticleProcessMaterial).color = tint     # Tönung des Farbverlaufs (z. B. Gegnerfarbe)
	p.restart()

# Dauerhafter Schweif an einem bewegten Node (Pfeil, Geisterkugel, Bombe)
func attach_trail(parent: Node3D, col: Color, size: float, amount: int = 14, life: float = 0.28) -> void:
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	p.local_coords = false
	p.visibility_aabb = AABB(Vector3(-30, -10, -30), Vector3(60, 20, 60))
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 30.0
	pm.initial_velocity_min = 0.0
	pm.initial_velocity_max = 0.25
	pm.gravity = Vector3.ZERO
	pm.scale_min = 0.8
	pm.scale_max = 1.2
	var sc := Curve.new()
	sc.add_point(Vector2(0, 1.0))
	sc.add_point(Vector2(1, 0.0))
	var sct := CurveTexture.new()
	sct.curve = sc
	pm.scale_curve = sct
	pm.color_ramp = _ramp([Color(col.r, col.g, col.b, 0.9), Color(col.r, col.g, col.b, 0.0)], [0.0, 1.0])
	p.process_material = pm
	p.draw_pass_1 = _quad(size * 2.0)
	parent.add_child(p)

# Weicher Leucht-Punkt (Billboard, additiv), z. B. unter Kristallen / an Geisterkugeln
func glow_sprite(parent: Node3D, col: Color, size: float, pos: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.albedo_texture = soft_tex
	m.albedo_color = col
	m.disable_receive_shadows = true
	q.material = m
	mi.mesh = q
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi

func ring(pos: Vector3, r0: float, r1: float, dur: float, col: Color) -> void:
	for mi in ring_pool:
		if not mi.visible:
			mi.visible = true
			mi.global_position = Vector3(pos.x, 0.06, pos.z)
			rings.append({"node": mi, "t": 0.0, "dur": dur, "r0": r0, "r1": r1, "col": col})
			return

func flash(pos: Vector3, col: Color, energy: float, rng: float, dur: float) -> void:
	for l in lights:
		if l["t"] >= l["dur"]:
			var n: OmniLight3D = l["node"]
			n.visible = true
			n.global_position = pos
			n.light_color = col
			n.omni_range = rng
			n.light_energy = energy
			l["t"] = 0.0
			l["dur"] = dur
			l["e0"] = energy
			return

func number(pos: Vector3, value: float, col: Color = Color(1, 0.95, 0.7), txt: String = "") -> void:
	if OS.has_environment("WW_NOUI"):   # Vorschaubilder ohne Zahlen
		return
	# Frische Zahlen in der Nähe (gleiche Farbe) werden zu einer Summe zusammengefasst (Text wie "Ausgewichen" nie)
	for d in (texts if txt == "" else []):
		var lb0: Label3D = d["node"]
		if d["t"] < 0.35 and d["col"] == col and lb0.global_position.distance_to(pos + Vector3(0, 1.2, 0)) < 1.4:
			d["sum"] += value
			lb0.text = str(int(round(d["sum"])))
			d["t"] = 0.05
			lb0.pixel_size = 0.0055 + 0.0035 * clampf(d["sum"] / 40.0, 0.0, 1.0)
			return
	for lb in text_pool:
		if not lb.visible:
			lb.visible = true
			lb.text = txt if txt != "" else str(int(round(value)))
			lb.modulate = col
			lb.global_position = pos + Vector3(randf_range(-0.6, 0.6), 1.2 + 0.18 * (texts.size() % 4), randf_range(-0.4, 0.4))
			lb.pixel_size = 0.0045 if txt != "" else 0.0055 + 0.0035 * clampf(value / 40.0, 0.0, 1.0)
			texts.append({"node": lb, "t": 0.0, "vy": 2.0, "col": col if txt == "" else Color(col.r, col.g, col.b, 0.999), "sum": value})
			return

func add_shake(amount: float) -> void:
	shake = minf(1.0, maxf(shake, amount))

# Feuerwerk: Raketen steigen vom Punkt auf und platzen in der Luft. Höhe richtet sich nach der Kamerahöhe (Draufsicht-Kamera).
func firework(origin: Vector3, bursts: int, palette: Array = ["gold", "teal", "pink"], spread: float = 5.0) -> void:
	for i in bursts:
		var col: String = palette[i % palette.size()]
		var delay := 0.13 * i + randf() * 0.08
		get_tree().create_timer(delay).timeout.connect(func(): _rocket(origin, col, spread))

func _rocket(origin: Vector3, col_name: String, spread: float) -> void:
	var col: Color = FIREWORK_COLORS[col_name]
	var cam_h := cam.global_position.y if cam != null else 10.0
	var apex := Vector3(origin.x + randf_range(-spread, spread), origin.y + clampf(cam_h * randf_range(0.18, 0.32), 1.5, 3.6), origin.z + randf_range(-spread, spread) * 0.6)
	var n := Node3D.new()
	add_child(n)
	n.global_position = origin + Vector3(0, 1.0, 0)
	glow_sprite(n, Color(col.r, col.g, col.b, 0.8), 0.32)
	attach_trail(n, col, 0.05, 20, 0.45)
	var tw := create_tween()
	tw.tween_property(n, "global_position", apex, 0.5 + randf() * 0.15).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func():
		burst("fw_" + col_name, apex)
		get_tree().create_timer(0.16).timeout.connect(func(): burst("fw_" + col_name, apex + Vector3(0, -0.2, 0)))   # zweite Welle
		flash(apex, col, 5.0, 16.0, 0.4)
		add_shake(0.06)
		n.queue_free())

# Lichtsäule (Level-Up, Kiste): steigt aus dem Boden, blendet aus
var pillars: Array = []

func pillar(pos: Vector3, col: Color, dur: float) -> void:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(1.6, 11.0)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	m.albedo_texture = soft_tex
	m.albedo_color = Color(col.r, col.g, col.b, 0.0)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	mi.global_position = Vector3(pos.x, 5.5, pos.z)
	pillars.append({"node": mi, "mat": m, "t": 0.0, "dur": dur, "col": col})

func set_low_hp(on: bool, k: float) -> void:
	low_hp = on
	low_k = k

func hurt_flash() -> void:
	hurt = 0.7

func _process(delta: float) -> void:
	# Ringe
	for i in range(rings.size() - 1, -1, -1):
		var r: Dictionary = rings[i]
		r["t"] += delta
		var k: float = clampf(r["t"] / r["dur"], 0.0, 1.0)
		var mi: MeshInstance3D = r["node"]
		var rad: float = lerpf(r["r0"], r["r1"], 1.0 - pow(1.0 - k, 3.0))
		mi.scale = Vector3(rad * 2.0, 1.0, rad * 2.0)
		var c: Color = r["col"]
		(mi.material_override as StandardMaterial3D).albedo_color = Color(c.r, c.g, c.b, c.a * (1.0 - k))
		if k >= 1.0:
			mi.visible = false
			rings.remove_at(i)
	# Lichter
	for l in lights:
		if l["t"] < l["dur"]:
			l["t"] += delta
			var n: OmniLight3D = l["node"]
			var k: float = clampf(l["t"] / l["dur"], 0.0, 1.0)
			n.light_energy = l["e0"] * (1.0 - k) * (1.0 - k)
			if k >= 1.0:
				n.visible = false
	# Zahlen
	for i in range(texts.size() - 1, -1, -1):
		var d: Dictionary = texts[i]
		d["t"] += delta
		var lb: Label3D = d["node"]
		lb.position.y += d["vy"] * delta
		d["vy"] = maxf(0.4, d["vy"] - 5.0 * delta)
		var k: float = d["t"] / 0.7
		lb.modulate.a = clampf(1.6 - k * 1.6, 0.0, 1.0)
		if k >= 1.0:
			lb.visible = false
			texts.remove_at(i)
	# Lichtsäulen
	for i in range(pillars.size() - 1, -1, -1):
		var pl2: Dictionary = pillars[i]
		pl2["t"] += delta
		var k2: float = clampf(pl2["t"] / pl2["dur"], 0.0, 1.0)
		var a: float = sin(k2 * PI) * 0.75
		var c2: Color = pl2["col"]
		(pl2["mat"] as StandardMaterial3D).albedo_color = Color(c2.r, c2.g, c2.b, a)
		(pl2["node"] as Node3D).scale = Vector3(1.0 - 0.35 * k2, 1.0, 1.0)
		if k2 >= 1.0:
			(pl2["node"] as Node3D).queue_free()
			pillars.remove_at(i)
	# Kamera + Overlay
	shake = maxf(0.0, shake - delta * 2.8)
	if cam != null:
		var s := shake * shake * 0.35
		cam.h_offset = randf_range(-s, s)
		cam.v_offset = randf_range(-s, s)
	hurt = maxf(0.0, hurt - delta * 3.0)
	if overlay_mat != null:
		overlay_mat.set_shader_parameter("hurt", hurt)
		var base := 0.35
		if low_hp:
			base = 0.45 + 0.3 * (0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.006 * (1.0 + (1.0 - low_k) * 1.5)))
		overlay_mat.set_shader_parameter("base", base)

func follow(pos: Vector3) -> void:
	motes.global_position = Vector3(pos.x, 1.5, pos.z)
