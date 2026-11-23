class_name LodeView
extends GroveView
## Filon illimité posé au sol (2 × 2 cases, planche filons-illimites.html) : même cadrage, même flaque
## et même rai que le bosquet ; un seul aspect par minerai, puisqu'il ne s'épuise jamais.

const LODE_SPRITES := preload("res://assets/ardoise/world/filons.png")
## filons.png : cuivre, fer, or, pierre (fer désaturé), 96 × 104 px chacun (emprise 64 × 64 en (16, 40)).
const LODE_FRAMES := ["copper", "iron", "gold", "rock"]

var _frame := 0


func setup(terrain_state: TerrainState, key: Vector2i) -> void:
	super.setup(terrain_state, key)
	name = "Lode_%d_%d" % [key.x, key.y]
	_frame = maxi(0, LODE_FRAMES.find(terrain_state.lodes.get(key, "")))


func _process(_delta: float) -> void:
	if not state.lodes.has(origin):
		queue_free()
		return
	_update_shake()
	_redraw_light()


func _draw() -> void:
	draw_texture_rect_region(LODE_SPRITES, Rect2(Vector2(-48 + _shake, -104), FRAME), Rect2(Vector2(_frame * FRAME.x, 0), FRAME))
