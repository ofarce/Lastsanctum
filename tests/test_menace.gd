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
		# Escouades : chacune sort d'un bloc, l'écart entre elles est réglé par la tactique (tactics.ready).
		check_eq(GameState.wave_squads, ceili(sample[2] / 7.0), "escouades de sept au plus")
		check_near(GameState.spawn_queue[1]["at"], GameState.spawn_queue[0]["at"], 1e-6, "sortie groupée")


func test_composition_and_champions() -> void:
	var advanced := range(18).map(func(i: int) -> String: return Combat.wave_kind(2, i, 18, 400))
	var plain := range(18).map(func(i: int) -> String: return Combat.wave_kind(2, i, 18, 0))
	check(advanced.has("archer") and not plain.has("archer"), "composition avancée à vague 4")
	for sample: Array in [[999, 1], [1000, 1], [1499, 1], [1500, 2], [2000, 3]]:
		var champions := 0
		for i in 70:
			if Combat.wave_kind(8, i, 70, sample[0]) == "strazhar":
				champions += 1
		check_eq(champions, sample[1], "champions à menace %d" % sample[0])
	check_eq(Combat.wave_kind(1, 6, 7, 1000), "strazhar", "seuil historique : champion en serre-file")
	check_eq(Catalog.menace_tier(99), 0, "avant premier palier")
	check_eq(Catalog.menace_tier(100), 1, "premier palier")


## Gardien ordinaire (pas l'alpha) d'une place de la meute qui vient de renaître.
func _respawned_guard(sim: Simulation, p: Dictionary) -> Enemy:
	var slot: Dictionary = p["slots"][0]
	var e: Enemy = slot["enemy"]
	e.hp = 0.0
	Pylons.tick(sim, DT)
	GameState.sim_time += Pylons.RESPAWN
	Pylons.tick(sim, DT)
	return slot["enemy"]


func _awake_pylon(sim: Simulation) -> Dictionary:
	var p: Dictionary = sim.state().portals[0]
	p["active"] = true
	p["threat"] = 1
	Pylons.tick(sim, DT)
	return p


func test_pylon_guards_follow_current_menace() -> void:
	var sim := game()
	var p := _awake_pylon(sim)
	for sample: Array in [[0, 1.0, 1.0], [300, 1.24, 1.15], [1000, 1.8, 1.5], [1500, 2.2, 1.75]]:
		GameState.menace = sample[0]
		var e := _respawned_guard(sim, p)
		check(e != null and not e.alpha, "gardien renaît")
		check_near(e.max_hp, 22.0 * sample[1], 1e-6, "PV du gardien")
		check_near(e.damage, 4.0 * sample[2], 1e-6, "dégâts du gardien")


func test_hud_explains_tier() -> void:
	var sim := game()
	GameState.menace = 1500
	var view := HudModel.view(sim)
	check_eq(view["menace"], "1500", "compteur conservé")
	check(view["menace_tooltip"].contains("palier 15"), "palier dans l’infobulle")
	check(view["menace_tooltip"].contains("+30 ennemis"), "effectif dans l’infobulle")
	check(view["menace_tooltip"].contains("Pylônes de Merenor"), "pylônes dans l’infobulle")


func test_pylon_escalation_keeps_existing_stats_and_no_menace_reward() -> void:
	var sim := game()
	GameState.menace = 0
	var p := _awake_pylon(sim)
	var original: Enemy = p["slots"][1]["enemy"]
	GameState.menace = 1000
	var reinforced := _respawned_guard(sim, p)
	check_near(original.max_hp, 22.0 * (Pylons.ALPHA if original.alpha else 1.0), 1e-6, "gardien en place inchangé")
	check_near(reinforced.max_hp, 39.6, 1e-6, "gardien renaissant renforcé")
	reinforced.hp = 0.0
	sim.combat.finish_tick(0.0, GameState.units)
	check_eq(GameState.menace, 1000, "aucune menace pour un gardien tué")
