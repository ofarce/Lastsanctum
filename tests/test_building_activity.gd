extends "res://tests/econ_case.gd"


func test_anchor_offering_cost_reuse_and_disabled_states() -> void:
	var sim := game()
	give(300)
	sim.offer_menace()
	check_eq(GameState.menace, 0, "Ancre éteinte")
	GameState.orb_active = true
	GameState.anchor_selected = true
	var actions := HudModel.panel_actions(sim)
	var offer: Dictionary = actions.filter(func(a: Dictionary) -> bool: return a["id"] == "offering")[0]
	check(not offer["disabled"], "action disponible")
	offer["run"].call()
	sim.offer_menace()
	check_eq(GameState.menace, 100, "deux utilisations immédiates")
	for resource: String in Catalog.RES_ORDER:
		check_eq(GameState.res[resource], 100.0, "coût par ressource")
	GameState.res["vie"] = 99
	sim.offer_menace()
	check_eq(GameState.res["forge"], 100.0, "paiement refusé atomiquement")
	check_eq(GameState.menace, 100, "pas de gain sans fonds")
	give(200)
	GameState.ended = true
	sim.offer_menace()
	check_eq(GameState.menace, 100, "pas après fin de partie")


func test_income_rates_count_only_current_producers() -> void:
	var sim := game()
	check_eq(Simulation.resource_rates()["savoir"], 0, "Ancre éteinte")
	GameState.orb_active = true
	var temple := built("sigil", 15, -130)
	var u := Unit.create(100, "Prieur", 15, -130, "sigil")
	u.job = {"type": "pray", "temple": temple}
	GameState.units.append(u)
	check_eq(Simulation.resource_rates()["savoir"], 1, "en déplacement : Ancre seule")
	u.working = true
	check_eq(Simulation.resource_rates()["savoir"], 2, "Ancre et prieur")
	check_eq(HudModel.view(sim)["resource_rates"]["forge"], 1, "revenus transmis au HUD")
	u.hp = 0
	check_eq(Simulation.resource_rates()["savoir"], 1, "prieur mort exclu")


func test_simultaneous_research_and_training_progress() -> void:
	var sim := game()
	give(1000)
	var barracks := built("caserne", 15, -130)
	sim.start_research(barracks, "mining_power")
	sim.train_unit(barracks, "archer")
	sim.update_buildings(3.0)
	var jobs := WorldOverlay.building_jobs(barracks)
	check_eq(jobs.size(), 2, "deux activités simultanées")
	check_eq(jobs[0]["icon"], "mining_seal", "icône recherche")
	check_near(jobs[0]["progress"], 0.3)
	check_eq(jobs[1]["icon"], "bow", "icône unité")
	check_near(jobs[1]["progress"], 0.5)
	sim.update_buildings(7.0)
	check(WorldOverlay.building_jobs(barracks).is_empty(), "indicateurs retirés à la fin")


func test_strazhar_stats_applied_to_spawned_enemy() -> void:
	var e := Enemy.make("strazhar", 0, -130, 0)
	check_eq(e.hp, 450.0, "PV triplés")
	check_eq(e.max_hp, 450.0, "PV maximum")
	check_near(e.speed, 8.4, 0.00001, "vitesse doublée")
