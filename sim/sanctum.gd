class_name Sanctum
## Décor vivant et salles à thème du Temple (planche sanctum-decor-propositions.html, placement : SanctumLayout).
## Tout se déclenche par la présence d'une unité, sans ordre à donner :
## - braseros : éteints à la découverte, rallumés pour de bon dès qu'une unité passe à REACH unités ;
## - crypte : le reliquaire s'ouvre une fois (un objet posé au sol, un peu de Forge) ;
## - bibliothèque : la tablette du lutrin se lit une fois (Savoir) ;
## - salle d'armes : le support d'armure se vide une fois (une arme ou une armure au sol) ;
## - oratoire : bénédiction (dégâts × 1,5 pendant BLESS_TIME) pour les unités proches, puis repos BLESS_REST ;
## - citerne : les unités de la salle récupèrent CISTERN_HEAL PV par seconde.
## État dans GameState.sanctum : {state, seed, layout, lit {brasero → vrai}, done {salle → vrai}, until {salle → t}}.

const Gear := preload("res://data/gear_items.gd")
const PERIOD := 0.3
const REACH := 3.5
## 2026-11-20 : plus de fer dans le Temple, ses coffres ne donnent que du cuivre (le fer vient du biome suivant).
const CRYPT_LOOT := ["gear_circlet", "gear_lantern", "gear_cape", "copper_armor", "copper_shield", "gear_lens"]
const ARMORY_LOOT := ["copper_sword", "copper_armor", "copper_greatsword", "copper_shield"]
const CRYPT_FORGE := 80
const LIBRARY_SAVOIR := 150
const BLESS_TIME := 60.0
const BLESS_REST := 240.0
const BLESS_RADIUS := 9.0
const CISTERN_HEAL := 2.0


## État du sanctum pour ce terrain, retiré au besoin (nouvelle carte, partie relancée).
static func data(st: TerrainState) -> Dictionary:
	var S := GameState.sanctum
	if S.get("state") != st or S.get("seed") != st.seed:
		S.clear()
		S["state"] = st
		S["seed"] = st.seed
		S["layout"] = SanctumLayout.build(st)
		S["lit"] = {}
		S["done"] = {}
		S["until"] = {}
		S["next"] = 0.0
	return S


static func lit(st: TerrainState, brazier: int) -> bool:
	return data(st)["lit"].has(brazier)


static func done(st: TerrainState, room: int) -> bool:
	return data(st)["done"].has(room)


## L'oratoire est prêt à bénir.
static func ready(st: TerrainState, room: int) -> bool:
	return GameState.sim_time >= float(data(st)["until"].get(room, 0.0))


static func tick(sim: Simulation, _dt: float) -> void:
	if GameState.ended or sim.world == null:
		return
	var st := sim.state()
	if st == null:
		return
	var S := data(st)
	var now := GameState.sim_time
	if now < float(S["next"]):
		return
	S["next"] = now + PERIOD
	var units: Array[Unit] = []
	for u in GameState.units:
		if u.alive() and not u.hidden:
			units.append(u)
	if units.is_empty():
		return
	var layout: Dictionary = S["layout"]
	var braziers: Array = layout["braziers"]
	var lit_now: Dictionary = S["lit"]
	for i in braziers.size():
		if lit_now.has(i):
			continue
		var b: Dictionary = braziers[i]
		if _near(units, Vector2(b["x"], b["z"]), REACH):
			lit_now[i] = true
	var rooms: Array = layout["rooms"]
	for i in rooms.size():
		var room: Dictionary = rooms[i]
		var focus: Vector2 = room["focus"]
		if not st.is_gallery_open(room["x"], room["z"]):
			continue
		match room["kind"]:
			"crypt":
				if not S["done"].has(i) and _near(units, focus, REACH):
					S["done"][i] = true
					var item: String = CRYPT_LOOT[floori(Rng.hash3(i, 7, st.seed) * CRYPT_LOOT.size())]
					GameState.ground_items.append({"item": item, "position": focus + Vector2(0.0, 1.6)})
					GameState.res["forge"] += CRYPT_FORGE
					GameState.pray_popups.append({"x": focus.x, "z": focus.y, "amount": CRYPT_FORGE, "res": "forge", "at": now})
					Events.notice.emit("Reliquaire ouvert : %s." % Gear.name_of(item), 5.0)
			"library":
				if not S["done"].has(i) and _near(units, focus, REACH):
					S["done"][i] = true
					GameState.res["savoir"] += LIBRARY_SAVOIR
					GameState.pray_popups.append({"x": focus.x, "z": focus.y, "amount": LIBRARY_SAVOIR, "res": "savoir", "at": now})
					Events.notice.emit("Tablette déchiffrée : +%d Savoir." % LIBRARY_SAVOIR, 5.0)
			"armory":
				if not S["done"].has(i) and _near(units, focus, REACH):
					S["done"][i] = true
					var item: String = ARMORY_LOOT[floori(Rng.hash3(i, 9, st.seed) * ARMORY_LOOT.size())]
					GameState.ground_items.append({"item": item, "position": focus + Vector2(0.0, 1.6)})
					Events.notice.emit("Salle d’armes : %s." % Gear.name_of(item), 5.0)
			"oratory":
				if now >= float(S["until"].get(i, 0.0)) and _near(units, focus, REACH):
					S["until"][i] = now + BLESS_REST
					for u in units:
						if u.pos().distance_to(focus) <= BLESS_RADIUS:
							u.buff = maxf(u.buff, BLESS_TIME)
					Events.notice.emit("Bénédiction de l’oratoire : dégâts accrus pendant une minute.", 5.0)
			"cistern":
				var half: Vector2i = room["half"]
				for u in units:
					if u.hp < u.max_hp and absf(u.x - float(room["x"])) < half.x * 4.0 + 2.0 and absf(u.z - float(room["z"])) < half.y * 4.0 + 2.0:
						u.hp = minf(u.max_hp, u.hp + CISTERN_HEAL * PERIOD)
						u.healed_at = now


static func _near(units: Array[Unit], p: Vector2, reach: float) -> bool:
	for u in units:
		if u.pos().distance_squared_to(p) <= reach * reach:
			return true
	return false
