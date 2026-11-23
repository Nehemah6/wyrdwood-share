class_name MenuUI
extends Control
## Hauptmenü: Spielen (Levelwahl) · Verstärkungen (Meta-Shop) · Optionen · Beenden. Liegt über der 3D-Waldszene.

signal start_run(level_id: String)
signal quit_game

var screen := "main"
var content: Control

static func sb(bg: Color, border: Color = Color(0, 0, 0, 0), radius: int = 8, bw: int = 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	return s

static func lab(text: String, size: int, col: Color = Color(1, 1, 1)) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 8)
	return l

static func btn(text: String, size: Vector2, font: int = 32, accent: Color = Color(0.4, 0.9, 0.8)) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = size
	b.add_theme_font_size_override("font_size", font)
	b.add_theme_stylebox_override("normal", sb(Color(0.05, 0.11, 0.11, 0.92), Color(accent.r, accent.g, accent.b, 0.5), 10, 2))
	b.add_theme_stylebox_override("hover", sb(Color(0.1, 0.24, 0.23, 0.96), accent, 10, 2))
	b.add_theme_stylebox_override("pressed", sb(Color(0.16, 0.38, 0.35, 1), accent, 10, 2))
	b.add_theme_stylebox_override("focus", sb(Color(0.1, 0.24, 0.23, 0.35), Color(1, 1, 1, 0.95), 10, 3))   # Controller-Auswahl
	b.add_theme_stylebox_override("disabled", sb(Color(0.05, 0.07, 0.07, 0.8), Color(0.3, 0.35, 0.35, 0.4), 10, 1))
	b.add_theme_color_override("font_disabled_color", Color(0.5, 0.55, 0.55))
	return b

# Controller: ersten Knopf (oder den gewünschten) fokussieren, damit Stick/Steuerkreuz + A sofort funktionieren
static func focus_first(root: Node, force: bool = false) -> void:
	if not force and Input.get_connected_joypads().is_empty():
		return      # nur mit Controller: Maus-Spieler sehen keinen Dauer-Rahmen
	for b in root.find_children("*", "Button", true, false):
		var bb := b as Button
		if bb.visible and not bb.disabled and bb.focus_mode != Control.FOCUS_NONE:
			bb.call_deferred("grab_focus")
			return

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS
	process_mode = Node.PROCESS_MODE_ALWAYS
	_show("main")

func _unhandled_input(event: InputEvent) -> void:
	if (event is InputEventJoypadButton or event is InputEventJoypadMotion) and get_viewport().gui_get_focus_owner() == null:
		focus_first(content, true)   # Controller erst jetzt benutzt -> Auswahl einblenden
	# Esc oder Controller B: eine Ebene zurück
	if event.is_action_pressed("ui_cancel") and screen != "main":
		_show("main")
		get_viewport().set_input_as_handled()

func _clear() -> void:
	if content != null:
		content.queue_free()
	content = Control.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(content)

func _show(which: String) -> void:
	screen = which
	_clear()
	match which:
		"main": _build_main()
		"levels": _build_levels()
		"shop": _build_shop()
		"options": _build_options()
	focus_first(content)

func _shards_label() -> Label:
	var l := lab("Wurzelsplitter  %d" % Meta.shards, 32, Color(1.0, 0.85, 0.4))
	l.anchor_left = 1.0
	l.anchor_right = 1.0
	l.offset_left = -520
	l.offset_right = -60
	l.offset_top = 36
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	return l

func _panel_frame(title: String) -> VBoxContainer:
	# Zentrierter Rahmen mit Titel + Zurück-Knopf unten; liefert den Inhaltsbereich
	var back := ColorRect.new()
	back.color = Color(0, 0.02, 0.03, 0.62)
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(back)
	content.add_child(_shards_label())
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.add_child(cc)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", sb(Color(0.04, 0.09, 0.09, 0.96), Color(0.4, 0.9, 0.8, 0.7), 16, 2))
	cc.add_child(panel)
	var pad := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 34)
	panel.add_child(pad)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 20)
	pad.add_child(v)
	var head := lab(title, 48, Color(0.75, 1.0, 0.95))
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(head)
	return v

func _back_button(v: VBoxContainer) -> void:
	var b := btn("Zurück  (Esc / B)", Vector2(300, 60), 28)
	b.pressed.connect(func(): _show("main"))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(b)
	v.add_child(row)

func _build_main() -> void:
	content.add_child(_shards_label())
	var title := lab("WYRDWOOD", 120, Color(0.8, 1.0, 0.95))
	title.position = Vector2(120, 110)
	content.add_child(title)
	var sub := lab("S U R V I V O R S", 38, Color(1.0, 0.85, 0.5))
	sub.position = Vector2(128, 250)
	content.add_child(sub)
	var col := VBoxContainer.new()
	col.position = Vector2(124, 400)
	col.add_theme_constant_override("separation", 18)
	content.add_child(col)
	for item in [["Spielen", "levels"], ["Verstärkungen", "shop"], ["Optionen", "options"]]:
		var b := btn(item[0], Vector2(440, 74), 36)
		var target: String = item[1]
		b.pressed.connect(func(): _show(target))
		col.add_child(b)
	var q := btn("Beenden", Vector2(440, 74), 36, Color(1.0, 0.5, 0.45))
	q.pressed.connect(func(): quit_game.emit())
	col.add_child(q)
	var best_t := 0.0
	for k in Meta.best:
		best_t = maxf(best_t, float(Meta.best[k]))
	var info := lab("Läufe %d   ·   Kills gesamt %d   ·   Bestzeit %02d:%02d" % [Meta.runs, Meta.total_kills, int(best_t) / 60, int(best_t) % 60], 24, Color(0.7, 0.8, 0.8))
	info.position = Vector2(128, 1010)
	content.add_child(info)

func _build_levels() -> void:
	# Raster mit Vorschaubild je Level; scrollt, wenn es mehr Level werden. Letzte Kachel = "Bald mehr"
	var v := _panel_frame("Level wählen")
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(1530, 690)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 24)
	scroll.add_child(grid)
	for id in Defs.LEVELS:
		grid.add_child(_level_card(id))
	var soon := PanelContainer.new()
	soon.custom_minimum_size = Vector2(480, 660)
	soon.add_theme_stylebox_override("panel", sb(Color(0.03, 0.06, 0.06, 0.6), Color(0.4, 0.5, 0.5, 0.35), 14, 2))
	var sl := lab("Weitere Level\nfolgen …", 32, Color(0.55, 0.65, 0.65))
	sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	soon.add_child(sl)
	grid.add_child(soon)
	_back_button(v)

func _level_card(id: String) -> Control:
	var d: Dictionary = Defs.LEVELS[id]
	var open: bool = Meta.unlocked.has(id)
	var accent: Color = d["env"]["vfog"]
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(480, 660)
	var base := sb(Color(0.05, 0.1, 0.1, 1), Color(accent.r, accent.g, accent.b, 0.7) if open else Color(0.4, 0.4, 0.4, 0.6), 14, 2)
	var hover := sb(Color(0.08, 0.15, 0.15, 1), Color(1, 1, 1, 0.9) if open else Color(0.6, 0.6, 0.6, 0.8), 14, 3)
	card.add_theme_stylebox_override("panel", base)
	card.mouse_entered.connect(func(): card.add_theme_stylebox_override("panel", hover))
	card.mouse_exited.connect(func(): card.add_theme_stylebox_override("panel", base))
	var pad := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 18)
	card.add_child(pad)
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 10)
	pad.add_child(cv)
	# Vorschau: ui/levels/<id>.png, sonst Farbfläche der Stimmung
	var thumb_path := "res://ui/levels/%s.png" % id
	if ResourceLoader.exists(thumb_path):
		var tr := TextureRect.new()
		tr.texture = load(thumb_path)
		tr.custom_minimum_size = Vector2(444, 250)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		if not open:
			tr.modulate = Color(0.45, 0.45, 0.45)
		cv.add_child(tr)
	else:
		var swatch := ColorRect.new()
		swatch.custom_minimum_size = Vector2(444, 250)
		swatch.color = (d["env"]["fog"] as Color).lerp(d["env"]["vfog"], 0.4)
		cv.add_child(swatch)
	var head := HBoxContainer.new()
	head.add_child(lab(d["name"], 36, Color(1, 1, 1)))
	var sp0 := Control.new()
	sp0.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp0)
	var diff: int = d.get("diff", 1)
	head.add_child(lab("Gefahr " + "●".repeat(diff) + "○".repeat(maxi(0, 3 - diff)), 22, Color(1.0, 0.55, 0.45) if diff >= 3 else Color(1.0, 0.8, 0.5)))
	cv.add_child(head)
	var desc := lab(d["desc"], 21, Color(0.85, 0.92, 0.92))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(440, 0)
	cv.add_child(desc)
	cv.add_child(lab("Boss: %s  ·  ab %d:%02d" % [d["boss"]["name"], int(d["boss"]["time"]) / 60, int(d["boss"]["time"]) % 60], 20, Color(0.85, 0.7, 1.0)))
	var bt: float = float(Meta.best.get(id, 0.0))
	cv.add_child(lab("Bestzeit %02d:%02d" % [int(bt) / 60, int(bt) % 60] if bt > 0.0 else "Noch nicht gespielt", 20, Color(0.7, 0.8, 0.8)))
	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cv.add_child(sp)
	if open:
		var go := btn("Starten", Vector2(0, 62), 30)
		go.pressed.connect(func(): start_run.emit(id))
		cv.add_child(go)
		card.gui_input.connect(func(ev: InputEvent):   # Klick auf die Kachel startet ebenfalls
			var mb := ev as InputEventMouseButton
			if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and mb.double_click:
				start_run.emit(id))
	else:
		var cost: int = d["cost"]
		var ub := btn("Freischalten  (%d Splitter)" % cost, Vector2(0, 62), 26, Color(1.0, 0.85, 0.4))
		ub.disabled = Meta.shards < cost
		ub.pressed.connect(func():
			if Meta.unlock_level(id):
				_show("levels"))
		cv.add_child(ub)
	return card

func _build_shop() -> void:
	var v := _panel_frame("Verstärkungen")
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 22)
	grid.add_theme_constant_override("v_separation", 16)
	v.add_child(grid)
	for id in Defs.META_UPGRADES:
		var d: Dictionary = Defs.META_UPGRADES[id]
		var l: int = Meta.lvl(id)
		var mx: int = d["max"]
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(640, 128)
		var acc: Color = Icon.ACCENTS.get(d["icon"], Color(0.8, 0.9, 0.9))
		card.add_theme_stylebox_override("panel", sb(Color(0.05, 0.1, 0.1, 1), Color(acc.r, acc.g, acc.b, 0.55), 12, 2))
		var pad := MarginContainer.new()
		for side in ["left", "right", "top", "bottom"]:
			pad.add_theme_constant_override("margin_" + side, 14)
		card.add_child(pad)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 16)
		pad.add_child(h)
		var ic := Icon.make(d["icon"], 88)
		var icc := CenterContainer.new()
		icc.add_child(ic)
		h.add_child(icc)
		var tv := VBoxContainer.new()
		tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tv.add_child(lab(d["name"], 28, Color(1, 1, 1)))
		var dl := lab(d["desc"], 20, Color(0.8, 0.9, 0.9))
		dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		dl.custom_minimum_size = Vector2(300, 0)
		tv.add_child(dl)
		var pips := ""
		for i in mx:
			pips += "●" if i < l else "○"
		tv.add_child(lab(pips, 18, acc))
		h.add_child(tv)
		var buy: Button
		if l >= mx:
			buy = btn("Max", Vector2(150, 64), 26)
			buy.disabled = true
		else:
			buy = btn("%d" % Meta.upgrade_cost(id), Vector2(150, 64), 28, Color(1.0, 0.85, 0.4))
			buy.disabled = not Meta.can_buy(id)
			buy.pressed.connect(func():
				if Meta.buy(id):
					_show("shop"))
		var bc := CenterContainer.new()
		bc.add_child(buy)
		h.add_child(bc)
		grid.add_child(card)
	_back_button(v)

func _build_options() -> void:
	var v := _panel_frame("Optionen")
	var fs := btn("Vollbild umschalten  (F11)", Vector2(520, 68), 30)
	fs.pressed.connect(func():
		var m := DisplayServer.window_get_mode()
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if m == DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(fs)
	v.add_child(row)
	var skin_names := {"druid": "Druidin", "classic": "Elfe mit Schwert"}
	var sk := btn("Figur:  " + str(skin_names.get(Meta.skin, Meta.skin)), Vector2(520, 68), 30)
	sk.pressed.connect(func():
		Meta.skin = "classic" if Meta.skin == "druid" else "druid"
		Meta.save()
		_show("options"))
	var row_s := HBoxContainer.new()
	row_s.alignment = BoxContainer.ALIGNMENT_CENTER
	row_s.add_child(sk)
	v.add_child(row_s)
	var order := ["native", "ssaa", "fsr2"]
	var up := btn("Grafik:  " + str(Meta.UPSCALE_NAMES[Meta.upscale]), Vector2(760, 68), 28)
	up.pressed.connect(func():
		Meta.upscale = order[(order.find(Meta.upscale) + 1) % order.size()]
		Meta.save()
		Meta.apply_quality(get_viewport())
		_show("options"))
	var row_u := HBoxContainer.new()
	row_u.alignment = BoxContainer.ALIGNMENT_CENTER
	row_u.add_child(up)
	v.add_child(row_u)
	var tips := lab("Steuerung:  WASD / Pfeile   oder   Maus (klicken oder halten = dorthin laufen)\nMausrad = Zoom  ·  Esc = Pause  ·  Level-Up: Karte anklicken oder Taste 1–3\nController:  Stick = laufen  ·  A = wählen  ·  B = zurück  ·  LB/RB = Zoom  ·  Start = Pause", 24, Color(0.8, 0.9, 0.9))
	tips.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(tips)
	var reset := btn("Speicherstand löschen", Vector2(520, 60), 26, Color(1.0, 0.5, 0.45))
	reset.pressed.connect(func():
		Meta.shards = 0
		Meta.upgrades = {}
		Meta.best = {}
		Meta.unlocked = ["wyrdwood"]
		Meta.runs = 0
		Meta.total_kills = 0
		Meta.save()
		_show("options"))
	var row2 := HBoxContainer.new()
	row2.alignment = BoxContainer.ALIGNMENT_CENTER
	row2.add_child(reset)
	v.add_child(row2)
	_back_button(v)
