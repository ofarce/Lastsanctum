class_name DoorGlyphView
extends Node2D
## Glyphe gravé sur une porte de quartier scellée (TerrainState.door_cells, sim/quarter_marks.gd) : la porte mb1 porte
## la Fourche de B, la porte mb2 (route du boss) a sa propre façade, OrbitGateView. Il pulse tant que la porte
## est fermée et disparaît à son ouverture. Pixels natifs, sur la face de la roche (au-dessus du pied de la case).

var key := ""
var world: World
## Le glyphe est gravé RISE px natifs au-dessus du sol, sur la face de la paroi.
const RISE := 22.0


func setup(k: String, at: Vector2, w: World) -> void:
	key = k
	world = w
	name = "PorteGlyphe_" + k
	position = Proj.nat(at.x, 0.0, at.y).round()


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var st := world.terrain_state if world != null else null
	if st == null or not st.doors_closed.get(key, false):
		return
	var pulse := 0.85 + 0.15 * sin(GameState.sim_time * 2.4)
	var o := Vector2(-10.5, -RISE - 10.5)
	# Liseré sombre derrière le glyphe : il se détache de la roche.
	draw_rect(Rect2(o - Vector2(3, 3), Vector2(27, 27)), Color(0.04, 0.04, 0.06, 0.55))
	# Porte mb1 : glyphe du quartier B qu'elle ouvre (Temple, ou Écluses des Salles oubliées).
	var qb := "VB" if key.ends_with("@veines") else "B"
	if key.begins_with("mb1"):
		var col := Color(QuarterMarks.COLOR[qb], pulse)
		for j in 7:
			var row: String = QuarterMarks.GLYPH[qb][j]
			for i in 7:
				if row[i] == "#":
					draw_rect(Rect2(o + Vector2(i, j) * 3.0, Vector2(3, 3)), col)
	else:
		var col := Color(QuarterMarks.COLOR["R"], pulse)
		for j in 7:
			var w := 3 - absi(j - 3)
			for i in range(3 - w, 4 + w):
				draw_rect(Rect2(o + Vector2(i, j) * 3.0, Vector2(3, 3)), col)
	for k in 3:
		draw_circle(o + Vector2(10.5, 10.5), 12.0 + k * 5.0, Color(QuarterMarks.COLOR[qb if key.begins_with("mb1") else "R"], (0.16 - k * 0.05) * pulse))
