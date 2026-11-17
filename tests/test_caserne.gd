extends "res://tests/econ_case.gd"
## Étape 7 (v2) : caserne (file de 5, 100 Discipline, 6 s par escouade de quatre, sortie devant le bâtiment).


func test_training_queue() -> void:
	var sim := game()
	var b := built("caserne", 26.0, -112.0)
	GameState.res["discipline"] = 250.0
	ready_caserne(sim, b, 2)
	sim.train_unit(b, "archer")
	sim.train_unit(b, "lame")
	sim.train_unit(b, "flammes")
	check_eq(b.queue, ["archer", "lame"] as Array[String], "250 Discipline : 2 escouades en file")
	check_near(GameState.res["discipline"], 50.0, 1e-9, "200 Discipline payés")
	var n := GameState.units.size()
	run(sim, 5.9)
	check_eq(GameState.units.size(), n, "pas de sortie avant 6 s")
	run(sim, 0.2)
	check_eq(GameState.units.size(), n + 4, "première escouade de quatre sortie")
	var u: Unit = GameState.units[-1]
	check_eq(u.role, "archer", "archer d'abord")
	check_eq(u.max_hp, 85.0, "PV d'archer")
	check(u.z > b.z + b.half() - 0.1, "sort au sud de la caserne : %s" % u.pos())
	check_eq(b.queue, ["lame"] as Array[String], "file restante")
	run(sim, 6.1)
	check_eq(GameState.units[-1].role, "lame", "puis épée et bouclier")


func test_queue_full() -> void:
	var sim := game()
	var b := built("caserne", 26.0, -112.0)
	GameState.res["discipline"] = 1000.0
	stock_caserne_items(6)
	for i in 6:
		sim.train_unit(b, "archer")
	check_eq(b.queue.size(), 5, "file de 5 au plus")
	check_near(GameState.res["discipline"], 500.0, 1e-9, "le 6e n'est pas payé")
	check(not HudModel.can_train(b), "bouton désactivé file pleine")
