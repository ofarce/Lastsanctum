extends Node
## Bouches de la grotte de départ (portes des tunnels) : liste par graine.
##   godot --headless --path . res://tools/portes/probe.tscn -- <graine>

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var map_seed := int(args[0]) if args.size() > 0 else 20261114
	var st := TerrainState.new()
	st.generate_galleries(map_seed)
	var cells := {}
	for i in range(-26, 26):
		for j in range(-54, -22):
			var p := Vector2(i * 4.0 + 2.0, j * 4.0 + 2.0)
			if CaveShape.in_cave(p.x, p.y) or not st.is_gallery(p.x, p.y):
				continue
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var q := p + Vector2(d) * 4.0
				if CaveShape.in_cave(q.x, q.y):
					cells[Vector2i(i, j)] = -d
	print("seed ", map_seed, " : ", cells.size(), " cases")
	for c: Vector2i in cells:
		print("  ", c, " sortie ", cells[c])
	for area: Rect2i in [Rect2i(-11, -52, 12, 12), Rect2i(11, -33, 12, 10)]:
		print("zone ", area)
		for j in range(area.position.y, area.end.y):
			var row := "%4d " % j
			for i in range(area.position.x, area.end.x):
				var p := Vector2(i * 4.0 + 2.0, j * 4.0 + 2.0)
				row += "C" if CaveShape.in_cave(p.x, p.y) else ("G" if st.is_gallery(p.x, p.y) else "#")
			print(row)
	get_tree().quit()
