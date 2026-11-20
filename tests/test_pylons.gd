extends "res://tests/fight_case.gd"
## Pylônes de Merenor (sim/pylons.gd) : ils remplacent les portails maléfiques. Meute et alpha, renaissance
## en une minute, canalisation par un esprit de chaque dieu, rupture, corruption qui ne ronge que l'Ingénieur.


## Partie de référence, pylône le plus proche de la salle éveillé (galerie découverte, premier tick).
func _awake(sim: Simulation) -> Dictionary:
	var st := sim.state()
	var p: Dictionary = st.portals[0]
	for q: Dictionary in st.portals:
		if Vector2(q["x"], q["z"]).length() < Vector2(p["x"], p["z"]).length():
			p = q
	sim.world.terrain_ops.reveal_gallery(p["x"], p["z"])
	Pylons.tick(sim, DT)
	return p


func _guards(p: Dictionary) -> Array:
	return GameState.enemies.filter(func(e: Enemy) -> bool: return e.pylon == p and e.hp > 0.0)


## Avance les pylônes seuls (ni combat ni déplacements) de `seconds`.
func _advance(sim: Simulation, seconds: float) -> void:
	for i in roundi(seconds / DT):
		GameState.sim_time += DT
		Pylons.tick(sim, DT)


func _pray(sim: Simulation, p: Dictionary, roles: Array) -> Array[Unit]:
	var out: Array[Unit] = []
	for r: String in roles:
		var u := sim.spawn("Esprit", p["x"], p["z"] + 8.0, r)
		sim.set_job(u, {"type": "pray_pylon", "pylon": p})
		var spot := Pylons.prayer_spot(sim.state(), u, p)
		u.x = spot.x
		u.z = spot.y
		out.append(u)
	sim.update_adepts(DT)
	return out


func test_pylons_replace_portals() -> void:
	var sim := game()
	var st := sim.state()
	check(not st.portals.is_empty(), "un pylône par réseau")
	for p: Dictionary in st.portals:
		check(st.pylon_at(p["x"] - 2.0, p["z"] - 2.0) and st.pylon_at(p["x"] + 2.0, p["z"] + 2.0), "socle de 2 × 2 cases")
		check(not st.walkable(p["x"] - 1.0, p["z"] - 1.0), "socle infranchissable")
		check(fmod(absf(p["x"]), 4.0) == 0.0 and fmod(absf(p["z"]), 4.0) == 0.0, "centre sur un coin de case")
		check(st.is_gallery(p["x"] + 6.0, p["z"]) and st.is_gallery(p["x"] - 6.0, p["z"]), "salle creusée autour")


func test_wake_pack_and_alpha() -> void:
	var sim := game()
	var p := _awake(sim)
	check(p["active"], "éveillé à la découverte de la galerie")
	var guards := _guards(p)
	check(guards.size() >= Pylons.PACK_MIN and guards.size() <= Pylons.PACK_MAX, "meute de 4 à 6 (%d)" % guards.size())
	var alphas := guards.filter(func(e: Enemy) -> bool: return e.alpha)
	check_eq(alphas.size(), 1, "un seul alpha")
	var plain: Enemy = guards.filter(func(e: Enemy) -> bool: return not e.alpha)[0]
	var alpha: Enemy = alphas[0]
	check_near(alpha.max_hp, plain.max_hp * Pylons.ALPHA, 1e-6, "alpha : PV doublés")
	check_near(alpha.damage, plain.damage * Pylons.ALPHA, 1e-6, "alpha : dégâts doublés")
	for e: Enemy in guards:
		check(e.beast, "hors menace et fin de vague")
		check(sim.state().walkable(e.x, e.z), "gardien hors de la roche")


func test_respawn_after_a_minute() -> void:
	var sim := game()
	var p := _awake(sim)
	var n := _guards(p).size()
	var dead: Enemy = _guards(p)[0]
	dead.hp = 0.0
	_advance(sim, DT)
	var tm := Pylons.timer(p)
	check_near(tm["rem"], Pylons.RESPAWN, 0.05, "minuteur d'une minute")
	check_eq(tm["waiting"], 0, "une seule bête en attente")
	_advance(sim, Pylons.RESPAWN - 1.0)
	check_eq(_guards(p).size(), n - 1, "pas encore revenue")
	_advance(sim, 1.1)
	check_eq(_guards(p).size(), n, "renaît au bout d'une minute")
	check(Pylons.timer(p).is_empty(), "plus de minuteur")
	check(_guards(p).all(func(e: Enemy) -> bool: return e != dead), "nouvelle bête")


func test_channel_needs_one_spirit_of_each_god() -> void:
	var sim := game()
	var p := _awake(sim)
	_pray(sim, p, ["aether", "indra", "medeina", "medeina"])
	_advance(sim, DT)
	check(not p["channeled"], "trois dieux seulement : pas canalisé")
	check_eq((p["praying"] as Array).size(), 3, "trois cultes en prière")
	var sigil := _pray(sim, p, ["sigil"])
	_advance(sim, DT)
	check(p["channeled"], "un esprit de chaque dieu : canalisé")
	_advance(sim, Pylons.COVER_TIME + 0.1)
	check_eq(p["cover"], 0.0, "la nappe s'est retirée")
	# Canalisé : une bête tuée ne revient pas, même longtemps après.
	(_guards(p)[0] as Enemy).hp = 0.0
	var n := _guards(p).size() - 1
	_advance(sim, Pylons.RESPAWN * 2.0)
	check_eq(_guards(p).size(), n, "aucune renaissance quand il est canalisé")
	check(Pylons.timer(p).is_empty(), "pas de minuteur")
	# Rupture : l'esprit de Sigil s'en va, le cycle reprend pour une minute.
	sigil[0].job = null
	sim.update_adepts(DT)
	_advance(sim, DT)
	check(not p["channeled"], "rupture")
	check_near(Pylons.timer(p)["rem"], Pylons.RESPAWN, 0.05, "minuteur repart d'une minute")
	_advance(sim, Pylons.COVER_TIME + 0.1)
	check_eq(p["cover"], 1.0, "la nappe revient")
	_advance(sim, Pylons.RESPAWN)
	check_eq(_guards(p).size(), n + 1, "renaissance après la rupture")


## Un point de la nappe sur du sol praticable, hors du socle.
func _corrupted_spot(sim: Simulation, p: Dictionary) -> Vector2:
	for r in range(5, 14):
		for k in 16:
			var q := Vector2(p["x"], p["z"]) + Vector2.from_angle(k * TAU / 16.0) * r
			if Pylons.corrupted(sim.state(), q.x, q.y) and sim.state().walkable(q.x, q.y):
				return q
	return Vector2.INF


func test_corruption_hurts_only_the_engineer() -> void:
	var sim := game()
	var p := _awake(sim)
	for e: Enemy in _guards(p):
		e.hp = 0.0
	var q := _corrupted_spot(sim, p)
	check(q != Vector2.INF, "un point corrompu praticable")
	if q == Vector2.INF:
		return
	var eng := engineer()
	eng.x = q.x
	eng.z = q.y
	var spirit := sim.spawn("Esprit", q.x, q.y, "medeina")
	var hp0 := eng.hp
	var hs := spirit.hp
	_advance(sim, 3.0 + DT)
	check_near(eng.hp, hp0 - 3.0 * Pylons.CORRUPTION_DPS, 1e-6, "1 PV par seconde")
	check_eq(spirit.hp, hs, "adeptes immunisés")
	p["cover"] = 0.0
	p["channeled"] = true
	var hp1 := eng.hp
	eng.memo.erase("corruption")
	Pylons._corrode(sim, 2.0)
	check_eq(eng.hp, hp1, "plus de corruption une fois retirée")


func test_order_pylon_sends_spirits() -> void:
	var sim := game()
	var p := _awake(sim)
	var a := sim.spawn("Esprit", p["x"] + 10.0, p["z"] + 10.0, "aether")
	GameState.selected = [a, engineer()]
	check(sim.order_pylon(Vector2(p["x"], p["z"])), "clic droit sur le pylône")
	check(a.job != null and a.job["type"] == "pray_pylon" and a.job["pylon"] == p, "l'esprit va prier")
	check(engineer().job == null or engineer().job.get("type") != "pray_pylon", "l'Ingénieur ne prie pas au pylône")
	check(not sim.order_pylon(Vector2(p["x"] + 40.0, p["z"] + 40.0)), "hors du pylône : pas d'ordre")


func test_engineer_blessing_delays_respawn() -> void:
	var sim := game()
	var p := _awake(sim)
	var dead: Enemy = _guards(p)[0]
	dead.hp = 0.0
	_advance(sim, DT)
	var n := _guards(p).size()
	# L'Ingénieur incarné, loin du socle : E ne bénit pas ; collé au socle (bord sud) : E lance la bénédiction.
	var eng := engineer()
	GameState.incarnated = eng
	eng.x = float(p["x"]) + 20.0
	eng.z = float(p["z"]) + 20.0
	check(not Pylons.toggle_bless(sim), "loin du socle : rien")
	eng.x = float(p["x"])
	eng.z = float(p["z"]) + 4.6
	eng.hp = eng.max_hp
	check(Pylons.toggle_bless(sim), "E au contact du socle")
	check_eq(eng.job["type"], "bless_pylon", "il bénit")
	check_eq(Pylons.bless_spot(sim.state(), p, eng.job), Vector2(eng.x, eng.z), "sur place")
	for i in roundi(10.0 / DT):
		sim.update_adepts(DT)
		GameState.sim_time += DT
		Pylons.tick(sim, DT)
	check_near(p["blessing"], 10.0, 0.05, "10 s de prière : 10 s de répit")
	var rem := float(Pylons.timer(p)["rem"])
	check_near(rem, Pylons.RESPAWN - 10.0, 0.1, "le minuteur court pendant la prière")
	# Il s'arrête (E de nouveau) : le répit s'écoule, le minuteur est gelé.
	check(Pylons.toggle_bless(sim), "E arrête la bénédiction")
	check(eng.job == null, "plus de prière")
	sim.update_adepts(DT)
	_advance(sim, 5.0)
	check_near(p["blessing"], 5.0, 0.05, "le répit s'écoule")
	check_near(float(Pylons.timer(p)["rem"]), rem, 0.05, "renaissance gelée pendant le répit")
	# Sans bénédiction la bête serait revenue à 60 s ; elle revient 10 s plus tard.
	_advance(sim, rem + 5.0 - 0.5)
	check_eq(_guards(p).size(), n, "pas encore revenue")
	_advance(sim, 1.0)
	check_eq(_guards(p).size(), n + 1, "revenue avec 10 s de retard")
	check_eq(p["blessing"], 0.0, "répit épuisé")


func test_spirits_channel_within_three_cells() -> void:
	var sim := game()
	var p := _awake(sim)
	var a := sim.spawn("Esprit", float(p["x"]) + 4.0 + 20.0, float(p["z"]), "aether")
	GameState.selected = [a]
	check(sim.channel_pylon(p), "clic droit sur le pylône")
	sim.update_adepts(DT)
	var spot := Pylons.prayer_spot(sim.state(), a, p)
	check_eq(Vector2(a.tx, a.tz), spot, "il gagne sa place de la planche")
	check(spot.x < float(p["x"]) and spot.y < float(p["z"]), "Aether au nord-ouest")
	check(Pylons.socle_distance(p, spot) <= Pylons.CHANNEL_REACH, "place à 3 cases du socle au plus")
	check(not a.working, "en route : pas encore")
	a.x = spot.x
	a.z = spot.y
	sim.update_adepts(DT)
	check(a.working, "arrivé : canalise")
	_advance(sim, DT)
	check_eq(p["praying"], ["aether"], "un culte en prière")
