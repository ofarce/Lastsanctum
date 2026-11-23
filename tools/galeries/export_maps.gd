extends Node
## Prototype de raccordement des galeries (planches/galeries-reliees-propositions.html) : exporte, pour trois
## graines, une grille de 4 u où chaque réseau isolé est rattaché par le plus court boyau au réseau déjà relié
## (Prim par recherche en largeur dans la roche). Temple depuis la grotte de départ, Veines depuis le couloir
## de l'Œil. Ne touche pas au jeu.
##   godot --headless --path . res://tools/galeries/export_maps.tscn -- <sortie.json>
const W := 232
const H := 204
const I0 := -116
const J0 := -186
const SEEDS := [20261114, 777, 4242]


func _ready() -> void:
	var out := {}
	for sd in SEEDS:
		out[str(sd)] = _one(sd)
	var args := OS.get_cmdline_user_args()
	var f := FileAccess.open(args[0] if args.size() > 0 else "user://galeries_maps.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(out))
	f.close()
	get_tree().quit()


func _one(sd: int) -> Dictionary:
	var st := TerrainState.new()
	st.generate_galleries(sd)
	var g := PackedByteArray()
	g.resize(W * H)
	var fz := TerrainState.frontier_z()
	for j in H:
		for i in W:
			var x := (i + I0) * 4.0 + 2.0
			var z := (j + J0) * 4.0 + 2.0
			var v := "#"
			var key := Vector2i(i + I0, j + J0)
			if CaveShape.outdoors(x, z):
				v = "~"
			elif CaveShape.in_cave(x, z) or CaveShape.in_tunnel(x, z):
				v = "B"
			elif st.frontier_cell(i + I0, j + J0):
				v = "F"
			elif st.water_cells.has(key):
				v = "P"
			elif st.lode_cells.has(key):
				v = "L"
			elif st.grove_cells.has(key):
				v = "W"
			elif st.is_gallery(x, z):
				v = "."
			elif st.block_types.has(key):
				v = {"copper": "c", "iron": "i", "quartz": "q", "gold": "g", "wood": "w"}.get(st.block_types[key], "#")
			g[j * W + i] = v.unicode_at(0)
	var comp := PackedInt32Array()
	comp.resize(W * H)
	var n := 0
	for k0 in W * H:
		if comp[k0] != 0 or not _open(g[k0]):
			continue
		n += 1
		var stack := [k0]
		while not stack.is_empty():
			var k: int = stack.pop_back()
			if k < 0 or k >= W * H or comp[k] != 0 or not _open(g[k]):
				continue
			comp[k] = n
			var i := k % W
			if i > 0:
				stack.append(k - 1)
			if i < W - 1:
				stack.append(k + 1)
			stack.append(k - W)
			stack.append(k + W)
	# Le Temple part de la grotte ; le couloir de l'Œil (qui traverse la porte) n'est relié qu'une fois la
	# salle de l'Œil rattachée à la base, puis sert de départ aux Veines.
	var linked := {comp[_k(0, -150)]: true}
	var links := []
	for band in 2:
		if band == 1:
			var gate_id := comp[_k(0, fz - 12.0)]
			if gate_id != 0:
				linked[gate_id] = true
		while true:
			var r := _bfs(g, comp, linked, band, fz)
			if r.is_empty():
				break
			links.append(r["steps"])
			for k: int in r["path"]:
				if g[k] != 46:
					g[k] = 45  # '-' : raccord creusé
			linked[r["hit"]] = true
	var pyl := []
	for p in st.portals:
		pyl.append([float(p["x"]), float(p["z"])])
	return {"grid": g.get_string_from_ascii(), "old": pyl, "links": links, "fz": fz, "nets": n}


static func _open(c: int) -> bool:
	return c in [46, 66, 76, 87, 80]  # . B L W P


func _k(x: float, z: float) -> int:
	return (floori(z / 4.0) - J0) * W + (floori(x / 4.0) - I0)


func _bfs(g: PackedByteArray, comp: PackedInt32Array, linked: Dictionary, band: int, fz: float) -> Dictionary:
	var dist := PackedInt32Array()
	dist.resize(W * H)
	dist.fill(-1)
	var par := PackedInt32Array()
	par.resize(W * H)
	var q := PackedInt32Array()
	var any_left := false
	for k in W * H:
		var z := (k / W + J0) * 4.0 + 2.0
		if (z < fz) != (band == 1):
			continue
		if comp[k] != 0:
			if linked.has(comp[k]):
				dist[k] = 0
				par[k] = -1
				q.append(k)
			else:
				any_left = true
	if not any_left:
		return {}
	var h := 0
	while h < q.size():
		var k := q[h]
		h += 1
		var i := k % W
		for nb: int in [k - 1 if i > 0 else -1, k + 1 if i < W - 1 else -1, k - W, k + W]:
			if nb < 0 or nb >= W * H or dist[nb] >= 0:
				continue
			var z := (nb / W + J0) * 4.0 + 2.0
			var x := (nb % W + I0) * 4.0 + 2.0
			if (z < fz) != (band == 1):
				continue
			var c := comp[nb]
			if c != 0 and not linked.has(c):
				# Boyau de 2 blocs : chaque case du chemin et sa voisine perpendiculaire.
				var path := []
				var p := k
				while p >= 0 and dist[p] > 0:
					path.append(p)
					path.append(p + 1 if absi(p - par[p]) == W else p + W)
					p = par[p]
				return {"hit": c, "path": path, "steps": dist[k]}
			if c != 0:
				continue
			var ch := g[nb]
			if ch == 126 or ch == 70 or absf(x) > 450.0 or z < -730.0 or z > CaveShape.mountain_edge(x) - 12.0:
				continue
			dist[nb] = dist[k] + 1
			par[nb] = k
			q.append(nb)
	return {}
