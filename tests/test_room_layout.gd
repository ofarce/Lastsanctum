extends "res://tests/test_case.gd"
## Biomes en salles (world/terrain/room_layout.gd, planches/biomes-salles-structure.html) : comptes de la planche,
## salles dans leur quartier sans chevauchement, ordre imposé par les portes, murs sans brèche, déterminisme.

const SEEDS: Array[int] = [1, 42, 777, 20261114, 9001]

## Bandes testées : une strate de 64 cases (biome 3) et les Veines, plus hautes.
func _bands() -> Array[Rect2i]:
	return [RoomLayout.band_rect(2), RoomLayout.band_rect(1), RoomLayout.band_rect(Biomes.LIST.size() - 1)]


## Gabarit des bandes 2 à 8, plus la variante du Temple si `temple`.
func _layouts(temple := true) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for band in _bands():
		for s in SEEDS:
			out.append(RoomLayout.build(band, s, 0.0))
	if temple:
		for s in SEEDS:
			out.append(RoomLayout.build_temple(s))
	return out


func _temples() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for s in SEEDS:
		out.append(RoomLayout.build_temple(s))
	return out


func _count(rooms: Array, pred: Callable) -> int:
	return rooms.filter(pred).size()


func test_band_sizes() -> void:
	check_eq(RoomLayout.BAND_GAP, TerrainState.BAND_GAP, "même roche de frontière que TerrainState")
	# Les marges de 10 u ne tombent pas sur des cases entières : on ne garde que les cases pleines.
	check_eq(RoomLayout.band_rect(2).size.y, 58, "strate de 256 u : 64 cases moins la roche des deux frontières")
	check_eq(RoomLayout.band_rect(2).size.x, 226, "toute la largeur moins 10 u de bord")
	check(RoomLayout.band_rect(1).size.y > 70, "les Veines sont plus hautes")


## Calmes divisées par deux le 2026-11-22 (RoomLayout) : 20 combats (7 / 10 / 3) et 2 calmes.
func test_counts_match_the_board() -> void:
	for lay in _layouts():
		var rooms: Array = lay["rooms"]
		var tag := " (graine %d, bande %s)" % [lay["seed"], lay["band"]]
		check_eq(rooms.size(), 40, "40 salles" + tag)
		check_eq(_count(rooms, func(r: Dictionary) -> bool: return r["kind"] == "combat"), 20, "20 combats" + tag)
		check_eq(_count(rooms, func(r: Dictionary) -> bool: return r["tier"] == "L"), 7, "7 légères" + tag)
		check_eq(_count(rooms, func(r: Dictionary) -> bool: return r["tier"] == "M"), 10, "10 moyennes" + tag)
		check_eq(_count(rooms, func(r: Dictionary) -> bool: return r["tier"] == "D"), 3, "3 dures" + tag)
		check_eq(_count(rooms, func(r: Dictionary) -> bool: return r["kind"] == "resource"), 5, "5 ressources" + tag)
		check_eq(_count(rooms, func(r: Dictionary) -> bool: return r["kind"] == "calm"), 2, "2 calmes" + tag)
		check_eq(_count(rooms, func(r: Dictionary) -> bool: return r["kind"] == "secret"), 3, "3 secrètes" + tag)
		check_eq(_count(rooms, func(r: Dictionary) -> bool: return r["kind"] == "miniboss"), 2, "2 mini-boss" + tag)
		check_eq(_count(rooms, func(r: Dictionary) -> bool: return r["kind"] == "boss"), 1, "1 boss" + tag)
		check_eq(_count(rooms, func(r: Dictionary) -> bool: return r["kind"] == "transit"), 7, "7 transits" + tag)
		for q: String in ["A", "B", "C"]:
			check_eq(_count(rooms, func(r: Dictionary) -> bool: return r["quarter"] == q and r["pylon"]), 1, "un pylône dans %s%s" % [q, tag])
		var portals := rooms.filter(func(r: Dictionary) -> bool: return r["portal"]).map(func(r: Dictionary) -> String: return r["role"] if r["role"] != "" else r["kind"])
		portals.sort()
		check_eq(portals, ["antechamber", "hub", "mb1", "mb2", "threshold"], "portails fixes" + tag)


func test_rooms_fit_their_quarter_without_overlap() -> void:
	for lay in _layouts():
		var rooms: Array = lay["rooms"]
		var band: Rect2i = lay["band"]
		for a: Dictionary in rooms:
			var ra: Rect2i = a["rect"]
			var q: Rect2i = lay["quarters"][a["quarter"]]
			check(ra.size.x >= 4 and ra.size.y >= 4, "salle %d assez grande" % a["id"])
			check(q.encloses(ra) and band.encloses(ra), "salle %d (%s) dans son quartier" % [a["id"], a["kind"]])
			for b: Dictionary in rooms:
				if b["id"] > a["id"]:
					check(not ra.grow(1).intersects(b["rect"]), "salles %d et %d séparées par la roche" % [a["id"], b["id"]])
			for cell: Vector2i in lay["walls"]:
				check(not ra.has_point(cell), "aucun mur dans la salle %d" % a["id"])


func test_doors_impose_the_order() -> void:
	for lay in _layouts():
		var rooms: Array = lay["rooms"]
		var quarter := func(ids: Dictionary) -> Dictionary:
			var out := {}
			for id: int in ids:
				out[rooms[id]["quarter"]] = true
			return out
		var closed := RoomLayout.reachable(lay)
		var q0: Dictionary = quarter.call(closed)
		check(q0.has("A") and q0.has("C") and not q0.has("B"), "portes fermées : A et C, pas B")
		check(closed.keys().all(func(id: int) -> bool: return rooms[id]["quarter"] != "R" or rooms[id]["role"] in ["entrance", "hub"]), "portes fermées : route du boss limitée à l'entrée et au hub")
		var after1 := RoomLayout.reachable(lay, ["mb1"])
		check((quarter.call(after1) as Dictionary).has("B"), "clef du mini-boss 1 : B s'ouvre")
		check(not after1.keys().any(func(id: int) -> bool: return rooms[id]["kind"] == "boss"), "clef du mini-boss 1 : pas encore le boss")
		var all := RoomLayout.reachable(lay, ["mb1", "mb2"])
		for r: Dictionary in rooms:
			check(all.has(r["id"]) == (r["kind"] != "secret"), "salle %d (%s) : accessible sauf si secrète" % [r["id"], r["kind"]])


func test_c_is_reached_without_crossing_b() -> void:
	for lay in _layouts():
		var rooms: Array = lay["rooms"]
		var seen := RoomLayout.reachable(lay)
		var c_rooms := rooms.filter(func(r: Dictionary) -> bool: return r["quarter"] == "C" and r["kind"] != "secret")
		check(c_rooms.all(func(r: Dictionary) -> bool: return seen.has(r["id"])), "tout C accessible portes fermées")
		var b: Rect2i = lay["quarters"]["B"]
		for l: Dictionary in lay["links"]:
			var qa: String = rooms[l["a"]]["quarter"]
			var qb: String = rooms[l["b"]]["quarter"]
			if qa != "B" and qb != "B":
				for cell in RoomLayout.corridor_cells(l["path"]):
					var inside_b := b.has_point(cell) and cell.y < b.end.y - 1
					check(not inside_b, "le couloir %d → %d ne passe pas par B" % [l["a"], l["b"]])


func test_minibosses_are_dead_ends_and_secrets_are_cracks() -> void:
	for lay in _layouts():
		var degree := {}
		for l: Dictionary in lay["links"]:
			degree[l["a"]] = int(degree.get(l["a"], 0)) + 1
			degree[l["b"]] = int(degree.get(l["b"], 0)) + 1
		for r: Dictionary in lay["rooms"]:
			if r["kind"] == "miniboss" or r["kind"] == "secret":
				check_eq(degree.get(r["id"], 0), 1, "%s %d : une seule issue" % [r["kind"], r["id"]])
		for l: Dictionary in lay["links"]:
			var secret: bool = lay["rooms"][l["a"]]["kind"] == "secret" or lay["rooms"][l["b"]]["kind"] == "secret"
			check_eq(l["kind"] == "secret", secret, "seule la salle secrète est derrière une fissure")


func test_walls_have_no_breach() -> void:
	for lay in _layouts(false):
		var walls: Dictionary = lay["walls"]
		var doors: Dictionary = lay["doors"]
		check(not (doors["mb1"] as Array).is_empty() and not (doors["mb2"] as Array).is_empty(), "deux portes")
		# Chaque case d'une colonne de mur est soit du mur, soit une porte, soit sous un couloir ouvert (passage).
		var open_cells := {}
		for l: Dictionary in lay["links"]:
			if l["kind"] == "corridor" and l["door"] == "":
				for cell in RoomLayout.corridor_cells(l["path"]):
					open_cells[cell] = true
		var band: Rect2i = lay["band"]
		var strip_top := band.end.y - RoomLayout.STRIP_H
		for q: String in ["R", "B", "C"]:
			var x0: int = (lay["quarters"][q] as Rect2i).position.x
			for i in range(x0 - RoomLayout.WALL, x0):
				for j in range(band.position.y, strip_top):
					var c := Vector2i(i, j)
					var ok := walls.has(c) or (doors["mb1"] as Array).has(c) or (doors["mb2"] as Array).has(c) or open_cells.has(c)
					check(ok, "mur à l'ouest de %s plein en %s" % [q, c])
		# Aucun couloir ouvert ne traverse un mur entre la route et B, ni le mur au nord du hub.
		for l: Dictionary in lay["links"]:
			if l["door"] == "":
				var qa: String = lay["rooms"][l["a"]]["quarter"]
				var qb: String = lay["rooms"][l["b"]]["quarter"]
				check(not ((qa == "R" and qb == "B") or (qa == "B" and qb == "R")), "R ↔ B seulement par la porte")


func test_hard_rooms_are_further_from_the_threshold() -> void:
	# Dans chaque quartier, les combats légers sont en moyenne plus près du seuil que les moyens. « Près » se compte
	# en salles à traverser (couloirs du plan), comme le fait RoomLayout pour ranger les combats : à vol d'oiseau, une
	# salle voisine du seuil peut n'être atteinte qu'au bout d'un long détour.
	for lay in _layouts():
		var rooms: Array = lay["rooms"]
		var next := {}
		for l: Dictionary in lay["links"]:
			for pair: Array in [[l["a"], l["b"]], [l["b"], l["a"]]]:
				if not next.has(pair[0]):
					next[pair[0]] = []
				(next[pair[0]] as Array).append(pair[1])
		for q: String in ["A", "B"]:
			var thr: Dictionary = rooms.filter(func(r: Dictionary) -> bool: return r["quarter"] == q and r["role"] == "threshold")[0]
			var hops := {thr["id"]: 0}
			var queue: Array = [thr["id"]]
			while not queue.is_empty():
				var at: int = queue.pop_front()
				for n: int in next.get(at, []):
					if not hops.has(n) and rooms[n]["quarter"] == q:
						hops[n] = int(hops[at]) + 1
						queue.append(n)
			var mean := func(t: String) -> float:
				var sel := rooms.filter(func(r: Dictionary) -> bool: return r["quarter"] == q and r["tier"] == t)
				var s := 0.0
				for r: Dictionary in sel:
					check(hops.has(r["id"]), "%s : salle %d reliée au seuil dans son quartier" % [q, r["id"]])
					s += float(hops.get(r["id"], 0))
				return s / maxf(1.0, sel.size())
			var light: float = mean.call("L")
			var medium: float = mean.call("M")
			check(light <= medium, "%s : légers avant moyens (graine %d : %.2f et %.2f salles du seuil)" % [q, lay["seed"], light, medium])


func test_temple_keeps_the_cave_and_the_eye() -> void:
	for lay in _temples():
		var rooms: Array = lay["rooms"]
		var fixed := rooms.filter(func(r: Dictionary) -> bool: return r["fixed"])
		check_eq(fixed.map(func(r: Dictionary) -> String: return r["kind"] + ":" + r["role"]), ["transit:entrance", "boss:"], "grotte et Œil fixes")
		var eye: Rect2i = fixed[1]["rect"]
		var c := TerrainState.eye_room_center()
		check(eye.has_point(Vector2i(floori(c.x / 4.0), floori(c.y / 4.0))), "l'arène du boss est la salle de l'Œil")
		check(fixed[0]["rect"].has_point(Vector2i(floori(CaveShape.CORE.x / 4.0), floori(CaveShape.CORE.y / 4.0))), "l'entrée est la grotte de l'Ancre")
		# Les salles taillées restent hors de la grotte, de la réserve du coffre, de la salle de l'Œil, de la frontière
		# et du flanc de la montagne.
		for r: Dictionary in rooms:
			if r["fixed"]:
				continue
			var rr: Rect2i = r["rect"]
			for i in range(rr.position.x, rr.end.x):
				for j in range(rr.position.y, rr.end.y):
					var x := i * 4.0 + 2.0
					var z := j * 4.0 + 2.0
					var bad := CaveShape.in_cave(x, z) or CaveShape.in_vault(x, z) or TerrainState.in_eye_room(x, z, 6.0) \
						or z < TerrainState.frontier_z() + TerrainState.FRONTIER_HALF or z > CaveShape.mountain_edge(x) - 12.0
					if bad:
						check(false, "salle %d (%s) empiète en (%d, %d)" % [r["id"], r["kind"], i, j])
		# Couloirs : jamais dans la réserve du coffre ni sur la capsule.
		for l: Dictionary in lay["links"]:
			for cell in RoomLayout.corridor_cells(l["path"]):
				var p := Vector2(cell.x * 4.0 + 2.0, cell.y * 4.0 + 2.0)
				check(not CaveShape.in_vault(p.x, p.y), "couloir %d → %d hors de la réserve" % [l["a"], l["b"]])
				check(p.distance_to(Capsule.POS) > 10.0, "couloir %d → %d loin de la capsule" % [l["a"], l["b"]])


func test_temple_walls_seal_the_quarters() -> void:
	# Seuls trois couloirs traversent un mur : hub → A (passage), hub → B (porte mb1), grotte → C (passage) ; et
	# hub → première salle dure (porte mb2) traverse le mur de la route.
	for lay in _temples():
		var rooms: Array = lay["rooms"]
		var crossing := []
		for l: Dictionary in lay["links"]:
			var qa: String = rooms[l["a"]]["quarter"]
			var qb: String = rooms[l["b"]]["quarter"]
			if qa != qb:
				crossing.append([qa, qb, l["door"]] if qa < qb else [qb, qa, l["door"]])
		crossing.sort()
		check_eq(crossing, [["A", "R", ""], ["B", "R", "mb1"], ["C", "R", ""]], "liaisons entre quartiers")
		var mb2 := (lay["links"] as Array).filter(func(l: Dictionary) -> bool: return l["door"] == "mb2")
		check_eq(mb2.size(), 1, "une porte mb2")
		check_eq(rooms[mb2[0]["b"]]["tier"], "D", "derrière mb2 : la première salle dure")


func test_arrival_reaches_the_strip() -> void:
	var band := RoomLayout.band_rect(1)
	for x: float in [-400.0, 0.0, 400.0]:
		var lay := RoomLayout.build(band, 42, x)
		var path: Array = lay["arrival"]
		check_eq((path[0] as Vector2i).y, band.end.y - 1, "part du bord sud")
		check((path[path.size() - 1] as Vector2i).y >= band.end.y - RoomLayout.STRIP_H, "finit dans le couloir sud")
		for cell in RoomLayout.corridor_cells(lay["arrival"]):
			check(not (lay["walls"] as Dictionary).has(cell), "l'arrivée ne bute sur aucun mur")


func test_deterministic() -> void:
	var band := RoomLayout.band_rect(3)
	var a := RoomLayout.build(band, 1234, 0.0)
	var b := RoomLayout.build(band, 1234, 0.0)
	check_eq(a["rooms"], b["rooms"], "même graine, mêmes salles")
	check_eq(a["links"], b["links"], "même graine, mêmes couloirs")
	var c := RoomLayout.build(band, 1235, 0.0)
	check(a["rooms"] != c["rooms"], "autre graine, autre plan")
