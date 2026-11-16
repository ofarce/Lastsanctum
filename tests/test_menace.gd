extends "res://tests/fight_case.gd"


func test_wave_scaling_and_snapshot() -> void:
	var sim := game()
	for sample: Array in [[0, 3, 13, 1.0, 0], [300, 3, 19, 1.12, 0], [1000, 3, 33, 1.4, 2], [1500, 6, 52, 1.6, 3]]:
		GameState.menace = sample[0]
		GameState.wave = sample[1] - 1
		sim.combat.start_wave()
		check_eq(GameState.spawn_queue.size(), sample[2], "effectif à menace %d" % sample[0])
		var queued: Dictionary = GameState.spawn_queue[-1]
		GameState.menace = 9900
		var e := sim.combat.spawn_enemy(queued)
		check_near(e.max_hp, Catalog.ENEMY[e.kind]["hp"] * sample[3], 1e-6, "PV figés au lancement")
		check_near(e.damage, Catalog.ENEMY[e.kind]["damage"] * (1.0 + 0.02 * Catalog.menace_tier(sample[0])), 1e-6, "dégâts")
		check_near(e.armor, Catalog.ENEMY[e.kind].get("armor", 0) + sample[4], 1e-6, "armure")
		check_near(GameState.spawn_queue[1]["at"] - GameState.spawn_queue[0]["at"], maxf(0.35, 1.5 - sample[1] * 0.14), 1e-6, "cadence inchangée")


func test_composition_and_champions() -> void:
	check_eq(Combat.wave_kind(2, 3, 18, 400), "archer", "composition avancée à vague 4")
	for sample: Array in [[999, 1], [1000, 1], [1499, 1], [1500, 2], [2000, 3]]:
		var champions := 0
		for i in 70:
			if Combat.wave_kind(8, i, 70, sample[0]) == "strazhar":
				champions += 1
		check_eq(champions, sample[1], "champions à menace %d" % sample[0])
	check_eq(Combat.wave_kind(1, 0, 7, 1000), "strazhar", "seuil historique")
	check_eq(Catalog.menace_tier(99), 0, "avant premier palier")
	check_eq(Catalog.menace_tier(100), 1, "premier palier")


func test_portals_follow_current_menace() -> void:
	var sim := game()
	var p: Dictionary = sim.state().portals[0]
	p["active"] = true
	for sample: Array in [[0, 7.0, 8, 1.0, 1.0], [300, 5.95, 11, 1.24, 1.15], [1000, 3.5, 16, 1.8, 1.5], [1500, 3.5, 16, 2.2, 1.75]]:
		GameState.enemies.clear()
		GameState.menace = sample[0]
		p["next"] = GameState.sim_time
		sim.combat.update_evil_portals()
		var e: Enemy = GameState.enemies[-1]
		check_near(e.max_hp, 22.0 * sample[3], 1e-6, "PV rejeton")
		check_near(e.damage, 4.0 * sample[4], 1e-6, "dégâts rejeton")
		check_near(p["next"] - GameState.sim_time, sample[1], 1e-6, "intervalle")
		for i in 20:
			GameState.sim_time = p["next"]
			sim.combat.update_evil_portals()
		check_eq(GameState.enemies.size(), sample[2], "plafond par portail")


func test_hud_explains_tier() -> void:
	var sim := game()
	GameState.menace = 1500
	var view := HudModel.view(sim)
	check_eq(view["menace"], "1500", "compteur conservé")
	check(view["menace_tooltip"].contains("palier 15"), "palier dans l’infobulle")
	check(view["menace_tooltip"].contains("+30 ennemis"), "effectif dans l’infobulle")
	check(view["menace_tooltip"].contains("16 créatures"), "plafond dans l’infobulle")


func test_portal_escalation_keeps_existing_stats_and_no_menace_reward() -> void:
	var sim := game()
	var p: Dictionary = sim.state().portals[0]
	p["active"] = true
	p["next"] = GameState.sim_time
	sim.combat.update_evil_portals()
	var original: Enemy = GameState.enemies[-1]
	GameState.menace = 1000
	GameState.sim_time = p["next"]
	sim.combat.update_evil_portals()
	var reinforced: Enemy = GameState.enemies[-1]
	check_near(original.max_hp, 22.0, 1e-6, "ancien rejeton inchangé")
	check_near(reinforced.max_hp, 39.6, 1e-6, "nouveau rejeton renforcé")
	check_near(p["next"] - GameState.sim_time, 3.5, 1e-6, "nouvelle cadence")
	reinforced.hp = 0.0
	sim.combat.finish_tick(0.0, GameState.units)
	check_eq(GameState.menace, 1000, "aucune menace pour un rejeton tué")
