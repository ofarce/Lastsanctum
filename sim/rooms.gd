class_name RoomEncounters
extends RefCounted
## Rencontres de salle (planches/biomes-salles-structure.html, validée le 2026-11-22) : chaque salle de combat du
## plan, sauf celles des pylônes (leur meute en tient lieu), garde un groupe d'ennemis qui se lève quand un allié
## entre dans la salle. Le groupe est une tanière d'errants (sim/roamers.gd) attachée à sa salle : mêmes attaques,
## même laisse, ronde bornée à la salle.
##
## - Composition tirée selon le niveau de la salle (léger, moyen, dur), parmi les ennemis codés.
## - Menace : celle du biome, plus un palier dans le quartier C (RoomLayout, threat_bonus).
## - Nettoyée quand le groupe est mort ; elle se repeuple au bout de REPOP_NIGHTS nuits (REPOP_NIGHTS_C dans C),
##   avec un nouveau tirage, sauf si elle est sur un chemin protégé : le plus court chemin (en salles) d'un portail
##   (portail fixe du plan, ou salle d'un pylône canalisé) à une salle de ressources.
##
## Temple et Veines sont en salles (TerrainState.room_layouts : identifiants globaux, champ « biome »).
## Champs ajoutés à la tanière : {room, tier, quarter, repop, cleared_day}.

## Compositions par niveau. Pas encore de squelettes : leur chaîne et leurs règles sont écrites pour la nuit.
const COMPOSITIONS := {
	"L": [["beast", "beast"], ["beast", "beast", "beast"], ["creep", "creep", "creep"], ["creep", "creep", "spitter"]],
	"M": [["brute", "creep", "creep", "spitter"], ["beast", "beast", "beast", "beast", "beast"], ["scout", "soldier", "shield", "archer"]],
	"D": [["strazhar", "creep", "creep"], ["brute", "brute", "spitter", "spitter"], ["shield", "shield", "soldier", "archer", "archer"]],
}
## Salles oubliées (biome 2, 2026-11-24 ; renommées le 2026-11-25) : leur faune, chauves-souris patinées et tiques de
## filon (ici hostiles, elles quittent leur filon), dans chaque groupe (demande du 2026-11-25), avec les patrouilles de
## Byrsa qui y montent. Les tiques neutres restent sur leurs filons et les anguilles dans leurs bassins (sim/wildlife.gd).
const COMPOSITIONS_VEINES := {
	"L": [["bat", "bat", "bat"], ["tick", "tick", "bat"], ["bat", "bat", "archer"], ["tick", "creep", "spitter"]],
	"M": [["bat", "bat", "bat", "bat", "bat"], ["tick", "tick", "tick", "bat", "bat"], ["scout", "soldier", "shield", "bat", "bat"],
		["brute", "tick", "tick", "spitter"]],
	"D": [["strazhar", "tick", "tick", "bat", "bat"], ["soldier", "shield", "shield", "tick", "archer"], ["brute", "brute", "bat", "bat", "bat"]],
}
const CORRIDOR_GROUPS_VEINES: Array = [["bat", "bat", "bat"], ["tick", "bat"], ["tick", "tick"], ["bat", "bat", "archer"], ["scout", "bat"]]
const REPOP_NIGHTS := 3
const REPOP_NIGHTS_C := 2


## Une tanière par salle de combat sans pylône du Temple.
static func dens(st: TerrainState) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for lay: Dictionary in st.room_layouts():
		var bonus: Dictionary = lay["threat_bonus"]
		for room: Dictionary in lay["rooms"]:
			var tier := encounter_tier(room)
			if tier == "":
				continue
			var c := _center(room)
			var biome := int(room.get("biome", 0))
			out.append({"x": c.x, "z": c.y, "room": room["id"], "tier": tier, "quarter": room["quarter"], "biome": biome,
				"threat": int(Biomes.LIST[biome]["threat"]) + int(bonus.get(room["quarter"], 0)),
				"kinds": draw(st.seed, room["id"], 0, tier, biome), "repop": 0})
	return out


## Groupes des couloirs (demande du 2026-11-22) : 3 ennemis au plus, tirés du niveau léger, non doublés.
const CORRIDOR_GROUPS: Array = [["beast", "beast"], ["beast", "beast", "beast"], ["creep", "creep", "spitter"],
	["creep", "creep", "creep"], ["brute", "creep"], ["scout", "archer", "creep"]]
## Un groupe par couloir d'au moins CORRIDOR_MIN cases ; deux au-delà de CORRIDOR_TWO.
const CORRIDOR_MIN := 10
const CORRIDOR_TWO := 30


## Groupes errants des couloirs du plan : tanières ordinaires (Roamers, levées à la vue, ne reviennent pas), posées sur
## la ligne du couloir, hors des salles et des portes scellées. Pas dans les couloirs qui touchent l'antichambre (salle
## sûre) ni l'arène du boss.
static func corridor_dens(st: TerrainState) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var r := Rng.new(st.seed ^ 0xc0771d)
	var links: Array = []
	for lay: Dictionary in st.room_layouts():
		links.append_array(lay["links"])
	for l: Dictionary in links:
		if l["kind"] != "corridor":
			continue
		var a: Dictionary = st.room_by_id(l["a"])
		var b: Dictionary = st.room_by_id(l["b"])
		var biome := int(a.get("biome", 0))
		var bonus: Dictionary = (st.veines_layout if biome == 1 else st.temple_layout)["threat_bonus"]
		var groups: Array = CORRIDOR_GROUPS_VEINES if biome == 1 else CORRIDOR_GROUPS
		if a["role"] == "antechamber" or b["role"] == "antechamber" or a["kind"] == "boss" or b["kind"] == "boss":
			continue
		var path: Array = l["path"]
		var length := 0.0
		for k in path.size() - 1:
			length += (path[k] as Vector2i).distance_to(path[k + 1])
		if length < CORRIDOR_MIN:
			continue
		# Tout premiers couloirs (sortie de la grotte, hub vers le seuil ouvert) : un seul monstre, léger.
		var first: bool = l["door"] == "" and (a["role"] in ["entrance", "hub"] or b["role"] in ["entrance", "hub"])
		var n := 2 if length >= CORRIDOR_TWO and not first else 1
		for g in n:
			# Point du couloir à (g + 1) / (n + 1) de sa longueur, hors salle.
			var want := length * (g + 1) / (n + 1)
			var at := Vector2.ZERO
			for k in path.size() - 1:
				var p: Vector2 = Vector2(path[k] as Vector2i)
				var q: Vector2 = Vector2(path[k + 1] as Vector2i)
				var d := p.distance_to(q)
				if want <= d:
					at = p.lerp(q, want / maxf(d, 0.01))
					break
				want -= d
			var w := at * 4.0 + Vector2(2.0, 2.0)
			if not st.temple_room(w.x, w.y).is_empty() or not st.is_gallery(w.x, w.y):
				continue
			var quarter: String = b["quarter"] if a["quarter"] == "R" else a["quarter"]
			var kinds: Array = (groups[floori(r.next() * groups.size())] as Array).duplicate()
			if first:
				kinds = [kinds[0]]
			out.append({"x": w.x, "z": w.y, "threat": int(Biomes.LIST[biome]["threat"]) + int(bonus.get(quarter, 0)),
				"kinds": kinds, "corridor": true})
	return out


## Niveau de la rencontre d'une salle, ou "" sans rencontre (demande du 2026-11-22 : plus de salles à monstres).
## Combats sans pylône : leur niveau ; salles de ressources : gardées (léger dans A, moyen ailleurs) ; salles
## secrètes : « à risque », moyen. Calmes, transits, arènes et salles de pylône restent sans rencontre.
static func encounter_tier(room: Dictionary) -> String:
	if room["pylon"] or room.get("fixed", false):
		return ""
	match room["kind"]:
		"combat":
			return room["tier"]
		"resource":
			return "L" if room["quarter"] == "A" else "M"
		"secret":
			return "M"
	return ""


## Composition de la salle `room` à son `repop`-ième repeuplement (déterministe). Doublée (demande du
## 2026-11-22) : chaque composition de COMPOSITIONS est levée deux fois.
static func draw(map_seed: int, room: int, repop: int, tier: String, biome := 0) -> Array:
	var list: Array = (COMPOSITIONS_VEINES if biome == 1 else COMPOSITIONS)[tier]
	var r := Rng.new(map_seed ^ (room * 7349 + repop * 104729 + 0x5a1e))
	var one: Array = list[floori(r.next() * list.size())]
	return one + one


static func _center(room: Dictionary) -> Vector2:
	var rr: Rect2i = room["rect"]
	return Vector2(rr.position.x * 4.0 + rr.size.x * 2.0, rr.position.y * 4.0 + rr.size.y * 2.0)


## Marge (unités monde) autour de la salle : le groupe se lève avant qu'un allié n'y entre (2026-11-22), pour être
## déjà en place quand il passe la porte.
const WAKE_MARGIN := 28.0


## Rectangle monde de la salle `id` (Rect2 vide si inconnue).
static func room_rect(st: TerrainState, id: int) -> Rect2:
	var room := st.room_by_id(id)
	if room.is_empty():
		return Rect2()
	var rr: Rect2i = room["rect"]
	return Rect2(Vector2(rr.position) * 4.0, Vector2(rr.size) * 4.0)


## Un allié vivant et visible approche de la salle de la tanière (dans la salle ou à WAKE_MARGIN de ses bords).
static func entered(st: TerrainState, d: Dictionary) -> bool:
	var rect := room_rect(st, d["room"]).grow(WAKE_MARGIN)
	for u: Unit in GameState.units:
		if u.alive() and not u.hidden:
			if rect.has_area() and rect.has_point(Vector2(u.x, u.z)):
				return true
			var room := st.temple_room(u.x, u.z)
			if not room.is_empty() and room["id"] == d["room"]:
				return true
	return false


## Places du groupe de salle : points praticables tirés dans la salle, écartés d'au moins 4 les uns des autres.
static func spread(st: TerrainState, d: Dictionary, count: int, rng: Rng) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var rect := room_rect(st, d["room"]).grow(-3.0)
	if not rect.has_area():
		return out
	for k in count:
		var best := Vector2.INF
		for t in 40:
			var q := rect.position + Vector2(rng.next() * rect.size.x, rng.next() * rect.size.y)
			if not st.walkable(q.x, q.y) or st.temple_room(q.x, q.y).get("id", -1) != d["room"]:
				continue
			var ok := true
			for p in out:
				if p.distance_to(q) < (4.0 if t < 30 else 2.0):
					ok = false
					break
			if ok:
				best = q
				break
		out.append(best)
	return out


## Tanière de salle, appelée par Roamers.tick : lève le groupe, constate la salle nettoyée, la repeuple.
## Vrai si le groupe n'est pas debout (rien d'autre à faire pour lui ce tick).
## Distance (unités) d'un allié à laquelle le groupe d'une salle se forme, dormant (hors de l'écran au zoom courant).
const SPAWN_R := 90.0


static func tick(sim: Simulation, d: Dictionary, index: int, watch: Awaken.Watch = null) -> bool:
	var st := sim.state()
	# Plus d'apparition sous les yeux du joueur (Temple sans brouillard, demande du 2026-11-23) : le groupe se forme
	# dès qu'un allié passe à SPAWN_R de la salle, hors de l'écran, et attend immobile (« dormant ») ; il ne vise et ne
	# bouge qu'à l'entrée d'un allié dans la salle, ou s'il est attaqué (Roamers.target).
	if not d.has("members"):
		if watch.seen(Vector2(d["x"], d["z"]), SPAWN_R) if watch != null else Awaken.seen(Vector2(d["x"], d["z"]), SPAWN_R):
			Roamers._spawn(sim, d, index)
			d["roused"] = entered(st, d)
			return false
		return true
	if not d.get("roused", false) and entered(st, d):
		d["roused"] = true
	var members: Array = d["members"]
	for k in range(members.size() - 1, -1, -1):
		if (members[k] as Enemy).hp <= 0.0:
			members.remove_at(k)
	if not members.is_empty():
		return false
	after_clear(st, d, DayNight.day(GameState.sim_time))
	return true


## Groupe de la salle tombé, au jour `day` : note le jour du nettoyage, puis repeuple la salle quand assez de nuits
## sont passées (hors chemin protégé). Vrai si la salle vient d'être repeuplée (elle redevient dormante).
static func after_clear(st: TerrainState, d: Dictionary, day: int) -> bool:
	if not d.has("cleared_day"):
		d["cleared_day"] = day
		return false
	var nights := REPOP_NIGHTS_C if d["quarter"] == "C" else REPOP_NIGHTS
	if day >= int(d["cleared_day"]) + nights and not protected_rooms(st).has(d["room"]):
		_reset(st, d)
		return true
	return false


## La salle redevient dormante, avec un nouveau tirage.
static func _reset(st: TerrainState, d: Dictionary) -> void:
	for key: String in ["members", "cleared_day", "prey", "goal", "rng", "until", "deadline", "roused"]:
		d.erase(key)
	d["repop"] = int(d["repop"]) + 1
	d["kinds"] = draw(st.seed, d["room"], d["repop"], d["tier"], int(d.get("biome", 0)))


## Ouvre la porte de quartier `key` (« mb1 », « mb2 ») : ses cases de roche scellée sont creusées (sol repeint,
## chemins invalidés), puis la porte est marquée ouverte. Sans monde (tests), les cases sont juste creusées.
static func open_door(sim: Simulation, key: String) -> void:
	var st := sim.state()
	if st == null or not st.doors_closed.get(key, false):
		return
	for c: Vector2i in st.door_cells:
		if st.door_cells[c] != key:
			continue
		st.room_walls.erase(c)
		if sim.world != null and sim.world.terrain_ops != null:
			sim.world.terrain_ops.dig_cell(c.x, c.y)
		else:
			st.dug[c] = true
	st.set_door_closed(key, false)


## Salles des chemins protégés : pour chaque salle de ressources, le plus court chemin (en salles, couloirs du plan)
## jusqu'au portail le plus proche. Portails : ceux du plan, et les salles des pylônes canalisés.
static func protected_rooms(st: TerrainState) -> Dictionary:
	var out := {}
	var rooms: Array = []
	var links: Array = []
	for lay: Dictionary in st.room_layouts():
		rooms.append_array(lay["rooms"])
		links.append_array(lay["links"])
	var portal := {}
	for room: Dictionary in rooms:
		if room["portal"]:
			portal[room["id"]] = true
	for p: Dictionary in st.portals:
		if p.get("channeled", false):
			var room := st.temple_room(p["x"], p["z"])
			if not room.is_empty():
				portal[room["id"]] = true
	var adj := {}
	for l: Dictionary in links:
		if l["kind"] != "corridor":
			continue
		(adj.get_or_add(l["a"], []) as Array).append(l["b"])
		(adj.get_or_add(l["b"], []) as Array).append(l["a"])
	for room: Dictionary in rooms:
		if room["kind"] != "resource":
			continue
		var prev := {room["id"]: -1}
		var queue: Array = [room["id"]]
		var hit := -1
		while not queue.is_empty():
			var k: int = queue.pop_front()
			if portal.has(k):
				hit = k
				break
			for n: int in adj.get(k, []):
				if not prev.has(n):
					prev[n] = k
					queue.append(n)
		var k := hit
		while k >= 0:
			out[k] = true
			k = prev[k]
	return out


## Salle de repos de la route du boss (avant l'antichambre, demande du 2026-11-23) : soins, hors combat. Toute
## unité alliée vivante dans la salle récupère REST_HEAL PV par seconde tant qu'aucun ennemi n'y est debout.
const REST_HEAL := 6.0


static func rest_tick(sim: Simulation, dt: float) -> void:
	var st := sim.state()
	if st == null:
		return
	for lay: Dictionary in st.room_layouts():
		for room: Dictionary in lay["rooms"]:
			if room["role"] == "rest":
				_rest_room(room, dt)


static func _rest_room(rest: Dictionary, dt: float) -> void:
	var rr: Rect2i = rest["rect"]
	var inside := func(x: float, z: float) -> bool: return rr.has_point(Vector2i(floori(x / 4.0), floori(z / 4.0)))
	for e: Enemy in GameState.enemies:
		if e.alive() and not e.hidden and inside.call(e.x, e.z):
			return
	for u: Unit in GameState.units:
		if u.alive() and not u.hidden and u.hp < u.max_hp and inside.call(u.x, u.z):
			u.hp = minf(u.max_hp, u.hp + REST_HEAL * dt)
			if fmod(GameState.sim_time, 1.0) < dt:
				Combat.zone(u.x, u.z, 1.2, Color("#6fe07a"))
