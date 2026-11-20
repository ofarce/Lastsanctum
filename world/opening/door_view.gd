class_name DoorView
extends Node2D
## Porte sud de la salle (planche sequence-ouverture-v2.html, 2.1 « Sobre ») : deux battants de rondins
## doublés de trois bandes de bronze vert-de-gris rivetées, gonds massifs, linteau de rondins, poutre de
## blocage sur crochets. Fermée au J1 (sim/opening.gd : GameState.door_closed) ; quand le bouclier se forme,
## la poutre tombe et les battants s'ouvrent vers l'intérieur des piliers.
## Origine : milieu de l'ouverture de la grotte, au pied du flanc (x 0, z = DOOR_Z), tri en profondeur avec les unités.

const K0 := Color("#0b090b")
const WOOD := Color("#5a3b22")
const WOOD_HI := Color("#6b4729")
const WOOD_LO := Color("#3b2614")
const WOOD_DK := Color("#4a311c")
const VERD := Color("#5f8a76")
const VERD_HI := Color("#86b09a")
const VERD_LO := Color("#3f6455")
const HALF := 55
const HEIGHT := 88
const OPEN_TIME := 1.6

var _opened_at := INF


func _ready() -> void:
	position = Proj.nat(0.0, 0.0, Opening.DOOR_Z)


func _process(_delta: float) -> void:
	if not GameState.door_closed and _opened_at == INF and GameState.opening_stage != "":
		_opened_at = GameState.sim_time
	if GameState.door_closed:
		_opened_at = INF
	visible = GameState.door_closed or (_opened_at != INF and not _breached())
	if visible:
		queue_redraw()


func _breached() -> bool:
	var w := get_parent().get_parent() as World
	return w != null and w.terrain_state.breach_open


func _draw() -> void:
	var open := 0.0 if GameState.door_closed else clampf((GameState.sim_time - _opened_at) / OPEN_TIME, 0.0, 1.0)
	open = open * open * (3.0 - 2.0 * open)
	var yT := -HEIGHT
	# Linteau de rondins.
	draw_rect(Rect2(-HALF - 6, yT - 10, HALF * 2 + 12, 12), K0)
	draw_rect(Rect2(-HALF - 5, yT - 9, HALF * 2 + 10, 10), WOOD)
	draw_rect(Rect2(-HALF - 5, yT - 9, HALF * 2 + 10, 2), Color("#7a5332"))
	for i in 8:
		draw_rect(Rect2(-HALF + i * 14, yT - 8, 1, 8), WOOD_LO)
	# Battants : largeur apparente réduite quand ils pivotent vers l'intérieur.
	for side in [-1, 1]:
		var bw := roundi((HALF - 1) * (1.0 - open * 0.82))
		var bx := -HALF if side < 0 else HALF - bw
		draw_rect(Rect2(bx, yT, bw, HEIGHT), K0)
		var n := maxi(1, bw / 7)
		for i in n:
			var lx := bx + 1 + i * 7
			var lw := mini(6, bx + bw - 1 - lx)
			if lw <= 0:
				continue
			draw_rect(Rect2(lx, yT + 1, lw, HEIGHT - 1), WOOD_DK if i % 2 else WOOD)
			draw_rect(Rect2(lx, yT + 1, 1, HEIGHT - 1), WOOD_HI)
			if lw > 5:
				draw_rect(Rect2(lx + 5, yT + 1, 1, HEIGHT - 1), WOOD_LO)
		for py in [yT + 10, yT + HEIGHT / 2 - 4, -20]:
			draw_rect(Rect2(bx, py, bw, 9), K0)
			draw_rect(Rect2(bx + 1, py + 1, bw - 2, 7), VERD)
			draw_rect(Rect2(bx + 1, py + 1, bw - 2, 1), VERD_HI)
			draw_rect(Rect2(bx + 1, py + 7, bw - 2, 1), VERD_LO)
			for k in range(4, bw - 2, 10):
				draw_rect(Rect2(bx + k, py + 3, 2, 2), K0)
				draw_rect(Rect2(bx + k, py + 3, 1, 1), Color("#a7cdb8"))
		# Gonds massifs côté pilier.
		var hx := -HALF + 1 if side < 0 else HALF - 7
		for py in [yT + 12, -18]:
			draw_rect(Rect2(hx, py - 2, 6, 9), K0)
			draw_rect(Rect2(hx + 1, py - 1, 4, 7), Color("#2b2f35"))
			draw_rect(Rect2(hx + 2, py, 2, 2), Color("#6c727c"))
	if open > 0.0:
		return
	draw_rect(Rect2(0, yT, 1, HEIGHT), Color("#120c08"))
	# Poutre de blocage sur ses crochets.
	var by := yT + HEIGHT / 2 - 2
	for hx in [-HALF + 10, HALF - 16]:
		draw_rect(Rect2(hx, by - 4, 6, 13), K0)
		draw_rect(Rect2(hx + 1, by - 3, 4, 11), Color("#3a3f46"))
	draw_rect(Rect2(-HALF - 4, by, HALF * 2 + 8, 8), K0)
	draw_rect(Rect2(-HALF - 3, by + 1, HALF * 2 + 6, 6), Color("#6b4b2e"))
	draw_rect(Rect2(-HALF - 3, by + 1, HALF * 2 + 6, 1), Color("#8a643c"))
	for i in 6:
		draw_rect(Rect2(-HALF + i * 20, by + 2, 8, 1), WOOD_LO)
	# Poussière qui tombe du linteau.
	var lt := fmod(GameState.sim_time, 4.0) / 4.0
	if lt < 0.6:
		for i in 5:
			draw_rect(Rect2(-HALF + 18 + i * 19, yT + lt * 60.0 + i * 3, 1, 1), Color(0.72, 0.67, 0.59, 0.7 * (1.0 - lt / 0.6)))
