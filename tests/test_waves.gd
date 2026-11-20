extends "res://tests/fight_case.gd"
## Étape 8 (v2) : vagues (Catalog.MENACE_WAVE : base + par vague + par palier de menace, en escouades), statistiques des ennemis,
## attente des ennemis hors rejetons avant la pause de 4 s.


## Effectif d'une vague au palier de menace 0 (Catalog.MENACE_WAVE).
static func wave_size(w: int) -> int:
	return int(Catalog.MENACE_WAVE["base"]) + w * int(Catalog.MENACE_WAVE["per_wave"])


func test_waves_follow_catalog() -> void:
	var sim := game()
	for w in 6:
		GameState.sim_time = 100.0
		GameState.wave = w
		sim.combat.start_wave()
		# Effectif du barème ; l'ordre d'apparition suit les escouades (Combat.wave_squads).
		check_eq(GameState.spawn_queue.size(), wave_size(w + 1), "vague %d : nombre" % (w + 1))
		var squads := Combat.wave_squads(w + 1, wave_size(w + 1))
		check_eq(GameState.wave_squads, squads.size(), "vague %d : escouades" % (w + 1))
		var i := 0
		for k in squads.size():
			for kind: String in squads[k]:
				var s: Dictionary = GameState.spawn_queue[i]
				check_eq(s["kind"], kind, "vague %d, ennemi %d : type" % [w + 1, i])
				check_near(s["at"], 102.0, 1e-6, "vague %d, ennemi %d : instant" % [w + 1, i])
				check_eq(s["x"], -2.0 if k % 2 == 0 else 2.0, "vague %d, ennemi %d : colonne" % [w + 1, i])
				check_eq(s["squad"], k, "vague %d, ennemi %d : escouade" % [w + 1, i])
				i += 1


func test_enemy_stats_follow_catalog() -> void:
	var sim := game()
	# Les trois ennemis du prototype ; leurs chiffres ont été rééquilibrés depuis (Catalog.ENEMY fait foi).
	for k: String in js()["enemies"]:
		var want: Dictionary = Catalog.ENEMY[k]
		var e := sim.combat.spawn_enemy({"x": 2.0, "kind": k})
		# Allure des vagues : vitesse du catalogue × Catalog.WAVE_PACE.
		check_eq([e.hp, e.max_hp, e.reach, e.damage], [float(want["hp"]), float(want["hp"]), float(want["range"]), float(want["damage"])], k)
		check_near(e.speed, float(want["speed"]) * Catalog.WAVE_PACE, 1e-6, k + " : vitesse")
		check(e.z >= 62.0 and e.z <= 66.0 and absf(e.x - 2.0) <= 1.6, "%s apparaît au sud : %s" % [k, e.pos()])


func test_first_wave_and_pause() -> void:
	var sim := game()
	# En armure, l'Ingénieur (portée 250) abattrait aussitôt le rampant qui doit retenir la vague suivante.
	for u: Unit in GameState.units:
		if u.role == "engineer":
			u.unarmored = true
	GameState.orb_active = true
	GameState.sim_time = 50.0
	GameState.next_wave = 70.0
	run(sim, 19.9)
	check_eq(GameState.wave, 0, "pas d'assaut avant 20 s")
	run(sim, 0.2)
	check_eq(GameState.wave, 1, "premier assaut")
	check_eq(GameState.spawn_queue.size(), wave_size(1), "ennemis de la première vague en file")
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
	check(GameState.next_wave > 0.0, "seuls des rejetons : pause")
	var at := GameState.next_wave
	var days := DayNight.day(at) - DayNight.day(GameState.sim_time)
	# Un assaut par jour (DayNight.next_assault) : le lendemain matin, ou le surlendemain si le repos déborde.
	check(days >= 1 and days <= 2, "prochain assaut le lendemain ou le surlendemain (%d)" % days)
	check(DayNight.is_day(at), "prochain assaut de jour")
	# Saut jusqu'à la veille de l'assaut (la faune laissée seule des jours durant abattrait l'Ingénieur désarmé).
	GameState.enemies.clear()
	GameState.sim_time = at - 0.1
	run(sim, 0.2)
	check_eq(GameState.wave, 2, "vague 2 au matin prévu (%.2f, t %.2f, fin %s, suivante %.2f)" % [at, GameState.sim_time, GameState.ended, GameState.next_wave])
