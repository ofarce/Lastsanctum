class_name Roamers
extends RefCounted
## Errants des galeries : petits groupes d'ennemis (meutes de chiens de la Bête, fanatiques du Credo, automates,
## patrouilles de Byrsa dans le biome 2) qui rôdent dans les galeries, loin des Pylônes de Merenor.
##
## - Les tanières sont tirées de la graine (dens) ; un groupe apparaît quand un allié le voit (Awaken.seen) : les
##   galeries sont toutes ouvertes dès le départ (galeries reliées, 2026-11-22).
## - Sans proie, le groupe marche d'un point à l'autre de sa galerie (ROAM unités autour de la tanière), au pas
##   (STROLL), avec une halte entre deux étapes.
## - Une unité repérée (AGGRO, ou la portée de tir) est attaquée par tout le groupe, avec les attaques normales
##   du type (Combat.update_enemies) ; il lâche prise quand elle sort de la laisse (LEASH) et reprend sa ronde.
## - Hors menace et hors fin de vague (beast = true), comme les gardiens des pylônes. Un groupe tué ne revient pas.
##
## Hors parité JS (TerrainState.groves).

## Groupes possibles : poids du tirage, niveau de menace minimal du biome (Biomes.at(z)["threat"]).
const GROUPS: Array[Dictionary] = [
	{"kinds": ["beast", "beast"], "weight": 3, "threat": 1},
	{"kinds": ["beast", "beast", "beast"], "weight": 3, "threat": 1},
	{"kinds": ["creep", "creep", "spitter"], "weight": 3, "threat": 1},
	{"kinds": ["creep", "creep", "creep"], "weight": 2, "threat": 1},
	{"kinds": ["brute"], "weight": 2, "threat": 1},
	{"kinds": ["scout", "soldier", "shield", "archer"], "weight": 4, "threat": 2},
	{"kinds": ["brute", "creep", "spitter", "spitter"], "weight": 2, "threat": 2},
	{"kinds": ["beast", "beast", "beast", "beast", "beast"], "weight": 2, "threat": 2},
	# Faune des Veines de vert-de-gris (biome 2) : tiques de filon, nuées de cinq chauves-souris patinées.
	# Les tiques ne rôdent pas : neutres, collées à leur filon (sim/wildlife.gd).
	{"kinds": ["bat", "bat", "bat", "bat", "bat"], "weight": 6, "threat": 2},
]
const MAX_DENS := 40
## Écarts (unités) : entre deux tanières, avec un pylône (sa salle et la laisse de sa meute), avec l'Ancre.
const DEN_GAP := 44.0
const PYLON_GAP := 36.0
const SAFE := 70.0
## Distance de chemin minimale à l'Ancre (unités, TerrainState.path_at).
const SAFE_PATH := 100.0
## Rayon de la ronde autour de la tanière, distance de repérage, laisse (distance de la proie à la tanière).
const ROAM := 26.0
const AGGRO := 16.0
const LEASH := 44.0
## Allure de la ronde (part de la vitesse du type) et durée maximale d'une étape avant d'en changer.
const STROLL := 0.45
const LEG_TIME := 16.0


## Tanières de la partie (fonction de la graine) : {x, z, threat, kinds}.
static func dens(st: TerrainState, map_seed: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var rng := Rng.new(map_seed ^ 0x70a3)
	var tries := 0
	while out.size() < MAX_DENS and tries < 8000:
		tries += 1
		var x := CaveShape.WORLD_X0 + 10.0 + rng.next() * (CaveShape.WORLD_X1 - CaveShape.WORLD_X0 - 20.0)
		var z := CaveShape.WORLD_Z0 + 10.0 + rng.next() * (CaveShape.WORLD_Z1 - CaveShape.WORLD_Z0 - 20.0)
		if not _roomy(st, x, z) or Vector2(x, z).distance_to(CaveShape.CORE) < SAFE:
			continue
		# Galeries reliées : loin de l'Ancre en chemin, jamais sur un raccord.
		if not st.path_d.is_empty() and st.path_at(x, z) < SAFE_PATH:
			continue
		if st.link_cells.has(Vector2i(floori(x / 4.0), floori(z / 4.0))):
			continue
		if st.frontier and (TerrainState.in_eye_room(x, z, 12.0) or st._in_eye_corridor(x, z)):
			continue
		if _near_pylon(st, x, z) or _crowded(out, x, z):
			continue
		# Temple en salles : seulement dans une salle de combat, en attendant les rencontres de salle.
		if not st.den_allowed(x, z):
			continue
		var threat := int(Biomes.at(z)["threat"])
		out.append({"x": x, "z": z, "threat": threat, "kinds": _draw(rng, threat)})
	return out


## Sol de galerie dégagé sur 3 × 3 unités, sans bosquet, filon, bassin ni socle.
static func _roomy(st: TerrainState, x: float, z: float) -> bool:
	for dz: float in [-1.5, 0.0, 1.5]:
		for dx: float in [-1.5, 0.0, 1.5]:
			var px := x + dx
			var pz := z + dz
			if not st.is_gallery(px, pz) or st.grove_at(px, pz) or st.lode_at(px, pz) or st.water_at(px, pz) or st.pylon_at(px, pz):
				return false
	return true


static func _near_pylon(st: TerrainState, x: float, z: float) -> bool:
	for p: Dictionary in st.portals:
		if Vector2(x - float(p["x"]), z - float(p["z"])).length() < PYLON_GAP:
			return true
	return false


static func _crowded(list: Array[Dictionary], x: float, z: float) -> bool:
	for d in list:
		if Vector2(x - float(d["x"]), z - float(d["z"])).length() < DEN_GAP:
			return true
	return false


static func _draw(rng: Rng, threat: int) -> Array:
	var total := 0.0
	for g in GROUPS:
		if int(g["threat"]) <= threat:
			total += float(g["weight"])
	var pick := rng.next() * total
	for g in GROUPS:
		if int(g["threat"]) > threat:
			continue
		pick -= float(g["weight"])
		if pick < 0.0:
			return g["kinds"]
	return GROUPS[0]["kinds"]


# ---------------------------------------------------------------- Simulation

static func tick(sim: Simulation, _dt: float) -> void:
	if GameState.ended or sim.world == null:
		return
	var st := sim.state()
	if st == null or not st.groves:
		return
	var R := GameState.roamers
	if R.get("state") != st or R.get("seed") != st.seed:
		R.clear()
		R["state"] = st
		R["seed"] = st.seed
		R["dens"] = dens(st, st.seed)
		# Rencontres de salle (sim/rooms.gd) : une tanière par salle de combat du plan, à la suite des errants.
		(R["dens"] as Array[Dictionary]).append_array(RoomEncounters.dens(st))
		# Groupes des couloirs (3 au plus) : tanières ordinaires, levées à la vue.
		(R["dens"] as Array[Dictionary]).append_array(RoomEncounters.corridor_dens(st))
	var now := GameState.sim_time
	var list: Array[Dictionary] = R["dens"]
	# Rien ne déplace ni ne tue un allié dans cette boucle : un seul instantané des alliés visibles pour toutes les tanières.
	var watch := Awaken.watch()
	for i in list.size():
		var d := list[i]
		# Salle : levée à l'entrée d'un allié, nettoyée puis repeuplée (RoomEncounters) ; debout, elle se bat et
		# fait sa ronde comme un groupe errant.
		if d.has("room") and RoomEncounters.tick(sim, d, i, watch):
			continue
		if not d.has("members"):
			# Formé à SPAWN_R (hors de l'écran) plutôt qu'à la vue : plus d'apparition sous les yeux du joueur.
			if st.is_gallery_open(d["x"], d["z"]) and watch.seen(Vector2(d["x"], d["z"]), RoomEncounters.SPAWN_R):
				_spawn(sim, d, i)
			continue
		var members: Array = d["members"]
		for k in range(members.size() - 1, -1, -1):
			if (members[k] as Enemy).hp <= 0.0:
				members.remove_at(k)
		if members.is_empty():
			continue
		# Proie du groupe : lâchée dès qu'elle tombe, se cache ou sort de la laisse.
		var prey: Unit = d.get("prey")
		if prey != null and (not prey.alive() or prey.hidden or prey.pos().distance_to(Vector2(d["x"], d["z"])) > LEASH):
			d["prey"] = null
		# Ronde : une étape vers un point de la galerie, puis une halte.
		if d["goal"] == null:
			if now >= float(d["until"]):
				d["goal"] = _waypoint(st, d)
				d["deadline"] = now + LEG_TIME
		elif (members[0] as Enemy).pos().distance_to(d["goal"]) < 1.5 or now > float(d["deadline"]):
			d["goal"] = null
			d["until"] = now + 2.0 + (d["rng"] as Rng).next() * 4.0


static func _spawn(sim: Simulation, d: Dictionary, index: int) -> void:
	var st := sim.state()
	var home := st.push_out_of_rock(Vector2(d["x"], d["z"]))
	var tier := Catalog.menace_tier(GameState.menace) + Biomes.threat_tiers(int(d["threat"]))
	var stats := Catalog.menace_stats(tier, true)
	var kinds: Array = d["kinds"]
	var rng := Rng.new(st.seed + index * 53 + 11)
	var members: Array = []
	# Groupe de salle : réparti dans toute la salle plutôt qu'en tas au centre (2026-11-22).
	var places: Array[Vector2] = []
	if d.has("room"):
		places.assign(RoomEncounters.spread(st, d, kinds.size(), rng))
	for k in kinds.size():
		var off := Vector2.ZERO if kinds.size() == 1 else Vector2.from_angle(float(k) / kinds.size() * TAU) * 2.4
		var at := home + off
		if k < places.size() and places[k] != Vector2.INF:
			at = places[k]
		elif not st.walkable(at.x, at.y):
			at = home
		var e := Enemy.make(kinds[k], at.x, at.y, 0.6 + 0.2 * k, stats)
		e.beast = true
		e.roam = d
		e.home = home
		e.memo["roam_off"] = off
		if k < places.size() and places[k] != Vector2.INF:
			e.memo["roam_post"] = at
		members.append(e)
		GameState.enemies.append(e)
	d["members"] = members
	d["rng"] = rng
	d["goal"] = null
	d["until"] = GameState.sim_time + 1.0 + rng.next() * 3.0
	d["prey"] = null


## Prochaine étape de la ronde : un point praticable de la galerie découverte, autour de la tanière.
static func _waypoint(st: TerrainState, d: Dictionary) -> Vector2:
	var rng: Rng = d["rng"]
	var home := Vector2(d["x"], d["z"])
	for t in 30:
		var q := home + Vector2.from_angle(rng.next() * TAU) * (8.0 + rng.next() * (ROAM - 8.0))
		if st.is_gallery_open(q.x, q.y) and st.walkable(q.x, q.y) and not _near_pylon(st, q.x, q.y):
			# Groupe de salle : sa ronde reste dans la salle.
			if d.has("room") and st.temple_room(q.x, q.y).get("id", -1) != d["room"]:
				continue
			return q
	return st.push_out_of_rock(home)


## Cible d'un errant : l'unité visible la plus proche sur son territoire, sinon son agresseur ou la proie du groupe.
## Jamais une unité réfugiée dans une salle sûre (TerrainState.safe_at : l'antichambre du boss).
static func target(e: Enemy, alive: Array[Unit], st: TerrainState = null) -> Unit:
	var d: Dictionary = e.roam
	# Groupe de salle dormant : il ne vise personne, sauf s'il est attaqué (il se lève alors).
	if d.has("room") and not d.get("roused", false):
		if not e.memo.has("hurt_by"):
			return null
		d["roused"] = true
	var home := Vector2(d["x"], d["z"])
	var safe := func(u: Unit) -> bool: return st != null and st.safe_at(u.x, u.z)
	var prey: Unit = d.get("prey")
	if prey != null and safe.call(prey):
		d["prey"] = null
	var sight := maxf(AGGRO, e.reach + 2.0)
	if e.kind == "beast":
		sight = Catalog.BEAST_SIGHT
	var best: Unit = null
	var bd := sight
	var ex := e.x
	var ez := e.z
	for u in alive:
		# Écart sur un seul axe déjà hors de vue : la distance (≥ |dx| et ≥ |dz|) l'est aussi.
		var dx := u.x - ex
		if dx >= bd or dx <= -bd:
			continue
		var dz := u.z - ez
		if dz >= bd or dz <= -bd or u.hidden:
			continue
		var nd := Combat.hyp(dx, dz)
		if nd < bd and u.pos().distance_to(home) < LEASH and not safe.call(u):
			best = u
			bd = nd
	# Frappé de loin : il riposte tant que le tireur reste près de son territoire.
	if best == null and e.memo.has("hurt_by"):
		var src: Unit = e.memo["hurt_by"]
		if src != null and src.alive() and not src.hidden and not src.is_enemy() and src.pos().distance_to(home) < LEASH and not safe.call(src):
			best = src
		else:
			e.memo.erase("hurt_by")
	if best != null:
		d["prey"] = best
		return best
	return d.get("prey")


## Ronde d'un errant sans cible : il suit l'étape de son groupe, à sa place dans le groupe.
static func wander(sim: Simulation, e: Enemy, speed: float, dt: float) -> void:
	var d: Dictionary = e.roam
	# Groupe de salle dormant : il attend sur place.
	if d["goal"] == null or (d.has("room") and not d.get("roused", false)):
		return
	var goal: Vector2 = d["goal"] + (e.memo.get("roam_off", Vector2.ZERO) as Vector2)
	# Groupe de salle : chacun garde son coin de la salle et n'en bouge que de 3 au plus.
	if e.memo.has("roam_post"):
		goal = (e.memo["roam_post"] as Vector2) + ((d["goal"] as Vector2) - Vector2(d["x"], d["z"])).limit_length(3.0)
	if not sim.state().walkable(goal.x, goal.y):
		goal = d["goal"]
	if e.pos().distance_to(goal) <= 0.4:
		return
	var x0 := e.x
	sim.combat._move_enemy(e, goal, speed * STROLL, dt)
	if absf(e.x - x0) > 0.001:
		e.face = -1 if e.x < x0 else 1
