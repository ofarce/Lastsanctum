class_name Simulation
extends Node

const ItemStorage := preload("res://sim/item_storage.gd")
const Recipes := preload("res://data/recipes.gd")
const Placeables := preload("res://sim/placeables.gd")
const Blocks := preload("res://data/mineable_blocks.gd")
## Boucle de simulation (frame() et update(), Index.html, 73b410f) et ordres du joueur.
## Ordre des systèmes identique au prototype (R14) : portail, bâtiments et Ancre, tâches des adeptes,
## portails maléfiques, unités, tourelles, ennemis, fin de partie. Les étapes 7 et 8 complèteront
## bâtiments, combat, tourelles et ennemis ; leurs emplacements sont marqués ci-dessous.

signal turrets_activated
signal engineer_greeted(unit: Unit)
signal engineer_spoke(unit: Unit, text: String)
## Surcharge de l'Ancre terminée : l'Ingénieur est à genoux, le dialogue peut s'ouvrir.
signal overload_finished(unit: Unit)

## Pas de simulation maximal (frame() : dt ≤ 0,045 s).
const MAX_DT := 0.045
const ORB_TIME := 8.0
const ORB_SPOT := Vector2(-5.0, -150.0)  # (core.x − 5, core.z + 4)
## Délai entre l'éveil de l'Ancre et l'armement des balistes : temps de trajet de l'étincelle
## (AnchorSpark, planche etincelle-ancre-propositions.html). Écart voulu avec le prototype, qui les arme aussitôt.
const SPARK_ARRIVAL := 4.75
## Durées des états du portail (PORTAL.dur) ; l'émergence a lieu après les 3 premiers.
const PORTAL_DUR := [1.0, 1.0, 1.0, 1.4, 1.2, 0.9, 0.9, 0.9, 0.9]
const PORTAL_EMERGE := 3
const PORTAL := Vector2(0.0, -167.7)
## Vitesses (move) : Ingénieur 15,2 ; adeptes 7,6 ; gardes 3,45.
const SPEED_ENGINEER := 15.2
const SPEED_ADEPT := 7.6
const SPEED_GUARD := 3.45
const ADEPT_ROLES := ["sigil", "medeina", "aether", "indra", "flammes", "archer", "lame"]
## Prière de l'Ingénieur (méditation en lévitation, planche ingenieur-priere-propositions.html, proposition 5) :
## +5 de la ressource du dieu par seconde, après le temps de s'asseoir en tailleur (planche « settle » : 1 s).
const ANCHOR_PRAY := 3.0
const ENGINEER_PRAY := 5.0
const MEDITATE_SETTLE := 1.0
const DIG_MSG :="Creusement · l’Ingénieur ancre quatre pitons à distance (une case de portée), la roche est suspendue puis effacée."

var world: World
var paused := false
## Hasard de la partie (Math.random du prototype) : apparitions, effets, sorties de la caserne. Graine fixée
## par new_game pour rejouer une partie à l'identique (tests, parties scriptées).
var rng := RandomNumberGenerator.new()
## Combat, ennemis, vagues et balistes (étape 8).
var combat := Combat.new(self)
## Bâtiments servis par des adeptes : postes, coffres, transports, mineurs (sim/production.gd).
var production := Production.new(self)
## Décision D9 : Paladin, Soigneur et Tireur présents dès le début de partie, comme avant leur mise de côté
## dans 73b410f (soldier(...) commentés dans init). Désactivé par défaut ; réglage de projet
## « exiles/debug/heros_historiques » ou affectation directe (tests).
static var legacy_heroes: bool = ProjectSettings.get_setting("exiles/debug/heros_historiques", false)


## Chronométrage optionnel des phases de tick (profilage, étape 12) : {phase: [cumul µs, max µs, appels]}.
var profile: Dictionary = {}
var profiling := false


func _process(delta: float) -> void:
	if not paused:
		tick(minf(delta, MAX_DT))


func _prof(phase: String, t0: int) -> int:
	var now := Time.get_ticks_usec()
	var r: Array = profile.get(phase, [0, 0, 0])
	r[0] += now - t0
	r[1] = maxi(r[1], now - t0)
	r[2] += 1
	profile[phase] = r
	return now


# ---------------------------------------------------------------- Partie

## init() : nouvelle partie. `seed` < 0 : graine des galeries au hasard.
func new_game(seed: int = -1) -> void:
	GameState.reset()
	var gallery_seed := seed if seed >= 0 else randi()
	rng.seed = gallery_seed
	combat.events.clear()
	Combat.reset_turrets()
	if world:
		world.reset_world(gallery_seed)
		world.camera.reset()
	# Héros « mis de côté pour une intégration ultérieure » dans 73b410f (décision D9) : derrière un drapeau.
	if legacy_heroes:
		spawn("Paladin", -2.5, 13.0, "paladin")
		spawn("Soigneur", 1.0, 15.0, "healer")
		spawn("Tireur", 3.0, 12.0, "shooter")
	var eng := spawn("Ingénieur Exilé", PORTAL.x, PORTAL.y + 0.8, "engineer")
	eng.hidden = true
	if world:
		world.camera.set_view(eng.pos(), world.camera.px)
	# selected = [units[0]] : le Paladin quand les héros sont présents.
	GameState.selected = [GameState.units[0]]
	say("L’Ancre s’est éteinte. Sélectionnez l’Ingénieur, puis clic droit sur l’Ancre (ou R) pour la réactiver.", 7.0)


func spawn(unit_name: String, x: float, z: float, role: String, squad := 0) -> Unit:
	var u := Unit.create(GameState.next_uid, unit_name, x, z, role, squad)
	GameState.next_uid += 1
	GameState.units.append(u)
	return u


func say(text: String, seconds := 2.0) -> void:
	Events.notice.emit(text, seconds)


func is_adept(u: Unit) -> bool:
	return ADEPT_ROLES.has(u.role)


func state() -> TerrainState:
	return world.terrain_state


# ---------------------------------------------------------------- Boucle

func tick(dt: float) -> void:
	GameState.sim_time += dt
	portal_tick()
	if GameState.ended:
		return
	var t := Time.get_ticks_usec() if profiling else 0
	update_buildings(dt)
	update_adepts(dt)
	if profiling:
		t = _prof("bâtiments et adeptes", t)
	combat.update_evil_portals()
	for u in GameState.units:
		u.attack -= dt
		u.ability = maxf(0.0, u.ability - dt)
		u.shield = maxf(0.0, u.shield - dt)
		u.buff = maxf(0.0, u.buff - dt)
	Martyre.tick(self)
	# Aucune vague tant que la Martyre de Byrsa est debout.
	while not Martyre.active() and not GameState.spawn_queue.is_empty() and GameState.spawn_queue[0]["at"] <= GameState.sim_time:
		combat.spawn_enemy(GameState.spawn_queue.pop_front())
	if Overload.tick():
		overload_finished.emit(GameState.overload_unit)
	var alive: Array[Unit] = []
	for u in GameState.units:
		if u.alive():
			alive.append(u)
	if profiling:
		t = _prof("portails et file", t)
	update_squads()
	combat.update_units(dt, alive)
	if not GameState.ground_items.is_empty():
		for u in alive:
			ItemStorage.collect_nearby(u)
	if profiling:
		t = _prof("alliés", t)
	combat.update_turrets(dt)
	if profiling:
		t = _prof("balistes", t)
	combat.update_enemies(dt, alive)
	if not GameState.placed.is_empty():
		Placeables.tick(self, dt)
	Martyre.enforce(self)
	if profiling:
		t = _prof("ennemis", t)
	combat.finish_tick(dt, alive)
	if profiling:
		_prof("fin de tick", t)


## steer : prochain point du chemin A* vers `to` (chemin en cache dans u.memo).
func steer(u: Unit, to: Vector2) -> Vector2:
	return world.pathfinder.steer(u.pos(), to, u.memo)


## portalTick : les unités cachées sortent du portail quand la séquence atteint l'émergence.
func portal_tick() -> void:
	var te := GameState.portal_start
	for i in PORTAL_EMERGE:
		te += PORTAL_DUR[i]
	if GameState.sim_time < te:
		return
	for u in GameState.units:
		if not u.hidden:
			continue
		u.hidden = false
		if u.role == "engineer":
			# Reste juste devant le portail après son émergence.
			u.tx = u.x
			u.tz = u.z
			engineer_greeted.emit(u)
		else:
			var e: Vector2 = u.exit_point if u.exit_point != null else Vector2(PORTAL.x + 3.0, CaveShape.CORE.y + 4.0)
			u.tx = e.x
			u.tz = e.y
			if u.arrival:
				say(u.arrival, 2.5)


## move : avance vers t ; glisse le long des murs si le pas direct entre dans la roche.
func move(u: Unit, t: Vector2, dt: float, mult := 1.0) -> void:
	var dx := t.x - u.x
	var dz := t.y - u.z
	var d := sqrt(dx * dx + dz * dz)
	if d < 0.24:
		return
	var speed := (SPEED_GUARD if u.role == "guard" else SPEED_ADEPT if is_adept(u) else SPEED_ENGINEER) * mult
	var step := minf(d, speed * dt)
	var nx := u.x + dx / d * step
	var nz := u.z + dz / d * step
	var st := state()
	if st.walkable(nx, nz):
		u.x = nx
		u.z = nz
	elif st.walkable(nx, u.z):
		u.x = nx
	elif st.walkable(u.x, nz):
		u.z = nz
	clamp_world(u)


## clampWorld : limites du monde puis sortie de la roche.
func clamp_world(u: Unit) -> void:
	u.x = clampf(u.x, CaveShape.WORLD_X0 + 8.0, CaveShape.WORLD_X1 - 8.0)
	u.z = clampf(u.z, CaveShape.WORLD_Z0 + 8.0, CaveShape.WORLD_Z1 - 6.0)
	# Position conservée en double précision quand elle est praticable (un Vector2 l'arrondirait en 32 bits).
	if state().walkable(u.x, u.z):
		return
	var p := state().push_out_of_rock(u.pos())
	u.x = p.x
	u.z = p.y


# ---------------------------------------------------------------- Ancre (buildings.js)

## updateBuildings : Ancre, chantiers (l'Ingénieur doit se tenir sur le point de travail), caserne.
func update_buildings(dt: float) -> void:
	update_orb(dt)
	update_research(dt)
	for b: Building in GameState.buildings.duplicate():
		var D := b.def()
		if not b.complete:
			var u := b.owner
			if u == null or not u.alive() or u.hidden or u.build_job != b:
				if u:
					cancel_build(u)
				else:
					GameState.buildings.erase(b)
				continue
			if Combat.hyp(u.x - b.spot.x, u.z - b.spot.y) > 0.5:
				continue
			b.progress = minf(D["time"], b.progress + dt * (2.0 if GameState.fast_construction else 1.0))
			if b.progress < D["time"]:
				continue
			b.complete = true
			b.finished_at = GameState.sim_time
			u.build_job = null
			Combat.zone(b.x, b.z, b.half(), Color("#e8d9a8"))
			var deity: String = D["deity"]
			if deity:
				say("%s achevé. Sélectionnez-le pour invoquer un adepte de %s (%d %s)." % [D["name"], Catalog.DEITY_NAMES[deity],
					Catalog.SUMMON_COST, Catalog.RES_INFO[Catalog.DEITY_RES[deity]]["name"]], 4.0)
			else:
				say("%s achevé.%s" % [D["name"], unlock_text(b.type)], 4.0)
			continue
		# Soins du Puits : il faut au moins un adepte de Medeina (ou l'Ingénieur) au poste.
		if b.type == "soulwell" and not Production.idle(b):
			for unit: Unit in GameState.units:
				if unit.alive() and not unit.hidden and unit.hp < unit.max_hp \
						and Vector2(unit.x - b.x, unit.z - b.z).length_squared() <= float(D["heal_radius"]) ** 2:
					unit.hp = minf(unit.max_hp, unit.hp + float(D["heal_per_second"]) * dt)
					unit.healed_at = GameState.sim_time
	# Fabrication, entraînement de la caserne et transports : sim/production.gd.
	production.update(dt)
	GameState.pray_popups = GameState.pray_popups.filter(func(p: Dictionary) -> bool: return GameState.sim_time - p["at"] < 1.8)


## unlockText : bâtiments débloqués par celui qui vient d'être achevé.
static func unlock_text(type: String) -> String:
	var next: PackedStringArray = []
	for k: String in Catalog.BUILDINGS:
		if Catalog.BUILDINGS[k]["requires"] == type:
			next.append(Catalog.BUILDINGS[k]["name"])
	return " Nouveau : %s." % ", ".join(next) if not next.is_empty() else ""


func update_orb(dt: float) -> void:
	if GameState.orb_active:
		if GameState.spark_pending and GameState.sim_time - GameState.orb_finished_at >= SPARK_ARRIVAL:
			GameState.spark_pending = false
			combat.activate_turrets()
			turrets_activated.emit()
		return
	var u := GameState.orb_owner
	if u == null:
		return
	if not u.alive() or u.hidden or not u.orb_job:
		GameState.orb_owner = null
		return
	if Combat.hyp(u.x - ORB_SPOT.x, u.z - ORB_SPOT.y) > 0.6:
		return
	GameState.orb_progress = minf(ORB_TIME, GameState.orb_progress + dt * (2.0 if GameState.fast_construction else 1.0))
	if GameState.orb_progress < ORB_TIME:
		return
	GameState.orb_active = true
	GameState.core_hp = 100.0
	GameState.orb_finished_at = GameState.sim_time
	u.orb_job = false
	Combat.zone(CaveShape.CORE.x, CaveShape.CORE.y, 7.0, Color("#bba7ff"))
	Combat.zone(CaveShape.CORE.x, CaveShape.CORE.y, 12.0, Color("#8777ac"))
	# Les balistes s'arment à l'arrivée de l'étincelle (SPARK_ARRIVAL), plus haut.
	GameState.spark_pending = true
	GameState.next_wave = GameState.sim_time + 20.0
	say("L’Ancre s’éveille ! Les gardes tyriennes de l’entrée se rallument · premier assaut dans 20 s.", 5.0)


## orderOrb : envoie l'Ingénieur (sélectionné, sinon le premier disponible) réactiver l'Ancre.
func order_orb(u: Unit = null) -> void:
	if GameState.ended:
		return
	if GameState.orb_active:
		say("L’Ancre est éveillée. L’Ingénieur peut y prier.", 2.0)
		return
	if u == null:
		u = builder()
	if u == null:
		for o in GameState.units:
			if o.role == "engineer" and o.alive() and not o.hidden:
				u = o
				break
	if u == null:
		say("Attendez la sortie de l’Ingénieur.", 2.0)
		return
	cancel_work(u)
	GameState.orb_owner = u
	u.orb_job = true
	u.tx = ORB_SPOT.x
	u.tz = ORB_SPOT.y
	u.stance = "attack"
	GameState.selected = [u]
	GameState.anchor_selected = false
	GameState.hud_menu = ""
	say("L’Ingénieur rejoint l’Ancre pour la réactiver · %d s d’Énonciation." % ORB_TIME, 3.0)


func cancel_orb(u: Unit) -> void:
	if u == null:
		return
	if GameState.orb_owner == u and not GameState.orb_active:
		GameState.orb_owner = null
	u.orb_job = false


## L'Ingénieur s'agenouille pendant l'Énonciation (templeKneeling) : chantier en cours ou réactivation de
## l'Ancre (réparation des balistes : étape 8).
func kneeling(u: Unit) -> bool:
	var b: Building = u.build_job
	if b:
		return b.owner == u and not b.complete and b.progress > 0.0 and Combat.hyp(u.x - b.spot.x, u.z - b.spot.y) <= 0.5
	return GameState.orb_owner == u and u.orb_job and not GameState.orb_active and GameState.orb_progress > 0.0 \
		and Combat.hyp(u.x - ORB_SPOT.x, u.z - ORB_SPOT.y) <= 0.6


# ---------------------------------------------------------------- Tâches (adepts.js)

func _first_engineer() -> Unit:
	for u in GameState.units:
		if u.role == "engineer" and u.alive():
			return u
	return null


func builder() -> Unit:
	for u in GameState.selected:
		if u.role == "engineer" and u.alive() and not u.hidden:
			return u
	return null


func set_job(u: Unit, job: Dictionary) -> void:
	if job.get("type") == "dig" and not can_mine(u):
		engineer_spoke.emit(u, "Impossible. Je n'ai pas mon sceau de minage.")
		return
	# cancelTurretRepair : étape 8.
	cancel_build(u)
	cancel_orb(u)
	if not u.carrying.is_empty():
		production._drop(u)
	job.merge({"phase": "go", "carry": 0, "work": 0.0})
	u.job = job
	u.stance = "attack"
	u.force_move = false


func cancel_work(u: Unit) -> void:
	if u == null:
		return
	cancel_build(u)
	cancel_orb(u)
	# cancelTurretRepair : étape 8.
	u.job = null


## cancelBuild : un chantier abandonné disparaît et son coût est remboursé.
func cancel_build(u: Unit) -> void:
	if u == null:
		return
	var b: Building = u.build_job
	if b and not b.complete:
		GameState.buildings.erase(b)
		Catalog.refund(b.def()["cost"])
		if GameState.hud_building == b:
			GameState.hud_building = null
	u.build_job = null


func _collect_mined_item(item: String, miner: Unit, drop_position: Vector2) -> void:
	if miner.role == "engineer":
		ItemStorage.deposit(item, miner, drop_position)
	else:
		miner.carrying = {"item": item, "quantity": 1}
	GameState.effects.append({"type": "mining_gain", "miner": miner, "item": item, "age": 0.0, "duration": 1.0})
	if not GameState.collected_items.has(item):
		GameState.collected_items[item] = true
		GameState.effects.append({"type": "new_resource", "miner": miner, "item": item, "age": 0.0, "duration": 2.6})


## Un bois récolté sur un arbre pétrifié : seul un adepte de Medeina ne l'entame pas. À WOOD_YIELD bois,
## l'arbre est abattu et sa case creusée. Renvoie true si l'arbre vient de disparaître.
func _spend_wood(u: Unit, key: Vector2i) -> bool:
	var st := state()
	if not st.grove_cells.has(key) or u.role == Blocks.WOOD_KEEPER:
		return false
	var origin: Vector2i = st.grove_cells[key]
	st.wood_left[origin] = int(st.wood_left[origin]) - 1
	if st.wood_left[origin] > 0:
		return false
	st.fell_grove(origin)
	say("Le bosquet pétrifié s’effondre : le gisement est épuisé.", 2.0)
	return true


func update_adepts(_dt: float) -> void:
	var dt := _dt
	combat.update_fire_walls(dt)
	var st := state()
	for u in GameState.units:
		u.working = false
		var j: Variant = u.job
		if j == null or not u.alive():
			continue
		if j["type"] == "dig":
			if not u.carrying.is_empty():
				if production.deliver_harvest(u) and j.get("advance_after_delivery", false):
					j.erase("advance_after_delivery")
					_advance_dig(u)
				continue
			if not can_mine(u):
				u.job = null
				u.tx = u.x
				u.tz = u.z
				continue
			var c: Dictionary = j["cell"]
			var key := Vector2i(c["i"], c["j"])
			var block := st.block_definition(key.x, key.y)
			# Case vide (bloc absent, ou bosquet abattu entre-temps) : on passe à la suivante.
			if block.is_empty() or (st.walkable(key.x * 4.0 + 2.0, key.y * 4.0 + 2.0) and not st.permanent_ores.has(key)):
				_advance_dig(u)
				continue
			var resistance: int = block["resistance"]
			var eng := u.role == "engineer"
			if st.dug.has(key):
				_advance_dig(u)
				continue
			var at: Vector2 = j["at"]
			# L'Ingénieur tire ses pitons à distance : il s'arrête dès que la case est à portée.
			if eng and st.in_dig_reach(key.x, key.y, u.pos()):
				u.tx = u.x
				u.tz = u.z
			else:
				u.tx = at.x
				u.tz = at.y
				if Combat.hyp(u.x - at.x, u.z - at.y) >= 0.7:
					continue
			u.working = true
			if not eng:
				var interval := adept_mining_seconds(u)
				j["work"] += dt
				if j["work"] >= interval:
					j["work"] -= interval
					_collect_mined_item(block["drop_item"], u, u.pos())
					j["advance_after_delivery"] = _spend_wood(u, key) or int(j.get("index", 0)) + 1 < (j.get("cells", []) as Array).size()
					if production.deliver_harvest(u) and j["advance_after_delivery"]:
						_advance_dig(u)
				continue
			j["work"] += dt * TerrainState.ENGINEER_DIG * TerrainState.DIG_HITS
			while j["work"] >= TerrainState.HIT_TIME:
				j["work"] -= TerrainState.HIT_TIME
				var h: int = st.dig_hits.get(key, 0) + 1
				st.dig_hits[key] = h
				st.dig_hit_at[key] = GameState.sim_time
				Combat.piton(u, key, (h - 1) % 4)
				if h >= resistance:
					if st.permanent_ores.has(key):
						st.dig_hits.erase(key)
						st.dig_hit_at.erase(key)
						_collect_mined_item(block["drop_item"], u, u.pos())
						if _spend_wood(u, key):
							_advance_dig(u)
							break
						# Gisement inépuisable : l'Ingénieur continue d'y récolter s'il termine sa file,
						# sinon il passe à la case suivante de la sélection.
						if int(j.get("index", 0)) + 1 < (j.get("cells", []) as Array).size():
							_advance_dig(u)
							break
						continue
					Combat.suspend(u, key, world.cell_image(key.x, key.y))
					world.dig_cell(key.x, key.y)
					_collect_mined_item(block["drop_item"], u, Vector2(key.x * 4 + 2, key.y * 4 + 2))
					_advance_dig(u)
					break
			continue
		if j["type"] == "anchor_pray":
			if not GameState.orb_active or u.role != "engineer" or u.hidden:
				u.job = null
				continue
			u.tx = ORB_SPOT.x
			u.tz = ORB_SPOT.y
			if u.pos().distance_to(ORB_SPOT) < 0.7:
				u.working = true
				if not j.has("since"):
					j["since"] = GameState.sim_time
				for resource: String in Catalog.RES_ORDER:
					GameState.res[resource] += ANCHOR_PRAY * dt
			else:
				j.erase("since")
			continue
		if j["type"] == "chest":
			var spot := CaveShape.CHEST_SPOT
			u.tx = spot.x
			u.tz = spot.y
			if Combat.hyp(u.x - spot.x, u.z - spot.y) >= 0.7:
				continue
			open_chest(u)
			u.job = null
			continue
		if j["type"] == "staff":
			production.update_unit(u, dt)
			continue
		if j["type"] == "collect":
			production.update_collect(u)
			continue
		if j["type"] == "pray":
			var t: Building = j["temple"]
			if not GameState.buildings.has(t) or not t.complete:
				u.job = null
				continue
			var spot := prayer_spot(u, t)
			u.tx = spot.x
			u.tz = spot.y
			if Combat.hyp(u.x - spot.x, u.z - spot.y) >= 0.7:
				j.erase("since")
				continue
			u.working = true
			var r: String = Catalog.DEITY_RES[t.def()["deity"]]
			if u.role == "engineer":
				# Méditation en lévitation : il s'assoit (MEDITATE_SETTLE), puis +5 à chaque seconde entière.
				if not j.has("since"):
					j["since"] = GameState.sim_time
					j["ticks"] = 0
				var n := floori(GameState.sim_time - j["since"] - MEDITATE_SETTLE)
				while j["ticks"] < n:
					j["ticks"] += 1
					GameState.res[r] += ENGINEER_PRAY
					GameState.pray_popups.append({"x": t.x, "z": t.z, "amount": int(ENGINEER_PRAY), "res": r, "at": GameState.sim_time})
				continue
			var gain := dt * pray_rate(u, t)
			GameState.res[r] += gain
			t.acc += gain
			if t.acc >= 5.0:
				t.acc -= 5.0
				GameState.pray_popups.append({"x": t.x, "z": t.z, "amount": 5, "res": r, "at": GameState.sim_time})
			continue
		u.job = null
	for id: String in Catalog.DEITY_NAMES:
		GameState.deity_active[id] = GameState.sim_time < GameState.deity_until.get(id, 0.0)
	_vault_hint()


## Distance à laquelle l'Ingénieur remarque le glyphe de la paroi est (unités de monde).
const VAULT_HINT_RANGE := 9.0


## L'Ingénieur muni du Sceau de minage passe près du glyphe : il le remarque, une fois par partie.
func _vault_hint() -> void:
	if GameState.vault_hint_said or state().vault_open or not GameState.research_done.has("mining_artifact"):
		return
	var at := Vector2(CaveShape.VAULT_X0 - 6.0, -146.0)
	for u in GameState.units:
		if u.role == "engineer" and u.alive() and not u.hidden and u.pos().distance_to(at) < VAULT_HINT_RANGE:
			GameState.vault_hint_said = true
			engineer_spoke.emit(u, "Un glyphe tyrien dans la roche, encore alimenté. Il y a quelque chose de scellé derrière cette paroi.")
			return


## Coffre antique (réserve scellée à l'est de la salle) : clic droit dessus. Fermé, l'Ingénieur (sélectionné,
## sinon le premier disponible) va l'ouvrir ; ouvert, l'inventaire s'affiche. Faux si la réserve est scellée.
func order_chest(u: Unit = null) -> bool:
	if GameState.ended or not state().vault_open:
		return false
	if GameState.base_inventory_unlocked:
		Events.inventory_requested.emit()
		return true
	if u == null:
		u = builder()
	if u == null:
		for o in GameState.units:
			if o.role == "engineer" and o.alive() and not o.hidden:
				u = o
				break
	if u == null:
		say("Seul l’Ingénieur sait ouvrir ce reliquaire.", 2.0)
		return true
	set_job(u, {"type": "chest"})
	u.tx = CaveShape.CHEST_SPOT.x
	u.tz = CaveShape.CHEST_SPOT.y
	GameState.selected = [u]
	say("L’Ingénieur rejoint le coffre antique.", 2.0)
	return true


## L'Ingénieur arrive devant le coffre : le couvercle s'ouvre et la réserve de la base (100 cases) se débloque.
func open_chest(u: Unit) -> void:
	if GameState.base_inventory_unlocked:
		return
	GameState.base_inventory_unlocked = true
	GameState.chest_opened_at = GameState.sim_time
	Combat.zone(CaveShape.CHEST.x, CaveShape.CHEST.y - 1.0, 4.0, Color("#5ce8ff"))
	engineer_spoke.emit(u, "Un reliquaire tyrien. Il tient bien plus que sa taille : cent emplacements.")
	say("Coffre antique ouvert · la réserve de la base (100 cases) reçoit désormais les objets minés (touche C).", 4.0)


func order_adepts(p: Vector2) -> bool:
	var cell: Variant = state().diggable_cell(p)
	return cell != null and order_mining_cells([cell])


func order_mining_cells(cells: Array) -> bool:
	if cells.is_empty():
		return false
	var ordered: Array[Dictionary] = []
	var seen: Dictionary = {}
	for cell: Dictionary in cells:
		var key := Vector2i(cell["i"], cell["j"])
		if not seen.has(key):
			seen[key] = true
			ordered.append(cell.duplicate())
	if ordered.is_empty():
		return false
	var handled := false
	var engineer_digging := false
	var adept_mining := false
	for u: Unit in GameState.selected:
		if not u.alive() or u.hidden or (u.role != "engineer" and not Catalog.is_adept(u)):
			continue
		handled = true
		# Adepte d'Aether affecté à un bâtiment, sur un gisement inépuisable : il devient mineur du bâtiment.
		if production.try_miner(u, ordered):
			continue
		if not can_mine(u):
			engineer_spoke.emit(u, "Impossible. Je n'ai pas mon sceau de minage.")
			continue
		var queue := ordered.duplicate(true)
		set_job(u, {"type": "dig", "cells": queue, "index": 0, "cell": queue[0], "at": queue[0]["at"]})
		if u.role == "engineer":
			engineer_digging = true
		else:
			adept_mining = true
	if engineer_digging:
		say(DIG_MSG, 2.0)
	elif adept_mining:
		say("Les adeptes récoltent le matériau du bloc.", 2.0)
	return handled


## Passe à la case suivante de la sélection, ou termine la tâche.
func _advance_dig(u: Unit) -> bool:
	var j: Dictionary = u.job
	j["index"] = int(j.get("index", 0)) + 1
	var cells: Array = j.get("cells", [])
	while int(j["index"]) < cells.size():
		var cell: Dictionary = cells[j["index"]]
		if not state().block_definition(cell["i"], cell["j"]).is_empty() and not state().dug.has(Vector2i(cell["i"], cell["j"])):
			j["cell"] = cell
			j["at"] = cell["at"]
			j["work"] = 0.0
			return true
		j["index"] = int(j["index"]) + 1
	u.job = null
	return false


# ---------------------------------------------------------------- Ordres (hud.js, Index.html)

## issueMove : formation en grille de 4 colonnes espacées de 1,5. `target_is_enemy` : ordre d'attaque.
func issue_move(target: Vector2, target_is_enemy := false) -> void:
	if GameState.anchor_selected or GameState.ended:
		return
	var valid := expand_squads(GameState.selected)
	var cols := mini(4, valid.size())
	for i in valid.size():
		var u: Unit = valid[i]
		cancel_work(u)
		u.tx = target.x + (i % cols - (cols - 1) / 2.0) * 1.5
		u.tz = target.y + (floori(float(i) / cols) - (ceili(float(valid.size()) / cols) - 1) / 2.0) * 1.5
		u.tx = clampf(u.tx, CaveShape.WORLD_X0 + 8.0, CaveShape.WORLD_X1 - 8.0)
		u.tz = clampf(u.tz, CaveShape.WORLD_Z0 + 8.0, CaveShape.WORLD_Z1 - 8.0)
		u.stance = "attack"
		u.force_move = not target_is_enemy
	GameState.hud_mode = ""


## hold : les unités sélectionnées tiennent leur position.
func hold() -> void:
	GameState.hud_mode = ""
	for u in expand_squads(GameState.selected):
		if u.alive() and not u.hidden:
			cancel_work(u)
			u.stance = "hold"
			u.tx = u.x
			u.tz = u.z
	if not GameState.selected.is_empty():
		say("Les unités maintiennent leur position.", 1.0)


## ability : compétence de la première unité sélectionnée vivante hors garde (Index.html:96). Ingénieur :
## réactiver l'Ancre si elle est éteinte, sinon la réparer (+15 %, 18 s). Paladin : Égide (16 s). Soigneur :
## Restauration (12 s). Tireur : tir de précision (10 s). Autres : Discipline martiale (14 s).
func ability() -> void:
	var source: Unit = null
	for u in GameState.selected:
		if u.alive() and u.role != "guard":
			source = u
			break
	if source == null and not GameState.selected.is_empty():
		source = GameState.selected[0]
	if source == null:
		return
	if source.role == "engineer" and not GameState.orb_active:
		order_orb(source)
		return
	if source.ability > 0.0:
		say("Compétence en recharge.", 1.0)
		return
	if source.role == "paladin":
		# Égide : onde de 5, 35 dégâts aux ennemis proches, boucliers (dégâts subis ÷ 2) pendant 7 s.
		source.ability = 16.0
		Combat.zone(source.x, source.z, 5.0, Color("#f1d28c"))
		for e in GameState.enemies:
			if Combat.dist(e, source) < 5.0:
				combat.damage(e, 35.0 + Catalog.lvl_bonus(source), source)
		for u in GameState.units:
			if Combat.dist(u, source) < 5.0:
				u.shield = 7.0
		say("PALADIN — Égide : boucliers renforcés.", 2.0)
	elif source.role == "healer":
		# Restauration : +55 PV dans un rayon de 7. Comme le prototype, une unité tombée dans le rayon
		# reprend aussi 55 PV (elle reste pourtant parmi les âmes du Puits) : comportement reproduit tel quel.
		source.ability = 12.0
		Combat.zone(source.x, source.z, 7.0, Color("#83e5bf"))
		for u in GameState.units:
			if Combat.dist(u, source) < 7.0:
				if u.hp < u.max_hp:
					u.healed_at = GameState.sim_time
				u.hp = minf(u.max_hp, u.hp + 55.0)
				if u.hp <= 0.0:
					u.hp = 25.0
		say("SOIGNEUR — Restauration de zone.", 2.0)
	elif source.role == "engineer":
		source.ability = 18.0
		GameState.core_hp = minf(100.0, GameState.core_hp + 15.0)
		Combat.zone(CaveShape.CORE.x, CaveShape.CORE.y, 4.0, Color("#ffb03c"))
		say("INGÉNIEUR EXILÉ — Réparation de l’Ancre.", 2.0)
	elif source.role == "shooter":
		source.ability = 10.0
		if world:
			world.fog.refresh(state())
		var t: Variant = Combat.target_closest(source, GameState.enemies, 18.0, world)
		if t:
			combat.damage(t, 95.0 + Catalog.lvl_bonus(source), source)
			Combat.blast(source, t, Color("#f7e7a2"))
			Combat.flash(t.x, t.z, Color("#f7e7a2"))
		say("TIREUR — Tir de précision.", 2.0)
	else:
		# Toute autre unité (branche finale du prototype) : Discipline martiale, dégâts ×1,5 pendant 8 s pour
		# toute son escouade (escouade 0 comprise : toutes les unités hors escouade).
		source.ability = 14.0
		Combat.zone(source.x, source.z, 7.0, Color("#a1badb"))
		for u in GameState.units:
			if u.squad == source.squad:
				u.buff = 8.0
		say("DISCIPLES D’INDRA — Discipline martiale.", 2.0)


## prayerSpot : rangées de 5 devant le temple (derrière s'il est adossé à la roche).
func prayer_spot(u: Unit, t: Building) -> Vector2:
	var praying := GameState.units.filter(func(o: Unit) -> bool:
		return o.job != null and o.job["type"] == "pray" and o.job["temple"] == t and o.alive())
	var i := maxi(0, praying.find(u))
	var h := t.half()
	var s := Vector2(t.x - 4.0 + (i % 5) * 2.0, t.z + h + 1.0 + floori(i / 5.0) * 1.6)
	if not state().walkable(s.x, s.y):
		s = Vector2(t.x - 4.0 + (i % 5) * 2.0, t.z - h - 1.0 - floori(i / 5.0) * 1.6)
	return s


# ---------------------------------------------------------------- Ordres du panneau (hud.js, buildings.js, adepts.js)

## runAbility : compétence de la sélection (bouton Réparer ou Compétence).
func run_ability() -> void:
	if GameState.anchor_selected or GameState.ended or not _any_selected_visible():
		return
	ability()


## armMove : bascule le mode « choisir une destination ».
func arm_move() -> void:
	if GameState.anchor_selected or GameState.ended or not _any_selected_visible():
		return
	GameState.hud_mode = "" if GameState.hud_mode == "move" else "move"


func _any_selected_visible() -> bool:
	return GameState.selected.any(func(u: Unit) -> bool: return u.alive() and not u.hidden)


## armBuild : choisit le bâtiment à placer. Le placement au clic (placeBuilding) arrive à l'étape 7.
func arm_build(type: String) -> void:
	if GameState.ended or builder() == null:
		return
	var D: Dictionary = Catalog.BUILDINGS[type]
	if not HudModel.unlocked(type):
		say("%s : construisez d’abord un %s." % [D["name"], Catalog.BUILDINGS[D["requires"]]["name"]], 3.0)
		return
	if not Catalog.can_pay(D["cost"]):
		say("%s : %s requis." % [D["name"], Catalog.cost_text(D["cost"])], 3.0)
		return
	GameState.hud_mode = "build"
	GameState.hud_build_type = type
	say("%s · %s · cliquez un emplacement libre. Échap : annuler." % [D["name"], Catalog.cost_text(D["cost"])], 4.0)


## summonHero : le héros Tireur franchit le portail central (même séquence que l'Ingénieur).
func summon_hero() -> void:
	if GameState.ended:
		return
	if not GameState.anchor_selected:
		say("Cliquez sur l’Ancre pour invoquer le héros Tireur.", 3.0)
		return
	if not GameState.orb_active:
		say("L’Ancre doit d’abord être réactivée par l’Ingénieur.", 3.0)
		return
	if not Catalog.can_pay(Catalog.HERO_COST):
		say("Héros Tireur : %s requis." % Catalog.cost_text(Catalog.HERO_COST), 3.0)
		return
	Catalog.pay(Catalog.HERO_COST)
	var u := spawn("Tireur", PORTAL.x, PORTAL.y + 0.8, "shooter")
	u.hidden = true
	u.exit_point = Vector2(PORTAL.x + 3.0, CaveShape.CORE.y + 4.0)
	u.arrival = "Le héros Tireur franchit le portail."
	GameState.portal_start = GameState.sim_time
	say("Le portail s’éveille…", 2.0)


## sendToPray, pour chaque adepte sélectionné (bouton Prier).
func pray_selected() -> void:
	var n := 0
	for u in HudModel.alive_selected():
		if send_to_pray(u):
			n += 1
	say("Les adeptes rejoignent leur temple pour prier." if n else "Aucun temple de leur dieu n’est achevé.", 2.0)


## Clic droit sur un temple avec l'Ingénieur sélectionné : il rejoint le parvis et médite en lévitation.
func order_pray(b: Building) -> bool:
	if b == null or not b.complete or not b.is_temple():
		return false
	var sigils := GameState.selected.filter(func(u: Unit) -> bool: return u.role == "sigil" and u.alive() and not u.hidden)
	for u: Unit in sigils:
		set_job(u, {"type": "pray", "temple": b})
	var engs := GameState.selected.filter(func(u: Unit) -> bool: return u.role == "engineer" and u.alive() and not u.hidden)
	if engs.is_empty():
		if not sigils.is_empty():
			var foreign: bool = b.def()["deity"] != "sigil"
			say("Les adeptes de Sigil prient au %s%s." % [b.def()["name"], " · deux fois plus lentement" if foreign else ""], 2.0)
		return not sigils.is_empty()
	for u: Unit in engs:
		set_job(u, {"type": "pray", "temple": b})
	say("L’Ingénieur rejoint le %s pour méditer · +%d %s / s." % [b.def()["name"], int(ENGINEER_PRAY), Catalog.RES_INFO[Catalog.DEITY_RES[b.def()["deity"]]]["name"]], 2.0)
	return true


func send_to_pray(u: Unit, t: Building = null) -> bool:
	if not Catalog.prays(u):
		return false
	if t == null:
		var best := INF
		var pool := HudModel.own_temples(u)
		if pool.is_empty():
			pool = HudModel.prayable_temples(u)
		for o in pool:
			var d := Combat.hyp(o.x - u.x, o.z - u.z)
			if d < best:
				best = d
				t = o
	if t == null:
		return false
	set_job(u, {"type": "pray", "temple": t})
	return true


# ---------------------------------------------------------------- Construction (buildings.js)

const CELL := 4.0
## Emplacements des deux balistes de l'entrée (resetTurrets, turret-game.js) : aucun bâtiment à moins de h + 5.
const TURRET_SPOTS: Array[Vector2] = [Vector2(-11, -71), Vector2(11, -71)]
## Portails divins (DEITY_PORTALS, Index.html) : abscisse de chaque dieu sur la rangée nord.
const DEITY_X := {"indra": -41.0, "sigil": -24.0, "medeina": 24.0, "aether": 41.0}


static func half_of(type: String) -> float:
	return int(Catalog.BUILDINGS[type]["size"]) * CELL / 2.0


## Math.round du JS : arrondi au demi supérieur (y compris pour les négatifs).
static func js_round(v: float) -> float:
	return floorf(v + 0.5)


## snapFor : centre de case (côté impair) ou nœud de la grille (côté pair).
static func snap_for(type: String, p: Vector2) -> Vector2:
	if int(Catalog.BUILDINGS[type]["size"]) % 2:
		return Vector2(floorf(p.x / CELL) * CELL + CELL / 2.0, floorf(p.y / CELL) * CELL + CELL / 2.0)
	return Vector2(js_round(p.x / CELL) * CELL, js_round(p.y / CELL) * CELL)


## Tout sol praticable est constructible, y compris les allées et les galeries.
func buildable_ground(x: float, z: float) -> bool:
	return state().walkable(x, z)


## validSite : sol constructible sous toute l'emprise, à l'écart des bâtiments, des balistes, de l'Ancre
## et des unités.
func valid_site(type: String, p: Vector2) -> bool:
	var h := half_of(type)
	var x := p.x - h + 0.5
	while x <= p.x + h - 0.4:
		var z := p.y - h + 0.5
		while z <= p.y + h - 0.4:
			if not buildable_ground(x, z):
				return false
			z += 2.0
		x += 2.0
	for b in GameState.buildings:
		if absf(b.x - p.x) < b.half() + h + CELL and absf(b.z - p.y) < b.half() + h + CELL:
			return false
	for t in TURRET_SPOTS:
		if absf(t.x - p.x) < h + 5.0 and absf(t.y - p.y) < h + 5.0:
			return false
	if absf(CaveShape.CORE.x - p.x) < h + 4.0 and absf(CaveShape.CORE.y - p.y) < h + 4.0:
		return false
	for u in GameState.units:
		if u.alive() and not u.hidden and absf(u.x - p.x) < h + 0.6 and absf(u.z - p.y) < h + 0.6:
			return false
	return true


## workSpot : premier côté praticable (ouest, est, sud, nord) où l'Ingénieur se tient.
func work_spot(type: String, p: Vector2) -> Vector2:
	var h := half_of(type)
	for q: Vector2 in [Vector2(p.x - h - 2.0, p.y + 3.0), Vector2(p.x + h + 2.0, p.y + 3.0), Vector2(p.x, p.y + h + 2.0), Vector2(p.x, p.y - h - 2.0)]:
		if state().walkable(q.x, q.y):
			return q
	return Vector2(p.x - h - 2.0, p.y + 3.0)


## Toutes les cases de l’emprise doivent avoir été repérées.
func site_visible(type: String, center: Vector2) -> bool:
	var size := int(Catalog.BUILDINGS[type]["size"])
	var first := center - Vector2.ONE * (half_of(type) - CELL / 2)
	for x in size:
		for z in size:
			if not world.fog.visible_at(first + Vector2(x, z) * CELL):
				return false
	return true


## Mode pose : l'objet `item` (défense de l'Atelier) suivra le prochain clic gauche.
func arm_place(item: String) -> void:
	GameState.hud_place_item = item
	GameState.hud_mode = "place"


## Clic en mode pose : l'objet est posé sur la case visée et retiré du stock. Le mode reste armé tant qu'il
## en reste (barricades à la chaîne), clic droit ou Échap pour sortir.
func place_item(p: Vector2) -> void:
	var item := GameState.hud_place_item
	if GameState.ended or builder() == null or item.is_empty() or GameState.hud_mode != "place":
		return
	world.fog.refresh(state())
	if Placeables.place(self, item, p) and ItemStorage.count(item) <= 0:
		GameState.hud_mode = ""


## placeBuilding : clic en mode construction. Paie, crée le chantier et envoie l'Ingénieur sur son point.
func place_building(p: Vector2) -> void:
	var u := builder()
	var type := GameState.hud_build_type
	if GameState.ended or u == null or type.is_empty() or GameState.hud_mode != "build":
		return
	var D: Dictionary = Catalog.BUILDINGS[type]
	p = snap_for(type, p)
	world.fog.refresh(state())
	if not site_visible(type, p):
		say("Explorez tout l’emplacement avant de construire.", 2.0)
		return
	if not valid_site(type, p):
		say("Emplacement impossible : il faut un sol dégagé (grotte, galerie creusée ou jungle).", 2.0)
		return
	if not Catalog.can_pay(D["cost"]):
		say("%s : %s requis." % [D["name"], Catalog.cost_text(D["cost"])], 3.0)
		GameState.hud_mode = ""
		return
	cancel_work(u)
	Catalog.pay(D["cost"])
	var id := 0
	for o in GameState.buildings:
		id = maxi(id, o.id + 1)
	var b := Building.create(id, type, p.x, p.y)
	b.owner = u
	b.spot = work_spot(type, p)
	GameState.buildings.append(b)
	u.build_job = b
	u.tx = b.spot.x
	u.tz = b.spot.y
	u.stance = "attack"
	GameState.hud_mode = ""
	GameState.hud_menu = ""
	say("L’Ingénieur rejoint le chantier · %s · Énonciation : %s s." % [D["name"], HudModel.num(D["time"])], 3.0)


# ---------------------------------------------------------------- Temples, caserne, Puits des Âmes

## summonAdept : un adepte du dieu franchit son portail divin (actif 3,5 s) et part prier au temple.
func summon_adept(b: Building) -> void:
	if GameState.ended or b == null:
		return
	var id: String = b.def()["deity"]
	if not b.complete or id.is_empty():
		return
	var cost := HudModel.summon_cost(b)
	if not Catalog.can_pay(cost):
		say("Invocation : %s requis." % Catalog.cost_text(cost), 3.0)
		return
	Catalog.pay(cost)
	GameState.deity_until[id] = GameState.sim_time + 3.5
	var A: Dictionary = Catalog.ADEPT[id]
	var u := spawn(A["name"], DEITY_X[id], PORTAL.y + 1.8, id)
	GameState.menace += 1
	u.hp = A["hp"]
	u.max_hp = u.hp
	u.radius = 0.55
	Combat.flash(DEITY_X[id], PORTAL.y + 1.0, Catalog.DEITY_GLOW[id])
	if b.rally_point != null:
		u.tx = b.rally_point.x
		u.tz = b.rally_point.y
		u.force_move = true
	else:
		set_job(u, {"type": "pray", "temple": b})
	say("%s franchit le portail et rejoint son temple pour prier." % A["name"], 2.0)


## trainUnit : file de la caserne (5 au plus), 100 Discipline par combattant.
func train_unit(b: Building, id: String) -> void:
	if b == null or b.type != "caserne" or not b.complete:
		return
	if b.queue.size() >= Catalog.CASERNE_QUEUE:
		say("File d’entraînement pleine.", 2.0)
		return
	if not Catalog.can_pay(Catalog.CASERNE_COST):
		say("Entraînement : %s requis." % Catalog.cost_text(Catalog.CASERNE_COST), 3.0)
		return
	# Les objets (arcs, flèches, épées, boucliers) sont apportés au coffre bleu par les adeptes d'Indra
	# (sim/production.gd) ; l'entraînement attend qu'ils y soient.
	Catalog.pay(Catalog.CASERNE_COST)
	b.queue.append(id)
	say("%s à l’entraînement · %s s." % [Catalog.ADEPT[id]["name"], HudModel.num(Catalog.CASERNE_TIME)], 2.0)


## Fabrication (Atelier, Forge, Creuset) : la recette choisie est fabriquée en boucle par les adeptes au poste,
## avec les ingrédients du coffre bleu (sim/production.gd).
static func can_craft(b: Building, item: String) -> bool:
	return not GameState.ended and b != null and GameState.buildings.has(b) and b.complete \
		and Recipes.RECIPES.get(b.type, {}).has(item)


## Choisit (ou arrête) la recette fabriquée en boucle.
func craft(b: Building, item: String) -> void:
	production.select_recipe(b, item)


## Vider le coffre rouge : l'Ingénieur rapporte son contenu au stock.
func collect_output(b: Building) -> void:
	if not production.order_collect(b):
		say("Le coffre rouge est vide." if b and b.output_box.all(func(s: Dictionary) -> bool: return s.is_empty()) else "Aucun Ingénieur disponible.", 2.0)


## Bâtiment servi : l'unité sélectionnée y prend un poste (clic droit).
func order_staff(b: Building) -> bool:
	return production.assign(b)


## spawnTrained : le combattant sort devant la caserne.
func spawn_trained(b: Building, id: String) -> void:
	var u := spawn(Catalog.ADEPT[id]["name"], b.x, b.z + b.half() + 1.0, id)
	u.power = 4.0
	u.hp = Catalog.ADEPT[id]["hp"] * 4.0
	u.max_hp = u.hp
	u.tx = u.x
	u.tz = u.z + 3.0
	clamp_world(u)
	if b.rally_point != null:
		u.tx = b.rally_point.x
		u.tz = b.rally_point.y
		u.force_move = true
	GameState.menace += 4
	say("%s sort de la caserne." % Catalog.ADEPT[id]["name"], 2.0)


## onUnitDeath : une unité tombée (hors Ingénieur) rejoint les âmes que le Puits peut rappeler.
func on_unit_death(u: Unit) -> void:
	if u.role == "engineer":
		return
	cancel_work(u)
	u.force_move = false
	GameState.selected.erase(u)
	if u.squad_capacity > 0 and squad_survivors(u).is_empty():
		GameState.fallen = GameState.fallen.filter(func(f: Unit) -> bool: return f.squad != u.squad)
		return
	if not GameState.fallen.has(u):
		GameState.fallen.append(u)
	var well := GameState.buildings.any(func(b: Building) -> bool: return b.type == "soulwell" and b.complete)
	say("%s est tombé%s" % [u.name, " · le Puits des Âmes peut le rappeler." if well else "."], 2.5)


## reviveUnit : l'unité revient devant le Puits, avec son niveau et son expérience (coût initial × niveau en Vie).
func revive_unit(b: Building, u: Unit) -> void:
	if GameState.ended or b == null or not GameState.buildings.has(b) or b.type != "soulwell" or not b.complete or not revivable(u):
		return
	if Production.idle(b):
		say("Le Puits des Âmes est à l’arrêt : il faut un adepte de Medeina au poste.", 3.0)
		return
	var cost := Catalog.revive_cost(u)
	if not Catalog.can_pay(cost):
		say("Résurrection : %s requis." % Catalog.cost_text(cost), 3.0)
		return
	Catalog.pay(cost)
	GameState.fallen.erase(u)
	var h := b.half()
	u.hp = u.max_hp
	u.dead = false
	u.x = b.x
	u.z = b.z + h + 1.0
	u.tx = b.x
	u.tz = b.z + h + 3.5
	u.memo.clear()
	u.attack = 0.0
	u.stance = "attack"
	if not state().walkable(u.x, u.z):
		var q := state().push_out_of_rock(u.pos())
		u.x = q.x
		u.z = q.y
	if not GameState.units.has(u):
		GameState.units.append(u)
	if u.squad_capacity > 0:
		u.rejoining = true
		if GameState.selected.any(func(member: Unit) -> bool: return member.squad == u.squad):
			GameState.selected.append(u)
		update_squads()
	# Retour visuel : bulle du Puits qui devient l'unité (ReviveFx), à la place de l'onde et de l'éclair.
	u.revived_at = GameState.sim_time
	u.revived_from = Vector2(b.x, b.z)
	say("%s revient du Puits des Âmes · niveau %d." % [u.name, Catalog.lvl(u)], 3.0)


static func adept_mining_seconds(u: Unit) -> float:
	return 2.0 if u.role == "aether" else 4.0


static func can_mine(u: Unit) -> bool:
	return u.role != "engineer" or not u.unarmored or GameState.research_done.has("mining_artifact")


static func research_requirements_met(id: String) -> bool:
	if not Catalog.RESEARCH.has(id):
		return false
	for required: String in Catalog.RESEARCH[id]["requires"]:
		if not GameState.research_done.has(required):
			return false
	return true


static func can_research(b: Building, id: String) -> bool:
	return not GameState.ended and b != null and GameState.buildings.has(b) and b.complete \
		and Catalog.RESEARCH.has(id) and Catalog.RESEARCH[id]["building"] == b.type \
		and not GameState.research_done.has(id) and not GameState.research_jobs.has(id) \
		and research_requirements_met(id) and Catalog.can_pay(Catalog.MINING_COST)


func start_research(b: Building, id: String) -> void:
	if not can_research(b, id):
		return
	Catalog.pay(Catalog.MINING_COST)
	GameState.research_jobs[id] = {"building": b, "progress": 0.0}


func update_research(dt: float) -> void:
	for id: String in GameState.research_jobs.keys():
		var job: Dictionary = GameState.research_jobs[id]
		if not GameState.buildings.has(job["building"]) or not job["building"].complete:
			continue
		# Recherche à la vitesse du personnel au poste (à l'arrêt sans personne).
		job["progress"] = minf(Catalog.RESEARCH_TIME, job["progress"] + dt * Production.speed(job["building"]))
		if job["progress"] < Catalog.RESEARCH_TIME:
			continue
		GameState.research_jobs.erase(id)
		GameState.research_done[id] = true
		GameState.menace += Catalog.RESEARCH_MENACE
		if id == "mining_artifact":
			for u in GameState.units:
				if u.role == "engineer" and u.alive():
					engineer_spoke.emit(u, "Ce sceau devrait ne faire qu'une bouchée de ces murs en pierre.")
					break


## Offrande réutilisable de l’Ancre : paiement atomique, sans recharge.
static func can_offer_menace() -> bool:
	return not GameState.ended and GameState.orb_active and Catalog.can_pay(Catalog.ANCHOR_MENACE_COST)


func offer_menace() -> void:
	if not can_offer_menace():
		return
	Catalog.pay(Catalog.ANCHOR_MENACE_COST)
	GameState.menace += Catalog.ANCHOR_MENACE_GAIN


## Revenus des unités effectivement en prière.
static func resource_rates() -> Dictionary:
	var rates := {}
	for resource: String in Catalog.RES_ORDER:
		rates[resource] = 0
	if GameState.ended:
		return rates
	for u: Unit in GameState.units:
		if not u.alive() or u.hidden or not u.working or u.job == null:
			continue
		if u.job.get("type") == "anchor_pray" and GameState.orb_active:
			for resource: String in Catalog.RES_ORDER:
				rates[resource] += ANCHOR_PRAY
		if u.job.get("type") != "pray":
			continue
		var temple: Building = u.job.get("temple")
		if temple != null and temple.complete and GameState.buildings.has(temple) and temple.is_temple():
			rates[Catalog.DEITY_RES[temple.def()["deity"]]] += pray_rate(u, temple)
	return rates


## Ressource par seconde d'une unité en prière : 1 pour un adepte, 5 pour l'Ingénieur. Un adepte de Sigil
## peut prier à un autel étranger : il y produit la ressource de ce dieu deux fois plus lentement.
static func pray_rate(u: Unit, temple: Building = null) -> float:
	if u.role == "engineer":
		return ENGINEER_PRAY
	if temple != null and u.role == "sigil" and temple.def()["deity"] != "sigil":
		return SIGIL_FOREIGN_RATE
	return 1.0


const SIGIL_FOREIGN_RATE := 0.5


## Un adepte peut prier à ce temple : celui de son dieu, ou n'importe lequel pour un adepte de Sigil.
static func can_pray_at(u: Unit, b: Building) -> bool:
	if b == null or not b.complete or not b.is_temple() or not Catalog.prays(u):
		return false
	return u.role == "sigil" or b.def()["deity"] == u.role


static func squad_survivors(u: Unit) -> Array[Unit]:
	var members: Array[Unit] = []
	for other: Unit in GameState.units:
		if other.squad == u.squad and other.alive() and not other.hidden:
			members.append(other)
	return members


static func expand_squads(units: Array[Unit]) -> Array[Unit]:
	var result: Array[Unit] = []
	for u: Unit in units:
		var group: Array[Unit] = []
		if u.squad_capacity > 0:
			group = squad_survivors(u)
		else:
			group.append(u)
		for member: Unit in group:
			if member.alive() and not member.hidden and not result.has(member):
				result.append(member)
	return result


static func revivable(u: Unit) -> bool:
	return u != null and not u.alive() and GameState.fallen.has(u) and (u.squad_capacity == 0 or not squad_survivors(u).is_empty())


static func squad_losses(u: Unit) -> Array[Unit]:
	var losses: Array[Unit] = []
	if u.squad_capacity > 0 and not squad_survivors(u).is_empty():
		for member: Unit in GameState.fallen:
			if member.squad == u.squad and revivable(member):
				losses.append(member)
	return losses


static func squad_revive_cost(u: Unit) -> Dictionary:
	var total := 0
	for member: Unit in squad_losses(u):
		total += int(Catalog.revive_cost(member)["vie"])
	return {"vie": total}


static func life_well() -> Building:
	for b: Building in GameState.buildings:
		if b.type == "soulwell" and b.complete:
			return b
	return null


func revive_squad(u: Unit) -> void:
	var well := life_well()
	var losses := squad_losses(u)
	if GameState.ended or well == null or losses.is_empty() or not Catalog.can_pay(squad_revive_cost(u)):
		return
	for member: Unit in losses:
		revive_unit(well, member)


func update_squads() -> void:
	var leaders := {}
	for u: Unit in GameState.units:
		if u.squad_capacity > 0 and u.alive() and not u.hidden and not u.rejoining and not leaders.has(u.squad):
			leaders[u.squad] = u
	# Si le dernier vétéran tombe pendant un ralliement, un renfort vivant prend la tête.
	for u: Unit in GameState.units:
		if u.squad_capacity > 0 and u.alive() and not u.hidden and not leaders.has(u.squad):
			leaders[u.squad] = u
			u.rejoining = false
	for u: Unit in GameState.units:
		if u.squad_capacity == 0 or not u.alive() or not leaders.has(u.squad):
			continue
		var leader: Unit = leaders[u.squad]
		if u == leader:
			continue
		var distance := u.pos().distance_to(leader.pos())
		if distance > 10.0:
			u.rejoining = true
		if u.rejoining:
			if distance < 3.0:
				u.rejoining = false
				u.force_move = false
				u.stance = leader.stance
			else:
				u.tx = leader.x + (u.id % 2 - 0.5) * 1.5
				u.tz = leader.z + 1.5
				u.force_move = true
				u.stance = "attack"
