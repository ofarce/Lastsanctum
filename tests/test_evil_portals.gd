extends "res://tests/fight_case.gd"
## Étape 8 (v2) : portails maléfiques (un rejeton toutes les 7 s, 8 au plus par portail).


func test_spawn_interval_and_cap() -> void:
	var sim := game()
	var p: Dictionary = sim.state().portals[0]
	p["active"] = true
	p["next"] = GameState.sim_time
	sim.combat.update_evil_portals()
	var beasts := func() -> Array: return GameState.enemies.filter(func(e: Enemy) -> bool: return e.portal == p)
	check_eq(beasts.call().size(), 1, "premier rejeton")
	check_near(p["next"], GameState.sim_time + 7.0, 1e-9, "suivant dans 7 s")
	var e0: Enemy = beasts.call()[0]
	check(e0.beast and e0.max_hp == 22.0, "rejeton : 22 PV")
	check(sim.state().walkable(e0.x, e0.z), "hors de la roche")
	for i in 12:
		GameState.sim_time = p["next"]
		sim.combat.update_evil_portals()
	check_eq(beasts.call().size(), 8, "plafond de 8 rejetons")
	(beasts.call()[0] as Enemy).hp = 0.0
	GameState.sim_time = p["next"]
	sim.combat.update_evil_portals()
	check_eq(beasts.call().filter(func(e: Enemy) -> bool: return e.hp > 0.0).size(), 8, "un mort est remplacé")
