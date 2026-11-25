class_name CisternView
extends Node2D
## Bassin de la citerne (salle à thème) : eau sombre sur les cases infranchissables, margelle claire,
## reflets qui glissent et gouttes qui tombent de la voûte. Posé à plat sous les unités.

const WATER := [Color8(12, 22, 29), Color8(21, 48, 58), Color8(34, 80, 92), Color8(74, 128, 136)]
const RIM := Color8(124, 134, 154)
const RIM_DARK := Color8(47, 52, 64)

## Salle de trempe des Forges mortes : eau noire, margelle de basalte, vapeur qui monte du bassin.
const TREMPE_WATER := [Color8(8, 8, 10), Color8(16, 17, 20), Color8(30, 32, 36), Color8(62, 66, 72)]
const TREMPE_RIM := Color8(120, 102, 92)
const TREMPE_RIM_DARK := Color8(43, 36, 37)
const STEAM := Color8(200, 204, 208)

var state: TerrainState
var center := Vector2.ZERO
var trempe := false
## Cases d'eau, relatives à la case centrale.
var cells: Array[Vector2i] = []


func setup(terrain_state: TerrainState, room: Dictionary) -> void:
	state = terrain_state
	center = Vector2(room["x"], room["z"])
	position = Vector2(roundf((center.x - 2.0) * 8.0), roundf((center.y - 2.0) * 8.0))
	for dj in range(-1, 2):
		for di in range(-2, 3):
			if di != 0 or dj < 0:
				cells.append(Vector2i(di, dj))
	visible = false


func _process(_delta: float) -> void:
	visible = state != null and state.is_gallery_open(center.x, center.y)
	if visible:
		queue_redraw()


func _draw() -> void:
	var t := GameState.sim_time
	var wc: Array = TREMPE_WATER if trempe else WATER
	var rim: Color = TREMPE_RIM if trempe else RIM
	var rim_dk: Color = TREMPE_RIM_DARK if trempe else RIM_DARK
	for c in cells:
		var o := Vector2(c * 32)
		draw_rect(Rect2(o, Vector2(32, 32)), wc[1])
		var north := not cells.has(c + Vector2i.UP)
		if north:
			draw_rect(Rect2(o, Vector2(32, 3)), wc[0])
			draw_rect(Rect2(o + Vector2(0, -1), Vector2(32, 1)), rim)
		if not cells.has(c + Vector2i.DOWN):
			draw_rect(Rect2(o + Vector2(0, 32), Vector2(32, 1)), rim_dk)
		if not cells.has(c + Vector2i.LEFT):
			draw_rect(Rect2(o + Vector2(-1, 0), Vector2(1, 32)), rim)
		if not cells.has(c + Vector2i.RIGHT):
			draw_rect(Rect2(o + Vector2(32, 0), Vector2(1, 32)), rim_dk)
		# Reflets : courts traits clairs qui dérivent.
		for k in 5:
			var h := Rng.hash3(c.x * 7 + k, c.y * 13 + 5, 0xc157)
			var x := fmod(h * 97.0 + t * (3.0 + k), 26.0)
			var y := 5.0 + fmod(h * 53.0 + k * 6.3, 24.0)
			var a := 0.5 + 0.5 * sin(t * 1.6 + h * 30.0)
			draw_rect(Rect2(o + Vector2(roundf(x), roundf(y)), Vector2(3 + k % 3, 1)), Color(wc[3] if k % 2 else wc[2], a))
	# Gouttes : une ride qui s'élargit, à quatre endroits du bassin.
	for k in 4:
		var c := cells[(k * 3 + 1) % cells.size()]
		var u := fmod(t * 0.45 + k * 0.27, 1.0)
		var p := Vector2(c * 32) + Vector2(16, 17)
		draw_arc(p, 2.0 + u * 9.0, 0.0, TAU, 12, Color(wc[3], (1.0 - u) * 0.8), 1.0)
	# Trempe : bouffées de vapeur qui montent du bassin et dérivent (planche, R1).
	if trempe:
		for k in 12:
			var c := cells[(k * 5 + 2) % cells.size()]
			var u := fmod(t * 0.25 + k / 12.0, 1.0)
			var h := Rng.hash3(k, 3, 0x7e3b)
			var p := Vector2(c * 32) + Vector2(4.0 + h * 24.0 + sin(t * 0.6 + k) * 4.0, 20.0 - u * 36.0)
			draw_circle(p, 3.0 + u * 5.0, Color(STEAM, (1.0 - u) * u * 0.7))
