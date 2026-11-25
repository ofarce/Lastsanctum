extends Node
## Ruines des seuils (CaveDoors.ruins) sur plusieurs graines : signale celles qui ne tiennent pas dans un goulot
## (sol de part et d'autre du seuil, au-delà des montants).
##   godot --headless --path . res://tools/portes/ruins_scan.tscn -- <première graine> <nombre>

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var s0 := int(args[0]) if args.size() > 0 else 1
	var n := int(args[1]) if args.size() > 1 else 10
	var bad := 0
	for s in range(s0, s0 + n):
		var st := TerrainState.new()
		st.generate_galleries(s)
		CaveDoors._ruins_seed = -1
		for r: Dictionary in CaveDoors.ruins(st):
			var a: Vector2 = r["a"]
			var b: Vector2 = r["b"]
			var t := (b - a).normalized()
			var into := Vector2(r["into"])
			var open := 0
			for side: Vector2 in [-into * 2.0]:
				for p: Vector2 in [a - t * 2.0 + side, b + t * 2.0 + side]:
					if st.is_gallery(p.x, p.y):
						open += 1
			if open > 0:
				bad += 1
				print("graine %d %s %s vers %s : %d côtés ouverts" % [s, r["quarter"], r["mid"], r["into"], open])
				if bad <= 3:
					var c := Vector2i(floori(r["mid"].x / 4.0), floori(r["mid"].y / 4.0))
					for j in range(c.y - 7, c.y + 8):
						var row := "%5d " % j
						for i in range(c.x - 10, c.x + 11):
							var q := Vector2(i * 4.0 + 2.0, j * 4.0 + 2.0)
							var room := st.temple_room(q.x, q.y)
							var ch := "#"
							if st.is_gallery(q.x, q.y):
								ch = "." if room.is_empty() else ("T" if room.get("role", "") == "threshold" else "r")
							if Vector2i(i, j) == c:
								ch = "X"
							row += ch
						print(row)
	print("mal placées : %d" % bad)
	get_tree().quit()
