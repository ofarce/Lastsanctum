extends "res://tests/test_case.gd"
## Étape 5 (v2) : introduction par le portail, déplacement, réactivation de l'Ancre, creusement par
## l'Ingénieur, formation de déplacement, priorités du clic droit (73b410f).

const DT := 1.0 / 60.0
const SEED := 20261114

static var _main: Node


func _game() -> Node:
	if _main == null:
		_main = load("res://main/main.tscn").instantiate()
		(Engine.get_main_loop() as SceneTree).root.add_child(_main)
	var sim: Simulation = _main.get_node("Simulation")
	sim.paused = true
	sim.new_game(SEED)
	return _main


func _sim() -> Simulation:
	return _game().get_node("Simulation")


func _run(sim: Simulation, seconds: float) -> void:
	for i in roundi(seconds / DT):
		sim.tick(DT)


func _engineer() -> Unit:
	return GameState.units[0]


func test_engineer_emerges_from_portal_at_3s() -> void:
	var sim := _sim()
	var greeted := []
	sim.engineer_greeted.connect(func(u: Unit) -> void: greeted.append(u))
	var u := _engineer()
	var arrival_pos := u.pos()
	check(u.hidden, "caché au départ")
	check_eq(GameState.selected, [u], "sélectionné au départ")
	_run(sim, 2.95)
	check(u.hidden, "toujours caché avant 3 s")
	_run(sim, 0.1)
	check(not u.hidden, "sorti du portail à 3 s")
	check_eq(Vector2(u.tx, u.tz), arrival_pos, "reste devant le portail")
	check_eq(greeted.size(), 1, "dialogue d'accueil déclenché une fois")
	_run(sim, 2.0)
	check_eq(u.pos(), arrival_pos, "aucun déplacement après la sortie du portail")


func test_move_speed_and_wall_sliding() -> void:
	var sim := _sim()
	var u := _engineer()
	u.hidden = false
	u.x = 0.0
	u.z = -130.0
	u.tx = 15.2
	u.tz = -130.0
	_run(sim, 0.5)
	check_near(u.x, 7.6, 0.05, "15,2 u/s")
	# Vers la roche à l'est de la salle : l'unité reste sur un sol praticable.
	u.tx = 120.0
	u.memo.clear()
	_run(sim, 3.0)
	check(sim.state().walkable(u.x, u.z), "toujours sur un sol praticable : %s" % u.pos())
	check(u.x < 66.0, "arrêtée par la paroi : %s" % u.pos())


func test_orb_reactivation() -> void:
	var sim := _sim()
	var woke := []
	sim.turrets_activated.connect(func() -> void: woke.append(true))
	_run(sim, 3.1)
	var u := _engineer()
	sim.order_orb(u)
	check(u.orb_job and GameState.orb_owner == u, "Ingénieur affecté à l'Ancre")
	check_eq(Vector2(u.tx, u.tz), Simulation.ORB_SPOT, "point de travail (core.x − 5, core.z + 4)")
	# Environ 17 unités à 15,2 u/s depuis la sortie du portail, puis 8 s d'Énonciation.
	_run(sim, 2.0)
	check(GameState.orb_progress > 0.0 and sim.kneeling(u), "Énonciation en cours, Ingénieur agenouillé")
	_run(sim, 7.5)
	check(GameState.orb_active, "Ancre réactivée")
	check(not u.orb_job, "tâche terminée")
	check_near(GameState.next_wave, GameState.orb_finished_at + 20.0, 1e-6, "premier assaut programmé à +20 s")
	# Les balistes s'arment à l'arrivée de l'étincelle, SPARK_ARRIVAL après l'éveil.
	if GameState.sim_time - GameState.orb_finished_at < Simulation.SPARK_ARRIVAL - 0.1:
		check(woke.is_empty() and not GameState.turrets[0]["complete"], "balistes endormies pendant le trajet de l'étincelle")
	_run(sim, Simulation.SPARK_ARRIVAL + 0.1)
	check_eq(woke.size(), 1, "tourelles éveillées une fois")
	check(GameState.turrets[0]["complete"] and GameState.turrets[1]["complete"], "les deux balistes armées")
	check_near(GameState.turrets[0]["finished_at"] - GameState.orb_finished_at, Simulation.SPARK_ARRIVAL, 0.05, "armées à l'arrivée de l'étincelle")
	var f0: float = GameState.res["forge"]
	_run(sim, 2.0)
	check_near(GameState.res["forge"] - f0, 0.0, 0.05, "aucun revenu passif")
	check_near(GameState.res["savoir"], GameState.res["forge"], 1e-6, "les 4 ressources au même rythme")

	var before := GameState.res.duplicate()
	sim.set_job(u, {"type": "anchor_pray"})
	_run(sim, 2.0)
	for resource: String in Catalog.RES_ORDER:
		check_near(GameState.res[resource] - before[resource], 6.0, 0.05, "deux secondes à l’Ancre")
		check_eq(Simulation.resource_rates()[resource], 3.0, "revenu de prière")
	sim.issue_move(Vector2(0, -130))
	_run(sim, 1.0)
	for resource: String in Catalog.RES_ORDER:
		check_near(GameState.res[resource] - before[resource], 6.0, 0.05, "prière interrompue")


func test_order_orb_cancelled_by_move() -> void:
	var sim := _sim()
	_run(sim, 3.1)
	var u := _engineer()
	sim.order_orb(u)
	sim.issue_move(Vector2(-20, -130))
	check(not u.orb_job and GameState.orb_owner == null, "un ordre de déplacement annule la réactivation")
	check(u.force_move, "déplacement explicite")


func test_engineer_digs_and_chains() -> void:
	var sim := _sim()
	_run(sim, 3.1)
	var u := _engineer()
	GameState.selected = [u]
	check(sim.order_adepts(Vector2(64, -138)), "clic droit sur la roche : creusement")
	check(u.job != null and u.job["type"] == "dig", "tâche de creusement")
	var first: Vector2i = Vector2i(u.job["cell"]["i"], u.job["cell"]["j"])
	# Trajet depuis le portail jusqu'à la paroi est (environ 70 unités), puis 1 case par seconde.
	_run(sim, 9.0)
	check(sim.state().dug.has(first), "première case creusée")
	# Le creusement suit la file de cases sélectionnées (glisser) : un clic seul ne creuse qu'une case.
	check_eq(sim.state().dug.size(), 1, "pas d'enchaînement automatique sur une case voisine")
	check(u.job == null, "tâche terminée après la case demandée")


func test_issue_move_formation_matches_js() -> void:
	var sim := _sim()
	_run(sim, 3.1)
	var units: Array[Unit] = [_engineer()]
	for i in 5:
		var a := sim.spawn("Adepte", -10.0 + i, -130.0, "sigil")
		units.append(a)
	GameState.selected = units
	sim.issue_move(Vector2(0, -120))
	# 6 unités, 4 colonnes : décalages x (−2,25, −0,75, 0,75, 2,25), lignes z (−0,75, +0,75).
	var expected := [Vector2(-2.25, -120.75), Vector2(-0.75, -120.75), Vector2(0.75, -120.75), Vector2(2.25, -120.75),
		Vector2(-2.25, -119.25), Vector2(-0.75, -119.25)]
	for i in units.size():
		check_eq(Vector2(units[i].tx, units[i].tz), expected[i], "cible %d" % i)


func test_right_click_on_orb_orders_reactivation() -> void:
	var main := _game()
	var sim: Simulation = main.get_node("Simulation")
	var input: InputController = main.get_node("Input")
	_run(sim, 3.1)
	var u := _engineer()
	GameState.selected = [u]
	var orb_screen := input.project(CaveShape.CORE.x, 2.6, CaveShape.CORE.y)
	check(input.hit_orb(orb_screen), "l'orbe est sous le curseur")
	input._right_click(orb_screen)
	check(u.orb_job, "clic droit sur l'Ancre éteinte : réactivation")
	input._left_click(orb_screen, false)
	check(GameState.anchor_selected and GameState.selected.is_empty(), "clic gauche sur l'Ancre : Ancre sélectionnée")
