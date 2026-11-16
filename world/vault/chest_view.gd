class_name ChestView
extends Node2D
## Coffre antique (Reliquaire d'ardoise tyrienne, planche planches/coffre-antique-propositions.html, piste A)
## posé dans la réserve scellée à l'est de la salle. Invisible tant que la réserve n'est pas découverte.
## Planche de sprites exportée par planches/coffre-export.html : rangées fermé (boucle des glyphes),
## ouverture (une fois, à GameState.chest_opened_at) et ouvert (boucle). Origine du nœud : milieu du bas
## de la face avant, au sol.

const SHEET := "res://assets/baked/world/chest_ardoise.png"
const META := "res://assets/baked/world/chest_ardoise.json"

var state: TerrainState
var _tex: Texture2D
var _frame := Vector2.ZERO
var _anchor := Vector2.ZERO
var _count := 16
var _fps := 5.6
var _open_time := 1.2


func setup(terrain_state: TerrainState) -> void:
	state = terrain_state
	_tex = load(SHEET)
	var m: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(META))
	_frame = Vector2(m["frame"][0], m["frame"][1])
	_anchor = Vector2(m["anchor"][0], m["anchor"][1])
	_count = int(m["count"])
	_fps = float(m["loop_fps"])
	_open_time = float(m["open_time"])
	position = Proj.nat(CaveShape.CHEST.x, 0.0, CaveShape.CHEST.y)


## Rangée et image affichées à l'instant t (0 fermé, 1 ouverture, 2 ouvert).
func frame_at(t: float) -> Vector2i:
	var since := t - GameState.chest_opened_at
	if since < 0.0 or is_inf(GameState.chest_opened_at):
		return Vector2i(posmod(floori(t * _fps), _count), 0)
	if since < _open_time:
		return Vector2i(mini(_count - 1, floori(since / _open_time * (_count - 1))), 1)
	return Vector2i(posmod(floori(t * _fps), _count), 2)


func _process(_delta: float) -> void:
	visible = state != null and state.vault_open
	if visible:
		queue_redraw()


func _draw() -> void:
	var f := frame_at(GameState.sim_time)
	draw_texture_rect_region(_tex, Rect2(-_anchor, _frame), Rect2(Vector2(f.x, f.y) * _frame, _frame))
