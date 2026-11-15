extends "res://tests/fight_case.gd"
## Étape 8 (v2) : vagues (4 + 3w ennemis, types, instants, x = ±2), statistiques des ennemis, attente des
## ennemis hors rejetons avant la pause de 4 s.


func test_waves_match_js() -> void:
	var sim := game()
	var want: Array = js()["waves"]
	for w in 6:
		GameState.sim_time = 100.0
		GameState.wave = w
		sim.combat.start_wave()
		var got := GameState.spawn_queue.map(func(s: Dictionary) -> Dictionary: return {"at": r4(s["at"]), "x": s["x"], "kind": s["kind"]})
		check_eq(got.size(), want[w].size(), "vague %d : nombre" % (w + 1))
		for i in mini(got.size(), want[w].size()):
			check_near(got[i]["at"], want[w][i]["at"], 1e-6, "vague %d, ennemi %d : instant" % [w + 1, i])
			check_eq(got[i]["x"], float(want[w][i]["x"]), "vague %d, ennemi %d : x" % [w + 1, i])
			check_eq(got[i]["kind"], want[w][i]["kind"], "vague %d, ennemi %d : type" % [w + 1, i])


func test_enemy_stats_match_js() -> void:
	var sim := game()
	var want: Dictionary = js()["enemies"]
	for k: String in want:
		var e := sim.combat.spawn_enemy({"x": 2.0, "kind": k})
		check_eq([e.hp, e.max_hp, e.speed, e.reach, e.damage], [float(want[k]["hp"]), float(want[k]["max"]), float(want[k]["speed"]), float(want[k]["range"]), float(want[k]["damage"])], k)
		check(e.z >= 62.0 and e.z <= 66.0 and absf(e.x - 2.0) <= 1.6, "%s apparaît au sud : %s" % [k, e.pos()])


func test_first_wave_and_pause() -> void:
	var sim := game()
	GameState.orb_active = true
	GameState.sim_time = 50.0
	GameState.next_wave = 70.0
	run(sim, 19.9)
	check_eq(GameState.wave, 0, "pas d'assaut avant 20 s")
	run(sim, 0.2)
	check_eq(GameState.wave, 1, "premier assaut")
	check_eq(GameState.spawn_queue.size(), 7, "7 ennemis en file")
	# Un rejeton seul ne retient pas la vague suivante ; un rampant, si.
	GameState.spawn_queue.clear()
	GameState.enemies.clear()
	var e := Enemy.make("creep", 0.0, 60.0, 1.0)
	GameState.enemies.append(e)
	run(sim, 0.1)
	check_eq(GameState.next_wave, 0.0, "un ennemi reste : pas de pause")
	GameState.enemies.clear()
	var b := Enemy.make("beast", 100.0, 60.0, 1.0)
	GameState.enemies.append(b)
	run(sim, 0.1)
	check(GameState.next_wave > 0.0, "seuls des rejetons : pause de 4 s")
	var at := GameState.next_wave
	run(sim, 4.1)
	check_eq(GameState.wave, 2, "vague 2 après la pause (%.2f)" % at)
