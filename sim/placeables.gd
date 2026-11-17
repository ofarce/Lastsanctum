extends RefCounted
## Défenses de l'Atelier posées au sol par l'Ingénieur (spec du 2026-11-17) : un objet fabriqué occupe une
## case de la grille (4 × 4 unités) et est consommé du stock à la pose.
##  - Poste de tir (Créneau de rondins) : une unité de tir à moins de POST_RADIUS du poste voit sa portée doublée.
##  - Barricade (Muret hérissé) : la case devient infranchissable (TerrainState.walls), les ennemis la
##    contournent ; refusée si elle fermait le dernier passage vers l'Ancre.
##  - Chausse-trappe (Planches hérissées) : CALTROPS_DPS dégâts par seconde à chaque ennemi sur la case.
## Aucune ne bloque les lignes de vue (les tirs du jeu n'en testent pas).
## Rendu : entities/building/placed_view.gd, dessins exportés par tools/defenses/serve.py (da-<objet>).

const ItemStorage := preload("res://sim/item_storage.gd")

const ITEMS: Array[String] = ["firing_post", "barricade", "caltrops"]
const CELL := 4.0
const CALTROPS_DPS := 25.0
const CALTROPS_PERIOD := 0.5
const POST_RADIUS := 3.0
const POST_FACTOR := 2.0
## Portée minimale d'une unité « de tir » (en deçà : corps à corps, le poste ne change rien).
const RANGED_MIN := 4.0
## Point d'arrivée des assauts (spawn_enemy : z ≈ 62) pour le contrôle du passage.
const ASSAULT_FROM := Vector2(0.0, 62.0)


static func is_placeable(item: String) -> bool:
	return ITEMS.has(item)


static func cell_of(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / CELL), floori(p.y / CELL))


static func center(c: Vector2i) -> Vector2:
	return (Vector2(c) + Vector2(0.5, 0.5)) * CELL


static func at(c: Vector2i) -> Dictionary:
	for o: Dictionary in GameState.placed:
		if o["cell"] == c:
			return o
	return {}


static func _occupied(c: Vector2i) -> bool:
	var lo := Vector2(c) * CELL
	var hi := lo + Vector2(CELL, CELL)
	var inside := func(x: float, z: float) -> bool: return x > lo.x - 0.5 and x < hi.x + 0.5 and z > lo.y - 0.5 and z < hi.y + 0.5
	for u: Unit in GameState.units:
		if u.alive() and not u.hidden and inside.call(u.x, u.z):
			return true
	for e: Enemy in GameState.enemies:
		if e.hp > 0.0 and inside.call(e.x, e.z):
			return true
	return false


## Raison du refus de poser `item` en `p`, ou "" si la pose est possible.
static func refusal(sim: Simulation, item: String, p: Vector2) -> String:
	if not is_placeable(item):
		return "Cet objet ne se pose pas."
	if ItemStorage.count(item) <= 0:
		return "%s : aucun en stock." % preload("res://data/recipes.gd").name_of(item)
	var c := cell_of(p)
	var mid := center(c)
	if sim.world and not sim.world.fog.visible_at(mid):
		return "Explorez la case avant d’y poser un objet."
	for k in 4:
		var q := Vector2(c) * CELL + Vector2(0.6 + 2.8 * (k % 2), 0.6 + 2.8 * (k / 2))
		if not sim.state().walkable(q.x, q.y):
			return "Il faut une case de sol dégagé."
	if not at(c).is_empty():
		return "Un objet occupe déjà cette case."
	for b: Building in GameState.buildings:
		if absf(b.x - mid.x) < b.half() + CELL / 2.0 and absf(b.z - mid.y) < b.half() + CELL / 2.0:
			return "Un bâtiment occupe cette case."
	if item == "barricade" and _occupied(c):
		return "Une unité se tient sur cette case."
	return ""


## Pose `item` sur la case de `p` : consomme un objet du stock. Vrai si posé.
static func place(sim: Simulation, item: String, p: Vector2) -> bool:
	var why := refusal(sim, item, p)
	if why != "":
		sim.say(why, 2.0)
		return false
	var c := cell_of(p)
	if item == "barricade":
		var st := sim.state()
		st.walls[c] = true
		st.version += 1
		if sim.world and sim.world.pathfinder.find_path(ASSAULT_FROM, CaveShape.CORE + Vector2(0.0, 6.0)) == null:
			st.walls.erase(c)
			st.version += 1
			sim.say("La barricade fermerait le dernier passage vers l’Ancre.", 2.5)
			return false
	ItemStorage.take({item: 1})
	GameState.placed.append({"item": item, "cell": c, "x": center(c).x, "z": center(c).y, "tick": 0.0})
	return true


## Chausse-trappes : CALTROPS_DPS × CALTROPS_PERIOD dégâts à chaque ennemi sur la case, toutes les CALTROPS_PERIOD s.
static func tick(sim: Simulation, dt: float) -> void:
	for o: Dictionary in GameState.placed:
		if o["item"] != "caltrops":
			continue
		o["tick"] = float(o["tick"]) + dt
		if o["tick"] < CALTROPS_PERIOD - 1e-6:
			continue
		o["tick"] = float(o["tick"]) - CALTROPS_PERIOD
		for e: Enemy in GameState.enemies.duplicate():
			if e.hp > 0.0 and not e.hidden and cell_of(e.pos()) == o["cell"]:
				sim.combat.damage(e, CALTROPS_DPS * CALTROPS_PERIOD)


## Multiplicateur de portée d'une unité de tir postée près d'un poste de tir (1 sinon).
static func reach_factor(u: Unit, base_reach: float) -> float:
	if base_reach < RANGED_MIN or u.is_enemy():
		return 1.0
	for o: Dictionary in GameState.placed:
		if o["item"] == "firing_post" and Vector2(o["x"], o["z"]).distance_to(u.pos()) <= POST_RADIUS:
			return POST_FACTOR
	return 1.0


## Vrai si l'unité bénéficie du bonus de portée d'un poste de tir (icône au-dessus d'elle).
static func posted(u: Unit) -> bool:
	if GameState.placed.is_empty() or u.is_enemy() or not u.alive():
		return false
	return reach_factor(u, Catalog.base_reach(u)) > 1.0


## Poste de tir posé sur la case de `p`, ou {}.
static func firing_post_at(p: Vector2) -> Dictionary:
	var o := at(cell_of(p))
	return o if not o.is_empty() and o["item"] == "firing_post" else {}


## Les unités sélectionnées vont se poster entre les rondins du poste `o` et y tiennent position.
static func order_post(sim: Simulation, o: Dictionary) -> void:
	var units := sim.expand_squads(GameState.selected)
	var n := units.size()
	for i in n:
		var u: Unit = units[i]
		sim.cancel_work(u)
		var off := Vector2.ZERO if n == 1 else Vector2.from_angle(TAU * i / n) * minf(POST_RADIUS * 0.6, 0.6 + 0.25 * n)
		u.tx = float(o["x"]) + off.x
		u.tz = float(o["z"]) + off.y
		u.stance = "hold"
		u.force_move = true
	GameState.hud_mode = ""
	if n > 0:
		sim.say("Ordre : se poster au poste de tir.", 1.0)
