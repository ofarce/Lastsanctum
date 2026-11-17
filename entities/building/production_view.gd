class_name ProductionView
extends Node2D
## Rendu de la production d'un bâtiment servi par des adeptes (sim/production.gd), dans le tri en profondeur du monde.
##  - Coffres A retenus (planches/coffres-production-propositions.html) : coffret d'ardoise émaillé bleu à gauche
##    (ingrédients), grenat à droite (produits), devant les bâtiments producteurs. Le coffre s'entrouvre à chaque
##    dépôt ou retrait (Building.chest_in_at / chest_out_at). Planche exportée par planches/production-export.html.
##  - Arrêt 2 retenu : quand personne n'est au poste, silhouette en pointillé clair d'un adepte du culte du bâtiment
##    à la première place de travail ; elle disparaît dès qu'un travailleur y est.
## Origine du nœud : ligne des coffres, au sol.

const SHEET := "res://assets/baked/world/production_chests.png"
const META := "res://assets/baked/world/production_chests.json"
## Ouverture d'un coffre : montée, tenue, descente (secondes).
const OPEN := [0.2, 0.45, 0.75]
const DASH := Color("#c4cad8")

static var _tex: Texture2D
static var _meta: Dictionary
## Silhouettes en pointillé par culte : trois phases de tirets {"tex": [ImageTexture ×3], "anchor": Vector2}.
static var _ghosts := {}

var building: Building
var world: World


func setup(b: Building, w: World) -> void:
	building = b
	world = w
	if _tex == null:
		_tex = load(SHEET)
		_meta = JSON.parse_string(FileAccess.get_file_as_string(META))
	position = Proj.nat(b.x, 0.0, Production.chest_pos(b, "in").y)


func _process(_delta: float) -> void:
	var b := building
	var bv := world.building_view(b) if world else null
	visible = b.complete and Production.staffed(b) and (bv == null or bv.visible)
	if visible:
		queue_redraw()


## Ouverture (0 fermé … 1 ouvert) d'un coffre dont le dernier mouvement date de `at`.
static func openness(at: float, now: float) -> float:
	var s := now - at
	if s < 0.0 or s >= OPEN[2]:
		return 0.0
	if s < OPEN[0]:
		return s / OPEN[0]
	if s < OPEN[1]:
		return 1.0
	return 1.0 - (s - OPEN[1]) / (OPEN[2] - OPEN[1])


func _draw() -> void:
	var b := building
	var now := GameState.sim_time
	if Production.idle(b):
		_draw_ghost(Proj.nat(Production.post_spot(b, 0).x, 0.0, Production.post_spot(b, 0).y) - position, now)
	if not Production.has_chests(b):
		return
	var frame := Vector2(_meta["frame"][0], _meta["frame"][1])
	var anchor := Vector2(_meta["anchor"][0], _meta["anchor"][1])
	var count := int(_meta["count"])
	for kind: String in Production.chest_kinds(b):
		var p := Production.chest_pos(b, kind)
		var o := openness(b.chest_in_at if kind == "in" else b.chest_out_at, now)
		var i := clampi(roundi(o * (count - 1)), 0, count - 1)
		var row := int(_meta["rows"][kind])
		draw_texture_rect_region(_tex, Rect2(Proj.nat(p.x, 0.0, p.y) - position - anchor, frame),
			Rect2(Vector2(i, row) * frame, frame))


func _draw_ghost(at: Vector2, now: float) -> void:
	var g := ghost(Production.staff_role(building))
	if g.is_empty():
		return
	var tex: Texture2D = g["tex"][posmod(floori(now * 6.0), 3)]
	var a := 0.55 + 0.3 * sin(now * 3.0)
	draw_set_transform(at, 0.0, Vector2(AdeptView.SCALE, AdeptView.SCALE))
	draw_texture(tex, -g["anchor"], Color(1, 1, 1, a))
	draw_set_transform(Vector2.ZERO)


## Contour en pointillé de l'image de repos d'un adepte du culte `role` (pixels transparents bordant le personnage).
static func ghost(role: String) -> Dictionary:
	if _ghosts.has(role):
		return _ghosts[role]
	var path := "res://assets/baked/adepts/%s_idle.png" % role
	if not ResourceLoader.exists(path):
		_ghosts[role] = {}
		return {}
	var src := (load(path) as Texture2D).get_image()
	src.decompress()
	var w := src.get_width()
	var h := src.get_height()
	var R: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/baked/manifest.json"))["adepts"]["roles"][role]
	var solid := func(x: int, y: int) -> bool: return x >= 0 and y >= 0 and x < w and y < h and src.get_pixel(x, y).a > 0.5
	var list: Array[ImageTexture] = []
	for phase in 3:
		var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
		for y in h:
			for x in w:
				if solid.call(x, y) or (x + y + phase) % 3 == 0:
					continue
				if solid.call(x - 1, y) or solid.call(x + 1, y) or solid.call(x, y - 1) or solid.call(x, y + 1):
					img.set_pixel(x, y, DASH)
		list.append(ImageTexture.create_from_image(img))
	_ghosts[role] = {"tex": list, "anchor": Vector2(R["ax"], R["ay"])}
	return _ghosts[role]
