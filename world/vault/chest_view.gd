class_name ChestView
extends Node2D
## Coffre antique (Reliquaire d'ardoise tyrienne, planche planches/coffre-antique-propositions.html, piste A)
## posé à côté de la capsule (planches/intro-capsule-planche.html), visible dès le départ.
## Planche de sprites exportée par planches/coffre-export.html : rangées fermé (boucle des glyphes),
## ouverture (une fois, à GameState.chest_opened_at), ouvert (boucle) et éteint (glyphes d'ardoise, V1 de la
## planche intro-capsule). Éteint tant que l'Ancre l'est ; à son allumage (GameState.orb_finished_at), l'œil se
## rallume puis les glyphes de la face avant, de gauche à droite (WAKE_*). Origine du nœud : milieu du bas de la
## face avant, au sol.

const SHEET := "res://assets/baked/world/chest_ardoise.png"
const META := "res://assets/baked/world/chest_ardoise.json"

var state: TerrainState
var _tex: Texture2D
var _frame := Vector2.ZERO
var _anchor := Vector2.ZERO
var _count := 16
var _fps := 5.6
var _open_time := 1.2
var _off_row := 3

## Rallumage : l'œil (rangées EYE de l'image) dès l'allumage de l'Ancre, puis la bande des glyphes (rangées BAND)
## balayée de gauche à droite, de la colonne WAKE_X0 à WAKE_X1, entre WAKE_SWEEP.x et WAKE_SWEEP.y secondes.
const EYE := Rect2(0, 26, 56, 20)
const BAND := Rect2(0, 46, 56, 26)
const WAKE_X0 := 12.0
const WAKE_X1 := 46.0
const WAKE_SWEEP := Vector2(0.2, 1.2)


func setup(terrain_state: TerrainState) -> void:
	state = terrain_state
	_tex = load(SHEET)
	var m: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(META))
	_frame = Vector2(m["frame"][0], m["frame"][1])
	_anchor = Vector2(m["anchor"][0], m["anchor"][1])
	_count = int(m["count"])
	_fps = float(m["loop_fps"])
	_open_time = float(m["open_time"])
	_off_row = int((m["rows"] as Dictionary).get("off", 3))
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
	visible = state != null
	if visible:
		queue_redraw()


## Partie `part` (rectangle en pixels de l'image) de l'image f.
func _part(f: Vector2i, part: Rect2) -> void:
	if part.size.x <= 0.0:
		return
	draw_texture_rect_region(_tex, Rect2(-_anchor + part.position, part.size), Rect2(Vector2(f.x, f.y) * _frame + part.position, part.size))


func _draw() -> void:
	if not Capsule.chest_active():
		_part(Vector2i(0, _off_row), Rect2(Vector2.ZERO, _frame))
		return
	var f := frame_at(GameState.sim_time)
	if GameState.hud_chest.get("kind") == "vault":
		ProductionView.halo(self, Vector2(0, -4), 26.0, 11.0)
	var since := GameState.sim_time - GameState.orb_finished_at
	if since >= WAKE_SWEEP.y or since < 0.0:
		_part(f, Rect2(Vector2.ZERO, _frame))
		return
	# Rallumage : image éteinte, puis l'œil et la part déjà balayée de la bande des glyphes, allumés.
	_part(Vector2i(0, _off_row), Rect2(Vector2.ZERO, _frame))
	_part(f, EYE)
	var k := clampf((since - WAKE_SWEEP.x) / (WAKE_SWEEP.y - WAKE_SWEEP.x), 0.0, 1.0)
	_part(f, Rect2(BAND.position, Vector2(floorf(WAKE_X0 + (WAKE_X1 - WAKE_X0) * k), BAND.size.y)))
