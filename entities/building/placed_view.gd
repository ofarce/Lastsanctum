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


func _process(_delta: float) -> void:
	if not ghost:
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
	draw_texture_rect(texture(_item), Rect2(0, 0, SW, SH), false)
