extends Node3D
## Wyrdwood Survivors: Vampire-Survivors-artiges Spiel in 3D (Top-Down) mit Dark-Fairytale-Setting.

const M := "res://models/"
# Spielfiguren (Skins, Wahl in den Optionen -> Meta.skin, Test: WW_SKIN): Clip-Animationen aus UniMate
# (idle/walk/run/cast/hit[/hit2]/die, 22 Knochen, schauen nach +Z). upper = Oberkörper-Knochen (Wirbel 2-3, Hals, Kopf,
# beide Arme) für hit über dem Laufzyklus; cast nimmt upper ohne spine (nur Arme/Hals/Kopf), sonst kippt der Rumpf
# bei jedem Schuss weg (Zauber-Clip der alten Elfe beugt Wirbel 2 bis 45°). feet = Fußknochen: die Figur wird so
# nachgeführt, dass die Mitte zwischen den Füßen auf dem Drehpunkt bleibt (Idle/Cast stehen 10-15 cm neben der Hüfte,
# sonst wandert sie beim Umdrehen zum Ziel auf einem Kreis). Die Rigs sind unterschiedlich nummeriert.
# Fehlt die Datei, kommt die alte T-Pose-Elfe mit der prozeduralen Animation (_animate_player).
const SKINS := {
	"druid": {"glb": "res://rigged/elf_druid_anim.glb", "upper": ["bone_2", "bone_3", "bone_4", "bone_5",
		"bone_6", "bone_7", "bone_8", "bone_9", "bone_25", "bone_26", "bone_27", "bone_28"], "spine": ["bone_2", "bone_3"], "feet": ["bone_46", "bone_50"],
		"walk_speed": 1.6, "run_speed": 2.7},
	"classic": {"glb": "res://rigged/elf_old_anim.glb", "upper": ["bone_2", "bone_3", "bone_4", "bone_5",
		"bone_7", "bone_8", "bone_9", "bone_10", "bone_26", "bone_27", "bone_28", "bone_29"], "spine": ["bone_2", "bone_3"], "feet": ["bone_47", "bone_51"],
		"walk_speed": 0.8, "run_speed": 2.2},   # run = Jogging-Clip (aufrechter als ihr Renn-Clip)
}
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
var bot := OS.has_environment("WW_BOT")
var sim := {"dealt": 0.0, "taken": 0.0, "min": -1, "low_hp": 1.0, "src": {}}
var bonus_shards := 0        # Splitterbeutel aus Level-Ups (kommt am Ende zur Belohnung)
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
# 8 Zoomstufen (geometrisch, gleich große Sprünge): 50 % näher bis 30 % weiter weg; Index 5 = Standard (1.0).
# Reine Kamera-Sache: Spawns, Reichweiten usw. hängen nicht vom Zoom ab.
const ZOOM_STEPS := [0.5, 0.58, 0.67, 0.77, 0.88, 1.0, 1.14, 1.3]
var zoom_idx := 5
# Reichweiten: alles auf den sichtbaren Bereich (Zoom 1: ~12 m seitlich, 9 m nach oben, 5 m nach unten) abgestimmt
const DART_RANGE := 12.0   # Reichweite Dornenpfeil (Zielsuche und Flugweite)
const BOMB_RANGE := 10.0
const SIGIL_ALPHA := 0.22   # Deckkraft des Runen-Siegels (fast durchsichtig)
var view_rigs: Array = []
var vfx: Vfx
var lantern: OmniLight3D
const LANTERN_E := 3.6   # Grundhelligkeit der Laterne
var step_acc := 0.0
var stuck_t := 0.0
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
var cast_kind := "throw"   # throw | lob | slam | sweep | point | cheer
var cast_dur := 0.3
var death_t := -1.0         # >= 0: Fallanimation läuft
var yaw_vel := 0.0          # Drehgeschwindigkeit der Figur (für das Einlehnen in Kurven)
var stance_k := 0.0
var hit_t := 0.0
var moving := false
var vel := Vector3.ZERO     # geglättete Laufgeschwindigkeit (Beschleunigung/Abbremsen)
var cur_speed := 0.0        # tatsächliches Lauftempo (m/s) für die Clip-Wiedergabe
var anim_tree: AnimationTree    # gesetzt = Clip-Animation (PLAYER_ANIMATED), sonst prozedural
var anim_player: AnimationPlayer
const ARM_DOWN := 1.15
# Clip-Tempo am Boden (m/s bei Wiedergabe 1.0, aus der Wurzelbewegung der UniMate-Clips, pro Skin in SKINS):
# run wird auf das Spieltempo beschleunigt, damit die Füße nicht rutschen.
var clip_walk_speed := 1.6
var clip_run_speed := 2.7

var enemies: Array = []     # Dictionary: node, type, hp, spd, dmg, flash
var pickups: Array = []     # Dictionary: node, kind
var shots: Array = []       # Dictionary: node, vel, life, dmg, pierce
var bombs: Array = []       # Dictionary: node, from, to, t, dur
var blasts: Array = []      # Dictionary: node, life
var props := {}             # Zellen-Key -> Array[Node3D]
var prop_cols := {}         # Zellen-Key -> Array[[Vector3 Mitte, Radius]] (Kollision)

# Waffen: Level 0 = nicht vorhanden
var weapons := {"thorn": 1}      # besessene Waffen -> Stufe
var passives := {}               # besessene Passive -> Stufe
var cd := {}
var base_speed := 5.0
var base_magnet := 3.0
var cd_mult := 1.0
var area_mult := 1.0
var xp_mult := 1.0
var armor_mult := 1.0
var dodge_chance := 0.0
var crit_chance := 0.0
var proj_bonus := 0          # Zwillingssaat: +Geschosse
var regen := 0.0
var meta_dmg := 0.0              # dauerhafte Boni (Meta-Fortschritt)
var meta_hp := 0.0
var extra: WeaponsExtra
var more: WeaponsMore
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
	if bot:   # Balancing-Simulation: direkt ins Spiel, Meta-Stufen aus WW_META (z. B. "m_dmg:5,m_hp:5"), sonst ohne
		Meta.in_menu = false
		Meta.upgrades = {}
		if OS.has_environment("WW_META"):
			for pair in OS.get_environment("WW_META").split(","):
				var kv := pair.split(":")
				Meta.upgrades[kv[0]] = int(kv[1])
		if OS.has_environment("WW_SEED"):
			seed(int(OS.get_environment("WW_SEED")))
			rng.seed = int(OS.get_environment("WW_SEED"))
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
	_setup_pad()
	_setup_quality()
	_setup_world()
	_setup_player()
	_setup_ui()
	vfx = Vfx.new()
	add_child(vfx)
	vfx.setup(cam, ui)
	if lv.has("embers"):   # Schwebeteilchen in Level-Farbe (Totenacker: Glut/Asche)
		var ec: Color = lv["embers"]
		(vfx.motes.process_material as ParticleProcessMaterial).color_ramp = vfx._ramp([Color(ec.r, ec.g, ec.b, 0.0), Color(ec.r, ec.g, ec.b, 0.9), Color(0.4, 0.35, 0.35, 0.0)], [0.0, 0.4, 1.0])
	extra = WeaponsExtra.new()
	extra.g = self
	more = WeaponsMore.new()
	more.g = self
	apply_passives()
	_refresh_slots()
	if menu_mode:
		_enter_menu_mode()
	if bot and OS.has_environment("WW_W"):
		weapons.clear()
		for pair in OS.get_environment("WW_W").split(","):
			var kv := pair.split(":")
			weapons[kv[0]] = int(kv[1])
		_refresh_slots()
	if bot and OS.has_environment("WW_END"):
		win_time = float(OS.get_environment("WW_END"))
	if OS.has_environment("WW_SHOT"):  # Test: Screenshot nach Vorlauf
		time = float(OS.get_environment("WW_SHOT"))
		cam_zoom = float(OS.get_environment("WW_ZOOM")) if OS.has_environment("WW_ZOOM") else 1.0
		zoom_target = cam_zoom
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
		if OS.has_environment("WW_FACE"):   # Test: Figur seitlich drehen (Grad)
			face_yaw = deg_to_rad(float(OS.get_environment("WW_FACE")))
			(player.get_node("Model") as Node3D).rotation.y = face_yaw
		if OS.has_environment("WW_ZIGZAG"):   # Test: Richtung mehrfach wechseln, danach Kamera-Winkel ausgeben
			for k in 6:
				get_tree().create_timer(0.5 + 0.5 * k).timeout.connect(func():
					_set_move_target(player.position + Vector3(8 * (1 if k % 2 == 0 else -1), 0, 6 * (-1 if k % 3 == 0 else 1)), false))
		if OS.has_environment("WW_CLICK"):
			var xz := OS.get_environment("WW_CLICK").split(",")
			get_tree().create_timer(0.8).timeout.connect(func(): _set_move_target(Vector3(float(xz[0]), 0, float(xz[1])), true))
		if OS.has_environment("WW_NOUI"):   # Test/Vorschaubilder: HUD aus
			ui.visible = false
		if OS.has_environment("WW_PADTEST"):   # Test: Controller-Tasten per Skript, z. B. "1.5:right,1.7:a"
			for step in OS.get_environment("WW_PADTEST").split(","):
				var tb := step.split(":")
				get_tree().create_timer(float(tb[0])).timeout.connect(func():
					var names := {"a": JOY_BUTTON_A, "b": JOY_BUTTON_B, "start": JOY_BUTTON_START, "right": JOY_BUTTON_DPAD_RIGHT, "left": JOY_BUTTON_DPAD_LEFT, "down": JOY_BUTTON_DPAD_DOWN, "up": JOY_BUTTON_DPAD_UP, "lb": JOY_BUTTON_LEFT_SHOULDER}
					for pressed in [true, false]:
						var ev := InputEventJoypadButton.new()
						ev.button_index = names[tb[1]]
						ev.pressed = pressed
						Input.parse_input_event(ev)
					await get_tree().create_timer(0.1).timeout
					print("PAD ", tb[1], " -> paused=", paused_menu, " cards=", choice_layer.visible, " focus=", get_viewport().gui_get_focus_owner(), " weapons=", weapons, " passives=", passives, " zoom=", zoom_target, " screen=", menu.screen if menu != null else "-"))
		if OS.has_environment("WW_HOVER"):   # Test: Maus über den n-ten belegten Platz (Tooltip)
			get_tree().create_timer(1.0).timeout.connect(func():
				var filled := []
				for c in slot_box.get_children():
					if c is PanelContainer and (c as Control).tooltip_text != "":
						filled.append(c)
				var sl: Control = filled[int(OS.get_environment("WW_HOVER"))]
				var sp: Vector2 = get_viewport().get_final_transform() * (sl.get_global_rect().get_center())
				for k in 3:
					var ev := InputEventMouseMotion.new()
					ev.position = sp + Vector2(k, 0)
					ev.global_position = ev.position
					Input.parse_input_event(ev))
		if OS.has_environment("WW_GEMS"):   # Test: Kristalle aller Stufen in einer Reihe (außerhalb der Magnet-Reichweite)
			get_tree().create_timer(0.3).timeout.connect(func():
				var vals := [1, 2, 5, 8, 20, 100]
				for gi in vals.size():
					_drop("gem", player.position + Vector3(-5.0 + gi * 2.0, 0, -3.3), vals[gi])
					_drop("gem", player.position + Vector3(-5.0 + gi * 2.0, 0, -4.6), vals[gi]))
		if OS.has_environment("WW_FIREWORK"):   # Test: Kisten-Feuerwerk ohne Level-Up-Menü
			get_tree().create_timer(0.5).timeout.connect(func():
				vfx.firework(player.position, 7, ["gold", "violet", "teal", "pink", "green"], 6.5)
				vfx.pillar(player.position, Color(1.0, 0.85, 0.4), 1.8))
		if OS.has_environment("WW_LEVELUP"):
			if OS.has_environment("WW_CLICKCARD"):   # Test: Mausklick mitten aufs Bild der 2. Karte
				get_tree().create_timer(1.8).timeout.connect(func():
					var icons := choice_box.find_children("*", "Icon", true, false)
					var r: Rect2 = (icons[1] as Control).get_global_rect()
					for pressed in [true, false]:
						var ev := InputEventMouseButton.new()
						ev.button_index = MOUSE_BUTTON_LEFT
						ev.pressed = pressed
						var sp: Vector2 = get_viewport().get_final_transform() * r.get_center()
						ev.position = sp
						ev.global_position = sp
						Input.parse_input_event(ev)
					get_tree().create_timer(0.2).timeout.connect(func(): print("CLICKTEST weapons=", weapons, " passives=", passives, " layer_visible=", choice_layer.visible)))
			get_tree().create_timer(1.2).timeout.connect(_level_up)
		get_tree().create_timer(float(OS.get_environment("WW_T")) if OS.has_environment("WW_T") else 6.0).timeout.connect(func():
			print("FPS ", Engine.get_frames_per_second(), " lv=", level, " xp=", xp, "/", xp_next,  " enemies=", enemies.size(), " player=", player.position.snapped(Vector3(0.1, 0.1, 0.1)), " target=", has_target, move_target.snapped(Vector3(0.1, 0.1, 0.1)), " cam_rot=", cam.rotation_degrees.snapped(Vector3(0.01, 0.01, 0.01)), " mitte=", (_ground_at(get_viewport().get_visible_rect().size / 2.0) as Vector3).snapped(Vector3(0.1, 0.1, 0.1)))
			get_viewport().get_texture().get_image().save_png(OS.get_environment("WW_OUT"))
			get_tree().quit())

# ---------- Aufbau ----------
# Xbox-Controller: Standard-UI-Aktionen um Controller-Tasten ergänzen (falls Godot sie nicht schon hat)
func _setup_pad() -> void:
	var add := func(action: String, ev: InputEvent):
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		if not InputMap.action_has_event(action, ev):
			InputMap.action_add_event(action, ev)
	var jb := func(i: int) -> InputEventJoypadButton:
		var e := InputEventJoypadButton.new()
		e.button_index = i
		return e
	var ja := func(axis: int, v: float) -> InputEventJoypadMotion:
		var e := InputEventJoypadMotion.new()
		e.axis = axis
		e.axis_value = v
		return e
	add.call("ui_accept", jb.call(JOY_BUTTON_A))
	add.call("ui_cancel", jb.call(JOY_BUTTON_B))
	add.call("ui_up", jb.call(JOY_BUTTON_DPAD_UP))
	add.call("ui_down", jb.call(JOY_BUTTON_DPAD_DOWN))
	add.call("ui_left", jb.call(JOY_BUTTON_DPAD_LEFT))
	add.call("ui_right", jb.call(JOY_BUTTON_DPAD_RIGHT))
	add.call("ui_up", ja.call(JOY_AXIS_LEFT_Y, -1.0))
	add.call("ui_down", ja.call(JOY_AXIS_LEFT_Y, 1.0))
	add.call("ui_left", ja.call(JOY_AXIS_LEFT_X, -1.0))
	add.call("ui_right", ja.call(JOY_AXIS_LEFT_X, 1.0))
	add.call("pad_pause", jb.call(JOY_BUTTON_START))
	add.call("zoom_in", jb.call(JOY_BUTTON_LEFT_SHOULDER))
	add.call("zoom_out", jb.call(JOY_BUTTON_RIGHT_SHOULDER))

func _set_pause(on: bool) -> void:
	paused_menu = on
	pause_box.visible = on
	get_tree().paused = on
	if on:
		MenuUI.focus_first(pause_box)
	else:
		get_viewport().gui_release_focus()

func _set_zoom_idx(i: int) -> void:
	zoom_idx = clampi(i, 0, ZOOM_STEPS.size() - 1)
	zoom_target = ZOOM_STEPS[zoom_idx]

func _setup_quality() -> void:
	# UI skaliert über canvas_items-Stretch (Basis 1920x1080). 3D-Last nach echter Pixelzahl:
	# 4K -> FSR2 mit 67 % Renderauflösung, 1440p -> nativ, 1080p -> nativ.
	Meta.apply_quality(get_viewport())


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
	"characters/elfe_mit_langen.glb": 1.75, "res://rigged/elf_druid_anim.glb": 1.75, "res://rigged/elf_old_anim.glb": 1.75,
	"items/spirit_gem.glb": 0.25, "items/heart_berry.glb": 0.3, "items/rune_chest.glb": 0.9,
	"weapons/thorn_dart.glb": 0.6, "weapons/acorn_bomb.glb": 0.4,
	"nature/gnarled_tree.glb": 5.0, "nature/mossy_boulder.glb": 1.8, "nature/glow_mushrooms.glb": 0.9,
	"structures/standing_stone.glb": 3.0, "weapons/moon_scythe.glb": 0.9,
	"items/spirit_wisp.glb": 0.5, "props/rune_sigil.glb": 3.0,
	# Totenacker
	"nature/dead_oak.glb": 4.5, "structures/crooked_gravestone.glb": 1.3, "props/bone_pile.glb": 1.0,
	"props/grave_candles.glb": 0.6, "structures/broken_crypt.glb": 4.0,
	"nature/bramble_hedge.glb": 4.0, "structures/graveyard_fence.glb": 4.0,
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
	var s := _scene_or_null(rel if rel.begins_with("res://") else M + rel)
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

# Platzhalter einfärben: Multiplikations-Overlay über alle Meshes
func _tint_model(n: Node, col: Color) -> void:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_MUL
	m.albedo_color = col
	for mi in n.find_children("*", "GeometryInstance3D", true, false):
		(mi as GeometryInstance3D).material_overlay = m

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
	env.glow_intensity = 0.6
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 0.9
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.ssao_enabled = true
	env.ssao_radius = 1.6
	env.ssao_intensity = 2.2
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.08
	env.adjustment_saturation = lv["env"].get("saturation", 1.18)
	env.fog_enabled = true
	env.fog_light_color = lv["env"]["fog"]
	env.fog_density = 0.012
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.012
	env.volumetric_fog_albedo = lv["env"]["vfog"]
	env.volumetric_fog_emission = lv["env"].get("vfog_emit", Color(0.01, 0.03, 0.03))
	env.volumetric_fog_length = 50.0
	env.volumetric_fog_temporal_reprojection_enabled = false   # Reprojektion zieht bei Bewegung Geisterbilder durch den Nebel
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -30, 0)
	sun.light_color = lv["env"]["sun"]
	sun.light_energy = lv["env"].get("sun_energy", 1.1)
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
	_build_walls()

func _ground_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.12, 0.2, 0.1)
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3(0.1, 0.1, 0.1)  # 10 m Kachel
	var dir := "res://textures/%s/" % lv.get("ground", "forest_floor")
	for fb in ["forest_floor_v3", "forest_floor"]:   # Platzhalter (ohne Glühpunkte zuerst), bis die Level-Textur da ist
		if DirAccess.open(dir) == null:
			dir = "res://textures/%s/" % fb
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
	var skin_id: String = OS.get_environment("WW_SKIN") if OS.has_environment("WW_SKIN") else Meta.skin
	var skin: Dictionary = SKINS.get(skin_id, SKINS["druid"])
	var animated := ResourceLoader.exists(skin["glb"])
	var mdl := _make_model(skin["glb"] if animated else "characters/elfe_mit_langen.glb", Color(0.8, 0.7, 0.5), 1.7)
	mdl.name = "Model"
	player.add_child(mdl)
	var aps := mdl.find_children("*", "AnimationPlayer", true, false)
	if animated and not aps.is_empty():
		_setup_anim_tree(aps[0], skin)
	else:
		var sks := mdl.find_children("*", "Skeleton3D", true, false)
		if not sks.is_empty():
			skel = sks[0]
	var light := OmniLight3D.new()  # Laterne der Druidin
	lantern = light
	light.light_color = lv.get("lantern", Color(1.0, 0.8, 0.5))
	light.omni_range = 12.0
	light.light_energy = LANTERN_E
	light.position = Vector3(0, 2.0, 0)
	player.add_child(light)
	orb_root = Node3D.new()
	player.add_child(orb_root)

# ---------- Clip-Animation (Skins aus SKINS) ----------
# Baum: Laufzyklus (BlendSpace1D idle/walk/run nach Tempo, Zeitskala gegen Fußrutschen) -> OneShot hit -> OneShot cast.
# Die OneShots sind auf den Oberkörper gefiltert, die Beine laufen beim Zaubern weiter. Tod: Baum aus, "die" ganz.
func _setup_anim_tree(ap: AnimationPlayer, skin: Dictionary) -> void:
	anim_player = ap
	clip_walk_speed = skin["walk_speed"]
	clip_run_speed = skin["run_speed"]
	var sks := ap.get_parent().find_children("*", "Skeleton3D", true, false)
	if not sks.is_empty():
		clip_skel = sks[0]
		clip_feet = [clip_skel.find_bone(skin["feet"][0]), clip_skel.find_bone(skin["feet"][1])]
	for a in ["idle", "walk", "run"]:
		if ap.has_animation(a):
			ap.get_animation(a).loop_mode = Animation.LOOP_LINEAR
	var bt := AnimationNodeBlendTree.new()
	var loco := AnimationNodeBlendSpace1D.new()
	loco.min_space = 0.0
	loco.max_space = clip_run_speed
	for pair in [["idle", 0.0], ["walk", clip_walk_speed], ["run", clip_run_speed]]:
		var an := AnimationNodeAnimation.new()
		an.animation = pair[0]
		loco.add_blend_point(an, pair[1], -1, pair[0])
	bt.add_node("loco", loco)
	bt.add_node("loco_speed", AnimationNodeTimeScale.new())
	bt.connect_node("loco_speed", 0, "loco")
	var prev := "loco_speed"
	for a in ["hit", "cast"]:
		var clip := AnimationNodeAnimation.new()
		clip.animation = a
		var shot := AnimationNodeOneShot.new()
		shot.fadein_time = 0.12
		shot.fadeout_time = 0.25
		shot.filter_enabled = true
		var anim := ap.get_animation(a)
		for i in anim.get_track_count():
			var tp := anim.track_get_path(i)
			var bn := tp.get_concatenated_subnames()
			if skin["upper"].has(bn) and not (a == "cast" and skin["spine"].has(bn)):
				shot.set_filter_path(tp, true)
		bt.add_node(a + "_clip", clip)
		bt.add_node(a + "_speed", AnimationNodeTimeScale.new())
		bt.add_node(a, shot)
		bt.connect_node(a + "_speed", 0, a + "_clip")
		bt.connect_node(a, 0, prev)
		bt.connect_node(a, 1, a + "_speed")
		prev = a
	bt.connect_node("output", 0, prev)
	anim_tree = AnimationTree.new()
	ap.get_parent().add_child(anim_tree)
	anim_tree.anim_player = anim_tree.get_path_to(ap)
	anim_tree.tree_root = bt
	anim_tree.set("parameters/hit_speed/scale", 2.0)
	anim_tree.active = true

var loco_pos := 0.0
var clip_dead := false
var clip_skel: Skeleton3D
var clip_feet := [-1, -1]

func _center_on_feet(delta: float) -> void:
	# Fußmitte (waagerecht) auf den Drehpunkt des Modells schieben; im Stand zügig, beim Laufen stark geglättet
	if clip_skel == null or clip_feet[0] < 0 or clip_feet[1] < 0:
		return
	var pivot := player.get_node("Model") as Node3D
	var inst := pivot.get_child(0) as Node3D
	var mid := (clip_skel.global_transform * clip_skel.get_bone_global_pose(clip_feet[0]).origin
		+ clip_skel.global_transform * clip_skel.get_bone_global_pose(clip_feet[1]).origin) * 0.5
	var f := pivot.to_local(mid)
	var k := 1.0 - exp(-(2.0 if moving else 8.0) * delta)
	inst.position.x -= f.x * k
	inst.position.z -= f.z * k
	if OS.has_environment("WW_FEETLOG") and Engine.get_process_frames() % 15 == 0:   # Test: Fußmitte in Welt + Blickwinkel
		print("FEET ", snappedf(mid.x - player.position.x, 0.001), " ", snappedf(mid.z - player.position.z, 0.001), " yaw ", snappedf(rad_to_deg(face_yaw), 1))

func _animate_clips(delta: float) -> void:
	walk_blend = move_toward(walk_blend, 1.0 if moving else 0.0, delta * 7.0)
	anim_t += delta
	cast_t = maxf(0.0, cast_t - delta)
	hit_t = maxf(0.0, hit_t - delta)
	if death_t >= 0.0:
		if not clip_dead:
			clip_dead = true
			anim_tree.active = false
			anim_player.play("die", 0.2)
		death_t += delta
		_death_fx()
		return
	# Tempo -> Mischung idle/walk/run; über dem Clip-Tempo von run schneller abspielen statt rutschen
	loco_pos = lerpf(loco_pos, minf(cur_speed, clip_run_speed), 1.0 - exp(-10.0 * delta))
	anim_tree.set("parameters/loco/blend_position", loco_pos)
	anim_tree.set("parameters/loco_speed/scale", clampf(cur_speed / clip_run_speed, 1.0, 3.2))
	_center_on_feet(delta)
	if hit_t > 0.3 and not anim_tree.get("parameters/hit/active"):
		# zweite Treffer-Variante (hit2), falls der Skin eine hat: zufällig abwechseln
		var clip: AnimationNodeAnimation = (anim_tree.tree_root as AnimationNodeBlendTree).get_node("hit_clip")
		clip.animation = "hit2" if anim_player.has_animation("hit2") and rng.randf() < 0.5 else "hit"
		anim_tree.set("parameters/hit/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)

func _clip_cast(dur: float) -> void:
	if anim_tree == null or clip_dead or anim_tree.get("parameters/cast/active"):
		return      # läuft schon (Dauerfeuer): nicht neu starten, sonst zuckt der Oberkörper
	var len := anim_player.get_animation("cast").length
	anim_tree.set("parameters/cast_speed/scale", clampf(len / maxf(dur * 1.6, 0.7), 0.8, 2.8))
	anim_tree.set("parameters/cast/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)

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

class Rays extends Control:
	var col := Color(1.0, 0.85, 0.45, 0.055)
	var spin := 0.0
	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _process(delta: float) -> void:
		spin += delta * 0.18
		queue_redraw()
	func _draw() -> void:
		var c := size * 0.5
		var r := size.length() * 0.6
		for k in 14:
			var a := spin + TAU * k / 14.0
			var pts := PackedVector2Array([c, c + Vector2(cos(a - 0.07), sin(a - 0.07)) * r, c + Vector2(cos(a + 0.07), sin(a + 0.07)) * r])
			draw_colored_polygon(pts, col)
		draw_circle(c, r * 0.22, Color(col.r, col.g, col.b, col.a * 0.8))

func _ptween() -> Tween:   # Tween, der auch bei pausiertem Spiel läuft (Level-Up)
	return create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)

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
	# Anker UND Abstände setzen: nur set_anchors_preset übernahm die Breite (1920) als rechten Überstand, solange die UI
	# noch Größe 0 hatte -> Balken breiter als der Bildschirm, ab ~70 % sah er voll aus
	xp_bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
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
	choice_panel.add_theme_stylebox_override("panel", _sb(Color(0.04, 0.09, 0.09, 0.96), Color(1.0, 0.82, 0.4, 0.85), 14, 2))
	var pad := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 22)
	choice_panel.add_child(pad)
	choice_box = VBoxContainer.new()
	choice_box.custom_minimum_size = Vector2(770, 0)
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
	var pb1 := MenuUI.btn("Weiter  (Esc / B)", Vector2(420, 66), 30)
	pb1.pressed.connect(func(): _set_pause(false))
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
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		_pad_input(event)
	var mb := event as InputEventMouseButton
	if mb == null:
		return
	if get_tree().paused or menu_mode or dead or won:
		mouse_down = false
		return
	if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
		_set_zoom_idx(zoom_idx - 1)
	elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
		_set_zoom_idx(zoom_idx + 1)
	elif mb.button_index == MOUSE_BUTTON_LEFT or mb.button_index == MOUSE_BUTTON_RIGHT:
		mouse_down = mb.pressed
		if mb.pressed:
			_update_mouse_target(true)

func _pad_input(event: InputEvent) -> void:
	if menu_mode:
		return
	if get_viewport().gui_get_focus_owner() == null:   # Controller erst jetzt benutzt: offenes Menü fokussieren
		if choice_layer.visible and choice_box.get_child_count() > 1:
			var crow := choice_box.get_child(choice_box.get_child_count() - 1)
			if crow.get_child_count() > 0:
				(crow.get_child(0) as Control).grab_focus()
				get_viewport().set_input_as_handled()
				return
		elif paused_menu:
			MenuUI.focus_first(pause_box, true)
		elif end_layer.visible:
			MenuUI.focus_first(end_layer, true)
	if event.is_action_pressed("pad_pause") and not choice_layer.visible and not dead and not won:
		_set_pause(not paused_menu)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel") and paused_menu:
		_set_pause(false)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel") and (dead or won) and end_layer.visible:
		_to_menu()
	elif event.is_action_pressed("zoom_in") and not get_tree().paused:
		_set_zoom_idx(zoom_idx - 1)
	elif event.is_action_pressed("zoom_out") and not get_tree().paused:
		_set_zoom_idx(zoom_idx + 1)

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
		vfx.ring(move_target, 0.1, 0.5, 0.3, Color(1.0, 1.0, 1.0, 0.3))   # kurzer, dezenter Klick-Puls

func _update_mouse_target(click: bool) -> void:
	var p = _ground_at(get_viewport().get_mouse_position())
	if p != null:
		_set_move_target(p, click)

func _update_move_marker() -> void:
	if move_marker == null:
		move_marker = MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(0.62, 0.62)
		move_marker.mesh = pm
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_texture = vfx.ring_tex
		m.albedo_color = Color(1.0, 1.0, 1.0, 0.38)      # dezent: klein, weiß, halb durchsichtig
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		move_marker.material_override = m
		move_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(move_marker)
	move_marker.visible = has_target
	if has_target:
		move_marker.position = Vector3(move_target.x, 0.07, move_target.z)
		var pulse := 1.0 + 0.05 * sin(time * 6.0)
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
				_set_pause(not paused_menu)
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
	if i < 0 or i >= choice_actions.size() or not choice_layer.visible or choice_busy:
		return
	choice_busy = true
	get_viewport().gui_release_focus()
	var row: Control = choice_box.get_child(choice_box.get_child_count() - 1)
	var tw := _ptween()
	for k in row.get_child_count():
		var cd_: Control = row.get_child(k)
		cd_.set_meta("picked", true)
		if cd_.has_meta("pulse"):
			(cd_.get_meta("pulse") as Tween).kill()
		if k == i:
			tw.parallel().tween_property(cd_, "scale", Vector2(1.14, 1.14), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.parallel().tween_property(cd_, "self_modulate", Color(1.8, 1.7, 1.4), 0.1)
		else:
			tw.parallel().tween_property(cd_, "modulate", Color(1, 1, 1, 0), 0.18)
			tw.parallel().tween_property(cd_, "scale", Vector2(0.85, 0.85), 0.18)
	tw.tween_interval(0.16)
	tw.tween_callback(func():
		(choice_actions[i] as Callable).call()
		choice_layer.visible = false
		get_tree().paused = false
		play_cast("cheer", 0.9)
		_try_level_up.call_deferred())   # Überschuss reicht für die nächste Stufe: gleich die nächste Wahl

func _process(delta: float) -> void:
	if get_tree().paused:
		return
	if menu_mode:
		_process_menu(delta)
		return
	if dead or won:
		moving = false
		_animate_player(delta)
		vfx.follow(player.position)
		return
	time += delta
	if bot:
		sim["low_hp"] = minf(sim["low_hp"], hp / max_hp)
		if int(time / 60.0) != sim["min"]:
			sim["min"] = int(time / 60.0)
			var bh: float = boss["hp"] if not boss.is_empty() and enemies.has(boss) else -1.0
			print("SIM min=%02d lvl=%d hp=%d/%d lowhp=%.2f kills=%d alive=%d dps=%.0f taken/min=%.0f boss_hp=%.0f W=%s P=%s" % [sim["min"], level, hp, max_hp, sim["low_hp"], kills, enemies.size(), sim["dealt"] / 60.0, sim["taken"], bh, str(weapons), str(passives)])
			var comp := {}
			var far := 0
			for e in enemies:
				comp[e["type"]] = comp.get(e["type"], 0) + 1
				if ((e["node"] as Node3D).position - player.position).length() > 16.0:
					far += 1
			print("    alive=", comp, " weiter_als_16m=", far)
			sim["dealt"] = 0.0
			sim["taken"] = 0.0
			sim["low_hp"] = 1.0
	for vr in view_rigs:
		(vr as RigAnim).update(0.0, 0.0)
	invuln = maxf(0.0, invuln - delta)
	if lantern != null:
		lantern.light_energy = LANTERN_E + 0.35 * sin(time * 13.0) + 0.2 * sin(time * 23.7) + 0.12 * sin(time * 41.0)
	if regen > 0.0:
		hp = minf(max_hp, hp + regen * delta)
	_move_player(delta)
	_update_camera(delta)
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
	var stick := Vector2(Input.get_joy_axis(0, JOY_AXIS_LEFT_X), Input.get_joy_axis(0, JOY_AXIS_LEFT_Y))
	if stick.length() > 0.2:   # Totzone; darüber stufenlos bis volle Geschwindigkeit
		var amt := clampf((stick.length() - 0.2) / 0.75, 0.0, 1.0)
		v = Vector3(stick.x, 0, stick.y).normalized() * amt + Vector3(_key_axis(KEY_A, KEY_D), 0, _key_axis(KEY_W, KEY_S))
	elif Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_LEFT) or Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_RIGHT) \
			or Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_UP) or Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_DOWN):
		v = Vector3(float(Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_RIGHT)) - float(Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_LEFT)), 0,
			float(Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_DOWN)) - float(Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_UP)))
	if OS.has_environment("WW_WALK"):
		v = Vector3(1, 0, 0.4)
	if bot:
		v = Vector3.ZERO if OS.has_environment("WW_STILL") else _bot_dir()
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
	cur_speed = speed * minf(v.length(), 1.0) if moving else 0.0
	_animate_player(delta)
	var mdl := player.get_node("Model") as Node3D
	if moving:
		v = v.limit_length(1.0)
		var before := player.position
		vel = vel.move_toward(v * speed, speed * 16.0 * delta)   # ~0,06 s bis Vollgas: direkt, aber ohne Ruck
		player.position += vel * delta
		player.position = _clamp_arena(_push_out(player.position, 0.35), 0.0)
		# Klickziel hinter einem Hindernis: kommt sie kaum voran, gibt sie nach 0,5 s auf
		if has_target and not mouse_down:
			var real := Vector2(player.position.x - before.x, player.position.z - before.z).length()
			stuck_t = stuck_t + delta if real < speed * v.length() * delta * 0.3 else 0.0
			if stuck_t > 0.5:
				has_target = false
				stuck_t = 0.0
		step_acc += speed * v.length() * delta
		if step_acc > 1.35:    # Schritt: Staub/Blätter am Fuß
			step_acc = 0.0
			vfx.burst("dust", player.position + Vector3(0, 0.05, 0) - v.normalized() * 0.25)
		look_dir = v.normalized()
		if anim_tree == null:   # Clip-Skins wippen selbst
			mdl.position.y = absf(sin(anim_t * 2.0)) * 0.05 * walk_blend
	elif vel.length() > 0.05:   # sanftes Ausrollen nach dem Loslassen
		vel = vel.move_toward(Vector3.ZERO, speed * 12.0 * delta)
		player.position = _clamp_arena(_push_out(player.position + vel * delta, 0.35), 0.0)
	else:
		vel = Vector3.ZERO
	# Blick: beim Feuern kurz in Zielrichtung, sonst in Laufrichtung
	aim_t = maxf(0.0, aim_t - delta)
	var face := Vector3.ZERO
	if aim_t > 0.0:
		face = aim_dir
	elif moving:
		face = look_dir
	if face != Vector3.ZERO:
		var prev_yaw := face_yaw
		face_yaw = lerp_angle(face_yaw, atan2(face.x, face.z) + deg_to_rad(FACE_OFFSET), 1.0 - exp(-18.0 * delta))
		yaw_vel = lerpf(yaw_vel, angle_difference(prev_yaw, face_yaw) / maxf(delta, 0.001), 0.2)
		mdl.rotation.y = face_yaw
	if face == Vector3.ZERO:
		yaw_vel = lerpf(yaw_vel, 0.0, 0.2)
	$Ground.position = Vector3(player.position.x, 0, player.position.z)

func _key_axis(neg: int, pos: int) -> float:
	return float(Input.is_physical_key_pressed(pos)) - float(Input.is_physical_key_pressed(neg))

var cam_snap := true

func _update_camera(delta: float) -> void:
	if not OS.has_environment("WW_SHOT"):
		# weich, aber zügig: gedämpfte Feder ohne Überschwingen
		cam_zoom = lerpf(cam_zoom, zoom_target, 1.0 - exp(-7.0 * delta))
	# Feste Ausrichtung: die Kamera folgt nur mit der Position. Früher wurde sie jedes Bild auf den Spieler gerichtet; weil sie
	# ihm hinterherläuft, hat sich dabei bei jedem Richtungswechsel der Winkel verändert (Kamera-Kippen).
	# Beim Reinzoomen neigt sie sich etwas flacher (mehr Blick nach vorn); der Winkel hängt nur vom Zoom ab, nicht von der Bewegung.
	var k := clampf((1.0 - cam_zoom) / 0.5, 0.0, 1.0)          # 0 bei Standard/weiter, 1 bei 50 %
	var pitch := deg_to_rad(lerpf(55.6, 44.0, k * k * (3.0 - 2.0 * k)))
	var aim_h := lerpf(0.5, 0.9, k)                              # Zielpunkt: Brust -> etwas höher
	var dist := 11.51                                            # = |(0, 9.5, 6.5)|: bei Zoom 1 exakt die bisherige Kamera
	var look_dir_fixed := Vector3(0, -sin(pitch), -cos(pitch))
	var target := player.position + Vector3(0, aim_h, 0) - look_dir_fixed * dist * cam_zoom
	if OS.has_environment("WW_SIDE"):
		look_dir_fixed = Vector3(0, -0.8, -9.0)
		target = player.position + Vector3(0, 1.8, 9.0) * cam_zoom
	if cam_snap:
		cam.position = target
		cam_snap = false
	else:
		cam.position = cam.position.lerp(target, 1.0 - exp(-18.0 * delta))
	cam.basis = Basis.looking_at(look_dir_fixed, Vector3.UP)

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

func play_cast(kind: String, dur: float) -> void:
	cast_kind = kind
	cast_dur = dur
	cast_t = dur
	_clip_cast(dur)
	if vfx == null:
		return
	var hand := player.position + Vector3(0, 1.25, 0) + (aim_dir * 0.55 if kind != "slam" and kind != "cheer" else Vector3.ZERO)
	match kind:
		"throw":
			vfx.flash(hand, Color(0.6, 1.0, 0.4), 2.2, 4.0, 0.14)
			vfx.burst("leaf", hand)
		"lob":
			vfx.flash(hand, Color(1.0, 0.7, 0.3), 2.5, 4.5, 0.16)
		"sweep":
			vfx.flash(hand, Color(0.7, 0.9, 1.0), 2.5, 5.0, 0.16)
		"point":
			vfx.flash(hand, Color(0.7, 0.85, 1.0), 3.0, 5.0, 0.15)
			vfx.burst("gem", hand)
		"slam":
			vfx.ring(player.position, 0.3, 2.6, 0.45, Color(0.75, 0.55, 0.3, 0.8))
			vfx.add_shake(0.1)

func _ss(a: float, b: float, x: float) -> float:   # smoothstep
	return smoothstep(a, b, x)

# Laufzyklus-Parameter (Test: WW_ANIM="lean=0.2,arm_sw=0.6" überschreibt einzelne Werte)
# Vorlage beim Laufen nur im Oberkörper: lean2 (Brustwirbel) trägt sie, lean (unterster Wirbel) klein halten, sonst knickt sie in der
# Hüfte ein wie beim Hocken. body/hip_off kippen den ganzen Körper ab Becken (nicht gewollt, 0). leg_in < 0 = Beine enger, head < 0 = Kopf aufrichten, pump = Nicken im Schritt
# knee_ph < 0 = Knie beugt früher (hebt vorn, kein Hürden-Kick nach hinten) · arm_out = Arme näher an den Körper
# Ellbogen beugt um Y der Ruhepose (T-Pose: Unterarm seitlich), pro Seite gespiegelt (elbow_mirror 2), sonst überstreckt der linke
var ANIM := {"body": 0.0, "hip_off": 0.0, "leg_in": -0.1, "lean": 0.04, "lean2": 0.2, "head": -0.42, "pump": 0.05, "arm_sw": 0.55,
	"arm_out": 0.25, "elbow": 1.1, "elbow_sw": 0.3, "elbow_axis": 1.0, "elbow_mirror": 2.0, "twist": 0.6, "hip": 0.6, "knee": 1.0,
	"knee_ph": -0.6, "knee_st": 0.0, "ankle": 0.25, "bob": 0.045}
var anim_cfg_done := false

func _animate_player(delta: float) -> void:
	if anim_tree != null:
		_animate_clips(delta)
		return
	if skel == null:
		return
	if not anim_cfg_done:
		anim_cfg_done = true
		if OS.has_environment("WW_ANIM"):
			for pair in OS.get_environment("WW_ANIM").split(","):
				var kv2 := pair.split("=")
				ANIM[kv2[0]] = float(kv2[1])
	var A: Dictionary = ANIM
	walk_blend = move_toward(walk_blend, 1.0 if moving else 0.0, delta * 7.0)
	anim_t += delta * (speed * 1.9 * walk_blend + 1.4 * (1.0 - walk_blend))
	cast_t = maxf(0.0, cast_t - delta)
	if OS.has_environment("WW_GAIT"):      # Test: Lauf-Phase einfrieren
		walk_blend = 1.0
		anim_t = float(OS.get_environment("WW_GAIT"))
	if OS.has_environment("WW_POSE"):      # Test: Pose einfrieren  "art:phase"  (z. B. slam:0.5, death:1, cheer:0.4)
		var kv := OS.get_environment("WW_POSE").split(":")
		if kv[0] == "death":
			death_t = float(kv[1])     # Sekunden seit dem Tod
		else:
			cast_kind = kv[0]
			cast_dur = 1.0
			cast_t = 1.0 - float(kv[1])
	elif OS.has_environment("WW_CAST"):
		cast_t = 0.15
	hit_t = maxf(0.0, hit_t - delta)
	var w := walk_blend
	if death_t >= 0.0:
		w = 0.0
	var p := anim_t
	var X := Vector3.RIGHT
	var Y := Vector3.UP
	var Z := Vector3.BACK
	var hit_k := clampf(hit_t / 0.35, 0.0, 1.0)
	var ph := clampf(1.0 - cast_t / maxf(cast_dur, 0.01), 0.0, 1.0) if cast_t > 0.0 else 0.0
	var casting := cast_t > 0.0
	var kind := cast_kind if casting else ""
	# Waffen-Haltung: mit Geisterkugeln/Sporenwolke halten die Arme leicht Abstand (kanalisierend)
	var want_stance := 1.0 if (weapons.has("orbs") or weapons.has("spores")) and not casting else 0.0
	stance_k = move_toward(stance_k, want_stance, delta * 3.0)

	# Zustände pro Zauberart: Arm-Werte A (+X) / B (-X), Rumpf, Beine
	var arm_swing := [-A["arm_sw"] * sin(p) * w, -A["arm_sw"] * sin(p + PI) * w]       # Laufschwung
	var arm_down := [ARM_DOWN - 0.28 * stance_k + A["arm_out"] * w, ARM_DOWN - 0.28 * stance_k + A["arm_out"] * w]
	var arm_elbow := [-A["elbow"] * (0.35 + w * 0.65) - A["elbow_sw"] * maxf(0.0, sin(p)) * w - 0.2 * stance_k, -A["elbow"] * (0.35 + w * 0.65) - A["elbow_sw"] * maxf(0.0, sin(p + PI)) * w - 0.2 * stance_k]
	var arm_yaw := [-0.14 * sin(p) * w, 0.14 * sin(p + PI) * w]       # vorschwingender Arm kreuzt leicht vor den Körper
	var twist := 0.0          # Rumpfdrehung (um Y)
	var lean := 0.0           # Rumpf nach vorn (+) / hinten (-)
	var crouch := 0.0         # Hocke 0..1
	var hop := 0.0            # Hüpfer (Jubel)
	var head_tilt := 0.0
	match kind:
		"throw":
			var k := sin(ph * PI)
			arm_swing[0] = lerpf(arm_swing[0], -1.45, k)
			arm_down[0] = ARM_DOWN * (1.0 - 0.15 * k)
			arm_elbow[0] = lerpf(arm_elbow[0], -0.15, k)
			twist = 0.25 * k
		"lob":   # Schleuderwurf: Arm zurück, Rumpf zurück, dann nach vorn/oben durchziehen
			var wind := _ss(0.0, 0.35, ph)
			var rel := _ss(0.35, 0.6, ph)
			var rec := _ss(0.6, 1.0, ph)
			var sw := lerpf(lerpf(arm_swing[0], 0.9, wind), -2.0, rel)
			arm_swing[0] = lerpf(sw, arm_swing[0], rec)
			var el := lerpf(lerpf(arm_elbow[0], -1.2, wind), -0.1, rel)
			arm_elbow[0] = lerpf(el, arm_elbow[0], rec)
			arm_down[0] = ARM_DOWN + 0.2     # Arm hängt fast senkrecht, dann hebt ihn der Schwung nach oben (flacher Winkel = Rollen um die Armachse)
			lean = (-0.28 * wind * (1.0 - rel) + 0.32 * rel * (1.0 - rec))
			twist = -0.3 * wind * (1.0 - rel) + 0.35 * rel * (1.0 - rec)
		"slam":   # beide Arme hoch, dann Stampfen/Schlag nach unten in die Hocke
			var up := _ss(0.0, 0.4, ph)
			var hit := _ss(0.4, 0.55, ph)
			var back := _ss(0.7, 1.0, ph)
			for i in 2:
				var sw2 := lerpf(lerpf(arm_swing[i], -2.9, up), -0.5, hit)
				arm_swing[i] = lerpf(sw2, arm_swing[i], back)
				arm_down[i] = ARM_DOWN + 0.25
				arm_elbow[i] = lerpf(-0.35, -0.1, up)
			crouch = hit * (1.0 - back)
			lean = 0.35 * crouch - 0.15 * up * (1.0 - hit)
		"sweep":   # Sichelschwung: Arm vorn, waagerecht von außen nach innen quer vor den Körper
			var env := _ss(0.0, 0.15, ph) * (1.0 - _ss(0.78, 1.0, ph))
			var sweep_t := _ss(0.15, 0.7, ph)
			arm_swing[0] = lerpf(arm_swing[0], -1.45, env)
			arm_down[0] = ARM_DOWN * (1.0 - 0.4 * env)
			arm_elbow[0] = lerpf(arm_elbow[0], -0.2, env)
			arm_yaw[0] = lerpf(0.9, -1.1, sweep_t) * env
			twist = lerpf(0.5, -0.5, sweep_t) * env
		"point":   # Blitz: Zeigearm B nach vorn, Arm A zurück, Kopf leicht geneigt
			var env2 := _ss(0.0, 0.2, ph) * (1.0 - _ss(0.8, 1.0, ph))
			arm_swing[1] = lerpf(arm_swing[1], -1.55, env2)
			arm_down[1] = ARM_DOWN * (1.0 - 0.2 * env2)
			arm_elbow[1] = lerpf(arm_elbow[1], -0.08, env2)
			arm_swing[0] = lerpf(arm_swing[0], 0.55, env2)
			twist = -0.18 * env2
			head_tilt = 0.12 * env2
		"cheer":   # Jubel (Level-Up/Sieg): beide Arme im V nach oben, kleiner Hüpfer
			var env3 := _ss(0.0, 0.15, ph) * (1.0 - _ss(0.8, 1.0, ph))
			for i in 2:
				arm_swing[i] = lerpf(arm_swing[i], -2.6 + 0.15 * sin(ph * TAU * 3.0 + i * PI), env3)
				arm_down[i] = lerpf(arm_down[i], 0.85, env3)
				arm_elbow[i] = lerpf(arm_elbow[i], -0.2, env3)
			hop = absf(sin(ph * PI * 4.0)) * 0.05 * env3
			lean = -0.1 * env3
			head_tilt = -0.15 * env3

	# Tod in drei Phasen: Treffer-Ruck zurück (Arme fliegen auf) -> auf die Knie sinken (Rumpf sackt vor, Arme hängen)
	# -> zur Seite/nach vorn auf den Boden kippen. Kippen + Aufprall macht unten das Modell (um die Knie).
	var kneel := 0.0
	if death_t >= 0.0:
		var dt_ := death_t
		var rec := _ss(0.0, 0.1, dt_) * (1.0 - _ss(0.14, 0.42, dt_))
		kneel = _ss(0.22, 0.7, dt_) * (1.0 - 0.9 * _ss(0.75, 1.15, dt_))   # beim Umkippen strecken sich die Beine wieder
		for i in 2:
			arm_swing[i] = -0.9 * rec + 0.25 * kneel * (1.0 if i == 0 else 0.6)
			arm_down[i] = ARM_DOWN - 0.75 * rec + 0.2 * kneel
			arm_elbow[i] = -0.25 - 0.3 * rec
			arm_yaw[i] = 0.0
		lean = -0.4 * rec + 0.5 * kneel
		head_tilt = 0.12 * kneel
		twist = 0.15 * kneel

	# Beine: Seite A (+X) / B (-X) gegenphasig; Hocke beugt Hüfte/Knie/Knöchel
	for side in 2:
		var sg := 1.0 if side == 0 else -1.0
		var hip := 45 if side == 0 else 49
		var lp := p + (0.0 if side == 0 else PI)
		# Knien (Tod): Oberschenkel senkrecht, Unterschenkel flach nach hinten; ein Bein etwas früher
		var kn := clampf(kneel * 1.25 - (0.0 if side == 0 else 0.25), 0.0, 1.0)
		_rot(hip, Basis(Z, sg * A.get("leg_in", 0.0) * w) * Basis(X, (A["hip"] * sin(lp) + A.get("hip_off", 0.0)) * w - 0.6 * crouch - 0.15 * kn))
		_rot(hip + 1, Basis(X, (A["knee"] * maxf(0.0, -cos(lp + A["knee_ph"])) + A["knee_st"]) * w + 1.1 * crouch + A.get("kneel_knee", 1.65) * kn))
		_rot(hip + 2, Basis(X, -A["ankle"] * maxf(0.0, sin(lp)) * w - 0.5 * crouch + A.get("kneel_ankle", 0.5) * kn))
		var sh := 8 if side == 0 else 27
		if A.get("sh_order", 0.0) > 0.5:   # erst absenken (Rumpf-Ebene), dann um die Querachse schwingen
			_rot(sh, Basis(Z, -sg * arm_down[side]) * Basis(X, arm_swing[side]) * Basis(Y, arm_yaw[side]))
		else:
			_rot(sh, Basis(Y, arm_yaw[side]) * Basis(X, arm_swing[side]) * Basis(Z, -sg * arm_down[side]))
		var eax: int = int(A.get("elbow_axis", 0.0))
		var em: float = A.get("elbow_mirror", 0.0)
		var ev: Vector3 = [X, Y, Z][absi(eax) % 3] * (sg if em > 1.5 else (-sg if em > 0.5 else 1.0))
		_rot(sh + 1, Basis(ev, arm_elbow[side]))

	# Rumpf: mehrgliedrig (Wirbelsäule 1-3 mit Phasenverzug), Seitneigung, Nicken, Schultern heben/senken
	var breathe := sin(p * 1.1) * 0.025 * (1.0 - w) + 0.02 * stance_k * sin(p * 1.4)
	var g2 := 2.0 * p
	var twk: float = A.get("twist", 1.0)        # Rumpfdrehung im Schritt (Summe ~0,62 rad bei 1.0)
	var tw1 := 0.30 * twk * sin(p) * w
	var tw2 := 0.20 * twk * sin(p + 0.35) * w
	var tw3 := 0.12 * twk * sin(p + 0.7) * w
	var bend1 := 0.07 * sin(p + 0.5) * w
	var bend2 := 0.05 * sin(p + 0.8) * w
	_rot(1, Basis(X, A["lean"] * w + 0.04 * cos(g2) * w + breathe - 0.25 * hit_k + lean) * Basis(Y, tw1 + twist) * Basis(Z, bend1))
	_rot(2, Basis(X, (A["lean2"] + 0.03 * cos(g2 + 0.4) - A["pump"] * maxf(0.0, cos(g2))) * w) * Basis(Y, tw2 + 0.3 * twist) * Basis(Z, bend2))
	_rot(3, Basis(X, breathe * 0.5 + 0.2 * lean + (A["lean2"] + 0.05 * cos(g2 + 0.8)) * w) * Basis(Y, tw3) * Basis(Z, -0.04 * sin(p) * w))
	_rot(7, Basis(Z, A.get("clav", 0.10) * sin(p) * w))            # Schultergürtel: wechselseitig heben/senken
	_rot(26, Basis(Z, A.get("clav", 0.10) * A.get("clav_m", 1.0) * sin(p + PI) * w))
	_rot(5, Basis(Y, -(tw1 + tw2 + tw3) * 0.8 - 0.5 * twist + 0.18 * sin(p * 0.35) * (1.0 - w)) * Basis(X, 0.1 * hit_k - 0.4 * lean + A["head"] * w + 0.05 * cos(g2 + 0.6) * w) * Basis(Z, head_tilt - (bend1 + bend2) * 0.7))
	# Becken: Gegendrehung zum Oberkörper, seitliches Wiegen, Einlehnen in Kurven, Gewichtsverlagerung im Stand
	var roll := clampf(yaw_vel * 0.035, -0.16, 0.16) * w
	_rot(0, Basis(X, A.get("body", 0.0) * w) * Basis(Y, -0.16 * sin(p) * w) * Basis(Z, 0.035 * cos(p) * w + roll + 0.02 * sin(p * 0.5) * (1.0 - w)))
	var hips_y: float = A["bob"] * absf(sin(p)) * w - 0.07 * crouch + hop - A.get("kneel_drop", 0.22) * kneel
	skel.set_bone_pose_position(0, skel.get_bone_rest(0).origin + Vector3(0, hips_y, 0))
	# Tod: kniend nach vorn/zur Seite auf den Boden kippen, kleiner Aufprall-Federer
	var mdl := player.get_node("Model") as Node3D
	if death_t >= 0.0:
		if not OS.has_environment("WW_POSE"):
			death_t += delta
		var fall := _ss(0.72, 1.2, death_t)
		var bounce := sin(clampf((death_t - 1.2) / 0.3, 0.0, 1.0) * PI) * 0.06
		mdl.rotation.x = 1.25 * fall - bounce
		mdl.rotation.z = 0.3 * fall
		mdl.position.y = 0.05 * fall
		_death_fx()
	else:
		mdl.rotation.x = 0.0
		mdl.rotation.z = 0.0

var death_fx_done := {}
func _death_fx() -> void:
	# Effekte zur Todesanimation, jeweils einmal (Zeitpunkte in Sekunden)
	var t := death_t
	var once := func(key: String, at: float) -> bool:
		if t >= at and not death_fx_done.has(key):
			death_fx_done[key] = true
			return true
		return false
	if once.call("hit", 0.0):
		vfx.flash(player.position + Vector3(0, 1.2, 0), Color(1.0, 0.25, 0.2), 6.0, 8.0, 0.5, 1.0)
		vfx.ring(player.position, 0.3, 3.0, 0.5, Color(1.0, 0.3, 0.25, 0.8))
		vfx.burst("hit", player.position + Vector3(0, 1.2, 0))
		vfx.add_shake(0.5)
		zoom_target = 0.77
	if once.call("knees", 0.62):
		vfx.burst("dust", player.position + Vector3(0, 0.1, 0))
		vfx.add_shake(0.15)
	if once.call("soul", 0.7):
		vfx.burst("leaf", player.position + Vector3(0, 1.6, 0))
		for k in 5:
			get_tree().create_timer(0.12 * k).timeout.connect(func(): vfx.burst("gem_b", player.position + Vector3(randf_range(-0.4, 0.4), 0.8 + 0.25 * k, randf_range(-0.4, 0.4))))
	if once.call("ground", 1.18):
		vfx.burst("dust", player.position + Vector3(0, 0.1, 0))
		vfx.burst("dust", player.position + Vector3(0.3, 0.1, 0.3))
		vfx.ring(player.position, 0.2, 1.8, 0.4, Color(0.8, 0.75, 0.6, 0.6))
		vfx.add_shake(0.25)
	if lantern != null:   # Laterne erlischt langsam
		lantern.light_energy = LANTERN_E * (1.0 - _ss(0.5, 2.2, t)) + 0.15

# ---------- Gegner ----------
func _spawn_logic(delta: float) -> void:
	var minute := time / 60.0
	var rate: float = Defs.difficulty(minute)["rate"] * float(lv["rate"])   # Gegner pro Sekunde
	if bot and OS.has_environment("WW_RATE"):
		rate *= float(OS.get_environment("WW_RATE"))
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
	var count := {}
	for e in enemies:
		count[e["type"]] = count.get(e["type"], 0) + 1
	var ok := func(r: Array) -> bool:   # Obergrenze pro Typ (z. B. Heiler), damit sich keine Zähigkeits-Klumpen bilden
		return minute >= r[0] and count.get(r[1], 0) < int(ENEMIES[r[1]].get("cap", 999))
	var total := 0.0
	for r in table:
		if ok.call(r):
			total += r[2]
	var roll := rng.randf() * total
	for r in table:
		if ok.call(r):
			roll -= r[2]
			if roll <= 0.0:
				return r[1]
	return "imp"

func _spawn_enemy(type: String) -> void:
	var d: Dictionary = ENEMIES[type]
	var pos := _spawn_point()
	var n: Node3D = null
	if RigAnim.CFG.has(type):
		n = RigAnim.make_model(type)   # geriggt + prozedural animiert (null = Rückfall auf statisches Modell)
	if n == null and d.has("alt") and _scene_or_null(M + d["m"]) == null:
		n = RigAnim.make_model(d["alt"])   # Platzhalter: vorhandene Kreatur, eingefärbt
		if n != null:
			var alt_sz: float = ENEMIES[d["alt"]]["sz"]
			var body := n.get_child(0) as Node3D    # Knoten selbst wird beim Treffer gestaucht -> Körper skalieren
			body.scale *= float(d["sz"]) / alt_sz
			body.position *= float(d["sz"]) / alt_sz
			_tint_model(n, d["col"].lerp(Color(1, 1, 1), 0.3))
	if n == null:
		n = _make_model(d["m"], d["col"], d["sz"] * 2.0)
	n.position = pos
	add_child(n)
	var sc := Defs.difficulty(time / 60.0)
	sc["hp"] *= float(lv.get("hp_mult", 1.0))
	sc["dmg"] *= float(lv.get("dmg_mult", 1.0))
	var scale_hp: float = sc["hp"]
	next_enemy_id += 1
	# Masse statt Tempo: Gegner (außer Boss) sind nie schneller als der Spieler
	enemies.append({"node": n, "type": type, "id": next_enemy_id, "role": d["role"], "hp": d["hp"] * scale_hp,
		"spd": minf(d["spd"] * rng.randf_range(0.9, 1.1) * sc["spd"], base_speed * 0.92) if d["role"] != "boss" else d["spd"] * sc["spd"], "dmg": d["dmg"] * sc["dmg"], "shot_dmg": d.get("shot_dmg", 0.0) * sc["dmg"], "punch": 0.0, "max": d["hp"] * scale_hp,
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
		if dist > 30.0 and e["role"] != "boss":  # abgehängt: vor die Figur (Laufrichtung) versetzen, knapp außerhalb des Bildes
			n.position = _spawn_point(look_dir)
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
					_enemy_shot(n.position + Vector3(0, 1.0, 0), dir, e["shot_dmg"])
			"healer":
				if dist < 8.0:
					move_speed = 0.0
				e["heal_t"] -= delta
				if e["heal_t"] <= 0.0:
					e["heal_t"] = 1.2
					_heal_pulse(e, d["heal"], d["heal_range"])
		n.position += mv * move_speed * delta
		if e["role"] != "boss":   # Boss walzt durch
			n.position = _push_out(n.position, e["r"] * 0.8)
		n.position = _clamp_arena(n.position, 0.0)
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
			_hurt(e["dmg"], e["type"])
	_update_eshots(delta)

func _heal_pulse(healer: Dictionary, amount: float, rng_h: float) -> void:
	var hp_pos: Vector3 = (healer["node"] as Node3D).position
	var healed := 0
	for o in enemies:
		if o == healer or o["hp"] >= o["max"]:
			continue
		if o.get("healed_until", 0.0) > time:   # Heilung stapelt nicht (mehrere Heiler)
			continue
		if ((o["node"] as Node3D).position - hp_pos).length() < rng_h:
			o["healed_until"] = time + 1.2
			o["hp"] = minf(o["max"], o["hp"] + amount * (1.0 + time / 300.0))
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
	n.material_override = _glow_mat(Color(1.0, 0.18, 0.12))     # Gegner-Geschosse immer rot (Spieler-Effekte nie)
	n.position = pos
	add_child(n)
	vfx.glow_sprite(n, Color(1.0, 0.15, 0.1, 0.75), 1.0)
	vfx.attach_trail(n, Color(1.0, 0.2, 0.12), 0.12, 16, 0.3)
	eshots.append({"node": n, "vel": dir * 6.0, "life": 4.0, "dmg": dmg})

func _update_eshots(delta: float) -> void:
	for i in range(eshots.size() - 1, -1, -1):
		var s: Dictionary = eshots[i]
		var n: Node3D = s["node"]
		n.position += s["vel"] * delta
		s["life"] -= delta
		var gone: bool = s["life"] <= 0.0 or not _in_arena(n.position, 0.6)
		if not gone and (n.position - (player.position + Vector3(0, 1.0, 0))).length() < 0.65:
			if invuln <= 0.0:
				_hurt(s["dmg"], "schuss")
			vfx.burst("ehit", n.position)
			gone = true
		if gone:
			n.queue_free()
			eshots.remove_at(i)

func _hurt(amount: float, src: String = "") -> void:
	if bot:
		sim["src"][src] = int(sim["src"].get(src, 0) + amount)
	if bot and OS.has_environment("WW_INVULN"):
		sim["taken"] += amount
		return
	if more != null and more.absorb(amount):   # Rindenschild fängt den Treffer ab
		invuln = 0.5
		return
	if dodge_chance > 0.0 and rng.randf() < dodge_chance:   # Nebelmantel: ausgewichen
		invuln = 0.35
		vfx.burst("dust", player.position + Vector3(0, 0.8, 0))
		vfx.number(player.position + Vector3(0, 0.6, 0), 0.0, Color(0.7, 0.85, 1.0), "Ausgewichen")
		return
	amount *= armor_mult
	hp -= amount
	sim["taken"] += amount
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
	var crit := crit_chance > 0.0 and rng.randf() < crit_chance
	if crit:
		dealt *= 2.0
	sim["dealt"] += minf(dealt, maxf(e["hp"], 0.0))
	e["hp"] -= dealt
	var n: Node3D = e["node"]
	if fx:
		n.position += (n.position - player.position).normalized() * 0.15
		e["punch"] = 1.0
		vfx.burst("hit", n.position + Vector3(0, 0.8, 0))
	vfx.number(n.position + Vector3(0, 0.8, 0), dealt, Color(1.0, 0.85, 0.3) if crit else Color(1, 0.95, 0.7))
	if e["hp"] <= 0.0:
		_kill(e)

func _kill(e: Dictionary) -> void:
	kills += 1
	var p: Vector3 = (e["node"] as Node3D).position
	var type: String = e["type"]
	_drop("gem", p, ENEMIES[type]["xp"])
	# HP-Beeren: Grundchance 3 %, bei wenig Leben bis ca. 8 %; Elite/Tank lassen sicher eine fallen
	var berry_p := 0.03 + 0.05 * (1.0 - hp / max_hp)
	if rng.randf() < berry_p or ENEMIES[type]["role"] in ["elite", "tank"]:
		_drop("berry", p + Vector3(rng.randf_range(-0.6, 0.6), 0, rng.randf_range(-0.6, 0.6)), 0)
	if ENEMIES[type]["role"] == "boss":
		_drop("chest", p, 0)
	var big: bool = ENEMIES[type]["role"] in ["elite", "boss", "tank"]
	if ENEMIES[type]["role"] == "boss":
		vfx.firework(p, 10, ["teal", "violet", "gold", "green"], 7.0)   # Boss besiegt
	var tint: Color = Color(1, 1, 1).lerp(ENEMIES[type]["col"], 0.55)
	vfx.burst("death", p + Vector3(0, 0.6, 0), tint)
	vfx.burst("leaf", p + Vector3(0, 0.6, 0))
	if big:
		vfx.ring(p, 0.5, 7.0 if ENEMIES[type]["role"] == "boss" else 4.0, 0.6, Color(0.5, 1.0, 0.8, 0.9))
		vfx.flash(p + Vector3(0, 1.5, 0), Color(0.5, 1.0, 0.8), 6.0, 10.0, 0.5)
		vfx.add_shake(0.8 if ENEMIES[type]["role"] == "boss" else 0.45)
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
			var cnt: int = int(st["count"]) + proj_bonus
			var base: Vector3 = (t["node"] as Node3D).position - player.position
			base.y = 0
			for k in cnt:
				var off := (k - (cnt - 1) * 0.5) * 0.18
				_fire_dart(base.normalized().rotated(Vector3.UP, off), st["dmg"], st["pierce"] == "ja", int(st["bounce"]))
	if weapons.has("acorn") and cd["acorn"] <= 0.0 and not enemies.is_empty():
		var st2 := Defs.weapon_stats("acorn", weapons["acorn"])
		cd["acorn"] = st2["cd"] * cd_mult
		for k in int(st2["count"]) + proj_bonus:
			var t2 := _nearest(player.position + Vector3(rng.randf_range(-4, 4), 0, rng.randf_range(-4, 4)), BOMB_RANGE)
			if not t2.is_empty():
				_throw_bomb((t2["node"] as Node3D).position)
	_update_orbs(delta)
	extra.update(delta)
	more.update(delta)

func _fire_dart(dir: Vector3, dmg: float, pierce: bool, bounce: int = 0) -> void:
	play_cast("throw", 0.3)
	aim_dir = dir
	aim_t = 0.6
	var n := _make_model("weapons/thorn_dart.glb", Color(0.7, 0.9, 0.5), 0.3)
	vfx.attach_trail(n, Color(0.7, 1.0, 0.45), 0.07, 16, 0.3)
	vfx.glow_sprite(n, Color(0.6, 1.0, 0.4, 0.8), 0.45, Vector3(0, 0.1, 0))
	n.position = player.position + Vector3(0, 1.1, 0) + dir * 0.6
	n.rotation.y = atan2(dir.x, dir.z) + deg_to_rad(FACE_OFFSET)
	add_child(n)
	shots.append({"node": n, "vel": dir * 22.0, "life": (DART_RANGE + 2.0) / 22.0, "dmg": dmg, "pierce": pierce, "hit": [], "bounce": bounce})

func _update_shots(delta: float) -> void:
	for i in range(shots.size() - 1, -1, -1):
		var s: Dictionary = shots[i]
		var n: Node3D = s["node"]
		n.position += s["vel"] * delta
		s["life"] -= delta
		var gone: bool = s["life"] <= 0.0
		if not _in_arena(n.position, 0.6):     # Wand: abprallen oder zerbrechen
			if int(s["bounce"]) > 0:
				s["bounce"] = int(s["bounce"]) - 1
				var vel: Vector3 = s["vel"]
				var h: Vector2 = Defs.ARENA_HALF - Vector2.ONE * 0.6
				if absf(n.position.x) > h.x:
					vel.x = -vel.x
				if absf(n.position.z) > h.y:
					vel.z = -vel.z
				s["vel"] = vel
				n.position = _clamp_arena(n.position, -Defs.WALL_INSET + 0.6)
				n.rotation.y = atan2(vel.x, vel.z) + deg_to_rad(FACE_OFFSET)
				s["life"] = maxf(float(s["life"]), 0.5)
				s["hit"].clear()
				vfx.burst("hit", n.position)
			else:
				vfx.burst("leaf", n.position)
				gone = true
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
	play_cast("lob", 0.55)
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
	if _scene_or_null(M + "props/rune_sigil.glb") == null:
		return
	var n := _make_model("props/rune_sigil.glb", Color.WHITE, 3.0)
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
# XP-Kristalle: klein = gelb, mittel = hellblau, groß = zartes Violett; dezent durchscheinend mit leichtem Pulsieren
const GEM_TIERS := [
	{"col": Color(1.0, 0.86, 0.32), "size": 1.0, "burst": "gem_y", "glow": 0.9},
	{"col": Color(0.55, 0.88, 1.0), "size": 1.3, "burst": "gem_b", "glow": 1.1},
	{"col": Color(0.85, 0.72, 1.0), "size": 1.7, "burst": "gem_v", "glow": 1.4},
]
var gem_mats: Array = []

func _gem_tier(value: int) -> int:
	return 0 if value <= 2 else (1 if value < 15 else 2)

func _gem_material(tier: int) -> StandardMaterial3D:
	if gem_mats.is_empty():
		for t in GEM_TIERS:
			var col: Color = t["col"]
			var m := StandardMaterial3D.new()
			m.albedo_color = Color(col.r, col.g, col.b, 0.72)
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.roughness = 0.12
			m.metallic = 0.1
			m.emission_enabled = true
			m.emission = col
			m.emission_energy_multiplier = 1.0
			m.rim_enabled = true
			m.rim = 1.0
			m.rim_tint = 0.7
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
			gem_mats.append(m)
	return gem_mats[tier]

func _drop(kind: String, pos: Vector3, value: int) -> void:
	var n: Node3D
	match kind:
		"gem": n = _make_model("items/spirit_gem.glb", Color(0.3, 1.0, 0.9), 0.25)
		"berry": n = _make_model("items/heart_berry.glb", Color(0.9, 0.2, 0.2), 0.3)
		_: n = _make_model("items/rune_chest.glb", Color(0.6, 0.4, 0.2), 0.9)
	n.position = Vector3(pos.x, 0.3, pos.z)
	var tier := _gem_tier(value) if kind == "gem" else 0
	if kind == "gem":
		n.scale = Vector3.ONE * float(GEM_TIERS[tier]["size"])
		var gm := _gem_material(tier)
		for mi in n.find_children("*", "MeshInstance3D", true, false):
			for si in (mi as MeshInstance3D).mesh.get_surface_count():
				(mi as MeshInstance3D).set_surface_override_material(si, gm)
	add_child(n)
	var gcol := Color(1.0, 0.3, 0.3, 0.8) if kind == "berry" else Color(1.0, 0.8, 0.3, 0.8)
	var gsize := 1.6
	if kind == "gem":
		var tc: Color = GEM_TIERS[tier]["col"]
		gcol = Color(tc.r, tc.g, tc.b, 0.42)       # dezenter Hof
		gsize = 0.8 * float(GEM_TIERS[tier]["glow"])
	if kind != "gem":   # XP-Kristalle leuchten nicht (nur das Material pulsiert dezent)
		vfx.glow_sprite(n, gcol, gsize, Vector3(0, 0.15, 0))
	pickups.append({"node": n, "kind": kind, "value": value, "tier": tier, "pulled": false, "t0": rng.randf() * TAU})

func _update_pickups(delta: float) -> void:
	for ti in gem_mats.size():   # sanftes Pulsieren (alle Kristalle einer Stufe gemeinsam)
		(gem_mats[ti] as StandardMaterial3D).emission_energy_multiplier = 0.9 + 0.45 * sin(time * 3.0 + ti * 1.3)
	for i in range(pickups.size() - 1, -1, -1):
		var p: Dictionary = pickups[i]
		var n: Node3D = p["node"]
		var d := n.position.distance_to(player.position + Vector3(0, 0.3, 0))
		n.rotation.y += delta * 2.0
		if not p["pulled"]:
			n.position.y = 0.3 + sin(time * 3.0 + p["t0"]) * 0.06
		if d < magnet or p["pulled"]:
			if not p["pulled"]:
				vfx.attach_trail(n, (GEM_TIERS[p["tier"]]["col"] as Color) if p["kind"] == "gem" else Color(1.0, 0.8, 0.4), 0.09, 10, 0.25)
			p["pulled"] = true
			n.position = n.position.move_toward(player.position + Vector3(0, 0.5, 0), (8.0 + 12.0 / maxf(d, 0.5)) * delta)
		if d < 0.7:
			vfx.burst("heal" if p["kind"] == "berry" else (GEM_TIERS[p["tier"]]["burst"] if p["kind"] == "gem" else "gem_y"), player.position + Vector3(0, 0.8, 0))
			match p["kind"]:
				"gem":
					xp += int(ceil(p["value"] * xp_mult))
					if _try_level_up():
						n.queue_free()
						pickups.remove_at(i)
						_level_up()
						return
				"berry":
						var heal_amt := maxf(25.0, max_hp * 0.15)
						hp = minf(max_hp, hp + heal_amt)
						vfx.number(player.position + Vector3(0, 0.8, 0), heal_amt, Color(0.5, 1.0, 0.5))
				"chest":
					vfx.firework(player.position, 7, ["gold", "violet", "teal", "pink", "green"], 6.5)
					vfx.burst("level", player.position + Vector3(0, 1.0, 0))
					vfx.ring(player.position, 0.5, 8.0, 0.8, Color(1.0, 0.85, 0.4, 1.0))
					vfx.pillar(player.position, Color(1.0, 0.85, 0.4), 1.8)
					_show_banner("Runentruhe geöffnet!")
					_level_up(true)
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
	armor_mult = 1.0 - 0.05 * pl("armor")
	dodge_chance = 0.04 * pl("dodge")
	crit_chance = 0.05 * pl("crit")
	proj_bonus = pl("twin")

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
	# Mindestens eine Waffe zur Auswahl, sofern noch eine wählbar ist
	var has_w := false
	for c in out:
		if c["kind"] == "weapon":
			has_w = true
	if not has_w:
		for c in pool:
			if c["kind"] == "weapon":
				if out.size() >= 3:
					out[2] = c
				else:
					out.append(c)
				break
	# Alle Plätze belegt und ausgebaut -> Splitterbeutel (Meta-Währung) statt leerer Karten
	if out.size() < 3:
		out.append({"kind": "gold", "id": "greed", "lvl": 0})
	if out.size() < 3:
		out.append({"kind": "heal", "id": "vigor", "lvl": 0})
	# Waffen immer links
	var ws := out.filter(func(c): return c["kind"] == "weapon")
	var rest := out.filter(func(c): return c["kind"] != "weapon")
	return ws + rest

func _gold_amount() -> int:
	return 15 + int(time / 60.0) * 2

func _card_title(c: Dictionary) -> String:
	match c["kind"]:
		"weapon": return Defs.WEAPONS[c["id"]]["name"]
		"passive": return Defs.PASSIVES[c["id"]]["name"]
		"gold": return "Splitterbeutel"
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
		"gold":
			return ["+%d Wurzelsplitter" % _gold_amount(), "für dauerhafte Verstärkungen"]
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
		"gold":
			bonus_shards += _gold_amount()
			vfx.number(player.position + Vector3(0, 1.2, 0), _gold_amount(), Color(1.0, 0.85, 0.4))
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
	panel.custom_minimum_size = Vector2(231, 336)
	panel.pivot_offset = Vector2(115.5, 168)
	var mx_l: int = Defs.WEAPONS[c["id"]]["max"] if is_w else (Defs.PASSIVES[c["id"]]["max"] if c["kind"] == "passive" else 99)
	var master: bool = c["kind"] in ["weapon", "passive"] and c["lvl"] + 1 >= mx_l
	var special: bool = master or (is_w and c["lvl"] == 0)
	var gold := Color(1.0, 0.82, 0.35)
	var base_style := _sb(Color(0.05, 0.1, 0.1, 1), Color(gold.r, gold.g, gold.b, 0.85) if special else Color(accent.r, accent.g, accent.b, 0.55), 12, 3 if special else 2)
	var hover_style := _sb(Color(0.09, 0.18, 0.18, 1), gold if special else accent, 12, 4)
	panel.set_meta("special", special)
	panel.add_theme_stylebox_override("panel", base_style)
	var pad := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 15)
	panel.add_child(pad)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 7)
	pad.add_child(v)
	var top := HBoxContainer.new()
	var tag_col := Color(1.0, 0.62, 0.3) if is_w else (Color(0.45, 0.85, 1.0) if c["kind"] == "passive" else (Color(1.0, 0.85, 0.35) if c["kind"] == "gold" else Color(0.55, 1.0, 0.55)))
	var tag_txt := "⚔  WAFFE" if is_w else ("✚  AUSRÜSTUNG" if c["kind"] == "passive" else ("◆  BELOHNUNG" if c["kind"] == "gold" else "♥  ERHOLUNG"))
	var kind_l := _label(tag_txt, 17, tag_col)
	var tag := PanelContainer.new()
	var tag_sb := _sb(Color(tag_col.r * 0.22, tag_col.g * 0.22, tag_col.b * 0.22, 1), Color(tag_col.r, tag_col.g, tag_col.b, 0.8), 8, 1)
	tag_sb.content_margin_left = 9
	tag_sb.content_margin_right = 9
	tag_sb.content_margin_top = 2
	tag_sb.content_margin_bottom = 2
	tag.add_theme_stylebox_override("panel", tag_sb)
	tag.add_child(kind_l)
	top.add_child(tag)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(sp)
	var badge := _label("" if c["kind"] in ["heal", "gold"] else ("MEISTERSTUFE" if master else ("NEU" if c["lvl"] == 0 else "Stufe %d" % (c["lvl"] + 1))), 14, Color(1, 0.85, 0.35) if master or c["lvl"] == 0 else Color(0.7, 0.8, 0.8))
	top.add_child(badge)
	v.add_child(top)
	var plate := PanelContainer.new()
	plate.add_theme_stylebox_override("panel", _sb(Color(accent.r * 0.12, accent.g * 0.12, accent.b * 0.12, 1), Color(accent.r, accent.g, accent.b, 0.3), 9, 1))
	var ic := Icon.make(c["id"], 105)
	var ic_c := CenterContainer.new()
	ic_c.custom_minimum_size = Vector2(0, 119)
	ic_c.add_child(ic)
	plate.add_child(ic_c)
	v.add_child(plate)
	var title := _label(_card_title(c), 23, Color(1, 1, 1))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	if c["kind"] in ["weapon", "passive"]:
		var mx: int = Defs.WEAPONS[c["id"]]["max"] if is_w else Defs.PASSIVES[c["id"]]["max"]
		var pips := _label(_pips(c["lvl"] + 1, mx), 15, accent)
		pips.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(pips)
	for line in _card_lines(c):
		var ll := _label(line, 16, Color(0.9, 0.95, 0.95))
		ll.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ll.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ll.custom_minimum_size = Vector2(196, 0)
		v.add_child(ll)
	var keyl := _label("Taste %d" % (idx + 1), 13, Color(0.6, 0.7, 0.7))
	keyl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	keyl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	keyl.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	v.add_child(keyl)
	for ch in panel.find_children("*", "Control", true, false):   # Bild/Platte/Texte schlucken keinen Klick
		(ch as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	# Glanzstreifen (läuft nach dem Erscheinen einmal über die Karte) – frei positioniert in einer Überlagerung
	panel.clip_contents = true
	var over := Control.new()
	over.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(over)
	var shine := TextureRect.new()
	var sg := GradientTexture2D.new()
	var sgr := Gradient.new()
	sgr.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	sgr.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 0.28), Color(1, 1, 1, 0)])
	sg.gradient = sgr
	sg.width = 64
	sg.height = 8
	shine.texture = sg
	shine.stretch_mode = TextureRect.STRETCH_SCALE
	shine.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shine.size = Vector2(90, 520)
	shine.rotation = 0.35
	shine.position = Vector2(-160, -80)
	shine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	over.add_child(shine)
	panel.set_meta("shine", shine)
	panel.focus_mode = Control.FOCUS_ALL      # Controller: Stick/Steuerkreuz wählt, A nimmt
	var lift := func(on: bool):
		panel.add_theme_stylebox_override("panel", hover_style if on else base_style)
		if panel.get_meta("ready", false) and not panel.get_meta("picked", false):
			_ptween().tween_property(panel, "scale", Vector2.ONE * (1.06 if on else 1.0), 0.12).set_trans(Tween.TRANS_SINE)
	panel.mouse_entered.connect(func(): lift.call(true))
	panel.mouse_exited.connect(func():
		if not panel.has_focus():
			lift.call(false))
	panel.focus_entered.connect(func(): lift.call(true))
	panel.focus_exited.connect(func(): lift.call(false))
	panel.gui_input.connect(func(ev: InputEvent):
		var mbe := ev as InputEventMouseButton
		if (mbe != null and mbe.pressed and mbe.button_index == MOUSE_BUTTON_LEFT) or ev.is_action_pressed("ui_accept"):
			get_viewport().set_input_as_handled()
			_pick(idx))
	return panel

func _bot_dir() -> Vector3:
	# Ausweichen: Abstoßung von nahen Gegnern/Geschossen; ohne Gefahr zum nächsten Kristall; immer etwas seitlich (kiten)
	var push := Vector3.ZERO
	for e in enemies:
		var d: Vector3 = player.position - (e["node"] as Node3D).position
		d.y = 0.0
		var l := d.length()
		if l < 7.0 and l > 0.01:
			push += d / l / pow(maxf(l - e["r"], 0.4), 2.0)
	for s2 in eshots:   # Geschossen seitlich ausweichen, wenn sie auf die Figur zufliegen
		var rel: Vector3 = player.position - (s2["node"] as Node3D).position
		rel.y = 0.0
		var sv: Vector3 = s2["vel"]
		sv.y = 0.0
		if rel.length() < 6.0 and sv.dot(rel) > 0.0:
			var side := rel - sv.normalized() * rel.dot(sv.normalized())   # Abstand quer zur Flugbahn
			if side.length() < 1.2:
				push += (side.normalized() if side.length() > 0.01 else sv.normalized().cross(Vector3.UP)) * 2.5 / maxf(rel.length(), 0.5)
	var hh: Vector2 = Defs.ARENA_HALF - Vector2.ONE * Defs.WALL_INSET   # Wände/Ecken meiden
	var wx := hh.x - absf(player.position.x)
	var wz := hh.y - absf(player.position.z)
	if wx < 6.0:
		push.x -= signf(player.position.x) * 0.6 / maxf(wx, 0.5)
	if wz < 6.0:
		push.z -= signf(player.position.z) * 0.6 / maxf(wz, 0.5)
	var danger := push.length()
	var v := Vector3.ZERO
	if danger > 0.02:
		v = push.normalized() + push.normalized().cross(Vector3.UP) * 0.6
	var best := 1e9
	var gem_dir := Vector3.ZERO
	for p in pickups:
		var gd: Vector3 = (p["node"] as Node3D).position - player.position
		gd.y = 0.0
		var gl := gd.length()
		var w := gl * (0.5 if p["kind"] != "gem" else 1.0)
		if gl < 14.0 and w < best:
			best = w
			gem_dir = gd / maxf(gl, 0.01)
	v += gem_dir * (1.2 if danger < 0.15 else 0.3)
	if v.length() < 0.1:
		v = Vector3(cos(time * 0.3), 0, sin(time * 0.3))
	return v.normalized()

func _bot_pick(cs: Array) -> Dictionary:
	var best: Dictionary = cs[0]
	var bs := -1e9
	for c in cs:
		var sc := rng.randf() * 0.5
		match c["kind"]:
			"weapon": sc += 3.0 if c["lvl"] == 0 else 2.0
			"passive": sc += 1.5 if c["id"] in ["might", "haste", "vigor", "area"] else 1.0
			"gold": sc += 0.5
		if sc > bs:
			bs = sc
			best = c
	return best

var choice_busy := false
var lvl_rays: Rays
var lvl_sparks: CPUParticles2D

func _levelup_fx(head: Label) -> void:
	# Strahlen + Funken hinter dem Fenster, Titel springt auf
	var layer := choice_layer
	if lvl_rays == null:
		lvl_rays = Rays.new()
		lvl_rays.set_anchors_preset(Control.PRESET_FULL_RECT)
		layer.add_child(lvl_rays)
		layer.move_child(lvl_rays, 1)        # über der Abdunklung, unter dem Fenster
		lvl_sparks = CPUParticles2D.new()
		lvl_sparks.process_mode = Node.PROCESS_MODE_ALWAYS
		lvl_sparks.amount = 70
		lvl_sparks.lifetime = 2.4
		lvl_sparks.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		lvl_sparks.emission_rect_extents = Vector2(620, 40)
		lvl_sparks.direction = Vector2(0, -1)
		lvl_sparks.spread = 25.0
		lvl_sparks.gravity = Vector2(0, -20)
		lvl_sparks.initial_velocity_min = 40.0
		lvl_sparks.initial_velocity_max = 120.0
		lvl_sparks.scale_amount_min = 2.0
		lvl_sparks.scale_amount_max = 5.0
		var gr := Gradient.new()
		gr.offsets = PackedFloat32Array([0.0, 0.2, 1.0])
		gr.colors = PackedColorArray([Color(1, 0.9, 0.5, 0), Color(1, 0.88, 0.5, 0.9), Color(0.6, 1, 0.9, 0)])
		lvl_sparks.color_ramp = gr
		layer.add_child(lvl_sparks)
		layer.move_child(lvl_sparks, 2)
	lvl_sparks.position = get_viewport().get_visible_rect().size * Vector2(0.5, 0.78)
	lvl_sparks.restart()
	lvl_rays.modulate = Color(1, 1, 1, 0)
	_ptween().tween_property(lvl_rays, "modulate", Color(1, 1, 1, 1), 0.4)
	head.scale = Vector2(0.4, 0.4)
	var tw := _ptween()
	tw.tween_property(head, "scale", Vector2(1.12, 1.12), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(head, "scale", Vector2.ONE, 0.15)

# Stufe aufsteigen, wenn die Erfahrung reicht. Ein großer Edelstein kann für mehrere Stufen reichen: der Rest bleibt in xp,
# nach jeder Kartenwahl wird erneut geprüft (sonst klebte der Balken voll bis zum nächsten Edelstein).
func _try_level_up() -> bool:
	# Nie zwei Kartenwahlen übereinander (z. B. Edelstein im selben Bild wie die Nachprüfung nach einer Wahl): die zweite
	# hätte die Karten der ersten mitten in der Einblendung gelöscht ("Lambda capture ... was freed", Wahl hing).
	# Was übrig ist, prüft der Abschluss der offenen Wahl nach.
	if dead or xp < xp_next or choice_layer.visible:
		return false
	xp -= xp_next
	level += 1
	xp_next = Defs.xp_need(level)
	_level_up()
	if bot:      # Bot wählt sofort, keine Pause dazwischen
		_try_level_up()
	return true

func _level_up(chest: bool = false) -> void:
	if bot:
		if not OS.has_environment("WW_NOCARDS"):
			_apply_card(_bot_pick(_make_cards()))
		return
	mouse_down = false
	has_target = false
	vfx.firework(player.position, 3, ["gold", "teal", "pink"], 4.5)
	vfx.pillar(player.position, Color(0.5, 1.0, 0.9), 1.4)
	vfx.burst("level", player.position + Vector3(0, 0.8, 0))
	vfx.ring(player.position, 0.5, 6.5, 0.7, Color(0.5, 1.0, 0.9, 1.0))
	_sigil(player.position, 4.2, 1.1)
	vfx.ring(player.position, 0.2, 4.0, 0.5, Color(1.0, 0.9, 0.5, 0.8))
	vfx.flash(player.position + Vector3(0, 1.5, 0), Color(0.6, 1.0, 0.9), 6.0, 12.0, 0.6)
	cards = _make_cards()
	for c in choice_box.get_children():
		c.queue_free()
	var head := _label("Runentruhe!" if chest else "Stufe %d!" % level, 40, Color(1.0, 0.86, 0.42))
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.pivot_offset = Vector2(385, 26)
	choice_box.add_child(head)
	var sub := _label("Wähle deine Belohnung", 18, Color(0.85, 0.95, 0.92))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	choice_box.add_child(sub)
	_levelup_fx(head)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	choice_box.add_child(row)
	choice_actions.clear()
	for k in cards.size():
		var card: Dictionary = cards[k]
		choice_actions.append(func(): _apply_card(card))
		row.add_child(_build_card(card, k))
	choice_layer.visible = true
	get_tree().paused = true
	choice_busy = false
	for k in row.get_child_count():   # Karten springen nacheinander ins Bild, danach Glanzstreifen
		var cd_: Control = row.get_child(k)
		cd_.scale = Vector2(0.55, 0.55)
		cd_.modulate = Color(1, 1, 1, 0)
		var tw := _ptween().bind_node(cd_)   # an die Karte gebunden: endet mit ihr, greift nie ins Leere
		tw.tween_interval(0.08 + 0.09 * k)
		tw.tween_property(cd_, "modulate", Color(1, 1, 1, 1), 0.16)
		tw.parallel().tween_property(cd_, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_callback(func(): cd_.set_meta("ready", true))
		var shn: Control = cd_.get_meta("shine")
		tw.tween_property(shn, "position:x", 520.0, 0.5).set_trans(Tween.TRANS_SINE)
		tw.tween_callback(func(): shn.visible = false)
		if cd_.get_meta("special", false):   # goldene Karten pulsieren sanft
			var pulse := _ptween().bind_node(cd_).set_loops()
			pulse.tween_property(cd_, "self_modulate", Color(1.25, 1.15, 0.9), 0.6).set_trans(Tween.TRANS_SINE)
			pulse.tween_property(cd_, "self_modulate", Color(1, 1, 1), 0.6).set_trans(Tween.TRANS_SINE)
			cd_.set_meta("pulse", pulse)
	if Input.get_connected_joypads().size() > 0:   # mit Controller: erste Karte vorauswählen
		(row.get_child(0) as Control).call_deferred("grab_focus")

# ---------- Props (Wald) ----------
# ---------- Arena ----------
func _in_arena(p: Vector3, margin: float = 0.0) -> bool:
	var h: Vector2 = Defs.ARENA_HALF
	return absf(p.x) <= h.x - margin and absf(p.z) <= h.y - margin

func _clamp_arena(p: Vector3, r: float = 0.0) -> Vector3:
	var h: Vector2 = Defs.ARENA_HALF - Vector2.ONE * (Defs.WALL_INSET + r)
	p.x = clampf(p.x, -h.x, h.x)
	p.z = clampf(p.z, -h.y, h.y)
	return p

# Spiegel-Faltung: Punkt einer geraden Bahn, die an den Arena-Wänden abprallt (für Sichel u. ä.)
func _fold(v: float, lim: float) -> float:
	var w := 4.0 * lim
	var t := fposmod(v + lim, w)
	return (t if t <= 2.0 * lim else w - t) - lim

func _fold_arena(p: Vector3) -> Vector3:
	var h: Vector2 = Defs.ARENA_HALF - Vector2.ONE * 0.8
	return Vector3(_fold(p.x, h.x), p.y, _fold(p.z, h.y))

# Spawnpunkt außerhalb des Bildes, aber in der Arena (bevorzugt vor der Figur)
func _spawn_point(bias_dir: Vector3 = Vector3.ZERO) -> Vector3:
	for k in 14:
		var a := rng.randf() * TAU
		if bias_dir != Vector3.ZERO and k < 7:
			a = atan2(bias_dir.z, bias_dir.x) + rng.randf_range(-1.1, 1.1)
		var p := player.position + Vector3(cos(a), 0, sin(a)) * rng.randf_range(15.0, 19.0)
		if _in_arena(p, Defs.WALL_INSET + 0.5):
			return p
	# Figur steht in einer Ecke: weitester Punkt einer Zufallsauswahl in der Arena
	var best := Vector3.ZERO
	var bd := -1.0
	for k in 10:
		var h: Vector2 = Defs.ARENA_HALF - Vector2.ONE * (Defs.WALL_INSET + 0.5)
		var q := Vector3(rng.randf_range(-h.x, h.x), 0, rng.randf_range(-h.y, h.y))
		var d := q.distance_to(player.position)
		if d > bd:
			bd = d
			best = q
	return best

func _build_walls() -> void:
	# Dichte Wand aus Level-Props entlang des Rechtecks (zwei versetzte Reihen), außerhalb der Spielfläche
	var list: Array = lv.get("wall", [])
	if list.is_empty():
		return
	var h: Vector2 = Defs.ARENA_HALF
	var wr := RandomNumberGenerator.new()
	wr.seed = 4242
	var seg: Array = list[0]      # eigenes Wandteil (falls im Asset Desk vorhanden) -> durchgehende Reihe
	var has_seg: bool = _scene_or_null(M + seg[0]) != null
	for side in 4:
		var horiz := side < 2
		var length: float = (h.x if horiz else h.y) * 2.0 + 6.0
		var step := 2.4 if not has_seg else float(seg[3]) * 0.92
		var cnt := int(length / step)
		for row in (1 if has_seg else 2):
			for k in cnt + 1:
				var t := -length * 0.5 + (k + 0.5 * row) * step
				var outward := 0.8 + row * 2.2 + wr.randf_range(0.0, 0.8)
				var pos := Vector3(t, 0, (h.y + outward) * (1 if side == 0 else -1)) if horiz else Vector3((h.x + outward) * (1 if side == 2 else -1), 0, t)
				var pt: Array = seg
				if not has_seg:
					var r := wr.randf()
					var acc := 0.0
					for item in list.slice(1):
						acc += float(item[1])
						pt = item
						if r <= acc:
							break
				var file: String = pt[0]
				if pt.size() > 4 and _scene_or_null(M + file) == null:
					file = pt[4]
				var n := _make_model(file, pt[2], pt[3])
				if file != pt[0]:
					_tint_model(n, lv["tint"])
				n.position = pos
				n.rotation.y = (0.0 if horiz else PI * 0.5) if has_seg else wr.randf() * TAU
				n.scale = Vector3.ONE * (1.0 if has_seg else wr.randf_range(0.8, 1.25))
				add_child(n)

# Kreis (pos, r) aus allen Prop-Kollisionen in den Nachbarzellen herausschieben -> Gleiten an Hindernissen
func _push_out(pos: Vector3, r: float) -> Vector3:
	const CELL := 7.0
	var cx := int(floor(pos.x / CELL))
	var cz := int(floor(pos.z / CELL))
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			var cl: Array = prop_cols.get(Vector2i(cx + dx, cz + dz), [])
			for c in cl:
				var cp: Vector3 = c[0]
				var min_d: float = float(c[1]) + r
				var ox := pos.x - cp.x
				var oz := pos.z - cp.z
				var d2 := ox * ox + oz * oz
				if d2 < min_d * min_d:
					var d := sqrt(d2)
					if d < 0.001:
						ox = 1.0
						oz = 0.0
						d = 1.0
					pos.x = cp.x + ox / d * min_d
					pos.z = cp.z + oz / d * min_d
	return pos

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
			var cols: Array = []
			var cell_c := Vector3((cx + 0.5) * CELL, 0, (cz + 0.5) * CELL)
			if h % 100 < 55 and (absi(cx) + absi(cz)) > 1 and _in_arena(cell_c, 4.5):  # Startbereich frei, nur in der Arena
				var r := float((h / 100) % 100) / 100.0
				var pt: Array = (lv["props"] as Array)[0]
				var acc := 0.0
				for t in (lv["props"] as Array):
					acc += t[1]
					if r * 1.0 <= acc:
						pt = t
						break
				var file: String = pt[0]
				if pt.size() > 4 and _scene_or_null(M + file) == null:
					file = pt[4]      # Platzhalter-Modell, bis das Level-Asset da ist
				var n := _make_model(file, pt[2], pt[3])
				if file != pt[0]:
					_tint_model(n, lv["tint"])
				n.position = Vector3((cx + float((h / 7) % 100) / 100.0) * CELL, 0, (cz + float((h / 13) % 100) / 100.0) * CELL)
				n.rotation.y = float((h / 17) % 360) * PI / 180.0
				n.scale = Vector3.ONE * (0.85 + float((h / 19) % 40) / 100.0)
				add_child(n)
				list.append(n)
				if Defs.PROP_COLLIDE.has(file):
					cols.append([n.position, float(Defs.PROP_COLLIDE[file]) * n.scale.x])
					if OS.has_environment("WW_COLDEBUG"):   # Test: Kollisionskreise anzeigen
						var dbg := MeshInstance3D.new()
						var cyl := CylinderMesh.new()
						cyl.top_radius = float(Defs.PROP_COLLIDE[file])
						cyl.bottom_radius = cyl.top_radius
						cyl.height = 0.1
						dbg.mesh = cyl
						var dm := _glow_mat(Color(1, 0.1, 0.1))
						dm.no_depth_test = true
						dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
						dm.albedo_color.a = 0.5
						dbg.material_override = dm
						n.add_child(dbg)
			props[key] = list
			prop_cols[key] = cols
	for key in props.keys():
		if absi(key.x - pcx) > 8 or absi(key.y - pcz) > 8:
			for n in props[key]:
				n.queue_free()
			props.erase(key)
			prop_cols.erase(key)

# ---------- UI / Ende ----------
func _slot_tooltip(kind: String, id: String, l: int) -> String:
	if kind == "weapon":
		var d: Dictionary = Defs.WEAPONS[id]
		var st := Defs.weapon_stats(id, l)
		var lines := ["%s   ·   Stufe %d / %d" % [d["name"], l, d["max"]], d["desc"], ""]
		var labels: Dictionary = d["labels"]
		for k in labels:
			if st.has(k):
				lines.append("%s  %s" % [labels[k][0], labels[k][1] % st[k]])
		return "\n".join(lines)
	var pd: Dictionary = Defs.PASSIVES[id]
	return "%s   ·   Stufe %d / %d\n%s pro Stufe\n\nGesamt: %s" % [pd["name"], l, pd["max"], pd["desc"], Defs.passive_total(id, l)]

func _hud_theme() -> Theme:
	var th := Theme.new()
	var tsb := _sb(Color(0.03, 0.08, 0.08, 0.96), Color(0.4, 0.9, 0.8, 0.7), 8, 2)
	tsb.set_content_margin_all(12)
	th.set_stylebox("panel", "TooltipPanel", tsb)
	th.set_font_size("font_size", "TooltipLabel", 20)
	th.set_color("font_color", "TooltipLabel", Color(0.9, 0.97, 0.95))
	return th

func _refresh_slots() -> void:
	if slot_box == null:
		return
	for c in slot_box.get_children():
		c.queue_free()
	if slot_box.theme == null:
		slot_box.theme = _hud_theme()
	# Oben Waffen, darunter Ausrüstung (Passive); freie Plätze angedeutet
	var rows := [["weapon", weapons, Defs.MAX_WEAPONS, "WAFFEN"], ["passive", passives, Defs.MAX_PASSIVES, "AUSRÜSTUNG"]]
	var y := 0.0
	for r in rows:
		var cap := _label(r[3], 13, Color(0.65, 0.8, 0.78))
		cap.position = Vector2(2, y)
		slot_box.add_child(cap)
		y += 18.0
		var ids: Array = (r[1] as Dictionary).keys()
		for k in int(r[2]):
			var slot := PanelContainer.new()
			slot.position = Vector2(k * 60.0, y)
			slot.custom_minimum_size = Vector2(54, 54)
			if k < ids.size():
				var id: String = ids[k]
				var acc: Color = Icon.ACCENTS.get(id, Color(0.8, 0.9, 0.9))
				slot.add_theme_stylebox_override("panel", _sb(Color(0.03, 0.07, 0.07, 0.85), Color(acc.r, acc.g, acc.b, 0.7), 8, 1))
				var holder := Control.new()
				holder.custom_minimum_size = Vector2(54, 54)
				holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
				var ic := Icon.make(id, 42)
				ic.position = Vector2(6, 4)
				holder.add_child(ic)
				var lvl: int = r[1][id]
				var lv := _label(str(lvl), 18, Color(1, 0.95, 0.7))
				lv.position = Vector2(34, 30)
				lv.mouse_filter = Control.MOUSE_FILTER_IGNORE
				holder.add_child(lv)
				slot.add_child(holder)
				slot.tooltip_text = _slot_tooltip(r[0], id, lvl)
				slot.mouse_filter = Control.MOUSE_FILTER_STOP
			else:
				slot.add_theme_stylebox_override("panel", _sb(Color(0.02, 0.05, 0.05, 0.35), Color(0.4, 0.55, 0.55, 0.25), 8, 1))
				slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
			slot_box.add_child(slot)
		y += 62.0

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
	if victory:
		play_cast("cheer", 3.0)
		vfx.firework(player.position, 12, ["gold", "teal", "pink", "green", "violet"], 7.0)
	else:
		death_t = 0.0
	var earned := Meta.finish_run(time, kills, level, victory, bonus_shards)
	if bot:
		print("SIMEND %s time=%02d:%02d lvl=%d kills=%d shards=%d bonus=%d schaden=%s" % ["SIEG" if victory else "TOD", int(time) / 60, int(time) % 60, level, kills, earned, bonus_shards, str(sim["src"])])
		get_tree().quit()
		return
	if not victory:
		await get_tree().create_timer(2.0).timeout     # Todesanimation abwarten, dann Ergebnis
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
	var b2 := MenuUI.btn("Hauptmenü  (B)", Vector2(280, 68), 28)
	b2.pressed.connect(_to_menu)
	var b3 := MenuUI.btn("Beenden", Vector2(220, 68), 28, Color(1.0, 0.5, 0.45))
	b3.pressed.connect(func(): get_tree().quit())
	row.add_child(b1)
	row.add_child(b2)
	row.add_child(b3)
	v.add_child(row)
	cc.add_child(panel)
	end_layer.visible = true
	MenuUI.focus_first(panel)

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
