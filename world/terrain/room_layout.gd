class_name RoomLayout
extends RefCounted
## Biomes en salles (planches/biomes-salles-structure.html, validée le 2026-11-22) : plan d'une bande de biome en
## ~40 salles, réparties en quatre colonnes d'ouest en est :
##   A  quartier de l'exp. 1, ouvert depuis le hub, mini-boss 1 au nord-ouest ;
##   R  route du boss : entrée, hub (portail), mur et porte « mb2 », deux salles dures et un repos, antichambre
##      (portail), arène du boss au nord ;
##   B  quartier de l'exp. 2, derrière la porte « mb1 », mini-boss 2 au nord-est ;
##   C  quartier ouvert dès l'entrée par un couloir scellé le long du bord sud, un palier de menace de plus.
## Des murs impossibles à creuser séparent les colonnes ; les portes s'ouvrent avec la clef d'un mini-boss.
##
## Module pur et déterministe (graine) : il ne touche pas au terrain. Tout est en cases de 4 unités, j vers le
## sud (comme z). Le branchement dans TerrainState (masque des galeries, murs, portes) se fait à part.
##
## Résultat de build() :
##   rooms     [{id, kind, role, tier, quarter, rect: Rect2i, portal, pylon, fixed}]
##             fixed : salle qui existe déjà sur la carte (grotte et salle de l'Œil du Temple), à ne pas tailler
##             kind : combat | resource | calm | secret | miniboss | boss | transit
##             tier : "L", "M", "D" pour les combats, "" sinon
##   links     [{a, b, kind: corridor | secret, door: "" | "mb1" | "mb2", path: Array[Vector2i]}]
##             path : ligne brisée (centres de cases) ; le couloir fait CORRIDOR_W cases de large autour.
##   arrival   ligne brisée depuis le bord sud de la bande (entry_x) jusqu'au couloir sud ou à l'entrée
##   walls     {Vector2i : true} cases de mur, portes et passages ouverts déjà retirés
##   doors     {"mb1": [Vector2i], "mb2": [Vector2i]}
##   quarters  {"A", "R", "B", "C" : Rect2i}
##   band      Rect2i de la bande, threat_bonus {"C": 1}

const CASE := 4.0
## Roche pleine laissée de chaque côté d'une frontière de strate : même valeur que TerrainState.BAND_GAP, recopiée
## pour que ce module ne dépende pas de TerrainState (qui lit les autoloads) et tourne dans un script en ligne de commande.
const BAND_GAP := 10.0
## Couloirs : 3 cases de large (ligne brisée ± 1 case).
const CORRIDOR_W := 3
## Épaisseur des murs de quartier (cases).
const WALL := 2
## Couloir scellé du bord sud (cases de haut) et rangée de mur au-dessus de lui sous le quartier B.
const STRIP_H := 3
## Grille d'un quartier : 3 colonnes × 4 rangées de cellules, une salle au plus par cellule.
const COLS := 3
const ROWS := 4
## Colonnes de la bande (fractions de la largeur) : A | R | B | C.
const SPLIT := [0.0, 0.25, 0.47, 0.73, 1.0]
const ORDER: Array[String] = ["A", "R", "B", "C"]

## Salles tirées dans chaque quartier, en plus du seuil et du mini-boss (comptes de la planche : 18 combats
## 7 / 8 / 3, 5 ressources, 4 calmes, 3 secrètes, 2 mini-boss, 1 boss, 7 transits, 40 salles).
const POOL := {
	"A": [["combat", "", "L"], ["combat", "", "L"], ["combat", "", "L"], ["combat", "", "L"], ["combat", "", "M"],
		["combat", "", "M"], ["resource", "", ""], ["combat", "", "M"], ["secret", "", ""]],
	"B": [["combat", "", "L"], ["combat", "", "L"], ["combat", "", "M"], ["combat", "", "M"], ["combat", "", "M"],
		["combat", "", "M"], ["combat", "", "D"], ["resource", "", ""], ["calm", "merchant", ""], ["secret", "", ""]],
	"C": [["combat", "", "L"], ["combat", "", "M"], ["combat", "", "M"], ["resource", "", ""], ["resource", "", ""],
		["resource", "", ""], ["combat", "", "M"], ["secret", "", ""], ["transit", "outpost", ""]],
}
## 2026-11-22 (demande) : salles de calme divisées par deux. L'autel de A et la source de C deviennent des combats
## moyens ; restent le repos de la route du boss et le marchand de B. Soit 20 combats (7 / 10 / 3) et 2 calmes.
## Grille de chaque quartier, cellule du seuil et du mini-boss (colonne, rangée ; rangée 0 au nord) : aux coins
## opposés du quartier. Une cellule fait environ 19 × 13 cases dans une bande de 64 : assez pour une arène de 17 × 11.
const SPEC := {
	"A": {"cols": COLS, "rows": ROWS, "thr": Vector2i(2, 3), "mb": [Vector2i(0, 0)]},
	"B": {"cols": COLS, "rows": ROWS, "thr": Vector2i(0, 3), "mb": [Vector2i(2, 0)]},
	"C": {"cols": COLS, "rows": ROWS, "thr": Vector2i(0, 3), "mb": []},
}

## Variante du Temple (2026-11-22, « grotte gardée ») : la grotte de départ est l'entrée (la ville), la salle de
## l'Œil est l'arène du boss ; toutes deux existent déjà et ne sont pas taillées ici. La route du boss est donc au
## centre ; A prend tout l'ouest, B le nord-est, C le sud-est, à côté de la base, ouvert par un couloir scellé qui
## part de la paroi est de la grotte (au sud de la réserve du coffre). Rectangles en cases [i0, j0, i1, j1).
const TEMPLE_BAND := [-113, -102, 113, -23]
const TEMPLE_Q := {"A": [-113, -100, -27, -24], "R": [-25, -102, 25, -23], "B": [27, -100, 113, -61], "C": [27, -59, 113, -24]}
const TEMPLE_SPEC := {
	"A": {"cols": 3, "rows": 4, "thr": Vector2i(2, 1), "mb": [Vector2i(0, 0)]},
	# Arène de la Martyre de Byrsa (mini-boss 2) : 2 × 2 cellules, assez pour son dôme de 24 cases de diamètre
	# (choix du 2026-11-22) ; la grille passe à 5 × 3 pour garder les 11 salles de B.
	"B": {"cols": 5, "rows": 3, "thr": Vector2i(0, 2), "mb": [Vector2i(3, 0), Vector2i(4, 0), Vector2i(3, 1), Vector2i(4, 1)],
		"mb_size": Vector2i(28, 24)},
	"C": {"cols": 4, "rows": 3, "thr": Vector2i(0, 2), "mb": []},
}
## Grotte (enveloppe, CaveShape.cave_w/e/n/s) et salle de l'Œil (enveloppe, TerrainState.in_eye_room), en cases.
const TEMPLE_CAVE := Rect2i(-15, -43, 30, 20)
const TEMPLE_EYE := Rect2i(-15, -102, 30, 14)
## Étages de la route (rangées j) : antichambre, salles dures et repos, mur « mb2 », hub.
const TEMPLE_ANTE := Rect2i(-5, -86, 10, 5)
const TEMPLE_D_ROW := -79
const TEMPLE_WALL_ROW := -70
const TEMPLE_HUB := Rect2i(-8, -68, 16, 8)
## Sorties de la grotte (cases) : au nord-ouest vers le hub (la capsule occupe le milieu de la paroi nord), à l'est
## vers C, au sud de la réserve du coffre (VAULT_Z1 = −144, couloir à z −112).
const TEMPLE_EXIT_HUB := Vector2i(-6, -40)
const TEMPLE_EXIT_C := Vector2i(14, -28)
## Taille des salles (cases) : [largeur min, max, hauteur min, max].
const SIZE := {
	"transit": [7, 9, 6, 7], "outpost": [11, 13, 8, 9], "L": [8, 10, 7, 8], "M": [9, 12, 8, 9], "D": [11, 13, 8, 10],
	"resource": [9, 12, 8, 10], "calm": [8, 10, 7, 8], "secret": [5, 6, 4, 5], "miniboss": [15, 17, 10, 11],
}
## Route du boss (largeur, hauteur) ; écart minimal entre deux étages, et sous le hub (le mur mb2 y passe).
const ROUTE := {"boss": Vector2i(40, 13), "antechamber": Vector2i(12, 7), "D": Vector2i(12, 9), "rest": Vector2i(9, 7),
	"hub": Vector2i(16, 8), "entrance": Vector2i(12, 6)}
const ROUTE_GAP := 2
const ROUTE_WALL_GAP := 3

var _r: Rng
var _rooms: Array[Dictionary] = []
var _links: Array[Dictionary] = []


## Bande du biome k en cases : toute la largeur moins 10 unités de bord, BAND_GAP de roche pleine au nord et au sud.
static func band_rect(k: int) -> Rect2i:
	var n := Biomes.north_z(k)
	if n == -INF:
		n = CaveShape.WORLD_Z0
	var s := minf(Biomes.south_z(k), Biomes.BASE_Z)
	var i0 := ceili((CaveShape.WORLD_X0 + 10.0) / CASE)
	var i1 := floori((CaveShape.WORLD_X1 - 10.0) / CASE)
	var j0 := ceili((n + BAND_GAP) / CASE)
	var j1 := floori((s - BAND_GAP) / CASE)
	return Rect2i(i0, j0, i1 - i0, j1 - j0)


## Plan de la bande `band` (cases) pour la graine `seed` ; entry_x : abscisse (unités) où arrive le passage du sud.
static func build(band: Rect2i, seed: int, entry_x: float = 0.0) -> Dictionary:
	return RoomLayout.new()._build(band, seed, entry_x)


func _build(band: Rect2i, seed: int, entry_x: float) -> Dictionary:
	_r = Rng.new(seed)
	_rooms.clear()
	_links.clear()
	var strip_top := band.end.y - STRIP_H
	var quarters := {}
	var walls := {}
	for q in ORDER.size():
		var x0 := band.position.x + roundi(band.size.x * float(SPLIT[q]))
		var x1 := band.position.x + roundi(band.size.x * float(SPLIT[q + 1]))
		if q > 0:
			x0 += WALL
			# Mur vertical à l'ouest de la colonne, du bord nord jusqu'au couloir sud.
			for i in range(x0 - WALL, x0):
				for j in range(band.position.y, strip_top):
					walls[Vector2i(i, j)] = true
		quarters[ORDER[q]] = Rect2i(x0, band.position.y, x1 - x0, strip_top - band.position.y)
	# Les quartiers à grille s'arrêtent une rangée de mur au-dessus du couloir sud.
	var grid_h := strip_top - 1 - band.position.y
	var by_cell := {}
	for q: String in ["A", "B", "C"]:
		var qr: Rect2i = quarters[q]
		by_cell[q] = _quarter(q, Rect2i(qr.position.x, qr.position.y, qr.size.x, grid_h), SPEC[q])
	var b: Rect2i = quarters["B"]
	for i in range(b.position.x - WALL, b.end.x + WALL):
		walls[Vector2i(i, strip_top - 1)] = true
	var route := _route(quarters["R"], strip_top, walls)
	# Liaisons entre quartiers.
	var hub: int = route["hub"]
	var thr_a: int = by_cell["A"][SPEC["A"]["thr"]]
	var thr_b: int = by_cell["B"][SPEC["B"]["thr"]]
	var thr_c: int = by_cell["C"][SPEC["C"]["thr"]]
	_link(hub, thr_a, "corridor", "")
	_link(hub, thr_b, "corridor", "mb1")
	# Couloir scellé : de l'entrée jusqu'au seuil de C, le long du bord sud.
	var sz := strip_top + STRIP_H / 2
	var e := _center(route["entrance"])
	var c := _center(thr_c)
	var strip: Array[Vector2i] = [e, Vector2i(e.x, sz), Vector2i(c.x, sz), c]
	_links.append({"a": route["entrance"], "b": thr_c, "kind": "corridor", "door": "", "path": strip})
	var ei := clampi(floori(entry_x / CASE), band.position.x + 1, band.end.x - 2)
	var arrival: Array[Vector2i] = [Vector2i(ei, band.end.y - 1), Vector2i(ei, sz)]
	if ei < e.x:
		arrival.append(Vector2i(e.x, sz))
	elif ei > c.x:
		arrival.append(Vector2i(c.x, sz))
	return _finish(walls, arrival, quarters, band, seed)


## Portes et passages : les cases de mur sous un couloir deviennent porte (lien fermé) ou passage (lien ouvert).
func _finish(walls: Dictionary, arrival: Array[Vector2i], quarters: Dictionary, band: Rect2i, seed: int) -> Dictionary:
	var door1: Array[Vector2i] = []
	var door2: Array[Vector2i] = []
	var doors := {"mb1": door1, "mb2": door2}
	for l in _links:
		if l["kind"] != "corridor":
			continue
		for cell in corridor_cells(l["path"]):
			if walls.has(cell):
				walls.erase(cell)
				if l["door"] != "":
					(doors[l["door"]] as Array[Vector2i]).append(cell)
	for cell in corridor_cells(arrival):
		walls.erase(cell)
	return {"rooms": _rooms.duplicate(), "links": _links.duplicate(), "arrival": arrival, "walls": walls, "doors": doors,
		"quarters": quarters, "band": band, "threat_bonus": {"C": 1}, "seed": seed}


# ---------------------------------------------------------------- Variante du Temple

## Plan du Temple (biome 1) pour la graine `seed`. La grotte (entrée) et la salle de l'Œil (boss) sont marquées
## « fixed » : elles existent déjà sur la carte, le terrain ne les taille pas.
static func build_temple(seed: int) -> Dictionary:
	return RoomLayout.new()._build_temple(seed)


func _build_temple(seed: int) -> Dictionary:
	_r = Rng.new(seed)
	_rooms.clear()
	_links.clear()
	var rect := func(a: Array) -> Rect2i:
		return Rect2i(a[0], a[1], a[2] - a[0], a[3] - a[1])
	var band: Rect2i = rect.call(TEMPLE_BAND)
	var quarters := {}
	for q: String in TEMPLE_Q:
		quarters[q] = rect.call(TEMPLE_Q[q])
	# Murs : A | route, route | est (B et C), B | C.
	var walls := {}
	var a_end: int = (quarters["A"] as Rect2i).end.x
	var east: int = (quarters["B"] as Rect2i).position.x
	var b_end: int = (quarters["B"] as Rect2i).end.y
	for j in range(band.position.y, band.end.y):
		for i in range(a_end, a_end + WALL):
			walls[Vector2i(i, j)] = true
		for i in range(east - WALL, east):
			walls[Vector2i(i, j)] = true
	for i in range(east - WALL, band.end.x):
		for j in range(b_end, b_end + WALL):
			walls[Vector2i(i, j)] = true
	var by_cell := {}
	for q: String in ["A", "B", "C"]:
		by_cell[q] = _quarter(q, quarters[q], TEMPLE_SPEC[q])
	# Route du boss : grotte (entrée), hub, mur mb2, salles dures et repos, antichambre, salle de l'Œil.
	var entrance := _add_room("transit", "entrance", "", "R", TEMPLE_CAVE, false, false)
	_rooms[entrance]["fixed"] = true
	var hub := _add_room("transit", "hub", "", "R", TEMPLE_HUB, true, false)
	var jitter := _ri(-1, 1)
	var d1 := _add_room("combat", "", "D", "R", Rect2i(-21 + jitter, TEMPLE_D_ROW, 12, 8), false, false)
	var rest := _add_room("calm", "rest", "", "R", Rect2i(-4 + jitter, TEMPLE_D_ROW + 1, 9, 6), false, false)
	var d2 := _add_room("combat", "", "D", "R", Rect2i(9 + jitter, TEMPLE_D_ROW, 12, 8), false, false)
	var ante := _add_room("transit", "antechamber", "", "R", TEMPLE_ANTE, true, false)
	var boss := _add_room("boss", "", "", "R", TEMPLE_EYE, false, false)
	_rooms[boss]["fixed"] = true
	var route: Rect2i = quarters["R"]
	for i in range(route.position.x - WALL, route.end.x + WALL):
		walls[Vector2i(i, TEMPLE_WALL_ROW)] = true
	var thr_a: int = by_cell["A"][TEMPLE_SPEC["A"]["thr"]]
	var thr_b: int = by_cell["B"][TEMPLE_SPEC["B"]["thr"]]
	var thr_c: int = by_cell["C"][TEMPLE_SPEC["C"]["thr"]]
	var h := _center(hub)
	var exit_hub: Array[Vector2i] = [TEMPLE_EXIT_HUB, Vector2i(TEMPLE_EXIT_HUB.x, h.y)]
	_links.append({"a": entrance, "b": hub, "kind": "corridor", "door": "", "path": exit_hub})
	_link(hub, thr_a, "corridor", "")
	_link(hub, thr_b, "corridor", "mb1")
	_link(hub, d1, "corridor", "mb2")
	_link(d1, rest, "corridor", "")
	_link(rest, d2, "corridor", "")
	_link(d2, ante, "corridor", "", true)
	# L'antichambre débouche dans la salle de l'Œil par le sud : le couloir s'arrête à son bord.
	var an := _center(ante)
	var to_eye: Array[Vector2i] = [an, Vector2i(an.x, TEMPLE_EYE.end.y - 2)]
	_links.append({"a": ante, "b": boss, "kind": "corridor", "door": "", "path": to_eye})
	var c := _center(thr_c)
	var exit_c: Array[Vector2i] = [TEMPLE_EXIT_C, Vector2i(c.x, TEMPLE_EXIT_C.y), c]
	_links.append({"a": entrance, "b": thr_c, "kind": "corridor", "door": "", "path": exit_c})
	var none: Array[Vector2i] = []
	return _finish(walls, none, quarters, band, seed)


# ---------------------------------------------------------------- Quartiers A, B, C

## Salles d'un quartier : cellule → id de salle (le mini-boss répond pour ses deux cellules).
func _quarter(q: String, area: Rect2i, spec: Dictionary) -> Dictionary:
	var cols: int = spec["cols"]
	var rows: int = spec["rows"]
	var cw := area.size.x / cols
	var ch := area.size.y / rows
	var cell_rect := func(c: Vector2i) -> Rect2i:
		return Rect2i(area.position.x + c.x * cw, area.position.y + c.y * ch, cw, ch)
	var mb: Array = spec["mb"]
	var thr: Vector2i = spec["thr"]
	var pool: Array = POOL[q]
	# Cellules occupées : toutes sauf celles du mini-boss ; les cellules en trop restent vides (roche), sans couper
	# la grille.
	var cells: Array[Vector2i] = []
	for row in rows:
		for col in cols:
			var v := Vector2i(col, row)
			if not mb.has(v):
				cells.append(v)
	var empty := cells.size() - 1 - pool.size()
	for t in 200:
		if empty <= 0:
			break
		var trial := cells.duplicate()
		for n in empty:
			var pick: Vector2i = trial[floori(_r.next() * trial.size())]
			while pick == thr:
				pick = trial[floori(_r.next() * trial.size())]
			trial.erase(pick)
		if _grid_connected(trial, thr):
			cells = trial
			break
	# Arbre couvrant tiré au hasard depuis le seuil ; on le retire tant qu'il n'offre aucune feuille libre pour
	# la salle secrète (ni le seuil ni l'accroche du mini-boss).
	var edges: Array = []
	var dist := {}
	var mb_anchor := Vector2i(-1, -1)
	var leaves: Array = []
	for attempt in 50:
		edges = _spanning_tree(cells, thr)
		dist = _grid_dist(cells, edges, thr)
		# Mini-boss : cul-de-sac accroché à la cellule voisine la plus éloignée du seuil.
		mb_anchor = Vector2i(-1, -1)
		var best := -1
		for m: Vector2i in mb:
			for d: Vector2i in [Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0)]:
				var n: Vector2i = m + d
				if cells.has(n) and int(dist[n]) > best:
					best = dist[n]
					mb_anchor = n
		var degree := {}
		for c in cells:
			degree[c] = 0
		for ed: Array in edges:
			degree[ed[0]] += 1
			degree[ed[1]] += 1
		leaves = cells.filter(func(c: Vector2i) -> bool: return degree[c] == 1 and c != thr and c != mb_anchor)
		if not leaves.is_empty():
			break
	# Salle secrète : une feuille de l'arbre, reliée par une fissure (lien « secret », à creuser).
	var secret: Vector2i = leaves[floori(_r.next() * leaves.size())]
	# Une boucle entre deux cellules voisines non reliées (hors secrète).
	var extra: Array = []
	for c in cells:
		for d: Vector2i in [Vector2i(1, 0), Vector2i(0, 1)]:
			var n: Vector2i = c + d
			if c != secret and n != secret and cells.has(n) and not _has_edge(edges, c, n):
				extra.append([c, n])
	if not extra.is_empty():
		edges.append(extra[floori(_r.next() * extra.size())])
	# Genres : seuil, secrète, puis le reste du tirage ; les combats sont rangés du plus léger au plus dur
	# selon la distance au seuil.
	var kinds := {thr: ["transit", "threshold", ""], secret: ["secret", "", ""]}
	var others: Array = pool.filter(func(p: Array) -> bool: return p[0] != "secret")
	var combats: Array = others.filter(func(p: Array) -> bool: return p[0] == "combat")
	var rest: Array = others.filter(func(p: Array) -> bool: return p[0] != "combat")
	var free := cells.filter(func(c: Vector2i) -> bool: return not kinds.has(c))
	free.sort_custom(func(u: Vector2i, v: Vector2i) -> bool: return dist[u] < dist[v] or (dist[u] == dist[v] and (u.y > v.y or (u.y == v.y and u.x < v.x))))
	# Les non-combats prennent des cellules au hasard ; les combats remplissent le reste, dans l'ordre des distances.
	var slots := free.duplicate()
	for p: Array in rest:
		var at: Vector2i = slots[floori(_r.next() * slots.size())]
		slots.erase(at)
		kinds[at] = p
	combats.sort_custom(func(u: Array, v: Array) -> bool: return "LMD".find(u[2]) < "LMD".find(v[2]))
	for k in combats.size():
		kinds[slots[k]] = combats[k]
	# Pylône : le combat moyen le plus éloigné du seuil (biomes 1 à 6 ; ignoré ailleurs).
	var pylon := Vector2i(-1, -1)
	for k in range(slots.size() - 1, -1, -1):
		if kinds[slots[k]][2] == "M":
			pylon = slots[k]
			break
	var ids := {}
	for c in cells:
		var p: Array = kinds[c]
		ids[c] = _add_room(p[0], p[1], p[2], q, _place(cell_rect.call(c), p[0], p[1], p[2]), c == thr and q == "C", c == pylon)
	if not mb.is_empty():
		var rr: Rect2i = cell_rect.call(mb[0])
		for m: Vector2i in mb:
			rr = rr.merge(cell_rect.call(m))
		var arena := _place(rr, "miniboss", "", "")
		# Taille imposée par le combat (dôme de la Martyre) : centrée dans ses cellules.
		var forced: Vector2i = spec.get("mb_size", Vector2i.ZERO)
		if forced != Vector2i.ZERO:
			var s := Vector2i(mini(forced.x, rr.size.x - 2), mini(forced.y, rr.size.y - 2))
			arena = Rect2i(rr.position + (rr.size - s) / 2, s)
		var mid := _add_room("miniboss", "mb1" if q == "A" else "mb2", "", q, arena, true, false)
		for m: Vector2i in mb:
			ids[m] = mid
		_link(ids[mb_anchor], mid, "corridor", "")
	for ed in edges:
		_link(ids[ed[0]], ids[ed[1]], "secret" if ed[0] == secret or ed[1] == secret else "corridor", "")
	return ids


## Salle de genre `kind` posée au hasard dans la cellule (une case de marge).
func _place(cell: Rect2i, kind: String, role: String, tier: String) -> Rect2i:
	var key := tier if kind == "combat" else ("outpost" if role == "outpost" else kind)
	var s: Array = SIZE[key]
	var w := mini(_ri(s[0], s[1]), cell.size.x - 2)
	var h := mini(_ri(s[2], s[3]), cell.size.y - 2)
	var x := cell.position.x + 1 + _ri(0, cell.size.x - 2 - w)
	var y := cell.position.y + 1 + _ri(0, cell.size.y - 2 - h)
	return Rect2i(x, y, w, h)


# ---------------------------------------------------------------- Route du boss

## Étages du nord au sud, espacés régulièrement ; mur « mb2 » entre la rangée des salles dures et le hub.
func _route(area: Rect2i, strip_top: int, walls: Dictionary) -> Dictionary:
	var cx := area.position.x + area.size.x / 2
	var hs: Array[int] = [ROUTE["boss"].y, ROUTE["antechamber"].y, ROUTE["D"].y, ROUTE["hub"].y, ROUTE["entrance"].y]
	var gaps: Array[int] = [ROUTE_GAP, ROUTE_GAP, ROUTE_WALL_GAP, ROUTE_GAP]
	var used := 0
	for h in hs:
		used += h
	for g in gaps:
		used += g
	# Une case de marge au nord, l'entrée posée juste au-dessus du couloir sud.
	var slack := maxi(0, strip_top - 1 - area.position.y - 1 - used)
	var y := area.position.y + 1
	var tops: Array[int] = []
	for k in hs.size():
		tops.append(y)
		y += hs[k]
		if k < gaps.size():
			y += gaps[k] + slack / gaps.size() + (1 if k < slack % gaps.size() else 0)
	var at := func(key: String, top: int, dx: int) -> Rect2i:
		var s: Vector2i = ROUTE[key]
		return Rect2i(cx + dx - s.x / 2, top, s.x, s.y)
	var boss := _add_room("boss", "", "", "R", at.call("boss", tops[0], 0), false, false)
	var ante := _add_room("transit", "antechamber", "", "R", at.call("antechamber", tops[1], 0), true, false)
	var spread := mini(15, area.size.x / 2 - ROUTE["D"].x / 2 - 1)
	var jitter := _ri(-2, 2)
	var d1 := _add_room("combat", "", "D", "R", at.call("D", tops[2], -spread + jitter), false, false)
	var rest := _add_room("calm", "rest", "", "R", at.call("rest", tops[2] + 1, jitter), false, false)
	var d2 := _add_room("combat", "", "D", "R", at.call("D", tops[2], spread + jitter), false, false)
	var hub := _add_room("transit", "hub", "", "R", at.call("hub", tops[3], 0), true, false)
	var entrance := _add_room("transit", "entrance", "", "R", at.call("entrance", tops[4], 0), false, false)
	var wall_j := tops[3] - 1 - (tops[3] - (tops[2] + ROUTE["D"].y)) / 2
	for i in range(area.position.x - WALL, area.end.x + WALL):
		walls[Vector2i(i, wall_j)] = true
	_link(entrance, hub, "corridor", "")
	_link(hub, d1, "corridor", "mb2")
	_link(d1, rest, "corridor", "")
	_link(rest, d2, "corridor", "")
	# Monter d'abord : un coude à l'horizontale traverserait la salle de repos.
	_link(d2, ante, "corridor", "", true)
	_link(ante, boss, "corridor", "")
	return {"hub": hub, "entrance": entrance, "boss": boss}


# ---------------------------------------------------------------- Outils

func _add_room(kind: String, role: String, tier: String, quarter: String, rect: Rect2i, portal: bool, pylon: bool) -> int:
	_rooms.append({"id": _rooms.size(), "kind": kind, "role": role, "tier": tier, "quarter": quarter, "rect": rect,
		"portal": portal or role in ["hub", "antechamber"] or kind == "miniboss", "pylon": pylon, "fixed": false})
	return _rooms.size() - 1


func _center(id: int) -> Vector2i:
	var r: Rect2i = _rooms[id]["rect"]
	return r.position + r.size / 2


## Couloir entre deux salles : droit si leurs étendues se chevauchent, sinon en L (horizontal puis vertical, ou
## vertical puis horizontal avec `vertical_first`).
func _link(a: int, b: int, kind: String, door: String, vertical_first := false) -> void:
	var ra: Rect2i = _rooms[a]["rect"]
	var rb: Rect2i = _rooms[b]["rect"]
	var ca := _center(a)
	var cb := _center(b)
	var path: Array[Vector2i] = []
	var z0 := maxi(ra.position.y + 1, rb.position.y + 1)
	var z1 := mini(ra.end.y - 2, rb.end.y - 2)
	var x0 := maxi(ra.position.x + 1, rb.position.x + 1)
	var x1 := mini(ra.end.x - 2, rb.end.x - 2)
	if z0 <= z1:
		var z := (z0 + z1) / 2
		path = [Vector2i(ca.x, z), Vector2i(cb.x, z)]
	elif x0 <= x1:
		var x := (x0 + x1) / 2
		path = [Vector2i(x, ca.y), Vector2i(x, cb.y)]
	elif vertical_first:
		path = [ca, Vector2i(ca.x, cb.y), cb]
	else:
		path = [ca, Vector2i(cb.x, ca.y), cb]
	_links.append({"a": a, "b": b, "kind": kind, "door": door, "path": path})


## Cases couvertes par un couloir (ligne brisée élargie à CORRIDOR_W).
static func corridor_cells(path: Array[Vector2i]) -> Array[Vector2i]:
	var out := {}
	var r := CORRIDOR_W / 2
	for k in path.size() - 1:
		var p := path[k]
		var q := path[k + 1]
		for i in range(mini(p.x, q.x) - r, maxi(p.x, q.x) + r + 1):
			for j in range(mini(p.y, q.y) - r, maxi(p.y, q.y) + r + 1):
				out[Vector2i(i, j)] = true
	var cells: Array[Vector2i] = []
	cells.assign(out.keys())
	return cells


## Salles accessibles depuis l'entrée par les couloirs, portes `open_keys` ouvertes (les fissures ne comptent pas).
static func reachable(layout: Dictionary, open_keys: Array = []) -> Dictionary:
	var start := -1
	for r: Dictionary in layout["rooms"]:
		if r["role"] == "entrance":
			start = r["id"]
	var adj := {}
	for l: Dictionary in layout["links"]:
		if l["kind"] != "corridor" or (l["door"] != "" and not open_keys.has(l["door"])):
			continue
		(adj.get_or_add(l["a"], []) as Array).append(l["b"])
		(adj.get_or_add(l["b"], []) as Array).append(l["a"])
	var seen := {start: true}
	var queue: Array = [start]
	while not queue.is_empty():
		var k: int = queue.pop_front()
		for n: int in adj.get(k, []):
			if not seen.has(n):
				seen[n] = true
				queue.append(n)
	return seen


func _ri(a: int, b: int) -> int:
	return a + floori(_r.next() * float(b - a + 1))


static func _has_edge(edges: Array, u: Vector2i, v: Vector2i) -> bool:
	return edges.any(func(e: Array) -> bool: return (e[0] == u and e[1] == v) or (e[0] == v and e[1] == u))


static func _grid_connected(cells: Array[Vector2i], from: Vector2i) -> bool:
	var seen := {from: true}
	var queue: Array[Vector2i] = [from]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if cells.has(n) and not seen.has(n):
				seen[n] = true
				queue.append(n)
	return seen.size() == cells.size()


## Arbre couvrant aléatoire (Prim) sur la grille des cellules occupées.
func _spanning_tree(cells: Array[Vector2i], from: Vector2i) -> Array:
	var inside := {from: true}
	var edges: Array = []
	while inside.size() < cells.size():
		var frontier: Array = []
		for c: Vector2i in inside:
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n: Vector2i = c + d
				if cells.has(n) and not inside.has(n):
					frontier.append([c, n])
		frontier.sort_custom(func(u: Array, v: Array) -> bool: return _key(u) < _key(v))
		var e: Array = frontier[floori(_r.next() * frontier.size())]
		inside[e[1]] = true
		edges.append(e)
	return edges


## Ordre stable des arêtes candidates (les dictionnaires ne garantissent pas l'ordre d'insertion d'une graine à l'autre).
static func _key(e: Array) -> int:
	var u: Vector2i = e[0]
	var v: Vector2i = e[1]
	return ((u.y * 8 + u.x) * 8 + v.y) * 8 + v.x


static func _grid_dist(cells: Array[Vector2i], edges: Array, from: Vector2i) -> Dictionary:
	var adj := {}
	for e: Array in edges:
		(adj.get_or_add(e[0], []) as Array).append(e[1])
		(adj.get_or_add(e[1], []) as Array).append(e[0])
	var dist := {from: 0}
	var queue: Array[Vector2i] = [from]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		for n: Vector2i in adj.get(c, []):
			if not dist.has(n):
				dist[n] = int(dist[c]) + 1
				queue.append(n)
	for c in cells:
		if not dist.has(c):
			dist[c] = 99
	return dist
