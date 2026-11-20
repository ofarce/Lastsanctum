class_name VaultHint
extends Node2D
## Indice de la réserve scellée : un glyphe tyrien gravé dans la roche, au bord de la paroi est de la salle,
## qui pulse en cyan (même langage que la frise du coffre). Il suit le front de taille : quand la première
## case est creusée, il passe sur la roche restante. Disparaît quand la réserve est découverte.

## Rangée de la paroi où le glyphe est gravé (milieu de la case (14, −37) puis (15, −37)).
const ROW_Z := -146.0
const GLYPH := ["..#.#..", ".#####.", "#..#..#", "#.###.#", "#..#..#", ".#####.", "..#.#.."]
## Fissures qui partent du glyphe (pixels natifs, relatifs à son coin haut-gauche).
const CRACKS := [Vector2i(-1, 3), Vector2i(-2, 3), Vector2i(-3, 4), Vector2i(7, 2), Vector2i(8, 1), Vector2i(9, 1),
	Vector2i(3, 7), Vector2i(3, 8), Vector2i(4, 9), Vector2i(3, -1), Vector2i(2, -2)]
const DIM := Color("#12596b")
const MID := Color("#1f9fb8")
const LIT := Color("#5ce8ff")
const HOT := Color("#c8fbff")
const CRACK := Color("#0b0a0e")

var state: TerrainState
var _edge_state: TerrainState
var _edge_version := -1
var _edge_x := 0.0


func setup(terrain_state: TerrainState) -> void:
	state = terrain_state


## Bord de roche de la rangée : premier point non praticable en partant de la salle, vers l'est.
func edge_x() -> float:
	# Parcours de ~100 appels à walkable : mis en cache tant que la praticabilité ne change pas (state.version,
	# comme les chemins en cache) ; appelé à chaque image par le glyphe et par l'éclairage.
	if _edge_state == state and _edge_version == state.version:
		return _edge_x
	var x := 50.0
	while x < CaveShape.VAULT_X0 and state.walkable(x, ROW_Z):
		x += 0.125
	_edge_state = state
	_edge_version = state.version
	_edge_x = x
	return x


func _process(_delta: float) -> void:
	visible = state != null and not state.vault_open
	if not visible:
		return
	position = Proj.nat(edge_x() + 0.75, 0.0, ROW_Z)
	queue_redraw()


## Éclat (0..1) d'un pixel du glyphe : vague lente du bas vers le haut, plus une respiration d'ensemble.
static func glow(row: int, t: float) -> float:
	return clampf(0.35 + 0.3 * sin(t * 1.6) + 0.45 * sin(t * 2.4 - row * 0.7), 0.0, 1.0)


func _draw() -> void:
	var t := GameState.sim_time
	var o := Vector2(-3, -3)
	for c: Vector2i in CRACKS:
		draw_rect(Rect2(o + Vector2(c), Vector2.ONE), CRACK)
	for j in GLYPH.size():
		var g := glow(GLYPH.size() - 1 - j, t)
		var col := HOT if g > 0.88 else LIT if g > 0.6 else MID if g > 0.3 else DIM
		for i in GLYPH[j].length():
			if GLYPH[j][i] == "#":
				draw_rect(Rect2(o + Vector2(i, j), Vector2.ONE), col)
