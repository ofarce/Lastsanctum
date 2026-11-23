class_name Oublieux
extends RefCounted
## L'Oublieux de l'Église des Oublieux (idée de l'utilisateur, 2026-11-20). Chaque nuit, si un adepte de Medeina
## (ou l'Ingénieur) tient l'Église, un Oublieux en sort : il va au butin le plus proche dans les zones déjà
## explorées (corps à fouiller, objets au sol), charge CAPACITY objets par trajet, les rapporte au coffre de
## l'Église et repart, jusqu'à l'aube. Il ne se bat pas et n'obéit à aucun ordre. Tué, son chargement tombe sur
## place et il ne revient que la nuit suivante. Rendu : AdeptView (rôle « oublieux » du manifeste).
## Tâche de l'unité : {type: "glean", building, step: seek | go | take | return, target, until, since, best, skip}.

const ItemStorage := preload("res://sim/item_storage.gd")
const Recipes := preload("res://data/recipes.gd")

const ROLE := "oublieux"
const CAPACITY := 12
## Temps penché sur un butin (une boucle de l'animation « work » : se pencher, saisir, ranger).
const TAKE_TIME := 1.3
const REACH := 1.5
## Sans progrès vers sa cible pendant ce délai, il l'abandonne pour la nuit (passage muré, rivière…).
const STUCK := 6.0


## Point où il sort, attend et décharge : à gauche des postes du personnel, face au coffre.
static func door(b: Building) -> Vector2:
	return Vector2(b.x - 3.2, b.z + b.half() + 2.6)


static func gleaner(b: Building) -> Unit:
	if b == null or b.gleaner_id < 0:
		return null
	for u: Unit in GameState.units:
		if u.id == b.gleaner_id and u.role == ROLE and not u.dead:
			return u
	return null


## Nuit en cours (numéro du jour dont elle est la fin), ou celle qui vient de finir pendant l'aube.
static func night_index() -> int:
	var t := GameState.sim_time
	return DayNight.day(t) if DayNight.phase(t) != "aube" else DayNight.day(t) - 1


static func load_of(u: Unit) -> int:
	var n := 0
	for stack: Dictionary in u.inventory:
		if not stack.is_empty():
			n += int(stack["quantity"])
	return n


## L'Église est « au repos » (boucle de jour) tant que son Oublieux n'est pas dehors.
static func resting(b: Building) -> bool:
	return gleaner(b) == null


static func tick(sim: Simulation, dt: float) -> void:
	# Un Oublieux tombé quitte la liste des unités : il n'est pas rappelé par le Puits des Âmes.
	for i in range(GameState.units.size() - 1, -1, -1):
		var d := GameState.units[i]
		if d.role == ROLE and d.dead:
			GameState.units.remove_at(i)
	var night := DayNight.phase(GameState.sim_time) == "nuit"
	for b: Building in GameState.buildings:
		if b.type != "eglise" or not b.complete:
			continue
		var active := night and not Production.idle(b)
		var u := gleaner(b)
		if u == null:
			if not active or b.gleaner_lost_night == night_index():
				continue
			u = _spawn(sim, b)
		_update(sim, b, u, active, dt)


static func _spawn(sim: Simulation, b: Building) -> Unit:
	var p := door(b)
	var u := sim.spawn(Catalog.ADEPT[ROLE]["name"], p.x, p.y, ROLE)
	u.hp = Catalog.ADEPT[ROLE]["hp"]
	u.max_hp = u.hp
	u.inventory_capacity = CAPACITY
	u.job = {"type": "glean", "building": b, "step": "seek", "skip": []}
	b.gleaner_id = u.id
	b.gleaned = 0
	sim.say("La nuit tombe : l’Oublieux sort de l’Église.", 3.0)
	return u


static func _update(sim: Simulation, b: Building, u: Unit, active: bool, _dt: float) -> void:
	# Aucun ordre ne le détourne : sa tâche est reposée à chaque pas.
	if not (u.job is Dictionary) or u.job.get("type") != "glean" or u.job.get("building") != b:
		u.job = {"type": "glean", "building": b, "step": "seek", "skip": []}
	var j: Dictionary = u.job
	u.force_move = false
	u.stance = "attack"
	var now := GameState.sim_time
	var carried := load_of(u)
	match String(j["step"]):
		"seek":
			if not active or carried >= CAPACITY:
				j["step"] = "return"
				return
			var t := _nearest(sim, u, j["skip"])
			if t.is_empty():
				if carried > 0:
					j["step"] = "return"
				else:
					_go(u, door(b))
				return
			j["target"] = t
			j["step"] = "go"
			j["since"] = now
			j["best"] = INF
		"go":
			var t: Dictionary = j["target"]
			if not active or not _valid(t):
				j["step"] = "seek" if active else "return"
				return
			var p := _pos(t)
			var d := u.pos().distance_to(p)
			if d < REACH:
				j["step"] = "take"
				j["until"] = now + TAKE_TIME
				_go(u, u.pos())
				return
			if d < float(j["best"]) - 0.5:
				j["best"] = d
				j["since"] = now
			elif now - float(j["since"]) > STUCK:
				(j["skip"] as Array).append(_key(t))
				j["step"] = "seek"
				return
			_go(u, p)
		"take":
			u.working = true
			_go(u, u.pos())
			var t: Dictionary = j["target"]
			if _valid(t):
				u.face = -1 if _pos(t).x < u.x else 1
			if now < float(j["until"]):
				return
			if _valid(t):
				_take(u, t)
			j["step"] = "seek"
		"return":
			var p := door(b)
			if u.pos().distance_to(p) >= REACH:
				_go(u, p)
				return
			_go(u, u.pos())
			var left := _deposit(b, u)
			if not active:
				_leave(sim, b, u, left)
			elif left == 0:
				j["step"] = "seek"
			elif not j.get("full_said", false):
				j["full_said"] = true
				sim.say("Le coffre de l’Église des Oublieux est plein.", 3.0)


static func _go(u: Unit, p: Vector2) -> void:
	u.tx = p.x
	u.tz = p.y


static func _key(t: Dictionary) -> Vector2:
	return _pos(t).snappedf(0.01)


static func _pos(t: Dictionary) -> Vector2:
	return (t["corpse"] as Enemy).pos() if t.has("corpse") else t["drop"]["position"]


static func _valid(t: Dictionary) -> bool:
	if t.has("corpse"):
		var e: Enemy = t["corpse"]
		return not e.loot.is_empty() and GameState.enemy_corpses.has(e)
	return GameState.ground_items.has(t["drop"])


## Butin le plus proche dans une zone explorée : corps à fouiller ou objet au sol.
static func _nearest(sim: Simulation, u: Unit, skip: Array) -> Dictionary:
	var fog: Variant = sim.world.fog if sim.world else null
	var from := u.pos()
	var best := {}
	var best_d := INF
	for e: Enemy in GameState.enemy_corpses:
		if e.loot.is_empty():
			continue
		var d := from.distance_squared_to(e.pos())
		if d < best_d and not skip.has(e.pos().snappedf(0.01)) and (fog == null or fog.explored_at(e.pos())):
			best_d = d
			best = {"corpse": e}
	for drop: Dictionary in GameState.ground_items:
		var p: Vector2 = drop["position"]
		var d := from.distance_squared_to(p)
		if d < best_d and not skip.has(p.snappedf(0.01)) and (fog == null or fog.explored_at(p)):
			best_d = d
			best = {"drop": drop}
	return best


static func _take(u: Unit, t: Dictionary) -> void:
	var room := CAPACITY - load_of(u)
	if t.has("corpse"):
		for got: Dictionary in Loot.take(t["corpse"], room):
			ItemStorage.store(u.inventory, CAPACITY, got["item"], got["owner"])
			Recipes.learn(got["item"])
	elif room > 0 and ItemStorage.store(u.inventory, CAPACITY, t["drop"]["item"], String(t["drop"].get("owner", ""))):
		GameState.ground_items.erase(t["drop"])
		Recipes.learn(String(t["drop"]["item"]))
	Sfx.at("coffre", u.x, u.z)


## Vide la palanche dans le coffre de l'Église ; renvoie ce qui n'y tient pas (reste sur lui).
static func _deposit(b: Building, u: Unit) -> int:
	var left := 0
	var moved := 0
	for i in u.inventory.size():
		var stack := u.inventory[i]
		if stack.is_empty():
			continue
		var rest := int(stack["quantity"])
		while rest > 0 and ItemStorage.store(b.output_box, Production.BOX_CAPACITY, stack["item"], String(stack.get("owner", ""))):
			rest -= 1
		moved += int(stack["quantity"]) - rest
		left += rest
		if rest == 0:
			u.inventory[i] = {}
		else:
			stack["quantity"] = rest
	if moved > 0:
		b.gleaned += moved
		b.chest_out_at = GameState.sim_time
	return left


## À l'aube il rentre. Ce qui ne tient pas dans le coffre est posé devant la porte.
static func _leave(sim: Simulation, b: Building, u: Unit, left: int) -> void:
	if left > 0:
		_spill(u, door(b))
	GameState.units.erase(u)
	GameState.selected.erase(u)
	b.gleaner_id = -1
	if b.gleaned > 0:
		sim.say("L’Oublieux rentre à l’aube : %d objet%s dans le coffre de l’Église." % [b.gleaned, "s" if b.gleaned > 1 else ""], 4.0)


static func _spill(u: Unit, at: Vector2) -> void:
	var k := 0
	for stack: Dictionary in u.inventory:
		if stack.is_empty():
			continue
		for i in int(stack["quantity"]):
			var a := k * 2.4
			GameState.ground_items.append(ItemStorage.drop_of(stack["item"], at + Vector2(cos(a), sin(a)) * (0.5 + 0.12 * k), String(stack.get("owner", ""))))
			k += 1
	u.inventory.clear()


## Appelé par Simulation.on_unit_death : son chargement tombe sur place, il reviendra la nuit suivante.
static func fell(sim: Simulation, u: Unit) -> void:
	_spill(u, u.pos())
	GameState.selected.erase(u)
	for b: Building in GameState.buildings:
		if b.gleaner_id == u.id:
			b.gleaner_id = -1
			b.gleaner_lost_night = night_index()
	u.job = null
	sim.say("L’Oublieux est tombé · il reviendra la nuit prochaine.", 3.5)


## Ligne d'état du panneau de l'Église (HUD).
static func status(b: Building) -> String:
	var u := gleaner(b)
	if u != null:
		return "L’Oublieux est dehors · %d / %d sur lui · %d rapporté%s cette nuit" % [load_of(u), CAPACITY, b.gleaned, "s" if b.gleaned > 1 else ""]
	if b.gleaner_lost_night == night_index() and DayNight.phase(GameState.sim_time) in ["nuit", "aube"]:
		return "L’Oublieux est tombé · il reviendra la nuit prochaine"
	return "L’Oublieux sort à la nuit tombée · butin de la nuit dans le coffre rouge"
