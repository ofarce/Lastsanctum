extends "res://tests/econ_case.gd"
## Étape 7 (v2) : Puits des Âmes. Les unités tombées (hors Ingénieur) peuvent revenir pour leur coût initial × niveau en Vie, avec leur
## niveau et leur expérience.


func test_passive_healing_range_and_limits() -> void:
	var sim := game()
	var well := built("soulwell", -30.0, -104.0)
	var near := sim.spawn("Archer", well.x + 8.0, well.z, "archer")
	var edge := sim.spawn("Archer", well.x, well.z + 12.0, "archer")
	var far := sim.spawn("Archer", well.x + 9.0, well.z + 9.0, "archer")
	var hidden := sim.spawn("Archer", well.x, well.z, "archer")
	var fallen := sim.spawn("Archer", well.x, well.z, "archer")
	for unit: Unit in [near, edge, far, hidden]:
		unit.hp = unit.max_hp - 20.0
	hidden.hidden = true
	fallen.hp = 0.0
	sim.update_buildings(0.5)
	check_near(near.hp, near.max_hp - 17.5, 1e-9, "soin proportionnel au temps")
	check_near(edge.hp, edge.max_hp - 17.5, 1e-9, "soin à la limite du rayon")
	check_eq(far.hp, far.max_hp - 20.0, "hors du rayon circulaire")
	check_eq(hidden.hp, hidden.max_hp - 20.0, "unité cachée exclue")
	check_eq(fallen.hp, 0.0, "aucune résurrection passive")
	sim.update_buildings(10.0)
	check_eq(near.hp, near.max_hp, "PV plafonnés")
	near.hp -= 20.0
	well.complete = false
	sim.update_buildings(1.0)
	check_eq(near.hp, near.max_hp - 20.0, "chantier sans soin")


func test_fallen_and_revive() -> void:
	var sim := game()
	var well := built("soulwell", -30.0, -104.0)
	var a := sim.spawn("Adepte archer", 0.0, -120.0, "archer")
	a.level = 3
	a.xp = 40.0
	a.hp = 0.0
	sim.on_unit_death(a)
	check(GameState.fallen.has(a), "âme en attente")
	sim.on_unit_death(engineer())
	check(not GameState.fallen.has(engineer()), "l'Ingénieur ne rejoint pas le Puits")
	GameState.res["vie"] = 150.0
	sim.revive_unit(well, a)
	check(GameState.fallen.has(a), "150 Vie : résurrection refusée")
	GameState.res["vie"] = 350.0
	sim.revive_unit(well, a)
	check(not GameState.fallen.has(a), "rappelé")
	check_near(GameState.res["vie"], 50.0, 1e-9, "100 × niveau 3 = 300 Vie payés")
	check(a.alive() and a.hp == a.max_hp, "PV pleins")
	check_eq(a.level, 3, "niveau conservé")
	check_eq(a.xp, 40.0, "expérience conservée")
	check(a.z > well.z, "devant le Puits : %s" % a.pos())
	check(sim.state().walkable(a.x, a.z), "sur un sol praticable")


func test_revive_actions_list() -> void:
	var sim := game()
	var well := built("soulwell", -30.0, -104.0)
	for i in 11:
		var a := sim.spawn("Adepte de Sigil", 0.0, -120.0, "sigil")
		a.hp = 0.0
		sim.on_unit_death(a)
	GameState.hud_building = well
	GameState.selected = []
	var acts := HudModel.panel_actions(sim).filter(func(action: Dictionary) -> bool: return action["id"].begins_with("revive-"))
	check_eq(acts.size(), 9, "9 âmes au plus dans le panneau")
	check_eq(acts[0]["id"], "revive-%d" % GameState.fallen[-1].id, "la plus récente d'abord")


func test_revive_cost_by_recruitment_and_level() -> void:
	game()
	for role: String in ["sigil", "aether", "medeina", "indra", "archer", "flammes", "lame", "shooter", "paladin", "healer"]:
		var u := Unit.create(100, role, 0, -120, role)
		var base := 50 if Catalog.DEITY_RES.has(role) else (100 if Catalog.ADEPT.has(role) else 400)
		for level in [1, 2, 5]:
			u.level = level
			check_eq(Catalog.revive_cost(u), {"vie": base * level}, "%s niveau %d" % [role, level])


func test_affordability_is_individual_and_payment_exact() -> void:
	var sim := game()
	var well := built("soulwell", -30, -104)
	var a := sim.spawn("Adepte de Sigil", 0, -120, "sigil")
	var b := sim.spawn("Archer", 0, -120, "archer")
	a.level = 2
	b.level = 3
	for u: Unit in [a, b]:
		u.hp = 0
		sim.on_unit_death(u)
	GameState.res["vie"] = 100
	GameState.hud_building = well
	GameState.selected.clear()
	var actions := HudModel.panel_actions(sim).filter(func(action: Dictionary) -> bool: return action["id"].begins_with("revive-"))
	check(actions[0]["disabled"], "archer 300 Vie indisponible")
	check(not actions[1]["disabled"], "adepte 100 Vie disponible")
	check(actions[1]["title"].contains("100 Vie"), "coût individuel dans infobulle")
	sim.revive_unit(well, b)
	check_eq(GameState.res["vie"], 100, "échec sans paiement partiel")
	sim.revive_unit(well, a)
	check_eq(GameState.res["vie"], 0, "paiement exact")
	check(a.alive() and GameState.fallen.has(b), "seule unité abordable ressuscitée")
	sim.revive_unit(well, a)
	check_eq(GameState.res["vie"], 0, "pas de paiement en double")
