extends "res://tests/econ_case.gd"
## File d'invocation des temples (2026-11-19) : une seule arrivée à la fois par autel, les invocations suivantes
## (déjà payées) attendent leur tour ; le panneau au-dessus du temple montre l'esprit qui naît puis la file.

const Overlay := preload("res://world/overlay/world_overlay.gd")


func _arrivals(t: Building) -> int:
	return GameState.units.filter(func(u: Unit) -> bool: return u.arrival_end > 0.0 and u.arrival_temple == t).size()


func test_one_arrival_at_a_time() -> void:
	var sim := game()
	var t := built("sigil", -26.0, -118.0)
	GameState.res["savoir"] = 30.0
	var n0 := GameState.units.size()
	for i in 3:
		sim.summon_adept(t)
	check_near(GameState.res["savoir"], 0.0, 1e-9, "trois invocations payées d'avance")
	check_eq(GameState.units.size(), n0 + 1, "un seul esprit à l'autel")
	check_eq(t.queue.size(), 2, "deux en file")
	var jobs := Overlay.building_jobs(t)
	check_eq(jobs.size(), 1, "un panneau au-dessus du temple")
	check_eq(jobs[0].get("portrait", ""), "sigil", "portrait de l'esprit qui naît")
	check_eq(jobs[0]["waiting"].size(), 2, "deux portraits en attente")
	run(sim, Simulation.ARRIVAL * 0.5)
	check_near(Overlay.building_jobs(t)[0]["progress"], 0.5, 0.02, "progression de l'arrivée")
	run(sim, Simulation.ARRIVAL * 0.5 + 0.1)
	check_eq(_arrivals(t), 1, "le suivant commence dès que l'autel se libère")
	check_eq(t.queue.size(), 1, "file raccourcie")
	run(sim, Simulation.ARRIVAL * 2.0 + 0.2)
	check_eq(GameState.units.size(), n0 + 3, "les trois esprits sont nés")
	check_eq(_arrivals(t), 0, "plus d'arrivée en cours")
	check(Overlay.building_jobs(t).is_empty(), "panneau retiré, file vide")


func test_queue_limit() -> void:
	var sim := game()
	var t := built("sigil", -26.0, -118.0)
	GameState.res["savoir"] = 1000.0
	for i in Catalog.TEMPLE_QUEUE + 3:
		sim.summon_adept(t)
	check_eq(t.queue.size(), Catalog.TEMPLE_QUEUE, "file de %d au plus" % Catalog.TEMPLE_QUEUE)
	check(not HudModel.can_summon_at(t), "bouton d'invocation grisé file pleine")
	check_near(GameState.res["savoir"], 1000.0 - 10.0 * (Catalog.TEMPLE_QUEUE + 1), 1e-6, "rien n'est payé au-delà")
