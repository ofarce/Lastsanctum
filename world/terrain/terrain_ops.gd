class_name TerrainOps
extends RefCounted
## Creusement d'une case et révélation des galeries (73b410f, adepts.js : digCell ; galleries.js :
## revealGalleriesNear, revealGallery). Modifie l'état du terrain, repeint le sol (si un peintre est
## fourni) et met à jour le décor, dans le même ordre que le prototype.

var state: TerrainState
var registry: DecorRegistry
## Facultatif (tests sans rendu).
var painter: TerrainPainter


func _init(terrain_state: TerrainState, decor: DecorRegistry, terrain_painter: TerrainPainter = null) -> void:
	state = terrain_state
	registry = decor
	painter = terrain_painter


## digCell(i, j).
func dig_cell(i: int, j: int) -> void:
	var key := Vector2i(i, j)
	if state.dug.has(key):
		return
	state.dug[key] = true
	state.dig_hits.erase(key)
	var x := i * 4.0
	var z := j * 4.0
	if painter:
		painter.paint_dug_cell(i, j)
	# Décor de la case retiré (falaise, éboulis) ; nouvelle falaise au fond si la case au nord reste de la roche.
	registry.remove_in_rect(x - 0.01, z - 0.01, x + 4.0, z + 4.01, func(e: Dictionary) -> bool:
		return not DecorRegistry.is_fixed(e) and e["x"] >= x - 0.01 and e["x"] < x + 4.0 and e["z"] >= z - 0.01 and e["z"] <= z + 4.01)
	if not state.walkable(x + 2.0, z - 2.0):
		var v := ((i * 7 + j * 3) & 7) % 6
		registry.add({"s": "face5_%d" % v, "runtime": true, "x": x, "z": z, "d": z, "bx": x, "bz": z})
	state.version += 1
	Combat.zone(x + 2.0, z + 2.0, 2.0, Color("#a89c86"))
	# Une galerie touche la case : elle est découverte.
	if not reveal_galleries_near(x - 1.5, z - 1.5, x + 5.5, z + 5.5):
		Events.notice.emit("Roche creusée : la grotte s’agrandit.", 1.5)
	if painter:
		painter.terrain.flush()


func reveal_galleries_near(x0: float, z0: float, x1: float, z1: float) -> bool:
	var any := false
	var z := floori(z0)
	while z <= z1:
		var x := floori(x0)
		while x <= x1:
			var k := TerrainState.gal_idx(x, z)
			if k >= 0 and state.mask[k] == 1 and state.open[k] == 0:
				reveal_gallery(x, z)
				any = true
			x += 1
		z += 1
	return any


func reveal_gallery(sx: float, sz: float) -> void:
	var w := TerrainState.GAL_W
	var h := TerrainState.GAL_H
	var stack: Array[int] = [TerrainState.gal_idx(sx, sz)]
	var i0 := 1000000000
	var i1 := -1000000000
	var j0 := 1000000000
	var j1 := -1000000000
	var n := 0
	while not stack.is_empty():
		var k: int = stack.pop_back()
		if k < 0 or state.mask[k] != 1 or state.open[k] == 1:
			continue
		state.open[k] = 1
		n += 1
		var i := k % w
		var j := (k - i) / w
		i0 = mini(i0, i)
		i1 = maxi(i1, i)
		j0 = mini(j0, j)
		j1 = maxi(j1, j)
		if i > 0:
			stack.append(k - 1)
		if i < w - 1:
			stack.append(k + 1)
		if j > 0:
			stack.append(k - w)
		if j < h - 1:
			stack.append(k + w)
	if n == 0:
		return
	state.found += 1
	var woke: Array[Dictionary] = []
	for p in state.portals:
		if not p["active"] and state.is_gallery_open(p["x"], p["z"]):
			woke.append(p)
	var X0 := floorf((i0 + CaveShape.WORLD_X0) / 4.0) * 4.0 - 4.0
	var X1 := ceilf((i1 + CaveShape.WORLD_X0 + 1.0) / 4.0) * 4.0 + 4.0
	var Z0 := floorf((j0 + CaveShape.WORLD_Z0) / 4.0) * 4.0 - 4.0
	var Z1 := ceilf((j1 + CaveShape.WORLD_Z0 + 1.0) / 4.0) * 4.0 + 4.0
	# Éboulis du dos de la montagne posés sur la galerie : retirés.
	# Toutes les cases ouvertes sont dans le rectangle [i0, i1] × [j0, j1] de la galerie.
	registry.remove_in_rect(i0 + CaveShape.WORLD_X0, j0 + CaveShape.WORLD_Z0, i1 + CaveShape.WORLD_X0 + 1.0, j1 + CaveShape.WORLD_Z0 + 1.0,
		func(e: Dictionary) -> bool: return not (DecorRegistry.is_fixed(e) or e.has("bx")) and state.is_gallery_open(e["x"], e["z"]))
	if painter:
		painter.paint_region(X0, Z0, X1, Z1)
	# Parois vues de face au nord de chaque ouverture, cristaux le long des murs.
	var r := Rng.new(state.seed + n)
	var x := X0
	while x < X1:
		var z := Z0
		while z < Z1:
			var cx := x + 2.0
			var cz := z + 2.0
			if not (state.walkable(cx, cz) or not state.walkable(cx, cz + 4.0) or CaveShape.in_cave(cx, cz + 4.0)):
				var bz := z + 4.0
				var t := z + 4.0
				while t < z + 8.0:
					if state.is_gallery_open(cx, t):
						bz = t
						break
					t += 0.5
				var v := floori(r.next() * 6.0)
				registry.add({"s": "face5_%d" % v, "runtime": true, "x": x, "z": bz, "d": bz, "bx": x, "bz": bz})
			z += 4.0
		x += 4.0
	# for (k = 0; k < max(2, n/90); k++) : 40 essais au plus pour placer chaque stalagmite.
	var spires := maxf(2.0, n / 90.0)
	var made := 0
	while made < spires:
		for t in 40:
			var sxp := X0 + r.next() * (X1 - X0)
			var szp := Z0 + r.next() * (Z1 - Z0)
			if not state.is_gallery_open(sxp, szp) or state.is_gallery_open(sxp, szp - 2.5):
				continue
			var v := floori(r.next() * 6.0)
			# d = x + z : reliquat de la version isométrique, conservé (ordre de dessin d'origine).
			registry.add({"s": "gallery_spire_%d" % v, "runtime": true, "x": sxp, "z": szp, "d": sxp + szp, "light": v % 2 == 0})
			break
		made += 1
	for p in woke:
		p["active"] = true
		p["next"] = GameState.sim_time + 5.0
		registry.add({"evil": p, "x": p["x"], "z": p["z"], "d": p["z"] + 0.5})
		Combat.zone(p["x"], p["z"] + 1.0, 4.0, Color("#ff5030"))
	state.version += 1
	Combat.zone((X0 + X1) / 2.0, (Z0 + Z1) / 2.0, 6.0, Color("#8fd6f0"))
	var msg := "Galerie découverte ! (%d / %d)" % [state.found, state.count]
	if not woke.is_empty():
		msg += " · un portail maléfique s’y éveille : les rejetons de la Bête en sortent sans fin."
	Events.notice.emit(msg, 5.0 if not woke.is_empty() else 3.0)
