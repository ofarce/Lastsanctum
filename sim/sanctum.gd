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
## Salles oubliées (planches/salles-oubliees-decor-propositions.html, 2026-11-25) : citerne des Tyriens, un adepte
## tenu PUMP_TIME s à la pompe amorce l'eau (PV rendus aux unités de la salle pendant PUMP_HEAL_TIME s, une fois par
## jour) ; atelier de Byrsa, WORKSHOP_INGOTS lingots de cuivre dans la caisse, une fois.
const PUMP_TIME := 10.0
const PUMP_HEAL_TIME := 60.0
const WORKSHOP_INGOTS := 10
## Forges mortes (planches/forges-mortes-decor-propositions.html, R1, R3 et R4 choisis le 2026-11-25) :
## - salle de trempe : l'escouade récupère CISTERN_HEAL PV par seconde dans la salle ;
## - forge aux esprits enchaînés : une unité tenue CHAIN_TIME s près d'une enclume brise la chaîne (CHAIN_REACH),
##   l'esprit libéré rejoint la base en adepte d'Aether, sans coût ;
## - magasin de la fonderie : STORE_INGOTS lingots de fer, une fois.
const CHAIN_TIME := 3.0
const CHAIN_REACH := 2.6
const STORE_INGOTS := 10
const SPIRIT_SAY := "Des esprits d’Aether, enchaînés à des enclumes. Qui forge avec des prisonniers ?"
const SPIRITS_FREE_SAY := "Ils sont libres. Ils savent déjà où est la Fonderie."


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


## Le boss d'une arène du Temple est tombé : « mb1 » l'Archiprêtre, « mb2 » la Martyre (leur porte de sortie s'ouvre
## à leur chute), « oeil » l'Œil de la Matrice.
static func boss_down(st: TerrainState, key: String) -> bool:
	if key == "oeil":
		return GameState.oeil_state == "defeated"
	if key == "gorge":
		return String(Gorge.run().get("mode", "")) == "dead"
	return st.doors_closed.has(key) and not st.doors_closed[key]


## Un adepte tient la pompe de la citerne `room` en ce moment.
static func pump_held(st: TerrainState, room: int) -> bool:
	return (data(st).get("held", {}) as Dictionary).has(room)


## La chaîne `n` de la forge aux esprits `room` est brisée.
static func chain_free(st: TerrainState, room: int, n: int) -> bool:
	return ((data(st).get("chains", {}) as Dictionary).get(room, {}) as Dictionary).has(n)


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
			"vcistern":
				var held := false
				for u in units:
					if sim.is_adept(u) and u.pos().distance_to(focus) <= REACH:
						held = true
						break
				var H: Dictionary = S.get_or_add("held", {})
				var acc: Dictionary = S.get_or_add("pump", {})
				var days: Dictionary = S.get_or_add("day", {})
				if held:
					H[i] = true
					acc[i] = float(acc.get(i, 0.0)) + PERIOD
					var day := DayNight.day(now)
					if float(acc[i]) >= PUMP_TIME and int(days.get(i, -1)) != day:
						days[i] = day
						acc[i] = 0.0
						S["until"][i] = now + PUMP_HEAL_TIME
						Events.notice.emit("La citerne est amorcée : l’escouade récupère %d PV/s pendant une minute." % int(CISTERN_HEAL), 5.0)
						Sfx.at("soin", focus.x, focus.y)
				else:
					H.erase(i)
					acc[i] = 0.0
				if now < float(S["until"].get(i, 0.0)):
					var vh: Vector2i = room["half"]
					for u in units:
						if u.hp < u.max_hp and absf(u.x - float(room["x"])) < vh.x * 4.0 + 6.0 and absf(u.z - float(room["z"])) < vh.y * 4.0 + 6.0:
							u.hp = minf(u.max_hp, u.hp + CISTERN_HEAL * PERIOD)
							u.healed_at = now
			"vworkshop":
				if not S["done"].has(i) and _near(units, focus, REACH):
					S["done"][i] = true
					for k in WORKSHOP_INGOTS:
						var a := TAU * k / WORKSHOP_INGOTS
						GameState.ground_items.append({"item": "copper_ingot", "position": focus + Vector2(cos(a) * 1.4, 1.2 + sin(a) * 0.8)})
					Events.notice.emit("Caisse de Byrsa : %d lingots de cuivre." % WORKSHOP_INGOTS, 5.0)
			"ftrempe":
				var th: Vector2i = room["half"]
				for u in units:
					if u.hp < u.max_hp and absf(u.x - float(room["x"])) < th.x * 4.0 + 2.0 and absf(u.z - float(room["z"])) < th.y * 4.0 + 2.0:
						u.hp = minf(u.max_hp, u.hp + CISTERN_HEAL * PERIOD)
						u.healed_at = now
			"fstore":
				if not S["done"].has(i) and _near(units, focus, REACH):
					S["done"][i] = true
					for k in STORE_INGOTS:
						var a := TAU * k / STORE_INGOTS
						GameState.ground_items.append({"item": "iron_ingot", "position": focus + Vector2(cos(a) * 1.4, 1.2 + sin(a) * 0.8)})
					Events.notice.emit("Magasin de la fonderie : %d lingots de fer." % STORE_INGOTS, 5.0)
			"fspirits":
				_spirits(sim, st, S, layout, i, units)
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


## Forge aux esprits enchaînés : chaque enclume garde un esprit ; une unité tenue CHAIN_TIME s à côté brise sa chaîne.
static func _spirits(sim: Simulation, st: TerrainState, S: Dictionary, layout: Dictionary, i: int, units: Array[Unit]) -> void:
	var spots: Dictionary = S.get_or_add("chain_spots", {})
	if not spots.has(i):
		var list: Array[Vector2] = []
		for e: Dictionary in layout["props"]:
			if e.get("role", "") == "chain" and int(e["room"]) == i:
				list.append(Vector2(e["x"], e["z"]))
		spots[i] = list
	var freed: Dictionary = (S.get_or_add("chains", {}) as Dictionary).get_or_add(i, {})
	var held: Dictionary = (S.get_or_add("chain_hold", {}) as Dictionary).get_or_add(i, {})
	var room: Dictionary = layout["rooms"][i]
	if not S["done"].has(i) and _near(units, room["focus"], 9.0):
		S["done"][i] = true
		Events.notice.emit(SPIRIT_SAY, 6.0)
	var list: Array[Vector2] = spots[i]
	for n in list.size():
		if freed.has(n):
			continue
		if _near(units, list[n], CHAIN_REACH):
			held[n] = float(held.get(n, 0.0)) + PERIOD
			if float(held[n]) >= CHAIN_TIME:
				freed[n] = true
				var u := sim.spawn(Catalog.ADEPT["aether"]["name"], Capsule.EXIT.x + (n - 1.5) * 1.2, Capsule.EXIT.y + 1.5, "aether")
				Sfx.at("soin", list[n].x, list[n].y)
				if freed.size() >= list.size():
					Events.notice.emit(SPIRITS_FREE_SAY, 6.0)
				else:
					Events.notice.emit("Un esprit d’Aether est libre : il rejoint la base (%d/%d)." % [freed.size(), list.size()], 4.0)
				if u != null:
					u.healed_at = GameState.sim_time
		else:
			held[n] = 0.0
