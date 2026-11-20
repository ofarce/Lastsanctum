extends "res://tests/econ_case.gd"


func test_seal_is_not_a_research_and_comes_from_the_capsule() -> void:
	var sim := game()
	for id: String in ["mining_concept", "mining_spark", "mining_power", "mining_artifact"]:
		check(not Catalog.RESEARCH.has(id), "plus de recherche " + id)
	check(not GameState.mining_seal, "pas de sceau en début de partie")
	engineer().unarmored = true
	check(not Simulation.can_mine(engineer()), "sans armure ni sceau, minage impossible")
	GameState.mining_seal = true
	check(Simulation.can_mine(engineer()), "sceau rétablit le minage sans armure")
	sim.new_game(SEED)
	check(not GameState.mining_seal, "sceau réinitialisé")


func test_unarmored_engineer_cannot_start_or_continue_mining() -> void:
	var sim := game()
	var u := engineer()
	check(Simulation.can_mine(u), "armure initiale permet de miner")
	u.unarmored = true
	var spoken: Array = []
	sim.engineer_spoke.connect(func(_u: Unit, text: String) -> void: spoken.append(text))
	GameState.selected = [u]
	check(sim.order_adepts(Vector2(58, -138)), "clic droit minage intercepté")
	check(u.job == null, "clic droit sans sceau refusé")
	spoken.clear()
	sim.set_job(u, {"type": "dig"})
	check(u.job == null, "ordre de minage refusé")
	check_eq(spoken, ["Impossible. Je n'ai pas mon sceau de minage."], "réplique sans sceau")
	u.job = {"type": "dig"}
	sim.update_adepts(1.0)
	check(u.job == null and not u.working, "minage en cours interrompu sans armure")
