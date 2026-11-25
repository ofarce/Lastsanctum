class_name QuarterMarks
extends RefCounted
## Repères d'entrée de quartier (planches/quartiers-entrees-propositions.html validée le 2026-11-22 ; dessins :
## planches/reperes-entrees-rendu.html, stèle S1 et arche A1 choisies le 2026-11-23 ; atlas assets/imported/reperes/,
## tools/reperes/export.py).
##
## - Dans la salle-seuil de chaque quartier (A, B, C) du Temple en salles : l'arche contre la paroi nord, la stèle à sa
##   gauche. Glyphe et flammes à la couleur du quartier (A ambre · Spirale, B azur · Fourche, C carmin · Œil fendu).
## - Éteints jusqu'à ce qu'un allié passe à LIGHT_R unités ; allumés pour de bon ensuite (GameState.quarter_lit).
## - Carton au premier passage de l'Exilé dans un quartier : nom et ligne de rappel (CARD_FIRST s) ; ensuite, le nom
##   seul (CARD_AGAIN s) chaque fois qu'il change de quartier. La route du boss (« R ») n'a ni stèle ni arche : son
##   carton vient en passant la porte de l'Orbite (salles de la route au-delà du hub).
## Rendu : world/reperes/quarter_mark_view.gd (repères), ui/hud/quarter_card.gd (carton).

const LIGHT_R := 20.0
const CARD_FIRST := 3.0
const CARD_AGAIN := 2.0
## Couleurs des quartiers (planche des repères) ; la route du boss en or.
## Salles oubliées (planches/salles-oubliees-decor-propositions.html, Q1 choisi le 2026-11-25) : quartiers « VA »,
## « VB », « VC », « VR » ; repères verdis (stele_V*, arch_V*), couleurs eau, cuivre, vert-de-gris.
const COLOR := {"A": Color("#f0a040"), "B": Color("#58a8f0"), "C": Color("#e04048"), "R": Color("#ddb457"),
	"VA": Color("#4aa6b8"), "VB": Color("#d88a48"), "VC": Color("#6cc4a0"), "VR": Color("#ddb457")}
## Glyphes tyriens des quartiers (7 × 7) : A la Spirale, B la Fourche, C l'Œil fendu (minicarte, portes).
const GLYPH := {
	"A": ["#######", "#.....#", "#.###.#", "#.#.#.#", "#.#...#", "#.#####", "#......"],
	"B": ["#..#..#", "#..#..#", "#..#..#", "#######", "...#...", "...#...", "..###.."],
	"C": ["..###..", ".#...#.", "#..#..#", "#.###.#", "#..#..#", ".#...#.", "..###.."],
	"VA": ["#######", "#.....#", "#..#..#", "#..#..#", "#.###.#", "#.....#", "#######"],
	"VB": ["#.#.#.#", "#.#.#.#", "#######", "#.#.#.#", "#.#.#.#", ".......", ".#.#.#."],
	"VC": ["...#...", "..#.#..", ".#...#.", "#.....#", "#..#..#", ".#...#.", "..###.."],
}
## Noms du Temple (planches/quartiers-entrees-propositions.html) et lignes de rappel.
const NAMES := {"A": "LES CLOÎTRES", "B": "LA NEF DORÉE", "C": "LES RACINES", "R": "L’ORBITE",
	"VA": "LES PUITS", "VB": "LES ÉCLUSES", "VC": "LA GRANDE PATINE", "VR": "L’ANTRE DE LA GORGE"}
const SUBS := {"A": "Temple · quartier A · exp. 1", "B": "Temple · quartier B · exp. 2", "C": "Temple · quartier C · menace +1",
	"R": "Temple · route du boss", "VA": "Salles oubliées · quartier A · exp. 1", "VB": "Salles oubliées · quartier B · exp. 2",
	"VC": "Salles oubliées · quartier C · menace +1", "VR": "Salles oubliées · route du boss"}


## Arche élargie (QuarterMarkView) : ouverture du dessin d'origine, en px natifs.
const ARCH_OPEN := 23.0

static var _marks_state: TerrainState = null
static var _marks_seed := -1
static var _marks: Array[Dictionary] = []


## Repères du plan : [{quarter, kind: "arch" | "stele", x, z, span?}] ; vide sans plan. En cache par carte.
## Arche (choix du 2026-11-25 « Encadrer le couloir ») : si un couloir part de la paroi nord de la salle-seuil, l'arche
## se pose sur sa bouche, élargie à sa largeur (« span », unités) ; sinon contre la partie pleine de la paroi nord la
## plus proche du milieu. Jamais sur la bouche où se tient la porte enfoncée (CaveDoors.ruins). La stèle va à gauche de
## l'arche (à droite si la paroi y est ouverte ou hors de la salle), contre de la roche.
static func marks(st: TerrainState) -> Array[Dictionary]:
	if st == null or st.temple_layout.is_empty():
		return []
	if _marks_state == st and _marks_seed == st.seed:
		return _marks
	_marks_state = st
	_marks_seed = st.seed
	_marks = []
	var ruins := CaveDoors.ruins(st)
	for lay: Dictionary in [st.temple_layout, st.veines_layout]:
		if lay.is_empty():
			continue
		var pre := "V" if lay == st.veines_layout else ""
		for room: Dictionary in lay["rooms"]:
			if room["role"] != "threshold":
				continue
			_place_marks(st, room["rect"], pre + room["quarter"], ruins)
	return _marks


static func _place_marks(st: TerrainState, rr: Rect2i, q: String, ruins: Array[Dictionary]) -> void:
	var row := rr.position.y - 1
	var north := rr.position.y * 4.0
	var open := func(i: int) -> bool: return st.is_gallery(i * 4.0 + 2.0, row * 4.0 + 2.0)
	var ruined := func(x: float) -> bool:
		for r: Dictionary in ruins:
			var m: Vector2 = r["mid"]
			if absf(m.y - north) < 2.5 and absf(m.x - x) < 10.0:
				return true
		return false
	var mid_x := rr.position.x * 4.0 + rr.size.x * 2.0
	# Bouches du nord : suites de cases ouvertes juste au-dessus de la salle.
	var best: Array = []
	var i := rr.position.x
	while i < rr.end.x:
		if not open.call(i):
			i += 1
			continue
		var j := i
		while j + 1 < rr.end.x and open.call(j + 1):
			j += 1
		var cx := (i + j + 1) * 2.0
		if j - i + 1 >= 2 and j - i + 1 <= CaveDoors.MOUTH_MAX and not ruined.call(cx) and (best.is_empty() or absf(cx - mid_x) < absf(float(best[0]) - mid_x)):
			best = [cx, (j - i + 1) * 4.0]
		i = j + 1
	var ax := mid_x
	var az := north + 4.5
	var arch := {"quarter": q, "kind": "arch"}
	if not best.is_empty():
		ax = best[0]
		az = north + 0.6
		arch["span"] = best[1]
	else:
		# Paroi pleine : l'arche (7 u) à la jonction de deux cases de roche, la plus proche du milieu.
		var bd := INF
		for k in range(rr.position.x + 1, rr.end.x):
			if open.call(k - 1) or open.call(k) or ruined.call(k * 4.0):
				continue
			if absf(k * 4.0 - mid_x) < bd:
				bd = absf(k * 4.0 - mid_x)
				ax = k * 4.0
	arch["x"] = ax
	arch["z"] = az
	_marks.append(arch)
	# Stèle : une case de la salle adossée à la roche, hors de l'arche et des bouches, au plus près de sa gauche.
	var half := float(arch.get("span", 7.0)) * 0.5
	var want := ax - half - 4.5
	var sx := want
	var sd := INF
	for c in range(rr.position.x, rr.end.x):
		var x := c * 4.0 + 2.0
		if open.call(c) or absf(x - ax) < half + 2.0 or ruined.call(x):
			continue
		var cost := absf(x - want) + (0.0 if x < ax else 6.0)
		if cost < sd:
			sd = cost
			sx = x
	_marks.append({"quarter": q, "kind": "stele", "x": sx, "z": north + 5.5})


## Quartier où se tient `p` pour le carton : A, B ou C dans leur rectangle ; R dans les salles de la route au-delà du
## hub (salles dures, repos, antichambre, arène de l'Œil) ; "" ailleurs (grotte, hub, couloirs de la route).
## Dans les Salles oubliées, les mêmes quartiers préfixés « V » (VA, VB, VC, VR).
static func quarter_at(st: TerrainState, p: Vector2) -> String:
	var room := st.temple_room(p.x, p.y)
	if int(room.get("biome", 0)) == 1 or (room.is_empty() and not st.veines_layout.is_empty() and Biomes.index_at(p.y) == 1):
		return _quarter_in(st.veines_layout, room, p, "V")
	if int(room.get("biome", 0)) != 0 or p.y < TerrainState.frontier_z():
		return ""
	return _quarter_in(st.temple_layout, room, p, "")


static func _quarter_in(lay: Dictionary, room: Dictionary, p: Vector2, pre: String) -> String:
	if lay.is_empty():
		return ""
	if not room.is_empty() and room["quarter"] == "R":
		return "" if room["role"] in ["entrance", "hub"] else pre + "R"
	var c := Vector2i(floori(p.x / 4.0), floori(p.y / 4.0))
	for q: String in ["A", "B", "C"]:
		if (lay["quarters"][q] as Rect2i).has_point(c):
			return pre + q
	return ""


static func tick(sim: Simulation) -> void:
	var st := sim.state()
	if st == null or st.temple_layout.is_empty() or GameState.ended:
		return
	# Allumage : un allié vivant et visible à LIGHT_R du pied de la stèle.
	var w: Awaken.Watch = null
	for m: Dictionary in marks(st):
		if m["kind"] != "stele" or GameState.quarter_lit.has(m["quarter"]):
			continue
		if w == null:
			w = Awaken.watch()
		if w.seen(Vector2(m["x"], m["z"]), LIGHT_R):
			GameState.quarter_lit[m["quarter"]] = true
			Sfx.at("portail", m["x"], m["z"])
	# Carton : l'Exilé (incarné, sinon l'Ingénieur) change de quartier.
	var u: Unit = GameState.incarnated if GameState.incarnated != null else Capsule.engineer()
	if u == null or not u.alive() or u.hidden:
		return
	var q := quarter_at(st, u.pos())
	if q == "" or q == GameState.quarter_last:
		if q != "":
			GameState.quarter_last = q
		return
	GameState.quarter_last = q
	var first := not GameState.quarter_seen.has(q)
	GameState.quarter_seen[q] = true
	GameState.quarter_card = {"name": NAMES[q], "sub": SUBS[q] if first else "", "color": COLOR[q],
		"at": GameState.sim_time, "dur": CARD_FIRST if first else CARD_AGAIN}
