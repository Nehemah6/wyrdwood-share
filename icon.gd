class_name Icon
extends Control
## Symbol für Waffen/Passive. Nimmt das Asset-Desk-Icon (res://textures/icon_<id>/…), dann res://ui/icons/<id>.png, sonst ein Vektorsymbol.

static var _tex := {}

var icon_id := ""
var accent := Color(0.5, 1.0, 0.9)

const ACCENTS := {
	"thorn": Color(0.65, 0.95, 0.4), "acorn": Color(1.0, 0.7, 0.25), "orbs": Color(0.4, 1.0, 0.95), "roots": Color(0.75, 0.55, 0.3),
	"scythe": Color(0.7, 0.9, 1.0), "chain": Color(0.7, 0.8, 1.0), "spores": Color(0.6, 0.95, 0.5),
	"fireflies": Color(1.0, 0.82, 0.3), "bramble": Color(0.55, 0.8, 0.25), "beam": Color(0.85, 0.75, 1.0), "frost": Color(0.6, 0.9, 1.0), "bark": Color(0.95, 0.68, 0.35),
	"armor": Color(0.75, 0.78, 0.85), "twin": Color(0.6, 1.0, 0.55), "dodge": Color(0.7, 0.85, 1.0), "crit": Color(1.0, 0.9, 0.45),
	"might": Color(1.0, 0.45, 0.35), "swift": Color(0.5, 0.9, 1.0), "vigor": Color(1.0, 0.4, 0.5), "magnet": Color(0.9, 0.5, 1.0),
	"haste": Color(0.6, 0.8, 1.0), "area": Color(0.5, 1.0, 0.8), "regen": Color(0.5, 1.0, 0.55), "greed": Color(1.0, 0.85, 0.35),
}

static func make(id: String, size: float) -> Icon:
	var i := Icon.new()
	i.icon_id = id
	i.accent = ACCENTS.get(id, Color(0.8, 0.9, 0.9))
	i.custom_minimum_size = Vector2(size, size)
	i.size = Vector2(size, size)
	i.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return i

static func _texture(id: String) -> Texture2D:
	if _tex.has(id):
		return _tex[id]
	# Reihenfolge: Asset-Desk-Library (textures/icon_<id>) vor ui/icons/<id>.png vor Vektor-Platzhalter
	var t: Texture2D = null
	for path in ["res://textures/icon_%s/icon_%s_albedo.png" % [id, id], "res://ui/icons/%s.png" % id]:
		if ResourceLoader.exists(path):
			t = load(path)
			break
	_tex[id] = t
	return t

func _draw() -> void:
	var t := _texture(icon_id)
	if t != null:
		draw_texture_rect(t, Rect2(Vector2.ZERO, size), false)
		return
	var s := minf(size.x, size.y)
	var c := accent
	var dark := Color(c.r * 0.35, c.g * 0.35, c.b * 0.35)
	var w := maxf(2.0, s * 0.07)
	var P := func(x: float, y: float) -> Vector2: return Vector2(x, y) * s
	match icon_id:
		"thorn":
			draw_line(P.call(0.18, 0.82), P.call(0.72, 0.28), c, w * 1.2)
			draw_colored_polygon(PackedVector2Array([P.call(0.62, 0.18), P.call(0.86, 0.14), P.call(0.82, 0.38)]), c)
			draw_line(P.call(0.18, 0.82), P.call(0.10, 0.62), dark, w)
			draw_line(P.call(0.18, 0.82), P.call(0.38, 0.90), dark, w)
		"acorn":
			draw_circle(P.call(0.5, 0.6), s * 0.28, c)
			draw_circle(P.call(0.5, 0.36), s * 0.27, dark)
			draw_line(P.call(0.5, 0.12), P.call(0.5, 0.26), c, w)
			draw_arc(P.call(0.5, 0.6), s * 0.28, 0.3, 2.8, 12, dark, w * 0.6)
		"orbs":
			draw_arc(P.call(0.5, 0.5), s * 0.34, 0, TAU, 28, dark, w * 0.7)
			draw_circle(P.call(0.5, 0.5), s * 0.1, c)
			for a in [0.5, 2.6, 4.7]:
				draw_circle(P.call(0.5, 0.5) / s * s + Vector2(cos(a), sin(a)) * s * 0.34, s * 0.09, c)
		"roots":
			for k in 3:
				var x0 := 0.28 + 0.22 * k
				draw_polyline(PackedVector2Array([P.call(x0, 0.9), P.call(x0 + 0.06, 0.62), P.call(x0 - 0.05, 0.42), P.call(x0 + 0.04, 0.16)]), c, w)
			draw_line(P.call(0.1, 0.9), P.call(0.9, 0.9), dark, w)
		"scythe":
			draw_arc(P.call(0.5, 0.6), s * 0.36, PI * 1.05, PI * 1.95, 24, c, w * 1.6)
			draw_line(P.call(0.5, 0.9), P.call(0.5, 0.52), dark, w)
			draw_circle(P.call(0.5, 0.92), s * 0.05, c)
		"chain":
			draw_polyline(PackedVector2Array([P.call(0.62, 0.08), P.call(0.34, 0.48), P.call(0.56, 0.5), P.call(0.3, 0.92)]), c, w * 1.3)
			draw_circle(P.call(0.3, 0.92), s * 0.06, c)
			draw_circle(P.call(0.62, 0.08), s * 0.06, c)
		"spores":
			draw_arc(P.call(0.5, 0.5), s * 0.38, 0, TAU, 28, dark, w * 0.6)
			for p in [Vector2(0.35, 0.4), Vector2(0.6, 0.35), Vector2(0.5, 0.6), Vector2(0.3, 0.68), Vector2(0.7, 0.62), Vector2(0.52, 0.22)]:
				draw_circle(p * s, s * (0.05 + 0.04 * fmod(p.x * 7.0, 1.0)), c)
		"might":
			for k in 3:
				draw_line(P.call(0.28 + 0.22 * k, 0.12), P.call(0.18 + 0.22 * k, 0.88), c, w * 1.3)
		"swift":
			for k in 2:
				var o := 0.0 + 0.26 * k
				draw_polyline(PackedVector2Array([P.call(0.14 + o, 0.2), P.call(0.42 + o, 0.5), P.call(0.14 + o, 0.8)]), c, w * 1.4)
		"vigor":
			draw_circle(P.call(0.34, 0.36), s * 0.2, c)
			draw_circle(P.call(0.66, 0.36), s * 0.2, c)
			draw_colored_polygon(PackedVector2Array([P.call(0.16, 0.45), P.call(0.84, 0.45), P.call(0.5, 0.88)]), c)
		"magnet":
			draw_arc(P.call(0.5, 0.45), s * 0.28, PI, TAU, 20, c, w * 1.6)
			draw_line(P.call(0.22, 0.45), P.call(0.22, 0.82), c, w * 1.6)
			draw_line(P.call(0.78, 0.45), P.call(0.78, 0.82), c, w * 1.6)
			draw_line(P.call(0.16, 0.82), P.call(0.28, 0.82), Color(1, 0.4, 0.4), w * 1.4)
			draw_line(P.call(0.72, 0.82), P.call(0.84, 0.82), Color(0.4, 0.6, 1), w * 1.4)
		"haste":
			draw_arc(P.call(0.5, 0.5), s * 0.36, 0, TAU, 28, c, w)
			draw_line(P.call(0.5, 0.5), P.call(0.5, 0.26), c, w)
			draw_line(P.call(0.5, 0.5), P.call(0.66, 0.58), c, w)
		"area":
			draw_arc(P.call(0.5, 0.5), s * 0.38, 0, TAU, 28, c, w)
			draw_arc(P.call(0.5, 0.5), s * 0.22, 0, TAU, 20, c, w)
			draw_circle(P.call(0.5, 0.5), s * 0.06, c)
		"regen":
			draw_line(P.call(0.5, 0.2), P.call(0.5, 0.8), c, w * 1.6)
			draw_line(P.call(0.2, 0.5), P.call(0.8, 0.5), c, w * 1.6)
			draw_circle(P.call(0.78, 0.22), s * 0.08, dark)
		"greed":
			draw_circle(P.call(0.5, 0.5), s * 0.36, c)
			draw_circle(P.call(0.5, 0.5), s * 0.26, dark)
			draw_line(P.call(0.5, 0.3), P.call(0.5, 0.7), c, w)
		"fireflies":
			for p2 in [Vector2(0.3, 0.6), Vector2(0.55, 0.35), Vector2(0.72, 0.68)]:
				draw_circle(p2 * s, s * 0.13, Color(c.r, c.g, c.b, 0.3))
				draw_circle(p2 * s, s * 0.06, c)
			draw_polyline(PackedVector2Array([P.call(0.1, 0.85), P.call(0.3, 0.6), P.call(0.55, 0.35), P.call(0.9, 0.15)]), dark, w * 0.6)
		"bramble":
			draw_polyline(PackedVector2Array([P.call(0.1, 0.8), P.call(0.35, 0.6), P.call(0.6, 0.7), P.call(0.9, 0.4)]), c, w * 1.2)
			for p3 in [Vector2(0.22, 0.7), Vector2(0.47, 0.64), Vector2(0.75, 0.55)]:
				draw_colored_polygon(PackedVector2Array([p3 * s + Vector2(-0.05, 0) * s, p3 * s + Vector2(0.05, 0) * s, p3 * s + Vector2(0, -0.16) * s]), c)
		"beam":
			draw_line(P.call(0.12, 0.88), P.call(0.88, 0.12), Color(c.r, c.g, c.b, 0.35), w * 3.0)
			draw_line(P.call(0.12, 0.88), P.call(0.88, 0.12), Color(1, 1, 1), w)
			draw_circle(P.call(0.12, 0.88), s * 0.09, c)
		"frost":
			for k in 6:
				var a := TAU * k / 6.0
				draw_line(P.call(0.5, 0.5), P.call(0.5, 0.5) + Vector2(cos(a), sin(a)) * s * 0.38, c, w)
			draw_arc(P.call(0.5, 0.5), s * 0.42, 0, TAU, 28, dark, w * 0.6)
		"bark":
			draw_colored_polygon(PackedVector2Array([P.call(0.5, 0.1), P.call(0.86, 0.24), P.call(0.8, 0.62), P.call(0.5, 0.9), P.call(0.2, 0.62), P.call(0.14, 0.24)]), c)
			draw_line(P.call(0.5, 0.2), P.call(0.5, 0.8), dark, w)
			draw_line(P.call(0.3, 0.4), P.call(0.7, 0.4), dark, w * 0.7)
		"armor":
			draw_colored_polygon(PackedVector2Array([P.call(0.5, 0.08), P.call(0.86, 0.22), P.call(0.8, 0.6), P.call(0.5, 0.92), P.call(0.2, 0.6), P.call(0.14, 0.22)]), dark)
			draw_polyline(PackedVector2Array([P.call(0.5, 0.08), P.call(0.86, 0.22), P.call(0.8, 0.6), P.call(0.5, 0.92), P.call(0.2, 0.6), P.call(0.14, 0.22), P.call(0.5, 0.08)]), c, w)
			for k in 3:
				draw_line(P.call(0.28, 0.32 + 0.16 * k), P.call(0.72, 0.32 + 0.16 * k), c, w * 0.6)
		"dodge":
			for k in 3:
				draw_arc(P.call(0.5 + 0.08 * k, 0.5), s * (0.32 - 0.07 * k), PI * 0.6, PI * 1.4, 16, Color(c.r, c.g, c.b, 1.0 - 0.28 * k), w)
			draw_circle(P.call(0.72, 0.5), s * 0.08, c)
		"twin":
			for k in 2:
				var cx := 0.36 + 0.28 * k
				draw_colored_polygon(PackedVector2Array([P.call(cx, 0.2), P.call(cx + 0.13, 0.5), P.call(cx, 0.82), P.call(cx - 0.13, 0.5)]), c)
				draw_line(P.call(cx, 0.28), P.call(cx, 0.74), dark, w * 0.6)
		"crit":
			var pts := PackedVector2Array()
			for k in 10:
				var a := -PI / 2 + TAU * k / 10.0
				var rr := 0.4 if k % 2 == 0 else 0.17
				pts.append(P.call(0.5, 0.52) + Vector2(cos(a), sin(a)) * s * rr)
			draw_colored_polygon(pts, c)
		_:
			draw_circle(P.call(0.5, 0.5), s * 0.3, c)
