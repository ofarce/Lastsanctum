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
## Sprite de la paroi (variante v) dont le pied est en z : la roche qu'elle habille est la case juste au nord.
static func face_id(v: int, z: float) -> String:
	return "face5_%d" % v + Biomes.sprite_suffix(Biomes.rock_tier(z - 2.0))


func dig_cell(i: int, j: int) -> void:
	var key := Vector2i(i, j)
	if state.dug.has(key) or state.permanent_ores.has(key):
		return
	state.dug[key] = true
	state.dig_hits.erase(key)
	state.dig_hit_at.erase(key)
	var x := i * 4.0
	var z := j * 4.0
	if painter:
		painter.paint_dug_cell(i, j)
	# Décor de la case retiré (falaise, éboulis) ; nouvelle falaise au fond si la case au nord reste de la roche.
	registry.remove_in_rect(x - 0.01, z - 0.01, x + 4.0, z + 4.01, func(e: Dictionary) -> bool:
		return not DecorRegistry.is_fixed(e) and e["x"] >= x - 0.01 and e["x"] < x + 4.0 and e["z"] >= z - 0.01 and e["z"] <= z + 4.01)
	if not state.ground(x + 2.0, z - 2.0):
		var v := ((i * 7 + j * 3) & 7) % 6
		registry.add({"s": face_id(v, z), "runtime": true, "x": x, "z": z, "d": z, "bx": x, "bz": z})
	state.version += 1
	Combat.zone(x + 2.0, z + 2.0, 2.0, Color("#a89c86"))
	# Une galerie touche la case : elle est découverte.
	reveal_galleries_near(x - 1.5, z - 1.5, x + 5.5, z + 5.5)
	if painter:
		painter.terrain.flush()


## Salle de départ (zone de CaveShape.in_cave) : le sol et les faces de falaise du baker suivent le contour
## du prototype. Sol repeint d'après la forme réelle, faces du baker et décor devenu faux retirés, une face
## vue de face au nord de chaque ouverture (comme pour une galerie).
const CAVE_RECT := Rect2(-92.0, -204.0, 184.0, 116.0)


func reshape_cave() -> void:
	var r := CAVE_RECT
	registry.remove_in_rect(r.position.x, r.position.y, r.end.x, r.end.y, func(e: Dictionary) -> bool:
		if DecorRegistry.is_fixed(e) or e.get("runtime", false):
			return false
		var x: float = e["x"]
		var z: float = e["z"]
		if String(e.get("s", "")).begins_with("face"):
			return true
		return CaveShape.in_cave(x, z) != CaveShape.in_prototype_outline(x, z))
	if painter:
		painter.repaint_cave(r.position.x, r.position.y, r.end.x, r.end.y)
	var z := r.position.y
	while z < r.end.y:
		var x := r.position.x
		while x < r.end.x:
			var cx := x + 2.0
			if not state.ground(cx, z + 2.0) and CaveShape.in_cave(cx, z + 6.0):
				var v := ((floori(x / 4.0) * 7 + floori(z / 4.0) * 3) & 7) % 6
				registry.add({"s": face_id(v, z + 4.0), "runtime": true, "x": x, "z": z + 4.0, "d": z + 4.0, "bx": x, "bz": z + 4.0})
			x += 4.0
		z += 4.0
	state.version += 1


## Ancienne réserve du coffre antique : devient creuse, sol repeint, décor de roche retiré, parois au nord. Plus
## appelée par le minage depuis que le coffre est à côté de la capsule (2026-11-22).
func open_vault() -> void:
	if state.vault_open:
		return
	state.vault_open = true
	var X0 := CaveShape.VAULT_X0
	var X1 := CaveShape.VAULT_X1
	var Z0 := CaveShape.VAULT_Z0
	var Z1 := CaveShape.VAULT_Z1
	registry.remove_in_rect(X0, Z0, X1, Z1, func(e: Dictionary) -> bool:
		return not DecorRegistry.is_fixed(e) and CaveShape.in_vault(e["x"], e["z"]))
	if painter:
		painter.paint_region(X0 - 4.0, Z0 - 4.0, X1 + 4.0, Z1 + 4.0)
	# Paroi vue de face au-dessus de chaque colonne (comme au nord d'une galerie).
	var x := X0
	while x < X1:
		var cx := x + 2.0
		var bz := Z0
		while bz < Z1 and not CaveShape.in_vault(cx, bz):
			bz += 0.5
		if not state.ground(cx, Z0 - 2.0):
			registry.add({"s": "face5_%d" % (floori(x / 4.0) % 6), "runtime": true, "x": x, "z": bz, "d": bz, "bx": x, "bz": bz})
		x += 4.0
	state.version += 1
	Combat.zone(CaveShape.CHEST.x, CaveShape.CHEST.y, 6.0, Color("#5ce8ff"))


## Mur sud soufflé par l'explosion du bouclier : la brèche devient creuse, sol repeint, roche retirée.
func open_breach() -> void:
	if state.breach_open:
		return
	state.breach_open = true
	var X := CaveShape.BREACH_W + 4.0
	registry.remove_in_rect(-X, CaveShape.CAVE_Z1 - 4.0, X, -70.0, func(e: Dictionary) -> bool:
		for k in 7:
			if CaveShape.in_breach(e["x"], e["z"] - k * 1.5):
				return true
		return false)
	if painter:
		painter.paint_region(-X - 4.0, CaveShape.CAVE_Z1 - 8.0, X + 4.0, -68.0)
		painter.terrain.flush()
	state.version += 1


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


## Galeries reliées (planches/galeries-reliees-propositions.html, 2026-11-22) : tout le réseau est ouvert dès le
## départ, sans annonce ni éveil (les pylônes et les tanières s'éveillent à la vue, sim/awaken.gd). Le sol autour
## de la grotte est peint en premier, le reste au fil des images.
func open_all_galleries() -> void:
	var w := TerrainState.GAL_W
	# Temple et Veines seulement (2026-11-22) : les galeries des six strates restent closes sous leur roche
	# scellée et s'ouvrent quand on y perce (reveal_galleries_near, appelé par dig_cell).
	var k := -1 if Biomes.LIST.size() <= 2 else maxi(0, TerrainState.gal_idx(CaveShape.WORLD_X0, Biomes.north_z(1))) - 1
	while true:
		k = state.mask.find(1, k + 1)
		if k < 0:
			break
		if state.open[k] == 0:
			var i := k % w
			@warning_ignore("integer_division")
			reveal_gallery(i + CaveShape.WORLD_X0 + 0.5, (k - i) / w + CaveShape.WORLD_Z0 + 0.5, true)
	if painter:
		painter.prioritize(Rect2(CaveShape.CORE - Vector2(160.0, 140.0), Vector2(320.0, 260.0)))


## Éveil d'un pylône (vu par un allié, sim/awaken.gd) : obélisque et nappe ajoutés au décor, éclat rouge.
func wake_pylon(p: Dictionary) -> void:
	if p["active"]:
		return
	p["active"] = true
	p["next"] = GameState.sim_time + 5.0
	dress_pylon(p)
	Combat.zone(p["x"], p["z"], 6.0, Color("#e0583a"))


## Id des pylônes dont l'obélisque est au décor (pas enregistré : une partie rechargée les rhabille, Awaken).
var dressed := {}


func dress_pylon(p: Dictionary) -> void:
	if dressed.has(p["id"]):
		return
	dressed[p["id"]] = true
	registry.add({"evil": p, "x": p["x"], "z": p["z"], "d": p["z"] + 3.8})
	state.version += 1


## `quiet` : ouverture de départ (open_all_galleries), sans éveil, éclat ni annonce.
func reveal_gallery(sx: float, sz: float, quiet := false) -> void:
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
		if not quiet and not p["active"] and state.is_gallery_open(p["x"], p["z"]):
			woke.append(p)
	var X0 := floorf((i0 + CaveShape.WORLD_X0) / 4.0) * 4.0 - 4.0
	var X1 := ceilf((i1 + CaveShape.WORLD_X0 + 1.0) / 4.0) * 4.0 + 4.0
	var Z0 := floorf((j0 + CaveShape.WORLD_Z0) / 4.0) * 4.0 - 4.0
	var Z1 := ceilf((j1 + CaveShape.WORLD_Z0 + 1.0) / 4.0) * 4.0 + 4.0
	# Éboulis du dos de la montagne posés sur la galerie : retirés.
	# Toutes les cases ouvertes sont dans le rectangle [i0, i1] × [j0, j1] de la galerie.
	registry.remove_in_rect(i0 + CaveShape.WORLD_X0, j0 + CaveShape.WORLD_Z0, i1 + CaveShape.WORLD_X0 + 1.0, j1 + CaveShape.WORLD_Z0 + 1.0,
		func(e: Dictionary) -> bool: return not (DecorRegistry.is_fixed(e) or e.has("bx")) and state.is_gallery_open(e["x"], e["z"]))
	# Parois vues de face déjà posées (grotte de départ, reshape_cave, ou galerie voisine) dont la roche habillée
	# — la case de la grille juste au nord de celle du pied — vient de s'ouvrir : sinon un mur reste dessiné sur du
	# sol praticable.
	registry.remove_in_rect(X0, Z0, X1, Z1 + 4.0, func(e: Dictionary) -> bool:
		return e.has("bx") and String(e.get("s", "")).begins_with("face") \
			and state.ground(float(e["bx"]) + 2.0, floorf(float(e["bz"]) / 4.0) * 4.0 - 2.0))
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
			if not (state.ground(cx, cz) or not state.ground(cx, cz + 4.0) or CaveShape.in_cave(cx, cz + 4.0)):
				var bz := z + 4.0
				var t := z + 4.0
				while t < z + 8.0:
					if state.is_gallery_open(cx, t):
						bz = t
						break
					t += 0.5
				var v := floori(r.next() * 6.0)
				registry.add({"s": face_id(v, z + 4.0), "runtime": true, "x": x, "z": bz, "d": bz, "bx": x, "bz": bz})
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
		dress_pylon(p)
		Combat.zone(p["x"], p["z"], 6.0, Color("#e0583a"))
	state.version += 1
	if quiet:
		return
	Combat.zone((X0 + X1) / 2.0, (Z0 + Z1) / 2.0, 6.0, Color("#8fd6f0"))
	var msg := "Galerie découverte ! (%d / %d)" % [state.found, state.count]
	Events.notice.emit(msg, 3.0)
