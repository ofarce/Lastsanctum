class_name CaveDoors
## Portes des tunnels (planches/portes-tunnels-propositions.html, choix du 2026-11-25 : P1 « Vantaux cerclés »,
## F2 « Porte qui garde », R1 « Vantaux enfoncés »).
##
## - Une porte à deux battants de chêne cerclés de fer ferme chaque bouche de tunnel qui part de la grotte de départ.
##   Le Temple en salles n'en a que deux, fixes quelle que soit la graine (RoomLayout.TEMPLE_EXIT_HUB et TEMPLE_EXIT_C,
##   contrôle : tools/portes/probe.tscn) : la bouche nord (couloir du hub) et la bouche est (couloir sud vers C).
##   La porte sud de la grotte (séquence d'ouverture) n'est pas concernée.
## - Porte qui garde : fermée par défaut, elle s'ouvre seule devant un allié (OPEN_R) et se referme derrière lui. Les
##   chemins la traversent (elle n'est pas un mur pour le Pathfinder) mais un ennemi ne peut pas franchir une porte
##   fermée : il est retenu contre elle (enforce) et la frappe s'il n'a rien d'autre à frapper, ou si sa cible est de
##   l'autre côté (Combat.update_enemies). Rien ne tire à travers une porte fermée (blocks, dans Combat.clear_shot) :
##   les tireurs s'approchent et la frappent comme la mêlée. PV d'une barricade (Placeables.barricade_max, Palissades comprises). À 0 PV
##   elle est enfoncée : on passe librement jusqu'à l'aube, où elle se relève, PV pleins.
## - Portes détruites (ruins) : à l'entrée de chaque salle-seuil de quartier (A, B, C du Temple et des Salles oubliées),
##   là où le couloir venu d'un autre quartier entre dans la salle. Décor seul.
## État : GameState.cave_doors (un dictionnaire par bouche, sauvegardé avec GameState). Rendu : world/reperes/cave_door_view.gd.

## Bouches : segment de la porte (a → b, unités), normale vers le tunnel (« dehors »), nom pour la bannière.
## Nord : couloir x −28…−16, porte au-dessus de la baie de la paroi (z −184). Est : couloir z −116…−104, porte au bord
## de la grotte (x 64).
const MOUTHS := [
	{"id": "n", "a": Vector2(-28.0, -184.0), "b": Vector2(-16.0, -184.0), "out": Vector2(0.0, -1.0), "name": "nord"},
	{"id": "e", "a": Vector2(64.0, -116.0), "b": Vector2(64.0, -104.0), "out": Vector2(1.0, 0.0), "name": "est"},
]
## Un allié à moins de OPEN_R unités du seuil ouvre la porte ; ouverture et fermeture en SWING secondes.
const OPEN_R := 4.0
const SWING := 0.45
## Au-delà de PASS d'ouverture, les battants sont contre les parois : plus rien ne retient les ennemis.
const PASS := 0.9
## Demi-épaisseur retenue de part et d'autre du seuil ; marge en bout de segment.
const BODY := 0.6
const END_MARGIN := 0.4
## Un ennemi « touche » la porte à moins de TOUCH unités du seuil.
const TOUCH := 1.6
## Zone autour des portes où l'on retient les positions des ennemis (unités).
const NEAR := 24.0
## Ruines : un goulot fait au plus MOUTH_MAX cases de large ; on le cherche sur les MOUTH_LOOK dernières cases du
## couloir avant la salle.
const MOUTH_MAX := 4
const MOUTH_LOOK := 14

## Positions des ennemis proches au début du tick : {Enemy: Vector2}.
static var _prev := {}
static var _phase := ""
static var _ruins_seed := -1
static var _ruins: Array[Dictionary] = []


## Vrai si le Temple en salles a ses portes (hors parité JS) et que GameState.cave_doors est prêt.
static func active(st: TerrainState) -> bool:
	if st == null or st.temple_layout.is_empty():
		return false
	if GameState.cave_doors.size() != MOUTHS.size():
		GameState.cave_doors.clear()
		for m: Dictionary in MOUTHS:
			var hp := Simulation.Placeables.barricade_max()
			GameState.cave_doors.append({"hp": hp, "max_hp": hp, "open": 0.0, "broken": false, "hit_at": -INF})
	return true


## Porte i fermée (même en partie) et debout : elle retient les ennemis.
static func shut(i: int) -> bool:
	var d: Dictionary = GameState.cave_doors[i]
	return not d["broken"] and float(d["open"]) < PASS


static func mid(i: int) -> Vector2:
	var m: Dictionary = MOUTHS[i]
	return ((m["a"] as Vector2) + (m["b"] as Vector2)) * 0.5


## (côté, abscisse le long du seuil) de p par rapport à la porte i : côté > 0 dehors (tunnel), < 0 dans la grotte.
static func _local(i: int, p: Vector2) -> Vector2:
	var m: Dictionary = MOUTHS[i]
	var a: Vector2 = m["a"]
	var b: Vector2 = m["b"]
	var t := (b - a).normalized()
	return Vector2((p - a).dot(m["out"]), (p - a).dot(t))


static func _span(i: int, along: float) -> bool:
	var m: Dictionary = MOUTHS[i]
	return along >= -END_MARGIN and along <= (m["b"] as Vector2).distance_to(m["a"]) + END_MARGIN


static func _seg_dist(i: int, p: Vector2) -> float:
	var m: Dictionary = MOUTHS[i]
	return p.distance_to(Geometry2D.get_closest_point_to_segment(p, m["a"], m["b"]))


## Début du tick, avant les ennemis : ouverture des portes devant les alliés, relève à l'aube, positions retenues.
static func before(sim: Simulation, dt: float, alive: Array[Unit]) -> void:
	var st := sim.state()
	if not active(st):
		return
	var phase := DayNight.phase(GameState.sim_time)
	if phase != _phase:
		if _phase != "" and phase == "aube":
			_rise(sim)
		_phase = phase
	var top := Simulation.Placeables.barricade_max()
	for i in MOUTHS.size():
		var d: Dictionary = GameState.cave_doors[i]
		if float(d["max_hp"]) != top:
			d["hp"] = float(d["hp"]) * top / maxf(float(d["max_hp"]), 1.0)
			d["max_hp"] = top
		var want := 0.0
		if not d["broken"]:
			for u in alive:
				if not u.hidden and _seg_dist(i, u.pos()) < OPEN_R:
					want = 1.0
					break
		d["open"] = move_toward(float(d["open"]), want, dt / SWING)
	_prev.clear()
	for e: Enemy in GameState.enemies:
		if e.hp <= 0.0:
			continue
		for i in MOUTHS.size():
			if _seg_dist(i, e.pos()) < NEAR:
				_prev[e] = e.pos()
				break


## Après les ennemis : aucun ne franchit une porte fermée ; celui qui s'y trouve est rendu à son côté.
static func enforce(sim: Simulation) -> void:
	if _prev.is_empty() or not active(sim.state()):
		return
	for e: Enemy in _prev:
		if not is_instance_valid(e) or e.hp <= 0.0:
			continue
		var before_p: Vector2 = _prev[e]
		for i in MOUTHS.size():
			if not shut(i):
				continue
			var now := _local(i, e.pos())
			if not _span(i, now.y) or absf(now.x) >= BODY and signf(now.x) == signf(_local(i, before_p).x):
				continue
			var was := _local(i, before_p).x
			var side := 1.0 if (was > 0.0 or (was == 0.0 and now.x >= 0.0)) else -1.0
			var out: Vector2 = MOUTHS[i]["out"]
			var p := e.pos() + out * (side * BODY - now.x)
			e.x = p.x
			e.z = p.y


## Porte fermée que l'ennemi touche, ou −1.
static func touched(e: Unit) -> int:
	if GameState.cave_doors.size() != MOUTHS.size():
		return -1
	for i in MOUTHS.size():
		if shut(i):
			var l := _local(i, e.pos())
			if absf(l.x) <= TOUCH and _span(i, l.y):
				return i
	return -1


## Vrai si la porte i sépare p de q (de part et d'autre du seuil).
static func between(i: int, p: Vector2, q: Vector2) -> bool:
	return signf(_local(i, p).x) != signf(_local(i, q).x)


## Vrai si une porte fermée coupe le segment a → b : rien ne tire à travers (Combat.clear_shot).
static func blocks(a: Vector2, b: Vector2) -> bool:
	if GameState.cave_doors.size() != MOUTHS.size():
		return false
	for i in MOUTHS.size():
		if shut(i) and Geometry2D.segment_intersects_segment(a, b, MOUTHS[i]["a"], MOUTHS[i]["b"]) != null:
			return true
	return false


## Coup porté à la porte i ; à 0 PV elle est enfoncée jusqu'à l'aube.
static func hit(sim: Simulation, i: int, dmg: float) -> void:
	var d: Dictionary = GameState.cave_doors[i]
	if d["broken"]:
		return
	d["hp"] = float(d["hp"]) - dmg
	d["hit_at"] = GameState.sim_time
	var c := mid(i)
	if float(d["hp"]) > 0.0:
		return
	d["hp"] = 0.0
	d["broken"] = true
	d["broken_at"] = GameState.sim_time
	Combat.zone(c.x, c.y, 6.0, Color("#b4a07a"))
	Sfx.at("objet_pose", c.x, c.y)
	sim.say("La porte %s de la grotte est enfoncée !" % MOUTHS[i]["name"], 3.0)


## Aube : les portes enfoncées ou entamées se relèvent, PV pleins.
static func _rise(sim: Simulation) -> void:
	var any := false
	for d: Dictionary in GameState.cave_doors:
		if d["broken"] or float(d["hp"]) < float(d["max_hp"]):
			any = any or d["broken"]
			d["broken"] = false
			d["hp"] = d["max_hp"]
	if any:
		sim.say("À l’aube, les portes de la grotte sont relevées.", 3.0)


# ---------------------------------------------------------------- Portes détruites

## Entrées des salles-seuils : [{quarter, mid: Vector2 (milieu du seuil, unités), into: Vector2i (vers la salle),
## a, b (bouts du seuil)}], pour le Temple puis les Salles oubliées (quartiers « VA »…).
static func ruins(st: TerrainState) -> Array[Dictionary]:
	if st == null or st.temple_layout.is_empty():
		return []
	if _ruins_seed == st.seed and not _ruins.is_empty():
		return _ruins
	_ruins_seed = st.seed
	_ruins = []
	for lay: Dictionary in [st.temple_layout, st.veines_layout]:
		if lay.is_empty():
			continue
		var pre := "V" if lay == st.veines_layout else ""
		var by_id := {}
		for room: Dictionary in lay["rooms"]:
			by_id[int(room["id"])] = room
		for room: Dictionary in lay["rooms"]:
			if room["role"] != "threshold":
				continue
			for l: Dictionary in lay["links"]:
				if l["kind"] != "corridor" or (int(l["a"]) != int(room["id"]) and int(l["b"]) != int(room["id"])):
					continue
				var other: Dictionary = by_id.get(int(l["b"]) if int(l["a"]) == int(room["id"]) else int(l["a"]), {})
				if other.get("quarter", "") == room["quarter"]:
					continue
				var path: Array = (l["path"] as Array).duplicate()
				if int(l["a"]) == int(room["id"]):
					path.reverse()
				var r := _entry(st, room["rect"], path)
				if not r.is_empty():
					r["quarter"] = pre + room["quarter"]
					_ruins.append(r)
	return _ruins


## Seuil de la ruine sur la ligne brisée `path` (cases) qui mène à `rect` : au bout du dernier goulot du couloir avant
## la salle (case dont le sol, en travers, tient en MOUTH_MAX cases bornées de roche), centré sur sa largeur réelle.
## Un couloir qui longe la salle avant d'y entrer (couloir sud de C) a donc sa ruine là où il s'ouvre, pas au milieu
## du carrefour. Sans goulot trouvé : le bord de la salle, comme avant.
static func _entry(st: TerrainState, rect: Rect2i, path: Array) -> Dictionary:
	if path.is_empty():
		return {}
	var cells: Array[Vector2i] = [path[0]]
	for k in range(1, path.size()):
		var to: Vector2i = path[k]
		var cur: Vector2i = cells[-1]
		while cur != to:
			cur += Vector2i(signi(to.x - cur.x), 0) if cur.x != to.x else Vector2i(0, signi(to.y - cur.y))
			cells.append(cur)
	var enter := -1
	for k in range(1, cells.size()):
		if rect.has_point(cells[k]) and not rect.has_point(cells[k - 1]):
			enter = k
			break
	if enter < 0:
		return {}
	for j in range(enter - 1, maxi(-1, enter - 1 - MOUTH_LOOK), -1):
		var step := cells[j + 1] - cells[j]
		var ext := _extent(st, cells[j], Vector2i(absi(step.y), absi(step.x)))
		if ext.is_empty():
			continue
		var perp := Vector2(absf(step.y), absf(step.x))
		var lo := Vector2(cells[j]) * 4.0 + Vector2(2.0, 2.0) + perp * (float(ext[0]) * 4.0 - 2.0) + Vector2(step) * 2.0
		var hi := Vector2(cells[j]) * 4.0 + Vector2(2.0, 2.0) + perp * (float(ext[1]) * 4.0 + 2.0) + Vector2(step) * 2.0
		return {"mid": (lo + hi) * 0.5, "into": step, "a": lo, "b": hi}
	var nxt := cells[enter]
	var st0 := nxt - cells[enter - 1]
	var edge := Vector2(nxt) * 4.0 + Vector2(2.0, 2.0) - Vector2(st0) * 2.0
	var t := Vector2(absf(st0.y), absf(st0.x)) * 6.0
	return {"mid": edge, "into": st0, "a": edge - t, "b": edge + t}


## Largeur du sol en travers de la case c (direction perp) : [premier, dernier] décalage en cases, ou [] si elle passe
## MOUTH_MAX cases ou n'est pas bornée de roche des deux côtés.
static func _extent(st: TerrainState, c: Vector2i, perp: Vector2i) -> Array:
	var gal := func(q: Vector2i) -> bool: return st.is_gallery(q.x * 4.0 + 2.0, q.y * 4.0 + 2.0)
	if not gal.call(c):
		return []
	var lo := 0
	var hi := 0
	while gal.call(c + perp * (lo - 1)):
		lo -= 1
		if hi - lo + 1 > MOUTH_MAX:
			return []
	while gal.call(c + perp * (hi + 1)):
		hi += 1
		if hi - lo + 1 > MOUTH_MAX:
			return []
	return [lo, hi]
