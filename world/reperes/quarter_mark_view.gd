class_name QuarterMarkView
extends Node2D
## Une stèle-glyphe ou une arche aux braseros (sim/quarter_marks.gd), à sa taille native : éteinte, puis allumée
## (glyphe et flammes à la couleur du quartier, flammes animées, lueur). Origine : le pied, dans le tri en profondeur.

const DIR := "res://assets/imported/reperes/"
static var _meta: Dictionary
static var _tex := {}

var mark: Dictionary
var world: World


static func meta() -> Dictionary:
	if _meta.is_empty():
		_meta = JSON.parse_string(FileAccess.get_file_as_string(DIR + "meta.json"))
		for q: String in ["A", "B", "C", "VA", "VB", "VC"]:
			for k: String in ["stele", "arch"]:
				_tex["%s_%s" % [k, q]] = load(DIR + "%s_%s.png" % [k, q])
	return _meta


func setup(m: Dictionary, w: World) -> void:
	mark = m
	world = w
	name = "Repere_%s_%s" % [m["kind"], m["quarter"]]
	meta()
	position = Proj.nat(m["x"], 0.0, m["z"]).round()


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if world != null and not world.fog.known_at(Vector2(mark["x"], mark["z"])):
		return
	var kind: String = mark["kind"]
	var q: String = mark["quarter"]
	var m: Dictionary = meta()[kind]
	var lit := GameState.quarter_lit.has(q)
	var now := GameState.sim_time
	var f := 0
	if lit:
		f = 1 if kind == "stele" else 1 + int(now * 6.0) % 2
	var w := float(m["w"])
	var h := float(m["h"])
	var tex: Texture2D = _tex["%s_%s" % [kind, q]]
	# Arche élargie sur la bouche d'un couloir (QuarterMarks, « span ») : tranches 22 et 34 répétées (linteau, vide,
	# socle), le reste du dessin tel quel ; e colonnes de plus de chaque côté du glyphe.
	var e := 0
	if kind == "arch" and mark.has("span"):
		e = maxi(0, roundi((float(mark["span"]) * Proj.K - QuarterMarks.ARCH_OPEN) / 2.0))
	if e == 0:
		draw_texture_rect_region(tex, Rect2(-float(m["ax"]), -float(m["ay"]), w, h), Rect2(f * w, 0.0, w, h))
	else:
		var x0 := -(w - 2.0 + 2.0 * e) / 2.0
		var y0 := -float(m["ay"])
		var u := f * w
		var x := x0
		for piece: Array in [[0, 22, 1], [22, 1, e], [23, 11, 1], [34, 1, e], [35, 21, 1]]:
			for k in int(piece[2]):
				draw_texture_rect_region(tex, Rect2(x, y0, piece[1], h), Rect2(u + piece[0], 0.0, piece[1], h))
				x += float(piece[1])
	if not lit:
		return
	var col: Color = QuarterMarks.COLOR[q]
	var pulse := 0.5 + 0.5 * sin(now * 3.0 + position.x)
	var glows: Array = [m["glow"]] if kind == "stele" else m["glow"]
	for g: Array in glows:
		var gx := float(g[0])
		if e > 0:
			gx += (2.0 * e - 2.0) if gx > 34.0 else ((e - 1.0) if gx > 22.0 else 0.0)
		var ox := float(m["ax"]) if e == 0 else (w - 2.0 + 2.0 * e) / 2.0
		var c := Vector2(gx - ox, float(g[1]) - float(m["ay"]))
		for k in 3:
			draw_circle(c, 5.0 + k * 4.0, Color(col, (0.12 + 0.06 * pulse) * (1.0 - k * 0.3)))
