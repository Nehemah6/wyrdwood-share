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
	b.add_theme_stylebox_override("disabled", sb(Color(0.05, 0.07, 0.07, 0.8), Color(0.3, 0.35, 0.35, 0.4), 10, 1))
	b.add_theme_color_override("font_disabled_color", Color(0.5, 0.55, 0.55))
	return b

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS
	process_mode = Node.PROCESS_MODE_ALWAYS
	_show("main")

func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k != null and k.pressed and not k.echo and k.keycode == KEY_ESCAPE and screen != "main":
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
	var b := btn("Zurück  (Esc)", Vector2(300, 60), 28)
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
	var v := _panel_frame("Level wählen")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 28)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(row)
	for id in Defs.LEVELS:
		var d: Dictionary = Defs.LEVELS[id]
		var open: bool = Meta.unlocked.has(id)
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(520, 480)
		card.add_theme_stylebox_override("panel", sb(Color(0.05, 0.1, 0.1, 1), d["env"]["vfog"] if open else Color(0.4, 0.4, 0.4), 14, 2))
		var pad := MarginContainer.new()
		for side in ["left", "right", "top", "bottom"]:
			pad.add_theme_constant_override("margin_" + side, 24)
		card.add_child(pad)
		var cv := VBoxContainer.new()
		cv.add_theme_constant_override("separation", 14)
		pad.add_child(cv)
		cv.add_child(lab(d["name"], 42, Color(1, 1, 1)))
		var swatch := ColorRect.new()
		swatch.custom_minimum_size = Vector2(0, 110)
		swatch.color = (d["env"]["fog"] as Color).lerp(d["env"]["vfog"], 0.4)
		cv.add_child(swatch)
		var desc := lab(d["desc"], 24, Color(0.85, 0.92, 0.92))
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.custom_minimum_size = Vector2(470, 0)
		cv.add_child(desc)
		var bt: float = float(Meta.best.get(id, 0.0))
		cv.add_child(lab("Bestzeit %02d:%02d" % [int(bt) / 60, int(bt) % 60] if bt > 0.0 else "Noch nicht gespielt", 22, Color(0.7, 0.8, 0.8)))
		var sp := Control.new()
		sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
		cv.add_child(sp)
		if open:
			var go := btn("Starten", Vector2(0, 66), 32)
			go.pressed.connect(func(): start_run.emit(id))
			cv.add_child(go)
		else:
			var cost: int = d["cost"]
			var ub := btn("Freischalten  (%d)" % cost, Vector2(0, 66), 28, Color(1.0, 0.85, 0.4))
			ub.disabled = Meta.shards < cost
			ub.pressed.connect(func():
				if Meta.unlock_level(id):
					_show("levels"))
			cv.add_child(ub)
		row.add_child(card)
	_back_button(v)

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
	var tips := lab("Steuerung:  WASD / Pfeile  ·  Mausrad = Zoom  ·  Esc = Pause\nLevel-Up: Karte anklicken oder Taste 1–3", 24, Color(0.8, 0.9, 0.9))
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
