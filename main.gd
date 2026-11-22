extends Node3D
## Wyrdwood Survivors: Vampire-Survivors-artiges Spiel in 3D (Top-Down) mit Dark-Fairytale-Setting.

const M := "res://assetdesk/3dmodels/"
const PLAYER_MODEL := M + "characters/elfe_mit_langen.glb"

const ENEMIES := Defs.ENEMIES   # Archetypen/Statistiken: defs.gd
const FACE_OFFSET := 0.0  # ggf. anpassen, falls Modelle seitlich/rückwärts schauen

var rng := RandomNumberGenerator.new()
var model_cache := {}

# Spielzustand
var player: Node3D
var cam: Camera3D
var hp := 100.0
var max_hp := 100.0
var speed := 5.0
var magnet := 3.0
var dmg_mult := 1.0
var xp := 0
var xp_next := 5
var level := 1
var kills := 0
var time := 0.0
var invuln := 0.0
var dead := false
var won := false
var boss_spawned := false
var elite_timer := 60.0
var spawn_acc := 0.0
var look_dir := Vector3(0, 0, 1)
var cam_zoom := 1.0
var zoom_target := 1.0
const ZOOM_MIN := 0.55
const ZOOM_MAX := 1.6
const DART_RANGE := 11.0   # Reichweite Dornenpfeil (Zielsuche und Flugweite)
const BOMB_RANGE := 9.0
const SIGIL_ALPHA := 0.22   # Deckkraft des Runen-Siegels (fast durchsichtig)
var view_rigs: Array = []
var vfx: Vfx
var mouse_down := false         # Maus: Taste gehalten = dem Cursor folgen, Klick = zum Punkt laufen
var move_target := Vector3.ZERO
var has_target := false
var move_marker: MeshInstance3D
var lv: Dictionary            # Level-Daten (defs.gd LEVELS)
var win_time := 900.0
var menu_mode := false
var menu: MenuUI
var menu_t := 0.0
var revived := false
var meta_xp := 0.0
var aim_dir := Vector3(0, 0, 1)
var aim_t := 0.0
var face_yaw := 0.0
var sigils: Array = []      # Dictionary: node, t, dur, d
var dying: Array = []       # Dictionary: node, t
var boss: Dictionary = {}
var banner_t := 0.0
var level_label: Label
var timer_label: Label
var boss_bar: ProgressBar
var boss_box: Control
var banner: Label
var pause_box: Control
var choice_panel: PanelContainer
var choice_layer: Control
var end_layer: Control
var choice_actions: Array = []
var paused_menu := false
var skel: Skeleton3D
var anim_t := 0.0
var walk_blend := 0.0
var cast_t := 0.0
var hit_t := 0.0
var moving := false
const ARM_DOWN := 1.15

var enemies: Array = []     # Dictionary: node, type, hp, spd, dmg, flash
var pickups: Array = []     # Dictionary: node, kind
var shots: Array = []       # Dictionary: node, vel, life, dmg, pierce
var bombs: Array = []       # Dictionary: node, from, to, t, dur
var blasts: Array = []      # Dictionary: node, life
var props := {}             # Zellen-Key -> Array[Node3D]

# Waffen: Level 0 = nicht vorhanden
var weapons := {"thorn": 1}      # besessene Waffen -> Stufe
var passives := {}               # besessene Passive -> Stufe
var cd := {}
var base_speed := 5.0
var base_magnet := 3.0
var cd_mult := 1.0
var area_mult := 1.0
var xp_mult := 1.0
var regen := 0.0
var meta_dmg := 0.0              # dauerhafte Boni (Meta-Fortschritt)
var meta_hp := 0.0
var extra: WeaponsExtra
var eshots: Array = []           # Gegner-Geschosse: node, vel, life, dmg
var next_enemy_id := 0
var slot_box: Control
var cards: Array = []
var orb_root: Node3D
var orb_angle := 0.0

# UI
var ui: CanvasLayer
var hp_bar: ProgressBar
var xp_bar: ProgressBar
var info: Label
var choice_box: VBoxContainer
var end_label: Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # Eingabe (Pause, Level-Up-Tasten) läuft auch bei pausiertem Baum
	rng.randomize()
	if OS.has_environment("WW_SHOT") and not OS.has_environment("WW_MENU"):
		Meta.in_menu = false      # Testläufe starten direkt im Spiel
	if OS.has_environment("WW_LEVEL"):
		Meta.level_id = OS.get_environment("WW_LEVEL")
	lv = Defs.LEVELS[Meta.level_id]
	win_time = lv["time"]
	menu_mode = Meta.in_menu
	base_speed = 5.0 * (1.0 + 0.02 * Meta.lvl("m_speed"))
	base_magnet = 3.0 * (1.0 + 0.10 * Meta.lvl("m_magnet"))
	meta_dmg = 0.02 * Meta.lvl("m_dmg")
	meta_hp = 5.0 * Meta.lvl("m_hp")
	meta_xp = 0.03 * Meta.lvl("m_xp")
	_setup_quality()
	_setup_world()
	_setup_player()
	_setup_ui()
	vfx = Vfx.new()
	add_child(vfx)
	vfx.setup(cam, ui)
	extra = WeaponsExtra.new()
	extra.g = self
	apply_passives()
	_refresh_slots()
	if menu_mode:
		_enter_menu_mode()
	if OS.has_environment("WW_SHOT"):  # Test: Screenshot nach Vorlauf
		time = float(OS.get_environment("WW_SHOT"))
		cam_zoom = float(OS.get_environment("WW_ZOOM")) if OS.has_environment("WW_ZOOM") else 1.0
		if not OS.has_environment("WW_W"):
			weapons["orbs"] = 2
		if OS.has_environment("WW_W"):
			weapons.clear()
			for pair in OS.get_environment("WW_W").split(","):
				var kv := pair.split(":")
				weapons[kv[0]] = int(kv[1])
		if OS.has_environment("WW_P"):
			for pair in OS.get_environment("WW_P").split(","):
				var kv2 := pair.split(":")
				passives[kv2[0]] = int(kv2[1])
			apply_passives()
		if OS.has_environment("WW_VIEW"):  # Test: Kreatur in 4 Gangphasen nebeneinander (eingefroren)
			player.visible = false
			var gap := float(OS.get_environment("WW_GAP")) if OS.has_environment("WW_GAP") else 2.0
			for k in 4:
				var vm := RigAnim.make_model(OS.get_environment("WW_VIEW"))
				vm.position = Vector3((k - 1.5) * gap, 0, 0)
				vm.rotation.y = float(OS.get_environment("WW_YAW")) if OS.has_environment("WW_YAW") else PI * 0.5
				add_child(vm)
				var vr: RigAnim = vm.get_meta("rig")
				vr.phase = k * PI * 0.5
				view_rigs.append(vr)
			weapons.clear()
			invuln = 99.0
		if OS.has_environment("WW_SPAWN"):
			for k in int(OS.get_environment("WW_N") if OS.has_environment("WW_N") else "1"):
				_spawn_enemy(OS.get_environment("WW_SPAWN"))
				var ee: Dictionary = enemies[-1]
				(ee["node"] as Node3D).position = player.position + Vector3(cos(k * 2.4), 0, sin(k * 2.4)) * (5.0 + (k % 25))
				ee["spd"] = float(OS.get_environment("WW_SPD")) if OS.has_environment("WW_SPD") else 0.8
			weapons.clear()
			invuln = 99.0
		if not OS.has_environment("WW_VIEW") and not OS.has_environment("WW_SPAWN"):
			weapons["acorn"] = 1
		_refresh_slots()
		if OS.has_environment("WW_PAUSE"):
			get_tree().create_timer(1.0).timeout.connect(func():
				paused_menu = true
				pause_box.visible = true
				get_tree().paused = true)
		if OS.has_environment("WW_ENDTEST"):
			get_tree().create_timer(1.0).timeout.connect(func(): kills = 123; level = 7; _end(false))
		if OS.has_environment("WW_CLICK"):
			var xz := OS.get_environment("WW_CLICK").split(",")
			get_tree().create_timer(0.8).timeout.connect(func(): _set_move_target(Vector3(float(xz[0]), 0, float(xz[1])), true))
		if OS.has_environment("WW_LEVELUP"):
			get_tree().create_timer(1.2).timeout.connect(_level_up)
		get_tree().create_timer(float(OS.get_environment("WW_T")) if OS.has_environment("WW_T") else 6.0).timeout.connect(func():
			print("FPS ", Engine.get_frames_per_second(), " enemies=", enemies.size(), " player=", player.position.snapped(Vector3(0.1, 0.1, 0.1)), " target=", has_target, move_target.snapped(Vector3(0.1, 0.1, 0.1)), " mitte=", (_ground_at(get_viewport().get_visible_rect().size / 2.0) as Vector3).snapped(Vector3(0.1, 0.1, 0.1)))
			get_viewport().get_texture().get_image().save_png(OS.get_environment("WW_OUT"))
			get_tree().quit())

# ---------- Aufbau ----------
func _setup_quality() -> void:
	# UI skaliert über canvas_items-Stretch (Basis 1920x1080). 3D-Last nach echter Pixelzahl:
	# 4K -> FSR2 mit 67 % Renderauflösung, 1440p -> nativ, 1080p -> nativ.
	var vp := get_viewport()
	var h := DisplayServer.window_get_size().y
	if h >= 2000:
		vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR2
		vp.scaling_3d_scale = 0.67
		vp.msaa_3d = Viewport.MSAA_DISABLED
	else:
		vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
		vp.scaling_3d_scale = 1.0
		vp.msaa_3d = Viewport.MSAA_2X
	vp.use_taa = false


func _scene_or_null(path: String) -> PackedScene:
	if model_cache.has(path):
		return model_cache[path]
	var s: PackedScene = null
	if ResourceLoader.exists(path):
		s = load(path)
	model_cache[path] = s
	return s

# Echte Längste-Seite (m) laut Asset Desk; die GLBs selbst sind auf Einheitsgröße (±0,5) normalisiert.
const MODEL_SIZE := {
	"characters/elfe_mit_langen.glb": 1.75,
	"items/spirit_gem.glb": 0.25, "items/heart_berry.glb": 0.3, "items/rune_chest.glb": 0.9,
	"weapons/thorn_dart.glb": 0.6, "weapons/acorn_bomb.glb": 0.4,
	"nature/gnarled_tree.glb": 5.0, "nature/mossy_boulder.glb": 1.8, "nature/glow_mushrooms.glb": 0.9,
	"structures/standing_stone.glb": 3.0, "weapons/moon_scythe.glb": 0.9,
	"items/spirit_wisp.glb": 0.5, "decor/rune_sigil.glb": 3.0,
}
var fit_cache := {}

func _mesh_aabb(n: Node, xf: Transform3D, acc: Array) -> void:
	for c in n.get_children():
		if c is Node3D:
			var cx: Transform3D = xf * (c as Node3D).transform
			if c is MeshInstance3D:
				var a: AABB = cx * (c as MeshInstance3D).get_aabb()
				acc[0] = a if acc[0] == null else (acc[0] as AABB).merge(a)
			_mesh_aabb(c, cx, acc)

func _make_model(rel: String, fb_col: Color, fb_size: float) -> Node3D:
	var s := _scene_or_null(M + rel)
	if s:
		var inst: Node3D = s.instantiate()
		if not fit_cache.has(rel):
			var acc := [null]
			_mesh_aabb(inst, Transform3D.IDENTITY, acc)
			var bb: AABB = acc[0]
			var ext := maxf(bb.size.x, maxf(bb.size.y, bb.size.z))
			var sc: float = float(MODEL_SIZE.get(rel, fb_size)) / maxf(ext, 0.001)
			var ctr := bb.get_center()
			fit_cache[rel] = [sc, Vector3(-ctr.x * sc, -bb.position.y * sc, -ctr.z * sc)]
		inst.scale = Vector3.ONE * fit_cache[rel][0]
		inst.position = fit_cache[rel][1]
		var pivot := Node3D.new()   # Füße auf y=0, mittig, echte Größe
		pivot.add_child(inst)
		return pivot
	var mi := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = fb_size * 0.5
	sph.height = fb_size
	mi.mesh = sph
	var mat := StandardMaterial3D.new()
	mat.albedo_color = fb_col
	mi.material_override = mat
	mi.position.y = fb_size * 0.5
	var n := Node3D.new()
	n.add_child(mi)
	return n

func _glow_mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = 2.0
	return m

func _setup_world() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = lv["env"]["bg"]
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = lv["env"]["ambient"]
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.1
	env.glow_enabled = true
	env.glow_intensity = 0.8
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 0.9
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.ssao_enabled = true
	env.ssao_radius = 1.6
	env.ssao_intensity = 2.2
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.08
	env.adjustment_saturation = 1.18
	env.fog_enabled = true
	env.fog_light_color = lv["env"]["fog"]
	env.fog_density = 0.012
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.012
	env.volumetric_fog_albedo = lv["env"]["vfog"]
	env.volumetric_fog_emission = Color(0.01, 0.03, 0.03)
	env.volumetric_fog_length = 50.0
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -30, 0)
	sun.light_color = lv["env"]["sun"]
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 40.0
	add_child(sun)

	cam = Camera3D.new()
	cam.fov = 45
	add_child(cam)

	# Boden: große Ebene, folgt dem Spieler, Textur per World-Triplanar
	var ground := MeshInstance3D.new()
	ground.name = "Ground"
	var pm := PlaneMesh.new()
	pm.size = Vector2(300, 300)
	ground.mesh = pm
	ground.material_override = _ground_material()
	add_child(ground)

func _ground_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.12, 0.2, 0.1)
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3(0.1, 0.1, 0.1)  # 10 m Kachel
	var dir := "res://assetdesk/textures/forest_floor/"
	var da := DirAccess.open(dir)
	if da:
		for f in da.get_files():
			if f.ends_with(".import") or f.ends_with(".md") or f.ends_with(".json"):
				continue
			var lf := f.to_lower()
			var tex = load(dir + f) if ResourceLoader.exists(dir + f) else null
			if tex == null:
				continue
			if "albedo" in lf or "basecolor" in lf or "base_color" in lf or "diffuse" in lf or "color" in lf:
				m.albedo_texture = tex
				m.albedo_color = lv["tint"]
			elif "normal" in lf:
				m.normal_enabled = true
				m.normal_texture = tex
			elif "rough" in lf:
				m.roughness_texture = tex
	return m

func _setup_player() -> void:
	player = Node3D.new()
	add_child(player)
	var mdl := _make_model("characters/elfe_mit_langen.glb", Color(0.8, 0.7, 0.5), 1.7)
	mdl.name = "Model"
	player.add_child(mdl)
	var sks := mdl.find_children("*", "Skeleton3D", true, false)
	if not sks.is_empty():
		skel = sks[0]
	var light := OmniLight3D.new()  # Laterne der Druidin
	light.light_color = Color(1.0, 0.8, 0.5)
	light.omni_range = 9.0
	light.light_energy = 2.0
	light.position = Vector3(0, 2.0, 0)
	player.add_child(light)
	orb_root = Node3D.new()
	player.add_child(orb_root)

func _sb(bg: Color, border: Color = Color(0, 0, 0, 0), radius: int = 6, bw: int = 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(radius)
	return sb

func _bar(col: Color, size: Vector2, pos: Vector2) -> ProgressBar:
	var b := ProgressBar.new()
	b.position = pos
	b.size = size
	b.show_percentage = false
	b.add_theme_stylebox_override("background", _sb(Color(0, 0, 0, 0.55), Color(1, 1, 1, 0.18), 6, 1))
	b.add_theme_stylebox_override("fill", _sb(col, Color(0, 0, 0, 0), 6))
	return b

func _label(text: String, size: int, col: Color = Color(1, 1, 1)) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 8)
	return l

func _centered_layer(dim: float) -> Control:
	var layer := Control.new()
	layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_STOP
	var back := ColorRect.new()
	back.color = Color(0, 0.02, 0.03, dim)
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(back)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(cc)
	layer.visible = false
	return layer

func _setup_ui() -> void:
	ui = CanvasLayer.new()
	ui.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(ui)
	# Leben (oben links) + XP (unten über die ganze Breite)
	hp_bar = _bar(Color(0.85, 0.2, 0.22), Vector2(360, 26), Vector2(28, 24))
	ui.add_child(hp_bar)
	level_label = _label("Lv 1", 30, Color(0.7, 1.0, 0.9))
	level_label.position = Vector2(28, 56)
	ui.add_child(level_label)
	info = _label("", 24, Color(0.9, 0.95, 0.95))
	info.position = Vector2(28, 98)
	ui.add_child(info)
	xp_bar = _bar(Color(0.25, 0.9, 0.95), Vector2(1920, 12), Vector2(0, 1068))
	xp_bar.add_theme_stylebox_override("background", _sb(Color(0, 0, 0, 0.6), Color(0, 0, 0, 0), 0))
	xp_bar.add_theme_stylebox_override("fill", _sb(Color(0.25, 0.9, 0.95), Color(0, 0, 0, 0), 0))
	xp_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	xp_bar.offset_top = -12
	ui.add_child(xp_bar)
	slot_box = Control.new()
	slot_box.position = Vector2(28, 140)
	ui.add_child(slot_box)
	# Zeit oben mittig
	timer_label = _label("15:00", 54, Color(1.0, 0.95, 0.8))
	timer_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	timer_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	timer_label.position.y = 12
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_label.custom_minimum_size = Vector2(300, 0)
	timer_label.offset_left = -150
	timer_label.offset_right = 150
	ui.add_child(timer_label)
	# Boss-Leiste
	boss_box = Control.new()
	boss_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	boss_box.visible = false
	ui.add_child(boss_box)
	boss_bar = _bar(Color(0.55, 0.9, 0.7), Vector2(900, 22), Vector2(-450, 84))
	boss_bar.add_theme_stylebox_override("fill", _sb(Color(0.55, 0.15, 0.7), Color(0, 0, 0, 0), 6))
	boss_box.add_child(boss_bar)
	var bl := _label(lv["boss"]["name"], 26, Color(0.85, 0.7, 1.0))
	bl.position = Vector2(-450, 48)
	boss_box.add_child(bl)
	# Banner
	banner = _label("", 64, Color(1, 0.9, 0.6))
	banner.set_anchors_preset(Control.PRESET_CENTER)
	banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.offset_left = -700
	banner.offset_right = 700
	banner.offset_top = -380
	banner.modulate.a = 0.0
	ui.add_child(banner)
	# Level-Up-Auswahl
	choice_layer = _centered_layer(0.55)
	ui.add_child(choice_layer)
	choice_panel = PanelContainer.new()
	choice_panel.add_theme_stylebox_override("panel", _sb(Color(0.04, 0.09, 0.09, 0.96), Color(0.4, 0.9, 0.8, 0.8), 14, 2))
	var pad := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 32)
	choice_panel.add_child(pad)
	choice_box = VBoxContainer.new()
	choice_box.custom_minimum_size = Vector2(1100, 0)
	choice_box.add_theme_constant_override("separation", 14)
	pad.add_child(choice_box)
	choice_layer.get_child(1).add_child(choice_panel)
	# Pause
	pause_box = _centered_layer(0.6)
	var pp := PanelContainer.new()
	pp.add_theme_stylebox_override("panel", _sb(Color(0.04, 0.09, 0.09, 0.97), Color(0.4, 0.9, 0.8, 0.7), 16, 2))
	var ppad := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		ppad.add_theme_constant_override("margin_" + side, 40)
	pp.add_child(ppad)
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 16)
	ppad.add_child(pv)
	var ptitle := _label("Pause", 56, Color(0.8, 1.0, 0.95))
	ptitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pv.add_child(ptitle)
	var pb1 := MenuUI.btn("Weiter  (Esc)", Vector2(420, 66), 30)
	pb1.pressed.connect(func():
		paused_menu = false
		pause_box.visible = false
		get_tree().paused = false)
	var pb2 := MenuUI.btn("Lauf beenden, Hauptmenü  (M)", Vector2(420, 66), 26)
	pb2.pressed.connect(_abandon)
	var pb3 := MenuUI.btn("Vollbild  (F11)", Vector2(420, 66), 26)
	pb3.pressed.connect(func():
		var m := DisplayServer.window_get_mode()
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if m == DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN))
	var pb4 := MenuUI.btn("Beenden  (Q)", Vector2(420, 66), 26, Color(1.0, 0.5, 0.45))
	pb4.pressed.connect(func(): get_tree().quit())
	for pbx in [pb1, pb2, pb3, pb4]:
		pv.add_child(pbx)
	pause_box.get_child(1).add_child(pp)
	ui.add_child(pause_box)
	# Ende
	end_layer = _centered_layer(0.65)
	end_label = _label("", 60, Color(1, 0.95, 0.8))
	end_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end_layer.get_child(1).add_child(end_label)
	ui.add_child(end_layer)

# ---------- Hauptschleife ----------
func _unhandled_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb == null:
		return
	if get_tree().paused or menu_mode or dead or won:
		mouse_down = false
		return
	if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
		zoom_target = clampf(zoom_target - 0.1, ZOOM_MIN, ZOOM_MAX)
	elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
		zoom_target = clampf(zoom_target + 0.1, ZOOM_MIN, ZOOM_MAX)
	elif mb.button_index == MOUSE_BUTTON_LEFT or mb.button_index == MOUSE_BUTTON_RIGHT:
		mouse_down = mb.pressed
		if mb.pressed:
			_update_mouse_target(true)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		mouse_down = false

# Punkt auf dem Boden (y = 0) unter einer Bildschirmposition
func _ground_at(screen: Vector2) -> Variant:
	var o := cam.project_ray_origin(screen)
	var d := cam.project_ray_normal(screen)
	if absf(d.y) < 0.001:
		return null
	var t := -o.y / d.y
	if t < 0.0:
		return null
	return o + d * t

func _set_move_target(p: Vector3, click: bool) -> void:
	var off := p - player.position
	off.y = 0.0
	if off.length() > 60.0:
		off = off.normalized() * 60.0
	move_target = player.position + off
	move_target.y = 0.0
	has_target = true
	if click:
		vfx.ring(move_target, 0.15, 0.9, 0.45, Color(0.5, 1.0, 0.9, 0.9))

func _update_mouse_target(click: bool) -> void:
	var p = _ground_at(get_viewport().get_mouse_position())
	if p != null:
		_set_move_target(p, click)

func _update_move_marker() -> void:
	if move_marker == null:
		move_marker = MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(1.1, 1.1)
		move_marker.mesh = pm
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_texture = vfx.ring_tex
		m.albedo_color = Color(0.5, 1.0, 0.9, 0.8)
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		move_marker.material_override = m
		move_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(move_marker)
	move_marker.visible = has_target
	if has_target:
		move_marker.position = Vector3(move_target.x, 0.07, move_target.z)
		var pulse := 1.0 + 0.12 * sin(time * 8.0)
		move_marker.scale = Vector3(pulse, 1.0, pulse)

func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	if menu_mode and k.keycode != KEY_F11:
		return
	match k.keycode:
		KEY_M:
			if paused_menu:
				_abandon()
		KEY_F11:
			var m := DisplayServer.window_get_mode()
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if m == DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)
		KEY_ESCAPE:
			if not choice_layer.visible and not dead and not won:
				paused_menu = not paused_menu
				pause_box.visible = paused_menu
				get_tree().paused = paused_menu
		KEY_Q:
			if paused_menu or dead or won:
				get_tree().quit()
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			if dead or won:
				_restart_run()
		KEY_1, KEY_2, KEY_3:
			if choice_layer.visible:
				_pick(k.keycode - KEY_1)

func _pick(i: int) -> void:
	if i < 0 or i >= choice_actions.size():
		return
	(choice_actions[i] as Callable).call()
	choice_layer.visible = false
	get_tree().paused = false

func _process(delta: float) -> void:
	if get_tree().paused:
		return
	if menu_mode:
		_process_menu(delta)
		return
	if dead or won:
		return
	time += delta
	for vr in view_rigs:
		(vr as RigAnim).update(0.0, 0.0)
	invuln = maxf(0.0, invuln - delta)
	if regen > 0.0:
		hp = minf(max_hp, hp + regen * delta)
	_move_player(delta)
	_update_camera()
	_spawn_logic(delta)
	_update_enemies(delta)
	_update_weapons(delta)
	_update_shots(delta)
	_update_bombs(delta)
	_update_blasts(delta)
	_update_pickups(delta)
	_update_dying(delta)
	_update_sigils(delta)
	_update_props()
	_update_ui()
	vfx.follow(player.position)
	if time >= win_time:
		_end(true)

func _move_player(delta: float) -> void:
	var v := Vector3(
		Input.get_axis("ui_left", "ui_right") + _key_axis(KEY_A, KEY_D),
		0,
		Input.get_axis("ui_up", "ui_down") + _key_axis(KEY_W, KEY_S))
	if OS.has_environment("WW_WALK"):
		v = Vector3(1, 0, 0.4)
	# Maus: Tastatur hat Vorrang; sonst zum Zielpunkt laufen (Taste gehalten = Ziel folgt dem Cursor)
	if v.length() > 0.1:
		has_target = false
	elif has_target or mouse_down:
		if mouse_down:
			_update_mouse_target(false)
		if has_target:
			var to := move_target - player.position
			to.y = 0.0
			var dist := to.length()
			if dist < 0.4:
				if not mouse_down:
					has_target = false
				v = Vector3.ZERO
			else:
				v = to / dist * clampf(dist / 1.2, 0.35, 1.0)
	_update_move_marker()
	moving = v.length() > 0.1
	_animate_player(delta)
	var mdl := player.get_node("Model") as Node3D
	if moving:
		v = v.limit_length(1.0)
		player.position += v * speed * delta
		look_dir = v.normalized()
		mdl.position.y = absf(sin(anim_t * 2.0)) * 0.05 * walk_blend
	# Blick: beim Feuern kurz in Zielrichtung, sonst in Laufrichtung
	aim_t = maxf(0.0, aim_t - delta)
	var face := Vector3.ZERO
	if aim_t > 0.0:
		face = aim_dir
	elif moving:
		face = look_dir
	if face != Vector3.ZERO:
		face_yaw = lerp_angle(face_yaw, atan2(face.x, face.z) + deg_to_rad(FACE_OFFSET), 1.0 - exp(-18.0 * delta))
		mdl.rotation.y = face_yaw
	$Ground.position = Vector3(player.position.x, 0, player.position.z)

func _key_axis(neg: int, pos: int) -> float:
	return float(Input.is_physical_key_pressed(pos)) - float(Input.is_physical_key_pressed(neg))

func _update_camera() -> void:
	if not OS.has_environment("WW_SHOT"):
		cam_zoom = lerpf(cam_zoom, zoom_target, 0.15)
	var target := player.position + Vector3(0, 10, 6.5) * cam_zoom
	if OS.has_environment("WW_SIDE"):
		target = player.position + Vector3(0, 1.8, 9.0) * cam_zoom
	cam.position = cam.position.lerp(target, 0.15)
	cam.look_at(player.position + Vector3(0, 1.0 if OS.has_environment("WW_SIDE") else 0.5, 0))

# ---------- Elfen-Animation (prozedural auf dem Rig) ----------
# Knochen (UniRig-Namen bone_N): 0 Hüfte, 1-2 Wirbelsäule, 3 Brust, 4-6 Hals/Kopf,
# Arm A: 8 Schulter, 9 Ellbogen, 10 Hand | Arm B: 27, 28, 29
# Bein A: 45 Hüfte, 46 Knie, 47 Knöchel    | Bein B: 49, 50, 51
func _rot(i: int, r: Basis) -> void:
	# r = Drehung im Skelett-Raum (Ruhepose-Rahmen), wird auf Knochen i angewandt
	var g := skel.get_bone_global_rest(i).basis.orthonormalized()
	var d := g.inverse() * r * g
	var rest_q := skel.get_bone_rest(i).basis.orthonormalized().get_rotation_quaternion()
	skel.set_bone_pose_rotation(i, rest_q * d.get_rotation_quaternion())

func _animate_player(delta: float) -> void:
	if skel == null:
		return
	walk_blend = move_toward(walk_blend, 1.0 if moving else 0.0, delta * 6.0)
	anim_t += delta * (speed * 1.9 * walk_blend + 1.4 * (1.0 - walk_blend))
	cast_t = maxf(0.0, cast_t - delta)
	if OS.has_environment("WW_CAST"):
		cast_t = 0.15
	hit_t = maxf(0.0, hit_t - delta)
	var w := walk_blend
	var p := anim_t
	var X := Vector3.RIGHT
	var Y := Vector3.UP
	var Z := Vector3.BACK
	var cast_k := sin(clampf(cast_t / 0.3, 0.0, 1.0) * PI)   # 0 -> 1 -> 0
	var hit_k := clampf(hit_t / 0.35, 0.0, 1.0)
	# Beine: Seite A (+X) / B (-X) gegenphasig
	for side in 2:
		var sg := 1.0 if side == 0 else -1.0
		var hip := 45 if side == 0 else 49
		var ph := p * (1.0 if side == 0 else 1.0) + (0.0 if side == 0 else PI)
		_rot(hip, Basis(X, 0.75 * sin(ph) * w))
		_rot(hip + 1, Basis(X, 0.9 * maxf(0.0, -cos(ph)) * w))
		_rot(hip + 2, Basis(X, -0.25 * maxf(0.0, sin(ph)) * w))
		# Arme: gegenläufig zum Bein derselben Seite
		var sh := 8 if side == 0 else 27
		var swing := -0.55 * sin(ph) * w
		var down := ARM_DOWN
		var elbow := -0.35 - 0.3 * maxf(0.0, -sin(ph)) * w
		if side == 0 and cast_k > 0.0:   # Wurfarm nach vorn
			swing = lerpf(swing, -1.45, cast_k)
			down = ARM_DOWN * (1.0 - 0.15 * cast_k)
			elbow = lerpf(elbow, -0.15, cast_k)
		_rot(sh, Basis(X, swing) * Basis(Z, -sg * down))
		_rot(sh + 1, Basis(X, elbow))
	# Rumpf: Vorlehnen, Gegendrehung, Atmen, Treffer-Rückbeuge
	var breathe := sin(p * 1.1) * 0.025 * (1.0 - w)
	_rot(1, Basis(X, 0.10 * w + breathe - 0.25 * hit_k) * Basis(Y, 0.22 * sin(p) * w + 0.25 * cast_k))
	_rot(2, Basis(Y, 0.12 * sin(p) * w))
	_rot(3, Basis(X, breathe * 0.5))
	_rot(5, Basis(Y, -0.2 * sin(p) * w) * Basis(X, 0.1 * hit_k))
	var hips_y := 0.03 * absf(sin(p)) * w
	skel.set_bone_pose_position(0, skel.get_bone_rest(0).origin + Vector3(0, hips_y, 0))

# ---------- Gegner ----------
func _spawn_logic(delta: float) -> void:
	var minute := time / 60.0
	var rate := (1.2 + minute * 1.1) * float(lv["rate"])   # Gegner pro Sekunde
	spawn_acc += rate * delta
	while spawn_acc >= 1.0 and enemies.size() < 350:
		spawn_acc -= 1.0
		_spawn_enemy(_pick_type(minute))
	var el: Dictionary = lv["elite"]
	elite_timer -= delta
	if elite_timer <= 0.0 and minute >= el["first"]:
		elite_timer = el["every"]
		_spawn_enemy(el["type"])
	var bs: Dictionary = lv["boss"]
	if not boss_spawned and time >= bs["time"]:
		boss_spawned = true
		_spawn_enemy(bs["type"])
		boss = enemies[-1]
		_show_banner(bs["banner"])
		vfx.add_shake(0.6)

func _pick_type(minute: float) -> String:
	var table: Array = lv["spawn"]
	var total := 0.0
	for r in table:
		if minute >= r[0]:
			total += r[2]
	var roll := rng.randf() * total
	for r in table:
		if minute >= r[0]:
			roll -= r[2]
			if roll <= 0.0:
				return r[1]
	return "imp"

func _spawn_enemy(type: String) -> void:
	var d: Dictionary = ENEMIES[type]
	var a := rng.randf() * TAU
	var pos := player.position + Vector3(cos(a), 0, sin(a)) * 24.0
	var n: Node3D = null
	if RigAnim.CFG.has(type):
		n = RigAnim.make_model(type)   # geriggt + prozedural animiert (null = Rückfall auf statisches Modell)
	if n == null:
		n = _make_model(d["m"], d["col"], d["sz"] * 2.0)
	n.position = pos
	add_child(n)
	var scale_hp := 1.0 + time / 240.0
	next_enemy_id += 1
	enemies.append({"node": n, "type": type, "id": next_enemy_id, "role": d["role"], "hp": d["hp"] * scale_hp,
		"spd": d["spd"] * rng.randf_range(0.9, 1.1), "dmg": d["dmg"], "punch": 0.0, "max": d["hp"] * scale_hp,
		"r": d["sz"] * 0.8, "acc": 0.0, "col": d["col"], "armor": d.get("armor", 0.0), "stun": 0.0, "slow": 0.0, "slow_until": 0.0,
		"shot_t": rng.randf_range(0.5, d.get("shot_cd", 2.0)), "heal_t": rng.randf_range(0.2, 1.0),
		"rig": (n.get_meta("rig") if n.has_meta("rig") else null)})

func _update_enemies(delta: float) -> void:
	var ppos := player.position
	for i in range(enemies.size() - 1, -1, -1):
		var e: Dictionary = enemies[i]
		var n: Node3D = e["node"]
		var to := ppos - n.position
		to.y = 0
		var dist := to.length()
		if dist > 45.0:  # zu weit weg: nahe Spieler neu setzen
			var a := rng.randf() * TAU
			n.position = ppos + Vector3(cos(a), 0, sin(a)) * 24.0
			continue
		var dir := to / maxf(dist, 0.001)
		var d: Dictionary = ENEMIES[e["type"]]
		# Statuseffekte
		var sf := 1.0
		if e["stun"] > 0.0:
			e["stun"] -= delta
			sf = 0.0
		elif time < e["slow_until"]:
			sf = 1.0 - e["slow"]
		var mv := dir
		var move_speed: float = e["spd"] * sf
		match e["role"]:
			"caster":
				var rng_c: float = d["range"]
				if dist < rng_c * 0.7:
					mv = -dir * 0.6                        # zu nah: zurückweichen
				elif dist < rng_c:
					move_speed = 0.0                        # in Reichweite: stehen und zaubern
				e["shot_t"] -= delta
				if e["shot_t"] <= 0.0 and dist < rng_c + 3.0 and e["stun"] <= 0.0:
					e["shot_t"] = d["shot_cd"]
					_enemy_shot(n.position + Vector3(0, 1.0, 0), dir, d["shot_dmg"])
			"healer":
				if dist < 8.0:
					move_speed = 0.0
				e["heal_t"] -= delta
				if e["heal_t"] <= 0.0:
					e["heal_t"] = 1.2
					_heal_pulse(e, d["heal"], d["heal_range"])
		n.position += mv * move_speed * delta
		e["punch"] = maxf(0.0, e["punch"] - delta * 7.0)
		var pk: float = e["punch"]
		n.scale = Vector3(1.0 + 0.16 * pk, 1.0 - 0.10 * pk, 1.0 + 0.16 * pk)
		var rigged = e["rig"] != null
		n.rotation.y = lerp_angle(n.rotation.y, atan2(dir.x, dir.z) + (0.0 if rigged else deg_to_rad(FACE_OFFSET)), 10.0 * delta)
		if rigged:  # weit entfernte Gegner nur jeden 3. Frame animieren (Kosten)
			e["acc"] += delta
			if dist < 16.0 or (Engine.get_process_frames() + i) % 3 == 0:
				(e["rig"] as RigAnim).update(e["acc"], move_speed)
				e["acc"] = 0.0
		# Abstoßung zu einem zufälligen Nachbarn (billig)
		if enemies.size() > 1:
			var o: Dictionary = enemies[rng.randi() % enemies.size()]
			if o != e:
				var diff: Vector3 = n.position - (o["node"] as Node3D).position
				diff.y = 0
				var l := diff.length()
				if l < 0.9 and l > 0.001:
					n.position += diff / l * 2.0 * delta
		if dist < e["r"] + 0.5 and invuln <= 0.0:
			_hurt(e["dmg"])
	_update_eshots(delta)

func _heal_pulse(healer: Dictionary, amount: float, rng_h: float) -> void:
	var hp_pos: Vector3 = (healer["node"] as Node3D).position
	var healed := 0
	for o in enemies:
		if o == healer or o["hp"] >= o["max"]:
			continue
		if ((o["node"] as Node3D).position - hp_pos).length() < rng_h:
			o["hp"] = minf(o["max"], o["hp"] + amount)
			vfx.burst("heal", (o["node"] as Node3D).position + Vector3(0, 0.8, 0))
			healed += 1
	if healed > 0:
		vfx.ring(hp_pos, 0.3, rng_h, 0.6, Color(0.5, 1.0, 0.5, 0.7))

func _enemy_shot(pos: Vector3, dir: Vector3, dmg: float) -> void:
	var n := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.2
	sph.height = 0.4
	n.mesh = sph
	n.material_override = _glow_mat(Color(0.5, 1.0, 0.85))
	n.position = pos
	add_child(n)
	vfx.glow_sprite(n, Color(0.4, 1.0, 0.8, 0.6), 0.9)
	vfx.attach_trail(n, Color(0.4, 1.0, 0.8), 0.12, 16, 0.3)
	eshots.append({"node": n, "vel": dir * 7.0, "life": 4.0, "dmg": dmg})

func _update_eshots(delta: float) -> void:
	for i in range(eshots.size() - 1, -1, -1):
		var s: Dictionary = eshots[i]
		var n: Node3D = s["node"]
		n.position += s["vel"] * delta
		s["life"] -= delta
		var gone: bool = s["life"] <= 0.0
		if not gone and (n.position - (player.position + Vector3(0, 1.0, 0))).length() < 0.8:
			if invuln <= 0.0:
				_hurt(s["dmg"])
			vfx.burst("hit", n.position)
			gone = true
		if gone:
			n.queue_free()
			eshots.remove_at(i)

func _hurt(amount: float) -> void:
	hp -= amount
	invuln = 0.5
	hit_t = 0.35
	vfx.hurt_flash()
	vfx.add_shake(0.35 + minf(0.4, amount / 40.0))
	vfx.number(player.position + Vector3(0, 0.8, 0), amount, Color(1.0, 0.35, 0.3))
	if hp <= 0.0:
		if Meta.lvl("m_revive") > 0 and not revived:
			revived = true
			hp = max_hp * 0.5
			invuln = 3.0
			_show_banner("Wiedergeburt!")
			vfx.ring(player.position, 0.5, 9.0, 0.8, Color(1.0, 0.9, 0.5, 1.0))
			vfx.flash(player.position + Vector3(0, 1.5, 0), Color(1.0, 0.9, 0.6), 8.0, 14.0, 0.6)
			vfx.add_shake(0.6)
			for e in enemies.duplicate():
				if ((e["node"] as Node3D).position - player.position).length() < 8.0:
					(e["node"] as Node3D).position += ((e["node"] as Node3D).position - player.position).normalized() * 6.0
		else:
			_end(false)

func _damage_enemy(e: Dictionary, amount: float, fx: bool = true) -> void:
	var dealt: float = amount * dmg_mult * (1.0 - float(e["armor"]))
	e["hp"] -= dealt
	var n: Node3D = e["node"]
	if fx:
		n.position += (n.position - player.position).normalized() * 0.15
		e["punch"] = 1.0
		vfx.burst("hit", n.position + Vector3(0, 0.8, 0))
	vfx.number(n.position + Vector3(0, 0.8, 0), dealt)
	if e["hp"] <= 0.0:
		_kill(e)

func _kill(e: Dictionary) -> void:
	kills += 1
	var p: Vector3 = (e["node"] as Node3D).position
	var type: String = e["type"]
	_drop("gem", p, ENEMIES[type]["xp"])
	if rng.randf() < 0.02:
		_drop("berry", p, 0)
	if type == "stag":
		_drop("chest", p, 0)
	var big := type == "golem" or type == "stag" or type == "tank"
	vfx.burst("death", p + Vector3(0, 0.6, 0))
	vfx.burst("leaf", p + Vector3(0, 0.6, 0))
	if big:
		vfx.ring(p, 0.5, 7.0 if type == "stag" else 4.0, 0.6, Color(0.5, 1.0, 0.8, 0.9))
		vfx.flash(p + Vector3(0, 1.5, 0), Color(0.5, 1.0, 0.8), 6.0, 10.0, 0.5)
		vfx.add_shake(0.8 if type == "stag" else 0.45)
	dying.append({"node": e["node"], "t": 0.0, "s0": (e["node"] as Node3D).scale})
	if e == boss:
		boss = {}
	enemies.erase(e)

func _update_dying(delta: float) -> void:
	for i in range(dying.size() - 1, -1, -1):
		var d: Dictionary = dying[i]
		d["t"] += delta
		var k: float = clampf(d["t"] / 0.22, 0.0, 1.0)
		var n: Node3D = d["node"]
		n.scale = (d["s0"] as Vector3) * (1.0 - k * k)
		n.position.y -= delta * 0.8
		if k >= 1.0:
			n.queue_free()
			dying.remove_at(i)

func _nearest(from: Vector3, maxd: float = 1e9) -> Dictionary:
	var best: Dictionary = {}
	var bd := maxd * maxd
	for e in enemies:
		var d := from.distance_squared_to((e["node"] as Node3D).position)
		if d < bd:
			bd = d
			best = e
	return best

# ---------- Waffen ----------
func _update_weapons(delta: float) -> void:
	for id in ["thorn", "acorn"]:
		cd[id] = cd.get(id, 0.0) - delta
	if weapons.has("thorn") and cd["thorn"] <= 0.0:
		var st := Defs.weapon_stats("thorn", weapons["thorn"])
		var t := _nearest(player.position, DART_RANGE)
		if not t.is_empty():
			cd["thorn"] = st["cd"] * cd_mult
			var cnt: int = st["count"]
			var base: Vector3 = (t["node"] as Node3D).position - player.position
			base.y = 0
			for k in cnt:
				var off := (k - (cnt - 1) * 0.5) * 0.18
				_fire_dart(base.normalized().rotated(Vector3.UP, off), st["dmg"], st["pierce"] == "ja")
	if weapons.has("acorn") and cd["acorn"] <= 0.0 and not enemies.is_empty():
		var st2 := Defs.weapon_stats("acorn", weapons["acorn"])
		cd["acorn"] = st2["cd"] * cd_mult
		for k in int(st2["count"]):
			var t2 := _nearest(player.position + Vector3(rng.randf_range(-4, 4), 0, rng.randf_range(-4, 4)), BOMB_RANGE)
			if not t2.is_empty():
				_throw_bomb((t2["node"] as Node3D).position)
	_update_orbs(delta)
	extra.update(delta)

func _fire_dart(dir: Vector3, dmg: float, pierce: bool) -> void:
	cast_t = 0.3
	aim_dir = dir
	aim_t = 0.6
	var n := _make_model("weapons/thorn_dart.glb", Color(0.7, 0.9, 0.5), 0.3)
	vfx.attach_trail(n, Color(0.7, 1.0, 0.45), 0.07, 16, 0.3)
	vfx.glow_sprite(n, Color(0.6, 1.0, 0.4, 0.8), 0.45, Vector3(0, 0.1, 0))
	n.position = player.position + Vector3(0, 1.1, 0) + dir * 0.6
	n.rotation.y = atan2(dir.x, dir.z) + deg_to_rad(FACE_OFFSET)
	add_child(n)
	shots.append({"node": n, "vel": dir * 22.0, "life": (DART_RANGE + 2.0) / 22.0, "dmg": dmg, "pierce": pierce, "hit": []})

func _update_shots(delta: float) -> void:
	for i in range(shots.size() - 1, -1, -1):
		var s: Dictionary = shots[i]
		var n: Node3D = s["node"]
		n.position += s["vel"] * delta
		s["life"] -= delta
		var gone: bool = s["life"] <= 0.0
		if not gone:
			for e in enemies:
				if e in s["hit"]:
					continue
				var en := e["node"] as Node3D
				if (en.position + Vector3(0, 1.0, 0)).distance_to(n.position) < e["r"] + 0.4:
					_damage_enemy(e, s["dmg"])
					s["hit"].append(e)
					if not s["pierce"]:
						gone = true
					break
		if gone:
			n.queue_free()
			shots.remove_at(i)

func _throw_bomb(target: Vector3) -> void:
	cast_t = 0.35
	var tdir := target - player.position
	tdir.y = 0.0
	if tdir.length() > 0.1:
		aim_dir = tdir.normalized()
		aim_t = 0.6
	var n := _make_model("weapons/acorn_bomb.glb", Color(1.0, 0.7, 0.2), 0.4)
	vfx.attach_trail(n, Color(1.0, 0.6, 0.15), 0.12, 18, 0.35)
	n.position = player.position + Vector3(0, 1.2, 0)
	add_child(n)
	bombs.append({"node": n, "from": n.position, "to": target, "t": 0.0, "dur": 0.7})

func _update_bombs(delta: float) -> void:
	for i in range(bombs.size() - 1, -1, -1):
		var b: Dictionary = bombs[i]
		b["t"] += delta
		var k: float = minf(b["t"] / b["dur"], 1.0)
		var p: Vector3 = (b["from"] as Vector3).lerp(b["to"], k)
		p.y += sin(k * PI) * 3.0
		(b["node"] as Node3D).position = p
		(b["node"] as Node3D).rotation.x += delta * 8.0
		if k >= 1.0:
			_explode(b["to"], Defs.weapon_stats("acorn", weapons.get("acorn", 1)))
			(b["node"] as Node3D).queue_free()
			bombs.remove_at(i)

func _explode(pos: Vector3, st: Dictionary) -> void:
	var radius: float = st["radius"] * area_mult
	for e in enemies.duplicate():
		if (e["node"] as Node3D).position.distance_to(pos) < radius + e["r"]:
			_damage_enemy(e, st["dmg"])
	vfx.burst("bomb", pos + Vector3(0, 0.5, 0))
	vfx.ring(pos, 0.3, radius * 1.1, 0.38, Color(1.0, 0.65, 0.2, 1.0))
	_sigil(pos, radius * 1.6, 0.6)
	vfx.flash(pos + Vector3(0, 1.0, 0), Color(1.0, 0.65, 0.25), 7.0, radius * 3.0, 0.35)
	vfx.add_shake(0.3)

func _update_blasts(delta: float) -> void:
	for i in range(blasts.size() - 1, -1, -1):
		var b: Dictionary = blasts[i]
		b["life"] -= delta
		if b["life"] <= 0.0:
			(b["node"] as Node3D).queue_free()
			blasts.remove_at(i)

func _make_orb() -> Node3D:
	if _scene_or_null(M + "items/spirit_wisp.glb") != null:
		var w := _make_model("items/spirit_wisp.glb", Color(0.3, 1.0, 0.9), 0.5)
		w.position.y = -0.25   # Mittelpunkt auf die Bahnhöhe
		var holder := Node3D.new()
		holder.add_child(w)
		return holder
	var mi := MeshInstance3D.new()   # Rückfall: leuchtende Kugel
	var sph := SphereMesh.new()
	sph.radius = 0.22
	sph.height = 0.44
	mi.mesh = sph
	mi.material_override = _glow_mat(Color(0.3, 1.0, 0.9))
	return mi

# Runen-Siegel am Boden: taucht auf, dreht sich, versinkt wieder
func _sigil(pos: Vector3, diameter: float, dur: float) -> void:
	if _scene_or_null(M + "decor/rune_sigil.glb") == null:
		return
	var n := _make_model("decor/rune_sigil.glb", Color.WHITE, 3.0)
	n.position = Vector3(pos.x, -0.3, pos.z)
	n.scale = Vector3(1, 0.3, 1) * (diameter / 3.0) * 0.6
	add_child(n)
	# fast durchsichtig: additiv, geringe Deckkraft, ohne Schatten
	var mats: Array = []
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for si in (mi as MeshInstance3D).mesh.get_surface_count():
			var m := (mi as MeshInstance3D).get_active_material(si)
			if m is StandardMaterial3D:
				var d := (m as StandardMaterial3D).duplicate() as StandardMaterial3D
				d.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				d.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
				d.albedo_color = Color(1, 1, 1, 0.0)
				(mi as MeshInstance3D).set_surface_override_material(si, d)
				mats.append(d)
	sigils.append({"node": n, "t": 0.0, "dur": dur, "d": diameter, "mats": mats})

func _update_sigils(delta: float) -> void:
	for i in range(sigils.size() - 1, -1, -1):
		var g: Dictionary = sigils[i]
		g["t"] += delta
		var k: float = clampf(g["t"] / g["dur"], 0.0, 1.0)
		var n: Node3D = g["node"]
		var rise := clampf(k / 0.2, 0.0, 1.0)
		var sink := clampf((k - 0.65) / 0.35, 0.0, 1.0)
		n.position.y = lerpf(-0.3, 0.02, rise)
		var alpha := SIGIL_ALPHA * clampf(k / 0.15, 0.0, 1.0) * (1.0 - sink)
		for m in g["mats"]:
			(m as StandardMaterial3D).albedo_color = Color(1, 1, 1, alpha)
		n.scale = Vector3(1, 0.3, 1) * (g["d"] / 3.0) * lerpf(0.6, 1.0, 1.0 - pow(1.0 - rise, 3.0))
		n.rotation.y += delta * 1.6
		if k >= 1.0:
			n.queue_free()
			sigils.remove_at(i)

func _update_orbs(delta: float) -> void:
	var lvl: int = weapons.get("orbs", 0)
	if lvl <= 0:
		return
	var st := Defs.weapon_stats("orbs", lvl)
	var cnt_w: int = st["count"]
	if orb_root.get_child_count() != cnt_w:
		for c in orb_root.get_children():
			c.queue_free()
		for k in cnt_w:
			var orb := _make_orb()
			orb_root.add_child(orb)
			vfx.glow_sprite(orb, Color(0.3, 1.0, 0.9, 0.55), 0.95, Vector3(0, 0.25, 0))
			vfx.attach_trail(orb, Color(0.35, 1.0, 0.9), 0.14, 22, 0.4)
	orb_angle += delta * st["speed"]
	var cnt := orb_root.get_child_count()
	var radius: float = st["radius"] * area_mult
	for k in cnt:
		var a := orb_angle + TAU * k / cnt
		var c := orb_root.get_child(k) as Node3D
		if c == null or c.is_queued_for_deletion():
			continue
		c.position = Vector3(cos(a), 0, sin(a)) * radius + Vector3(0, 1.0, 0)
		c.rotation.y = atan2(-sin(a), cos(a))   # Wisp schaut in Flugrichtung
		for e in enemies.duplicate():
			var ep := (e["node"] as Node3D).position + Vector3(0, 0.8, 0)
			if ep.distance_to(c.global_position) < e["r"] + 0.3:
				if e.get("orb_cd", 0.0) <= time:
					e["orb_cd"] = time + 0.4
					_damage_enemy(e, st["dmg"])

# ---------- Pickups ----------
func _drop(kind: String, pos: Vector3, value: int) -> void:
	var n: Node3D
	match kind:
		"gem": n = _make_model("items/spirit_gem.glb", Color(0.3, 1.0, 0.9), 0.25)
		"berry": n = _make_model("items/heart_berry.glb", Color(0.9, 0.2, 0.2), 0.3)
		_: n = _make_model("items/rune_chest.glb", Color(0.6, 0.4, 0.2), 0.9)
	n.position = Vector3(pos.x, 0.3, pos.z)
	add_child(n)
	var gcol := Color(0.3, 1.0, 0.9, 0.8) if kind == "gem" else (Color(1.0, 0.3, 0.3, 0.8) if kind == "berry" else Color(1.0, 0.8, 0.3, 0.8))
	vfx.glow_sprite(n, gcol, 0.9 if kind == "gem" else 1.6, Vector3(0, 0.15, 0))
	pickups.append({"node": n, "kind": kind, "value": value, "pulled": false, "t0": rng.randf() * TAU})

func _update_pickups(delta: float) -> void:
	for i in range(pickups.size() - 1, -1, -1):
		var p: Dictionary = pickups[i]
		var n: Node3D = p["node"]
		var d := n.position.distance_to(player.position + Vector3(0, 0.3, 0))
		n.rotation.y += delta * 2.0
		if not p["pulled"]:
			n.position.y = 0.3 + sin(time * 3.0 + p["t0"]) * 0.06
		if d < magnet or p["pulled"]:
			if not p["pulled"]:
				vfx.attach_trail(n, Color(0.4, 1.0, 1.0), 0.09, 10, 0.25)
			p["pulled"] = true
			n.position = n.position.move_toward(player.position + Vector3(0, 0.5, 0), (8.0 + 12.0 / maxf(d, 0.5)) * delta)
		if d < 0.7:
			vfx.burst("heal" if p["kind"] == "berry" else "gem", player.position + Vector3(0, 0.8, 0))
			match p["kind"]:
				"gem":
					xp += int(ceil(p["value"] * xp_mult))
					if xp >= xp_next:
						xp -= xp_next
						level += 1
						xp_next = int(xp_next * 1.35) + 3
						n.queue_free()
						pickups.remove_at(i)
						_level_up()
						return
				"berry":
						hp = minf(max_hp, hp + 25.0)
						vfx.number(player.position + Vector3(0, 0.8, 0), 25.0, Color(0.5, 1.0, 0.5))
				"chest":
					_level_up()
			n.queue_free()
			pickups.remove_at(i)
			return

# ---------- Passive ----------
func pl(id: String) -> int:
	return int(passives.get(id, 0))

func apply_passives() -> void:
	dmg_mult = 1.0 + 0.05 * pl("might") + meta_dmg
	speed = base_speed * (1.0 + 0.04 * pl("swift"))
	var new_max := 100.0 + 10.0 * pl("vigor") + meta_hp
	if new_max > max_hp:
		hp += new_max - max_hp
	max_hp = new_max
	magnet = base_magnet * (1.0 + 0.15 * pl("magnet"))
	cd_mult = maxf(0.4, 1.0 - 0.04 * pl("haste"))
	area_mult = 1.0 + 0.06 * pl("area")
	regen = 0.25 * pl("regen")
	xp_mult = 1.0 + 0.06 * pl("greed") + meta_xp

# ---------- Level-Up ----------
func _make_cards() -> Array:
	var pool := []
	for id in Defs.WEAPONS:
		var l: int = weapons.get(id, 0)
		if l >= Defs.WEAPONS[id]["max"] or (l == 0 and weapons.size() >= Defs.MAX_WEAPONS):
			continue
		pool.append({"kind": "weapon", "id": id, "lvl": l})
	for id in Defs.PASSIVES:
		var l2: int = passives.get(id, 0)
		if l2 >= Defs.PASSIVES[id]["max"] or (l2 == 0 and passives.size() >= Defs.MAX_PASSIVES):
			continue
		pool.append({"kind": "passive", "id": id, "lvl": l2})
	pool.shuffle()
	var out := pool.slice(0, 3)
	if out.is_empty():
		out.append({"kind": "heal", "id": "vigor", "lvl": 0})
	return out

func _card_title(c: Dictionary) -> String:
	match c["kind"]:
		"weapon": return Defs.WEAPONS[c["id"]]["name"]
		"passive": return Defs.PASSIVES[c["id"]]["name"]
	return "Rast im Moos"

func _card_lines(c: Dictionary) -> Array:
	match c["kind"]:
		"weapon":
			var lines: Array = Defs.weapon_diff_lines(c["id"], c["lvl"])
			if c["lvl"] == 0:
				lines.push_front(Defs.WEAPONS[c["id"]]["desc"])
			return lines
		"passive":
			var d: Dictionary = Defs.PASSIVES[c["id"]]
			return [d["desc"]]
	return ["Heilt 40 Leben"]

func _apply_card(c: Dictionary) -> void:
	match c["kind"]:
		"weapon":
			weapons[c["id"]] = c["lvl"] + 1
		"passive":
			passives[c["id"]] = c["lvl"] + 1
			apply_passives()
		"heal":
			hp = minf(max_hp, hp + 40.0)
	_refresh_slots()

func _pips(l: int, mx: int) -> String:
	var t := ""
	for i in mx:
		t += "●" if i < l else "○"
	return t

func _build_card(c: Dictionary, idx: int) -> Control:
	var is_w: bool = c["kind"] == "weapon"
	var accent: Color = Icon.ACCENTS.get(c["id"], Color(0.8, 0.9, 0.9))
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(330, 480)
	var base_style := _sb(Color(0.05, 0.1, 0.1, 1), Color(accent.r, accent.g, accent.b, 0.55), 16, 2)
	var hover_style := _sb(Color(0.09, 0.18, 0.18, 1), accent, 16, 3)
	panel.add_theme_stylebox_override("panel", base_style)
	var pad := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 22)
	panel.add_child(pad)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	pad.add_child(v)
	var top := HBoxContainer.new()
	var kind_l := _label("WAFFE" if is_w else ("PASSIV" if c["kind"] == "passive" else "ERHOLUNG"), 20, Color(accent.r, accent.g, accent.b, 0.9))
	top.add_child(kind_l)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(sp)
	var badge := _label("NEU" if c["lvl"] == 0 and c["kind"] != "heal" else "Stufe %d" % (c["lvl"] + 1), 20, Color(1, 0.9, 0.5) if c["lvl"] == 0 else Color(0.7, 0.8, 0.8))
	top.add_child(badge)
	v.add_child(top)
	var plate := PanelContainer.new()
	plate.add_theme_stylebox_override("panel", _sb(Color(accent.r * 0.12, accent.g * 0.12, accent.b * 0.12, 1), Color(accent.r, accent.g, accent.b, 0.3), 12, 1))
	var ic := Icon.make(c["id"], 150)
	var ic_c := CenterContainer.new()
	ic_c.custom_minimum_size = Vector2(0, 170)
	ic_c.add_child(ic)
	plate.add_child(ic_c)
	v.add_child(plate)
	var title := _label(_card_title(c), 32, Color(1, 1, 1))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	if c["kind"] != "heal":
		var mx: int = Defs.WEAPONS[c["id"]]["max"] if is_w else Defs.PASSIVES[c["id"]]["max"]
		var pips := _label(_pips(c["lvl"] + 1, mx), 22, accent)
		pips.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(pips)
	for line in _card_lines(c):
		var ll := _label(line, 22, Color(0.9, 0.95, 0.95))
		ll.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ll.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ll.custom_minimum_size = Vector2(280, 0)
		v.add_child(ll)
	var keyl := _label("Taste %d" % (idx + 1), 18, Color(0.6, 0.7, 0.7))
	keyl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	keyl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	keyl.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	v.add_child(keyl)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.mouse_entered.connect(func(): panel.add_theme_stylebox_override("panel", hover_style))
	panel.mouse_exited.connect(func(): panel.add_theme_stylebox_override("panel", base_style))
	panel.gui_input.connect(func(ev: InputEvent):
		var mbe := ev as InputEventMouseButton
		if mbe != null and mbe.pressed and mbe.button_index == MOUSE_BUTTON_LEFT:
			_pick(idx))
	return panel

func _level_up() -> void:
	mouse_down = false
	has_target = false
	vfx.burst("level", player.position + Vector3(0, 0.8, 0))
	vfx.ring(player.position, 0.5, 6.5, 0.7, Color(0.5, 1.0, 0.9, 1.0))
	_sigil(player.position, 4.2, 1.1)
	vfx.ring(player.position, 0.2, 4.0, 0.5, Color(1.0, 0.9, 0.5, 0.8))
	vfx.flash(player.position + Vector3(0, 1.5, 0), Color(0.6, 1.0, 0.9), 6.0, 12.0, 0.6)
	cards = _make_cards()
	for c in choice_box.get_children():
		c.queue_free()
	var head := _label("Stufe %d" % level, 44, Color(0.75, 1.0, 0.95))
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	choice_box.add_child(head)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 26)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	choice_box.add_child(row)
	choice_actions.clear()
	for k in cards.size():
		var card: Dictionary = cards[k]
		choice_actions.append(func(): _apply_card(card))
		row.add_child(_build_card(card, k))
	choice_layer.visible = true
	get_tree().paused = true

# ---------- Props (Wald) ----------
func _cell_hash(cx: int, cz: int) -> int:
	return int(absi((cx * 73856093) ^ (cz * 19349663)))

func _update_props() -> void:
	const CELL := 7.0
	var pcx := int(floor(player.position.x / CELL))
	var pcz := int(floor(player.position.z / CELL))
	for cx in range(pcx - 6, pcx + 7):
		for cz in range(pcz - 6, pcz + 7):
			var key := Vector2i(cx, cz)
			if props.has(key):
				continue
			var h := _cell_hash(cx, cz)
			var list: Array = []
			if h % 100 < 55 and (absi(cx) + absi(cz)) > 1:  # Startbereich frei
				var r := float((h / 100) % 100) / 100.0
				var pt: Array = (lv["props"] as Array)[0]
				var acc := 0.0
				for t in (lv["props"] as Array):
					acc += t[1]
					if r * 1.0 <= acc:
						pt = t
						break
				var n := _make_model(pt[0], pt[2], pt[3])
				n.position = Vector3((cx + float((h / 7) % 100) / 100.0) * CELL, 0, (cz + float((h / 13) % 100) / 100.0) * CELL)
				n.rotation.y = float((h / 17) % 360) * PI / 180.0
				n.scale = Vector3.ONE * (0.85 + float((h / 19) % 40) / 100.0)
				add_child(n)
				list.append(n)
			props[key] = list
	for key in props.keys():
		if absi(key.x - pcx) > 8 or absi(key.y - pcz) > 8:
			for n in props[key]:
				n.queue_free()
			props.erase(key)

# ---------- UI / Ende ----------
func _refresh_slots() -> void:
	if slot_box == null:
		return
	for c in slot_box.get_children():
		c.queue_free()
	var rows := [["weapon", weapons], ["passive", passives]]
	var y := 0.0
	for r in rows:
		var x := 0.0
		for id in (r[1] as Dictionary):
			var slot := PanelContainer.new()
			slot.position = Vector2(x, y)
			slot.custom_minimum_size = Vector2(54, 54)
			var acc: Color = Icon.ACCENTS.get(id, Color(0.8, 0.9, 0.9))
			slot.add_theme_stylebox_override("panel", _sb(Color(0.03, 0.07, 0.07, 0.8), Color(acc.r, acc.g, acc.b, 0.6), 8, 1))
			var holder := Control.new()
			holder.custom_minimum_size = Vector2(54, 54)
			var ic := Icon.make(id, 42)
			ic.position = Vector2(6, 4)
			holder.add_child(ic)
			var lv := _label(str(r[1][id]), 18, Color(1, 0.95, 0.7))
			lv.position = Vector2(34, 30)
			holder.add_child(lv)
			slot.add_child(holder)
			slot_box.add_child(slot)
			x += 60.0
		y += 60.0

func _show_banner(text: String) -> void:
	banner.text = text
	banner_t = 3.0

func _update_ui() -> void:
	vfx.set_low_hp(hp < max_hp * 0.3, hp / maxf(max_hp, 1.0))
	hp_bar.max_value = max_hp
	hp_bar.value = hp
	xp_bar.max_value = xp_next
	xp_bar.value = xp
	var left := int(win_time - time)
	timer_label.text = "%02d:%02d" % [left / 60, left % 60]
	level_label.text = "Lv %d" % level
	info.text = "Kills %d   ·   %d / %d Leben" % [kills, int(hp), int(max_hp)]
	banner_t = maxf(0.0, banner_t - get_process_delta_time())
	banner.modulate.a = clampf(banner_t / 0.6, 0.0, 1.0) * clampf((3.0 - banner_t) / 0.3, 0.0, 1.0)
	boss_box.visible = not boss.is_empty()
	if not boss.is_empty():
		boss_bar.max_value = boss["max"]
		boss_bar.value = boss["hp"]

func _end(victory: bool) -> void:
	if dead or won:
		return
	dead = not victory
	won = victory
	var earned := Meta.finish_run(time, kills, level, victory)
	var cc: Control = end_layer.get_child(1)
	for c in cc.get_children():
		c.queue_free()
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _sb(Color(0.04, 0.09, 0.09, 0.97), Color(0.4, 0.9, 0.8, 0.7), 16, 2))
	var pad := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 40)
	panel.add_child(pad)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 18)
	pad.add_child(v)
	var t := _label("Der Wald ist gerettet!" if victory else "Der Wald verschlingt dich ...", 56, Color(1, 0.95, 0.8))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var st := _label("Überlebt %02d:%02d   ·   Stufe %d   ·   %d Kills" % [int(time) / 60, int(time) % 60, level, kills], 30, Color(0.85, 0.95, 0.95))
	st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(st)
	var sh := _label("+ %d Wurzelsplitter" % earned, 44, Color(1.0, 0.85, 0.4))
	sh.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sh)
	var tot := _label("Vorrat: %d  (im Hauptmenü unter „Verstärkungen“ ausgeben)" % Meta.shards, 22, Color(0.7, 0.8, 0.8))
	tot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(tot)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var b1 := MenuUI.btn("Nochmal  (Enter)", Vector2(300, 68), 28)
	b1.pressed.connect(_restart_run)
	var b2 := MenuUI.btn("Hauptmenü", Vector2(260, 68), 28)
	b2.pressed.connect(_to_menu)
	var b3 := MenuUI.btn("Beenden", Vector2(220, 68), 28, Color(1.0, 0.5, 0.45))
	b3.pressed.connect(func(): get_tree().quit())
	row.add_child(b1)
	row.add_child(b2)
	row.add_child(b3)
	v.add_child(row)
	cc.add_child(panel)
	end_layer.visible = true

func _restart_run() -> void:
	get_tree().paused = false
	Meta.in_menu = false
	get_tree().reload_current_scene()

func _to_menu() -> void:
	get_tree().paused = false
	Meta.in_menu = true
	get_tree().reload_current_scene()

func _abandon() -> void:
	Meta.finish_run(time, kills, level, false)
	_to_menu()

# ---------- Hauptmenü-Modus ----------
func _enter_menu_mode() -> void:
	for n in [hp_bar, level_label, info, xp_bar, timer_label, boss_box, slot_box, banner]:
		(n as Control).visible = false
	menu = MenuUI.new()
	ui.add_child(menu)
	menu.start_run.connect(func(id: String):
		Meta.level_id = id
		Meta.in_menu = false
		get_tree().reload_current_scene())
	menu.quit_game.connect(func(): get_tree().quit())
	cam.position = player.position + Vector3(0, 3.2, 8.5)
	if OS.has_environment("WW_SHARDS"):
		Meta.shards = int(OS.get_environment("WW_SHARDS"))   # nur Test, wird nicht gespeichert
	if OS.has_environment("WW_SCREEN"):
		menu._show(OS.get_environment("WW_SCREEN"))

func _process_menu(delta: float) -> void:
	time += delta
	menu_t += delta
	moving = false
	_animate_player(delta)
	var a := menu_t * 0.12
	var target := player.position + Vector3(sin(a) * 8.5, 3.0 + sin(menu_t * 0.2) * 0.5, cos(a) * 8.5)
	cam.position = cam.position.lerp(target, 0.08)
	cam.look_at(player.position + Vector3(0, 1.1, 0))
	var mdl := player.get_node("Model") as Node3D
	face_yaw = lerp_angle(face_yaw, atan2(sin(a), cos(a)) + 0.5, 1.0 - exp(-3.0 * delta))
	mdl.rotation.y = face_yaw
	_update_props()
	vfx.follow(player.position)

