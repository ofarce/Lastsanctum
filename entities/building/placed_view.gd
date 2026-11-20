class_name PlacedView
extends Node2D
## Rendu d'une défense de l'Atelier posée au sol (sim/placeables.gd), dans le tri en profondeur du monde.
## Sprite 320 × 240 exporté par tools/defenses/serve.py (da-<objet>), ancre au centre de la case, échelle native.
## En aperçu (`ghost`), suit la case sous le pointeur en mode pose : vert si la pose est possible, rouge sinon.

const SW := 320
const SH := 240

static var _meta: Dictionary
static var _tex := {}

var placed: Dictionary
var ghost := false
var world: Node
var _item := ""


static func art(item: String) -> Dictionary:
	if _meta.is_empty():
		var m: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/baked/manifest.json"))
		_meta = m["buildings"]["arts"]
	return _meta.get("da-" + item, {})


static func texture(item: String) -> Texture2D:
	if not _tex.has(item):
		_tex[item] = load("res://assets/baked/buildings/da-%s_base.png" % item)
	return _tex[item]


func setup(o: Dictionary) -> void:
	placed = o
	_item = o["item"]
	position = Proj.nat(o["x"], 0.0, o["z"])


var _key: Array = []


func _process(_delta: float) -> void:
	if not ghost:
		# Barricade : redessin quand ses PV ou son bardage changent.
		if _item == "barricade":
			var key := [placed.get("hp", 0.0), placed.get("max_hp", 0.0), GameState.sim_time - float(placed.get("hit_at", -INF)) < 0.12]
			if key != _key:
				_key = key
				queue_redraw()
		return
	var p: Variant = GameState.build_pointer
	visible = GameState.hud_mode == "place" and p != null and not GameState.hud_place_item.is_empty()
	if not visible:
		return
	_item = GameState.hud_place_item
	var c := Simulation.Placeables.cell_of(p)
	var mid := Simulation.Placeables.center(c)
	position = Proj.nat(mid.x, 0.0, mid.y)
	var ok: bool = world.simulation != null and Simulation.Placeables.refusal(world.simulation, _item, mid) == ""
	modulate = Color(0.75, 1.0, 0.8, 0.7) if ok else Color(1.0, 0.45, 0.4, 0.6)
	queue_redraw()


func _draw() -> void:
	if _item.is_empty():
		return
	var A := art(_item)
	if A.is_empty():
		return
	var anchor := Vector2(A["anchor"][0], A["anchor"][1])
	var f := float(A.get("scale", 1.0))
	if ghost:
		# Case visée : contour de 32 px.
		draw_rect(Rect2(-16, -16, 32, 32), Color(1, 1, 1, 0.5), false, 1.0)
	draw_set_transform(-anchor * f, 0.0, Vector2(f, f))
	var struck: bool = not ghost and GameState.sim_time - float(placed.get("hit_at", -INF)) < 0.12
	draw_texture_rect(texture(_item), Rect2(0, 0, SW, SH), false, Color(1.6, 1.6, 1.6) if struck else Color.WHITE)
	if _item != "barricade":
		return
	# Palissades (recherche de la Bibliothèque) : bardage de bois riveté en travers du muret.
	if GameState.research_done.has("palisades"):
		draw_rect(Rect2(145, 164, 31, 1), Color("#d4a462"))
		draw_rect(Rect2(145, 165, 31, 2), Color("#7a4c24"))
		draw_rect(Rect2(145, 167, 31, 1), Color("#1c1008"))
		for x: int in [149, 160, 171]:
			draw_rect(Rect2(x, 165, 1, 1), Color("#d6dce8"))
	# Barre de vie dès qu'elle est entamée.
	var hp := float(placed.get("hp", 0.0))
	var hp_max := float(placed.get("max_hp", 0.0))
	if not ghost and hp_max > 0.0 and hp < hp_max:
		draw_rect(Rect2(148, 144, 26, 3), Color("#000000aa"))
		draw_rect(Rect2(149, 145, 24.0 * clampf(hp / hp_max, 0.0, 1.0), 1), Color("#e2c682"))
