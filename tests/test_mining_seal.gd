extends "res://tests/econ_case.gd"


func test_research_cost_duration_prerequisites_and_unique_completion() -> void:
	var sim := game()
	give(100.0)
	var forge := built("forge", 0, -130)
	check(not Simulation.can_research(forge, "mining_artifact"), "artefact verrouillé sans prérequis")
	for id: String in ["mining_concept", "mining_spark", "mining_power"]:
		var b := built(Catalog.RESEARCH[id]["building"], 10, -130)
		sim.start_research(b, id)
		sim.start_research(b, id)
		check_eq(GameState.research_jobs.size(), 1, "pas de recherche en double")
		sim.update_research(9.9)
		check(not GameState.research_done.has(id), "pas achevée avant dix secondes")
		var menace := GameState.menace
		sim.update_research(0.1)
		check(GameState.research_done.has(id), "recherche achevée")
		check_eq(GameState.menace, menace + 20, "+20 menace à la fin")
		check(not Simulation.can_research(b, id), "recherche unique")
	check(Simulation.can_research(forge, "mining_artifact"), "artefact déverrouillé")
	var spoken: Array = []
	sim.engineer_spoke.connect(func(_u: Unit, text: String) -> void: spoken.append(text))
	engineer().unarmored = true
	check(not Simulation.can_mine(engineer()), "sans armure ni sceau, minage impossible")
	sim.start_research(forge, "mining_artifact")
	for resource: String in Catalog.RES_ORDER:
		check_near(GameState.res[resource], 60.0, 1e-9, "quatre recherches coûtent 40 par ressource")
	sim.update_research(10.0)
	check(Simulation.can_mine(engineer()), "sceau rétablit le minage sans armure")
	check_eq(GameState.menace, 80, "80 menace pour les quatre recherches")
	check_eq(spoken, ["Ce sceau devrait ne faire qu'une bouchée de ces murs en pierre."], "réplique de fabrication")
	GameState.selected.clear()
	GameState.hud_building = forge
	var action := HudModel.panel_actions(sim)[0]
	check(action["disabled"], "recherche terminée grisée")
	check(action["completed"], "statut vert")
	check_eq(action["status"], "Déjà achevée", "libellé achevé")
	sim.new_game(SEED)
	check(GameState.research_done.is_empty() and GameState.research_jobs.is_empty(), "recherches réinitialisées")


func test_unarmored_engineer_cannot_start_or_continue_mining() -> void:
	var sim := game()
	var u := engineer()
	check(Simulation.can_mine(u), "armure initiale permet de miner")
	u.unarmored = true
	var spoken: Array = []
	sim.engineer_spoke.connect(func(_u: Unit, text: String) -> void: spoken.append(text))
	GameState.selected = [u]
	check(sim.order_adepts(Vector2(64, -138)), "clic droit minage intercepté")
	check(u.job == null, "clic droit sans sceau refusé")
	spoken.clear()
	sim.set_job(u, {"type": "dig"})
	check(u.job == null, "ordre de minage refusé")
	check_eq(spoken, ["Impossible. Je n'ai pas mon sceau de minage."], "réplique sans sceau")
	u.job = {"type": "dig"}
	sim.update_adepts(1.0)
	check(u.job == null and not u.working, "minage en cours interrompu sans armure")
