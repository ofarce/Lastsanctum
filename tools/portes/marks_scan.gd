extends Node
## Repères de quartier (QuarterMarks.marks) : l'arche et la stèle ont-elles une paroi derrière elles ?
##   godot --headless --path . res://tools/portes/marks_scan.tscn -- <première graine> <nombre>

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var s0 := int(args[0]) if args.size() > 0 else 1
	var n := int(args[1]) if args.size() > 1 else 10
	var bad := 0
	var total := 0
	var framed := 0
	for s in range(s0, s0 + n):
		var st := TerrainState.new()
		st.generate_galleries(s)
		for m: Dictionary in QuarterMarks.marks(st):
			total += 1
			if m.has("span"):
				framed += 1
				# Arche sur une bouche : roche derrière chaque pilier, couloir dans l'ouverture.
				var hs: float = float(m["span"]) * 0.5
				var ok: bool = not st.is_gallery(m["x"] - hs - 2.0, m["z"] - 3.0) and not st.is_gallery(m["x"] + hs + 2.0, m["z"] - 3.0) and st.is_gallery(m["x"], m["z"] - 3.0)
				if not ok:
					bad += 1
					print("graine %d %s arche sur bouche mal calée (%.0f, %.0f) span %.0f" % [s, m["quarter"], m["x"], m["z"], m["span"]])
				continue
			var half := 3.0 if m["kind"] == "arch" else 1.0
			var open := 0
			var gap := 0
			for dx in range(-int(half), int(half) + 1, 1):
				var x: float = m["x"] + dx
				# Paroi attendue juste au nord du pied (le pied est à 4,5 u du bord nord de la salle).
				if st.is_gallery(x, m["z"] - 6.0):
					open += 1
				if st.is_gallery(x, m["z"] + 3.0) == false:
					gap += 1
			if open > 0:
				bad += 1
				if bad <= 4:
					print("graine %d %s %s (%.0f, %.0f) : %d points ouverts derrière" % [s, m["quarter"], m["kind"], m["x"], m["z"], open])
					var c := Vector2i(floori(m["x"] / 4.0), floori(m["z"] / 4.0))
					for j in range(c.y - 5, c.y + 4):
						var row := "%5d " % j
						for i in range(c.x - 9, c.x + 10):
							var q := Vector2(i * 4.0 + 2.0, j * 4.0 + 2.0)
							row += "X" if Vector2i(i, j) == c else ("." if st.is_gallery(q.x, q.y) else "#")
						print(row)
	print("repères devant une ouverture : %d / %d · arches sur un couloir : %d" % [bad, total, framed])
	get_tree().quit()
